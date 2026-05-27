# device.mk — hardware-specific config for Orange Pi Zero 3

LOCAL_PATH := device/orangepi/zero3

# ── Permissions / features ────────────────────────────────────────────────────
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.ethernet.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.ethernet.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml

# ── RRO overlays ─────────────────────────────────────────────────────────────
PRODUCT_PACKAGE_OVERLAYS += \
    device/orangepi/zero3/overlay

# ── FSTAB ────────────────────────────────────────────────────────────────────
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/fstab.zero3:$(TARGET_COPY_OUT_RAMDISK)/fstab.zero3 \
    $(LOCAL_PATH)/fstab.zero3:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.zero3

# ── Init scripts ─────────────────────────────────────────────────────────────
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/init.zero3.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.zero3.rc \
    $(LOCAL_PATH)/init.zero3.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.zero3.usb.rc

# ── Audio ─────────────────────────────────────────────────────────────────────
USE_XML_AUDIO_POLICY_CONF := 1

# ── Display ───────────────────────────────────────────────────────────────────
TARGET_SCREEN_DENSITY := 213