#!/usr/bin/env bash
# =============================================================================
# PulsarOS — Установка зависимостей и синхронизация исходников
# Проверено на Ubuntu 22.04 LTS x86_64
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

# ── Проверка системы ──────────────────────────────────────────────────────────
check_system() {
    step "System check"
    [[ "$(uname -s)" == "Linux" ]] || die "Требуется Linux. macOS/Windows не поддерживаются."
    [[ "$(uname -m)" == "x86_64" ]] || die "Требуется x86_64. Текущая архитектура: $(uname -m)"

    if ! grep -qE "Ubuntu (20|22)\.04" /etc/os-release 2>/dev/null; then
        warn "Рекомендуется Ubuntu 20.04 или 22.04."
    else
        success "ОС: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    fi

    local ram_gb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
    local free_gb=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | tr -d 'G')

    info "ОЗУ: ${ram_gb}GB  |  Свободно на диске: ${free_gb}GB"
    (( ram_gb >= 16 )) || warn "Мало ОЗУ (${ram_gb}GB). Рекомендуется 32GB+."
    (( free_gb >= 200 )) || warn "Мало места (${free_gb}GB). Нужно ~300GB для сборки."
}

# ── Зависимости (из официальной документации Orange Pi H618) ─────────────────
install_packages() {
    step "Install build dependencies"
    info "Обновление пакетной базы..."
    sudo apt-get update -qq

    # Точный список из официального руководства Orange Pi H618 Android 12
    info "Установка зависимостей сборки Android..."
    sudo apt-get install -y \
        git gnupg flex bison gperf build-essential \
        zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
        lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev ccache \
        libgl1-mesa-dev libxml2-utils xsltproc unzip u-boot-tools \
        python-is-python3 libssl-dev libncurses5 clang gawk \
        rsync patchelf schedtool squashfs-tools lz4 bc

    success "Зависимости установлены"
}

# ── Java 11 ───────────────────────────────────────────────────────────────────
install_java() {
    step "Java 11"
    if java -version 2>&1 | grep -q '"11'; then
        success "Java 11 уже установлен"
        return
    fi
    info "Установка OpenJDK 11..."
    sudo apt-get install -y openjdk-11-jdk
    sudo update-alternatives --set java /usr/lib/jvm/java-11-openjdk-amd64/bin/java 2>/dev/null || true
    success "Java 11 установлен"
}

# ── repo tool ─────────────────────────────────────────────────────────────────
install_repo() {
    step "repo tool"
    if command -v repo &>/dev/null; then
        success "repo уже установлен: $(repo --version 2>/dev/null | head -1)"
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
        warn "Задал git user.name = 'PulsarOS Builder'. Смени при необходимости."
    fi
    if [[ -z "$email" ]]; then
        git config --global user.email "build@pulsaros.local"
        warn "Задал git user.email = 'build@pulsaros.local'. Смени при необходимости."
    fi
    success "Git: $(git config --global user.name) <$(git config --global user.email)>"
}

# ── Инструкция по получению исходников ───────────────────────────────────────
print_source_instructions() {
    step "Android source"

    if [[ -d "$ANDROID_SRC/longan" && -f "$ANDROID_SRC/build/envsetup.sh" ]]; then
        success "Исходники уже находятся в: $ANDROID_SRC"
        return
    fi

    warn "Исходники Android не найдены в $ANDROID_SRC"
    echo ""
    echo -e "${BOLD}  Шаги для получения исходников Orange Pi H618 Android 12:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Скачай архив исходников с Google Drive:"
    echo -e "     https://drive.google.com/drive/folders/1acn4Oosu1s-39hCK3uRiqj9gG0Jw-tGZ"
    echo -e "     Файлы: H618-Android12-Src.tar.gza*, H618-Android12-Src.tar.gz.md5sum"
    echo ""
    echo -e "  ${CYAN}2.${NC} Проверь MD5 и распакуй:"
    echo -e "     ${YELLOW}md5sum -c H618-Android12-Src.tar.gz.md5sum${NC}"
    echo -e "     ${YELLOW}cat H618-Android12-Src.tar.gza* > H618-Android12-Src.tar.gz${NC}"
    echo -e "     ${YELLOW}tar -xvf H618-Android12-Src.tar.gz${NC}"
    echo ""
    echo -e "  ${CYAN}3.${NC} Переместить/симлинкнуть в:"
    echo -e "     ${YELLOW}mv H618-Android12-Src $ANDROID_SRC${NC}"
    echo -e "     или задай свой путь: ${YELLOW}export ANDROID_SRC=/путь/к/исходникам${NC}"
    echo ""
    echo -e "  ${CYAN}4.${NC} Снова запусти сборку:"
    echo -e "     ${YELLOW}./scripts/build.sh debug${NC}"
    echo ""
}

# ── Итог ─────────────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Окружение PulsarOS готово к сборке!${NC}"
    echo -e "${BOLD}${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  PulsarOS repo  : ${CYAN}$REPO_ROOT${NC}"
    echo -e "  Android source : ${CYAN}$ANDROID_SRC${NC}"
    echo ""
    echo -e "  Следующие шаги:"
    echo -e "  ${YELLOW}source ~/.bashrc${NC}   (или открой новый терминал)"
    echo -e "  ${YELLOW}./scripts/build.sh debug${NC}"
    echo ""
}

main() {
    echo -e "${BOLD}PulsarOS — Setup Environment${NC}"
    echo ""
    check_system
    install_packages
    install_java
    install_repo
    setup_ccache
    setup_git
    print_source_instructions
    print_summary
}

main "$@"
