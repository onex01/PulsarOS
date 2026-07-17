#!/usr/bin/env bash
# Fix cedarx build issues for PulsarOS
# 1. CONF_ANDROID_MAJOR_VER=10 → =12 in cedarx_config.go
# 2. Add sun50iw9 board mapping in cedarx_config.go
# 3. Restore layerControl.cpp from original BSP

set -euo pipefail

ANDROID_SRC="${1:-/mnt/BF/H618-Android12-Src}"
ORIG_SRC="${2:-/mnt/BF/OriginalVersion/H618-Android12-Src}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

found=0

# Fix 1: Replace CONF_ANDROID_MAJOR_VER=10 with =12 in cedarx_config.go
CONFIG_GO="${ANDROID_SRC}/frameworks/av/media/libcedarx/config/cedarx_config.go"
if [[ -f "${CONFIG_GO}" ]]; then
    count=$(grep -c "CONF_ANDROID_MAJOR_VER=10" "${CONFIG_GO}" 2>/dev/null || true)
    if [[ $count -gt 0 ]]; then
        warn "cedarx_config.go: Replacing $count CONF_ANDROID_MAJOR_VER=10 → =12"
        cp "${CONFIG_GO}" "${CONFIG_GO}.backup"
        sed -i 's/CONF_ANDROID_MAJOR_VER=10/CONF_ANDROID_MAJOR_VER=12/g' "${CONFIG_GO}"
        ok "cedarx_config.go fixed"
        found=$((found+1))
    fi
fi

# Fix 2: Add sun50iw9 board mapping if missing
if [[ -f "${CONFIG_GO}" ]]; then
    if ! grep -q 'sun50iw9' "${CONFIG_GO}" 2>/dev/null; then
        warn "cedarx_config.go: Adding sun50iw9 → apollo_S_cflags mapping"
        sed -i 's/cdxCfgType {"apollo",  apollo_S_cflags},/cdxCfgType {"apollo",  apollo_S_cflags},\n            cdxCfgType {"sun50iw9", apollo_S_cflags},/' "${CONFIG_GO}"
        ok "sun50iw9 mapping added"
        found=$((found+1))
    fi
fi

# Fix 3: Restore layerControl.cpp from original BSP (has CONF_SIMPLE_ION guard)
LAYER_CTL="${ANDROID_SRC}/frameworks/av/media/libcedarx/android_adapter/output/layerControl.cpp"
ORIG_LAYER_CTL="${ORIG_SRC}/frameworks/av/media/libcedarx/android_adapter/output/layerControl.cpp"
if [[ -f "${ORIG_LAYER_CTL}" ]] && [[ -f "${LAYER_CTL}" ]]; then
    if ! grep -q "CONF_SIMPLE_ION" "${LAYER_CTL}" 2>/dev/null; then
        warn "layerControl.cpp: Missing CONF_SIMPLE_ION guard, restoring from original BSP"
        cp "${ORIG_LAYER_CTL}" "${LAYER_CTL}"
        ok "layerControl.cpp restored"
        found=$((found+1))
    fi
fi

if [[ $found -eq 0 ]]; then
    info "All cedarx fixes already applied."
else
    ok "Applied $found fix(es)"
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
    info "No duplicates found in Android.bp files."
fi

# Fix cedarx_config.go — remove ALL CONF_ANDROID_MAJOR_VER lines
# The build system already defines it (=12 for Android 12)
# cedarx_config.go has board-specific =10 that conflicts
CONFIG_GO="${ANDROID_SRC}/frameworks/av/media/libcedarx/config/cedarx_config.go"
if [[ -f "${CONFIG_GO}" ]]; then
    count=$(grep -c "CONF_ANDROID_MAJOR_VER=10" "${CONFIG_GO}" || true)
    if [[ $count -gt 0 ]]; then
        warn "cedarx_config.go: Found $count CONF_ANDROID_MAJOR_VER=10, replacing with =12..."
        cp "${CONFIG_GO}" "${CONFIG_GO}.backup"
        sed -i 's/CONF_ANDROID_MAJOR_VER=10/CONF_ANDROID_MAJOR_VER=12/g' "${CONFIG_GO}"
        ok "Fixed cedarx_config.go"
        found=$((found+1))
    fi
fi

if [[ $found -eq 0 ]]; then
    info "No duplicates found."
else
    ok "Fixed $found file(s)"
fi
