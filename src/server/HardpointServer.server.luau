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
-- v1.1 (practice match, MDA-407, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 3; Kepu 2026-11-10: the Sandbox is a Hardpoint
--   practice match vs bots "for now"):
--   * Also runs in the Sandbox while the practice match is set up there (PRACTICE: ServerScriptService.PracticeServer exists,
--     Enabled, PracticeEnabled not false, and this script's HardpointPracticeEnabled not false; read once at start). In
--     practice PracticeServer owns the teams (player HardpointTeam, bot HardpointBotTeam) and the start: no auto team pick,
--     no rebalance, no auto match; HpPhase "lobby" between matches; after the results the match ends (no new match) and the
--     BindableEvent HardpointPracticeEnded (child) fires with the winner.
--   * Bot models: server-only BindableFunction HardpointPractice (child): Invoke("start") a new match; ("bot", model, "A" / "B")
--     registers a bot (counted like a player of that team, needs HardpointBotTeam on the model too); ("unbot", model);
--     ("stop") ends the match now (lobby); ("stat", id, name, team, species, isBot, field "k" / "d") adds 1 to that stat.
--   * HardpointPickSpawn also takes a model (a bot): its team = HardpointBotTeam; itself is left out of mates.
--   * Scoreboard (Arena and practice): per participant {id, name, team, species, bot, k, d, pt (seconds on the point)} for
--     the current match, reset at its start; ReplicatedStorage.Hardpoint HpBoard (JSON array) at most every 0.5 s.
--     Participant id: "u<UserId>" for a player, "b<model name>" for a bot.
--   Switch: script attribute HardpointPracticeEnabled (default true; false = 1.0 in the Sandbox: off). Diagnostic
--   HardpointState "practice" while running there.
-- v1.2 (spawns v2, MDA-422, plan docs/plans/HARDPOINT_SPAWNS_MARKER_v1.0.md Task 2; Kepu 2026-11-10 "B · Scored ring",
--   420–600): HardpointPickSpawn uses HardpointRules 1.1:
--   * bands: H.bandSpots(point centre, the 1.0 ground check) per point at start (24 directions x 420 / 480 / 540 / 600;
--     fewer than 8 -> + 360 / 300). Diagnostic HpBandSpots ("n1,n2,..").
--   * warm-up (the match's first 5 s): opening anchors, once per match: H.pickOpening(point 1's band, its centre, seesFn) with
--     seesFn = a ray between the two spots (+6 studs) that hits nothing in the world; team A the first, B the second. A spawn
--     during the warm-up = H.pickNear(point 1's band, its team's anchor, taken within the last 3 s). No pair -> the rule below.
--     Diagnostic HpOpening ("A x,z | B x,z" or "none").
--   * after the warm-up: H.pickScored(the current point's band, living enemies, mates, seenFn) with seenFn(spot) = any living
--     enemy within H.SIGHT_MAX (700, flat) has a clear ray from its root + 6 to the spot + 6 (dinos left out: player
--     characters and DinoIsland.Bots; trees, rocks, ground block). Nothing -> the 1.1 ring pick.
--   Diagnostics HpSpawnLast ("open A" / "scored 512 seen=false" / "ring" / "none"), HpSpawnCount.
--   Switch: script attribute HardpointScoredSpawnsEnabled (default true, read per pick; false = 1.1 ring pick).
-- v1.3 (far spawns + fair start sides, MDA-426, plan docs/plans/HUD_SLIM_SPAWNS_FAR_v1.0.md Task 2; Kepu 2026-11-11 "make the
--   distance even further for spawns", picks "700–900" and "Equal running distance"), HardpointRules 1.2:
--   * band 2 per point at start: H.bandSpots(centre, the ground check, H.BAND2_RADII, H.BAND2_EXTRA_RADII) (24 directions x
--     700 / 750 / 800 / 850 / 900; fewer than 8 -> + 650 / 600). Diagnostic HpBandSpots2 ("n1,n2,..").
--   * while far spawns are on: picks use band 2, and sight rays come from enemies within H.SIGHT_MAX2 (1000).
--   * run lengths: in the background at start, a server path (PathfindingService, agent radius HpRunAgentRadius 4, height
--     HpRunAgentHeight 10, can jump, waypoint spacing 8) from every band-2 spot of point 1 (then every 1.2 band spot of
--     point 1) to the point centre, summed waypoint to waypoint; no path (status not Success) = no run. Diagnostic HpRunPaths
--     ("<ok> ok / <tried> of <total>" for band 2, then " | 1.2 ..." once that band is done).
--   * opening (once per match, first warm-up pick): with run openings on and that band's runs all worked out,
--     H.pickOpeningByRun(point 1's band, the ray seesFn, run, band 2 ? H.OPEN_MIN_APART2 : H.OPEN_MIN_APART); no pair (or runs
--     not ready) -> the 1.2 straight-line H.pickOpening on the same band. HpOpening: "A x,z run r | B x,z run r" or
--     "flat A x,z | B x,z" or "none".
--   Switches (script attributes, read per pick): HardpointFarSpawnsEnabled (default true; false = 1.2 band, sight 700) and
--   HardpointRunOpeningEnabled (default true; false = 1.2 straight-line pair). Diagnostic HpSpawnLast gets " far" on band-2 picks.
-- v1.4 (island hub, MDA-454, plan docs/plans/ISLAND_HUB_v1.0.md Task 3, ADR-011; Kepu 2026-11-11: the hub island is free roam):
--   when ModeRules 1.2 serverKind() == "hub" nothing starts (HardpointState "hub"; no HpLive, no teams). Kinds "practice" /
--   "arena": exactly 1.3. Switch: script attribute HardpointHubEnabled (default true; false = 1.3). Read once at start.
-- v1.5 (match end, MDA-464, plan docs/plans/MATCH_END_v1.0.md Task 4, mockup docs/mockups/match_end_v0.1.html; Kepu 2026-11-11
--   19:43 "Build with all the recs"):
--   * Scoreboard rows get pk (player kills): the practice hook's "stat" also takes field "pk" (KillFeedServer 1.1 sends it when a
--     player kills a player); HpBoard rows carry pk.
--   * Awards, once per match, the moment the winner is decided (match.awarded): the board rows go through
--     ServerStorage.DinoArcade.MatchAwards 1.0 compute(rows, winner, PRACTICE, cfg) (MVP / SVP one per team; XP lines). For each
--     human row "u<UserId>" whose Player is in the server and whose total > 0: ServerScriptService.SkillServer.SkillGrantXp
--     (SkillServer 1.10) Invoke(player, total, "match") (skill XP to the dino being played). Then ReplicatedStorage.Hardpoint
--     HpAwards = JSON {mvp, svp, practice, winner, rows = {[id] = {kill, point, win, mvp, svp, total, granted (the grant's
--     result), lvB, inB, nxB, lvA, inA, nxA}}} (levels from the grant; 0 when not granted). newMatch / the practice lobby / stop
--     set HpAwards "".
--   * cfg from script attributes (read at each award): HpXpKill 50, HpXpPerSec 1, HpXpWin 100, HpXpDraw 50, HpXpMvp 50, HpXpSvp
--     25, HpXpPracticeMul 0.1, HpMvpKillPts 100, HpMvpSecPts 10.
--   Switch: script attribute HardpointAwardsEnabled (default true, read at each award; false = 1.4: no awards, HpAwards "").
--   Diagnostics: HpAwardsLast ("mvp <id> svp <id> rows n granted n" / "off" / "noModule"), HpAwardsCount.
-- v1.7 (Kepu 2026-11-12 18:04 XP "doesn't feel rewarding"; pick "50% of a real match"): HpXpPracticeMul default 0.5 (was 0.1):
--   a bots match's point / win / MVP / SVP lines pay half a real match's (PracticeServer 1.8 makes bot kills 50% too).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.1"
VERSION = "1.2" -- v1.2 spawns v2
VERSION = "1.3" -- v1.3 far spawns + start sides by run
VERSION = "1.4" -- v1.4 off on the hub
VERSION = "1.5" -- v1.5 match awards
VERSION = "1.6" -- v1.6 score per teammate on the point
VERSION = "1.7" -- v1.7 bots match XP 50%
script:SetAttribute("HardpointServerVersion", VERSION)
if script:GetAttribute("HardpointEnabled") == nil then script:SetAttribute("HardpointEnabled", true) end
if script:GetAttribute("HpMinPlayers") == nil then script:SetAttribute("HpMinPlayers", 1) end
if script:GetAttribute("HardpointPracticeEnabled") == nil then script:SetAttribute("HardpointPracticeEnabled", true) end -- v1.1
script:SetAttribute("HpTicks", 0)
-- v1.5: awards switch + numbers (see the header)
if script:GetAttribute("HardpointAwardsEnabled") == nil then script:SetAttribute("HardpointAwardsEnabled", true) end
if script:GetAttribute("HpXpPracticeMul") == nil then script:SetAttribute("HpXpPracticeMul", 0.5) end -- v1.7 (was 0.1)
for k, v in pairs({HpXpKill = 50, HpXpPerSec = 1, HpXpWin = 100, HpXpDraw = 50, HpXpMvp = 50, HpXpSvp = 25, HpXpPracticeMul = 0.1,
	HpMvpKillPts = 100, HpMvpSecPts = 10}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("HpAwardsCount", script:GetAttribute("HpAwardsCount") or 0)

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

-- v1.6 (Kepu 2026-11-12 15:48): the holding team scores 1 a second per teammate on the point when uncontested
--   (HardpointRules 1.3 stepCount with nA / nB). Switch: script attribute HpScorePerMateEnabled (default true, read per tick;
--   false = 1.5, 1 a second).
-- v1.1: the practice match in the Sandbox
local PRACTICE = false
do
	local ps = game:GetService("ServerScriptService"):FindFirstChild("PracticeServer")
	PRACTICE = MODE == "sandbox" and script:GetAttribute("HardpointPracticeEnabled") ~= false and ps ~= nil and ps:IsA("BaseScript")
		and ps.Enabled and ps:GetAttribute("PracticeEnabled") ~= false
end

if script:GetAttribute("HardpointHubEnabled") == nil then script:SetAttribute("HardpointHubEnabled", true) end -- v1.4
if MODE == "sandbox" and script:GetAttribute("HardpointHubEnabled") ~= false and ModeRules.serverKind
	and ModeRules.serverKind() == "hub" then -- v1.4
	script:SetAttribute("HardpointState", "hub")
	return
end
if MODE ~= "arena" and not PRACTICE then -- v1.1: + not PRACTICE
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
-- v1.2: the 420–600 bands (see the header)
if script:GetAttribute("HardpointScoredSpawnsEnabled") == nil then script:SetAttribute("HardpointScoredSpawnsEnabled", true) end
local BANDS = {}
for i, p in ipairs(POINTS) do
	BANDS[i] = H.bandSpots and H.bandSpots(p.centre, groundOk) or {}
end
script:SetAttribute("HpBandSpots", (function() local s = {} for i, r in ipairs(BANDS) do s[i] = tostring(#r) end return table.concat(s, ",") end)())
script:SetAttribute("HpSpawnCount", 0)
-- v1.3: band 2 + run lengths (see the header)
if script:GetAttribute("HardpointFarSpawnsEnabled") == nil then script:SetAttribute("HardpointFarSpawnsEnabled", true) end
if script:GetAttribute("HardpointRunOpeningEnabled") == nil then script:SetAttribute("HardpointRunOpeningEnabled", true) end
if script:GetAttribute("HpRunAgentRadius") == nil then script:SetAttribute("HpRunAgentRadius", 4) end
if script:GetAttribute("HpRunAgentHeight") == nil then script:SetAttribute("HpRunAgentHeight", 10) end
local BANDS2 = {}
for i, p in ipairs(POINTS) do
	BANDS2[i] = (H.BAND2_RADII and H.bandSpots(p.centre, groundOk, H.BAND2_RADII, H.BAND2_EXTRA_RADII)) or {}
end
script:SetAttribute("HpBandSpots2", (function() local s = {} for i, r in ipairs(BANDS2) do s[i] = tostring(#r) end return table.concat(s, ",") end)())
local RUNS = {} -- [band table] = {done = bool, [spot] = studs}
task.spawn(function()
	local PathfindingService = game:GetService("PathfindingService")
	local path = PathfindingService:CreatePath({
		AgentRadius = tonumber(script:GetAttribute("HpRunAgentRadius")) or 4,
		AgentHeight = tonumber(script:GetAttribute("HpRunAgentHeight")) or 10,
		AgentCanJump = true,
		WaypointSpacing = 8,
	})
	local diag = ""
	for _, band in ipairs({BANDS2[1] or {}, BANDS[1] or {}}) do
		local r = {done = false}
		RUNS[band] = r
		local okN, tried = 0, 0
		local goal = POINTS[1] and POINTS[1].centre
		for _, spot in ipairs(band) do
			tried += 1
			if goal then
				local ok = pcall(function() path:ComputeAsync(spot + Vector3.new(0, 3, 0), goal) end)
				if ok and path.Status == Enum.PathStatus.Success then
					local wps = path:GetWaypoints()
					local len = 0
					for k = 2, #wps do len += (wps[k].Position - wps[k - 1].Position).Magnitude end
					if #wps >= 2 then r[spot] = len okN += 1 end
				end
			end
			if tried % 8 == 0 then
				script:SetAttribute("HpRunPaths", diag .. ("%d ok / %d of %d"):format(okN, tried, #band))
				task.wait()
			end
		end
		r.done = true
		diag ..= ("%d ok / %d of %d"):format(okN, tried, #band)
		script:SetAttribute("HpRunPaths", diag)
		diag ..= " | 1.2 "
	end
end)

-- ---------- teams ----------
local testModels = {} -- [model] = true (hook-tagged dummies)
local botModels = {} -- v1.1: [model] = true (practice bots)

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
	if PRACTICE then return end -- v1.1: PracticeServer owns the teams
	if player:GetAttribute("HardpointTeam") == "A" or player:GetAttribute("HardpointTeam") == "B" then return end
	local a, b = teamCounts()
	local s = match and match.state or H.newState()
	player:SetAttribute("HardpointTeam", H.pickTeam(a, b, s.scoreA, s.scoreB, squadTeamOf(player)))
end

local function rebalance()
	if PRACTICE then return end -- v1.1
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
	for m in pairs(botModels) do -- v1.1
		local t = m:GetAttribute("HardpointBotTeam")
		local r = m.Parent and rootOf(m)
		if (t == "A" or t == "B") and r and alive(m) then table.insert(list, {team = t, pos = r.Position, model = m}) end
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
	if not player:IsA("Player") then team = player:GetAttribute("HardpointBotTeam") end -- v1.1: a bot model
	local idx = currentIndex()
	if (team ~= "A" and team ~= "B") or not idx then return nil end
	local enemies, mates = {}, {}
	for _, d in ipairs(counted()) do
		if d.player ~= player and d.model ~= player then -- v1.1: + a bot leaves itself out
			if d.team == team then table.insert(mates, d.pos) else table.insert(enemies, d.pos) end
		end
	end
	-- v1.2: spawns v2 (see the header)
	local far = script:GetAttribute("HardpointFarSpawnsEnabled") ~= false and H.SIGHT_MAX2 ~= nil and #(BANDS2[idx] or {}) > 0 -- v1.3
	local useBands = far and BANDS2 or BANDS
	local sightMax = far and H.SIGHT_MAX2 or H.SIGHT_MAX
	if script:GetAttribute("HardpointScoredSpawnsEnabled") ~= false and H.pickScored and #(useBands[idx] or {}) > 0 then
		local function spawned(spot, how)
			script:SetAttribute("HpSpawnLast", far and (how .. " far") or how) -- v1.3: " far"
			script:SetAttribute("HpSpawnCount", (script:GetAttribute("HpSpawnCount") or 0) + 1)
			local keep = {}
			for _, k in ipairs(match.taken or {}) do if os.clock() - k.at < 3 then table.insert(keep, k) end end
			table.insert(keep, {spot = spot, at = os.clock()})
			match.taken = keep
			return spot, POINTS[idx].centre
		end
		-- sight rays leave every dino out
		local sp = RaycastParams.new()
		sp.FilterType = Enum.RaycastFilterType.Exclude
		local ex = {}
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
		local botsF = island and island:FindFirstChild("Bots")
		if botsF then table.insert(ex, botsF) end
		for m in pairs(testModels) do table.insert(ex, m) end
		sp.FilterDescendantsInstances = ex
		sp.IgnoreWater = true
		local UP = Vector3.new(0, 6, 0)
		local function clear(a, b) return workspace:Raycast(a + UP, (b + UP) - (a + UP), sp) == nil end
		local ph = H.phaseAt(now() - match.startAt, #POINTS)
		if ph.warmup then
			if match.opening == nil then
				-- v1.3: start sides by run length first (see the header)
				local band1 = useBands[1]
				local runs = RUNS[band1]
				local a, b
				if script:GetAttribute("HardpointRunOpeningEnabled") ~= false and H.pickOpeningByRun and runs and runs.done then
					a, b = H.pickOpeningByRun(band1, function(x, y) return clear(x, y) end, function(s) return runs[s] end,
						far and H.OPEN_MIN_APART2 or H.OPEN_MIN_APART)
					if a then
						script:SetAttribute("HpOpening", ("A %d,%d run %d | B %d,%d run %d"):format(a.X, a.Z, runs[a], b.X, b.Z, runs[b]))
					end
				end
				if not a then
					a, b = H.pickOpening(band1, POINTS[1].centre, function(x, y) return clear(x, y) end)
					script:SetAttribute("HpOpening", a and ("flat A %d,%d | B %d,%d"):format(a.X, a.Z, b.X, b.Z) or "none")
				end
				match.opening = a and {A = a, B = b, band = band1} or false
			end
			if match.opening then
				local t = os.clock()
				local spot = H.pickNear(match.opening.band or BANDS[1], match.opening[team], function(s)
					for _, k in ipairs(match.taken or {}) do
						if k.spot == s and t - k.at < 3 then return true end
					end
					return false
				end)
				if spot then return spawned(spot, "open " .. team) end
			end
		end
		local seenMap = {}
		local spot, score = H.pickScored(useBands[idx], enemies, mates, function(s) -- v1.3: useBands / sightMax
			for _, e in ipairs(enemies) do
				local dx, dz = e.X - s.X, e.Z - s.Z
				if dx * dx + dz * dz <= sightMax * sightMax and clear(e, s) then seenMap[s] = true return true end
			end
			return false
		end)
		if spot then
			return spawned(spot, ("scored %d seen=%s"):format(math.floor(score + 0.5), tostring(seenMap[spot] == true)))
		end
	end
	local spot = H.pickSpawn(RINGS[idx], enemies, mates)
	if not spot then
		script:SetAttribute("HpSpawnLast", "none") -- v1.2
		return nil
	end
	script:SetAttribute("HpSpawnLast", "ring") -- v1.2
	return spot, POINTS[idx].centre
end

-- ---------- v1.1: scoreboard ----------
local board = {} -- [id] = {id, name, team, species, bot, k, d, pt}
local boardDirty, boardAt = false, 0
local function boardRow(id, name, team, species, isBot)
	local r = board[id]
	if not r then
		r = {id = id, name = name, team = team, species = species, bot = isBot == true, k = 0, d = 0, pt = 0}
		board[id] = r
	end
	r.name, r.team = name or r.name, team or r.team
	if species then r.species = species end
	boardDirty = true
	return r
end
local function publishBoard(force)
	if not boardDirty and not force then return end
	if not force and os.clock() - boardAt < 0.5 then return end
	boardAt, boardDirty = os.clock(), false
	local list = {}
	for _, r in pairs(board) do
		table.insert(list, {id = r.id, name = r.name, team = r.team, species = r.species, bot = r.bot, k = r.k, d = r.d,
			pt = math.floor(r.pt + 0.5), pk = r.pk or 0}) -- v1.5: + pk
	end
	table.sort(list, function(x, y) if x.k ~= y.k then return x.k > y.k end return x.name < y.name end)
	set("HpBoard", HttpService:JSONEncode(list))
end
local function idOf(d)
	if d.player then return "u" .. d.player.UserId, d.player.DisplayName, d.player.Character and d.player.Character:GetAttribute("Species"), false end
	if d.model then return "b" .. d.model.Name, d.model:GetAttribute("DisplayName") or d.model.Name, d.model:GetAttribute("Species"), true end
	return nil
end

-- ---------- the match ----------
local function newMatch()
	match = {startAt = now(), state = H.newState(), phase = "warmup", winner = nil, resultsEndAt = nil, acc = 0}
	board = {} -- v1.1
	publishBoard(true)
	rebalance()
	set("HpMatchStartAt", match.startAt)
	set("HpWinner", "")
	set("HpResultsEndAt", 0)
	set("HpAwards", "") -- v1.5
end

-- ---------- v1.5: awards (see the header) ----------
local MatchAwards
do
	local m = arcade:FindFirstChild("MatchAwards")
	if m then
		local ok, mod = pcall(require, m)
		if ok then MatchAwards = mod end
	end
end
local function awardsCfg()
	local function n(k, dflt) local v = script:GetAttribute(k) return type(v) == "number" and v or dflt end
	return {kill = n("HpXpKill", 50), sec = n("HpXpPerSec", 1), win = n("HpXpWin", 100), draw = n("HpXpDraw", 50),
		mvp = n("HpXpMvp", 50), svp = n("HpXpSvp", 25), practiceMul = n("HpXpPracticeMul", 0.1), mvpKill = n("HpMvpKillPts", 100),
		mvpSec = n("HpMvpSecPts", 10)}
end
local function award(m)
	if not m or m.awarded then return end
	m.awarded = true
	if script:GetAttribute("HardpointAwardsEnabled") == false then
		script:SetAttribute("HpAwardsLast", "off")
		return
	end
	if not MatchAwards then
		script:SetAttribute("HpAwardsLast", "noModule")
		return
	end
	local rows = {}
	for _, r in pairs(board) do
		table.insert(rows, {id = r.id, team = r.team, bot = r.bot, k = r.k, d = r.d, pt = r.pt, pk = r.pk or 0})
	end
	local res = MatchAwards.compute(rows, m.winner, PRACTICE, awardsCfg())
	task.spawn(function()
		local grantFn = game:GetService("ServerScriptService"):FindFirstChild("SkillServer")
		grantFn = grantFn and grantFn:FindFirstChild("SkillGrantXp")
		local out, nRows, nGranted = {}, 0, 0
		for id, l in pairs(res.rows) do
			nRows += 1
			local row = {kill = l.kill, point = l.point, win = l.win, mvp = l.mvp, svp = l.svp, total = l.total, granted = "none",
				lvB = 0, inB = 0, nxB = 0, lvA = 0, inA = 0, nxA = 0}
			local uid = tonumber(string.match(id, "^u(%d+)$") or "")
			local pl = uid and Players:GetPlayerByUserId(uid)
			if not pl then
				row.granted = "left"
			elseif l.total > 0 and grantFn then
				local ok, why, b, a = pcall(function() return grantFn:Invoke(pl, l.total, "match") end)
				row.granted = ok and tostring(why) or "error"
				if ok and why == "ok" and type(b) == "table" and type(a) == "table" then
					nGranted += 1
					row.lvB, row.inB, row.nxB = b.level or 0, b.into or 0, b.next or 0
					row.lvA, row.inA, row.nxA = a.level or 0, a.into or 0, a.next or 0
				end
			elseif not grantFn then
				row.granted = "noGrant"
			end
			out[id] = row
		end
		if match ~= m then return end -- a new match started meanwhile
		set("HpAwards", HttpService:JSONEncode({mvp = res.mvp, svp = res.svp, practice = PRACTICE == true, winner = m.winner,
			rows = out}))
		script:SetAttribute("HpAwardsLast", ("mvp %s svp %s rows %d granted %d"):format(res.mvp, res.svp, nRows, nGranted))
		script:SetAttribute("HpAwardsCount", (script:GetAttribute("HpAwardsCount") or 0) + 1)
	end)
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
	publishBoard(false) -- v1.1
	if not match then
		set("HpPhase", PRACTICE and "lobby" or "waiting") -- v1.1: "lobby" in practice
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

local practiceEnded = script:FindFirstChild("HardpointPracticeEnded") -- v1.1
if not practiceEnded then
	practiceEnded = Instance.new("BindableEvent")
	practiceEnded.Name = "HardpointPracticeEnded"
	practiceEnded.Parent = script
end

local ticks = 0
local function tick()
	if not match then
		if not PRACTICE and playingCount() >= (tonumber(script:GetAttribute("HpMinPlayers")) or 1) then newMatch() end -- v1.1: + not PRACTICE
		publish()
		return
	end
	if match.phase == "results" then
		if now() >= match.resultsEndAt then
			if PRACTICE then -- v1.1: back to the lobby
				local w = match.winner
				match = nil
				set("HpAwards", "") -- v1.5
				publish()
				practiceEnded:Fire(w)
				return
			end
			newMatch()
		end
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
			local id, name, species, isBot = idOf(d) -- v1.1: seconds on the point
			if id then
				local r = boardRow(id, name, d.team, species, isBot)
				r.pt += H.TICK
			end
		end
	end
	local occ = H.occupancy(nA, nB)
	if H.stepCount and script:GetAttribute("HpScorePerMateEnabled") ~= false then -- v1.6
		match.state = H.stepCount(match.state, occ, nA, nB, H.TICK)
	else
		match.state = H.step(match.state, occ, H.TICK)
	end
	set("HpOcc", occ)
	set("HpClockPaused", occ ~= "N")
	local w = H.winner(match.state)
	if w then
		match.phase = "results"
		match.winner = w
		match.resultsEndAt = now() + H.RESULTS
		set("HpWinner", w)
		set("HpResultsEndAt", match.resultsEndAt)
		award(match) -- v1.5
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

-- ---------- v1.1: practice hook ----------
local practiceFn = script:FindFirstChild("HardpointPractice")
if not practiceFn then
	practiceFn = Instance.new("BindableFunction")
	practiceFn.Name = "HardpointPractice"
	practiceFn.Parent = script
end
practiceFn.OnInvoke = function(action, a, b, c, d, e2, f)
	if action == "bot" then
		if typeof(a) ~= "Instance" or (b ~= "A" and b ~= "B") then return "badArg" end
		botModels[a] = true
		a:SetAttribute("HardpointBotTeam", b)
		a.AncestryChanged:Connect(function() if not a.Parent then botModels[a] = nil end end)
		return "ok"
	elseif action == "unbot" then
		if typeof(a) == "Instance" then botModels[a] = nil end
		return "ok"
	elseif action == "start" then
		if not PRACTICE then return "notPractice" end
		newMatch()
		return "ok"
	elseif action == "stop" then
		match = nil
		set("HpAwards", "") -- v1.5
		publish()
		return "ok"
	elseif action == "stat" then
		-- ("stat", id, name, team, species, isBot, field)
		if type(a) ~= "string" or (f ~= "k" and f ~= "d" and f ~= "pk") or not match then return "badArg" end -- v1.5: + "pk"
		local r = boardRow(a, b, c, d, e2)
		r[f] = (r[f] or 0) + 1
		return "ok"
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
	script:SetAttribute("HardpointState", PRACTICE and "practice" or "running") -- v1.1
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
	set("HpAwards", "") -- v1.5
	set("HpPhase", "off")
	clearTeams()
	script:SetAttribute("HardpointState", "off")
end
local function apply()
	if script:GetAttribute("HardpointEnabled") ~= false then start() else stop() end
end
script:GetAttributeChangedSignal("HardpointEnabled"):Connect(apply)
apply()
