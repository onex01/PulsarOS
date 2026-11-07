#!/usr/bin/env python3
"""mbr.py — read and shift the Allwinner MBR.

The image carries `sunxi_mbr.fex`, but its partition starts do not match where
PhoenixCard actually puts things on an SD card. cardscript.fex (the script
PhoenixCard executes) says:

    [boot_0_0]   start=16      boot0 at 8 KiB
    [boot_1_0]   start=32800   boot_package at 16.79 MiB
    [card_boot]  start=40960   first partition at 20 MiB

The MBR in the image starts the first partition at 32768 (16 MiB), which would
put boot_package *inside* bootloader_a. So the starts have to be shifted by
40960 - 32768 = 8192 sectors before writing to an SD card.

Entry layout, verified against the stock image (128 bytes per entry):

    +0   u32  unused
    +4   u32  start, in 512-byte sectors
    +8   u32  unused
    +12  u32  size, in 512-byte sectors
    +16  char[16] class, e.g. "DISK"
    +32  char[16] name
    +48  u32  start again
    +52  ...

Usage:
    python3 mbr.py list   <sunxi_mbr.fex>
    python3 mbr.py shift  <sunxi_mbr.fex> <delta_sectors> <out.fex>
    python3 mbr.py align  <sunxi_mbr.fex> <first_start_sectors> <out.fex>
"""

import struct
import sys

ENTRY_COUNT = 25
ENTRY_SIZE = 128
ENTRIES_OFFSET = 32


def entries(buf):
    out = []
    for i in range(ENTRY_COUNT):
        off = ENTRIES_OFFSET + i * ENTRY_SIZE
        if off + ENTRY_SIZE > len(buf):
            break
        start = struct.unpack_from("<I", buf, off + 4)[0]
        size = struct.unpack_from("<I", buf, off + 12)[0]
        name = buf[off + 32:off + 48].split(b"\x00")[0].decode("ascii", "replace")
        out.append({"index": i, "offset": off, "start": start, "size": size, "name": name})
    return out


def cmd_list(path):
    buf = bytearray(open(path, "rb").read())
    print(f"{'#':>2} {'name':18s} {'start':>11s} {'size':>11s} {'start_MiB':>10s} {'end_MiB':>9s}")
    for e in entries(buf):
        print(f"{e['index']:>2} {e['name']:18s} {e['start']:>11,} {e['size']:>11,} "
              f"{e['start'] * 512 / 1048576:>10.1f} {(e['start'] + e['size']) * 512 / 1048576:>9.1f}")
    return 0


def rewrite(buf, fn):
    for e in entries(buf):
        if e["size"] == 0:
            continue
        new = fn(e["start"])
        struct.pack_into("<I", buf, e["offset"] + 4, new)
        struct.pack_into("<I", buf, e["offset"] + 48, new)


def cmd_shift(path, delta, out):
    buf = bytearray(open(path, "rb").read())
    delta = int(delta)
    rewrite(buf, lambda s: s + delta)
    open(out, "wb").write(buf)
    print(f"сдвиг на {delta} секторов ({delta * 512 / 1048576:.1f} MiB) -> {out}")
    return 0


def cmd_align(path, first, out):
    buf = bytearray(open(path, "rb").read())
    ents = [e for e in entries(buf) if e["size"]]
    if not ents:
        raise SystemExit("в MBR нет разделов")
    cur = ents[0]["start"]
    delta = int(first) - cur
    rewrite(buf, lambda s: s + delta)
    open(out, "wb").write(buf)
    print(f"первый раздел {cur} -> {first} (сдвиг {delta}) -> {out}")
    return 0


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "list":
        return cmd_list(sys.argv[2])
    if cmd == "shift":
        return cmd_shift(sys.argv[2], sys.argv[3], sys.argv[4])
    if cmd == "align":
        return cmd_align(sys.argv[2], sys.argv[3], sys.argv[4])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())