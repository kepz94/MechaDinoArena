r"""Raptor ability sounds v2 (MDA-552, Kepu 2026-11-17 18:40 "1. Okay let's do this now": the Raptor gets the record-the-game
pick page the Pachy got in round 11). Sonniss GDC 2026 sources (not in this repo; the converted sources are in Kepu's
Music\MechaDinoArena_SFX\_work_titles_sonniss), same engine as gen_pachy_v2_sfx.py (each option is a SET of parts, each part
scheduled at a stamp; t = 0 of a clip is its stamp). Beats from the Studio recordings in tools/mockup/raptor_rec (2026-11-17):
  cloak  on @ CloakStartedAt (the shimmer covers it by +0.55 s) | off @ CloakState "off" (CloakFX fades 0.32 s)
  shield up @ EnergyShieldStartedAt | hum (loop) +0.10 .. EnergyShieldUntil | down @ EnergyShieldUntil | block @ EnergyShieldBlockAt
  adren  inject @ AdrenalineStartedAt | rush (loop) +0.30 .. AdrenalineUntil | end @ AdrenalineUntil
  cannon charge (loop) from the press (the aim laser) .. ScreechStartedAt | fire @ ScreechStartedAt | hit @ the target's ScreechHitAt
  scent  sniff @ ScentStartedAt | aura (loop) +0.60 .. ScentUntil | end @ ScentUntil (only you hear scent)
Run: python3 -I gen_raptor_v2_sfx.py <src_dir> <out_dir>."""
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
         "ArcPowerUpDesign04", "Magic_Light_Spell", "Alert_Swell_Creature", "Quadcopter_Beeps", "Wind_Whipping_Constricted_Flow"}
HB = lambda at, g=0: [dict(name="Punch_Body_02", t0=1.13, t1=1.45, at=at, gain_db=g, lp=700, semis=-5, start=True),
                      dict(name="Punch_Body_02", t0=1.13, t1=1.40, at=at + 0.14, gain_db=g - 5, lp=800, semis=-3, start=True)]
SETS = {}
SETS["cloak"] = {
    "A": ("Light bend: a glassy shimmer sweeps over it as it fades out; a soft falling arpeggio as it reappears", {
        "on": [dict(name="Magic_Light_Spell", t0=0.55, t1=1.75, at=0.0, gain_db=0, fin=0.08, fout=0.4, start=True),
               dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=0.12, gain_db=-4, semis=-3)],
        "off": [dict(name="Interface_Arp_Reveal_Down_Long", t0=0.0, t1=0.75, at=0.0, gain_db=0, semis=-2, start=True),
                dict(name="Magic_Light_Spell", t0=1.2, t1=1.8, at=0.0, gain_db=-8, fin=0.05, fout=0.3, start=True)],
    }),
    "B": ("Electro camo: a crackling arc and a digital glitch as the skin switches off; a click and a glitch as it drops", {
        "on": [dict(name="ArcDesign15", t0=0.0, t1=0.5, at=0.0, gain_db=0, start=True, fout=0.15),
               dict(name="Glitch_Corrupted_Data", t0=1.75, t1=2.3, at=0.08, gain_db=-2, start=True, fout=0.15),
               dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.6, at=0.25, gain_db=-8, semis=2)],
        "off": [dict(name="Power_Button_003", t0=0.3, t1=0.7, at=0.0, gain_db=-2, semis=-3),
                dict(name="Glitch_Corrupted_Data", t0=2.05, t1=2.45, at=0.02, gain_db=-4, start=True, fout=0.12)],
    }),
    "C": ("Ghost fade: a breathy rising whoosh and a dark swell as it vanishes; a quick swish and a low thump as it snaps back", {
        "on": [dict(name="Magic_Energy_Astonishment", t0=1.9, t1=3.0, at=0.0, gain_db=0, fin=0.05, fout=0.4, start=True),
               dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=0.7, at=0.2, gain_db=-3, semis=-4)],
        "off": [dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.45, at=0.0, gain_db=0, semis=-5, start=True),
                dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.5, at=0.12, gain_db=-6, lp=900)],
    }),
}
SETS["shield"] = {
    "A": ("Hard-light shell: a bass burst and an electric crack as it snaps on, a buzzing power hum while it holds, a falling sci-fi ping as it drops", {
        "up": [dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=0, start=True),
               dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.9, at=0.03, gain_db=-3, fout=0.3)],
        "hum": [dict(name="Electricity_Hum_Lightbulb", t0=4.0, t1=5.4, at=0.0, gain_db=0),
                dict(name="ELECBuzz_Buzz27", t0=4.0, t1=5.4, at=0.0, gain_db=-9)],
        "down": [dict(name="Interface_SciFi_Ping_Down", t0=0.0, t1=0.6, at=0.0, gain_db=0, start=True)],
        "block": [dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.6, at=0.0, gain_db=0, semis=3),
                  dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.5, at=0.0, gain_db=-6, lp=1500)],
    }),
    "B": ("Force bubble: a rising power-up swell as it inflates, a warm reactor hum with metal shimmer, a power-off click as it pops", {
        "up": [dict(name="ArcPowerUpDesign04", t0=4.95, t1=5.6, at=0.0, gain_db=-2, fin=0.08, start=True, fout=0.15),
               dict(name="Power_Up_Bright", t0=0.06, t1=1.0, at=0.0, gain_db=-4, start=True, fout=0.3)],
        "hum": [dict(name="Scifi_Loop_Ship_Reactor", t0=20.0, t1=21.4, at=0.0, gain_db=0, semis=4),
                dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=10.0, t1=11.4, at=0.0, gain_db=-10)],
        "down": [dict(name="Power_Button_003", t0=0.3, t1=0.7, at=0.0, gain_db=0, semis=-4),
                 dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.02, gain_db=-6, semis=-3, start=True)],
        "block": [dict(name="Metal_Shield_Spin_On_Floor", t0=0.0, t1=0.6, at=0.0, gain_db=0, semis=2),
                  dict(name="ArcDesign15", t0=0.0, t1=0.4, at=0.0, gain_db=-4)],
    }),
    "C": ("Wobble dome: a bright magic shimmer as it forms, a wobbling static drone while it holds, a glitch as it collapses", {
        "up": [dict(name="Magic_Light_Spell", t0=0.7, t1=1.6, at=0.0, gain_db=0, fin=0.03, fout=0.35, start=True),
               dict(name="Interface_SciFi_Ping_Down", t0=0.0, t1=0.4, at=0.0, gain_db=-5, semis=7, start=True)],
        "hum": [dict(name="Radio_Static_Hum", t0=6.0, t1=7.4, at=0.0, gain_db=0, lp=1800),
                dict(name="Magic_Drone_Spellbound", t0=8.0, t1=9.4, at=0.0, gain_db=-4)],
        "down": [dict(name="Glitch_Corrupted_Data", t0=1.75, t1=2.2, at=0.0, gain_db=0, start=True, fout=0.12)],
        "block": [dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.5, at=0.0, gain_db=0, semis=5),
                  dict(name="Glass_Crystal_Fragments_Sharp", t0=0.0, t1=0.4, at=0.0, gain_db=-8)],
    }),
}
SETS["adren"] = {
    "A": ("Injector + heartbeat: a latch click and a hiss as the needle goes in with a gasp, a pounding fast heartbeat while it runs, a long breath out at the end", {
        "inject": [dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.3, at=0.0, gain_db=-3, semis=2),
                   dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.02, gain_db=0, start=True),
                   dict(name="Gasp_Male", t0=0.0, t1=0.3, at=0.12, gain_db=-5, semis=-3)],
        "rush": HB(0.0) + HB(0.43, -1),
        "end": [dict(name="Exhale_Creature", t0=0.0, t1=0.43, at=0.0, gain_db=0, semis=-4, start=True, lp=3000)],
    }),
    "B": ("Pressure shot: a pump stroke, a bright power-up as the dose kicks in, fast panting breaths while it runs, a hiss as it wears off", {
        "inject": [dict(name="Barber_Chair_Foot_Pump", t0=0.2, t1=0.5, at=0.0, gain_db=-2, start=True),
                   dict(name="Power_Up_Bright", t0=0.06, t1=1.1, at=0.08, gain_db=-2, start=True, fout=0.3)],
        "rush": [dict(name="Panting_Male", t0=0.0, t1=0.86, at=0.0, gain_db=-2, semis=-6, lp=2500)] + HB(0.0, -6) + HB(0.43, -7),
        "end": [dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.0, gain_db=0, semis=-5, start=True, fout=0.2)],
    }),
    "C": ("Raptor rush: a snort and a needle hiss, a rushing wind with a heartbeat while it runs, a low satisfied growl at the end", {
        "inject": [dict(name="Raptor_Flair", t0=0.05, t1=0.6, at=0.0, gain_db=0, start=True, fout=0.15),
                   dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.1, gain_db=-3, semis=3, start=True)],
        "rush": [dict(name="Wind_Whipping_Constricted_Flow", t0=1.0, t1=1.86, at=0.0, gain_db=-4)] + HB(0.0, -2) + HB(0.43, -3),
        "end": [dict(name="Werewolf_Growl", t0=0.2, t1=0.9, at=0.0, gain_db=-4, semis=4, start=True, fout=0.3)],
    }),
}
SETS["cannon"] = {
    "A": ("Tesla cannon: a crackling electric buzz while the laser aims, a bass-burst crack on the shot, an arc zap with a small blast on the hit", {
        "charge": [dict(name="ELECBuzz_Buzz27", t0=2.0, t1=2.8, at=0.0, gain_db=0),
                   dict(name="Electricity_Hum_Lightbulb", t0=4.0, t1=4.8, at=0.0, gain_db=-4, semis=5)],
        "fire": [dict(name="Collect_Scifi_Bass_Burst", t0=0.0, t1=0.31, at=0.0, gain_db=0, start=True),
                 dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.7, at=0.0, gain_db=-2, fout=0.25)],
        "hit": [dict(name="ArcDesign15", t0=0.0, t1=0.6, at=0.0, gain_db=0, start=True),
                dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.6, at=0.0, gain_db=-4, semis=4)],
    }),
    "B": ("Plasma ball: a reactor whine winding up while it aims, a jet-blast thump on the shot, a thunder crack and crackle on the hit", {
        "charge": [dict(name="Scifi_Loop_Ship_Reactor", t0=20.0, t1=20.8, at=0.0, gain_db=0, semis=9),
                   dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=10.0, t1=10.8, at=0.0, gain_db=-10)],
        "fire": [dict(name="Blast_Off_Clean", t0=3.0, t1=3.5, at=0.0, gain_db=0, start=True, fout=0.15),
                 dict(name="Interface_SciFi_Ping_Down", t0=0.0, t1=0.5, at=0.0, gain_db=-4, start=True)],
        "hit": [dict(name="Texas_Rain_Thunder_Initial_Crash", t0=0.0, t1=0.9, at=0.0, gain_db=0, fout=0.4),
                dict(name="ArcDesign15", t0=0.0, t1=0.5, at=0.02, gain_db=-5, start=True)],
    }),
    "C": ("Shock whip: a glitchy electric chatter while it aims, a whip-crack zap on the shot, a punchy electric thud on the hit", {
        "charge": [dict(name="Glitch_High_Electronic", t0=4.0, t1=4.8, at=0.0, gain_db=0, lp=6000)],
        "fire": [dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.5, at=0.0, gain_db=0, semis=3),
                 dict(name="ArcDesign15", t0=0.0, t1=0.4, at=0.0, gain_db=-4, start=True)],
        "hit": [dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=0.8, at=0.0, gain_db=0, fout=0.3),
                dict(name="Punch_Body_02", t0=1.13, t1=1.45, at=0.0, gain_db=-3)],
    }),
}
SETS["scent"] = {
    "A": ("Snort + chime: two quick raptor snorts and a soft twinkle, a faint bell shimmer while the trails glow, a falling chime as they fade", {
        "sniff": [dict(name="Raptor_Flair", t0=0.05, t1=0.4, at=0.0, gain_db=0, start=True, fout=0.08, hp=300),
                  dict(name="Raptor_Flair", t0=0.05, t1=0.4, at=0.28, gain_db=-1, start=True, fout=0.08, hp=300, semis=1),
                  dict(name="Button_Arp_Twinkle", t0=0.0, t1=1.0, at=0.5, gain_db=-6, start=True, fout=0.4)],
        "aura": [dict(name="Shimmer_Loop_Small_Bell_Metal_Taps", t0=12.0, t1=13.4, at=0.0, gain_db=0, lp=7000)],
        "end": [dict(name="Interface_Arp_Reveal_Down_Long", t0=0.0, t1=0.7, at=0.0, gain_db=0, semis=-5, start=True)],
    }),
    "B": ("Deep breath: a long sniffing breath in and a rising magic swell, a low mystic drone while the trails glow, a soft breath out as they fade", {
        "sniff": [dict(name="Panting_Male", t0=0.55, t1=0.9, at=0.0, gain_db=0, hp=1200, start=True, fout=0.1),
                  dict(name="Magic_Energy_Astonishment", t0=1.9, t1=3.0, at=0.2, gain_db=-4, fin=0.1, fout=0.4, start=True)],
        "aura": [dict(name="Magic_Drone_Spellbound", t0=8.0, t1=9.4, at=0.0, gain_db=0)],
        "end": [dict(name="Exhale_Creature", t0=0.0, t1=0.43, at=0.0, gain_db=-2, semis=-2, start=True, lp=2500)],
    }),
    "C": ("Tracker: a snort and a radar ping, soft scanner beeps while the trails glow, a power-down blip as they fade", {
        "sniff": [dict(name="Raptor_Flair", t0=0.05, t1=0.4, at=0.0, gain_db=0, start=True, fout=0.08, hp=300),
                  dict(name="Interface_SciFi_Ping_Down", t0=0.0, t1=0.6, at=0.25, gain_db=-3, semis=5, start=True)],
        "aura": [dict(name="Quadcopter_Beeps", t0=0.15, t1=1.15, at=0.0, gain_db=0, hp=400)],
        "end": [dict(name="Thermometer_Beep", t0=0.0, t1=0.2, at=0.0, gain_db=0, semis=-5, start=True),
                dict(name="Power_Button_003", t0=0.3, t1=0.7, at=0.05, gain_db=-6, semis=-6)],
    }),
}
LOOPS = {("shield", "hum"): 1.0, ("adren", "rush"): 0.86, ("cannon", "charge"): 0.6, ("scent", "aura"): 1.0}
POST_DB = {("adren", "rush", "A"): -8.0}  # a heartbeat alone has almost nothing above 200 Hz, so level() would push it far too loud
MAXLEN = {("cloak", "on"): 1.3, ("shield", "up"): 0.9, ("cannon", "hit"): 0.9}
meta = {}
for mv, opts in SETS.items():
    for opt, (desc, parts) in opts.items():
        for part, layers in parts.items():
            y = loop(layers, LOOPS[(mv, part)]) if (mv, part) in LOOPS else one_shot(layers, max_len=MAXLEN.get((mv, part)))
            y = y * 10 ** (POST_DB.get((mv, part, opt), 0.0) / 20.0)
            fn = f"MDA_SFX_raptor2_{mv}{part}_{opt}.wav"
            sf.write(os.path.join(OUT, fn), y, SR, subtype="PCM_16")
            meta.setdefault(mv, {}).setdefault(opt, {"desc": desc, "parts": {}})["parts"][part] = {
                "file": fn, "len": round(len(y) / SR, 3), "loop": (mv, part) in LOOPS}
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
for mv, opts in meta.items():
    for opt, d in opts.items():
        print(mv, opt, " ".join(f"{p}={v['len']}s{'(loop)' if v['loop'] else ''}" for p, v in d["parts"].items()))
