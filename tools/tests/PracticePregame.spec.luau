-- PracticePregame.spec v1.0 (Mecha Dino Arena) — PracticeRules 1.3 (plan docs/plans/PREGAME_LINEUP_v1.0.md T3, MDA-483).
-- Run in Studio Edit (clone + require ServerStorage.DinoArcade.PracticeRules); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage"):FindFirstChild("DinoArcade") and game.ServerStorage.DinoArcade:FindFirstChild("PracticeRules")
if not src then return "FAIL require: PracticeRules missing" end
local ok, R = pcall(function() local c = src:Clone() c.Parent = src.Parent local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
eq("switch default", R.ELITE_MIX, true)
eq("mix4", table.concat(R.mixFor(4), ","), "Elite,Hard,Elite,Hard")
eq("mix3 (your team's bots)", table.concat(R.mixFor(3), ","), "Elite,Hard,Elite")
eq("mix5 repeats", table.concat(R.mixFor(5), ","), "Elite,Hard,Elite,Hard,Elite")
local rng = Random.new(7)
eq("refill the missing Hard", R.respawnTier({"Elite", "Elite", "Hard"}, 4, rng), "Hard")
eq("refill the missing Elite", R.respawnTier({"Elite", "Hard", "Hard"}, 4, rng), "Elite")
local full = R.respawnTier({"Elite", "Elite", "Hard", "Hard"}, 4, rng)
eq("full team stays in the mix", full == "Elite" or full == "Hard", true)
eq("lineup", R.PG_LINEUP, 30); eq("ready", R.PG_READY, 5); eq("intro", R.PG_INTRO, 8)
eq("cut 20 s left -> 5", R.readyCut(100, 80), 85)
eq("cut never later", R.readyCut(100, 97), 100)
eq("cut bad now", R.readyCut(100, nil), 100)
R.ELITE_MIX = false
eq("off = 1.2 mix4", table.concat(R.mixFor(4), ","), "Elite,Hard,Normal,Easy")
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
