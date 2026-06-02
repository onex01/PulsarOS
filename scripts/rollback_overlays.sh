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
  echo "No backups found in ${BACKUP_BASE}"
  exit 1
fi

if [[ -n "${TS_ARG}" ]]; then
  BACKUP_DIR="${BACKUP_BASE}/${TS_ARG}"
else
  # pick latest
  BACKUP_DIR="$(ls -1d ${BACKUP_BASE}/* 2>/dev/null | tail -n1 || true)"
fi

if [[ -z "${BACKUP_DIR}" || ! -d "${BACKUP_DIR}" ]]; then
  echo "Backup directory not found: ${BACKUP_DIR}" >&2
  exit 1
fi

MANIFEST="${BACKUP_DIR}/manifest.txt"
if [[ ! -f "${MANIFEST}" ]]; then
  echo "Manifest not found in backup: ${MANIFEST}" >&2
  exit 1
fi

echo "[INFO] Rolling back using backup: ${BACKUP_DIR}"

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
