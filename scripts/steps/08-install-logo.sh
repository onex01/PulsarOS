#!/usr/bin/env bash
# Step 8: Install Boot Logo

step_install_logo() {
    msg_info "Установка bootlogo..."

    local logo_src="${REPO_DIR}/vendor/pulsaros/boot-logo/bootlogo.bmp"
    local logo_dst="${ANDROID_SRC}/longan/device/config/chips/h618/boot-resource/boot-resource/bootlogo.bmp"

    [[ ! -f "${logo_src}" ]] && { msg_warn "bootlogo.bmp не найден — пропуск"; return 0; }
    msg_info "Источник: ${logo_src} ($(du -h "${logo_src}" | cut -f1))"

    if [[ -d "$(dirname "${logo_dst}")" ]]; then
        cp "${logo_src}" "${logo_dst}" && msg_ok "bootlogo.bmp → BSP: ${logo_dst}" || msg_warn "Не удалось скопировать в BSP"
    else
        msg_warn "BSP директория не найдена: $(dirname "${logo_dst}")"
    fi
}
