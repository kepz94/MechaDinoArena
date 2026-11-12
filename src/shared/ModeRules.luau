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
local M = {}

M.Version = "1.2"
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

-- v1.2
function M.serverKind()
	local mode = M.currentMode()
	local okH, H = pcall(function() return require(script.Parent:WaitForChild("HubRules", 5)) end)
	if not okH or type(H) ~= "table" then return mode == "arena" and "arena" or "practice" end
	return H.kind({placeMode = mode, hubOn = M.hubOn(), isStudio = game:GetService("RunService"):IsStudio(),
		testPractice = workspace:GetAttribute("ModeTestPractice") == true, privateId = game.PrivateServerId,
		ownerId = game.PrivateServerOwnerId})
end

function M.currentMode()
	local isStudio = game:GetService("RunService"):IsStudio()
	return M.placeMode(game.PlaceId, isStudio, workspace:GetAttribute("ModeTestArena"))
end

return M
