#!/usr/bin/env bash
# PulsarOS build script
# Usage: ./scripts/build.sh [build|clean|sync] [user|userdebug|eng]
set -eo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PULSAR_VERSION="$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || echo "0.1.0-dev")"
REPO_DIR="${SCRIPT_DIR}/.."
ANDROID_SRC="${ANDROID_SRC:-/mnt/OHDD/H618-Android12-Src}"   # override via env
PRODUCT="pulsaros_zero3"
JOBS="${JOBS:-$(nproc)}"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Args ─────────────────────────────────────────────────────────────────────
ACTION="${1:-build}"
VARIANT="${2:-userdebug}"

[[ "$VARIANT" =~ ^(user|userdebug|eng)$ ]] \
    || die "Unknown variant '$VARIANT'. Use: user | userdebug | eng"

# ── Sync overlays ─────────────────────────────────────────────────────────────
sync_overlays() {
    info "Syncing PulsarOS overlays to ${ANDROID_SRC}"

    for dir in device vendor; do
        src="${REPO_DIR}/${dir}"
        dst="${ANDROID_SRC}/${dir}"
        if [[ -d "$src" ]]; then
            rsync -a --delete "${src}/" "${dst}/"
            ok "  ${dir}/ synced"
        else
            warn "  ${dir}/ not found in repo, skipping"
        fi
    done

    src="${REPO_DIR}/packages"
    dst="${ANDROID_SRC}/packages"
    if [[ -d "$src" ]]; then
        found=false
        for sub in "$src"/*; do
            [[ -d "$sub" ]] || continue
            found=true
            subname=$(basename "$sub")
            mkdir -p "${dst}/${subname}"
            rsync -a --delete "${sub}/" "${dst}/${subname}/"
            ok "  packages/${subname}/ synced"
        done
        if [[ "$found" = false ]]; then
            warn "  packages/ directory is empty, nothing to sync"
        fi
    else
        warn "  packages/ not found in repo, skipping"
    fi
}

# ── Build ─────────────────────────────────────────────────────────────────────
do_build() {
    info "Building PulsarOS v${PULSAR_VERSION} (${VARIANT})"

    cd "${ANDROID_SRC}"

    # Validate Android source tree
    [[ -f "build/envsetup.sh" ]] \
        || die "Android source not found at ${ANDROID_SRC}. Set ANDROID_SRC env var."

    if [[ ! -f "packages/modules/common/Android.bp" ]]; then
        die "Android source appears incomplete: missing packages/modules/common/Android.bp."
    fi

    # shellcheck disable=SC1091
    source build/envsetup.sh

    # lunch target: pulsaros_zero3-userdebug
    local LUNCH_TARGET="${PRODUCT}-${VARIANT}"
    info "Running: lunch ${LUNCH_TARGET}"
    lunch "${LUNCH_TARGET}" \
        || die "lunch failed. Check device/orangepi/zero3/AndroidProducts.mk"

    # CCACHE
    if command -v ccache &>/dev/null; then
        export USE_CCACHE=1
        export CCACHE_EXEC="$(command -v ccache)"
        ccache -M "${CCACHE_SIZE:-60G}"
    else
        warn "ccache not found — build will be slower"
    fi

    # Export version info into the build
    export PULSAR_VERSION
    export PULSAR_BUILD_TYPE="${VARIANT}"
    export BUILD_DATETIME="$(date -u +%s)"
    export BUILD_USERNAME="${USER}"
    export BUILD_HOSTNAME="$(hostname)"

    info "Starting make -j${JOBS} (this will take a while…)"
    make -j"${JOBS}" \
        || die "make failed — check build output above"

    ok "Build complete → out/target/product/zero3/"
    _print_artifacts
}

_print_artifacts() {
    local out="${ANDROID_SRC}/out/target/product/zero3"
    echo ""
    echo "  Artifacts:"
    for f in boot.img system.img vendor.img; do
        [[ -f "${out}/${f}" ]] \
            && echo "    ${GREEN}✓${NC} ${out}/${f}" \
            || echo "    ${RED}✗${NC} ${out}/${f} (missing)"
    done
}

# ── Clean ─────────────────────────────────────────────────────────────────────
do_clean() {
    warn "Cleaning out/target/product/zero3 …"
    cd "${ANDROID_SRC}"
    source build/envsetup.sh
    lunch "${PRODUCT}-${VARIANT}"
    make clean
    ok "Clean done"
}

# ── Main ─────────────────────────────────────────────────────────────────────
sync_overlays

case "${ACTION}" in
    build) do_build ;;
    clean) do_clean ;;
    sync)  ok "Overlays synced, no build requested." ;;
    *)     die "Unknown action '${ACTION}'. Use: build | clean | sync" ;;
esac