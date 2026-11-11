-- LabClipRecipes.spec v1.0 (Mecha Dino Arena) — LabClipRecipes 1.0 (plan docs/plans/LAB_CLIPS_v1.0.md Task 2, MDA-442).
-- Run in Studio Edit (clones StarterPlayerScripts.LabClipRecipes and ServerStorage.DinoArcade.SkillTree); returns "PASS n" or
-- "FAIL ...".
local DA = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
local src = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("LabClipRecipes")
if not DA or not src then return "FAIL require: modules missing" end
local function load(m) local c = m:Clone() c.Parent = m.Parent local ok, r = pcall(require, c) c:Destroy() if not ok then error(r) end return r end
local R, ST = load(src), load(DA.SkillTree)
local fails, passes = {}, 0
local function ok(name, cond) if cond then passes += 1 else table.insert(fails, name) end end
local function eq(name, got, want) ok(("%s: got %s want %s"):format(name, tostring(got), tostring(want)), got == want) end

eq("version", R.VERSION, "1.0")
-- every live dilo mech part has a recipe
local n = 0
for id, p in pairs(ST.PATHS) do
	if p.mech == true and not p.soon and p.dino == "Dilo" then
		n += 1
		ok("recipe " .. id, R[id] ~= nil)
	end
end
eq("dilo parts", n, 7)
for _, id in ipairs({"dgatling", "dmortar", "dhiss", "dspine", "dpump", "djets", "dover"}) do
	local r = R[id]
	ok(id .. " what", type(r.what) == "string" and #r.what > 10 and #r.what <= 110)
	ok(id .. " template", R.TEMPLATES[r.template] == true)
	ok(id .. " attach", typeof(r.attach) == "Vector3")
	eq(id .. " steps", #r.steps, 4)
	for s = 1, 4 do
		for _, c in ipairs(r.chips) do ok(("%s step %d key %s"):format(id, s, c[2]), r.steps[s][c[2]] ~= nil) end
	end
end
eq("pump mode", R.dpump.mode, "pump"); eq("over mode", R.dover.mode, "over")
-- the numbers match the SkillTree 1.89 step texts
local WANT = {
	dgatling = {{"4 auto-aimed darts", "3 damage", "12 s"}, {"6 darts"}, {"10 s"}, {"8 darts"}},
	dmortar = {{"80 studs", "24-stud", "3 s", "16 s"}, {"100 studs", "30 studs"}, {"4 s"}, {"120 studs", "36 studs", "5 s"}},
	dhiss = {{"40-stud", "140°", "1.5 s", "15 s"}, {"50 studs"}, {"2 s", "12 s"}, {"60 studs", "3 s"}},
	dspine = {{"6 spines", "4 damage", "12 s"}, {"8 spines"}, {"venom"}, {"12 spines"}},
	dpump = {{"heals 15", "20 s"}, {"Heals 20"}, {"Heals 30"}, {"4 s immune"}},
	djets = {{"40 studs", "4.2 s"}, {"50 studs, 2 charges"}, {"65 studs", "poison trail"}, {"3 charges"}},
	dover = {{"for 4 s", "30 s"}, {"6 s"}, {"double damage"}, {"8 s"}},
}
for id, rows in pairs(WANT) do
	for s, list in ipairs(rows) do
		local text = tostring(ST.PATHS[id].steps[s])
		for _, w in ipairs(list) do ok(("%s step %d text has '%s' (%s)"):format(id, s, w, text), string.find(text, w, 1, true) ~= nil) end
	end
end
-- recipe numbers agree with those texts
eq("hiss r1", R.dhiss.steps[1].range, 40); eq("hiss r4", R.dhiss.steps[4].range, 60); eq("hiss sil3", R.dhiss.steps[3].silence, 2)
eq("mortar r1", R.dmortar.steps[1].reach, 80); eq("mortar c4", R.dmortar.steps[4].cloud, 36); eq("mortar l3", R.dmortar.steps[3].lasts, 4)
eq("jets d3", R.djets.steps[3].dist, 65); eq("jets c2", R.djets.steps[2].charges, 2); eq("jets cd", R.djets.steps[1].cd, 4.2)
eq("gat d4", R.dgatling.steps[4].darts, 8); eq("gat cd3", R.dgatling.steps[3].cd, 10)
-- helpers
eq("fmt studs", R.fmt(40, "studs"), "40 studs"); eq("fmt deg", R.fmt(140, "°"), "140°"); eq("fmt s", R.fmt(1.5, "s"), "1.5 s")
eq("fmt bool", R.fmt(true, "bool"), "YES"); eq("fmt plain", R.fmt(4, ""), "4"); eq("fmt 4.2", R.fmt(4.2, "s"), "4.2 s")
local c = R.chips(R.dhiss, 4, 1)
eq("chips n", #c, 4)
eq("chip range", c[1][2], "40 → 60 studs"); eq("chip range up", c[1][3], true)
eq("chip cone", c[2][2], "140°"); eq("chip cone up", c[2][3], false)
eq("chip sil", c[3][2], "1.5 → 3 s"); eq("chip cd", c[4][2], "15 → 12 s")
local c0 = R.chips(R.dhiss, 3, 0)
eq("unowned no up", c0[1][3] or c0[3][3] or c0[4][3], false); eq("unowned range", c0[1][2], "50 studs")
local cs = R.chips(R.dhiss, 2, 2)
eq("same step no up", cs[1][3], false)
local cb = R.chips(R.djets, 3, 1)
eq("bool up", cb[3][2], "NO → YES"); eq("bool up flag", cb[3][3], true)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
