-- ModeRules.spec v1.0 (Mecha Dino Arena) — tests for ServerStorage.DinoArcade.ModeRules (MDA-85, plan
-- docs/plans/MAIN_MENU_v1.0.md Task 1, deterministic map tables). Run in Studio Edit through execute_luau; returns
-- "PASS n" or "FAIL ...". Requires a fresh clone so a re-run in the same Studio session sees the installed source.
local ok, MR = pcall(function()
	local src = game.ServerStorage.DinoArcade.ModeRules
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(MR) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end

eq("Version", MR.Version, "1.0")
eq("SANDBOX_PLACE_ID", MR.SANDBOX_PLACE_ID, 84022023159448)
eq("ARENA_PLACE_ID", MR.ARENA_PLACE_ID, 75433819286625)

-- placeMode(placeId, isStudio, testArena)
local A, S = MR.ARENA_PLACE_ID, MR.SANDBOX_PLACE_ID
eq("studio + test -> arena", MR.placeMode(S, true, true), "arena")
eq("studio + test, any place -> arena", MR.placeMode(0, true, true), "arena")
eq("live + test ignored", MR.placeMode(S, false, true), "sandbox")
eq("arena place", MR.placeMode(A, false, false), "arena")
eq("arena place, studio no test", MR.placeMode(A, true, false), "arena")
eq("arena place, test nil", MR.placeMode(A, false, nil), "arena")
eq("sandbox place", MR.placeMode(S, false, false), "sandbox")
eq("studio unpublished (0)", MR.placeMode(0, true, false), "sandbox")
eq("other place", MR.placeMode(123, false, false), "sandbox")
eq("bad placeId", MR.placeMode("x", false, false), "sandbox")
eq("test not exactly true", MR.placeMode(S, true, "yes"), "sandbox")

-- canAffect(srcIsPlayer, tgtIsPlayer, tgtInMenu, mode): every row of the table
for _, m in ipairs({"sandbox", "arena"}) do
	for _, src in ipairs({true, false}) do
		for _, menu in ipairs({true, false}) do
			eq(("non-player target %s %s %s"):format(m, tostring(src), tostring(menu)), MR.canAffect(src, false, menu, m), true)
		end
		eq(("menu player target %s %s"):format(m, tostring(src)), MR.canAffect(src, true, true, m), false)
	end
	eq("bot -> player " .. m, MR.canAffect(false, true, false, m), true)
end
eq("player -> player arena", MR.canAffect(true, true, false, "arena"), true)
eq("player -> player sandbox", MR.canAffect(true, true, false, "sandbox"), false)
eq("player -> player unknown mode", MR.canAffect(true, true, false, "menu"), false)
eq("player -> player nil mode", MR.canAffect(true, true, false, nil), false)
eq("nil target flag = not a player", MR.canAffect(true, nil, false, "sandbox"), true)
eq("nil menu flag = playing", MR.canAffect(true, true, nil, "arena"), true)
eq("nil source flag = not a player", MR.canAffect(nil, true, false, "sandbox"), true)

-- currentMode() returns a known mode in Edit
local cm = MR.currentMode()
eq("currentMode known", cm == "sandbox" or cm == "arena", true)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
