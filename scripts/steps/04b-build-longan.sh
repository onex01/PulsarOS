#!/usr/bin/env bash
# Step: Build longan (kernel + bootloader)

step_build_longan() {
    echo -e "\n${BOLD}═══ Сборка longan (ядро + загрузчик) ═══${NC}\n"

    if [[ -z "${ANDROID_SRC:-}" ]] || [[ ! -d "${ANDROID_SRC}" ]]; then
        msg_error "ANDROID_SRC не задан: ${ANDROID_SRC:-<пусто>}"
        return 1
    fi

    local LONGAN_DIR="${ANDROID_SRC}/longan"
    if [[ ! -f "${LONGAN_DIR}/build.sh" ]]; then
        msg_error "longan/build.sh не найден: ${LONGAN_DIR}/build.sh"
        return 1
    fi

    # Check if already built
    local BIMAGE="${LONGAN_DIR}/out/h618/p2/android/bImage"
    if [[ -f "${BIMAGE}" ]]; then
        msg_ok "longan уже собран: ${BIMAGE}"
        return 0
    fi
    
    # ── Step 1: Install bootlogo BEFORE kernel build ──
    msg_info "Установка bootlogo..."
    step_install_logo
    
    # ── Step 2: Auto-configure ──
    if [[ ! -f "${LONGAN_DIR}/.buildconfig" ]]; then
        msg_info "Конфигурация longan: android, h618, p2, default, linux-5.4, arm64"
        cd "${LONGAN_DIR}"
        printf '0\n0\n2\n0\n0\n1\n' | bash build.sh config
        cd "${REPO_DIR}"

        if [[ ! -f "${LONGAN_DIR}/.buildconfig" ]]; then
            msg_error "Конфигурация longan не создалась"
            return 1
        fi
        msg_ok "Конфигурация longan создана"
    fi

    # ── Step 3: Fix spl symlink ──
    local BRANDY_DIR="${LONGAN_DIR}/brandy/brandy-2.0"
    if [[ -d "${BRANDY_DIR}/spl-pub" ]] && [[ ! -d "${BRANDY_DIR}/spl" ]]; then
        msg_info "Создаю symlink spl → spl-pub..."
        ln -s spl-pub "${BRANDY_DIR}/spl"
        msg_ok "symlink создан"
    fi

    # ── Step 4: Fix broken ANDROID_CLANG_PATH ──
    local BCFG="${LONGAN_DIR}/.buildconfig"
    if [[ -f "${BCFG}" ]]; then
        local clang_path=$(grep "^export ANDROID_CLANG_PATH=" "${BCFG}" 2>/dev/null | cut -d= -f2-)
        if [[ "${clang_path}" == *"//mnt/"* ]] || [[ "${clang_path}" == *"/mnt/BF/H618"*"/mnt/"* ]]; then
            msg_warn "Исправляю ANDROID_CLANG_PATH в .buildconfig..."
            sed -i "s|^export ANDROID_CLANG_PATH=.*|export ANDROID_CLANG_PATH=${ANDROID_SRC}/prebuilts/clang/host/linux-x86/clang-r416183b1/bin|" "${BCFG}"
            msg_ok "ANDROID_CLANG_PATH исправлен"
        fi
    fi

    # ── Step 5: Build ──
    msg_info "Сборка longan (ядро + загрузчик)..."
    msg_info "Лог: ${LOG_FILE}"
    msg_info "Сборка идёт напрямую в терминале. Не закрывайте его!"

    export PATH="/usr/sbin:${PATH}"
    export USE_CCACHE=false

    cd "${LONGAN_DIR}"
    bash build.sh
    local rc=$?
    cd "${REPO_DIR}"

    if [[ ${rc} -ne 0 ]]; then
        msg_error "Сборка longan завершилась с ошибкой (код ${rc})"
        return ${rc}
    fi

    # ── Step 6: Copy kernel outputs to expected locations ──
    msg_info "Копирование ядра в longan/out/h618/p2/android/..."
    local PLAT_OUT="${LONGAN_DIR}/out/h618/p2/android"
    local STAGING="${LONGAN_DIR}/out/kernel/staging"
    mkdir -p "${PLAT_OUT}/dist"

    # bImage
    if [[ -f "${STAGING}/bImage" ]]; then
        cp "${STAGING}/bImage" "${PLAT_OUT}/bImage"
        msg_ok "bImage скопирован ($(du -h "${PLAT_OUT}/bImage" | cut -f1))"
    fi

    # sunxi.dtb
    if [[ -f "${STAGING}/sunxi.dtb" ]]; then
        cp "${STAGING}/sunxi.dtb" "${PLAT_OUT}/sunxi.dtb"
        msg_ok "sunxi.dtb скопирован"
    fi

    # .ko modules
    local ko_count=0
    if [[ -d "${STAGING}/lib/modules/5.4.125" ]]; then
        cp "${STAGING}/lib/modules/5.4.125/"*.ko "${PLAT_OUT}/dist/" 2>/dev/null
        ko_count=$(ls "${PLAT_OUT}/dist/"*.ko 2>/dev/null | wc -l)
    fi
    msg_ok "Скопировано: bImage + sunxi.dtb + ${ko_count} модулей (.ko)"

    msg_ok "longan собран успешно!"
}
