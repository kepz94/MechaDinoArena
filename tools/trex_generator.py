#!/usr/bin/env python3
"""T-Rex generator v2.0-draft (Mecha Dino Arena) — mockup stage: three realistic T-Rex designs for Kepu to pick from.

Kepu 2026-11-02: "the t-Rex needs a redesign. It looks way too cartoonish with its portions" (+ "I want you to always
design the dinosaurs carefully from now on"). The shipped T-Rex (TRexModelData 1.24, style 1.1 StripeEye, preset B
cartoon: big head, chunky short legs, short thick tail, big square eyes) was built in Studio by tools/trex_generator_v3.luau;
this Python generator only makes the redesign options for the mockup and does NOT write TRexModelData.
Three different body designs, all with real T-Rex proportions (a long, deep skull wide at the back, a short thick
S-neck, a deep ribcage, tiny two-claw arms, long powerful legs with long metatarsals, a long tail held level as a
counterweight, a small eye under a brow boss):
  A Apex    - the museum T-Rex: balanced, level body, long level tail.
  B Brawler - heavier all over: deeper chest, thicker neck and tail, bigger skull, heavier brows, a lower stance.
  C Stalker - leaner and taller: longer legs, slimmer body tilted forward, a longer narrower snout held low, tail raised.
Kept from the shipped T-Rex so a later install fits the game: the rig 1.3 segment / joint names, the part names other
code finds (Head_mouth, Torso_body), and the three skin colour roles (main 666A4A, dark 50523A, belly B2A278) plus the
never-paint teeth E8E2D2, eye 111111, eye shine F5F5F0, mouth 6E342E. Size: TARGET_LEN 38 studs (the shipped T-Rex is
37.6 at scale 1; it is not doubled).
Run: python3 tools/trex_generator.py --look A|B|C --json OUT
"""
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSION = "2.0-draft"
TARGET_LEN = 38.0
HRP_SIZE_D0 = (4.0, 3.9, 3.0)
ROLES = ["main", "dark", "belly"]
NEVER = {"E8E2D2", "111111", "F5F5F0", "6E342E"}
C = {"main": "666A4A", "dark": "50523A", "belly": "B2A278", "tooth": "E8E2D2", "eye": "111111", "shine": "F5F5F0", "mouth": "6E342E"}
LOOK = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else "A"
M = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))  # D -> HRP space
NECK_RAISE = 0
F = 1.0


def matmul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mv(a, v):
    return tuple(sum(a[i][k] * v[k] for k in range(3)) for i in range(3))


def rot(pitch=0.0, yaw=0.0, roll=0.0):
    p, y, r = math.radians(pitch), math.radians(yaw), math.radians(roll)
    Rz = ((math.cos(p), -math.sin(p), 0), (math.sin(p), math.cos(p), 0), (0, 0, 1))
    Ry = ((math.cos(y), 0, math.sin(y)), (0, 1, 0), (-math.sin(y), 0, math.cos(y)))
    Rx = ((1, 0, 0), (0, math.cos(r), -math.sin(r)), (0, math.sin(r), math.cos(r)))
    return matmul(Rz, matmul(Ry, Rx))


def norm(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


segments, order = {}, []


def seg(name, root):
    segments[name] = {"root": root, "parts": []}
    order.append(name)


def part(segname, key, size, center, pitch=0.0, yaw=0.0, roll=0.0, name=None, R=None):
    segments[segname]["parts"].append({"name": name or f"{segname}_{key}", "size": size, "center": center,
                                       "R": R or rot(pitch, yaw, roll), "key": key})


def blade(segname, key, start, d, length, width, thick, ref=(0, 0, 1), name=None):
    """A block from `start` along direction `d` (feathers, claws); its thin side faces `ref` (z = a side sheet, y = flat)."""
    y = norm(d)
    x = norm(cross(y, ref))
    z = cross(x, y)
    R = tuple(tuple((x, y, z)[j][i] for j in range(3)) for i in range(3))
    centre = tuple(start[i] + y[i] * length / 2 for i in range(3))
    part(segname, key, (width, length, thick), centre, name=name, R=R)
    return tuple(start[i] + y[i] * length for i in range(3))


def bone(segname, key, a, b, w, d, name, extra=0.08):
    part(segname, key, (w, math.dist(a[:2], b[:2]) + extra, d), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, a[2]),
         pitch=math.degrees(math.atan2(b[0] - a[0], -(b[1] - a[1]))), name=name)


def about(root, point, pitch):
    a = math.radians(pitch)
    dx, dy = point[0] - root[0], point[1] - root[1]
    return (root[0] + dx * math.cos(a) - dy * math.sin(a), root[1] + dx * math.sin(a) + dy * math.cos(a), point[2])



# ---------------------------------------------------------------- builders
def bonec(segname, key, a, b, w, d, name, extra=0.1):
    """a block from a to b in the side plane (z = a[2])."""
    bone(segname, key, a, b, w, d, name, extra)


GROUND_Y = None


def build(P):
    """P = the style's proportions. D space: x forward, y up, z left; hip centre = origin."""
    B, NK, HD, LG, TL = P["body"], P["neck"], P["head"], P["legs"], P["tail"]
    # ------------------------------------------------------------ torso: hips, a deep ribcage, shoulders; belly stripe; back scutes
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (2.5, 2.3 * B["depth"], 1.7 * B["width"]), (1.1, 0.0, 0.0), pitch=B["pitch"], name="Torso_body")  # deep barrel ribcage
    part("Torso", "main", (1.9, 1.85 * B["depth"], 1.6 * B["width"]), (-0.35, 0.25, 0.0), pitch=B["pitch"] - 4, name="Torso_hips")
    part("Torso", "main", (1.5, 2.0 * B["depth"], 1.5 * B["width"]), (2.55, 0.32, 0.0), pitch=B["pitch"] + 14, name="Torso_chest")
    part("Torso", "belly", (2.9, 0.22, 1.2 * B["width"]), (1.25, 0.0 - 1.15 * B["depth"], 0.0), pitch=B["pitch"] + 2, name="Torso_belly")
    part("Torso", "belly", (0.3, 1.3 * B["depth"], 1.0 * B["width"]), (3.25, 0.35, 0.0), pitch=B["pitch"] + 22, name="Torso_belly")
    for side in (1, -1):  # big thigh muscles on the hips
        part("Torso", "main", (1.7, 1.6 * LG["thigh"], 0.45), (0.0, -0.2, side * (0.8 * B["width"] + 0.1)), pitch=8, name="Torso_body")
    for i, x in enumerate((-0.6, 0.35, 1.3, 2.2)):  # dark saddle bands across the back
        y = 0.0 + 1.15 * B["depth"] + (x - 1.1) * math.tan(math.radians(B["pitch"])) - 0.35 * B["depth"]
        part("Torso", "dark", (0.42, 0.75 * B["depth"], 1.74 * B["width"]), (x, y + (0.12 if x > 2.0 else 0.0), 0.0), pitch=B["pitch"], name="Torso_dark")
    n = P["scutes"]  # (sit on top of the saddle bands)
    for i in range(n):  # a row of low back scutes along the spine
        t = i / max(1, n - 1)
        x = -1.1 + 4.0 * t
        y = 0.0 + 1.15 * B["depth"] + (x - 1.1) * math.tan(math.radians(B["pitch"])) + 0.08 + (0.12 if x > 2.0 else 0.0)
        part("Torso", "dark", (0.36, 0.2, 0.36 * B["width"]), (x, y, 0.0), pitch=B["pitch"], name="Torso_dark")
    # ------------------------------------------------------------ neck: short, thick, S-curved
    nr = (3.0, 0.75 + 0.2 * B["depth"])
    seg("Neck", (nr[0], nr[1], 0.0))
    a1, a2 = NK["angle"], NK["angle"] * 0.35
    n1 = (nr[0] + 0.55 * math.cos(math.radians(a1)), nr[1] + 0.55 * math.sin(math.radians(a1)))
    part("Neck", "main", (1.3, 1.3 * NK["thick"], 1.1 * NK["thick"]), (n1[0], n1[1], 0.0), pitch=a1, name="Neck_body")
    n2 = (n1[0] + 0.85 * math.cos(math.radians((a1 + a2) / 2)), n1[1] + 0.85 * math.sin(math.radians((a1 + a2) / 2)))
    part("Neck", "main", (1.0, 1.15 * NK["thick"], 1.0 * NK["thick"]), (n2[0], n2[1], 0.0), pitch=a2, name="Neck_body")
    thr = (n1[0] + 0.25, n1[1] - 0.55 * NK["thick"])
    part("Neck", "belly", (1.5, 0.2, 0.8 * NK["thick"]), (thr[0] + 0.2, thr[1] + 0.1, 0.0), pitch=(a1 + a2) / 2, name="Neck_belly")
    for i, (x, y) in enumerate((n1, n2)):
        part("Neck", "dark", (0.36, 0.2, 0.34), (x - 0.15, y + 0.62 * NK["thick"], 0.0), pitch=a1 if i == 0 else a2, name="Neck_dark")
    # ------------------------------------------------------------ head: long, deep, wide at the back; brow bosses; small eye
    hx, hy = n2[0] + 0.55, n2[1] + 0.05
    L, Dp, Wb = HD["len"], HD["depth"], HD["width"]
    tilt = HD["tilt"]
    seg("Head", (hx, hy, 0.0))
    H = lambda dx, dy: about((hx, hy, 0.0), (hx + dx, hy + dy, 0.0), tilt)  # head-local point -> D (pitched by tilt)
    def hp(key, size, dx, dy, z=0.0, pitch=0.0, name=None, yaw=0.0):
        c = H(dx, dy)
        part("Head", key, size, (c[0], c[1], z), pitch=pitch + tilt, yaw=yaw, name=name)
    hp("main", (1.35 * L, 1.35 * Dp, 1.35 * Wb), 0.55 * L, 0.2 * Dp, name="Head_body")                 # cranium, widest at the back
    hp("main", (1.4 * L, 0.95 * Dp, 1.0 * Wb), 1.75 * L, 0.02 * Dp, pitch=-5, name="Head_body")        # upper jaw / muzzle
    hp("main", (0.65 * L, 0.78 * Dp, 0.85 * Wb), 2.65 * L, -0.12 * Dp, pitch=-9, name="Head_body")     # snout tip
    hp("main", (0.9 * L, 0.95 * Dp, 1.5 * Wb), 0.35 * L, -0.35 * Dp, name="Head_body")                 # jaw muscles (cheeks)
    hp("mouth", (2.3 * L, 0.06, 0.9 * Wb), 1.75 * L, -0.48 * Dp, pitch=-5, name="Head_mouth")
    hp("belly", (1.0 * L, 0.12, 0.9 * Wb), 0.5 * L, -0.83 * Dp, name="Head_belly")                      # throat under the cheeks
    for side in (1, -1):
        z = side * 0.66 * Wb
        hp("dark", (0.5 * L, 0.24 * Dp, 0.3 * Wb), 0.85 * L, 0.88 * Dp, side * 0.42 * Wb, pitch=-8, name="Head_dark")   # brow boss
        hp("dark", (0.85 * L, 0.12 * Dp, 0.1), 1.6 * L, 0.42 * Dp, side * 0.48 * Wb, pitch=-5, name="Head_dark")       # ridge to the nose
        hp("eye", (0.26 * L, 0.2 * Dp, 0.05), 0.82 * L, 0.6 * Dp, side * (0.675 * Wb + 0.01), name="Head_eye")
        hp("shine", (0.07 * L, 0.07 * Dp, 0.03), 0.89 * L, 0.65 * Dp, side * (0.675 * Wb + 0.03), name="Head_shine")
        hp("dark", (0.1 * L, 0.08 * Dp, 0.05), 2.85 * L, 0.18 * Dp, side * 0.3 * Wb, name="Head_dark")                 # nostril
        for i in range(HD["teeth"]):  # upper teeth along the jaw edge, both sides
            t = i / max(1, HD["teeth"] - 1)
            hp("tooth", (0.12 * L, 0.24 * Dp, 0.1), (1.1 + 1.75 * t) * L, -0.58 * Dp - 0.04 * t, side * (0.43 - 0.06 * t) * Wb, name="Head_tooth")
    # ------------------------------------------------------------ jaw: long, deep at the back, teeth, open 10 deg at rest
    jr = H(0.4 * L, -0.55 * Dp)
    seg("Jaw", jr)
    J = lambda dx, dy: about(jr, H(dx, dy), -HD["jaw"])
    def jp(key, size, dx, dy, z=0.0, pitch=0.0, name=None):
        c = J(dx, dy)
        part("Jaw", key, size, (c[0], c[1], z), pitch=pitch + tilt - HD["jaw"], name=name)
    jp("dark", (2.6 * L, 0.42 * Dp, 0.88 * Wb), 1.65 * L, -0.78 * Dp, pitch=-3, name="Jaw_dark")
    jp("main", (1.2 * L, 0.55 * Dp, 1.25 * Wb), 0.55 * L, -0.75 * Dp, name="Jaw_body")
    jp("belly", (2.3 * L, 0.1, 0.7 * Wb), 1.55 * L, -1.0 * Dp, pitch=-3, name="Jaw_belly")
    for side in (1, -1):
        for i in range(HD["teeth"] - 2):
            t = i / max(1, HD["teeth"] - 3)
            jp("tooth", (0.11 * L, 0.2 * Dp, 0.1), (1.2 + 1.5 * t) * L, -0.47 * Dp, side * (0.38 - 0.06 * t) * Wb, name="Jaw_tooth")
    # ------------------------------------------------------------ arms: tiny, two claws
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        z = side * 0.66 * B["width"]
        sh = (2.75, -0.25 * B["depth"])
        el = (sh[0] + 0.15, sh[1] - 0.6)
        wr = (el[0] + 0.45, el[1] - 0.05)
        seg(f"Arm{s}", (sh[0], sh[1], z))
        bonec(f"Arm{s}", "main", (sh[0], sh[1], z), (el[0], el[1], z), 0.3, 0.28, f"Arm{s}_body")
        bonec(f"Arm{s}", "main", (el[0], el[1], z), (wr[0], wr[1], z), 0.24, 0.24, f"Arm{s}_body")
        for i, dz in enumerate((-0.06, 0.06)):
            blade(f"Arm{s}", "tooth", (wr[0] + 0.05, wr[1], z + dz), (0.5, -0.85, 0), 0.24, 0.07, 0.07, name=f"Arm{s}_tooth")
    # ------------------------------------------------------------ tail: long, held level, tapering to a point
    root = (-1.25, 0.45)
    th = TL["thick"]
    spec = [(1.7, 1.75, 1.45), (1.6, 1.35, 1.12), (1.5, 1.0, 0.85), (1.4, 0.7, 0.6), (1.35, 0.42, 0.38)]
    for i, (sl, h, w) in enumerate(spec):
        name = f"Tail{i + 1}"
        rise = TL["rise"] - i * TL["droop"]
        a = math.radians(rise)
        d = (-math.cos(a), math.sin(a))
        sl *= TL["len"]
        seg(name, (root[0], root[1], 0.0))
        part(name, "main", (sl + 0.15, h * th, w * th), (root[0] + d[0] * sl / 2, root[1] + d[1] * sl / 2, 0.0), pitch=-rise, name=f"{name}_body")
        part(name, "belly", (sl * 0.9, 0.12, w * th * 0.75), (root[0] + d[0] * sl / 2, root[1] + d[1] * sl / 2 - h * th / 2, 0.0), pitch=-rise, name=f"{name}_belly")
        if i < 4:
            part(name, "dark", (0.34, 0.18, 0.32 * w * th), (root[0] + d[0] * sl * 0.5, root[1] + d[1] * sl * 0.5 + h * th / 2 + 0.06, 0.0), pitch=-rise, name=f"{name}_dark")
        root = (root[0] + d[0] * sl, root[1] + d[1] * sl)
    # ------------------------------------------------------------ legs: big thighs, long shins, long metatarsals, three toes
    lm = LG["len"]
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        z = side * (0.8 * B["width"] + 0.22)
        hip = (0.0, -0.1)
        knee = (0.65 + LG["bend"], -2.05 * lm)
        ankle = (-0.35 - LG["bend"] * 0.5, -3.85 * lm)
        ball = (0.2, -4.75 * lm)
        seg(f"Leg{s}", (hip[0], hip[1], z))
        bonec(f"Leg{s}", "main", (hip[0], hip[1], z), (knee[0], knee[1], z), 1.45 * LG["thigh"], 1.05 * LG["thigh"], f"Leg{s}_body")
        seg(f"Shin{s}", (knee[0], knee[1], z))
        bonec(f"Shin{s}", "main", (knee[0], knee[1], z), (ankle[0], ankle[1], z), 0.78 * LG["thigh"], 0.7 * LG["thigh"], f"Shin{s}_body")
        cm = (knee[0] * 0.7 + ankle[0] * 0.3 - 0.12, knee[1] * 0.7 + ankle[1] * 0.3)  # calf muscle
        part(f"Shin{s}", "main", (0.7 * LG["thigh"], 1.0, 0.72 * LG["thigh"]), (cm[0], cm[1], z), pitch=math.degrees(math.atan2(ankle[0] - knee[0], -(ankle[1] - knee[1]))), name=f"Shin{s}_body")
        seg(f"Foot{s}", (ankle[0], ankle[1], z))
        bonec(f"Foot{s}", "dark", (ankle[0], ankle[1], z), (ball[0], ball[1], z), 0.55, 0.55, f"Foot{s}_dark")
        gy = ball[1] - 0.15
        for i, yw in enumerate((16, 0, -16)):
            Lt = 0.95 if yw == 0 else 0.75
            dx, dz = math.cos(math.radians(yw)) * Lt / 2, -math.sin(math.radians(yw)) * Lt / 2
            part(f"Foot{s}", "dark", (Lt, 0.3, 0.3), (ball[0] + dx, gy, z + side * dz), yaw=yw * side, name=f"Foot{s}_dark")
            part(f"Foot{s}", "tooth", (0.24, 0.2, 0.18), (ball[0] + dx * 2 + 0.08, gy - 0.03, z + side * dz * 2), yaw=yw * side, name=f"Foot{s}_tooth")
    return nr


STYLES = {
    # A Apex: the museum T-Rex. Level body, a long, deep, heavy skull, short thick S-neck, powerful legs, long level tail.
    "A": {"name": "Apex", "body": {"depth": 1.0, "width": 1.0, "pitch": 4}, "neck": {"angle": 38, "thick": 1.0},
          "head": {"len": 1.0, "depth": 1.0, "width": 1.0, "tilt": -6, "jaw": 10, "teeth": 7},
          "legs": {"len": 1.0, "thigh": 1.0, "bend": 0.0}, "tail": {"len": 1.0, "thick": 1.0, "rise": 4, "droop": 1.5}, "scutes": 9},
    # B Brawler: heavier all over: a deeper chest, thicker neck and tail, a bigger skull with heavier brows, a lower
    # stance with the knees more bent, the head held low and forward.
    "B": {"name": "Brawler", "body": {"depth": 1.15, "width": 1.15, "pitch": 2}, "neck": {"angle": 30, "thick": 1.2},
          "head": {"len": 1.05, "depth": 1.15, "width": 1.15, "tilt": -10, "jaw": 12, "teeth": 7},
          "legs": {"len": 0.94, "thigh": 1.2, "bend": 0.25}, "tail": {"len": 0.95, "thick": 1.2, "rise": 2, "droop": 1.0}, "scutes": 11},
    # C Stalker: leaner and taller: longer legs, a slimmer body tilted forward, a longer, narrower snout held low and
    # level, the tail raised as a counterweight.
    "C": {"name": "Stalker", "body": {"depth": 0.9, "width": 0.88, "pitch": -2}, "neck": {"angle": 26, "thick": 0.9},
          "head": {"len": 1.08, "depth": 0.92, "width": 0.9, "tilt": -12, "jaw": 8, "teeth": 8},
          "legs": {"len": 1.12, "thigh": 0.92, "bend": 0.15}, "tail": {"len": 1.08, "thick": 0.9, "rise": 9, "droop": 2.0}, "scutes": 9},
}

L = STYLES[LOOK]
NECK_ROOT = build(L)
NECK_ROOT = (NECK_ROOT[0], NECK_ROOT[1])

JOINTS = [("RootJoint", "HRP", "Torso"), ("Neck", "Torso", "Neck"), ("Head", "Neck", "Head"), ("Jaw", "Head", "Jaw"),
          ("ArmL", "Torso", "ArmL"), ("ArmR", "Torso", "ArmR"), ("Tail1", "Torso", "Tail1"), ("Tail2", "Tail1", "Tail2"),
          ("Tail3", "Tail2", "Tail3"), ("Tail4", "Tail3", "Tail4"), ("Tail5", "Tail4", "Tail5"),
          ("LegL", "Torso", "LegL"), ("LegR", "Torso", "LegR"), ("KneeL", "LegL", "ShinL"), ("KneeR", "LegR", "ShinR"),
          ("AnkleL", "ShinL", "FootL"), ("AnkleR", "ShinR", "FootR")]

# ---------------------------------------------------------------- posture: the look's neck lean (neck, head, jaw turn about the neck root)
if NECK_RAISE:
    Rn = rot(NECK_RAISE)
    for n_ in ("Neck", "Head", "Jaw"):
        s_ = segments[n_]
        s_["root"] = about(NECK_ROOT, s_["root"], NECK_RAISE)
        for p in s_["parts"]:
            p["center"] = about(NECK_ROOT, p["center"], NECK_RAISE)
            p["R"] = matmul(Rn, p["R"])


# ---------------------------------------------------------------- bounds + length scale
def bounds():
    lo, hi = [1e9] * 3, [-1e9] * 3
    for n_ in order:
        for p in segments[n_]["parts"]:
            h = [v / 2 for v in p["size"]]
            for sx in (-1, 1):
                for sy in (-1, 1):
                    for sz in (-1, 1):
                        w = mv(p["R"], (sx * h[0], sy * h[1], sz * h[2]))
                        for i in range(3):
                            lo[i] = min(lo[i], p["center"][i] + w[i])
                            hi[i] = max(hi[i], p["center"][i] + w[i])
    return lo, hi


lo, hi = bounds()
K = TARGET_LEN / (hi[0] - lo[0])
for n_ in order:
    s_ = segments[n_]
    s_["root"] = tuple(v * K for v in s_["root"])
    for p in s_["parts"]:
        p["size"] = tuple(v * K for v in p["size"])
        p["center"] = tuple(v * K for v in p["center"])
lo, hi = bounds()
HIP = -lo[1]
HRP_SIZE_D = tuple(v * K for v in HRP_SIZE_D0)


def cf(pos_d, R_d=None):
    R = matmul(M, R_d if R_d else rot())
    p = mv(M, pos_d)
    return [round(v, 5) + 0.0 for v in list(p) + [R[0][0], R[0][1], R[0][2], R[1][0], R[1][1], R[1][2], R[2][0], R[2][1], R[2][2]]]


hexes = [C[r] for r in ROLES]
assert len(set(hexes)) == len(hexes), "two colour groups share a hex"
used = {C[p["key"]] for n_ in order for p in segments[n_]["parts"]}
assert used <= set(hexes) | NEVER, "a block colour is not a role or never-paint"

if "--json" in sys.argv:
    out = sys.argv[sys.argv.index("--json") + 1]
    hx, hy, hz = HRP_SIZE_D
    data = {"look": LOOK, "name": L["name"], "version": VERSION, "roles": {r: C[r] for r in ROLES},
            "segs": [{"n": n_, "root": cf(segments[n_]["root"]),
                      "parts": [{"n": p["name"], "s": [round(v, 4) for v in p["size"]], "cf": cf(p["center"], p["R"]),
                                 "c": C[p["key"]], "k": p["key"]} for p in segments[n_]["parts"]]} for n_ in order],
            "joints": [{"n": jn, "p0": p0, "p1": p1,
                        "c0": cf((0.0, 0.0, 0.0)) if p0 == "HRP" else [round(segments[p1]["root"][i] - segments[p0]["root"][i], 5) + 0.0 for i in range(3)] + [1, 0, 0, 0, 1, 0, 0, 0, 1],
                        "c1": [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]} for jn, p0, p1 in JOINTS],
            "hrp": [round(hz, 4), round(hy, 4), round(hx, 4)], "hip": round(HIP - hy / 2, 4),
            "stats": {"length": round(hi[0] - lo[0], 2), "height": round(hi[1] + HIP, 2), "width": round(hi[2] - lo[2], 2), "hip": round(HIP, 3)}}
    json.dump(data, open(out, "w"))
    print("json ->", out)
n = sum(len(segments[s_]["parts"]) for s_ in order)
print(f"look {LOOK} ({L['name']}): {n} parts, {len(order)} segments, scale {K:.3f}, HIP {HIP:.3f}")
print("length %.2f, height %.2f, width %.2f" % (hi[0] - lo[0], hi[1] + HIP, hi[2] - lo[2]))
