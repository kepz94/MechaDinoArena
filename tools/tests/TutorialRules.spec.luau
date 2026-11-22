-- TutorialRules.spec v1.1 (Mecha Dino Arena) — TutorialRules 1.0 / 1.1 lessons (plan docs/plans/FIRST_TIME_FLOW_v1.0.md Task 0, MDA-558).
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
local scr, slam = R.lessonsFor("Teno")[1], R.lessonsFor("Teno")[2]
eq("scratch by hit", R.lessonEvent(scr, {kind = "hit"}), true)
eq("scratch not by stamp", R.lessonEvent(scr, {kind = "stamp", name = "TenoSlamAt"}), false)
eq("slam by stamp", R.lessonEvent(slam, {kind = "stamp", name = "TenoSlamAt", value = 1}), true)
eq("slam not by hit", R.lessonEvent(slam, {kind = "hit"}), false)
eq("slam not by other stamp", R.lessonEvent(slam, {kind = "stamp", name = "TenoScratchAt"}), false)
local combo = R.lessonsFor("Therizino")[1]
eq("combo step 2", R.lessonEvent(combo, {kind = "stamp", name = "TheriComboStep", value = 2}), false)
eq("combo step 3", R.lessonEvent(combo, {kind = "stamp", name = "TheriComboStep", value = 3}), true)
eq("combo hit only", R.lessonEvent(combo, {kind = "hit"}), false)
eq("bad lesson", R.lessonEvent(nil, {kind = "hit"}), false)
eq("parse", R.parseDone("1,3")[3], true)
eq("parse empty", next(R.parseDone("")), nil)
eq("done string", R.doneString({[2] = true, [1] = true}), "1,2")
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
