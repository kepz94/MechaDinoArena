-- PouncePose v1.1 (Dino Arcade) — raptor pounce: claws-first lunge, then gripping and biting while latched.
-- Pure functions: phase values -> per-joint offset, applied on top of each joint's rest C0 (same joint frames as
-- WalkPose / JumpPose: +X forward, +Y up, Z = side; rotation about Z = pitch, positive lifts the front / swings a
-- limb forward; Neck positive = head up; Jaw negative = open; Tail positive pitch = tail lower).
-- Phases (driven by the animator, IdleAnimation 1.16; the wind-up before the lunge uses JumpPose.crouch):
--   lunge   (a = seconds since launch): body pitched nose-up PounceLungePitch, both feet thrown forward (sickle claws
--           first: foot target PounceLungeLegFwd / PounceLungeLegDown of the leg reach, toes up PounceLungeToe), arms
--           reaching forward PounceLungeArms, head forward, jaws wide open PounceLungeJaw, tail straight back.
--   latched (t = seconds since the latch, chomp = seconds since the last bite, nil = none yet): the body clings to
--           the target surface (the latch frame's down is the surface): deep crouch PounceLatchCrouch with feet planted
--           (knee IK), nose-down PounceLatchLean, neck down into the target PounceLatchNeck, head pitched further
--           into it PounceLatchHead (negative = snout down, so the jaws dig into the body instead of facing up the
--           surface), arms gripping forward PounceLatchArms, jaws open PounceLatchJawOpen and snapping shut over
--           PounceChompTime after each bite with a head thrash PounceThrash, tail swishing for balance.
-- geo: WalkPose.buildGeo result.
-- v1.1: claw slashes while latched (Kepu 2026-10-29: "It shows him biting them but we need to see visible slashing with
--   the arm claws. I need to see the raptor animate his swings on the downed victim" + "the slashes need to be animated
--   and show some wind up ... and be accurate to the damage taken"; mockup docs/mockups/hud_target_slash_options.html
--   "Claw slashes only": arms alternate raking down with the long claws, no bite, head low and snarling, jaws half open,
--   feet keep gripping). Used by IdleAnimation 1.28 through PounceSlash 1.0 (which decides each arm's phase from the
--   server hits) while PounceSlashEnabled ~= false; latch() above is unchanged and still used when it is off.
--   PouncePose.slashArm(phase, u, fromP, fromS, s, k) -> pitch, splay (degrees) for one arm:
--     "rest"    gripping: pitch PounceLatchArms x k (k = latch blend), splay 0;
--     "windup"  u 0..1: smoothstep from the angles the arm had when the wind-up began (fromP / fromS) up to
--               PounceSlashCocked (pitch, arm raised high in front) and PounceSlashSplay (out to the side);
--     "cocked"  held raised, trembling PounceSlashTremble degrees, until the server hit arrives;
--     "strike"  u 0..1 over PounceSlashStrike s: accelerating (u^2) from fromP / fromS down to PounceSlashRakeEnd (pitch,
--               the claws raked down past the grip) and -PounceSlashCross (splay: across under the body), a diagonal rake;
--     "rake"    u 0..1 over PounceSlashRakeTime s: held down, dragging PounceSlashDrag degrees back and forth once;
--     "recover" u 0..1 over PounceSlashRecover s: smoothstep back to the grip.
--   Splay: positive = away from the body (ArmL toward +Z, ArmR toward -Z); applied about the shoulder's forward axis
--   before the pitch, so "out" stays out at any pitch.
--   PouncePose.slash(t, arms, s, geo): t = seconds since the latch; arms = {L = {p, sp}, R = {p, sp}, dip = 0..1,
--   side = "L" / "R" (the arm of the newest strike)}. Body and feet as latch() plus a dip into the target on each
--   strike (PounceSlashDip x geo.scale studs lower and PounceSlashLean degrees more nose-down at dip 1, feet re-solved so
--   they stay planted); neck and head low as latch(), the head turning PounceSlashHeadTurn degrees toward the striking
--   arm at dip 1; jaws half open (PounceLatchJawOpen) with a snarl flutter of PounceSnarl degrees; no chomp, no thrash.

local PouncePose = {}

PouncePose.Version = "1.1"
PouncePose.Defaults = {
	PouncePoseEnabled  = true,
	-- lunge
	PounceLungePitch   = 18,   -- degrees nose-up
	PounceLungeLegFwd  = 0.55, -- foot target forward of the hip (share of leg reach)
	PounceLungeLegDown = 0.45, -- foot target below the hip (share of leg reach)
	PounceLungeToe     = -20,  -- degrees toes down (negative = toes up, claws forward)
	PounceLungeArms    = 45,   -- degrees the arms reach forward
	PounceLungeJaw     = 28,   -- degrees the jaws open
	-- latched
	PounceLatchCrouch  = 2.6,  -- studs the body drops toward the surface (x geo.scale; raptor 0.31 -> 0.8)
	PounceLatchLean    = 22,   -- degrees nose-down (toward the surface)
	PounceLatchNeck    = 60,   -- degrees the neck lowers into the target
	PounceLatchHead    = -20,  -- degrees head pitch (negative = snout down into the target)
	PounceLatchArms    = 55,   -- degrees the arms grip forward
	PounceLatchJawOpen = 22,   -- degrees the jaws stay open between bites
	PounceChompTime    = 0.22, -- seconds a bite snaps shut and reopens
	PounceThrash       = 10,   -- degrees of head shake on each bite
	-- v1.1: claw slashes
	PounceSlashEnabled  = true,  -- false = latch() (bite) as in 1.0
	PounceSlashWindup   = 0.22,  -- seconds the next arm takes to rise (capped at 70% of the hit interval by PounceSlash)
	PounceSlashStrike   = 0.07,  -- seconds from cocked to raked down (the hit's damage number shows at the end)
	PounceSlashRakeTime = 0.07,  -- seconds held down after the strike
	PounceSlashRecover  = 0.16,  -- seconds back to the grip
	PounceSlashCocked   = 160,   -- degrees arm pitch at full wind-up (raised high in front)
	PounceSlashSplay    = 50,    -- degrees out to the side at full wind-up (wide, so the raised arm shows from behind)
	PounceSlashRakeEnd  = -15,   -- degrees arm pitch at the end of the strike
	PounceSlashCross    = 10,    -- degrees across under the body at the end of the strike
	PounceSlashDrag     = 6,     -- degrees of drag while raked down
	PounceSlashTremble  = 3,     -- degrees of tremble while cocked
	PounceSlashDip      = 0.8,   -- studs (x geo.scale) the body dips into the target on a strike
	PounceSlashLean     = 6,     -- extra degrees nose-down on a strike
	PounceSlashHeadTurn = 8,     -- degrees the head turns toward the striking arm
	PounceSnarl         = 3,     -- degrees of jaw flutter (snarl)
}

local rad, sin, cos, max, min = math.rad, math.sin, math.cos, math.max, math.min
local atan2, acos = math.atan2, math.acos

local function clamp(x, a, b) return max(a, min(b, x)) end
local function smoothstep(s) s = clamp(s, 0, 1); return s * s * (3 - 2 * s) end

-- Two-joint IK in the hip's X/Y plane (same solution as WalkPose 3.3 / JumpPose 1.0, kept local).
local function solveLeg(geo, T)
	local d = T.Magnitude
	local dMin, dMax = math.abs(geo.l1 - geo.l2) + 0.01, (geo.l1 + geo.l2) * 0.999
	d = clamp(d, dMin, dMax)
	local cosA = clamp((geo.l1 * geo.l1 + d * d - geo.l2 * geo.l2) / (2 * geo.l1 * d), -1, 1)
	local phi1 = atan2(T.Y, T.X) + geo.bend * acos(cosA)
	local K = Vector2.new(cos(phi1), sin(phi1)) * geo.l1
	local Tc = T.Unit * d
	local phi2 = atan2(Tc.Y - K.Y, Tc.X - K.X)
	local dHip = phi1 - geo.phi1
	local dShin = phi2 - geo.phi2
	return dHip, dShin - dHip, dShin
end

local function tailStraight(out, pitch, swish)
	out.Tail1 = CFrame.Angles(0, rad(swish), pitch)
	for k = 2, 5 do out["Tail" .. k] = CFrame.Angles(0, rad(swish * 0.5), 0) end
end

-- lunge: a = seconds since launch (the pose is reached within ~0.08 s)
function PouncePose.lunge(a, s, geo)
	local out = {}
	local k = smoothstep(a / 0.08)
	local L = geo.l1 + geo.l2
	local rz = rad(s.PounceLungePitch * k)
	out.RootJoint = CFrame.Angles(0, 0, rz)
	local T = Vector2.new(geo.A0.X, geo.A0.Y):Lerp(Vector2.new(s.PounceLungeLegFwd * L, -s.PounceLungeLegDown * L), k)
	local dHip, dKnee, dShin = solveLeg(geo, T)
	local toe = rad(-s.PounceLungeToe) * k
	for _, S in ipairs({"L", "R"}) do
		out["Leg" .. S] = CFrame.Angles(0, 0, dHip)
		out["Knee" .. S] = CFrame.Angles(0, 0, dKnee)
		out["Ankle" .. S] = CFrame.Angles(0, 0, toe - dShin)
	end
	out.ArmL = CFrame.Angles(0, 0, rad(s.PounceLungeArms * k))
	out.ArmR = CFrame.Angles(0, 0, rad(s.PounceLungeArms * k))
	out.Neck = CFrame.Angles(0, 0, -rz * 0.6)          -- head stays level, aimed at the target
	out.Head = CFrame.Angles(0, 0, -rz * 0.3)
	out.Jaw = CFrame.Angles(0, 0, rad(-s.PounceLungeJaw * k))
	tailStraight(out, -rz * 0.8, 0)
	return out
end

-- latched: t = seconds since the latch, chomp = seconds since the last bite (nil = none)
function PouncePose.latch(t, chomp, s, geo)
	local out = {}
	local k = smoothstep(t / 0.12)
	local bodyY = -s.PounceLatchCrouch * geo.scale * k
	local rz = rad(-s.PounceLatchLean * k)
	local bodyRot = CFrame.Angles(0, 0, rz)
	out.RootJoint = CFrame.new(0, bodyY, 0) * bodyRot
	-- feet gripping the surface at their rest spots
	local counter = CFrame.Angles(0, 0, -rz)
	for _, S in ipairs({"L", "R"}) do
		local hip = geo["hip" .. S]
		local shift = bodyRot * hip - hip
		local T = Vector2.new(geo.A0.X - shift.X, geo.A0.Y - bodyY - shift.Y)
		local dHip, dKnee, dShin = solveLeg(geo, T)
		out["Leg" .. S] = counter * CFrame.Angles(0, 0, dHip)
		out["Knee" .. S] = CFrame.Angles(0, 0, dKnee)
		out["Ankle" .. S] = CFrame.Angles(0, 0, -dShin)
	end
	out.ArmL = CFrame.Angles(0, 0, rad(s.PounceLatchArms * k))
	out.ArmR = CFrame.Angles(0, 0, rad(s.PounceLatchArms * k))
	-- bite: jaws snap shut over the first 40% of PounceChompTime, reopen after; head thrashes
	local jaw = s.PounceLatchJawOpen * k
	local thrash = 0
	if chomp and chomp >= 0 and chomp < s.PounceChompTime then
		local u = chomp / s.PounceChompTime
		local shut = u < 0.4 and smoothstep(u / 0.4) or (1 - smoothstep((u - 0.4) / 0.6))
		jaw = jaw * (1 - shut)
		thrash = s.PounceThrash * sin(u * math.pi * 2) * (1 - u)
	end
	out.Neck = CFrame.Angles(0, rad(thrash * 0.5), rad(-s.PounceLatchNeck * k) - rz * 0.4)
	out.Head = CFrame.Angles(rad(thrash), rad(thrash * 0.5), rad(s.PounceLatchHead * k))
	out.Jaw = CFrame.Angles(0, 0, rad(-jaw))
	tailStraight(out, -rz * 0.6, 8 * sin(t * 5))
	return out
end

-- v1.1: one arm's slash angles (degrees): pitch about the shoulder's side axis, splay away from the body
function PouncePose.slashArm(phase, u, fromP, fromS, s, k)
	local G = s.PounceLatchArms
	fromP, fromS = fromP or G, fromS or 0
	if phase == "windup" then
		local e = smoothstep(u)
		return fromP + (s.PounceSlashCocked - fromP) * e, fromS + (s.PounceSlashSplay - fromS) * e
	elseif phase == "cocked" then
		return s.PounceSlashCocked + s.PounceSlashTremble * sin(os.clock() * 40), s.PounceSlashSplay
	elseif phase == "strike" then
		local e = clamp(u, 0, 1) ^ 2
		return fromP + (s.PounceSlashRakeEnd - fromP) * e, fromS + (-s.PounceSlashCross - fromS) * e
	elseif phase == "rake" then
		return s.PounceSlashRakeEnd - s.PounceSlashDrag * sin(clamp(u, 0, 1) * math.pi), -s.PounceSlashCross
	elseif phase == "recover" then
		local e = smoothstep(u)
		return s.PounceSlashRakeEnd + (G - s.PounceSlashRakeEnd) * e, -s.PounceSlashCross * (1 - e)
	end
	return G * (k or 1), 0
end

-- v1.1: latched with claw slashes (see the header)
function PouncePose.slash(t, arms, s, geo)
	local out = {}
	local k = smoothstep(t / 0.12)
	local dip = clamp(arms.dip or 0, 0, 1)
	local bodyY = -s.PounceLatchCrouch * geo.scale * k - s.PounceSlashDip * geo.scale * dip
	local rz = rad(-s.PounceLatchLean * k - s.PounceSlashLean * dip)
	local bodyRot = CFrame.Angles(0, 0, rz)
	out.RootJoint = CFrame.new(0, bodyY, 0) * bodyRot
	-- feet gripping the surface at their rest spots (as latch)
	local counter = CFrame.Angles(0, 0, -rz)
	for _, S in ipairs({"L", "R"}) do
		local hip = geo["hip" .. S]
		local shift = bodyRot * hip - hip
		local T = Vector2.new(geo.A0.X - shift.X, geo.A0.Y - bodyY - shift.Y)
		local dHip, dKnee, dShin = solveLeg(geo, T)
		out["Leg" .. S] = counter * CFrame.Angles(0, 0, dHip)
		out["Knee" .. S] = CFrame.Angles(0, 0, dKnee)
		out["Ankle" .. S] = CFrame.Angles(0, 0, -dShin)
	end
	-- arms: splay first (about the shoulder's forward axis), then pitch
	local L, R = arms.L or {}, arms.R or {}
	out.ArmL = CFrame.Angles(0, 0, rad(L.p or s.PounceLatchArms * k)) * CFrame.Angles(rad(-(L.sp or 0)), 0, 0)
	out.ArmR = CFrame.Angles(0, 0, rad(R.p or s.PounceLatchArms * k)) * CFrame.Angles(rad(R.sp or 0), 0, 0)
	-- head low, turning toward the striking arm; jaws half open with a snarl
	local turn = s.PounceSlashHeadTurn * dip * (arms.side == "R" and 1 or -1)
	out.Neck = CFrame.Angles(0, rad(turn * 0.6), rad(-s.PounceLatchNeck * k) - rz * 0.4)
	out.Head = CFrame.Angles(0, rad(turn * 0.4), rad(s.PounceLatchHead * k))
	out.Jaw = CFrame.Angles(0, 0, rad(-(s.PounceLatchJawOpen * k + s.PounceSnarl * sin(t * 28))))
	tailStraight(out, -rz * 0.6, 8 * sin(t * 5) + 6 * dip)
	return out
end

function PouncePose.settings(model)
	local s = {}
	for k, v in pairs(PouncePose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

return PouncePose
