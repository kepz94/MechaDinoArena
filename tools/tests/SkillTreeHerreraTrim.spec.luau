-- SkillTreeHerreraTrim.spec v1.1 (Mecha Dino Arena) — SkillTree 1.47 Herrera trim (Kepu 2026-11-01 "Trim overlap"). Run in
-- Studio Edit (loadstring(Source)()); returns "PASS n" or "FAIL ...".
-- v1.1 (SkillTree 1.73 balance pass 1, MDA-358): while ST.BALANCE_PASS1 the base is HerreraModelData 1.5 (slash 15, refill 2.5 s,
--   3 charges, bleed 4): Razor Claws III bleed 5, texts "slash 15 -> 18", "(2.5 s -> 1.6 s)", "5 per second (was 4)", "A 4th slash charge".
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
local P = ST.PATHS
eq("switch", ST.HERRERA_TRIM, true)
-- removed rows
eq("regen hidden herrera", ST.seesPath(P.regen, "Herrera"), false)
eq("siphon hidden herrera", ST.seesPath(P.siphon, "Herrera"), false)
eq("ironclaw hidden herrera", ST.seesPath(P.ironclaw, "Herrera"), false)
eq("regen raptor kept", ST.seesPath(P.regen, "Raptor"), true)
eq("regen trex still hidden", ST.seesPath(P.regen, "TRex"), false)
for _, d in ipairs({"TRex", "Raptor", "Pachy", "Teno"}) do
	eq("siphon " .. d, ST.seesPath(P.siphon, d), false); eq("ironclaw " .. d, ST.seesPath(P.ironclaw, d), false)
end
local s = ST.sanitize({regen = 4, siphon = 4, ironclaw = 4, lifesteal = 2, jaws = 1}, "Herrera")
eq("sanitize regen", s.regen, 0); eq("sanitize siphon", s.siphon, 0); eq("sanitize ironclaw", s.ironclaw, 0)
eq("sanitize keeps lifesteal", s.lifesteal, 2); eq("sanitize keeps jaws", s.jaws, 1)
eq("refund: spent counts only kept rows", ST.spent({regen = 4, siphon = 4, ironclaw = 4, lifesteal = 2, jaws = 1}, "Herrera"),
	ST.spent({lifesteal = 2, jaws = 1}, "Herrera"))
local H = function(t) return ST.effects(t, "Herrera") end
local z = H({regen = 4, siphon = 4, ironclaw = 4})
eq("no regen rate", z.regenRate, 0); eq("no siphon", z.siphonRate, 0); eq("no siphon kill heal", z.siphonKillHeal, 0)
eq("no iron claw mul", z.ironClawDamageMul, 1); eq("no iron claw slow", z.ironClawSpeedMul, 1)
-- numbers
eq("razor I attack 3", H({jaws = 1}).attackPts, 3)
eq("razor III bleed", H({jaws = 3}).slashBleedDps, ST.BALANCE_PASS1 and 5 or 3) -- v1.1
eq("razor II refill kept", H({jaws = 2}).slashRefillMul, 0.65); eq("razor star charge kept", H({jaws = 4}).slashExtraCharges, 1)
eq("frenzy II 5 s", H({frenzy = 2}).slashBleedTime, 5); eq("frenzy III +2", H({frenzy = 3}).bleedBonus, 2)
eq("frenzy I speed kept", H({frenzy = 1}).frenzySpeedMul, 1.1); eq("frenzy star kept", H({frenzy = 4}).killRefill, true)
eq("unbought razor 0", H({}).attackPts, 0); eq("unbought frenzy 0", H({}).slashBleedTime, 0)
-- texts
local js = P.jaws.stepsFor.Herrera
eq("razor I text", js[1], ST.BALANCE_PASS1 and "Slash hits harder (+3 Attack points: slash 15 -> 18)" or "Slash hits harder (+3 Attack points: slash 7 -> 10)")
eq("razor III text", js[3], ST.BALANCE_PASS1 and "Bleed burns hotter: 5 per second (was 4)" or "Bleed burns hotter: 3 per second (was 2)")
if ST.BALANCE_PASS1 then -- v1.1
	eq("razor II text", js[2], "Slash charges refill 35% faster (2.5 s -> 1.6 s)")
	eq("razor star text", js[4], "A 4th slash charge")
end
eq("frenzy II text", P.frenzy.steps[2], "Bleed lasts 5 s (was 4)")
eq("frenzy III text", P.frenzy.steps[3], "Slash a bleeding dino: +2 damage")
-- other dinos unchanged
eq("trex jaws I attack", ST.effects({jaws = 1}, "TRex").attackPts, 5)
eq("raptor regen III", ST.effects({regen = 3}, "Raptor").regenRate, 0.045)
eq("teno brace kept", ST.effects({brace = 1}, "Teno").braceMul, 0.8)
-- the Herrera's rows now
local seen = {}
for _, a in ipairs(ST.AREAS) do
	for _, p in ipairs(ST.pathsFor(a.id, "Herrera")) do if not p.mech then table.insert(seen, p.id) end end
end
eq("herrera stat rows", table.concat(seen, ","), "lifesteal,jaws,frenzy,hide,plating,legs,stalker")
if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
