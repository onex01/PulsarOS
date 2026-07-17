# Build Instructions / Инструкция по сборке

> [English](#english) | [Русский](#русский)

---

## English

### System Requirements

- **OS**: Ubuntu 22.04 LTS (x86_64) — recommended by Allwinner
- **RAM**: 16 GB minimum, 32 GB recommended
- **Storage**: 300 GB SSD (source tree ~100 GB, build output ~80 GB)
- **CPU**: Multi-core x86_64 (build uses `nproc` parallel jobs)
- **Internet**: Required for initial download (~5 GB)

### Quick Start (Modular Script)

```bash
# 1. Clone PulsarOS
git clone https://github.com/one/PulsarOS.git
cd PulsarOS

# 2. Run the build system
bash scripts/build.sh

# 3. Select "1) Auto Build" — follows all steps automatically
```

### Step-by-Step Build

#### 1. Install Build Dependencies

```bash
sudo apt-get update
sudo apt-get install -y git gnupg flex bison gperf build-essential \
    zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
    lib32ncurses-dev x11proto-core-dev libx11-dev lib32z1-dev ccache \
    libgl1-mesa-dev libxml2-utils xsltproc unzip u-boot-tools \
    python3 python-is-python3 libssl-dev libncurses-dev clang gawk imagemagick
```

Or use the script: `bash scripts/build.sh` → select **8) Setup System**

#### 2. Prepare Android Source Tree

Download from Allwinner SDK (Baidu/Google Drive):
```bash
# Verify MD5
md5sum -c H618-Android12-Src.tar.gz.md5sum

# Extract
cat H618-Android12-Src.tar.gza* > H618-Android12-Src.tar.gz
tar -xvf H618-Android12-Src.tar.gz
```

**Reference**: http://nskhuman.ru/allwinner/opizero3/zero3man.php?nglav=6&nlang=1

#### 3. Build longan (Kernel + Bootloader)

```bash
cd H618-Android12-Src/longan
./build.sh config
# Select: android, h618, p2, default, linux-5.4, arm64
./build.sh
```

#### 4. Build Android

```bash
cd H618-Android12-Src
source build/envsetup.sh
lunch apollo_p2-userdebug
make -j$(nproc)
pack
```

Output: `longan/out/h618_android12_p2_uart0.img`

#### 5. Apply PulsarOS Overlays

The build script handles this automatically via `sync_and_backup.sh`:
- Syncs `device/softwinner/zero3/` into Android source
- Syncs `vendor/pulsaros/` into Android source
- Syncs `packages/apps/PulsarSetup/` into Android source
- Creates timestamped backups for rollback

#### 6. Create Firmware Image

```bash
# Using the modular build system:
bash scripts/build.sh  # → 6) Create Image
```

The `pack` tool creates proper IMAGEWTY format. See [IMAGE-FORMAT.md](IMAGE-FORMAT.md).

#### 7. Flash to SD Card

```bash
# Using the build system:
bash scripts/build.sh  # → 7) Flash to SD

# Or manually:
sudo dd if=out/pulsaros.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### Modular Build Script Structure

```
scripts/
├── build.sh                    # Entry point (menu + auto-build)
├── lib/common.sh               # Colors, logging, helpers
├── lib/config.sh               # Configuration management
└── steps/                      # One file per build step
    ├── 00-setup-system.sh
    ├── 01-configure.sh
    ├── 02-download-apks.sh
    ├── 03-build-cores.sh
    ├── 04b-build-longan.sh
    ├── 05-build-android.sh
    ├── 06-create-image.sh
    ├── 07-flash.sh
    ├── 08-install-logo.sh
    ├── 09-clean.sh
    └── 10-view-log.sh
```

Each step is independently testable:
```bash
source scripts/lib/common.sh
source scripts/lib/config.sh
source scripts/steps/03-build-cores.sh
step_build_cores  # Run just this step
```

### Build Logs

All build output is logged to `out/logs/build_YYYYMMDD_HHMMSS.log` with a symlink at `out/logs/latest.log`.

View logs via the menu: **l) View Build Log**

---

## Русский

### Требования к системе

- **ОС**: Ubuntu 22.04 LTS (x86_64) — рекомендовано Allwinner
- **ОЗУ**: 16 GB минимум, 32 GB рекомендуется
- **Диск**: 300 GB SSD (исходники ~100 GB, сборка ~80 GB)
- **CPU**: Многоядерный x86_64
- **Интернет**: Нужен для начальной загрузки (~5 GB)

### Быстрый старт

```bash
# 1. Клонировать PulsarOS
git clone https://github.com/one/PulsarOS.git
cd PulsarOS

# 2. Запустить систему сборки
bash scripts/build.sh

# 3. Выбрать "1) Автосборка"
```

### Пошаговая сборка

#### 1. Установить зависимости

```bash
sudo apt-get update
sudo apt-get install -y git gnupg flex bison gperf build-essential \
    zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
    lib32ncurses-dev x11proto-core-dev libx11-dev lib32z1-dev ccache \
    libgl1-mesa-dev libxml2-utils xsltproc unzip u-boot-tools \
    python3 python-is-python3 libssl-dev libncurses-dev clang gawk imagemagick
```

Или через скрипт: `bash scripts/build.sh` → пункт **8) Подготовка системы**

#### 2. Подготовить исходники Android

Скачать из SDK Allwinner (Baidu/Google Drive):
```bash
md5sum -c H618-Android12-Src.tar.gz.md5sum
cat H618-Android12-Src.tar.gza* > H618-Android12-Src.tar.gz
tar -xvf H618-Android12-Src.tar.gz
```

**Источник**: http://nskhuman.ru/allwinner/opizero3/zero3man.php?nglav=6&nlang=1

#### 3. Собрать longan (ядро + загрузчик)

```bash
cd H618-Android12-Src/longan
./build.sh config
# Выбрать: android, h618, p2, default, linux-5.4, arm64
./build.sh
```

#### 4. Собрать Android

```bash
cd H618-Android12-Src
source build/envsetup.sh
lunch apollo_p2-userdebug
make -j$(nproc)
pack
```

Результат: `longan/out/h618_android12_p2_uart0.img`

#### 5. Применить оверлеи PulsarOS

Скрипт сборки делает это автоматически через `sync_and_backup.sh`.

#### 6. Создать образ прошивки

```bash
bash scripts/build.sh  # → 6) Создать образ
```

Используется `pack` для создания формата IMAGEWTY. См. [IMAGE-FORMAT.md](IMAGE-FORMAT.md).

#### 7. Прошить на SD карту

```bash
bash scripts/build.sh  # → 7) Прошить на SD
```

### Логи сборки

Весь вывод записывается в `out/logs/build_YYYYMMDD_HHMMSS.log`, симлинк: `out/logs/latest.log`.

Просмотр через меню: **l) Лог сборки**
