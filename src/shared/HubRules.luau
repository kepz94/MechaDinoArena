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
-- v1.1 (Kepu 2026-11-11 18:48: "When you step in a portal in Fortnite it goes straight to the loading. That's how this shit needs
--   to fucking work"): TRIP_TIME 0 — walking into a portal starts the trip at once (no countdown). The 1.0 value stays as
--   TRIP_TIME_V10 = 5.
-- v1.2 (Arena queue, MDA-489, plan docs/plans/PREGAME_LINEUP_v1.0.md T4 (Part 2), ADR-012, mockup docs/mockups/arena_queue_v0.1.html
--   pick "A · Top pill"; Kepu 2026-11-12: queue up to 30 s, start 4v4 with whoever is found, bots fill (D6); 2026-11-13 pick A: you
--   can walk around while queued):
--   QUEUE_SIZE 8 (humans in a full match), TEAM_SIZE 4, QUEUE_WAIT 30 (s the oldest group waits before a match starts with
--   fewer), FOUND_SHOW 1.5 (s "MATCH FOUND" shows before the trip). MODES gains arenaMatch (HubTravel 1.1: a reserved Sandbox
--   server, like bots).
--   packTeams(groups) -> {A = {UserId}, B = {UserId}} | nil. groups = {{ids = {UserId}, at}}; bigger groups first (ties: older
--     first), each into the team with fewer players that has room for the whole group (ties: A). A group that fits neither ->
--     nil (squads are never split).
--   queueTake(groups, now) -> taken {group} | nil. Oldest first (at; ties keep the given order), a group is added when the
--     total stays <= QUEUE_SIZE and packTeams of the taken set + it is not nil. Returns the taken set when it holds QUEUE_SIZE
--     humans, or when the oldest group (the first taken) has waited >= QUEUE_WAIT; else nil. No groups / bad input -> nil.
--   count(groups) -> humans queued.
local M = {}
M.VERSION = "1.1"
M.VERSION = "1.2" -- v1.2 Arena queue
M.TRIP_TIME = 0 -- v1.1: straight to the loading (1.0: 5)
M.TRIP_TIME_V10 = 5
M.GUARD = 3
M.SAVE_WAIT = 12
M.POLL = 0.2
M.KEY_KEEP = 60
M.MODES = {arena = true, bots = true, island = true}
M.MODES.arenaMatch = true -- v1.2
M.QUEUE_SIZE = 8 -- v1.2
M.TEAM_SIZE = 4 -- v1.2
M.QUEUE_WAIT = 30 -- v1.2
M.FOUND_SHOW = 1.5 -- v1.2

-- v1.2: the Arena queue
local function idsOf(g) return type(g) == "table" and type(g.ids) == "table" and g.ids or {} end
function M.count(groups)
	local n = 0
	for _, g in ipairs(type(groups) == "table" and groups or {}) do n += #idsOf(g) end
	return n
end
function M.packTeams(groups)
	if type(groups) ~= "table" then return nil end
	local order = {}
	for i, g in ipairs(groups) do table.insert(order, {g = g, i = i}) end
	table.sort(order, function(a, b)
		local na, nb = #idsOf(a.g), #idsOf(b.g)
		if na ~= nb then return na > nb end
		local ta, tb = tonumber(a.g.at) or 0, tonumber(b.g.at) or 0
		if ta ~= tb then return ta < tb end
		return a.i < b.i
	end)
	local teams = {A = {}, B = {}}
	for _, o in ipairs(order) do
		local ids = idsOf(o.g)
		local first, second = "A", "B"
		if #teams.B < #teams.A then first, second = "B", "A" end
		local into = nil
		if #teams[first] + #ids <= M.TEAM_SIZE then into = first elseif #teams[second] + #ids <= M.TEAM_SIZE then into = second end
		if not into then return nil end
		for _, id in ipairs(ids) do table.insert(teams[into], id) end
	end
	return teams
end
function M.queueTake(groups, now)
	if type(groups) ~= "table" or #groups == 0 or type(now) ~= "number" then return nil end
	local order = {}
	for i, g in ipairs(groups) do if #idsOf(g) > 0 then table.insert(order, {g = g, i = i}) end end
	table.sort(order, function(a, b)
		local ta, tb = tonumber(a.g.at) or 0, tonumber(b.g.at) or 0
		if ta ~= tb then return ta < tb end
		return a.i < b.i
	end)
	local taken, total = {}, 0
	for _, o in ipairs(order) do
		local n = #idsOf(o.g)
		if total + n <= M.QUEUE_SIZE then
			table.insert(taken, o.g)
			if M.packTeams(taken) then
				total += n
			else
				table.remove(taken)
			end
		end
	end
	if #taken == 0 then return nil end
	if total >= M.QUEUE_SIZE then return taken end
	if now - (tonumber(taken[1].at) or now) >= M.QUEUE_WAIT then return taken end
	return nil
end

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
