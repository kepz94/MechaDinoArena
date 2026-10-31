#!/usr/bin/env python3
"""Herrerasaurus generator v0.1 (Mecha Dino Arena) — MOCKUP prototype (not installed in the game yet).

Kepu 2026-10-30: "the next Dino I want to work on it's the Herrerasaurus. This will be a utility Dino someone that's a
Pain in the ass to deal with but easy to kill" · "It's going to have the most mecha utility and the fastest in the game" ·
answers: 40 HP, a bit smaller than the raptor; ATTACK = hit-and-run slash; hard to catch + climber; day 1.
Reference look (Kepu's picture, used only as a colour / feature reference; the model is our own block design): olive
green body, dark back stripe, red markings and a red throat, pale bands on the tail, long low skull, long clawed arms.

Same 17-segment rig and joint names as the T-Rex / raptor / pachy (rig 1.3). Dino space D = (x forward, y up, z left),
origin at the hip centre (= HumanoidRootPart centre). The whole body is scaled so its length is TARGET_LEN studs.
Skin rule: every visible block uses one authored colour per group, no hex shared between groups, none equal to a
never-paint colour (teeth E8E2D2, pupils 111111, mouth 6E342E, HRP A3A2A5).
Look options for the mockup (all parts are always built; the mockup hides one set by name):
  Neck_dewlap*      red throat pouch            (option A "Red throat", C "Both")
  Head_browridge*   red brow horns over the eyes (option B "Brow horns", C "Both")
Run: python3 tools/herrera_generator.py [--mock OUT]   (--mock writes segments + joints only, for Studio renders)
"""
import math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Models", "HerreraModelData.luau")

VERSION = "0.1"
TARGET_LEN = 11.2    # studs at scale 1 (raptor 12.85; doubled in game: ~22.4 vs the raptor's 25.4)
HIP0 = 2.9           # authored hip height before the length scale
HRP_SIZE_D0 = (3.2, 2.1, 1.2)

C = {
    "main":      "7E9A4A",  # olive green
    "stripes":   "3F5A2A",  # dark back stripe / snout line
    "belly":     "D8D2A0",  # pale cream-yellow
    "markings":  "B8414A",  # red spots, throat, brow
    "limbs":     "6C8540",  # lower legs / hands
    "claws":     "2C2620",
    "eyes":      "E8C547",
    "tailbands": "C9C46A",  # pale tail rings
    "tooth":     "E8E2D2",  # never-paint
    "pupil":     "111111",  # never-paint
    "mouth":     "6E342E",  # never-paint
}
SMOOTH = {"eyes", "pupil", "tooth", "claws", "mouth"}
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


segments, order = {}, []


def seg(name, root):
    segments[name] = {"root": root, "parts": []}
    order.append(name)


def part(segname, key, size, center, pitch=0.0, yaw=0.0, roll=0.0, name=None):
    segments[segname]["parts"].append({"name": name or f"{segname}_{key}", "size": size, "center": center,
                                       "R": rot(pitch, yaw, roll), "key": key})


def about(root, point, pitch):
    a = math.radians(pitch)
    dx, dy = point[0] - root[0], point[1] - root[1]
    return (root[0] + dx * math.cos(a) - dy * math.sin(a), root[1] + dx * math.sin(a) + dy * math.cos(a), point[2])


def tilt_down(dx, dy):
    return math.degrees(math.atan2(dx, -dy))


# ---------------------------------------------------------------- torso (lean, low)
seg("Torso", (0.0, 0.0, 0.0))
part("Torso", "main", (2.4, 1.0, 0.92), (0.45, 0.12, 0.0))
part("Torso", "main", (0.95, 0.95, 0.84), (1.6, 0.04, 0.0), pitch=-8, name="Torso_chest")
part("Torso", "main", (1.0, 0.92, 0.86), (-0.5, 0.2, 0.0), pitch=6, name="Torso_hips")
part("Torso", "belly", (2.2, 0.24, 0.76), (0.6, -0.37, 0.0))
part("Torso", "stripes", (2.9, 0.12, 0.42), (0.35, 0.66, 0.0), name="Torso_backstripe")
for i, (x, y) in enumerate([(-0.65, 0.3), (-0.2, 0.05), (0.25, 0.3), (0.7, 0.08), (1.15, 0.3), (1.55, 0.1)]):
    for side in (1, -1):
        part("Torso", "markings", (0.24, 0.2, 0.04), (x, y, side * 0.47), name=f"Torso_spot{i + 1}{'L' if side > 0 else 'R'}")

# ---------------------------------------------------------------- neck (slender S curve)
seg("Neck", (1.85, 0.35, 0.0))
part("Neck", "main", (0.85, 0.58, 0.56), (2.2, 0.72, 0.0), pitch=45)
part("Neck", "main", (0.8, 0.5, 0.5), (2.62, 1.12, 0.0), pitch=20, name="Neck_upper")
part("Neck", "belly", (0.7, 0.2, 0.46), (2.38, 0.5, 0.0), pitch=45, name="Neck_throat")
part("Neck", "stripes", (0.85, 0.1, 0.3), (2.05, 0.98, 0.0), pitch=45, name="Neck_backstripe")
part("Neck", "markings", (0.62, 0.42, 0.3), (2.62, 0.62, 0.0), pitch=30, name="Neck_dewlap1")
part("Neck", "markings", (0.4, 0.3, 0.26), (2.92, 0.86, 0.0), pitch=15, name="Neck_dewlap2")

# ---------------------------------------------------------------- head (long, low skull)
seg("Head", (2.95, 1.3, 0.0))
part("Head", "main", (0.9, 0.62, 0.66), (3.3, 1.36, 0.0), name="Head_skull")
part("Head", "main", (1.5, 0.44, 0.5), (4.35, 1.27, 0.0), pitch=-3, name="Head_snout")
part("Head", "main", (0.3, 0.36, 0.44), (5.15, 1.21, 0.0), name="Head_tip")
part("Head", "mouth", (2.0, 0.1, 0.44), (4.2, 1.02, 0.0), name="Head_mouth")
for i, x in enumerate([3.6, 3.85, 4.1, 4.35, 4.6, 4.85, 5.1]):
    part("Head", "tooth", (0.1, 0.13, 0.5), (x, 1.05, 0.0), name=f"Head_tooth{i + 1}")
part("Head", "stripes", (1.3, 0.06, 0.26), (4.25, 1.5, 0.0), pitch=-3, name="Head_snoutline")
part("Head", "stripes", (0.5, 0.1, 0.68), (3.4, 1.7, 0.0), name="Head_brow")
for side in (1, -1):
    s = "L" if side > 0 else "R"
    part("Head", "eyes", (0.24, 0.2, 0.05), (3.5, 1.5, side * 0.335), name=f"Head_eye{s}")
    part("Head", "pupil", (0.06, 0.17, 0.03), (3.52, 1.5, side * 0.36), name=f"Head_pupil{s}")
    part("Head", "stripes", (0.07, 0.06, 0.04), (5.25, 1.3, side * 0.2), name=f"Head_nostril{s}")
    part("Head", "markings", (0.55, 0.14, 0.1), (3.45, 1.74, side * 0.3), pitch=-8, name=f"Head_browridge{s}")
    part("Head", "markings", (0.2, 0.2, 0.1), (3.22, 1.84, side * 0.3), pitch=-20, name=f"Head_browridgeTip{s}")
    part("Head", "markings", (0.5, 0.1, 0.03), (3.95, 1.36, side * 0.26), name=f"Head_cheek{s}")

# ---------------------------------------------------------------- jaw (rest open 12 deg)
JAW_ROOT = (3.1, 1.0, 0.0)
JAW_OPEN = -12
seg("Jaw", JAW_ROOT)
for key, size, c, nm in [
    ("main", (2.0, 0.26, 0.46), (4.15, 0.83, 0.0), "Jaw_lower"),
    ("main", (0.35, 0.22, 0.4), (5.05, 0.86, 0.0), "Jaw_chin"),
    ("belly", (1.7, 0.08, 0.38), (4.1, 0.69, 0.0), "Jaw_under"),
] + [("tooth", (0.1, 0.11, 0.42), (x, 0.99, 0.0), f"Jaw_tooth{i + 1}") for i, x in enumerate([3.75, 4.0, 4.25, 4.5, 4.75, 5.0])]:
    part("Jaw", key, size, about(JAW_ROOT, c, JAW_OPEN), pitch=JAW_OPEN, name=nm)

# ---------------------------------------------------------------- arms (long, three big hand claws)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.52
    sh, el, ha = (1.65, -0.2), (1.95, -0.75), (2.35, -1.25)
    seg(f"Arm{s}", (sh[0], sh[1], side * 0.44))
    part(f"Arm{s}", "main", (0.24, 0.66, 0.2), ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, z),
         pitch=tilt_down(el[0] - sh[0], el[1] - sh[1]), name=f"Arm{s}_upper")
    part(f"Arm{s}", "limbs", (0.2, 0.68, 0.18), ((el[0] + ha[0]) / 2, (el[1] + ha[1]) / 2, z),
         pitch=tilt_down(ha[0] - el[0], ha[1] - el[1]), name=f"Arm{s}_fore")
    part(f"Arm{s}", "limbs", (0.28, 0.2, 0.22), (2.4, -1.32, z), name=f"Arm{s}_hand")
    for i, dz in enumerate((-0.07, 0.0, 0.07)):
        part(f"Arm{s}", "claws", (0.07, 0.38, 0.06), (2.55, -1.52, z + dz), pitch=30, name=f"Arm{s}_claw{i + 1}")

# ---------------------------------------------------------------- tail (long, straight, nearly level)
TAIL_RISE = 6.0
tail = [
    (1.25, (1.4, 0.68, 0.64), [(0.95, "stripes")]),
    (1.2, (1.32, 0.54, 0.5), [(0.45, "stripes"), (0.95, "tailbands")]),
    (1.15, (1.26, 0.42, 0.38), [(0.35, "stripes"), (0.8, "tailbands")]),
    (1.1, (1.2, 0.31, 0.28), [(0.3, "stripes"), (0.75, "tailbands")]),
    (1.1, (1.2, 0.21, 0.18), [(0.25, "tailbands"), (0.6, "stripes"), (0.95, "tailbands")]),
]
_a = math.radians(TAIL_RISE)
_dir = (-math.cos(_a), math.sin(_a))
_root = (-0.95, 0.3)
for i, (seglen, size, bands) in enumerate(tail):
    name = f"Tail{i + 1}"
    seg(name, (_root[0], _root[1], 0.0))
    centre = (_root[0] + _dir[0] * (size[0] / 2 - 0.05), _root[1] + _dir[1] * (size[0] / 2 - 0.05), 0.0)
    part(name, "main", size, centre, pitch=-TAIL_RISE)
    part(name, "stripes", (size[0] * 0.9, 0.08, size[2] * 0.45),
         (centre[0], centre[1] + size[1] / 2 + 0.02, 0.0), pitch=-TAIL_RISE, name=f"{name}_backstripe")
    for j, (d, key) in enumerate(bands):
        part(name, key, (0.16, size[1] + 0.04, size[2] + 0.04), (_root[0] + _dir[0] * d, _root[1] + _dir[1] * d, 0.0),
             pitch=-TAIL_RISE, name=f"{name}_band{j + 1}")
    _root = (_root[0] + _dir[0] * seglen, _root[1] + _dir[1] * seglen)

# ---------------------------------------------------------------- legs (long, built for speed)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.48
    hip, knee, ankle, ball = (-0.15, 0.0), (0.25, -1.05), (-0.4, -2.0), (-0.12, -2.75)
    seg(f"Leg{s}", (hip[0], hip[1], z))
    part(f"Leg{s}", "main", (0.55, 1.3, 0.5), ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, z),
         pitch=tilt_down(knee[0] - hip[0], knee[1] - hip[1]), name=f"Leg{s}_thigh")
    part(f"Leg{s}", "main", (1.0, 0.75, 0.55), (-0.1, -0.22, z), pitch=10, name=f"Leg{s}_muscle")
    part(f"Leg{s}", "markings", (0.3, 0.2, 0.04), (-0.15, -0.15, z + side * 0.28), name=f"Leg{s}_spot")
    seg(f"Shin{s}", (knee[0], knee[1], z))
    part(f"Shin{s}", "limbs", (0.32, 1.25, 0.34), ((knee[0] + ankle[0]) / 2, (knee[1] + ankle[1]) / 2, z),
         pitch=tilt_down(ankle[0] - knee[0], ankle[1] - knee[1]), name=f"Shin{s}_shin")
    seg(f"Foot{s}", (ankle[0], ankle[1], z))
    part(f"Foot{s}", "limbs", (0.27, 0.85, 0.28), ((ankle[0] + ball[0]) / 2, (ankle[1] + ball[1]) / 2, z),
         pitch=tilt_down(ball[0] - ankle[0], ball[1] - ankle[1]), name=f"Foot{s}_meta")
    part(f"Foot{s}", "limbs", (0.75, 0.2, 0.38), (0.15, -2.8, z), name=f"Foot{s}_toes")
    for i, dz in enumerate((-0.12, 0.0, 0.12)):
        part(f"Foot{s}", "claws", (0.15, 0.11, 0.07), (0.57, -2.83, z + dz), name=f"Foot{s}_claw{i + 1}")

JOINTS = [("RootJoint", "HRP", "Torso"), ("Neck", "Torso", "Neck"), ("Head", "Neck", "Head"), ("Jaw", "Head", "Jaw"),
          ("ArmL", "Torso", "ArmL"), ("ArmR", "Torso", "ArmR"), ("Tail1", "Torso", "Tail1"), ("Tail2", "Tail1", "Tail2"),
          ("Tail3", "Tail2", "Tail3"), ("Tail4", "Tail3", "Tail4"), ("Tail5", "Tail4", "Tail5"),
          ("LegL", "Torso", "LegL"), ("LegR", "Torso", "LegR"), ("KneeL", "LegL", "ShinL"), ("KneeR", "LegR", "ShinR"),
          ("AnkleL", "ShinL", "FootL"), ("AnkleR", "ShinR", "FootR")]


# ---------------------------------------------------------------- bounds + length scale
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
    s = segments[n]
    s["root"] = tuple(v * K for v in s["root"])
    for p in s["parts"]:
        p["size"] = tuple(v * K for v in p["size"])
        p["center"] = tuple(v * K for v in p["center"])
HIP = HIP0 * K
HRP_SIZE_D = tuple(v * K for v in HRP_SIZE_D0)
lo, hi = bounds()


def cf(pos_d, R_d=None):
    R = matmul(M, R_d if R_d else rot())
    p = mv(M, pos_d)
    return [round(v, 5) + 0.0 for v in list(p) + [R[0][0], R[0][1], R[0][2], R[1][0], R[1][1], R[1][2], R[2][0], R[2][1], R[2][2]]]


def fmt(v):
    return "{" + ",".join(f"{x:g}" for x in v) + "}"


def body_lines():
    out = []
    hx, hy, hz = HRP_SIZE_D
    out.append(f'\thrp = {{size = {{{hz:.4g},{hy:.4g},{hx:.4g}}}, color = "A3A2A5", surface = {{"Studs","Inlet","Smooth","Smooth","Smooth","Smooth"}}}},')
    out.append(f'\thumanoid = {{RigType = "R15", HipHeight = {HIP - hy / 2:.4g}, DisplayDistanceType = "None"}},')
    out.append('\tmodelStreamingMode = "Atomic",')
    out.append("\tsegments = {")
    for n in order:
        s = segments[n]
        out.append(f'\t\t{{name = "{n}", root = {fmt(cf(s["root"]))}, parts = {{')
        for p in s["parts"]:
            surface = '"Smooth"' if p["key"] in SMOOTH else '"Studs"'
            out.append(f'\t\t\t{{name = "{p["name"]}", size = {fmt([round(v, 4) for v in p["size"]])}, '
                       f'cf = {fmt(cf(p["center"], p["R"]))}, color = "{C[p["key"]]}", surface = {surface}}},')
        out.append("\t\t}},")
    out.append("\t},")
    out.append("\tjoints = {")
    for jn, p0, p1 in JOINTS:
        if p0 == "HRP":
            c0 = cf((0.0, 0.0, 0.0))
        else:
            a, b = segments[p0]["root"], segments[p1]["root"]
            c0 = [round(b[i] - a[i], 5) + 0.0 for i in range(3)] + [1, 0, 0, 0, 1, 0, 0, 0, 1]
        out.append(f'\t\t{{name = "{jn}", part0 = "{p0}", part1 = "{p1}", c0 = {fmt(c0)}, c1 = {{0,0,0,1,0,0,0,1,0,0,0,1}}}},')
    out.append("\t},")
    return out


if "--mock" in sys.argv:
    path = sys.argv[sys.argv.index("--mock") + 1]
    lines = ["return {", f'\tversion = "{VERSION}", species = "Herrera", style = "1.0", rig = "1.3",'] + body_lines() + ["\tattributes = {Species = \"Herrera\"},", "}"]
    open(path, "w").write("\n".join(lines) + "\n")
    print("mock ->", path)
n = sum(len(segments[s]["parts"]) for s in order)
print(f"{n} parts, {len(order)} segments, scale {K:.3f}, HIP {HIP:.3f}")
print("D bounds: length %.2f, height %.2f (ground %.2f, top %.2f), width %.2f" % (
    hi[0] - lo[0], hi[1] + HIP, -HIP, hi[1], hi[2] - lo[2]))
print("lowest point %.3f vs ground %.3f" % (lo[1], -HIP))
