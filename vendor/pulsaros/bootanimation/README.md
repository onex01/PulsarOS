# Загрузочная анимация

Положите сюда `bootanimation.zip` — он заменит стоковый
`/system/media/bootanimation.zip` при сборке образа.

Формат архива — стандартный Android: `desc.txt` плюс каталоги `part0/`,
`part1/`… с PNG-кадрами.

```
bootanimation.zip
├── desc.txt          # "1080 1920 30" + "p 1 0 part0"
├── part0/
│   └── 0001.png …
└── part1/
```

Первая строка `desc.txt` — ширина, высота и fps. Кадры должны быть того же
разрешения, что и экран (для этой платы 1920x1080), иначе Android растянет
их сам.

Логотип ядра (`bootlogo.bmp`) — отдельный файл: он лежит в
`vendor/pulsaros/boot-logo/bootlogo.bmp` и попадает в раздел `boot-resource`,
который показывает u-boot до старта Android. Требования: BMP, 24 бита, без
сжатия; сейчас 800x480.
