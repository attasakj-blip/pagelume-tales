"""Launcher icon: the enormous turnip with sparkles on Pagelume's night indigo.
Run: python3 tools/make_icon.py"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import make_art as art  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), '..')


def draw(size_px, bg=True, scale=1.0):
    S = 1024 * art.SS
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg:
        for y in range(0, S, 6):
            t = y / S
            c = (int(46 + 40 * t), int(35 + 20 * t), int(71 + 60 * t), 255)
            d.rectangle([0, y, S, y + 6], fill=c)
    p = art.Pen(d, 512 - 512 * scale, 512 - 512 * scale, scale)
    art.turnip(p, 512, 650, 230, leaves=0.95)
    for x, y, r in ((250, 280, 40), (790, 330, 32), (720, 160, 22), (300, 760, 22)):
        art.sparkle(p, x, y, r)
    return img.resize((size_px, size_px), Image.LANCZOS)


sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for k, px in sizes.items():
    draw(px).convert('RGB').save(f'{ROOT}/android/app/src/main/res/mipmap-{k}/ic_launcher.png')
draw(1024).convert('RGB').save(f'{ROOT}/assets/icon_1024.png')
ios = f'{ROOT}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
for f in os.listdir(ios):
    if f.endswith('.png'):
        w = Image.open(f'{ios}/{f}').size[0]
        draw(w).convert('RGB').save(f'{ios}/{f}')
print('icons written')
