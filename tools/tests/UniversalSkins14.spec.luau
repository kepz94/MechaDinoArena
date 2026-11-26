-- UniversalSkins14.spec v1.0 (Mecha Dino Arena) — island streak unlocks (UniversalSkins 1.4). Run in Studio Edit; "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("UniversalSkins")
local ok, US = pcall(function() local c = src:Clone() c.Parent = workspace local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(US) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
eq("version", US.VERSION, "1.4")
eq("flag", US.ISLAND_STREAK_UNLOCKS, true)
local h, n = US.progress("zebra", {istreak = 4})
eq("zebra have 4", h, 4) eq("zebra need 10", n, 10)
eq("zebra locked at 4", US.unlocked("zebra", {istreak = 4}), false)
eq("zebra at 10", US.unlocked("zebra", {istreak = 10}), true)
eq("zebra ignores wins", US.unlocked("zebra", {w = 99}), false)
eq("storm kind", US.get("storm").unlock.kind, "earn")
eq("storm at 24", US.unlocked("storm", {istreak = 24}), false)
eq("storm at 25", US.unlocked("storm", {istreak = 25}), true)
eq("zebra text", US.get("zebra").unlock.text, "Get a 10 kill streak on the island")
eq("storm text", US.get("storm").unlock.text, "Get a 25 kill streak on the island")
eq("storm anim kept", US.get("storm").anim, true)
-- every other skin as 1.3
local OLD = {desert = "earn:matches:3", riverstone = "earn:kills:25", canopy = "earn:wins:5", ghostbark = "earn:kills:100",
	inkwar = "earn:best:3", arctic = "robux:RARE:149", sakura = "robux:RARE:149", vipergold = "robux:RARE:149", chrome = "robux:RARE:149",
	lava = "robux:EPIC:499", venom = "robux:EPIC:499", circuit = "robux:EPIC:499", gold = "robux:EPIC:499", obsidianfang = "robux:EPIC:499",
	prism = "robux:LEGENDARY:999", voidmatter = "robux:LEGENDARY:999", spectral = "robux:LEGENDARY:999", elementx = "robux:LEGENDARY:999",
	glitch = "robux:LEGENDARY:999", bloodline = "robux:LEGENDARY:999", hellfire = "robux:LEGENDARY:999"}
for id, want in pairs(OLD) do
	local u = US.get(id).unlock
	local got = u.kind == "earn" and ("earn:" .. u.stat .. ":" .. u.need) or ("robux:" .. tostring(u.rarity) .. ":" .. tostring(u.price))
	eq("unchanged " .. id, got, want)
end
eq("riverstone kills", US.unlocked("riverstone", {kills = 25}), true)
eq("inkwar best", US.unlocked("inkwar", {best = 3}), true)
eq("order has storm", table.find(US.ORDER, "storm") ~= nil, true)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
