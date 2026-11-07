#!/usr/bin/env bash
# =============================================================================
#  flash-linux.sh — записать прошивку PulsarOS на SD-карту из Linux
#
#  IMAGEWTY — это контейнер прошивки, а не образ диска, поэтому `dd` всего
#  файла не работает: карте нужен boot0 по смещению 8 КиБ, особая таблица
#  разделов Allwinner и содержимое разделов по абсолютным смещениям.
#
#  Скрипт воспроизводит то, что делает PhoenixCard в режиме StartUp:
#
#    0            sunxi_mbr.fex      таблица разделов (формат Allwinner)
#    8 КиБ        boot0_sdcard.fex   первичный загрузчик (BROM читает отсюда)
#    128 КиБ      boot_package.fex   u-boot + optee + dtb (парсит boot0)
#    по MBR       boot-resource, env, boot, vendor_boot, super, misc,
#                 vbmeta*, dtbo, metadata, private, media_data, ...
#    UDISK        не форматируется — Android создаст /data при первом старте
#
#  Использование:
#    sudo scripts/flash-linux.sh out/PulsarOS-20261107.img /dev/sdX [--yes]
#    sudo scripts/flash-linux.sh out/PulsarOS-20261107.img /dev/sdX --dry-run
#
#  --uboot-offset N   смещение boot_package в байтах (по умолчанию 131072)
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG=""
DEV=""
ASSUME_YES=0
DRY_RUN=0
VERIFY_ONLY=0
UBOOT_OFFSET=131072
WORK=""

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

args=()
for a in "$@"; do
    case "$a" in
        --yes)          ASSUME_YES=1 ;;
        --dry-run)      DRY_RUN=1 ;;
        --verify-only)  VERIFY_ONLY=1 ;;
        --uboot-offset=*) UBOOT_OFFSET="${a#*=}" ;;
        -h|--help)      usage 0 ;;
        *)              args+=("$a") ;;
    esac
done
IMG="${args[0]:-}"; DEV="${args[1]:-}"
[[ -n "$IMG" && -n "$DEV" ]] || usage

log()  { printf '\033[36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m  ok  %s\033[0m\n' "$*"; }
warn() { printf '\033[33m  !   %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31m[FAIL] %s\033[0m\n' "$*" >&2; exit 1; }

[[ -f "$IMG" ]] || die "нет файла образа: $IMG"
[[ -b "$DEV" ]] || die "$DEV не блочное устройство"
[[ $EUID -eq 0 ]] || die "нужен root"

# ── Защита от записи на системный диск ──────────────────────────────────────
ROOT_SRC="$(findmnt -no SOURCE /)"
ROOT_DISK="/dev/$(lsblk -no PKNAME "$ROOT_SRC" | head -1)"
[[ "$DEV" == "$ROOT_DISK" ]] && die "$DEV — диск, с которого загружен хост"

REMOVABLE="$(lsblk -no RM "$DEV" | head -1)"
TRAN="$(lsblk -no TRAN "$DEV" | head -1)"
if [[ "$REMOVABLE" != "1" && "$TRAN" != "usb" ]]; then
    die "$DEV не выглядит съёмным (rm=$REMOVABLE, transport=${TRAN:-?})"
fi

# ── Распаковка секций ───────────────────────────────────────────────────────
WORK="$(mktemp -d /tmp/pulsaros-flash.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

log "Читаю образ"
python3 "$REPO_DIR/tools/imagewty.py" list "$IMG" > "$WORK/list.txt" || die "не IMAGEWTY"
for sec in sunxi_mbr.fex boot0_sdcard.fex boot_package.fex; do
    python3 "$REPO_DIR/tools/imagewty.py" extract "$IMG" "$sec" "$WORK/$sec" >/dev/null
done

# ── План: смещения из MBR ───────────────────────────────────────────────────
python3 - "$WORK" > "$WORK/plan.txt" <<'PY'
import struct, sys, os
work = sys.argv[1]
mbr = open(os.path.join(work, "sunxi_mbr.fex"), "rb").read()

# Формат Allwinner MBR: запись 128 байт, +4 start (секторы), +12 size,
# +32 имя. Проверено на стоковом образе: разделы идут непрерывно.
FILES = {
    "bootloader_a": "boot-resource.fex",
    "env_a":        "env.fex",
    "boot_a":       "boot.fex",
    "vendor_boot_a": "vendor_boot.fex",
    "super":        "super.fex",
    "misc":         "misc.fex",
    "vbmeta_a":     "vbmeta.fex",
    "vbmeta_system_a": "vbmeta_system.fex",
    "vbmeta_vendor_a": "vbmeta_vendor.fex",
    "dtbo_a":       "dtbo.fex",
}
for i in range(25):
    off = 32 + i * 128
    start, size = struct.unpack_from("<I", mbr, off + 4)[0], struct.unpack_from("<I", mbr, off + 12)[0]
    name = mbr[off + 32:off + 48].split(b"\x00")[0].decode("ascii", "replace")
    fex = FILES.get(name)
    if fex:
        print(f"{name}\t{start}\t{size}\t{fex}")
    elif size:
        print(f"{name}\t{start}\t{size}\t-")
PY

DATA_END=$(awk -F'\t' '{ if ($2+$3 > m) m = $2+$3 } END { print m*512 }' "$WORK/plan.txt")

echo
log "План записи"
printf '  %-18s %12s %12s  %s\n' "partition" "offset" "size" "source"
printf '  %-18s %12s %12s  %s\n' "sunxi_mbr" "0" "$(stat -c %s "$WORK/sunxi_mbr.fex")" "partition table"
printf '  %-18s %12s %12s  %s\n' "boot0_sdcard" "8192" "$(stat -c %s "$WORK/boot0_sdcard.fex")" "first stage"
printf '  %-18s %12s %12s  %s\n' "boot_package" "$UBOOT_OFFSET" "$(stat -c %s "$WORK/boot_package.fex")" "u-boot+dtb"
while IFS=$'\t' read -r name start size fex; do
    [[ "$fex" == "-" ]] && continue
    printf '  %-18s %12s %12s  %s\n' "$name" "$((start*512))" "$((size*512))" "$fex"
done < "$WORK/plan.txt"

CARD_BYTES=$(blockdev --getsize64 "$DEV")
echo
log "Карта: $DEV  $(numfmt --to=iec "$CARD_BYTES")"
echo "  данные до: $(numfmt --to=iec "$DATA_END"), UDISK (/data) — остаток"
[[ $CARD_BYTES -ge $DATA_END ]] || die "карта меньше образа"

if [[ $DRY_RUN -eq 1 ]]; then
    echo
    ok "dry-run: ничего не записано"
    exit 0
fi

# ── Проверка ────────────────────────────────────────────────────────────────
fail=0
verify_at() {
    # 4-й аргумент — сколько байт сравнивать (по умолчанию весь файл).
    local off="$1" f="$2" label="$3" limit="${4:-0}" sz h1 h2
    sz=$(stat -c %s "$f")
    if [[ "$limit" -gt 0 && "$limit" -lt "$sz" ]]; then sz="$limit"; fi
    h1=$(head -c "$sz" "$f" | sha256sum | cut -d' ' -f1)
    h2=$(dd if="$DEV" bs=4M iflag=skip_bytes,count_bytes skip="$off" count="$sz" \
         status=none | sha256sum | cut -d' ' -f1)
    if [[ "$h1" == "$h2" ]]; then ok "$label"; else printf '\033[31m  FAIL %s\033[0m\n' "$label"; fail=$((fail+1)); fi
}

# ── Только проверка ─────────────────────────────────────────────────────────
if [[ $VERIFY_ONLY -eq 1 ]]; then
    log "Проверяю уже записанное (без записи)"
    fail=0
    verify_at 0 "$WORK/sunxi_mbr.fex" "sunxi_mbr" 8192
    verify_at 8192 "$WORK/boot0_sdcard.fex" "boot0_sdcard"
    verify_at "$UBOOT_OFFSET" "$WORK/boot_package.fex" "boot_package"
    while IFS=$'\t' read -r name start size fex; do
        [[ "$fex" == "-" ]] && continue
        src="$WORK/$fex"
        [[ -f "$src" ]] || python3 "$REPO_DIR/tools/imagewty.py" extract "$IMG" "$fex" "$src" >/dev/null
        verify_at "$((start*512))" "$src" "$name"
    done < "$WORK/plan.txt"
    echo
    [[ $fail -eq 0 ]] && { ok "все разделы на карте совпадают с образом"; exit 0; }
    die "не совпало разделов: $fail"
fi

# ── Подтверждение ───────────────────────────────────────────────────────────
lsblk "$DEV"
echo
printf '\033[31mВСЁ НА %s БУДЕТ УНИЧТОЖЕНО.\033[0m\n' "$DEV"
if [[ $ASSUME_YES -ne 1 ]]; then
    read -r -p "Введите имя устройства ($DEV): " ans
    [[ "$ans" == "$DEV" ]] || { echo "Отменено."; exit 10; }
fi

for p in "$DEV"*; do umount "$p" 2>/dev/null || true; done

# ── Запись ──────────────────────────────────────────────────────────────────
wr() { # wr <файл> <смещение> <подпись>
    local f="$1" off="$2" label="$3"
    [[ -f "$f" ]] || { warn "$label: нет файла"; return; }
    local sz; sz=$(stat -c %s "$f")
    # seek_bytes обязателен: смещения не кратны размеру блока (boot0 на 8 КиБ,
    # boot_package на 128 КиБ). С seek=N в блоках dd округлил бы их вниз.
    dd if="$f" of="$DEV" bs=4M iflag=fullblock oflag=seek_bytes seek="$off" \
       conv=notrunc,fsync status=none || die "запись $label не удалась"
    ok "$label → $off ($(numfmt --to=iec "$sz"))"
}

log "Пишу"
wr "$WORK/sunxi_mbr.fex" 0 "sunxi_mbr"
wr "$WORK/boot0_sdcard.fex" 8192 "boot0_sdcard"
wr "$WORK/boot_package.fex" "$UBOOT_OFFSET" "boot_package"

while IFS=$'\t' read -r name start size fex; do
    [[ "$fex" == "-" ]] && continue
    src="$WORK/$fex"
    [[ -f "$src" ]] || python3 "$REPO_DIR/tools/imagewty.py" extract "$IMG" "$fex" "$src" >/dev/null
    wr "$src" "$((start*512))" "$name"
done < "$WORK/plan.txt"

sync

# ── Проверка чтением ────────────────────────────────────────────────────────
log "Проверяю записанное"
verify_at 0 "$WORK/sunxi_mbr.fex" "sunxi_mbr" 8192
verify_at 8192 "$WORK/boot0_sdcard.fex" "boot0_sdcard"
verify_at "$UBOOT_OFFSET" "$WORK/boot_package.fex" "boot_package"
while IFS=$'\t' read -r name start size fex; do
    [[ "$fex" == "-" ]] && continue
    src="$WORK/$fex"
    [[ -f "$src" ]] || python3 "$REPO_DIR/tools/imagewty.py" extract "$IMG" "$fex" "$src" >/dev/null
    verify_at "$((start*512))" "$src" "$name"
done < "$WORK/plan.txt"

echo
if [[ $fail -eq 0 ]]; then
    ok "карта записана, все проверки прошли"
    echo
    echo "Дальше: вставить в Orange Pi Zero 3, включить."
    echo "Если не загружается — попробовать другое смещение boot_package:"
    echo "  sudo $0 $IMG $DEV --uboot-offset=1048576"
else
    die "проверка не прошла ($fail)"
fi