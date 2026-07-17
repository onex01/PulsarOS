# Repository Structure / Структура репозитория

> [English](#english) | [Русский](#русский)

---

## English

### Overview

PulsarOS is an Android 12 firmware for the Orange Pi Zero 3 (Allwinner H618) — a plug-and-play retro gaming handheld console.

### Directory Tree

```
PulsarOS/
├── scripts/                        # Build system (modular, v3.0)
│   ├── build.sh                    # Entry point — menu, auto-build pipeline
│   ├── lib/
│   │   ├── common.sh               # Colors, logging, msg_*, run_cmd
│   │   └── config.sh               # Config management, default values
│   ├── steps/
│   │   ├── 00-setup-system.sh      # Install build dependencies (apt, repo, NDK)
│   │   ├── 01-configure.sh         # Set ANDROID_SRC path
│   │   ├── 02-download-apks.sh     # Download RetroArch, Daijishou, Kodi, TV Bro
│   │   ├── 03-build-cores.sh       # Download 24 libretro cores from buildbot
│   │   ├── 04b-build-longan.sh     # Build longan (kernel + bootloader)
│   │   ├── 05-build-android.sh     # Sync overlays → AOSP build
│   │   ├── 06-create-image.sh      # Create firmware image (pack or dd-concat)
│   │   ├── 07-flash.sh             # Flash image to SD card
│   │   ├── 08-install-logo.sh      # Install bootlogo.bmp to BSP
│   │   ├── 09-clean.sh             # Clean build artifacts
│   │   └── 10-view-log.sh          # View last build log
│   ├── sync_and_backup.sh          # Sync overlays into Android source (rsync)
│   ├── rollback_overlays.sh        # Rollback overlay changes
│   ├── fix-libcedarx-macros.sh     # Fix CONF_ANDROID_MAJOR_VER conflicts
│   ├── check-licenses.sh           # License header checker
│   ├── flash.sh                    # Simple SD card flasher
│   └── setup-env.sh                # Minimal build env setup
│
├── device/softwinner/zero3/        # Android device tree
│   ├── AndroidProducts.mk          # Product definition (lunch choices)
│   ├── BoardConfig.mk              # Board config (arch, kernel, GPU, partitions)
│   ├── device.mk                   # Device makefile (permissions, overlays)
│   ├── pulsaros_zero3.mk           # Product makefile (packages, properties)
│   ├── fstab.zero3                 # Filesystem table (system, vendor, userdata f2fs)
│   ├── init.zero3.rc               # Init script (mount, GPU, thermal, charger)
│   ├── init.zero3.usb.rc           # USB gadget config (ADB, MTP, RNDIS, MIDI)
│   ├── config/
│   │   ├── manifest.xml            # VINTF manifest (HAL declarations)
│   │   ├── thermal-engine.conf     # Thermal policy (75°C throttle, 95°C shutdown)
│   │   ├── gamepad_vibrator_whitelist.xml
│   │   └── component_enabled_state_default_tv_input.xml
│   └── overlay/frameworks/base/core/res/values/config.xml
│                                    # RRO overlay (launcher, gamepad nav, etc.)
│
├── vendor/pulsaros/                # Vendor overlays
│   ├── pulsaros-vendor.mk          # Vendor makefile (dropbear, configs, props)
│   ├── debloat.mk                  # Remove unused AOSP apps
│   ├── boot-logo/
│   │   └── bootlogo.bmp            # Boot splash (800x480 BMP)
│   ├── bootanimation/
│   │   └── bootanimation.zip       # Custom boot animation
│   ├── config/
│   │   ├── retroarch/
│   │   │   ├── retroarch.cfg       # RetroArch config (GL, audio, input, paths)
│   │   │   └── cores-whitelist.txt # 26 cores by category
│   │   ├── esde/
│   │   │   ├── es_systems.xml      # 28 system definitions
│   │   │   └── es_settings.xml     # ES-DE settings
│   │   └── daijishou/
│   │       └── platforms.json      # 28 gaming system configs
│   ├── scripts/
│   │   ├── init.pulsaros.rc        # Init: SSH, ZRAM, storage-watcher
│   │   ├── set-resolution.sh       # Display resolution setter
│   │   ├── ssh-toggle.sh           # Dropbear SSH manager
│   │   └── storage-watcher.sh      # Auto-create PulsarOS dirs on storage
│   └── prebuilt/
│       ├── Android.bp              # APK + cores build rules
│       ├── apk/                    # Prebuilt APKs (RetroArch, Daijishou, Kodi, TV Bro)
│       └── cores/                  # 24 libretro .so files (armeabi-v7a)
│
├── packages/apps/PulsarSetup/      # OOBE wizard (Kotlin)
│   ├── Android.bp                  # Build config
│   ├── AndroidManifest.xml         # Package manifest
│   ├── src/com/pulsaros/setup/     # Kotlin sources (9-step wizard)
│   └── res/                        # Layouts, drawables, strings, themes
│
├── patches/android-source/         # BSP patches (4 files)
│   ├── 0001-libcedarc-vencoderDemo.patch
│   ├── 0002-libcedarx-liblive555-32bit-only.patch
│   ├── 0004-libcedarx-sun50iw9-board-config.patch
│   └── 0005-build-soong-binder-32bit-cast.patch
│
├── docs/                           # Documentation
│   ├── BUILD.md                    # Build instructions (EN+RU)
│   ├── BUILD-SYSTEM-FIX.md         # Overlay patching model
│   ├── FLASHING.md                 # Flashing instructions
│   ├── HARDWARE.md                 # Compatible hardware
│   ├── LICENSE-STRATEGY.md         # Licensing approach
│   ├── SOURCES.md                  # Source links
│   ├── COMPLIANCE-CHECKLIST.md     # Pre-release checklist
│   ├── REPOSITORY-STRUCTURE.md     # This file
│   ├── IMAGE-FORMAT.md             # Allwinner IMAGEWTY format
│   └── TROUBLESHOOTING.md          # Common issues
│
├── .github/workflows/              # CI/CD
│   ├── build-debug.yml             # Debug build on push
│   └── build-release.yml           # Release build on tag
│
├── README.md                       # Project overview (bilingual)
├── PROJECT_CONTEXT.md              # Full context for AI assistants
├── VERSION                         # 0.1.0-dev
├── LICENSE                         # MIT
├── NOTICE                          # Third-party notices
└── .gitignore                      # Build outputs, IDE, prebuilt
```

### Key Design Decisions

1. **Modular build script**: Each step is an independent `.sh` file in `steps/`, sourced by `build.sh`
2. **Overlay model**: PulsarOS files are synced into Android source via `rsync` (no `--delete`), with timestamped backups
3. **32-bit ARM userspace**: H618 requires 32-bit Android despite 64-bit kernel
4. **Prebuilt cores**: Libretro cores downloaded from buildbot (not compiled from source)
5. **IMAGEWTY format**: Firmware uses Allwinner's proprietary image format via `pack` tool

---

## Русский

### Обзор

PulsarOS — прошивка Android 12 для Orange Pi Zero 3 (Allwinner H618) — готовая к использованию консоль для ретро-игр.

### Структура каталогов

(См. английскую секцию выше — структура идентична)

Ключевые отличия от стандартного Android:
- **Устройство**: `device/softwinner/zero3/` — дерево устройства для H618
- **Вендор**: `vendor/pulsaros/` — оверлеи, APK, ядра, логотип, скрипты
- **Приложения**: `packages/apps/PulsarSetup/` — мастер начальной настройки (OOBE)
- **Скрипты**: `scripts/` — модульная система сборки v3.0
- **Патчи**: `patches/` — исправления для Android BSP
