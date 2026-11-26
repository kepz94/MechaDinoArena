-- TrailServer v1.0 (Mecha Dino Arena) — dino trails: own, save, earn, equip, buy (plan docs/plans/TRAILS_v1.0.md, Kepu
-- 2026-11-25 11:00 "Build"; picks docs/plans/TRAILS_v0.1.md).
-- Catalog: ServerStorage.DinoArcade.TrailCatalog (copied to ReplicatedStorage.TrailShared for clients).
-- Remote ReplicatedStorage.DinoTrailRequest (created here):
--   ("equip", id)  an owned trail id, or "none" -> player TrailEquipped = id (saved); every character of the player gets
--                  TrailId = id ("" for none). One trail for every dino (pick A). Not owned -> TrailResult "notOwned".
--   ("buy", id)    a 149 trail not owned -> intent {id, rarity, at} + Roblox prompt for SkinCatalog.PRODUCTS[rarity] (the
--                  skins' product).
-- Receipts: SkinServer 1.4 is the game's only ProcessReceipt; it asks the BindableFunction ServerStorage.TrailReceipt (made here):
--   Invoke("intent", userId, rarity) -> intent time (os.clock) or nil; Invoke("grant", receipt) -> "trail" / "repeat" / nil.
--   The newest of the skin, emote and trail intents takes a receipt.
-- Own: Neon Streak free; earned when the player attribute reaches need (ArenaW >= 25 Fossil Prints, StatKills >= 250 Comet Tail),
--   written to owned once; robux by receipt; every trail while SkinCatalog.ALL_UNLOCKED (the skins' test switch).
-- Equipped default: TrailCatalog.DEFAULT ("neon"). An equipped trail that is no longer owned (the test switch turned off) falls
--   back to the default.
-- Save: DataStore MDA_Trails_v1, key "u<UserId>", {v = 1, owned = {[id] = true}, equipped = id, receipts = {}}. Never written
--   before a successful load. Studio: TrailTestMemoryStore = true uses an in-memory store.
-- Player attributes: TrailSaveState, TrailOwned (csv, catalog order), TrailEquipped, TrailAllUnlocked, TrailResult,
--   TrailUnlocked (last id earned or bought, toast trigger). Character attribute: TrailId.
-- Switches (script attributes): TrailsEnabled (false = this script does nothing: no remote, no TrailId), TrailBuyEnabled (true),
--   TrailTestMemoryStore (false). Diagnostics: TrailServerVersion, TrailStoreKind, TrailReceipts, TrailEquips.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 TrailGrant
-- v1.1 (Favorite Egg, plan docs/plans/FAVORITE_EGG_v1.0.md Task 2, MDA-608): server-only BindableFunction TrailGrant (child of this
--   script): Invoke(player, id, reason) -> "ok" (written to owned with one UpdateAsync, TrailUnlocked set) / "owned" / "unknown" /
--   "notLoaded" / "failed" / "disabled". Buying and receipts are not touched. Switch: script attribute TrailGrantEnabled (true, read
--   per call). Diagnostic: TrailGrants.
local STORE = "MDA_Trails_v1"
local LOAD_TRIES, LOAD_WAITS = 3, {2, 4}
local INTENT_TTL = 600
local RECEIPT_KEEP = 200

local function default(name, v) if script:GetAttribute(name) == nil then script:SetAttribute(name, v) end end
script:SetAttribute("TrailServerVersion", VERSION)
default("TrailsEnabled", true)
default("TrailBuyEnabled", true)
default("TrailTestMemoryStore", false)
script:SetAttribute("TrailReceipts", 0)
script:SetAttribute("TrailEquips", 0)
if script:GetAttribute("TrailsEnabled") == false then return end

local dino = ServerStorage:WaitForChild("DinoArcade")
local catModule = dino:WaitForChild("TrailCatalog")
local TC = require(catModule)
local SC = require(dino:WaitForChild("SkinCatalog"))

local shared = ReplicatedStorage:FindFirstChild("TrailShared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "TrailShared"
	shared.Parent = ReplicatedStorage
end
local oldCopy = shared:FindFirstChild("TrailCatalog")
if oldCopy then oldCopy:Destroy() end
catModule:Clone().Parent = shared

local remote = ReplicatedStorage:FindFirstChild("DinoTrailRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoTrailRequest"
	remote.Parent = ReplicatedStorage
end

local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE) end)
	store = ok and s or nil
end
script:SetAttribute("TrailStoreKind", store and "datastore" or "none")
if RunService:IsStudio() and script:GetAttribute("TrailTestMemoryStore") == true then
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
	script:SetAttribute("TrailStoreKind", "memory")
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

local states = {} -- [player] = {loaded, owned, equipped, intent}

local function stats(player)
	return {ArenaW = player:GetAttribute("ArenaW"), StatKills = player:GetAttribute("StatKills")}
end
local function owns(player, id)
	local st = states[player]
	return TC.owns(id, st and st.owned, SC.ALL_UNLOCKED, stats(player))
end
local function setResult(player, r) player:SetAttribute("TrailResult", r) end

-- the trail every character of this player draws ("" = none)
local function stampChar(player, char)
	local st = states[player]
	if not (st and char) then return end
	local id = st.equipped
	if id ~= TC.NONE and not owns(player, id) then id = TC.DEFAULT end
	char:SetAttribute("TrailId", id == TC.NONE and "" or id)
end
local function publish(player)
	local st = states[player]
	if not st then return end
	local ids = {}
	for _, id in ipairs(TC.ORDER) do if owns(player, id) then table.insert(ids, id) end end
	player:SetAttribute("TrailOwned", table.concat(ids, ","))
	local eq = st.equipped
	if eq ~= TC.NONE and not owns(player, eq) then eq = TC.DEFAULT end
	player:SetAttribute("TrailEquipped", eq)
	player:SetAttribute("TrailAllUnlocked", SC.ALL_UNLOCKED == true)
	stampChar(player, player.Character)
end

local function saveEquipped(player)
	local st = states[player]
	if not (st and st.loaded and store) then return end
	local eq = st.equipped
	local ok, err = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local v = blank(old)
			v.equipped = eq
			return v
		end)
	end)
	player:SetAttribute("TrailSaveState", ok and "saved" or (isNoApi(err) and "noApi" or "saveFailed"))
end

-- earned trails: written to owned once the stat reaches the need
local function checkEarn(player)
	local st = states[player]
	if not (st and st.loaded and store) then return end
	local new = {}
	for _, id in ipairs(TC.ORDER) do
		local t = TC.get(id)
		if t.unlock.kind == "earn" and st.owned[id] ~= true and TC.earned(id, stats(player)) then table.insert(new, id) end
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
		player:SetAttribute("TrailUnlocked", new[#new])
		publish(player)
	end
end

local function tryLoad(player)
	local st = states[player]
	if not st or st.loaded then return end
	if not store then player:SetAttribute("TrailSaveState", "noApi") return end
	local lastErr
	for i = 1, LOAD_TRIES do
		if not player.Parent then return end
		local ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if ok then
			st.loaded = true
			if type(value) == "table" then
				if type(value.owned) == "table" then st.owned = value.owned end
				st.equipped = TC.clean(value.equipped) or TC.DEFAULT
				player:SetAttribute("TrailSaveState", "loaded")
			else
				player:SetAttribute("TrailSaveState", "new")
			end
			publish(player)
			task.spawn(checkEarn, player)
			return
		end
		lastErr = value
		if isNoApi(value) then break end
		if i < LOAD_TRIES then task.wait(LOAD_WAITS[i] or 2) end
	end
	player:SetAttribute("TrailSaveState", isNoApi(lastErr) and "noApi" or "loadFailed")
end

local function onEquip(player, id)
	local st = states[player]
	local clean = TC.clean(id)
	if not (st and clean) then return setResult(player, "badArg") end
	if clean ~= TC.NONE and not owns(player, clean) then return setResult(player, "notOwned") end
	st.equipped = clean
	bump("TrailEquips")
	publish(player)
	setResult(player, clean == TC.NONE and "off" or "equipped")
	task.spawn(saveEquipped, player)
end

local function onBuy(player, id)
	local st = states[player]
	local t = TC.get(id)
	if not (st and t) then return setResult(player, "badArg") end
	if t.unlock.kind ~= "robux" then return setResult(player, "notForSale") end
	if owns(player, id) then publish(player) return setResult(player, "owned") end
	if not (script:GetAttribute("TrailBuyEnabled") ~= false and st.loaded and store) then return setResult(player, "notLoaded") end
	local pid = SC.PRODUCTS and SC.PRODUCTS[t.unlock.rarity]
	if not pid then return setResult(player, "noProduct") end
	st.intent = {id = id, rarity = t.unlock.rarity, at = os.clock()}
	local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, pid) end)
	setResult(player, ok and "prompted" or "promptFailed")
end

remote.OnServerEvent:Connect(function(player, action, a)
	if action == "equip" then onEquip(player, a)
	elseif action == "buy" then onBuy(player, a)
	end
end)

-- ---------- receipts (called by SkinServer 1.4) ----------
local hook = ServerStorage:FindFirstChild("TrailReceipt")
if hook then hook:Destroy() end
hook = Instance.new("BindableFunction")
hook.Name = "TrailReceipt"
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
				result = "trail"
				return v
			end)
		end)
		if not ok or not result then return nil end
		if type(value) == "table" and type(value.owned) == "table" then st.owned = value.owned end
		if result == "trail" then
			bump("TrailReceipts")
			player:SetAttribute("TrailUnlocked", it.id)
			st.intent = nil
		end
		publish(player)
		setResult(player, result == "trail" and "bought" or "repeat")
		return result
	end
end
hook.Parent = ServerStorage
-- v1.1: TrailGrant (see the v1.1 note)
if script:GetAttribute("TrailGrantEnabled") == nil then script:SetAttribute("TrailGrantEnabled", true) end
do
	local grantFn = script:FindFirstChild("TrailGrant") or Instance.new("BindableFunction")
	grantFn.Name = "TrailGrant"
	grantFn.Parent = script
	grantFn.OnInvoke = function(player, id, reason)
		if script:GetAttribute("TrailGrantEnabled") == false then return "disabled" end
		if typeof(player) ~= "Instance" or not player:IsA("Player") or type(id) ~= "string" or not TC.get(id) then return "unknown" end
		local st = states[player]
		if not (st and st.loaded and store) then return "notLoaded" end
		if st.owned[id] == true then return "owned" end
		local ok, value = pcall(function()
			return store:UpdateAsync("u" .. player.UserId, function(old)
				local v = blank(old)
				v.owned[id] = true
				return v
			end)
		end)
		if not (ok and player.Parent) then return "failed" end
		if type(value) == "table" and type(value.owned) == "table" then st.owned = value.owned end
		st.owned[id] = true
		bump("TrailGrants")
		player:SetAttribute("TrailUnlocked", id)
		publish(player)
		setResult(player, "granted")
		return "ok"
	end
end

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
	states[player] = {loaded = false, owned = {}, equipped = TC.DEFAULT}
	player:SetAttribute("TrailSaveState", "loading")
	publish(player)
	player.CharacterAdded:Connect(function(char) stampChar(player, char) end)
	for _, stat in ipairs({"ArenaW", "StatKills"}) do
		player:GetAttributeChangedSignal(stat):Connect(function()
			task.spawn(checkEarn, player)
			publish(player)
		end)
	end
	task.spawn(tryLoad, player)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p) states[p] = nil end)
