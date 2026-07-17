#!/usr/bin/env bash
# Step 6: Create Firmware Image
# Stock firmware + наш bootlogo + наш Android system
# Stock firmware берётся из img/patch/fex/ (хранилище в репо)
# Заменяем: super.fex (наш Android) + boot-resource.fex (наш bootlogo) + vbmeta*.fex (AVB off)

step_create_image() {
    echo -e "\n${BOLD}═══ Создание образа ═══${NC}\n"

    local IMGREPACKER="${REPO_DIR}/tools/bin/imgrepacker"
    [[ ! -x "${IMGREPACKER}" ]] && { msg_error "imgRePacker не найден"; return 1; }

    local FEX_DIR="${REPO_DIR}/img/patch/fex"
    [[ ! -d "${FEX_DIR}" ]] && { msg_error "Stock firmware не найден: ${FEX_DIR}"; return 1; }

    # ── Find product output ──
    local PRODUCT_OUT=""
    for d in "${ANDROID_SRC}/out/target/product/"*/; do
        [[ -f "${d}boot.img" ]] && PRODUCT_OUT="${d}" && break
    done
    [[ -z "${PRODUCT_OUT}" ]] && { msg_error "Продукт не найден"; return 1; }
    msg_ok "Продукт: $(basename "${PRODUCT_OUT}")"

    # ── 1. Create work directory ──
    local WORK="${REPO_DIR}/out/pack_work"
    rm -rf "${WORK}"
    mkdir -p "${WORK}"

    # ── 2. Copy stock firmware to work ──
    msg_info "Копирование stock firmware..."
    cp "${FEX_DIR}"/*.fex "${WORK}/"

    # ── 3. Copy stock image.cfg ──
    local STOCK_DUMP="${ANDROID_SRC}/../OrangePi_Zero3_Android12_v1.0.img.dump"
    if [[ -d "${STOCK_DUMP}" ]]; then
        cp "${STOCK_DUMP}/image.cfg" "${WORK}/image.cfg"
    else
        # Extract image.cfg from stock
        msg_info "Извлечение image.cfg..."
        local TEMP="${WORK}/.temp_stock"
        mkdir -p "${TEMP}"
        cp "/mnt/BF/OrangePi_Zero3_Android12_v1.0.img" "${TEMP}/stock.img"
        cd "${TEMP}"
        "${IMGREPACKER}" stock.img 2>&1 | tail -2
        cp "${TEMP}/stock.img.dump/image.cfg" "${WORK}/image.cfg"
        rm -rf "${TEMP}"
    fi
    msg_ok "Stock firmware: $(ls "${WORK}"/*.fex 2>/dev/null | wc -l) sections"

    # ── 4. Replace super.fex (наш Android) ──
    msg_info "Замена super.fex..."
    cp "${PRODUCT_OUT}/super.img" "${WORK}/super.fex"
    msg_ok "super.fex ← наш Android ($(du -h "${PRODUCT_OUT}/super.img" | cut -f1))"

    # ── 5. Replace boot-resource.fex (наш bootlogo) ──
    msg_info "Замена boot-resource.fex (наш bootlogo)..."
    python3 << 'PYEOF'
import struct, os

br_path = "${WORK}/boot-resource.fex"
our_logo = "${REPO_DIR}/vendor/pulsaros/boot-logo/bootlogo.bmp"

with open(br_path, 'rb') as f:
    br = bytearray(f.read())
with open(our_logo, 'rb') as f:
    logo = f.read()

bps = 512; spc = 4; cs = bps*spc
data_start = 545*bps; fat1 = bps; fat_size = 256

def get_chain(br, start):
    chain = []; c = start
    while 2 <= c < 0xFFF0:
        chain.append(c)
        val = struct.unpack('<H', br[fat1+c*2:fat1+c*2+2])[0]
        if val == c: break
        c = val
    return chain

chain = get_chain(br, 172)
needed = (len(logo) + cs - 1) // cs

if needed > len(chain):
    used = set(chain)
    free = [i for i in range(2, 65535) if struct.unpack('<H', br[fat1+i*2:fat1+i*2+2])[0] == 0 and i not in used][:needed-len(chain)+10]
    new_c = free[:needed-len(chain)]
    struct.pack_into('<H', br, fat1+chain[-1]*2, new_c[0])
    for i in range(len(new_c)-1):
        struct.pack_into('<H', br, fat1+new_c[i]*2, new_c[i+1])
    struct.pack_into('<H', br, fat1+new_c[-1]*2, 0xFFF8)
    fat2 = (1+2*fat_size)*bps
    br[fat2:fat2+fat_size*bps] = br[fat1:fat1+fat_size*bps]
    chain.extend(new_c)

for i, c in enumerate(chain):
    off = data_start + (c-2)*cs
    s, e = i*cs, min(i*cs+cs, len(logo))
    br[off:off+(e-s)] = logo[s:e]
    if e-s < cs: br[off+(e-s):off+cs] = b'\x00'*(cs-(e-s))

root_dir = (1+2*fat_size)*bps
for i in range(512):
    eo = root_dir + i*32
    n = br[eo:eo+8].decode('ascii','replace').strip()
    x = br[eo+8:eo+11].decode('ascii','replace').strip()
    if n == "BOOTLOGO" and x == "BMP":
        struct.pack_into('<I', br, eo+28, len(logo))
        break

with open(br_path, 'wb') as f:
    f.write(br)
print(f"  boot-resource.fex ← наш bootlogo ({len(logo):,} bytes)")
PYEOF
    msg_ok "boot-resource.fex patched"

    # ── 6. Replace vbmeta*.fex (AVB off) ──
    for v in vbmeta vbmeta_system vbmeta_vendor; do
        if [[ -f "${PRODUCT_OUT}/${v}.img" ]]; then
            cp "${PRODUCT_OUT}/${v}.img" "${WORK}/${v}.fex" 2>/dev/null
            msg_ok "${v}.fex ← AVB off"
        fi
    done

    # ── 7. Repack with imgRePacker ──
    msg_info "Сборка IMAGEWTY..."
    cd "${WORK}"
    "${IMGREPACKER}" stock.img.dump 2>&1 | tail -3

    # imgRePacker creates output as stock.img (overwrites)
    # But we need a different output name
    local DATE=$(date +%Y-%m-%d)
    local OUTPUT="${REPO_DIR}/out/pulsaros-v7.img"

    if [[ -f "${WORK}/stock.img" ]]; then
        cp "${WORK}/stock.img" "${OUTPUT}"
        md5sum "${OUTPUT}" > "${OUTPUT}.md5"
        msg_ok "IMAGEWTY: ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
        msg_ok "MD5: $(awk '{print $1}' "${OUTPUT}.md5")"
    else
        msg_error "Repack не удался"
        rm -rf "${WORK}"
        return 1
    fi

    # ── Summary ──
    echo ""
    msg_info "Stock firmware (boot, boot_package, U-Boot, DTB) + наш bootlogo + наш Android"
    msg_info "Flash: sudo scripts/flash-sdcard.sh ${OUTPUT} /dev/sdX"

    rm -rf "${WORK}"
    return 0
}
