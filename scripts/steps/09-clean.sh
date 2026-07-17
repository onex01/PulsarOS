#!/usr/bin/env bash
# Step C: Clean

step_clean() {
    echo -e "\n${BOLD}═══ Очистка ═══${NC}\n"

    local APK_DIR="${REPO_DIR}/vendor/pulsaros/prebuilt/apk"
    local CORES_DIR="${REPO_DIR}/vendor/pulsaros/prebuilt/cores"
    local LONGAN_DIR="${ANDROID_SRC:-}/longan"

    echo "  Удалить:"
    echo "    1) Сборка ядра (longan/out/)"
    echo "    2) Сборка Android (out/)"
    echo "    3) APK файлы"
    echo "    4) Ядра libretro"
    echo "    5) Логи сборки"
    echo "    6) Всё"
    echo ""
    printf "  Выбор [1-6]: "; read choice

    case "${choice}" in
        1)
            if [[ -d "${LONGAN_DIR}/out" ]]; then
                rm -rf "${LONGAN_DIR}/out"
                msg_ok "longan/out/ удалён"
            else
                msg_warn "longan/out/ не найден"
            fi
            ;;
        2)
            if [[ -n "${ANDROID_SRC:-}" ]] && [[ -d "${ANDROID_SRC}/out" ]]; then
                rm -rf "${ANDROID_SRC}/out"
                msg_ok "Android out/ удалён"
            else
                msg_warn "Android out/ не найден"
            fi
            ;;
        3)
            rm -f "${APK_DIR}"/*.apk 2>/dev/null
            msg_ok "APK удалены"
            ;;
        4)
            rm -f "${CORES_DIR}"/*.so 2>/dev/null
            msg_ok "Ядра удалены"
            ;;
        5)
            rm -f "${LOG_DIR}"/*.log 2>/dev/null
            msg_ok "Логи удалены"
            ;;
        6)
            [[ -d "${LONGAN_DIR}/out" ]] && rm -rf "${LONGAN_DIR}/out"
            [[ -n "${ANDROID_SRC:-}" ]] && [[ -d "${ANDROID_SRC}/out" ]] && rm -rf "${ANDROID_SRC}/out"
            rm -f "${APK_DIR}"/*.apk 2>/dev/null
            rm -f "${CORES_DIR}"/*.so 2>/dev/null
            rm -f "${LOG_DIR}"/*.log 2>/dev/null
            msg_ok "Всё очищено"
            ;;
    esac
}
