-- VictoryTitlesServer v1.0 (Mecha Dino Arena) — counts what the MEDIC and BUTTON MASHER victory titles need. MDA-555, plan
-- docs/plans/VICTORY_TITLES_v1.0.md Task 3 (Kepu 2026-11-16 19:00 "Let's implement them").
-- * Healing: ServerStorage BindableEvent VictoryHealReport (made here) :Fire(healer model, HP added) — TrooMovesServer 1.14
--   (Mender Drone on another dino) and MedStationServer 1.6 (a pad on a squadmate) fire it. The healer's scoreboard row gets
--   the HP: HardpointServer.HardpointPractice:Invoke("stat", id, name, team, species, isBot, "heal", hp).
-- * Abilities: every mecha-button press a player sends on a part remote (PracticeKit 1.1 PARTS: each part's remote), at most
--   one per remote per VictoryAbilityGap (0.5) s per player -> "stat" ... "ab", 1. Bots: each rise of their BotPartsUsed
--   (PracticeKit) -> "ab" by the rise.
-- Rows only count while a match runs (HardpointServer drops stats otherwise). Participant ids as KillFeedServer: "u<UserId>"
--   for a player (team = player attribute HardpointTeam), "b<model name>" for a bot (team = HardpointBotTeam).
-- Switch: script attribute VictoryTitlesServerEnabled (default true, read per report). Diagnostics: VictoryHeals (count),
--   VictoryAbilities (count), VictoryRemotes (remotes hooked), VictoryLast.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VERSION = "1.0"
script:SetAttribute("VictoryTitlesServerVersion", VERSION)
for k, v in pairs({VictoryTitlesServerEnabled = true, VictoryAbilityGap = 0.5}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("VictoryHeals", 0)
script:SetAttribute("VictoryAbilities", 0)

local function on() return script:GetAttribute("VictoryTitlesServerEnabled") ~= false end
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end

local hpFn
local function stat(who, field, amount)
	if not hpFn then
		local hs = ServerScriptService:FindFirstChild("HardpointServer")
		hpFn = hs and hs:FindFirstChild("HardpointPractice")
	end
	if not hpFn or not who then return end
	pcall(function() hpFn:Invoke("stat", who.key, who.name, who.team, who.sp, who.bot, field, amount) end)
end

local function whoOfModel(m)
	if typeof(m) ~= "Instance" then return nil end
	local pl = Players:GetPlayerFromCharacter(m)
	if pl then
		return {key = "u" .. pl.UserId, name = pl.DisplayName, team = pl:GetAttribute("HardpointTeam") or "", bot = false,
			sp = m:GetAttribute("Species") or pl:GetAttribute("DinoSpecies") or ""}
	end
	if m:GetAttribute("HardpointBotTeam") ~= nil then
		return {key = "b" .. m.Name, name = m:GetAttribute("DisplayName") or m.Name, team = m:GetAttribute("HardpointBotTeam") or "",
			bot = true, sp = m:GetAttribute("Species") or ""}
	end
	return nil
end

-- ---------- healing ----------
local healEv = ServerStorage:FindFirstChild("VictoryHealReport")
if not healEv then
	healEv = Instance.new("BindableEvent")
	healEv.Name = "VictoryHealReport"
	healEv.Parent = ServerStorage
end
healEv.Event:Connect(function(healer, hp)
	if not on() or type(hp) ~= "number" or hp ~= hp or hp <= 0 then return end
	local who = whoOfModel(healer)
	if not who then return end
	stat(who, "heal", hp)
	bump("VictoryHeals")
	script:SetAttribute("VictoryLast", ("heal %s +%.1f"):format(who.key, hp))
end)

-- ---------- abilities: players' part remotes ----------
local lastAt = {} -- [player] = {[remote name] = os.clock()}
local hooked, hookedN = {}, 0
local function hookRemote(r)
	if hooked[r] or not r:IsA("RemoteEvent") then return end
	hooked[r] = true
	hookedN += 1
	script:SetAttribute("VictoryRemotes", hookedN)
	r.OnServerEvent:Connect(function(player)
		if not on() then return end
		local t = os.clock()
		local per = lastAt[player]
		if not per then per = {}; lastAt[player] = per end
		if per[r.Name] and t - per[r.Name] < (tonumber(script:GetAttribute("VictoryAbilityGap")) or 0.5) then return end
		per[r.Name] = t
		local who = player.Character and whoOfModel(player.Character)
		if not who then return end
		stat(who, "ab", 1)
		bump("VictoryAbilities")
		script:SetAttribute("VictoryLast", ("ab %s %s"):format(who.key, r.Name))
	end)
end
Players.PlayerRemoving:Connect(function(p) lastAt[p] = nil end)
task.spawn(function()
	local names = {}
	local ok, kit = pcall(function()
		return require(ServerScriptService:WaitForChild("PracticeServer", 30):WaitForChild("PracticeKit", 30))
	end)
	if ok and type(kit) == "table" and type(kit.PARTS) == "table" then
		for _, p in pairs(kit.PARTS) do if type(p.remote) == "string" then names[p.remote] = true end end
	end
	for name in pairs(names) do
		local r = ReplicatedStorage:FindFirstChild(name, true)
		if r then hookRemote(r) end
	end
	ReplicatedStorage.DescendantAdded:Connect(function(d) if names[d.Name] then hookRemote(d) end end)
end)

-- ---------- abilities: bots ----------
local botSeen = setmetatable({}, {__mode = "k"})
local function watchBot(m)
	if botSeen[m] or not m:IsA("Model") then return end
	botSeen[m] = m:GetAttribute("BotPartsUsed") or 0
	m:GetAttributeChangedSignal("BotPartsUsed"):Connect(function()
		local v = m:GetAttribute("BotPartsUsed") or 0
		local rise = v - (botSeen[m] or 0)
		botSeen[m] = v
		if rise > 0 and on() then
			local who = whoOfModel(m)
			if who then
				stat(who, "ab", rise)
				bump("VictoryAbilities")
			end
		end
	end)
end
task.spawn(function()
	local island = workspace:WaitForChild("DinoIsland", 60)
	local bots = island and island:WaitForChild("Bots", 60)
	if not bots then return end
	for _, m in ipairs(bots:GetChildren()) do watchBot(m) end
	bots.ChildAdded:Connect(watchBot)
end)
