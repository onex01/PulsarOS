#!/system/bin/sh
# pulsaros-firstboot.sh — Copy configs to app data directories on first boot
# Runs once via init.pulsaros.rc (oneshot service)

TAG="PulsarOS"

# ── Wait for boot to complete ──
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done
sleep 5

# ── RetroArch config ──
RA_DATA="/data/data/com.retroarch"
RA_VENDOR="/vendor/etc/retroarch"

if [ -d "${RA_VENDOR}" ] && [ -d "${RA_DATA}" ]; then
    # Copy retroarch.cfg
    mkdir -p "${RA_DATA}/files"
    if [ ! -f "${RA_DATA}/files/retroarch.cfg" ]; then
        cp "${RA_VENDOR}/retroarch.cfg" "${RA_DATA}/files/retroarch.cfg"
        log -t "${TAG}" "RetroArch config copied"
    fi
    
    # Copy autoconfig profiles
    mkdir -p "${RA_DATA}/files/autoconfig"
    if [ -d "${RA_VENDOR}/autoconfig" ]; then
        cp "${RA_VENDOR}/autoconfig/"*.cfg "${RA_DATA}/files/autoconfig/" 2>/dev/null
        log -t "${TAG}" "RetroArch autoconfig profiles copied"
    fi
    
    # Copy shaders
    mkdir -p "${RA_DATA}/files/shaders"
    if [ -d "${RA_VENDOR}/shaders" ]; then
        cp -r "${RA_VENDOR}/shaders/"* "${RA_DATA}/files/shaders/" 2>/dev/null
        log -t "${TAG}" "RetroArch shaders copied"
    fi
    
    # Copy overlays
    mkdir -p "${RA_DATA}/files/overlays"
    if [ -d "${RA_VENDOR}/overlays" ]; then
        cp -r "${RA_VENDOR}/overlays/"* "${RA_DATA}/files/overlays/" 2>/dev/null
        log -t "${TAG}" "RetroArch overlays copied"
    fi
    
    # Copy cheats
    mkdir -p "${RA_DATA}/files/cheats"
    if [ -d "${RA_VENDOR}/cheats" ]; then
        cp -r "${RA_VENDOR}/cheats/"* "${RA_DATA}/files/cheats/" 2>/dev/null
        log -t "${TAG}" "RetroArch cheats copied"
    fi
fi

# ── Daijishou config ──
DJ_DATA="/data/data/com.cyberdemic.gamebox.daijishou"
DJ_VENDOR="/vendor/etc/daijishou"

if [ -d "${DJ_VENDOR}" ] && [ -d "${DJ_DATA}" ]; then
    mkdir -p "${DJ_DATA}/files"
    if [ -f "${DJ_VENDOR}/platforms.json" ] && [ ! -f "${DJ_DATA}/files/platforms.json" ]; then
        cp "${DJ_VENDOR}/platforms.json" "${DJ_DATA}/files/platforms.json"
        log -t "${TAG}" "Daijishou platforms config copied"
    fi
fi

# ── Set default launcher to Daijishou ──
# Wait for package manager
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done
sleep 10

# Set Daijishou as home
cmd package set-home-activity com.cyberdemic.gamebox.daijishou/.ui.activities.MainActivity 2>/dev/null
log -t "${TAG}" "Default launcher set to Daijishou"

# ── Create PulsarOS storage structure on USB ──
for storage in /storage/*/; do
    if [ -d "${storage}" ] && [ "${storage}" != "/storage/emulated/" ]; then
        mkdir -p "${storage}/PulsarOS/roms"/{nes,snes,gb,gbc,gba,n64,nds,psx,psp,arcade,mame,neogeo,md,mastersystem,gamegear,segacd,sega32x,atari2600,lynx,atari7800,atari800,msx,wonderswan,pokemonmini,amiga,scummvm,doom}
        mkdir -p "${storage}/PulsarOS"/{video,music,pictures,other}
        log -t "${TAG}" "PulsarOS storage created at ${storage}"
    fi
done

log -t "${TAG}" "First-boot setup complete"
