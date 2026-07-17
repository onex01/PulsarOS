#!/usr/bin/env bash
# 00-prepare-bsp.sh
# Full BSP preparation: patches + PulsarOS integration.
# Run from clean BSP before Android build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "═══ PulsarOS: Full BSP Preparation ═══"

# Step 1: Apply minimal patches (AVB, RECOVERY_AS_BOOT, binder)
echo ""
echo "── Step 1: Minimal patches ──"
bash "${SCRIPT_DIR}/00-apply-minimal-patches.sh"

# Step 2: Integrate PulsarOS (APKs, configs, boot animation)
echo ""
echo "── Step 2: PulsarOS integration ──"
bash "${SCRIPT_DIR}/01-integrate-pulsaros.sh"

echo ""
echo "═══ BSP Ready ═══"
echo "Next: cd /mnt/BF/H618-Android12-Src"
echo "      source build/envsetup.sh"
echo "      lunch apollo_p2-userdebug"
echo "      make -j8"
echo "      pack"
