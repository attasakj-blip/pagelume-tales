"""Launcher icons from tools/src/icon_source.png (the artwork the owner chose).
Run: python3 tools/make_icon.py"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), '..')
TOP, BOTTOM = (22, 118, 218), (5, 54, 122)


def art():
    """The artwork cropped to its rounded square, with the white corners clear."""
    im = Image.open(f'{ROOT}/tools/src/icon_source.png').convert('RGBA')
    px = im.load()
    w, h = im.size
    # Trim the white margin.
    xs = [x for x in range(w) if any(sum(px[x, y][:3]) < 720 for y in range(0, h, 7))]
    ys = [y for y in range(h) if any(sum(px[x, y][:3]) < 720 for x in range(0, w, 7))]
    im = im.crop((xs[0], ys[0], xs[-1] + 1, ys[-1] + 1))
    side = max(im.size)
    im = im.resize((side, side), Image.LANCZOS)
    # Clear the white outside the rounded corners.
    for corner in ((0, 0), (side - 1, 0), (0, side - 1), (side - 1, side - 1)):
        ImageDraw.floodfill(im, corner, (0, 0, 0, 0), thresh=40)
    return im


def gradient(size):
    g = Image.new('RGBA', (size, size))
    d = ImageDraw.Draw(g)
    for y in range(size):
        t = y / max(1, size - 1)
        d.line([(0, y), (size, y)], fill=tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)) + (255,))
    return g


def full(size, a):
    """Square icon with no transparency (legacy Android, iOS, store)."""
    out = gradient(size)
    out.alpha_composite(a.resize((size, size), Image.LANCZOS))
    return out.convert('RGB')


def main():
    a = art()
    legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    res = f'{ROOT}/android/app/src/main/res'
    for k, px in legacy.items():
        full(px, a).save(f'{res}/mipmap-{k}/ic_launcher.png')
        # Adaptive icon layers are 108dp; the launcher shows about the middle 72dp.
        layer = round(px * 108 / 48)
        fg = Image.new('RGBA', (layer, layer), (0, 0, 0, 0))
        inner = round(layer * 0.76)
        off = (layer - inner) // 2
        fg.alpha_composite(a.resize((inner, inner), Image.LANCZOS), (off, off))
        fg.save(f'{res}/mipmap-{k}/ic_launcher_foreground.png')
        gradient(layer).convert('RGB').save(f'{res}/mipmap-{k}/ic_launcher_background.png')
    os.makedirs(f'{res}/mipmap-anydpi-v26', exist_ok=True)
    with open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    full(1024, a).save(f'{ROOT}/assets/icon_1024.png')
    full(512, a).save(f'{ROOT}/assets/icon_512.png')
    ios = f'{ROOT}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for name in os.listdir(ios):
        if name.endswith('.png'):
            full(Image.open(f'{ios}/{name}').size[0], a).save(f'{ios}/{name}')
    print('icons written')


if __name__ == '__main__':
    main()
