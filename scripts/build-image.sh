#!/usr/bin/env bash
# =============================================================================
#  build-image.sh — пересобрать прошивку PulsarOS из стокового образа
#
#  Пайплайн:
#    1. достать секции из IMAGEWTY
#    2. развернуть super.fex (sparse) и вынуть логические разделы
#    3. расширить system/product (место внутри super уже есть)
#    4. влить overlay: APK, ядра libretro, раскладки геймпадов
#    5. собрать super заново
#    6. сжать в sparse и подменить в IMAGEWTY со сдвигом секций
#
#  Использование:
#    scripts/build-image.sh [--stock <img>] [--out <img>] [--no-apk] [--no-cores]
#
#  Ничего не пишет в стоковый образ. Результат: out/PulsarOS-<дата>.img
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STOCK="${PULSAR_STOCK:-$HOME/Github/tmp/OrangePi_Zero3_Android12_v1.0/OrangePi_Zero3_Android12_v1.0.img}"
OUT=""
WITH_APK=1
WITH_CORES=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stock)    STOCK="$2"; shift 2 ;;
        --out)      OUT="$2"; shift 2 ;;
        --no-apk)   WITH_APK=0; shift ;;
        --no-cores) WITH_CORES=0; shift ;;
        -h|--help)  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

WORK="$REPO_DIR/work/build"
STOCK_PARTS="$REPO_DIR/work/stock"
OUTDIR="$REPO_DIR/out"
OUT="${OUT:-$OUTDIR/PulsarOS-$(date +%Y%m%d).img}"

log()  { printf '\n\033[36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m[WARN] %s\033[0m\n' "$*" >&2; }
fail() { printf '\033[31m[FAIL] %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "нужен root: скрипт монтирует ext4-образы"
[[ -f "$STOCK" ]] || fail "нет стокового образа: $STOCK"
command -v resize2fs >/dev/null || fail "нет resize2fs"
command -v setfattr  >/dev/null || fail "нет setfattr"

mkdir -p "$WORK" "$OUTDIR" "$STOCK_PARTS"

# ── 1. Секции ───────────────────────────────────────────────────────────────
if [[ ! -f "$STOCK_PARTS/super.sparse.img" ]]; then
    log "Достаю секции из $STOCK"
    python3 "$REPO_DIR/tools/imagewty.py" extract "$STOCK" super.fex \
        "$STOCK_PARTS/super.sparse.img"
fi

# ── 2. super → raw → разделы ────────────────────────────────────────────────
if [[ ! -f "$WORK/super.raw.img" ]]; then
    log "Разворачиваю sparse"
    python3 "$REPO_DIR/tools/sparse.py" unsparse \
        "$STOCK_PARTS/super.sparse.img" "$WORK/super.raw.img"
fi

if [[ ! -f "$WORK/parts/system_a.img" ]]; then
    log "Извлекаю логические разделы"
    mkdir -p "$WORK/parts"
    python3 "$REPO_DIR/tools/lpunpack.py" extract-all "$WORK/super.raw.img" "$WORK/parts"
fi

# ── 3. Расширение разделов ──────────────────────────────────────────────────
# Свободное место есть внутри самого super (3 ГБ на карте, занято ~1.06 ГБ),
# поэтому таблицу разделов на карте трогать не нужно.
declare -A TARGET_MIB=( [system_a]=1600 [product_a]=400 )

for part in "${!TARGET_MIB[@]}"; do
    src="$WORK/parts/$part.img"
    dst="$WORK/parts/$part.big.img"
    want=$(( TARGET_MIB[$part] * 1024 * 1024 ))
    cur=$(stat -c %s "$src")
    if [[ -f "$dst" ]] && [[ $(stat -c %s "$dst") -eq $want ]]; then
        continue
    fi
    log "Расширяю $part: $((cur/1024/1024)) MiB → ${TARGET_MIB[$part]} MiB"
    cp --sparse=always "$src" "$dst"
    truncate -s "$want" "$dst"
    resize2fs "$dst" >/dev/null
    e2fsck -fn "$dst" >/dev/null 2>&1 || fail "fsck не прошёл после расширения $part"
done

# ── 4. Overlay ──────────────────────────────────────────────────────────────
log "Вливаю overlay"

# Метка, как у всех файлов в этом образе: разметки SELinux нет.
LABEL="system_u:object_r:unlabeled_t:s0"

inject_into() {
    local img="$1" name="$2"; shift 2
    local mnt="$WORK/mnt-$name"
    mkdir -p "$mnt"
    mount -o loop,rw "$img" "$mnt"
    "$@"
    sync
    umount "$mnt"
    rmdir "$mnt" 2>/dev/null || true
}

# Файлы копируются без xattr; явно ставим ту же метку, что у остальных.
place() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
    chmod 644 "$dst"
    chown 0:0 "$dst"
    setfattr -n security.selinux -v "$LABEL" "$dst" 2>/dev/null || true
}

inject_system() {
    local m="$WORK/mnt-system_a"

    if [[ $WITH_APK -eq 1 ]]; then
        place "$REPO_DIR/prebuilt/apk/Daijishou.apk"  "$m/system/app/Daijishou/Daijishou.apk"
        place "$REPO_DIR/prebuilt/apk/RetroArch.apk"  "$m/system/app/RetroArch/RetroArch.apk"
        echo "   APK: Daijishou, RetroArch"
    fi

    if [[ $WITH_CORES -eq 1 ]] && compgen -G "$REPO_DIR/prebuilt/cores/*.so" >/dev/null; then
        mkdir -p "$m/system/etc/pulsaros/cores"
        local n=0
        for so in "$REPO_DIR/prebuilt/cores"/*.so; do
            place "$so" "$m/system/etc/pulsaros/cores/$(basename "$so")"
            n=$((n + 1))
        done
        echo "   ядер: $n"
    fi

    # Раскладки геймпадов: наши дополнения поверх стоковых 186.
    if compgen -G "$REPO_DIR/overlay/system/usr/keylayout/*.kl" >/dev/null; then
        mkdir -p "$m/system/usr/keylayout"
        local k=0
        for kl in "$REPO_DIR/overlay/system/usr/keylayout"/*.kl; do
            place "$kl" "$m/system/usr/keylayout/$(basename "$kl")"
            k=$((k + 1))
        done
        echo "   раскладок: $k"
    fi

    # Своя загрузочная анимация: если в репозитории лежит
    # vendor/pulsaros/bootanimation/bootanimation.zip, он заменяет стоковый
    # /system/media/bootanimation.zip.
    local anim="$REPO_DIR/vendor/pulsaros/bootanimation/bootanimation.zip"
    if [[ -f "$anim" ]]; then
        place "$anim" "$m/system/media/bootanimation.zip"
        echo "   bootanimation: свой ($(du -h "$anim" | cut -f1))"
    fi

    # Конфиги и seed-скрипт для первого запуска.
    if [[ -d "$REPO_DIR/overlay/system/etc/pulsaros" ]]; then
        cp -a "$REPO_DIR/overlay/system/etc/pulsaros/." "$m/system/etc/pulsaros/" 2>/dev/null || true
    fi
}

inject_product() {
    local m="$WORK/mnt-product_a"
    if [[ -d "$REPO_DIR/overlay/product" ]]; then
        cp -a "$REPO_DIR/overlay/product/." "$m/" 2>/dev/null || true
    fi
}

log "system_a"
inject_into "$WORK/parts/system_a.big.img" system_a inject_system
log "product_a"
inject_into "$WORK/parts/product_a.big.img" product_a inject_product

# ── 5. Новый super ──────────────────────────────────────────────────────────
log "Собираю super"

# Стоковые раскладки берём из манифеста, который сгенерировал lpunpack.
python3 - "$WORK" <<'PY'
import json, os, sys
work = sys.argv[1]
parts = []
for name, group in [("system_a","sb_a"),("vendor_a","sb_a"),("product_a","sb_a"),
                    ("vendor_dlkm_a","sb_a"),("system_b","sb_b"),("vendor_b","sb_b"),
                    ("product_b","sb_b"),("vendor_dlkm_b","sb_b")]:
    big = os.path.join(work, "parts", f"{name}.big.img")
    plain = os.path.join(work, "parts", f"{name}.img")
    path = big if os.path.exists(big) else plain
    size = os.path.getsize(path) if os.path.exists(path) else 0
    parts.append({"name": name, "group": group,
                  "source": path if size else None,
                  "size": size, "attributes": 1})
cfg = {
    "output": os.path.join(work, "super.new.img"),
    "total_size": 3221225472,
    "logical_block_size": 4096, "sector_size": 512,
    "metadata_max_size": 65536, "metadata_slot_count": 3,
    "alignment": 1048576, "first_logical_sector": 2048,
    "block_device_name": "super",
    "groups": [{"name": "default", "maximum_size": 0},
               {"name": "sb_a", "maximum_size": 3212836864},
               {"name": "sb_b", "maximum_size": 3212836864}],
    "partitions": parts,
}
json.dump(cfg, open(os.path.join(work, "super.manifest.json"), "w"), indent=2)
PY

python3 "$REPO_DIR/tools/lpmake.py" "$WORK/super.manifest.json" || fail "lpmake"

log "Сжимаю в sparse"
python3 "$REPO_DIR/tools/sparse.py" mk "$WORK/super.new.img" "$WORK/super.new.sparse"

# ── 6. Пересборка IMAGEWTY ──────────────────────────────────────────────────
log "Пересобираю образ"
python3 "$REPO_DIR/tools/imagewty.py" repack "$STOCK" "$OUT" \
    --replace "super.fex=$WORK/super.new.sparse" >/dev/null

md5sum "$OUT" > "$OUT.md5"

log "Готово"
ls -lh "$OUT"
cat "$OUT.md5"