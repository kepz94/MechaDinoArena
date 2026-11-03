-- SkillTreeTenoParts.spec v1.4 (Mecha Dino Arena) — the Tenontosaurus' 7 mecha button parts in
-- ServerStorage.DinoArcade.SkillTree 1.49 (plan docs/plans/TENO_ABILITIES_v1.0.md Task 1, MDA-173). Run in Studio Edit (copy in
-- ServerStorage.DinoArcadeTools.SkillTreeTenoParts_spec, loadstring(Source)()); returns "PASS n" or "FAIL ...".
-- Build 1 (Kepu 2026-11-01 "two builds"): tgrab / tmortar / tstomp / tleap live; tbellow / tchallenge / tmud "soon".
-- v1.1 (SkillTree 1.52, Kepu 2026-11-02: the stomp never knocks a latched raptor off; star: it loses 50 stamina from its
--   current pounce): new step I / star texts, stompLatchDrain 50 at star, stompNoJump always 0.
-- v1.2 (SkillTree 1.53): Boulder Mortar step I = the crosshair + snap text.
-- v1.3 (SkillTree 1.54, build 2: Kepu "Next" 2026-11-02): tbellow / tchallenge / tmud live (SkillTree.TENO_SUPPORT_LIVE):
--   not soon, buyable, slottable, and their effects follow the plan's numbers.
-- v1.4 (SkillTree 1.55, Kepu 2026-11-02 16:43): TENO_LEAP_ON_JUMP (Hydraulic Leap fires through JUMP: new step I text,
--   leapCooldown 6, leapBoostMul I 1.65 / II 2.1, leapPowerMul I 1.2 / II 1.45, leapOnJump) and TENO_SHIELD_ARMOR ("tmud"
--   named "Shield Armor", shield texts). Other leap / mud numbers unchanged.
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
local OTHERS = {"TRex", "Raptor", "Pachy", "Herrera"}

eq("TENO_PARTS", ST.TENO_PARTS, true)
eq("TENO_PARTS_SUPPORT_SOON", ST.TENO_PARTS_SUPPORT_SOON, true)
eq("TENO_STOMP_DRAIN", ST.TENO_STOMP_DRAIN, true) -- v1.1
eq("TENO_MORTAR_AIM", ST.TENO_MORTAR_AIM, true) -- v1.2
eq("TENO_SUPPORT_LIVE", ST.TENO_SUPPORT_LIVE, true) -- v1.3
eq("TENO_LEAP_ON_JUMP", ST.TENO_LEAP_ON_JUMP, true) -- v1.4
eq("TENO_SHIELD_ARMOR", ST.TENO_SHIELD_ARMOR, true) -- v1.4
local ROWS = {
	tgrab = {"Tail Grab & Fling", "attack", false},
	tmortar = {"Boulder Mortar", "attack", false},
	tstomp = {"Stomp Shockwave", "defense", false},
	tbellow = {"Herd Bellow", "health", false}, -- v1.3: live
	tchallenge = {"Challenge Call", "defense", false}, -- v1.3: live
	tleap = {"Hydraulic Leap", "speed", false},
	tmud = {"Shield Armor", "defense", false}, -- v1.3: live; v1.4: Shield Armor
}
for id, want in pairs(ROWS) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, want[1])
		eq(id .. " area", P[id].area, want[2])
		eq(id .. " dino", P[id].dino, "Teno")
		eq(id .. " owner", ST.OWNER[id], "Teno")
		eq(id .. " mech", P[id].mech, true)
		eq(id .. " steps", #P[id].steps, 4)
		eq(id .. " button", ST.BUTTONS[id], true)
		eq(id .. " soon", P[id].soon == true, want[3])
		eq(id .. " live", ST.LIVE_MECH[id] == true, not want[3])
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		local inArea = false
		for _, a in ipairs(ST.AREAS) do
			if a.id == want[2] then for _, p in ipairs(a.paths) do if p.id == id then inArea = true end end end
		end
		eq(id .. " in area", inArea, true)
		eq(id .. " teno sees", ST.seesPath(P[id], "Teno"), true)
		for _, d in ipairs(OTHERS) do eq(id .. " hidden " .. d, ST.seesPath(P[id], d), false) end
	end
end
-- step texts (the plan's ability table)
if P.tgrab then
	eq("grab I", P.tgrab.steps[1], "Button: grab the nearest raptor-size dino within 12 studs with your tail and fling it 30 studs ahead. 8 damage, stunned 1 s when it lands. Recharges in 16 s")
	eq("grab II", P.tgrab.steps[2], "Fling 45 studs")
	eq("grab III", P.tgrab.steps[3], "Grabs bigger dinos too (up to pachy size)")
	eq("grab star", P.tgrab.steps[4], "The flung dino crashes into others where it lands: 8 damage to each")
end
if P.tmortar then
	eq("mortar I", P.tmortar.steps[1], "Button: lob a boulder where your crosshair points (15-60 studs); it snaps onto a dino within 8 studs of that spot. 12 damage in a 10-stud splash, enemies slowed 30% for 2 s. Recharges in 14 s")
	eq("mortar II", P.tmortar.steps[2], "Splash 14 studs")
	eq("mortar III", P.tmortar.steps[3], "Lobs 2 boulders side by side")
	eq("mortar star", P.tmortar.steps[4], "Leaves a rubble patch for 4 s: enemies in it are slowed 30%")
end
if P.tstomp then
	eq("stomp I", P.tstomp.steps[1], "Button: rear up and stomp. A 14-stud shockwave: 6 damage and stuns 0.5 s. Recharges in 15 s")
	eq("stomp II", P.tstomp.steps[2], "Stun 1 s")
	eq("stomp III", P.tstomp.steps[3], "Shockwave 20 studs")
	eq("stomp star", P.tstomp.steps[4], "A raptor latched on you loses 50 stamina from its pounce")
end
if P.tleap then
	eq("leap I", P.tleap.steps[1], "Fires through JUMP: every jump is a hydraulic leap, 40 studs forward. Landing slams the tail: 10 damage in 12 studs (no slam charge used). Recharges in 6 s") -- v1.4
	eq("leap II", P.tleap.steps[2], "Leap 55 studs")
	eq("leap III", P.tleap.steps[3], "Landing stuns 0.5 s")
	eq("leap star", P.tleap.steps[4], "2 leaps (2 charges)")
end
if P.tbellow then
	eq("bellow I", P.tbellow.steps[1], "Button: you and squadmates within 25 studs take 50% less damage and run 50% faster for 4 s. Recharges in 30 s")
	eq("bellow star", P.tbellow.steps[4], "Also clears stuns on everyone it reaches")
end
if P.tchallenge then
	eq("challenge I", P.tchallenge.steps[1], "Button: enemies within 30 studs are marked for 5 s: they deal 40% less damage, and bots go for you. Recharges in 20 s")
	eq("challenge star", P.tchallenge.steps[4], "Marked enemies are also slowed 20%")
end
if P.tmud then
	eq("mud I", P.tmud.steps[1], "Button: a purple energy shield for 8 s blocks your next 3 hits completely, and each blocked hit slows every enemy within 15 studs 40% for 4 s. Latched raptors are knocked off. Recharges in 20 s") -- v1.4
	eq("mud III", P.tmud.steps[3], "Shield lasts 12 s") -- v1.4
	eq("mud star", P.tmud.steps[4], "When the shield ends it bursts 12 studs around: enemies slowed 40% for 4 s") -- v1.4
end

-- buying / slotting
eq("canBuy grab teno", (ST.canBuy({}, "tgrab", 5, "Teno")), true)
eq("canBuy grab raptor", select(2, ST.canBuy({}, "tgrab", 5, "Raptor")), "otherDino")
eq("canBuy bellow live", (ST.canBuy({}, "tbellow", 5, "Teno")), true) -- v1.3
eq("canBuy challenge live", (ST.canBuy({}, "tchallenge", 5, "Teno")), true)
eq("canBuy mud live", (ST.canBuy({}, "tmud", 5, "Teno")), true)
eq("canBuy bellow raptor", select(2, ST.canBuy({}, "tbellow", 5, "Raptor")), "otherDino")
local lo = ST.sanitizeLoadout({"tgrab", "tmortar", "tstomp", "tleap"}, {tgrab = 1, tmortar = 1, tstomp = 1, tleap = 1}, "Teno")
eq("slot 1", lo[1], "tgrab"); eq("slot 2", lo[2], "tmortar"); eq("slot 3", lo[3], "tstomp"); eq("slot 4", lo[4], "tleap")
local lo2 = ST.sanitizeLoadout({"tbellow", "tchallenge", "tmud", "tgrab"}, {tbellow = 1, tchallenge = 1, tmud = 1, tgrab = 1}, "Teno") -- v1.3
eq("slot bellow", lo2[1], "tbellow"); eq("slot challenge", lo2[2], "tchallenge"); eq("slot mud", lo2[3], "tmud")
eq("raptor cannot slot", ST.sanitizeLoadout({"tgrab"}, {tgrab = 1}, "Raptor")[1], false)
-- the teno's button parts list
local btn = {}
for _, a in ipairs(ST.AREAS) do
	for _, p in ipairs(ST.pathsFor(a.id, "Teno")) do
		if p.mech and ST.BUTTONS[p.id] then table.insert(btn, p.id) end
	end
end
table.sort(btn)
eq("teno buttons", table.concat(btn, ","), "tbellow,tchallenge,tgrab,tleap,tmortar,tmud,tstomp")
for _, d in ipairs(OTHERS) do
	local n = 0
	for _, a in ipairs(ST.AREAS) do
		for _, p in ipairs(ST.pathsFor(a.id, d)) do if ROWS[p.id] then n += 1 end end
	end
	eq("none for " .. d, n, 0)
end

-- effects
local function E(s) return ST.effects(s, "Teno") end
local off = E({})
for k, v in pairs({grabRange = 0, grabFling = 0, grabDamage = 0, grabStun = 0, grabBig = false, grabCrash = 0, grabCrashRadius = 0,
	grabCooldown = 0, mortarRange = 0, mortarMiss = 0, mortarCone = 0, mortarDamage = 0, mortarSplash = 0, mortarCount = 0,
	mortarSlowMul = 1, mortarSlowTime = 0, mortarRubble = 0, mortarCooldown = 0, stompRange = 0, stompDamage = 0, stompStun = 0,
	stompNoJump = 0, stompLatchDrain = 0, stompCooldown = 0, leapDist = 0, leapDamage = 0, leapRadius = 0, leapStun = 0, leapCharges = 0,
	leapCooldown = 0, bellowRange = 0, bellowTime = 0, bellowDamageMul = 1, bellowRunMul = 1, bellowClearStun = false,
	bellowCooldown = 0, challengeRange = 0, challengeTime = 0, challengeWeakMul = 1, challengeSlowMul = 1,
	challengeCooldown = 0, mudTime = 0, mudHits = 0, mudSlowRadius = 0, mudSlowMul = 1, mudSlowTime = 0, mudSplash = 0,
	mudCooldown = 0}) do
	eq("off " .. k, off[k], v)
	for _, d in ipairs(OTHERS) do
		eq("off " .. d .. " " .. k, ST.effects({tgrab = 4, tmortar = 4, tstomp = 4, tleap = 4, tbellow = 4, tchallenge = 4, tmud = 4}, d)[k], v)
	end
end
-- grab
eq("grab I range", E({tgrab = 1}).grabRange, 12); eq("grab I fling", E({tgrab = 1}).grabFling, 30)
eq("grab I damage", E({tgrab = 1}).grabDamage, 8); eq("grab I stun", E({tgrab = 1}).grabStun, 1)
eq("grab I small only", E({tgrab = 1}).grabBig, false); eq("grab I no crash", E({tgrab = 1}).grabCrash, 0)
eq("grab I cooldown", E({tgrab = 1}).grabCooldown, 16)
eq("grab II fling", E({tgrab = 2}).grabFling, 45); eq("grab II small only", E({tgrab = 2}).grabBig, false)
eq("grab III big", E({tgrab = 3}).grabBig, true); eq("grab III fling", E({tgrab = 3}).grabFling, 45)
eq("grab star crash", E({tgrab = 4}).grabCrash, 8); eq("grab star crash radius", E({tgrab = 4}).grabCrashRadius, 8)
-- mortar
eq("mortar I range", E({tmortar = 1}).mortarRange, 60); eq("mortar I miss", E({tmortar = 1}).mortarMiss, 45)
eq("mortar I cone", E({tmortar = 1}).mortarCone, 30); eq("mortar I damage", E({tmortar = 1}).mortarDamage, 12)
eq("mortar I splash", E({tmortar = 1}).mortarSplash, 10); eq("mortar I count", E({tmortar = 1}).mortarCount, 1)
eq("mortar I slow", E({tmortar = 1}).mortarSlowMul, 0.7); eq("mortar I slow time", E({tmortar = 1}).mortarSlowTime, 2)
eq("mortar I no rubble", E({tmortar = 1}).mortarRubble, 0); eq("mortar I cooldown", E({tmortar = 1}).mortarCooldown, 14)
eq("mortar II splash", E({tmortar = 2}).mortarSplash, 14); eq("mortar II count", E({tmortar = 2}).mortarCount, 1)
eq("mortar III count", E({tmortar = 3}).mortarCount, 2); eq("mortar III splash", E({tmortar = 3}).mortarSplash, 14)
eq("mortar star rubble", E({tmortar = 4}).mortarRubble, 4)
-- stomp
eq("stomp I range", E({tstomp = 1}).stompRange, 14); eq("stomp I damage", E({tstomp = 1}).stompDamage, 6)
eq("stomp I stun", E({tstomp = 1}).stompStun, 0.5); eq("stomp I no nojump", E({tstomp = 1}).stompNoJump, 0)
eq("stomp I cooldown", E({tstomp = 1}).stompCooldown, 15)
eq("stomp II stun", E({tstomp = 2}).stompStun, 1); eq("stomp II range", E({tstomp = 2}).stompRange, 14)
eq("stomp III range", E({tstomp = 3}).stompRange, 20); eq("stomp star no nojump", E({tstomp = 4}).stompNoJump, 0) -- v1.1
eq("stomp III no drain", E({tstomp = 3}).stompLatchDrain, 0); eq("stomp star drain", E({tstomp = 4}).stompLatchDrain, 50) -- v1.1
-- leap
eq("leap I dist", E({tleap = 1}).leapDist, 40); eq("leap I damage", E({tleap = 1}).leapDamage, 10)
eq("leap I radius", E({tleap = 1}).leapRadius, 12); eq("leap I no stun", E({tleap = 1}).leapStun, 0)
eq("leap I charges", E({tleap = 1}).leapCharges, 1); eq("leap I cooldown", E({tleap = 1}).leapCooldown, 6) -- v1.4: 6 (was 14)
eq("leap none boost", E({}).leapBoostMul, 1); eq("leap none power", E({}).leapPowerMul, 1); eq("leap none onJump", E({}).leapOnJump, false) -- v1.4
eq("leap I boost", E({tleap = 1}).leapBoostMul, 1.65); eq("leap I power", E({tleap = 1}).leapPowerMul, 1.2); eq("leap I onJump", E({tleap = 1}).leapOnJump, true)
eq("leap II boost", E({tleap = 2}).leapBoostMul, 2.1); eq("leap II power", E({tleap = 2}).leapPowerMul, 1.45)
eq("leap raptor no boost", ST.effects({tleap = 4}, "Raptor").leapBoostMul, 1); eq("leap raptor no onJump", ST.effects({tleap = 4}, "Raptor").leapOnJump, false)
eq("leap II dist", E({tleap = 2}).leapDist, 55); eq("leap III stun", E({tleap = 3}).leapStun, 0.5)
eq("leap star charges", E({tleap = 4}).leapCharges, 2)
-- v1.3: build-2 parts live
eq("bellow none", E({}).bellowTime, 0); eq("bellow none mul", E({}).bellowDamageMul, 1)
eq("bellow I range", E({tbellow = 1}).bellowRange, 25); eq("bellow I time", E({tbellow = 1}).bellowTime, 4)
eq("bellow I dmg mul", E({tbellow = 1}).bellowDamageMul, 0.5); eq("bellow I run mul", E({tbellow = 1}).bellowRunMul, 1.5)
eq("bellow I no clear", E({tbellow = 1}).bellowClearStun, false); eq("bellow I cooldown", E({tbellow = 1}).bellowCooldown, 30)
eq("bellow II time", E({tbellow = 2}).bellowTime, 6); eq("bellow II range", E({tbellow = 2}).bellowRange, 25)
eq("bellow III range", E({tbellow = 3}).bellowRange, 40); eq("bellow star clear", E({tbellow = 4}).bellowClearStun, true)
eq("bellow star dmg mul", E({tbellow = 4}).bellowDamageMul, 0.5)
eq("challenge none", E({}).challengeTime, 0); eq("challenge none mul", E({}).challengeWeakMul, 1)
eq("challenge I range", E({tchallenge = 1}).challengeRange, 30); eq("challenge I time", E({tchallenge = 1}).challengeTime, 5)
eq("challenge I weak", E({tchallenge = 1}).challengeWeakMul, 0.6); eq("challenge I no slow", E({tchallenge = 1}).challengeSlowMul, 1)
eq("challenge I cooldown", E({tchallenge = 1}).challengeCooldown, 20)
eq("challenge II time", E({tchallenge = 2}).challengeTime, 7); eq("challenge III range", E({tchallenge = 3}).challengeRange, 45)
eq("challenge star slow", E({tchallenge = 4}).challengeSlowMul, 0.8)
eq("mud none", E({}).mudHits, 0)
eq("mud I time", E({tmud = 1}).mudTime, 8); eq("mud I hits", E({tmud = 1}).mudHits, 3)
eq("mud I slow radius", E({tmud = 1}).mudSlowRadius, 15); eq("mud I slow mul", E({tmud = 1}).mudSlowMul, 0.6)
eq("mud I slow time", E({tmud = 1}).mudSlowTime, 4); eq("mud I no splash", E({tmud = 1}).mudSplash, 0)
eq("mud I cooldown", E({tmud = 1}).mudCooldown, 20)
eq("mud II hits", E({tmud = 2}).mudHits, 4); eq("mud II time", E({tmud = 2}).mudTime, 8)
eq("mud III time", E({tmud = 3}).mudTime, 12); eq("mud star splash", E({tmud = 4}).mudSplash, 12)
eq("bellow raptor none", ST.effects({tbellow = 4}, "Raptor").bellowTime, 0)
-- existing rows unchanged
eq("buck star charge", E({buckoff = 4}).buckCharge, 1)
eq("heavy tail I", E({heavytail = 1}).heavyBonus, 3)
eq("herrera quills", ST.effects({quills = 1}, "Herrera").quillCount, 5)
eq("sanitize drops tgrab on raptor", ST.sanitize({tgrab = 2}, "Raptor").tgrab, 0)
eq("sanitize keeps tgrab on teno", ST.sanitize({tgrab = 2}, "Teno").tgrab, 2)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n", 1, math.min(#fails, 15)) end
return "PASS " .. passes
