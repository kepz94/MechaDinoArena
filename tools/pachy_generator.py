#!/usr/bin/env python3
"""Pachy generator v1.2 (Mecha Dino Arena) -> src/shared/Models/PachyModelData.luau

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
v1.1 (plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 1, MDA-117; Kepu 2026-10-30: "a bit slower than the raptor but faster
      than the t-rex" -> run 45 in the arena, health 90, "it should be able to leap", headbutt charge numbers from the
      mockup docs/mockups/pachy_charge_options.html + "at least 20" damage + "shoved maybe 40 studs"): playable
      attributes. Geometry unchanged.
      DinoMaxHealth 90; MoveWalkSpeed 36.9 / MoveRunSpeed 69.2 (x ArenaSpeedScale 0.65 = 24 / 45; raptor 27 / 50.7,
      T-Rex 20.8 / 39); GaitAlwaysRun true; TurnLimitRate 360 (raptor 540, T-Rex 180); CameraStartZoom 18 (x2 in game);
      the raptor's leap (JumpEnabled ... JumpCooldown 0.5, JumpStaminaCost 0); Headbutt* settings (HeadbuttServer /
      HeadbuttTest 1.0); gait = the raptor's scaled by the hip (4.0 / 3.3 = 1.21) for lengths.
v1.2 (Kepu 2026-10-30: "i think the pachy charging speed is good but the base speed should be a little slower than the
      t-rex. it feels a little overpowered right now" -> run "37" in the arena; measured in Play: T-Rex 39, pachy 45):
      MoveRunSpeed 56.9 / MoveWalkSpeed 30.3 (x 0.65 = 37 / 19.7, the same walk / run ratio); HeadbuttSpeedMul 1.7 so the
      charge stays at 63 (37 x 1.7 = 62.9; was 45 x 1.4). Everything else unchanged.
v1.3 (Kepu 2026-10-31: "let's shorten the cool down for the pachy headbutts for each refill"; picked "3 s per charge"):
      HeadbuttRefill 3 (was 5). HeadbuttServer's tiers (x1.3 with 2 missing, x1.6 with 3) and the Bone Dome skill
      multiplier (x0.7) are unchanged: 3 / 3.9 / 4.8 s, 2.1 s with the skill. Everything else unchanged.
"""
import math, re, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Models", "PachyModelData.luau")
TREX = os.path.join(ROOT, "src", "shared", "Models", "TRexModelData.luau")

VERSION = "1.3"
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


def part(segname, key, size, center, pitch=0.0, yaw=0.0, roll=0.0, name=None, hidden=False, R=None):
    segments[segname]["parts"].append({
        "name": name or f"{segname}_{key}",
        "size": size, "center": center, "R": R or rot(pitch, yaw, roll), "key": key, "hidden": hidden})


def _norm(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v)


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def cone(segname, key, base, d, length, w, name, hidden=False, steps=((0.42, 1.0), (0.34, 0.64), (0.3, 0.32))):
    """v1.4: a cone-like spike from `base` along direction `d`: stacked tapering square blocks (all named name*)."""
    y = _norm(d)
    ref = (0.0, 1.0, 0.0) if abs(y[1]) < 0.9 else (1.0, 0.0, 0.0)
    x = _norm(_cross(y, ref))
    z = _cross(x, y)
    R = tuple(tuple((x, y, z)[j][i] for j in range(3)) for i in range(3))
    p = base
    for j, (fl, fw) in enumerate(steps):
        ln = length * fl
        c = tuple(p[i] + y[i] * ln / 2 for i in range(3))
        part(segname, key, (w * fw, ln + 0.04, w * fw), c, name=name + ("", "b", "c")[j], hidden=hidden, R=R)
        p = tuple(p[i] + y[i] * ln for i in range(3))


def rounded_slab(segname, key, c, L, H, W, name):
    """v1.4: a slab with its four upper edges chamfered (45-degree blocks), so a stack of them reads as a rounded dome."""
    cx, cy = c
    part(segname, key, (L * 0.86, H, W * 0.86), (cx, cy, 0.0), name=name)
    e = H * 0.72
    for side in (1, -1):
        part(segname, key, (L * 0.8, e, e), (cx, cy + H * 0.12, side * (W / 2 - e * 0.36)), roll=45, name=f"{name}_side{'L' if side > 0 else 'R'}")
        part(segname, key, (e, e, W * 0.8), (cx + side * (L / 2 - e * 0.36), cy + H * 0.12, 0.0), pitch=45, name=f"{name}_{'front' if side > 0 else 'back'}")


def tilt_down(dx, dy):
    """pitch (deg) that turns a box's +Y axis to point along (dx, dy) downward direction (bottom end toward +x)."""
    return math.degrees(math.atan2(dx, -dy))


def along(c, pitch, d):
    """point d studs along a box's x axis tilted by pitch (deg) from centre c (2D)."""
    a = math.radians(pitch)
    return (c[0] + d * math.cos(a), c[1] + d * math.sin(a))


# ---------------------------------------------------------------- torso (thick, front raised 15 deg)
BODY_P = 15
# v1.4 (mockup stage; Kepu 2026-11-02: "I think the mid section could be a bit more bulkier"): --bulk B thickens the
# mid section (body full B, chest / hips / throat 60% of it, the belly drops with the body) and spreads the legs / arms
# to stay on the outside; default 1.0 = the shipped 1.3 body.
import sys as _sys0
BULK = float(_sys0.argv[_sys0.argv.index("--bulk") + 1]) if "--bulk" in _sys0.argv else 1.0
BP = 1 + (BULK - 1) * 0.6
seg("Torso", (0.0, 0.0, 0.0))
part("Torso", "main", (3.0, 1.9 * BULK, 1.7 * BULK), (0.6, 0.5, 0.0), pitch=BODY_P, name="Torso_body")
part("Torso", "main", (1.6, 1.9 * BP, 1.6 * BP), (2.0, 1.0, 0.0), pitch=25, name="Torso_chest")
part("Torso", "main", (1.6, 1.7 * BP, 1.6 * BP), (-0.8, 0.3, 0.0), pitch=5, name="Torso_hips")
part("Torso", "belly", (2.6, 0.35, 1.4 * BULK), (0.9, -0.42 - 0.95 * (BULK - 1), 0.0), pitch=BODY_P, name="Torso_belly")
part("Torso", "belly", (0.6, 1.3 * BP, 1.1 * BP), (2.65 + 0.3 * (BP - 1), 1.0, 0.0), pitch=25, name="Torso_throat")
for i, x in enumerate((-1.1, -0.4, 0.3, 1.0, 1.7)):
    top = 0.5 + 0.95 * BULK / math.cos(math.radians(BODY_P)) + (x - 0.6) * math.tan(math.radians(BODY_P))
    part("Torso", "stripes", (0.26, 1.0 * BULK, 1.76 * BULK), (x, top - 0.42 * BULK, 0.0), pitch=BODY_P, name=f"Torso_stripe{i + 1}")

# ---------------------------------------------------------------- neck (thick, rising forward)
NECK_P = 55
seg("Neck", (2.6, 1.6, 0.0))
part("Neck", "main", (1.9, 1.25, 1.2), (3.15, 2.4, 0.0), pitch=NECK_P, name="Neck_body")
nb = along((3.15, 2.4), NECK_P - 90, 0.5)  # toward the throat side
part("Neck", "belly", (1.6, 0.35, 1.0), (nb[0], nb[1], 0.0), pitch=NECK_P, name="Neck_throat")
ns = along((3.15, 2.4), NECK_P, -0.35)
part("Neck", "stripes", (0.24, 1.3, 1.24), (ns[0], ns[1], 0.0), pitch=NECK_P, name="Neck_stripe1")

# ---------------------------------------------------------------- head
# v1.4 (mockup stage; Kepu 2026-11-02: "the pachy dome could be reworked. Looks too much like an egg and I think it should be
# a more intimidating Dino"): --head egg (default = the shipped 1.3 head) | helm | ram | crown (mockup
# docs/mockups/pachy_head_options.html). Every option keeps the part names other code uses (Head_mouth; the 10 hidden
# Head_spike* that PachyLook shows for the Battering Dome star, re-seated on the new dome) and only the existing colour roles.
import sys as _sys
HEAD = _sys.argv[_sys.argv.index("--head") + 1] if "--head" in _sys.argv else "egg"
# --spikes: the 10 Head_spike* are part of the normal look (Kepu: "crowned skull with the battering dome spikes be the default look")
SPIKES_SHOWN = "--spikes" in _sys.argv
if HEAD == "egg":
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

else:
    seg("Head", (3.7, 3.2, 0.0))
    part("Head", "main", (1.6, 1.2, 1.25), (4.2, 3.4, 0.0), name="Head_skull")
    part("Head", "mouth", (0.95, 0.08, 0.72), (5.25, 2.84, 0.0), name="Head_mouth")
    for side in (1, -1):
        s_ = "L" if side > 0 else "R"
        part("Head", "stripes", (0.1, 0.08, 0.05), (5.62, 3.3, side * 0.26), name=f"Head_nostril{s_}")

    def eyes_(x, y, brow_pitch, brow_key="dome", deep=False):
        for side in (1, -1):
            s_ = "L" if side > 0 else "R"
            part("Head", "mask", (0.7 if deep else 0.62, 0.42, 0.03), (x - 0.03, y - 0.02, side * 0.64), name=f"Head_mask{s_}")
            part("Head", "eyes", (0.22, 0.16, 0.04), (x, y, side * 0.655), name=f"Head_eye{s_}")
            part("Head", "pupil", (0.08, 0.14, 0.03), (x + 0.02, y, side * 0.675), name=f"Head_pupil{s_}")
            part("Head", brow_key, (0.62, 0.18, 0.2), (x + 0.02, y + 0.2, side * 0.58), pitch=brow_pitch, name=f"Head_brow{s_}")

    if HEAD == "helm":
        # A War Helm: a long, low helmet of bone sweeping back over the neck and forward into a brow shelf that hangs
        # over the eyes; bone cheek guards; a row of big knobs along the back rim; the snout heavy and down-turned
        part("Head", "dome", (2.1, 0.5, 1.42), (4.0, 4.2, 0.0), pitch=-6, name="Head_dome1")
        part("Head", "dome", (1.65, 0.3, 1.18), (3.95, 4.55, 0.0), pitch=-6, name="Head_dome2")
        part("Head", "dome", (0.55, 0.32, 1.48), (4.95, 3.92, 0.0), pitch=-20, name="Head_browshelf")
        for side in (1, -1):
            part("Head", "dome", (1.25, 0.55, 0.1), (4.1, 3.85, side * 0.68), pitch=-6, name=f"Head_cheekguard{'L' if side > 0 else 'R'}")
        part("Head", "main", (0.95, 0.85, 0.85), (5.3, 3.15, 0.0), pitch=-20, name="Head_snout")
        part("Head", "main", (0.42, 0.55, 0.6), (5.85, 2.92, 0.0), pitch=-20, name="Head_beak")
        eyes_(4.62, 3.55, -22, brow_key="mask", deep=True)
        rim = [(3.0, 4.2, 0.0), (3.08, 4.15, 0.42), (3.08, 4.15, -0.42), (3.25, 4.0, 0.68), (3.25, 4.0, -0.68),
               (3.7, 3.98, 0.74), (3.7, 3.98, -0.74), (5.35, 3.68, 0.0), (5.6, 3.45, 0.22), (5.6, 3.45, -0.22)]
        for i, (x, y, z) in enumerate(rim):
            part("Head", "knobs", (0.36, 0.36, 0.36), (x, y, z), name=f"Head_knob{i + 1}")
        spikes = [((2.85, 4.4, 0.0), 60, 0), ((2.95, 4.35, 0.42), 55, 25), ((2.95, 4.35, -0.42), 55, -25),
                  ((3.15, 4.15, 0.75), 40, 50), ((3.15, 4.15, -0.75), 40, -50), ((3.6, 4.1, 0.82), 20, 60),
                  ((3.6, 4.1, -0.82), 20, -60), ((5.15, 4.15, 0.45), -30, 30), ((5.15, 4.15, -0.45), -30, -30), ((5.35, 3.95, 0.0), -45, 0)]
    elif HEAD == "crown2":
        # D2 Crowned Skull, refined (Kepu 2026-11-02: "put more effort into the design. This looks really sloppy"): fewer,
        # bigger, cleaner shapes in the block style. A thick, wide bone helmet (one big block and a smaller cap) sitting on
        # the skull and overhanging it a little; a crown of ten chunky cone spikes (the Head_spike* parts) set into the
        # helmet's rim round the back and sides, radiating out and slightly up, longest at the back; bone brow ridges flush
        # with the skull over narrow slanted eyes; two small cone horns on each cheek; three knobs down the nose ridge
        HORN = ((0.55, 1.0), (0.5, 0.5))  # two blocks: a chunky base and a point
        part("Head", "main", (0.55, 1.0, 1.2), (3.45, 3.52, 0.0), name="Head_skullback")
        # the dome grows out of the skull (same footprint, a little wider), sloping down at the front into the brow and at
        # the back into the spike ring, with rounded sides and a low cap: it reads as a thick armoured skull, not a hat
        part("Head", "dome", (1.75, 0.55, 1.36), (4.15, 4.2, 0.0), name="Head_dome1")
        part("Head", "dome", (0.5, 0.42, 1.3), (4.86, 4.12, 0.0), pitch=-38, name="Head_domefront")
        part("Head", "dome", (0.62, 0.5, 1.3), (3.33, 4.08, 0.0), pitch=40, name="Head_domeback")
        part("Head", "dome", (1.2, 0.3, 1.06), (4.12, 4.57, 0.0), name="Head_dome2")
        part("Head", "dome", (0.62, 0.16, 0.62), (4.12, 4.78, 0.0), name="Head_dome3")
        part("Head", "main", (0.95, 0.8, 0.8), (5.3, 3.2, 0.0), pitch=-15, name="Head_snout")
        part("Head", "main", (0.4, 0.5, 0.56), (5.85, 3.0, 0.0), pitch=-15, name="Head_beak")
        for side in (1, -1):
            s_ = "L" if side > 0 else "R"
            part("Head", "dome", (0.62, 0.18, 0.2), (4.62, 3.88, side * 0.6), pitch=-14, name=f"Head_brow{s_}")
            part("Head", "mask", (0.5, 0.24, 0.03), (4.55, 3.6, side * 0.64), pitch=-12, name=f"Head_mask{s_}")
            part("Head", "eyes", (0.22, 0.12, 0.04), (4.58, 3.6, side * 0.655), pitch=-12, name=f"Head_eye{s_}")
            part("Head", "pupil", (0.06, 0.11, 0.03), (4.6, 3.6, side * 0.675), pitch=-12, name=f"Head_pupil{s_}")
            cone("Head", "knobs", (4.15, 3.02, side * 0.52), (-0.45, -0.4, side * 1.0), 0.45, 0.32, f"Head_cheekhorn{s_}", steps=HORN)
        for j, t in enumerate((-0.3, 0.0, 0.3)):  # knobs on the nose ridge (the snout's top face)
            x, y = 5.40 + 0.966 * t, 3.586 - 0.259 * t
            sz = 0.24 - 0.03 * j
            part("Head", "knobs", (sz, sz * 0.8, sz), (x, y + sz * 0.3, 0.0), pitch=-15, name=f"Head_nose{j + 1}")
        n_ = 0
        for k_, a in enumerate((12, 36, 60, 84, 108)):  # the 10 spikes: symmetric, round the back and sides of the dome's base
            for side in (1, -1):
                n_ += 1
                ar = math.radians(a)
                base = (4.12 - 0.92 * math.cos(ar), 4.02 + 0.06 * k_, side * 0.62 * math.sin(ar))
                d = (-math.cos(ar), 0.12 + 0.05 * k_, side * math.sin(ar) * 1.1)
                cone("Head", "knobs", base, d, 0.78 - 0.06 * k_, 0.42 - 0.025 * k_, f"Head_spike{n_}", hidden=not SPIKES_SHOWN, steps=HORN)
        spikes = []
    elif HEAD == "ram":
        # B Battering Ram: the dome thrust forward with a flat, near-vertical bone face for hitting; a ridge of horn knobs
        # along the top edge of the face; a heavy brow; a shorter, deeper snout tucked under
        part("Head", "dome", (1.75, 0.75, 1.36), (4.3, 4.15, 0.0), pitch=-22, name="Head_dome1")
        part("Head", "dome", (1.25, 0.4, 1.05), (4.05, 4.62, 0.0), pitch=-22, name="Head_dome2")
        part("Head", "dome", (0.45, 1.15, 1.38), (5.05, 3.95, 0.0), pitch=-22, name="Head_ramface")
        part("Head", "main", (0.8, 0.85, 0.85), (5.35, 3.05, 0.0), pitch=-25, name="Head_snout")
        part("Head", "main", (0.36, 0.55, 0.6), (5.78, 2.82, 0.0), pitch=-25, name="Head_beak")
        eyes_(4.5, 3.5, -24, brow_key="dome")
        front = [(5.42, 4.38, 0.0), (5.38, 4.32, 0.36), (5.38, 4.32, -0.36), (5.3, 4.18, 0.62), (5.3, 4.18, -0.62),
                 (3.35, 4.3, 0.0), (3.42, 4.2, 0.45), (3.42, 4.2, -0.45), (3.6, 3.9, 0.68), (3.6, 3.9, -0.68)]
        for i, (x, y, z) in enumerate(front):
            part("Head", "knobs", (0.34, 0.34, 0.34), (x, y, z), name=f"Head_knob{i + 1}")
        spikes = [((5.55, 4.6, 0.0), -35, 0), ((5.5, 4.55, 0.38), -35, 20), ((5.5, 4.55, -0.38), -35, -20),
                  ((5.4, 4.35, 0.68), -25, 45), ((5.4, 4.35, -0.68), -25, -45), ((3.2, 4.45, 0.0), 50, 0),
                  ((3.3, 4.35, 0.45), 45, 25), ((3.3, 4.35, -0.45), 45, -25), ((3.5, 4.0, 0.72), 35, 50), ((3.5, 4.0, -0.72), 35, -50)]
    else:
        # C Crowned Skull: a low, broad dome studded all over with knobs, ringed by a crown of short cone knobs round the
        # back and sides; dark skull-like eye sockets; knobs down the nose
        part("Head", "dome", (1.9, 0.5, 1.46), (4.0, 4.18, 0.0), name="Head_dome1")
        part("Head", "dome", (1.4, 0.36, 1.12), (4.0, 4.58, 0.0), name="Head_dome2")
        part("Head", "dome", (0.8, 0.2, 0.7), (4.0, 4.82, 0.0), name="Head_dome3")
        part("Head", "main", (0.95, 0.8, 0.8), (5.3, 3.2, 0.0), pitch=-15, name="Head_snout")
        part("Head", "main", (0.4, 0.5, 0.56), (5.85, 3.0, 0.0), pitch=-15, name="Head_beak")
        eyes_(4.5, 3.58, -18, brow_key="mask", deep=True)
        k = 0
        for x in (3.6, 4.0, 4.4):  # studs on the dome
            for z in (-0.3, 0.0, 0.3):
                k += 1
                part("Head", "knobs", (0.24, 0.18, 0.24), (x, 4.78 if x == 4.0 and z == 0.0 else 4.74, z), name=f"Head_knob{k}")
        for i, a in enumerate(range(-120, 121, 30)):  # the crown: cones round the back and sides
            ar = math.radians(a)
            x, z = 4.0 - 1.0 * math.cos(ar), 0.78 * math.sin(ar)
            k += 1
            part("Head", "knobs", (0.4, 0.34, 0.4), (x, 4.2, z), roll=-a * 0.25, name=f"Head_knob{k}")
            k += 1
            part("Head", "knobs", (0.24, 0.3, 0.24), (x - 0.08 * math.cos(ar), 4.48, z * 1.06), roll=-a * 0.3, name=f"Head_knob{k}")
        for i, x in enumerate((4.95, 5.25, 5.55)):  # nose knobs
            k += 1
            part("Head", "knobs", (0.22, 0.2, 0.22), (x, 3.72 - (x - 4.95) * 0.35, 0.0), name=f"Head_knob{k}")
        spikes = [((2.9, 4.45, 0.0), 55, 0), ((3.0, 4.4, 0.45), 50, 25), ((3.0, 4.4, -0.45), 50, -25),
                  ((3.25, 4.3, 0.75), 35, 50), ((3.25, 4.3, -0.75), 35, -50), ((3.7, 4.65, 0.4), 25, 20),
                  ((3.7, 4.65, -0.4), 25, -20), ((5.3, 3.85, 0.28), -20, 15), ((5.3, 3.85, -0.28), -20, -15), ((5.65, 3.6, 0.0), -40, 0)]
    for i, ((x, y, z), p_, r_) in enumerate(spikes):  # the 10 hidden spikes (PachyLook), re-seated on the new dome
        part("Head", "knobs", (0.22, 0.85, 0.22), (x, y, z), pitch=p_, roll=r_, name=f"Head_spike{i + 1}", hidden=not SPIKES_SHOWN)

# ---------------------------------------------------------------- jaw (small beak jaw)
seg("Jaw", (4.6, 2.9, 0.0))
part("Jaw", "main", (1.15, 0.35, 0.8), (5.15, 2.68, 0.0), pitch=-10, name="Jaw_lower")
part("Jaw", "belly", (0.9, 0.12, 0.7), (5.05, 2.5, 0.0), pitch=-10, name="Jaw_under")

# ---------------------------------------------------------------- arms (short, three claws)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * (0.78 + 0.6 * (BP - 1))
    sh, el, ha = (2.4, 0.4), (2.6, -0.2), (2.9, -0.7)
    seg(f"Arm{s}", (sh[0], sh[1], side * (0.7 + 0.6 * (BP - 1))))
    part(f"Arm{s}", "main", (0.34, 0.7, 0.32), ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, z),
         pitch=tilt_down(el[0] - sh[0], el[1] - sh[1]), name=f"Arm{s}_upper")
    part(f"Arm{s}", "main", (0.28, 0.62, 0.28), ((el[0] + ha[0]) / 2, (el[1] + ha[1]) / 2, z),
         pitch=tilt_down(ha[0] - el[0], ha[1] - el[1]), name=f"Arm{s}_fore")
    part(f"Arm{s}", "limbs", (0.32, 0.22, 0.3), (2.95, -0.85, z), name=f"Arm{s}_hand")
    for i, dz in enumerate((-0.08, 0.0, 0.08)):
        part(f"Arm{s}", "claws", (0.06, 0.26, 0.05), (3.05, -1.02, z + dz), pitch=20, name=f"Arm{s}_claw{i + 1}")

# v1.4: crown2 adds a neat row of small knobs down the spine (torso, neck, first two tail segments) to tie the body to the head
if HEAD == "crown2":
    for j, x in enumerate((-1.2, -0.6, 0.0, 0.6, 1.2, 1.8)):
        top = 0.5 + 0.95 * BULK / math.cos(math.radians(BODY_P)) + (x - 0.6) * math.tan(math.radians(BODY_P))
        sz = 0.26 + 0.04 * (j in (2, 3))
        part("Torso", "knobs", (sz, sz * 0.8, sz), (x, top + 0.04, 0.0), pitch=BODY_P, name=f"Torso_spineknob{j + 1}")
    for j, dd in enumerate((-0.15, 0.25)):
        c_ = along((3.15, 2.4), NECK_P, dd)
        nt = along(c_, NECK_P + 90, 0.62)
        part("Neck", "knobs", (0.24, 0.2, 0.24), (nt[0], nt[1], 0.0), pitch=NECK_P, name=f"Neck_spineknob{j + 1}")

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
    if HEAD == "crown2" and i < 2:  # v1.4: spine knobs on the first two tail segments
        for j, d in enumerate((0.3, 0.9)):
            sz = 0.22 - 0.03 * (i * 2 + j)
            part(name, "knobs", (sz, sz * 0.8, sz), (_root[0] + _dir[0] * d, _root[1] + _dir[1] * d + size[1] / 2 + 0.03, 0.0), pitch=-TAIL_RISE,
                 name=f"{name}_spineknob{j + 1}")
    _root = (_root[0] + _dir[0] * seglen, _root[1] + _dir[1] * seglen)

# ---------------------------------------------------------------- legs (strong: thigh, shin, metatarsus, toes)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * (0.75 + 0.45 * (BULK - 1))
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
    # v1.1 playable (plan PACHY_PLAYABLE_v1.0 Task 1)
    "DinoMaxHealth": "90",
    "MoveWalkSpeed": "30.3", "MoveRunSpeed": "56.9", "GaitAlwaysRun": "true", "TurnLimitRate": "360",
    "CameraStartZoom": "18", "IdleBob": "0.12",
    "JumpEnabled": "true", "JumpWindup": "0.12", "JumpLaunchPower": "59", "JumpBoost": "10",
    "JumpBoostMinSpeed": "2", "JumpAirHold": "true", "JumpStaminaCost": "0", "JumpCooldown": "0.5",
    "WalkStepLength": "10.3", "WalkDuty": "0.38", "WalkCrouch": "1", "WalkLift": "2.7", "WalkStrideStretch": "1.4",
    "RunStepLength": "12.6", "RunDuty": "0.3", "RunCrouch": "1.9", "RunLift": "3.6", "RunFootForward": "1.9",
    "RunStrideStretch": "1.22", "WalkSideStepReach": "1.2",
    "RunNeckDrop": "12", "WalkTailWhip": "0.3", "RunTailWhip": "0.2", "IdleTailSway": "0.4",
    "HeadbuttEnabled": "true", "HeadbuttCharges": "2", "HeadbuttWindup": "0.15", "HeadbuttSpeedMul": "1.7",
    "HeadbuttMaxTime": "1.8", "HeadbuttTurnMul": "2", "HeadbuttDamage": "20", "HeadbuttShove": "40",
    "HeadbuttShoveTime": "0.35", "HeadbuttSlowMul": "0.65", "HeadbuttSlowTime": "3", "HeadbuttRefill": "3",
    "HeadbuttSelfSlowMul": "0.65", "HeadbuttSelfSlowTime": "2.5", "HeadbuttReach": "2",
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
if "--json" in _sys.argv:  # v1.4: mockup export (the three.js viewer's format); the data file is not written
    import json as _json
    out = _sys.argv[_sys.argv.index("--json") + 1]
    hx_, hy_, hz_ = HRP_SIZE_D
    data = {"look": HEAD, "name": HEAD, "roles": {r: C[r] for r in ROLES},
            "segs": [{"n": n_, "root": cf(segments[n_]["root"]),
                      "parts": [dict({"n": p["name"], "s": [round(v, 4) for v in p["size"]], "cf": cf(p["center"], p["R"]), "c": C[p["key"]], "k": p["key"]},
                                     **({"t": 1} if p["hidden"] else {})) for p in segments[n_]["parts"]]} for n_ in order],
            "joints": [{"n": jn, "p0": p0, "p1": p1,
                        "c0": cf((0.0, 0.0, 0.0)) if p0 == "HRP" else [round(segments[p1]["root"][i] - segments[p0]["root"][i], 6) + 0.0 for i in range(3)] + [1, 0, 0, 0, 1, 0, 0, 0, 1],
                        "c1": [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]} for jn, p0, p1 in JOINTS],
            "hrp": [hz_, hy_, hx_], "hip": HIP - hy_ / 2}
    _json.dump(data, open(out, "w"))
    print("json ->", out, f"({count} parts, head {HEAD})")
    raise SystemExit
open(OUT, "w").write("\n".join(lines) + "\n")
print(f"{count} parts ({sum(1 for n in order for p in segments[n]['parts'] if p['hidden'])} hidden spikes), {len(order)} segments -> {OUT}")
print("D bounds (visible): x %.2f..%.2f (length %.2f)  y %.2f..%.2f (ground at %.2f, height %.2f)  z %.2f..%.2f (width %.2f)" % (
    lo[0], hi[0], hi[0] - lo[0], lo[1], hi[1], -HIP, hi[1] + HIP, lo[2], hi[2], hi[2] - lo[2]))
