# PulsarOS product definition for Orange Pi Zero 3 (Allwinner H618 / Mali G31 MP2)
# Inherits from AOSP generic tablet (NOT TV — we use our own launcher).

PRODUCT_PLATFORM_PATH := $(shell dirname $(lastword $(MAKEFILE_LIST)))

# ── Base AOSP products ────────────────────────────────────────────────────────
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# ── Allwinner common configs ──────────────────────────────────────────────────
$(call inherit-product, device/softwinner/apollo/common/media/config.mk)
$(call inherit-product, device/softwinner/apollo/common/system/config.mk)
$(call inherit-product, device/softwinner/apollo/common/display/config.mk)
$(call inherit-product, device/softwinner/apollo/common/input/config.mk)
$(call inherit-product, device/softwinner/apollo/common/storage/config.mk)
$(call inherit-product, device/softwinner/apollo/common/overlay/config.mk)
$(call inherit-product, device/softwinner/apollo/common/misc/config.mk)

# ── Device tree ───────────────────────────────────────────────────────────────
$(call inherit-product, device/softwinner/zero3/device.mk)

# ── Vendor overlays ───────────────────────────────────────────────────────────
$(call inherit-product, vendor/pulsaros/pulsaros-vendor.mk)

# ── Identity ──────────────────────────────────────────────────────────────────
PRODUCT_PLATFORM_PATH := $(shell dirname $(lastword $(MAKEFILE_LIST)))
TARGET_BOARD_IC       := h618
PRODUCT_PREBUILT_PATH := longan/out/$(TARGET_BOARD_IC)/p2/android
PRODUCT_BRAND         := Allwinner
PRODUCT_NAME          := pulsaros_zero3      # MUST match filename stem
PRODUCT_DEVICE        := zero3               # device folder name
PRODUCT_BOARD         := zero3
PRODUCT_MODEL         := PulsarOS for Orange Pi Zero 3
PRODUCT_MANUFACTURER  := Allwinner

PRODUCT_COPY_FILES += \
    $(PRODUCT_PREBUILT_PATH)/bImage:kernel

# ── Locales ───────────────────────────────────────────────────────────────────
PRODUCT_LOCALES := en_US ru_RU

# ── Characteristics: tablet (not TV, not phone) ───────────────────────────────
PRODUCT_CHARACTERISTICS := tablet,nosdcard

# ── No GMS / no Google services ───────────────────────────────────────────────
PRODUCT_PACKAGES += \
    FakeGapps

# ── Disable uses-library check for prebuilt APKs ─────────────────────────────
PRODUCT_BROKEN_VERIFY_USES_LIBRARIES := true

# ── PulsarOS apps ────────────────────────────────────────────────────────────
PRODUCT_PACKAGES += \
    PulsarSetup \
    ConsoleLauncher \
    TVBro \
    Daijishou

# ── Prebuilt APKs (RetroArch, Kodi) ─────────────────────────────────────────
PRODUCT_PACKAGES += \
    RetroArch \
    Kodi

# ── System properties ────────────────────────────────────────────────────────
PRODUCT_PRODUCT_PROPERTIES_DEFAULT += \
    ro.pulsar.version=$(PULSAR_VERSION) \
    ro.pulsar.build_type=$(PULSAR_BUILD_TYPE) \
    persist.sys.locale=en-US \
    persist.sys.timezone=UTC \
    ro.setupwizard.mode=DISABLED

# ── Build version ────────────────────────────────────────────────────────────
PRODUCT_VERSION_MAJOR := 0
PRODUCT_VERSION_MINOR := 1
# BUILD_FINGERPRINT is intentionally omitted to use the Android build system default.
# Custom fingerprints may trigger obsolete BUILD_DATETIME handling in this BSP.
