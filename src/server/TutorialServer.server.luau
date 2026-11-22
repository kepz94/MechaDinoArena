-- TutorialServer v1.0 (Mecha Dino Arena) — the first-time flow's server side: steps, training lanes, the training bot and the
-- one XP grant (Script, ServerScriptService). MDA-561, plan docs/plans/FIRST_TIME_FLOW_v1.0.md Task 3, ADR-013, mockup
-- docs/mockups/first_time_flow_v0.3.html. Kepu 2026-11-22: welcome -> roll a free dino -> its parts -> first attack -> equip ->
--   try the parts -> the first kill on a training bot levels the dino up -> spend the point -> what points do -> the island.
--   Picks: "A + B's cards", no skip, "Training area"; old players replay it from the menu (TUTORIAL).
-- Runs on hub and practice kinds of the Sandbox place (ModeRules.currentMode() == "sandbox"); TutorialEnabled false -> nothing.
-- Lanes: built at start, TrainingLanes (8) copies in Workspace.TrainingGround ("Lane1".."LaneN") at TrainingOrigin
--   (Vector3, default (0, 400, 4000), off the island) + (lane - 1) x TrainingSpacing (300) on X. Each lane: a TrainingPad
--   (LanePad x 1.2 x LanePad, Grass, 120), invisible walls (LaneWall 30 high) on the 4 edges, fence posts every 12 studs,
--   a "TRAINING" sign, the player mark (PlayerMark) on the south side facing north and the bot mark (BotMark)
--   TutBotDistance (28) studs north of it.
-- Player attributes (all written here): TutStep (0 = not in the flow, 1..10 = TutorialRules.STEPS), TutLane (0 / lane),
--   TutReplay (bool), TutRolled ("" / dino key, the egg's answer), TutHit (step 4 done), TutUsed ("" / "1,2,3,4" slots the
--   client reported), TutNeed (parts to equip / use: min(4, button parts the dino has)), TutKilled (step 7 kill seen),
--   TutPtsStart (SkillSpent when step 8 began), TutLastResult.
-- Requests: RemoteEvent ReplicatedStorage.TutorialRequest(action, arg). Every request is judged on the current TutStep:
--   "next" at 1 -> 2 | at 2 when TutRolled ~= "" -> 3 | at 3 -> into the lane, 4 | at 4 when TutHit -> 5 |
--          at 5 when SkillSlot1..TutNeed are all set -> 6 | at 6 when TutUsed holds 1..TutNeed -> 7 (bot to finish health) |
--          at 7 when TutKilled -> 8 | at 8 when SkillSpent > TutPtsStart, or SkillLeft == 0 on a replay -> 9 | at 9 -> 10.
--          Anything else -> TutLastResult "notYet".
--   "roll" at 2 -> DinoOwnership OwnRoll; TutRolled = the key (DinoSpecies is set by OwnRoll).
--   "used", n (1..4) at 6 -> n added to TutUsed (MechaButtonsLastPress is only seen by the client).
--   "island" at 10 -> DinoOwnership OwnFinishTut (not on a replay), lane and bot freed, TutStep 0, a new body on the island.
--   "replay" with TutState "done" / "grand", TutStep 0 -> TutReplay = true, straight into a lane at step 4 (no roll, no
--          free parts, no XP grant).
-- New players: TutState "new" -> TutStep 1; "resume" -> TutStep 3 (DinoOwnership 1.0).
-- Into the lane: a free lane (none -> TutLastResult "full", the client asks again), InMenu = false, TutLane set, a new body
--   (player:LoadCharacter(); SpeciesServer swaps it to DinoSpecies), placed on the player mark once its Species matches
--   (TutPlaceWait (10) s at most), then the bot. Every later body of that player (death) is placed there again.
-- The bot: PracticeBots.spawn (species TutBotSpecies "Pachy", passive: no brain), SkillXpMul 0, model attributes TutOwner
--   (UserId) and TutBot = true. Steps 4..6: DummyMaxHealth / DummyHealth = TutBotSafeHealth (100000), refilled to max
--   whenever it drops under half (it cannot die). Step 7: DummyHealth = TutBotFinishHealth (40). A drop of DummyHealth at step
--   4 sets TutHit. KilledAt at step 7 -> TutKilled; when not a replay, SkillGrantXp(player, SkillXPNext - SkillXPInto,
--   "training") (SkillServer 1.10) so the dino reaches the next level (1 skill point). The body is removed after 2 s. A bot
--   killed before step 7 or lost (more than TutBotLeash (60) studs from its mark or under the pad) is put back on its mark.
-- Leaving the game frees the lane and removes the bot (a "resume" player starts again at step 3 next time).
-- Script attributes: TutorialEnabled (true), TrainingOrigin, TrainingLanes, TrainingSpacing, LanePad (120), LaneWall (30),
--   TutBotSpecies, TutBotDistance, TutBotSafeHealth, TutBotFinishHealth, TutBotLeash, TutPlaceWait, TutUnlockTextOn (false:
--   the client shows "Coming soon." for unlocking dinos; red-team 5). Diagnostics: TutorialServerVersion, TutorialState
--   ("off" / "notSandbox" / "on"), TutLanesUsed, TutFinished, TutGrants.
-- v1.0.1 (found in the Studio check 2026-11-22: the Therizino's claws never hit the training bot; the attack servers only
--   target models in Workspace.DinoIsland.Bots): the bot is parented to Workspace.DinoIsland.Bots (made if missing) while it
--   stands in its lane, like the practice bots. Clients find it there by TutOwner. Switch: script attribute TutBotIslandFolder
--   (default true, read per spawn; false = the lane's own Bots folder, 1.0).
-- v1.1 (first-time flow v1.1, mockup docs/mockups/first_time_flow_v0.4.html; Kepu 2026-11-22 11:38 "The teno has two different
--   attack styles and it doesn't even teach you it", 12:09 "Build"):
--   * Step 4 is a list of attack lessons (TutorialRules 1.1 lessonsFor(dino)): player attributes TutLesson (1-based, the current
--     one) and TutLessonsDone ("1,2"). A lesson completes on its event (TutorialRules.lessonEvent): "hit" = the bot lost health,
--     "stamp" = a character attribute the attack server writes (TenoSlamAt, DiloSnipeAt, TheriComboStep >= 3). When every
--     lesson is done: TutHit = true and, TutAutoNext (1.2) s later, step 5 by itself ("next" still works).
--   * Step 6 moves to 7 by itself TutAutoNext s after the last part is used ("next" still works).
--   * Only "next" is gapped (0.15 s); "roll" / "used" are not (fast taps and keys were dropped as "busy").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.0.1" -- v1.0.1 the bot stands in DinoIsland.Bots
VERSION = "1.1" -- v1.1 attack lessons, auto-advance
script:SetAttribute("TutorialServerVersion", VERSION)
local DEFAULTS = {TutorialEnabled = true, TrainingOrigin = Vector3.new(0, 400, 4000), TrainingLanes = 8, TrainingSpacing = 300,
	LanePad = 120, LaneWall = 30, TutBotSpecies = "Pachy", TutBotDistance = 28, TutBotSafeHealth = 100000, TutBotFinishHealth = 40,
	TutBotLeash = 60, TutPlaceWait = 10, TutUnlockTextOn = false, TutBotIslandFolder = true, TutAutoNext = 1.2}
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
for k, v in pairs({TutLanesUsed = 0, TutFinished = 0, TutGrants = 0}) do script:SetAttribute(k, script:GetAttribute(k) or v) end
local function A(k) local v = script:GetAttribute(k) if v == nil then return DEFAULTS[k] end return v end

if A("TutorialEnabled") == false then script:SetAttribute("TutorialState", "off") return end
local DinoArcade = ServerStorage:WaitForChild("DinoArcade")
local okMode, ModeRules = pcall(require, DinoArcade:WaitForChild("ModeRules", 10))
if okMode and ModeRules and ModeRules.currentMode and ModeRules.currentMode() ~= "sandbox" then
	script:SetAttribute("TutorialState", "notSandbox")
	return
end
script:SetAttribute("TutorialState", "on")

local R = require(DinoArcade:WaitForChild("TutorialRules"))
local ST = require(DinoArcade:WaitForChild("SkillTree"))
local Bots = require(ServerScriptService:WaitForChild("PracticeServer"):WaitForChild("PracticeBots"))
local own = ServerScriptService:WaitForChild("DinoOwnership")
local ownRoll, ownFinish = own:WaitForChild("OwnRoll"), own:WaitForChild("OwnFinishTut")
local grantFn = ServerScriptService:WaitForChild("SkillServer"):WaitForChild("SkillGrantXp", 30)

-- the client copy of the rules
do
	local old = ReplicatedStorage:FindFirstChild("TutorialShared")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "TutorialShared"
	DinoArcade.TutorialRules:Clone().Parent = f
	f.Parent = ReplicatedStorage
end
ReplicatedStorage:SetAttribute("TutUnlockTextOn", A("TutUnlockTextOn") == true)
script:GetAttributeChangedSignal("TutUnlockTextOn"):Connect(function()
	ReplicatedStorage:SetAttribute("TutUnlockTextOn", A("TutUnlockTextOn") == true)
end)

local remote = ReplicatedStorage:FindFirstChild("TutorialRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "TutorialRequest"
	remote.Parent = ReplicatedStorage
end

-- ---------- lanes ----------
local ground = workspace:FindFirstChild("TrainingGround")
if ground then ground:Destroy() end
ground = Instance.new("Folder")
ground.Name = "TrainingGround"
local lanes = {} -- [i] = {model, playerCF, botCF, owner}
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
local function buildLane(i)
	local origin = R.laneCFrame(CFrame.new(A("TrainingOrigin")), i, A("TrainingSpacing"))
	local size, wallH = A("LanePad"), A("LaneWall")
	local m = Instance.new("Model")
	m.Name = "Lane" .. i
	part({Name = "TrainingPad", Size = Vector3.new(size, 1.2, size), CFrame = origin, Material = Enum.Material.Grass,
		Color = Color3.fromRGB(86, 140, 62)}, m)
	for _, e in ipairs({{0, size / 2, size, 2}, {0, -size / 2, size, 2}, {size / 2, 0, 2, size}, {-size / 2, 0, 2, size}}) do
		part({Name = "LaneWall", Size = Vector3.new(e[3], wallH, e[4]), CFrame = origin * CFrame.new(e[1], wallH / 2, e[2]),
			Transparency = 1, CanCollide = true}, m)
		local n = math.floor((e[3] > e[4] and e[3] or e[4]) / 12)
		for k = 0, n do
			local t = -size / 2 + k * size / n
			local x, z = e[3] > e[4] and t or e[1], e[3] > e[4] and e[2] or t
			part({Name = "FencePost", Size = Vector3.new(0.8, 4, 0.8), CFrame = origin * CFrame.new(x, 2.6, z),
				Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 78, 44), CanCollide = false}, m)
		end
	end
	local sign = part({Name = "Sign", Size = Vector3.new(24, 6, 1), CFrame = origin * CFrame.new(0, 14, -size / 2 + 4),
		Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(70, 52, 30), CanCollide = false}, m)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "TRAINING"
	tl.TextScaled = true
	tl.Font = Enum.Font.FredokaOne
	tl.TextColor3 = Color3.fromRGB(255, 200, 50)
	tl.Parent = sg
	sg.Parent = sign
	local playerCF = origin * CFrame.new(0, 0.6, A("TutBotDistance") / 2) -- faces -Z (north)
	local botCF = origin * CFrame.new(0, 0.6, -A("TutBotDistance") / 2) * CFrame.Angles(0, math.pi, 0)
	part({Name = "PlayerMark", Size = Vector3.new(6, 0.2, 6), CFrame = playerCF * CFrame.new(0, 0.1, 0),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 200, 255), Transparency = 0.6, CanCollide = false}, m)
	part({Name = "BotMark", Size = Vector3.new(10, 0.2, 10), CFrame = botCF * CFrame.new(0, 0.1, 0),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 50), Transparency = 0.7, CanCollide = false}, m)
	local bots = Instance.new("Folder")
	bots.Name = "Bots"
	bots.Parent = m
	m.Parent = ground
	lanes[i] = {model = m, playerCF = playerCF, botCF = botCF, bots = bots, owner = nil}
end
for i = 1, A("TrainingLanes") do buildLane(i) end
ground.Parent = workspace

-- ---------- per player ----------
local st = {} -- [player] = {bot, conns, laneConn, grantDone}
local function setStep(p, n) p:SetAttribute("TutStep", n) end
local function step(p) return p:GetAttribute("TutStep") or 0 end
local function result(p, why) p:SetAttribute("TutLastResult", why) end
local function laneUsed()
	local n = 0
	for _, l in ipairs(lanes) do if l.owner then n += 1 end end
	script:SetAttribute("TutLanesUsed", n)
end

local function speciesKey(p)
	local c = p.Character
	return (c and c:GetAttribute("Species")) or p:GetAttribute("DinoSpecies") or "TRex"
end
local function needParts(p) -- min(4, button parts the active dino has)
	local dino, n = speciesKey(p), 0
	for _, id in ipairs(ST.PATH_ORDER) do
		local path = ST.PATHS[id]
		if path and ST.BUTTONS[id] and not path.soon and (not ST.seesPath or ST.seesPath(path, dino))
			and (tonumber(p:GetAttribute("SkillPath_" .. id)) or 0) >= 1 then
			n += 1
		end
	end
	return math.min(4, n)
end

local function clearBot(p)
	local s = st[p]
	if not s then return end
	for _, c in ipairs(s.botConns or {}) do c:Disconnect() end
	s.botConns = {}
	if s.bot and s.bot.Parent then s.bot:Destroy() end
	s.bot = nil
end

-- v1.1: attack lessons (see the header)
local STAMPS = {TenoSlamAt = true, DiloSnipeAt = true, TheriComboStep = true}
local function lessonEvent(p, ev)
	if step(p) ~= 4 or not st[p] then return end
	local ls = R.lessonsFor(speciesKey(p))
	local done = R.parseDone(p:GetAttribute("TutLessonsDone"))
	local cur = tonumber(p:GetAttribute("TutLesson")) or 1
	local L = ls[cur]
	if not L or done[cur] or not R.lessonEvent(L, ev) then return end
	done[cur] = true
	p:SetAttribute("TutLessonsDone", R.doneString(done))
	if cur < #ls then
		p:SetAttribute("TutLesson", cur + 1)
		return
	end
	p:SetAttribute("TutHit", true)
	local tok = os.clock()
	st[p].autoTok = tok
	task.delay(A("TutAutoNext"), function()
		if st[p] and st[p].autoTok == tok and step(p) == 4 then
			p:SetAttribute("TutNeed", needParts(p))
			setStep(p, 5)
			result(p, "auto 5")
		end
	end)
end
local function hookStamps(p, c)
	c.AttributeChanged:Connect(function(name)
		if STAMPS[name] and step(p) == 4 then lessonEvent(p, {kind = "stamp", name = name, value = c:GetAttribute(name)}) end
	end)
end

local spawnBot
local function botHealth(bot, n)
	bot:SetAttribute("DummyMaxHealth", n)
	bot:SetAttribute("DummyHealth", n)
end
spawnBot = function(p)
	local s = st[p]
	local lane = s and lanes[p:GetAttribute("TutLane") or 0]
	if not lane then return end
	clearBot(p)
	local folder = lane.bots
	if A("TutBotIslandFolder") ~= false then -- v1.0.1: where the attack servers look for bots
		local isl = workspace:FindFirstChild("DinoIsland")
		if isl then
			folder = isl:FindFirstChild("Bots")
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = "Bots"
				folder.Parent = isl
			end
		end
	end
	local bot = Bots.spawn({species = A("TutBotSpecies"), name = "Training Bot", loadout = {}, steps = {}}, "B", lane.botCF,
		folder, {xpMul = 0})
	if not bot then result(p, "noBot") return end
	bot:SetAttribute("TutOwner", p.UserId)
	bot:SetAttribute("TutBot", true)
	bot:SetAttribute("SkillXpMul", 0)
	botHealth(bot, step(p) >= 7 and A("TutBotFinishHealth") or A("TutBotSafeHealth"))
	s.bot = bot
	s.botConns = {}
	local last = bot:GetAttribute("DummyHealth")
	table.insert(s.botConns, bot:GetAttributeChangedSignal("DummyHealth"):Connect(function()
		local hp = tonumber(bot:GetAttribute("DummyHealth")) or 0
		local dropped = last and hp < last
		last = hp
		if dropped and step(p) == 4 then lessonEvent(p, {kind = "hit"}) end -- v1.1 (1.0: TutHit on the first hit)
		if step(p) < 7 then
			local max = tonumber(bot:GetAttribute("DummyMaxHealth")) or A("TutBotSafeHealth")
			if hp < max / 2 then task.defer(function() if bot.Parent then bot:SetAttribute("DummyHealth", max) end end) end
		end
	end))
	table.insert(s.botConns, bot:GetAttributeChangedSignal("KilledAt"):Connect(function()
		if step(p) == 7 and p:GetAttribute("TutKilled") ~= true then
			p:SetAttribute("TutKilled", true)
			if p:GetAttribute("TutReplay") ~= true and not s.grantDone and grantFn then
				local need = (tonumber(p:GetAttribute("SkillXPNext")) or 0) - (tonumber(p:GetAttribute("SkillXPInto")) or 0)
				if need > 0 then
					local ok, why = pcall(function() return grantFn:Invoke(p, math.floor(need), "training") end)
					s.grantDone = ok and why == "ok"
					if s.grantDone then script:SetAttribute("TutGrants", (script:GetAttribute("TutGrants") or 0) + 1) end
					result(p, "grant " .. tostring(ok and why or "error"))
				end
			end
			task.delay(2, function() if s.bot == bot then clearBot(p) end end)
		elseif step(p) < 7 then
			task.delay(1, function() if s.bot == bot and st[p] then spawnBot(p) end end)
		end
	end))
end

local function placeBody(p, c)
	local lane = lanes[p:GetAttribute("TutLane") or 0]
	if not lane or not c then return end
	local want = p:GetAttribute("DinoSpecies")
	local t0 = os.clock()
	while c.Parent and p.Character == c and want and c:GetAttribute("Species") ~= want and os.clock() - t0 < A("TutPlaceWait") do
		task.wait(0.1)
	end
	task.wait(0.1)
	local c2 = p.Character
	local hrp = c2 and c2:FindFirstChild("HumanoidRootPart")
	local hum = c2 and c2:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) or (p:GetAttribute("TutLane") or 0) == 0 then return end
	local pos = lane.playerCF.Position + Vector3.new(0, 0.6 + hrp.Size.Y / 2 + hum.HipHeight + 0.5, 0)
	local look = lane.playerCF.LookVector
	pcall(function() hrp:SetNetworkOwner(nil) end)
	hrp.Anchored = true
	c2:PivotTo(CFrame.lookAt(pos, pos + look))
	hrp.AssemblyLinearVelocity = Vector3.zero
	c2:SetAttribute("ShoulderCamLookAt", pos + look * 500)
	task.delay(0.3, function()
		if hrp.Parent then
			hrp.Anchored = false
			pcall(function() hrp:SetNetworkOwnershipAuto() end)
		end
	end)
	task.delay(1, function() if c2.Parent then c2:SetAttribute("ShoulderCamLookAt", nil) end end)
end

local function enterLane(p)
	local free
	for i, l in ipairs(lanes) do
		if not l.owner then free = i break end
	end
	if not free then result(p, "full") return false end
	lanes[free].owner = p
	laneUsed()
	p:SetAttribute("TutLane", free)
	p:SetAttribute("TutHit", false)
	p:SetAttribute("TutUsed", "")
	p:SetAttribute("TutKilled", false)
	p:SetAttribute("TutLesson", 1) -- v1.1
	p:SetAttribute("TutLessonsDone", "")
	p:SetAttribute("InMenu", false)
	setStep(p, 4)
	task.spawn(function()
		p:LoadCharacter()
		local c = p.Character
		placeBody(p, c)
		p:SetAttribute("TutNeed", needParts(p))
		spawnBot(p)
	end)
	return true
end

local function leaveLane(p)
	clearBot(p)
	local i = p:GetAttribute("TutLane") or 0
	if lanes[i] and lanes[i].owner == p then lanes[i].owner = nil end
	p:SetAttribute("TutLane", 0)
	laneUsed()
end

local function slotsFilled(p, n)
	for k = 1, n do
		local v = p:GetAttribute("SkillSlot" .. k)
		if type(v) ~= "string" or v == "" then return false end
	end
	return true
end
local function usedAll(p, n)
	local set = {}
	for k in string.gmatch(p:GetAttribute("TutUsed") or "", "%d") do set[tonumber(k)] = true end
	for k = 1, n do if not set[k] then return false end end
	return true
end

local function onNext(p)
	local s = step(p)
	if s == 1 then setStep(p, 2)
	elseif s == 2 and (p:GetAttribute("TutRolled") or "") ~= "" then setStep(p, 3)
	elseif s == 3 then enterLane(p)
	elseif s == 4 and p:GetAttribute("TutHit") == true then
		p:SetAttribute("TutNeed", needParts(p))
		setStep(p, 5)
	elseif s == 5 and slotsFilled(p, p:GetAttribute("TutNeed") or 4) then setStep(p, 6)
	elseif s == 6 and usedAll(p, p:GetAttribute("TutNeed") or 4) then
		setStep(p, 7)
		local b = st[p] and st[p].bot
		if b and b.Parent then botHealth(b, A("TutBotFinishHealth")) end
	elseif s == 7 and p:GetAttribute("TutKilled") == true then
		p:SetAttribute("TutPtsStart", p:GetAttribute("SkillSpent") or 0)
		setStep(p, 8)
	elseif s == 8 and ((p:GetAttribute("SkillSpent") or 0) > (p:GetAttribute("TutPtsStart") or 0)
		or (p:GetAttribute("TutReplay") == true and (p:GetAttribute("SkillLeft") or 0) == 0)) then setStep(p, 9)
	elseif s == 9 then setStep(p, 10)
	else
		result(p, "notYet")
		return
	end
	result(p, "ok " .. step(p))
end

local function finish(p)
	local replay = p:GetAttribute("TutReplay") == true
	if not replay then pcall(function() ownFinish:Invoke(p) end) end
	leaveLane(p)
	setStep(p, 0)
	p:SetAttribute("TutReplay", false)
	script:SetAttribute("TutFinished", (script:GetAttribute("TutFinished") or 0) + 1)
	result(p, "island")
	p:SetAttribute("InMenu", false)
	task.spawn(function() p:LoadCharacter() end)
end

remote.OnServerEvent:Connect(function(p, action, arg)
	local s = st[p]
	if not s then return end
	if action == "next" then
		if os.clock() - (s.lastReq or 0) < 0.15 then result(p, "busy") return end -- v1.1: only "next" is gapped
		s.lastReq = os.clock()
		onNext(p)
	elseif action == "roll" and step(p) == 2 then
		local ok, key = pcall(function() return ownRoll:Invoke(p) end)
		if ok and type(key) == "string" then
			p:SetAttribute("TutRolled", key)
			result(p, "rolled " .. key)
		else
			result(p, "rollFailed")
		end
	elseif action == "used" and step(p) == 6 and type(arg) == "number" and arg >= 1 and arg <= 4 and arg % 1 == 0 then
		local cur = p:GetAttribute("TutUsed") or ""
		if not string.find(cur, tostring(arg), 1, true) then
			p:SetAttribute("TutUsed", cur == "" and tostring(arg) or (cur .. "," .. arg))
		end
		if usedAll(p, p:GetAttribute("TutNeed") or 4) then -- v1.1: on to step 7 by itself
			local tok = os.clock()
			s.autoTok = tok
			task.delay(A("TutAutoNext"), function()
				if st[p] and st[p].autoTok == tok and step(p) == 6 then onNext(p) end
			end)
		end
	elseif action == "island" and step(p) == 10 then
		finish(p)
	elseif action == "replay" and step(p) == 0 then
		local ts = p:GetAttribute("TutState")
		if ts == "done" or ts == "grand" then
			p:SetAttribute("TutReplay", true)
			s.grantDone = true
			if not enterLane(p) then p:SetAttribute("TutReplay", false) end
		else
			result(p, "notReplay")
		end
	else
		result(p, "badArg")
	end
end)

local function onPlayer(p)
	st[p] = {botConns = {}, grantDone = false}
	p:SetAttribute("TutStep", 0)
	p:SetAttribute("TutLane", 0)
	p:SetAttribute("TutReplay", false)
	p:SetAttribute("TutRolled", "")
	local function begin()
		local ts = p:GetAttribute("TutState")
		if step(p) ~= 0 then return end
		local first = R.startStep(ts, false)
		if first == 1 then setStep(p, 1)
		elseif first == 3 then
			local d = p:GetAttribute("FreeDino")
			p:SetAttribute("TutRolled", type(d) == "string" and d or "")
			if type(d) == "string" and d ~= "" then p:SetAttribute("DinoSpecies", d) end
			setStep(p, 3)
		end
	end
	p:GetAttributeChangedSignal("TutState"):Connect(begin)
	begin()
	if p.Character then hookStamps(p, p.Character) end -- v1.1
	p.CharacterAdded:Connect(function(c)
		hookStamps(p, c) -- v1.1
		if (p:GetAttribute("TutLane") or 0) > 0 and step(p) >= 4 then
			task.spawn(placeBody, p, c)
		end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p)
	leaveLane(p)
	st[p] = nil
end)

-- leash: a lost bot goes back to its mark
task.spawn(function()
	while true do
		task.wait(1)
		for p, s in pairs(st) do
			local b = s.bot
			local lane = lanes[p:GetAttribute("TutLane") or 0]
			local root = b and b.Parent and b:FindFirstChild("HumanoidRootPart")
			if root and lane and (b:GetAttribute("DummyHealth") or 1) > 0 then
				local off = root.Position - lane.botCF.Position
				if off.Magnitude > A("TutBotLeash") or off.Y < -10 then
					b:PivotTo(lane.botCF + Vector3.new(0, 6, 0))
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end
end)
