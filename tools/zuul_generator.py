#!/usr/bin/env python3
"""Zuul generator v1.1 (Mecha Dino Arena) — writes src/shared/Models/ZuulModelData.luau.
v1.1 (Kepu 2026-11-02: "Okay let's just go with the battering Ram version"): Classic = C Battering Ram (default look,
Ram colours); the data file is look C. D stays reproducible with --look D.
v1.0 (Kepu 2026-11-02: "I want the thorn back with the mace shape at the end of the tail from the battering ram build"):
look D = B Thornback with C's mace club = Classic (default look, Thornback colours); without --json the generator writes
the data file (geometry + the T-Rex's attributes with every move off, Species "Zuul"). A / B / C stay reproducible.
v0.1 (mockup stage): three different styles for Kepu to pick from.

Kepu 2026-11-02: "The zuul is my next dinosaur" (three reference pictures: a teal Zuul with pale spikes and a big tail
club; a red-backed one with huge spikes and the tail swung round; a sandy model with rows of spikes). Answers: role
"Counter-attacker"; size "Like the T-Rex (~40)"; style "Heavier armor / spikier"; roster "Day 1".
Three different body designs (not one body in three colours):
  A Fortress    - a low, wide, flat-topped tank: even bands of big cone spikes across the back and sides, a horn-crowned
                  head, short thick legs, a long tail lined with paired spikes ending in a huge two-lobed club.
  B Thornback   - a high arched dome bristling like a hedgehog: long spikes radiating out, very long side spikes, the head
                  low with swept-back horns, the tail curled round to the side ready to swing, a club ringed with spikes.
  C Battering Ram - front-heavy: high armoured shoulders with huge forward shoulder spikes, rows of flat keeled plates on
                  the back, brow horns pointing forward, the tail held up straight with a heavy spiked mace.
Same 17-segment rig and joint names as the other dinos (rig 1.3); Arm segments = the front legs (like the teno). Dino
space D = (x forward, y up, z left), origin at the hip centre. Scaled so its length is TARGET_LEN (20 studs at scale 1,
doubled in game: ~40 like the T-Rex). Skin rule: 10 colour groups, no shared hex, no never-paint colour (pupil 111111,
mouth 6E342E, HRP A3A2A5; teeth E8E2D2 unused). Colours are a first pass per style and can move between styles.
Run: python3 tools/zuul_generator.py                (writes the data file: D Thornback Mace)
     python3 tools/zuul_generator.py --look A|B|C|D [--straight] --json OUT   (the three.js viewer's format)
"""
import json, math, os, sys

import re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Models", "ZuulModelData.luau")
TREX = os.path.join(ROOT, "src", "shared", "Models", "TRexModelData.luau")
SMOOTH = {"eyes", "pupil", "tooth", "claws", "mouth"}
VERSION = "1.1"
TARGET_LEN = 20.0    # studs at scale 1 (~40 in game, the T-Rex's length)
HRP_SIZE_D0 = (3.0, 1.8, 2.2)
ROLES = ["main", "plates", "spikes", "belly", "headplate", "horns", "limbs", "claws", "eyes", "club"]
NEVER = {"E8E2D2", "111111", "6E342E", "A3A2A5"}
LOOKS = {
    "A": {"name": "Fortress", "style": "fortress", "spk": 1.0, "neck": 0,
          "pal": {"main": "3E6E5A", "plates": "2F5446", "spikes": "D8D27A", "belly": "C9B98A", "headplate": "5A8A6A",
                  "horns": "E6D88A", "limbs": "33584A", "claws": "2A2620", "eyes": "E07A2A", "club": "B8B060"}},
    "B": {"name": "Thornback", "style": "thornback", "spk": 1.2, "neck": 0, "k": 1.499,
          "pal": {"main": "5E6A3E", "plates": "A8483A", "spikes": "E4D6B4", "belly": "B0A27A", "headplate": "B85440",
                  "horns": "D9CBA6", "limbs": "4A5432", "claws": "2A2420", "eyes": "F0C040", "club": "8E3A2E"}},
    "C": {"name": "Battering Ram", "style": "ram", "spk": 1.1, "neck": 0,
          "pal": {"main": "B08A62", "plates": "8E6A48", "spikes": "E2C8A0", "belly": "D6C4A0", "headplate": "9A7650",
                  "horns": "F0DCB8", "limbs": "7A5A3E", "claws": "2E2620", "eyes": "D8A030", "club": "6A4C34"}},
    # v1.0: Kepu's pick = B Thornback (body, colours, curled tail) with C Battering Ram's mace at the end of the tail
    "D": {"name": "Thornback Mace", "style": "thornback", "club": "mace", "spk": 1.2, "neck": 0, "k": 1.499,
          "pal": {"main": "5E6A3E", "plates": "A8483A", "spikes": "E4D6B4", "belly": "B0A27A", "headplate": "B85440",
                  "horns": "D9CBA6", "limbs": "4A5432", "claws": "2A2420", "eyes": "F0C040", "club": "8E3A2E"}},
}
LOOK = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else "C"  # v1.1: Classic = C Battering Ram (v1.0 was D)
L = LOOKS[LOOK]
SPK, NECK_RAISE, STYLE = L["spk"], L["neck"], L["style"]
F = 1.0
TAIL_W = 1.25  # tails read thin at 1.0
CURL = 0.0 if "--straight" in sys.argv else 1.0  # B: the scale is measured with the tail laid straight (--straight)
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
def spike(segname, base, d, length, w, key="spikes", name="spike"):
    """A cone-ish spike: three stacked tapering blocks along d (wide base, sharp tip)."""
    ref = (0, 1, 0) if abs(norm(d)[1]) < 0.9 else (1, 0, 0)
    w = w * 1.35
    p = blade(segname, key, base, d, length * 0.42, w, w, ref=ref, name=f"{name}a")
    p = blade(segname, key, p, d, length * 0.36, w * 0.64, w * 0.64, ref=ref, name=f"{name}b")
    blade(segname, key, p, d, length * 0.3, w * 0.3, w * 0.3, ref=ref, name=f"{name}c")


def bevel(x, length, cy, ry, rz, key="main", name="bevel", pitch=0.0):
    """Round the top corners of a box body: a block along each upper edge turned 45 degrees."""
    for side in (1, -1):
        part("Torso", key, (length, ry * 0.75, rz * 0.55), (x, cy + ry * 0.62, side * rz * 0.68), pitch=pitch, roll=-side * 45,
             name=f"{name}{'L' if side > 0 else 'R'}")


def body_ring(x, cy, ry, rz, angles, length_at, w, key, name, lean=-0.25, sz=1.0):
    """Spikes around an elliptical body cross-section at x (angle 0 = straight up, +90 = left side), leaning back."""
    for k, a in enumerate(angles):
        ar = math.radians(a)
        ny, nz = math.cos(ar), math.sin(ar)
        base = (x, cy + ry * ny * 0.92, rz * nz * 0.92)
        d = (lean, ny / ry, nz / rz)
        spike("Torso", base, d, length_at(a) * sz * SPK, w, key, f"{name}_{k + 1}")


def bumps(segname, x, cy, ry, rz, angles, size, key="plates", name="bump"):
    for k, a in enumerate(angles):
        ar = math.radians(a)
        part(segname, key, size, (x, cy + ry * math.cos(ar), rz * math.sin(ar)), roll=-a, name=f"{name}_{k + 1}")


def front_legs(sh, el, wr, z, upper, fore, foot):
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        zz = side * z
        seg(f"Arm{s}", (sh[0], sh[1], zz))
        part(f"Arm{s}", "main", (upper * 1.3, upper * 1.2, upper * 1.15), (sh[0], sh[1] - 0.1, zz), name=f"Arm{s}_shoulder")
        bone(f"Arm{s}", "main", (sh[0], sh[1], zz), (el[0], el[1], zz), upper, upper * 0.95, f"Arm{s}_upper")
        bone(f"Arm{s}", "limbs", (el[0], el[1], zz), (wr[0], wr[1], zz), fore, fore * 0.95, f"Arm{s}_fore")
        part(f"Arm{s}", "limbs", (foot, 0.28, foot * 0.95), (wr[0] + 0.08, GROUND + 0.14, zz), name=f"Arm{s}_foot")
        for i, dz in enumerate((-0.2, 0.0, 0.2)):
            part(f"Arm{s}", "claws", (0.2, 0.16, 0.14), (wr[0] + foot / 2 + 0.1, GROUND + 0.08, zz + dz * foot), name=f"Arm{s}_claw{i + 1}")
        spike(f"Arm{s}", (el[0] - 0.1, el[1] + 0.15, zz + side * upper * 0.45), (-0.4, 0.1, side * 1.0), 0.35 * SPK, 0.16, name=f"Arm{s}_elbowspike")


def hind_legs(knee, ankle, ball, z, thigh, shin):
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        zz = side * z
        seg(f"Leg{s}", (0.0, 0.0, zz))
        part(f"Leg{s}", "main", (thigh * 1.5, thigh * 1.3, thigh * 1.05), (0.0, -0.25, zz), name=f"Leg{s}_haunch")
        bone(f"Leg{s}", "main", (0.0, 0.0, zz), (knee[0], knee[1], zz), thigh, thigh * 0.95, f"Leg{s}_thigh")
        seg(f"Shin{s}", (knee[0], knee[1], zz))
        bone(f"Shin{s}", "limbs", (knee[0], knee[1], zz), (ankle[0], ankle[1], zz), shin, shin * 0.95, f"Shin{s}_shin")
        seg(f"Foot{s}", (ankle[0], ankle[1], zz))
        bone(f"Foot{s}", "limbs", (ankle[0], ankle[1], zz), (ball[0], GROUND + 0.2, zz), shin * 0.9, shin * 0.9, f"Foot{s}_meta")
        part(f"Foot{s}", "limbs", (shin * 1.6, 0.26, shin * 1.4), (ball[0] + 0.1, GROUND + 0.13, zz), name=f"Foot{s}_foot")
        for i, dz in enumerate((-0.22, 0.0, 0.22)):
            part(f"Foot{s}", "claws", (0.22, 0.16, 0.15), (ball[0] + shin * 0.8 + 0.18, GROUND + 0.08, zz + dz * shin * 1.4), name=f"Foot{s}_claw{i + 1}")


def tail(spec, root, side_spike, top="plates", curl=0.0, club="lobed", club_k=1.0):
    """spec = [(length, (width, height), pitch, yaw)]: a chain of tapering segments; the heading turns by yaw (curl)."""
    pos = root
    heading, pitch_acc = 0.0, 0.0
    for i, (seglen, (w, h), pch, yw) in enumerate(spec):
        name = f"Tail{i + 1}"
        heading += yw
        pitch_acc = pch
        hr, pr = math.radians(heading), math.radians(pitch_acc)
        d = (-math.cos(pr) * math.cos(hr), math.sin(pr), math.cos(pr) * math.sin(hr))
        seg(name, pos)
        w, h = w * TAIL_W, h * TAIL_W
        blade(name, "main", pos, d, seglen + 0.1, w, h, ref=(0, 1, 0), name=f"{name}_main")
        lat = norm(cross(d, (0, 1, 0)))  # horizontal, perpendicular to the tail
        for j, t in enumerate((0.3, 0.75)):
            c = tuple(pos[k] + d[k] * seglen * t for k in range(3))
            blade(name, top, (c[0] - d[0] * 0.15, c[1] + h / 2 - 0.05, c[2] - d[2] * 0.15), d, 0.32, w * 0.75, 0.12, ref=(0, 1, 0), name=f"{name}_plate{j + 1}")
            if side_spike(i) > 0:
                for sgn in (1, -1):
                    base = tuple(c[k] + lat[k] * sgn * w * 0.45 for k in range(3))
                    sd = tuple(lat[k] * sgn * 1.0 + d[k] * 0.55 for k in range(3))
                    spike(name, base, (sd[0], sd[1] + 0.15, sd[2]), side_spike(i) * SPK * (1.0 - 0.15 * j), 0.18, name=f"{name}_spike{j + 1}{'L' if sgn > 0 else 'R'}")
        end = tuple(pos[k] + d[k] * seglen for k in range(3))
        if i == len(spec) - 1:
            if club == "lobed":  # two big side lobes and a middle knob
                for sgn in (1, -1):
                    c = tuple(end[k] + d[k] * 0.1 + lat[k] * sgn * 0.42 * club_k for k in range(3))
                    blade(name, "club", tuple(c[k] - d[k] * 0.45 * club_k for k in range(3)), d, 0.95 * club_k, 0.72 * club_k, 0.85 * club_k, ref=(0, 1, 0), name=f"{name}_lobe{'L' if sgn > 0 else 'R'}")
                    blade(name, "club", tuple(c[k] - d[k] * 0.3 * club_k + lat[k] * sgn * 0.12 for k in range(3)), d, 0.65 * club_k, 0.5 * club_k, 1.05 * club_k, ref=(0, 1, 0), name=f"{name}_lobecore{'L' if sgn > 0 else 'R'}")
                blade(name, "club", tuple(end[k] - d[k] * 0.3 for k in range(3)), d, 1.05 * club_k, 0.7 * club_k, 0.7 * club_k, ref=(0, 1, 0), name=f"{name}_knob")
            elif club == "spiked":  # a lobed club ringed with spikes
                blade(name, "club", tuple(end[k] - d[k] * 0.35 for k in range(3)), d, 1.0 * club_k, 1.2 * club_k, 0.7 * club_k, ref=(0, 1, 0), name=f"{name}_club")
                for k_, (a_lat, a_up) in enumerate(((1, 0), (-1, 0), (0.7, 0.7), (-0.7, 0.7), (0.7, -0.6), (-0.7, -0.6))):
                    base = tuple(end[k] + d[k] * 0.15 + lat[k] * a_lat * 0.55 * club_k for k in range(3))
                    base = (base[0], base[1] + a_up * 0.3 * club_k, base[2])
                    sd = tuple(lat[k] * a_lat + d[k] * 0.2 for k in range(3))
                    spike(name, base, (sd[0], sd[1] + a_up, sd[2]), 0.55 * SPK, 0.2, name=f"{name}_clubspike{k_ + 1}")
            else:  # mace: a heavy block hammer with spikes all round
                blade(name, "club", tuple(end[k] - d[k] * 0.45 for k in range(3)), d, 1.2 * club_k, 1.0 * club_k, 1.0 * club_k, ref=(0, 1, 0), name=f"{name}_mace")
                c = tuple(end[k] + d[k] * 0.15 for k in range(3))
                for k_, (a_lat, a_up) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1), (0.7, 0.7), (-0.7, 0.7), (0.7, -0.7), (-0.7, -0.7))):
                    base = tuple(c[k] + lat[k] * a_lat * 0.45 * club_k for k in range(3))
                    base = (base[0], base[1] + a_up * 0.45 * club_k, base[2])
                    sd = tuple(lat[k] * a_lat for k in range(3))
                    spike(name, base, (sd[0] + d[0] * 0.1, sd[1] + a_up, sd[2] + d[2] * 0.1), 0.5 * SPK, 0.2, name=f"{name}_macespike{k_ + 1}")
                spike(name, tuple(end[k] + d[k] * 0.7 for k in range(3)), d, 0.5 * SPK, 0.22, name=f"{name}_macetip")
        pos = end


def head(cx, cy, w, l, h, horn_back, horn_cheek, brow, pitch=0.0):
    """Broad armoured head with a beak; horns: back corners (up / out / back) and cheeks (down / out / back)."""
    seg("Head", (cx - l * 0.45, cy, 0.0))
    part("Head", "main", (l, h, w), (cx, cy, 0.0), pitch=pitch, name="Head_skull")
    part("Head", "main", (l * 0.45, h * 0.7, w * 0.72), (cx + l * 0.62, cy - h * 0.15, 0.0), pitch=pitch - 6, name="Head_snout")
    part("Head", "headplate", (l * 0.16, h * 0.55, w * 0.55), (cx + l * 0.9, cy - h * 0.2, 0.0), pitch=pitch - 6, name="Head_beak")
    part("Head", "mouth", (l * 0.5, 0.05, w * 0.6), (cx + l * 0.6, cy - h * 0.48, 0.0), name="Head_mouth")
    for i, (x, z, sz) in enumerate(((-0.25, 0.0, 0.3), (0.1, -0.25, 0.26), (0.1, 0.25, 0.26), (-0.3, -0.32, 0.24), (-0.3, 0.32, 0.24), (0.35, 0.0, 0.24))):
        part("Head", "headplate", (sz * l, 0.14, sz * w), (cx + x * l, cy + h / 2 + 0.05, z * w), name=f"Head_plate{i + 1}")
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        part("Head", "eyes", (0.16, 0.14, 0.05), (cx + l * 0.2, cy + h * 0.12, side * (w / 2 + 0.01)), name=f"Head_eye{s}")
        part("Head", "pupil", (0.06, 0.12, 0.03), (cx + l * 0.22, cy + h * 0.12, side * (w / 2 + 0.03)), name=f"Head_pupil{s}")
        part("Head", "headplate", (0.42, 0.14, 0.12), (cx + l * 0.18, cy + h * 0.32, side * (w / 2 - 0.02)), pitch=-brow, name=f"Head_brow{s}")
        spike("Head", (cx - l * 0.4, cy + h * 0.35, side * w * 0.45), (-horn_back[1], horn_back[2], side * 1.0), horn_back[0], 0.24, "horns", f"Head_hornback{s}")
        spike("Head", (cx - l * 0.15, cy - h * 0.3, side * w * 0.48), (-0.4, -horn_cheek[1], side * 1.0), horn_cheek[0], 0.22, "horns", f"Head_horncheek{s}")
    seg("Jaw", (cx - l * 0.3, cy - h * 0.4, 0.0))
    part("Jaw", "belly", (l * 0.95, h * 0.22, w * 0.8), (cx + l * 0.25, cy - h * 0.58, 0.0), pitch=-4, name="Jaw_lower")
    part("Jaw", "headplate", (l * 0.14, h * 0.24, w * 0.5), (cx + l * 0.78, cy - h * 0.56, 0.0), pitch=-6, name="Jaw_beak")


GROUND = -1.75  # low-slung: short legs

if STYLE == "fortress":
    # ------------------------------------------------------------ A Fortress: a low, wide, flat-topped tank. Even bands of
    # big cone spikes across the whole back and down the sides, a broad head with a horn crown, short thick splayed legs,
    # a long tail lined with paired spikes ending in a huge two-lobed club.
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (1.8, 1.1, 2.3), (-0.4, 0.15, 0.0), name="Torso_hips")
    part("Torso", "main", (2.5, 1.3, 2.7), (1.0, 0.25, 0.0), name="Torso_body")
    part("Torso", "main", (1.3, 1.1, 2.4), (2.4, 0.15, 0.0), name="Torso_shoulders")
    part("Torso", "plates", (4.0, 0.3, 1.5), (0.9, 0.9, 0.0), name="Torso_shell")
    bevel(0.9, 4.0, 0.25, 0.75, 1.35, key="plates", name="Torso_shellbevel")
    part("Torso", "belly", (3.6, 0.2, 1.9), (0.9, -0.45, 0.0), name="Torso_belly")
    for i, x in enumerate([-0.95, -0.35, 0.25, 0.85, 1.45, 2.05, 2.6]):
        body_ring(x, 0.45, 0.62, 1.32, (0, -35, 35, -70, 70, -100, 100), lambda a: 0.42 + 0.003 * abs(a), 0.26, "spikes", f"Torso_band{i + 1}", lean=-0.15)
        if i < 6:
            bumps("Torso", x + 0.3, 0.45, 0.62, 1.32, (-18, 18, -52, 52, -85, 85), (0.34, 0.12, 0.3), name=f"Torso_bump{i + 1}")
    NECK_ROOT = (3.0, 0.25)
    seg("Neck", (3.0, 0.25, 0.0))
    part("Neck", "main", (0.7, 0.9, 1.5), (3.25, 0.2, 0.0), name="Neck_main")
    for k, a in enumerate((-60, -20, 20, 60)):
        ar = math.radians(a)
        spike("Neck", (3.25, 0.2 + 0.45 * math.cos(ar), 0.7 * math.sin(ar)), (0.05, math.cos(ar), math.sin(ar) * 1.2), 0.45 * SPK, 0.24, name=f"Neck_collar{k + 1}")
    head(4.1, 0.15, 1.35, 1.15, 0.8, (0.5 * SPK, 0.7, 0.5), (0.4 * SPK, 0.6), 10)
    front_legs((2.55, -0.05), (2.72, -0.85), (2.65, -1.5), 1.05, 0.6, 0.52, 0.66)
    hind_legs((0.3, -0.8), (-0.05, -1.45), (0.15, -1.65), 0.95, 0.66, 0.54)
    tail([(1.45, (1.4, 0.85), -4, 0), (1.4, (1.15, 0.68), -3, 0), (1.35, (0.9, 0.52), -2, 0), (1.3, (0.7, 0.42), -1, 0), (1.2, (0.55, 0.34), 0, 0)],
         (-1.3, 0.25, 0.0), lambda i: [0.55, 0.5, 0.42, 0.34, 0.0][i], club="lobed", club_k=1.0)

elif STYLE == "thornback":
    # ------------------------------------------------------------ B Thornback: a high arched dome bristling like a hedgehog,
    # long spikes radiating out of the back and very long side spikes, the head held low with swept-back horns, the tail
    # curled round to the side ready to swing, its club ringed with spikes.
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (1.7, 1.2, 2.2), (-0.4, 0.2, 0.0), pitch=-8, name="Torso_hips")
    part("Torso", "main", (2.6, 1.8, 2.6), (0.95, 0.5, 0.0), name="Torso_dome")
    part("Torso", "main", (1.3, 1.2, 2.3), (2.4, 0.15, 0.0), pitch=10, name="Torso_shoulders")
    part("Torso", "plates", (3.2, 0.35, 1.5), (0.95, 1.35, 0.0), name="Torso_shell")
    bevel(0.95, 2.8, 0.5, 0.95, 1.35, key="plates", name="Torso_domebevel")
    part("Torso", "belly", (3.4, 0.2, 1.8), (0.9, -0.45, 0.0), name="Torso_belly")
    for i, x in enumerate([-0.85, -0.2, 0.45, 1.1, 1.75, 2.35]):
        hump = 1.0 - abs(x - 0.9) / 2.4
        body_ring(x, 0.55, 0.65 + 0.45 * hump, 1.3, (0, -30, 30, -60, 60, -90, 90),
                  lambda a, h=hump: (0.55 + 0.5 * h) * (1.0 + 0.6 * (abs(a) >= 90)), 0.24, "spikes", f"Torso_ring{i + 1}", lean=-0.45)
        bumps("Torso", x + 0.33, 0.55, 0.65 + 0.45 * hump, 1.3, (-15, 15, -45, 45, -75, 75), (0.3, 0.12, 0.28), name=f"Torso_bump{i + 1}")
    NECK_ROOT = (2.9, 0.1)
    seg("Neck", (2.9, 0.1, 0.0))
    part("Neck", "main", (0.8, 0.85, 1.4), (3.2, -0.05, 0.0), pitch=-20, name="Neck_main")
    for k, a in enumerate((-50, 0, 50)):
        ar = math.radians(a)
        spike("Neck", (3.15, 0.3 * math.cos(ar) + 0.2, 0.65 * math.sin(ar)), (-0.5, math.cos(ar), math.sin(ar) * 1.4), 0.55 * SPK, 0.22, name=f"Neck_collar{k + 1}")
    head(4.0, -0.3, 1.3, 1.1, 0.78, (0.75 * SPK, 1.2, 0.35), (0.45 * SPK, 0.4), 18, pitch=-10)
    front_legs((2.5, -0.05), (2.72, -0.85), (2.6, -1.5), 1.0, 0.56, 0.5, 0.62)
    hind_legs((0.3, -0.8), (-0.05, -1.45), (0.15, -1.65), 0.95, 0.62, 0.5)
    tail([(1.4, (1.3, 0.8), 2, 6 * CURL), (1.35, (1.05, 0.64), 8, 16 * CURL), (1.3, (0.85, 0.5), 10, 22 * CURL), (1.2, (0.68, 0.4), 6, 24 * CURL), (1.1, (0.55, 0.32), 0, 22 * CURL)],
         (-1.25, 0.3, 0.0), lambda i: [0.7, 0.65, 0.55, 0.45, 0.0][i], club=L.get("club", "spiked"), club_k=1.0)

else:
    # ------------------------------------------------------------ C Battering Ram: front-heavy with high armoured shoulders
    # and huge forward shoulder spikes, the back covered in rows of flat keeled plates instead of cones, a thick head with
    # brow horns pointing forward, the tail held up and straight behind with a heavy spiked mace.
    seg("Torso", (0.0, 0.0, 0.0))
    part("Torso", "main", (1.6, 1.0, 2.1), (-0.4, 0.1, 0.0), pitch=-6, name="Torso_hips")
    part("Torso", "main", (2.4, 1.4, 2.6), (0.95, 0.3, 0.0), pitch=-8, name="Torso_body")
    part("Torso", "main", (1.6, 1.6, 2.6), (2.35, 0.55, 0.0), pitch=-10, name="Torso_shoulders")
    part("Torso", "belly", (3.4, 0.2, 1.8), (0.9, -0.42, 0.0), name="Torso_belly")
    bevel(0.95, 2.4, 0.3, 0.7, 1.3, name="Torso_bodybevel", pitch=-8)
    bevel(2.35, 1.6, 0.55, 0.8, 1.3, name="Torso_shoulderbevel", pitch=-10)
    for i, x in enumerate([-0.9, -0.35, 0.2, 0.75, 1.3, 1.85]):
        top = 0.62 + 0.18 * (x + 0.9)
        for k, z in enumerate((-0.9, -0.3, 0.3, 0.9)):
            part("Torso", "plates", (0.5, 0.16, 0.52), (x, top + 0.05 - 0.12 * abs(z), z), roll=-z * 12, name=f"Torso_plate{i + 1}_{k + 1}")
            part("Torso", "spikes", (0.32, 0.18, 0.08), (x, top + 0.18 - 0.12 * abs(z), z), roll=-z * 12, name=f"Torso_keel{i + 1}_{k + 1}")
        for side in (1, -1):  # side spikes, short at the hips, growing to the shoulders
            spike("Torso", (x, 0.3, side * 1.25), (-0.3, -0.05, side * 1.0), (0.3 + 0.12 * i) * SPK, 0.22, name=f"Torso_side{i + 1}{'L' if side > 0 else 'R'}")
    for side in (1, -1):  # the huge forward shoulder spikes
        s = "L" if side > 0 else "R"
        spike("Torso", (2.55, 0.75, side * 1.3), (0.9, 0.3, side * 0.75), 1.8 * SPK, 0.4, name=f"Torso_shoulderspike{s}")
        spike("Torso", (2.2, 1.2, side * 0.95), (0.4, 0.75, side * 0.6), 1.2 * SPK, 0.34, name=f"Torso_shoulderspike2{s}")
        spike("Torso", (1.95, 0.45, side * 1.32), (0.2, 0.05, side * 1.0), 1.1 * SPK, 0.32, name=f"Torso_shoulderspike3{s}")
    NECK_ROOT = (3.0, 0.5)
    seg("Neck", (3.0, 0.5, 0.0))
    part("Neck", "main", (0.7, 1.0, 1.5), (3.25, 0.35, 0.0), pitch=-15, name="Neck_main")
    part("Neck", "plates", (0.6, 0.18, 1.2), (3.25, 0.9, 0.0), pitch=-15, name="Neck_plate")
    head(4.15, 0.2, 1.4, 1.2, 0.95, (0.45 * SPK, 0.3, 0.6), (0.35 * SPK, 0.5), 6)
    for side in (1, -1):  # forward brow horns (ramming)
        spike("Head", (4.4, 0.75, side * 0.5), (1.0, 0.45, side * 0.25), 0.6 * SPK, 0.24, "horns", f"Head_ramhorn{'L' if side > 0 else 'R'}")
    front_legs((2.6, 0.05), (2.8, -0.85), (2.7, -1.5), 1.05, 0.66, 0.56, 0.7)
    hind_legs((0.3, -0.8), (-0.05, -1.45), (0.15, -1.65), 0.9, 0.58, 0.48)
    tail([(1.4, (1.2, 0.78), 6, 0), (1.35, (0.95, 0.6), 5, 0), (1.3, (0.75, 0.46), 3, 0), (1.25, (0.6, 0.38), 1, 0), (1.15, (0.5, 0.32), 0, 0)],
         (-1.2, 0.3, 0.0), lambda i: [0.3, 0.25, 0.0, 0.0, 0.0][i], club="mace", club_k=1.0)


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
K = (L.get("k") if CURL else None) or TARGET_LEN / (hi[0] - lo[0])  # B has a fixed k: its length is measured with the tail straight
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
    assert LOOK == "C", "the data file is the picked look: C Battering Ram (v1.1)"
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
    attrs.update({"Species": '"Zuul"', "StyleVersion": '"1.0"', "ZuulModelVersion": f'"{VERSION}"', "DisplayName": '"Zuul"',
                  "RigHipHeight": f"{HIP:.4g}", "BiteEnabled": "false", "PounceEnabled": "false", "RamEnabled": "false",
                  "RoarEnabled": "false", "JumpEnabled": "false", "CreepEnabled": "false"})
    attrs.pop("StarterCharacterVersion", None)
    lines = [f"-- ZuulModelData v{VERSION} (Mecha Dino Arena) — block-style armoured Zuul ankylosaur ({LOOK} {L['name']}: high armoured shoulders, huge shoulder spikes, keeled plates, spiked mace), rig 1.3 joint names, skin-ready colour groups.",
             "-- Generated by tools/zuul_generator.py (do not edit by hand; change the generator and re-run). Mockup docs/mockups/zuul_model_options.html (v0.4, Kepu picked C Battering Ram).",
             f"-- Scale: {hi[0] - lo[0]:.2f} studs long, hip {HIP:.4g} studs; doubled in game (~40, the T-Rex's length); four legs, Arm segments = front legs.",
             f"-- Colour groups (Classic = {L['name']}): " + ", ".join(f"{r} {C[r]}" for r in ROLES) + "; never painted: pupil 111111, mouth 6E342E.",
             "-- All CFrames are relative to the HumanoidRootPart; sizes in studs; colors hex RGB. Rebuild with DinoModelBuilder.build(require(ZuulModelData)).",
             "-- Not playable yet: no SpeciesServer entry, no kit (every move off). Those come with the Zuul kit plan.",
             "return {", f'\tversion = "{VERSION}", species = "Zuul", style = "1.0", rig = "1.3",'] + body + ["\tattributes = {"] + [f"\t\t{k} = {attrs[k]}," for k in sorted(attrs)] + ["\t},", "}"]
    open(OUT, "w").write("\n".join(lines) + "\n")
    print("data ->", OUT, f"({len(attrs)} attributes)")
n = sum(len(segments[s_]["parts"]) for s_ in order)
print(f"look {LOOK} ({L['name']}): {n} parts, {len(order)} segments, scale {K:.3f}, HIP {HIP:.3f}")
print("length %.2f, height %.2f, width %.2f" % (hi[0] - lo[0], hi[1] + HIP, hi[2] - lo[2]))
