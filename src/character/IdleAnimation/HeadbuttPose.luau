-- HeadbuttPose v1.1 (Mecha Dino Arena) — the pachy's headbutt charge pose (HeadbuttTest 1.0 / HeadbuttServer 1.0), as
-- per-joint offsets multiplied onto the current pose (IdleAnimation 1.29). MDA-119, plan docs/plans/PACHY_PLAYABLE_v1.0.md
-- Task 8 (Kepu 2026-10-30: "animations that indicate a speed up and the charge. the pachy should dip its head forward
-- with intent like the inspo pick that i sent where its charging"; inspo docs/reference/pachy/).
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front), about Y = yaw,
-- about X = roll; tail positive pitch = lower (PouncePose convention).
-- Phases (attributes below):
--   windup  0 .. HeadbuttWindup  quick rear-up of the head (first 40%), then it drops: the "about to charge" tell
--   charge  until the end        body low in front, neck down and forward, head tucked so the dome leads, arms tucked,
--                                tail straight out behind (counters the tail sag), a fast small head bob (the speed-up)
--   impact  hit .. +IMPACT       the dome snaps up and back from the hit and shakes, then eases out
--   fade    end .. +FADE         eases out after a charge that missed
-- phase(model, isOwner, serverNow): owner client = HeadbuttLocalState / HeadbuttPredictedAt / HeadbuttLocalEndAt
--   (HeadbuttTest 1.0); other clients = server stamps HeadbuttStartedAt, HeadbuttHitAt, HeadbuttEndedAt.
--   Returns phase ("windup" / "charge" / "impact" / "fade" / nil), u (0..1 inside the phase), source ("local" / "server").
-- v1.1 (MDA-304, plan docs/plans/PACHY_MOVES_ANIM_v1.0.md Task 2; Kepu 2026-11-05 23:34 "A for everything": Headbutt
--   "A · Bull Charge", Blood Rush "A · Blood Pact"; mockup docs/mockups/pachy_moves_anim.html v0.1 keys PAW / BULL_LOW /
--   CRUNCH / RECOIL_UP / PACT). Model switches (default true, read every frame):
--   BullChargeEnabled: wind-up = READY -> PAW (snort + back-foot scrape, at 0.10 s) -> BULL_LOW (0.15 s); charge = BULL_LOW
--     + the bob; impact lasts IMPACT_BULL 1.0 s: CRUNCH (0.04 s) -> RECOIL_UP (0.16 s) -> NEUT (0.5 s) -> rest (1.0 s), with
--     a head shake-off between 0.5 and 0.95 s (yaw 14 deg decaying); a miss fades from BULL_LOW in FADE. Timing unchanged.
--   BloodPactEnabled: when HeadbuttSacrificeAt is within 0.2 s before the start (Blood Rush), the wind-up is READY -> PACT
--     (a jolt + roar, 0.07 s) -> BULL_LOW instead of PAW.
--   The owner's impact is held for IMPACT_BULL from its recover stamp (HeadbuttTest RECOVER is 0.3 s).
--   get(phase, u, k, now, model) — model is new (nil = 1.0 pose).

local HeadbuttPose = {}

HeadbuttPose.Version = "1.0"
HeadbuttPose.Version = "1.1" -- v1.1 Bull Charge + Blood Pact
HeadbuttPose.Defaults = {
	HeadbuttEnabled = false, -- PachyModelData 1.1 sets true
	HeadbuttWindup  = 0.15,
	HeadbuttMaxTime = 1.8,
	HeadbuttPoseEnabled = true, -- switch: false = no headbutt pose (IdleAnimation 1.28 look)
}
HeadbuttPose.IMPACT = 0.3 -- = HeadbuttTest 1.0 RECOVER, so the owner's impact ends with its recover state
HeadbuttPose.FADE = 0.25
HeadbuttPose.IMPACT_BULL = 1.0 -- v1.1
local function bullOn(model) return model ~= nil and model:GetAttribute("BullChargeEnabled") ~= false end
local ownerHit = setmetatable({}, {__mode = "k"}) -- v1.1: [model] = the owner's last recover (hit) stamp

local rad, sin, pi = math.rad, math.sin, math.pi
local function smoothstep(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

function HeadbuttPose.settings(model)
	local s = {}
	for k, v in pairs(HeadbuttPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

function HeadbuttPose.phase(model, isOwner, serverNow)
	local s = HeadbuttPose.settings(model)
	if s.HeadbuttEnabled ~= true or s.HeadbuttPoseEnabled == false then return nil, 0, "none" end
	local W = math.max(0.01, tonumber(s.HeadbuttWindup) or 0.15)
	if isOwner then
		local st = model:GetAttribute("HeadbuttLocalState")
		local pStart = model:GetAttribute("HeadbuttPredictedAt")
		local endAt = model:GetAttribute("HeadbuttLocalEndAt")
		if st == "windup" and typeof(pStart) == "number" then
			return "windup", math.clamp((serverNow - pStart) / W, 0, 1), "local"
		elseif st == "charge" then
			return "charge", 0, "local"
		elseif st == "recover" and typeof(endAt) == "number" then
			if bullOn(model) then
				ownerHit[model] = endAt
				return "impact", math.clamp((serverNow - endAt) / HeadbuttPose.IMPACT_BULL, 0, 1), "local"
			end
			return "impact", math.clamp((serverNow - endAt) / HeadbuttPose.IMPACT, 0, 1), "local"
		elseif bullOn(model) and ownerHit[model] and typeof(endAt) == "number" and ownerHit[model] == endAt
			and serverNow - endAt < HeadbuttPose.IMPACT_BULL then -- v1.1: the long impact after the recover state
			return "impact", math.clamp((serverNow - endAt) / HeadbuttPose.IMPACT_BULL, 0, 1), "local"
		elseif typeof(endAt) == "number" and typeof(pStart) == "number" and endAt >= pStart
			and serverNow - endAt < HeadbuttPose.FADE then
			return "fade", (serverNow - endAt) / HeadbuttPose.FADE, "local"
		end
		return nil, 0, "local"
	end
	local start = model:GetAttribute("HeadbuttStartedAt")
	if typeof(start) ~= "number" then return nil, 0, "server" end
	local hitAt = model:GetAttribute("HeadbuttHitAt")
	local endAt = model:GetAttribute("HeadbuttEndedAt")
	if typeof(hitAt) == "number" and hitAt >= start - 0.001 then
		local IMP = bullOn(model) and HeadbuttPose.IMPACT_BULL or HeadbuttPose.IMPACT -- v1.1
		if serverNow - hitAt < IMP then
			return "impact", math.clamp((serverNow - hitAt) / IMP, 0, 1), "server"
		end
		return nil, 0, "server"
	end
	if typeof(endAt) == "number" and endAt >= start - 0.001 then
		if serverNow - endAt < HeadbuttPose.FADE then return "fade", (serverNow - endAt) / HeadbuttPose.FADE, "server" end
		return nil, 0, "server"
	end
	local t = serverNow - start
	if t >= 0 and t < W then return "windup", t / W, "server" end
	if t >= W and t < W + (tonumber(s.HeadbuttMaxTime) or 1.8) + 1 then return "charge", 0, "server" end
	return nil, 0, "server"
end

-- v1.1: key poses {pitch, yaw, roll} in degrees (pitch about Z, + lifts the front / swings a limb forward; tail + = lower;
-- jaw - = open; knee - = bend); right-side joints mirror the left (yaw / roll negated)
local function BOTH(t) local o = {} for n, v in pairs(t) do o[n] = v; if n:sub(-1) == "L" then o[n:sub(1, -2) .. "R"] = {v[1], -v[2], -v[3]} end end return o end
local function over(a, b) local o = {} for n, v in pairs(a) do o[n] = v end for n, v in pairs(b) do o[n] = v end return o end
local K = {}
K.PAW = over(BOTH({RootJoint = {-10, 0, 0}, Neck = {-22, 0, 0}, Head = {-34, 0, 0}, ArmL = {-34, 0, 0}, Tail1 = {-8, 0, 0}, Tail2 = {-4, 0, 0}}),
	{LegL = {20, 0, 0}, KneeL = {-34, 0, 0}, AnkleL = {12, 0, 0}, LegR = {-30, 0, 0}, KneeR = {-8, 0, 0}, AnkleR = {-22, 0, 0}})
K.BULL_LOW = BOTH({RootJoint = {-13, 0, 0}, Neck = {-30, 0, 0}, Head = {-44, 0, 0}, ArmL = {-42, 0, 0}, Tail1 = {-2, 0, 0}, Tail2 = {-2, 0, 0}})
K.CRUNCH = BOTH({RootJoint = {-15, 0, 0}, Neck = {-36, 0, 0}, Head = {-48, 0, 0}, ArmL = {-40, 0, 0}})
K.RECOIL_UP = over(BOTH({RootJoint = {9, 0, 0}, Neck = {26, 0, 0}, Head = {24, 0, 0}, Jaw = {-10, 0, 0}, ArmL = {12, 0, 0}, Tail1 = {8, 0, 0}}),
	{LegL = {16, 0, 0}, KneeL = {-20, 0, 0}, LegR = {-6, 0, 0}})
K.NEUT = {Neck = {6, 0, 0}}
K.PACT = BOTH({RootJoint = {10, 0, 0}, Neck = {32, 0, 0}, Head = {24, 0, 0}, Jaw = {-42, 0, 0}, ArmL = {30, 0, -16}, Tail1 = {10, 0, 0}})
K.ZERO = {}
HeadbuttPose.KEYS = K
local EASE = {
	io = smoothstep, out = function(x) x = math.clamp(x, 0, 1); return 1 - (1 - x) ^ 3 end,
	out5 = function(x) x = math.clamp(x, 0, 1); return 1 - (1 - x) ^ 5 end, in2 = function(x) x = math.clamp(x, 0, 1); return x * x end,
}
local NAMES = {"RootJoint", "Neck", "Head", "Jaw", "ArmL", "ArmR", "Tail1", "Tail2", "LegL", "LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"}
-- keys: {{t, keyName, ease}, ...}; returns {name = {p, y, r}}
local function sample(keys, t)
	local a, b = keys[1], keys[#keys]
	if t <= a[1] then b = a else
		for i = 2, #keys do if t <= keys[i][1] then a, b = keys[i - 1], keys[i]; break end end
	end
	local u = (a == b) and 1 or EASE[b[3] or "io"]((t - a[1]) / math.max(1e-4, b[1] - a[1]))
	if t >= keys[#keys][1] then a, b, u = keys[#keys], keys[#keys], 1 end
	local A, B, o = K[a[2]], K[b[2]], {}
	for _, n in ipairs(NAMES) do
		local va, vb = A[n] or {0, 0, 0}, B[n] or {0, 0, 0}
		o[n] = {va[1] + (vb[1] - va[1]) * u, va[2] + (vb[2] - va[2]) * u, va[3] + (vb[3] - va[3]) * u}
	end
	return o
end
local W_BULL = {{0, "ZERO"}, {0.10 / 0.15, "PAW", "io"}, {1, "BULL_LOW", "io"}} -- u of the wind-up
local W_PACT = {{0, "ZERO"}, {0.07 / 0.15, "PACT", "out5"}, {1, "BULL_LOW", "in2"}}
local IMP_BULL = {{0, "BULL_LOW"}, {0.04, "CRUNCH", "in2"}, {0.16, "RECOIL_UP", "out"}, {0.5, "NEUT", "io"}, {1.0, "ZERO", "io"}} -- seconds
local function sacrifice(model, serverNow)
	if model:GetAttribute("BloodPactEnabled") == false then return false end
	local sac = model:GetAttribute("HeadbuttSacrificeAt")
	local start = model:GetAttribute("HeadbuttStartedAt")
	local pred = model:GetAttribute("HeadbuttPredictedAt")
	local s0 = math.max(typeof(start) == "number" and start or -1e9, typeof(pred) == "number" and pred or -1e9)
	return typeof(sac) == "number" and sac >= s0 - 0.2 and serverNow - sac < 0.6
end
local function bullGet(model, phase, u, k, now)
	local W = math.max(0.01, tonumber(model:GetAttribute("HeadbuttWindup")) or 0.15)
	local p
	if phase == "windup" then
		p = sample(sacrifice(model, workspace:GetServerTimeNow()) and W_PACT or W_BULL, u)
	elseif phase == "charge" then
		p = sample({{0, "BULL_LOW"}}, 0)
		p.Neck[1] += 2.5 * sin(now * 2 * pi * 4.5)
	elseif phase == "impact" then
		local t = u * HeadbuttPose.IMPACT_BULL
		p = sample(IMP_BULL, t)
		if t > 0.5 and t < 0.95 then
			local d = 1 - (t - 0.5) / 0.45
			p.Neck[2] += 14 * sin((t - 0.5) * 34) * d
			p.Head[2] += 10 * sin((t - 0.5) * 34 + 0.6) * d
			p.Head[3] += 6 * sin((t - 0.5) * 34) * d
		end
	elseif phase == "fade" then
		local f = 1 - smoothstep(u)
		p = sample({{0, "BULL_LOW"}}, 0)
		for _, n in ipairs(NAMES) do local v = p[n]; p[n] = {v[1] * f, v[2] * f, v[3] * f} end
	else
		return {}
	end
	local out = {}
	for n, v in pairs(p) do
		if v[1] ~= 0 or v[2] ~= 0 or v[3] ~= 0 then out[n] = CFrame.Angles(rad(v[3] * k), rad(v[2] * k), rad(v[1] * k)) end
	end
	out.Jaw = out.Jaw or CFrame.Angles(0, 0, 0)
	return out
end
HeadbuttPose.bullGet = bullGet
HeadbuttPose.bullOn = bullOn

-- phase / u from HeadbuttPose.phase; k: overall weight 0..1; now: clock seconds
function HeadbuttPose.get(phase, u, k, now, model)
	if bullOn(model) then return bullGet(model, phase, u, k, now) end -- v1.1
	local out = {}
	local rear = (phase == "windup" and u < 0.4) and sin(pi * u / 0.4) or 0
	local w = phase == "windup" and smoothstep((u - 0.3) / 0.7) or 0
	local c = phase == "charge" and 1 or 0
	local hit = phase == "impact" and (1 - smoothstep(u)) or 0
	local fade = phase == "fade" and (1 - smoothstep(u)) or 0
	local low = math.max(w, c, fade, hit * 0.5)
	local bob = c * sin(now * 2 * pi * 4.5)
	local shake = rad(9 * hit * sin(now * 2 * pi * 10))
	out.RootJoint = CFrame.Angles(0, 0, rad((-8 * low + 5 * rear + 3 * hit) * k))
	out.Neck = CFrame.Angles(0, shake * 0.5, rad((-26 * low + 12 * rear + 22 * hit + 2.5 * bob) * k))
	out.Head = CFrame.Angles(shake * 0.4, shake, rad((-38 * low + 8 * rear + 20 * hit) * k))
	out.Jaw = CFrame.Angles(0, 0, 0)
	out.ArmL = CFrame.Angles(0, 0, rad(-35 * low * k))
	out.ArmR = CFrame.Angles(0, 0, rad(-35 * low * k))
	-- tail straight out behind: the body's -8 pitch already raises it, so Tail1 lowers it back near level (Studio
	-- capture: -10 / -6 / -4 / -3 lifted it about 30 degrees)
	out.Tail1 = CFrame.Angles(0, 0, rad(6 * low * k))
	return out
end

return HeadbuttPose
