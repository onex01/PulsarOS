# PulsarOS — Полная документация сессии

> **Дата**: 2026-07-14
> **Цель**: Читать этот файл в начале новой сессии для продолжения работы

---

## 1. Текущее состояние проекта

### Что работает
- Android сборка завершена (super.img, boot.img, system.img существуют)
- imgRePacker работает в WSL2 (Linux x86_32 бинарник)
- IMAGEWTY пересборка через imgRePacker — **РАБОТАЕТ**
- PulsarSetup APK собран через Gradle (SDK 34)
- 24 libretro ядра скачаны
- 4 APK: RetroArch, Daijishou, Kodi, TVBro

### Что НЕ работает
- NTFS копия Android source **неполная** — нет `build/envsetup.sh`
- Нельзя пересобрать Android из WSL2
- `hardware check error1` при прошивке (но возможно из-за Product режима)
- Super.fex из pack_out имеет другой MD5 чем super.fex из оригинального образа

### Ключевая находка: StartUp vs Product
- Оригинальный образ загружается **только в StartUp** режиме PhoenixCard
- Product режим не работает (особенность доски)
- Это доказано: стоковый образ загрузился в StartUp

---

## 2. IMAGEWTY формат

### Структура
```
Offset     Описание
0x000000   Header (96 bytes)
           - Magic: "IMAGEWTY"
           - Version: 0x300
           - Subversion: 0x60 (imgRePacker) или 0x00 (dragon)
           - File size
0x000060   Creator string / padding (32 bytes)
0x000400   Section table (45 entries × 1024 bytes)
0x00B800   Data area (секции подряд)
```

### Критическое поле: subversion
- `subversion = 0x60` → совместимо с PhoenixCard ✓
- `subversion = 0x00` (dragon) → PhoenixCard отклоняет ✗
- Ошибка: "Image error, use new version image file!"

### Секции IMAGEWTY (45 штук)
```
1-6:   sys_config, board, config, split, sys_partition, sunxi (конфиги)
7-8:   boot0_nand, boot0_sdcard (DRAM init, 60KB)
9-14:  u-boot, u-boot-crash, toc1, toc0, fes1, boot_package (загрузчик)
15-23: usbtool, aultools, cardtool, cardscript, sunxi_gpt, sunxi_mbr, dlinfo, arisc (инструменты)
24:    vmlinux (ядро, ~12MB)
25-26: boot-resource, Vboot-resource (FAT16, bootlogo)
27-28: env, Venv (U-Boot переменные)
29-30: boot, Vboot (Android boot image, ~64MB)
31-32: vendor_boot, Vvendor_boot (~32MB)
33-34: super, Vsuper (system+vendor, ~1GB, sparse)
35-42: misc, vbmeta, vbmeta_system, vbmeta_vendor (метаданные)
43-44: dtbo, Vdtbo (device tree overlay)
```

### V*.fex секции
- 4-byte checksum файлы (не полные копии данных)
- Вычисляются из соответствующих данных
- Не хранятся отдельно в IMAGEWTY

---

## 3. Инструменты

### imgRePacker (RedScorpio)
- **Версия**: 2.0.7.8 (Linux & Windows)
- **Автор**: RedScorpio (RedScorpio.lab@gmail.com)
- **Лицензия**: Проприетарный, распространяется открыто
- **Источник**: XDA Developers (требуется VPN из РФ)
- **Путь**: `tools/bin/imgrepacker` (Linux), `tools/bin/imgRePacker.exe` (Windows)
- **Работает в WSL2** ✓

#### Распаковка
```bash
./tools/bin/imgrepacker original.img
# → original.img.dump/ (45 .fex файлов + image.cfg)
```

#### Запаковка
```bash
./tools/bin/imgrepacker directory.dump
# → directory (IMAGEWTY файл)
# ВАЖНО: директория ДОЛЖНА заканчиваться на .dump!
```

#### Формат image.cfg
```lua
[DIR_DEF]
INPUT_DIR = ""

[FILELIST]
{filename = INPUT_DIR .. "sys_config.fex", maintype = "COMMON  ", subtype = "SYS_CONFIG100000",},
...

[IMAGE_CFG]
version = 0x00100234;
subversion = 0x00000060;  ← КЛЮЧЕВОЕ для PhoenixCard
pid = 0x00001234;
vid = 0x00008743;
hardwareid = 0x0100;
firmwareid = 0x0100;
filelist = FILELIST
```

### dragon (Allwinner)
- **Путь**: `longan/tools/pack/pctools/linux/eDragonEx/dragon`
- **Формат**: 32-bit i386 Linux ELF
- **Требует**: `libc6:i386` (`sudo apt install libc6:i386`)
- **Проблема**: `subversion = 0x00` → PhoenixCard отклоняет
- **Решение**: Использовать imgRePacker вместо dragon

### pack (Allwinner BSP)
- **Путь**: `longan/build/pack`
- **Вызов**: `./pack -i h618 -c sun50iw9p1 -p android -b p2 -d uart0`
- **Требует**: `ANDROID_IMAGE_OUT` env var, buildserver daemon
- **Boot0**: копирует из `longan/out/h618/p2/android/`, НЕ из `device/config/`

---

## 4. Сборка Android

### Требования
- Ubuntu 22.04 LTS (или WSL2)
- 16+ GB RAM
- 300+ GB SSD
- `sudo apt install libc6:i386` (для dragon)

### Ключевые команды
```bash
# Настройка окружения
cd /path/to/android/source
source build/envsetup.sh
lunch apollo_p2-userdebug

# Сборка (8 jobs для 32GB RAM)
make -j8

# Pack
cd longan/build
./pack -i h618 -c sun50iw9p1 -p android -b p2 -d uart0
```

### Критические правила
- **Lunch target**: `apollo_p2-userdebug` (НЕ pulsaros_zero3!)
- **USE_CCACHE=false** (НЕ "0")
- **set +u** перед `source build/envsetup.sh`
- **Build jobs**: max 8 (31GB RAM, без swap — 28 jobs вызывает OOM)
- **Boot0**: pack копирует из `longan/out/h618/p2/android/`, а НЕ из `device/config/`

---

## 5. Подход V1 vs V2

### V1: Сборка из исходников
- Полная сборка Android с нуля
- Оверлеи PulsarOS добавляются в Android source
- pack_out содержит .fex файлы с нашими изменениями
- **Проблема**: envsetup.sh отсутствует в NTFS копии
- **Преимущества**: Полный контроль, все компоненты включены

### V2: Модификация стокового образа
- Берём оригинальный образ Orange Pi
- Распаковываем через imgRePacker
- Заменяем super.fex на нашу версию
- Пересобираем через imgRePacker
- **Преимущества**: Быстро, не нужна полная сборка
- **Проблема**: super.fex из pack_out ≠ super.fex из оригинала (разные MD5)

### Рекомендация
Для 100% эффективности — native Linux с полным `repo sync`. WSL2 подходит для:
- Пересборки IMAGEWTY (imgRePacker работает)
- Тестирования
- Модификации отдельных секций

---

## 6. Структура репозитория

### PulsarOS (V1)
```
PulsarOS/
├── device/softwinner/zero3/     # Device tree для H618
├── vendor/pulsaros/             # Наши компоненты
│   ├── prebuilt/apk/            # RetroArch, Daijishou, Kodi, TVBro
│   ├── prebuilt/cores/          # 24 libretro .so
│   ├── config/                  # Конфиги RetroArch, ES-DE
│   ├── scripts/                 # Storage watcher, SSH toggle
│   ├── boot-logo/               # bootlogo.bmp
│   └── bootanimation/           # bootanimation.zip
├── packages/apps/PulsarSetup/   # OOBE wizard (Kotlin)
├── scripts/                     # Build scripts
├── patches/android-source/      # BSP патчи
├── docs/                        # Документация
├── tools/bin/                   # imgRePacker (binary)
└── PROJECT_CONTEXT.md           # Контекст проекта
```

### PulsarOS-V2
```
PulsarOS-V2/
├── scripts/
│   ├── build.sh                 # Главный pipeline
│   ├── unpack_imagewty.py       # Python unpacker
│   ├── repack_imagewty.py       # Python repacker
│   ├── patch_imagewty.py        # Creator string
│   └── modify_via_adb.sh        # ADB fallback
├── prebuilt/apk/                # APK файлы
├── prebuilt/cores/              # libretro ядра
├── overlay/vendor/etc/          # Конфиги
├── tools/bin/                   # imgRePacker
├── original/                    # Стоковый образ
├── work/                        # Временные файлы
└── output/                      # Готовые образы
```

---

## 7. Известные проблемы

### boot0
- Pack копирует boot0 из `longan/out/h618/p2/android/`, а НЕ из `device/config/`
- Если заменить boot0 в `device/config/`, pack его перезапишет
- **Решение**: заменять boot0 в `longan/out/h618/p2/android/`

### .buildconfig
- Содержит пути `/mnt/BF/H618-Android12-Src/`
- **Решение**: заменять на `/mnt/d/OPiZero3_AOSP/H618-Android12-Src/`

### 32-bit runtime
- `dragon` (32-bit i386) требует `libc6:i386`
- Установка: `sudo apt install libc6:i386`

### NTFS ограничения
- Медленный I/O
- Проблемы с симлинками
- Нет `build/envsetup.sh` в копии

---

## 8. Следующие шаги

### Приоритет 1: Протестировать текущий образ
- `PulsarOS-V2.img` на рабочем столе (1.2G)
- Прошить через PhoenixCard **StartUp** режим
- Проверить загрузку и наличие приложений

### Приоритет 2: Настроить native Linux
- Установить Ubuntu 22.04
- Сделать `repo sync` полных исходников
- Собрать Android с нашими оверлеями
- Проверить что приложения включены в build

### Приоритет 3: Доработки OOBE
- Исправить навигацию геймпадом
- Добавить лицензии
- Улучшить UI

---

## 9. Контакты и ссылки

- **Репозиторий**: https://github.com/onex01/PulsarOS
- **ImgRePacker**: XDA Developers (требуется VPN)
- **nskhuman.ru**: Документация по IMAGEWTY формату
- **OrangePi BSP**: Google Drive (ссылки в PROJECT_CONTEXT.md)

---

*Документ создан: 2026-07-14*
*Последнее обновление: 2026-07-14*
