-- PracticeRules v1.0 (Mecha Dino Arena) — every practice-match number and bot decision, pure (no Instance writes). MDA-404,
-- plan docs/plans/PRACTICE_MATCH_v1.0.md Task 0, ADR-010, mockup docs/mockups/practice_match_v0.1.html (v0.2).
-- Kepu 2026-11-10: the Sandbox is a Hardpoint practice match vs bots "for now"; bots with random dinos and loadouts that
--   play the objective, use their abilities and fight each other; direction A (lobby, 5v5); 10% XP (like CoD Mobile); the
--   lobby shows only the parts that work for bots.
-- Lives in ServerStorage.DinoArcade.PracticeRules; PracticeServer 1.0 clones it to ReplicatedStorage.PracticeShared.
-- Numbers: SIZE 5 per team, AUTO_START 20 s, CONE 120 degrees of view, CLIMB_GIVE_UP 25 s (then "hold below"), BOT_LEVEL 30
--   (its skill points spent at random), XP_MUL 0.1. DIFF per difficulty: react (s before the first attack on a new target),
--   sight (studs), abil (chance a ready ability is used, Phase 2+), retreat (backs off when hurt and outnumbered), aimErr
--   (degrees). BOT_LIVE = part ids whose bot entrance exists (Phase 1: none).
-- API:
--   rollBot(rng: Random, used: {[name] = true}, SkillTree, level?, species?) -> {name, species, steps, loadout}
--   pickSide(nA, nB, scoreA, scoreB) -> "A" | "B"        fillRoster(humans, bots, size) -> {A, B, moved, refused}
--   assignRoles(n, rng) -> {role}                        scoreTarget(dist, onPoint, hpFrac) -> number (lower = better)
--   shouldRetreat(hpFrac, mates, foes, diff) -> bool     goalFor(role, centre, nextCentre, home, into, pointTime) -> Vector3
--   wantsAttack(seenFor, dist, reach, cdLeft, diff) -> bool   aimError(rng, diff) -> degrees   diffOf(name) -> DIFF row
local M = {}
M.VERSION = "1.0"

M.SIZE = 5
M.AUTO_START = 20
M.CONE = 120
M.CLIMB_GIVE_UP = 25
M.BOT_LEVEL = 30
M.XP_MUL = 0.1
M.SPECIES = {"Raptor", "TRex", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}
M.NAMES = {"Fang", "Mako", "Rook", "Ember", "Vex", "Grit", "Talon", "Nova", "Bolt", "Sable", "Rex", "Dash", "Quill", "Moss",
	"Jinx", "Onyx", "Pike", "Rusty", "Zed", "Kiwi", "Blaze", "Clank", "Drift", "Echo", "Flint", "Gizmo", "Hex", "Ivy",
	"Jolt", "Knox", "Lumen", "Mortar", "Nyx", "Orbit", "Pixel", "Rivet", "Scrap", "Torque", "Volt", "Wrench", "Yuki", "Zap"}
M.DIFF = {
	Easy = {name = "Easy", react = 0.8, sight = 70, abil = 0.25, retreat = false, aimErr = 14},
	Normal = {name = "Normal", react = 0.5, sight = 90, abil = 0.5, retreat = true, aimErr = 8},
	Hard = {name = "Hard", react = 0.3, sight = 110, abil = 0.85, retreat = true, aimErr = 3},
}
M.BOT_LIVE = {}
local ROLES5 = {"cap", "cap", "def", "hunt", "esc"}
local ROLE_PRIORITY = {"cap", "def", "hunt", "cap", "esc"}

function M.diffOf(name)
	return M.DIFF[name] or M.DIFF.Normal
end

local function shuffle(rng, list)
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- a bot: species (given or random), an unused name, its level's points spent at random with its button parts first
function M.rollBot(rng, used, SkillTree, level, species)
	used = used or {}
	species = species or M.SPECIES[rng:NextInteger(1, #M.SPECIES)]
	local free = {}
	for _, n in ipairs(M.NAMES) do if not used[n] then table.insert(free, n) end end
	local name
	if #free > 0 then
		name = free[rng:NextInteger(1, #free)]
	else
		local k = 2
		repeat name = M.NAMES[rng:NextInteger(1, #M.NAMES)] .. k; k += 1 until not used[name]
	end
	used[name] = true
	local points = SkillTree.pointsOf(level or M.BOT_LEVEL)
	local steps = SkillTree.sanitize({}, species)
	-- the dino's live button parts, random order; the first SLOTS get step 1 first
	local buttons = {}
	for id in pairs(SkillTree.BUTTONS) do
		local p = SkillTree.PATHS[id]
		if p and SkillTree.LIVE_MECH[id] and not p.soon and SkillTree.seesPath(p, species) then table.insert(buttons, id) end
	end
	table.sort(buttons)
	buttons = shuffle(rng, buttons)
	local slotted = {}
	for _, id in ipairs(buttons) do
		if #slotted >= SkillTree.SLOTS then break end
		local new = SkillTree.buy(steps, id, points, species)
		if new then steps = new; table.insert(slotted, id) end
	end
	-- the rest at random over every path it may buy
	local ids = {}
	for _, id in ipairs(SkillTree.PATH_ORDER) do
		if SkillTree.seesPath(id, species) then table.insert(ids, id) end
	end
	for _ = 1, 200 do
		local can = {}
		for _, id in ipairs(ids) do
			if SkillTree.canBuy(steps, id, points, species) then table.insert(can, id) end
		end
		if #can == 0 then break end
		steps = SkillTree.buy(steps, can[rng:NextInteger(1, #can)], points, species)
	end
	local loadout = {}
	for n = 1, SkillTree.SLOTS do loadout[n] = false end
	for n, id in ipairs(slotted) do
		local out = SkillTree.setSlot(loadout, steps, n, id, species)
		if out then loadout = out end
	end
	return {name = name, species = species, steps = steps, loadout = loadout}
end

function M.pickSide(nA, nB, scoreA, scoreB)
	nA, nB = tonumber(nA) or 0, tonumber(nB) or 0
	if nA ~= nB then return nA < nB and "A" or "B" end
	scoreA, scoreB = tonumber(scoreA) or 0, tonumber(scoreB) or 0
	if scoreA ~= scoreB then return scoreA < scoreB and "A" or "B" end
	return "A"
end

-- humans: {{id, want = "A" | "B" | "auto"}} in join order; bots: {bot spec}. A human whose side is full goes to the other
-- side (moved[id] = true); with both full: refused[id] = "full". Bots fill A then B up to size.
function M.fillRoster(humans, bots, size)
	size = size or M.SIZE
	local out = {A = {}, B = {}, moved = {}, refused = {}}
	for _, h in ipairs(humans or {}) do
		local want = h.want
		if want ~= "A" and want ~= "B" then want = M.pickSide(#out.A, #out.B, 0, 0) end
		local other = want == "A" and "B" or "A"
		if #out[want] < size then
			table.insert(out[want], {kind = "human", id = h.id})
		elseif #out[other] < size then
			table.insert(out[other], {kind = "human", id = h.id})
			out.moved[h.id] = true
		else
			out.refused[h.id] = "full"
		end
	end
	local i = 1
	for _, side in ipairs({"A", "B"}) do
		while #out[side] < size and bots and bots[i] do
			table.insert(out[side], {kind = "bot", bot = bots[i]})
			i += 1
		end
	end
	return out
end

function M.assignRoles(n, rng)
	n = math.max(0, math.floor(tonumber(n) or 0))
	local list = {}
	if n >= 5 then
		list = table.clone(ROLES5)
		for _ = 6, n do table.insert(list, "cap") end
	else
		for i = 1, n do list[i] = ROLE_PRIORITY[i] end
	end
	return shuffle(rng, list)
end

function M.scoreTarget(dist, onPoint, hpFrac)
	return (tonumber(dist) or 0) - (onPoint and 60 or 0) + (tonumber(hpFrac) or 1) * 30
end

function M.shouldRetreat(hpFrac, mates, foes, diff)
	return diff ~= nil and diff.retreat == true and (tonumber(hpFrac) or 1) < 0.3 and (tonumber(foes) or 0) > (tonumber(mates) or 0) + 1
end

-- home = where the bot's team is (its own spot or the team's average); the goal is placed relative to it
function M.goalFor(role, centre, nextCentre, home, into, pointTime)
	if role == "esc" and nextCentre and (tonumber(into) or 0) > (tonumber(pointTime) or 60) - 10 then return nextCentre end
	local d = Vector3.new((home or centre).X - centre.X, 0, (home or centre).Z - centre.Z)
	if d.Magnitude < 1e-3 then d = Vector3.new(-1, 0, 0) else d = d.Unit end
	local perp = Vector3.new(-d.Z, 0, d.X)
	if role == "def" then
		return centre + d * 35
	elseif role == "hunt" then
		return centre - d * 120 + perp * 80
	elseif role == "esc" then
		return centre + d * 20 + perp * 25
	end
	return centre + d * 8
end

function M.wantsAttack(seenFor, dist, reach, cdLeft, diff)
	return diff ~= nil and (tonumber(seenFor) or 0) >= diff.react and (tonumber(dist) or math.huge) <= (tonumber(reach) or 0)
		and (tonumber(cdLeft) or 0) <= 0
end

function M.aimError(rng, diff)
	local e = diff and diff.aimErr or 8
	return (rng:NextNumber() * 2 - 1) * e
end

return M
