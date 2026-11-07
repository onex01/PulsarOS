#!/usr/bin/env python3
"""flashplan.py — построить план записи SD-карты из образа IMAGEWTY.

Раскладка берётся из двух файлов внутри образа:

  cardscript.fex   скрипт, который исполняет PhoenixCard:
                     [boot_0_0]  start=16      boot0
                     [boot_1_0]  start=32800   boot_package
                     [card_boot] start=40960   начало разделов
  sunxi_mbr.fex    таблица разделов Allwinner; её начальные смещения
                   отсчитаны от card_boot, поэтому перед записью на карту
                   их нужно сдвинуть

Почему сдвиг обязателен: в sunxi_mbr.fex первый раздел начинается с сектора
32768 (16 МиБ), а boot_package по cardscript лежит на 32800 (16.79 МиБ) —
то есть внутри bootloader_a. PhoenixCard поэтому кладёт разделы с 40960
(20 МиБ). Сдвиг = card_boot - первый_раздел_MBR.

Вывод — TSV: kind, name, offset_bytes, size_bytes, source

Usage:
    python3 flashplan.py <image.img> [--json]
"""

import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from imagewty import ImageWTY, DATA_START  # noqa: E402

ENTRY_COUNT = 25
ENTRY_SIZE = 128
ENTRIES_OFFSET = 32

# какое содержимое раздела куда писать
FILES = {
    "bootloader_a": "boot-resource.fex",
    "env_a": "env.fex",
    "boot_a": "boot.fex",
    "vendor_boot_a": "vendor_boot.fex",
    "super": "super.fex",
    "misc": "misc.fex",
    "vbmeta_a": "vbmeta.fex",
    "vbmeta_system_a": "vbmeta_system.fex",
    "vbmeta_vendor_a": "vbmeta_vendor.fex",
    "dtbo_a": "dtbo.fex",
}


def parse_cardscript(text):
    """Достаёт start= из нужных секций."""
    out = {}
    section = None
    for raw in text.splitlines():
        line = raw.split(";")[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            continue
        if "=" in line and section:
            key, _, value = line.partition("=")
            if key.strip() == "start":
                try:
                    out[section] = int(value.strip())
                except ValueError:
                    pass
    return out


def read_mbr(buf):
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


def build_plan(image_path):
    img = ImageWTY(image_path)

    script = img.read_section("cardscript.fex").decode("utf-8", "replace")
    starts = parse_cardscript(script)

    boot0_sector = starts.get("boot_0_0", 16)
    pkg_sector = starts.get("boot_1_0", 32800)
    card_boot = starts.get("card_boot")

    mbr = bytearray(img.read_section("sunxi_mbr.fex"))
    ents = read_mbr(mbr)

    first = next((e["start"] for e in ents if e["size"]), 0)
    if card_boot is None:
        card_boot = first
    delta = card_boot - first

    plan = []

    def add(kind, name, sector, size, source):
        plan.append({
            "kind": kind,
            "name": name,
            "offset": sector * 512,
            "size": size,
            "source": source,
        })

    add("bootloader", "boot0_sdcard", boot0_sector,
        len(img.read_section("boot0_sdcard.fex")), "boot0_sdcard.fex")
    add("bootloader", "boot_package", pkg_sector,
        len(img.read_section("boot_package.fex")), "boot_package.fex")

    # MBR пишется со сдвинутыми смещениями
    shifted = bytearray(mbr)
    for e in ents:
        if e["size"] == 0:
            continue
        new = e["start"] + delta
        struct.pack_into("<I", shifted, e["offset"] + 4, new)
        struct.pack_into("<I", shifted, e["offset"] + 48, new)
        plan.append({
            "kind": "partition",
            "name": e["name"],
            "offset": new * 512,
            "size": e["size"] * 512,
            "source": FILES.get(e["name"]),
            "mbr_start": new,
        })

    data_end = max(p["offset"] + p["size"] for p in plan if p["kind"] == "partition")

    return {
        "image": image_path,
        "disk_sectors": 0,  # заполняется флешером из реального размера карты
        "card_boot_sector": card_boot,
        "mbr_delta_sectors": delta,
        "mbr_bytes": bytes(shifted),
        "entries": plan,
        "data_end": data_end,
    }


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    plan = build_plan(sys.argv[1])

    if "--json" in sys.argv:
        plan["mbr_bytes"] = plan["mbr_bytes"].hex()
        print(json.dumps(plan, indent=2))
        return 0

    print(f"card_boot : сектор {plan['card_boot_sector']} "
          f"({plan['card_boot_sector'] * 512 / 1048576:.1f} MiB)")
    print(f"сдвиг MBR : {plan['mbr_delta_sectors']} секторов "
          f"({plan['mbr_delta_sectors'] * 512 / 1048576:.1f} MiB)")
    print()
    print(f"{'kind':10s} {'name':18s} {'offset':>13s} {'size':>13s}  source")
    for e in plan["entries"]:
        src = e["source"] or "-"
        print(f"{e['kind']:10s} {e['name']:18s} {e['offset']:>13,} {e['size']:>13,}  {src}")
    print()
    print(f"данные до: {plan['data_end']:,} ({plan['data_end'] / 1048576:.1f} MiB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())