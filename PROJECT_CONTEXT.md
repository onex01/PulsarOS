# PulsarOS — Project Context & Instructions

> **For new AI conversations**: paste this entire file at the start.
> It contains the full project context, decision history, and current tasks.

---

## What is PulsarOS

PulsarOS is a custom Android 12 ROM for the **Orange Pi Zero 3** single-board computer
(SoC: Allwinner H618, GPU: Mali G31 MP2) that transforms it into a standalone
retro-gaming console connectable to a monitor/TV.

Goal: ArkOS / Rocknix-class system, but on Allwinner platform instead of RockChip,
and on Android instead of Linux.

**GitHub Repository**: `https://github.com/onex01/PulsarOS`
**License**: MIT (open-source, free to build)

---

## History: Why Android, not Linux

### Beginning (OrionOS on Armbian/Linux)

The project started as `OrionOS` — a firmware based on Armbian Debian with EmulationStation
and RetroArch. Repository: `https://github.com/onex01/OrionOS` (archived, legacy).

### The GPU Problem

After practical experiments, we discovered: **GPU acceleration doesn't work in Linux**
on Orange Pi Zero 3. Reasons:

- Orange Pi provides downstream Linux kernel 5.16 (not mainline)
- Mali G31 only works through proprietary blob from Arm
- Panfrost (open-source driver) is unstable/not integrated in this BSP
- Official Orange Pi distributions (Debian, Ubuntu, Arch) all use software rendering
- All emulation work ran on CPU, which is unacceptable for performance

### Solution: Android 12

Android 12 BSP from Orange Pi contains working Mali blob and full GPU acceleration
(OpenGL ES 3.2, Vulkan 1.1). The community has successfully run ES-DE and RetroArch
on Android builds for Zero 3. Switching to Android is the only way to get
proper GPU acceleration on this hardware.

**Result**: OrionOS (Linux) → archived. PulsarOS (Android 12) → active project.

---

## Hardware: Orange Pi Zero 3

| Component | Specifications |
|---|---|
| SoC | Allwinner H618, Cortex-A53 × 4, up to 1.5 GHz |
| GPU | Mali G31 MP2, OpenGL ES 3.2, Vulkan 1.1, OpenCL 2.0 |
| RAM | 1 / 1.5 / 2 / 4 GB LPDDR4 |
| Storage | microSD + 16 MB SPI Flash |
| Video | micro-HDMI up to 4K@60Hz |
| Network | Gigabit Ethernet, WiFi 5 (802.11ac), Bluetooth 5.0 |
| USB | 1× USB 2.0 (Type-A) + expansion board (2× more USB 2.0) |

**Official Android**: Android TV 12 (BSP from Orange Pi).
**Community Port**: OmniROM 12.1 (tablet, not TV) — works on Zero 3.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   BUILD PIPELINE                        │
│  Orange Pi Android 12 source + PulsarOS overlays        │
│  → GitHub Actions (self-hosted runner) / local          │
│  → DEBUG build (SSH on) / RELEASE build (SSH off)       │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│              ANDROID 12 BASE (tablet/gaming)            │
│  AOSP Android 12 + Orange Pi H618 BSP patches           │
│  Stripped: TV-specific components removed               │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                  SYSTEM SERVICES                        │
│  USB OTG automount │ BT gamepad pairing │ Display mgr   │
│  Storage watcher (PulsarOS dir) │ Web file server       │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│               PREINSTALLED APPS                         │
│                                                         │
│  Console Launcher (fork)   EmulationStation DE (ES-DE)  │
│  RetroArch + cores         Kodi (video/audio)           │
│  TV Bro (browser, fork)    PulsarOS Setup (OOBE)        │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                STORAGE LAYOUT                           │
│  SD / USB → /storage/PulsarOS/                          │
│    roms/   video/   audio/   other/                     │
│  Auto-discovered by ES-DE and Kodi                      │
└─────────────────────────────────────────────────────────┘
```

---

## Components (What and From Where)

### Launcher: Console Launcher (fork)
- **Source**: `github.com/likeich/console-launcher` (open-source)
- **License**: verify before forking
- **Why**: gamepad navigation out of the box, auto ROM scanning, RetroArch core integration,
  guided onboarding, RetroAchievements support
- **What we change**: PulsarOS branding, default paths (`/storage/PulsarOS/roms`),
  preinstalled platforms, remove unnecessary categories

### Emulation Frontend: EmulationStation-DE
- **Source**: official ES-DE for Android (APK and open source available)
- **Why**: industry standard, huge theme database, works on Android
- **What we configure**: ROM paths, gamepad mapping, default theme

### Emulator: RetroArch
- **Source**: official RetroArch for Android
- **Preinstalled cores** (for Allwinner H618 — A53 × 4):
  - NES: `fceumm` or `nestopia`
  - SNES: `snes9x`
  - Mega Drive: `genesis_plus_gx`
  - GBA: `mgba`
  - PS1: `pcsx_rearmed` (MIPS JIT, good on ARM)
  - NDS: `desmume`
  - N64: `mupen64plus_next`
  - GBC: `gambatte`
  - PC Engine: `mednafen_pce_fast`
  - MAME (arcades): `mame2003_plus`
- **What we configure**: gamepad auto-config, light shaders (CRT-simple),
  hot corners, rewind/save states, hide unsuitable cores

### Media Player: Kodi
- **Source**: official Kodi for Android (open-source)
- **What we configure**: sources `/storage/PulsarOS/video` and `/storage/PulsarOS/audio`,
  gamepad mapping, default theme

### Browser: TV Bro (fork)
- **Source**: `github.com/truefedex/tv-bro` (open-source, MIT-compatible)
- **Why**: optimized for TV remote/D-pad, WebKit/Blink engine on Android,
  tabs, bookmarks, download manager
- **What we change**: branding, default homepage, remove bloat

### OOBE (First Boot Wizard): PulsarOS Setup (write from scratch)
- Small Android app (Kotlin/Java), runs on first boot
- Steps:
  1. Welcome + language selection
  2. Gamepad connection (Bluetooth or USB) + button test
  3. WiFi setup (system WiFi picker or nmcli)
  4. Resolution / refresh rate (based on monitor capabilities)
  5. External storage connection (optional)
  6. Done → launch Console Launcher / ES-DE

---

## Build System

### Requirements (AOSP build machine)

| Parameter | Minimum |
|---|---|
| OS | Ubuntu 20.04 / 22.04 LTS (x86_64) |
| RAM | 32 GB (64 GB recommended) |
| Disk | 300 GB free space (SSD recommended) |
| CPU | 8+ cores (more = faster) |
| Build time | 4–8 hours (depends on hardware) |

### Tools
```bash
# Essential dependencies (Ubuntu 22.04)
sudo apt install git-core gnupg flex bison build-essential zip curl \
  zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 libncurses5 \
  lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev \
  libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig python3 \
  python-is-python3 openjdk-11-jdk ccache rsync

# repo tool
mkdir -p ~/.local/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.local/bin/repo
chmod a+x ~/.local/bin/repo
export PATH="$HOME/.local/bin:$PATH"
```

### Repository Structure

```
PulsarOS/
├── device/
│   └── softwinner/
│       └── zero3/                # Device tree for H618 (Allwinner naming)
│           ├── AndroidProducts.mk
│           ├── pulsaros_zero3.mk # Our product definition
│           ├── BoardConfig.mk
│           ├── device.mk
│           ├── config/           # Thermal, gamepad configs
│           └── overlay/          # RRO overlays (system resource customization)
│
├── vendor/
│   └── pulsaros/
│       ├── prebuilt/
│       │   ├── apk/              # RetroArch, ES-DE, Kodi, TV Bro APKs
│       │   └── cores/            # RetroArch cores (.so libraries)
│       ├── config/               # RetroArch, ES-DE configs
│       └── scripts/              # Storage watcher, SSH toggle
│
├── packages/
│   └── apps/
│       ├── PulsarSetup/          # OOBE wizard (Kotlin, write from scratch)
│       ├── ConsoleLauncher/      # Fork of Console Launcher
│       └── TVBro/                # Fork of TV Bro
│
├── scripts/
│   ├── build.sh                  # Local build (./build.sh debug|release)
│   ├── setup-env.sh              # Install dependencies
│   └── flash.sh                  # Write image to SD card
│
├── docs/
│   ├── BUILD.md                  # Build instructions
│   ├── FLASHING.md               # How to flash ROM
│   └── HARDWARE.md               # Compatible gamepads, hubs, etc.
│
├── PROJECT_CONTEXT.md            # This file (for AI assistants)
└── README.md
```

### How Overlay Patching Works

**IMPORTANT**: PulsarOS patches are **overlays**, not replacements.

Orange Pi provides complete Android 12 source (3333 directories, 21103 files). Our repo
contains only **customizations**:

- **`device/softwinner/zero3/`** — our product definition + config
  - Does NOT replace standard device configs (amlogic, generic, google, linaro, mediatek, ti)
  - Orange Pi's `device/softwinner/apollo/` and `device/softwinner/common/` remain intact
  
- **`vendor/pulsaros/`** — our vendor additions
  - Does NOT touch Orange Pi's vendor configs
  
- **`packages/apps/`** — our applications
  - Does NOT delete system apps from AOSP

When building:

```bash
$ ./scripts/build.sh debug
  1. Syncs device/softwinner/zero3/ → ANDROID_SRC/device/softwinner/zero3/
  2. Syncs vendor/pulsaros/ → ANDROID_SRC/vendor/pulsaros/
  3. Syncs packages/apps/* → ANDROID_SRC/packages/apps/*
  4. Source build/envsetup.sh
  5. lunch pulsaros_zero3-userdebug
  6. make -j$(nproc)
```

**Key Rule**: `rsync` uses **NO `--delete` flag**. This preserves Orange Pi's original files.

### Debug vs Release

**Debug build** (`./build.sh debug`):
- SSH enabled and auto-started
- ADB enabled over network (port 5555)
- Verbose logging (`logcat` available)
- "DEBUG" watermark on screen
- For development and debugging

**Release build** (`./build.sh release`):
- SSH disabled by default
- ADB disabled
- Minimal logging
- User can enable SSH via `Settings → PulsarOS Tools → Enable SSH`
  (script shows IP, port, password)

### GitHub Actions

AOSP builds are huge (~250+ GB, 4–8 hours). GitHub-hosted runners **won't work**.
We use **self-hosted runner** on own machine or rented server:

```yaml
# .github/workflows/build-release.yml
runs-on: [self-hosted, linux, android-build]
```

Local and CI builds produce **identical images** (deterministic build via
`BUILD_NUMBER` and fixed tool versions).

---

## Storage: How It Works

System monitors SD card and USB drive connections. When a device is detected:

1. Mounts at `/storage/UUID_device/`
2. If `PulsarOS/` folder exists — registered as game storage
3. ES-DE and RetroArch automatically discover paths:
   - Games: `/storage/.../PulsarOS/roms/<system>/`
   - Video: `/storage/.../PulsarOS/video/`
   - Audio: `/storage/.../PulsarOS/audio/`
4. Kodi gets these paths as media sources

User just plugs in a flash drive with the right structure — it works automatically.

### USB Drive Folder Structure

```
PulsarOS/
├── roms/
│   ├── nes/          # .nes files
│   ├── snes/         # .sfc, .smc
│   ├── md/           # .md, .bin (Mega Drive)
│   ├── gba/          # .gba
│   ├── psx/          # .bin/.cue, .pbp, .chd
│   ├── nds/          # .nds
│   ├── arcade/       # .zip (MAME)
│   └── ...
├── video/
├── audio/
└── other/
```

---

## WiFi and Remote Access

### First WiFi Setup
- In OOBE (first boot), WiFi setup is offered
- User selects network, enters password with gamepad (Android on-screen keyboard)
- Alternative: Ethernet via expansion board (automatic)

### Web File Manager
- After connecting to network, web interface available for file uploads
- Address shown on screen: `http://192.168.x.x:8080`
- Allows uploading ROMs, videos, audio without SSH
- Based on ready-made Android solution (e.g., `Primitive FTPd`)

### SSH (Debug only / on request)
- Debug: enabled automatically, `ssh root@IP` with password from build config
- Release: `PulsarOS Tools → Enable SSH` script → shows IP and temporary password

---

## Performance and Optimization

### What We Remove from Android TV Base
- Google TV / Leanback components (replaced with our launcher)
- GMS stubs (work without Google Play Services)
- Unused system apps (Chrome, Gmail, etc.)
- TV Input Framework (not needed for gaming console)

### Performance Settings
- CPU Governor: `schedutil` or `performance` (set in device tree)
- GPU: max frequency in gaming mode
- Thermal: monitoring H618 temperature (up to 85°C nominal)
- I/O scheduler: `mq-deadline` for SD card
- Zswap / ZRAM: enabled for 1 GB RAM variants

### Resolution and Refresh Rate
- OOBE allows selecting resolution and Hz based on monitor
- Supported modes: 720p60, 1080p60, 1080p120, 4K30, 4K60
- Configuration via Android DisplayManager API

---

## Compatible Gamepads (Verified / Expected)

| Gamepad | Connection | Status |
|---|---|---|
| Xbox Series X/S | Bluetooth / USB | Native Android support |
| PlayStation DualSense | Bluetooth / USB | Native Android support |
| PlayStation DualShock 4 | Bluetooth / USB | Native Android support |
| Nintendo Switch Pro | Bluetooth / USB | Native Android support |
| 8BitDo (any) | Bluetooth / USB | Native Android support |
| Generic USB HID | USB | Native Android support |

OOBE on first boot:
1. Shows list of compatible gamepads
2. Offers Bluetooth pairing
3. If not recognized — manual configuration via RetroArch

---

## Key Links

- Orange Pi Zero 3 official page:
  `http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-Zero-3.html`
- Orange Pi Android 12 source (Google Drive, official):
  `https://drive.google.com/drive/folders/1acn4Oosu1s-39hCK3uRiqj9gG0Jw-tGZ`
- Additional materials (second drive):
  `https://drive.google.com/drive/folders/1xnASyXu2cKq312JOpkNebYOWb1dW_T56`
- Community GitHub org with BSP and TWRP for Zero 3:
  `https://github.com/OrangePi-Zero3`
- OmniROM 12.1 port (reference):
  `https://blogs.yajatkumar.com/2024/09/omnirom-121-v01-for-orange-pi-zero-3.html`
- Console Launcher (fork source):
  `https://github.com/likeich/console-launcher`
- TV Bro (fork source):
  `https://github.com/truefedex/tv-bro`
- Legacy OrionOS repo (archived):
  `https://github.com/onex01/OrionOS`

---

## Current Project Status

### Phase 0 — Preparation (CURRENT)
- [x] Understand Orange Pi Android 12 source structure
- [x] Create device/softwinner/zero3/ (correct location per AOSP convention)
- [x] Fix build.sh to preserve Orange Pi source files (remove `--delete` flag)
- [ ] Get Orange Pi Android 12 source from Google Drive
- [ ] Run initial build to validate structure
- [ ] Setup GitHub Actions (self-hosted runner)

### Phase 1 — Basic Build
- [ ] Build clean Android 12 for Zero 3 (no mods)
- [ ] Verify GPU works (glmark2-android or similar test)
- [ ] Switch from TV product to Tablet/Generic
- [ ] Fork and integrate Console Launcher
- [ ] Fork and integrate TV Bro
- [ ] Preinstall RetroArch + base cores

### Phase 2 — Functionality
- [ ] Write PulsarOS Setup (OOBE)
- [ ] Implement storage watcher (auto-detect PulsarOS/)
- [ ] Configure ES-DE with correct paths
- [ ] Integrate Kodi with video/audio sources
- [ ] Web file manager
- [ ] SSH toggle script

### Phase 3 — Polish
- [ ] Performance optimization (governor, zram)
- [ ] Custom boot animation
- [ ] Gamepad testing
- [ ] User documentation
- [ ] First public Release (GitHub Releases)

---

## Instructions for AI Assistant

When working on the project:

1. **Platform**: Android 12, target device Orange Pi Zero 3 (Allwinner H618 / ARM64)
2. **Don't suggest Linux fixes** for system level — GPU doesn't work
3. **Don't write from scratch** what exists open-source (launcher, browser — use forks)
4. **Write from scratch**: OOBE Setup, storage watcher service, SSH toggle script,
   device tree patches, build.sh, CI configs
5. **Code language**: Kotlin for Android apps, Bash for scripts,
   Make/Soong for Android build system
6. **Debug-first**: always think about logging and debugging when writing code
7. **Deterministic build**: local = CI, no "download and place manually"
8. **Minimize image size**: remove unnecessary AOSP components, keep final image compact

When finding bugs — offer specific fixes with code, not abstract advice.

**CRITICAL**: Orange Pi provides complete source. Our job is to add `/device/softwinner/zero3/`,
not rewrite `/device/`. Use rsync **without `--delete`**.
