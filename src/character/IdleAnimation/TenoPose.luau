-- TenoPose v1.7 (Mecha Dino Arena) — the Tenontosaurus' poses: rearing leap (J2), claw scratch, tail-slam wind-up (hold)
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
-- v1.3 (teno mecha abilities build 1, plan docs/plans/TENO_ABILITIES_v1.0.md Task 7, MDA-179; mockup
--   docs/mockups/teno_abilities_options.html v0.3 poses, same angles): when no scratch / hold / slam is playing, phase()
--   returns the latest ability move still running from TenoMovesServer 1.0's stamps (every client, the owner too):
--   "tgrab"   TenoGrabStartedAt: 0.3 s 0 -> TAIL_DOWN (ease; the catch), 0.5 s -> TAIL_OVER (smooth; carried over the back),
--             0.3 s -> TAIL_THROW (ease; the fling), 0.8 s -> 0 (smooth).
--   "tmortar" TenoMortarStartedAt: 0.35 s 0 -> TAIL_DOWN (smooth), 0.25 s -> TAIL_THROW (ease; the whip), 1 s -> 0.
--   "tstomp"  TenoStompStartedAt: 0.4 s 0 -> REAR (smooth), 0.1 s -> STOMP (easeIn; the hit at 0.5 s), held 0.3 s,
--             0.9 s -> 0 (smooth).
--   "tleap"   TenoLeapStartedAt: 0.12 s 0 -> CROUCH, 0.25 s -> AIR, AIR until the landing (TenoLeapLandedAt, or 1.0 s), then
--             0.15 s -> LEAP_SLAM (the tail slams), held 0.15 s, 0.6 s -> 0.
--   attackAngles handles these phases; IdleAnimation 1.37+ multiplies them on like the attacks (no IdleAnimation change).
--   Switch: model attribute TenoAbilityPoseEnabled (default true; false = 1.2).
-- v1.4 (TenoMovesServer 1.2: the boulder leaves 0.15 s after the press, was 0.35): "tmortar" 0.15 s 0 -> TAIL_DOWN, 0.12 s
--   -> TAIL_THROW (the whip), 0.8 s -> 0 (ends at 1.1 s). Switch: model attribute TenoMortarFastPoseEnabled (default true;
--   false = 1.3 timing).
-- v1.5 (build 2, plan docs/plans/TENO_ABILITIES_v1.0.md Task 7, MDA-179; mockup v0.3 BELLOW / WALLOW angles): three more
--   ability moves from TenoMovesServer 1.3's stamps, in the same layer (the latest running one wins over the build-1 moves):
--   "tbellow"    TenoBellowStartedAt: 0.5 s 0 -> BELLOW (smooth; head up, jaw open), held to 1.7 s, 0.6 s -> 0.
--   "tchallenge" TenoChallengeStartedAt: 0.5 s 0 -> 0.4 x BELLOW (smooth; the painter's turn), held to 1.4 s, 0.6 s -> 0.
--   "tmud"       TenoMudStartedAt: 0.3 s 0 -> WALLOW (smooth; flat on the belly), a body roll RootJoint roll
--                sin(9 t) x 20 x min(1, 3 t) x (1 - t / 1.2) degrees until 1.2 s, then 0.5 s -> 0.
--   Switch: model attribute TenoSupportPoseEnabled (default true; false = 1.4).
-- v1.6 (Kepu 2026-11-02 visual check, "fix all the failed ones": the stomp and the leap landing swung the tail straight up;
--   on TenoModelData 1.4's high S-curve tail the mockup's STOMP / LEAP_SLAM tail angles point it at the sky):
--   * "tstomp" uses STOMP2 = STOMP with Tail1 {14, 0, 0}, Tail2 0 (the tail root cancels the -14 body pitch, so the tail
--     stays level while the front stomps down). Same timing.
--   * "tleap": crouch 0.12 s, AIR, then over the last 0.25 s of the flight AIR -> LEAP_RAISE (a small lift: Tail1 -10,
--     Tail2 -6, RootJoint -4, arms -10, neck -6); at the landing 0.12 s LEAP_RAISE -> SLAM_DOWN2 (easeIn; the mockup's SLAM_DOWN, deeper: Tail1 26, Tail2 14, Tail3 10, Tail4 4,
--     Tail5 -4, RootJoint 6), held to 0.3 s, then 0.6 s -> 0. 1.3 never played the mockup's slam-down.
--   Switch: model attribute TenoPoseFix16Enabled (default true; false = 1.5).
-- v1.7 (Kepu 2026-11-02 16:43: Hydraulic Leap fires through JUMP; "purple shield armor", look B Energy Armor):
--   * "tland" (model TenoLeapOnJump true; TenoMovesServer 1.4 stamps TenoLeapLandedAt at the JUMP leap's landing): 0.12 s
--     0 -> SLAM_DOWN2 (easeIn), held to 0.3 s, 0.6 s -> 0. Only when no scratch / hold / slam plays.
--   * "tmud" is a shield brace instead of the mud wallow: 0.25 s 0 -> BRACE (chest up, arms forward, head up), held to
--     0.9 s, 0.5 s -> 0 (ends 1.4 s, inside SUPPORT_END 1.7).
--   Switch: model attribute TenoPoseFix17Enabled (default true; false = 1.6).
local TenoPose = {}
TenoPose.Version = "1.7"
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
	TenoAbilityPoseEnabled = true, -- v1.3
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
-- v1.3: ability poses (mockup teno_abilities_app.js)
local TAIL_DOWN = {Tail1 = {14, 0, 0}, Tail2 = {14, 0, 0}, Tail3 = {14, 0, 0}, Tail4 = {12, 0, 0}, Tail5 = {10, 0, 0}, RootJoint = {-4, 0, 0}}
local TAIL_OVER = {Tail1 = {-80, 0, 0}, Tail2 = {-48, 0, 0}, Tail3 = {-42, 0, 0}, Tail4 = {-30, 0, 0}, Tail5 = {-20, 0, 0},
	RootJoint = {-10, 0, 0}, LegL = {10, 0, 0}, LegR = {10, 0, 0}, Neck = {-10, 0, 0}}
local TAIL_THROW = {Tail1 = {-95, 0, 0}, Tail2 = {-60, 0, 0}, Tail3 = {-50, 0, 0}, Tail4 = {-35, 0, 0}, Tail5 = {-25, 0, 0},
	RootJoint = {-16, 0, 0}, LegL = {16, 0, 0}, LegR = {16, 0, 0}, Neck = {-14, 0, 0}}
local REAR = {RootJoint = {40, 0, 0}, LegL = {-40, 0, 0}, LegR = {-40, 0, 0}, KneeL = {-30, 0, 0}, KneeR = {-30, 0, 0},
	ArmL = {70, 0, 0}, ArmR = {60, 0, 0}, Neck = {12, 0, 0}, Head = {-6, 0, 0}, Jaw = {-20, 0, 0}, Tail1 = {-30, 0, 0},
	Tail2 = {0, 0, 0}, Tail5 = {-12, 0, 0}}
local STOMP = {RootJoint = {-14, 0, 0}, LegL = {14, 0, 0}, LegR = {14, 0, 0}, ArmL = {-12, 0, 0}, ArmR = {-12, 0, 0},
	Neck = {-16, 0, 0}, Head = {-12, 0, 0}, Jaw = {-8, 0, 0}, Tail1 = {-20, 0, 0}, Tail2 = {-10, 0, 0}}
local CROUCH = {RootJoint = {-8, 0, 0}, LegL = {30, 0, 0}, LegR = {30, 0, 0}, KneeL = {-40, 0, 0}, KneeR = {-40, 0, 0},
	AnkleL = {12, 0, 0}, AnkleR = {12, 0, 0}, ArmL = {-25, 0, 0}, ArmR = {-25, 0, 0}, Neck = {-10, 0, 0}, Tail1 = {8, 0, 0},
	Tail2 = {6, 0, 0}}
local AIR = {RootJoint = {10, 0, 0}, LegL = {-30, 0, 0}, LegR = {-30, 0, 0}, KneeL = {-20, 0, 0}, KneeR = {-20, 0, 0},
	ArmL = {55, 0, 0}, ArmR = {55, 0, 0}, Neck = {12, 0, 0}, Head = {-6, 0, 0}, Jaw = {-18, 0, 0}, Tail1 = {-16, 0, 0},
	Tail2 = {-10, 0, 0}, Tail3 = {-8, 0, 0}, Tail4 = {-6, 0, 0}, Tail5 = {-6, 0, 0}}
local LEAP_SLAM = {RootJoint = {-6, 0, 0}, LegL = {6, 0, 0}, LegR = {6, 0, 0}, ArmL = {-10, 0, 0}, ArmR = {-10, 0, 0},
	Neck = {-8, 0, 0}, Tail1 = {-30, 0, 0}, Tail2 = {-12, 0, 0}, Tail3 = {-6, 0, 0}, Tail4 = {4, 0, 0}, Tail5 = {8, 0, 0}}
local ABILITY_END = {tgrab = 1.9, tmortar = 1.6, tstomp = 1.7}
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
local leapLand = nil -- v1.3: landing time (s after the leap start) of the current leap
local fastMortar = true -- v1.4
local function phaseV12(model, isOwner, serverNow)
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
-- v1.3: the ability moves when no attack plays
function TenoPose.phase(model, isOwner, serverNow)
	local ph, t, hold, src = phaseV12(model, isOwner, serverNow)
	if ph or src == "off" or model:GetAttribute("TenoAbilityPoseEnabled") == false then return ph, t, hold, src end
	local best, bestAt
	for id, k in pairs({tgrab = "TenoGrabStartedAt", tmortar = "TenoMortarStartedAt", tstomp = "TenoStompStartedAt",
		tleap = "TenoLeapStartedAt"}) do
		local at = num(model:GetAttribute(k))
		if at and at > 0 and serverNow >= at then
			local dur = ABILITY_END[id]
			if id == "tleap" then
				local la = num(model:GetAttribute("TenoLeapLandedAt"))
				leapLand = (la and la >= at) and (la - at) or nil
				dur = (leapLand or 1.0) + 0.9
			end
			if serverNow - at < dur and (not bestAt or at > bestAt) then best, bestAt = id, at end
		end
	end
	fastMortar = model:GetAttribute("TenoMortarFastPoseEnabled") ~= false -- v1.4
	if best then return best, serverNow - bestAt, 0, "ability" end
	return ph, t, hold, src
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
	elseif phase == "tgrab" then -- v1.3
		if t < 0.3 then return mix(ZERO, TAIL_DOWN, ease(t / 0.3)) end
		if t < 0.8 then return mix(TAIL_DOWN, TAIL_OVER, smooth((t - 0.3) / 0.5)) end
		if t < 1.1 then return mix(TAIL_OVER, TAIL_THROW, ease((t - 0.8) / 0.3)) end
		return mix(TAIL_THROW, ZERO, smooth((t - 1.1) / 0.8))
	elseif phase == "tmortar" and fastMortar then -- v1.4
		if t < 0.15 then return mix(ZERO, TAIL_DOWN, smooth(t / 0.15)) end
		if t < 0.27 then return mix(TAIL_DOWN, TAIL_THROW, ease((t - 0.15) / 0.12)) end
		return mix(TAIL_THROW, ZERO, smooth((t - 0.27) / 0.8))
	elseif phase == "tmortar" then
		if t < 0.35 then return mix(ZERO, TAIL_DOWN, smooth(t / 0.35)) end
		if t < 0.6 then return mix(TAIL_DOWN, TAIL_THROW, ease((t - 0.35) / 0.25)) end
		return mix(TAIL_THROW, ZERO, smooth((t - 0.6) / 1))
	elseif phase == "tstomp" then
		if t < 0.4 then return mix(ZERO, REAR, smooth(t / 0.4)) end
		if t < 0.5 then return mix(REAR, STOMP, easeIn((t - 0.4) / 0.1)) end
		if t < 0.8 then return mix(STOMP, STOMP, 0) end
		return mix(STOMP, ZERO, smooth((t - 0.8) / 0.9))
	elseif phase == "tleap" then
		local L = leapLand or 1.0
		if t < 0.12 then return mix(ZERO, CROUCH, ease(t / 0.12)) end
		if t < L then return mix(CROUCH, AIR, smooth((t - 0.12) / 0.25)) end
		local u = t - L
		if u < 0.15 then return mix(AIR, LEAP_SLAM, ease(u / 0.15)) end
		if u < 0.3 then return mix(LEAP_SLAM, LEAP_SLAM, 0) end
		return mix(LEAP_SLAM, ZERO, smooth((u - 0.3) / 0.6))
	end
	return {}
end

function TenoPose.attack(phase, t, hold, s, now)
	return toCF(TenoPose.attackAngles(phase, t, hold, s, now))
end

-- v1.5: build-2 ability poses (mockup teno_abilities_app.js BELLOW / WALLOW)
local BELLOW = {Neck = {34, 0, 0}, Head = {18, 0, 0}, Jaw = {-38, 0, 0}, RootJoint = {6, 0, 0}, LegL = {-6, 0, 0}, LegR = {-6, 0, 0},
	Tail1 = {-10, 0, 0}}
local WALLOW = {RootJoint = {-6, 0, 0}, LegL = {40, 0, 0}, LegR = {40, 0, 0}, KneeL = {-60, 0, 0}, KneeR = {-60, 0, 0}, ArmL = {-40, 0, 0},
	ArmR = {-40, 0, 0}, Neck = {-20, 0, 0}}
local SUPPORT_END = {tbellow = 2.3, tchallenge = 2.0, tmud = 1.7}
local SUPPORT_KEYS = {tbellow = "TenoBellowStartedAt", tchallenge = "TenoChallengeStartedAt", tmud = "TenoMudStartedAt"}
do
	local phaseV14 = TenoPose.phase
	function TenoPose.phase(model, isOwner, serverNow)
		local ph, t, hold, src = phaseV14(model, isOwner, serverNow)
		if src == "off" or model:GetAttribute("TenoAbilityPoseEnabled") == false or model:GetAttribute("TenoSupportPoseEnabled") == false then
			return ph, t, hold, src
		end
		if ph and src ~= "ability" then return ph, t, hold, src end -- a scratch / hold / slam plays
		local best, bestAt
		for id, k in pairs(SUPPORT_KEYS) do
			local at = num(model:GetAttribute(k))
			if at and at > 0 and serverNow >= at and serverNow - at < SUPPORT_END[id] and (not bestAt or at > bestAt) then best, bestAt = id, at end
		end
		if best and (not ph or bestAt > serverNow - t) then return best, serverNow - bestAt, 0, "ability" end
		return ph, t, hold, src
	end
	local anglesV14 = TenoPose.attackAngles
	function TenoPose.attackAngles(phase, t, hold, s, now)
		if phase == "tbellow" then
			if t < 0.5 then return mix(ZERO, BELLOW, smooth(t / 0.5)) end
			if t < 1.7 then return mix(BELLOW, BELLOW, 0) end
			return mix(BELLOW, ZERO, smooth((t - 1.7) / 0.6))
		elseif phase == "tchallenge" then
			local half = mix(ZERO, BELLOW, 0.4)
			if t < 0.5 then return mix(ZERO, BELLOW, smooth(t / 0.5) * 0.4) end
			if t < 1.4 then return half end
			return mix(half, ZERO, smooth((t - 1.4) / 0.6))
		elseif phase == "tmud" then
			if t < 1.2 then
				local a = mix(ZERO, WALLOW, smooth(t / 0.3))
				a.RootJoint[3] += sin(t * 9) * 20 * min(1, t * 3) * (1 - t / 1.2)
				return a
			end
			return mix(WALLOW, ZERO, smooth((t - 1.2) / 0.5))
		end
		return anglesV14(phase, t, hold, s, now)
	end
end

-- v1.6: stomp keeps the tail level; the leap landing slams the tail down
local STOMP2 = {RootJoint = {-14, 0, 0}, LegL = {14, 0, 0}, LegR = {14, 0, 0}, ArmL = {-12, 0, 0}, ArmR = {-12, 0, 0},
	Neck = {-16, 0, 0}, Head = {-12, 0, 0}, Jaw = {-8, 0, 0}, Tail1 = {14, 0, 0}}
local SLAM_DOWN2 = {RootJoint = {6, 0, 0}, LegL = {-6, 0, 0}, LegR = {-6, 0, 0}, Neck = {-4, 0, 0}, Tail1 = {26, 0, 0},
	Tail2 = {14, 0, 0}, Tail3 = {10, 0, 0}, Tail4 = {4, 0, 0}, Tail5 = {-4, 0, 0}}
local LEAP_RAISE = {RootJoint = {-4, 0, 0}, ArmL = {-10, 0, 0}, ArmR = {-10, 0, 0}, Neck = {-6, 0, 0}, Tail1 = {-10, 0, 0},
	Tail2 = {-6, 0, 0}}
local fix16 = true
do
	local phaseV15 = TenoPose.phase
	function TenoPose.phase(model, isOwner, serverNow)
		fix16 = model:GetAttribute("TenoPoseFix16Enabled") ~= false
		return phaseV15(model, isOwner, serverNow)
	end
	local anglesV15 = TenoPose.attackAngles
	function TenoPose.attackAngles(phase, t, hold, s, now)
		if fix16 and phase == "tstomp" then
			if t < 0.4 then return mix(ZERO, REAR, smooth(t / 0.4)) end
			if t < 0.5 then return mix(REAR, STOMP2, easeIn((t - 0.4) / 0.1)) end
			if t < 0.8 then return mix(STOMP2, STOMP2, 0) end
			return mix(STOMP2, ZERO, smooth((t - 0.8) / 0.9))
		elseif fix16 and phase == "tleap" then
			local L = leapLand or 1.0
			if t < 0.12 then return mix(ZERO, CROUCH, ease(t / 0.12)) end
			if t < L then
				local a = mix(CROUCH, AIR, smooth((t - 0.12) / 0.25))
				local k = smooth((t - (L - 0.25)) / 0.25)
				if k > 0 then a = mix(a, LEAP_RAISE, k) end
				return a
			end
			local u = t - L
			if u < 0.12 then return mix(LEAP_RAISE, SLAM_DOWN2, easeIn(u / 0.12)) end
			if u < 0.3 then return mix(SLAM_DOWN2, SLAM_DOWN2, 0) end
			return mix(SLAM_DOWN2, ZERO, smooth((u - 0.3) / 0.6))
		end
		return anglesV15(phase, t, hold, s, now)
	end
end

-- v1.7: the JUMP leap's landing slam; the shield brace
local BRACE = {RootJoint = {10, 0, 0}, LegL = {-10, 0, 0}, LegR = {-10, 0, 0}, ArmL = {35, 0, 0}, ArmR = {35, 0, 0},
	Neck = {16, 0, 0}, Head = {-8, 0, 0}, Jaw = {-16, 0, 0}, Tail1 = {-6, 0, 0}}
local fix17 = true
do
	local phaseV16 = TenoPose.phase
	function TenoPose.phase(model, isOwner, serverNow)
		fix17 = model:GetAttribute("TenoPoseFix17Enabled") ~= false
		local ph, t, hold, src = phaseV16(model, isOwner, serverNow)
		if not fix17 or src == "off" or model:GetAttribute("TenoLeapOnJump") ~= true then return ph, t, hold, src end
		if ph and src ~= "ability" then return ph, t, hold, src end -- a scratch / hold / slam plays
		local la = num(model:GetAttribute("TenoLeapLandedAt"))
		if la and la > 0 and serverNow >= la and serverNow - la < 0.9 and (not ph or la > serverNow - t) then
			return "tland", serverNow - la, 0, "ability"
		end
		return ph, t, hold, src
	end
	local anglesV16 = TenoPose.attackAngles
	function TenoPose.attackAngles(phase, t, hold, s, now)
		if fix17 and phase == "tland" then
			if t < 0.12 then return mix(ZERO, SLAM_DOWN2, easeIn(t / 0.12)) end
			if t < 0.3 then return mix(SLAM_DOWN2, SLAM_DOWN2, 0) end
			return mix(SLAM_DOWN2, ZERO, smooth((t - 0.3) / 0.6))
		elseif fix17 and phase == "tmud" then
			if t < 0.25 then return mix(ZERO, BRACE, smooth(t / 0.25)) end
			if t < 0.9 then return mix(BRACE, BRACE, 0) end
			return mix(BRACE, ZERO, smooth((t - 0.9) / 0.5))
		end
		return anglesV16(phase, t, hold, s, now)
	end
end

return TenoPose
