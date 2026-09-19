#!/usr/bin/env python3
"""Generate the starry-night wallpaper. Pure stdlib: zlib + struct write the PNG.

Colours are taken from the Tokyo Night palette so the wallpaper matches the
rest of the desktop. Change SEED for a different sky, W/H for another display.

    ./generate-wallpaper.py > /dev/null && feh wallpapers/starry-night-tokyo.png
"""
import math, os, random, struct, zlib

W, H, SEED = 1920, 1080, 7749
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "wallpapers", "starry-night-tokyo.png")
random.seed(SEED)

STOPS = [(0.00, (0x07, 0x08, 0x0e)),
         (0.38, (0x11, 0x13, 0x1e)),
         (0.70, (0x1a, 0x1b, 0x26)),
         (1.00, (0x25, 0x29, 0x3d))]

STAR_COLS = ([(0xc0, 0xca, 0xf5)] * 5 + [(0xa9, 0xb1, 0xd6)] * 3 +
             [(0x7a, 0xa2, 0xf7)] * 2 +
             [(0x7d, 0xcf, 0xff), (0xbb, 0x9a, 0xf7), (0xe0, 0xaf, 0x68), (0xf7, 0x76, 0x8e)])


def grad(v):
    """Smooth vertical gradient. Interpolating every stop avoids the visible
    seam a branch between two ranges would leave."""
    for i in range(len(STOPS) - 1):
        v0, c0 = STOPS[i]
        v1, c1 = STOPS[i + 1]
        if v <= v1:
            t = (v - v0) / (v1 - v0)
            t = t * t * (3 - 2 * t)
            return tuple(c0[k] + (c1[k] - c0[k]) * t for k in range(3))
    return STOPS[-1][1]


def make_grid(gw, gh):
    """Value-noise grid whose last row/column repeat the first, so sampling
    wraps without a seam."""
    g = [[random.random() for _ in range(gw)] for _ in range(gh)]
    for row in g:
        row.append(row[0])
    g.append(list(g[0]))
    return g


def sample(grid, gw, gh, x, y):
    x -= math.floor(x)
    y -= math.floor(y)
    fx, fy = x * gw, y * gh
    x0, y0 = int(fx), int(fy)
    tx, ty = fx - x0, fy - y0
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    a = grid[y0][x0] + (grid[y0][x0 + 1] - grid[y0][x0]) * tx
    b = grid[y0 + 1][x0] + (grid[y0 + 1][x0 + 1] - grid[y0 + 1][x0]) * tx
    return a + (b - a) * ty


OCT = [(make_grid(g, gh), g, gh, amp)
       for g, gh, amp in ((4, 3, 0.50), (9, 5, 0.27), (19, 11, 0.15), (37, 21, 0.08))]


def fbm(x, y):
    return sum(sample(gr, gw, gh, x, y) * a for gr, gw, gh, a in OCT)


buf = bytearray(W * H * 3)
for y in range(H):
    v = y / (H - 1)
    br, bg, bb = grad(v)
    row = y * W * 3
    for x in range(W):
        u = x / (W - 1)
        d = (u * 0.48 + 0.26) - v                      # diagonal galactic band
        core = math.exp(-(d * d) / 0.0075)
        wing = math.exp(-(d * d) / 0.045)
        dust = 0.55 + 0.45 * fbm(u * 2.2 + 0.3, v * 2.2)
        band = (core * 0.72 + wing * 0.38) * dust
        n = fbm(u * 1.3, v * 1.3) - 0.5
        r, g, b = br + band * 30 + n * 4, bg + band * 33 + n * 4, bb + band * 58 + n * 7
        cx, cy = u - 0.5, v - 0.5
        vig = 1.0 - 0.26 * (cx * cx * 1.1 + cy * cy * 1.3)
        i = row + x * 3
        buf[i] = max(0, min(255, int(r * vig + random.random() * 1.6)))
        buf[i + 1] = max(0, min(255, int(g * vig + random.random() * 1.6)))
        buf[i + 2] = max(0, min(255, int(b * vig + random.random() * 1.6)))


def splat(cx, cy, rad, col, power):
    x0, x1 = max(0, int(cx - rad) - 1), min(W - 1, int(cx + rad) + 1)
    y0, y1 = max(0, int(cy - rad) - 1), min(H - 1, int(cy + rad) + 1)
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            dx, dy = xx - cx, yy - cy
            dd = math.sqrt(dx * dx + dy * dy)
            if dd > rad:
                continue
            f = (1.0 - dd / rad) ** 2 * power
            i = (yy * W + xx) * 3
            for k in range(3):
                buf[i + k] = min(255, int(buf[i + k] + col[k] * f))


# Dense field, concentrated along the band; brightness follows a power law so
# most stars are faint and a few stand out.
for _ in range(9000):
    x, y = random.random() * W, random.random() * H
    u, v = x / W, y / H
    d = (u * 0.48 + 0.26) - v
    if random.random() > 0.22 + 0.78 * math.exp(-(d * d) / 0.040):
        continue
    mag = random.random() ** 2.6
    splat(x, y, 0.75 + mag * 1.9, random.choice(STAR_COLS), 0.45 + mag * 0.55)

# A few showpiece stars with a halo and diffraction spikes.
for _ in range(22):
    x, y = random.random() * W, random.random() * H
    col = random.choice(STAR_COLS)
    splat(x, y, 11 + random.random() * 15, col, 0.10)
    for L in range(1, 13):
        f = (1 - L / 13) ** 2 * 0.22
        for dx, dy in ((L, 0), (-L, 0), (0, L), (0, -L)):
            xx, yy = int(x + dx), int(y + dy)
            if 0 <= xx < W and 0 <= yy < H:
                i = (yy * W + xx) * 3
                for k in range(3):
                    buf[i + k] = min(255, int(buf[i + k] + col[k] * f))

raw = bytearray()
for y in range(H):
    raw.append(0)                                       # filter type 0
    raw += buf[y * W * 3:(y + 1) * W * 3]


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))


png = (b"\x89PNG\r\n\x1a\n" +
       chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) +
       chunk(b"IDAT", zlib.compress(bytes(raw), 9)) +
       chunk(b"IEND", b""))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "wb") as fh:
    fh.write(png)
print(f"wrote {OUT} ({len(png) / 1024 / 1024:.2f} MB)")
