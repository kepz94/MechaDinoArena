-- TutorialRules v1.0 (Mecha Dino Arena) — pure rules for the first-time flow. MDA-558, plan docs/plans/FIRST_TIME_FLOW_v1.0.md
-- Task 0, ADR-013, mockup docs/mockups/first_time_flow_v0.3.html (Kepu 2026-11-22: "A + B's cards", no skip, old players keep
-- all + TUTORIAL button; 10:46 red-team: roll 7 (no T-Rex), a saved lastSpecies also marks an old player).
-- Rojo: src/shared -> ServerStorage.DinoArcade.TutorialRules (TutorialServer clones it to ReplicatedStorage.TutorialShared).
-- classify(ownValue, readOk, skillState, hasLastSpecies, enabled, force) -> "off" | "new" | "done" | "resume" | "grand",
--   first matching row:
--     enabled ~= true                         -> "off"   (OwnershipEnabled false)
--     force == true                           -> "new"   (Studio test: Workspace TutorialTestForce)
--     readOk ~= true                          -> "off"   (ownership store read failed: never lock anyone out)
--     skillState not "loaded" / "new"         -> "off"   (SkillServer noApi / failed / off / loading)
--     ownValue table, tut.done == true        -> "done"
--     ownValue table                          -> "resume" (rolled, not finished)
--     skillState "loaded" or hasLastSpecies   -> "grand" (old player: owns all, never sees the flow)
--     otherwise                               -> "new"
-- rollPick(pool, r) -> pool[floor(r * #pool) + 1] (r clamped to [0, 1)), nil for an empty pool.
-- startStep(state, replay) -> 3 for a replay or "resume", 1 for "new", else nil.
-- laneCFrame(origin, lane, spacing) -> origin * CFrame.new((lane - 1) * spacing, 0, 0).
-- ownedString(set) -> the owned keys in ALL_DINOS order, comma-separated. allOwned() -> every key of ALL_DINOS.
-- v1.1 (first-time flow v1.1, mockup docs/mockups/first_time_flow_v0.4.html; Kepu 2026-11-22 11:38: "The teno has two different
--   attack styles and it doesn't even teach you it"; 12:09 "Build"): every attack style gets a lesson.
--   LESSONS[dino] = list of {n = name, how = "tap" | "hold" | "tap3", line = the tip, done = "hit" | "stamp" | "combo",
--   stamp = the character attribute the attack server writes (done "stamp"), key = PC key when not a click}. Grounded in the
--   attack servers: TenoAttackServer 1.11 (tap = scratch, hold + let go = tail slam behind, TenoSlamAt), TheriAttackServer 1.9
--   (3-hit combo, TheriComboStep 1-3), the others one attack each (any hit on the training bot). The dilo has one: tap = spit
--   (found in the Studio check: DiloAttackTest 1.6 turned the main attack's hold-to-snipe off, the sniper shot is the Sniper
--   Scope part, SkillTree 1.92).
--   lessonsFor(dino) -> LESSONS[dino] or a one-lesson "attack" fallback. ROLE[dino] -> "HOLDER" / "FIGHTER" / "RANGED"
--   (PregameScreen's role groups). lessonEvent(lesson, ev) -> true when ev completes the lesson; ev = {kind = "hit"} (the
--   bot lost health) or {kind = "stamp", name, value} (a character attribute changed). parseDone(s) / doneString(t) turn
--   "1,2" into {[1] = true, [2] = true} and back.
-- v1.3 (plan docs/plans/WELCOME_MOVES_v1.0.md Task 1, MDA-593, mockup docs/mockups/welcome_moves_v0.2.html; Kepu 2026-11-26
--   02:10 "Just have the climbing ability in the description of the Dino attack ability as a passive", "for mecha parts that's
--   just a different mechanic to use it"; "Build" 02:36):
--   PASSIVES[dino] = list of {n = name, tag = "PASSIVE" | "ON JUMP", line} = a dino's built-in move that is not a button
--   (Herrera climbing: ClimbLogic 1.1 + SlashServer "dive"; Therizino Spin Dive and Troodon Flap & Glide on JUMP, their
--   ModelData). passivesFor(dino) -> a copy of PASSIVES[dino], {} for nil / unknown.
--   JUMP_PARTS[id] = {stamp, needAttr?, big, pcBig, small, tip}: mecha parts that fire through JUMP, not their slot button
--   (MechaButtons: Glider Wings has no key, Mecha Legs / Hydraulic Leap presses do nothing). stamp = the character attribute
--   written when the move really happens (HerreraMovesServer GlideStartedAt, JumpServer 1.2 JumpDoubleAt, JumpServer
--   JumpStartedAt); needAttr = a character attribute that must be true at that moment (TenoLeapOnJump: the jump is the
--   hydraulic leap). jumpPart(id) -> the entry or nil. jumpPartEvent(entry, attrName, needValue) -> true when attrName is
--   entry.stamp and (no needAttr or needValue == true).
local M = {}
M.Version = "1.0"
M.Version = "1.1" -- v1.1 attack lessons
M.Version = "1.2" -- v1.2 a lesson needs the attack to land on the bot
M.Version = "1.3" -- v1.3 passives + JUMP parts

M.ALL_DINOS = {"Raptor", "TRex", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}
M.ROLL_POOL = {"Raptor", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"} -- Kepu 10:46 "No, roll 7"
M.STEPS = {"Welcome", "Roll", "Parts", "Hit the bot", "Equip 4 parts", "Use each part", "Defeat the bot", "Spend your point",
	"Skill points", "Island"}

function M.classify(ownValue, readOk, skillState, hasLastSpecies, enabled, force)
	if enabled ~= true then return "off" end
	if force == true then return "new" end
	if readOk ~= true then return "off" end
	if skillState ~= "loaded" and skillState ~= "new" then return "off" end
	if type(ownValue) == "table" then
		if type(ownValue.tut) == "table" and ownValue.tut.done == true then return "done" end
		return "resume"
	end
	if skillState == "loaded" or hasLastSpecies == true then return "grand" end
	return "new"
end

function M.rollPick(pool, r)
	if type(pool) ~= "table" or #pool == 0 then return nil end
	r = math.clamp(tonumber(r) or 0, 0, 0.999999)
	return pool[math.floor(r * #pool) + 1]
end

function M.startStep(state, replay)
	if replay == true or state == "resume" then return 3 end
	if state == "new" then return 1 end
	return nil
end

function M.laneCFrame(origin, lane, spacing)
	return origin * CFrame.new((lane - 1) * spacing, 0, 0)
end

-- v1.1: attack lessons
M.LESSONS = {
	Teno = {
		{n = "Scratch", how = "tap", line = "Hits in front of you.", done = "hit"},
		{n = "Tail Slam", how = "hold", line = "Hits behind you. Turn your back to it.", done = "stamp", stamp = "TenoSlamAt"},
	},
	Dilo = {
		{n = "Spit", how = "tap", line = "5 shots, then it reloads.", done = "hit"},
	},
	Therizino = {{n = "Claw Combo", how = "tap3", line = "Tap 3 times. The 3rd hit is the big one.", done = "combo", stamp = "TheriComboStep"}},
	Raptor = {{n = "Pounce", how = "tap", key = "F", line = "Jump on it and hang on.", done = "hit"}},
	Pachy = {{n = "Headbutt", how = "tap", line = "Charge into it. You have 2 charges.", done = "hit"}},
	Herrera = {{n = "Dash Slash", how = "tap", line = "Dash through it.", done = "hit"}},
	Troodon = {{n = "Glow Pod Toss", how = "tap", line = "Lobs a pod. Aim a little ahead.", done = "hit"}},
	TRex = {{n = "Bite", how = "tap", line = "Get close and bite.", done = "hit"}},
}
M.ROLE = {Pachy = "HOLDER", Teno = "HOLDER", Raptor = "FIGHTER", TRex = "FIGHTER", Herrera = "FIGHTER", Therizino = "FIGHTER",
	Dilo = "RANGED", Troodon = "RANGED"}

-- v1.2 (Kepu 2026-11-22 12:52 "I had the tail [slam] but I pressed it out of range and it still passed me"): the lessons with
--   their own attack need that attack to land on the training bot. done = "target": the attack server's hit stamp `stamp`
--   changed and its target list `targets` ("|" joined model names) holds the bot (ev.onBot, worked out by TutorialServer 1.2);
--   `stepAttr` / `stepMin`: the hit's combo step must be at least stepMin (the Therizino's 3rd cut). Grounded in
--   TenoAttackServer (TenoScratchHitAt / TenoScratchTargets, TenoSlamImpactAt / TenoSlamTargets, set at every scratch / slam,
--   hit or miss) and TheriAttackServer (TheriHitAt / TheriHitTargets / TheriHitStep). Same names, hows and lines as 1.1.
--   lessonsFor(dino, hitRules): hitRules false -> the 1.1 table (TutorialServer switch TutLessonNeedsHit).
M.LESSONS_HIT = {
	Teno = {
		{n = "Scratch", how = "tap", line = "Hits in front of you.", done = "target", stamp = "TenoScratchHitAt", targets = "TenoScratchTargets"},
		{n = "Tail Slam", how = "hold", line = "Hits behind you. Turn your back to it.", done = "target", stamp = "TenoSlamImpactAt",
			targets = "TenoSlamTargets"},
	},
	Therizino = {{n = "Claw Combo", how = "tap3", line = "Tap 3 times. The 3rd hit is the big one.", done = "target", stamp = "TheriHitAt",
		targets = "TheriHitTargets", stepAttr = "TheriHitStep", stepMin = 3}},
}

function M.lessonsFor(dino, hitRules)
	if hitRules ~= false and M.LESSONS_HIT[dino] then return M.LESSONS_HIT[dino] end -- v1.2
	return M.LESSONS[dino] or {{n = "Attack", how = "tap", line = "Hit it.", done = "hit"}}
end

-- v1.2: is a model name in a "|" joined target list
function M.listHas(list, name)
	if type(list) ~= "string" or type(name) ~= "string" or name == "" then return false end
	for k in string.gmatch(list, "[^|]+") do if k == name then return true end end
	return false
end

function M.lessonEvent(lesson, ev)
	if type(lesson) ~= "table" or type(ev) ~= "table" then return false end
	if lesson.done == "hit" then return ev.kind == "hit" end
	if lesson.done == "stamp" then return ev.kind == "stamp" and ev.name == lesson.stamp end
	if lesson.done == "combo" then
		return ev.kind == "stamp" and ev.name == lesson.stamp and (tonumber(ev.value) or 0) >= 3
	end
	if lesson.done == "target" then -- v1.2
		return ev.kind == "stamp" and ev.name == lesson.stamp and ev.onBot == true
			and (lesson.stepMin == nil or (tonumber(ev.step) or 0) >= lesson.stepMin)
	end
	return false
end

function M.parseDone(s)
	local t = {}
	for k in string.gmatch(tostring(s or ""), "%d+") do t[tonumber(k)] = true end
	return t
end

function M.doneString(t)
	local out = {}
	for k = 1, 16 do if type(t) == "table" and t[k] then table.insert(out, tostring(k)) end end
	return table.concat(out, ",")
end

function M.allOwned()
	local t = {}
	for _, k in ipairs(M.ALL_DINOS) do t[k] = true end
	return t
end

function M.ownedString(set)
	local out = {}
	for _, k in ipairs(M.ALL_DINOS) do
		if type(set) == "table" and set[k] then table.insert(out, k) end
	end
	return table.concat(out, ",")
end

-- v1.3: passives + JUMP parts (see the header)
M.PASSIVES = {
	Herrera = {{n = "Tree Climber", tag = "PASSIVE", line = "Walk into a tree to climb it. SLASH from a tree drops onto the dino below."}},
	Therizino = {{n = "Spin Dive", tag = "ON JUMP", line = "JUMP spins you forward. 3 charges."}},
	Troodon = {{n = "Flap & Glide", tag = "ON JUMP", line = "JUMP, then JUMP twice more in the air. Then it glides."}},
}
function M.passivesFor(dino)
	local out = {}
	for _, P in ipairs(M.PASSIVES[dino or ""] or {}) do table.insert(out, P) end
	return out
end
M.JUMP_PARTS = {
	glider = {stamp = "GlideStartedAt", big = "JUMP, THEN HOLD JUMP", pcBig = "SPACE, THEN HOLD SPACE", small = "Glider Wings",
		tip = "Glider Wings works on JUMP. Jump, then hold JUMP in the air."},
	mechalegs = {stamp = "JumpDoubleAt", big = "JUMP, THEN JUMP AGAIN", pcBig = "SPACE, THEN SPACE AGAIN", small = "Mecha Legs",
		tip = "Mecha Legs works on JUMP. Leap, then JUMP again in the air."},
	tleap = {stamp = "JumpStartedAt", needAttr = "TenoLeapOnJump", big = "TAP JUMP", pcBig = "PRESS SPACE", small = "Hydraulic Leap",
		tip = "Hydraulic Leap works on JUMP. Every jump is the leap."},
}
function M.jumpPart(id)
	return id and M.JUMP_PARTS[id] or nil
end
function M.jumpPartEvent(entry, attrName, needValue)
	if type(entry) ~= "table" or attrName ~= entry.stamp then return false end
	return entry.needAttr == nil or needValue == true
end

return M
