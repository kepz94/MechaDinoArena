-- StaggerPose v1.0 (Mecha Dino Arena) — the hit-react stagger of a dino struck by a pachy headbutt or a Grappling Hook
-- smash (ModuleScript under IdleAnimation 1.46). MDA-303, plan docs/plans/PACHY_MOVES_ANIM_v1.0.md Task 1; Kepu
-- 2026-11-05 "Yes, headbutt + hook smash" (scope) and red-team "Look only" (no control loss: HeadbuttShove / HookPull
-- still move the body); mockup docs/mockups/pachy_moves_anim.html v0.1 (rapPose stagger).
-- Stamps on the hit model (HeadbuttServer 1.16 / HookServer 1.9): StaggerFrom (attacker name), StaggerPower ("big" /
--   "mid"), StaggerAt (server time, last). Every client plays it on every model with IdleAnimation (players and bots).
-- Pose (DURATION 0.9 s, "mid" x 0.7): the head snaps back and away from the attacker, the jaw drops, the arms fling out,
--   two stumbling steps back, then a wobble that fades. Joint frames are world-aligned at build time (rotation about Z =
--   pitch, positive lifts the front / swings a limb forward; about Y = yaw, positive turns toward the dino's left; about
--   X = roll). Model switch StaggerPoseEnabled (default true, read every frame). No stagger while dead / KO.
-- get(model, hrp, serverNow) -> offsets or nil, u (0..1). Diagnostic (set by IdleAnimation): StaggerPoseState.
local StaggerPose = {}
StaggerPose.Version = "1.0"
StaggerPose.DURATION = 0.9

local rad, sin, min, max = math.rad, math.sin, math.min, math.max
local function outCubic(x) x = math.clamp(x, 0, 1); return 1 - (1 - x) ^ 3 end

local memo = setmetatable({}, {__mode = "k"}) -- [model] = {at, side}

local function findModel(name)
	if typeof(name) ~= "string" or name == "" then return nil end
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		if pl.Character and pl.Character.Name == name then return pl.Character end
	end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end

function StaggerPose.get(model, hrp, serverNow)
	if model:GetAttribute("StaggerPoseEnabled") == false then return nil, 0 end
	local at = model:GetAttribute("StaggerAt")
	if typeof(at) ~= "number" then return nil, 0 end
	local age = serverNow - at
	if age < 0 or age >= StaggerPose.DURATION then return nil, 0 end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if (hum and hum.Health <= 0) or model:GetAttribute("DummyState") == "ko" then return nil, 0 end
	local m = memo[model]
	if not m or m.at ~= at then
		-- the attacker's side in this model's frame: +X = the dino's right
		local side = 1
		local a = findModel(model:GetAttribute("StaggerFrom"))
		local ar = a and (a:FindFirstChild("HumanoidRootPart") or a.PrimaryPart)
		if ar and hrp then side = hrp.CFrame:PointToObjectSpace(ar.Position).X >= 0 and 1 or -1 end
		m = {at = at, side = side}
		memo[model] = m
	end
	local k = model:GetAttribute("StaggerPower") == "mid" and 0.7 or 1
	local u = age / StaggerPose.DURATION
	local sg = 1 - u
	local st = outCubic(min(1, u * 6)) * min(1, sg * 2.2) * k -- snaps in fast, fades out
	local wob = sin(u * 22) * sg * k
	local step = st * sin(u * 18) * 24
	local s = m.side -- turn away from the attacker: attacker on the right (+1) -> yaw toward the left (+)
	local o = {}
	o.RootJoint = CFrame.Angles(rad(10 * wob), 0, rad(16 * st))
	o.Neck = CFrame.Angles(0, rad((24 * st + 12 * wob) * s), rad(26 * st))
	o.Head = CFrame.Angles(0, rad(10 * wob * s), rad(12 * st))
	o.Jaw = CFrame.Angles(0, 0, rad(-26 * st))
	o.ArmL = CFrame.Angles(rad(-20 * st), 0, rad(30 * st))
	o.ArmR = CFrame.Angles(rad(20 * st), 0, rad(30 * st))
	o.Tail1 = CFrame.Angles(0, rad(10 * wob), rad(-14 * st))
	o.LegL = CFrame.Angles(0, 0, rad(-20 * st + step))
	o.LegR = CFrame.Angles(0, 0, rad(-6 * st - step))
	o.KneeL = CFrame.Angles(0, 0, rad(-20 * st))
	o.KneeR = CFrame.Angles(0, 0, rad(-30 * st))
	return o, u
end

return StaggerPose
