#!/usr/bin/env python3
"""Pachy generator v1.0 (Mecha Dino Arena) -> src/shared/Models/PachyModelData.luau

Pachycephalosaurus in the T-Rex / raptor block style. Plan docs/plans/PACHY_MODEL_v1.0.md, mockup
docs/mockups/pachy_model_options.html, inspo docs/reference/pachy/ (Kepu 2026-10-30: knob ring head by default, "the
spikes can be the fully upgraded attack stat", "lets keep it at 15 studs" = a bit bigger than the raptor: built at
~15 studs like the raptor's 12.85 and doubled in game like the raptor).
Scale: T-Rex 40.1 studs ~ 12.3 m (3.26 studs/m); pachy ~4.5 m -> ~14.8 studs long, hip 4.0.

Skin-ready (Kepu: "these models were making from this point forward have to be made with skins in mind"): every block
uses exactly one colour group (C below); no hex is shared between groups; pupils (111111) and mouth (6E342E) are the
never-paint colours of SkinCatalog. Spikes ("Head_spike*", group knobs) are built transparent (shown later by the
abilities plan when the attack line is maxed; model attribute PachySpikes false).

Same 17-segment rig and joint names as the T-Rex and raptor (rig 1.3):
  RootJoint (HRP->Torso), Neck, Head, Jaw, ArmL/R, Tail1-5, LegL/R (hip), KneeL/R, AnkleL/R.
All joints are world-aligned (identity rotation in C0); tilts are baked into the parts.

Coordinates: "dino space" D = (x forward, y up, z side; z > 0 is the L side), origin at the hip centre
(= HumanoidRootPart centre). HRP space = (z, y, -x).
Gameplay attributes: the T-Rex's (as the raptor inherits them) with every move switched off; abilities, speeds and gait
come with the abilities plan.
Run: python3 tools/pachy_generator.py   (writes the data file; prints the bounds and the colour check)
"""
import math, re, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Models", "PachyModelData.luau")
TREX = os.path.join(ROOT, "src", "shared", "Models", "TRexModelData.luau")

VERSION = "1.0"
HIP = 4.0            # hip (HRP centre) height above the ground
HRP_SIZE_D = (4.0, 3.0, 1.8)   # D x (length), y, z (width)

C = {   # colour groups (Classic) — each a SkinCatalog role, no hex shared
    "main":    "7A6A4E",  # olive-brown body
    "stripes": "3E5A55",  # dark teal stripes
    "belly":   "C8B898",  # pale belly / throat
    "dome":    "E6DCC4",  # bone dome
    "knobs":   "8C7A5A",  # knob ring and spikes
    "mask":    "3F6F7A",  # teal eye patch
    "limbs":   "5E5240",  # lower legs, feet, hands
    "claws":   "2E2620",
    "eyes":    "8A2A1E",  # red-brown iris
    "pupil":   "111111",  # never painted
    "mouth":   "6E342E",  # never painted
}
ROLES = ("main", "stripes", "belly", "dome", "knobs", "mask", "limbs", "claws", "eyes")
SMOOTH = {"eyes", "pupil", "claws", "mouth", "dome"}

M = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))  # D -> HRP space


def matmul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mv(a, v):
    return tuple(sum(a[i][k] * v[k] for k in range(3)) for i in range(3))


def rot(pitch=0.0, yaw=0.0, roll=0.0):
    """Rotation in D: roll about x, then yaw about y, then pitch about z (degrees), R = Rz*Ry*Rx."""
    p, y, r = math.radians(pitch), math.radians(yaw), math.radians(roll)
    Rz = ((math.cos(p), -math.sin(p), 0), (math.sin(p), math.cos(p), 0), (0, 0, 1))
    Ry = ((math.cos(y), 0, math.sin(y)), (0, 1, 0), (-math.sin(y), 0, math.cos(y)))
    Rx = ((1, 0, 0), (0, math.cos(r), -math.sin(r)), (0, math.sin(r), math.cos(r)))
    return matmul(Rz, matmul(Ry, Rx))


def cf(pos_d, R_d=None):
    R = matmul(M, R_d if R_d else rot())
    p = mv(M, pos_d)
    vals = list(p) + [R[0][0], R[0][1], R[0][2], R[1][0], R[1][1], R[1][2], R[2][0], R[2][1], R[2][2]]
    return [round(v, 6) + 0.0 for v in vals]


segments = {}
order = []


def seg(name, root):
    segments[name] = {"root": root, "parts": []}
    order.append(name)


def part(segname, key, size, center, pitch=0.0, yaw=0.0, roll=0.0, name=None, hidden=False):
    segments[segname]["parts"].append({
        "name": name or f"{segname}_{key}",
        "size": size, "center": center, "R": rot(pitch, yaw, roll), "key": key, "hidden": hidden})


def tilt_down(dx, dy):
    """pitch (deg) that turns a box's +Y axis to point along (dx, dy) downward direction (bottom end toward +x)."""
    return math.degrees(math.atan2(dx, -dy))


def along(c, pitch, d):
    """point d studs along a box's x axis tilted by pitch (deg) from centre c (2D)."""
    a = math.radians(pitch)
    return (c[0] + d * math.cos(a), c[1] + d * math.sin(a))


# ---------------------------------------------------------------- torso (thick, front raised 15 deg)
BODY_P = 15
seg("Torso", (0.0, 0.0, 0.0))
part("Torso", "main", (3.0, 1.9, 1.7), (0.6, 0.5, 0.0), pitch=BODY_P, name="Torso_body")
part("Torso", "main", (1.6, 1.9, 1.6), (2.0, 1.0, 0.0), pitch=25, name="Torso_chest")
part("Torso", "main", (1.6, 1.7, 1.6), (-0.8, 0.3, 0.0), pitch=5, name="Torso_hips")
part("Torso", "belly", (2.6, 0.35, 1.4), (0.9, -0.42, 0.0), pitch=BODY_P, name="Torso_belly")
part("Torso", "belly", (0.6, 1.3, 1.1), (2.65, 1.0, 0.0), pitch=25, name="Torso_throat")
for i, x in enumerate((-1.1, -0.4, 0.3, 1.0, 1.7)):
    top = 0.5 + 0.95 / math.cos(math.radians(BODY_P)) + (x - 0.6) * math.tan(math.radians(BODY_P))
    part("Torso", "stripes", (0.26, 1.0, 1.76), (x, top - 0.42, 0.0), pitch=BODY_P, name=f"Torso_stripe{i + 1}")

# ---------------------------------------------------------------- neck (thick, rising forward)
NECK_P = 55
seg("Neck", (2.6, 1.6, 0.0))
part("Neck", "main", (1.9, 1.25, 1.2), (3.15, 2.4, 0.0), pitch=NECK_P, name="Neck_body")
nb = along((3.15, 2.4), NECK_P - 90, 0.5)  # toward the throat side
part("Neck", "belly", (1.6, 0.35, 1.0), (nb[0], nb[1], 0.0), pitch=NECK_P, name="Neck_throat")
ns = along((3.15, 2.4), NECK_P, -0.35)
part("Neck", "stripes", (0.24, 1.3, 1.24), (ns[0], ns[1], 0.0), pitch=NECK_P, name="Neck_stripe1")

# ---------------------------------------------------------------- head (skull, 3-tier bone dome, snout, knob ring)
seg("Head", (3.7, 3.2, 0.0))
part("Head", "main", (1.6, 1.2, 1.25), (4.2, 3.4, 0.0), name="Head_skull")
part("Head", "dome", (1.55, 0.55, 1.2), (4.05, 4.25, 0.0), name="Head_dome1")
part("Head", "dome", (1.15, 0.42, 0.95), (4.05, 4.7, 0.0), name="Head_dome2")
part("Head", "dome", (0.65, 0.26, 0.6), (4.05, 5.03, 0.0), name="Head_dome3")
part("Head", "main", (0.95, 0.8, 0.8), (5.3, 3.2, 0.0), pitch=-15, name="Head_snout")
part("Head", "main", (0.4, 0.5, 0.56), (5.85, 3.0, 0.0), pitch=-15, name="Head_beak")
part("Head", "mouth", (0.95, 0.08, 0.72), (5.25, 2.84, 0.0), name="Head_mouth")
for side in (1, -1):
    s = "L" if side > 0 else "R"
    part("Head", "mask", (0.62, 0.5, 0.03), (4.45, 3.55, side * 0.64), name=f"Head_mask{s}")
    part("Head", "eyes", (0.22, 0.22, 0.04), (4.5, 3.6, side * 0.655), name=f"Head_eye{s}")
    part("Head", "pupil", (0.08, 0.18, 0.03), (4.52, 3.6, side * 0.675), name=f"Head_pupil{s}")
    part("Head", "stripes", (0.1, 0.08, 0.05), (5.62, 3.3, side * 0.26), name=f"Head_nostril{s}")
# knob ring (default look)
KNOBS = [(3.35, 3.95, 0.0), (3.42, 3.85, 0.45), (3.42, 3.85, -0.45), (3.55, 3.55, 0.62), (3.55, 3.55, -0.62),
         (3.55, 4.28, 0.36), (3.55, 4.28, -0.36), (4.0, 4.02, 0.66), (4.0, 4.02, -0.66), (4.6, 3.05, 0.66),
         (4.6, 3.05, -0.66), (5.0, 3.68, 0.0), (5.3, 3.62, 0.3), (5.3, 3.62, -0.3), (5.58, 3.42, 0.0)]
for i, (x, y, z) in enumerate(KNOBS):
    part("Head", "knobs", (0.28, 0.28, 0.28), (x, y, z), name=f"Head_knob{i + 1}")
# spikes (hidden: the fully upgraded attack look)
SPIKES = [  # centre, pitch (+ = leaning back), roll (+ = leaning to the L side)
    ((3.2, 4.15, 0.0), 50, 0), ((3.3, 4.05, 0.42), 45, 25), ((3.3, 4.05, -0.42), 45, -25),
    ((3.5, 3.7, 0.66), 35, 45), ((3.5, 3.7, -0.66), 35, -45), ((3.5, 4.45, 0.3), 30, 15), ((3.5, 4.45, -0.3), 30, -15),
    ((5.3, 3.8, 0.28), -20, 15), ((5.3, 3.8, -0.28), -20, -15), ((5.65, 3.55, 0.0), -40, 0),
]
for i, ((x, y, z), p, r) in enumerate(SPIKES):
    part("Head", "knobs", (0.22, 0.85, 0.22), (x, y, z), pitch=p, roll=r, name=f"Head_spike{i + 1}", hidden=True)

# ---------------------------------------------------------------- jaw (small beak jaw)
seg("Jaw", (4.6, 2.9, 0.0))
part("Jaw", "main", (1.15, 0.35, 0.8), (5.15, 2.68, 0.0), pitch=-10, name="Jaw_lower")
part("Jaw", "belly", (0.9, 0.12, 0.7), (5.05, 2.5, 0.0), pitch=-10, name="Jaw_under")

# ---------------------------------------------------------------- arms (short, three claws)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.78
    sh, el, ha = (2.4, 0.4), (2.6, -0.2), (2.9, -0.7)
    seg(f"Arm{s}", (sh[0], sh[1], side * 0.7))
    part(f"Arm{s}", "main", (0.34, 0.7, 0.32), ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, z),
         pitch=tilt_down(el[0] - sh[0], el[1] - sh[1]), name=f"Arm{s}_upper")
    part(f"Arm{s}", "main", (0.28, 0.62, 0.28), ((el[0] + ha[0]) / 2, (el[1] + ha[1]) / 2, z),
         pitch=tilt_down(ha[0] - el[0], ha[1] - el[1]), name=f"Arm{s}_fore")
    part(f"Arm{s}", "limbs", (0.32, 0.22, 0.3), (2.95, -0.85, z), name=f"Arm{s}_hand")
    for i, dz in enumerate((-0.08, 0.0, 0.08)):
        part(f"Arm{s}", "claws", (0.06, 0.26, 0.05), (3.05, -1.02, z + dz), pitch=20, name=f"Arm{s}_claw{i + 1}")

# ---------------------------------------------------------------- tail (level, slightly down, striped)
TAIL_RISE = -3.0
tail = [  # segment length, block size, stripe offsets from the root
    (1.6, (1.75, 1.3, 1.2), (0.55, 1.15)),
    (1.5, (1.65, 1.0, 0.95), (0.5, 1.05)),
    (1.4, (1.55, 0.78, 0.74), (0.45, 1.0)),
    (1.3, (1.45, 0.56, 0.54), (0.4, 0.9)),
    (1.3, (1.4, 0.38, 0.36), (0.35, 0.85)),
]
_a = math.radians(TAIL_RISE)
_dir = (-math.cos(_a), math.sin(_a))
_root = (-1.5, 0.35)
for i, (seglen, size, bands) in enumerate(tail):
    name = f"Tail{i + 1}"
    seg(name, (_root[0], _root[1], 0.0))
    centre = (_root[0] + _dir[0] * (size[0] / 2 - 0.05), _root[1] + _dir[1] * (size[0] / 2 - 0.05), 0.0)
    part(name, "main", size, centre, pitch=-TAIL_RISE)
    for j, d in enumerate(bands):
        part(name, "stripes", (0.2, size[1] + 0.04, size[2] + 0.04), (_root[0] + _dir[0] * d, _root[1] + _dir[1] * d, 0.0),
             pitch=-TAIL_RISE, name=f"{name}_stripe{j + 1}")
    _root = (_root[0] + _dir[0] * seglen, _root[1] + _dir[1] * seglen)

# ---------------------------------------------------------------- legs (strong: thigh, shin, metatarsus, toes)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.75
    hip, knee, ankle, ball = (-0.2, 0.0), (0.35, -1.6), (-0.45, -2.9), (-0.1, -3.76)
    seg(f"Leg{s}", (hip[0], hip[1], z))
    part(f"Leg{s}", "main", (0.85, 1.8, 0.75), ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, z),
         pitch=tilt_down(knee[0] - hip[0], knee[1] - hip[1]), name=f"Leg{s}_thigh")
    part(f"Leg{s}", "main", (1.4, 1.1, 0.8), (-0.15, -0.35, z), pitch=10, name=f"Leg{s}_muscle")
    part(f"Leg{s}", "stripes", (0.18, 1.1, 0.83), (-0.32, -0.32, z), pitch=10, name=f"Leg{s}_stripe")
    seg(f"Shin{s}", (knee[0], knee[1], z))
    part(f"Shin{s}", "limbs", (0.5, 1.6, 0.5), ((knee[0] + ankle[0]) / 2, (knee[1] + ankle[1]) / 2, z),
         pitch=tilt_down(ankle[0] - knee[0], ankle[1] - knee[1]), name=f"Shin{s}_shin")
    seg(f"Foot{s}", (ankle[0], ankle[1], z))
    part(f"Foot{s}", "limbs", (0.42, 1.0, 0.42), ((ankle[0] + ball[0]) / 2, (ankle[1] + ball[1]) / 2, z),
         pitch=tilt_down(ball[0] - ankle[0], ball[1] - ankle[1]), name=f"Foot{s}_meta")
    part(f"Foot{s}", "limbs", (1.05, 0.24, 0.6), (0.25, -HIP + 0.12, z), name=f"Foot{s}_toes")
    for i, dz in enumerate((-0.18, 0.0, 0.18)):
        part(f"Foot{s}", "claws", (0.22, 0.14, 0.1), (0.85, -HIP + 0.07, z + dz), name=f"Foot{s}_claw{i + 1}")

JOINTS = [("RootJoint", "HRP", "Torso"), ("Neck", "Torso", "Neck"), ("Head", "Neck", "Head"), ("Jaw", "Head", "Jaw"),
          ("ArmL", "Torso", "ArmL"), ("ArmR", "Torso", "ArmR"), ("Tail1", "Torso", "Tail1"), ("Tail2", "Tail1", "Tail2"),
          ("Tail3", "Tail2", "Tail3"), ("Tail4", "Tail3", "Tail4"), ("Tail5", "Tail4", "Tail5"),
          ("LegL", "Torso", "LegL"), ("LegR", "Torso", "LegR"), ("KneeL", "LegL", "ShinL"), ("KneeR", "LegR", "ShinR"),
          ("AnkleL", "ShinL", "FootL"), ("AnkleR", "ShinR", "FootR")]

# ---------------------------------------------------------------- attributes: the T-Rex's, every move off
trex = open(TREX).read()
block = trex[trex.index("attributes = {"):]
block = block[:block.index("\n\t},")]
attrs = {}
for m in re.finditer(r'^\t\t(\w+) = (.+?),$', block, re.M):
    attrs[m.group(1)] = m.group(2)
OVERRIDES = {
    "Species": '"Pachy"', "StyleVersion": '"1.0"', "PachyModelVersion": f'"{VERSION}"', "DisplayName": '"Pachy"',
    "RigHipHeight": f"{HIP}", "PachySpikes": "false",
    "BiteEnabled": "false", "PounceEnabled": "false", "RamEnabled": "false", "RoarEnabled": "false",
    "JumpEnabled": "false", "CreepEnabled": "false",
}
attrs.update(OVERRIDES)
for k in ("StarterCharacterVersion",):
    attrs.pop(k, None)


def fmt_list(v):
    return "{" + ",".join(f"{x:g}" if isinstance(x, float) else str(x) for x in v) + "}"


# colour check (skin rule)
hexes = [C[r] for r in ROLES]
assert len(set(hexes)) == len(hexes), "two colour groups share a hex"
assert C["pupil"] not in hexes and C["mouth"] not in hexes, "a group uses a never-paint colour"

lines = []
lines.append(f"-- PachyModelData v{VERSION} (Mecha Dino Arena) — block-style Pachycephalosaurus, rig 1.3 joint names, skin-ready colour groups.")
lines.append("-- Generated by tools/pachy_generator.py (do not edit by hand; change the generator and re-run).")
lines.append(f"-- Scale: T-Rex 40.1 studs ~ 12.3 m; pachy ~4.5 m -> about 14.8 studs long, hip {HIP} studs (doubled in game like the raptor).")
lines.append("-- Colour groups: " + ", ".join(f"{r} {C[r]}" for r in ROLES) + "; never painted: pupil 111111, mouth 6E342E.")
lines.append("-- Head_spike* parts are hidden (Transparency 1): the fully upgraded attack look, shown by the abilities plan.")
lines.append("-- All CFrames are relative to the HumanoidRootPart; sizes in studs; colors hex RGB.")
lines.append("-- Rebuild with DinoModelBuilder.build(require(PachyModelData)).")
lines.append("return {")
lines.append(f'\tversion = "{VERSION}", species = "Pachy", style = "1.0", rig = "1.3",')
hx, hy, hz = HRP_SIZE_D
lines.append(f'\thrp = {{size = {{{hz},{hy},{hx}}}, color = "A3A2A5", surface = {{"Studs","Inlet","Smooth","Smooth","Smooth","Smooth"}}}},')
lines.append(f'\thumanoid = {{RigType = "R15", HipHeight = {HIP - hy / 2:g}, DisplayDistanceType = "None"}},')
lines.append('\tmodelStreamingMode = "Atomic",')
lines.append("\tsegments = {")
lo = [1e9] * 3
hi = [-1e9] * 3
count = 0
for name in order:
    s = segments[name]
    lines.append(f'\t\t{{name = "{name}", root = {fmt_list(cf(s["root"]))}, parts = {{')
    for p in s["parts"]:
        surface = '"Smooth"' if p["key"] in SMOOTH else '"Studs"'
        extra = ", transparency = 1" if p["hidden"] else ""
        lines.append(f'\t\t\t{{name = "{p["name"]}", size = {fmt_list([round(v, 4) for v in p["size"]])}, '
                     f'cf = {fmt_list(cf(p["center"], p["R"]))}, color = "{C[p["key"]]}", surface = {surface}{extra}}},')
        count += 1
        if p["hidden"]:
            continue
        hx2, hy2, hz2 = (v / 2 for v in p["size"])
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    w = mv(p["R"], (sx * hx2, sy * hy2, sz * hz2))
                    for i in range(3):
                        lo[i] = min(lo[i], p["center"][i] + w[i])
                        hi[i] = max(hi[i], p["center"][i] + w[i])
    lines.append("\t\t}},")
lines.append("\t},")
lines.append("\tjoints = {")
for jn, p0, p1 in JOINTS:
    if p0 == "HRP":
        c0 = cf((0.0, 0.0, 0.0))
    else:
        a, b = segments[p0]["root"], segments[p1]["root"]
        c0 = [round(b[i] - a[i], 6) + 0.0 for i in range(3)] + [1, 0, 0, 0, 1, 0, 0, 0, 1]
    lines.append(f'\t\t{{name = "{jn}", part0 = "{p0}", part1 = "{p1}", c0 = {fmt_list(c0)}, c1 = {{0,0,0,1,0,0,0,1,0,0,0,1}}}},')
lines.append("\t},")
lines.append("\tattributes = {")
for k in sorted(attrs):
    lines.append(f"\t\t{k} = {attrs[k]},")
lines.append("\t},")
lines.append("}")
open(OUT, "w").write("\n".join(lines) + "\n")
print(f"{count} parts ({sum(1 for n in order for p in segments[n]['parts'] if p['hidden'])} hidden spikes), {len(order)} segments -> {OUT}")
print("D bounds (visible): x %.2f..%.2f (length %.2f)  y %.2f..%.2f (ground at %.2f, height %.2f)  z %.2f..%.2f (width %.2f)" % (
    lo[0], hi[0], hi[0] - lo[0], lo[1], hi[1], -HIP, hi[1] + HIP, lo[2], hi[2], hi[2] - lo[2]))
