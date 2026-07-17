#!/usr/bin/env bash
# Step 0: Setup System (install build dependencies)

step_setup_system() {
    echo -e "\n${BOLD}═══ Подготовка системы ═══${NC}\n"

    msg_info "Установка зависимостей для сборки Android..."
    run_cmd sudo apt-get update -qq
    run_cmd sudo apt-get install -y -qq \
        git-core gnupg flex bison gperf build-essential zip curl \
        zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
        lib32ncurses-dev x11proto-core-dev libx11-dev lib32z1-dev \
        ccache libgl1-mesa-dev libxml2-utils xsltproc unzip \
        u-boot-tools python3 python-is-python3 libssl-dev libncurses-dev \
        clang gawk imagemagick dos2unix kmod

    # GNU Make 4.3 — Allwinner BSP несовместим с Make 4.4 (Debian 13)
    local MAKE_VERSION=$(make --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+')
    if [[ "${MAKE_VERSION}" != "4.3" ]]; then
        msg_warn "Make ${MAKE_VERSION} — Allwinner BSP требует Make 4.3"
        msg_info "Скачиваю Make 4.3 из исходников..."
        local MAKE_SRC="/tmp/make-4.3"
        if [[ ! -d "${MAKE_SRC}" ]]; then
            curl -sL "https://ftp.gnu.org/gnu/make/make-4.3.tar.gz" -o /tmp/make-4.3.tar.gz
            tar xzf /tmp/make-4.3.tar.gz -C /tmp/
            rm -f /tmp/make-4.3.tar.gz
        fi
        if [[ -d "${MAKE_SRC}" ]]; then
            cd "${MAKE_SRC}"
            ./configure --prefix=/usr/local --quiet 2>&1 | tail -3
            make -j$(nproc) --quiet 2>&1 | tail -3
            sudo make install --quiet 2>&1 | tail -3
            cd "${REPO_DIR}"
            local NEW_VER=$(/usr/local/bin/make --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+')
            if [[ "${NEW_VER}" == "4.3" ]]; then
                msg_ok "Make 4.3 установлен: /usr/local/bin/make"
                msg_info "Для использования: hash -r (сброс кэша путей)"
            else
                msg_warn "Не удалось установить Make 4.3"
            fi
        fi
    else
        msg_ok "Make 4.3 уже установлен"
    fi

    # repo tool
    mkdir -p ~/.local/bin
    if [[ ! -f ~/.local/bin/repo ]]; then
        msg_info "Скачиваю repo tool..."
        curl -sL https://storage.googleapis.com/git-repo-downloads/repo > ~/.local/bin/repo
        chmod a+x ~/.local/bin/repo
        msg_ok "repo tool установлен"
    else
        msg_ok "repo tool уже есть"
    fi
    export PATH="$HOME/.local/bin:$PATH"
    grep -q '.local/bin' ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

    # Android NDK
    local NDK_DIR="${HOME}/Android/Sdk/ndk"
    local NDK_VERSION="27.0.12077973"
    if [[ ! -d "${NDK_DIR}/${NDK_VERSION}" ]]; then
        msg_info "Скачиваю Android NDK r27d..."
        local NDK_URL="https://dl.google.com/android/repository/android-ndk-r27d-linux.zip"
        run_cmd curl -L --progress-bar -o /tmp/android-ndk.zip "${NDK_URL}"
        if [[ -f /tmp/android-ndk.zip ]] && [[ $(stat -c%s /tmp/android-ndk.zip 2>/dev/null || echo 0) -gt 100000000 ]]; then
            msg_info "Распаковываю NDK (может занять время)..."
            run_cmd unzip -q -o /tmp/android-ndk.zip -d /tmp/ndk_extract/
            mkdir -p "${NDK_DIR}"
            mv /tmp/ndk_extract/android-ndk-r27d "${NDK_DIR}/${NDK_VERSION}" 2>/dev/null || \
            mv /tmp/ndk_extract/android-ndk-r27* "${NDK_DIR}/${NDK_VERSION}" 2>/dev/null || true
            rm -rf /tmp/ndk_extract /tmp/android-ndk.zip
            msg_ok "NDK установлен: ${NDK_DIR}/${NDK_VERSION}"
        else
            msg_warn "Не удалось скачать NDK. Скачайте вручную: https://developer.android.com/ndk/downloads"
            rm -f /tmp/android-ndk.zip
        fi
    else
        msg_ok "NDK уже установлен: ${NDK_DIR}/${NDK_VERSION}"
    fi

    # Export NDK path
    export ANDROID_NDK_HOME="${NDK_DIR}/${NDK_VERSION}"
    grep -q 'ANDROID_NDK_HOME' ~/.bashrc 2>/dev/null || echo "export ANDROID_NDK_HOME=\"${NDK_DIR}/${NDK_VERSION}\"" >> ~/.bashrc

    msg_ok "Система готова к сборке"
    msg_info "Установлено: git, build-essential, clang, ccache, imagemagick, repo, NDK, make 4.3"
}
