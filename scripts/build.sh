#!/usr/bin/env bash
# PulsarOS Build Script
# SPDX-License-Identifier: MIT
set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_SRC="${ANDROID_SRC:-/mnt/wwn-0x50014ee60877474c-part1/unpuck/out/H618-Android12-Src}"
PULSAROS_VERSION="$(cat "$REPO_ROOT/VERSION")"
export PULSAROS_VERSION

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

sync_overlays() {
    info "Syncing PulsarOS overlays to $ANDROID_SRC"
    for sub in device vendor packages; do
        if [[ -d "$REPO_ROOT/$sub" ]]; then
            mkdir -p "$ANDROID_SRC/$sub"
            rsync -a --delete \
                --exclude='*/ConsoleLauncher/' \
                --exclude='*/TVBro/' \
                --exclude='*/RetroArch/' \
                --exclude='*/Kodi/' \
                --exclude='*/EmulationStationDE/' \
                "$REPO_ROOT/$sub/" "$ANDROID_SRC/$sub/"
            info "  $sub/ synced"
        fi
    done
}

update_submodules() {
    info "Updating git submodules"
    ( cd "$REPO_ROOT" && git submodule update --init --recursive --jobs=4 )
}

build_android() {
    local type="${1:-userdebug}"
    info "Building PulsarOS v$PULSAROS_VERSION ($type)"
    cd "$ANDROID_SRC"
    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    command -v ccache &>/dev/null && ccache -M 60G || warn "ccache not found"
    source build/envsetup.sh
    lunch "pulsaros_zero3-$type"
    export BUILD_NUMBER="${PULSAROS_BUILD_NUMBER:-0}"
    m -j"$(nproc)" target-files-package otatools
    info "Build complete: out/target/product/zero3/"
}

case "${1:-help}" in
    sync)   sync_overlays; update_submodules ;;
    build)  sync_overlays; build_android "${2:-userdebug}" ;;
    clean)  ( cd "$ANDROID_SRC" && make clobber ) ;;
    *)      echo "Usage: $0 {sync|build [userdebug|user|eng]|clean}"; exit 1 ;;
esac