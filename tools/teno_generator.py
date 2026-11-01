#!/usr/bin/env python3
"""Tenontosaurus generator v0.1 (Mecha Dino Arena) — mockup stage (plan docs/plans/TENO_MODEL_v1.0.md).

Kepu 2026-10-31: "I want to add the teno. I want you to make a model for it that's full of character and true to the
build of the teno with character. A long tail that will be used for its attack." Answers: size "~34 studs" (built at
17 studs like the raptor / pachy / Herrera and doubled in game), stance "4 legs, rears up" (walks and idles on all fours;
rears onto the hind legs for some moves; gait comes in its own plan).

Body plan, true to Tenontosaurus (a big iguanodont-type ornithopod): deep barrel body with the highest point over the
hips, the back sloping down to the shoulders; long sturdy hind legs, shorter but strong front legs with blunt hoof-like
fingers (it walks on all fours); a medium neck and a long low head with a toothless keratin beak and big cheeks; and a
VERY long tail (more than half the body length) stiffened by bony tendons, held off the ground. Three looks for the
mockup (same proportions, different character): A "Old Gardener", B "Grumpy Bruiser", C "Skittish Strider".

Same 17-segment rig and joint names as the T-Rex / raptor / pachy / Herrera (rig 1.3). Arms = the front legs.
Dino space D = (x forward, y up, z left), origin at the hip centre (= HumanoidRootPart centre); HRP space = (z, y, -x).
All joints world-aligned (identity C0 rotation); tilts are baked into the parts.
Skin rule (SkinCatalog): every visible block uses one colour group, no hex shared between groups, none equal to a
never-paint colour (pupils 111111, mouth 6E342E, HRP A3A2A5; also E8E2D2, 963C3C, F5F5F0).
Run: python3 tools/teno_generator.py --look A|B|C --json OUT   (mockup export, the three.js viewer's format)
"""
import json, math, sys

VERSION = "0.1"
TARGET_LEN = 17.0
ROLES = ["main", "dorsal", "belly", "bands", "limbs", "claws", "eyes", "beak", "scutes", "mask"]
NEVER = {"E8E2D2", "111111", "963C3C", "6E342E", "F5F5F0", "A3A2A5"}
M = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))  # D -> HRP space

# Look parameters: proportions stay Tenontosaurus; character comes from posture, head, tail carriage and details.
LOOKS = {
    "A": dict(name="Old Gardener", hip0=4.0, headPitch=-14, lid=1.0, bodyH=1.0, bodyW=1.0, neckLen=1.0, neckRise=14, headLen=1.0, brow=0.0,
              eye=1.0, beakHook=0.15, tailRise=[6, 0, -4, -6, -6], tailThick=1.0, scuteH=0.28, plates=False,
              legThick=1.0, armThick=1.0, dewlap=True, crest=False,
              pal={"main": "8A7350", "dorsal": "5A4632", "belly": "D8C7A0", "bands": "4A3A2A", "limbs": "6E5A3E",
                   "claws": "2E2620", "eyes": "D9A23A", "beak": "3A332C", "scutes": "6B5236", "mask": "B89A6A"}),
    "B": dict(name="Grumpy Bruiser", hip0=3.7, headPitch=-10, lid=0.0, bodyH=1.18, bodyW=1.2, neckLen=0.82, neckRise=4, headLen=0.92, brow=1.0,
              eye=0.8, beakHook=0.3, tailRise=[2, -2, -3, -3, -2], tailThick=1.3, scuteH=0.45, plates=True,
              legThick=1.3, armThick=1.35, dewlap=False, crest=False,
              pal={"main": "5F6A4A", "dorsal": "3A4230", "belly": "B9B48E", "bands": "2B3022", "limbs": "4C553A",
                   "claws": "1E201A", "eyes": "E0742A", "beak": "2A2622", "scutes": "8C8A6A", "mask": "7A3A2E"}),
    "C": dict(name="Skittish Strider", hip0=4.4, headPitch=-6, lid=0.0, bodyH=0.9, bodyW=0.86, neckLen=1.22, neckRise=30, headLen=0.95, brow=-0.5,
              eye=1.35, beakHook=0.05, tailRise=[22, 14, 2, -14, -24], tailThick=0.85, scuteH=0.2, plates=False,
              legThick=0.85, armThick=0.85, dewlap=False, crest=True,
              pal={"main": "9A7A4A", "dorsal": "3E5A5A", "belly": "E6D8B0", "bands": "C24A2A", "limbs": "7A6038",
                   "claws": "2A221C", "eyes": "7FD0E6", "beak": "4A3A2A", "scutes": "2E4444", "mask": "E0B04A"}),
}
LOOK = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else "A"
L = LOOKS[LOOK]
C = {**L["pal"], "pupil": "111111", "mouth": "6E342E", "shine": "F5F5F0"}
SMOOTH = {"eyes", "pupil", "claws", "mouth", "beak", "shine"}


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


segments, order = {}, []


def seg(name, root):
    segments[name] = {"root": root, "parts": []}
    order.append(name)


def part(segname, key, size, center, pitch=0.0, yaw=0.0, roll=0.0, name=None):
    segments[segname]["parts"].append({"name": name or f"{segname}_{key}{len(segments[segname]['parts']) + 1}",
                                       "size": size, "center": center, "R": rot(pitch, yaw, roll), "key": key})


def tilt_down(dx, dy):
    return math.degrees(math.atan2(dx, -dy))


def limb(segname, key, a, b, w, d, name):
    """A block from point a to point b (x, y) at side z, thickness w (x) / d (z)."""
    (ax, ay, z), (bx, by, _) = a, b
    ln = math.hypot(bx - ax, by - ay)
    part(segname, key, (w, ln + w * 0.35, d), ((ax + bx) / 2, (ay + by) / 2, z), pitch=tilt_down(bx - ax, by - ay), name=name)


H = L["hip0"]
G = -H  # ground
bh, bw = L["bodyH"], L["bodyW"]


def side_name(base, side):
    return f"{base}{'L' if side > 0 else 'R'}"


# ---------------------------------------------------------------- torso: deep barrel, highest over the hips, back sloping to the shoulders
seg("Torso", (0.0, 0.0, 0.0))
part("Torso", "main", (2.0, 2.3 * bh, 1.75 * bw), (-0.3, 0.05, 0.0), pitch=-3, name="Torso_hips")
part("Torso", "main", (2.5, 2.6 * bh, 2.0 * bw), (1.3, -0.3 * bh, 0.0), pitch=-8, name="Torso_barrel")
part("Torso", "main", (1.7, 2.25 * bh, 1.75 * bw), (2.75, -0.72 * bh, 0.0), pitch=-15, name="Torso_chest")
part("Torso", "belly", (3.6, 0.32, 1.45 * bw), (1.35, -1.62 * bh, 0.0), pitch=-6, name="Torso_belly")
part("Torso", "belly", (0.36, 1.55 * bh, 1.45 * bw), (3.55, -0.85 * bh, 0.0), pitch=-15, name="Torso_breast")
part("Torso", "dorsal", (2.05, 0.26, 1.35 * bw), (-0.3, 1.2 * bh + 0.05, 0.0), pitch=-3, name="Torso_dorsalHips")
part("Torso", "dorsal", (2.55, 0.26, 1.55 * bw), (1.3, 1.0 * bh - 0.02, 0.0), pitch=-8, name="Torso_dorsalBack")
part("Torso", "dorsal", (1.75, 0.26, 1.35 * bw), (2.75, 0.4 * bh, 0.0), pitch=-15, name="Torso_dorsalShoulder")
# flank bands: dark saddle stripes running down from the back
for i, x in enumerate([-0.7, 0.35, 1.4, 2.4]):
    y = 0.35 * bh - max(0.0, x) * 0.17
    w = 0.9 * bw if x < 0.3 else (1.01 * bw if x < 2.0 else 0.89 * bw)
    for side in (1, -1):
        part("Torso", "bands", (0.3, 1.15 * bh, 0.05), (x, y, side * w), pitch=-8, name=side_name(f"Torso_band{i + 1}", side))
# scutes: a row of bony knobs along the spine, tallest over the hips
for i in range(8):
    x = 3.2 - i * 0.55
    top = 1.33 * bh + 0.05 if x < 0.4 else (1.13 * bh - (x - 0.6) * 0.27)
    h = L["scuteH"] * (1.15 - abs(x) * 0.08)
    part("Torso", "scutes", (0.24, h, 0.24), (x, top + h / 2 - 0.03, 0.0), pitch=-8, name=f"Torso_scute{i + 1}")
    if L["plates"] and i % 2 == 0:
        for side in (1, -1):
            part("Torso", "scutes", (0.34, 0.28, 0.12), (x, top - 0.45, side * (0.82 * bw)), pitch=-8, roll=side * 35,
                 name=side_name(f"Torso_plate{i + 1}", side))

# ---------------------------------------------------------------- neck (from the shoulders, forward and a little up)
nl, nr = L["neckLen"], L["neckRise"]
NECK_ROOT = (3.35, -0.25 * bh)
seg("Neck", (NECK_ROOT[0], NECK_ROOT[1], 0.0))
na = math.radians(nr)
nd = (math.cos(na), math.sin(na))
nn = (-math.sin(na), math.cos(na))  # neck "up" normal


def along_neck(t, up=0.0):
    return (NECK_ROOT[0] + nd[0] * t * nl + nn[0] * up, NECK_ROOT[1] + nd[1] * t * nl + nn[1] * up, 0.0)


NECK_END = along_neck(2.35)[:2]
part("Neck", "main", (1.6 * nl, 1.45 * bh, 1.2 * bw), along_neck(0.6), pitch=nr, name="Neck_base")
part("Neck", "main", (1.5 * nl, 1.08, 0.92 * (0.8 + 0.2 * bw)), along_neck(1.6), pitch=nr, name="Neck_upper")
part("Neck", "belly", (2.2 * nl, 0.2, 0.7), along_neck(1.05, -0.62), pitch=nr, name="Neck_throat")
part("Neck", "dorsal", (2.3 * nl, 0.2, 0.74), along_neck(1.1, 0.6), pitch=nr, name="Neck_dorsal")
for i in range(3):
    h = L["scuteH"] * 0.8
    part("Neck", "scutes", (0.2, h, 0.2), along_neck(0.35 + i * 0.65, 0.68 + h / 2), pitch=nr, name=f"Neck_scute{i + 1}")
if L["dewlap"]:
    part("Neck", "mask", (1.1, 0.42, 0.42), along_neck(1.85, -0.75), pitch=nr - 8, name="Neck_dewlap")

# ---------------------------------------------------------------- head (long and low; keratin beak, big cheeks, an eye full of mood)
hl = L["headLen"]
HX, HY = NECK_END[0] + 0.05, NECK_END[1]
seg("Head", (HX, HY, 0.0))
hp = L["headPitch"]
hr = math.radians(hp)
hd_ = (math.cos(hr), math.sin(hr))
hn = (-math.sin(hr), math.cos(hr))


def along_head(t, up=0.0, z=0.0):
    return (HX + hd_[0] * t * hl + hn[0] * up, HY + hd_[1] * t * hl + hn[1] * up, z)


part("Head", "main", (1.2, 1.2, 1.1), along_head(0.35, 0.12), pitch=hp, name="Head_cranium")
part("Head", "main", (1.3 * hl, 0.9, 0.86), along_head(1.35, -0.02), pitch=hp, name="Head_snout")
part("Head", "main", (0.55, 0.8, 0.74), along_head(2.15, -0.08), pitch=hp, name="Head_nose")
part("Head", "beak", (0.5, 0.62, 0.62), along_head(2.6, -0.16 - L["beakHook"] * 0.15), pitch=hp - 8, name="Head_beak")
part("Head", "beak", (0.26, 0.3 + L["beakHook"], 0.42), along_head(2.86, -0.38 - L["beakHook"] * 0.35), pitch=hp - 28, name="Head_beakHook")
part("Head", "mouth", (2.0 * hl, 0.08, 0.8), along_head(1.4, -0.47), pitch=hp, name="Head_mouth")
part("Head", "dorsal", (1.9 * hl, 0.14, 0.62), along_head(1.15, 0.47), pitch=hp, name="Head_top")
e = L["eye"]
for side in (1, -1):
    part("Head", "main", (0.55, 0.45, 0.32), along_head(0.55, 0.42, side * 0.46), pitch=hp, name=side_name("Head_eyebump", side))
    part("Head", "eyes", (0.32 * e, 0.28 * e, 0.06), along_head(0.6, 0.42, side * 0.63), pitch=hp, name=side_name("Head_eye", side))
    part("Head", "pupil", (0.11 * e, 0.2 * e, 0.03), along_head(0.66, 0.42, side * 0.665), pitch=hp, name=side_name("Head_pupil", side))
    part("Head", "shine", (0.06 * e, 0.06 * e, 0.02), along_head(0.62, 0.48 + 0.04 * e, side * 0.68), pitch=hp, name=side_name("Head_shine", side))
    lid = L["lid"]
    if lid > 0:  # heavy sleepy lid over the top of the eye
        part("Head", "dorsal", (0.42 * e, 0.16 * e * lid, 0.08), along_head(0.6, 0.42 + 0.14 * e - 0.04 * lid, side * 0.66), pitch=hp + 4, name=side_name("Head_lid", side))
    if L["brow"] > 0:  # angry brow ridge
        part("Head", "dorsal", (0.62, 0.22, 0.26), along_head(0.6, 0.66, side * 0.5), pitch=hp - 18 * L["brow"], name=side_name("Head_brow", side))
    part("Head", "mask", (0.95 * hl, 0.5, 0.08), along_head(1.15, -0.12, side * 0.44), pitch=hp, name=side_name("Head_cheek", side))
    part("Head", "mask", (0.14, 0.12, 0.05), along_head(2.32, 0.2, side * 0.37), pitch=hp, name=side_name("Head_nostril", side))
if L["crest"]:
    for i in range(3):
        part("Head", "bands", (0.16, 0.5 - i * 0.1, 0.14), along_head(0.02 - i * 0.26, 0.72 - i * 0.06), pitch=hp - 38, name=f"Head_crest{i + 1}")

# ---------------------------------------------------------------- jaw (lower beak; rest closed)
JR = along_head(0.25, -0.45)
seg("Jaw", (JR[0], JR[1], 0.0))
part("Jaw", "main", (2.0 * hl, 0.38, 0.8), along_head(1.35, -0.7), pitch=hp, name="Jaw_lower")
part("Jaw", "beak", (0.44, 0.34, 0.58), along_head(2.42, -0.76), pitch=hp, name="Jaw_beak")
part("Jaw", "belly", (1.8 * hl, 0.1, 0.62), along_head(1.25, -0.9), pitch=hp, name="Jaw_under")

# ---------------------------------------------------------------- front legs (Arm segments: shoulder -> ground, blunt hoof fingers)
at = L["armThick"]
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.78 * bw
    sh = (2.8, -1.05 * bh, z)
    el = (2.5, G * 0.62, z)
    wr = (2.82, G + 0.45, z)
    seg(f"Arm{s}", sh)
    part(f"Arm{s}", "main", (0.95 * at, 1.0 * at, 0.42 * at), (sh[0] + 0.05, sh[1] - 0.15, z + side * 0.06), pitch=-10, name=f"Arm{s}_shoulder")
    limb(f"Arm{s}", "main", sh, el, 0.62 * at, 0.52 * at, f"Arm{s}_upper")
    limb(f"Arm{s}", "limbs", el, wr, 0.46 * at, 0.44 * at, f"Arm{s}_fore")
    part(f"Arm{s}", "limbs", (0.66 * at, 0.42, 0.58 * at), (wr[0] + 0.1, G + 0.21, z), name=f"Arm{s}_hand")
    for i, dz in enumerate((-0.19, 0.0, 0.19)):
        part(f"Arm{s}", "claws", (0.22, 0.2, 0.15), (wr[0] + 0.46, G + 0.1, z + dz * at), name=f"Arm{s}_hoof{i + 1}")

# ---------------------------------------------------------------- tail (very long, stiff, tapering; held off the ground)
tt = L["tailThick"]
tail = [(2.05, (2.2, 1.85 * bh * tt, 1.5 * bw * tt)), (2.0, (2.15, 1.35 * tt, 1.12 * tt)), (1.95, (2.1, 0.98 * tt, 0.82 * tt)),
        (1.85, (2.0, 0.66 * tt, 0.56 * tt)), (1.75, (1.9, 0.4 * tt, 0.34 * tt))]
_root = (-1.1, 0.3)
for i, (seglen, size) in enumerate(tail):
    name = f"Tail{i + 1}"
    rise = L["tailRise"][i]
    a = math.radians(rise)
    d = (-math.cos(a), math.sin(a))
    up = (math.sin(a), math.cos(a))  # perpendicular, pointing up
    seg(name, (_root[0], _root[1], 0.0))
    c = (_root[0] + d[0] * (size[0] / 2 - 0.08), _root[1] + d[1] * (size[0] / 2 - 0.08))

    def at_(t, u=0.0):
        return (_root[0] + d[0] * t + up[0] * u, _root[1] + d[1] * t + up[1] * u, 0.0)

    part(name, "main", size, (c[0], c[1], 0.0), pitch=-rise, name=f"{name}_main")
    part(name, "dorsal", (size[0], 0.16, size[2] * 0.84), at_(size[0] / 2 - 0.08, size[1] / 2), pitch=-rise, name=f"{name}_dorsal")
    part(name, "belly", (size[0] * 0.9, 0.12, size[2] * 0.7), at_(size[0] / 2 - 0.08, -size[1] / 2), pitch=-rise, name=f"{name}_under")
    if i >= 1:
        part(name, "bands", (0.34, size[1] + 0.06, size[2] + 0.06), at_(seglen * 0.55), pitch=-rise, name=f"{name}_band")
    h = L["scuteH"] * (1.0 - i * 0.15)
    part(name, "scutes", (0.22, h, 0.22), at_(seglen * 0.3, size[1] / 2 + h / 2), pitch=-rise, name=f"{name}_scute1")
    if i < 3:
        part(name, "scutes", (0.22, h, 0.22), at_(seglen * 0.8, size[1] / 2 + h / 2), pitch=-rise, name=f"{name}_scute2")
    if L["plates"] and i >= 1:
        for side in (1, -1):
            part(name, "scutes", (0.3, 0.2, 0.18), (at_(seglen * 0.3)[0], at_(seglen * 0.3)[1], side * (size[2] / 2 + 0.06)), pitch=-rise, roll=side * 20,
                 name=side_name(f"{name}_plate", side))
    _root = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)

# ---------------------------------------------------------------- hind legs (long and sturdy; meaty thighs; three-toed feet)
lt = L["legThick"]
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.86 * bw
    hip, knee, ankle, ball = (-0.25, -0.2, z), (0.45, G * 0.55, z), (-0.05, G * 0.86, z), (0.35, G + 0.2, z)
    seg(f"Leg{s}", hip)
    part(f"Leg{s}", "main", (1.65 * lt, 2.1 * bh, 0.5 * lt), (-0.05, -0.75, z + side * 0.14), pitch=12, name=f"Leg{s}_haunch")
    limb(f"Leg{s}", "main", hip, knee, 0.95 * lt, 0.78 * lt, f"Leg{s}_thigh")
    seg(f"Shin{s}", knee)
    part(f"Shin{s}", "limbs", (0.68 * lt, 0.6, 0.66 * lt), (knee[0] + 0.05, knee[1], z), name=f"Shin{s}_knee")
    limb(f"Shin{s}", "limbs", knee, ankle, 0.56 * lt, 0.56 * lt, f"Shin{s}_shin")
    seg(f"Foot{s}", ankle)
    limb(f"Foot{s}", "limbs", ankle, ball, 0.46 * lt, 0.48 * lt, f"Foot{s}_meta")
    for i, yw in enumerate((-20, 0, 20)):
        ln = 1.05 if yw == 0 else 0.85
        dx, dz = math.cos(math.radians(yw)) * ln / 2, -math.sin(math.radians(yw)) * ln / 2
        part(f"Foot{s}", "limbs", (ln, 0.26, 0.3 * lt), (0.3 + dx, G + 0.13, z + dz), yaw=yw, name=f"Foot{s}_toe{i + 1}")
        part(f"Foot{s}", "claws", (0.26, 0.22, 0.26 * lt), (0.3 + dx * 2 + 0.07, G + 0.11, z + dz * 2), yaw=yw, name=f"Foot{s}_hoof{i + 1}")

JOINTS = [("RootJoint", "HRP", "Torso"), ("Neck", "Torso", "Neck"), ("Head", "Neck", "Head"), ("Jaw", "Head", "Jaw"),
          ("ArmL", "Torso", "ArmL"), ("ArmR", "Torso", "ArmR"), ("Tail1", "Torso", "Tail1"), ("Tail2", "Tail1", "Tail2"),
          ("Tail3", "Tail2", "Tail3"), ("Tail4", "Tail3", "Tail4"), ("Tail5", "Tail4", "Tail5"),
          ("LegL", "Torso", "LegL"), ("LegR", "Torso", "LegR"), ("KneeL", "LegL", "ShinL"), ("KneeR", "LegR", "ShinR"),
          ("AnkleL", "ShinL", "FootL"), ("AnkleR", "ShinR", "FootR")]


def bounds():
    lo, hi = [1e9] * 3, [-1e9] * 3
    for n in order:
        for p in segments[n]["parts"]:
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
for n in order:
    sg = segments[n]
    sg["root"] = tuple(v * K for v in sg["root"])
    for p in sg["parts"]:
        p["size"] = tuple(v * K for v in p["size"])
        p["center"] = tuple(v * K for v in p["center"])
HIP = H * K
HRP_SIZE_D = tuple(v * K for v in (3.2, 2.1, 1.2))
lo, hi = bounds()


def cf(pos_d, R_d=None):
    R = matmul(M, R_d if R_d else rot())
    p = mv(M, pos_d)
    return [round(v, 5) + 0.0 for v in list(p) + [R[0][0], R[0][1], R[0][2], R[1][0], R[1][1], R[1][2], R[2][0], R[2][1], R[2][2]]]


# colour checks (the skin rule)
hexes = [C[r] for r in ROLES]
assert len(set(hexes)) == len(hexes), "two colour groups share a hex"
assert not (NEVER & set(hexes)), "a group uses a never-paint colour"

if "--json" in sys.argv:
    out = sys.argv[sys.argv.index("--json") + 1]
    hx, hy, hz = HRP_SIZE_D
    data = {"look": LOOK, "name": L["name"], "roles": {r: C[r] for r in ROLES},
            "segs": [{"n": n, "root": cf(segments[n]["root"]),
                      "parts": [{"n": p["name"], "s": [round(v, 4) for v in p["size"]], "cf": cf(p["center"], p["R"]),
                                 "c": C[p["key"]], "k": p["key"]} for p in segments[n]["parts"]]} for n in order],
            "joints": [{"n": jn, "p0": p0, "p1": p1,
                        "c0": cf((0.0, 0.0, 0.0)) if p0 == "HRP" else [round(segments[p1]["root"][i] - segments[p0]["root"][i], 5) + 0.0 for i in range(3)] + [1, 0, 0, 0, 1, 0, 0, 0, 1],
                        "c1": [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]} for jn, p0, p1 in JOINTS],
            "hrp": [round(hz, 4), round(hy, 4), round(hx, 4)], "hip": round(HIP - hy / 2, 4)}
    json.dump(data, open(out, "w"))
    print("json ->", out)
n = sum(len(segments[s]["parts"]) for s in order)
tail_len = sum(t[0] for t in tail) * K
print(f"look {LOOK} ({L['name']}): {n} parts, {len(order)} segments, scale {K:.3f}, HIP {HIP:.3f}")
print("length %.2f, height %.2f, width %.2f, tail %.2f (%.0f%%), lowest %.3f vs ground %.3f" % (
    hi[0] - lo[0], hi[1] + HIP, hi[2] - lo[2], tail_len, tail_len / (hi[0] - lo[0]) * 100, lo[1], -HIP))
