-- SkillTree v1.5 (Mecha Dino Arena) — skill tree data and maths: areas, paths, step costs, the level curve, buy / respec
-- checks and what a build does. MDA-11, plan docs/plans/SKILLTREES_v1.0.md Task 1, ADR "Skill trees own XP and replace
-- class stat points". Pure: no Instance access. Used by SkillServer 1.0 / SkillEffects 1.0 (server) and, through the copy
-- SkillServer puts in ReplicatedStorage.SkillShared, by SkillScreen 1.0 (client).
-- Kepu: layout A; the paths replace the class stat points; Jaws upgrades the main attack (bite / pounce); 1 point per
--   level, cap 60; costs 1-2-3-4 along a path; free respec; fast start, slower later; the 5 missing effects are real
--   (bleed, crushing hit, less knockback, overheal shield) and Sprint Legs II is run speed x1.5.
-- Tree: AREAS = 5 areas (health, attack, defense, speed, eng) x 3 paths x 4 steps (I, II, III, star). PATHS[id] =
--   {id, name, area, mech, soon, steps}. Only regen, lifesteal, jaws, hide, legs are buyable in this piece; the other
--   10 have soon = true.
-- Level: xpToNext(L) = 30 + 10 (L - 1). levelOf(totalXp) -> level, xpIntoLevel, xpNext (0 at MAX_LEVEL 61; a bad or
--   negative total counts as 0). pointsOf(level) = min(level - 1, MAX_POINTS 60).
-- Builds: steps = {[pathId] = 0..4}. sanitize(raw) -> a clean copy: known ids only, whole numbers 0..4, soon paths 0, a
--   non-number -> 0. spent(steps) = sum of COST over the bought steps of the sanitized build.
--   canBuy(steps, pathId, pointsEarned) -> ok, reason ("ok" / "unknownPath" / "soon" / "maxed" / "noPoints").
--   buy(...) -> a new steps table and "ok", or nil and the reason; never changes its input. Respec = {}.
-- effects(steps) -> what the build does (sanitized; soon paths never count):
--   attackPts / defensePts / speedPts: player StatAdded_* points (StatServer: +2 bite / +2 land / +1 tick, -5% damage
--     taken, +10% walk / run per point)
--   regenDelay (s without damage) / regenRate (fraction of max health per s); killRegenAdd (added to KillRegenFraction)
--   lifesteal (fraction of damage dealt healed); shieldMax (fraction of max health) / shieldTime (s)
--   mainCdMul (main attack cooldown), moveCdMul (pounce / ram / jump cooldowns)
--   bleedDps / bleedTime; crushStun (s) / crushCooldown (s per target)
--   tossMul (ram toss distance), stunMul (stun length), stunImmuneAbove (health fraction; 0 = off)
-- v1.1 (mecha parts framework + Thrusters, MDA-24, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 1, mockup
--   docs/mockups/mecha_thrusters_options.html; Kepu 2026-10-28: framework + 1 part, Thrusters first, numbers as proposed):
--   LIVE_MECH = {thrusters = true}: these mecha paths get soon = false at load (buyable); the other 9 stay "soon".
--   BUTTONS = {thrusters = true}: mecha parts that take a loadout slot. SLOTS = 2.
--   effects(steps) adds dashCharges (0; 1 at I; 2 from II), dashDist (35; 50 from III), dashHop (0; 25 at star).
--   Loadout = {[1] = pathId or false, [2] = pathId or false}:
--   sanitizeLoadout(raw, steps) -> a clean loadout: each slot a BUTTONS id bought (steps >= 1) and not soon, no id twice
--     (the lower slot wins), anything else false.
--   autoSlot(loadout, steps, pathId) -> a new loadout: a bought, unslotted BUTTONS id goes in the first empty slot;
--     otherwise the clean loadout unchanged.
--   setSlot(loadout, steps, n, pathId or false) -> a new loadout, "ok" | nil, reason ("badSlot" / "notButton" /
--     "notOwned"); the id leaves its other slot. None of these change their inputs.
-- v1.2 (Thrusters boost, MDA-31, plan docs/plans/MECHA_THRUSTERS_v1.0.md "v1.1 changes"; Kepu 2026-10-28 after trying it:
--   "make the thrusters actually last longer" -> "1.5 s boost, steerable"): effects adds dashTime (0; 1.5 s from I; 2 s
--   from III). The Thrusters step texts describe the boost. dashDist stays as in 1.1 (no longer used by the boost).
-- v1.3 (35% rule, MDA-34; Kepu 2026-10-28: "its an arcade game. i want these boosts to feel significant" / "every single
--   boost you made needs to be at least 35% of an improvement from before" -> each step's number at least 1.35x the
--   step before (for times, cooldowns and damage taken: at most 1 / 1.35 of it), whole tree): STRONG (default true;
--   false = the 1.2 numbers). While on, effects() uses: Regeneration II delay 4.4 s, III 3.2 s and 4.5%/s; Jaws I +5
--   Attack (T-Rex bite 25 -> 35), II main attack cooldown x0.74; Thick Hide I +6 Defense (damage taken x0.70), III stuns
--   x0.70; Sprint Legs I +4 Speed (run x1.4), II 9 (x1.9), III move cooldowns x0.74, star 16 (x2.6; StatSheet 1.1 cap 16);
--   Thrusters III boost 2.1 s. The step texts of those paths say the new numbers (Thrusters I: 3x run speed, SkillEffects
--   1.3).
-- v1.4 (MDA-36; Kepu 2026-10-28 after playing it: "the thrusters might be a little too fast. maybe just make it 1.75 my
--   run speed and 1 second long"): while STRONG, the Thrusters boost is 1 s (I / II) and 1.35 s from III (the 35% rule:
--   1.35 x 1 s); texts say 1 s at 1.75x run speed (SkillEffects 1.4) and 1.35 s.
-- v1.5 (Cloak release, MDA-49, plan docs/plans/CLOAK_v1.0.md; ADR-003 / ADR-004; Kepu 2026-10-29):
--   * Per-dino trees: path.dino = nil (shared stat path) / "Raptor" / "TRex" / "none" (kept, shown to nobody);
--     path.notFor = {[dino] = true} for a shared path a dino skips (regen: TRex). New paths are added to AREAS after the
--     1.4 ones (raptor: adrenaline, blade, dart, cloak, beacon, decoy; T-Rex: repairdrone, biobattery, reactive, ramjet,
--     shieldproj, roaramp); shield / grapple / thrusters become Raptor, rocket / armor TRex, medstation / turret / sentry
--     / traps / barricade "none". seesPath(p, dino): dino nil = every path (1.4 behaviour), "All" = every path but
--     "none", any other key = shared paths it isn't skipped from + its own. pathsFor(areaId, dino) -> the area's paths
--     the dino sees, shared first, then its own, each in AREAS order.
--   * Every build function takes an optional last argument dino: sanitize(raw, dino) zeroes paths the dino doesn't see;
--     spent / canBuy / buy / effects / sanitizeLoadout / autoSlot / setSlot pass it on. canBuy reasons in order:
--     unknownPath, otherDino, soon, maxed, masteryFull, noPoints, ok.
--   * Build limits (BUILD_LIMITS, default true; false = 1.4): MAX_POINTS 40, MAX_LEVEL 41 (one point per level), and
--     Mastery 3: a line is mastered at step >= 3; buying step III of a line while MASTERY_MAX (3) other lines are
--     mastered -> "masteryFull". mastered(steps, dino) -> ids in PATH_ORDER; masteryOk(steps, dino) -> count <= max.
--   * SLOTS = 4 (slot 1 = button 1 tap / R, 2 = button 2 tap / C, 3 = button 1 pull / T, 4 = button 2 pull / V).
--   * Cloak Field live (LIVE_MECH, BUTTONS): effects cloakTime (0; 3 s at I; 4.1 s from II), cloakCooldown (0; 12 s),
--     cloakPounceMul (1; 1.35 from III, added with other same-hit bonuses by PounceServer), cloakStill (false; true at
--     star: standing still keeps the cloak, up to 2 x cloakTime). BUTTONS also lists every button part (not live ones
--     stay "soon", so they can't be slotted).
local SkillTree = {}
SkillTree.Version = "1.5"
SkillTree.COST = {1, 2, 3, 4}
SkillTree.MAX_POINTS = 60
SkillTree.MAX_LEVEL = 61
-- v1.5: build limits (ADR-003 Mastery 3, ADR-004 40 points / level cap 41)
SkillTree.BUILD_LIMITS = true
SkillTree.MASTERY_MAX = 3
if SkillTree.BUILD_LIMITS then
	SkillTree.MAX_POINTS = 40
	SkillTree.MAX_LEVEL = 41
end

local function path(id, name, mech, soon, steps)
	return {id = id, name = name, mech = mech, soon = soon, steps = steps}
end

SkillTree.AREAS = {
	{id = "health", name = "Health", color = {95, 209, 106}, paths = {
		path("regen", "Regeneration", false, false, {
			"Heal 2% of max health per second after 6 s without damage",
			"Starts after 5 s, 3% per second",
			"Starts after 4 s, 4% per second",
			"Kill heal doubled: each kill heals 50% over 5 s (was 25%)"}),
		path("medstation", "Med-Station", true, true, {
			"Button: drop a machine that heals everyone nearby", "Bigger heal area", "Lasts longer", "Two stations"}),
		path("lifesteal", "Lifesteal", false, false, {
			"5% of the damage you deal heals you",
			"10% of the damage you deal heals you",
			"15% of the damage you deal heals you",
			"Healing past full becomes a shield (up to 20% of max health, lasts 6 s)"}),
	}},
	{id = "attack", name = "Attack", color = {240, 90, 79}, paths = {
		path("jaws", "Jaws", false, false, {
			"Main attack hits harder (+1 Attack point)",
			"Main attack recharges 10% faster",
			"Hits make the target bleed: 3 damage per second for 4 s",
			"Crushing hit: a hit stuns the target for 0.75 s (once every 4 s per target)"}),
		path("turret", "Back Turret", true, true, {
			"A turret on your back fires at the nearest enemy", "Faster fire", "Longer range", "Twin barrels"}),
		path("rocket", "Shoulder Rocket", true, true, {
			"Button: aimed rocket with splash damage", "Faster reload", "Bigger blast", "3-rocket burst"}),
	}},
	{id = "defense", name = "Defense", color = {90, 160, 255}, paths = {
		path("hide", "Thick Hide", false, false, {
			"Take 5% less damage (+1 Defense point)",
			"Less knockback: thrown half as far when a T-Rex rams you off",
			"Stuns are 25% shorter",
			"No stuns while above 50% health"}),
		path("armor", "Armor Plating", true, true, {
			"Button: absorb damage, press again to release it as a blast", "Bigger charge", "Faster recharge",
			"Bigger blast at max charge"}),
		path("shield", "Energy Shield", true, true, {
			"Button: a bubble that blocks damage for a few seconds", "Stronger", "Shorter cooldown",
			"Bursts and knocks enemies back"}),
	}},
	{id = "speed", name = "Speed", color = {255, 211, 77}, paths = {
		path("legs", "Sprint Legs", false, false, {
			"Run 10% faster (+1 Speed point)",
			"Run speed x1.5",
			"Pounce, ram and leap recharge 15% faster",
			"Run 10% faster again"}),
		path("thrusters", "Thrusters", true, true, {
			"Button: dash forward", "2 charges", "Longer dash", "Rocket hop"}),
		path("grapple", "Grapple Hook", true, true, {
			"Button: pull yourself to a tree", "Longer range", "Faster pull", "Hook an enemy and pull them in"}),
	}},
	{id = "eng", name = "Engineer", color = {255, 155, 46}, paths = {
		path("sentry", "Sentry", true, true, {"Button: drop an auto-turret", "More health", "More damage", "Two sentries"}),
		path("traps", "Traps", true, true, {
			"Button: drop mines", "Slowing net trap", "More mines", "EMP mine: shuts off enemy mech skills"}),
		path("barricade", "Barricade", true, true, {"Button: drop a wall", "Bigger", "Tougher", "A dome the squad can stand in"}),
	}},
}

-- v1.5: per-dino paths, appended to their areas (1.4 order kept)
do
	local add = {
		health = {
			path("adrenaline", "Adrenaline Injector", true, true, {
				"Button: heal 20% of max health over 3 s and run 1.3x faster while it lasts", "Heal 27%",
				"Recharges 26% faster", "Also ends a stun at once"}),
			path("repairdrone", "Repair Drone", true, true, {
				"Button: a drone lifts off your back and heals 20% of max health over 5 s", "Heals 27%",
				"Recharges 26% faster", "The drone also heals an ally next to you"}),
			path("biobattery", "Bio-Battery Spine", true, true, {
				"Every hit you land fills a cell (5 cells); full = heal 15% of max health", "Heal 20%",
				"4 cells to fill", "A full battery also gives 3 s of 35% faster bite recharge"}),
		},
		attack = {
			path("blade", "Blade Claws", true, true, {
				"Mech sickle claws: pounce landing hits 35% harder", "Latch / pin bites tick 35% faster",
				"Pounce hits make the target bleed", "A pin kill gives back half your pounce stamina"}),
			path("dart", "Dart Launcher", true, true, {
				"Button: fire a dart; the hit dino is slowed 30% for 3 s",
				"Marked: the hit dino shows through tall grass for 6 s", "Two darts per charge", "Tranquilizer: slow 60%"}),
		},
		defense = {
			path("cloak", "Cloak Field", true, true, {
				"Button: nearly invisible for 3 s; bots lose you. Ends when you pounce, get hit or use another part",
				"Lasts 4.1 s", "A pounce out of the cloak hits 35% harder",
				"Standing still keeps you cloaked, up to twice as long"}),
			path("reactive", "Reactive Armor", true, true, {
				"Each hit you take charges the panels (6 hits); full = your next bite deals +35% damage", "4 hits to charge",
				"The charged bite also knocks the target back", "The charged bite also stuns for 0.75 s"}),
		},
		speed = {
			path("ramjet", "Ramjet Charge", true, true, {
				"Button: charge straight ahead at 1.75x run speed for 1 s; dinos in the way are knocked aside",
				"2 charges", "Lasts 1.35 s", "Hitting a dino stuns it for 0.75 s"}),
		},
		eng = {
			path("beacon", "Pack Beacon", true, true, {
				"Button: mark every enemy within 60 studs for your squad for 5 s", "81-stud radius",
				"Marked enemies take 35% more damage from you", "Marks last until they leave the radius"}),
			path("decoy", "Decoy Hologram", true, true, {
				"Button: a fake raptor runs ahead for 5 s; bots chase it", "Lasts 6.75 s", "Two decoys",
				"The decoy bursts and stuns whoever is near it"}),
			path("shieldproj", "Shield Projector", true, true, {
				"Button: a hard-light wall in front of you for 3 s that blocks hits and rockets", "Lasts 4.1 s",
				"Wider wall", "The wall moves with you"}),
			path("roaramp", "Roar Amplifier", true, true, {
				"Button: roar; enemies in the cone take 25% more damage for 5 s", "Lasts 6.75 s",
				"Enemies take 35% more damage", "The roar also shields allies near you (25% less damage for 5 s)"}),
		},
	}
	for _, a in ipairs(SkillTree.AREAS) do
		for _, p in ipairs(add[a.id] or {}) do table.insert(a.paths, p) end
	end
end

SkillTree.PATHS = {}
SkillTree.PATH_ORDER = {}
for _, a in ipairs(SkillTree.AREAS) do
	for _, p in ipairs(a.paths) do
		p.area = a.id
		SkillTree.PATHS[p.id] = p
		table.insert(SkillTree.PATH_ORDER, p.id)
	end
end

-- v1.1: mecha parts that are built (buyable) and the ones that take a loadout slot
SkillTree.LIVE_MECH = {thrusters = true}
SkillTree.BUTTONS = {thrusters = true}
SkillTree.SLOTS = 2
-- v1.5: ownership, Cloak live, every button part listed, 4 slots
SkillTree.OWNER = {
	adrenaline = "Raptor", blade = "Raptor", dart = "Raptor", cloak = "Raptor", shield = "Raptor", thrusters = "Raptor",
	grapple = "Raptor", beacon = "Raptor", decoy = "Raptor",
	repairdrone = "TRex", biobattery = "TRex", rocket = "TRex", armor = "TRex", reactive = "TRex", ramjet = "TRex",
	shieldproj = "TRex", roaramp = "TRex",
	medstation = "none", turret = "none", sentry = "none", traps = "none", barricade = "none",
}
for id, dino in pairs(SkillTree.OWNER) do
	if SkillTree.PATHS[id] then SkillTree.PATHS[id].dino = dino end
end
SkillTree.PATHS.regen.notFor = {TRex = true}
SkillTree.LIVE_MECH.cloak = true
for _, id in ipairs({"adrenaline", "dart", "cloak", "shield", "grapple", "beacon", "decoy", "repairdrone", "rocket",
	"armor", "ramjet", "shieldproj", "roaramp"}) do
	SkillTree.BUTTONS[id] = true
end
SkillTree.SLOTS = 4
for id in pairs(SkillTree.LIVE_MECH) do
	if SkillTree.PATHS[id] then SkillTree.PATHS[id].soon = false end
end
-- v1.2: Thrusters is a steerable rocket boost
SkillTree.PATHS.thrusters.steps = {
	"Button: rocket boost for 1.5 s at 2x run speed (steer while boosting)",
	"2 charges",
	"Longer boost: 2 s",
	"Rocket hop: the boost starts with a 25-stud hop"}

-- v1.3: the 35% rule
SkillTree.STRONG = true
if SkillTree.STRONG then
	local P = SkillTree.PATHS
	P.regen.steps[2] = "Starts after 4.4 s, 3% per second"
	P.regen.steps[3] = "Starts after 3.2 s, 4.5% per second"
	P.jaws.steps[1] = "Main attack hits harder (+5 Attack points: T-Rex bite 25 -> 35)"
	P.jaws.steps[2] = "Main attack recharges 35% faster"
	P.hide.steps[1] = "Take 30% less damage (+6 Defense points)"
	P.hide.steps[3] = "Stuns are 30% shorter"
	P.legs.steps[1] = "Run 40% faster (+4 Speed points)"
	P.legs.steps[2] = "Run speed x1.9"
	P.legs.steps[3] = "Pounce, ram and leap recharge 35% faster"
	P.legs.steps[4] = "Run speed x2.6"
	P.thrusters.steps[1] = "Button: rocket boost for 1 s at 1.75x run speed (steer while boosting)" -- v1.4 (1.3: 1.5 s at 3x)
	P.thrusters.steps[3] = "Longer boost: 1.35 s" -- v1.4 (1.3: 2.1 s)
end

-- level curve
function SkillTree.xpToNext(level)
	return 30 + 10 * (level - 1)
end

function SkillTree.levelOf(totalXp)
	local xp = tonumber(totalXp)
	if not xp or xp ~= xp or xp < 0 then xp = 0 end
	xp = math.floor(xp)
	local level = 1
	while level < SkillTree.MAX_LEVEL do
		local need = SkillTree.xpToNext(level)
		if xp < need then return level, xp, need end
		xp -= need
		level += 1
	end
	return SkillTree.MAX_LEVEL, xp, 0
end

function SkillTree.pointsOf(level)
	return math.clamp(math.floor(tonumber(level) or 1) - 1, 0, SkillTree.MAX_POINTS)
end

-- v1.5: which paths a dino sees
function SkillTree.seesPath(p, dino)
	if type(p) == "string" then p = SkillTree.PATHS[p] end
	if not p then return false end
	if dino == nil then return true end
	if p.dino == "none" then return false end
	if dino == "All" then return true end
	if p.dino == nil then return not (p.notFor and p.notFor[dino]) end
	return p.dino == dino
end

function SkillTree.pathsFor(areaId, dino)
	local shared, own = {}, {}
	for _, a in ipairs(SkillTree.AREAS) do
		if a.id == areaId then
			for _, p in ipairs(a.paths) do
				if SkillTree.seesPath(p, dino) then table.insert(p.dino == nil and shared or own, p) end
			end
		end
	end
	for _, p in ipairs(own) do table.insert(shared, p) end
	return shared
end

-- builds
function SkillTree.sanitize(raw, dino) -- v1.5: + dino
	local clean = {}
	for id, p in pairs(SkillTree.PATHS) do
		local n = type(raw) == "table" and raw[id] or nil
		if type(n) ~= "number" or n ~= n or p.soon or not SkillTree.seesPath(p, dino) then n = 0 end
		clean[id] = math.clamp(math.floor(n), 0, 4)
	end
	return clean
end

function SkillTree.spent(steps, dino) -- v1.5: + dino
	local s = 0
	for _, n in pairs(SkillTree.sanitize(steps, dino)) do
		for i = 1, n do s += SkillTree.COST[i] end
	end
	return s
end

-- v1.5: Mastery 3
function SkillTree.mastered(steps, dino)
	local clean, out = SkillTree.sanitize(steps, dino), {}
	for _, id in ipairs(SkillTree.PATH_ORDER) do
		if (clean[id] or 0) >= 3 then table.insert(out, id) end
	end
	return out
end

function SkillTree.masteryOk(steps, dino)
	return not SkillTree.BUILD_LIMITS or #SkillTree.mastered(steps, dino) <= SkillTree.MASTERY_MAX
end

function SkillTree.canBuy(steps, pathId, pointsEarned, dino) -- v1.5: + dino, otherDino, masteryFull
	local p = SkillTree.PATHS[pathId]
	if not p then return false, "unknownPath" end
	if not SkillTree.seesPath(p, dino) then return false, "otherDino" end
	if p.soon then return false, "soon" end
	local clean = SkillTree.sanitize(steps, dino)
	local n = clean[pathId]
	if n >= 4 then return false, "maxed" end
	if SkillTree.BUILD_LIMITS and n == 2 and #SkillTree.mastered(clean, dino) >= SkillTree.MASTERY_MAX then
		return false, "masteryFull"
	end
	local left = (tonumber(pointsEarned) or 0) - SkillTree.spent(clean, dino)
	if left < SkillTree.COST[n + 1] then return false, "noPoints" end
	return true, "ok"
end

function SkillTree.buy(steps, pathId, pointsEarned, dino) -- v1.5: + dino
	local ok, why = SkillTree.canBuy(steps, pathId, pointsEarned, dino)
	if not ok then return nil, why end
	local new = SkillTree.sanitize(steps, dino)
	new[pathId] += 1
	return new, "ok"
end

-- effects
function SkillTree.effects(steps, dino) -- v1.5: + dino
	local s = SkillTree.sanitize(steps, dino)
	local e = {attackPts = 0, defensePts = 0, speedPts = 0, regenDelay = 0, regenRate = 0, killRegenAdd = 0,
		lifesteal = 0, shieldMax = 0, shieldTime = 0, mainCdMul = 1, moveCdMul = 1, bleedDps = 0, bleedTime = 0,
		crushStun = 0, crushCooldown = 0, tossMul = 1, stunMul = 1, stunImmuneAbove = 0}
	-- Regeneration
	local r = s.regen
	if r >= 1 then e.regenDelay, e.regenRate = 6, 0.02 end
	if r >= 2 then e.regenDelay, e.regenRate = 5, 0.03 end
	if r >= 3 then e.regenDelay, e.regenRate = 4, 0.04 end
	if r >= 4 then e.killRegenAdd = 0.25 end
	-- Lifesteal
	local l = s.lifesteal
	if l >= 1 then e.lifesteal = 0.05 end
	if l >= 2 then e.lifesteal = 0.10 end
	if l >= 3 then e.lifesteal = 0.15 end
	if l >= 4 then e.shieldMax, e.shieldTime = 0.20, 6 end
	-- Jaws (main attack)
	local j = s.jaws
	if j >= 1 then e.attackPts += 1 end
	if j >= 2 then e.mainCdMul = 0.9 end
	if j >= 3 then e.bleedDps, e.bleedTime = 3, 4 end
	if j >= 4 then e.crushStun, e.crushCooldown = 0.75, 4 end
	-- Thick Hide
	local h = s.hide
	if h >= 1 then e.defensePts += 1 end
	if h >= 2 then e.tossMul = 0.5 end
	if h >= 3 then e.stunMul = 0.75 end
	if h >= 4 then e.stunImmuneAbove = 0.5 end
	-- Sprint Legs
	local g = s.legs
	if g >= 1 then e.speedPts += 1 end
	if g >= 2 then e.speedPts += 5 end -- run speed x1.5 (StatServer: +10% per point)
	if g >= 3 then e.moveCdMul = 0.85 end
	if g >= 4 then e.speedPts += 1 end
	-- v1.1: Thrusters
	e.dashCharges, e.dashDist, e.dashHop = 0, 0, 0
	local t = s.thrusters or 0
	if t >= 1 then e.dashCharges, e.dashDist = 1, 35 end
	if t >= 2 then e.dashCharges = 2 end
	if t >= 3 then e.dashDist = 50 end
	if t >= 4 then e.dashHop = 25 end
	-- v1.2: boost length
	e.dashTime = 0
	if t >= 1 then e.dashTime = 1.5 end
	if t >= 3 then e.dashTime = 2.0 end
	-- v1.3: the 35% rule (each step >= 1.35x the step before)
	if SkillTree.STRONG then
		if r >= 2 then e.regenDelay = 4.4 end
		if r >= 3 then e.regenDelay, e.regenRate = 3.2, 0.045 end
		e.attackPts = j >= 1 and 5 or 0
		if j >= 2 then e.mainCdMul = 0.74 end
		e.defensePts = h >= 1 and 6 or 0
		if h >= 3 then e.stunMul = 0.70 end
		e.speedPts = g >= 4 and 16 or g >= 2 and 9 or g >= 1 and 4 or 0
		if g >= 3 then e.moveCdMul = 0.74 end
		if t >= 1 then e.dashTime = 1.0 end -- v1.4 (1.3: 1.5)
		if t >= 3 then e.dashTime = 1.35 end -- v1.4 (1.3: 2.1)
	end
	-- v1.5: Cloak Field
	local c = s.cloak or 0
	e.cloakTime, e.cloakCooldown, e.cloakPounceMul, e.cloakStill = 0, 0, 1, false
	if c >= 1 then e.cloakTime, e.cloakCooldown = 3, 12 end
	if c >= 2 then e.cloakTime = 4.1 end
	if c >= 3 then e.cloakPounceMul = 1.35 end
	if c >= 4 then e.cloakStill = true end
	return e
end

-- v1.1: loadout
local function slottable(clean, id) -- clean = sanitized with the dino (v1.5)
	local p = type(id) == "string" and SkillTree.PATHS[id]
	return p and SkillTree.BUTTONS[id] == true and not p.soon and (clean[id] or 0) >= 1 or false
end

function SkillTree.sanitizeLoadout(raw, steps, dino) -- v1.5: + dino
	local clean = SkillTree.sanitize(steps, dino)
	local out, seen = {}, {}
	for n = 1, SkillTree.SLOTS do
		local id = type(raw) == "table" and raw[n] or nil
		if slottable(clean, id) and not seen[id] then
			out[n], seen[id] = id, true
		else
			out[n] = false
		end
	end
	return out
end

function SkillTree.autoSlot(loadout, steps, pathId, dino) -- v1.5: + dino
	local out = SkillTree.sanitizeLoadout(loadout, steps, dino)
	if not slottable(SkillTree.sanitize(steps, dino), pathId) then return out end
	for n = 1, SkillTree.SLOTS do
		if out[n] == pathId then return out end
	end
	for n = 1, SkillTree.SLOTS do
		if out[n] == false then
			out[n] = pathId
			return out
		end
	end
	return out
end

function SkillTree.setSlot(loadout, steps, n, pathId, dino) -- v1.5: + dino
	if type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > SkillTree.SLOTS then return nil, "badSlot" end
	local out = SkillTree.sanitizeLoadout(loadout, steps, dino)
	if pathId == false or pathId == nil or pathId == "" then
		out[n] = false
		return out, "ok"
	end
	if type(pathId) ~= "string" or not SkillTree.PATHS[pathId] or SkillTree.BUTTONS[pathId] ~= true then
		return nil, "notButton"
	end
	if not slottable(SkillTree.sanitize(steps, dino), pathId) then return nil, "notOwned" end
	for m = 1, SkillTree.SLOTS do
		if out[m] == pathId then out[m] = false end
	end
	out[n] = pathId
	return out, "ok"
end

return SkillTree
