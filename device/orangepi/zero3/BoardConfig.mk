# Copyright (C) 2026 PulsarOS Project
# SPDX-License-Identifier: MIT
#
# Board config for Orange Pi Zero 3 (Allwinner H618) — PulsarOS flavor

# Inherit upstream Orange Pi base
-include device/orangepi/zero3/BoardConfig.mk.upstream

# ═══════════════════════════════════════════════════════════════════
# PULSAROS BOARD OVERRIDES
# ═══════════════════════════════════════════════════════════════════

# GPU: Mali G31 MP2 — принудительно используем blob
BOARD_USES_LIBMALI := true
BOARD_GPU_DRIVERS := mali
USE_OPENGL_RENDERER := true
NUM_FRAMEBUFFER_SURFACE_BUFFERS := 3

# RRO overlays
DEVICE_PACKAGE_OVERLAYS += device/orangepi/zero3/overlay

# ZRAM (для версий 1/1.5/2 GB)
BOARD_ZRAM_SIZE_MB := 1024
BOARD_USES_ZRAM := true

# Deterministic builds
BUILD_NUMBER ?= 0
SOURCE_DATE_EPOCH := $(shell date +%s)

# Disable TV-specific hardware
BOARD_HAS_NO_TV_TUNER := true
BOARD_HAS_NO_HDMI_CEC := true

# Board-level copy files
PRODUCT_COPY_FILES += \
    device/orangepi/zero3/config/thermal-engine.conf:$(TARGET_COPY_OUT_VENDOR)/etc/thermal-engine.conf \
    vendor/pulsaros/scripts/init.pulsaros.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.pulsaros.rc