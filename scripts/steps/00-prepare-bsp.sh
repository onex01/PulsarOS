#!/usr/bin/env bash
# Step 0: Prepare BSP — patches + PulsarOS integration
# Runs BEFORE Android build. Modifies BSP in-place.

step_prepare_bsp() {
    echo -e "\n${BOLD}═══ Подготовка BSP ═══${NC}\n"

    if [[ -z "${ANDROID_SRC:-}" ]] || [[ ! -d "${ANDROID_SRC}" ]]; then
        msg_error "ANDROID_SRC не задан"
        return 1
    fi

    local BSP="${ANDROID_SRC}"

    # ── 1. Apply minimal patches ──
    msg_info "Применение патчей..."
    local BCFG="${BSP}/device/softwinner/apollo/BoardConfig.mk"

    # AVB — enabled for production
    if grep -q "BOARD_AVB_ENABLE.*:= false" "${BCFG}" 2>/dev/null; then
        sed -i 's/BOARD_AVB_ENABLE.*:= false/BOARD_AVB_ENABLE := true/' "${BCFG}"
        msg_ok "AVB enabled"
    fi

    # RECOVERY_AS_BOOT — false for 32MB boot partition
    if grep -q "BOARD_USES_RECOVERY_AS_BOOT.*:= true" "${BCFG}" 2>/dev/null; then
        sed -i 's/BOARD_USES_RECOVERY_AS_BOOT.*:= true/BOARD_USES_RECOVERY_AS_BOOT := false/' "${BCFG}"
        msg_ok "RECOVERY_AS_BOOT disabled"
    fi

    # 64-bit binder for 32-bit userspace
    grep -q "TARGET_USES_64_BIT_BINDER" "${BCFG}" 2>/dev/null || \
        echo "TARGET_USES_64_BIT_BINDER := true" >> "${BCFG}"

    # Boot header version 0 (Allwinner mkbootimg only supports v0-v2)
    if grep -q "BOARD_BOOT_HEADER_VERSION := 3" "${BCFG}" 2>/dev/null; then
        sed -i 's/BOARD_BOOT_HEADER_VERSION := 3/BOARD_BOOT_HEADER_VERSION := 0/' "${BCFG}"
        sed -i 's/BOARD_BOOT_HEADER_VERSION ?= 3/BOARD_BOOT_HEADER_VERSION ?= 0/' "${BCFG}"
        msg_ok "Boot header version set to 0 (Allwinner format)"
    fi

    # Brandy spl symlink
    local BRANDY="${BSP}/longan/brandy/brandy-2.0"
    [[ -d "${BRANDY}/spl-pub" ]] && [[ ! -e "${BRANDY}/spl" ]] && \
        ln -s spl-pub "${BRANDY}/spl" 2>/dev/null

    # U-Boot console: ttyS0 → ttyAS0 (Allwinner UART driver)
    local SUNXI_H="${BSP}/longan/brandy/brandy-2.0/u-boot-2018/include/configs/sunxi-common.h"
    if grep -q "console=ttyS0" "${SUNXI_H}" 2>/dev/null; then
        sed -i 's/console=ttyS0,115200/console=ttyAS0,115200/' "${SUNXI_H}"
        msg_ok "U-Boot console: ttyAS0 patched"
    fi

    # Remove vendor_boot from sys_partition.fex (our build doesn't produce vendor_boot.img)
    local SYS_PART="${BSP}/longan/device/config/chips/h618/configs/p2/android/sys_partition.fex"
    if [[ -f "${SYS_PART}" ]] && grep -q "vendor_boot" "${SYS_PART}" 2>/dev/null; then
        python3 -c "
import re
with open('${SYS_PART}') as f: c = f.read()
c = re.sub(r'\[partition\]\s*\n\s*name\s*=\s*vendor_boot.*?(?=\n\[partition\]|\n\[partition_start\]|\Z)', '', c, flags=re.DOTALL)
with open('${SYS_PART}', 'w') as f: f.write(c)
"
        msg_ok "vendor_boot removed from sys_partition.fex"
    fi

    # Create dummy vendor_boot.fex if not present (pack needs it)
    local DEFAULT_DIR="${BSP}/longan/device/config/chips/h618/configs/default"
    if [[ ! -f "${DEFAULT_DIR}/vendor_boot.fex" ]]; then
        dd if=/dev/zero of="${DEFAULT_DIR}/vendor_boot.fex" bs=1M count=32 2>/dev/null
        msg_ok "dummy vendor_boot.fex created (32MB zeros)"
    fi

    # ── 2. Integrate PulsarOS customizations ──
    msg_info "Интеграция PulsarOS..."

    # APKs
    local APK_DIR="${BSP}/vendor/pulsaros/prebuilt/apk"
    mkdir -p "${APK_DIR}"
    for apk in RetroArch.apk Daijishou.apk Kodi.apk TVBro.apk F-Droid.apk; do
        [[ -f "${REPO_DIR}/vendor/pulsaros/prebuilt/apk/${apk}" ]] && \
            cp "${REPO_DIR}/vendor/pulsaros/prebuilt/apk/${apk}" "${APK_DIR}/"
    done

    # Libretro cores
    local CORES_DIR="${BSP}/vendor/pulsaros/prebuilt/cores"
    mkdir -p "${CORES_DIR}"
    [[ -d "${REPO_DIR}/vendor/pulsaros/prebuilt/cores" ]] && \
        cp "${REPO_DIR}/vendor/pulsaros/prebuilt/cores/"*.so "${CORES_DIR}/" 2>/dev/null

    # Configs
    mkdir -p "${BSP}/vendor/pulsaros/config/retroarch"
    mkdir -p "${BSP}/vendor/pulsaros/config/daijishou"
    cp "${REPO_DIR}/vendor/pulsaros/config/retroarch/"* "${BSP}/vendor/pulsaros/config/retroarch/" 2>/dev/null
    cp "${REPO_DIR}/vendor/pulsaros/config/daijishou/"* "${BSP}/vendor/pulsaros/config/daijishou/" 2>/dev/null

    # Boot animation
    mkdir -p "${BSP}/device/softwinner/apollo/common/media/bootanimation"
    cp "${REPO_DIR}/vendor/pulsaros/bootanimation/bootanimation.zip" \
       "${BSP}/device/softwinner/apollo/common/media/bootanimation/bootanimation.zip" 2>/dev/null

    # Init scripts
    mkdir -p "${BSP}/vendor/pulsaros/scripts"
    cp "${REPO_DIR}/vendor/pulsaros/scripts/"*.sh "${BSP}/vendor/pulsaros/scripts/" 2>/dev/null
    cp "${REPO_DIR}/vendor/pulsaros/scripts/init.pulsaros.rc" "${BSP}/vendor/pulsaros/scripts/" 2>/dev/null

    # Web server
    mkdir -p "${BSP}/vendor/pulsaros/web"
    cp "${REPO_DIR}/vendor/pulsaros/web/"* "${BSP}/vendor/pulsaros/web/" 2>/dev/null

    # Debloat
    cp "${REPO_DIR}/vendor/pulsaros/debloat.mk" "${BSP}/vendor/pulsaros/" 2>/dev/null

    # pulsaros-vendor.mk
    cp "${REPO_DIR}/vendor/pulsaros/pulsaros-vendor.mk" "${BSP}/vendor/pulsaros/" 2>/dev/null

    # Android.mk for prebuilt APKs
    cp "${REPO_DIR}/vendor/pulsaros/prebuilt/apk/Android.mk" "${APK_DIR}/" 2>/dev/null

    # ── 3. Add to apollo_p2.mk ──
    local APOLLO="${BSP}/device/softwinner/apollo/apollo_p2.mk"
    if ! grep -q "pulsaros-vendor" "${APOLLO}" 2>/dev/null; then
        echo "" >> "${APOLLO}"
        echo "# ── PulsarOS Customizations ──" >> "${APOLLO}"
        echo "\$(call inherit-product, vendor/pulsaros/pulsaros-vendor.mk)" >> "${APOLLO}"
        echo "PRODUCT_BROKEN_VERIFY_USES_LIBRARIES := true" >> "${APOLLO}"
        msg_ok "pulsaros-vendor.mk added to apollo_p2.mk"
    fi

    msg_ok "BSP подготовлен"
}
