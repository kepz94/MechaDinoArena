-- PracticeTiers.spec v1.0 (Mecha Dino Arena) — PracticeRules 1.2 Bots v2 rules (plan docs/plans/BOTS_V2_v1.0.md T1, MDA-466).
-- Run in Studio Edit (clones ServerStorage.DinoArcade.PracticeRules); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("PracticeRules")
if not src then return "FAIL require: PracticeRules missing" end
local c = src:Clone() c.Parent = src.Parent
local okR, R = pcall(require, c)
c:Destroy()
if not okR then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want) if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end end
local function near(name, got, want) eq(name, math.abs((got or 0) - want) < 1e-6, true) end

eq("version", R.VERSION, "1.2")
-- tiers
eq("tiers", R.TIERS.Easy.react > R.TIERS.Normal.react and R.TIERS.Normal.react > R.TIERS.Hard.react and R.TIERS.Hard.react > R.TIERS.Elite.react, true)
eq("aim", R.TIERS.Easy.aimErr > R.TIERS.Elite.aimErr, true)
eq("abil", R.TIERS.Elite.abil > R.TIERS.Easy.abil, true)
eq("elite flags", R.TIERS.Elite.strafe and R.TIERS.Elite.dodge and R.TIERS.Elite.lead and R.TIERS.Elite.combo, true)
eq("easy flags", not R.TIERS.Easy.strafe and not R.TIERS.Easy.dodge, true)
eq("tierOf bad", R.tierOf("x").name, "Normal")
eq("tierOf", R.tierOf("Elite").name, "Elite")
-- mix
local m5 = R.mixFor(5)
eq("mix5", table.concat(m5, ","), "Elite,Hard,Normal,Easy,Normal")
eq("mix4", table.concat(R.mixFor(4), ","), "Elite,Hard,Normal,Easy")
eq("mix7", table.concat(R.mixFor(7), ","), "Elite,Hard,Normal,Easy,Normal,Elite,Hard")
eq("mix0", #R.mixFor(0), 0)
local rng = Random.new(7)
local d = R.dealTiers(5, rng)
local cnt = {}
for _, t in ipairs(d) do cnt[t] = (cnt[t] or 0) + 1 end
eq("deal counts", (cnt.Elite or 0) == 1 and (cnt.Hard or 0) == 1 and (cnt.Normal or 0) == 2 and (cnt.Easy or 0) == 1, true)
-- respawn keeps the spread
eq("respawn missing elite", R.respawnTier({"Hard", "Normal", "Normal", "Easy"}, 5, rng), "Elite")
eq("respawn missing easy", R.respawnTier({"Hard", "Normal", "Normal", "Elite"}, 5, rng), "Easy")
eq("respawn missing normal", R.respawnTier({"Hard", "Normal", "Easy", "Elite"}, 5, rng), "Normal")
local r2 = R.respawnTier({"Normal", "Normal", "Easy"}, 5, rng)
eq("respawn two missing", r2 == "Elite" or r2 == "Hard", true)
local r3 = R.respawnTier({"Elite", "Hard", "Normal", "Normal", "Easy"}, 5, rng)
eq("respawn full", table.find(R.mixFor(5), r3) ~= nil, true)
eq("respawn size0", R.respawnTier({}, 0, rng), "Normal")
-- slowMul
near("slow none", R.slowMul({}, 10), 1)
near("slow one", R.slowMul({SlowMul_A = 0.5, SlowUntil_A = 20}, 10), 0.5)
near("slow two", R.slowMul({SlowMul_A = 0.8, SlowUntil_A = 20, SlowMul_B = 0.5, SlowUntil_B = 20}, 10), 0.4)
near("slow ended", R.slowMul({SlowMul_A = 0.5, SlowUntil_A = 5}, 10), 1)
near("slow floor", R.slowMul({SlowMul_A = 0.1, SlowUntil_A = 20, SlowMul_B = 0.1, SlowUntil_B = 20}, 10), 0.25)
near("slow no until", R.slowMul({SlowMul_A = 0.5}, 10), 1)
near("slow bad", R.slowMul({SlowMul_A = "x", SlowUntil_A = 20}, 10), 1)
near("slow nil", R.slowMul(nil, 10), 1)
-- abilityWant
local W = R.abilityWant
eq("mob swim", W("mobility", {swimming = true}), 0.9)
eq("mob stuck", W("mobility", {stuckFor = 2}), 0.9)
eq("mob escape", W("mobility", {hpFrac = 0.2, foesNear = 2, matesNear = 0}), 0.85)
eq("mob gap", W("mobility", {hasTarget = true, gap = 60, maxR = 100}), 0.8)
eq("mob gap far", W("mobility", {hasTarget = true, gap = 200, maxR = 100}), 0)
eq("mob close", W("mobility", {hasTarget = true, gap = 20}), 0)
eq("mob travel", W("mobility", {goalDist = 300}), 0.5)
eq("mob none", W("mobility", {goalDist = 50}), 0)
eq("ranged in", W("ranged", {hasTarget = true, dist = 40, minR = 10, maxR = 80}), 0.8)
eq("ranged near", W("ranged", {hasTarget = true, dist = 5, minR = 10, maxR = 80}), 0)
eq("ranged none", W("ranged", {dist = 40, minR = 10, maxR = 80}), 0)
eq("melee", W("melee", {hasTarget = true, gap = 4, maxR = 6}), 0.8)
eq("control", W("control", {hasTarget = true, gap = 20, maxR = 30}), 0.75)
eq("control out", W("control", {hasTarget = true, gap = 40, maxR = 30}), 0)
near("aoe one", W("aoe", {foesNear = 1, hasTarget = true, gap = 5, radius = 15}), 0.75)
near("aoe three", W("aoe", {foesNear = 3}), 1)
eq("aoe none", W("aoe", {foesNear = 0}), 0)
eq("aoe far target", W("aoe", {foesNear = 1, hasTarget = true, gap = 30, radius = 15}), 0)
eq("defend hit", W("defend", {hpFrac = 0.5, recentlyHit = true}), 0.8)
eq("defend crowd", W("defend", {hpFrac = 1, foesNear = 2}), 0.6)
eq("defend calm", W("defend", {hpFrac = 1}), 0)
eq("heal self", W("heal", {hpFrac = 0.3}), 0.8)
eq("heal mate", W("heal", {hpFrac = 1, mateLow = true}), 0.7)
eq("heal no", W("heal", {hpFrac = 1}), 0)
eq("buff", W("buff", {hasTarget = true, gap = 10}), 0.7)
eq("buff far", W("buff", {hasTarget = true, gap = 40}), 0)
eq("stealth low", W("stealth", {hpFrac = 0.3, foesNear = 1}), 0.8)
eq("stealth ambush", W("stealth", {hasTarget = true, gap = 60}), 0.5)
eq("zone point", W("zone", {onPoint = true, foesNear = 1}), 0.7)
eq("trap near", W("trap", {hasTarget = true, gap = 20}), 0.55)
eq("sense", W("sense", {goalDist = 100}), 0.4)
eq("sense target", W("sense", {hasTarget = true, goalDist = 100}), 0)
eq("unknown", W("x", {}), 0)
eq("nil ctx", W("heal", nil), 0)
-- pickLoadout
local lo = R.pickLoadout({"a", "b", "c", "thrusters", "e"}, {"thrusters"}, 4, Random.new(3))
eq("lo first mobility", lo[1], "thrusters")
eq("lo size", #lo, 4)
local seen = {}
local dup = false
for _, id in ipairs(lo) do if seen[id] then dup = true end seen[id] = true end
eq("lo no dup", dup, false)
local lo2 = R.pickLoadout({"a", "b"}, {"thrusters"}, 4, Random.new(3))
eq("lo no mobility live", #lo2, 2)
eq("lo none", #R.pickLoadout({}, {}, 4, Random.new(1)), 0)
eq("lo zero slots", #R.pickLoadout({"a"}, {"a"}, 0, Random.new(1)), 0)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
