-- ClimbPose v1.0 (Mecha Dino Arena) — the Herrerasaurus on a tree trunk: body straight up the trunk, belly on the bark,
-- limbs gripping in diagonal pairs, tail hanging. MDA-139, plan docs/plans/HERRERA_KIT_v1.0.md Task 7, mockup
-- docs/mockups/herrera_kit_options.html ("auto-climb"). Used by IdleAnimation 1.32 while ClimbState (or this client's
-- ClimbLocalState) is "climbing" / "clinging", and by ScurryHitbox 1.1 (the climb hitboxes).
-- Built on ScurryPose 1.0's angles (same joint frames: pitch about Z, yaw about Y, roll about X):
--   RootJoint pitch ClimbBodyPitch (90: nose up) instead of the scurry's -24, no body S-wave yaw, ClimbRoll roll wave,
--   neck +4 / head -10 (looking up the trunk), arms +20 reaching up, legs -10, tail bent down
--   (Tail1..5 - 30 / 6 / 10 / 16 / 22) so it hangs along the trunk; the RootJoint is moved ClimbBodyIn x scale toward
--   the trunk (forward of the HumanoidRootPart) so the belly rests on the bark.
-- Phase: the caller advances it by the climbed distance / (ClimbStride x scale); while clinging it stays.
-- API: Defaults; settings(model); angles(phase, s); mean(s) (the hitbox pose: swings at zero); get(phase, s, scale) ->
--   pose {[joint] = CFrame}.
local ScurryPose = require(script.Parent:WaitForChild("ScurryPose"))
local ClimbPose = {}
ClimbPose.Version = "1.0"
ClimbPose.Defaults = {ClimbBodyPitch = 90, ClimbRoll = 6, ClimbBodyIn = 1.2, ClimbStride = 2.4}
local TAIL_DOWN = {30, 6, 10, 16, 22}

function ClimbPose.settings(model)
	local s = ScurryPose.settings(model)
	for k, v in pairs(ClimbPose.Defaults) do
		local a = model and model:GetAttribute(k)
		s[k] = type(a) == "number" and a or v
	end
	return s
end

local function adjust(a, s, phase)
	a.RootJoint[1] = s.ClimbBodyPitch
	a.body[1], a.body[2] = 0, 0
	a.body[3] = phase and s.ClimbRoll * math.sin(phase) or 0
	a.body[4] = 0
	a.Neck[1] += 4
	a.Head[1] -= 10
	a.ArmL[1] += 20
	a.ArmR[1] += 20
	a.LegL[1] -= 10
	a.LegR[1] -= 10
	for i = 1, 5 do a["Tail" .. i][1] -= TAIL_DOWN[i] end
	-- no S-wave on the trunk
	a.Neck[2], a.Head[2] = 0, 0
	for i = 1, 5 do a["Tail" .. i][2] *= 0.4 end
	return a
end

function ClimbPose.angles(phase, s)
	return adjust(ScurryPose.angles(phase, s), s, phase)
end

function ClimbPose.mean(s)
	return adjust(ScurryPose.meanAngles(s), s, nil)
end

local function toPose(a, s, scale)
	local pose = ScurryPose.toPose(a)
	pose.RootJoint = CFrame.new(s.ClimbBodyIn * (scale or 1), 0, 0) * pose.RootJoint
	return pose
end

function ClimbPose.get(phase, s, scale)
	return toPose(ClimbPose.angles(phase, s), s, scale)
end

function ClimbPose.meanPose(s, scale)
	return toPose(ClimbPose.mean(s), s, scale)
end

return ClimbPose
