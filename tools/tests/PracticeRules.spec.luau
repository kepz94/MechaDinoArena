-- PracticeRules.spec v1.0 (Mecha Dino Arena) — PracticeRules 1.0 (plan docs/plans/PRACTICE_MATCH_v1.0.md Task 0, MDA-404).
-- Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.PracticeRules_spec): clone + require
-- ServerStorage.DinoArcade.PracticeRules and .SkillTree; returns "PASS n" or "FAIL ...".
local DA = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
local function load(name)
	local src = DA and DA:FindFirstChild(name)
	if not src then return nil, "missing " .. name end
	local ok, m = pcall(function() local c = src:Clone() c.Parent = src.Parent local r = require(c) c:Destroy() return r end)
	if not ok then return nil, tostring(m) end
	return m
end
local P, e1 = load("PracticeRules")
if not P then return "FAIL require PracticeRules: " .. tostring(e1) end
local T, e2 = load("SkillTree")
if not T then return "FAIL require SkillTree: " .. tostring(e2) end

local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-6) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end

-- numbers
eq("size", P.SIZE, 5); eq("auto start", P.AUTO_START, 20); eq("cone", P.CONE, 120); eq("give up", P.CLIMB_GIVE_UP, 25)
eq("bot level", P.BOT_LEVEL, 30); eq("xp mul", P.XP_MUL, 0.1); eq("species", #P.SPECIES, 8); eq("names >= 40", #P.NAMES >= 40, true)
eq("easy react", P.DIFF.Easy.react, 0.8); eq("normal sight", P.DIFF.Normal.sight, 90); eq("hard abil", P.DIFF.Hard.abil, 0.85)
eq("easy no retreat", P.DIFF.Easy.retreat, false); eq("hard aim", P.DIFF.Hard.aimErr, 3)
eq("bot live empty in phase 1", next(P.BOT_LIVE), nil)
local seenNames = {}
local dupe = false
for _, n in ipairs(P.NAMES) do if seenNames[n] then dupe = true end seenNames[n] = true end
eq("names unique", dupe, false)

-- rollBot: own-dino paths only, owned buttons only, all points spent or nothing buyable
local rng = Random.new(7)
for _, sp in ipairs(P.SPECIES) do
	local used = {}
	local b = P.rollBot(rng, used, T, 30, sp)
	eq("roll species " .. sp, b.species, sp)
	eq("roll name used " .. sp, used[b.name], true)
	local bad = false
	for id, n in pairs(b.steps) do if n > 0 and not T.seesPath(id, sp) then bad = true end end
	eq("own paths only " .. sp, bad, false)
	eq("spent <= points " .. sp, T.spent(b.steps, sp) <= T.pointsOf(30), true)
	local badSlot, slots = false, 0
	for n = 1, T.SLOTS do
		local id = b.loadout[n]
		if id then
			slots += 1
			if not (T.BUTTONS[id] and (b.steps[id] or 0) >= 1 and T.seesPath(id, sp)) then badSlot = true end
		end
	end
	eq("slots owned buttons " .. sp, badSlot, false)
	if sp == "TRex" then eq("trex loadout empty", slots, 0) else eq("loadout filled " .. sp, slots >= 1, true) end
end
-- names never repeat in a lobby of 10
local used = {}
local names = {}
local r2 = Random.new(3)
for _ = 1, 10 do local b = P.rollBot(r2, used, T, 30) names[b.name] = (names[b.name] or 0) + 1 end
local rep = false
for _, c in pairs(names) do if c > 1 then rep = true end end
eq("10 bots unique names", rep, false)
eq("random species valid", table.find(P.SPECIES, P.rollBot(r2, {}, T, 30).species) ~= nil, true)

-- pickSide
eq("side smaller A", P.pickSide(1, 2, 0, 0), "A"); eq("side smaller B", P.pickSide(3, 2, 0, 0), "B")
eq("side tie behind", P.pickSide(2, 2, 10, 50), "A"); eq("side tie behind B", P.pickSide(2, 2, 50, 10), "B")
eq("side tie A", P.pickSide(2, 2, 5, 5), "A")

-- fillRoster
local bots = {}
for i = 1, 10 do bots[i] = {name = "b" .. i} end
local r = P.fillRoster({}, bots, 5)
eq("0 humans A", #r.A, 5); eq("0 humans B", #r.B, 5); eq("0 humans all bots", r.A[1].kind, "bot")
r = P.fillRoster({{id = 1, want = "B"}}, bots, 5)
eq("1 human on B", r.B[1].kind, "human"); eq("1 human B size", #r.B, 5); eq("A still 5 bots", #r.A, 5)
local h = {}
for i = 1, 6 do h[i] = {id = i, want = "A"} end
r = P.fillRoster(h, bots, 5)
eq("6 want A: 5 on A", #r.A, 5); eq("6th moved to B", r.B[1].kind, "human"); eq("6th moved flag", r.moved[6], true)
h = {}
for i = 1, 11 do h[i] = {id = i, want = "auto"} end
r = P.fillRoster(h, bots, 5)
eq("11 humans: 1 refused", r.refused[11], "full"); eq("11 humans: A full of humans", r.A[5].kind, "human")
r = P.fillRoster({{id = 1, want = "auto"}, {id = 2, want = "auto"}}, bots, 5)
eq("auto 1 -> A", r.A[1].id, 1); eq("auto 2 -> B", r.B[1].id, 2)
r = P.fillRoster({}, {{name = "x"}}, 5)
eq("not enough bots: A has 1", #r.A, 1); eq("not enough bots: B empty", #r.B, 0)

-- assignRoles
local roles = P.assignRoles(5, Random.new(1))
local count = {}
for _, x in ipairs(roles) do count[x] = (count[x] or 0) + 1 end
eq("5 roles", #roles, 5); eq("2 cap", count.cap, 2); eq("1 def", count.def, 1); eq("1 hunt", count.hunt, 1); eq("1 esc", count.esc, 1)
roles = P.assignRoles(1, Random.new(1)); eq("1 role cap", roles[1], "cap")
roles = P.assignRoles(3, Random.new(1)); count = {}
for _, x in ipairs(roles) do count[x] = (count[x] or 0) + 1 end
eq("3 roles cap def hunt", (count.cap == 1 and count.def == 1 and count.hunt == 1), true)
eq("0 roles", #P.assignRoles(0, Random.new(1)), 0)

-- scoreTarget
eq("score plain", P.scoreTarget(50, false, 1), 80); eq("score on point", P.scoreTarget(50, true, 1), 20)
eq("weak preferred", P.scoreTarget(50, false, 0.2) < P.scoreTarget(50, false, 1), true)

-- shouldRetreat
eq("retreat", P.shouldRetreat(0.2, 0, 2, P.DIFF.Normal), true)
eq("no retreat even", P.shouldRetreat(0.2, 1, 2, P.DIFF.Normal), false)
eq("no retreat healthy", P.shouldRetreat(0.5, 0, 3, P.DIFF.Normal), false)
eq("easy never", P.shouldRetreat(0.1, 0, 4, P.DIFF.Easy), false)

-- goalFor (home = west of the centre)
local c, nx = Vector3.new(100, 10, 0), Vector3.new(500, 10, 0)
local home = Vector3.new(-200, 10, 0)
local g = P.goalFor("cap", c, nx, home, 5, 60); eq("cap near centre", (g - c).Magnitude, 8, 1e-6); eq("cap home side", g.X < c.X, true)
g = P.goalFor("def", c, nx, home, 5, 60); eq("def inside the point", (Vector3.new(g.X, 0, g.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude <= 45, true)
g = P.goalFor("hunt", c, nx, home, 5, 60); eq("hunt past the centre", g.X > c.X, true)
g = P.goalFor("esc", c, nx, home, 49.9, 60); eq("esc stays before 50", (g - nx).Magnitude > 1, true)
g = P.goalFor("esc", c, nx, home, 50.1, 60); eq("esc rotates after 50", g, nx)
g = P.goalFor("cap", c, nx, c, 5, 60); eq("home on centre -> default west", g.X < c.X, true)

-- wantsAttack
eq("attack ok", P.wantsAttack(0.6, 4, 5, 0, P.DIFF.Normal), true)
eq("too soon", P.wantsAttack(0.4, 4, 5, 0, P.DIFF.Normal), false)
eq("too far", P.wantsAttack(1, 6, 5, 0, P.DIFF.Normal), false)
eq("cooldown", P.wantsAttack(1, 4, 5, 0.2, P.DIFF.Normal), false)

-- aimError within the difficulty
local within = true
local r3 = Random.new(5)
for _ = 1, 50 do local a = P.aimError(r3, P.DIFF.Hard) if math.abs(a) > 3 then within = false end end
eq("aim error within 3", within, true)

-- diff lookup
eq("diffOf bad -> Normal", P.diffOf("nope"), P.DIFF.Normal); eq("diffOf Hard", P.diffOf("Hard"), P.DIFF.Hard)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
