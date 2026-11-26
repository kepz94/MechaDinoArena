-- SpeciesServer v1.8 (Dino Arcade) — TEST species switch: respawns a player as the dino they pick.
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
-- v1.4 (MDA-135, plan docs/plans/HERRERA_KIT_v1.0.md Task 3): fourth species "Herrera", exactly like the pachy (1.2): a
--   template built once from ServerStorage.DinoArcade.Models.HerreraModelData while the script attribute
--   SpeciesHerreraEnabled (default true, read at start) is on; "Herrera" is then a known species (switch, respawn after a
--   death, remembered choice). Script attribute SpeciesHerreraTemplate ("ready" / "missing <reason>" / "off").
-- v1.5 (MDA-172, plan docs/plans/TENO_KIT_v1.0.md Task 3): fifth species "Teno", exactly like the Herrera (1.4): a template
--   built once from ServerStorage.DinoArcade.Models.TenoModelData while SpeciesTenoEnabled (default true, read at start)
--   is on; "Teno" is then a known species (switch, respawn after a death, remembered choice). Script attribute
--   SpeciesTenoTemplate ("ready" / "missing <reason>" / "off").
-- v1.6 (MDA-199, plan docs/plans/THERIZINO_KIT_v1.0.md Task 3): sixth species "Therizino", exactly like the teno (1.5): a
--   template built once from ServerStorage.DinoArcade.Models.TherizinoModelData while SpeciesTherizinoEnabled (default true,
--   read at start) is on; "Therizino" is then a known species (switch, respawn after a death, remembered choice). Script
--   attribute SpeciesTherizinoTemplate ("ready" / "missing <reason>" / "off").
-- v1.7 (MDA-223, plan docs/plans/DILO_KIT_v1.0.md Task 3): seventh species "Dilo", exactly like the therizino (1.6): a template
--   built once from ServerStorage.DinoArcade.Models.DiloModelData while SpeciesDiloEnabled (default true, read at start) is on;
--   "Dilo" is then a known species (switch, respawn after a death, remembered choice). Script attribute SpeciesDiloTemplate
--   ("ready" / "missing <reason>" / "off").
-- v1.8 (MDA-332, plan docs/plans/TROODON_KIT_v1.0.md Task 3): eighth species "Troodon", exactly like the dilo (1.7): a template
--   built once from ServerStorage.DinoArcade.Models.TroodonModelData while SpeciesTroodonEnabled (default true, read at start)
--   is on; "Troodon" is then a known species (switch, respawn after a death, remembered choice). Script attribute
--   SpeciesTroodonTemplate ("ready" / "missing <reason>" / "off").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SWITCH_COOLDOWN = 2
local SPECIES = {TRex = true, Raptor = true}
script:SetAttribute("SpeciesServerVersion", "1.3")
script:SetAttribute("SpeciesServerVersion", "1.4") -- v1.4
script:SetAttribute("SpeciesServerVersion", "1.5") -- v1.5
script:SetAttribute("SpeciesServerVersion", "1.7") -- v1.7 (1.6 did not bump this line)
script:SetAttribute("SpeciesServerVersion", "1.8") -- v1.8
script:SetAttribute("SpeciesServerVersion", "1.9") -- v1.9 remember respawn picks
-- v1.9 (respawn swap, MDA-539, plan docs/plans/RESPAWN_SWAP_v1.0.md rule 4): a dino picked on the respawn screen (RespawnServer 1.0
--   sets player attribute RespawnPicked = species, then DinoSpecies) is remembered like a switch (rememberSpecies: the next session
--   starts as it). Switch: script attribute SpeciesRememberPicksEnabled (default true, read per pick).
-- v1.10 (account reset, Kepu 2026-11-22 11:22 "reset everyone's account anyways to zero so we can see how hard it is to grind players"; picks "Fresh saves, keep old", "Last picked dino"): the remembered dino is stored in the field named by
--   the script attribute SpeciesSaveField (default "lastSpecies2", read per load / save) of the same "MDA_Settings_v1" record; the old
--   lastSpecies field stays as it is (music settings in the record are untouched). DinoOwnership 1.1 reads the same field.
script:SetAttribute("SpeciesServerVersion", "1.10") -- v1.10 fresh last-dino field (account reset)
script:SetAttribute("SpeciesServerVersion", "1.11") -- v1.11 coming soon + dino unlock gate
-- v1.11 (Kepu 2026-11-26 08:06 "make dinos 40 skill points to unlock base or pay robux to unlock maxed out", 08:09 "for the t-rex
--   have it be unselectable and unable to use. just slap a coming soon on it"; picks "Spend 40 (as said)", "R$149"):
--   * Coming soon: script attribute SpeciesComingSoon (csv, default "TRex", read per check). Such a dino can't be picked (request
--     -> "comingSoon") and a player whose DinoSpecies becomes one (a saved pick, RespawnServer, any script) is moved to a fallback.
--   * Unlock gate: script attribute SpeciesUnlockGateEnabled (default true, read per check). Once the player's ownership is known
--     (TutState set and not "wait", OwnedDinos not empty), a dino not in OwnedDinos (DinoOwnership) is "locked": request ->
--     "locked", and DinoSpecies set to it is moved to a fallback. Unlocking is DinoUnlockServer 1.0 (40 points or R$149 maxed).
--   * Fallback: the last allowed DinoSpecies (player SpeciesLastAllowed), FreeDino, SpeciesDefault, then any owned dino; the body is
--     swapped with switch(). Diagnostic: player SpeciesLockReverts (count).
--   * ReplicatedStorage attributes for the pick screens: DinoComingSoon (csv), DinoUnlockGate (bool).
--   * Launch reset (Kepu 2026-11-26 08:10 "everybody has clean sheets nothing on their accounts ready for launch"): SpeciesSaveField default "lastSpecies3" (DinoOwnership 1.3 reads the same field).
if script:GetAttribute("SpeciesSaveField") == nil then script:SetAttribute("SpeciesSaveField", "lastSpecies3") end -- v1.11 launch reset (1.10: "lastSpecies2")
local function speciesField() return script:GetAttribute("SpeciesSaveField") or "lastSpecies2" end
if script:GetAttribute("SpeciesDefault") == nil then script:SetAttribute("SpeciesDefault", "Raptor") end -- v1.1
-- v1.11: coming soon + unlock gate (see the v1.11 note)
for k, v in pairs({SpeciesComingSoon = "TRex", SpeciesUnlockGateEnabled = true}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function soonSet()
	local s = {}
	for id in tostring(script:GetAttribute("SpeciesComingSoon") or ""):gmatch("[^,%s]+") do s[id] = true end
	return s
end
local function publishLocks()
	ReplicatedStorage:SetAttribute("DinoComingSoon", tostring(script:GetAttribute("SpeciesComingSoon") or ""))
	ReplicatedStorage:SetAttribute("DinoUnlockGate", script:GetAttribute("SpeciesUnlockGateEnabled") ~= false)
end
publishLocks()
script:GetAttributeChangedSignal("SpeciesComingSoon"):Connect(publishLocks)
script:GetAttributeChangedSignal("SpeciesUnlockGateEnabled"):Connect(publishLocks)
local function lockOf(player, sp)
	if soonSet()[sp] then return "comingSoon" end
	if script:GetAttribute("SpeciesUnlockGateEnabled") == false then return nil end
	local ts = player:GetAttribute("TutState")
	local owned = tostring(player:GetAttribute("OwnedDinos") or "")
	if ts == nil or ts == "wait" or owned == "" then return nil end
	if string.find("," .. owned .. ",", "," .. tostring(sp) .. ",", 1, true) then return nil end
	return "locked"
end

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

-- v1.4: herrera template
if script:GetAttribute("SpeciesHerreraEnabled") == nil then script:SetAttribute("SpeciesHerreraEnabled", true) end
local herreraTemplate
if script:GetAttribute("SpeciesHerreraEnabled") ~= false then
	local ok, err = pcall(function()
		local folder = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(folder:WaitForChild("DinoModelBuilder"))
		local data = require(folder:WaitForChild("Models"):WaitForChild("HerreraModelData"))
		herreraTemplate = Builder.build(data, {name = "Herrera"})
	end)
	script:SetAttribute("SpeciesHerreraTemplate", ok and herreraTemplate and "ready" or ("missing " .. tostring(err)))
	if herreraTemplate then SPECIES.Herrera = true end
else
	script:SetAttribute("SpeciesHerreraTemplate", "off")
end

-- v1.5: teno template
if script:GetAttribute("SpeciesTenoEnabled") == nil then script:SetAttribute("SpeciesTenoEnabled", true) end
local tenoTemplate
if script:GetAttribute("SpeciesTenoEnabled") ~= false then
	local ok, err = pcall(function()
		local folder = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(folder:WaitForChild("DinoModelBuilder"))
		local data = require(folder:WaitForChild("Models"):WaitForChild("TenoModelData"))
		tenoTemplate = Builder.build(data, {name = "Teno"})
	end)
	script:SetAttribute("SpeciesTenoTemplate", ok and tenoTemplate and "ready" or ("missing " .. tostring(err)))
	if tenoTemplate then SPECIES.Teno = true end
else
	script:SetAttribute("SpeciesTenoTemplate", "off")
end

-- v1.6: therizino template
if script:GetAttribute("SpeciesTherizinoEnabled") == nil then script:SetAttribute("SpeciesTherizinoEnabled", true) end
local theriTemplate
if script:GetAttribute("SpeciesTherizinoEnabled") ~= false then
	local ok, err = pcall(function()
		local folder = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(folder:WaitForChild("DinoModelBuilder"))
		local data = require(folder:WaitForChild("Models"):WaitForChild("TherizinoModelData"))
		theriTemplate = Builder.build(data, {name = "Therizino"})
	end)
	script:SetAttribute("SpeciesTherizinoTemplate", ok and theriTemplate and "ready" or ("missing " .. tostring(err)))
	if theriTemplate then SPECIES.Therizino = true end
else
	script:SetAttribute("SpeciesTherizinoTemplate", "off")
end

-- v1.7: dilo template
if script:GetAttribute("SpeciesDiloEnabled") == nil then script:SetAttribute("SpeciesDiloEnabled", true) end
local diloTemplate
if script:GetAttribute("SpeciesDiloEnabled") ~= false then
	local ok, err = pcall(function()
		local folder = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(folder:WaitForChild("DinoModelBuilder"))
		local data = require(folder:WaitForChild("Models"):WaitForChild("DiloModelData"))
		diloTemplate = Builder.build(data, {name = "Dilo"})
	end)
	script:SetAttribute("SpeciesDiloTemplate", ok and diloTemplate and "ready" or ("missing " .. tostring(err)))
	if diloTemplate then SPECIES.Dilo = true end
else
	script:SetAttribute("SpeciesDiloTemplate", "off")
end

-- v1.8: troodon template
if script:GetAttribute("SpeciesTroodonEnabled") == nil then script:SetAttribute("SpeciesTroodonEnabled", true) end
local trooTemplate
if script:GetAttribute("SpeciesTroodonEnabled") ~= false then
	local ok, err = pcall(function()
		local folder = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(folder:WaitForChild("DinoModelBuilder"))
		local data = require(folder:WaitForChild("Models"):WaitForChild("TroodonModelData"))
		trooTemplate = Builder.build(data, {name = "Troodon"})
	end)
	script:SetAttribute("SpeciesTroodonTemplate", ok and trooTemplate and "ready" or ("missing " .. tostring(err)))
	if trooTemplate then SPECIES.Troodon = true end
else
	script:SetAttribute("SpeciesTroodonTemplate", "off")
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
			t[speciesField()] = value -- v1.10 (was t.lastSpecies)
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
	local sp = type(data) == "table" and data[speciesField()] or nil -- v1.10 (was data.lastSpecies)
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

-- v1.4: same as spawnPachy, from the herrera template
local function spawnHerrera(player)
	local char = herreraTemplate:Clone()
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

-- v1.5: same as spawnHerrera, from the teno template
local function spawnTeno(player)
	local char = tenoTemplate:Clone()
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

-- v1.6: same as spawnTeno, from the therizino template
local function spawnTherizino(player)
	local char = theriTemplate:Clone()
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

-- v1.7: same as spawnTherizino, from the dilo template
local function spawnDilo(player)
	local char = diloTemplate:Clone()
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

-- v1.8: same as spawnDilo, from the troodon template
local function spawnTroodon(player)
	local char = trooTemplate:Clone()
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
	elseif species == "Herrera" and herreraTemplate then -- v1.4
		spawnHerrera(player)
	elseif species == "Teno" and tenoTemplate then -- v1.5
		spawnTeno(player)
	elseif species == "Therizino" and theriTemplate then -- v1.6
		spawnTherizino(player)
	elseif species == "Dilo" and diloTemplate then -- v1.7
		spawnDilo(player)
	elseif species == "Troodon" and trooTemplate then -- v1.8
		spawnTroodon(player)
	else
		player:LoadCharacter()
	end
end

remote.OnServerEvent:Connect(function(player, species)
	if typeof(species) ~= "string" or not SPECIES[species] then
		player:SetAttribute("SpeciesLastResult", "badArg")
		return
	end
	do -- v1.11
		local lk = lockOf(player, species)
		if lk then
			player:SetAttribute("SpeciesLastResult", lk)
			return
		end
	end
	if species == "Raptor" and not raptorTemplate then
		player:SetAttribute("SpeciesLastResult", "noTemplate")
		return
	end
	if species == "Pachy" and not pachyTemplate then -- v1.2
		player:SetAttribute("SpeciesLastResult", "noTemplate")
		return
	end
	if species == "Herrera" and not herreraTemplate then -- v1.4
		player:SetAttribute("SpeciesLastResult", "noTemplate")
		return
	end
	if species == "Teno" and not tenoTemplate then -- v1.5
		player:SetAttribute("SpeciesLastResult", "noTemplate")
		return
	end
	if species == "Therizino" and not theriTemplate then -- v1.6
		player:SetAttribute("SpeciesLastResult", "noTemplate")
		return
	end
	if species == "Dilo" and not diloTemplate then -- v1.7
		player:SetAttribute("SpeciesLastResult", "noTemplate")
		return
	end
	if species == "Troodon" and not trooTemplate then -- v1.8
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
		if want == "Herrera" and herreraTemplate and speciesOf(char) ~= "Herrera" then -- v1.4
			task.defer(function()
				if player.Character == char then spawnHerrera(player) end
			end)
		end
		if want == "Teno" and tenoTemplate and speciesOf(char) ~= "Teno" then -- v1.5
			task.defer(function()
				if player.Character == char then spawnTeno(player) end
			end)
		end
		if want == "Therizino" and theriTemplate and speciesOf(char) ~= "Therizino" then -- v1.6
			task.defer(function()
				if player.Character == char then spawnTherizino(player) end
			end)
		end
		if want == "Dilo" and diloTemplate and speciesOf(char) ~= "Dilo" then -- v1.7
			task.defer(function()
				if player.Character == char then spawnDilo(player) end
			end)
		end
		if want == "Troodon" and trooTemplate and speciesOf(char) ~= "Troodon" then -- v1.8
			task.defer(function()
				if player.Character == char then spawnTroodon(player) end
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
			elseif want == "Herrera" and herreraTemplate then spawnHerrera(player) -- v1.4
			elseif want == "Teno" and tenoTemplate then spawnTeno(player) -- v1.5
			elseif want == "Therizino" and theriTemplate then spawnTherizino(player) -- v1.6
			elseif want == "Dilo" and diloTemplate then spawnDilo(player) -- v1.7
			elseif want == "Troodon" and trooTemplate then spawnTroodon(player) -- v1.8
			elseif want == "TRex" and speciesOf(char) == "Herrera" then player:LoadCharacter() -- v1.4
			elseif want == "TRex" and speciesOf(char) == "Teno" then player:LoadCharacter() -- v1.5
			elseif want == "TRex" and speciesOf(char) == "Therizino" then player:LoadCharacter() -- v1.6
			elseif want == "TRex" and speciesOf(char) == "Dilo" then player:LoadCharacter() -- v1.7
			elseif want == "TRex" and speciesOf(char) == "Troodon" then player:LoadCharacter() -- v1.8
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

-- v1.9: remember respawn picks (see the header)
local function watchRespawnPick(player)
	player:GetAttributeChangedSignal("RespawnPicked"):Connect(function()
		local sp = player:GetAttribute("RespawnPicked")
		if script:GetAttribute("SpeciesRememberPicksEnabled") ~= false and type(sp) == "string" and SPECIES[sp] then
			rememberSpecies(player, sp)
		end
	end)
end
Players.PlayerAdded:Connect(watchRespawnPick)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watchRespawnPick, p) end

-- v1.11: keep players off coming-soon and locked dinos (see the v1.11 note)
local function fallbackFor(player)
	local cands = {player:GetAttribute("SpeciesLastAllowed"), player:GetAttribute("FreeDino"), script:GetAttribute("SpeciesDefault")}
	for id in tostring(player:GetAttribute("OwnedDinos") or ""):gmatch("[^,]+") do table.insert(cands, id) end
	for _, c in ipairs(cands) do
		if type(c) == "string" and c ~= "" and SPECIES[c] and not lockOf(player, c) then return c end
	end
	return nil
end
local function enforceLocks(player)
	if not player.Parent then return end
	local sp = player:GetAttribute("DinoSpecies")
	if type(sp) ~= "string" or sp == "" then return end
	if not lockOf(player, sp) then
		if player:GetAttribute("SpeciesLastAllowed") ~= sp then player:SetAttribute("SpeciesLastAllowed", sp) end
		return
	end
	local fb = fallbackFor(player)
	if not fb then return end
	player:SetAttribute("SpeciesLockReverts", (player:GetAttribute("SpeciesLockReverts") or 0) + 1)
	player:SetAttribute("DinoSpecies", fb)
	local char = player.Character
	if char and speciesOf(char) ~= fb then
		task.defer(function() if player.Parent and player.Character == char then switch(player, fb) end end)
	end
end
local function watchLocks(player)
	for _, k in ipairs({"DinoSpecies", "OwnedDinos", "TutState"}) do
		player:GetAttributeChangedSignal(k):Connect(function() enforceLocks(player) end)
	end
	task.delay(1, enforceLocks, player)
end
Players.PlayerAdded:Connect(watchLocks)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watchLocks, p) end
script:GetAttributeChangedSignal("SpeciesComingSoon"):Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do enforceLocks(p) end
end)
