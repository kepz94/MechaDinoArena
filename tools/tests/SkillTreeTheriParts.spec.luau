-- SkillTreeTheriParts.spec v1.7 (1.7: Bola reach 60 / 80, SkillTree 1.71 THERI_BOLA_RANGE_V2, MDA-324; 1.6: feather range 35 / 40 / 50, SkillTree 1.67; 1.5: Overclock III extra jump, SkillTree 1.66; 1.4: moves rework, SkillTree 1.65, MDA-262; 1.1: build 2 live, SkillTree 1.62; 1.2: grapple v2 + passive overclock, SkillTree 1.63; 1.3: grapple lock-on text, SkillTree 1.64) (Mecha Dino Arena) — the Therizinosaurus' 7 mecha button parts in
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
eq("THERI_PARTS_B2_LIVE", ST.THERI_PARTS_B2_LIVE, true) -- v1.1
eq("THERI_PARTS_B2_SOON", ST.THERI_PARTS_B2_SOON, false) -- v1.1
eq("THERI_GRAPPLE_V2", ST.THERI_GRAPPLE_V2, true) -- v1.2
eq("THERI_CLOCK_PASSIVE", ST.THERI_CLOCK_PASSIVE, true) -- v1.2
eq("THERI_GRAPPLE_LOCKON", ST.THERI_GRAPPLE_LOCKON, true) -- v1.3
for _, k in ipairs({"THERI_VORTEX", "THERI_BOLA", "THERI_DASH", "THERI_REEL"}) do eq(k, ST[k], true) end -- v1.4
local VX, BO, DA, RE = ST.THERI_VORTEX, ST.THERI_BOLA, ST.THERI_DASH, ST.THERI_REEL -- v1.4
local BR = BO and ST.THERI_BOLA_RANGE_V2 -- v1.7
eq("THERI_BOLA_RANGE_V2", ST.THERI_BOLA_RANGE_V2, true) -- v1.7
local ROWS = {
	zhook = {"Reaper's Hook", "attack", false}, zfeather = {"Feather Barrage", "attack", false},
	zharvest = {"Harvest Field", "attack", false}, zsnare = {"Snare Wires", "eng", false},
	zgrapple = {DA and "Dash" or "Grapple Zip", "speed", false}, zdeflect = {"Deflector Claws", "defense", false}, -- v1.1: live
	zclock = {"Overclock Joints", "speed", false},
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
	zhook = RE and {"Button: fire the chest claw at the nearest enemy ahead (50 studs) and reel yourself in for a double claw slash: 10 damage. Recharges in 14 s",
		"Chain reaches 65 studs", "Chain reaches 80 studs", "The slashed dino is stunned 1 s and cut 1 starts on it"} -- v1.4
		or {"Button: fire a claw chain up to 50 studs and yank the dino in. Recharges in 18 s", "Chain reaches 65 studs",
		"Chain reaches 80 studs; recharges in 15 s", "The yanked dino is stunned 1 s and cut 1 starts on it"},
	zfeather = ST.THERI_FEATHER_RANGE2 and {"Button: fire 8 feather blades in a 35-stud fan: 3 damage each, hit dinos slowed 25% for 1 s. Recharges in 14 s",
		"10 blades, fan reaches 40 studs", "Slow lasts 2 s", "12 blades, fan reaches 50 studs"} -- v1.6
		or {"Button: fire 8 feather blades in a 20-stud fan: 3 damage each, hit dinos slowed 25% for 1 s. Recharges in 14 s",
		"10 blades, fan reaches 25 studs", "Slow lasts 2 s", "12 blades, fan reaches 30 studs"},
	zharvest = VX and {"Button: stab the claws in: a spinning sickle ring 30 studs wide drags enemies toward you for 3 s. They bleed 4/s and are slowed 30%. Recharges in 20 s",
		"Ring 34 studs wide", "Lasts 4 s", "Ring 38 studs wide, lasts 5 s"} or {"Button: stab the claws down: a 12-stud-wide circle for 3 s. Enemies inside bleed 4/s and are slowed 30%. Recharges in 20 s",
		"Circle 16 studs wide", "Lasts 4 s", "Circle 20 studs wide, lasts 5 s"},
	zsnare = BR and {"Button: sling a bola from the tail at the nearest enemy ahead (60 studs). It wraps their legs: held 1 s, 12 damage. Recharges in 14 s",
		"2 bolas ready at once", "Held 2 s; reaches 80 studs", "3 bolas ready at once"} or BO and {"Button: sling a bola from the tail at the nearest enemy ahead (35 studs). It wraps their legs: held 1 s, 12 damage. Recharges in 14 s",
		"2 bolas ready at once", "Held 2 s; reaches 45 studs", "3 bolas ready at once"} or {"Button: lay a wire trap. The first dino to cross it is rooted 1 s and takes 12. Recharges in 18 s",
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
	snareRadius = 0, snareCooldown = 0, snareRange = 0, clockJump = 0}
local ALL = {zhook = 4, zfeather = 4, zharvest = 4, zsnare = 4, zgrapple = 4, zdeflect = 4, zclock = 4}
local z = E({})
for k, v in pairs(OFF) do
	eq("off " .. k, z[k], v)
	for _, d in ipairs({"Raptor", "Teno", "Pachy", "Dilo"}) do eq(d .. " off " .. k, ST.effects(ALL, d)[k], v) end
end
-- effects per step (build 1)
local function chk(id, field, want) for i = 1, 4 do eq(("%s %d %s"):format(id, i, field), E({[id] = i})[field], want[i], 1e-6) end end
chk("zhook", "hookRange", {50, 65, 80, 80}); chk("zhook", "hookCone", RE and {35, 35, 35, 35} or {20, 20, 20, 20}); chk("zhook", "hookStun", {0, 0, 0, 1})
chk("zhook", "hookCut", {false, false, false, true}); chk("zhook", "hookCooldown", RE and {14, 14, 14, 14} or {18, 18, 15, 15})
chk("zfeather", "featherCount", {8, 10, 10, 12}); chk("zfeather", "featherRange", ST.THERI_FEATHER_RANGE2 and {35, 40, 40, 50} or {20, 25, 25, 30}) -- v1.6
eq("THERI_FEATHER_RANGE2", ST.THERI_FEATHER_RANGE2, true) -- v1.6
chk("zfeather", "featherFan", {60, 60, 60, 60}); chk("zfeather", "featherDamage", {3, 3, 3, 3})
chk("zfeather", "featherSlowMul", {0.75, 0.75, 0.75, 0.75}); chk("zfeather", "featherSlowTime", {1, 1, 2, 2})
chk("zfeather", "featherCooldown", {14, 14, 14, 14})
chk("zharvest", "fieldRadius", VX and {15, 17, 17, 19} or {6, 8, 8, 10}); chk("zharvest", "fieldTime", {3, 3, 4, 5}); chk("zharvest", "fieldBleed", {4, 4, 4, 4})
chk("zharvest", "fieldSlowMul", {0.7, 0.7, 0.7, 0.7}); chk("zharvest", "fieldCooldown", {20, 20, 20, 20})
chk("zsnare", "snareMax", {1, 2, 2, 3}); chk("zsnare", "snareDamage", {12, 12, 12, 12}); chk("zsnare", "snareRoot", {1, 1, 2, 2})
chk("zsnare", "snareRadius", {4, 4, 4, 4}); chk("zsnare", "snareCooldown", BO and {14, 14, 14, 14} or {18, 18, 18, 18})
chk("zsnare", "snareRange", BR and {60, 60, 80, 80} or (BO and {35, 35, 45, 45} or {0, 0, 0, 0})) -- v1.4; v1.7 60 / 80
-- v1.1: build-2 effects per step
chk("zgrapple", "grappleRange", DA and {30, 40, 50, 50} or {90, 110, 130, 130}); chk("zgrapple", "grappleCharges", DA and {2, 2, 2, 3} or {1, 1, 1, 2}) -- v1.2: range (SkillTree 1.63)
chk("zgrapple", "grappleCooldown", DA and {6, 6, 5, 5} or {12, 12, 10, 10})
chk("zdeflect", "deflectTime", {1, 1.5, 2, 2}); chk("zdeflect", "deflectAngle", {70, 70, 70, 70})
chk("zdeflect", "deflectLevel", {1, 2, 2, 2}); chk("zdeflect", "deflectReflect", {false, false, false, true})
chk("zdeflect", "deflectCooldown", {16, 16, 13, 13})
chk("zclock", "clockTime", {3, 4, 5, 5}); chk("zclock", "clockRunMul", {1.4, 1.4, 1.4, 1.4})
chk("zclock", "clockTapMul", {1, 0.7, 0.7, 0.7}); chk("zclock", "clockNoSlow", {false, false, false, true})
chk("zclock", "clockCooldown", {22, 22, 18, 18})
eq("THERI_CLOCK_JUMP", ST.THERI_CLOCK_JUMP, true) -- v1.5
chk("zclock", "clockJump", ST.THERI_CLOCK_JUMP and {0, 0, 1, 1} or {0, 0, 0, 0}) -- v1.5
local TEXT2 = {
	zgrapple = DA and {"Button: jolt 30 studs the way you're moving (standing still: forward). 2 charges, each back in 6 s",
		"Dashes 40 studs", "Dashes 50 studs; charges back in 5 s", "3 charges"} or {"Button: hold to lock onto the furthest tree or rock ahead (up to 90 studs), let go to zip there. Nothing ahead: it latches in the air. Recharges in 12 s",
		"Reaches 110 studs", "Reaches 130 studs; recharges in 10 s", "2 charges"}, -- v1.2; v1.3 step 1
	zdeflect = {"Button: claws spin in front for 1 s and block darts. Recharges in 16 s", "Spin 1.5 s; blocks boulders and cannon shots too",
		"Spin 2 s; recharges in 13 s", "Blocked shots bounce back at the shooter"},
	zclock = {"Always on while slotted (no button): run 40% faster", "Cut taps come 30% faster too",
		ST.THERI_CLOCK_JUMP and "One extra jump charge" or "Nothing extra yet (it's always on now)", "Slows don't work on you"}, -- v1.2; v1.5 step 3
}
for id, t in pairs(TEXT2) do
	if P[id] then for i = 1, 4 do eq(id .. " text " .. i, P[id].steps[i], t[i]) end end
end
-- buying / slotting
eq("canBuy hook theri", (ST.canBuy({}, "zhook", 5, "Therizino")), true)
eq("canBuy hook raptor", select(2, ST.canBuy({}, "zhook", 5, "Raptor")), "otherDino")
eq("canBuy grapple live", (ST.canBuy({}, "zgrapple", 5, "Therizino")), true) -- v1.1
eq("canBuy clock live", (ST.canBuy({}, "zclock", 5, "Therizino")), true)
local lo2 = ST.sanitizeLoadout({"zgrapple", "zdeflect", "zclock", "zhook"}, {zgrapple = 1, zdeflect = 1, zclock = 1, zhook = 1}, "Therizino")
eq("slot grapple", lo2[1], "zgrapple"); eq("slot deflect", lo2[2], "zdeflect"); eq("slot clock", lo2[3], "zclock")
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
