#!/usr/bin/env bash
# Step 2: Download APKs

step_download_apks() {
    echo -e "\n${BOLD}═══ Скачивание APK ═══${NC}\n"

    local APK_DIR="${REPO_DIR}/vendor/pulsaros/prebuilt/apk"
    mkdir -p "${APK_DIR}"

    download_one() {
        local name="$1" url="$2" out="$3"
        if [[ -f "${out}" ]] && [[ $(stat -c%s "${out}" 2>/dev/null || echo 0) -gt 10000 ]]; then
            msg_ok "${name} уже есть ($(du -h "${out}" | cut -f1))"
            return 0
        fi
        if [[ -z "${url}" ]]; then
            msg_warn "${name}: URL пустой"
            return 1
        fi
        msg_info "Скачиваю ${name}... (${url})"
        local http_code
        http_code=$(curl -L --connect-timeout 30 --max-time 300 -w '%{http_code}' -o "${out}" "${url}" 2>/dev/null)
        local size=$(stat -c%s "${out}" 2>/dev/null || echo 0)
        if [[ "${size}" -gt 10000 ]]; then
            msg_ok "${name}: $(du -h "${out}" | cut -f1) (HTTP ${http_code})"
        else
            msg_warn "${name}: ошибка загрузки (HTTP ${http_code}, ${size} bytes)"
            rm -f "${out}"
            return 1
        fi
    }

    download_one_RetroArch() {
        local url="$1" out="$2"
        msg_info "  Пробую: ${url}"
        local http_code
        http_code=$(curl -L --connect-timeout 10 --max-time 120 -w '%{http_code}' -o "${out}" "${url}" 2>/dev/null)
        local size=$(stat -c%s "${out}" 2>/dev/null || echo 0)
        if [[ "${size}" -gt 100000 ]]; then
            msg_ok "RetroArch: $(du -h "${out}" | cut -f1) (HTTP ${http_code})"
            return 0
        fi
        msg_warn "  Не удалось (${size} bytes, HTTP ${http_code})"
        rm -f "${out}"
        return 1
    }

    # Daijishou
    local daijishou_url=$(curl -s --connect-timeout 10 "https://api.github.com/repos/TapiocaFox/Daijishou/releases/latest" 2>/dev/null | grep -o '"browser_download_url": "[^"]*\.apk"' | head -1 | cut -d'"' -f4)
    [[ -z "${daijishou_url}" ]] && daijishou_url="https://github.com/TapiocaFox/Daijishou/releases/download/v1.5.0/416.apk"
    download_one "Daijishou" "${daijishou_url}" "${APK_DIR}/Daijishou.apk"

    # Kodi
    download_one "Kodi" "https://mirrors.kodi.tv/releases/android/arm/kodi-21.0-Omega-armeabi-v7a.apk" "${APK_DIR}/Kodi.apk"

    # TV Bro
    local tvbro_url=$(curl -s --connect-timeout 10 "https://api.github.com/repos/truefedex/tv-bro/releases/latest" 2>/dev/null | grep -o '"browser_download_url": "[^"]*\.apk"' | head -1 | cut -d'"' -f4)
    [[ -z "${tvbro_url}" ]] && tvbro_url="https://github.com/truefedex/tv-bro/releases/download/v2.1.6/tvbro-2.1.6-generic-geckoExcluded.apk"
    download_one "TV Bro" "${tvbro_url}" "${APK_DIR}/TVBro.apk"

    # RetroArch
    msg_info "Скачиваю RetroArch..."
    local ra_ok=0
    for url in \
        "https://f-droid.org/repo/com.retroarch.apk" \
        "https://buildbot.libretro.com/stable/1.19.1/android/RetroArch.apk" \
        "https://buildbot.libretro.com/stable/1.17.0/android/RetroArch.apk"; do
        if download_one_RetroArch "${url}" "${APK_DIR}/RetroArch.apk"; then ra_ok=1; break; fi
    done
    [[ ${ra_ok} -eq 0 ]] && msg_warn "RetroArch: соберите из исходников (пункт 5)"

    echo ""
    msg_info "Загруженные APK:"
    for f in "${APK_DIR}"/*.apk; do [[ -f "$f" ]] && echo "  $(du -h "$f" | cut -f1) $(basename "$f")"; done
}
