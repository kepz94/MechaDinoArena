-- SkillTreePachy.spec v1.0 (Mecha Dino Arena) — the Pachycephalosaurus' Last Stand (Health) and Head Down (Defense) rows in
-- ServerStorage.DinoArcade.SkillTree 1.59 (MDA-230, plan docs/plans/PACHY_STATS_v1.0.md Task 1; Kepu 2026-11-04 "Option B for
-- health and option A for defense", star "Untouchable at 30%", step III "Shoves only"). Run in Studio Edit (copy in
-- ServerStorage.DinoArcadeTools.SkillTreePachy_spec, loadstring(Source)()); returns "PASS n" or "FAIL ...".
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
local function E(steps) return ST.effects(steps, "Pachy") end

eq("PACHY_STATS", ST.PACHY_STATS, true)
-- the rows
local ROWS = {laststand = {"Last Stand", "health"}, headdown = {"Head Down", "defense"}}
for id, want in pairs(ROWS) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, want[1])
		eq(id .. " area", P[id].area, want[2])
		eq(id .. " not a part", P[id].mech, false)
		eq(id .. " not soon", P[id].soon, false)
		eq(id .. " steps", #P[id].steps, 4)
		eq(id .. " owner", ST.OWNER[id], "Pachy")
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		eq(id .. " no slot", ST.BUTTONS[id] == nil, true)
		for _, d in ipairs({"TRex", "Raptor", "Herrera", "Teno", "Therizino", "Dilo"}) do eq(id .. " hidden " .. d, ST.seesPath(P[id], d), false) end
		eq(id .. " pachy sees", ST.seesPath(P[id], "Pachy"), true)
	end
end
if P.laststand then
	eq("laststand I", P.laststand.steps[1], "Below 30% health: take 15% less damage")
	eq("laststand II", P.laststand.steps[2], "Below 30% health: take 25% less damage")
	eq("laststand III", P.laststand.steps[3], "Below 30% health: headbutt charges refill 40% faster")
	eq("laststand star", P.laststand.steps[4], "Once per life, the first time you drop below 30% health you are untouchable for 1.5 s")
end
if P.headdown then
	eq("headdown I", P.headdown.steps[1], "While charging a headbutt: take 15% less damage")
	eq("headdown II", P.headdown.steps[2], "While charging: take 25% less damage")
	eq("headdown III", P.headdown.steps[3], "While charging: can't be shoved")
	eq("headdown star", P.headdown.steps[4], "While charging: can't be stunned")
end
-- the pachy's whole STATS list (was dome, crest, legs)
local function list(d)
	local seen = {}
	for _, a in ipairs(ST.AREAS) do
		for _, p in ipairs(ST.pathsFor(a.id, d)) do if not p.mech then table.insert(seen, p.id) end end
	end
	return table.concat(seen, ",")
end
eq("pachy stat rows", list("Pachy"), "laststand,dome,crest,headdown,legs")
-- the others unchanged
eq("raptor rows", list("Raptor"), "regen,lifesteal,blade,hide,legs")
eq("herrera rows", list("Herrera"), "lifesteal,jaws,frenzy,hide,plating,legs,stalker")
eq("trex rows", list("TRex"), "lifesteal,jaws,hide,legs")
eq("dilo rows", list("Dilo"), "regen,lifesteal,jaws,hide,legs")
eq("theri rows", list("Therizino"), "harvest,fury,guard,flow,fourth")
eq("teno rows", list("Teno"), "survivor,heavytail,frontclaws,hide,brace,chargeup,buckoff")
-- still blocked for the pachy (Kepu 2026-10-30)
for _, id in ipairs({"regen", "lifesteal", "jaws", "hide"}) do eq(id .. " hidden pachy", ST.seesPath(P[id], "Pachy"), false) end
-- effects: off values (no steps, other dinos)
local OFF = {lastStandMul = 1, lastStandBelow = 0, lastStandRefillMul = 1, lastStandStar = false, lastStandTime = 0,
	headDownMul = 1, headDownNoShove = false, headDownNoStun = false}
local z = E({})
for k, v in pairs(OFF) do
	eq("off " .. k, z[k], v)
	eq("raptor off " .. k, ST.effects({laststand = 4, headdown = 4}, "Raptor")[k], v)
	eq("teno off " .. k, ST.effects({laststand = 4, headdown = 4}, "Teno")[k], v)
	eq("dilo off " .. k, ST.effects({laststand = 4, headdown = 4}, "Dilo")[k], v)
end
-- effects per step
eq("ls I mul", E({laststand = 1}).lastStandMul, 0.85); eq("ls I below", E({laststand = 1}).lastStandBelow, 0.3)
eq("ls I refill off", E({laststand = 1}).lastStandRefillMul, 1)
eq("ls II mul", E({laststand = 2}).lastStandMul, 0.75); eq("ls II refill off", E({laststand = 2}).lastStandRefillMul, 1)
eq("ls III refill", E({laststand = 3}).lastStandRefillMul, 0.714); eq("ls III mul", E({laststand = 3}).lastStandMul, 0.75)
eq("ls III star off", E({laststand = 3}).lastStandStar, false); eq("ls III time off", E({laststand = 3}).lastStandTime, 0)
eq("ls star", E({laststand = 4}).lastStandStar, true); eq("ls star time", E({laststand = 4}).lastStandTime, 1.5)
eq("ls star refill", E({laststand = 4}).lastStandRefillMul, 0.714)
eq("hd I mul", E({headdown = 1}).headDownMul, 0.85); eq("hd I shove off", E({headdown = 1}).headDownNoShove, false)
eq("hd II mul", E({headdown = 2}).headDownMul, 0.75); eq("hd II shove off", E({headdown = 2}).headDownNoShove, false)
eq("hd III shove", E({headdown = 3}).headDownNoShove, true); eq("hd III stun off", E({headdown = 3}).headDownNoStun, false)
eq("hd star stun", E({headdown = 4}).headDownNoStun, true); eq("hd star mul", E({headdown = 4}).headDownMul, 0.75)
-- sanitize / mastery
eq("sanitize keeps laststand", ST.sanitize({laststand = 2}, "Pachy").laststand, 2)
eq("sanitize keeps headdown", ST.sanitize({headdown = 3}, "Pachy").headdown, 3)
eq("sanitize drops on raptor", ST.sanitize({laststand = 2}, "Raptor").laststand, 0)
eq("sanitize still drops regen", ST.sanitize({regen = 2}, "Pachy").regen, 0)
eq("mastery counts pachy rows", ST.masteryOk({laststand = 3, headdown = 3, dome = 3, crest = 3}, "Pachy"), false)
eq("mastery 3 ok", ST.masteryOk({laststand = 3, headdown = 3, dome = 3, crest = 2}, "Pachy"), true)
eq("spent full build", ST.spent({laststand = 4, headdown = 4, dome = 4, crest = 2, legs = 2}, "Pachy"), 36)
-- pachy effects that were there before still the same (spot checks)
eq("dome I still 1.25", E({dome = 1}).hbDamageMul, 1.25)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
