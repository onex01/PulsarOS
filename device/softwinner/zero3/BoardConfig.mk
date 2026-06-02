# Copyright (C) 2026 PulsarOS Project
# SPDX-License-Identifier: MIT
#
# BoardConfig.mk — Orange Pi Zero 3 (Allwinner H618, Cortex-A53 × 4, Mali G31 MP2)

LOCAL_PATH := device/softwinner/zero3
TARGET_COPY_OUT_VENDOR := vendor

# ═══════════════════════════════════════════════════════════════════════════════
# ARCHITECTURE — ОБЯЗАТЕЛЬНЫЙ БЛОК
# ═══════════════════════════════════════════════════════════════════════════════

TARGET_ARCH         := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI      := arm64-v8a
TARGET_CPU_VARIANT  := cortex-a53

# 32-bit secondary ABI (for compatibility with older APK and RetroArch cores)
TARGET_2ND_ARCH         := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI      := armeabi-v7a
TARGET_2ND_CPU_ABI2     := armeabi
TARGET_2ND_CPU_VARIANT  := cortex-a53

# ═══════════════════════════════════════════════════════════════════════════════
# PLATFORM
# ═══════════════════════════════════════════════════════════════════════════════

TARGET_BOARD_PLATFORM         := sun50iw9   # Allwinner H618 BSP platform name
TARGET_BOARD_PLATFORM_GPU     := mali-g31
TARGET_BOOTLOADER_BOARD_NAME  := zero3
TARGET_NO_BOOTLOADER          := true       # U-Boot is not part of Android build
TARGET_NO_KERNEL              := false

# ═══════════════════════════════════════════════════════════════════════════════
# KERNEL
# ═══════════════════════════════════════════════════════════════════════════════

TARGET_KERNEL_ARCH        := arm64
TARGET_KERNEL_SOURCE      := kernel/orangepi/zero3
TARGET_KERNEL_CONFIG      := pulsaros_zero3_defconfig

# Using kernel artifacts built by Orange Pi Longan for the apollo_p2/Zero 3 board.
TARGET_PREBUILT_KERNEL    := longan/out/h618/p2/android/bImage
BOARD_PREBUILT_DTBIMAGE   := longan/out/h618/p2/android/sunxi.dtb
BOARD_DTBO_SUPPORT        := false

# Kernel command line arguments
BOARD_KERNEL_CMDLINE := \
    console=ttyS0,115200 \
    loglevel=8 \
    root=/dev/mmcblk0p5 \
    rootwait \
    init=/init \
    androidboot.hardware=sun50iw9 \
    androidboot.selinux=permissive

BOARD_KERNEL_BASE        := 0x40000000
BOARD_KERNEL_PAGESIZE    := 4096
BOARD_KERNEL_OFFSET      := 0x00080000
BOARD_RAMDISK_OFFSET     := 0x05000000
BOARD_KERNEL_TAGS_OFFSET := 0x00000100

# ═══════════════════════════════════════════════════════════════════════════════
# PARTITIONS
# ═══════════════════════════════════════════════════════════════════════════════

BOARD_BOOTIMAGE_PARTITION_SIZE         := 67108864    # 64 MB
BOARD_SYSTEMIMAGE_PARTITION_SIZE       := 2684354560  # 2.5 GB
BOARD_VENDORIMAGE_PARTITION_SIZE       := 536870912   # 512 MB
BOARD_USERDATAIMAGE_PARTITION_SIZE     := 4294967296  # 4 GB

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE    := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE    := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE  := f2fs

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# ═══════════════════════════════════════════════════════════════════════════════
# BOOT/RECOVERY IMAGE
# ═══════════════════════════════════════════════════════════════════════════════

BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_HAS_NO_SELECT_BUTTON   := true
BOARD_SUPPRESS_EMMC_WIPE     := true

# ═══════════════════════════════════════════════════════════════════════════════
# SELINUX
# ═══════════════════════════════════════════════════════════════════════════════

BOARD_SEPOLICY_DIRS += device/softwinner/zero3/sepolicy

# ═══════════════════════════════════════════════════════════════════════════════
# GRAPHICS
# ═══════════════════════════════════════════════════════════════════════════════

TARGET_USES_HWC2 := true
NUM_FRAMEBUFFER_SURFACE_BUFFERS := 3

# ═══════════════════════════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════════════════════════

AUDIO_FEATURE_ENABLED_DEFAULT_STEREO_SPEAKER := true

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD METADATA
# ═══════════════════════════════════════════════════════════════════════════════

BOARD_VENDOR_KERNEL_MODULES_LOAD := \
    sunxi_mmc.ko \
    sunxi_wlan.ko \
    mali_kbase.ko
