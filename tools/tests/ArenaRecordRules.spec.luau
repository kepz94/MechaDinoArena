-- ArenaRecordRules.spec v1.1 (Mecha Dino Arena) — ArenaRecordRules 1.0 (plan docs/plans/PREGAME_LINEUP_v1.0.md T1, MDA-481).
-- v1.1 (MDA-493, plan docs/plans/ARENA_RECORD_v1.1.md T1): last 10 + streak (last, s, streakText).
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
-- v1.1: last 10 + streak
eq("version", R.VERSION, "1.1")
eq("LAST_N", R.LAST_N, 10)
local c = R.clean(nil)
eq("clean last", c.last, ""); eq("clean s", c.s, 0)
c = R.clean({w = 1, l = 1, last = "wxLlw", s = 3.7})
eq("clean last letters", c.last, "wlw"); eq("clean s whole", c.s, 3)
eq("clean last 10", R.clean({last = "lwwwwwwwwwwl"}).last, "wwwwwwwwwl")
eq("clean s clamp", R.clean({s = 1e9}).s, 9999); eq("clean s clamp neg", R.clean({s = -1e9}).s, -9999)
eq("clean bad s", R.clean({s = "x"}).s, 0); eq("clean bad last", R.clean({last = 5}).last, "")
local old = {w = 31, l = 12, lastMatch = "m0"} -- a 1.0 record
local a = R.apply(old, "w", "m1")
eq("old record w", a.w, 32); eq("old record last", a.last, "w"); eq("old record s", a.s, 1)
a = R.apply(a, "w", "m2")
eq("2 wins last", a.last, "ww"); eq("2 wins s", a.s, 2)
a = R.apply(a, "l", "m3")
eq("loss after wins s", a.s, -1); eq("loss last", a.last, "wwl")
a = R.apply(a, "l", "m4")
eq("2 losses s", a.s, -2)
a = R.apply(a, "w", "m5")
eq("win after losses s", a.s, 1); eq("last 5", a.last, "wwllw")
local d = R.apply(a, "w", "m5")
eq("dedupe last", d.last, "wwllw"); eq("dedupe s", d.s, 1); eq("dedupe w", d.w, a.w)
local n = R.apply(a, nil, "m6")
eq("nil out last", n.last, "wwllw"); eq("nil out s", n.s, 1)
local t = {last = "", s = 0}
for i = 1, 12 do t = R.apply(t, i % 3 == 0 and "l" or "w", "x" .. i) end
eq("keeps 10", #t.last, 10); eq("newest last", t.last:sub(-1), "l"); eq("oldest dropped", t.last, "lwwlwwlwwl")
eq("streak 2", R.streakText(2), "2 WIN STREAK"); eq("streak 7", R.streakText(7), "7 WIN STREAK")
eq("streak 1", R.streakText(1), ""); eq("streak 0", R.streakText(0), ""); eq("streak -3", R.streakText(-3), ""); eq("streak nil", R.streakText(nil), "")
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
