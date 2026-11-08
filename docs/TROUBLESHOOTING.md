# Troubleshooting / Решение проблем

> [English](#english) | [Русский](#русский)

---

## English

### Build Issues

#### longan build hangs on "build for sun50iw9p1_android11_defconfig"
GNU Make 4.4+ (Debian 13) is incompatible with Allwinner BSP — recursive variable exports cause infinite loops.
```bash
# Fix: Install Make 4.3 via build script
bash scripts/build.sh  # → s) Setup System
# Or manually:
curl -sL https://ftp.gnu.org/gnu/make/make-4.3.tar.gz | tar xzf - -C /tmp/
cd /tmp/make-4.3 && ./configure --prefix=/usr/local && make -j$(nproc) && sudo make install
hash -r  # Reset shell hash
make --version  # Should show 4.3
```

#### `buildserver` not running / make hangs
The Allwinner `buildserver` daemon may not start on modern systems.
- The build script patches `prepare_buildserver()` to a no-op automatically
- If build still hangs, check if make is version 4.3 (see above)

#### `spl/Makefile: No such file or directory`
BSP has `spl-pub/` instead of `spl/`. The build script creates a symlink automatically.
```bash
cd /path/to/H618-Android12-Src/longan/brandy/brandy-2.0
ln -s spl-pub spl
```

#### `CONF_ANDROID_MAJOR_VER` redefinition
```bash
# Fix: Run the macro fix script
bash scripts/fix-libcedarx-macros.sh
```

#### `spl/Makefile: No such file or directory`
The longan build expects `brandy/brandy-2.0/spl/` but some BSP versions have `spl-pub/` instead.
```bash
# Fix: Create symlink (handled automatically by build script)
cd /path/to/H618-Android12-Src/longan/brandy/brandy-2.0
ln -s spl-pub spl
```

#### `pack` fails with error 400
The longan `pack` tool may fail due to missing dependencies or incorrect board config.
- Check `longan/build.log` for details
- Ensure longan build completed successfully first
- Fallback: dd-concatenation is used automatically

#### `set -u: unbound variable`
The build system uses `set -u`. Some Android scripts reference unset variables.
- The build script runs with `set +u` when sourcing `envsetup.sh`

#### NDK not found
```bash
# Ensure ANDROID_NDK_HOME is set
echo $ANDROID_NDK_HOME
# Should point to: ~/Android/Sdk/ndk/27.0.12077973

# Install via build script:
bash scripts/build.sh  # → 8) Setup System
```

#### GitHub API rate limit (APK download fails)
The build script uses fallback URLs if GitHub API is rate-limited. Manual download:
- Daijishou: https://github.com/TapiocaFox/Daijishou/releases
- TV Bro: https://github.com/truefedex/tv-bro/releases

### Boot Issues

#### No display output
- Check HDMI cable and monitor
- Ensure 5V/3A power supply (undervoltage causes boot failure)
- Check `bootlogo.bmp` format: must be 800x480 BMP

#### Boot loop
- Re-flash SD card
- Check SD card health (try different card)
- Verify image was written correctly: `cmp out/pulsaros.img /dev/sdX`

#### Gamepad not detected
- PulsarSetup wizard auto-detects USB gamepads
- Supported: Nintendo, Sony, Xbox, 8BitDo, GameSir, Razer, SteelSeries (35+ models)
- Try different USB port

### Runtime Issues

#### SSH access
```bash
# Default: port 2222, dropbear SSH
ssh -p 2222 root@<device-ip>

# Toggle SSH:
bash /system/etc/pulsaros/scripts/ssh-toggle.sh start
```

#### Storage not mounted
The `storage-watcher.sh` auto-creates PulsarOS directories on new storage. Check:
```bash
# Via SSH
ls /storage/*/PulsarOS/
```

#### WiFi not connecting
- Use PulsarSetup wizard (runs on first boot)
- Or configure via Android Settings

---

## Русский

### Проблемы сборки

#### Ошибка `CONF_ANDROID_MAJOR_VER`
```bash
bash scripts/fix-libcedarx-macros.sh
```

#### `pack` падает с ошибкой 400
- Проверить `longan/build.log`
- Убедиться что longan собран успешно
- Автоматически используется dd-concat как запасной вариант

#### NDK не найден
```bash
bash scripts/build.sh  # → 8) Подготовка системы
```

### Проблемы загрузки

#### Нет изображения
- Проверить HDMI кабель и монитор
- Использовать блок питания 5V/3A
- Проверить `bootlogo.bmp`: 800x480 BMP

#### Зацикливание загрузки
- Перепрошить SD карту
- Проверить здоровье SD карты

#### Геймпад не определяется
- Подключить через USB до загрузки
- Поддерживается 35+ моделей

### Проблемы во время работы

#### SSH доступ
```bash
ssh -p 2222 root@<ip-адрес>
```

#### WiFi не подключается
- Использовать мастер PulsarSetup
- Настроить через Android Settings

---

## Русский — случаи из этой прошивки

Ниже не гипотезы, а то, что реально встретилось на Orange Pi Zero 3, с точной
причиной и проверенным лечением.

### RetroArch падает: `dlopen failed: library "libretroarch-activity.so" not found`

Системному APK Android **не распаковывает** нативные библиотеки в `/data`.
Если рядом с APK нет `lib/arm`, загрузчику неоткуда взять `.so`.

Лечение — распаковать `lib/armeabi-v7a/*.so` из APK в
`/system/app/RetroArch/lib/arm/` (`chmod 755`). `build-image.sh` делает это
для всех предустановленных приложений автоматически.

### PPSSPP «не открывается», в логе `No Activity found to handle OPEN_DOCUMENT`

В стоковой прошивке нет `com.android.documentsui` — системного файлового
диалога. PPSSPP на первом запуске просит выбрать папку для данных и падает.

Лечение: положить DocumentsUI в `/system/priv-app/DocumentsUI/` **и** его
allowlist в `/system/etc/permissions/com.android.documentsui.xml`. На этой
прошивке `ro.control_privapp_permissions=enforce`, поэтому priv-app без
allowlist валит system_server на старте.

Дополнительно: `MANAGE_DOCUMENTS` выдаётся только **одному** системному
пакету, который обрабатывает `OPEN_DOCUMENT`. Если в `/system` есть второй
такой (например, Material Files), грант не достаётся никому и DocumentsUI
падает с `Permission Denial: opening provider ... ExternalStorageProvider`.
Второй пакет надо убрать из `/system`.

### `getevent` видит кнопку, а RetroArch её не замечает

RetroArch в Android не имеет таблицы keycode→кнопка: Android-драйвер пишет
сырой keycode в битовую маску, а бинды задаёт профиль «Android Gamepad». Коды
`98 (BUTTON_C)` и `101 (BUTTON_Z)` в нём не назначены ни на что и
**игнорируются молча**.

Проверять так:

```bash
adb shell getevent -t /dev/input/eventN   # нажимать по одной кнопке
adb shell cat /system/usr/keylayout/Vendor_XXXX_Product_YYYY.kl
```

Если кода нет в раскладке, Android отдаёт `AKEYCODE_UNKNOWN`. У Switch Pro
Controller (057e:2009) так терялась кнопка X (`0x132`).

### Экран 1280×720 вместо 1080p

```
ERROR: pinctrl_get for HDMI2.0 DDC fail
```

EDID не читается, драйвер берёт дефолтный режим. `wm size` и `dumpsys display`
показывают единственный режим 1280×720 — «1080» даёт скейлер телевизора.

### Логотип ядра не появляется, в логе `update gpt fail`

u-boot не нашёл резервную копию GPT там, где ждал, и перезаписал первый раздел
вместе с FAT и `bootlogo.bmp`. Причина — неверная геометрия резервной копии в
`tools/mkgpt.py`; подробности и правильные числа — в `FLASHING.md`,
раздел про резервную копию GPT.

### Сборка падает с `write error (disk full?)` на `libxul.so`

В стейджинге остались каталоги приложений, которые больше не ставятся
(например, Fennec после замены на TV Bro). `inject_apk` чистит только то, что
есть в `SYSTEM_APPS`. Лечение: `OBSOLETE_APPS` в `build-image.sh` и
`rm -rf` целевого каталога перед установкой — уже сделано.

### `mount: ... is already mounted` при повторной сборке

Прошлая сборка упала и оставила loop-монтирование. Размонтировать:

```bash
sudo umount work/build/mnt-system_a work/build/mnt-product_a
```
