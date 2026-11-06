-- TenoPose v1.11 (Mecha Dino Arena) — the Tenontosaurus' poses: rearing leap (J2), claw scratch, tail-slam wind-up (hold)
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
-- v1.8 (Kepu 2026-11-02 17:29: "the mortar animation ... needs to be beefed up" -> "Big wind-up + whip"; TenoMovesServer 1.5
--   releases the boulder at 0.55 s): "tmortar" = 0.5 s 0 -> MORTAR_COIL (smooth: the body sinks into a crouch, the front
--   dips, the tail drops low behind, curled down), 0.1 s -> MORTAR_WHIP (easeIn: the tail cracks up over the back, the
--   chest lifts), held to 0.75 s, 0.7 s -> 0 (ends 1.45 s, inside ABILITY_END 1.6). Switch: model attribute
--   TenoMortarBigPoseEnabled (default true; false = 1.7, the 1.4 quick whip).
-- v1.9 (MDA-218, plan docs/plans/TENO_TAIL_GRAB_v1.0.md Task 4, mockup docs/mockups/teno_tail_grab_v0.1.html; Kepu
--   2026-11-03 picked A "Over the Top"): when the teno's grab is TenoMovesServer 1.7's (TenoGrabSide "front" / "back",
--   TenoGrabCatchAt, TenoGrabThrowAtPlan, TenoGrabStartedAt younger than 4 s), "tgrab" no longer plays the 1.3 tail
--   keyframes. Times t from TenoGrabStartedAt; catch / throw from the stamps; W = GRAB_WIND 0.25, R = GRAB_RECOVER 0.9:
--   * body (attackAngles, no tail joints): GRAB_BRACE (legs braced) and, in front, GRAB_LEAN_FRONT (chest down, legs pushed);
--     0 -> lean over W (ease), held, over the last 0.2 s before the throw + the whip lean (front RootJoint -14; back
--     RootJoint -16, Neck -14; easeIn), then over R back to 0 (smooth). The phase lasts throw + R + 0.05 (was 1.9).
--   * tail (grabTail, called by IdleAnimation 1.41 with its motors and this frame's pose): the clamp point (Tail5_main x
--     (CLAMP_X -2.6 x scale, 0, 0), between the Clamp Tail's jaws) is driven to a goal in HumanoidRootPart space by
--     coordinate descent on Tail1..Tail5 pitch / yaw offsets (pitch -118..48, yaw -82..82 degrees; cost = squared miss +
--     0.0006 x angle^2 + 0.0012 x (neighbour difference)^2; IK_SWEEPS 6 sweeps of steps 6, 3, 1.5, 0.8, 0.4, 0.2 degrees,
--     warm-started from the last frame) through the rig's forward kinematics (restC0 x pose x C1^-1 from the root).
--     Landmarks at the grab's start (HRP space): rest = the clamp point with no tail offset, hips = Torso_hips, head =
--     Head_cranium; k = |rest - hips| / 33.8 (the mockup's length). Target = the top of TenoGrabTargetRef's bounding box
--     (front fallback head + (0, 0, -10k), back rest + (0, 0, 5k)). Goals:
--       wind-up 0..W: rest -> the coil, rest + (0, 2k, 3k) (ease);
--       strike W..catch: front = bezier(coil, hips + (0, 29.2k, -2.5k), target) (ease); back = straight (ease);
--       lift catch..throw - 0.2: clamp at the catch -> hips + (0, 23.2k, 0.5k) (+ 4k x sin(pi u) up; smooth);
--       whip throw - 0.2..throw: -> front rest + (0, 5.4k, 6k) / back head + (0, 10.6k, -5k) (easeIn);
--       recover throw..throw + R: from the whip's end to front rest + (0, 1.4k, 3k) / back rest + (0, 3k, -2k)
--       (smooth over the first 1 / 1.6 of R), the offsets fading to 0 (smooth). Returns {TailN = CFrame} and the miss
--       (studs) for the diagnostic.
--   Switch: model attribute TenoGrabIKEnabled (default true; false = 1.8 keyframes for every grab).
-- v1.10 (Kepu 2026-11-05 17:40 "the jump is like glitching when I land and some of the tail grab animations ain't looking
--   good"; Studio: the landing slam started ~0.2 s after the touchdown (the server's TenoLeapLandedAt), and the grab's clamp
--   point was the old Clamp Tail's while the v460 Pincer Tail grips ~2 units further out):
--   * "tland" on the owner's client starts at the character's local TenoLocalLandAt (TenoPoseFix 1.0, the touchdown on this
--     client) when it is newer than the server's TenoLeapLandedAt, or when the server's stamp comes less than 1 s after it
--     (the same landing). Other clients keep the server stamp. Switch: model attribute TenoLocalLandEnabled (nil = true).
--   * the grab's clamp point x (Tail5_main frame, scale 1) = the character's TenoGrabClampX (TenoPartsServer 1.4: -3.7 with
--     the Pincer Tail) when it is set, else CLAMP_X (-2.6). Switch: model attribute TenoGrabClampAttrEnabled (nil = true).
-- v1.11 (MDA-279, plan docs/plans/TENO_GRAB_SCORPION_v1.0.md Task 2, mockup docs/mockups/teno_moves_anim.html v0.1; Kepu
--   2026-11-05 18:10 picked A "Scorpion Strike"): when the grab's TenoGrabStyle is "scorpion" (TenoMovesServer 1.10) the
--   v1.9 grab plays the Scorpion path. W = catch - 0.15 (the strike), S = throw - 0.15 (the slam), R = GRAB_RECOVER 0.9.
--   k2 = |rest - hips| / 17.9 (the v0.1 mockup's clamp-to-hips length); goals = hips + offset x k2 (HRP space):
--   * body (attackAngles): 0..W 0 -> SC_BODY[side] (front nose down: RootJoint -12, Neck -12, Head -8, legs 24 / knees -24 /
--     ankles 8, arms -14; back rearing: RootJoint 10, Neck 8, Head -4, legs -6, knees -14, arms 16) (ease); held to the
--     catch; catch..S -> GRAB_BRACE (smooth); S..throw -> SC_SLAM[side] (front RootJoint 6, back RootJoint -10 / Neck -10 on
--     the brace; easeIn); throw..throw + R -> 0 (smooth).
--   * tail goals: 0..W rest -> coil (front (0.4, 10.08, 2.25), back (0.4, 7.58, 12.75)) (ease); W..catch the strike =
--     bezier(coil, coil + (0, 2, -6 front / +6 back), target) (easeIn), "tight" IK (smoothing x 0.08, IK_SWEEPS + 4) from
--     70 % of the strike; catch..S bezier(clamp at the catch, its midpoint to carry + (0, 3, 0), carry) (smooth), carry front
--     (0.4, 7.08, 2.75) / back (0.4, 7.08, 0.75); S..throw -> slam front (0.6, 1.58, 15.75) / back (0.6, 1.58, -9.25)
--     (easeIn); throw..throw + R -> recover front (0.4, 3.58, 14.75) / back (0.4, 4.58, 8.75) over the first 1 / 1.6, the
--     offsets fading to 0 (smooth).
--   * reach step (owner only): at a new grab the tail is pre-solved (tight, 10 sweeps) onto the target from this frame's pose;
--     a miss over 0.5 k2 sets the character's local TenoGrabStepWant = the flat world vector toward the target of length
--     (miss - 0.5 k2), capped at 2 k2 front / 5 k2 back (TenoPoseFix 1.1 slides the root by it), and TenoGrabStepFor = the
--     grab's TenoGrabStartedAt; else TenoGrabStepWant = Vector3.zero.
--   Switch: model attribute TenoGrabScorpionEnabled (nil = true; false = the 1.10 Over-the-Top path for every grab).
local TenoPose = {}
TenoPose.Version = "1.8"
TenoPose.Version = "1.9" -- v1.9 Over-the-Top grab IK
TenoPose.Version = "1.10" -- v1.10 local landing slam, the look's clamp point
TenoPose.Version = "1.11" -- v1.11 Scorpion Strike grab
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

-- v1.10: the landing time the "tland" slam starts from (see the header)
local function landTime(model, isOwner)
	local la = num(model:GetAttribute("TenoLeapLandedAt"))
	if not isOwner or model:GetAttribute("TenoLocalLandEnabled") == false then return la end
	local ll = num(model:GetAttribute("TenoLocalLandAt"))
	if ll and (not la or la < ll or la - ll < 1.0) then return ll end
	return la
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
		local la = landTime(model, isOwner) -- v1.10 (was the server's TenoLeapLandedAt)
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

-- v1.8: the mortar's big wind-up and whip
local MORTAR_COIL = {RootJoint = {-8, 0, 0}, LegL = {20, 0, 0}, LegR = {20, 0, 0}, KneeL = {-28, 0, 0}, KneeR = {-28, 0, 0},
	AnkleL = {8, 0, 0}, AnkleR = {8, 0, 0}, ArmL = {-12, 0, 0}, ArmR = {-12, 0, 0}, Neck = {-10, 0, 0}, Head = {6, 0, 0},
	Tail1 = {28, 0, 0}, Tail2 = {22, 0, 0}, Tail3 = {20, 0, 0}, Tail4 = {18, 0, 0}, Tail5 = {16, 0, 0}}
local MORTAR_WHIP = {RootJoint = {10, 0, 0}, LegL = {-10, 0, 0}, LegR = {-10, 0, 0}, ArmL = {20, 0, 0}, ArmR = {20, 0, 0},
	Neck = {12, 0, 0}, Head = {-8, 0, 0}, Jaw = {-14, 0, 0}, Tail1 = {-110, 0, 0}, Tail2 = {-70, 0, 0}, Tail3 = {-55, 0, 0},
	Tail4 = {-40, 0, 0}, Tail5 = {-30, 0, 0}}
local bigMortar = true
do
	local phaseV17 = TenoPose.phase
	function TenoPose.phase(model, isOwner, serverNow)
		bigMortar = model:GetAttribute("TenoMortarBigPoseEnabled") ~= false
		return phaseV17(model, isOwner, serverNow)
	end
	local anglesV17 = TenoPose.attackAngles
	function TenoPose.attackAngles(phase, t, hold, s, now)
		if bigMortar and phase == "tmortar" then
			if t < 0.5 then return mix(ZERO, MORTAR_COIL, smooth(t / 0.5)) end
			if t < 0.6 then return mix(MORTAR_COIL, MORTAR_WHIP, easeIn((t - 0.5) / 0.1)) end
			if t < 0.75 then return mix(MORTAR_WHIP, MORTAR_WHIP, 0) end
			return mix(MORTAR_WHIP, ZERO, smooth((t - 0.75) / 0.7))
		end
		return anglesV17(phase, t, hold, s, now)
	end
end

-- v1.9: Over-the-Top grab (see the header)
local GRAB_WIND, GRAB_RECOVER, CLAMP_X, IK_SWEEPS, MOCK_LEN = 0.25, 0.9, -2.6, 6, 33.8
local GRAB_BRACE = {LegL = {12, 0, 0}, LegR = {12, 0, 0}, KneeL = {-10, 0, 0}, KneeR = {-10, 0, 0}}
local GRAB_LEAN_FRONT = {RootJoint = {-10, 0, 0}, Neck = {-16, 0, 0}, Head = {-10, 0, 0}, LegL = {22, 0, 0}, LegR = {22, 0, 0},
	KneeL = {-18, 0, 0}, KneeR = {-18, 0, 0}}
local GRAB_WHIP = {front = {RootJoint = {-14, 0, 0}}, back = {RootJoint = {-16, 0, 0}, Neck = {-14, 0, 0}}}
local TAILS = {"Tail1", "Tail2", "Tail3", "Tail4", "Tail5"}
local LIM = {{-118, 48}, {-82, 82}}
local IK_STEPS = {6, 3, 1.5, 0.8, 0.4, 0.2}
local grab -- the current v1.7 grab {side, st, catch, throw} (relative times) or nil
local function over(a, b) -- angle table a with b's joints added on top
	local o = {}
	for k, v in pairs(a) do o[k] = {v[1], v[2], v[3]} end
	for k, v in pairs(b) do
		local x = o[k] or {0, 0, 0}
		o[k] = {x[1] + v[1], x[2] + v[2], x[3] + v[3]}
	end
	return o
end
do
	local phaseV18 = TenoPose.phase
	function TenoPose.phase(model, isOwner, serverNow)
		grab = nil
		ABILITY_END.tgrab = 1.9
		if model:GetAttribute("TenoGrabIKEnabled") ~= false then
			local st, side = num(model:GetAttribute("TenoGrabStartedAt")), model:GetAttribute("TenoGrabSide")
			local ca, th = num(model:GetAttribute("TenoGrabCatchAt")), num(model:GetAttribute("TenoGrabThrowAtPlan"))
			if st and ca and th and (side == "front" or side == "back") and ca > st and th > ca and serverNow - st < 4 then
				grab = {side = side, st = st, catch = ca - st, throw = th - st}
				ABILITY_END.tgrab = grab.throw + GRAB_RECOVER + 0.05
			end
		end
		return phaseV18(model, isOwner, serverNow)
	end
	local anglesV18 = TenoPose.attackAngles
	function TenoPose.attackAngles(phase, t, hold, s, now)
		if phase == "tgrab" and grab then
			local lean = grab.side == "front" and over(GRAB_BRACE, GRAB_LEAN_FRONT) or GRAB_BRACE
			local whip = over(lean, GRAB_WHIP[grab.side])
			if t < GRAB_WIND then return mix(ZERO, lean, ease(t / GRAB_WIND)) end
			if t < grab.throw - 0.2 then return mix(lean, lean, 0) end
			if t < grab.throw then return mix(lean, whip, easeIn((t - (grab.throw - 0.2)) / 0.2)) end
			return mix(whip, ZERO, smooth((t - grab.throw) / GRAB_RECOVER))
		end
		return anglesV18(phase, t, hold, s, now)
	end
end

-- the tail IK (IdleAnimation 1.41 calls this while the phase is "tgrab")
local chain, chainScale, clampOff -- motor names from the root to Tail5's segment; Tail5 Root -> clamp point
local chainClampX -- v1.10: the clamp x the chain was built with
local function clampX(model) -- v1.10
	if model:GetAttribute("TenoGrabClampAttrEnabled") == false then return CLAMP_X end
	return num(model:GetAttribute("TenoGrabClampX")) or CLAMP_X
end
local sol, solKey -- warm start {TailN = {pitch, yaw}}, the grab it belongs to
local marks -- landmarks of the current grab (HRP space)
local function buildChain(model, motors, hrp)
	local seg = model:FindFirstChild("Tail5")
	local root = seg and seg:FindFirstChild("Root")
	local main = model:FindFirstChild("Tail5_main", true)
	if not (root and main) then return nil end
	local names, part, guard = {}, root, 0
	while part ~= hrp do
		guard += 1
		if guard > 16 then return nil end
		local found
		for name, e in pairs(motors) do
			if e.motor.Part1 == part then found = name break end
		end
		if not found then return nil end
		table.insert(names, 1, found)
		part = motors[found].motor.Part0
		if not part then return nil end
	end
	local sc = model:GetScale()
	chainClampX = clampX(model) -- v1.10 (was CLAMP_X)
	clampOff = root.CFrame:Inverse() * main.CFrame * CFrame.new(chainClampX * sc, 0, 0)
	chainScale = sc
	return names
end
local function fkClamp(motors, pose, ang)
	local cf = CFrame.identity
	for _, name in ipairs(chain) do
		local e = motors[name]
		local p = pose[name] or CFrame.identity
		local a = ang and ang[name]
		if a then p = p * rot({a[1], a[2], 0}) end
		cf = cf * e.restC0 * p * e.motor.C1:Inverse()
	end
	return (cf * clampOff).Position
end
local function bez(a, b, c, u) return a * ((1 - u) * (1 - u)) + b * (2 * u * (1 - u)) + c * (u * u) end
local function solve(motors, pose, goal)
	local ang = {}
	for _, n in ipairs(TAILS) do local v = sol and sol[n] or {0, 0} ang[n] = {v[1], v[2]} end
	local function cost()
		local d = fkClamp(motors, pose, ang) - goal
		local c = d:Dot(d)
		for i, n in ipairs(TAILS) do
			local a = ang[n]
			c += 0.0006 * (a[1] * a[1] + a[2] * a[2])
			if i > 1 then
				local b = ang[TAILS[i - 1]]
				c += 0.0012 * ((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
			end
		end
		return c
	end
	local best = cost()
	for sw = 1, IK_SWEEPS do
		local st = IK_STEPS[math.min(sw, #IK_STEPS)]
		for i = #TAILS, 1, -1 do
			local a = ang[TAILS[i]]
			for ax = 1, 2 do
				for _, dir in ipairs({1, -1}) do
					for _ = 1, 4 do
						local old = a[ax]
						a[ax] = math.clamp(old + dir * st, LIM[ax][1], LIM[ax][2])
						local c = cost()
						if c < best - 1e-6 then best = c else a[ax] = old break end
					end
				end
			end
		end
	end
	sol = ang
	return ang, (fkClamp(motors, pose, ang) - goal).Magnitude
end
local function toOffsets(ang, w)
	local out = {}
	for _, n in ipairs(TAILS) do
		local a = ang[n]
		out[n] = CFrame.identity:Lerp(rot({a[1], a[2], 0}), w)
	end
	return out
end
function TenoPose.grabTail(model, motors, pose, serverNow)
	if not grab then return nil end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	for _, n in ipairs(TAILS) do if not motors[n] then return nil end end
	if not chain or chainScale ~= model:GetScale() or chainClampX ~= clampX(model) then chain = buildChain(model, motors, hrp) end -- v1.10: + clamp x
	if not chain then return nil end
	local t = serverNow - grab.st
	if solKey ~= grab.st then -- a new grab: landmarks from this frame's pose
		solKey, sol = grab.st, nil
		local rest = fkClamp(motors, pose, nil)
		local hips, head = model:FindFirstChild("Torso_hips", true), model:FindFirstChild("Head_cranium", true)
		local hipsL = hips and hrp.CFrame:PointToObjectSpace(hips.Position) or Vector3.zero
		local headL = head and hrp.CFrame:PointToObjectSpace(head.Position) or Vector3.new(0, 0, -10)
		marks = {rest = rest, hips = hipsL, head = headL, k = math.max(0.2, (rest - hipsL).Magnitude / MOCK_LEN)}
	end
	local k, M = marks.k, marks
	local function target()
		local ref = model:FindFirstChild("TenoGrabTargetRef")
		local m = ref and ref:IsA("ObjectValue") and ref.Value
		if m and m.Parent then
			local cf, size = m:GetBoundingBox()
			return hrp.CFrame:PointToObjectSpace(cf.Position + Vector3.new(0, size.Y / 2, 0))
		end
		return grab.side == "front" and M.head + Vector3.new(0, 0, -10 * k) or M.rest + Vector3.new(0, 0, 5 * k)
	end
	M.wind = M.wind or M.rest + Vector3.new(0, 2 * k, 3 * k) -- the coil: back and a little up (stays off the ground)
	local overPt = M.hips + Vector3.new(0, 23.2 * k, 0.5 * k)
	local whipTo = grab.side == "front" and M.rest + Vector3.new(0, 5.4 * k, 6 * k) or M.head + Vector3.new(0, 10.6 * k, -5 * k)
	local follow = grab.side == "front" and M.rest + Vector3.new(0, 1.4 * k, 3 * k) or M.rest + Vector3.new(0, 3 * k, -2 * k)
	local goal, w = nil, 1
	if t < GRAB_WIND then
		goal = M.rest:Lerp(M.wind, ease(t / GRAB_WIND))
	elseif t < grab.catch then
		local u = ease((t - GRAB_WIND) / math.max(0.05, grab.catch - GRAB_WIND))
		if grab.side == "front" then
			goal = bez(M.wind, M.hips + Vector3.new(0, 29.2 * k, -2.5 * k), target(), u)
		else
			goal = M.wind:Lerp(target(), u)
		end
		M.atCatch = nil
	elseif t < grab.throw - 0.2 then
		if not M.atCatch then M.atCatch = fkClamp(motors, pose, sol) end
		local u = smooth((t - grab.catch) / math.max(0.05, grab.throw - 0.2 - grab.catch))
		goal = M.atCatch:Lerp(overPt, u) + Vector3.new(0, 4 * k * math.sin(math.pi * u), 0)
	elseif t < grab.throw then
		goal = overPt:Lerp(whipTo, easeIn((t - (grab.throw - 0.2)) / 0.2))
	elseif t < grab.throw + GRAB_RECOVER then
		local u = (t - grab.throw) / GRAB_RECOVER
		goal = whipTo:Lerp(follow, smooth(u * 1.6)) -- follow-through from where the whip ended
		w = 1 - smooth(u)
	else
		return nil
	end
	local ang, miss = solve(motors, pose, goal)
	return toOffsets(ang, w), miss
end

-- v1.11: Scorpion Strike grab (see the header)
local SC_LEN, SC_STRIKE, SC_SLAM_T = 17.9, 0.15, 0.15
local SC_BODY = {
	front = {RootJoint = {-12, 0, 0}, Neck = {-12, 0, 0}, Head = {-8, 0, 0}, LegL = {24, 0, 0}, LegR = {24, 0, 0}, KneeL = {-24, 0, 0},
		KneeR = {-24, 0, 0}, AnkleL = {8, 0, 0}, AnkleR = {8, 0, 0}, ArmL = {-14, 0, 0}, ArmR = {-14, 0, 0}},
	back = {RootJoint = {10, 0, 0}, Neck = {8, 0, 0}, Head = {-4, 0, 0}, LegL = {-6, 0, 0}, LegR = {-6, 0, 0}, KneeL = {-14, 0, 0},
		KneeR = {-14, 0, 0}, ArmL = {16, 0, 0}, ArmR = {16, 0, 0}},
}
local SC_SLAM = {front = over(GRAB_BRACE, {RootJoint = {6, 0, 0}}), back = over(GRAB_BRACE, {RootJoint = {-10, 0, 0}, Neck = {-10, 0, 0}})}
local SC_GOALS = {
	front = {coil = Vector3.new(0.4, 10.08, 2.25), dz = -6, carry = Vector3.new(0.4, 7.08, 2.75), slam = Vector3.new(0.6, 1.58, 15.75),
		rec = Vector3.new(0.4, 3.58, 14.75), cap = 2},
	back = {coil = Vector3.new(0.4, 7.58, 12.75), dz = 6, carry = Vector3.new(0.4, 7.08, 0.75), slam = Vector3.new(0.6, 1.58, -9.25),
		rec = Vector3.new(0.4, 4.58, 8.75), cap = 5},
}
local function scorpionOn(model) -- this frame's grab plays the Scorpion path
	return grab ~= nil and grab.style == "scorpion" and model:GetAttribute("TenoGrabScorpionEnabled") ~= false
end
local function solveSc(motors, pose, goal, tight, sweeps) -- solve() with weak smoothing ("tight": the jaws ON the target)
	local ang = {}
	for _, n in ipairs(TAILS) do local v = sol and sol[n] or {0, 0} ang[n] = {v[1], v[2]} end
	local w = tight and 0.08 or 1
	local function cost()
		local d = fkClamp(motors, pose, ang) - goal
		local c = d:Dot(d)
		for i, n in ipairs(TAILS) do
			local a = ang[n]
			c += w * 0.0006 * (a[1] * a[1] + a[2] * a[2])
			if i > 1 then
				local b = ang[TAILS[i - 1]]
				c += w * 0.0012 * ((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
			end
		end
		return c
	end
	local best = cost()
	for sw = 1, sweeps or (IK_SWEEPS + (tight and 4 or 0)) do
		local st = IK_STEPS[math.min(sw, #IK_STEPS)]
		for i = #TAILS, 1, -1 do
			local a = ang[TAILS[i]]
			for ax = 1, 2 do
				for _, dir in ipairs({1, -1}) do
					for _ = 1, 4 do
						local old = a[ax]
						a[ax] = math.clamp(old + dir * st, LIM[ax][1], LIM[ax][2])
						local c = cost()
						if c < best - 1e-6 then best = c else a[ax] = old break end
					end
				end
			end
		end
	end
	sol = ang
	return ang, (fkClamp(motors, pose, ang) - goal).Magnitude
end
do
	local phaseV110 = TenoPose.phase
	function TenoPose.phase(model, isOwner, serverNow)
		local r1, r2, r3, r4 = phaseV110(model, isOwner, serverNow)
		if grab then grab.style, grab.owner = model:GetAttribute("TenoGrabStyle"), isOwner grab.scOn = scorpionOn(model) end
		return r1, r2, r3, r4
	end
	local anglesV110 = TenoPose.attackAngles
	function TenoPose.attackAngles(phase, t, hold, s, now)
		if phase == "tgrab" and grab and grab.style == "scorpion" and grab.scOn then
			local body = SC_BODY[grab.side]
			local W, S = grab.catch - SC_STRIKE, grab.throw - SC_SLAM_T
			if t < W then return mix(ZERO, body, ease(t / math.max(0.05, W))) end
			if t < grab.catch then return mix(body, body, 0) end
			if t < S then return mix(body, GRAB_BRACE, smooth((t - grab.catch) / math.max(0.05, S - grab.catch))) end
			if t < grab.throw then return mix(GRAB_BRACE, SC_SLAM[grab.side], easeIn((t - S) / SC_SLAM_T)) end
			return mix(SC_SLAM[grab.side], ZERO, smooth((t - grab.throw) / GRAB_RECOVER))
		end
		return anglesV110(phase, t, hold, s, now)
	end
	local grabTailV110 = TenoPose.grabTail
	function TenoPose.grabTail(model, motors, pose, serverNow)
		if grab then grab.scOn = scorpionOn(model) end
		if not (grab and grab.scOn) then return grabTailV110(model, motors, pose, serverNow) end
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if not hrp then return nil end
		for _, n in ipairs(TAILS) do if not motors[n] then return nil end end
		if not chain or chainScale ~= model:GetScale() or chainClampX ~= clampX(model) then chain = buildChain(model, motors, hrp) end
		if not chain then return nil end
		local t = serverNow - grab.st
		local G = SC_GOALS[grab.side]
		local function target(M)
			local ref = model:FindFirstChild("TenoGrabTargetRef")
			local m = ref and ref:IsA("ObjectValue") and ref.Value
			if m and m.Parent then
				local cf, size = m:GetBoundingBox()
				return hrp.CFrame:PointToObjectSpace(cf.Position + Vector3.new(0, size.Y / 2, 0))
			end
			return grab.side == "front" and M.head + Vector3.new(0, 0, -10 * M.k) or M.rest + Vector3.new(0, 0, 5 * M.k)
		end
		if solKey ~= grab.st then -- a new grab: landmarks from this frame's pose
			solKey, sol = grab.st, nil
			local rest = fkClamp(motors, pose, nil)
			local hips, head = model:FindFirstChild("Torso_hips", true), model:FindFirstChild("Head_cranium", true)
			local hipsL = hips and hrp.CFrame:PointToObjectSpace(hips.Position) or Vector3.zero
			local headL = head and hrp.CFrame:PointToObjectSpace(head.Position) or Vector3.new(0, 0, -10)
			marks = {rest = rest, hips = hipsL, head = headL, k = math.max(0.1, (rest - hipsL).Magnitude / SC_LEN)}
			if grab.owner then -- the reach step
				local tg = target(marks)
				local _, miss = solveSc(motors, pose, tg, true, 10)
				sol = nil
				local want = Vector3.zero
				local over2 = miss - 0.5 * marks.k
				local flatL = Vector3.new(tg.X - hipsL.X, 0, tg.Z - hipsL.Z)
				if over2 > 0 and flatL.Magnitude > 1e-3 then
					want = hrp.CFrame:VectorToWorldSpace(flatL.Unit * math.min(over2, G.cap * marks.k))
				end
				model:SetAttribute("TenoGrabStepWant", want)
				model:SetAttribute("TenoGrabStepFor", grab.st)
			end
		end
		local M, k = marks, marks.k
		local P = function(v) return M.hips + v * k end
		local coil, carry, slam, rec = P(G.coil), P(G.carry), P(G.slam), P(G.rec)
		local W, S = grab.catch - SC_STRIKE, grab.throw - SC_SLAM_T
		local goal, w, tight = nil, 1, false
		if t < W then
			goal = M.rest:Lerp(coil, ease(t / math.max(0.05, W)))
			M.scCatch = nil
		elseif t < grab.catch then
			local u = clamp01((t - W) / SC_STRIKE)
			goal = bez(coil, coil + Vector3.new(0, 2 * k, G.dz * k), target(M), easeIn(u))
			tight = u > 0.7
			M.scCatch = nil
		elseif t < S then
			if not M.scCatch then M.scCatch = fkClamp(motors, pose, sol) end
			local u = smooth((t - grab.catch) / math.max(0.05, S - grab.catch))
			goal = bez(M.scCatch, M.scCatch:Lerp(carry, 0.5) + Vector3.new(0, 3 * k, 0), carry, u)
		elseif t < grab.throw then
			goal = carry:Lerp(slam, easeIn((t - S) / SC_SLAM_T))
		elseif t < grab.throw + GRAB_RECOVER then
			local u = (t - grab.throw) / GRAB_RECOVER
			goal = slam:Lerp(rec, smooth(u * 1.6))
			w = 1 - smooth(u)
		else
			return nil
		end
		local ang, miss = solveSc(motors, pose, goal, tight)
		return toOffsets(ang, w), miss
	end
end

return TenoPose
