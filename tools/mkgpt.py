#!/usr/bin/env python3
"""mkgpt.py — build a GUID Partition Table for the SD card.

u-boot in this image parses partitions with EFI GPT only (`part_get_info_efi`),
so the Allwinner `softw411` MBR alone is not enough: u-boot reports
"Invalid GPT" and cannot find bootloader / boot-resource / env / boot.

The GPT is generated from the partition list, with two naming rules:

  * names come from sys_partition.fex (boot_a, env_a, super, ...), because
    Android mounts /dev/block/by-name/<name> and expects the slot suffix;
  * UDISK becomes `userdata`, which is the name both u-boot
    ("sprite update error: no userdata partition") and Android's fstab use.

Layout written:

    LBA 0        protective MBR (type 0xEE)
    LBA 1        GPT header
    LBA 2..33    128 partition entries of 128 bytes
    last LBA     backup header
    ...          backup entries

Usage:
    python3 mkgpt.py --disk-sectors N --out gpt.bin \
        --part "name:start:size" [--part ...]
"""

import argparse
import binascii
import struct
import sys
import uuid

SECTOR = 512
ENTRY_COUNT = 128
ENTRY_SIZE = 128
ENTRIES_LBA = 2
ENTRIES_SECTORS = ENTRY_COUNT * ENTRY_SIZE // SECTOR

# Microsoft basic data. Every Allwinner Android partition uses it, including
# the ones Android later mounts as ext4 or f2fs.
TYPE_BASIC_DATA = uuid.UUID("EBD0A0A2-B9E5-4433-87C0-68B6B72699C7")

# Deterministic namespace so a rebuild produces the same GUIDs.
GUID_NAMESPACE = uuid.UUID("6f1c7d2a-3b4e-4a55-9c8d-0e1f2a3b4c5d")

RENAME = {"UDISK": "userdata"}


def part_guid(name):
    return uuid.uuid5(GUID_NAMESPACE, name)


def build_entries(parts, first_usable, last_usable):
    entries = bytearray(ENTRY_COUNT * ENTRY_SIZE)
    for i, (name, start, size) in enumerate(parts):
        if size <= 0:
            continue
        end = start + size - 1
        off = i * ENTRY_SIZE
        entries[off:off + 16] = TYPE_BASIC_DATA.bytes_le
        entries[off + 16:off + 32] = part_guid(name).bytes_le
        struct.pack_into("<QQQ", entries, off + 32, start, end, 0)
        encoded = name.encode("utf-16-le")[:72]
        entries[off + 56:off + 56 + len(encoded)] = encoded
    return bytes(entries)


def build_header(my_lba, alt_lba, first_usable, last_usable,
                 disk_guid, entries_crc, entries_lba):
    header = bytearray(92)
    header[0:8] = b"EFI PART"
    struct.pack_into("<I", header, 8, 0x00010000)          # revision
    struct.pack_into("<I", header, 12, 92)                 # header size
    struct.pack_into("<Q", header, 24, my_lba)
    struct.pack_into("<Q", header, 32, alt_lba)
    struct.pack_into("<Q", header, 40, first_usable)
    struct.pack_into("<Q", header, 48, last_usable)
    header[56:72] = disk_guid.bytes_le
    struct.pack_into("<Q", header, 72, entries_lba)
    struct.pack_into("<I", header, 80, ENTRY_COUNT)
    struct.pack_into("<I", header, 84, ENTRY_SIZE)
    struct.pack_into("<I", header, 88, entries_crc)
    crc = binascii.crc32(bytes(header)) & 0xFFFFFFFF
    struct.pack_into("<I", header, 16, crc)
    return bytes(header)


def build(disk_sectors, parts, disk_guid):
    first_usable = ENTRIES_LBA + ENTRIES_SECTORS
    last_usable = disk_sectors - ENTRIES_SECTORS - 2

    # The last partition (userdata) is sized to the end of the card, which
    # would overlap the backup GPT. Clamp every partition to last_usable.
    clamped = []
    for name, start, size in parts:
        if size > 0:
            size = min(size, last_usable - start + 1)
            if size <= 0:
                continue
        clamped.append((name, start, size))
    parts = clamped

    entries = build_entries(parts, first_usable, last_usable)
    entries_crc = binascii.crc32(entries) & 0xFFFFFFFF

    # Protective MBR
    mbr = bytearray(SECTOR)
    struct.pack_into("<I", mbr, 440, 0)                     # disk signature
    e = 446
    mbr[e + 0] = 0x00
    mbr[e + 1:e + 4] = b"\x00\x02\x00"                      # CHS start
    mbr[e + 4] = 0xEE                                       # GPT protective
    mbr[e + 5:e + 8] = b"\xff\xff\xff"                      # CHS end
    struct.pack_into("<I", mbr, e + 8, 1)
    struct.pack_into("<I", mbr, e + 12, min(disk_sectors - 1, 0xFFFFFFFF))
    mbr[510:512] = b"\x55\xaa"

    primary_header = build_header(1, disk_sectors - 1, first_usable,
                                  last_usable, disk_guid, entries_crc, ENTRIES_LBA)
    backup_entries_lba = disk_sectors - ENTRIES_SECTORS - 1
    backup_header = build_header(disk_sectors - 1, 1, first_usable,
                                 last_usable, disk_guid, entries_crc, backup_entries_lba)

    out = bytearray()
    out += mbr
    out += primary_header + b"\x00" * (SECTOR - len(primary_header))
    out += entries
    return bytes(out), bytes(backup_header), entries, backup_entries_lba, disk_sectors - 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--disk-sectors", type=int, required=True)
    ap.add_argument("--part", action="append", default=[],
                    metavar="NAME:START:SIZE")
    ap.add_argument("--out", required=True)
    ap.add_argument("--guid", default=None)
    args = ap.parse_args()

    parts = []
    for spec in args.part:
        name, start, size = spec.split(":")
        name = RENAME.get(name, name)
        parts.append((name, int(start), int(size)))

    disk_guid = uuid.UUID(args.guid) if args.guid else part_guid("pulsaros-disk")

    head, backup_header, entries, backup_entries_lba, backup_header_lba = build(
        args.disk_sectors, parts, disk_guid)

    with open(args.out, "wb") as f:
        f.write(head)

    # Backup GPT goes at the end of the card; the flasher writes it separately.
    with open(args.out + ".backup", "wb") as f:
        f.write(entries)
        f.write(backup_header)

    print(f"GPT: {len(parts)} разделов, disk {args.disk_sectors:,} секторов")
    print(f"  таблица: {args.out} ({len(head):,} байт)")
    print(f"  backup : {args.out}.backup, entries на LBA {backup_entries_lba}, "
          f"header на LBA {backup_header_lba}")
    for name, start, size in parts:
        if size > 0:
            print(f"    {name:18s} {start:>11,} +{size:>11,}")
    return 0


if __name__ == "__main__":
    sys.exit(main())