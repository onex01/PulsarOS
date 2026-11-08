#!/usr/bin/env bash
# pulsaros-diag.sh — снять с платы всё, что нужно для разбора падения
# приложения, одним заходом.
#
#   pulsaros-diag.sh                    общая картина: дисплей, GLES, пакеты
#   pulsaros-diag.sh ppsspp             запустить PPSSPP и снять лог падения
#   pulsaros-diag.sh app <package>      то же для любого пакета
#   pulsaros-diag.sh logcat <файл>      просто выгрузить logcat
#
# Запускается на хосте, работает через adb по сети. Ничего на устройстве
# не меняет, кроме запуска приложения.
set -uo pipefail

HOST="${PULSAR_HOST:-192.168.1.162:5555}"
ADB=(adb -s "$HOST")

die() { echo "ОШИБКА: $*" >&2; exit 1; }

connect() {
    "${ADB[@]}" get-state >/dev/null 2>&1 && return 0
    adb connect "$HOST" >/dev/null 2>&1
    sleep 2
    "${ADB[@]}" get-state >/dev/null 2>&1 || die "нет связи с $HOST"
}

sh_() { "${ADB[@]}" shell "$@"; }

cmd_overview() {
    echo "=== устройство ==="
    sh_ 'getprop ro.product.model; getprop ro.build.version.release; getprop ro.product.cpu.abilist'
    echo
    echo "=== экран ==="
    sh_ 'wm size; wm density'
    sh_ 'dumpsys display | grep -oE "real [0-9]+ x [0-9]+|supportedModes \[[^]]*\]" | head -3'
    echo
    echo "=== GLES / Vulkan ==="
    sh_ 'dumpsys SurfaceFlinger | grep -iE "GLES|Vulkan|driver" | head -8'
    echo "  --- библиотеки ---"
    sh_ 'ls -l /vendor/lib/egl/ 2>/dev/null | head -10'
    sh_ 'getprop | grep -iE "gles|egl|vulkan|opengl" | head -10'
    echo
    echo "=== наши приложения ==="
    sh_ 'pm list packages | grep -iE "retroarch|daijishou|ppsspp|duckstation|mupen|vlc|tvbro|fennec|materialfiles|primftpd"'
    echo
    echo "=== их нативные библиотеки на месте? ==="
    sh_ 'for d in RetroArch PPSSPP DuckStation Mupen64PlusFZ TVBro MaterialFiles PrimitiveFTPd; do
            n=$(ls /system/app/$d/lib/arm/*.so 2>/dev/null | wc -l)
            echo "  $d: $n .so"
        done'
    echo
    echo "=== свободное место ==="
    sh_ 'df -h /data /system 2>/dev/null | tail -3'
}

cmd_app() {
    local pkg="$1" out="$2"
    echo "=== запускаю $pkg ==="
    sh_ 'logcat -c' 2>/dev/null
    sh_ "am force-stop $pkg" 2>/dev/null
    sleep 1
    local start
    start=$(sh_ "monkey -p $pkg -c android.intent.category.LAUNCHER 1" 2>&1 | tail -3)
    echo "$start"
    echo "  ждём 15 с..."
    sleep 15
    echo
    echo "=== в фокусе ==="
    sh_ 'dumpsys activity activities | grep -E "mResumedActivity|mFocusedApp" | head -2'
    echo
    echo "=== падения и ошибки ==="
    sh_ 'logcat -d -b crash -b main' > "$out" 2>/dev/null
    local n
    n=$(grep -icE "FATAL|UnsatisfiedLink|dlopen failed|AndroidRuntime|signal [0-9]|tombstone|SIGSEGV|SIGABRT" "$out" || true)
    echo "  строк с ошибками: $n  (полный лог: $out)"
    if [[ $n -gt 0 ]]; then
        grep -iE "FATAL|UnsatisfiedLink|dlopen failed|AndroidRuntime|signal [0-9]|SIGSEGV|SIGABRT|Caused by" "$out" | head -25
    fi
    echo
    echo "=== томбстоуны ==="
    sh_ 'ls -lt /data/tombstones/ 2>/dev/null | head -5'
}

cmd_logcat() {
    sh_ 'logcat -d -b crash -b main' > "$1" 2>/dev/null
    echo "сохранено: $1 ($(wc -l < "$1") строк)"
}

connect

case "${1:-overview}" in
    overview) cmd_overview ;;
    ppsspp)   cmd_app org.ppsspp.ppsspp "${2:-/tmp/ppsspp.log}" ;;
    app)      [[ $# -ge 2 ]] || die "нужно имя пакета"; cmd_app "$2" "${3:-/tmp/$2.log}" ;;
    logcat)   [[ $# -ge 2 ]] || die "нужен путь"; cmd_logcat "$2" ;;
    *)        die "неизвестная команда: $1" ;;
esac