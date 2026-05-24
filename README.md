# PulsarOS

> A custom Android 12 gaming firmware for the Orange Pi Zero 3 (Allwinner H618).
> The ArkOS / Rocknix experience — but for Allwinner hardware, built on Android.

PulsarOS is an open-source firmware that transforms the Orange Pi Zero 3
into a dedicated retro gaming console connected to any monitor or TV.

Unlike Linux-based alternatives for this board, PulsarOS runs on Android 12
with the official Allwinner GPU driver — delivering full hardware acceleration
on the Mali G31 MP2 GPU (OpenGL ES 3.2, Vulkan 1.1) without any workarounds.

## Why Android instead of Linux?

The Orange Pi Zero 3 ships with a downstream Linux 5.16 BSP where the
open-source Panfrost GPU driver is non-functional. Every official Linux
distribution for this board — Debian, Ubuntu, Arch — runs on software
rendering. Android 12, on the other hand, includes the proprietary Mali blob
and works with full GPU acceleration out of the box.

## What you get

- **Plug and play** — flash the image, connect a gamepad, and start playing.
  No terminal, no configuration files, no internet required.
- **External storage** — drop a USB drive or SD card with a `PulsarOS/roms/`
  folder and games are detected automatically.
- **EmulationStation-DE** — a polished frontend for browsing your game library
  by system, with artwork, metadata, and controller navigation.
- **RetroArch** — preloaded with cores for NES, SNES, Mega Drive, GBA,
  PlayStation, NDS, arcade, and more.
- **Kodi** — full video and audio playback from your `PulsarOS/video/` and
  `PulsarOS/audio/` folders.
- **First-run wizard** — connects your Bluetooth gamepad, sets up Wi-Fi,
  and configures display resolution on first boot.
- **Web file manager** — upload ROMs and media from any browser on your
  local network, no SSH needed.
- **High refresh rate** — supports up to 1080p@120Hz and 4K@60Hz depending
  on your display.

## Supported hardware

| Board | SoC | Status |
|---|---|---|
| Orange Pi Zero 3 (1 / 1.5 / 2 / 4 GB) | Allwinner H618 | ✅ Primary target |

## Compared to similar projects

| | PulsarOS | ArkOS | Rocknix |
|---|---|---|---|
| Platform | Allwinner H618 | Rockchip | Rockchip |
| OS base | Android 12 | Linux | Linux |
| GPU acceleration | ✅ Full (Mali blob) | ✅ Full | ✅ Full |
| Frontend | ES-DE | EmulationStation | EmulationStation |
| Gamepad setup | OOBE wizard | Manual | Manual |
| External storage | Auto-detect | Manual | Manual |


## License

PulsarOS-specific code (device tree, build scripts, OOBE app, overlays)
is licensed under the **GNU General Public License v3.0** — see [LICENSE](LICENSE).

Third-party components retain their original licenses:
- EmulationStation-DE: MIT
- TV Bro (browser): Apache 2.0
- RetroArch: GPL v3 (distributed as prebuilt APK, not modified)
- Kodi: GPL v2+ (distributed as prebuilt APK, not modified)
- AOSP Android 12: Apache 2.0
