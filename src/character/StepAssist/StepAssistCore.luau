-- StepAssistCore v1.1 (Dino Arcade) — step-up assist shared by the owner client (StepAssist 1.0, player dinos) and the
-- server (StepAssistServer 1.0, bots in DinoIsland.Bots and prey in DinoIsland.Prey).
-- Why (DINO-7 terrain gate, measured in Play): the island is a 16-stud tile grid whose most common step between land
--   tiles is 2 studs (8038 edges; Sand -> Grass 2.4). A Humanoid only got up a step when its HipHeight was about the step
--   height or more: Hatchling T-Rex (HipHeight 1.98) 0 of 6 test steps, raptors below Adult (0.84 / 1.26 / 1.68) 0 of 6,
--   adult raptor (2.10) 3 of 6, adult T-Rex (4.96) 5 of 6. User's answer: step-up assist, for all dinos.
-- Rule, every frame (PreSimulation) per dino:
--   * Active only while: DinoIsland attribute StepAssistEnabled ~= false; HumanoidRootPart not anchored; Humanoid state
--     Running / RunningNoPhysics (on the ground, not jumping / falling / ragdolled / dead); Humanoid.MoveDirection
--     (flat) > MOVE_MIN (it wants to move); not riding a latch (PounceLatched ~= true), not knocked out (DummyState ~=
--     "ko"), not pinned (PinnedAt not set) - those positions belong to PounceServer / BotServer / BiteTargetHealth.
--   * Direction: Humanoid.MoveDirection. Server-driven dinos (opts.walkTo, StepAssistServer): Humanoid:MoveTo on the
--     server leaves MoveDirection at 0 (measured: wandering bots read 0.00), so when it is 0 and no WalkToPart is set,
--     the flat direction to Humanoid.WalkToPoint is used when that point is more than WALKTO_MIN studs away. Players
--     never use WalkToPoint (theirs is unused and points at the origin).
--   * Blocked: flat speed < BLOCK_SPEED_FRAC x WalkSpeed for BLOCK_TIME s in a row.
--   * Ledge search (only when blocked): ground under the HumanoidRootPart = y0 (ray down, DinoIsland.Ground only); rays
--     down at PROBE_STEP .. PROBE_REACH studs ahead along MoveDirection (from StepAssistMax + 1 above y0); the first
--     hit higher than y0 + STEP_MIN is the ledge when it is at most y0 + StepAssistMax (default 2.6) and flat (normal
--     Y > FLAT_MIN); higher = a wall (no lift, StepAssistState "wall").
--   * Lift: over LIFT_TIME s the HumanoidRootPart (and with it the whole welded / jointed model) rises (ledge - y0 +
--     LIFT_CLEAR) and moves (probe distance where the ledge was found + LIFT_PAST, at most PROBE_REACH) studs along the
--     direction, so the HumanoidRootPart ends over the ledge, vertical velocity held at 0; then COOLDOWN s before the
--     next lift. Legs, joints and animation are untouched. (A fixed 0.6-stud nudge left a server-walked 0.4 raptor
--     1.06 studs short of the face: it dropped back and needed a second lift.)
--   * Repeat guard: a new lift within REPEAT_TIME s of the last one and less than REPEAT_DIST studs (flat) from where
--     that one started is skipped (StepAssistState "stuck"; something else, e.g. a tree trunk, is in the way).
-- Diagnostics (model attributes, written by whoever runs it): StepAssistState ("idle" / "blocked" / "lift" / "wall" /
--   "off" / "stuck"), StepAssistCount, StepAssistLastHeight (studs lifted), StepAssistLastAt (server time), StepAssistWalls.
-- v1.1 (walkable mountain steps, MDA-398, plan docs/plans/HARDPOINT_v1.0.md Task 3; Kepu 2026-11-10: "Fix the seven stud steps
--   to be walkable", everywhere: players and bots, Sandbox and Arena). Measured before: a raptor walking at the summit stopped at
--   the first 7-stud Workspace.DinoIsland.MountainSteps shelf (the rays only hit DinoIsland.Ground). While the DinoIsland
--   attribute StepAssistMountainEnabled ~= false (default on):
--   * the rays also hit DinoIsland.MountainSteps;
--   * a ledge may be up to StepAssistMountainMax (DinoIsland attribute, default MOUNTAIN_MAX 17.5: measured in Play, the first
--     shelf on the summit's east side is 13 studs over the rock at its foot, the cliff bands are 14, and the T-Rex stopped at
--     a 16-stud face under the top at 14.5) when the ledge is a
--     MountainSteps part or the dino stands on one (shelf -> rock top); every other ledge keeps StepAssistMax;
--   * mountain ledges are looked for up to the dino's own reach (half its longest flat size + 2, 4..MOUNTAIN_REACH_MAX 34
--     studs): a scaled raptor stood 5.5 studs short of the face (its hitboxes touch first), past PROBE_REACH 4; the lift then
--     moves it forward that far. Any other ledge is still only looked for up to PROBE_REACH;
--   * a thin trail step (Workspace.DinoIsland.MountainSteps.TrailSteps, tools/mountain_steps_trail_v1_1, 2.5 deep: a body
--     doesn't fit on it, measured: a raptor lifted onto one fell back off) is a hand-hold: the ledge search looks up to
--     TRAIL_LOOK (12) studs past it for the rock top and, when that is at most StepAssistMountainMax above the step (and at most
--     2 x that above the dino), lifts straight onto the rock (a mantle);
--   * the lift takes LIFT_TIME x (height / DEFAULT_MAX), between LIFT_TIME and LIFT_TIME_MAX (0.5 s), so a 7-stud step is a
--     short climb, not a snap.
--   Diagnostic: StepAssistLastMountain (true when the last lift used the mountain rule). Off -> exactly 1.0.
local StepAssistCore = {}

StepAssistCore.Version = "1.1"
StepAssistCore.DEFAULT_MAX = 2.6
StepAssistCore.MOUNTAIN_MAX = 17.5 -- v1.1
local MOUNTAIN_REACH_MAX = 34 -- v1.1
local LIFT_TIME_MAX = 0.5 -- v1.1
local TRAIL_LOOK = 12 -- v1.1
local MOVE_MIN = 0.5
local BLOCK_SPEED_FRAC = 0.25
local BLOCK_TIME = 0.1
local STEP_MIN = 0.3
local PROBE_STEP = 0.5
local PROBE_REACH = 4
local FLAT_MIN = 0.9
local LIFT_TIME = 0.12
local LIFT_CLEAR = 0.15
local LIFT_PAST = 0.4
local COOLDOWN = 0.25
local REPEAT_TIME, REPEAT_DIST = 1.5, 1
local WALKTO_MIN = 6

local RUNNING = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- one state table per dino
-- opts (optional): {walkTo = true} for server-driven dinos (see Direction above)
function StepAssistCore.new(model, hum, hrp, opts)
	return {model = model, hum = hum, hrp = hrp, blockedFor = 0, lift = nil, nextAt = 0, shown = {},
		walkTo = opts ~= nil and opts.walkTo == true}
end

-- v1.1: how far ahead of the root a mountain ledge may be (the dino's own size), measured once per dino
local function reachOf(st)
	if st.reach then return st.reach end
	local ok, size = pcall(function() return st.model:GetExtentsSize() end)
	local r = PROBE_REACH
	if ok and typeof(size) == "Vector3" then r = math.clamp(math.max(size.X, size.Z) / 2 + 2, PROBE_REACH, MOUNTAIN_REACH_MAX) end
	st.reach = r
	return r
end

local function show(st, k, v)
	if st.shown[k] ~= v then
		st.shown[k] = v
		st.model:SetAttribute(k, v)
	end
end

local function settings()
	local island = workspace:FindFirstChild("DinoIsland")
	local ground = island and island:FindFirstChild("Ground")
	local enabled = not island or island:GetAttribute("StepAssistEnabled") ~= false
	local max = island and island:GetAttribute("StepAssistMax")
	if type(max) ~= "number" then max = StepAssistCore.DEFAULT_MAX end
	-- v1.1: the mountain steps
	local steps = island and island:GetAttribute("StepAssistMountainEnabled") ~= false and island:FindFirstChild("MountainSteps") or nil
	local mmax = island and island:GetAttribute("StepAssistMountainMax")
	if type(mmax) ~= "number" then mmax = StepAssistCore.MOUNTAIN_MAX end
	return enabled, max, ground, steps, math.max(max, mmax)
end

local paramsCache = {}
local function paramsFor(ground, steps) -- v1.1: + the MountainSteps folder when the mountain rule is on
	local key = steps and (tostring(ground) .. "|" .. tostring(steps)) or ground
	local p = paramsCache[key]
	if not p then
		p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Include
		p.FilterDescendantsInstances = steps and {ground, steps} or {ground}
		p.RespectCanCollide = true
		paramsCache[key] = p
	end
	return p
end

-- returns ledge height above y0, or nil + reason ("noGround" / "wall" / "none")
-- v1.1: steps / mmax (the MountainSteps folder and the mountain max) when the mountain rule is on; third result = true when
-- the ledge used the mountain rule
local function findLedge(hrp, dir, max, params, steps, mmax, reach)
	local pos = hrp.Position
	local down = workspace:Raycast(pos, Vector3.new(0, -60, 0), params)
	if not down then return nil, "noGround" end
	local y0 = down.Position.Y
	local onSteps = steps ~= nil and down.Instance:IsDescendantOf(steps)
	local probe = steps and 2 * mmax or max -- v1.1: high enough to see a rock top behind a thin trail step
	for s = PROBE_STEP, steps and math.max(PROBE_REACH, reach or PROBE_REACH) or PROBE_REACH, PROBE_STEP do
		local origin = Vector3.new(pos.X, y0 + probe + 1, pos.Z) + dir * s
		local hit = workspace:Raycast(origin, Vector3.new(0, -(probe + 1 + STEP_MIN + 0.5), 0), params)
		if hit then
			local h = hit.Position.Y - y0
			if h >= probe + 0.999 then return nil, "wall" end -- the ray started inside / at the top of something tall
			if h > STEP_MIN then
				local mountain = steps ~= nil and (onSteps or hit.Instance:IsDescendantOf(steps))
				if s > PROBE_REACH and not mountain then return nil, "none" end -- v1.1: the long reach is for the mountain only
				local allowed = mountain and mmax or max
				if h <= allowed and hit.Normal.Y > FLAT_MIN then
					-- v1.1: a thin trail step: mantle onto the rock behind it when that is in reach
					local trail = steps ~= nil and hit.Instance.Parent ~= nil and hit.Instance.Parent.Name == "TrailSteps"
					if trail then
						for s2 = s + PROBE_STEP, s + TRAIL_LOOK, PROBE_STEP do
							local o2 = Vector3.new(pos.X, y0 + probe + 1, pos.Z) + dir * s2
							local hit2 = workspace:Raycast(o2, Vector3.new(0, -(probe + 1 + STEP_MIN + 0.5), 0), params)
							if hit2 and not (hit2.Instance.Parent and hit2.Instance.Parent.Name == "TrailSteps") then
								local h2 = hit2.Position.Y - y0
								if h2 > h + STEP_MIN and h2 - h <= mmax and h2 < probe + 0.999 and hit2.Normal.Y > FLAT_MIN then
									return h2, s2, true
								end
								break
							end
						end
					end
					return h, s, mountain and h > max
				end
				return nil, "wall"
			end
		elseif s > PROBE_REACH then
			-- v1.1: beyond the 1.0 reach a miss just means no ledge there
			return nil, "none"
		else
			-- the ray started inside a part taller than max + 1 (no hit from inside): a wall
			local inside = workspace:Raycast(Vector3.new(pos.X, y0 + 0.05, pos.Z) + dir * (s - PROBE_STEP), dir * PROBE_STEP, params)
			if inside then return nil, "wall" end
		end
	end
	return nil, "none"
end

-- call every frame; dt in seconds; now = server time (for the diagnostic)
function StepAssistCore.step(st, dt, now)
	local hum, hrp = st.hum, st.hrp
	local enabled, max, ground, steps, mmax = settings()
	if not enabled or not ground then
		st.lift, st.blockedFor = nil, 0
		show(st, "StepAssistState", "off")
		return
	end
	-- lift in progress
	local l = st.lift
	if l then
		if hrp.Anchored or not hrp.Parent then
			st.lift = nil
			return
		end
		l.t += dt
		local a = math.min(1, l.t / (l.time or LIFT_TIME)) -- v1.1: per-lift time
		local p = l.from + l.dir * (l.nudge * a) + Vector3.new(0, l.dy * a, 0)
		local cur = hrp.Position
		-- keep any sideways / forward motion the Humanoid made this frame, replace the climb part
		hrp.CFrame = CFrame.new(Vector3.new(cur.X + (p.X - l.lastX), p.Y, cur.Z + (p.Z - l.lastZ))) * hrp.CFrame.Rotation
		l.lastX, l.lastZ = p.X, p.Z
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
		if a >= 1 then
			st.lift = nil
			st.nextAt = os.clock() + COOLDOWN
			show(st, "StepAssistState", "idle")
		end
		return
	end
	local want = flat(hum.MoveDirection)
	if want.Magnitude < MOVE_MIN and st.walkTo and hum.WalkToPart == nil then
		local d = flat(hum.WalkToPoint - hrp.Position)
		if d.Magnitude > WALKTO_MIN then want = d.Unit end
	end
	local m = st.model
	if hrp.Anchored or hum.Health <= 0 or not RUNNING[hum:GetState()] or want.Magnitude < MOVE_MIN
		or m:GetAttribute("PounceLatched") == true or m:GetAttribute("DummyState") == "ko" or m:GetAttribute("PinnedAt") ~= nil then
		st.blockedFor = 0
		show(st, "StepAssistState", "idle")
		return
	end
	local speed = flat(hrp.AssemblyLinearVelocity).Magnitude
	if speed >= BLOCK_SPEED_FRAC * math.max(hum.WalkSpeed, 1) then
		st.blockedFor = 0
		show(st, "StepAssistState", "idle")
		return
	end
	st.blockedFor += dt
	if st.blockedFor < BLOCK_TIME or os.clock() < st.nextAt then
		show(st, "StepAssistState", "blocked")
		return
	end
	local dir = want.Unit
	local h, why, viaMountain = findLedge(hrp, dir, max, paramsFor(ground, steps), steps, mmax, steps and reachOf(st) or nil) -- why = probe distance when h is found
	if not h then
		if why == "wall" then
			if st.shown.StepAssistState ~= "wall" then
				st.model:SetAttribute("StepAssistWalls", (st.model:GetAttribute("StepAssistWalls") or 0) + 1)
			end
			show(st, "StepAssistState", "wall")
		else
			show(st, "StepAssistState", "blocked")
		end
		st.nextAt = os.clock() + COOLDOWN
		return
	end
	local from = hrp.Position
	if st.lastFrom and os.clock() - st.lastClock < REPEAT_TIME and flat(from - st.lastFrom).Magnitude < REPEAT_DIST then
		st.nextAt = os.clock() + COOLDOWN
		show(st, "StepAssistState", "stuck")
		return
	end
	st.lastFrom, st.lastClock = from, os.clock()
	st.lift = {t = 0, from = from, dir = dir, dy = h + LIFT_CLEAR, nudge = math.min(why + LIFT_PAST, why > PROBE_REACH and (reachOf(st) + TRAIL_LOOK) or PROBE_REACH),
		lastX = from.X, lastZ = from.Z,
		time = steps and math.clamp(LIFT_TIME * h / StepAssistCore.DEFAULT_MAX, LIFT_TIME, LIFT_TIME_MAX) or LIFT_TIME} -- v1.1
	st.blockedFor = 0
	st.model:SetAttribute("StepAssistCount", (st.model:GetAttribute("StepAssistCount") or 0) + 1)
	st.model:SetAttribute("StepAssistLastHeight", math.floor(h * 100 + 0.5) / 100)
	st.model:SetAttribute("StepAssistLastAt", now)
	if steps then st.model:SetAttribute("StepAssistLastMountain", viaMountain == true) end -- v1.1
	show(st, "StepAssistState", "lift")
end

return StepAssistCore
