# gen_titles_sfx.py v1.1 (Mecha Dino Arena) — sound effects for the end-of-match title show (MDA-552, round 15; Kepu
# 2026-11-17 15:05 "Nah these are ass, I think it would be better to have better music and sound effects during these",
# 15:10 "Clown music for the crappy title cards and hero music for the good ones" / "With the appropriate sound effects").
# Every cue is built from recordings in the Sonniss GDC 2026 Game Audio Bundle (royalty-free for games; the raw sounds may
# not be redistributed, so neither the sources nor the renders are committed; run this against the converted sources in
# Kepu's Music\MechaDinoArena_SFX\_work_titles_sonniss\mono_flac). Timings are VictoryTitlesAnim 1.1's own beats
# (c:at("land", 1.5), c:at("roar", 2.26), c:at("pop", 3.0), c:at("impact", 2.3), ...); docs/sfx/TITLES_SFX_v1.0.md has
# the cue sheet. Trims were picked from each source's loudness every 0.1 s (no listening).
# v1.1 (Kepu 2026-11-17 16:48 kept all 16 music tracks; the in-game build): adds the cues for KING OF THE HILL (king_*),
#   UNKILLABLE (unk_*), MEDIC (med_*) and PACIFIST (pac_*) from VictoryTitlesAnim 1.2's beats (c:at("bonk", 1.0),
#   c:at("ding", 2.55), c:at("hit", 1.7), c:at("pebble", 4.75), c:at("open", 1.05), c:at("slap", 2.62), c:at("choo", 2.42),
#   ...) and gslam_hero / gslam_roast, the game's title-card hits with the hit 0.42 s in (the lower third slams in at 0.3 s,
#   so the cue starts with the title instead of before it as on the mockup page). 14 more Sonniss sources (S2). The 1.0
#   cues are unchanged. docs/sfx/TITLES_SFX_v1.1.md has the cue sheet.
# Output: <out>/MDA_SFX_vt_<cue>.wav, mono 48 kHz 16-bit, peak -1 dBFS.
# Usage: python3 -I docs/sfx/gen_titles_sfx.py <mono_flac dir> <out dir>
import os, sys
import numpy as np, soundfile as sf
SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
SR = 48000
S = {  # short names -> source files (Sonniss GDC 2026)
    "fw13": "13_Fireworks_powerful_explosions_multiples_in_a_row_near", "fw02": "02_Fireworks__explosions_dense_whistles",
    "cheer": "CRWDCheer_Small_Club_50_People_Crowd_Spanish_Cheering_and_Applause-Surround_KSL_KS015",
    "cutsweep": "Impact_Cut_Sweep", "shaker": "Transition_Frantic_Shaker_Snap",
    "whoosh": "WINDDsgn_Wind_Rush_Whoosh_Long_x5_01_344_Audio_Elemental_Palette_Designed_Vol_1",
    "thud": "DSGNImpt_Metal_Hit_Thud_Thump_Low_Ring_Geofon_1_The_Noisery_Moaning_Metal",
    "pieces": "GAMEBoard_Event_Board_Reset_Organic_Multiple_Pieces_Wood_Small_02_ESM_BG",
    "trex": "ANMLRept_T_Rex_344_Audio_Dinosaurs", "boom075": "EffectiveTrailer_Booms_Vol2_075", "boom214": "EffectiveTrailer_Booms_Vol2_214",
    "latch": "MECHLtch_Click_Deep_Mechanism_Latch_Button_Nearfield_Thunk_02_ESM_HDLM",
    "click": "UIClick_UI_Button_Analog_Vintage_Double_Click_Neutral_Dry_Press_11_ESM_BG",
    "fire": "FIRECrkl_Fire_Crackling_Popping_Witch_s_Cauldron_344_Audio_Haunting_Ambiences_Vol_5",
    "boing": "Accept_Boing_Crunch", "blast": "EXPLDsgn_Explosion_Small_Blast_Enemy_Death_Crunchy_Boom_Cartoon_Noisy_Crash_Impact_Delay_03_ESM_AG",
    "debris": "Woosh_Debris", "deny": "Deny_Muted", "bassdown": "Cartoon_Transition_Bass_Down",
    "plucks": "Interface_Plucks_Happy", "kalimba": "UIMisc_Kalimba_3_Up_CB_Sounddesign_APPlicable_Sounds",
    "bubbles": "Cartoon_Bubbles_Short", "firewhoosh": "FIREWhsh_Whoosh_Fire_Deep_Growl_Monster_Saturated_Crisp_03_ESM_EMWI",
    "thunder": "THUN_Interior_Thunder_Rumble_JF_INT_Storm_01", "pophi": "Interface_Pop_High_Short", "pops": "Cartoon_Pops_Random_Sequence_Reverb",
    "spell": "MAGAngl_Magic_Light_Spell_Enchantment_Potion_Effect_Tonal_Bright_03_ESM_FG2",
    "bite": "ANMLRept_Dinosaur_Eating_Meat_01_344_Audio_Dinosaurs_Vol_2", "swish": "Woosh_Sweep_Slide_Infographics_Basic",
    "snapspin": "Vibrato_Impact_Snap_Spin_Transition", "dizzy": "Cartoon_Confused_Dizzy",
    "bag": "CLOTHFlp_Action_Inventory_Open_Flip_Cloth_Canvas_Bag_Slide_Light_02_ESM_FG2",
    "pats": "FOLYMisc_WashingBasket_Pats_Movement12_InMotionAudio_WashingBasketFoley", "velcro": "OBJTape_VelcroRip29_InMotionAudio_Velcro",
    "grunt": "ANMLDog_Dog_Shuffle_Grunt_Movement_Lying_Down_344_Audio_Dog_Vocalisations",
}
S.update({  # v1.1
    "airy": "Cartoon_Airy_Impact_Creaks", "metaltap": "METLImpt_Metal_Old_File_Impact_Tap_Against_Tire_Iron_Metallic_Hit_01_ESM_HDGM",
    "coinflip": "Foley_Coin_Flip_Single_Fast", "spring": "METLTonl_Item_Spring_Wire_Impact_Flick_Top_Clatter_Light_Tap_Roll_Handling_Short_01_ESM_HDLM",
    "ting": "Ting_Coins", "twinkle": "Button_Arp_Twinkle", "piece": "GAMEBoard_Game_Play_Piece_Action_Organic_Connect_Dots_Fall_Bounce_04_ESM_BG",
    "lid": "METLMvmt__Opening_Lid_Of_Antique_Blowtorch_344_Audio_Antique_Small_Metals", "confetti": "Cofetti_Whoosh_Pluck_Spill",
    "happy": "Game_Entry_Happy_Short", "swing": "SWSH_SWING_IMPACTS_Quick_Heavy_Weapon_Swing_To_Thud_Impact_Var_01_DDUMAIS_MWP2",
    "smack": "FGHTImpt_Combat_Punch_Impact_Light_Hit_Delay_Crunchy_Vintage_Quick_Smack_05_ESM_AG",
    "powerup": "DSGNStngr_Power_Up_Bright_Positive_Successful_Light_Saturation_Crash_Shimmer_05_ESM_AG",
    "magic": "GAMEMisc_Magic_Creation_23_CB_Sounddesign_APPlicable_Sounds", "gasp": "HMNBrth_Police_Officer_Gasp_Vocal_Male_Shocked_Alert_1",
    "exhale": "CREAHmn_Violent_Humanoid_Creature_Exhale_Short_4_SNDBTS_VB_SE",
    "exhale2": "VOXFem_Anime_Schoolgirl_Fight_Exhale_15_344_Audio_Anime_Fight_Voices_Vol_2",
})
# cue -> layers: (source, from s, length s, at s inside the cue, gain dB, options)
# options: fi / fo = fade in / out s, lp = low-pass Hz, rate = varispeed
CUES = {
    "res_fireworks": [("fw13", 2.45, 4.9, 0, 0, {"fo": 1.0})],
    "res_cheer": [("cheer", 0.0, 3.4, 0, 0, {"fi": 0.05, "fo": 1.2})],
    "slam_hero": [("cutsweep", 0.30, 2.2, 0, 0, {"fo": 0.4})],                           # hit at 0.74 s
    "slam_roast": [("shaker", 0.0, 1.46, 0, 0, {"fo": 0.3})],                             # snap at 0.50 s
    "apex_pounce": [("whoosh", 0.0, 1.05, 0, 12, {"fo": 0.2})],
    "apex_land": [("thud", 0.0, 1.5, 0, 0, {"fo": 0.5}), ("pieces", 0.0, 1.1, 0.02, -4, {"fo": 0.2})],
    "apex_roar": [("trex", 3.55, 1.85, 0, 0, {"fi": 0.04, "fo": 0.35}), ("boom075", 0.20, 2.5, 0, -6, {"fo": 0.8})],
    "apex_cheer": [("cheer", 0.3, 2.0, 0, 0, {"fi": 0.1, "fo": 0.8})],
    "mash_click": [("latch", 0.0, 0.3, 0, 0, {"fo": 0.05}), ("click", 0.0, 0.17, 0, -6, {})],
    "mash_sizzle": [("fire", 0.2, 1.6, 0, 0, {"fi": 0.3, "fo": 0.4})],
    "mash_pop": [("boing", 0.0, 0.9, 0, 0, {"fo": 0.15}), ("blast", 0.0, 1.0, 0.18, -4, {"fo": 0.3})],   # boing peak 0.28
    "mash_fly": [("debris", 0.2, 1.3, 0, 0, {"fo": 0.3})],
    "mash_sad": [("deny", 0.1, 0.6, 0, 0, {"fo": 0.1}), ("click", 0.0, 0.17, 0.12, -4, {})],
    "mash_wahwah": [("bassdown", 0.2, 3.0, 0, 0, {"fo": 0.5})],
    "ext_happy": [("plucks", 0.0, 0.85, 0, 0, {}), ("kalimba", 0.0, 0.55, 0.4, 0, {})],
    "ext_gulp": [("bubbles", 0.1, 0.6, 0, 0, {"fo": 0.1})],
    "ext_fall": [("firewhoosh", 0.0, 1.0, 0, 0, {"fi": 0.2})],                             # peak at 0.8
    "ext_impact": [("boom214", 0.20, 3.5, 0, 0, {"fo": 1.0}), ("blast", 0.0, 1.4, 0.02, -3, {"fo": 0.3}), ("thunder", 0.6, 3.0, 0.1, -4, {"fo": 1.2})],
    "ext_sign": [("pophi", 0.0, 0.3, 0, 0, {}), ("pops", 0.15, 0.8, 0.05, -6, {"fo": 0.2})],
    "ext_ghost": [("spell", 0.0, 2.3, 0, 0, {"fo": 0.6})],
    "car_bite": [("bite", 0.78, 0.45, 0, 0, {"fo": 0.1})],
    "car_swish": [("swish", 0.0, 0.5, 0, 0, {"fo": 0.1})],
    "car_fling": [("snapspin", 0.55, 2.0, 0, 0, {"fo": 0.4})],                             # peak at 0.77
    "car_dizzy": [("dizzy", 0.0, 1.5, 0, 0, {"fo": 0.3})],
    "car_poof": [("pops", 0.15, 0.9, 0, 0, {"fo": 0.2})],
    "car_bag": [("bag", 0.0, 0.6, 0, 0, {}), ("pats", 0.3, 1.0, 0.15, -3, {"fo": 0.3})],
    "car_zip": [("velcro", 0.1, 0.3, 0, 0, {})],
    "car_mmph": [("grunt", 0.38, 0.45, 0, 0, {"lp": 900, "fo": 0.08})],
    "car_thump": [("thud", 0.0, 0.8, 0, -6, {"lp": 1200, "fo": 0.3})],
    "board_cheer": [("cheer", 0.0, 7.0, 0, 0, {"fi": 0.2, "fo": 2.0})],
    "board_fireworks": [("fw02", 0.2, 7.0, 0, 0, {"fi": 0.2, "fo": 2.0})],
    # ---- v1.1 ----
    "gslam_hero": [("cutsweep", 0.62, 1.9, 0, 0, {"fi": 0.02, "fo": 0.4})],                # hit at 0.42
    "gslam_roast": [("shaker", 0.05, 1.41, 0, 0, {"fi": 0.02, "fo": 0.3})],               # snap at 0.42
    "king_bonk": [("airy", 0.15, 1.6, 0, 0, {"fi": 0.3, "fo": 0.4}), ("metaltap", 0.08, 0.35, 0.86, -2, {"fo": 0.1})],   # hit at 0.90
    "king_coin": [("coinflip", 0.0, 0.7, 0, 0, {"fo": 0.2})],
    "king_land": [("metaltap", 0.08, 0.35, 0, 0, {"fo": 0.1}), ("piece", 0.0, 0.2, 0.01, -6, {})],
    "king_rattle": [("spring", 0.30, 0.65, 0, 0, {"fi": 0.03, "fo": 0.15})],
    "king_ding": [("ting", 0.04, 1.0, 0, 0, {"fo": 0.3}), ("twinkle", 0.0, 1.1, 0.02, -6, {"fo": 0.4})],                # ting at 0.06
    "unk_chew": [("bite", 0.8, 1.6, 0, 0, {"fi": 0.05, "fo": 0.3})],
    "unk_glint": [("twinkle", 0.0, 1.0, 0, 0, {"fo": 0.4})],
    "unk_hit": [("blast", 0.0, 1.4, 0, 0, {"fo": 0.3}), ("boom075", 0.20, 2.5, 0, -5, {"fo": 0.8}),
                ("pieces", 0.0, 1.1, 0.05, -3, {"fo": 0.2}), ("debris", 0.2, 1.3, 0.1, -6, {"fo": 0.3})],
    "unk_rocks": [("piece", 0.0, 0.2, a, g, {}) for a, g in ((0, 0), (0.14, -3), (0.33, -5), (0.5, -8), (0.71, -11))],
    "unk_pebble": [("piece", 0.0, 0.2, 0, 0, {}), ("metaltap", 0.08, 0.3, 0.0, -10, {"fo": 0.1})],
    "med_open": [("lid", 0.15, 0.5, 0, 0, {"fo": 0.1}), ("confetti", 0.1, 1.5, 0.05, -2, {"fo": 0.4}), ("happy", 0.0, 0.35, 0.08, -4, {"fo": 0.05})],
    "med_slap": [("swing", 0.0, 1.4, 0, 0, {"fo": 0.4}), ("smack", 0.0, 0.66, 0.2, -2, {"fo": 0.15})],                # hit at 0.20
    "med_heal": [("powerup", 0.0, 1.5, 0, 0, {"fo": 0.4})],
    "pac_bloom": [("magic", 0.2, 2.2, 0, 0, {"fi": 0.05, "fo": 0.8})],
    "pac_ah": [("gasp", 0.0, 0.3, 0, 0, {"fo": 0.08})],
    "pac_choo": [("exhale", 0.0, 0.43, 0, 0, {"fo": 0.1}), ("exhale2", 0.05, 0.5, 0.0, -3, {"fo": 0.1}),
                 ("confetti", 0.15, 1.4, 0.03, -4, {"fo": 0.4}), ("smack", 0.0, 0.5, 0.0, -10, {"fo": 0.1})],
}
_cache = {}
def src(name):
    if name not in _cache:
        x, sr = sf.read(os.path.join(SRC, S[name] + ".flac"))
        assert sr == SR, (name, sr)
        _cache[name] = x.astype(np.float64)
    return _cache[name]
def lowpass(x, hz):  # 2nd-order biquad, applied twice
    import math
    w = 2 * math.pi * hz / SR; c = math.cos(w); a = math.sin(w) / (2 * 0.707)
    b0, b1, b2, a0, a1, a2 = (1 - c) / 2, 1 - c, (1 - c) / 2, 1 + a, -2 * c, 1 - a
    from scipy.signal import lfilter
    for _ in range(2): x = lfilter([b0 / a0, b1 / a0, b2 / a0], [1, a1 / a0, a2 / a0], x)
    return x
for cue, layers in CUES.items():
    total = max(at + ln for _, _, ln, at, _, _ in layers)
    mix = np.zeros(int(total * SR) + 1)
    for name, fr, ln, at, gdb, o in layers:
        x = src(name)[int(fr * SR):int((fr + ln) * SR)].copy()
        if o.get("lp"): x = lowpass(x, o["lp"])
        n = len(x)
        fi, fo = int(o.get("fi", 0.005) * SR), int(o.get("fo", 0.01) * SR)
        if fi: x[:fi] *= np.linspace(0, 1, fi)
        if fo: x[-fo:] *= np.linspace(1, 0, fo)
        i0 = int(at * SR)
        mix[i0:i0 + n] += x * 10 ** (gdb / 20)
    mix -= np.mean(mix)
    mix *= 10 ** (-1 / 20) / max(1e-9, np.max(np.abs(mix)))
    sf.write(os.path.join(OUT, f"MDA_SFX_vt_{cue}.wav"), mix, SR, subtype="PCM_16")
    print(cue, round(len(mix) / SR, 2))
