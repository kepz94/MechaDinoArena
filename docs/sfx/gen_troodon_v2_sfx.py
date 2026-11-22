r"""Troodon ability sounds v2 (MDA-552, sound pass round 20; Kepu 2026-11-22 05:06 "next" after the GameSounds 1.20 publish:
the Troodon gets the record-the-game pick page after the Herrera). Sonniss GDC 2026 sources (not in this repo): the Dilo /
Herrera set (Kepu's Music\MechaDinoArena_SFX\_work_dilo_sonniss\mono_flac) plus 27 more extracted from the bundle into
_work_troo_sonniss\mono_flac (map.txt there). Same engine as gen_herrera_v2_sfx.py (each option is a SET of parts, each part
scheduled at a stamp; t = 0 of a clip is its stamp). Beats from the Studio recordings in tools/mockup/troodon_rec (2026-11-22,
build v888):
  mender   launch @ TrooMenderAt (the drone leaves the back after the 0.45 s wind-up) | arrive @ TrooMenderArriveAt |
           loop (the heal hum) .. TrooMenderUntil | end @ TrooMenderEndAt (the drone flies home)
  lantern  throw @ TrooLanternAt (the lob leaves the hand at + 0.42) | land @ TrooLanternLandAt | zap @ each TrooLanternZapAt
  sap      throw @ TrooSapAt (the pod leaves at + 0.34) | rise @ TrooSapSplatAt (the wall goes up) | end @ TrooSapEndAt (8 s on)
  shed     snap @ TrooShedAt (the stun / pin / snare breaks) | burst @ TrooShedBurstAt (the feathers blast out)
  portal   tear @ TrooRiftAt (placing starts) | trail (loop) .. the second press | open @ TrooRiftOpenAt | travel @ each
           TrooRiftTravelAt (a dino carried along the rift)
  burst    throw @ TrooBurstAt (the bud leaves at + 0.34) | bloom @ TrooBurstLandAt
  dome     throw @ TrooDomeAt | open @ the dome opening (TrooDomeUntil written) | loop .. TrooDomeUntil | close @ TrooDomeUntil
  sleep    coil @ TrooSleepAt (the neck coils) | fire @ TrooSleepFireAt | hit @ the target's TrooSleepAt | snore (loop) on
           the target .. its TrooSleepUntil (or TrooSleepWokeAt)
  sentry   throw @ TrooSentryAt | deploy @ the turret opening (TrooSentryOpenAt) | shot @ each TrooSentryShotAt (on the turret) |
           fold @ TrooSentryEndAt
Run: python3 -I gen_troodon_v2_sfx.py <src_dir> <out_dir>."""
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






BEDS |= {"Quadcopter_Toy_Flying_Sustained", "Electricity_Hum_Lightbulb", "Shimmer_Loop_Small_Bell_Metal_Taps", "Magic_Astral_Travel",
         "Unidentified_Encounter", "Deep_Fridge_Hum_Buzz_Electric_Tone_Deep", "Rhythmic_Electric_Fridge_Hum_Buzz_Static",
         "Dark_Loop_Mystic_Forest_Tonal_Steady_Synth", "Ambience_Forest_Crickets_Birds_Connecticut_02",
         "Loop_Ambience_Jungle_Night_Humid_Birds_Bug_Chirps_01", "Respirator_Breathing", "Magic_Energy_Astonishment",
         "ArcPowerUpDesign04", "Magic_Light_Spell", "Magic_Christmas_Bells_2", "Metal_Scrape_Low_Tonal", "Transition_Braam",
         "Cartoon_Transition_Bass_Down", "Spray_Bottle_Spray", "Magic_Creation_23", "Interface_Arp_Reveal_Down_Long",
         "Button_Arp_Twinkle", "Wind_Whipping_Constricted_Flow", "Glitch_High_Electronic", "ELECBuzz_Buzz27", "Tone_Downer",
         "SBmb_Music_Box_A_013", "SBmb_Music_Box_B_028", "SBmb_Music_Box_C_059", "SBmb_Music_Box_C_Wind_Up_006"}
WINDUP = 0.42  # the lantern leaves the hand (TrooMovesServer lanternWindup); the sap pod / bud / dome / sentry leave at 0.34
THROW = 0.34
SETS = {}
SETS["mender"] = {
    "A": ("Med drone: power-on beeps and a rotor spin-up as it lifts off, a soft rotor hum while it heals, a confirm ping on arrival, a beep-down as it flies home", {
        "launch": [dict(name="Quadcopter_Beeps", t0=0.15, t1=0.55, at=0.0, gain_db=-4, start=True, fout=0.08),
                   dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.05, t1=0.6, at=0.3, gain_db=-2, semis=5, start=True, fout=0.15),
                   dict(name="Quadcopter_Toy_Flying_Sustained", t0=5.0, t1=5.9, at=0.45, gain_db=-4, start=True, fin=0.15, fout=0.3)],
        "arrive": [dict(name="Interface_SciFi_Ping_Down", t0=0.08, t1=0.75, at=0.0, gain_db=0, start=True, semis=5, fout=0.2)],
        "loop": [dict(name="Quadcopter_Toy_Flying_Sustained", t0=8.0, t1=9.6, at=0.0, gain_db=-4, hp=400, lp=6000),
                 dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=10.0, t1=11.6, at=0.0, gain_db=-10)],
        "end": [dict(name="Quadcopter_Beeps", t0=0.6, t1=1.0, at=0.0, gain_db=-4, start=True, fout=0.1),
                dict(name="Power_Button_003", t0=0.3, t1=0.7, at=0.05, gain_db=-6, semis=3, start=True)],
    }),
    "B": ("Healing hum: a magic swell as it lifts off, a warm glowing hum while it heals, a kalimba rise on arrival, a falling arpeggio as it flies home", {
        "launch": [dict(name="Magic_Creation_23", t0=0.0, t1=0.9, at=0.0, gain_db=-2, start=True, fin=0.02, fout=0.3),
                   dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=0.45, gain_db=-6, semis=3, start=True)],
        "arrive": [dict(name="UIMisc_Kalimba_3_Up", t0=0.0, t1=0.55, at=0.0, gain_db=0, start=True, fout=0.15)],
        "loop": [dict(name="Electricity_Hum_Lightbulb", t0=6.0, t1=7.6, at=0.0, gain_db=-6, lp=3000),
                 dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=4.0, t1=5.6, at=0.0, gain_db=-2)],
        "end": [dict(name="Interface_Arp_Reveal_Down_Long", t0=0.0, t1=1.0, at=0.0, gain_db=0, start=True, fout=0.3)],
    }),
    "C": ("Hummingbird: a bird trill as it lifts off, a fast wing-buzz while it heals, a happy chime on arrival, a short trill as it flies home", {
        "launch": [dict(name="Bird_Flutes_3", t0=0.03, t1=0.55, at=0.0, gain_db=-2, start=True, fout=0.15),
                   dict(name="ClothMovement24", t0=0.5, t1=0.95, at=0.45, gain_db=-6, fout=0.1)],
        "arrive": [dict(name="Game_Entry_Happy_Short", t0=0.0, t1=0.85, at=0.0, gain_db=0, start=True, fout=0.25)],
        "loop": [dict(name="Quadcopter_Toy_Flying_Sustained", t0=12.0, t1=13.6, at=0.0, gain_db=-4, semis=7, hp=900, lp=7000),
                 dict(name="Ambience_Forest_Crickets_Birds_Connecticut_02", t0=4.0, t1=5.6, at=0.0, gain_db=-12)],
        "end": [dict(name="Bird_Flutes_3", t0=0.36, t1=0.8, at=0.0, gain_db=-2, start=True, fout=0.15)],
    }),
}
SETS["lantern"] = {
    "A": ("Tesla lantern: a glass clink and a whoosh as it is lobbed, a metal clank as it lands, a crackling arc on every zap", {
        "throw": [dict(name="Metal_Old_File_Impact_Tap", t0=0.0, t1=0.3, at=0.0, gain_db=-4, start=True, semis=5),
                  dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=WINDUP, gain_db=-3, start=True)],
        "land": [dict(name="Case_Closed06", t0=0.0, t1=0.5, at=0.0, gain_db=0, start=True, fout=0.15),
                 dict(name="Metal_Old_File_Impact_Tap", t0=0.0, t1=0.3, at=0.0, gain_db=-6)],
        "zap": [dict(name="ArcDesign15", t0=0.0, t1=0.6, at=0.0, gain_db=0, start=True, fout=0.15),
                dict(name="ELECBuzz_Buzz27", t0=2.0, t1=2.5, at=0.0, gain_db=-6, start=True, fout=0.2)],
    }),
    "B": ("Storm jar: a rising hum and a whoosh as it is lobbed, a glassy snap as it lands, a deep thunder-zap on every zap", {
        "throw": [dict(name="ArcPowerUpDesign04", t0=4.4, t1=4.85, at=0.0, gain_db=-5, start=True, fin=0.05, fout=0.05),
                  dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.6, at=WINDUP, gain_db=-4, semis=3, start=True, fout=0.2)],
        "land": [dict(name="Interface_Glassy_Snap", t0=0.0, t1=0.35, at=0.0, gain_db=0, start=True)],
        "zap": [dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.8, at=0.0, gain_db=0, fout=0.3),
                dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=-4, start=True)],
    }),
    "C": ("Firefly lamp: a soft pluck as it is lobbed, a wooden tok as it lands, a buzzing glitch-sting on every zap", {
        "throw": [dict(name="Interface_Plucks_Happy", t0=0.08, t1=0.5, at=0.0, gain_db=-3, start=True, fout=0.1),
                  dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=WINDUP, gain_db=-6, semis=5, start=True)],
        "land": [dict(name="Game_Play_Piece_Action_Organic_Connect_Dots_Fall_Bounce_04", t0=0.08, t1=0.22, at=0.0, gain_db=0, start=True)],
        "zap": [dict(name="Glitch_High_Electronic", t0=3.0, t1=3.45, at=0.0, gain_db=-2, start=True, fout=0.15),
                dict(name="Interface_Pop_High_Short", t0=0.0, t1=0.12, at=0.0, gain_db=-4, start=True)],
    }),
}
SETS["sap"] = {
    "A": ("Amber wall: a wet spit as the pod is thrown, a gooey splat and a creaking rise as the wall goes up, a crackle as it crumbles", {
        "throw": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.3, at=THROW, gain_db=-3, semis=-5, start=True, fout=0.1)],
        "rise": [dict(name="Liquid_Impact_Bubble", t0=0.1, t1=0.7, at=0.0, gain_db=0, semis=-4, fout=0.25),
                 dict(name="Metal_Scrape_Low_Tonal", t0=3.0, t1=4.0, at=0.05, gain_db=-6, start=True, lp=2500, fout=0.4)],
        "end": [dict(name="ice_block_snapping", t0=0.48, t1=1.2, at=0.0, gain_db=-2, lp=4000, fout=0.3),
                dict(name="Cartoon_Bubbles_Short", t0=0.0, t1=0.4, at=0.05, gain_db=-8, start=True, semis=-5)],
    }),
    "B": ("Tree resin: a squishy frog-plop as the pod is thrown, a wet slap and a wooden creak as the wall goes up, a cracking crumble as it breaks", {
        "throw": [dict(name="Animal_Frog_Echo_Short_Squished_Frequency_Formant_03", t0=0.0, t1=0.3, at=THROW, gain_db=-2, start=True, fout=0.1)],
        "rise": [dict(name="Dinosaur_Eating_Meat_01", t0=0.8, t1=1.2, at=0.0, gain_db=0, fout=0.15),
                 dict(name="Cartoon_Airy_Impact_Creaks", t0=1.0, t1=2.0, at=0.08, gain_db=-4, start=True, fout=0.4)],
        "end": [dict(name="surface_cracking_fissure", t0=0.25, t1=1.2, at=0.0, gain_db=0, start=True, fout=0.35)],
    }),
    "C": ("Goo barrier: a cartoon pop as the pod is thrown, a deep slurping gloop as the wall goes up, a bubbly fizz as it melts", {
        "throw": [dict(name="Cartoon_Pops", t0=0.06, t1=0.3, at=THROW, gain_db=-2, start=True, fout=0.05)],
        "rise": [dict(name="Impact_Water_Deep_Submerge", t0=0.0, t1=0.8, at=0.0, gain_db=0, fout=0.3),
                 dict(name="Blood_Spill_Splat", t0=0.2, t1=0.33, at=0.0, gain_db=-4, semis=-3)],
        "end": [dict(name="Cartoon_Bubbles_Short", t0=0.0, t1=0.8, at=0.0, gain_db=0, start=True, semis=-3, fout=0.25),
                dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.05, gain_db=-8, start=True)],
    }),
}
SETS["shed"] = {
    "A": ("Feather burst: a tearing rip as it breaks free, a fluttering whoosh of feathers as they blast out", {
        "snap": [dict(name="VelcroRip29", t0=0.1, t1=0.41, at=0.0, gain_db=0, start=True)],
        "burst": [dict(name="Cofetti_Whoosh_Pluck_Spill", t0=0.2, t1=1.0, at=0.0, gain_db=0, fout=0.3),
                  dict(name="ClothMovement24", t0=0.5, t1=0.95, at=0.0, gain_db=-5, fout=0.1)],
    }),
    "B": ("Bird flush: a sharp snap as it breaks free, a burst of bird trills and debris as the feathers blast out", {
        "snap": [dict(name="Interface_Percussion_Snap", t0=0.0, t1=0.3, at=0.0, gain_db=0, start=True)],
        "burst": [dict(name="Bird_Flutes_3", t0=0.03, t1=0.6, at=0.0, gain_db=-2, start=True, fout=0.2),
                  dict(name="Woosh_Debris", t0=0.3, t1=1.0, at=0.0, gain_db=-4, fout=0.3)],
    }),
    "C": ("Pillow pop: a springy boing as it breaks free, a soft cloth whomp and a swoosh as the feathers blast out", {
        "snap": [dict(name="Accept_Boing_Crunch", t0=0.0, t1=0.45, at=0.0, gain_db=0, start=True, fout=0.12)],
        "burst": [dict(name="Action_Inventory_Open_Flip_Cloth_Canvas_Bag_Slide_Light_02", t0=0.0, t1=0.6, at=0.0, gain_db=0, fout=0.2),
                  dict(name="Cartoon_Pull_Swoosh", t0=0.0, t1=0.6, at=0.0, gain_db=-5, start=True, fout=0.2)],
    }),
}
SETS["portal"] = {
    "A": ("Astral rift: a rising energy tear as it starts, a flowing astral stream while you walk the path, a big magic bloom as it opens, a rushing whoosh when someone rides it", {
        "tear": [dict(name="ArcPowerUpDesign04", t0=4.2, t1=4.85, at=0.0, gain_db=-2, start=True, fin=0.05, fout=0.1)],
        "trail": [dict(name="Magic_Astral_Travel", t0=6.0, t1=7.6, at=0.0, gain_db=0)],
        "open": [dict(name="Magic_Energy_Astonishment", t0=1.9, t1=3.0, at=0.0, gain_db=0, start=True, fin=0.01, fout=0.5),
                 dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=-5, start=True)],
        "travel": [dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.8, at=0.0, gain_db=0, semis=2, fout=0.3),
                   dict(name="Magic_Astral_Travel", t0=12.0, t1=12.6, at=0.0, gain_db=-6, start=True, fin=0.05, fout=0.3)],
    }),
    "B": ("Sci-fi warp: a glitchy rip as it starts, a low UFO drone while you walk the path, a bass burst and a crackle as it opens, a zooming pass when someone rides it", {
        "tear": [dict(name="Glitch_Corrupted_Data", t0=2.05, t1=2.45, at=0.0, gain_db=0, start=True, fout=0.1)],
        "trail": [dict(name="Unidentified_Encounter", t0=7.0, t1=8.6, at=0.0, gain_db=0)],
        "open": [dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=0, start=True),
                 dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.8, at=0.0, gain_db=-3, fout=0.3)],
        "travel": [dict(name="Kawasaki_Ninja_ZX_10R_Pass_By_Fast", t0=4.6, t1=5.3, at=0.0, gain_db=0, semis=4, fin=0.03, fout=0.25)],
    }),
    "C": ("Feather path: a bird trill as it starts, tinkling bells and wind while you walk the path, a sparkling bell bloom as it opens, a quick swoosh when someone rides it", {
        "tear": [dict(name="Bird_Flutes_3", t0=0.03, t1=0.45, at=0.0, gain_db=-2, start=True, fout=0.12)],
        "trail": [dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=12.0, t1=13.6, at=0.0, gain_db=0),
                  dict(name="Wind_Whipping_Constricted_Flow", t0=4.0, t1=5.6, at=0.0, gain_db=-10, hp=1200)],
        "open": [dict(name="Magic_Christmas_Bells_2", t0=2.15, t1=3.3, at=0.0, gain_db=0, start=True, fout=0.4),
                 dict(name="Magic_Light_Spell", t0=0.55, t1=1.4, at=0.0, gain_db=-4, start=True, fin=0.01, fout=0.4)],
        "travel": [dict(name="Cartoon_Pull_Swoosh", t0=0.0, t1=0.6, at=0.0, gain_db=0, start=True, fout=0.2)],
    }),
}
SETS["burst"] = {
    "A": ("Seed pod: a soft pluck as the bud is thrown, a magic bloom with a kalimba rise as it bursts", {
        "throw": [dict(name="Interface_Plucks_Happy", t0=0.08, t1=0.5, at=0.0, gain_db=-4, start=True, fout=0.1),
                  dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=THROW, gain_db=-6, semis=4, start=True)],
        "bloom": [dict(name="Magic_Light_Spell", t0=0.55, t1=1.6, at=0.0, gain_db=0, start=True, fin=0.01, fout=0.4),
                  dict(name="UIMisc_Kalimba_3_Up", t0=0.0, t1=0.55, at=0.0, gain_db=-3, start=True, fout=0.15)],
    }),
    "B": ("Spring bloom: a cartoon pop as the bud is thrown, a happy chime with bird trills and a spritz as it bursts", {
        "throw": [dict(name="Cartoon_Pops", t0=0.06, t1=0.3, at=THROW, gain_db=-2, start=True, fout=0.05)],
        "bloom": [dict(name="Game_Entry_Happy_Short", t0=0.0, t1=0.85, at=0.0, gain_db=0, start=True, fout=0.25),
                  dict(name="Bird_Flutes_3", t0=0.03, t1=0.6, at=0.05, gain_db=-6, start=True, fout=0.2),
                  dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=-10, start=True)],
    }),
    "C": ("Power bloom: a swooshing toss as the bud is thrown, a bright power-up crash with jingling bells as it bursts", {
        "throw": [dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=THROW, gain_db=-2, start=True)],
        "bloom": [dict(name="Power_Up_Bright", t0=0.06, t1=1.2, at=0.0, gain_db=0, start=True, fout=0.4),
                  dict(name="Magic_Christmas_Bells_2", t0=2.15, t1=3.0, at=0.05, gain_db=-6, start=True, fout=0.3)],
    }),
}
SETS["dome"] = {
    "A": ("Force field: a whoosh as it is thrown, a powering-up crack as the dome snaps open, a deep electric hum while it holds, a power-down as it fades", {
        "throw": [dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=THROW, gain_db=-3, start=True)],
        "open": [dict(name="ArcPowerUpDesign04", t0=4.4, t1=4.85, at=0.0, gain_db=-2, start=True, fin=0.02, fout=0.05),
                 dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.1, gain_db=-3, start=True)],
        "loop": [dict(name="Deep_Fridge_Hum_Buzz_Electric_Tone_Deep", t0=16.0, t1=17.6, at=0.0, gain_db=-2, lp=4000),
                 dict(name="Electricity_Hum_Lightbulb", t0=10.0, t1=11.6, at=0.0, gain_db=-10)],
        "close": [dict(name="Power_Button_003", t0=0.3, t1=0.7, at=0.0, gain_db=0, semis=-3),
                  dict(name="Tone_Downer", t0=0.0, t1=0.8, at=0.0, gain_db=-6, start=True, fout=0.3)],
    }),
    "B": ("Bubble: a cartoon pop as it is thrown, a wobbly bubble bloom as the dome opens, a shimmering bell hum while it holds, a bubbly pop as it fades", {
        "throw": [dict(name="Cartoon_Pops", t0=0.06, t1=0.3, at=THROW, gain_db=-2, start=True, fout=0.05)],
        "open": [dict(name="Liquid_Impact_Bubble", t0=0.1, t1=0.8, at=0.0, gain_db=0, semis=3, fout=0.3),
                 dict(name="Magic_Light_Spell", t0=0.55, t1=1.3, at=0.0, gain_db=-6, start=True, fin=0.01, fout=0.3)],
        "loop": [dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=20.0, t1=21.6, at=0.0, gain_db=-2),
                 dict(name="Dark_Loop_Mystic_Forest_Tonal_Steady_Synth", t0=8.0, t1=9.6, at=0.0, gain_db=-8)],
        "close": [dict(name="Cartoon_Bubbles_Short", t0=0.0, t1=0.5, at=0.0, gain_db=0, start=True, fout=0.15)],
    }),
    "C": ("Leaf canopy: a cloth toss as it is thrown, a gust and a magic swell as the dome opens, a low forest drone with birds while it holds, a falling arpeggio as it fades", {
        "throw": [dict(name="ClothMovement24", t0=0.5, t1=0.95, at=THROW, gain_db=-2, fout=0.1)],
        "open": [dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.8, at=0.0, gain_db=-2, semis=-2, fout=0.3),
                 dict(name="Magic_Creation_23", t0=0.0, t1=0.9, at=0.0, gain_db=-4, start=True, fin=0.02, fout=0.3)],
        "loop": [dict(name="Dark_Loop_Mystic_Forest_Tonal_Steady_Synth", t0=12.0, t1=13.6, at=0.0, gain_db=-2),
                 dict(name="Ambience_Forest_Crickets_Birds_Connecticut_02", t0=8.0, t1=9.6, at=0.0, gain_db=-8)],
        "close": [dict(name="Interface_Arp_Reveal_Down_Long", t0=0.0, t1=1.0, at=0.0, gain_db=0, start=True, fout=0.3)],
    }),
}
SETS["sleep"] = {
    "A": ("Lullaby dart: a music-box wind-up as the neck coils, a soft blowgun puff as the dart flies, a music-box note on the hit, a slow music-box lullaby while it sleeps", {
        "coil": [dict(name="SBmb_Music_Box_C_Wind_Up_006", t0=0.0, t1=0.35, at=0.0, gain_db=-3, start=True, fout=0.08)],
        "fire": [dict(name="Exhale_Creature", t0=0.0, t1=0.3, at=0.0, gain_db=-2, semis=5, start=True, hp=600, fout=0.08)],
        "hit": [dict(name="Spear_And_Stick_Impact", t0=0.03, t1=0.25, at=0.0, gain_db=-4, semis=5, start=True, fout=0.05),
                dict(name="SBmb_Music_Box_A_013", t0=0.0, t1=1.4, at=0.02, gain_db=0, start=True, fout=0.6)],
        "snore": [dict(name="SBmb_Music_Box_C_059", t0=0.0, t1=1.4, at=0.0, gain_db=-4, start=True),
                  dict(name="SBmb_Music_Box_B_028", t0=0.0, t1=1.4, at=0.7, gain_db=-6, start=True)],
    }),
    "B": ("Tranq dart: a latch click as the neck coils, an air-gun pop as the dart flies, a smack and a dozing slide-down on the hit, a raspy snore while it sleeps", {
        "coil": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.3, at=0.0, gain_db=-2, start=True)],
        "fire": [dict(name="Paintball_Firefight", t0=1.82, t1=1.98, at=0.0, gain_db=0, start=True, fout=0.05)],
        "hit": [dict(name="Quick_Smack", t0=0.0, t1=0.3, at=0.0, gain_db=-2, start=True, semis=3),
                dict(name="Cartoon_Transition_Bass_Down", t0=0.75, t1=1.8, at=0.05, gain_db=-4, start=True, fout=0.4)],
        "snore": [dict(name="Respirator_Breathing", t0=2.0, t1=3.4, at=0.0, gain_db=0, semis=-4, lp=1800)],
    }),
    "C": ("Sleepy whistle: a whistled breath in as the neck coils, a quick whistle-swoosh as the dart flies, a dizzy wobble on the hit, a night of crickets while it sleeps", {
        "coil": [dict(name="Screeching_Breath_Inhale", t0=0.0, t1=0.35, at=0.0, gain_db=-4, start=True, lp=5000, fout=0.08)],
        "fire": [dict(name="Whistle_Male_06_09", t0=0.18, t1=0.36, at=0.0, gain_db=-2, start=True, fout=0.05),
                 dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.3, at=0.0, gain_db=-6, semis=6, start=True)],
        "hit": [dict(name="Cartoon_Confused_Dizzy", t0=0.0, t1=0.9, at=0.0, gain_db=0, start=True, fout=0.3)],
        "snore": [dict(name="Loop_Ambience_Jungle_Night_Humid_Birds_Bug_Chirps_01", t0=6.0, t1=7.6, at=0.0, gain_db=-2, lp=7000)],
    }),
}
SETS["sentry"] = {
    "A": ("Clockwork turret: a whoosh as the pod is thrown, a case unlatching and lock clicks as it unfolds, a sharp pop on every shot, a lid snapping shut as it folds away", {
        "throw": [dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=THROW, gain_db=-3, start=True)],
        "deploy": [dict(name="Suitcase_Opening_and_Closing_Antique_Suitcase", t0=0.5, t1=0.9, at=0.0, gain_db=0, start=True, fout=0.1),
                   dict(name="Tinkering_Antique_Lock", t0=1.18, t1=1.45, at=0.25, gain_db=-4, start=True, fout=0.08)],
        "shot": [dict(name="Interface_Pop_High_Short", t0=0.0, t1=0.12, at=0.0, gain_db=0, start=True, semis=-3),
                 dict(name="Paintball_Firefight", t0=1.82, t1=1.95, at=0.0, gain_db=-6, start=True, fout=0.04)],
        "fold": [dict(name="Suitcase_Opening_and_Closing_Antique_Suitcase", t0=5.65, t1=6.1, at=0.0, gain_db=0, start=True, fout=0.12)],
    }),
    "B": ("Robo turret: a whoosh as the pod is thrown, a servo whine as it unfolds, an air-gun pop on every shot, a power-down as it folds away", {
        "throw": [dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.5, at=THROW, gain_db=-4, semis=3, start=True, fout=0.15)],
        "deploy": [dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.05, t1=0.9, at=0.0, gain_db=0, start=True, fout=0.2)],
        "shot": [dict(name="Paintball_Firefight", t0=1.82, t1=1.98, at=0.0, gain_db=0, start=True, fout=0.05)],
        "fold": [dict(name="Power_Button_003", t0=0.3, t1=0.7, at=0.0, gain_db=0, semis=-3),
                 dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.05, t1=0.5, at=0.0, gain_db=-6, semis=-5, start=True, fout=0.2)],
    }),
    "C": ("Seed spitter: a pluck as the pod is thrown, wooden pieces clattering into place as it unfolds, a pea-shooter pop on every shot, a rattle of pieces as it folds away", {
        "throw": [dict(name="Interface_Plucks_Happy", t0=0.08, t1=0.5, at=THROW, gain_db=-4, start=True, fout=0.1)],
        "deploy": [dict(name="Event_Board_Reset_Organic_Multiple_Pieces_Wood_Small_02", t0=0.0, t1=0.7, at=0.0, gain_db=0, start=True, fout=0.2)],
        "shot": [dict(name="Cartoon_Pops", t0=0.06, t1=0.2, at=0.0, gain_db=0, start=True, fout=0.03),
                 dict(name="Game_Play_Piece_Action_Organic_Connect_Dots_Fall_Bounce_04", t0=0.1, t1=0.22, at=0.0, gain_db=-6, start=True)],
        "fold": [dict(name="Event_Board_Reset_Organic_Multiple_Pieces_Wood_Small_02", t0=0.55, t1=1.1, at=0.0, gain_db=0, start=True, fout=0.2)],
    }),
}
LOOPS = {("mender", "loop"): 1.4, ("portal", "trail"): 1.4, ("dome", "loop"): 1.4, ("sleep", "snore"): 1.4}
POST_DB = {  # parts that level() pushes too loud (bass-heavy sources, short whooshes): brought down toward about -14 dB full-band RMS
    ("dome", "close", "A"): -11.0, ("dome", "loop", "A"): -5.0, ("sap", "rise", "B"): -7.0, ("burst", "throw", "C"): -3.0,
    ("dome", "throw", "A"): -3.0, ("sentry", "throw", "A"): -3.0}
MAXLEN = {("lantern", "zap"): 0.6, ("sentry", "shot"): 0.25, ("sleep", "hit"): 1.4}
meta = {}
for mv, opts in SETS.items():
    for opt, (desc, parts) in opts.items():
        for part, layers in parts.items():
            y = loop(layers, LOOPS[(mv, part)]) if (mv, part) in LOOPS else one_shot(layers, max_len=MAXLEN.get((mv, part)))
            y = y * 10 ** (POST_DB.get((mv, part, opt), 0.0) / 20.0)
            fn = f"MDA_SFX_troo2_{mv}{part}_{opt}.wav"
            sf.write(os.path.join(OUT, fn), y, SR, subtype="PCM_16")
            meta.setdefault(mv, {}).setdefault(opt, {"desc": desc, "parts": {}})["parts"][part] = {
                "file": fn, "len": round(len(y) / SR, 3), "loop": (mv, part) in LOOPS}
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
for mv, opts in meta.items():
    for opt, d in opts.items():
        print(mv, opt, " ".join(f"{p}={v['len']}s{'(loop)' if v['loop'] else ''}" for p, v in d["parts"].items()))
