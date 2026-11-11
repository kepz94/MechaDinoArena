-- PracticeServer v1.0 (Mecha Dino Arena) — the Sandbox practice match: lobby, teams, bots, their life and the match flow.
-- MDA-408 (+ MDA-406 / 409 / 410 through its children PracticeBots / PracticeBrain), plan docs/plans/PRACTICE_MATCH_v1.0.md
-- Task 4, ADR-010, mockup docs/mockups/practice_match_v0.1.html (v0.2). Kepu 2026-11-10: the Sandbox opens a Hardpoint practice
-- match vs bots "for now"; direction A (lobby: JOIN BLUE / JOIN RED / AUTO, EASY / NORMAL / HARD, NEW BOTS, START, starts by
-- itself after 20 s; 5v5); real abilities; 10% bot XP; the lobby lists only parts that work for bots.
-- Runs only in the Sandbox (ModeRules.currentMode() == "sandbox") with script attribute PracticeEnabled ~= false (read at start;
--   PlaceGate 1.1 / ArenaPvP 1.3 / HardpointServer 1.1 read the same switch). Rules and numbers: ServerStorage.DinoArcade.PracticeRules
--   (cloned to ReplicatedStorage.PracticeShared for clients).
-- State (ReplicatedStorage folder "Practice"): PrPhase ("lobby" / "match"), PrStartAt (server time the lobby starts by itself, 0 =
--   nobody in the lobby), PrDifficulty ("Easy" / "Normal" / "Hard"), PrSize, PrRoster (JSON {A = [slot], B = [slot]}, slot =
--   {kind "human" | "bot", name, species, userId (human), parts = [names of BOT_LIVE parts]}), PrResult (last winner).
--   ReplicatedStorage PracticeLive = (PrPhase == "match") (ModeRules 1.1 lets players hurt players then).
-- Players: PrInLobby (on the team screen), PrInMatch (playing), PrSide ("A" / "B"), PrLastResult (last request's answer).
-- Requests: RemoteEvent ReplicatedStorage.PracticeRequest(action, arg):
--   "lobby"            enter the lobby (from the menu's PLAY on PRACTICE); during a match: straight into it, on the smaller
--                      side (ties: the side behind on score), taking a bot's slot.
--   "join", "A"|"B"|"auto"   pick a side in the lobby ("full" when that side has PrSize humans).
--   "difficulty", name  "newbots" (re-roll every bot; 1 s gap)   "start" (lobby -> match)   "leave" (out of the lobby / match).
-- Match: START or PrStartAt -> bots spawned on HardpointPickSpawn spots, HardpointServer.HardpointPractice("start"); humans get
--   HardpointTeam = their side and PrInMatch (their client presses play: DinoModeRequest "play"); each human body is placed on
--   a spawn spot when it leaves the menu and after every respawn. A bot whose DummyHealth reaches 0 is removed after BOT_BODY
--   (2) s and comes back after PrBotRespawn (5) s on a spawn spot. A human who leaves (menu / quits) gets a bot in the slot
--   after PrRefill (5) s. HardpointPracticeEnded -> "lobby" (bots removed; humans back on the team screen with the same
--   roster; PrStartAt = now + PrAutoStart). No human left in the roster -> the match stops.
-- Bots think at THINK_HZ (10 Hz) through PracticeBrain; roles are dealt (PracticeRules.assignRoles) per team at match start and
--   every point change.
-- Script attributes: PracticeEnabled (true), PracticeTeamSize (5; 4 if phones are slow, red-team 2), PrAutoStart (20),
--   PrBotRespawn (5), PrRefill (5), PrBotLevel (30), PrBotXpMul (0.1), PrDifficultyDefault ("Normal").
-- Diagnostics: PracticeServerVersion, PracticeState ("off" / "notSandbox" / "lobby" / "match"), PrBots (alive), PrServerMs
--   (think time per tick, ms).
-- v1.1 (MDA-408, found in the Build 2026-11-10): the roster is built once at start (rebuild() before the first publish()), so
--   PrRoster lists the bots before anyone opens the lobby. 1.0 published an empty roster until the first "lobby" request.
-- v1.2 (MDA-408 / MDA-406, found in QA 2026-11-10: bots flung far up or out of the map; one 133 000 studs away pulled its
--   team's "home" (the average position the brain uses) off the island, so that team stopped playing the point):
--   * bots are spawned with PracticeBots 1.1 noCollide (bots don't collide with bots). Switch: script attribute
--     PrBotNoCollide (default true, read at each spawn; false = 1.1).
--   * a lost bot (no root part in Workspace, or the root more than PrLostDistance (2000) studs from the current point
--     centre, or below PrLostY (-150)) is removed and comes back after PrBotRespawn s like a dead one; no kill, no death.
--     It is left out of the team home. Switch: script attribute PrLostEnabled (default true, read per tick; false = 1.1).
--     Diagnostics: PrBotsLost (total), PrLastLost ("<name> <why>").
-- v1.3 (bot jobs, MDA-430, plan docs/plans/BOT_JOBS_v1.0.md Task 2; Kepu 2026-11-11 picks "C" and "1"):
--   * no T-Rex bots: each rolled bot's dino is picked here from PracticeRules.BOT_SPECIES (7, no TRex) and passed to rollBot
--     (rollPool and a refill bot). Switch: script attribute PrBotNoTRex (default true, read per roll; false = 1.2: any of 8).
--   * team brain: each team every PracticeRules.TEAM_EVERY (1) s, and on the next tick after a bot spawns,
--     R.dealJobs(that team's bots in roster order, {held = HpOcc is the team, humansOnPoint = the team's living humans on the
--     point, into (0 in the warm-up), pointTime, now = os.clock()}) -> rec.job / rec.jobWhy / rec.filledAt and the model's
--     BotJob / BotJobWhy. A spawn clears the bot's job (it gets its dino job, then the rules).
--   * ctx.jobs = true, ctx.taken[team][enemy model] = how many of that team's bots target it, ctx.duelTaken[team][enemy] = how
--     many of them are on the "duel" job (from the bots' targets at the start of the tick); PracticeBrain 1.1 uses them.
--   Switch: script attribute PrJobsEnabled (default true, read per tick; false = 1.2 roles, ctx.jobs nil).
--   Diagnostics: PrJobsA / PrJobsB ("hold n duel n guard n run n"), PrMaxOnOne (most bots of one team on one enemy this tick).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.2"
VERSION = "1.3" -- v1.3 bot jobs + no T-Rex bots
local THINK_HZ = 10
local BOT_BODY = 2
local DEFAULTS = {PracticeEnabled = true, PracticeTeamSize = 5, PrAutoStart = 20, PrBotRespawn = 5, PrRefill = 5, PrBotLevel = 30,
	PrBotXpMul = 0.1, PrDifficultyDefault = "Normal", PrBotNoCollide = true, PrLostEnabled = true, PrLostDistance = 2000, PrLostY = -150} -- v1.2: + the last four
script:SetAttribute("PracticeServerVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function get(k) local v = script:GetAttribute(k) if v == nil then return DEFAULTS[k] end return v end
for k, v in pairs({PrBotNoTRex = true, PrJobsEnabled = true}) do -- v1.3
	DEFAULTS[k] = v
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local DA = ServerStorage:WaitForChild("DinoArcade")
local ModeRules = require(DA:WaitForChild("ModeRules"))
local rulesModule = DA:WaitForChild("PracticeRules")
local R = require(rulesModule)
local H = require(DA:WaitForChild("HardpointRules"))
local SkillTree = require(DA:WaitForChild("SkillTree"))
local Bots = require(script:WaitForChild("PracticeBots"))
local Brain = require(script:WaitForChild("PracticeBrain"))

if script:GetAttribute("PracticeEnabled") == false then
	script:SetAttribute("PracticeState", "off")
	return
end
if ModeRules.currentMode() ~= "sandbox" then
	script:SetAttribute("PracticeState", "notSandbox")
	return
end

-- client copy of the rules
local shared = ReplicatedStorage:FindFirstChild("PracticeShared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "PracticeShared"
	shared.Parent = ReplicatedStorage
end
if shared:FindFirstChild("PracticeRules") then shared.PracticeRules:Destroy() end
rulesModule:Clone().Parent = shared

local state = ReplicatedStorage:FindFirstChild("Practice")
if not state then
	state = Instance.new("Folder")
	state.Name = "Practice"
	state.Parent = ReplicatedStorage
end
local function set(k, v) if state:GetAttribute(k) ~= v then state:SetAttribute(k, v) end end

local remote = ReplicatedStorage:FindFirstChild("PracticeRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "PracticeRequest"
	remote.Parent = ReplicatedStorage
end

local function now() return workspace:GetServerTimeNow() end
local rng = Random.new()

local hs = ServerScriptService:WaitForChild("HardpointServer")
local hpFn = hs:WaitForChild("HardpointPractice", 30)
local pickFn = hs:WaitForChild("HardpointPickSpawn", 30)
local endedEv = hs:WaitForChild("HardpointPracticeEnded", 30)
local hpState = ReplicatedStorage:WaitForChild("Hardpoint", 30)

local island = workspace:WaitForChild("DinoIsland", 30)
local botFolder = island and island:FindFirstChild("Bots")
if island and not botFolder then
	botFolder = Instance.new("Folder")
	botFolder.Name = "Bots"
	botFolder.Parent = island
end
Brain.init()

-- ---------- roster ----------
local phase = "lobby"
local difficulty = get("PrDifficultyDefault")
local size = math.clamp(math.floor(tonumber(get("PracticeTeamSize")) or 5), 1, 5)
local pool = {} -- rolled bot specs (2 x size)
local humans = {} -- ordered {player, want}
local slots = {A = {}, B = {}} -- {kind, player | spec, bot record}
local botRecs = {} -- live bot records {spec, team, model, hrp, hum, species, role, deadAt, respawnAt, ...}
local lastNewBots = 0

-- v1.3: the dino for a new bot (nil = rollBot picks any, as 1.2)
local function botSpecies()
	if get("PrBotNoTRex") == false or not R.BOT_SPECIES then return nil end
	return R.BOT_SPECIES[rng:NextInteger(1, #R.BOT_SPECIES)]
end
local jobsDirty, lastJobs = true, 0 -- v1.3

local function rollPool()
	local used = {}
	pool = {}
	for i = 1, size * 2 do pool[i] = R.rollBot(rng, used, SkillTree, get("PrBotLevel"), botSpecies()) end -- v1.3: + species
end
rollPool()

local function humanIndex(pl)
	for i, h in ipairs(humans) do if h.player == pl then return i end end
	return nil
end

local function partNames(spec)
	local out = {}
	for _, id in ipairs(spec.loadout or {}) do
		if id and R.BOT_LIVE[id] then
			local p = SkillTree.PATHS[id]
			table.insert(out, p and p.name or id)
		end
	end
	return out
end

local function rebuild()
	local hlist = {}
	for _, h in ipairs(humans) do table.insert(hlist, {id = h.player, want = h.want}) end
	local r = R.fillRoster(hlist, pool, size)
	slots = {A = {}, B = {}}
	for _, side in ipairs({"A", "B"}) do
		for i, s in ipairs(r[side]) do
			if s.kind == "human" then
				slots[side][i] = {kind = "human", player = s.id}
				s.id:SetAttribute("PrSide", side)
			else
				slots[side][i] = {kind = "bot", spec = s.bot}
			end
		end
	end
	for pl in pairs(r.refused) do pl:SetAttribute("PrLastResult", "full") end
end

local function publish()
	local out = {A = {}, B = {}}
	for _, side in ipairs({"A", "B"}) do
		for _, s in ipairs(slots[side]) do
			if s.kind == "human" then
				local c = s.player.Character
				table.insert(out[side], {kind = "human", name = s.player.DisplayName, userId = s.player.UserId,
					species = c and c:GetAttribute("Species") or s.player:GetAttribute("DinoSpecies") or "", parts = {}})
			else
				table.insert(out[side], {kind = "bot", name = s.spec.name, species = s.spec.species, parts = partNames(s.spec)})
			end
		end
	end
	set("PrRoster", HttpService:JSONEncode(out))
	set("PrPhase", phase)
	set("PrDifficulty", difficulty)
	set("PrSize", size)
	ReplicatedStorage:SetAttribute("PracticeLive", phase == "match")
	script:SetAttribute("PracticeState", phase)
end

-- ---------- spawning ----------
local function groundCF(spot, centre)
	local look = centre and Vector3.new(centre.X - spot.X, 0, centre.Z - spot.Z) or Vector3.new(0, 0, -1)
	if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
	return CFrame.lookAt(spot, spot + look.Unit)
end

local function pick(who)
	local ok, spot, centre = pcall(function() return pickFn:Invoke(who) end)
	if ok and typeof(spot) == "Vector3" then return spot, centre end
	-- fallback: the SpawnLocation
	local sl = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	return sl and (sl.Position + Vector3.new(0, sl.Size.Y / 2, 0)) or Vector3.new(0, 20, 0), nil
end

local function spawnBot(rec)
	-- a stand-in model with the team so the spawn pick can read it
	local probe = Instance.new("Model")
	probe:SetAttribute("HardpointBotTeam", rec.team)
	local spot, centre = pick(probe)
	probe:Destroy()
	local model = Bots.spawn(rec.spec, rec.team, groundCF(spot, centre), botFolder, {xpMul = get("PrBotXpMul"),
		noCollide = get("PrBotNoCollide") ~= false}) -- v1.2: + noCollide
	if not model then return end
	rec.model, rec.hrp, rec.hum, rec.species = model, model:FindFirstChild("HumanoidRootPart"), model:FindFirstChildOfClass("Humanoid"), rec.spec.species
	rec.deadAt, rec.respawnAt, rec.busy, rec.target, rec.path, rec.wp = nil, nil, false, nil, nil, nil
	rec.goalPoint, rec.holdUntil = nil, nil
	model:SetAttribute("BotRole", rec.role or "cap")
	rec.job, rec.jobWhy, rec.filledAt = nil, nil, nil -- v1.3: the team brain gives it its dino job on the next tick
	jobsDirty = true
	pcall(function() hpFn:Invoke("bot", model, rec.team) end)
end

local function despawnBot(rec)
	if rec.model then
		pcall(function() hpFn:Invoke("unbot", rec.model) end)
		rec.model:Destroy()
	end
	rec.model, rec.hrp, rec.hum = nil, nil, nil
end

local function placeHuman(pl)
	local c = pl.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then return end
	local spot, centre = pick(pl)
	local cf = groundCF(spot + Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight + 0.3, 0), centre)
	c:PivotTo(cf * c:GetPivot():ToObjectSpace(hrp.CFrame):Inverse())
	hrp.AssemblyLinearVelocity = Vector3.zero
	pl:SetAttribute("PrPlacedAt", now())
end

local function dealRoles()
	for _, side in ipairs({"A", "B"}) do
		local list = {}
		for _, rec in ipairs(botRecs) do if rec.team == side then table.insert(list, rec) end end
		local roles = R.assignRoles(#list, rng)
		for i, rec in ipairs(list) do
			rec.role = roles[i]
			if rec.model then rec.model:SetAttribute("BotRole", rec.role) end
		end
	end
end

-- ---------- match flow ----------
local function setHuman(pl, inLobby, inMatch, side)
	pl:SetAttribute("PrInLobby", inLobby)
	pl:SetAttribute("PrInMatch", inMatch)
	pl:SetAttribute("HardpointTeam", inMatch and side or nil)
end

local function startMatch()
	if phase == "match" then return "busy" end
	if #humans == 0 then return "nobody" end
	rebuild()
	phase = "match"
	set("PrStartAt", 0)
	local ok, r = pcall(function() return hpFn:Invoke("start") end)
	if not ok or r ~= "ok" then
		phase = "lobby"
		publish()
		return "hardpoint " .. tostring(r)
	end
	botRecs = {}
	for _, side in ipairs({"A", "B"}) do
		for _, s in ipairs(slots[side]) do
			if s.kind == "bot" then
				local rec = {spec = s.spec, team = side}
				s.rec = rec
				table.insert(botRecs, rec)
			else
				setHuman(s.player, false, true, side)
			end
		end
	end
	dealRoles()
	for _, rec in ipairs(botRecs) do spawnBot(rec) end
	publish()
	return "ok"
end

local function toLobby(result)
	for _, rec in ipairs(botRecs) do despawnBot(rec) end
	botRecs = {}
	phase = "lobby"
	set("PrResult", result or "")
	for _, h in ipairs(humans) do setHuman(h.player, true, false, nil) end
	set("PrStartAt", #humans > 0 and (now() + get("PrAutoStart")) or 0)
	rebuild()
	publish()
end

endedEv.Event:Connect(function(w)
	if phase == "match" then toLobby(w) end
end)

-- a slot's bot for a leaving human (match) / a human taking a bot's slot
local function botForSlot(side, idx)
	local s = slots[side][idx]
	local spec = R.rollBot(rng, (function() local u = {} for _, r in ipairs(botRecs) do u[r.spec.name] = true end return u end)(), SkillTree, get("PrBotLevel"), botSpecies()) -- v1.3: + species
	local rec = {spec = spec, team = side}
	slots[side][idx] = {kind = "bot", spec = spec, rec = rec}
	table.insert(botRecs, rec)
	rec.role = "cap"
	task.delay(get("PrRefill"), function()
		if phase == "match" and table.find(botRecs, rec) and not rec.model then spawnBot(rec) end
	end)
	return s
end

local function removeHuman(pl, why)
	local i = humanIndex(pl)
	if not i then return end
	table.remove(humans, i)
	if phase == "match" then
		for _, side in ipairs({"A", "B"}) do
			for k, s in ipairs(slots[side]) do
				if s.kind == "human" and s.player == pl then botForSlot(side, k) end
			end
		end
		setHuman(pl, false, false, nil)
		if #humans == 0 then
			pcall(function() hpFn:Invoke("stop") end)
			toLobby("")
			return
		end
	else
		setHuman(pl, false, false, nil)
		rebuild()
	end
	if #humans == 0 then set("PrStartAt", 0) end
	publish()
end

local function joinMatch(pl)
	-- the smaller side by humans + bots alive is always size; take a bot slot on the side behind
	local nA, nB = 0, 0
	for _, s in ipairs(slots.A) do if s.kind == "human" then nA += 1 end end
	for _, s in ipairs(slots.B) do if s.kind == "human" then nB += 1 end end
	local side = R.pickSide(nA, nB, hpState:GetAttribute("HpScoreA"), hpState:GetAttribute("HpScoreB"))
	local other = side == "A" and "B" or "A"
	for _, sd in ipairs({side, other}) do
		for k, s in ipairs(slots[sd]) do
			if s.kind == "bot" then
				if s.rec then
					despawnBot(s.rec)
					local j = table.find(botRecs, s.rec)
					if j then table.remove(botRecs, j) end
				end
				slots[sd][k] = {kind = "human", player = pl}
				table.insert(humans, {player = pl, want = sd})
				pl:SetAttribute("PrSide", sd)
				setHuman(pl, false, true, sd)
				publish()
				return "ok"
			end
		end
	end
	return "full"
end

-- ---------- requests ----------
local lastReq = {}
remote.OnServerEvent:Connect(function(pl, action, arg)
	if os.clock() - (lastReq[pl] or 0) < 0.2 then pl:SetAttribute("PrLastResult", "busy") return end
	lastReq[pl] = os.clock()
	local r = "badArg"
	if action == "lobby" then
		if humanIndex(pl) and (pl:GetAttribute("PrInLobby") or pl:GetAttribute("PrInMatch")) then
			r = "already"
		elseif phase == "match" then
			r = joinMatch(pl)
		else
			table.insert(humans, {player = pl, want = "auto"})
			setHuman(pl, true, false, nil)
			if (state:GetAttribute("PrStartAt") or 0) == 0 then set("PrStartAt", now() + get("PrAutoStart")) end
			rebuild()
			publish()
			r = "ok"
		end
	elseif action == "join" then
		local i = humanIndex(pl)
		if phase ~= "lobby" or not i then
			r = "notInLobby"
		elseif arg ~= "A" and arg ~= "B" and arg ~= "auto" then
			r = "badArg"
		else
			local n = 0
			if arg ~= "auto" then for _, h in ipairs(humans) do if h.player ~= pl and h.want == arg then n += 1 end end end
			if n >= size then
				r = "full"
			else
				humans[i].want = arg
				rebuild()
				publish()
				r = "ok"
			end
		end
	elseif action == "difficulty" then
		if R.DIFF[arg] then difficulty = arg; publish(); r = "ok" end
	elseif action == "newbots" then
		if phase ~= "lobby" then
			r = "notInLobby"
		elseif os.clock() - lastNewBots < 1 then
			r = "busy"
		else
			lastNewBots = os.clock()
			rollPool()
			rebuild()
			publish()
			r = "ok"
		end
	elseif action == "start" then
		r = (phase == "lobby" and humanIndex(pl)) and startMatch() or "notInLobby"
	elseif action == "leave" then
		removeHuman(pl, "leave")
		r = "ok"
	end
	pl:SetAttribute("PrLastResult", r)
	pl:SetAttribute("PrLastAt", now())
end)

-- ---------- humans: place on play / respawn; leaving the match through the menu ----------
local function onPlayer(pl)
	pl:GetAttributeChangedSignal("InMenu"):Connect(function()
		if pl:GetAttribute("InMenu") == false and pl:GetAttribute("PrInMatch") == true then
			task.delay(0.3, placeHuman, pl)
		elseif pl:GetAttribute("InMenu") == true and pl:GetAttribute("PrInMatch") == true and phase == "match" then
			removeHuman(pl, "menu")
		end
	end)
	pl.CharacterAdded:Connect(function(c)
		if pl:GetAttribute("PrInMatch") ~= true or pl:GetAttribute("InMenu") == true then return end
		task.delay(0.6, function()
			local want = pl:GetAttribute("DinoSpecies")
			if pl.Character == c and (want == nil or c:GetAttribute("Species") == want) then placeHuman(pl) end
		end)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, pl) end
Players.PlayerRemoving:Connect(function(pl) removeHuman(pl, "quit") lastReq[pl] = nil end)

-- ---------- the loop ----------
local acc, lastIndex = 0, nil
rebuild() -- v1.1
publish()
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 / THINK_HZ then return end
	local step = acc
	acc = 0
	if phase == "lobby" then
		local at = state:GetAttribute("PrStartAt") or 0
		if at > 0 and now() >= at and #humans > 0 then startMatch() end
		return
	end
	local t0 = os.clock()
	-- point info
	local idx = hpState:GetAttribute("HpIndex") or 1
	local warm = hpState:GetAttribute("HpPhase") == "warmup"
	local pts = {}
	local okP, list = pcall(function() return HttpService:JSONDecode(hpState:GetAttribute("HpPoints") or "[]") end)
	if okP then for i, p in ipairs(list) do pts[i] = Vector3.new(p.x, p.y, p.z) end end
	if lastIndex ~= idx and not warm then
		lastIndex = idx
		dealRoles()
	end
	local endsAt = hpState:GetAttribute("HpPointEndsAt") or now()
	local ctx = {bots = botRecs, R = R, H = H, diff = R.diffOf(difficulty), rng = rng, centre = pts[warm and 1 or idx],
		nextCentre = pts[hpState:GetAttribute("HpNextIndex") or 1], into = H.POINT_TIME - (endsAt - now()), pointTime = H.POINT_TIME,
		index = idx}
	-- v1.3: team brain + who targets whom (see the header)
	if get("PrJobsEnabled") ~= false and R.dealJobs then
		ctx.jobs = true
		local function fd(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end
		if jobsDirty or os.clock() - lastJobs >= (R.TEAM_EVERY or 1) then
			jobsDirty, lastJobs = false, os.clock()
			local occ = hpState:GetAttribute("HpOcc")
			for _, side in ipairs({"A", "B"}) do
				local list = {}
				for _, rec in ipairs(botRecs) do
					if rec.team == side then
						local live = rec.model ~= nil and rec.model.Parent ~= nil and rec.hrp ~= nil and rec.hrp.Parent ~= nil
							and not rec.deadAt and (tonumber(rec.model:GetAttribute("DummyHealth")) or 0) > 0
						local pos = live and rec.hrp.Position or nil
						table.insert(list, {id = rec, species = rec.spec and rec.spec.species, alive = live,
							dPoint = (pos and ctx.centre) and fd(pos, ctx.centre) or math.huge,
							dNext = (pos and ctx.nextCentre) and fd(pos, ctx.nextCentre) or math.huge,
							job = rec.job, why = rec.jobWhy, filledAt = rec.filledAt})
					end
				end
				local humansOn = 0
				for _, h in ipairs(humans) do
					local pl = h.player
					local c = pl and pl.Character
					local r = c and c:FindFirstChild("HumanoidRootPart")
					local hum = c and c:FindFirstChildOfClass("Humanoid")
					if r and hum and hum.Health > 0 and pl:GetAttribute("HardpointTeam") == side and pl:GetAttribute("PrInMatch") == true
						and ctx.centre and H.inPoint(r.Position, ctx.centre) then humansOn += 1 end
				end
				local res = R.dealJobs(list, {held = occ == side, humansOnPoint = humansOn, into = warm and 0 or ctx.into,
					pointTime = H.POINT_TIME, now = os.clock()})
				local n = {hold = 0, duel = 0, guard = 0, run = 0}
				for rec, e in pairs(res) do
					rec.job, rec.jobWhy, rec.filledAt = e.job, e.why, e.filledAt
					if rec.model then
						if rec.model:GetAttribute("BotJob") ~= e.job then rec.model:SetAttribute("BotJob", e.job) end
						if rec.model:GetAttribute("BotJobWhy") ~= e.why then rec.model:SetAttribute("BotJobWhy", e.why) end
						if n[e.job] and rec.model.Parent and not rec.deadAt then n[e.job] += 1 end
					end
				end
				script:SetAttribute("PrJobs" .. side, ("hold %d duel %d guard %d run %d"):format(n.hold, n.duel, n.guard, n.run))
			end
		end
		ctx.taken, ctx.duelTaken = {A = {}, B = {}}, {A = {}, B = {}}
		local most = 0
		for _, rec in ipairs(botRecs) do
			local t = rec.model and rec.model.Parent and not rec.deadAt and rec.target
			if t and ctx.taken[rec.team] then
				ctx.taken[rec.team][t] = (ctx.taken[rec.team][t] or 0) + 1
				most = math.max(most, ctx.taken[rec.team][t])
				if rec.job == "duel" then ctx.duelTaken[rec.team][t] = (ctx.duelTaken[rec.team][t] or 0) + 1 end
			end
		end
		if script:GetAttribute("PrMaxOnOne") ~= most then script:SetAttribute("PrMaxOnOne", most) end
	end
	local alive = 0
	-- v1.2: lost bots (see the header)
	if get("PrLostEnabled") ~= false then
		local c = ctx.centre
		for _, rec in ipairs(botRecs) do
			if rec.model and rec.model.Parent and not rec.deadAt then
				local why
				if not (rec.hrp and rec.hrp:IsDescendantOf(workspace)) then
					why = "noRoot"
				elseif rec.hrp.Position.Y < get("PrLostY") then
					why = "low"
				elseif c and (rec.hrp.Position - c).Magnitude > get("PrLostDistance") then
					why = "far"
				end
				if why then
					despawnBot(rec)
					rec.respawnAt = os.clock() + get("PrBotRespawn")
					script:SetAttribute("PrBotsLost", (script:GetAttribute("PrBotsLost") or 0) + 1)
					script:SetAttribute("PrLastLost", rec.spec.name .. " " .. why)
				end
			end
		end
	end
	-- team homes (average position)
	local sum = {A = Vector3.zero, B = Vector3.zero}
	local cnt = {A = 0, B = 0}
	for _, rec in ipairs(botRecs) do
		if rec.model and rec.hrp and rec.hrp.Parent then
			sum[rec.team] += rec.hrp.Position
			cnt[rec.team] += 1
		end
	end
	for _, rec in ipairs(botRecs) do
		if rec.model then
			local dead = (tonumber(rec.model:GetAttribute("DummyHealth")) or 0) <= 0 or not rec.model.Parent
			if dead then
				if not rec.deadAt then
					rec.deadAt = os.clock()
					rec.model:SetAttribute("BotState", "dead")
				elseif os.clock() - rec.deadAt > BOT_BODY then
					despawnBot(rec)
					rec.respawnAt = os.clock() + math.max(0, get("PrBotRespawn") - BOT_BODY)
				end
			else
				alive += 1
				ctx.home = cnt[rec.team] > 0 and sum[rec.team] / cnt[rec.team] or nil
				local ok, err = pcall(Brain.step, rec, ctx)
				if not ok then script:SetAttribute("PrBrainError", tostring(err)) end
			end
		elseif rec.respawnAt and os.clock() >= rec.respawnAt then
			rec.respawnAt = nil
			spawnBot(rec)
		end
	end
	script:SetAttribute("PrBots", alive)
	script:SetAttribute("PrServerMs", math.floor((os.clock() - t0) * 10000 + 0.5) / 10)
end)
