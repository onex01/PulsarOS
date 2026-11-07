#!/usr/bin/env python3
"""sparse.py — convert Android sparse images to raw and back.

super.fex in the Orange Pi Android image is a sparse image (magic 0xed26ff3a),
so it has to be expanded before the logical partitions inside it can be read.

Usage:
    python3 sparse.py info    <sparse.img>
    python3 sparse.py unsparse <sparse.img> <raw.img>
"""

import struct
import sys

SPARSE_MAGIC = 0xED26FF3A
CHUNK_RAW = 0xCAC1
CHUNK_FILL = 0xCAC2
CHUNK_DONT_CARE = 0xCAC3
CHUNK_CRC32 = 0xCAC4


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
        hdr = SparseHeader(f.read(28))
        f.seek(hdr.file_hdr_sz)
        written = 0
        chunks = 0
        with open(dst, "wb") as out:
            while chunks < hdr.total_chunks:
                raw = f.read(12)
                if len(raw) < 12:
                    raise ValueError(f"truncated chunk header after {chunks} chunks")
                ctype, _, chunk_sz, total_sz = struct.unpack("<HHII", raw)
                chunks += 1
                payload = total_sz - hdr.chunk_hdr_sz

                # chunk_sz counts blocks, not bytes.
                nbytes = chunk_sz * hdr.blk_sz

                if ctype == CHUNK_RAW:
                    data = f.read(payload)
                    if len(data) != payload:
                        raise ValueError("truncated raw chunk")
                    out.write(data)
                    written += len(data)
                elif ctype == CHUNK_FILL:
                    fill = f.read(4)
                    out.write(fill * (nbytes // 4))
                    written += nbytes
                elif ctype == CHUNK_DONT_CARE:
                    out.write(b"\x00" * nbytes)
                    written += nbytes
                elif ctype == CHUNK_CRC32:
                    f.read(payload)
                else:
                    raise ValueError(f"unknown chunk type 0x{ctype:04x}")
        return written, hdr


def cmd_info(path):
    with open(path, "rb") as f:
        hdr = SparseHeader(f.read(28))
    print(f"sparse version : {hdr.major}.{hdr.minor}")
    print(f"block size     : {hdr.blk_sz}")
    print(f"total blocks   : {hdr.total_blks:,}")
    print(f"total chunks   : {hdr.total_chunks:,}")
    print(f"raw size       : {hdr.total_blks * hdr.blk_sz:,} bytes "
          f"({hdr.total_blks * hdr.blk_sz / 1024 / 1024:.1f} MiB)")
    return 0


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "info":
        return cmd_info(sys.argv[2])
    if cmd == "unsparse":
        written, hdr = unsparse(sys.argv[2], sys.argv[3])
        expected = hdr.total_blks * hdr.blk_sz
        status = "OK" if written == expected else f"MISMATCH (expected {expected:,})"
        print(f"unsparsed {sys.argv[2]} -> {sys.argv[3]}: {written:,} bytes  [{status}]")
        return 0 if written == expected else 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())