r"""Herrera ability sounds v2 (MDA-552, sound pass round 19; Kepu 2026-11-17 21:12 "then next": the Herrera gets the
record-the-game pick page after the Dilo). Sonniss GDC 2026 sources (not in this repo): the Raptor's set plus the Dilo's 39
(Kepu's Music\MechaDinoArena_SFX\_work_dilo_sonniss\mono_flac, map.txt there) and Cartoon_Confused_Dizzy. Same engine as
gen_raptor_v2_sfx.py (each option is a SET of parts, each part scheduled at a stamp; t = 0 of a clip is its stamp). Beats from
the Studio recordings in tools/mockup/herrera_rec (2026-11-17, build v886):
  quills   arm @ QuillWindupAt | fire @ QuillStartedAt | hit @ the target's QuillHitAt (one per quill)
  cruise   launch @ CruiseLaunchAt | fly (loop) + 0.6 (the launch view) .. CruiseBoomAt | boost @ CruiseBoosted true |
           boom @ CruiseBoomAt (at CruiseBoomPos) | crater (loop) .. CruiseCraterUntil (the star)
  strobe   charge @ StrobeStartedAt | flash @ StrobeAt | daze @ each dazed dino's DazedAt
  smoke    pop @ SmokeWindupAt | burst @ SmokeStartedAt | loop (at SmokeCenter) .. SmokeUntil | end @ SmokeUntil
  breaker  snap @ BreakerWindupAt (the stun breaks at the press) | push @ BreakerAt
  caltrops drop @ CaltropDroppedAt | land @ + ArmFly (0.42, the first spike lands)
  goo      charge @ GooWindupAt | fire @ GooFiredAt | splat @ + the flight (0.85 / 1.5 s on the ground, 0.45 / 1.5 gliding)
  glider   open @ GlideStartedAt | loop .. GlideEndedAt | close @ GlideEndedAt
The Adrenaline Injector plays the Raptor's beat-timed adrenaline (GameSounds 1.18).
Run: python3 -I gen_herrera_v2_sfx.py <src_dir> <out_dir>."""
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
         "Thermometer_Emf", "Blast_Off_Clean", "Kawasaki_Ninja_ZX_10R_Pass_By_Fast", "Respirator_Breathing", "Magic_Drone_Spellbound",
         "Quadcopter_Toy_Flying_Sustained", "Tone_Downer", "Bass_Downer_Medium", "Rattling_Downer", "Glass_Crystal_Fragments_Sharp",
         "ClothMovement29", "Interior_Thunder_Rumble"}
SETS = {}
SETS["quills"] = {
    "A": ("Quill volley: a latch click as the launcher arms, a fast spray of whooshing quills, a sharp arrow thunk on each hit", {
        "arm": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.3, at=0.0, gain_db=0, start=True),
                dict(name="Spring_Wire_Flick", t0=0.3, t1=0.7, at=0.05, gain_db=-6, fout=0.15)],
        "fire": [dict(name="Cofetti_Whoosh_Pluck_Spill", t0=0.2, t1=1.0, at=0.0, gain_db=0, fout=0.3),
                 dict(name="Action_Deploy_Units_Sword_Slice", t0=0.0, t1=0.7, at=0.05, gain_db=-5, fout=0.25)],
        "hit": [dict(name="Arrow_Hit_Rattle", t0=0.0, t1=1.0, at=0.0, gain_db=0, fout=0.2)],
    }),
    "B": ("Dart gun: a servo whine as it arms, rapid air-gun pops as the quills leave, a wooden stick thud on each hit", {
        "arm": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.05, t1=0.5, at=0.0, gain_db=0, semis=4, start=True, fout=0.1)],
        "fire": [dict(name="Paintball_Firefight", t0=1.62, t1=2.05, at=0.0, gain_db=0, start=True, fout=0.1),
                 dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=0.0, gain_db=-6, semis=3)],
        "hit": [dict(name="Spear_And_Stick_Impact", t0=0.03, t1=0.4, at=0.0, gain_db=0, semis=2, fout=0.1)],
    }),
    "C": ("Spine rattle: a porcupine rattle as it arms, a whip-snap volley, a dull smack on each hit", {
        "arm": [dict(name="Transition_Frantic_Shaker_Snap", t0=0.15, t1=0.5, at=0.0, gain_db=0, start=True, fout=0.1)],
        "fire": [dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.6, at=0.0, gain_db=0, semis=4, fout=0.2),
                 dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.6, at=0.0, gain_db=-5, semis=3)],
        "hit": [dict(name="Quick_Smack", t0=0.0, t1=0.3, at=0.0, gain_db=0, start=True, semis=3),
                dict(name="Blood_Spill_Splat", t0=0.2, t1=0.33, at=0.0, gain_db=-8)],
    }),
}
SETS["breaker"] = {
    "A": ("Chain snap: metal chains rattle and snap as it breaks free, a deep metal whump as the push goes out", {
        "snap": [dict(name="Carabiner_Screwing_Lock", t0=0.2, t1=0.55, at=0.0, gain_db=-2, start=True, fout=0.05),
                 dict(name="METAL_SWING_HIT", t0=0.08, t1=0.8, at=0.05, gain_db=0, fout=0.3)],
        "push": [dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.6, at=0.0, gain_db=0, fout=0.25),
                 dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.6, at=0.0, gain_db=-4, semis=-4)],
    }),
    "B": ("Shock release: a glitchy electric crackle as it breaks free, a bass burst shockwave as the push goes out", {
        "snap": [dict(name="ArcDesign15", t0=0.0, t1=0.45, at=0.0, gain_db=0, start=True, fout=0.12),
                 dict(name="Glitch_Corrupted_Data", t0=2.05, t1=2.4, at=0.02, gain_db=-4, start=True, fout=0.1)],
        "push": [dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=0, start=True),
                 dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.7, at=0.0, gain_db=-3, fout=0.25)],
    }),
    "C": ("Beast shrug: an angry snort as it breaks free, a heavy swing-thud as the push goes out", {
        "snap": [dict(name="Raptor_Flair", t0=0.05, t1=0.45, at=0.0, gain_db=0, start=True, semis=-5, fout=0.1),
                 dict(name="VelcroRip29", t0=0.1, t1=0.41, at=0.0, gain_db=-4, start=True)],
        "push": [dict(name="Quick_Heavy_Weapon_Swing_To_Thud", t0=0.0, t1=0.9, at=0.0, gain_db=0, fout=0.3)],
    }),
}
SETS["smoke"] = {
    "A": ("Smoke grenade: a pod pop, a big hissing burst as the cloud blooms, a steady gas hiss while it hangs, a fading puff as it clears", {
        "pop": [dict(name="Cracker_Bang", t0=0.05, t1=0.4, at=0.0, gain_db=-2, fout=0.1)],
        "burst": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=0, semis=-6, start=True),
                  dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.0, at=0.0, gain_db=-3, semis=-3, fout=0.4)],
        "loop": [dict(name="Wind_Whipping_Constricted_Flow", t0=1.0, t1=2.6, at=0.0, gain_db=0, hp=800, lp=6000)],
        "end": [dict(name="Exhale_Creature", t0=0.0, t1=0.43, at=0.0, gain_db=-4, semis=-6, start=True, lp=2000),
                dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=0.0, gain_db=-6, semis=-6, start=True)],
    }),
    "B": ("Fog machine: a valve clunk, a blowtorch whoosh as the cloud blooms, a low rumbling fog while it hangs, a soft breath out as it clears", {
        "pop": [dict(name="Blowtorch_Lid", t0=0.1, t1=0.6, at=0.0, gain_db=0, start=True, fout=0.1)],
        "burst": [dict(name="Whoosh_Fire_Deep_Growl", t0=0.0, t1=0.9, at=0.0, gain_db=-2, lp=3000, fout=0.3)],
        "loop": [dict(name="Magic_Drone_Spellbound", t0=8.0, t1=9.6, at=0.0, gain_db=-2),
                 dict(name="Wind_Whipping_Constricted_Flow", t0=3.0, t1=4.6, at=0.0, gain_db=-8, lp=1200)],
        "end": [dict(name="Exhale_Creature", t0=0.0, t1=0.43, at=0.0, gain_db=0, semis=-3, start=True, lp=2500)],
    }),
    "C": ("Ninja smoke: a sharp snap, a puff with a dark swell as the cloud blooms, an eerie whisper bed while it hangs, a reverse swoosh as it clears", {
        "pop": [dict(name="Interface_Percussion_Snap", t0=0.0, t1=0.3, at=0.0, gain_db=0, start=True, semis=-3)],
        "burst": [dict(name="Magic_Energy_Astonishment", t0=1.9, t1=2.8, at=0.0, gain_db=-2, start=True, fin=0.02, fout=0.4),
                  dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=-4, semis=-4, start=True)],
        "loop": [dict(name="Magic_Evil_Presence", t0=10.0, t1=11.6, at=0.0, gain_db=0),
                 dict(name="Wind_Whipping_Constricted_Flow", t0=5.0, t1=6.6, at=0.0, gain_db=-10, hp=1500)],
        "end": [dict(name="Cartoon_Pull_Swoosh", t0=0.0, t1=0.6, at=0.0, gain_db=0, start=True, fout=0.2)],
    }),
}
SETS["strobe"] = {
    "A": ("Camera flash: a rising flash-charge whine as it rears up, a bright pop-zap on the flash, a dizzy ring on each dino dazed", {
        "charge": [dict(name="Thermometer_Emf", t0=0.35, t1=0.75, at=0.0, gain_db=-6, start=True, fout=0.05),
                   dict(name="Power_Up_Bright", t0=0.06, t1=0.5, at=0.0, gain_db=-3, start=True, fout=0.1)],
        "flash": [dict(name="Cracker_Bang", t0=0.05, t1=0.4, at=0.0, gain_db=-2, fout=0.1),
                  dict(name="ArcDesign15", t0=0.0, t1=0.4, at=0.0, gain_db=-3, start=True)],
        "daze": [dict(name="Cartoon_Confused_Dizzy", t0=0.0, t1=0.9, at=0.0, gain_db=0, start=True, fout=0.3)],
    }),
    "B": ("Laser frill: a sci-fi charge-up as it rears up, a glassy laser snap on the flash, a high ringing on each dino dazed", {
        "charge": [dict(name="ArcPowerUpDesign04", t0=4.4, t1=4.85, at=0.0, gain_db=-2, start=True, fin=0.05, fout=0.05)],
        "flash": [dict(name="Interface_Glassy_Snap", t0=0.0, t1=0.35, at=0.0, gain_db=0, start=True),
                  dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=-5, start=True)],
        "daze": [dict(name="Aztec_Whistle_Dry", t0=0.25, t1=1.0, at=0.0, gain_db=-8, semis=7, start=True, fin=0.05, fout=0.5, lp=8000)],
    }),
    "C": ("Disco blast: a hum swelling as it rears up, a magic sparkle burst on the flash, a woozy wobble on each dino dazed", {
        "charge": [dict(name="Alert_Swell_Creature", t0=0.0, t1=0.45, at=0.0, gain_db=-2, start=True, fout=0.05)],
        "flash": [dict(name="Magic_Light_Spell", t0=0.55, t1=1.4, at=0.0, gain_db=0, start=True, fin=0.01, fout=0.4),
                  dict(name="Interface_Pop_High_Short", t0=0.0, t1=0.12, at=0.0, gain_db=-3, start=True)],
        "daze": [dict(name="Tentacle_Wobble", t0=0.4, t1=1.3, at=0.0, gain_db=-4, start=True, fin=0.05, fout=0.3)],
    }),
}
SETS["caltrops"] = {
    "A": ("Spike spill: a chute rattle as the spikes pour out, a scatter of metal tinks as they land", {
        "drop": [dict(name="Large_Metal_Box_Drag", t0=1.7, t1=2.2, at=0.0, gain_db=0, start=True, fout=0.15)],
        "land": [dict(name="Ting_Coins", t0=0.05, t1=0.9, at=0.0, gain_db=0, start=True, fout=0.3),
                 dict(name="Metal_Old_File_Impact_Tap", t0=0.0, t1=0.3, at=0.0, gain_db=-6)],
    }),
    "B": ("Caltrop bag: a sack shake as the spikes pour out, a crunchy sharp scatter as they land", {
        "drop": [dict(name="Pick_Up_Multiple_Cards_At_Once", t0=0.05, t1=0.38, at=0.0, gain_db=0, start=True),
                 dict(name="Transition_Frantic_Shaker_Snap", t0=0.15, t1=0.5, at=0.05, gain_db=-4, start=True)],
        "land": [dict(name="Glass_Crystal_Fragments_Sharp", t0=0.0, t1=0.8, at=0.0, gain_db=0, fout=0.3),
                 dict(name="Ting_Coins", t0=0.05, t1=0.6, at=0.05, gain_db=-6, start=True)],
    }),
    "C": ("Ice spikes: a counting-machine clatter as they pour out, an icy crack-scatter as they land", {
        "drop": [dict(name="Mechanism_Counting_Machine_Interact", t0=0.0, t1=0.27, at=0.0, gain_db=0, start=True),
                 dict(name="Measuring_Tape", t0=0.18, t1=0.6, at=0.05, gain_db=-4, start=True)],
        "land": [dict(name="ice_block_snapping", t0=0.48, t1=1.2, at=0.0, gain_db=0, fout=0.3),
                 dict(name="Ting_Coins", t0=0.05, t1=0.6, at=0.05, gain_db=-8, start=True)],
    }),
}
SETS["goo"] = {
    "A": ("Goo spit: a throaty gurgle as it loads, a wet spit as the blob leaves, a big wet splat where it lands", {
        "charge": [dict(name="Aquatic_Creature_Gurgling", t0=0.7, t1=1.1, at=0.0, gain_db=0, start=True, fout=0.08)],
        "fire": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.25, at=0.0, gain_db=-2, start=True, semis=-5, fout=0.08),
                 dict(name="Cartoon_Bubbles_Short", t0=0.0, t1=0.25, at=0.0, gain_db=-4, start=True)],
        "splat": [dict(name="Blood_Spill_Splat", t0=0.2, t1=0.33, at=0.0, gain_db=0, semis=-3),
                  dict(name="Liquid_Impact_Bubble", t0=0.1, t1=0.7, at=0.02, gain_db=-3, fout=0.3)],
    }),
    "B": ("Slime cannon: a pump stroke as it loads, a deep plop as the blob leaves, a sloppy squelch where it lands", {
        "charge": [dict(name="Barber_Chair_Foot_Pump", t0=1.0, t1=1.3, at=0.0, gain_db=0, start=True)],
        "fire": [dict(name="Liquid_Impact_Bubble", t0=0.1, t1=0.5, at=0.0, gain_db=0, semis=-6, fout=0.15)],
        "splat": [dict(name="Dinosaur_Eating_Meat_01", t0=0.8, t1=1.3, at=0.0, gain_db=0, fout=0.2),
                  dict(name="Impact_Water_Deep_Submerge", t0=0.0, t1=0.5, at=0.0, gain_db=-6, fout=0.25)],
    }),
    "C": ("Toxic blob: a bubbling cauldron as it loads, a cartoon pop as the blob leaves, a gooey splash with fizz where it lands", {
        "charge": [dict(name="Cauldron_Bubbling", t0=5.0, t1=5.4, at=0.0, gain_db=0, start=True, fin=0.05, fout=0.08)],
        "fire": [dict(name="Cartoon_Pops", t0=0.06, t1=0.3, at=0.0, gain_db=0, start=True, fout=0.05)],
        "splat": [dict(name="Impact_Water_Deep_Submerge", t0=0.0, t1=0.7, at=0.0, gain_db=0, fout=0.3),
                  dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.03, gain_db=-8, start=True)],
    }),
}
SETS["glider"] = {
    "A": ("Wing sail: a cloth snap as the wings open, a rushing wind while it glides, a flap as they fold", {
        "open": [dict(name="ClothMovement24", t0=0.5, t1=0.95, at=0.0, gain_db=0, fout=0.1),
                 dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=0.0, gain_db=-5, start=True)],
        "loop": [dict(name="Wind_Whipping_Constricted_Flow", t0=4.0, t1=5.6, at=0.0, gain_db=0)],
        "close": [dict(name="SinglePats04", t0=0.05, t1=0.4, at=0.0, gain_db=0),
                  dict(name="ClothMovement29", t0=0.0, t1=0.4, at=0.0, gain_db=-5, start=True, fout=0.1)],
    }),
    "B": ("Jet wings: a servo whine as the wings lock out, a jet engine hum while it glides, a power-down as they fold", {
        "open": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.05, t1=0.9, at=0.0, gain_db=0, start=True, fout=0.2)],
        "loop": [dict(name="Kawasaki_Ninja_ZX_10R_Pass_By_Fast", t0=5.0, t1=6.6, at=0.0, gain_db=-2, lp=4000),
                 dict(name="Wind_Whipping_Constricted_Flow", t0=4.0, t1=5.6, at=0.0, gain_db=-8)],
        "close": [dict(name="Power_Button_003", t0=0.3, t1=0.7, at=0.0, gain_db=0, semis=-3)],
    }),
    "C": ("Pterosaur: a leathery flap and a screech as the wings open, a soft breezy flutter while it glides, a thump as they fold", {
        "open": [dict(name="Hatchling_Calling_Out", t0=0.06, t1=0.6, at=0.0, gain_db=-3, start=True, semis=-5, fout=0.15),
                 dict(name="ClothMovement24", t0=0.5, t1=0.95, at=0.0, gain_db=-2, fout=0.1)],
        "loop": [dict(name="Quadcopter_Toy_Flying_Sustained", t0=5.0, t1=6.6, at=0.0, gain_db=-4, semis=-12, lp=2500),
                 dict(name="Wind_Whipping_Constricted_Flow", t0=5.8, t1=7.4, at=0.0, gain_db=-4)],
        "close": [dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=2.2, t1=2.6, at=0.0, gain_db=-4, fout=0.15),
                  dict(name="ClothMovement29", t0=0.0, t1=0.4, at=0.0, gain_db=-4, start=True, fout=0.1)],
    }),
}
SETS["cruise"] = {
    "A": ("Hellfire: a silo pop and an ignition roar at the launch, a jet roar while it flies, an afterburner kick on the boost, a big boom, a crackling fire in the crater", {
        "launch": [dict(name="Cracker_Bang", t0=0.05, t1=0.4, at=0.0, gain_db=-2, fout=0.1),
                   dict(name="Blast_Off_Clean", t0=3.0, t1=3.8, at=0.05, gain_db=-2, start=True, fout=0.3)],
        "fly": [dict(name="Blast_Off_Clean", t0=5.0, t1=6.6, at=0.0, gain_db=0)],
        "boost": [dict(name="Whoosh_Fire_Deep_Growl", t0=0.0, t1=0.8, at=0.0, gain_db=0, fout=0.3)],
        "boom": [dict(name="EffectiveTrailer_Booms_Vol2_011", t0=0.25, t1=1.8, at=0.0, gain_db=0, fout=0.6),
                 dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.9, at=0.0, gain_db=-4)],
        "crater": [dict(name="Fire_Burn_Loop", t0=2.0, t1=3.6, at=0.0, gain_db=0)],
    }),
    "B": ("Thunder strike: a deep launch thump, a whistling dive while it flies, a whoosh on the boost, a thunder crash, a low rumble in the crater", {
        "launch": [dict(name="EffectiveTrailer_Booms_Vol2_075", t0=0.24, t1=0.9, at=0.0, gain_db=-2, lp=2000, fout=0.3),
                   dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.0, at=0.05, gain_db=-4, semis=4, fout=0.3)],
        "fly": [dict(name="Wind_Whipping_Constricted_Flow", t0=2.0, t1=3.6, at=0.0, gain_db=0, semis=5),
                dict(name="Blast_Off_Clean", t0=6.0, t1=7.6, at=0.0, gain_db=-8)],
        "boost": [dict(name="Kawasaki_Ninja_ZX_10R_Pass_By_Fast", t0=4.5, t1=5.4, at=0.0, gain_db=0, fin=0.05, fout=0.3)],
        "boom": [dict(name="Texas_Rain_Thunder_Initial_Crash", t0=3.0, t1=4.6, at=0.0, gain_db=0, fout=0.6),
                 dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.05, t1=0.6, at=0.0, gain_db=-4)],
        "crater": [dict(name="Interior_Thunder_Rumble", t0=5.0, t1=6.6, at=0.0, gain_db=0, lp=1500),
                   dict(name="Fire_Burn_Loop", t0=6.0, t1=7.6, at=0.0, gain_db=-8)],
    }),
    "C": ("Arcade nuke: a sci-fi launch zap, a rising reactor whine while it flies, a power-up on the boost, a crunchy cartoon blast, a buzzing fire in the crater", {
        "launch": [dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=0, start=True),
                   dict(name="Blast_Off_Clean", t0=3.0, t1=3.6, at=0.05, gain_db=-5, start=True, fout=0.3)],
        "fly": [dict(name="Scifi_Loop_Ship_Reactor", t0=20.0, t1=21.6, at=0.0, gain_db=0, semis=6)],
        "boost": [dict(name="Power_Up_Bright", t0=0.06, t1=0.9, at=0.0, gain_db=0, start=True, fout=0.3)],
        "boom": [dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=1.2, at=0.0, gain_db=0, fout=0.4),
                 dict(name="EffectiveTrailer_Booms_Vol2_214", t0=0.25, t1=1.4, at=0.0, gain_db=-4, lp=2500, fout=0.4)],
        "crater": [dict(name="Fire_Burn_Loop", t0=8.0, t1=9.6, at=0.0, gain_db=-2),
                   dict(name="ELECBuzz_Buzz27", t0=4.0, t1=5.6, at=0.0, gain_db=-12)],
    }),
}
LOOPS = {("smoke", "loop"): 1.4, ("glider", "loop"): 1.4, ("cruise", "fly"): 1.4, ("cruise", "crater"): 1.4}
POST_DB = {  # parts that level() pushes too loud (bass-heavy sources): full-band RMS brought to about -14 dB (the cruise blast to -11)
    ("caltrops", "drop", "A"): -11.5, ("cruise", "boom", "A"): -5.0, ("cruise", "boom", "C"): -2.5, ("cruise", "boost", "A"): -5.3,
    ("cruise", "crater", "B"): -5.6, ("cruise", "launch", "B"): -2.5, ("goo", "charge", "B"): -3.3, ("goo", "splat", "A"): -1.2,
    ("quills", "arm", "A"): -2.4, ("smoke", "burst", "B"): -5.6, ("strobe", "charge", "C"): -1.5, ("strobe", "daze", "C"): -1.0}
MAXLEN = {("quills", "hit"): 0.4, ("caltrops", "land"): 0.9, ("cruise", "boom"): 1.6, ("strobe", "daze"): 0.9}
meta = {}
for mv, opts in SETS.items():
    for opt, (desc, parts) in opts.items():
        for part, layers in parts.items():
            y = loop(layers, LOOPS[(mv, part)]) if (mv, part) in LOOPS else one_shot(layers, max_len=MAXLEN.get((mv, part)))
            y = y * 10 ** (POST_DB.get((mv, part, opt), 0.0) / 20.0)
            fn = f"MDA_SFX_herr2_{mv}{part}_{opt}.wav"
            sf.write(os.path.join(OUT, fn), y, SR, subtype="PCM_16")
            meta.setdefault(mv, {}).setdefault(opt, {"desc": desc, "parts": {}})["parts"][part] = {
                "file": fn, "len": round(len(y) / SR, 3), "loop": (mv, part) in LOOPS}
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
for mv, opts in meta.items():
    for opt, d in opts.items():
        print(mv, opt, " ".join(f"{p}={v['len']}s{'(loop)' if v['loop'] else ''}" for p, v in d["parts"].items()))
