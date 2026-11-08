# PulsarOS

> **English** | [Русский](#pulsaros-русский)

> Android 12 gaming firmware for the Orange Pi Zero 3 (Allwinner H618).
> Built by repacking the stock Orange Pi image, not by compiling AOSP.

PulsarOS turns the Orange Pi Zero 3 into a retro console: flash the card, plug in
a gamepad, play. The base is the official Orange Pi Android 12 image — we resize
its logical partitions, install our apps and drivers, and rebuild the flashable
image with our own tools.

**Version:** 0.1.0-dev · **Status:** booting and usable, OOBE not built yet.

## What actually works

Verified on the board, not planned:

| Area | State |
| --- | --- |
| Boot chain | boot0 → boot_package → OP-TEE → u-boot → GPT → kernel → Android |
| Network | Wi-Fi (`wlan0`, sprdwl_ng), ADB over TCP at `:5555` (`adb root`) |
| Storage | `/data` = 56 GB f2fs, userdata pre-formatted |
| Frontend | Daijishou installed; the stock `TvLauncher` is still the home app |
| RetroArch | 1.22.2 `ra32`, native libs unpacked, 30 armv7 cores staged |
| Standalone emulators | PPSSPP 1.20.4, DuckStation, Mupen64Plus FZ |
| Video | VLC 3.7.1 |
| Browser | TV Bro 2.1.6 — navigable with a d-pad / gamepad |
| File access | AOSP DocumentsUI added — the stock image has none |
| File transfer | Primitive FTPd (FTP/SFTP/SCP on the LAN) |
| Gamepads | Nintendo Switch Pro fixed against measured evdev codes; 190 layouts |
| Boot animation | Owner's own `bootanimation.zip`, 800×480@60 |
| Debloat | 17 stock test/demo packages removed (~54 MiB) |

## What is not done yet

- **Kernel logo** — u-boot still rewrites the GPT into partition 1 on some
  boots; the fix is in the GPT geometry and is being verified.
- **OOBE** — language, licence, network, gamepad wizard. Nothing of this exists.
- **External storage layout** — automatic `PulsarOS/{game,video,music}` tree and
  auto-scan are not implemented.
- **Web file server** — only FTP for now.
- **1080p** — the display comes up as 1280×720 because HDMI DDC/EDID fails at
  probe (`pinctrl_get for HDMI2.0 DDC fail`); the driver falls back to 720p.
- **Launcher switch, core seeding into `/data`** — done by hand over ADB, not in
  the image yet.

## Hardware

| Board | SoC | RAM | Status |
| --- | --- | --- | --- |
| Orange Pi Zero 3 | Allwinner H618, Mali-G31 MP2 | 1–4 GB | primary target |

Display out is micro-HDMI; the expansion board adds two USB ports, analogue
video, a microphone and an IR receiver.

## Requirements

- Orange Pi Zero 3 (any RAM variant)
- microSD card, 16 GB or larger
- Gamepad (USB or Bluetooth) or keyboard + mouse
- 5 V / 3 A USB-C supply
- Monitor or TV over micro-HDMI

## Building

This is not an AOSP build. The pipeline takes the stock image apart, replaces
`super` and the boot resources, and writes the result back as a flashable
IMAGEWTY image.

```bash
# 1. Put the stock image here (md5 2fa5d4f1e890a03d7d8a36c410c8bd48):
#    /home/one/Github/tmp/OrangePi_Zero3_Android12_v1.0/OrangePi_Zero3_Android12_v1.0.img

# 2. Download the apps that are not in git (~950 MB):
scripts/fetch-apps.sh

# 3. Build the image (needs root: mounts loops, resizes ext4):
echo <sudo-password> | sudo -S bash -c 'HOME=$HOME bash scripts/build-image.sh'
#    → out/PulsarOS-YYYYMMDD.img + .md5

# 4. Flash the card:
sudo scripts/flash-linux.sh out/PulsarOS-YYYYMMDD.img /dev/sdX --yes
```

The build needs about 11 GB of scratch space under `work/` and roughly
20 minutes on a mechanical disk.

### What the build does

1. Extracts the stock sections (`imagewty.py`) and unpacks `super` (`lpunpack.py`).
2. Enlarges `system_a` to 2048 MiB and `product_a` to 400 MiB, resizes ext4.
3. Drops stock bloat, installs 7 apps plus RetroArch/Daijishou, unpacks their
   `lib/armeabi-v7a` into `lib/arm` (a preinstalled APK does not get its native
   libraries extracted into `/data`), stages 30 libretro cores, key layouts,
   boot animation and the DocumentsUI priv-app allowlist.
4. Packs `super` back with `lpmake.py`, compresses it, and rewrites the IMAGEWTY
   section table.

`flash-linux.sh` then derives the card layout from `cardscript.fex` and
`sunxi_mbr.fex`, generates a GPT, and writes everything with verification:
`boot0` at sector 16, `boot_package` at sector 32800, partitions from 40960.

## Project structure

```
PulsarOS/
├── tools/            image tools (no external deps)
│   ├── imagewty.py   Allwinner IMAGEWTY sections: list/extract/repack
│   ├── lpunpack.py   Android dynamic partitions (liblp) read/write
│   ├── lpmake.py     rebuild super from a manifest
│   ├── sparse.py     Android sparse ↔ raw
│   ├── mkgpt.py      GPT for the card (Allwinner-compatible geometry)
│   ├── mbr.py        Allwinner softw411 MBR
│   ├── flashplan.py  card layout from cardscript.fex + sunxi_mbr.fex
│   ├── writeimg.py   writes only allocated blocks (for f2fs userdata)
│   └── fatextract.py reads the stock boot-resource FAT (mtools cannot)
├── scripts/
│   ├── build-image.sh    the image builder
│   ├── flash-linux.sh    card writer with verification
│   ├── fetch-apps.sh     downloads APKs and checks SHA256SUMS
│   └── pulsaros-diag.sh  pulls display/GLES/logcat from the board over adb
├── prebuilt/apk/     APKs (gitignored) + SHA256SUMS
├── prebuilt/cores/   30 libretro cores (gitignored)
├── overlay/system/   key layouts, priv-app permission allowlists
├── vendor/pulsaros/  boot animation, kernel logo
└── docs/             findings, flashing, troubleshooting, status
```

## Documentation

| File | What is inside |
| --- | --- |
| `docs/STATUS.md` | Current state, known bugs, next steps |
| `docs/FINDINGS-STOCK.md` | Everything measured about the stock image |
| `docs/FLASHING.md` | Card layout and flashing procedure |
| `docs/TROUBLESHOOTING.md` | Symptom → cause → fix |
| `docs/IMAGE-FORMAT.md` | IMAGEWTY and the section table |
| `docs/BUILD.md` | Build pipeline details |
| `docs/SESSION-HANDOFF.md` | Handover notes |

## Supported gamepads

Switch Pro Controller, Joy-Con halves and the NSO N64 pad have layouts
measured on this kernel. The stock 186 Android layouts cover Xbox, PlayStation
and 8BitDo pads. Anything else falls back to `Generic.kl`.

## License

MIT for the PulsarOS code. The stock Orange Pi image and the prebuilt APKs keep
their own licences — DuckStation, for example, is CC BY-NC-ND 4.0 and must not
be shipped commercially.

---

# PulsarOS (русский)

> Игровая прошивка Android 12 для Orange Pi Zero 3 (Allwinner H618).
> Собирается перепаковкой стокового образа Orange Pi, а не сборкой AOSP.

**Версия:** 0.1.0-dev · **Состояние:** грузится и пригодна к работе, OOBE не сделан.

## Что реально работает

Проверено на плате, а не запланировано:

| Область | Состояние |
| --- | --- |
| Загрузка | boot0 → boot_package → OP-TEE → u-boot → GPT → ядро → Android |
| Сеть | Wi-Fi (`wlan0`, sprdwl_ng), ADB по TCP `:5555` (`adb root`) |
| Хранилище | `/data` = 56 ГБ f2fs, userdata отформатирована заранее |
| Фронтенд | Daijishou установлен; домашним остаётся стоковый `TvLauncher` |
| RetroArch | 1.22.2 `ra32`, библиотеки распакованы, 30 ядер armv7 |
| Эмуляторы | PPSSPP 1.20.4, DuckStation, Mupen64Plus FZ |
| Видео | VLC 3.7.1 |
| Браузер | TV Bro 2.1.6 — управляется пультом и геймпадом |
| Файлы | добавлен AOSP DocumentsUI — в стоке его нет вообще |
| Передача файлов | Primitive FTPd (FTP/SFTP/SCP по сети) |
| Геймпады | Switch Pro починен по измеренным кодам; 190 раскладок |
| Анимация | своя `bootanimation.zip`, 800×480@60 |
| Деблоат | вычищено 17 стоковых тестовых пакетов (~54 МиБ) |

## Что ещё не сделано

- **Логотип ядра** — u-boot всё ещё перезаписывает GPT в первый раздел;
  исправление геометрии GPT проверяется.
- **OOBE** — язык, лицензия, сеть, визард геймпада. Ничего из этого нет.
- **Внешние носители** — дерево `PulsarOS/{game,video,music}` и автоскан.
- **Веб-сервер** — пока только FTP.
- **1080p** — экран поднимается в 1280×720, потому что HDMI DDC/EDID не
  читается (`pinctrl_get for HDMI2.0 DDC fail`).
- **Лончер и ядра в `/data`** — делается руками по ADB, в образе этого нет.

## Сборка

Это не сборка AOSP. Пайплайн разбирает стоковый образ, заменяет `super` и
загрузочные ресурсы и собирает обратно прошиваемый IMAGEWTY.

```bash
scripts/fetch-apps.sh          # ~950 МБ APK, которых нет в git
sudo bash scripts/build-image.sh   # → out/PulsarOS-YYYYMMDD.img
sudo scripts/flash-linux.sh out/PulsarOS-YYYYMMDD.img /dev/sdX --yes
```

Нужно ~11 ГБ под `work/` и около 20 минут на механическом диске.

## Документация

`docs/STATUS.md` — текущее состояние и баги, `docs/FINDINGS-STOCK.md` — всё
измеренное про сток, `docs/FLASHING.md` — раскладка карты,
`docs/TROUBLESHOOTING.md` — симптом → причина → лечение.

## Лицензия

Код PulsarOS — MIT. Стоковый образ Orange Pi и предустановленные APK сохраняют
свои лицензии: например, DuckStation распространяется по CC BY-NC-ND 4.0 и в
коммерческую поставку попасть не может.
