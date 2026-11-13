-- ArenaRecordRules.spec v1.0 (Mecha Dino Arena) — ArenaRecordRules 1.0 (plan docs/plans/PREGAME_LINEUP_v1.0.md T1, MDA-481).
-- Run in Studio Edit (clone + require ServerStorage.DinoArcade.ArenaRecordRules); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage"):FindFirstChild("DinoArcade") and game.ServerStorage.DinoArcade:FindFirstChild("ArenaRecordRules")
if not src then return "FAIL require: ServerStorage.DinoArcade.ArenaRecordRules missing" end
local ok, R = pcall(function() local c = src:Clone() c.Parent = src.Parent local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
-- outcome
eq("not eligible", R.outcome(false, "A", "A", false, false), nil)
eq("not eligible leaver", R.outcome(false, nil, "A", true, false), nil)
eq("leaver loses", R.outcome(true, nil, "A", true, false), "l")
eq("leaver on winning team still loses", R.outcome(true, "A", "A", true, true), "l")
eq("win", R.outcome(true, "A", "A", false, false), "w")
eq("win B", R.outcome(true, "B", "B", false, true), "w")
eq("loss", R.outcome(true, "B", "A", false, false), "l")
eq("lost with a leaver = nothing", R.outcome(true, "B", "A", false, true), nil)
eq("draw", R.outcome(true, "draw", "A", false, false), nil)
eq("no winner", R.outcome(true, nil, "A", false, false), nil)
eq("no team", R.outcome(true, "A", nil, false, false), nil)
-- eligible
eq("1v1 eligible", R.eligible(1, 1), true)
eq("1v0 not", R.eligible(1, 0), false)
eq("bad input", R.eligible(nil, "x"), false)
-- apply
local r = R.apply(nil, "w", "m1")
eq("first win", r.w, 1); eq("first win l", r.l, 0); eq("lastMatch", r.lastMatch, "m1")
local r2 = R.apply(r, "w", "m1")
eq("dedupe", r2.w, 1)
eq("input untouched", r.w, 1)
r2 = R.apply(r, "l", "m2")
eq("loss adds", r2.l, 1); eq("w kept", r2.w, 1); eq("lastMatch m2", r2.lastMatch, "m2")
r2 = R.apply(r, nil, "m3")
eq("nil out unchanged", r2.w + r2.l, 1); eq("nil out keeps lastMatch", r2.lastMatch, "m1")
r2 = R.apply({w = -3, l = "x", lastMatch = 5}, "l", "")
eq("clean w", r2.w, 0); eq("clean l", r2.l, 1); eq("empty id counts", r2.lastMatch, "")
r2 = R.apply(r2, "l", "")
eq("empty id never dedupes", r2.l, 2)
-- pct
eq("pct 0-0", R.pct(0, 0), 0); eq("pct 31-12", R.pct(31, 12), 72); eq("pct 1-0", R.pct(1, 0), 100)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
