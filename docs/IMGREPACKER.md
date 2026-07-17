# imgRePacker — Инструмент для работы с IMAGEWTY

> **Автор**: RedScorpio (RedScorpio.lab@gmail.com), Moscow, 2012-2022
> **Версия**: 2.0.7.8 (Linux & Windows)
> **Лицензия**: Проприетарный, но распространяется открыто
> **Источник**: XDA Developers (требуется VPN из РФ)

## Назначение

Распаковка/запаковка образов прошивок Allwinner (IMAGEWTY формат) для PhoenixCard/PhoenixSuite.

## Бинарники

| Файл | Платформа | Описание |
|------|-----------|----------|
| `imgrepacker` | Linux x86_32 | Основной инструмент (работает в WSL2) |
| `imgRePacker.exe` | Windows x86_32 | Windows версия |
| `zlib1.dll` | Windows | Библиотека для Windows версии |
| `lzma.exe` | Windows | Утилита сжатия |

## Использование

### Распаковка IMAGEWTY

```bash
# Распаковать образ прошивки
./tools/bin/imgrepacker OrangePi_Zero3_Android12_v1.0.img

# Результат: создается директория <имя_файла>.dump/
# Содержимое: все .fex секции + image.cfg
```

### Запаковка IMAGEWTY

```bash
# Запаковать из .dump директории
./tools/bin/imgrepacker <имя_директории>.dump

# ВАЖНО: директория ДОЛЖНА заканчиваться на .dump!
# Например: OrangePi_Zero3_Android12_v1.0.img.dump

# Результат: создается файл <имя_директории> (без .dump)
```

### Опции

| Опция | Описание |
|-------|----------|
| `/log` | Создавать log-файл |
| `/debug` | Отладочная информация (требует /log) |
| `/quiet` | Без вывода в консоль |
| `/noiso` | Не формировать ISO образы файловых систем |
| `/2nd` | Распаковка/запаковка файлов второго слоя |
| `/skip` | Пропустить проверку размера файла |

## Формат image.cfg

imgRePacker использует Lua-формат конфигурации:

```lua
[DIR_DEF]
INPUT_DIR = ""

[FILELIST]
    {filename = INPUT_DIR .. "sys_config.fex", maintype = "COMMON  ", subtype = "SYS_CONFIG100000",},
    {filename = INPUT_DIR .. "boot.fex", maintype = "RFSFAT16", subtype = "BOOT_FEX00000000",},
    -- ... другие секции

[IMAGE_CFG]
version = 0x00100234;
subversion = 0x00000060;  -- КЛЮЧЕВОЕ: формат imgRePacker (совместим с PhoenixCard)
pid = 0x00001234;
vid = 0x00008743;
hardwareid = 0x0100;
firmwareid = 0x0100;
filelist = FILELIST
```

**Ключевое отличие от dragon**: поле `subversion = 0x60` в IMAGE_CFG. Без него PhoenixCard отклоняет образ с ошибкой "Image error, use new version image file!".

## Полный pipeline

```bash
# 1. Распаковать оригинальный образ
./tools/bin/imgrepacker original.img
# → original.img.dump/ (45 .fex файлов + image.cfg)

# 2. Модифицировать секции (super.fex, boot.fex и т.д.)
cp modified_super.fex original.img.dump/super.fex

# 3. Запаковать обратно
./tools/bin/imgrepacker original.img.dump
# → original.img (пересобранный IMAGEWTY)

# 4. Прошить через PhoenixCard (StartUp режим)
```

## Структура IMAGEWTY

```
Offset     Описание
0x000000   Header (96 bytes): magic "IMAGEWTY", version, subversion=0x60
0x000060   Creator string / padding (32 bytes)
0x000080   ...
0x000400   Section table (45 entries × 1024 bytes)
0x00B800   Data area (секции подряд)
```

## Секции IMAGEWTY (OrangePi Zero3)

| # | Секция | Описание |
|---|--------|----------|
| 1-6 | sys_config, board, config, split, sys_partition, sunxi | Конфигурация |
| 7-8 | boot0_nand, boot0_sdcard | DRAM init (60 KB) |
| 9-14 | u-boot, u-boot-crash, toc1, toc0, fes1, boot_package | Загрузчик |
| 15-23 | usbtool, aultools, cardtool, cardscript, sunxi_gpt, sunxi_mbr, dlinfo | Инструменты |
| 24 | vmlinux | Ядро Linux (~12 MB) |
| 25-26 | boot-resource, Vboot-resource | FAT16 с bootlogo |
| 27-28 | env, Venv | U-Boot переменные |
| 29-30 | boot, Vboot | Android boot image (~64 MB) |
| 31-32 | vendor_boot, Vvendor_boot | Vendor boot (~32 MB) |
| 33-34 | super, Vsuper | System+Vendor (~1 GB, sparse) |
| 35-42 | misc, vbmeta, vbmeta_system, vbmeta_vendor | Метаданные |
| 43-44 | dtbo, Vdtbo | Device tree overlay |

## Решение проблем

### "Image error, use new version image file!"
PhoenixCard отклоняет образ. Причина: `subversion != 0x60`. Используйте imgRePacker вместо dragon.

### "Can't find file"
Убедитесь, что:
1. Директория заканчивается на `.dump`
2. Файлы .fex находятся в той же директории что и image.cfg
3. image.cfg содержит `[DIR_DEF] INPUT_DIR = ""`

### Segmentation fault
Попробуйте запустить из директории где лежит .dump:
```bash
cd /path/to/parent/
./tools/bin/imgrepacker directory.dump
```
