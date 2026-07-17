#!/usr/bin/env bash
# Step 1: Configure Source Path

step_configure() {
    echo -e "\n${BOLD}═══ Путь к Android Source ═══${NC}\n"

    if [[ -n "${ANDROID_SRC}" ]] && [[ -d "${ANDROID_SRC}" ]] && [[ -f "${ANDROID_SRC}/build/envsetup.sh" ]]; then
        msg_ok "Текущий путь: ${ANDROID_SRC}"
        printf "  Использовать? [Y/n]: "; read choice
        [[ "${choice}" =~ ^[Nn]$ ]] || return 0
    fi

    echo "  Введите путь к Android 12 source tree:"
    printf "  Путь: "; read new_path
    [[ -z "${new_path}" ]] && { msg_error "Путь не может быть пустым"; return 1; }

    new_path="${new_path/#\~/$HOME}"
    new_path="$(realpath "${new_path}" 2>/dev/null || echo "${new_path}")"

    [[ ! -d "${new_path}" ]] && { msg_error "Директория не существует: ${new_path}"; return 1; }
    [[ ! -f "${new_path}/build/envsetup.sh" ]] && { msg_error "Не является Android source tree"; return 1; }

    ANDROID_SRC="${new_path}"
    save_config
    msg_ok "Путь сохранён: ${ANDROID_SRC}"
}
