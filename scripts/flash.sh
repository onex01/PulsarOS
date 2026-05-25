#!/usr/bin/env bash
# =============================================================================
# PulsarOS — Flash Script
# Записывает образ PulsarOS на SD-карту через dd (RAW формат)
#
# Использование:
#   sudo ./scripts/flash.sh <образ.img> <устройство>
#
# Примеры:
#   sudo ./scripts/flash.sh out/PulsarOS-0.1.0-debug-20250101.img /dev/sdb
#   sudo ./scripts/flash.sh out/PulsarOS-0.1.0-debug-20250101.img /dev/mmcblk0
#
# ВНИМАНИЕ: Все данные на целевом устройстве будут уничтожены!
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[flash]${NC} $*"; }
success() { echo -e "${GREEN}[flash]${NC} ✓ $*"; }
warn()    { echo -e "${YELLOW}[flash]${NC} ⚠ $*"; }
die()     { echo -e "${RED}[flash]${NC} ✗ $*" >&2; exit 1; }

IMG="${1:-}"
DEV="${2:-}"

# ── Проверки ──────────────────────────────────────────────────────────────────
[[ -n "$IMG" ]] || die "Укажи образ: sudo ./scripts/flash.sh <образ.img> <устройство>"
[[ -n "$DEV" ]] || die "Укажи устройство: sudo ./scripts/flash.sh <образ.img> /dev/sdX"
[[ -f "$IMG" ]] || die "Файл образа не найден: $IMG"
[[ -b "$DEV" ]] || die "Устройство не существует: $DEV"
[[ $EUID -eq 0 ]]  || die "Запусти с sudo: sudo ./scripts/flash.sh $IMG $DEV"

# Не дать записать на системный диск
ROOT_DEV="$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')"
if [[ "$DEV" == "$ROOT_DEV"* ]]; then
    die "Нельзя записывать на системный диск ($ROOT_DEV)!"
fi

# ── Информация ────────────────────────────────────────────────────────────────
IMG_SIZE=$(du -sh "$IMG" | cut -f1)
IMG_SHA=$(cut -d' ' -f1 "${IMG}.sha256" 2>/dev/null || echo "нет файла .sha256")
DEV_MODEL=$(cat "/sys/block/$(basename "$DEV")/device/model" 2>/dev/null | xargs || echo "неизвестно")
DEV_SIZE=$(lsblk -dno SIZE "$DEV" 2>/dev/null || echo "неизвестно")

echo ""
echo -e "${BOLD}  PulsarOS Flash Tool${NC}"
echo ""
echo -e "  Образ    : ${CYAN}$IMG${NC}"
echo -e "  Размер   : $IMG_SIZE"
echo -e "  SHA256   : $IMG_SHA"
echo -e "  Устройство: ${YELLOW}$DEV${NC}"
echo -e "  Модель   : $DEV_MODEL"
echo -e "  Объём    : $DEV_SIZE"
echo ""
echo -e "${RED}${BOLD}  ВНИМАНИЕ! ВСЕ ДАННЫЕ НА $DEV БУДУТ УНИЧТОЖЕНЫ!${NC}"
echo ""
read -rp "  Продолжить? Введи 'yes' для подтверждения: " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { info "Отменено."; exit 0; }
echo ""

# ── Отмонтируем разделы ───────────────────────────────────────────────────────
info "Отмонтирую разделы $DEV..."
for part in "${DEV}"?*; do
    if mountpoint -q "$part" 2>/dev/null; then
        umount "$part" && info "  Отмонтирован: $part"
    fi
done

# ── Запись образа ─────────────────────────────────────────────────────────────
info "Записываю образ (это займёт несколько минут)..."

# pv для прогресс-бара если установлен, иначе dd с status=progress
if command -v pv &>/dev/null; then
    pv "$IMG" | dd of="$DEV" bs=4M conv=fsync oflag=direct
else
    dd if="$IMG" of="$DEV" bs=4M conv=fsync oflag=direct status=progress
fi

# ── Синхронизация ──────────────────────────────────────────────────────────────
info "Синхронизация..."
sync

success "Запись завершена!"
echo ""
echo -e "  SD-карта $DEV готова к установке в Orange Pi Zero 3."
echo -e "  Вставь карту и подай питание — PulsarOS запустится автоматически."
echo ""
