-- ModeRules v1.0 (Mecha Dino Arena) — which mode a server runs and who may hurt / stun / throw whom. MDA-85, plan
-- docs/plans/MAIN_MENU_v1.0.md Task 1 (deterministic map), ADR-005 (Arena = a second place from the same file).
-- Kepu 2026-10-29: Sandbox = today's island with bots, no player damage; Arena = the same island, no bots, PvP on.
-- Places: SANDBOX_PLACE_ID 84022023159448 ("Mecha Dino Arena"), ARENA_PLACE_ID 75433819286625 ("Mecha Dino Arena - Arena").
-- placeMode(placeId, isStudio, testArena) -> "sandbox" | "arena" (pure):
--   isStudio == true and testArena == true -> "arena" (Studio test switch: Workspace attribute ModeTestArena)
--   placeId == ARENA_PLACE_ID                -> "arena"
--   otherwise                                -> "sandbox" (Sandbox place, unpublished 0, unknown ids, bad input)
-- canAffect(srcIsPlayer, tgtIsPlayer, tgtInMenu, mode) -> boolean (pure), first matching row wins:
--   tgtIsPlayer ~= true      -> true  (bots, prey, dummies: unchanged)
--   tgtInMenu == true        -> false (nobody touches a player in the menu)
--   srcIsPlayer ~= true      -> true  (bots and server test hooks may hit players)
--   mode == "arena"          -> true  (player vs player in Arena)
--   otherwise                -> false (player vs player in Sandbox or an unknown mode)
-- currentMode() -> placeMode(game.PlaceId, RunService:IsStudio(), workspace:GetAttribute("ModeTestArena")).
-- Used by PlaceGate 1.0, ModeServer 1.0, MineServer 1.4, ScreechServer 1.4, ArenaPvP 1.0 (server).
-- v1.1 (practice match, MDA-405, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 1; Kepu 2026-11-10: the Sandbox is a Hardpoint
--   practice match "for now"): canAffect gets one row before the last: mode == "sandbox" and practiceLive() -> true (players
--   hurt players there while the practice match runs; who is a teammate stays SquadRules' answer). practiceLive() ->
--   ReplicatedStorage attribute PracticeLive == true (PracticeServer 1.0 writes it). Not live -> exactly 1.0.
-- v1.2 (island hub, MDA-453, plan docs/plans/ISLAND_HUB_v1.0.md Task 2, ADR-011; Kepu 2026-11-11 "PvP on" off the safe islet):
--   serverKind() -> "hub" | "practice" | "arena" = ServerStorage.DinoArcade.HubRules 1.0 kind({placeMode = currentMode(),
--     hubOn = ServerScriptService.HubServer exists, is a Script, Enabled and its attribute HubEnabled ~= false, isStudio,
--     testPractice = Workspace attribute ModeTestPractice, privateId = game.PrivateServerId, ownerId =
--     game.PrivateServerOwnerId}). No HubRules -> "practice" (today's Sandbox) or "arena".
--   hubLive() -> ReplicatedStorage attribute HubLive == true (HubServer 1.0 sets it on hub servers only).
--   canAffect gets one row before the last: mode == "sandbox" and hubLive() -> true (players hurt players on the hub
--   island; the safe islet's protection is SquadRules 1.3's answer). Hub not live -> exactly 1.1.
-- v1.3 (Kepu 2026-11-11 19:02, live v701: "I just portaled to bot island but then it placed me on the portal area when I
--   arrived" — the private bots server came up as a hub; most likely the reserved-server id was not set yet when the scripts started):
--   on a live server (not Studio) whose 1.2 answer is "hub", serverKind() waits for the first player, then reads
--   game.PrivateServerId / PrivateServerOwnerId again and the first player's join data: TeleportData
--   mdaTrip.mode == "bots" (HubServer's portal trip) -> "practice"; otherwise the 1.2 rule on the fresh values. The answer is
--   kept for the server's life (live only; Studio is worked out on every call as in 1.2), so every script gets the same kind;
--   callers that ask at start wait with it (they all handle players already in the server). serverKindWhy() -> "arena" /
--   "hubOff" / "studio" / "reservedId" / "tripBots" / "public" / "vip" / "noHubRules". Switch: M.KIND_WAIT_FIRST_PLAYER
--   (true; false = 1.2: decided at once).
-- v1.4 (Arena queue, MDA-489, plan docs/plans/PREGAME_LINEUP_v1.0.md T4 (Part 2), ADR-012): an Arena match is a reserved copy
--   of the Sandbox place (HubTravel 1.1 "arenaMatch"), entered with TeleportData mdaTrip.mode == "arena". The v1.3 first-player
--   check treats that trip like "bots": kind "practice" (PracticeServer 1.10 runs the 4v4). serverKindWhy() "tripArena".
--   Switch: M.TRIP_ARENA_PRACTICE (true; false = 1.3).
local M = {}

M.Version = "1.3"
M.Version = "1.4" -- v1.4 arena trips are practice servers
M.TRIP_ARENA_PRACTICE = true -- v1.4
M.KIND_WAIT_FIRST_PLAYER = true -- v1.3
M.SANDBOX_PLACE_ID = 84022023159448
M.ARENA_PLACE_ID = 75433819286625

function M.placeMode(placeId, isStudio, testArena)
	if isStudio == true and testArena == true then
		return "arena"
	elseif type(placeId) == "number" and placeId == M.ARENA_PLACE_ID then
		return "arena"
	else
		return "sandbox"
	end
end

function M.canAffect(srcIsPlayer, tgtIsPlayer, tgtInMenu, mode)
	if tgtIsPlayer ~= true then
		return true
	elseif tgtInMenu == true then
		return false
	elseif srcIsPlayer ~= true then
		return true
	elseif mode == "arena" then
		return true
	elseif mode == "sandbox" and M.practiceLive() then -- v1.1
		return true
	elseif mode == "sandbox" and M.hubLive() then -- v1.2
		return true
	else
		return false
	end
end

-- v1.1
function M.practiceLive()
	return game:GetService("ReplicatedStorage"):GetAttribute("PracticeLive") == true
end

-- v1.2
function M.hubLive()
	return game:GetService("ReplicatedStorage"):GetAttribute("HubLive") == true
end

-- v1.2
function M.hubOn()
	local hs = game:GetService("ServerScriptService"):FindFirstChild("HubServer")
	return hs ~= nil and hs:IsA("Script") and hs.Enabled and hs:GetAttribute("HubEnabled") ~= false
end

-- v1.2, v1.3 (live: the answer is kept; a hub answer waits for the first player's trip)
local kindCache, kindWhy, kindBusy = nil, nil, false
function M.serverKindWhy() return kindWhy end
local function why(k, info, trip)
	if info.placeMode == "arena" then return "arena" end
	if info.hubOn ~= true then return "hubOff" end
	if info.isStudio then return "studio" end
	if trip == "arena" then return "tripArena" end -- v1.4
	if trip then return "tripBots" end
	if k == "practice" then return "reservedId" end
	if type(info.privateId) == "string" and info.privateId ~= "" then return "vip" end
	return "public"
end
function M.serverKind()
	if kindCache then return kindCache end
	local mode = M.currentMode()
	local okH, H = pcall(function() return require(script.Parent:WaitForChild("HubRules", 5)) end)
	if not okH or type(H) ~= "table" then
		kindWhy = "noHubRules"
		return mode == "arena" and "arena" or "practice"
	end
	local isStudio = game:GetService("RunService"):IsStudio()
	local function infoNow()
		return {placeMode = mode, hubOn = M.hubOn(), isStudio = isStudio,
			testPractice = workspace:GetAttribute("ModeTestPractice") == true, privateId = game.PrivateServerId,
			ownerId = game.PrivateServerOwnerId}
	end
	local info = infoNow()
	local k = H.kind(info)
	if isStudio then -- worked out on every call (Studio test attributes)
		kindWhy = why(k, info, false)
		return k
	end
	if k ~= "hub" or not M.KIND_WAIT_FIRST_PLAYER then
		kindCache, kindWhy = k, why(k, info, false)
		return k
	end
	-- v1.3: a hub answer: wait for the first player and check its trip (one waiter decides, the others wait for it)
	if kindBusy then
		while not kindCache do task.wait(0.05) end
		return kindCache
	end
	kindBusy = true
	local Players = game:GetService("Players")
	local first = Players:GetPlayers()[1]
	while not first do
		Players.PlayerAdded:Wait()
		first = Players:GetPlayers()[1]
	end
	local okJd, jd = pcall(function() return first:GetJoinData() end)
	local td = okJd and type(jd) == "table" and jd.TeleportData or nil
	local trip = type(td) == "table" and type(td.mdaTrip) == "table" and td.mdaTrip.mode == "bots"
	if not trip and M.TRIP_ARENA_PRACTICE and type(td) == "table" and type(td.mdaTrip) == "table" and td.mdaTrip.mode == "arena" then
		trip = "arena" -- v1.4
	end
	info = infoNow()
	k = trip and "practice" or H.kind(info)
	kindCache, kindWhy = k, why(k, info, trip)
	return k
end

function M.currentMode()
	local isStudio = game:GetService("RunService"):IsStudio()
	return M.placeMode(game.PlaceId, isStudio, workspace:GetAttribute("ModeTestArena"))
end

return M
