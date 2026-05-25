#!/system/bin/sh
# =============================================================================
# PulsarOS — Set Resolution
# Устанавливает разрешение и частоту обновления через DisplayManager
# Вызывается из OOBE и из Настроек → PulsarOS Tools
#
# Использование:
#   pulsaros-set-resolution <разрешение> <hz>
#   pulsaros-set-resolution 1920x1080 60
#   pulsaros-set-resolution 1920x1080 120
#   pulsaros-set-resolution list   — показать доступные режимы
# =============================================================================

TAG="PulsarOS-Display"

list_modes() {
    echo "Доступные режимы дисплея:"
    wm size 2>/dev/null
    echo ""
    # Получаем список поддерживаемых режимов через surfaceflinger
    service call SurfaceFlinger 1016 2>/dev/null || \
    dumpsys display | grep -E "mDisplayInfo|refreshRate|resolution" | head -30
}

set_mode() {
    local RES="$1"
    local HZ="${2:-60}"
    local WIDTH HEIGHT

    WIDTH=$(echo "$RES" | cut -dx -f1)
    HEIGHT=$(echo "$RES" | cut -dx -f2)

    if [ -z "$WIDTH" ] || [ -z "$HEIGHT" ]; then
        echo "Неверный формат разрешения: $RES. Используй, например: 1920x1080"
        exit 1
    fi

    echo "Устанавливаю: ${WIDTH}×${HEIGHT} @ ${HZ}Hz"

    # Устанавливаем через wm (работает в Android без root для userdebug)
    wm size "${WIDTH}x${HEIGHT}"
    wm density 213  # PulsarOS default DPI для TV

    # Частота обновления через настройки
    settings put system min_refresh_rate "$HZ"
    settings put system peak_refresh_rate "$HZ"
    settings put global animator_duration_scale 1.0

    log -t "$TAG" "Режим установлен: ${WIDTH}x${HEIGHT}@${HZ}Hz"
    echo "Готово. Экран будет обновлён через несколько секунд."
}

case "${1:-list}" in
    list) list_modes ;;
    *)    set_mode "$1" "${2:-60}" ;;
esac
