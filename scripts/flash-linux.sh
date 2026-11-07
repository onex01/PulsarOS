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

# На диске, а не в /tmp: развёрнутый super занимает 3 ГБ, а /tmp обычно tmpfs.
mkdir -p "$REPO_DIR/work"
WORK="$(mktemp -d "$REPO_DIR/work/flash.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# ── План ────────────────────────────────────────────────────────────────────
log "Строю план записи"
python3 "$REPO_DIR/tools/flashplan.py" "$IMG" --json > "$WORK/plan.json" \
    || die "не удалось разобрать образ"

python3 - "$WORK" "$(blockdev --getsz "$DEV")" <<'PY'
import json, os, sys
work = sys.argv[1]
plan = json.load(open(os.path.join(work, "plan.json")))
plan["disk_sectors"] = int(sys.argv[2])
# userdata в MBR нет (у UDISK размер 0), а boot-resource нужен u-boot.
# Считаем оба один раз и пишем и в plan.tsv, и в GPT — иначе таблица и
# запись расходятся, и userdata перекрывает boot-resource.
ends = [e["offset"] // 512 + e["size"] // 512
        for e in plan["entries"] if e["kind"] == "partition" and e["size"] > 0]
derived_parts = []
if ends:
    start = max(ends)
    LOGO = 65536                      # 32 МиБ под FAT с логотипом
    derived_parts.append(("boot-resource", start, LOGO))
    start += LOGO
    size = plan["disk_sectors"] - start - 64
    if size > 0:
        derived_parts.append(("userdata", start, size))

with open(os.path.join(work, "plan.tsv"), "w") as f:
    for e in plan["entries"]:
        f.write(f"{e['kind']}\t{e['name']}\t{e['offset']}\t{e['size']}\t{e['source'] or '-'}\n")
    for name, start, size in derived_parts:
        f.write(f"partition\t{name}\t{start * 512}\t{size * 512}\t-\n")

with open(os.path.join(work, "derived.json"), "w") as f:
    json.dump([{"name": n, "start": s, "size": z} for n, s, z in derived_parts], f)
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
# 26 записей по 128 байт = 3328 байт = 6.5 сектора, то есть LBA 2..8.
# С boot0 на секторе 16 помещается до (16-2)*4 = 56 записей.
MAX_ENTRIES=$(( (BOOT0_SECTOR - 2) * 512 / 128 ))
# +1: userdata в plan.tsv нет (в MBR у UDISK размер 0), его добавляет
# генератор ниже.
# +2: userdata и boot-resource появляются только в plan.tsv, в MBR их нет.
# plan.tsv уже содержит userdata и boot-resource (их дописывает генератор
# выше), поэтому считаем все partition-строки как есть.
ENTRIES_COUNT=$(awk -F'\t' '$1=="partition"{n++} END{print n+0}' "$WORK/plan.tsv")
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
for e in plan["entries"]:
    if e["kind"] != "partition" or e["size"] <= 0:
        continue
    args += ["--part", "%s:%d:%d" % (e["name"], e["offset"] // 512, e["size"] // 512)]

# Те же derived-разделы, что и в plan.tsv: иначе GPT и запись расходятся.
derived = json.load(open(os.path.join(work, "derived.json")))
for d in derived:
    args += ["--part", "%s:%d:%d" % (d["name"], d["start"], d["size"])]
    print("  %s: %d + %d секторов" % (d["name"], d["start"], d["size"]))
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

# super.fex в прошивке — Android sparse image, а в разделе на карте Android
# ждёт обычный (raw) образ: init читает LP-геометрию по смещению 4096, а там
# у sparse лежит его собственный заголовок, и загрузка падает с
# "liblp: invalid geometry magic signature". PhoenixCard разворачивает его при
# записи, поэтому делаем то же.
prepare_source() { # prepare_source <file> -> печатает путь к пригодному файлу
    local f="$1"
    local magic
    magic=$(head -c 4 "$f" | od -An -t x1 | tr -d ' \n')
    if [[ "$magic" == "3aff26ed" ]]; then
        local out="${f%.*}.raw"
        if [[ ! -f "$out" ]]; then
            python3 "$REPO_DIR/tools/sparse.py" unsparse "$f" "$out" >/dev/null \
                || die "не удалось развернуть $f"
        fi
        printf '%s\n' "$out"
    else
        printf '%s\n' "$f"
    fi
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
    read_magic() { # read_magic <offset> <count> -> hex
        dd if="$DEV" bs=1 iflag=skip_bytes,count_bytes skip="$1" count="$2" \
           status=none | od -An -t x1 | tr -d ' \n'
    }

    while IFS=$'\t' read -r kind name off size src; do
        case "$name" in
            metadata)
                if [[ "$(read_magic $(( off + 1080 )) 2)" == "53ef" ]]; then ok "metadata: ext4"
                else printf '\033[31m  FAIL metadata: не ext4\033[0m\n'; fail=$((fail+1)); fi
                continue
                ;;
            media_data)
                # FAT32: строка "FAT32" по смещению 82 в загрузочном секторе
                if [[ "$(read_magic $(( off + 82 )) 5)" == "4641543332" ]]; then ok "media_data: FAT32"
                else printf '\033[31m  FAIL media_data: не FAT32\033[0m\n'; fail=$((fail+1)); fi
                continue
                ;;
            userdata)
                # f2fs superblock: magic 0xF2F52010 по смещению 1024
                if [[ "$(read_magic $(( off + 1024 )) 4)" == "1020f5f2" ]]; then ok "userdata: f2fs"
                else printf '\033[31m  FAIL userdata: не f2fs\033[0m\n'; fail=$((fail+1)); fi
                continue
                ;;
            boot-resource)
                # раздел должен быть читаемым FAT с нашим логотипом
                if dd if="$DEV" bs=1M iflag=skip_bytes,count_bytes skip="$off" \
                        count="$size" status=none > "$WORK/br-check.fex" 2>/dev/null \
                   && mdir -i "$WORK/br-check.fex" ::bootlogo.bmp >/dev/null 2>&1; then
                    ok "boot-resource: FAT + bootlogo.bmp"
                else
                    printf '\033[31m  FAIL boot-resource: FAT/логотип\033[0m\n'; fail=$((fail+1))
                fi
                continue
                ;;
        esac
        [[ "$src" == "-" ]] && continue
        extract "$src" "$WORK/$src"
        verify_at "$off" "$(prepare_source "$WORK/$src")" "$name"
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

# Разделы, которых нет в образе, но без которых Android не стартует или
# которые нужны загрузчику. Содержимое создаётся здесь.
derived() { # derived <name> <size> -> печатает путь к файлу
    local name="$1" size="$2" out="$WORK/derived-$1.img"
    case "$name" in
        boot-resource)
            # u-boot читает bootlogo.bmp именно из раздела с этим именем. В образе лежит
            # усечённый FAT (заявляет 128 МиБ при файле 5.6 МБ), который
            # u-boot не принимает: "Unrecognized filesystem type".
            if [[ ! -f "$out" ]]; then
                truncate -s "$size" "$out"
                mkfs.vfat -F 16 -n BOOTLOGO "$out" >/dev/null 2>&1 \
                    || die "mkfs.vfat для boot-resource не удался"
                if [[ -f "$REPO_DIR/vendor/pulsaros/boot-logo/bootlogo.bmp" ]]; then
                    mcopy -i "$out" "$REPO_DIR/vendor/pulsaros/boot-logo/bootlogo.bmp" ::bootlogo.bmp \
                        || die "не удалось положить bootlogo.bmp"
                else
                    warn "bootlogo.bmp не найден — раздел останется пустым"
                fi
            fi
            ;;
        metadata)
            if [[ ! -f "$out" ]]; then
                truncate -s "$size" "$out"
                mkfs.ext4 -q -F "$out" >/dev/null 2>&1 || die "mkfs.ext4 для metadata не удался"
            fi
            ;;
        media_data)
            # fstab монтирует его как vfat; пустой раздел даёт
            # "FAT-fs: invalid media value".
            if [[ ! -f "$out" ]]; then
                truncate -s "$size" "$out"
                mkfs.vfat -F 32 -n OEM "$out" >/dev/null 2>&1 || die "mkfs.vfat для media_data не удался"
            fi
            ;;
        userdata)
            # Android форматирует /data сам, но в этом образе он этого не
            # делает и credstore падает с "No such file or directory".
            # Готовим f2fs заранее; файл разреженный, на карту уйдут только
            # занятые блоки (см. tools/writeimg.py).
            if [[ ! -f "$out" ]]; then
                truncate -s "$size" "$out"
                mkfs.f2fs -q -f "$out" >/dev/null 2>&1 || die "mkfs.f2fs для userdata не удался"
            fi
            ;;
        *)
            return 1
            ;;
    esac
    printf '%s\n' "$out"
}

while IFS=$'\t' read -r kind name off size src; do
    [[ "$kind" == "partition" ]] || continue

    if out=$(derived "$name" "$size"); then
        case "$name" in
            userdata)
                # только занятые блоки, иначе 56 ГБ по USB 2.0
                python3 "$REPO_DIR/tools/writeimg.py" "$out" "$DEV" "$off" \
                    || die "запись userdata не удалась"
                ok "$name → $off (f2fs, только занятые блоки)"
                ;;
            *)
                wr "$out" "$off" "$name"
                ;;
        esac
        continue
    fi

    [[ "$src" == "-" ]] && continue
    extract "$src" "$WORK/$src"
    wr "$(prepare_source "$WORK/$src")" "$off" "$name"
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