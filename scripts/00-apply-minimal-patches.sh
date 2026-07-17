#!/usr/bin/env bash
# 00-apply-minimal-patches.sh
# Apply ONLY the minimal patches needed for clean BSP build.
# Run this AFTER copying OriginalVersion to H618-Android12-Src.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BSP="${BSP:-/mnt/BF/H618-Android12-Src}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "═══ PulsarOS: Minimal BSP Patches ═══"
echo "BSP: ${BSP}"

[[ -d "${BSP}" ]] || { echo "BSP not found: ${BSP}"; exit 1; }

# ── Patch 1: Disable AVB ──
BCFG="${BSP}/device/softwinner/apollo/BoardConfig.mk"
if grep -q "BOARD_AVB_ENABLE.*:= true" "${BCFG}" 2>/dev/null; then
    sed -i 's/BOARD_AVB_ENABLE.*:= true/BOARD_AVB_ENABLE := false/' "${BCFG}"
    ok "AVB disabled in BoardConfig.mk"
elif grep -q "BOARD_AVB_ENABLE.*:= false" "${BCFG}" 2>/dev/null; then
    ok "AVB already disabled"
else
    echo "BOARD_AVB_ENABLE := false" >> "${BCFG}"
    ok "AVB disabled (appended)"
fi

# ── Patch 2: Disable RECOVERY_AS_BOOT ──
if grep -q "BOARD_USES_RECOVERY_AS_BOOT.*:= true" "${BCFG}" 2>/dev/null; then
    sed -i 's/BOARD_USES_RECOVERY_AS_BOOT.*:= true/BOARD_USES_RECOVERY_AS_BOOT := false/' "${BCFG}"
    ok "RECOVERY_AS_BOOT disabled"
elif grep -q "BOARD_USES_RECOVERY_AS_BOOT.*:= false" "${BCFG}" 2>/dev/null; then
    ok "RECOVERY_AS_BOOT already disabled"
else
    echo "BOARD_USES_RECOVERY_AS_BOOT := false" >> "${BCFG}"
    ok "RECOVERY_AS_BOOT disabled (appended)"
fi

# ── Patch 3: Enable 64-bit binder for 32-bit userspace ──
if ! grep -q "TARGET_USES_64_BIT_BINDER" "${BCFG}" 2>/dev/null; then
    echo "TARGET_USES_64_BIT_BINDER := true" >> "${BCFG}"
    ok "64-bit binder enabled"
else
    ok "64-bit binder already set"
fi

# ── Patch 4: Fix brandy spl symlink ──
BRANDY="${BSP}/longan/brandy/brandy-2.0"
if [[ -d "${BRANDY}/spl-pub" ]] && [[ ! -e "${BRANDY}/spl" ]]; then
    ln -s spl-pub "${BRANDY}/spl"
    ok "brandy spl symlink created"
elif [[ -e "${BRANDY}/spl" ]]; then
    ok "brandy spl symlink already exists"
else
    warn "brandy spl-pub not found (may not be needed)"
fi

# ── Patch 5: Create PulsarOS product overlay ──
# Minimal device tree for PulsarOS (uses apollo_p2 lunch target)
if [[ ! -d "${BSP}/device/softwinner/zero3" ]]; then
    mkdir -p "${BSP}/device/softwinner/zero3"
    warn "Created empty zero3 device dir — will use apollo_p2 product"
fi

echo ""
echo "═══ Patches applied ═══"
echo "Next: cd ${BSP}/longan && ./build.sh"
