-- SkillServer v1.6 (Mecha Dino Arena) — skill tree XP, levels, points, buy / respec and saving. MDA-12, plan
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
-- v1.2 (skills per dino, MDA-44, plan docs/plans/SKILLS_PER_DINO_v1.0.md Task 1; Kepu 2026-10-29: "the skill points
--   should be separate for each dino" -> everything per dino, reset all):
--   * Each dino has its own record {xp, steps, loadout}. The dino key = the character's Species attribute, else the
--     player's DinoSpecies, else "TRex"; script attribute SkillPerDinoEnabled (default true) = false -> one record "All".
--   * The active record lives in the same d.xp / d.steps / d.loadout fields as before, so buy / respec / slot and the kill
--     XP act on the dino being played (a kill credits the dino played when its KilledAt is counted). On CharacterAdded and
--     when the character's Species changes, a different key stores the active fields in d.dinos[old key], loads the new
--     key's record (fresh {0 XP, no steps, empty loadout} if none) and publishes it with no level-up stamp. Player
--     attribute SkillDino = the active key.
--   * Saving: new DataStore SAVE_STORE_V2 "MDA_Skills_v2" (Kepu: reset all; "MDA_Skills_v1" is no longer read or written
--     and stays as it is), value {v = 2, dinos = {[key] = {xp, steps, loadout}}}. Each loaded record is sanitized like
--     1.1 (a build over its points is refunded, the loadout sanitized); a value without v = 2 counts as "new".
-- v1.3 (Cloak release, MDA-50, plan docs/plans/CLOAK_v1.0.md Task 2; SkillTree 1.5, ADR-003 / ADR-004):
--   * The active dino key goes into every SkillTree call (sanitize / spent / buy / autoSlot / setSlot / sanitizeLoadout):
--     a dino only buys, slots and keeps its own paths plus the shared ones it isn't skipped from. A buy of another
--     dino's path -> SkillLastResult "otherDino"; a 4th mastered line -> "masteryFull" (SkillTree 1.5).
--   * Loaded records (cleanRecord(raw, key)) are sanitized for their dino (e.g. a T-Rex record's Thrusters / Regeneration
--     steps are dropped and their points come back); a record over Mastery 3 has every line cut back to step II; then,
--     as before, a build over its points (now 40 at level 41) is refunded.
--   * Empty loadouts are built from SkillTree.SLOTS (4): fresh records, the load default and respec.
-- v1.4 (test unlock; Kepu 2026-10-29: "for testing sake we'll have whatever we just implemented unlocked", private
--   publish; picked "Cloak given" + "Test switch only"): script attribute SkillTestCloakEnabled (default false; set true
--   on the place's SkillServer for testing). While it is true and the active dino is "Raptor", publish shows a test layer
--   over the real record: SkillPath_cloak = 4 (star) and SkillSlot1 = "cloak" (Cloak removed from any other slot; the
--   real slot-1 part is hidden while the layer is on). SkillEffects / CloakServer / the screens read those attributes, so
--   the Cloak works at star in R. The layer is never stored: d.steps / d.loadout, points, buys, slots and the save stay
--   the real record, so switching the attribute off (or playing the T-Rex) shows the real build again at once.
--   Points are not charged for the given Cloak. Diagnostic: player attribute SkillTestCloak ("on" / "off").
-- v1.5 (bug, Kepu 2026-10-29: "i unlocked thrusters and its not assigning to the button"): 1.4 forced SkillSlot1 =
--   "cloak" over the real loadout, so (a) a bought part auto-slotted into the real slot 1 was hidden under the Cloak, and
--   (b) the SKILLS loadout tiles cycled to the given Cloak first and the server refused it ("notOwned": the real record
--   has no Cloak), so a tile never reached Thrusters. Now, while the layer is on, the dino's loadout works with the
--   effective steps (real steps + cloak 4, stepsFor): sanitizeLoadout in publish, autoSlot on a buy and setSlot on a
--   slot request treat the Cloak as owned, and the Cloak is placed once (autoSlot: the first empty slot, R on an empty
--   loadout) when the layer turns on for that dino (d.testPlaced[key]; cleared when the layer is off for it and on
--   respec). Nothing is hidden: SkillSlot1..4 are the loadout itself. Points, steps and buys stay real; a "cloak" left
--   in a saved loadout is dropped on load (not owned) and when the layer is off.
-- v1.6 (Kepu 2026-10-29, after raptor parts batch 1 shipped and Blade Claws had to be bought: "all things that are added
--   need to be maxed unlocked for testing"): the same switch (SkillTestCloakEnabled) now gives EVERY live mecha part of
--   the active dino at star (SkillTree.LIVE_MECH paths the dino owns: today the raptor's Cloak Field, Thrusters, Blade
--   Claws, Adrenaline Injector, Energy Shield; later batches join automatically), not only the Cloak, and for any dino
--   (1.5: raptor only). stepsFor = real steps with each of those set to 4. Each button part among them is placed once
--   into the first empty slot (d.testPlaced[key] is now a set of part ids; an old boolean counts as {cloak}); passive
--   parts (Blade Claws) need no slot. Points, steps, buys and the save stay real, as before. New diagnostic: player
--   attribute SkillTestParts (the given ids, comma-separated; "" when off).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local VERSION = "1.6"
local SAVE_STORE = "MDA_Skills_v1"
local SAVE_STORE_V2 = "MDA_Skills_v2" -- v1.2: per-dino records (reset all)
local SAVE_GAP = 10
local RETRY_GAP = 30
local REQUEST_GAP = 0.2
local DEFAULTS = {SkillEnabled = true, SkillKillXpFraction = 0.5, SkillSaveEnabled = true}
DEFAULTS.SkillLoadoutEnabled = true -- v1.1
DEFAULTS.SkillPerDinoEnabled = true -- v1.2
DEFAULTS.SkillTestCloakEnabled = false -- v1.4: test layer (raptor Cloak at star in slot 1, not saved)

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
	local ok, s = pcall(function() return DataStoreService:GetDataStore(SAVE_STORE_V2) end) -- v1.2 (was SAVE_STORE)
	store = ok and s or nil
end

local data = {} -- [player] = {xp, steps, loaded, dirty, lastSave, lastRequest; v1.2: dinos, active}

-- v1.6: the live mecha parts the active dino owns (PATH_ORDER order)
local function testParts(d)
	local out = {}
	if script:GetAttribute("SkillTestCloakEnabled") ~= true or not d.active then return out end
	for _, id in ipairs(ST.PATH_ORDER) do
		local p = ST.PATHS[id]
		if ST.LIVE_MECH[id] and p and not p.soon and ST.seesPath(p, d.active) then table.insert(out, id) end
	end
	return out
end
local function testCloak(d) -- v1.4; v1.6: true when the layer gives any part to this dino
	return #testParts(d) > 0
end
local function stepsFor(d) -- v1.5: real steps, plus the test parts at star while the layer is on (v1.6: all live parts)
	local parts = testParts(d)
	if #parts == 0 then return d.steps end
	local s = table.clone(d.steps)
	for _, id in ipairs(parts) do s[id] = 4 end
	return s
end

local function publish(player, d, levelUp)
	local test = testCloak(d) -- v1.4
	player:SetAttribute("SkillTestCloak", test and "on" or "off")
	local given = testParts(d) -- v1.6
	player:SetAttribute("SkillTestParts", table.concat(given, ","))
	local level, into, nxt = ST.levelOf(d.xp)
	local earned = ST.pointsOf(level)
	local spent = ST.spent(d.steps, d.active) -- v1.3: + dino
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
	local eff = stepsFor(d) -- v1.5 (1.4: cloak 4 here only)
	for _, id in ipairs(ST.PATH_ORDER) do
		player:SetAttribute("SkillPath_" .. id, eff[id] or 0)
	end
	d.loadout = ST.sanitizeLoadout(d.loadout, eff, d.active) -- v1.1; v1.3: + dino; v1.5: effective steps
	d.testPlaced = d.testPlaced or {}
	if test then -- v1.5: the given Cloak takes the first empty slot once (1.4 forced slot 1 and hid the real part)
		if d.active then -- v1.6: every given button part, each once
			local placed = d.testPlaced[d.active]
			if type(placed) ~= "table" then placed = placed and {cloak = true} or {} end
			for _, id in ipairs(given) do
				if not placed[id] then
					placed[id] = true
					d.loadout = ST.autoSlot(d.loadout, eff, id, d.active) -- passive parts are left out by autoSlot
				end
			end
			d.testPlaced[d.active] = placed
		end
	elseif d.active then
		d.testPlaced[d.active] = nil
	end
	for n = 1, ST.SLOTS do player:SetAttribute("SkillSlot" .. n, d.loadout[n] or "") end
end

-- v1.2: per-dino records -------------------------------------------------------------------------------------------
local function dinoKey(player)
	if script:GetAttribute("SkillPerDinoEnabled") == false then return "All" end
	local c = player.Character
	local s = c and c:GetAttribute("Species")
	if type(s) == "string" and s ~= "" then return s end
	s = player:GetAttribute("DinoSpecies")
	if type(s) == "string" and s ~= "" then return s end
	return "TRex"
end
local function emptyLoadout() -- v1.3: SLOTS empties (4)
	local l = {}
	for n = 1, ST.SLOTS do l[n] = false end
	return l
end
local function stash(d) -- the active fields back into their record
	if d.active then d.dinos[d.active] = {xp = d.xp, steps = d.steps, loadout = d.loadout} end
end
local function switchTo(player, d, key)
	if d.active == key then return end
	stash(d)
	local r = d.dinos[key] or {xp = 0, steps = ST.sanitize({}, key), loadout = emptyLoadout()} -- v1.3
	d.xp, d.steps, d.loadout = r.xp, r.steps, r.loadout
	d.active = key
	player:SetAttribute("SkillDino", key)
	if d.loaded then publish(player, d, false) end
end
local function cleanRecord(raw, key) -- a saved record -> {xp, steps, loadout}, sanitized like 1.1; v1.3: for its dino
	local xp = math.max(0, math.floor(tonumber(type(raw) == "table" and raw.xp) or 0))
	local steps = ST.sanitize(type(raw) == "table" and raw.steps or {}, key)
	if not ST.masteryOk(steps, key) then -- v1.3: over Mastery 3 -> every line back to step II
		for id, n in pairs(steps) do if n > 2 then steps[id] = 2 end end
	end
	if ST.spent(steps, key) > ST.pointsOf((ST.levelOf(xp))) then steps = ST.sanitize({}, key) end
	return {xp = xp, steps = steps, loadout = ST.sanitizeLoadout(type(raw) == "table" and raw.loadout or nil, steps, key)}
end

local function save(player, d)
	if script:GetAttribute("SkillSaveEnabled") == false or not store then return end
	local st = player:GetAttribute("SkillSaveState")
	if st == "noApi" or st == "loading" then return end
	d.lastSave = os.clock()
	stash(d) -- v1.2
	local value = {v = 2, dinos = d.dinos} -- v1.2 (1.1: {v = 1, xp, steps, loadout})
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
		loadout = emptyLoadout()} -- v1.1: + loadout; v1.3: SLOTS empties
	d.dinos, d.active = {}, nil -- v1.2
	data[player] = d
	if script:GetAttribute("SkillSaveEnabled") == false or not store then
		player:SetAttribute("SkillSaveState", "off")
	else
		player:SetAttribute("SkillSaveState", "loading")
		local ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if not player.Parent then return end
		if not ok then
			player:SetAttribute("SkillSaveState", tostring(value):find("not allowed") and "noApi" or "failed")
		elseif type(value) == "table" and value.v == 2 and type(value.dinos) == "table" then -- v1.2: per-dino records
			for key, raw in pairs(value.dinos) do
				if type(key) == "string" then d.dinos[key] = cleanRecord(raw, key) end -- v1.3: + key
			end
			player:SetAttribute("SkillSaveState", "loaded")
		else
			player:SetAttribute("SkillSaveState", "new")
		end
	end
	switchTo(player, d, dinoKey(player)) -- v1.2: the dino being played (d.loaded is still false: no publish yet)
	d.loaded = true
	publish(player, d, false)
end

-- v1.2: follow the dino being played
local function hookCharacter(player, char)
	local function check()
		local d = data[player]
		if d and d.active then switchTo(player, d, dinoKey(player)) end
	end
	check()
	char:GetAttributeChangedSignal("Species"):Connect(check)
end
local function hookPlayer(player)
	player.CharacterAdded:Connect(function(char) hookCharacter(player, char) end)
	if player.Character then hookCharacter(player, player.Character) end
end
Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
script:GetAttributeChangedSignal("SkillTestCloakEnabled"):Connect(function() -- v1.4
	for player, d in pairs(data) do
		if d.loaded then publish(player, d, false) end
	end
end)
script:GetAttributeChangedSignal("SkillPerDinoEnabled"):Connect(function()
	for player, d in pairs(data) do
		if d.active then switchTo(player, d, dinoKey(player)) end
	end
end)

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
		local new, why = ST.buy(d.steps, pathId, earned, d.active) -- v1.3: + dino
		if new then
			d.steps = new
			if script:GetAttribute("SkillLoadoutEnabled") ~= false then d.loadout = ST.autoSlot(d.loadout, stepsFor(d), pathId, d.active) end -- v1.1; v1.3: + dino; v1.5: effective steps
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
			local new, why = ST.setSlot(d.loadout, stepsFor(d), pathId, slotPath or "", d.active) -- v1.3: + dino; v1.5: effective steps
			if new then
				d.loadout = new
				d.dirty = true
				publish(player, d, false)
			end
			player:SetAttribute("SkillLastResult", why)
		end
	elseif action == "respec" then
		d.steps = ST.sanitize({}, d.active)
		d.loadout = emptyLoadout() -- v1.1; v1.3: SLOTS empties
		if d.testPlaced and d.active then d.testPlaced[d.active] = nil end -- v1.5: the test Cloak is placed again
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
