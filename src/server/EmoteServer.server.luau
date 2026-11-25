-- EmoteServer v1.0 (Mecha Dino Arena) — battle emotes: own, save, unlock, wheel, play, cancel, cooldown, buy.
-- Plan docs/plans/EMOTES_v1.0.md (Kepu 2026-11-24 20:27 "Build"); picks docs/plans/EMOTES_v0.1.md.
-- Catalog: ServerStorage.DinoArcade.EmoteCatalog (copied to ReplicatedStorage.EmoteShared for clients).
-- Remote ReplicatedStorage.DinoEmoteRequest (created here):
--   ("play", id)        owned + alive + out of the menu + cooldown passed + standing still -> character EmoteId, EmoteStartedAt (server
--                       time), EmoteDuration; player EmoteCooldownUntil = now + EmoteCooldown.
--   ("stop")            ends the player's emote.
--   ("equip", slot, id) puts an owned emote in wheel slot 1..8 (moves it if it is in another slot); id = "" empties the slot.
--   ("buy", id)         a 149 emote not owned -> intent {id, at} + Roblox prompt for SkinCatalog.PRODUCTS[rarity] (the skins' product).
-- Receipts: SkinServer 1.3 is the game's only ProcessReceipt; it asks the BindableFunction ServerStorage.EmoteReceipt (made here):
--   Invoke("intent", userId, rarity) -> intent time (os.clock) or nil; Invoke("grant", receipt) -> "emote" / "repeat" / nil (not ours).
-- Cancel (server): MoveDirection > EmoteMoveCancel, Jump, a health drop, any character attribute ending "StartedAt" (attacks,
--   abilities) other than EmoteStartedAt, death, or the length passing. Reason in player EmoteEndReason.
-- Own: free emotes; earned when the player attribute reaches need (ArenaW >= 10 Stomp Stomp, StatBestStreak >= 5 Play Dead), written to
--   owned once; robux by receipt; every emote while SkinCatalog.ALL_UNLOCKED (the skins' test switch).
-- Save: DataStore MDA_Emotes_v1, key "u<UserId>", {v = 1, owned = {[id] = true}, wheel = {8 x id or false}, receipts = {}}.
--   Never written before a successful load. Studio: EmoteTestMemoryStore = true uses an in-memory store.
-- Player attributes: EmoteSaveState, EmoteOwned (csv, catalog order), EmoteWheel (csv of 8, "" = empty), EmoteAllUnlocked,
--   EmoteCooldownUntil, EmoteResult, EmoteEndReason, EmoteUnlocked (last earned id, toast trigger).
-- Switches (script attributes): EmotesEnabled (false = this script does nothing), EmoteCooldown (3), EmoteStillSpeed (2, studs/s flat),
--   EmoteMoveCancel (0.1), EmoteBuyEnabled (true), EmoteTestMemoryStore (false).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local STORE = "MDA_Emotes_v1"
local LOAD_TRIES, LOAD_WAITS = 3, {2, 4}
local INTENT_TTL = 600
local RECEIPT_KEEP = 200

local function default(name, v) if script:GetAttribute(name) == nil then script:SetAttribute(name, v) end end
script:SetAttribute("EmoteServerVersion", VERSION)
default("EmotesEnabled", true)
default("EmoteCooldown", 3)
default("EmoteStillSpeed", 2)
default("EmoteMoveCancel", 0.1)
default("EmoteBuyEnabled", true)
default("EmoteTestMemoryStore", false)
script:SetAttribute("EmotePlays", 0)
script:SetAttribute("EmoteReceipts", 0)
if script:GetAttribute("EmotesEnabled") == false then return end

local dino = ServerStorage:WaitForChild("DinoArcade")
local catModule = dino:WaitForChild("EmoteCatalog")
local EC = require(catModule)
local SC = require(dino:WaitForChild("SkinCatalog"))

local shared = ReplicatedStorage:FindFirstChild("EmoteShared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "EmoteShared"
	shared.Parent = ReplicatedStorage
end
local oldCopy = shared:FindFirstChild("EmoteCatalog")
if oldCopy then oldCopy:Destroy() end
catModule:Clone().Parent = shared

local remote = ReplicatedStorage:FindFirstChild("DinoEmoteRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoEmoteRequest"
	remote.Parent = ReplicatedStorage
end

local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE) end)
	store = ok and s or nil
end
script:SetAttribute("EmoteStoreKind", store and "datastore" or "none")
if RunService:IsStudio() and script:GetAttribute("EmoteTestMemoryStore") == true then
	local mem = {}
	local function copy(v)
		if type(v) ~= "table" then return v end
		local t = {}
		for k, x in pairs(v) do t[k] = copy(x) end
		return t
	end
	store = {
		GetAsync = function(_, key) return copy(mem[key]) end,
		UpdateAsync = function(_, key, fn)
			local new = fn(copy(mem[key]))
			if new ~= nil then mem[key] = copy(new) end
			return copy(new)
		end,
	}
	script:SetAttribute("EmoteStoreKind", "memory")
end

local function isNoApi(err)
	err = tostring(err)
	return err:find("StudioAccessToApisNotAllowed") ~= nil or err:find("403") ~= nil or err:find("not allowed") ~= nil
end
local function bump(name) script:SetAttribute(name, (script:GetAttribute(name) or 0) + 1) end
local function blank(old)
	local v = type(old) == "table" and old or {}
	v.v = 1
	v.owned = type(v.owned) == "table" and v.owned or {}
	v.wheel = type(v.wheel) == "table" and v.wheel or {}
	v.receipts = type(v.receipts) == "table" and v.receipts or {}
	return v
end
local function trimReceipts(r)
	local n = 0
	for _ in pairs(r) do n += 1 end
	if n <= RECEIPT_KEEP then return end
	local list = {}
	for k, t in pairs(r) do table.insert(list, {k, tonumber(t) or 0}) end
	table.sort(list, function(a, b) return a[2] < b[2] end)
	for i = 1, n - RECEIPT_KEEP do r[list[i][1]] = nil end
end

local states = {} -- [player] = {loaded, owned, wheel, intent, conns}

local function stats(player)
	return {ArenaW = player:GetAttribute("ArenaW"), StatBestStreak = player:GetAttribute("StatBestStreak")}
end
local function owns(player, id)
	local st = states[player]
	return EC.owns(id, st and st.owned, SC.ALL_UNLOCKED, stats(player))
end
local function publish(player)
	local st = states[player]
	if not st then return end
	local ids = {}
	for _, id in ipairs(EC.ORDER) do if owns(player, id) then table.insert(ids, id) end end
	player:SetAttribute("EmoteOwned", table.concat(ids, ","))
	local w = {}
	for i = 1, EC.SLOTS do w[i] = st.wheel[i] or "" end
	player:SetAttribute("EmoteWheel", table.concat(w, ","))
	player:SetAttribute("EmoteAllUnlocked", SC.ALL_UNLOCKED == true)
end
local function setResult(player, r) player:SetAttribute("EmoteResult", r) end

-- fill empty wheel slots with owned emotes (catalog order) that are not on the wheel yet
local function fillWheel(player)
	local st = states[player]
	local on = {}
	for i = 1, EC.SLOTS do if st.wheel[i] then on[st.wheel[i]] = true end end
	local changed = false
	for _, id in ipairs(EC.ORDER) do
		if not on[id] and owns(player, id) then
			for i = 1, EC.SLOTS do
				if not st.wheel[i] then st.wheel[i] = id on[id] = true changed = true break end
			end
		end
	end
	return changed
end

local function saveWheel(player)
	local st = states[player]
	if not (st and st.loaded and store) then return end
	local w = {}
	for i = 1, EC.SLOTS do w[i] = st.wheel[i] or false end
	local ok, err = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local v = blank(old)
			v.wheel = w
			return v
		end)
	end)
	player:SetAttribute("EmoteSaveState", ok and "saved" or (isNoApi(err) and "noApi" or "saveFailed"))
end

-- earned emotes: written to owned once the stat reaches the need
local function checkEarn(player)
	local st = states[player]
	if not (st and st.loaded and store) then return end
	local new = {}
	for _, id in ipairs(EC.ORDER) do
		local e = EC.get(id)
		if e.unlock.kind == "earn" and st.owned[id] ~= true and EC.earned(id, stats(player)) then table.insert(new, id) end
	end
	if #new == 0 then return end
	local ok = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local v = blank(old)
			for _, id in ipairs(new) do v.owned[id] = true end
			return v
		end)
	end)
	if ok then
		for _, id in ipairs(new) do st.owned[id] = true end
		if fillWheel(player) then task.spawn(saveWheel, player) end
		player:SetAttribute("EmoteUnlocked", new[#new])
		publish(player)
	end
end

local function tryLoad(player)
	local st = states[player]
	if not st or st.loaded then return end
	if not store then player:SetAttribute("EmoteSaveState", "noApi") return end
	local lastErr
	for i = 1, LOAD_TRIES do
		if not player.Parent then return end
		local ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if ok then
			st.loaded = true
			if type(value) == "table" then
				if type(value.owned) == "table" then st.owned = value.owned end
				if type(value.wheel) == "table" then st.wheel = EC.sanitizeWheel(value.wheel) end
				player:SetAttribute("EmoteSaveState", "loaded")
			else
				player:SetAttribute("EmoteSaveState", "new")
			end
			-- unowned emotes leave the wheel (the test switch turned off, say); then empty slots fill
			for i = 1, EC.SLOTS do
				if st.wheel[i] and not owns(player, st.wheel[i]) then st.wheel[i] = false end
			end
			if fillWheel(player) then task.spawn(saveWheel, player) end
			publish(player)
			task.spawn(checkEarn, player)
			return
		end
		lastErr = value
		if isNoApi(value) then break end
		if i < LOAD_TRIES then task.wait(LOAD_WAITS[i] or 2) end
	end
	player:SetAttribute("EmoteSaveState", isNoApi(lastErr) and "noApi" or "loadFailed")
end

-- ---------- playing ----------
local function endEmote(player, reason)
	local char = player.Character
	if char and char:GetAttribute("EmoteId") ~= nil then
		char:SetAttribute("EmoteId", nil)
		char:SetAttribute("EmoteStartedAt", nil)
		char:SetAttribute("EmoteDuration", nil)
		player:SetAttribute("EmoteEndReason", reason)
	end
end

local function watch(player, char)
	local st = states[player]
	if not st then return end
	for _, c in ipairs(st.conns) do c:Disconnect() end
	st.conns = {}
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local lastHealth = hum.Health
	table.insert(st.conns, hum.HealthChanged:Connect(function(hp)
		if hp < lastHealth - 0.01 then endEmote(player, hp <= 0 and "died" or "hit") end
		lastHealth = hp
	end))
	table.insert(st.conns, hum:GetPropertyChangedSignal("Jump"):Connect(function()
		if hum.Jump then endEmote(player, "jump") end
	end))
	table.insert(st.conns, hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if hum.MoveDirection.Magnitude > (script:GetAttribute("EmoteMoveCancel") or 0.1) then endEmote(player, "move") end
	end))
	table.insert(st.conns, char.AttributeChanged:Connect(function(name)
		if name ~= "EmoteStartedAt" and name:sub(-9) == "StartedAt" and char:GetAttribute(name) ~= nil then endEmote(player, "attack:" .. name) end
	end))
end

local function onPlay(player, id)
	local st = states[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local e = EC.get(id)
	local now = workspace:GetServerTimeNow()
	if not (st and e) then return setResult(player, "badArg") end
	if not (hum and hrp and hum.Health > 0) then return setResult(player, "noBody") end
	if player:GetAttribute("InMenu") == true then return setResult(player, "inMenu") end
	if not owns(player, id) then return setResult(player, "notOwned") end
	if (tonumber(player:GetAttribute("EmoteCooldownUntil")) or 0) > now then return setResult(player, "cooldown") end
	local flat = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
	if flat > (script:GetAttribute("EmoteStillSpeed") or 2) or hum.MoveDirection.Magnitude > (script:GetAttribute("EmoteMoveCancel") or 0.1) then
		return setResult(player, "moving")
	end
	char:SetAttribute("EmoteDuration", e.dur)
	char:SetAttribute("EmoteStartedAt", now)
	char:SetAttribute("EmoteId", id)
	player:SetAttribute("EmoteCooldownUntil", now + (script:GetAttribute("EmoteCooldown") or 3))
	player:SetAttribute("EmoteEndReason", nil)
	bump("EmotePlays")
	setResult(player, "playing")
	task.delay(e.dur + 0.05, function()
		if char.Parent and char:GetAttribute("EmoteStartedAt") == now then endEmote(player, "done") end
	end)
	-- backup move check (MoveDirection / Jump may not reach the server on every device): flat speed while the emote runs
	task.spawn(function()
		while char.Parent and char:GetAttribute("EmoteStartedAt") == now do
			local v = hrp.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > 2 * (script:GetAttribute("EmoteStillSpeed") or 2) then endEmote(player, "move") break end
			if v.Y > 8 then endEmote(player, "jump") break end
			task.wait(0.1)
		end
	end)
end

local function onEquip(player, slot, id)
	local st = states[player]
	slot = tonumber(slot)
	if not (st and slot and slot >= 1 and slot <= EC.SLOTS and slot == math.floor(slot)) then return setResult(player, "badArg") end
	if not st.loaded then return setResult(player, "notLoaded") end
	if id == "" or id == nil then
		st.wheel[slot] = false
	else
		if not (EC.get(id) and owns(player, id)) then return setResult(player, "notOwned") end
		for i = 1, EC.SLOTS do if st.wheel[i] == id then st.wheel[i] = st.wheel[slot] end end
		st.wheel[slot] = id
	end
	publish(player)
	setResult(player, "equipped")
	task.spawn(saveWheel, player)
end

local buyOn = script:GetAttribute("EmoteBuyEnabled") ~= false
local function onBuy(player, id)
	local st = states[player]
	local e = EC.get(id)
	if not (st and e) then return setResult(player, "badArg") end
	if e.unlock.kind ~= "robux" then return setResult(player, "notForSale") end
	if owns(player, id) then publish(player) return setResult(player, "owned") end
	if not (buyOn and st.loaded and store) then return setResult(player, "notLoaded") end
	local pid = SC.PRODUCTS and SC.PRODUCTS[e.unlock.rarity]
	if not pid then return setResult(player, "noProduct") end
	st.intent = {id = id, rarity = e.unlock.rarity, at = os.clock()}
	local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, pid) end)
	setResult(player, ok and "prompted" or "promptFailed")
end

remote.OnServerEvent:Connect(function(player, action, a, b)
	if action == "play" then onPlay(player, a)
	elseif action == "stop" then endEmote(player, "stopped")
	elseif action == "equip" then onEquip(player, a, b)
	elseif action == "buy" then onBuy(player, a)
	end
end)

-- ---------- receipts (called by SkinServer 1.3) ----------
local hook = ServerStorage:FindFirstChild("EmoteReceipt")
if hook then hook:Destroy() end
hook = Instance.new("BindableFunction")
hook.Name = "EmoteReceipt"
hook.OnInvoke = function(kind, a, b)
	if kind == "intent" then
		local player = Players:GetPlayerByUserId(a)
		local st = player and states[player]
		local it = st and st.intent
		if it and it.rarity == b and os.clock() - it.at < INTENT_TTL then return it.at end
		return nil
	elseif kind == "grant" then
		local receipt = a
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local st = player and states[player]
		local it = st and st.intent
		if not (it and store and st.loaded) then return nil end
		local result
		local ok, value = pcall(function()
			return store:UpdateAsync("u" .. player.UserId, function(old)
				local v = blank(old)
				result = nil
				if v.receipts[receipt.PurchaseId] ~= nil then result = "repeat" return v end
				v.owned[it.id] = true
				v.receipts[receipt.PurchaseId] = os.time()
				trimReceipts(v.receipts)
				result = "emote"
				return v
			end)
		end)
		if not ok or not result then return nil end
		if type(value) == "table" and type(value.owned) == "table" then st.owned = value.owned end
		if result == "emote" then
			bump("EmoteReceipts")
			player:SetAttribute("EmoteUnlocked", it.id)
			st.intent = nil
			if fillWheel(player) then task.spawn(saveWheel, player) end
		end
		publish(player)
		setResult(player, result == "emote" and "bought" or "repeat")
		return result
	end
end
hook.Parent = ServerStorage

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, isPurchased)
	local player = Players:GetPlayerByUserId(userId)
	local st = player and states[player]
	if st and not isPurchased and st.intent then
		st.intent = nil
		setResult(player, "cancelled")
	end
end)

-- ---------- players ----------
local function onPlayer(player)
	states[player] = {loaded = false, owned = {}, wheel = EC.sanitizeWheel({}), conns = {}}
	player:SetAttribute("EmoteSaveState", "loading")
	publish(player)
	player.CharacterAdded:Connect(function(char) task.spawn(watch, player, char) end)
	if player.Character then task.spawn(watch, player, player.Character) end
	for _, stat in ipairs({"ArenaW", "StatBestStreak"}) do
		player:GetAttributeChangedSignal(stat):Connect(function() task.spawn(checkEarn, player) end)
	end
	task.spawn(tryLoad, player)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p)
	local st = states[p]
	if st then for _, c in ipairs(st.conns) do c:Disconnect() end end
	states[p] = nil
end)
