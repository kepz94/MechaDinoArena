# rec_pack.py v1.1 (Mecha Dino Arena) — packs a move recording made in Studio by tools/studio/move_recorder.luau (MDA-552,
# Kepu 2026-11-17 "How about you actually use the fucking animation from the game") into the compact form the pick pages play.
# Usage: python3 tools/mockup/rec_pack.py <raw.json> <out.json> [lead seconds before the press, default 0.3] [--nobot]
# Raw (from the recorder): every part of the dino, the target bot and the effects near them, 30 Hz, in the frame of the
#   dino's root at the start (+X right, +Y up, -Z forward). Parts rigid on a joint segment are {seg, rel}; the rest {tr: per
#   frame [x,y,z, r00..r22] or 0 (absent) or 1 (same as the frame before)}. changes = [frame, part, size, transparency, colour]
#   or [frame, part, 0] (gone). bursts / emits = particle emitters made / running; stamps = attribute changes
#   [time, "me"/"bot", name, value (server stamps as seconds on the recording clock), isServerTime].
# Out: {len, press, ground, lines (beams / ropes per frame), parts: [{sh, m, s0, seg?, rel?, k?}], tracks: base64 int16 (x, y, z in 1/100 stud, quaternion
#   x 32767; absent = -32768 in x), changes, particles, stamps}. Time 0 = the press - lead.
# v1.1 (the Raptor pick page, 2026-11-17): also reads move_recorder 1.1's export3 tracks ("trb": base64 int16 x7 per frame,
#   already quaternions; absent = -32768 in x), about a quarter of the size of "tr"; and its Highlight changes ("hls" ->
#   out "hl": [frame, who, fill, fillT, outline, outlineT] or [frame, who, 0]; the state at the window start folds into frame 0).
import base64, json, math, struct, sys

NOBOT = "--nobot" in sys.argv  # v1.0: drop the bot (a bystander in that recording, pinned at the wrong height by the test setup)
args = [a for a in sys.argv[1:] if a != "--nobot"]
raw, out_path = args[0], args[1]
LEAD = float(args[2]) if len(args) > 2 else 0.3
d = json.load(open(raw))
F = d["frames"]
times = d["times"]
press = d["presses"][0][0]
t0 = press - LEAD
# first frame at or after t0
f0 = next(i for i, t in enumerate(times) if t >= t0 - 1e-6)
frames = list(range(f0, F))
parts = d["parts"]

def expand(tr):
    out, prev = [], 0
    for a in tr:
        if a == 1: a = prev
        out.append(a)
        prev = a
    return out

def quat(m):  # rotation matrix rows r00 r01 r02 / r10.. -> (x, y, z, w)
    r00, r01, r02, r10, r11, r12, r20, r21, r22 = m
    tr = r00 + r11 + r22
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2; w = 0.25 * s; x = (r21 - r12) / s; y = (r02 - r20) / s; z = (r10 - r01) / s
    elif r00 > r11 and r00 > r22:
        s = math.sqrt(1.0 + r00 - r11 - r22) * 2; w = (r21 - r12) / s; x = 0.25 * s; y = (r01 + r10) / s; z = (r02 + r20) / s
    elif r11 > r22:
        s = math.sqrt(1.0 + r11 - r00 - r22) * 2; w = (r02 - r20) / s; x = (r01 + r10) / s; y = 0.25 * s; z = (r12 + r21) / s
    else:
        s = math.sqrt(1.0 + r22 - r00 - r11) * 2; w = (r10 - r01) / s; x = (r02 + r20) / s; y = (r12 + r21) / s; z = 0.25 * s
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1
    return x / n, y / n, z / n, w / n

# first state of every part (size, transparency, colour) and its changes inside the window
first, chg = {}, {}
for c in d["changes"]:
    f, i = c[0] - 1, c[1] - 1
    if i not in first and len(c) > 3: first[i] = c
    chg.setdefault(i, []).append(c)
# parts never visible are dropped unless something hangs on them
used_as_seg = {p["seg"] - 1 for p in parts if p.get("seg")}
def ever_visible(i):
    return any(len(c) > 3 and c[3] < 0.99 for c in chg.get(i, []))
keep = [i for i in range(len(parts)) if (ever_visible(i) or i in used_as_seg or parts[i]["n"] == "HumanoidRootPart") and not (NOBOT and parts[i]["own"] == "bot")]
idx = {i: k for k, i in enumerate(keep)}
P, tracks = [], bytearray()
ntr = 0
for i in keep:
    p = parts[i]
    fc = first.get(i)
    e = {"n": p["n"], "o": p["own"], "sh": p["sh"], "m": p["mat"],
         "s0": fc[2] if fc else [1, 1, 1], "t0": fc[3] if fc else 1, "c0": fc[4] if fc else "ffffff"}
    if not ever_visible(i): e["hid"] = 1
    if p.get("seg"):
        e["seg"] = idx[p["seg"] - 1]
        e["rel"] = p["rel"]
    elif p.get("trb"):  # v1.1: packed already
        raw7 = base64.b64decode(p["trb"])
        e["k"] = ntr
        ntr += 1
        for f in frames:
            tracks += raw7[f * 14:(f + 1) * 14] if (f + 1) * 14 <= len(raw7) else struct.pack("<7h", -32768, 0, 0, 0, 0, 0, 0)
    else:
        tr = expand(p["tr"])
        e["k"] = ntr
        ntr += 1
        for f in frames:
            a = tr[f] if f < len(tr) else 0
            if a == 0:
                tracks += struct.pack("<7h", -32768, 0, 0, 0, 0, 0, 0)
            else:
                q = quat(a[3:12])
                tracks += struct.pack("<7h", *[max(-32767, min(32767, round(v * 100))) for v in a[:3]], *[round(v * 32767) for v in q])
    # changes inside the window (frame index relative to f0; earlier ones fold into the start state)
    cl, start = [], None
    for c in chg.get(i, []):
        f = c[0] - 1
        if f < f0:
            if len(c) > 3: start = c
            else: start = ["gone"]
            continue
        cl.append([f - f0] + (c[2:] if len(c) > 3 else [0]))
    if start is not None:
        if start == ["gone"]: e["gone0"] = 1
        else: e["s0"], e["t0"], e["c0"] = start[2], start[3], start[4]
    if cl: e["ch"] = cl
    P.append(e)

# particles: bursts (made during the recording) and running emitters, in the window
em = d["emitters"]
parts_fx = []
for f, k in d["bursts"]:
    f -= 1
    if f < f0: continue
    E = em[k - 1]
    parts_fx.append({"f": f - f0, "e": k - 1, "burst": 1})
emits = [[f - 1 - f0, k - 1, cf, rate] for f, k, cf, rate in d["emits"] if f - 1 >= f0]
emitters = [{k2: E[k2] for k2 in ("c0", "c1", "s0", "s1", "t0", "sp", "sp0", "life", "life0", "spread", "dir", "acc", "drag", "le", "rate", "cf", "n")} for E in em]

# beams and ropes (the tether chain): [frame, x0, y0, z0, x1, y1, z1, width, colour, transparency]
lines = [[b[0] - 1 - f0] + b[2:8] + [b[8], b[10], b[11]] for b in d.get("beamFrames", []) if b[0] - 1 >= f0]
hl, hl0 = [], {}
for h in d.get("hls", []):  # v1.1
    f = h[0] - 1 - f0
    if f < 0: hl0[h[1]] = h
    else: hl.append([f] + h[1:])
hl = [[0] + h[1:] for h in hl0.values()] + hl
st = d["stamps"]
stamps = [[round(s[0] - t0, 3), s[1], s[2], (round(s[3] - t0, 3) if (len(s) > 4 and s[4]) else s[3]), bool(len(s) > 4 and s[4])] for s in st]
out = {"name": d["name"], "fps": 30, "frames": len(frames), "len": round(times[-1] - t0, 3), "lead": LEAD, "ground": d["ground"],
       "times": [round(times[f] - t0, 3) for f in frames], "parts": P, "ntr": ntr,
       "tracks": base64.b64encode(bytes(tracks)).decode(), "lines": lines, "bursts": parts_fx, "emits": emits, "emitters": emitters,
       "hl": hl, "stamps": stamps, "presses": [[round(p[0] - t0, 3), p[1]] for p in d["presses"]]}
json.dump(out, open(out_path, "w"), separators=(",", ":"))
print(out_path, "frames", len(frames), "parts", len(P), "tracks", ntr, "bytes", len(json.dumps(out, separators=(",", ":"))))
