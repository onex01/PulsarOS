#!/usr/bin/env bash
# PulsarOS build script
# Usage: ./scripts/build.sh [build|clean|sync] [user|userdebug|eng]
set -eo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PULSAR_VERSION="$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || echo "0.1.0-dev")"
REPO_DIR="${SCRIPT_DIR}/.."
ANDROID_SRC="${ANDROID_SRC:-/mnt/LinuxFile/H618-Android12-Src}"   # override via env
PRODUCT="pulsaros_zero3"         # Product name (must match device/softwinner/zero3/pulsaros_zero3.mk)
JOBS="${JOBS:-$(nproc)}"

# Validate that device tree exists in correct location
[[ -d "${REPO_DIR}/device/softwinner/zero3" ]] \
    || die "device/softwinner/zero3 not found in repo. Check repository structure."

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
# NOTE: We ONLY copy our additions, never delete Orange Pi source files.
# This allows device/ and vendor/ to contain both Orange Pi BSP and our customizations.
sync_overlays() {
    info "Syncing PulsarOS overlays to ${ANDROID_SRC} (with backup)"
    bash "${REPO_DIR}/scripts/sync_and_backup.sh" "${ANDROID_SRC}"
}

# ── Fix known libcedarx issues ───────────────────────────────────────────────
fix_known_issues() {
    info "Fixing known build issues..."
    
    # Fix CONF_ANDROID_MAJOR_VER macro duplication in libcedarx
    if bash "${REPO_DIR}/scripts/fix-libcedarx-macros.sh" "${ANDROID_SRC}"; then
        ok "  Known issues fixed"
    else
        warn "  Issue with known-issues fixer (continuing anyway)"
    fi
}

# ── Android source patches ───────────────────────────────────────────────────
apply_source_patches() {
    local patches_dir="${REPO_DIR}/patches/android-source"
    [[ -d "${patches_dir}" ]] || return 0

    info "Applying Android source patches"

    local patch_file
    for patch_file in "${patches_dir}"/*.patch; do
        [[ -e "${patch_file}" ]] || continue

        if patch -d "${ANDROID_SRC}" -p1 --dry-run < "${patch_file}" >/dev/null; then
            patch -d "${ANDROID_SRC}" -p1 < "${patch_file}"
            ok "  $(basename "${patch_file}") applied"
        elif patch -d "${ANDROID_SRC}" -p1 --reverse --dry-run < "${patch_file}" >/dev/null; then
            ok "  $(basename "${patch_file}") already applied"
        else
            die "Could not apply patch: ${patch_file}"
        fi
    done
}

check_prebuilt_clang_libs() {
    local clang_bin="${ANDROID_SRC}/prebuilts/clang/host/linux-x86/clang-3289846/bin/llvm-as"
    if [[ ! -x "${clang_bin}" ]]; then
        warn "Prebuilt clang binary not found: ${clang_bin}. Skipping shared library check."
        return 0
    fi

    if ! command -v ldd &>/dev/null; then
        warn "ldd not available; cannot verify prebuilts shared libraries."
        return 0
    fi

    local missing
    missing=$(ldd "${clang_bin}" 2>/dev/null | grep -E 'not found|no such file' || true)
    if [[ -n "${missing}" ]]; then
        cat <<EOF >&2
[ERROR] Prebuilt clang host tool is missing shared libraries:
${missing}

Install required packages and retry. On Ubuntu/Debian:
  sudo apt update
  sudo apt install libncurses5 lib32ncurses5-dev

If you already installed dependencies, make sure the host tool is running on the same architecture as your OS.
EOF
        exit 1
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

    # Check prebuilts host tool dependencies early.
    check_prebuilt_clang_libs

    # Fix known build issues before lunch
    fix_known_issues

    # lunch target: pulsaros_zero3-userdebug
    local LUNCH_TARGET="${PRODUCT}-${VARIANT}"
    info "Running: lunch ${LUNCH_TARGET}"
    lunch "${LUNCH_TARGET}" \
        || die "lunch failed. Check device/softwinner/zero3/AndroidProducts.mk"

    # CCACHE
    if command -v ccache &>/dev/null; then
        export USE_CCACHE=1
        export CCACHE_EXEC="$(command -v ccache)"
        export CCACHE_DIR="${ANDROID_SRC}/out/.ccache"
        export CCACHE_TEMPDIR="${ANDROID_SRC}/out/.ccache/tmp"
        mkdir -p "${CCACHE_DIR}" "${CCACHE_TEMPDIR}" || warn "Unable to create ccache directories"
        if ! "${CCACHE_EXEC}" -M "${CCACHE_SIZE:-60G}"; then
            warn "ccache initialization failed; disabling ccache"
            unset USE_CCACHE
        fi
    else
        warn "ccache not found — build will be slower"
    fi

    # Export version info into the build
    export PULSAR_VERSION
    export PULSAR_BUILD_TYPE="${VARIANT}"
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
apply_source_patches

case "${ACTION}" in
    build) do_build ;;
    clean) do_clean ;;
    sync)  ok "Overlays and source patches synced, no build requested." ;;
    *)     die "Unknown action '${ACTION}'. Use: build | clean | sync" ;;
esac
