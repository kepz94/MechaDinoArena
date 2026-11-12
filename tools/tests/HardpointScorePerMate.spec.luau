-- HardpointScorePerMate.spec v1.0 (Mecha Dino Arena) — HardpointRules 1.3 stepCount: 1 a second per teammate on the point.
-- Run in Studio Edit (clones ServerStorage.DinoArcade.HardpointRules); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("HardpointRules")
if not src then return "FAIL require: HardpointRules missing" end
local c = src:Clone() c.Parent = src.Parent
local okR, H = pcall(require, c)
c:Destroy()
if not okR then return "FAIL require: " .. tostring(H) end
local fails, passes = {}, 0
local function eq(name, got, want) if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end end
local function run(occ, nA, nB, secs)
	local s = H.newState()
	for _ = 1, math.floor(secs / H.TICK + 0.5) do s = H.stepCount(s, occ, nA, nB, H.TICK) end
	return s
end
eq("version", H.VERSION, "1.3")
eq("switch", H.SCORE_PER_MATE, true)
eq("A x1", run("A", 1, 0, 10).scoreA, 10)
eq("A x4", run("A", 4, 0, 10).scoreA, 40)
eq("B x3", run("B", 0, 3, 10).scoreB, 30)
eq("B x3 A none", run("B", 0, 3, 10).scoreA, 0)
eq("contested", run("C", 4, 2, 10).scoreA + run("C", 4, 2, 10).scoreB, 0)
eq("contested clock", run("C", 4, 2, 10).clock, H.CLOCK)
eq("empty clock", run("N", 0, 0, 10).clock, H.CLOCK - 10)
eq("A x5 clock paused", run("A", 5, 0, 10).clock, H.CLOCK)
eq("cap", run("A", 5, 0, 60).scoreA, H.LIMIT)
eq("A count 0 -> 1", run("A", 0, 0, 10).scoreA, 10)
H.SCORE_PER_MATE = false
eq("switch off = 1 a second", run("A", 4, 0, 10).scoreA, 10)
H.SCORE_PER_MATE = true
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
