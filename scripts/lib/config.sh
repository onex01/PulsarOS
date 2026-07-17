#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  PulsarOS Build System — Configuration                                    ║
# ║  Config management, default values, path resolution                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_DIR="${SCRIPT_DIR}"
CONFIG_FILE="${HOME}/.pulsaros.conf"
PULSAR_VERSION="$(cat "${REPO_DIR}/VERSION" 2>/dev/null || echo "0.1.0-dev")"

# ── Default config ───────────────────────────────────────────────────────────
ANDROID_SRC=""
VARIANT="userdebug"
JOBS="$(nproc)"
CCACHE_SIZE="60G"
KEEP_CHANGES=1

load_config() { [[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}" 2>/dev/null || true; }

save_config() {
    cat > "${CONFIG_FILE}" << EOF
ANDROID_SRC="${ANDROID_SRC}"
VARIANT="${VARIANT}"
JOBS="${JOBS}"
CCACHE_SIZE="${CCACHE_SIZE}"
EOF
    msg_ok "Конфигурация сохранена"
}
