-- SkinStats v1.0 (Mecha Dino Arena) — saved lifetime kills and best win streak, for the universal skins' challenges.
-- MDA-567, plan docs/plans/UNIVERSAL_SKINS_v0.1.md Task 2 (Kepu 2026-11-24: Riverstone "Get 25 kills", Ghost Bark "Get 100 kills",
-- Ink War "Win 3 Arena matches in a row"; kills = "Arena + island bots").
-- Kills: the BindableEvents KillCredit of KillFeedServer 1.2 (Arena / practice: players and practice bots killed by a player) and
--   KillRegenServer 1.2 (island bots) fire (killer UserId, victim model, KilledAt). One death counts once: a victim model + KilledAt
--   pair seen from both scripts (a practice bot) is counted the first time only (true / no KilledAt = the KillFeed fallback, its
--   own key "fb").
-- Best streak: best = max(best, player ArenaStreak) on every ArenaStreak change (ArenaRecordServer 1.4 keeps the current streak).
-- Store: DataStore "MDA_SkinStats_v1", key "u<UserId>", value {v = 1, k = kills, best = best win streak}.
--   * Load at join (GetAsync, 3 tries, waits 2 / 4 s); failure -> "loadFailed", retried every 30 s; NOTHING is written before a
--     successful load. Kills made before the load are kept and added on top of the stored count.
--   * Save with UpdateAsync, merging: k = stored k + the kills this server has not written yet, best = max(stored, ours). 10 s
--     after a change, on leave and in BindToClose; pcall with one retry.
-- Player attributes: StatKills, StatBestStreak (whole numbers), SkinStatsReady (true once loaded, or with saves off),
--   SkinStatsState ("loading" / "loaded" / "new" / "loadFailed" / "noApi" / "saved" / "saveFailed" / "off").
-- Switches (script attributes, read at start): SkinStatsEnabled (default true; false = nothing counted, no attributes);
--   SkinStatsSaveEnabled (default true; false = no DataStore calls at all: counts start at 0 this session, ready at once, never
--   written; the Studio test guard).
-- Diagnostics: script SkinStatsVersion, SkinStatsCounted (kills counted), SkinStatsDupes (second reports of one death).
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 island kill streak
-- v1.1 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 2; Kepu 2026-11-26 "a fire streak emblem once you go on a killing spree on the main island. 25 kills streak unlocks the
--   thunder storm skin. 10 kill streak unlocks the zebra"; kills of players and bots, main island
--   only; picks "Death or menu"): every counted kill (after the dedupe above) also adds 1 to the killer's island streak when
--   script attribute SkinStatsIslandStreakEnabled ~= false, ReplicatedStorage ServerKind == "hub", the killer's TutLane is not
--   > 0 and the killer's Humanoid is alive. The streak goes back to 0 when the killer's Humanoid dies, on a new character and
--   when the player's InMenu turns true. Best island streak = max(best, streak), saved as ib in the same UpdateAsync merge
--   (ib = max(stored, ours); v stays 1) and loaded with the rest. Player attributes IslandStreak (current) and StatIslandBest
--   (best). Diagnostics: script IslandStreakCounted, IslandStreakResets. false = 1.0.local STORE = "MDA_SkinStats_v1"
local LOAD_TRIES, LOAD_WAITS = 3, {2, 4}
local RETRY_GAP = 30
local SAVE_GAP = 10

script:SetAttribute("SkinStatsVersion", VERSION)
script:SetAttribute("SkinStatsCounted", 0)
script:SetAttribute("SkinStatsDupes", 0)
if script:GetAttribute("SkinStatsEnabled") == nil then script:SetAttribute("SkinStatsEnabled", true) end
if script:GetAttribute("SkinStatsSaveEnabled") == nil then script:SetAttribute("SkinStatsSaveEnabled", true) end
if script:GetAttribute("SkinStatsEnabled") == false then return end
local saveOn = script:GetAttribute("SkinStatsSaveEnabled") ~= false

local store
if saveOn then
	local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE) end)
	store = ok and s or nil
end

-- [player] = {loaded, k (stored), pending (kills not written yet), best, bestDirty, lastChange}
local states = {}

local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end
local function isNoApi(err)
	local e = tostring(err)
	return e:find("not allowed") ~= nil or e:find("StudioAccessToApisNotAllowed") ~= nil or e:find("API Services") ~= nil
end

local function publish(player)
	local st = states[player]
	if not st then return end
	player:SetAttribute("StatKills", st.k + st.pending)
	player:SetAttribute("StatBestStreak", st.best)
	player:SetAttribute("SkinStatsReady", st.loaded)
	player:SetAttribute("IslandStreak", st.istreak or 0) -- v1.1
	player:SetAttribute("StatIslandBest", st.ib or 0) -- v1.1
end

local function save(player)
	local st = states[player]
	if not (st and st.loaded and store) then return end
	if st.pending == 0 and not st.bestDirty and not st.ibDirty then return end -- v1.1: + ibDirty
	local add, best = st.pending, st.best
	local ib = st.ib or 0 -- v1.1
	local stored
	local function attempt()
		return pcall(function()
			store:UpdateAsync("u" .. player.UserId, function(old)
				local v = type(old) == "table" and old or {}
				v.v = 1
				v.k = (tonumber(v.k) or 0) + add
				v.best = math.max(tonumber(v.best) or 0, best)
				v.ib = math.max(tonumber(v.ib) or 0, ib) -- v1.1
				stored = v
				return v
			end)
		end)
	end
	local ok, err = attempt()
	if not ok then ok, err = attempt() end
	if ok and stored then
		st.pending -= add
		st.k = stored.k
		st.best = math.max(st.best, stored.best)
		if st.best == best then st.bestDirty = false end
		st.ib = math.max(st.ib or 0, tonumber(stored.ib) or 0) -- v1.1
		if st.ib == ib then st.ibDirty = false end
		player:SetAttribute("SkinStatsState", "saved")
		publish(player)
	else
		player:SetAttribute("SkinStatsState", isNoApi(err) and "noApi" or "saveFailed")
	end
end

local function tryLoad(player)
	local st = states[player]
	if not st or st.loaded then return end
	if not saveOn then
		st.loaded = true
		player:SetAttribute("SkinStatsState", "off")
		publish(player)
		return
	end
	if not store then
		player:SetAttribute("SkinStatsState", "noApi")
		return
	end
	local lastErr
	for i = 1, LOAD_TRIES do
		if not player.Parent then return end
		local ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if ok then
			st.loaded = true
			if type(value) == "table" then
				st.k = math.max(0, math.floor(tonumber(value.k) or 0))
				st.best = math.max(st.best, math.floor(tonumber(value.best) or 0))
				st.ib = math.max(st.ib or 0, math.floor(tonumber(value.ib) or 0)) -- v1.1
				player:SetAttribute("SkinStatsState", "loaded")
			else
				player:SetAttribute("SkinStatsState", "new")
			end
			publish(player)
			return
		end
		lastErr = value
		if isNoApi(value) then break end
		if i < LOAD_TRIES then task.wait(LOAD_WAITS[i] or 2) end
	end
	player:SetAttribute("SkinStatsState", isNoApi(lastErr) and "noApi" or "loadFailed")
end

local function onStreak(player)
	local st = states[player]
	if not st then return end
	local s = math.floor(tonumber(player:GetAttribute("ArenaStreak")) or 0)
	if s > st.best then
		st.best = s
		st.bestDirty = true
		st.lastChange = os.clock()
		publish(player)
	end
end

local function onPlayer(player)
	states[player] = {loaded = false, k = 0, pending = 0, best = 0, bestDirty = false, lastChange = 0}
	states[player].istreak, states[player].ib, states[player].ibDirty = 0, 0, false -- v1.1
	player:SetAttribute("SkinStatsState", "loading")
	publish(player)
	player:GetAttributeChangedSignal("ArenaStreak"):Connect(function() onStreak(player) end)
	onStreak(player)
	local function resetStreak() -- v1.1: death, a new body or the menu ends the island streak
		local s = states[player]
		if s and (s.istreak or 0) > 0 then
			s.istreak = 0
			bump("IslandStreakResets")
			publish(player)
		end
	end
	local function hookChar(c)
		resetStreak()
		local hum = c:WaitForChild("Humanoid", 10)
		if hum then hum.Died:Connect(resetStreak) end
	end
	player.CharacterAdded:Connect(hookChar)
	if player.Character then task.spawn(hookChar, player.Character) end
	player:GetAttributeChangedSignal("InMenu"):Connect(function()
		if player:GetAttribute("InMenu") == true then resetStreak() end
	end)
	task.spawn(tryLoad, player)
	task.spawn(function()
		while player.Parent and states[player] and not states[player].loaded do
			task.wait(RETRY_GAP)
			if player.Parent and states[player] and not states[player].loaded
				and player:GetAttribute("SkinStatsState") == "loadFailed" then tryLoad(player) end
		end
	end)
end

-- v1.1: the island streak part of a counted kill
if script:GetAttribute("SkinStatsIslandStreakEnabled") == nil then script:SetAttribute("SkinStatsIslandStreakEnabled", true) end
script:SetAttribute("IslandStreakCounted", 0)
script:SetAttribute("IslandStreakResets", 0)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function islandKill(player, st)
	if script:GetAttribute("SkinStatsIslandStreakEnabled") == false or ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" then return end
	if (tonumber(player:GetAttribute("TutLane")) or 0) > 0 then return end
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then return end
	st.istreak = (st.istreak or 0) + 1
	if st.istreak > (st.ib or 0) then
		st.ib = st.istreak
		st.ibDirty = true
	end
	bump("IslandStreakCounted")
end
-- kills
local seen = setmetatable({}, {__mode = "k"}) -- [victim model] = {[KilledAt key] = true}
local function onKill(userId, victim, at)
	local player = Players:GetPlayerByUserId(tonumber(userId) or 0)
	local st = player and states[player]
	if not st then return end
	if typeof(victim) == "Instance" then
		local key = type(at) == "number" and at or "fb"
		local s = seen[victim]
		if not s then s = {} seen[victim] = s end
		if s[key] then bump("SkinStatsDupes") return end
		s[key] = true
	end
	st.pending += 1
	st.lastChange = os.clock()
	bump("SkinStatsCounted")
	islandKill(player, st) -- v1.1
	publish(player)
end
local hooked = {}
local function hook(scriptName)
	task.spawn(function()
		local src = ServerScriptService:WaitForChild(scriptName, 60)
		local ev = src and src:WaitForChild("KillCredit", 60)
		if ev and ev:IsA("BindableEvent") and not hooked[ev] then
			hooked[ev] = true
			ev.Event:Connect(onKill)
		end
	end)
end
hook("KillFeedServer")
hook("KillRegenServer")

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	states[player] = nil
end)
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do save(player) end
end)
task.spawn(function()
	while true do
		task.wait(1)
		for player, st in pairs(states) do
			if st.loaded and (st.pending > 0 or st.bestDirty or st.ibDirty) and os.clock() - st.lastChange >= SAVE_GAP then
				save(player)
				st.lastChange = os.clock()
			end
		end
	end
end)
