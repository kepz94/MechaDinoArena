-- MatchAwards.spec v1.0 (Mecha Dino Arena) — MatchAwards 1.0 (plan docs/plans/MATCH_END_v1.0.md Task 1, MDA-461).
-- Run in Studio Edit (clones ServerStorage.DinoArcade.MatchAwards); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("MatchAwards")
if not src then return "FAIL require: MatchAwards missing" end
local c = src:Clone() c.Parent = src.Parent
local okR, R = pcall(require, c)
c:Destroy()
if not okR then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want) if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end end

eq("version", R.VERSION, "1.0")
eq("cfg", R.CFG.kill == 50 and R.CFG.sec == 1 and R.CFG.win == 100 and R.CFG.draw == 50 and R.CFG.mvp == 50 and R.CFG.svp == 25
	and R.CFG.practiceMul == 0.1 and R.CFG.mvpKill == 100 and R.CFG.mvpSec == 10, true)
-- score
eq("score", R.score({k = 8, pt = 140.4}), 8 * 100 + 140 * 10)
eq("score round pt", R.score({k = 0, pt = 9.5}), 100)
eq("score bad", R.score(nil), 0)
eq("score cfg", R.score({k = 2, pt = 10}, {mvpKill = 1, mvpSec = 0}), 2)

local rows = {
	{id = "u1", team = "A", k = 8, d = 4, pt = 140, pk = 8},
	{id = "u2", team = "A", k = 11, d = 6, pt = 35, pk = 11},
	{id = "u3", team = "B", k = 9, d = 7, pt = 120, pk = 9},
	{id = "u4", team = "B", k = 2, d = 6, pt = 95, pk = 2},
	{id = "bX", team = "B", k = 30, d = 1, pt = 600, bot = true},
}
-- u1: 800 + 1400 = 2200; u2: 1100 + 350 = 1450; u3: 900 + 1200 = 2100; u4: 200 + 950 = 1150; bot ignored
local m, s = R.pick(rows, "A")
eq("win A mvp", m, "u1"); eq("win A svp", s, "u3")
m, s = R.pick(rows, "B")
eq("win B mvp", m, "u3"); eq("win B svp", s, "u1")
m, s = R.pick(rows, "draw")
eq("draw mvp", m, "u1"); eq("draw svp", s, "u3")
m, s = R.pick(rows, "x")
eq("bad winner", m, nil); eq("bad winner svp", s, nil)
m, s = R.pick({{id = "u1", team = "A", k = 1, pt = 0}, {id = "bB", team = "B", bot = true, k = 9, pt = 9}}, "B")
eq("only bots win: no mvp", m, nil); eq("only bots win: svp human", s, "u1")
m, s = R.pick({}, "A")
eq("empty", m, nil); eq("empty svp", s, nil)
eq("pick nil rows", (R.pick(nil, "A")), nil)
-- ties: same score -> more point time; then fewer deaths; then smaller id
m = R.pick({{id = "u9", team = "A", k = 1, pt = 0, d = 0}, {id = "u8", team = "A", k = 0, pt = 10, d = 5}}, "A")
eq("tie point time", m, "u8")
m = R.pick({{id = "u9", team = "A", k = 1, pt = 10, d = 2}, {id = "u8", team = "A", k = 1, pt = 10, d = 3}}, "A")
eq("tie deaths", m, "u9")
m = R.pick({{id = "u9", team = "A", k = 1, pt = 10, d = 2}, {id = "u8", team = "A", k = 1, pt = 10, d = 2}}, "A")
eq("tie id", m, "u8")
eq("no team skipped", (R.pick({{id = "u1", team = "", k = 5, pt = 5}}, "draw")), nil)
-- lines arena
local ctx = {winner = "A", practice = false, mvpId = "u1", svpId = "u3"}
local l = R.lines(rows[1], ctx)
eq("a kill", l.kill, 400); eq("a point", l.point, 140); eq("a win", l.win, 100); eq("a mvp", l.mvp, 50); eq("a svp", l.svp, 0)
eq("a total", l.total, 690)
l = R.lines(rows[3], ctx)
eq("b kill", l.kill, 450); eq("b win", l.win, 0); eq("b svp", l.svp, 25); eq("b total", l.total, 450 + 120 + 25)
l = R.lines(rows[4], {winner = "draw", mvpId = "u1", svpId = "u3"})
eq("draw win", l.win, 50); eq("draw total", l.total, 100 + 95 + 50)
l = R.lines({id = "u5", team = "A", pt = 10.4}, ctx)
eq("no pk", l.kill, 0); eq("pt rounds", l.point, 10)
-- lines practice
local pctx = {winner = "A", practice = true, mvpId = "u1", svpId = nil}
l = R.lines(rows[1], pctx)
eq("p kill", l.kill, 0); eq("p point", l.point, 14); eq("p win", l.win, 10); eq("p mvp", l.mvp, 5); eq("p total", l.total, 29)
l = R.lines({id = "u7", team = "A", pt = 3}, pctx)
eq("p point round", l.point, 0)
l = R.lines({id = "u7", team = "A", pt = 5}, pctx)
eq("p point half up", l.point, 1)
eq("p svp", R.lines({id = "u3", team = "B"}, {winner = "A", practice = true, svpId = "u3"}).svp, 3)
-- cfg overrides
l = R.lines(rows[1], ctx, {kill = 10, sec = 2, win = 0, mvp = 0})
eq("cfg kill", l.kill, 80); eq("cfg point", l.point, 280); eq("cfg win", l.win, 0); eq("cfg mvp", l.mvp, 0)
eq("cfg bad -> default", R.lines(rows[1], ctx, {kill = "x"}).kill, 400)
eq("bot lines", R.lines(rows[5], ctx).total, 0)
eq("bad row", R.lines(nil, ctx).total, 0)
-- compute
local res = R.compute(rows, "A", false)
eq("c mvp", res.mvp, "u1"); eq("c svp", res.svp, "u3")
eq("c u1", res.rows.u1 and res.rows.u1.total, 690)
eq("c u2", res.rows.u2 and res.rows.u2.total, 550 + 35 + 100)
eq("c bot absent", res.rows.bX, nil)
res = R.compute(rows, "B", true)
eq("cp mvp", res.mvp, "u3"); eq("cp u3", res.rows.u3.total, 0 + 12 + 10 + 5)
res = R.compute(nil, "A", false)
eq("c nil", res.mvp .. "|" .. res.svp, "|")
local n = 0 for _ in pairs(res.rows) do n += 1 end
eq("c nil rows", n, 0)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
