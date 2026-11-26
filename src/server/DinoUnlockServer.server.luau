-- DinoUnlockServer v1.0 (Mecha Dino Arena) — unlock a dino with skill points (base) or Robux (maxed) (Script, ServerScriptService).
-- Kepu 2026-11-26 08:06 "make dinos 40 skill points to unlock base or pay robux to unlock maxed out"; picks "Spend 40 (as said)",
--   "R$149". Works with SpeciesServer 1.11 (locked dinos can't be picked), DinoOwnership 1.2 (OwnGrant, MaxedDinos), SkillServer 1.17
--   (SkillSpendUnlock) and SkinServer 1.8 (the game's only ProcessReceipt asks ServerStorage.DinoReceipt).
-- RemoteFunction ReplicatedStorage.DinoUnlockRequest (made here):
--   ("points", dino) -> result. dino one of TutorialRules.ALL_DINOS, not coming soon (ReplicatedStorage DinoComingSoon), not owned
--     (player OwnedDinos), ownership known (TutState "done"; "new" / "resume" -> "notReady"; "wait" -> "notLoaded"). One request at a
--     time. SkillServer.SkillSpendUnlock(player, DinoUnlockCost (40), "unlock <dino>") -> "ok" then DinoOwnership.OwnGrant(player, dino,
--     false) -> "ok" (base: owned, parts bought with points as usual). A grant that fails gives the points back
--     (SkillGrantPoints, "refund") -> "failed". Else "notEnough" (with the player's pool) / "owned" / "comingSoon" / "unknown" /
--     "busy".
--   ("robux", dino) -> result. Same checks, but an owned dino that is not maxed may still be bought (-> maxed); owned + maxed ->
--     "owned". Keeps the intent {dino, at} and opens Roblox's window for SkinCatalog.PRODUCTS[DinoUnlockRarity ("RARE", R$149)] ->
--     "prompted". The window is cancelled -> intent dropped.
-- ServerStorage.DinoReceipt (BindableFunction, made here) for SkinServer 1.8: Invoke("intent", userId, rarity) -> the intent's time
--   (os.clock) when it is for that rarity and younger than 600 s, else nil; Invoke("grant", receipt) -> "dino" (OwnGrant(player,
--   dino, true) gave "ok" / "owned", then the PurchaseId is written to DataStore DinoUnlockStoreName ("MDA_DinoUnlock_v1"),
--   key "u<UserId>", {v = 1, receipts = {[PurchaseId] = os.time()}}) / "repeat" (already written) / nil (not ours or not ready:
--   Roblox retries).
-- Player attributes: DinoUnlockResult (last result), DinoUnlocked (the last dino unlocked), DinoUnlockedAt (server time).
-- Switches / numbers (script attributes): DinoUnlockEnabled (true, read at start), DinoUnlockCost (40, read per request),
--   DinoUnlockRarity ("RARE"), DinoUnlockRobuxEnabled (true, read per request). Diagnostics: DinoUnlockServerVersion,
--   DinoUnlockPoints, DinoUnlockRobux (counts).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local VERSION = "1.0"
script:SetAttribute("DinoUnlockServerVersion", VERSION)
for k, v in pairs({DinoUnlockEnabled = true, DinoUnlockCost = 40, DinoUnlockRarity = "RARE", DinoUnlockRobuxEnabled = true,
	DinoUnlockStoreName = "MDA_DinoUnlock_v1"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
if script:GetAttribute("DinoUnlockEnabled") == false then return end
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end
local INTENT_TTL = 600

local arcade = ServerStorage:WaitForChild("DinoArcade")
local TR = require(arcade:WaitForChild("TutorialRules"))
local SC = require(arcade:WaitForChild("SkinCatalog"))
local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(tostring(script:GetAttribute("DinoUnlockStoreName"))) end)
	store = ok and s or nil
end

local function has(csv, id) return string.find("," .. tostring(csv or "") .. ",", "," .. id .. ",", 1, true) ~= nil end
local function hook(scriptName, fnName)
	local s = ServerScriptService:FindFirstChild(scriptName)
	return s and s:FindFirstChild(fnName)
end
local function result(player, r)
	player:SetAttribute("DinoUnlockResult", r)
	return r
end
local function check(player, dino)
	if type(dino) ~= "string" or not table.find(TR.ALL_DINOS, dino) then return "unknown" end
	if has(ReplicatedStorage:GetAttribute("DinoComingSoon"), dino) then return "comingSoon" end
	local ts = player:GetAttribute("TutState")
	if ts == nil or ts == "wait" then return "notLoaded" end
	if ts == "new" or ts == "resume" then return "notReady" end
	return nil
end

local busy, intents = {}, {}
local function points(player, dino)
	local why = check(player, dino)
	if why then return result(player, why) end
	if has(player:GetAttribute("OwnedDinos"), dino) then return result(player, "owned") end
	if busy[player] then return result(player, "busy") end
	local spend, grant = hook("SkillServer", "SkillSpendUnlock"), hook("DinoOwnership", "OwnGrant")
	if not (spend and grant) then return result(player, "failed") end
	busy[player] = true
	local cost = math.floor(tonumber(script:GetAttribute("DinoUnlockCost")) or 40)
	local ok, r, have = pcall(function() return spend:Invoke(player, cost, "unlock " .. dino) end)
	if not ok or r ~= "ok" then
		busy[player] = nil
		if ok and r == "notEnough" then return result(player, "notEnough"), have end
		return result(player, ok and tostring(r) or "failed")
	end
	local okG, g = pcall(function() return grant:Invoke(player, dino, false) end)
	busy[player] = nil
	if not (okG and (g == "ok" or g == "owned")) then
		local refund = hook("SkillServer", "SkillGrantPoints")
		if refund then pcall(function() refund:Invoke(player, cost, "refund") end) end
		return result(player, "failed")
	end
	bump("DinoUnlockPoints")
	player:SetAttribute("DinoUnlocked", dino)
	player:SetAttribute("DinoUnlockedAt", workspace:GetServerTimeNow())
	return result(player, "ok")
end

local function robux(player, dino)
	if script:GetAttribute("DinoUnlockRobuxEnabled") == false then return result(player, "disabled") end
	local why = check(player, dino)
	if why then return result(player, why) end
	if has(player:GetAttribute("OwnedDinos"), dino) and has(player:GetAttribute("MaxedDinos"), dino) then return result(player, "owned") end
	local rarity = tostring(script:GetAttribute("DinoUnlockRarity") or "RARE")
	local pid = SC.PRODUCTS and SC.PRODUCTS[rarity]
	if not pid then return result(player, "failed") end
	intents[player] = {dino = dino, rarity = rarity, at = os.clock()}
	local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, pid) end)
	if not ok then intents[player] = nil return result(player, "failed") end
	return result(player, "prompted")
end

local remote = ReplicatedStorage:FindFirstChild("DinoUnlockRequest")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "DinoUnlockRequest"
	remote.Parent = ReplicatedStorage
end
remote.OnServerInvoke = function(player, action, dino)
	if action == "points" then return points(player, dino) end
	if action == "robux" then return robux(player, dino) end
	return result(player, "badArg")
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, isPurchased)
	local player = Players:GetPlayerByUserId(userId)
	if player and not isPurchased and intents[player] then
		intents[player] = nil
		result(player, "cancelled")
	end
end)

-- receipts (asked by SkinServer 1.8)
local receiptHook = ServerStorage:FindFirstChild("DinoReceipt")
if receiptHook then receiptHook:Destroy() end
receiptHook = Instance.new("BindableFunction")
receiptHook.Name = "DinoReceipt"
receiptHook.OnInvoke = function(kind, a, b)
	if kind == "intent" then
		local player = Players:GetPlayerByUserId(a)
		local it = player and intents[player]
		if it and it.rarity == b and os.clock() - it.at < INTENT_TTL then return it.at end
		return nil
	elseif kind == "grant" then
		local receipt = a
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local it = player and intents[player]
		if not (it and store) then return nil end
		local seen = false
		local okR = pcall(function()
			local v = store:GetAsync("u" .. player.UserId)
			seen = type(v) == "table" and type(v.receipts) == "table" and v.receipts[receipt.PurchaseId] ~= nil
		end)
		if not okR then return nil end
		if seen then intents[player] = nil return "repeat" end
		local grant = hook("DinoOwnership", "OwnGrant")
		local okG, g = pcall(function() return grant and grant:Invoke(player, it.dino, true) end)
		if not (okG and (g == "ok" or g == "owned")) then return nil end
		local okW = pcall(function()
			store:UpdateAsync("u" .. player.UserId, function(old)
				local v = type(old) == "table" and old or {}
				v.v = 1
				v.receipts = type(v.receipts) == "table" and v.receipts or {}
				v.receipts[receipt.PurchaseId] = os.time()
				return v
			end)
		end)
		if not okW then return nil end
		intents[player] = nil
		bump("DinoUnlockRobux")
		player:SetAttribute("DinoUnlocked", it.dino)
		player:SetAttribute("DinoUnlockedAt", workspace:GetServerTimeNow())
		result(player, "bought")
		return "dino"
	end
end
receiptHook.Parent = ServerStorage

Players.PlayerRemoving:Connect(function(p) busy[p] = nil intents[p] = nil end)
