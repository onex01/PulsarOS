#!/usr/bin/env bash
# Step 5: Build Android (with BSP preparation)

step_build_android() {
    echo -e "\n${BOLD}═══ Сборка Android ═══${NC}\n"

    if [[ -z "${ANDROID_SRC:-}" ]] || [[ ! -d "${ANDROID_SRC}" ]]; then
        msg_error "ANDROID_SRC не задан"
        return 1
    fi

    [[ ! -f "${ANDROID_SRC}/build/envsetup.sh" ]] && { msg_error "build/envsetup.sh не найден"; return 1; }

    # ── Prepare BSP first ──
    msg_info "Подготовка BSP..."
    step_prepare_bsp || return 1

    # ── Build Android ──
    msg_info "Сборка Android (JOBS=${JOBS:-8})..."
    msg_info "Лог: ${LOG_FILE}"

    export USE_CCACHE=false
    set +u
    cd "${ANDROID_SRC}"
    source build/envsetup.sh
    lunch apollo_p2-${VARIANT:-userdebug}
    set -u
    make -j${JOBS:-8}
    local rc=$?
    cd "${REPO_DIR}"

    if [[ ${rc} -ne 0 ]]; then
        msg_error "Сборка завершилась с ошибкой (код ${rc})"
        return ${rc}
    fi
    msg_ok "Android собран"

    # ── Setup pack_hook override ──
    # pack_hook.sh пересобирает boot.fex/vendor_boot.fex если override пустой
    # Положим наши файлы в override → pack_hook использует их как есть
    local OVERRIDE="${ANDROID_SRC}/longan/build/hook/pack/android12/override"
    mkdir -p "${OVERRIDE}"

    local PRODUCT_OUT=""
    for d in "${ANDROID_SRC}/out/target/product/"*/; do
        [[ -f "${d}boot.img" ]] && PRODUCT_OUT="${d}" && break
    done

    if [[ -n "${PRODUCT_OUT}" ]]; then
        [[ -f "${PRODUCT_OUT}/boot.img" ]] && {
            cp "${PRODUCT_OUT}/boot.img" "${OVERRIDE}/boot.img"
            msg_ok "override/boot.img ← наш $(du -h "${PRODUCT_OUT}/boot.img" | cut -f1)"
        }
        [[ -f "${PRODUCT_OUT}/vendor_boot.img" ]] && {
            cp "${PRODUCT_OUT}/vendor_boot.img" "${OVERRIDE}/vendor_boot.img"
            msg_ok "override/vendor_boot.img ← наш"
        }
        # dtbo, misc, super — pack берёт из product output через symlinks
        [[ -f "${PRODUCT_OUT}/dtbo.img" ]] && {
            cp "${PRODUCT_OUT}/dtbo.img" "${OVERRIDE}/dtbo.img"
            msg_ok "override/dtbo.img ← наш"
        }
    fi
}
