#!/usr/bin/env bash
# Step 3: Download Libretro Cores from Buildbot

step_build_cores() {
    echo -e "\n${BOLD}═══ Загрузка ядер Libretro (buildbot) ═══${NC}\n"

    local CORES_DST="${REPO_DIR}/vendor/pulsaros/prebuilt/cores"
    mkdir -p "${CORES_DST}"

    local BUILDBOT_BASE="https://buildbot.libretro.com/nightly/android/latest/armeabi-v7a"

    declare -A CORE_ZIPS=(
        [fceumm]="fceumm_libretro_android.so.zip"
        [snes9x]="snes9x_libretro_android.so.zip"
        [gambatte]="gambatte_libretro_android.so.zip"
        [mgba]="mgba_libretro_android.so.zip"
        [melonds]="melonds_libretro_android.so.zip"
        [genesis_plus_gx]="genesis_plus_gx_libretro_android.so.zip"
        [pcsx_rearmed]="pcsx_rearmed_libretro_android.so.zip"
        [fbneo]="fbneo_libretro_android.so.zip"
        [mame2003_plus]="mame2003_plus_libretro_android.so.zip"
        [stella]="stella_libretro_android.so.zip"
        [handy]="handy_libretro_android.so.zip"
        [prosystem]="prosystem_libretro_android.so.zip"
        [atari800]="atari800_libretro_android.so.zip"
        [mednafen_pce_fast]="mednafen_pce_fast_libretro_android.so.zip"
        [bluemsx]="bluemsx_libretro_android.so.zip"
        [mednafen_wswan]="mednafen_wswan_libretro_android.so.zip"
        [puae]="puae_libretro_android.so.zip"
        [scummvm]="scummvm_libretro_android.so.zip"
        [prboom]="prboom_libretro_android.so.zip"
        [picodrive]="picodrive_libretro_android.so.zip"
        [smsplus_gx]="smsplus_libretro_android.so.zip"
        [ppsspp]="ppsspp_libretro_android.so.zip"
        [mupen64plus_next]="mupen64plus_next_gles3_libretro_android.so.zip"
        [mednafen_pokemini]="pokemini_libretro_android.so.zip"
    )

    local success=0 failed=0
    local tmp_dir=$(mktemp -d)
    trap "rm -rf ${tmp_dir}" RETURN

    for core in "${!CORE_ZIPS[@]}"; do
        local so_name="${core}_libretro.so"

        if [[ -f "${CORES_DST}/${so_name}" ]]; then
            msg_ok "${core} уже есть: $(du -h "${CORES_DST}/${so_name}" | cut -f1)"
            ((success++))
            continue
        fi

        local zip_name="${CORE_ZIPS[$core]}"
        local url="${BUILDBOT_BASE}/${zip_name}"

        msg_info "Скачиваю ${core}... (${zip_name})"

        local http_code
        http_code=$(curl -sL --connect-timeout 15 --max-time 120 -w '%{http_code}' -o "${tmp_dir}/${zip_name}" "${url}")
        local dl_size=$(stat -c%s "${tmp_dir}/${zip_name}" 2>/dev/null || echo 0)
        if [[ "${http_code}" != "200" ]] || [[ "${dl_size}" -lt 1000 ]]; then
            msg_warn "${core}: ошибка скачивания (HTTP ${http_code}, ${dl_size} bytes)"
            rm -f "${tmp_dir}/${zip_name}"
            ((failed++))
            continue
        fi

        if ! unzip -t "${tmp_dir}/${zip_name}" >/dev/null 2>&1; then
            msg_warn "${core}: невалидный zip"
            rm -f "${tmp_dir}/${zip_name}"
            ((failed++))
            continue
        fi

        local so_file=$(unzip -l "${tmp_dir}/${zip_name}" 2>/dev/null | grep '\.so$' | awk '{print $NF}' | head -1)
        if [[ -z "${so_file}" ]]; then
            msg_warn "${core}: .so не найден в zip"
            rm -f "${tmp_dir}/${zip_name}"
            ((failed++))
            continue
        fi

        unzip -o "${tmp_dir}/${zip_name}" "${so_file}" -d "${tmp_dir}/extract" >/dev/null 2>&1
        if [[ -f "${tmp_dir}/extract/${so_file}" ]]; then
            cp "${tmp_dir}/extract/${so_file}" "${CORES_DST}/${so_name}"
            msg_ok "${core}: $(du -h "${CORES_DST}/${so_name}" | cut -f1)"
            ((success++))
        else
            msg_warn "${core}: не удалось распаковать"
            ((failed++))
        fi

        rm -f "${tmp_dir}/${zip_name}"
        rm -rf "${tmp_dir}/extract"
    done

    echo ""
    msg_info "Результат: ${success} загружено, ${failed} ошибок"
}
