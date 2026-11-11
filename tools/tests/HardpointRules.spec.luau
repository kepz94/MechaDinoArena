-- HardpointRules.spec v1.0 (Mecha Dino Arena) — HardpointRules 1.0 (plan docs/plans/HARDPOINT_v1.0.md Task 1, MDA-396).
-- Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.HardpointRules_spec, clone + require); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage"):FindFirstChild("DinoArcade") and game.ServerStorage.DinoArcade:FindFirstChild("HardpointRules")
if not src then return "FAIL require: ServerStorage.DinoArcade.HardpointRules missing" end
local ok, H = pcall(function() local c = src:Clone() c.Parent = src.Parent local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(H) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-6) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
-- numbers
eq("radius", H.RADIUS, 45); eq("limit", H.LIMIT, 250); eq("clock", H.CLOCK, 600); eq("point time", H.POINT_TIME, 60)
eq("first", H.FIRST, 5); eq("next shown", H.NEXT_SHOWN, 10); eq("layout B", #H.LAYOUT_B, 5); eq("P3 summit", H.LAYOUT_B[3].name, "Summit")
-- phase
local p = H.phaseAt(4.99, 5)
eq("warmup 4.99", p.warmup, true); eq("warmup shows P1 locked", p.showNext, true); eq("warmup next", p.nextIndex, 1); eq("warmup remaining", p.remaining, 0.01, 1e-6)
p = H.phaseAt(5, 5)
eq("P1 opens at 5", p.warmup, false); eq("P1 index", p.index, 1); eq("P1 into", p.into, 0); eq("P1 not next yet", p.showNext, false)
p = H.phaseAt(5 + 49.99, 5); eq("49.99 no next", p.showNext, false)
p = H.phaseAt(5 + 50, 5); eq("50 next shown", p.showNext, true); eq("next index", p.nextIndex, 2); eq("remaining 10", p.remaining, 10, 1e-6)
p = H.phaseAt(5 + 60, 5); eq("P2 at 65", p.index, 2); eq("P2 into", p.into, 0, 1e-9)
p = H.phaseAt(5 + 4 * 60 + 55, 5); eq("P5", p.index, 5); eq("P5 next wraps to 1", p.nextIndex, 1)
p = H.phaseAt(5 + 5 * 60, 5); eq("wrap to P1", p.index, 1)
-- occupancy
eq("N", H.occupancy(0, 0), "N"); eq("A", H.occupancy(2, 0), "A"); eq("B", H.occupancy(0, 1), "B"); eq("C", H.occupancy(1, 3), "C")
-- in point
local c = Vector3.new(10, 5, 10)
eq("in centre", H.inPoint(c, c), true); eq("edge 45", H.inPoint(c + Vector3.new(45, 0, 0), c), true)
eq("out 45.1", H.inPoint(c + Vector3.new(45.1, 0, 0), c), false); eq("dy 40", H.inPoint(c + Vector3.new(0, 40, 0), c), true)
eq("dy 41", H.inPoint(c + Vector3.new(0, -41, 0), c), false); eq("bad input", H.inPoint(nil, c), false)
-- scoring: 0.25 s ticks, 4 per point
local s = H.newState()
for _ = 1, 4 do s = H.step(s, "A", 0.25) end
eq("4 ticks = 1 point", s.scoreA, 1); eq("clock frozen while held", s.clock, 600)
for _ = 1, 3 do s = H.step(s, "A", 0.25) end
s = H.step(s, "C", 0.25)
eq("contested drops the carry", s.carryA, 0); eq("no point from 0.75 s", s.scoreA, 1); eq("clock frozen while contested", s.clock, 600)
s = H.step(s, "N", 0.25); eq("clock runs while empty", s.clock, 599.75, 1e-9)
local s0 = H.newState(); local s1 = H.step(s0, "B", 1); eq("input unchanged", s0.scoreB, 0); eq("B +1", s1.scoreB, 1)
-- winners
eq("no winner", H.winner(H.newState()), nil)
eq("A at 250", H.winner({scoreA = 250, scoreB = 10, clock = 100, carryA = 0, carryB = 0}), "A")
eq("B at 250", H.winner({scoreA = 249, scoreB = 250, clock = 100, carryA = 0, carryB = 0}), "B")
eq("clock 0 lead", H.winner({scoreA = 100, scoreB = 120, clock = 0, carryA = 0, carryB = 0}), "B")
eq("clock 0 tie", H.winner({scoreA = 90, scoreB = 90, clock = 0, carryA = 0, carryB = 0}), "draw")
local cap = {scoreA = 249, scoreB = 0, clock = 1, carryA = 0, carryB = 0}; cap = H.step(cap, "A", 3); eq("capped 250", cap.scoreA, 250)
-- teams
eq("smaller team", H.pickTeam(3, 2, 0, 0), "B"); eq("tie -> behind on score", H.pickTeam(2, 2, 50, 10), "B")
eq("tie -> A", H.pickTeam(2, 2, 5, 5), "A"); eq("squad kept", H.pickTeam(3, 2, 0, 0, "A"), "A")
eq("squad split past gap 2", H.pickTeam(4, 2, 0, 0, "A"), "B"); eq("bad squad team ignored", H.pickTeam(1, 2, 0, 0, "X"), "A")
local g = H.assignGroups({{id = "sq", n = 4}, {id = "solo1", n = 1}})
eq("4+1: squad split", g.sq.A + g.sq.B, 4); eq("4+1 gap", math.abs((g.sq.A + g.solo1.A) - (g.sq.B + g.solo1.B)) <= 2, true); eq("4+1 squad mostly A", g.sq.A, 3)
g = H.assignGroups({{id = "a", n = 2}, {id = "b", n = 2}, {id = "c", n = 1}})
eq("2+2+1 a whole", g.a.A == 2 or g.a.B == 2, true); eq("2+2+1 b whole", g.b.A == 2 or g.b.B == 2, true)
eq("2+2+1 a/b apart", (g.a.A == 2) ~= (g.b.A == 2), true)
-- spawns: a full ring of 12 spots at 300 on each layout point; the mockup's 3 situations (A west of the point, B east)
local SIT = {
	even = {a = {{-140, -40}, {-90, 60}, {-30, 10}}, b = {{150, 30}, {100, -70}, {40, 20}}, wantA = "W", wantB = "E"},
	push = {a = {{60, -30}, {140, 70}, {180, -90}}, b = {{260, 40}}, wantA = "E", wantB = "W"},
	camp = {a = {{40, 10}}, b = {{-230, -60}, {-200, 90}, {-120, 0}}, wantA = "E", wantB = "W"},
}
for i, pt in ipairs(H.LAYOUT_B) do
	local centre = Vector3.new(pt.x, 0, pt.z)
	local ring = H.ringSpots(centre, function(v) return v end)
	eq("ring 12 at P" .. i, #ring, 12)
	eq("ring radius 300 at P" .. i, (Vector3.new(ring[1].X, 0, ring[1].Z) - centre).Magnitude, 300, 1e-6)
	for name, S in pairs(SIT) do
		local A, B = {}, {}
		for _, o in ipairs(S.a) do table.insert(A, centre + Vector3.new(o[1], 0, o[2])) end
		for _, o in ipairs(S.b) do table.insert(B, centre + Vector3.new(o[1], 0, o[2])) end
		local sa, sb = H.pickSpawn(ring, B, A), H.pickSpawn(ring, A, B)
		eq(name .. " A side P" .. i, sa and (sa.X < centre.X and "W" or "E"), S.wantA)
		eq(name .. " B side P" .. i, sb and (sb.X < centre.X and "W" or "E"), S.wantB)
	end
end
-- ring falls back through the radii; bad ground -> no spot
local ring2 = H.ringSpots(Vector3.zero, function(v) if v.Magnitude > 330 then return v end return nil end)
eq("first good radius 340", ring2[1] and ring2[1].Magnitude, 340, 1e-6)
eq("no ground -> empty", #H.ringSpots(Vector3.zero, function() return nil end), 0)
-- never within 150 of an enemy; nil when every spot is too close
local one = {Vector3.new(0, 0, 0), Vector3.new(500, 0, 0)}
eq("skip near enemy", H.pickSpawn(one, {Vector3.new(149, 0, 0)}, {}), Vector3.new(500, 0, 0))
eq("all near -> nil", H.pickSpawn({Vector3.new(0, 0, 0)}, {Vector3.new(100, 0, 0)}, {}), nil)
eq("no enemies: near a mate", H.pickSpawn(one, {}, {Vector3.new(480, 0, 0)}), Vector3.new(500, 0, 0))
if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
