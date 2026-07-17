#!/usr/bin/env bash
# 00-full-rebuild.sh
# Complete PulsarOS build from clean BSP.
# Run after: 00-apply-minimal-patches.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BSP="${BSP:-/mnt/BF/H618-Android12-Src}"
LONGAN="${BSP}/longan"
IMGREPACKER="${REPO_DIR}/tools/bin/imgrepacker"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "═══ PulsarOS Full Rebuild ═══"
echo "BSP: ${BSP}"
echo "imgRePacker: ${IMGREPACKER}"
echo ""

# ── Step 1: Longan build ──
echo "── Step 1: Longan build (kernel + brandy) ──"
cd "${LONGAN}"
[[ -f "build.sh" ]] || err "longan/build.sh not found"

# Fix spl symlink
[[ -d "brandy/brandy-2.0/spl-pub" ]] && [[ ! -e "brandy/brandy-2.0/spl" ]] && \
    ln -s spl-pub brandy/brandy-2.0/spl

# Build
echo "Running: cd ${LONGAN} && ./build.sh"
echo "NOTE: This must run in a REAL TERMINAL (not via script/tee)"
echo "After longan build completes, run this script again for Step 2."
echo ""
echo "Press Enter when longan build is complete..."
read

# ── Step 2: Android build ──
echo "── Step 2: Android build ──"
cd "${BSP}"
export USE_CCACHE=false
bash -c "source build/envsetup.sh && lunch apollo_p2-userdebug && make -j12"
ok "Android build complete"

# ── Step 3: Pack + imgRePacker ──
echo "── Step 3: Pack + imgRePacker ──"
cd "${LONGAN}/build"

# Restore prebuilt firmware
BIN_DIR="${LONGAN}/device/config/chips/h618/bin"
PLAT_OUT="${LONGAN}/out/h618/p2/android"
for fw in boot0_sdcard_sun50iw9p1.bin u-boot-sun50iw9p1.bin sboot_sun50iw9p1.bin fes1_sun50iw9p1.bin; do
    [[ -f "${BIN_DIR}/${fw}" ]] && cp "${BIN_DIR}/${fw}" "${PLAT_OUT}/${fw}" 2>/dev/null
done

# Fix pack: cp instead of symlinks
grep -q 'ln -sf ${link_real}/${img_name} ${fex_name}' pack 2>/dev/null && \
    sed -i 's|ln -sf ${link_real}/${img_name} ${fex_name}|cp ${link_real}/${img_name} ${fex_name}|' pack

# Sync Android images to longan/out
PRODUCT_OUT=""
for d in "${BSP}/out/target/product/"*/; do
    [[ -f "${d}boot.img" ]] && PRODUCT_OUT="${d}" && break
done
[[ -z "${PRODUCT_OUT}" ]] && err "Product output not found"

for img in "${PRODUCT_OUT}"/*.img; do
    [[ -f "${img}" ]] && cp "${img}" "${PLAT_OUT}/$(basename "${img}")" 2>/dev/null
done

# Run pack
export PATH="/usr/sbin:${PATH}"
export ANDROID_IMAGE_OUT="${PRODUCT_OUT}"
set +u
./pack -i h618 -c sun50iw9p1 -p android -b p2 -d uart0 --key_path "${BSP}/vendor/security/toc_keys" 2>&1
set -u

# Find pack output
PACK_IMG=""
for p in "h618_android_p2_uart0.img" "h618_android12_p2_uart0.img"; do
    [[ -f "${LONGAN}/out/${p}" ]] && PACK_IMG="${LONGAN}/out/${p}" && break
done
[[ -z "${PACK_IMG}" ]] && err "Pack output not found"

# ── Step 4: imgRePacker conversion ──
echo "── Step 4: imgRePacker conversion ──"
if [[ -x "${IMGREPACKER}" ]]; then
    WORK_IMG="${REPO_DIR}/out/.imgrepacker_work.img"
    mkdir -p "${REPO_DIR}/out"
    cp "${PACK_IMG}" "${WORK_IMG}"
    
    rm -rf "${WORK_IMG}.dump"
    cd "$(dirname "${WORK_IMG}")"
    "${IMGREPACKER}" "$(basename "${WORK_IMG}")" 2>&1 | tail -3
    
    if [[ -d "${WORK_IMG}.dump" ]]; then
        cd "$(dirname "${WORK_IMG}.dump")"
        "${IMGREPACKER}" "$(basename "${WORK_IMG}.dump")" 2>&1 | tail -3
        
        DATE=$(date +%Y-%m-%d)
        OUTPUT="${REPO_DIR}/out/PulsarOS-OPiZero3-Android12-${DATE}.img"
        FINAL="${WORK_IMG}"
        if [[ -f "${FINAL}" ]]; then
            cp "${FINAL}" "${OUTPUT}"
            md5sum "${OUTPUT}" > "${OUTPUT}.md5"
            ok "IMAGEWTY: ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
            rm -rf "${WORK_IMG}" "${WORK_IMG}.dump"
        fi
    else
        cp "${PACK_IMG}" "${REPO_DIR}/out/PulsarOS-OPiZero3-Android12-$(date +%Y-%m-%d).img"
        warn "imgRePacker unpack failed, using dragon output"
    fi
else
    warn "imgRePacker not found, using dragon output"
    cp "${PACK_IMG}" "${REPO_DIR}/out/PulsarOS-OPiZero3-Android12-$(date +%Y-%m-%d).img"
fi

echo ""
echo "═══ Build complete ═══"
echo "Flash via PhoenixCard (Product/Develop mode)"
