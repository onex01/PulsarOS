#!/usr/bin/env bash
set -euo pipefail

# Rollback PulsarOS overlays from a previous backup created by
# scripts/sync_and_backup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}/.."
ANDROID_SRC="${1:-}" || true
TS_ARG="${2:-}" || true

if [[ -z "${ANDROID_SRC}" ]]; then
  echo "Usage: $0 /path/to/android/source [backup-timestamp]"
  exit 2
fi

BACKUP_BASE="${ANDROID_SRC}/.pulsaros_backups"
if [[ ! -d "${BACKUP_BASE}" ]]; then
  echo "[INFO] No backups found in ${BACKUP_BASE} - nothing to rollback"
  exit 0
fi

if [[ -n "${TS_ARG}" ]]; then
  BACKUP_DIR="${BACKUP_BASE}/${TS_ARG}"
else
  # pick latest
  BACKUP_DIR="$(ls -1d ${BACKUP_BASE}/* 2>/dev/null | tail -n1 || true)"
fi

if [[ -z "${BACKUP_DIR}" || ! -d "${BACKUP_DIR}" ]]; then
  echo "[INFO] No backup directory found: ${BACKUP_DIR:-none} - nothing to rollback"
  exit 0
fi

MANIFEST="${BACKUP_DIR}/manifest.txt"
if [[ ! -f "${MANIFEST}" ]]; then
  echo "[INFO] Manifest not found in backup: ${MANIFEST} - nothing to rollback"
  exit 0
fi

# Check if there's anything to rollback
if ! grep -qE '^(BACKED_UP|CREATED) ' "${MANIFEST}" 2>/dev/null; then
  echo "[INFO] No entries in backup manifest - nothing to rollback"
  rmdir "${BACKUP_DIR}" 2>/dev/null || true
  exit 0
fi

echo "[INFO] Rolling back using backup: ${BACKUP_DIR}"

# Check for OVERLAY_DIRS to remove entire directories
if grep -q "^OVERLAY_DIRS:" "${MANIFEST}" 2>/dev/null; then
  while IFS= read -r dir; do
    [[ -z "${dir}" ]] && continue
    if [[ -d "${dir}" ]]; then
      rm -rf "${dir}"
      echo "REMOVED overlay dir: ${dir}"
    else
      echo "NOT FOUND overlay dir: ${dir}"
    fi
  done < <(grep "^OVERLAY_DIRS:" "${MANIFEST}" | cut -d: -f2- | tr ' ' '\n' | grep -v '^$')
  echo "[OK] Rollback finished"
  rmdir "${BACKUP_DIR}" 2>/dev/null || true
  exit 0
fi

# Legacy rollback for BACKED_UP/CREATED entries
while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  case "${line}" in
    BACKED_UP\ *)
      rel="${line#BACKED_UP }"
      src="${BACKUP_DIR}/${rel}"
      dst="${ANDROID_SRC}/${rel}"
      if [[ -e "${src}" ]]; then
        mkdir -p "$(dirname "${dst}")"
        cp -a "${src}" "${dst}"
        echo "RESTORED ${rel}"
      else
        echo "[WARN] backup file missing: ${src}"
      fi
      ;;
    CREATED\ *)
      rel="${line#CREATED }"
      tgt="${ANDROID_SRC}/${rel}"
      if [[ -e "${tgt}" ]]; then
        rm -rf "${tgt}"
        echo "REMOVED created ${rel}"
      else
        echo "NOT FOUND (created) ${rel}"
      fi
      ;;
    *)
      ;;
  esac
done < <(grep -E '^(BACKED_UP|CREATED) ' "${MANIFEST}" || true)

echo "[OK] Rollback finished"
