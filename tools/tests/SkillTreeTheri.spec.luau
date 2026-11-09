-- SkillTreeTheri.spec v1.1 (Mecha Dino Arena) — the Therizinosaurus' own stat rows in ServerStorage.DinoArcade.SkillTree 1.57
-- (MDA-210, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 4; Kepu 2026-11-02/03: shared rows "None, all its own", theme
-- "Combo flow", rows "Keep all five", Fourth Cut "Mock it up first"). Run in Studio Edit (copy in
-- ServerStorage.DinoArcadeTools.SkillTreeTheri_spec, loadstring(Source)()); returns "PASS n" or "FAIL ...".
-- v1.1 (SkillTree 1.58, MDA-213: Kepu picked the Fourth Cut "C" Ground Scythe): THERI_FOURTH is true, the Fourth Cut row is the
-- therizino's (rows harvest, fury, guard, flow, fourth) and its effects are live (I 10, II 14, III reach x1.3, star fast).
-- v1.2 (SkillTree 1.73 balance pass 1, MDA-362): while ST.BALANCE_PASS1 Building Fury keeps its step over TherizinoModelData 1.6
--   (cuts 11 / 11 / 24): furyHit2 14, furyFinisher 30, texts "(11 -> 14)" / "(24 -> 30)".
local ok, ST = pcall(function()
	local src = game.ServerStorage.DinoArcade.SkillTree
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(ST) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-9) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local P = ST.PATHS
local function E(steps) return ST.effects(steps, "Therizino") end

eq("THERI_STATS", ST.THERI_STATS, true)
eq("THERI_FOURTH on (v1.1)", ST.THERI_FOURTH, true)
-- the rows
local ROWS = {flow = {"Flowing Cuts", "speed"}, fury = {"Building Fury", "attack"}, fourth = {"Fourth Cut", "sig"},
	guard = {"Flow Guard", "defense"}, harvest = {"Reaper's Harvest", "health"}}
for id, want in pairs(ROWS) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, want[1])
		eq(id .. " area", P[id].area, want[2])
		eq(id .. " not a part", P[id].mech, false)
		eq(id .. " steps", #P[id].steps, 4)
		eq(id .. " owner", ST.OWNER[id], "Therizino")
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		for _, d in ipairs({"TRex", "Raptor", "Pachy", "Herrera", "Teno"}) do eq(id .. " hidden " .. d, ST.seesPath(P[id], d), false) end
		eq(id .. " theri sees", ST.seesPath(P[id], "Therizino"), true) -- v1.1: fourth too
	end
end
if P.flow then eq("flow I text", P.flow.steps[1], "Chain window 0.8 -> 1.0 s: more time to tap the next cut") end
if P.fury then eq("fury star text", P.fury.steps[4], "A full 3-hit chain on one dino: the finisher deals x1.5") end
if P.harvest then eq("harvest I text", P.harvest.steps[1], "Each finisher hit heals 4% of your max health") end
-- shared rows hidden from the therizino, still shown to the others
for _, id in ipairs({"regen", "lifesteal", "jaws", "hide", "legs"}) do eq(id .. " hidden theri", ST.seesPath(P[id], "Therizino"), false) end
eq("hide still raptor", ST.seesPath(P.hide, "Raptor"), true)
eq("hide still teno (armored)", ST.seesPath(P.hide, "Teno"), true)
eq("legs still trex", ST.seesPath(P.legs, "TRex"), true)
eq("regen still raptor", ST.seesPath(P.regen, "Raptor"), true)
eq("lifesteal still herrera", ST.seesPath(P.lifesteal, "Herrera"), true)
-- the therizino's whole STATS list
local seen = {}
for _, a in ipairs(ST.AREAS) do
	for _, p in ipairs(ST.pathsFor(a.id, "Therizino")) do
		if not p.mech then table.insert(seen, p.id) end
	end
end
eq("theri stat rows", table.concat(seen, ","), "harvest,fury,guard,flow,fourth")
-- the teno's list unchanged
local tseen = {}
for _, a in ipairs(ST.AREAS) do
	for _, p in ipairs(ST.pathsFor(a.id, "Teno")) do if not p.mech then table.insert(tseen, p.id) end end
end
eq("teno stat rows unchanged", table.concat(tseen, ","), "survivor,heavytail,frontclaws,hide,brace,chargeup,buckoff")
-- effects: off values (no steps, other dinos)
local OFF = {flowWindow = 0, flowGap = 0, flowRecover = 0, flowRefill = false, furyHit2 = 0, furyFinisher = 0, furyStack = 0,
	furyFullMul = 1, fourthDamage = 0, fourthReachMul = 1, fourthFast = false, guardTakenMul = 1, guardFinisherNoStun = false,
	guardShoveMul = 1, guardKeepChain = false, harvestHeal = 0, harvestKillHeal = 0, harvestLowDouble = false}
local z = E({})
for k, v in pairs(OFF) do
	eq("off " .. k, z[k], v)
	eq("raptor off " .. k, ST.effects({flow = 4, fury = 4, guard = 4, harvest = 4, fourth = 4}, "Raptor")[k], v)
	eq("teno off " .. k, ST.effects({flow = 4, fury = 4, guard = 4, harvest = 4}, "Teno")[k], v)
end
-- effects per step
eq("flow I window", E({flow = 1}).flowWindow, 1.0); eq("flow I gap off", E({flow = 1}).flowGap, 0)
eq("flow II gap", E({flow = 2}).flowGap, 0.26); eq("flow II recover off", E({flow = 2}).flowRecover, 0)
eq("flow III recover", E({flow = 3}).flowRecover, 0.55); eq("flow III no refill", E({flow = 3}).flowRefill, false)
eq("flow star refill", E({flow = 4}).flowRefill, true)
eq("fury I hit2", E({fury = 1}).furyHit2, ST.BALANCE_PASS1 and 14 or 12); -- v1.2
eq("fury I finisher off", E({fury = 1}).furyFinisher, 0)
eq("fury II finisher", E({fury = 2}).furyFinisher, ST.BALANCE_PASS1 and 30 or 26); -- v1.2
eq("fury II stack off", E({fury = 2}).furyStack, 0)
eq("fury III stack", E({fury = 3}).furyStack, 2); eq("fury III full off", E({fury = 3}).furyFullMul, 1)
eq("fury star full", E({fury = 4}).furyFullMul, 1.5)
eq("guard I taken", E({guard = 1}).guardTakenMul, 0.85); eq("guard I no stun off", E({guard = 1}).guardFinisherNoStun, false)
eq("guard II no stun", E({guard = 2}).guardFinisherNoStun, true); eq("guard II shove off", E({guard = 2}).guardShoveMul, 1)
eq("guard III shove", E({guard = 3}).guardShoveMul, 0.5); eq("guard III keep off", E({guard = 3}).guardKeepChain, false)
eq("guard star keep", E({guard = 4}).guardKeepChain, true)
eq("harvest I heal", E({harvest = 1}).harvestHeal, 0.04); eq("harvest I kill off", E({harvest = 1}).harvestKillHeal, 0)
eq("harvest II heal", E({harvest = 2}).harvestHeal, 0.06)
eq("harvest III kill", E({harvest = 3}).harvestKillHeal, 0.15); eq("harvest III double off", E({harvest = 3}).harvestLowDouble, false)
eq("harvest star double", E({harvest = 4}).harvestLowDouble, true)
eq("fourth I damage", E({fourth = 1}).fourthDamage, 10); eq("fourth I reach off", E({fourth = 1}).fourthReachMul, 1)
eq("fourth II damage", E({fourth = 2}).fourthDamage, 14); eq("fourth II fast off", E({fourth = 2}).fourthFast, false)
eq("fourth III reach", E({fourth = 3}).fourthReachMul, 1.3); eq("fourth III damage", E({fourth = 3}).fourthDamage, 14)
eq("fourth star fast", E({fourth = 4}).fourthFast, true)
eq("sanitize keeps fourth", ST.sanitize({fourth = 2}, "Therizino").fourth, 2)
eq("sanitize drops fourth on teno", ST.sanitize({fourth = 2}, "Teno").fourth, 0)
-- sanitize / mastery
eq("sanitize keeps flow", ST.sanitize({flow = 2}, "Therizino").flow, 2)
eq("sanitize drops shared hide", ST.sanitize({hide = 3}, "Therizino").hide, 0)
eq("sanitize drops flow on raptor", ST.sanitize({flow = 2}, "Raptor").flow, 0)
eq("mastery limit counts theri rows", ST.masteryOk({flow = 3, fury = 3, guard = 3, harvest = 3}, "Therizino"), false)
-- other dinos unchanged (spot checks)
eq("raptor thick hide I still 6", ST.effects({hide = 1}, "Raptor").defensePts, 6)
eq("teno armored I still 2", ST.effects({hide = 1}, "Teno").defensePts, 2)
eq("herrera razor II", ST.effects({jaws = 2}, "Herrera").slashRefillMul, 0.65)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
