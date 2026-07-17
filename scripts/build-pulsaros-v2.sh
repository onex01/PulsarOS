#!/usr/bin/env bash
# build-pulsaros-v2.sh
# Build PulsarOS: stock firmware + our Android system (super.fex)
# This avoids the hardware check error1 by keeping stock boot_package.fex

set -euo pipefail

REPO="/home/one/GitHub/PulsarOS"
BSP="/mnt/BF/H618-Android12-Src"
STOCK="/home/one/opizero3_android_12_mod_malay_all_wifi.img"
IMGREPACKER="${REPO}/tools/bin/imgrepacker"
PRODUCT_OUT="${BSP}/out/target/product/apollo-p2"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "═══ PulsarOS V2 Build: Stock Firmware + Our System ═══"

# ── Step 1: Extract stock IMAGEWTY ──
echo ""
echo "── Step 1: Extract stock firmware ──"
WORK="${REPO}/out/pulsaros_v2_work"
rm -rf "${WORK}"
mkdir -p "${WORK}"

cp "${STOCK}" "${WORK}/stock.img"
cd "${WORK}"
"${IMGREPACKER}" stock.img 2>&1 | tail -3
STOCK_DUMP="${WORK}/stock.img.dump"
[[ -d "${STOCK_DUMP}" ]] || err "Stock extraction failed"
ok "Stock: $(ls "${STOCK_DUMP}"/*.fex 2>/dev/null | wc -l) sections"

# ── Step 2: Replace super.fex with our build ──
echo ""
echo "── Step 2: Replace super.fex ──"
OUR_SUPER="${PRODUCT_OUT}/super.img"
if [[ -f "${OUR_SUPER}" ]]; then
    cp "${OUR_SUPER}" "${STOCK_DUMP}/super.fex"
    ok "super.fex replaced ($(du -h "${OUR_SUPER}" | cut -f1))"
else
    err "super.img not found at ${OUR_SUPER}"
fi

# ── Step 3: Replace boot.fex with our build (if smaller) ──
echo ""
echo "── Step 3: Replace boot.fex ──"
OUR_BOOT="${PRODUCT_OUT}/boot.img"
STOCK_BOOT_SIZE=$(stat -c%s "${STOCK_DUMP}/boot.fex")
OUR_BOOT_SIZE=$(stat -c%s "${OUR_BOOT}")

if [[ ${OUR_BOOT_SIZE} -le ${STOCK_BOOT_SIZE} ]]; then
    cp "${OUR_BOOT}" "${STOCK_DUMP}/boot.fex"
    ok "boot.fex replaced ($(du -h "${OUR_BOOT}" | cut -f1))"
else
    warn "Our boot.img (${OUR_BOOT_SIZE}) larger than stock (${STOCK_BOOT_SIZE}), keeping stock"
fi

# ── Step 4: Replace vendor_boot.fex with our build (if smaller) ──
echo ""
echo "── Step 4: Replace vendor_boot.fex ──"
OUR_VB="${PRODUCT_OUT}/vendor_boot.img"
if [[ -f "${OUR_VB}" ]]; then
    STOCK_VB_SIZE=$(stat -c%s "${STOCK_DUMP}/vendor_boot.fex")
    OUR_VB_SIZE=$(stat -c%s "${OUR_VB}")
    if [[ ${OUR_VB_SIZE} -le ${STOCK_VB_SIZE} ]]; then
        cp "${OUR_VB}" "${STOCK_DUMP}/vendor_boot.fex"
        ok "vendor_boot.fex replaced ($(du -h "${OUR_VB}" | cut -f1))"
    else
        warn "Our vendor_boot.img larger, keeping stock"
    fi
fi

# ── Step 5: Replace dtbo.fex with our build ──
echo ""
echo "── Step 5: Replace dtbo.fex ──"
OUR_DTBO="${PRODUCT_OUT}/dtbo.img"
if [[ -f "${OUR_DTBO}" ]]; then
    cp "${OUR_DTBO}" "${STOCK_DUMP}/dtbo.fex"
    ok "dtbo.fex replaced"
fi

# ── Step 6: Replace boot animation ──
echo ""
echo "── Step 6: Replace boot animation ──"
OUR_BA="${REPO}/vendor/pulsaros/bootanimation/bootanimation.zip"
if [[ -f "${OUR_BA}" ]]; then
    # boot-resource.fex is a FAT16 image — we can't easily modify it
    # But we can replace it if our build has a different one
    # For now, keep stock boot-resource.fex (has correct bootlogo)
    warn "Keeping stock boot-resource.fex (FAT16, can't easily modify)"
fi

# ── Step 7: Repack with imgRePacker ──
echo ""
echo "── Step 7: Repack IMAGEWTY ──"
# Create a new dump dir name for repacking
REPACK_DIR="${WORK}/pulsaros_v2.dump"
rm -rf "${REPACK_DIR}"
cp -a "${STOCK_DUMP}" "${REPACK_DIR}"

# Remove old image to prevent overwrite
rm -f "${WORK}/pulsaros_v2"

cd "${WORK}"
"${IMGREPACKER}" pulsaros_v2.dump 2>&1 | tail -3

# ── Step 8: Copy to output ──
echo ""
echo "── Step 8: Copy to output ──"
DATE=$(date +%Y-%m-%d)
OUTPUT="${REPO}/out/PulsarOS-V2-OPiZero3-Android12-${DATE}.img"
mkdir -p "${REPO}/out"

if [[ -f "${WORK}/pulsaros_v2" ]]; then
    cp "${WORK}/pulsaros_v2" "${OUTPUT}"
    md5sum "${OUTPUT}" > "${OUTPUT}.md5"
    ok "IMAGEWTY: ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
    ok "MD5: $(awk '{print $1}' "${OUTPUT}.md5")"
else
    err "Repack failed"
fi

# Cleanup
rm -rf "${WORK}"

echo ""
echo "═══ Build complete ═══"
echo "Flash: sudo ${REPO}/scripts/flash-sdcard.sh ${OUTPUT} /dev/sdX"
echo ""
echo "What's new vs stock:"
echo "  ✅ RetroArch + 24 cores"
echo "  ✅ Daijishou launcher"
echo "  ✅ Kodi media center"
echo "  ✅ TV Bro browser"
echo "  ✅ RetroArch config (gamepad profiles)"
echo "  ✅ Daijishou config (28 systems)"
echo "  ✅ SSH (dropbear)"
echo "  ✅ Debloat (no Google bloatware)"
echo "  Stock firmware (boot_package, BL3-1, DTB) preserved"
