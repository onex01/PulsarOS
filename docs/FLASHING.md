# Flashing Instructions / Инструкция по прошивке

> [English](#english) | [Русский](#русский)

---

## English

### Prerequisites

- PulsarOS firmware image (`out/PulsarOS-OPiZero3-Android12-*.img`)
- MicroSD card (16GB+, SanDisk recommended)
- Windows PC (for PhoenixCard)

### Method 1: PhoenixCard (Recommended)

Download PhoenixCard 4.3.3 with Russian localization:
http://nskhuman.ru/allwinner/card/phoenixcard433rus.zip

**Important**: Install Microsoft VisualC++ 2008 Redistributable first.

#### Steps:
1. Extract PhoenixCard from zip
2. Run `phoenixcard.exe`
3. Click **Image** button, select `PulsarOS-*.img`
4. Select your SD card from the dropdown
5. Mode: **StartUp** (启动卡)
6. Click **Burn** (Записать)
7. Wait for completion
8. Remove SD card

**Про режим — в репозитории было противоречие.** `FLASHING.md` требовал
«Product», а `SESSION-HANDOFF.md` сообщал, что стоковый образ грузится
только в «StartUp», а «Product» на этой плате не работает. Проверено на
стоковой прошивке было именно **StartUp**, поэтому начинайте с него.

Если карта не грузится — попробуйте «Product», но это менее вероятный путь:
в режиме StartUp PhoenixCard создаёт таблицу разделов, без которой плата
не стартует.

### Method 2: Linux (native, no Windows)

`dd` всего образа **не работает**: IMAGEWTY — контейнер прошивки, а не образ
диска. Карте нужны boot0 по смещению 8 КиБ, особая таблица разделов
Allwinner и содержимое разделов по абсолютным смещениям. Скрипт делает это
сам:

```bash
sudo scripts/flash-linux.sh out/PulsarOS-20261107.img /dev/sdX
```

Проверка без записи и проверка уже записанной карты:

```bash
sudo scripts/flash-linux.sh out/PulsarOS-*.img /dev/sdX --dry-run
sudo scripts/flash-linux.sh out/PulsarOS-*.img /dev/sdX --verify-only
```

Раскладка, которую он пишет (все смещения берутся из `sunxi_mbr.fex` внутри
образа, а не задаются в скрипте):

| Смещение | Что |
| --- | --- |
| 0 | protective MBR + заголовок GPT + 26 записей (LBA 2..8, до `boot0`) |
| 8 КиБ (сектор 16) | `boot0_sdcard.fex` — первичный загрузчик, BROM читает отсюда |
| 16.79 МиБ (сектор 32800) | `boot_package.fex` — u-boot + optee + dtb |
| 20 МиБ (сектор 40960) | `bootloader_a` — FAT16 32 МиБ с нашим `bootlogo.bmp` |
| дальше | `bootloader_b`, `env_a/b`, `boot_a/b`, `vendor_boot_a/b`, `super`, `misc`, `vbmeta*`, `dtbo_a/b`, `media_data`, `boot-resource` (32 МиБ, резервная копия логотипа), `userdata` |
| `диск − 33` … `диск − 1` | резервная копия GPT: 32 сектора записей + заголовок в последнем секторе |

После записи скрипт сверяет sha256 каждого записанного участка с образом и
отдельно проверяет, что заголовок резервной копии GPT лежит в последнем
секторе карты.

**Геометрия резервной копии GPT критична.** Если она не там, где её ищет
u-boot, он считает таблицу битой (`the GPT table is bad` — строка есть в его
бинарнике рядом с `update gpt fail`), пытается «починить» её и пишет копию в
первый раздел. Это уничтожает FAT с `bootlogo.bmp` до того, как
`boot_gui_init` успеет прочитать логотип. Симптом в логе:

```
[mmc]: MMC: block number 0x75c1007 exceeds max(0x75c1000)
[mmc]: write block failed
update gpt fail
```

Число `0x75c1007` — это `размер карты + 7`, то есть записи уехали за конец.
`mkgpt.py` теперь повторяет раскладку Allwinner (как в `sunxi_gpt.fex`):

```
first_usable    = entries_lba + ceil(count * 128 / 512)   = 9
last_usable     = last_lba - 33
entries (backup) = диск - 33 … диск - 2
header  (backup) = диск - 1
```


**Таблица разделов — GPT, а не Allwinner MBR.** u-boot в этой прошивке
разбирает разделы только через `part_get_info_efi`; с MBR он пишет
`Invalid GPT` и не находит ни `env`, ни `boot`. Поэтому флешер пишет
protective MBR + GPT (и резервную копию в конце карты), а имена разделов
берёт из `sys_partition.fex` — их ждёт Android через
`/dev/block/by-name/<name>`. Исключение: `UDISK` называется `userdata`,
потому что так его ищут и u-boot, и fstab.

**Смещения не угадываются.** Их берёт `tools/flashplan.py` из
`cardscript.fex` — скрипта, который исполняет сам PhoenixCard:

```
[boot_0_0]   start=16      boot0
[boot_1_0]   start=32800   boot_package
[card_boot]  start=40960   начало разделов
```

Из этого же следует, что `sunxi_mbr.fex` надо сдвигать: в нём первый раздел
начинается с сектора 32768 (16 МиБ), а `boot_package` занимает
32800–35328 (16.79–17.26 МиБ), то есть попал бы внутрь `bootloader_a`.
Сдвиг = `card_boot` − первый раздел MBR = 8192 сектора (4 МиБ).

Первая версия флешера писала `boot_package` на 128 КиБ и не сдвигала MBR —
плата отвечала `error:bad magic` / `Loading boot-pkg fail(error=4)`.
Причина ошибки: в заголовке `boot0` по смещениям `0x1c` и `0x20` стоит
`0x20000`, и это адрес загрузки в SRAM, а не смещение на карте.

### Method 3: dd (не работает)

Оставлено для истории. `dd` пишет IMAGEWTY как есть, без boot0 и таблицы
разделов — плата не загрузится.

IMAGEWTY format can be written with `dd` but may not boot on all boards:
```bash
sudo dd if=PulsarOS-OPiZero3-Android12-*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### First Boot

1. Insert SD card into Orange Pi Zero 3
2. Connect HDMI monitor
3. Connect USB-C power (5V/3A)
4. Connect gamepad via USB or Bluetooth
5. Wait for boot animation (~30 seconds)
6. OOBE wizard will start automatically

### References

- [Flashing guide (Russian)](http://nskhuman.ru/allwinner/opizero3/zero3man.php?np=15&nlang=1)
- [PhoenixCard documentation](http://nskhuman.ru/allwinner/card/phoenixcard.php)
- [IMAGEWTY format](http://nskhuman.ru/allwinner/firmware.php)

---

## Русский

### Предварительные требования

- Образ прошивки PulsarOS (`out/PulsarOS-OPiZero3-Android12-*.img`)
- MicroSD карта (16GB+, рекомендуется SanDisk)
- Windows ПК (для PhoenixCard)

### Способ 1: PhoenixCard (Рекомендуется)

Скачать PhoenixCard 4.3.3 с русской локализацией:
http://nskhuman.ru/allwinner/card/phoenixcard433rus.zip

**Важно**: Сначала установите Microsoft VisualC++ 2008 Redistributable.

#### Пошагово:
1. Распакуйте PhoenixCard из zip
2. Запустите `phoenixcard.exe`
3. Нажмите кнопку **Image**, выберите `PulsarOS-OPiZero3-Android12-*.img`
4. Выберите SD карту из выпадающего списка
5. **Выберите режим "Product"** (НЕ "StartUp"!)
6. Нажмите **Burn** (Записать)
7. Дождитесь завершения
8. Извлеките SD карту

**⚠️ ВНИМАНИЕ**: PhoenixCard 4.2.8 по умолчанию использует режим "StartUp" для Android 12. StartUp НЕ создаёт таблицу разделов — плата не загрузится! Всегда выбирайте режим **Product**.

### Способ 2: Linux dd (Экспериментальный)

IMAGEWTY формат можно записать через `dd`, но может не загрузиться на всех платах:
```bash
sudo dd if=PulsarOS-OPiZero3-Android12-*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### Первая загрузка

1. Вставьте SD карту в Orange Pi Zero 3
2. Подключите HDMI монитор
3. Подключите USB-C питание (5V/3A)
4. Подключите геймпад через USB или Bluetooth
5. Дождитесь анимации загрузки (~30 секунд)
6. Мастер начальной настройки запустится автоматически

### Источники

- [Инструкция по прошивке](http://nskhuman.ru/allwinner/opizero3/zero3man.php?np=15&nlang=1)
- [Документация PhoenixCard](http://nskhuman.ru/allwinner/card/phoenixcard.php)
- [Формат IMAGEWTY](http://nskhuman.ru/allwinner/firmware.php)


## 11. Разделы, которые флешер создаёт сам

Часть разделов в образе либо отсутствует, либо лежит в виде, который
устройство не принимает. Флешер создаёт их содержимое:

| Раздел | Что делает флешер | Почему |
| --- | --- | --- |
| `bootloader_a` | FAT16 32 МиБ: наш `bootlogo.bmp` + шрифты и кадры заряда из стока | сюда u-boot смотрит за логотипом; стоковый `boot-resource.fex` заявляет 128 МиБ при файле 5.6 МБ и имеет `sectors-per-track = 0`, поэтому mtools его не открывает — содержимое вытаскивает `tools/fatextract.py` |
| `boot-resource` | тот же FAT16 | часть сборок u-boot ищет раздел ровно с таким именем, а не по номеру |
| `metadata` | `mkfs.ext4` | монтируется на first_stage_mount, пустой даёт `VFS: Can't find ext4 filesystem` |
| `media_data` | `mkfs.vfat -F 32` | монтируется как `/oem`; пустой даёт `FAT-fs: invalid media value` |
| `userdata` | `mkfs.f2fs` | без него `/data` не появляется, `credstore` падает с `chdir: /data/misc/credstore: No such file or directory` |

`userdata` занимает 56 ГБ, но свежий f2fs реально содержит ~120 МБ данных.
`tools/writeimg.py` пишет только занятые экстенты (`SEEK_DATA`/`SEEK_HOLE`),
поэтому запись занимает секунды, а не час по USB 2.0.

## 12. Загрузочная анимация и логотип

* **Логотип ядра** (до Android, рисует u-boot): `vendor/pulsaros/boot-logo/bootlogo.bmp`,
  попадает в первый раздел `bootloader_a` вместе со стоковыми шрифтами
  `FONT24.SFT`/`FONT32.SFT`, `FASTBOOT.BMP`, `MAGIC.BIN` и каталогом `BAT/`
  (кадры анимации заряда). Сейчас 800×480, 24 бита.
* Раздел собирается заново на весь размер: стоковый `boot-resource.fex`
  усечён и нестандартен, поэтому содержимое вытаскивается `tools/fatextract.py`,
  а файловая система создаётся `mkfs.vfat`. После записи флешер проверяет
  `mdir ::BOOTLOGO.BMP`.
* **Загрузочная анимация** (Android): положите `bootanimation.zip` в
  `vendor/pulsaros/bootanimation/` — он заменит стоковый
  `/system/media/bootanimation.zip` при сборке образа. Кадры рендерятся как
  есть, на экране 720p анимация 800×480 будет по центру.
* **Логотип виден только если GPT корректен** — иначе u-boot затирает первый
  раздел (см. раздел про резервную копию GPT выше).
