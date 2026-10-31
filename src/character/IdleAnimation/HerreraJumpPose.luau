-- HerreraJumpPose v1.1 (Mecha Dino Arena) — the Herrerasaurus' jump, option C "Branch reach" (MDA-147, plan
-- docs/plans/HERRERA_JUMP_v1.0.md Task 4; mockup docs/mockups/herrera_jump_options.html, Kepu 2026-10-31 "C · Branch
-- reach"). Springs from the scurry head-first, arms stretched forward and up as if grabbing a branch, legs trailing, tail
-- curled up; swings the legs under to land on all fours. Used by IdleAnimation 1.34 instead of JumpPose on GaitScurry
-- models.
-- Built on ScurryPose 1.0's mean angles (same joint frames: pitch about Z (+ lifts the front / swings a limb forward;
--   Tail + = lower; Neck + = head up), yaw about Y, roll about X; RootJoint carries the whole-body pitch). The numbers are
--   the mockup's option C.
-- Phases (driven by IdleAnimation's leap clock, like JumpPose):
--   crouch(c)      c = 0..1 over JumpWindup: hips down (legs fold), arms back, head low, nose down.
--   air(a, vyN)    a = s since launch, vyN = vertical speed / launch speed (+1 rising .. -1 falling): push (legs drive
--                  back for HJumpPushTime), then arms reach up / forward, legs trail, tail curls up (over HJumpReachTime);
--                  falling: arms come down, legs swing forward under the body; body pitch = HJumpPitch x vyN.
--   land(u)        u = 0..1 over HJumpLandTime: squash on all fours (the caller fades it out).
-- Crouch / land are ground-fitted (ScurryPose.fitted: the lowest hand / foot block on the rest ground height); air keeps
--   the mean scurry drop so the body does not pop up at liftoff.
-- API: Defaults; settings(model); crouch(c, s, ss); air(a, vyN, s, ss); land(u, s, ss) -> angles;
--   get(kind, x, y, s, ss, geo, motors, scale) -> pose {[joint] = CFrame} (kind "crouch" (x = c) / "air" (x = a, y = vyN)
--   / "land" (x = u)).
-- v1.1 (Kepu 2026-10-31, live v255: "it doesn't show the same jump animation all the time, only when I leap towards a
--   tree. I want it to be that animation every time"): a leap at a tree grabs on while still rising, so only the rising
--   branch reach showed; a full jump turned into the falling pose (arms down, legs forward, nose down) after the apex.
--   With HJumpHoldReach = 1 (default) the reach is held for the whole air time: arms up / forward, legs trailing, tail
--   curled, body pitched HJumpPitch x HJumpHoldPitch nose-up (ramped in with the reach), no falling change; the landing
--   squash is unchanged. HJumpHoldReach = 0 = 1.0 (rising / falling by vyN).
local ScurryPose = require(script.Parent:WaitForChild("ScurryPose"))
local HerreraJumpPose = {}
HerreraJumpPose.Version = "1.1"
HerreraJumpPose.Defaults = {
	HJumpPoseScale = 1,    -- multiplier on every offset below (0 = the plain scurry crouch)
	HJumpPitch = 28,       -- degrees of body pitch at full vertical speed (nose up rising, down falling)
	HJumpArmReach = 100,   -- degrees the arms swing forward / up
	HJumpLegTrail = 70,    -- degrees the legs trail back
	HJumpTailCurl = 1,     -- multiplier on the tail curl (14 / 10 / 14 / 18 / 22 degrees up)
	HJumpPushTime = 0.14,  -- s of the leg push at liftoff
	HJumpReachTime = 0.2,  -- s to the full reach
	HJumpLandTime = 0.18,  -- s of the landing squash
	HJumpHoldReach = 1,    -- v1.1: 1 = hold the branch reach for the whole air time; 0 = 1.0 (falling pose after the apex)
	HJumpHoldPitch = 0.5,  -- v1.1: share of HJumpPitch held nose-up while holding the reach
}
local TAIL_CURL = {14, 10, 14, 18, 22}
local sin, min, max, pi = math.sin, math.min, math.max, math.pi

function HerreraJumpPose.settings(model)
	local s = {}
	for k, v in pairs(HerreraJumpPose.Defaults) do
		local a = model and model:GetAttribute(k)
		s[k] = type(a) == "number" and a or v
	end
	return s
end

local function smooth(k)
	k = max(0, min(1, k))
	return k * k * (3 - 2 * k)
end
local function add(o, n, p, y, r)
	o[n][1] += p
	o[n][2] += (y or 0)
	o[n][3] += (r or 0)
end
-- both sides: pitch / yaw the same, roll mirrored (L gets r, R gets -r)
local function both(o, prefix, p, r)
	add(o, prefix .. "L", p, 0, r or 0)
	add(o, prefix .. "R", p, 0, -(r or 0))
end

function HerreraJumpPose.crouch(c, s, ss)
	local o = ScurryPose.meanAngles(ss)
	local k = c * s.HJumpPoseScale
	add(o, "RootJoint", -10 * k)
	both(o, "Leg", 24 * k); both(o, "Knee", -30 * k); both(o, "Ankle", 12 * k)
	both(o, "Arm", -10 * k)
	add(o, "Neck", -12 * k); add(o, "Head", -6 * k)
	return o
end

function HerreraJumpPose.air(a, vyN, s, ss)
	local o = ScurryPose.meanAngles(ss)
	local g = s.HJumpPoseScale
	local push = 1 - smooth(a / max(0.01, s.HJumpPushTime))
	local up = smooth(a / max(0.01, s.HJumpReachTime))
	local hold = s.HJumpHoldReach ~= 0 -- v1.1
	local reach = hold and 0 or smooth(-vyN * 1.4)
	both(o, "Arm", (s.HJumpArmReach * up - 35 * reach) * g, -12 * up * g)
	add(o, "Jaw", -16 * up * g)
	local trail = s.HJumpLegTrail * up * (1 - reach)
	both(o, "Leg", (-trail + 40 * reach - 20 * push) * g)
	both(o, "Knee", (30 * up * (1 - reach) - 30 * reach) * g)
	both(o, "Ankle", -40 * up * (1 - reach) * g)
	add(o, "Neck", 14 * up * g); add(o, "Head", -6 * up * g)
	for i = 1, 5 do add(o, "Tail" .. i, -TAIL_CURL[i] * s.HJumpTailCurl * up * (1 - 0.6 * reach) * g) end
	if hold then -- v1.1: the same nose-up reach all the way
		add(o, "RootJoint", s.HJumpPitch * s.HJumpHoldPitch * up * g)
	else
		add(o, "RootJoint", s.HJumpPitch * max(-1, min(1, vyN)) * g)
	end
	return o
end

function HerreraJumpPose.land(u, s, ss)
	local o = ScurryPose.meanAngles(ss)
	local k = sin(pi * min(1, u * 1.4)) * (1 - 0.3 * u) * s.HJumpPoseScale
	add(o, "RootJoint", -18 * k)
	both(o, "Leg", 26 * k); both(o, "Knee", -32 * k)
	both(o, "Arm", 22 * k)
	add(o, "Neck", -10 * k)
	return o
end

-- joint poses; crouch / land ground-fitted, air with the mean scurry drop
local meanDrop -- cached per geo
function HerreraJumpPose.get(kind, x, y, s, ss, geo, motors, scale)
	if kind == "air" then
		if not meanDrop or meanDrop.geo ~= geo then
			local _, d = ScurryPose.fitted(ScurryPose.meanAngles(ss), geo, motors, scale)
			meanDrop = {geo = geo, d = d}
		end
		local pose = ScurryPose.toPose(HerreraJumpPose.air(x, y, s, ss))
		pose.RootJoint = CFrame.new(0, meanDrop.d, 0) * pose.RootJoint
		return pose
	end
	local a = kind == "crouch" and HerreraJumpPose.crouch(x, s, ss) or HerreraJumpPose.land(x, s, ss)
	local pose = ScurryPose.fitted(a, geo, motors, scale)
	return pose
end

return HerreraJumpPose
