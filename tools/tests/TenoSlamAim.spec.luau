-- TenoSlamAim.spec v1.0 (Mecha Dino Arena) — tests for ServerStorage.DinoArcade.TenoSlamAim 1.0 (plan
-- docs/plans/TENO_SLAM_REWORK_v1.0.md Task 1). Run in Studio Edit (loadstring(Source)()); returns "PASS n" or "FAIL ...".
local ok, A = pcall(function()
	local src = game.ServerStorage.DinoArcade.TenoSlamAim
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(A) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-6) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local S = {reach = 37, aimMax = 35, cone = 70}
local function ids(list) local t = {} for _, c in ipairs(list) do table.insert(t, c.id) end table.sort(t) return table.concat(t, ",") end

-- nobody: straight back
local r = A.pick({}, S)
eq("empty yaw", r.yaw, 0); eq("empty target", r.target, nil); eq("empty members", #r.members, 0)
-- front and mid section are never hit
r = A.pick({{id = "front", x = 0, z = -10, gap = 6}, {id = "side", x = 12, z = 0, gap = 9}, {id = "mid", x = 4, z = -1, gap = 2}}, S)
eq("front/side/mid not hit", #r.members, 0); eq("front/side/mid no aim", r.target, nil)
-- straight behind in reach
r = A.pick({{id = "b", x = 0, z = 20, gap = 18}}, S)
eq("behind aimed", r.target and r.target.id, "b"); eq("behind yaw", r.yaw, 0); eq("behind hit", ids(r.members), "b")
-- out of reach
r = A.pick({{id = "far", x = 0, z = 45, gap = 40}}, S)
eq("out of reach", #r.members, 0)
-- soft aim turns the tail: a target 30 deg to the left
local x30, z30 = 20 * math.sin(math.rad(30)), 20 * math.cos(math.rad(30))
r = A.pick({{id = "l30", x = x30, z = z30, gap = 18}}, S)
eq("aim 30 left", r.yaw, 30, 1e-4); eq("aim 30 hit", ids(r.members), "l30")
-- beyond the aim limit (50 deg) is not aimed and not hit when alone
local x50, z50 = 20 * math.sin(math.rad(50)), 20 * math.cos(math.rad(50))
r = A.pick({{id = "l50", x = x50, z = z50, gap = 18}}, S)
eq("50 deg not aimed", r.target, nil); eq("50 deg not hit (cone 35 around 0)", #r.members, 0)
-- but it is hit when the aim swung 30 left (50 - 30 = 20 <= 35)
r = A.pick({{id = "l30", x = x30, z = z30, gap = 18}, {id = "l50", x = x50, z = z50, gap = 18}}, S)
eq("swept by the aim", ids(r.members), "l30,l50")
-- every dino in the tail zone is hit
r = A.pick({{id = "a", x = 0, z = 10, gap = 8}, {id = "b", x = 3, z = 25, gap = 23}, {id = "c", x = -4, z = 30, gap = 28}}, S)
eq("all in zone", ids(r.members), "a,b,c"); eq("closest aimed", r.target.id, "a")
-- score: a near target off-axis vs a far one straight back (bite weights)
r = A.pick({{id = "near", x = 6, z = 10, gap = 9}, {id = "farstraight", x = 0, z = 30, gap = 28}}, S)
eq("near wins", r.target.id, "near")
-- members() with a fixed yaw
eq("members fixed yaw", ids(A.members({{id = "r40", x = -20 * math.sin(math.rad(40)), z = 20 * math.cos(math.rad(40)), gap = 18}}, -30, S)), "r40")
-- bad entries are ignored
r = A.pick({{id = "bad", x = "a", z = 3, gap = 1}, {id = "ok", x = 0, z = 5, gap = 3}}, S)
eq("bad ignored", ids(r.members), "ok")
-- back half
eq("back half", A.backHalf(0.4), true); eq("front half", A.backHalf(-0.4), false); eq("at hips", A.backHalf(0), false); eq("nil", A.backHalf(nil), false)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
