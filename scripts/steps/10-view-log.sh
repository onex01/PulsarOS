#!/usr/bin/env bash
# Step: View Build Log

step_view_log() {
    if [[ -f "${_LATEST_LOG}" ]]; then
        echo -e "\n${BOLD}═══ Последний лог: ${_LATEST_LOG} ═══${NC}\n"
        echo "  Размер: $(du -h "${_LATEST_LOG}" | cut -f1), строк: $(wc -l < "${_LATEST_LOG}")"
        echo ""
        tail -50 "${_LATEST_LOG}"
        echo ""
        echo "  Для полного просмотра: less ${_LATEST_LOG}"
    else
        msg_warn "Логи ещё не созданы"
    fi
}
