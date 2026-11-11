-- DiloTexts.spec v1.0 (Mecha Dino Arena) — SkillTree 1.89 DILO_TEXTS_V2 + StatSheet 1.8 DILO_ABILITY_V2 (plan
-- docs/plans/LAB_CLIPS_v1.0.md Task 1, MDA-441). Run in Studio Edit through the MCP / command bar (it writes the Source of
-- a throw-away StatSheet clone to test its switch off); returns "PASS n" or "FAIL ...".
local DA = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
if not DA or not DA:FindFirstChild("SkillTree") or not DA:FindFirstChild("StatSheet") then return "FAIL require: modules missing" end
local function load(name, from, to)
	local c = DA[name]:Clone()
	if from then c.Source = (c.Source:gsub(from, to)) end
	c.Parent = DA
	local ok, m = pcall(require, c)
	c:Destroy()
	if not ok then error(name .. ": " .. tostring(m)) end
	return m
end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local ST = load("SkillTree")
local P = ST.PATHS
eq("misses", ST.DILO_TEXTS_V2_MISSES, 0)
eq("hiss 1", P.dhiss.steps[1], "Button: the hood speakers blast a 40-stud, 140° cone: dinos are knocked back and their mecha parts are silenced 1.5 s. Recharges in 15 s")
eq("hiss 2", P.dhiss.steps[2], "Cone reaches 50 studs")
eq("hiss 3", P.dhiss.steps[3], "Silence lasts 2 s; recharges in 12 s")
eq("hiss 4", P.dhiss.steps[4], "Cone reaches 60 studs, silence lasts 3 s")
eq("over 1", P.dover.steps[1], "Button: for 4 s you spit with no wait and no ammo use, and your 5 shots refill. Recharges in 30 s")
eq("over 2", P.dover.steps[2], "Lasts 6 s")
eq("cold 4", P.coldblood.steps[4], "Below 30% health: double damage, and once per life your 5 shots refill the moment you drop below 30%")
eq("cold 1", P.coldblood.steps[1], "Below 30% health: darts deal 25% more damage")
-- Switch off: SkillTree's Source is over the 200k a script can set, so the off case is checked through the rows: the
-- block only writes a row's new text when the step still reads the row's old text, and DILO_TEXTS_V2 = false skips it.
local R = ST.DILO_TEXTS_V2_ROWS
eq("rows", #R, 5)
local OLD = {
	dhiss1 = "Button: the hood speakers blast a 20-stud cone: dinos are knocked back and their mecha parts are silenced 1.5 s. Recharges in 15 s",
	dhiss2 = "Cone reaches 25 studs", dhiss4 = "Cone reaches 30 studs, silence lasts 3 s",
	dover1 = "Button: for 4 s your darts recharge at once. Recharges in 30 s",
	coldblood4 = "Below 30% health: double damage, and once per life the dart recharges the moment you drop below 30%",
}
for _, r in ipairs(R) do
	eq("row old " .. r[1] .. r[2], r[3], OLD[r[1] .. r[2]])
	eq("row new " .. r[1] .. r[2], P[r[1]].steps[r[2]], r[4])
end
eq("switch", ST.DILO_TEXTS_V2, true)
local SS = load("StatSheet")
eq("ss version", SS.Version, "1.8")
eq("ss dilo 1", SS.SPECIES.Dilo.abilities[1], "Spit Dart (5 shots)")
eq("ss dilo 2", SS.SPECIES.Dilo.abilities[2], "Cobra Leap")
eq("ss dilo n", #SS.SPECIES.Dilo.abilities, 2)
local SSOFF = load("StatSheet", "StatSheet%.DILO_ABILITY_V2 = true", "StatSheet.DILO_ABILITY_V2 = false")
eq("ss off", SSOFF.SPECIES.Dilo.abilities[1], "Bite + Spit Dart")
eq("ss raptor", SS.SPECIES.Raptor and SS.SPECIES.Raptor.abilities[1], SSOFF.SPECIES.Raptor and SSOFF.SPECIES.Raptor.abilities[1])
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
