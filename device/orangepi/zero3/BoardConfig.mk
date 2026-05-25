# =============================================================================
# PulsarOS — BoardConfig.mk
# Orange Pi Zero 3 | SoC: Allwinner H618 | GPU: Mali G31 MP2
# Наследует конфиг базовой платы p2 из Orange Pi BSP
# =============================================================================

# Наследуем конфигурацию платы p2 из Orange Pi BSP
# (apollo_p2 = H618, board variant p2 = Orange Pi Zero 3)
-include device/softwinner/apollo-p2/BoardConfig.mk

# Переопределяем идентификацию
TARGET_DEVICE := zero3
TARGET_PRODUCT := pulsaros_zero3

# Архитектура — ARM64 (Cortex-A53 × 4)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53

# 32-bit libs (для совместимости со старыми ядрами эмуляторов)
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53

# GPU — Mali G31 MP2
# Используем проприетарный blob из Orange Pi BSP (OpenGL ES 3.2, Vulkan 1.1)
BOARD_GPU_DRIVERS := mali-g31

# Display — micro-HDMI, до 4K@60Hz
TARGET_SCREEN_DENSITY := 213

# Раздел System (размер зависит от конкретного BSP)
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2147483648  # 2GB
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4

# Vendor partition
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912   # 512MB
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4

# Userdata
BOARD_USERDATAIMAGE_PARTITION_SIZE := 4294967296  # 4GB (остаток SD)
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4

# Kernel (берём из longan, собранный отдельно)
TARGET_NO_KERNEL := false
TARGET_KERNEL_SOURCE := kernel/linux-5.4
TARGET_KERNEL_CONFIG := sun50iw9p1smp_h618_android_defconfig

# ADB / USB
BOARD_USES_USBDISK := true

# Верификация (Verified Boot)
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3  # отключаем принудительную проверку для dev
