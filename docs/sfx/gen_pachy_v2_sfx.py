"""Pachy ability sounds v2 (round 11, timed to the animation). Sonniss GDC 2026 sources, same engine as
gen_theri_v2_sfx.py. Each move's option is a SET of parts; each part is scheduled at a stamp (t = 0 of the clip) and its
beats are offsets inside it. Beat sheet: docs/sfx/PACHY_BEATS_v1.0.md (the game plays the A versions of every move).
  hook   fire @ HookLaunchAt - 0.15: brace 0..0.15, the shot ON 0.15, chain paying out after | reel @ HookContactAt: the
         clamp ON 0, the winch, cut at HookSmashAt (the head smash keeps HookFX's sound)
  dash   blast @ ServoDashBlastAt - 0.06: squat 0..0.06, BLAST ON 0.06 | burn (loop) BlastAt + 0.25 .. ServoDashUntil |
         skid @ ServoDashUntil
  visor  up @ VisorStartedAt: panels slam ON 0.10 | field (loop) +0.10 .. VisorUntil | block @ VisorBlockAt | down @ VisorUntil
  ink    fire @ InkFireAt - 0.10: pump 0..0.10, the shot ON 0.10 | splat @ InkArriveAt at InkAimEnd
  tether cock @ the aim start | throw @ TetherStartedAt: the whip ON 0 | land @ TetherLandAt at TetherAnchor
  blood  pact @ HeadbuttSacrificeAt: the jolt ON 0, roar + vial spray inside the 0.15 s wind-up
  med    drop @ MedDroppedAt: pop 0, the thud ON 0.30, unfolding to 0.6 | hum (loop) +0.6 .. MedActiveUntil | fold @ MedActiveUntil
  headbutt windup @ HeadbuttStartedAt: snort / scrape 0..0.15, the rush off the line from 0.15 | charge (loop) +0.15 ..
         HeadbuttHitAt or HeadbuttEndedAt | hit @ HeadbuttHitAt: the CRUNCH ON 0, the head-shake ~0.6
  leap   launch @ JumpStartedAt + JumpWindup (the pistons fire ON 0) | double @ JumpDoubleAt (own: JumpDoublePredictedAt) |
         land @ the touchdown (absorb ON 0, steam after)
Run: python3 gen_pachy_v2_sfx.py <src_dir> <out_dir>."""
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



BEDS |= {"Barber_Chair_Foot_Pump", "Spray_Bottle_Spray", "Tower_Deploy_Hitech_Robot_Motor", "Typewriter_Carriage_Movement",
         "Tool_Tape_Measure_Pull_Retract", "Kawasaki_Ninja_ZX_10R_Pass_By_Fast", "Engine_Start_Tires_Skidding",
         "Large_Herbivore_Roar_01", "Werewolf_Growl", "ANMLRept_T_Rex", "Aquatic_Creature_Gurgling", "Blast_Off_Clean",
         "Jump_Start_Drop_3", "Suitcase_Being_Locked"}
SETS = {}
SETS["hook"] = {
    "A": ("Chain claw: a hydraulic brace, a whip-crack shot and the chain rattling out; a heavy latch clamps on and a ratchet winch hauls", {
        "fire": [dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.36, at=0.0, gain_db=-6, semis=-3, fout=0.03),
                 dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.6, at=0.15, gain_db=0, semis=-2),
                 dict(name="Flicking_Carabiner_On_Rope", t0=2.66, t1=3.2, at=0.20, gain_db=-5, semis=-2, start=True)],
        "reel": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.0, gain_db=0, semis=-3),
                 dict(name="Typewriter_Carriage_Movement", t0=0.2, t1=1.0, at=0.03, gain_db=-3, semis=-3),
                 dict(name="Large_Metal_Box_Drag", t0=10.0, t1=10.8, at=0.03, gain_db=-9, semis=-2)],
    }),
    "B": ("Harpoon: a click, a sharp crack-snap launch with a rushing whoosh; a grab-clamp and a tape-reel whir pulling in", {
        "fire": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.02, gain_db=-5, semis=-2),
                 dict(name="Cracker_Grab02", t0=0.07, t1=0.4, at=0.15, gain_db=0, semis=-4),
                 dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.7, at=0.30, gain_db=-5, semis=1)],
        "reel": [dict(name="Grabandrelease30", t0=0.0, t1=0.5, at=0.0, gain_db=-1, semis=-3),
                 dict(name="Tool_Tape_Measure_Pull_Retract", t0=1.6, t1=2.4, at=0.02, gain_db=-2, semis=-5)],
    }),
    "C": ("Grapple gun: a motor spin-up, a gun-pop with an arrow rattle; a metal tap clamp and a motor whine reeling in", {
        "fire": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.26, at=0.0, gain_db=-11, semis=-2, fout=0.02),
                 dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.5, at=0.15, gain_db=-3, semis=5),
                 dict(name="Arrow_Hit_Rattle", t0=0.20, t1=1.0, at=0.24, gain_db=-4, semis=-3)],
        "reel": [dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.0, gain_db=0, semis=-4),
                 dict(name="Wahl_Sterling_Trimmer", t0=0.5, t1=1.3, at=0.02, gain_db=-4, semis=-5),
                 dict(name="Flicking_Carabiner_On_Rope", t0=2.66, t1=3.2, at=0.05, gain_db=-8, semis=-4, start=True)],
    }),
}
SETS["dash"] = {
    "A": ("Hip rockets: a short charge whine, a rocket BLAST with a crack, a roaring reactor burn while it sprints, a gravel skid with a steam hiss", {
        "blast": [dict(name="ArcPowerUpDesign04", t0=4.48, t1=4.56, at=0.0, gain_db=-8, fin=0.05, fout=0.01),
                  dict(name="Blast_Off_Clean", t0=3.0, t1=3.9, at=0.06, gain_db=0, fin=0.01, fout=0.2, start=True),
                  dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.6, at=0.06, gain_db=-5, semis=2)],
        "burn": [dict(name="Scifi_Loop_Ship_Reactor", t0=20.0, t1=21.4, at=0.0, gain_db=-1),
                 dict(name="Wind_Whipping_Constricted_Flow", t0=1.0, t1=2.4, at=0.0, gain_db=-6)],
        "skid": [dict(name="Tire_Skids_on_Gravel", t0=1.75, t1=2.3, at=0.0, gain_db=0, semis=-3, start=True, fout=0.12),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.05, gain_db=-5, semis=-6)],
    }),
    "B": ("Jet hop: a latch click, a bass-jump blast with steam, a buzzy jet whine while it sprints, a metal scrape stop", {
        "blast": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.0, gain_db=-4, semis=-2),
                  dict(name="Jump_Start_Drop_3", t0=0.03, t1=1.0, at=0.06, gain_db=0, fout=0.25, start=True),
                  dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.06, gain_db=-4, semis=-4)],
        "burn": [dict(name="Quadcopter_Toy_Flying_Sustained", t0=2.0, t1=3.4, at=0.0, gain_db=-2, semis=-7)],
        "skid": [dict(name="Large_Metal_Box_Drag", t0=10.0, t1=10.5, at=0.0, gain_db=0, semis=-2, start=True, fout=0.12),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=-6, semis=-7)],
    }),
    "C": ("Motor sprint: a fiery whoosh-roar off the line, a racing engine pass while it sprints, a tire screech stop", {
        "blast": [dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.27, at=0.0, gain_db=-6, semis=-3, fout=0.01),
                  dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.6, at=0.06, gain_db=-2, semis=-2),
                  dict(name="Whoosh_Fire_Deep_Growl", t0=0.0, t1=1.0, at=0.08, gain_db=-3)],
        "burn": [dict(name="Kawasaki_Ninja_ZX_10R_Pass_By_Fast", t0=4.4, t1=5.8, at=0.0, gain_db=-1, semis=-5)],
        "skid": [dict(name="Engine_Start_Tires_Skidding", t0=12.7, t1=13.3, at=0.0, gain_db=0, semis=-3, start=True, fout=0.15)],
    }),
}
SETS["visor"] = {
    "A": ("Steel panels: a mechanism click as it tucks, panels clanking shut with a zap, an electric hum while braced, each block a ringing clang, and a click-down when it folds away", {
        "up": [dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=0.0, gain_db=-3, semis=-3),
               dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.10, gain_db=0, semis=-3),
               dict(name="ArcDesign15", t0=0.0, t1=0.3, at=0.10, gain_db=-5)],
        "field": [dict(name="Electricity_Hum_Lightbulb", t0=20.0, t1=21.4, at=0.0, gain_db=-3)],
        "block": [dict(name="METAL_SWING_HIT", t0=0.80, t1=1.25, at=0.0, gain_db=0, semis=-2, fout=0.15),
                  dict(name="ArcDesign15", t0=0.0, t1=0.25, at=0.0, gain_db=-6)],
        "down": [dict(name="ArcPowerUpDesign04", t0=6.6, t1=7.0, at=0.0, gain_db=-3, fout=0.15),
                 dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.15, gain_db=-3, semis=-3)],
    }),
    "B": ("Energy dome: a deep electric hit as the field grows, a shimmering bell ring while it holds, each block a zap with an electric thump, and a sinking drop", {
        "up": [dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.6, at=0.10, gain_db=0)],
        "field": [dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=20.0, t1=21.4, at=0.0, gain_db=-2)],
        "block": [dict(name="ArcDesign15", t0=0.0, t1=0.3, at=0.0, gain_db=0),
                  dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.3, at=0.0, gain_db=-5)],
        "down": [dict(name="Bass_Drop_Downer_Fast_16", t0=0.08, t1=0.7, at=0.0, gain_db=-2, fout=0.2, start=True)],
    }),
    "C": ("Frost guard: a case-snap and an icy whoosh-break, a low reactor drone, each block a spear thump with glass, and a mechanism click-off", {
        "up": [dict(name="Case_Closed06", t0=0.0, t1=0.27, at=0.10, gain_db=-1, semis=-3),
               dict(name="Skill_Freeze_Whoosh_Break", t0=0.05, t1=0.6, at=0.10, gain_db=-3)],
        "field": [dict(name="Scifi_Loop_Ship_Reactor", t0=34.0, t1=35.4, at=0.0, gain_db=0, semis=3)],
        "block": [dict(name="Spear_And_Stick_Impact", t0=0.02, t1=0.22, at=0.0, gain_db=0, semis=-4),
                  dict(name="Glass_Crystal_Fragments_Sharp", t0=0.21, t1=0.5, at=0.0, gain_db=-7)],
        "down": [dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=0.0, gain_db=-1, semis=-5)],
    }),
}
SETS["ink"] = {
    "A": ("Squid cannon: a pump hiss, a wet pop-blast with a spray; the hit is a thick splat with bubbles", {
        "fire": [dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.30, at=0.0, gain_db=-4, semis=-2, fout=0.01),
                 dict(name="Cracker_Grab02", t0=0.07, t1=0.4, at=0.10, gain_db=0, semis=-6),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.10, gain_db=-3, semis=-5, start=True)],
        "splat": [dict(name="Blood_Spill_Splat", t0=0.0, t1=0.33, at=0.0, gain_db=0, semis=-3),
                  dict(name="Liquid_Impact_Bubble", t0=0.14, t1=0.9, at=0.0, gain_db=-4, semis=-2)],
    }),
    "B": ("Goo mortar: two quick pumps, a deep wet thump; the hit is a deep water slap with a gurgle", {
        "fire": [dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.26, at=0.0, gain_db=-5, semis=-2, fout=0.01),
                 dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.26, at=0.05, gain_db=-5, semis=0, fout=0.01),
                 dict(name="Impact_Water_Deep_Submerge", t0=0.03, t1=0.7, at=0.10, gain_db=0, semis=4)],
        "splat": [dict(name="Impact_Water_Deep_Submerge", t0=0.03, t1=0.8, at=0.0, gain_db=0, semis=2),
                  dict(name="Aquatic_Creature_Gurgling", t0=1.2, t1=1.7, at=0.05, gain_db=-8)],
    }),
    "C": ("Oil gun: a latch click, a sharp gun pop with a squirt; the hit is a meaty squelch with bubbles", {
        "fire": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.0, gain_db=-4, semis=-2),
                 dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.5, at=0.10, gain_db=-2, semis=6),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.3, at=0.10, gain_db=-5, semis=-3, start=True)],
        "splat": [dict(name="Dinosaur_Eating_Meat_01", t0=6.6, t1=7.1, at=0.0, gain_db=0),
                  dict(name="Cartoon_Bubbles_Short", t0=0.0, t1=0.8, at=0.06, gain_db=-8, semis=-4)],
    }),
}
SETS["tether"] = {
    "A": ("Chain sling: a ratchet as the tail cocks, a whip crack with a chain rattle on the throw; the spike thunks in and the chain snaps tight", {
        "cock": [dict(name="Typewriter_Carriage_Movement", t0=0.2, t1=0.55, at=0.0, gain_db=-3, semis=-2),
                 dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.32, gain_db=-3, semis=-1)],
        "throw": [dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.6, at=0.0, gain_db=0, semis=-3),
                  dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=0.8, at=0.15, gain_db=-5, semis=-2)],
        "land": [dict(name="Spear_And_Stick_Impact", t0=0.02, t1=0.22, at=0.0, gain_db=0, semis=-4),
                 dict(name="Flicking_Carabiner_On_Rope", t0=2.66, t1=3.2, at=0.08, gain_db=-6, semis=-2),
                 dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.30, gain_db=-13, semis=-2)],
    }),
    "B": ("Spike launcher: a screw-lock wind-up, a launcher thump with a rush; a heavy metal thud with the chain clinking", {
        "cock": [dict(name="Carabiner_Screwing_Lock", t0=0.10, t1=0.4, at=0.0, gain_db=-2, semis=-2)],
        "throw": [dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.0, gain_db=0, semis=-6),
                  dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.8, at=0.20, gain_db=-5, semis=-1)],
        "land": [dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.8, at=0.0, gain_db=0, lp=1500),
                 dict(name="Flicking_Carabiner_On_Rope", t0=2.66, t1=3.2, at=0.06, gain_db=-5, semis=-3)],
    }),
    "C": ("Tail flick: a motor whir as it aims, a quick sword-swing flick with a chain jingle; an arrow-thunk with a rattle and a lock click", {
        "cock": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.45, at=0.0, gain_db=-4, semis=-4)],
        "throw": [dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.4, at=0.0, gain_db=0, semis=-2),
                  dict(name="Flicking_Carabiner_On_Rope", t0=2.66, t1=3.2, at=0.06, gain_db=-5)],
        "land": [dict(name="Arrow_Hit_Rattle", t0=0.20, t1=1.0, at=0.0, gain_db=0, semis=-4),
                 dict(name="Suitcase_Being_Locked", t0=2.1, t1=2.5, at=0.25, gain_db=-4)],
    }),
}
SETS["blood"] = {
    "A": ("Blood pact: a body jolt, a short roar and the vials spraying out", {
        "pact": [dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.0, gain_db=-2, semis=-4),
                 dict(name="Large_Herbivore_Roar_01", t0=0.14, t1=1.0, at=0.02, gain_db=0, semis=3, fout=0.25, start=True),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.04, gain_db=-4, semis=-3, start=True),
                 dict(name="Blood_Spill_Splat", t0=0.0, t1=0.33, at=0.08, gain_db=-6)],
    }),
    "B": ("Heart pump: three hard heartbeats, a pressure hiss and a growl", {
        "pact": [dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.25, at=0.0, gain_db=0, lp=350),
                 dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.25, at=0.07, gain_db=-1, lp=350),
                 dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.25, at=0.14, gain_db=0, lp=350),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.05, gain_db=-7, semis=-6, start=True),
                 dict(name="Werewolf_Growl", t0=0.18, t1=1.0, at=0.12, gain_db=-3, semis=-2, fout=0.25, start=True)],
    }),
    "C": ("Red snort: a wet snort spray, a stomp, and a reptile snarl", {
        "pact": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.3, at=0.0, gain_db=-1, semis=-8, start=True),
                 dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.10, gain_db=0, semis=-5),
                 dict(name="ANMLRept_T_Rex", t0=4.6, t1=5.6, at=0.06, gain_db=-3, semis=2, fout=0.25, start=True)],
    }),
}
SETS["med"] = {
    "A": ("Capsule drop: a pop as it ejects, a thud and a motor whir as it unfolds, a soft bell shimmer with a pulse every second while it heals, and a whir-click as it folds away", {
        "drop": [dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=0.0, gain_db=-2, semis=-2),
                 dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.30, gain_db=0, semis=-5),
                 dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.55, at=0.32, gain_db=-3, semis=2)],
        "hum": [dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=30.0, t1=31.4, at=0.0, gain_db=-4),
                dict(name="ArcDesign15", t0=0.0, t1=0.3, at=0.0, gain_db=-9)],
        "fold": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.50, at=0.0, gain_db=-2, semis=-4),
                 dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.32, gain_db=-3, semis=-1)],
    }),
    "B": ("Stomp plant: a click, a metal tap landing, a rising power whine, a warm reactor hum with a zap pulse, and a sinking drop", {
        "drop": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.0, gain_db=-3, semis=0),
                 dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.30, gain_db=0, semis=-3),
                 dict(name="ArcPowerUpDesign04", t0=4.2, t1=4.6, at=0.32, gain_db=-4, start=True, fout=0.05)],
        "hum": [dict(name="Scifi_Loop_Ship_Reactor", t0=36.0, t1=37.4, at=0.0, gain_db=-5),
                dict(name="ArcDesign15", t0=0.0, t1=0.3, at=0.0, gain_db=-6)],
        "fold": [dict(name="Bass_Drop_Downer_Fast_16", t0=0.08, t1=0.7, at=0.0, gain_db=-3, fout=0.2, start=True)],
    }),
    "C": ("Pod unfold: a case snap, a low ringing thud, a bubbling heal-tank hum, and a suitcase lock as it closes", {
        "drop": [dict(name="Case_Closed06", t0=0.0, t1=0.27, at=0.0, gain_db=-2, semis=-1),
                 dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.7, at=0.30, gain_db=0, lp=1200),
                 dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.21, at=0.42, gain_db=-5, semis=3)],
        "hum": [dict(name="Electricity_Hum_Lightbulb", t0=30.0, t1=31.4, at=0.0, gain_db=-6),
                dict(name="Cartoon_Bubbles_Short", t0=0.0, t1=0.8, at=0.0, gain_db=-10, semis=-6)],
        "fold": [dict(name="Suitcase_Being_Locked", t0=2.0, t1=2.6, at=0.0, gain_db=-1, start=True)],
    }),
}

SETS["headbutt"] = {
    "A": ("Bull charge: a wet snort and a foot scrape, a rush off the line, pounding hoof-thuds with wind while it charges; the hit is a ringing dome clang with a bone crunch, then a rattling head-shake", {
        "windup": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.2, at=0.0, gain_db=-2, semis=-9, start=True),
                   dict(name="Large_Metal_Box_Drag", t0=10.0, t1=10.12, at=0.04, gain_db=-6, semis=-2, start=True),
                   dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.5, at=0.22, gain_db=-5, semis=-3)],
        "charge": [dict(name="Punch_Body_02", t0=0.16, t1=0.40, at=0.0, gain_db=0, semis=-8),
                   dict(name="Punch_Body_02", t0=0.16, t1=0.40, at=0.15, gain_db=-2, semis=-7),
                   dict(name="Punch_Body_02", t0=0.16, t1=0.40, at=0.30, gain_db=0, semis=-8),
                   dict(name="Punch_Body_02", t0=0.16, t1=0.40, at=0.45, gain_db=-2, semis=-7),
                   dict(name="Wind_Whipping_Constricted_Flow", t0=3.0, t1=3.8, at=0.0, gain_db=-9)],
        "hit": [dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.9, at=0.0, gain_db=0),
                dict(name="block_of_ice_crushed_heavy", t0=0.22, t1=0.8, at=0.0, gain_db=-3, semis=-5),
                dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=0.6, at=0.62, gain_db=-8, semis=-3)],
    }),
    "B": ("Ram: a low growl and a latch click, a grinding rumble under heavy steps while it charges; the hit is a dark wooden slam with a gore crunch, then a chain-rattle shake", {
        "windup": [dict(name="Werewolf_Growl", t0=0.18, t1=0.45, at=0.0, gain_db=-2, semis=-4, start=True, fout=0.05),
                   dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.12, gain_db=-4, semis=-4)],
        "charge": [dict(name="Large_Metal_Box_Drag", t0=11.0, t1=11.8, at=0.0, gain_db=-5, semis=-4),
                   dict(name="Punch_Body_02", t0=1.13, t1=1.40, at=0.0, gain_db=0, semis=-9),
                   dict(name="Punch_Body_02", t0=1.13, t1=1.40, at=0.30, gain_db=0, semis=-9)],
        "hit": [dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=2.25, t1=3.17, at=0.0, gain_db=0),
                dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=0.6, at=0.0, gain_db=-3),
                dict(name="Flicking_Carabiner_On_Rope", t0=2.66, t1=3.1, at=0.62, gain_db=-8, semis=-3)],
    }),
    "C": ("Steel dome: a servo whine and a snort, a scraping metal rumble while it charges; the hit is a big bell-like steel clang with a punch, then a metal shake", {
        "windup": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.28, at=0.0, gain_db=-4, semis=-3, fout=0.04),
                   dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.15, at=0.03, gain_db=-5, semis=-9, start=True)],
        "charge": [dict(name="Metal_Scrape_Low_Tonal", t0=1.0, t1=1.8, at=0.0, gain_db=-3),
                   dict(name="Punch_Body_02", t0=0.16, t1=0.40, at=0.10, gain_db=-1, semis=-8),
                   dict(name="Punch_Body_02", t0=0.16, t1=0.40, at=0.50, gain_db=-1, semis=-8)],
        "hit": [dict(name="METAL_SWING_HIT", t0=0.80, t1=1.6, at=0.0, gain_db=0, semis=-4, fout=0.2),
                dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.0, gain_db=-2, semis=-4),
                dict(name="Metal_Shield_Spin_On_Floor", t0=1.2, t1=1.6, at=0.62, gain_db=-9, semis=-2, start=True)],
    }),
}
SETS["leap"] = {
    "A": ("Coiled spring: a pump hiss and a bass jump as the pistons fire, a sharp blast-kick on the double jump, a soft thud with a click and a steam vent on the landing", {
        "launch": [dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.40, at=0.0, gain_db=-4, semis=-2, start=True),
                   dict(name="Jump_Start_Drop_3", t0=0.03, t1=0.9, at=0.0, gain_db=0, fout=0.25, start=True),
                   dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.0, gain_db=-5, semis=-3)],
        "double": [dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.6, at=0.0, gain_db=0, semis=4),
                   dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.02, gain_db=-5, semis=-5, start=True)],
        "land": [dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.0, gain_db=0, semis=-6),
                 dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.04, gain_db=-5, semis=-4),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.08, gain_db=-4, semis=-7, start=True)],
    }),
    "B": ("Rocket boots: a clean jet blast off the ground, a higher second blast on the double jump, a heavy ringing thud on the landing", {
        "launch": [dict(name="Blast_Off_Clean", t0=3.0, t1=3.8, at=0.0, gain_db=0, fin=0.01, fout=0.25, start=True)],
        "double": [dict(name="Blast_Off_Clean", t0=3.0, t1=3.6, at=0.0, gain_db=0, semis=3, fin=0.01, fout=0.2, start=True),
                   dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.4, at=0.0, gain_db=-6, semis=5)],
        "land": [dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.7, at=0.0, gain_db=0, lp=1400),
                 dict(name="Woosh_Debris", t0=0.55, t1=1.0, at=0.04, gain_db=-8)],
    }),
    "C": ("Spring steel: a springy boing on the jump, a higher boing on the double jump, a wooden thump with dirt on the landing", {
        "launch": [dict(name="Vibrato_Impact_Snap_Spin", t0=0.0, t1=0.8, at=0.0, gain_db=0, semis=-4)],
        "double": [dict(name="Vibrato_Impact_Snap_Spin", t0=0.0, t1=0.7, at=0.0, gain_db=0, semis=-1)],
        "land": [dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=27.26, t1=27.9, at=0.0, gain_db=0, semis=-1),
                 dict(name="Woosh_Debris", t0=0.55, t1=1.03, at=0.04, gain_db=-6)],
    }),
}
LOOPS = {("headbutt", "charge"): 0.6, ("dash", "burn"): 1.0, ("visor", "field"): 1.0, ("med", "hum"): 1.0}
MAXLEN = {("hook", "reel"): 1.2, ("dash", "blast"): 0.9, ("blood", "pact"): 1.1}
meta = {}
for mv, opts in SETS.items():
    for opt, (desc, parts) in opts.items():
        for part, layers in parts.items():
            y = loop(layers, LOOPS[(mv, part)]) if (mv, part) in LOOPS else one_shot(layers, max_len=MAXLEN.get((mv, part)))
            fn = f"MDA_SFX_pachy2_{mv}{part}_{opt}.wav"
            sf.write(os.path.join(OUT, fn), y, SR, subtype="PCM_16")
            meta.setdefault(mv, {}).setdefault(opt, {"desc": desc, "parts": {}})["parts"][part] = {
                "file": fn, "len": round(len(y) / SR, 3), "loop": (mv, part) in LOOPS}
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
for mv, opts in meta.items():
    for opt, d in opts.items():
        print(mv, opt, " ".join(f"{p}={v['len']}s{'(loop)' if v['loop'] else ''}" for p, v in d["parts"].items()))
