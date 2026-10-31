-- SquadServer v1.0 (Mecha Dino Arena) — Arena squads: invites, joins, leaves (server owns every SquadId). MDA-158, plan
-- docs/plans/SQUADS_v1.0.md Task S1, ADR-006, mockup docs/mockups/arena_squads_options.html (picked A). Kepu 2026-10-31: "for
-- arena allow for a teams mode where you can squad up with other players turning friendly fire off. Just have a button under
-- skills that allows me to send an invite to someone to squad up. Also lets me unsquad with that person"; up to 4; "Leave
-- the squad".
-- Arena only: ModeRules.currentMode() == "arena" (Studio: Workspace ModeTestArena) and script attribute SquadServerEnabled
--   (default true, read at start). Then ReplicatedStorage attribute SquadsLive = true (SquadRules 1.0 answers "not squadmates"
--   for everything while it is not true). Otherwise SquadsLive = false and every request answers "notArena".
-- Client copy: ServerStorage.DinoArcade.SquadRules is cloned into ReplicatedStorage.SquadShared (folder) at start.
-- Client -> server: ReplicatedStorage.DinoSquadRequest:FireServer(action, targetUserId). First failing check wins; the result
--   goes to the sender's player attributes SquadResult (then SquadResultAt, last):
--   any action: "notArena", "busy" (less than BUSY (0.15) s since this player's last request), "badArg" (unknown action);
--   "invite":  "badArg" (targetUserId not a number), "menu" (sender InMenu), "self", "noTarget" (no such player here),
--              "targetMenu" (target InMenu), "same" (already squadmates), "full" (sender's squad has MAX (4)), "inSquad"
--              (target is in another squad), "cooldown" (same target less than INVITE_GUARD (5) s ago), "ok": the target's
--              SquadInviteFrom (UserId), SquadInviteFromName, SquadInviteUntil (now + INVITE_TIME (15)) are set (a newer
--              invite replaces an older one); the sender's SquadInvitedAt_<targetUserId> = now.
--   "accept":  "menu", "noInvite" (none, or SquadInviteUntil passed), "gone" (inviter left or is in the menu), "same", "full"
--              (inviter's squad has MAX), "ok": the accepter leaves its old squad (reason "switch"); an inviter with no squad
--              gets a new SquadId (inviter UserId .. "_" .. counter); the accepter gets the inviter's SquadId; invite cleared.
--   "decline": "ok", invite cleared.
--   "leave":   "noSquad" or "ok" (reason "leave").
-- Leaving (any reason): SquadId = "", SquadLeftReason = reason ("leave" / "switch" / "menu" / "quit" via the others' rows); a
--   squad left with one member is dissolved: that member's SquadId = "", SquadLeftReason "dissolved". Automatic: player
--   InMenu turning true (reason "menu", the pending invite is cleared too); PlayerRemoving (reason "quit"). A death keeps the
--   squad.
-- Test hook (server only; clients can't reach it): BindableFunction "SquadTest" under this script.
--   Invoke("join", player, model) -> squadId: the player gets a SquadId (a new one if it has none) and the model (ArenaPvP's
--     test target) gets SquadTestId = that id, so SquadRules.sameChar treats it as the player's squadmate.
--   Invoke("clear", player, model) -> "ok": the model's SquadTestId is removed; a player alone in its squad gets SquadId "".
--   Works only while SquadsLive; otherwise returns "notArena".
-- Diagnostics: script SquadServerVersion, SquadServerMode, SquadRequests, SquadSquads (live squads with 2+ members, or with a
--   test member); player SquadId, SquadResult / SquadResultAt, SquadLeftReason, SquadInvite*.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
local INVITE_TIME, INVITE_GUARD, BUSY = 15, 5, 0.15

script:SetAttribute("SquadServerVersion", VERSION)
if script:GetAttribute("SquadServerEnabled") == nil then script:SetAttribute("SquadServerEnabled", true) end
script:SetAttribute("SquadRequests", 0)
script:SetAttribute("SquadSquads", 0)

local arcade = ServerStorage:WaitForChild("DinoArcade")
local ModeRules = require(arcade:WaitForChild("ModeRules"))
local rulesModule = arcade:WaitForChild("SquadRules")
local SquadRules = require(rulesModule)
local MODE = ModeRules.currentMode()
script:SetAttribute("SquadServerMode", MODE)
local LIVE = MODE == "arena" and script:GetAttribute("SquadServerEnabled") ~= false
ReplicatedStorage:SetAttribute("SquadsLive", LIVE)

-- client copy
local shared = ReplicatedStorage:FindFirstChild("SquadShared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "SquadShared"
	shared.Parent = ReplicatedStorage
end
local oldCopy = shared:FindFirstChild("SquadRules")
if oldCopy then oldCopy:Destroy() end
rulesModule:Clone().Parent = shared

local remote = ReplicatedStorage:FindFirstChild("DinoSquadRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoSquadRequest"
	remote.Parent = ReplicatedStorage
end

local function now() return workspace:GetServerTimeNow() end
local counter = 0
local lastReq = setmetatable({}, {__mode = "k"})

local function idOf(p) return SquadRules.idOfPlayer(p) end
local function size(id)
	if id == "" then return 1 end
	return #SquadRules.members(id)
end
local function recount()
	local seen, n = {}, 0
	for _, p in ipairs(Players:GetPlayers()) do
		local id = idOf(p)
		if id ~= "" and not seen[id] then seen[id] = true n += 1 end
	end
	script:SetAttribute("SquadSquads", n)
end
local function result(p, r)
	p:SetAttribute("SquadResult", r)
	p:SetAttribute("SquadResultAt", now()) -- last
end
local function clearInvite(p)
	p:SetAttribute("SquadInviteFrom", nil)
	p:SetAttribute("SquadInviteFromName", nil)
	p:SetAttribute("SquadInviteUntil", nil)
end
local function testMembers(id)
	local n = 0
	for _, d in ipairs(workspace:GetChildren()) do
		if d:IsA("Model") and d:GetAttribute("SquadTestId") == id then n += 1 end
	end
	return n
end
local function leave(p, reason)
	local old = idOf(p)
	if old == "" then return false end
	p:SetAttribute("SquadId", "")
	p:SetAttribute("SquadLeftReason", reason)
	local rest = SquadRules.members(old)
	if #rest == 1 and testMembers(old) == 0 then
		rest[1]:SetAttribute("SquadId", "")
		rest[1]:SetAttribute("SquadLeftReason", "dissolved")
	end
	recount()
	return true
end
local function newId(founder)
	counter += 1
	local id = tostring(founder.UserId) .. "_" .. counter
	founder:SetAttribute("SquadId", id)
	founder:SetAttribute("SquadLeftReason", nil)
	return id
end

local function invite(p, uid)
	if type(uid) ~= "number" then return "badArg" end
	if p:GetAttribute("InMenu") == true then return "menu" end
	if uid == p.UserId then return "self" end
	local t = Players:GetPlayerByUserId(uid)
	if not t then return "noTarget" end
	if t:GetAttribute("InMenu") == true then return "targetMenu" end
	local mine, theirs = idOf(p), idOf(t)
	if mine ~= "" and mine == theirs then return "same" end
	if size(mine) >= SquadRules.MAX then return "full" end
	if theirs ~= "" then return "inSquad" end
	local key = "SquadInvitedAt_" .. uid
	local last = tonumber(p:GetAttribute(key))
	local tt = now()
	if last and tt - last < INVITE_GUARD then return "cooldown" end
	p:SetAttribute(key, tt)
	t:SetAttribute("SquadInviteFrom", p.UserId)
	t:SetAttribute("SquadInviteFromName", p.Name)
	t:SetAttribute("SquadInviteUntil", tt + INVITE_TIME)
	return "ok"
end

local function accept(p)
	if p:GetAttribute("InMenu") == true then return "menu" end
	local from, untilT = tonumber(p:GetAttribute("SquadInviteFrom")), tonumber(p:GetAttribute("SquadInviteUntil"))
	if not from or not untilT or untilT <= now() then
		clearInvite(p)
		return "noInvite"
	end
	local inv = Players:GetPlayerByUserId(from)
	if not inv or inv:GetAttribute("InMenu") == true then
		clearInvite(p)
		return "gone"
	end
	local theirs = idOf(inv)
	if theirs ~= "" and theirs == idOf(p) then
		clearInvite(p)
		return "same"
	end
	if size(theirs) >= SquadRules.MAX then
		clearInvite(p)
		return "full"
	end
	leave(p, "switch")
	if theirs == "" then theirs = newId(inv) end
	p:SetAttribute("SquadId", theirs)
	p:SetAttribute("SquadLeftReason", nil)
	clearInvite(p)
	recount()
	return "ok"
end

remote.OnServerEvent:Connect(function(p, action, uid)
	script:SetAttribute("SquadRequests", (script:GetAttribute("SquadRequests") or 0) + 1)
	if not LIVE then result(p, "notArena") return end
	local t = os.clock()
	if lastReq[p] and t - lastReq[p] < BUSY then result(p, "busy") return end
	lastReq[p] = t
	local r
	if action == "invite" then r = invite(p, uid)
	elseif action == "accept" then r = accept(p)
	elseif action == "decline" then clearInvite(p) r = "ok"
	elseif action == "leave" then r = leave(p, "leave") and "ok" or "noSquad"
	else r = "badArg" end
	result(p, r)
end)

local function onPlayer(p)
	if p:GetAttribute("SquadId") == nil then p:SetAttribute("SquadId", "") end
	p:GetAttributeChangedSignal("InMenu"):Connect(function()
		if p:GetAttribute("InMenu") == true then
			clearInvite(p)
			leave(p, "menu")
		end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p)
	leave(p, "quit")
	task.defer(recount)
end)

-- test hook (server only)
local hook = script:FindFirstChild("SquadTest")
if not hook then
	hook = Instance.new("BindableFunction")
	hook.Name = "SquadTest"
	hook.Parent = script
end
hook.OnInvoke = function(action, player, model)
	if not LIVE then return "notArena" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(model) ~= "Instance" then return "badArg" end
	if action == "join" then
		local id = idOf(player)
		if id == "" then id = newId(player) end
		model:SetAttribute("SquadTestId", id)
		recount()
		return id
	elseif action == "clear" then
		local id = model:GetAttribute("SquadTestId")
		model:SetAttribute("SquadTestId", nil)
		if type(id) == "string" and id ~= "" and #SquadRules.members(id) == 1 and testMembers(id) == 0 then
			player:SetAttribute("SquadId", "")
			player:SetAttribute("SquadLeftReason", "dissolved")
		end
		recount()
		return "ok"
	end
	return "badArg"
end
