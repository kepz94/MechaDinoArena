-- EmotePose v1.0 (Mecha Dino Arena) — the 12 battle emotes as joint offsets on the shared rig 1.3 joints, so one emote fits all 8 dinos.
-- Plan docs/plans/EMOTES_v1.0.md; the maths is mockup docs/mockups/battle_emotes_v0.2.html (Kepu 2026-11-24 "keep all of these").
-- Pure: EmotePose.get(id, f, t, R) -> {[joint] = CFrame}. f = 0..1 over the emote, t = seconds in. Multiplied onto the current pose by
-- IdleAnimation 1.48 (like RoarPose). Joint frames: X forward, Y up, Z side; rz = pitch (+ lifts the front), ry = yaw, rx = roll.
-- R (EmotePose.rig): h = root height over the ground (HipHeight + HRP half height), th = torso top over the root, sL = the side
-- (+1 / -1 on Z) the L joints sit on, elbow = the rig has ElbowL / ElbowR (Therizino). Props go in the L hand (pa = sL).
-- Props and pop-up words are EmoteFX 1.0 (client); this module only moves joints.

local EmotePose = {}

EmotePose.Version = "1.0"

local rad, sin, cos, abs, exp, floor, max, min, pi = math.rad, math.sin, math.cos, math.abs, math.exp, math.floor, math.max, math.min, math.pi
local function cl(x, a, b) return min(b or 1, max(a or 0, x)) end
local function sm(x) x = cl(x) return x * x * (3 - 2 * x) end
local function env(f, inF, outF) return sm(f / inF) * (1 - sm((f - (1 - outF)) / outF)) end
local function pulse(t, a, b, c, d) return sm((t - a) / (b - a)) * (1 - sm((t - c) / (d - c))) end
local function bump(t, a, len) local x = (t - a) / len return (x > 0 and x < 1) and sin(pi * x) or 0 end

-- additive accumulator, turned into CFrames at the end (same as the mockup's P.add / P.pair)
local function newP(R)
	local v = {}
	local P = {}
	function P.add(n, rx, ry, rz, tx, ty, tz)
		local o = v[n]
		if not o then o = {0, 0, 0, 0, 0, 0} v[n] = o end
		o[1] += rx or 0 o[2] += ry or 0 o[3] += rz or 0 o[4] += tx or 0 o[5] += ty or 0 o[6] += tz or 0
	end
	function P.pair(base, fn)
		P.add(base .. "L", table.unpack(fn(R.sL)))
		P.add(base .. "R", table.unpack(fn(-R.sL)))
	end
	function P.out()
		local out = {}
		for n, o in pairs(v) do
			out[n] = CFrame.new(o[4], o[5], o[6]) * CFrame.Angles(rad(o[1]), rad(o[2]), rad(o[3]))
		end
		return out
	end
	return P
end

local POSES = {}

POSES.cooked = function(P, f, t, R)
	local e, flip, call = env(f, .06, .1), bump(t, .7, .3) + bump(t, 1.25, .3), pulse(t, 1.75, 1.9, 2.6, 2.85)
	P.add("RootJoint", 0, 0, (4 + 8 * call) * e, 0, .02 * R.h * flip * e, 0); P.pair("Leg", function() return {0, 0, -(4 + 8 * call) * e} end)
	P.pair("Arm", function(s) if s == R.pa then return {-s * 15 * e, 0, (35 + 40 * flip + 10 * call) * e} end return {-s * 25 * call * e, 0, (5 + 70 * call) * e} end)
	P.pair("Elbow", function() return {0, 0, 30 * e} end)
	P.add("Neck", 0, 0, (-8 * flip + 8 * call) * e)
	P.add("Head", 0, -R.sL * 10 * sin(t * 3) * (1 - call) * e, (10 * flip + 16 * call) * e)
	P.add("Jaw", 0, 0, (-6 * flip - 30 * call - 6 * call * sin(t * 30)) * e)
	P.add("Tail1", 0, 16 * sin(t * 9) * call * e, 10 * e); P.add("Tail2", 0, 12 * sin(t * 9 - 1) * call * e, 0)
end
POSES.mic = function(P, f, t, R)
	local e, hold, aft = env(f, .06, .1), sm((t - .15) / .35) * (1 - sm((t - .95) / .12)), sm((t - 1.1) / .3)
	P.pair("Arm", function(s) if s == R.pa then return {-s * 40 * hold * e, 0, (75 * hold + 10) * e} end return {0, 0, -10 * aft * e} end)
	P.pair("Elbow", function(s) if s == R.pa then return {0, 0, -20 * hold * e} end return {0, 0, 0} end)
	P.add("RootJoint", 0, 14 * aft * e, 6 * aft * e); P.pair("Leg", function() return {0, -14 * aft * e, -6 * aft * e} end)
	P.add("Neck", 0, 10 * aft * e, 10 * aft * e); P.add("Head", 0, R.sL * (-12 * hold + 30 * aft) * e, (5 * hold + 16 * aft) * e)
	P.add("Tail1", 0, 0, 8 * aft * e); P.add("Tail2", 0, 6 * sin(t * 4) * aft * e, 0)
end
POSES.skill = function(P, f, t, R)
	local e, up = env(f, .06, .1), sm((t - .1) / .3)
	local pump = sin(2 * pi * 2.2 * t) * up
	local ap = (55 + 14 * pump) * e
	P.pair("Arm", function(s) return {-s * 15 * e, 0, ap} end); P.pair("Elbow", function() return {0, 0, 25 * e} end)
	P.add("RootJoint", 0, 0, 4 * e, 0, .02 * R.h * abs(pump) * e, 0)
	P.add("Head", 0, 0, 10 * pump * e); P.add("Jaw", 0, 0, -20 * max(0, pump) * e)
	P.add("Tail1", 0, 12 * sin(t * 7) * e, 8 * e)
end
POSES.tea = function(P, f, t, R)
	local e, up, smug = env(f, .06, .1), pulse(t, .45, .8, 1.55, 1.9), pulse(t, 1.95, 2.15, 2.7, 2.95)
	local ap = (30 + 40 * up) * e
	P.add("RootJoint", 0, 0, 5 * e); P.pair("Leg", function() return {0, 0, -5 * e} end)
	P.pair("Arm", function(s) if s == R.pa then return {-s * 45 * e, 0, ap} end return {-s * 25 * smug * e, 0, 10 * e} end)
	P.add("Neck", 0, 0, (10 - 24 * up) * e); P.add("Head", -R.sL * 16 * smug * e, 0, (-12 * up + 14 * smug) * e)
	P.add("Jaw", 0, 0, -6 * up * e)
end
POSES.easy = function(P, f, t, R)
	local e, lean = env(f, .06, .1), sm((t - .55) / .3)
	local nod = (t > .8 and t < 2) and sin(2 * pi * 1.6 * (t - .8)) or 0
	P.add("RootJoint", 0, 8 * lean * e, 8 * lean * e); P.pair("Leg", function() return {0, -8 * lean * e, -8 * lean * e} end)
	P.add("Neck", 0, 0, 6 * lean * e); P.add("Head", 0, -R.sL * 10 * lean * e, 10 * nod * e)
	P.pair("Arm", function(s) if s == R.pa then return {-s * 30 * lean * e, 0, 30 * lean * e} end return {0, 0, 0} end)
	P.add("Tail1", 0, 10 * sin(t * 3) * e, 6 * e)
end
POSES.party = function(P, f, t, R)
	local e, crouch, hop, wig = env(f, .04, .1), pulse(t, .1, .25, .28, .35), bump(t, .3, .45), pulse(t, .85, 1, 2.2, 2.45)
	P.add("RootJoint", 8 * sin(t * 12) * wig * e, 0, 6 * hop * e, 0, (.4 * R.h * hop - .08 * R.h * crouch) * e, 0)
	P.pair("Leg", function() return {0, 0, (30 * hop + 10 * crouch) * e} end); P.pair("Knee", function() return {0, 0, (-50 * hop - 25 * crouch) * e} end)
	P.pair("Ankle", function() return {0, 0, (20 * hop + 15 * crouch) * e} end)
	P.pair("Arm", function(s) return {-s * 30 * e, 0, (40 + 40 * hop + 22 * sin(t * 14 + s) * wig) * e} end)
	P.add("Head", 0, 0, 15 * hop * e); P.add("Jaw", 0, 0, (-25 * hop - 12 * wig * (.5 + .5 * sin(t * 16))) * e)
	for k = 1, 4 do P.add("Tail" .. k, 0, (8 + 4 * k) * sin(t * 10 - k * .7) * wig * e, k == 1 and 15 * e or 0) end
end
POSES.stomp = function(P, f, t, R)
	local e, u = env(f, .08, .14), (t - .2) / .42
	local k = floor(u)
	local p = u - k
	local lift, jolt = 0, 0
	local side = (k % 2 == 0) and 1 or -1
	if k >= 0 and k < 4 then
		lift = p < .55 and sm(p / .55) or (p < .68 and 1 - ((p - .55) / .13) ^ 2 or 0)
		jolt = p >= .68 and exp(-(p - .68) * 12) or 0
	end
	local ls = side * R.sL
	P.pair("Leg", function(s) return s == ls and {0, 0, 42 * lift * e} or {0, 0, -4 * lift * e} end)
	P.pair("Knee", function(s) return s == ls and {0, 0, -58 * lift * e} or {0, 0, -8 * e} end)
	P.pair("Ankle", function(s) return s == ls and {0, 0, 22 * lift * e} or {0, 0, 6 * e} end)
	P.add("RootJoint", -ls * 7 * lift * e, 0, (6 * lift - 5 * jolt) * e, 0, -.06 * R.h * jolt * e, 0)
	P.add("Neck", 0, 0, (-6 * lift + 6 * jolt) * e); P.add("Head", 0, 0, -12 * jolt * e); P.add("Jaw", 0, 0, -26 * jolt * e)
	P.pair("Arm", function(s) return {-s * 20 * e, 0, (20 + 25 * lift) * e} end)
	P.add("Tail1", 0, 0, 14 * lift * e); P.add("Tail2", 0, 0, -8 * jolt * e)
end
POSES.moon = function(P, f, t, R)
	local e, c = env(f, .18, .18), pulse(f, .28, .38, .8, .9)
	P.add("RootJoint", 0, 0, 30 * e, 0, -.2 * R.h * e, 0)
	P.pair("Leg", function() return {0, 0, 18 * e} end); P.pair("Knee", function() return {0, 0, -72 * e} end); P.pair("Ankle", function() return {0, 0, 30 * e} end)
	P.add("Neck", 0, 3 * sin(t * 11) * c, 26 * e); P.add("Head", 0, 0, 6 * e + 26 * c)
	P.add("Jaw", 0, 0, -30 * c - 4 * c * sin(t * 38))
	P.pair("Arm", function() return {0, 0, -28 * e} end)
	P.add("Tail1", 0, 0, -26 * e); P.add("Tail2", 0, 0, -6 * e); P.add("Tail3", 0, 4 * sin(t * 3), 0)
end
POSES.shake = function(P, f, t, R)
	local A, w = env(f, .1, .28), 2 * pi * 6.5
	local function ph(k) return w * t - k * .95 end
	P.add("Head", 26 * A * sin(ph(0)), 10 * A * sin(ph(0) + 1), 0); P.add("Neck", 16 * A * sin(ph(1)), 8 * A * sin(ph(1) + 1), 4 * A)
	P.add("RootJoint", 9 * A * sin(ph(2)), 4 * A * sin(ph(2) + 1), 0, 0, .025 * R.h * A * abs(sin(2 * ph(2))), 0)
	for k = 1, 5 do P.add("Tail" .. k, 4 * A * sin(ph(2 + k)), (12 + 5 * k) * A * sin(ph(2 + k)), 0) end
	P.add("Jaw", 0, 0, -10 * A * (.5 + .5 * sin(ph(0) * 2)))
	P.pair("Arm", function(s) return {-s * 18 * A * sin(ph(2)), 0, 10 * A} end)
end
POSES.arms = function(P, f, t, R)
	local e, w = env(f, .14, .18), 2 * pi * 1.7
	local c = sin(w * t)
	P.add("RootJoint", 0, 0, 9 * e, 0, .03 * R.h * e, 0); P.pair("Leg", function() return {0, 0, -9 * e} end)
	P.pair("Arm", function(s) return {-s * 40 * e, 0, (R.elbow and 30 or (45 + 28 * c * s * R.sL)) * e} end)
	P.pair("Elbow", function(s) return {0, 0, (60 + 30 * c * s * R.sL) * e} end)
	P.add("Neck", 0, 0, -4 * e); P.add("Head", 0, -R.sL * 30 * c * e, -10 * e); P.add("Jaw", 0, 0, -8 * e)
	P.add("Tail1", 0, 0, 10 * e); P.add("Tail2", 0, 6 * sin(t * 5), 0)
end
POSES.dead = function(P, f, t, R)
	local e = env(f, .04, .04)
	local wob, down, up = pulse(t, 0, .1, .4, .55), sm((t - .45) / .5), sm((t - 2.6) / .45)
	local roll, lie = 180 * down + 180 * up, down * (1 - up)
	local hop = sin(pi * cl((t - 2.6) / .45)) * .35 * R.h
	local tw = pulse(t, 1.6, 1.65, 1.75, 1.85) + pulse(t, 2.05, 2.1, 2.2, 2.3)
	P.add("RootJoint", (roll + 8 * sin(t * 18) * wob) * e, 0, 6 * wob * e, 0, (-(R.h - R.th) * lie + hop) * e, 0)
	P.pair("Leg", function() return {0, 0, (-10 * lie + 14 * tw) * e} end); P.pair("Knee", function() return {0, 0, (12 * lie - 20 * tw) * e} end)
	P.pair("Ankle", function() return {0, 0, 10 * tw * e} end)
	P.pair("Arm", function() return {0, 0, (40 * wob - 40 * lie) * e} end)
	P.add("Neck", 0, 0, (10 * wob - 20 * lie) * e); P.add("Head", -R.sL * 25 * lie * e, 0, -10 * lie * e); P.add("Jaw", 0, 0, (-22 * lie - 18 * wob) * e)
	P.add("Tail1", 0, 0, -18 * lie * e)
end
POSES.yawn = function(P, f, t, R)
	local e = env(f, .1, .16)
	local o = t < 1.75 and sm((t - .2) / .95) or 1 - sm((t - 1.75) / .1)
	local sh = t > 1.85 and exp(-(t - 1.85) * 5) * sin((t - 1.85) * 26) or 0
	P.add("RootJoint", 0, 0, -8 * o * e, 0, -.03 * R.h * o * e, 0); P.pair("Leg", function() return {0, 0, 8 * o * e} end)
	P.add("Neck", 0, 12 * sh * e, 16 * o * e); P.add("Head", 12 * o * e, 6 * sh * e, 22 * o * e)
	P.add("Jaw", 0, 0, -50 * o * e)
	P.pair("Arm", function(s) return {-s * 14 * o * e, 0, 60 * o * e} end); P.pair("Elbow", function() return {0, 0, -30 * o * e} end)
	P.add("Tail1", 0, 0, 14 * o * e); P.add("Tail2", 0, 0, 6 * o * e)
end

EmotePose.IDS = {}
for id in pairs(POSES) do EmotePose.IDS[id] = true end

-- R from a live (or viewport) dino model; motors = {[jointName] = {motor = Motor6D, restC0 = CFrame}} or nil (read from the model)
function EmotePose.rig(model, motors)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	local h = (hrp and hrp.Size.Y / 2 or 2) + (hum and hum.HipHeight or 2)
	local function c0(name)
		local e = motors and motors[name]
		if e then return e.restC0 end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") and d.Name == name then return d.C0 end
		end
		return nil
	end
	local legL = c0("LegL")
	local sL = (legL and legL.Position.Z < 0) and -1 or 1
	local th = .3 * h
	local torso = model:FindFirstChild("Torso")
	local root = torso and torso:FindFirstChild("Root")
	if root then
		local top = -math.huge
		for _, p in ipairs(torso:GetChildren()) do
			if p:IsA("BasePart") and p ~= root and p.Transparency < 1 then
				local rel = root.CFrame:ToObjectSpace(p.CFrame)
				local s = p.Size / 2
				local ext = abs(rel.RightVector.Y) * s.X + abs(rel.UpVector.Y) * s.Y + abs(rel.LookVector.Y) * s.Z
				top = max(top, rel.Position.Y + ext)
			end
		end
		if top > -math.huge then th = max(.3, top) end
	end
	return {h = h, th = th, sL = sL, pa = sL, elbow = c0("ElbowL") ~= nil}
end

-- id, f (0..1), t (s), R (EmotePose.rig) -> {[joint] = CFrame} or nil
function EmotePose.get(id, f, t, R)
	local fn = POSES[id]
	if not (fn and R) then return nil end
	local P = newP(R)
	fn(P, cl(f), max(0, t), R)
	return P.out()
end

return EmotePose
