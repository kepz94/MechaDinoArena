-- DinoOwnership v1.0 (Mecha Dino Arena) — which dinos a player owns, their free dino and their first-time flow state (Script,
-- ServerScriptService). MDA-559, plan docs/plans/FIRST_TIME_FLOW_v1.0.md Task 1, ADR-013, mockup docs/mockups/first_time_flow_v0.3.html.
-- Kepu 2026-11-22: a new player rolls a free dino (all its mecha parts maxed); old players keep every dino and never see the flow;
--   10:46 red-team: no gate in this build (every dino stays pickable; DINO_UNLOCKS_v1.0 later), a saved lastSpecies also marks
--   an old player.
-- Store: DataStore "MDA_Owned_v1", key "u" .. UserId, value {v = 1, owned = {[key] = true}, free = key | nil,
--   tut = {done = bool, at = os.time()}}. Read at join (pcall). Also read (only) "MDA_Settings_v1" field lastSpecies (SpeciesServer
--   1.3) and the player's SkillSaveState (SkillServer; waited up to OWN_SKILL_WAIT (15) s while "loading" / unset, then "failed").
-- State: TutorialRules.classify(value, readOk, skillState, hasLastSpecies, OwnershipEnabled, Workspace TutorialTestForce):
--   "grand" -> owned = all 8, tut.done = true, written once (script OwnGrandfathered += 1).
--   "new"   -> no value yet; TutActive = true (the flow starts at step 1).
--   "resume"-> the stored value (rolled, not finished); TutActive = true (the flow restarts at step 3).
--   "done"  -> the stored value; TutActive = false.
--   "off"   -> owns all, TutActive = false, nothing written (a store outage never locks anyone out or forces the flow).
--   Studio force ("new" by TutorialTestForce) -> nothing is ever written for that player (OwnNoWrite).
-- Player attributes (all written here): TutState ("wait" until classified, then one of the above), TutActive (bool),
--   OwnedDinos (comma list, TutorialRules.ownedString), FreeDino ("" or key; SkillServer 1.13 gives that dino's parts).
-- BindableFunctions (children of this script, server only):
--   OwnRoll:Invoke(player) -> key | nil, why. Only while TutState is "new" or "resume": the first call picks
--     TutorialRules.rollPick(ROLL_POOL, Random) and stores owned = {key}, free = key, tut.done = false; later calls return the
--     stored free dino. Sets FreeDino, OwnedDinos, DinoSpecies = key, TutState = "resume". Refused: "notTutorial".
--   OwnFinishTut:Invoke(player) -> true | false, why. Sets tut.done = true, TutActive = false, TutState = "done", writes.
-- Writes: UpdateAsync (the new value replaces the stored one), retried every OWN_RETRY (30) s while it fails, and once more
--   on leave. Diagnostics: script OwnershipVersion, OwnSaveState ("ok" / "noStore" / "readFailed" / "writeFailed"),
--   OwnGrandfathered, OwnRolls; player OwnLastResult.
-- Switch: script attribute OwnershipEnabled (default true, read per join; false -> every joiner "off").
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local VERSION = "1.0"
script:SetAttribute("OwnershipVersion", VERSION)
if script:GetAttribute("OwnershipEnabled") == nil then script:SetAttribute("OwnershipEnabled", true) end
if script:GetAttribute("OwnSkillWait") == nil then script:SetAttribute("OwnSkillWait", 15) end
if script:GetAttribute("OwnRetry") == nil then script:SetAttribute("OwnRetry", 30) end
script:SetAttribute("OwnGrandfathered", script:GetAttribute("OwnGrandfathered") or 0)
script:SetAttribute("OwnRolls", script:GetAttribute("OwnRolls") or 0)

local R = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("TutorialRules"))

local store, settings
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore("MDA_Owned_v1") end)
	store = ok and s or nil
	local ok2, s2 = pcall(function() return DataStoreService:GetDataStore("MDA_Settings_v1") end)
	settings = ok2 and s2 or nil
	if not store then script:SetAttribute("OwnSaveState", "noStore") end
end

local data = {} -- [player] = {value = table?, noWrite = bool, dirty = bool}

local function publish(player, d)
	local v = d.value
	local owned = (d.state == "off" or d.state == "grand") and R.allOwned() or (v and v.owned) or {}
	player:SetAttribute("OwnedDinos", R.ownedString(owned))
	player:SetAttribute("FreeDino", v and type(v.free) == "string" and v.free or "")
end

local function write(player, d)
	if d.noWrite or not store or not d.value then return true end
	local value = d.value
	local ok, err = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function() return value end)
	end)
	if ok then
		d.dirty = false
		script:SetAttribute("OwnSaveState", "ok")
	else
		d.dirty = true
		script:SetAttribute("OwnSaveState", "writeFailed")
		warn("[DinoOwnership] write failed: " .. tostring(err))
	end
	return ok
end

local function setState(player, d, state)
	d.state = state
	player:SetAttribute("TutState", state)
	player:SetAttribute("TutActive", state == "new" or state == "resume")
	publish(player, d)
end

local function onPlayer(player)
	local d = {value = nil, noWrite = false, dirty = false, state = "wait"}
	data[player] = d
	player:SetAttribute("TutState", "wait")
	player:SetAttribute("TutActive", false)
	local enabled = script:GetAttribute("OwnershipEnabled") ~= false
	local force = workspace:GetAttribute("TutorialTestForce") == true
	local readOk, value, hasLast = false, nil, false
	if enabled and store then
		local ok, v = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		readOk = ok
		if ok then value = type(v) == "table" and v or nil else script:SetAttribute("OwnSaveState", "readFailed") end
		if settings then
			local ok2, sv = pcall(function() return settings:GetAsync("u" .. player.UserId) end)
			hasLast = ok2 and type(sv) == "table" and type(sv.lastSpecies) == "string" or false
		end
	end
	if not player.Parent then return end
	local t0 = os.clock()
	local wait = script:GetAttribute("OwnSkillWait") or 15
	local ss = player:GetAttribute("SkillSaveState")
	while (ss == nil or ss == "loading") and os.clock() - t0 < wait and player.Parent do
		task.wait(0.2)
		ss = player:GetAttribute("SkillSaveState")
	end
	if not player.Parent then return end
	if ss == nil or ss == "loading" then ss = "failed" end
	local state = R.classify(value, readOk, ss, hasLast, enabled, force)
	d.noWrite = force
	if state == "grand" then
		d.value = {v = 1, owned = R.allOwned(), tut = {done = true, at = os.time()}}
		script:SetAttribute("OwnGrandfathered", (script:GetAttribute("OwnGrandfathered") or 0) + 1)
		write(player, d)
	elseif state == "done" or state == "resume" then
		d.value = value
	elseif state == "new" then
		d.value = nil
	end
	setState(player, d, state)
end

-- OwnRoll / OwnFinishTut
local function fn(name)
	local f = script:FindFirstChild(name)
	if not f then f = Instance.new("BindableFunction") f.Name = name f.Parent = script end
	return f
end

fn("OwnRoll").OnInvoke = function(player)
	local d = data[player]
	if not d or (d.state ~= "new" and d.state ~= "resume") then
		if player and player.Parent then player:SetAttribute("OwnLastResult", "notTutorial") end
		return nil, "notTutorial"
	end
	if d.value and type(d.value.free) == "string" then
		player:SetAttribute("OwnLastResult", "rolled " .. d.value.free)
		return d.value.free
	end
	local key = R.rollPick(R.ROLL_POOL, Random.new():NextNumber())
	d.value = {v = 1, owned = {[key] = true}, free = key, tut = {done = false, at = os.time()}}
	script:SetAttribute("OwnRolls", (script:GetAttribute("OwnRolls") or 0) + 1)
	player:SetAttribute("DinoSpecies", key)
	setState(player, d, "resume")
	player:SetAttribute("OwnLastResult", "rolled " .. key)
	task.spawn(write, player, d)
	return key
end

fn("OwnFinishTut").OnInvoke = function(player)
	local d = data[player]
	if not d then return false, "noData" end
	if d.value then
		d.value.tut = {done = true, at = os.time()}
	end
	if d.state == "new" or d.state == "resume" then setState(player, d, "done") end
	player:SetAttribute("OwnLastResult", "finished")
	task.spawn(write, player, d)
	return true
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

Players.PlayerRemoving:Connect(function(player)
	local d = data[player]
	if d and d.dirty then write(player, d) end
	data[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(script:GetAttribute("OwnRetry") or 30)
		for player, d in pairs(data) do
			if d.dirty and player.Parent then write(player, d) end
		end
	end
end)

game:BindToClose(function()
	for player, d in pairs(data) do
		if d.dirty then write(player, d) end
	end
end)
