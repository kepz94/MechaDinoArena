-- SkillPool v1.0 (Mecha Dino Arena) — universal skill points maths (ModuleScript, ServerStorage.DinoArcade). Plan
-- docs/plans/UNIVERSAL_POINTS_v1.0.md Task 1; Kepu 2026-11-26 "Make all points universal", picks "Full pool on every dino",
-- "Highest dino's XP", quest points "Yes, past 40", red-team "No cap".
-- accountXp(value): the account XP of a saved SkillServer value = max(value.uxp, every value.dinos[k].xp); each floored, a
--   non-number / negative / NaN counts as 0; nil or a bad value -> 0.
-- cleanBonus(n, max): bonus skill points = a whole number >= 0 (anything else -> 0), clamped to max (nil -> no cap).
-- earned(xp, bonus, ST, max): ST.pointsOf(level of xp) + cleanBonus(bonus, max).
-- grantOk(amount): a whole number 1 .. GRANT_MAX (100).
local M = {}
M.Version = "1.0"
M.GRANT_MAX = 100

local function num(v)
	v = tonumber(type(v) == "number" and v or nil)
	if not v or v ~= v or v < 0 or v == math.huge then return 0 end
	return math.floor(v)
end

function M.accountXp(value)
	if type(value) ~= "table" then return 0 end
	local best = num(value.uxp)
	if type(value.dinos) == "table" then
		for _, r in pairs(value.dinos) do
			if type(r) == "table" then best = math.max(best, num(r.xp)) end
		end
	end
	return best
end

function M.cleanBonus(n, max)
	if type(n) ~= "number" or n ~= n or n < 0 or n ~= math.floor(n) or n == math.huge then return 0 end
	if type(max) == "number" and max == max and max >= 0 then n = math.min(n, math.floor(max)) end
	return n
end

function M.earned(xp, bonus, ST, max)
	return ST.pointsOf((ST.levelOf(xp))) + M.cleanBonus(bonus, max)
end

function M.grantOk(amount)
	return type(amount) == "number" and amount == amount and amount == math.floor(amount) and amount >= 1 and amount <= M.GRANT_MAX
end

return M
