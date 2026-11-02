-- TenoSlamAim v1.0 (Mecha Dino Arena) — the Tenontosaurus' rear tail slam soft aim (pure maths, no Instances). Plan
-- docs/plans/TENO_SLAM_REWORK_v1.0.md (Kepu 2026-11-01: "The tail slam only damages Dino's behind the Dino within the range
-- of the tail not anywhere in the mid section or front of the teno"; picks "Every dino in the tail zone", "Narrow"; "Have
-- the teno's rear tail slam function like how the t-Rex bite soft aim works").
-- Lives in ServerStorage.DinoArcade.TenoSlamAim (TenoAttackServer 1.2 requires it and copies it to
-- ReplicatedStorage.TenoSlamAimShared so TenoAttackTest 1.2 can predict the same aim for its own pose).
-- Coordinates are the teno's HumanoidRootPart space, flat: x = +left, z = +back (behind the hips). One candidate =
--   {id = any, x = number, z = number, gap = studs from the hips to its nearest hitbox}.
-- Settings s = {reach = studs (TenoSlamReach x scale), aimMax = degrees (TenoSlamAimMax), cone = degrees (TenoSlamCone)}.
-- pick(cands, s) -> {yaw = degrees (+ = the tail swings to the teno's left), target = the aimed candidate or nil,
--   members = the candidates the slam hits}:
--   * In reach: z > 0 (behind the hips, never the mid section or the front) and gap <= reach.
--   * Aim (the T-Rex bite's soft aim, BiteTest 1.5): among the in-reach candidates whose yaw = atan2(x, z) is within
--     +-aimMax, the lowest score = gap + AIM_YAW_WEIGHT x |yaw| + AIM_DIST_WEIGHT x distance wins; yaw = its yaw. None ->
--     yaw 0 (straight back), target nil.
--   * Members: every in-reach candidate whose yaw is within cone / 2 of the aimed yaw ("Every dino in the tail zone").
-- members(cands, yaw, s) -> the members for an already chosen yaw (the impact re-checks positions with the aim it started).
-- backHalf(z) -> true when a latch point at HRP-space z is behind the hips (a raptor latched there is bucked off by the
--   slam; one on the front half is not).
local M = {}
M.Version = "1.0"
M.AIM_YAW_WEIGHT, M.AIM_DIST_WEIGHT = 0.05, 0.02 -- the bite's weights (BiteTest 1.5)

local function yawOf(c) return math.deg(math.atan2(c.x, c.z)) end
local function inReach(c, s) return type(c.x) == "number" and type(c.z) == "number" and type(c.gap) == "number" and c.z > 0 and c.gap <= s.reach end

function M.members(cands, yaw, s)
	local out = {}
	for _, c in ipairs(cands) do
		if inReach(c, s) and math.abs(yawOf(c) - yaw) <= s.cone / 2 then table.insert(out, c) end
	end
	return out
end

function M.pick(cands, s)
	local best, bestScore
	for _, c in ipairs(cands) do
		if inReach(c, s) then
			local y = yawOf(c)
			if math.abs(y) <= s.aimMax then
				local score = c.gap + M.AIM_YAW_WEIGHT * math.abs(y) + M.AIM_DIST_WEIGHT * math.sqrt(c.x * c.x + c.z * c.z)
				if not bestScore or score < bestScore then best, bestScore = c, score end
			end
		end
	end
	local yaw = best and yawOf(best) or 0
	return {yaw = yaw, target = best, members = M.members(cands, yaw, s)}
end

function M.backHalf(z) return type(z) == "number" and z > 0 end

return M
