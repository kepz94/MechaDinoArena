-- BalancePass1.spec v1.1 (Mecha Dino Arena) — balance pass 1 (plan docs/plans/BALANCE_PASS_v1.0.md, MDA-357 .. MDA-364) in
-- Studio: the installed model data against the plan table, and SkillTree 1.73's BALANCE_PASS1 block against a clone with the
-- switch off (only the listed fields / texts may differ). Run in Studio Edit (paste into execute_luau, or a copy in
-- ServerStorage.DinoArcadeTools.BalancePass1_spec, loadstring(Source)()); returns "PASS n" or "FAIL ...".
-- The offline twin is tools/tests/balance_pass1_check.py (repo files, generators, latch simulation); this one reads what is
-- installed in ServerStorage.DinoArcade, so it is red until the pass is installed.
-- v1.1 (Kepu 2026-11-09 answers): DiloModelData 1.5 (Cobra Leap plain: JumpCharges 0), walk x the run ratio (TenoModelData 1.6
--   38, TherizinoModelData 1.7 42.5, TRexModelData 2.2 + the StarterCharacter 39.5), BotServer 1.28 latch defaults (script
--   attributes unset or equal), SkillEffects 1.49 (no dilo leap keep).
local DA = game.ServerStorage.DinoArcade
local function load(off)
	local src = DA.SkillTree
	local c = src:Clone()
	if off then
		local s = c.Source
		local a, b = s:find("SkillTree.BALANCE_PASS1 = true", 1, true)
		if not a then error("BALANCE_PASS1 line not found") end
		c.Source = s:sub(1, a - 1) .. "SkillTree.BALANCE_PASS1 = false" .. s:sub(b + 1)
	end
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end
local ok, ST = pcall(load, false)
if not ok then return "FAIL require: " .. tostring(ST) end
local ok2, OFF = pcall(load, true)
if not ok2 then return "FAIL require off: " .. tostring(OFF) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-9) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end

-- 1. model data (plan table; the T-Rex row is TRexModelData, the live T-Rex is the StarterCharacter: checked too)
local PLAN = {
	HerreraModelData = {HerreraModelVersion = "1.5", SlashDamage = 15, SlashCharges = 3, SlashRefill = 2.5, SlashBleedDps = 4},
	TroodonModelData = {TroodonModelVersion = "1.6", TrooPodDamage = 12, TrooZoneDps = 6, TrooPodCharges = 3, TrooPodRefill = 2,
		JumpCooldown = 0.25},
	DiloModelData = {DiloModelVersion = "1.5", DiloBiteDamage = 15, DiloDartDamage = 10, DiloVenomDps = 4, MoveRunSpeed = 78,
		MoveWalkSpeed = 42.5, JumpCharges = 0, JumpCooldown = 0.25, DiloHoldTime = 0.25, DiloDartCooldown = 0.75},
	TenoModelData = {TenoModelVersion = "1.6", MoveWalkSpeed = 38, TenoScratchDamage = 12, TenoSlamDamage = 25, MoveRunSpeed = 66, JumpLaunchPower = 64,
		JumpCooldown = 0.25},
	TherizinoModelData = {TherizinoModelVersion = "1.7", MoveWalkSpeed = 42.5, TheriHitDamage1 = 11, TheriHitDamage2 = 11, TheriHitDamage3 = 24,
		JumpCharges = 3, JumpCooldown = 3, MoveRunSpeed = 78},
	TRexModelData = {TRexModelVersion = "2.2", BiteDamage = 30, MoveRunSpeed = 74, MoveWalkSpeed = 39.5},
	RaptorModelData = {RaptorModelVersion = "1.14", PounceTickDamage = 5, PounceLatchDrain = 32, PounceLatchMaxTime = 2.5,
		PounceLandDamage = 8, PounceTickInterval = 0.5, JumpCooldown = 0.25},
	PachyModelData = {PachyModelVersion = "1.6", JumpCooldown = 0.25},
}
for name, want in pairs(PLAN) do
	local m = DA:FindFirstChild("Models") and DA.Models:FindFirstChild(name)
	local okD, data = pcall(function() return loadstring(m.Source)() end)
	if not okD then table.insert(fails, name .. ": not loaded " .. tostring(data)) else
		for k, v in pairs(want) do eq(name .. "." .. k, data.attributes[k], v) end
	end
end
local sc = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
eq("StarterCharacter BiteDamage (live T-Rex)", sc and sc:GetAttribute("BiteDamage"), 30)
eq("StarterCharacter MoveRunSpeed (live T-Rex)", sc and sc:GetAttribute("MoveRunSpeed"), 74)
eq("StarterCharacter MoveWalkSpeed (live T-Rex)", sc and sc:GetAttribute("MoveWalkSpeed"), 39.5) -- v1.1
-- v1.1: scripts
local SSS = game:GetService("ServerScriptService")
local bs = SSS:FindFirstChild("BotServer")
eq("BotServer 1.28", bs and bs.Source:find('VERSION = "1.28"', 1, true) ~= nil, true)
for k, v in pairs({BotLatchBalanceEnabled = true, BotLatchMaxTime = 2.5, BotLatchLandDamage = 8, BotLatchTickDamage = 5,
	BotLatchTickInterval = 0.5}) do
	local a = bs and bs:GetAttribute(k)
	eq("BotServer " .. k .. " (unset or default)", a == nil or a == v, true)
	eq("BotServer DEFAULTS." .. k, bs and bs.Source:find(("DEFAULTS.%s = %s "):format(k, tostring(v)), 1, true) ~= nil, true)
end
local se = SSS:FindFirstChild("SkillEffects")
eq("SkillEffects 1.49, no dilo leap keep", se and (se.Source:find('VERSION = "1.49"', 1, true) ~= nil
	and se.Source:find("SkillEffectsDiloLeapKeepEnabled", 1, true) == nil), true)
local ps = SSS:FindFirstChild("PounceServer")
eq("PounceServer 1.16", ps and ps.Source:find('"PounceServerVersion", "1.16"', 1, true) ~= nil, true)
local tj = SSS:FindFirstChild("TRexJump")
eq("TRexJump 1.1", tj and tj.Source:find('local VERSION = "1.1"', 1, true) ~= nil, true)

-- 2. SkillTree 1.73: effects
eq("switch on", ST.BALANCE_PASS1, true); eq("switch off clone", OFF.BALANCE_PASS1, false)
local H = function(t, M) return (M or ST).effects(t, "Herrera") end
eq("razor III bleed 5", H({jaws = 3}).slashBleedDps, 5); eq("razor III bleed off clone 3", H({jaws = 3}, OFF).slashBleedDps, 3)
eq("razor I attack 3 kept", H({jaws = 1}).attackPts, 3); eq("razor II x0.65 kept", H({jaws = 2}).slashRefillMul, 0.65)
eq("razor star +1 kept", H({jaws = 4}).slashExtraCharges, 1); eq("unbought bleed 0", H({}).slashBleedDps, 0)
local T = function(t, M) return (M or ST).effects(t, "Therizino") end
eq("fury I hit2 14", T({fury = 1}).furyHit2, 14); eq("fury II finisher 30", T({fury = 2}).furyFinisher, 30)
eq("fury I finisher off", T({fury = 1}).furyFinisher, 0); eq("fury unbought 0", T({}).furyHit2, 0)
eq("fury off clone 12 / 26", ("%d/%d"):format(T({fury = 1}, OFF).furyHit2, T({fury = 2}, OFF).furyFinisher), "12/26")
local D = function(t) return ST.effects(t, "Dilo") end
local holds, cds = {0.22, 0.19, 0.19, 0.16}, {0, 0, 0.63, 0.5}
for i = 1, 4 do
	eq("quickdraw " .. i .. " hold", D({quickdraw = i}).drawHold, holds[i], 1e-6)
	eq("quickdraw " .. i .. " cooldown", D({quickdraw = i}).drawCooldown, cds[i], 1e-6)
	eq("quickdraw " .. i .. " faster than the base", D({quickdraw = i}).drawHold < 0.25, true)
end
eq("quickdraw unbought 0", D({}).drawHold, 0)
-- every other field of every dino is the same with the switch off
local CHANGED = {Herrera = {slashBleedDps = true}, Therizino = {furyHit2 = true, furyFinisher = true},
	Dilo = {drawHold = true, drawCooldown = true}}
local SAMPLES = {
	Herrera = {{}, {jaws = 4, frenzy = 4, lifesteal = 4, hide = 4, legs = 4}},
	Therizino = {{}, {fury = 4, flow = 4, guard = 4, harvest = 4, fourth = 4}},
	Dilo = {{}, {quickdraw = 4, venombite = 4, longspit = 4, coldblood = 4}},
	Teno = {{}, {heavytail = 4, frontclaws = 4, buckoff = 4, survivor = 4, hide = 4}},
	TRex = {{}, {jaws = 4, regen = 4, hide = 4, legs = 4}}, Raptor = {{}, {blade = 4, thrusters = 4, regen = 4}},
	Pachy = {{}, {dome = 4, crest = 4, mechalegs = 4}}, Troodon = {{}, {jaws = 4, regen = 4}}, [""] = {{}, {jaws = 4, regen = 4}},
}
for dino, list in pairs(SAMPLES) do
	local key = dino ~= "" and dino or nil
	for i, steps in ipairs(list) do
		local a, b = ST.effects(steps, key), OFF.effects(steps, key)
		local diff = {}
		for k, v in pairs(b) do if a[k] ~= v and not (CHANGED[dino] and CHANGED[dino][k] and i > 1) then table.insert(diff, k) end end
		for k in pairs(a) do if b[k] == nil then table.insert(diff, k .. "(new)") end end
		eq((key or "nil") .. " sample " .. i .. " only the listed fields differ", #diff == 0 and "same" or table.concat(diff, ","), "same")
	end
end

-- 3. SkillTree 1.73: texts
local P = ST.PATHS
local js = P.jaws.stepsFor.Herrera
eq("razor I text", js[1], "Slash hits harder (+3 Attack points: slash 15 -> 18)")
eq("razor II text", js[2], "Slash charges refill 35% faster (2.5 s -> 1.6 s)")
eq("razor III text", js[3], "Bleed burns hotter: 5 per second (was 4)")
eq("razor star text", js[4], "A 4th slash charge")
eq("fury I text", P.fury.steps[1], "Cut 2 hits harder (11 -> 14)")
eq("fury II text", P.fury.steps[2], "The finisher hits harder (24 -> 30)")
eq("quickdraw I text", P.quickdraw.steps[1], "Spit ready after a 0.22 s hold (was 0.25)")
eq("quickdraw II text", P.quickdraw.steps[2], "Spit ready after a 0.19 s hold")
eq("quickdraw III text", P.quickdraw.steps[3], "Dart recharges in 0.63 s (was 0.75)")
eq("quickdraw star text", P.quickdraw.steps[4], "0.16 s hold, and the dart recharges in 0.5 s")
eq("claws I text", P.frontclaws.steps[1], "Scratch hits harder (12 -> 15)")
eq("heavy I text", P.heavytail.steps[1], "Tail slam +3 damage (25 -> 28)")
eq("trex jaws I text", P.jaws.steps[1], "Main attack hits harder (+5 Attack points: T-Rex bite 30 -> 40)")
local TEXTS = {jaws = true, fury = true, quickdraw = true, frontclaws = true, heavytail = true}
local textDiff = {}
for id, p in pairs(OFF.PATHS) do
	local q = P[id]
	if not q then table.insert(textDiff, id .. "(gone)") elseif not TEXTS[id] then
		for i = 1, #p.steps do if p.steps[i] ~= q.steps[i] then table.insert(textDiff, id .. i) end end
	end
end
eq("other step texts unchanged", #textDiff == 0 and "same" or table.concat(textDiff, ","), "same")

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
