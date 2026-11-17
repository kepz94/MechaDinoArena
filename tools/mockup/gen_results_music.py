# gen_results_music.py v1.0 (Mecha Dino Arena) — placeholder results music for the end-of-match presentation mockup (MDA-552,
# Kepu 2026-11-17 13:18 "Send me a mock up of the actual presentation that we have plus all the new stuff we're proposing").
# Original 8-bit pieces written here note by note (no samples, no outside music), to show where a victory / defeat track
# would sit under the show; the real tracks are picked later. Writes, mono 48 kHz 16-bit:
#   MDA_MUS_victory_intro.wav (2 bars, a fanfare)  MDA_MUS_victory_loop.wav (4 bars, loops cleanly)  132 BPM, C major
#   MDA_MUS_defeat_loop.wav (4 bars, loops cleanly)  76 BPM, A minor
# Usage: python3 -I tools/mockup/gen_results_music.py <out dir>
import sys, os, wave
import numpy as np
SR = 48000
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
def hz(n):  # "C5" -> Hz
    name, octv = n[:-1], int(n[-1])
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octv + 1) - 69) / 12)
def env(n, a=0.004, r=0.06, sus=0.75):
    e = np.ones(n) * sus
    ai, ri = max(1, int(a * SR)), max(1, int(r * SR))
    e[:ai] = np.linspace(0, 1, ai)
    if ai < n: e[ai:min(n, ai + int(0.03 * SR))] = np.linspace(1, sus, min(n, ai + int(0.03 * SR)) - ai)
    e[-ri:] *= np.linspace(1, 0, ri)
    return e
def pulse(f, n, duty=0.25):
    t = np.arange(n) / SR
    return np.where((t * f) % 1 < duty, 1.0, -1.0)
def tri(f, n):
    t = np.arange(n) / SR
    return 2 * np.abs(2 * ((t * f) % 1) - 1) - 1
_rng = np.random.default_rng(7)
def noise(n):
    return _rng.uniform(-1, 1, n)
def render(bars, bpm, voices):
    beat = 60 / bpm
    total = int(bars * 4 * beat * SR)
    mix = np.zeros(total)
    for kind, vol, notes in voices:  # notes: [(start beat, length beats, note or None)]
        for st, ln, nt in notes:
            i0, n = int(st * beat * SR), int(ln * beat * SR)
            n = min(n, total - i0)
            if n <= 0: continue
            if kind == "lead": w = pulse(hz(nt), n, 0.25) * env(n, r=0.05, sus=0.7)
            elif kind == "lead2": w = pulse(hz(nt), n, 0.125) * env(n, r=0.04, sus=0.55)
            elif kind == "bass": w = tri(hz(nt), n) * env(n, r=0.03, sus=0.9)
            elif kind == "pad": w = tri(hz(nt), n) * env(n, a=0.08, r=0.3, sus=0.8)
            elif kind == "hat": m = min(n, int(0.035 * SR)); w = np.zeros(n); w[:m] = noise(m) * np.linspace(1, 0, m) ** 2
            elif kind == "kick":
                m = min(n, int(0.12 * SR)); t = np.arange(m) / SR; w = np.zeros(n)
                w[:m] = np.sin(2 * np.pi * (110 * t - 220 * t * t)) * np.linspace(1, 0, m) ** 1.5
            elif kind == "snare": m = min(n, int(0.1 * SR)); w = np.zeros(n); w[:m] = noise(m) * np.linspace(1, 0, m) ** 1.2
            mix[i0:i0 + n] += w * vol
    return mix
def write(name, x):
    x = x / max(1e-9, np.max(np.abs(x))) * 0.89
    with wave.open(os.path.join(out, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(name, round(len(x) / SR, 2), "s")
def arp(chords, start, beats_per, pattern, octs, step=0.5, length=0.45):
    notes = []
    b = start
    for ch in chords:
        k = 0
        t = 0.0
        while t < beats_per - 1e-6:
            nm = ch[pattern[k % len(pattern)]]
            notes.append((b + t, length, nm + str(octs[k % len(octs)])))
            k += 1; t += step
        b += beats_per
    return notes
def drums(bars, start=0, hat=True, kick=True, snare=True):
    h, k, s = [], [], []
    for bar in range(bars):
        b0 = start + bar * 4
        for i in range(8): h.append((b0 + i * 0.5, 0.25, None))
        k += [(b0, 0.5, None), (b0 + 2, 0.5, None), (b0 + 2.75, 0.5, None)]
        s += [(b0 + 1, 0.5, None), (b0 + 3, 0.5, None)]
    v = []
    if hat: v.append(("hat", 0.10, h))
    if kick: v.append(("kick", 0.55, k))
    if snare: v.append(("snare", 0.22, s))
    return v

# ---------- victory intro: 2 bars, a rising fanfare that lands on C ----------
intro_lead = [(0, 0.5, "G4"), (0.5, 0.5, "C5"), (1, 0.5, "E5"), (1.5, 0.5, "G5"), (2, 1.0, "E5"), (3, 0.5, "G5"),
              (3.5, 0.5, "A5"), (4, 1.5, "C6"), (5.5, 0.5, "B5"), (6, 2.0, "C6")]
intro_bass = [(0, 2, "C3"), (2, 2, "G2"), (4, 2, "F2"), (6, 2, "C3")]
intro = render(2, 132, [("lead", 0.30, intro_lead), ("lead2", 0.12, [(s + 0.02, l, n[:-1] + str(int(n[-1]) - 1)) for s, l, n in intro_lead]),
                        ("bass", 0.40, intro_bass)] + drums(2, hat=True, kick=True, snare=False))
write("MDA_MUS_victory_intro.wav", intro)

# ---------- victory loop: 4 bars C - G - Am - F, bouncy arps + a hook ----------
CH = [("C", "E", "G"), ("G", "B", "D"), ("A", "C", "E"), ("F", "A", "C")]
hook = [(0, 0.5, "E5"), (0.5, 0.5, "G5"), (1, 1, "C6"), (2, 0.5, "B5"), (2.5, 0.5, "G5"), (3, 1, "E5"),
        (4, 0.5, "D5"), (4.5, 0.5, "G5"), (5, 1, "B5"), (6, 1, "D6"), (7, 1, "B5"),
        (8, 0.5, "C5"), (8.5, 0.5, "E5"), (9, 1, "A5"), (10, 0.5, "G5"), (10.5, 0.5, "E5"), (11, 1, "C5"),
        (12, 0.5, "A4"), (12.5, 0.5, "C5"), (13, 1, "F5"), (14, 0.5, "E5"), (14.5, 0.5, "D5"), (15, 1, "C5")]
loop_bass = []
for i, ch in enumerate(CH):
    r = ch[0]
    o = 2 if r in ("A", "F", "G") else 3
    for j in range(4): loop_bass.append((i * 4 + j, 0.45, r + str(o)))
loop = render(4, 132, [("lead", 0.26, hook), ("lead2", 0.10, arp(CH, 0, 4, [0, 1, 2, 1], [4, 4, 4, 5], 0.25, 0.22)),
                       ("bass", 0.40, loop_bass)] + drums(4))
write("MDA_MUS_victory_loop.wav", loop)

# ---------- defeat loop: 4 bars Am - F - C - E, slow, no drums ----------
DCH = [("A", "C", "E"), ("F", "A", "C"), ("C", "E", "G"), ("E", "G#", "B")]
dlead = [(0, 2, "E5"), (2, 1, "D5"), (3, 1, "C5"), (4, 3, "C5"), (7, 1, "B4"), (8, 2, "G4"), (10, 2, "E5"), (12, 4, "B4")]
dbass = [(i * 4, 3.8, ch[0] + "2") for i, ch in enumerate(DCH)]
defeat = render(4, 76, [("pad", 0.20, dlead), ("lead2", 0.08, arp(DCH, 0, 4, [0, 1, 2, 1], [3, 4, 4, 4], 0.5, 0.45)), ("bass", 0.35, dbass)])
write("MDA_MUS_defeat_loop.wav", defeat)
