-- PracticeBrain v1.0 (Mecha Dino Arena) — what a practice bot does every tick: see, pick a target, move, attack, retreat,
-- hold below. MDA-409 + MDA-410, plan docs/plans/PRACTICE_MATCH_v1.0.md Tasks 5-6 (ModuleScript, child of PracticeServer).
-- Decisions come from PracticeRules (pure, tested): roles, target score, retreat, goal, wantsAttack, aimError, DIFF.
-- Senses (like a player, no wall knowledge): an enemy (other-team bot with DummyHealth > 0, or a player character on the other
--   Hardpoint team, alive, out of the menu) is seen when it is within DIFF.sight flat studs AND (inside the CONE in front, or
--   within NEAR (20) studs) AND a ray from the bot's root + 3 to the target root hits no island ground / rock / tree; a cloaked
--   (CloakedUntil in the future) or hidden (Hidden) one only within NEAR_CLOAK (15). Seen time counts from the first tick it was
--   seen; the attack waits DIFF.react s (wantsAttack).
-- Movement: Humanoid:MoveTo. Trips over PATH_MIN (80) studs follow a PathfindingService path (agent radius from the body,
--   recomputed every PATH_EVERY (2) s, straight MoveTo when no path). Unstuck: under STUCK_DIST (2) studs moved in STUCK_TIME
--   (2) s while it wants to move -> a sidestep of 10 studs left / right for 1 s (BotStuckCount + 1); the second in a row also
--   jumps.
-- Hold below (red-team 1, Kepu "Paths + hold below"): a bot whose goal is the current point and is not on it CLIMB_GIVE_UP (25)
--   s after taking that goal goes to the closest spot it reached on the way and holds there (BotState "holdBelow") for 15 s,
--   then tries again.
-- Attacks (the real ones, through each server's BotUse; ADR-010): Troodon pod (TrooAttackServer), Dilo bite / dart
--   (DiloAttackServer), Teno scratch (TenoAttackServer), Therizino cut (TheriAttackServer), T-Rex bite with aimTarget (BiteServer);
--   Raptor pounce (PounceServer request -> lunge here -> claim -> ride while latched -> release), Pachy headbutt (HeadbuttServer
--   request -> charge here -> hit -> end), Herrera dash slash (SlashServer request -> dash here along SlashFrom..SlashTo -> hit).
--   The bot turns to face the target plus aimError degrees first. One attack at a time per bot (busy flag).
-- Per-bot attributes: BotRole, BotState (move / fight / retreat / holdBelow / attack / dead), BotTarget (name or ""),
--   BotStuckCount, BotLastAttack (result), BotAttacks.
-- v1.1 (bot jobs, MDA-431, plan docs/plans/BOT_JOBS_v1.0.md Task 3; Kepu 2026-11-11 pick "C"): while ctx.jobs (PracticeServer
--   1.3, PrJobsEnabled) every bot acts on its job (b.job, else PracticeRules.jobOf(its dino)):
--   * targets: a seen enemy counts only if R.canTarget(job, {dist, dPoint = the enemy from the point centre, onPoint, takenBy =
--     ctx.taken[team][enemy] minus this bot, duelTaken = ctx.duelTaken[team][enemy] minus this bot}) (leash per job, at most
--     MAX_ON_ONE 2 on one enemy, one duelist per enemy, self-defence within 20 always). The 1.0 score picks among those.
--   * walk goal (no target / retreat as 1.0): R.jobGoal(job, centre, nextCentre, home); the 1.0 hold-below still applies to a
--     goal on the point (hold).
--   * a guard's fight move is kept within R.GUARD_LEASH (90) of the point (R.guardClamp).
--   * a target change updates ctx.taken / ctx.duelTaken at once (QA 2026-11-11: two bots could both take an enemy's last free
--     place in the same tick).
--   * fix (the known 1.0 error at line 267, logged 2026-11-11): startAttack's task checks that b.model / b.hrp still exist
--     (the bot can be removed while it attacks).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")

local M = {}
M.Version = "1.0"
M.Version = "1.1" -- v1.1 bot jobs

local NEAR, NEAR_CLOAK = 20, 15
local PATH_MIN, PATH_EVERY = 80, 2
local STUCK_DIST, STUCK_TIME = 2, 2
local HOLD_TIME = 15

local function now() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Include
local function setupLos()
	local island = workspace:FindFirstChild("DinoIsland")
	local list = {}
	for _, n in ipairs({"Ground", "MountainSteps", "Rocks", "Trees"}) do
		local f = island and island:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	losParams.FilterDescendantsInstances = list
end

local function botUse(serverName, ...)
	local s = ServerScriptService:FindFirstChild(serverName)
	local fn = s and s:FindFirstChild("BotUse")
	if not fn then return "noEntrance" end
	local ok, r = pcall(fn.Invoke, fn, ...)
	return ok and r or ("error " .. tostring(r))
end

-- size helpers (cached per model)
local halfCache = setmetatable({}, {__mode = "k"})
local function halfOf(model)
	local h = halfCache[model]
	if h then return h end
	local ok, size = pcall(function() return model:GetExtentsSize() end)
	h = (ok and math.max(size.X, size.Z) or 8) * 0.5
	halfCache[model] = h
	return h
end
local function rootOf(m) return m and m:FindFirstChild("HumanoidRootPart") end

local function aliveModel(m)
	if not m or not m.Parent then return false end
	if m:GetAttribute("PracticeBot") == true then return (tonumber(m:GetAttribute("DummyHealth")) or 0) > 0 end
	local hum = m:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- every enemy of team (bots and players)
function M.enemiesOf(team, bots)
	local list = {}
	for _, b in ipairs(bots) do
		if b.team ~= team and b.model and aliveModel(b.model) then table.insert(list, b.model) end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		local t = pl:GetAttribute("HardpointTeam")
		local c = pl.Character
		if (t == "A" or t == "B") and t ~= team and c and pl:GetAttribute("InMenu") ~= true and aliveModel(c) then table.insert(list, c) end
	end
	return list
end

local function visible(b, target, diff, R)
	local r0, r1 = b.hrp, rootOf(target)
	if not r1 then return false end
	local d = flat(r1.Position - r0.Position)
	local dist = d.Magnitude
	if dist > diff.sight then return false end
	local cloaked = (tonumber(target:GetAttribute("CloakedUntil")) or 0) > now() or target:GetAttribute("Hidden") == true
	if cloaked and dist > NEAR_CLOAK then return false end
	if dist > NEAR then
		local look = flat(r0.CFrame.LookVector)
		if look.Magnitude > 1e-3 and dist > 1e-3 then
			local cos = look.Unit:Dot(d.Unit)
			if cos < math.cos(math.rad(R.CONE / 2)) then return false end
		end
	end
	local from = r0.Position + Vector3.new(0, 3, 0)
	local hit = workspace:Raycast(from, (r1.Position + Vector3.new(0, 2, 0)) - from, losParams)
	return hit == nil
end

-- ---------- attacks ----------
local function face(b, target, R, rng, diff)
	local r1 = rootOf(target)
	if not r1 then return end
	local p = b.hrp.Position
	local d = flat(r1.Position - p)
	if d.Magnitude < 1e-3 then return end
	local yaw = math.rad(R.aimError(rng, diff))
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.lookAt(Vector3.zero, d.Unit)).LookVector
	b.hrp.CFrame = CFrame.lookAt(p, p + Vector3.new(dir.X, 0, dir.Z))
end

local function gapTo(b, target)
	local r1 = rootOf(target)
	if not r1 then return math.huge end
	return math.max(0, flat(r1.Position - b.hrp.Position).Magnitude - halfOf(b.model) - halfOf(target))
end

-- per species: reach (gap studs) and the attack
local ATTACK = {}
ATTACK.Troodon = {reach = 55, cd = 0.6, fire = function(b, target)
	return botUse("TrooAttackServer", b.model, now())
end}
ATTACK.Dilo = {reach = 40, cd = 0.5, fire = function(b, target)
	if gapTo(b, target) <= 4 then return botUse("DiloAttackServer", b.model, "bite", now()) end
	return botUse("DiloAttackServer", b.model, "dart", now())
end}
ATTACK.Teno = {reach = 5, cd = 0.5, fire = function(b, target)
	return botUse("TenoAttackServer", b.model, "scratch", now())
end}
ATTACK.Therizino = {reach = 6, cd = 0.45, fire = function(b, target)
	return botUse("TheriAttackServer", b.model, now())
end}
ATTACK.TRex = {reach = 5, cd = 0.9, fire = function(b, target)
	return botUse("BiteServer", b.model, now(), 0, 0, target)
end}
ATTACK.Raptor = {reach = 18, cd = 1.5, fire = function(b, target)
	local stamp = now()
	local before = b.model:GetAttribute("PounceStartedAt")
	local r = botUse("PounceServer", b.model, "request", stamp)
	if r ~= "ok" or b.model:GetAttribute("PounceStartedAt") == before then return "refused" end
	task.wait(math.clamp(tonumber(b.model:GetAttribute("PounceWindup")) or 0.1, 0, 0.6))
	local hrp, r1 = b.hrp, rootOf(target)
	if not (hrp.Parent and r1) then return "gone" end
	local hb = target:FindFirstChild("Hitboxes")
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = {hb or target}
	local from = hrp.Position
	local dest = r1.Position
	local total = math.clamp((flat(dest - from)).Magnitude, 4, 26)
	local dir = flat(dest - from)
	dir = dir.Magnitude > 1e-3 and dir.Unit or flat(hrp.CFrame.LookVector).Unit
	local speed = 70 * (tonumber(b.model:GetAttribute("BotSpeedScale")) or 1)
	local dur = total / speed
	hrp.Anchored = true
	local t0 = os.clock()
	local claimed
	while os.clock() - t0 < dur + 0.05 and hrp.Parent do
		local a = math.min(1, (os.clock() - t0) / dur)
		local pos = from + dir * total * a + Vector3.new(0, 2.7 * math.sin(math.pi * a), 0)
		hrp.CFrame = CFrame.lookAt(pos, pos + dir)
		local snout = pos + dir * halfOf(b.model) * 0.9
		local parts = workspace:GetPartBoundsInRadius(snout, 3.5, op)
		if #parts > 0 then
			local part = parts[1]
			local off = part.CFrame:ToObjectSpace(hrp.CFrame)
			botUse("PounceServer", b.model, "claim", stamp, part, off)
			if b.model:GetAttribute("PounceLatched") == true then claimed = {part = part, off = off} end
			break
		end
		RunService.Heartbeat:Wait()
	end
	if claimed then
		local t1 = os.clock()
		while b.model.Parent and b.model:GetAttribute("PounceLatched") == true and claimed.part.Parent and os.clock() - t1 < 4 do
			hrp.CFrame = claimed.part.CFrame * claimed.off
			RunService.Heartbeat:Wait()
		end
		if b.model:GetAttribute("PounceLatched") == true then botUse("PounceServer", b.model, "release") end
		hrp.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
	end
	hrp.Anchored = false
	pcall(function() hrp:SetNetworkOwner(nil) end)
	return claimed and "latched" or "missed"
end}
ATTACK.Pachy = {reach = 30, cd = 1.2, fire = function(b, target)
	local stamp = now()
	local before = b.model:GetAttribute("HeadbuttStartedAt")
	local r = botUse("HeadbuttServer", b.model, "request", stamp)
	if r ~= "ok" or b.model:GetAttribute("HeadbuttStartedAt") == before then return "refused" end
	local m = b.model
	task.wait(math.clamp(tonumber(m:GetAttribute("HeadbuttWindup")) or 0.2, 0, 0.8))
	local speed0 = b.hum.WalkSpeed
	b.hum.WalkSpeed = speed0 * (tonumber(m:GetAttribute("HeadbuttSpeedMul")) or 1.4)
	local t0 = os.clock()
	local maxT = math.clamp(tonumber(m:GetAttribute("HeadbuttMaxTime")) or 1.2, 0.3, 3)
	local hit = false
	while os.clock() - t0 < maxT and m.Parent and aliveModel(target) do
		local r1 = rootOf(target)
		if not r1 then break end
		b.hum:MoveTo(r1.Position)
		if gapTo(b, target) <= 3 then
			botUse("HeadbuttServer", m, "hit", stamp, target)
			hit = true
			break
		end
		task.wait(0.05)
	end
	botUse("HeadbuttServer", m, "end", stamp, hit and "ended" or "timeout")
	b.hum.WalkSpeed = speed0
	return hit and "hit" or "missed"
end}
ATTACK.Herrera = {reach = 10, cd = 0.8, fire = function(b, target)
	local stamp = now()
	local m = b.model
	local before = m:GetAttribute("SlashStartedAt")
	local r = botUse("SlashServer", m, "request", stamp, "ground")
	if r ~= "ok" or m:GetAttribute("SlashStartedAt") == before then return "refused" end
	local from, to = m:GetAttribute("SlashFrom"), m:GetAttribute("SlashTo")
	local dur = math.clamp(tonumber(m:GetAttribute("SlashDashTime")) or 0.3, 0.1, 1)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then return "noPath" end
	local hrp = b.hrp
	hrp.Anchored = true
	local t0 = os.clock()
	local hitDone = false
	local dir = flat(to - from)
	dir = dir.Magnitude > 1e-3 and dir.Unit or flat(hrp.CFrame.LookVector)
	while os.clock() - t0 < dur and hrp.Parent do
		local a = math.min(1, (os.clock() - t0) / dur)
		local pos = from:Lerp(to, a)
		hrp.CFrame = CFrame.lookAt(pos, pos + dir)
		if not hitDone and gapTo(b, target) <= 4 then
			botUse("SlashServer", m, "hit", stamp, target)
			hitDone = true
		end
		RunService.Heartbeat:Wait()
	end
	if not hitDone and gapTo(b, target) <= 4 then botUse("SlashServer", m, "hit", stamp, target) hitDone = true end
	hrp.Anchored = false
	pcall(function() hrp:SetNetworkOwner(nil) end)
	return hitDone and "hit" or "missed"
end}
M.ATTACK = ATTACK

local function startAttack(b, target, R, rng, diff)
	local a = ATTACK[b.species]
	if not a or b.busy then return end
	b.busy = true
	b.model:SetAttribute("BotState", "attack")
	face(b, target, R, rng, diff)
	task.spawn(function()
		local ok, res = pcall(a.fire, b, target)
		b.nextAttack = os.clock() + a.cd
		b.busy = false
		if b.model and b.model.Parent then -- v1.1: b.model can be nil after a despawn
			b.model:SetAttribute("BotLastAttack", ok and tostring(res) or ("error " .. tostring(res)))
			b.model:SetAttribute("BotAttacks", (b.model:GetAttribute("BotAttacks") or 0) + 1)
		end
		if b.hrp and b.hrp.Parent and b.hrp.Anchored then b.hrp.Anchored = false end -- v1.1: b.hrp can be nil
	end)
end

-- ---------- movement ----------
local function moveTo(b, goal)
	local p = b.hrp.Position
	local d = flat(goal - p).Magnitude
	if d < 3 then
		b.hum:MoveTo(p)
		b.path, b.wp = nil, nil
		return
	end
	if d > PATH_MIN then
		if (not b.path or os.clock() - (b.pathAt or 0) > PATH_EVERY or (b.pathGoal and (b.pathGoal - goal).Magnitude > 30)) and not b.pathing then
			b.pathing = true
			b.pathAt = os.clock()
			b.pathGoal = goal
			task.spawn(function()
				local r = math.clamp(halfOf(b.model) * 0.5, 2, 8)
				local path = PathfindingService:CreatePath({AgentRadius = r, AgentHeight = 8, AgentCanJump = true, WaypointSpacing = 10})
				local ok = pcall(function() path:ComputeAsync(b.hrp.Position, goal) end)
				if ok and path.Status == Enum.PathStatus.Success then
					b.path, b.wp = path:GetWaypoints(), 2
				else
					b.path, b.wp = nil, nil
				end
				b.pathing = false
			end)
		end
		if b.path and b.wp and b.path[b.wp] then
			local w = b.path[b.wp].Position
			if flat(w - p).Magnitude < 6 then
				b.wp += 1
				w = b.path[b.wp] and b.path[b.wp].Position or goal
			end
			b.hum:MoveTo(w)
			return
		end
	end
	b.hum:MoveTo(goal)
end

local function unstuck(b, wantMove)
	local p = b.hrp.Position
	if not wantMove then b.lastPos, b.lastPosAt = p, os.clock() return false end
	if not b.lastPos or (p - b.lastPos).Magnitude > STUCK_DIST then
		b.lastPos, b.lastPosAt = p, os.clock()
		b.stuckRow = 0
		return false
	end
	if os.clock() - b.lastPosAt < STUCK_TIME then return false end
	b.stuckRow = (b.stuckRow or 0) + 1
	b.lastPos, b.lastPosAt = p, os.clock()
	b.model:SetAttribute("BotStuckCount", (b.model:GetAttribute("BotStuckCount") or 0) + 1)
	local side = flat(b.hrp.CFrame.RightVector)
	side = (side.Magnitude > 1e-3 and side.Unit or Vector3.new(1, 0, 0)) * (b.stuckRow % 2 == 1 and 10 or -10)
	b.sideUntil = os.clock() + 1
	b.sideGoal = p + side
	if b.stuckRow >= 2 then b.hum.Jump = true end
	b.path, b.wp = nil, nil
	return true
end

-- ---------- the tick ----------
-- ctx: {bots, R (PracticeRules), H (HardpointRules), diff, rng, centre, nextCentre, into, pointTime, live (bool)}
function M.step(b, ctx)
	local m = b.model
	if not m or not m.Parent or not b.hrp.Parent then return end
	if not aliveModel(m) then
		m:SetAttribute("BotState", "dead")
		return
	end
	if b.busy then return end
	local R, diff = ctx.R, ctx.diff
	if m:GetAttribute("PounceLatched") == true or (tonumber(m:GetAttribute("StunnedUntil")) or 0) > now() then return end
	-- sense
	local best, bestScore
	local foes, mates = 0, 0
	local p = b.hrp.Position
	local job = ctx.jobs and (b.job or (R.jobOf and R.jobOf(b.species))) or nil -- v1.1
	for _, e in ipairs(M.enemiesOf(b.team, ctx.bots)) do
		local r1 = rootOf(e)
		if r1 then
			local dist = flat(r1.Position - p).Magnitude
			if dist < 80 then foes += 1 end
			if visible(b, e, diff, R) then
				local onPoint = ctx.centre and ctx.H.inPoint(r1.Position, ctx.centre) or false
				local hp
				if e:GetAttribute("PracticeBot") == true then
					hp = (tonumber(e:GetAttribute("DummyHealth")) or 0) / math.max(1, tonumber(e:GetAttribute("DummyMaxHealth")) or 1)
				else
					local h = e:FindFirstChildOfClass("Humanoid")
					hp = h and h.Health / math.max(1, h.MaxHealth) or 1
				end
				local s = R.scoreTarget(dist, onPoint, hp)
				if e == b.target then s -= 15 end -- keep the current target unless another is clearly better
				local allowed = true -- v1.1: the job's rules
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
		if orr and (orr.Position - p).Magnitude < 80 then mates += 1 end
	end
	if best ~= b.target then
		if job and ctx.taken and ctx.taken[b.team] then -- v1.1: count the change now, so two bots can't both take the last free place this tick
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
	local myHp = (tonumber(m:GetAttribute("DummyHealth")) or 0) / math.max(1, tonumber(m:GetAttribute("DummyMaxHealth")) or 1)
	local retreat = R.shouldRetreat(myHp, mates, foes, diff)
	-- sidestep in progress
	if b.sideUntil and os.clock() < b.sideUntil then
		b.hum:MoveTo(b.sideGoal)
		return
	end
	-- fight
	if best and not retreat then
		local a = ATTACK[b.species]
		local gap = gapTo(b, best)
		if a and R.wantsAttack(os.clock() - (b.seenSince or os.clock()), gap, a.reach, (b.nextAttack or 0) - os.clock(), diff) then
			startAttack(b, best, R, ctx.rng, diff)
			return
		end
		m:SetAttribute("BotState", "fight")
		local r1 = rootOf(best)
		local dv = flat(r1.Position - p)
		local want = dv.Magnitude > 1e-3 and (r1.Position - dv.Unit * math.max(0, (a and a.reach or 4) * 0.6)) or r1.Position
		if job == "guard" and ctx.centre and R.guardClamp then want = R.guardClamp(want, ctx.centre) end -- v1.1
		unstuck(b, true)
		moveTo(b, want)
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
		m:SetAttribute("BotState", "retreat")
	elseif ctx.centre then
		goal = R.goalFor(b.role, ctx.centre, ctx.nextCentre, ctx.home or p, ctx.into, ctx.pointTime)
		if job and R.jobGoal then goal = R.jobGoal(job, ctx.centre, ctx.nextCentre, ctx.home or p) end -- v1.1
		-- hold below
		local wantsPoint = (goal - ctx.centre).Magnitude < 45
		if wantsPoint and b.goalPoint ~= ctx.index then
			b.goalPoint, b.goalSince, b.bestPos, b.bestDist, b.holdUntil = ctx.index, os.clock(), p, math.huge, nil
		end
		if wantsPoint then
			local onIt = ctx.H.inPoint(p, ctx.centre)
			local dd = (p - ctx.centre).Magnitude
			if dd < (b.bestDist or math.huge) then b.bestDist, b.bestPos = dd, p end
			if b.holdUntil and os.clock() < b.holdUntil then
				goal = b.bestPos or p
				m:SetAttribute("BotState", "holdBelow")
				unstuck(b, false)
				moveTo(b, goal)
				return
			elseif b.holdUntil then
				b.holdUntil, b.goalSince = nil, os.clock()
			end
			if not onIt and os.clock() - (b.goalSince or os.clock()) > R.CLIMB_GIVE_UP then
				b.holdUntil = os.clock() + HOLD_TIME
			end
		end
		m:SetAttribute("BotState", "move")
	else
		goal = p
	end
	unstuck(b, (goal - p).Magnitude > 4)
	moveTo(b, goal)
end

function M.init()
	setupLos()
end

return M
