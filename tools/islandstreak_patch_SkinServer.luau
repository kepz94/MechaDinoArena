-- islandstreak_patch_SkinServer: ISLAND_STREAK_v1.0.
local PAIRS = {
{[=====[VERSION = "1.5" -- v1.5 SkinPaintBot for filler bots]=====], [=====[VERSION = "1.5" -- v1.5 SkinPaintBot for filler bots
VERSION = "1.6" -- v1.6 island streak earn stat
-- v1.6 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 3): the earn stats also carry istreak =
--   max(StatIslandBest, IslandStreak) (SkinStats 1.1) for UniversalSkins 1.4 (Zebra 10, Storm Front 25), and a change of
--   IslandStreak / StatIslandBest runs the earn check. Switch: script attribute SkinIslandStreakEarnEnabled (default true, read
--   per check; false = istreak 0, so the streak skins stay locked).]=====]},
{[=====[	return {w = player:GetAttribute("ArenaW"), l = player:GetAttribute("ArenaL"), kills = player:GetAttribute("StatKills"), best = streak}]=====], [=====[	local istreak = script:GetAttribute("SkinIslandStreakEarnEnabled") ~= false -- v1.6
		and math.max(tonumber(player:GetAttribute("StatIslandBest")) or 0, tonumber(player:GetAttribute("IslandStreak")) or 0) or 0
	return {w = player:GetAttribute("ArenaW"), l = player:GetAttribute("ArenaL"), kills = player:GetAttribute("StatKills"), best = streak,
		istreak = istreak}]=====]},
{[=====[		SkinStatsReady = true}
]=====], [=====[		SkinStatsReady = true, IslandStreak = true, StatIslandBest = true} -- v1.6: + island streak
]=====]},
}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
local m = Instance.new("ModuleScript")
m.Source = "return function()\n" .. s .. "\nend"
m.Parent = workspace
local okC, errC = pcall(require, m)
m:Destroy()
if not okC then return "COMPILE FAIL " .. tostring(errC) end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
