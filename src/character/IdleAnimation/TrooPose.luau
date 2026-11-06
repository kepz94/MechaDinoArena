-- TrooPose v1.0 (Mecha Dino Arena) — the Troodon's animation layers for IdleAnimation 1.47: the Glow Pod Toss (attack A),
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
local TrooPose = {}
TrooPose.Version = "1.0"
TrooPose.Defaults = {TrooPoseEnabled = true, TrooHopPoseEnabled = true, TrooEyeFlareEnabled = true, TrooGroundLockEnabled = true,
	TrooHopLandTime = 0.8}

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
TrooPose.KEYS, TrooPose.FWD = KEYS, FWD

local TRACKS = {
	throw = {{0, "$from"}, {0.2, "TA_WIND", "io"}, {0.27, "TA_HOLD", "io"}, {0.34, "TA_THROW", "in2"}, {0.52, "TA_FOLLOW", "out"},
		{1.15, "READY", "io"}},
	cancel = {{0, "$from"}, {0.35, "READY", "io"}},
}
local HOP_LAND = {{0, "TH_AIR"}, {0.1, "TJ_LAND", "out"}, {0.6, "READY", "io"}}
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
function TrooPose.hopOn(model)
	return TrooPose.on(model) and model:GetAttribute("TrooHopPoseEnabled") ~= false and model:GetAttribute("JumpHopBack") == true
end

-- per-model state (each character's IdleAnimation requires its own copy of this module)
local atk = {kind = nil, at = nil, from = nil, target = nil, springs = newSprings(), seen = nil, lastState = nil}
local hopS = {springs = newSprings(), w = 0, lockW = 0, phase = "none", lastAt = -math.huge}
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
function TrooPose.leap(model, jump, serverNow, now, hrp, dt)
	local s = TrooPose.settings(model)
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
