-- SkillTreeUnlock.spec v1.0 (Mecha Dino Arena) — SkillTree 1.96 unlock-only helpers (MDA-613, plan docs/plans/UNLOCK_ONLY_v1.0.md
-- Task 1). Run in Studio Edit (clone + require of ServerStorage.DinoArcade.SkillTree); returns "PASS n" or "FAIL ...".
local ok, ST = pcall(function()
	local src = game.ServerStorage.DinoArcade.SkillTree
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(ST) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
eq("PART_PRICE", ST.PART_PRICE, 10)
eq("isPart screech Raptor", ST.isPart("screech", "Raptor"), true)
eq("isPart regen Raptor (stat row)", ST.isPart("regen", "Raptor"), false)
eq("isPart screech Pachy (other dino)", ST.isPart("screech", "Pachy"), false)
eq("isPart unknown", ST.isPart("nope", "Raptor"), false)
eq("isPart nil", ST.isPart(nil, "Raptor"), false)
local soonId
for _, id in ipairs(ST.PATH_ORDER) do local p = ST.PATHS[id] if p.mech and p.soon then soonId = id break end end
if soonId then eq("isPart soon " .. soonId, ST.isPart(soonId, nil), false) end
local u = ST.unlockSteps({screech = 3, regen = 4, traps = 0}, "Raptor", {traps = true})
eq("screech 3 -> 1", u.screech, 1)
eq("regen 4 -> 0", u.regen, 0)
eq("given traps 0 -> 1", u.traps, 1)
eq("cloak unowned -> 0", u.cloak, 0)
local o = ST.unlockSteps({hookarm = 4}, "Raptor")
eq("other dino's part -> 0", o.hookarm, 0)
local z = ST.unlockSteps(nil, "Raptor")
local any = 0 for _, v in pairs(z) do any += v end
eq("nil steps all 0", any, 0)
local n = 0 for _ in pairs(z) do n += 1 end
eq("every path present", n, #ST.PATH_ORDER)
for _, dino in ipairs({"Raptor", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}) do
	local all = {}
	for _, id in ipairs(ST.PATH_ORDER) do all[id] = 4 end
	local okE, e = pcall(ST.effects, ST.unlockSteps(all, dino), dino)
	eq("effects " .. dino, okE and type(e) == "table", true)
end
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
