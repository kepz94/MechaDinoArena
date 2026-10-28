-- SkillTree v1.0 (Mecha Dino Arena) — skill tree data and maths: areas, paths, step costs, the level curve, buy / respec
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
local SkillTree = {}
SkillTree.Version = "1.0"
SkillTree.COST = {1, 2, 3, 4}
SkillTree.MAX_POINTS = 60
SkillTree.MAX_LEVEL = 61

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

SkillTree.PATHS = {}
SkillTree.PATH_ORDER = {}
for _, a in ipairs(SkillTree.AREAS) do
	for _, p in ipairs(a.paths) do
		p.area = a.id
		SkillTree.PATHS[p.id] = p
		table.insert(SkillTree.PATH_ORDER, p.id)
	end
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

-- builds
function SkillTree.sanitize(raw)
	local clean = {}
	for id, p in pairs(SkillTree.PATHS) do
		local n = type(raw) == "table" and raw[id] or nil
		if type(n) ~= "number" or n ~= n or p.soon then n = 0 end
		clean[id] = math.clamp(math.floor(n), 0, 4)
	end
	return clean
end

function SkillTree.spent(steps)
	local s = 0
	for _, n in pairs(SkillTree.sanitize(steps)) do
		for i = 1, n do s += SkillTree.COST[i] end
	end
	return s
end

function SkillTree.canBuy(steps, pathId, pointsEarned)
	local p = SkillTree.PATHS[pathId]
	if not p then return false, "unknownPath" end
	if p.soon then return false, "soon" end
	local clean = SkillTree.sanitize(steps)
	local n = clean[pathId]
	if n >= 4 then return false, "maxed" end
	local left = (tonumber(pointsEarned) or 0) - SkillTree.spent(clean)
	if left < SkillTree.COST[n + 1] then return false, "noPoints" end
	return true, "ok"
end

function SkillTree.buy(steps, pathId, pointsEarned)
	local ok, why = SkillTree.canBuy(steps, pathId, pointsEarned)
	if not ok then return nil, why end
	local new = SkillTree.sanitize(steps)
	new[pathId] += 1
	return new, "ok"
end

-- effects
function SkillTree.effects(steps)
	local s = SkillTree.sanitize(steps)
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
	return e
end

return SkillTree
