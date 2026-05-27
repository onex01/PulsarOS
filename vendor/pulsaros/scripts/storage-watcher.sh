#!/vendor/bin/sh
# PulsarOS Storage Watcher
# SPDX-License-Identifier: MIT

TAG="PulsarOS.Storage"
log() { log -t "$TAG" -p i "$1"; }

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
    done

    [ "$FOUND" = false ] && setprop persist.pulsaros.storage.ready 0
    sleep 5
done