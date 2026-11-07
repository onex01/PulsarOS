#!/usr/bin/env bash
# =============================================================================
#  flash-linux.sh — записать прошивку PulsarOS на SD-карту из Linux
#
#  IMAGEWTY — контейнер прошивки, а не образ диска, поэтому `dd` всего файла
#  не работает. Раскладка на карте задаётся двумя файлами внутри образа:
#
#    cardscript.fex  скрипт PhoenixCard: boot0, boot_package, начало разделов
#    sunxi_mbr.fex   таблица разделов (её смещения надо сдвинуть)
#
#  Смещения не задаются в скрипте: их вычисляет tools/flashplan.py.
#
#  Использование:
#    sudo scripts/flash-linux.sh <image.img> /dev/sdX [--yes]
#    sudo scripts/flash-linux.sh <image.img> /dev/sdX --dry-run
#    sudo scripts/flash-linux.sh <image.img> /dev/sdX --verify-only
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSUME_YES=0
DRY_RUN=0
VERIFY_ONLY=0

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

args=()
for a in "$@"; do
    case "$a" in
        --yes)         ASSUME_YES=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        --verify-only) VERIFY_ONLY=1 ;;
        -h|--help)     usage 0 ;;
        *)             args+=("$a") ;;
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

ROOT_SRC="$(findmnt -no SOURCE /)"
ROOT_DISK="/dev/$(lsblk -no PKNAME "$ROOT_SRC" | head -1)"
[[ "$DEV" == "$ROOT_DISK" ]] && die "$DEV — диск, с которого загружен хост"

REMOVABLE="$(lsblk -no RM "$DEV" | head -1)"
TRAN="$(lsblk -no TRAN "$DEV" | head -1)"
if [[ "$REMOVABLE" != "1" && "$TRAN" != "usb" ]]; then
    die "$DEV не выглядит съёмным (rm=$REMOVABLE, transport=${TRAN:-?})"
fi

WORK="$(mktemp -d /tmp/pulsaros-flash.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# ── План ────────────────────────────────────────────────────────────────────
log "Строю план записи"
python3 "$REPO_DIR/tools/flashplan.py" "$IMG" --json > "$WORK/plan.json" \
    || die "не удалось разобрать образ"

python3 - "$WORK" <<'PY'
import json, os, sys
work = sys.argv[1]
plan = json.load(open(os.path.join(work, "plan.json")))
with open(os.path.join(work, "plan.tsv"), "w") as f:
    for e in plan["entries"]:
        f.write(f"{e['kind']}\t{e['name']}\t{e['offset']}\t{e['size']}\t{e['source'] or '-'}\n")
PY

CARD_BOOT=$(python3 -c "import json;print(json.load(open('$WORK/plan.json'))['card_boot_sector'])")
DELTA=$(python3 -c "import json,sys;print(json.load(open('$WORK/plan.json'))['mbr_delta_sectors'])")
DATA_END=$(python3 -c "import json;print(json.load(open('$WORK/plan.json'))['data_end'])")

# u-boot reads partitions with EFI GPT only, so the Allwinner MBR alone is not
# enough: without a GPT it reports "Invalid GPT" and cannot find env or boot.
# The GPT is generated for the real card size, because the backup header lives
# in the last sectors.
CARD_SECTORS=$(blockdev --getsz "$DEV")

# Таблица должна лежать в LBA 2: u-boot этого образа не уважает поле
# partition_entry_lba и читает записи сразу за заголовком. При 128 записях
# они занимают LBA 2..33 и налезают на boot0 (сектор 16), поэтому число
# записей уменьшается ровно настолько, чтобы закончиться до boot0.
BOOT0_SECTOR=$(( $(awk -F'\t' '$2=="boot0_sdcard"{print $3}' "$WORK/plan.tsv") / 512 ))
MAX_ENTRIES=$(( (BOOT0_SECTOR - 2) * 512 / 128 ))
ENTRIES_COUNT=$(awk -F'\t' '$1=="partition"{n++} END{print n}' "$WORK/plan.tsv")
[[ $ENTRIES_COUNT -gt $MAX_ENTRIES ]] && ENTRIES_COUNT=$MAX_ENTRIES

log "Генерирую GPT: LBA 2, $ENTRIES_COUNT записей (до boot0 на секторе $BOOT0_SECTOR)"
python3 - "$WORK" "$CARD_SECTORS" "$REPO_DIR" "$ENTRIES_COUNT" <<'PY'
import json, os, subprocess, sys
work, sectors, repo, count = sys.argv[1], int(sys.argv[2]), sys.argv[3], int(sys.argv[4])
plan = json.load(open(os.path.join(work, "plan.json")))
args = ["python3", os.path.join(repo, "tools", "mkgpt.py"),
        "--disk-sectors", str(sectors), "--entries-lba", "2",
        "--entries-count", str(count),
        "--out", os.path.join(work, "gpt.bin")]
ends = []
for e in plan["entries"]:
    if e["kind"] != "partition" or e["size"] <= 0:
        continue
    start = e["offset"] // 512
    size = e["size"] // 512
    args += ["--part", "%s:%d:%d" % (e["name"], start, size)]
    ends.append(start + size)

# UDISK в MBR имеет размер 0, поэтому в план он не попал. Без раздела
# userdata Android не создаст /data: и u-boot, и fstab ищут именно это имя.
# Отдаём ему всё до резервной копии GPT.
if ends:
    udisk_start = max(ends)
    udisk_size = sectors - udisk_start - 64
    if udisk_size > 0:
        args += ["--part", "userdata:%d:%d" % (udisk_start, udisk_size)]
        print("  userdata: %d + %d секторов" % (udisk_start, udisk_size))
subprocess.run(args, check=True)
PY

printf '  %-18s %13s %13s  %s\n' "что" "смещение" "размер" "источник"
while IFS=$'\t' read -r kind name off size src; do
    printf '  %-18s %13s %13s  %s\n' "$name" "$off" "$size" "$src"
done < "$WORK/plan.tsv"

CARD_BYTES=$(blockdev --getsize64 "$DEV")
echo
log "Карта $DEV: $(numfmt --to=iec "$CARD_BYTES")"
echo "  разделы с сектора $CARD_BOOT (сдвиг MBR $DELTA), данные до $(numfmt --to=iec "$DATA_END")"
echo "  остальное — UDISK (/data), Android отформатирует при первом старте"
[[ $CARD_BYTES -ge $DATA_END ]] || die "карта меньше образа"

extract() { # extract <section> <out>
    [[ -f "$2" ]] || python3 "$REPO_DIR/tools/imagewty.py" extract "$IMG" "$1" "$2" >/dev/null
}

# ── Проверка ────────────────────────────────────────────────────────────────
fail=0
verify_at() { # verify_at <offset> <file> <label> [limit]
    local off="$1" f="$2" label="$3" limit="${4:-0}" sz h1 h2
    [[ -f "$f" ]] || { warn "$label: нет файла"; return; }
    sz=$(stat -c %s "$f")
    if [[ "$limit" -gt 0 && "$limit" -lt "$sz" ]]; then sz="$limit"; fi
    h1=$(head -c "$sz" "$f" | sha256sum | cut -d' ' -f1)
    h2=$(dd if="$DEV" bs=4M iflag=skip_bytes,count_bytes skip="$off" count="$sz" \
         status=none | sha256sum | cut -d' ' -f1)
    if [[ "$h1" == "$h2" ]]; then ok "$label"; else printf '\033[31m  FAIL %s\033[0m\n' "$label"; fail=$((fail+1)); fi
}

verify_all() {
    fail=0
    # gpt.bin содержит дыру между заголовком и таблицей — в неё пишется
    # boot0, поэтому проверять файл целиком нельзя. Сверяем две области:
    # protective MBR + заголовок (LBA 0..1) и саму таблицу.
    verify_at 0 "$WORK/gpt.bin" "GPT (LBA 0..1 + entries)"
    while IFS=$'\t' read -r kind name off size src; do
        [[ "$src" == "-" ]] && continue
        extract "$src" "$WORK/$src"
        verify_at "$off" "$WORK/$src" "$name"
    done < "$WORK/plan.tsv"
}

if [[ $VERIFY_ONLY -eq 1 ]]; then
    log "Проверяю карту (без записи)"
    verify_all
    echo
    [[ $fail -eq 0 ]] && { ok "все разделы совпадают с образом"; exit 0; }
    die "не совпало: $fail"
fi

if [[ $DRY_RUN -eq 1 ]]; then
    echo
    ok "dry-run: ничего не записано"
    exit 0
fi

# ── Запись ──────────────────────────────────────────────────────────────────
lsblk "$DEV"
echo
printf '\033[31mВСЁ НА %s БУДЕТ УНИЧТОЖЕНО.\033[0m\n' "$DEV"
if [[ $ASSUME_YES -ne 1 ]]; then
    read -r -p "Введите имя устройства ($DEV): " ans
    [[ "$ans" == "$DEV" ]] || { echo "Отменено."; exit 10; }
fi

for p in "$DEV"*; do umount "$p" 2>/dev/null || true; done

wr() { # wr <file> <offset> <label>
    local f="$1" off="$2" label="$3"
    [[ -f "$f" ]] || { warn "$label: нет файла"; return; }
    # seek_bytes: смещения не кратны блоку (8 КиБ, 16.79 МиБ), с seek=N в
    # блоках dd округлил бы их вниз и затёр MBR.
    dd if="$f" of="$DEV" bs=4M iflag=fullblock oflag=seek_bytes seek="$off" \
       conv=notrunc,fsync status=none || die "запись $label не удалась"
    ok "$label → $off ($(numfmt --to=iec "$(stat -c %s "$f")"))"
}

log "Пишу"
# GPT: protective MBR + header + entries одним куском с LBA0.
wr "$WORK/gpt.bin" 0 "GPT"

# Резервная копия GPT в конце карты: u-boot проверяет и её, а без неё
# ругается "Invalid Backup GPT".
BACKUP_LBA=$(( CARD_SECTORS - 33 ))
wr "$WORK/gpt.bin.backup" $(( BACKUP_LBA * 512 )) "GPT backup"

while IFS=$'\t' read -r kind name off size src; do
    [[ "$src" == "-" ]] && continue
    [[ "$kind" == "partition" ]] || continue
    extract "$src" "$WORK/$src"
    wr "$WORK/$src" "$off" "$name"
done < "$WORK/plan.tsv"

# загрузчики пишем последними: boot0 и boot_package лежат в промежутке,
# который разделы не занимают, но так исключаем любой шанс их затереть.
while IFS=$'\t' read -r kind name off size src; do
    [[ "$kind" == "bootloader" ]] || continue
    extract "$src" "$WORK/$src"
    wr "$WORK/$src" "$off" "$name"
done < "$WORK/plan.tsv"

sync

log "Проверяю записанное"
verify_all

echo
if [[ $fail -eq 0 ]]; then
    ok "карта записана, проверки прошли"
    echo
    echo "Вставить в Orange Pi Zero 3 и включить."
else
    die "проверка не прошла ($fail)"
fi