-- AchievementRules v1.0 (Mecha Dino Arena) — the 17 achievements (ModuleScript, ServerStorage.DinoArcade). Plan
-- docs/plans/ACHIEVEMENTS_v1.0.md Task 1, mockup docs/mockups/achievements_v0.1.html "B · Three columns"; Kepu 2026-11-26 "create random
-- achievements they can collect on through either the island fighting or the arena or both"; picks "Skill points by tier", "Claim at
-- the Quest Stand", "In-game only", "Use as written", "Start fresh" (counted stats count from launch), "Live state" (own / reach).
-- LIST: {id, name, text, where ("ISLAND" / "ARENA" / "BOTH"), medal ("b" / "s" / "g"), stat, need}. PTS by medal: b 2, s 5, g 10.
-- Stats: counted by QuestServer 1.1 ("ikill", "akill", "aplay", "awin", "qclaim": add; "istreak", "awstreak": max) or live ("dinos",
--   "skins", "level") from liveStats(OwnedDinos, SkinOwnedU, SkillLevel).
-- have(a, counters, live) -> the value for a's stat; claimable(a, have, claimed) -> have >= need and not claimed.
local M = {}
M.Version = "1.0"
M.PTS = {b = 2, s = 5, g = 10}
M.MAX_STATS = {istreak = true, awstreak = true}
M.LIVE_STATS = {dinos = true, skins = true, level = true}
local function a(id, name, text, where, medal, stat, need)
	return {id = id, name = name, text = text, where = where, medal = medal, stat = stat, need = need}
end
M.LIST = {
	a("first", "FIRST BLOOD", "Get your first kill on the island", "ISLAND", "b", "ikill", 1),
	a("hunter", "ISLAND HUNTER", "Get 50 kills on the island", "ISLAND", "s", "ikill", 50),
	a("apex", "APEX OF THE ISLAND", "Get 250 kills on the island", "ISLAND", "g", "ikill", 250),
	a("fire", "ON FIRE", "Reach a 5 kill streak on the island", "ISLAND", "b", "istreak", 5),
	a("unstop", "UNSTOPPABLE", "Reach a 15 kill streak on the island", "ISLAND", "s", "istreak", 15),
	a("storm", "STORM BRINGER", "Reach a 25 kill streak on the island", "ISLAND", "g", "istreak", 25),
	a("win1", "FIRST WIN", "Win an Arena match", "ARENA", "b", "awin", 1),
	a("regular", "ARENA REGULAR", "Play 25 Arena matches", "ARENA", "s", "aplay", 25),
	a("champ", "CHAMPION", "Win 25 Arena matches", "ARENA", "g", "awin", 25),
	a("hot", "HOT STREAK", "Win 3 Arena matches in a row", "ARENA", "s", "awstreak", 3),
	a("brawler", "ARENA BRAWLER", "Get 100 Arena kills", "ARENA", "s", "akill", 100),
	a("collect", "DINO COLLECTOR", "Own 4 dinos", "BOTH", "s", "dinos", 4),
	a("roster", "FULL ROSTER", "Own all 8 dinos", "BOTH", "g", "dinos", 8),
	a("lvl10", "LEVELING UP", "Reach level 10", "BOTH", "b", "level", 10),
	a("lvlmax", "MAX LEVEL", "Reach level 41", "BOTH", "g", "level", 41),
	a("quests", "QUEST FAN", "Claim 25 daily quests", "BOTH", "s", "qclaim", 25),
	a("fashion", "FASHION DINO", "Own 5 skins", "BOTH", "b", "skins", 5),
}
M.BY_ID = {}
for _, x in ipairs(M.LIST) do M.BY_ID[x.id] = x end

local function count(s)
	local n = 0
	if type(s) ~= "string" then return 0 end
	for _ in s:gmatch("[^,%s]+") do n += 1 end
	return n
end
function M.liveStats(ownedDinos, skinOwned, level)
	return {dinos = count(ownedDinos), skins = count(skinOwned), level = math.max(0, math.floor(tonumber(level) or 0))}
end
function M.have(x, counters, live)
	if M.LIVE_STATS[x.stat] then return tonumber(live and live[x.stat]) or 0 end
	return tonumber(counters and counters[x.stat]) or 0
end
function M.claimable(x, have, claimed)
	return claimed ~= true and (tonumber(have) or 0) >= x.need
end
function M.pts(x) return M.PTS[x.medal] or 0 end

return M
