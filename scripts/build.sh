#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                        PulsarOS Build System v3.0                           ║
# ║                     Modular Build Script                                    ║
# ║                     SPDX-License-Identifier: MIT                           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -uo pipefail

# ── Source libraries ─────────────────────────────────────────────────────────
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib/common.sh"
source "${SCRIPTS_DIR}/lib/config.sh"

# ── Source all step modules ──────────────────────────────────────────────────
for step_file in "${SCRIPTS_DIR}"/steps/*.sh; do
    [[ -f "${step_file}" ]] && source "${step_file}"
done

# ═══════════════════════════════════════════════════════════════════════════════
# Auto Build (sequential pipeline)
# ═══════════════════════════════════════════════════════════════════════════════
step_auto_build() {
    echo -e "\n${BOLD}═══ Автоматическая сборка ═══${NC}\n"
    msg_info "Лог сборки: ${LOG_FILE}"

    msg_info "═══ Этап 1/6: Конфигурация ═══"
    step_configure || return 1

    msg_info "═══ Этап 2/6: Скачивание APK ═══"
    step_download_apks || true

    msg_info "═══ Этап 3/6: Загрузка ядер ═══"
    step_build_cores || true

    msg_info "═══ Этап 4/6: Сборка longan (ядро + загрузчик + bootlogo) ═══"
    step_build_longan || return 1

    msg_info "═══ Этап 5/6: Сборка Android ═══"
    step_build_android || return 1

    msg_info "═══ Этап 6/6: Создание образа ═══"
    step_create_image || return 1

    local DATE=$(date +%Y-%m-%d)
    local FINAL="${REPO_DIR}/out/PulsarOS-OPiZero3-Android12-${DATE}.img"
    echo ""
    msg_ok "Автосборка завершена!"
    msg_ok "Образ: ${FINAL} ($(du -h "${FINAL}" | cut -f1))"
    msg_ok "MD5: ${FINAL}.md5"
    msg_ok "Лог: ${LOG_FILE}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Info
# ═══════════════════════════════════════════════════════════════════════════════
show_info() {
    echo -e "\n${BOLD}═══ Информация ═══${NC}\n"
    echo "  Android Source: ${ANDROID_SRC:-не задан}"
    echo "  Вариант: ${VARIANT}"
    echo "  Потоки: ${JOBS}"
    echo "  ccache: ${CCACHE_SIZE}"
    local APK_DIR="${REPO_DIR}/vendor/pulsaros/prebuilt/apk"
    echo "  APK:"
    for f in "${APK_DIR}"/*.apk; do [[ -f "$f" ]] && echo "    $(du -h "$f" | cut -f1) $(basename "$f")"; done
    local CORES_DIR="${REPO_DIR}/vendor/pulsaros/prebuilt/cores"
    echo "  Ядра: $(ls "${CORES_DIR}"/*.so 2>/dev/null | wc -l) файлов"
    echo "  Логотип: $([ -f "${REPO_DIR}/vendor/pulsaros/boot-logo/bootlogo.bmp" ] && echo "есть" || echo "нет")"
    echo ""
    echo "  Логи:"
    if [[ -f "${_LATEST_LOG}" ]]; then
        echo "    Последний: ${_LATEST_LOG}"
        echo "    Размер: $(du -h "${_LATEST_LOG}" | cut -f1)"
    fi
    echo "    Директория: ${LOG_DIR}/"
    ls -lt "${LOG_DIR}"/*.log 2>/dev/null | head -5 | while read line; do echo "      ${line}"; done
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Menu
# ═══════════════════════════════════════════════════════════════════════════════
show_menu() {
    echo "" >&2
    echo "  ╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ║  PulsarOS Build System v3.0                                 ║" >&2
    echo "  ╚══════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    echo "  1) Автосборка           всё последовательно (рекомендуется)" >&2
    echo "" >&2
    echo "  2) Скачать APK          RetroArch, Daijishou, Kodi, TV Bro" >&2
    echo "  3) Собрать ядра         libretro cores для ARM" >&2
    echo "  4) Собрать longan       ядро + загрузчик" >&2
    echo "  5) Собрать Android      sync → make" >&2
    echo "  6) Создать образ        IMAGEWTY (pack) или dd-concat" >&2
    echo "  7) Прошить на SD        dd" >&2
    echo "" >&2
    echo "  9) Настройки" >&2
    echo "  s) Подготовка системы   установка зависимостей" >&2
    echo "  c) Очистка              удалить out/, ядра, APK" >&2
    echo "  l) Лог сборки           показать последний лог" >&2
    echo "  i) Информация" >&2
    echo "  q) Выход" >&2
    echo "" >&2
    printf "  Выбор: " >&2
    read choice
    printf "%s" "${choice}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Settings
# ═══════════════════════════════════════════════════════════════════════════════
step_settings() {
    echo -e "\n${BOLD}═══ Настройки ═══${NC}\n"
    echo "  1) Путь к Android source: ${ANDROID_SRC:-не задан}"
    echo "  2) Вариант сборки: ${VARIANT}"
    echo "  3) Параллельные потоки: ${JOBS}"
    echo "  4) ccache: ${CCACHE_SIZE}"
    echo ""
    printf "  Выбор [1-4]: "; read choice
    [[ -z "${choice}" ]] && return
    case "${choice}" in
        1) step_configure ;;
        2) printf "  Варианты: userdebug, user, eng [${VARIANT}]: "; read v; [[ -n "${v}" ]] && VARIANT="${v}"; save_config ;;
        3) printf "  JOBS [${JOBS}]: "; read j; [[ -n "${j}" ]] && JOBS="${j}"; save_config ;;
        4) printf "  ccache [${CCACHE_SIZE}]: "; read c; [[ -n "${c}" ]] && CCACHE_SIZE="${c}"; save_config ;;
    esac
    wait_key
}

# ═══════════════════════════════════════════════════════════════════════════════
# Entry Point
# ═══════════════════════════════════════════════════════════════════════════════
load_config

while true; do
    choice=$(show_menu)
    case "${choice}" in
        1) step_auto_build; wait_key ;;
        2) step_download_apks; wait_key ;;
        3) step_build_cores; wait_key ;;
        4) step_build_longan; wait_key ;;
        5) step_build_android; wait_key ;;
        6) step_create_image; wait_key ;;
        7) step_flash; wait_key ;;
        9) step_settings ;;
        s|S) step_setup_system; wait_key ;;
        c|C) step_clean; wait_key ;;
        l|L) step_view_log; wait_key ;;
        i|I) show_info; wait_key ;;
        q|Q) echo -e "\n  До свидания!\n"; exit 0 ;;
        *) ;;
    esac
done
