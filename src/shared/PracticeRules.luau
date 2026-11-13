-- PracticeRules v1.0 (Mecha Dino Arena) — every practice-match number and bot decision, pure (no Instance writes). MDA-404,
-- plan docs/plans/PRACTICE_MATCH_v1.0.md Task 0, ADR-010, mockup docs/mockups/practice_match_v0.1.html (v0.2).
-- Kepu 2026-11-10: the Sandbox is a Hardpoint practice match vs bots "for now"; bots with random dinos and loadouts that
--   play the objective, use their abilities and fight each other; direction A (lobby, 5v5); 10% XP (like CoD Mobile); the
--   lobby shows only the parts that work for bots.
-- Lives in ServerStorage.DinoArcade.PracticeRules; PracticeServer 1.0 clones it to ReplicatedStorage.PracticeShared.
-- Numbers: SIZE 5 per team, AUTO_START 20 s, CONE 120 degrees of view, CLIMB_GIVE_UP 25 s (then "hold below"), BOT_LEVEL 30
--   (its skill points spent at random), XP_MUL 0.1. DIFF per difficulty: react (s before the first attack on a new target),
--   sight (studs), abil (chance a ready ability is used, Phase 2+), retreat (backs off when hurt and outnumbered), aimErr
--   (degrees). BOT_LIVE = part ids whose bot entrance exists (Phase 1: none).
-- API:
--   rollBot(rng: Random, used: {[name] = true}, SkillTree, level?, species?) -> {name, species, steps, loadout}
--   pickSide(nA, nB, scoreA, scoreB) -> "A" | "B"        fillRoster(humans, bots, size) -> {A, B, moved, refused}
--   assignRoles(n, rng) -> {role}                        scoreTarget(dist, onPoint, hpFrac) -> number (lower = better)
--   shouldRetreat(hpFrac, mates, foes, diff) -> bool     goalFor(role, centre, nextCentre, home, into, pointTime) -> Vector3
--   wantsAttack(seenFor, dist, reach, cdLeft, diff) -> bool   aimError(rng, diff) -> degrees   diffOf(name) -> DIFF row
-- v1.1 (bot jobs, MDA-429, plan docs/plans/BOT_JOBS_v1.0.md Task 1, research docs/research/BOT_PLAYSTYLE_v0.1.md; Kepu
--   2026-11-11 "the pachy play objective while other Dino's look for 1v1 matchups", picks "C" (preferred job by dino, the team
--   brain changes it when the team needs it) and "1" (bots never pick the T-Rex)). Added, 1.0 untouched:
--   BOT_SPECIES = SPECIES without TRex (PracticeServer passes one to rollBot).
--   Jobs: JOB_OF Pachy / Teno = "hold", Raptor / Herrera / Therizino / TRex = "duel", Dilo / Troodon = "guard"; "run" is given
--     by the team brain only. jobOf(species) -> job (unknown -> "duel").
--   dealJobs(bots, ctx) -> {[id] = {job, why, filledAt}}; bots = {{id, species, alive, dPoint, dNext, job?, why?, filledAt?}} in
--     a fixed order (ties go to the first); ctx = {held, humansOnPoint, into, pointTime, now}. Rules in order:
--     1. a dead bot or one with no job -> its dino job (why "dino").
--     2. runner: while into >= pointTime - RUN_WINDOW (10) and no living "run", the living bot on a dino "duel" job (else on
--        a dino "guard" job) nearest the next point (dNext) -> "run" (why "run: next"); outside that window every "run" -> its
--        dino job.
--     3. holders: wanted = held and HOLD_WANT_HELD (1) or HOLD_WANT_OPEN (2); have = living "hold" + humansOnPoint. have <
--        wanted -> living non-hold, non-run bots, guards before duelists, nearest the point (dPoint) first -> "hold" (why
--        "fill: point", filledAt = now) until have = wanted. have > wanted -> filled holders whose filledAt is FILL_MIN (5) s
--        or more ago, furthest from the point first -> their dino job, until have = wanted. Dino holders are never released.
--   canTarget(job, info) -> bool; info = {dist (from the bot), dPoint (target from the point centre), onPoint, takenBy (other
--     teammates targeting it), duelTaken (other duelists on it)}: dist <= SELF_DEFENSE (20) -> true always; takenBy >=
--     MAX_ON_ONE (2) -> false unless job "hold" and onPoint; then hold: dPoint <= HOLD_FIGHT (60); duel: duelTaken < 1 and
--     dPoint <= DUEL_LEASH (250); guard: dPoint <= GUARD_ZONE (110); run: false (only self-defence); other: true.
--   jobGoal(job, centre, nextCentre, home) -> Vector3: hold = the 1.0 "cap" goal, duel = the 1.0 "hunt" goal, guard = centre +
--     GUARD_RING (45) toward home, run = nextCentre (else centre). GUARD_LEASH (90): a guard's walk is kept within this of the
--     point (guardClamp(pos, centre) -> Vector3).
-- v1.2 (Bots v2, MDA-466, plan docs/plans/BOTS_V2_v1.0.md T1; Kepu 2026-11-11 20:39 "mixed at all times. Some really hard bots and
--   some easy ones", picks "1 Elite · 1 Hard · 2 Normal · 1 Easy" re-rolled each respawn). Added, 1.0 / 1.1 untouched:
--   TIERS (rows like DIFF plus: strafe (orbit / side-step in a fight), dodge (side-jump when an enemy attack starts near),
--     kite (ranged dinos keep their distance), focusLow (prefer low-HP targets), lead (aim at where the target will be),
--     combo, loseTrack (s the target is forgotten after it leaves sight), speedMul, abilDelay (s before a wanted ability)):
--     Easy / Normal / Hard / Elite. tierOf(name) -> row (unknown -> Normal).
--   TEAM_MIX = {Elite 1, Hard 1, Normal 2, Easy 1}; MIX_ORDER = Elite, Hard, Normal, Easy, Normal (sizes over 5 repeat it).
--     mixFor(size) -> {tier name} (the first size of MIX_ORDER, repeated). dealTiers(size, rng) -> mixFor(size) shuffled.
--     respawnTier(living, size, rng) -> a tier the team is missing (mixFor(size) minus the living bots' tiers, random among the
--     missing), else a random one of mixFor(size). living = {tier name}.
--   slowMul(attrs, now) -> the product of every attrs["SlowMul_<x>"] whose attrs["SlowUntil_<x>"] > now, clamped to
--     [SLOW_FLOOR (0.25), 1] (no slow -> 1). Non-number values are skipped.
--   abilityWant(kind, ctx) -> 0..1 (0 = no). ctx: {hasTarget, gap (to the target, studs between bodies), dist, minR, maxR (the
--     part's range), radius (area parts), hpFrac, foesNear (within 30), matesNear, mateLow (a mate under 50% within 60),
--     recentlyHit (hurt in the last 2 s), swimming, stuckFor (s), onPoint, goalDist}. Kinds and rules (first match wins):
--     mobility: swimming 0.9; stuckFor >= 1.5 -> 0.9; hpFrac < 0.3 and foesNear > matesNear -> 0.85 (escape); hasTarget and
--       35 < gap <= maxR (else 140) -> 0.8; no target and goalDist > 120 -> 0.5; else 0.
--     ranged: hasTarget and minR <= dist <= maxR -> 0.8; else 0.
--     melee / control: hasTarget and gap <= maxR -> 0.8 (control 0.75); else 0.
--     aoe: foesNear >= 1 and (not hasTarget or gap <= radius) -> min(1, 0.6 + 0.15 x foesNear); else 0.
--     defend: hpFrac < 0.6 and recentlyHit -> 0.8; foesNear >= 2 -> 0.6; else 0.
--     heal: hpFrac < 0.5 -> 0.8; mateLow -> 0.7; else 0.
--     buff: hasTarget and gap <= 20 -> 0.7; else 0.
--     stealth: hpFrac < 0.4 and foesNear >= 1 -> 0.8; hasTarget and 40 <= gap <= 90 -> 0.5; else 0.
--     zone / trap: onPoint and foesNear >= 1 -> 0.7; hasTarget and gap <= 30 -> 0.55; else 0.
--     sense: no target and goalDist <= 200 -> 0.4; else 0.
--     unknown kind -> 0.
--   pickLoadout(liveIds, mobilityIds, slots, rng) -> {id}: one mobility id first (random among those in liveIds), then the
--     rest of liveIds shuffled, at most slots.
-- v1.3 (pre-game, MDA-483, plan docs/plans/PREGAME_LINEUP_v1.0.md T3, mockup docs/mockups/pregame_v0.4.html; Kepu 2026-11-12:
--   bots matches 4v4, "2 elite 2 hard", on both teams):
--   ELITE_MIX (true; PracticeServer 1.9 sets it from its attribute PrEliteMixEnabled): mixFor / respawnTier deal from
--     ELITE_ORDER = Elite, Hard, Elite, Hard (sizes over 4 repeat it: 4 bots = 2 Elite + 2 Hard, your team's 3 bots = Elite,
--     Hard, Elite) instead of MIX_ORDER. false = 1.2 exactly.
--   Pre-game timings: PG_LINEUP 30 (s the lineup runs), PG_READY 5 (s left once every human is ready), PG_INTRO 8 (s of
--     intros before the match). readyCut(endsAt, now) -> min(endsAt, now + PG_READY) (never later than endsAt; bad input ->
--     endsAt).
local M = {}
M.VERSION = "1.0"
M.VERSION = "1.1" -- v1.1 bot jobs
M.VERSION = "1.2" -- v1.2 Bots v2: tiers, mix, slowMul, abilityWant
M.VERSION = "1.3" -- v1.3 pre-game: 2 Elite + 2 Hard, timings

M.SIZE = 5
M.AUTO_START = 20
M.CONE = 120
M.CLIMB_GIVE_UP = 25
M.BOT_LEVEL = 30
M.XP_MUL = 0.1
M.SPECIES = {"Raptor", "TRex", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}
M.NAMES = {"Fang", "Mako", "Rook", "Ember", "Vex", "Grit", "Talon", "Nova", "Bolt", "Sable", "Rex", "Dash", "Quill", "Moss",
	"Jinx", "Onyx", "Pike", "Rusty", "Zed", "Kiwi", "Blaze", "Clank", "Drift", "Echo", "Flint", "Gizmo", "Hex", "Ivy",
	"Jolt", "Knox", "Lumen", "Mortar", "Nyx", "Orbit", "Pixel", "Rivet", "Scrap", "Torque", "Volt", "Wrench", "Yuki", "Zap"}
M.DIFF = {
	Easy = {name = "Easy", react = 0.8, sight = 70, abil = 0.25, retreat = false, aimErr = 14},
	Normal = {name = "Normal", react = 0.5, sight = 90, abil = 0.5, retreat = true, aimErr = 8},
	Hard = {name = "Hard", react = 0.3, sight = 110, abil = 0.85, retreat = true, aimErr = 3},
}
M.BOT_LIVE = {}
local ROLES5 = {"cap", "cap", "def", "hunt", "esc"}
local ROLE_PRIORITY = {"cap", "def", "hunt", "cap", "esc"}

function M.diffOf(name)
	return M.DIFF[name] or M.DIFF.Normal
end

local function shuffle(rng, list)
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- a bot: species (given or random), an unused name, its level's points spent at random with its button parts first
function M.rollBot(rng, used, SkillTree, level, species)
	used = used or {}
	species = species or M.SPECIES[rng:NextInteger(1, #M.SPECIES)]
	local free = {}
	for _, n in ipairs(M.NAMES) do if not used[n] then table.insert(free, n) end end
	local name
	if #free > 0 then
		name = free[rng:NextInteger(1, #free)]
	else
		local k = 2
		repeat name = M.NAMES[rng:NextInteger(1, #M.NAMES)] .. k; k += 1 until not used[name]
	end
	used[name] = true
	local points = SkillTree.pointsOf(level or M.BOT_LEVEL)
	local steps = SkillTree.sanitize({}, species)
	-- the dino's live button parts, random order; the first SLOTS get step 1 first
	local buttons = {}
	for id in pairs(SkillTree.BUTTONS) do
		local p = SkillTree.PATHS[id]
		if p and SkillTree.LIVE_MECH[id] and not p.soon and SkillTree.seesPath(p, species) then table.insert(buttons, id) end
	end
	table.sort(buttons)
	buttons = shuffle(rng, buttons)
	local slotted = {}
	for _, id in ipairs(buttons) do
		if #slotted >= SkillTree.SLOTS then break end
		local new = SkillTree.buy(steps, id, points, species)
		if new then steps = new; table.insert(slotted, id) end
	end
	-- the rest at random over every path it may buy
	local ids = {}
	for _, id in ipairs(SkillTree.PATH_ORDER) do
		if SkillTree.seesPath(id, species) then table.insert(ids, id) end
	end
	for _ = 1, 200 do
		local can = {}
		for _, id in ipairs(ids) do
			if SkillTree.canBuy(steps, id, points, species) then table.insert(can, id) end
		end
		if #can == 0 then break end
		steps = SkillTree.buy(steps, can[rng:NextInteger(1, #can)], points, species)
	end
	local loadout = {}
	for n = 1, SkillTree.SLOTS do loadout[n] = false end
	for n, id in ipairs(slotted) do
		local out = SkillTree.setSlot(loadout, steps, n, id, species)
		if out then loadout = out end
	end
	return {name = name, species = species, steps = steps, loadout = loadout}
end

function M.pickSide(nA, nB, scoreA, scoreB)
	nA, nB = tonumber(nA) or 0, tonumber(nB) or 0
	if nA ~= nB then return nA < nB and "A" or "B" end
	scoreA, scoreB = tonumber(scoreA) or 0, tonumber(scoreB) or 0
	if scoreA ~= scoreB then return scoreA < scoreB and "A" or "B" end
	return "A"
end

-- humans: {{id, want = "A" | "B" | "auto"}} in join order; bots: {bot spec}. A human whose side is full goes to the other
-- side (moved[id] = true); with both full: refused[id] = "full". Bots fill A then B up to size.
function M.fillRoster(humans, bots, size)
	size = size or M.SIZE
	local out = {A = {}, B = {}, moved = {}, refused = {}}
	for _, h in ipairs(humans or {}) do
		local want = h.want
		if want ~= "A" and want ~= "B" then want = M.pickSide(#out.A, #out.B, 0, 0) end
		local other = want == "A" and "B" or "A"
		if #out[want] < size then
			table.insert(out[want], {kind = "human", id = h.id})
		elseif #out[other] < size then
			table.insert(out[other], {kind = "human", id = h.id})
			out.moved[h.id] = true
		else
			out.refused[h.id] = "full"
		end
	end
	local i = 1
	for _, side in ipairs({"A", "B"}) do
		while #out[side] < size and bots and bots[i] do
			table.insert(out[side], {kind = "bot", bot = bots[i]})
			i += 1
		end
	end
	return out
end

function M.assignRoles(n, rng)
	n = math.max(0, math.floor(tonumber(n) or 0))
	local list = {}
	if n >= 5 then
		list = table.clone(ROLES5)
		for _ = 6, n do table.insert(list, "cap") end
	else
		for i = 1, n do list[i] = ROLE_PRIORITY[i] end
	end
	return shuffle(rng, list)
end

function M.scoreTarget(dist, onPoint, hpFrac)
	return (tonumber(dist) or 0) - (onPoint and 60 or 0) + (tonumber(hpFrac) or 1) * 30
end

function M.shouldRetreat(hpFrac, mates, foes, diff)
	return diff ~= nil and diff.retreat == true and (tonumber(hpFrac) or 1) < 0.3 and (tonumber(foes) or 0) > (tonumber(mates) or 0) + 1
end

-- v1.1: bot jobs (see the header)
M.BOT_SPECIES = {"Raptor", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}
M.JOB_OF = {Pachy = "hold", Teno = "hold", Raptor = "duel", Herrera = "duel", Therizino = "duel", TRex = "duel",
	Dilo = "guard", Troodon = "guard"}
M.HOLD_FIGHT = 60
M.SELF_DEFENSE = 20
M.DUEL_LEASH = 250
M.GUARD_RING = 45
M.GUARD_ZONE = 110
M.GUARD_LEASH = 90
M.TEAM_EVERY = 1
M.FILL_MIN = 5
M.MAX_ON_ONE = 2
M.HOLD_WANT_OPEN = 2
M.HOLD_WANT_HELD = 1
M.RUN_WINDOW = 10

function M.jobOf(species)
	return M.JOB_OF[species] or "duel"
end

function M.dealJobs(bots, ctx)
	ctx = ctx or {}
	local now = tonumber(ctx.now) or 0
	local out, order = {}, {}
	for _, b in ipairs(bots or {}) do
		local dino = M.jobOf(b.species)
		local e = {job = b.job, why = b.why, filledAt = b.filledAt}
		if not b.alive or not e.job then e = {job = dino, why = "dino"} end
		out[b.id] = e
		table.insert(order, {b = b, e = e, dino = dino})
	end
	-- 2. runner
	local window = (tonumber(ctx.into) or 0) >= (tonumber(ctx.pointTime) or 60) - M.RUN_WINDOW
	if window then
		local hasRun = false
		for _, o in ipairs(order) do if o.b.alive and o.e.job == "run" then hasRun = true end end
		if not hasRun then
			local pick
			for _, kind in ipairs({"duel", "guard"}) do
				for _, o in ipairs(order) do
					if o.b.alive and o.e.job == kind and o.e.why == "dino"
						and (not pick or (tonumber(o.b.dNext) or math.huge) < (tonumber(pick.b.dNext) or math.huge)) then pick = o end
				end
				if pick then break end
			end
			if pick then out[pick.b.id] = {job = "run", why = "run: next"} pick.e = out[pick.b.id] end
		end
	else
		for _, o in ipairs(order) do
			if o.e.job == "run" then out[o.b.id] = {job = o.dino, why = "dino"} o.e = out[o.b.id] end
		end
	end
	-- 3. holders
	local wanted = ctx.held and M.HOLD_WANT_HELD or M.HOLD_WANT_OPEN
	local have = tonumber(ctx.humansOnPoint) or 0
	for _, o in ipairs(order) do if o.b.alive and o.e.job == "hold" then have += 1 end end
	if have < wanted then
		for _, kind in ipairs({"guard", "duel"}) do
			while have < wanted do
				local pick
				for _, o in ipairs(order) do
					if o.b.alive and o.e.job == kind
						and (not pick or (tonumber(o.b.dPoint) or math.huge) < (tonumber(pick.b.dPoint) or math.huge)) then pick = o end
				end
				if not pick then break end
				out[pick.b.id] = {job = "hold", why = "fill: point", filledAt = now}
				pick.e = out[pick.b.id]
				have += 1
			end
		end
	elseif have > wanted then
		while have > wanted do
			local pick
			for _, o in ipairs(order) do
				if o.b.alive and o.e.job == "hold" and o.e.why == "fill: point" and now - (tonumber(o.e.filledAt) or now) >= M.FILL_MIN
					and (not pick or (tonumber(o.b.dPoint) or 0) > (tonumber(pick.b.dPoint) or 0)) then pick = o end
			end
			if not pick then break end
			out[pick.b.id] = {job = pick.dino, why = "dino"}
			pick.e = out[pick.b.id]
			have -= 1
		end
	end
	return out
end

function M.canTarget(job, info)
	info = info or {}
	local dist = tonumber(info.dist) or math.huge
	if dist <= M.SELF_DEFENSE then return true end
	local dPoint = tonumber(info.dPoint) or math.huge
	if (tonumber(info.takenBy) or 0) >= M.MAX_ON_ONE and not (job == "hold" and info.onPoint == true) then return false end
	if job == "hold" then return dPoint <= M.HOLD_FIGHT end
	if job == "duel" then return (tonumber(info.duelTaken) or 0) < 1 and dPoint <= M.DUEL_LEASH end
	if job == "guard" then return dPoint <= M.GUARD_ZONE end
	if job == "run" then return false end
	return true
end

function M.jobGoal(job, centre, nextCentre, home)
	if job == "run" then return nextCentre or centre end
	if job == "guard" then
		local d = Vector3.new((home or centre).X - centre.X, 0, (home or centre).Z - centre.Z)
		if d.Magnitude < 1e-3 then d = Vector3.new(-1, 0, 0) else d = d.Unit end
		return centre + d * M.GUARD_RING
	end
	return M.goalFor(job == "duel" and "hunt" or "cap", centre, nil, home, 0, 60)
end

function M.guardClamp(pos, centre)
	local d = Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z)
	if d.Magnitude <= M.GUARD_LEASH then return pos end
	local q = centre + d.Unit * M.GUARD_LEASH
	return Vector3.new(q.X, pos.Y, q.Z)
end

-- home = where the bot's team is (its own spot or the team's average); the goal is placed relative to it
function M.goalFor(role, centre, nextCentre, home, into, pointTime)
	if role == "esc" and nextCentre and (tonumber(into) or 0) > (tonumber(pointTime) or 60) - 10 then return nextCentre end
	local d = Vector3.new((home or centre).X - centre.X, 0, (home or centre).Z - centre.Z)
	if d.Magnitude < 1e-3 then d = Vector3.new(-1, 0, 0) else d = d.Unit end
	local perp = Vector3.new(-d.Z, 0, d.X)
	if role == "def" then
		return centre + d * 35
	elseif role == "hunt" then
		return centre - d * 120 + perp * 80
	elseif role == "esc" then
		return centre + d * 20 + perp * 25
	end
	return centre + d * 8
end

function M.wantsAttack(seenFor, dist, reach, cdLeft, diff)
	return diff ~= nil and (tonumber(seenFor) or 0) >= diff.react and (tonumber(dist) or math.huge) <= (tonumber(reach) or 0)
		and (tonumber(cdLeft) or 0) <= 0
end

function M.aimError(rng, diff)
	local e = diff and diff.aimErr or 8
	return (rng:NextNumber() * 2 - 1) * e
end

-- ---------- v1.2: Bots v2 (see the header) ----------
M.TIERS = {
	Easy = {name = "Easy", react = 0.9, sight = 75, abil = 0.15, retreat = false, aimErr = 16, strafe = false, dodge = false,
		kite = false, focusLow = false, lead = false, combo = false, loseTrack = 2, speedMul = 0.92, abilDelay = 0.8},
	Normal = {name = "Normal", react = 0.5, sight = 95, abil = 0.45, retreat = true, aimErr = 8, strafe = false, dodge = false,
		kite = true, focusLow = false, lead = false, combo = false, loseTrack = 3, speedMul = 0.95, abilDelay = 0.5},
	Hard = {name = "Hard", react = 0.3, sight = 115, abil = 0.75, retreat = true, aimErr = 4, strafe = true, dodge = true,
		kite = true, focusLow = true, lead = false, combo = false, loseTrack = 4, speedMul = 0.97, abilDelay = 0.35},
	Elite = {name = "Elite", react = 0.18, sight = 130, abil = 0.95, retreat = true, aimErr = 2, strafe = true, dodge = true,
		kite = true, focusLow = true, lead = true, combo = true, loseTrack = 5, speedMul = 1.0, abilDelay = 0.2},
}
M.TEAM_MIX = {Elite = 1, Hard = 1, Normal = 2, Easy = 1}
M.MIX_ORDER = {"Elite", "Hard", "Normal", "Easy", "Normal"}
M.SLOW_FLOOR = 0.25
M.ELITE_MIX = true -- v1.3
M.ELITE_ORDER = {"Elite", "Hard", "Elite", "Hard"} -- v1.3
M.PG_LINEUP = 30 -- v1.3
M.PG_READY = 5 -- v1.3
M.PG_INTRO = 8 -- v1.3
local function mixOrder() -- v1.3
	return (M.ELITE_MIX == true and M.ELITE_ORDER) or M.MIX_ORDER
end

function M.readyCut(endsAt, now) -- v1.3
	endsAt, now = tonumber(endsAt), tonumber(now)
	if not endsAt then return endsAt end
	if not now then return endsAt end
	return math.min(endsAt, now + M.PG_READY)
end

function M.tierOf(name)
	return M.TIERS[name] or M.TIERS.Normal
end

function M.mixFor(size)
	local out = {}
	local order = mixOrder() -- v1.3
	for i = 1, math.max(0, tonumber(size) or 0) do out[i] = order[(i - 1) % #order + 1] end
	return out
end

function M.dealTiers(size, rng)
	return shuffle(rng, M.mixFor(size))
end

function M.respawnTier(living, size, rng)
	local want = {}
	for _, t in ipairs(M.mixFor(size)) do want[t] = (want[t] or 0) + 1 end
	for _, t in ipairs(type(living) == "table" and living or {}) do
		if want[t] then want[t] -= 1 end
	end
	local missing = {}
	for _, t in ipairs(mixOrder()) do -- v1.3
		if (want[t] or 0) > 0 then
			table.insert(missing, t)
			want[t] -= 1
		end
	end
	if #missing > 0 then return missing[rng:NextInteger(1, #missing)] end
	local all = M.mixFor(size)
	if #all == 0 then return "Normal" end
	return all[rng:NextInteger(1, #all)]
end

function M.slowMul(attrs, now)
	local mul = 1
	if type(attrs) ~= "table" then return 1 end
	for k, v in pairs(attrs) do
		if type(k) == "string" and string.sub(k, 1, 8) == "SlowMul_" and type(v) == "number" and v == v then
			local untilT = attrs["SlowUntil_" .. string.sub(k, 9)]
			if type(untilT) == "number" and untilT > (tonumber(now) or 0) then mul *= math.clamp(v, 0, 1) end
		end
	end
	return math.clamp(mul, M.SLOW_FLOOR, 1)
end

function M.abilityWant(kind, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local gap, dist = tonumber(ctx.gap) or math.huge, tonumber(ctx.dist) or math.huge
	local hp = tonumber(ctx.hpFrac) or 1
	local foes, mates = tonumber(ctx.foesNear) or 0, tonumber(ctx.matesNear) or 0
	local has = ctx.hasTarget == true
	if kind == "mobility" then
		if ctx.swimming == true then return 0.9 end
		if (tonumber(ctx.stuckFor) or 0) >= 1.5 then return 0.9 end
		if hp < 0.3 and foes > mates then return 0.85 end
		if has and gap > 35 and gap <= (tonumber(ctx.maxR) or 140) then return 0.8 end
		if not has and (tonumber(ctx.goalDist) or 0) > 120 then return 0.5 end
		return 0
	elseif kind == "ranged" then
		if has and dist >= (tonumber(ctx.minR) or 0) and dist <= (tonumber(ctx.maxR) or 0) then return 0.8 end
		return 0
	elseif kind == "melee" or kind == "control" then
		if has and gap <= (tonumber(ctx.maxR) or 0) then return kind == "control" and 0.75 or 0.8 end
		return 0
	elseif kind == "aoe" then
		if foes >= 1 and (not has or gap <= (tonumber(ctx.radius) or 0)) then return math.min(1, 0.6 + 0.15 * foes) end
		return 0
	elseif kind == "defend" then
		if hp < 0.6 and ctx.recentlyHit == true then return 0.8 end
		if foes >= 2 then return 0.6 end
		return 0
	elseif kind == "heal" then
		if hp < 0.5 then return 0.8 end
		if ctx.mateLow == true then return 0.7 end
		return 0
	elseif kind == "buff" then
		if has and gap <= 20 then return 0.7 end
		return 0
	elseif kind == "stealth" then
		if hp < 0.4 and foes >= 1 then return 0.8 end
		if has and gap >= 40 and gap <= 90 then return 0.5 end
		return 0
	elseif kind == "zone" or kind == "trap" then
		if ctx.onPoint == true and foes >= 1 then return 0.7 end
		if has and gap <= 30 then return 0.55 end
		return 0
	elseif kind == "sense" then
		if not has and (tonumber(ctx.goalDist) or math.huge) <= 200 then return 0.4 end
		return 0
	end
	return 0
end

function M.pickLoadout(liveIds, mobilityIds, slots, rng)
	local live = {}
	for _, id in ipairs(type(liveIds) == "table" and liveIds or {}) do live[id] = true end
	local mob = {}
	for _, id in ipairs(type(mobilityIds) == "table" and mobilityIds or {}) do if live[id] then table.insert(mob, id) end end
	local out, used = {}, {}
	slots = math.max(0, tonumber(slots) or 0)
	if #mob > 0 and slots > 0 then
		local id = mob[rng:NextInteger(1, #mob)]
		table.insert(out, id)
		used[id] = true
	end
	local rest = {}
	for _, id in ipairs(liveIds or {}) do if not used[id] then table.insert(rest, id) end end
	table.sort(rest)
	for _, id in ipairs(shuffle(rng, rest)) do
		if #out >= slots then break end
		table.insert(out, id)
	end
	return out
end

return M
