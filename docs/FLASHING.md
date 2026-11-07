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
| 0 | `sunxi_mbr.fex` — таблица разделов Allwinner (`softw411`) |
| 8 КиБ | `boot0_sdcard.fex` — первичный загрузчик, BROM читает отсюда |
| 128 КиБ | `boot_package.fex` — u-boot + optee + dtb |
| по MBR | boot-resource, env, boot, vendor_boot, super, misc, vbmeta*, dtbo |
| 3444 МиБ | `UDISK` — будущий `/data`, Android форматирует при первом старте |

После записи скрипт сверяет sha256 каждого записанного участка с образом.

**Единственное место, которое не выводится из образа, — смещение
`boot_package`.** В `boot0` есть таблица имён (`u-boot`, `optee`, `monitor`,
`scp`, `dtb`, `dtbo`, `logo`), то есть он парсит именно `boot_package`, но
самого смещения в файлах нет. По умолчанию 128 КиБ; если плата не
загружается, попробуйте другое:

```bash
sudo scripts/flash-linux.sh out/PulsarOS-*.img /dev/sdX --uboot-offset=1048576
```

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
