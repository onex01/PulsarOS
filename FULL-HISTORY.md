# PulsarOS — Полная история проекта

> **Это продолжение чата с MiMoCode (ассистент).** Документ содержит ВСЕ знания, накопленные за несколько сессий. Используй его как отправную точку для нового чата.

---

## 1. Что такое PulsarOS

Android 12 прошивка для Orange Pi Zero 3 (Allwinner H618), портативная ретро-игровая консоль.
- 32-bit ARM userspace, 64-bit kernel
- RetroArch (24 ядра), Daijishou (лаунчер), Kodi, Browser (TVBro fork)
- Скрипт сборки: `scripts/build.sh` (модульный, v3.0, меню)
- **Web file manager**: NanoHTTPD HTTP server для загрузки игр с Windows
- **Gamepad autoconfig**: 11 профилей (Xbox/PS4/PS5/Switch/8BitDo/GameSir/IPEGA/Razer)
- **High refresh rate**: поддержка 120Hz через sunxi-drm driver

## 2. Где что лежит

| Путь | Описание |
|------|----------|
| `/mnt/BF/H618-Android12-Src` | BSP исходники (btrfs диск) |
| `/mnt/BF/OriginalVersion/H618-Android12-Src` | Оригинальный BSP (для отката патчей) |
| `/home/one/GitHub/PulsarOS/` | Наш репозиторий (скрипты, патчи, конфиги) |
| `/home/one/opizero3_android_12_mod_malay_all_wifi.img` | Оригинальный рабочий образ |
| `/home/one/GitHub/PulsarOS/out/` | Выходные файлы (образы, логи) |

### Ключевые BSP пути (ОБЯЗАТЕЛЬНО для патчей!)

| Что | BSP путь | Наш путь |
|-----|----------|----------|
| Boot animation | `device/softwinner/apollo/common/media/bootanimation/bootanimation.zip` | `vendor/pulsaros/bootanimation/bootanimation.zip` |
| Product config | `device/softwinner/apollo/apollo_p2.mk` | `device/softwinner/apollo/apollo_p2.mk` (копируем) |
| Vendor overlay | `vendor/pulsaros/pulsaros-vendor.mk` | `vendor/pulsaros/pulsaros-vendor.mk` |
| Prebuilt APKs | `vendor/pulsaros/prebuilt/apk/Android.mk` | `vendor/pulsaros/prebuilt/apk/Android.mk` |
| Libretro cores | `vendor/pulsaros/prebuilt/cores/*.so` | `vendor/pulsaros/prebuilt/cores/*.so` |
| RetroArch config | `vendor/pulsaros/config/retroarch/` | `vendor/pulsaros/config/retroarch/` |
| Daijishou config | `vendor/pulsaros/config/daijishou/` | `vendor/pulsaros/config/daijishou/` |
| Debloat | `vendor/pulsaros/debloat.mk` | `vendor/pulsaros/debloat.mk` |

## 3. Правила (ОБЯЗАТЕЛЬНЫ)

- Lunch target: **`apollo_p2-userdebug`** (pulsaros_zero3 вызывает каскадные ошибки VINTF/VNDK)
- `USE_CCACHE=false` (НЕ `0` — AOSP filter-out пропускает "0")
- Все исправления — в скриптах сборки (автоматизация)
- Сборка Android: `bash -c "source build/envsetup.sh; lunch apollo_p2-userdebug; make -j12"`
- Запуск longan/build НАПРЯМУЮ в терминале (не через скрипт/tee)
- `set +u` обязательно перед `source build/envsetup.sh`
- Syslog: не добавлять комментарии除非 нужно
- **НИКОГДА не заменять boot.fex** — наш boot.img содержит kernel+ramdisk (2 gzip), стоковый boot.fex содержит только kernel (1 gzip). Замена ломает загрузку.
- **Подход к сборке**: stock IMAGEWTY → imgRePacker unpack → заменить ТОЛЬКО super.fex + vbmeta*.fex → repack
- **Стоковое (не трогать)**: boot.fex, vendor_boot.fex, dtbo.fex, misc.fex, boot_package.fex, env.fex, sys_config.fex, boot-resource.fex, boot0, u-boot, sunxi.fex

---

## 4. КРИТИЧЕСКАЯ ПРОБЛЕМА: IMAGEWTY формат

### Что происходит
Скрипт `pack` вызывает `dragon image.cfg sys_partition.fex` → создаёт IMAGEWTY.
PhoenixCard прошивает IMAGEWTY на SD-карту.
**НО**: `dragon` (eDragonEx, 32-bit i386) Produces IMAGEWTY **несовместимый** с PhoenixCard.

### Доказательство
1. Оригинальный образ Orange Pi (`opizero3_android_12_mod_malay_all_wifi.img`) — **работает**
2. Мы извлекаем ВСЕ файлы из оригинала (boot.fex, vendor_boot.fex, sunxi.fex, super.fex, sys_config.fex)
3. Собираем IMAGEWTY из оригинальных файлов → **не работает**
4. sys_config.fex **байт-идентичен** между оригиналом и нашим BSP
5. BL3-1 **идентичен** (MD5 `7437440be6e471be18c43d7bb62542c0`)
6. optee.bin **идентичен** (MD5 `d31181de72a6863cb4aabd77e208fa95`)

### Корень проблемы
- **`imgRePacker`** (Windows инструмент от RedScorpio) — создаёт IMAGEWTY совместимый с PhoenixCard
- **`dragon`** (Linux 32-bit) — создаёт IMAGEWTY **несовместимый** с PhoenixCard
- Разница в формате контейнера, не в содержимом файлов
- cardtool.fex (плагин PhoenixCard) проверяет формат и выдаёт "Image error, use new version image file!"
- Оригинальный образ содержит `imgRePacker     (c) RedScorpio` в section table

### Что НЕ является корнем проблемы
- sys_config.fex — идентичен
- BL3-1 — идентичен
- optee.bin — идентичен
- Hardware check error1 — **также падает на оригинале в Product mode** (это особенность доски, не баг)
- PhoenixCard версия — 4.3.3 (последняя)
- boot0_sdcard.fex — разный (наша сборка vs оригинал)

### Решение ✅ НАЙДЕНО
**imgRePacker (Linux)** найден: `tools/bin/imgrepacker` (32-bit i386 ELF, v2.0.7.8, (c) RedScorpio)
- **Unpack**: `./imgrepacker image.img` → создаёт `image.img.dump/` с 45 секциями + `image.cfg`
- **Pack**: `./imgrepacker image.img.dump` → собирает IMAGEWTY (перезаписывает файл рядом с dump)
- **Формат image.cfg**: Lua-style `{filename = ..., maintype = ..., subtype = ...}`
- **Round-trip работает**: unpack → pack → идентичный образ по заголовку
- **Интегрирован** в `scripts/steps/06-create-image.sh`: dragon создаёт секции → imgRePacker пересобирает IMAGEWTY

---

## 5. Структура IMAGEWTY (из nskhuman.ru)

### Заголовок (96 байт)
```
Offset  Size  Описание
0x00    8     Магия "IMAGEWTY"
0x08    2     Версия (0x300)
0x0A    2     Размер заголовка (96)
0x0C    4     RAMbase (0x4d00000)
0x10    4     Версия образа (0x100234)
0x14    4     Размер файла
0x18    2     Выравнивание (0)
0x1A    2     Зарезервировано
0x1C    2     USB PID (0x1234)
0x1E    2     USB VID (0x8743)
0x20    2     Hard ID (0x100)
0x22    2     Firmware ID (0x100)
0x24    4     parX1 (1)
0x28    4     parX2 (1024)
0x2C    2     Размер записи таблицы (40)
0x2E    4     parX3 (1024)
0x32    48    Зарезервировано
```

### Таблица секций (40 байт на запись)
```
Offset  Size  Описание
0x00    4     Смещение данных
0x04    4     Длина данных
0x08    8     maintype (например "COMMON  ")
0x10    16    subtype (например "SYS_CONFIG100000")
0x20    4     Неизвестно
0x24    24    Имя файла (null-terminated)
0x3C    4     Оригинальный размер данных
0x40    4     Заполнение
0x44    4     Размер данных с выравниванием
0x48    4     Заполнение
0x4C    4     Смещение данных (0x18000)
```

### Секции IMAGEWTY (40+ штук)
**Группа 1 (Данные)**: sys_config, board, config, split, sys_partition, sunxi
**Группа 2 (Загрузка с SD/eMMC)**: sunxi_gpt, boot0_sdcard, boot_package
**Группа 3 (Инструменты PhoenixCard)**: sunxi_mbr, dlinfo, usbtool, aultools, cardscript, cardtool, fes1
**Группа 4 (Не записываются)**: sunxi.fex, u-boot.fex, sys_partition, sys_config, config, split
**Группа 5 (Проверка)**: V*.fex (4-байтные контрольные суммы от FileAddSum.exe)
**Группа 6 (Разное)**: toc1, toc0, arisc, usbtool_crash, board

---

## 6. Структура GPT (из nskhuman.ru)

```
Номер  Раздел             Стартовый LBA   Размер
1      bootloader         32768           32MB
2      env                98304           16MB
3      boot               131072          32MB
4      super              196608          ~1.5GB
5      misc               3383296         16MB
6      recovery           3416064         32MB
7      cache              3481600         ~640MB
8      vbmeta             4792320         16MB
9      vbmeta_system      4825088         16MB
10     vbmeta_vendor      4857856         16MB
11     metadata           4890624         16MB
12     private            4923392         16MB
13     frp                4956160         512KB
14     empty              4957184         ~15MB
15     media_data         4988928         16MB
16     Reserve0           5021696         16MB
17     UDISK              5054464         до конца
```

**First Usable LBA = 73728**

PhoenixCard создаёт GPT из **sunxi_mbr.fex + dlinfo.fex** (НЕ из sunxi_gpt.fex!).

---

## 7. Как PhoenixCard записывает образ

1. Читает cardtool.fex (Windows DLL-плагин) из IMAGEWTY
2. Читает cardscript.fex — инструкции по записи
3. Записывает boot0_sdcard.fex → **сектор 16** (16*512 = 8192)
4. Записывает boot_package.fex → **сектор 32800** (32800*512 = 16793600)
5. Создаёт GPT из sunxi_mbr.fex + dlinfo.fex → **сектор 40960**
6. Записывает остальные разделы (bootloader, env, boot, super, misc, recovery, cache, vbmeta)
7. super.fex = sparse → раскрывается в raw при записи
8. "Magic complete" = проверка split_xxxx.fex (UUID в magic.bin)

---

## 8. Cardscript.fex (инструкции PhoenixCard)

```ini
[process]
version = 300
mode = product
startpos = 2006844
data = 0

[boot_0_0]
main = 12345678
sub = 1234567890BOOT_0
start = 16
sectors = 0
type = 1
commen = phoenix card_00

[boot_1_0]
main = 12345678
sub = BOOTPKG-00000000
start = 32800
sectors = 0
type = 1
commen = phoenix card_10

[card_boot]
start = 40960
```

---

## 9. Все ссылки nskhuman.ru (ОБЯЗАТЕЛЬНО ИЗУЧИТЬ)

| Ссылка | Содержание |
|--------|------------|
| http://nskhuman.ru/menu.php?cat=4 | Индекс всех документов Allwinner |
| http://nskhuman.ru/allwinner/firmware.php?np=1 | Формат IMAGEWTY (заголовок, таблица секций) |
| http://nskhuman.ru/allwinner/firmware.php?np=2 | Содержимое секций |
| http://nskhuman.ru/allwinner/firmware.php?np=3 | GPT структура |
| http://nskhuman.ru/allwinner/firmware.php?np=4 | Утилиты, резервное копирование, dd команды |
| http://nskhuman.ru/allwinner/firmware.php?np=5 | RAW формат образа |
| http://nskhuman.ru/allwinner/firmware.php?np=2&nf=1 | super.fex (sparse) |
| http://nskhuman.ru/allwinner/firmware.php?np=2&nf=2 | boot-resource.fex (FAT16, bootlogo) |
| http://nskhuman.ru/allwinner/firmware.php?np=2&nf=3 | boot_package.fex (u-boot, DTB, OP-TEE) |
| http://nskhuman.ru/allwinner/firmware.php?np=2&nf=4 | boot0_sdcard.fex (DRAM init) |
| http://nskhuman.ru/allwinner/firmware.php?np=2&nf=5 | cardscript.fex (инструкции PhoenixCard) |
| http://nskhuman.ru/allwinner/firmware.php?np=2&nf=6 | cardtool.fex (плагин PhoenixCard) |
| http://nskhuman.ru/allwinner/firmware.php?np=2&nf=7 | split_xxxx.fex (magic.bin UUID) |
| http://nskhuman.ru/allwinner/firmware.php?np=2&nf=8 | fes1.fex (USB FEL mode) |

---

## 10. Цепочка загрузки H618

```
Boot0 (SRAM) → DRAM init → чтение IMAGEWTY
  ↓
BL3-1 (ATF) → проверка PMIC + DTB
  ↓ (hardware check error1 = ошибка)
U-Boot → чтение GPT, проверка AVB
  ↓ (data abort = нет раздела)
Kernel → монтирование system/vendor
  ↓ (Unable to mount root fs = неверный root device)
Android init → framework
```

---

## 11. Что работает и что нет

### Работает
- ✅ pulsaros-v6.img загружается на Orange Pi Zero 3
- ✅ Stock firmware (boot.fex, boot_package.fex, env.fex) + наш bootlogo + наш super.fex
- ✅ imgRePacker работает (Linux 32-bit, v2.0.7.8, tools/bin/imgrepacker)
- ✅ ADB через USB работает
- ✅ RetroArch, Daijishou, Kodi, F-Droid установлены
- ✅ Libretro cores (24 ядра) через Android.mk
- ✅ Boot animation 4.8MB (наша)
- ✅ Density 213, Dark theme, DPI setting
- ✅ 21 stock app скрыто
- ✅ Stock firmware в img/patch/fex/ (13 файлов, 73MB)

### Не работает / Требует доработки
- ❌ PulsarSetup не установлен в текущем билде
- ❌ Libretro cores не попадают в product output (требует rebuild с Android.mk)
- ❌ ro.product.brand/model — read-only (требует build.prop)
- ❌ Security patch 2022-02-05 (не трогаем)
- ❌ GMS variant не создан (только Vanilla)
- ❌ Web File Manager не установлен
- ❌ 120Hz не настроен
- ❌ USB auto-mount не настроен
- ❌ Game Translator не создан

---

## 12. Следующий шаг: WSL2

### Почему WSL2
- Можно запускать Windows .exe из Linux
- imgRePacker.exe доступен напрямую
- Btrfs диск примонтируется в WSL2

### Монтаж btrfs диска в WSL2

**PowerShell (от администратора):**
```powershell
# Найти номер диска с btrfs:
Get-Disk | Format-Table Number, FriendlyName, Size

# Подключить диск к WSL:
wsl --mount \\.\PHYSICALDRIVEn --bare
# (n = номер диска)
```

**WSL (внутри):**
```bash
# Найти диск:
lsblk

# Смонтировать:
sudo mkdir -p /mnt/BF
sudo mount -t btrfs /dev/sdX1 /mnt/BF
```

### Память MiMoCode

Структура памяти:
```
~/.local/share/mimocode/memory/
  projects/
    947f2717-9b15-40e9-b19e-a6c2de07efa8/
      MEMORY.md           — основная память проекта
      MEMORY-build-setup.md
      MEMORY-bsp-fixes.md
      MEMORY-build-quirks.md
      MEMORY-features.md
  sessions/
    ses_xxx/
      checkpoint.md       — чекпоинты сессий
```

Для переноса:
```bash
# На текущей Linux:
tar czf /tmp/mimocode-memory.tar.gz \
  /home/one/.local/share/mimocode/memory/

# Скопировать на USB/облако

# В WSL:
tar xzf mimocode-memory.tar.gz -C /
```

### Запуск сессии

**Начинай сессию из WSL (не из PowerShell):**
```bash
# В WSL:
cd /mnt/BF/H618-Android12-Src
# или
cd /home/one/GitHub/PulsarOS
```

MiMoCode автоматически подхватит память проекта.

### Типичный промпт для нового чата

```
Продолжаем проект PulsarOS. Читай FULL-HISTORY.md в /home/one/GitHub/PulsarOS/
Корневая проблема: dragon tool Produces IMAGEWTY несовместимый с PhoenixCard.
Нужно найти imgRePacker.exe или написать Python-реализацию.
Исходники на btrfs диске: /mnt/BF/H618-Android12-Src
Оригинальный образ: /home/one/opizero3_android_12_mod_malay_all_wifi.img
OpenixIMG (extract only): /tmp/OpenixIMG/build/app/openiximgcli
Все ссылки nskhuman.ru в FULL-HISTORY.md §9
```

---

## 13. dd команды для резервного копирования (из nskhuman.ru np=4)

```bash
dd if=/dev/block/mmcblk0 of=bootloader-backup.img bs=512 skip=73728 count=65536
dd if=/dev/block/mmcblk0 of=env-backup.img bs=512 skip=139264 count=32768
dd if=/dev/block/mmcblk0 of=boot-backup.img bs=512 skip=172032 count=65536
dd if=/dev/block/mmcblk0 of=super-backup.img bs=512 skip=237568 count=3145728
dd if=/dev/block/mmcblk0 of=misc-backup.img bs=512 skip=3383296 count=32768
dd if=/dev/block/mmcblk0 of=recovery-backup.img bs=512 skip=3416064 count=65536
dd if=/dev/block/mmcblk0 of=cache-backup.img bs=512 skip=3481600 count=1310720
dd if=/dev/block/mmcblk0 of=vbmeta-backup.img bs=512 skip=4792320 count=32768
dd if=/dev/block/mmcblk0 of=vbmeta_system-backup.img bs=512 skip=4825088 count=32768
dd if=/dev/block/mmcblk0 of=vbmeta_vendor-backup.img bs=512 skip=4857856 count=32768
dd if=/dev/block/mmcblk0 of=metadata-backup.img bs=512 skip=4890624 count=32768
dd if=/dev/block/mmcblk0 of=private-backup.img bs=512 skip=4923392 count=32768
dd if=/dev/block/mmcblk0 of=frp-backup.img bs=512 skip=4956160 count=1024
dd if=/dev/block/mmcblk0 of=empty-backup.img bs=512 skip=4957184 count=31744
dd if=/dev/block/mmcblk0 of=media_data-backup.img bs=512 skip=4988928 count=32768
dd if=/dev/block/mmcblk0 of=Reserve0-backup.img bs=512 skip=5021696 count=32768
```

---

## 14. RAW-подход (альтернатива IMAGEWTY)

RAW-образ = полный дамп SD-карты. Пишется через dd/DiskImager.
Структура: gpt.img + boot0_sdcard + boot_package + boot-resource + env + boot.fex + super.img (raw 1.5GB)
super.img в RAW = raw (не sparse!). Размер ~1.7GB.
VBMETA отключен.

Если IMAGEWTY формат не удастся починить — это запасной путь.

---

## 15. Ключевые файлы BSP (для патчей)

| Файл | Что делаем |
|------|-----------|
| `device/softwinner/apollo/BoardConfig.mk:35` | `BOARD_AVB_ENABLE := false` |
| `device/softwinner/apollo/BoardConfig.mk:70` | `BOARD_USES_RECOVERY_AS_BOOT := false` |
| `longan/build/pack` (строка 1124) | `dragon image.cfg sys_partition.fex` |
| `longan/build/pack` (symlink fix) | `ln -sf` → `cp` для dragon |
| `longan/out/pack_out/image.cfg` | Конфиг IMAGEWTY |
| `longan/device/config/chips/h618/configs/p2/android/sys_partition.fex` | Таблица разделов |

---

## 16. Ошибки и их решения

| Ошибка | Решение |
|--------|---------|
| `hardware check error1` | **Падает и на оригинале в Product mode** — не баг |
| `mmc 2 not found` | Безвредно (нет eMMC на OPi Zero 3) |
| `unable to open file vbmeta.fex` | AVB выключен → нет vbmeta*.img → удалить из sys_partition.fex |
| `file dtbo.fex length = 0` | dragon отвергает 0-байтные файлы |
| `data abort` в U-Boot | vendor_boot отсутствует в sys_partition.fex |
| `Unable to mount root fs` | Неверный root device или раздел super |
| `GOGC goroutine panic` | `GOGC=50` предотвращает |
| `BINDER_IPC_32BIT` cast error | `-Wno-int-to-void-pointer-cast` в global.go |
| `Check error: startpos` | cardscript.fex не найден или неверен |
| `Image error, use new version image file!` | **dragon формат несовместим с PhoenixCard** |

---

## 17. Новые фичи (план)

### App Store
- **Aptoide TV** — альтернатива Google Play, работает без GMS
- **F-Droid** — open-source магазин приложений
- **Vanilla версия**: без GMS, с Aptoide TV + F-Droid
- **Gapps версия**: с Google Play Services + Google Play Store

### AVB (Android Verified Boot)
- Сейчас выключен (`BOARD_AVB_ENABLE := false`)
- Для продакшена нужен включённый AVB с signing keys
- Две ветки сборки: debug (AVB off) и release (AVB on)

### Дебloat
- Уже готово: `vendor/pulsaros/debloat.mk` (30+ пакетов)
- Удалить: Google TV, Leanback, Browser2, Gallery, Camera, SoundRecorder, NFC, TV Input

### Web file manager
- NanoHTTPD HTTP server на порту 8080
- HTML интерфейс для загрузки файлов с Windows
- Решает "нет доступа к памяти из Windows"

### Gamepad autoconfig
- 11 профилей в `vendor/pulsaros/config/retroarch/autoconfig/`
- Xbox One (BT/USB), PS4, PS5, Switch Pro, 8BitDo, GameSir, IPEGA, Razer, Generic

### High refresh rate (120Hz)
- sunxi-drm driver поддерживает до 120Hz
- `settings put system peak_refresh_rate 120`

---

## 18. Модули сборки

```
scripts/build.sh          — главный менеджер
scripts/lib/common.sh     — общие функции
scripts/lib/config.sh     — переменные конфигурации
scripts/steps/01-setup.sh — системная подготовка
scripts/steps/02-longan.sh — сборка longan (kernel)
scripts/steps/03-android.sh — сборка Android
scripts/steps/04-cores.sh — сборка ядер RetroArch
scripts/steps/05-apks.sh — загрузка APK
scripts/steps/06-create-image.sh — pack + IMAGEWTY
```

---

*Документ создан: 2026-07-13*
## 19. Сессия 2026-07-16/17: boot.fex + imgRePacker + финальная сборка

### Найдено и исправлено

1. **imgRePacker найден** (`tools/bin/imgrepacker`, v2.0.7.8, Linux 32-bit, RedScorpio)
   - Unpack: `./imgrepacker image.img` → создаёт `.dump/` с 45 .fex + image.cfg
   - Pack: `./imgrepacker .dump/` → IMAGEWTY совместимый с PhoenixCard
   - Round-trip тест: ✅ работает

2. **boot.fex формат — КОРНЕВАЯ ПРОБЛЕМА**
   - Стоковый boot.fex: **1 gzip stream** (только kernel)
   - Наш boot.img: **2 gzip streams** (kernel + ramdisk)
   - Kernel binary **идентичен** (MD5 совпадает), но формат boot.fex разный
   - header_version = 0 **не решает** проблему — ramdisk всё равно встроен
   - **Решение**: стоковый boot.fex оставляем, заменяем ТОЛЬКО super.fex

3. **Dragon pack создаёт 25 секций, стоковый образ — 45**
   - Отсутствуют: dtbo.fex, misc.fex, Vdtbo.fex, Vmisc.fex
   - **Решение**: imgRePacker напрямую (без dragon)

4. **Console ttyS0 → ttyAS0**
   - Стоковый env.fex: `console=ttyAS0,115200` (Allwinner UART)
   - Наш U-Boot: `console=ttyS0,115200` (generic 8250)
   - Исправлено в sunxi-common.h + env.fex

5. **AVB включён** (`BOARD_AVB_ENABLE := true`)

6. **boot-resource.fex** — FAT16 образ с bootlogo.bmp
   - Парсинг FAT16 через Python (mtools не работает с нестандартной геометрией)
   - Замена bootlogo.bmp в FAT16 (цепочка кластеров 563 кластера)

7. **F-Droid добавлен** в build (12MB APK)

8. **Init-скрипты созданы**:
   - `pulsaros-firstboot.sh` — копирует конфиги при первом запуске
   - `pulsaros-webserver.sh` — HTTP сервер на порту 8080
   - `init.pulsaros.rc` — Android init service definitions

9. **Linux flasher создан** (`scripts/flash-sdcard.sh`)
   - Распаковывает IMAGEWTY → записывает boot0/boot_package → создаёт GPT из sys_partition.fex

### Финальная стратегия сборки

**Рабочий pipeline (V2)**:
```
Stock IMAGEWTY → imgRePacker unpack → заменить super.fex + boot-resource.fex + vbmeta*.fex → imgRePacker repack
```

- ✅ **Работает** — подтверждено пользователем
- ✅ Стоковый kernel (boot.fex) с правильным форматом
- ✅ Наш Android system (super.fex)
- ✅ Наш bootlogo (boot-resource.fex)

**Альтернатива (полная сборка)**: см. PLAN.md

### Ключевые файлы этой сессии

| Файл | Что делает |
|------|-----------|
| `scripts/steps/00-prepare-bsp.sh` | Патчи BSP (AVB, header_version=0, console, APKs, configs) |
| `scripts/steps/05-build-android.sh` | Сборка Android с интеграцией BSP |
| `scripts/steps/06-create-image.sh` | imgRePacker pipeline (unpack stock → replace → repack) |
| `scripts/flash-sdcard.sh` | Linux прошивка через dd + GPT |
| `img/patch/fex/boot.fex` | Стоковый kernel (64MB) |
| `img/patch/fex/boot-resource.fex` | Стоковый boot-resource с нашим bootlogo |
| `vendor/pulsaros/pulsaros-vendor.mk` | PRODUCT_COPY_FILES для APKs, configs, cores |
| `vendor/pulsaros/debloat.mk` | Список удалённых пакетов |
| `vendor/pulsaros/scripts/init.pulsaros.rc` | Android init services |
| `vendor/pulsaros/scripts/pulsaros-firstboot.sh` | First-boot config copy |
| `vendor/pulsaros/scripts/pulsaros-webserver.sh` | HTTP file server |
| `PLAN.md` | Альтернативный план: полная сборка BSP |

---

*Последнее обновление: 2026-07-17*
*Следующий шаг: GMS/Vanilla variants → Android debugging → GitHub push*
