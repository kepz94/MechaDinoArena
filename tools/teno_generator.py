#!/usr/bin/env python3
"""Tenontosaurus generator v1.3 (Mecha Dino Arena) — mockup stage (plan docs/plans/TENO_MODEL_v1.0.md).

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
v0.2 (Kepu: "The tail isn't long enough. I want this to be cartoonish with a lot of character super easily
  identifiable"): cartoon looks (big heads, huge eyes, coloured beaks, tail ~62%). v0.3 (Kepu on C Goofy Noodle: "I need
  the tail to be more longer and thicker"): C tail x1.22 longer, x1.45 thicker; body scale kept (BODY_K 0.84), so the
  dino is ~24.9 studs at scale 1 (~50 in game). v1.0 (Kepu "Yes, build v0.3"): the data file for look C.
v1.1 (plan docs/plans/TENO_KIT_v1.0.md Task 1, MDA-172): kit attributes (tank; tap = scratch, hold = rear tail slam with 3
  charges / 8 s each; J2 rearing leap). Geometry unchanged.
v1.2 (Kepu 2026-10-31 after v302: "40 damage is way too strong. Lower it to 20"): TenoSlamDamage 40 -> 20. Nothing else.
v1.3 (Kepu 2026-10-31 after v309: "It's a little too cartoonish. Go with the first option from your mockups but with the
  enlarged tail that I requested"): mockup v0.4 looks D and E = the v0.1 A "Old Gardener" (v0.1 head via classic=True, v0.1
  body and colours) with the v0.3 tail size (tailLen 1.22, tailThick 1.45, body scale BODY_K like C); D keeps the Old
  Gardener's level tail carriage, E the Goofy Noodle's S-curve. Kepu picked "E · S-curve tail": TenoModelData 1.3 = look E
  (same 17-segment rig, joint names, kit attributes and tail size; Old Gardener head, body and colours). Look C stays
  reproducible with --look C (TenoModelData 1.2 geometry).
Run: python3 tools/teno_generator.py                         (writes src/shared/Models/TenoModelData.luau, look C)
     python3 tools/teno_generator.py --look A|B|C --json OUT  (mockup export, the three.js viewer's format)
"""
import json, math, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Models", "TenoModelData.luau")
TREX = os.path.join(ROOT, "src", "shared", "Models", "TRexModelData.luau")

VERSION = "1.3"
BODY_K = 0.84  # v0.3: the v0.2 C scale
TARGET_LEN = 20.0  # v0.2: the body keeps about its v0.1 size, the much longer tail adds length (~40 studs in game)
ROLES = ["main", "dorsal", "belly", "bands", "limbs", "claws", "eyes", "beak", "scutes", "mask"]
NEVER = {"E8E2D2", "111111", "963C3C", "6E342E", "F5F5F0", "A3A2A5"}
M = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))  # D -> HRP space

# Look parameters: proportions stay Tenontosaurus; character comes from posture, head, tail carriage and details.
LOOKS = {  # v0.2 (Kepu: "The tail isn't long enough. I want this to be cartoonish with a lot of character super easily identifiable")
    "A": dict(name="Grandpa Whip", hip0=3.5, headPitch=-12, lid=1.0, bodyH=1.12, bodyW=1.08, neckLen=0.85, neckRise=12, headLen=0.95,
              hs=1.45, brow=0.0, eye=1.9, beakHook=0.25, smile=1, tailRise=[8, 0, -6, -4, 30], tailThick=1.1, scuteH=0.3,
              plates=False, legThick=1.15, armThick=1.1, dewlap=True, crest=False, rings=False,
              pal={"main": "A88A5A", "dorsal": "6E5434", "belly": "EADBB4", "bands": "5A4228", "limbs": "8A6E46",
                   "claws": "3A2E22", "eyes": "F2E2A0", "beak": "E8A23A", "scutes": "7A5C38", "mask": "D2B484"}),
    "B": dict(name="Grumpy Tank", hip0=3.3, headPitch=-6, lid=0.45, bodyH=1.25, bodyW=1.28, neckLen=0.72, neckRise=2, headLen=0.9,
              hs=1.35, brow=1.0, eye=1.5, beakHook=0.45, smile=-1, tailRise=[3, -1, -2, -2, -1], tailThick=1.35, scuteH=0.48,
              plates=True, legThick=1.35, armThick=1.35, dewlap=False, crest=False, rings=True,
              pal={"main": "6F7E56", "dorsal": "485436", "belly": "D2CC9E", "bands": "333C26", "limbs": "5A6646",
                   "claws": "22261C", "eyes": "F3C64A", "beak": "6A6E78", "scutes": "B8B48A", "mask": "9C4A36"}),
    "C": dict(name="Goofy Noodle", hip0=3.9, headPitch=-4, lid=0.0, bodyH=1.0, bodyW=0.95, neckLen=1.15, neckRise=34, headLen=0.95,
              hs=1.5, brow=-0.5, eye=2.3, beakHook=0.1, smile=1, tailRise=[26, 16, 2, -14, -30], tailThick=1.45, tailLen=1.22, scuteH=0.22,
              plates=False, legThick=1.0, armThick=1.0, dewlap=False, crest=True, rings=False,
              pal={"main": "D99A4A", "dorsal": "2E8C8A", "belly": "F6E6BE", "bands": "C83A3A", "limbs": "B87A36",
                   "claws": "3A2A1E", "eyes": "FFFFFF", "beak": "F2D04A", "scutes": "1E6462", "mask": "F2B8A0"}),
}
# v1.3 (mockup v0.4): the v0.1 A Old Gardener (its exact v0.1 parameters and colours) + the v0.3 tail size
_OLD = dict(hip0=4.0, headPitch=-14, lid=1.0, bodyH=1.0, bodyW=1.0, neckLen=1.0, neckRise=14, headLen=1.0, hs=1.0, brow=0.0,
            eye=1.0, beakHook=0.15, smile=0, tailThick=1.45, tailLen=1.22, scuteH=0.28, plates=False, legThick=1.0, armThick=1.0,
            dewlap=True, crest=False, rings=False, classic=True,
            pal={"main": "8A7350", "dorsal": "5A4632", "belly": "D8C7A0", "bands": "4A3A2A", "limbs": "6E5A3E",
                 "claws": "2E2620", "eyes": "D9A23A", "beak": "3A332C", "scutes": "6B5236", "mask": "B89A6A"})
LOOKS["D"] = dict(_OLD, name="Old Gardener · big tail (level)", tailRise=[6, 0, -4, -6, -6])  # the v0.1 A carriage
LOOKS["E"] = dict(_OLD, name="Old Gardener · big tail (S-curve)", tailRise=[26, 16, 2, -14, -30])  # the C carriage
LOOK = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else "E"  # v1.3: Kepu "E · S-curve tail" (v1.0-1.2: C Goofy Noodle)
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

# ---------------------------------------------------------------- head (cartoon: big, huge eyes, chunky coloured beak, puffy cheeks)
hl, hs = L["headLen"], L["hs"]
HX, HY = NECK_END[0] + 0.05, NECK_END[1]
seg("Head", (HX, HY, 0.0))
hp = L["headPitch"]
hr = math.radians(hp)
hd_ = (math.cos(hr), math.sin(hr))
hn = (-math.sin(hr), math.cos(hr))


def along_head(t, up=0.0, z=0.0):
    return (HX + hd_[0] * t * hl * hs + hn[0] * up * hs, HY + hd_[1] * t * hl * hs + hn[1] * up * hs, z * hs)


def hpart(key, size, t, up, z=0.0, dp=0.0, name=None):
    part("Head", key, tuple(v * hs for v in size), along_head(t, up, z), pitch=hp + dp, name=name)


if not L.get("classic"):  # v0.2+ cartoon head
    hpart("main", (1.25, 1.25, 1.15), 0.35, 0.18, name="Head_cranium")
    hpart("main", (1.3 * hl, 0.92, 0.9), 1.3, -0.02, name="Head_snout")
    hpart("main", (0.6, 0.85, 0.8), 2.05, -0.06, name="Head_nose")
    hpart("beak", (0.62, 0.7, 0.72), 2.55, -0.14 - L["beakHook"] * 0.12, dp=-8, name="Head_beak")
    hpart("beak", (0.32, 0.3 + L["beakHook"], 0.5), 2.86, -0.38 - L["beakHook"] * 0.3, dp=-30, name="Head_beakHook")
    hpart("mouth", (1.9 * hl, 0.08, 0.84), 1.3, -0.47, name="Head_mouth")
    hpart("mouth", (0.32, 0.08, 0.86), 0.42, -0.47 + 0.1 * L["smile"], dp=-30 * L["smile"], name="Head_mouthEnd")
    hpart("dorsal", (1.9 * hl, 0.14, 0.66), 1.15, 0.47, name="Head_top")
    e = L["eye"]
    for side in (1, -1):
        hpart("main", (0.36 * e, 0.34 * e, 0.3), 0.5, 0.44, side * 0.44, name=side_name("Head_eyebump", side))
        hpart("eyes", (0.3 * e, 0.3 * e, 0.06), 0.52, 0.44, side * 0.6, name=side_name("Head_eye", side))
        hpart("pupil", (0.13 * e, 0.17 * e, 0.03), 0.6, 0.42, side * 0.635, name=side_name("Head_pupil", side))
        hpart("shine", (0.05 * e, 0.05 * e, 0.02), 0.56, 0.48 + 0.03 * e, side * 0.65, name=side_name("Head_shine", side))
        lid = L["lid"]
        if lid > 0:  # heavy sleepy lid over the top of the eye
            hpart("dorsal", (0.34 * e, 0.16 * e * lid, 0.1), 0.52, 0.44 + 0.15 * e - 0.08 * e * lid, side * 0.63, dp=6, name=side_name("Head_lid", side))
        if L["brow"] > 0:  # angry slanted brow
            hpart("dorsal", (0.44 * e, 0.12 * e, 0.22), 0.55, 0.47 + 0.17 * e, side * 0.56, dp=-22, name=side_name("Head_brow", side))
        elif L["brow"] < 0:  # surprised raised brow
            hpart("dorsal", (0.3 * e, 0.06 * e, 0.16), 0.52, 0.5 + 0.22 * e, side * 0.55, dp=14, name=side_name("Head_brow", side))
        hpart("mask", (0.85 * hl, 0.62, 0.1), 1.05, -0.12, side * 0.47, name=side_name("Head_cheek", side))
        hpart("mask", (0.14, 0.12, 0.05), 2.22, 0.24, side * 0.4, name=side_name("Head_nostril", side))
    if L["crest"]:
        for i in range(3):
            hpart("bands", (0.16, 0.5 - i * 0.1, 0.14), 0.02 - i * 0.2, 0.74 - i * 0.05, dp=-38, name=f"Head_crest{i + 1}")

    # ---------------------------------------------------------------- jaw (lower beak; rest closed)
    JR = along_head(0.25, -0.45)
    seg("Jaw", (JR[0], JR[1], 0.0))
    for key, size, t, up, nm in [("main", (1.95 * hl, 0.4, 0.84), 1.3, -0.7, "Jaw_lower"), ("beak", (0.5, 0.36, 0.62), 2.38, -0.74, "Jaw_beak"),
                                 ("belly", (1.75 * hl, 0.1, 0.66), 1.2, -0.92, "Jaw_under")]:
        part("Jaw", key, tuple(v * hs for v in size), along_head(t, up), pitch=hp, name=nm)
else:  # v1.3: the v0.1 head (true-to-animal proportions, small eyes; hs = 1, so along_head is the v0.1 one)
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
TL = L.get("tailLen", 1.0)  # v0.3 (Kepu on C: "I need the tail to be more longer and thicker")
tail = [(3.3, (3.45, 1.85 * bh * tt, 1.5 * bw * tt)), (3.25, (3.4, 1.3 * tt, 1.08 * tt)), (3.2, (3.35, 0.9 * tt, 0.76 * tt)),
        (3.15, (3.3, 0.58 * tt, 0.5 * tt)), (3.1, (3.2, 0.34 * tt, 0.3 * tt))]  # v0.2: ~16 long (was 9.6), about 62% of the length
_root = (-1.1, 0.3)
tail = [(sl * TL, (sz[0] * TL, sz[1], sz[2])) for sl, sz in tail]
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
        for j, f in enumerate((0.35, 0.75) if L["rings"] else (0.55,)):
            part(name, "bands", (0.34, size[1] + 0.08, size[2] + 0.08), at_(seglen * f), pitch=-rise, name=f"{name}_band{j + 1}")
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
if "tailLen" in L:  # v0.3: keep the v0.2 body size; the longer tail only adds length
    K = BODY_K
for n in order:
    sg = segments[n]
    sg["root"] = tuple(v * K for v in sg["root"])
    for p in sg["parts"]:
        p["size"] = tuple(v * K for v in p["size"])
        p["center"] = tuple(v * K for v in p["center"])
HIP = H * K
HRP_SIZE_D = tuple(v * K for v in (3.2, 2.1, 1.2))
lo, hi = bounds()
HIP = max(HIP, -lo[1])  # the lowest block (a hoof) sits on the ground


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
if "--json" not in sys.argv:
    # ------------------------------------------------------------ full data file (v1.0), same layout as HerreraModelData
    def fmt(v):
        return "{" + ",".join(f"{x:g}" for x in v) + "}"
    used = {C[p["key"]] for n_ in order for p in segments[n_]["parts"]}
    assert used <= set(hexes) | {"111111", "6E342E", "F5F5F0"}, "a block colour is not a role or never-paint"
    hx, hy, hz = HRP_SIZE_D
    body = [f'\thrp = {{size = {{{hz:.4g},{hy:.4g},{hx:.4g}}}, color = "A3A2A5", surface = {{"Studs","Inlet","Smooth","Smooth","Smooth","Smooth"}}}},',
            f'\thumanoid = {{RigType = "R15", HipHeight = {HIP - hy / 2:.4g}, DisplayDistanceType = "None"}},',
            '\tmodelStreamingMode = "Atomic",', "\tsegments = {"]
    for n_ in order:
        sg = segments[n_]
        body.append(f'\t\t{{name = "{n_}", root = {fmt(cf(sg["root"]))}, parts = {{')
        for p in sg["parts"]:
            surface = '"Smooth"' if p["key"] in SMOOTH else '"Studs"'
            body.append(f'\t\t\t{{name = "{p["name"]}", size = {fmt([round(v, 4) for v in p["size"]])}, '
                        f'cf = {fmt(cf(p["center"], p["R"]))}, color = "{C[p["key"]]}", surface = {surface}}},')
        body.append("\t\t}},")
    body.append("\t},")
    body.append("\tjoints = {")
    for jn, p0, p1 in JOINTS:
        c0 = cf((0.0, 0.0, 0.0)) if p0 == "HRP" else [round(segments[p1]["root"][i] - segments[p0]["root"][i], 5) + 0.0 for i in range(3)] + [1, 0, 0, 0, 1, 0, 0, 0, 1]
        body.append(f'\t\t{{name = "{jn}", part0 = "{p0}", part1 = "{p1}", c0 = {fmt(c0)}, c1 = {{0,0,0,1,0,0,0,1,0,0,0,1}}}},')
    body.append("\t},")
    trex = open(TREX).read()
    block = trex[trex.index("attributes = {"):]
    block = block[:block.index("\n\t},")]
    attrs = {m.group(1): m.group(2) for m in re.finditer(r'^\t\t(\w+) = (.+?),$', block, re.M)}
    attrs.update({"Species": '"Teno"', "StyleVersion": '"1.0"', "TenoModelVersion": f'"{VERSION}"', "DisplayName": '"Tenontosaurus"',
                  "RigHipHeight": f"{HIP:.4g}", "BiteEnabled": "false", "PounceEnabled": "false", "RamEnabled": "false",
                  "RoarEnabled": "false", "JumpEnabled": "false", "CreepEnabled": "false"})
    attrs.update({  # v1.1: kit (plan TENO_KIT_v1.0 Task 1)
        "DinoMaxHealth": "150", "MoveWalkSpeed": "30", "MoveRunSpeed": "52", "CameraStartZoom": "24", "TurnLimitRate": "240",
        "TenoAttackEnabled": "true", "TenoPoseEnabled": "true",
        "TenoScratchDamage": "8", "TenoScratchGap": "0.5", "TenoScratchReach": "5.5", "TenoScratchShove": "6",
        "TenoSlamDamage": "20", "TenoSlamCharges": "3", "TenoSlamRefill": "8", "TenoSlamHoldMin": "0.22",
        "TenoSlamRange": "15", "TenoSlamArc": "220", "TenoSlamToss": "35", "TenoSlamStun": "1", "TenoSlamDropTime": "0.13",
        "JumpEnabled": "true", "JumpWindup": "0.28", "JumpLaunchPower": "54", "JumpBoost": "14", "JumpBoostMinSpeed": "2",
        "JumpAirHold": "true", "JumpStaminaCost": "0", "JumpCooldown": "1",
    })
    attrs.pop("StarterCharacterVersion", None)
    lines = [f"-- TenoModelData v{VERSION} (Mecha Dino Arena) — block-style Tenontosaurus ({LOOK} {L["name"]}, long thick tail), rig 1.3 joint names, skin-ready colour groups.",
             "-- Generated by tools/teno_generator.py (do not edit by hand; change the generator and re-run). Plan docs/plans/TENO_MODEL_v1.0.md.",
             f"-- Scale: {hi[0] - lo[0]:.2f} studs long (tail {sum(t[0] for t in tail) * K:.2f}), hip {HIP:.4g} studs; doubled in game like the raptor / pachy / Herrera (~{2 * (hi[0] - lo[0]):.0f}).",
             f"-- Colour groups (Classic = {L['name']}): " + ", ".join(f"{r} {C[r]}" for r in ROLES) + "; never painted: pupil 111111, mouth 6E342E, eye shine F5F5F0.",
             "-- All CFrames are relative to the HumanoidRootPart; sizes in studs; colors hex RGB. Rebuild with DinoModelBuilder.build(require(TenoModelData)).",
             "return {", f'\tversion = "{VERSION}", species = "Teno", style = "1.0", rig = "1.3",'] + body + ["\tattributes = {"] + [f"\t\t{k} = {attrs[k]}," for k in sorted(attrs)] + ["\t},", "}"]
    open(OUT, "w").write("\n".join(lines) + "\n")
    print("data ->", OUT, f"({len(attrs)} attributes)")
n = sum(len(segments[s]["parts"]) for s in order)
tail_len = sum(t[0] for t in tail) * K
print(f"look {LOOK} ({L['name']}): {n} parts, {len(order)} segments, scale {K:.3f}, HIP {HIP:.3f}")
print("length %.2f, height %.2f, width %.2f, tail %.2f (%.0f%%), lowest %.3f vs ground %.3f" % (
    hi[0] - lo[0], hi[1] + HIP, hi[2] - lo[2], tail_len, tail_len / (hi[0] - lo[0]) * 100, lo[1], -HIP))
