-- SkillTreeDiloParts.spec v1.2 (1.2: MDA-365 Spring Jets 4.2 s; Mecha Dino Arena) — the Dilophosaurus' 7 mecha button parts in ServerStorage.DinoArcade.SkillTree
-- 1.69 (plan docs/plans/DILO_PARTS_v1.0.md Task 1, MDA-314). Run in Studio Edit (copy in
-- ServerStorage.DinoArcadeTools.SkillTreeDiloParts_spec, clone + require); returns "PASS n" or "FAIL ...".
-- Build 1 (Kepu 2026-11-06 two builds): dgatling / dmortar / dspine / dover live; dhiss / dpump / djets "soon".
-- v1.1 (build 2, MDA-320; SkillTree 1.70 DILO_PARTS_B2_LIVE): all 7 live; the build-2 texts, ladders, buying and slotting.
-- The no-overwrite check (the 1.61 hookRange lesson): a second clone with "SkillTree.DILO_PARTS = true" switched to false is
-- required too, and every other dino's effects table (minus the new d* fields) must be identical between the two.
local function load(off)
	local src = game.ServerStorage.DinoArcade.SkillTree
	local c = src:Clone()
	if off then
		local s = c.Source
		local a, b = s:find("SkillTree.DILO_PARTS = true", 1, true)
		if not a then error("DILO_PARTS line not found") end
		c.Source = s:sub(1, a - 1) .. "SkillTree.DILO_PARTS = false" .. s:sub(b + 1)
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
local P = ST.PATHS
local function E(steps) return ST.effects(steps, "Dilo") end

eq("DILO_PARTS", ST.DILO_PARTS, true)
eq("DILO_PARTS_B2_SOON", ST.DILO_PARTS_B2_SOON, true)
eq("DILO_PARTS_B2_LIVE", ST.DILO_PARTS_B2_LIVE, true) -- v1.1
eq("off clone has no dgatling", OFF.PATHS.dgatling == nil, true)
local ROWS = {
	dgatling = {"Venom Gatling", "attack", false}, dmortar = {"Toxin Mortar", "attack", false},
	dhiss = {"Sonic Hiss", "attack", false}, dspine = {"Spine Burst", "defense", false}, -- v1.1: build 2 live
	dpump = {"Antivenom Pump", "defense", false}, djets = {"Spring Jets", "speed", false},
	dover = {"Venom Overdrive", "sig", false},
}
for id, want in pairs(ROWS) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, want[1])
		eq(id .. " area", P[id].area, want[2])
		eq(id .. " is a part", P[id].mech, true)
		eq(id .. " soon", P[id].soon == true, want[3])
		eq(id .. " live", ST.LIVE_MECH[id] == true, not want[3])
		eq(id .. " button", ST.BUTTONS[id], true)
		eq(id .. " steps", #P[id].steps, 4)
		eq(id .. " owner", ST.OWNER[id], "Dilo")
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		for _, d in ipairs({"TRex", "Raptor", "Herrera", "Teno", "Pachy", "Therizino"}) do eq(id .. " hidden " .. d, ST.seesPath(P[id], d), false) end
		eq(id .. " dilo sees", ST.seesPath(P[id], "Dilo"), true)
	end
end
local TEXT = {
	dgatling = {"Button: the hood barrels fire 4 auto-aimed darts in 1 s: 3 damage each plus dart venom. Recharges in 12 s",
		"6 darts", "Recharges in 10 s", "8 darts"},
	dmortar = {"Button: the chest launcher lobs a canister up to 40 studs: a 16-stud poison cloud for 3 s. Recharges in 16 s",
		"Reaches 50 studs, cloud 20 studs wide", "Cloud lasts 4 s", "Reaches 60 studs, cloud 24 studs wide, lasts 5 s"},
	dspine = {"Button: the frill fires 6 spines all around: 4 damage each. Recharges in 12 s", "8 spines", "Spines add dart venom", "12 spines"},
	dover = {"Button: for 4 s your darts recharge at once. Recharges in 30 s", "Lasts 6 s", "Your venom does double damage while it's on", "Lasts 8 s"},
	dhiss = {"Button: the hood speakers blast a 20-stud cone: dinos are knocked back and their mecha parts are silenced 1.5 s. Recharges in 15 s",
		"Cone reaches 25 studs", "Silence lasts 2 s; recharges in 12 s", "Cone reaches 30 studs, silence lasts 3 s"},
	dpump = {"Button: the back pump clears your debuffs and heals 15. Recharges in 20 s", "Heals 20", "Heals 30",
		"Then 4 s immune to slows, stuns and blinds"},
	djets = {"Button: the tail booster dashes you 25 studs the way you move. Recharges in " .. (ST.MOVE_CD_PASS and "4.2" or "6") .. " s", "30 studs, 2 charges",
		"40 studs; leaves a poison trail", "3 charges"},
}
for id, t in pairs(TEXT) do
	if P[id] then for i = 1, 4 do eq(id .. " text " .. i, P[id].steps[i], t[i]) end end
end
-- effects ladders (steps 1..4); soon parts are dropped by sanitize, so they read off
local function chk(id, field, want)
	for n = 1, 4 do eq(id .. " " .. field .. " @" .. n, E({[id] = n})[field], want[n]) end
	local off = 0
	if type(want[1]) == "boolean" then off = false elseif field == "dOverVenomMul" then off = 1 end
	eq(id .. " " .. field .. " @0", E({})[field], off)
end
chk("dgatling", "dGatlingCount", {4, 6, 6, 8}); chk("dgatling", "dGatlingDamage", {3, 3, 3, 3})
chk("dgatling", "dGatlingCone", {25, 25, 25, 25}); chk("dgatling", "dGatlingTime", {1, 1, 1, 1})
chk("dgatling", "dGatlingCooldown", {12, 12, 10, 10})
chk("dmortar", "dMortarRange", {40, 50, 50, 60}); chk("dmortar", "dMortarRadius", {8, 10, 10, 12})
chk("dmortar", "dMortarTime", {3, 3, 4, 5}); chk("dmortar", "dMortarCooldown", {16, 16, 16, 16})
chk("dspine", "dSpineCount", {6, 8, 8, 12}); chk("dspine", "dSpineDamage", {4, 4, 4, 4})
chk("dspine", "dSpineRange", {22, 22, 22, 22}); chk("dspine", "dSpineVenom", {false, false, true, true})
chk("dspine", "dSpineCooldown", {12, 12, 12, 12})
chk("dover", "dOverTime", {4, 6, 6, 8}); chk("dover", "dOverVenomMul", {1, 1, 2, 2}); chk("dover", "dOverCooldown", {30, 30, 30, 30})
-- v1.1: build-2 ladders (live now)
chk("dhiss", "dHissRange", {20, 25, 25, 30}); chk("dhiss", "dHissAngle", {35, 35, 35, 35}); chk("dhiss", "dHissKnock", {18, 18, 18, 18})
chk("dhiss", "dHissSilence", {1.5, 1.5, 2, 3}); chk("dhiss", "dHissCooldown", {15, 15, 12, 12})
chk("dpump", "dPumpHeal", {15, 20, 30, 30}); chk("dpump", "dPumpImmune", {0, 0, 0, 4}); chk("dpump", "dPumpCooldown", {20, 20, 20, 20})
chk("djets", "dJetsDist", {25, 30, 40, 40}); chk("djets", "dJetsCharges", {1, 2, 2, 3}); chk("djets", "dJetsTrail", {0, 0, 6, 6})
chk("djets", "dJetsCooldown", ST.MOVE_CD_PASS and {4.2, 4.2, 4.2, 4.2} or {6, 6, 6, 6}) -- v1.2: MDA-365
-- other dinos read the off values, and their own fields are untouched by DILO_PARTS
eq("raptor dgatling off", ST.effects({dgatling = 4}, "Raptor").dGatlingCount, 0)
eq("pachy dmortar off", ST.effects({dmortar = 4}, "Pachy").dMortarRange, 0)
local SAMPLES = {
	Pachy = {{}, {hookarm = 4, mechalegs = 4, servodash = 4, visor = 4, ink = 4, tether = 4, medstation = 4, dome = 4, crest = 4, bloodrush = 4, laststand = 4, headdown = 4}, {hookarm = 1, ink = 2, dgatling = 4}},
	Therizino = {{}, {zhook = 4, zfeather = 4, zharvest = 4, zgrapple = 4, zdeflect = 4, zclock = 4, zsnare = 4, harvest = 4, fury = 4}, {zhook = 2, dmortar = 4}},
	Teno = {{}, {tmortar = 4, tstomp = 4, tbellow = 4, tchallenge = 4, tleap = 4, tgrab = 4, tmud = 4, buckoff = 4}, {tmortar = 1, dover = 4}},
	Herrera = {{}, {quills = 4, smoke = 4, goo = 4, glider = 4, frenzy = 4, stalker = 4}},
	Raptor = {{}, {thrusters = 4, cloak = 4, blade = 4, shield = 4, scent = 4, screech = 4, regen = 4, jaws = 4}},
}
for dino, list in pairs(SAMPLES) do
	for i, steps in ipairs(list) do
		local a, b = ST.effects(steps, dino), OFF.effects(steps, dino)
		local diff = {}
		for k, v in pairs(b) do if a[k] ~= v then table.insert(diff, k) end end
		for k in pairs(a) do if b[k] == nil and not k:match("^d[A-Z]") then table.insert(diff, k .. "(new)") end end
		eq(dino .. " sample " .. i .. " unchanged", #diff == 0 and "same" or table.concat(diff, ","), "same")
	end
end
-- the pachy hook values themselves (the hook stays as it is, not this plan's bug to fix)
eq("pachy hook effect same as off clone", ST.effects({hookarm = 4}, "Pachy").hookRange, OFF.effects({hookarm = 4}, "Pachy").hookRange)
-- buying / slotting
eq("canBuy gatling dilo", (ST.canBuy({}, "dgatling", 5, "Dilo")), true)
eq("canBuy gatling raptor", select(2, ST.canBuy({}, "dgatling", 5, "Raptor")), "otherDino")
eq("canBuy hiss live", (ST.canBuy({}, "dhiss", 5, "Dilo")), true) -- v1.1
eq("canBuy jets raptor", select(2, ST.canBuy({}, "djets", 5, "Raptor")), "otherDino")
local lo2 = ST.sanitizeLoadout({"dhiss", "dpump", "djets", "dover"}, {dhiss = 1, dpump = 1, djets = 1, dover = 1}, "Dilo")
eq("b2 slot 1", lo2[1], "dhiss"); eq("b2 slot 2", lo2[2], "dpump"); eq("b2 slot 3", lo2[3], "djets"); eq("b2 slot 4", lo2[4], "dover")
local lo = ST.sanitizeLoadout({"dgatling", "dmortar", "dspine", "dover"}, {dgatling = 1, dmortar = 1, dspine = 1, dover = 1}, "Dilo")
eq("slot 1", lo[1], "dgatling"); eq("slot 2", lo[2], "dmortar"); eq("slot 3", lo[3], "dspine"); eq("slot 4", lo[4], "dover")
eq("raptor cannot slot", ST.sanitizeLoadout({"dgatling"}, {dgatling = 1}, "Raptor")[1], false)
-- the dilo's stat rows unchanged
local rows = {}
for _, a in ipairs(ST.AREAS) do
	for _, p in ipairs(ST.pathsFor(a.id, "Dilo")) do if not p.mech then table.insert(rows, p.id) end end
end
table.sort(rows)
eq("dilo stat rows", table.concat(rows, ","), "coldblood,longspit,quickdraw,toxicblood,venombite,venomfeast")
eq("dilo venom bite still", E({venombite = 4}).venomBiteDps, 2)
if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
