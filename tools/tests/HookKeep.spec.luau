-- HookKeep.spec v1.0 (Mecha Dino Arena) — SkillTree 1.90 HOOK_KEEP_OTHERS: the pachy Grappling Hook keeps its numbers (#36).
-- Run in Studio Edit (clones ServerStorage.DinoArcade.SkillTree); returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("SkillTree")
if not src then return "FAIL require: SkillTree missing" end
local c = src:Clone() c.Parent = src.Parent
local okR, T = pcall(require, c)
c:Destroy()
if not okR then return "FAIL require: " .. tostring(T) end
local fails, passes = {}, 0
local function eq(name, got, want) if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end end
eq("switch", T.HOOK_KEEP_OTHERS, true)
-- pachy: 1.21 numbers (range 60 / 80, cooldown 8 / 6), then SHOT_RANGE_KEYS doubles the range
local base = {}
for lvl = 1, 4 do
	local e = T.effects({hookarm = lvl}, "Pachy")
	eq("pachy " .. lvl .. " range > 0", (e.hookRange or 0) > 0, true)
	eq("pachy " .. lvl .. " cooldown", e.hookCooldown, lvl >= 3 and 6 or 8)
	eq("pachy " .. lvl .. " damage", e.hookDamage, lvl >= 4 and 15 or 10)
	base[lvl] = e.hookRange
end
eq("pachy II reaches further", base[2] > base[1], true)
eq("pachy none", T.effects({}, "Pachy").hookRange, 0)
eq("pachy none cd", T.effects({}, "Pachy").hookCooldown, 0)
-- other dinos stay 0
for _, d in ipairs({"Raptor", "Troodon", "Teno", "Herrera", "Dilo"}) do eq(d .. " range", T.effects({}, d).hookRange, 0) end
-- therizino unchanged by the switch
local on = T.effects({zhook = 3}, "Therizino")
T.HOOK_KEEP_OTHERS = false
local off = T.effects({zhook = 3}, "Therizino")
local pOff = T.effects({hookarm = 2}, "Pachy")
T.HOOK_KEEP_OTHERS = true
eq("theri same range", on.hookRange, off.hookRange)
eq("theri same cd", on.hookCooldown, off.hookCooldown)
eq("theri range > 0", (on.hookRange or 0) > 0, true)
eq("switch off = 1.89 (pachy 0)", pOff.hookRange, 0)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
