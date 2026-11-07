#!/usr/bin/env bash
# PulsarOS — скачивание APK, которые нужны сборке.
#
# Сами APK в git не лежат (`.gitignore`: prebuilt/apk/*.apk), иначе репозиторий
# пухнет на гигабайт. Здесь — официальные адреса и сверка с SHA256SUMS, чтобы
# сборка из чистого клона была воспроизводимой.
#
#   scripts/fetch-apps.sh           скачать недостающее / битое
#   scripts/fetch-apps.sh --check   только проверить наличие и хеши
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK_DIR="$REPO_DIR/prebuilt/apk"
SUMS="$APK_DIR/SHA256SUMS"
CHECK_ONLY=0
[[ ${1:-} == "--check" ]] && CHECK_ONLY=1

# Разложено по категориям, чтобы было видно, зачем приложение в прошивке.
APPS=(
    # видео
    "VLC.apk|https://get.videolan.org/vlc-android/3.7.1/VLC-Android-3.7.1-armeabi-v7a.apk"
    # эмуляторы standalone
    "PPSSPP.apk|https://www.ppsspp.org/files/1_20_4/ppsspp.apk"
    "DuckStation.apk|https://downloads.duckstation.org/android-testing/downloads/duckstation-12010.apk"
    "Mupen64PlusFZ.apk|https://f-droid.org/repo/org.mupen64plusae.v3.alpha_246.apk"
    # браузер и утилиты
    "Fennec.apk|https://f-droid.org/repo/org.mozilla.fennec_fdroid_1590000.apk"
    "MaterialFiles.apk|https://f-droid.org/repo/me.zhanghai.android.files_40.apk"
    "primftpd.apk|https://f-droid.org/repo/org.primftpd_71.apk"
)

die() { echo "ОШИБКА: $*" >&2; exit 1; }

want_sum() { # want_sum <имя файла> -> ожидаемый sha256 или пусто
    [[ -f "$SUMS" ]] || return 0
    awk -v f="$1" '$2 == f { print $1 }' "$SUMS" | head -1
}

ok=0 bad=0
for entry in "${APPS[@]}"; do
    file="${entry%%|*}"
    url="${entry#*|}"
    dst="$APK_DIR/$file"
    sum="$(want_sum "$file")"

    if [[ -f "$dst" ]]; then
        if [[ -n "$sum" ]] && [[ "$(sha256sum "$dst" | cut -d' ' -f1)" != "$sum" ]]; then
            echo "  битый хеш, перекачиваю: $file"
            rm -f "$dst"
        else
            ok=$((ok + 1))
            continue
        fi
    fi

    if [[ $CHECK_ONLY -eq 1 ]]; then
        echo "  нет: $file"; bad=$((bad + 1)); continue
    fi

    echo "  качаю: $file"
    curl -fL --retry 3 --retry-delay 2 -o "$dst.part" "$url" \
        || die "не скачался $file ($url)"
    mv "$dst.part" "$dst"
    if [[ -n "$sum" ]]; then
        [[ "$(sha256sum "$dst" | cut -d' ' -f1)" == "$sum" ]] \
            || die "$file: sha256 не совпал с SHA256SUMS"
    fi
    ok=$((ok + 1))
done

echo "готово: $ok файлов, отсутствуют/битые: $bad"
[[ $CHECK_ONLY -eq 1 && $bad -gt 0 ]] && exit 1
exit 0