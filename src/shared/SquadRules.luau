-- SquadRules v1.0 (Mecha Dino Arena) — who is on whose squad (pure reads; no writes). MDA-158, plan
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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = {}
M.Version = "1.0"
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

function M.same(plA, plB)
	if typeof(plA) ~= "Instance" or typeof(plB) ~= "Instance" then return false end
	return M.sameIds(M.live(), M.idOfPlayer(plA), M.idOfPlayer(plB), plA == plB)
end

function M.sameChar(a, b)
	if typeof(a) ~= "Instance" or typeof(b) ~= "Instance" then return false end
	return M.sameIds(M.live(), M.idOf(a), M.idOf(b), a == b)
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
