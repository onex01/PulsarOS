#!/usr/bin/env python3
"""patch_imagewty.py — Patch dragon-produced IMAGEWTY for PhoenixCard compatibility.

Dragon writes different data at offset 0x60-0x7F (right after the 96-byte header).
imgRePacker writes "imgRePacker (c) RedScorpio" at the same offset.

PhoenixCard's cardtool.fex validates this region and rejects images without
the imgRePacker signature.

This script replaces the 32 bytes at offset 0x60 with the creator string,
making dragon's IMAGEWTY compatible with PhoenixCard.

Usage: python3 scripts/patch_imagewty.py <image_file>
"""

import struct
import sys
import os
import shutil

CREATOR = b"imgRePacker     (c) RedScorpio  "  # 32 bytes, space-padded
HEADER_SIZE = 96
MAGIC = b"IMAGEWTY"


def patch_imagewty(img_path):
    file_size = os.path.getsize(img_path)
    print(f"Input: {img_path} ({file_size / (1024*1024):.1f} MB)")

    with open(img_path, "rb") as f:
        header = f.read(HEADER_SIZE)

    if header[:8] != MAGIC:
        print(f"ERROR: Not an IMAGEWTY file")
        return False

    version = struct.unpack_from("<H", header, 8)[0]
    subversion = struct.unpack_from("<H", header, 0x0C)[0]
    print(f"Header: version=0x{version:04x}, subversion=0x{subversion:04x}")

    # Check if already patched
    with open(img_path, "rb") as f:
        f.seek(HEADER_SIZE)
        current = f.read(32)
    if current == CREATOR:
        print("Already patched")
        return True

    # Backup
    backup = img_path + ".bak"
    if not os.path.exists(backup):
        shutil.copy2(img_path, backup)
        print(f"Backup: {backup}")

    # Patch: overwrite 32 bytes at offset 0x60
    with open(img_path, "r+b") as f:
        f.seek(HEADER_SIZE)
        f.write(CREATOR)

    print(f"Patched: creator string written at offset 0x60")

    # Verify
    with open(img_path, "rb") as f:
        f.seek(HEADER_SIZE)
        verify = f.read(32)
        print(f"Verify: {verify}")

    return True


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: patch_imagewty.py <image_file>")
        sys.exit(1)
    success = patch_imagewty(sys.argv[1])
    sys.exit(0 if success else 1)
