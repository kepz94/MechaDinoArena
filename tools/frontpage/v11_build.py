# Front page v1.1 (Kepu 2026-11-26 11:33: "Redo our icon and thumbnail to something like this [a FREE -> TITAN before / after
# tile]. Then have our current icon just be thumbnail sized"). Real Studio frames only:
#   src/plain_raptor_frame.jpg  - Studio screen_capture 2026-11-26, classic Raptor, no parts, anchored copy on the magenta stage
#   src/mecha_raptor_frame_19-40-18_4.5s.png - Game Bar recording 19-40-18 at 4.5 s (Lava Raptor, Shock Cannon / Adrenaline /
#   Thrusters lit), the same take as the v1.0 icon frames.
# Output: thumb_dino_to_mecha.jpg (1920 x 1080), icon_dino_to_mecha_1024.png / _512.png, thumb_current_icon.jpg (the v1.0 icon
# on a 16:9 burst). Run: python3 -I tools/frontpage/v11_build.py (from the repo root).
import os, sys, math, numpy as np
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'frontpage'))
D = os.path.join(ROOT, 'docs', 'front_page_v1.1')
import comp
comp.FONT = os.path.join(D, 'src', 'Silkscreen-700.ttf')
from comp import burst, outlined, crop_sub, text3d
from key import key
from PIL import Image, ImageDraw, ImageFilter

def keyed(path, crop=None, clear=()):
    src = Image.open(path).convert('RGB')
    if crop: src = src.crop(crop)
    tmp = os.path.join(D, 'src', '_k.png'); src.save(tmp)
    im = key(tmp); os.remove(tmp)
    px = im.load()
    for (x0, y0, x1, y1) in clear:
        for y in range(y0, min(y1, im.size[1])):
            for x in range(x0, min(x1, im.size[0])): px[x, y] = (0, 0, 0, 0)
    return crop_sub(im, 30)

plain = keyed(os.path.join(D, 'src', 'plain_front.jpg'), clear=[(0, 600, 1920, 700)])  # v1.1d: facing the camera (3/4 front)

def sky_ground(W, H, horizon):
    yy, xx = np.mgrid[0:H, 0:W]
    y = yy.astype(np.float32)
    top, mid = np.array([70, 150, 255.]), np.array([175, 220, 255.])
    g0, g1 = np.array([110, 200, 80.]), np.array([60, 150, 50.])
    t = np.clip(y / horizon, 0, 1)[..., None]
    sky = top * (1 - t) + mid * t
    tg = np.clip((y - horizon) / (H - horizon), 0, 1)[..., None]
    img = np.where((y >= horizon)[..., None], g0 * (1 - tg) + g1 * tg, sky)
    chk = (((xx // 48) + ((yy - int(horizon)) // 48)) % 2 == 0) & (yy >= horizon)
    img[chk] *= 0.9
    return Image.fromarray(img.astype(np.uint8)).convert('RGBA')

def gold(W, H, cx=0.5, cy=0.45):
    return burst(W, H, (255, 236, 140), (226, 120, 10), (255, 250, 210), cx=cx, cy=cy, n=16, ray_a=90, vig=0.35)

def arrow(size, p0, p1, p2, width=46, head=110):
    fine = [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in np.linspace(0, 0.86, 300)]
    ex, ey = fine[-1]; dx, dy = p2[0] - ex, p2[1] - ey
    L = math.hypot(dx, dy); ux, uy = dx / L, dy / L; nx, ny = -uy, ux
    headpoly = [(ex + ux * head, ey + uy * head), (ex + nx * head * 0.62, ey + ny * head * 0.62), (ex - nx * head * 0.62, ey - ny * head * 0.62)]
    def layer(extra, col):
        im = Image.new('RGBA', size, (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        r = (width + extra * 2) / 2
        for x, y in fine: d.ellipse([x - r, y - r, x + r, y + r], fill=col)
        cx = sum(p[0] for p in headpoly) / 3; cy = sum(p[1] for p in headpoly) / 3
        d.polygon([(cx + (x - cx) * (1 + extra / 55), cy + (y - cy) * (1 + extra / 55)) for x, y in headpoly], fill=col)
        return im
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    out.alpha_composite(layer(18, (0, 0, 0, 120)).filter(ImageFilter.GaussianBlur(10)), (8, 12))
    out.alpha_composite(layer(16, (15, 10, 20, 255)))
    out.alpha_composite(layer(9, (255, 255, 255, 255)))
    out.alpha_composite(layer(0, (235, 40, 40, 255)))
    return out

def place(canvas, layer, w, cx, cy):
    s = w / layer.size[0]
    L = layer.resize((int(layer.size[0] * s), int(layer.size[1] * s)), Image.LANCZOS)
    canvas.paste(L, (int(cx - L.size[0] / 2), int(cy - L.size[1] / 2)), L)

def split(W, H, xt, xb, left, right, stripe=16):
    mask = Image.new('L', (W, H), 0)
    ImageDraw.Draw(mask).polygon([(xt, 0), (W, 0), (W, H), (xb, H)], fill=255)
    out = left.copy(); out.paste(right, (0, 0), mask)
    d = ImageDraw.Draw(out)
    d.line([(xt, -10), (xb, H + 10)], fill=(15, 10, 20, 255), width=stripe + 12)
    d.line([(xt, -10), (xb, H + 10)], fill=(255, 255, 255, 255), width=stripe)
    return out

WHITE_TXT = dict(fill_top=(255, 255, 255), fill_bot=(205, 225, 255))
GOLD_TXT = dict(fill_top=(255, 240, 130), fill_bot=(255, 150, 20))
def build_mech(frame, ball_c, ball_r):
    # v1.1d: the Shock Cannon frame has the dino and the ball; the ball is the disc of radius ball_r around ball_c (frame pixels).
    # Only the dino gets the sticker outline; the ball gets an electric glow instead.
    src = Image.open(os.path.join(D, 'src', frame)).convert('RGB')
    tmp = os.path.join(D, 'src', '_k.png'); src.save(tmp); full = key(tmp); os.remove(tmp)
    px = full.load()
    for y in range(600, full.size[1]):
        for x in range(full.size[0]): px[x, y] = (0, 0, 0, 0)
    W0, H0 = full.size
    bm = Image.new('L', (W0, H0), 0)
    ImageDraw.Draw(bm).ellipse([ball_c[0] - ball_r, ball_c[1] - ball_r, ball_c[0] + ball_r, ball_c[1] + ball_r], fill=255)
    dm = Image.eval(bm, lambda v: 255 - v)
    dino = full.copy(); ball = full.copy()
    dino.putalpha(Image.composite(dino.getchannel('A'), Image.new('L', (W0, H0), 0), dm))
    ball.putalpha(Image.composite(ball.getchannel('A'), Image.new('L', (W0, H0), 0), bm))
    dl = outlined(dino, 12, (255, 255, 255), 6, (12, 12, 20), glow=(255, 210, 90))
    arr = np.asarray(ball).astype(np.float32)
    arr[..., :3] = arr[..., :3] * 0.35 + np.array([225, 245, 255.]) * 0.65
    ballc = Image.fromarray(arr.astype(np.uint8))
    glow = Image.new('RGBA', (W0, H0), (110, 220, 255, 0)); glow.putalpha(ball.getchannel('A').filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(26)))
    out = Image.new('RGBA', (W0, H0), (0, 0, 0, 0))
    out.alpha_composite(glow); out.alpha_composite(glow); out.alpha_composite(dl); out.alpha_composite(ballc)
    return crop_sub(out, 20)

PLAIN_T = outlined(plain, 10, (255, 255, 255), 5, (12, 12, 20))
PLAIN_I = outlined(plain, 9, (255, 255, 255), 5, (12, 12, 20))
VARIANTS = {'stand': ('mecha_shoot_stand.jpg', (1255, 437), 150), 'leap': ('mecha_shoot_leap.jpg', (1255, 405), 175)}
for tag, (frame, bc, br) in VARIANTS.items():
    MECH = build_mech(frame, bc, br)
    # thumbnail 1920 x 1080
    W, H = 1920, 1080
    R = gold(W, H, cx=0.72, cy=0.5)
    place(R, MECH, 1180, 1390, 630)
    base = split(W, H, 930, 790, sky_ground(W, H, 720), R)
    place(base, PLAIN_T, 470, 410, 690)
    place(base, text3d('DINO', 190, **WHITE_TXT), 560, 410, 175)
    place(base, text3d('MECHA', 210, **GOLD_TXT), 720, 1430, 150)
    base.alpha_composite(arrow((W, H), (560, 340), (740, 140), (950, 290)))
    base.convert('RGB').save(os.path.join(D, 'thumb_dino_to_mecha_' + tag + '.jpg'), quality=92)
    # icon 1024 x 1024
    W, H = 1024, 1024
    R = gold(W, H, cx=0.7, cy=0.5)
    place(R, MECH, 900, 600, 600)
    base = split(W, H, 470, 330, sky_ground(W, H, 700), R, stripe=14)
    place(base, PLAIN_I, 270, 170, 870)
    place(base, text3d('DINO', 150, **WHITE_TXT), 380, 210, 120)
    place(base, text3d('MECHA', 170, **GOLD_TXT), 520, 740, 120)
    base.alpha_composite(arrow((W, H), (200, 700), (220, 470), (390, 420), width=34, head=80))
    base.convert('RGB').save(os.path.join(D, 'icon_dino_to_mecha_' + tag + '_1024.png'))
    base.convert('RGB').resize((512, 512), Image.LANCZOS).save(os.path.join(D, 'icon_dino_to_mecha_' + tag + '_512.png'))

# the v1.0 icon as a 16:9 thumbnail: a framed card on a matching blue burst
ic = Image.open(os.path.join(ROOT, 'docs', 'front_page_v1.0', 'icon_1024.png')).convert('RGBA')
W, H = 1920, 1080
bg = burst(W, H, (40, 170, 240), (10, 40, 100), (120, 210, 255), cx=0.5, cy=0.5, n=18, ray_a=70, vig=0.5)
S2 = 880
card = ic.resize((S2, S2), Image.LANCZOS)
m = Image.new('L', (S2, S2), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, S2 - 1, S2 - 1], radius=70, fill=255)
card.putalpha(m)
x0, y0 = (W - S2) // 2, (H - S2) // 2 - 20
sh = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ImageDraw.Draw(sh).rounded_rectangle([x0 - 14, y0 - 14, x0 + S2 + 14, y0 + S2 + 14], radius=84, fill=(0, 0, 0, 150))
bg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(22)), (10, 18))
fr = Image.new('RGBA', (W, H), (0, 0, 0, 0)); fd = ImageDraw.Draw(fr)
fd.rounded_rectangle([x0 - 16, y0 - 16, x0 + S2 + 16, y0 + S2 + 16], radius=86, fill=(15, 10, 20, 255))
fd.rounded_rectangle([x0 - 10, y0 - 10, x0 + S2 + 10, y0 + S2 + 10], radius=80, fill=(255, 255, 255, 255))
bg.alpha_composite(fr)
bg.alpha_composite(card, (x0, y0))
bg.convert('RGB').save(os.path.join(D, 'thumb_current_icon.jpg'), quality=92)
print('ok')
