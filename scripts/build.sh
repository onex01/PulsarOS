#!/usr/bin/env bash
# =============================================================================
# PulsarOS — Build Script
# Основан на официальной инструкции Orange Pi H618 Android 12
#
# Использование:
#   ./scripts/build.sh debug          — debug сборка (SSH + ADB включены)
#   ./scripts/build.sh release        — release сборка
#   ./scripts/build.sh debug clean    — clean + debug сборка
#
# Переменные окружения:
#   ANDROID_SRC   — путь к исходникам Android (по умолчанию ~/android/pulsaros)
#   JOBS          — количество потоков сборки (по умолчанию nproc-2)
# =============================================================================

set -euo pipefail

# ── Цвета ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[PulsarOS]${NC} $*"; }
success() { echo -e "${GREEN}[PulsarOS]${NC} ✓ $*"; }
warn()    { echo -e "${YELLOW}[PulsarOS]${NC} ⚠ $*"; }
die()     { echo -e "${RED}[PulsarOS]${NC} ✗ $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }

# ── Конфигурация ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

BUILD_TYPE="${1:-debug}"
DO_CLEAN="${2:-}"

ANDROID_SRC="${ANDROID_SRC:-$HOME/android/pulsaros}"
VERSION="$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo "0.1.0-dev")"
BUILD_DATE="$(date +%Y%m%d-%H%M)"
BUILD_NUMBER="${BUILD_NUMBER:-local}"

# Наш product lunch target
# Базируется на apollo_p2 (Orange Pi Zero 3 = H618, board p2)
PRODUCT_LUNCH="pulsaros_zero3"

# Финальный образ Orange Pi кладёт сюда
OPI_IMG="$ANDROID_SRC/longan/out/h618_android12_p2_uart0.img"

OUTPUT_DIR="$REPO_ROOT/out"

# ── Баннер ───────────────────────────────────────────────────────────────────
print_banner() {
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ██████  ██    ██ ██      ███████  █████  ██████   ██████  ███████
  ██   ██ ██    ██ ██      ██      ██   ██ ██   ██ ██    ██ ██
  ██████  ██    ██ ██      ███████ ███████ ██████  ██    ██ ███████
  ██      ██    ██ ██           ██ ██   ██ ██   ██ ██    ██      ██
  ██       ██████  ███████ ███████ ██   ██ ██   ██  ██████  ███████
EOF
echo -e "${NC}"
    echo -e "  Version  : ${BOLD}$VERSION${NC}"
    echo -e "  Build    : ${BOLD}$BUILD_TYPE${NC}  |  Date: $BUILD_DATE  |  #$BUILD_NUMBER"
    echo -e "  Source   : $ANDROID_SRC"
    echo -e "  Output   : $OUTPUT_DIR"
    echo ""
}

# ── Проверка аргументов ───────────────────────────────────────────────────────
check_args() {
    case "$BUILD_TYPE" in
        debug|release) ;;
        *) die "Неизвестный тип сборки: '$BUILD_TYPE'. Используй: debug или release" ;;
    esac
}

# ── Предварительные проверки ──────────────────────────────────────────────────
preflight() {
    step "Preflight checks"

    # ОС
    if ! grep -qE "Ubuntu (20|22)\.04" /etc/os-release 2>/dev/null; then
        warn "Рекомендуется Ubuntu 20.04 или 22.04. Продолжаем..."
    fi
    [[ "$(uname -m)" == "x86_64" ]] || die "Требуется x86_64. Текущий: $(uname -m)"

    # Исходники Android
    [[ -d "$ANDROID_SRC" ]] || die \
        "Исходники Android не найдены: '$ANDROID_SRC'\n" \
        "  Запусти сначала: ./scripts/setup-env.sh\n" \
        "  Или укажи путь: ANDROID_SRC=/путь/к/исходникам ./scripts/build.sh"

    [[ -f "$ANDROID_SRC/build/envsetup.sh" ]] || die \
        "Некорректное дерево исходников Android: отсутствует build/envsetup.sh"

    [[ -d "$ANDROID_SRC/longan" ]] || die \
        "Отсутствует директория longan (u-boot + kernel). Проверь целостность исходников."

    # Java
    if ! java -version 2>&1 | grep -qE '"(11|17)'; then
        die "Требуется Java 11 или 17.\nУстанови: sudo apt install openjdk-11-jdk"
    fi

    # RAM
    local ram_gb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
    (( ram_gb >= 16 )) || warn "Мало ОЗУ: ${ram_gb}GB. Рекомендуется 32GB+."

    # Диск
    local free_gb=$(df -BG "$ANDROID_SRC" | tail -1 | awk '{print $4}' | tr -d 'G')
    (( free_gb >= 50 )) || warn "Мало места: ${free_gb}GB свободно. Может не хватить."

    success "Preflight пройден"
}

# ── Синхронизация PulsarOS оверлеев в дерево исходников ──────────────────────
sync_overlays() {
    step "Sync PulsarOS overlays"

    # device tree
    local dev_dst="$ANDROID_SRC/device/orangepi/zero3"
    mkdir -p "$(dirname "$dev_dst")"
    rsync -a --delete "$REPO_ROOT/device/orangepi/zero3/" "$dev_dst/"
    success "device/orangepi/zero3 → $dev_dst"

    # vendor overlay
    local ven_dst="$ANDROID_SRC/vendor/pulsaros"
    rsync -a --delete "$REPO_ROOT/vendor/pulsaros/" "$ven_dst/"
    success "vendor/pulsaros → $ven_dst"

    # PulsarSetup OOBE
    local pkg_dst="$ANDROID_SRC/packages/apps/PulsarSetup"
    mkdir -p "$(dirname "$pkg_dst")"
    rsync -a --delete "$REPO_ROOT/packages/apps/PulsarSetup/" "$pkg_dst/"
    success "packages/apps/PulsarSetup → $pkg_dst"

    success "Оверлеи синхронизированы"
}

# ── Шаг 1: Сборка longan (u-boot + kernel) ───────────────────────────────────
build_longan() {
    step "Step 1 / 3 — Build longan (u-boot + kernel)"
    cd "$ANDROID_SRC/longan"

    # Конфигурируем если нет .config
    # Параметры для Zero 3: platform=android, ic=h618, board=p2,
    #   flash=default, kern_ver=linux-5.4, arch=arm64
    if [[ ! -f "out/kernel/build/.config" ]]; then
        info "Конфигурирую longan (android / h618 / p2 / default / linux-5.4 / arm64)..."
        # Подаём ответы автоматически
        printf "0\n0\n2\n0\n0\n1\n" | ./build.sh config
        success "longan сконфигурирован"
    else
        info "longan уже сконфигурирован, пропускаем config"
    fi

    info "Собираю u-boot и kernel..."
    ./build.sh || die "Сборка longan упала. Проверь логи выше."
    success "longan собран"

    cd "$ANDROID_SRC"
}

# ── Шаг 2: Сборка Android ────────────────────────────────────────────────────
build_android() {
    step "Step 2 / 3 — Build Android"
    cd "$ANDROID_SRC"

    # shellcheck disable=SC1091
    source build/envsetup.sh

    # Выбор варианта сборки
    local VARIANT
    if [[ "$BUILD_TYPE" == "debug" ]]; then
        VARIANT="userdebug"
        export PULSAROS_BUILD_TYPE="debug"
        export PULSAROS_SSH_ENABLED="true"
        export PULSAROS_ADB_ENABLED="true"
        export PULSAROS_WATERMARK="true"
    else
        VARIANT="user"
        export PULSAROS_BUILD_TYPE="release"
        export PULSAROS_SSH_ENABLED="false"
        export PULSAROS_ADB_ENABLED="false"
        export PULSAROS_WATERMARK="false"
    fi

    export PULSAROS_VERSION="$VERSION"
    export PULSAROS_BUILD_DATE="$BUILD_DATE"
    export PULSAROS_BUILD_NUMBER="$BUILD_NUMBER"

    info "lunch ${PRODUCT_LUNCH}-${VARIANT}"
    lunch "${PRODUCT_LUNCH}-${VARIANT}"

    local JOBS="${JOBS:-$(( $(nproc) > 2 ? $(nproc) - 2 : 1 ))}"
    info "Собираю Android ($JOBS потоков)..."

    mkdir -p "$OUTPUT_DIR/logs"
    local LOGFILE="$OUTPUT_DIR/logs/build_${BUILD_TYPE}_${BUILD_DATE}.log"

    if ! make -j"$JOBS" 2>&1 | tee "$LOGFILE"; then
        die "make завершился с ошибкой.\nЛог: $LOGFILE"
    fi

    success "Android собран"
}

# ── Шаг 3: pack — упаковка финального образа ─────────────────────────────────
build_pack() {
    step "Step 3 / 3 — Pack image"
    cd "$ANDROID_SRC"
    # shellcheck disable=SC1091
    source build/envsetup.sh
    lunch "${PRODUCT_LUNCH}-$([ "$BUILD_TYPE" == "debug" ] && echo userdebug || echo user)" > /dev/null 2>&1

    info "Упаковка образа (pack)..."
    pack || die "pack завершился с ошибкой"

    [[ -f "$OPI_IMG" ]] || die "Образ не найден после pack: $OPI_IMG"
    success "Образ упакован: $OPI_IMG"
}

# ── Копируем и именуем финальный образ ───────────────────────────────────────
package_output() {
    step "Package output"
    mkdir -p "$OUTPUT_DIR"

    local IMG_NAME="PulsarOS-${VERSION}-${BUILD_TYPE}-${BUILD_DATE}.img"
    local IMG_DST="$OUTPUT_DIR/$IMG_NAME"

    cp "$OPI_IMG" "$IMG_DST"
    sha256sum "$IMG_DST" > "$IMG_DST.sha256"

    local SIZE
    SIZE=$(du -sh "$IMG_DST" | cut -f1)

    success "Образ готов!"
    echo ""
    echo -e "  ${BOLD}Файл  :${NC} $IMG_DST"
    echo -e "  ${BOLD}Размер:${NC} $SIZE"
    echo -e "  ${BOLD}SHA256:${NC} $(cut -d' ' -f1 "$IMG_DST.sha256")"
    echo ""
    echo -e "  Запись на SD-карту:"
    echo -e "  ${CYAN}sudo ./scripts/flash.sh $IMG_DST /dev/sdX${NC}"
    echo ""
}

# ── Clean ─────────────────────────────────────────────────────────────────────
do_clean() {
    step "Clean"
    warn "Очистка займёт некоторое время..."
    cd "$ANDROID_SRC"
    # shellcheck disable=SC1091
    source build/envsetup.sh > /dev/null 2>&1
    lunch "${PRODUCT_LUNCH}-userdebug" > /dev/null 2>&1 || true
    make clean
    # Очищаем longan тоже
    cd "$ANDROID_SRC/longan"
    ./build.sh clean 2>/dev/null || rm -rf out/
    success "Clean завершён"
}

# ── Главная функция ───────────────────────────────────────────────────────────
main() {
    print_banner
    check_args
    preflight
    sync_overlays

    [[ "$DO_CLEAN" == "clean" ]] && do_clean

    build_longan
    build_android
    build_pack
    package_output

    success "Сборка завершена! Тип: ${BOLD}$BUILD_TYPE${NC}  Версия: ${BOLD}$VERSION${NC}"
}

main "$@"
