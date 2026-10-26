"""BadNote のアプリアイコンを書き出す(2026-10-27)。

**`skip icon` を使わずに自前で描く理由** —— あのコマンドは
`--shadow 0` を渡しても影が消えず、1024 の書き出しにアルファが残る。
App Store はアルファ付きのアイコンを弾く。

単色面(ブランド色のインディゴ)に、白いシャトル 1 つ。文字なし。
外部ライブラリは使わず、走査線で塗って zlib で PNG にする。
"""
import math, struct, zlib

SIZE = 1024
BG = (0x5C, 0x6B, 0xC0)      # ブランド色(light)。design.md の AccentColor と同じ
FG = (0xFF, 0xFF, 0xFF)
SS = 4                        # 縦方向の分割数(横は解析的に被覆を出す)

# --- 100 単位の設計空間 → 1024px ---
SCALE = 700.0 / 72.0          # モチーフの横幅が canvas の約 62% になる倍率
CX, CY = 512.0, 502.0         # 視覚的な中心はわずかに上

def to_px(x, y):
    return (CX + (x - 50.0) * SCALE, CY + (y - 50.0) * SCALE)

def feather(bx0, bx1, tx0, ty0, tx1, ty1):
    return [(bx0, 58.0), (tx0, ty0), (tx1, ty1), (bx1, 58.0)]

polys = [
    feather(37.0, 41.8, 14.0, 26.00, 26.4, 20.30),
    feather(42.3, 47.1, 28.9, 19.44, 41.3, 16.58),
    feather(47.6, 52.4, 43.8, 16.30, 56.2, 16.30),
    feather(52.9, 57.7, 58.7, 16.58, 71.1, 19.44),
    feather(58.2, 63.0, 73.6, 20.30, 86.0, 26.00),
]

# コルク: 上は角、下は半円
cork = [(37.0, 56.0), (37.0, 71.0)]
for i in range(1, 64):
    t = math.pi + math.pi * i / 64.0
    # y は下向きなので sin を引く。足すとドームが上に膨らんで欠けて見える
    cork.append((50.0 + 13.0 * math.cos(t), 71.0 - 13.0 * math.sin(t)))
cork.append((63.0, 71.0))
cork.append((63.0, 56.0))
polys.append(cork)

polys = [[to_px(x, y) for (x, y) in p] for p in polys]

cover = [[0.0] * SIZE for _ in range(SIZE)]

def add_span(row, x0, x1, w):
    """[x0, x1) を被覆 w で row に足す。端は面積で按分する。"""
    if x1 <= x0:
        return
    x0 = max(0.0, x0); x1 = min(float(SIZE), x1)
    if x1 <= x0:
        return
    i0, i1 = int(x0), int(math.ceil(x1)) - 1
    if i0 == i1:
        row[i0] += (x1 - x0) * w
        return
    row[i0] += (i0 + 1 - x0) * w
    for i in range(i0 + 1, i1):
        row[i] += w
    row[i1] += (x1 - i1) * w

for poly in polys:
    ys = [p[1] for p in poly]
    y_lo, y_hi = max(0, int(min(ys))), min(SIZE - 1, int(math.ceil(max(ys))))
    n = len(poly)
    for py in range(y_lo, y_hi + 1):
        row = cover[py]
        for s in range(SS):
            yc = py + (s + 0.5) / SS
            xs = []
            for i in range(n):
                x1p, y1p = poly[i]
                x2p, y2p = poly[(i + 1) % n]
                if (y1p <= yc < y2p) or (y2p <= yc < y1p):
                    xs.append(x1p + (yc - y1p) * (x2p - x1p) / (y2p - y1p))
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                add_span(row, xs[k], xs[k + 1], 1.0 / SS)

raw = bytearray()
for py in range(SIZE):
    raw.append(0)
    row = cover[py]
    for px in range(SIZE):
        a = row[px]
        a = 0.0 if a < 0.0 else (1.0 if a > 1.0 else a)
        for c in range(3):
            raw.append(int(BG[c] + (FG[c] - BG[c]) * a + 0.5))

def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
       + chunk(b"IEND", b""))

import sys
open(sys.argv[1], "wb").write(png)
print("wrote", sys.argv[1], len(png), "bytes")
