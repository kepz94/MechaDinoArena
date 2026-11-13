-- HubQueue.spec v1.0 (Mecha Dino Arena) — HubRules 1.2 Arena queue (plan docs/plans/PREGAME_LINEUP_v1.0.md T4, MDA-489).
-- Run in Studio Edit (clone + require ServerStorage.DinoArcade.HubRules); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage"):FindFirstChild("DinoArcade") and game.ServerStorage.DinoArcade:FindFirstChild("HubRules")
if not src then return "FAIL require: HubRules missing" end
local ok, R = pcall(function() local c = src:Clone() c.Parent = src.Parent local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local function g(at, ...) return {at = at, ids = {...}} end
-- packTeams
local t = R.packTeams({g(1, 1, 2, 3, 4), g(2, 5, 6), g(3, 7), g(4, 8)})
eq("squad of 4 on A", #t.A, 4); eq("rest on B", #t.B, 4); eq("A holds the squad", t.A[1], 1)
t = R.packTeams({g(1, 1), g(2, 2), g(3, 3)})
eq("1v1v1 -> 2 / 1", #t.A + #t.B, 3); eq("balanced", math.abs(#t.A - #t.B) <= 1, true)
eq("3+3+2 can't pack", R.packTeams({g(1, 1, 2, 3), g(2, 4, 5, 6), g(3, 7, 8)}), nil)
t = R.packTeams({g(1, 1, 2, 3), g(2, 4, 5), g(3, 6), g(4, 7, 8)})
eq("3+2+1+2 packs", t ~= nil and (#t.A + #t.B) or -1, 8)
-- queueTake
eq("empty", R.queueTake({}, 10), nil)
eq("one player early", R.queueTake({g(0, 1)}, 10), nil)
local take = R.queueTake({g(0, 1)}, 30)
eq("one player at 30 s", take and #take, 1)
take = R.queueTake({g(0, 1, 2, 3, 4), g(1, 5, 6, 7, 8), g(2, 9)}, 3)
eq("8 now", take and #take, 2)
take = R.queueTake({g(0, 1, 2, 3), g(1, 4, 5, 6), g(2, 7, 8), g(3, 9)}, 30)
eq("skip the group that can't pack, take the next", take and R.count(take), 7)
take = R.queueTake({g(5, 1), g(0, 2)}, 30)
eq("oldest decides", take and #take, 2)
eq("count", R.count({g(0, 1, 2), g(1, 3)}), 3)
eq("modes", R.MODES.arenaMatch, true)
eq("numbers", R.QUEUE_SIZE .. "/" .. R.TEAM_SIZE .. "/" .. R.QUEUE_WAIT, "8/4/30")
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
