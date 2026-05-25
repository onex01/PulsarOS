#!/system/bin/sh
# =============================================================================
# PulsarOS — SSH Toggle
# Включает/выключает SSH-сервер (dropbear) и показывает параметры подключения
#
# Использование (из Android Settings → PulsarOS Tools):
#   pulsaros-ssh-toggle enable
#   pulsaros-ssh-toggle disable
#   pulsaros-ssh-toggle status
# =============================================================================

TAG="PulsarOS-SSH"
DROPBEAR_BIN="/system/bin/dropbear"
DROPBEAR_KEYS_DIR="/data/ssh"
DROPBEAR_PID="/data/run/dropbear.pid"
SSH_PORT="2222"
SSH_USER="shell"

log_info() { log -t "$TAG" "INFO: $*"; echo "$*"; }
log_err()  { log -t "$TAG" "ERR:  $*"; echo "ERROR: $*" >&2; }

# Получаем IP-адрес (первый не-loopback)
get_ip() {
    ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || \
    ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 || \
    echo "неизвестен"
}

# Генерируем ключи если нет
ensure_keys() {
    mkdir -p "$DROPBEAR_KEYS_DIR"
    if [ ! -f "$DROPBEAR_KEYS_DIR/dropbear_rsa_host_key" ]; then
        log_info "Генерирую SSH ключи..."
        dropbearkey -t rsa -f "$DROPBEAR_KEYS_DIR/dropbear_rsa_host_key" -s 2048
    fi
    if [ ! -f "$DROPBEAR_KEYS_DIR/dropbear_ecdsa_host_key" ]; then
        dropbearkey -t ecdsa -f "$DROPBEAR_KEYS_DIR/dropbear_ecdsa_host_key"
    fi
}

enable_ssh() {
    if [ -f "$DROPBEAR_PID" ] && kill -0 "$(cat "$DROPBEAR_PID")" 2>/dev/null; then
        log_info "SSH уже запущен"
    else
        ensure_keys
        "$DROPBEAR_BIN" \
            -p "$SSH_PORT" \
            -P "$DROPBEAR_PID" \
            -r "$DROPBEAR_KEYS_DIR/dropbear_rsa_host_key" \
            -r "$DROPBEAR_KEYS_DIR/dropbear_ecdsa_host_key" \
            -F -E &

        sleep 1
        log_info "SSH запущен на порту $SSH_PORT"
    fi

    local IP
    IP=$(get_ip)
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║       PulsarOS SSH доступ            ║"
    echo "╠══════════════════════════════════════╣"
    printf "║  Адрес : %-29s║\n" "$IP"
    printf "║  Порт  : %-29s║\n" "$SSH_PORT"
    printf "║  Польз.: %-29s║\n" "$SSH_USER"
    echo "╠══════════════════════════════════════╣"
    echo "║  Команда подключения:                ║"
    printf "║  ssh %s@%s -p %s%s║\n" "$SSH_USER" "$IP" "$SSH_PORT" "$(printf '%*s' $((22 - ${#IP})) '')"
    echo "╚══════════════════════════════════════╝"
    echo ""
}

disable_ssh() {
    if [ -f "$DROPBEAR_PID" ]; then
        kill "$(cat "$DROPBEAR_PID")" 2>/dev/null && rm -f "$DROPBEAR_PID"
        log_info "SSH остановлен"
    else
        log_info "SSH не запущен"
    fi
}

status_ssh() {
    if [ -f "$DROPBEAR_PID" ] && kill -0 "$(cat "$DROPBEAR_PID")" 2>/dev/null; then
        local IP
        IP=$(get_ip)
        log_info "SSH активен — ssh $SSH_USER@$IP -p $SSH_PORT"
    else
        log_info "SSH неактивен"
    fi
}

case "${1:-status}" in
    enable)  enable_ssh  ;;
    disable) disable_ssh ;;
    status)  status_ssh  ;;
    *) echo "Использование: pulsaros-ssh-toggle [enable|disable|status]" ;;
esac
