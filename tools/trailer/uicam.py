import subprocess, sys, json
from PIL import Image, ImageDraw, ImageFilter

W, H = 1920, 1080
FPS = 30
YEL = (255, 200, 50)


def ease(a):
    a = max(0.0, min(1.0, a))
    return a * a * (3 - 2 * a)


def cam_at(keys, t):
    if t <= keys[0][0]:
        return keys[0][1:]
    for (t0, *a), (t1, *b) in zip(keys, keys[1:]):
        if t0 <= t <= t1:
            k = ease((t - t0) / (t1 - t0))
            return [a[i] + (b[i] - a[i]) * k for i in range(3)]
    return keys[-1][1:]


def render(src, out, start, end, speed, keys, highs, srcsize):
    sw, sh = srcsize
    dec = subprocess.Popen(["ffmpeg", "-v", "error", "-ss", str(start), "-t", str(end - start), "-i", src,
                            "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                            "-r", str(FPS), "-i", "-", "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "16",
                            "-pix_fmt", "yuv420p", out], stdin=subprocess.PIPE)
    fsz = sw * sh * 3
    frames = []
    while True:
        b = dec.stdout.read(fsz)
        if len(b) < fsz:
            break
        frames.append(b)
    n_out = int((end - start) / speed * FPS)
    for i in range(n_out):
        st = start + i / FPS * speed
        idx = min(len(frames) - 1, int((st - start) * 30))
        im = Image.frombytes("RGB", (sw, sh), frames[idx]).convert("RGBA")
        ov = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
        d = ImageDraw.Draw(ov)
        for (h0, h1, x0, y0, x1, y1) in highs:
            if h0 <= st <= h1:
                a = min(1.0, (st - h0) / 0.12, (h1 - st) / 0.12)
                pop = 1 + 0.12 * (1 - ease((st - h0) / 0.2))
                cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                hw, hh = (x1 - x0) / 2 * pop + 4, (y1 - y0) / 2 * pop + 4
                box = [cx - hw, cy - hh, cx + hw, cy + hh]
                glow = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
                ImageDraw.Draw(glow).rounded_rectangle(box, radius=14, outline=YEL + (int(200 * a),), width=12)
                glow = glow.filter(ImageFilter.GaussianBlur(10))
                ov = Image.alpha_composite(ov, glow)
                d = ImageDraw.Draw(ov)
                d.rounded_rectangle(box, radius=12, outline=YEL + (int(255 * a),), width=5)
        im = Image.alpha_composite(im, ov).convert("RGB")
        cx, cy, w = cam_at(keys, st)
        h = w * 9 / 16
        if h > sh:
            h = sh; w = h * 16 / 9
        x0 = min(max(cx - w / 2, 0), sw - w)
        y0 = min(max(cy - h / 2, 0), sh - h)
        fr = im.crop((int(x0), int(y0), int(x0 + w), int(y0 + h))).resize((W, H), Image.LANCZOS)
        enc.stdin.write(fr.tobytes())
    enc.stdin.close(); enc.wait(); dec.wait()


if __name__ == "__main__":
    spec = json.load(open(sys.argv[1]))
    for s in spec:
        render(s["src"], s["out"], s["start"], s["end"], s["speed"], s["keys"], s["highs"], tuple(s["size"]))
        print("done", s["out"])
