#!/usr/bin/env python3
"""Therizino generator v1.6 (Mecha Dino Arena) — writes src/shared/Models/TherizinoModelData.luau.
v1.3 (MDA-207, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 1; Kepu 2026-11-03 jump "Spin Dive" -> "Corkscrew"): SPIN_ATTRS
on top of KIT_ATTRS (--no-spin leaves them out = 1.4's attributes): the teno landing slam off for the therizino
(TenoLeapEnabled / TenoLeapOnJump false; TenoMovesServer is not changed) and the Spin Dive numbers TheriSpin* (TheriSpinServer
1.0, TheriPose 1.3); TherizinoModelData 1.5.
v1.4 (MDA-362, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 10:48 "very strong for everything"): BAL_V16 on top of
KIT_ATTRS + SPIN_ATTRS: MoveRunSpeed 66 -> 78 (eff 42.9 -> 50.7; walk 36 unchanged), TheriHitDamage1 / 2 / 3 9 / 9 / 20 ->
11 / 11 / 24, Spin Dive JumpCharges 2 -> 3 and JumpCooldown (the per-charge refill) 6 -> 3; TherizinoModelData 1.6. --v15
rebuilds TherizinoModelData 1.5 byte-identical (the attributes are carried from the current file and KIT_ATTRS holds every
key BAL_V16 changes).
v1.5 (MDA-362; Kepu 2026-11-09 walk speeds "Yes, same proportion" as run): BAL_V17 on top of BAL_V16: MoveWalkSpeed 36 -> 42.5
(36 x 78 / 66 = 42.55, rounded to 0.5 like the data; the dilo's 1.4 walk is the same 42.5); TherizinoModelData 1.7. --v16
rebuilds 1.6 byte-identical, --v15 1.5 (KIT_ATTRS holds MoveWalkSpeed 36).
v1.6 (Kepu 2026-11-09 after v586 "Why the fuck do they turn at that radius" -> "540 (Raptor)"): BAL_V18 on top of BAL_V17: TurnLimitRate 180 -> 540 (the 180 was
inherited from TRexModelData; KIT_ATTRS never set a therizino turn rate); TherizinoModelData 1.8. --v17 rebuilds 1.7
byte-identical (the carried attributes hold 540 after 1.8, so older versions pin TurnLimitRate back to 180).
v1.2 (MDA-197, plan docs/plans/THERIZINO_KIT_v1.0.md Task 1): the data file is built with the elbow / wrist rig (--elbows is on
unless --no-elbows; ArmL/R + ForeL/R (ElbowL/R) + HandL/R (WristL/R), same blocks) and carries KIT_ATTRS (--no-kit leaves them
out); TherizinoModelData 1.3.
v1.1 (Kepu 2026-11-02: "I want to redo the therizino stance. Let's have holding its close in a more open stance like
wolverine does from the X men"): arm stances for A Reaper, picked with --stance (pose reference only; nothing copies the
character). Only the two arm segments change; the body, head, tail, legs, colours and every joint position stay as v1.0:
  close  - v1.0: arms hang in front at the body's side, scythes curl down and back
  guard  - B Wide guard: elbows bent out to the sides, forearms forward, hands out wide at hip height, the three claws
           fanned apart pointing forward
  low    - C Low flare: arms down and out wide, hands low, the claws fanned out pointing forward and down
  high   - D High flare: hands raised out wide at shoulder height, the claws fanned up and curling forward
  lowup  - C2 Low flare, palms up (Kepu's pick 2026-11-02: "Low flare but claws facing up palms up"): C's arms, hands
           low and out wide, palms turned up, the fanned claws reaching forward and curling up (TherizinoModelData 1.1,
           never published; Kepu: "I want it open handed with the claws still hanging low")
  lowopen - C3 Low flare, open hand (the pick, TherizinoModelData 1.2): C's arms, hands at hip height and out wide, the
           three claws spread apart in the front plane (24 deg) like spread fingers, hanging down and a little out, the tips
           kept off the ground (the HIP stays 5.74)
The open stances keep the v1.0 scale (K from the close build) so wide arms never shrink the body. The data file's
attributes are carried from the current TherizinoModelData (v1.0 took them from the T-Rex file, which has changed since).
v1.0 (Kepu 2026-11-02: "Let's go with the reaper look"): Classic = A Reaper (default look); without --json the generator
writes the data file (geometry + the T-Rex's attributes with every move off, Species "Therizino"). B / C stay reproducible
with --look for the mockup.
v0.2 (mockup stage): three different styles for Kepu to pick from.

Kepu 2026-11-02: "Therizino. Slasher build" -> "Make the model". Answers: size "Between raptor and T-Rex (~32)";
style "True to the animal"; feathers "Fully feathered"; roster "Day 1".
v0.2 (Kepu: "I need it to look more intimidating with its big claws for slashing" / "you're not even presenting different
options you're just changing the posture and bringing different colors. I want 3 different styles to choose from"):
three different body designs, each with its own claws, head, neck, coat and stance (v0.1's three looks were one body in
three colours / poses; they are in git at commit e005463):
  A Reaper - tall and gaunt: a ragged feather cloak, a long straight neck, a skull-like head with a hooked beak and
             deep-set eyes, the longest thin scythe claws held out wide.
  B Brute  - massive and hunched like a bear: a huge belly and a feather hump over the shoulders, a thick neck carrying a
             heavy boxy head low in front, thick arms with broad meat-hook claws that curl right back.
  C Mantis - crouched to strike: the neck coiled in an S, a wedge head pointed forward, raised display quills on the back
             and head, the arms folded up in front like a praying mantis with flat blade claws cocked over them.
Our own design of the real animal (Therizinosaurus). Kepu's reference picture was film art (UCS LLC and Amblin); nothing
here copies that creature.

Same 17-segment rig and joint names as the other dinos (rig 1.3). Dino space D = (x forward, y up, z left), origin at
the hip centre (= HumanoidRootPart centre). The whole body is scaled so its length is TARGET_LEN studs (16 at scale 1,
doubled in game like the raptor / Herrera / troodon: ~32; T-Rex ~40, raptor ~25.7).
Skin rule: every visible block uses one authored colour per group (10 groups), no hex shared between groups, none equal
to a never-paint colour (teeth E8E2D2, pupils 111111, mouth 6E342E, HRP A3A2A5). Colours are a first pass per style and
can move between styles.
Run: python3 tools/therizino_generator.py                (writes the data file: A Reaper)
     python3 tools/therizino_generator.py --look A|B|C --json OUT   (the three.js viewer's format)
"""
import json, math, os, sys

import re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Models", "TherizinoModelData.luau")
TREX = os.path.join(ROOT, "src", "shared", "Models", "TRexModelData.luau")
SMOOTH = {"eyes", "pupil", "tooth", "claws", "mouth"}
VERSION = "1.5" if "--v15" in sys.argv else "1.6"  # v1.6 balance pass 1 (MDA-362); --v15 = 1.5
if "--v15" not in sys.argv and "--v16" not in sys.argv: VERSION = "1.7"  # v1.7 walk x the run ratio (MDA-362); --v16 = 1.6
BAL_V17 = {"MoveWalkSpeed": "42.5"}  # v1.7: on top of BAL_V16
if not any(f in sys.argv for f in ("--v15", "--v16", "--v17")): VERSION = "1.8"  # v1.8 turn rate 540 (generator 1.6); --v17 = 1.7
BAL_V18 = {"TurnLimitRate": "540"}  # v1.8: on top of BAL_V17 (was the T-Rex 180)
BAL_V16 = {"MoveRunSpeed": "78", "TheriHitDamage1": "11", "TheriHitDamage2": "11", "TheriHitDamage3": "24", "JumpCharges": "3",
           "JumpCooldown": "3"}  # v1.6 (MDA-362)
# TherizinoModelData 1.6 = balance pass 1 (MDA-362); 1.5 = Spin Dive attributes (MDA-207); 1.4 = kit reach 9 / 10 (MDA-201 Play check); 1.3 = kit (MDA-197): elbow / wrist rig + kit attributes; 1.2 = stance C3
GEN_VERSION = "1.4"
GEN_VERSION = "1.5"  # v1.5 (MDA-362 walk)
GEN_VERSION = "1.6"  # v1.6 (turn rate 540)
TARGET_LEN = 16.0    # studs at scale 1 (~32 in game)
HRP_SIZE_D0 = (3.0, 2.6, 1.6)
ROLES = ["main", "back", "belly", "coat", "mane", "limbs", "claws", "eyes", "beak", "mask"]
NEVER = {"E8E2D2", "111111", "6E342E", "A3A2A5"}

LOOKS = {  # v0.2: three styles (body designs)
    "A": {"name": "Reaper", "style": "reaper", "feather": 1.1, "neck": 0,
          "pal": {"main": "3E3B38", "back": "2A2826", "belly": "8C857A", "coat": "4A4642", "mane": "6E6A64",
                  "limbs": "2F2D2B", "claws": "E2DCCB", "eyes": "F2C83A", "beak": "1E1C1B", "mask": "161514"}},
    "B": {"name": "Brute", "style": "brute", "feather": 1.3, "neck": 0,
          "pal": {"main": "7A5236", "back": "4E3424", "belly": "C9B48E", "coat": "6A4630", "mane": "3A2A20",
                  "limbs": "5A3E2C", "claws": "2C2622", "eyes": "D8A030", "beak": "46403A", "mask": "40302A"}},
    "C": {"name": "Mantis", "style": "mantis", "feather": 0.9, "neck": 0,
          "pal": {"main": "5A6046", "back": "D0702E", "belly": "B9B48E", "coat": "474D38", "mane": "7A8060",
                  "limbs": "3A3E2E", "claws": "24221E", "eyes": "F0D040", "beak": "2E2C26", "mask": "8E3A1E"}},
}
LOOK = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else "A"  # v1.0: Classic = A Reaper
STANCES = {"close": "A Close (v1.0)", "guard": "B Wide guard", "low": "C Low flare", "high": "D High flare",
           "lowup": "C2 Low flare, palms up", "lowopen": "C3 Low flare, open hand"}  # v1.1
STANCE = sys.argv[sys.argv.index("--stance") + 1] if "--stance" in sys.argv else "lowopen"  # v1.1: Kepu picked C3 (C2 lowup was the first try)
assert STANCE in STANCES, "unknown stance"
K_CLOSE = None  # v1.1: the close build's length scale, used for every stance
# v1.2 kit attributes (MDA-197; Kepu 2026-11-02: "3-hit combo", "Damage only", "80 HP", "Pounce slash", picks A Reaper
# Sweeps + J1 Diving Rake, red-team: "No hitbox on claws", landing "Front only"). Distances at scale 1 (x2 body in game).
KIT_ATTRS = {
    "DinoMaxHealth": "80", "MoveRunSpeed": "66", "MoveWalkSpeed": "36",
    "TheriAttackEnabled": "true", "TheriHitDamage1": "9", "TheriHitDamage2": "9", "TheriHitDamage3": "20",
    "TheriHitDelay1": "0.3", "TheriHitDelay2": "0.33", "TheriHitDelay3": "0.55", "TheriReach": "9", "TheriReach3": "10",  # 1.4: 7 / 8 missed a raptor the claws touch (MDA-201)
    "TheriCone": "100", "TheriMinGap": "0.33", "TheriChainWindow": "0.8", "TheriFinisherRecover": "0.9",
    "JumpEnabled": "true", "JumpCharges": "2", "JumpCooldown": "6", "JumpStaminaCost": "0", "JumpBoost": "14",
    "JumpLaunchPower": "54", "JumpWindup": "0.27",
    "TenoLeapEnabled": "true", "TenoLeapOnJump": "true", "TenoLeapDamage": "18", "TenoLeapRadius": "16", "TenoLeapStun": "0",
    "TenoLeapArc": "180", "HitboxSkipSegments": '"HandL|HandR"',
}
# v1.3 Spin Dive (MDA-207; Kepu 2026-11-03 "Corkscrew", damage "Yes, tune it in Studio"): the teno slam off, the spin numbers
SPIN_ATTRS = {
    "TenoLeapEnabled": "false", "TenoLeapOnJump": "false",
    "TheriSpinEnabled": "true", "TheriSpinDamage": "7", "TheriSpinMaxCuts": "3", "TheriSpinCutGap": "0.16",
    "TheriSpinRadius": "7", "TheriSpinTurns": "2",
}
L = LOOKS[LOOK]
F, NECK_RAISE, STYLE = L["feather"], L["neck"], L["style"]
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


# ---------------------------------------------------------------- shared builders (v0.2)
def coat_shag(segname, pts, length, width, side_z, name, d=(-0.35, -0.94)):
    for i, (x, y) in enumerate(pts):
        for side in (1, -1):
            blade(segname, "coat", (x, y, side * side_z), (d[0], d[1], side * 0.15), length * (0.85 + 0.3 * ((i * 7) % 3) / 2) * F,
                  width, 0.06, name=f"{name}{i + 1}{'L' if side > 0 else 'R'}")


def line(a, b, n):
    return [(a[0] + (b[0] - a[0]) * i / max(1, n - 1), a[1] + (b[1] - a[1]) * i / max(1, n - 1)) for i in range(n)]


def claws(segname, wr, z, side, dirs, lens, widths, thicks, spread, start=0.12):
    """Three big curved claws from the wrist: each a chain of tapering blocks following `dirs` (a curve in the side plane)."""
    for i, (dz, lm) in enumerate(((-spread, 0.88), (0.0, 1.0), (spread, 0.8))):
        splay = (1 if dz > 0 else -1 if dz < 0 else 0) * 0.14
        pt = (wr[0] + dirs[0][0] * start, wr[1] + dirs[0][1] * start, z + dz)
        for j, (dd, ln, w, t) in enumerate(zip(dirs, lens, widths, thicks)):
            pt = blade(segname, "claws", pt, (dd[0], dd[1], splay), ln * lm, w, t, name=f"{segname}_claw{i + 1}{'abcd'[j]}")


def arm(side, sh, el, wr, z, upper_w, fore_w, hand, fringe_len):
    s = "L" if side > 0 else "R"
    nm = f"Arm{s}"
    seg(nm, (sh[0], sh[1], side * abs(z) * 0.85))
    part(nm, "coat", (upper_w * 1.5, upper_w * 1.3, upper_w * 1.1), (sh[0] - 0.05, sh[1] - 0.25, z), name=f"{nm}_shoulder")
    bone(nm, "coat", (sh[0], sh[1], z), (el[0], el[1], z), upper_w, upper_w * 0.95, f"{nm}_upper")
    part(nm, "limbs", (fore_w * 1.1,) * 3, (el[0], el[1], z), name=f"{nm}_elbow")
    bone(nm, "limbs", (el[0], el[1], z), (wr[0], wr[1], z), fore_w, fore_w, f"{nm}_fore")
    part(nm, "limbs", hand, (wr[0], wr[1], z), name=f"{nm}_hand")
    n = nfe(5)
    for i in range(n):  # feather fringe trailing off the forearm
        t = i / max(1, n - 1)
        st = (el[0] + (wr[0] - el[0]) * t, el[1] + (wr[1] - el[1]) * t, z + side * fore_w * 0.3)
        dx, dy = wr[0] - el[0], wr[1] - el[1]
        ln = math.hypot(dx, dy)
        perp = (dy / ln, -dx / ln)  # the side of the forearm facing down
        if perp[1] > 0:
            perp = (-perp[0], -perp[1])
        blade(nm, "coat", st, (perp[0] - 0.3, perp[1], 0), fringe_len * (0.8 + 0.4 * t) * F, 0.24, 0.05, name=f"{nm}_fringe{i + 1}")
    return nm


def arm_open(side, sh, el, wr, root_z, upper_w, fore_w, hand, fringe_len):
    """v1.1: an arm whose shoulder, elbow and wrist each have their own width (z), so it can reach out from the body.
    sh / el / wr = (x, y, |z|); the segment root stays where v1.0 put it (same ArmL / ArmR joints)."""
    s = "L" if side > 0 else "R"
    nm = f"Arm{s}"
    P = lambda q: (q[0], q[1], side * q[2])
    a, b, c = P(sh), P(el), P(wr)
    seg(nm, (sh[0], sh[1], side * root_z))
    part(nm, "coat", (upper_w * 1.5, upper_w * 1.3, upper_w * 1.1), (a[0] - 0.05, a[1] - 0.25, a[2]), name=f"{nm}_shoulder")
    d1 = tuple(b[i] - a[i] for i in range(3))
    blade(nm, "coat", tuple(a[i] - norm(d1)[i] * 0.04 for i in range(3)), d1, math.dist(a, b) + 0.08, upper_w, upper_w * 0.95, ref=(0, 1, 0), name=f"{nm}_upper")
    part(nm, "limbs", (fore_w * 1.1,) * 3, b, name=f"{nm}_elbow")
    d2 = tuple(c[i] - b[i] for i in range(3))
    blade(nm, "limbs", tuple(b[i] - norm(d2)[i] * 0.04 for i in range(3)), d2, math.dist(b, c) + 0.08, fore_w, fore_w, ref=(0, 1, 0), name=f"{nm}_fore")
    part(nm, "limbs", hand, c, yaw=-side * math.degrees(math.atan2(d2[2], d2[0])), name=f"{nm}_hand")
    n = nfe(5)
    for i in range(n):  # feather fringe hanging under the forearm
        t = i / max(1, n - 1)
        st = (b[0] + d2[0] * t, b[1] + d2[1] * t - fore_w * 0.3, b[2] + d2[2] * t)
        blade(nm, "coat", st, (-0.3, -0.95, 0), fringe_len * (0.8 + 0.4 * t) * F, 0.24, 0.05, ref=(-d2[2], 0, d2[0]) if abs(d2[0]) + abs(d2[2]) > 0.2 else (0, 0, 1),
              name=f"{nm}_fringe{i + 1}")
    return nm, c


def claws_fan(segname, wr, side, dirs, lens, widths, thicks, fan, start=0.12, axis="y"):
    """v1.1: three claws fanned apart: each claw's curve (`dirs`, outward z positive) is turned `fan` degrees further
    about the up axis than its neighbour (inner -fan, middle 0, outer +fan), so the tips flare."""
    for i, (k, lm) in enumerate(((-1, 0.88), (0, 1.0), (1, 0.8))):
        a = math.radians(fan * k)
        def turn(d):
            x, y, z = d[0], d[1], d[2]
            if axis == "x":  # v1.1 open hand: the claws spread in the front plane (about the forward axis), like spread fingers
                return (x, y * math.cos(a) - z * math.sin(a), side * (y * math.sin(a) + z * math.cos(a)))
            return (x * math.cos(a) - z * math.sin(a), y, side * (x * math.sin(a) + z * math.cos(a)))
        d0 = norm(turn(dirs[0]))
        pt = (wr[0] + d0[0] * start, wr[1] + d0[1] * start + k * 0.04, wr[2] + d0[2] * start)
        for j, (dd, ln, w, t) in enumerate(zip(dirs, lens, widths, thicks)):
            pt = blade(segname, "claws", pt, turn(dd), ln * lm, w, t, ref=(0, 0, 1), name=f"{segname}_claw{i + 1}{'abcd'[j]}")


ARM_STANCES = {  # v1.1: (shoulder, elbow, wrist as (x, y, |z|)), claw curve (x fwd, y up, z out), claw fan degrees
    "guard": ((1.75, 1.3, 1.0), (1.55, 0.15, 2.25), (2.85, -0.15, 2.75),
              ((0.97, -0.05, 0.22), (0.95, -0.2, 0.18), (0.85, -0.45, 0.1), (0.6, -0.8, 0.0)), 20),
    "low": ((1.75, 1.3, 1.0), (1.45, -0.05, 2.2), (2.35, -0.95, 3.0),
            ((0.82, -0.3, 0.48), (0.78, -0.55, 0.3), (0.5, -0.86, 0.1), (0.15, -0.99, 0.0)), 22),
    "lowup": ((1.75, 1.3, 1.0), (1.45, -0.05, 2.2), (2.35, -0.95, 3.0),  # v1.1 pick: C's arms, palms up, claws curl up
              ((0.86, 0.12, 0.46), (0.8, 0.48, 0.3), (0.48, 0.86, 0.12), (0.08, 0.99, 0.0)), 22),
    "lowopen": ((1.75, 1.3, 1.0), (1.45, 0.2, 2.2), (2.2, -0.05, 2.85),  # v1.1 pick 2: C's arms, open hand, claws hang low
                ((0.2, -0.8, 0.56), (0.15, -0.88, 0.45), (0.1, -0.95, 0.3), (0.05, -0.99, 0.12)), 24, "x"),
    "high": ((1.75, 1.3, 1.0), (1.45, 0.95, 2.35), (2.4, 2.05, 2.7),
             ((0.32, 0.9, 0.28), (0.72, 0.66, 0.2), (0.97, 0.18, 0.1), (0.88, -0.48, 0.0)), 18),
}


def legs(knee, ankle, ball, zoff, thigh_w, shin_w, meta_w, toe_l):
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        z = side * zoff
        seg(f"Leg{s}", (0.0, 0.0, z))
        part(f"Leg{s}", "main", (thigh_w * 1.45, thigh_w * 1.4, thigh_w * 1.05), (0.1, -0.35, z), pitch=10, name=f"Leg{s}_haunch")
        bone(f"Leg{s}", "main", (0.0, 0.0, z), (knee[0], knee[1], z), thigh_w, thigh_w * 0.86, f"Leg{s}_thigh")
        for i, (x, y) in enumerate(line((-0.35, -0.3), (0.15, -1.2), nfe(4))):
            blade(f"Leg{s}", "coat", (x, y, z + side * thigh_w * 0.35), (-0.5, -0.86, 0), 0.6 * F, 0.3, 0.06, name=f"Leg{s}_pants{i + 1}")
        seg(f"Shin{s}", (knee[0], knee[1], z))
        part(f"Shin{s}", "limbs", (shin_w * 1.15,) * 3, (knee[0], knee[1], z), name=f"Shin{s}_knee")
        bone(f"Shin{s}", "limbs", (knee[0], knee[1], z), (ankle[0], ankle[1], z), shin_w, shin_w * 0.95, f"Shin{s}_shin")
        seg(f"Foot{s}", (ankle[0], ankle[1], z))
        bone(f"Foot{s}", "limbs", (ankle[0], ankle[1], z), (ball[0], ball[1], z), meta_w, meta_w, f"Foot{s}_meta")
        for i, yw in enumerate((18, 0, -18)):
            L_ = toe_l if yw == 0 else toe_l * 0.83
            dx, dz = math.cos(math.radians(yw)) * L_ / 2, -math.sin(math.radians(yw)) * L_ / 2
            part(f"Foot{s}", "limbs", (L_, 0.18, 0.22), (ball[0] + dx, ball[1] - 0.04, z + side * dz), yaw=yw * side, name=f"Foot{s}_toe{i + 1}")
            part(f"Foot{s}", "claws", (0.24, 0.16, 0.14), (ball[0] + dx * 2 + 0.07, ball[1] - 0.05, z + side * dz * 2), yaw=yw * side,
                 name=f"Foot{s}_claw{i + 1}")
        part(f"Foot{s}", "limbs", (0.32, 0.14, 0.15), (ball[0] - 0.25, ball[1] + 0.05, z + side * 0.2), yaw=-40 * side, name=f"Foot{s}_toe4")


def tail(spec, root, plume_k="back", tip=True):
    _root = root
    for i, (seglen, size, rise) in enumerate(spec):
        name = f"Tail{i + 1}"
        a = math.radians(rise)
        d = (-math.cos(a), math.sin(a))
        seg(name, (_root[0], _root[1], 0.0))
        part(name, "main", size, (_root[0] + d[0] * (size[0] / 2 - 0.05), _root[1] + d[1] * (size[0] / 2 - 0.05), 0.0), pitch=-rise)
        blade(name, plume_k, (_root[0] + d[0] * 0.45, _root[1] + d[1] * 0.45 + size[1] / 2 - 0.05, 0.0), (d[0], d[1] + 0.12, 0),
              0.45 * F, size[2] * 0.85, 0.08, ref=(0, 1, 0), name=f"{name}_plume")
        for side in (1, -1):
            blade(name, "coat", (_root[0] + d[0] * 0.5, _root[1] + d[1] * 0.5, side * size[2] / 2), (d[0] * 0.6, -0.55, side * 0.55),
                  0.45 * F, 0.3, 0.05, ref=(0, 1, 0), name=f"{name}_shag{'L' if side > 0 else 'R'}")
        if i == len(spec) - 1 and tip:
            tp = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)
            for k, ang in enumerate((-30, 0, 30)):
                r_ = math.radians(ang)
                blade(name, "coat", (tp[0] + 0.1, tp[1], 0.0), (d[0] * math.cos(r_), d[1], math.sin(r_)), 0.75 * F, 0.26, 0.06,
                      ref=(0, 1, 0), name=f"{name}_tuft{k + 1}")
        _root = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)


def eyes_and_brow(cx, cy, zz, eye, brow_len, brow_pitch, socket=True):
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        if socket:
            part("Head", "mask", (eye[0] * 1.7, eye[1] * 1.9, 0.04), (cx, cy, side * (zz - 0.005)), name=f"Head_socket{s}")
        part("Head", "eyes", (eye[0], eye[1], 0.05), (cx + 0.02, cy, side * (zz + 0.01)), name=f"Head_eye{s}")
        part("Head", "pupil", (eye[0] * 0.35, eye[1] * 0.8, 0.03), (cx + 0.04, cy, side * (zz + 0.03)), name=f"Head_pupil{s}")
        part("Head", "mask", (brow_len, 0.14, 0.1), (cx + 0.05, cy + eye[1] * 0.85, side * (zz - 0.02)), pitch=brow_pitch, name=f"Head_brow{s}")


NECK_ROOT = (0.0, 0.0)  # set per style; the look posture (NECK_RAISE) is 0 for every v0.2 style

if STYLE == "reaper":
    # ------------------------------------------------------------ A Reaper: tall and gaunt, a ragged feather cloak, the
    # longest scythe claws held out wide, a skull-like head with a hooked beak and deep-set eyes
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (1.4, 1.2, 1.1), (-0.3, 0.25, 0.0), pitch=20, name="Torso_hips")
    part("Torso", "main", (1.8, 1.6, 1.3), (0.7, 0.55, 0.0), pitch=35, name="Torso_body")
    part("Torso", "main", (1.3, 1.5, 1.2), (1.6, 1.35, 0.0), pitch=50, name="Torso_chest")
    part("Torso", "belly", (1.6, 0.18, 0.8), (0.75, -0.3, 0.0), pitch=30, name="Torso_under")
    part("Torso", "back", (2.4, 0.16, 0.7), (0.65, 1.3, 0.0), pitch=35, name="Torso_backstripe")
    coat_shag("Torso", line((-0.7, 0.0), (1.8, 1.5), nfe(10)), 1.25, 0.3, 0.68, "Torso_cloak")
    coat_shag("Torso", line((-0.4, 0.75), (1.6, 2.0), nfe(6)), 0.9, 0.3, 0.45, "Torso_cape", d=(-0.6, -0.8))
    NECK_ROOT = (2.0, 2.0)
    seg("Neck", (2.0, 2.0, 0.0))
    for i, (sz, c, p) in enumerate([((1.0, 0.62, 0.58), (2.12, 2.6), 80), ((0.95, 0.52, 0.5), (2.22, 3.5), 86), ((0.9, 0.46, 0.44), (2.3, 4.35), 80)]):
        part("Neck", "mane", sz, (c[0], c[1], 0.0), pitch=p, name=f"Neck_{i + 1}")
    for i, (x, y) in enumerate(line((1.95, 2.4), (2.15, 4.5), nfe(7))):
        blade("Neck", "mane", (x, y, 0.0), (-0.75, -0.65, 0), 0.7 * F, 0.32, 0.07, name=f"Neck_mane{i + 1}")
    seg("Head", (2.35, 4.75, 0.0))
    part("Head", "main", (0.66, 0.56, 0.5), (2.6, 4.9, 0.0), name="Head_skull")
    part("Head", "main", (0.72, 0.32, 0.36), (3.1, 4.8, 0.0), pitch=-12, name="Head_snout")
    part("Head", "beak", (0.36, 0.2, 0.3), (3.5, 4.7, 0.0), pitch=-25, name="Head_beak")
    part("Head", "beak", (0.16, 0.36, 0.26), (3.66, 4.54, 0.0), pitch=-35, name="Head_hook")
    part("Head", "mouth", (0.8, 0.05, 0.37), (3.1, 4.66, 0.0), pitch=-12, name="Head_mouth")
    eyes_and_brow(2.66, 4.95, 0.25, (0.13, 0.1), 0.52, -20)
    for i in range(max(2, nfe(3))):
        a = math.radians(20 + 16 * i)
        blade("Head", "mane", (2.3, 5.05 - 0.08 * i, 0.0), (-math.cos(a), -math.sin(a) * 0.4, 0), 0.5 * F, 0.12, 0.06, name=f"Head_crest{i + 1}")
    seg("Jaw", (2.75, 4.62, 0.0))
    for key, size, c, nm, pch in [("main", (0.72, 0.14, 0.3), (3.1, 4.6, 0.0), "Jaw_lower", -12), ("beak", (0.2, 0.14, 0.24), (3.48, 4.52, 0.0), "Jaw_beak", -20)]:
        part("Jaw", key, size, about((2.75, 4.62, 0.0), c, -10), pitch=-10 + pch, name=nm)
    for side in (1, -1):
        if STANCE == "close":  # v1.0 arms
            nm = arm(side, (1.75, 1.3), (2.15, -0.05), (3.2, -0.45), side * 1.15, 0.36, 0.26, (0.44, 0.32, 0.42), 0.6)
            claws(nm, (3.2, -0.45), side * 1.15, side, ((0.9, -0.44), (0.6, -0.8), (0.2, -0.98), (-0.25, -0.97)),
                  (1.1, 1.0, 0.9, 0.7), (0.2, 0.16, 0.11, 0.06), (0.11, 0.09, 0.07, 0.05), 0.2)
        else:  # v1.1 open stances (same joint root as v1.0: z 1.15 * 0.85)
            sh_, el_, wr_, cdirs, fan = ARM_STANCES[STANCE][:5]
            fan_axis = ARM_STANCES[STANCE][5] if len(ARM_STANCES[STANCE]) > 5 else "y"
            nm, wpt = arm_open(side, sh_, el_, wr_, 1.15 * 0.85, 0.36, 0.26, (0.44, 0.32, 0.42), 0.6)
            claws_fan(nm, wpt, side, cdirs, (1.1, 1.0, 0.9, 0.7), (0.2, 0.16, 0.11, 0.06), (0.11, 0.09, 0.07, 0.05), fan, axis=fan_axis)
    tail([(0.9, (0.95, 0.62, 0.58), -8), (0.85, (0.9, 0.48, 0.45), -10), (0.75, (0.8, 0.36, 0.34), -12),
          (0.65, (0.7, 0.27, 0.26), -10), (0.55, (0.6, 0.2, 0.2), -8)], (-0.9, 0.3))
    legs((0.55, -1.7), (-0.2, -3.1), (0.12, -3.6), 0.55, 0.6, 0.36, 0.32, 0.72)

elif STYLE == "brute":
    # ------------------------------------------------------------ B Brute: massive and hunched like a bear, a huge belly
    # and feather hump over the shoulders, a thick neck carrying a heavy boxy head low in front, thick arms with broad
    # meat-hook claws that curl right back
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (1.6, 1.5, 1.5), (-0.3, 0.15, 0.0), pitch=8, name="Torso_hips")
    part("Torso", "main", (2.4, 2.2, 2.1), (0.9, 0.05, 0.0), pitch=10, name="Torso_belly")
    part("Torso", "main", (1.6, 2.0, 2.0), (2.1, 0.6, 0.0), pitch=20, name="Torso_shoulders")
    part("Torso", "mane", (1.7, 0.9, 1.8), (1.75, 1.75, 0.0), pitch=12, name="Torso_hump")
    part("Torso", "belly", (2.0, 0.2, 1.5), (0.95, -1.05, 0.0), pitch=10, name="Torso_under")
    part("Torso", "back", (2.2, 0.18, 1.0), (0.4, 1.2, 0.0), pitch=6, name="Torso_backstripe")
    for i, (x, y) in enumerate(line((0.9, 2.15), (2.6, 2.0), nfe(6))):
        for side in (1, -1):
            blade("Torso", "mane", (x, y - 0.1, side * 0.45), (-0.8, -0.35, side * 0.45), 0.7 * F, 0.34, 0.08, ref=(0, 1, 0),
                  name=f"Torso_humpfur{i + 1}{'L' if side > 0 else 'R'}")
        blade("Torso", "mane", (x, y, 0.0), (-0.9, 0.35, 0), 0.55 * F, 0.3, 0.1, name=f"Torso_humpridge{i + 1}")
    coat_shag("Torso", line((-0.8, 0.0), (2.4, 0.4), nfe(10)), 0.95, 0.38, 1.0, "Torso_shag")
    coat_shag("Torso", line((0.2, -0.95), (1.8, -0.8), nfe(4)), 0.6, 0.5, 0.45, "Torso_fringe", d=(-0.2, -0.98))
    NECK_ROOT = (2.6, 1.4)
    seg("Neck", (2.6, 1.4, 0.0))
    part("Neck", "mane", (1.1, 1.05, 1.0), (3.0, 1.6, 0.0), pitch=20, name="Neck_base")
    part("Neck", "mane", (0.95, 0.9, 0.85), (3.65, 1.45, 0.0), pitch=-15, name="Neck_upper")
    for i, (x, y) in enumerate(line((2.8, 2.2), (3.8, 1.95), nfe(5))):
        blade("Neck", "mane", (x, y, 0.0), (-0.85, 0.35, 0), 0.5 * F, 0.3, 0.1, name=f"Neck_mane{i + 1}")
    seg("Head", (4.0, 1.3, 0.0))
    part("Head", "main", (0.95, 0.85, 0.85), (4.32, 1.38, 0.0), name="Head_cranium")
    part("Head", "main", (0.8, 0.6, 0.68), (4.95, 1.22, 0.0), pitch=-8, name="Head_snout")
    part("Head", "beak", (0.38, 0.52, 0.58), (5.4, 1.06, 0.0), pitch=-20, name="Head_beak")
    part("Head", "mask", (0.75, 0.2, 0.95), (4.48, 1.82, 0.0), pitch=-14, name="Head_browridge")
    part("Head", "mouth", (0.95, 0.06, 0.66), (4.95, 0.93, 0.0), pitch=-8, name="Head_mouth")
    for i in range(5):
        part("Head", "tooth", (0.07, 0.1, 0.67), (4.6 + i * 0.15, 0.97 - i * 0.02, 0.0), name=f"Head_tooth{i + 1}")
    eyes_and_brow(4.45, 1.55, 0.43, (0.16, 0.12), 0.55, -22)
    seg("Jaw", (4.2, 0.95, 0.0))
    for key, size, c, nm, pch in [("main", (1.15, 0.3, 0.62), (4.85, 0.85, 0.0), "Jaw_lower", -8), ("beak", (0.3, 0.3, 0.5), (5.38, 0.8, 0.0), "Jaw_beak", -18),
                                  ("mane", (0.8, 0.3, 0.55), (4.6, 0.62, 0.0), "Jaw_beard", -5)]:
        part("Jaw", key, size, about((4.2, 0.95, 0.0), c, -12), pitch=-12 + pch, name=nm)
    for side in (1, -1):
        nm = arm(side, (2.4, 0.9), (2.75, -0.6), (3.65, -0.85), side * 1.2, 0.65, 0.5, (0.62, 0.5, 0.62), 0.7)
        claws(nm, (3.65, -0.85), side * 1.2, side, ((0.8, -0.6), (0.3, -0.95), (-0.3, -0.95), (-0.75, -0.66)),
              (0.85, 0.75, 0.6, 0.42), (0.38, 0.3, 0.2, 0.1), (0.22, 0.18, 0.13, 0.07), 0.24, start=0.2)
    tail([(0.9, (1.0, 1.0, 0.95), -5), (0.85, (0.95, 0.78, 0.72), -8), (0.75, (0.85, 0.58, 0.55), -10),
          (0.65, (0.75, 0.42, 0.4), -8), (0.55, (0.65, 0.3, 0.3), -5)], (-1.0, 0.2))
    legs((0.5, -1.4), (-0.15, -2.75), (0.15, -3.2), 0.75, 0.88, 0.56, 0.48, 0.8)

else:
    # ------------------------------------------------------------ C Mantis: crouched to strike, the neck coiled in an S
    # with the wedge head pointed forward, a fan of display quills raised on the back and head, the arms folded up in
    # front like a praying mantis with flat blade claws cocked over them, the tail held up
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (1.3, 1.1, 1.1), (-0.3, 0.2, 0.0), pitch=15, name="Torso_hips")
    part("Torso", "main", (1.9, 1.5, 1.4), (0.8, 0.4, 0.0), pitch=18, name="Torso_body")
    part("Torso", "main", (1.2, 1.3, 1.2), (1.75, 0.95, 0.0), pitch=35, name="Torso_chest")
    part("Torso", "belly", (1.7, 0.18, 0.9), (0.85, -0.3, 0.0), pitch=18, name="Torso_under")
    for i, (x, y) in enumerate(line((-0.6, 0.95), (1.6, 1.75), nfe(8))):  # raised display quills
        t = i / max(1, nfe(8) - 1)
        a = math.radians(115 - 45 * t)
        blade("Torso", "back", (x, y, 0.0), (math.cos(a), math.sin(a), 0), (0.8 + 0.6 * math.sin(t * math.pi)) * F, 0.16, 0.08, name=f"Torso_quill{i + 1}")
        for side in (1, -1):
            blade("Torso", "back", (x, y - 0.1, side * 0.3), (math.cos(a) * 0.8, math.sin(a) * 0.8, side * 0.6), (0.6 + 0.4 * math.sin(t * math.pi)) * F,
                  0.14, 0.07, name=f"Torso_quill{i + 1}{'L' if side > 0 else 'R'}")
    coat_shag("Torso", line((-0.6, 0.0), (1.9, 0.9), nfe(8)), 0.8, 0.3, 0.7, "Torso_shag")
    NECK_ROOT = (2.1, 1.4)
    seg("Neck", (2.1, 1.4, 0.0))
    part("Neck", "mane", (0.8, 0.58, 0.52), (2.3, 1.95, 0.0), pitch=75, name="Neck_1")
    part("Neck", "mane", (0.75, 0.52, 0.48), (2.38, 2.65, 0.0), pitch=98, name="Neck_2")
    part("Neck", "mane", (0.75, 0.5, 0.46), (2.7, 3.25, 0.0), pitch=35, name="Neck_3")
    for i, (x, y) in enumerate(line((2.0, 2.0), (2.25, 3.35), nfe(5))):
        blade("Neck", "mane", (x, y, 0.0), (-0.9, 0.2, 0), 0.5 * F, 0.28, 0.06, name=f"Neck_mane{i + 1}")
    seg("Head", (3.05, 3.42, 0.0))
    part("Head", "main", (0.62, 0.5, 0.46), (3.3, 3.48, 0.0), name="Head_cranium")
    part("Head", "main", (0.82, 0.3, 0.32), (3.86, 3.36, 0.0), pitch=-15, name="Head_snout")
    part("Head", "beak", (0.24, 0.34, 0.26), (4.26, 3.17, 0.0), pitch=-38, name="Head_hook")
    part("Head", "mouth", (0.85, 0.05, 0.33), (3.85, 3.22, 0.0), pitch=-15, name="Head_mouth")
    eyes_and_brow(3.35, 3.55, 0.235, (0.18, 0.08), 0.45, -25, socket=False)
    for i in range(nfe(4)):  # head crest quills standing up and back
        a = math.radians(70 + 18 * i)
        blade("Head", "back", (3.15 - 0.05 * i, 3.68, 0.0), (math.cos(a), math.sin(a), 0), (0.75 - 0.08 * i) * F, 0.12, 0.06, name=f"Head_crest{i + 1}")
    seg("Jaw", (3.4, 3.28, 0.0))
    for key, size, c, nm, pch in [("main", (0.8, 0.14, 0.28), (3.85, 3.2, 0.0), "Jaw_lower", -15), ("beak", (0.18, 0.14, 0.22), (4.22, 3.08, 0.0), "Jaw_beak", -25)]:
        part("Jaw", key, size, about((3.4, 3.28, 0.0), c, -10), pitch=-10 + pch, name=nm)
    for side in (1, -1):
        nm = arm(side, (1.85, 0.9), (1.8, -0.45), (2.75, 0.55), side * 0.95, 0.38, 0.3, (0.42, 0.36, 0.4), 0.55)
        claws(nm, (2.75, 0.55), side * 0.95, side, ((0.35, 0.94), (0.85, 0.53), (0.98, -0.2), (0.6, -0.8)),
              (0.9, 0.85, 0.75, 0.5), (0.26, 0.22, 0.15, 0.07), (0.07, 0.06, 0.05, 0.04), 0.16)
    tail([(0.9, (0.95, 0.66, 0.62), 12), (0.85, (0.9, 0.5, 0.47), 10), (0.8, (0.85, 0.38, 0.36), 8),
          (0.7, (0.75, 0.28, 0.27), 6), (0.6, (0.65, 0.2, 0.2), 4)], (-0.85, 0.35))
    legs((0.75, -1.35), (-0.25, -2.6), (0.15, -3.2), 0.55, 0.62, 0.38, 0.34, 0.75)

JOINTS = [("RootJoint", "HRP", "Torso"), ("Neck", "Torso", "Neck"), ("Head", "Neck", "Head"), ("Jaw", "Head", "Jaw"),
          ("ArmL", "Torso", "ArmL"), ("ArmR", "Torso", "ArmR"), ("Tail1", "Torso", "Tail1"), ("Tail2", "Tail1", "Tail2"),
          ("Tail3", "Tail2", "Tail3"), ("Tail4", "Tail3", "Tail4"), ("Tail5", "Tail4", "Tail5"),
          ("LegL", "Torso", "LegL"), ("LegR", "Torso", "LegR"), ("KneeL", "LegL", "ShinL"), ("KneeR", "LegR", "ShinR"),
          ("AnkleL", "ShinL", "FootL"), ("AnkleR", "ShinR", "FootR")]

# ---------------------------------------------------------------- v1.1 --elbows (kit mockup): elbow + wrist joints
# Splits each arm segment into ArmL (shoulder + upper arm), ForeL (elbow + forearm + feather fringe, root at the elbow,
# joint ElbowL) and HandL (hand + claws, root at the wrist, joint WristL); same for R. Same blocks, same rest pose: only
# the joints are new, so the claws can bend at the elbow and flick at the wrist. Off unless --elbows is passed (the data
# file stays the 17-segment rig until a kit plan adopts it).
ELBOWS = ("--elbows" in sys.argv) or ("--json" not in sys.argv and "--no-elbows" not in sys.argv)  # v1.2: on for the data file
if ELBOWS:
    for s_ in ("L", "R"):
        arm_ = segments[f"Arm{s_}"]
        elbow_ = next(p for p in arm_["parts"] if p["name"] == f"Arm{s_}_elbow")
        hand_ = next(p for p in arm_["parts"] if p["name"] == f"Arm{s_}_hand")
        fore_parts = [p for p in arm_["parts"] if p["name"] in (f"Arm{s_}_elbow", f"Arm{s_}_fore") or "_fringe" in p["name"]]
        hand_parts = [p for p in arm_["parts"] if p["name"] == f"Arm{s_}_hand" or "_claw" in p["name"]]
        arm_["parts"] = [p for p in arm_["parts"] if p not in fore_parts and p not in hand_parts]
        seg(f"Fore{s_}", elbow_["center"])
        segments[f"Fore{s_}"]["parts"] = fore_parts
        seg(f"Hand{s_}", hand_["center"])
        segments[f"Hand{s_}"]["parts"] = hand_parts
        JOINTS.append((f"Elbow{s_}", f"Arm{s_}", f"Fore{s_}"))
        JOINTS.append((f"Wrist{s_}", f"Fore{s_}", f"Hand{s_}"))


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
if STANCE != "close":  # v1.1: keep the v1.0 body scale (the close build's K), whatever the arms reach
    K = float(os.popen(f'{sys.executable} "{os.path.abspath(__file__)}" --look {LOOK} --stance close --k-only').read().strip())
if "--k-only" in sys.argv:
    print(repr(K))
    sys.exit(0)
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
    data = {"look": LOOK, "name": L["name"], "version": VERSION, "stance": STANCE, "stanceName": STANCES[STANCE], "roles": {r: C[r] for r in ROLES},
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
    assert LOOK == "A", "the data file is the picked look: A Reaper"
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
    trex = open(OUT).read() if os.path.exists(OUT) else open(TREX).read()  # v1.1: carry the current therizino attributes
    block = trex[trex.index("attributes = {"):]
    block = block[:block.index("\n\t},")]
    attrs = {m.group(1): m.group(2) for m in re.finditer(r'^\t\t(\w+) = (.+?),$', block, re.M)}
    attrs.update({"Species": '"Therizino"', "StyleVersion": '"1.0"', "TherizinoModelVersion": f'"{VERSION}"', "DisplayName": '"Therizino"',
                  "RigHipHeight": f"{HIP:.4g}", "BiteEnabled": "false", "PounceEnabled": "false", "RamEnabled": "false",
                  "RoarEnabled": "false", "JumpEnabled": "false", "CreepEnabled": "false"})
    attrs.pop("StarterCharacterVersion", None)
    if "--no-kit" not in sys.argv:  # v1.2 (MDA-197, plan docs/plans/THERIZINO_KIT_v1.0.md Task 1): the kit attributes
        attrs.update(KIT_ATTRS)
        if "--no-spin" not in sys.argv:  # v1.3 (MDA-207)
            attrs.update(SPIN_ATTRS)
        if VERSION in ("1.6", "1.7", "1.8"):  # v1.4 generator (MDA-362)
            attrs.update(BAL_V16)
        if VERSION in ("1.7", "1.8"):  # v1.5 generator
            attrs.update(BAL_V17)
        if VERSION == "1.8":  # v1.6 generator
            attrs.update(BAL_V18)
        elif "TurnLimitRate" in attrs:  # v1.6 generator: versions before 1.8 keep the inherited 180
            attrs["TurnLimitRate"] = "180"
    lines = [f"-- TherizinoModelData v{VERSION} (Mecha Dino Arena) — block-style feathered Therizinosaurus ({LOOK} {L['name']}: tall and gaunt, feather cloak, scythe claws), rig 1.3 joint names, skin-ready colour groups.",
             "-- Generated by tools/therizino_generator.py (do not edit by hand; change the generator and re-run). Mockup docs/mockups/therizino_model_options.html (v0.2, Kepu picked A Reaper).",
             f"-- Arm stance: {STANCES[STANCE]} (Kepu 2026-11-02 \"open handed with the claws still hanging low like the iconic wolverine stance\"; mockup docs/mockups/therizino_stance_options.html v0.3). v1.0 = close, v1.1 = lowup.",
             f"-- Scale: {hi[0] - lo[0]:.2f} studs long, hip {HIP:.4g} studs; doubled in game like the raptor / Herrera / troodon (~{2 * (hi[0] - lo[0]):.0f}; raptor ~25.7, T-Rex ~40).",
             f"-- Colour groups (Classic = {L['name']}): " + ", ".join(f"{r} {C[r]}" for r in ROLES) + "; never painted: teeth E8E2D2, pupil 111111, mouth 6E342E.",
             "-- All CFrames are relative to the HumanoidRootPart; sizes in studs; colors hex RGB. Rebuild with DinoModelBuilder.build(require(TherizinoModelData)).",
             ("-- v1.3 kit (MDA-197, plan docs/plans/THERIZINO_KIT_v1.0.md): elbow / wrist rig (ForeL/R + HandL/R, joints ElbowL/R + WristL/R, same blocks) and the kit attributes (3-hit claw combo, Diving Rake on JUMP, 80 HP); playable through SpeciesServer 1.6.\n-- v1.4: TheriReach 9 / TheriReach3 10 (1.3's 7 / 8 missed a raptor the claws touch; MDA-201 Studio check)." + ("\n-- v1.5 (MDA-207): Spin Dive (Corkscrew) on JUMP: the teno landing slam off (TenoLeapEnabled / TenoLeapOnJump false), TheriSpin* numbers for TheriSpinServer 1.0." if "--no-spin" not in sys.argv else "") + ("\n-- v1.6 balance pass 1 (MDA-362, plan docs/plans/BALANCE_PASS_v1.0.md): run 78 (was 66), cuts 11 / 11 / 24 (were 9 / 9 / 20), Spin Dive 3 charges refilling 3 s each (were 2 / 6 s)." if VERSION in ("1.6", "1.7", "1.8") else "") + ("\n-- v1.7 (MDA-362, Kepu 2026-11-09 walk \"same proportion\"): MoveWalkSpeed 42.5 (was 36)." if VERSION in ("1.7", "1.8") else "") + ("\n-- v1.8 (Kepu 2026-11-09 after v586 \"Why the fuck do they turn at that radius\" -> \"540 (Raptor)\"): TurnLimitRate 540 (was 180, copied from the T-Rex; full-run turn circle ~8 studs radius, was ~25)." if VERSION == "1.8" else "") if "--no-kit" not in sys.argv else "-- Not playable yet: no SpeciesServer entry, no kit (every move off). Those come with the therizino kit plan."),
             "return {", f'\tversion = "{VERSION}", species = "Therizino", style = "1.0", rig = "1.3",'] + body + ["\tattributes = {"] + [f"\t\t{k} = {attrs[k]}," for k in sorted(attrs)] + ["\t},", "}"]
    open(OUT, "w").write("\n".join(lines) + "\n")
    print("data ->", OUT, f"({len(attrs)} attributes)")
n = sum(len(segments[s_]["parts"]) for s_ in order)
print(f"look {LOOK} ({L['name']}): {n} parts, {len(order)} segments, scale {K:.3f}, HIP {HIP:.3f}")
print("length %.2f, height %.2f, width %.2f" % (hi[0] - lo[0], hi[1] + HIP, hi[2] - lo[2]))
