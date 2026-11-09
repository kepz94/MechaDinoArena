#!/usr/bin/env python3
"""balance_pass1_check v1.1 (Mecha Dino Arena) — offline spec for balance pass 1 (plan docs/plans/BALANCE_PASS_v1.0.md,
MDA-357 .. MDA-364). Needs only python3; touches nothing in the repo (generators run in a temporary copy).
Checks:
  1. every new model number against the plan table (PLAN below), read from src/shared/Models/*ModelData.luau;
  2. numbers that must NOT change (walk speeds the plan leaves alone, the pinned BiteDamage 25 of the non-biters, Herrera's
     JumpEnabled false / no JumpCooldown, heals, the Therizino walk, the T-Rex walk);
  3. each generator, run in a temp copy of tools/ + src/shared/Models: the default run rebuilds the repo file byte-identical,
     and the old-version flag rebuilds the pre-pass file byte-identical (size / hash h = (h * 31 + byte) % 1000000007 of
     main 34bee59, recorded in OLD);
  4. the latch simulation (tools/tests/pounce_latch_sim.py) passes;
  5. script numbers: TRexJump 1.1 default 0.25, PounceServer 1.16 cap switch, SkillEffects 1.50 dilo keep, SkillTree 1.73 block.
v1.1 (Kepu 2026-11-09 answers on MDA-357 / 360 / 361 / 362 / 363): Dilo Cobra Leap "Plain 0.25 s" (DiloModelData 1.5: JumpCharges
  0; SkillEffects stays 1.49, the 1.50 dilo leap keep is withdrawn), walk x the run ratio (TenoModelData 1.6 walk 38,
  TherizinoModelData 1.7 42.5, TRexModelData 2.2 39.5), raptor BOTS latch like players (BotServer 1.28). GENS_MID: the
  code-phase versions (52621b2) rebuild byte-identical with the new flags (--v14 dilo, --v15 teno, --v16 therizino, --v21 trex).
Run: python3 tools/tests/balance_pass1_check.py      -> "PASS n" (exit 0) or the failures and "FAIL n/m" (exit 1)
"""
import os, re, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS = os.path.join(ROOT, "src", "shared", "Models")

# plan table "Numbers (Very strong)" + MDA-357 / MDA-364 -> model attribute = value (file, attribute, before, after)
PLAN = [
    ("HerreraModelData", "SlashDamage", 7, 15), ("HerreraModelData", "SlashCharges", 2, 3),
    ("HerreraModelData", "SlashRefill", 4, 2.5), ("HerreraModelData", "SlashBleedDps", 2, 4),
    ("TroodonModelData", "TrooPodDamage", 6, 12), ("TroodonModelData", "TrooZoneDps", 3, 6),
    ("TroodonModelData", "TrooPodCharges", 2, 3), ("TroodonModelData", "TrooPodRefill", 3, 2),
    ("DiloModelData", "DiloBiteDamage", 10, 15), ("DiloModelData", "DiloDartDamage", 6, 10),
    ("DiloModelData", "DiloVenomDps", 2, 4), ("DiloModelData", "MoveRunSpeed", 66, 78),
    ("DiloModelData", "JumpCharges", 0, 0),  # v1.1: "Plain 0.25 s" (1.4 had 2) ("DiloModelData", "DiloHoldTime", 0.4, 0.25),
    ("DiloModelData", "DiloDartCooldown", 1.5, 0.75),
    ("TenoModelData", "TenoScratchDamage", 8, 12), ("TenoModelData", "TenoSlamDamage", 15, 25),
    ("TenoModelData", "MoveRunSpeed", 52, 66), ("TenoModelData", "JumpLaunchPower", 54, 64),
    ("TherizinoModelData", "TheriHitDamage1", 9, 11), ("TherizinoModelData", "TheriHitDamage2", 9, 11),
    ("TherizinoModelData", "TheriHitDamage3", 20, 24), ("TherizinoModelData", "JumpCharges", 2, 3),
    ("TherizinoModelData", "JumpCooldown", 6, 3), ("TherizinoModelData", "MoveRunSpeed", 66, 78),
    ("TRexModelData", "BiteDamage", 25, 30), ("TRexModelData", "MoveRunSpeed", 60, 74),
    # MDA-357 (latch 2.5 s, 5 per hit; drain + cap chosen by the simulation)
    ("RaptorModelData", "PounceTickDamage", 4, 5), ("RaptorModelData", "PounceLatchDrain", 15, 32),
    ("RaptorModelData", "PounceLatchMaxTime", None, 2.5),
    # MDA-364 (JumpCooldown 0.25; T-Rex in TRexJump 1.1)
    ("RaptorModelData", "JumpCooldown", 0.5, 0.25), ("PachyModelData", "JumpCooldown", 0.5, 0.25),
    ("DiloModelData", "JumpCooldown", 0.5, 0.25), ("TroodonModelData", "JumpCooldown", 0.5, 0.25),
    ("TenoModelData", "JumpCooldown", 1, 0.25),
    # v1.1: walk x the run ratio, rounded to 0.5 (Kepu 2026-11-09 "Yes, same proportion")
    ("TenoModelData", "MoveWalkSpeed", 30, 38), ("TherizinoModelData", "MoveWalkSpeed", 36, 42.5),
    ("TRexModelData", "MoveWalkSpeed", 32, 39.5), ("DiloModelData", "MoveWalkSpeed", 36, 42.5),
]
VERSIONS = {"RaptorModelData": ("RaptorModelVersion", "1.14"), "PachyModelData": ("PachyModelVersion", "1.6"),
            "HerreraModelData": ("HerreraModelVersion", "1.5"), "TenoModelData": ("TenoModelVersion", "1.6"),
            "TherizinoModelData": ("TherizinoModelVersion", "1.7"), "DiloModelData": ("DiloModelVersion", "1.5"),
            "TroodonModelData": ("TroodonModelVersion", "1.6"), "TRexModelData": ("TRexModelVersion", "2.2")}
SAME = [  # unchanged on purpose
    ("DiloModelData", "JumpCooldown", 0.25),  # v1.1: plain leap
    ("TroodonModelData", "TrooZoneHeal", 5), ("TroodonModelData", "TrooSelfHeal", 2), ("TroodonModelData", "JumpCharges", 0),
    ("HerreraModelData", "JumpEnabled", False), ("HerreraModelData", "SlashBleedTime", 4),
    ("RaptorModelData", "PounceLandDamage", 8), ("RaptorModelData", "PounceTickInterval", 0.5),
    ("RaptorModelData", "PounceStaminaCost", 15), ("RaptorModelData", "BiteDamage", 8),
    ("PachyModelData", "BiteDamage", 25), ("HerreraModelData", "BiteDamage", 25), ("TenoModelData", "BiteDamage", 25),
    ("DiloModelData", "BiteDamage", 25), ("TroodonModelData", "BiteDamage", 25), ("TherizinoModelData", "BiteDamage", 25),
]
# v1.1: generator, output, flag, code-phase (52621b2) size / hash
GENS_MID = [
    ("dilo_generator.py", "DiloModelData", "--v14", 38535, 346861290),
    ("teno_generator.py", "TenoModelData", "--v15", 28924, 398504457),
    ("therizino_generator.py", "TherizinoModelData", "--v16", 42159, 144559858),
    ("trex_generator.py", "TRexModelData", "--v21", 27945, 729223109),
]
# generator, default output, old flag, old size / hash (main 34bee59)
GENS = [
    ("raptor_generator.py", "RaptorModelData", "--v113", 22949, 584866431),
    ("pachy_generator.py", "PachyModelData", "--v15", 29071, 117401205),
    ("herrera_generator.py", "HerreraModelData", "--v14", 34605, 692073488),
    ("teno_generator.py", "TenoModelData", "--v14", 28717, 466403113),
    ("therizino_generator.py", "TherizinoModelData", "--v15", 41976, 180423010),
    ("dilo_generator.py", "DiloModelData", "--v13", 38249, 808053056),
    ("troodon_generator.py", "TroodonModelData", "--v15", 42668, 793441595),
    ("trex_generator.py", "TRexModelData", "--v20", 27748, 643607252),
]

fails, passes = [], 0


def eq(name, got, want):
    global passes
    good = (abs(got - want) < 1e-9) if isinstance(want, (int, float)) and not isinstance(want, bool) and isinstance(got, (int, float)) else got == want
    if good:
        passes += 1
    else:
        fails.append(f"{name}: got {got!r} want {want!r}")


def h(data):
    v = 0
    for b in data:
        v = (v * 31 + b) % 1000000007
    return v


def attrs(path):
    s = open(path).read()
    block = s[s.index("attributes = {"):]
    block = block[:block.index("\n\t},")]
    out = {}
    for m in re.finditer(r'^\t\t(\w+) = (.+?),$', block, re.M):
        v = m.group(2)
        if v in ("true", "false"):
            v = v == "true"
        elif v.startswith('"'):
            v = v.strip('"')
        else:
            try:
                v = float(v)
            except ValueError:
                pass
        out[m.group(1)] = v
    return out


def main():
    data = {f[:-5]: attrs(os.path.join(MODELS, f)) for f in os.listdir(MODELS) if f.endswith(".luau")}
    # 1. plan numbers
    for model, key, before, after in PLAN:
        eq(f"{model}.{key} (plan {before} -> {after})", data[model].get(key), after)
    for model, (key, v) in VERSIONS.items():
        eq(f"{model}.{key}", data[model].get(key), v)
    # 2. unchanged on purpose
    for model, key, v in SAME:
        eq(f"{model}.{key} unchanged", data[model].get(key), v)
    eq("Herrera has no JumpCooldown (HerreraJump writes 0)", "JumpCooldown" in data["HerreraModelData"], False)
    # 3. generators in a temp copy
    tmp = tempfile.mkdtemp(prefix="bal1_")
    try:
        shutil.copytree(os.path.join(ROOT, "tools"), os.path.join(tmp, "tools"),
                        ignore=shutil.ignore_patterns("island_v2", "island_v3", "mockup", "*_mockup", "*brainstorm*", "tests"))
        shutil.copytree(MODELS, os.path.join(tmp, "src", "shared", "Models"))
        for gen, model, old_flag, old_size, old_hash in GENS:
            out = os.path.join(tmp, "src", "shared", "Models", model + ".luau")
            repo = open(os.path.join(MODELS, model + ".luau"), "rb").read()
            r = subprocess.run([sys.executable, os.path.join(tmp, "tools", gen)], capture_output=True, text=True)
            eq(f"{gen} default run ok", r.returncode, 0)
            new = open(out, "rb").read()
            eq(f"{gen} default = repo {model} ({len(repo)}/{h(repo)})", (len(new), h(new)), (len(repo), h(repo)))
            r = subprocess.run([sys.executable, os.path.join(tmp, "tools", gen), old_flag], capture_output=True, text=True)
            eq(f"{gen} {old_flag} run ok", r.returncode, 0)
            old = open(out, "rb").read()
            eq(f"{gen} {old_flag} = main {model} ({old_size}/{old_hash})", (len(old), h(old)), (old_size, old_hash))
            # put the new file back for the generators that read it (therizino) or the T-Rex (read by the others)
            open(out, "wb").write(repo)
        for gen, model, flag, size, hsh in GENS_MID:  # v1.1
            out = os.path.join(tmp, "src", "shared", "Models", model + ".luau")
            repo = open(os.path.join(MODELS, model + ".luau"), "rb").read()
            r = subprocess.run([sys.executable, os.path.join(tmp, "tools", gen), flag], capture_output=True, text=True)
            eq(f"{gen} {flag} run ok", r.returncode, 0)
            mid = open(out, "rb").read()
            eq(f"{gen} {flag} = code phase {model} ({size}/{hsh})", (len(mid), h(mid)), (size, hsh))
            open(out, "wb").write(repo)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    # 4. latch simulation
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "tests", "pounce_latch_sim.py")], capture_output=True, text=True)
    eq("pounce_latch_sim PASS", r.returncode, 0)
    # 5. scripts
    src = lambda rel: open(os.path.join(ROOT, rel)).read()
    tj = src("src/server/TRexJump.server.luau")
    eq("TRexJump 1.1", 'local VERSION = "1.1"' in tj, True)
    eq("TRexJump default 0.25", 'script:SetAttribute("TRexJumpCooldown", 0.25)' in tj, True)
    eq("TRexJump switch", "TRexJumpBalanceEnabled" in tj, True)
    ps = src("src/server/PounceServer.server.luau")
    eq("PounceServer 1.16", 'SetAttribute("PounceServerVersion", "1.16")' in ps, True)
    eq("PounceServer cap switch", 'SetAttribute("PounceLatchMaxTimeEnabled", true)' in ps, True)
    se = src("src/server/SkillEffects.server.luau")
    eq("SkillEffects 1.49 (1.50 dilo leap keep withdrawn: JumpCharges 0)", ("VERSION = \"1.49\"" in se, "SkillEffectsDiloLeapKeepEnabled" in se), (True, False))
    bs = src("src/server/BotServer.server.luau")  # v1.1: raptor bots latch like players
    eq("BotServer 1.28", 'VERSION = "1.28"' in bs, True)
    for k, v in (("BotLatchBalanceEnabled", "true"), ("BotLatchMaxTime", "2.5"), ("BotLatchLandDamage", "8"),
                 ("BotLatchTickDamage", "5"), ("BotLatchTickInterval", "0.5")):
        eq(f"BotServer DEFAULTS.{k} = {v}", f"DEFAULTS.{k} = {v} " in bs, True)
    st = src("src/shared/SkillTree.luau")
    eq("SkillTree 1.73 switch", "SkillTree.BALANCE_PASS1 = true" in st, True)
    for k, v in (("herreraBleed", "{2, 4}"), ("theriHit2", "{9, 11}"), ("theriHit3", "{20, 24}"), ("diloHold", "{0.4, 0.25}"),
                 ("diloDartCd", "{1.5, 0.75}"), ("tenoScratch", "{8, 12}"), ("tenoSlam", "{15, 25}"), ("trexBite", "{25, 30}"),
                 ("herreraSlash", "{7, 15}"), ("herreraRefill", "{4, 2.5}"), ("herreraCharges", "{2, 3}")):
        eq(f"SkillTree.BAL1.{k} = plan", f"{k} = {v}" in st, True)
    for f in fails:
        print("FAIL", f)
    print(f"PASS {passes}" if not fails else f"FAIL {len(fails)}/{len(fails) + passes}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
