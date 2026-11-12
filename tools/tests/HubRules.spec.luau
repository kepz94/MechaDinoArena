-- HubRules.spec v1.1 (Mecha Dino Arena) — HubRules 1.1 (TRIP_TIME 0) (plan docs/plans/ISLAND_HUB_v1.0.md Task 1, MDA-452).
-- Run in Studio Edit (clones ServerStorage.DinoArcade.HubRules); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("HubRules")
if not src then return "FAIL require: HubRules missing" end
local c = src:Clone() c.Parent = src.Parent
local okR, R = pcall(require, c)
c:Destroy()
if not okR then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want) if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end end

eq("version", R.VERSION, "1.1"); eq("trip", R.TRIP_TIME, 0); eq("trip v10", R.TRIP_TIME_V10, 5); eq("guard", R.GUARD, 3); eq("save", R.SAVE_WAIT, 12)
eq("poll", R.POLL, 0.2); eq("keep", R.KEY_KEEP, 60)
-- kind
local function k(t) return R.kind(t) end
eq("arena", k({placeMode = "arena", hubOn = true}), "arena")
eq("arena hub off", k({placeMode = "arena", hubOn = false}), "arena")
eq("hub off", k({placeMode = "sandbox", hubOn = false, privateId = ""}), "practice")
eq("hub nil", k({placeMode = "sandbox"}), "practice")
eq("studio hub", k({placeMode = "sandbox", hubOn = true, isStudio = true}), "hub")
eq("studio practice", k({placeMode = "sandbox", hubOn = true, isStudio = true, testPractice = true}), "practice")
eq("studio reserved ignored", k({placeMode = "sandbox", hubOn = true, isStudio = true, privateId = "x", ownerId = 0}), "hub")
eq("reserved", k({placeMode = "sandbox", hubOn = true, privateId = "abc", ownerId = 0}), "practice")
eq("vip", k({placeMode = "sandbox", hubOn = true, privateId = "abc", ownerId = 123}), "hub")
eq("public", k({placeMode = "sandbox", hubOn = true, privateId = "", ownerId = 0}), "hub")
eq("public nil id", k({placeMode = "sandbox", hubOn = true}), "hub")
eq("bad", R.kind(nil), "practice")
-- shapes
local cf = CFrame.new(10, 0, 10)
eq("box in", R.inShape(Vector3.new(12, 1, 8), cf, Vector3.new(10, 4, 10), "box"), true)
eq("box edge", R.inShape(Vector3.new(15, 2, 5), cf, Vector3.new(10, 4, 10), "box"), true)
eq("box out x", R.inShape(Vector3.new(15.1, 0, 10), cf, Vector3.new(10, 4, 10), "box"), false)
eq("box out y", R.inShape(Vector3.new(10, 2.5, 10), cf, Vector3.new(10, 4, 10), "box"), false)
local rot = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(45), 0)
eq("box rotated in", R.inShape(Vector3.new(4, 0, 4), rot, Vector3.new(2, 2, 12), "box"), true)
eq("box rotated out", R.inShape(Vector3.new(4, 0, -4), rot, Vector3.new(2, 2, 12), "box"), false)
-- a flat disc: cylinder axis X turned to point up
local disc = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
eq("cyl in", R.inShape(Vector3.new(90, 3, 0), disc, Vector3.new(20, 200, 200), "cyl"), true)
eq("cyl edge", R.inShape(Vector3.new(100, 0, 0), disc, Vector3.new(20, 200, 200), "cyl"), true)
eq("cyl out radius", R.inShape(Vector3.new(80, 0, 80), disc, Vector3.new(20, 200, 200), "cyl"), false)
eq("cyl out height", R.inShape(Vector3.new(0, 11, 0), disc, Vector3.new(20, 200, 200), "cyl"), false)
eq("cyl uneven uses min", R.inShape(Vector3.new(0, 0, 60), disc, Vector3.new(20, 100, 200), "cyl"), false)
eq("shape bad", R.inShape(nil, cf, Vector3.one, "box"), false)
local shapes = {{cf = cf, size = Vector3.new(10, 4, 10), shape = "box"}, {cf = disc, size = Vector3.new(20, 200, 200), shape = "cyl"}}
eq("zone first", R.inZone(Vector3.new(10, 0, 10), shapes), true)
eq("zone second", R.inZone(Vector3.new(-50, 0, 0), shapes), true)
eq("zone none", R.inZone(Vector3.new(300, 0, 0), shapes), false)
eq("zone empty", R.inZone(Vector3.new(0, 0, 0), {}), false)
eq("zone nil", R.inZone(Vector3.new(0, 0, 0), nil), false)
-- protected
eq("prot zone", R.protected(true, nil, 5), true)
eq("prot guard", R.protected(false, 10, 9), true)
eq("prot guard end", R.protected(false, 10, 10), false)
eq("prot none", R.protected(false, nil, 3), false)
-- tripParty
local function party(...) local t, why = R.tripParty(...) return t and table.concat(t, ",") or ("nil " .. tostring(why)) end
eq("solo", party(5, {}), "5")
eq("solo nil", party(5, nil), "5")
eq("empty squad id", party(5, {squadId = "", leaderId = 5, members = {5, 6}}), "5")
eq("no members", party(5, {squadId = "a", leaderId = 5, members = {}}), "5")
eq("leader", party(5, {squadId = "a", leaderId = 5, members = {6, 5, 7}}), "5,6,7")
eq("member", party(6, {squadId = "a", leaderId = 5, members = {5, 6}}), "nil notLeader")
eq("no leader", party(6, {squadId = "a", members = {5, 6}}), "nil notLeader")
-- nextLeader
eq("next earliest", R.nextLeader({{id = 9, joinedAt = 30}, {id = 4, joinedAt = 10}, {id = 7, joinedAt = 20}}), 4)
eq("next tie", R.nextLeader({{id = 9, joinedAt = 10}, {id = 4, joinedAt = 10}}), 4)
eq("next none", R.nextLeader({}), nil)
eq("next no time", R.nextLeader({{id = 3}, {id = 2, joinedAt = 50}}), 2)
-- tripData
local d = R.tripData("arena", "k1", 5, {5, 6}, "hub")
eq("data play", d.mdaPlay, true); eq("data from", d.mdaFrom, "hub"); eq("data mode", d.mdaTrip.mode, "arena")
eq("data key", d.mdaTrip.key, "k1"); eq("data leader", d.mdaTrip.leader, 5); eq("data members", #d.mdaTrip.members, 2)
eq("modes", R.MODES.bots and R.MODES.arena and R.MODES.island and not R.MODES.x, true)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
