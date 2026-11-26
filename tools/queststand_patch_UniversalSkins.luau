-- queststand_patch_UniversalSkins: QUEST_STAND_v1.0.
local PAIRS = {
{[=====[US.VERSION = "1.4" -- v1.4 island streak unlocks (Zebra 10, Storm Front 25)]=====], [=====[US.VERSION = "1.4" -- v1.4 island streak unlocks (Zebra 10, Storm Front 25)
US.VERSION = "1.5" -- v1.5 streak skins claimed at the Quest Stand
-- v1.5 (Quest Stand, plan docs/plans/QUEST_STAND_v1.0.md Task 3; Kepu 2026-11-26 "this is the only place where you can claim them",
--   picks "Claim at the stand", "Always claimable"): with US.STAND_CLAIMS (true) the Zebra and Storm Front unlocks get
--   claim = "stand" (SkinServer 1.7 no longer grants them by itself; QuestServer 1.0 grants them through SkinGrant when claimed) and
--   the text "10 / 25 kill streak on the island, claim at the Quest Stand". Progress (istreak) is unchanged. false = 1.4.]=====]},
{[=====[	US.SKINS.storm.unlock = earn("istreak", 25, "Get a 25 kill streak on the island")
end
]=====], [=====[	US.SKINS.storm.unlock = earn("istreak", 25, "Get a 25 kill streak on the island")
end
US.STAND_CLAIMS = true -- v1.5
if US.ISLAND_STREAK_UNLOCKS and US.STAND_CLAIMS then
	US.SKINS.zebra.unlock.claim = "stand"
	US.SKINS.zebra.unlock.text = "10 kill streak on the island, claim at the Quest Stand"
	US.SKINS.storm.unlock.claim = "stand"
	US.SKINS.storm.unlock.text = "25 kill streak on the island, claim at the Quest Stand"
end
]=====]},
}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k)
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
