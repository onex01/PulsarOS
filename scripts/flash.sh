#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

IMG="${1:-}"
DEV="${2:-}"

if [[ -z "$IMG" || -z "$DEV" ]]; then
    echo "Usage: $0 <image.img> <device>"
    echo "Example: $0 out/target/product/zero3/pulsaros.img /dev/sdX"
    exit 1
fi

if [[ ! -b "$DEV" ]]; then
    echo "Error: $DEV is not a block device"
    exit 1
fi

echo "⚠️  This will ERASE all data on $DEV"
read -p "Continue? [y/N] " -r
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

sudo dd if="$IMG" of="$DEV" bs=4M status=progress conv=fsync
sync
echo "✓ Flash complete"