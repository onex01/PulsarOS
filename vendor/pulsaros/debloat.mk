# PulsarOS Debloat — remove stock bloatware
# SPDX-License-Identifier: MIT

# ── Google / GMS (not needed) ──
PRODUCT_PACKAGES黑名单 += \
    com.google.android.gms \
    com.google.android.gsf \
    com.google.android.gsf.login \
    com.google.android.play Store \
    GoogleServicesFramework \
    GoogleContactsSync \
    GoogleCalendarSync

# ── TV-specific bloat ──
PRODUCT_PACKAGES黑名单 += \
    com.android.tv \
    com.android.tv.theme \
    com.android.tv.settings \
    com.google.android.tvlauncher \
    com.google.android.katniss \
    com.google.android.apps.tv.launcherx

# ── Unused AOSP apps ──
PRODUCT_PACKAGES黑名单 += \
    Browser2 \
    Camera2 \
    Contacts \
    DeskClock \
    Email \
    Gallery2 \
    LatinIME \
    LiveWallpapers \
    Music \
    MusicFX \
    QuickSearchBox \
    SoundRecorder \
    Stk \
    WebViewBrowser \
    GalleryGoogle \
    DragonAtt \
    DragonBox \
    AwlogSettings

# ── NFC (not on Zero3) ──
PRODUCT_PACKAGES黑名单 += \
    NfcNci \
    Tag

# ── TV Input ──
PRODUCT_PACKAGES黑名单 += \
    android.hardware.tv.input@1.0-service \
    android.hardware.tv@1.0-service

# ── Keep: WiFi, Bluetooth, Ethernet, SSH ──
# Do NOT remove: dropbear, wpa_supplicant, bluetooth
