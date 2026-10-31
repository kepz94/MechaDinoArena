#!/usr/bin/env python3
"""Herrerasaurus generator v0.4 (Mecha Dino Arena) — MOCKUP prototype (not installed in the game yet).

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

VERSION = "0.4"
TARGET_LEN = 11.2    # studs at scale 1 (raptor 12.85; doubled in game: ~22.4 vs the raptor's 25.4)
HIP0 = 3.3           # authored hip height before the length scale
HRP_SIZE_D0 = (3.2, 2.1, 1.2)

# v0.2: three palette candidates for the mockup (all keep the skin rule); PALETTE picks the Classic one
PALETTES = {
    "rust":     {"main": "B5652E", "stripes": "2A1E18", "belly": "E6D2A8", "markings": "8E2A22", "limbs": "8A4A24",
                 "claws": "241C18", "eyes": "F2D54A", "tailbands": "D9A66A", "mask": "3A2420", "frill": "E2A93A"},
    "charcoal": {"main": "4A4F55", "stripes": "25282C", "belly": "B9B3A4", "markings": "C8323C", "limbs": "3A3E43",
                 "claws": "1A1A1C", "eyes": "F07A2A", "tailbands": "8C9096", "mask": "16181B", "frill": "E04A2C"},
    "olive":    {"main": "6E6A3A", "stripes": "2F3320", "belly": "D3C89A", "markings": "B8414A", "limbs": "5A5530",
                 "claws": "2C2620", "eyes": "E8C547", "tailbands": "B9B26A", "mask": "262A1A", "frill": "C9572E"},
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


# ---------------------------------------------------------------- v0.4 (Kepu 2026-10-30: "the body is basically the same thing
# as the raptor. You didn't add any creative character to it" / "It should look really different not even closely the
# same" -> "Hunched goblin" + "Frill-necked trickster"): its own body plan, nothing shared with the raptor's shapes:
#   goblin  - barrel chest and a high bony shoulder hump, pinched waist, scrawny hips; the spine rises from the hips to the
#             shoulders and the neck drops DOWN to an oversized head that hangs below the shoulder line; long dangling
#             arms almost to the ground with big hooked claws; skinny stilt legs with knobbly knees and big splayed feet;
#             a thin whip tail that curls up at the end;
#   face    - big round cranium with bulging eyes on top, little back-swept horns, a short wide snout, a jutting
#             underbite jaw with snaggle teeth poking up outside the lip;
#   trickster - a big flared fan frill around the back of the head (plates with dark spokes and a bright rim), a bright
#             throat sac, quills down the back getting longest at the shoulders, a quill tuft on the tail tip.
seg("Torso", (0.0, 0.0, 0.0))
part("Torso", "main", (0.85, 0.72, 0.68), (-0.5, 0.18, 0.0), pitch=10, name="Torso_hips")
part("Torso", "main", (0.85, 0.74, 0.66), (0.25, 0.32, 0.0), pitch=18, name="Torso_waist")
part("Torso", "main", (1.35, 1.45, 1.15), (1.15, 0.62, 0.0), pitch=25, name="Torso_chest")
part("Torso", "main", (1.05, 0.55, 1.05), (1.2, 1.38, 0.0), pitch=18, name="Torso_hump")
part("Torso", "belly", (1.5, 0.22, 0.56), (0.55, -0.08, 0.0), pitch=18, name="Torso_belly")
part("Torso", "belly", (0.45, 1.15, 0.95), (1.8, 0.4, 0.0), pitch=25, name="Torso_breast")
for i, (x, y, h) in enumerate([(-0.75, 0.55, 0.35), (-0.35, 0.68, 0.42), (0.05, 0.82, 0.5), (0.45, 1.05, 0.62),
                                (0.85, 1.42, 0.85), (1.25, 1.62, 1.0), (1.6, 1.58, 0.85)]):
    a = math.radians(55)
    part("Torso", "stripes", (0.13, h, 0.13), (x - math.sin(a) * h / 2 * 0.5, y + math.cos(a) * h / 2, 0.0), pitch=35, name=f"Torso_quill{i + 1}")
for i, x in enumerate([-0.55, 0.0, 0.55, 1.05]):
    for side in (1, -1):
        part("Torso", "stripes", (0.14, 0.62, 0.04), (x, 0.42 + x * 0.25, side * (0.37 + max(0, x) * 0.17)), pitch=-12,
             name=f"Torso_stripe{i + 1}{'L' if side > 0 else 'R'}")
for i, (x, y) in enumerate([(-0.2, 0.05), (0.7, 0.35)]):
    for side in (1, -1):
        part("Torso", "markings", (0.24, 0.2, 0.04), (x, y, side * (0.36 + max(0, x) * 0.25)), name=f"Torso_spot{i + 1}{'L' if side > 0 else 'R'}")

# ---------------------------------------------------------------- neck (drops down and forward from the hump)
seg("Neck", (1.75, 1.15, 0.0))
part("Neck", "main", (0.9, 0.64, 0.62), (2.15, 0.92, 0.0), pitch=-35)
part("Neck", "main", (0.8, 0.6, 0.58), (2.65, 0.6, 0.0), pitch=-22, name="Neck_lower")
part("Neck", "markings", (0.95, 0.62, 0.7), (2.75, 0.18, 0.0), pitch=-10, name="Neck_sac")
part("Neck", "markings", (0.55, 0.42, 0.56), (2.3, 0.45, 0.0), pitch=-25, name="Neck_sac2")
for i, (x, y) in enumerate([(2.05, 1.3), (2.5, 0.98)]):
    part("Neck", "stripes", (0.12, 0.55 - i * 0.12, 0.12), (x, y, 0.0), pitch=40, name=f"Neck_quill{i + 1}")

# ---------------------------------------------------------------- head (oversized, hanging low)
seg("Head", (3.0, 0.45, 0.0))
part("Head", "main", (1.15, 0.98, 1.05), (3.45, 0.6, 0.0), name="Head_cranium")
part("Head", "main", (1.15, 0.66, 0.86), (4.48, 0.46, 0.0), pitch=-4, name="Head_snout")
part("Head", "main", (0.38, 0.58, 0.8), (5.18, 0.4, 0.0), name="Head_tip")
part("Head", "mouth", (2.1, 0.08, 0.84), (4.3, 0.12, 0.0), name="Head_mouth")
for i, x in enumerate([3.75, 4.05, 4.35, 4.65, 4.95]):
    part("Head", "tooth", (0.1, 0.12, 0.86), (x, 0.15, 0.0), name=f"Head_tooth{i + 1}")
part("Head", "stripes", (1.2, 0.07, 0.4), (4.5, 0.8, 0.0), pitch=-4, name="Head_snoutline")
for side in (1, -1):
    s = "L" if side > 0 else "R"
    part("Head", "main", (0.46, 0.4, 0.4), (3.62, 1.12, side * 0.32), name=f"Head_eyebump{s}")
    part("Head", "eyes", (0.34, 0.3, 0.06), (3.66, 1.14, side * 0.53), name=f"Head_eye{s}")
    part("Head", "pupil", (0.1, 0.24, 0.03), (3.7, 1.14, side * 0.565), name=f"Head_pupil{s}")
    part("Head", "markings", (0.16, 0.5, 0.13), (3.28, 1.4, side * 0.32), pitch=45, name=f"Head_horn{s}")
    part("Head", "mask", (0.5, 0.3, 0.03), (4.45, 0.5, side * 0.44), pitch=-4, name=f"Head_cheek{s}")
    part("Head", "mask", (0.09, 0.09, 0.04), (5.3, 0.55, side * 0.33), name=f"Head_nostril{s}")
# the frill: a fan of plates around the back of the head, dark spokes between them, bright rim
FRILL_C = (2.92, 0.55)
for i, a in enumerate(range(-105, 106, 21)):
    r = 0.95
    ar = math.radians(a)
    part("Head", "frill", (0.1, 0.95, 0.5), (FRILL_C[0], FRILL_C[1] + r * math.cos(ar), r * math.sin(ar)), roll=a, name=f"Head_frill{i + 1}")
    part("Head", "markings", (0.11, 0.2, 0.52), (FRILL_C[0] - 0.01, FRILL_C[1] + 1.48 * math.cos(ar), 1.48 * math.sin(ar)), roll=a, name=f"Head_frillrim{i + 1}")
for i, a in enumerate(range(-94, 95, 21)):
    ar = math.radians(a)
    part("Head", "mask", (0.12, 1.0, 0.07), (FRILL_C[0] + 0.01, FRILL_C[1] + 0.98 * math.cos(ar), 0.98 * math.sin(ar)), roll=a, name=f"Head_frillspoke{i + 1}")

# ---------------------------------------------------------------- jaw (jutting underbite, snaggle teeth; rest open 4 deg)
JAW_ROOT = (3.2, 0.1, 0.0)
JAW_OPEN = -4
seg("Jaw", JAW_ROOT)
for key, size, c, nm, pch in [
    ("main", (2.2, 0.42, 0.95), (4.35, -0.12, 0.0), "Jaw_lower", 0),
    ("main", (0.42, 0.42, 0.88), (5.5, -0.06, 0.0), "Jaw_chin", 0),
    ("belly", (1.9, 0.08, 0.7), (4.3, -0.34, 0.0), "Jaw_under", 0),
] + [("tooth", (0.11, h, 0.1), (x, 0.1 + h / 2 - 0.05, side * zz), f"Jaw_snaggle{i + 1}{'L' if side > 0 else 'R'}", 0)
     for i, (x, h, zz) in enumerate([(5.45, 0.42, 0.34), (4.75, 0.32, 0.43), (4.1, 0.28, 0.45)]) for side in (1, -1)]:
    part("Jaw", key, size, about(JAW_ROOT, c, JAW_OPEN), pitch=JAW_OPEN + pch, name=nm)

# ---------------------------------------------------------------- arms (long, dangling, big hooked claws)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.66
    sh, el, wr = (1.6, 0.65), (1.95, -0.4), (2.2, -1.75)
    seg(f"Arm{s}", (sh[0], sh[1], side * 0.56))
    part(f"Arm{s}", "main", (0.38, 1.15, 0.34), ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, z),
         pitch=tilt_down(el[0] - sh[0], el[1] - sh[1]), name=f"Arm{s}_upper")
    part(f"Arm{s}", "main", (0.4, 0.34, 0.4), (el[0], el[1], z), name=f"Arm{s}_elbow")
    part(f"Arm{s}", "limbs", (0.3, 1.38, 0.28), ((el[0] + wr[0]) / 2, (el[1] + wr[1]) / 2, z),
         pitch=tilt_down(wr[0] - el[0], wr[1] - el[1]), name=f"Arm{s}_fore")
    part(f"Arm{s}", "limbs", (0.55, 0.36, 0.44), (2.32, -1.95, z), name=f"Arm{s}_hand")
    for i, dz in enumerate((-0.14, 0.0, 0.14)):
        part(f"Arm{s}", "claws", (0.12, 0.42, 0.1), (2.62, -2.12, z + dz), pitch=35, name=f"Arm{s}_claw{i + 1}")
        part(f"Arm{s}", "claws", (0.1, 0.3, 0.09), (2.84, -2.38, z + dz), pitch=75, name=f"Arm{s}_hook{i + 1}")

# ---------------------------------------------------------------- tail (thin whip, curls up at the end, quill tuft)
tail = [(1.4, (1.42, 0.5, 0.46), 8), (1.35, (1.36, 0.38, 0.34), 10), (1.25, (1.28, 0.28, 0.25), 16),
        (1.1, (1.14, 0.2, 0.18), 28), (0.95, (1.0, 0.14, 0.13), 45)]
_root = (-0.9, 0.38)
for i, (seglen, size, rise) in enumerate(tail):
    name = f"Tail{i + 1}"
    a = math.radians(rise)
    d = (-math.cos(a), math.sin(a))
    seg(name, (_root[0], _root[1], 0.0))
    centre = (_root[0] + d[0] * (size[0] / 2 - 0.05), _root[1] + d[1] * (size[0] / 2 - 0.05), 0.0)
    part(name, "main", size, centre, pitch=-rise)
    for j, dd in enumerate((0.35, 0.85)):
        key = "stripes" if j == 0 else "tailbands"
        part(name, key, (0.14, size[1] + 0.04, size[2] + 0.04), (_root[0] + d[0] * dd, _root[1] + d[1] * dd, 0.0), pitch=-rise, name=f"{name}_band{j + 1}")
    if i == 4:
        tip = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)
        for k, (yaw_, pt) in enumerate([(0, 20), (25, 35), (-25, 35)]):
            part(name, "stripes", (0.09, 0.6, 0.09), (tip[0] - 0.05, tip[1] + 0.25, math.sin(math.radians(yaw_)) * 0.18),
                 pitch=pt, roll=yaw_, name=f"{name}_quill{k + 1}")
    _root = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)

# ---------------------------------------------------------------- legs (skinny stilts, knobbly knees, big splayed feet)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.42
    hip, knee, ankle, ball = (-0.45, 0.05), (0.15, -1.3), (-0.55, -2.55), (-0.25, -3.18)
    seg(f"Leg{s}", (hip[0], hip[1], z))
    part(f"Leg{s}", "main", (0.62, 0.7, 0.5), (-0.4, -0.15, z), pitch=10, name=f"Leg{s}_haunch")
    part(f"Leg{s}", "main", (0.36, 1.45, 0.34), ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, z),
         pitch=tilt_down(knee[0] - hip[0], knee[1] - hip[1]), name=f"Leg{s}_thigh")
    seg(f"Shin{s}", (knee[0], knee[1], z))
    part(f"Shin{s}", "limbs", (0.46, 0.42, 0.44), (knee[0] + 0.05, knee[1], z), name=f"Shin{s}_knee")
    part(f"Shin{s}", "limbs", (0.22, 1.42, 0.24), ((knee[0] + ankle[0]) / 2, (knee[1] + ankle[1]) / 2, z),
         pitch=tilt_down(ankle[0] - knee[0], ankle[1] - knee[1]), name=f"Shin{s}_shin")
    seg(f"Foot{s}", (ankle[0], ankle[1], z))
    part(f"Foot{s}", "limbs", (0.22, 0.75, 0.24), ((ankle[0] + ball[0]) / 2, (ankle[1] + ball[1]) / 2, z),
         pitch=tilt_down(ball[0] - ankle[0], ball[1] - ankle[1]), name=f"Foot{s}_meta")
    for i, yw in enumerate((-28, 0, 28)):
        L = 1.0 if yw == 0 else 0.8
        dx, dz = math.cos(math.radians(yw)) * L / 2, -math.sin(math.radians(yw)) * L / 2
        part(f"Foot{s}", "limbs", (L, 0.16, 0.2), (-0.2 + dx, -3.22, z + dz), yaw=yw, name=f"Foot{s}_toe{i + 1}")
        part(f"Foot{s}", "claws", (0.2, 0.13, 0.1), (-0.2 + dx * 2 + 0.06, -3.24, z + dz * 2), yaw=yw, name=f"Foot{s}_claw{i + 1}")

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
