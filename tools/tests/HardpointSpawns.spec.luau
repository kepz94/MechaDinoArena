-- HardpointSpawns.spec v1.0 (Mecha Dino Arena) — HardpointRules 1.1 spawns v2 (plan docs/plans/HARDPOINT_SPAWNS_MARKER_v1.0.md
-- Task 1, MDA-421). The 1.0 spec (HardpointRules.spec.luau) stays as it is.
-- Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.HardpointSpawns_spec, clone + require); returns "PASS n" or "FAIL ...".
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
eq("version", H.VERSION, "1.1"); eq("dirs", H.BAND_DIRS, 24); eq("radii n", #H.BAND_RADII, 4); eq("r1", H.BAND_RADII[1], 420)
eq("r4", H.BAND_RADII[4], 600); eq("extra", #H.BAND_EXTRA_RADII, 2); eq("min spots", H.BAND_MIN_SPOTS, 8)
eq("min enemy", H.MIN_ENEMY, 250); eq("cap2", H.ENEMY_CAP2, 600); eq("seen pen", H.SEEN_PEN, 400); eq("sight max", H.SIGHT_MAX, 700)
eq("open apart", H.OPEN_MIN_APART, 600); eq("open diff", H.OPEN_MAX_DIFF, 60)
-- 1.0 untouched
eq("1.0 ring dirs", H.RING_DIRS, 12); eq("1.0 near enemy", H.NEAR_ENEMY, 150); eq("1.0 cap", H.ENEMY_CAP, 350)

-- bandSpots
local C = V(0, 10, 0)
local all = H.bandSpots(C, function(p) return p end)
eq("band all", #all, 96)
local minR, maxR = math.huge, 0
for _, s in ipairs(all) do local r = flat(s, C) minR = math.min(minR, r) maxR = math.max(maxR, r) end
eq("band min r", minR, 420, 1e-3); eq("band max r", maxR, 600, 1e-3)
local east = H.bandSpots(C, function(p) if p.X > 1e-3 then return p end return nil end)
eq("band east half", #east, 44) -- 11 directions with x > 0 (0° .. 75° and 285° .. 345°; 90° / 270° have x = 0) x 4 radii
local few = H.bandSpots(C, function(p)
	local r = flat(p, C)
	local a = math.deg(math.atan2(p.Z, p.X)) % 360
	if a < 50 and (math.abs(r - 420) < 1e-3 or math.abs(r - 360) < 1e-3) then return p end
	return nil
end)
eq("band few -> extra", #few, 8) -- 0°, 15°, 30°, 45° at 420 = 4 (< 8) -> the extra radii add 360 at the same 4
eq("band nil centre", #H.bandSpots(nil, function(p) return p end), 0)
eq("band nil fn", #H.bandSpots(C, nil), 0)

-- scoreSpawn
local S = V(500, 0, 0)
eq("score empty", H.scoreSpawn(S, {}, {}, false), 600)
eq("score nil lists", H.scoreSpawn(S, nil, nil, false), 600)
eq("score enemy 249 skip", H.scoreSpawn(S, {V(251, 0, 0)}, {}, false), nil)
eq("score enemy 250", H.scoreSpawn(S, {V(250, 0, 0)}, {}, false), 250)
eq("score enemy far capped", H.scoreSpawn(S, {V(-500, 0, 0)}, {}, false), 600)
eq("score nearest enemy", H.scoreSpawn(S, {V(-500, 0, 0), V(100, 0, 0)}, {}, false), 400)
eq("score mate 100", H.scoreSpawn(S, {}, {V(400, 0, 0)}, false), 600 + 0.4 * 200)
eq("score mate far", H.scoreSpawn(S, {}, {V(0, 0, 0)}, false), 600)
eq("score seen", H.scoreSpawn(S, {}, {}, true), 200)
eq("score flat (height ignored)", H.scoreSpawn(S, {V(500, 400, 300)}, {}, false), 300)
eq("score bad spot", H.scoreSpawn(nil, {}, {}, false), nil)

-- pickScored
local spots = {V(500, 0, 0), V(-500, 0, 0), V(0, 0, 500)}
local enemies = {V(-450, 0, 0)}
local got = H.pickScored(spots, enemies, {}, function() return false end)
eq("pick far from enemy", got, V(500, 0, 0))
got = H.pickScored(spots, enemies, {}, function(s) return s == V(500, 0, 0) end)
eq("pick unseen over seen", got, V(0, 0, 500)) -- 500,0,0 = 600 - 400 = 200; 0,0,500 = min(673,600) = 600
local asked = {}
H.pickScored(spots, enemies, {}, function(s) asked[#asked + 1] = s return false end)
eq("seenFn not asked for skipped", #asked, 2)
got = H.pickScored({V(-500, 0, 0)}, enemies, {}, nil)
eq("all skipped -> nil", got, nil)
local g2, sc = H.pickScored(spots, {}, {V(0, 0, 450)}, nil)
eq("mates pull", g2, V(0, 0, 500)); eq("mates score", sc, 600 + 0.4 * 250)
eq("pick tie first", H.pickScored({V(500, 0, 0), V(-500, 0, 0)}, {}, {}, nil), V(500, 0, 0))
eq("pick none", H.pickScored({}, {}, {}, nil), nil)

-- pickOpening
local ring = {V(500, 0, 0), V(-500, 0, 0), V(0, 0, 520), V(0, 0, -430)}
local a, b = H.pickOpening(ring, V(0, 0, 0), function() return false end)
eq("open best a", a, V(500, 0, 0)); eq("open best b", b, V(-500, 0, 0))
a, b = H.pickOpening(ring, V(0, 0, 0), function(x, y) return (x == V(500, 0, 0) and y == V(-500, 0, 0)) end)
-- next by distance apart: (0,0,520)-(0,0,-430) is 950 but differs by 90 (> 60) -> not a pair; then (500,0,0)/(0,0,520) 721 diff 20
eq("open next a", a, V(500, 0, 0)); eq("open next b", b, V(0, 0, 520))
a, b = H.pickOpening({V(300, 0, 0), V(-200, 0, 0)}, V(0, 0, 0), nil)
eq("open too close", a, nil)
a, b = H.pickOpening({V(500, 0, 0), V(-400, 0, 0)}, V(0, 0, 0), nil)
eq("open unequal (100 > 60)", a, nil)
a, b = H.pickOpening(ring, V(0, 0, 0), function() return true end)
eq("open all seen", a, nil)
eq("open nil centre", (H.pickOpening(ring, nil, nil)), nil)

-- pickNear
local pts = {V(100, 0, 0), V(200, 0, 0), V(300, 0, 0)}
eq("near", H.pickNear(pts, V(0, 0, 0), nil), V(100, 0, 0))
eq("near taken", H.pickNear(pts, V(0, 0, 0), function(s) return s == V(100, 0, 0) end), V(200, 0, 0))
eq("near all taken", H.pickNear(pts, V(0, 0, 0), function() return true end), V(100, 0, 0))
eq("near none", H.pickNear({}, V(0, 0, 0), nil), nil)
eq("near nil anchor", H.pickNear(pts, nil, nil), nil)

if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
