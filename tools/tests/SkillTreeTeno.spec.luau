-- SkillTreeTeno.spec v1.2 (Mecha Dino Arena) — the Tenontosaurus rows of ServerStorage.DinoArcade.SkillTree 1.45 (plan
-- docs/plans/TENO_STATS_v1.0.md Task 1). Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.SkillTreeTeno_spec,
-- loadstring(Source)()); returns "PASS n" or "FAIL ...".
-- v1.1: SkillTree 1.48 Buck Off star text + buckCharge.
-- v1.2: SkillTree 1.50 teno stats part 2 (plan docs/plans/TENO_STATS_v1.1.md): Survivor, Heavy Tail, Front Claws rows,
--   the shared Thick Hide re-opened for the teno as Armored Hide, and their effects fields.
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

eq("TENO_STATS", ST.TENO_STATS, true)
-- area + rows
local sig
for _, a in ipairs(ST.AREAS) do if a.id == "sig" then sig = a end end
eq("sig area", sig and sig.name, "Signature")
for id, want in pairs({chargeup = {"Charge Up", "speed"}, brace = {"Brace", "defense"}, buckoff = {"Buck Off", "sig"}}) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, want[1])
		eq(id .. " area", P[id].area, want[2])
		eq(id .. " dino", P[id].dino, "Teno")
		eq(id .. " not a part", P[id].mech, false)
		eq(id .. " steps", #P[id].steps, 4)
		eq(id .. " owner", ST.OWNER[id], "Teno")
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		for _, d in ipairs({"TRex", "Raptor", "Pachy", "Herrera"}) do eq(id .. " hidden " .. d, ST.seesPath(P[id], d), false) end
		eq(id .. " teno sees", ST.seesPath(P[id], "Teno"), true)
	end
end
if P.chargeup then eq("charge I text", P.chargeup.steps[1], "After 2 s of running: run 10% faster") end
if P.buckoff then eq("buck star text", P.buckoff.steps[4], "A raptor that latches on takes 3 damage per second until it lets go, and your tail slam gets a 4th charge") end -- v1.1
-- shared rows hidden from the teno (and still shown to the others as before)
for _, id in ipairs({"regen", "lifesteal", "jaws", "legs"}) do -- v1.2: hide is the teno's Armored Hide now
	eq(id .. " hidden teno", ST.seesPath(P[id], "Teno"), false)
end
eq("legs still trex", ST.seesPath(P.legs, "TRex"), true)
eq("hide still raptor", ST.seesPath(P.hide, "Raptor"), true)
eq("lifesteal still herrera", ST.seesPath(P.lifesteal, "Herrera"), true)
-- the teno's whole STATS list (passive rows it sees)
local seen = {}
for _, a in ipairs(ST.AREAS) do
	for _, p in ipairs(ST.pathsFor(a.id, "Teno")) do
		if not p.mech then table.insert(seen, p.id) end
	end
end
eq("teno stat rows", table.concat(seen, ","), "survivor,heavytail,frontclaws,hide,brace,chargeup,buckoff") -- v1.2
eq("sanitize keeps teno", ST.sanitize({brace = 2}, "Teno").brace, 2)
eq("sanitize drops on trex", ST.sanitize({brace = 2}, "TRex").brace, 0)
eq("sanitize drops regen on teno", ST.sanitize({regen = 3}, "Teno").regen, 0)
eq("canBuy teno", (ST.canBuy({}, "buckoff", 5, "Teno")), true)
eq("canBuy other", select(2, ST.canBuy({}, "buckoff", 5, "Raptor")), "otherDino")
-- effects
local E = function(t) return ST.effects(t, "Teno") end
local z = E({})
for k, v in pairs({chargeMul1 = 1, chargeMul2 = 1, chargeNoShove = false, chargeBump = 0, chargeBumpStun = 0, braceMul = 1,
	braceNoStun = false, braceStack = 0, braceHeal = 0, buckBonus = 0, buckFree = false, buckImmune = 0, buckDps = 0}) do
	eq("off " .. k, z[k], v)
	eq("trex off " .. k, ST.effects({}, "TRex")[k], v)
end
eq("charge I mul1", E({chargeup = 1}).chargeMul1, 1.1); eq("charge I mul2", E({chargeup = 1}).chargeMul2, 1.1)
eq("charge I no shove off", E({chargeup = 1}).chargeNoShove, false)
eq("charge II mul2", E({chargeup = 2}).chargeMul2, 1.2); eq("charge II shove", E({chargeup = 2}).chargeNoShove, true)
eq("charge II no bump", E({chargeup = 2}).chargeBump, 0)
eq("charge III bump", E({chargeup = 3}).chargeBump, 10); eq("charge III no stun", E({chargeup = 3}).chargeBumpStun, 0)
eq("charge star stun", E({chargeup = 4}).chargeBumpStun, 0.5)
eq("brace I mul", E({brace = 1}).braceMul, 0.8); eq("brace I no immune", E({brace = 1}).braceNoStun, false)
eq("brace II immune", E({brace = 2}).braceNoStun, true); eq("brace III stack", E({brace = 3}).braceStack, 3)
eq("brace II no stack", E({brace = 2}).braceStack, 0); eq("brace star heal", E({brace = 4}).braceHeal, 0.05)
eq("buck I bonus", E({buckoff = 1}).buckBonus, 10); eq("buck I no free", E({buckoff = 1}).buckFree, false)
eq("buck II free", E({buckoff = 2}).buckFree, true); eq("buck III immune", E({buckoff = 3}).buckImmune, 2)
eq("buck star dps", E({buckoff = 4}).buckDps, 3); eq("buck III no dps", E({buckoff = 3}).buckDps, 0)
eq("buck star charge", E({buckoff = 4}).buckCharge, 1); eq("buck III no charge", E({buckoff = 3}).buckCharge, 0) -- v1.1
eq("trex no buck charge", ST.effects({buckoff = 4}, "TRex").buckCharge, 0) -- v1.1
eq("teno rows give no stat points", E({chargeup = 4, brace = 4, buckoff = 4}).speedPts, 0)
-- v1.2: teno stats part 2
eq("TENO_STATS_2", ST.TENO_STATS_2, true)
for id, want in pairs({survivor = {"Survivor", "health"}, heavytail = {"Heavy Tail", "attack"}, frontclaws = {"Front Claws", "attack"}}) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, want[1]); eq(id .. " area", P[id].area, want[2]); eq(id .. " dino", P[id].dino, "Teno")
		eq(id .. " not a part", P[id].mech, false); eq(id .. " steps", #P[id].steps, 4); eq(id .. " owner", ST.OWNER[id], "Teno")
		for _, d in ipairs({"TRex", "Raptor", "Pachy", "Herrera"}) do eq(id .. " hidden " .. d, ST.seesPath(P[id], d), false) end
	end
end
if P.survivor then eq("survivor I text", P.survivor.steps[1], "A kill heals 15% of your max health over 4 s") end
if P.heavytail then eq("heavy I text", P.heavytail.steps[1], "Tail slam +3 damage (15 -> 18)") end
if P.frontclaws then eq("claws I text", P.frontclaws.steps[1], "Scratch hits harder (8 -> 11)") end
eq("hide seen by teno", ST.seesPath(P.hide, "Teno"), true)
eq("hide teno name", P.hide.nameFor and P.hide.nameFor.Teno, "Armored Hide")
eq("hide teno I text", P.hide.stepsFor and P.hide.stepsFor.Teno and P.hide.stepsFor.Teno[1], "Take 10% less damage, always")
eq("hide name for raptor unchanged", P.hide.name, "Thick Hide")
eq("hide herrera name unchanged", P.hide.nameFor and P.hide.nameFor.Herrera, "Wiry Frame")
local z2 = E({})
for k, v in pairs({survivorKillHeal = 0, survivorNearHeal = 0, survivorNearRange = 0, survivorRefill = false, heavyBonus = 0,
	heavyRefillMul = 1, heavyReachMul = 1, heavySlow = 0, heavySlowTime = 0, clawBonus = 0, clawCone = 0, clawGap = 0, clawSlow = 0,
	clawSlowTime = 0}) do
	eq("off2 " .. k, z2[k], v)
	eq("trex off2 " .. k, ST.effects({survivor = 4, heavytail = 4, frontclaws = 4}, "TRex")[k], v)
	eq("raptor off2 " .. k, ST.effects({}, "Raptor")[k], v)
end
eq("survivor I", E({survivor = 1}).survivorKillHeal, 0.15); eq("survivor I no near", E({survivor = 1}).survivorNearHeal, 0)
eq("survivor II", E({survivor = 2}).survivorKillHeal, 0.25)
eq("survivor III near", E({survivor = 3}).survivorNearHeal, 0.10); eq("survivor III range", E({survivor = 3}).survivorNearRange, 25)
eq("survivor III no refill", E({survivor = 3}).survivorRefill, false); eq("survivor star refill", E({survivor = 4}).survivorRefill, true)
eq("heavy I bonus", E({heavytail = 1}).heavyBonus, 3); eq("heavy I refill off", E({heavytail = 1}).heavyRefillMul, 1)
eq("heavy II refill", E({heavytail = 2}).heavyRefillMul, 0.75); eq("heavy II reach off", E({heavytail = 2}).heavyReachMul, 1)
eq("heavy III reach", E({heavytail = 3}).heavyReachMul, 1.2); eq("heavy III no slow", E({heavytail = 3}).heavySlow, 0)
eq("heavy star slow", E({heavytail = 4}).heavySlow, 0.3); eq("heavy star slow time", E({heavytail = 4}).heavySlowTime, 3)
eq("claws I bonus", E({frontclaws = 1}).clawBonus, 3); eq("claws I cone off", E({frontclaws = 1}).clawCone, 0)
eq("claws II cone", E({frontclaws = 2}).clawCone, 130); eq("claws II gap off", E({frontclaws = 2}).clawGap, 0)
eq("claws III gap", E({frontclaws = 3}).clawGap, 0.35); eq("claws III no slow", E({frontclaws = 3}).clawSlow, 0)
eq("claws star slow", E({frontclaws = 4}).clawSlow, 0.3); eq("claws star slow time", E({frontclaws = 4}).clawSlowTime, 1.5)
eq("armored I defense 2", E({hide = 1}).defensePts, 2); eq("armored II toss", E({hide = 2}).tossMul, 0.5)
eq("armored III stun 0.7", E({hide = 3}).stunMul, 0.7); eq("armored star immune", E({hide = 4}).stunImmuneAbove, 0.5)
eq("raptor thick hide I still 6", ST.effects({hide = 1}, "Raptor").defensePts, 6)
eq("raptor thick hide III still 0.7", ST.effects({hide = 3}, "Raptor").stunMul, 0.7)
eq("sanitize keeps survivor", ST.sanitize({survivor = 2, hide = 3}, "Teno").survivor, 2)
eq("sanitize keeps teno hide", ST.sanitize({hide = 3}, "Teno").hide, 3)
eq("sanitize drops survivor on pachy", ST.sanitize({survivor = 2}, "Pachy").survivor, 0)
-- the Herrera rows unchanged
eq("herrera razor II", ST.effects({jaws = 2}, "Herrera").slashRefillMul, 0.65)
eq("herrera rows unchanged", ST.seesPath(P.stalker, "Herrera"), true)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
