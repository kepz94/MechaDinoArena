-- HookPose v1.0 (Mecha Dino Arena) — the pachy's Grappling Hook pose (HookServer 1.0), per-joint offsets multiplied onto
-- the current pose (IdleAnimation 1.30). MDA-122, plan docs/plans/PACHY_PARTS_v1.0.md Drop A Task 6 (Kepu 2026-10-30:
-- "something he lifts his arm to shoot" · "pull them in then the pachy would dip its head for a smash").
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front).
-- Phases from the pachy's server stamps (same on every client): HookStartedAt, HookLaunchAt, HookContactAt,
--   HookSmashAt, HookResult, HookBusyUntil.
--   raise  start .. launch            right arm lifts forward (ArmR +ARM_UP), body leans back a touch
--   hold   launch .. smash (or end)   arm stays up while the claw flies and reels
--   smash  smash .. +SMASH            arm drops, the head dips hard for the smash and snaps back (then done)
--   lower  end .. +LOWER              after a miss: the arm eases down
-- phase(model, serverNow) -> phase or nil, u (0..1). get(phase, u, k) -> offsets.

local HookPose = {}
HookPose.Version = "1.0"
HookPose.ARM_UP = 75
HookPose.SMASH = 0.3
HookPose.LOWER = 0.25

local rad, sin, pi = math.rad, math.sin, math.pi
local function smoothstep(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

function HookPose.phase(model, t)
	if model:GetAttribute("HookPoseEnabled") == false then return nil, 0 end
	local s = tonumber(model:GetAttribute("HookStartedAt"))
	if not s or t < s then return nil, 0 end
	local launch = tonumber(model:GetAttribute("HookLaunchAt")) or s
	local smash = tonumber(model:GetAttribute("HookSmashAt")) or 0
	local busy = tonumber(model:GetAttribute("HookBusyUntil")) or launch
	if t < launch then return "raise", (t - s) / math.max(0.01, launch - s) end
	if smash > 0 then
		if t < smash then return "hold", 0 end
		if t < smash + HookPose.SMASH then return "smash", (t - smash) / HookPose.SMASH end
		return nil, 0
	end
	if t < busy then return "hold", 0 end
	if t < busy + HookPose.LOWER then return "lower", (t - busy) / HookPose.LOWER end
	return nil, 0
end

function HookPose.get(phase, u, k)
	local out = {}
	local arm, dip, back = 0, 0, 0
	if phase == "raise" then arm, back = smoothstep(u), smoothstep(u)
	elseif phase == "hold" then arm, back = 1, 1
	elseif phase == "smash" then
		arm = 1 - smoothstep(u * 2)
		dip = sin(pi * math.clamp(u, 0, 1))
	elseif phase == "lower" then arm, back = 1 - smoothstep(u), 1 - smoothstep(u)
	end
	out.ArmR = CFrame.Angles(0, 0, rad(HookPose.ARM_UP * arm * k))
	out.RootJoint = CFrame.Angles(0, 0, rad((3 * back - 6 * dip) * k))
	out.Neck = CFrame.Angles(0, 0, rad((4 * back - 30 * dip) * k))
	out.Head = CFrame.Angles(0, 0, rad(-40 * dip * k))
	return out
end

return HookPose
