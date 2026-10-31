-- ClimbLogic.spec v1.1 (Mecha Dino Arena) — tests for ServerStorage.DinoArcade.ClimbLogic (MDA-137, plan
-- docs/plans/HERRERA_KIT_v1.0.md Task 5). Run in Studio Edit through execute_luau; returns "PASS n" or "FAIL ...".
-- One case per row of the module's rules (the plan's deterministic map) plus mantleTarget.
-- v1.1 (MDA-145): trunk end + forward -> mantle (the plan's row "the trunk ends -> onto the top"), treeTopTarget.
local src = game.ServerStorage:FindFirstChild("DinoArcade") and game.ServerStorage.DinoArcade:FindFirstChild("ClimbLogic")
if not src then return "FAIL ClimbLogic missing" end
local CL = loadstring(src.Source)()
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local S = {grab = 3, topGap = 4, speed = 20}
local function case(name, state, input, probe, wantState, check)
	local st, out = CL.step(state, input, probe, S)
	eq(name .. " state", st, wantState)
	for k, v in pairs(check or {}) do eq(name .. " " .. k, out[k], v) end
end

eq("Version", CL.Version, "1.1")
-- ground / top
case("grab", "ground", {forward = true}, {trunkAhead = 2}, "climbing", {hold = true, vy = 20, reason = "grab"})
case("too far to grab", "ground", {forward = true}, {trunkAhead = 5}, "ground", {hold = false})
case("no forward no grab", "ground", {}, {trunkAhead = 1}, "ground", {hold = false})
case("grab from top", "top", {forward = true}, {trunkAhead = 1, onTop = true}, "climbing", {hold = true})
case("hop off top", "top", {hop = true}, {onTop = true}, "ground", {hop = true, hold = false})
case("stand on top", "ground", {}, {onTop = true}, "top", {hold = false, reason = "onTop"})
case("walk off top", "top", {forward = true}, {onTop = false}, "ground", {hold = false})
-- on the trunk
case("climb up", "climbing", {forward = true}, {trunkAhead = 1.5}, "climbing", {hold = true, vy = 20, reason = "up"})
case("cling start", "clinging", {forward = true}, {trunkAhead = 1.5}, "climbing", {vy = 20})
case("let go -> cling", "climbing", {}, {trunkAhead = 1.5}, "clinging", {hold = true, vy = 0, reason = "cling"})
case("hop off trunk", "climbing", {hop = true, forward = true}, {trunkAhead = 1.5}, "ground", {hop = true, hold = false})
case("hop from cling", "clinging", {hop = true}, {trunkAhead = 1.5}, "ground", {hop = true})
case("lost trunk", "climbing", {forward = true}, {trunkAhead = nil}, "ground", {hold = false, reason = "lostTrunk"})
case("trunk far", "clinging", {}, {trunkAhead = 7}, "ground", {reason = "lostTrunk"})
case("mantle", "climbing", {forward = true}, {trunkAhead = 1, topAbove = 3}, "top", {mantle = true, hold = false})
case("top not near yet", "climbing", {forward = true}, {trunkAhead = 1, topAbove = 9}, "climbing", {mantle = false, vy = 20})
case("trunk end -> mantle", "climbing", {forward = true}, {trunkAhead = 1, trunkEnds = true}, "top", {mantle = true, hold = false, reason = "trunkEnd"})
case("trunk end, no forward -> cling", "climbing", {}, {trunkAhead = 1, trunkEnds = true}, "clinging", {hold = true, vy = 0, reason = "cling"})
case("slide down", "clinging", {back = true}, {trunkAhead = 1, groundBelow = 6}, "climbing", {vy = -20, reason = "down"})
case("reach ground", "climbing", {back = true}, {trunkAhead = 1, groundBelow = 0.3}, "ground", {hold = false, reason = "slidDown"})
case("back with no ground below", "climbing", {back = true}, {trunkAhead = 1}, "climbing", {vy = -20})
case("hop beats mantle", "climbing", {hop = true, forward = true}, {trunkAhead = 1, topAbove = 1}, "ground", {hop = true})
case("nil input / probe", "ground", nil, nil, "ground", {hold = false})

-- mantle target
local proxies = {
	{x = 0, z = 0, top = 40, reach = 9}, -- palm pad
	{x = 30, z = 0, top = 60, reach = 11}, -- another tree
	{x = 2, z = 1, top = 44, reach = 4}, -- a higher block over the trunk
	{x = 0, z = 0, top = 10, reach = 9}, -- below the body: ignored
}
local t = CL.mantleTarget(proxies, Vector3.new(1, 30, 0), 33)
eq("mantle highest over trunk", t and t.Y, 44)
eq("mantle x = trunk", t and t.X, 1)
t = CL.mantleTarget(proxies, Vector3.new(50, 30, 50), 33)
eq("mantle none in reach", t, nil)
t = CL.mantleTarget({{x = 0, z = 0, top = 10, reach = 9}}, Vector3.new(0, 30, 0), 33)
eq("mantle only below -> nil", t, nil)
eq("mantle nil proxies", CL.mantleTarget(nil, Vector3.new(), 0), nil)
-- v1.1: the climbed tree's own top (no footprint test: a leaning palm's crown is off the trunk line)
local own = {{x = 11, z = 3, top = 52, reach = 8.85}, {x = 12, z = 2, top = 48, reach = 4}, {x = 11, z = 3, top = 20, reach = 8}}
t = CL.treeTopTarget(own, 37)
eq("tree top highest", t and t.Y, 52)
eq("tree top x = proxy", t and t.X, 11)
eq("tree top z = proxy", t and t.Z, 3)
eq("tree top only below -> nil", CL.treeTopTarget({{x = 0, z = 0, top = 20, reach = 5}}, 37), nil)
eq("tree top nil proxies", CL.treeTopTarget(nil, 0), nil)

if #fails > 0 then return "FAIL " .. #fails .. " / " .. (passes + #fails) .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
