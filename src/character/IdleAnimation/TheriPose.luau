-- TheriPose v1.0 (Mecha Dino Arena) — the Therizinosaurus' animation layers for IdleAnimation 1.39: the 3-hit claw combo
-- ("A Reaper Sweeps"), the Diving Rake leap (J1) and the Sidewinder run (B). MDA-203, plan docs/plans/THERIZINO_KIT_v1.0.md
-- Task 6; mockups docs/mockups/therizino_kit_options_v0.3.html (Kepu 2026-11-02 "I like this one") and
-- docs/mockups/therizino_run_options.html v0.1 (Kepu: "B Sidewinder"). Key poses = tools/therizino_kit_keys_v0.3.py /
-- tools/therizino_run_keys_v0.1.py (arm angles solved from claw-tip targets); timings, springs, tremble, root push and ground
-- lock = the mockups' anim / run code.
-- Angles: degrees {p, y, r} on the rig's joint frames (rig 1.3 + ElbowL/R, WristL/R: TherizinoModelData 1.3+). Joint pose =
--   restC0 * pose; rotation = CFrame.fromEulerAngles(rad(r), rad(y), rad(p), ZYX) (= the mockup's three.js Euler(r, y, p,
--   "ZYX"); TenoPose / SlashPose use the same mapping). p: RootJoint / Neck / Head - = lean or nod forward; Arm / Elbow /
--   Wrist + = swing forward and up; Leg + = thigh forward; Knee - = bend; Tail - = lift; Jaw - = open. y: RootJoint + = turn
--   right. r: ArmR + = out to the side. Left joints mirror y and r.
-- Who: models with Species "Therizino" and TheriPoseEnabled ~= false (TheriPose.on). Every other model: nothing (IdleAnimation
--   calls nothing here for them).
-- Combo layer (multiplied on top of the current pose, after the teno layers; sprung):
--   Stamps: the owner's client reads TheriLocalStep / TheriLocalAt (TheriAttackTest 1.0, at the tap); other clients read
--   TheriComboStep / TheriComboAt (TheriAttackServer 1.0; none once TheriComboCancelAt >= TheriComboAt). Each new (step, at)
--   starts a step; t = server time - at.
--   Step 1 (right cut):  0 READY, 0.22 R_W (io), 0.29 R_S (in2), 0.41 R_F (out), 0.75 READY (io).
--   Step 2 (left cut):   0 the target at the tap, 0.19 L_W (io), 0.26 L_S (in2), 0.38 L_F (out), 0.75 READY (io).
--   Step 3 (finisher):   0 the target at the tap, 0.34 REAR (io), 0.46 REAR2 (io; arms and wrists tremble), 0.55 CHOP (in),
--                        0.81 CHOP_SET (out), 1.36 READY (io).
--   (= the mockup's single 2.4 s timeline cut at its taps 0 / 0.41 / 0.79.) READY is held to TheriChainHold (0.8 s; steps 1
--   and 2) or the last key, then fades to the plain stance over TheriFadeTime (0.5 s); the layer weight follows the fade.
--   Root push (the mockup's root fwd, studs at scale 2, x scale / 2): R_W -0.5, R_S 1, R_F 1.3 (L_* the same), REAR -1,
--   REAR2 -1.4, CHOP / CHOP_SET 2, through its own spring (w 20, z 0.9).
-- Leap layer (replaces the pose by its weight, like TenoPose's leap; sprung), from IdleAnimation's leap tracker (JumpStartedAt /
--   JumpPredictedAt, airborne, landing); IdleAnimation 1.39 turns the biped JumpPose off for these models:
--   crouch (t < JumpWindup): READY -> J_CROUCH (io), weight io(t / (JumpWindup / 2)); push (before lift-off): J_CROUCH ->
--   J_AIR over 0.19 s (out); air: the same, and the down-rake starts as the ground nears: J_LAND by in((0.13 - time to ground)
--   / 0.13) (time to ground = ground gap / fall speed; the mockup's J_AIR -> J_LAND 0.13 s before the touchdown); land
--   (s since the touchdown): 0 J_LAND, 0.31 CHOP_SET (out), 0.96 READY (io), then the weight fades to 0 by TheriLeapLandTime
--   (1.4 s); CHOP_SET's root push 2 applies.
-- Run layer (Sidewinder; multiplied on top, its own softer springs): weight = walk blend x gait blend x (1 - creep) x (1 - combo
--   weight) x (1 - leap weight). RUN_B posture (hunched RootJoint -24, neck low, right arm out wide with the claws dragging,
--   left arm tucked) + the mockup's run motion on the walk phase (lean -4 + 3 sin 2ph, sway 4, roll 2.5, neck / head
--   counter-bob, tail sway, arm pumps, the dragging wrist skipping). The legs stay WalkPose's: the RootJoint part of the run
--   layer is taken back out of the hips (LegL / LegR = E^-1 * pose), so the feet keep their steps.
--   Drag: each frame the right wrist bends (pitch, Newton steps on the measured slope, at most 3, within +-45 degrees,
--   x the run weight) so the lowest right claw tip sits TheriDragClearance (0.15) studs above the ground under it (raycast
--   at each tip); no ground within reach (a jump, a ledge) = no bend, so the claws lift clear.
-- Claw floor (every frame, the left hand always, the right one when not dragging): a wrist only bends (same solver) to lift
--   claw tips that would be under TheriClawFloor (0.1) studs above the ground (the combo's CHOP_SET -> READY sweep and the
--   leap landing went ~1-2 studs into the floor without it).
-- Ground lock (combo and leap crouch / push / land): the body moves up / down so the lowest foot point is where the rest pose
--   puts it (the mockup kept the feet on the ground the same way); clamped +-3 x scale / 2 studs.
-- Switches (model attributes, read each frame): TheriPoseEnabled (default true; false = no layers, the biped jump pose plays),
--   TheriRunPoseEnabled (true), TheriLeapPoseEnabled (true; false = the biped jump pose), TheriGroundLockEnabled (true),
--   TheriDragEnabled (true), TheriClawFloorEnabled (true).
-- Test hook: model attribute TheriPoseTestKey = a key name ("READY" ... "J_LAND", "RUN_B"): every joint shows that key exactly
--   (replaced, no springs / push / lock / drag); used for the tip parity check. Unset in play.
-- Diagnostics (model attributes, this client): TheriPoseVersion, TheriPoseState ("none" / "step1".."step3" / "test:<key>"),
--   TheriPoseSource ("local" / "server"), TheriPoseWeight, TheriLeapPhase ("none" / "crouch" / "push" / "air" / "land"),
--   TheriRunBlend, TheriGroundShift (studs), TheriDragGap (lowest right tip above the ground after the bend, studs; -1 = no
--   ground), TheriDragBend (degrees), TheriClawLift (degrees, the largest claw-floor bend this frame).
-- v1.1 (Kepu 2026-11-02 "publish what is for sure done"): TheriRunPoseEnabled defaults to false: the Sidewinder drag does not
--   reach the ground at full run yet (right claw tips 7-9 studs up; MDA-203 item 4). A model attribute TheriRunPoseEnabled =
--   true turns the 1.0 run layer back on. Nothing else changed.
local TheriPose = {}
TheriPose.Version = "1.1"
TheriPose.Defaults = {
	TheriPoseEnabled = true, TheriRunPoseEnabled = false, TheriLeapPoseEnabled = true, TheriGroundLockEnabled = true,
	TheriDragEnabled = true, TheriChainHold = 0.8, TheriFadeTime = 0.5, TheriLeapLandTime = 1.4, TheriDragClearance = 0.15,
	TheriClawFloorEnabled = true, TheriClawFloor = 0.1,
}

local JOINTS = {"RootJoint", "Neck", "Head", "Jaw", "ArmL", "ElbowL", "WristL", "ArmR", "ElbowR", "WristR", "Tail1", "Tail2",
	"Tail3", "Tail4", "Tail5", "LegL", "LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"}
TheriPose.JOINTS = JOINTS

local KEYS = {}
KEYS.READY = {RootJoint = {-6, 0, 0}, Neck = {-4, 0, 0}, LegL = {10, 0, 0}, LegR = {10, 0, 0}, KneeL = {-16, 0, 0},
	KneeR = {-16, 0, 0}, AnkleL = {6, 0, 0}, AnkleR = {6, 0, 0}}
KEYS.R_W = {RootJoint = {6, 26, -4}, Neck = {-2, -14, 0}, Head = {0, -8, 0}, ArmR = {58, -11, 81},
	ElbowR = {3, 0, 0}, WristR = {15, 0, 0}, Tail1 = {0, -8, 0}, LegL = {4, 0, 0}, LegR = {12, 0, 0},
	KneeL = {-8, 0, 0}, KneeR = {-22, 0, 0}}
KEYS.R_S = {RootJoint = {-12, -12, 3}, Neck = {-6, 10, 0}, ArmR = {88, 18, -41}, ElbowR = {27, 0, 0},
	WristR = {-62, 0, 0}, Tail1 = {0, 6, 0}, LegL = {18, 0, 0}, LegR = {-4, 0, 0}, KneeL = {-26, 0, 0},
	AnkleL = {8, 0, 0}}
KEYS.R_F = {RootJoint = {-16, -34, 5}, Neck = {-6, 18, 0}, Head = {0, 8, 0}, ArmR = {55, -64, -60},
	ElbowR = {21, 0, 0}, WristR = {1, 0, 0}, Tail1 = {0, 12, 0}, LegL = {18, 0, 0}, LegR = {-6, 0, 0},
	KneeL = {-26, 0, 0}, AnkleL = {8, 0, 0}}
KEYS.L_W = {RootJoint = {6, -26, 4}, Neck = {-2, 14, 0}, Head = {0, 8, 0}, ArmL = {58, 11, -81}, ElbowL = {3, 0, 0},
	WristL = {15, 0, 0}, Tail1 = {0, 8, 0}, LegL = {12, 0, 0}, LegR = {4, 0, 0}, KneeL = {-22, 0, 0},
	KneeR = {-8, 0, 0}}
KEYS.L_S = {RootJoint = {-12, 12, -3}, Neck = {-6, -10, 0}, ArmL = {88, -18, 41}, ElbowL = {27, 0, 0},
	WristL = {-62, 0, 0}, Tail1 = {0, -6, 0}, LegL = {-4, 0, 0}, LegR = {18, 0, 0}, KneeR = {-26, 0, 0},
	AnkleR = {8, 0, 0}}
KEYS.L_F = {RootJoint = {-16, 34, -5}, Neck = {-6, -18, 0}, Head = {0, -8, 0}, ArmL = {55, 64, 60},
	ElbowL = {21, 0, 0}, WristL = {1, 0, 0}, Tail1 = {0, -12, 0}, LegL = {-6, 0, 0}, LegR = {18, 0, 0},
	KneeR = {-26, 0, 0}, AnkleR = {8, 0, 0}}
KEYS.REAR = {RootJoint = {20, 0, 0}, Neck = {12, 0, 0}, Head = {10, 0, 0}, Jaw = {-30, 0, 0},
	ArmL = {-25, -82, -107}, WristL = {3, 0, 0}, ArmR = {-25, 82, 107}, WristR = {3, 0, 0}, Tail1 = {12, 0, 0},
	Tail2 = {6, 0, 0}, LegL = {-6, 0, 0}, LegR = {-6, 0, 0}, KneeL = {4, 0, 0}, KneeR = {4, 0, 0}}
KEYS.REAR2 = {RootJoint = {24, 0, 0}, Neck = {14, 0, 0}, Head = {12, 0, 0}, Jaw = {-34, 0, 0},
	ArmL = {-18, -83, -114}, WristL = {9, 0, 0}, ArmR = {-18, 83, 114}, WristR = {9, 0, 0}, Tail1 = {14, 0, 0},
	Tail2 = {8, 0, 0}, LegL = {-8, 0, 0}, LegR = {-8, 0, 0}, KneeL = {4, 0, 0}, KneeR = {4, 0, 0}}
KEYS.CHOP = {RootJoint = {-30, 0, 0}, Neck = {-18, 0, 0}, Head = {-8, 0, 0}, Jaw = {-8, 0, 0}, ArmL = {75, 46, 30},
	ElbowL = {47, 0, 0}, WristL = {-57, 0, 0}, ArmR = {75, -46, -30}, ElbowR = {47, 0, 0}, WristR = {-57, 0, 0},
	Tail1 = {10, 0, 0}, LegL = {26, 0, 0}, LegR = {26, 0, 0}, KneeL = {-40, 0, 0}, KneeR = {-40, 0, 0},
	AnkleL = {14, 0, 0}, AnkleR = {14, 0, 0}}
KEYS.CHOP_SET = {RootJoint = {-26, 0, 0}, Neck = {-14, 0, 0}, Head = {-6, 0, 0}, ArmL = {76, 25, 33},
	ElbowL = {51, 0, 0}, WristL = {-69, 0, 0}, ArmR = {76, -25, -33}, ElbowR = {51, 0, 0}, WristR = {-69, 0, 0},
	Tail1 = {8, 0, 0}, LegL = {22, 0, 0}, LegR = {22, 0, 0}, KneeL = {-34, 0, 0}, KneeR = {-34, 0, 0},
	AnkleL = {12, 0, 0}, AnkleR = {12, 0, 0}}
KEYS.J_CROUCH = {RootJoint = {-14, 0, 0}, Neck = {-8, 0, 0}, ArmL = {85, -76, -90}, WristL = {3, 0, 0},
	ArmR = {85, 76, 90}, WristR = {3, 0, 0}, Tail1 = {-4, 0, 0}, LegL = {32, 0, 0}, LegR = {32, 0, 0},
	KneeL = {-58, 0, 0}, KneeR = {-58, 0, 0}, AnkleL = {26, 0, 0}, AnkleR = {26, 0, 0}}
KEYS.J_AIR = {RootJoint = {12, 0, 0}, Neck = {8, 0, 0}, Head = {6, 0, 0}, Jaw = {-28, 0, 0}, ArmL = {-15, -85, -108},
	WristL = {6, 0, 0}, ArmR = {-15, 85, 108}, WristR = {6, 0, 0}, Tail1 = {-8, 0, 0}, Tail2 = {-6, 0, 0},
	LegL = {45, 0, 0}, LegR = {45, 0, 0}, KneeL = {-72, 0, 0}, KneeR = {-72, 0, 0}, AnkleL = {22, 0, 0},
	AnkleR = {22, 0, 0}}
KEYS.J_LAND = {RootJoint = {-32, 0, 0}, Neck = {-20, 0, 0}, Head = {-8, 0, 0}, Jaw = {-8, 0, 0}, ArmL = {83, 12, 27},
	WristL = {-13, 0, 0}, ArmR = {83, -12, -27}, WristR = {-13, 0, 0}, Tail1 = {10, 0, 0}, LegL = {36, 0, 0},
	LegR = {36, 0, 0}, KneeL = {-64, 0, 0}, KneeR = {-64, 0, 0}, AnkleL = {26, 0, 0}, AnkleR = {26, 0, 0}}
KEYS.RUN_B = {RootJoint = {-24, 0, 0}, Neck = {-14, 0, 0}, Head = {12, 0, 0}, Jaw = {-6, 0, 0}, ArmL = {32, 27, 60},
	ElbowL = {130, 0, 0}, WristL = {-26, 0, 0}, ArmR = {-14, 18, 2}, WristR = {9, 0, 0}, Tail1 = {-4, 0, 0}}
local FWD = {R_W = -0.5, R_S = 1, R_F = 1.3, L_W = -0.5, L_S = 1, L_F = 1.3, REAR = -1, REAR2 = -1.4, CHOP = 2, CHOP_SET = 2}
KEYS.ZERO = {}
TheriPose.KEYS = KEYS

local STEPS = {
	{{0, "READY"}, {0.22, "R_W", "io"}, {0.29, "R_S", "in2"}, {0.41, "R_F", "out"}, {0.75, "READY", "io"}},
	{{0, "$from"}, {0.19, "L_W", "io"}, {0.26, "L_S", "in2"}, {0.38, "L_F", "out"}, {0.75, "READY", "io"}},
	{{0, "$from"}, {0.34, "REAR", "io"}, {0.46, "REAR2", "io"}, {0.55, "CHOP", "in"}, {0.81, "CHOP_SET", "out"},
		{1.36, "READY", "io"}},
}
local TREMBLE = {0.34, 0.46} -- step 3
local LAND = {{0, "J_LAND"}, {0.31, "CHOP_SET", "out"}, {0.96, "READY", "io"}}

local rad, sin, cos, min, max, clamp = math.rad, math.sin, math.cos, math.min, math.max, math.clamp
local EASE = {
	lin = function(u) return u end,
	io = function(u) return u * u * (3 - 2 * u) end,
	out = function(u) return 1 - (1 - u) ^ 3 end,
	["in"] = function(u) return u * u * u end,
	in2 = function(u) return u * u end,
}
local function rot(v) return CFrame.fromEulerAngles(rad(v[3]), rad(v[2]), rad(v[1]), Enum.RotationOrder.ZYX) end
TheriPose.rot = rot
local function num(v) return typeof(v) == "number" and v or nil end

-- a pose = {a = {joint = {p, y, r}}, fwd = studs}
local function keyPose(name) return {a = KEYS[name], fwd = FWD[name] or 0} end
local function mixP(A, B, u)
	local o = {}
	for k, va in pairs(A.a) do
		local vb = B.a[k] or {0, 0, 0}
		o[k] = {va[1] + (vb[1] - va[1]) * u, va[2] + (vb[2] - va[2]) * u, va[3] + (vb[3] - va[3]) * u}
	end
	for k, vb in pairs(B.a) do
		if not o[k] then o[k] = {vb[1] * u, vb[2] * u, vb[3] * u} end
	end
	return {a = o, fwd = A.fwd + (B.fwd - A.fwd) * u}
end
local function sample(keys, t, from)
	local function at(i)
		local n = keys[i][2]
		return n == "$from" and from or keyPose(n)
	end
	if t <= keys[1][1] then return at(1) end
	for i = 2, #keys do
		if t <= keys[i][1] then
			local a, b = keys[i - 1], keys[i]
			return mixP(at(i - 1), at(i), EASE[b[3] or "io"]((t - a[1]) / (b[1] - a[1])))
		end
	end
	return at(#keys)
end
TheriPose.sample = sample

-- springs (sub-stepped at <= 1/300 s like the mockups)
local function kitK(n)
	if n:match("^Arm") or n:match("^Elbow") or n:match("^Wrist") then return 38, 0.6 end
	if n == "RootJoint" then return 30, 0.85 end
	if n:match("^Leg") or n:match("^Knee") or n:match("^Ankle") then return 34, 0.9 end
	if n == "Neck" then return 20, 0.6 end
	if n == "Head" then return 16, 0.55 end
	if n == "Jaw" then return 28, 0.45 end
	local tn = tonumber(n:match("^Tail(%d)"))
	if tn then return 18 - 2.2 * tn, 0.42 end
	return 24, 0.8
end
local function runK(n)
	if n:match("^Arm") or n:match("^Elbow") or n:match("^Wrist") then return 26, 0.55 end
	if n == "RootJoint" then return 24, 0.8 end
	if n:match("^Leg") or n:match("^Knee") or n:match("^Ankle") then return 60, 1 end
	if n == "Neck" then return 14, 0.55 end
	if n == "Head" then return 12, 0.5 end
	if n == "Jaw" then return 18, 0.4 end
	local tn = tonumber(n:match("^Tail(%d)"))
	if tn then return 14 - 1.8 * tn, 0.4 end
	return 20, 0.8
end
local function newSprings(kfn)
	local S = {j = {}, fwd = {x = 0, v = 0}, settled = true}
	for _, n in ipairs(JOINTS) do
		local w, z = kfn(n)
		S.j[n] = {x = {0, 0, 0}, v = {0, 0, 0}, w = w, z = z}
	end
	return S
end
-- step toward the target pose (missing joints = 0); returns the sprung pose; S.settled when everything is ~0 and still
local function springStep(S, target, dt, init)
	local steps = clamp(math.ceil(dt * 300), 1, 40)
	local h = dt / steps
	local busy = false
	for n, s in pairs(S.j) do
		local tv = target.a[n] or {0, 0, 0}
		if init then
			s.x = {tv[1], tv[2], tv[3]}
			s.v = {0, 0, 0}
		else
			local w, z = s.w, s.z
			for _ = 1, steps do
				for i = 1, 3 do
					local acc = w * w * (tv[i] - s.x[i]) - 2 * z * w * s.v[i]
					s.v[i] += acc * h
					s.x[i] += s.v[i] * h
				end
			end
		end
		for i = 1, 3 do
			if math.abs(s.x[i]) > 0.01 or math.abs(s.v[i]) > 0.01 or tv[i] ~= 0 then busy = true end
		end
	end
	local f = S.fwd
	if init then
		f.x, f.v = target.fwd, 0
	else
		for _ = 1, steps do
			f.v += (400 * (target.fwd - f.x) - 2 * 0.9 * 20 * f.v) * h
			f.x += f.v * h
		end
	end
	if math.abs(f.x) > 0.001 or math.abs(f.v) > 0.001 or target.fwd ~= 0 then busy = true end
	S.settled = not busy
	local o = {}
	for n, s in pairs(S.j) do o[n] = {s.x[1], s.x[2], s.x[3]} end
	return {a = o, fwd = f.x}
end
TheriPose.springStep, TheriPose.newSprings = springStep, newSprings

function TheriPose.settings(model)
	local s = {}
	for k, v in pairs(TheriPose.Defaults) do
		local a = model:GetAttribute(k)
		if typeof(a) ~= typeof(v) then a = v end
		s[k] = a
	end
	return s
end
function TheriPose.on(model)
	return model:GetAttribute("Species") == "Therizino" and model:GetAttribute("TheriPoseEnabled") ~= false
end
function TheriPose.leapOn(model)
	return TheriPose.on(model) and model:GetAttribute("TheriLeapPoseEnabled") ~= false
end

-- the state below belongs to one model (each character's IdleAnimation requires its own copy of this module)
local combo = {step = 0, at = nil, from = nil, target = nil, springs = newSprings(kitK), w = 0}
local run = {springs = newSprings(runK), phase = 0, lastPh = nil}
local leapS = {springs = newSprings(kitK), w = 0, lockW = 0, fwd = 0, phase = "none", lastAt = -math.huge, landFrom = nil}
local lockSmooth = 0
local fk -- {FootL = chain, FootR = chain, HandR = chain, scale = s}

local function stepEnd(step, s)
	local keys = STEPS[step]
	local last = keys[#keys][1]
	local hold = step < 3 and max(last, s.TheriChainHold) or last
	return hold, hold + s.TheriFadeTime
end

-- the combo target at t of the current step, and its layer weight
local function comboTarget(s, t, clock)
	local hold, finish = stepEnd(combo.step, s)
	if t >= finish then return nil, 0 end
	local tg, w
	if t <= hold then
		tg, w = sample(STEPS[combo.step], t, combo.from), 1
	else
		local u = EASE.io(clamp((t - hold) / max(0.01, s.TheriFadeTime), 0, 1))
		tg, w = mixP(keyPose("READY"), keyPose("ZERO"), u), 1 - u
	end
	if combo.step == 3 and t > TREMBLE[1] and t < TREMBLE[2] then
		for _, n in ipairs({"ArmL", "ArmR", "WristL", "WristR"}) do
			local v = tg.a[n] or {0, 0, 0}
			local o = {}
			for i = 1, 3 do o[i] = v[i] + sin(clock * 70 + (i - 1) * 2 + #n) * 2.2 end
			tg.a[n] = o
		end
	end
	return tg, w
end

-- forward kinematics ---------------------------------------------------------------------------------------------------
local function buildChain(model, motors, hrpPart, segName)
	local seg = model:FindFirstChild(segName)
	local root = seg and seg:FindFirstChild("Root")
	if not root then return nil end
	local joints, part, guard = {}, root, 0
	while part ~= hrpPart do
		guard += 1
		if guard > 12 then return nil end
		local found
		for name, e in pairs(motors) do
			if e.motor.Part1 == part then found = name break end
		end
		if not found then return nil end
		table.insert(joints, 1, found)
		part = motors[found].motor.Part0
		if not part then return nil end
	end
	local parts, tips = {}, {}
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 and p ~= root then
			table.insert(parts, {off = root.CFrame:Inverse() * p.CFrame, half = p.Size / 2})
			if p.Name:match("_claw%dd$") then
				table.insert(tips, root.CFrame:Inverse() * p.CFrame * Vector3.new(0, p.Size.Y / 2, 0))
			end
		end
	end
	return {joints = joints, parts = parts, tips = tips}
end
local function chainCF(motors, hrpCF, chain, pose)
	local cf = hrpCF
	for _, name in ipairs(chain.joints) do
		local e = motors[name]
		cf = cf * e.restC0 * (pose[name] or CFrame.identity) * e.motor.C1:Inverse()
	end
	return cf
end
local function footLow(motors, hrpCF, pose)
	local low = math.huge
	for _, sn in ipairs({"FootL", "FootR"}) do
		local ch = fk[sn]
		local cf = chainCF(motors, hrpCF, ch, pose)
		for _, pt in ipairs(ch.parts) do
			local w = cf * pt.off
			local hh = pt.half
			local ext = math.abs(w.RightVector.Y) * hh.X + math.abs(w.UpVector.Y) * hh.Y + math.abs(w.LookVector.Y) * hh.Z
			low = min(low, w.Position.Y - ext)
		end
	end
	return low
end
local function ensureFK(model, motors, hrp)
	local sc = model:IsA("Model") and model:GetScale() or 1
	if fk and math.abs(fk.scale - sc) < 1e-4 then return fk.ok end
	fk = {scale = sc, ok = false}
	for _, sn in ipairs({"FootL", "FootR", "HandR", "HandL"}) do
		fk[sn] = buildChain(model, motors, hrp, sn)
		if not fk[sn] then return false end
	end
	fk.ok = #fk.HandR.tips > 0 and #fk.HandL.tips > 0
	return fk.ok
end

-- leap layer -----------------------------------------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- jump = IdleAnimation's leap tracker {start, air, landAt (os.clock), done}; returns {joint = CFrame}, weight
function TheriPose.leap(model, jump, serverNow, now, hrp, dt)
	local s = TheriPose.settings(model)
	local W = num(model:GetAttribute("JumpWindup")) or 0.27
	local phase, x, tg, w, lock = "none", 0, nil, 0, 0
	if jump and jump.landAt and now - jump.landAt < s.TheriLeapLandTime then
		phase, x = "land", now - jump.landAt
	elseif jump and not jump.done and not jump.landAt then
		local t = serverNow - jump.start
		if jump.air then phase, x = "air", max(0, t - W)
		elseif t >= 0 and t < W then phase, x = "crouch", t
		elseif t >= W then phase, x = "push", t - W end
	end
	if phase == "crouch" then
		tg = mixP(keyPose("READY"), keyPose("J_CROUCH"), EASE.io(clamp(x / W, 0, 1)))
		w, lock = EASE.io(clamp(x / max(0.01, W / 2), 0, 1)), 1
	elseif phase == "push" or phase == "air" then
		tg = mixP(keyPose("J_CROUCH"), keyPose("J_AIR"), EASE.out(clamp(x / 0.19, 0, 1)))
		w, lock = 1, phase == "push" and 1 or 0
		if phase == "air" then
			local vy = hrp.AssemblyLinearVelocity.Y
			local hum = model:FindFirstChildOfClass("Humanoid")
			local base = hrp.Size.Y / 2 + (hum and hum.HipHeight or 0)
			rayParams.FilterDescendantsInstances = {model}
			local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -(base + 40), 0), rayParams)
			if hit and vy < -1 then
				local tl = max(0, hrp.Position.Y - hit.Position.Y - base) / -vy
				local k = EASE["in"](clamp(1 - tl / 0.13, 0, 1))
				if k > 0 then tg = mixP(tg, keyPose("J_LAND"), k) end
			end
		end
	elseif phase == "land" then
		tg = sample(LAND, x, nil)
		w = x < 0.96 and 1 or 1 - EASE.io(clamp((x - 0.96) / max(0.01, s.TheriLeapLandTime - 0.96), 0, 1))
		lock = w
	end
	leapS.phase = phase
	if not tg then
		leapS.w, leapS.lockW, leapS.fwd = 0, 0, 0
		return nil, 0
	end
	local init = now - leapS.lastAt > 0.25
	leapS.lastAt = now
	local out = springStep(leapS.springs, tg, dt, init)
	leapS.w, leapS.lockW, leapS.fwd = w, lock * w, out.fwd
	local cfs = {}
	for n, v in pairs(out.a) do cfs[n] = rot(v) end
	return cfs, w
end

-- run motion on top of the posture (the mockup's runLayer without the legs); ph = unwrapped walk phase
local function runMotion(ph)
	local s, c, s2 = sin(ph), cos(ph), sin(ph * 2)
	local lean, sway = -4, 4
	return {
		RootJoint = {lean + 3 * s2, sway * s, 2.5 * s}, Neck = {-3 * s2, -sway * 0.6 * s, -2 * s}, Head = {2 * s2, -sway * 0.4 * s, 0},
		Tail1 = {2 * s2, -sway * 1.2 * sin(ph - 0.5), 0}, Tail2 = {0, -sway * 1.4 * sin(ph - 1.0), 0},
		Tail3 = {0, -sway * 1.6 * sin(ph - 1.5), 0}, Tail4 = {0, -sway * 1.8 * sin(ph - 2.0), 0},
		Tail5 = {0, -sway * 2 * sin(ph - 2.5), 0},
		ArmL = {6 * c, 0, 0}, ElbowL = {4 * s, 0, 0}, WristL = {5 * sin(ph * 2 + 1), 0, 0},
		ArmR = {2 * c, 0, 0}, WristR = {3 * sin(ph * 4.3) + 2 * sin(ph * 7.1), 0, 0},
	}
end

-- wrist solver: bends Wrist<side> (pitch, degrees, Newton steps on the measured slope, at most 3, within +-45) so the lowest
-- claw tip of that hand sits `target` studs above the ground under it (raycast at each tip; ground = terrain or anchored
-- parts, so a target dino's body never counts); liftOnly = only when it is lower.
-- The bend is applied x weight. Returns the gap after (nil = no ground under the tips) and the bend.
local function solveWrist(motors, hrpCF, pose, side, target, liftOnly, weight, model)
	local chain, wrist = fk["Hand" .. side], "Wrist" .. side
	if not chain or not motors[wrist] or #chain.tips == 0 then return nil, 0 end
	rayParams.FilterDescendantsInstances = {model}
	local ground = {}
	local function gapOf(first)
		local cf = chainCF(motors, hrpCF, chain, pose)
		local g = math.huge
		for i, tip in ipairs(chain.tips) do
			local p = cf * tip
			if first then
				local hit = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -10, 0), rayParams)
				ground[i] = (hit and (hit.Instance:IsA("Terrain") or hit.Instance.Anchored)) and hit.Position.Y or false
			end
			if ground[i] then g = min(g, p.Y - ground[i]) end
		end
		return g
	end
	local gap = gapOf(true)
	if gap == math.huge then return nil, 0 end
	if liftOnly and gap >= target then return gap, 0 end
	local base = pose[wrist] or CFrame.identity
	local b = 0
	for _ = 1, 3 do
		local err = gap - target
		if math.abs(err) < 0.05 then break end
		pose[wrist] = base * rot({b + 4, 0, 0})
		local slope = (gapOf(false) - gap) / 4
		if math.abs(slope) < 0.005 then break end
		b = clamp(b - clamp(err / slope, -20, 20), -45, 45)
		pose[wrist] = base * rot({b, 0, 0})
		gap = gapOf(false)
	end
	pose[wrist] = base * rot({b * weight, 0, 0})
	if weight < 1 then gap = gapOf(false) end
	return gap, b * weight
end

-- top layers: combo + run + root push + ground lock + drag. ctx = {isOwner, serverNow, now, dt, runW, walkPhase, show}
function TheriPose.top(model, pose, motors, hrp, ctx)
	local s = TheriPose.settings(model)
	local show = ctx.show
	show("TheriPoseVersion", TheriPose.Version)
	-- test hook: one key, exactly
	local testKey = model:GetAttribute("TheriPoseTestKey")
	if typeof(testKey) == "string" and KEYS[testKey] then
		for _, n in ipairs(JOINTS) do
			if motors[n] then pose[n] = KEYS[testKey][n] and rot(KEYS[testKey][n]) or CFrame.identity end
		end
		show("TheriPoseState", "test:" .. testKey)
		return
	end
	-- combo stamps
	local st, at, src
	if ctx.isOwner then
		st, at, src = num(model:GetAttribute("TheriLocalStep")), num(model:GetAttribute("TheriLocalAt")), "local"
	else
		st, at, src = num(model:GetAttribute("TheriComboStep")), num(model:GetAttribute("TheriComboAt")), "server"
		local c = num(model:GetAttribute("TheriComboCancelAt"))
		if c and at and c >= at then st = 0 end
	end
	st = st and math.floor(st) or 0
	if st >= 1 and st <= 3 and at and (st ~= combo.step or at ~= combo.at) then
		combo.from = combo.target or keyPose("ZERO")
		combo.step, combo.at = st, at
	elseif st == 0 and combo.step ~= 0 then
		combo.step, combo.at = 0, nil
	end
	local tg, cw = nil, 0
	if combo.step ~= 0 then
		tg, cw = comboTarget(s, max(0, ctx.serverNow - combo.at), ctx.now)
		if not tg then combo.step, combo.at = 0, nil end
	end
	combo.target, combo.w = tg, cw
	local cOut
	if tg or not combo.springs.settled then
		cOut = springStep(combo.springs, tg or keyPose("ZERO"), ctx.dt, false)
	end
	show("TheriPoseState", combo.step ~= 0 and ("step" .. combo.step) or "none")
	show("TheriPoseSource", src)
	show("TheriPoseWeight", math.floor(cw * 10 + 0.5) / 10)
	show("TheriLeapPhase", leapS.phase)
	-- run layer
	local dPh = ctx.walkPhase - (run.lastPh or ctx.walkPhase)
	if dPh < -math.pi then dPh += 2 * math.pi elseif dPh > math.pi then dPh -= 2 * math.pi end
	run.phase += dPh
	run.lastPh = ctx.walkPhase
	local rw = s.TheriRunPoseEnabled and clamp(ctx.runW, 0, 1) * (1 - cw) * (1 - leapS.w) or 0
	show("TheriRunBlend", math.floor(rw * 10 + 0.5) / 10)
	local rOut
	if rw > 0.001 or not run.springs.settled then
		local mo = runMotion(run.phase)
		local a = {}
		for n, v in pairs(KEYS.RUN_B) do a[n] = {v[1] * rw, v[2] * rw, v[3] * rw} end
		for n, v in pairs(mo) do
			local b = a[n] or {0, 0, 0}
			a[n] = {b[1] + v[1] * rw, b[2] + v[2] * rw, b[3] + v[3] * rw}
		end
		rOut = springStep(run.springs, {a = a, fwd = 0}, ctx.dt, false)
	end
	-- apply: run (legs keep their world pose), then the combo
	if rOut then
		for n, v in pairs(rOut.a) do
			if motors[n] and n ~= "RootJoint" then pose[n] = (pose[n] or CFrame.identity) * rot(v) end
		end
		local E = rot(rOut.a.RootJoint)
		if motors.RootJoint then pose.RootJoint = (pose.RootJoint or CFrame.identity) * E end
		for _, n in ipairs({"LegL", "LegR"}) do
			if motors[n] then pose[n] = E:Inverse() * (pose[n] or CFrame.identity) end
		end
	end
	if cOut then
		for n, v in pairs(cOut.a) do
			if motors[n] then pose[n] = (pose[n] or CFrame.identity) * rot(v) end
		end
	end
	-- root push + ground lock (RootJoint translation, HRP space)
	local rj = motors.RootJoint
	if not (rj and hrp) then return end
	local sc = model:IsA("Model") and model:GetScale() or 2
	local fwd = ((cOut and cOut.fwd or 0) + leapS.fwd * leapS.w) * sc / 2
	local lockT = s.TheriGroundLockEnabled and max(cw, leapS.lockW) or 0
	lockSmooth += (lockT - lockSmooth) * min(1, ctx.dt * 20)
	if lockSmooth < 0.001 then lockSmooth = 0 end
	local fkOk = ensureFK(model, motors, hrp)
	local up = 0
	if lockSmooth > 0 and fkOk then
		local hrpCF = hrp.CFrame
		local d = footLow(motors, hrpCF, {}) - footLow(motors, hrpCF, pose)
		up = clamp(d, -3 * sc / 2, 3 * sc / 2) * lockSmooth
	end
	show("TheriGroundShift", math.floor(up * 10 + 0.5) / 10)
	if fwd ~= 0 or up ~= 0 then
		local v = hrp.CFrame:VectorToObjectSpace(Vector3.new(0, up, 0)) + Vector3.new(0, 0, -fwd)
		pose.RootJoint = CFrame.new(rj.restC0.Rotation:Inverse() * v) * (pose.RootJoint or CFrame.identity)
	end
	-- claws vs the ground: the right wrist bends so its lowest claw tip rides TheriDragClearance above the ground while running
	-- (drag); otherwise (and the left hand always) a wrist only bends to lift claws that would go under TheriClawFloor
	if not fkOk then return end
	local hrpCF = hrp.CFrame
	local dragOn = rw > 0.05 and s.TheriDragEnabled
	if dragOn then
		local gap, bend = solveWrist(motors, hrpCF, pose, "R", s.TheriDragClearance, false, min(1, rw), model)
		show("TheriDragGap", gap and math.floor(gap * 100 + 0.5) / 100 or -1)
		show("TheriDragBend", math.floor((bend or 0) + 0.5))
	end
	if s.TheriClawFloorEnabled then
		local lift = 0
		for _, side in ipairs(dragOn and {"L"} or {"L", "R"}) do
			local _, b = solveWrist(motors, hrpCF, pose, side, s.TheriClawFloor, true, 1, model)
			if b and math.abs(b) > math.abs(lift) then lift = b end
		end
		show("TheriClawLift", math.floor(lift + 0.5))
	end
end

return TheriPose
