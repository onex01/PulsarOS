#!/usr/bin/env bash
set -euo pipefail

# Sync PulsarOS overlays into an Android source tree, backing up any
# files that would be overwritten. Writes a manifest in the backup dir
# so rollback is possible.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}/.."
ANDROID_SRC="${1:-}" || true
if [[ -z "${ANDROID_SRC}" ]]; then
  echo "Usage: $0 /path/to/android/source"
  exit 2
fi

timestamp() { date -u +%Y%m%dT%H%M%SZ; }
TS="$(timestamp)"
BACKUP_ROOT="${ANDROID_SRC}/.pulsaros_backups/${TS}"
MANIFEST="${BACKUP_ROOT}/manifest.txt"

mkdir -p "${BACKUP_ROOT}"
echo "backup_timestamp=${TS}" > "${MANIFEST}"
echo "android_src=${ANDROID_SRC}" >> "${MANIFEST}"
echo "repo_dir=${REPO_DIR}" >> "${MANIFEST}"
echo "" >> "${MANIFEST}"

rsync_dry_list() {
  local src="$1" dst="$2"
  rsync -av --dry-run --exclude '.git' --exclude '.gitignore' --out-format='%n' "${src}/" "${dst}/"
}

backup_and_sync() {
  local src="$1" dst="$2"
  if [[ ! -d "${src}" ]]; then
    echo "[WARN] source ${src} not found, skipping"
    return 0
  fi
  mkdir -p "${dst}"

  echo "[INFO] Dry-run to detect changes for ${src} → ${dst}"
  local rel
  while IFS= read -r rel; do
    [[ -z "${rel}" ]] && continue
    # target path for this item
    local target="${dst}/${rel}"
    if [[ -e "${target}" ]]; then
      mkdir -p "$(dirname "${BACKUP_ROOT}/${rel}")"
      cp -a "${target}" "${BACKUP_ROOT}/${rel}"
      echo "BACKED_UP ${rel}" >> "${MANIFEST}"
    else
      echo "CREATED ${rel}" >> "${MANIFEST}"
    fi
  done < <(rsync_dry_list "${src}" "${dst}")

  echo "[INFO] Performing rsync ${src} → ${dst}"
  rsync -av "${src}/" "${dst}/" --exclude '.git' --exclude '.gitignore'
}

echo "[INFO] Backup root: ${BACKUP_ROOT}"

# device overlay
backup_and_sync "${REPO_DIR}/device/softwinner/zero3" "${ANDROID_SRC}/device/softwinner/zero3"

# vendor overlay
backup_and_sync "${REPO_DIR}/vendor/pulsaros" "${ANDROID_SRC}/vendor/pulsaros"

# packages/apps
if [[ -d "${REPO_DIR}/packages/apps" ]]; then
  for sub in "${REPO_DIR}/packages/apps"/*; do
    [[ -d "$sub" ]] || continue
    name="$(basename "$sub")"
    backup_and_sync "$sub" "${ANDROID_SRC}/packages/apps/${name}"
  done
fi

echo "" >> "${MANIFEST}"
echo "Done. To rollback run: ./scripts/rollback_overlays.sh ${ANDROID_SRC} ${TS}" >> "${MANIFEST}"
echo "Manifest written to ${MANIFEST}"
echo ""
echo "[OK] Sync completed"
