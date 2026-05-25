# PulsarOS — Запись прошивки на SD-карту

## Что нужно

- microSD карта **≥16 GB** (Class 10 / UHS-I рекомендуется)
- Компьютер с Linux или Windows
- Файл образа: `PulsarOS-x.x.x-release-XXXXXXXX.img`

## Способ 1 — Скрипт flash.sh (Linux, рекомендуется)

```bash
# Найди устройство SD-карты
lsblk

# Запиши образ (замени /dev/sdb на своё устройство)
sudo ./scripts/flash.sh out/PulsarOS-0.1.0-release-20250101.img /dev/sdb
```

Скрипт:
- Проверит SHA256 образа
- Отмонтирует все разделы устройства
- Запишет образ через `dd`
- Синхронизирует кеш

## Способ 2 — dd (Linux, вручную)

```bash
# Запись
sudo dd if=PulsarOS-0.1.0-release.img of=/dev/sdb bs=4M conv=fsync oflag=direct status=progress

# Синхронизация
sync
```

## Способ 3 — balenaEtcher (Windows / macOS / Linux GUI)

1. Скачай [balenaEtcher](https://etcher.balena.io/)
2. Flash from file → выбери `.img`
3. Select target → выбери SD-карту
4. Flash!

## Способ 4 — PhoenixCard (Windows, формат IMAGEWTY)

> Используй если стандартный dd не работает — Orange Pi использует формат IMAGEWTY

1. Скачай [PhoenixCard](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-Zero-3.html)
2. Выбери образ `.img`
3. Режим: **"Startup"** (загрузочная карта)
4. Burn

## Первый запуск

1. Вставь SD-карту в Orange Pi Zero 3
2. Подключи HDMI к монитору/телевизору
3. Подай питание (5V/3A через USB-C)
4. Запустится **PulsarOS Setup** (OOBE) — следуй инструкциям на экране

## Структура хранилища для ROMs

Создай на USB-накопителе или второй SD-карте:

```
PulsarOS/
├── roms/
│   ├── nes/
│   ├── snes/
│   ├── md/          (Mega Drive)
│   ├── gba/
│   ├── psx/
│   ├── nds/
│   ├── gbc/
│   ├── n64/
│   ├── pce/         (PC Engine)
│   └── arcade/      (MAME)
├── video/
├── audio/
└── other/
```

PulsarOS автоматически обнаружит папку `PulsarOS/` и настроит ES-DE и RetroArch.
