-- PracticeJobs.spec v1.0 (Mecha Dino Arena) — PracticeRules 1.1 bot jobs (plan docs/plans/BOT_JOBS_v1.0.md Task 1, MDA-429).
-- The 1.0 spec (PracticeRules.spec.luau) stays as it is.
-- Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.PracticeJobs_spec, clone + require); returns "PASS n" or "FAIL ...".
local DA = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
local src = DA and DA:FindFirstChild("PracticeRules")
if not src then return "FAIL require: ServerStorage.DinoArcade.PracticeRules missing" end
local ok, P = pcall(function() local c = src:Clone() c.Parent = src.Parent local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(P) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-6) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local V = Vector3.new

-- numbers
eq("version", P.VERSION, "1.1"); eq("bot species 7", #P.BOT_SPECIES, 7); eq("1.0 species 8", #P.SPECIES, 8)
local hasRex = false
for _, s in ipairs(P.BOT_SPECIES) do if s == "TRex" then hasRex = true end end
eq("no TRex", hasRex, false)
eq("hold fight", P.HOLD_FIGHT, 60); eq("self def", P.SELF_DEFENSE, 20); eq("duel leash", P.DUEL_LEASH, 250)
eq("guard ring", P.GUARD_RING, 45); eq("guard zone", P.GUARD_ZONE, 110); eq("guard leash", P.GUARD_LEASH, 90)
eq("team every", P.TEAM_EVERY, 1); eq("fill min", P.FILL_MIN, 5); eq("max on one", P.MAX_ON_ONE, 2)
eq("want open", P.HOLD_WANT_OPEN, 2); eq("want held", P.HOLD_WANT_HELD, 1); eq("run window", P.RUN_WINDOW, 10)

-- jobOf
eq("pachy hold", P.jobOf("Pachy"), "hold"); eq("teno hold", P.jobOf("Teno"), "hold")
eq("raptor duel", P.jobOf("Raptor"), "duel"); eq("herrera duel", P.jobOf("Herrera"), "duel"); eq("theri duel", P.jobOf("Therizino"), "duel")
eq("trex duel", P.jobOf("TRex"), "duel"); eq("dilo guard", P.jobOf("Dilo"), "guard"); eq("troodon guard", P.jobOf("Troodon"), "guard")
eq("unknown duel", P.jobOf("Nope"), "duel")

-- dealJobs
local function bot(id, sp, dPoint, dNext, prev)
	local b = {id = id, species = sp, alive = true, dPoint = dPoint, dNext = dNext}
	if prev then for k, v in pairs(prev) do b[k] = v end end
	return b
end
local mid = {held = false, humansOnPoint = 0, into = 20, pointTime = 60, now = 100}
-- a full team with 2 holders by dino: dino jobs, nothing filled
local team = {bot("a", "Pachy", 300), bot("b", "Teno", 400), bot("c", "Raptor", 200), bot("d", "Dilo", 250), bot("e", "Herrera", 500)}
local j = P.dealJobs(team, mid)
eq("dino a", j.a.job, "hold"); eq("dino b", j.b.job, "hold"); eq("dino c", j.c.job, "duel"); eq("dino d", j.d.job, "guard")
eq("dino why", j.a.why, "dino"); eq("dino e", j.e.job, "duel")
-- no holders, open point: guards first, nearest first, until 2
team = {bot("a", "Raptor", 100), bot("b", "Dilo", 400), bot("c", "Troodon", 300), bot("d", "Herrera", 50)}
j = P.dealJobs(team, mid)
eq("fill guard c", j.c.job, "hold"); eq("fill guard b", j.b.job, "hold"); eq("fill why", j.c.why, "fill: point")
eq("fill at", j.c.filledAt, 100); eq("duel kept a", j.a.job, "duel"); eq("duel kept d", j.d.job, "duel")
-- one guard only -> guard then the nearest duelist
team = {bot("a", "Raptor", 100), bot("b", "Dilo", 400), bot("d", "Herrera", 50)}
j = P.dealJobs(team, mid)
eq("guard then duel b", j.b.job, "hold"); eq("guard then duel d", j.d.job, "hold"); eq("far duel a", j.a.job, "duel")
-- held point wants 1
team = {bot("a", "Raptor", 100), bot("b", "Dilo", 400)}
j = P.dealJobs(team, {held = true, humansOnPoint = 0, into = 20, pointTime = 60, now = 100})
eq("held 1 fill b", j.b.job, "hold"); eq("held 1 keep a", j.a.job, "duel")
-- a human on the point counts
j = P.dealJobs(team, {held = true, humansOnPoint = 1, into = 20, pointTime = 60, now = 100})
eq("human counts a", j.a.job, "duel"); eq("human counts b", j.b.job, "guard")
-- release: filled holder older than 5 s, furthest first
team = {bot("a", "Pachy", 10), bot("b", "Dilo", 20, nil, {job = "hold", why = "fill: point", filledAt = 90}),
	bot("c", "Raptor", 30, nil, {job = "hold", why = "fill: point", filledAt = 90})}
j = P.dealJobs(team, {held = true, humansOnPoint = 0, into = 20, pointTime = 60, now = 100})
eq("release far c", j.c.job, "duel"); eq("release far b", j.b.job, "guard"); eq("dino holder kept", j.a.job, "hold")
eq("release why", j.c.why, "dino")
-- too soon to release (4 s)
team = {bot("a", "Pachy", 10), bot("b", "Dilo", 20, nil, {job = "hold", why = "fill: point", filledAt = 96})}
j = P.dealJobs(team, {held = true, humansOnPoint = 0, into = 20, pointTime = 60, now = 100})
eq("no release < 5 s", j.b.job, "hold")
j = P.dealJobs(team, {held = true, humansOnPoint = 0, into = 20, pointTime = 60, now = 101})
eq("release at 5 s", j.b.job, "guard")
-- dino holders over the want are never released
team = {bot("a", "Pachy", 10), bot("b", "Teno", 20)}
j = P.dealJobs(team, {held = true, humansOnPoint = 0, into = 20, pointTime = 60, now = 100})
eq("2 dino holders kept a", j.a.job, "hold"); eq("2 dino holders kept b", j.b.job, "hold")
-- dead bot -> dino job, not counted
team = {bot("a", "Pachy", 10), bot("b", "Teno", 20), bot("c", "Raptor", 100, nil, {job = "hold", why = "fill: point", filledAt = 50})}
team[2].alive = false
j = P.dealJobs(team, mid)
eq("dead -> dino", j.b.job, "hold"); eq("dead why", j.b.why, "dino")
eq("dead not counted: filled c stays", j.c.job, "hold")
team[3].alive = false
j = P.dealJobs(team, mid)
eq("dead filled -> dino", j.c.job, "duel")
-- runner in the last 10 s: nearest dino duelist to the next point
local late = {held = false, humansOnPoint = 0, into = 50, pointTime = 60, now = 100}
team = {bot("a", "Pachy", 10, 600), bot("b", "Teno", 20, 650), bot("c", "Raptor", 100, 500), bot("d", "Herrera", 200, 300), bot("e", "Dilo", 50, 100)}
j = P.dealJobs(team, late)
eq("runner d", j.d.job, "run"); eq("runner why", j.d.why, "run: next"); eq("guard not runner", j.e.job, "guard")
eq("window starts at 50", P.dealJobs(team, {held = false, humansOnPoint = 0, into = 49.9, pointTime = 60, now = 100}).d.job, "duel")
-- one runner only
team[4].job, team[4].why = "run", "run: next"
j = P.dealJobs(team, late)
eq("still one runner c", j.c.job, "duel"); eq("runner kept", j.d.job, "run")
-- out of the window -> back to dino job
j = P.dealJobs(team, mid)
eq("runner back", j.d.job, "duel"); eq("runner back why", j.d.why, "dino")
-- no duelist -> guard runs
team = {bot("a", "Pachy", 10, 600), bot("b", "Teno", 20, 650), bot("e", "Dilo", 50, 100), bot("f", "Troodon", 60, 80)}
j = P.dealJobs(team, late)
eq("guard runner f", j.f.job, "run"); eq("other guard e", j.e.job, "guard")
-- a filled duelist is not picked as runner (why ~= dino)
team = {bot("c", "Raptor", 10, 50, {job = "hold", why = "fill: point", filledAt = 99}), bot("d", "Herrera", 200, 300), bot("a", "Pachy", 5, 600)}
j = P.dealJobs(team, late)
eq("filled not runner", j.c.job, "hold"); eq("dino duel runs", j.d.job, "run")
-- empty
eq("empty", next(P.dealJobs({}, mid)), nil)
eq("nil bots", next(P.dealJobs(nil, mid)), nil)

-- canTarget
eq("self defence always", P.canTarget("run", {dist = 20, dPoint = 900, takenBy = 5}), true)
eq("run no fight", P.canTarget("run", {dist = 21, dPoint = 10}), false)
eq("hold in", P.canTarget("hold", {dist = 50, dPoint = 60}), true)
eq("hold out", P.canTarget("hold", {dist = 50, dPoint = 61}), false)
eq("cap", P.canTarget("guard", {dist = 50, dPoint = 10, takenBy = 2}), false)
eq("cap 1 ok", P.canTarget("guard", {dist = 50, dPoint = 10, takenBy = 1}), true)
eq("hold on point ignores cap", P.canTarget("hold", {dist = 50, dPoint = 10, takenBy = 3, onPoint = true}), true)
eq("hold off point cap", P.canTarget("hold", {dist = 50, dPoint = 10, takenBy = 2, onPoint = false}), false)
eq("duel free", P.canTarget("duel", {dist = 50, dPoint = 250, takenBy = 1, duelTaken = 0}), true)
eq("duel taken", P.canTarget("duel", {dist = 50, dPoint = 100, duelTaken = 1}), false)
eq("duel leash", P.canTarget("duel", {dist = 50, dPoint = 251}), false)
eq("guard zone", P.canTarget("guard", {dist = 50, dPoint = 110}), true)
eq("guard out", P.canTarget("guard", {dist = 50, dPoint = 111}), false)
eq("other job", P.canTarget("cap", {dist = 50, dPoint = 999}), true)
eq("nil info", P.canTarget("duel", nil), false)

-- jobGoal (home west of the centre)
local C, N, Hm = V(0, 0, 0), V(500, 0, 0), V(-300, 0, 0)
eq("goal hold = cap", P.jobGoal("hold", C, N, Hm), P.goalFor("cap", C, nil, Hm, 0, 60))
eq("goal duel = hunt", P.jobGoal("duel", C, N, Hm), P.goalFor("hunt", C, nil, Hm, 0, 60))
eq("goal guard", P.jobGoal("guard", C, N, Hm), V(-45, 0, 0))
eq("goal run", P.jobGoal("run", C, N, Hm), N)
eq("goal run no next", P.jobGoal("run", C, nil, Hm), C)
eq("goal guard no home", P.jobGoal("guard", C, N, nil), V(-45, 0, 0))
-- guardClamp
eq("clamp inside", P.guardClamp(V(50, 5, 0), C), V(50, 5, 0))
eq("clamp outside", P.guardClamp(V(200, 7, 0), C), V(90, 7, 0))

if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
