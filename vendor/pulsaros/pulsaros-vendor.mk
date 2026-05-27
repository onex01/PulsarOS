# Copyright (C) 2026 PulsarOS Project
# SPDX-License-Identifier: MIT

LOCAL_PATH := vendor/pulsaros

# ── Prebuilt APKs (для тех, кто не хочет submodule) ─────────────────
# Раскомментируйте при необходимости:
# PRODUCT_PACKAGES += \
#     RetroArch-prebuilt \
#     EmulationStationDE-prebuilt \
#     Kodi-prebuilt
#
# include $(CLEAR_VARS)
# LOCAL_MODULE := RetroArch-prebuilt
# LOCAL_SRC_FILES := prebuilt/apk/RetroArch.apk
# LOCAL_MODULE_CLASS := APPS
# LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
# LOCAL_CERTIFICATE := PRESIGNED
# include $(BUILD_PREBUILT)

# ── Dropbear для SSH ─────────────────────────────────────────────────
PRODUCT_PACKAGES += dropbear dropbearkey

# ── Vendor properties ────────────────────────────────────────────────
PRODUCT_VENDOR_PROPERTIES += \
    persist.vendor.pulsaros.sku=zero3

# ── RetroArch cores whitelist (24 stable cores for H618) ─────────────────────
PRODUCT_COPY_FILES += \
    vendor/pulsaros/config/retroarch/cores-whitelist.txt:$(TARGET_COPY_OUT_VENDOR)/etc/retroarch/cores-whitelist.txt \
    vendor/pulsaros/config/retroarch/retroarch.cfg:$(TARGET_COPY_OUT_VENDOR)/etc/retroarch/retroarch.cfg

# ── EmulationStation-DE systems config ───────────────────────────────────────
PRODUCT_COPY_FILES += \
    vendor/pulsaros/config/esde/es_systems.xml:$(TARGET_COPY_OUT_VENDOR)/etc/esde/es_systems.xml \
    vendor/pulsaros/config/esde/es_settings.xml:$(TARGET_COPY_OUT_VENDOR)/etc/esde/es_settings.xml

# ── Prebuilt libretro cores (если будут в prebuilt/cores/) ───────────────────
# PRODUCT_COPY_FILES += \
#     vendor/pulsaros/prebuilt/cores/nestopia_libretro.so:$(TARGET_COPY_OUT_VENDOR)/lib/libretro/nestopia_libretro.so \
#     vendor/pulsaros/prebuilt/cores/snes9x_libretro.so:$(TARGET_COPY_OUT_VENDOR)/lib/libretro/snes9x_libretro.so \
#     ... # добавить остальные 22 ядра по необходимости