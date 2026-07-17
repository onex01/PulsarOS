# PulsarOS

> **English** | [Русский](#pulsaros-русский)

> Android 12 gaming firmware for the Orange Pi Zero 3 (Allwinner H618).
> Plug-and-play retro gaming console — flash, connect gamepad, play.

PulsarOS transforms the Orange Pi Zero 3 into a dedicated retro gaming console
connected to any monitor or TV. Built on Android 12 with full GPU acceleration
(Mali G31 MP2, OpenGL ES 3.2, Vulkan 1.1).

## Features

- **Plug and play** — flash the image, connect a gamepad, and start playing.
  No terminal, no configuration files, no internet required.
- **28 gaming systems** — NES, SNES, Game Boy, GBA, N64, NDS, Mega Drive,
  PlayStation, PSP, arcade, Atari, MSX, WonderSwan, and more.
- **Auto-detect gamepads** — Xbox, PlayStation, Nintendo Switch Pro, 8BitDo,
  and 30+ controllers work out of the box via USB or Bluetooth.
- **External storage** — plug in a USB drive with `PulsarOS/roms/` and games
  are detected automatically. No file transfers needed.
- **Daijishou** — open-source retro launcher with widgets, themes, and
  RetroAchievements support. Manages your game library with artwork and metadata.
- **RetroArch** — preloaded with 24 optimized cores for ARM Cortex-A53.
- **Kodi** — video and audio playback from `PulsarOS/video/` and `PulsarOS/audio/`.
- **OOBE wizard** — guided first-run setup: language, gamepad, network, display.
- **Web file manager** — upload ROMs and media from any browser on your network.
- **Custom boot animation** — gradient sweep of PulsarOS logo.
- **F-Droid** — open-source app store for additional applications.
- **SSH access** — remote management via dropbear SSH server.
- **Dark theme** — enabled by default for better visibility.

## Hardware

| Board | SoC | RAM | Status |
|---|---|---|---|
| Orange Pi Zero 3 | Allwinner H618, Mali G31 MP2 | 1–4 GB | Primary target |

## Requirements

- Orange Pi Zero 3 (any RAM variant)
- microSD card (16GB+, A2 recommended)
- Gamepad (USB or Bluetooth) — or keyboard+mouse
- Power supply (5V/3A USB-C)
- Monitor/TV via micro-HDMI

## Building

### Prerequisites

- Ubuntu 22.04 LTS (x86_64) — recommended by Allwinner
- 16+ GB RAM (32 GB recommended)
- 300+ GB SSD
- Orange Pi Android 12 BSP source

### Quick Start

```bash
# 1. Clone PulsarOS
git clone https://github.com/one/PulsarOS.git
cd PulsarOS

# 2. Run the interactive build system
bash scripts/build.sh

# 3. Select "7) Auto Build" — follows all steps automatically
```

### Build Pipeline

```
1. Build Android    → scripts/build.sh → 5)
2. Create image     → scripts/build.sh → 6) (imgRePacker)
3. Flash to SD card → sudo scripts/flash-sdcard.sh out/pulsaros-v7.img /dev/sdX
```

### Manual Build Steps

```bash
# Build Android (with BSP patches + PulsarOS integration)
bash scripts/build.sh  # → 5) Build Android

# Create IMAGEWTY (stock firmware + our super.fex)
bash scripts/build.sh  # → 6) Create Image

# Flash to SD card (Linux, no Windows needed)
sudo ./scripts/flash-sdcard.sh out/pulsaros-v7.img /dev/sdX
```

### Variants

| Variant | GMS | F-Droid | Description |
|---------|-----|---------|-------------|
| Vanilla | ❌ | ✅ | No Google services, open-source only |
| GMS | ✅ | ✅ | Google Play Store + Play Services |

## Project Structure

```
PulsarOS/
├── scripts/                        # Modular build system (v3.0)
│   ├── build.sh                    # Entry point — menu + auto-build
│   ├── lib/common.sh               # Colors, logging, helpers
│   ├── lib/config.sh               # Configuration management
│   └── steps/                      # One file per build step
│       ├── 00-setup-system.sh      # Install dependencies
│       ├── 01-configure.sh         # Set source path
│       ├── 02-download-apks.sh     # Download APKs
│       ├── 03-build-cores.sh       # Download libretro cores
│       ├── 04b-build-longan.sh     # Build longan (kernel + bootloader)
│       ├── 05-build-android.sh     # Build Android
│       ├── 06-create-image.sh      # Create firmware image
│       ├── 07-flash.sh             # Flash to SD
│       ├── 08-install-logo.sh      # Install boot logo
│       ├── 09-clean.sh             # Clean build artifacts
│       └── 10-view-log.sh          # View build logs
├── device/softwinner/zero3/        # Device tree (H618 board config)
├── vendor/pulsaros/                # Vendor overlays (configs, scripts, APKs)
├── packages/apps/PulsarSetup/      # OOBE wizard (Kotlin)
├── patches/android-source/         # Source patches for BSP
├── docs/                           # Documentation
└── PROJECT_CONTEXT.md              # Full project context
```

See [docs/REPOSITORY-STRUCTURE.md](docs/REPOSITORY-STRUCTURE.md) for complete inventory.

## Documentation

| Document | Description |
|----------|-------------|
| [BUILD.md](docs/BUILD.md) | Build instructions (EN+RU) |
| [FLASHING.md](docs/FLASHING.md) | Flashing to SD card |
| [IMAGE-FORMAT.md](docs/IMAGE-FORMAT.md) | Allwinner IMAGEWTY format |
| [REPOSITORY-STRUCTURE.md](docs/REPOSITORY-STRUCTURE.md) | Full repo inventory |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and fixes |
| [HARDWARE.md](docs/HARDWARE.md) | Compatible hardware |
| [SOURCES.md](docs/SOURCES.md) | Source code links |
| [LICENSE-STRATEGY.md](docs/LICENSE-STRATEGY.md) | Licensing approach |
| [BUILD-SYSTEM-FIX.md](docs/BUILD-SYSTEM-FIX.md) | Overlay patching model |
| [COMPLIANCE-CHECKLIST.md](docs/COMPLIANCE-CHECKLIST.md) | Pre-release checklist |

## Supported Gamepads

| Gamepad | Connection | Status |
|---------|-----------|--------|
| Xbox Series X/S | BT/USB | Auto-detect |
| PlayStation DualSense | BT/USB | Auto-detect |
| DualShock 4 | BT/USB | Auto-detect |
| Nintendo Switch Pro | BT/USB | Auto-detect |
| Nintendo Joy-Con | BT | Auto-detect |
| 8BitDo (all models) | BT/USB | Auto-detect |
| GameSir T4 Pro/Mini | BT/USB | Auto-detect |
| Generic USB HID | USB | Works |
| Any BT gamepad | BT | Manual pairing |

## Supported Systems (28)

| Category | Systems |
|----------|---------|
| Nintendo | NES, SNES, Game Boy, GBC, GBA, N64, NDS |
| Sega | Master System, Game Gear, Mega Drive, Sega CD, 32X |
| Sony | PlayStation, PSP |
| Arcade | FBNeo, MAME 2003+, Neo Geo |
| Atari | 2600, 7800, Lynx, 8-bit |
| Other | MSX, WonderSwan, Pokemon Mini, Amiga |
| Engines | ScummVM, Doom |

## License

PulsarOS core is MIT licensed. Third-party components retain their original
licenses (RetroArch LGPL, Daijishou MIT, Kodi GPL, AOSP Apache 2.0).

See [docs/LICENSE-STRATEGY.md](docs/LICENSE-STRATEGY.md) for details.

---

# PulsarOS (Русский)

> Прошивка Android 12 для Orange Pi Zero 3 (Allwinner H618).
> Готовая к использованию консоль для ретро-игр — прошей, подключи геймпад, играй.

PulsarOS превращает Orange Pi Zero 3 в dedicated консоль для ретро-игр,
подключённую к любому монитору или ТВ. Построена на Android 12 с полным
ускорением GPU (Mali G31 MP2, OpenGL ES 3.2, Vulkan 1.1).

## Возможности

- **Plug and play** — прошейте образ, подключите геймпад и начните играть
- **28 игровых систем** — NES, SNES, Game Boy, GBA, N64, NDS, Mega Drive, PlayStation, PSP, аркады, Atari и др.
- **Автоопределение геймпадов** — Xbox, PlayStation, Nintendo Switch Pro, 8BitDo и 30+ контроллеров
- **Внешнее хранилище** — USB флешка с `PulsarOS/roms/` определяется автоматически
- **Daijishou** — лаунчер с виджетами, темами и RetroAchievements
- **RetroArch** — 24 оптимизированных ядра для ARM Cortex-A53
- **Kodi** — воспроизведение видео и аудио
- **OOBE мастер** — пошаговая настройка при первом запуске

## Железо

| Плата | SoC | ОЗУ | Статус |
|---|---|---|---|
| Orange Pi Zero 3 | Allwinner H618, Mali G31 MP2 | 1–4 GB | Основная цель |

## Требования

- Orange Pi Zero 3 (любой вариант ОЗУ)
- MicroSD карта (16GB+, рекомендуется A2)
- Геймпад (USB или Bluetooth)
- Блок питания (5V/3A USB-C)
- Монитор/ТВ через micro-HDMI

## Сборка

### Быстрый старт

```bash
# 1. Клонировать PulsarOS
git clone https://github.com/one/PulsarOS.git
cd PulsarOS

# 2. Запустить интерактивную систему сборки
bash scripts/build.sh

# 3. Выбрать "1) Автосборка"
```

Подробные инструкции: [docs/BUILD.md](docs/BUILD.md)

### Структура сборки

Система сборки v3.0 — модульная:
- `scripts/build.sh` — точка входа (меню + автосборка)
- `scripts/lib/` — общие функции (логирование, конфигурация)
- `scripts/steps/` — по одному файлу на каждый шаг сборки

Каждый шаг можно запустить отдельно:
```bash
source scripts/lib/common.sh
source scripts/lib/config.sh
source scripts/steps/03-build-cores.sh
step_build_cores
```

## Документация

| Документ | Описание |
|----------|----------|
| [BUILD.md](docs/BUILD.md) | Инструкция по сборке (EN+RU) |
| [FLASHING.md](docs/FLASHING.md) | Прошивка на SD карту |
| [IMAGE-FORMAT.md](docs/IMAGE-FORMAT.md) | Формат Allwinner IMAGEWTY |
| [REPOSITORY-STRUCTURE.md](docs/REPOSITORY-STRUCTURE.md) | Структура репозитория |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Решение проблем |
| [HARDWARE.md](docs/HARDWARE.md) | Совместимое оборудование |
| [SOURCES.md](docs/SOURCES.md) | Ссылки на исходники |
| [LICENSE-STRATEGY.md](docs/LICENSE-STRATEGY.md) | Стратегия лицензирования |

## Поддерживаемые системы (28)

| Категория | Системы |
|-----------|---------|
| Nintendo | NES, SNES, Game Boy, GBC, GBA, N64, NDS |
| Sega | Master System, Game Gear, Mega Drive, Sega CD, 32X |
| Sony | PlayStation, PSP |
| Аркады | FBNeo, MAME 2003+, Neo Geo |
| Atari | 2600, 7800, Lynx, 8-bit |
| Другие | MSX, WonderSwan, Pokemon Mini, Amiga |
| Движки | ScummVM, Doom |

## Лицензия

Ядро PulsarOS — MIT. Сторонние компоненты сохраняют свои лицензии.
См. [docs/LICENSE-STRATEGY.md](docs/LICENSE-STRATEGY.md).

---

*Последнее обновление: 2026-07-17*
