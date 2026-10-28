-- SkillServer v1.1 (Mecha Dino Arena) — skill tree XP, levels, points, buy / respec and saving. MDA-12, plan
-- docs/plans/SKILLTREES_v1.0.md Task 2, ADR "Skill trees own XP and replace class stat points".
-- Kepu: kills give XP, each level gives 1 skill point (cap 60), free respec any time, keep everything on death, builds
--   saved. GrowthServer stays off (adult spawns); this script owns skill XP. Maths: ServerStorage.DinoArcade.SkillTree.
-- Client copy: at start SkillTree is cloned into ReplicatedStorage.SkillShared (folder) for SkillScreen 1.0.
-- XP: every model with IsBot = true is watched (the KillRegenServer 1.0 pattern). A new KilledAt value on a bot
--   (BiteServer / PounceServer / SkillEffects bleed stamp KilledBy, KilledByUserId, KilledWith, then KilledAt) credits
--   the player KilledByUserId (else the player named KilledBy) with DummyMaxHealth x SkillKillXpFraction XP, rounded.
--   Each bot's KilledAt value is counted once. A killer who is not in the game is not credited (bot attribute
--   SkillXpCredited = "noPlayer"; else the player's name). Dead killers are credited (state lives on the Player).
--   Player kills come later with PvP.
-- Requests: RemoteEvent ReplicatedStorage.SkillRequest, client -> server ("buy", pathId) or ("respec"). Before the
--   player's data is loaded, or within REQUEST_GAP s of the last request -> "busy". Bad arguments -> "badArg".
--   buy: SkillTree.buy with the player's points; respec: every step back to 0 (free). Result in SkillLastResult.
-- Saving: DataStore SAVE_STORE, key "u" .. UserId, value {v = 1, xp = total XP, steps = {[pathId] = n}}. Loaded at join
--   (SkillSaveState "loading" -> "loaded" (data found) / "new" (no data) / "noApi" (Studio without API access) /
--   "failed" (any other error: the session goes on with a fresh build and saving is retried every RETRY_GAP s)).
--   Saved when something changed, at most every SAVE_GAP s, and on leave and server close -> "saved" (or "failed").
--   SkillSaveEnabled = false: no loading or saving ("off"), session only.
-- Player attributes (all written here): SkillLevel, SkillXP (total), SkillXPInto, SkillXPNext (0 at max), SkillPoints
--   (earned), SkillSpent, SkillLeft, SkillPath_<pathId> (0-4, every path), SkillLastResult, SkillLastXp ("kill +30"),
--   SkillSaveState, SkillLevelUpAt (server time, on a level-up from XP).
-- Script attributes: SkillServerVersion, SkillEnabled (default true; false = no XP and requests -> "disabled"),
--   SkillKillXpFraction (0.5), SkillSaveEnabled (true), SkillKillsCounted (total credited kills).
-- v1.1 (mecha loadout, MDA-25, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 2): 2 loadout slots (SkillTree 1.1).
--   Save value {v = 1, xp, steps, loadout = {[1] = id or false, [2] = id or false}}; loaded through
--   SkillTree.sanitizeLoadout (a save without loadout -> both empty). Buying a step of a BUTTONS path runs
--   SkillTree.autoSlot (the first step fills the first empty slot). Request ("slot", n, pathId or "") -> SkillTree.setSlot
--   ("" = clear); result "ok" / "badSlot" / "notButton" / "notOwned" in SkillLastResult (bad argument types -> "badArg").
--   Respec empties both slots. Player attributes SkillSlot1 / SkillSlot2 (path id or ""). Script attribute
--   SkillLoadoutEnabled (default true; false -> slot requests "disabled", buys don't auto-slot, the loadout stays as is).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local VERSION = "1.1"
local SAVE_STORE = "MDA_Skills_v1"
local SAVE_GAP = 10
local RETRY_GAP = 30
local REQUEST_GAP = 0.2
local DEFAULTS = {SkillEnabled = true, SkillKillXpFraction = 0.5, SkillSaveEnabled = true}
DEFAULTS.SkillLoadoutEnabled = true -- v1.1

local treeModule = ServerStorage:WaitForChild("DinoArcade"):WaitForChild("SkillTree")
local ST = require(treeModule)

script:SetAttribute("SkillServerVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("SkillKillsCounted", 0)

-- client copy of the tree
local shared = ReplicatedStorage:FindFirstChild("SkillShared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "SkillShared"
	shared.Parent = ReplicatedStorage
end
local oldCopy = shared:FindFirstChild("SkillTree")
if oldCopy then oldCopy:Destroy() end
treeModule:Clone().Parent = shared

local remote = ReplicatedStorage:FindFirstChild("SkillRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "SkillRequest"
	remote.Parent = ReplicatedStorage
end

local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(SAVE_STORE) end)
	store = ok and s or nil
end

local data = {} -- [player] = {xp, steps, loaded, dirty, lastSave, lastRequest}

local function publish(player, d, levelUp)
	local level, into, nxt = ST.levelOf(d.xp)
	local earned = ST.pointsOf(level)
	local spent = ST.spent(d.steps)
	if levelUp and (player:GetAttribute("SkillLevel") or level) < level then
		player:SetAttribute("SkillLevelUpAt", workspace:GetServerTimeNow())
	end
	player:SetAttribute("SkillLevel", level)
	player:SetAttribute("SkillXP", d.xp)
	player:SetAttribute("SkillXPInto", into)
	player:SetAttribute("SkillXPNext", nxt)
	player:SetAttribute("SkillPoints", earned)
	player:SetAttribute("SkillSpent", spent)
	player:SetAttribute("SkillLeft", earned - spent)
	for _, id in ipairs(ST.PATH_ORDER) do
		player:SetAttribute("SkillPath_" .. id, d.steps[id] or 0)
	end
	d.loadout = ST.sanitizeLoadout(d.loadout, d.steps) -- v1.1
	for n = 1, ST.SLOTS do player:SetAttribute("SkillSlot" .. n, d.loadout[n] or "") end
end

local function save(player, d)
	if script:GetAttribute("SkillSaveEnabled") == false or not store then return end
	local st = player:GetAttribute("SkillSaveState")
	if st == "noApi" or st == "loading" then return end
	d.lastSave = os.clock()
	local value = {v = 1, xp = d.xp, steps = d.steps, loadout = d.loadout} -- v1.1: + loadout
	local ok, err = pcall(function() store:SetAsync("u" .. player.UserId, value) end)
	if ok then
		d.dirty = false
		if player.Parent then player:SetAttribute("SkillSaveState", "saved") end
	else
		if player.Parent then
			player:SetAttribute("SkillSaveState", tostring(err):find("not allowed") and "noApi" or "failed")
		end
	end
end

local function load(player)
	local d = {xp = 0, steps = ST.sanitize({}), loaded = false, dirty = false, lastSave = os.clock(), lastRequest = 0,
		loadout = {false, false}} -- v1.1: + loadout
	data[player] = d
	if script:GetAttribute("SkillSaveEnabled") == false or not store then
		player:SetAttribute("SkillSaveState", "off")
	else
		player:SetAttribute("SkillSaveState", "loading")
		local ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if not player.Parent then return end
		if not ok then
			player:SetAttribute("SkillSaveState", tostring(value):find("not allowed") and "noApi" or "failed")
		elseif type(value) == "table" then
			d.xp = math.max(0, math.floor(tonumber(value.xp) or 0))
			d.steps = ST.sanitize(value.steps)
			-- a saved build that no longer fits the points (curve change) is refunded
			if ST.spent(d.steps) > ST.pointsOf((ST.levelOf(d.xp))) then d.steps = ST.sanitize({}) end
			d.loadout = ST.sanitizeLoadout(value.loadout, d.steps) -- v1.1
			player:SetAttribute("SkillSaveState", "loaded")
		else
			player:SetAttribute("SkillSaveState", "new")
		end
	end
	d.loaded = true
	publish(player, d, false)
end

Players.PlayerAdded:Connect(load)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(load, p) end
Players.PlayerRemoving:Connect(function(player)
	local d = data[player]
	if d and d.loaded and d.dirty then save(player, d) end
	data[player] = nil
end)
game:BindToClose(function()
	for player, d in pairs(data) do
		if d.loaded and d.dirty then save(player, d) end
	end
end)

-- periodic saves (changed data at most every SAVE_GAP s; failed ones retried every RETRY_GAP s)
task.spawn(function()
	while true do
		task.wait(1)
		for player, d in pairs(data) do
			if d.loaded and d.dirty then
				local gap = player:GetAttribute("SkillSaveState") == "failed" and RETRY_GAP or SAVE_GAP
				if os.clock() - d.lastSave >= gap then task.spawn(save, player, d) end
			end
		end
	end
end)

-- requests
remote.OnServerEvent:Connect(function(player, action, pathId, slotPath) -- v1.1: + slotPath ("slot": pathId = slot n)
	local d = data[player]
	if script:GetAttribute("SkillEnabled") == false then
		player:SetAttribute("SkillLastResult", "disabled")
		return
	end
	if not d or not d.loaded or os.clock() - d.lastRequest < REQUEST_GAP then
		player:SetAttribute("SkillLastResult", "busy")
		return
	end
	d.lastRequest = os.clock()
	if action == "buy" and type(pathId) == "string" then
		local earned = ST.pointsOf((ST.levelOf(d.xp)))
		local new, why = ST.buy(d.steps, pathId, earned)
		if new then
			d.steps = new
			if script:GetAttribute("SkillLoadoutEnabled") ~= false then d.loadout = ST.autoSlot(d.loadout, d.steps, pathId) end -- v1.1
			d.dirty = true
			publish(player, d, false)
		end
		player:SetAttribute("SkillLastResult", why)
	elseif action == "slot" then -- v1.1
		if script:GetAttribute("SkillLoadoutEnabled") == false then
			player:SetAttribute("SkillLastResult", "disabled")
		elseif type(pathId) ~= "number" or (type(slotPath) ~= "string" and slotPath ~= nil) then
			player:SetAttribute("SkillLastResult", "badArg")
		else
			local new, why = ST.setSlot(d.loadout, d.steps, pathId, slotPath or "")
			if new then
				d.loadout = new
				d.dirty = true
				publish(player, d, false)
			end
			player:SetAttribute("SkillLastResult", why)
		end
	elseif action == "respec" then
		d.steps = ST.sanitize({})
		d.loadout = {false, false} -- v1.1
		d.dirty = true
		publish(player, d, false)
		player:SetAttribute("SkillLastResult", "ok")
	else
		player:SetAttribute("SkillLastResult", "badArg")
	end
end)

-- XP from bot kills
local counted = setmetatable({}, {__mode = "k"}) -- [bot] = the KilledAt value already credited
local function credit(bot)
	local at = bot:GetAttribute("KilledAt")
	if typeof(at) ~= "number" or counted[bot] == at then return end
	counted[bot] = at
	if script:GetAttribute("SkillEnabled") == false then return end
	local player = Players:GetPlayerByUserId(bot:GetAttribute("KilledByUserId") or 0)
		or Players:FindFirstChild(tostring(bot:GetAttribute("KilledBy")))
	local d = player and data[player]
	if not d or not d.loaded then
		bot:SetAttribute("SkillXpCredited", "noPlayer")
		return
	end
	local maxHp = tonumber(bot:GetAttribute("DummyMaxHealth")) or 0
	local gain = math.floor(maxHp * (script:GetAttribute("SkillKillXpFraction") or 0.5) + 0.5)
	d.xp += gain
	d.dirty = true
	publish(player, d, true)
	player:SetAttribute("SkillLastXp", "kill +" .. gain)
	bot:SetAttribute("SkillXpCredited", player.Name)
	script:SetAttribute("SkillKillsCounted", (script:GetAttribute("SkillKillsCounted") or 0) + 1)
end

local watched = setmetatable({}, {__mode = "k"})
local function watch(m)
	if watched[m] or not m:IsA("Model") or m:GetAttribute("IsBot") ~= true then return end
	watched[m] = true
	m:GetAttributeChangedSignal("KilledAt"):Connect(function() credit(m) end)
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		if d:GetAttribute("IsBot") == true then
			watch(d)
		else
			local conn
			conn = d:GetAttributeChangedSignal("IsBot"):Connect(function()
				conn:Disconnect()
				watch(d)
			end)
			task.delay(2, function() if conn.Connected then conn:Disconnect() end end)
		end
	end
end)
for _, d in ipairs(workspace:GetDescendants()) do watch(d) end
