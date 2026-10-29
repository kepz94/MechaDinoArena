-- SkillTree.spec v1.5 (Mecha Dino Arena) — tests for ServerStorage.DinoArcade.SkillTree (MDA-11, plan
-- docs/plans/SKILLTREES_v1.0.md Task 1). Run in Studio Edit through execute_luau; returns "PASS n" or "FAIL ...".
local ok, ST = pcall(function() return require(game.ServerStorage.DinoArcade.SkillTree) end)
if not ok then return "FAIL require: " .. tostring(ST) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-9) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end

eq("Version", ST.Version, "1.5")
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
	"regen,medstation,lifesteal,adrenaline,repairdrone,biobattery,jaws,turret,rocket,blade,dart,hide,armor,shield,cloak,"
	.. "reactive,legs,thrusters,grapple,ramjet,sentry,traps,barricade,beacon,decoy,shieldproj,roaramp")
local buyable = {}
for _, id in ipairs(ids) do if not ST.PATHS[id].soon then table.insert(buyable, id) end end
eq("buyable", table.concat(buyable, ","), "regen,lifesteal,jaws,hide,cloak,legs,thrusters") -- v1.1: + thrusters; v1.5: + cloak (AREAS order)

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
eq("grapple still soon", ST.PATHS.grapple.soon, true)
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
eq("sanitizeLoadout soon", lo(ST.sanitizeLoadout({"grapple", "turret"}, {grapple = 1})), "false,false")
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
eq("thrusters text I", ST.PATHS.thrusters.steps[1], "Button: rocket boost for 1 s at 1.75x run speed (steer while boosting)") -- v1.4 text
eq("thrusters steps", #ST.PATHS.thrusters.steps, 4)
eq("grapple text kept", ST.PATHS.grapple.steps[1], "Button: pull yourself to a tree")
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
eq("thrusters I time", E("thrusters", 1).dashTime, 1.0); eq("thrusters II time", E("thrusters", 2).dashTime, 1.0) -- v1.4
eq("thrusters III time", E("thrusters", 3).dashTime, 1.35); ok35("thrusters III time", E("thrusters", 2).dashTime, E("thrusters", 3).dashTime)
eq("thrusters star time", E("thrusters", 4).dashTime, 1.35)
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
eq("pathsFor attack Raptor", names(ST.pathsFor("attack", "Raptor")), "jaws,blade,dart")
eq("pathsFor attack TRex", names(ST.pathsFor("attack", "TRex")), "jaws,rocket")
eq("pathsFor defense Raptor", names(ST.pathsFor("defense", "Raptor")), "hide,shield,cloak")
eq("pathsFor defense TRex", names(ST.pathsFor("defense", "TRex")), "hide,armor,reactive")
eq("pathsFor speed Raptor", names(ST.pathsFor("speed", "Raptor")), "legs,thrusters,grapple")
eq("pathsFor speed TRex", names(ST.pathsFor("speed", "TRex")), "legs,ramjet")
eq("pathsFor eng Raptor", names(ST.pathsFor("eng", "Raptor")), "beacon,decoy")
eq("pathsFor eng TRex", names(ST.pathsFor("eng", "TRex")), "shieldproj,roaramp")
eq("pathsFor eng new dino", names(ST.pathsFor("eng", "Stego")), "")
eq("pathsFor health new dino", names(ST.pathsFor("health", "Stego")), "regen,lifesteal")
eq("pathsFor nil = all", #ST.pathsFor("eng", nil), 7)
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
local m3 = {legs = 3, jaws = 3, cloak = 3, hide = 2}
eq("mastered list", table.concat(ST.mastered(m3, "Raptor"), ","), "jaws,cloak,legs") -- PATH_ORDER; hide at II is not mastered
eq("mastered count", #ST.mastered(m3, "Raptor"), 3)
eq("4th line III", cbd(m3, "hide", 40, "Raptor"), "false:masteryFull")
eq("4th line II ok", cbd(m3, "thrusters", 40, "Raptor"), "true:ok")
eq("star of mastered", cbd(m3, "legs", 40, "Raptor"), "true:ok")
eq("3rd line III ok", cbd({legs = 3, jaws = 3, hide = 2}, "hide", 40, "Raptor"), "true:ok")
eq("masteryOk 3", ST.masteryOk(m3, "Raptor"), true)
eq("masteryOk 4", ST.masteryOk({legs = 3, jaws = 3, cloak = 3, hide = 3}, "Raptor"), false)
ST.BUILD_LIMITS = false
eq("limits off: 4th III", cbd(m3, "hide", 60, "Raptor"), "true:ok")
eq("limits off: masteryOk", ST.masteryOk({legs = 3, jaws = 3, cloak = 3, hide = 3}, "Raptor"), true)
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

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
