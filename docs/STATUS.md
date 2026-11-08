# PulsarOS — состояние на 2026-11-08

Короткий срез: что проверено на железе, где известные баги и с чего продолжать.
Всё, что ниже, проверялось командами на Orange Pi Zero 3, а не выведено из кода.

## 1. Что работает

### Загрузка и система

- Цепочка: `boot0` (сектор 16) → `boot_package` (сектор 32800) → OP-TEE →
  u-boot 2018.07 → GPT → ядро → Android 12.
- Карта грузится с GPT из 26 разделов, `super` — 3 ГиБ, внутри свободно ~535 МБ.
- `/data` монтируется как f2fs на 56 ГБ, `credstore` не падает.
- Wi-Fi: `wlan0`, драйвер `sprdwl_ng`, ADB по TCP `192.168.1.162:5555`,
  `adb root` работает (сборка `userdebug`).
- `/system` перемонтируется в rw — dm-verity не включена, правки переживают
  перезагрузку.

### Приложения

Установлены в `/system` и проверены запуском:

| Пакет | Версия | Что проверено |
| --- | --- | --- |
| `com.retroarch.ra32` | 1.22.2 | стартует, `MainMenuActivity` в фокусе, переживает ребут |
| `com.magneticchen.daijishou` | 1.5.0 | установлен, не выбран домашним |
| `org.ppsspp.ppsspp` | 1.20.4 | стартует, проходит приветствие, видит SAF-дерево |
| `com.github.stenzek.duckstation` | build 12010 | `MainActivity` в фокусе |
| `org.mupen64plusae.v3.alpha` | 3.0.246 | стартует, спрашивает разрешения |
| `org.videolan.vlc` | 3.7.1 | `OnboardingActivity` |
| `com.phlox.tvwebbrowser` | 2.1.6 | открывается, рисует страницы |
| `org.primftpd` | 8.2 | установлен |
| `com.android.documentsui` | 12 (LineageOS 19.1) | `MANAGE_DOCUMENTS granted=true`, диалог открывается |

Все нативные библиотеки — 32-битные ARM, распакованы в
`/system/app/<Dir>/lib/arm/`. Без этого системный APK падает с
`dlopen failed: library ... not found`.

### Debloat

Удалено 17 стоковых пакетов: `Test_AD`, `wiringop`, `AwlogSettings`,
`DragonAgingTV`, `DragonAtt`, `DragonBox`, `EasterEgg`, `TimerSwitch`,
`Update`, `WebScreensaver`, `WallpaperBackup`, `ImageParser`, `Traceur`
(в `app` и `priv-app`), `BasicDreams`, `LiveWallpapersPicker`,
`ExactCalculator`, `SoundRecorder`, плюс `Camera2`, `Calendar`, `DeskClock`,
`PhotoTable`, `Browser2` из `/product/app`.

### Геймпады

`Vendor_057e_Product_2009.kl` переписана по фактическим кодам `getevent`:

```
A 0x130  B 0x131  X 0x132  Y 0x133  L 0x134  R 0x135
ZL 0x136 ZR 0x137 Minus 0x138 Plus 0x139 L3 0x13a R3 0x13b
Home 0x13c Capture 0x13d; D-pad — ABS_HAT0X/0Y
```

Стоковая раскладка не описывала `0x132` вообще, поэтому X превращался в
`AKEYCODE_UNKNOWN` и молча терялся всеми приложениями.

## 2. Известные проблемы

### 2.1 Логотип ядра не показывается

Причина найдена арифметически: резервная копия GPT писалась так, что её
записи выходили за конец карты.

```
было:   alt_lba = 123 473 919 (последний сектор), entries_lba = 123 473 887
        last_usable = 123 473 912, first_usable = 8
лог:    MMC: block number 0x75c1007 exceeds max(0x75c1000) → update gpt fail
```

После провала u-boot «чинит» таблицу и пишет её в первый раздел, уничтожая
FAT с `bootlogo.bmp` до того, как `boot_gui_init` успеет его прочитать.

Исправлено в `tools/mkgpt.py`: `last_usable = last_lba - 33`, резервные записи
на `диск - 33`, заголовок в последнем секторе, `first_usable` считается через
`ceil`. Первый раздел теперь собирается заново как FAT16 с нашим
`bootlogo.bmp` (`tools/fatextract.py` вытаскивает шрифты и кадры заряда из
стокового образа — mtools его не открывает).

**Статус:** образ собран, на карте проверена геометрия GPT и содержимое
раздела. Загрузку с этим образом на плате ещё не подтверждали.

### 2.2 PPSSPP и файловый диалог

В стоковой прошивке **нет `com.android.documentsui`** — от него остались только
упоминания в `framework.jar` и `framework-res.apk`. Любое приложение с
Storage Access Framework падало с
`No Activity found to handle Intent { act=android.intent.action.OPEN_DOCUMENT }`.

Добавлено в `/system/priv-app` вместе с allowlist-ом
(`/system/etc/permissions/com.android.documentsui.xml`): на этой прошивке
`ro.control_privapp_permissions=enforce`, и priv-app без allowlist валит
system_server на старте.

`MANAGE_DOCUMENTS` имеет `protectionLevel=signature|documenter` и выдаётся
единственному системному пакету, который обрабатывает `OPEN_DOCUMENT`.
Поэтому **Material Files пришлось убрать**: он тоже объявляет этот intent, и
при двух системных обработчиках грант не доставался никому.

**Статус:** проверено на живой системе — диалог открывается, папка выбирается,
PPSSPP получает SAF-дерево. В образе исправление есть.

### 2.3 Экран 720p, а не 1080p

```
Physical size: 1280x720   Physical density: 160
supportedModes [{id=1, width=1280, height=720, fps=60}]
```

Других режимов нет. В логе ядра `ERROR: pinctrl_get for HDMI2.0 DDC fail` —
EDID не читается, драйвер берёт дефолтный режим. «1080» на телевизоре — это его
собственный скейлер.

### 2.4 Мелочи

- Домашним лончером остаётся `TvLauncher`; Daijishou не выбран.
- 30 ядер лежат в `/system/etc/pulsaros/cores`, но в `/data` не засеяны.
- `Run-as-root` файловый менеджер убран вместе с Material Files; файлы
  доступны через DocumentsUI и FTP.

## 3. Как снимать состояние с платы

```bash
scripts/pulsaros-diag.sh overview    # экран, GLES, пакеты, их .so, место
scripts/pulsaros-diag.sh ppsspp      # запуск + crash/main logcat
scripts/pulsaros-diag.sh app <pkg>   # то же для любого пакета
```

Скрипт работает по `adb` через `PULSAR_HOST` (по умолчанию
`192.168.1.162:5555`).

## 4. Следующие шаги

1. Прошить образ с исправленным GPT и подтвердить логотип ядра.
2. Переключить домашний лончер на Daijishou.
3. Засеять ядра в `/data` RetroArch (сейчас только `system/etc`).
4. Разобраться с 720p: попробовать принудительный режим через disp-параметры
   u-boot или починить DDC в device tree.
5. OOBE: язык, лицензия, сеть, визард геймпада.
6. Внешние носители: дерево `PulsarOS/{game,video,music}` и автоскан.
7. Заменить FTP веб-сервером (или добавить его рядом).

## 5. Что нельзя публиковать

- Стоковый образ Orange Pi и `work/` — не в git (см. `.gitignore`).
- `prebuilt/apk/*.apk` и `prebuilt/cores/*.so` — тоже, их тянет
  `scripts/fetch-apps.sh` из официальных источников с проверкой SHA256.
- DuckStation — CC BY-NC-ND 4.0: в коммерческую сборку класть нельзя.
