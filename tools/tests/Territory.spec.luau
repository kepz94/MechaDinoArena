-- Territory.spec v1.0 (Mecha Dino Arena) — tests for ServerStorage.DinoArcade.Territory (MDA-17, plan
-- docs/plans/TERRITORIES_v1.0.md Task 1). Run in Studio Edit through execute_luau; returns "PASS n" or "FAIL ...".
local ok, T = pcall(function() return require(game.ServerStorage.DinoArcade.Territory) end)
if not ok then return "FAIL require: " .. tostring(T) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end

eq("Version", T.Version, "1.0")
eq("SPAWN", T.SPAWN, Vector3.new(88, 0, 904))
eq("SPAWN_SAFE", T.SPAWN_SAFE, 300)
-- T-Rex: the left half (x <= -40)
eq("trex left", T.inside("TRex", -500, -300), true)
eq("trex edge", T.inside("TRex", -40, 0), true)
eq("trex gap", T.inside("TRex", -39, 0), false)
eq("trex right", T.inside("TRex", 300, 0), false)
eq("trex far south-left", T.inside("TRex", -600, 900), true) -- 690 from spawn
eq("trex near spawn", T.inside("TRex", -150, 800), false) -- 260 from spawn (< 300)
-- Raptor: right half, z <= 560
eq("raptor right", T.inside("Raptor", 400, -300), true)
eq("raptor edge", T.inside("Raptor", 40, 0), true)
eq("raptor gap", T.inside("Raptor", 39, 0), false)
eq("raptor left", T.inside("Raptor", -300, 0), false)
eq("raptor south cut", T.inside("Raptor", 400, 561), false)
eq("raptor z edge", T.inside("Raptor", 600, 560), true)
-- the spawn circle (300 studs around (88, 904)) is nobody's (the raptor zone already ends at z 560, below the circle)
eq("trex spawn circle", T.inside("TRex", -60, 700), false)
-- unknown species: no limit
eq("unknown", T.inside("Chicken", 88, 904), true)
eq("nil species", T.inside(nil, 0, 0), true)
-- home: the 4 marker bots (inside -> same; outside -> x mirror)
local function v(x, z) return Vector3.new(x, 2, z) end
eq("home raptor inside", T.home("Raptor", v(238.6, 446.4)), v(238.6, 446.4))
eq("home raptor mirror 1", T.home("Raptor", v(-152.7, 476.9)), v(152.7, 476.9))
eq("home raptor mirror 2", T.home("Raptor", v(-89.6, -461.6)), v(89.6, -461.6))
eq("home trex mirror", T.home("TRex", v(60, 349.9)), v(-60, 349.9))
eq("home none", T.home("Raptor", v(-20, 700)), nil) -- mirror (20, 700) is in the gap / south cut
eq("home unknown", T.home("Chicken", v(5, 5)), v(5, 5))
-- paths
eq("path inside", T.pathInside("Raptor", v(100, 0), v(800, -500)), true)
eq("path crosses gap", T.pathInside("Raptor", v(100, 0), v(-100, 0)), false)
eq("path through spawn circle", T.pathInside("TRex", v(-400, 900), v(-40, 650)), false)
eq("path unknown", T.pathInside("Chicken", v(-900, 0), v(900, 0)), true)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
