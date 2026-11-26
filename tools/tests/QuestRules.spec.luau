-- QuestRules.spec v1.0 (Mecha Dino Arena) — run in Studio Edit; returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("QuestRules")
if not src then return "FAIL missing ServerStorage.DinoArcade.QuestRules" end
local ok, Q = pcall(function() local c = src:Clone() c.Parent = workspace local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(Q) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
eq("version", Q.Version, "1.0")
eq("day 0", Q.day(0), 0)
eq("day 1", Q.day(86400 * 20000 + 5), 20000)
eq("secsToDay", Q.secsToDay(86400 * 3 + 100), 86300)
local owned = {"Raptor", "Pachy"}
local a, b = Q.pickDailies(20418, 8595585713, owned), Q.pickDailies(20418, 8595585713, owned)
for d = 1, 3 do eq("same pick " .. d, a[d].id, b[d].id) eq("diff " .. d, a[d].diff, d) eq("pts " .. d, a[d].pts, d) end
-- 400 player-days: kinds differ, dino from owned, text filled, needs from POOL
local bad, dinoSeen, kindsSeen = 0, 0, {}
for day = 20000, 20019 do
	for u = 1, 20 do
		local p = Q.pickDailies(day, u * 977, owned)
		local seen = {}
		for d = 1, 3 do
			local q = p[d]
			if seen[q.kind] then bad += 1 end
			seen[q.kind] = true
			kindsSeen[q.kind .. d] = true
			if q.need ~= Q.POOL[q.kind][d].need then bad += 1 end
			if q.kind == "dino" then
				dinoSeen += 1
				if q.dino ~= "Raptor" and q.dino ~= "Pachy" then bad += 1 end
				if not q.text:find(Q.DINO_NAMES[q.dino], 1, true) then bad += 1 end
			end
			if q.text:find("%%") then bad += 1 end
		end
	end
end
eq("no bad picks", bad, 0)
eq("dino quests happen", dinoSeen > 0, true)
eq("istreak never easy", kindsSeen.istreak1 == nil, true)
eq("akills never easy", kindsSeen.akills1 == nil, true)
eq("hard parts seen", kindsSeen.parts3, true)
-- no owned dinos -> never a dino quest
local none = 0
for day = 20000, 20049 do for d = 1, 3 do if Q.pickDailies(day, 5, {})[d].kind == "dino" then none += 1 end end end
eq("no dino without owned", none, 0)
eq("istreak max mode", Q.POOL.istreak[2].mode, "max")
local sp = Q.specials()
eq("2 specials", #sp, 2)
eq("zebra 10", sp[1].skin == "zebra" and sp[1].need, 10)
eq("storm 25", sp[2].skin == "storm" and sp[2].need, 25)
eq("claimable yes", Q.claimable(5, 5, false), true)
eq("claimable short", Q.claimable(5, 4, false), false)
eq("claimable claimed", Q.claimable(5, 9, true), false)
local ol = Q.ownedList("Raptor,TRex")
eq("ownedList", #ol == 2 and ol[2], "TRex")
eq("ownedList nil", #Q.ownedList(nil), 0)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
