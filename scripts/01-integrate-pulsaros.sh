#!/usr/bin/env bash
# 01-integrate-pulsaros.sh
# Integrate PulsarOS customizations into BSP build system.
# Run BEFORE Android build (make).
# This adds our APKs, configs, boot animation, debloat into the BSP.

set -euo pipefail

BSP="${BSP:-/mnt/BF/H618-Android12-Src}"
REPO="/home/one/GitHub/PulsarOS"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "═══ PulsarOS: Integrate into BSP ═══"
echo "BSP: ${BSP}"

# ── 1. Copy APKs to BSP prebuilt ──
PREBUILT="${BSP}/vendor/pulsaros/prebuilt/apk"
mkdir -p "${PREBUILT}"
for apk in RetroArch.apk Daijishou.apk Kodi.apk TVBro.apk; do
    if [[ -f "${REPO}/vendor/pulsaros/prebuilt/apk/${apk}" ]]; then
        cp "${REPO}/vendor/pulsaros/prebuilt/apk/${apk}" "${PREBUILT}/"
        ok "APK: ${apk}"
    else
        warn "APK not found: ${apk}"
    fi
done

# ── 2. Copy libretro cores ──
CORES_SRC="${REPO}/vendor/pulsaros/prebuilt/cores"
CORES_DST="${BSP}/vendor/pulsaros/prebuilt/cores"
mkdir -p "${CORES_DST}"
if [[ -d "${CORES_SRC}" ]]; then
    cp "${CORES_SRC}"/*.so "${CORES_DST}/" 2>/dev/null
    ok "Cores: $(ls "${CORES_DST}"/*.so 2>/dev/null | wc -l) files"
else
    warn "Cores directory not found"
fi

# ── 3. Copy configs ──
CONFIGS="${REPO}/vendor/pulsaros/config"
mkdir -p "${BSP}/vendor/pulsaros/config/retroarch"
mkdir -p "${BSP}/vendor/pulsaros/config/daijishou"
cp "${CONFIGS}/retroarch/retroarch.cfg" "${BSP}/vendor/pulsaros/config/retroarch/" 2>/dev/null
cp "${CONFIGS}/retroarch/cores-whitelist.txt" "${BSP}/vendor/pulsaros/config/retroarch/" 2>/dev/null
cp "${CONFIGS}/daijishou/platforms.json" "${BSP}/vendor/pulsaros/config/daijishou/" 2>/dev/null
ok "Configs copied"

# ── 4. Copy boot animation ──
mkdir -p "${BSP}/vendor/pulsaros/bootanimation"
cp "${REPO}/vendor/pulsaros/bootanimation/bootanimation.zip" "${BSP}/vendor/pulsaros/bootanimation/" 2>/dev/null
ok "Boot animation copied"

# ── 5. Copy pulsaros-vendor.mk ──
cp "${REPO}/vendor/pulsaros/pulsaros-vendor.mk" "${BSP}/vendor/pulsaros/pulsaros-vendor.mk"
ok "pulsaros-vendor.mk"

# ── 6. Copy debloat.mk ──
cp "${REPO}/vendor/pulsaros/debloat.mk" "${BSP}/vendor/pulsaros/" 2>/dev/null
ok "Debloat config"

# ── 7. Add pulsaros-vendor to apollo_p2.mk ──
APOLLO_P2="${BSP}/device/softwinner/apollo/apollo_p2.mk"
if [[ -f "${APOLLO_P2}" ]]; then
    if ! grep -q "pulsaros-vendor" "${APOLLO_P2}" 2>/dev/null; then
        echo "" >> "${APOLLO_P2}"
        echo "# ── PulsarOS Customizations ──" >> "${APOLLO_P2}"
        echo "\$(call inherit-product, vendor/pulsaros/pulsaros-vendor.mk)" >> "${APOLLO_P2}"
        ok "pulsaros-vendor.mk added to apollo_p2.mk"
    else
        ok "pulsaros-vendor.mk already in apollo_p2.mk"
    fi
else
    warn "apollo_p2.mk not found at ${APOLLO_P2}"
fi

echo ""
echo "═══ Integration complete ═══"
echo "Next: source build/envsetup.sh && lunch apollo_p2-userdebug && make -j8"
echo ""
echo "Note: Run 00-apply-minimal-patches.sh FIRST if starting from clean BSP."
