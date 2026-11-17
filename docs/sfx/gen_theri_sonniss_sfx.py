"""Therizino ability sounds, round 9 (Sonniss GDC 2026 bundle sources). Builds 3 options per sound from real recordings:
trim one take, optional varispeed pitch (resample), EQ, fades, layered with offsets, normalized. Mono 48 kHz 16-bit WAV.
Sources: the FLAC working copies in Music\\MechaDinoArena_SFX\\_work_teno_sonniss + _work_theri_sonniss (mono 48 kHz conversions of the bundle
files). Run: python3 gen_theri_sonniss_sfx.py <src_dir> <out_dir>."""
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

R["zreel"] = {  # Reaper Reel (TheriReelAt, the press): claw shoots out 0.12-0.35 s, then winches the target in 0.3-0.8 s
    "A": ("Claw shoots out with a whip of air, then a big ratcheting winch (a tape-measure retract pitched way down) and a lock click", [
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.0, gain_db=-2, semis=-4),
        dict(name="Tool_Tape_Measure_Pull_Retract", t0=1.0, t1=1.91, at=0.22, gain_db=0, semis=-8),
        dict(name="Carabiner_Screwing_Lock", t0=0.20, t1=0.34, at=1.20, gain_db=-4, semis=-3),
    ], {}),
    "B": ("Metal claw flies out rattling, the rope snaps taut, and a servo winch drags it back", [
        dict(name="Metal_Slow_Whoosh_Rattle", t0=0.05, t1=0.6, at=0.0, gain_db=-2, semis=-2),
        dict(name="Flicking_Carabiner_On_Rope", t0=2.66, t1=3.47, at=0.28, gain_db=-1),
        dict(name="Tower_Deploy_Hitech_Robot_Motor", t0=0.10, t1=0.69, at=0.40, gain_db=-4, semis=-4),
    ], {}),
    "C": ("Claw bites in with a sharp rattle, then a heavy metal grind as it reels", [
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.0, gain_db=-3, semis=-2),
        dict(name="Arrow_Hit_Rattle", t0=0.07, t1=0.77, at=0.18, gain_db=0, semis=-4),
        dict(name="Large_Metal_Box_Drag", t0=10.0, t1=10.9, at=0.35, gain_db=-3, semis=4, fout=0.25),
    ], {}),
}
R["zreelhit"] = {  # Reaper Reel slash (TheriReelHitAt): the pulled dino gets slashed
    "A": ("Fast metallic blade slice with a meaty body hit", [
        dict(name="Sword_Slide_Cuts_Metallic", t0=0.13, t1=0.55, at=0.0, gain_db=0, semis=-3),
        dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.03, gain_db=-3, semis=-2),
    ], {}),
    "B": ("Big sweeping cut with a wet splat", [
        dict(name="Impact_Cut_Sweep", t0=0.89, t1=1.46, at=0.0, gain_db=0),
        dict(name="Blood_Spill_Splat", t0=0.0, t1=0.28, at=0.04, gain_db=-4, semis=-3),
    ], {}),
    "C": ("Heavy claw swing into a metal hit with a crunchy smash", [
        dict(name="METAL_SWING_HIT", t0=0.05, t1=0.95, at=0.0, gain_db=0, semis=-2),
        dict(name="Gore_Designed_Transient_Heavy_Impact", t0=0.0, t1=0.5, at=0.05, gain_db=-5),
    ], {}),
}
R["zvolley"] = {  # Wing Volley (TheriFeatherAt, the press): wings wind up, darts released at 0.42 s
    "A": ("Feathers rustle as the wings flare, then a burst of feather darts and glassy shards whooshing out", [
        dict(name="ClothMovement24", t0=0.07, t1=0.50, at=0.0, gain_db=-3, semis=-3),
        dict(name="Cofetti_Whoosh_Pluck_Spill", t0=0.10, t1=1.30, at=0.36, gain_db=0, semis=-3),
        dict(name="Glass_Crystal_Fragments_Sharp", t0=0.21, t1=1.2, at=0.40, gain_db=-5, semis=-5),
    ], {}),
    "B": ("A wing snap, then a layered blade-swish volley", [
        dict(name="ClothMovement29", t0=0.03, t1=0.45, at=0.0, gain_db=-3, semis=-2),
        dict(name="Action_Deploy_Units_Sword_Slice", t0=0.15, t1=1.5, at=0.36, gain_db=0, semis=-2),
    ], {}),
    "C": ("Two heavy wing flaps, then a swarm of darts zipping out", [
        dict(name="SinglePats04", t0=0.06, t1=0.28, at=0.0, gain_db=-2, semis=-6),
        dict(name="SinglePats04", t0=0.06, t1=0.28, at=0.20, gain_db=-1, semis=-7),
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.42, gain_db=0, semis=-1),
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.48, gain_db=-2, semis=1),
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.55, gain_db=-3, semis=-3),
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.61, gain_db=-4, semis=2),
        dict(name="Glass_Crystal_Fragments_Sharp", t0=0.21, t1=1.0, at=0.44, gain_db=-7, semis=-4),
    ], {}),
}
R["zvortex"] = {  # Reaper Vortex (TheriVortexAt, the press; the vortex runs from 0.95 s)
    "A": ("A spinning metal shield whirling up, over a howling wind (a blade storm)", [
        dict(name="Metal_Shield_Spin_On_Floor", t0=0.96, t1=3.6, at=0.0, gain_db=0, semis=-3, fin=0.3, fout=0.5),
        dict(name="Wind_Whipping_Constricted_Flow", t0=0.0, t1=2.8, at=0.1, gain_db=-5, fin=0.6, fout=0.6),
    ], {}),
    "B": ("A deep rotor whirr (a rotor pitched way down) with blade cuts flicking past", [
        dict(name="Quadcopter_Toy_Flying_Sustained", t0=1.0, t1=4.5, at=0.0, gain_db=0, semis=-12, fin=0.5, fout=0.5, lp=5000),
        dict(name="Sword_Slide_Cuts_Metallic", t0=2.24, t1=2.63, at=0.9, gain_db=-5, semis=-2),
        dict(name="Sword_Slide_Cuts_Metallic", t0=4.32, t1=4.69, at=1.5, gain_db=-6, semis=-4),
        dict(name="Sword_Slide_Cuts_Metallic", t0=6.32, t1=6.72, at=2.1, gain_db=-7, semis=-3),
    ], {"max_len": 2.8}),
    "C": ("Whipping wind with heavy blade swings looping around you", [
        dict(name="Wind_Whipping_Constricted_Flow", t0=0.0, t1=2.8, at=0.0, gain_db=-1, fin=0.4, fout=0.6),
        dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.67, at=0.6, gain_db=-3, semis=-5),
        dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.67, at=1.1, gain_db=-4, semis=-6),
        dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.67, at=1.6, gain_db=-5, semis=-5),
        dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.67, at=2.1, gain_db=-7, semis=-6),
    ], {"max_len": 2.8}),
}
R["zbola"] = {  # Bola (TheriBolaAt, the press): whirled for 0.6 s, then thrown
    "A": ("Rope whirling faster and faster, then a whip crack as it's let go", [
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.0, gain_db=-6, semis=-5),
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.22, gain_db=-4, semis=-4),
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.40, gain_db=-3, semis=-3),
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.52, gain_db=-2, semis=-2),
        dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.70, at=0.60, gain_db=0, semis=-2),
    ], {}),
    "B": ("Two heavy whirls of the weighted rope, then a long throw whoosh", [
        dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.5, at=0.0, gain_db=-3, semis=-6),
        dict(name="Swift_Melee_Weapon_Swing", t0=0.0, t1=0.5, at=0.28, gain_db=-2, semis=-5),
        dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.01, at=0.58, gain_db=0, semis=-3),
    ], {}),
    "C": ("Weighted rope rattling round three times, then thrown with a rush of air", [
        dict(name="Flicking_Carabiner_On_Rope", t0=0.02, t1=0.41, at=0.0, gain_db=-3, semis=-3),
        dict(name="Flicking_Carabiner_On_Rope", t0=0.90, t1=1.27, at=0.20, gain_db=-2, semis=-2),
        dict(name="Flicking_Carabiner_On_Rope", t0=1.85, t1=2.27, at=0.40, gain_db=-1, semis=-1),
        dict(name="Wind_Rush_Whoosh_Long", t0=0.04, t1=1.01, at=0.58, gain_db=0, semis=-2),
    ], {}),
}
R["zbolahit"] = {  # Bola catch (TheriBolaHitAt, at TheriBolaEnd): the rope wraps the target
    "A": ("Rope wraps tight with a sharp strap squeeze, a metal clasp and a thud", [
        dict(name="VelcroRip29", t0=0.13, t1=0.27, at=0.0, gain_db=-2, semis=-4),
        dict(name="Punch_Body_02", t0=0.16, t1=0.46, at=0.0, gain_db=-3, semis=-4),
        dict(name="Carabiner_Screwing_Lock", t0=0.20, t1=0.34, at=0.12, gain_db=-3, semis=-2),
    ], {}),
    "B": ("Heavy strap and buckle locking shut (a suitcase strap), with the rope going taut", [
        dict(name="Suitcase_Being_Locked", t0=1.03, t1=1.50, at=0.0, gain_db=0, semis=-3),
        dict(name="Flicking_Carabiner_On_Rope", t0=0.90, t1=1.27, at=0.02, gain_db=-3),
    ], {}),
    "C": ("Whip-wrap crack with a cloth snap and a body hit", [
        dict(name="WHIP_Snap_Crack_05", t0=0.12, t1=0.55, at=0.0, gain_db=-1, semis=-4),
        dict(name="ClothMovement29", t0=0.03, t1=0.4, at=0.05, gain_db=-5),
        dict(name="Punch_Body_02", t0=1.13, t1=1.54, at=0.04, gain_db=-4, semis=-5),
    ], {}),
}
R["zdash"] = {  # Dash (TheriDashAt): Storm Core burst, 0.16 s delay + 0.08-0.16 s travel
    "A": ("Electric Storm Core zap and a fast engine-like whoosh past (motorbike pass-by peak)", [
        dict(name="ArcDesign15", t0=0.0, t1=0.5, at=0.0, gain_db=-3),
        dict(name="Kawasaki_Ninja_ZX_10R_Pass_By_Fast", t0=4.6, t1=6.2, at=0.0, gain_db=0, semis=3, fin=0.15, fout=0.4),
    ], {"max_len": 1.1}),
    "B": ("Deep electric hiss-glitch burst with a sharp whoosh", [
        dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=1.2, at=0.0, gain_db=0, fout=0.3),
        dict(name="Woosh_Sweep_Slide_Infographics", t0=0.0, t1=0.16, at=0.12, gain_db=-2, semis=-3),
    ], {}),
    "C": ("Icy whoosh-and-snap burst with a zap", [
        dict(name="Skill_Freeze_Whoosh_Break", t0=0.05, t1=1.0, at=0.0, gain_db=0, fout=0.25),
        dict(name="ArcDesign15", t0=0.0, t1=0.4, at=0.08, gain_db=-6),
    ], {}),
}
R["zdeflect"] = {  # Deflector Claws (TheriDeflectAt): the claws raise a shield wall
    "A": ("Energy power-up surge into a ringing metal clang", [
        dict(name="ArcPowerUpDesign04", t0=4.6, t1=5.6, at=0.0, gain_db=-3, fin=0.05, fout=0.3),
        dict(name="METAL_SWING_HIT", t0=0.05, t1=1.2, at=0.15, gain_db=0, semis=-3),
    ], {}),
    "B": ("A metal shield slammed into place with a crystalline shatter-whoosh", [
        dict(name="Metal_Shield_Spin_On_Floor", t0=0.42, t1=0.75, at=0.0, gain_db=0, semis=-2),
        dict(name="Skill_Freeze_Whoosh_Break", t0=0.05, t1=1.2, at=0.0, gain_db=-4, semis=-3),
    ], {}),
    "C": ("A bright metal ting over a deep electric hum (energy wall)", [
        dict(name="Metal_Old_File_Impact_Tap", t0=0.11, t1=0.40, at=0.0, gain_db=0, semis=-5),
        dict(name="Impact_Electric_Tonal_Deep_Movement", t0=0.02, t1=1.3, at=0.0, gain_db=-3, semis=-5, fout=0.4),
    ], {}),
}

meta = {}
for snd, opts in R.items():
    for opt, (desc, layers, kw) in opts.items():
        y = render(layers, **kw)
        fn = f"MDA_SFX_theri_{snd}_{opt}.wav"
        sf.write(os.path.join(OUT, fn), y, SR, subtype="PCM_16")
        rms = 20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-12)
        meta[f"{snd}_{opt}"] = {"file": fn, "desc": desc, "len": round(len(y) / SR, 2), "rms_db": round(rms, 1),
                                "sources": sorted({L["name"] for L in layers})}
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
for k, v in meta.items():
    print(f"{k:16s} {v['len']:5.2f}s rms{v['rms_db']:6.1f}  {v['desc'][:70]}")
