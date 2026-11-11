-- LabClipRecipes v1.0 (Mecha Dino Arena) — what each mecha part's Lab clip shows (ModuleScript, StarterPlayerScripts, next to
-- Lab; plan docs/plans/LAB_CLIPS_v1.0.md Task 2, MDA-442; Kepu 2026-11-11 "A · Live clip", "Built in the game", "Dilo
-- first, then the rest"). Pure data + 2 helpers: no instances, no services. Read by Lab 1.15 and LabClipPlayer 1.0.
-- One entry per path id:
--   what      one plain sentence (under the clip)
--   template  "burst" | "lob" | "cone" | "ring" | "self" | "dash" (LabClipPlayer draws it)
--   mode      template variant ("pump" / "over" for self)
--   attach    the part's centre in the dino's rest space (studs at Model scale 1, relative to the HumanoidRootPart, -Z =
--             forward; measured 2026-11-11 from DiloPartsServer's BuildPreview_<id> on a DiloModelData mannequin), used
--             when the part isn't on your dino
--   muzzle    where shots leave (same space; default = attach)
--   chips     {label, key, unit}; unit "studs" / "s" / "°" / "" / "bool" (YES / NO)
--   steps     4 tables of numbers (step I, II, III, ★) — the live numbers, the same as the SkillTree 1.89 step texts
-- Numbers here must change in the same commit as a part's tune (VERSIONS change checklist).
local R = {}
R.VERSION = "1.0"

R.dgatling = {
	what = "Fires a quick burst of auto-aimed darts that poison whoever they hit.",
	template = "burst",
	attach = Vector3.new(0, 2.09, -2.8), muzzle = Vector3.new(0.72, 1.95, -3.48),
	chips = {{"DARTS", "darts", ""}, {"DAMAGE", "dmg", "each"}, {"RECHARGE", "cd", "s"}},
	steps = {{darts = 4, dmg = 3, cd = 12}, {darts = 6, dmg = 3, cd = 12}, {darts = 6, dmg = 3, cd = 10}, {darts = 8, dmg = 3, cd = 10}},
}
R.dmortar = {
	what = "Lobs a canister far ahead that leaves a poison cloud where it lands.",
	template = "lob",
	attach = Vector3.new(0.55, 0.37, -1.71), muzzle = Vector3.new(1.28, 1.91, -2.09),
	chips = {{"REACH", "reach", "studs"}, {"CLOUD", "cloud", "studs"}, {"LASTS", "lasts", "s"}, {"RECHARGE", "cd", "s"}},
	steps = {{reach = 80, cloud = 24, lasts = 3, cd = 16}, {reach = 100, cloud = 30, lasts = 3, cd = 16},
		{reach = 100, cloud = 30, lasts = 4, cd = 16}, {reach = 120, cloud = 36, lasts = 5, cd = 16}},
}
R.dhiss = {
	what = "Blasts a wide cone in front of you: dinos in it are knocked back and their mecha parts shut off.",
	template = "cone",
	attach = Vector3.new(-0.01, 2.64, -2.41),
	chips = {{"RANGE", "range", "studs"}, {"CONE", "cone", "°"}, {"SILENCE", "silence", "s"}, {"RECHARGE", "cd", "s"}},
	steps = {{range = 40, cone = 140, silence = 1.5, cd = 15}, {range = 50, cone = 140, silence = 1.5, cd = 15},
		{range = 50, cone = 140, silence = 2, cd = 12}, {range = 60, cone = 140, silence = 3, cd = 12}},
}
R.dspine = {
	what = "Fires spines out all around you, hitting every dino close by.",
	template = "ring",
	attach = Vector3.new(0, 2.63, -2.63),
	chips = {{"SPINES", "spines", ""}, {"DAMAGE", "dmg", "each"}, {"VENOM", "venom", "bool"}, {"RECHARGE", "cd", "s"}},
	steps = {{spines = 6, dmg = 4, venom = false, cd = 12}, {spines = 8, dmg = 4, venom = false, cd = 12},
		{spines = 8, dmg = 4, venom = true, cd = 12}, {spines = 12, dmg = 4, venom = true, cd = 12}},
}
R.dpump = {
	what = "Clears your debuffs and heals you.",
	template = "self", mode = "pump",
	attach = Vector3.new(0, 1.53, -0.24),
	chips = {{"HEAL", "heal", ""}, {"IMMUNE", "immune", "s"}, {"RECHARGE", "cd", "s"}},
	steps = {{heal = 15, immune = 0, cd = 20}, {heal = 20, immune = 0, cd = 20}, {heal = 30, immune = 0, cd = 20}, {heal = 30, immune = 4, cd = 20}},
}
R.djets = {
	what = "Dashes you a short way in the direction you're moving.",
	template = "dash",
	attach = Vector3.new(0, 0.97, 1.94), muzzle = Vector3.new(0, 1.1, 2.75),
	chips = {{"DASH", "dist", "studs"}, {"CHARGES", "charges", ""}, {"POISON TRAIL", "trail", "bool"}, {"RECHARGE", "cd", "s"}},
	steps = {{dist = 40, charges = 1, trail = false, cd = 4.2}, {dist = 50, charges = 2, trail = false, cd = 4.2},
		{dist = 65, charges = 2, trail = true, cd = 4.2}, {dist = 65, charges = 3, trail = true, cd = 4.2}},
}
R.dover = {
	what = "For a few seconds your spit never runs out and never has to wait.",
	template = "self", mode = "over",
	attach = Vector3.new(0, 0.71, -1.54), muzzle = Vector3.new(0, 2.7, -4.2),
	chips = {{"LASTS", "lasts", "s"}, {"DOUBLE VENOM", "double", "bool"}, {"RECHARGE", "cd", "s"}},
	steps = {{lasts = 4, double = false, cd = 30}, {lasts = 6, double = false, cd = 30}, {lasts = 6, double = true, cd = 30},
		{lasts = 8, double = true, cd = 30}},
}

R.TEMPLATES = {burst = true, lob = true, cone = true, ring = true, self = true, dash = true}

-- "40 studs" / "1.5 s" / "140°" / "4" / "YES"
function R.fmt(v, unit)
	if unit == "bool" then return v and "YES" or "NO" end
	local s
	if type(v) == "number" then
		s = (math.abs(v - math.floor(v)) < 1e-6) and tostring(math.floor(v)) or tostring(math.floor(v * 10 + 0.5) / 10)
	else
		s = tostring(v)
	end
	if unit == "°" then return s .. "°" end
	if unit == nil or unit == "" then return s end
	return s .. " " .. unit
end

-- the chips of a recipe at step `shown` (1..4) against the owned step `owned` (0..4):
-- {{label, text, up}} where up = the value changed from the owned step (owned >= 1 and shown > owned)
function R.chips(recipe, shown, owned)
	local out = {}
	if type(recipe) ~= "table" or type(recipe.steps) ~= "table" then return out end
	shown = math.clamp(math.floor(tonumber(shown) or 1), 1, #recipe.steps)
	owned = math.floor(tonumber(owned) or 0)
	local now = recipe.steps[shown]
	local base = owned >= 1 and recipe.steps[math.min(owned, #recipe.steps)] or nil
	for _, c in ipairs(recipe.chips or {}) do
		local label, key, unit = c[1], c[2], c[3]
		local v = now[key]
		local up = base ~= nil and shown > owned and base[key] ~= v
		local text = R.fmt(v, unit)
		if up then text = R.fmt(base[key], unit == "°" and "°" or (unit == "bool" and "bool" or "")) .. " → " .. text end
		table.insert(out, {label, text, up})
	end
	return out
end

return R
