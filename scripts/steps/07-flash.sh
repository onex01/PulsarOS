#!/usr/bin/env bash
# Step 7: Flash to SD

step_flash() {
    echo -e "\n${BOLD}═══ Прошивка на SD ═══${NC}\n"

    local img=""
    for f in "${REPO_DIR}/out/PulsarOS-OPiZero3-Android12-"*.img; do
        [[ -f "${f}" ]] && img="${f}" && break
    done
    [[ -z "${img}" ]] && img="${REPO_DIR}/out/pulsaros.img"
    [[ ! -f "${img}" ]] && { msg_error "Образ не найден в ${REPO_DIR}/out/"; return 1; }

    # Detect image format
    local img_magic=$(xxd -l 8 "${img}" 2>/dev/null | head -1)
    local img_type="raw"
    if echo "${img_magic}" | grep -q "IMAGEWTY"; then
        img_type="IMAGEWTY"
    fi

    local img_size=$(stat -c%s "${img}")
    local img_human=$(du -h "${img}" | cut -f1)
    msg_info "Образ: ${img_human} (${img_type})"

    echo ""
    echo "  Доступные устройства:"
    local devs=()
    local i=1
    while IFS= read -r dev; do
        local size=$(lsblk -dno SIZE "${dev}" 2>/dev/null || echo "?")
        local model=$(lsblk -dno MODEL "${dev}" 2>/dev/null | xargs)
        local display="${dev} (${size})"
        [[ -n "${model}" ]] && display="${dev} ${model} (${size})"
        echo "    ${i}) ${display}"
        devs+=("${dev}")
        ((i++))
    done < <(lsblk -dno NAME 2>/dev/null | grep -E '^sd|^mmcblk' | sed 's|^|/dev/|')

    [[ ${#devs[@]} -eq 0 ]] && { msg_error "Нет доступных устройств"; return 1; }

    printf "  Устройство [1-${#devs[@]}]: "; read choice
    [[ -z "${choice}" ]] && return
    local dev="${devs[$((choice - 1))]}"

    # Safety checks
    if [[ "${dev}" == "/" ]]; then
        msg_error "Нельзя прошить корневую файловую систему!"
        return 1
    fi

    local dev_size=$(blockdev --getsize64 "${dev}" 2>/dev/null || echo 0)
    if [[ "${img_size}" -gt "${dev_size}" ]]; then
        msg_error "Образ (${img_human}) больше устройства ($(lsblk -dno SIZE "${dev}"))"
        return 1
    fi

    # Show warning
    echo ""
    echo -e "  ${RED}ВНИМАНИЕ: Все данные на ${dev} будут удалены!${NC}"
    echo "  Образ: ${img_human} (${img_type})"
    echo "  Устройство: ${dev} ($(lsblk -dno SIZE "${dev}"))"
    echo ""
    printf "  Введите имя устройства для подтверждения [${dev##*/}]: "; read confirm_dev
    [[ "${confirm_dev}" != "${dev##*/}" ]] && { msg_warn "Отмена"; return; }

    msg_info "Прошивка ${dev}..."
    sudo dd if="${img}" of="${dev}" bs=4M status=progress conv=fsync
    sync

    msg_ok "Прошивка завершена!"
    echo ""
    msg_info "Извлеките SD карту и вставьте в Orange Pi Zero 3"
    msg_info "Подключите питание 5V/3A USB-C и HDMI монитор"
}
