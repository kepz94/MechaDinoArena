-- SkillTreeTheriParts.spec v1.0 (Mecha Dino Arena) — the Therizinosaurus' 7 mecha button parts in
-- ServerStorage.DinoArcade.SkillTree 1.61 (plan docs/plans/THERIZINO_PARTS_v1.0.md Task 1, MDA-241). Run in Studio Edit (copy in
-- ServerStorage.DinoArcadeTools.SkillTreeTheriParts_spec, clone + require); returns "PASS n" or "FAIL ...".
-- Build 1 (Kepu 2026-11-04 "Two builds"): zhook / zfeather / zharvest / zsnare live; zgrapple / zdeflect / zclock "soon".
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

eq("THERI_PARTS", ST.THERI_PARTS, true)
eq("THERI_PARTS_B2_SOON", ST.THERI_PARTS_B2_SOON, true)
local ROWS = {
	zhook = {"Reaper's Hook", "attack", false}, zfeather = {"Feather Barrage", "attack", false},
	zharvest = {"Harvest Field", "attack", false}, zsnare = {"Snare Wires", "eng", false},
	zgrapple = {"Grapple Zip", "speed", true}, zdeflect = {"Deflector Claws", "defense", true},
	zclock = {"Overclock Joints", "speed", true},
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
		eq(id .. " owner", ST.OWNER[id], "Therizino")
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		for _, d in ipairs({"TRex", "Raptor", "Herrera", "Teno", "Pachy", "Dilo"}) do eq(id .. " hidden " .. d, ST.seesPath(P[id], d), false) end
		eq(id .. " theri sees", ST.seesPath(P[id], "Therizino"), true)
	end
end
-- the step texts the Lab shows
local TEXT = {
	zhook = {"Button: fire a claw chain up to 50 studs and yank the dino in. Recharges in 18 s", "Chain reaches 65 studs",
		"Chain reaches 80 studs; recharges in 15 s", "The yanked dino is stunned 1 s and cut 1 starts on it"},
	zfeather = {"Button: fire 8 feather blades in a 20-stud fan: 3 damage each, hit dinos slowed 25% for 1 s. Recharges in 14 s",
		"10 blades, fan reaches 25 studs", "Slow lasts 2 s", "12 blades, fan reaches 30 studs"},
	zharvest = {"Button: stab the claws down: a 12-stud-wide circle for 3 s. Enemies inside bleed 4/s and are slowed 30%. Recharges in 20 s",
		"Circle 16 studs wide", "Lasts 4 s", "Circle 20 studs wide, lasts 5 s"},
	zsnare = {"Button: lay a wire trap. The first dino to cross it is rooted 1 s and takes 12. Recharges in 18 s",
		"2 traps at once", "Rooted 2 s", "3 traps at once"},
}
for id, t in pairs(TEXT) do
	if P[id] then for i = 1, 4 do eq(id .. " text " .. i, P[id].steps[i], t[i]) end end
end
-- effects: off values (nothing bought, other dinos)
local OFF = {hookRange = 0, hookCone = 0, hookStun = 0, hookCut = false, hookCooldown = 0, featherCount = 0, featherRange = 0,
	featherFan = 0, featherDamage = 0, featherSlowMul = 1, featherSlowTime = 0, featherCooldown = 0, fieldRadius = 0, fieldTime = 0,
	fieldBleed = 0, fieldSlowMul = 1, fieldCooldown = 0, grappleRange = 0, grappleCharges = 0, grappleCooldown = 0,
	deflectTime = 0, deflectAngle = 0, deflectLevel = 0, deflectReflect = false, deflectCooldown = 0, clockTime = 0,
	clockRunMul = 1, clockTapMul = 1, clockNoSlow = false, clockCooldown = 0, snareMax = 0, snareDamage = 0, snareRoot = 0,
	snareRadius = 0, snareCooldown = 0}
local ALL = {zhook = 4, zfeather = 4, zharvest = 4, zsnare = 4, zgrapple = 4, zdeflect = 4, zclock = 4}
local z = E({})
for k, v in pairs(OFF) do
	eq("off " .. k, z[k], v)
	for _, d in ipairs({"Raptor", "Teno", "Pachy", "Dilo"}) do eq(d .. " off " .. k, ST.effects(ALL, d)[k], v) end
end
-- effects per step (build 1)
local function chk(id, field, want) for i = 1, 4 do eq(("%s %d %s"):format(id, i, field), E({[id] = i})[field], want[i], 1e-6) end end
chk("zhook", "hookRange", {50, 65, 80, 80}); chk("zhook", "hookCone", {20, 20, 20, 20}); chk("zhook", "hookStun", {0, 0, 0, 1})
chk("zhook", "hookCut", {false, false, false, true}); chk("zhook", "hookCooldown", {18, 18, 15, 15})
chk("zfeather", "featherCount", {8, 10, 10, 12}); chk("zfeather", "featherRange", {20, 25, 25, 30})
chk("zfeather", "featherFan", {60, 60, 60, 60}); chk("zfeather", "featherDamage", {3, 3, 3, 3})
chk("zfeather", "featherSlowMul", {0.75, 0.75, 0.75, 0.75}); chk("zfeather", "featherSlowTime", {1, 1, 2, 2})
chk("zfeather", "featherCooldown", {14, 14, 14, 14})
chk("zharvest", "fieldRadius", {6, 8, 8, 10}); chk("zharvest", "fieldTime", {3, 3, 4, 5}); chk("zharvest", "fieldBleed", {4, 4, 4, 4})
chk("zharvest", "fieldSlowMul", {0.7, 0.7, 0.7, 0.7}); chk("zharvest", "fieldCooldown", {20, 20, 20, 20})
chk("zsnare", "snareMax", {1, 2, 2, 3}); chk("zsnare", "snareDamage", {12, 12, 12, 12}); chk("zsnare", "snareRoot", {1, 1, 2, 2})
chk("zsnare", "snareRadius", {4, 4, 4, 4}); chk("zsnare", "snareCooldown", {18, 18, 18, 18})
-- build-2 parts are soon: saved steps give nothing yet
eq("grapple soon gives nothing", E({zgrapple = 4}).grappleRange, 0)
eq("deflect soon gives nothing", E({zdeflect = 4}).deflectTime, 0)
eq("clock soon gives nothing", E({zclock = 4}).clockTime, 0)
-- buying / slotting
eq("canBuy hook theri", (ST.canBuy({}, "zhook", 5, "Therizino")), true)
eq("canBuy hook raptor", select(2, ST.canBuy({}, "zhook", 5, "Raptor")), "otherDino")
eq("canBuy grapple soon", select(2, ST.canBuy({}, "zgrapple", 5, "Therizino")), "soon")
local lo = ST.sanitizeLoadout({"zhook", "zfeather", "zharvest", "zsnare"}, {zhook = 1, zfeather = 1, zharvest = 1, zsnare = 1}, "Therizino")
eq("slot 1", lo[1], "zhook"); eq("slot 2", lo[2], "zfeather"); eq("slot 3", lo[3], "zharvest"); eq("slot 4", lo[4], "zsnare")
eq("raptor cannot slot", ST.sanitizeLoadout({"zhook"}, {zhook = 1}, "Raptor")[1], false)
-- the therizino's stat rows unchanged
local rows = {}
for _, a in ipairs(ST.AREAS) do
	for _, p in ipairs(ST.pathsFor(a.id, "Therizino")) do if not p.mech then table.insert(rows, p.id) end end
end
eq("theri stat rows", table.concat(rows, ","), "harvest,fury,guard,flow,fourth")
eq("theri harvest heal still", E({harvest = 1}).harvestHeal, 0.04)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
