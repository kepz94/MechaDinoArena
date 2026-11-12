-- SquadRules v1.1 (Mecha Dino Arena) — who is on whose squad (pure reads; no writes). MDA-158, plan
-- docs/plans/SQUADS_v1.0.md Task S1, ADR-006, mockup docs/mockups/arena_squads_options.html (Kepu 2026-10-31: "for arena allow
-- for a teams mode where you can squad up with other players turning friendly fire off"; up to 4, everything harmful off).
-- Lives in ServerStorage.DinoArcade.SquadRules; SquadServer 1.0 clones it to ReplicatedStorage.SquadShared.SquadRules for
-- clients (the SkillShared pattern).
-- Data (written only by SquadServer): player attribute SquadId (string, "" or nil = no squad); a model's SquadTestId (string,
--   SquadServer's server-only test hook on ArenaPvP's test target); ReplicatedStorage attribute SquadsLive (true only in the
--   Arena with SquadServerEnabled). With SquadsLive not true every answer below is "not squadmates".
-- API:
--   MAX = 4
--   live() -> bool                       ReplicatedStorage.SquadsLive == true
--   idOfPlayer(player) -> string         player SquadId or ""
--   idOf(model) -> string                the model's player's SquadId, else the model's SquadTestId, else ""
--   same(plA, plB) -> bool               live, both Players, plA ~= plB, equal non-empty SquadId
--   sameChar(a, b) -> bool               live, a ~= b, idOf(a) ~= "" and idOf(a) == idOf(b)
--   members(id) -> {Player}              players with SquadId == id (id ~= ""), sorted by Name
-- Pure helpers for the Studio test (tools/squad_rules_test.luau): sameIds(liveFlag, idA, idB, isSelf) -> bool.
-- v1.1 (Arena Hardpoint teams, MDA-397, plan docs/plans/HARDPOINT_v1.0.md Task 2, ADR-009; Kepu 2026-11-10 "team wins" over
--   squads): while teamLive() — ReplicatedStorage HardpointLive == true (HardpointServer 1.0) and ReplicatedStorage
--   HardpointTeamRules ~= false (the switch) — same / sameChar answer by Hardpoint team instead of SquadId: equal non-empty
--   teams, never self. A player's team = player attribute HardpointTeam ("A" / "B"); a model's = its player's, else the
--   model's HardpointTestTeam (HardpointServer's server-only test hook on a dummy). SquadId is ignored then, so squadmates
--   split across teams can hurt each other. teamLive() false -> exactly 1.0.
--   teamLive() -> bool; teamOfPlayer(player) -> string; teamOf(model) -> string
-- v1.2 (practice match, MDA-405, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 1): a model with no player also answers its
--   HardpointBotTeam (PracticeServer's bots), read after HardpointTestTeam. Nothing else changes.
-- v1.3 (island hub, MDA-453, plan docs/plans/ISLAND_HUB_v1.0.md Task 2, ADR-011; Kepu 2026-11-11: no fighting on the portal
--   islet, 3 s guard after leaving it "both ways"):
--   * sameChar(a, b) first row, on the server only (RunService:IsServer()): ReplicatedStorage HubLive == true (HubServer 1.0,
--     hub servers only), a ~= b and either model has the attribute HubSafe == true (on the islet / bridge or in the 3 s
--     guard) -> true, so every damage path that skips squadmates also skips that pair (both ways). Clients: unchanged (team
--     tags and effects don't treat strangers on the islet as friends). Switch: ReplicatedStorage attribute HubSafeRules ~=
--     false (false = 1.2).
--   * leaderOf(id) -> the member Player with player attribute SquadLeader == true (SquadServer 1.1), else nil.
--     isLeader(player) -> SquadLeader == true and a squad.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService") -- v1.3

local M = {}
M.Version = "1.3"
M.MAX = 4

function M.sameIds(liveFlag, idA, idB, isSelf)
	if liveFlag ~= true or isSelf == true then return false end
	if type(idA) ~= "string" or type(idB) ~= "string" then return false end
	return idA ~= "" and idA == idB
end

function M.live()
	return ReplicatedStorage:GetAttribute("SquadsLive") == true
end

function M.idOfPlayer(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return "" end
	local id = player:GetAttribute("SquadId")
	return type(id) == "string" and id or ""
end

function M.idOf(model)
	if typeof(model) ~= "Instance" then return "" end
	local pl = Players:GetPlayerFromCharacter(model)
	if pl then return M.idOfPlayer(pl) end
	local t = model:GetAttribute("SquadTestId")
	return type(t) == "string" and t or ""
end

-- v1.1: Hardpoint teams
function M.teamLive()
	return ReplicatedStorage:GetAttribute("HardpointLive") == true and ReplicatedStorage:GetAttribute("HardpointTeamRules") ~= false
end

function M.teamOfPlayer(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return "" end
	local t = player:GetAttribute("HardpointTeam")
	return type(t) == "string" and t or ""
end

function M.teamOf(model)
	if typeof(model) ~= "Instance" then return "" end
	local pl = Players:GetPlayerFromCharacter(model)
	if pl then return M.teamOfPlayer(pl) end
	local t = model:GetAttribute("HardpointTestTeam")
	if type(t) ~= "string" or t == "" then t = model:GetAttribute("HardpointBotTeam") end -- v1.2
	return type(t) == "string" and t or ""
end

function M.same(plA, plB)
	if typeof(plA) ~= "Instance" or typeof(plB) ~= "Instance" then return false end
	if M.teamLive() then return M.sameIds(true, M.teamOfPlayer(plA), M.teamOfPlayer(plB), plA == plB) end -- v1.1
	return M.sameIds(M.live(), M.idOfPlayer(plA), M.idOfPlayer(plB), plA == plB)
end

function M.sameChar(a, b)
	if typeof(a) ~= "Instance" or typeof(b) ~= "Instance" then return false end
	if a ~= b and RunService:IsServer() and ReplicatedStorage:GetAttribute("HubLive") == true -- v1.3
		and ReplicatedStorage:GetAttribute("HubSafeRules") ~= false
		and (a:GetAttribute("HubSafe") == true or b:GetAttribute("HubSafe") == true) then
		return true
	end
	if M.teamLive() then return M.sameIds(true, M.teamOf(a), M.teamOf(b), a == b) end -- v1.1
	return M.sameIds(M.live(), M.idOf(a), M.idOf(b), a == b)
end

-- v1.3
function M.isLeader(player)
	return typeof(player) == "Instance" and player:IsA("Player") and M.idOfPlayer(player) ~= ""
		and player:GetAttribute("SquadLeader") == true
end

-- v1.3
function M.leaderOf(id)
	for _, p in ipairs(M.members(id)) do
		if p:GetAttribute("SquadLeader") == true then return p end
	end
	return nil
end

function M.members(id)
	local list = {}
	if type(id) ~= "string" or id == "" then return list end
	for _, p in ipairs(Players:GetPlayers()) do
		if M.idOfPlayer(p) == id then table.insert(list, p) end
	end
	table.sort(list, function(x, y) return x.Name < y.Name end)
	return list
end

return M
