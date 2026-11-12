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
-- v1.1 (spawns v2, MDA-421, plan docs/plans/HARDPOINT_SPAWNS_MARKER_v1.0.md Task 1; Kepu 2026-11-10 23:30 "it starts off way
--   to close to the point and then when I die I'm still pretty close ... Usually you both start an equal distance away to
--   where you can't see each other"; picks "B · Scored ring", 23:41 keep 420–600). Added, 1.0 untouched:
--   Band: BAND_DIRS 24 directions x every BAND_RADII {420, 480, 540, 600} that is good ground; a point with fewer than
--     BAND_MIN_SPOTS 8 also takes BAND_EXTRA_RADII {360, 300}.
--   Respawn score: a spot within MIN_ENEMY 250 (flat) of a living enemy is skipped; score = min(nearest enemy, ENEMY_CAP2
--     600; no enemies = 600) + MATE_W 0.4 x max(0, MATE_RANGE 300 - nearest teammate; none = 300) - SEEN_PEN 400 when an
--     enemy can see it; the best wins (first on a tie). SIGHT_MAX 700: enemies further away are not asked "can you see it"
--     (the server's ray check; constant here so server and spec agree).
--   Opening pair: two band spots at least OPEN_MIN_APART 600 apart (flat), whose flat distances to the point differ by at most
--     OPEN_MAX_DIFF 60, and that can't see each other; the pair furthest apart wins (first found on a tie).
--   Warm-up spot: the spot nearest an anchor that is not taken (takenFn(spot) false); all taken -> the nearest.
--   API: bandSpots(centre, okFn) -> {Vector3}; scoreSpawn(spot, enemies, mates, seen) -> number? (nil = skipped);
--     pickScored(spots, enemies, mates, seenFn(spot) -> bool) -> Vector3?, score?; pickOpening(spots, centre,
--     seesFn(a, b) -> bool) -> Vector3?, Vector3?; pickNear(spots, anchor, takenFn(spot) -> bool) -> Vector3?
-- v1.2 (far spawns + fair start sides, MDA-425, plan docs/plans/HUD_SLIM_SPAWNS_FAR_v1.0.md Task 1; Kepu 2026-11-11 "make the
--   distance even further for spawns", picks "700–900" and "Equal running distance"). Added, 1.0 / 1.1 untouched:
--   Band 2: BAND2_RADII {700, 750, 800, 850, 900}, BAND2_EXTRA_RADII {650, 600} (under BAND_MIN_SPOTS 8); SIGHT_MAX2 1000
--     (enemies this close are ray-checked; 700 would miss an enemy on the point looking out at the band); OPEN_MIN_APART2 900.
--   Start sides by run: two spots at least minApart (default OPEN_MIN_APART2) apart (flat) whose run lengths (runFn(spot) ->
--     studs, nil = no path, the spot is left out) differ by at most maxDiff (default OPEN_RUN_DIFF 60) and that can't see
--     each other; the pair furthest apart wins (first found on a tie).
--   API: bandSpots(centre, okFn, radii?, extraRadii?) (new optional args; nil = BAND_RADII / BAND_EXTRA_RADII as 1.1);
--     pickOpeningByRun(spots, seesFn(a, b) -> bool, runFn(spot) -> number?, minApart?, maxDiff?) -> Vector3?, Vector3?
-- v1.3 (Kepu 2026-11-12 15:48 "have the time multiplied by the amount of teammates in the point. So 1 point per second per
--   teammate only when uncontested ... if there's 4 blue team players in the zone then it's 4 points a second"):
--   stepCount(s, occ, nA, nB, dt) = step with the holding team's time x its count on the point (a bot counts like a player):
--   occ "A" -> step(s, "A", dt x nA), "B" -> dt x nB; contested ("C") and empty ("N") are exactly step. LIMIT stays 250.
--   Switch: M.SCORE_PER_MATE (default true; false = step).
local M = {}
M.VERSION = "1.0"
M.VERSION = "1.1" -- v1.1 spawns v2
M.VERSION = "1.2" -- v1.2 far spawns + start sides by run
M.VERSION = "1.3" -- v1.3 score per teammate on the point
M.SCORE_PER_MATE = true

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

-- v1.3: score per teammate on the point (see the header)
function M.stepCount(s, occ, nA, nB, dt)
	dt = math.max(0, tonumber(dt) or 0)
	if M.SCORE_PER_MATE then
		if occ == "A" then return M.step(s, occ, dt * math.max(1, math.floor(tonumber(nA) or 1))) end
		if occ == "B" then return M.step(s, occ, dt * math.max(1, math.floor(tonumber(nB) or 1))) end
	end
	return M.step(s, occ, dt)
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

-- v1.1: spawns v2 (see the header)
M.BAND_DIRS = 24
M.BAND_RADII = {420, 480, 540, 600}
M.BAND_EXTRA_RADII = {360, 300}
M.BAND_MIN_SPOTS = 8
M.MIN_ENEMY = 250
M.ENEMY_CAP2 = 600
M.SEEN_PEN = 400
M.SIGHT_MAX = 700
M.OPEN_MIN_APART = 600
M.OPEN_MAX_DIFF = 60

function M.bandSpots(centre, okFn, radii, extraRadii) -- v1.2: optional radii / extraRadii (nil = 1.1)
	local out = {}
	if typeof(centre) ~= "Vector3" or type(okFn) ~= "function" then return out end
	local function ring(radii)
		for d = 0, M.BAND_DIRS - 1 do
			local a = d / M.BAND_DIRS * 2 * math.pi
			for _, r in ipairs(radii) do
				local spot = okFn(Vector3.new(centre.X + math.cos(a) * r, centre.Y, centre.Z + math.sin(a) * r))
				if typeof(spot) == "Vector3" then table.insert(out, spot) end
			end
		end
	end
	ring(type(radii) == "table" and radii or M.BAND_RADII)
	if #out < M.BAND_MIN_SPOTS then ring(type(extraRadii) == "table" and extraRadii or M.BAND_EXTRA_RADII) end
	return out
end

local function flatDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function M.scoreSpawn(spot, enemies, mates, seen)
	if typeof(spot) ~= "Vector3" then return nil end
	local de = M.ENEMY_CAP2
	if enemies and #enemies > 0 then
		de = math.huge
		for _, e in ipairs(enemies) do de = math.min(de, flatDist(spot, e)) end
		if de < M.MIN_ENEMY then return nil end
	end
	local dm = M.MATE_RANGE
	if mates and #mates > 0 then
		dm = math.huge
		for _, m in ipairs(mates) do dm = math.min(dm, flatDist(spot, m)) end
	end
	return math.min(de, M.ENEMY_CAP2) + M.MATE_W * math.max(0, M.MATE_RANGE - dm) - (seen and M.SEEN_PEN or 0)
end

function M.pickScored(spots, enemies, mates, seenFn)
	local best, bestScore
	for _, c in ipairs(spots or {}) do
		if M.scoreSpawn(c, enemies, mates, false) ~= nil then
			local seen = type(seenFn) == "function" and seenFn(c) == true
			local score = M.scoreSpawn(c, enemies, mates, seen)
			if score and (not bestScore or score > bestScore) then best, bestScore = c, score end
		end
	end
	return best, bestScore
end

function M.pickOpening(spots, centre, seesFn)
	if typeof(centre) ~= "Vector3" then return nil, nil end
	local list = spots or {}
	local cands = {}
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			local apart = flatDist(a, b)
			if apart >= M.OPEN_MIN_APART and math.abs(flatDist(a, centre) - flatDist(b, centre)) <= M.OPEN_MAX_DIFF then
				table.insert(cands, {a = a, b = b, apart = apart, order = #cands + 1})
			end
		end
	end
	table.sort(cands, function(x, y) if x.apart ~= y.apart then return x.apart > y.apart end return x.order < y.order end)
	for _, c in ipairs(cands) do
		if not (type(seesFn) == "function" and seesFn(c.a, c.b) == true) then return c.a, c.b end
	end
	return nil, nil
end

-- v1.2: band 2 + start sides by run (see the header)
M.BAND2_RADII = {700, 750, 800, 850, 900}
M.BAND2_EXTRA_RADII = {650, 600}
M.SIGHT_MAX2 = 1000
M.OPEN_MIN_APART2 = 900
M.OPEN_RUN_DIFF = 60

function M.pickOpeningByRun(spots, seesFn, runFn, minApart, maxDiff)
	if type(runFn) ~= "function" then return nil, nil end
	local minA = type(minApart) == "number" and minApart or M.OPEN_MIN_APART2
	local maxD = type(maxDiff) == "number" and maxDiff or M.OPEN_RUN_DIFF
	local list, runs = {}, {}
	for _, s in ipairs(spots or {}) do
		local r = runFn(s)
		if typeof(s) == "Vector3" and type(r) == "number" then
			table.insert(list, s)
			table.insert(runs, r)
		end
	end
	local cands = {}
	for i = 1, #list do
		for j = i + 1, #list do
			local apart = flatDist(list[i], list[j])
			if apart >= minA and math.abs(runs[i] - runs[j]) <= maxD then
				table.insert(cands, {a = list[i], b = list[j], apart = apart, order = #cands + 1})
			end
		end
	end
	table.sort(cands, function(x, y) if x.apart ~= y.apart then return x.apart > y.apart end return x.order < y.order end)
	for _, c in ipairs(cands) do
		if not (type(seesFn) == "function" and seesFn(c.a, c.b) == true) then return c.a, c.b end
	end
	return nil, nil
end

function M.pickNear(spots, anchor, takenFn)
	if typeof(anchor) ~= "Vector3" then return nil end
	local best, bestD, any, anyD
	for _, s in ipairs(spots or {}) do
		local d = flatDist(s, anchor)
		if not anyD or d < anyD then any, anyD = s, d end
		if not (type(takenFn) == "function" and takenFn(s) == true) and (not bestD or d < bestD) then best, bestD = s, d end
	end
	return best or any
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
