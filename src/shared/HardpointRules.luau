-- HardpointRules v1.0 (Mecha Dino Arena) — every Arena Hardpoint number and rule, pure (no Instance writes). MDA-396, plan
-- docs/plans/HARDPOINT_v1.0.md Task 1, ADR-009, mockups docs/mockups/arena_hardpoint_v0.1.html +
-- docs/mockups/hardpoint_point_look_v0.1.html. Kepu 2026-11-10: Call of Duty Hardpoint "but with dinos"; 2 auto-balanced teams;
-- spawns "in relation to the hard point like how call of duty does it"; it is a "point", never a "hill"; layout B · Summit;
-- radius 45; a cloaked dino counts; 250 to win; team wins over squad.
-- Lives in ServerStorage.DinoArcade.HardpointRules; HardpointServer 1.0 clones it to ReplicatedStorage.HardpointShared for
-- clients (the SkillShared pattern). Used by HardpointServer, HardpointPointFX, HardpointHUD and the spec
-- tools/tests/HardpointRules.spec.luau.
-- Numbers (CoD Black Ops 6 where it has one): FIRST 5 s before point 1 opens; POINT_TIME 60 s per point; NEXT_SHOWN 10 s (the
--   next point shows LOCKED); LIMIT 250; CLOCK 600 s (runs only while nobody is on the point); RESULTS 15 s; TICK 0.25 s
--   (occupancy check); RADIUS 45 (flat), DY 40 (vertical) for "on the point".
-- Spawns: RING_DIRS 12 directions round the current point, the first of RING_RADII that is good ground; a spot within
--   NEAR_ENEMY 150 of a living enemy is skipped; score = min(enemy distance, ENEMY_CAP 350) + MATE_W 0.4 x max(0, MATE_RANGE
--   300 - nearest teammate distance); the best wins (first one on a tie).
-- Teams: pickTeam (one joiner) and assignGroups (match start, squads as groups); MAX_GAP 2.
-- API:
--   phaseAt(elapsed, n) -> {warmup, index, into, remaining, nextIndex, showNext}   (index / nextIndex 1-based)
--   occupancy(nA, nB) -> "N" | "A" | "B" | "C"
--   inPoint(root: Vector3, centre: Vector3) -> bool
--   newState() -> {scoreA = 0, scoreB = 0, clock = CLOCK, carryA = 0, carryB = 0}
--   step(state, occ, dt) -> state (a new table; the input is not changed)
--   winner(state) -> "A" | "B" | "draw" | nil
--   pickTeam(nA, nB, scoreA, scoreB, squadTeam?) -> "A" | "B"
--   assignGroups(groups: {{id, n}}) -> {[id] = {A = a, B = b}}
--   ringSpots(centre: Vector3, okFn(Vector3) -> Vector3?) -> {Vector3}
--   pickSpawn(spots, enemies: {Vector3}, mates: {Vector3}) -> Vector3?
local M = {}
M.VERSION = "1.0"

M.RADIUS = 45
M.DY = 40
M.FIRST = 5
M.POINT_TIME = 60
M.NEXT_SHOWN = 10
M.LIMIT = 250
M.CLOCK = 600
M.RESULTS = 15
M.TICK = 0.25
M.RING_DIRS = 12
M.RING_RADII = {300, 260, 340, 220, 380}
M.NEAR_ENEMY = 150
M.ENEMY_CAP = 350
M.MATE_RANGE = 300
M.MATE_W = 0.4
M.MAX_GAP = 2

-- layout B · Summit (Kepu 2026-11-10 "I like B"); studs, x east, z south; the ground height is found by the server
M.LAYOUT_B = {
	{name = "Centre Meadow", x = -100, z = -40},
	{name = "East Shore", x = 450, z = 150},
	{name = "Summit", x = 285, z = -240},
	{name = "NW Foothills", x = -280, z = -270},
	{name = "West Meadow", x = -450, z = 270},
}

function M.phaseAt(elapsed, n)
	elapsed = math.max(0, tonumber(elapsed) or 0)
	n = math.max(1, math.floor(tonumber(n) or 1))
	if elapsed < M.FIRST then
		return {warmup = true, index = 1, into = 0, remaining = M.FIRST - elapsed, nextIndex = 1, showNext = true}
	end
	local live = elapsed - M.FIRST
	local k = math.floor(live / M.POINT_TIME)
	local into = live - k * M.POINT_TIME
	return {
		warmup = false,
		index = k % n + 1,
		into = into,
		remaining = M.POINT_TIME - into,
		nextIndex = (k + 1) % n + 1,
		showNext = into >= M.POINT_TIME - M.NEXT_SHOWN,
	}
end

function M.occupancy(nA, nB)
	local a, b = (tonumber(nA) or 0) > 0, (tonumber(nB) or 0) > 0
	if a and b then
		return "C"
	elseif a then
		return "A"
	elseif b then
		return "B"
	end
	return "N"
end

function M.inPoint(root, centre)
	if typeof(root) ~= "Vector3" or typeof(centre) ~= "Vector3" then return false end
	local dx, dz = root.X - centre.X, root.Z - centre.Z
	return dx * dx + dz * dz <= M.RADIUS * M.RADIUS and math.abs(root.Y - centre.Y) <= M.DY
end

function M.newState()
	return {scoreA = 0, scoreB = 0, clock = M.CLOCK, carryA = 0, carryB = 0}
end

-- whole seconds held in a row score; a team's carried fraction is dropped when it stops holding alone
function M.step(s, occ, dt)
	dt = math.max(0, tonumber(dt) or 0)
	local r = {scoreA = s.scoreA, scoreB = s.scoreB, clock = s.clock, carryA = s.carryA, carryB = s.carryB}
	if occ == "A" then
		r.carryA += dt
		local whole = math.floor(r.carryA + 1e-9)
		r.scoreA = math.min(M.LIMIT, r.scoreA + whole)
		r.carryA = math.max(0, r.carryA - whole)
	else
		r.carryA = 0
	end
	if occ == "B" then
		r.carryB += dt
		local whole = math.floor(r.carryB + 1e-9)
		r.scoreB = math.min(M.LIMIT, r.scoreB + whole)
		r.carryB = math.max(0, r.carryB - whole)
	else
		r.carryB = 0
	end
	if occ == "N" then
		r.clock = math.max(0, r.clock - dt)
	end
	return r
end

function M.winner(s)
	if s.scoreA >= M.LIMIT then return "A" end
	if s.scoreB >= M.LIMIT then return "B" end
	if s.clock <= 0 then
		if s.scoreA > s.scoreB then return "A" end
		if s.scoreB > s.scoreA then return "B" end
		return "draw"
	end
	return nil
end

local function smaller(nA, nB, scoreA, scoreB)
	if nA ~= nB then return nA < nB and "A" or "B" end
	if scoreA ~= scoreB then return scoreA < scoreB and "A" or "B" end
	return "A"
end

function M.pickTeam(nA, nB, scoreA, scoreB, squadTeam)
	nA, nB = tonumber(nA) or 0, tonumber(nB) or 0
	scoreA, scoreB = tonumber(scoreA) or 0, tonumber(scoreB) or 0
	if squadTeam == "A" or squadTeam == "B" then
		local mine, other = (squadTeam == "A" and nA or nB) + 1, squadTeam == "A" and nB or nA
		if mine - other <= M.MAX_GAP then return squadTeam end
	end
	return smaller(nA, nB, scoreA, scoreB)
end

-- groups (squads; a solo player is a group of 1), largest first, each onto the smaller team; then, while the teams are more
-- than MAX_GAP apart, one member of the biggest group on the bigger team moves across (a split squad)
function M.assignGroups(groups)
	local list = {}
	for i, g in ipairs(groups or {}) do
		table.insert(list, {id = g.id, n = math.max(0, math.floor(tonumber(g.n) or 0)), order = i})
	end
	table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.order < b.order end)
	local out, nA, nB = {}, 0, 0
	for _, g in ipairs(list) do
		local t = nA <= nB and "A" or "B"
		out[g.id] = {A = t == "A" and g.n or 0, B = t == "B" and g.n or 0}
		if t == "A" then nA += g.n else nB += g.n end
	end
	while math.abs(nA - nB) > M.MAX_GAP do
		local from = nA > nB and "A" or "B"
		local to = from == "A" and "B" or "A"
		local best
		for _, g in ipairs(list) do
			if out[g.id][from] > 0 and (not best or out[g.id][from] > out[best.id][from]) then best = g end
		end
		if not best then break end
		out[best.id][from] -= 1
		out[best.id][to] += 1
		if from == "A" then nA -= 1; nB += 1 else nB -= 1; nA += 1 end
	end
	return out
end

function M.ringSpots(centre, okFn)
	local out = {}
	if typeof(centre) ~= "Vector3" or type(okFn) ~= "function" then return out end
	for d = 0, M.RING_DIRS - 1 do
		local a = d / M.RING_DIRS * 2 * math.pi
		for _, r in ipairs(M.RING_RADII) do
			local spot = okFn(Vector3.new(centre.X + math.cos(a) * r, centre.Y, centre.Z + math.sin(a) * r))
			if typeof(spot) == "Vector3" then
				table.insert(out, spot)
				break
			end
		end
	end
	return out
end

local function flat(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function M.pickSpawn(spots, enemies, mates)
	local best, bestScore
	for _, c in ipairs(spots or {}) do
		local de = M.ENEMY_CAP
		local near = false
		if enemies and #enemies > 0 then
			de = math.huge
			for _, e in ipairs(enemies) do de = math.min(de, flat(c, e)) end
			near = de < M.NEAR_ENEMY
		end
		if not near then
			local dm = M.MATE_RANGE
			if mates and #mates > 0 then
				dm = math.huge
				for _, m in ipairs(mates) do dm = math.min(dm, flat(c, m)) end
			end
			local score = math.min(de, M.ENEMY_CAP) + M.MATE_W * math.max(0, M.MATE_RANGE - dm)
			if not bestScore or score > bestScore then best, bestScore = c, score end
		end
	end
	return best
end

return M
