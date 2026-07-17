#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  PulsarOS Build System — Common Functions                                  ║
# ║  Colors, logging, message helpers, run_cmd                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'
BOLD='\033[1m'

# ── Logging ──────────────────────────────────────────────────────────────────
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LOG_DIR="${REPO_DIR}/out/logs"
mkdir -p "${LOG_DIR}" 2>/dev/null || true
LOG_FILE="${LOG_DIR}/build_$(date +%Y%m%d_%H%M%S).log"
_LATEST_LOG="${LOG_DIR}/latest.log"
ln -sf "${LOG_FILE}" "${_LATEST_LOG}" 2>/dev/null || true

_log() {
    local ts
    ts=$(date '+%H:%M:%S')
    echo -e "${ts} $*" | tee -a "${LOG_FILE}" >&2
}

msg_info()  { _log "${CYAN}[INFO]${NC}  $*"; }
msg_ok()    { _log "${GREEN}[OK]${NC}    $*"; }
msg_warn()  { _log "${YELLOW}[WARN]${NC}  $*"; }
msg_error() { _log "${RED}[ERROR]${NC} $*"; }

# Run a command with output visible AND logged in real-time
run_cmd() {
    echo -e "${CYAN}[CMD]${NC}   $*" | tee -a "${LOG_FILE}" >&2
    "$@" 2>&1 | tee -a "${LOG_FILE}"
    return ${PIPESTATUS[0]}
}

# Run a command with output logged only (for noisy commands)
run_quiet() {
    echo -e "${CYAN}[CMD]${NC}   $*" | tee -a "${LOG_FILE}" >&2
    "$@" >> "${LOG_FILE}" 2>&1
    return $?
}

wait_key() { printf "  Нажмите Enter..." >&2; read; }
