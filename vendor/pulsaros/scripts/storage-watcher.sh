#!/system/bin/sh
# =============================================================================
# PulsarOS — Storage Watcher
# Следит за подключением USB/SD накопителей.
# При обнаружении папки PulsarOS/ — оповещает ES-DE и RetroArch.
#
# Запускается через init.pulsaros.rc при загрузке системы.
# =============================================================================

TAG="PulsarOS-Storage"
PULSAROS_DIR="PulsarOS"
MEDIA_DIRS="roms video audio other"
SYMLINK_BASE="/data/media/0/PulsarOS"

log()  { log -t "$TAG" "$*"; }
info() { log -t "$TAG" "INFO: $*"; }
warn() { log -t "$TAG" "WARN: $*"; }

# Создаём базовые директории во внутреннем хранилище (fallback)
init_internal_storage() {
    for dir in $MEDIA_DIRS; do
        mkdir -p "$SYMLINK_BASE/$dir"
    done
    info "Внутреннее хранилище инициализировано: $SYMLINK_BASE"
}

# Проверяем смонтированный том на наличие PulsarOS/ директории
check_volume() {
    local mount_path="$1"
    local pulsar_path="$mount_path/$PULSAROS_DIR"

    if [ -d "$pulsar_path" ]; then
        info "Найдено хранилище PulsarOS: $pulsar_path"
        setup_storage_links "$pulsar_path"
        notify_apps "$pulsar_path"
    fi
}

# Создаём симлинки для ES-DE и RetroArch
setup_storage_links() {
    local source_path="$1"

    for dir in $MEDIA_DIRS; do
        local src="$source_path/$dir"
        local dst="$SYMLINK_BASE/$dir"

        # Создаём папку на накопителе если её нет
        if [ ! -d "$src" ]; then
            mkdir -p "$src"
            info "Создана папка: $src"
        fi

        # Симлинк из внутреннего хранилища → накопитель
        if [ -L "$dst" ] || [ -d "$dst" ]; then
            rm -rf "$dst"
        fi
        ln -sf "$src" "$dst"
        info "Симлинк: $dst → $src"
    done
}

# Оповещаем приложения о новом хранилище через broadcast
notify_apps() {
    local path="$1"
    # ES-DE перезапускает сканирование при получении этого intent
    am broadcast \
        -a "dev.pulsaros.STORAGE_READY" \
        --es "storage_path" "$path" \
        --ez "has_roms" "$([ -d "$path/roms" ] && echo true || echo false)" \
        2>/dev/null || true
    info "Broadcast отправлен: STORAGE_READY path=$path"
}

# Основной цикл — следим за /proc/mounts
main() {
    info "Storage Watcher запущен"
    init_internal_storage

    # Первичная проверка уже смонтированных томов
    while IFS= read -r line; do
        local mount_point
        mount_point=$(echo "$line" | awk '{print $2}')
        case "$mount_point" in
            /storage/emulated*) continue ;;   # Внутреннее хранилище — пропускаем
            /storage/*)         check_volume "$mount_point" ;;
        esac
    done < /proc/mounts

    # Следим за изменениями
    # inotifywait не всегда доступен в AOSP, используем polling
    local PREV_MOUNTS=""
    while true; do
        local CURR_MOUNTS
        CURR_MOUNTS=$(grep "^/dev" /proc/mounts | awk '{print $2}' | sort)

        if [ "$CURR_MOUNTS" != "$PREV_MOUNTS" ]; then
            # Что-то изменилось — проверяем новые точки монтирования
            while IFS= read -r mount_point; do
                case "$mount_point" in
                    /storage/emulated*) continue ;;
                    /storage/*)
                        # Это новый mount — проверяем
                        echo "$PREV_MOUNTS" | grep -qF "$mount_point" || \
                            check_volume "$mount_point"
                        ;;
                esac
            done <<EOF
$CURR_MOUNTS
EOF
            PREV_MOUNTS="$CURR_MOUNTS"
        fi

        sleep 3
    done
}

main
