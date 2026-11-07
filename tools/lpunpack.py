#!/usr/bin/env python3
"""lpunpack.py — read Android dynamic partitions from a super image.

`lpunpack` is not packaged on Fedora or Debian, so this reimplements the parts
needed to inspect and rebuild a super image. The format is documented in AOSP
system/core/fs_mgr/liblp.

Layout of a super image:

    offset 4096                  LP geometry (magic 0x616c4467 "gDla")
    4096 + 4096 + slot * max     metadata slot, `metadata_slot_count` of them
    ...                          partition data, addressed by extents

Geometry:

    0x00  magic                 u32  0x616c4467
    0x04  struct_size           u32  52
    0x08  checksum              u8[32]
    0x28  metadata_max_size     u32
    0x2C  metadata_slot_count   u32
    0x30  logical_block_size    u32

Metadata header:

    0x00  magic                 u32  0x414c5030
    0x04  major_version         u16  10
    0x06  minor_version         u16
    0x08  header_size           u32  80
    0x0C  header_checksum       u8[32]
    0x2C  tables_size           u32
    0x30  tables_checksum       u8[32]
    0x50  partitions            table descriptor
    0x5C  extents               table descriptor
    0x68  groups                table descriptor
    0x74  block_devices         table descriptor

Table descriptor: offset u32, num_entries u32, entry_size u32. Offsets are
relative to the start of the metadata header.

Partition entry: name char[36], attributes u8[4], first_extent_index u32,
num_extents u32, group_index u32.

Extent: num_sectors u64, target_type u32 (0 linear, 1 zero), target_data u32,
target_source u32.

Usage:
    python3 lpunpack.py info     <super.img>
    python3 lpunpack.py extract  <super.img> <partition> <out.img>
    python3 lpunpack.py extract-all <super.img> <outdir>
"""

import os
import struct
import sys

GEOMETRY_MAGIC = 0x616C4467
METADATA_MAGIC = 0x414C5030
GEOMETRY_OFFSET = 4096
GEOMETRY_SIZE = 4096
EXTENT_LINEAR = 0
EXTENT_ZERO = 1


class Geometry:
    def __init__(self, buf):
        magic, struct_size = struct.unpack_from("<II", buf, 0)
        if magic != GEOMETRY_MAGIC:
            raise ValueError("LP geometry magic not found at offset 4096")
        self.struct_size = struct_size
        self.metadata_max_size = struct.unpack_from("<I", buf, 0x28)[0]
        self.metadata_slot_count = struct.unpack_from("<I", buf, 0x2C)[0]
        self.logical_block_size = struct.unpack_from("<I", buf, 0x30)[0]


class TableDescriptor:
    def __init__(self, buf, off):
        self.offset, self.num_entries, self.entry_size = struct.unpack_from("<III", buf, off)


class Partition:
    def __init__(self, name, first_extent, num_extents, group_index, attributes):
        self.name = name
        self.first_extent = first_extent
        self.num_extents = num_extents
        self.group_index = group_index
        self.attributes = attributes

    @property
    def readonly(self):
        return bool(self.attributes[0] & 0x01)


class Extent:
    def __init__(self, num_sectors, target_type, target_data, target_source):
        self.num_sectors = num_sectors
        self.target_type = target_type
        self.target_data = target_data
        self.target_source = target_source


class Metadata:
    def __init__(self, buf, base):
        magic, major, minor, header_size = struct.unpack_from("<IHHI", buf, base)
        if magic != METADATA_MAGIC:
            raise ValueError(f"metadata magic not found at 0x{base:x}")
        self.major = major
        self.minor = minor
        self.header_size = header_size
        self.tables_size = struct.unpack_from("<I", buf, base + 0x2C)[0]

        self.partitions_desc = TableDescriptor(buf, base + 0x50)
        self.extents_desc = TableDescriptor(buf, base + 0x5C)
        self.groups_desc = TableDescriptor(buf, base + 0x68)
        self.blocks_desc = TableDescriptor(buf, base + 0x74)

        # Table offsets are relative to the end of the header, not to its start:
        # this image has header_size 256 and partitions at rel_offset 0, and the
        # first entry at metadata+256 is "system_a".
        tables_base = base + header_size

        self.partitions = []
        for i in range(self.partitions_desc.num_entries):
            off = tables_base + self.partitions_desc.offset + i * self.partitions_desc.entry_size
            name = buf[off:off + 36].split(b"\x00")[0].decode("ascii", "replace")
            attrs = buf[off + 36:off + 40]
            first_extent, num_extents, group_index = struct.unpack_from("<III", buf, off + 40)
            self.partitions.append(
                Partition(name, first_extent, num_extents, group_index, attrs))

        self.extents = []
        for i in range(self.extents_desc.num_entries):
            off = tables_base + self.extents_desc.offset + i * self.extents_desc.entry_size
            num_sectors, target_type, target_data, target_source = \
                struct.unpack_from("<QIII", buf, off)
            self.extents.append(Extent(num_sectors, target_type, target_data, target_source))

        self.group_names = []
        for i in range(self.groups_desc.num_entries):
            off = tables_base + self.groups_desc.offset + i * self.groups_desc.entry_size
            self.group_names.append(buf[off:off + 36].split(b"\x00")[0].decode("ascii", "replace"))

    def find(self, name):
        for p in self.partitions:
            if p.name == name:
                return p
        raise KeyError(name)

    def extents_for(self, part):
        return self.extents[part.first_extent:part.first_extent + part.num_extents]

    def partition_size(self, part, block_size):
        return sum(e.num_sectors for e in self.extents_for(part)) * block_size


class SuperImage:
    def __init__(self, path):
        self.path = path
        self.size = os.path.getsize(path)
        with open(path, "rb") as f:
            f.seek(GEOMETRY_OFFSET)
            self.geometry = Geometry(f.read(GEOMETRY_SIZE))
            # The metadata does not always start right after the geometry
            # block: this image puts it two blocks in (0x3000). Locate it by
            # magic at block alignment instead of trusting an offset formula.
            self.metadata_base = self._find_metadata(f)
            self.slot_offsets = [
                self.metadata_base + i * self.geometry.metadata_max_size
                for i in range(self.geometry.metadata_slot_count)
            ]
            f.seek(self.metadata_base)
            buf = f.read(self.geometry.metadata_max_size)
        self.metadata = Metadata(buf, 0)
        # Extent sector units: liblp documents them in logical blocks, but this
        # image stores them in 512-byte sectors. Detect instead of assuming.
        self.sector_size = self._detect_sector_size()

    def _detect_sector_size(self):
        candidates = [512, self.geometry.logical_block_size]
        for size in candidates:
            ok = 0
            with open(self.path, "rb") as f:
                for p in self.metadata.partitions:
                    exts = self.metadata.extents_for(p)
                    if not exts:
                        continue
                    e = exts[0]
                    if e.target_type != EXTENT_LINEAR:
                        continue
                    f.seek(e.target_data * size)
                    head = f.read(4096)
                    if len(head) < 0x43A:
                        continue
                    ext4 = struct.unpack_from("<H", head, 0x438)[0]
                    if ext4 == 0xEF53 or head[:4] == b"\xe2\xe1\xf5\xe0":
                        ok += 1
            if ok:
                return size
        return self.geometry.logical_block_size

    def _find_metadata(self, f):
        magic = struct.pack("<I", METADATA_MAGIC)
        f.seek(GEOMETRY_OFFSET)
        head = f.read(4 << 20)
        pos = 0
        while True:
            hit = head.find(magic, pos)
            if hit < 0:
                raise ValueError("LP metadata magic not found after the geometry block")
            if hit % 4096 == 0:
                # hit is relative to GEOMETRY_OFFSET; return an absolute one.
                return GEOMETRY_OFFSET + hit
            pos = hit + 1

    def extract(self, part, out_path):
        bs = self.sector_size
        with open(self.path, "rb") as f, open(out_path, "wb") as out:
            for e in self.metadata.extents_for(part):
                nbytes = e.num_sectors * bs
                if e.target_type == EXTENT_LINEAR:
                    f.seek(e.target_data * bs)
                    left = nbytes
                    while left:
                        chunk = f.read(min(left, 8 << 20))
                        if not chunk:
                            raise ValueError(f"{part.name}: extent runs past end of image")
                        out.write(chunk)
                        left -= len(chunk)
                elif e.target_type == EXTENT_ZERO:
                    out.write(b"\x00" * nbytes)
                else:
                    raise ValueError(f"{part.name}: unknown extent type {e.target_type}")
        return os.path.getsize(out_path)


def cmd_info(path):
    img = SuperImage(path)
    g = img.geometry
    m = img.metadata
    print(f"super image    : {path}")
    print(f"size           : {img.size:,} bytes")
    print(f"logical block  : {g.logical_block_size}")
    print(f"extent sector  : {img.sector_size} (auto-detected)")
    print(f"metadata slots : {g.metadata_slot_count} x {g.metadata_max_size:,} bytes")
    print(f"metadata ver   : {m.major}.{m.minor}")
    print(f"groups         : {', '.join(m.group_names) or '-'}")
    print()
    print(f"{'partition':24s} {'size':>13s} {'extents':>8s}  group")
    total = 0
    for p in m.partitions:
        sz = m.partition_size(p, img.sector_size)
        total += sz
        grp = m.group_names[p.group_index] if p.group_index < len(m.group_names) else "?"
        print(f"{p.name:24s} {sz:>13,} {p.num_extents:>8d}  {grp}")
    print(f"\n{'total':24s} {total:>13,}")
    return 0


def cmd_extract(path, name, out):
    img = SuperImage(path)
    part = img.metadata.find(name)
    n = img.extract(part, out)
    print(f"{name}: {n:,} bytes -> {out}")
    return 0


def cmd_extract_all(path, outdir):
    img = SuperImage(path)
    os.makedirs(outdir, exist_ok=True)
    for p in img.metadata.partitions:
        out = os.path.join(outdir, f"{p.name}.img")
        n = img.extract(p, out)
        print(f"{p.name:24s} {n:>13,} -> {out}")
    return 0


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "info":
        return cmd_info(sys.argv[2])
    if cmd == "extract":
        return cmd_extract(sys.argv[2], sys.argv[3], sys.argv[4])
    if cmd == "extract-all":
        return cmd_extract_all(sys.argv[2], sys.argv[3])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())