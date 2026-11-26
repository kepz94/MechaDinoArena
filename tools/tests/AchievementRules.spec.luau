-- AchievementRules.spec v1.0 (Mecha Dino Arena) — run in Studio Edit; returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("AchievementRules")
if not src then return "FAIL missing ServerStorage.DinoArcade.AchievementRules" end
local ok, R = pcall(function() local c = src:Clone() c.Parent = workspace local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
eq("17", #R.LIST, 17)
local total, where, ids = 0, {}, {}
for _, x in ipairs(R.LIST) do
	total += R.pts(x)
	where[x.where] = (where[x.where] or 0) + 1
	eq("unique " .. x.id, ids[x.id], nil)
	ids[x.id] = true
	eq("medal " .. x.id, R.PTS[x.medal] ~= nil, true)
	eq("stat " .. x.id, R.MAX_STATS[x.stat] or R.LIVE_STATS[x.stat] or ({ikill = 1, akill = 1, aplay = 1, awin = 1, qclaim = 1})[x.stat] ~= nil, true)
end
eq("95 points", total, 95)
eq("6 island", where.ISLAND, 6)
eq("5 arena", where.ARENA, 5)
eq("6 both", where.BOTH, 6)
local live = R.liveStats("Raptor,TRex,Pachy,Dilo", "classic,zebra", 12)
eq("dinos 4", live.dinos, 4)
eq("skins 2", live.skins, 2)
eq("level 12", live.level, 12)
eq("live nil", R.liveStats(nil, nil, nil).dinos, 0)
eq("collect have", R.have(R.BY_ID.collect, {}, live), 4)
eq("collect ready", R.claimable(R.BY_ID.collect, 4, false), true)
eq("first have", R.have(R.BY_ID.first, {ikill = 3}, live), 3)
eq("first none", R.have(R.BY_ID.first, nil, live), 0)
eq("first claimed", R.claimable(R.BY_ID.first, 3, true), false)
eq("apex short", R.claimable(R.BY_ID.apex, 249, false), false)
eq("hot max stat", R.MAX_STATS[R.BY_ID.hot.stat], true)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
