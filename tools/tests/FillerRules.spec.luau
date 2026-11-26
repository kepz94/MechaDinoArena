-- FillerRules.spec v1.0 (Mecha Dino Arena) — FillerRules 1.0 (Filler Bots v1.0, plan docs/plans/FILLER_BOTS_v1.0.md T1, MDA-573).
-- Run in Studio Edit (clone + require ServerStorage.DinoArcade.FillerRules); returns "PASS n" or "FAIL ...".
local DA = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
local src = DA and DA:FindFirstChild("FillerRules")
if not src then return "FAIL require: ServerStorage.DinoArcade.FillerRules missing" end
local ok, R = pcall(function() local c = src:Clone() c.Parent = src.Parent local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(R) end
local PR = DA:FindFirstChild("PracticeRules") and require(DA.PracticeRules:Clone())
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local function yes(name, cond) eq(name, cond == true, true) end

-- names: 1000 unique, valid, never a practice name
local practice = {}
if PR then for _, n in ipairs(PR.NAMES) do practice[n] = true end end
local rng = Random.new(42)
local used = {}
local bad, dup, prac, lens = 0, 0, 0, 0
for i = 1, 1000 do
	local n = R.name(rng, used)
	if used[n] ~= true then dup += 1 end -- name() marks it used
	if type(n) ~= "string" or #n < 3 or #n > 20 or n:find("[^%w_]") or select(2, n:gsub("_", "")) > 1
		or n:sub(1, 1) == "_" or n:sub(-1) == "_" then bad += 1 end
	if practice[n] then prac += 1 end
end
local count = 0
for _ in pairs(used) do count += 1 end
eq("1000 names unique", count, 1000)
eq("names marked used", dup, 0)
eq("names valid", bad, 0)
eq("never a practice name", prac, 0)
yes("valid() accepts a good name", R.valid("MossyClaw27"))
yes("valid() refuses two underscores", not R.valid("a_b_c"))
yes("valid() refuses a space", not R.valid("Mossy Claw"))
yes("valid() refuses too long", not R.valid(string.rep("a", 21)))

-- record: stable, ranges
local w1, l1 = R.record("MossyClaw")
local w2, l2 = R.record("MossyClaw")
eq("record stable w", w1, w2)
eq("record stable l", l1, l2)
local outG, outR, total, low = 0, 0, 0, 0
for i = 1, 2000 do
	local n = "Name" .. i
	local w, l = R.record(n)
	local g = w + l
	if g < 6 or g > 220 or w ~= math.floor(w) or l ~= math.floor(l) then outG += 1 end
	local rate = w / g
	if rate < 0.35 or rate > 0.65 then outR += 1 end
	if g >= 20 and g <= 90 then low += 1 end
	total += 1
end
eq("games 6..220", outG, 0)
eq("win rate ~0.36..0.64", outR, 0)
yes("most records 20..90 games", low / total > 0.45)

-- wanted
eq("0 real -> 0", R.wanted(0, 8), 0)
eq("1 real -> 7", R.wanted(1, 8), 7)
eq("7 real -> 1", R.wanted(7, 8), 1)
eq("8 real -> 0", R.wanted(8, 8), 0)
eq("12 real -> 0", R.wanted(12, 8), 0)
eq("bad input -> 0", R.wanted(nil, 8), 0)
eq("fillTo 6, 1 real -> 5", R.wanted(1, 6), 5)

-- look
local r2 = Random.new(7)
local classic, none, n = 0, 0, 400
for i = 1, n do
	local s, t = R.look(r2, {"classic", "lava", "night"}, {"neon", "comet"})
	if s == "classic" then classic += 1 end
	if t == "" then none += 1 end
	yes("skin from list " .. i, s == "classic" or s == "lava" or s == "night")
end
yes("classic ~40%", classic / n > 0.3 and classic / n < 0.5)
yes("no trail ~30%", none / n > 0.2 and none / n < 0.4)
local s0, t0 = R.look(r2, {}, {})
eq("empty lists skin", s0, "classic")
eq("empty lists trail", t0, "")

-- emote
local r3 = Random.new(3)
local ids = {"party", "stomp"}
eq("no ids -> nil", R.emote(r3, {afterKill = true, emoteIds = {}}), nil)
local afterK = 0
for i = 1, 400 do if R.emote(r3, {afterKill = true, emoteIds = ids}) then afterK += 1 end end
yes("after a kill ~half", afterK > 150 and afterK < 250)
yes("idle in safe after the gap", R.emote(r3, {inSafe = true, idleFor = 30, idleNeed = 25, emoteIds = ids}) ~= nil)
eq("idle in safe before the gap", R.emote(r3, {inSafe = true, idleFor = 10, idleNeed = 25, emoteIds = ids}), nil)
eq("idle outside the safe area", R.emote(r3, {inSafe = false, idleFor = 60, idleNeed = 25, emoteIds = ids}), nil)

-- timings and tiers
local r4 = Random.new(9)
local okJ, okG, hard = true, true, 0
for i = 1, 300 do
	local j = R.joinDelay(r4)
	if j < 8 or j > 20 then okJ = false end
	local g = R.idleGap(r4)
	if g < 20 or g > 45 then okG = false end
	if R.tier(r4) == "Hard" then hard += 1 end
end
yes("joinDelay 8..20", okJ)
yes("idleGap 20..45", okG)
yes("Hard ~40%", hard / 300 > 0.3 and hard / 300 < 0.5)
eq("respawnDelay", R.respawnDelay(), 5)
eq("leaveWalkMax", R.leaveWalkMax(), 25)

if #fails > 0 then return "FAIL " .. #fails .. " of " .. (#fails + passes) .. ": " .. table.concat(fails, " | ", 1, math.min(#fails, 8)) end
return "PASS " .. passes
