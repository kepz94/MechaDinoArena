-- SpeciesServer v1.3 (Dino Arcade) — TEST species switch: respawns a player as the dino they pick.
-- Client -> server: ReplicatedStorage.DinoSpeciesRequest:FireServer(species) (sent by SpeciesPicker 1.0),
--   species = "TRex" or "Raptor".
-- TRex   -> player:LoadCharacter() (StarterPlayer.StarterCharacter, the T-Rex).
-- Raptor -> a copy of the raptor template: built once at start from ServerStorage.DinoArcade.Models.RaptorModelData
--   with DinoModelBuilder 1.0 (Rojo: src/shared -> ServerStorage.DinoArcade). The copy gets clones of every
--   StarterCharacterScripts child (so IdleAnimation, SprintTest, TurnLimit, StaminaBar ... run on it), is
--   placed standing at the SpawnLocation (or where the old character stood), then set as player.Character, so
--   every CharacterAdded hook (DinoHitboxes, StaminaServer, CreepServer ...) treats it like any character.
-- The choice is kept in the player attribute DinoSpecies: when Roblox respawns the player after a death
--   (always as the StarterCharacter T-Rex), a player who picked Raptor is switched back to a raptor.
-- Checks: species is a known name; at most one switch per SWITCH_COOLDOWN seconds; template built.
-- Diagnostics: player attributes DinoSpecies, SpeciesLastResult ("ok" / "same" / "badArg" / "cooldown" /
--   "noTemplate"); SpeciesTemplate (server attribute on this script: "ready" / "missing <reason>").
-- v1.1 (Kepu 2026-10-29: "When I load into the game the raptor should be the default choice"): on join, a player
--   without DinoSpecies gets DinoSpecies = script attribute SpeciesDefault (default "Raptor"; "TRex" = 1.0), so the first
--   spawn is swapped to a raptor by the hook below (the menu opens on it); a body that spawned before the default was set
--   is swapped too. An unknown value is ignored (1.0: T-Rex). The red flash on a dino switch is handled on the client by
--   HurtFlashGuard 1.0. Diagnostics: script attribute SpeciesServerVersion; player attribute SpeciesDefaulted (true when
--   the default was applied).
-- v1.2 (MDA-118, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 3): third species "Pachy". A pachy template is built once
--   from ServerStorage.DinoArcade.Models.PachyModelData (like the raptor's) while the script attribute
--   SpeciesPachyEnabled (default true, read at start) is on; "Pachy" is then a known species: a request swaps in a copy
--   of the template exactly as for the raptor (StarterCharacterScripts copies, old spot, player.Character), and after a
--   death a player whose DinoSpecies is "Pachy" is switched back to a pachy. No template -> "noTemplate". Script
--   attribute SpeciesPachyTemplate ("ready" / "missing <reason>" / "off").
-- v1.3 (Kepu 2026-10-30: "whatever was my last selected dino in the main menu should be the auto option when i reopen the
--   game. it keeps resetting back to raptor when i keep testing the pachy"): the last species a player switched to is
--   remembered. Saved in DataStore "MDA_Settings_v1" (MusicServer's store), key "u<UserId>", field lastSpecies (the
--   table's other fields are kept; UpdateAsync), after every accepted switch (at most once per SAVE_GAP 4 s; the newest
--   wins; the last one is saved on leave). On join it is read before the default: a known species becomes DinoSpecies
--   (player attribute SpeciesFromSave = true, SpeciesDefaulted not set) and a body that already spawned as another
--   species is swapped to it, so the menu opens on that dino and the Arena place (same store) starts as it too. Nothing
--   saved / read failed (e.g. Studio without API access) -> the 1.1 default (Raptor). Diagnostics: script attribute
--   SpeciesSaveState ("ok" / "readFailed" / "writeFailed" / "noStore"); player SpeciesSaved (last saved value). Switch:
--   script attribute SpeciesRememberEnabled (default true, read at start; false = 1.2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SWITCH_COOLDOWN = 2
local SPECIES = {TRex = true, Raptor = true}
script:SetAttribute("SpeciesServerVersion", "1.3")
if script:GetAttribute("SpeciesDefault") == nil then script:SetAttribute("SpeciesDefault", "Raptor") end -- v1.1

local remote = ReplicatedStorage:FindFirstChild("DinoSpeciesRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoSpeciesRequest"
	remote.Parent = ReplicatedStorage
end

-- raptor template, built once from the model data
local raptorTemplate
do
	local ok, err = pcall(function()
		local folder = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(folder:WaitForChild("DinoModelBuilder"))
		local data = require(folder:WaitForChild("Models"):WaitForChild("RaptorModelData"))
		raptorTemplate = Builder.build(data, {name = "Raptor"})
	end)
	script:SetAttribute("SpeciesTemplate", ok and raptorTemplate and "ready" or ("missing " .. tostring(err)))
end

-- v1.2: pachy template
if script:GetAttribute("SpeciesPachyEnabled") == nil then script:SetAttribute("SpeciesPachyEnabled", true) end
local pachyTemplate
if script:GetAttribute("SpeciesPachyEnabled") ~= false then
	local ok, err = pcall(function()
		local folder = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(folder:WaitForChild("DinoModelBuilder"))
		local data = require(folder:WaitForChild("Models"):WaitForChild("PachyModelData"))
		pachyTemplate = Builder.build(data, {name = "Pachy"})
	end)
	script:SetAttribute("SpeciesPachyTemplate", ok and pachyTemplate and "ready" or ("missing " .. tostring(err)))
	if pachyTemplate then SPECIES.Pachy = true end
else
	script:SetAttribute("SpeciesPachyTemplate", "off")
end

local lastSwitch = {}

-- v1.3: remember the last species (MusicServer's settings store)
if script:GetAttribute("SpeciesRememberEnabled") == nil then script:SetAttribute("SpeciesRememberEnabled", true) end
local REMEMBER = script:GetAttribute("SpeciesRememberEnabled") ~= false
local SAVE_GAP = 4
local settingsStore
if REMEMBER then
	local ok, st = pcall(function() return game:GetService("DataStoreService"):GetDataStore("MDA_Settings_v1") end)
	settingsStore = ok and st or nil
	if not settingsStore then script:SetAttribute("SpeciesSaveState", "noStore") end
end
local saveState = {} -- [player] = {want, saved, lastSave, queued}
local function saveSpecies(player)
	local st = saveState[player]
	if not (st and settingsStore) or st.want == st.saved then return end
	local value = st.want
	st.lastSave = os.clock()
	local ok = pcall(function()
		settingsStore:UpdateAsync("u" .. player.UserId, function(old)
			local t = type(old) == "table" and old or {}
			t.lastSpecies = value
			return t
		end)
	end)
	if ok then
		st.saved = value
		player:SetAttribute("SpeciesSaved", value)
		script:SetAttribute("SpeciesSaveState", "ok")
	else
		script:SetAttribute("SpeciesSaveState", "writeFailed")
	end
end
local function rememberSpecies(player, species)
	if not (REMEMBER and settingsStore) then return end
	local st = saveState[player]
	if not st then st = {lastSave = 0}; saveState[player] = st end
	st.want = species
	if st.queued then return end
	local waitFor = math.max(0, SAVE_GAP - (os.clock() - st.lastSave))
	st.queued = true
	task.delay(waitFor, function()
		st.queued = false
		if player.Parent then saveSpecies(player) end
	end)
end
local function loadSpecies(player)
	if not (REMEMBER and settingsStore) then return nil end
	local ok, data = pcall(function() return settingsStore:GetAsync("u" .. player.UserId) end)
	if not ok then script:SetAttribute("SpeciesSaveState", "readFailed") return nil end
	local sp = type(data) == "table" and data.lastSpecies or nil
	if type(sp) == "string" then
		saveState[player] = saveState[player] or {lastSave = 0}
		saveState[player].saved, saveState[player].want = sp, sp
	end
	return sp
end

local function speciesOf(char)
	return char and char:GetAttribute("Species") or nil
end

-- where the new body stands: the old character's spot, else the SpawnLocation
local function spawnCFrame(player, hipHeight)
	local old = player.Character
	local hrp = old and old:FindFirstChild("HumanoidRootPart")
	local hum = old and old:FindFirstChildOfClass("Humanoid")
	local base
	if hrp and hum and hum.Health > 0 then
		local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		local ground = hrp.Position.Y - (hrp.Size.Y / 2 + hum.HipHeight)
		local pos = Vector3.new(hrp.Position.X, ground, hrp.Position.Z)
		base = CFrame.lookAt(pos, pos + (look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)))
	else
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		local pos = spawn and (spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0)) or Vector3.zero
		base = CFrame.new(pos)
	end
	return base + Vector3.new(0, hipHeight, 0)
end

local function spawnRaptor(player)
	local char = raptorTemplate:Clone()
	char.Name = player.Name
	for _, s in ipairs(StarterPlayer.StarterCharacterScripts:GetChildren()) do
		s:Clone().Parent = char
	end
	local hrp = char.HumanoidRootPart
	local hum = char:FindFirstChildOfClass("Humanoid")
	char:PivotTo(spawnCFrame(player, hrp.Size.Y / 2 + hum.HipHeight))
	local old = player.Character
	char.Parent = workspace
	player.Character = char
	if old and old ~= char then old:Destroy() end
end

-- v1.2: same as spawnRaptor, from the pachy template
local function spawnPachy(player)
	local char = pachyTemplate:Clone()
	char.Name = player.Name
	for _, s in ipairs(StarterPlayer.StarterCharacterScripts:GetChildren()) do
		s:Clone().Parent = char
	end
	local hrp = char.HumanoidRootPart
	local hum = char:FindFirstChildOfClass("Humanoid")
	char:PivotTo(spawnCFrame(player, hrp.Size.Y / 2 + hum.HipHeight))
	local old = player.Character
	char.Parent = workspace
	player.Character = char
	if old and old ~= char then old:Destroy() end
end

local function switch(player, species)
	player:SetAttribute("DinoSpecies", species)
	if species == "Raptor" then
		spawnRaptor(player)
	elseif species == "Pachy" and pachyTemplate then -- v1.2
		spawnPachy(player)
	else
		player:LoadCharacter()
	end
end

remote.OnServerEvent:Connect(function(player, species)
	if typeof(species) ~= "string" or not SPECIES[species] then
		player:SetAttribute("SpeciesLastResult", "badArg")
		return
	end
	if species == "Raptor" and not raptorTemplate then
		player:SetAttribute("SpeciesLastResult", "noTemplate")
		return
	end
	if species == "Pachy" and not pachyTemplate then -- v1.2
		player:SetAttribute("SpeciesLastResult", "noTemplate")
		return
	end
	local now = os.clock()
	if lastSwitch[player] and now - lastSwitch[player] < SWITCH_COOLDOWN then
		player:SetAttribute("SpeciesLastResult", "cooldown")
		return
	end
	if speciesOf(player.Character) == species then
		player:SetAttribute("DinoSpecies", species)
		player:SetAttribute("SpeciesLastResult", "same")
		rememberSpecies(player, species) -- v1.3
		return
	end
	lastSwitch[player] = now
	switch(player, species)
	player:SetAttribute("SpeciesLastResult", "ok")
	rememberSpecies(player, species) -- v1.3
end)

-- keep the chosen species after a death (Roblox respawns as the StarterCharacter T-Rex)
local function onPlayer(player)
	-- v1.3: the remembered dino first (read before the default; this thread may wait for the store)
	local saved = loadSpecies(player)
	if player.Parent and player:GetAttribute("DinoSpecies") == nil and type(saved) == "string" and SPECIES[saved] then
		player:SetAttribute("DinoSpecies", saved)
		player:SetAttribute("SpeciesFromSave", true)
	end
	-- v1.1: default dino for a player who has not picked one
	local default = script:GetAttribute("SpeciesDefault")
	if player:GetAttribute("DinoSpecies") == nil and type(default) == "string" and SPECIES[default] then
		player:SetAttribute("DinoSpecies", default)
		player:SetAttribute("SpeciesDefaulted", true)
	end
	player.CharacterAdded:Connect(function(char)
		local want = player:GetAttribute("DinoSpecies")
		if want == "Raptor" and raptorTemplate and speciesOf(char) ~= "Raptor" then
			task.defer(function()
				if player.Character == char then spawnRaptor(player) end
			end)
		end
		if want == "Pachy" and pachyTemplate and speciesOf(char) ~= "Pachy" then -- v1.2
			task.defer(function()
				if player.Character == char then spawnPachy(player) end
			end)
		end
	end)
	-- v1.1: a body that spawned before the default was set
	local char = player.Character
	if player:GetAttribute("SpeciesDefaulted") == true and player:GetAttribute("DinoSpecies") == "Raptor" and raptorTemplate
		and char and speciesOf(char) ~= "Raptor" then
		task.defer(function()
			if player.Character == char then spawnRaptor(player) end
		end)
	end
end
local function onPlayerV13(player) -- v1.3: a body that spawned (as another dino) while the store was read
	onPlayer(player)
	local char = player.Character
	local want = player:GetAttribute("DinoSpecies")
	if player:GetAttribute("SpeciesFromSave") == true and char and speciesOf(char) ~= want then
		task.defer(function()
			if player.Character ~= char then return end
			if want == "Raptor" and raptorTemplate then spawnRaptor(player)
			elseif want == "Pachy" and pachyTemplate then spawnPachy(player)
			elseif want == "TRex" and (speciesOf(char) == "Raptor" or speciesOf(char) == "Pachy") then player:LoadCharacter() end
		end)
	end
end
Players.PlayerAdded:Connect(onPlayerV13)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerV13, p) end
Players.PlayerRemoving:Connect(function(player)
	lastSwitch[player] = nil
	if saveState[player] then saveSpecies(player); saveState[player] = nil end -- v1.3: the last choice
end)
