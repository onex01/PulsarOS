#!/usr/bin/env bash
# flash-sdcard.sh — Flash PulsarOS IMAGEWTY to SD card from Linux
# Usage: sudo ./flash-sdcard.sh <image.img> /dev/sdX

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
IMGREPACKER="${REPO}/tools/bin/imgrepacker"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[[ $# -ne 2 ]] && echo "Usage: sudo $0 <image.img> /dev/sdX" && exit 1
IMAGE="$1"; DEVICE="$2"
[[ ! -f "${IMAGE}" ]] && err "Image not found: ${IMAGE}"
[[ ! -b "${DEVICE}" ]] && err "Device not found: ${DEVICE}"

echo "═══ PulsarOS Linux Flasher ═══"
echo "Image: ${IMAGE} ($(du -h "${IMAGE}" | cut -f1))"
echo "Device: ${DEVICE}"
echo -e "${RED}WARNING: DESTROYS ALL DATA on ${DEVICE}!${NC}"
read -p "Continue? (y/N): " CONFIRM
[[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]] && exit 0

# ── Step 1: Extract IMAGEWTY ──
WORK="/tmp/pulsaros_flash_$$"
mkdir -p "${WORK}"
cp "${IMAGE}" "${WORK}/image.img"
cd "${WORK}"
"${IMGREPACKER}" image.img 2>&1 | tail -3
DUMP="${WORK}/image.img.dump"
[[ -d "${DUMP}" ]] || err "Extraction failed"
ok "Extracted $(ls "${DUMP}"/*.fex 2>/dev/null | wc -l) sections"

# ── Step 2: Unmount ──
for part in "${DEVICE}"*; do umount "${part}" 2>/dev/null || true; done

# ── Step 3: Write boot0 (Allwinner Boot ROM) ──
dd if="${DUMP}/boot0_sdcard.fex" of="${DEVICE}" bs=512 seek=16 conv=notrunc 2>/dev/null
ok "boot0 → sector 16"

# ── Step 4: Write boot_package (U-Boot + DTB) ──
dd if="${DUMP}/boot_package.fex" of="${DEVICE}" bs=512 seek=32800 conv=notrunc 2>/dev/null
ok "boot_package → sector 32800"

# ── Step 5: Create GPT from sys_partition.fex ──
wipefs -a "${DEVICE}" 2>/dev/null
sgdisk -Z "${DEVICE}" 2>/dev/null || true
sgdisk -o "${DEVICE}" 2>/dev/null

echo "── Creating GPT partitions ──"

# Parse sys_partition.fex and create GPT
python3 - "${DUMP}" "${DEVICE}" << 'PYEOF'
import sys, subprocess, os

dump = sys.argv[1]
device = sys.argv[2]

with open(os.path.join(dump, "sys_partition.fex")) as f:
    content = f.read()

partitions = []
current = {}
for line in content.split('\n'):
    line = line.strip()
    if line.startswith('[partition]'):
        if current.get('name') and current.get('size'):
            partitions.append(current)
        current = {}
    elif '=' in line and not line.startswith(';') and not line.startswith('['):
        k, v = line.split('=', 1)
        k, v = k.strip(), v.strip().strip('"')
        if k == 'name': current['name'] = v
        elif k == 'size':
            try: current['size'] = int(v)
            except:
                if v.endswith('M'): current['size'] = int(v[:-1]) * 2048
                elif v.endswith('K'): current['size'] = int(v[:-1]) * 2
                else: current['size'] = 0
        elif k == 'downloadfile': current['file'] = v
if current.get('name') and current.get('size'):
    partitions.append(current)

for p in partitions:
    size = p['size']
    name = p['name']
    if size <= 0: continue
    cmd = f'sgdisk -n 0:0:+{size}s -t 0:8300 -c 0:"{name}" {device}'
    subprocess.run(cmd.split(), capture_output=True)

result = subprocess.run(f'sgdisk -p {device}'.split(), capture_output=True, text=True)
count = len([l for l in result.stdout.split('\n') if l.strip().startswith('  ')])
print(f"  Created {count} partitions")
PYEOF

ok "GPT created"

# ── Step 6: Write partition images ──
echo "── Writing partitions ──"

python3 - "${DUMP}" "${DEVICE}" << 'PYEOF2'
import sys, subprocess, os

dump = sys.argv[1]
device = sys.argv[2]

FILE_MAP = {
    "boot-resource": "boot-resource.fex",
    "env": "env.fex",
    "boot": "boot.fex",
    "vendor_boot": "vendor_boot.fex",
    "super": "super.fex",
    "misc": "misc.fex",
    "vbmeta": "vbmeta.fex",
    "vbmeta_system": "vbmeta_system.fex",
    "vbmeta_vendor": "vbmeta_vendor.fex",
    "dtbo": "dtbo.fex",
}

result = subprocess.run(f'sgdisk -p {device}'.split(), capture_output=True, text=True)
partitions = []
for line in result.stdout.split('\n'):
    parts = line.strip().split()
    if len(parts) >= 5 and parts[0].isdigit():
        num = int(parts[0])
        start = int(parts[1])
        end = int(parts[2])
        name = parts[4] if len(parts) > 4 else ""
        partitions.append((num, name, start, end - start + 1))

for num, name, start, size in partitions:
    base = name.replace('_a', '').replace('_b', '')
    fex_file = FILE_MAP.get(base)
    if not fex_file: continue

    fex_path = os.path.join(dump, fex_file)
    if not os.path.exists(fex_path): continue

    fex_size = os.path.getsize(fex_path)
    max_bytes = size * 512

    if fex_size > max_bytes:
        print(f"  ⚠️  {name}: {fex_file} too large ({fex_size} > {max_bytes})")
        continue

    subprocess.run(
        ['dd', f'if={fex_path}', f'of={device}', 'bs=512', f'seek={start}', 'conv=notrunc'],
        capture_output=True
    )
    mb = fex_size / (1024*1024)
    print(f"  ✅ {name:25s} ← {fex_file} ({mb:.1f}MB)")
PYEOF2

# ── Step 7: Sync ──
sync
rm -rf "${WORK}"

echo ""
echo "═══ Flash complete! ═══"
echo "Insert SD card into Orange Pi Zero 3 and power on."
