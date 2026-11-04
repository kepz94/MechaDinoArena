#!/usr/bin/env python3
"""Dilo generator v1.0 (Mecha Dino Arena) — writes src/shared/Models/DiloModelData.luau.
v1.0 (Kepu 2026-11-02: "I like the bruiser face."): Classic = E (D's thick Cobra Hood body, red / yellow split hood, Bruiser
face; default look); without --json the generator writes the data file (geometry + the T-Rex's attributes with every
move off, Species "Dilo"). The other looks stay reproducible with --look.
v0.1-0.8 (mockup stage): styles for Kepu to pick from.
v0.2 (Kepu 2026-11-02: "The frill splits in the middle"): every frill is two halves, left and right, with a gap down the
middle (--whole = the v0.1 one-piece frill). Colours and patterns stay our own.
v0.3: look D = A Cobra Hood with a red frill and yellow markings (Kepu: "the quill stalker frill colors on the cobra hood").
v0.4: D's hood is red / yellow / red rings out from the neck, like the quill bands (Kepu: "the frill itself to be red and yellow").
v0.6: D is thicker: bulk 1.35 on the body, neck, tail, legs and arms, the head x1.18 (Kepu: "the Dilo is too thin"); A unchanged.
v0.7: D thicker still: bulk 1.7, head x1.35 (Kepu: "Maybe even more thicker just all around").
v0.8: three face options on the D body: E Bruiser, F Croc, G Viper (Kepu: "the face looks too skinny and narrow").

Kepu 2026-11-02: "Next is the dilo" (two reference pictures of the film-style frilled dilophosaurus). Answers: role
"Ranged spitter"; size "Raptor size (~26)"; frill "Crests + a frill" (the real animal had twin head crests and no frill;
the frill here is our own design, not a copy of the pictures); roster "Day 1".
Three different styles, each its own body, posture, crests and frill:
  A Cobra Hood   - slender, a long S-neck held high, the frill a solid rounded hood with two eye-spots and a dark rim, tall
                   thin arched twin crests, a long whip tail.
  B Sunburst     - stocky and upright with a bigger head, the frill a full round sail with spines past the edge and
                   eye-spots, a tall notched double-crest mohawk, a thick tail.
  C Quill Stalker - low and horizontal, the neck stretched forward, the frill a ruff of long banded quills, short
                   swept-back crests like horns, a long level tail.
Every style has a throat sac (the spitter's venom pouch) on the jaw. The frill is built twice: open ("_frill" parts) and
folded back along the neck ("_fold" parts); the mockup toggles them. How the game opens it comes with the kit plan.
Same 17-segment rig and joint names as the other dinos (rig 1.3). Dino space D = (x forward, y up, z left), origin at
the hip centre. Scaled so its length is TARGET_LEN (13 studs at scale 1, doubled in game: ~26 like the raptor).
Skin rule: 10 colour groups, no shared hex, no never-paint colour (teeth E8E2D2, pupil 111111, mouth 6E342E, HRP A3A2A5).
Colours are a first pass per style and can move between styles.
Run: python3 tools/dilo_generator.py                (writes the data file: E, Bruiser face)
     python3 tools/dilo_generator.py --look A|B|C|D|E|F|G --json OUT   (the three.js viewer's format)
The data file (DiloModelData.luau) comes after Kepu picks.
"""
import json, math, os, sys

import re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Models", "DiloModelData.luau")
TREX = os.path.join(ROOT, "src", "shared", "Models", "TRexModelData.luau")
SMOOTH = {"eyes", "pupil", "tooth", "claws", "mouth"}
VERSION = "1.0"
VERSION = "1.1"  # v1.1 kit attributes (MDA-221, plan docs/plans/DILO_KIT_v1.0.md Task 1)
# v1.1 (Kepu 2026-11-03: picks "C and J1", "70 HP", "Weaker dart", leap "No refill just like the Raptor"); --no-kit = 1.0
VERSION = "1.2"  # v1.2 bite gap 1.0 s (MDA-229; Kepu 2026-11-04 "Let's go with your suggestions": 0.35 s let the bite land
# ~29 damage / s; 1.0 s = 10 / s)
KIT_ATTRS = {
    "DinoMaxHealth": "70", "MoveRunSpeed": "66", "MoveWalkSpeed": "36",
    "DiloAttackEnabled": "true", "DiloBiteDamage": "10", "DiloBiteDelay": "0.18", "DiloBiteReach": "5", "DiloBiteCone": "70",
    "DiloHoldTime": "0.4", "DiloDartDamage": "6", "DiloVenomDps": "2", "DiloVenomTime": "3", "DiloDartRange": "30",
    "DiloDartSpeed": "60", "DiloDartCooldown": "1.5", "DiloAssistAngle": "30", "DiloAssistMin": "0", "DiloAssistMax": "30",
    "DiloMinGap": "1.0",  # v1.2 (was 0.35)
    "JumpEnabled": "true", "JumpCharges": "0", "JumpCooldown": "0.5", "JumpStaminaCost": "0", "JumpBoost": "14",
    "JumpLaunchPower": "54", "JumpWindup": "0.27", "TenoLeapEnabled": "false", "TenoLeapOnJump": "false",
}
TARGET_LEN = 13.0    # studs at scale 1 (~26 in game, the raptor's size)
HRP_SIZE_D0 = (3.0, 2.0, 1.1)
ROLES = ["main", "stripes", "belly", "frill", "frillmark", "crest", "limbs", "claws", "eyes", "mask"]
NEVER = {"E8E2D2", "111111", "6E342E", "A3A2A5"}
LOOKS = {
    "A": {"name": "Cobra Hood", "style": "cobra", "fr": 1.0, "neck": 0,
          "pal": {"main": "6E7A3A", "stripes": "3A3F22", "belly": "D8D0A0", "frill": "E2C23A", "frillmark": "2A2A26",
                  "crest": "C24A2A", "limbs": "5A6430", "claws": "2C2822", "eyes": "F0E04A", "mask": "1C1C1A"}},
    "B": {"name": "Sunburst", "style": "sail", "fr": 1.0, "neck": 0,
          "pal": {"main": "6A5240", "stripes": "3E2E24", "belly": "D6C2A0", "frill": "2E8C9A", "frillmark": "E8E2A8",
                  "crest": "E06A2A", "limbs": "54402F", "claws": "2A221C", "eyes": "F2B030", "mask": "16222A"}},
    "C": {"name": "Quill Stalker", "style": "quills", "fr": 1.0, "neck": 0,
          "pal": {"main": "2F4A36", "stripes": "1C2A20", "belly": "A8B48E", "frill": "C8362E", "frillmark": "EDE6D6",
                  "crest": "8A9A6A", "limbs": "26382A", "claws": "1A1A18", "eyes": "E8C23A", "mask": "0E1410"}},
    # v0.3 (Kepu 2026-11-02: "Let's do the quill stalker frill colors on the cobra hood. Red and yellow"): A's body, hood
    # and colours with C's red on the frill and yellow markings (spots); everything else is A
    # v0.4 (Kepu: "I want the frill itself to be red and yellow"): the hood in red / yellow / red rings (no spots)
    # v0.6 (Kepu: "I feel like the Dilo is too thin in these mockups"): D bulk 1.35 (body, neck, tail, legs, arms; head x1.18)
    # v0.7 (Kepu: "Maybe even more thicker just all around"): D bulk 1.7 (head x1.35)
    "D": {"name": "Cobra Hood Red", "style": "cobra", "fr": 1.0, "neck": 0, "hood": "hoodband", "bulk": 1.7,
          "pal": {"main": "6E7A3A", "stripes": "3A3F22", "belly": "D8D0A0", "frill": "C8362E", "frillmark": "E2C23A",
                  "crest": "C24A2A", "limbs": "5A6430", "claws": "2C2822", "eyes": "F0E04A", "mask": "1C1C1A"}},
    # v0.8 (Kepu: "Redesign the face of the dilo as well with different options. The body build is fine I just think the
    # face looks too skinny and narrow"): D's body and colours with three wider heads
    "E": {"name": "Bruiser Face", "style": "cobra", "fr": 1.0, "neck": 0, "hood": "hoodband", "bulk": 1.7, "face": "bruiser",
          "pal": {"main": "6E7A3A", "stripes": "3A3F22", "belly": "D8D0A0", "frill": "C8362E", "frillmark": "E2C23A",
                  "crest": "C24A2A", "limbs": "5A6430", "claws": "2C2822", "eyes": "F0E04A", "mask": "1C1C1A"}},
    "F": {"name": "Croc Face", "style": "cobra", "fr": 1.0, "neck": 0, "hood": "hoodband", "bulk": 1.7, "face": "croc",
          "pal": {"main": "6E7A3A", "stripes": "3A3F22", "belly": "D8D0A0", "frill": "C8362E", "frillmark": "E2C23A",
                  "crest": "C24A2A", "limbs": "5A6430", "claws": "2C2822", "eyes": "F0E04A", "mask": "1C1C1A"}},
    "G": {"name": "Viper Face", "style": "cobra", "fr": 1.0, "neck": 0, "hood": "hoodband", "bulk": 1.7, "face": "viper",
          "pal": {"main": "6E7A3A", "stripes": "3A3F22", "belly": "D8D0A0", "frill": "C8362E", "frillmark": "E2C23A",
                  "crest": "C24A2A", "limbs": "5A6430", "claws": "2C2822", "eyes": "F0E04A", "mask": "1C1C1A"}},
}
LOOK = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else "E"  # v1.0: Classic = E (Bruiser face)
L = LOOKS[LOOK]
FR, NECK_RAISE, STYLE = L["fr"], L["neck"], L["style"]
F = 1.0
SPLIT = "--whole" not in sys.argv  # v0.2: the frill splits in the middle (--whole = v0.1)
SPLIT_GAP = 16  # degrees each side of the middle line left open
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



# ---------------------------------------------------------------- shared builders
def line(a, b, n):
    return [tuple(a[k] + (b[k] - a[k]) * i / max(1, n - 1) for k in range(len(a))) for i in range(n)]


def frill(segname, c, n, kind, R, a0, a1, count, fold=False, side=""):
    """A frill around the neck at centre c, in the plane facing along n (the neck direction, toward the head).
    kind: hood (solid fan, eye-spots), sail (round fan with spines past the edge), quills (separate banded quills).
    fold=True builds the folded-down version (laid back along the neck) for the frill toggle."""
    n = norm(n)
    u = norm(cross((0, 0, 1), n))  # in-plane "up"
    if u[1] < 0:
        u = tuple(-v for v in u)
    zv = (0.0, 0.0, 1.0)
    tag = ("fold" if fold else "frill") + side
    step = (a1 - a0) / max(1, count - 1)
    for i in range(count):
        th = math.radians(a0 + step * i)
        r = tuple(math.cos(th) * u[k] + math.sin(th) * zv[k] for k in range(3))
        if fold:  # laid back along the neck: mostly backward (-n), a little outward
            d = tuple(-n[k] * 1.0 + r[k] * 0.35 for k in range(3))
            L = R * (0.55 if kind != "quills" else 0.7)
            blade(segname, "frill" if kind != "quills" else ("frillmark" if i % 2 else "frill"), tuple(c[k] + r[k] * 0.32 for k in range(3)), d,
                  L, 0.16, 0.06, ref=r, name=f"{segname}_{tag}{i + 1}")
            continue
        start = tuple(c[k] + r[k] * 0.3 for k in range(3))
        if kind == "hoodband":  # v0.4: the hood in rings out from the neck, red / yellow / red like the quill bands, dark rim
            d = tuple(r[k] + n[k] * 0.12 for k in range(3))
            wd = 2 * R * math.sin(math.radians(step) / 2) * 1.25 + 0.06
            for j, (t0, t1, key) in enumerate(((0.0, 0.42, "frill"), (0.42, 0.72, "frillmark"), (0.72, 0.92, "frill"))):
                blade(segname, key, tuple(start[k] + r[k] * R * t0 for k in range(3)), d, R * (t1 - t0) + 0.02, wd * (0.55 + 0.45 * t1), 0.06,
                      ref=n, name=f"{segname}_{tag}{i + 1}{'abc'[j]}")
            blade(segname, "mask", tuple(start[k] + r[k] * R * 0.9 for k in range(3)), d, R * 0.14, wd * 0.98, 0.07, ref=n,
                  name=f"{segname}_{tag}rim{i + 1}")
        elif kind == "hood":
            d = tuple(r[k] + n[k] * 0.12 for k in range(3))
            blade(segname, "frill", start, d, R, 2 * R * math.sin(math.radians(step) / 2) * 1.25 + 0.06, 0.06, ref=n, name=f"{segname}_{tag}{i + 1}")
            if i % 2 == 0:
                blade(segname, "frillmark", tuple(start[k] + r[k] * R * 0.5 for k in range(3)), d, R * 0.3, 0.18, 0.07, ref=n,
                      name=f"{segname}_{tag}spot{i + 1}")
            blade(segname, "mask", tuple(start[k] + r[k] * R * 0.9 for k in range(3)), d, R * 0.14, 2 * R * math.sin(math.radians(step) / 2) * 1.2,
                  0.07, ref=n, name=f"{segname}_{tag}rim{i + 1}")
        elif kind == "sail":
            d = tuple(r[k] - n[k] * 0.08 for k in range(3))
            blade(segname, "frill", start, d, R, 2 * R * math.sin(math.radians(step) / 2) * 1.2 + 0.05, 0.05, ref=n, name=f"{segname}_{tag}{i + 1}")
            blade(segname, "frillmark", start, d, R * 1.32, 0.08, 0.09, ref=n, name=f"{segname}_{tag}spine{i + 1}")
            if i % 3 == 1:
                blade(segname, "mask", tuple(start[k] + r[k] * R * 0.55 for k in range(3)), d, R * 0.22, 0.24, 0.07, ref=n,
                      name=f"{segname}_{tag}eye{i + 1}")
        else:  # quills, banded, leaning back a little
            d = tuple(r[k] - n[k] * 0.35 for k in range(3))
            p = blade(segname, "frill", start, d, R * 0.55, 0.12, 0.12, ref=n, name=f"{segname}_{tag}{i + 1}a")
            p = blade(segname, "frillmark", p, d, R * 0.3, 0.09, 0.09, ref=n, name=f"{segname}_{tag}{i + 1}b")
            blade(segname, "frill", p, d, R * 0.25, 0.05, 0.05, ref=n, name=f"{segname}_{tag}{i + 1}c")


def split_frill(segname, c, n, kind, R, a1, count, fold=False, gap=SPLIT_GAP):
    """v0.2 (Kepu 2026-11-02: "The frill splits in the middle"): the frill in two halves, left and right, with a gap down
    the middle at the top (and the bottom where the fan reaches round); each half keeps the style's look."""
    half = max(2, (count + 1) // 2)
    frill(segname, c, n, kind, R, gap, a1, half, fold, side="L")
    frill(segname, c, n, kind, R, -a1, -gap, half, fold, side="R")


def crests(cx0, cx1, y0, h, z, lean, thick, name="Head_crest"):
    """Twin crests on the snout: each a row of blocks rising to a peak (an arch), set at +-z."""
    pts = 6
    for side in (1, -1):
        for i in range(pts):
            t = i / (pts - 1)
            x = cx0 + (cx1 - cx0) * t
            hh = h * math.sin(math.pi * (0.15 + 0.8 * t)) * (0.65 + 0.35 * (1 - t))
            part("Head", "crest", ((cx1 - cx0) / pts * 1.15, hh, thick), (x, y0 + hh / 2, side * z), pitch=lean,
                 name=f"{name}{i + 1}{'L' if side > 0 else 'R'}")


def arms(sh, el, wr, z, w):
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        zz = side * z
        seg(f"Arm{s}", (sh[0], sh[1], zz))
        bone(f"Arm{s}", "main", (sh[0], sh[1], zz), (el[0], el[1], zz), w, w, f"Arm{s}_upper")
        bone(f"Arm{s}", "limbs", (el[0], el[1], zz), (wr[0], wr[1], zz), w * 0.8, w * 0.8, f"Arm{s}_fore")
        part(f"Arm{s}", "limbs", (0.22, 0.14, 0.16), (wr[0] + 0.08, wr[1] - 0.02, zz), name=f"Arm{s}_hand")
        for i, dz in enumerate((-0.05, 0.0, 0.05)):
            blade(f"Arm{s}", "claws", (wr[0] + 0.18, wr[1] - 0.04, zz + dz), (0.45, -0.89, 0), 0.2, 0.05, 0.05, name=f"Arm{s}_claw{i + 1}")


def legs(knee, ankle, ball, z, thigh, shin):
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        zz = side * z
        seg(f"Leg{s}", (0.0, 0.0, zz))
        part(f"Leg{s}", "main", (thigh * 1.6, thigh * 1.7, thigh * 1.15), (-0.15, -0.2, zz), pitch=10, name=f"Leg{s}_haunch")
        bone(f"Leg{s}", "main", (0.0, 0.0, zz), (knee[0], knee[1], zz), thigh, thigh * 0.9, f"Leg{s}_thigh")
        seg(f"Shin{s}", (knee[0], knee[1], zz))
        part(f"Shin{s}", "limbs", (shin * 1.25,) * 3, (knee[0], knee[1], zz), name=f"Shin{s}_knee")
        bone(f"Shin{s}", "limbs", (knee[0], knee[1], zz), (ankle[0], ankle[1], zz), shin, shin * 0.95, f"Shin{s}_shin")
        seg(f"Foot{s}", (ankle[0], ankle[1], zz))
        bone(f"Foot{s}", "limbs", (ankle[0], ankle[1], zz), (ball[0], ball[1], zz), shin * 0.85, shin * 0.85, f"Foot{s}_meta")
        for i, yw in enumerate((20, 0, -20)):
            L_ = 0.7 if yw == 0 else 0.55
            dx, dz = math.cos(math.radians(yw)) * L_ / 2, -math.sin(math.radians(yw)) * L_ / 2
            part(f"Foot{s}", "limbs", (L_, 0.13, 0.15), (ball[0] + dx, ball[1] - 0.06, zz + side * dz), yaw=yw * side, name=f"Foot{s}_toe{i + 1}")
            part(f"Foot{s}", "claws", (0.17, 0.11, 0.1), (ball[0] + dx * 2 + 0.05, ball[1] - 0.07, zz + side * dz * 2), yaw=yw * side,
                 name=f"Foot{s}_claw{i + 1}")


def tail(spec, root, stripes=True):
    _root = root
    for i, (seglen, size, rise) in enumerate(spec):
        name = f"Tail{i + 1}"
        a = math.radians(rise)
        d = (-math.cos(a), math.sin(a))
        seg(name, (_root[0], _root[1], 0.0))
        part(name, "main", size, (_root[0] + d[0] * (size[0] / 2 - 0.05), _root[1] + d[1] * (size[0] / 2 - 0.05), 0.0), pitch=-rise)
        if stripes:
            part(name, "stripes", (0.16, size[1] + 0.04, size[2] + 0.04), (_root[0] + d[0] * 0.6, _root[1] + d[1] * 0.6, 0.0), pitch=-rise, name=f"{name}_band")
        _root = (_root[0] + d[0] * seglen, _root[1] + d[1] * seglen)


def head(base, snout_len, h, w, jaw_open, eye):
    """Long theropod head with the dilo's notch (a kink in the upper jaw behind the snout tip) and a throat sac."""
    hx, hy = base
    seg("Head", (hx, hy, 0.0))
    part("Head", "main", (0.7, h, w), (hx + 0.3, hy + 0.08, 0.0), name="Head_cranium")
    part("Head", "main", (snout_len, h * 0.62, w * 0.72), (hx + 0.62 + snout_len / 2, hy - 0.02, 0.0), pitch=-4, name="Head_snout")
    part("Head", "main", (0.32, h * 0.5, w * 0.62), (hx + 0.7 + snout_len + 0.1, hy - 0.12, 0.0), pitch=-14, name="Head_tip")
    part("Head", "mask", (0.08, h * 0.22, w * 0.74), (hx + 0.62 + snout_len * 0.78, hy - 0.2, 0.0), name="Head_notch")
    part("Head", "mouth", (snout_len + 0.3, 0.05, w * 0.66), (hx + 0.55 + snout_len / 2, hy - h * 0.33, 0.0), pitch=-4, name="Head_mouth")
    for i in range(7):
        x = hx + 0.45 + i * snout_len / 6.5
        part("Head", "tooth", (0.06, 0.12, w * 0.68), (x, hy - h * 0.3 - 0.02 + (x - hx) * -0.06, 0.0), name=f"Head_tooth{i + 1}")
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        part("Head", "mask", (eye * 1.6, eye * 1.4, 0.04), (hx + 0.38, hy + 0.15, side * (w / 2)), name=f"Head_eyering{s}")
        part("Head", "eyes", (eye, eye * 0.9, 0.05), (hx + 0.4, hy + 0.15, side * (w / 2 + 0.01)), name=f"Head_eye{s}")
        part("Head", "pupil", (eye * 0.3, eye * 0.8, 0.03), (hx + 0.42, hy + 0.15, side * (w / 2 + 0.03)), name=f"Head_pupil{s}")
        part("Head", "stripes", (snout_len * 0.8, 0.06, 0.03), (hx + 0.62 + snout_len * 0.45, hy + 0.06, side * (w * 0.37)), pitch=-4, name=f"Head_stripe{s}")
    jr = (hx + 0.15, hy - h * 0.32, 0.0)
    seg("Jaw", jr)
    for key, size, c, nm in [("main", (snout_len + 0.5, h * 0.24, w * 0.66), (hx + 0.55 + snout_len / 2, hy - h * 0.45, 0.0), "Jaw_lower"),
                             ("frillmark", (0.6, h * 0.35, w * 0.5), (hx + 0.35, hy - h * 0.65, 0.0), "Jaw_sac")] + \
            [("tooth", (0.06, 0.1, w * 0.64), (hx + 0.55 + i * snout_len / 6, hy - h * 0.3, 0.0), f"Jaw_tooth{i + 1}") for i in range(6)]:
        part("Jaw", key, size, about(jr, c, -jaw_open), pitch=-jaw_open, name=nm)


def face(kind, base, S, jaw_open=8):
    """v0.8 (Kepu 2026-11-02: "Redesign the face of the dilo as well with different options ... the face looks too skinny
    and narrow"): three wider, heavier heads for the D body. S = the head scale (HB). Head + Jaw segments, crests included.
      bruiser - a short deep snout on a wide boxy skull, a heavy brow ridge, a deep jaw and big teeth, short thick crests;
      croc    - a long, broad, flat snout that widens at the tip, teeth along the sides, eyes set high, low crests along
                the snout;
      viper   - a wedge: very wide at the back with swollen venom-gland cheeks, tapering to a hooked point, slit eyes under
                angled brows, crests that sweep back."""
    hx, hy = base
    seg("Head", (hx, hy, 0.0))

    def eyes(x, y, zz, ew, eh, brow_pitch, brow_len, slit=False):
        for side in (1, -1):
            s = "L" if side > 0 else "R"
            part("Head", "mask", (ew * 1.5, eh * 1.6, 0.04), (x, y, side * zz), name=f"Head_eyering{s}")
            part("Head", "eyes", (ew, eh, 0.05), (x + 0.01, y, side * (zz + 0.01)), name=f"Head_eye{s}")
            part("Head", "pupil", (ew * (0.2 if slit else 0.32), eh * 0.85, 0.03), (x + 0.03, y, side * (zz + 0.03)), name=f"Head_pupil{s}")
            part("Head", "mask", (brow_len, 0.12, 0.12), (x + 0.03, y + eh * 0.9, side * (zz - 0.03)), pitch=brow_pitch, name=f"Head_brow{s}")

    def teeth(x0, x1, y, z, n, h, w, prefix="Head", seg_="Head", t=0.07):
        for i in range(n):
            x = x0 + (x1 - x0) * i / max(1, n - 1)
            part(seg_, "tooth", (t, h, w), (x, y, z), name=f"{prefix}_tooth{i + 1}")

    if kind == "bruiser":
        part("Head", "main", (0.8 * S, 0.62 * S, 0.74 * S), (hx + 0.32, hy + 0.08, 0.0), name="Head_skull")
        part("Head", "main", (0.42 * S, 0.42 * S, 0.84 * S), (hx + 0.28, hy - 0.12, 0.0), name="Head_cheeks")
        part("Head", "main", (0.86, 0.5 * S, 0.62 * S), (hx + 1.05, hy - 0.04, 0.0), pitch=-4, name="Head_snout")
        part("Head", "main", (0.3, 0.44 * S, 0.58 * S), (hx + 1.55, hy - 0.1, 0.0), pitch=-8, name="Head_tip")
        part("Head", "mask", (0.55, 0.16, 0.8 * S), (hx + 0.45, hy + 0.08 + 0.31 * S + 0.05, 0.0), pitch=-12, name="Head_browridge")
        part("Head", "mouth", (1.25, 0.05, 0.6 * S), (hx + 1.0, hy - 0.25 * S, 0.0), pitch=-4, name="Head_mouth")
        teeth(hx + 0.65, hx + 1.55, hy - 0.25 * S - 0.06, 0.0, 6, 0.17, 0.62 * S, t=0.09)
        eyes(hx + 0.45, hy + 0.24, 0.37 * S + 0.02, 0.17, 0.15, -14, 0.38)
        for side in (1, -1):
            part("Head", "mask", (0.08, 0.08, 0.04), (hx + 1.65, hy - 0.02, side * 0.29 * S), name=f"Head_nostril{'L' if side > 0 else 'R'}")
        crests(hx + 0.55, hx + 1.45, hy + 0.08 + 0.31 * S - 0.05, 0.45, 0.2 * S, -6, 0.11)
        jr = (hx + 0.1, hy - 0.3 * S, 0.0)
        seg("Jaw", jr)
        for key, size, c, nm in [("main", (1.5, 0.32 * S, 0.66 * S), (hx + 0.85, hy - 0.5 * S, 0.0), "Jaw_lower"),
                                 ("main", (0.3, 0.34 * S, 0.6 * S), (hx + 1.55, hy - 0.5 * S, 0.0), "Jaw_chin"),
                                 ("frillmark", (0.7, 0.36 * S, 0.56 * S), (hx + 0.4, hy - 0.72 * S, 0.0), "Jaw_sac")]:
            part("Jaw", key, size, about(jr, c, -jaw_open), pitch=-jaw_open, name=nm)
        for i in range(5):
            c = (hx + 0.7 + i * 0.2, hy - 0.3 * S + 0.07, 0.0)
            part("Jaw", "tooth", (0.08, 0.14, 0.62 * S), about(jr, c, -jaw_open), pitch=-jaw_open, name=f"Jaw_tooth{i + 1}")

    elif kind == "croc":
        part("Head", "main", (0.72 * S, 0.58 * S, 0.68 * S), (hx + 0.3, hy + 0.06, 0.0), name="Head_skull")
        part("Head", "main", (1.45, 0.36 * S, 0.62 * S), (hx + 1.3, hy - 0.08, 0.0), pitch=-2, name="Head_snout")
        part("Head", "main", (0.4, 0.38 * S, 0.8 * S), (hx + 2.15, hy - 0.11, 0.0), pitch=-2, name="Head_spoon")
        part("Head", "mouth", (1.9, 0.05, 0.62 * S), (hx + 1.3, hy - 0.08 - 0.19 * S, 0.0), pitch=-2, name="Head_mouth")
        for side in (1, -1):  # teeth poking out along the sides
            s = "L" if side > 0 else "R"
            for i in range(7):
                x = hx + 0.75 + i * 0.24
                zz = side * (0.31 * S + (0.09 * S if x > hx + 1.9 else 0.0))
                part("Head", "tooth", (0.07, 0.16, 0.07), (x, hy - 0.08 - 0.22 * S, zz), name=f"Head_tooth{s}{i + 1}")
            part("Head", "main", (0.32, 0.24, 0.24), (hx + 0.42, hy + 0.06 + 0.33 * S, side * 0.24 * S), name=f"Head_eyebump{s}")
            part("Head", "mask", (0.08, 0.08, 0.04), (hx + 2.3, hy - 0.02, side * 0.3 * S), name=f"Head_nostril{s}")
        eyes(hx + 0.45, hy + 0.06 + 0.33 * S, 0.24 * S + 0.12, 0.15, 0.13, -10, 0.3)
        for side in (1, -1):  # low crests running along the snout sides
            for i in range(6):
                t = i / 5
                hh = 0.38 * math.sin(math.pi * (0.15 + 0.8 * t))
                part("Head", "crest", (0.2, hh, 0.07), (hx + 0.75 + 1.1 * t, hy - 0.08 + 0.18 * S + hh / 2, side * 0.26 * S),
                     name=f"Head_crest{i + 1}{'L' if side > 0 else 'R'}")
        jr = (hx + 0.1, hy - 0.3 * S, 0.0)
        seg("Jaw", jr)
        for key, size, c, nm in [("main", (2.0, 0.22 * S, 0.6 * S), (hx + 1.15, hy - 0.08 - 0.33 * S, 0.0), "Jaw_lower"),
                                 ("main", (0.38, 0.22 * S, 0.76 * S), (hx + 2.12, hy - 0.08 - 0.33 * S, 0.0), "Jaw_spoon"),
                                 ("frillmark", (0.6, 0.32 * S, 0.5 * S), (hx + 0.4, hy - 0.62 * S, 0.0), "Jaw_sac")]:
            part("Jaw", key, size, about(jr, c, -jaw_open), pitch=-jaw_open, name=nm)

    else:  # viper
        part("Head", "main", (0.78, 0.6 * S, 0.98 * S), (hx + 0.3, hy + 0.05, 0.0), name="Head_skull")
        for side in (1, -1):  # swollen venom-gland cheeks
            part("Head", "frillmark", (0.5, 0.42 * S, 0.22), (hx + 0.32, hy - 0.08, side * 0.52 * S), name=f"Head_gland{'L' if side > 0 else 'R'}")
        part("Head", "main", (0.62, 0.48 * S, 0.7 * S), (hx + 0.95, hy - 0.02, 0.0), pitch=-4, name="Head_snoutback")
        part("Head", "main", (0.6, 0.38 * S, 0.44 * S), (hx + 1.52, hy - 0.08, 0.0), pitch=-8, name="Head_snoutfront")
        part("Head", "main", (0.26, 0.34 * S, 0.3 * S), (hx + 1.9, hy - 0.16, 0.0), pitch=-28, name="Head_hook")
        part("Head", "mouth", (1.55, 0.05, 0.5 * S), (hx + 1.15, hy - 0.24 * S, 0.0), pitch=-6, name="Head_mouth")
        teeth(hx + 0.75, hx + 1.75, hy - 0.24 * S - 0.06, 0.0, 6, 0.13, 0.46 * S)
        part("Head", "tooth", (0.08, 0.3, 0.08), (hx + 1.62, hy - 0.24 * S - 0.12, 0.17 * S), name="Head_fangL")
        part("Head", "tooth", (0.08, 0.3, 0.08), (hx + 1.62, hy - 0.24 * S - 0.12, -0.17 * S), name="Head_fangR")
        eyes(hx + 0.5, hy + 0.18, 0.49 * S + 0.02, 0.24, 0.12, -22, 0.44, slit=True)
        for side in (1, -1):  # crests sweeping back off the snout
            for k in range(4):
                blade("Head", "crest", (hx + 1.35 - k * 0.3, hy + 0.12 + 0.05 * k, side * 0.16 * S), (-0.75, 0.66, 0), 0.55 + 0.08 * k, 0.16, 0.07,
                      name=f"Head_crest{k + 1}{'L' if side > 0 else 'R'}")
        jr = (hx + 0.1, hy - 0.3 * S, 0.0)
        seg("Jaw", jr)
        for key, size, c, nm in [("main", (0.7, 0.28 * S, 0.9 * S), (hx + 0.45, hy - 0.48 * S, 0.0), "Jaw_back"),
                                 ("main", (1.1, 0.22 * S, 0.48 * S), (hx + 1.25, hy - 0.42 * S, 0.0), "Jaw_front"),
                                 ("frillmark", (0.65, 0.34 * S, 0.62 * S), (hx + 0.4, hy - 0.7 * S, 0.0), "Jaw_sac")]:
            part("Jaw", key, size, about(jr, c, -jaw_open), pitch=-jaw_open, name=nm)


GROUND = -3.4

if STYLE == "cobra":
    # ------------------------------------------------------------ A Cobra Hood: slender, a long S-neck held high, the frill
    # a solid rounded hood around the head like a spitting cobra, with two dark eye-spots and a dark rim; tall thin
    # arched twin crests; a long whip tail
    BK = L.get("bulk", 1.0)  # v0.6: body thickness (A 1.0 = v0.1; D 1.35, Kepu: "the Dilo is too thin")
    HB = 1 + (BK - 1) * 0.5   # the head grows half as much
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (1.0, 0.76 * BK, 0.7 * BK), (-0.35, 0.14, 0.0), pitch=8, name="Torso_hips")
    part("Torso", "main", (1.25, 0.8 * BK, 0.74 * BK), (0.55, 0.22, 0.0), pitch=12, name="Torso_body")
    part("Torso", "main", (0.82, 0.82 * BK, 0.66 * BK), (1.32, 0.4, 0.0), pitch=24, name="Torso_chest")
    part("Torso", "belly", (1.8, 0.14, 0.5 * BK), (0.55, 0.22 - 0.4 * BK, 0.0), pitch=10, name="Torso_belly")
    for i, x in enumerate([-0.6, -0.15, 0.3, 0.75, 1.15]):
        for side in (1, -1):
            part("Torso", "stripes", (0.14, 0.56 * BK, 0.04), (x, 0.28 + x * 0.08, side * (0.37 * BK + 0.005)), pitch=-14, name=f"Torso_stripe{i + 1}{'L' if side > 0 else 'R'}")
    seg("Neck", (1.6, 0.6, 0.0))
    for i, (sz, c, p) in enumerate([((0.7, 0.48, 0.44), (1.88, 0.98, 0.0), 58), ((0.65, 0.42, 0.4), (2.08, 1.55, 0.0), 80), ((0.6, 0.4, 0.38), (2.22, 2.05, 0.0), 62)]):
        part("Neck", "main", (sz[0], sz[1] * BK, sz[2] * BK), c, pitch=p, name=f"Neck_{i + 1}")
    part("Neck", "belly", (0.95, 0.08, 0.3 * BK), (2.05 + 0.1 * (BK - 1), 1.4 - 0.12 * (BK - 1), 0.0), pitch=72, name="Neck_throat")
    if SPLIT:
        split_frill("Neck", (2.3, 2.15, 0.0), (0.85, 0.45, 0), L.get("hood", "hood"), 1.05 * FR, 115, 12)
    else:
        frill("Neck", (2.3, 2.15, 0.0), (0.85, 0.45, 0), L.get("hood", "hood"), 1.05 * FR, -115, 115, 11)
    if SPLIT:
        split_frill("Neck", (2.3, 2.15, 0.0), (0.85, 0.45, 0), "hood", 1.05 * FR, 115, 8, fold=True)
    else:
        frill("Neck", (2.3, 2.15, 0.0), (0.85, 0.45, 0), "hood", 1.05 * FR, -115, 115, 7, fold=True)
    if L.get("face"):  # v0.8: the redesigned heads
        face(L["face"], (2.45, 2.35), HB)
    else:
        head((2.45, 2.35), 1.15, 0.5 * HB, 0.44 * HB, 8, 0.17)
        crests(2.85, 3.85, 2.35 + 0.17 * HB, 0.6, 0.17 * HB, -4, 0.06)
    arms((1.35, 0.1), (1.55, -0.38), (1.92, -0.32), 0.35 * BK + 0.05 * (BK - 1), 0.14 * BK)
    tail([(1.35, (1.4, 0.5 * BK, 0.46 * BK), 4), (1.3, (1.35, 0.4 * BK, 0.36 * BK), 2), (1.25, (1.3, 0.3 * BK, 0.28 * BK), 0), (1.15, (1.2, 0.22 * BK, 0.2 * BK), -2), (1.05, (1.1, 0.15 * BK, 0.15 * BK), -3)], (-0.85, 0.22))
    legs((0.45, -1.45), (-0.4, -2.75), (-0.05, -3.3), 0.36 * BK, 0.38 * BK, 0.2 * BK)

elif STYLE == "sail":
    # ------------------------------------------------------------ B Sunburst: stocky and upright with a bigger head; the frill
    # a full round sail like a frilled lizard, spines poking past the edge and eye-spots in the membrane; a tall notched
    # mohawk of double crests; a thick tail
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (1.05, 0.9, 0.84), (-0.3, 0.2, 0.0), pitch=20, name="Torso_hips")
    part("Torso", "main", (1.2, 1.0, 0.9), (0.5, 0.5, 0.0), pitch=32, name="Torso_body")
    part("Torso", "main", (0.85, 0.95, 0.8), (1.1, 1.05, 0.0), pitch=48, name="Torso_chest")
    part("Torso", "belly", (0.3, 1.4, 0.62), (1.05, 0.5, 0.0), pitch=34, name="Torso_belly")
    for i, (x, y) in enumerate([(-0.45, 0.45), (0.0, 0.62), (0.45, 0.85), (0.85, 1.12)]):
        for side in (1, -1):
            part("Torso", "stripes", (0.16, 0.6, 0.04), (x, y - 0.2, side * 0.45), pitch=10, name=f"Torso_stripe{i + 1}{'L' if side > 0 else 'R'}")
    seg("Neck", (1.3, 1.4, 0.0))
    part("Neck", "main", (0.75, 0.6, 0.56), (1.45, 1.8, 0.0), pitch=72, name="Neck_1")
    part("Neck", "main", (0.65, 0.55, 0.5), (1.6, 2.25, 0.0), pitch=58, name="Neck_2")
    if SPLIT:
        split_frill("Neck", (1.68, 2.35, 0.0), (0.7, 0.7, 0), "sail", 1.2 * FR, 168, 16)
    else:
        frill("Neck", (1.68, 2.35, 0.0), (0.7, 0.7, 0), "sail", 1.2 * FR, -168, 168, 15)
    if SPLIT:
        split_frill("Neck", (1.68, 2.35, 0.0), (0.7, 0.7, 0), "sail", 1.2 * FR, 150, 10, fold=True)
    else:
        frill("Neck", (1.68, 2.35, 0.0), (0.7, 0.7, 0), "sail", 1.2 * FR, -150, 150, 9, fold=True)
    head((1.82, 2.55), 1.0, 0.62, 0.54, 12, 0.2)
    crests(2.1, 3.0, 2.82, 0.75, 0.2, -8, 0.08)
    for i in range(5):  # notches on the crest tops
        for side in (1, -1):
            part("Head", "mask", (0.08, 0.12, 0.1), (2.25 + i * 0.17, 2.86 + 0.6 * math.sin(math.pi * (0.15 + 0.8 * (i + 0.5) / 5)), side * 0.2),
                 name=f"Head_notchtop{i + 1}{'L' if side > 0 else 'R'}")
    arms((1.2, 0.75), (1.45, 0.2), (1.85, 0.32), 0.42, 0.17)
    tail([(1.2, (1.25, 0.62, 0.58), -18), (1.15, (1.2, 0.5, 0.46), -12), (1.1, (1.15, 0.4, 0.36), -6), (1.0, (1.05, 0.3, 0.28), -2), (0.95, (1.0, 0.22, 0.2), 2)], (-0.8, 0.0))
    legs((0.4, -1.4), (-0.4, -2.75), (-0.05, -3.3), 0.42, 0.44, 0.24)

else:
    # ------------------------------------------------------------ C Quill Stalker: low and horizontal like a sprinting heron,
    # the neck stretched forward; the frill a ruff of long banded quills like a lionfish; short swept-back crests like
    # horns; a long straight tail held level
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (1.05, 0.72, 0.68), (-0.35, 0.12, 0.0), pitch=0, name="Torso_hips")
    part("Torso", "main", (1.3, 0.76, 0.72), (0.6, 0.16, 0.0), pitch=2, name="Torso_body")
    part("Torso", "main", (0.85, 0.78, 0.64), (1.45, 0.2, 0.0), pitch=6, name="Torso_chest")
    part("Torso", "belly", (1.9, 0.14, 0.48), (0.6, -0.22, 0.0), name="Torso_belly")
    for i, x in enumerate([-0.6, -0.2, 0.2, 0.6, 1.0, 1.4]):
        part("Torso", "stripes", (0.18, 0.12, 0.72), (x, 0.55, 0.0), name=f"Torso_saddle{i + 1}")
    seg("Neck", (1.75, 0.35, 0.0))
    part("Neck", "main", (0.7, 0.46, 0.42), (2.05, 0.55, 0.0), pitch=32, name="Neck_1")
    part("Neck", "main", (0.65, 0.42, 0.4), (2.55, 0.78, 0.0), pitch=14, name="Neck_2")
    if SPLIT:
        split_frill("Neck", (2.75, 0.85, 0.0), (0.95, 0.25, 0), "quills", 1.15 * FR, 150, 14)
    else:
        frill("Neck", (2.75, 0.85, 0.0), (0.95, 0.25, 0), "quills", 1.15 * FR, -150, 150, 13)
    if SPLIT:
        split_frill("Neck", (2.75, 0.85, 0.0), (0.95, 0.25, 0), "quills", 1.15 * FR, 140, 10, fold=True)
    else:
        frill("Neck", (2.75, 0.85, 0.0), (0.95, 0.25, 0), "quills", 1.15 * FR, -140, 140, 9, fold=True)
    head((2.9, 0.92), 1.2, 0.48, 0.42, 6, 0.15)
    for side in (1, -1):  # short crests swept back like horns
        for k in range(3):
            blade("Head", "crest", (3.2 + k * 0.25, 1.12 - k * 0.04, side * 0.1), (-0.85, 0.5, side * 0.12), 0.45 - 0.08 * k, 0.12, 0.05,
                  name=f"Head_horn{k + 1}{'L' if side > 0 else 'R'}")
    arms((1.5, -0.05), (1.62, -0.5), (2.0, -0.45), 0.34, 0.13)
    tail([(1.35, (1.4, 0.48, 0.44), 0), (1.3, (1.35, 0.38, 0.35), 0), (1.25, (1.3, 0.3, 0.27), 0), (1.15, (1.2, 0.22, 0.2), 0), (1.05, (1.1, 0.15, 0.15), 0)], (-0.85, 0.2))
    legs((0.5, -1.4), (-0.45, -2.7), (-0.05, -3.3), 0.34, 0.36, 0.19)

NECK_ROOT = (0.0, 0.0)

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
if "--json" not in sys.argv:
    # ------------------------------------------------------------ full data file (v1.0), same layout as HerreraModelData / TenoModelData
    assert LOOK == "E" and SPLIT, "the data file is the picked look: E (D body + Bruiser face), split frill"
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
    attrs.update({"Species": '"Dilo"', "StyleVersion": '"1.0"', "DiloModelVersion": f'"{VERSION}"', "DisplayName": '"Dilo"',
                  "RigHipHeight": f"{HIP:.4g}", "BiteEnabled": "false", "PounceEnabled": "false", "RamEnabled": "false",
                  "RoarEnabled": "false", "JumpEnabled": "false", "CreepEnabled": "false"})
    attrs.pop("StarterCharacterVersion", None)
    for k in ("GaitAlwaysRun", "TRexModelVersion"):  # v1.1: T-Rex 2.0-only keys (not in the 1.0 data; the dilo walks and runs)
        attrs.pop(k, None)
    if "--no-kit" not in sys.argv:  # v1.1
        attrs.update(KIT_ATTRS)
    lines = [f"-- DiloModelData v{VERSION} (Mecha Dino Arena) — block-style Dilophosaurus ({LOOK} {L['name']}: thick Cobra Hood body, red / yellow split hood frill, Bruiser face), rig 1.3 joint names, skin-ready colour groups.",
             "-- Generated by tools/dilo_generator.py (do not edit by hand; change the generator and re-run). Mockup docs/mockups/dilo_model_options.html (v0.8, Kepu picked E: D's body with the Bruiser face).",
             f"-- Scale: {hi[0] - lo[0]:.2f} studs long, hip {HIP:.4g} studs; doubled in game (~26, the raptor's size). The frill is built twice: open (\"_frill\" parts) and folded (\"_fold\" parts); the kit plan decides which shows when.",
             f"-- Colour groups (Classic = {L['name']}): " + ", ".join(f"{r} {C[r]}" for r in ROLES) + "; never painted: teeth E8E2D2, pupil 111111, mouth 6E342E.",
             "-- All CFrames are relative to the HumanoidRootPart; sizes in studs; colors hex RGB. Rebuild with DinoModelBuilder.build(require(DiloModelData)).",
             ("-- v1.1 kit (MDA-221, plan docs/plans/DILO_KIT_v1.0.md): 70 HP, Bite + Spit Dart (DiloAttack*), Cobra Leap on JUMP (no charges, 0.5 s cooldown like the raptor, no landing slam); playable through SpeciesServer.\n-- v1.2: bite gap DiloMinGap 1.0 s (was 0.35; MDA-229)." if "--no-kit" not in sys.argv else "-- Not playable yet: no SpeciesServer entry, no kit (every move off). Those come with the Dilo kit plan."),
             "return {", f'\tversion = "{VERSION}", species = "Dilo", style = "1.0", rig = "1.3",'] + body + ["\tattributes = {"] + [f"\t\t{k} = {attrs[k]}," for k in sorted(attrs)] + ["\t},", "}"]
    open(OUT, "w").write("\n".join(lines) + "\n")
    print("data ->", OUT, f"({len(attrs)} attributes)")
n = sum(len(segments[s_]["parts"]) for s_ in order)
print(f"look {LOOK} ({L['name']}): {n} parts, {len(order)} segments, scale {K:.3f}, HIP {HIP:.3f}")
print("length %.2f, height %.2f, width %.2f" % (hi[0] - lo[0], hi[1] + HIP, hi[2] - lo[2]))
