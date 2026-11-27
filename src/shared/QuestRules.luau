-- QuestRules v1.0 (Mecha Dino Arena) — the Quest Stand's quest data and maths (ModuleScript, ServerStorage.DinoArcade). Plan
-- docs/plans/QUEST_STAND_v1.0.md Task 1, mockup docs/mockups/quest_stand_v0.1.html "A · Board"; Kepu 2026-11-26 "3 daily quests ...
-- as well as special quests. this is the only place where you can claim them", "the daily quest rewards will be skill points";
-- picks "1 / 2 / 3 by difficulty", "Per player", "Use as written", "Always claimable", "Lost at reset", "Dailies + streak skins
-- first" (the weekly rotating special is the next release).
-- Days are UTC days of the server clock: day(t) = floor(t / 86400); secsToDay(t) = seconds to the next 00:00 UTC.
-- Dailies: pickDailies(day, userId, owned) -> 3 quests, one of each difficulty (hard, then medium, then easy are picked; never the same
--   kind twice), from POOL by a Random seeded with hash(day, userId), so the same player gets the same 3 all day on every server.
--   A dino kind is only possible when owned (a list of species keys) is not empty; its dino is one of owned.
--   Quest = {id = "d<day>_<diff>_<kind>", kind, diff (1-3), ev, need, pts (PTS[diff]), text, dino (species key or nil), mode}.
--   mode "add" (counts add up) or "max" (the best value reached counts: island streak).
-- Events (ev): "ikill" island kill, "akill" kill on an Arena / practice server, "dkill" kill as the quest's dino (any server),
--   "aplay" an Arena match played (W or L), "awin" an Arena match won, "part" a mecha part used, "istreak" the island streak value.
-- Specials: specials() -> the permanent stand specials: s_zebra (best island streak 10 -> skin "zebra") and s_storm (25 -> "storm"),
--   {id, ev = "ibest", need, skin, name, text}. Progress = the player's best island streak (SkinStats 1.1 StatIslandBest).
-- claimable(need, have, claimed) -> have >= need and not claimed.
local M = {}
M.Version = "1.0"
M.Version = "1.1" -- v1.1 kills / streaks anywhere texts, Storm Front 15
-- v1.1 (Kepu 2026-11-27 16:17 "Okay do 1"; QuestServer 1.3 / SkinStats 1.3 count kills and streaks on every server): with
--   M.ANYWHERE_TEXTS (true) the ikills / istreak dailies and the specials lose "on the island" ("Get 5 kills anywhere", "Reach a 5 kill
--   streak"); with M.STORM_NEED (15; nil = 1.0's 25) s_storm needs that best streak. Ids, events and the other numbers unchanged.
M.DAY = 86400
M.PTS = {1, 2, 3}
M.DIFF_NAMES = {"EASY", "MEDIUM", "HARD"}
M.DINO_NAMES = {Raptor = "Raptor", TRex = "T-Rex", Pachy = "Pachy", Herrera = "Herrera", Teno = "Teno", Therizino = "Therizino",
	Dilo = "Dilo", Troodon = "Troodon"}
-- [kind][diff] = {ev, need, text}; text may have %s for the dino name
M.POOL = {
	ikills = {
		{ev = "ikill", need = 5, text = "Get 5 kills on the island"},
		{ev = "ikill", need = 12, text = "Get 12 kills on the island"},
		{ev = "ikill", need = 25, text = "Get 25 kills on the island"},
	},
	istreak = {
		nil,
		{ev = "istreak", need = 5, text = "Reach a 5 kill streak on the island", mode = "max"},
		{ev = "istreak", need = 10, text = "Reach a 10 kill streak on the island", mode = "max"},
	},
	arena = {
		{ev = "aplay", need = 1, text = "Play 1 Arena match"},
		{ev = "awin", need = 1, text = "Win 1 Arena match"},
		{ev = "awin", need = 3, text = "Win 3 Arena matches"},
	},
	akills = {
		nil,
		{ev = "akill", need = 8, text = "Get 8 Arena kills"},
		{ev = "akill", need = 20, text = "Get 20 Arena kills"},
	},
	parts = {
		{ev = "part", need = 10, text = "Use mecha parts 10 times"},
		{ev = "part", need = 30, text = "Use mecha parts 30 times"},
		{ev = "part", need = 60, text = "Use mecha parts 60 times"},
	},
	dino = {
		{ev = "dkill", need = 2, text = "Get 2 kills as a %s"},
		{ev = "dkill", need = 5, text = "Get 5 kills as a %s"},
		{ev = "dkill", need = 12, text = "Get 12 kills as a %s"},
	},
}
M.KIND_ORDER = {"ikills", "istreak", "arena", "akills", "parts", "dino"}
M.SPECIALS = {
	{id = "s_zebra", ev = "ibest", need = 10, skin = "zebra", name = "ZEBRA", text = "Get a 10 kill streak on the island"},
	{id = "s_storm", ev = "ibest", need = 25, skin = "storm", name = "STORM FRONT", text = "Get a 25 kill streak on the island"},
}

M.ANYWHERE_TEXTS = true -- v1.1
M.STORM_NEED = 15 -- v1.1
if M.ANYWHERE_TEXTS then
	for d = 1, 3 do -- the pools may start with nil (no easy quest of that kind)
		local q = M.POOL.ikills[d]
		if q then q.text = ("Get %d kills anywhere"):format(q.need) end
		q = M.POOL.istreak[d]
		if q then q.text = ("Reach a %d kill streak"):format(q.need) end
	end
end
for _, s in ipairs(M.SPECIALS) do
	if s.id == "s_storm" and M.STORM_NEED then s.need = M.STORM_NEED end
	if M.ANYWHERE_TEXTS then s.text = ("Get a %d kill streak"):format(s.need) end
end
function M.day(t) return math.floor((tonumber(t) or 0) / M.DAY) end
function M.secsToDay(t)
	t = tonumber(t) or 0
	return M.DAY - (t % M.DAY)
end

local function seedOf(day, userId)
	local s = tostring(day) .. ":" .. tostring(userId)
	local h = 7
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
	return h
end

function M.pickDailies(day, userId, owned)
	local rng = Random.new(seedOf(day, userId))
	local dinos = {}
	if type(owned) == "table" then
		for _, k in ipairs(owned) do if M.DINO_NAMES[k] then table.insert(dinos, k) end end
		table.sort(dinos)
	end
	local used, out = {}, {}
	for _, diff in ipairs({3, 2, 1}) do
		local options = {}
		for _, kind in ipairs(M.KIND_ORDER) do
			if not used[kind] and M.POOL[kind][diff] and (kind ~= "dino" or #dinos > 0) then table.insert(options, kind) end
		end
		local kind = options[rng:NextInteger(1, #options)]
		used[kind] = true
		local p = M.POOL[kind][diff]
		local q = {id = ("d%d_%d_%s"):format(day, diff, kind), kind = kind, diff = diff, ev = p.ev, need = p.need, pts = M.PTS[diff],
			mode = p.mode or "add"}
		if kind == "dino" then
			q.dino = dinos[rng:NextInteger(1, #dinos)]
			q.text = p.text:format(M.DINO_NAMES[q.dino])
		else
			q.text = p.text
		end
		out[diff] = q
	end
	return out -- [1] easy, [2] medium, [3] hard
end

function M.specials() return M.SPECIALS end

function M.claimable(need, have, claimed)
	return claimed ~= true and (tonumber(have) or 0) >= (tonumber(need) or math.huge)
end

-- "a,b,c" (DinoOwnership OwnedDinos) -> {"a", "b", "c"}
function M.ownedList(s)
	local out = {}
	if type(s) ~= "string" then return out end
	for k in s:gmatch("[^,%s]+") do table.insert(out, k) end
	return out
end

return M
