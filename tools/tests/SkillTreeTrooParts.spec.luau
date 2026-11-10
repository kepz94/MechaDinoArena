-- SkillTreeTrooParts.spec v1.6 (1.6: SkillTree 1.87 TROO_SOON_REMOVED takes the 4 soon parts out of the troodon's rows; 1.5: the 5 slot parts of SkillTree 1.85 join the troodon rows; 1.4: MDA-377 Arc Lantern 12 per zap + stun text; 1.3: MDA-375 Portal Rift 185 / 250 studs, 22 / 30 s, 61 / 45 s; 1.2: MDA-373 Sap Wall 74 / 100 wide, 4.2 / 5.8 / 8 s, 30 tall; 1.1: MDA-365 Portal 14 s; Mecha Dino Arena) — the Troodon's 9 mecha parts in ServerStorage.DinoArcade.SkillTree 1.72
-- (plan docs/plans/TROODON_PARTS_v1.0.md ticket 2, MDA-346). Run in Studio Edit (paste into execute_luau, or a copy in
-- ServerStorage.DinoArcadeTools.SkillTreeTrooParts_spec, clone + require); returns "PASS n" or "FAIL ...".
-- Build 1 (Kepu 2026-11-06 "two builds"): omender / olantern / osapwall / oshed / oportal live; olastfeather / oplume /
-- ofortify / oricochet listed but "soon" (TROO_PARTS_B2_SOON).
-- The no-overwrite check (the 1.61 hookRange lesson): a second clone with "SkillTree.TROO_PARTS = true" switched to false is
-- required too, and every dino's effects table (minus the new o* fields) must be identical between the two, for each dino key
-- AND for dino nil (SkillEffects reads the raptor / T-Rex / troodon that way).
local function load(off)
	local src = game.ServerStorage.DinoArcade.SkillTree
	local c = src:Clone()
	if off then
		local s = c.Source
		local a, b = s:find("SkillTree.TROO_PARTS = true", 1, true)
		if not a then error("TROO_PARTS line not found") end
		c.Source = s:sub(1, a - 1) .. "SkillTree.TROO_PARTS = false" .. s:sub(b + 1)
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
local function E(steps) return ST.effects(steps, "Troodon") end

eq("TROO_PARTS", ST.TROO_PARTS, true)
eq("TROO_PARTS_B2_SOON", ST.TROO_PARTS_B2_SOON, true)
eq("off clone has no omender", OFF.PATHS.omender == nil, true)
local ROWS = { -- name, area, soon (build 1)
	omender = {"Mender Drone", "health", false}, olantern = {"Arc Lantern", "attack", false},
	osapwall = {"Sap Wall", "defense", false}, oshed = {"Feather Shed", "defense", false},
	oportal = {"Portal Feathers", "speed", false},
	olastfeather = {"Last Feather", "health", true}, oplume = {"Overheal Plume", "health", true},
	ofortify = {"Fortify Field", "defense", true}, oricochet = {"Ricochet Pod", "attack", true},
}
for id, want in pairs(ROWS) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, want[1])
		eq(id .. " area", P[id].area, want[2])
		eq(id .. " is a part", P[id].mech, true)
		eq(id .. " soon", P[id].soon == true, want[3])
		eq(id .. " live", ST.LIVE_MECH[id] == true, not want[3])
		eq(id .. " button (takes a slot)", ST.BUTTONS[id], true)
		eq(id .. " steps", #P[id].steps, 4)
		eq(id .. " owner", ST.OWNER[id], "Troodon")
		eq(id .. " dino", P[id].dino, "Troodon")
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		for _, d in ipairs({"TRex", "Raptor", "Herrera", "Teno", "Pachy", "Therizino", "Dilo"}) do
			eq(id .. " hidden " .. d, ST.seesPath(P[id], d), false)
		end
		eq(id .. " troodon sees", ST.seesPath(P[id], "Troodon"), true)
	end
end
-- the troodon's skill screen: its areas list exactly these parts as its own mecha rows
local trooMech = {}
for _, a in ipairs(ST.AREAS) do
	for _, p in ipairs(ST.pathsFor(a.id, "Troodon")) do if p.mech and p.dino == "Troodon" then table.insert(trooMech, p.id) end end
end
table.sort(trooMech)
local soonOut = ST.TROO_SOON_REMOVED and not ST.TROO_PARTS_B2_LIVE -- v1.6
local wantRows = ST.TROO_SLOT_PARTS and "obloom,oburst,odome,ofortify,olantern,olastfeather,omender,oplume,oportal,oricochet,osapwall,osentry,oshed,osleep" or "ofortify,olantern,olastfeather,omender,oplume,oportal,oricochet,osapwall,oshed"
if soonOut then
	local keep = {}
	for id in wantRows:gmatch("[^,]+") do if not table.find(ST.TROO_SOON_IDS, id) then table.insert(keep, id) end end
	wantRows = table.concat(keep, ",")
end
eq("troodon mech rows", table.concat(trooMech, ","), wantRows) -- v1.5 / v1.6
if soonOut then -- v1.6: the 4 are in no area, still in PATHS / PATH_ORDER as soon
	for _, id in ipairs(ST.TROO_SOON_IDS) do
		local inArea = false
		for _, a in ipairs(ST.AREAS) do for _, p in ipairs(a.paths) do if p.id == id then inArea = true end end end
		eq(id .. " out of every area", inArea, false)
	end
	eq("T-Rex soon part stays", (function() for _, a in ipairs(ST.AREAS) do for _, p in ipairs(a.paths) do if p.id == "repairdrone" then return true end end end return false end)(), true)
end
-- no other dino lists any o part
for _, d in ipairs({"TRex", "Raptor", "Herrera", "Teno", "Pachy", "Therizino", "Dilo"}) do
	local n = 0
	for _, a in ipairs(ST.AREAS) do
		for _, p in ipairs(ST.pathsFor(a.id, d)) do if ROWS[p.id] then n += 1 end end
	end
	eq(d .. " lists no troodon part", n, 0)
end
local TEXT = {
	omender = {"Button: the drone heals the most hurt squadmate within 40 studs (you, with no squad) 4 per second for 4 s. Recharges in 20 s",
		"Heals for 5.4 s", "Recharges in 14.8 s", "When its target is full it moves on to the next most hurt squadmate"},
	olantern = {"Button: throw a lantern up to " .. (ST.SHOT_PASS and "80" or "40") .. " studs; it zaps the nearest enemy near it, then chains to 1 more within 24 studs: " .. (ST.TROO_LANTERN_PASS and "12 damage each and stunned 1 s" or "8 damage each") .. ". Recharges in 14 s", -- v1.4: MDA-377 (+ the 1.74 shot-pass range)
		"Chains reach 32.4 studs", "Recharges in 10.3 s", "Chains to 3 enemies"},
	osapwall = ST.TROO_SAP_PASS and {"Button: throw a sap pod up to " .. (ST.SHOT_PASS and "80" or "40") .. " studs: it hardens into a wall 74 studs wide and 30 tall that blocks dinos and shots for 4.2 s. Recharges in 18 s",
		"Wall 100 studs wide", "Lasts 5.8 s", "Lasts 8 s"} or {"Button: throw a sap pod up to 40 studs: it hardens into a 50-stud wall that blocks dinos and shots for 2.1 s. Recharges in 18 s",
		"Wall 67.5 studs wide", "Lasts 2.9 s", "Lasts 4 s"}, -- v1.2: MDA-373
	oshed = {"Button: shed your feathers to break out of a stun, pin or grab; immune to them for 1 s. Recharges in 24 s",
		"Immune 1.4 s", "Recharges in 17.7 s", "The burst knocks dinos within 20 studs back and slows them 25% for 2 s"},
	oportal = ST.TROO_RIFT_PASS and ST.RIFT_TEXTS or {"Button: fling two linked feather rings, one just ahead and one up to 40 studs away; walk into one, come out of the other. They last 6 s, you only. Recharges in " .. (ST.MOVE_CD_PASS and "14" or "20") .. " s",
		"The far ring reaches 54 studs", "They last 8.1 s", "Squadmates can use them too"}, -- v1.3: the rift texts when TROO_RIFT_PASS
	olastfeather = {"Always on (takes a slot): once per life a killing hit leaves you at 1 HP, untouchable for 0.7 s",
		"You also burst up into a glide (a free flap)", "Untouchable 1 s", "You drop a glow zone (40 studs) where you were"},
	oplume = {"Always on (takes a slot): healing above your max becomes a plume that soaks up to 10 damage; it fades after 5 s",
		"Soaks up to 14", "Fades after 7 s", "Squadmates you heal above their max get a plume too"},
	ofortify = {"Always on (takes a slot): squadmates inside your glow zones (40 studs) take 25% less damage",
		"It lingers 1 s after they leave", "Lingers 1.4 s", "You're fortified too inside your own zones"},
	oricochet = {"Always on (takes a slot): the pod bounces once and splats a second, half-size zone (20 studs) on the next enemy within 30 studs; it lasts 2.2 s",
		"Bounce reach 40 studs", "The second zone lasts the full 3 s", "The second zone is full size (40 studs)"},
}
for id, t in pairs(TEXT) do
	if P[id] then for i = 1, 4 do eq(id .. " text " .. i, P[id].steps[i], t[i]) end end
end
-- effects ladders (steps 1..4) read as the troodon; off values at 0 steps
local OFFV = {oShedSlowMul = 1}
local function chk(id, field, want)
	for n = 1, 4 do eq(id .. " " .. field .. " @" .. n, E({[id] = n})[field], want[n]) end
	local off = OFFV[field] or 0
	if type(want[1]) == "boolean" then off = false end
	eq(id .. " " .. field .. " @0", E({})[field], off)
end
chk("omender", "oMenderHeal", {4, 4, 4, 4}); chk("omender", "oMenderTime", {4, 5.4, 5.4, 5.4})
chk("omender", "oMenderRange", {40, 40, 40, 40}); chk("omender", "oMenderHop", {false, false, false, true})
chk("omender", "oMenderCooldown", {20, 20, 14.8, 14.8})
chk("olantern", "oLanternRange", {40, 40, 40, 40}); chk("olantern", "oLanternChain", {24, 32.4, 32.4, 32.4})
chk("olantern", "oLanternTargets", {2, 2, 2, 3}); chk("olantern", "oLanternDamage", ST.TROO_LANTERN_PASS and {12, 12, 12, 12} or {8, 8, 8, 8}) -- v1.4: MDA-377
if ST.TROO_LANTERN_PASS then eq("lantern text misses", ST.LANTERN_TEXT_MISSES, 0); eq("lantern damage x1.5", E({olantern = 1}).oLanternDamage, 8 * 1.5) end
chk("olantern", "oLanternCooldown", {14, 14, 10.3, 10.3})
chk("osapwall", "oSapRange", {40, 40, 40, 40}); chk("osapwall", "oSapWidth", ST.TROO_SAP_PASS and {74, 100, 100, 100} or {50, 67.5, 67.5, 67.5}) -- v1.2: MDA-373
chk("osapwall", "oSapTime", ST.TROO_SAP_PASS and {4.2, 4.2, 5.8, 8} or {2.1, 2.1, 2.9, 4}); chk("osapwall", "oSapCooldown", {18, 18, 18, 18})
if ST.TROO_SAP_PASS then chk("osapwall", "oSapHeight", {30, 30, 30, 30}); eq("sap text misses", ST.SAP_TEXT_MISSES, 0) end -- v1.2
chk("oshed", "oShedImmune", {1, 1.4, 1.4, 1.4}); chk("oshed", "oShedCooldown", {24, 24, 17.7, 17.7})
chk("oshed", "oShedKnockRadius", {0, 0, 0, 20}); chk("oshed", "oShedSlowMul", {1, 1, 1, 0.75})
chk("oshed", "oShedSlowTime", {0, 0, 0, 2})
chk("oportal", "oPortalRange", {40, 54, 54, 54}); chk("oportal", "oPortalTime", {6, 6, 8.1, 8.1})
if ST.TROO_RIFT_PASS then -- v1.3: MDA-375
	chk("oportal", "oRiftLength", {185, 250, 250, 250}); chk("oportal", "oRiftTime", {22, 22, 30, 30}); chk("oportal", "oRiftCooldown", {61, 61, 61, 45})
	eq("rift steps >= 1.35x", 250 >= 185 * 1.35 and 30 >= 22 * 1.35 and 61 >= 45 * 1.35, true); eq("rift text misses", ST.RIFT_TEXT_MISSES, 0)
end
chk("oportal", "oPortalSquad", {false, false, false, true}); chk("oportal", "oPortalCooldown", ST.MOVE_CD_PASS and {14, 14, 14, 14} or {20, 20, 20, 20}) -- v1.1: MDA-365
-- the 35% rule on every upgrading step (time / reach / count up, recharge down)
local function up(name, a, b) eq(name .. " >= 1.35x", b >= a * 1.35 - 1e-9, true) end
up("mender time II", 4, E({omender = 2}).oMenderTime); up("mender cooldown III", E({omender = 3}).oMenderCooldown, 20)
up("lantern chain II", 24, E({olantern = 2}).oLanternChain); up("lantern cooldown III", E({olantern = 3}).oLanternCooldown, 14)
up("lantern targets star", 2, E({olantern = 4}).oLanternTargets)
up("sap width II", E({osapwall = 1}).oSapWidth, E({osapwall = 2}).oSapWidth); up("sap time III", E({osapwall = 2}).oSapTime, E({osapwall = 3}).oSapTime) -- v1.2: from the rank below
up("sap time star", E({osapwall = 3}).oSapTime, E({osapwall = 4}).oSapTime)
up("shed immune II", 1, E({oshed = 2}).oShedImmune); up("shed cooldown III", E({oshed = 3}).oShedCooldown, 24)
up("portal range II", 40, E({oportal = 2}).oPortalRange); up("portal time III", 6, E({oportal = 3}).oPortalTime)
-- soon parts are dropped by sanitize, so build-2 parts give nothing yet and cannot be bought / slotted
eq("canBuy lastfeather soon", select(2, ST.canBuy({}, "olastfeather", 5, "Troodon")), "soon")
eq("lastfeather sanitized off", ST.sanitize({olastfeather = 2}, "Troodon").olastfeather or 0, 0)
-- other dinos (and dino nil, how SkillEffects reads the troodon) read the off values
eq("raptor omender off", ST.effects({omender = 4}, "Raptor").oMenderHeal, 0)
eq("dilo osapwall off", ST.effects({osapwall = 4}, "Dilo").oSapWidth, 0)
eq("nil-dino oportal off", ST.effects({oportal = 4}).oPortalRange, 0)
-- every dino's own fields are untouched by TROO_PARTS (only new o* fields appear)
local SAMPLES = {
	Pachy = {{}, {hookarm = 4, mechalegs = 4, servodash = 4, visor = 4, ink = 4, tether = 4, medstation = 4, dome = 4, crest = 4, bloodrush = 4, laststand = 4, headdown = 4}, {hookarm = 1, ink = 2, omender = 4}},
	Therizino = {{}, {zhook = 4, zfeather = 4, zharvest = 4, zgrapple = 4, zdeflect = 4, zclock = 4, zsnare = 4, harvest = 4, fury = 4}, {zhook = 2, osapwall = 4}},
	Teno = {{}, {tmortar = 4, tstomp = 4, tbellow = 4, tchallenge = 4, tleap = 4, tgrab = 4, tmud = 4, buckoff = 4}, {tmortar = 1, oportal = 4}},
	Herrera = {{}, {quills = 4, smoke = 4, goo = 4, glider = 4, frenzy = 4, stalker = 4}, {goo = 2, olantern = 4}},
	Raptor = {{}, {thrusters = 4, cloak = 4, blade = 4, shield = 4, scent = 4, screech = 4, regen = 4, jaws = 4}},
	Dilo = {{}, {dgatling = 4, dmortar = 4, dhiss = 4, dspine = 4, dpump = 4, djets = 4, dover = 4, venombite = 4, longspit = 4}, {dgatling = 2, oshed = 4}},
	TRex = {{}, {regen = 4, jaws = 4, hide = 4, legs = 4, thrusters = 4}},
	Troodon = {{}, {regen = 4, jaws = 4, hide = 4, legs = 4, mechalegs = 4}, {omender = 4, olantern = 4, osapwall = 4, oshed = 4, oportal = 4}},
	[""] = {{}, {regen = 4, jaws = 4, thrusters = 4, cloak = 4}, {omender = 4, olantern = 4, osapwall = 4, oshed = 4, oportal = 4, regen = 2}},
}
for dino, list in pairs(SAMPLES) do
	local key = dino ~= "" and dino or nil
	for i, steps in ipairs(list) do
		local a, b = ST.effects(steps, key), OFF.effects(steps, key)
		local diff = {}
		for k, v in pairs(b) do if a[k] ~= v then table.insert(diff, k) end end
		for k in pairs(a) do if b[k] == nil and not k:match("^o[A-Z]") then table.insert(diff, k .. "(new)") end end
		eq((key or "nil") .. " sample " .. i .. " unchanged", #diff == 0 and "same" or table.concat(diff, ","), "same")
	end
end
eq("pachy hook effect same as off clone", ST.effects({hookarm = 4}, "Pachy").hookRange, OFF.effects({hookarm = 4}, "Pachy").hookRange)
-- the step texts of every other path are unchanged too
local textDiff = {}
for id, p in pairs(OFF.PATHS) do
	local q = P[id]
	if not q then table.insert(textDiff, id .. "(gone)") else
		for i = 1, #p.steps do if p.steps[i] ~= q.steps[i] then table.insert(textDiff, id .. i) end end
		if (p.soon == true) ~= (q.soon == true) then table.insert(textDiff, id .. "(soon)") end
	end
end
eq("other paths unchanged", #textDiff == 0 and "same" or table.concat(textDiff, ","), "same")
eq("path count +9", #ST.PATH_ORDER, #OFF.PATH_ORDER + (ST.TROO_SLOT_PARTS and 14 or 9)) -- v1.5: + the 5 slot parts
-- buying / slotting
eq("canBuy mender troodon", (ST.canBuy({}, "omender", 5, "Troodon")), true)
eq("canBuy mender raptor", select(2, ST.canBuy({}, "omender", 5, "Raptor")), "otherDino")
eq("canBuy portal dilo", select(2, ST.canBuy({}, "oportal", 5, "Dilo")), "otherDino")
local lo = ST.sanitizeLoadout({"omender", "olantern", "osapwall", "oshed"}, {omender = 1, olantern = 1, osapwall = 1, oshed = 1}, "Troodon")
eq("slot 1", lo[1], "omender"); eq("slot 2", lo[2], "olantern"); eq("slot 3", lo[3], "osapwall"); eq("slot 4", lo[4], "oshed")
local lo2 = ST.sanitizeLoadout({"oportal", "olastfeather"}, {oportal = 1, olastfeather = 1}, "Troodon")
eq("portal slots", lo2[1], "oportal"); eq("soon lastfeather not slotted", lo2[2], false)
eq("raptor cannot slot", ST.sanitizeLoadout({"omender"}, {omender = 1}, "Raptor")[1], false)
eq("autoSlot portal", ST.autoSlot({false, false, false, false}, {oportal = 1}, "oportal", "Troodon")[1], "oportal")
if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
