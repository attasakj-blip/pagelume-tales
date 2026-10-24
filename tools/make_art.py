"""Draws the picture pages for "The Enormous Turnip".

Everything is drawn from simple shapes, so the art is ours and free to use.
Run: python3 tools/make_art.py  (writes assets/stories/turnip/p00.png ... p09.png)
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 3  # draw 3x larger, then shrink: smooth edges
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'stories', 'turnip')
GROUND = 820

SKIN = '#f6cfa8'
SKIN_D = '#e9a98a'
INK = '#3b2b25'


class Pen:
    """Draws shapes through a move/scale/rotate/mirror transform."""

    def __init__(self, draw, ox=0.0, oy=0.0, s=1.0, ang=0.0, flip=False):
        self.d, self.ox, self.oy, self.s, self.flip = draw, ox, oy, s, flip
        self.c, self.sn = math.cos(math.radians(ang)), math.sin(math.radians(ang))

    def pt(self, x, y):
        if self.flip:
            x = -x
        x, y = x * self.c - y * self.sn, x * self.sn + y * self.c
        return ((self.ox + x * self.s) * SS, (self.oy + y * self.s) * SS)

    def poly(self, pts, fill, outline=INK, width=2.2):
        p = [self.pt(x, y) for x, y in pts]
        self.d.polygon(p, fill=fill)
        if outline:
            self.d.line(p + [p[0]], fill=outline, width=max(1, int(width * self.s * SS)), joint='curve')

    def ellipse(self, cx, cy, rx, ry, fill, outline=INK, rot=0.0, width=2.2, a0=0, a1=360):
        n = 48
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        pts = []
        for i in range(n + 1):
            t = math.radians(a0 + (a1 - a0) * i / n)
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((cx + x * c - y * s, cy + x * s + y * c))
        if a1 - a0 < 360:
            pts.append((cx, cy))
        self.poly(pts, fill, outline, width)

    def circle(self, cx, cy, r, fill, outline=INK, width=2.2):
        self.ellipse(cx, cy, r, r, fill, outline, width=width)

    def line(self, pts, color=INK, width=3):
        p = [self.pt(x, y) for x, y in pts]
        self.d.line(p, fill=color, width=max(1, int(width * self.s * SS)), joint='curve')

    def limb(self, a, b, w, fill, end_r=None, end_fill=None):
        """A thick rounded stroke from a to b (arm, leg, tail)."""
        (x1, y1), (x2, y2) = a, b
        dx, dy = x2 - x1, y2 - y1
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L * w / 2, dx / L * w / 2
        self.poly([(x1 + nx, y1 + ny), (x2 + nx, y2 + ny), (x2 - nx, y2 - ny), (x1 - nx, y1 - ny)], fill)
        self.circle(x1, y1, w / 2, fill, outline=None)
        if end_r:
            self.circle(x2, y2, end_r, end_fill or fill)

    def eye(self, x, y, r=4.5, closed=False):
        if closed:
            self.line([(x - r, y), (x, y - r * 0.7), (x + r, y)], width=2.5)
        else:
            self.circle(x, y, r, INK, outline=None)
            self.circle(x - r * 0.35, y - r * 0.35, r * 0.35, 'white', outline=None)

    def smile(self, x, y, w=10, open_=False):
        if open_:
            self.ellipse(x, y + 2, w * 0.6, w * 0.5, '#b5473f', a0=0, a1=180)
        else:
            self.line([(x - w / 2, y), (x, y + w * 0.35), (x + w / 2, y)], width=2.5)


# ---------------------------------------------------------------- people ---
# Local coordinates: feet at (0, 0), facing left (negative x), y up is negative.
# `hands` is where the hands reach, in the same local coordinates.

def grandpa(p, hands=(-85, -150), face='happy', hands2=None):
    back = hands2 or hands
    p.limb((-14, -80), (-20, -8), 20, '#5b4636')
    p.limb((14, -80), (12, -8), 20, '#5b4636')
    p.ellipse(-28, -6, 20, 9, '#3a2a20')
    p.ellipse(6, -6, 20, 9, '#3a2a20')
    p.limb((18, -185), back, 19, '#4a78b5', 11, SKIN)  # back arm
    p.ellipse(0, -135, 46, 68, '#4a78b5')
    p.poly([(-30, -190), (30, -190), (34, -80), (-34, -80)], '#8b5a3c')  # vest
    p.ellipse(0, -132, 8, 50, '#4a78b5', outline=None)
    p.circle(20, -250, 20, '#f2f2f2')  # hair behind
    p.circle(-5, -245, 40, SKIN)
    p.ellipse(-20, -212, 30, 30, '#f7f7f7')  # beard
    p.ellipse(-28, -228, 18, 7, '#f0f0f0')  # moustache
    p.circle(-43, -242, 9, SKIN_D)  # nose
    p.eye(-25, -256, closed=face == 'strain')
    if face == 'wow':
        p.ellipse(-30, -212, 7, 9, '#b5473f')
    p.line([(-34, -268), (-16, -270)], '#e0e0e0', 4)  # eyebrow
    p.ellipse(-5, -282, 60, 11, '#e7c25a')  # straw hat
    p.ellipse(-3, -298, 33, 22, '#e7c25a', a0=180, a1=360)
    p.line([(-35, -290), (29, -290)], '#b5473f', 5)
    p.limb((-14, -185), hands, 19, '#4a78b5', 11, SKIN)  # front arm


def grandma(p, hands=(-80, -140), face='happy', hands2=None):
    back = hands2 or hands
    p.limb((-12, -50), (-14, -6), 16, '#6b4f3a')
    p.limb((12, -50), (10, -6), 16, '#6b4f3a')
    p.ellipse(-22, -5, 17, 8, '#3a2a20')
    p.ellipse(4, -5, 17, 8, '#3a2a20')
    p.limb((14, -170), back, 16, '#c94c4c', 10, SKIN)
    p.poly([(-34, -185), (34, -185), (58, -40), (-58, -40)], '#c94c4c')  # dress
    p.poly([(-30, -150), (12, -150), (20, -50), (-44, -50)], '#fff6e8')  # apron
    p.circle(18, -232, 16, '#bdbdbd')  # bun
    p.circle(-5, -222, 37, SKIN)
    p.poly([(-38, -238), (-20, -268), (20, -264), (40, -230), (30, -200), (10, -232)], '#7bb661')  # scarf
    p.circle(-41, -219, 8, SKIN_D)
    p.circle(-22, -207, 7, '#f3a3a0', outline=None)  # cheek
    p.eye(-24, -228, closed=face == 'strain')
    p.smile(-27, -203, 10, open_=face == 'wow')
    p.limb((-12, -170), hands, 16, '#c94c4c', 10, SKIN)


def girl(p, hands=(-65, -95), face='happy', hands2=None):
    back = hands2 or hands
    p.limb((-9, -35), (-10, -4), 12, SKIN)
    p.limb((9, -35), (8, -4), 12, SKIN)
    p.ellipse(-16, -4, 13, 6, '#d24a7a')
    p.ellipse(2, -4, 13, 6, '#d24a7a')
    p.limb((10, -112), back, 12, '#f28cb1', 8, SKIN)
    p.poly([(-24, -122), (24, -122), (42, -30), (-42, -30)], '#f28cb1')
    p.circle(26, -160, 14, '#7a4a2a')  # pigtail
    p.circle(-3, -150, 33, SKIN)
    p.ellipse(4, -168, 33, 22, '#7a4a2a', rot=-10)  # hair
    p.ellipse(26, -178, 10, 7, '#ffd34d')  # bow
    p.circle(-34, -148, 6, SKIN_D)
    p.circle(-18, -138, 6, '#f3a3a0', outline=None)
    p.eye(-20, -154, closed=face == 'strain')
    p.smile(-22, -133, 9, open_=face == 'wow')
    p.limb((-8, -112), hands, 12, '#f28cb1', 8, SKIN)


def dog(p, head=(-48, -92), face='happy'):
    hx, hy = head
    p.limb((60, -70), (95, -118), 12, 'white')  # tail
    p.limb((-20, -45), (-28, -5), 15, 'white')
    p.limb((50, -45), (56, -5), 15, 'white')
    p.ellipse(18, -62, 62, 30, 'white')
    p.ellipse(30, -70, 18, 13, '#a0673d', outline=None)
    p.ellipse(-2, -52, 12, 9, '#a0673d', outline=None)
    p.limb((-10, -45), (-14, -5), 15, 'white')
    p.limb((40, -45), (42, -5), 15, 'white')
    p.circle(hx, hy, 28, 'white')
    p.ellipse(hx - 24, hy + 6, 20, 13, 'white')
    p.circle(hx - 42, hy + 2, 6, INK)
    p.ellipse(hx + 14, hy + 6, 10, 22, '#a0673d', rot=15)  # ear
    p.eye(hx - 10, hy - 8, closed=face == 'strain')
    p.line([(hx - 36, hy + 15), (hx - 24, hy + 18)], width=2.5)


def cat(p, paw=(-50, -80), face='happy'):
    o = '#f2a54a'
    p.line([(48, -40), (70, -60), (66, -95), (78, -105)], '#3b2b25', 12)
    p.line([(48, -40), (70, -60), (66, -95), (78, -105)], o, 8)
    p.limb((-14, -30), (-16, -4), 11, o)
    p.limb((34, -30), (36, -4), 11, o)
    p.ellipse(14, -40, 42, 22, o)
    for x in (2, 16, 30):
        p.line([(x, -60), (x + 4, -48)], '#c9772a', 4)
    p.limb((-20, -45), paw, 10, o, 6)
    p.circle(-30, -64, 23, o)
    p.poly([(-48, -78), (-44, -100), (-30, -84)], o)
    p.poly([(-26, -84), (-14, -100), (-12, -76)], o)
    p.eye(-38, -68, 3.8, closed=face == 'strain')
    p.circle(-52, -60, 3, '#f08a8a', outline=None)
    p.line([(-50, -56), (-64, -58)], width=1.5)
    p.line([(-50, -53), (-63, -50)], width=1.5)


def mouse(p, paw=(-34, -22), face='happy'):
    g = '#a7a2a8'
    p.line([(22, -10), (40, -2), (52, -14), (62, -10)], '#c98f9b', 3)
    p.ellipse(6, -16, 22, 14, g)
    p.limb((-8, -18), paw, 5, g, 3)
    p.circle(-14, -24, 11, g)
    p.circle(-8, -36, 7, '#f2b8c6')
    p.ellipse(-25, -21, 6, 4, g)
    p.circle(-30, -21, 2.2, '#e57a8a', outline=None)
    p.eye(-17, -27, 2.2)


# ----------------------------------------------------------------- scenery ---

def background(img, d, indoor=False, sun=(860, 150)):
    W = SIZE * SS
    if indoor:
        d.rectangle([0, 0, W, W], fill='#f7e2bf')
        for x in range(0, SIZE, 64):
            d.rectangle([x * SS, 0, (x + 32) * SS, 640 * SS], fill='#f3d9ae')
        d.rectangle([0, 640 * SS, W, W], fill='#c9925a')
        return
    top, bot = (126, 196, 240), (214, 239, 250)
    for y in range(0, GROUND * SS, 4):
        t = y / (GROUND * SS)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        d.rectangle([0, y, W, y + 4], fill=c)
    p = Pen(d)
    p.circle(sun[0], sun[1], 70, '#ffe27a', outline='#f7c948', width=4)
    random.seed(sun[0])
    for cx, cy in ((180, 140), (520, 90)):
        for dx, dy, r in ((0, 0, 40), (40, -14, 46), (84, 0, 38)):
            p.circle(cx + dx, cy + dy, r, 'white', outline=None)
    p.ellipse(220, GROUND + 80, 520, 230, '#9fd27e', outline=None)
    p.ellipse(860, GROUND + 90, 480, 200, '#8cc56b', outline=None)


def ground(d):
    p = Pen(d)
    p.poly([(-10, GROUND), (SIZE + 10, GROUND), (SIZE + 10, SIZE + 10), (-10, SIZE + 10)], '#9b6a43', outline=None)
    p.poly([(-10, GROUND - 6), (SIZE + 10, GROUND - 6), (SIZE + 10, GROUND + 14), (-10, GROUND + 14)], '#6fb35a', outline=None)
    random.seed(4)
    for _ in range(40):
        x, y = random.uniform(0, SIZE), random.uniform(GROUND + 30, SIZE)
        p.ellipse(x, y, 10, 4, '#87593a', outline=None)


def house(p):
    p.poly([(0, 0), (0, -150), (180, -150), (180, 0)], '#f4e3c3')
    p.poly([(-20, -150), (90, -240), (200, -150)], '#c75b4a')
    p.poly([(70, 0), (70, -80), (110, -80), (110, 0)], '#8b5a3c')
    p.poly([(125, -110), (125, -70), (165, -70), (165, -110)], '#bfe3f5')


def turnip(p, x, y, r, leaves=1.0, roots=False):
    """Bulb centre (x, y), radius r; leaves scale with the bulb."""
    for ang, ln in ((-38, 1.5), (-15, 1.9), (8, 2.1), (30, 1.7), (52, 1.3)):
        a = math.radians(ang - 90)
        bx, by = x, y - r * 0.85
        ex, ey = bx + math.cos(a) * r * ln * leaves, by + math.sin(a) * r * ln * leaves
        p.line([(bx, by), (ex, ey)], '#3f8a3a', r * 0.07)
        p.ellipse((bx + ex) / 2 + (ex - bx) * 0.2, (by + ey) / 2 + (ey - by) * 0.2,
                  r * 0.32 * leaves, r * 0.75 * ln * leaves * 0.5, '#5fb04f', rot=ang)
    if roots:
        p.line([(x, y + r * 0.9), (x - r * 0.1, y + r * 1.4), (x + r * 0.05, y + r * 1.7)], '#d8cbb0', r * 0.06)
    p.ellipse(x, y, r * 1.05, r, '#fbf6ee')
    p.ellipse(x, y - r * 0.15, r * 1.0, r * 0.82, '#a35ab5', outline=None, a0=180, a1=360)
    p.ellipse(x, y, r * 1.05, r, None)
    p.ellipse(x - r * 0.45, y - r * 0.35, r * 0.18, r * 0.3, '#ffffff', outline=None, rot=25)


def sparkle(p, x, y, r, c='#ffd34d'):
    pts = []
    for i in range(8):
        a = math.radians(i * 45)
        rr = r if i % 2 == 0 else r * 0.35
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    p.poly(pts, c, outline=None)


# ------------------------------------------------------------------ scenes ---

CHAIN = [  # x position, drawer, scale
    (360, grandpa, 0.95),
    (468, grandma, 0.95),
    (560, girl, 1.0),
    (680, dog, 0.95),
    (830, cat, 1.0),
    (925, mouse, 1.3),
]


def pulling(d, n, face='strain', mouse_peek=False):
    background(None, d)
    p = Pen(d)
    house(Pen(d, 760, GROUND - 4, 0.9)) if n < 4 else None
    turnip(p, 200, GROUND + 10, 120)
    ground(d)
    targets = {
        grandpa: dict(hands=(-82, -150)),
        grandma: dict(hands=(-78, -168)),
        girl: dict(hands=(-62, -128)),
        dog: dict(head=(-52, -78)),
        cat: dict(paw=(-56, -95)),
        mouse: dict(paw=(-36, -26)),
    }
    for x, fn, s in CHAIN[:n]:
        lean = 10 if fn in (grandpa, grandma, girl) else 4
        fn(Pen(d, x, GROUND, s, ang=lean), face=face, **targets[fn])
    if mouse_peek:
        p.ellipse(950, GROUND + 6, 40, 16, '#5b3a24', outline=None)
        mouse(Pen(d, 945, GROUND + 4, 1.3), paw=(-28, -18))


def scene_cover(d):
    background(None, d, sun=(150, 150))
    p = Pen(d)
    turnip(p, 512, GROUND - 120, 230, leaves=0.9)
    ground(d)
    row = [(150, grandpa, 0.8, dict(hands=(-70, -280), hands2=(70, -280))), (260, grandma, 0.8, dict(hands=(-65, -260), hands2=(65, -260))),
           (360, girl, 0.85, dict(hands=(-50, -190), hands2=(50, -190))), (700, dog, 0.85, dict()),
           (840, cat, 0.9, dict(paw=(-50, -110))), (930, mouse, 1.3, dict(paw=(-30, -45)))]
    for x, fn, s, kw in row:
        fn(Pen(d, x, GROUND + 60, s, flip=x > 512), face='wow', **kw)
    for x, y, r in ((300, 300, 26), (740, 260, 22), (520, 140, 30), (880, 420, 18), (130, 440, 18)):
        sparkle(p, x, y, r)


def scene_plant(d):
    background(None, d, sun=(820, 230))
    p = Pen(d)
    house(Pen(d, 640, GROUND - 4, 1.1))
    ground(d)
    p.ellipse(330, GROUND + 4, 50, 14, '#6b4429', outline=None)
    p.circle(330, GROUND - 6, 7, '#d9b56a')
    p.line([(330, GROUND - 6), (330, GROUND - 40)], '#4f9a45', 5)
    p.ellipse(318, GROUND - 44, 14, 7, '#6cc05a', rot=-20)
    p.ellipse(343, GROUND - 46, 14, 7, '#6cc05a', rot=20)
    grandpa(Pen(d, 450, GROUND, 1.0, ang=-12), hands=(-95, -60))
    can = Pen(d, 160, GROUND, 1.0)
    can.poly([(0, 0), (-10, -70), (60, -70), (50, 0)], '#7fb3d5')
    can.limb((-6, -50), (-50, -80), 10, '#7fb3d5')
    can.ellipse(25, -80, 30, 14, None)
    for x in (380, 270, 230):
        p.line([(x, GROUND + 40), (x + 40, GROUND + 40)], '#87593a', 6)


def scene_big(d):
    background(None, d, sun=(900, 120))
    p = Pen(d)
    house(Pen(d, 40, GROUND - 4, 0.8))
    turnip(p, 470, GROUND - 40, 230, leaves=1.05)
    ground(d)
    grandpa(Pen(d, 850, GROUND, 0.8), hands=(-75, -285), hands2=(75, -285), face='wow')
    for x, y in ((760, 380), (930, 330), (700, 250)):
        sparkle(p, x, y, 20)


def scene_pop(d):
    background(None, d, sun=(880, 140))
    p = Pen(d)
    for x, y, r in ((230, 300, 120), (230, 300, 80)):
        sparkle(p, x, y, r, '#fff1a8' if r > 100 else '#ffd34d')
    turnip(p, 230, 360, 115, roots=True)
    ground(d)
    p.ellipse(230, GROUND + 6, 90, 22, '#5b3a24', outline=None)
    for (x, y, fn, s, ang, kw) in (
        (400, GROUND + 20, grandpa, 0.85, 70, dict(hands=(-110, -230), face='wow')),
        (570, GROUND + 10, grandma, 0.85, 45, dict(hands=(-80, -250), face='wow')),
        (720, GROUND, girl, 0.95, -25, dict(hands=(-60, -190), face='wow')),
        (840, GROUND + 4, dog, 0.9, 25, dict()),
        (900, GROUND - 120, cat, 0.9, -40, dict(paw=(-50, -110))),
        (980, GROUND - 4, mouse, 1.3, 15, dict(paw=(-30, -40))),
    ):
        fn(Pen(d, x, y, s, ang=ang), **kw)
    for x, y in ((520, 560), (780, 600), (360, 600), (960, 540)):
        sparkle(p, x, y, 16)


def scene_supper(d):
    background(None, d, indoor=True)
    p = Pen(d)
    p.poly([(380, 140), (640, 140), (640, 380), (380, 380)], '#bfe3f5')  # window
    p.line([(510, 140), (510, 380)], INK, 5)
    p.line([(380, 260), (640, 260)], INK, 5)
    p.circle(590, 190, 26, '#fff7d6', outline=None)
    folks = [(160, grandpa, 1.3, False, 760, dict(hands=(-60, -170))),
             (330, girl, 1.4, False, 760, dict(hands=(-50, -150))),
             (730, grandma, 1.3, True, 760, dict(hands=(-70, -160))),
             (890, dog, 1.1, True, 650, dict(head=(-48, -100)))]
    for x, fn, s, flip, y, kw in folks:
        fn(Pen(d, x, y, s, flip=flip), face='wow', **kw)
    p.poly([(40, 640), (984, 640), (984, 690), (40, 690)], '#a0673d')  # table
    p.poly([(80, 690), (110, 690), (110, 1024), (80, 1024)], '#7a4d2c')
    p.poly([(914, 690), (944, 690), (944, 1024), (914, 1024)], '#7a4d2c')
    p.ellipse(512, 640, 150, 26, '#555b66')  # pot
    p.poly([(362, 640), (662, 640), (640, 520), (384, 520)], '#6d7480')
    p.ellipse(512, 520, 128, 22, '#f2d16b')
    p.ellipse(480, 516, 26, 10, '#a35ab5', outline=None)
    p.ellipse(545, 522, 20, 8, '#fbf6ee', outline=None)
    for x in (450, 512, 575):
        p.line([(x, 490), (x - 14, 450), (x + 6, 410), (x - 8, 370)], '#ffffff', 6)
    cat(Pen(d, 250, 640, 1.1), paw=(-46, -70), face='wow')
    p.ellipse(640, 636, 22, 8, '#fbf6ee')
    mouse(Pen(d, 700, 640, 1.7), paw=(-36, -40))
    for x, y in ((420, 420), (620, 400), (700, 300)):
        sparkle(p, x, y, 14)


SCENES = [
    scene_cover,
    scene_plant,
    scene_big,
    lambda d: pulling(d, 1),
    lambda d: pulling(d, 2),
    lambda d: pulling(d, 3),
    lambda d: pulling(d, 4),
    lambda d: pulling(d, 5, mouse_peek=True),
    scene_pop,
    scene_supper,
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, scene in enumerate(SCENES):
        img = Image.new('RGB', (SIZE * SS, SIZE * SS), 'white')
        scene(ImageDraw.Draw(img))
        img = img.resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.SMOOTH)
        img.save(os.path.join(OUT, f'p{i:02d}.png'), optimize=True)
        print('wrote', f'p{i:02d}.png')


if __name__ == '__main__':
    main()
