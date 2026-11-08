#!/usr/bin/env python3
"""fatextract.py — вытащить файлы из сырого образа FAT16.

Зачем свой разбор: стоковый `boot-resource.fex` — FAT16, который заявляет
128 МиБ при файле 5.6 МБ, с `sectors per track = 0` и `heads = 0` в BPB.
mtools на таком отказывается работать ("zero number of heads or sectors"),
а нам нужно забрать оттуда шрифты и кадры заряда, чтобы пересобрать раздел
на полный размер, не потеряв то, что читает boot_gui.

Читаются только короткие имена (8.3): длинные имена в этом образе не нужны.

    python3 fatextract.py <образ> <каталог> [файл ...]
"""

import os
import struct
import sys


def parse(buf):
    bps, spc, rsv, nf, root, ts16 = struct.unpack_from("<HBHBHH", buf, 11)
    spf, = struct.unpack_from("<H", buf, 22)
    ts32, = struct.unpack_from("<I", buf, 32)
    total = ts16 or ts32
    root_sectors = (root * 32 + bps - 1) // bps
    fat_off = rsv * bps
    root_off = (rsv + nf * spf) * bps
    data_off = (rsv + nf * spf + root_sectors) * bps
    return dict(bps=bps, spc=spc, nf=nf, spf=spf, root=root, total=total,
                fat_off=fat_off, root_off=root_off, data_off=data_off)


def chain(buf, geo, start):
    """Кластеры файла по FAT. Оборванный образ просто закончится."""
    out, seen = [], set()
    c = start
    limit = geo["total"]
    while 2 <= c < 0xFFF8 and c not in seen:
        seen.add(c)
        off = geo["data_off"] + (c - 2) * geo["spc"] * geo["bps"]
        if off >= len(buf):
            break
        out.append(off)
        fat_entry = geo["fat_off"] + c * 2
        if fat_entry + 2 > len(buf):
            break
        c = struct.unpack_from("<H", buf, fat_entry)[0]
        if len(out) > limit:
            break
    return out


def read_file(buf, geo, entry):
    clus, = struct.unpack_from("<H", entry, 26)
    size, = struct.unpack_from("<I", entry, 28)
    data = b""
    for off in chain(buf, geo, clus):
        data += buf[off:off + geo["spc"] * geo["bps"]]
    return data[:size]


def walk(buf, geo, off, count, prefix, out):
    for i in range(count):
        e = buf[off + i * 32:off + (i + 1) * 32]
        if len(e) < 32 or e[0] == 0:
            return
        if e[0] == 0xE5 or e[11] == 0x0F:
            continue
        name = e[0:8].decode("ascii", "replace").rstrip()
        ext = e[8:11].decode("ascii", "replace").rstrip()
        if name in (".", ".."):
            continue
        full = f"{prefix}{name}.{ext}" if ext else f"{prefix}{name}"
        if e[11] & 0x08:
            continue
        if e[11] & 0x10:
            clus, = struct.unpack_from("<H", e, 26)
            sub = geo["data_off"] + (clus - 2) * geo["spc"] * geo["bps"]
            # каталог может занимать несколько кластеров
            for coff in chain(buf, geo, clus):
                walk(buf, geo, coff, geo["spc"] * geo["bps"] // 32, full + "/", out)
            continue
        out.append((full, read_file(buf, geo, e)))


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip())
        return 2
    image, dest = sys.argv[1], sys.argv[2]
    want = set(sys.argv[3:])

    buf = open(image, "rb").read()
    geo = parse(buf)
    if geo["bps"] not in (512, 1024, 2048, 4096) or geo["spc"] == 0:
        print(f"{image}: не FAT", file=sys.stderr)
        return 1

    files = []
    walk(buf, geo, geo["root_off"], geo["root"], "", files)

    os.makedirs(dest, exist_ok=True)
    n = 0
    for name, data in files:
        if want and name not in want and not any(name.startswith(w + "/") for w in want):
            continue
        path = os.path.join(dest, name)
        os.makedirs(os.path.dirname(path) or dest, exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
        print(f"  {name:<24} {len(data):>9,}")
        n += 1
    if n == 0:
        print(f"{image}: файлы не найдены", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())