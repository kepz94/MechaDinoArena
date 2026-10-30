-- SkinServer v1.0 (Mecha Dino Arena) — dino skins: tags every new dino body by colour role, paints the player's equipped
-- skin on it, takes equip requests from the Lab (menu only) and saves the choice. MDA-106, plan docs/plans/SKINS_v1.0.md
-- Task 2, mockup docs/mockups/skins_lab_tab.html (Kepu 2026-10-30: "whatever is chosen in the menu is what youre spawning
-- with every time unless you choose a different skin"; "is there no way to assign a skin to a dino and keep it that way
-- until unassigned?"; Neon accepted: "this is an arcade game").
-- Client copy: at start SkinCatalog (ServerStorage.DinoArcade) is cloned into ReplicatedStorage.SkinShared (folder) for
--   Lab 1.6.
-- New body (Players.PlayerAdded -> CharacterAdded; also the raptor SpeciesServer swaps in, which fires CharacterAdded): the
--   species is the character attribute Species, else the player attribute DinoSpecies. Every BasePart of the body that is
--   visible (Transparency < 1), not the HumanoidRootPart, not inside a "Hitboxes" folder and not inside a Mecha_* model
--   gets, once, the attribute SkinRole = SkinCatalog.roleOf(species, its colour) (when that colour has a role; teeth,
--   pupils, mouths ... have none) and SkinBaseMaterial = its Material name. Then the equipped skin of that species is
--   painted: each tagged part's Color = the skin's colour for its role, Material = the skin's material for the role, else
--   SkinBaseMaterial. Character attributes SkinParts (tagged parts) and, last, SkinApplied (skin id).
-- Equip: ReplicatedStorage.DinoSkinRequest:FireServer("equip", skinId). Checks, first failing wins: "badArg" (not
--   "equip" + a string), "notInMenu" (player InMenu ~= true: skins are picked in the menu Lab only), "noBody" (no
--   character / species), "unknown" (not a skin of the current species), "locked" (not free and not owned; v1: no
--   purchases yet), "same" (already equipped), "ok". ok: player attribute SkinEquipped_<Species> = id, the live body is
--   painted at once, a save is queued. Player attribute SkinServerResult (+ SkinServerResultAt).
-- Persistence (the choice stays until the player picks another; Classic = the default look):
--   * DataStore STORE (MDA_Skins_v1), key "u<UserId>", value {v = 1, equipped = {[species] = id}, owned = {}} (owned is
--     reserved for the buying plan and only carried through).
--   * Load at join with GetAsync, LOAD_TRIES (3) attempts, waits LOAD_WAITS (2, 4) s between them. Data -> "loaded",
--     none -> "new". Failure -> "loadFailed" (or "noApi" in Studio without API access): the player plays with the defaults
--     and NOTHING is written for that player while the load has not succeeded (a failed load can never overwrite a stored
--     skin); the load is retried every RETRY_GAP (30) s and a later success applies the stored skins.
--   * Save with UpdateAsync (merge: only this session's equipped[species] values replace the stored ones; other species,
--     owned and unknown fields are kept) SAVE_GAP (6) s after a change, on PlayerRemoving and in game:BindToClose, in pcall
--     with one retry. SkinSaveState "saved" / "saveFailed" (retried at the next gap).
--   * Stored ids are checked with SkinCatalog.sanitize / owns when painting; an unknown or locked stored id paints the
--     default but the stored value is left alone.
-- Switches: script attribute SkinServerEnabled (default true, read at start; false = nothing tagged, painted or saved,
--   requests ignored). Test switch SkinTestForceLoadFail (default false; true = every load attempt fails, for checking
--   the no-write rule).
-- Diagnostics: script SkinServerVersion, SkinRequests; player SkinSaveState ("loading" / "loaded" / "new" /
--   "loadFailed" / "noApi" / "saved" / "saveFailed"), SkinEquipped_<Species>, SkinServerResult, SkinWrites (successful
--   writes this session); character SkinParts, SkinApplied.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local VERSION = "1.0"
local STORE = "MDA_Skins_v1"
local LOAD_TRIES, LOAD_WAITS = 3, {2, 4}
local RETRY_GAP = 30
local SAVE_GAP = 6

script:SetAttribute("SkinServerVersion", VERSION)
script:SetAttribute("SkinRequests", 0)
if script:GetAttribute("SkinServerEnabled") == nil then script:SetAttribute("SkinServerEnabled", true) end
if script:GetAttribute("SkinTestForceLoadFail") == nil then script:SetAttribute("SkinTestForceLoadFail", false) end
if script:GetAttribute("SkinServerEnabled") == false then return end

local catalogModule = ServerStorage:WaitForChild("DinoArcade"):WaitForChild("SkinCatalog")
local SC = require(catalogModule)

-- client copy
local shared = ReplicatedStorage:FindFirstChild("SkinShared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "SkinShared"
	shared.Parent = ReplicatedStorage
end
local oldCopy = shared:FindFirstChild("SkinCatalog")
if oldCopy then oldCopy:Destroy() end
catalogModule:Clone().Parent = shared

local remote = ReplicatedStorage:FindFirstChild("DinoSkinRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoSkinRequest"
	remote.Parent = ReplicatedStorage
end

local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE) end)
	store = ok and s or nil
end

local states = {} -- [player] = {loaded, equipped = {[species] = id}, owned = {}, changed = {[species] = true}, lastChange}

local function speciesOf(player, char)
	local s = char and char:GetAttribute("Species")
	if type(s) ~= "string" or not SC.SKINS[s] then s = player:GetAttribute("DinoSpecies") end
	if type(s) == "string" and SC.SKINS[s] then return s end
	return nil
end

local function equippedId(player, species)
	local st = states[player]
	local id = st and st.equipped[species]
	id = SC.sanitize(species, id)
	if not SC.owns(species, id, st and st.owned) then id = SC.default(species) end
	return id
end

local function publish(player)
	local st = states[player]
	if not st then return end
	for species in pairs(SC.SKINS) do
		player:SetAttribute("SkinEquipped_" .. species, equippedId(player, species))
	end
end

-- tag a body once (SkinRole / SkinBaseMaterial)
local function tag(char, species)
	local n = 0
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
			local skip = p:FindFirstAncestor("Hitboxes") ~= nil
			if not skip then
				local m = p:FindFirstAncestorWhichIsA("Model")
				while m and m ~= char do
					if m.Name:sub(1, 6) == "Mecha_" then skip = true break end
					m = m:FindFirstAncestorWhichIsA("Model")
				end
			end
			if not skip then
				if p:GetAttribute("SkinRole") == nil then
					local role = SC.roleOf(species, p.Color)
					if role then
						p:SetAttribute("SkinRole", role)
						p:SetAttribute("SkinBaseMaterial", p.Material.Name)
					end
				end
				if p:GetAttribute("SkinRole") ~= nil then n += 1 end
			end
		end
	end
	char:SetAttribute("SkinParts", n)
end

local function paint(char, species, id)
	local skin = SC.get(species, id) or SC.get(species, SC.default(species))
	if not skin then return end
	for _, p in ipairs(char:GetDescendants()) do
		local role = p:IsA("BasePart") and p:GetAttribute("SkinRole")
		if role then
			local hex = skin.colors[role]
			if hex then p.Color = Color3.fromHex(hex) end
			local mat = skin.materials and skin.materials[role] or p:GetAttribute("SkinBaseMaterial")
			if type(mat) == "string" then
				local ok, m = pcall(function() return Enum.Material[mat] end)
				if ok and m then p.Material = m end
			end
		end
	end
	char:SetAttribute("SkinApplied", skin.id) -- last: clients react to this one
end

local function dress(player, char)
	char = char or player.Character
	if not (char and char.Parent) then return end
	local species = speciesOf(player, char)
	if not species then return end
	tag(char, species)
	paint(char, species, equippedId(player, species))
end

-- saving
local function isNoApi(err)
	local e = tostring(err)
	return e:find("not allowed") ~= nil or e:find("StudioAccessToApisNotAllowed") ~= nil or e:find("API Services") ~= nil
end

local function save(player)
	local st = states[player]
	if not (st and store and st.loaded) then return end -- never write before a successful load
	if next(st.changed) == nil then return end
	local changes = {}
	for species in pairs(st.changed) do changes[species] = st.equipped[species] end
	local function attempt()
		return pcall(function()
			store:UpdateAsync("u" .. player.UserId, function(old)
				local v = type(old) == "table" and old or {}
				v.v = 1
				v.equipped = type(v.equipped) == "table" and v.equipped or {}
				v.owned = type(v.owned) == "table" and v.owned or {}
				for species, id in pairs(changes) do v.equipped[species] = id end
				return v
			end)
		end)
	end
	local ok, err = attempt()
	if not ok then ok, err = attempt() end
	if ok then
		for species, id in pairs(changes) do
			if st.equipped[species] == id then st.changed[species] = nil end
		end
		player:SetAttribute("SkinSaveState", "saved")
		player:SetAttribute("SkinWrites", (player:GetAttribute("SkinWrites") or 0) + 1)
	else
		player:SetAttribute("SkinSaveState", isNoApi(err) and "noApi" or "saveFailed")
	end
end

-- loading
local function tryLoad(player)
	local st = states[player]
	if not st or st.loaded then return end
	if not store then
		player:SetAttribute("SkinSaveState", "noApi")
		return
	end
	local lastErr
	for i = 1, LOAD_TRIES do
		if not player.Parent then return end
		local ok, value
		if script:GetAttribute("SkinTestForceLoadFail") == true then
			ok, value = false, "forced load failure (SkinTestForceLoadFail)"
		else
			ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		end
		if ok then
			st.loaded = true
			if type(value) == "table" then
				if type(value.owned) == "table" then st.owned = value.owned end
				if type(value.equipped) == "table" then
					for species, id in pairs(value.equipped) do
						if type(species) == "string" and type(id) == "string" and st.changed[species] == nil then
							st.equipped[species] = id
						end
					end
				end
				player:SetAttribute("SkinSaveState", "loaded")
			else
				player:SetAttribute("SkinSaveState", "new")
			end
			publish(player)
			dress(player)
			return
		end
		lastErr = value
		if isNoApi(value) then break end
		if i < LOAD_TRIES then task.wait(LOAD_WAITS[i] or 2) end
	end
	player:SetAttribute("SkinSaveState", isNoApi(lastErr) and "noApi" or "loadFailed")
end

local function onPlayer(player)
	states[player] = {loaded = false, equipped = {}, owned = {}, changed = {}, lastChange = 0}
	player:SetAttribute("SkinSaveState", "loading")
	publish(player)
	player.CharacterAdded:Connect(function(char)
		task.defer(function() dress(player, char) end)
	end)
	if player.Character then task.defer(function() dress(player, player.Character) end) end
	task.spawn(tryLoad, player)
	-- retry a failed load (never a save) until it succeeds
	task.spawn(function()
		while player.Parent and states[player] and not states[player].loaded do
			task.wait(RETRY_GAP)
			local s = player:GetAttribute("SkinSaveState")
			if player.Parent and states[player] and not states[player].loaded and (s == "loadFailed") then tryLoad(player) end
		end
	end)
end

remote.OnServerEvent:Connect(function(player, action, id)
	script:SetAttribute("SkinRequests", (script:GetAttribute("SkinRequests") or 0) + 1)
	local st = states[player]
	local char = player.Character
	local species = char and speciesOf(player, char)
	local result
	if action ~= "equip" or type(id) ~= "string" or not st then
		result = "badArg"
	elseif player:GetAttribute("InMenu") ~= true then
		result = "notInMenu"
	elseif not (char and char.Parent and species) then
		result = "noBody"
	elseif not SC.get(species, id) then
		result = "unknown"
	elseif not SC.owns(species, id, st.owned) then
		result = "locked"
	elseif equippedId(player, species) == id then
		result = "same"
	else
		result = "ok"
		st.equipped[species] = id
		st.changed[species] = true
		st.lastChange = os.clock()
		publish(player)
		dress(player, char)
	end
	player:SetAttribute("SkinServerResult", result)
	player:SetAttribute("SkinServerResultAt", workspace:GetServerTimeNow())
end)

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	states[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do save(player) end
end)

-- periodic saves: changed choices SAVE_GAP s after the last change
task.spawn(function()
	while true do
		task.wait(1)
		for player, st in pairs(states) do
			if st.loaded and next(st.changed) ~= nil and os.clock() - st.lastChange >= SAVE_GAP then
				save(player)
				if next(st.changed) ~= nil then st.lastChange = os.clock() end -- failed: try again a gap later
			end
		end
	end
end)
