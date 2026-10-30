-- SkillTree.spec v1.15 (Mecha Dino Arena) — tests for ServerStorage.DinoArcade.SkillTree (MDA-11, plan
-- docs/plans/SKILLTREES_v1.0.md Task 1). Run in Studio Edit through execute_luau; returns "PASS n" or "FAIL ...".
-- v1.9: requires a fresh clone so a re-run in the same Studio session sees the installed source (require caches)
-- v1.10: Shock Dart (screech shown as "Shock Dart", range 100 / 135; the 35% range check reads the data)
-- v1.11: Shock Cannon (name; stun 1.1 s, 1.5 s at star, 35% check)
-- v1.12: Shock Mine (traps live for Raptor, Grapple hidden; effects, 35% checks)
-- v1.13: Shock Mine blast + launch (damage 25, launch 25, daze 1)
-- v1.14: Shock Cannon star = heavy shot (30 damage, stun 1.1, no jam); Decoy hidden
-- v1.15: Grapple, Dart Launcher, Pack Beacon, Decoy Hologram deleted from the tree
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

eq("Version", ST.Version, "1.15") -- v1.15 (was 1.14)
eq("COST", table.concat(ST.COST, ","), "1,2,3,4")
eq("MAX_POINTS", ST.MAX_POINTS, 40) -- v1.5 (ADR-004)
eq("MAX_LEVEL", ST.MAX_LEVEL, 41)

-- tree shape: 5 areas, 4 steps per path, ids as in the plans (v1.5: per-dino paths appended to their areas)
local ids, areas = {}, {}
for _, a in ipairs(ST.AREAS) do
	table.insert(areas, a.id)
	for _, p in ipairs(a.paths) do
		table.insert(ids, p.id)
		eq("steps in " .. p.id, #p.steps, 4)
		eq("area of " .. p.id, ST.PATHS[p.id] and ST.PATHS[p.id].area, a.id)
	end
end
eq("areas", table.concat(areas, ","), "health,attack,defense,speed,eng")
eq("path ids", table.concat(ids, ","),
	"regen,medstation,lifesteal,adrenaline,repairdrone,biobattery,jaws,turret,rocket,blade,screech,hide,armor,shield,cloak,"
	.. "reactive,legs,thrusters,ramjet,sentry,traps,barricade,shieldproj,roaramp,scent") -- v1.15: - dart, grapple, beacon, decoy; -- v1.9: + screech, scent
local buyable = {}
for _, id in ipairs(ids) do if not ST.PATHS[id].soon then table.insert(buyable, id) end end
eq("buyable", table.concat(buyable, ","), "regen,lifesteal,adrenaline,jaws,blade,screech,hide,shield,cloak,legs,thrusters,traps,scent") -- v1.12: + traps; -- v1.1: + thrusters; v1.5: + cloak (AREAS order); v1.9: + batch 1 (was stale since 1.6) + screech, scent

-- level curve: xpToNext(L) = 30 + 10 (L - 1); points = level - 1, v1.5: cap 40 at level 41
eq("xpToNext 1", ST.xpToNext(1), 30)
eq("xpToNext 2", ST.xpToNext(2), 40)
eq("xpToNext 10", ST.xpToNext(10), 120)
eq("xpToNext 60", ST.xpToNext(60), 620)
local function lv(x) local l, into, nxt = ST.levelOf(x) return ("%d/%d/%d"):format(l, into, nxt) end
eq("levelOf 0", lv(0), "1/0/30")
eq("levelOf 29", lv(29), "1/29/30")
eq("levelOf 30", lv(30), "2/0/40")
eq("levelOf 75", lv(75), "3/5/50") -- 30 + 40 = 70 -> level 3, 5 into 50
eq("levelOf 630", lv(630), "10/0/120") -- sum of 30..110 (9 levels) = 630
eq("levelOf cap", lv(9000), "41/0/0") -- v1.5: sum of 30..420 (40 levels) = 9000
eq("levelOf below cap", lv(8999), "40/419/420")
eq("levelOf over cap", lv(9500), "41/500/0")
eq("levelOf bad", lv(-5), "1/0/30")
eq("pointsOf 1", ST.pointsOf(1), 0)
eq("pointsOf 10", ST.pointsOf(10), 9)
eq("pointsOf 41", ST.pointsOf(41), 40) -- v1.5
eq("pointsOf 61", ST.pointsOf(61), 40)
eq("pointsOf 99", ST.pointsOf(99), 40)

-- spent / sanitize
eq("spent empty", ST.spent({}), 0)
eq("spent regen 2", ST.spent({regen = 2}), 3)
eq("spent full path", ST.spent({jaws = 4}), 10)
local clean = ST.sanitize({regen = 2.7, jaws = 9, hide = -1, nope = 3, turret = 2, legs = "x"})
eq("sanitize regen", clean.regen, 2)
eq("sanitize jaws clamp", clean.jaws, 4)
eq("sanitize hide", clean.hide, 0)
eq("sanitize unknown", clean.nope, nil)
eq("sanitize soon", clean.turret, 0)
eq("sanitize bad type", clean.legs, 0)

-- buy rules
local function cb(steps, id, earned) local okb, why = ST.canBuy(steps, id, earned) return tostring(okb) .. ":" .. why end
eq("canBuy ok", cb({}, "regen", 1), "true:ok")
eq("canBuy noPoints", cb({}, "regen", 0), "false:noPoints")
eq("canBuy step II needs 2", cb({regen = 1}, "regen", 2), "false:noPoints") -- 1 spent, 1 left, needs 2
eq("canBuy step II ok", cb({regen = 1}, "regen", 3), "true:ok")
eq("canBuy soon", cb({}, "turret", 10), "false:soon")
eq("canBuy unknown", cb({}, "nope", 10), "false:unknownPath")
eq("canBuy maxed", cb({hide = 4}, "hide", 60), "false:maxed")
local before = {regen = 1}
local after, why = ST.buy(before, "regen", 3)
eq("buy result", after and after.regen, 2)
eq("buy reason", why, "ok")
eq("buy no mutate", before.regen, 1)
local none, why2 = ST.buy({}, "regen", 0)
eq("buy refused", none, nil)
eq("buy refused reason", why2, "noPoints")

ST.STRONG = false -- v1.3: the 1.0 - 1.2 cases below check the old numbers
-- effects: neutral for an empty build
local e0 = ST.effects({})
eq("e0 attack", e0.attackPts, 0); eq("e0 defense", e0.defensePts, 0); eq("e0 speed", e0.speedPts, 0)
eq("e0 regenRate", e0.regenRate, 0); eq("e0 regenDelay", e0.regenDelay, 0); eq("e0 killRegenAdd", e0.killRegenAdd, 0)
eq("e0 lifesteal", e0.lifesteal, 0); eq("e0 shieldMax", e0.shieldMax, 0)
eq("e0 mainCdMul", e0.mainCdMul, 1); eq("e0 moveCdMul", e0.moveCdMul, 1)
eq("e0 bleedDps", e0.bleedDps, 0); eq("e0 crushStun", e0.crushStun, 0)
eq("e0 tossMul", e0.tossMul, 1); eq("e0 stunMul", e0.stunMul, 1); eq("e0 stunImmuneAbove", e0.stunImmuneAbove, 0)

-- effects per step (numbers table in the plan)
local function e(steps) return ST.effects(steps) end
eq("regen I", e({regen = 1}).regenRate, 0.02); eq("regen I delay", e({regen = 1}).regenDelay, 6)
eq("regen II", e({regen = 2}).regenRate, 0.03); eq("regen II delay", e({regen = 2}).regenDelay, 5)
eq("regen III", e({regen = 3}).regenRate, 0.04); eq("regen III delay", e({regen = 3}).regenDelay, 4)
eq("regen star kill", e({regen = 4}).killRegenAdd, 0.25); eq("regen star keeps rate", e({regen = 4}).regenRate, 0.04)
eq("regen III no kill", e({regen = 3}).killRegenAdd, 0)
eq("life I", e({lifesteal = 1}).lifesteal, 0.05); eq("life II", e({lifesteal = 2}).lifesteal, 0.10)
eq("life III", e({lifesteal = 3}).lifesteal, 0.15); eq("life III shield", e({lifesteal = 3}).shieldMax, 0)
eq("life star shield", e({lifesteal = 4}).shieldMax, 0.20); eq("life star time", e({lifesteal = 4}).shieldTime, 6)
eq("life star keeps steal", e({lifesteal = 4}).lifesteal, 0.15)
eq("jaws I", e({jaws = 1}).attackPts, 1); eq("jaws I cd", e({jaws = 1}).mainCdMul, 1)
eq("jaws II cd", e({jaws = 2}).mainCdMul, 0.9); eq("jaws II attack", e({jaws = 2}).attackPts, 1)
eq("jaws III bleed", e({jaws = 3}).bleedDps, 3); eq("jaws III bleed time", e({jaws = 3}).bleedTime, 4)
eq("jaws II no bleed", e({jaws = 2}).bleedDps, 0)
eq("jaws star stun", e({jaws = 4}).crushStun, 0.75); eq("jaws star stun cd", e({jaws = 4}).crushCooldown, 4)
eq("hide I", e({hide = 1}).defensePts, 1); eq("hide I toss", e({hide = 1}).tossMul, 1)
eq("hide II toss", e({hide = 2}).tossMul, 0.5); eq("hide II defense", e({hide = 2}).defensePts, 1)
eq("hide III stun", e({hide = 3}).stunMul, 0.75)
eq("hide star immune", e({hide = 4}).stunImmuneAbove, 0.5)
eq("legs I", e({legs = 1}).speedPts, 1)
eq("legs II", e({legs = 2}).speedPts, 6) -- +5 = run speed x1.5 through StatServer (+10% per point)
eq("legs III cd", e({legs = 3}).moveCdMul, 0.85); eq("legs III speed", e({legs = 3}).speedPts, 6)
eq("legs star", e({legs = 4}).speedPts, 7)
-- a soon path's steps never count
eq("soon ignored", e({turret = 4}).attackPts, 0)
-- full build of all five passives
local all = e({regen = 4, lifesteal = 4, jaws = 4, hide = 4, legs = 4})
eq("all attack", all.attackPts, 1); eq("all defense", all.defensePts, 1); eq("all speed", all.speedPts, 7)
eq("all spent", ST.spent({regen = 4, lifesteal = 4, jaws = 4, hide = 4, legs = 4}), 50)

-- v1.1: mecha framework + Thrusters
eq("LIVE thrusters", ST.LIVE_MECH.thrusters, true)
eq("BUTTONS thrusters", ST.BUTTONS.thrusters, true)
eq("SLOTS", ST.SLOTS, 4) -- v1.5 (1.1: 2)
eq("thrusters not soon", ST.PATHS.thrusters.soon, false)
eq("grapple deleted", ST.PATHS.grapple, nil) -- v1.15 (was: still soon)
eq("cloak live", ST.PATHS.cloak.soon, false) -- v1.5
eq("canBuy thrusters I", cb({}, "thrusters", 1), "true:ok")
eq("canBuy thrusters II needs 3", cb({thrusters = 1}, "thrusters", 2), "false:noPoints")
eq("canBuy thrusters II", cb({thrusters = 1}, "thrusters", 3), "true:ok")
eq("sanitize keeps thrusters", ST.sanitize({thrusters = 2}).thrusters, 2)
eq("spent thrusters full", ST.spent({thrusters = 4}), 10)
eq("dash 0 charges", e({}).dashCharges, 0); eq("dash 0 dist", e({}).dashDist, 0); eq("dash 0 hop", e({}).dashHop, 0)
eq("dash I charges", e({thrusters = 1}).dashCharges, 1); eq("dash I dist", e({thrusters = 1}).dashDist, 35)
eq("dash II charges", e({thrusters = 2}).dashCharges, 2); eq("dash II dist", e({thrusters = 2}).dashDist, 35)
eq("dash III dist", e({thrusters = 3}).dashDist, 50); eq("dash III hop", e({thrusters = 3}).dashHop, 0)
eq("dash star hop", e({thrusters = 4}).dashHop, 25); eq("dash star charges", e({thrusters = 4}).dashCharges, 2)
eq("dash leaves passives", e({thrusters = 4}).speedPts, 0)
local function lo(t) return tostring(t[1]) .. "," .. tostring(t[2]) end
local own = {thrusters = 1}
eq("sanitizeLoadout nil", lo(ST.sanitizeLoadout(nil, own)), "false,false")
eq("sanitizeLoadout ok", lo(ST.sanitizeLoadout({"thrusters", false}, own)), "thrusters,false")
eq("sanitizeLoadout dup", lo(ST.sanitizeLoadout({"thrusters", "thrusters"}, own)), "thrusters,false")
eq("sanitizeLoadout slot2", lo(ST.sanitizeLoadout({false, "thrusters"}, own)), "false,thrusters")
eq("sanitizeLoadout unowned", lo(ST.sanitizeLoadout({"thrusters", false}, {})), "false,false")
eq("sanitizeLoadout passive", lo(ST.sanitizeLoadout({"regen", "jaws"}, {regen = 2, jaws = 1})), "false,false")
eq("sanitizeLoadout soon", lo(ST.sanitizeLoadout({"sentry", "turret"}, {sentry = 1})), "false,false") -- v1.15: sentry (grapple deleted)
eq("sanitizeLoadout deleted id", lo(ST.sanitizeLoadout({"grapple", "decoy"}, {grapple = 4, decoy = 4}, "Raptor")), "false,false") -- v1.15
eq("sanitizeLoadout junk", lo(ST.sanitizeLoadout({5, {}}, own)), "false,false")
eq("autoSlot first", lo(ST.autoSlot({false, false}, own, "thrusters")), "thrusters,false")
eq("autoSlot already", lo(ST.autoSlot({false, "thrusters"}, own, "thrusters")), "false,thrusters")
eq("autoSlot passive", lo(ST.autoSlot({false, false}, {regen = 1}, "regen")), "false,false")
eq("autoSlot unowned", lo(ST.autoSlot({false, false}, {}, "thrusters")), "false,false")
local inLo = {false, false}
ST.autoSlot(inLo, own, "thrusters")
eq("autoSlot no input change", lo(inLo), "false,false")
local function ss(l, st, n, id) local r, why = ST.setSlot(l, st, n, id) return (r and lo(r) or "nil") .. ":" .. tostring(why) end
eq("setSlot 2", ss({"thrusters", false}, own, 2, "thrusters"), "false,thrusters:ok")
eq("setSlot 1", ss({false, false}, own, 1, "thrusters"), "thrusters,false:ok")
eq("setSlot clear", ss({"thrusters", false}, own, 1, ""), "false,false:ok")
eq("setSlot clear false", ss({false, "thrusters"}, own, 2, false), "false,false:ok")
eq("setSlot badSlot 0", ss({false, false}, own, 0, "thrusters"), "nil:badSlot")
eq("setSlot badSlot 5", ss({false, false}, own, 5, "thrusters"), "nil:badSlot") -- v1.5: 4 slots
eq("setSlot badSlot str", ss({false, false}, own, "1", "thrusters"), "nil:badSlot")
eq("setSlot notButton", ss({false, false}, {regen = 1}, 1, "regen"), "nil:notButton")
eq("setSlot notButton junk", ss({false, false}, own, 1, "nope"), "nil:notButton")
eq("setSlot notOwned", ss({false, false}, {}, 1, "thrusters"), "nil:notOwned")
-- v1.2: boost length and step texts
eq("boost 0", e({}).dashTime, 0)
eq("boost I", e({thrusters = 1}).dashTime, 1.5)
eq("boost II", e({thrusters = 2}).dashTime, 1.5)
eq("boost III", e({thrusters = 3}).dashTime, 2.0)
eq("boost star", e({thrusters = 4}).dashTime, 2.0)
eq("thrusters text I", ST.PATHS.thrusters.steps[1], "Button: rocket boost for 1.37 s at 2x run speed (steer while boosting; in the air with no stick: straight up)") -- v1.8 text
eq("thrusters steps", #ST.PATHS.thrusters.steps, 4)
eq("deleted ids not buyable", select(2, ST.canBuy({}, "decoy", 40, "Raptor")), "unknownPath") -- v1.15 (was: grapple text kept)
-- v1.3: the 35% rule (STRONG): every step >= 1.35x the step before (times / cooldowns / damage taken: <= 1 / 1.35)
ST.STRONG = true
local function ok35(name, before, after, lower) -- lower = smaller is better
	local ratio = lower and before / after or after / before
	eq(name .. " >= 1.35x", ratio >= 1.35 - 1e-9, true)
end
local function E(k, n) local st = {} st[k] = n return ST.effects(st) end
eq("regen I rate", E("regen", 1).regenRate, 0.02); eq("regen I delay", E("regen", 1).regenDelay, 6)
eq("regen II rate", E("regen", 2).regenRate, 0.03); eq("regen II delay", E("regen", 2).regenDelay, 4.4)
eq("regen III rate", E("regen", 3).regenRate, 0.045); eq("regen III delay", E("regen", 3).regenDelay, 3.2)
ok35("regen rate I->II", 0.02, E("regen", 2).regenRate); ok35("regen rate II->III", 0.03, E("regen", 3).regenRate)
ok35("regen delay I->II", 6, E("regen", 2).regenDelay, true); ok35("regen delay II->III", 4.4, E("regen", 3).regenDelay, true)
ok35("kill heal star", 0.25, 0.25 + E("regen", 4).killRegenAdd)
ok35("lifesteal I->II", E("lifesteal", 1).lifesteal, E("lifesteal", 2).lifesteal)
ok35("lifesteal II->III", E("lifesteal", 2).lifesteal, E("lifesteal", 3).lifesteal)
eq("jaws I attack", E("jaws", 1).attackPts, 5)
ok35("jaws I bite", 25, 25 + 2 * E("jaws", 1).attackPts)
ok35("jaws I pounce land", 8, 8 + 2 * E("jaws", 1).attackPts); ok35("jaws I pounce tick", 4, 4 + E("jaws", 1).attackPts)
eq("jaws II cd", E("jaws", 2).mainCdMul, 0.74); ok35("jaws II cd", 1, E("jaws", 2).mainCdMul, true)
eq("jaws star keeps attack", E("jaws", 4).attackPts, 5)
eq("hide I defense", E("hide", 1).defensePts, 6); ok35("hide I damage taken", 1, 1 - 0.05 * E("hide", 1).defensePts, true)
ok35("hide II toss", 1, E("hide", 2).tossMul, true)
eq("hide III stun", E("hide", 3).stunMul, 0.70); ok35("hide III stun", 1, E("hide", 3).stunMul, true)
local function run(n) return 1 + 0.1 * E("legs", n).speedPts end
eq("legs I pts", E("legs", 1).speedPts, 4); eq("legs II pts", E("legs", 2).speedPts, 9)
eq("legs III pts", E("legs", 3).speedPts, 9); eq("legs star pts", E("legs", 4).speedPts, 16)
ok35("legs I run", 1, run(1)); ok35("legs II run", run(1), run(2)); ok35("legs star run", run(3), run(4))
eq("legs III cd", E("legs", 3).moveCdMul, 0.74); ok35("legs III cd", 1, E("legs", 3).moveCdMul, true)
ok35("thrusters II charges", E("thrusters", 1).dashCharges, E("thrusters", 2).dashCharges)
eq("thrusters I time", E("thrusters", 1).dashTime, 1.37); eq("thrusters II time", E("thrusters", 2).dashTime, 1.37) -- v1.8
eq("thrusters III time", E("thrusters", 3).dashTime, 1.85); ok35("thrusters III time", E("thrusters", 2).dashTime, E("thrusters", 3).dashTime)
eq("thrusters star time", E("thrusters", 4).dashTime, 1.85) -- v1.8
eq("thrusters text III", ST.PATHS.thrusters.steps[3], "Longer boost: 1.85 s")
eq("text legs star", ST.PATHS.legs.steps[4], "Run speed x2.6")
eq("text jaws II", ST.PATHS.jaws.steps[2], "Main attack recharges 35% faster")
local all3 = ST.effects({regen = 4, lifesteal = 4, jaws = 4, hide = 4, legs = 4, thrusters = 4})
eq("all3 attack", all3.attackPts, 5); eq("all3 defense", all3.defensePts, 6); eq("all3 speed", all3.speedPts, 16)
ST.STRONG = false
eq("off legs star", ST.effects({legs = 4}).speedPts, 7); eq("off jaws cd", ST.effects({jaws = 2}).mainCdMul, 0.9)
ST.STRONG = true

-- v1.5: per-dino trees
local function names(list) local o = {} for _, p in ipairs(list) do table.insert(o, p.id) end return table.concat(o, ",") end
eq("pathsFor health Raptor", names(ST.pathsFor("health", "Raptor")), "regen,lifesteal,adrenaline")
eq("pathsFor health TRex", names(ST.pathsFor("health", "TRex")), "lifesteal,repairdrone,biobattery")
eq("pathsFor attack Raptor", names(ST.pathsFor("attack", "Raptor")), "blade,screech") -- v1.9 (1.6: no jaws; dart hidden)
eq("pathsFor attack TRex", names(ST.pathsFor("attack", "TRex")), "jaws,rocket")
eq("pathsFor defense Raptor", names(ST.pathsFor("defense", "Raptor")), "hide,shield,cloak")
eq("pathsFor defense TRex", names(ST.pathsFor("defense", "TRex")), "hide,armor,reactive")
eq("pathsFor speed Raptor", names(ST.pathsFor("speed", "Raptor")), "legs,thrusters") -- v1.12: grapple scrapped;
eq("pathsFor speed TRex", names(ST.pathsFor("speed", "TRex")), "legs,ramjet")
eq("pathsFor eng Raptor", names(ST.pathsFor("eng", "Raptor")), "traps,scent") -- v1.9 (beacon hidden); v1.12: + traps; v1.14: decoy hidden
eq("pathsFor eng TRex", names(ST.pathsFor("eng", "TRex")), "shieldproj,roaramp")
eq("pathsFor eng new dino", names(ST.pathsFor("eng", "Stego")), "")
eq("pathsFor health new dino", names(ST.pathsFor("health", "Stego")), "regen,lifesteal")
eq("pathsFor nil = all", #ST.pathsFor("eng", nil), 6) -- v1.9: + scent; v1.15: - beacon, decoy
eq("none hidden from All", ST.seesPath("turret", "All"), false)
eq("canBuy cloak no dino", cb({}, "cloak", 5), "true:ok") -- dino nil = 1.4 behaviour (every path)
local function cbd(steps, id, earned, dino) local okb, why = ST.canBuy(steps, id, earned, dino) return tostring(okb) .. ":" .. why end
eq("canBuy cloak as TRex", cbd({}, "cloak", 5, "TRex"), "false:otherDino")
eq("canBuy cloak as Raptor", cbd({}, "cloak", 1, "Raptor"), "true:ok")
eq("canBuy thrusters as TRex", cbd({}, "thrusters", 5, "TRex"), "false:otherDino")
eq("canBuy regen as TRex", cbd({}, "regen", 5, "TRex"), "false:otherDino")
eq("canBuy regen as Raptor", cbd({}, "regen", 5, "Raptor"), "true:ok")
eq("canBuy ramjet soon", cbd({}, "ramjet", 5, "TRex"), "false:soon")
local trex = ST.sanitize({thrusters = 2, regen = 2, jaws = 1}, "TRex")
eq("sanitize TRex thrusters", trex.thrusters, 0); eq("sanitize TRex regen", trex.regen, 0); eq("sanitize TRex jaws", trex.jaws, 1)
eq("spent TRex refunds", ST.spent({thrusters = 2, regen = 2, jaws = 1}, "TRex"), 1)
eq("sanitize nil keeps", ST.sanitize({thrusters = 2}).thrusters, 2)

-- v1.5: Mastery 3 (ADR-003)
local m3 = {legs = 3, blade = 3, cloak = 3, hide = 2} -- v1.9: blade (jaws is not a raptor path since 1.6; these 4 cases were stale)
eq("mastered list", table.concat(ST.mastered(m3, "Raptor"), ","), "blade,cloak,legs") -- PATH_ORDER; hide at II is not mastered
eq("mastered count", #ST.mastered(m3, "Raptor"), 3)
eq("4th line III", cbd(m3, "hide", 40, "Raptor"), "false:masteryFull")
eq("4th line II ok", cbd(m3, "thrusters", 40, "Raptor"), "true:ok")
eq("star of mastered", cbd(m3, "legs", 40, "Raptor"), "true:ok")
eq("3rd line III ok", cbd({legs = 3, blade = 3, hide = 2}, "hide", 40, "Raptor"), "true:ok")
eq("masteryOk 3", ST.masteryOk(m3, "Raptor"), true)
eq("masteryOk 4", ST.masteryOk({legs = 3, blade = 3, cloak = 3, hide = 3}, "Raptor"), false)
ST.BUILD_LIMITS = false
eq("limits off: 4th III", cbd(m3, "hide", 60, "Raptor"), "true:ok")
eq("limits off: masteryOk", ST.masteryOk({legs = 3, blade = 3, cloak = 3, hide = 3}, "Raptor"), true)
ST.BUILD_LIMITS = true

-- v1.5: Cloak effects (35% rule on time)
eq("cloak 0 time", E("cloak", 0).cloakTime, 0); eq("cloak 0 cd", E("cloak", 0).cloakCooldown, 0)
eq("cloak I time", E("cloak", 1).cloakTime, 3); eq("cloak I cd", E("cloak", 1).cloakCooldown, 12)
eq("cloak I mul", E("cloak", 1).cloakPounceMul, 1); eq("cloak I still", E("cloak", 1).cloakStill, false)
eq("cloak II time", E("cloak", 2).cloakTime, 4.1); ok35("cloak II time", 3, E("cloak", 2).cloakTime)
eq("cloak III mul", E("cloak", 3).cloakPounceMul, 1.35); eq("cloak III still", E("cloak", 3).cloakStill, false)
eq("cloak star still", E("cloak", 4).cloakStill, true); eq("cloak star time", E("cloak", 4).cloakTime, 4.1)
eq("cloak TRex ignored", ST.effects({cloak = 4}, "TRex").cloakTime, 0)

-- v1.5: 4 slots
local function lo4(t) return ("%s,%s,%s,%s"):format(tostring(t[1]), tostring(t[2]), tostring(t[3]), tostring(t[4])) end
local both = {thrusters = 1, cloak = 1}
eq("pad 2-slot save", lo4(ST.sanitizeLoadout({"thrusters", false}, both, "Raptor")), "thrusters,false,false,false")
eq("setSlot 3", (function() local r = ST.setSlot({"thrusters", false, false, false}, both, 3, "thrusters", "Raptor") return lo4(r) end)(), "false,false,thrusters,false")
eq("setSlot 4 cloak", (function() local r = ST.setSlot({"thrusters", false, false, false}, both, 4, "cloak", "Raptor") return lo4(r) end)(), "thrusters,false,false,cloak")
eq("autoSlot cloak", lo4(ST.autoSlot({"thrusters", false, false, false}, both, "cloak", "Raptor")), "thrusters,cloak,false,false")
eq("TRex loadout drops raptor parts", lo4(ST.sanitizeLoadout({"thrusters", "cloak", false, false}, both, "TRex")), "false,false,false,false")

-- v1.6: raptor batch 1 (Blade Claws, Adrenaline Injector, Energy Shield; plan docs/plans/RAPTOR_PARTS_B1_v1.0.md)
eq("Version 1.6+", ST.Version, "1.15") -- v1.15
for _, id in ipairs({"blade", "adrenaline", "shield"}) do eq(id .. " live", ST.PATHS[id].soon, false) end
eq("blade passive", ST.BUTTONS.blade == true, false)
local function R(id, n) return ST.effects({[id] = n}, "Raptor") end
eq("blade 0", R("blade", 0).bladeLandBonus, 0); eq("blade 0 tick", R("blade", 0).bladeTickMul, 1)
eq("blade I", R("blade", 1).bladeLandBonus, 0.35); eq("blade I tick", R("blade", 1).bladeTickMul, 1)
eq("blade II tick", R("blade", 2).bladeTickMul, 0.74); eq("blade II bleed", R("blade", 2).bladeBleedDps, 0)
eq("blade III bleed", R("blade", 3).bladeBleedDps, 3); eq("blade III time", R("blade", 3).bladeBleedTime, 4)
eq("blade III refund", R("blade", 3).bladePinRefund, 0); eq("blade star refund", R("blade", 4).bladePinRefund, 0.5)
eq("adren 0", R("adrenaline", 0).adrenHeal, 0); eq("adren 0 cd", R("adrenaline", 0).adrenCooldown, 0)
eq("adren I heal", R("adrenaline", 1).adrenHeal, 0.25); eq("adren I time", R("adrenaline", 1).adrenTime, 3)
eq("adren I speed", R("adrenaline", 1).adrenSpeedMul, 1.4); eq("adren I cd", R("adrenaline", 1).adrenCooldown, 20)
eq("adren II heal", R("adrenaline", 2).adrenHeal, 0.34); eq("adren star heal", R("adrenaline", 4).adrenHeal, 0.34)
eq("adren III cd", R("adrenaline", 3).adrenCooldown, 14.8) -- v1.7: heal / speed / star-heal cases updated
eq("adren III clear", R("adrenaline", 3).adrenStunClear, false); eq("adren star clear", R("adrenaline", 4).adrenStunClear, true)
eq("adren 0 speed", R("adrenaline", 0).adrenSpeedMul, 1)
eq("shield 0", R("shield", 0).eshieldTime, 0); eq("shield 0 slow", R("shield", 0).eshieldSpeedMul, 1)
eq("shield I", R("shield", 1).eshieldTime, 1.5); eq("shield I cd", R("shield", 1).eshieldCooldown, 16)
eq("shield I slow", R("shield", 1).eshieldSpeedMul, 0.5)
eq("shield II", R("shield", 2).eshieldTime, 2.05); eq("shield III cd", R("shield", 3).eshieldCooldown, 11.8)
eq("shield star", R("shield", 4).eshieldTime, 2.77); eq("shield star slow", R("shield", 4).eshieldSpeedMul, 0.68)
eq("shield III slow", R("shield", 3).eshieldSpeedMul, 0.5)
-- 35% rule
eq("35 adren heal", R("adrenaline", 2).adrenHeal / R("adrenaline", 1).adrenHeal >= 1.35 - 1e-9, true) -- v1.7: from the data
eq("35 adren cd", 20 / 14.8 >= 1.35, true)
eq("35 shield II", 2.05 / 1.5 >= 1.35, true); eq("35 shield star", 2.77 / 2.05 >= 1.35, true)
eq("35 shield cd", 16 / 11.8 >= 1.35, true); eq("35 shield slow", 0.68 / 0.5 >= 1.35, true)
-- T-Rex gets none of it
local tx = ST.effects({blade = 4, adrenaline = 4, shield = 4}, "TRex")
eq("TRex blade", tx.bladeLandBonus, 0); eq("TRex adren", tx.adrenHeal, 0); eq("TRex shield", tx.eshieldTime, 0)
-- slots: adrenaline / shield slottable, blade not
local b1 = {adrenaline = 1, shield = 1, blade = 1}
eq("autoSlot adrenaline", lo4(ST.autoSlot({false, false, false, false}, b1, "adrenaline", "Raptor")), "adrenaline,false,false,false")
eq("autoSlot blade", lo4(ST.autoSlot({false, false, false, false}, b1, "blade", "Raptor")), "false,false,false,false")
eq("setSlot shield 4", (function() local r = ST.setSlot({false, false, false, false}, b1, 4, "shield", "Raptor") return lo4(r) end)(), "false,false,false,shield")
eq("shield step I text", ST.PATHS.shield.steps[1], "Button: block all damage for 1.5 s, but move at half speed while it's up")
eq("shield star text", ST.PATHS.shield.steps[4], "Blocks even longer (2.77 s) and the slow is lighter")
eq("adren step I text", ST.PATHS.adrenaline.steps[1], "Button: heal 25% of max health over 3 s and run 1.4x faster while it lasts") -- v1.7
eq("adren step II text", ST.PATHS.adrenaline.steps[2], "Heal 34%")
-- v1.6: no Jaws for raptors
eq("raptor jaws hidden", ST.seesPath("jaws", "Raptor"), false); eq("trex jaws", ST.seesPath("jaws", "TRex"), true)
eq("raptor jaws buy", select(2, ST.canBuy({}, "jaws", 5, "Raptor")), "otherDino")
eq("raptor jaws effects", ST.effects({jaws = 4}, "Raptor").bleedDps, 0)
eq("raptor jaws refunded", ST.sanitize({jaws = 2}, "Raptor").jaws, 0)
local att = {} for _, p in ipairs(ST.pathsFor("attack", "Raptor")) do table.insert(att, p.id) end
eq("raptor attack area", table.concat(att, ","), "blade,screech") -- v1.9

-- v1.9: raptor batch 2 (Scent Sense, Raptor Screech; plan docs/plans/RAPTOR_PARTS_B2_v1.0.md)
for _, id in ipairs({"scent", "screech"}) do eq(id .. " live", ST.PATHS[id].soon, false); eq(id .. " button", ST.BUTTONS[id], true) end
eq("dart deleted", ST.PATHS.dart, nil); eq("beacon deleted", ST.PATHS.beacon, nil) -- v1.15 (was: hidden)
eq("scent trex", ST.seesPath("scent", "TRex"), false); eq("screech trex", ST.seesPath("screech", "TRex"), false)
eq("scent 0", R("scent", 0).scentRadius, 0); eq("scent 0 cd", R("scent", 0).scentCooldown, 0)
eq("scent I", R("scent", 1).scentRadius, 60); eq("scent I mem", R("scent", 1).scentMemory, 8)
eq("scent I time", R("scent", 1).scentTime, 6); eq("scent I cd", R("scent", 1).scentCooldown, 16)
eq("scent II", R("scent", 2).scentRadius, 81); eq("scent II fresh", R("scent", 2).scentFresh, false)
eq("scent III mem", R("scent", 3).scentMemory, 10.8); eq("scent III fresh", R("scent", 3).scentFresh, true)
eq("scent III blood", R("scent", 3).scentBlood, false); eq("scent star blood", R("scent", 4).scentBlood, true)
eq("screech 0", R("screech", 0).screechRange, 0)
eq("screech I", R("screech", 1).screechRange, 100); eq("screech I flinch", R("screech", 1).screechFlinch, 1.1)
eq("screech I cd", R("screech", 1).screechCooldown, 14); eq("screech II", R("screech", 2).screechRange, 135)
eq("screech III cd", R("screech", 3).screechCooldown, 10.3); eq("screech III jam", R("screech", 3).screechJam, false)
eq("screech star jam", R("screech", 4).screechJam, false) -- v1.14 (was true)
eq("35 scent radius", 81 / 60 >= 1.35 - 1e-9, true); eq("35 scent mem", 10.8 / 8 >= 1.35 - 1e-9, true)
eq("35 screech range", R("screech", 2).screechRange / R("screech", 1).screechRange >= 1.35 - 1e-9, true)
eq("35 screech cd", R("screech", 1).screechCooldown / R("screech", 3).screechCooldown >= 1.35 - 1e-9, true)
eq("shock cannon name", ST.PATHS.screech.name, "Shock Cannon") -- v1.11 (1.10: Shock Dart)
eq("screech III flinch", R("screech", 3).screechFlinch, 1.1); eq("screech star flinch", R("screech", 4).screechFlinch, 1.1) -- v1.14 (was 1.5)
eq("screech star dmg", R("screech", 4).screechDamage, 30); eq("screech III dmg", R("screech", 3).screechDamage, 0) -- v1.14 (was the 35% stun check)
eq("decoy deleted", ST.PATHS.decoy, nil) -- v1.15 (1.14: hidden)
-- v1.12: Shock Mine
eq("mine name", ST.PATHS.traps.name, "Shock Mine"); eq("mine button", ST.BUTTONS.traps, true); eq("mine live", ST.PATHS.traps.soon, false)
eq("mine raptor", ST.seesPath("traps", "Raptor"), true); eq("mine trex", ST.seesPath("traps", "TRex"), false)
eq("grapple deleted (raptor)", ST.sanitize({grapple = 4}, "Raptor").grapple, nil) -- v1.15 (was: hidden)
eq("mine 0", R("traps", 0).mineDamage, 0); eq("mine 0 slow", R("traps", 0).mineSlow, 1)
eq("mine I dmg", R("traps", 1).mineDamage, 25); eq("mine I slow", R("traps", 1).mineSlow, 0.5)
eq("mine I slow time", R("traps", 1).mineSlowTime, 2); eq("mine I cd", R("traps", 1).mineCooldown, 12)
eq("mine I max", R("traps", 1).mineMax, 1); eq("mine II max", R("traps", 2).mineMax, 2)
eq("mine III cd", R("traps", 3).mineCooldown, 8.8); eq("mine III jam", R("traps", 3).mineJam, false)
eq("mine star jam", R("traps", 4).mineJam, true)
eq("35 mine max", R("traps", 2).mineMax / R("traps", 1).mineMax >= 1.35 - 1e-9, true)
eq("35 mine cd", R("traps", 1).mineCooldown / R("traps", 3).mineCooldown >= 1.35 - 1e-9, true)
eq("TRex mine", ST.effects({traps = 4}, "TRex").mineDamage, 0)
eq("mine 0 launch", R("traps", 0).mineLaunch, 0); eq("mine I launch", R("traps", 1).mineLaunch, 25)
eq("mine I daze", R("traps", 1).mineDaze, 1); eq("mine star launch", R("traps", 4).mineLaunch, 25)
local tx2 = ST.effects({scent = 4, screech = 4}, "TRex")
eq("TRex scent", tx2.scentRadius, 0); eq("TRex screech", tx2.screechRange, 0)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
