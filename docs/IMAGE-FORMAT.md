# Allwinner IMAGEWTY Firmware Format / Формат прошивки IMAGEWTY

> [English](#english) | [Русский](#русский)

---

## English

### Overview

Allwinner SoCs (including H618) use a proprietary firmware image format called **IMAGEWTY**. This format is created by the `pack` tool in the longan build system and is required for flashing via PhoenixCard/PhoenixSuite.

**Reference**: http://nskhuman.ru/allwinner/firmware.php

### Image Structure

An IMAGEWTY image consists of:

1. **Header** (96 bytes): Magic string `IMAGEWTY`, version, partition count, offsets
2. **Partition table** (40 bytes per entry): Type, name, offset, size for each section
3. **Sections** (variable count): Actual data partitions

### Standard Sections (Orange Pi Zero 3)

The image contains these sections at specific offsets:

| # | Section | Size | Offset | Description |
|---|---------|------|--------|-------------|
| 1 | sys_config.fex | 22543 | 0xa400 | Hardware configuration |
| 2 | board.fex | 1024 | 0x10000 | Board configuration |
| 3 | config.fex | 30720 | 0x10400 | System configuration |
| 4 | split_xxxx.fex | 512 | 0x17c00 | Partition split info |
| 5 | sys_partition.fex | 5238 | 0x18000 | Partition table |
| 6 | sunxi.fex | 129536 | 0x19800 | SoC configuration |
| 7 | boot0_nand.fex | 49152 | 0x39400 | NAND bootloader |
| 8 | boot0_sdcard.fex | 49152 | 0x45400 | SD card bootloader |
| 9 | u-boot.fex | 1015808 | 0x51400 | U-Boot bootloader |
| 10 | boot-resource.fex | 5876736 | 0x380000 | Boot resources (logo, etc.) |
| 11 | boot.fex | 33554432 | 0x93b400 | Linux kernel + ramdisk |
| 12 | super.fex | 852623532 | 0x293b800 | Android system (system+vendor+product) |
| 13 | recovery.fex | 33554432 | 0x3565c000 | Recovery partition |
| 14 | vbmeta.fex | 4096 | 0x3765c400 | Verified boot metadata |
| 15 | vbmeta_system.fex | 4096 | 0x3765d800 | System VB metadata |
| 16 | vbmeta_vendor.fex | 4096 | 0x3765ec00 | Vendor VB metadata |

Each section has a corresponding `V<section>.fex` verification file (4 bytes).

### How `pack` Creates the Image

The `pack` command in `longan/build.sh`:

1. Builds kernel, bootloader, and Android
2. Assembles all `.fex` sections
3. Creates IMAGEWTY header with magic `IMAGEWTY`
4. Writes partition table
5. Concatenates all sections at correct offsets
6. Outputs: `longan/out/h618_android12_p2_uart0.img`

### Flashing Tools

- **PhoenixCard**: Creates bootable SD card from IMAGEWTY image
- **PhoenixSuite**: Flashes via USB connection
- **Linux `dd`**: Direct write to SD card (for raw images)

### Why dd-concat Is Wrong

The current `dd`-concatenation approach in PulsarOS simply concatenates boot.img + system.img + vendor.img + userdata.img. This is **not** a valid IMAGEWTY image because:
- Missing header and partition table
- Missing bootloader sections (boot0, u-boot)
- Missing boot resources (logo)
- Missing verified boot metadata
- Incorrect offsets

The `pack` tool should be used instead to create proper IMAGEWTY format.

---

## Русский

### Обзор

SoC Allwinner (включая H618) используют проприетарный формат прошивки **IMAGEWTY**. Этот формат создаётся инструментом `pack` в системе сборки longan и необходим для прошивки через PhoenixCard/PhoenixSuite.

**Источник**: http://nskhuman.ru/allwinner/firmware.php

### Структура образа

IMAGEWTY образ состоит из:

1. **Заголовок** (96 байт): Magic-строка `IMAGEWTY`, версия, количество разделов, смещения
2. **Таблица разделов** (40 байт на запись): Тип, имя, смещение, размер для каждого раздела
3. **Разделы** (переменное количество): Данные

### Стандартные разделы (Orange Pi Zero 3)

| # | Раздел | Описание |
|---|--------|----------|
| 1 | sys_config.fex | Конфигурация оборудования |
| 2 | board.fex | Конфигурация платы |
| 3 | config.fex | Конфигурация системы |
| 5 | sys_partition.fex | Таблица разделов |
| 6 | sunxi.fex | Конфигурация SoC |
| 8 | boot0_sdcard.fex | Загрузчик SD карты |
| 9 | u-boot.fex | U-Boot загрузчик |
| 10 | boot-resource.fex | Ресурсы загрузки (логотип) |
| 11 | boot.fex | Ядро Linux + ramdisk |
| 12 | super.fex | Android система (system+vendor+product) |
| 13 | recovery.fex | Раздел восстановления |
| 14 | vbmeta.fex | Метаданные verified boot |

### Как `pack` создаёт образ

Команда `pack` в `longan/build.sh`:

1. Собирает ядро, загрузчик и Android
2. Собирает все секции `.fex`
3. Создаёт заголовок IMAGEWTY с magic `IMAGEWTY`
4. Записывает таблицу разделов
5. Конкатенирует все секции по правильным смещениям
6. Вывод: `longan/out/h618_android12_p2_uart0.img`

### Инструменты прошивки

- **PhoenixCard**: Создаёт загрузочную SD карту из IMAGEWTY образа
- **PhoenixSuite**: Прошивает через USB
- **Linux `dd`**: Прямая запись на SD карту (для raw образов)

### Почему dd-concat неправильный

Текущий подход с dd-concat просто склеивает boot.img + system.img + vendor.img + userdata.img. Это **не** валидный IMAGEWTY образ, потому что:
- Нет заголовка и таблицы разделов
- Нет секций загрузчика (boot0, u-boot)
- Нет ресурсов загрузки (логотип)
- Нет метаданных verified boot
- Неправильные смещения

Нужно использовать инструмент `pack` для создания правильного формата IMAGEWTY.
