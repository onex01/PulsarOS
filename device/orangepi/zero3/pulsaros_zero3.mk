# PulsarOS product definition for Orange Pi Zero 3 (Allwinner H618 / Mali G31 MP2)
# Inherits from AOSP generic tablet (NOT TV — we use our own launcher).

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# ── Device tree ──────────────────────────────────────────────────────────────
$(call inherit-product, device/orangepi/zero3/device.mk)

# ── Vendor overlays ──────────────────────────────────────────────────────────
$(call inherit-product, vendor/pulsaros/pulsaros-vendor.mk)

# ── Identity ─────────────────────────────────────────────────────────────────
PRODUCT_NAME   := pulsaros_zero3      # MUST match filename stem
PRODUCT_DEVICE := zero3
PRODUCT_BRAND  := PulsarOS
PRODUCT_MODEL  := PulsarOS for Orange Pi Zero 3
PRODUCT_MANUFACTURER := Allwinner

# ── Locales ──────────────────────────────────────────────────────────────────
PRODUCT_LOCALES := en_US ru_RU

# ── Characteristics: tablet (not TV, not phone) ───────────────────────────────
PRODUCT_CHARACTERISTICS := tablet,nosdcard

# ── No GMS / no Google services ──────────────────────────────────────────────
PRODUCT_PACKAGES += \
    FakeGapps

# ── PulsarOS apps ────────────────────────────────────────────────────────────
PRODUCT_PACKAGES += \
    PulsarSetup \
    ConsoleLauncher \
    TVBro

# ── Prebuilt APKs (RetroArch, ES-DE, Kodi) ───────────────────────────────────
PRODUCT_PACKAGES += \
    RetroArch \
    EmulationStation \
    Kodi

# ── System properties ─────────────────────────────────────────────────────────
PRODUCT_PRODUCT_PROPERTIES += \
    ro.pulsar.version=$(PULSAR_VERSION) \
    ro.pulsar.build_type=$(PULSAR_BUILD_TYPE) \
    persist.sys.locale=en-US \
    persist.sys.timezone=UTC \
    ro.setupwizard.mode=DISABLED

# ── Build version ─────────────────────────────────────────────────────────────
PRODUCT_VERSION_MAJOR := 0
PRODUCT_VERSION_MINOR := 1
PULSAR_VERSION        := $(PRODUCT_VERSION_MAJOR).$(PRODUCT_VERSION_MINOR).0-dev