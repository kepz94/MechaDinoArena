-- islandstreak_patch_SkinStats: ISLAND_STREAK_v1.0.
local PAIRS = {
{[=====[local VERSION = "1.0"
]=====], [=====[local VERSION = "1.0"
VERSION = "1.1" -- v1.1 island kill streak
-- v1.1 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 2; Kepu 2026-11-26 "a fire streak emblem once you go on a killing spree on the main island. 25 kills streak unlocks the
--   thunder storm skin. 10 kill streak unlocks the zebra"; kills of players and bots, main island
--   only; picks "Death or menu"): every counted kill (after the dedupe above) also adds 1 to the killer's island streak when
--   script attribute SkinStatsIslandStreakEnabled ~= false, ReplicatedStorage ServerKind == "hub", the killer's TutLane is not
--   > 0 and the killer's Humanoid is alive. The streak goes back to 0 when the killer's Humanoid dies, on a new character and
--   when the player's InMenu turns true. Best island streak = max(best, streak), saved as ib in the same UpdateAsync merge
--   (ib = max(stored, ours); v stays 1) and loaded with the rest. Player attributes IslandStreak (current) and StatIslandBest
--   (best). Diagnostics: script IslandStreakCounted, IslandStreakResets. false = 1.0.]=====]},
{[=====[	player:SetAttribute("SkinStatsReady", st.loaded)
]=====], [=====[	player:SetAttribute("SkinStatsReady", st.loaded)
	player:SetAttribute("IslandStreak", st.istreak or 0) -- v1.1
	player:SetAttribute("StatIslandBest", st.ib or 0) -- v1.1
]=====]},
{[=====[	if st.pending == 0 and not st.bestDirty then return end
	local add, best = st.pending, st.best
]=====], [=====[	if st.pending == 0 and not st.bestDirty and not st.ibDirty then return end -- v1.1: + ibDirty
	local add, best = st.pending, st.best
	local ib = st.ib or 0 -- v1.1
]=====]},
{[=====[				v.best = math.max(tonumber(v.best) or 0, best)
]=====], [=====[				v.best = math.max(tonumber(v.best) or 0, best)
				v.ib = math.max(tonumber(v.ib) or 0, ib) -- v1.1
]=====]},
{[=====[		if st.best == best then st.bestDirty = false end
]=====], [=====[		if st.best == best then st.bestDirty = false end
		st.ib = math.max(st.ib or 0, tonumber(stored.ib) or 0) -- v1.1
		if st.ib == ib then st.ibDirty = false end
]=====]},
{[=====[				st.best = math.max(st.best, math.floor(tonumber(value.best) or 0))
]=====], [=====[				st.best = math.max(st.best, math.floor(tonumber(value.best) or 0))
				st.ib = math.max(st.ib or 0, math.floor(tonumber(value.ib) or 0)) -- v1.1
]=====]},
{[=====[	states[player] = {loaded = false, k = 0, pending = 0, best = 0, bestDirty = false, lastChange = 0}
]=====], [=====[	states[player] = {loaded = false, k = 0, pending = 0, best = 0, bestDirty = false, lastChange = 0}
	states[player].istreak, states[player].ib, states[player].ibDirty = 0, 0, false -- v1.1
]=====]},
{[=====[	player:GetAttributeChangedSignal("ArenaStreak"):Connect(function() onStreak(player) end)
	onStreak(player)
]=====], [=====[	player:GetAttributeChangedSignal("ArenaStreak"):Connect(function() onStreak(player) end)
	onStreak(player)
	local function resetStreak() -- v1.1: death, a new body or the menu ends the island streak
		local s = states[player]
		if s and (s.istreak or 0) > 0 then
			s.istreak = 0
			bump("IslandStreakResets")
			publish(player)
		end
	end
	local function hookChar(c)
		resetStreak()
		local hum = c:WaitForChild("Humanoid", 10)
		if hum then hum.Died:Connect(resetStreak) end
	end
	player.CharacterAdded:Connect(hookChar)
	if player.Character then task.spawn(hookChar, player.Character) end
	player:GetAttributeChangedSignal("InMenu"):Connect(function()
		if player:GetAttribute("InMenu") == true then resetStreak() end
	end)
]=====]},
{[=====[-- kills
local seen = setmetatable({}, {__mode = "k"})]=====], [=====[-- v1.1: the island streak part of a counted kill
if script:GetAttribute("SkinStatsIslandStreakEnabled") == nil then script:SetAttribute("SkinStatsIslandStreakEnabled", true) end
script:SetAttribute("IslandStreakCounted", 0)
script:SetAttribute("IslandStreakResets", 0)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function islandKill(player, st)
	if script:GetAttribute("SkinStatsIslandStreakEnabled") == false or ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" then return end
	if (tonumber(player:GetAttribute("TutLane")) or 0) > 0 then return end
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then return end
	st.istreak = (st.istreak or 0) + 1
	if st.istreak > (st.ib or 0) then
		st.ib = st.istreak
		st.ibDirty = true
	end
	bump("IslandStreakCounted")
end
-- kills
local seen = setmetatable({}, {__mode = "k"})]=====]},
{[=====[	bump("SkinStatsCounted")
]=====], [=====[	bump("SkinStatsCounted")
	islandKill(player, st) -- v1.1
]=====]},
{[=====[if st.loaded and (st.pending > 0 or st.bestDirty) and]=====], [=====[if st.loaded and (st.pending > 0 or st.bestDirty or st.ibDirty) and]=====]},
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
