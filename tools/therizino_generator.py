#!/usr/bin/env python3
"""Therizino generator v0.1 (Mecha Dino Arena) — mockup stage: three looks for Kepu to pick from.

Kepu 2026-11-02: "Therizino. Slasher build" -> "Make the model". Answers: size "Between raptor and T-Rex (~32)";
style "True to the animal"; feathers "Fully feathered"; roster "Day 1".
Our own design of the real animal (Therizinosaurus): a small head with a beak, a long upright neck, a deep pot-bellied
body held at a slant, a short drooping tail, stocky four-toed legs, and huge arms with three giant sickle claws; a shaggy
feather coat. Kepu's reference picture was film art (UCS LLC and Amblin); nothing here copies that creature.

Same 17-segment rig and joint names as the other dinos (rig 1.3). Dino space D = (x forward, y up, z left), origin at
the hip centre (= HumanoidRootPart centre). The whole body is scaled so its length is TARGET_LEN studs (16 at scale 1,
doubled in game like the raptor / Herrera / troodon: ~32; T-Rex ~40, raptor ~25.7).
Skin rule: every visible block uses one authored colour per group (10 groups), no hex shared between groups, none equal
to a never-paint colour (teeth E8E2D2, pupils 111111, mouth 6E342E, HRP A3A2A5).
Looks (mockup docs/mockups/therizino_model_options.html):
  A Bark Ranger - russet-brown coat, cream mane, claws held forward ready to slash, neck upright.
  B Ghost Moss  - ash-grey shaggy coat (fullest), white mane, charcoal arms, ivory claws hanging low, neck leaning forward.
  C Ember Back  - charcoal coat with an orange back and arm bars, a face mask, claws raised high, a sleeker coat, neck up.
Run: python3 tools/therizino_generator.py --look A|B|C --json OUT   (the three.js viewer's format)
The data file (TherizinoModelData.luau, attributes, Classic colours) comes after Kepu picks.
"""
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSION = "0.1"
TARGET_LEN = 16.0    # studs at scale 1 (~32 in game)
HRP_SIZE_D0 = (3.0, 2.6, 1.6)
ROLES = ["main", "back", "belly", "coat", "mane", "limbs", "claws", "eyes", "beak", "mask"]
NEVER = {"E8E2D2", "111111", "6E342E", "A3A2A5"}

LOOKS = {
    "A": {"name": "Bark Ranger", "feather": 1.0, "neck": 0, "claws": "forward",
          "pal": {"main": "7A5236", "back": "4E3424", "belly": "C9B48E", "coat": "6A4630", "mane": "E6D8B8",
                  "limbs": "5A3E2C", "claws": "2C2622", "eyes": "D8A030", "beak": "3A3530", "mask": "40302A"}},
    "B": {"name": "Ghost Moss", "feather": 1.3, "neck": -10, "claws": "hang",
          "pal": {"main": "8A8C88", "back": "5C5E5A", "belly": "CFCBC0", "coat": "767874", "mane": "EDEBE4",
                  "limbs": "3C3D3B", "claws": "D8D0BC", "eyes": "E0B848", "beak": "2E2F2E", "mask": "4A4C49"}},
    "C": {"name": "Ember Back", "feather": 0.8, "neck": 6, "claws": "raised",
          "pal": {"main": "3A3836", "back": "D2632A", "belly": "A69C8C", "coat": "2C2A28", "mane": "8E8A84",
                  "limbs": "4A4644", "claws": "1E1C1B", "eyes": "F2C040", "beak": "5A4A3A", "mask": "C24A22"}},
}
LOOK = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else "A"
L = LOOKS[LOOK]
F, NECK_RAISE, CLAWS = L["feather"], L["neck"], L["claws"]
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


def nfe(n):
    return max(1, round(n * F))


# ---------------------------------------------------------------- torso (deep pot belly, held at a slant, shaggy coat)
seg("Torso", (0.0, 0.0, 0.0))
part("Torso", "main", (1.6, 1.4, 1.3), (-0.3, 0.2, 0.0), pitch=15, name="Torso_hips")
part("Torso", "main", (2.2, 1.9, 1.75), (0.85, 0.35, 0.0), pitch=25, name="Torso_belly")
part("Torso", "main", (1.5, 1.55, 1.4), (1.95, 1.15, 0.0), pitch=42, name="Torso_chest")
part("Torso", "belly", (1.9, 0.2, 1.15), (0.85, -0.62, 0.0), pitch=22, name="Torso_under")
part("Torso", "belly", (0.3, 1.2, 1.0), (2.55, 1.0, 0.0), pitch=40, name="Torso_breast")
part("Torso", "back", (2.6, 0.18, 0.8), (0.6, 1.2, 0.0), pitch=22, name="Torso_backstripe")
part("Torso", "back", (1.1, 0.18, 0.7), (1.9, 1.95, 0.0), pitch=42, name="Torso_backstripe2")
n = nfe(9)  # shaggy coat hanging off the flanks and belly
for i in range(n):
    t = i / max(1, n - 1)
    x, y = -0.7 + 2.9 * t, -0.05 + 0.85 * t
    for side in (1, -1):
        blade("Torso", "coat", (x, y, side * 0.86), (-0.35, -0.94, side * 0.15), (0.75 + 0.2 * math.sin(t * 9)) * F, 0.34, 0.06,
              name=f"Torso_shag{i + 1}{'L' if side > 0 else 'R'}")
for i in range(nfe(5)):  # belly fringe
    t = i / max(1, nfe(5) - 1)
    blade("Torso", "coat", (0.1 + 1.6 * t, -0.62 + 0.4 * t, 0.0), (-0.25, -0.97, 0), 0.6 * F, 0.5, 0.08, name=f"Torso_fringe{i + 1}")
for i in range(nfe(8)):  # back feathers
    t = i / max(1, nfe(8) - 1)
    blade("Torso", "back", (-0.9 + 3.0 * t, 0.86 + 1.25 * t * t, 0.0), (-0.97, 0.12, 0), 0.6 * F, 0.6, 0.1, ref=(0, 1, 0),
          name=f"Torso_plume{i + 1}")

# ---------------------------------------------------------------- neck (long, upright, mane down the back)
NECK_ROOT = (2.45, 1.75)
seg("Neck", (NECK_ROOT[0], NECK_ROOT[1], 0.0))
part("Neck", "mane", (1.15, 0.78, 0.74), (2.75, 2.25, 0.0), pitch=68, name="Neck_base")
part("Neck", "mane", (1.05, 0.62, 0.6), (2.98, 3.15, 0.0), pitch=80, name="Neck_mid")
part("Neck", "mane", (0.95, 0.54, 0.52), (3.12, 4.0, 0.0), pitch=78, name="Neck_upper")
for i in range(nfe(7)):
    t = i / max(1, nfe(7) - 1)
    blade("Neck", "mane", (2.45 + 0.6 * t, 2.3 + 2.0 * t, 0.0), (-0.85, -0.2, 0), 0.5 * F, 0.3, 0.07, name=f"Neck_mane{i + 1}")
    for side in (1, -1):
        blade("Neck", "mane", (2.65 + 0.45 * t, 2.0 + 2.0 * t, side * 0.3), (-0.5, -0.6, side * 0.62), 0.45 * F, 0.3, 0.05,
              ref=(0, 1, 0), name=f"Neck_ruff{i + 1}{'L' if side > 0 else 'R'}")

# ---------------------------------------------------------------- head (small, beaked)
seg("Head", (3.2, 4.4, 0.0))
part("Head", "main", (0.72, 0.62, 0.58), (3.45, 4.62, 0.0), name="Head_cranium")
part("Head", "main", (0.66, 0.42, 0.44), (3.95, 4.5, 0.0), pitch=-10, name="Head_snout")
part("Head", "beak", (0.32, 0.32, 0.38), (4.32, 4.4, 0.0), pitch=-18, name="Head_beak")
part("Head", "mouth", (0.8, 0.05, 0.43), (3.95, 4.3, 0.0), pitch=-10, name="Head_mouth")
for i in range(4):
    part("Head", "tooth", (0.06, 0.08, 0.44), (3.62 + i * 0.13, 4.36 - i * 0.022, 0.0), name=f"Head_tooth{i + 1}")
for side in (1, -1):
    s = "L" if side > 0 else "R"
    part("Head", "eyes", (0.2, 0.2, 0.05), (3.52, 4.72, side * 0.3), name=f"Head_eye{s}")
    part("Head", "pupil", (0.08, 0.14, 0.03), (3.54, 4.72, side * 0.325), name=f"Head_pupil{s}")
    part("Head", "mask", (0.62, 0.1, 0.04), (3.6, 4.85, side * 0.29), pitch=-6, name=f"Head_brow{s}")
    part("Head", "mask", (0.5, 0.08, 0.03), (3.95, 4.58, side * 0.225), pitch=-10, name=f"Head_cheek{s}")
for i in range(max(2, nfe(3))):
    a = math.radians(25 + 18 * i)
    blade("Head", "mane", (3.18, 4.82 - 0.08 * i, 0.0), (-math.cos(a), math.sin(a), 0), 0.38 * F, 0.12, 0.06, name=f"Head_crest{i + 1}")

# ---------------------------------------------------------------- jaw (beaked; rest open 5 deg)
JAW_ROOT = (3.4, 4.32, 0.0)
JAW_OPEN = -5
seg("Jaw", JAW_ROOT)
for key, size, c, nm, pch in [("main", (0.92, 0.18, 0.4), (3.9, 4.24, 0.0), "Jaw_lower", -8),
                              ("beak", (0.26, 0.2, 0.34), (4.3, 4.18, 0.0), "Jaw_beak", -14),
                              ("belly", (0.7, 0.05, 0.3), (3.85, 4.14, 0.0), "Jaw_under", -8)]:
    part("Jaw", key, size, about(JAW_ROOT, c, JAW_OPEN), pitch=JAW_OPEN + pch, name=nm)

# ---------------------------------------------------------------- arms (long, feathered, three giant sickle claws)
ARM_POSES = {  # shoulder, elbow, wrist, claw directions base -> mid -> tip (a curved sickle in three blocks)
    "forward": ((2.15, 1.0), (2.45, -0.85), (3.4, -0.75), ((0.75, -0.66), (0.35, -0.94), (-0.1, -1.0))),
    "hang":    ((2.15, 1.0), (2.2, -0.6), (2.6, -1.6), ((0.55, -0.83), (0.2, -0.98), (-0.3, -0.95))),
    "raised":  ((2.15, 1.0), (2.8, 0.1), (3.7, 0.75), ((0.98, 0.1), (0.8, -0.6), (0.35, -0.94))),
}
sh, el, wr, CD = ARM_POSES[CLAWS]
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.95
    seg(f"Arm{s}", (sh[0], sh[1], side * 0.8))
    part(f"Arm{s}", "coat", (0.6, 0.5, 0.42), (sh[0] - 0.05, sh[1] - 0.32, z - side * 0.05), name=f"Arm{s}_shoulder")
    bone(f"Arm{s}", "coat", (sh[0], sh[1], z), (el[0], el[1], z), 0.4, 0.38, f"Arm{s}_upper")
    part(f"Arm{s}", "limbs", (0.32, 0.32, 0.32), (el[0], el[1], z), name=f"Arm{s}_elbow")
    bone(f"Arm{s}", "limbs", (el[0], el[1], z), (wr[0], wr[1], z), 0.3, 0.3, f"Arm{s}_fore")
    part(f"Arm{s}", "limbs", (0.42, 0.34, 0.4), (wr[0], wr[1], z), name=f"Arm{s}_hand")
    for i in range(nfe(5)):  # feather fringe trailing off the forearm
        t = i / max(1, nfe(5) - 1)
        st = (el[0] + (wr[0] - el[0]) * t, el[1] + (wr[1] - el[1]) * t, z + side * 0.1)
        blade(f"Arm{s}", "coat", st, (-0.55, -0.83, 0), (0.55 + 0.15 * t) * F, 0.24, 0.05, name=f"Arm{s}_fringe{i + 1}")
    for i, (dz, lm) in enumerate(((-0.14, 0.88), (0.0, 1.0), (0.14, 0.8))):  # three giant sickle claws, tapering, curved
        pt = (wr[0] + CD[0][0] * 0.12, wr[1] + CD[0][1] * 0.12, z + dz)
        for j, (dd, ln, w, t) in enumerate(zip(CD, (0.8, 0.7, 0.55), (0.2, 0.15, 0.1), (0.12, 0.1, 0.07))):
            pt = blade(f"Arm{s}", "claws", pt, (dd[0], dd[1], 0), ln * lm, w, t, name=f"Arm{s}_claw{i + 1}{'abc'[j]}")

# ---------------------------------------------------------------- tail (short, drooping, feathered, tip tuft)
tail = [(1.0, (1.05, 0.85, 0.8), -6), (0.95, (1.0, 0.66, 0.62), -9), (0.85, (0.9, 0.5, 0.48), -11),
        (0.75, (0.8, 0.38, 0.36), -9), (0.65, (0.7, 0.28, 0.27), -6)]
_root = (-1.0, 0.25)
for i, (seglen, size, rise) in enumerate(tail):
    name = f"Tail{i + 1}"
    a = math.radians(rise)
    d = (-math.cos(a), math.sin(a))
    seg(name, (_root[0], _root[1], 0.0))
    part(name, "main", size, (_root[0] + d[0] * (size[0] / 2 - 0.05), _root[1] + d[1] * (size[0] / 2 - 0.05), 0.0), pitch=-rise)
    blade(name, "back", (_root[0] + d[0] * 0.45, _root[1] + d[1] * 0.45 + size[1] / 2 - 0.05, 0.0), (-0.97, 0.12, 0),
          0.45 * F, size[2] * 0.85, 0.08, ref=(0, 1, 0), name=f"{name}_plume")
    for side in (1, -1):
        blade(name, "coat", (_root[0] + d[0] * 0.5, _root[1] + d[1] * 0.5, side * size[2] / 2), (-0.6, -0.55, side * 0.55),
              0.45 * F, 0.3, 0.05, ref=(0, 1, 0), name=f"{name}_shag{'L' if side > 0 else 'R'}")
    if i == 4:
        tip = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)
        for k, ang in enumerate((-30, 0, 30)):
            r_ = math.radians(ang)
            blade(name, "coat", (tip[0] + 0.1, tip[1], 0.0), (-math.cos(r_), 0.05, math.sin(r_)), 0.7 * F, 0.26, 0.06,
                  ref=(0, 1, 0), name=f"{name}_tuft{k + 1}")
    _root = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)

# ---------------------------------------------------------------- legs (stocky, feathered thighs, four toes)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.62
    hip, knee, ankle, ball = (0.0, 0.0), (0.55, -1.65), (-0.15, -3.05), (0.15, -3.55)
    seg(f"Leg{s}", (hip[0], hip[1], z))
    part(f"Leg{s}", "main", (1.0, 1.0, 0.7), (0.1, -0.35, z), pitch=10, name=f"Leg{s}_haunch")
    bone(f"Leg{s}", "main", (hip[0], hip[1], z), (knee[0], knee[1], z), 0.72, 0.62, f"Leg{s}_thigh")
    for i in range(nfe(4)):
        t = i / max(1, nfe(4) - 1)
        blade(f"Leg{s}", "coat", (-0.35 + 0.5 * t, -0.3 - 0.9 * t, z + side * 0.25), (-0.5, -0.86, 0), 0.6 * F, 0.3, 0.06,
              name=f"Leg{s}_pants{i + 1}")
    seg(f"Shin{s}", (knee[0], knee[1], z))
    part(f"Shin{s}", "limbs", (0.48, 0.44, 0.48), (knee[0], knee[1], z), name=f"Shin{s}_knee")
    bone(f"Shin{s}", "limbs", (knee[0], knee[1], z), (ankle[0], ankle[1], z), 0.42, 0.4, f"Shin{s}_shin")
    seg(f"Foot{s}", (ankle[0], ankle[1], z))
    bone(f"Foot{s}", "limbs", (ankle[0], ankle[1], z), (ball[0], ball[1], z), 0.38, 0.4, f"Foot{s}_meta")
    for i, yw in enumerate((18, 0, -18)):
        L_ = 0.75 if yw == 0 else 0.62
        dx, dz = math.cos(math.radians(yw)) * L_ / 2, -math.sin(math.radians(yw)) * L_ / 2
        part(f"Foot{s}", "limbs", (L_, 0.18, 0.2), (ball[0] + dx, ball[1] - 0.04, z + side * dz), yaw=yw * side, name=f"Foot{s}_toe{i + 1}")
        part(f"Foot{s}", "claws", (0.2, 0.15, 0.13), (ball[0] + dx * 2 + 0.06, ball[1] - 0.05, z + side * dz * 2), yaw=yw * side,
             name=f"Foot{s}_claw{i + 1}")
    part(f"Foot{s}", "limbs", (0.32, 0.14, 0.15), (ball[0] - 0.25, ball[1] + 0.05, z + side * 0.2), yaw=-40 * side, name=f"Foot{s}_toe4")

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
n = sum(len(segments[s_]["parts"]) for s_ in order)
print(f"look {LOOK} ({L['name']}): {n} parts, {len(order)} segments, scale {K:.3f}, HIP {HIP:.3f}")
print("length %.2f, height %.2f, width %.2f" % (hi[0] - lo[0], hi[1] + HIP, hi[2] - lo[2]))
