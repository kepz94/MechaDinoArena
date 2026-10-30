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
local M = {}

M.Version = "1.0"
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
	else
		return false
	end
end

function M.currentMode()
	local isStudio = game:GetService("RunService"):IsStudio()
	return M.placeMode(game.PlaceId, isStudio, workspace:GetAttribute("ModeTestArena"))
end

return M
