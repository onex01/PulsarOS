#!/usr/bin/env bash
# =============================================================================
#  verify-image.sh — проверить собранный образ PulsarOS без прошивки
#
#  Проверяет то, что обычно выясняется только после загрузки: структуру
#  IMAGEWTY, наличие наших файлов в разделах, целостность ext4.
#
#  Использование: sudo scripts/verify-image.sh out/PulsarOS-20261107.img
#  Ничего не пишет в образ.
# =============================================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG="${1:?usage: sudo $0 <image.img>}"
TMP="$REPO_DIR/work/verify-run"

[[ -f "$IMG" ]] || { echo "нет файла: $IMG" >&2; exit 2; }
[[ $EUID -eq 0 ]] || { echo "нужен root" >&2; exit 2; }

PASS=0; FAIL=0
declare -a PROBLEMS=()
check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf '  [ ok ] %s\n' "$desc"; PASS=$((PASS+1))
    else
        printf '  [FAIL] %s\n' "$desc"; FAIL=$((FAIL+1)); PROBLEMS+=("$desc")
    fi
}

rm -rf "$TMP"; mkdir -p "$TMP"

echo "== структура образа"
check "заголовок IMAGEWTY" bash -c "head -c8 '$IMG' | grep -q IMAGEWTY"
check "subversion 0x60 (PhoenixCard)" python3 -c "
import struct,sys
h=open('$IMG','rb').read(96)
sys.exit(0 if struct.unpack_from('<I',h,0xC)[0]==0x60 else 1)"
check "размер в заголовке совпадает" python3 -c "
import struct,os,sys
h=open('$IMG','rb').read(96)
sys.exit(0 if struct.unpack_from('<I',h,0x18)[0]==os.path.getsize('$IMG') else 1)"

echo "== секции"
python3 "$REPO_DIR/tools/imagewty.py" extract "$IMG" super.fex "$TMP/super.sparse" >/dev/null \
    && echo "  super.fex извлечён" || { echo "  [FAIL] super.fex"; FAIL=$((FAIL+1)); }
python3 "$REPO_DIR/tools/sparse.py" unsparse "$TMP/super.sparse" "$TMP/super.raw" >/dev/null \
    && echo "  sparse развёрнут" || echo "  (не sparse, читаю как есть)" 
[[ -f "$TMP/super.raw" ]] || cp "$TMP/super.sparse" "$TMP/super.raw"

python3 "$REPO_DIR/tools/lpunpack.py" extract-all "$TMP/super.raw" "$TMP/parts" >/dev/null

echo "== разделы"
for p in system_a vendor_a product_a vendor_dlkm_a; do
    check "$p извлечён" test -f "$TMP/parts/$p.img"
    check "$p: ext4 цел" e2fsck -fn "$TMP/parts/$p.img"
done

echo "== содержимое system_a"
M="$TMP/mnt"
mkdir -p "$M"
if mount -o ro,loop "$TMP/parts/system_a.img" "$M" 2>/dev/null; then
    check "Daijishou.apk" test -f "$M/system/app/Daijishou/Daijishou.apk"
    check "RetroArch.apk" test -f "$M/system/app/RetroArch/RetroArch.apk"
    NCORES=$(ls "$M/system/etc/pulsaros/cores"/*.so 2>/dev/null | wc -l)
    echo "     ядер libretro: $NCORES"
    check "ядра >= 20" bash -c "[[ $NCORES -ge 20 ]]"
    NKL=$(ls "$M/system/usr/keylayout"/*.kl 2>/dev/null | wc -l)
    echo "     раскладок геймпадов: $NKL"
    check "раскладки >= 186" bash -c "[[ $NKL -ge 186 ]]"
    check "Joy-Con L" test -f "$M/system/usr/keylayout/Vendor_057e_Product_2006.kl"
    check "Joy-Con R" test -f "$M/system/usr/keylayout/Vendor_057e_Product_2007.kl"
    check "build.prop на месте" test -f "$M/system/build.prop"
    check "TvLauncher на месте" test -d "$M/system/priv-app/TvLauncher"
    umount "$M"
else
    echo "  [FAIL] не удалось смонтировать system_a"
    FAIL=$((FAIL+1)); PROBLEMS+=("mount system_a")
fi
rmdir "$M" 2>/dev/null || true

echo
echo "== итог: $PASS ok, $FAIL fail"
if [[ $FAIL -gt 0 ]]; then
    printf '   проблема: %s\n' "${PROBLEMS[@]}"
    exit 1
fi
echo "== образ структурно корректен (загрузка проверяется только на железе)"
rm -rf "$TMP"