#!/usr/bin/env python3
"""writeimg.py — write a sparse file to a block device without copying holes.

A freshly created f2fs on a 56 GB partition occupies only ~120 MB on disk: the
rest is holes. Writing it with dd would push 56 GB through USB 2.0, which takes
about an hour. This walks the file's data extents (SEEK_DATA / SEEK_HOLE) and
writes only those.

Usage:
    python3 writeimg.py <file> <device> <offset_bytes>
"""

import os
import sys


def write_extents(src, dst, offset):
    written = 0
    with open(src, "rb") as f, open(dst, "r+b") as dev:
        size = os.fstat(f.fileno()).st_size
        pos = 0
        while pos < size:
            try:
                data_start = os.lseek(f.fileno(), pos, os.SEEK_DATA)
            except OSError:
                break  # no more data, only holes
            hole_start = os.lseek(f.fileno(), data_start, os.SEEK_HOLE)
            length = hole_start - data_start
            f.seek(data_start)
            dev.seek(offset + data_start)
            left = length
            while left:
                chunk = f.read(min(left, 8 << 20))
                if not chunk:
                    break
                dev.write(chunk)
                left -= len(chunk)
                written += len(chunk)
            pos = hole_start
    return written


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    src, dst, offset = sys.argv[1], sys.argv[2], int(sys.argv[3])
    n = write_extents(src, dst, offset)
    total = os.path.getsize(src)
    print(f"{src}: {n:,} байт записано из {total:,} (остальное — дыры)")
    return 0


if __name__ == "__main__":
    sys.exit(main())