-- FontSwapRules.spec v1.0 (Mecha Dino Arena) — FontSwapRules 1.0 (plan docs/plans/FONT_SILKSCREEN_v1.0.md Task 1, MDA-449).
-- Run in Studio Edit (clones StarterPlayerScripts.FontSwapRules); returns "PASS n" or "FAIL ...".
local src = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("FontSwapRules")
if not src then return "FAIL require: FontSwapRules missing" end
local c = src:Clone() c.Parent = src.Parent
local okR, R = pcall(require, c)
c:Destroy()
if not okR then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want) if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end end

eq("version", R.VERSION, "1.0"); eq("max", R.MAX_CHARS, 24); eq("min", R.MIN_SIZE, 8)
-- plainLength
eq("len plain", R.plainLength("MECHA ABILITIES"), 15)
eq("len rich", R.plainLength('RANGE <font color="#FFFFFF">40 studs</font>'), 14)
eq("len escapes", R.plainLength("A &amp; B &lt;3"), 8)
eq("len utf8", R.plainLength("STEP ★"), 6)
eq("len arrow", R.plainLength("40 → 60 studs"), 13)
eq("len nil", R.plainLength(nil), 0)
-- classify
local function cl(t) return R.classify(t) end
eq("short fredoka", cl({font = "FredokaOne", text = "Sonic Hiss"}), "silk")
eq("short gblack", cl({font = "GothamBlack", text = "UPGRADE · 2 PTS"}), "silk")
eq("gbold short", cl({font = "GothamBold", text = "Cone reaches 50 studs"}), "silk")
eq("sourcesans", cl({font = "SourceSansBold", text = "-12"}), "silk")
eq("exactly 24", cl({font = "GothamBlack", text = string.rep("A", 24)}), "silk")
eq("25 keep", cl({font = "GothamBlack", text = string.rep("A", 25)}), "keep")
eq("wrapped keep", cl({font = "GothamBlack", text = "Short", wrapped = true}), "keep")
eq("scaled long silk", cl({font = "FredokaOne", text = string.rep("A", 40), scaled = true, wrapped = true}), "silk")
eq("sentence keep", cl({font = "GothamBold", text = "Button: the hood speakers blast a 40-stud cone"}), "keep")
eq("mono keep", cl({font = "RobotoMono", text = "ALL UPGRADES"}), "keep")
eq("code keep", cl({font = "Code", text = "x"}), "keep")
eq("unknown keep", cl({font = "Unknown", text = "x"}), "keep")
eq("box keep", cl({font = "FredokaOne", text = "hi", isBox = true}), "keep")
eq("override keep", cl({font = "FredokaOne", text = "hi", override = "keep"}), "keep")
eq("override silk", cl({font = "RobotoMono", text = string.rep("A", 60), wrapped = true, override = "silk"}), "silk")
eq("box beats override", cl({font = "FredokaOne", text = "hi", isBox = true, override = "silk"}), "keep")
eq("rich chip", cl({font = "GothamBlack", text = 'RANGE <font color="#FFC832">40 → 50 studs</font>'}), "silk")
eq("empty", cl({font = "FredokaOne", text = ""}), "silk")
eq("bad info", R.classify(nil), "keep")
eq("wrapped title silk", cl({font = "FredokaOne", text = "Venom Gatling", wrapped = true}), "silk")
eq("wrapped long title keep", cl({font = "FredokaOne", text = string.rep("A", 30), wrapped = true}), "keep")
eq("wrapped gbold keep", cl({font = "GothamBold", text = "6 darts", wrapped = true}), "keep")
eq("no glyph x", cl({font = "GothamBlack", text = "✕"}), "keep")
eq("no glyph tri", cl({font = "FredokaOne", text = "PRACTICE  ▾"}), "keep")
eq("glyph ok", cl({font = "FredokaOne", text = "◀"}), "silk")
eq("scaled no glyph", cl({font = "FredokaOne", text = "✕", scaled = true}), "keep")
-- fitSize
eq("fit 20", R.fitSize(20, 0.88), 18)
eq("fit default", R.fitSize(20), 18)
eq("fit clamp low", R.fitSize(20, 0.3), 14)
eq("fit clamp high", R.fitSize(20, 1.4), 20)
eq("fit floor 8", R.fitSize(9, 0.7), 8)
eq("fit small stays", R.fitSize(7, 0.88), 7)
eq("fit tiny", R.fitSize(6, 0.88), 6)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
