-- KillFeedServer v1.0 (Mecha Dino Arena) — who killed whom, for the kill feed and the scoreboard. MDA-411, plan
-- docs/plans/PRACTICE_MATCH_v1.0.md Task 7, mockup docs/mockups/practice_match_v0.1.html (v0.2; Kepu 2026-11-10 "Make sure you
-- have the kill feed down", phone rules "Yes, like that").
-- Victims watched:
--   * player characters while ArenaPvPBridged is true (ArenaPvP 1.3: the Arena, and the Sandbox during the practice match);
--   * practice bots: models with PracticeBot = true in Workspace.DinoIsland.Bots (PracticeBots 1.0).
-- A kill = a new KilledAt on the victim (every attack stamps KilledBy / KilledByUserId / KilledWith / KilledAt on the killing
--   blow). Fallback when a victim dies without a new KilledAt within FALLBACK_WAIT (0.4) s (player: Humanoid.Died; bot:
--   DummyHealth from above 0 to 0 or less): killer = LastHitBy when LastHitAt is at most KillFeedLastHitWindow (5) s old,
--   how = "". No killer -> no feed line; the death is still counted (KillFeedNoKiller += 1).
-- Names: KilledBy / LastHitBy is a name: a player in Players -> that player (DisplayName, team = player HardpointTeam, id =
--   UserId); else a model of that name in DinoIsland.Bots -> a bot (DisplayName attribute, team = HardpointBotTeam, id 0); else
--   the name with "PBot_" taken off, team "", bot = the prefix was there.
-- how = HOW[KilledWith] or KilledWith with its first letter capitalised; "" when none.
-- Out: RemoteEvent ReplicatedStorage.KillFeed:FireAllClients(entry), entry = {k, kTeam, kBot, kId, kSp, how, v, vTeam, vBot,
--   vId, vSp, at} (k / v display names; kId / vId UserId or 0; kSp / vSp species; at = server time). Then
--   HardpointServer.HardpointPractice("stat", id, name, team, species, isBot, "k" / "d") for the killer (k, when known and not
--   the victim) and the victim (d); ids as HardpointServer 1.1 ("u<UserId>" / "b<model name>"). HardpointServer ignores stats
--   outside a match.
-- One line per death: a victim model is counted once per KilledAt value and once per life (seen[model] = the KilledAt used).
-- Switch: script attribute KillFeedEnabled (default true, read at every death; false = nothing sent, nothing counted).
-- Settings: KillFeedLastHitWindow (5). Diagnostics: KillFeedServerVersion, KillFeedSent, KillFeedNoKiller, KillFeedLast
--   ("<k> > <how> > <v>").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VERSION = "1.0"
local FALLBACK_WAIT = 0.4
local HOW = {bite = "Bite", pounce = "Pounce", headbutt = "Headbutt", slash = "Slash", bleed = "Bleed", dilobite = "Bite",
	dilodart = "Venom Dart", dilovenom = "Venom", troopod = "Pod", troozone = "Zone", scratch = "Scratch", thericlaw = "Claws",
	therispin = "Spin", crest = "Bone Crest", cannon = "Cannon", mine = "Mine", hook = "Hook"}

script:SetAttribute("KillFeedServerVersion", VERSION)
if script:GetAttribute("KillFeedEnabled") == nil then script:SetAttribute("KillFeedEnabled", true) end
if script:GetAttribute("KillFeedLastHitWindow") == nil then script:SetAttribute("KillFeedLastHitWindow", 5) end
script:SetAttribute("KillFeedSent", 0)
script:SetAttribute("KillFeedNoKiller", 0)

local remote = ReplicatedStorage:FindFirstChild("KillFeed")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "KillFeed"
	remote.Parent = ReplicatedStorage
end

local function now() return workspace:GetServerTimeNow() end
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end

local hpFn
local function stat(id, name, team, species, isBot, field)
	if not hpFn then
		local hs = ServerScriptService:FindFirstChild("HardpointServer")
		hpFn = hs and hs:FindFirstChild("HardpointPractice")
	end
	if hpFn then pcall(function() hpFn:Invoke("stat", id, name, team, species, isBot, field) end) end
end

local botFolder
local function bots()
	if botFolder and botFolder.Parent then return botFolder end
	local island = workspace:FindFirstChild("DinoIsland")
	botFolder = island and island:FindFirstChild("Bots")
	return botFolder
end

-- who = {name, team, bot, id (UserId or 0), sp, key (stat id)}
local function whoOfName(name)
	if type(name) ~= "string" or name == "" then return nil end
	local pl = Players:FindFirstChild(name)
	if pl and pl:IsA("Player") then
		local c = pl.Character
		return {name = pl.DisplayName, team = pl:GetAttribute("HardpointTeam") or "", bot = false, id = pl.UserId,
			sp = (c and c:GetAttribute("Species")) or pl:GetAttribute("DinoSpecies") or "", key = "u" .. pl.UserId}
	end
	local f = bots()
	local m = f and f:FindFirstChild(name)
	if m then
		return {name = m:GetAttribute("DisplayName") or name, team = m:GetAttribute("HardpointBotTeam") or "", bot = true, id = 0,
			sp = m:GetAttribute("Species") or "", key = "b" .. name}
	end
	local short = name:match("^PBot_(.+)$")
	return {name = short or name, team = "", bot = short ~= nil, id = 0, sp = "", key = (short and "b" or "n") .. name}
end

local function howOf(w)
	if type(w) ~= "string" or w == "" then return "" end
	return HOW[w] or (w:sub(1, 1):upper() .. w:sub(2))
end

local seen = setmetatable({}, {__mode = "k"}) -- [victim model] = the KilledAt counted (or true for a fallback)

local function report(victim, vWho, killerName, how)
	if script:GetAttribute("KillFeedEnabled") == false then return end
	local kWho = whoOfName(killerName)
	if kWho and kWho.key == vWho.key then kWho = nil end -- no self-kill credit
	stat(vWho.key, vWho.name, vWho.team, vWho.sp, vWho.bot, "d")
	if not kWho then
		bump("KillFeedNoKiller")
		return
	end
	stat(kWho.key, kWho.name, kWho.team, kWho.sp, kWho.bot, "k")
	local e = {k = kWho.name, kTeam = kWho.team, kBot = kWho.bot, kId = kWho.id, kSp = kWho.sp, how = how, v = vWho.name,
		vTeam = vWho.team, vBot = vWho.bot, vId = vWho.id, vSp = vWho.sp, at = now()}
	remote:FireAllClients(e)
	bump("KillFeedSent")
	script:SetAttribute("KillFeedLast", ("%s > %s > %s"):format(e.k, how, e.v))
end

local function onKilledAt(model, vWhoFn)
	local at = model:GetAttribute("KilledAt")
	if type(at) ~= "number" or seen[model] ~= nil then return end
	seen[model] = at
	report(model, vWhoFn(), model:GetAttribute("KilledBy"), howOf(model:GetAttribute("KilledWith")))
end

local function fallback(model, vWhoFn)
	task.delay(FALLBACK_WAIT, function()
		if seen[model] ~= nil then return end
		seen[model] = true
		local by, hitAt = model:GetAttribute("LastHitBy"), tonumber(model:GetAttribute("LastHitAt"))
		local win = tonumber(script:GetAttribute("KillFeedLastHitWindow")) or 5
		if not (hitAt and now() - hitAt <= win) then by = nil end
		report(model, vWhoFn(), by, "")
	end)
end

-- players
local function watchCharacter(pl, c)
	local function vWho()
		return {name = pl.DisplayName, team = pl:GetAttribute("HardpointTeam") or "", bot = false, id = pl.UserId,
			sp = c:GetAttribute("Species") or "", key = "u" .. pl.UserId}
	end
	local startAt = c:GetAttribute("KilledAt") -- a stamp already there is not this life's
	if startAt ~= nil then seen[c] = startAt end
	c:GetAttributeChangedSignal("KilledAt"):Connect(function()
		if c:GetAttribute("ArenaPvPBridged") == true then onKilledAt(c, vWho) end
	end)
	local hum = c:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			if c:GetAttribute("ArenaPvPBridged") == true then fallback(c, vWho) end
		end)
	end
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(function(c) watchCharacter(pl, c) end)
	if pl.Character then task.spawn(watchCharacter, pl, pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, pl) end

-- practice bots
local function watchBot(m)
	if not m:IsA("Model") or m:GetAttribute("PracticeBot") ~= true then return end
	local function vWho()
		return {name = m:GetAttribute("DisplayName") or m.Name, team = m:GetAttribute("HardpointBotTeam") or "", bot = true, id = 0,
			sp = m:GetAttribute("Species") or "", key = "b" .. m.Name}
	end
	local startAt = m:GetAttribute("KilledAt")
	if startAt ~= nil then seen[m] = startAt end
	m:GetAttributeChangedSignal("KilledAt"):Connect(function() onKilledAt(m, vWho) end)
	local last = tonumber(m:GetAttribute("DummyHealth")) or 1
	m:GetAttributeChangedSignal("DummyHealth"):Connect(function()
		local h = tonumber(m:GetAttribute("DummyHealth")) or 0
		if last > 0 and h <= 0 then fallback(m, vWho) end
		last = h
	end)
end
task.spawn(function()
	local island = workspace:WaitForChild("DinoIsland", 60)
	local f = island and island:WaitForChild("Bots", 60)
	if not f then return end
	botFolder = f
	f.ChildAdded:Connect(watchBot)
	for _, m in ipairs(f:GetChildren()) do watchBot(m) end
end)
