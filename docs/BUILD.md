# PulsarOS — Сборка из исходников

## Требования к машине

| Параметр | Минимум | Рекомендуется |
|---|---|---|
| ОС | Ubuntu 20.04 LTS x86_64 | Ubuntu 22.04 LTS x86_64 |
| ОЗУ | 16 GB | 32 GB+ |
| Диск | 200 GB SSD | 500 GB NVMe |
| CPU | 4 ядра | 16+ ядер |
| Время сборки | ~8 часов | ~2 часа |

## Шаг 1 — Получение исходников Orange Pi H618 Android 12

Официальные исходники распространяются через Google Drive Orange Pi:
- **Google Drive:** https://drive.google.com/drive/folders/1acn4Oosu1s-39hCK3uRiqj9gG0Jw-tGZ

Скачай все файлы `H618-Android12-Src.tar.gz*` и `H618-Android12-Src.tar.gz.md5sum`.

```bash
# Проверь целостность
md5sum -c H618-Android12-Src.tar.gz.md5sum

# Собери архив из частей и распакуй
cat H618-Android12-Src.tar.gza* > H618-Android12-Src.tar.gz
tar -xvf H618-Android12-Src.tar.gz

# Перемести в рабочую директорию
mv H618-Android12-Src ~/android/pulsaros
```

## Шаг 2 — Установка зависимостей

```bash
git clone https://github.com/[username]/PulsarOS.git
cd PulsarOS
./scripts/setup-env.sh
source ~/.bashrc
```

Скрипт установит все необходимые пакеты, Java 11, repo tool и ccache.

> Список пакетов основан на официальной документации Orange Pi H618 Android 12.

## Шаг 3 — Сборка

### Debug сборка (SSH + ADB включены, для разработки)
```bash
./scripts/build.sh debug
```

### Release сборка (для конечных пользователей)
```bash
./scripts/build.sh release
```

### Clean + Debug
```bash
./scripts/build.sh debug clean
```

## Процесс сборки

Скрипт выполняет три шага автоматически:

**Шаг 1/3 — longan (u-boot + ядро Linux 5.4)**
```
cd H618-Android12-Src/longan
./build.sh config   # platform=android, ic=h618, board=p2, arch=arm64
./build.sh
```

**Шаг 2/3 — Android AOSP**
```
source build/envsetup.sh
lunch pulsaros_zero3-userdebug  # или -user для release
make -j$(nproc)
```

**Шаг 3/3 — pack (финальный образ)**
```
pack
# → longan/out/h618_android12_p2_uart0.img
```

Образ копируется в `out/PulsarOS-<версия>-<тип>-<дата>.img`.

## Переменные окружения

| Переменная | По умолчанию | Описание |
|---|---|---|
| `ANDROID_SRC` | `~/android/pulsaros` | Путь к исходникам Android |
| `JOBS` | `nproc - 2` | Число потоков сборки |
| `BUILD_NUMBER` | `local` | Номер сборки (CI заполняет автоматически) |

## GitHub Actions (CI)

Сборка требует **self-hosted runner** из-за размера исходников (~200+ GB).

### Настройка runner

1. Зарегистрируй runner на машине с Android исходниками:
   ```
   GitHub repo → Settings → Actions → Runners → New self-hosted runner
   ```
2. Укажи лейблы: `self-hosted`, `linux`, `android-build`
3. Убедись что Android source находится в `~/android/pulsaros`

### Запуск CI

- **Debug**: автоматически при push в `main` или `dev`
- **Release**: создай тег `v0.1.0` → автоматически создаётся GitHub Release (draft)

## Структура выходных файлов

```
out/
├── PulsarOS-0.1.0-debug-20250101-1200.img    # Финальный образ
├── PulsarOS-0.1.0-debug-20250101-1200.img.sha256
└── logs/
    └── build_debug_20250101-1200.log          # Лог сборки
```

## Возможные проблемы

### Ошибка: "Java version mismatch"
```bash
sudo update-alternatives --config java
# Выбери Java 11
```

### Ошибка: "longan build.sh: command not found"
```bash
chmod +x ~/android/pulsaros/longan/build.sh
```

### Ошибка: "lunch: command not found"
```bash
source ~/android/pulsaros/build/envsetup.sh
```

### Мало места во время сборки
Android AOSP создаёт ~100GB промежуточных файлов. Проверь:
```bash
df -h ~/android/pulsaros/out
```
