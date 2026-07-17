# PulsarOS Vendor Makefile — absolute paths for BSP compatibility

# ── Prebuilt APKs (names from Android.mk) ──
PRODUCT_PACKAGES += F-Droid-prebuilt \
    RetroArch-prebuilt \
    Daijishou-prebuilt \
    Kodi-prebuilt \
    TVBro-prebuilt

# ── Boot Animation (already copied to correct BSP path) ──
# device/softwinner/apollo/common/media/bootanimation/bootanimation.zip

# ── RetroArch Config ──
PRODUCT_COPY_FILES += \
    vendor/pulsaros/config/retroarch/retroarch.cfg:$(TARGET_COPY_OUT_VENDOR)/etc/retroarch/retroarch.cfg \
    vendor/pulsaros/config/retroarch/cores-whitelist.txt:$(TARGET_COPY_OUT_VENDOR)/etc/retroarch/cores-whitelist.txt

# ── Daijishou Config ──
PRODUCT_COPY_FILES += \
    vendor/pulsaros/config/daijishou/platforms.json:$(TARGET_COPY_OUT_VENDOR)/etc/daijishou/platforms.json

# ── Libretro Cores (via Android.mk) ──
PRODUCT_PACKAGES += \
    fceumm_libretro snes9x_libretro gambatte_libretro mgba_libretro \
    melonds_libretro mupen64plus_next_libretro mednafen_pce_fast_libretro \
    genesis_plus_gx_libretro picodrive_libretro pcsx_rearmed_libretro \
    ppsspp_libretro fbneo_libretro mame2003_plus_libretro stella_libretro \
    handy_libretro prosystem_libretro atari800_libretro bluemsx_libretro \
    mednafen_wswan_libretro mednafen_pokemini_libretro puae_libretro \
    scummvm_libretro prboom_libretro smsplus_gx_libretro

# ── System Properties ──
PRODUCT_VENDOR_PROPERTIES += \
    persist.vendor.pulsaros.sku=zero3

# ── SSH (dropbear) ──
PRODUCT_PACKAGES += F-Droid-prebuilt dropbear dropbearkey

# ── Init scripts ──
PRODUCT_COPY_FILES += \
    vendor/pulsaros/scripts/init.pulsaros.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.pulsaros.rc \
    vendor/pulsaros/scripts/pulsaros-firstboot.sh:$(TARGET_COPY_OUT_VENDOR)/bin/pulsaros-firstboot.sh \
    vendor/pulsaros/scripts/storage-watcher.sh:$(TARGET_COPY_OUT_VENDOR)/bin/storage-watcher.sh \
    vendor/pulsaros/scripts/ssh-toggle.sh:$(TARGET_COPY_OUT_VENDOR)/bin/ssh-toggle.sh \
    vendor/pulsaros/scripts/set-resolution.sh:$(TARGET_COPY_OUT_VENDOR)/bin/set-resolution.sh

# ── Register init script ──
PRODUCT_PROPERTY_OVERRIDES += \
    init.pulsaros.rc=1

# ── Web file manager ──
PRODUCT_COPY_FILES += \
    vendor/pulsaros/scripts/pulsaros-webserver.sh:$(TARGET_COPY_OUT_VENDOR)/bin/pulsaros-webserver.sh \
    vendor/pulsaros/web/index.html:$(TARGET_COPY_OUT_VENDOR)/etc/pulsaros/web/index.html

# ── Debloat ──
$(call inherit-product, vendor/pulsaros/debloat.mk)
