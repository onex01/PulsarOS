# =============================================================================
# PulsarOS — pulsaros.mk
# Главный product makefile
# Наследует apollo_p2 (Orange Pi H618) и переопределяет под gaming-консоль
# =============================================================================

# Базовый product от Orange Pi (содержит BSP, драйверы, Mali blob)
$(call inherit-product, device/softwinner/apollo-p2/apollo_p2.mk)

# Android Gaming / Tablet base (не TV!)
# Убираем Leanback / Google TV компоненты
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# PulsarOS vendor overlay (prebuilt APK, конфиги, скрипты)
$(call inherit-product, vendor/pulsaros/pulsaros-vendor.mk)

# ── Идентификация продукта ────────────────────────────────────────────────────
PRODUCT_NAME    := pulsaros_zero3
PRODUCT_DEVICE  := zero3
PRODUCT_BRAND   := PulsarOS
PRODUCT_MODEL   := PulsarOS Zero3
PRODUCT_MANUFACTURER := OnexOS
PRODUCT_CHARACTERISTICS := gaming,tv

# Версия прошивки (инжектируется из build.sh через переменные окружения)
PULSAROS_VERSION      ?= 0.1.0-dev
PULSAROS_BUILD_TYPE   ?= debug
PULSAROS_BUILD_DATE   ?= unknown

PRODUCT_BUILD_PROP_OVERRIDES += \
    ro.pulsaros.version=$(PULSAROS_VERSION) \
    ro.pulsaros.build.type=$(PULSAROS_BUILD_TYPE) \
    ro.pulsaros.build.date=$(PULSAROS_BUILD_DATE) \
    ro.product.name=PulsarOS \
    ro.product.model=PulsarOS\ Zero3 \
    ro.product.brand=PulsarOS \
    ro.product.manufacturer=OnexOS

# ── Убираем TV-специфичные компоненты ────────────────────────────────────────
# Отключаем Google TV / Leanback launcher
PRODUCT_PACKAGES_DEL += \
    TvProvider \
    TvSettings \
    LiveTv \
    TvSampleApp

# Отключаем TV Input Framework (не нужен для консоли)
PRODUCT_COPY_FILES += \
    device/orangepi/zero3/config/component_enabled_state_default_tv_input.xml:system/etc/sysconfig/component_enabled_state_default_tv_input.xml

# ── Производительность CPU/GPU ────────────────────────────────────────────────
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.max_starting_bg=8 \
    ro.sys.fw.bservice_age=5000 \
    ro.sys.fw.bservice_limit=5 \
    ro.sys.fw.bservice_enable=true \
    ro.vendor.extension_library=libqti-perfd-client.so

# CPU Governor — schedutil в обычном режиме, performance в играх
PRODUCT_PROPERTY_OVERRIDES += \
    ro.cpu_governor_default=schedutil \
    ro.cpu_governor_game=performance

# ZRAM (важно для версий с 1GB RAM)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.zram.size=512m

# ── Дисплей ───────────────────────────────────────────────────────────────────
# Поддержка высокой частоты обновления (120Hz, 144Hz)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.surface_flinger.set_touch_timer_ms=0 \
    ro.surface_flinger.set_display_power_timer_ms=0 \
    ro.surface_flinger.use_content_detection_for_refresh_rate=true \
    ro.surface_flinger.game_default_frame_rate_override=60

# ── ADB / SSH (управляется из build.sh) ──────────────────────────────────────
ifeq ($(PULSAROS_ADB_ENABLED),true)
    PRODUCT_PROPERTY_OVERRIDES += ro.adb.secure=0
    PRODUCT_DEFAULT_PROPERTY_OVERRIDES += service.adb.tcp.port=5555
else
    PRODUCT_PROPERTY_OVERRIDES += ro.adb.secure=1
endif

# ── Геймпады ─────────────────────────────────────────────────────────────────
# Разрешаем вибрацию геймпадов через kernel haptic API
PRODUCT_COPY_FILES += \
    device/orangepi/zero3/config/gamepad_vibrator_whitelist.xml:system/etc/gamepad_vibrator_whitelist.xml

# Bluetooth геймпады — нативная поддержка Android
PRODUCT_PACKAGES += \
    bluetooth.default

# ── Предустановленные приложения ──────────────────────────────────────────────
PRODUCT_PACKAGES += \
    PulsarSetup \
    ConsoleLauncher \
    TVBro

# ── Хранилище ─────────────────────────────────────────────────────────────────
# Автоматическое монтирование USB/SD
PRODUCT_PROPERTY_OVERRIDES += \
    persist.fuse.force_readahead=1 \
    ro.vold.primary_physical=1

# ── RRO Overlays ─────────────────────────────────────────────────────────────
PRODUCT_PACKAGES += \
    PulsarOSSettingsOverlay \
    PulsarOSFrameworkOverlay

# ── Локализация ───────────────────────────────────────────────────────────────
PRODUCT_LOCALES := en_US ru_RU uk_UA de_DE fr_FR es_ES zh_CN ja_JP ko_KR
PRODUCT_DEFAULT_LOCALE := en_US

# ── Разное ───────────────────────────────────────────────────────────────────
# Отключаем SELinux permissive только в debug
ifeq ($(PULSAROS_BUILD_TYPE),debug)
    PRODUCT_PROPERTY_OVERRIDES += ro.build.selinux=0
endif

PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.timezone=UTC \
    ro.setupwizard.mode=DISABLED
