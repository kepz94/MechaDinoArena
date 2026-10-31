-- HerreraMovesPose v1.0 (Mecha Dino Arena) — the Herrera's Glider Wings glide pose and the Strobe Frill rear-up, used by
-- IdleAnimation 1.36. Plan docs/plans/HERRERA_PARTS_v1.0.md Part 2 (glide pose) and Part 7 (rear-up), "Pass 2 — build map".
-- Joint frames as ScurryPose 1.0: pitch about Z (+ lifts the front / swings a limb forward; Tail + = lower), yaw about Y,
--   roll about X; RootJoint carries the whole-body pitch.
-- Glide (full pose, ScurryPose.meanAngles + offsets, with the mean scurry drop like HerreraJumpPose's air pose):
--   arms out (ArmL roll -GlideArmRoll, ArmR roll +GlideArmRoll, pitch +GlideArmPitch), legs trailing (LegL / LegR pitch
--   -GlideLegTrail), the tail straightened (the scurry tail angles x GlideTailKeep), body pitch +GlidePitch.
--   glideWeight(model, isOwner, dt) -> 0..1: eases in over GLIDE_IN (0.2 s) while gliding (owner: GlideLocal, GliderTest
--   1.0; others: the replicated Gliding), out over GLIDE_OUT (0.25 s). The caller lerps the pose toward getGlide(...) by it.
-- Strobe rear-up (offsets multiplied on top): from the model's StrobeStartedAt (HerreraMovesServer 1.0): up over
--   STROBE_UP (0.15 s), held STROBE_HOLD (0.2 s), down over STROBE_DOWN (0.2 s): RootJoint +18 x k, Neck +18 x k,
--   Jaw -20 x k. strobe(model, serverNow) -> {[joint] = CFrame} or nil.
-- Switches (model attributes): GlidePoseEnabled, StrobePoseEnabled (default true each).
local ScurryPose = require(script.Parent:WaitForChild("ScurryPose"))
local M = {}
M.Version = "1.0"
M.Defaults = {GlideArmRoll = 55, GlideArmPitch = 20, GlideLegTrail = 45, GlideTailKeep = 0.2, GlidePitch = 14}
local GLIDE_IN, GLIDE_OUT = 0.2, 0.25
local STROBE_UP, STROBE_HOLD, STROBE_DOWN = 0.15, 0.2, 0.2
local rad = math.rad

local function settings(model)
	local s = {}
	for k, v in pairs(M.Defaults) do
		local a = model and model:GetAttribute(k)
		s[k] = type(a) == "number" and a or v
	end
	return s
end
local function add(o, n, p, y, r)
	if not o[n] then return end
	o[n][1] += p
	o[n][2] += (y or 0)
	o[n][3] += (r or 0)
end

local weights = setmetatable({}, {__mode = "k"})
function M.glideWeight(model, isOwner, dt)
	local on = model:GetAttribute("GlidePoseEnabled") ~= false
		and (isOwner and model:GetAttribute("GlideLocal") or model:GetAttribute("Gliding")) == true
	local w = weights[model] or 0
	if on then w = math.min(1, w + dt / GLIDE_IN) else w = math.max(0, w - dt / GLIDE_OUT) end
	weights[model] = w
	return w * w * (3 - 2 * w)
end

local meanDrop
function M.getGlide(model, ss, geo, motors, scale)
	local s = settings(model)
	local o = ScurryPose.meanAngles(ss)
	add(o, "ArmL", s.GlideArmPitch, 0, -s.GlideArmRoll)
	add(o, "ArmR", s.GlideArmPitch, 0, s.GlideArmRoll)
	add(o, "LegL", -s.GlideLegTrail)
	add(o, "LegR", -s.GlideLegTrail)
	for i = 1, 5 do
		local n = o["Tail" .. i]
		if n then n[1], n[2], n[3] = n[1] * s.GlideTailKeep, n[2] * s.GlideTailKeep, n[3] * s.GlideTailKeep end
	end
	add(o, "RootJoint", s.GlidePitch)
	if not meanDrop or meanDrop.geo ~= geo then
		local _, d = ScurryPose.fitted(ScurryPose.meanAngles(ss), geo, motors, scale)
		meanDrop = {geo = geo, d = d}
	end
	local pose = ScurryPose.toPose(o)
	pose.RootJoint = CFrame.new(0, meanDrop.d, 0) * pose.RootJoint
	return pose
end

local function rot(p) return CFrame.fromEulerAngles(0, 0, rad(p), Enum.RotationOrder.ZYX) end
function M.strobe(model, serverNow)
	if model:GetAttribute("StrobePoseEnabled") == false then return nil end
	local st = model:GetAttribute("StrobeStartedAt")
	if typeof(st) ~= "number" then return nil end
	local t = serverNow - st
	local k
	if t < 0 or t > STROBE_UP + STROBE_HOLD + STROBE_DOWN then return nil
	elseif t < STROBE_UP then k = t / STROBE_UP
	elseif t < STROBE_UP + STROBE_HOLD then k = 1
	else k = 1 - (t - STROBE_UP - STROBE_HOLD) / STROBE_DOWN end
	k = k * k * (3 - 2 * k)
	return {RootJoint = rot(18 * k), Neck = rot(18 * k), Jaw = rot(-20 * k)}
end

return M
