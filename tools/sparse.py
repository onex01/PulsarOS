#!/usr/bin/env python3
"""sparse.py — Android sparse image conversion.

super.fex in the Orange Pi Android image is a sparse image (magic 0xed26ff3a),
so it has to be expanded before the logical partitions inside it can be read,
and re-compressed before it goes back into the firmware.

Usage:
    python3 sparse.py info      <sparse.img>
    python3 sparse.py unsparse  <sparse.img> <raw.img>
    python3 sparse.py mk        <raw.img> <sparse.img>
"""

import os
import struct
import sys

SPARSE_MAGIC = 0xED26FF3A
CHUNK_RAW = 0xCAC1
CHUNK_FILL = 0xCAC2
CHUNK_DONT_CARE = 0xCAC3
CHUNK_CRC32 = 0xCAC4
HEADER_SIZE = 28
CHUNK_HEADER_SIZE = 12


class SparseHeader:
    def __init__(self, buf):
        (magic, major, minor, file_hdr_sz, chunk_hdr_sz,
         blk_sz, total_blks, total_chunks, checksum) = struct.unpack_from("<IHHHHIIII", buf, 0)
        if magic != SPARSE_MAGIC:
            raise ValueError("not an Android sparse image")
        self.major = major
        self.minor = minor
        self.file_hdr_sz = file_hdr_sz
        self.chunk_hdr_sz = chunk_hdr_sz
        self.blk_sz = blk_sz
        self.total_blks = total_blks
        self.total_chunks = total_chunks
        self.checksum = checksum


def unsparse(src, dst):
    with open(src, "rb") as f:
        hdr = SparseHeader(f.read(HEADER_SIZE))
        f.seek(hdr.file_hdr_sz)
        written = 0
        chunks = 0
        with open(dst, "wb") as out:
            while chunks < hdr.total_chunks:
                raw = f.read(CHUNK_HEADER_SIZE)
                if len(raw) < CHUNK_HEADER_SIZE:
                    raise ValueError(f"truncated chunk header after {chunks} chunks")
                ctype, _, chunk_sz, total_sz = struct.unpack("<HHII", raw)
                chunks += 1
                payload = total_sz - hdr.chunk_hdr_sz
                # chunk_sz counts blocks, not bytes.
                nbytes = chunk_sz * hdr.blk_sz

                if ctype == CHUNK_RAW:
                    left = payload
                    while left:
                        data = f.read(min(left, 8 << 20))
                        if not data:
                            raise ValueError("truncated raw chunk")
                        out.write(data)
                        left -= len(data)
                    written += payload
                elif ctype == CHUNK_FILL:
                    fill = f.read(4)
                    block = fill * (hdr.blk_sz // 4)
                    for _ in range(chunk_sz):
                        out.write(block)
                    written += nbytes
                elif ctype == CHUNK_DONT_CARE:
                    zero = b"\x00" * hdr.blk_sz
                    for _ in range(chunk_sz):
                        out.write(zero)
                    written += nbytes
                elif ctype == CHUNK_CRC32:
                    f.read(payload)
                else:
                    raise ValueError(f"unknown chunk type 0x{ctype:04x}")
        return written, hdr


def mksparse(src, dst, blk_sz=4096):
    """Wrap a raw image in the sparse format.

    Runs of zero blocks become DONT_CARE chunks; everything else is RAW. A
    super image is mostly unused space, so this keeps the firmware small.
    """
    total = os.path.getsize(src)
    if total % blk_sz:
        raise ValueError(f"{src}: size {total} is not a multiple of {blk_sz}")
    total_blks = total // blk_sz

    # First pass: classify blocks so the chunk count is known up front.
    chunks = []          # (type, nblocks)
    zero = b"\x00" * blk_sz
    with open(src, "rb") as f:
        i = 0
        while i < total_blks:
            block = f.read(blk_sz)
            if block == zero:
                j = i + 1
                while j < total_blks:
                    nb = f.read(blk_sz)
                    if nb != zero:
                        f.seek(-blk_sz, os.SEEK_CUR)
                        break
                    j += 1
                chunks.append((CHUNK_DONT_CARE, j - i))
                i = j
            else:
                j = i + 1
                while j < total_blks:
                    nb = f.read(blk_sz)
                    if nb == zero:
                        f.seek(-blk_sz, os.SEEK_CUR)
                        break
                    j += 1
                chunks.append((CHUNK_RAW, j - i))
                i = j

    # Second pass: write headers interleaved with payloads.
    with open(src, "rb") as f, open(dst, "wb") as out:
        out.write(struct.pack("<IHHHHIIII", SPARSE_MAGIC, 1, 0,
                              HEADER_SIZE, CHUNK_HEADER_SIZE,
                              blk_sz, total_blks, len(chunks), 0))
        for ctype, nblk in chunks:
            if ctype == CHUNK_RAW:
                total_sz = CHUNK_HEADER_SIZE + nblk * blk_sz
            else:
                total_sz = CHUNK_HEADER_SIZE
            out.write(struct.pack("<HHII", ctype, 0, nblk, total_sz))
            if ctype == CHUNK_RAW:
                left = nblk * blk_sz
                while left:
                    data = f.read(min(left, 8 << 20))
                    if not data:
                        raise ValueError("unexpected end of input")
                    out.write(data)
                    left -= len(data)
            else:
                # DONT_CARE emits no payload, but the input still has to move
                # past those blocks or everything after it is misaligned.
                f.seek(nblk * blk_sz, os.SEEK_CUR)
    return os.path.getsize(dst), total_blks, len(chunks)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cmd = sys.argv[1]

    if cmd == "info":
        with open(sys.argv[2], "rb") as f:
            hdr = SparseHeader(f.read(HEADER_SIZE))
        print(f"sparse version : {hdr.major}.{hdr.minor}")
        print(f"block size     : {hdr.blk_sz}")
        print(f"total blocks   : {hdr.total_blks:,}")
        print(f"total chunks   : {hdr.total_chunks:,}")
        print(f"raw size       : {hdr.total_blks * hdr.blk_sz:,} bytes "
              f"({hdr.total_blks * hdr.blk_sz / 1024 / 1024:.1f} MiB)")
        return 0

    if cmd == "unsparse":
        written, hdr = unsparse(sys.argv[2], sys.argv[3])
        expected = hdr.total_blks * hdr.blk_sz
        status = "OK" if written == expected else f"MISMATCH (expected {expected:,})"
        print(f"unsparsed -> {sys.argv[3]}: {written:,} bytes  [{status}]")
        return 0 if written == expected else 1

    if cmd == "mk":
        size, nblks, nchunks = mksparse(sys.argv[2], sys.argv[3])
        print(f"sparsed -> {sys.argv[3]}: {size:,} bytes, "
              f"{nblks:,} blocks in {nchunks:,} chunks")
        return 0

    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())