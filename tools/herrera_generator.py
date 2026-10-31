#!/usr/bin/env python3
"""Herrerasaurus generator v0.3 (Mecha Dino Arena) — MOCKUP prototype (not installed in the game yet).

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

VERSION = "0.3"
TARGET_LEN = 11.2    # studs at scale 1 (raptor 12.85; doubled in game: ~22.4 vs the raptor's 25.4)
HIP0 = 3.3           # authored hip height before the length scale
HRP_SIZE_D0 = (3.2, 2.1, 1.2)

# v0.2: three palette candidates for the mockup (all keep the skin rule); PALETTE picks the Classic one
PALETTES = {
    "rust":     {"main": "B5652E", "stripes": "2A1E18", "belly": "E6D2A8", "markings": "8E2A22", "limbs": "8A4A24",
                 "claws": "241C18", "eyes": "F2D54A", "tailbands": "D9A66A", "mask": "3A2420"},
    "charcoal": {"main": "4A4F55", "stripes": "25282C", "belly": "B9B3A4", "markings": "C8323C", "limbs": "3A3E43",
                 "claws": "1A1A1C", "eyes": "F07A2A", "tailbands": "8C9096", "mask": "16181B"},
    "olive":    {"main": "6E6A3A", "stripes": "2F3320", "belly": "D3C89A", "markings": "B8414A", "limbs": "5A5530",
                 "claws": "2C2620", "eyes": "E8C547", "tailbands": "B9B26A", "mask": "262A1A"},
}
PALETTE = sys.argv[sys.argv.index("--palette") + 1] if "--palette" in sys.argv else "rust"
C = {
    **PALETTES[PALETTE],
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


# ---------------------------------------------------------------- v0.3 (Kepu 2026-10-30: "it looks exactly like a raptor. It
# needs to look different" / "The facial structure and the whole body needs to be it's own"): its own body plan:
#   head  - a WEDGE: tall boxy rear skull tapering to a long snout, a dark open window on the side of the snout (the
#           fenestra), a hooked-down snout tip with a notch and a big fang behind it, horn ridges over the eyes, a deep
#           kinked lower jaw, a red throat pouch;
#   body  - deep chest with a shoulder hump, narrow hips, a row of dark back scutes and slanted flank stripes, held
#           level; long neck carried forward; big three-claw hands; long legs; a long straight tail.
seg("Torso", (0.0, 0.0, 0.0))
part("Torso", "main", (2.7, 1.1, 0.92), (0.45, 0.15, 0.0))
part("Torso", "main", (1.15, 1.3, 0.94), (1.8, 0.05, 0.0), pitch=-10, name="Torso_chest")
part("Torso", "main", (1.0, 0.4, 0.82), (1.45, 0.78, 0.0), pitch=-6, name="Torso_hump")
part("Torso", "main", (1.0, 0.95, 0.84), (-0.65, 0.25, 0.0), pitch=4, name="Torso_hips")
part("Torso", "belly", (2.6, 0.24, 0.76), (0.55, -0.42, 0.0))
part("Torso", "belly", (0.6, 0.9, 0.8), (2.25, -0.05, 0.0), pitch=-10, name="Torso_breast")
for i, (x, y) in enumerate([(-1.0, 0.8), (-0.55, 0.8), (-0.1, 0.8), (0.35, 0.8), (0.8, 0.84), (1.25, 1.06), (1.7, 1.02)]):
    part("Torso", "stripes", (0.3, 0.26, 0.3), (x, y, 0.0), name=f"Torso_scute{i + 1}")
for i, x in enumerate([-0.85, -0.35, 0.15, 0.65, 1.15, 1.65]):
    for side in (1, -1):
        part("Torso", "stripes", (0.15, 0.8, 0.04), (x, 0.28, side * 0.47), pitch=18, name=f"Torso_stripe{i + 1}{'L' if side > 0 else 'R'}")
for i, (x, y) in enumerate([(-0.6, -0.15), (0.4, -0.12), (1.4, -0.15)]):
    for side in (1, -1):
        part("Torso", "markings", (0.28, 0.22, 0.04), (x, y, side * 0.475), name=f"Torso_spot{i + 1}{'L' if side > 0 else 'R'}")

# ---------------------------------------------------------------- neck (long, carried forward)
seg("Neck", (2.25, 0.5, 0.0))
part("Neck", "main", (1.0, 0.68, 0.64), (2.7, 0.78, 0.0), pitch=28)
part("Neck", "main", (0.95, 0.6, 0.56), (3.38, 1.12, 0.0), pitch=15, name="Neck_upper")
part("Neck", "belly", (1.5, 0.2, 0.48), (3.0, 0.62, 0.0), pitch=22, name="Neck_throat")
part("Neck", "stripes", (0.26, 0.22, 0.26), (2.65, 1.2, 0.0), pitch=28, name="Neck_scute1")
part("Neck", "stripes", (0.24, 0.2, 0.24), (3.25, 1.47, 0.0), pitch=15, name="Neck_scute2")
part("Neck", "markings", (0.85, 0.46, 0.4), (3.55, 0.72, 0.0), pitch=12, name="Neck_dewlap1")
part("Neck", "markings", (0.45, 0.3, 0.32), (3.95, 0.66, 0.0), pitch=0, name="Neck_dewlap2")

# ---------------------------------------------------------------- head (wedge skull)
seg("Head", (3.75, 1.2, 0.0))
part("Head", "main", (0.85, 0.98, 0.88), (4.12, 1.32, 0.0), name="Head_skull")
part("Head", "main", (1.1, 0.74, 0.74), (4.98, 1.24, 0.0), pitch=-6, name="Head_snout")
part("Head", "main", (0.85, 0.56, 0.62), (5.88, 1.11, 0.0), pitch=-6, name="Head_muzzle")
part("Head", "main", (0.36, 0.52, 0.58), (6.42, 0.98, 0.0), pitch=22, name="Head_tip")
part("Head", "mouth", (2.4, 0.1, 0.62), (5.15, 0.86, 0.0), name="Head_mouth")
for i, x in enumerate([4.55, 4.8, 5.05, 5.3, 5.55, 5.8]):
    part("Head", "tooth", (0.1, 0.15, 0.66), (x, 0.9, 0.0), name=f"Head_tooth{i + 1}")
part("Head", "tooth", (0.13, 0.32, 0.68), (6.12, 0.82, 0.0), pitch=8, name="Head_fang")
part("Head", "stripes", (1.75, 0.06, 0.32), (5.3, 1.6, 0.0), pitch=-6, name="Head_snoutline")
part("Head", "stripes", (0.6, 0.1, 0.9), (4.2, 1.82, 0.0), name="Head_brow")
for side in (1, -1):
    s = "L" if side > 0 else "R"
    part("Head", "mask", (0.62, 0.36, 0.03), (4.98, 1.24, side * 0.37), pitch=-6, name=f"Head_window{s}")
    part("Head", "mask", (0.08, 0.08, 0.04), (6.42, 1.12, side * 0.28), name=f"Head_nostril{s}")
    part("Head", "eyes", (0.26, 0.24, 0.05), (4.3, 1.52, side * 0.445), name=f"Head_eye{s}")
    part("Head", "pupil", (0.07, 0.2, 0.03), (4.32, 1.52, side * 0.47), name=f"Head_pupil{s}")
    part("Head", "markings", (0.6, 0.18, 0.14), (4.3, 1.84, side * 0.38), pitch=-15, name=f"Head_browridge{s}")
    part("Head", "markings", (0.22, 0.3, 0.14), (4.02, 1.98, side * 0.38), pitch=-30, name=f"Head_browridgeTip{s}")
    part("Head", "stripes", (0.14, 0.5, 0.03), (3.82, 1.25, side * 0.445), pitch=12, name=f"Head_cheekstripe{s}")

# ---------------------------------------------------------------- jaw (deep at the back, kinked underside, rest open 8 deg)
JAW_ROOT = (3.9, 0.9, 0.0)
JAW_OPEN = -8
seg("Jaw", JAW_ROOT)
for key, size, c, nm, pch in [
    ("main", (1.0, 0.5, 0.66), (4.45, 0.62, 0.0), "Jaw_rear", 0),
    ("main", (1.25, 0.36, 0.6), (5.48, 0.68, 0.0), "Jaw_lower", 0),
    ("main", (0.75, 0.26, 0.52), (6.25, 0.74, 0.0), "Jaw_chin", -5),
    ("belly", (2.3, 0.08, 0.5), (5.25, 0.42, 0.0), "Jaw_under", 3),
] + [("tooth", (0.1, 0.12, 0.56), (x, 0.88, 0.0), f"Jaw_tooth{i + 1}", 0) for i, x in enumerate([4.75, 5.0, 5.25, 5.5, 5.75, 6.0, 6.25])]:
    part("Jaw", key, size, about(JAW_ROOT, c, JAW_OPEN), pitch=JAW_OPEN + pch, name=nm)

# ---------------------------------------------------------------- arms (big hands, long three-claw fingers)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.6
    sh, el, ha = (2.0, -0.1), (2.35, -0.75), (2.85, -1.05)
    seg(f"Arm{s}", (sh[0], sh[1], side * 0.5))
    part(f"Arm{s}", "main", (0.28, 0.76, 0.26), ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, z),
         pitch=tilt_down(el[0] - sh[0], el[1] - sh[1]), name=f"Arm{s}_upper")
    part(f"Arm{s}", "limbs", (0.25, 0.62, 0.23), ((el[0] + ha[0]) / 2, (el[1] + ha[1]) / 2, z),
         pitch=tilt_down(ha[0] - el[0], ha[1] - el[1]), name=f"Arm{s}_fore")
    part(f"Arm{s}", "limbs", (0.42, 0.3, 0.32), (2.92, -1.1, z), name=f"Arm{s}_hand")
    for i, dz in enumerate((-0.1, 0.0, 0.1)):
        part(f"Arm{s}", "claws", (0.09, 0.6, 0.08), (3.22, -1.32, z + dz), pitch=45, name=f"Arm{s}_claw{i + 1}")

# ---------------------------------------------------------------- tail (long, straight, scutes on the first three)
TAIL_RISE = 4.0
tail = [
    (1.4, (1.5, 0.78, 0.72), [(0.95, "stripes")], 2),
    (1.35, (1.42, 0.62, 0.56), [(0.45, "stripes"), (0.95, "tailbands")], 2),
    (1.3, (1.36, 0.48, 0.44), [(0.35, "stripes"), (0.8, "tailbands")], 1),
    (1.25, (1.3, 0.35, 0.32), [(0.3, "stripes"), (0.75, "tailbands")], 0),
    (1.25, (1.3, 0.23, 0.21), [(0.25, "tailbands"), (0.6, "stripes"), (0.95, "tailbands")], 0),
]
_a = math.radians(TAIL_RISE)
_dir = (-math.cos(_a), math.sin(_a))
_root = (-1.1, 0.35)
for i, (seglen, size, bands, scutes) in enumerate(tail):
    name = f"Tail{i + 1}"
    seg(name, (_root[0], _root[1], 0.0))
    centre = (_root[0] + _dir[0] * (size[0] / 2 - 0.05), _root[1] + _dir[1] * (size[0] / 2 - 0.05), 0.0)
    part(name, "main", size, centre, pitch=-TAIL_RISE)
    for j in range(scutes):
        d = 0.35 + j * 0.6
        part(name, "stripes", (0.26 - i * 0.04, 0.2 - i * 0.03, 0.26 - i * 0.04),
             (_root[0] + _dir[0] * d, _root[1] + _dir[1] * d + size[1] / 2 + 0.06, 0.0), pitch=-TAIL_RISE, name=f"{name}_scute{j + 1}")
    for j, (d, key) in enumerate(bands):
        part(name, key, (0.16, size[1] + 0.04, size[2] + 0.04), (_root[0] + _dir[0] * d, _root[1] + _dir[1] * d, 0.0),
             pitch=-TAIL_RISE, name=f"{name}_band{j + 1}")
    _root = (_root[0] + _dir[0] * seglen, _root[1] + _dir[1] * seglen)

# ---------------------------------------------------------------- legs (long, for speed)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.52
    hip, knee, ankle, ball = (-0.2, 0.0), (0.35, -1.25), (-0.5, -2.35), (-0.1, -3.1)
    seg(f"Leg{s}", (hip[0], hip[1], z))
    part(f"Leg{s}", "main", (0.64, 1.5, 0.54), ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, z),
         pitch=tilt_down(knee[0] - hip[0], knee[1] - hip[1]), name=f"Leg{s}_thigh")
    part(f"Leg{s}", "main", (1.2, 0.9, 0.58), (-0.15, -0.25, z), pitch=10, name=f"Leg{s}_muscle")
    part(f"Leg{s}", "stripes", (0.15, 0.75, 0.04), (-0.2, -0.3, z + side * 0.3), pitch=18, name=f"Leg{s}_stripe")
    seg(f"Shin{s}", (knee[0], knee[1], z))
    part(f"Shin{s}", "limbs", (0.36, 1.45, 0.38), ((knee[0] + ankle[0]) / 2, (knee[1] + ankle[1]) / 2, z),
         pitch=tilt_down(ankle[0] - knee[0], ankle[1] - knee[1]), name=f"Shin{s}_shin")
    seg(f"Foot{s}", (ankle[0], ankle[1], z))
    part(f"Foot{s}", "limbs", (0.3, 0.9, 0.32), ((ankle[0] + ball[0]) / 2, (ankle[1] + ball[1]) / 2, z),
         pitch=tilt_down(ball[0] - ankle[0], ball[1] - ankle[1]), name=f"Foot{s}_meta")
    part(f"Foot{s}", "limbs", (0.9, 0.22, 0.42), (0.22, -3.19, z), name=f"Foot{s}_toes")
    for i, dz in enumerate((-0.14, 0.0, 0.14)):
        part(f"Foot{s}", "claws", (0.18, 0.13, 0.08), (0.72, -3.22, z + dz), name=f"Foot{s}_claw{i + 1}")

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
