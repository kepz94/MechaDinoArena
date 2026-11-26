-- islandstreak_patch_UniversalSkins: ISLAND_STREAK_v1.0.
local PAIRS = {
{[=====[US.VERSION = "1.3" -- v1.3 price steps bland 149 / glowing 499 / animated 999 (v1.2 Prism 999; v1.1 whole-body animation)]=====], [=====[US.VERSION = "1.3" -- v1.3 price steps bland 149 / glowing 499 / animated 999 (v1.2 Prism 999; v1.1 whole-body animation)
US.VERSION = "1.4" -- v1.4 island streak unlocks (Zebra 10, Storm Front 25)
-- v1.4 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 1; Kepu 2026-11-26 "a fire streak emblem once you go on a killing spree on the main island. 25 kills streak unlocks the
--   thunder storm skin. 10 kill streak unlocks the zebra"; roadmap D3 "Streak replaces old";
--   Storm Front "Earn only"): with US.ISLAND_STREAK_UNLOCKS (true) Zebra unlocks at a 10 kill streak on the island and Storm Front
--   at a 25 kill streak (earn stat "istreak" = stats.istreak, SkinServer / Lab: max(StatIslandBest, IslandStreak) from SkinStats
--   1.1). Storm Front is no longer a Robux skin (owners keep it); its look, anim and ORDER place are unchanged. false = 1.3.]=====]},
{[=====[}
for id, sk in pairs(US.SKINS) do
]=====], [=====[}
US.ISLAND_STREAK_UNLOCKS = true -- v1.4
if US.ISLAND_STREAK_UNLOCKS then
	US.SKINS.zebra.unlock = earn("istreak", 10, "Get a 10 kill streak on the island")
	US.SKINS.storm.unlock = earn("istreak", 25, "Get a 25 kill streak on the island")
end
for id, sk in pairs(US.SKINS) do
]=====]},
{[=====[	elseif s == "best" then have = tonumber(stats.best) or 0 end]=====], [=====[	elseif s == "best" then have = tonumber(stats.best) or 0
	elseif s == "istreak" then have = tonumber(stats.istreak) or 0 end -- v1.4]=====]},
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
