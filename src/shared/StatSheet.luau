-- StatSheet v1.2 (Mecha Dino Arena) — the 5-stat point sheet: species starting points (natural build type) and the
-- stat -> attribute formula. MDA-1, plan docs/plans/CLASSSTATS_v1.0.md, ADR-001. Pure: no Instance access.
-- User: option C "Stat points"; "stamina isnt a tree because stamina is unlimited" (no Stamina stat); Speed alone for
--   Roamer. Red-team answers: the cap is on ADDED points (+10 per stat); Health and Attack points are flat (same gain on
--   every dino); Defense and Speed are percentages. Per-point values are placeholders until the stat trees (part 3).
-- Stats: Health, Attack, Defense, Speed, Support (Support has no effect until squads; its added points are always 0).
-- added(species, raw) -> added {[stat] = int}, clampedAny: raw[stat] floored; a non-number, NaN or negative value -> 0;
--   above MAX_ADDED -> MAX_ADDED; Support -> 0. clampedAny is true when any raw value had to be changed by those rules
--   (flooring alone does not count). Unknown species -> nil, false.
-- points(species, added) -> {[stat] = start + added}, or nil for an unknown species.
-- values(base, added) -> {[attribute] = value} for the keys present in base, plus StatDamageTakenMul:
--   MaxHealth = base + HEALTH_PER_POINT x Health; attack keys = base + ATTACK_PER_POINT[key] x Attack;
--   speed keys = round to 0.1 of base x (1 + SPEED_RATE x Speed); StatDamageTakenMul = round to 0.01 of
--   1 - DEFENSE_RATE x Defense. With 0 added every value equals base exactly.
-- v1.1 (MDA-34; Kepu 2026-10-28: every skill step at least 35% over the one before; Sprint Legs star "Raise the cap: x2.6
--   run"): MAX_ADDED_BY = {Speed = 16}: the added cap per stat (others keep MAX_ADDED 10). Speed 16 = run x2.6.
-- v1.2 (MDA-117, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 2): SPECIES.Pachy (class "Bruiser", start Health 5 /
--   Attack 6 / Defense 5 / Speed 7 / Support 1, abilities "Headbutt charge", "Leap"), so StatServer applies the arena
--   speed scale and stat points to the pachy (unknown species -> "noSheet"). ATTACK_PER_POINT.HeadbuttDamage 2 and
--   ATTACK_KEYS + "HeadbuttDamage" (only characters that have the attribute are affected: the T-Rex and raptor don't).
local StatSheet = {}
StatSheet.Version = "1.2"
StatSheet.STATS = {"Health", "Attack", "Defense", "Speed", "Support"}
StatSheet.MAX_ADDED = 10
StatSheet.MAX_ADDED_BY = {Speed = 16} -- v1.1
StatSheet.HEALTH_PER_POINT = 15
StatSheet.ATTACK_PER_POINT = {BiteDamage = 2, PounceLandDamage = 2, PounceTickDamage = 1}
StatSheet.ATTACK_PER_POINT.HeadbuttDamage = 2 -- v1.2
StatSheet.SPEED_RATE = 0.10
StatSheet.DEFENSE_RATE = 0.05
StatSheet.ATTACK_KEYS = {"BiteDamage", "PounceLandDamage", "PounceTickDamage"}
table.insert(StatSheet.ATTACK_KEYS, "HeadbuttDamage") -- v1.2
StatSheet.SPEED_KEYS = {"MoveWalkSpeed", "MoveRunSpeed", "MoveCreepSpeed"}
StatSheet.SPECIES = {
	TRex = {class = "Bulky", start = {Health = 9, Attack = 7, Defense = 7, Speed = 4, Support = 1}, abilities = {"Roar", "Ram"}},
	Raptor = {class = "Roamer", start = {Health = 3, Attack = 4, Defense = 3, Speed = 9, Support = 1},
		abilities = {"Pounce + latch", "Jump"}},
}
StatSheet.SPECIES.Pachy = {class = "Bruiser", start = {Health = 5, Attack = 6, Defense = 5, Speed = 7, Support = 1},
	abilities = {"Headbutt charge", "Leap"}} -- v1.2

local function roundTo(x, step)
	return math.floor(x / step + 0.5) * step
end

function StatSheet.added(species, raw)
	if StatSheet.SPECIES[species] == nil then return nil, false end
	raw = type(raw) == "table" and raw or {}
	local out, clamped = {}, false
	for _, s in ipairs(StatSheet.STATS) do
		local v = raw[s]
		local n
		if v == nil then
			n = 0
		elseif type(v) ~= "number" or v ~= v or v < 0 then
			n, clamped = 0, true
		else
			n = math.floor(v)
			local cap = StatSheet.MAX_ADDED_BY[s] or StatSheet.MAX_ADDED -- v1.1: per-stat cap
			if n > cap then n, clamped = cap, true end
		end
		if s == "Support" and n ~= 0 then n, clamped = 0, true end
		out[s] = n
	end
	return out, clamped
end

function StatSheet.points(species, added)
	local sp = StatSheet.SPECIES[species]
	if sp == nil then return nil end
	local out = {}
	for _, s in ipairs(StatSheet.STATS) do out[s] = sp.start[s] + ((added and added[s]) or 0) end
	return out
end

function StatSheet.values(base, added)
	added = added or {}
	local h, a, d, sp = added.Health or 0, added.Attack or 0, added.Defense or 0, added.Speed or 0
	local out = {}
	if type(base.MaxHealth) == "number" then out.MaxHealth = base.MaxHealth + StatSheet.HEALTH_PER_POINT * h end
	for _, k in ipairs(StatSheet.ATTACK_KEYS) do
		if type(base[k]) == "number" then out[k] = base[k] + StatSheet.ATTACK_PER_POINT[k] * a end
	end
	for _, k in ipairs(StatSheet.SPEED_KEYS) do
		if type(base[k]) == "number" then
			out[k] = sp == 0 and base[k] or roundTo(base[k] * (1 + StatSheet.SPEED_RATE * sp), 0.1)
		end
	end
	out.StatDamageTakenMul = d == 0 and 1 or roundTo(1 - StatSheet.DEFENSE_RATE * d, 0.01)
	return out
end

return StatSheet
