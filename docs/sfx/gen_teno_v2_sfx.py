"""Teno ability sounds v2 (round 10, timed to the animation). Sonniss GDC 2026 sources (Music\\MechaDinoArena_SFX\\
_work_teno_sonniss + _work_theri_sonniss, mono 48 kHz FLAC). Same engine as gen_theri_v2_sfx.py. Each move's option is a
SET of parts; each part is scheduled at a stamp (t = 0 of the clip) and its beats are offsets inside it.
Beat sheet: docs/sfx/TENO_BEATS_v1.0.md (TenoMovesServer 1.18, TenoPose 1.13; picks Grab A Scorpion, Mortar A, Stomp A,
Bellow A, Challenge A, Leap A Piston, Shield C Pulse). Parts (schedule point: beats inside the clip):
  grab      wind @ TenoGrabStartedAt: servo + pincer opening 0..0.40 | snap @ TenoGrabCatchAt - 0.15: strike whoosh to 0.15,
            the clamp ON 0.15, lift strain after | throw @ TenoGrabThrowAt(Plan) - 0.15: slam swing to 0.15, release ON 0.15,
            fling whoosh after | land @ TenoGrabLandAt at TenoGrabLand
  mortar    brace @ TenoMortarStartedAt: legs anchor, lock 0.25..0.30, ends at 0.35 | fire @ TenoMortarFiredAt: the BOOM ON 0,
            recoil, casing clink ~0.2 | boom @ TenoMortarLandedAt at TenoMortarLand
  stomp     rear @ TenoStompStartedAt: rise + resonator spin-up 0..0.52 (hang 0.38..0.52), ends at 0.6 | smash @ TenoStompAt
  bellow    inhale @ TenoBellowStartedAt: sacs balloon 0..0.40 | shriek @ TenoBellowStartedAt + 0.40: the shriek ON 0
  challenge call @ TenoChallengeStartedAt: head snap 0 | scan sweep 0.20..0.65 | alarm ON 0.65
  leap      launch @ the lift-off (JUMP leap): rams fire ON 0 | land @ TenoLeapLandedAt: touchdown 0, tail slam ON 0.12
  shield    up @ TenoMudStartedAt: shove 0..0.25, the disc ON 0.20 | loop @ TenoMudCoatAt until TenoMudEndedAt |
            block @ each TenoMudBlockAt | down @ TenoMudEndedAt
Run: python3 gen_teno_v2_sfx.py <src_dir> <out_dir>."""
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



BEDS |= {"Barber_Chair_Foot_Pump", "Spray_Bottle_Spray", "Tower_Deploy_Hitech_Robot_Motor", "Large_Herbivore_Roar_01",
         "Werewolf_Growl", "Raptor_Flair", "Orc_Male_Attack_Long_Heavy", "Cinematic_Horn_Braam_Epic_Cinematic_Dark",
         "Metal_Scrape_Low_Tonal", "Interior_Thunder_Rumble", "VelcroSqueeze01", "Woosh_Sweep_Slide_Infographics",
         "Jump_Start_Drop_3", "Blast_Off_Clean"}
W = "Woosh_Sweep_Slide_Infographics"
SETS = {}
SETS["grab"] = {
    "A": ("Servo pincer: a servo whine and rattle as the pincer opens, a heavy swing into a deep clamp, a whip crack on the release and a rushing fling; the landing is a body slam on a heavy thud", {
        "wind": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.50, at=0.0, gain_db=-1, semis=-3, fout=0.08),
                 dict(name="Flicking_Carabiner_On_Rope", t0=2.66, t1=3.0, at=0.06, gain_db=-5, semis=-3)],
        "snap": [dict(name="Quick_Heavy_Weapon_Swing_To_Thud", t0=0.0, t1=0.62, at=0.15, gain_db=-1, semis=-4),
                 dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.15, gain_db=0, semis=-6),
                 dict(name="Large_Metal_Box_Drag", t0=10.0, t1=10.45, at=0.18, gain_db=-8, semis=-3, fout=0.15)],
        "throw": [dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=0.6, at=0.08, gain_db=-6, semis=-3),
                  dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.7, at=0.15, gain_db=-1, semis=-3),
                  dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.01, at=0.40, gain_db=-8, semis=-2)],
        "land": [dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.0, gain_db=0, semis=-3),
                 dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=2.25, t1=3.17, at=0.0, gain_db=-3, lp=2500)],
    }),
    "B": ("Ratchet claw: a ratchet cranking the tail up, a sword-swing into a sharp crack-snap, a latch clank and a debris whoosh on the throw; the landing is a crunchy smash with a low thump", {
        "wind": [dict(name="Typewriter_Carriage_Movement", t0=0.2, t1=0.6, at=0.0, gain_db=-2, semis=-4, fout=0.08),
                 dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.02, gain_db=-3, semis=-3)],
        "snap": [dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.4, at=0.11, gain_db=-9, semis=-4),
                 dict(name="Cracker_Grab02", t0=0.07, t1=0.4, at=0.15, gain_db=0, semis=-3),
                 dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.15, gain_db=-4, semis=-5),
                 dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.50, at=0.22, gain_db=-9, semis=-6)],
        "throw": [dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.5, at=0.12, gain_db=-2, semis=-4),
                  dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.15, gain_db=-2, semis=-3),
                  dict(name="Woosh_Debris", t0=0.18, t1=1.0, at=0.42, gain_db=-4, semis=-2)],
        "land": [dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=1.05, at=0.0, gain_db=0),
                 dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.8, at=0.0, gain_db=-6, lp=900)],
    }),
    "C": ("Steel trap: a low metal scrape and a screw-lock click winding up, a rush into a spear-thump and a grab, a rattling slam and a case snap on the release; the landing is a creaky bonk with dirt", {
        "wind": [dict(name="Metal_Scrape_Low_Tonal", t0=0.3, t1=0.72, at=0.0, gain_db=-2, fin=0.1, fout=0.08),
                 dict(name="Carabiner_Screwing_Lock", t0=0.20, t1=0.34, at=0.02, gain_db=-3, semis=-3)],
        "snap": [dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.6, at=0.12, gain_db=-5, semis=-2),
                 dict(name="Spear_And_Stick_Impact", t0=0.02, t1=0.22, at=0.15, gain_db=0, semis=-6),
                 dict(name="Grabandrelease30", t0=0.0, t1=0.5, at=0.16, gain_db=-4, semis=-3)],
        "throw": [dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=1.04, at=0.13, gain_db=-1, semis=-3),
                  dict(name="Case_Closed06", t0=0.0, t1=0.27, at=0.15, gain_db=-3, semis=-5),
                  dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.01, at=0.45, gain_db=-6, semis=-3)],
        "land": [dict(name="Cartoon_Airy_Impact_Creaks", t0=0.54, t1=1.50, at=0.0, gain_db=0),
                 dict(name="Woosh_Debris", t0=0.55, t1=1.03, at=0.05, gain_db=-8),
                 dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.0, gain_db=-5)],
    }),
}
SETS["mortar"] = {
    "A": ("Anchored cannon: a hydraulic hiss as the legs anchor and a lock clank, a cannon blast with a ringing metal thud and a casing clink; the landing is a big cinematic boom with rock snapping and rubble", {
        "brace": [dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.55, at=0.0, gain_db=-2, semis=-4, fout=0.04),
                  dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.27, gain_db=0, semis=-7)],
        "fire": [dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.98, at=0.0, gain_db=-1, semis=-3),
                 dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.6, at=0.0, gain_db=-4, lp=700),
                 dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=1.04, at=0.12, gain_db=-5, semis=-5),
                 dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.24, gain_db=-8, semis=3)],
        "boom": [dict(name="EffectiveTrailer_Booms_Vol2_075", t0=0.24, t1=2.4, at=0.0, gain_db=0),
                 dict(name="ice_block_snapping", t0=0.51, t1=1.6, at=0.0, gain_db=-3, semis=-7),
                 dict(name="Woosh_Debris", t0=0.55, t1=1.31, at=0.25, gain_db=-3, semis=-2)],
    }),
    "B": ("Siege gun: a steel drag as it braces and a hard tap, a deep trailer boom with a recoil latch and a stick thump; the landing is a rock crunch over a deep boom", {
        "brace": [dict(name="Large_Metal_Box_Drag", t0=10.0, t1=10.35, at=0.0, gain_db=-1, semis=-3, fout=0.04),
                  dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.28, gain_db=-2, semis=-5)],
        "fire": [dict(name="EffectiveTrailer_Booms_Vol2_214", t0=0.24, t1=1.3, at=0.0, gain_db=0, lp=2500),
                 dict(name="Spear_And_Stick_Impact", t0=0.02, t1=0.22, at=0.0, gain_db=-3, semis=-9),
                 dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.07, gain_db=-4, semis=-4)],
        "boom": [dict(name="block_of_ice_crushed_heavy", t0=0.22, t1=1.66, at=0.0, gain_db=0, semis=-6),
                 dict(name="EffectiveTrailer_Booms_Vol2_011", t0=0.25, t1=2.6, at=0.0, gain_db=-3, lp=1500)],
    }),
    "C": ("Charged turret: a servo with a charge whine and a lock click, a dark heavy slam-shot with a long rush and a case snap; the landing is a crunchy blast with the ground cracking", {
        "brace": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.45, at=0.0, gain_db=-2, semis=-5, fout=0.04),
                  dict(name="ArcPowerUpDesign04", t0=4.4, t1=4.75, at=0.0, gain_db=-8, fin=0.2, fout=0.03),
                  dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.30, gain_db=-2, semis=-5)],
        "fire": [dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=13.28, t1=14.09, at=0.0, gain_db=0),
                 dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.01, at=0.16, gain_db=-3, semis=-5),
                 dict(name="Case_Closed06", t0=0.0, t1=0.27, at=0.22, gain_db=-7, semis=-2)],
        "boom": [dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.98, at=0.0, gain_db=0, semis=-4),
                 dict(name="surface_cracking_fissure", t0=0.30, t1=1.95, at=0.10, gain_db=-5, semis=-4)],
    }),
}
SETS["stomp"] = {
    "A": ("Resonator smash: a servo lifting with a rising resonator whine through the hang, then a metal-foot thud with a low ring, a sub drop and crushed rubble", {
        "rear": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.60, at=0.0, gain_db=-3, semis=-6, fout=0.05),
                 dict(name="ArcPowerUpDesign04", t0=4.0, t1=4.6, at=0.0, gain_db=-4, fin=0.35, fout=0.06)],
        "smash": [dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=2.2, at=0.0, gain_db=0),
                  dict(name="Bass_Drop_Downer_Fast_16", t0=0.08, t1=1.8, at=0.0, gain_db=-3),
                  dict(name="block_of_ice_crushed_heavy", t0=0.22, t1=1.2, at=0.0, gain_db=-4, semis=-6),
                  dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.0, gain_db=-4, semis=-3)],
    }),
    "B": ("Hydraulic quake: a hydraulic pump rising with spinning steel rings, then a deep ground boom with the earth splitting", {
        "rear": [dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.80, at=0.0, gain_db=-2, semis=-6, fout=0.05),
                 dict(name="Metal_Shield_Spin_On_Floor", t0=1.2, t1=1.75, at=0.05, gain_db=-7, semis=-2, fin=0.2, fout=0.05)],
        "smash": [dict(name="EffectiveTrailer_Booms_Vol2_011", t0=0.25, t1=2.5, at=0.0, gain_db=0, lp=2000),
                  dict(name="surface_cracking_fissure", t0=0.30, t1=1.95, at=0.02, gain_db=-4, semis=-5)],
    }),
    "C": ("Steel drum: a grinding steel drag and a selector wheel ticking up, then a dark wooden slam into a thunder rumble", {
        "rear": [dict(name="Large_Metal_Box_Drag", t0=10.0, t1=10.6, at=0.0, gain_db=-2, semis=-3, fout=0.05),
                 dict(name="Mode_Select_Wheel", t0=0.0, t1=0.6, at=0.0, gain_db=-6, semis=-2, fout=0.05)],
        "smash": [dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=20.85, t1=21.77, at=0.0, gain_db=0, semis=-3),
                  dict(name="Interior_Thunder_Rumble", t0=0.6, t1=2.6, at=0.0, gain_db=-3),
                  dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=0.6, at=0.0, gain_db=-5)],
    }),
}
SETS["bellow"] = {
    "A": ("Iron chest: the sacs pumping up with air, then the herbivore roar with a low metal resonance", {
        "inhale": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=-2, semis=-7, fin=0.2, fout=0.05),
                   dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.60, at=0.0, gain_db=-6, semis=-2, fout=0.05)],
        "shriek": [dict(name="Large_Herbivore_Roar_01", t0=0.14, t1=2.2, at=0.0, gain_db=0, fout=0.4, start=True),
                   dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.0, gain_db=-7, semis=-6),
                   dict(name="Metal_Scrape_Low_Tonal", t0=0.3, t1=2.2, at=0.0, gain_db=-9, fout=0.5, start=True)],
    }),
    "B": ("War call: a rushing breath in with leather sacs stretching, then the deeper second roar over a dark war-horn", {
        "inhale": [dict(name="Wind_Whipping_Constricted_Flow", t0=0.0, t1=0.42, at=0.0, gain_db=-3, fin=0.3, fout=0.05),
                   dict(name="VelcroSqueeze01", t0=0.0, t1=0.42, at=0.0, gain_db=-9, semis=-5, fout=0.05)],
        "shriek": [dict(name="Large_Herbivore_Roar_01", t0=4.90, t1=7.0, at=0.0, gain_db=0, semis=-2, fout=0.4, start=True),
                   dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.0, gain_db=-7, semis=-6),
                   dict(name="Cinematic_Horn_Braam_Epic_Cinematic_Dark", t0=0.15, t1=2.2, at=0.0, gain_db=-8, fout=0.5, start=True)],
    }),
    "C": ("Concussion shriek: a cloth-and-air inhale, then a higher, screechier roar with a creature cry on top", {
        "inhale": [dict(name="ClothMovement24", t0=0.07, t1=0.45, at=0.0, gain_db=-3, semis=-6, fout=0.05),
                   dict(name="Wind_Whipping_Constricted_Flow", t0=1.0, t1=1.42, at=0.0, gain_db=-7, fin=0.3, fout=0.05)],
        "shriek": [dict(name="Large_Herbivore_Roar_01", t0=0.14, t1=1.9, at=0.0, gain_db=0, semis=3, fout=0.4, start=True),
                   dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.0, gain_db=-7, semis=-6),
                   dict(name="Raptor_Flair", t0=0.0, t1=1.2, at=0.0, gain_db=-7, semis=-2, fout=0.3, start=True)],
    }),
}
SETS["challenge"] = {
    "A": ("Growl alarm: a click as the head snaps round, a sweeping scan, then a menacing growl-bark with a beacon buzz", {
        "call": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.0, gain_db=-1, semis=-3),
                 dict(name=W, t0=0.0, t1=0.5, at=0.20, gain_db=-4, semis=-3, start=True),
                 dict(name="Werewolf_Growl", t0=0.18, t1=1.5, at=0.65, gain_db=0, semis=-3, fout=0.3, start=True),
                 dict(name="ELECBuzz_Buzz27", t0=1.0, t1=1.5, at=0.65, gain_db=-9, fout=0.2, start=True)],
    }),
    "B": ("Honk alarm: a counter-click snap, a ticking scan wheel, then a sharp herbivore honk with a zap", {
        "call": [dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=0.0, gain_db=-1, semis=-4),
                 dict(name="Mode_Select_Wheel", t0=0.0, t1=0.45, at=0.20, gain_db=-5, semis=-2, start=True),
                 dict(name="Large_Herbivore_Roar_01", t0=4.90, t1=6.2, at=0.65, gain_db=0, semis=3, fout=0.25, start=True),
                 dict(name="ArcDesign15", t0=0.0, t1=0.3, at=0.65, gain_db=-8, start=True)],
    }),
    "C": ("Hoot alarm: a case snap, an airy scan whoosh, then a low dino hoot-call over a heavy grunt", {
        "call": [dict(name="Case_Closed06", t0=0.0, t1=0.27, at=0.0, gain_db=-2, semis=-4),
                 dict(name="Wind_Whipping_Constricted_Flow", t0=2.0, t1=2.45, at=0.20, gain_db=-6, fin=0.15, fout=0.1, start=True),
                 dict(name="Raptor_Flair", t0=0.0, t1=1.4, at=0.65, gain_db=0, semis=-6, fout=0.3, start=True),
                 dict(name="Orc_Male_Attack_Long_Heavy", t0=0.06, t1=1.0, at=0.65, gain_db=-10, semis=-5, lp=1500, start=True)],
    }),
}
SETS["leap"] = {
    "A": ("Piston burst: a servo whine with a steam hiss and a rising bass jump on the lift-off; the landing is a hydraulic squash, then a dark wooden tail slam with dirt", {
        "launch": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.30, t1=0.69, at=0.0, gain_db=-3, semis=-3),
                   dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=-3, semis=-7),
                   dict(name="Jump_Start_Drop_3", t0=0.03, t1=1.2, at=0.0, gain_db=-1, fout=0.3)],
        "land": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.3, at=0.0, gain_db=-6, semis=-9),
                 dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.0, gain_db=-4, semis=-4),
                 dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=27.26, t1=28.07, at=0.12, gain_db=0, semis=-2),
                 dict(name="Woosh_Debris", t0=0.55, t1=1.03, at=0.15, gain_db=-4)],
    }),
    "B": ("Jet rams: a clean jet blast-off with a pump hiss; the landing is a heavy smash and a cinematic boom on the tail slam", {
        "launch": [dict(name="Blast_Off_Clean", t0=3.0, t1=4.2, at=0.0, gain_db=0, fin=0.02, fout=0.3, start=True),
                   dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=-4, semis=-5),
                   dict(name="Barber_Chair_Foot_Pump", t0=0.55, t1=0.85, at=0.0, gain_db=-6, semis=-4)],
        "land": [dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.4, at=0.0, gain_db=-5, lp=1200),
                 dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=1.05, at=0.12, gain_db=-1),
                 dict(name="EffectiveTrailer_Booms_Vol2_214", t0=0.24, t1=1.8, at=0.12, gain_db=-4, lp=1800)],
    }),
    "C": ("Steel spring: a metal-rattle whoosh with a latch kick; the landing is a metal-foot thud, then a low-ring tail slam with crunching rubble", {
        "launch": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.0, gain_db=-2, semis=-6),
                   dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=1.04, at=0.12, gain_db=0, semis=-3),
                   dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.01, at=0.2, gain_db=-5, semis=-4)],
        "land": [dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.0, gain_db=-5, semis=-7),
                 dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=1.6, at=0.12, gain_db=0),
                 dict(name="block_of_ice_crushed_heavy", t0=0.22, t1=1.0, at=0.13, gain_db=-5, semis=-7)],
    }),
}
SETS["shield"] = {
    "A": ("Purple pulse: a charging whine and a pulse whoosh as the disc snaps up with a deep electric hit, a buzzing energy hum while it's up, each block a zap with a metal tick, and a power-down when it ends", {
        "up": [dict(name="ArcPowerUpDesign04", t0=4.55, t1=4.8, at=0.0, gain_db=-6, fin=0.15, fout=0.03),
               dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.6, at=0.12, gain_db=-5, semis=-3),
               dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.6, at=0.20, gain_db=0)],
        "loop": [dict(name="Electricity_Hum_Lightbulb", t0=10.0, t1=11.4, at=0.0, gain_db=-3),
                 dict(name="Scifi_Loop_Ship_Reactor", t0=30.0, t1=31.4, at=0.0, gain_db=-8)],
        "block": [dict(name="ArcDesign15", t0=0.0, t1=0.3, at=0.0, gain_db=0),
                  dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.0, gain_db=-4, semis=-3)],
        "down": [dict(name="ArcPowerUpDesign04", t0=6.6, t1=7.2, at=0.0, gain_db=-2, fout=0.2),
                 dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.25, gain_db=-5, semis=-4)],
    }),
    "B": ("Frost barrier: a shoulder clack and an icy whoosh-snap as the disc forms, a low reactor drone while it's up, each block a ringing clang, and a sinking drop when it ends", {
        "up": [dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=0.0, gain_db=-3, semis=-4),
               dict(name="Skill_Freeze_Whoosh_Break", t0=0.05, t1=0.7, at=0.20, gain_db=0)],
        "loop": [dict(name="Scifi_Loop_Ship_Reactor", t0=12.0, t1=13.4, at=0.0, gain_db=0)],
        "block": [dict(name="METAL_SWING_HIT", t0=0.80, t1=1.25, at=0.0, gain_db=0, semis=-3, fout=0.15),
                  dict(name="ArcDesign15", t0=0.0, t1=0.25, at=0.0, gain_db=-7)],
        "down": [dict(name="Bass_Drop_Downer_Fast_16", t0=0.08, t1=0.8, at=0.0, gain_db=-2, fout=0.2),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.05, gain_db=-8, semis=-7)],
    }),
    "C": ("Spin shield: a shove swing and a vibrating snap-spin as the disc whirls up, a shimmering ring while it's up, each block an ice crack, and the disc shattering when it ends", {
        "up": [dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.32, at=0.10, gain_db=-6, semis=-4),
               dict(name="Vibrato_Impact_Snap_Spin", t0=0.0, t1=0.9, at=0.20, gain_db=0, semis=-2)],
        "loop": [dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=12.0, t1=13.4, at=0.0, gain_db=-2),
                 dict(name="ELECBuzz_Buzz27", t0=3.0, t1=4.4, at=0.0, gain_db=-12)],
        "block": [dict(name="ice_block_snapping", t0=0.51, t1=0.9, at=0.0, gain_db=0, semis=-2),
                  dict(name="Glass_Crystal_Fragments_Sharp", t0=0.21, t1=0.5, at=0.0, gain_db=-8)],
        "down": [dict(name="Glass_Crystal_Fragments_Sharp", t0=0.21, t1=0.9, at=0.0, gain_db=0, semis=-3, fout=0.2, start=True), dict(name="ice_block_snapping", t0=0.51, t1=1.1, at=0.0, gain_db=-4, semis=-5)],
    }),
}
LOOPS = {("shield", "loop"): 1.2}
MAXLEN = {("grab", "wind"): 0.42, ("mortar", "brace"): 0.36, ("stomp", "rear"): 0.62, ("bellow", "inhale"): 0.42,
          ("bellow", "shriek"): 1.6, ("challenge", "call"): 1.9, ("mortar", "boom"): 2.2, ("stomp", "smash"): 2.0,
          ("leap", "land"): 1.6}
meta = {}
for mv, opts in SETS.items():
    for opt, (desc, parts) in opts.items():
        for part, layers in parts.items():
            if (mv, part) in LOOPS:
                y = loop(layers, LOOPS[(mv, part)])
            else:
                y = one_shot(layers, max_len=MAXLEN.get((mv, part)))
            fn = f"MDA_SFX_teno2_{mv}{part}_{opt}.wav"
            sf.write(os.path.join(OUT, fn), y, SR, subtype="PCM_16")
            meta.setdefault(mv, {}).setdefault(opt, {"desc": desc, "parts": {}})["parts"][part] = {
                "file": fn, "len": round(len(y) / SR, 3), "loop": (mv, part) in LOOPS}
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
for mv, opts in meta.items():
    for opt, d in opts.items():
        print(mv, opt, " ".join(f"{p}={v['len']}s{'(loop)' if v['loop'] else ''}" for p, v in d["parts"].items()))
