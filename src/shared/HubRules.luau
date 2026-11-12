-- HubRules v1.0 (Mecha Dino Arena) — the island hub's rules: what a server is, the safe area, who goes on a portal trip.
-- MDA-452, plan docs/plans/ISLAND_HUB_v1.0.md Task 1, ADR-011, mockup docs/mockups/island_portals_v0.1.html (Kepu 2026-11-11:
-- portals like Fortnite creative, the squad goes with the leader; picks "C · Portal Islet", 3 s guard both ways, no hub bots,
-- private bots match). Pure: no instances, no services. Lives in ServerStorage.DinoArcade.HubRules; HubServer 1.0 clones it
-- to ReplicatedStorage.HubShared for clients.
-- Numbers: TRIP_TIME 5 s countdown; GUARD 3 s protected after leaving the safe area; SAVE_WAIT 12 s at most for a skill save
--   before a trip; POLL 0.2 s zone / portal check; KEY_KEEP 60 s a trip key stays open on the arriving server.
-- API:
--   kind(info) -> "hub" | "practice" | "arena"; info = {placeMode, hubOn, isStudio, testPractice, privateId, ownerId}.
--     First row wins: placeMode == "arena" -> "arena"; hubOn ~= true -> "practice" (today's Sandbox); isStudio ->
--     testPractice == true and "practice" or "hub"; privateId a non-empty string and ownerId == 0 (a reserved server) ->
--     "practice"; otherwise "hub" (a public server or a VIP server).
--   inShape(pos, cf, size, shape) -> bool. shape "box": inside the box cf / size (edges count). shape "cyl": a Roblox
--     cylinder part (axis = the part's X): |local x| <= size.X / 2 and the distance from the axis <= min(size.Y, size.Z) / 2.
--   inZone(pos, shapes) -> bool: inside any {cf, size, shape}.
--   protected(inZone, guardUntil, now) -> bool: inZone == true, or now < guardUntil.
--   tripParty(starter, info) -> {UserId} | nil, reason. info = {squadId, leaderId, members = {UserId}}: no squad (squadId nil /
--     "", or no members) -> {starter}; starter == leaderId -> members (starter first); else nil, "notLeader".
--   nextLeader(members) -> UserId | nil; members = {{id, joinedAt}}: earliest joinedAt, ties -> the smallest id.
--   tripData(mode, key, leader, members, from) -> the teleport data {mdaPlay = true, mdaFrom = from, mdaTrip = {mode, key,
--     leader, members}}.
local M = {}
M.VERSION = "1.0"
M.TRIP_TIME = 5
M.GUARD = 3
M.SAVE_WAIT = 12
M.POLL = 0.2
M.KEY_KEEP = 60
M.MODES = {arena = true, bots = true, island = true}

function M.kind(info)
	if type(info) ~= "table" then return "practice" end
	if info.placeMode == "arena" then return "arena" end
	if info.hubOn ~= true then return "practice" end
	if info.isStudio == true then
		return info.testPractice == true and "practice" or "hub"
	end
	if type(info.privateId) == "string" and info.privateId ~= "" and info.ownerId == 0 then return "practice" end
	return "hub"
end

function M.inShape(pos, cf, size, shape)
	if typeof(pos) ~= "Vector3" or typeof(cf) ~= "CFrame" or typeof(size) ~= "Vector3" then return false end
	local p = cf:PointToObjectSpace(pos)
	if shape == "cyl" then
		if math.abs(p.X) > size.X / 2 then return false end
		local r = math.min(size.Y, size.Z) / 2
		return p.Y * p.Y + p.Z * p.Z <= r * r
	end
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

function M.inZone(pos, shapes)
	if type(shapes) ~= "table" then return false end
	for _, s in ipairs(shapes) do
		if type(s) == "table" and M.inShape(pos, s.cf, s.size, s.shape) then return true end
	end
	return false
end

function M.protected(inZone, guardUntil, now)
	if inZone == true then return true end
	return type(guardUntil) == "number" and type(now) == "number" and now < guardUntil
end

function M.tripParty(starter, info)
	info = type(info) == "table" and info or {}
	local members = type(info.members) == "table" and info.members or {}
	if type(info.squadId) ~= "string" or info.squadId == "" or #members == 0 then return {starter} end
	if starter ~= info.leaderId then return nil, "notLeader" end
	local out = {starter}
	for _, id in ipairs(members) do
		if id ~= starter then table.insert(out, id) end
	end
	return out
end

function M.nextLeader(members)
	local best
	for _, m in ipairs(type(members) == "table" and members or {}) do
		if type(m) == "table" and type(m.id) == "number" then
			local t = tonumber(m.joinedAt) or math.huge
			if not best or t < best.t or (t == best.t and m.id < best.id) then best = {id = m.id, t = t} end
		end
	end
	return best and best.id or nil
end

function M.tripData(mode, key, leader, members, from)
	return {mdaPlay = true, mdaFrom = from, mdaTrip = {mode = mode, key = key, leader = leader, members = members}}
end

return M
