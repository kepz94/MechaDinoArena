-- TenoPose v1.2 (Mecha Dino Arena) — the Tenontosaurus' poses: rearing leap (J2), claw scratch, tail-slam wind-up (hold)
-- and rear tail slam, for IdleAnimation 1.37. MDA-172, plan docs/plans/TENO_KIT_v1.0.md Tasks 4 + 7, mockup
-- docs/mockups/teno_attacks_options.html v0.2 (Kepu 2026-10-31: slam D "a rear slam it lifts and slams its tail in that
-- back", jump "I want the second leap"). Every angle below is the mockup's (degrees {pitch, yaw, roll}).
-- Joint frames: rig 1.3 joint pose = restC0 * pose; pitch = about Z (+ lifts the front / swings a limb forward; Tail +
--   lowers it), yaw = about Y, roll = about X; rotation = CFrame.fromEulerAngles(roll, yaw, pitch, ZYX) (SlashPose 1.0).
-- Leap (replaces the pose by the leap weight, like JumpPose): leap(phase, x, s) -> {joint = CFrame}, weight
--   "crouch" x = 0..1 of JumpWindup: 0 -> J_REAR (ease)                                   weight 1
--   "air"    x = seconds since launch: J_REAR -> J_AIR over TenoLeapAirBlend (ease)        weight 1
--   "land"   x = 0..1 of TenoLeapLandTime: J_AIR -> J_LAND over the first 0.3, then J_LAND  weight 1, then
--            1 - ease((x - 0.3) / 0.7) (fades back into the walk / idle pose)
--   Every leap table names all 17 joints (unnamed = 0), so the leap fully owns the body at weight 1.
-- Attacks (multiplied onto the current pose, like SlashPose): phase(model, isOwner, serverNow) -> phase, t, hold, source
--   owner client: TenoLocalState ("hold" / "scratch" / "slam" / "none"), TenoLocalAt (server time the state began),
--     TenoLocalHold (hold seconds at the release) — written by TenoAttackTest.
--   other clients: the latest of TenoHoldSince (> 0 = holding), TenoScratchAt, TenoSlamAt (+ TenoSlamHold) — written by
--     TenoAttackServer.
--   "hold"    t = held seconds: weight hw = 0 below TenoSlamHoldMin, then ease(t / TenoHoldRise) (the mockup's 0.55 s); D_UP x hw,
--             plus a tail-tip quiver (Tail5 pitch + sin(40 x now) x min(t, 1) x 1.5).
--   "scratch" T1 0.12 s 0 -> SCRATCH_UP (ease), T2 0.10 s -> SCRATCH_DOWN (easeIn), T3 0.25 s -> 0 (ease); ends after.
--   "slam"    TenoSlamDropTime (0.13) s D_UP x hw(hold at the release) -> D_DOWN (easeIn), TenoSlamRecover (0.7) s -> 0
--             (ease); ends after.
--   attack(phase, t, hold, s, now) -> {joint = CFrame}.
-- Switch: model attribute TenoPoseEnabled (default true; false = no teno leap or attack poses, the biped jump pose plays).
-- v1.1 (Kepu 2026-10-31: "make the teno's jump animation more smooth. It looks so rough rn"): smoother leap (the same J_REAR /
--   J_AIR / J_LAND poses), while the model attribute TenoLeapSmoothEnabled is not false (default true; false = 1.0):
--   * crouch: the full J_REAR pose with weight smoothstep(x), so the body eases out of the walk / idle pose into the rear-up
--     (1.0 jumped to the rest pose at weight 1 on the first frame); IdleAnimation 1.38 uses this weight.
--   * air: J_REAR -> J_AIR by smoothstep over TenoLeapAirBlend2 (0.4 s; 1.0: ease-out over 0.34 s, a hard first frame),
--     then from TenoLeapReachStart (0.25 s) over TenoLeapReachTime (0.35 s) a TenoLeapReach (0.45) share of J_LAND (legs
--     reach for the ground before the touchdown).
--   * land: from the pose held at the touchdown to J_LAND by smoothstep over the first TenoLeapLandIn (0.35) of the landing,
--     then the weight fades 1 -> 0 by smoothstep; the landing lasts TenoLeapLandTime2 (0.55 s; 1.0: 0.4 s, a linear 0.12 s snap
--     into J_LAND and an ease-out fade).
--   * every leap frame is low-pass filtered (angles follow the target at TenoLeapFilterRate 16 per second; reset when a new
--     leap starts after 0.25 s without leap frames). The filter state lives in this module, which each character's
--     IdleAnimation requires from its own copy, so it belongs to one model.
-- v1.2 (plan docs/plans/TENO_SLAM_REWORK_v1.0.md, Kepu 2026-11-01 "like how the t-Rex bite soft aim works"): the slam
--   bends the tail toward the aimed yaw: Tail1..Tail5 yaw = -aimYaw x TenoSlamYawShare (0.3 / 0.25 / 0.2 / 0.15 / 0.1;
--   joint yaw + = the tail to the right, aimYaw + = left). aimYaw = the owner's TenoLocalSlamYaw (TenoAttackTest 1.2,
--   at once) or else the character's TenoSlamAimYaw (TenoAttackServer 1.2), read by phase() for each slam. Switch: model
--   attribute TenoSlamYawEnabled (default true; false = 1.1, no turn).
local TenoPose = {}
TenoPose.Version = "1.2"
TenoPose.Defaults = {
	TenoPoseEnabled = true,
	TenoLeapAirBlend = 0.34,   -- s from launch to the full air pose (mockup TA 0.62 / 1.8)
	TenoLeapLandTime = 0.4,    -- s of the landing (mockup TL)
	TenoScratchUp = 0.12, TenoScratchDown = 0.10, TenoScratchRecover = 0.25,
	TenoSlamHoldMin = 0.22, TenoSlamDropTime = 0.13, TenoSlamRecover = 0.7,
	TenoHoldRise = 0.55,       -- s from the press to the full wind-up (mockup hold / 0.55)
	-- v1.1: smooth leap
	TenoLeapSmoothEnabled = true, TenoLeapAirBlend2 = 0.4, TenoLeapReachStart = 0.25, TenoLeapReachTime = 0.35,
	TenoLeapReach = 0.45, TenoLeapLandIn = 0.35, TenoLeapLandTime2 = 0.55, TenoLeapFilterRate = 16,
	TenoSlamYawEnabled = true, -- v1.2
}

local JOINTS = {"RootJoint", "Neck", "Head", "Jaw", "ArmL", "ArmR", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5",
	"LegL", "LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"}
TenoPose.JOINTS = JOINTS

-- mockup tables
local J_REAR = {RootJoint = {40, 0, 0}, LegL = {-40, 0, 0}, LegR = {-40, 0, 0}, KneeL = {-30, 0, 0}, KneeR = {-30, 0, 0},
	ArmL = {60, 0, 0}, ArmR = {60, 0, 0}, Neck = {12, 0, 0}, Tail1 = {-30, 0, 0}, Tail2 = {0, 0, 0}, Tail5 = {-12, 0, 0}}
local J_AIR = {RootJoint = {10, 0, 0}, LegL = {-30, 0, 0}, LegR = {-30, 0, 0}, KneeL = {-20, 0, 0}, KneeR = {-20, 0, 0},
	ArmL = {55, 0, 0}, ArmR = {55, 0, 0}, Neck = {12, 0, 0}, Head = {-6, 0, 0}, Jaw = {-18, 0, 0}, Tail1 = {-16, 0, 0},
	Tail2 = {-10, 0, 0}, Tail3 = {-8, 0, 0}, Tail4 = {-6, 0, 0}, Tail5 = {-6, 0, 0}}
local J_LAND = {RootJoint = {-10, 0, 0}, LegL = {24, 0, 0}, LegR = {24, 0, 0}, KneeL = {-30, 0, 0}, KneeR = {-30, 0, 0},
	ArmL = {-20, 0, 0}, ArmR = {-20, 0, 0}, Neck = {-14, 0, 0}, Head = {-8, 0, 0}, Tail1 = {10, 0, 0}, Tail2 = {8, 0, 0},
	Tail3 = {6, 0, 0}}
local D_UP = {RootJoint = {-12, 0, 0}, LegL = {12, 0, 0}, LegR = {12, 0, 0}, KneeL = {-10, 0, 0}, KneeR = {-10, 0, 0},
	ArmL = {-14, 0, 0}, ArmR = {-14, 0, 0}, Neck = {-14, 0, 0}, Head = {14, 0, 0}, Jaw = {-16, 0, 0}, Tail1 = {-58, 0, 0},
	Tail2 = {-24, 0, 0}, Tail3 = {-12, 0, 0}, Tail4 = {6, 0, 0}, Tail5 = {14, 0, 0}}
local D_DOWN = {RootJoint = {6, 0, 0}, LegL = {-6, 0, 0}, LegR = {-6, 0, 0}, ArmL = {-4, 0, 0}, ArmR = {-4, 0, 0},
	Neck = {-4, 0, 0}, Head = {-4, 0, 0}, Tail1 = {16, 0, 0}, Tail2 = {8, 0, 0}, Tail3 = {6, 0, 0}, Tail4 = {-2, 0, 0},
	Tail5 = {-6, 0, 0}}
local SCRATCH_UP = {ArmR = {95, 0, 30}, Neck = {4, -10, 0}, Head = {6, 0, 0}, RootJoint = {8, 0, 0}, LegL = {-8, 0, 0},
	LegR = {-8, 0, 0}, Jaw = {-14, 0, 0}}
local SCRATCH_DOWN = {ArmR = {-20, 0, -10}, Neck = {-6, 6, 0}, Head = {-6, 0, 0}, RootJoint = {-4, 0, 0}, LegL = {4, 0, 0},
	LegR = {4, 0, 0}}
local ZERO = {}
TenoPose.TABLES = {J_REAR = J_REAR, J_AIR = J_AIR, J_LAND = J_LAND, D_UP = D_UP, D_DOWN = D_DOWN,
	SCRATCH_UP = SCRATCH_UP, SCRATCH_DOWN = SCRATCH_DOWN}

local rad, sin, min, max = math.rad, math.sin, math.min, math.max
local function clamp01(u) return math.clamp(u, 0, 1) end
local function ease(u) return 1 - (1 - clamp01(u)) ^ 3 end
local function easeIn(u) return clamp01(u) ^ 2.2 end
local function rot(v) return CFrame.fromEulerAngles(rad(v[3]), rad(v[2]), rad(v[1]), Enum.RotationOrder.ZYX) end
TenoPose.ease, TenoPose.easeIn = ease, easeIn

-- angle table mix (missing joints = {0, 0, 0}); names = which joints to output (nil = the union)
local function mix(A, B, u, names)
	local o = {}
	local function one(k)
		local a, b = A[k] or {0, 0, 0}, B[k] or {0, 0, 0}
		o[k] = {a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u}
	end
	if names then
		for _, k in ipairs(names) do one(k) end
	else
		for k in pairs(A) do one(k) end
		for k in pairs(B) do if not o[k] then one(k) end end
	end
	return o
end
TenoPose.mix = mix

local function toCF(a)
	local out = {}
	for k, v in pairs(a) do out[k] = rot(v) end
	return out
end

function TenoPose.settings(model)
	local s = {}
	for k, v in pairs(TenoPose.Defaults) do
		local a = model:GetAttribute(k)
		if typeof(a) ~= typeof(v) then a = v end
		s[k] = a
	end
	if s.TenoLeapSmoothEnabled ~= false then s.TenoLeapLandTime = s.TenoLeapLandTime2 end -- v1.1: IdleAnimation reads this
	return s
end

-- leap angles (degrees) and weight
function TenoPose.leapAngles(phase, x, s)
	if phase == "crouch" then
		return mix(ZERO, J_REAR, ease(x), JOINTS), 1
	elseif phase == "air" then
		return mix(J_REAR, J_AIR, ease(x / max(0.01, s.TenoLeapAirBlend)), JOINTS), 1
	elseif phase == "land" then
		if x < 0.3 then return mix(J_AIR, J_LAND, x / 0.3, JOINTS), 1 end
		return mix(J_LAND, ZERO, 0, JOINTS), 1 - ease((x - 0.3) / 0.7)
	end
	return mix(ZERO, ZERO, 0, JOINTS), 0
end

-- v1.1: the smooth leap (see the header)
local function smooth(u) u = clamp01(u) return u * u * (3 - 2 * u) end
local filt = {at = -math.huge, a = nil, landFrom = nil}
function TenoPose.leapSmoothAngles(phase, x, s, clock)
	local A, w
	if phase == "crouch" then
		A, w = mix(J_REAR, J_REAR, 0, JOINTS), smooth(x)
	elseif phase == "air" then
		A = mix(J_REAR, J_AIR, smooth(x / max(0.01, s.TenoLeapAirBlend2)), JOINTS)
		A = mix(A, J_LAND, s.TenoLeapReach * smooth((x - s.TenoLeapReachStart) / max(0.01, s.TenoLeapReachTime)), JOINTS)
		w = 1
	elseif phase == "land" then
		local from = filt.landFrom or filt.a or J_AIR
		if not filt.landFrom then filt.landFrom = from end
		local inF = math.clamp(s.TenoLeapLandIn, 0.05, 0.95)
		if x < inF then
			A, w = mix(from, J_LAND, smooth(x / inF), JOINTS), 1
		else
			A, w = mix(J_LAND, J_LAND, 0, JOINTS), 1 - smooth((x - inF) / (1 - inF))
		end
	else
		return mix(ZERO, ZERO, 0, JOINTS), 0
	end
	if phase ~= "land" then filt.landFrom = nil end
	local now = clock or os.clock()
	if not filt.a or now - filt.at > 0.25 then
		filt.a = A
	else
		filt.a = mix(filt.a, A, 1 - math.exp(-s.TenoLeapFilterRate * math.max(0, now - filt.at)), JOINTS)
	end
	filt.at = now
	return filt.a, w
end

function TenoPose.leap(phase, x, s)
	if s.TenoLeapSmoothEnabled ~= false then -- v1.1
		local a, w = TenoPose.leapSmoothAngles(phase, x, s)
		return toCF(a), w
	end
	local a, w = TenoPose.leapAngles(phase, x, s)
	return toCF(a), w
end

-- hold weight for a hold of t seconds
function TenoPose.holdWeight(t, s)
	if t < s.TenoSlamHoldMin then return 0 end
	return ease(t / max(0.01, s.TenoHoldRise))
end

local function num(v) return typeof(v) == "number" and v or nil end

local slamYaw = 0 -- v1.2: the aimed yaw of the current slam (this module copy belongs to one model)
function TenoPose.phase(model, isOwner, serverNow)
	local s = TenoPose.settings(model)
	slamYaw = 0
	if s.TenoSlamYawEnabled ~= false then
		slamYaw = num(isOwner and model:GetAttribute("TenoLocalSlamYaw")) or num(model:GetAttribute("TenoSlamAimYaw")) or 0
	end
	if s.TenoPoseEnabled == false then return nil, 0, 0, "off" end
	local scratchEnd = s.TenoScratchUp + s.TenoScratchDown + s.TenoScratchRecover
	local slamEnd = s.TenoSlamDropTime + s.TenoSlamRecover
	if isOwner then
		local st, at = model:GetAttribute("TenoLocalState"), num(model:GetAttribute("TenoLocalAt"))
		if not at then return nil, 0, 0, "local" end
		local t = serverNow - at
		if st == "hold" then return "hold", t, t, "local" end
		if st == "scratch" and t >= 0 and t < scratchEnd then return "scratch", t, 0, "local" end
		if st == "slam" and t >= 0 and t < slamEnd then
			return "slam", t, num(model:GetAttribute("TenoLocalHold")) or 1, "local"
		end
		return nil, 0, 0, "local"
	end
	local hs = num(model:GetAttribute("TenoHoldSince")) or 0
	local sc = num(model:GetAttribute("TenoScratchAt")) or 0
	local sl = num(model:GetAttribute("TenoSlamAt")) or 0
	if hs > 0 and hs >= sc and hs >= sl then return "hold", serverNow - hs, serverNow - hs, "server" end
	if sl > 0 and sl >= sc and serverNow - sl >= 0 and serverNow - sl < slamEnd then
		return "slam", serverNow - sl, num(model:GetAttribute("TenoSlamHold")) or 1, "server"
	end
	if sc > 0 and sc > sl and serverNow - sc >= 0 and serverNow - sc < scratchEnd then
		return "scratch", serverNow - sc, 0, "server"
	end
	return nil, 0, 0, "server"
end

-- attack angles (degrees)
function TenoPose.attackAngles(phase, t, hold, s, now)
	if phase == "hold" then
		local a = mix(ZERO, D_UP, TenoPose.holdWeight(t, s))
		if t >= s.TenoSlamHoldMin then
			a.Tail5 = a.Tail5 or {0, 0, 0}
			a.Tail5[1] += sin(now * 40) * min(t, 1) * 1.5
		end
		return a
	elseif phase == "scratch" then
		local T1, T2, T3 = s.TenoScratchUp, s.TenoScratchDown, s.TenoScratchRecover
		if t < T1 then return mix(ZERO, SCRATCH_UP, ease(t / T1)) end
		if t < T1 + T2 then return mix(SCRATCH_UP, SCRATCH_DOWN, easeIn((t - T1) / T2)) end
		return mix(SCRATCH_DOWN, ZERO, ease((t - T1 - T2) / T3))
	elseif phase == "slam" then
		local TD = s.TenoSlamDropTime
		local a
		if t < TD then
			local up = mix(ZERO, D_UP, TenoPose.holdWeight(hold, s))
			a = mix(up, D_DOWN, easeIn(t / TD))
		else
			a = mix(D_DOWN, ZERO, ease((t - TD) / s.TenoSlamRecover))
		end
		if slamYaw ~= 0 then -- v1.2: bend the tail toward the aim (fades with the recover)
			local k = t < TD and 1 or 1 - ease((t - TD) / s.TenoSlamRecover)
			for i, share in ipairs({0.3, 0.25, 0.2, 0.15, 0.1}) do
				local j = "Tail" .. i
				a[j] = a[j] or {0, 0, 0}
				a[j][2] += -slamYaw * share * k
			end
		end
		return a
	end
	return {}
end

function TenoPose.attack(phase, t, hold, s, now)
	return toCF(TenoPose.attackAngles(phase, t, hold, s, now))
end

return TenoPose
