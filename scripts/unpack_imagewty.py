#!/usr/bin/env python3
"""unpack_imagewty.py — Extract sections from Allwinner IMAGEWTY firmware.

Layout: Header(96) → SectionTable(45×1024 at 0x400) → DataArea(starts at 0xB800)
Sections are stored sequentially with sizes from the BSP pack system.

Usage:
    python3 scripts/unpack_imagewty.py <image.img> [-o <output_dir>]
"""

import struct
import os
import sys
import argparse

MAGIC = b"IMAGEWTY"
DATA_AREA_START = 0xB800

# Section sizes from BSP pack_out (45 sections)
SECTION_SIZES = {
    "sys_config.fex": 32529,
    "board.fex": 1024,
    "config.fex": 53248,
    "split_xxxx.fex": 0,
    "sys_partition.fex": 5601,
    "sunxi.fex": 71680,
    "boot0_nand.fex": 61440,
    "boot0_sdcard.fex": 61440,
    "u-boot.fex": 917504,
    "u-boot-crash.fex": 37,
    "toc1.fex": 8,
    "toc0.fex": 8,
    "fes1.fex": 40160,
    "boot_package.fex": 1294336,
    "usbtool.fex": 154624,
    "usbtool_crash.fex": 621056,
    "aultools.fex": 166515,
    "aultls32.fex": 152069,
    "cardtool.fex": 73728,
    "cardscript.fex": 1899,
    "sunxi_gpt.fex": 8192,
    "sunxi_mbr.fex": 65536,
    "dlinfo.fex": 16384,
    "arisc.fex": 6,
    "vmlinux.fex": 12500351,
    "boot-resource.fex": 281600,
    "Vboot-resource.fex": 4,
    "env.fex": 131072,
    "Venv.fex": 4,
    "boot.fex": 25378816,
    "Vboot.fex": 4,
    "vendor_boot.fex": 73728,
    "Vvendor_boot.fex": 4,
    "super.fex": 1082213912,
    "Vsuper.fex": 4,
    "misc.fex": 16777216,
    "Vmisc.fex": 4,
    "vbmeta.fex": 4096,
    "Vvbmeta.fex": 4,
    "vbmeta_system.fex": 4096,
    "Vvbmeta_system.fex": 4,
    "vbmeta_vendor.fex": 4096,
    "Vvbmeta_vendor.fex": 4,
    "dtbo.fex": 4596,
    "Vdtbo.fex": 4,
}

# Section order from IMAGEWTY table
SECTION_ORDER = [
    "sys_config.fex", "board.fex", "config.fex", "split_xxxx.fex",
    "sys_partition.fex", "sunxi.fex", "boot0_nand.fex", "boot0_sdcard.fex",
    "u-boot.fex", "u-boot-crash.fex", "toc1.fex", "toc0.fex",
    "fes1.fex", "boot_package.fex", "usbtool.fex", "usbtool_crash.fex",
    "aultools.fex", "aultls32.fex", "cardtool.fex", "cardscript.fex",
    "sunxi_gpt.fex", "sunxi_mbr.fex", "dlinfo.fex", "arisc.fex",
    "vmlinux.fex", "boot-resource.fex", "Vboot-resource.fex",
    "env.fex", "Venv.fex", "boot.fex", "Vboot.fex",
    "vendor_boot.fex", "Vvendor_boot.fex", "super.fex", "Vsuper.fex",
    "misc.fex", "Vmisc.fex", "vbmeta.fex", "Vvbmeta.fex",
    "vbmeta_system.fex", "Vvbmeta_system.fex", "vbmeta_vendor.fex",
    "Vvbmeta_vendor.fex", "dtbo.fex", "Vdtbo.fex",
]


def extract_sections(image_path, output_dir):
    file_size = os.path.getsize(image_path)
    print(f"Input: {image_path} ({file_size / (1024*1024):.1f} MB)")

    with open(image_path, "rb") as f:
        header = f.read(96)
        if header[:8] != MAGIC:
            print(f"ERROR: Not IMAGEWTY")
            return
        print(f"Header: version=0x{struct.unpack_from('<H', header, 8)[0]:04x}")

        os.makedirs(output_dir, exist_ok=True)

        pos = DATA_AREA_START
        total = 0

        for name in SECTION_ORDER:
            size = SECTION_SIZES.get(name, 0)
            if size == 0:
                continue

            if pos + size > file_size:
                actual = file_size - pos
            else:
                actual = size

            if actual <= 0:
                continue

            f.seek(pos)
            data = f.read(actual)

            out_path = os.path.join(output_dir, name)
            with open(out_path, "wb") as out:
                out.write(data)

            print(f"  {name:30s} {actual:12d} bytes  0x{pos:08x}")
            pos += actual
            total += actual

    print(f"\nExtracted to {output_dir}")
    print(f"Total: {total} bytes ({total/(1024*1024):.1f} MB)")


def main():
    parser = argparse.ArgumentParser(description="Extract IMAGEWTY sections")
    parser.add_argument("image", help="Input IMAGEWTY file")
    parser.add_argument("-o", "--output", default=None)
    args = parser.parse_args()

    if not os.path.exists(args.image):
        print(f"ERROR: {args.image} not found")
        sys.exit(1)

    output_dir = args.output or args.image + ".extracted"
    extract_sections(args.image, output_dir)


if __name__ == "__main__":
    main()
