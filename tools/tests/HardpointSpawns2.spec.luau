-- HardpointSpawns2.spec v1.0 (Mecha Dino Arena) — HardpointRules 1.2 band 2 + start sides by run (plan
-- docs/plans/HUD_SLIM_SPAWNS_FAR_v1.0.md Task 1, MDA-425). The 1.0 / 1.1 specs stay as they are.
-- Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.HardpointSpawns2_spec, clone + require); returns "PASS n" or "FAIL ...".
local DA = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
local src = DA and DA:FindFirstChild("HardpointRules")
if not src then return "FAIL require: ServerStorage.DinoArcade.HardpointRules missing" end
local ok, H = pcall(function() local c = src:Clone() c.Parent = src.Parent local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(H) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-6) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local V = Vector3.new
local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end

-- numbers
eq("version", H.VERSION, "1.2"); eq("b2 n", #H.BAND2_RADII, 5); eq("b2 r1", H.BAND2_RADII[1], 700); eq("b2 r5", H.BAND2_RADII[5], 900)
eq("b2 extra n", #H.BAND2_EXTRA_RADII, 2); eq("b2 extra 1", H.BAND2_EXTRA_RADII[1], 650); eq("b2 extra 2", H.BAND2_EXTRA_RADII[2], 600)
eq("sight2", H.SIGHT_MAX2, 1000); eq("apart2", H.OPEN_MIN_APART2, 900); eq("run diff", H.OPEN_RUN_DIFF, 60)
-- 1.1 untouched
eq("1.1 radii", H.BAND_RADII[1], 420); eq("1.1 sight", H.SIGHT_MAX, 700); eq("1.1 apart", H.OPEN_MIN_APART, 600)

-- bandSpots with band 2
local C = V(0, 10, 0)
local all = H.bandSpots(C, function(p) return p end, H.BAND2_RADII, H.BAND2_EXTRA_RADII)
eq("b2 all", #all, 120)
local minR, maxR = math.huge, 0
for _, s in ipairs(all) do local r = flat(s, C) minR = math.min(minR, r) maxR = math.max(maxR, r) end
eq("b2 min r", minR, 700, 1e-3); eq("b2 max r", maxR, 900, 1e-3)
eq("1.1 default still 96", #H.bandSpots(C, function(p) return p end), 96)
local few = H.bandSpots(C, function(p)
	local r = flat(p, C)
	local a = math.deg(math.atan2(p.Z, p.X)) % 360
	if a < 50 and (math.abs(r - 900) < 1e-3 or math.abs(r - 650) < 1e-3) then return p end
	return nil
end, H.BAND2_RADII, H.BAND2_EXTRA_RADII)
eq("b2 few -> extra", #few, 8) -- 0/15/30/45 deg at 900 = 4 (< 8) -> 650 adds 4
local enough = H.bandSpots(C, function(p)
	if math.abs(flat(p, C) - 650) < 1e-3 then return p end
	if p.X > 1e-3 and math.abs(flat(p, C) - 700) < 1e-3 then return p end
	return nil
end, H.BAND2_RADII, H.BAND2_EXTRA_RADII)
eq("b2 enough -> no extra", #enough, 11) -- 11 directions with x > 0 at 700 (>= 8): no 650 ring

-- pickOpeningByRun
local A, B, Cc, D = V(800, 0, 0), V(-800, 0, 0), V(0, 0, 820), V(0, 0, -760)
local spots = {A, B, Cc, D}
local runs = {[A] = 900, [B] = 1100, [Cc] = 1000, [D] = 1020}
local function run(s) return runs[s] end
-- A/B are 1600 apart but runs differ 200; C/D are 1580 apart, runs differ 20 -> C, D
local a, b = H.pickOpeningByRun(spots, nil, run)
eq("run pair a", a, Cc); eq("run pair b", b, D)
-- equal runs for A/B -> the furthest pair A/B
runs[B] = 930
a, b = H.pickOpeningByRun(spots, nil, run)
eq("furthest equal a", a, A); eq("furthest equal b", b, B)
-- diff 60 ok, 61 rejected
runs[B] = 960
a, b = H.pickOpeningByRun({A, B}, nil, run); eq("diff 60 ok", a, A)
runs[B] = 961
a, b = H.pickOpeningByRun({A, B}, nil, run); eq("diff 61 rejected", a, nil)
-- no path -> spot left out
runs[B] = 900
local noB = function(s) if s == B then return nil end return runs[s] end
a, b = H.pickOpeningByRun({A, B}, nil, noB); eq("no path skipped", a, nil)
a, b = H.pickOpeningByRun(spots, nil, noB); eq("no path -> C/D a", a, Cc); eq("no path -> C/D b", b, D)
-- seen pair rejected -> next
a, b = H.pickOpeningByRun(spots, function(x, y) return x == A and y == B end, run)
eq("seen -> next a", a, Cc); eq("seen -> next b", b, D)
a, b = H.pickOpeningByRun(spots, function() return true end, run); eq("all seen", a, nil)
-- too close (< 900)
a, b = H.pickOpeningByRun({V(440, 0, 0), V(-440, 0, 0)}, nil, function() return 800 end); eq("880 apart rejected", a, nil)
a, b = H.pickOpeningByRun({V(450, 0, 0), V(-450, 0, 0)}, nil, function() return 800 end); eq("900 apart ok", a, V(450, 0, 0))
-- custom thresholds
a, b = H.pickOpeningByRun({V(300, 0, 0), V(-300, 0, 0)}, nil, function() return 500 end, 600, 10); eq("custom apart", a, V(300, 0, 0))
-- ties = first found
local P1, P2, P3, P4 = V(500, 0, 0), V(-500, 0, 0), V(0, 0, 500), V(0, 0, -500)
a, b = H.pickOpeningByRun({P1, P2, P3, P4}, nil, function() return 600 end)
eq("tie first a", a, P1); eq("tie first b", b, P2)
-- bad input
eq("no runFn", (H.pickOpeningByRun(spots, nil, nil)), nil)
eq("empty", (H.pickOpeningByRun({}, nil, run)), nil)
eq("nil spots", (H.pickOpeningByRun(nil, nil, run)), nil)

if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
