# PulsarOS — Полная история проекта
## Документ для продолжения работы в новой сессии

---

## Краткое описание проекта

**PulsarOS** — Android 12 прошивка для Orange Pi Zero 3 (Allwinner H618), портативная консоль для ретро-игр. 32-bit ARM userspace, 64-bit kernel. Включает RetroArch, Daijishou лаунчер, Kodi, TV Bro.

---

## Текущая проблема (2026-07-13)

### Корневая причина: dragon vs imgRePacker IMAGEWTY несовместимость

BSP Allwinner содержит два инструмента для создания IMAGEWTY:
- **`dragon`** (32-bit i386 Linux) — текущий BSP использует его
- **`imgRePacker.exe`** (Windows, RedScorpio) — оригинальный образ был создан им

PhoenixCard содержит **cardtool.fex** (Windows DLL плагин), который **валидирует формат IMAGEWTY**. cardtool.fex:
- Проверяет маркер `PHOENIX_CARD_IMG`
- Проверяет структуру section table
- Проверяет наличие cardscript.fex
- Проверяет sparse-формат

**dragon оборачивает файлы иначе чем imgRePacker** — даже когда ВСЕ секции идентичны, cardtool.fex отвергает IMAGEWTY от dragon. Ошибка: `"Image error, use new version image file!"`

### Что проверено и НЕ работает

1. ✅ Longan build — работает
2. ✅ Android build — работает  
3. ✅ Pack (dragon SUCCESS) — создаёт 1.1G IMAGEWTY
4. ❌ Product mode — `hardware check error1` на BL3-1
5. ❌ Startup mode — тоже падает на BL3-1
6. ❌ Замена ВСЕХ оригинальных файлов boot_package/boot0/u-boot — НЕ помогает
7. ❌ sys_config.fex идентичен оригиналу — НЕ проблема
8. ❌ Wine + eDragonEx200 dragon.exe — MFC42.DLL не найден
9. ❌ OpenixIMG pack — "Operation failed!" (не реализовано)
10. ❌ imgRePacker.exe — нет в BSP, не найден

### Что НЕ пробовалось / может сработать

1. **Бинарный патчинг оригинального IMAGEWTY** — заменить super.fex в контейнере оригинала
2. **RAW-образ** — создать полный дамп SD-карты (dd/DiskImager)
3. **imgRePacker.exe через WSL** — Windows инструмент доступен из WSL

---

## Ссылки на документацию (ВСЕ изучены)

### Построение
- http://nskhuman.ru/allwinner/opizero3/zero3man.php?nglav=6&nlang=1 — инструкция сборки
- http://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_Zero_3 — вики Orange Pi

### Формат прошивки (IMAGEWTY)
- http://nskhuman.ru/allwinner/firmware.php — overview
- http://nskhuman.ru/allwinner/firmware.php?np=1 — IMAGEWTY формат: 96B header, section table
- http://nskhuman.ru/allwinner/firmware.php?np=2 — описание секций
- http://nskhuman.ru/allwinner/firmware.php?np=3 — GPT: 17 разделов, LBA layout
- http://nskhuman.ru/allwinner/firmware.php?np=4 — утилиты, DD команды
- http://nskhuman.ru/allwinner/firmware.php?np=5 — RAW-формат

### Отдельные секции IMAGEWTY
- http://nskhuman.ru/allwinner/firmware.php?np=2&nf=1 — super.fex
- http://nskhuman.ru/allwinner/firmware.php?np=2&nf=2 — boot-resource.fex (FAT16: bootlogo, fonts, magic.bin)
- http://nskhuman.ru/allwinner/firmware.php?np=2&nf=3 — boot_package.fex (dragonsecboot, header+items)
- http://nskhuman.ru/allwinner/firmware.php?np=2&nf=4 — boot0_sdcard.fex
- http://nskhuman.ru/allwinner/firmware.php?np=2&nf=5 — **cardscript.fex** (blueprint для PhoenixCard: boot0@16, boot_package@32800, GPT@40960)
- http://nskhuman.ru/allwinner/firmware.php?np=2&nf=6 — **cardtool.fex** (DLL валидации PhoenixCard)
- http://nskhuman.ru/allwinner/firmware.php?np=2&nf=7 — split_xxxx.fex (UUID magic.bin)
- http://nskhuman.ru/allwinner/firmware.php?np=2&nf=8 — fes1.fex (USB FEL)

### Инструменты
- http://nskhuman.ru/allwinner/card/phoenixcard.php — PhoenixCard документация
- http://nskhuman.ru/allwinner/card/phoenixcard433rus.zip — PhoenixCard 4.3.3 (последняя)
- https://linux-sunxi.org/LiveSuit_images — LiveSuit
- http://nskhuman.ru/menu.php?cat=4 — индекс всех документов Allwinner

---

## Boot chain Allwinner H618 (4 стадии)

1. **Boot0** → SRAM, тренирует DRAM, читает IMAGEWTY header. `mmc not para` = ошибка чтения SD
2. **BL3-1** (ATF) → проверяет PMIC + DTB. `hardware check error1` = несоответствие параметров
3. **U-Boot** → читает GPT, проверяет AVB, формирует bootargs
4. **Kernel** → монтирует system/vendor

---

## Разметка разделов (17 штук)

| # | Имя | LBA начало | Размер (секторов) | Размер |
|---|-----|-----------|-------------------|--------|
| - | boot0 | 16 | - | ~8KB |
| - | boot_package | 32800 | - | ~16MB |
| - | GPT | 40960 | - | - |
| 1 | bootloader | 73728 | 65536 | 32MB |
| 2 | env | 139264 | 32768 | 16MB |
| 3 | boot | 172032 | 65536 | 32MB |
| 4 | super | 237568 | 1665312 | ~813MB (stock) |
| 5 | misc | 3383296 | 32768 | - |
| 6 | recovery | 3416064 | 65536 | - |
| 7 | cache | 3481600 | 1310720 | - |
| 8 | vbmeta | 4792320 | 32768 | - |
| 9-16 | vbmeta_system/vendor, metadata, private, frp, empty, media_data, Reserve0 | ... | ... | ... |
| 17 | UDISK | 5054464 | до конца | ~27GB (32GB карта) |

---

## cardscript.fex — Blueprint для PhoenixCard

```ini
[process]
version = 300
mode = product        ; полная прошивка с GPT (не startup!)
startpos = 2006844    ; начало данных

[boot_0_0]            ; boot0_sdcard.fex
start = 16            ; сектор 16
type = 1              ; raw
commen = phoenix card_00

[boot_1_0]            ; boot_package.fex
start = 32800         ; сектор 32800
type = 1              ; raw
commen = phoenix card_10

[card_boot]
start = 40960         ; начало GPT
```

---

## PhoenixCard режимы

- **Product** — полная прошивка с GPT. Использует полный sys_config.fex. Триггерит hardware check.
- **StartUp** — временная загрузка БЕЗ GPT. Использует урезанный sys_config.fex. Обходит BL3-1 проверки.
- **BromRun** — загрузка через BROM

PhoenixCard 4.2.8+ (последняя 4.3.3) ОБЯЗАТЕЛЕН для Android 12.

---

## Три пути к рабочей прошивке

### Путь A: Бинарный патчинг оригинального IMAGEWTY
1. Распаковать оригинальный образ (OpenixIMG)
2. Найти offset super.fex в контейнере
3. Заменить super.fex на наш (бинарно)
4. Пересобрать IMAGEWTY

### Путь B: RAW-образ
Создать полный дамп SD-карты:
1. gpt.img (16 секторов GPT)
2. boot0_sdcard.fex (сектор 16)
3. boot_package.fex (сектор 32800)
4. boot-resource.fex → bootloader раздел
5. env.fex → env раздел
6. boot.fex → boot раздел
7. super.img (RAW, не sparse!) → super раздел

Записать через dd или DiskImager.

### Путь C: imgRePacker.exe через WSL
1. Установить WSL2 на Windows
2. Примонтировать btrfs диск: `wsl --mount \\.\PHYSICALDRIVEn --bare`
3. Внутри WSL: `sudo mount -t btrfs /dev/sdX1 /mnt/BF`
4. Собрать IMAGEWTY, используя imgRePacker.exe из WSL interop
5. Записать через PhoenixCard

---

## Настройка WSL

### Монтирование btrfs диска
```powershell
# PowerShell от администратора:
Get-Disk | Format-Table Number, FriendlyName, Size
wsl --mount \\.\PHYSICALDRIVEn --bare
```

```bash
# Внутри WSL:
lsblk
sudo mkdir -p /mnt/BF
sudo mount -t btrfs /dev/sdX1 /mnt/BF
```

### Перенос памяти MiMoCode
```bash
# На текущей Linux:
tar czf /tmp/mimocode-memory.tar.gz \
  /home/one/.local/share/mimocode/memory/ \
  /home/one/GitHub/PulsarOS/

# Внутри WSL:
tar xzf mimocode-memory.tar.gz -C /
```

### Файловая система
- **NTFS НЕ подходит** для сборки Android (case-insensitive, нет Unix permissions)
- **btrfs/ext4** — подходят
- **WSL2 ext4 VHD** — подходит, но исходники лучше не копировать (100GB+)

---

## Сборка Android — ключевые параметры

| Параметр | Значение |
|----------|----------|
| Lunch target | `apollo_p2-userdebug` |
| USE_CCACHE | `false` (НЕ `0`!) |
| BOARD_AVB_ENABLE | `false` (BoardConfig.mk:35) |
| BOARD_USES_RECOVERY_AS_BOOT | `false` (BoardConfig.mk:70) |
| ANDROID_SRC | `/mnt/BF/H618-Android12-Src` |
| Host | Debian 13 (trixie) |
| GNU Make | 4.3 (установлен из исходников) |

---

## Ошибки и решения

### Решённые
- **AVB kernel panic**: `BOARD_AVB_ENABLE := false`
- **boot.img 64MB → 32MB**: `BOARD_USES_RECOVERY_AS_BOOT := false` + чистый `out/`
- **Pack перезаписывает прошивку**: cp prebuilt firmware перед pack
- **vbmeta.fex not found**: AVB выключен → vbmeta не генерируется → убрать из sys_partition.fex
- **grep -oP тихо падает**: GNU grep 3.11. Использовать sed
- **dragon отвергает 0-byte файлы**: Нужен непустой контент

### Нерешённые (корневая проблема)
- **dragon IMAGEWTY ≠ imgRePacker IMAGEWTY**: cardtool.fex отвергает формат dragon
- **hardware check error1**: Даже с оригинальными файлами, dragon-контейнер не работает

---

## Структура файлов проекта

```
PulsarOS/
├── scripts/
│   ├── build.sh              # Главный скрипт сборки (v3.0, модульный)
│   ├── lib/
│   │   ├── common.sh         # Общие функции
│   │   └── config.sh         # Конфигурация
│   └── steps/
│       ├── 01-setup.sh       # Подготовка системы
│       ├── 02-fetch.sh       # Загрузка исходников
│       ├── 03-build-longan.sh # Сборка ядра/brandy
│       ├── 04-build-android.sh # Сборка Android
│       ├── 05-build-apps.sh  # Сборка приложений (RetroArch, Daijishou)
│       └── 06-create-image.sh # Создание IMAGEWTY
├── vendor/
│   └── pulsaros/
│       ├── boot-logo/        # bootlogo.bmp
│       ├── overlays/         # Device tree overlays
│       └── apps/             # APK файлы
├── patches/                  # BSP патчи
├── out/                      # Выход сборки
│   ├── logs/
│   ├── PulsarOS-OPiZero3-Android12-*.img
│   └── *.md5
└── docs/
    └── FLASHING.md           # Инструкция прошивки (EN+RU)
```

---

## Важные файлы BSP

| Файл | Описание |
|------|----------|
| `device/softwinner/apollo/BoardConfig.mk` | BSP BoardConfig (AVB, RECOVERY_AS_BOOT) |
| `device/softwinner/zero3/BoardConfig.mk` | Наш BoardConfig (переопределяет BSP) |
| `device/config/chips/h618/configs/p2/android/sys_partition.fex` | Разметка разделов |
| `device/config/chips/h618/bin/` | Prebuilt firmware (boot0, u-boot, sboot) |
| `longan/build/pack` | Pack скрипт (строка 1124: `dragon image.cfg sys_partition.fex`) |
| `longan/tools/pctools/linux/eDragonEx/dragon` | dragon tool (32-bit i386) |

---

## Следующий шаг

1. **Запустить MiMoCode внутри WSL** (не из PowerShell!)
2. Примонтировать btrfs диск в WSL
3. Выбрать один из трёх путей (A/B/C) выше
4. Реализовать и протестировать

---

## Дополнительные файлы памяти

- `~/.local/share/mimocode/memory/projects/947f2717-9b15-40e9-b19e-a6c2de07efa8/MEMORY.md` — основная память проекта (220+ строк)
- `MEMORY-build-setup.md` — детали настройки сборки
- `MEMORY-bsp-fixes.md` — исправления BSP
- `MEMORY-build-quirks.md` — особенности сборки
- `MEMORY-features.md` — описание функций PulsarOS
