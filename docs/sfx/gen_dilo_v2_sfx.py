r"""Dilo ability sounds v2 (MDA-552, sound pass round 18; Kepu 2026-11-17 19:52 "Next": the Dilo gets the record-the-game
pick page the Pachy (round 11) and the Raptor (round 17) got). Sonniss GDC 2026 sources (not in this repo): the Raptor's set
(Kepu's Music\MechaDinoArena_SFX\_work_titles_sonniss) plus 39 more extracted for the Dilo into _work_dilo_sonniss\mono_flac
(map.txt there: bundle name -> short name; Cauldron_Bubbling = the first 40 s). Same engine as gen_raptor_v2_sfx.py (each
option is a SET of parts, each part scheduled at a stamp; t = 0 of a clip is its stamp). Beats from the Studio recordings in
tools/mockup/dilo_rec (2026-11-17, build v885):
  scope   in @ DiloScopeStartAt | charge (loop) +0.15 .. DiloScopeShotAt | shot @ DiloScopeShotAt | hit @ the target's DiloScopeMarkUntil
  gatling spinup @ DiloGatlingAt | whirr (loop) + DiloGatlingWindup .. + DiloGatlingTime | spindown there | shot per DiloGatlingShot | hit per DiloGatlingHit
  mortar  load @ DiloMortarAt | fire @ DiloMortarFireAt | land @ DiloMortarLandAt | cloud (loop) +0.15 .. land + DiloMortarTime (at the landing point)
  spine   flare @ DiloSpineAt | burst @ DiloSpineBurstAt | hit @ burst + DiloSpineFlight (each dino in DiloSpineHits)
  hiss    charge @ DiloHissAt | blast @ DiloHissBlastAt
  pump    prime @ DiloPumpAt | jolt @ DiloPumpJoltAt
  over    charge @ DiloOverdriveAt | loop DiloOverdriveStartAt .. DiloOverdriveUntil | end @ DiloOverdriveUntil
Spring Jets keeps its sound (not in this pass).
Run: python3 -I gen_dilo_v2_sfx.py <src_dir> <out_dir>."""
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


BEDS = {"Wind_Whipping_Constricted_Flow", "Magic_Drone_Spellbound", "Radio_Static_Hum", "Glitch_High_Electronic", "Magic_Energy_Astonishment", "ELECBuzz_Buzz27", "Electricity_Hum_Lightbulb", "Wahl_Sterling_Trimmer",
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






BEDS |= {"Spray_Bottle_Spray", "Shimmer_Loop_Small_Bell_Metal_Taps", "Electricity_Hum_Lightbulb", "ELECBuzz_Buzz27", "Scifi_Loop_Ship_Reactor",
         "ArcPowerUpDesign04", "Magic_Light_Spell", "Alert_Swell_Creature", "Wind_Whipping_Constricted_Flow", "Hair_Dryer",
         "Crane_Motors", "Cauldron_Bubbling", "Fire_Burn_Loop", "Aquatic_Creature_Gurgling", "Magic_Evil_Presence", "Readout_Thin_Long",
         "Thermometer_Emf", "Aztec_Whistle_Distortion", "Jumpscare_Whisper", "Metal_Bowed_Screech", "Tentacle_Wobble", "Insectoid_Tremble",
         "Respirator_Breathing", "Tone_Downer", "Bass_Downer_Medium", "Rattling_Downer", "Magic_Drone_Spellbound"}
SETS = {}
SETS["gatling"] = {
    "A": ("Dart minigun: a servo whine as the barrels spin up, a buzzing whirr while they fire, a soft pop per dart, a wet splat on each hit, a falling whine as they stop", {
        "spinup": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.05, t1=0.95, at=0.0, gain_db=0, semis=3, start=True, fout=0.1)],
        "whirr": [dict(name="Wahl_Sterling_Trimmer", t0=1.0, t1=1.7, at=0.0, gain_db=0, semis=-5),
                  dict(name="Quadcopter_Toy_Flying_Sustained", t0=5.0, t1=5.7, at=0.0, gain_db=-8, semis=-3)],
        "spindown": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.05, t1=0.6, at=0.0, gain_db=-2, semis=-7, start=True, fout=0.25)],
        "shot": [dict(name="Paintball_Firefight", t0=1.235, t1=1.33, at=0.0, gain_db=0, start=True, fout=0.03),
                 dict(name="Interface_Pop_High_Short", t0=0.0, t1=0.12, at=0.0, gain_db=-6, semis=-5, start=True)],
        "hit": [dict(name="Liquid_Impact_Bubble", t0=0.12, t1=0.45, at=0.0, gain_db=0, semis=4, fout=0.1),
                dict(name="Blood_Spill_Splat", t0=0.2, t1=0.33, at=0.0, gain_db=-5)],
    }),
    "B": ("Air blaster: a motor spinning up like a hair dryer, a high steady blow while it fires, a hissing spit per dart, a bubble pop on each hit, the motor winding down", {
        "spinup": [dict(name="Hair_Dryer", t0=0.0, t1=0.5, at=0.0, gain_db=0, semis=5, start=True, fin=0.03, fout=0.06)],
        "whirr": [dict(name="Hair_Dryer", t0=2.0, t1=2.7, at=0.0, gain_db=0, semis=5)],
        "spindown": [dict(name="Hair_Dryer", t0=10.6, t1=11.3, at=0.0, gain_db=0, semis=5, start=True, fin=0.02, fout=0.2)],
        "shot": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.14, at=0.0, gain_db=0, semis=4, start=True, fout=0.05),
                 dict(name="Interface_Percussion_Snap", t0=0.0, t1=0.12, at=0.0, gain_db=-5, start=True)],
        "hit": [dict(name="Cartoon_Bubbles_Short", t0=0.0, t1=0.22, at=0.0, gain_db=0, start=True, fout=0.06),
                dict(name="Quick_Smack", t0=0.0, t1=0.25, at=0.0, gain_db=-8, start=True)],
    }),
    "C": ("Bio rifle: a heavy motor revving up, a grinding motor chatter while it fires, a sharp snap per dart, a dart thunk on each hit, a rattling drop as it stops", {
        "spinup": [dict(name="Crane_Motors", t0=1.0, t1=1.6, at=0.0, gain_db=0, semis=7, start=True, fin=0.08, fout=0.06)],
        "whirr": [dict(name="Crane_Motors", t0=1.75, t1=2.45, at=0.0, gain_db=0, semis=7)],
        "spindown": [dict(name="Rattling_Downer", t0=0.1, t1=0.75, at=0.0, gain_db=0, semis=5, start=True, fout=0.25)],
        "shot": [dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.3, at=0.0, gain_db=0, semis=6, fout=0.05)],
        "hit": [dict(name="Arrow_Hit_Rattle", t0=0.0, t1=1.0, at=0.0, gain_db=0, semis=3, fout=0.2),
                dict(name="Blood_Spill_Splat", t0=0.2, t1=0.33, at=0.0, gain_db=-6)],
    }),
}
SETS["mortar"] = {
    "A": ("Goo cannon: a latch and a pump as it loads, a deep boom on the launch, a big wet splash where it lands, a bubbling cauldron while the cloud hangs", {
        "load": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.3, at=0.0, gain_db=0, start=True),
                 dict(name="Barber_Chair_Foot_Pump", t0=1.0, t1=1.3, at=0.08, gain_db=-3, start=True)],
        "fire": [dict(name="EffectiveTrailer_Booms_Vol2_011", t0=0.25, t1=0.9, at=0.0, gain_db=0, lp=2500, fout=0.3),
                 dict(name="Cartoon_Bubbles_Short", t0=0.0, t1=0.3, at=0.03, gain_db=-6, semis=-4, start=True)],
        "land": [dict(name="Impact_Water_Deep_Submerge", t0=0.0, t1=1.0, at=0.0, gain_db=0, fout=0.4),
                 dict(name="Blood_Spill_Splat", t0=0.2, t1=0.33, at=0.0, gain_db=-3, semis=-4)],
        "cloud": [dict(name="Cauldron_Bubbling", t0=5.0, t1=6.6, at=0.0, gain_db=0),
                  dict(name="Wind_Whipping_Constricted_Flow", t0=2.0, t1=3.6, at=0.0, gain_db=-12, lp=1500)],
    }),
    "B": ("Toxic shell: a heavy latch as it loads, a punchy thump and a bass drop on the launch, a crunchy splat where it lands, a hissing gas with gurgles while the cloud hangs", {
        "load": [dict(name="Suitcase_Being_Locked", t0=0.3, t1=0.62, at=0.0, gain_db=0, start=True, fout=0.05)],
        "fire": [dict(name="Combat_Punch", t0=0.0, t1=0.4, at=0.0, gain_db=0, semis=-6, start=True),
                 dict(name="Jump_Start_Drop_3", t0=0.06, t1=0.7, at=0.0, gain_db=-4, start=True, fout=0.3)],
        "land": [dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.05, t1=0.8, at=0.0, gain_db=0, fout=0.3),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.02, gain_db=-4, semis=-5, start=True)],
        "cloud": [dict(name="Wind_Whipping_Constricted_Flow", t0=1.0, t1=2.6, at=0.0, gain_db=-2, hp=600),
                  dict(name="Aquatic_Creature_Gurgling", t0=0.7, t1=2.3, at=0.0, gain_db=-6, lp=1200)],
    }),
    "C": ("Spore bomb: a screw-lock click as it loads, a sci-fi bass whump on the launch, a trailer boom with a bubble where it lands, a dark wobbling drone while the cloud hangs", {
        "load": [dict(name="Carabiner_Screwing_Lock", t0=0.2, t1=0.55, at=0.0, gain_db=0, start=True, fout=0.05)],
        "fire": [dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=0, start=True),
                 dict(name="Woosh_Debris", t0=0.35, t1=0.9, at=0.05, gain_db=-4)],
        "land": [dict(name="EffectiveTrailer_Booms_Vol2_214", t0=0.25, t1=1.2, at=0.0, gain_db=0, lp=3000, fout=0.4),
                 dict(name="Liquid_Impact_Bubble", t0=0.1, t1=0.6, at=0.02, gain_db=-4, semis=-3)],
        "cloud": [dict(name="Magic_Evil_Presence", t0=4.0, t1=5.6, at=0.0, gain_db=0),
                  dict(name="Cauldron_Bubbling", t0=12.0, t1=13.6, at=0.0, gain_db=-8, semis=-4)],
    }),
}
SETS["spine"] = {
    "A": ("Quill volley: a rip and a flap as the frill flares, a sweeping slash and a spray of pings as the spines burst, a rattling arrow thunk on each hit", {
        "flare": [dict(name="VelcroRip29", t0=0.1, t1=0.41, at=0.0, gain_db=0, start=True, fout=0.08),
                  dict(name="ClothMovement24", t0=0.0, t1=0.4, at=0.05, gain_db=-4, start=True)],
        "burst": [dict(name="Action_Deploy_Units_Sword_Slice", t0=0.0, t1=0.9, at=0.0, gain_db=0, fout=0.3),
                  dict(name="Cofetti_Whoosh_Pluck_Spill", t0=0.2, t1=1.0, at=0.0, gain_db=-4, fout=0.3)],
        "hit": [dict(name="Arrow_Hit_Rattle", t0=0.0, t1=1.0, at=0.0, gain_db=0, fout=0.25)],
    }),
    "B": ("Bone spikes: a springy twang and a hiss as the frill flares, an icy whoosh-shatter as the spines burst, a hard stick impact on each hit", {
        "flare": [dict(name="Spring_Wire_Flick", t0=0.3, t1=0.8, at=0.0, gain_db=0, fout=0.2),
                  dict(name="Raptor_Flair", t0=0.05, t1=0.4, at=0.05, gain_db=-6, start=True, hp=400, fout=0.1)],
        "burst": [dict(name="Skill_Freeze_Whoosh_Break", t0=0.05, t1=1.0, at=0.0, gain_db=0, fout=0.3),
                  dict(name="Glass_Crystal_Fragments_Sharp", t0=0.0, t1=0.5, at=0.0, gain_db=-5)],
        "hit": [dict(name="Spear_And_Stick_Impact", t0=0.03, t1=0.4, at=0.0, gain_db=0, fout=0.1)],
    }),
    "C": ("Needle storm: quick snips and a metal rattle as the frill flares, a debris whoosh and a shaker snap as the spines burst, a dull wooden thud on each hit", {
        "flare": [dict(name="Scissor_Snips", t0=0.1, t1=0.5, at=0.0, gain_db=0, start=True, fout=0.05),
                  dict(name="Metal_Slow_Whoosh_Rattle", t0=0.0, t1=0.4, at=0.0, gain_db=-5, start=True, fout=0.1)],
        "burst": [dict(name="Woosh_Debris", t0=0.35, t1=1.2, at=0.0, gain_db=0, fout=0.3),
                  dict(name="Transition_Frantic_Shaker_Snap", t0=0.15, t1=0.7, at=0.0, gain_db=-3)],
        "hit": [dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=2.2, t1=2.7, at=0.0, gain_db=0, fout=0.15),
                dict(name="Quick_Smack", t0=0.0, t1=0.25, at=0.0, gain_db=-6, start=True)],
    }),
}
SETS["over"] = {
    "A": ("Reactor roar: an electric power-up swell and a big dino roar as it charges, a deep reactor hum while it lasts, a falling bass and a breath out at the end", {
        "charge": [dict(name="ArcPowerUpDesign04", t0=4.2, t1=5.3, at=0.0, gain_db=-3, start=True, fin=0.1, fout=0.3),
                   dict(name="Large_Herbivore_Roar_01", t0=0.2, t1=1.6, at=0.25, gain_db=0, start=True, fout=0.4)],
        "loop": [dict(name="Scifi_Loop_Ship_Reactor", t0=10.0, t1=11.6, at=0.0, gain_db=0, semis=-3),
                 dict(name="Magic_Evil_Presence", t0=4.0, t1=5.6, at=0.0, gain_db=-8)],
        "end": [dict(name="Tone_Downer", t0=0.2, t1=1.3, at=0.0, gain_db=0, start=True, fout=0.4),
                dict(name="Exhale_Creature", t0=0.0, t1=0.43, at=0.05, gain_db=-4, semis=-3, start=True)],
    }),
    "B": ("Venom rage: a charged-up beast yell and a creature swell, a boiling bubbling burn while it lasts, a bass drop and a harsh exhale at the end", {
        "charge": [dict(name="Orc_Male_Attack_Long_Heavy", t0=0.05, t1=1.2, at=0.0, gain_db=0, semis=-5, start=True, fout=0.3),
                   dict(name="Alert_Swell_Creature", t0=0.0, t1=1.0, at=0.0, gain_db=-5, start=True, fout=0.3)],
        "loop": [dict(name="Fire_Burn_Loop", t0=2.0, t1=3.6, at=0.0, gain_db=0, lp=4000),
                 dict(name="Cauldron_Bubbling", t0=20.0, t1=21.6, at=0.0, gain_db=-4, semis=-5)],
        "end": [dict(name="Bass_Downer_Medium", t0=0.0, t1=1.2, at=0.0, gain_db=0, start=True, fout=0.4),
                dict(name="Creature_Exhale_Violent", t0=0.0, t1=0.43, at=0.02, gain_db=-3, start=True)],
    }),
    "C": ("Overclock: a bright power-up and a T-rex roar as it charges, an electric buzz with glitches while it lasts, a power-off click and a rattling drop at the end", {
        "charge": [dict(name="Power_Up_Bright", t0=0.06, t1=1.0, at=0.0, gain_db=-2, start=True, fout=0.3),
                   dict(name="ANMLRept_T_Rex", t0=0.1, t1=1.3, at=0.2, gain_db=0, start=True, fout=0.4)],
        "loop": [dict(name="Electricity_Hum_Lightbulb", t0=4.0, t1=5.6, at=0.0, gain_db=0),
                 dict(name="Glitch_High_Electronic", t0=4.0, t1=5.6, at=0.0, gain_db=-10, lp=5000)],
        "end": [dict(name="Power_Button_003", t0=0.3, t1=0.7, at=0.0, gain_db=0, semis=-4),
                dict(name="Rattling_Downer", t0=0.1, t1=1.0, at=0.03, gain_db=-3, start=True, fout=0.3)],
    }),
}
SETS["hiss"] = {
    "A": ("Cobra hiss: a sharp breath in and a speaker whine as the hood flares, a harsh distorted hiss with a gust on the blast", {
        "charge": [dict(name="Screeching_Breath_Inhale", t0=0.0, t1=0.5, at=0.0, gain_db=0, start=True, fout=0.08),
                   dict(name="Thermometer_Emf", t0=0.35, t1=0.7, at=0.1, gain_db=-12, start=True, fout=0.1)],
        "blast": [dict(name="Jumpscare_Whisper", t0=0.35, t1=1.4, at=0.0, gain_db=0, start=True, fin=0.02, fout=0.4),
                  dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=-3, semis=-3, start=True),
                  dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.6, at=0.05, gain_db=-6)],
    }),
    "B": ("Sonic screech: a raptor snarl rising as the hood flares, a piercing distorted whistle-scream on the blast", {
        "charge": [dict(name="Raptor_Flair", t0=0.05, t1=0.55, at=0.0, gain_db=0, start=True, fout=0.1),
                   dict(name="Insectoid_Tremble", t0=0.0, t1=0.5, at=0.0, gain_db=-8, start=True, fout=0.1)],
        "blast": [dict(name="Aztec_Whistle_Distortion", t0=0.0, t1=0.9, at=0.0, gain_db=-2, start=True, fin=0.01, fout=0.45, lp=7000),
                  dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=-4, start=True)],
    }),
    "C": ("Bass hiss: an insect tremble as the hood flares, a bass burst with a low metal groan and a long hiss on the blast", {
        "charge": [dict(name="Insectoid_Tremble", t0=0.0, t1=0.5, at=0.0, gain_db=0, start=True, fout=0.1)],
        "blast": [dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=0, start=True),
                  dict(name="Metal_Bowed_Screech", t0=1.8, t1=2.8, at=0.0, gain_db=-4, start=True, fin=0.02, fout=0.4),
                  dict(name="Wind_Whipping_Constricted_Flow", t0=1.0, t1=2.0, at=0.0, gain_db=-4, hp=1500, fin=0.01, fout=0.5)],
    }),
}
SETS["pump"] = {
    "A": ("Piston pump: two quick pump strokes as it primes, a spray hiss, an electric zap and a healing shimmer on the jolt", {
        "prime": [dict(name="Barber_Chair_Foot_Pump", t0=1.0, t1=1.3, at=0.0, gain_db=0, start=True),
                  dict(name="Barber_Chair_Foot_Pump", t0=1.4, t1=1.7, at=0.3, gain_db=0, start=True)],
        "jolt": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=0, start=True),
                 dict(name="ArcDesign15", t0=0.0, t1=0.4, at=0.0, gain_db=-3, start=True),
                 dict(name="Magic_Light_Spell", t0=0.7, t1=1.6, at=0.1, gain_db=-6, fin=0.05, fout=0.4, start=True)],
    }),
    "B": ("Hydraulic: a pedal press and a heavy latch as it primes, a torch-valve hiss, a bass burst and a bright power-up on the jolt", {
        "prime": [dict(name="Car_Pedals", t0=0.1, t1=0.6, at=0.0, gain_db=0, start=True, fout=0.1),
                  dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.3, at=0.45, gain_db=-2, start=True)],
        "jolt": [dict(name="Blowtorch_Lid", t0=0.1, t1=0.6, at=0.0, gain_db=-2, start=True, fout=0.15),
                 dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=0, start=True),
                 dict(name="Power_Up_Bright", t0=0.06, t1=1.0, at=0.05, gain_db=-5, start=True, fout=0.3)],
    }),
    "C": ("Syringe: a ratchet winding and a sharp breath in as it primes, an electric thump, a gasp and a glassy snap on the jolt", {
        "prime": [dict(name="Tool_Tape_Measure_Pull_Retract", t0=0.7, t1=1.25, at=0.0, gain_db=0, start=True, fout=0.1),
                  dict(name="Screeching_Breath_Inhale", t0=0.0, t1=0.5, at=0.1, gain_db=-8, start=True, fout=0.1)],
        "jolt": [dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.7, at=0.0, gain_db=0, fout=0.25),
                 dict(name="Gasp_Male", t0=0.0, t1=0.3, at=0.05, gain_db=-5, semis=-2),
                 dict(name="Interface_Glassy_Snap", t0=0.0, t1=0.3, at=0.0, gain_db=-4, start=True)],
    }),
}
SETS["scope"] = {
    "A": ("Rail sniper: a dial click and a servo as the scope comes up, a thin rising electric whine while it aims, a whip-crack and a boom on the shot, a metal clang and a ping on the hit", {
        "in": [dict(name="Mode_Select_Wheel", t0=0.0, t1=0.25, at=0.0, gain_db=0, start=True),
               dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.05, t1=0.6, at=0.02, gain_db=-5, semis=6, start=True, fout=0.15)],
        "charge": [dict(name="Electricity_Hum_Lightbulb", t0=6.0, t1=6.8, at=0.0, gain_db=0, semis=7),
                   dict(name="ELECBuzz_Buzz27", t0=3.0, t1=3.8, at=0.0, gain_db=-12, semis=5)],
        "shot": [dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.45, at=0.0, gain_db=0, fout=0.1),
                 dict(name="EffectiveTrailer_Booms_Vol2_075", t0=0.24, t1=0.8, at=0.0, gain_db=-4, lp=1800, fout=0.3)],
        "hit": [dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.5, at=0.0, gain_db=0, fout=0.2),
                dict(name="Interface_SciFi_Ping_Down", t0=0.0, t1=0.5, at=0.08, gain_db=-5, semis=5, start=True)],
    }),
    "B": ("Venom rifle: a case latch and a tape click as the scope comes up, a soft beeping readout while it aims, a cracker bang and a punch on the shot, a wet hit and a beep on the hit", {
        "in": [dict(name="Case_Closed06", t0=0.0, t1=0.3, at=0.0, gain_db=0, start=True),
               dict(name="Measuring_Tape", t0=0.18, t1=0.5, at=0.06, gain_db=-4, start=True)],
        "charge": [dict(name="Readout_Thin_Long", t0=0.0, t1=0.84, at=0.0, gain_db=0, semis=-3)],
        "shot": [dict(name="Cracker_Bang", t0=0.05, t1=0.4, at=0.0, gain_db=0, fout=0.12),
                 dict(name="Combat_Punch", t0=0.0, t1=0.35, at=0.0, gain_db=-4, semis=-4, start=True)],
        "hit": [dict(name="Liquid_Impact_Bubble", t0=0.12, t1=0.6, at=0.0, gain_db=0, fout=0.2),
                dict(name="Thermometer_Beep", t0=0.0, t1=0.2, at=0.1, gain_db=-4, start=True)],
    }),
    "C": ("Plasma lance: a bright swell and a switch click as the scope comes up, an arcing power-up hum while it aims, a bass burst and an arc zap on the shot, a small blast and a twinkle on the hit", {
        "in": [dict(name="Light_Switch_On", t0=0.0, t1=0.25, at=0.0, gain_db=0, start=True),
               dict(name="Power_Up_Bright", t0=0.06, t1=0.6, at=0.02, gain_db=-6, start=True, fout=0.2)],
        "charge": [dict(name="ArcPowerUpDesign04", t0=2.6, t1=3.4, at=0.0, gain_db=0)],
        "shot": [dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=0, start=True),
                 dict(name="ArcDesign15", t0=0.0, t1=0.45, at=0.0, gain_db=-3, start=True)],
        "hit": [dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.6, at=0.0, gain_db=0, semis=3),
                dict(name="Button_Arp_Twinkle", t0=0.0, t1=0.8, at=0.1, gain_db=-7, start=True, fout=0.3)],
    }),
}
LOOPS = {("gatling", "whirr"): 0.5, ("mortar", "cloud"): 1.4, ("over", "loop"): 1.4, ("scope", "charge"): 0.6}
POST_DB = {  # parts that level() pushes too loud (bass-heavy sources measured to the -18 dB phone band): full-band RMS brought to about -14 dB
    ("gatling", "hit", "A"): -5.4, ("gatling", "spindown", "A"): -1.5, ("gatling", "spindown", "C"): -12.3, ("hiss", "blast", "C"): -2.1,
    ("mortar", "fire", "A"): -2.5, ("mortar", "land", "C"): -7.2, ("over", "charge", "C"): -4.4, ("over", "end", "A"): -9.3,
    ("over", "end", "C"): -10.8, ("pump", "prime", "A"): -1.6, ("spine", "burst", "C"): -3.1, ("spine", "flare", "B"): -2.4, ("spine", "hit", "C"): -1.2}
MAXLEN = {("gatling", "shot"): 0.16, ("gatling", "hit"): 0.4, ("over", "charge"): 1.5, ("hiss", "blast"): 1.2, ("mortar", "land"): 1.0}
meta = {}
for mv, opts in SETS.items():
    for opt, (desc, parts) in opts.items():
        for part, layers in parts.items():
            y = loop(layers, LOOPS[(mv, part)]) if (mv, part) in LOOPS else one_shot(layers, max_len=MAXLEN.get((mv, part)))
            y = y * 10 ** (POST_DB.get((mv, part, opt), 0.0) / 20.0)
            fn = f"MDA_SFX_dilo2_{mv}{part}_{opt}.wav"
            sf.write(os.path.join(OUT, fn), y, SR, subtype="PCM_16")
            meta.setdefault(mv, {}).setdefault(opt, {"desc": desc, "parts": {}})["parts"][part] = {
                "file": fn, "len": round(len(y) / SR, 3), "loop": (mv, part) in LOOPS}
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
for mv, opts in meta.items():
    for opt, d in opts.items():
        print(mv, opt, " ".join(f"{p}={v['len']}s{'(loop)' if v['loop'] else ''}" for p, v in d["parts"].items()))
