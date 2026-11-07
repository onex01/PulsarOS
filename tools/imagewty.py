#!/usr/bin/env python3
"""imagewty.py — read and rewrite Allwinner IMAGEWTY firmware images.

The repo previously carried a table of section sizes hardcoded from one dump.
That table is wrong for the v1.0 Orange Pi image (it is off by 97 MB, and its
super.fex size is 18 MB short), so it is not used. Everything here is parsed
from the image itself.

Layout (verified against OrangePi_Zero3_Android12_v1.0.img):

    0x0000  header, 96 bytes
    0x0400  section table, `count` entries of `entry_size` bytes (45 x 1024)
    0xB800  data area, sections stored at the offsets from the table

Header fields (little endian):

    0x00  magic        "IMAGEWTY"
    0x08  version      u32   0x00000300
    0x0C  subversion   u32   0x60 for imgRePacker / PhoenixCard compatible
    0x18  file_size    u32
    0x20  table_offset u32   0x400
    0x3C  count        u32
    0x40  entry_size   u32   0x400

Section entry fields:

    +0x08  maintype   char[8]
    +0x10  subtype    char[16]
    +0x24  filename   char[N]
    +0x124 size       u32   length of the section payload
    +0x134 offset     u32   absolute offset of the payload in the image

Usage:
    python3 imagewty.py list   <image>
    python3 imagewty.py extract <image> <section> <outfile>
    python3 imagewty.py replace <image> <section> <infile> [--out out.img]
"""

import argparse
import os
import shutil
import struct
import sys

MAGIC = b"IMAGEWTY"
HEADER_SIZE = 96
TABLE_OFFSET_FIELD = 0x20
COUNT_FIELD = 0x3C
ENTRY_SIZE_FIELD = 0x40
DATA_START = 0xB800

# PhoenixCard checks this creator string; images packed by `dragon` leave it
# empty and are rejected with "Image error, use new version image file!".
CREATOR = b"imgRePacker     (c) RedScorpio  "


class ImageWTY:
    def __init__(self, path):
        self.path = path
        self.size = os.path.getsize(path)
        with open(path, "rb") as f:
            self.header = f.read(HEADER_SIZE)
        if self.header[:8] != MAGIC:
            raise ValueError(f"{path}: not an IMAGEWTY image")
        self.version = struct.unpack_from("<I", self.header, 0x08)[0]
        self.subversion = struct.unpack_from("<I", self.header, 0x0C)[0]
        self.file_size = struct.unpack_from("<I", self.header, 0x18)[0]
        self.table_offset = struct.unpack_from("<I", self.header, TABLE_OFFSET_FIELD)[0]
        self.count = struct.unpack_from("<I", self.header, COUNT_FIELD)[0]
        self.entry_size = struct.unpack_from("<I", self.header, ENTRY_SIZE_FIELD)[0]
        self.sections = self._parse_table()

    def _parse_table(self):
        out = []
        with open(self.path, "rb") as f:
            for i in range(self.count):
                f.seek(self.table_offset + i * self.entry_size)
                entry = f.read(self.entry_size)
                if len(entry) < 0x138:
                    break
                name = entry[0x24:0x24 + 64].split(b"\x00")[0].decode("ascii", "replace")
                out.append({
                    "index": i,
                    "name": name,
                    "maintype": entry[0x08:0x10].decode("ascii", "replace").strip(),
                    "subtype": entry[0x10:0x20].decode("ascii", "replace").strip(),
                    "size": struct.unpack_from("<I", entry, 0x124)[0],
                    "offset": struct.unpack_from("<I", entry, 0x134)[0],
                })
        return out

    def get(self, name):
        for s in self.sections:
            if s["name"] == name:
                return s
        raise KeyError(name)

    def read_section(self, name):
        s = self.get(name)
        with open(self.path, "rb") as f:
            f.seek(s["offset"])
            return f.read(s["size"])

    def write_section(self, name, data, out_path=None):
        """Overwrite a section in place. The new payload must not be larger
        than the space the section occupies, because every following section
        keeps its absolute offset."""
        s = self.get(name)
        # Space available = distance to the next section's offset.
        nxt = self.size
        for other in self.sections:
            if other["offset"] > s["offset"]:
                nxt = min(nxt, other["offset"])
        available = nxt - s["offset"]
        if len(data) > available:
            raise ValueError(
                f"{name}: payload {len(data)} bytes does not fit in {available} "
                f"bytes; repacking a larger image needs lpmake, not an in-place patch")

        target = out_path or self.path
        if out_path:
            shutil.copy2(self.path, out_path)

        with open(target, "r+b") as f:
            f.seek(s["offset"])
            f.write(data)
            if len(data) < s["size"]:
                f.write(b"\x00" * (s["size"] - len(data)))
            # Record the new length in the table entry.
            f.seek(self.table_offset + s["index"] * self.entry_size + 0x124)
            f.write(struct.pack("<I", len(data)))
        return target

    def ensure_phoenix_compatible(self, out_path=None):
        """Write the creator string at 0x60, which PhoenixCard validates."""
        target = out_path or self.path
        if out_path:
            shutil.copy2(self.path, out_path)
        with open(target, "r+b") as f:
            f.seek(HEADER_SIZE)
            current = f.read(32)
            if current != CREATOR:
                f.seek(HEADER_SIZE)
                f.write(CREATOR)
        return target


def cmd_list(args):
    img = ImageWTY(args.image)
    print(f"image      : {args.image}")
    print(f"size       : {img.size:,} bytes ({img.size / 1024 / 1024:.1f} MiB)")
    print(f"version    : 0x{img.version:04x}")
    print(f"subversion : 0x{img.subversion:04x}"
          + ("  (PhoenixCard compatible)" if img.subversion == 0x60 else "  (dragon)"))
    print(f"sections   : {img.count} x {img.entry_size} bytes at 0x{img.table_offset:x}")
    print()
    print(f"{'#':>2}  {'name':22s} {'offset':>13s} {'size':>13s} {'end':>13s}")
    for s in img.sections:
        print(f"{s['index']:>2}  {s['name']:22s} {s['offset']:>13,} "
              f"{s['size']:>13,} {s['offset'] + s['size']:>13,}")
    return 0


def cmd_extract(args):
    img = ImageWTY(args.image)
    data = img.read_section(args.section)
    with open(args.outfile, "wb") as f:
        f.write(data)
    print(f"{args.section}: {len(data):,} bytes -> {args.outfile}")
    return 0


def cmd_replace(args):
    img = ImageWTY(args.image)
    with open(args.infile, "rb") as f:
        data = f.read()
    out = img.write_section(args.section, data, args.out)
    print(f"{args.section} <- {args.infile} ({len(data):,} bytes)")
    print(f"written: {out}")
    return 0


def cmd_info(args):
    img = ImageWTY(args.image)
    s = img.get(args.section)
    print(f"{s['name']}: offset={s['offset']:,} size={s['size']:,} "
          f"maintype={s['maintype']} subtype={s['subtype']}")
    with open(img.path, "rb") as f:
        f.seek(s["offset"])
        head = f.read(32)
    print(f"head: {head.hex(' ')}")
    return 0


def repack(image_path, replacements, out_path, align=1024):
    """Build a new IMAGEWTY with sections laid out sequentially.

    Needed because super.fex has only 352 bytes of slack before the next
    section: as soon as the payload grows, every following offset has to move.
    Header and table metadata are preserved; only offsets, sizes and the total
    file size are recomputed.
    """
    img = ImageWTY(image_path)

    with open(image_path, "rb") as f:
        head = bytearray(f.read(DATA_START))

    payloads = []
    for sec in img.sections:
        name = sec["name"]
        if name in replacements:
            with open(replacements[name], "rb") as f:
                data = f.read()
        else:
            data = img.read_section(name)
        payloads.append((sec, data))

    cursor = DATA_START
    layout = []
    for sec, data in payloads:
        cursor = (cursor + align - 1) // align * align
        layout.append((sec, data, cursor))
        cursor += len(data)

    total = cursor
    if total > 0xFFFFFFFF:
        raise ValueError("image would exceed the 32-bit size field")

    struct.pack_into("<I", head, 0x18, total)

    with open(out_path, "wb") as out:
        out.write(head)
        out.truncate(total)
        for sec, data, offset in layout:
            entry_off = img.table_offset + sec["index"] * img.entry_size
            out.seek(entry_off + 0x124)
            out.write(struct.pack("<I", len(data)))
            out.seek(entry_off + 0x134)
            out.write(struct.pack("<I", offset))
            out.seek(offset)
            out.write(data)

    return total, layout


def cmd_repack(args):
    replacements = {}
    for item in args.replace or []:
        name, _, path = item.partition("=")
        if not path:
            raise SystemExit(f"--replace needs section=file, got {item!r}")
        replacements[name] = path
    total, layout = repack(args.image, replacements, args.out)
    print(f"repacked -> {args.out}: {total:,} bytes")
    for sec, data, offset in layout:
        mark = " *" if sec["name"] in replacements else ""
        print(f"  {sec['name']:22s} {offset:>13,} {len(data):>13,}{mark}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("list"); p.add_argument("image"); p.set_defaults(func=cmd_list)

    p = sub.add_parser("extract")
    p.add_argument("image"); p.add_argument("section"); p.add_argument("outfile")
    p.set_defaults(func=cmd_extract)

    p = sub.add_parser("replace")
    p.add_argument("image"); p.add_argument("section"); p.add_argument("infile")
    p.add_argument("--out")
    p.set_defaults(func=cmd_replace)

    p = sub.add_parser("info")
    p.add_argument("image"); p.add_argument("section")
    p.set_defaults(func=cmd_info)

    p = sub.add_parser("repack")
    p.add_argument("image"); p.add_argument("out")
    p.add_argument("--replace", action="append", metavar="SECTION=FILE")
    p.set_defaults(func=cmd_repack)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())