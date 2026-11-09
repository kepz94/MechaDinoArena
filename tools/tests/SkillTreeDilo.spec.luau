-- SkillTreeDilo.spec v1.2 (Mecha Dino Arena) — the Dilophosaurus' six own stat rows in ServerStorage.DinoArcade.SkillTree 1.60
-- (MDA-235, plan docs/plans/DILO_STATS_v1.0.md Task 1; Kepu 2026-11-04 picks 2 Venom Bite, 3 Quick Draw, 5 Long Spit, 9 Toxic
-- Blood, 14 Venom Feast, 20 Cold Blood; shared lines "Only its own"). Run in Studio Edit (copy in
-- ServerStorage.DinoArcadeTools.SkillTreeDilo_spec, clone + require); returns "PASS n" or "FAIL ...".
-- v1.1 (SkillTree 1.73 balance pass 1, MDA-360): while ST.BALANCE_PASS1 Quick Draw keeps its ratio over DiloModelData 1.4
--   (hold 0.25, dart 0.75 s): drawHold 0.22 / 0.19 / 0.19 / 0.16, drawCooldown 0.63 / 0.5, texts to match.
-- v1.2 (SkillTree 1.75 DILO_SPIT_ONLY, MDA-360): while ST.DILO_SPIT_ONLY Quick Draw texts are the spit gap (spitGap 0.26 / 0.19 /
--   0.14 / 0.14, each rank >= 1.35x faster than the one before, the base 0.35) and Venom Bite is shown as "Venom Spit" with
--   spit-poison texts (spitVenomAddDps 2 / 2 / 5 / 5, spitVenomAddTime 0 / 1.5 / 0 / 1.5 over the dart's 4/s for 3 s; every
--   changed number >= 1.35x); the new fields are off (0) unbought and on every other dino; drawHold / drawCooldown /
--   venomBiteDps / venomBiteTime keep their 1.1 values.
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
local function E(steps) return ST.effects(steps, "Dilo") end

eq("DILO_STATS", ST.DILO_STATS, true)
local ROWS = {venomfeast = {"Venom Feast", "health"}, venombite = {ST.DILO_SPIT_ONLY and "Venom Spit" or "Venom Bite", "attack"}, longspit = {"Long Spit", "attack"},
	toxicblood = {"Toxic Blood", "defense"}, quickdraw = {"Quick Draw", "speed"}, coldblood = {"Cold Blood", "sig"}}
for id, want in pairs(ROWS) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, want[1])
		eq(id .. " area", P[id].area, want[2])
		eq(id .. " not a part", P[id].mech, false)
		eq(id .. " not soon", P[id].soon, false)
		eq(id .. " steps", #P[id].steps, 4)
		eq(id .. " owner", ST.OWNER[id], "Dilo")
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		eq(id .. " no slot", ST.BUTTONS[id] == nil, true)
		for _, d in ipairs({"TRex", "Raptor", "Herrera", "Teno", "Therizino", "Pachy"}) do eq(id .. " hidden " .. d, ST.seesPath(P[id], d), false) end
		eq(id .. " dilo sees", ST.seesPath(P[id], "Dilo"), true)
	end
end
local TEXT = {
	venomfeast = {"Heal 20% of the poison damage you deal", "Heal 30% of your poison damage", "Heal 40% of your poison damage",
		"Heal 50% of your poison damage"},
	venombite = ST.DILO_SPIT_ONLY and {"Spit poison 6/s (was 4)", "Spit poison lasts 4.5 s (was 3)", "Spit poison 9/s for 3 s", -- v1.2
		"Spit poison 9/s for 4.5 s"}
		or {"Bites poison 1/s for 2 s", "Bite poison lasts 3 s", "Bite poison 2/s for 2 s", "Bites poison 2/s for 3 s"},
	longspit = {"Dart range 60 -> 70 studs", "Dart range 80 studs", "Darts fly 40% faster", "Dart range 90 studs"},
	toxicblood = {"A dino that hits you up close is poisoned 1/s for 2 s", "Its poison lasts 3 s", "Its poison 2/s for 2 s",
		"Its poison 2/s for 3 s"},
	quickdraw = ST.DILO_SPIT_ONLY and {"Spit every 0.26 s (was 0.35)", "Spit every 0.19 s", "Spit every 0.14 s", -- v1.2
		"Spit every 0.14 s, the fastest spit"}
		or ST.BALANCE_PASS1 and {"Spit ready after a 0.22 s hold (was 0.25)", "Spit ready after a 0.19 s hold", -- v1.1
		"Dart recharges in 0.63 s (was 0.75)", "0.16 s hold, and the dart recharges in 0.5 s"}
		or {"Spit ready after a 0.35 s hold (was 0.4)", "Spit ready after a 0.3 s hold", "Dart recharges in 1.25 s (was 1.5)",
		"0.25 s hold, and the dart recharges in 1.0 s"},
	coldblood = {"Below 30% health: darts deal 25% more damage", "Below 30% health: darts and poison deal 50% more",
		"Below 30% health: darts and poison deal 75% more",
		"Below 30% health: double damage, and once per life the dart recharges the moment you drop below 30%"},
}
for id, t in pairs(TEXT) do
	if P[id] then for i = 1, 4 do eq(id .. " text " .. i, P[id].steps[i], t[i]) end end
end
-- the dilo's whole STATS list (was regen, lifesteal, jaws, hide, legs)
local function list(d)
	local seen = {}
	for _, a in ipairs(ST.AREAS) do
		for _, p in ipairs(ST.pathsFor(a.id, d)) do if not p.mech then table.insert(seen, p.id) end end
	end
	return table.concat(seen, ",")
end
eq("dilo stat rows", list("Dilo"), "venomfeast,venombite,longspit,toxicblood,quickdraw,coldblood")
for _, id in ipairs({"regen", "lifesteal", "jaws", "hide", "legs"}) do eq(id .. " hidden dilo", ST.seesPath(P[id], "Dilo"), false) end
-- the others unchanged
eq("raptor rows", list("Raptor"), "regen,lifesteal,blade,hide,legs")
eq("herrera rows", list("Herrera"), "lifesteal,jaws,frenzy,hide,plating,legs,stalker")
eq("trex rows", list("TRex"), "lifesteal,jaws,hide,legs")
eq("pachy rows", list("Pachy"), "laststand,dome,crest,headdown,legs")
eq("theri rows", list("Therizino"), "harvest,fury,guard,flow,fourth")
eq("teno rows", list("Teno"), "survivor,heavytail,frontclaws,hide,brace,chargeup,buckoff")
-- effects: off values (no steps, other dinos)
local OFF = {venomBiteDps = 0, venomBiteTime = 0, spitRangeMul = 1, spitSpeedMul = 1, toxicDps = 0, toxicTime = 0, feastFrac = 0,
	drawHold = 0, drawCooldown = 0, coldMul = 1, coldBelow = 0, coldVenom = false, coldReset = false}
local ALL = {venomfeast = 4, venombite = 4, longspit = 4, toxicblood = 4, quickdraw = 4, coldblood = 4}
local z = E({})
for k, v in pairs(OFF) do
	eq("off " .. k, z[k], v)
	for _, d in ipairs({"Raptor", "Pachy", "Therizino", "Teno"}) do eq(d .. " off " .. k, ST.effects(ALL, d)[k], v) end
end
-- effects per step
local function chk(id, field, want) for i = 1, 4 do eq(("%s %d %s"):format(id, i, field), E({[id] = i})[field], want[i], 1e-6) end end
chk("venombite", "venomBiteDps", {1, 1, 2, 2}); chk("venombite", "venomBiteTime", {2, 3, 2, 3})
chk("longspit", "spitRangeMul", {7 / 6, 4 / 3, 4 / 3, 1.5}); chk("longspit", "spitSpeedMul", {1, 1, 1.4, 1.4})
chk("toxicblood", "toxicDps", {1, 1, 2, 2}); chk("toxicblood", "toxicTime", {2, 3, 2, 3})
chk("venomfeast", "feastFrac", {0.2, 0.3, 0.4, 0.5})
if ST.BALANCE_PASS1 then -- v1.1
	chk("quickdraw", "drawHold", {0.22, 0.19, 0.19, 0.16}); chk("quickdraw", "drawCooldown", {0, 0, 0.63, 0.5})
else
	chk("quickdraw", "drawHold", {0.35, 0.3, 0.3, 0.25}); chk("quickdraw", "drawCooldown", {0, 0, 1.25, 1.0})
end
chk("coldblood", "coldMul", {1.25, 1.5, 1.75, 2}); chk("coldblood", "coldBelow", {0.3, 0.3, 0.3, 0.3})
chk("coldblood", "coldVenom", {false, true, true, true}); chk("coldblood", "coldReset", {false, false, false, true})
-- v1.2: spit only (Quick Draw = spit gap, Venom Bite = spit poison)
if ST.DILO_SPIT_ONLY then
	chk("quickdraw", "spitGap", {0.26, 0.19, 0.14, 0.14}); chk("venombite", "spitVenomAddDps", {2, 2, 5, 5})
	chk("venombite", "spitVenomAddTime", {0, 1.5, 0, 1.5})
	for _, f in ipairs({"spitGap", "spitVenomAddDps", "spitVenomAddTime"}) do
		eq("off " .. f, z[f], 0)
		for _, d in ipairs({"Raptor", "Pachy", "Therizino", "Teno", "Herrera", "Troodon", "TRex"}) do eq(d .. " off " .. f, ST.effects(ALL, d)[f], 0) end
	end
	local gaps = {0.35, 0.26, 0.19, 0.14}
	for i = 2, 4 do eq(("quickdraw %d >= 35%% faster"):format(i - 1), gaps[i - 1] / gaps[i] >= 1.345, true) end
	local d, tm = {4, 6, 6, 9, 9}, {3, 3, 4.5, 3, 4.5}
	for i = 1, 4 do
		local e = E({venombite = i})
		eq("venom spit " .. i .. " dps", 4 + e.spitVenomAddDps, d[i + 1]); eq("venom spit " .. i .. " time", 3 + e.spitVenomAddTime, tm[i + 1])
	end
	eq("venom spit I dps 1.5x", d[2] / d[1] >= 1.35, true); eq("venom spit II time 1.5x", tm[3] / tm[2] >= 1.35, true)
	eq("venom spit III dps 1.5x", d[4] / d[3] >= 1.35, true); eq("venom spit star time 1.5x", tm[5] / tm[4] >= 1.35, true)
	eq("star = III gap (Kepu 0.14 / 0.14)", E({quickdraw = 4}).spitGap, E({quickdraw = 3}).spitGap)
	eq("spit fields with a full build", E(ALL).spitGap, 0.14)
end
-- the shared lines give a dilo nothing now (saved steps dropped)
local sh = E({regen = 4, lifesteal = 4, jaws = 4, hide = 4, legs = 4})
eq("dilo regen gone", sh.regenRate, 0); eq("dilo lifesteal gone", sh.lifesteal, 0); eq("dilo jaws gone", sh.mainCdMul, 1)
eq("dilo attack pts gone", sh.attackPts, 0)
eq("sanitize drops regen on dilo", ST.sanitize({regen = 2}, "Dilo").regen, 0)
eq("sanitize keeps venombite", ST.sanitize({venombite = 3}, "Dilo").venombite, 3)
eq("sanitize drops venombite on raptor", ST.sanitize({venombite = 3}, "Raptor").venombite, 0)
eq("raptor regen still", ST.sanitize({regen = 2}, "Raptor").regen, 2)
-- build limits
eq("mastery counts dilo rows", ST.masteryOk({venombite = 3, longspit = 3, quickdraw = 3, coldblood = 3}, "Dilo"), false)
eq("mastery 3 ok", ST.masteryOk({venombite = 3, longspit = 3, quickdraw = 3, coldblood = 2}, "Dilo"), true)
eq("spent full build", ST.spent({venombite = 4, longspit = 4, quickdraw = 4}, "Dilo"), 30)
eq("buy ok", (ST.buy({}, "venombite", 5, "Dilo")) ~= nil, true)
eq("buy other dino", select(2, ST.canBuy({}, "venombite", 5, "Raptor")), "otherDino")

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
