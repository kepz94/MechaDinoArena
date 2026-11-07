#!/usr/bin/env python3
"""Troodon generator v1.1 (Mecha Dino Arena) — writes src/shared/Models/TroodonModelData.luau.
v0.2: long drooping arms on every look (--arms folded = v0.1).
v1.0 (Kepu 2026-11-01: "I like the night watcher. Let's save this model"): Classic = B Night Watcher (default look) with the
v0.2 drooping arms; without --json the generator writes the data file (geometry + the T-Rex's attributes with every move
off, Species "Troodon"). Looks A / C stay reproducible with --look for the mockup.

Kepu 2026-11-01: "Let's start planning for the next Dino after the teno. Are you able to make models for a troodon"
(reference picture: slim green troodon with brown stripes, big yellow eyes, a long narrow toothy snout, a feather crest
down the neck and back, feather fans on the arms, a feathered tail tip, long slender legs, raised sickle toe claws).
Answers: size "Between Herrera and raptor"; style "True to the animal"; feathers "Yes, like the picture"; roster "Day 1".

Same 17-segment rig and joint names as the T-Rex / raptor / pachy / Herrera / teno (rig 1.3). Dino space D = (x forward,
y up, z left), origin at the hip centre (= HumanoidRootPart centre). The whole body is scaled so its length is TARGET_LEN
studs (Herrera 11.2, raptor 12.85; doubled in game like them: ~24 studs vs 22.4 / 25.7).
Skin rule: every visible block uses one authored colour per group (10 groups), no hex shared between groups, none equal
to a never-paint colour (teeth E8E2D2, pupils 111111, mouth 6E342E, HRP A3A2A5).
Looks (mockup docs/mockups/troodon_model_options.html):
  A Forest Stalker - like the picture: green with brown stripes, a brown crest, feathers as drawn, neck level.
  B Night Watcher  - dusk grey-brown, bigger eyes (troodon had very large eyes), a fuller feather coat, neck low.
  C Sand Runner    - sandy with dark stripes, a lighter feather coat, longer legs, neck held up.
The data file (src/shared/Models/TroodonModelData.luau, attributes, Classic colours) comes after Kepu picks.
v1.1 kit attributes (MDA-330, plan docs/plans/TROODON_KIT_v1.0.md Task 1; Kepu 2026-11-06 15:38 "Let's go with your
recommendations": attack A Glow Pod Toss, jump J2 Evade Hop, the mockup v0.1 numbers): only the KIT_ATTRS keys and
TroodonModelVersion change; the body is unchanged; --no-kit = the 1.0 attributes.
v1.2 (Kepu 2026-11-06 17:38: "This is supposed to be in between a Raptor and herera and the Raptor is chasing me down
easily. Also the spit range is unplayable as a base form. Increase that" -> picks "86 / 46", "80 studs"): KIT_V12 on top
of KIT_ATTRS: MoveRunSpeed 86 / MoveWalkSpeed 46 (raptor 78, Herrera 90), TrooPodRange / TrooAssistMax 40 (80 studs in
game; was 22.5 = 45). --v11 = the 1.1 numbers.
v1.3 (Troodon Flap & Glide, MDA-340, plan docs/plans/TROODON_FLAP_GLIDE_v1.0.md Task 1; Kepu 2026-11-06 17:50 "Build",
mockup v0.2 J3): KIT_V13 on top: JUMP = a leap (JumpLaunchPower 59, ~11 studs) + 2 air flaps (JumpDoubleEnabled,
JumpAirJumps 2, JumpDoubleMul 0.80, JumpDoubleForward 0) + an automatic glide after the last one (GliderEnabled, GliderAuto,
GliderFall 8); the Evade Hop off (JumpHopBack false, JumpCharges 0, JumpCooldown 0.5; its Hop keys stay). --v12 = 1.2.
v1.4 (Kepu 2026-11-06 19:02 "Let's make them bigger flaps double it"): KIT_V14 on top: JumpDoubleMul 1.13 (a flap sets the
climb to 59 x 1.13 = 66.7 studs/s: ~11.3 studs per flap, double the measured 5.58 at 0.8). --v13 = 1.3.
Run: python3 tools/troodon_generator.py                (writes the data file: look B, drooping arms)
     python3 tools/troodon_generator.py --look A|B|C [--arms droop|folded] --json OUT   (the three.js viewer's format)
v1.5 (Troodon parts, MDA-345, plan docs/plans/TROODON_PARTS_v1.0.md ticket 1; Kepu 2026-11-06 21:24 "areas should be doubled" ->
"Yes, main zone 20->40 too"): KIT_V15 on top: TrooZoneRadius 10 (the glow zone 40 studs wide at the 2x body; per-second
numbers unchanged). --v14 = 1.4.
"""
import json, math, os, sys

import re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Models", "TroodonModelData.luau")
TREX = os.path.join(ROOT, "src", "shared", "Models", "TRexModelData.luau")
SMOOTH = {"eyes", "pupil", "tooth", "claws", "mouth"}
VERSION = "1.0"
VERSION = "1.1"  # v1.1 kit attributes (MDA-330, plan docs/plans/TROODON_KIT_v1.0.md Task 1); --no-kit = 1.0
VERSION = "1.1" if "--v11" in sys.argv else "1.2"  # v1.2 speed 86 / 46, pod range 80 studs (Kepu 2026-11-06 17:38)
V13 = "--v11" not in sys.argv and "--v12" not in sys.argv  # v1.3 Flap & Glide
if V13: VERSION = "1.3"
V14 = V13 and "--v13" not in sys.argv  # v1.4 flaps doubled
if V14: VERSION = "1.4"
V15 = V14 and "--v14" not in sys.argv  # v1.5 main zone doubled
if V15: VERSION = "1.5"
# v1.1 numbers (distances at scale 1, x2 body in game). The plan's "WalkSpeed 39 / RunSpeed 74" are the game's speed keys
# MoveWalkSpeed / MoveRunSpeed (the Dilo's KIT_ATTRS pattern). JumpHopPower 40: Kepu 2026-11-06 hop ~5.3 studs high (MDA-335; ~4 studs made the Humanoid land at the top).
KIT_ATTRS = {
    "DinoMaxHealth": "55", "MoveWalkSpeed": "39", "MoveRunSpeed": "74",
    "TrooAttackEnabled": "true", "TrooPodWindup": "0.34", "TrooPodFlight": "0.55", "TrooPodRange": "22.5",
    "TrooPodCharges": "2", "TrooPodRefill": "3", "TrooMinGap": "0.35", "TrooAssistAngle": "30", "TrooAssistMax": "22.5",
    "TrooPodLead": "true",
    "TrooZoneRadius": "5", "TrooZoneTime": "3", "TrooPodDamage": "6", "TrooZoneDps": "3", "TrooZoneSlowMul": "0.75",
    "TrooZoneHeal": "5", "TrooSelfHeal": "2",
    "JumpEnabled": "true", "JumpHopBack": "true", "JumpCharges": "2", "JumpCooldown": "4", "JumpHopDistance": "9",
    "JumpHopTime": "0.42", "JumpHopWindup": "0.1", "JumpHopPower": "40", "JumpStaminaCost": "0", "TenoLeapOnJump": "false",
}
KIT_V12 = {"MoveWalkSpeed": "46", "MoveRunSpeed": "86", "TrooPodRange": "40", "TrooAssistMax": "40"}  # v1.2
KIT_V13 = {"JumpHopBack": "false", "JumpCharges": "0", "JumpCooldown": "0.5", "JumpLaunchPower": "59",  # v1.3 Flap & Glide
           "JumpDoubleEnabled": "true", "JumpAirJumps": "2", "JumpDoubleMul": "0.8", "JumpDoubleForward": "0",
           "GliderEnabled": "true", "GliderAuto": "true", "GliderFall": "8", "JumpStaminaCost": "0", "TenoLeapOnJump": "false"}
KIT_V14 = {"JumpDoubleMul": "1.13"}  # v1.4 flaps doubled (Kepu 2026-11-06 19:02)
KIT_V15 = {"TrooZoneRadius": "10"}  # v1.5 main zone 40 studs (Kepu 2026-11-06 21:24)
TARGET_LEN = 12.0    # studs at scale 1: between the Herrera (11.2) and the raptor (12.85)
HRP_SIZE_D0 = (3.0, 2.0, 1.1)
ROLES = ["main", "stripes", "belly", "feathers", "crest", "limbs", "claws", "eyes", "mask", "tailfan"]
NEVER = {"E8E2D2", "111111", "6E342E", "A3A2A5"}

LOOKS = {
    "A": {"name": "Forest Stalker", "feather": 1.0, "eye": 1.0, "neck": 0, "leg": 1.0,
          "pal": {"main": "5E7A3A", "stripes": "5A3C22", "belly": "D6CC9C", "feathers": "4E6A2E", "crest": "7A5232",
                  "limbs": "4A5C2C", "claws": "2A2420", "eyes": "F2C230", "mask": "2E3A1C", "tailfan": "8A6236"}},
    "B": {"name": "Night Watcher", "feather": 1.35, "eye": 1.25, "neck": -10, "leg": 1.0,
          "pal": {"main": "4E4A44", "stripes": "2A2622", "belly": "B8AE98", "feathers": "3C3833", "crest": "6B5A48",
                  "limbs": "3A3632", "claws": "1C1A18", "eyes": "F0A62A", "mask": "1E1C1A", "tailfan": "8C7E6A"}},
    "C": {"name": "Sand Runner", "feather": 0.7, "eye": 1.0, "neck": 12, "leg": 1.1,
          "pal": {"main": "B08A5A", "stripes": "5E4028", "belly": "EADBB8", "feathers": "9A764A", "crest": "C9A06A",
                  "limbs": "8A6A44", "claws": "2E2620", "eyes": "E6C24A", "mask": "4A3624", "tailfan": "7A5636"}},
}
LOOK = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else "B"  # v1.0: Classic = B Night Watcher
L = LOOKS[LOOK]
F, ES, NECK_RAISE, LEG = L["feather"], L["eye"], L["neck"], L["leg"]
C = {**L["pal"], "tooth": "E8E2D2", "pupil": "111111", "mouth": "6E342E"}
M = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))  # D -> HRP space


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
    """A feather / claw blade from `start` along direction `d`; its thin side faces `ref` (z = a side sheet, y = flat)."""
    y = norm(d)
    x = norm(cross(y, ref))
    z = cross(x, y)
    R = tuple(tuple((x, y, z)[j][i] for j in range(3)) for i in range(3))
    centre = tuple(start[i] + y[i] * length / 2 for i in range(3))
    part(segname, key, (width, length, thick), centre, name=name, R=R)


def about(root, point, pitch):
    a = math.radians(pitch)
    dx, dy = point[0] - root[0], point[1] - root[1]
    return (root[0] + dx * math.cos(a) - dy * math.sin(a), root[1] + dx * math.sin(a) + dy * math.cos(a), point[2])


def tilt_down(dx, dy):
    return math.degrees(math.atan2(dx, -dy))


def nfe(n):  # feather count by the look's density
    return max(1, round(n * F))


# ---------------------------------------------------------------- torso (slim, level, a feather crest down the back)
seg("Torso", (0.0, 0.0, 0.0))
part("Torso", "main", (1.0, 0.74, 0.7), (-0.35, 0.12, 0.0), pitch=6, name="Torso_hips")
part("Torso", "main", (1.2, 0.8, 0.76), (0.55, 0.2, 0.0), pitch=8, name="Torso_body")
part("Torso", "main", (0.85, 0.84, 0.68), (1.35, 0.32, 0.0), pitch=18, name="Torso_chest")
part("Torso", "belly", (1.7, 0.14, 0.5), (0.55, -0.2, 0.0), pitch=8, name="Torso_belly")
part("Torso", "belly", (0.3, 0.7, 0.56), (1.7, 0.26, 0.0), pitch=18, name="Torso_breast")
for i, x in enumerate([-0.65, -0.25, 0.15, 0.55, 0.95]):
    for side in (1, -1):
        part("Torso", "stripes", (0.13, 0.56, 0.04), (x, 0.26 + x * 0.06, side * 0.385), pitch=-14,
             name=f"Torso_stripe{i + 1}{'L' if side > 0 else 'R'}")
n = nfe(11)
for i in range(n):
    x = -0.85 + 2.4 * i / max(1, n - 1)
    top = 0.5 + max(0.0, x) * 0.14
    blade("Torso", "crest", (x, top - 0.04, 0.0), (-0.9, 0.44, 0), (0.3 + 0.08 * (x > 0.6)) * (0.8 + 0.2 * F), 0.13, 0.07,
          name=f"Torso_crest{i + 1}")
if F > 1.1:  # B: a fuller coat - shingled feathers along the flanks
    for i, x in enumerate([-0.5, 0.0, 0.5, 1.0]):
        for side in (1, -1):
            blade("Torso", "feathers", (x, 0.42, side * 0.36), (-0.88, -0.3, side * 0.36), 0.46, 0.26, 0.06, ref=(0, 1, 0),
                  name=f"Torso_coat{i + 1}{'L' if side > 0 else 'R'}")

# ---------------------------------------------------------------- neck (S-curve up and forward, feather mane)
NECK_ROOT = (1.65, 0.55)
seg("Neck", (NECK_ROOT[0], NECK_ROOT[1], 0.0))
part("Neck", "main", (0.72, 0.5, 0.46), (1.95, 0.9, 0.0), pitch=55, name="Neck_lower")
part("Neck", "main", (0.62, 0.42, 0.4), (2.22, 1.38, 0.0), pitch=68, name="Neck_upper")
part("Neck", "belly", (0.66, 0.1, 0.32), (2.12, 1.05, 0.0), pitch=62, name="Neck_throat")
n = nfe(5)
for i in range(n):
    t = i / max(1, n - 1)
    sx, sy = 1.74 + 0.34 * t, 1.1 + 0.62 * t
    blade("Neck", "crest", (sx, sy, 0.0), (-0.9, 0.44, 0), 0.32 * (0.8 + 0.2 * F), 0.12, 0.07, name=f"Neck_crest{i + 1}")
for i in range(nfe(3)):
    t = i / max(1, nfe(3) - 1)
    for side in (1, -1):
        blade("Neck", "feathers", (1.82 + 0.3 * t, 0.95 + 0.5 * t, side * 0.2), (-0.6, -0.55, side * 0.55), 0.36 * F, 0.22, 0.05,
              ref=(0, 1, 0), name=f"Neck_mane{i + 1}{'L' if side > 0 else 'R'}")

# ---------------------------------------------------------------- head (big eyes, long narrow toothy snout)
seg("Head", (2.4, 1.72, 0.0))
part("Head", "main", (0.72, 0.62, 0.62), (2.65, 1.86, 0.0), name="Head_cranium")
part("Head", "main", (1.25, 0.32, 0.34), (3.55, 1.76, 0.0), pitch=-5, name="Head_snout")
part("Head", "main", (0.26, 0.26, 0.28), (4.2, 1.7, 0.0), pitch=-5, name="Head_tip")
part("Head", "mask", (0.46, 0.08, 0.66), (2.84, 2.12, 0.0), pitch=-4, name="Head_brow")
part("Head", "mouth", (1.5, 0.05, 0.33), (3.5, 1.6, 0.0), pitch=-5, name="Head_mouth")
for i in range(9):
    x = 2.95 + i * 0.15
    part("Head", "tooth", (0.06, 0.1, 0.35), (x, 1.62 - (x - 3.5) * 0.087 - 0.03, 0.0), name=f"Head_tooth{i + 1}")
for side in (1, -1):
    s = "L" if side > 0 else "R"
    part("Head", "eyes", (0.34 * ES, 0.34 * ES, 0.06), (2.8, 1.93, side * 0.32), name=f"Head_eye{s}")
    part("Head", "pupil", (0.12 * ES, 0.22 * ES, 0.03), (2.83, 1.93, side * 0.355), name=f"Head_pupil{s}")
    part("Head", "mask", (0.95, 0.06, 0.03), (3.45, 1.84, side * 0.176), pitch=-5, name=f"Head_mask{s}")
    part("Head", "mask", (0.08, 0.08, 0.04), (4.26, 1.76, side * 0.14), name=f"Head_nostril{s}")
for i, (dy, ang) in enumerate([(0.12, 20), (0.0, 35), (-0.12, 50)][:max(2, nfe(3))]):
    a = math.radians(ang)
    blade("Head", "crest", (2.34, 1.98 + dy, 0.0), (-math.cos(a), math.sin(a), 0), 0.38 * (0.8 + 0.2 * F), 0.1, 0.07,
          name=f"Head_crest{i + 1}")

# ---------------------------------------------------------------- jaw (long, thin, teeth up; rest open 5 deg)
JAW_ROOT = (2.55, 1.55, 0.0)
JAW_OPEN = -5
seg("Jaw", JAW_ROOT)
for key, size, c, nm in [("main", (1.65, 0.18, 0.3), (3.4, 1.49, 0.0), "Jaw_lower"),
                         ("belly", (1.4, 0.05, 0.24), (3.35, 1.39, 0.0), "Jaw_under")] + \
        [("tooth", (0.06, 0.09, 0.31), (2.9 + i * 0.15, 1.62, 0.0), f"Jaw_tooth{i + 1}") for i in range(8)]:
    part("Jaw", key, size, about(JAW_ROOT, c, JAW_OPEN), pitch=JAW_OPEN - 6 * (key == "main"), name=nm)

# ---------------------------------------------------------------- arms
# v0.2 (Kepu 2026-11-01, reference picture: "Can you make the arms longer and hang more more droopier"): ARMS "droop" =
# long arms hanging down from the shoulders, the hands drooping at about knee height with curled hooked fingers, the
# feather fan trailing back off the forearm. --arms folded keeps the v0.1 folded wing arms.
ARMS = sys.argv[sys.argv.index("--arms") + 1] if "--arms" in sys.argv else "droop"
if ARMS == "folded":  # v0.1: folded like wings, feather fans, 3 small claws
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        z = side * 0.42
        sh, el, wr = (1.45, 0.08), (1.72, -0.48), (2.2, -0.34)
        seg(f"Arm{s}", (sh[0], sh[1], side * 0.36))
        part(f"Arm{s}", "feathers", (0.22, 0.66, 0.2), ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, z),
             pitch=tilt_down(el[0] - sh[0], el[1] - sh[1]), name=f"Arm{s}_upper")
        part(f"Arm{s}", "limbs", (0.16, 0.5, 0.16), ((el[0] + wr[0]) / 2, (el[1] + wr[1]) / 2, z),
             pitch=tilt_down(wr[0] - el[0], wr[1] - el[1]), name=f"Arm{s}_fore")
        part(f"Arm{s}", "limbs", (0.24, 0.14, 0.14), (2.32, -0.37, z), name=f"Arm{s}_hand")
        for i, dz in enumerate((-0.05, 0.0, 0.05)):
            blade(f"Arm{s}", "claws", (2.4, -0.38, z + dz), (0.5, -0.86, 0), 0.22, 0.05, 0.05, name=f"Arm{s}_claw{i + 1}")
        n = nfe(5)
        for i in range(n):
            t = i / max(1, n - 1)
            st = (el[0] + (wr[0] - el[0]) * t, el[1] + (wr[1] - el[1]) * t, side * 0.46)
            blade(f"Arm{s}", "feathers", st, (-0.55, -0.84, 0), (0.42 + 0.22 * t) * (0.75 + 0.25 * F), 0.17, 0.04,
                  name=f"Arm{s}_fan{i + 1}")
else:  # v0.2 droop
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        z = side * 0.42
        sh, el, wr, kn = (1.45, 0.08), (1.36, -0.9), (1.92, -1.66), (2.04, -1.96)  # shoulder, elbow, wrist, knuckles
        seg(f"Arm{s}", (sh[0], sh[1], side * 0.36))
        part(f"Arm{s}", "main", (0.3, 0.36, 0.3), (sh[0] + 0.02, sh[1] - 0.08, z), name=f"Arm{s}_shoulder")
        part(f"Arm{s}", "feathers", (0.22, math.dist(sh, el) + 0.08, 0.2), ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, z),
             pitch=tilt_down(el[0] - sh[0], el[1] - sh[1]), name=f"Arm{s}_upper")
        part(f"Arm{s}", "limbs", (0.2, 0.2, 0.2), (el[0], el[1], z), name=f"Arm{s}_elbow")
        part(f"Arm{s}", "limbs", (0.15, math.dist(el, wr) + 0.06, 0.15), ((el[0] + wr[0]) / 2, (el[1] + wr[1]) / 2, z),
             pitch=tilt_down(wr[0] - el[0], wr[1] - el[1]), name=f"Arm{s}_fore")
        part(f"Arm{s}", "limbs", (0.16, math.dist(wr, kn) + 0.06, 0.2), ((wr[0] + kn[0]) / 2, (wr[1] + kn[1]) / 2, z),
             pitch=tilt_down(kn[0] - wr[0], kn[1] - wr[1]), name=f"Arm{s}_hand")
        for i, dz in enumerate((-0.07, 0.0, 0.07)):  # fingers hang down and hook back under
            f0 = (kn[0], kn[1] + 0.04, z + dz)
            blade(f"Arm{s}", "limbs", f0, (0.25, -0.97, 0), 0.22, 0.06, 0.06, name=f"Arm{s}_finger{i + 1}")
            f1 = (f0[0] + 0.25 * 0.22, f0[1] - 0.97 * 0.22, z + dz)
            blade(f"Arm{s}", "claws", f1, (-0.55, -0.83, 0), 0.2, 0.05, 0.05, name=f"Arm{s}_claw{i + 1}")
        n = nfe(5)
        for i in range(n):
            t = i / max(1, n - 1)
            st = (el[0] + (wr[0] - el[0]) * t, el[1] + (wr[1] - el[1]) * t, side * 0.47)
            blade(f"Arm{s}", "feathers", st, (-0.62, -0.78, 0), (0.3 + 0.16 * t) * (0.75 + 0.25 * F), 0.2, 0.04,
                  name=f"Arm{s}_fan{i + 1}")

# ---------------------------------------------------------------- tail (long, slim, level, feather fan at the tip)
tail = [(1.3, (1.34, 0.5, 0.46), 6), (1.25, (1.3, 0.4, 0.37), 4), (1.15, (1.2, 0.31, 0.29), 2),
        (1.05, (1.1, 0.23, 0.22), 0), (0.95, (1.0, 0.16, 0.16), -2)]
_root = (-0.85, 0.24)
for i, (seglen, size, rise) in enumerate(tail):
    name = f"Tail{i + 1}"
    a = math.radians(rise)
    d = (-math.cos(a), math.sin(a))
    seg(name, (_root[0], _root[1], 0.0))
    part(name, "main", size, (_root[0] + d[0] * (size[0] / 2 - 0.05), _root[1] + d[1] * (size[0] / 2 - 0.05), 0.0), pitch=-rise)
    part(name, "stripes", (0.14, size[1] + 0.04, size[2] + 0.04), (_root[0] + d[0] * 0.6, _root[1] + d[1] * 0.6, 0.0),
         pitch=-rise, name=f"{name}_band")
    if i <= 1:
        blade(name, "crest", (_root[0] + d[0] * 0.5, _root[1] + d[1] * 0.5 + size[1] / 2 - 0.04, 0.0), (-0.85, 0.5, 0),
              0.26 * (0.8 + 0.2 * F), 0.22, 0.05, name=f"{name}_crest")
    if i >= 3:  # feathers along the sides of the last two, flat
        for j, dd in enumerate((0.2, 0.55, 0.9)):
            for side in (1, -1):
                ang = math.radians(32 - 8 * j - 8 * (i - 3))
                blade(name, "tailfan", (_root[0] + d[0] * dd, _root[1] + d[1] * dd, side * size[2] / 2),
                      (-math.cos(ang), 0.12, side * math.sin(ang)), (0.48 + 0.12 * j + 0.12 * (i - 3)) * F, 0.24, 0.06,
                      ref=(0, 1, 0), name=f"{name}_fan{j + 1}{'L' if side > 0 else 'R'}")
    if i == 4:
        tip = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)
        for k, ang in enumerate((-24, 0, 24)):
            r_ = math.radians(ang)
            blade(name, "tailfan", (tip[0] + 0.05, tip[1], 0.0), (-math.cos(r_), 0.1, math.sin(r_)), 0.8 * F, 0.26, 0.06,
                  ref=(0, 1, 0), name=f"{name}_tip{k + 1}")
        for k, ang in enumerate((28, -22)):  # a plume above and below the tip so it reads from the side too
            r_ = math.radians(ang)
            blade(name, "tailfan", (tip[0] + 0.25, tip[1], 0.0), (-math.cos(r_), math.sin(r_), 0), 0.6 * F, 0.2, 0.06,
                  name=f"{name}_plume{k + 1}")
    _root = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)

# ---------------------------------------------------------------- legs (long and slender, feathered thighs, raised sickle claw)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.38
    hip, knee, ankle, ball = (-0.25, 0.0), (0.4, -1.45 * LEG), (-0.4, -2.8 * LEG), (-0.05, -3.45 * LEG)
    seg(f"Leg{s}", (hip[0], hip[1], z))
    part(f"Leg{s}", "main", (0.62, 0.66, 0.46), (-0.2, -0.2, z), pitch=10, name=f"Leg{s}_haunch")
    part(f"Leg{s}", "main", (0.4, 1.5 * LEG, 0.38), ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, z),
         pitch=tilt_down(knee[0] - hip[0], knee[1] - hip[1]), name=f"Leg{s}_thigh")
    for i in range(nfe(3)):
        t = i / max(1, nfe(3) - 1)
        blade(f"Leg{s}", "feathers", (-0.45 + 0.35 * t, -0.2 - 0.5 * t * LEG, z + side * 0.05), (-0.62, -0.78, 0), 0.4 * F, 0.2, 0.05,
              name=f"Leg{s}_pants{i + 1}")
    seg(f"Shin{s}", (knee[0], knee[1], z))
    part(f"Shin{s}", "limbs", (0.28, 0.26, 0.28), (knee[0], knee[1], z), name=f"Shin{s}_knee")
    part(f"Shin{s}", "limbs", (0.2, 1.52 * LEG, 0.2), ((knee[0] + ankle[0]) / 2, (knee[1] + ankle[1]) / 2, z),
         pitch=tilt_down(ankle[0] - knee[0], ankle[1] - knee[1]), name=f"Shin{s}_shin")
    seg(f"Foot{s}", (ankle[0], ankle[1], z))
    part(f"Foot{s}", "limbs", (0.17, 0.74 * LEG, 0.18), ((ankle[0] + ball[0]) / 2, (ankle[1] + ball[1]) / 2, z),
         pitch=tilt_down(ball[0] - ankle[0], ball[1] - ankle[1]), name=f"Foot{s}_meta")
    for i, yw in enumerate((10, -10)):  # toes III and IV on the ground
        L_ = 0.72
        dx, dz = math.cos(math.radians(yw)) * L_ / 2, -math.sin(math.radians(yw)) * L_ / 2
        part(f"Foot{s}", "limbs", (L_, 0.13, 0.15), (ball[0] + dx, ball[1] - 0.07, z + side * dz), yaw=yw * side, name=f"Foot{s}_toe{i + 1}")
        part(f"Foot{s}", "claws", (0.16, 0.11, 0.09), (ball[0] + dx * 2 + 0.05, ball[1] - 0.08, z + side * dz * 2), yaw=yw * side,
             name=f"Foot{s}_claw{i + 1}")
    # toe II held up off the ground with the big sickle claw
    tz = z + side * 0.1
    t0 = (ball[0], ball[1] - 0.02, tz)
    blade(f"Foot{s}", "limbs", t0, (0.8, 0.6, 0), 0.34, 0.13, 0.13, name=f"Foot{s}_toe2")
    t1 = (t0[0] + 0.8 * 0.34, t0[1] + 0.6 * 0.34, tz)
    blade(f"Foot{s}", "claws", t1, (0.3, 0.95, 0), 0.26, 0.1, 0.07, name=f"Foot{s}_sickle1")
    t2 = (t1[0] + 0.3 * 0.26, t1[1] + 0.95 * 0.26, tz)
    blade(f"Foot{s}", "claws", t2, (-0.45, 0.89, 0), 0.2, 0.08, 0.06, name=f"Foot{s}_sickle2")

JOINTS = [("RootJoint", "HRP", "Torso"), ("Neck", "Torso", "Neck"), ("Head", "Neck", "Head"), ("Jaw", "Head", "Jaw"),
          ("ArmL", "Torso", "ArmL"), ("ArmR", "Torso", "ArmR"), ("Tail1", "Torso", "Tail1"), ("Tail2", "Tail1", "Tail2"),
          ("Tail3", "Tail2", "Tail3"), ("Tail4", "Tail3", "Tail4"), ("Tail5", "Tail4", "Tail5"),
          ("LegL", "Torso", "LegL"), ("LegR", "Torso", "LegR"), ("KneeL", "LegL", "ShinL"), ("KneeR", "LegR", "ShinR"),
          ("AnkleL", "ShinL", "FootL"), ("AnkleR", "ShinR", "FootR")]

# ---------------------------------------------------------------- posture: the look's neck raise (neck, head and jaw turn about the neck root)
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
HIP = -lo[1]  # the hip height = the lowest point (toes) below the hip centre
HRP_SIZE_D = tuple(v * K for v in HRP_SIZE_D0)


def cf(pos_d, R_d=None):
    R = matmul(M, R_d if R_d else rot())
    p = mv(M, pos_d)
    return [round(v, 5) + 0.0 for v in list(p) + [R[0][0], R[0][1], R[0][2], R[1][0], R[1][1], R[1][2], R[2][0], R[2][1], R[2][2]]]


# colour checks (the skin rule)
hexes = [C[r] for r in ROLES]
assert len(set(hexes)) == len(hexes), "two colour groups share a hex"
assert not (NEVER & set(hexes)), "a group uses a never-paint colour"
used = {C[p["key"]] for n_ in order for p in segments[n_]["parts"]}
assert used <= set(hexes) | {"E8E2D2", "111111", "6E342E"}, "a block colour is not a role or never-paint"

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
if "--json" not in sys.argv:
    # ------------------------------------------------------------ full data file (v1.0), same layout as HerreraModelData / TenoModelData
    assert LOOK == "B" and ARMS == "droop", "the data file is the picked look: B Night Watcher with drooping arms"
    def fmt(v):
        return "{" + ",".join(f"{x:g}" for x in v) + "}"
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
    attrs.update({"Species": '"Troodon"', "StyleVersion": '"1.0"', "TroodonModelVersion": f'"{VERSION}"', "DisplayName": '"Troodon"',
                  "RigHipHeight": f"{HIP:.4g}", "BiteEnabled": "false", "PounceEnabled": "false", "RamEnabled": "false",
                  "RoarEnabled": "false", "JumpEnabled": "false", "CreepEnabled": "false"})
    attrs.pop("StarterCharacterVersion", None)
    for k in ("GaitAlwaysRun", "TRexModelVersion"):  # v1.1: T-Rex 2.0-only keys (not in the 1.0 data; the Dilo generator's rule)
        attrs.pop(k, None)
    if "--no-kit" not in sys.argv:  # v1.1
        attrs.update(KIT_ATTRS)
        if "--v11" not in sys.argv:  # v1.2
            attrs.update(KIT_V12)
        if V13:  # v1.3
            attrs.update(KIT_V13)
        if V14:  # v1.4
            attrs.update(KIT_V14)
        if V15:  # v1.5
            attrs.update(KIT_V15)
    lines = [f"-- TroodonModelData v{VERSION} (Mecha Dino Arena) — block-style feathered Troodon ({LOOK} {L['name']}, long drooping arms), rig 1.3 joint names, skin-ready colour groups.",
             "-- Generated by tools/troodon_generator.py (do not edit by hand; change the generator and re-run). Mockup docs/mockups/troodon_model_options.html (v0.2, Kepu picked B).",
             f"-- Scale: {hi[0] - lo[0]:.2f} studs long, hip {HIP:.4g} studs; doubled in game like the raptor / Herrera (~{2 * (hi[0] - lo[0]):.0f}; Herrera ~22.4, raptor ~25.7).",
             f"-- Colour groups (Classic = {L['name']}): " + ", ".join(f"{r} {C[r]}" for r in ROLES) + "; never painted: teeth E8E2D2, pupil 111111, mouth 6E342E.",
             "-- All CFrames are relative to the HumanoidRootPart; sizes in studs; colors hex RGB. Rebuild with DinoModelBuilder.build(require(TroodonModelData)).",
             ("-- v1.1 kit (MDA-330, plan docs/plans/TROODON_KIT_v1.0.md): 55 HP area control + support: Glow Pod Toss on ATTACK (TrooAttack*: a pod that splats a 3 s glow zone hurting / slowing enemies and healing squadmates), Evade Hop on JUMP (JumpHopBack: 2 charges, a low hop backward, no landing slam); playable through SpeciesServer." + (" v1.2: run 86 / walk 46 (between the raptor and the Herrera), pod range 80 studs (TrooPodRange / TrooAssistMax 40)." if "--v11" not in sys.argv else "") + (" v1.3: Flap & Glide on JUMP instead of the Evade Hop: a leap + 2 air flaps (JumpAirJumps 2, JumpDoubleMul 0.8), then an automatic glide (GliderAuto, GliderFall 8)." if V13 else "") + (" v1.4: flaps doubled (JumpDoubleMul 1.13, ~11 studs each)." if V14 else "") + (" v1.5: main glow zone 40 studs wide (TrooZoneRadius 10)." if V15 else "") if "--no-kit" not in sys.argv else "-- Not playable yet: no SpeciesServer entry, no kit (every move off). Those come with the troodon kit plan."),
             "return {", f'\tversion = "{VERSION}", species = "Troodon", style = "1.0", rig = "1.3",'] + body + ["\tattributes = {"] + [f"\t\t{k} = {attrs[k]}," for k in sorted(attrs)] + ["\t},", "}"]
    open(OUT, "w").write("\n".join(lines) + "\n")
    print("data ->", OUT, f"({len(attrs)} attributes)")
n = sum(len(segments[s_]["parts"]) for s_ in order)
print(f"look {LOOK} ({L['name']}): {n} parts, {len(order)} segments, scale {K:.3f}, HIP {HIP:.3f}")
print("length %.2f, height %.2f, width %.2f" % (hi[0] - lo[0], hi[1] + HIP, hi[2] - lo[2]))
