#!/usr/bin/env bash
# Fix CONF_ANDROID_MAJOR_VER macro redefinition in libcedarx
# This script finds and removes duplicate CONF_ANDROID_MAJOR_VER definitions

set -euo pipefail

ANDROID_SRC="${1:-/mnt/LinuxFile/H618-Android12-Src}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

if [[ ! -d "${ANDROID_SRC}" ]]; then
    die "Android source not found at ${ANDROID_SRC}"
fi

info "Scanning for CONF_ANDROID_MAJOR_VER duplicates in libcedarx..."

# Find all Android.bp files in libcedarx
found=0
while IFS= read -r file; do
    count=$(grep -c "CONF_ANDROID_MAJOR_VER" "$file" || true)
    if [[ $count -gt 1 ]]; then
        info "Found $count definitions in $(basename $(dirname "$file"))/$(basename "$file")"
        
        # Check if file has both =12 and =10
        has_12=$(grep -c "CONF_ANDROID_MAJOR_VER=12" "$file" || true)
        has_10=$(grep -c "CONF_ANDROID_MAJOR_VER=10" "$file" || true)
        
        if [[ $has_12 -gt 0 && $has_10 -gt 0 ]]; then
            warn "  Found both =12 and =10, removing =10..."
            
            # Create backup
            cp "$file" "${file}.backup"
            
            # Remove lines with CONF_ANDROID_MAJOR_VER=10
            sed -i '/CONF_ANDROID_MAJOR_VER=10/d' "$file"
            
            ok "  Fixed: removed CONF_ANDROID_MAJOR_VER=10"
            ok "  Backup saved: ${file}.backup"
            found=$((found+1))
        fi
    fi
done < <(find "${ANDROID_SRC}/frameworks/av/media/libcedarx" -name "Android.bp" 2>/dev/null)

if [[ $found -eq 0 ]]; then
    info "No duplicates found to fix."
else
    ok "Fixed $found file(s)"
fi
