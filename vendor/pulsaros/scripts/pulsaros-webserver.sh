#!/system/bin/sh
# pulsaros-webserver.sh — Simple HTTP file server for LAN access
# Port 8080, serves /storage/emulated/0/PulsarOS/ and /sdcard/

TAG="PulsarOS"
PORT=8080
ROOT="/storage/emulated/0"

# Check if busybox httpd is available
if ! command -v httpd >/dev/null 2>&1; then
    log -t "${TAG}" "busybox httpd not found, trying toybox"
    if ! command -v toybox >/dev/null 2>&1; then
        log -t "${TAG}" "No HTTP server available"
        exit 1
    fi
fi

# Create PulsarOS directory if not exists
mkdir -p "${ROOT}/PulsarOS"/{roms,video,music,pictures,other}

# Start HTTP server on all interfaces
log -t "${TAG}" "Starting web file server on port ${PORT}"
log -t "${TAG}" "Access: http://$(ip route get 1 | head -1 | awk '{print $7}'):${PORT}"

if command -v httpd >/dev/null 2>&1; then
    # busybox httpd
    httpd -p "${PORT}" -h "${ROOT}" -r "${ROOT}" 2>/dev/null
elif command -v python3 >/dev/null 2>&1; then
    # Python SimpleHTTPServer fallback
    cd "${ROOT}" && python3 -m http.server "${PORT}" 2>/dev/null
else
    log -t "${TAG}" "No suitable HTTP server found"
    exit 1
fi
