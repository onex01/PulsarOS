# PulsarOS — Совместимое железо

## Orange Pi Zero 3 — конфигурации

| Вариант | RAM | Примечание |
|---|---|---|
| Zero 3 1GB | 1 GB LPDDR4 | Включается ZRAM, ограниченный N64/NDS |
| Zero 3 1.5GB | 1.5 GB LPDDR4 | Рекомендуемый минимум |
| Zero 3 2GB | 2 GB LPDDR4 | Оптимальный вариант |
| Zero 3 4GB | 4 GB LPDDR4 | Максимальная производительность |

## Геймпады

| Геймпад | Подключение | Статус |
|---|---|---|
| Xbox Series X/S | Bluetooth / USB | ✅ Нативная поддержка Android |
| Xbox One S/X | Bluetooth / USB | ✅ Нативная поддержка Android |
| PlayStation DualSense (PS5) | Bluetooth / USB | ✅ Нативная поддержка Android |
| PlayStation DualShock 4 (PS4) | Bluetooth / USB | ✅ Нативная поддержка Android |
| Nintendo Switch Pro Controller | Bluetooth / USB | ✅ Нативная поддержка Android |
| 8BitDo (любая модель) | Bluetooth / USB | ✅ Нативная поддержка Android |
| Generic USB HID | USB | ✅ Нативная поддержка Android |
| Generic Bluetooth HID | Bluetooth | ⚠️ Зависит от профиля устройства |

> Android содержит встроенные профили для Xbox, PlayStation и Nintendo геймпадов.
> При первом подключении OOBE поможет настроить геймпад.

## USB-хабы

Orange Pi Zero 3 имеет 1× USB 2.0 (Type-A). Для подключения геймпада + накопителя нужен хаб.

Рекомендуемые:
- Любой USB 2.0 хаб с внешним питанием (геймпад через Bluetooth, хаб для накопителя)
- Расширительная плата Orange Pi Zero 3 добавляет ещё 2× USB 2.0

## microSD карты

| Класс | Статус | Примечание |
|---|---|---|
| Class 10 / UHS-I A1 | ✅ Минимум | Рекомендуется для системы |
| UHS-I A2 | ✅ Рекомендуется | Быстрый запуск игр |
| UHS-I A1 128GB+ | ✅ Отлично | Система + игры на одной карте |

## Мониторы и телевизоры

Подключение через **micro-HDMI** (Zero 3) → HDMI (монитор/TV).

Поддерживаемые режимы (зависит от монитора):
- 720p @ 60Hz
- 1080p @ 60Hz
- 1080p @ 120Hz
- 4K @ 30Hz
- 4K @ 60Hz

> OOBE автоматически определяет поддерживаемые режимы и предлагает выбор.
