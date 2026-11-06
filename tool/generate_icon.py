"""Builds every brand asset from Crave's official logo (navy line art on yellow). The logo is never redrawn.

Run from the project root:  py tool/generate_icon.py [official-logo.png]   (needs Pillow and NumPy)
Without an argument it rebuilds from the bundled copy (assets/brand/crave_logo_full.webp).

Outputs:
  assets/brand/crave_logo_full.webp     the official logo, pixel for pixel (lossless): splash, sign in, register
  assets/brand/crave_logo.png           its CRAVE lettering as a navy mask: the Rewards tab's "Rewards from" line
  assets/icons/app_icon.png             the cup symbol on a yellow rounded tile: the Home header, 384 px
  tool/icon/app_icon.png                1024 px master of the icon
  android/app/src/main/res/mipmap-*/ic_launcher.png                        legacy icon (Android < 8)
  android/app/src/main/res/drawable-*/ic_launcher_{background,foreground,monochrome}.png   adaptive (8+), themed (13+)
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png                       opaque squares; iOS rounds the corners

The icon is the logo's own steam, cup and saucer (no lettering, unreadable at launcher sizes), in the brand navy
(#142477) on the brand yellow (#FFC914).
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

LOGO = 'assets/brand/crave_logo_full.webp'
YELLOW = (0xFF, 0xC9, 0x14)
NAVY = (0x14, 0x24, 0x77)
WHITE = (0xFF, 0xFF, 0xFF)
# The logo's own ground and ink, measured from the official image.
GROUND = np.array([253.0, 207.0, 9.0])
INK = np.array([11.0, 23.0, 114.0])


def ink_alpha(rgb):
    """How much of each pixel is navy ink (0 ground .. 1 ink), so anti-aliased edges keep their softness."""
    d = INK - GROUND
    return np.clip(((rgb - GROUND) @ d) / (d @ d), 0, 1)


def bands(alpha):
    """Rows holding ink, as (first, last) runs: steam, cup and saucer, CRAVE, BY: SECRET CAFE."""
    rows = (alpha > 0.5).any(1)
    runs, start = [], None
    for y, on in enumerate(rows):
        if on and start is None:
            start = y
        if not on and start is not None:
            runs.append((start, y - 1))
            start = None
    return runs


def cutout(alpha, top, bottom, colour, pad=4):
    """The ink between two rows as a mask in one colour, cropped to its ink plus a small margin."""
    cols = np.nonzero((alpha[top:bottom + 1] > 0.02).any(0))[0]
    a = alpha[top - pad:bottom + pad + 1, cols[0] - pad:cols[-1] + pad + 1]
    img = Image.new('RGBA', (a.shape[1], a.shape[0]), colour + (0,))
    img.putalpha(Image.fromarray(np.round(a * 255).astype(np.uint8)))
    return img


def place(canvas, mark, width_frac):
    """Pastes the mark centred on the canvas, scaled to a fraction of its width (aspect kept)."""
    n = canvas.size[0]
    w = round(n * width_frac)
    h = round(mark.size[1] * w / mark.size[0])
    m = mark.resize((w, h), Image.LANCZOS)
    canvas.alpha_composite(m, ((n - w) // 2, (n - h) // 2))
    return canvas


def rounded(img, radius_frac):
    n = img.size[0]
    mask = Image.new('L', (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n - 1, n - 1], radius=round(n * radius_frac), fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def save(img, path, px=None, rgb=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img if px is None else img.resize((px, px), Image.LANCZOS)
    (out.convert('RGB') if rgb else out).save(path, optimize=True)
    print('wrote', path, out.size[0])


def main(source):
    logo = Image.open(source).convert('RGB')
    if os.path.abspath(source) != os.path.abspath(LOGO):
        logo.save(LOGO, lossless=True, quality=100, method=6)
        print('wrote', LOGO)
    alpha = ink_alpha(np.asarray(logo, dtype=float))
    runs = bands(alpha)
    assert len(runs) == 4, f'expected steam, cup, CRAVE and subtitle bands, found {runs}'
    cup = cutout(alpha, runs[0][0], runs[1][1], NAVY)
    save(cutout(alpha, *runs[2], NAVY, pad=2), 'assets/brand/crave_logo.png')

    n = 1024
    tile = place(Image.new('RGBA', (n, n), YELLOW + (255,)), cup, 0.62)
    save(rounded(tile, 0.225), 'tool/icon/app_icon.png')
    save(rounded(tile, 0.225), 'assets/icons/app_icon.png', 384)

    res = 'android/app/src/main/res'
    for dens, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        save(rounded(tile, 0.225), f'{res}/mipmap-{dens}/ic_launcher.png', px)
    # Adaptive layers: a 108 dp canvas of which only a 66 dp circle is sure to show. The cup's diagonal
    # (0.44 of the width x 1.32) stays inside it.
    bg = Image.new('RGB', (n, n), YELLOW)
    fg = place(Image.new('RGBA', (n, n), (0, 0, 0, 0)), cup, 0.44)
    mono = place(Image.new('RGBA', (n, n), (0, 0, 0, 0)), cutout(alpha, runs[0][0], runs[1][1], WHITE), 0.44)
    for dens, px in {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}.items():
        save(bg, f'{res}/drawable-{dens}/ic_launcher_background.png', px)
        save(fg, f'{res}/drawable-{dens}/ic_launcher_foreground.png', px)
        save(mono, f'{res}/drawable-{dens}/ic_launcher_monochrome.png', px)

    ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for name in sorted(os.listdir(ios)):
        m = re.match(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$', name)
        if m:
            save(tile, f'{ios}/{name}', round(float(m.group(1)) * int(m.group(2))), rgb=True)

    # Self-check: the bundled logo is the source pixel for pixel, and the icons are yellow with a navy cup.
    assert np.array_equal(np.asarray(Image.open(LOGO).convert('RGB')), np.asarray(logo))
    icon = Image.open(f'{ios}/Icon-App-1024x1024@1x.png')
    assert icon.mode == 'RGB' and icon.getpixel((8, 8)) == YELLOW
    assert (np.asarray(icon)[300:700, 300:700] == NAVY).all(2).any(), 'navy cup in the middle'
    assert Image.open(f'{res}/drawable-xxxhdpi/ic_launcher_foreground.png').getpixel((0, 0))[3] == 0


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else LOGO)
