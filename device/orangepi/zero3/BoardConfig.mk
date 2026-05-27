# Copyright (C) 2026 PulsarOS Project
# SPDX-License-Identifier: MIT
#
# BoardConfig.mk — Orange Pi Zero 3 (Allwinner H618, Cortex-A53 × 4, Mali G31 MP2)
#
# NOTE: не используем -include upstream — все переменные прописаны явно,
# чтобы сборка была детерминированной и независимой от внешних файлов.

LOCAL_PATH := device/orangepi/zero3

# ═══════════════════════════════════════════════════════════════════════════════
# ARCHITECTURE — ОБЯЗАТЕЛЬНЫЙ БЛОК (именно его не хватало)
# ═══════════════════════════════════════════════════════════════════════════════

TARGET_ARCH         := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI      := arm64-v8a
TARGET_CPU_VARIANT  := cortex-a53

# 32-bit secondary ABI (нужен для совместимости со старыми APK и RetroArch cores)
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
TARGET_NO_BOOTLOADER          := true       # U-Boot — не часть Android build
TARGET_NO_KERNEL              := false

# ═══════════════════════════════════════════════════════════════════════════════
# KERNEL
# ═══════════════════════════════════════════════════════════════════════════════

TARGET_KERNEL_ARCH        := arm64
TARGET_KERNEL_SOURCE      := kernel/orangepi/zero3
TARGET_KERNEL_CONFIG      := pulsaros_zero3_defconfig

# Если используем prebuilt ядро от Orange Pi (рекомендуется на старте):
TARGET_PREBUILT_KERNEL    := $(LOCAL_PATH)/prebuilt/kernel
BOARD_PREBUILT_DTBOIMAGE  := $(LOCAL_PATH)/prebuilt/dtbo.img
BOARD_PREBUILT_DTBIMAGE   := $(LOCAL_PATH)/prebuilt/sun50iw9p1-orangepi-zero3.dtb

# Аргументы командной строки ядра
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
BOARD_USERDATAIMAGE_PARTITION_SIZE     := 4294967296  # 4 GB (резервируем)

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE    := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE    := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE  := f2fs    # f2fs лучше для SD

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Dynamic partitions — выключаем, Orange Pi BSP их не использует
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false
BOARD_USES_METADATA_PARTITION := false

# ═══════════════════════════════════════════════════════════════════════════════
# GPU — Mali G31 MP2
# ═══════════════════════════════════════════════════════════════════════════════

BOARD_USES_LIBMALI        := true
USE_OPENGL_RENDERER       := true
TARGET_USES_HWC2          := true
TARGET_USES_GRALLOC1      := true
NUM_FRAMEBUFFER_SURFACE_BUFFERS := 3

# Не используем swiftshader/softpipe — только blob
TARGET_USES_VULKAN        := true

# ═══════════════════════════════════════════════════════════════════════════════
# DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

TARGET_SCREEN_DENSITY := 213
SF_PRIMARY_DISPLAY_ORIENTATION := 0    # landscape

# ═══════════════════════════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════════════════════════

USE_XML_AUDIO_POLICY_CONF := 1
BOARD_USES_ALSA_AUDIO     := true

# ═══════════════════════════════════════════════════════════════════════════════
# CONNECTIVITY
# ═══════════════════════════════════════════════════════════════════════════════

BOARD_WLAN_DEVICE            := xr829      # WiFi chip на Zero 3
BOARD_HOSTAPD_DRIVER         := NL80211
BOARD_WPA_SUPPLICANT_DRIVER  := NL80211
WPA_SUPPLICANT_VERSION       := VER_0_8_X
WIFI_DRIVER_MODULE_NAME      := xradio_wlan
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true

BOARD_HAVE_BLUETOOTH         := true
BOARD_HAVE_BLUETOOTH_RTK     := true   # Bluetooth через XR829 (Realtek-совместимый)

# ═══════════════════════════════════════════════════════════════════════════════
# USB
# ═══════════════════════════════════════════════════════════════════════════════

TARGET_USE_CUSTOM_LUN_FILE_PATH := /config/usb_gadget/g1/functions/mass_storage.0/lun
BOARD_CHARGER_DISABLE_INIT_BLANK := true

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY / SELINUX
# ═══════════════════════════════════════════════════════════════════════════════

# Permissive на этапе разработки; переключим в enforcing перед Release
BOARD_SEPOLICY_DIRS += device/orangepi/zero3/sepolicy
SELINUX_IGNORE_NEVERALLOWS := true   # убрать перед первым public release

# ═══════════════════════════════════════════════════════════════════════════════
# MISC
# ═══════════════════════════════════════════════════════════════════════════════

BOARD_HAS_NO_SELECT_BUTTON := true
BOARD_FLASH_BLOCK_SIZE     := 131072   # 128 KB (512 * pagesize)

TARGET_COPY_OUT_VENDOR     := vendor

# Overlay
DEVICE_PACKAGE_OVERLAYS    += device/orangepi/zero3/overlay

# ZRAM
BOARD_ZRAM_SIZE_MB  := 1024
BOARD_USES_ZRAM     := true

# Deterministic build
BUILD_NUMBER        ?= 0