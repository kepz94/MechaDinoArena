# gen_theri_v2_sfx.py v2.0 (Mecha Dino Arena) — Therizino sound pass round 9 v2 (MDA-552): every part timed to the move beats (TheriPose 1.11, TheriMovesFX2 1.2, storyboard therizino_moves_anim.js v0.5). One-shots peak-align transients on their beat; loops crossfaded. Sources: Sonniss GDC bundle (not in the repo). Usage: python3 gen_theri_v2_sfx.py <src dir> <out dir>
"""Therizino ability sounds v2 (round 9 redo, timed to the animation). Sonniss GDC 2026 sources (Music\\MechaDinoArena_SFX\\
_work_teno_sonniss + _work_theri_sonniss, mono 48 kHz FLAC). Each move's option is a SET of parts; every part starts at a beat
of the move (TheriPose 1.11 / TheriMovesFX2 1.2 / storyboard tools/mockup/therizino_moves_anim.js v0.5), and loop parts are
seamless loops the game stops at the move's end stamp. Beat sheet (t = seconds from the move's stamp):
  reel    brace 0..0.3 | claw flies brace..brace+fly (0.12..0.35) | clamp + winch brace+fly..finish (reel 0.3..0.8) |
          slash at finish (arcs 0.25 s) | claw back finish+0.22..+0.5
          parts: fire @ brace; winch @ brace+fly, stopped at finish; slash @ finish
  vortex  arms up 0..0.4 | stab 0.4..0.52, cracks 0.48..0.75 | sickles out 0.58..0.95 | ring spins 0.95..TheriFieldUntil
          (3 / 4 / 5 s), 6 sickles at 3.2 rad/s = a pass every 0.33 s | sickles back 0.35 s
          parts: start @ 0; loop @ TheriVortexStart (0.95) until TheriFieldUntil; end @ TheriFieldUntil
  bola    whirl at the tail tip 0.05..0.55 | throw (tail whip) 0.45..0.6 | flight TheriBolaFlight | wrap at 0.6 + flight
          parts: throw @ 0; hit @ TheriBolaHitAt (at the target)
  dash    charge arcs 0..0.16 | jolt 0.16..0.16+T (T 0.08..0.16) | landing ring at the jolt's end | skid 0.42..0.6
          parts: dash @ 0
  volley  wind-up (arms cross, fan glows) 0..0.35 | release 0.35..0.48, darts leave 0.42 | flight 0.42..1.02 |
          hits stick at ~1.0 | blades slide back 1.2..1.6
          parts: volley @ 0; hit @ TheriVolleyLandedAt at each hit dino
  deflect collar spins + wall unrolls 0..0.23 | up until TheriDeflectUntil (1 / 1.5 / 2 s) | each block a ripple |
          rolls back 0.3 s
          parts: up @ 0; loop @ 0.15 until TheriDeflectUntil; block @ each TheriDeflectBlockAt; down @ TheriDeflectUntil
Run: python3 gen_theri_v2.py <src_dir> <out_dir>."""
import sys, os, json
import numpy as np, soundfile as sf
from scipy.signal import resample_poly, butter, sosfilt

SR = 48000
PHONE_RMS = -18.0
BASS_MAX_DB = 6.0
SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
_cache = {}


def load(name):
    if name not in _cache:
        x, sr = sf.read(os.path.join(SRC, name + ".flac"))
        assert sr == SR, name
        _cache[name] = x.astype(np.float64)
    return _cache[name]


BEDS = {"Wind_Whipping_Constricted_Flow", "ELECBuzz_Buzz27", "Electricity_Hum_Lightbulb", "Wahl_Sterling_Trimmer",
        "Typewriter_Carriage_Movement", "Tire_Skids_on_Gravel", "Engine_Start_Tires_Skidding", "Large_Metal_Box_Drag",
        "Shimmer_Loop_Small_Bell_Metal_Taps", "ArcPowerUpDesign04", "Scifi_Loop_Ship_Reactor", "Quadcopter_Toy_Flying_Sustained",
        "Metal_Shield_Spin_On_Floor", "ClothMovement24", "ClothMovement29", "Mode_Select_Wheel", "Impact_Electric_Tonal_Deep_Movement",
        "Whoosh_Fire_Deep_Growl"}
ALIGN_PEAK = True  # one-shots: a transient / whoosh layer puts its loudest point ON its beat (`at`); beds start at `at`


def layer(name, t0, t1, at=0.0, gain_db=0.0, semis=0.0, hp=None, lp=None, fin=0.005, fout=0.05, start=False, _peak=None):
    x = load(name)[int(t0 * SR):int(t1 * SR)].copy()
    if semis:
        x = resample_poly(x, 1000, int(round(1000 * 2 ** (semis / 12.0))))
    if hp:
        x = sosfilt(butter(2, hp, "hp", fs=SR, output="sos"), x)
    if lp:
        x = sosfilt(butter(2, lp, "lp", fs=SR, output="sos"), x)
    n = len(x)
    fi, fo = min(n, int(fin * SR)), min(n, int(fout * SR))
    if fi: x[:fi] *= np.linspace(0, 1, fi)
    if fo: x[-fo:] *= np.linspace(1, 0, fo)
    x = x / (np.max(np.abs(x)) + 1e-12) * 10 ** (gain_db / 20.0)
    off = int(at * SR)
    if _peak and not start and name not in BEDS:
        env = np.convolve(np.abs(x), np.ones(int(0.004 * SR)) / int(0.004 * SR), mode="same")
        off -= int(np.argmax(env))
    return off, x


def mixdown(layers, total=None, peak=False):
    placed = []
    for L in layers:
        o, x = layer(**L, _peak=peak and ALIGN_PEAK)
        if o < 0: x, o = x[-o:], 0  # the part before the stamp is dropped (the sound starts at the stamp)
        placed.append((o, x))
    n = max(o + len(x) for o, x in placed)
    if total: n = max(n, int(total * SR))
    y = np.zeros(n)
    for o, x in placed:
        y[o:o + min(len(x), n - o)] += x[:n - o]
    return y


def level(y, peak_db=-1.0):
    y = sosfilt(butter(2, 45, "hp", fs=SR, output="sos"), y)
    lo = sosfilt(butter(4, 200, "lp", fs=SR, output="sos"), y)
    hi = y - lo
    e_lo, e_hi = np.sqrt(np.mean(lo ** 2)) + 1e-12, np.sqrt(np.mean(hi ** 2)) + 1e-12
    if e_lo > e_hi * 10 ** (BASS_MAX_DB / 20.0):
        lo = lo * (e_hi * 10 ** (BASS_MAX_DB / 20.0) / e_lo)
    y = lo + hi
    ph = sosfilt(butter(4, 200, "hp", fs=SR, output="sos"), y)
    y = y * 10 ** ((PHONE_RMS - 20 * np.log10(np.sqrt(np.mean(ph ** 2)) + 1e-12)) / 20.0)
    ceil, knee = 10 ** (peak_db / 20.0), 0.7
    over = np.abs(y) > knee
    y[over] = np.sign(y[over]) * (knee + (ceil - knee) * np.tanh((np.abs(y[over]) - knee) / (ceil - knee)))
    return y


def one_shot(layers, max_len=None, keep_start=True):
    """A one-shot. keep_start: the clip starts at 0 exactly (its beats are offsets from the move's stamp), so the leading
    silence is kept; only the tail is trimmed."""
    y = mixdown(layers, peak=True)
    if max_len:
        y = y[:int(max_len * SR)]
        f = int(0.06 * SR)
        y[-f:] *= np.linspace(1, 0, f)
    y = level(y)
    a = np.where(np.abs(y) > 10 ** (-60 / 20))[0]
    start = 0 if keep_start else max(0, a[0] - int(0.002 * SR))
    return y[start:a[-1] + 1]


def loop(layers, length, xf=0.2):
    """A seamless loop of `length` s: the layers rendered over length + xf, the last xf crossfaded (equal power) into the
    start. Level from the looped body."""
    y = mixdown(layers, total=length + xf)[:int((length + xf) * SR)]
    n, k = int(length * SR), int(xf * SR)
    u = np.linspace(0, 1, k)
    head = y[:k] * np.sin(u * np.pi / 2) + y[n:n + k] * np.cos(u * np.pi / 2)
    y = np.concatenate([head, y[k:n]])
    return level(y)


W = "Woosh_Sweep_Slide_Infographics"
SETS = {}

# ---------------------------------------------------------------- REAPER REEL: fire @ brace, winch @ brace+fly (stopped at finish), slash @ finish
SETS["reel"] = {
    "A": ("Ratchet winch: a launcher thunk and chain rattle, a clamp clank into a fast ratchet winch, a double blade slash and the claw zipping back into the chest", {
        "fire": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.3, at=0.0, gain_db=0, semis=-5),
                 dict(name=W, t0=0.0, t1=0.16, at=0.0, gain_db=-2, semis=-4),
                 dict(name="Flicking_Carabiner_On_Rope", t0=2.66, t1=3.0, at=0.04, gain_db=-4)],
        "winch": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.3, at=0.0, gain_db=0, semis=-7),
                  dict(name="Typewriter_Carriage_Movement", t0=0.2, t1=1.2, at=0.04, gain_db=-1, semis=-5, fout=0.02),
                  dict(name="Wahl_Sterling_Trimmer", t0=2.0, t1=3.0, at=0.0, gain_db=-8, semis=-12, fout=0.02)],
        "slash": [dict(name="Sword_Slide_Cuts_Metallic", t0=0.13, t1=0.55, at=0.0, gain_db=0, semis=-3),
                  dict(name="Sword_Slide_Cuts_Metallic", t0=2.24, t1=2.63, at=0.08, gain_db=-2, semis=-4),
                  dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.02, gain_db=-4, semis=-2),
                  dict(name="Tool_Tape_Measure_Pull_Retract", t0=2.91, t1=3.22, at=0.22, gain_db=-4, semis=-5),
                  dict(name="Case_Closed06", t0=0.0, t1=0.27, at=0.50, gain_db=-5, semis=-4)],
    }),
    "B": ("Servo drum: a mechanical clack and metal whoosh, a claw bite and a whining servo drum, a big sweeping cut and a tape-measure snap back", {
        "fire": [dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=0.0, gain_db=0, semis=-6),
                 dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=0.40, at=0.0, gain_db=-2, semis=-2)],
        "winch": [dict(name="Arrow_Hit_Rattle", t0=0.07, t1=0.45, at=0.0, gain_db=0, semis=-4),
                  dict(name="Wahl_Sterling_Trimmer", t0=2.0, t1=3.0, at=0.02, gain_db=-2, semis=-7, fout=0.02),
                  dict(name="Mode_Select_Wheel", t0=0.0, t1=1.2, at=0.05, gain_db=-6, semis=-3)],
        "slash": [dict(name="Impact_Cut_Sweep", t0=0.89, t1=1.46, at=0.0, gain_db=0),
                  dict(name="Blood_Spill_Splat", t0=0.0, t1=0.28, at=0.03, gain_db=-5, semis=-3),
                  dict(name="Tool_Tape_Measure_Pull_Retract", t0=1.0, t1=1.3, at=0.22, gain_db=-4, semis=-3)],
    }),
    "C": ("Heavy chain: a wooden launcher thump, a metal clamp ting into a grinding chain, a heavy claw hit and the chain rattling back", {
        "fire": [dict(name="Spear_And_Stick_Impact", t0=0.02, t1=0.22, at=0.0, gain_db=0, semis=-9),
                 dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=0.45, at=0.0, gain_db=-3, semis=-3)],
        "winch": [dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.0, gain_db=0, semis=-6),
                  dict(name="Large_Metal_Box_Drag", t0=10.0, t1=11.0, at=0.03, gain_db=-1, semis=4, fout=0.02)],
        "slash": [dict(name="METAL_SWING_HIT", t0=0.05, t1=0.6, at=0.0, gain_db=0, semis=-2),
                  dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=0.5, at=0.03, gain_db=-5),
                  dict(name="Flicking_Carabiner_On_Rope", t0=1.85, t1=2.27, at=0.22, gain_db=-3)],
    }),
}
# ---------------------------------------------------------------- REAPER VORTEX: start @ 0, loop @ 0.95 until FieldUntil, end @ FieldUntil
P = 0.327  # a sickle passes every 0.327 s (6 sickles at 3.2 rad/s)
SETS["vortex"] = {
    "A": ("Spinning steel: wind rising as the arms go up, a heavy slam with the ground cracking at 0.48 s, rattling sickles flying out, then a spinning shield whirl with a blade pass every 0.33 s; the sickles rattle back and clank home", {
        "start": [dict(name="Wind_Whipping_Constricted_Flow", t0=0.0, t1=0.5, at=0.0, gain_db=-7, fin=0.4, fout=0.05),
                  dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=0.6, at=0.46, gain_db=0),
                  dict(name="ice_block_snapping", t0=0.51, t1=1.3, at=0.48, gain_db=-3, semis=-6),
                  dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=0.6, at=0.58, gain_db=-2, semis=-2)],
        "loop": [dict(name="Metal_Shield_Spin_On_Floor", t0=1.2, t1=2.4, at=0.0, gain_db=-4, semis=-3),
                 dict(name="Wind_Whipping_Constricted_Flow", t0=1.0, t1=2.2, at=0.0, gain_db=-9)]
                + [dict(name=W, t0=0.0, t1=0.16, at=i * P, gain_db=-6, semis=-5 - i) for i in range(3)],
        "end": [dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=0.4, at=0.0, gain_db=0, semis=-1),
                dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.3, at=0.33, gain_db=-2, semis=-4)],
    }),
    "B": ("Rotor storm: a motor spinning up, a deep boom with the ground splitting, whooshes as the sickles shoot out, then a deep buzzing rotor with blade cuts every 0.33 s; a whoosh and a clack as they return", {
        "start": [dict(name="Wahl_Sterling_Trimmer", t0=0.0, t1=0.48, at=0.0, gain_db=-5, semis=-7, fout=0.05),
                  dict(name="EffectiveTrailer_Booms_Vol2_011", t0=0.25, t1=1.2, at=0.46, gain_db=0, lp=2500),
                  dict(name="surface_cracking_fissure", t0=0.30, t1=1.1, at=0.48, gain_db=-3, semis=-5)]
                 + [dict(name=W, t0=0.0, t1=0.16, at=0.58 + i * 0.08, gain_db=-3 - i, semis=-2 + i) for i in range(4)],
        "loop": [dict(name="Quadcopter_Toy_Flying_Sustained", t0=2.0, t1=3.2, at=0.0, gain_db=-4, semis=-12, lp=5000)]
                + [dict(name="Sword_Slide_Cuts_Metallic", t0=t0, t1=t0 + 0.3, at=i * P, gain_db=-8, semis=-4)
                   for i, t0 in enumerate([2.24, 4.32, 6.32])],
        "end": [dict(name=W, t0=0.0, t1=0.16, at=0.0, gain_db=0, semis=-3),
                dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=0.32, gain_db=-2, semis=-5)],
    }),
    "C": ("Wind vortex: a deep growling rush, a heavy wooden slam with crushed rock, a blade swing out, then a howling wind loop with heavy swings every 0.33 s; a rush back and a clunk", {
        "start": [dict(name="Whoosh_Fire_Deep_Growl", t0=0.15, t1=0.60, at=0.0, gain_db=-4, fin=0.3),
                  dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=13.28, t1=14.09, at=0.46, gain_db=0, semis=-3),
                  dict(name="block_of_ice_crushed_heavy", t0=0.22, t1=1.2, at=0.48, gain_db=-4, semis=-6),
                  dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.5, at=0.58, gain_db=-2, semis=-4)],
        "loop": [dict(name="Wind_Whipping_Constricted_Flow", t0=3.0, t1=4.2, at=0.0, gain_db=-3)]
                + [dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.32, at=i * P, gain_db=-7, semis=-6) for i in range(3)],
        "end": [dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.6, at=0.0, gain_db=0, semis=-3),
                dict(name="Case_Closed06", t0=0.0, t1=0.27, at=0.33, gain_db=-3, semis=-5)],
    }),
}
# ---------------------------------------------------------------- BOLA: throw @ 0 (whirl 0.05..0.55, whip 0.5), hit @ TheriBolaHitAt
WHIRL = [0.06, 0.22, 0.35, 0.45]
SETS["bola"] = {
    "A": ("Whirl and crack: four whooshes speeding up as it whirls, rope rattling, a whip crack as the tail throws; the catch is a wire cinch, a metal clasp and the raptor tripping", {
        "throw": [dict(name=W, t0=0.0, t1=0.16, at=a, gain_db=-6 + 1.5 * i, semis=-6 + i) for i, a in enumerate(WHIRL)]
                 + [dict(name="Flicking_Carabiner_On_Rope", t0=0.02, t1=0.41, at=0.10, gain_db=-8),
                    dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.70, at=0.50, gain_db=0, semis=-2)],
        "hit": [dict(name="VelcroRip29", t0=0.13, t1=0.27, at=0.0, gain_db=-2, semis=-4),
                dict(name="VelcroRip29", t0=0.13, t1=0.27, at=0.07, gain_db=-4, semis=-6),
                dict(name="Carabiner_Screwing_Lock", t0=0.20, t1=0.34, at=0.10, gain_db=-4, semis=-2),
                dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.14, gain_db=-1, semis=-4)],
    }),
    "B": ("Heavy weights: heavy swings speeding up, the rope snapping out, a long throw whoosh; the catch is a strap buckling shut and a thud", {
        "throw": [dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.32, at=a, gain_db=-6 + 1.5 * i, semis=-7 + i) for i, a in enumerate(WHIRL)]
                 + [dict(name="Flicking_Carabiner_On_Rope", t0=0.90, t1=1.27, at=0.48, gain_db=-3),
                    dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.8, at=0.52, gain_db=-1, semis=-3)],
        "hit": [dict(name="Suitcase_Being_Locked", t0=1.03, t1=1.50, at=0.0, gain_db=0, semis=-3),
                dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.12, gain_db=-2, semis=-5)],
    }),
    "C": ("Rope rattle: the weighted rope rattling round, a snap and a rush of air as it's thrown; the catch is a whip-wrap crack, a cloth snap and a body hit", {
        "throw": [dict(name="Flicking_Carabiner_On_Rope", t0=t0, t1=t0 + 0.32, at=a, gain_db=-5 + 1.5 * i, semis=-3 + i)
                  for i, (a, t0) in enumerate(zip(WHIRL, [0.02, 0.90, 1.85, 2.66]))]
                 + [dict(name="Cracker_Grab02", t0=0.07, t1=0.49, at=0.50, gain_db=-2, semis=-4),
                    dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.8, at=0.53, gain_db=-1, semis=-2)],
        "hit": [dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.55, at=0.0, gain_db=-1, semis=-4),
                dict(name="ClothMovement29", t0=0.03, t1=0.4, at=0.04, gain_db=-5),
                dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.13, gain_db=-2, semis=-5)],
    }),
}
# ---------------------------------------------------------------- DASH (Storm Core): charge 0..0.16, jolt 0.16, landing 0.3, skid 0.42
SETS["dash"] = {
    "A": ("Thunder jolt: an electric buzz charging up, a real thunder crack at the jolt, a zap on landing and a gravel skid", {
        "dash": [dict(name="ELECBuzz_Buzz27", t0=1.0, t1=1.17, at=0.0, gain_db=-6, fin=0.15, fout=0.01),
                 dict(name="ArcDesign15", t0=0.0, t1=0.16, at=0.02, gain_db=-6),
                 dict(name="Texas_Rain_Thunder_Initial_Crash", t0=3.22, t1=4.0, at=0.16, gain_db=0, fout=0.3),
                 dict(name=W, t0=0.0, t1=0.16, at=0.16, gain_db=-4, semis=-2),
                 dict(name="ArcDesign15", t0=0.0, t1=0.5, at=0.29, gain_db=-4),
                 dict(name="Tire_Skids_on_Gravel", t0=1.75, t1=2.35, at=0.42, gain_db=-5, fin=0.03, fout=0.15)],
    }),
    "B": ("Electric burst: a deep electric hiss charging, an engine-fast whoosh at the jolt, a metal thud landing and a skid", {
        "dash": [dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.18, at=0.0, gain_db=-3, fin=0.1, fout=0.01),
                 dict(name="Kawasaki_Ninja_ZX_10R_Pass_By_Fast", t0=5.0, t1=5.6, at=0.16, gain_db=0, semis=4, fin=0.02, fout=0.2),
                 dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.5, at=0.29, gain_db=-3),
                 dict(name="Engine_Start_Tires_Skidding", t0=2.55, t1=3.1, at=0.42, gain_db=-5, fin=0.03, fout=0.15)],
    }),
    "C": ("Icy snap: a crackling charge, an icy whoosh-snap at the jolt, a crunchy landing and a gravel skid", {
        "dash": [dict(name="ArcDesign15", t0=0.0, t1=0.16, at=0.0, gain_db=-3, fin=0.1),
                 dict(name="Skill_Freeze_Whoosh_Break", t0=0.05, t1=0.6, at=0.16, gain_db=0, fout=0.2),
                 dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=0.4, at=0.29, gain_db=-4),
                 dict(name="Tire_Skids_on_Gravel", t0=1.75, t1=2.35, at=0.42, gain_db=-5, fin=0.03, fout=0.15)],
    }),
}
# ---------------------------------------------------------------- WING VOLLEY: wind-up 0..0.35, darts 0.42, blades back 1.2; hit @ each landed dart
SETS["volley"] = {
    "A": ("Charged swarm: feathers rustling with a rising charge, a wing snap and a swarm of darts at 0.42 s, the blades sliding back at 1.2 s; each hit is a dart thunking in with a rattle", {
        "volley": [dict(name="ClothMovement24", t0=0.07, t1=0.42, at=0.0, gain_db=-4, semis=-3),
                   dict(name="ArcPowerUpDesign04", t0=4.4, t1=4.8, at=0.0, gain_db=-9, fin=0.3, fout=0.02),
                   dict(name="SinglePats04", t0=0.06, t1=0.28, at=0.38, gain_db=-2, semis=-6)]
                  + [dict(name=W, t0=0.0, t1=0.16, at=0.42 + d, gain_db=-1 - 1.5 * i, semis=-2 + i) for i, d in enumerate([0, 0.04, 0.09, 0.15])]
                  + [dict(name="Glass_Crystal_Fragments_Sharp", t0=0.21, t1=0.9, at=0.42, gain_db=-7, semis=-5),
                     dict(name="Sword_Slide_Cuts_Metallic", t0=6.32, t1=6.72, at=1.2, gain_db=-8, semis=-3)],
        "hit": [dict(name="Arrow_Hit_Rattle", t0=0.07, t1=0.6, at=0.0, gain_db=0, semis=-2)],
    }),
    "B": ("Blade swish: a wing snap and a layered blade-swish volley at 0.42 s, a mechanical clack as the blades reseat; each hit is a wooden thunk with a metal tick", {
        "volley": [dict(name="ClothMovement29", t0=0.03, t1=0.38, at=0.0, gain_db=-3, semis=-2),
                   dict(name="Action_Deploy_Units_Sword_Slice", t0=0.17, t1=1.0, at=0.40, gain_db=0, semis=-2),
                   dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=1.25, gain_db=-6, semis=-3)],
        "hit": [dict(name="Spear_And_Stick_Impact", t0=0.62, t1=0.86, at=0.0, gain_db=0, semis=-3),
                dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.30, at=0.0, gain_db=-6, semis=-2)],
    }),
    "C": ("Wing flaps: two heavy wing flaps winding up, a feather burst at 0.42 s, a tape-measure zip as the blades slide back; each hit is a sharp snap with a thud", {
        "volley": [dict(name="SinglePats04", t0=0.06, t1=0.28, at=0.06, gain_db=-2, semis=-6),
                   dict(name="SinglePats04", t0=0.06, t1=0.28, at=0.24, gain_db=-1, semis=-7),
                   dict(name="Cofetti_Whoosh_Pluck_Spill", t0=0.10, t1=1.10, at=0.40, gain_db=0, semis=-3),
                   dict(name="Tool_Tape_Measure_Pull_Retract", t0=2.91, t1=3.22, at=1.2, gain_db=-6, semis=-4)],
        "hit": [dict(name="Cracker_Grab02", t0=0.07, t1=0.40, at=0.0, gain_db=0, semis=-3),
                dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.0, gain_db=-5, semis=-2)],
    }),
}
# ---------------------------------------------------------------- DEFLECTOR (Shield Wall): up @ 0, loop 0.15..Until, block @ each block, down @ Until
SETS["deflect"] = {
    "A": ("Energy wall: the collar whirs up and an energy surge unrolls the wall, a humming wall with shimmering taps while it's up, each block a ringing clang with a zap, and a short power-down as it rolls back", {
        "up": [dict(name="Wahl_Sterling_Trimmer", t0=0.0, t1=0.3, at=0.0, gain_db=-5, semis=-3, fout=0.1),
               dict(name="ArcPowerUpDesign04", t0=4.6, t1=5.0, at=0.02, gain_db=0, fout=0.1),
               dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=4.0, t1=4.4, at=0.05, gain_db=-6, fout=0.15)],
        "loop": [dict(name="Electricity_Hum_Lightbulb", t0=10.0, t1=11.2, at=0.0, gain_db=-3),
                 dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=8.0, t1=9.2, at=0.0, gain_db=-10)],
        "block": [dict(name="METAL_SWING_HIT", t0=0.80, t1=1.3, at=0.0, gain_db=0, semis=-3, fout=0.18),
                  dict(name="ArcDesign15", t0=0.0, t1=0.3, at=0.0, gain_db=-4)],
        "down": [dict(name="ArcPowerUpDesign04", t0=6.6, t1=7.2, at=0.0, gain_db=-2, fout=0.2),
                 dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=0.28, gain_db=-4, semis=-4)],
    }),
    "B": ("Steel shutter: a ratchet unrolling a steel wall with a clang, a deep reactor hum while it's up, each block a metal ting with a rattle, and the ratchet rolling it back with a clunk", {
        "up": [dict(name="Typewriter_Carriage_Movement", t0=0.2, t1=0.45, at=0.0, gain_db=-2, semis=-3),
               dict(name="Metal_Shield_Spin_On_Floor", t0=0.42, t1=0.75, at=0.15, gain_db=0, semis=-2)],
        "loop": [dict(name="Scifi_Loop_Ship_Reactor", t0=30.0, t1=31.2, at=0.0, gain_db=0)],
        "block": [dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.0, gain_db=0, semis=-3),
                  dict(name="Arrow_Hit_Rattle", t0=0.07, t1=0.6, at=0.0, gain_db=-4, semis=-3)],
        "down": [dict(name="Typewriter_Carriage_Movement", t0=1.9, t1=2.2, at=0.0, gain_db=-2, semis=-3),
                 dict(name="Case_Closed06", t0=0.0, t1=0.27, at=0.28, gain_db=-2, semis=-4)],
    }),
    "C": ("Crystal wall: an icy whoosh as a crystal wall forms, a glassy shimmer while it's up, each block a sharp ice crack with a ting, and shards falling as it goes", {
        "up": [dict(name="Skill_Freeze_Whoosh_Break", t0=0.05, t1=0.5, at=0.0, gain_db=0, fout=0.15)],
        "loop": [dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=12.0, t1=13.2, at=0.0, gain_db=-1),
                 dict(name="ELECBuzz_Buzz27", t0=3.0, t1=4.2, at=0.0, gain_db=-12)],
        "block": [dict(name="ice_block_snapping", t0=0.51, t1=0.9, at=0.0, gain_db=0, semis=-3),
                  dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.0, gain_db=-4)],
        "down": [dict(name="Glass_Crystal_Fragments_Sharp", t0=0.21, t1=0.8, at=0.0, gain_db=0, semis=-3, fout=0.2)],
    }),
}

LOOPS = {("vortex", "loop"): 3 * P, ("deflect", "loop"): 1.2}
MAXLEN = {("vortex", "start"): 1.15}  # hands over to the loop at 0.95 (60 ms fade at the end)
meta = {}
for mv, opts in SETS.items():
    for opt, (desc, parts) in opts.items():
        for part, layers in parts.items():
            if (mv, part) in LOOPS:
                y = loop(layers, LOOPS[(mv, part)])
            else:
                y = one_shot(layers, max_len=MAXLEN.get((mv, part)))
            fn = f"MDA_SFX_theri_{mv}{part}_{opt}.wav"
            sf.write(os.path.join(OUT, fn), y, SR, subtype="PCM_16")
            meta.setdefault(mv, {}).setdefault(opt, {"desc": desc, "parts": {}})["parts"][part] = {
                "file": fn, "len": round(len(y) / SR, 3), "loop": (mv, part) in LOOPS}
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
for mv, opts in meta.items():
    for opt, d in opts.items():
        print(mv, opt, " ".join(f"{p}={v['len']}s{'(loop)' if v['loop'] else ''}" for p, v in d["parts"].items()))
