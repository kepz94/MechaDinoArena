-- TrooPose v1.2 (Mecha Dino Arena) — the Troodon's animation layers for IdleAnimation 1.47: the Glow Pod Toss (attack A),
-- the Evade Hop (jump J2) and the eyes flaring during the throw. MDA-337, plan docs/plans/TROODON_KIT_v1.0.md Task 8; mockup
-- docs/mockups/troodon_kit_options_v0.1.html (Kepu 2026-11-06 15:38 "Let's go with your recommendations"; source
-- tools/troodon_kit_mockup/app_tail.js TA_WIND / TA_HOLD / TA_THROW / TA_FOLLOW, TH_SET / TH_AIR / TJ_LAND, and the
-- engine's springs). Pattern copied from DiloPose 1.4 (not edited): key poses, easing, sub-stepped springs, foot FK ground
-- lock, root push.
-- Angles: degrees {p, y, r} on the rig's joint frames (rig 1.3, TroodonModelData 1.1). Joint pose = restC0 * pose; rotation =
--   CFrame.fromEulerAngles(rad(r), rad(y), rad(p), ZYX) (= the mockup's three.js Euler(r, y, p, "ZYX"), DiloPose's mapping).
--   Right joints mirror the left ([p, -y, -r], the mockup's BOTH()).
-- Who: models with Species "Troodon" and TrooPoseEnabled ~= false (TrooPose.on). Every other model: nothing.
-- Throw layer (multiplied on top of the current pose, after the dilo layer; sprung like the mockup): the owner's client starts
--   it on TrooAttackTest 1.0's TrooLocalState "throw" (at TrooLocalAt, the press); other clients on TrooAttackServer 1.0's
--   TrooThrowAt. Track (the mockup's attack A keys, release REL 0.34 = TrooPodWindup): 0 $from, 0.2 TA_WIND (io), 0.27 TA_HOLD
--   (io), 0.34 TA_THROW (in2), 0.52 TA_FOLLOW (out), 1.15 READY (io) = wind-up -> action -> result -> recovery. A wind-up
--   cancel (TrooThrowCancelAt after the start, before the release) plays {0 $from, 0.35 READY (io)} instead. Root push (the
--   mockup's root fwd, studs at scale 2, x scale / 2): TA_WIND / TA_HOLD -0.9, TA_THROW 1.7, TA_FOLLOW 2.0, own spring (w 20,
--   z 0.9). Ground lock (feet FK, DiloPose's) x (1 - walk blend), clamped +-3 x scale / 2.
-- Eyes flare (local, this client): while a throw track runs from 0.05 s to 1.0 s (the mockup's eyes window) the parts
--   Head_eyeL / Head_eyeR turn Neon and brighter (their colour 35 % toward FFD27A, the pod's glow); restored after.
-- Hop layer (replaces the pose by its weight, like DiloPose's leap; sprung), from IdleAnimation's leap tracker while the model's
--   JumpHopBack is true (JumpTest 1.5's Evade Hop; IdleAnimation 1.47 turns the biped JumpPose off for it): crouch (t <
--   JumpHopWindup 0.1): READY -> TH_SET (io), weight io(t / (W / 2)); air (x = t - W): TH_SET -> TH_AIR over 0.12 s (out),
--   then TH_AIR held; land (s since the touchdown): 0 TH_AIR, 0.1 TJ_LAND (out), 0.6 READY (io) (the mockup's J2 keys: T0
--   0.1 TH_SET, +0.12 TH_AIR, held to the touchdown, +0.1 TJ_LAND, +0.6 READY), then the weight fades to 0 by TrooHopLandTime
--   (0.8 s). The keys follow the real hop's timing (about 5.3 studs high, Kepu 2026-11-06). Plain landing (no FX).
-- Test hook: model attribute TrooPoseTestKey = a key name -> that key exactly (no springs / push / lock); unset in play.
-- Switches (model attributes, read each frame): TrooPoseEnabled, TrooHopPoseEnabled, TrooEyeFlareEnabled, TrooGroundLockEnabled
--   (default true each).
-- Diagnostics (model, this client): TrooPoseVersion, TrooPoseState ("throw" / "cancel" / "none" / "test:<key>"),
--   TrooPoseSource ("local" / "server"), TrooHopPhase ("crouch" / "air" / "land" / "none"), TrooEyeFlare (bool),
--   TrooGroundShift (studs, 0.1 steps).
-- v1.1 (Troodon Flap & Glide, MDA-342, plan docs/plans/TROODON_FLAP_GLIDE_v1.0.md Task 3; mockup
--   docs/mockups/troodon_kit_options_v0.2.html J3, keys TF_UP / TF_DOWN / TF_GLIDE / TJ_CROUCH / TJ_DOWN from
--   tools/troodon_kit_mockup/app_tail.js, unchanged numbers): while the model is not in hop mode (JumpHopBack ~= true; TroodonModelData
--   1.3) and TrooPoseFlapEnabled ~= false, TrooPose.hopOn is true too (so IdleAnimation 1.47 turns the biped JumpPose off and
--   calls TrooPose.leap, unchanged) and TrooPose.leap draws the Flap & Glide layer (replaces the pose by its weight, sprung):
--   crouch (t < JumpWindup): READY -> TJ_CROUCH (io); each beat = the leap's launch (start + JumpWindup) and every new
--   JumpDoublePredictedAt (owner) / JumpDoubleAt (others): $from -> TF_DOWN (in2) in 0.05 s (the leap) / 0.06 s (a flap: the
--   mockup's down-stroke 0.06 s after the press), held to +0.13 / +0.14, then -> TF_UP (io) by +0.38 / +0.39 (the recovery,
--   which is also the wind-up of the next beat: a live press cannot be anticipated, so the up-stroke comes before it);
--   glide (GlideLocal on the owner, Gliding for others): $from -> TF_GLIDE (out) over 0.15 s, held; land (the leap tracker's
--   touchdown, or the glide ending): $from -> TJ_DOWN 0.05 (io) -> TJ_LAND 0.12 (out) -> READY 0.7 (io), the weight fading
--   to 0 by TrooHopLandTime (0.8). Foot ground lock in the crouch and the landing. No landing FX. The hop mode (1.0) unchanged.
--   Diagnostics TrooFlapPhase ("crouch" / "beat" / "glide" / "land" / "none"), TrooFlapBeats (beats this leap).
-- v1.2 (MDA-344, P1 bug, Kepu 2026-11-06 18:37: "walking in the air instead of gliding"; a fall without a leap had no air
--   pose, so the walk cycle ran in the air): in flap mode, with TrooPoseFallEnabled ~= false, the layer also covers air time
--   without a leap: gliding (GlideLocal / Gliding; GliderTest 1.2 starts it on a fall) -> TF_GLIDE (the 1.1 glide track);
--   airborne (ground more than 2 studs under the feet by a raycast, falling faster than 1 stud/s, for 0.1 s) and not gliding
--   -> TF_UP (arms raised, legs tucked) in over 0.15 s; touchdown after 0.25 s or more in the air -> the 1.1 land track. A
--   glide that ends while still airborne no longer shows the landing keys mid-air (it falls back to TF_UP). Diagnostic
--   TrooFlapPhase adds "fall".
local TrooPose = {}
TrooPose.Version = "1.2"
TrooPose.Defaults = {TrooPoseEnabled = true, TrooHopPoseEnabled = true, TrooEyeFlareEnabled = true, TrooGroundLockEnabled = true,
	TrooHopLandTime = 0.8, TrooPoseFlapEnabled = true, TrooPoseFallEnabled = true}
local Players = game:GetService("Players")

local JOINTS = {"RootJoint", "Neck", "Head", "Jaw", "ArmL", "ArmR", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "LegL",
	"LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"}
TrooPose.JOINTS = JOINTS

local function BOTH(o, extra)
	local r = {}
	for k, v in pairs(o) do r[k] = v end
	for k, v in pairs(o) do
		if k:sub(-1) == "L" then r[k:sub(1, -2) .. "R"] = {v[1], -v[2], -v[3]} end
	end
	for k, v in pairs(extra or {}) do r[k] = v end
	return r
end
local function plus(a, b)
	local r = {}
	for k, v in pairs(a) do r[k] = v end
	for k, v in pairs(b) do
		local o = r[k] or {0, 0, 0}
		r[k] = {o[1] + v[1], o[2] + v[2], o[3] + v[3]}
	end
	return r
end

-- key poses (app_tail.js, unchanged numbers) -----------------------------------------------------------------------------
local KEYS, FWD = {}, {}
KEYS.READY, KEYS.ZERO = {}, {}
KEYS.TA_WIND = BOTH({RootJoint = {9, 0, 0}, Neck = {18, 0, 0}, Head = {-14, 0, 0}, Jaw = {-6, 0, 0}, ArmL = {-48, 0, 0},
	LegL = {6, 0, 0}, KneeL = {-12, 0, 0}, AnkleL = {4, 0, 0}, Tail1 = {6, 0, 0}, Tail2 = {3, 0, 0}})
FWD.TA_WIND = -0.9
KEYS.TA_HOLD = plus(KEYS.TA_WIND, {ArmL = {-6, 0, 0}, ArmR = {-6, 0, 0}, Neck = {3, 0, 0}})
FWD.TA_HOLD = -0.9
KEYS.TA_THROW = BOTH({RootJoint = {-9, 0, 0}, Neck = {-14, 0, 0}, Head = {10, 0, 0}, Jaw = {-14, 0, 0}, ArmL = {88, 0, 0},
	KneeL = {-6, 0, 0}, Tail1 = {-10, 0, 0}, Tail2 = {-5, 0, 0}}, {LegL = {-6, 0, 0}, LegR = {12, 0, 0}, KneeR = {-16, 0, 0}})
FWD.TA_THROW = 1.7
KEYS.TA_FOLLOW = BOTH({RootJoint = {-7, 0, 0}, Neck = {-10, 0, 0}, Head = {6, 0, 0}, Jaw = {-6, 0, 0}, ArmL = {62, 0, 0},
	KneeL = {-6, 0, 0}, Tail1 = {-8, 0, 0}, Tail2 = {-4, 0, 0}}, {LegL = {-6, 0, 0}, LegR = {12, 0, 0}, KneeR = {-16, 0, 0}})
FWD.TA_FOLLOW = 2.0
KEYS.TH_SET = BOTH({RootJoint = {-4, 0, 0}, Neck = {10, 0, 0}, Head = {-8, 0, 0}, ArmL = {-8, 0, 0}, LegL = {20, 0, 0},
	KneeL = {-40, 0, 0}, AnkleL = {18, 0, 0}, Tail1 = {4, 0, 0}})
KEYS.TH_AIR = BOTH({RootJoint = {6, 0, 0}, Neck = {6, 0, 0}, Head = {-4, 0, 0}, ArmL = {20, 0, 0}, LegL = {-14, 0, 0},
	KneeL = {-36, 0, 0}, AnkleL = {16, 0, 0}, Tail1 = {-10, 0, 0}, Tail2 = {-6, 0, 0}})
KEYS.TJ_LAND = BOTH({RootJoint = {-6, 0, 0}, Neck = {8, 0, 0}, Head = {-6, 0, 0}, ArmL = {6, 0, 0}, LegL = {24, 0, 0},
	KneeL = {-42, 0, 0}, AnkleL = {18, 0, 0}, Tail1 = {6, 0, 0}})
-- v1.1: Flap & Glide (J3) keys and the J2 jump keys they use
KEYS.TF_UP = BOTH({RootJoint = {4, 0, 0}, Neck = {12, 0, 0}, Head = {-10, 0, 0}, ArmL = {-30, -25, -130}, LegL = {34, 0, 0},
	KneeL = {-64, 0, 0}, AnkleL = {30, 0, 0}, Tail1 = {-6, 0, 0}, Tail2 = {-4, 0, 0}})
KEYS.TF_DOWN = BOTH({RootJoint = {-6, 0, 0}, Neck = {18, 0, 0}, Head = {-14, 0, 0}, ArmL = {-10, 15, 25}, LegL = {40, 0, 0},
	KneeL = {-72, 0, 0}, AnkleL = {34, 0, 0}, Tail1 = {-10, 0, 0}, Tail2 = {-6, 0, 0}, Tail3 = {-3, 0, 0}})
KEYS.TF_GLIDE = BOTH({RootJoint = {-2, 0, 0}, Neck = {-4, 0, 0}, Head = {2, 0, 0}, ArmL = {-25, -15, -98}, LegL = {44, 0, 0},
	KneeL = {-78, 0, 0}, AnkleL = {36, 0, 0}, Tail1 = {-6, 0, 0}, Tail2 = {-3, 0, 0}, Tail3 = {-2, 0, 0}})
KEYS.TJ_CROUCH = BOTH({RootJoint = {-8, 0, 0}, Neck = {20, 0, 0}, Head = {-16, 0, 0}, ArmL = {-20, 0, 0}, LegL = {34, 0, 0},
	KneeL = {-58, 0, 0}, AnkleL = {26, 0, 0}, Tail1 = {6, 0, 0}})
KEYS.TJ_DOWN = BOTH({RootJoint = {-6, 0, 0}, Neck = {14, 0, 0}, Head = {-10, 0, 0}, ArmL = {10, 0, 0}, LegL = {22, 0, 0},
	KneeL = {-30, 0, 0}, AnkleL = {12, 0, 0}, Tail1 = {-4, 0, 0}})
TrooPose.KEYS, TrooPose.FWD = KEYS, FWD

local TRACKS = {
	throw = {{0, "$from"}, {0.2, "TA_WIND", "io"}, {0.27, "TA_HOLD", "io"}, {0.34, "TA_THROW", "in2"}, {0.52, "TA_FOLLOW", "out"},
		{1.15, "READY", "io"}},
	cancel = {{0, "$from"}, {0.35, "READY", "io"}},
}
local HOP_LAND = {{0, "TH_AIR"}, {0.1, "TJ_LAND", "out"}, {0.6, "READY", "io"}}
local FLAP = { -- v1.1
	leap = {{0, "$from"}, {0.05, "TF_DOWN", "in2"}, {0.13, "TF_DOWN"}, {0.38, "TF_UP", "io"}},
	flap = {{0, "$from"}, {0.06, "TF_DOWN", "in2"}, {0.14, "TF_DOWN"}, {0.39, "TF_UP", "io"}},
	glide = {{0, "$from"}, {0.15, "TF_GLIDE", "out"}},
	fall = {{0, "$from"}, {0.15, "TF_UP", "io"}}, -- v1.2
	land = {{0, "$from"}, {0.05, "TJ_DOWN", "io"}, {0.12, "TJ_LAND", "out"}, {0.7, "READY", "io"}},
}
local REL, EYES_FROM, EYES_TO = 0.34, 0.05, 1.0
local FLARE_TO = Color3.fromHex("FFD27A")

local rad, min, max, clamp = math.rad, math.min, math.max, math.clamp
local EASE = {
	lin = function(u) return u end,
	io = function(u) return u * u * (3 - 2 * u) end,
	out = function(u) return 1 - (1 - u) ^ 3 end,
	["in"] = function(u) return u * u * u end,
	in2 = function(u) return u * u end,
}
local function rot(v) return CFrame.fromEulerAngles(rad(v[3]), rad(v[2]), rad(v[1]), Enum.RotationOrder.ZYX) end
TrooPose.rot = rot
local function num(v) return typeof(v) == "number" and v or nil end
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
		return n == "$from" and (from or keyPose("ZERO")) or keyPose(n)
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
TrooPose.sample = sample

-- springs (the mockup's SPR; sub-stepped at <= 1/300 s) --------------------------------------------------------------------
local function sprK(n)
	if n:match("^Arm") then return 30, 0.55 end
	if n == "RootJoint" then return 30, 0.85 end
	if n:match("^Leg") or n:match("^Knee") or n:match("^Ankle") then return 36, 0.9 end
	if n == "Neck" then return 26, 0.58 end
	if n == "Head" then return 22, 0.55 end
	if n == "Jaw" then return 34, 0.5 end
	local tn = tonumber(n:match("^Tail(%d)"))
	if tn then return 18 - 2.2 * tn, 0.42 end
	return 24, 0.8
end
local function newSprings()
	local S = {j = {}, fwd = {x = 0, v = 0}, settled = true}
	for _, n in ipairs(JOINTS) do
		local w, z = sprK(n)
		S.j[n] = {x = {0, 0, 0}, v = {0, 0, 0}, w = w, z = z}
	end
	return S
end
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

function TrooPose.settings(model)
	local s = {}
	for k, v in pairs(TrooPose.Defaults) do
		local a = model:GetAttribute(k)
		if typeof(a) ~= typeof(v) then a = v end
		s[k] = a
	end
	return s
end
function TrooPose.on(model)
	return model:GetAttribute("Species") == "Troodon" and model:GetAttribute("TrooPoseEnabled") ~= false
end
function TrooPose.flapOn(model) -- v1.1: Flap & Glide (not the hop)
	return TrooPose.on(model) and model:GetAttribute("TrooPoseFlapEnabled") ~= false and model:GetAttribute("JumpHopBack") ~= true
		and model:GetAttribute("JumpEnabled") == true
end
function TrooPose.hopOn(model) -- v1.1: also true in flap mode (the leap layer is ours either way)
	if TrooPose.flapOn(model) then return true end
	return TrooPose.on(model) and model:GetAttribute("TrooHopPoseEnabled") ~= false and model:GetAttribute("JumpHopBack") == true
end

-- per-model state (each character's IdleAnimation requires its own copy of this module)
local atk = {kind = nil, at = nil, from = nil, target = nil, springs = newSprings(), seen = nil, lastState = nil}
local hopS = {springs = newSprings(), w = 0, lockW = 0, phase = "none", lastAt = -math.huge}
local flS = {springs = newSprings(), start = nil, beats = {}, seenD = nil, glideAt = nil, landAt = nil, phase = "none",
	seg = nil, segAt = 0, from = nil, target = nil, lastAt = -math.huge, -- v1.1
	airSince = nil, airLandAt = nil} -- v1.2
local gapParams = RaycastParams.new() -- v1.2
gapParams.FilterType = Enum.RaycastFilterType.Exclude
local function airborneNow(model, hrp) -- v1.2: ground > 2 studs under the feet and falling
	if not hrp then return false end
	gapParams.FilterDescendantsInstances = {model}
	local hum = model:FindFirstChildOfClass("Humanoid")
	local base = hrp.Size.Y / 2 + (hum and hum.HipHeight or 0)
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -(base + 40), 0), gapParams)
	local gap = hit and (hrp.Position.Y - hit.Position.Y - base) or math.huge
	return gap > 2 and hrp.AssemblyLinearVelocity.Y < -1, gap
end
local lockSmooth = 0
local fk
local eyes = {on = false, parts = nil}

-- foot FK (DiloPose's) ---------------------------------------------------------------------------------------------------
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
	local parts = {}
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 and p ~= root then
			table.insert(parts, {off = root.CFrame:Inverse() * p.CFrame, half = p.Size / 2})
		end
	end
	return {joints = joints, parts = parts}
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
	for _, sn in ipairs({"FootL", "FootR"}) do
		fk[sn] = buildChain(model, motors, hrp, sn)
		if not fk[sn] then return false end
	end
	fk.ok = #fk.FootL.parts > 0 and #fk.FootR.parts > 0
	return fk.ok
end

-- hop layer ----------------------------------------------------------------------------------------------------------------
-- jump = IdleAnimation's leap tracker {start, air, landAt (os.clock), done}; returns {joint = CFrame}, weight
-- v1.1: Flap & Glide layer
local function flapLeap(model, jump, serverNow, now, hrp, dt, s)
	local W = num(model:GetAttribute("JumpWindup")) or 0.12
	local lp = Players.LocalPlayer
	local isOwner = lp ~= nil and lp.Character == model
	local dAt = num(model:GetAttribute(isOwner and "JumpDoublePredictedAt" or "JumpDoubleAt"))
	if isOwner then
		local srv = num(model:GetAttribute("JumpDoubleAt"))
		if srv and (not dAt or srv > dAt + 0.3) then dAt = srv end
	end
	local gliding = model:GetAttribute(isOwner and "GlideLocal" or "Gliding") == true
	if jump and jump.start ~= flS.start and jump.start > (flS.start or -math.huge) then -- a new leap
		flS.start, flS.beats, flS.glideAt, flS.landAt, flS.noLeap = jump.start, {jump.start + W}, nil, nil, false
		flS.seenD = dAt
	end
	-- v1.2: air time without a leap
	local fallOn = model:GetAttribute("TrooPoseFallEnabled") ~= false
	local airRaw = fallOn and airborneNow(model, hrp) or false
	if airRaw then flS.airSince = flS.airSince or now
	else
		if flS.airSince and now - flS.airSince >= 0.25 then flS.airLandAt = now end
		flS.airSince = nil
	end
	local air = flS.airSince ~= nil and now - flS.airSince >= 0.1
	if not flS.start then flS.start, flS.beats, flS.noLeap = -math.huge, {}, true end
	if dAt and dAt ~= flS.seenD then
		flS.seenD = dAt
		if dAt > flS.start and not flS.landAt then table.insert(flS.beats, dAt) end
	end
	if gliding and not flS.glideAt and not flS.landAt then flS.glideAt = now end
	if not flS.landAt then
		if jump and jump.start == flS.start and jump.landAt then flS.landAt = jump.landAt
		elseif flS.glideAt and not gliding and not (fallOn and air) then flS.landAt = now end -- v1.2: not mid-air
	end
	local t = serverNow - flS.start
	local phase, seg, segT, w, lock = "none", nil, 0, 0, 0
	if flS.landAt then
		local x = now - flS.landAt
		if x < s.TrooHopLandTime then
			phase, seg, segT = "land", "land", x
			w = x < 0.7 and 1 or 1 - EASE.io(clamp((x - 0.7) / max(0.01, s.TrooHopLandTime - 0.7), 0, 1))
			lock = w
		end
	elseif flS.glideAt and gliding then
		phase, seg, segT, w = "glide", "glide", now - flS.glideAt, 1
	elseif not flS.noLeap and t >= 0 and t < W and not (jump and jump.air) then
		phase, w, lock = "crouch", EASE.io(clamp(t / max(0.01, W / 2), 0, 1)), 1
	elseif not flS.noLeap and not flS.glideAt and t >= W and t < 4 and (jump and not jump.done or jump and jump.air) then
		local b = flS.beats[#flS.beats]
		phase, seg, segT, w = "beat", (#flS.beats == 1) and "leap" or "flap", serverNow - b, 1
	end
	if phase == "none" and fallOn then -- v1.2: no leap layer: glide / fall / landing after air time
		if gliding then
			flS.fallGlideAt = flS.fallGlideAt or now
			phase, seg, segT, w = "glide", "glide", now - flS.fallGlideAt, 1
		else
			flS.fallGlideAt = nil
			if air then
				phase, seg, segT = "fall", "fall", now - flS.airSince - 0.1
				w = EASE.io(clamp(segT / 0.15, 0, 1))
			elseif flS.airLandAt and now - flS.airLandAt < s.TrooHopLandTime then
				local x = now - flS.airLandAt
				phase, seg, segT = "land", "land", x
				w = x < 0.7 and 1 or 1 - EASE.io(clamp((x - 0.7) / max(0.01, s.TrooHopLandTime - 0.7), 0, 1))
				lock = w
			end
		end
	end
	flS.phase = phase
	if model:GetAttribute("TrooFlapPhase") ~= phase then model:SetAttribute("TrooFlapPhase", phase) end
	if model:GetAttribute("TrooFlapBeats") ~= #flS.beats then model:SetAttribute("TrooFlapBeats", #flS.beats) end
	if phase == "none" then
		flS.seg, flS.target = nil, nil
		hopS.w, hopS.lockW = 0, 0
		return nil, 0
	end
	local tg
	if phase == "crouch" then
		tg = mixP(keyPose("READY"), keyPose("TJ_CROUCH"), EASE.io(clamp(t / W, 0, 1)))
	else
		local segKey = seg .. ":" .. tostring(seg == "flap" and flS.beats[#flS.beats] or seg)
		if segKey ~= flS.seg then flS.seg, flS.from = segKey, flS.target or keyPose("ZERO") end
		tg = sample(FLAP[seg], max(0, segT), flS.from)
	end
	flS.target = tg
	local init = now - flS.lastAt > 0.25
	flS.lastAt = now
	local out = springStep(flS.springs, tg, dt, init)
	hopS.w, hopS.lockW = w, lock * w
	local cfs = {}
	for n, v in pairs(out.a) do cfs[n] = rot(v) end
	return cfs, w
end

function TrooPose.leap(model, jump, serverNow, now, hrp, dt)
	local s = TrooPose.settings(model)
	if TrooPose.flapOn(model) then return flapLeap(model, jump, serverNow, now, hrp, dt, s) end -- v1.1
	local W = num(model:GetAttribute("JumpHopWindup")) or 0.1
	local phase, x, tg, w, lock = "none", 0, nil, 0, 0
	local t = jump and serverNow - jump.start or 0
	if jump and jump.landAt and now - jump.landAt < s.TrooHopLandTime then
		phase, x = "land", now - jump.landAt
	elseif jump and not jump.done and not jump.landAt then
		if jump.air then phase, x = "air", max(0, t - W)
		elseif t >= 0 and t < W then phase, x = "crouch", t
		elseif t >= W then phase, x = "air", t - W end
	end
	if phase == "crouch" then
		tg = mixP(keyPose("READY"), keyPose("TH_SET"), EASE.io(clamp(x / W, 0, 1)))
		w, lock = EASE.io(clamp(x / max(0.01, W / 2), 0, 1)), 1
	elseif phase == "air" then
		tg = mixP(keyPose("TH_SET"), keyPose("TH_AIR"), EASE.out(clamp(x / 0.12, 0, 1)))
		w, lock = 1, 0
	elseif phase == "land" then
		tg = sample(HOP_LAND, x, nil)
		w = x < 0.6 and 1 or 1 - EASE.io(clamp((x - 0.6) / max(0.01, s.TrooHopLandTime - 0.6), 0, 1))
		lock = w
	end
	hopS.phase = phase
	if not tg then
		hopS.w, hopS.lockW = 0, 0
		return nil, 0
	end
	local init = now - hopS.lastAt > 0.25
	hopS.lastAt = now
	local out = springStep(hopS.springs, tg, dt, init)
	hopS.w, hopS.lockW = w, lock * w
	local cfs = {}
	for n, v in pairs(out.a) do cfs[n] = rot(v) end
	return cfs, w
end

-- eyes flare (local) -------------------------------------------------------------------------------------------------------
local function eyeParts(model)
	if eyes.parts and eyes.parts[1] and eyes.parts[1].p.Parent then return eyes.parts end
	eyes.parts = {}
	for _, n in ipairs({"Head_eyeL", "Head_eyeR"}) do
		local p = model:FindFirstChild(n, true)
		if p and p:IsA("BasePart") then table.insert(eyes.parts, {p = p, mat = p.Material, col = p.Color}) end
	end
	return eyes.parts
end
local function setEyes(model, on)
	if on == eyes.on then return end
	eyes.on = on
	for _, e in ipairs(eyeParts(model)) do
		if on then
			e.mat, e.col = e.p.Material, e.p.Color
			e.p.Material = Enum.Material.Neon
			e.p.Color = e.col:Lerp(FLARE_TO, 0.35)
		else
			e.p.Material, e.p.Color = e.mat, e.col
		end
	end
end

-- throw layer + root push / ground lock + eyes ----------------------------------------------------------------------------------
function TrooPose.top(model, pose, motors, hrp, ctx)
	local s = TrooPose.settings(model)
	local show = ctx.show
	show("TrooPoseVersion", TrooPose.Version)
	local testKey = model:GetAttribute("TrooPoseTestKey")
	if typeof(testKey) == "string" and KEYS[testKey] then
		for _, n in ipairs(JOINTS) do
			if motors[n] then pose[n] = KEYS[testKey][n] and rot(KEYS[testKey][n]) or CFrame.identity end
		end
		show("TrooPoseState", "test:" .. testKey)
		return
	end
	local st, stAt, src, throwAt
	if ctx.isOwner then
		st, stAt, src = model:GetAttribute("TrooLocalState"), num(model:GetAttribute("TrooLocalAt")), "local"
	else
		throwAt, src = num(model:GetAttribute("TrooThrowAt")), "server"
	end
	local cancelAt = num(model:GetAttribute("TrooThrowCancelAt"))
	local function start(kind, at)
		atk.from = atk.target or keyPose("ZERO")
		atk.kind, atk.at = kind, at
	end
	if atk.seen == nil then
		atk.seen = {throw = throwAt, local_ = stAt, cancel = cancelAt}
	else
		if ctx.isOwner then
			if st == "throw" and stAt and stAt ~= atk.seen.local_ then start("throw", stAt) end
			atk.seen.local_ = stAt
		elseif throwAt and throwAt ~= atk.seen.throw then
			start("throw", throwAt)
		end
		atk.seen.throw = throwAt
		if cancelAt and cancelAt ~= atk.seen.cancel and atk.kind == "throw" and cancelAt >= atk.at - 0.05 and cancelAt < atk.at + REL + 0.3 then
			start("cancel", ctx.serverNow)
		end
		atk.seen.cancel = cancelAt
	end
	local tg
	local t = atk.at and max(0, ctx.serverNow - atk.at) or 0
	if atk.kind then
		local keys = TRACKS[atk.kind]
		if t > keys[#keys][1] then
			atk.kind, atk.at = nil, nil
		else
			tg = sample(keys, t, atk.from)
		end
	end
	atk.target = tg
	local aOut
	if tg or not atk.springs.settled then
		aOut = springStep(atk.springs, tg or keyPose("ZERO"), ctx.dt, false)
	end
	show("TrooPoseState", atk.kind or "none")
	show("TrooPoseSource", src)
	show("TrooHopPhase", hopS.phase)
	if aOut then
		for n, v in pairs(aOut.a) do
			if motors[n] then pose[n] = (pose[n] or CFrame.identity) * rot(v) end
		end
	end
	-- eyes flare
	local flare = s.TrooEyeFlareEnabled and atk.kind == "throw" and t >= EYES_FROM and t < EYES_TO
	setEyes(model, flare)
	show("TrooEyeFlare", flare)
	-- root push + ground lock (DiloPose's)
	local rj = motors.RootJoint
	if not (rj and hrp) then return end
	local sc = model:IsA("Model") and model:GetScale() or 2
	local fwd = (aOut and aOut.fwd or 0) * sc / 2
	local aw = (atk.kind ~= nil or not atk.springs.settled) and 1 - clamp(ctx.moveW or 0, 0, 1) or 0
	local lockT = s.TrooGroundLockEnabled and max(aw, hopS.lockW) or 0
	lockSmooth += (lockT - lockSmooth) * min(1, ctx.dt * 20)
	if lockSmooth < 0.001 then lockSmooth = 0 end
	local up = 0
	if lockSmooth > 0 and ensureFK(model, motors, hrp) then
		local hrpCF = hrp.CFrame
		local d = footLow(motors, hrpCF, {}) - footLow(motors, hrpCF, pose)
		up = clamp(d, -3 * sc / 2, 3 * sc / 2) * lockSmooth
	end
	show("TrooGroundShift", math.floor(up * 10 + 0.5) / 10)
	if fwd ~= 0 or up ~= 0 then
		local v = hrp.CFrame:VectorToObjectSpace(Vector3.new(0, up, 0)) + Vector3.new(0, 0, -fwd)
		pose.RootJoint = CFrame.new(rj.restC0.Rotation:Inverse() * v) * (pose.RootJoint or CFrame.identity)
	end
end

return TrooPose
