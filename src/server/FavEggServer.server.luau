-- FavEggServer v1.0 (Mecha Dino Arena) — the Favorite Egg: the 48 h window, the one roll, the grant (Script, ServerScriptService).
-- Plan docs/plans/FAVORITE_EGG_v1.0.md Task 3 (MDA-609), mockup docs/mockups/favorite_egg_v0.1.html "B · Prize reel".
-- Kepu 2026-11-26 07:36 "an egg floating in an incubator that says like and favorite for free egg roll ... a roll for anything at
--   all in the game ... a limited time offer timer ... we'll only really be able to check if they favorited"; picks "One ever",
--   "By rarity", "Reroll to new", "Per player, 48 h", "Owned + parts maxed"; red-team "Lower paid odds", "When they first see it",
--   "Leave them out".
-- Store: DataStore FavEggStoreName ("MDA_FavEgg_v1"), key "u<UserId>", value {v = 1, first = server time (the first "seen"),
--   roll = {kind, id, tier, at} | nil, granted = bool}. Read at join (3 tries). Never written before a good read. Studio:
--   FavEggTestMemoryStore = true uses an in-memory store.
-- Player attributes: FavEggState ("loading" / "unseen" / "open" / "rolled" / "expired" / "failed" / "off"), FavEggEndsAt (server
--   time, while open / expired), FavEggPrize ("kind:id" once rolled), FavEggLastResult.
-- RemoteFunction ReplicatedStorage.FavEggRequest (made here):
--   ("seen") -> result. Hub only (ReplicatedStorage ServerKind "hub"), loaded, state "unseen", the HumanoidRootPart within
--     FavEggSeenRange (60) studs (flat) of Workspace.FavEggStand's FavEggFront: one UpdateAsync sets first (kept if already set)
--     -> "ok" (state "open"). Else "notHub" / "notLoaded" / "far" / "already".
--   ("favorited") -> result, prize, reel. The client sends it after Roblox's favorite window answered Success
--     (AvatarEditorService.PromptSetFavoriteCompleted; the server cannot check a favorite: red-team R1, accepted). Hub only,
--     loaded, within FavEggRange (24) + 6 studs of FavEggFront, state "open", the other stores loaded (SkinOwnedU set,
--     EmoteSaveState / TrailSaveState loaded or saved, TutState not "wait"); one request at a time. EggRules.pick over the items
--     the player does not own (SkinOwnedU, EmoteOwned, TrailOwned, OwnedDinos) with the odds FavEggOddsCommon / Rare / Epic /
--     Legend / Dino (60 / 30 / 5 / 2 / 3, read per roll). One UpdateAsync writes roll (refused when a roll is stored or the window
--     is over) -> "ok", prize {kind, id, name, tier}, reel (FavEggReelLen (40) items, the prize at FavEggReelAt (34)). The grant
--     runs FavEggGrantDelay (5) s later (after the client's reel), then granted = true is written. Else "notHub" / "notLoaded" /
--     "notNear" / "notOpen" (unseen) / "expired" / "rolled" (with the stored prize) / "busy" / "failed".
-- Grants (each owner's own hook): skin -> SkinServer.SkinGrant(player, id, "egg"); emote -> EmoteServer.EmoteGrant; trail ->
--   TrailServer.TrailGrant; dino -> DinoOwnership.OwnGrant(player, key, true) (owned + every mecha part, SkillServer 1.16);
--   points (owns everything) -> SkillServer.SkillGrantPoints(player, EggRules.ALL_OWNED_POINTS, "egg"). "ok" or "owned" counts as
--   granted. A stored roll that is not granted is retried at join and every FavEggRetry (15) s while the player is here.
-- Switches / numbers (script attributes): FavEggEnabled (true, read at start), FavEggStoreName, FavEggWindowH (48, read per use),
--   FavEggSeenRange (60), FavEggRange (24), FavEggGrantDelay (5), FavEggRetry (15), FavEggReelLen (40), FavEggReelAt (34), the odds,
--   FavEggTestMemoryStore (false). Diagnostics: FavEggServerVersion, FavEggRolls, FavEggGrants, FavEggStoreKind.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("FavEggServerVersion", VERSION)
for k, v in pairs({FavEggEnabled = true, FavEggStoreName = "MDA_FavEgg_v1", FavEggWindowH = 48, FavEggSeenRange = 60,
	FavEggRange = 24, FavEggGrantDelay = 5, FavEggRetry = 15, FavEggReelLen = 40, FavEggReelAt = 34, FavEggOddsCommon = 60,
	FavEggOddsRare = 30, FavEggOddsEpic = 5, FavEggOddsLegend = 2, FavEggOddsDino = 3, FavEggTestMemoryStore = false}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function A(k, d) return tonumber(script:GetAttribute(k)) or d end
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end
if script:GetAttribute("FavEggEnabled") == false then return end

local arcade = ServerStorage:WaitForChild("DinoArcade")
local R = require(arcade:WaitForChild("EggRules"))
local US = require(arcade:WaitForChild("UniversalSkins"))
local EC = require(arcade:WaitForChild("EmoteCatalog"))
local TC = require(arcade:WaitForChild("TrailCatalog"))
local POOL = R.pool(US, EC, TC)

local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(tostring(script:GetAttribute("FavEggStoreName"))) end)
	store = ok and s or nil
end
if RunService:IsStudio() and script:GetAttribute("FavEggTestMemoryStore") == true then
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
			return copy(new ~= nil and new or mem[key])
		end,
	}
	script:SetAttribute("FavEggStoreKind", "memory")
else
	script:SetAttribute("FavEggStoreKind", store and "datastore" or "none")
end

local function now() return workspace:GetServerTimeNow() end
local function isHub() return ReplicatedStorage:GetAttribute("ServerKind") == "hub" end
local function clean(old)
	local v = type(old) == "table" and old or {}
	v.v = 1
	if type(v.roll) ~= "table" then v.roll = nil end
	v.granted = v.granted == true
	return v
end

local states = {} -- [player] = {loaded, rec, busy}
local function publish(player)
	local st = states[player]
	if not st then return end
	if not st.loaded then player:SetAttribute("FavEggState", st.failed and "failed" or "loading") return end
	local hours = A("FavEggWindowH", 48)
	local s = R.state(st.rec, now(), hours)
	player:SetAttribute("FavEggState", s)
	player:SetAttribute("FavEggEndsAt", tonumber(st.rec.first) and R.endsAt(st.rec.first, hours) or nil)
	player:SetAttribute("FavEggPrize", st.rec.roll and (st.rec.roll.kind .. ":" .. tostring(st.rec.roll.id)) or nil)
end
local function result(player, r) player:SetAttribute("FavEggLastResult", r) return r end

local function front()
	local stand = workspace:FindFirstChild("FavEggStand")
	local f = stand and stand:GetAttribute("FavEggFront")
	return typeof(f) == "Vector3" and f or nil
end
local function flatDist(player, p)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (hrp and p) then return math.huge end
	return Vector3.new(hrp.Position.X - p.X, 0, hrp.Position.Z - p.Z).Magnitude
end

-- grants
local function hookFn(scriptName, fnName)
	local s = ServerScriptService:FindFirstChild(scriptName)
	return s and s:FindFirstChild(fnName)
end
local function grantNow(player, roll)
	local fn, args
	if roll.kind == "skin" then fn, args = hookFn("SkinServer", "SkinGrant"), {roll.id, "egg"}
	elseif roll.kind == "emote" then fn, args = hookFn("EmoteServer", "EmoteGrant"), {roll.id, "egg"}
	elseif roll.kind == "trail" then fn, args = hookFn("TrailServer", "TrailGrant"), {roll.id, "egg"}
	elseif roll.kind == "dino" then fn, args = hookFn("DinoOwnership", "OwnGrant"), {roll.id, true}
	elseif roll.kind == "points" then fn, args = hookFn("SkillServer", "SkillGrantPoints"), {R.ALL_OWNED_POINTS, "egg"}
	end
	if not fn then return false, "noHook" end
	local ok, r = pcall(function() return fn:Invoke(player, table.unpack(args)) end)
	r = ok and r or "error"
	return r == "ok" or r == "owned" or r == "allOwned", tostring(r)
end
local function markGranted(player)
	local st = states[player]
	if not (st and store) then return end
	local ok = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local v = clean(old)
			if not v.roll then return nil end
			v.granted = true
			return v
		end)
	end)
	if ok then st.rec.granted = true end
end
local function tryGrant(player)
	local st = states[player]
	if not (st and st.loaded and st.rec.roll and not st.rec.granted) or st.granting then return end
	st.granting = true
	local okG, why = grantNow(player, st.rec.roll)
	if okG then
		bump("FavEggGrants")
		markGranted(player)
		result(player, "granted " .. st.rec.roll.kind)
	else
		result(player, "grantWait " .. why)
	end
	st.granting = false
end

-- load
local function load(player)
	local st = states[player]
	if not store then st.failed = true publish(player) return end
	for i = 1, 3 do
		local ok, v = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if not player.Parent then return end
		if ok then
			st.rec = clean(v)
			st.loaded = true
			publish(player)
			task.delay(3, tryGrant, player)
			return
		end
		task.wait(i * 2)
	end
	st.failed = true
	publish(player)
end

local function othersLoaded(player)
	local function ok(s) return s == "loaded" or s == "saved" end
	return player:GetAttribute("SkinOwnedU") ~= nil and ok(player:GetAttribute("EmoteSaveState"))
		and ok(player:GetAttribute("TrailSaveState")) and player:GetAttribute("TutState") ~= "wait"
		and player:GetAttribute("TutState") ~= nil
end

local function reelFor(prize)
	local all = {}
	for _, t in ipairs(R.TIERS) do for _, it in ipairs(POOL[t]) do table.insert(all, it) end end
	local reel, rng = {}, Random.new()
	local n, at = math.floor(A("FavEggReelLen", 40)), math.floor(A("FavEggReelAt", 34))
	for i = 1, n do
		if i == at then table.insert(reel, prize)
		elseif #all > 0 then
			local it = all[rng:NextInteger(1, #all)]
			table.insert(reel, {kind = it.kind, id = it.id, name = it.name, tier = it.tier})
		end
	end
	return reel
end
local function prizeOf(roll)
	if roll.kind == "points" then return {kind = "points", id = tostring(R.ALL_OWNED_POINTS), name = R.ALL_OWNED_POINTS .. " SKILL POINTS", tier = "common"} end
	for _, it in ipairs(POOL[roll.tier] or {}) do
		if it.kind == roll.kind and it.id == roll.id then return {kind = it.kind, id = it.id, name = it.name, tier = it.tier} end
	end
	return {kind = roll.kind, id = roll.id, name = tostring(roll.id), tier = roll.tier}
end

local function favorited(player)
	local st = states[player]
	if not isHub() then return result(player, "notHub") end
	if not (st and st.loaded and store) then return result(player, "notLoaded") end
	if st.busy then return result(player, "busy") end
	local f = front()
	if flatDist(player, f) > A("FavEggRange", 24) + 6 then return result(player, "notNear") end
	local s = R.state(st.rec, now(), A("FavEggWindowH", 48))
	if s == "rolled" then return result(player, "rolled"), prizeOf(st.rec.roll) end
	if s == "unseen" then return result(player, "notOpen") end
	if s == "expired" then return result(player, "expired") end
	if not othersLoaded(player) then return result(player, "notLoaded") end
	st.busy = true
	local owned = {skin = R.setOf(player:GetAttribute("SkinOwnedU")), emote = R.setOf(player:GetAttribute("EmoteOwned")),
		trail = R.setOf(player:GetAttribute("TrailOwned")), dino = R.setOf(player:GetAttribute("OwnedDinos"))}
	local odds = {common = A("FavEggOddsCommon", 60), rare = A("FavEggOddsRare", 30), epic = A("FavEggOddsEpic", 5),
		legend = A("FavEggOddsLegend", 2), dino = A("FavEggOddsDino", 3)}
	local rng = Random.new()
	local pick = R.pick(POOL, owned, function() return rng:NextNumber() end, odds)
	local roll = {kind = pick.kind, id = pick.id or tostring(R.ALL_OWNED_POINTS), tier = pick.tier or "common", at = now()}
	local outcome, stored = "failed", nil
	local hours = A("FavEggWindowH", 48)
	local ok = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local v = clean(old)
			stored = v
			if v.roll then outcome = "rolled" return nil end
			if not tonumber(v.first) then outcome = "notOpen" return nil end
			if now() >= R.endsAt(v.first, hours) then outcome = "expired" return nil end
			v.roll = roll
			v.granted = false
			outcome = "ok"
			return v
		end)
	end)
	if not ok then outcome = "failed" end
	if stored and outcome ~= "failed" then st.rec = stored end
	publish(player)
	st.busy = false
	if outcome == "rolled" and st.rec.roll then return result(player, "rolled"), prizeOf(st.rec.roll) end
	if outcome ~= "ok" then return result(player, outcome) end
	bump("FavEggRolls")
	local prize = prizeOf(roll)
	task.delay(A("FavEggGrantDelay", 5), tryGrant, player)
	return result(player, "ok"), prize, reelFor(prize)
end

local function seen(player)
	local st = states[player]
	if not isHub() then return result(player, "notHub") end
	if not (st and st.loaded and store) then return result(player, "notLoaded") end
	if tonumber(st.rec.first) or st.rec.roll then return result(player, "already") end
	if flatDist(player, front()) > A("FavEggSeenRange", 60) then return result(player, "far") end
	if st.busy then return result(player, "busy") end
	st.busy = true
	local stored
	local t = now()
	local ok = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local v = clean(old)
			stored = v
			if tonumber(v.first) then return nil end
			v.first = t
			return v
		end)
	end)
	st.busy = false
	if not ok then return result(player, "failed") end
	if stored then
		if not tonumber(stored.first) then stored.first = t end
		st.rec = stored
	end
	publish(player)
	return result(player, "ok")
end

local remote = ReplicatedStorage:FindFirstChild("FavEggRequest")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "FavEggRequest"
	remote.Parent = ReplicatedStorage
end
remote.OnServerInvoke = function(player, action)
	if action == "seen" then return seen(player) end
	if action == "favorited" then return favorited(player) end
	return result(player, "badArg")
end

local function onPlayer(player)
	states[player] = {loaded = false, rec = clean(nil), busy = false}
	publish(player)
	task.spawn(load, player)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p) states[p] = nil end)

-- the window closing while here, and grant retries
task.spawn(function()
	while true do
		task.wait(A("FavEggRetry", 15))
		for p, st in pairs(states) do
			if p.Parent and st.loaded then
				publish(p)
				if st.rec.roll and not st.rec.granted then task.spawn(tryGrant, p) end
			end
		end
	end
end)
