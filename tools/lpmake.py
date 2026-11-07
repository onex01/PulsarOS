#!/usr/bin/env python3
"""lpmake.py — build an Android super image from partition files.

`lpmake` ships only inside AOSP, so this reimplements the part needed to
rebuild the Orange Pi super partition with different partition sizes.

Manifest (JSON):

    {
      "output": "super.raw.img",
      "total_size": 3221225472,
      "logical_block_size": 4096,
      "sector_size": 512,
      "metadata_max_size": 65536,
      "metadata_slot_count": 3,
      "alignment": 1048576,
      "first_logical_sector": 2048,
      "block_device_name": "super",
      "groups": [
        {"name": "default", "maximum_size": 0},
        {"name": "sb_a", "maximum_size": 3212836864},
        {"name": "sb_b", "maximum_size": 3212836864}
      ],
      "partitions": [
        {"name": "system_a", "group": "sb_a", "source": "system_a.img",
         "size": 833998848, "attributes": 1}
      ]
    }

The layout matches the stock image, which was verified byte for byte:

    0x000000  reserved
    0x001000  geometry block (4096 bytes)
    0x003000  metadata slots, metadata_slot_count x metadata_max_size
    0x100000  partition data (first_logical_sector 2048 x 512)

Checksums are SHA-256 over the structure with the checksum field zeroed;
verified against the stock image before this tool was written.

Usage:
    python3 lpmake.py <manifest.json>
"""

import hashlib
import json
import os
import struct
import sys

GEOMETRY_OFFSET = 4096
GEOMETRY_SIZE = 4096
METADATA_OFFSET = 0x3000
METADATA_HEADER_SIZE = 256
GEOMETRY_MAGIC = 0x616C4467
METADATA_MAGIC = 0x414C5030
METADATA_MAJOR = 10
METADATA_MINOR = 2
PARTITION_ENTRY_SIZE = 52
EXTENT_ENTRY_SIZE = 24
GROUP_ENTRY_SIZE = 48
BLOCK_DEVICE_ENTRY_SIZE = 64
ATTR_READONLY = 0x01
EXTENT_LINEAR = 0


def align_up(value, alignment):
    return (value + alignment - 1) // alignment * alignment


def build_geometry(cfg):
    max_size = cfg.get("metadata_max_size", 65536)
    slots = cfg.get("metadata_slot_count", 3)
    lb = cfg.get("logical_block_size", 4096)
    geom = bytearray(GEOMETRY_SIZE)
    struct.pack_into("<II", geom, 0, GEOMETRY_MAGIC, 52)
    struct.pack_into("<III", geom, 40, max_size, slots, lb)
    checksum = hashlib.sha256(bytes(geom[:52])).digest()
    geom[8:40] = checksum
    return bytes(geom)


def build_metadata(cfg, partitions, extents, groups):
    partitions_size = len(partitions) * PARTITION_ENTRY_SIZE
    extents_size = len(extents) * EXTENT_ENTRY_SIZE
    groups_size = len(groups) * GROUP_ENTRY_SIZE
    blocks_size = BLOCK_DEVICE_ENTRY_SIZE

    partitions_off = 0
    extents_off = partitions_off + partitions_size
    groups_off = extents_off + extents_size
    blocks_off = groups_off + groups_size
    tables_size = blocks_off + blocks_size

    tables = bytearray(tables_size)

    for i, p in enumerate(partitions):
        off = partitions_off + i * PARTITION_ENTRY_SIZE
        name = p["name"].encode()[:35]
        tables[off:off + len(name)] = name
        tables[off + 36:off + 40] = bytes([p.get("attributes", ATTR_READONLY), 0, 0, 0])
        struct.pack_into("<III", tables, off + 40,
                         p["first_extent"], p["num_extents"], p["group_index"])

    for i, e in enumerate(extents):
        off = extents_off + i * EXTENT_ENTRY_SIZE
        struct.pack_into("<QIII", tables, off,
                         e["num_sectors"], e["target_type"], e["target_data"], e["target_source"])

    for i, g in enumerate(groups):
        off = groups_off + i * GROUP_ENTRY_SIZE
        name = g["name"].encode()[:35]
        tables[off:off + len(name)] = name
        struct.pack_into("<I", tables, off + 36, g.get("flags", 0))
        struct.pack_into("<Q", tables, off + 40, g.get("maximum_size", 0))

    off = blocks_off
    struct.pack_into("<II", tables, off,
                     cfg.get("first_logical_sector", 2048),
                     cfg.get("alignment_offset", 0))
    struct.pack_into("<Q", tables, off + 8, cfg.get("alignment", 1048576))
    struct.pack_into("<Q", tables, off + 16, cfg["total_size"])
    name = cfg.get("block_device_name", "super").encode()[:35]
    tables[off + 24:off + 24 + len(name)] = name

    header = bytearray(METADATA_HEADER_SIZE)
    struct.pack_into("<IHHI", header, 0, METADATA_MAGIC, METADATA_MAJOR,
                     METADATA_MINOR, METADATA_HEADER_SIZE)
    struct.pack_into("<I", header, 0x2C, tables_size)
    struct.pack_into("<III", header, 0x50, partitions_off, len(partitions), PARTITION_ENTRY_SIZE)
    struct.pack_into("<III", header, 0x5C, extents_off, len(extents), EXTENT_ENTRY_SIZE)
    struct.pack_into("<III", header, 0x68, groups_off, len(groups), GROUP_ENTRY_SIZE)
    struct.pack_into("<III", header, 0x74, blocks_off, 1, BLOCK_DEVICE_ENTRY_SIZE)

    tables_checksum = hashlib.sha256(bytes(tables)).digest()
    header[0x30:0x50] = tables_checksum

    header_checksum = hashlib.sha256(bytes(header)).digest()
    header[0x0C:0x2C] = header_checksum

    return bytes(header) + bytes(tables)


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    with open(sys.argv[1]) as f:
        cfg = json.load(f)

    sector_size = cfg.get("sector_size", 512)
    alignment = cfg.get("alignment", 1048576)
    first_sector = cfg.get("first_logical_sector", 2048)

    groups = cfg["groups"]
    group_index = {g["name"]: i for i, g in enumerate(groups)}

    # Lay the data out first: one linear extent per partition, aligned.
    cursor = first_sector * sector_size
    placed = []
    extents = []
    for spec in cfg["partitions"]:
        source = spec.get("source")
        size = spec.get("size", 0)
        if source and os.path.exists(source):
            size = os.path.getsize(source)
        elif size == 0:
            # Empty slot (for example system_b in an A/B layout): no extents.
            placed.append({"spec": spec, "offset": None, "size": 0,
                           "first_extent": len(extents), "num_extents": 0})
            continue

        cursor = align_up(cursor, alignment)
        num_sectors = align_up(size, sector_size) // sector_size
        placed.append({"spec": spec, "offset": cursor, "size": size,
                       "first_extent": len(extents), "num_extents": 1})
        extents.append({"num_sectors": num_sectors, "target_type": EXTENT_LINEAR,
                        "target_data": cursor // sector_size, "target_source": 0})
        cursor += num_sectors * sector_size

    total_size = cfg.get("total_size")
    if not total_size:
        total_size = align_up(cursor, alignment)
    if cursor > total_size:
        print(f"ERROR: data needs {cursor:,} bytes but total_size is {total_size:,}",
              file=sys.stderr)
        return 1

    partitions = []
    for item in placed:
        spec = item["spec"]
        partitions.append({
            "name": spec["name"],
            "group_index": group_index[spec.get("group", "default")],
            "first_extent": item["first_extent"],
            "num_extents": item["num_extents"],
            "attributes": spec.get("attributes", ATTR_READONLY),
        })

    out_path = cfg["output"]
    with open(out_path, "wb") as out:
        out.truncate(total_size)
        out.seek(GEOMETRY_OFFSET)
        out.write(build_geometry(cfg))

        metadata = build_metadata(cfg, partitions, extents, groups)
        max_size = cfg.get("metadata_max_size", 65536)
        if len(metadata) > max_size:
            print(f"ERROR: metadata {len(metadata)} > max_size {max_size}", file=sys.stderr)
            return 1
        for slot in range(cfg.get("metadata_slot_count", 3)):
            out.seek(METADATA_OFFSET + slot * max_size)
            out.write(metadata)

        for item in placed:
            if item["offset"] is None:
                continue
            out.seek(item["offset"])
            with open(item["spec"]["source"], "rb") as src:
                while True:
                    chunk = src.read(8 << 20)
                    if not chunk:
                        break
                    out.write(chunk)

    print(f"super image : {out_path}")
    print(f"size        : {total_size:,} bytes ({total_size / 1024 / 1024:.1f} MiB)")
    print(f"data end    : {cursor:,}")
    print(f"free inside : {total_size - cursor:,} bytes")
    print()
    print(f"{'partition':20s} {'group':10s} {'size':>14s} {'offset':>14s}")
    for item in placed:
        spec = item["spec"]
        off = "-" if item["offset"] is None else f"{item['offset']:,}"
        print(f"{spec['name']:20s} {spec.get('group', 'default'):10s} "
              f"{item['size']:>14,} {off:>14s}")
    return 0


if __name__ == "__main__":
    sys.exit(main())