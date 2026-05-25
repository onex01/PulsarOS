# =============================================================================
# PulsarOS — Vendor overlay makefile
# Подключает prebuilt APK, конфиги и скрипты
# =============================================================================

LOCAL_PATH := vendor/pulsaros

# ── Prebuilt APK ──────────────────────────────────────────────────────────────
# RetroArch — универсальный эмулятор
PRODUCT_PACKAGES += RetroArch

# EmulationStation DE — фронтенд для игровой библиотеки
PRODUCT_PACKAGES += EmulationStationDE

# Kodi — медиаплеер
PRODUCT_PACKAGES += Kodi

# ── Конфиги RetroArch ─────────────────────────────────────────────────────────
PRODUCT_COPY_FILES += \
    vendor/pulsaros/config/retroarch/retroarch.cfg:data/media/0/Android/data/com.retroarch/files/retroarch.cfg \
    vendor/pulsaros/config/retroarch/autoconfig/pulsaros_gamepad.cfg:data/media/0/Android/data/com.retroarch/files/autoconfig/pulsaros_gamepad.cfg

# ── Конфиги ES-DE ─────────────────────────────────────────────────────────────
PRODUCT_COPY_FILES += \
    vendor/pulsaros/config/esde/es_systems.xml:data/media/0/ES-DE/custom_systems/es_systems.xml \
    vendor/pulsaros/config/esde/es_settings.xml:data/media/0/ES-DE/settings/es_settings.xml

# ── Системные скрипты ─────────────────────────────────────────────────────────
PRODUCT_COPY_FILES += \
    vendor/pulsaros/scripts/storage-watcher.sh:system/bin/pulsaros-storage-watcher \
    vendor/pulsaros/scripts/ssh-toggle.sh:system/bin/pulsaros-ssh-toggle \
    vendor/pulsaros/scripts/set-resolution.sh:system/bin/pulsaros-set-resolution

# ── Init скрипты (запуск при загрузке) ───────────────────────────────────────
PRODUCT_COPY_FILES += \
    vendor/pulsaros/scripts/init.pulsaros.rc:system/etc/init/init.pulsaros.rc
