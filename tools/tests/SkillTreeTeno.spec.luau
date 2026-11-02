-- SkillTreeTeno.spec v1.1 (Mecha Dino Arena) — the Tenontosaurus rows of ServerStorage.DinoArcade.SkillTree 1.45 (plan
-- docs/plans/TENO_STATS_v1.0.md Task 1). Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.SkillTreeTeno_spec,
-- loadstring(Source)()); returns "PASS n" or "FAIL ...".
-- v1.1: SkillTree 1.48 Buck Off star text + buckCharge.
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
for _, id in ipairs({"regen", "lifesteal", "jaws", "hide", "legs"}) do
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
eq("teno stat rows", table.concat(seen, ","), "brace,chargeup,buckoff")
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
-- the Herrera rows unchanged
eq("herrera razor II", ST.effects({jaws = 2}, "Herrera").slashRefillMul, 0.65)
eq("herrera rows unchanged", ST.seesPath(P.stalker, "Herrera"), true)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
