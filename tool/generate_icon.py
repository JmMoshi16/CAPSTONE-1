"""Draws the ECOReward app icon and writes every Android launcher size.

Run from the project root:  python tool/generate_icon.py   (needs Pillow)

The mark: a cream leaf inside a mint "cycle" ring on the forest-green brand gradient,
the same palette as lib/core/tokens.dart (AppPalette). Outputs:
  android/app/src/main/res/mipmap-*/ic_launcher.png           legacy icon (Android < 8)
  android/app/src/main/res/drawable-*/ic_launcher_{background,foreground,monochrome}.png
                                                               adaptive layers (Android 8+, themed 13+)
  assets/icons/app_icon.png                                    used by the in-app launch screen
  tool/icon/app_icon.png                                       1024 px master
"""
import math
import os
from PIL import Image, ImageDraw

FOREST_DEEP = (0x1F, 0x3F, 0x27)
FOREST = (0x2F, 0x5D, 0x3A)
FOREST_LIGHT = (0x3E, 0x7A, 0x4C)
MINT = (0x7C, 0xCF, 0xA5)
CREAM = (0xF5, 0xED, 0xE0)

SS = 4            # supersampling factor for smooth edges
N = 1024 * SS     # working canvas


def gradient(size):
    """Diagonal forest gradient, deep at the top-left to lighter at the bottom-right."""
    small = Image.new('RGB', (256, 256))
    px = small.load()
    for y in range(256):
        for x in range(256):
            t = (x + y) / 510
            a, b, u = (FOREST_DEEP, FOREST, t / 0.6) if t < 0.6 else (FOREST, FOREST_LIGHT, (t - 0.6) / 0.4)
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * u) for i in range(3))
    return small.resize((size, size), Image.BICUBIC)


def leaf_points(cx, cy, length, width, angle_deg, steps=90):
    """A leaf as the overlap of two circular arcs (tip to base), rotated by angle_deg."""
    half_l, half_w = length / 2, width / 2
    r = (half_l ** 2 + half_w ** 2) / (2 * half_w)
    # Right edge: an arc of a circle centred left of the axis, from the tip (top) to the base.
    centre_x = half_w - r
    a_tip = math.atan2(-half_l, -centre_x)
    a_base = math.atan2(half_l, -centre_x)
    right = [(centre_x + r * math.cos(a_tip + (a_base - a_tip) * i / steps),
              r * math.sin(a_tip + (a_base - a_tip) * i / steps)) for i in range(steps + 1)]
    # Left edge: the mirror image, walked back from the base to the tip.
    pts = right + [(-x, y) for x, y in reversed(right)]
    th = math.radians(angle_deg)
    return [(cx + x * math.cos(th) - y * math.sin(th), cy + x * math.sin(th) + y * math.cos(th)) for x, y in pts]


def draw_mark(img, scale, colour_leaf=CREAM, colour_rib=FOREST, colour_ring=MINT, mono=False):
    """Draws the ring + leaf centred on img. scale = ring outer radius as a fraction of the canvas."""
    d = ImageDraw.Draw(img)
    w = img.size[0]
    c = w / 2
    ring_r = w * scale
    ring_w = ring_r * 0.13

    # Cycle ring: an open arc with an arrowhead, like a loop that gives back.
    start, end = 120, 400            # degrees, clockwise from 3 o'clock (PIL convention)
    box = [c - ring_r, c - ring_r, c + ring_r, c + ring_r]
    d.arc(box, start, end, fill=colour_ring, width=round(ring_w))
    # round cap at the tail
    ta = math.radians(start)
    mid = ring_r - ring_w / 2
    tx, ty = c + mid * math.cos(ta), c + mid * math.sin(ta)
    d.ellipse([tx - ring_w / 2, ty - ring_w / 2, tx + ring_w / 2, ty + ring_w / 2], fill=colour_ring)
    # arrowhead at the head, pointing along the direction of travel
    ha = math.radians(end)
    hx, hy = c + mid * math.cos(ha), c + mid * math.sin(ha)
    tangent = (-math.sin(ha), math.cos(ha))
    normal = (math.cos(ha), math.sin(ha))
    size = ring_w * 1.9
    tip = (hx + tangent[0] * size * 0.9, hy + tangent[1] * size * 0.9)
    left = (hx + normal[0] * size * 0.75, hy + normal[1] * size * 0.75)
    right = (hx - normal[0] * size * 0.75, hy - normal[1] * size * 0.75)
    d.polygon([tip, left, right], fill=colour_ring)

    # Leaf, tip towards the top-right, with a short curved stem and a midrib.
    leaf_len = ring_r * 1.36
    leaf_w = leaf_len * 0.56
    lc = (c + ring_r * 0.04, c - ring_r * 0.04)
    angle = 45
    d.polygon(leaf_points(lc[0], lc[1], leaf_len, leaf_w, angle), fill=colour_leaf)
    th = math.radians(angle)
    axis = (-math.sin(th), math.cos(th))     # towards the base, after rotation
    side = (math.cos(th), math.sin(th))      # across the leaf

    def at(along, across):                   # a point in leaf coordinates
        return (lc[0] + axis[0] * along + side[0] * across, lc[1] + axis[1] * along + side[1] * across)

    def stroke(points, width, fill):
        d.line(points, fill=fill, width=round(width), joint='curve')
        for x, y in (points[0], points[-1]):
            d.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=fill)

    # Stem: starts inside the leaf so there is no seam, curls slightly as it leaves the base.
    stem = [at(leaf_len * (0.40 + 0.22 * i / 20), -leaf_w * 0.10 * (i / 20) ** 2) for i in range(21)]
    stroke(stem, leaf_w * 0.10, colour_leaf)
    if not mono:
        rib = [at(leaf_len * (0.40 - 0.76 * i / 30), leaf_w * 0.05 * math.sin(math.pi * i / 30)) for i in range(31)]
        stroke(rib, leaf_w * 0.065, colour_rib)


def rounded_mask(size, radius_frac):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=round(size * radius_frac), fill=255)
    return m


def save(img, path, px):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((px, px), Image.LANCZOS).save(path, optimize=True)
    print('wrote', path, px)


def main():
    res = 'android/app/src/main/res'

    # Full icon (legacy launchers, the in-app launch screen and the master).
    full = gradient(N).convert('RGBA')
    draw_mark(full, 0.30)
    full.putalpha(rounded_mask(N, 0.225))
    save(full, 'tool/icon/app_icon.png', 1024)
    save(full, 'assets/icons/app_icon.png', 384)
    for dens, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        save(full, f'{res}/mipmap-{dens}/ic_launcher.png', px)

    # Adaptive layers: 108 dp canvas; launchers mask it and only the central 66 dp is
    # guaranteed visible, so the ring (outer radius 0.27 of the canvas) stays inside it.
    bg = gradient(N)
    fg = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    draw_mark(fg, 0.27)
    mono = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    white = (255, 255, 255)
    draw_mark(mono, 0.27, colour_leaf=white, colour_ring=white, mono=True)
    for dens, px in {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}.items():
        save(bg, f'{res}/drawable-{dens}/ic_launcher_background.png', px)
        save(fg, f'{res}/drawable-{dens}/ic_launcher_foreground.png', px)
        save(mono, f'{res}/drawable-{dens}/ic_launcher_monochrome.png', px)


if __name__ == '__main__':
    main()
