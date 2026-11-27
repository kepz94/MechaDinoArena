"""Kepu 2026-11-27 16:16 "The broken stuff you mentioned can still work if it applies to arena", 16:17 "Okay do 1" (bug hunt
2026-11-27 HIGH 1: island kill / streak quests, Zebra / Storm Front and the island achievements could not be done alone since the island
bots are off, v1086). Item 1 as proposed: kills and kill streaks count on every server (island and Arena match servers); texts lose
"on the island"; Storm Front 25 -> 15 (proposed, standing pick "recommended"). The achievements' ISLAND column (QuestScreen three
columns, Kepu's pick) is kept as it is: only the texts change.
* SkinStats 1.3: the kill streak counts on every ServerKind (1.1: hub only). Switch SkinStatsStreakEverywhereEnabled.
* QuestServer 1.3: a kill on a non-hub server also adds "ikill" (with "akill"). Switch QuestKillsEverywhereEnabled.
* QuestRules 1.1, AchievementRules 1.1, UniversalSkins 1.9: texts; Storm Front special / skin need 15. Switches in the modules.
Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_anywhere.py"""
SSS = 'game:GetService("ServerScriptService").'
DA = 'game:GetService("ServerStorage").DinoArcade.'
JOBS = {}

S = []
a = 'VERSION = "1.2" -- v1.2 store line + launch reset\n'
S.append((a, a + '''VERSION = "1.3" -- v1.3 the kill streak counts in the Arena too
-- v1.3 (Kepu 2026-11-27 16:16 "The broken stuff you mentioned can still work if it applies to arena", 16:17 "Okay do 1"; bug hunt
--   2026-11-27: island streaks could not be reached alone since the island bots are off): while script attribute
--   SkinStatsStreakEverywhereEnabled ~= false (default true, read per kill) the streak counts on every server kind (island and Arena
--   match servers), with the same rules (not in a tutorial lane, alive; reset on death, a new body or the menu). The saved best (ib)
--   is the same value, so Zebra / Storm Front and the streak quests count Arena streaks. false = 1.2 (island only).
'''))
a = '''	if script:GetAttribute("SkinStatsIslandStreakEnabled") == false or ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" then return end
'''
S.append((a, '''	if script:GetAttribute("SkinStatsIslandStreakEnabled") == false then return end
	if ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" and script:GetAttribute("SkinStatsStreakEverywhereEnabled") == false then return end -- v1.3
'''))
JOBS["SkinStats"] = ("src/server/SkinStats.server.luau", SSS + "SkinStats", S)

Q = []
a = 'VERSION = "1.2" -- v1.2 launch reset\n'
Q.append((a, a + '''VERSION = "1.3" -- v1.3 kills count for the "kills" quests and achievements on every server
-- v1.3 (Kepu 2026-11-27 16:17 "Okay do 1"; bug hunt 2026-11-27: island kills could not be had alone since the island bots are off):
--   while script attribute QuestKillsEverywhereEnabled ~= false (default true, read per kill) a kill on a non-hub server adds "ikill"
--   as well as "akill" (dailies "Get n kills anywhere", achievements FIRST BLOOD / ISLAND HUNTER / APEX OF THE ISLAND). The streak
--   ("istreak") follows SkinStats 1.3. false = 1.2.
'''))
a = '''	add(player, isHub() and "ikill" or "akill", 1)
'''
Q.append((a, a + '''	if not isHub() and script:GetAttribute("QuestKillsEverywhereEnabled") ~= false then add(player, "ikill", 1) end -- v1.3
'''))
JOBS["QuestServer"] = ("src/server/QuestServer.server.luau", SSS + "QuestServer", Q)

R = []
a = 'M.Version = "1.0"\n'
R.append((a, '''M.Version = "1.0"
M.Version = "1.1" -- v1.1 kills / streaks anywhere texts, Storm Front 15
-- v1.1 (Kepu 2026-11-27 16:17 "Okay do 1"; QuestServer 1.3 / SkinStats 1.3 count kills and streaks on every server): with
--   M.ANYWHERE_TEXTS (true) the ikills / istreak dailies and the specials lose "on the island" ("Get 5 kills anywhere", "Reach a 5 kill
--   streak"); with M.STORM_NEED (15; nil = 1.0's 25) s_storm needs that best streak. Ids, events and the other numbers unchanged.
'''))
a = 'function M.day(t) return math.floor((tonumber(t) or 0) / M.DAY) end\n'
R.append((a, '''M.ANYWHERE_TEXTS = true -- v1.1
M.STORM_NEED = 15 -- v1.1
if M.ANYWHERE_TEXTS then
	for _, q in ipairs(M.POOL.ikills) do q.text = ("Get %d kills anywhere"):format(q.need) end
	for _, q in ipairs(M.POOL.istreak) do q.text = ("Reach a %d kill streak"):format(q.need) end
end
for _, s in ipairs(M.SPECIALS) do
	if s.id == "s_storm" and M.STORM_NEED then s.need = M.STORM_NEED end
	if M.ANYWHERE_TEXTS then s.text = ("Get a %d kill streak"):format(s.need) end
end
''' + a))
JOBS["QuestRules"] = ("src/shared/QuestRules.luau", DA + "QuestRules", R)

A = []
a = 'M.Version = "1.0"\n'
A.append((a, '''M.Version = "1.0"
M.Version = "1.1" -- v1.1 kills / streaks anywhere texts
-- v1.1 (Kepu 2026-11-27 16:17 "Okay do 1"; QuestServer 1.3 / SkinStats 1.3 count kills and streaks on every server): with
--   M.ANYWHERE_TEXTS (true) the six ikill / istreak achievements lose "on the island"; names, columns (where "ISLAND"), medals and
--   needs unchanged.
'''))
a = 'M.BY_ID = {}\n'
A.append((a, '''M.ANYWHERE_TEXTS = true -- v1.1
if M.ANYWHERE_TEXTS then
	local T = {first = "Get your first kill", hunter = "Get 50 kills anywhere", apex = "Get 250 kills anywhere",
		fire = "Reach a 5 kill streak", unstop = "Reach a 15 kill streak", storm = "Reach a 25 kill streak"}
	for _, x in ipairs(M.LIST) do if T[x.id] then x.text = T[x.id] end end
end
''' + a))
JOBS["AchievementRules"] = ("src/shared/AchievementRules.luau", DA + "AchievementRules", A)

U = []
a = '''	US.SKINS.storm.unlock.text = "25 kill streak on the island, claim at the Quest Stand"
end
'''
U.append((a, a + '''US.VERSION = "1.9" -- v1.9 streak skins: any server, Storm Front 15
-- v1.9 (Kepu 2026-11-27 16:17 "Okay do 1"; SkinStats 1.3 counts the streak on every server): with US.STREAK_ANYWHERE (true) Zebra /
--   Storm Front texts lose "on the island" and Storm Front needs US.STORM_NEED (15; 1.4: 25). Zebra stays 10. false = 1.8.
US.STREAK_ANYWHERE = true -- v1.9
US.STORM_NEED = 15 -- v1.9
if US.STREAK_ANYWHERE and US.ISLAND_STREAK_UNLOCKS then
	US.SKINS.storm.unlock.need = US.STORM_NEED
	for _, id in ipairs({"zebra", "storm"}) do
		local u = US.SKINS[id].unlock
		u.text = u.claim == "stand" and (u.need .. " kill streak, claim at the Quest Stand") or ("Get a " .. u.need .. " kill streak")
	end
end
'''))
JOBS["UniversalSkins"] = ("src/shared/UniversalSkins.luau", DA + "UniversalSkins", U)
