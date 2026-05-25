#!/usr/bin/env bash
# =============================================================================
# PulsarOS — Установка зависимостей и синхронизация исходников
# Поддерживается: Ubuntu 20.04, 22.04, 24.04 LTS x86_64
# Использование: ./scripts/setup-env.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[setup]${NC} $*"; }
success() { echo -e "${GREEN}[setup]${NC} ✓ $*"; }
warn()    { echo -e "${YELLOW}[setup]${NC} ⚠ $*"; }
die()     { echo -e "${RED}[setup]${NC} ✗ $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ANDROID_SRC="${ANDROID_SRC:-$HOME/android/pulsaros}"

# ── Определяем версию Ubuntu ──────────────────────────────────────────────────
get_ubuntu_version() {
    grep VERSION_ID /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "0"
}

# ── Проверка системы ──────────────────────────────────────────────────────────
check_system() {
    step "System check"
    [[ "$(uname -s)" == "Linux" ]] || die "Требуется Linux."
    [[ "$(uname -m)" == "x86_64" ]] || die "Требуется x86_64. Текущая: $(uname -m)"

    local ver
    ver=$(get_ubuntu_version)
    case "$ver" in
        20.04|22.04|24.04)
            success "ОС: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)" ;;
        *)
            warn "Обнаружена ОС версии $ver. Официально поддерживаются 20.04 / 22.04 / 24.04." ;;
    esac

    local ram_gb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
    local free_gb=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | tr -d 'G')

    info "ОЗУ: ${ram_gb}GB  |  Свободно на диске: ${free_gb}GB"
    (( ram_gb >= 16 )) || warn "Мало ОЗУ (${ram_gb}GB). Рекомендуется 32GB+."

    # Предупреждение про диск — 200 GB нужно только для ПОЛНОЙ сборки
    # Для работы с репо и частичных операций хватит меньше
    if (( free_gb < 50 )); then
        warn "Критически мало места (${free_gb}GB). Для полной сборки нужно ~300GB."
    elif (( free_gb < 200 )); then
        warn "Места ${free_gb}GB — для работы с репо хватит, для полной сборки Android нужно ~300GB."
    else
        success "Места на диске достаточно: ${free_gb}GB"
    fi
}

# ── Зависимости с учётом версии Ubuntu ───────────────────────────────────────
install_packages() {
    step "Install build dependencies"

    local ver
    ver=$(get_ubuntu_version)

    info "Обновление пакетной базы..."
    sudo apt-get update -qq

    # Базовые пакеты — одинаковы для всех версий Ubuntu
    local BASE_PKGS=(
        git gnupg flex bison gperf build-essential
        zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386
        x11proto-core-dev libx11-dev lib32z1-dev ccache
        libgl1-mesa-dev libxml2-utils xsltproc unzip u-boot-tools
        python-is-python3 libssl-dev clang gawk
        rsync patchelf schedtool squashfs-tools lz4 bc
    )

    # Пакеты зависящие от версии Ubuntu
    local VERSIONED_PKGS=()

    case "$ver" in
        20.04|22.04)
            info "Выбран набор пакетов для Ubuntu ${ver}"
            VERSIONED_PKGS=(
                lib32ncurses5-dev
                libncurses5
                libncurses5-dev
            )
            ;;
        24.04)
            info "Выбран набор пакетов для Ubuntu 24.04 (ncurses переименованы)"
            # В Ubuntu 24.04 lib32ncurses5-dev и libncurses5 удалены
            # Заменены на libncurses-dev + multilib варианты
            VERSIONED_PKGS=(
                libncurses-dev
                lib32ncurses-dev
                libtinfo-dev
                lib32z1-dev
            )
            ;;
        *)
            warn "Неизвестная версия Ubuntu ($ver), пробуем пакеты для 24.04..."
            VERSIONED_PKGS=(
                libncurses-dev
                lib32ncurses-dev
                libtinfo-dev
            )
            ;;
    esac

    info "Установка базовых зависимостей..."
    sudo apt-get install -y "${BASE_PKGS[@]}"

    info "Установка версионных зависимостей (ncurses и др.)..."
    # Ставим по одному чтоб пропустить недоступные, не падая целиком
    for pkg in "${VERSIONED_PKGS[@]}"; do
        if apt-cache show "$pkg" &>/dev/null 2>&1; then
            sudo apt-get install -y "$pkg" && info "  ✓ $pkg" || warn "  ✗ Не удалось установить $pkg (некритично)"
        else
            warn "  ↷ Пакет $pkg недоступен в этой версии Ubuntu (пропускаем)"
        fi
    done

    success "Зависимости установлены"
}

# ── Java ──────────────────────────────────────────────────────────────────────
install_java() {
    step "Java"

    # Проверяем Java 11 или 17 (оба поддерживаются AOSP Android 12)
    if java -version 2>&1 | grep -qE '"(11|17)'; then
        local jver
        jver=$(java -version 2>&1 | head -1)
        success "Java уже установлен: $jver"
        return
    fi

    local ver
    ver=$(get_ubuntu_version)

    # Ubuntu 24.04 → Java 17 (11 снят с поддержки в репах)
    # Ubuntu 20/22 → Java 11
    # if [[ "$ver" == "24.04" ]]; then
    #     info "Ubuntu 24.04 — устанавливаю OpenJDK 17..."
    #     sudo apt-get install -y openjdk-17-jdk
    #     success "Java 17 установлен"
    #     warn "Примечание: Android 12 официально требует Java 11."
    #     warn "Java 17 работает с большинством AOSP сборок, но возможны предупреждения."
    # else
    #     info "Устанавливаю OpenJDK 11..."
    #     sudo apt-get install -y openjdk-11-jdk
    #     sudo update-alternatives --set java \
    #         /usr/lib/jvm/java-11-openjdk-amd64/bin/java 2>/dev/null || true
    #     success "Java 11 установлен"
    # fi
}

# ── repo tool ─────────────────────────────────────────────────────────────────
install_repo() {
    step "repo tool"
    if command -v repo &>/dev/null; then
        success "repo уже установлен: $(repo --version 2>/dev/null | head -1 || echo 'OK')"
        return
    fi
    info "Установка repo..."
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo \
        -o "$HOME/.local/bin/repo"
    chmod a+x "$HOME/.local/bin/repo"

    if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    export PATH="$HOME/.local/bin:$PATH"
    success "repo установлен"
}

# ── ccache ────────────────────────────────────────────────────────────────────
setup_ccache() {
    step "ccache"
    ccache --max-size=50G
    if ! grep -q 'USE_CCACHE' "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" << 'EOF'

# PulsarOS — ccache для Android сборки
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR="$HOME/.ccache"
EOF
    fi
    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    success "ccache настроен (50GB, ~/.ccache)"
}

# ── git ───────────────────────────────────────────────────────────────────────
setup_git() {
    step "Git"
    local name email
    name=$(git config --global user.name 2>/dev/null || true)
    email=$(git config --global user.email 2>/dev/null || true)
    if [[ -z "$name" ]]; then
        git config --global user.name "PulsarOS Builder"
        warn "git user.name не задан — установлен 'PulsarOS Builder'. Смени при необходимости."
    fi
    if [[ -z "$email" ]]; then
        git config --global user.email "build@pulsaros.local"
        warn "git user.email не задан — установлен 'build@pulsaros.local'."
    fi
    success "Git: $(git config --global user.name) <$(git config --global user.email)>"
}

# ── Проверка symlink для Python ───────────────────────────────────────────────
check_python() {
    step "Python"
    if python --version 2>&1 | grep -q "Python 3"; then
        success "Python: $(python --version)"
    else
        warn "python → python3 симлинк отсутствует. Устанавливаю python-is-python3..."
        sudo apt-get install -y python-is-python3
        success "Python: $(python --version)"
    fi
}

# ── Инструкция по получению исходников ───────────────────────────────────────
print_source_instructions() {
    step "Android source"

    if [[ -d "$ANDROID_SRC/longan" && -f "$ANDROID_SRC/build/envsetup.sh" ]]; then
        success "Исходники уже находятся в: $ANDROID_SRC"
        return
    fi

    warn "Исходники Android не найдены в: $ANDROID_SRC"
    echo ""
    echo -e "${BOLD}  Шаги для получения исходников Orange Pi H618 Android 12:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Скачай архив исходников с Google Drive:"
    echo -e "     https://drive.google.com/drive/folders/1acn4Oosu1s-39hCK3uRiqj9gG0Jw-tGZ"
    echo -e "     Файлы: H618-Android12-Src.tar.gz.a*, H618-Android12-Src.tar.gz.md5sum"
    echo ""
    echo -e "  ${CYAN}2.${NC} Проверь MD5 и распакуй:"
    echo -e "     ${YELLOW}md5sum -c H618-Android12-Src.tar.gz.md5sum${NC}"
    echo -e "     ${YELLOW}cat H618-Android12-Src.tar.gz.a* > H618-Android12-Src.tar.gz${NC}"
    echo -e "     ${YELLOW}tar -xvf H618-Android12-Src.tar.gz${NC}"
    echo ""
    echo -e "  ${CYAN}3.${NC} Перемести в рабочую директорию:"
    echo -e "     ${YELLOW}mv H618-Android12-Src $ANDROID_SRC${NC}"
    echo -e "     ${YELLOW}# или: export ANDROID_SRC=/другой/путь${NC}"
    echo ""
    echo -e "  ${CYAN}4.${NC} После распаковки запусти сборку:"
    echo -e "     ${YELLOW}./scripts/build.sh debug${NC}"
    echo ""
}

# ── Итог ─────────────────────────────────────────────────────────────────────
print_summary() {
    local ver
    ver=$(get_ubuntu_version)
    local java_ver
    java_ver=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1 2>/dev/null || echo "?")

    echo ""
    echo -e "${BOLD}${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Окружение PulsarOS готово к сборке!${NC}"
    echo -e "${BOLD}${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Система       : Ubuntu ${ver}"
    echo -e "  Java          : JDK ${java_ver}"
    echo -e "  PulsarOS repo : ${CYAN}$REPO_ROOT${NC}"
    echo -e "  Android source: ${CYAN}$ANDROID_SRC${NC}"
    echo ""
    echo -e "  Следующие шаги:"
    echo -e "  ${YELLOW}source ~/.bashrc${NC}       (или открой новый терминал)"
    echo -e "  ${YELLOW}./scripts/build.sh debug${NC}"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}PulsarOS — Setup Environment${NC}"
    echo ""
    check_system
    install_packages
    install_java
    install_repo
    setup_ccache
    setup_git
    check_python
    print_source_instructions
    print_summary
}

main "$@"