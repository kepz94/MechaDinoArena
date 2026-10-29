-- BoostPose v1.0 (Mecha Dino Arena) — Thrusters boost lean + booster swivel, option B of
-- docs/mockups/boost_lean_options.html (Kepu 2026-10-29: "When I go backwards in the thrusters tho I think the raptors
-- animation should reflect that ... leaning its body back so the thrusters are firing in the right direction same with
-- left and right" -> "I love B"). Plan docs/plans/BOOST_LEAN_v1.0.md. Pure math; IdleAnimation 1.27 applies it.
-- Direction: (f, r) = unit travel direction in the body frame (RootJoint rest frame: +X forward, +Z right).
-- Lean (RootJoint, rest frame): pitch about +Z (+ = chest up): forward travel -BoostLeanForward * f, backward travel
--   +BoostLeanBack * -f; roll about +X (+ = right side down): -BoostLeanSide * r (right travel -> left side down).
--   Both x the boost weight.
-- Swivel (booster frame: +X right, +Y up, +Z back = where the nozzle points at rest): nozzle target
--   D = unit(-r, max(0, -f) * tan(180 - BoostSwivelOver), f) (opposite the travel; backward travel lifts it so the
--   booster swings up and over, BoostSwivelOver degrees at straight back). Rotation = the shortest turn from +Z to D,
--   angle x weight (no flip: D.Y > 0 whenever D points forward).
-- Stagger: two parallel boosters 2 * half apart (booster width bx) would overlap when turned across the back, so they
--   slide apart along Z (the right one by +dz / 2, the left one by -dz / 2) until the gap between their axes is at least
--   BoostSwivelGap * bx.
local BoostPose = {}

BoostPose.Defaults = {
	BoostLeanEnabled = true,   -- false: no body lean
	BoostSwivelEnabled = true, -- false: boosters stay fixed (MechaServer 1.2 look)
	BoostLeanForward = 10,     -- degrees, chest down when boosting forward
	BoostLeanBack = 15,        -- degrees, chest up when boosting backward
	BoostLeanSide = 12,        -- degrees, bank when boosting sideways
	BoostSwivelOver = 160,     -- degrees the boosters swing up and over for a straight-back boost (100..179)
	BoostEaseIn = 0.15,        -- s, from the boost start
	BoostEaseOut = 0.25,       -- s, after the boost end (DashStartedAt + DashTime)
	BoostDirRate = 12,         -- per second, how fast the travel direction follows the movement
	BoostDirMinSpeed = 2,      -- studs/s of movement below which the direction is held
	BoostSwivelGap = 1.15,     -- x booster width, minimum gap between the two booster axes
}

function BoostPose.settings(model)
	local s = {}
	for k, v in pairs(BoostPose.Defaults) do
		local a = model:GetAttribute(k)
		s[k] = (typeof(a) == typeof(v)) and a or v
	end
	return s
end

local function smooth(u)
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- boost weight 0..1 at t s after the boost start (dur = DashTime)
function BoostPose.weight(t, dur, s)
	local easeIn, easeOut = math.max(0.001, s.BoostEaseIn), math.max(0.001, s.BoostEaseOut)
	if t < 0 or t >= dur + easeOut then return 0 end
	if t < easeIn then return smooth(t / easeIn) end
	if t <= dur then return 1 end
	return 1 - smooth((t - dur) / easeOut)
end

-- RootJoint offset; returns the CFrame, pitch and roll in degrees
function BoostPose.lean(f, r, w, s)
	local pitch = (f >= 0 and -s.BoostLeanForward * f or s.BoostLeanBack * -f) * w
	local roll = -s.BoostLeanSide * r * w
	return CFrame.Angles(0, 0, math.rad(pitch)) * CFrame.Angles(math.rad(roll), 0, 0), pitch, roll
end

-- booster rotation (booster frame) and the Z stagger; returns rot, dz (right minus left), angle in degrees
function BoostPose.swivel(f, r, w, s, half, bx)
	local over = math.clamp(s.BoostSwivelOver, 100, 179)
	local D = Vector3.new(-r, math.max(0, -f) * math.tan(math.rad(180 - over)), f)
	if D.Magnitude < 1e-6 then return CFrame.identity, 0, 0 end
	D = D.Unit
	local axis = Vector3.new(-D.Y, D.X, 0) -- +Z x D
	local ang = math.acos(math.clamp(D.Z, -1, 1)) * w
	if axis.Magnitude < 1e-4 or ang < 1e-4 then return CFrame.identity, 0, 0 end
	local rot = CFrame.fromAxisAngle(axis.Unit, ang)
	local Dw = rot:VectorToWorldSpace(Vector3.zAxis) -- where the nozzle points now
	local g = s.BoostSwivelGap * bx
	local q = math.sqrt(math.max(0, 1 - Dw.X * Dw.X))
	local dz = 0
	if 2 * half * q < g then
		local st = (g - 2 * half * q) / (2 * math.max(math.abs(Dw.X), 0.3))
		dz = -2 * st * (Dw.X >= 0 and 1 or -1) * (Dw.Z >= 0 and 1 or -1)
	end
	return rot, dz, math.deg(ang)
end

return BoostPose
