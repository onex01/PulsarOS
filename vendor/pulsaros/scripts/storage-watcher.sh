#!/vendor/bin/sh
# PulsarOS Storage Watcher
# Auto-detects USB/SD storage and creates PulsarOS directory structure
# SPDX-License-Identifier: MIT

TAG="PulsarOS.Storage"
log() { log -t "$TAG" -p i "$1"; }

create_pulsaros_dirs() {
    local base="$1/PulsarOS"
    mkdir -p "$base/roms/nes"
    mkdir -p "$base/roms/snes"
    mkdir -p "$base/roms/gb"
    mkdir -p "$base/roms/gbc"
    mkdir -p "$base/roms/gba"
    mkdir -p "$base/roms/n64"
    mkdir -p "$base/roms/nds"
    mkdir -p "$base/roms/pce"
    mkdir -p "$base/roms/mastersystem"
    mkdir -p "$base/roms/gamegear"
    mkdir -p "$base/roms/megadrive"
    mkdir -p "$base/roms/segacd"
    mkdir -p "$base/roms/sega32x"
    mkdir -p "$base/roms/psx"
    mkdir -p "$base/roms/psp"
    mkdir -p "$base/roms/arcade"
    mkdir -p "$base/roms/mame"
    mkdir -p "$base/roms/neogeo"
    mkdir -p "$base/roms/atari2600"
    mkdir -p "$base/roms/lynx"
    mkdir -p "$base/roms/atari7800"
    mkdir -p "$base/roms/atari800"
    mkdir -p "$base/roms/msx"
    mkdir -p "$base/roms/wonderswan"
    mkdir -p "$base/roms/pokemonmini"
    mkdir -p "$base/roms/amiga"
    mkdir -p "$base/roms/scummvm"
    mkdir -p "$base/roms/doom"
    mkdir -p "$base/roms/saves"
    mkdir -p "$base/roms/states"
    mkdir -p "$base/roms/screenshots"
    mkdir -p "$base/roms/playlists"
    mkdir -p "$base/video"
    mkdir -p "$base/audio"
    mkdir -p "$base/other"
    log "Created PulsarOS directory structure at $base"
}

notify_storage_found() {
    am broadcast -a com.pulsaros.STORAGE_FOUND --es path "$1" -n com.pulsaros.setup/.StorageReceiver 2>/dev/null
}

log "Storage watcher started"

while true; do
    FOUND=false
    for mp in /storage/*; do
        [ "$mp" = "/storage/emulated" ] && continue
        [ "$mp" = "/storage/self" ] && continue
        [ ! -d "$mp" ] && continue

        if [ -d "$mp/PulsarOS/roms" ]; then
            log "Detected PulsarOS storage at $mp"
            setprop persist.pulsaros.storage.path "$mp/PulsarOS"
            setprop persist.pulsaros.storage.ready 1
            FOUND=true
            break
        fi

        # Auto-create PulsarOS structure on newly mounted removable storage
        if [ -d "$mp" ] && [ ! -d "$mp/PulsarOS" ]; then
            # Check if it's a removable device (USB or SD)
            case "$mp" in
                */usb*|*/sdcard*|*/ext*)
                    log "New removable storage detected at $mp, creating PulsarOS structure"
                    create_pulsaros_dirs "$mp"
                    setprop persist.pulsaros.storage.path "$mp/PulsarOS"
                    setprop persist.pulsaros.storage.ready 1
                    notify_storage_found "$mp/PulsarOS"
                    FOUND=true
                    break
                    ;;
            esac
        fi
    done

    [ "$FOUND" = false ] && setprop persist.pulsaros.storage.ready 0
    sleep 5
done
