-- VictoryTitles.spec v1.0 (Mecha Dino Arena) — VictoryTitles 1.0 (plan docs/plans/VICTORY_TITLES_v1.0.md Task 1, MDA-553).
-- v1.1: VictoryTitles 1.1 (zero-kill leftovers get CARRIED; switch CFG.zeroKillCarried).
-- Run in Studio Edit (clones ServerStorage.DinoArcade.VictoryTitles); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("VictoryTitles")
if not src then return "FAIL require: VictoryTitles missing" end
local c = src:Clone() c.Parent = src.Parent
local okR, R = pcall(require, c)
c:Destroy()
if not okR then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want) if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end end
local function byId(list) local m = {} for i, e in ipairs(list) do m[e.id] = e.title; m["#" .. i] = e.id end return m end

eq("version", R.VERSION, "1.1")
eq("order", table.concat(R.ORDER, ","), "apex,king,unkill,medic,masher,extinct,carried,pacifist")
-- the mockup's sample team
local team = {
	{id = "u1", team = "A", k = 11, d = 2, pt = 102, heal = 120, ab = 31},
	{id = "u2", team = "A", k = 3, d = 3, pt = 125, heal = 0, ab = 18},
	{id = "u3", team = "A", k = 7, d = 0, pt = 70, heal = 0, ab = 24},
	{id = "u4", team = "A", k = 0, d = 2, pt = 12, heal = 0, ab = 9},
	{id = "u9", team = "B", k = 20, d = 0, pt = 300},
}
local m = byId(R.assign(team, "A"))
eq("apex", m.u1, "apex"); eq("king", m.u2, "king"); eq("unkill", m.u3, "unkill"); eq("carried", m.u4, "carried")
eq("loser not shown", m.u9, nil)
eq("show order 1", m["#1"], "u1"); eq("show order 4", m["#4"], "u4")
-- draw / bad
eq("draw", #R.assign(team, "draw"), 0)
eq("empty", #R.assign({}, "A"), 0)
eq("nil rows", #R.assign(nil, "A"), 0)
-- medic / masher / extinct / pacifist
local t2 = {
	{id = "a", team = "B", k = 2, d = 1, pt = 10, heal = 400, ab = 5},
	{id = "b", team = "B", k = 1, d = 6, pt = 5, heal = 0, ab = 3},
	{id = "c", team = "B", k = 1, d = 1, pt = 8, heal = 0, ab = 40},
	{id = "d", team = "B", k = 0, d = 1, pt = 20, heal = 0, ab = 0},
}
local m2 = byId(R.assign(t2, "B"))
eq("medic", m2.a, "medic"); eq("extinct", m2.b, "extinct"); eq("masher", m2.c, "masher"); eq("pacifist/carried d", m2.d == "carried" or m2.d == "pacifist", true)
-- everyone gets a title, no duplicates while titles are left
local seen, n = {}, 0
for _, e in ipairs(R.assign(t2, "B")) do n += 1; eq("unique " .. e.title, seen[e.title], nil); seen[e.title] = true end
eq("all 4", n, 4)
-- leftover: nobody earns anything -> closest
local m3 = byId(R.assign({{id = "x", team = "A", k = 2, d = 1, pt = 29}}, "A"))
eq("solo closest king", m3.x, "king")
-- max 4, bots count
local big = {}
for i = 1, 6 do table.insert(big, {id = "p" .. i, team = "A", k = i, d = 1, pt = 0, bot = i == 6}) end
local lb = R.assign(big, "A")
eq("max 4", #lb, 4); eq("bot first (most kills)", lb[1].id, "p6")
-- stat text
eq("stat apex", R.statText("apex", {k = 11}), "11 KILLS")
eq("stat king", R.statText("king", {pt = 125.2}), "2:05 ON POINT")
eq("stat unkill", R.statText("unkill", {k = 7, d = 0}), "0 DEATHS · 7 KILLS")
eq("stat carried", R.statText("carried", {k = 0, pt = 12}), "0 K · 0:12 ON POINT")
eq("len carried", R.LEN.carried, 6.4)
-- v1.1: zero-kill leftovers -> CARRIED (the 2026-11-16 Studio test: 4 winners, no stats at all)
local z = {{id = "z1", team = "A"}, {id = "z2", team = "A"}, {id = "z3", team = "A"}, {id = "z4", team = "A"}}
local nP, nC = 0, 0
for _, e in ipairs(R.assign(z, "A")) do if e.title == "pacifist" then nP += 1 elseif e.title == "carried" then nC += 1 end end
eq("zero: 1 pacifist", nP, 1); eq("zero: 3 carried", nC, 3)
local mz = byId(R.assign({{id = "q", team = "A", k = 0, d = 0, pt = 25, heal = 0, ab = 3}, {id = "w", team = "A", k = 0, d = 0, pt = 0}}, "A"))
eq("zero-kill leftover carried", mz.w == "carried" or mz.q == "carried", true)
eq("no apex at 0 kills", mz.q ~= "apex" and mz.w ~= "apex", true)
R.CFG.zeroKillCarried = false
local zoff = byId(R.assign({{id = "z1", team = "A"}, {id = "z2", team = "A"}}, "A"))
R.CFG.zeroKillCarried = true
eq("switch off = 1.0 closest (no carried)", zoff.z1 ~= "carried" and zoff.z2 ~= "carried", true)
eq("switch on: no unkill / apex at 0 kills", (function() local mm = byId(R.assign({{id = "z1", team = "A"}, {id = "z2", team = "A"}}, "A")) return mm.z1 ~= "unkill" and mm.z2 ~= "unkill" and mm.z1 ~= "apex" and mm.z2 ~= "apex" end)(), true)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
