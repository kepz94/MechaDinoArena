-- DeflectRules v1.0 (Mecha Dino Arena) — the therizino's Deflector Claws as one shared check for the projectile servers
-- (ServerStorage.DinoArcade.DeflectRules, server only). Plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7 (MDA-247; Kepu
-- 2026-11-04 "Yes, in build 2": one guarded line each in DiloAttackServer, TenoMovesServer, ScreechServer).
-- DeflectRules.check(target, fromPos, kind, t) -> blocked (bool), reflect (bool):
--   blocked when the target model's TheriDeflectUntil (TheriMovesServer 1.2) is after t, its TheriDeflectLevel (SkillEffects
--   1.42) reaches LEVEL[kind] (dart 1; boulder / cannon 2) and fromPos (where the shot comes from) is within TheriDeflectAngle
--   (70) degrees of the target root's flat facing. reflect = blocked and TheriDeflectReflect (the star). A block stamps the
--   target: TheriDeflectBlocks (count), TheriDeflectBlockKind, TheriDeflectBlockFrom (fromPos), TheriDeflectBlockAt (last;
--   TheriMovesFX shows the spark). Anything else (no deflect, wrong level, from the side / behind, no root): false, false.
-- Pure apart from those stamps; never yields.
local DeflectRules = {}
DeflectRules.Version = "1.0"
DeflectRules.LEVEL = {dart = 1, boulder = 2, cannon = 2}

function DeflectRules.check(target, fromPos, kind, t)
	if typeof(target) ~= "Instance" or not target:IsA("Model") or typeof(fromPos) ~= "Vector3" then return false, false end
	local untilT = tonumber(target:GetAttribute("TheriDeflectUntil")) or 0
	if untilT <= t then return false, false end
	local need = DeflectRules.LEVEL[kind]
	if not need or (tonumber(target:GetAttribute("TheriDeflectLevel")) or 0) < need then return false, false end
	local root = target:FindFirstChild("HumanoidRootPart")
	if not root then return false, false end
	local f = root.CFrame.LookVector
	f = Vector3.new(f.X, 0, f.Z)
	local v = fromPos - root.Position
	v = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 or v.Magnitude < 1e-3 then return false, false end
	local ang = math.deg(math.acos(math.clamp(f.Unit:Dot(v.Unit), -1, 1)))
	if ang > (tonumber(target:GetAttribute("TheriDeflectAngle")) or 70) then return false, false end
	target:SetAttribute("TheriDeflectBlocks", (tonumber(target:GetAttribute("TheriDeflectBlocks")) or 0) + 1)
	target:SetAttribute("TheriDeflectBlockKind", kind)
	target:SetAttribute("TheriDeflectBlockFrom", fromPos)
	target:SetAttribute("TheriDeflectBlockAt", t) -- last
	return true, target:GetAttribute("TheriDeflectReflect") == true
end

return DeflectRules
