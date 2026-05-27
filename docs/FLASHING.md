# Прошивка PulsarOS на SD-карту

## Что нужно
- microSD 16GB+ (рекомендуется 32GB, A2-класс)
- USB-картридер
- Linux-машина

## Процесс
\`\`\`bash
# Определить устройство (ВНИМАТЕЛЬНО!)
lsblk
# Например /dev/sdc

# Записать
sudo ./scripts/flash.sh pulsaros-1.0.0-alpha1.img /dev/sdc
\`\`\`

## Первый запуск
1. Вставить SD в Orange Pi Zero 3
2. Подключить HDMI + питание
3. Пройти OOBE (PulsarOS Setup)