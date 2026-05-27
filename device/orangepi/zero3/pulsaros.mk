# PRODUCT_NAME ДОЛЖЕН БЫТЬ ПЕРВОЙ ПЕРЕМЕННОЙ В ФАЙЛЕ
PRODUCT_NAME := pulsaros_zero3
PRODUCT_DEVICE := zero3
PRODUCT_BRAND := PulsarOS
PRODUCT_MODEL := PulsarOS Console (Orange Pi Zero 3)
PRODUCT_MANUFACTURER := Orange Pi
PRODUCT_CHARACTERISTICS := tablet

# Минимальная база AOSP (проверка lunch)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_no_telephony.mk)

# Наши пакеты
PRODUCT_PACKAGES += \
    PulsarSetup \
    ConsoleLauncher \
    TVBro

# Свойства
PRODUCT_SYSTEM_PROPERTIES += \
    ro.pulsaros.version=0.1.0-dev \
    ro.pulsaros.device=zero3 \
    ro.setupwizard.mode=DISABLED
