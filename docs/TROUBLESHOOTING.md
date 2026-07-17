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
