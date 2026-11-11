-- HardpointServer v1.0 (Mecha Dino Arena) — Arena Hardpoint: teams, the point rotation, occupancy, score, match clock, results,
-- the state every client draws from, the spawn pick and a server-only test hook. MDA-399, plan docs/plans/HARDPOINT_v1.0.md
-- Task 4, ADR-009, mockups docs/mockups/arena_hardpoint_v0.1.html + hardpoint_point_look_v0.1.html.
-- Kepu 2026-11-10: Call of Duty Hardpoint "but with dinos"; 2 auto-balanced teams; spawns "in relation to the hard point like how
--   call of duty does it"; layout B · Summit; radius 45; a cloaked dino counts; 250 to win; team wins over squad; the Arena
--   plays Hardpoint only while this is on.
-- Every number and rule: ServerStorage.DinoArcade.HardpointRules 1.0 (cloned to ReplicatedStorage.HardpointShared for clients).
-- Runs only in the Arena (ModeRules.currentMode() == "arena"; Studio: Workspace ModeTestArena) with script attribute
--   HardpointEnabled ~= false (read at start and live: false stops the match, HpLive false, teams cleared).
-- Phases (ReplicatedStorage.Hardpoint HpPhase): "waiting" (fewer than HpMinPlayers players out of the menu) -> "warmup" (match
--   start; point 1 shows LOCKED for FIRST s) -> "live" -> "results" (RESULTS s; HpWinner "A" / "B" / "draw") -> a new match:
--   teams rebalanced (squads as groups, HardpointRules.assignGroups), scores 0, clock CLOCK, point 1.
-- Every TICK s while live: occupancy = HardpointRules.occupancy over the counted dinos on the current point (alive, not in the
--   menu, a team, HumanoidRootPart within RADIUS flat / DY vertical of the point centre; cloaked dinos count; test dummies
--   tagged through the hook count the same); state = HardpointRules.step(state, occ, TICK); HardpointRules.winner -> results.
-- Points: HardpointRules.LAYOUT_B; each centre's height = the top of DinoIsland.Ground / MountainSteps under it (ray down).
-- Teams: player attribute HardpointTeam ("A" / "B"), given when the player leaves the menu without one
--   (HardpointRules.pickTeam; a squadmate's team when it keeps the gap <= MAX_GAP) and at every match start; cleared when
--   Hardpoint stops. SquadRules 1.1 turns friendly fire off by team while ReplicatedStorage HardpointLive is true.
-- State (ReplicatedStorage folder "Hardpoint", attributes; times are workspace:GetServerTimeNow()): HpLive, HpPhase,
--   HpMatchStartAt, HpIndex, HpNextIndex, HpShowNext, HpPointEndsAt, HpOcc ("N" / "A" / "B" / "C"), HpScoreA, HpScoreB, HpClock
--   (whole seconds left), HpClockPaused, HpWinner, HpResultsEndAt, HpPoints (JSON [{name, x, y, z}]), HpCountA, HpCountB.
--   ReplicatedStorage HardpointLive mirrors HpLive.
-- Spawns: BindableFunction HardpointPickSpawn (child of this script): Invoke(player) -> ground point (Vector3) and the point
--   centre, or nil. HardpointRules.ringSpots round the current point (warmup: point 1) with the ground check (DinoIsland.Ground /
--   MountainSteps under the spot, dry y >= 0, flat normal Y > 0.9, no Trees / Rocks / EdgeWalls in a 36 x 22 x 36 box), then
--   HardpointRules.pickSpawn(spots, enemies, mates). ArenaSpawnServer 1.3 calls it.
-- Test hook (server-only BindableFunction HardpointTest, child of this script): Invoke(action, ...):
--   "team", model, "A"/"B"/nil  tag a dummy model (HardpointTestTeam; counted like a player of that team)
--   "skip"                      jump to the next point's start      "start"   a new match now
--   "score", a, b               set the scores                       "clock", s  set the clock
--   "state"                     -> a one-line summary
-- Diagnostics: script HardpointServerVersion, HardpointState ("off" / "sandbox" / "running"), HpTicks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.0"
script:SetAttribute("HardpointServerVersion", VERSION)
if script:GetAttribute("HardpointEnabled") == nil then script:SetAttribute("HardpointEnabled", true) end
if script:GetAttribute("HpMinPlayers") == nil then script:SetAttribute("HpMinPlayers", 1) end
script:SetAttribute("HpTicks", 0)

local arcade = ServerStorage:WaitForChild("DinoArcade")
local ModeRules = require(arcade:WaitForChild("ModeRules"))
local rulesModule = arcade:WaitForChild("HardpointRules")
local H = require(rulesModule)
local MODE = ModeRules.currentMode()

-- client copy of the rules
local shared = ReplicatedStorage:FindFirstChild("HardpointShared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "HardpointShared"
	shared.Parent = ReplicatedStorage
end
local oldCopy = shared:FindFirstChild("HardpointRules")
if oldCopy then oldCopy:Destroy() end
rulesModule:Clone().Parent = shared

local stateFolder = ReplicatedStorage:FindFirstChild("Hardpoint")
if not stateFolder then
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "Hardpoint"
	stateFolder.Parent = ReplicatedStorage
end
local function set(k, v)
	if stateFolder:GetAttribute(k) ~= v then stateFolder:SetAttribute(k, v) end
end
local function setLive(v)
	set("HpLive", v)
	if ReplicatedStorage:GetAttribute("HardpointLive") ~= v then ReplicatedStorage:SetAttribute("HardpointLive", v) end
end
setLive(false)

local function now() return workspace:GetServerTimeNow() end

if MODE ~= "arena" then
	script:SetAttribute("HardpointState", "sandbox")
	return
end

-- ---------- points ----------
local island = workspace:WaitForChild("DinoIsland", 30)
local groundF = island and island:FindFirstChild("Ground")
local stepsF = island and island:FindFirstChild("MountainSteps")
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = {groundF, stepsF}
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Include
do
	local block = {}
	for _, n in ipairs({"Trees", "Rocks", "EdgeWalls"}) do
		local f = island and island:FindFirstChild(n)
		if f then table.insert(block, f) end
	end
	op.FilterDescendantsInstances = block
end
local WATER = {Water = true, LakeWater = true, Seabed = true, Shallows = true}

local POINTS = {}
for i, p in ipairs(H.LAYOUT_B) do
	local hit = workspace:Raycast(Vector3.new(p.x, 900, p.z), Vector3.new(0, -1200, 0), rp)
	POINTS[i] = {name = p.name, centre = Vector3.new(p.x, hit and hit.Position.Y or 0, p.z)}
end
do
	local list = {}
	for _, p in ipairs(POINTS) do
		table.insert(list, {name = p.name, x = p.centre.X, y = math.floor(p.centre.Y * 10 + 0.5) / 10, z = p.centre.Z})
	end
	set("HpPoints", HttpService:JSONEncode(list))
end

local function groundOk(v)
	local hit = workspace:Raycast(Vector3.new(v.X, 900, v.Z), Vector3.new(0, -1200, 0), rp)
	if not hit or WATER[hit.Instance.Name] or hit.Position.Y < 0 or hit.Normal.Y <= 0.9 then return nil end
	if #workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 12, 0)), Vector3.new(36, 22, 36), op) > 0 then return nil end
	return hit.Position
end
local RINGS = {}
for i, p in ipairs(POINTS) do
	RINGS[i] = H.ringSpots(p.centre, groundOk)
end
script:SetAttribute("HpRingSpots", (function() local s = {} for i, r in ipairs(RINGS) do s[i] = tostring(#r) end return table.concat(s, ",") end)())

-- ---------- teams ----------
local testModels = {} -- [model] = true (hook-tagged dummies)

local function teamCounts()
	local a, b = 0, 0
	for _, pl in ipairs(Players:GetPlayers()) do
		local t = pl:GetAttribute("HardpointTeam")
		if t == "A" then a += 1 elseif t == "B" then b += 1 end
	end
	return a, b
end

local match -- {startAt, state, phase, winner, resultsEndAt}

local function squadTeamOf(player)
	local id = player:GetAttribute("SquadId")
	if type(id) ~= "string" or id == "" then return nil end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl:GetAttribute("SquadId") == id then
			local t = pl:GetAttribute("HardpointTeam")
			if t == "A" or t == "B" then return t end
		end
	end
	return nil
end

local function giveTeam(player)
	if player:GetAttribute("HardpointTeam") == "A" or player:GetAttribute("HardpointTeam") == "B" then return end
	local a, b = teamCounts()
	local s = match and match.state or H.newState()
	player:SetAttribute("HardpointTeam", H.pickTeam(a, b, s.scoreA, s.scoreB, squadTeamOf(player)))
end

local function rebalance()
	local groups, members = {}, {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("InMenu") ~= true then
			local id = pl:GetAttribute("SquadId")
			id = (type(id) == "string" and id ~= "") and ("squad:" .. id) or ("solo:" .. pl.UserId)
			if not members[id] then
				members[id] = {}
				table.insert(groups, {id = id, n = 0})
			end
			table.insert(members[id], pl)
		else
			pl:SetAttribute("HardpointTeam", nil)
		end
	end
	for _, g in ipairs(groups) do
		g.n = #members[g.id]
		table.sort(members[g.id], function(x, y) return x.UserId < y.UserId end)
	end
	local split = H.assignGroups(groups)
	for _, g in ipairs(groups) do
		local s = split[g.id]
		for k, pl in ipairs(members[g.id]) do
			pl:SetAttribute("HardpointTeam", k <= s.A and "A" or "B")
		end
	end
end

local function clearTeams()
	for _, pl in ipairs(Players:GetPlayers()) do pl:SetAttribute("HardpointTeam", nil) end
end

-- ---------- occupancy ----------
local function alive(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then return hum.Health > 0 end
	local dh = model:GetAttribute("DummyHealth")
	return dh == nil or dh > 0
end

local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or (model:IsA("Model") and model.PrimaryPart) or nil
end

-- every counted dino: {team, pos}
local function counted()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local t = pl:GetAttribute("HardpointTeam")
		local c = pl.Character
		local r = c and rootOf(c)
		if (t == "A" or t == "B") and r and pl:GetAttribute("InMenu") ~= true and alive(c) then
			table.insert(list, {team = t, pos = r.Position, player = pl})
		end
	end
	for m in pairs(testModels) do
		local t = m:GetAttribute("HardpointTestTeam")
		local r = m.Parent and rootOf(m)
		if (t == "A" or t == "B") and r and alive(m) then table.insert(list, {team = t, pos = r.Position}) end
	end
	return list
end

-- ---------- spawn pick ----------
local pickFn = script:FindFirstChild("HardpointPickSpawn")
if not pickFn then
	pickFn = Instance.new("BindableFunction")
	pickFn.Name = "HardpointPickSpawn"
	pickFn.Parent = script
end

local function currentIndex()
	if not match or match.phase == "results" then return nil end
	return H.phaseAt(now() - match.startAt, #POINTS).index
end

pickFn.OnInvoke = function(player)
	if stateFolder:GetAttribute("HpLive") ~= true or typeof(player) ~= "Instance" then return nil end
	local team = player:GetAttribute("HardpointTeam")
	local idx = currentIndex()
	if (team ~= "A" and team ~= "B") or not idx then return nil end
	local enemies, mates = {}, {}
	for _, d in ipairs(counted()) do
		if d.player ~= player then
			if d.team == team then table.insert(mates, d.pos) else table.insert(enemies, d.pos) end
		end
	end
	local spot = H.pickSpawn(RINGS[idx], enemies, mates)
	if not spot then return nil end
	return spot, POINTS[idx].centre
end

-- ---------- the match ----------
local function newMatch()
	match = {startAt = now(), state = H.newState(), phase = "warmup", winner = nil, resultsEndAt = nil, acc = 0}
	rebalance()
	set("HpMatchStartAt", match.startAt)
	set("HpWinner", "")
	set("HpResultsEndAt", 0)
end

local function playingCount()
	local n = 0
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("InMenu") ~= true and pl.Character then n += 1 end
	end
	return n
end

local function publish()
	local a, b = teamCounts()
	set("HpCountA", a)
	set("HpCountB", b)
	if not match then
		set("HpPhase", "waiting")
		return
	end
	local s = match.state
	set("HpScoreA", s.scoreA)
	set("HpScoreB", s.scoreB)
	set("HpClock", math.ceil(s.clock - 1e-6))
	if match.phase == "results" then
		set("HpPhase", "results")
		set("HpOcc", "N")
		return
	end
	local ph = H.phaseAt(now() - match.startAt, #POINTS)
	set("HpPhase", ph.warmup and "warmup" or "live")
	set("HpIndex", ph.index)
	set("HpNextIndex", ph.nextIndex)
	set("HpShowNext", ph.showNext)
	set("HpPointEndsAt", now() + ph.remaining)
end

local ticks = 0
local function tick()
	if not match then
		if playingCount() >= (tonumber(script:GetAttribute("HpMinPlayers")) or 1) then newMatch() end
		publish()
		return
	end
	if match.phase == "results" then
		if now() >= match.resultsEndAt then newMatch() end
		publish()
		return
	end
	local ph = H.phaseAt(now() - match.startAt, #POINTS)
	if ph.warmup then
		match.phase = "warmup"
		set("HpOcc", "N")
		set("HpClockPaused", false)
		publish()
		return
	end
	match.phase = "live"
	local centre = POINTS[ph.index].centre
	local nA, nB = 0, 0
	for _, d in ipairs(counted()) do
		if H.inPoint(d.pos, centre) then
			if d.team == "A" then nA += 1 else nB += 1 end
		end
	end
	local occ = H.occupancy(nA, nB)
	match.state = H.step(match.state, occ, H.TICK)
	set("HpOcc", occ)
	set("HpClockPaused", occ ~= "N")
	local w = H.winner(match.state)
	if w then
		match.phase = "results"
		match.winner = w
		match.resultsEndAt = now() + H.RESULTS
		set("HpWinner", w)
		set("HpResultsEndAt", match.resultsEndAt)
	end
	ticks += 1
	if ticks % 20 == 0 then script:SetAttribute("HpTicks", ticks) end
	publish()
end

-- ---------- players ----------
local function onPlayer(player)
	player:GetAttributeChangedSignal("InMenu"):Connect(function()
		if stateFolder:GetAttribute("HpLive") == true and player:GetAttribute("InMenu") == false then giveTeam(player) end
	end)
	if stateFolder:GetAttribute("HpLive") == true and player:GetAttribute("InMenu") == false then giveTeam(player) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

-- ---------- test hook ----------
local test = script:FindFirstChild("HardpointTest")
if not test then
	test = Instance.new("BindableFunction")
	test.Name = "HardpointTest"
	test.Parent = script
end
test.OnInvoke = function(action, a, b)
	if action == "team" then
		if typeof(a) ~= "Instance" then return "badArg" end
		a:SetAttribute("HardpointTestTeam", (b == "A" or b == "B") and b or nil)
		testModels[a] = (b == "A" or b == "B") or nil
		return "ok"
	elseif action == "skip" then
		if not match or match.phase == "results" then return "noMatch" end
		local ph = H.phaseAt(now() - match.startAt, #POINTS)
		match.startAt -= (ph.warmup and ph.remaining or ph.remaining)
		set("HpMatchStartAt", match.startAt)
		return "ok"
	elseif action == "start" then
		newMatch()
		return "ok"
	elseif action == "score" then
		if not match then return "noMatch" end
		match.state.scoreA, match.state.scoreB = tonumber(a) or 0, tonumber(b) or 0
		return "ok"
	elseif action == "clock" then
		if not match then return "noMatch" end
		match.state.clock = tonumber(a) or H.CLOCK
		return "ok"
	elseif action == "state" then
		local f = stateFolder
		return ("live %s phase %s P%s next P%s shown %s occ %s score %s-%s clock %s paused %s winner %s teams %s/%s"):format(
			tostring(f:GetAttribute("HpLive")), tostring(f:GetAttribute("HpPhase")), tostring(f:GetAttribute("HpIndex")),
			tostring(f:GetAttribute("HpNextIndex")), tostring(f:GetAttribute("HpShowNext")), tostring(f:GetAttribute("HpOcc")),
			tostring(f:GetAttribute("HpScoreA")), tostring(f:GetAttribute("HpScoreB")), tostring(f:GetAttribute("HpClock")),
			tostring(f:GetAttribute("HpClockPaused")), tostring(f:GetAttribute("HpWinner")), tostring(f:GetAttribute("HpCountA")),
			tostring(f:GetAttribute("HpCountB")))
	end
	return "badArg"
end

-- ---------- run ----------
local running = false
local acc = 0
local conn
local function start()
	if running then return end
	running = true
	setLive(true)
	script:SetAttribute("HardpointState", "running")
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("InMenu") == false then giveTeam(pl) end
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		while acc >= H.TICK do
			acc -= H.TICK
			tick()
		end
	end)
end
local function stop()
	if not running then return end
	running = false
	if conn then conn:Disconnect() conn = nil end
	match = nil
	setLive(false)
	set("HpPhase", "off")
	clearTeams()
	script:SetAttribute("HardpointState", "off")
end
local function apply()
	if script:GetAttribute("HardpointEnabled") ~= false then start() else stop() end
end
script:GetAttributeChangedSignal("HardpointEnabled"):Connect(apply)
apply()
