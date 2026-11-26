-- islandstreak_patch_Lab: ISLAND_STREAK_v1.0.
local PAIRS = {
{[=====[VERSION = "2.1" -- v2.1 Looks Lab v1.0: owned first, locked tiles say why, emote wheel on the left]=====], [=====[VERSION = "2.1" -- v2.1 Looks Lab v1.0: owned first, locked tiles say why, emote wheel on the left
VERSION = "2.2" -- v2.2 island streak progress
-- v2.2 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 4): uniStats() also carries istreak = max(StatIslandBest,
--   IslandStreak) (SkinStats 1.1), so the Zebra and Storm Front cards (UniversalSkins 1.4) show their island streak progress through
--   the existing earn card path. No layout change.]=====]},
{[=====[		best = math.max(tonumber(player:GetAttribute("StatBestStreak")) or 0, tonumber(player:GetAttribute("ArenaStreak")) or 0)}]=====], [=====[		best = math.max(tonumber(player:GetAttribute("StatBestStreak")) or 0, tonumber(player:GetAttribute("ArenaStreak")) or 0),
		istreak = math.max(tonumber(player:GetAttribute("StatIslandBest")) or 0, tonumber(player:GetAttribute("IslandStreak")) or 0)} -- v2.2]=====]},
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
