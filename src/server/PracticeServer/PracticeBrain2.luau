-- PracticeBrain2 v2.0 (Mecha Dino Arena) — practice bots that move and fight like players (ModuleScript, child of PracticeServer).
-- MDA-469, plan docs/plans/BOTS_V2_v1.0.md T4 + T5; Kepu 2026-11-11 20:39 "The bots are still dumb … Bots keep getting stuck …
-- some bots just sit in spawn after a while … Make this a realistic experience versus bots", picks: swim for everyone, mixed tiers
-- 1 Elite · 1 Hard · 2 Normal · 1 Easy. PracticeBrain 1.1 stays as it is (PracticeServer 1.7 uses this module while its switch
-- PrBrainV2Enabled is on). Reuses PracticeBrain.ATTACK (each dino's real attack through the servers' BotUse) and
-- PracticeBrain.enemiesOf; decisions from PracticeRules 1.2 (TIERS, slowMul, scoreTarget, canTarget, jobGoal, shouldRetreat,
-- wantsAttack, aimError).
-- step(b, ctx): b = PracticeServer's bot record (model, hrp, hum, species, team, job, target, busy, tier (name)); ctx = the 1.1
--   context plus ctx.tiered = true, ctx.pathBudget = {n} (path computes left this tick, shared), ctx.kit (PracticeKit 1.0 or nil).
--   Per-life state lives in b.v2 (made new whenever b.model changes).
-- Speed (the fix for frozen bots, found in Studio 2026-11-11): while the bot is not busy (no attack / kit move running),
--   Humanoid.WalkSpeed = its run speed at spawn x tier.speedMul / 0.95 x PracticeRules.slowMul(model attributes) every tick
--   (bot-slow loops of 7 scripts now write SlowMul_* / SlowUntil_* for practice bots instead of changing WalkSpeed).
-- Senses: as 1.0 (cone CONE, NEAR 20, line of sight over Ground / MountainSteps / Rocks / Trees, cloak NEAR_CLOAK 15) with
--   sight = tier.sight. A target that leaves sight is chased to where it was last seen for tier.loseTrack s.
-- Targets: the 1.0 score (R.scoreTarget) minus 15 for the current one; tier.focusLow: minus 40 x (1 - its health fraction).
--   Jobs (1.1 canTarget) as before.
-- Movement (nav):
--   * a goal within DIRECT (40) flat studs with a clear knee-high ray, or any goal while no path is known yet -> Humanoid:MoveTo.
--   * further: PathfindingService path (agent radius = half the body width x 0.5 clamped 2..6, height 8, can jump, Costs Water
--     WATER_COST (3): it swims across water (WaterSwim 1.0 / its bot drive) but prefers land), at most ctx.pathBudget computes
--     per tick for all bots, recomputed every REPATH (1.5) s or when the goal moved over 20 studs; waypoints within 5 flat
--     studs are passed; a Jump waypoint jumps.
--   * stuck ladder (no 3 studs of progress while it wants to move): >= 1.2 s side-step (perpendicular to the goal) 1 s and jump;
--     >= 2.5 s a new path and a back-step 8 studs for 0.8 s; >= 5 s b.v2.wantMobility (PracticeKit uses a mobility part) and
--     jump; >= 9 s rescue when no enemy within 140 studs can see it: moved to the next path waypoint (else 20 studs toward the
--     goal, else the nearest dry ground) on the ground (BotRescues + 1, BotLastRescue). Progress resets the ladder.
--     Diagnostics BotStuckStep (0-4), BotStuckCount.
--   * hold below (fix for bots waiting at their spawn): the climb timer for a point goal starts only when the bot is first
--     within CLIMB_NEAR (150) of the point; the best spot is only taken inside that distance (the highest spot for a point over
--     40 studs up); after CLIMB_GIVE_UP (25) s it holds there HOLD_TIME (12) s, then tries again.
-- Fighting (tier micro):
--   * attacks as 1.0 (R.wantsAttack with the tier's react, PracticeBrain.ATTACK[species].fire, aim error from the tier); a tier
--     with lead aims at where the target will be (its velocity x the flat distance / LEAD_SPEED (90)).
--   * melee: stands off at reach x 0.6; tier.strafe orbits the target (perpendicular, side flips every 1.2-2.4 s, ORBIT 8 studs)
--     while within reach + 10.
--   * ranged (Troodon pods, Dilo darts) with tier.kite: keeps KITE_MIN (22) .. KITE_MAX (42) studs, strafing.
--   * tier.dodge: an enemy within 16 studs whose BiteStartedAt / PounceStartedAt / HeadbuttStartedAt / SlashStartedAt is under
--     0.35 s old -> jump + a sideways push of DODGE_PUSH (38) studs / s, at most every DODGE_EVERY (1.4) s.
--   * retreat as 1.0 (R.shouldRetreat with the tier) toward the nearest mate, else the team home.
-- Model attributes: BotState (move / fight / retreat / holdBelow / attack / swim / dead), BotTarget, BotTier, BotStuckStep,
--   BotStuckCount, BotRescues, BotLastRescue, BotDodges, BotLastAttack, BotAttacks, BotSpeedSet.
-- v2.1 (found in the Studio match test 2026-11-11: 38 of 139 stuck-ladder events in 4 min were "hold" bots standing on point 4's
--   hold spot): the objective goal is a ground point (y = the ground) and the root stands about 7 studs above it, so the caller's
--   3D check (goal - root) > 4 kept wantMove on after the bot had arrived; the stuck ladder then made it side-step and hop on the
--   spot. Now nav treats a goal within ARRIVE_FLAT (4) flat studs as arrived (not moving: no stuck ladder, stands). Switch:
--   PracticeServer attribute PrArriveFlatEnabled (default true, read per call; false = 2.0).
-- v2.1 roam (same test, after the fix above: with no target, "hold" bots stood still on their spot up to 18 s and "duel" bots
--   up to 11 s on their hunt spot 145 studs off the point — read as bots sitting): on the objective (not retreat / holdBelow /
--   fight), with no target:
--   * once within ROAM_NEAR (6) flat studs of its job spot for 0.5 s, the bot walks to a random spot ROAM_R x 0.4..1 (4..10)
--     studs around it, a new one every 2.5..4 s (a spot is used only when the ground there is within 4 studs of the ground at
--     the job spot and not water: no walking off the summit); it stops roaming when the job spot moves away (new point / job).
--   * a "duel" bot that has waited DUEL_WAIT (3) s on its hunt spot sweeps to the point centre (counted in model attribute
--     BotSweeps) and roams there until it sees a target or the point moves.
--   Switch: PracticeServer attribute PrRoamEnabled (default true, read per tick; false = the standing above).
-- v2.2 (Kepu 2026-11-12 15:54 "Create specific paths for them to climb when it's time"): when the bot's objective goal is
--   within 60 flat studs of a point higher than PracticeClimb.MIN_Y (40) (the current point, or the next one for a runner) and
--   the bot is not on that point yet, it follows the climb route (PracticeClimb 1.0: the island's trail up the mountain,
--   bottom first): walks to the trail base (or joins the trail where it already is), then tile by tile up (nav with the stuck
--   ladder, no PathfindingService jumps over the step blocks, no hold-below on the way, no parts fired). Fights still come
--   first. BotState "climb", model attribute BotClimbIdx (route tile). Switch: PracticeServer attribute PrClimbRoutesEnabled
--   (default true, read per tick; false = 2.1). Needs the module PracticeServer.PracticeClimb (missing -> 2.1).
--   Leaving early (same test: 2 bots on the Summit by 29 / 37 s, the rest set off when it opened and were still on the trail
--   when it moved): when the next point is high and the current one has PracticeServer attribute PrClimbEarlySec (20) s or
--   less left, a bot whose job is not "hold" climbs to the next point already (holders stay on the current point).
-- v2.3 (Kepu 2026-11-12 17:18 "when we would eliminate all the enemy bots my teammate bots would just stand around right outside
--   the point. Can you make it so the bots when there is no enemies that they prioritize the point"; found: a "guard" bot's
--   spot is PracticeRules.GUARD_RING (45) from the centre = the point's edge (HardpointRules.RADIUS 45), a "duel" bot waits on
--   its hunt spot 145 studs off before it sweeps): while no enemy is alive (PracticeBrain.enemiesOf is empty: every enemy bot
--   dead, no enemy player in play), every bot not retreating goes onto the current point, whatever its job: its goal is a spot
--   RUSH_R x 0.3..1 (6..20) studs from the centre (picked once per point; only where the ground is within 4 studs of the
--   centre's and not water, else the centre), the climb route still takes it up a high point, and it does not leave early
--   for the next point. Then it roams there as 2.1. BotState "rush" ("climb" / "swim" on the way); model attribute
--   BotRushes (count). Ends the moment an enemy is alive again. Switch: PracticeServer attribute PrRushPointEnabled (default
--   true, read per tick; false = 2.2).
-- v2.4 (Kepu 2026-11-12 17:23 "Add that" = feeler rays: "rays out in front of a bot, so it steers around a rock or wall before
--   it gets stuck"): whenever nav walks the bot (straight to a goal, to a path waypoint, or the last-resort walk), it first
--   feels ahead: rays at knee height (feet + FEEL_KNEE 2.5) over Ground / MountainSteps / Rocks / Trees, FEEL_LEN (14) studs
--   (never past the spot it walks to): one from the middle and one from each shoulder (half the body width x 0.8) straight
--   ahead. A hit whose surface faces up (normal Y > FEEL_SLOPE 0.7: ground it can walk up) is ignored. When one is blocked,
--   it tries the directions FEEL_ANGLES (30, 60, 90) degrees to each side (middle ray, same length) and walks the first clear
--   one, the side it chose last first (kept FEEL_KEEP 0.6 s, so it does not wobble); none clear -> walks as before (the stuck
--   ladder takes over). Not used on the climb route (the trail's step blocks would read as walls). Model attributes
--   BotFeelSteers (count of steers started), BotFeel ("clear" / "left" / "right" / "blocked"). Switch: PracticeServer
--   attribute PrFeelersEnabled (default true, read per call; false = 2.3).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local M = {}
M.Version = "2.0"
M.Version = "2.1" -- v2.1 arrive by flat distance
M.Version = "2.2" -- v2.2 climb routes
M.Version = "2.3" -- v2.3 onto the point when no enemy is alive
M.Version = "2.4" -- v2.4 feeler rays
local Climb = nil -- v2.2
do
	local mod = script.Parent and script.Parent:FindFirstChild("PracticeClimb")
	if mod then local ok, c = pcall(require, mod) if ok then Climb = c end end
end
local ARRIVE_FLAT = 4 -- v2.1
local ROAM_NEAR, ROAM_R, DUEL_WAIT = 6, 10, 3 -- v2.1 roam
local RUSH_R = 20 -- v2.3
local FEEL_LEN, FEEL_KNEE, FEEL_SLOPE, FEEL_KEEP = 14, 2.5, 0.7, 0.6 -- v2.4
local FEEL_ANGLES = {30, 60, 90} -- v2.4

local NEAR, NEAR_CLOAK = 20, 15
local DIRECT, REPATH, WATER_COST = 40, 1.5, 3
local CLIMB_NEAR, HOLD_TIME = 150, 12
local ORBIT, KITE_MIN, KITE_MAX = 8, 22, 42
local DODGE_PUSH, DODGE_EVERY, LEAD_SPEED = 38, 1.4, 90
local RANGED = {Troodon = true, Dilo = true}
local ATTACK_STAMPS = {"BiteStartedAt", "PounceStartedAt", "HeadbuttStartedAt", "SlashStartedAt"}

local V1 -- PracticeBrain (1.1), given at init
local Bots -- PracticeBots, given at init
local IslandWater

local function now() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m and m:FindFirstChild("HumanoidRootPart") end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Include
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function setup()
	local island = workspace:FindFirstChild("DinoIsland")
	local list, ground = {}, {}
	for _, n in ipairs({"Ground", "MountainSteps", "Rocks", "Trees"}) do
		local f = island and island:FindFirstChild(n)
		if f then
			table.insert(list, f)
			if n ~= "Trees" then table.insert(ground, f) end
		end
	end
	losParams.FilterDescendantsInstances = list
	groundParams.FilterDescendantsInstances = ground
end

local halfCache = setmetatable({}, {__mode = "k"})
local function halfOf(model)
	local h = halfCache[model]
	if h then return h end
	local ok, size = pcall(function() return model:GetExtentsSize() end)
	h = (ok and math.max(size.X, size.Z) or 8) * 0.5
	halfCache[model] = h
	return h
end

local function aliveModel(m)
	if not m or not m.Parent then return false end
	if m:GetAttribute("PracticeBot") == true then return (tonumber(m:GetAttribute("DummyHealth")) or 0) > 0 end
	local hum = m:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function hpFracOf(m)
	if m:GetAttribute("PracticeBot") == true then
		return (tonumber(m:GetAttribute("DummyHealth")) or 0) / math.max(1, tonumber(m:GetAttribute("DummyMaxHealth")) or 1)
	end
	local h = m:FindFirstChildOfClass("Humanoid")
	return h and h.Health / math.max(1, h.MaxHealth) or 1
end

local function gapTo(b, target)
	local r1 = rootOf(target)
	if not r1 then return math.huge end
	return math.max(0, flat(r1.Position - b.hrp.Position).Magnitude - halfOf(b.model) - halfOf(target))
end

local function canSee(fromRoot, target, sight, cone)
	local r1 = rootOf(target)
	if not r1 then return false end
	local d = flat(r1.Position - fromRoot.Position)
	local dist = d.Magnitude
	if dist > sight then return false end
	local cloaked = (tonumber(target:GetAttribute("CloakedUntil")) or 0) > now() or target:GetAttribute("Hidden") == true
	if cloaked and dist > NEAR_CLOAK then return false end
	if dist > NEAR and cone then
		local look = flat(fromRoot.CFrame.LookVector)
		if look.Magnitude > 1e-3 and dist > 1e-3 and look.Unit:Dot(d.Unit) < math.cos(math.rad(cone / 2)) then return false end
	end
	local from = fromRoot.Position + Vector3.new(0, 3, 0)
	return workspace:Raycast(from, (r1.Position + Vector3.new(0, 2, 0)) - from, losParams) == nil
end

local function groundAt(p)
	local hit = workspace:Raycast(Vector3.new(p.X, p.Y + 60, p.Z), Vector3.new(0, -200, 0), groundParams)
	return hit and hit.Position or nil
end

local function setState(m, s)
	if m:GetAttribute("BotState") ~= s then m:SetAttribute("BotState", s) end
end

-- ---------- speed ----------
local function ownSpeed(b, tier, R)
	if b.busy then return end
	local v = b.v2
	if not v.base then v.base = (Bots and Bots.runSpeed(b.model) or b.hum.WalkSpeed) end
	local want = v.base * (tier.speedMul or 0.95) * R.slowMul(b.model:GetAttributes(), now())
	if math.abs(b.hum.WalkSpeed - want) > 0.01 then b.hum.WalkSpeed = want end
	if v.speedShown ~= math.floor(want) then
		v.speedShown = math.floor(want)
		b.model:SetAttribute("BotSpeedSet", v.speedShown)
	end
end

-- ---------- navigation ----------
local function clearLine(b, goal)
	local p = b.hrp.Position + Vector3.new(0, 1, 0)
	local d = goal - b.hrp.Position
	d = Vector3.new(d.X, 0, d.Z)
	if d.Magnitude < 1e-3 then return true end
	if workspace:Raycast(p, d, losParams) then return false end
	if IslandWater then
		local _, dry = IslandWater.dryLine(b.hrp.Position, goal)
		if not dry then return false end
	end
	return true
end

local function computePath(b, goal, ctx)
	local v = b.v2
	if v.pathing then return end
	if ctx.pathBudget and ctx.pathBudget.n <= 0 then return end
	if ctx.pathBudget then ctx.pathBudget.n -= 1 end
	v.pathing, v.pathAt, v.pathGoal = true, os.clock(), goal
	local model = b.model
	task.spawn(function()
		local r = math.clamp(halfOf(model) * 0.5, 2, 6)
		local path = PathfindingService:CreatePath({AgentRadius = r, AgentHeight = 8, AgentCanJump = true, WaypointSpacing = 8,
			Costs = {Water = WATER_COST}})
		local from = b.hrp and b.hrp.Parent and b.hrp.Position
		local ok = from and pcall(function() path:ComputeAsync(from, goal) end)
		if b.v2 == v then
			if ok and path.Status == Enum.PathStatus.Success then
				v.path, v.wp = path:GetWaypoints(), 2
			else
				v.path, v.wp = nil, nil
				v.noPathAt = os.clock()
			end
			v.pathing = false
		end
	end)
end

local function sideOf(b, goal)
	local d = flat(goal - b.hrp.Position)
	if d.Magnitude < 1e-3 then d = flat(b.hrp.CFrame.LookVector) end
	if d.Magnitude < 1e-3 then d = Vector3.new(0, 0, -1) end
	d = d.Unit
	return Vector3.new(-d.Z, 0, d.X), d
end

local function enemySees(b, ctx)
	for _, e in ipairs(V1.enemiesOf(b.team, ctx.bots)) do
		local r1 = rootOf(e)
		if r1 and (r1.Position - b.hrp.Position).Magnitude < 140 then
			local from = r1.Position + Vector3.new(0, 3, 0)
			if workspace:Raycast(from, (b.hrp.Position + Vector3.new(0, 2, 0)) - from, losParams) == nil then return true end
		end
	end
	return false
end

local function rescue(b, goal, ctx)
	if enemySees(b, ctx) then return false end
	local v = b.v2
	local p = b.hrp.Position
	local spot
	if v.path and v.wp and v.path[v.wp + 1] then spot = v.path[v.wp + 1].Position end
	if spot and (spot - p).Magnitude > 60 then spot = nil end
	if not spot then
		local _, dir = sideOf(b, goal)
		local g = groundAt(p + dir * 20)
		if g and not (IslandWater and IslandWater.isWater(g)) then spot = g end
	end
	if not spot and IslandWater then
		local q = IslandWater.nearestDry(p)
		if q then spot = groundAt(q) end
	end
	if not spot then return false end
	local up = b.hrp.Size.Y / 2 + b.hum.HipHeight + 1
	b.model:PivotTo(CFrame.new(spot + Vector3.new(0, up, 0)) * (b.hrp.CFrame - b.hrp.Position))
	b.hrp.AssemblyLinearVelocity = Vector3.zero
	pcall(function() b.hrp:SetNetworkOwner(nil) end)
	b.model:SetAttribute("BotRescues", (b.model:GetAttribute("BotRescues") or 0) + 1)
	b.model:SetAttribute("BotLastRescue", ("%d,%d,%d"):format(p.X, p.Y, p.Z))
	v.path, v.wp = nil, nil
	return true
end

-- v2.1 roam (see the header): goal -> the goal to walk to this tick
local function roam(b, goal, job, ctx)
	local ps = game:GetService("ServerScriptService"):FindFirstChild("PracticeServer")
	if ps and ps:GetAttribute("PrRoamEnabled") == false then return goal end
	local v = b.v2
	local p = b.hrp.Position
	local t = os.clock()
	if v.sweep and v.sweep ~= ctx.index then v.sweep = nil end
	local sweeping = job == "duel" and v.sweep == ctx.index
	local base = sweeping and ctx.centre or goal
	if flat(base - p).Magnitude < ROAM_NEAR then
		v.atSpotSince = v.atSpotSince or t
		if job == "duel" and not sweeping and t - v.atSpotSince > DUEL_WAIT then
			v.sweep, v.atSpotSince, v.roamOff = ctx.index, nil, nil
			b.model:SetAttribute("BotSweeps", (b.model:GetAttribute("BotSweeps") or 0) + 1)
			return ctx.centre
		end
	elseif not v.roamOff or flat(base + v.roamOff - p).Magnitude > ROAM_NEAR + ROAM_R then
		v.atSpotSince, v.roamOff, v.roamNext = nil, nil, nil
	end
	if v.atSpotSince and t - v.atSpotSince > 0.5 then
		if not v.roamNext or t >= v.roamNext then
			v.roamNext = t + 2.5 + math.random() * 1.5
			v.roamOff = nil
			local gb = groundAt(base) or groundAt(p)
			for _ = 1, 4 do
				local a = math.random() * math.pi * 2
				local off = Vector3.new(math.cos(a), 0, math.sin(a)) * (ROAM_R * (0.4 + 0.6 * math.random()))
				local g = gb and groundAt(base + off)
				if g and math.abs(g.Y - gb.Y) < 4 and not (IslandWater and IslandWater.isWater(g)) then
					v.roamOff = Vector3.new(off.X, g.Y - base.Y, off.Z)
					break
				end
			end
		end
		if v.roamOff then return base + v.roamOff end
	end
	return base
end

-- v2.4 feeler rays (see the header): target -> the target to walk to this tick
local function wallHit(o, d)
	local hit = workspace:Raycast(o, d, losParams)
	return hit ~= nil and hit.Normal.Y <= FEEL_SLOPE
end
local function feel(b, target)
	local ps = game:GetService("ServerScriptService"):FindFirstChild("PracticeServer")
	if ps and ps:GetAttribute("PrFeelersEnabled") == false then return target end
	local v, m = b.v2, b.model
	local p = b.hrp.Position
	local to = flat(target - p)
	local dist = to.Magnitude
	if dist < 2 then return target end
	local dir = to.Unit
	local len = math.min(FEEL_LEN, dist)
	local feet = p.Y - b.hrp.Size.Y / 2 - b.hum.HipHeight
	local o = Vector3.new(p.X, feet + FEEL_KNEE, p.Z)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local w = halfOf(m) * 0.8
	local function clear(d, shoulders)
		if wallHit(o, d * len) then return false end
		if shoulders and (wallHit(o + side * w, d * len) or wallHit(o - side * w, d * len)) then return false end
		return true
	end
	local function set(st)
		if m:GetAttribute("BotFeel") ~= st then m:SetAttribute("BotFeel", st) end
	end
	if clear(dir, true) then
		set("clear")
		return target
	end
	local t = os.clock()
	local first = (v.feelSide and v.feelUntil and t < v.feelUntil) and v.feelSide or (math.random() < 0.5 and 1 or -1)
	for _, a in ipairs(FEEL_ANGLES) do
		for _, sgn in ipairs({first, -first}) do
			local r = math.rad(a) * sgn
			local d = Vector3.new(dir.X * math.cos(r) - dir.Z * math.sin(r), 0, dir.X * math.sin(r) + dir.Z * math.cos(r))
			if clear(d, false) then
				if v.feelSide ~= sgn or not v.feelUntil or t >= v.feelUntil then
					m:SetAttribute("BotFeelSteers", (m:GetAttribute("BotFeelSteers") or 0) + 1)
				end
				v.feelSide, v.feelUntil = sgn, t + FEEL_KEEP
				set(sgn > 0 and "left" or "right")
				return Vector3.new(p.X, target.Y, p.Z) + d * len
			end
		end
	end
	set("blocked")
	return target
end

-- wantMove: the bot is trying to get somewhere; returns nothing
local function nav(b, goal, ctx, wantMove, noFeel) -- v2.4: + noFeel (the climb route)
	local v = b.v2
	local p = b.hrp.Position
	local t = os.clock()
	-- v2.1: arrived by flat distance (see the header)
	if wantMove and flat(goal - p).Magnitude < ARRIVE_FLAT then
		local ps = game:GetService("ServerScriptService"):FindFirstChild("PracticeServer")
		if not (ps and ps:GetAttribute("PrArriveFlatEnabled") == false) then wantMove = false end
	end
	-- progress / stuck ladder
	if not wantMove or not v.progP or (p - v.progP).Magnitude > 3 then
		v.progP, v.progAt, v.ladder = p, t, 0
	end
	local stuckFor = wantMove and (t - (v.progAt or t)) or 0
	v.stuckFor = stuckFor
	if v.sideUntil and t < v.sideUntil then
		b.hum:MoveTo(v.sideGoal)
		return
	end
	if stuckFor >= 9 and v.ladder < 4 then
		v.ladder = 4
		b.model:SetAttribute("BotStuckStep", 4)
		if rescue(b, goal, ctx) then v.progP, v.progAt, v.ladder = b.hrp.Position, t, 0 return end
	elseif stuckFor >= 5 and v.ladder < 3 then
		v.ladder = 3
		b.model:SetAttribute("BotStuckStep", 3)
		v.wantMobility = t
		b.hum.Jump = true
	elseif stuckFor >= 2.5 and v.ladder < 2 then
		v.ladder = 2
		b.model:SetAttribute("BotStuckStep", 2)
		v.path, v.wp = nil, nil
		computePath(b, goal, ctx)
		local _, dir = sideOf(b, goal)
		v.sideGoal, v.sideUntil = p - dir * 8, t + 0.8
		b.hum.Jump = true
		b.hum:MoveTo(v.sideGoal)
		return
	elseif stuckFor >= 1.2 and v.ladder < 1 then
		v.ladder = 1
		b.model:SetAttribute("BotStuckStep", 1)
		b.model:SetAttribute("BotStuckCount", (b.model:GetAttribute("BotStuckCount") or 0) + 1)
		local side = sideOf(b, goal)
		v.flip = not v.flip
		v.sideGoal, v.sideUntil = p + side * (v.flip and 10 or -10), t + 1
		b.hum.Jump = true
		b.hum:MoveTo(v.sideGoal)
		return
	elseif stuckFor < 1.2 and (b.model:GetAttribute("BotStuckStep") or 0) ~= 0 then
		b.model:SetAttribute("BotStuckStep", 0)
	end
	if not wantMove then
		b.hum:MoveTo(p)
		return
	end
	local d = flat(goal - p).Magnitude
	if d < 3 then
		b.hum:MoveTo(p)
		v.path, v.wp = nil, nil
		return
	end
	if d <= DIRECT and clearLine(b, goal) then
		v.path, v.wp = nil, nil
		b.hum:MoveTo(noFeel and goal or feel(b, goal)) -- v2.4: + feel
		return
	end
	if (not v.path and not v.pathing and (not v.noPathAt or t - v.noPathAt > 1)) or (v.path and t - (v.pathAt or 0) > REPATH)
		or (v.pathGoal and (v.pathGoal - goal).Magnitude > 20) then
		computePath(b, goal, ctx)
	end
	if v.path and v.wp and v.path[v.wp] then
		local w = v.path[v.wp]
		if flat(w.Position - p).Magnitude < 5 then
			v.wp += 1
			w = v.path[v.wp]
		end
		if w then
			if w.Action == Enum.PathWaypointAction.Jump then b.hum.Jump = true end
			b.hum:MoveTo(noFeel and w.Position or feel(b, w.Position)) -- v2.4: + feel
			return
		end
		v.path, v.wp = nil, nil
	end
	b.hum:MoveTo(noFeel and goal or feel(b, goal)) -- v2.4: + feel
end

-- ---------- attacks ----------
local function face(b, target, R, rng, tier)
	local r1 = rootOf(target)
	if not r1 then return end
	local p = b.hrp.Position
	local aimAt = r1.Position
	if tier.lead then
		local dist = flat(aimAt - p).Magnitude
		aimAt += flat(r1.AssemblyLinearVelocity) * math.clamp(dist / LEAD_SPEED, 0, 0.8)
	end
	local d = flat(aimAt - p)
	if d.Magnitude < 1e-3 then return end
	local yaw = math.rad(R.aimError(rng, tier))
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.lookAt(Vector3.zero, d.Unit)).LookVector
	b.hrp.CFrame = CFrame.lookAt(p, p + Vector3.new(dir.X, 0, dir.Z))
end

local function startAttack(b, target, R, rng, tier)
	local a = V1.ATTACK[b.species]
	if not a or b.busy then return end
	b.busy = true
	setState(b.model, "attack")
	face(b, target, R, rng, tier)
	local model = b.model
	task.spawn(function()
		local ok, res = pcall(a.fire, b, target)
		b.nextAttack = os.clock() + a.cd
		b.busy = false
		if model and model.Parent then
			model:SetAttribute("BotLastAttack", ok and tostring(res) or ("error " .. tostring(res)))
			model:SetAttribute("BotAttacks", (model:GetAttribute("BotAttacks") or 0) + 1)
		end
		if b.hrp and b.hrp.Parent and b.hrp.Anchored then b.hrp.Anchored = false end
	end)
end

local function dodge(b, tier, enemies)
	if not tier.dodge then return false end
	local v = b.v2
	if os.clock() - (v.dodgeAt or 0) < DODGE_EVERY then return false end
	local p = b.hrp.Position
	local t = now()
	for _, e in ipairs(enemies) do
		local r1 = rootOf(e)
		if r1 and (r1.Position - p).Magnitude < 16 then
			for _, k in ipairs(ATTACK_STAMPS) do
				local s = tonumber(e:GetAttribute(k))
				if s and t - s >= 0 and t - s < 0.35 then
					v.dodgeAt = os.clock()
					local side = flat(r1.CFrame.RightVector)
					if side.Magnitude < 1e-3 then side = Vector3.new(1, 0, 0) end
					side = side.Unit * ((v.flip and 1) or -1)
					v.flip = not v.flip
					b.hum.Jump = true
					local vel = b.hrp.AssemblyLinearVelocity
					b.hrp.AssemblyLinearVelocity = Vector3.new(side.X * DODGE_PUSH, math.max(vel.Y, 20), side.Z * DODGE_PUSH)
					b.model:SetAttribute("BotDodges", (b.model:GetAttribute("BotDodges") or 0) + 1)
					return true
				end
			end
		end
	end
	return false
end

local function fightGoal(b, target, tier, a)
	local r1 = rootOf(target)
	local p = b.hrp.Position
	local d = flat(r1.Position - p)
	local dist = d.Magnitude
	local dir = dist > 1e-3 and d.Unit or flat(b.hrp.CFrame.LookVector)
	local perp = Vector3.new(-dir.Z, 0, dir.X)
	local v = b.v2
	if not v.orbitFlipAt or os.clock() > v.orbitFlipAt then
		v.orbitSign = (v.orbitSign == 1) and -1 or 1
		v.orbitFlipAt = os.clock() + 1.2 + math.random() * 1.2
	end
	if RANGED[b.species] and tier.kite then
		local want = r1.Position
		if dist < KITE_MIN then
			want = p - dir * 12
		elseif dist > KITE_MAX then
			want = r1.Position - dir * ((KITE_MIN + KITE_MAX) / 2)
		else
			want = p + perp * 10 * v.orbitSign
		end
		return want
	end
	local reach = a and a.reach or 4
	local stand = r1.Position - dir * math.max(0, reach * 0.6)
	if tier.strafe and gapTo(b, target) <= reach + 10 then
		stand += perp * ORBIT * v.orbitSign
	end
	return stand
end

-- ---------- the tick ----------
function M.step(b, ctx)
	local m = b.model
	if not m or not m.Parent or not b.hrp or not b.hrp.Parent then return end
	if not b.v2 or b.v2.model ~= m then
		b.v2 = {model = m}
		b.target, b.seenSince, b.nextAttack = nil, nil, nil
	end
	local v = b.v2
	local R = ctx.R
	local tier = R.tierOf(b.tier)
	if m:GetAttribute("BotTier") ~= tier.name then m:SetAttribute("BotTier", tier.name) end
	if not aliveModel(m) then
		setState(m, "dead")
		return
	end
	ownSpeed(b, tier, R)
	-- hurt?
	local hp = hpFracOf(m)
	if v.lastHp and hp < v.lastHp - 1e-3 then v.hurtAt = os.clock() end
	v.lastHp = hp
	if b.busy then return end
	if m:GetAttribute("PounceLatched") == true or (tonumber(m:GetAttribute("StunnedUntil")) or 0) > now() then return end
	local p = b.hrp.Position
	local job = ctx.jobs and (b.job or (R.jobOf and R.jobOf(b.species))) or nil
	-- sense
	local enemies = V1.enemiesOf(b.team, ctx.bots)
	local best, bestScore
	local foes, foesNear, mates, matesNear, mateLow = 0, 0, 0, 0, false
	for _, e in ipairs(enemies) do
		local r1 = rootOf(e)
		if r1 then
			local dist = flat(r1.Position - p).Magnitude
			if dist < 80 then foes += 1 end
			if dist < 30 then foesNear += 1 end
			if canSee(b.hrp, e, tier.sight, R.CONE) then
				local onPoint = ctx.centre and ctx.H.inPoint(r1.Position, ctx.centre) or false
				local ehp = hpFracOf(e)
				local s = R.scoreTarget(dist, onPoint, ehp)
				if e == b.target then s -= 15 end
				if tier.focusLow then s -= 40 * (1 - ehp) end
				local allowed = true
				if job and R.canTarget then
					local mine = (e == b.target) and 1 or 0
					local tk = ctx.taken and ctx.taken[b.team] and ctx.taken[b.team][e] or 0
					local dk = ctx.duelTaken and ctx.duelTaken[b.team] and ctx.duelTaken[b.team][e] or 0
					allowed = R.canTarget(job, {dist = dist, dPoint = ctx.centre and flat(r1.Position - ctx.centre).Magnitude or math.huge,
						onPoint = onPoint, takenBy = tk - mine, duelTaken = dk - ((job == "duel") and mine or 0)})
				end
				if allowed and (not bestScore or s < bestScore) then best, bestScore = e, s end
			end
		end
	end
	for _, o in ipairs(ctx.bots) do
		local orr = o ~= b and o.team == b.team and o.model and o.model.Parent and aliveModel(o.model) and rootOf(o.model)
		if orr then
			local dd = (orr.Position - p).Magnitude
			if dd < 80 then mates += 1 end
			if dd < 30 then matesNear += 1 end
			if dd < 60 and hpFracOf(o.model) < 0.5 then mateLow = true end
		end
	end
	-- memory: keep chasing a target that just left sight
	local seen = best ~= nil
	if best then
		v.lastSeenPos, v.lastSeenAt = rootOf(best).Position, os.clock()
		v.sweep, v.atSpotSince = nil, nil -- v2.1 roam: a target ends the sweep
	elseif b.target and aliveModel(b.target) and v.lastSeenAt and os.clock() - v.lastSeenAt < (tier.loseTrack or 3) then
		best = b.target
	end
	if best ~= b.target then
		if job and ctx.taken and ctx.taken[b.team] then
			local tt, dt = ctx.taken[b.team], ctx.duelTaken and ctx.duelTaken[b.team]
			if b.target and tt[b.target] then tt[b.target] -= 1 end
			if best then tt[best] = (tt[best] or 0) + 1 end
			if dt and job == "duel" then
				if b.target and dt[b.target] then dt[b.target] -= 1 end
				if best then dt[best] = (dt[best] or 0) + 1 end
			end
		end
		b.target = best
		b.seenSince = os.clock()
	end
	m:SetAttribute("BotTarget", best and (best:GetAttribute("DisplayName") or best.Name) or "")
	local retreat = R.shouldRetreat(hp, mates, foes, tier)
	local swimming = m:GetAttribute("BotSwimming") == true
	-- dodge
	if dodge(b, tier, enemies) then return end
	-- abilities (PracticeKit), before the move
	local goalForKit
	local kit = ctx.kit
	-- fight
	if best and not retreat then
		local a = V1.ATTACK[b.species]
		local gap = gapTo(b, best)
		local dist = flat(rootOf(best).Position - p).Magnitude
		if kit then
			if kit.think(b, ctx, {target = best, hasTarget = true, gap = gap, dist = dist, hpFrac = hp, foesNear = foesNear,
				matesNear = matesNear, mateLow = mateLow, recentlyHit = v.hurtAt ~= nil and os.clock() - v.hurtAt < 2,
				swimming = swimming, stuckFor = v.stuckFor or 0, onPoint = ctx.centre and ctx.H.inPoint(p, ctx.centre) or false,
				goal = rootOf(best).Position, goalDist = dist, tier = tier}) then return end
		end
		if seen and a and R.wantsAttack(os.clock() - (b.seenSince or os.clock()), gap, a.reach, (b.nextAttack or 0) - os.clock(), tier) then
			startAttack(b, best, R, ctx.rng, tier)
			return
		end
		setState(m, swimming and "swim" or "fight")
		local want = seen and fightGoal(b, best, tier, a) or v.lastSeenPos or rootOf(best).Position
		if job == "guard" and ctx.centre and R.guardClamp then want = R.guardClamp(want, ctx.centre) end
		nav(b, want, ctx, true)
		return
	end
	-- objective
	local goal
	if retreat then
		local nearest, nd
		for _, o in ipairs(ctx.bots) do
			local orr = o ~= b and o.team == b.team and o.model and o.model.Parent and aliveModel(o.model) and rootOf(o.model)
			if orr then
				local d = (orr.Position - p).Magnitude
				if not nd or d < nd then nearest, nd = o, d end
			end
		end
		goal = nearest and rootOf(nearest.model).Position or (ctx.home or p)
		setState(m, "retreat")
	elseif ctx.centre then
		goal = R.goalFor(b.role, ctx.centre, ctx.nextCentre, ctx.home or p, ctx.into, ctx.pointTime)
		if job and R.jobGoal then goal = R.jobGoal(job, ctx.centre, ctx.nextCentre, ctx.home or p) end
		local ps = game:GetService("ServerScriptService"):FindFirstChild("PracticeServer")
		-- v2.3: no enemy alive -> onto the point (see the header)
		local rush = #enemies == 0 and not (ps and ps:GetAttribute("PrRushPointEnabled") == false)
		if rush then
			if v.rushIdx ~= ctx.index then
				v.rushIdx, v.rushOff = ctx.index, Vector3.zero
				local gc = groundAt(ctx.centre)
				for _ = 1, 4 do
					local a = math.random() * math.pi * 2
					local off = Vector3.new(math.cos(a), 0, math.sin(a)) * (RUSH_R * (0.3 + 0.7 * math.random()))
					local g = gc and groundAt(ctx.centre + off)
					if g and math.abs(g.Y - gc.Y) < 4 and not (IslandWater and IslandWater.isWater(g)) then
						v.rushOff = Vector3.new(off.X, g.Y - ctx.centre.Y, off.Z)
						break
					end
				end
			end
			if not v.rushing then
				v.rushing = true
				m:SetAttribute("BotRushes", (m:GetAttribute("BotRushes") or 0) + 1)
			end
			goal = ctx.centre + v.rushOff
		else
			v.rushing = nil
		end
		-- v2.2: climb routes (see the header)
		if Climb and not (ps and ps:GetAttribute("PrClimbRoutesEnabled") == false) then
			local high = nil
			for _, c in ipairs({ctx.centre, ctx.nextCentre}) do
				if not high and typeof(c) == "Vector3" and c.Y > Climb.MIN_Y and flat(goal - c).Magnitude < 60 then high = c end
			end
			local nc = ctx.nextCentre
			local left = (ctx.pointTime or 60) - (ctx.into or 0)
			if not high and not rush and job ~= "hold" and typeof(nc) == "Vector3" and nc.Y > Climb.MIN_Y and nc ~= ctx.centre
				and left <= (tonumber(ps and ps:GetAttribute("PrClimbEarlySec")) or 20) then
				high = nc -- leaving early (see the header)
			end
			if high and not ctx.H.inPoint(p, high) then
				local route = Climb.route(high)
				if route then
					local tgt, idx, jump = Climb.follow(v, p, route)
					if jump then b.hum.Jump = true end
					setState(m, "climb")
					if m:GetAttribute("BotClimbIdx") ~= idx then m:SetAttribute("BotClimbIdx", idx) end
					nav(b, tgt, ctx, true, true) -- v2.4: no feelers on the trail
					return
				end
			end
		end
		v.climbIdx = nil
		local wantsPoint = (goal - ctx.centre).Magnitude < 45
		if wantsPoint and v.goalPoint ~= ctx.index then
			v.goalPoint, v.climbSince, v.bestPos, v.bestScore, v.holdUntil = ctx.index, nil, nil, nil, nil
		end
		if wantsPoint then
			local dd = (p - ctx.centre).Magnitude
			local high = ctx.centre.Y > 40
			if dd <= CLIMB_NEAR then
				v.climbSince = v.climbSince or os.clock()
				local score = high and -p.Y or dd
				if not v.bestScore or score < v.bestScore then v.bestScore, v.bestPos = score, p end
			end
			if v.holdUntil and os.clock() < v.holdUntil and v.bestPos then
				setState(m, "holdBelow")
				nav(b, v.bestPos, ctx, (v.bestPos - p).Magnitude > 4)
				return
			elseif v.holdUntil then
				v.holdUntil, v.climbSince = nil, os.clock()
			end
			if v.climbSince and not ctx.H.inPoint(p, ctx.centre) and os.clock() - v.climbSince > R.CLIMB_GIVE_UP and v.bestPos then
				v.holdUntil = os.clock() + HOLD_TIME
			end
		end
		setState(m, swimming and "swim" or (rush and "rush") or "move") -- v2.3: + rush
		goal = roam(b, goal, job, ctx) -- v2.1
	else
		goal = p
	end
	if kit then
		if kit.think(b, ctx, {hasTarget = false, hpFrac = hp, foesNear = foesNear, matesNear = matesNear, mateLow = mateLow,
			recentlyHit = v.hurtAt ~= nil and os.clock() - v.hurtAt < 2, swimming = swimming, stuckFor = v.stuckFor or 0,
			onPoint = ctx.centre and ctx.H.inPoint(p, ctx.centre) or false, goal = goal, goalDist = flat(goal - p).Magnitude,
			tier = tier, wantMobility = v.wantMobility and os.clock() - v.wantMobility < 3}) then return end
	end
	nav(b, goal, ctx, (goal - p).Magnitude > 4)
end

function M.init(v1, bots)
	V1, Bots = v1, bots
	setup()
	local ok, w = pcall(function()
		return require(game:GetService("ServerStorage"):WaitForChild("DinoArcade"):WaitForChild("IslandWater"))
	end)
	IslandWater = ok and w or nil
end

return M
