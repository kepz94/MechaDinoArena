-- PracticeClimb v1.0 (Mecha Dino Arena) — the climb route practice bots follow up the mountain (ModuleScript, child of
-- PracticeServer). Kepu 2026-11-12 15:54 "The boys just don't know how to climb the mountain that's the problem. Create specific
-- paths for them to climb when it's time".
-- Found in Studio 2026-11-12: in a full 60 s on the Summit point (P3, 285,200,-240) no bot stood on it (best height 165 of 200).
--   PathfindingService took 1 250 – 1 400 studs over the 7-stud MountainStep blocks with about 60 jumps (each one slows the bot)
--   and the hold-below rule stopped bots part way. The island has a built trail up the mountain: Ground parts named "Trail"
--   (16-stud tiles, about 2 studs up each) and MountainSteps.TrailSteps, from the base at about (232, 8, 0) to the top
--   (280, 196, -207): 77 tiles, 1 283 studs, no jumps.
-- route(centre) -> {Vector3 (tile tops), bottom first} or nil: the trail tile (Trail or TrailSteps, collidable) nearest the point
--   centre, then each next tile down = the nearest unused tile at most LINK_FLAT (34) flat away that is at most LINK_DOWN (9)
--   lower and at most 1 higher (score flat + drop x 0.5), until none; reversed. nil when the chain has under MIN_TILES (10)
--   tiles or does not reach below the centre by MIN_DROP (60). Cached per centre (rounded).
-- follow(v, pos, route) -> target, index, jump: v (the bot's brain table) keeps v.climbRoute / v.climbIdx. Join: the highest route
--   tile within JOIN_FLAT (24) flat whose top is 3 above .. JOIN_DY + 6 (14) below the bot's root (the same level of the
--   switchbacks); else tile 1 (walk to the trail base first). Each call: while the next tile is no further (flat) than the
--   current one, or the current one is within REACH (10) flat and 3 above .. 16 below the root, move on; off the route (more than OFF_ROUTE (60) flat from the current tile, after the base) -> join again.
-- Studio test 2026-11-12 (route followed): a bot on the trail climbs base -> top in about 25 s; found and fixed: (1) bots near
--   the base never got within REACH of tile 1 (stood 20 – 30 s at y 7 – 21): while on tile 1 the bot joins wherever it reaches
--   the trail; (2) bots stopped 5 – 10 s at the trail's step-ups (tiles rising 4 – 6 studs, StepAssist lifts 2.6): follow also
--   returns jump = true when the target tile rises over STEP_RISE (2.5) from the one before and is within JUMP_NEAR (14) flat.
-- Diagnostics: script attributes PracticeClimbVersion, PracticeClimbRoutes (built), PracticeClimbTiles (last route).
local M = {}
M.VERSION = "1.0"
script:SetAttribute("PracticeClimbVersion", M.VERSION)

M.MIN_Y = 40 -- a point higher than this is climbed by the route
local LINK_FLAT, LINK_DOWN, MIN_TILES, MIN_DROP = 34, 9, 10, 60
local JOIN_FLAT, JOIN_DY, REACH, OFF_ROUTE = 24, 8, 10, 60
local STEP_RISE, JUMP_NEAR = 2.5, 14

local cache = {}

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function tiles()
	local out = {}
	local island = workspace:FindFirstChild("DinoIsland")
	if not island then return out end
	local function add(p)
		if p:IsA("BasePart") and p.CanCollide then
			table.insert(out, Vector3.new(p.Position.X, p.Position.Y + p.Size.Y / 2, p.Position.Z))
		end
	end
	local g = island:FindFirstChild("Ground")
	if g then for _, p in ipairs(g:GetDescendants()) do if p.Name == "Trail" then add(p) end end end
	local ms = island:FindFirstChild("MountainSteps")
	local ts = ms and ms:FindFirstChild("TrailSteps")
	if ts then for _, p in ipairs(ts:GetDescendants()) do add(p) end end
	return out
end

function M.route(centre)
	if typeof(centre) ~= "Vector3" or centre.Y <= M.MIN_Y then return nil end
	local key = string.format("%d,%d,%d", math.floor(centre.X + 0.5), math.floor(centre.Y + 0.5), math.floor(centre.Z + 0.5))
	if cache[key] ~= nil then return cache[key] or nil end
	local all = tiles()
	local cur, cd
	for _, t in ipairs(all) do
		local d = (t - centre).Magnitude
		if not cd or d < cd then cur, cd = t, d end
	end
	local chain = {}
	if cur then
		local used = {[cur] = true}
		chain[1] = cur
		while true do
			local best, bd
			for _, t in ipairs(all) do
				if not used[t] then
					local f = flat(t - cur).Magnitude
					local drop = cur.Y - t.Y
					if f <= LINK_FLAT and drop >= -1 and drop <= LINK_DOWN then
						local s = f + drop * 0.5
						if not bd or s < bd then best, bd = t, s end
					end
				end
			end
			if not best then break end
			used[best] = true
			table.insert(chain, best)
			cur = best
		end
	end
	local ok = #chain >= MIN_TILES and chain[#chain].Y < centre.Y - MIN_DROP
	local route = nil
	if ok then
		route = {}
		for i = #chain, 1, -1 do table.insert(route, chain[i]) end
		script:SetAttribute("PracticeClimbRoutes", (script:GetAttribute("PracticeClimbRoutes") or 0) + 1)
		script:SetAttribute("PracticeClimbTiles", #route)
	end
	cache[key] = route or false
	return route
end

local function join(pos, route)
	local best = nil
	for i, t in ipairs(route) do
		local up = pos.Y - t.Y -- the root stands above the tile top
		if flat(t - pos).Magnitude <= JOIN_FLAT and up >= -3 and up <= JOIN_DY + 6 then best = i end
	end
	return best or 1
end

function M.follow(v, pos, route)
	if v.climbRoute ~= route or not v.climbIdx then
		v.climbRoute, v.climbIdx = route, join(pos, route)
	end
	local i = v.climbIdx
	if i > 1 and flat(route[i] - pos).Magnitude > OFF_ROUTE then
		i = join(pos, route)
	end
	if i == 1 then i = join(pos, route) end -- v1.0 test fix: not on the trail yet -> join wherever it is reached
	while i < #route do
		local here = flat(route[i] - pos).Magnitude
		local nextD = flat(route[i + 1] - pos).Magnitude
		local up = pos.Y - route[i].Y
		local close = here <= REACH and up >= -3 and up <= 16
		if close or (i > 1 and nextD <= here) then i += 1 else break end
	end
	v.climbIdx = i
	-- a step up (rise over STEP_RISE from the tile before) close ahead -> jump
	local rise = i > 1 and (route[i].Y - route[i - 1].Y) or 0
	local jump = rise > STEP_RISE and flat(route[i] - pos).Magnitude <= JUMP_NEAR
	return route[i], i, jump
end

return M
