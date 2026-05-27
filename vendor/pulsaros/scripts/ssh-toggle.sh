#!/vendor/bin/sh
# PulsarOS SSH Manager (Dropbear)
# SPDX-License-Identifier: MIT

PORT=2222
KEY=/data/pulsaros/ssh/ssh_host_rsa_key
BIN=/system/xbin/dropbear
PIDFILE=/data/pulsaros/ssh/dropbear.pid

log() { log -t PulsarOS.SSH -p i "$1"; }

case "$1" in
start)
    log "Enabling SSH on port $PORT"
    mkdir -p "$(dirname "$KEY")"
    [ -f "$KEY" ] || dropbearkey -t rsa -f "$KEY" 2>/dev/null
    killall dropbear 2>/dev/null
    $BIN -p $PORT -R -F -E 2>&1 | log -t PulsarOS.SSH &
    echo $! > "$PIDFILE"
    log "SSH running, PID $(cat $PIDFILE)"
    ;;
stop)
    log "Disabling SSH"
    [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null
    killall dropbear 2>/dev/null
    rm -f "$PIDFILE"
    ;;
status)
    pgrep -x dropbear >/dev/null && echo "Running" || echo "Stopped"
    ;;
*)
    echo "Usage: $0 {start|stop|status}"
    exit 1
    ;;
esac