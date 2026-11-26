-- TutorialRules.spec v1.3 (Mecha Dino Arena) — TutorialRules 1.0 / 1.1 lessons / 1.2 hit rules (plan docs/plans/FIRST_TIME_FLOW_v1.0.md Task 0, MDA-558)
-- / 1.3 passives + JUMP parts (plan docs/plans/WELCOME_MOVES_v1.0.md Task 1, MDA-593).
-- Run in Studio Edit (clone + require ServerStorage.DinoArcade.TutorialRules); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage"):FindFirstChild("DinoArcade") and game.ServerStorage.DinoArcade:FindFirstChild("TutorialRules")
if not src then return "FAIL require: ServerStorage.DinoArcade.TutorialRules missing" end
local ok, R = pcall(function() local c = src:Clone() c.Parent = src.Parent local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
-- classify(ownValue, readOk, skillState, hasLastSpecies, enabled, force)
local done = {v = 1, owned = {Herrera = true}, free = "Herrera", tut = {done = true}}
local half = {v = 1, owned = {Herrera = true}, free = "Herrera", tut = {done = false}}
eq("disabled", R.classify(nil, true, "new", false, false, false), "off")
eq("disabled beats force", R.classify(nil, true, "new", false, false, true), "off")
eq("force", R.classify(done, true, "loaded", true, true, true), "new")
eq("read failed", R.classify(nil, false, "new", false, true, false), "off")
eq("skills noApi", R.classify(nil, true, "noApi", false, true, false), "off")
eq("skills failed", R.classify(nil, true, "failed", false, true, false), "off")
eq("skills off", R.classify(nil, true, "off", false, true, false), "off")
eq("skills loading", R.classify(nil, true, "loading", false, true, false), "off")
eq("done", R.classify(done, true, "loaded", false, true, false), "done")
eq("done new skills", R.classify(done, true, "new", false, true, false), "done")
eq("resume", R.classify(half, true, "new", false, true, false), "resume")
eq("resume no tut table", R.classify({v = 1, owned = {}, free = "Dilo"}, true, "new", false, true, false), "resume")
eq("grand by skills", R.classify(nil, true, "loaded", false, true, false), "grand")
eq("grand by lastSpecies", R.classify(nil, true, "new", true, true, false), "grand")
eq("new", R.classify(nil, true, "new", false, true, false), "new")
eq("bad value = no value", R.classify("junk", true, "new", false, true, false), "new")
-- rollPick
eq("pick first", R.rollPick({"A", "B", "C"}, 0), "A")
eq("pick last", R.rollPick({"A", "B", "C"}, 0.999), "C")
eq("pick mid", R.rollPick({"A", "B", "C"}, 0.5), "B")
eq("pick r=1 clamps", R.rollPick({"A", "B", "C"}, 1), "C")
eq("pick empty", R.rollPick({}, 0.5), nil)
eq("pool size", #R.ROLL_POOL, 7)
local hasRex = false
for _, k in ipairs(R.ROLL_POOL) do if k == "TRex" then hasRex = true end end
eq("no T-Rex in pool", hasRex, false)
eq("all dinos", #R.ALL_DINOS, 8)
-- steps
eq("steps", #R.STEPS, 10)
eq("step 1", R.STEPS[1], "Welcome")
eq("step 10", R.STEPS[10], "Island")
eq("start new", R.startStep("new", false), 1)
eq("start resume", R.startStep("resume", false), 3)
eq("start replay", R.startStep("done", true), 3)
eq("start done", R.startStep("done", false), nil)
-- laneCFrame
local o = CFrame.new(10, 600, 4000)
eq("lane 1", R.laneCFrame(o, 1, 300).Position, Vector3.new(10, 600, 4000))
eq("lane 3", R.laneCFrame(o, 3, 300).Position, Vector3.new(610, 600, 4000))
-- ownedList / ownedString
eq("owned string", R.ownedString({Herrera = true, Dilo = true}), "Herrera,Dilo")
eq("owned string all", R.ownedString(R.allOwned()), table.concat(R.ALL_DINOS, ","))
-- v1.1 lessons
eq("teno 2 lessons", #R.lessonsFor("Teno"), 2)
eq("dilo 1 lesson (no hold-to-snipe since DiloAttackTest 1.6)", #R.lessonsFor("Dilo"), 1)
eq("theri combo", R.lessonsFor("Therizino")[1].how, "tap3")
eq("fallback", #R.lessonsFor("Nope"), 1)
eq("every rolled dino has lessons", (function() for _, k in ipairs(R.ROLL_POOL) do if not R.LESSONS[k] then return k end end return "all" end)(), "all")
eq("every dino has a role", (function() for _, k in ipairs(R.ALL_DINOS) do if not R.ROLE[k] then return k end end return "all" end)(), "all")
local scr, slam = R.lessonsFor("Teno", false)[1], R.lessonsFor("Teno", false)[2] -- the 1.1 table
eq("scratch by hit", R.lessonEvent(scr, {kind = "hit"}), true)
eq("scratch not by stamp", R.lessonEvent(scr, {kind = "stamp", name = "TenoSlamAt"}), false)
eq("slam by stamp", R.lessonEvent(slam, {kind = "stamp", name = "TenoSlamAt", value = 1}), true)
eq("slam not by hit", R.lessonEvent(slam, {kind = "hit"}), false)
eq("slam not by other stamp", R.lessonEvent(slam, {kind = "stamp", name = "TenoScratchAt"}), false)
local combo = R.lessonsFor("Therizino", false)[1]
eq("combo step 2", R.lessonEvent(combo, {kind = "stamp", name = "TheriComboStep", value = 2}), false)
eq("combo step 3", R.lessonEvent(combo, {kind = "stamp", name = "TheriComboStep", value = 3}), true)
eq("combo hit only", R.lessonEvent(combo, {kind = "hit"}), false)
eq("bad lesson", R.lessonEvent(nil, {kind = "hit"}), false)
eq("parse", R.parseDone("1,3")[3], true)
eq("parse empty", next(R.parseDone("")), nil)
eq("done string", R.doneString({[2] = true, [1] = true}), "1,2")
-- v1.2 hit rules
local scr2, slam2 = R.lessonsFor("Teno")[1], R.lessonsFor("Teno")[2]
eq("v1.2 default = hit rules", slam2.done, "target")
eq("v1.2 off = 1.1 table", R.lessonsFor("Teno", false)[2].done, "stamp")
eq("slam missed", R.lessonEvent(slam2, {kind = "stamp", name = "TenoSlamImpactAt", onBot = false}), false)
eq("slam on bot", R.lessonEvent(slam2, {kind = "stamp", name = "TenoSlamImpactAt", onBot = true}), true)
eq("slam stamp alone", R.lessonEvent(slam2, {kind = "stamp", name = "TenoSlamAt", onBot = true}), false)
eq("slam by bot hp drop", R.lessonEvent(slam2, {kind = "hit"}), false)
eq("scratch on bot", R.lessonEvent(scr2, {kind = "stamp", name = "TenoScratchHitAt", onBot = true}), true)
eq("scratch by bot hp drop", R.lessonEvent(scr2, {kind = "hit"}), false)
local combo2 = R.lessonsFor("Therizino")[1]
eq("combo cut 2 on bot", R.lessonEvent(combo2, {kind = "stamp", name = "TheriHitAt", onBot = true, step = 2}), false)
eq("combo cut 3 missed", R.lessonEvent(combo2, {kind = "stamp", name = "TheriHitAt", onBot = false, step = 3}), false)
eq("combo cut 3 on bot", R.lessonEvent(combo2, {kind = "stamp", name = "TheriHitAt", onBot = true, step = 3}), true)
eq("dilo unchanged", R.lessonsFor("Dilo")[1].done, "hit")
eq("listHas", R.listHas("A|PBot_Training Bot|C", "PBot_Training Bot"), true)
eq("listHas no", R.listHas("A|B", "PBot_Training Bot"), false)
eq("listHas empty", R.listHas("", "x"), false)
-- v1.3: passives + JUMP parts (MDA-593)
local function n(t) return type(t) == "table" and #t or -1 end
eq("passives Herrera", n(R.passivesFor and R.passivesFor("Herrera")), 1)
eq("passives Therizino", n(R.passivesFor and R.passivesFor("Therizino")), 1)
eq("passives Troodon", n(R.passivesFor and R.passivesFor("Troodon")), 1)
for _, d in ipairs({"Raptor", "Pachy", "Teno", "Dilo", "TRex", "Nope"}) do eq("passives none " .. d, n(R.passivesFor and R.passivesFor(d)), 0) end
eq("passives nil", n(R.passivesFor and R.passivesFor(nil)), 0)
eq("Herrera passive name", R.passivesFor and R.passivesFor("Herrera")[1] and R.passivesFor("Herrera")[1].n, "Tree Climber")
if R.passivesFor then
	local c = R.passivesFor("Herrera")
	c[1] = nil
	eq("passives copy", n(R.passivesFor("Herrera")), 1)
end
for d, list in pairs(R.PASSIVES or {}) do
	for i, P in ipairs(list) do
		eq("passive tag " .. d .. i, P.tag == "PASSIVE" or P.tag == "ON JUMP", true)
		eq("passive dash " .. d .. i, string.find(P.n .. P.line, "\u{2014}") == nil, true)
		eq("passive line " .. d .. i, type(P.line) == "string" and #P.line > 0, true)
	end
end
local gl, ml, tl = R.jumpPart and R.jumpPart("glider"), R.jumpPart and R.jumpPart("mechalegs"), R.jumpPart and R.jumpPart("tleap")
eq("glider stamp", gl and gl.stamp, "GlideStartedAt")
eq("mechalegs stamp", ml and ml.stamp, "JumpDoubleAt")
eq("tleap stamp", tl and tl.stamp, "JumpStartedAt")
eq("tleap needAttr", tl and tl.needAttr, "TenoLeapOnJump")
eq("quills not jump", R.jumpPart and R.jumpPart("quills"), nil)
eq("nil not jump", R.jumpPart and R.jumpPart(nil), nil)
eq("tleap needs flag", R.jumpPartEvent and R.jumpPartEvent(tl, "JumpStartedAt", false), false)
eq("tleap with flag", R.jumpPartEvent and R.jumpPartEvent(tl, "JumpStartedAt", true), true)
eq("glider wrong stamp", R.jumpPartEvent and R.jumpPartEvent(gl, "JumpStartedAt", nil), false)
eq("glider stamp ok", R.jumpPartEvent and R.jumpPartEvent(gl, "GlideStartedAt", nil), true)
eq("mechalegs stamp ok", R.jumpPartEvent and R.jumpPartEvent(ml, "JumpDoubleAt", nil), true)
eq("nil entry", R.jumpPartEvent and R.jumpPartEvent(nil, "GlideStartedAt", true), false)
local okST, ST = pcall(function() return require(game:GetService("ServerStorage").DinoArcade.SkillTree) end)
for id, J in pairs(R.JUMP_PARTS or {}) do
	eq("jump part in SkillTree " .. id, okST and ST.PATHS[id] ~= nil, true)
	for _, k in ipairs({"big", "pcBig", "small", "tip"}) do
		eq("jump part " .. id .. " " .. k, type(J[k]) == "string" and #J[k] > 0 and string.find(J[k], "\u{2014}") == nil, true)
	end
end
eq("jump parts count", (function() local c = 0 for _ in pairs(R.JUMP_PARTS or {}) do c += 1 end return c end)(), 3)
eq("lessons kept", #R.lessonsFor("Teno"), 2)
eq("roll pool kept", #R.ROLL_POOL, 7)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
