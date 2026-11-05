-- TheriPose v1.9 (Mecha Dino Arena) — the Therizinosaurus' animation layers for IdleAnimation 1.39: the 3-hit claw combo
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
-- v1.2 (MDA-206, Kepu 2026-11-03): the Sidewinder drag fixed. Root cause: the run layer multiplied RUN_B on top of WalkPose's
--   run gait, but RUN_B (and the mockup's run motion) were made on a body without it: WalkPose folds both arms back by
--   RunArmTuck (35 degrees, plus RunArmSwing), so at full run the right claws rode behind and up (HRP-local tip
--   (-14.7, -3.6, 6.4) instead of (-14.7, -10.1, 1.2); measured in Play (-15, -2.7..-4.7, 6..8)), and its RunLean / neck /
--   tail motion stacked on RUN_B's hunch (the tucked left claws hung at the ground). Now, while the run layer plays, every
--   joint but the legs (RootJoint, Neck, Head, Jaw, Tail1-5, ArmL/R, ElbowL/R, WristL/R) blends from WalkPose's pose to the
--   rest pose by the run weight before the run layer is multiplied on, so the upper body is the mockup's run; the legs keep
--   WalkPose's world pose (LegL / LegR = (new RootJoint)^-1 * WalkPose's RootJoint * pose). Switch: model attribute
--   TheriRunOwnUpperEnabled (default true; false = 1.1). Drag reach: the run's body bob / roll lifted the right hand out of
--   the wrist's reach every other step (lowest tip 0.25 / 1.5 studs alternating); when the wrist leaves the tip more than
--   0.15 studs above TheriDragClearance, the same solver rolls ArmR (axis r, within +-25 degrees) to bring it down. Switch
--   TheriDragShoulderEnabled (default true); diagnostic TheriDragShoulder (degrees). Slopes: the solver measured the ground
--   under each tip once and kept it while the bend moved the tips 2-4 studs, so on a 14-degree ramp the claws went up to
--   0.94 studs into the slope; now the ground is measured again at every step (model attribute TheriClawRecastEnabled,
--   default true). Play check (TheriRunPoseEnabled true): lowest right tip flat 0.12-0.29 (255 frames), 14-degree ramp
--   0.01-0.29 (315), never under the ground, claws clear in a leap; left claws tucked ((6.2, -5.8, -18) vs the mockup's
--   (6.3, -4.5, -18.1)). TheriRunPoseEnabled defaults to true again (Kepu sees the run in Studio before any publish).
-- v1.3 (MDA-209, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 3; Kepu 2026-11-03 "Corkscrew", mockup
--   docs/mockups/therizino_spin_dive_v0.1.html style B): the leap is the Spin Dive. Push / air target = S_SCREW (body
--   stretched, neck forward, arms straight out; solved arm angles, tools/therizino_spin_poses_v0.1.json) instead of J_AIR
--   (J_CROUCH -> S_SCREW over 0.1 s, out; the down-rake into J_LAND before the touchdown and the landing are 1.2's), and the
--   whole body rolls about its own forward axis through the torso's middle: TheriSpinTurns (2) turns over TheriSpinAirTime
--   (0.6 s; the measured air time) after the lift-off, fast start and easing into exactly the full turns (it ends upright);
--   a landing before that finishes the roll in 0.12 s. The roll is a RootJoint rotation (the legs and tail turn with the
--   body), so the HRP and the physics do not turn. Switch: model attribute TheriSpinPoseEnabled (default true; false = 1.2's
--   Diving Rake). Diagnostic TheriSpinRoll (degrees, whole). Key S_SCREW joins KEYS (test hook / tip parity).
-- v1.4 (MDA-213, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 7; mockup docs/mockups/therizino_fourth_cut_v0.1.html, Kepu
--   2026-11-03 picked "C" Ground Scythe): combo step 4 (the Fourth Cut, TheriAttackTest / TheriAttackServer 1.2). Key SCYTHE
--   = J_LAND's crouch (RootJoint, Neck, Head, legs) with the arms out and angled down (the mockup's S_TORNADO arms), jaw open,
--   tail dragged sideways. Step 4: 0 the target at the tap, 0.1 SCYTHE (out), 0.16 SCYTHE (in2), 0.62 SCYTHE (lin), 0.72
--   CHOP_SET (out), 1.25 READY (io). Whole-body yaw (degrees, about the vertical through the HumanoidRootPart, applied to the
--   RootJoint like 1.3's roll: the HRP and the physics do not turn): 0, 0.1 +25 (out), 0.16 0 (in2), 0.62 -700 (lin), 0.72 -720
--   (out) = two full turns, ending facing forward. With the model attribute TheriFourthFast (Fourth Cut star) step 4 plays
--   x FOURTH_FAST_MUL (1.5) faster. Switch: model attribute TheriFourthPoseEnabled (default true; false = step 4 is ignored, as
--   1.3). Diagnostic TheriFourthYaw (degrees).
-- v1.5 (MDA-204, plan docs/plans/THERIZINO_KIT_v1.0.md Task 7; mockups docs/mockups/therizino_kit_options_v0.3.html onHit and
--   docs/mockups/therizino_fourth_cut_v0.1.html onHit): hit-stop on your own therizino. When TheriHitAt changes (TheriAttackServer:
--   a cut resolved) with TheriHitTargets not empty and TheriHitStep = the step this client is playing, the combo layer's clock
--   runs at HIT_STOP_RATE (0.04) for HIT_STOP[step] seconds (steps 1 / 2: 0.08, 3: 0.15, 4: 0.06): the step time (and the
--   Fourth Cut's yaw time) loses that much and the combo springs step with dt x 0.04, so the claws hang in the target for a
--   beat. The lost time belongs to that step only (a new step starts from its own stamp). Only the owner (ctx.isOwner); other
--   clients and the run / leap layers are untouched. Switch: model attribute TheriHitStopEnabled (default true; false = 1.4).
--   Diagnostic TheriHitStops (count, this client).
-- v1.6 (MDA-245, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 5; Kepu 2026-11-04 "Add the animations first"): a mecha-parts
--   layer for build 1, multiplied onto the pose BEFORE the combo / run / leap layers (TheriPose.top is wrapped), with the
--   picked looks' poses from docs/mockups/therizino_parts_options.html v0.1 (tools/mockup/therizino_parts_app.js, same angles,
--   same {p, y, r} convention): Reaper's Hook C "Back Crane" HOOK_AIM {RootJoint -4, Neck -10}; Feather Barrage A "Arm Racks"
--   FEATHER_PRE {ArmL 40 60 40, ArmR 40 -60 -40, RootJoint 4} then SWEEP {ArmL 55 -50 -30, ArmR 55 50 30, RootJoint -4};
--   Harvest Field B "Arm Pistons" ARMS_UP {ArmL 75 30 25, ArmR 75 -30 -25, RootJoint 6, Neck 8} then STAB (crouch: RootJoint
--   -22, Neck -14, Head -8, arms -10 0 +-10, legs 22, knees -30, ankles 10, Tail1 -14); Snare Wires A "Tail Spools" TAIL_FLICK
--   {Tail1..5 -30 -30 -25 -20 -15, RootJoint -8}. Clocks (server stamps, every client): t = server now - <Prefix>At.
--   Hook (TheriHookAt): 0 -> 0.15 HOOK_AIM (io), held to 0.15 + TheriHookPullTime + 0.2, out over 0.3 (io).
--   Feather (TheriFeatherAt): 0 -> 0.12 FEATHER_PRE (io), -> 0.24 SWEEP (out), held to 0.6, out by 1.0 (io).
--   Field (TheriFieldAt): 0 -> 0.2 ARMS_UP (io), -> 0.35 STAB (in2), held while the field lasts (TheriFieldUntil) and the
--   body is not moving (flat HRP speed < 6 studs/s; once it moves the hold ends), out over 0.4 (io).
--   Snare (TheriSnareAt): 0 -> 0.25 TAIL_FLICK (io), held to 0.6, out by 1.0 (io).
--   The newest stamp wins (one part pose at a time). While the layer weighs, a ground lock (1.0's foot rule, this layer's own
--   smoothing) keeps the feet on the ground for STAB's crouch. Switch: model attribute TheriPartsPoseEnabled (default true;
--   false = 1.5). Diagnostics: TheriPartsPose ("none" / "hook" / "feather" / "field" / "snare"), TheriPartsPoseWeight.
-- v1.7 (therizino parts build 2, MDA-248, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 8; mockup v0.1, looks 12-C / 16-A):
--   two more poses in the parts layer: Grapple Zip (TheriGrappleAt, result "zip"): 0 -> 0.12 GRAPPLE_AIM {RootJoint -6} (io),
--   then the zip pose ARMS_FWD + legs tucked {LegL -30, LegR -20, KneeL -50, KneeR -60, RootJoint -18, Tail1 10} (0.12 s, io)
--   held to 0.12 + TheriGrappleTime, then ARMS_FWD out over 0.3 (io). Deflector Claws (TheriDeflectAt): ARMS_FWD {ArmL 62 0 8,
--   ArmR 62 0 -8, RootJoint -6} in over 0.15 (io), held to TheriDeflectUntil, out over 0.4 (io). Overclock Joints has no pose
--   (the run plays). The newest of all six stamps wins. Same switch TheriPartsPoseEnabled.
-- v1.8 (therizino moves rework, plan docs/plans/THERIZINO_MOVES_REWORK_v1.0.md, MDA-264; TheriMovesServer 1.4): a rework layer
--   multiplied on before the 1.7 parts layer, with the storyboard's poses and times (tools/mockup/therizino_moves_anim.js v0.3,
--   same {p, y, r}); t = server now - the stamp, the newest of the four plays:
--   Vortex (TheriVortexAt): ARMS_UP in 0..0.4 (io), VORTEX (STAB with the arms {-14, +-12, +-18}) 0.4..0.52 (in2), held while
--     the vortex lasts (TheriFieldUntil) and the body stands (flat speed < 6), out over 0.4 (io).
--   Bola (TheriBolaAt): BOLA_WIND 0..0.45 (io), BOLA_THROW 0.45..0.6 (out), out 0.9..1.5 (io).
--   Dash (TheriDashAt, result "dash"): DODGE 0.02..0.14 (out), SKID 0.42..0.6 (out), out 0.75..1.2 (io).
--   Reel (TheriReelAt): HOOK_SET 0..brace (io); "hit": REEL from brace + fly - 0.02 over 0.12 (io), SLASH from end - 0.02 over
--     0.14 (out) (end = brace + fly + TheriReelTime), out end + 0.25..end + 0.8 (io); otherwise HOOK_SET held to brace + 2 x
--     fly, out over 0.4 (io).
--   Its own ground lock (the crouches of VORTEX / DODGE / SKID / REEL / SLASH) as 1.6's. Switch: model attribute
--   TheriReworkPoseEnabled (default true). Diagnostics: TheriReworkPose ("none" / "vortex" / "bola" / "dash" / "reel"),
--   TheriReworkPoseWeight.
-- v1.9 (bug, Kepu 2026-11-04 18:03, with IdleAnimation 1.44): the Diving Rake's air-phase probe (when the down-rake starts)
--   also ignores other dinos (every player's character, DinoIsland.Bots, the FX folders) while JumpProbeIgnoreDinosEnabled
--   ~= false, so a latched raptor under the body does not start the rake early.
local TheriPose = {}
TheriPose.Version = "1.3"
TheriPose.Version = "1.4" -- v1.4 Fourth Cut (Ground Scythe)
TheriPose.Version = "1.5" -- v1.5 hit-stop (MDA-204)
TheriPose.Version = "1.6" -- v1.6 mecha-parts poses (build 1)
TheriPose.Version = "1.7" -- v1.7 grapple + deflect poses (build 2)
TheriPose.Version = "1.8" -- v1.8 moves rework poses (vortex, bola, dash, reel)
TheriPose.Version = "1.9" -- v1.9 leap probe ignores other dinos
TheriPose.Defaults = {
	TheriPoseEnabled = true, TheriRunPoseEnabled = true, TheriLeapPoseEnabled = true, TheriGroundLockEnabled = true,
	TheriDragEnabled = true, TheriChainHold = 0.8, TheriFadeTime = 0.5, TheriLeapLandTime = 1.4, TheriDragClearance = 0.15,
	TheriClawFloorEnabled = true, TheriClawFloor = 0.1,
	TheriRunOwnUpperEnabled = true, TheriDragShoulderEnabled = true, -- v1.2
	TheriSpinPoseEnabled = true, TheriSpinTurns = 2, TheriSpinAirTime = 0.6, -- v1.3
	TheriFourthPoseEnabled = true, -- v1.4
	TheriHitStopEnabled = true, -- v1.5
}
local LEG_JOINTS = {LegL = true, LegR = true, KneeL = true, KneeR = true, AnkleL = true, AnkleR = true} -- v1.2

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
KEYS.S_SCREW = {RootJoint = {-10, 0, 0}, Neck = {-50, 0, 0}, Head = {30, 0, 0}, Jaw = {-16, 0, 0}, ArmL = {43, -20, -41},
	WristL = {18, 0, 0}, ArmR = {43, 20, 41}, WristR = {18, 0, 0}, Tail1 = {-8, 0, 0}, LegL = {-20, 0, 0}, LegR = {-20, 0, 0},
	KneeL = {-30, 0, 0}, KneeR = {-30, 0, 0}} -- v1.3: the Corkscrew body (mockup v0.1 B)
KEYS.SCYTHE = {RootJoint = {-32, 0, 0}, Neck = {-20, 0, 0}, Head = {-8, 0, 0}, Jaw = {-14, 0, 0}, ArmL = {45, -42, -11},
	ElbowL = {0, 0, 0}, WristL = {22, 0, 0}, ArmR = {45, 42, 11}, ElbowR = {0, 0, 0}, WristR = {22, 0, 0}, Tail1 = {-4, 12, 0},
	Tail2 = {0, 16, 0}, Tail3 = {0, 20, 0}, Tail4 = {0, 22, 0}, Tail5 = {0, 24, 0}, LegL = {36, 0, 0}, LegR = {36, 0, 0},
	KneeL = {-64, 0, 0}, KneeR = {-64, 0, 0}, AnkleL = {26, 0, 0}, AnkleR = {26, 0, 0}} -- v1.4: Ground Scythe (mockup C)
KEYS.ZERO = {}
TheriPose.KEYS = KEYS

local STEPS = {
	{{0, "READY"}, {0.22, "R_W", "io"}, {0.29, "R_S", "in2"}, {0.41, "R_F", "out"}, {0.75, "READY", "io"}},
	{{0, "$from"}, {0.19, "L_W", "io"}, {0.26, "L_S", "in2"}, {0.38, "L_F", "out"}, {0.75, "READY", "io"}},
	{{0, "$from"}, {0.34, "REAR", "io"}, {0.46, "REAR2", "io"}, {0.55, "CHOP", "in"}, {0.81, "CHOP_SET", "out"},
		{1.36, "READY", "io"}},
}
local TREMBLE = {0.34, 0.46} -- step 3
STEPS[4] = {{0, "$from"}, {0.1, "SCYTHE", "out"}, {0.16, "SCYTHE", "in2"}, {0.62, "SCYTHE", "lin"}, {0.72, "CHOP_SET", "out"},
	{1.25, "READY", "io"}} -- v1.4: the Fourth Cut
local YAW4 = {{0, 0}, {0.1, 25, "out"}, {0.16, 0, "in2"}, {0.62, -700, "lin"}, {0.72, -720, "out"}} -- v1.4 (degrees)
local FOURTH_FAST_MUL = 1.5 -- v1.4: Fourth Cut star
local HIT_STOP, HIT_STOP_RATE = {0.08, 0.08, 0.15, 0.06}, 0.04 -- v1.5 (seconds by step; clock rate)
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
local leapS = {springs = newSprings(kitK), w = 0, lockW = 0, fwd = 0, phase = "none", lastAt = -math.huge, landFrom = nil,
	roll = 0, rollAtLand = nil} -- v1.3: roll (radians) of the Spin Dive
local spinPivot -- v1.3: the torso's middle in the RootJoint pose frame (studs)
local lockSmooth = 0
local hitStop = {seen = nil, left = 0, lag = 0, at = nil, n = 0} -- v1.5
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
		if s.TheriSpinPoseEnabled then -- v1.3: the Corkscrew body
			tg = mixP(keyPose("J_CROUCH"), keyPose("S_SCREW"), EASE.out(clamp(x / 0.1, 0, 1)))
		else
			tg = mixP(keyPose("J_CROUCH"), keyPose("J_AIR"), EASE.out(clamp(x / 0.19, 0, 1)))
		end
		w, lock = 1, phase == "push" and 1 or 0
		if phase == "air" then
			local vy = hrp.AssemblyLinearVelocity.Y
			local hum = model:FindFirstChildOfClass("Humanoid")
			local base = hrp.Size.Y / 2 + (hum and hum.HipHeight or 0)
			rayParams.FilterDescendantsInstances = {model}
			if model:GetAttribute("JumpProbeIgnoreDinosEnabled") ~= false then -- v1.9: a latched raptor is not the ground
				local ex = {model}
				for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do if pl.Character and pl.Character ~= model then table.insert(ex, pl.Character) end end
				local isl = workspace:FindFirstChild("DinoIsland")
				local bots = isl and isl:FindFirstChild("Bots")
				if bots then table.insert(ex, bots) end
				for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX"}) do
					local f = workspace:FindFirstChild(n)
					if f then table.insert(ex, f) end
				end
				rayParams.FilterDescendantsInstances = ex
			end
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
	-- v1.3: the Spin Dive roll
	local full = 2 * math.pi * (tonumber(s.TheriSpinTurns) or 2)
	if s.TheriSpinPoseEnabled and phase == "air" then
		local u = clamp(x / max(0.05, s.TheriSpinAirTime), 0, 1)
		leapS.roll, leapS.rollAtLand = full * (1 - (1 - u) ^ 2.2), nil
	elseif s.TheriSpinPoseEnabled and phase == "land" then
		leapS.rollAtLand = leapS.rollAtLand or leapS.roll
		local r0 = leapS.rollAtLand
		leapS.roll = (r0 > 0.01 and r0 < full - 0.01) and (r0 + (full - r0) * EASE.out(clamp(x / 0.12, 0, 1))) or 0
	else
		leapS.roll, leapS.rollAtLand = 0, nil
	end
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
	local roll = leapS.roll % (2 * math.pi)
	if roll > 1e-3 and roll < 2 * math.pi - 1e-3 and cfs.RootJoint then -- v1.3: roll about the body's forward axis (+X)
		local sc = model:IsA("Model") and model:GetScale() or 1
		if spinPivot and spinPivot.scale ~= sc then spinPivot = nil end
		if not spinPivot then
			local torso = model:FindFirstChild("Torso")
			local root = torso and torso:FindFirstChild("Root")
			local sum, n = Vector3.zero, 0
			for _, p in ipairs(root and torso:GetDescendants() or {}) do
				if p:IsA("BasePart") and p ~= root then sum += root.CFrame:PointToObjectSpace(p.Position); n += 1 end
			end
			spinPivot = {p = n > 0 and Vector3.new(0, sum.Y / n, sum.Z / n) or Vector3.zero, scale = sc}
		end
		cfs.RootJoint = CFrame.new(spinPivot.p) * CFrame.Angles(roll, 0, 0) * CFrame.new(-spinPivot.p) * cfs.RootJoint
	end
	local rd = math.floor(math.deg(roll) + 0.5)
	if model:GetAttribute("TheriSpinRoll") ~= rd then model:SetAttribute("TheriSpinRoll", rd) end
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
local function solveWrist(motors, hrpCF, pose, side, target, liftOnly, weight, model, joint, axis, limit)
	local chain, wrist = fk["Hand" .. side], joint or ("Wrist" .. side)
	axis, limit = axis or 1, limit or 45
	local function ang(b) local v = {0, 0, 0}; v[axis] = b; return rot(v) end
	if not chain or not motors[wrist] or #chain.tips == 0 then return nil, 0 end
	rayParams.FilterDescendantsInstances = {model}
	local ground = {}
	local s12 = model:GetAttribute("TheriClawRecastEnabled") ~= false -- v1.2
	local function gapOf(first)
		local cf = chainCF(motors, hrpCF, chain, pose)
		local g = math.huge
		for i, tip in ipairs(chain.tips) do
			local p = cf * tip
			if first or s12 then -- v1.2: the ground is measured again under the tip's new spot (bends move tips 2-4 studs)
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
		pose[wrist] = base * ang(b + 4)
		local slope = (gapOf(false) - gap) / 4
		if math.abs(slope) < 0.005 then break end
		b = clamp(b - clamp(err / slope, -20, 20), -limit, limit)
		pose[wrist] = base * ang(b)
		gap = gapOf(false)
	end
	pose[wrist] = base * ang(b * weight)
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
	if st == 4 and not s.TheriFourthPoseEnabled then st = 0 end -- v1.4
	if st >= 1 and st <= 4 and at and (st ~= combo.step or at ~= combo.at) then
		combo.from = combo.target or keyPose("ZERO")
		combo.step, combo.at = st, at
	elseif st == 0 and combo.step ~= 0 then
		combo.step, combo.at = 0, nil
	end
	-- v1.5: hit-stop (owner only; see the header)
	local hsRate, hsLag = 1, 0
	do
		local ha = num(model:GetAttribute("TheriHitAt"))
		if hitStop.seen == nil then hitStop.seen = ha or -1 end
		if ha and ha ~= hitStop.seen then
			hitStop.seen = ha
			local hst = num(model:GetAttribute("TheriHitStep"))
			local tgs = model:GetAttribute("TheriHitTargets")
			if s.TheriHitStopEnabled and ctx.isOwner and combo.step ~= 0 and combo.at and hst and math.floor(hst) == combo.step
				and typeof(tgs) == "string" and tgs ~= "" then
				if hitStop.at ~= combo.at then hitStop.at, hitStop.lag = combo.at, 0 end
				hitStop.left = HIT_STOP[combo.step] or 0
				hitStop.n += 1
			end
		end
		if hitStop.at ~= combo.at then hitStop.left = 0 end
		if hitStop.left > 0 then
			hitStop.lag += min(ctx.dt, hitStop.left) * (1 - HIT_STOP_RATE)
			hitStop.left -= ctx.dt
			hsRate = HIT_STOP_RATE
		end
		if hitStop.at == combo.at and combo.at then hsLag = hitStop.lag end
		show("TheriHitStops", hitStop.n)
	end
	local tg, cw = nil, 0
	if combo.step ~= 0 then
		local ct = max(0, ctx.serverNow - combo.at - hsLag) -- v1.5: - hsLag (0 without a hit-stop)
		if combo.step == 4 and model:GetAttribute("TheriFourthFast") == true then ct *= FOURTH_FAST_MUL end -- v1.4
		tg, cw = comboTarget(s, ct, ctx.now)
		if not tg then combo.step, combo.at = 0, nil end
	end
	combo.target, combo.w = tg, cw
	local cOut
	if tg or not combo.springs.settled then
		cOut = springStep(combo.springs, tg or keyPose("ZERO"), ctx.dt * hsRate, false) -- v1.5: x hsRate (1 without a hit-stop)
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
		local own = s.TheriRunOwnUpperEnabled and rw or 0 -- v1.2: the run layer takes the upper body over from WalkPose's run
		for n, v in pairs(rOut.a) do
			if motors[n] and n ~= "RootJoint" then
				local base = pose[n] or CFrame.identity
				if own > 0 and not LEG_JOINTS[n] then base = base:Lerp(CFrame.identity, own) end
				pose[n] = base * rot(v)
			end
		end
		local E = rot(rOut.a.RootJoint)
		local Wr = pose.RootJoint or CFrame.identity
		local Wl = own > 0 and Wr:Lerp(CFrame.identity, own) or Wr
		if motors.RootJoint then pose.RootJoint = Wl * E end
		local back = (Wl * E):Inverse() * Wr -- the legs keep WalkPose's world pose
		for _, n in ipairs({"LegL", "LegR"}) do
			if motors[n] then pose[n] = back * (pose[n] or CFrame.identity) end
		end
	end
	if cOut then
		for n, v in pairs(cOut.a) do
			if motors[n] then pose[n] = (pose[n] or CFrame.identity) * rot(v) end
		end
	end
	-- v1.4: the Fourth Cut's whole-body yaw (about the vertical through the HRP), on top of the combo pose
	local yaw4 = 0
	if combo.step == 4 and combo.at and motors.RootJoint then
		local t4 = max(0, ctx.serverNow - combo.at - hsLag) -- v1.5: - hsLag
		if model:GetAttribute("TheriFourthFast") == true then t4 *= FOURTH_FAST_MUL end
		yaw4 = YAW4[#YAW4][2]
		for i = 2, #YAW4 do
			if t4 <= YAW4[i][1] then
				local a, b = YAW4[i - 1], YAW4[i]
				yaw4 = a[2] + (b[2] - a[2]) * EASE[b[3] or "io"]((t4 - a[1]) / (b[1] - a[1]))
				break
			end
		end
		local c0 = motors.RootJoint.restC0
		pose.RootJoint = c0:Inverse() * CFrame.Angles(0, rad(yaw4), 0) * c0 * (pose.RootJoint or CFrame.identity)
	end
	show("TheriFourthYaw", math.floor(yaw4 + 0.5))
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
		local shoulder = 0
		if s.TheriDragShoulderEnabled and gap and gap > s.TheriDragClearance + 0.15 then -- v1.2: out of the wrist's reach
			gap, shoulder = solveWrist(motors, hrpCF, pose, "R", s.TheriDragClearance, false, min(1, rw), model, "ArmR", 3, 25)
		end
		show("TheriDragGap", gap and math.floor(gap * 100 + 0.5) / 100 or -1)
		show("TheriDragBend", math.floor((bend or 0) + 0.5))
		show("TheriDragShoulder", math.floor((shoulder or 0) + 0.5))
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

-- v1.6: mecha-parts poses (see the header) -------------------------------------------------------------------------------
do
	local P = {
		HOOK_AIM = {RootJoint = {-4, 0, 0}, Neck = {-10, 0, 0}},
		FEATHER_PRE = {ArmL = {40, 60, 40}, ArmR = {40, -60, -40}, RootJoint = {4, 0, 0}},
		SWEEP = {ArmL = {55, -50, -30}, ArmR = {55, 50, 30}, RootJoint = {-4, 0, 0}},
		ARMS_UP = {ArmL = {75, 30, 25}, ArmR = {75, -30, -25}, RootJoint = {6, 0, 0}, Neck = {8, 0, 0}},
		STAB = {ArmL = {-10, 0, 10}, ArmR = {-10, 0, -10}, RootJoint = {-22, 0, 0}, Neck = {-14, 0, 0}, Head = {-8, 0, 0},
			LegL = {22, 0, 0}, LegR = {22, 0, 0}, KneeL = {-30, 0, 0}, KneeR = {-30, 0, 0}, AnkleL = {10, 0, 0}, AnkleR = {10, 0, 0},
			Tail1 = {-14, 0, 0}},
		TAIL_FLICK = {Tail1 = {-30, 0, 0}, Tail2 = {-30, 0, 0}, Tail3 = {-25, 0, 0}, Tail4 = {-20, 0, 0}, Tail5 = {-15, 0, 0},
			RootJoint = {-8, 0, 0}},
		GRAPPLE_AIM = {RootJoint = {-6, 0, 0}}, -- v1.7
		ARMS_FWD = {ArmL = {62, 0, 8}, ArmR = {62, 0, -8}, RootJoint = {-6, 0, 0}},
		ZIP = {ArmL = {62, 0, 8}, ArmR = {62, 0, -8}, LegL = {-30, 0, 0}, LegR = {-20, 0, 0}, KneeL = {-50, 0, 0}, KneeR = {-60, 0, 0},
			RootJoint = {-18, 0, 0}, Tail1 = {10, 0, 0}},
	}
	local ZERO = {}
	local function mix(A, B, u)
		local o = {}
		for n, v in pairs(A) do o[n] = v end
		for n in pairs(B) do o[n] = o[n] or {0, 0, 0} end
		for n, a in pairs(o) do
			local b = B[n] or {0, 0, 0}
			local aa = A[n] or {0, 0, 0}
			o[n] = {aa[1] + (b[1] - aa[1]) * u, aa[2] + (b[2] - aa[2]) * u, aa[3] + (b[3] - aa[3]) * u}
		end
		return o
	end
	local function ease(name, u) return EASE[name](clamp(u, 0, 1)) end
	local states = setmetatable({}, {__mode = "k"}) -- [model] = {moved = at, lock = 0}
	local function stamp(model, k) local v = model:GetAttribute(k) return typeof(v) == "number" and v or nil end
	-- the target pose and its name for the newest part stamp; nil when nothing plays
	local function partsTarget(model, serverNow, st, hrp)
		local best, bestAt
		local ATTR = {hook = "TheriHookAt", feather = "TheriFeatherAt", field = "TheriFieldAt", snare = "TheriSnareAt",
			grapple = "TheriGrappleAt", deflect = "TheriDeflectAt"} -- v1.7: + grapple, deflect
		for _, k in ipairs({"hook", "feather", "field", "snare", "grapple", "deflect"}) do
			local at = stamp(model, ATTR[k])
			if at and serverNow - at >= 0 and serverNow - at < 12 and (not bestAt or at > bestAt) then best, bestAt = k, at end
		end
		if not best then return nil end
		local t = serverNow - bestAt
		if best == "hook" then
			if model:GetAttribute("TheriHookResult") == nil then return nil end
			local hold = 0.15 + (stamp(model, "TheriHookPullTime") or 0) + 0.2
			if t < 0.15 then return mix(ZERO, P.HOOK_AIM, ease("io", t / 0.15)), best end
			if t < hold then return P.HOOK_AIM, best end
			if t < hold + 0.3 then return mix(P.HOOK_AIM, ZERO, ease("io", (t - hold) / 0.3)), best end
		elseif best == "feather" then
			if t < 0.12 then return mix(ZERO, P.FEATHER_PRE, ease("io", t / 0.12)), best end
			if t < 0.24 then return mix(P.FEATHER_PRE, P.SWEEP, ease("out", (t - 0.12) / 0.12)), best end
			if t < 0.6 then return P.SWEEP, best end
			if t < 1.0 then return mix(P.SWEEP, ZERO, ease("io", (t - 0.6) / 0.4)), best end
		elseif best == "field" then
			if t < 0.2 then return mix(ZERO, P.ARMS_UP, ease("io", t / 0.2)), best end
			if t < 0.35 then return mix(P.ARMS_UP, P.STAB, ease("in2", (t - 0.2) / 0.15)), best end
			local untilT = stamp(model, "TheriFieldUntil") or (bestAt + 3)
			local v = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
			if st.fieldAt ~= bestAt then st.fieldAt, st.fieldEnd = bestAt, nil end
			if not st.fieldEnd and (serverNow >= untilT or Vector3.new(v.X, 0, v.Z).Magnitude >= 6) then st.fieldEnd = serverNow end
			if not st.fieldEnd then return P.STAB, best end
			local u = (serverNow - st.fieldEnd) / 0.4
			if u < 1 then return mix(P.STAB, ZERO, ease("io", u)), best end
		elseif best == "grapple" then -- v1.7
			if model:GetAttribute("TheriGrappleResult") ~= "zip" then return nil end
			local zt = stamp(model, "TheriGrappleTime") or 0.5
			if t < 0.12 then return mix(ZERO, P.GRAPPLE_AIM, ease("io", t / 0.12)), best end
			if t < 0.24 then return mix(P.GRAPPLE_AIM, P.ZIP, ease("io", (t - 0.12) / 0.12)), best end
			if t < 0.12 + zt then return P.ZIP, best end
			if t < 0.12 + zt + 0.12 then return mix(P.ZIP, P.ARMS_FWD, ease("io", (t - 0.12 - zt) / 0.12)), best end
			if t < 0.12 + zt + 0.42 then return mix(P.ARMS_FWD, ZERO, ease("io", (t - 0.24 - zt) / 0.3)), best end
		elseif best == "deflect" then -- v1.7
			local untilT = stamp(model, "TheriDeflectUntil") or (bestAt + 1)
			local hold = untilT - bestAt
			if t < 0.15 then return mix(ZERO, P.ARMS_FWD, ease("io", t / 0.15)), best end
			if t < hold then return P.ARMS_FWD, best end
			if t < hold + 0.4 then return mix(P.ARMS_FWD, ZERO, ease("io", (t - hold) / 0.4)), best end
		else
			if t < 0.25 then return mix(ZERO, P.TAIL_FLICK, ease("io", t / 0.25)), best end
			if t < 0.6 then return P.TAIL_FLICK, best end
			if t < 1.0 then return mix(P.TAIL_FLICK, ZERO, ease("io", (t - 0.6) / 0.4)), best end
		end
		return nil
	end
	local topV15 = TheriPose.top
	function TheriPose.top(model, pose, motors, hrp, ctx)
		local show = ctx.show
		local st = states[model]
		if not st then
			st = {lock = 0}
			states[model] = st
		end
		local tg, name
		if model:GetAttribute("TheriPartsPoseEnabled") ~= false and model:GetAttribute("TheriPoseTestKey") == nil then
			tg, name = partsTarget(model, ctx.serverNow, st, hrp)
		end
		if tg then
			for n, v in pairs(tg) do
				if motors[n] then pose[n] = (pose[n] or CFrame.identity) * rot(v) end
			end
		end
		show("TheriPartsPose", name or "none")
		topV15(model, pose, motors, hrp, ctx)
		-- the layer's own ground lock (STAB crouches)
		local want = (tg and name == "field") and 1 or 0
		st.lock += (want - st.lock) * min(1, ctx.dt * 20)
		if st.lock < 0.001 then st.lock = 0 end
		show("TheriPartsPoseWeight", math.floor(st.lock * 10 + 0.5) / 10)
		local rj = motors.RootJoint
		if st.lock > 0 and rj and hrp and model:GetAttribute("TheriGroundLockEnabled") ~= false and ensureFK(model, motors, hrp) then
			local sc = model:IsA("Model") and model:GetScale() or 2
			local hrpCF = hrp.CFrame
			local d = footLow(motors, hrpCF, {}) - footLow(motors, hrpCF, pose)
			local up = clamp(d, -3 * sc / 2, 3 * sc / 2) * st.lock
			if math.abs(up) > 1e-3 then
				local v = hrpCF:VectorToObjectSpace(Vector3.new(0, up, 0))
				pose.RootJoint = CFrame.new(rj.restC0.Rotation:Inverse() * v) * (pose.RootJoint or CFrame.identity)
			end
		end
	end
end

-- v1.8: the moves rework poses (see the header) -------------------------------------------------------------------------------
do
	local STAB = {ArmL = {-10, 0, 10}, ArmR = {-10, 0, -10}, RootJoint = {-22, 0, 0}, Neck = {-14, 0, 0}, Head = {-8, 0, 0},
		LegL = {22, 0, 0}, LegR = {22, 0, 0}, KneeL = {-30, 0, 0}, KneeR = {-30, 0, 0}, AnkleL = {10, 0, 0}, AnkleR = {10, 0, 0},
		Tail1 = {-14, 0, 0}}
	local VORTEX = table.clone(STAB)
	VORTEX.ArmL, VORTEX.ArmR = {-14, 12, 18}, {-14, -12, -18}
	local P = {
		ARMS_UP = {ArmL = {75, 30, 25}, ArmR = {75, -30, -25}, RootJoint = {6, 0, 0}, Neck = {8, 0, 0}, Tail1 = {-6, 0, 0}},
		VORTEX = VORTEX,
		BOLA_WIND = {RootJoint = {-6, 18, 0}, Neck = {0, -14, 0}, Tail1 = {-6, -22, 0}, Tail2 = {-6, -24, 0}, Tail3 = {-4, -26, 0},
			Tail4 = {0, -26, 0}, Tail5 = {4, -26, 0}, LegL = {8, 0, 0}, KneeL = {-14, 0, 0}},
		BOLA_THROW = {RootJoint = {-10, -16, 0}, Neck = {-4, 16, 0}, Tail1 = {-18, 26, 0}, Tail2 = {-18, 30, 0}, Tail3 = {-14, 30, 0},
			Tail4 = {-10, 28, 0}, Tail5 = {-6, 26, 0}, LegR = {10, 0, 0}, KneeR = {-16, 0, 0}},
		DODGE = {RootJoint = {-14, 0, 16}, LegL = {36, 0, 0}, LegR = {26, 0, 0}, KneeL = {-62, 0, 0}, KneeR = {-52, 0, 0},
			AnkleL = {22, 0, 0}, AnkleR = {18, 0, 0}, ArmL = {34, 0, 16}, ArmR = {34, 0, -16}, Neck = {-6, 0, -10}, Tail1 = {8, 0, -10},
			Tail2 = {6, 0, -8}},
		SKID = {RootJoint = {-6, 0, 6}, LegL = {18, 0, 0}, LegR = {-10, 0, 0}, KneeL = {-30, 0, 0}, KneeR = {-20, 0, 0},
			ArmL = {20, 0, 10}, ArmR = {20, 0, -10}},
		HOOK_SET = {RootJoint = {-6, 0, 0}, Neck = {-14, 0, 0}, ArmL = {40, 0, 40}, ArmR = {40, 0, -40}, LegL = {12, 0, 0},
			LegR = {-6, 0, 0}, KneeL = {-20, 0, 0}, KneeR = {-10, 0, 0}},
		REEL = {RootJoint = {-20, 0, 0}, Neck = {-10, 0, 0}, ArmL = {100, -20, 20}, ArmR = {100, 20, -20}, LegL = {48, 0, 0},
			LegR = {36, 0, 0}, KneeL = {-74, 0, 0}, KneeR = {-62, 0, 0}, AnkleL = {24, 0, 0}, AnkleR = {20, 0, 0}, Tail1 = {12, 0, 0},
			Tail2 = {8, 0, 0}},
		SLASH = {RootJoint = {-26, 0, 0}, Neck = {-16, 0, 0}, Head = {-6, 0, 0}, ArmL = {-24, 30, 34}, ArmR = {-24, -30, -34},
			LegL = {26, 0, 0}, LegR = {-8, 0, 0}, KneeL = {-38, 0, 0}, KneeR = {-16, 0, 0}, Tail1 = {-10, 0, 0}},
	}
	local ZERO = {}
	local function mix(A, B, u)
		local o = {}
		for n in pairs(A) do o[n] = true end
		for n in pairs(B) do o[n] = true end
		local r = {}
		for n in pairs(o) do
			local a, b = A[n] or {0, 0, 0}, B[n] or {0, 0, 0}
			r[n] = {a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u}
		end
		return r
	end
	local function seg(t, a, b) return clamp((t - a) / (b - a), 0, 1) end
	local function e(name, u) return EASE[name](clamp(u, 0, 1)) end
	local function stamp(model, k) local v = model:GetAttribute(k) return typeof(v) == "number" and v or nil end
	local states = setmetatable({}, {__mode = "k"})
	local CROUCH = {vortex = true, dash = true, reel = true}
	local function target(model, serverNow, st, hrp)
		local best, bestAt
		for k, attr in pairs({vortex = "TheriVortexAt", bola = "TheriBolaAt", dash = "TheriDashAt", reel = "TheriReelAt"}) do
			local at = stamp(model, attr)
			if at and serverNow - at >= 0 and serverNow - at < 12 and (not bestAt or at > bestAt) then best, bestAt = k, at end
		end
		if not best then return nil end
		local t = serverNow - bestAt
		if best == "vortex" then
			local A = mix(ZERO, P.ARMS_UP, e("io", t / 0.4))
			A = mix(A, P.VORTEX, e("in2", seg(t, 0.4, 0.52)))
			if t < 0.52 then return A, best end
			local untilT = stamp(model, "TheriFieldUntil") or (bestAt + 4)
			local v = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
			if st.vAt ~= bestAt then st.vAt, st.vEnd = bestAt, nil end
			if not st.vEnd and (serverNow >= untilT or Vector3.new(v.X, 0, v.Z).Magnitude >= 6) then st.vEnd = serverNow end
			if not st.vEnd then return P.VORTEX, best end
			local u = (serverNow - st.vEnd) / 0.4
			if u < 1 then return mix(P.VORTEX, ZERO, e("io", u)), best end
		elseif best == "bola" then
			if t >= 1.5 then return nil end
			local A = mix(ZERO, P.BOLA_WIND, e("io", t / 0.45))
			A = mix(A, P.BOLA_THROW, e("out", seg(t, 0.45, 0.6)))
			if t > 0.9 then A = mix(A, ZERO, e("io", seg(t, 0.9, 1.5))) end
			return A, best
		elseif best == "dash" then
			if model:GetAttribute("TheriDashResult") ~= "dash" or t >= 1.2 then return nil end
			local A = mix(ZERO, P.DODGE, e("out", seg(t, 0.02, 0.14)))
			if t > 0.42 then A = mix(A, P.SKID, e("out", seg(t, 0.42, 0.6))) end
			if t > 0.75 then A = mix(A, ZERO, e("io", seg(t, 0.75, 1.2))) end
			return A, best
		else
			local brace = stamp(model, "TheriReelBrace") or 0.3
			local fly = stamp(model, "TheriReelFly") or 0.2
			local A = mix(ZERO, P.HOOK_SET, e("io", t / brace))
			if model:GetAttribute("TheriReelResult") == "hit" or model:GetAttribute("TheriReelResult") == "missed" then
				local finish = brace + fly + (stamp(model, "TheriReelTime") or 0.5)
				if t >= finish + 0.8 then return nil end
				A = mix(A, P.REEL, e("io", seg(t, brace + fly - 0.02, brace + fly + 0.1)))
				A = mix(A, P.SLASH, e("out", seg(t, finish - 0.02, finish + 0.12)))
				if t > finish + 0.25 then A = mix(A, ZERO, e("io", seg(t, finish + 0.25, finish + 0.8))) end
				return A, best
			end
			local hold = brace + 2 * fly
			if t >= hold + 0.4 then return nil end
			if t > hold then A = mix(A, ZERO, e("io", seg(t, hold, hold + 0.4))) end
			return A, best
		end
		return nil
	end
	local topV17 = TheriPose.top
	function TheriPose.top(model, pose, motors, hrp, ctx)
		local show = ctx.show
		local st = states[model]
		if not st then
			st = {lock = 0}
			states[model] = st
		end
		local tg, name
		if model:GetAttribute("TheriReworkPoseEnabled") ~= false and model:GetAttribute("TheriPoseTestKey") == nil then
			tg, name = target(model, ctx.serverNow, st, hrp)
		end
		if tg then
			for n, v in pairs(tg) do
				if motors[n] then pose[n] = (pose[n] or CFrame.identity) * rot(v) end
			end
		end
		show("TheriReworkPose", name or "none")
		topV17(model, pose, motors, hrp, ctx)
		local want = (tg and CROUCH[name]) and 1 or 0
		st.lock += (want - st.lock) * min(1, ctx.dt * 20)
		if st.lock < 0.001 then st.lock = 0 end
		show("TheriReworkPoseWeight", math.floor(st.lock * 10 + 0.5) / 10)
		local rj = motors.RootJoint
		if st.lock > 0 and rj and hrp and model:GetAttribute("TheriGroundLockEnabled") ~= false and ensureFK(model, motors, hrp) then
			local sc = model:IsA("Model") and model:GetScale() or 2
			local hrpCF = hrp.CFrame
			local d = footLow(motors, hrpCF, {}) - footLow(motors, hrpCF, pose)
			local up = clamp(d, -3 * sc / 2, 3 * sc / 2) * st.lock
			if math.abs(up) > 1e-3 then
				local v = hrpCF:VectorToObjectSpace(Vector3.new(0, up, 0))
				pose.RootJoint = CFrame.new(rj.restC0.Rotation:Inverse() * v) * (pose.RootJoint or CFrame.identity)
			end
		end
	end
end

return TheriPose
