# PulsarOS — План сборки и развития

> **Актуальное состояние — `docs/STATUS.md` (2026-11-08).**
>
> Этот план написан под старый пайплайн (BSP → dragon pack → imgRePacker).
> Сейчас образ собирается `scripts/build-image.sh` из стокового IMAGEWTY
> нашими инструментами, а прошивается `scripts/flash-linux.sh`. Пункты ниже
> сохранены как история; что из них сделано и что осталось — в `STATUS.md`.

## Текущий статус (2026-07-17)

### Что работает
- pulsaros-v6.img загружается на Orange Pi Zero 3
- Stock firmware + наш bootlogo + наш super.fex
- ADB через USB работает
- imgRePacker работает (Linux 32-bit, tools/bin/imgrepacker)
- Build pipeline: BSP → pack (dragon) → imgRePacker → IMAGEWTY

### Что не работает
- PulsarSetup не установлен
- Libretro cores не попадают в product output (требует Android.mk rebuild)
- ro.product.brand/model — read-only (требует build.prop)
- GMS variant не создан
- Web File Manager не установлен
- 120Hz не настроен
- USB auto-mount не настроен
- Game Translator не создан

---

## Pipeline сборки

```
1. BSP подготовка     → scripts/00-prepare-bsp.sh
2. Android build      → make -j24
3. Pack (dragon)      → pack
4. imgRePacker        → scripts/06-create-image.sh
5. Прошивка           → scripts/flash-sdcard.sh
```

### Структура репозитория
```
PulsarOS/
├── img/patch/fex/           # Stock firmware (13 файлов, 73MB)
├── scripts/
│   ├── build.sh
│   ├── steps/
│   │   ├── 00-prepare-bsp.sh
│   │   ├── 05-build-android.sh
│   │   └── 06-create-image.sh
│   └── flash-sdcard.sh
├── vendor/pulsaros/
│   ├── prebuilt/apk/       # 5 APK (RetroArch, Daijishou, Kodi, TVBro, F-Droid)
│   ├── prebuilt/cores/     # 24 libretro cores + Android.mk
│   ├── config/retroarch/   # retroarch.cfg, cores-whitelist.txt
│   ├── config/daijishou/   # platforms.json
│   └── bootanimation/      # boot animation
├── device/softwinner/apollo/
│   └── apollo_p2.mk        # density=213, dark theme, DPI, no stock launcher
└── packages/apps/PulsarSetup/  # OOBE wizard
```

---

## Варианты сборки

### Vanilla (текущий)
- F-Droid
- Без Google services
- Debloat: Google TV, Leanback, Browser2, Gallery, Camera, SoundRecorder

### GMS (план)
- Google Play Services
- Google Play Store
- GMS config: CONFIG_SUPPORT_GMS=true

---

## Доработки (план)

### Приоритет 1
1. ~~Исправить density 160→213~~ ✅
2. ~~Включить dark theme~~ ✅
3. ~~Добавить DPI setting~~ ✅
4. ~~Заблокировать stock launcher~~ ✅
5. ~~Добавить cores через Android.mk~~ ✅
6. ~~Исправить boot.fex (stock kernel)~~ ✅

### Приоритет 2
7. Добавить PulsarSetup в build
8. Настроить RetroArch (ядро, геймпады, шейдеры)
9. Исправить Daijishou (themes, download, language)
10. Настроить Kodi (медиа пути, авто-скан)
11. Fork TVBro → Browser

### Приоритет 3
12. Web File Manager (HTTP server 8080)
13. 120Hz display
14. USB auto-mount + storage structure
15. Game Translator
16. GMS variant

---

*Последнее обновление: 2026-07-17*
