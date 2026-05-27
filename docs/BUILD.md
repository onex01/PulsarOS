# Сборка PulsarOS

## Требования

- Ubuntu 20.04/22.04 (x86_64)
- 32+ GB RAM (64 рекомендуется)
- 300+ GB свободного места на SSD
- 8+ ядер CPU

## Шаги

### 1. Подготовка окружения
\`\`\`bash
./scripts/setup-env.sh
source ~/.bashrc
\`\`\`

### 2. Получение исходников Orange Pi
Скачайте Android 12 BSP с официального Google Drive:
https://drive.google.com/drive/folders/1acn4Oosu1s-39hCK3uRiqj9gG0Jw-tGZ

Распакуйте в `~/android12`.

### 3. Клонирование PulsarOS
\`\`\`bash
git clone --recursive https://github.com/onex01/PulsarOS
cd PulsarOS
\`\`\`

### 4. Сборка
\`\`\`bash
export ANDROID_SRC=~/android12
./scripts/build.sh sync
./scripts/build.sh build userdebug   # debug
./scripts/build.sh build user        # release
\`\`\`

### 5. Прошивка
\`\`\`bash
./scripts/flash.sh $ANDROID_SRC/out/target/product/zero3/pulsaros.img /dev/sdX
\`\`\`