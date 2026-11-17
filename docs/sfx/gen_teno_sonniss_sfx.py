"""Teno ability sounds, round 8 (Sonniss GDC 2026 bundle sources). Builds 3 options per sound from real recordings:
trim one take, optional varispeed pitch (resample), EQ, fades, layered with offsets, normalized. Mono 48 kHz 16-bit WAV.
Sources: the FLAC working copies in Music\\MechaDinoArena_SFX\\_work_teno_sonniss (mono 48 kHz conversions of the bundle
files). Run: python3 build_teno_sfx.py <src_dir> <out_dir>."""
import sys, os, json
import numpy as np, soundfile as sf
from scipy.signal import resample_poly, butter, sosfilt

SR = 48000
PHONE_RMS = -18.0   # loudness of the >= 200 Hz band (what a phone speaker plays)
BASS_MAX_DB = 6.0   # bass (< 200 Hz) at most this many dB over the phone band
SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
_cache = {}


def load(name):
    if name not in _cache:
        x, sr = sf.read(os.path.join(SRC, name + ".flac"))
        assert sr == SR
        _cache[name] = x.astype(np.float64)
    return _cache[name]


def layer(name, t0, t1, at=0.0, gain_db=0.0, semis=0.0, hp=None, lp=None, fin=0.005, fout=0.05):
    """One layer: source take [t0, t1] s, placed at `at` s, varispeed `semis` semitones, filters, fades."""
    x = load(name)[int(t0 * SR):int(t1 * SR)].copy()
    if semis:
        ratio = 2 ** (semis / 12.0)          # >1 = higher and shorter
        up, down = 1000, int(round(1000 * ratio))
        x = resample_poly(x, up, down)
    if hp:
        x = sosfilt(butter(2, hp, "hp", fs=SR, output="sos"), x)
    if lp:
        x = sosfilt(butter(2, lp, "lp", fs=SR, output="sos"), x)
    n = len(x)
    fi, fo = min(n, int(fin * SR)), min(n, int(fout * SR))
    if fi: x[:fi] *= np.linspace(0, 1, fi)
    if fo: x[-fo:] *= np.linspace(1, 0, fo)
    peak = np.max(np.abs(x)) + 1e-12
    x = x / peak * 10 ** (gain_db / 20.0)   # each layer peak-normalized, then its gain
    return int(at * SR), x


def render(layers, peak_db=-1.0, max_len=None):
    placed = [layer(**L) for L in layers]
    n = max(o + len(x) for o, x in placed)
    y = np.zeros(n)
    for o, x in placed:
        y[o:o + len(x)] += x
    if max_len:
        y = y[:int(max_len * SR)]
        f = int(0.06 * SR)
        y[-f:] *= np.linspace(1, 0, f)
    # 1) clear subsonics; 2) bass no louder than BASS_MAX_DB over the phone band (a phone speaker plays little under
    # ~200-350 Hz, so a sub-only sound would be near silent there); 3) level-match on the phone band (>= 200 Hz) to
    # PHONE_RMS; 4) soft-limit above 0.7 with a -1 dBFS ceiling.
    y = sosfilt(butter(2, 45, "hp", fs=SR, output="sos"), y)
    lo = sosfilt(butter(4, 200, "lp", fs=SR, output="sos"), y)
    hi = y - lo
    e_lo, e_hi = np.sqrt(np.mean(lo ** 2)) + 1e-12, np.sqrt(np.mean(hi ** 2)) + 1e-12
    lim = 10 ** (BASS_MAX_DB / 20.0)
    if e_lo > e_hi * lim:
        lo = lo * (e_hi * lim / e_lo)
    y = lo + hi
    ph = sosfilt(butter(4, 200, "hp", fs=SR, output="sos"), y)
    rms_ph = 20 * np.log10(np.sqrt(np.mean(ph ** 2)) + 1e-12)
    y = y * 10 ** ((PHONE_RMS - rms_ph) / 20.0)
    ceil, knee = 10 ** (peak_db / 20.0), 0.7
    over = np.abs(y) > knee
    y[over] = np.sign(y[over]) * (knee + (ceil - knee) * np.tanh((np.abs(y[over]) - knee) / (ceil - knee)))
    # trim leading / trailing near-silence (-60 dB)
    a = np.where(np.abs(y) > 10 ** (-60 / 20))[0]
    y = y[max(0, a[0] - int(0.002 * SR)):a[-1] + 1]
    return y


R = {}  # sound -> option -> (description, layers, kwargs)

R["tgrab"] = {  # Tail Grab & Fling, at the press (TenoGrabStartedAt): swing, catch at 0.3 s, fling
    "A": ("Heavy tail swing, a deep mechanical clamp on the catch, then a rattling metal fling whoosh", [
        dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.67, at=0.0, gain_db=-4, semis=-5, lp=6000),
        dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.28, gain_db=0, semis=-4),
        dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.69, at=0.30, gain_db=-8),
        dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=1.04, at=0.75, gain_db=-3, semis=-3),
    ], {}),
    "B": ("Real whip crack on the swing, servo whine as the tail clamps on", [
        dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.99, at=0.0, gain_db=-2, semis=-3),
        dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.69, at=0.26, gain_db=-3),
        dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.01, at=0.70, gain_db=-6, semis=-4),
    ], {}),
    "C": ("Big heavy-weapon swing into a thud (the catch), then a rushing throw whoosh", [
        dict(name="Quick_Heavy_Weapon_Swing_To_Thud", t0=0.0, t1=0.62, at=0.0, gain_db=-1, semis=-4),
        dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.01, at=0.60, gain_db=-3, semis=-2),
    ], {}),
}
R["tgrabland"] = {  # the flung dino hits the ground (TenoGrabLandAt, at TenoGrabLand)
    "A": ("Body slam: a punch-to-body hit over a dark heavy wooden thud", [
        dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.0, gain_db=0, semis=-3),
        dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=2.25, t1=3.17, at=0.0, gain_db=-3, lp=2500),
    ], {}),
    "B": ("Crunchy heavy smash (gore impact) with a low thump under it", [
        dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=1.05, at=0.0, gain_db=0),
        dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.8, at=0.0, gain_db=-6, lp=900),
    ], {}),
    "C": ("Cartoon bonk with creaks, plus a dirt-debris tail", [
        dict(name="Cartoon_Airy_Impact_Creaks", t0=0.54, t1=1.50, at=0.0, gain_db=0),
        dict(name="Woosh_Debris", t0=0.55, t1=1.03, at=0.05, gain_db=-8),
        dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.0, gain_db=-5),
    ], {}),
}
R["tmortar"] = {  # Boulder Mortar fires (TenoMortarFiredAt): the tail catapult throws the boulder
    "A": ("Wooden catapult arm thunk (pitched way down) and a debris whoosh as the boulder leaves", [
        dict(name="Spear_And_Stick_Impact", t0=0.02, t1=0.22, at=0.0, gain_db=0, semis=-9),
        dict(name="Woosh_Debris", t0=0.18, t1=1.03, at=0.04, gain_db=-3, semis=-3),
    ], {}),
    "B": ("Mechanical latch release, heavy metal throw whoosh, low thump", [
        dict(name="Click_Deep_Mechanism_Latch", t0=0.0, t1=0.30, at=0.0, gain_db=-2, semis=-5),
        dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=0.6, at=0.02, gain_db=-4, lp=700),
        dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=1.04, at=0.06, gain_db=-2, semis=-5),
    ], {}),
    "C": ("Dark heavy wooden hit with a long rushing whoosh (big siege-engine feel)", [
        dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=13.28, t1=14.09, at=0.0, gain_db=0),
        dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.01, at=0.05, gain_db=-3, semis=-5),
    ], {}),
}
R["tmortarboom"] = {  # the boulder lands (TenoMortarLandedAt, at TenoMortarLand, heard far like the missile blast)
    "A": ("Rock crunch (a heavy ice block crushed, pitched down) over a deep trailer boom", [
        dict(name="block_of_ice_crushed_heavy", t0=0.22, t1=1.66, at=0.0, gain_db=0, semis=-6),
        dict(name="EffectiveTrailer_Booms_Vol2_011", t0=0.25, t1=2.6, at=0.0, gain_db=-3, lp=1500),
    ], {"max_len": 2.4}),
    "B": ("Crunchy explosion-style boom with the ground cracking after", [
        dict(name="Explosion_Small_Blast_Enemy_Death", t0=0.0, t1=0.98, at=0.0, gain_db=0, semis=-4),
        dict(name="surface_cracking_fissure", t0=0.30, t1=1.95, at=0.10, gain_db=-5, semis=-4),
    ], {}),
    "C": ("Big cinematic boom, a rock snapping apart and falling rubble", [
        dict(name="EffectiveTrailer_Booms_Vol2_075", t0=0.24, t1=2.4, at=0.0, gain_db=0),
        dict(name="ice_block_snapping", t0=0.51, t1=1.6, at=0.0, gain_db=-3, semis=-7),
        dict(name="Woosh_Debris", t0=0.55, t1=1.31, at=0.25, gain_db=-3, semis=-2),
    ], {"max_len": 2.2}),
}
R["tstomp"] = {  # Stomp Shockwave hit (TenoStompAt)
    "A": ("Deep ground boom with the earth splitting (rock fissure crack)", [
        dict(name="EffectiveTrailer_Booms_Vol2_011", t0=0.25, t1=2.5, at=0.0, gain_db=0, lp=2000),
        dict(name="surface_cracking_fissure", t0=0.30, t1=1.95, at=0.02, gain_db=-4, semis=-5),
    ], {"max_len": 2.0}),
    "B": ("Heavy metal-foot thud with a low ring, a sub drop and crushed rubble (mecha stomp)", [
        dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=2.2, at=0.0, gain_db=0),
        dict(name="Bass_Drop_Downer_Fast_16", t0=0.08, t1=1.8, at=0.0, gain_db=-3),
        dict(name="block_of_ice_crushed_heavy", t0=0.22, t1=1.2, at=0.0, gain_db=-4, semis=-6),
        dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.0, gain_db=-4, semis=-3),
    ], {}),
    "C": ("Dark wooden slam into a thunder rumble (ground shake)", [
        dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=20.85, t1=21.77, at=0.0, gain_db=0, semis=-3),
        dict(name="Interior_Thunder_Rumble", t0=0.6, t1=2.6, at=0.0, gain_db=-3),
        dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=0.6, at=0.0, gain_db=-5),
    ], {"max_len": 2.0}),
}
R["tleap"] = {  # Hydraulic Leap launch (TenoLeapStartedAt)
    "A": ("Hydraulic pump hiss into a short jet blast (launch)", [
        dict(name="Barber_Chair_Foot_Pump", t0=0.20, t1=0.9, at=0.0, gain_db=-2, semis=-4),
        dict(name="Blast_Off_Clean", t0=0.16, t1=1.4, at=0.18, gain_db=0, fout=0.3),
    ], {}),
    "B": ("Servo whine and a pneumatic hiss, then a rising bass jump", [
        dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.69, at=0.0, gain_db=-1, semis=-3),
        dict(name="Spray_Bottle_Spray", t0=0.0, t1=0.47, at=0.05, gain_db=-4, semis=-7),
        dict(name="Jump_Start_Drop_3", t0=0.03, t1=1.4, at=0.15, gain_db=-2, fout=0.3),
    ], {}),
    "C": ("Clean jet blast-off with a metal rattle whoosh", [
        dict(name="Blast_Off_Clean", t0=0.16, t1=1.6, at=0.0, gain_db=0, fout=0.3),
        dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=1.04, at=0.1, gain_db=-4, semis=-3),
    ], {}),
}
R["tleapland"] = {  # Hydraulic Leap landing slam (TenoLeapLandedAt)
    "A": ("Heavy smash with a cinematic boom (big belly-flop landing)", [
        dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=1.05, at=0.0, gain_db=-1),
        dict(name="EffectiveTrailer_Booms_Vol2_214", t0=0.24, t1=2.0, at=0.0, gain_db=-3, lp=1800),
        dict(name="block_of_ice_crushed_heavy", t0=0.22, t1=1.0, at=0.0, gain_db=-6, semis=-6),
    ], {"max_len": 1.8}),
    "B": ("Mecha legs slamming down: metal thud with a low ring and rubble crunch", [
        dict(name="Metal_Hit_Thud_Thump_Low_Ring", t0=0.0, t1=1.6, at=0.0, gain_db=0),
        dict(name="block_of_ice_crushed_heavy", t0=0.22, t1=1.0, at=0.0, gain_db=-5, semis=-7),
    ], {}),
    "C": ("Dark wooden slam with dirt debris", [
        dict(name="Wooden_Hit_Dark_Heavy_Hit", t0=27.26, t1=28.07, at=0.0, gain_db=0, semis=-2),
        dict(name="Woosh_Debris", t0=0.55, t1=1.03, at=0.03, gain_db=-3),
        dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.0, gain_db=-4, semis=-4),
    ], {}),
}
R["tbellow"] = {  # Herd Bellow (TenoBellowAt)
    "A": ("A real large-herbivore dinosaur roar, first call, trimmed", [
        dict(name="Large_Herbivore_Roar_01", t0=0.14, t1=2.9, at=0.0, gain_db=0, fout=0.5),
    ], {}),
    "B": ("The herbivore roar's second call, a bit deeper, with a low war-horn braam under it (rallying the herd)", [
        dict(name="Large_Herbivore_Roar_01", t0=4.90, t1=7.7, at=0.0, gain_db=0, semis=-2, fout=0.5),
        dict(name="Cinematic_Horn_Braam_Epic_Cinematic_Dark", t0=0.15, t1=2.8, at=0.05, gain_db=-8, fout=0.6),
    ], {"max_len": 3.0}),
    "C": ("The herbivore roar with a low metal resonance (mecha chest)", [
        dict(name="Large_Herbivore_Roar_01", t0=0.14, t1=2.9, at=0.0, gain_db=0, fout=0.5),
        dict(name="Metal_Scrape_Low_Tonal", t0=0.3, t1=2.6, at=0.0, gain_db=-9, fout=0.6),
    ], {}),
}
R["tchallenge"] = {  # Challenge Call (TenoChallengeAt): a sharp taunt that marks enemies
    "A": ("Short sharp honk: the herbivore roar's opening, pitched up, with a chest thump", [
        dict(name="Large_Herbivore_Roar_01", t0=4.90, t1=6.2, at=0.0, gain_db=0, semis=3, fout=0.25),
        dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.0, gain_db=-6, semis=-6),
    ], {}),
    "B": ("Menacing creature growl-bark (werewolf growl source), cut short and pitched down", [
        dict(name="Werewolf_Growl", t0=0.18, t1=1.6, at=0.0, gain_db=0, semis=-3, fout=0.3),
    ], {}),
    "C": ("Dino hoot-call (the raptor flair pitched way down) over a charged-up heavy grunt", [
        dict(name="Raptor_Flair", t0=0.0, t1=1.67, at=0.0, gain_db=0, semis=-6, fout=0.3),
        dict(name="Orc_Male_Attack_Long_Heavy", t0=0.06, t1=1.2, at=0.0, gain_db=-10, semis=-5, lp=1500),
    ], {}),
}
R["tmud"] = {  # Mud Armor coat (TenoMudStartedAt)
    "A": ("Wet mud slap: a squelchy splat, a liquid impact and a few bubbles", [
        dict(name="Blood_Spill_Splat", t0=0.0, t1=0.28, at=0.0, gain_db=0, semis=-5),
        dict(name="Liquid_Impact_Bubble", t0=0.12, t1=0.84, at=0.04, gain_db=-3, semis=-4),
        dict(name="Cartoon_Bubbles_Short", t0=0.22, t1=0.45, at=0.45, gain_db=-8, semis=-5),
    ], {}),
    "B": ("Deep sloppy submerge (thick mud closing over the body) with wet squelching", [
        dict(name="Impact_Water_Deep_Submerge", t0=0.02, t1=1.48, at=0.0, gain_db=0, semis=-4),
        dict(name="Dinosaur_Eating_Meat_01", t0=1.84, t1=2.6, at=0.1, gain_db=-6, lp=4000),
    ], {}),
    "C": ("Gloopy gurgle with two quick splats", [
        dict(name="Aquatic_Creature_Gurgling", t0=0.3, t1=1.4, at=0.0, gain_db=-3, semis=-5, lp=3500),
        dict(name="Blood_Spill_Splat", t0=0.0, t1=0.28, at=0.0, gain_db=0, semis=-4),
        dict(name="Blood_Spill_Splat", t0=0.0, t1=0.28, at=0.22, gain_db=-4, semis=-7),
    ], {}),
}

meta = {}
for snd, opts in R.items():
    for opt, (desc, layers, kw) in opts.items():
        y = render(layers, **kw)
        fn = f"MDA_SFX_teno_{snd}_{opt}.wav"
        sf.write(os.path.join(OUT, fn), y, SR, subtype="PCM_16")
        rms = 20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-12)
        meta[f"{snd}_{opt}"] = {"file": fn, "desc": desc, "len": round(len(y) / SR, 2), "rms_db": round(rms, 1),
                                "sources": sorted({L["name"] for L in layers})}
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
for k, v in meta.items():
    print(f"{k:16s} {v['len']:5.2f}s rms{v['rms_db']:6.1f}  {v['desc'][:70]}")
