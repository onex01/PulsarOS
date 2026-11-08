# PulsarOS — Обновлённый контекст проекта

> **Версия**: 0.2.0-dev
> **Обновлено**: 2026-07-14

> **ВНИМАНИЕ: файл устарел как описание текущего пайплайна.**
>
> С 2026-11-07 образ собирается **без imgRePacker и без сборки BSP**: наши
> собственные инструменты (`tools/imagewty.py`, `lpunpack.py`, `lpmake.py`,
> `mkgpt.py`) разбирают стоковый образ, заменяют `super` и загрузочные
> ресурсы, и собирают IMAGEWTY обратно. Актуальное состояние —
> `docs/STATUS.md`, пайплайн — `README.md` и `docs/BUILD.md`, раскладка
> карты — `docs/FLASHING.md`.
>
> Ниже сохранено как история: как проект шёл от imgRePacker к своим
> инструментам.

---

## Что изменилось

### imgRePacker найден и работает
- **Путь**: `tools/bin/imgrepacker` (Linux), `tools/bin/imgRePacker.exe` (Windows)
- **Версия**: 2.0.7.8 (RedScorpio)
- **Работает в WSL2** ✓
- **Решает проблему IMAGEWTY**: `subversion = 0x60` для PhoenixCard

### Pipeline работает
```
imgRePacker (unpack) → modify .fex files → imgRePacker (repack) → PhoenixCard
```

### Ключевая находка: StartUp vs Product
- Оригинальный образ загружается **только в StartUp** режиме
- Product режим не работает (особенность доски H618)

---

## Быстрый старт

### Пересборка IMAGEWTY
```bash
# 1. Распаковать
./tools/bin/imgrepacker original.img
# → original.img.dump/

# 2. Модифицировать
cp modified_super.fex original.img.dump/super.fex

# 3. Запаковать
./tools/bin/imgrepacker original.img.dump
# → original.img (IMAGEWTY с subversion=0x60)

# 4. Прошить через PhoenixCard (StartUp!)
```

### Сборка Android (требует native Linux)
```bash
cd /path/to/android/source
source build/envsetup.sh
lunch apollo_p2-userdebug
make -j8
cd longan/build && ./pack -i h618 -c sun50iw9p1 -p android -b p2 -d uart0
```

---

## Текущие файлы

| Файл | Описание |
|------|----------|
| `docs/SESSION-HANDOFF.md` | Полная документация сессии |
| `docs/IMGREPACKER.md` | Документация по imgRePacker |
| `docs/IMAGE-FORMAT.md` | Спецификация IMAGEWTY |
| `tools/bin/imgrepacker` | Linux бинарник |
| `tools/bin/imgRePacker.exe` | Windows бинарник |

---

*Обновлено: 2026-07-14*
