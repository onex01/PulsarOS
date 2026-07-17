#!/usr/bin/env bash
set -uo pipefail

# Sync PulsarOS overlays into an Android source tree, backing up any
# files that would be overwritten. Writes a manifest in the backup dir
# so rollback is possible. Outputs BACKUP_TS for parent script to capture.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}/.."
ANDROID_SRC="${1:-}" || true
if [[ -z "${ANDROID_SRC}" ]]; then
  echo "Usage: $0 /path/to/android/source" >&2
  exit 2
fi

timestamp() { date -u +%Y%m%dT%H%M%SZ; }
TS="$(timestamp)"
BACKUP_ROOT="${ANDROID_SRC}/.pulsaros_backups/${TS}"
MANIFEST="${BACKUP_ROOT}/manifest.txt"
TOTAL_CHANGES=0

# Список директорий для полного удаления при откате
OVERLAY_DIRS=""

echo "[INFO] Backup root: ${BACKUP_ROOT}"

# Process one source directory
process_overlay() {
  local src="$1" dst="$2"
  local changes_count=0
  local files_list=""
  
  if [[ ! -d "${src}" ]]; then
    echo "[WARN] source ${src} not found, skipping" >&2
    return 0
  fi
  
  # Get list of files that would be synced (dry-run)
  # Filter out rsync metadata lines
  files_list=$(rsync -rl --dry-run --exclude '.git' --exclude '.gitignore' --out-format='%n' "${src}/" "${dst}/" 2>/dev/null | \
    grep -v '^sending incremental file list$' | \
    grep -v '^sent ' | \
    grep -v '^total size' | \
    grep -v '^speedup' | \
    grep -v '^created directory ' | \
    grep -v '^./$' || true)
  
  # Determine if we have changes
  if [[ -n "${files_list}" ]]; then
    changes_count=$(echo "${files_list}" | wc -l)
  fi
  
  # Save destination directory for rollback (for full removal)
  if [[ "${changes_count}" -gt 0 ]]; then
    OVERLAY_DIRS="${OVERLAY_DIRS} ${dst}"
  fi
  
  # Create manifest
  if [[ "${changes_count}" -gt 0 ]]; then
    mkdir -p "${BACKUP_ROOT}"
    echo "backup_timestamp=${TS}" > "${MANIFEST}"
    echo "android_src=${ANDROID_SRC}" >> "${MANIFEST}"
    echo "repo_dir=${REPO_DIR}" >> "${MANIFEST}"
    echo "" >> "${MANIFEST}"
    
    # List all files to be synced as CREATED (we're adding new files)
    while IFS= read -r rel; do
      [[ -z "${rel}" ]] && continue
      echo "CREATED ${rel}" >> "${MANIFEST}"
    done <<< "${files_list}"
    
    echo "[INFO] Performing rsync ${src} → ${dst}"
    rsync -av "${src}/" "${dst}/" --exclude '.git' --exclude '.gitignore'
  fi
  
  TOTAL_CHANGES=$((TOTAL_CHANGES+changes_count))
}

# device overlay
process_overlay "${REPO_DIR}/device/softwinner/zero3" "${ANDROID_SRC}/device/softwinner/zero3"

# vendor overlay
process_overlay "${REPO_DIR}/vendor/pulsaros" "${ANDROID_SRC}/vendor/pulsaros"

# packages/apps
if [[ -d "${REPO_DIR}/packages/apps" ]]; then
  for sub in "${REPO_DIR}/packages/apps"/*; do
    [[ -d "$sub" ]] || continue
    name="$(basename "$sub")"
    process_overlay "$sub" "${ANDROID_SRC}/packages/apps/${name}"
  done
fi

if [[ "${TOTAL_CHANGES}" -gt 0 ]]; then
  echo "" >> "${MANIFEST}"
  echo "Done. To rollback run: ./scripts/rollback_overlays.sh ${ANDROID_SRC} ${TS}" >> "${MANIFEST}"
  echo "Manifest written to ${MANIFEST}"
  echo ""
  echo "[OK] Sync completed (${TOTAL_CHANGES} changes)"
  echo "BACKUP_TS=${TS}"
  
  # Store overlay directories for rollback
  echo "OVERLAY_DIRS:${OVERLAY_DIRS}" >> "${MANIFEST}"
else
  rm -rf "${BACKUP_ROOT}"
  echo ""
  echo "[OK] No changes needed - source already in sync"
fi