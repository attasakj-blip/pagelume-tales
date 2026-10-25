"""Turns the owner's picture files (tools/src/turnip/upload_NN.png) into the
book's page pictures assets/stories/turnip/pNN.png, all one shape.

Each entry: page -> (upload number, crop box in that file, how to fit).
fit 'cover' fills the page (cropping), 'contain' shows the whole picture on a
soft blurred copy of itself. A (fx, fy) focus picks which part a cover keeps.
Run: python3 tools/prepare_pictures.py
"""
import os

from PIL import Image, ImageFilter, ImageEnhance

ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = f'{ROOT}/tools/src/turnip'
OUT = f'{ROOT}/assets/stories/turnip'
W = 1200
ASPECT = 0.82  # page height / width; keep in step with story.json pageAspect
H = round(W * ASPECT)

PAGES = {
    0: (3, (20, 12, 248, 200), 'cover', None),     # cover: the enormous turnip
    1: (1, (20, 12, 248, 200), 'cover', None),     # planting the seed
    2: (2, (20, 12, 218, 200), 'cover', None),     # watering
    3: (3, (20, 12, 248, 200), 'cover', None),     # the enormous turnip
    4: (5, (20, 12, 218, 192), 'cover', None),     # grandma helps
    5: (6, (20, 12, 248, 190), 'cover', None),     # granddaughter helps
    6: (7, (20, 10, 256, 170), 'cover', (0.5, 0.5)),  # Spot helps
    7: (8, (20, 10, 410, 170), 'cover', (0.85, 0.5)),  # Kitty and the mouse
    8: (8, (20, 10, 410, 170), 'cover', (0.25, 0.5)),  # out it comes
    9: (10, (85, 88, 940, 755), 'cover', None),    # turnip soup
}


def fit(img, mode, focus):
    if mode == 'contain':
        bg = img.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(28))
        bg = ImageEnhance.Brightness(bg).enhance(1.05)
        s = min(W / img.width, H / img.height)
        fg = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
        bg.paste(fg, ((W - fg.width) // 2, (H - fg.height) // 2))
        return bg
    fx, fy = focus or (0.5, 0.5)
    s = max(W / img.width, H / img.height)
    big = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    x = round((big.width - W) * fx)
    y = round((big.height - H) * fy)
    return big.crop((x, y, x + W, y + H))


def main():
    os.makedirs(OUT, exist_ok=True)
    for page, (n, box, mode, focus) in PAGES.items():
        img = Image.open(f'{SRC}/upload_{n:02d}.png').convert('RGB').crop(box)
        out = fit(img, mode, focus)
        # The small sources were enlarged a lot; sharpen gently.
        if img.width < 600:
            out = out.filter(ImageFilter.UnsharpMask(radius=2.2, percent=70, threshold=2))
        out.save(f'{OUT}/p{page:02d}.png', optimize=True)
        print(f'p{page:02d} from upload {n} ({img.width}x{img.height}, {mode})')


if __name__ == '__main__':
    main()
