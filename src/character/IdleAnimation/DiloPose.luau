-- DiloPose v1.1 (Mecha Dino Arena) — the Dilophosaurus' animation layers for IdleAnimation 1.43: Bite + Spit Dart (attack C)
-- and the Cobra Leap (J1), plus the frill (folded at rest, snapping open on the attack and the leap) and the throat sac.
-- MDA-226, plan docs/plans/DILO_KIT_v1.0.md Task 6; mockup docs/mockups/dilo_kit_options_v0.1.html (Kepu 2026-11-03 "C and
-- J1"; source tools/dilo_kit_mockup/app.js). Key poses, timings, springs, frill pop and sac = the mockup's.
-- Angles: degrees {p, y, r} on the rig's joint frames (rig 1.3, DiloModelData 1.1). Joint pose = restC0 * pose; rotation =
--   CFrame.fromEulerAngles(rad(r), rad(y), rad(p), ZYX) (= the mockup's three.js Euler(r, y, p, "ZYX"); TheriPose uses the
--   same mapping). p: RootJoint / Neck / Head + = rear back / nose up, - = lunge / nod forward; Arm / Leg + = swing forward;
--   Knee - = bend; Ankle + = toes up; Tail + = droop, - = lift; Jaw - = open. Right joints mirror the left ([p, -y, -r]).
-- Who: models with Species "Dilo" and DiloPoseEnabled ~= false (DiloPose.on). Every other model: nothing.
-- Attack layer (multiplied on top of the current pose, after the teno / therizino layers; sprung like the mockup):
--   Events. The owner's client reads DiloAttackTest 1.0's DiloLocalBiteAt (bite), DiloLocalState / DiloLocalAt ("coil" =
--   coil, "armed" = armed, "idle" after coil / armed = release) and DiloLocalDartAt (spit). Other clients read
--   DiloAttackServer 1.0's DiloBiteAt (bite) and DiloDartAt (spit); they never see a coil. Each new event starts its track
--   at its stamp (t = server time - stamp) from the pose the layer had at that moment ("$from"). Stamps already set when the
--   model is first seen start nothing.
--   BITE:    0 $from, 0.1 C_BWIND (io), 0.17 C_BITE (in2), 0.32 C_BITE2 (out), 0.7 READY (io), then done.
--   COIL:    0 $from, 0.3 C_COIL (io), 0.85 C_COIL2 (io), held while DiloLocalState is "coil" / "armed"; while "armed"
--            the neck and head tremble (pitch + 1.6 sin(80 clock)). Owner only.
--   RELEASE: 0 $from, 0.4 READY (io), then done (the hold ended without a spit: too short, dart cooling, stun / menu).
--   SPIT:    0 $from, 0.05 C_DART (in2), 0.25 C_DART2 (out), 0.8 READY (io), then done.
--   (= the mockup's attack C keys: bite 0 / 0.1 / 0.17 / 0.32 / 0.7; coil H0 + 0.3, REL - 0.02; spit REL + 0.05 / 0.25 / 0.8.)
--   Root push (the mockup's root fwd, studs at scale 2, x scale / 2): C_BWIND -0.6, C_BITE / C_BITE2 3.4, C_COIL / C_COIL2
--   -1, C_DART / C_DART2 2, through its own spring (w 20, z 0.9).
-- Leap layer (replaces the pose by its weight, like TheriPose's; sprung), from IdleAnimation's leap tracker (JumpStartedAt /
--   JumpPredictedAt, airborne, landing); IdleAnimation 1.43 turns the biped JumpPose off for these models:
--   crouch (t < JumpWindup): READY -> J_CROUCH (io), weight io(t / (JumpWindup / 2)); push / air (x = t - JumpWindup):
--   J_CROUCH -> J_PUSH over 0.1 s (out), J_PUSH -> J_AIR over the next 0.2 s (io); as the ground nears J_AIR -> J_DOWN by
--   io((0.14 - time to ground) / 0.12) (the mockup's J_AIR held to 0.14 s before the touchdown, J_DOWN 0.02 s before);
--   land (s since the touchdown): 0 J_DOWN, 0.12 J_LAND (out), 0.7 READY (io), then the weight fades to 0 by DiloLeapLandTime
--   (1.0 s). Plain landing (no FX here or anywhere).
-- Ground lock (attack layer and leap crouch / push / land): the body moves up / down so the lowest foot point is where the
--   rest pose puts it (the mockup kept the feet on the ground the same way); clamped +-3 x scale / 2 studs. The attack
--   layer's lock is x (1 - IdleAnimation's walk blend), so a bite on the run leaves the stride's feet to WalkPose.
-- Frill (local, this client only): parts named "*_frill*" (the open hood) and "*_fold*" (the folded hood) on the Neck
--   segment. Open while: the COIL track plays, a SPIT track is under 0.75 s, or a leap runs from 0.16 s after its start to
--   0.32 s after its landing. Opening: the open parts show and grow out of the frill hub (the mean of the "_frill<L|R><n>a"
--   parts, Z = 0 in the Neck Root's space) by 0.2 + 0.8 back(t / 0.13) (back overshoot 1.9) plus a rattle 0.035 sin(95 t)
--   (1 - t / 0.3) for t < 0.3; closing: they shrink 1 -> 0.25 over 0.1 s, then hide and the folded parts show. Hidden =
--   LocalTransparencyModifier 1 (so a server Transparency, e.g. a cloak, still applies to what shows). The grow moves each
--   open part with a local Weld (its WeldConstraint is disabled on this client) and scales its Size locally; offsets are
--   measured once and follow Model:GetScale().
-- Throat sac (local): part Jaw_sac's Size eases (rate 25/s) to x DiloSacSwell (1.55) while the COIL track plays and for the
--   first 0.05 s of a SPIT (other clients: 0.12 s), else x 1 (the mockup: 1 + 0.55 in the sac windows).
-- Switches (model attributes, read each frame): DiloPoseEnabled (default true; false = no layers, the biped jump pose plays,
--   the frill parts keep their last local state), DiloLeapPoseEnabled (true; false = the biped jump pose),
--   DiloGroundLockEnabled (true), DiloFrillEnabled (true; false = frill parts untouched), DiloFrillPopEnabled (true; false =
--   the frill only shows / hides, no grow), DiloSacEnabled (true).
-- Test hooks: model attribute DiloPoseTestKey = a key name ("READY" ... "J_LAND"): every joint shows that key exactly
--   (replaced, no springs / push / lock); DiloFrillTest = "open" / "fold" forces the frill. Unset in play.
-- Diagnostics (model attributes, this client): DiloPoseVersion, DiloPoseState ("none" / "bite" / "coil" / "armed" /
--   "release" / "spit" / "test:<key>"), DiloPoseSource ("local" / "server"), DiloLeapPhase ("none" / "crouch" / "push" /
--   "air" / "land"), DiloFrillState ("open" / "folded" / "off"), DiloFrillScale (0.01 steps), DiloFrillParts (open / fold
--   counts, "a/b"), DiloSacScale (0.01 steps), DiloGroundShift (studs, 0.1 steps).
-- v1.1 (plan docs/plans/DILO_MOVES_ANIM_v1.0.md Task 3, MDA-301; Kepu 2026-11-05 22:32 "A for all of them"; mockup
--   docs/mockups/dilo_moves_anim.html v0.1, keys from tools/mockup/dilo_moves_anim.js):
--   * Cobra Strike (model DiloCobraStrikeEnabled, default true): the bite track is {0 $from, 0.1 DRAW (io), 0.17 STRIKE (in2),
--     0.24 CLAMP (out), 0.42 CLAMP (io), 0.6 C_BITE2 (io), 1.0 READY (io)} with a head shake between 0.2 and 0.42 s (Neck yaw
--     + 12 sin(55 (t - 0.2)) x (1 - (t - 0.2) / 0.22), Head 0.6 of it); the frill opens from 0.01 to 0.5 s. The server's hit
--     time (0.18 s) is unchanged.
--   * Hood Flare (model DiloHoodFlareEnabled, default true): the coil track is {0 $from, 0.27 FLARE_COIL (io), 0.75
--     FLARE_COIL2 (io)}, the spit track {0 $from, 0.05 THRUST (in2), 0.18 RECOIL (out), 0.9 READY (io)}; the frill is x1.25
--     while the coil / spit shows it; the sac pumps (DiloSacSwell) while (coil time mod 0.24) is in [0.03, 0.15).
--     Other clients play the coil from DiloCoilAt (DiloAttackServer 1.4) while it is newer than DiloCoilEndAt / DiloDartAt
--     (armed tremble from 0.25 s; it ends after 3 s without an end stamp); the end stamp starts the release.
--   * Spring Coil (model DiloSpringCoilEnabled, default true): the leap crouch is J_DEEP, the push J_DEEP -> J_STRETCH over
--     0.08 s (out5) then J_STRETCH -> J_AIR over 0.24 s (io), the landing {0 J_DOWN, 0.14 J_SOFTLAND (out), 0.8 READY (io)};
--     the frill opens 0.1 s after the start (was 0.16). Leap timing unchanged.
--   Diagnostics: DiloPoseSet ("1.1"); DiloPoseState "coil:server" / "armed:server" on other clients' coils.
-- v1.2 (dilo parts build 1, MDA-319, plan docs/plans/DILO_PARTS_v1.0.md Task 6; keys from the looks mockup
--   tools/mockup/dilo_parts_looks.js v0.1, picked looks): the mecha part moves play as attack tracks, started on every client
--   (the owner too) by DiloMovesServer 1.0's server stamps, each wind-up -> action -> result -> recovery, ground lock as the
--   other attack tracks:
--   * p_gatling (DiloGatlingAt): {0 $from, 0.35 GAT_BRACE (io), 1.35 GAT_BRACE, 1.8 READY (io)}; hood open 0.1 - 1.6 s (the
--     Twin Hood Repeaters sit under it); a recoil buzz on the neck (+-1.5 deg, 70 rad/s) while the darts fly (0.4 - 1.4 s).
--   * p_mortar (DiloMortarAt): {0 $from, 0.45 A_WIND (io), 0.57 MORTAR_KICK (out5), 1.05 A_WIND (io), 1.55 READY (io)}.
--   * p_spine (DiloSpineAt): {0 $from, 0.35 CURL (io), 0.46 BURST (out5), 0.82 BURST, 1.52 READY (io)}; hood open 0.08 -
--     1.22 s; a tremble (the armed one) 0.05 - 0.42 s.
--   * p_over (DiloOverdriveAt): {0 $from, 0.55 HISS_WIND (io), 0.75 ROAR (out5), 1.2 ROAR, 1.55 SPIT_SET (io), 2.0 READY
--     (io)}; the hood stays open from 0.6 s after the press until DiloOverdriveUntil.
--   A part track and a bite / spit replace each other (the newer start wins). Switch: model attribute DiloPartPosesEnabled
--   (default true, read each frame; false = 1.1). Diagnostics: DiloPoseState "p_gatling" / ..., DiloPoseSet "1.2".
local DiloPose = {}
DiloPose.Version = "1.0"
DiloPose.Version = "1.1" -- v1.1 Cobra Strike, Hood Flare, Spring Coil
DiloPose.Version = "1.2" -- v1.2 mecha part move poses
DiloPose.Defaults = {
	DiloPoseEnabled = true, DiloLeapPoseEnabled = true, DiloGroundLockEnabled = true, DiloFrillEnabled = true,
	DiloFrillPopEnabled = true, DiloSacEnabled = true, DiloLeapLandTime = 1.0, DiloSacSwell = 1.55,
}

local JOINTS = {"RootJoint", "Neck", "Head", "Jaw", "ArmL", "ArmR", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "LegL",
	"LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"}
DiloPose.JOINTS = JOINTS

-- the mockup's BOTH(): left joints mirrored onto the right ones ([p, -y, -r])
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

local KEYS = {}
KEYS.READY = {}
KEYS.ZERO = {}
KEYS.C_BWIND = BOTH({RootJoint = {4, 0, 0}, Neck = {14, 0, 0}, Head = {-4, 0, 0}, Jaw = {-34, 0, 0}, ArmL = {-8, 0, 0}})
KEYS.C_BITE = BOTH({RootJoint = {-14, 0, 0}, Neck = {-36, 0, 0}, Head = {-2, 0, 0}, Jaw = {3, 0, 0}, ArmL = {22, 0, 0},
	KneeL = {-8, 0, 0}, Tail1 = {-12, 0, 0}, Tail2 = {-6, 0, 0}}, {LegL = {-8, 0, 0}, LegR = {16, 0, 0}, KneeR = {-20, 0, 0}})
KEYS.C_BITE2 = plus(KEYS.C_BITE, {Neck = {6, 0, 0}})
KEYS.C_COIL = BOTH({RootJoint = {6, 0, 0}, Neck = {30, 0, 0}, Head = {-26, 0, 0}, Jaw = {-12, 0, 0}, ArmL = {-16, 0, 0},
	KneeL = {-10, 0, 0}, LegL = {6, 0, 0}, Tail1 = {6, 0, 0}, Tail2 = {4, 0, 0}})
KEYS.C_COIL2 = plus(KEYS.C_COIL, {Neck = {3, 0, 0}, Head = {-2, 0, 0}})
KEYS.C_DART = BOTH({RootJoint = {-8, 0, 0}, Neck = {-20, 0, 0}, Head = {4, 0, 0}, Jaw = {-34, 0, 0}, ArmL = {14, 0, 0},
	Tail1 = {-8, 0, 0}}, {LegL = {-6, 0, 0}, LegR = {10, 0, 0}, KneeR = {-12, 0, 0}})
KEYS.C_DART2 = plus(KEYS.C_DART, {Neck = {-4, 0, 0}})
KEYS.J_CROUCH = BOTH({RootJoint = {-8, 0, 0}, Neck = {24, 0, 0}, Head = {-20, 0, 0}, Jaw = {-6, 0, 0}, ArmL = {-24, 0, 0},
	LegL = {34, 0, 0}, KneeL = {-58, 0, 0}, AnkleL = {26, 0, 0}, Tail1 = {6, 0, 0}})
KEYS.J_PUSH = BOTH({RootJoint = {-4, 0, 0}, Neck = {18, 0, 0}, Head = {-14, 0, 0}, ArmL = {-20, 0, 0}, LegL = {-22, 0, 0},
	KneeL = {-4, 0, 0}, AnkleL = {-24, 0, 0}, Tail1 = {-6, 0, 0}})
KEYS.J_AIR = BOTH({RootJoint = {-2, 0, 0}, Neck = {28, 0, 0}, Head = {-26, 0, 0}, Jaw = {-12, 0, 0}, ArmL = {-30, 0, 0},
	LegL = {40, 0, 0}, KneeL = {-72, 0, 0}, AnkleL = {34, 0, 0}, Tail1 = {-8, 0, 0}, Tail2 = {-4, 0, 0}, Tail3 = {-3, 0, 0}})
KEYS.J_DOWN = BOTH({RootJoint = {-6, 0, 0}, Neck = {16, 0, 0}, Head = {-12, 0, 0}, ArmL = {-10, 0, 0}, LegL = {22, 0, 0},
	KneeL = {-30, 0, 0}, AnkleL = {12, 0, 0}, Tail1 = {-4, 0, 0}})
KEYS.J_LAND = BOTH({RootJoint = {-6, 0, 0}, Neck = {8, 0, 0}, Head = {-6, 0, 0}, ArmL = {6, 0, 0}, LegL = {24, 0, 0},
	KneeL = {-42, 0, 0}, AnkleL = {18, 0, 0}, Tail1 = {6, 0, 0}})
-- v1.1 keys (the mockup's dilo_moves_anim.js)
KEYS.DRAW = BOTH({RootJoint = {6, 0, 0}, Neck = {26, 0, 0}, Head = {-18, 0, 0}, Jaw = {-6, 0, 0}, ArmL = {-12, 0, 0}})
KEYS.STRIKE = KEYS.C_BITE
KEYS.CLAMP = plus(KEYS.C_BITE, {Jaw = {2, 0, 0}})
KEYS.FLARE_COIL = plus(KEYS.C_COIL, {Neck = {6, 0, 0}, Head = {-4, 0, 0}, Jaw = {-10, 0, 0}})
KEYS.FLARE_COIL2 = plus(KEYS.FLARE_COIL, {Neck = {3, 0, 0}})
KEYS.THRUST = plus(KEYS.C_DART, {Neck = {-8, 0, 0}})
KEYS.RECOIL = plus(KEYS.C_DART, {RootJoint = {10, 0, 0}, Neck = {10, 0, 0}})
KEYS.J_DEEP = plus(KEYS.J_CROUCH, {Neck = {10, 0, 0}, Head = {-6, 0, 0}, KneeL = {-10, 0, 0}, KneeR = {-10, 0, 0}, Tail1 = {6, 0, 0},
	Tail2 = {6, 0, 0}, Tail3 = {4, 0, 0}})
KEYS.J_STRETCH = BOTH({RootJoint = {-14, 0, 0}, Neck = {-18, 0, 0}, Head = {6, 0, 0}, Jaw = {-14, 0, 0}, ArmL = {30, 0, 0},
	LegL = {-40, 0, 0}, KneeL = {-2, 0, 0}, AnkleL = {-30, 0, 0}, Tail1 = {-6, 0, 0}})
KEYS.J_SOFTLAND = plus(KEYS.J_LAND, {KneeL = {-12, 0, 0}, KneeR = {-12, 0, 0}, Neck = {6, 0, 0}})
-- v1.2 keys (the looks mockup's dilo_parts_looks.js + dilo_kit_mockup A_WIND)
KEYS.GAT_BRACE = BOTH({RootJoint = {-4, 0, 0}, Neck = {-6, 0, 0}, Head = {2, 0, 0}, ArmL = {-12, 0, 0}, KneeL = {-16, 0, 0},
	AnkleL = {6, 0, 0}, Tail1 = {-4, 0, 0}}, {LegL = {14, 0, 0}, LegR = {-6, 0, 0}})
KEYS.A_WIND = BOTH({RootJoint = {10, 0, 0}, Neck = {32, 0, 0}, Head = {-22, 0, 0}, Jaw = {-8, 0, 0}, ArmL = {-14, 0, 0},
	LegL = {5, 0, 0}, KneeL = {-8, 0, 0}, Tail1 = {7, 0, 0}, Tail2 = {4, 0, 0}})
KEYS.MORTAR_KICK = plus(KEYS.A_WIND, {RootJoint = {6, 0, 0}})
KEYS.CURL = BOTH({RootJoint = {-4, 0, 0}, Neck = {18, 0, 0}, Head = {-18, 0, 0}, Jaw = {-8, 0, 0}, ArmL = {-26, 0, 0},
	LegL = {16, 0, 0}, KneeL = {-30, 0, 0}, AnkleL = {12, 0, 0}, Tail1 = {8, 0, 0}, Tail2 = {6, 0, 0}})
KEYS.BURST = BOTH({RootJoint = {12, 0, 0}, Neck = {28, 0, 0}, Head = {-14, 0, 0}, Jaw = {-36, 0, 0}, ArmL = {-34, 0, -26},
	LegL = {-4, 0, 0}, KneeL = {-6, 0, 0}, Tail1 = {-14, 0, 0}, Tail2 = {-8, 0, 0}})
KEYS.HISS_WIND = plus(KEYS.A_WIND, {Jaw = {-22, 0, 0}, Head = {-4, 0, 0}})
KEYS.ROAR = BOTH({RootJoint = {8, 0, 0}, Neck = {22, 0, 0}, Head = {8, 0, 0}, Jaw = {-44, 0, 0}, ArmL = {-24, 0, -14},
	Tail1 = {-10, 0, 0}, Tail2 = {-6, 0, 0}})
KEYS.SPIT_SET = BOTH({RootJoint = {2, 0, 0}, Neck = {12, 0, 0}, Head = {-10, 0, 0}, Jaw = {-10, 0, 0}, ArmL = {-12, 0, 0},
	KneeL = {-8, 0, 0}})
DiloPose.KEYS = KEYS
local FWD = {C_BWIND = -0.6, C_BITE = 3.4, C_BITE2 = 3.4, C_COIL = -1, C_COIL2 = -1, C_DART = 2, C_DART2 = 2}
FWD.DRAW, FWD.STRIKE, FWD.CLAMP = -1.2, 4.0, 4.0 -- v1.1
FWD.FLARE_COIL, FWD.FLARE_COIL2, FWD.THRUST, FWD.RECOIL = -1, -1, 2.8, 0.4
FWD.A_WIND, FWD.MORTAR_KICK, FWD.BURST, FWD.HISS_WIND, FWD.ROAR = -1.2, -2.4, -0.6, -1.2, -0.4 -- v1.2

local TRACKS = {
	bite = {{0, "$from"}, {0.1, "C_BWIND", "io"}, {0.17, "C_BITE", "in2"}, {0.32, "C_BITE2", "out"}, {0.7, "READY", "io"}},
	coil = {{0, "$from"}, {0.3, "C_COIL", "io"}, {0.85, "C_COIL2", "io"}},
	release = {{0, "$from"}, {0.4, "READY", "io"}},
	spit = {{0, "$from"}, {0.05, "C_DART", "in2"}, {0.25, "C_DART2", "out"}, {0.8, "READY", "io"}},
}
local LAND = {{0, "J_DOWN"}, {0.12, "J_LAND", "out"}, {0.7, "READY", "io"}}
-- v1.1 tracks
TRACKS.bite_cs = {{0, "$from"}, {0.1, "DRAW", "io"}, {0.17, "STRIKE", "in2"}, {0.24, "CLAMP", "out"}, {0.42, "CLAMP", "io"},
	{0.6, "C_BITE2", "io"}, {1.0, "READY", "io"}}
TRACKS.coil_hf = {{0, "$from"}, {0.27, "FLARE_COIL", "io"}, {0.75, "FLARE_COIL2", "io"}}
TRACKS.spit_hf = {{0, "$from"}, {0.05, "THRUST", "in2"}, {0.18, "RECOIL", "out"}, {0.9, "READY", "io"}}
local LAND_SC = {{0, "J_DOWN"}, {0.14, "J_SOFTLAND", "out"}, {0.8, "READY", "io"}}
-- v1.2 part tracks (see the header)
TRACKS.p_gatling = {{0, "$from"}, {0.35, "GAT_BRACE", "io"}, {1.35, "GAT_BRACE"}, {1.8, "READY", "io"}}
TRACKS.p_mortar = {{0, "$from"}, {0.45, "A_WIND", "io"}, {0.57, "MORTAR_KICK", "out5"}, {1.05, "A_WIND", "io"}, {1.55, "READY", "io"}}
TRACKS.p_spine = {{0, "$from"}, {0.35, "CURL", "io"}, {0.46, "BURST", "out5"}, {0.82, "BURST"}, {1.52, "READY", "io"}}
TRACKS.p_over = {{0, "$from"}, {0.55, "HISS_WIND", "io"}, {0.75, "ROAR", "out5"}, {1.2, "ROAR"}, {1.55, "SPIT_SET", "io"}, {2.0, "READY", "io"}}
local PART_STAMPS = {{"p_gatling", "DiloGatlingAt"}, {"p_mortar", "DiloMortarAt"}, {"p_spine", "DiloSpineAt"}, {"p_over", "DiloOverdriveAt"}}
local function partPosesOn(model) return model:GetAttribute("DiloPartPosesEnabled") ~= false end
local partSeen = nil -- v1.2: [stamp attribute] = last seen value
local function cobraOn(model) return model:GetAttribute("DiloCobraStrikeEnabled") ~= false end
local function flareOn(model) return model:GetAttribute("DiloHoodFlareEnabled") ~= false end
local function springOn(model) return model:GetAttribute("DiloSpringCoilEnabled") ~= false end
local function trackKey(model, kind)
	if kind == "bite" and cobraOn(model) then return "bite_cs" end
	if kind == "coil" and flareOn(model) then return "coil_hf" end
	if kind == "spit" and flareOn(model) then return "spit_hf" end
	return kind
end
local SPIT_FRILL, LEAP_FRILL_FROM, LEAP_FRILL_AFTER = 0.75, 0.16, 0.32
local SAC_SPIT_OWN, SAC_SPIT_OTHER = 0.05, 0.12

local rad, sin, min, max, clamp = math.rad, math.sin, math.min, math.max, math.clamp
local EASE = {
	lin = function(u) return u end,
	io = function(u) return u * u * (3 - 2 * u) end,
	out = function(u) return 1 - (1 - u) ^ 3 end,
	["in"] = function(u) return u * u * u end,
	in2 = function(u) return u * u end,
	out5 = function(u) return 1 - (1 - u) ^ 5 end, -- v1.1
	back = function(u) local c = 1.9; return 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2 end,
}
local function rot(v) return CFrame.fromEulerAngles(rad(v[3]), rad(v[2]), rad(v[1]), Enum.RotationOrder.ZYX) end
DiloPose.rot = rot
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
DiloPose.sample = sample

-- springs (the mockup's SPR; sub-stepped at <= 1/300 s)
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

function DiloPose.settings(model)
	local s = {}
	for k, v in pairs(DiloPose.Defaults) do
		local a = model:GetAttribute(k)
		if typeof(a) ~= typeof(v) then a = v end
		s[k] = a
	end
	return s
end
function DiloPose.on(model)
	return model:GetAttribute("Species") == "Dilo" and model:GetAttribute("DiloPoseEnabled") ~= false
end
function DiloPose.leapOn(model)
	return DiloPose.on(model) and model:GetAttribute("DiloLeapPoseEnabled") ~= false
end

-- the state below belongs to one model (each character's IdleAnimation requires its own copy of this module)
local atk = {kind = nil, at = nil, from = nil, target = nil, springs = newSprings(), seen = nil, lastState = nil}
local leapS = {springs = newSprings(), w = 0, lockW = 0, phase = "none", lastAt = -math.huge, frill = false}
local lockSmooth = 0
local frill = {open = false, t = 9, parts = nil, lastS = nil, sac = 1}
local fk -- {FootL = chain, FootR = chain, scale = s, ok = bool}

-- forward kinematics (feet only; TheriPose's) ----------------------------------------------------------------------------
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

-- leap layer -----------------------------------------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- jump = IdleAnimation's leap tracker {start, air, landAt (os.clock), done}; returns {joint = CFrame}, weight
function DiloPose.leap(model, jump, serverNow, now, hrp, dt)
	local s = DiloPose.settings(model)
	local W = num(model:GetAttribute("JumpWindup")) or 0.27
	local phase, x, tg, w, lock = "none", 0, nil, 0, 0
	local t = jump and serverNow - jump.start or 0
	if jump and jump.landAt and now - jump.landAt < s.DiloLeapLandTime then
		phase, x = "land", now - jump.landAt
	elseif jump and not jump.done and not jump.landAt then
		if jump.air then phase, x = "air", max(0, t - W)
		elseif t >= 0 and t < W then phase, x = "crouch", t
		elseif t >= W then phase, x = "push", t - W end
	end
	local SC = springOn(model) -- v1.1: Spring Coil
	local CROUCH = SC and "J_DEEP" or "J_CROUCH"
	if phase == "crouch" then
		tg = mixP(keyPose("READY"), keyPose(CROUCH), EASE.io(clamp(x / W, 0, 1)))
		w, lock = EASE.io(clamp(x / max(0.01, W / 2), 0, 1)), 1
	elseif phase == "push" or phase == "air" then
		if SC then -- v1.1
			if x < 0.08 then
				tg = mixP(keyPose("J_DEEP"), keyPose("J_STRETCH"), EASE.out5(clamp(x / 0.08, 0, 1)))
			else
				tg = mixP(keyPose("J_STRETCH"), keyPose("J_AIR"), EASE.io(clamp((x - 0.08) / 0.24, 0, 1)))
			end
		elseif x < 0.1 then
			tg = mixP(keyPose("J_CROUCH"), keyPose("J_PUSH"), EASE.out(clamp(x / 0.1, 0, 1)))
		else
			tg = mixP(keyPose("J_PUSH"), keyPose("J_AIR"), EASE.io(clamp((x - 0.1) / 0.2, 0, 1)))
		end
		w, lock = 1, phase == "push" and 1 or 0
		if phase == "air" then
			local vy = hrp.AssemblyLinearVelocity.Y
			local hum = model:FindFirstChildOfClass("Humanoid")
			local base = hrp.Size.Y / 2 + (hum and hum.HipHeight or 0)
			rayParams.FilterDescendantsInstances = {model}
			local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -(base + 40), 0), rayParams)
			if hit and vy < -1 then
				local tl = max(0, hrp.Position.Y - hit.Position.Y - base) / -vy
				local k = EASE.io(clamp((0.14 - tl) / 0.12, 0, 1))
				if k > 0 then tg = mixP(tg, keyPose("J_DOWN"), k) end
			end
		end
	elseif phase == "land" then
		tg = sample(SC and LAND_SC or LAND, x, nil)
		w = x < 0.7 and 1 or 1 - EASE.io(clamp((x - 0.7) / max(0.01, s.DiloLeapLandTime - 0.7), 0, 1))
		lock = w
	end
	leapS.phase = phase
	-- frill window: 0.16 s after the start (crouch on) to 0.32 s after the landing
	leapS.frill = (phase == "crouch" and x >= (SC and 0.1 or LEAP_FRILL_FROM)) or phase == "push" or phase == "air"
		or (phase == "land" and x < LEAP_FRILL_AFTER)
	if not tg then
		leapS.w, leapS.lockW = 0, 0
		return nil, 0
	end
	local init = now - leapS.lastAt > 0.25
	leapS.lastAt = now
	local out = springStep(leapS.springs, tg, dt, init)
	leapS.w, leapS.lockW = w, lock * w
	local cfs = {}
	for n, v in pairs(out.a) do cfs[n] = rot(v) end
	return cfs, w
end

-- frill + sac (local) --------------------------------------------------------------------------------------------------
local function frillScale()
	if frill.open then
		local u = min(1, frill.t / 0.13)
		local sc = 0.2 + 0.8 * EASE.back(u)
		if frill.t < 0.3 then sc += sin(frill.t * 95) * 0.035 * (1 - frill.t / 0.3) end
		return sc
	end
	return frill.t < 0.1 and 1 - 0.75 * (frill.t / 0.1) or 0
end
local function frillParts(model)
	local P = frill.parts
	if P and P.root and P.root.Parent and P.neck.Parent == model then return P end
	local neck = model:FindFirstChild("Neck")
	local root = neck and neck:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then return nil end
	P = {neck = neck, root = root, open = {}, fold = {}, sc0 = model:IsA("Model") and model:GetScale() or 1, sc = nil}
	local sum, n = Vector3.zero, 0
	for _, p in ipairs(neck:GetChildren()) do
		if p:IsA("BasePart") and p.Name:find("_frill", 1, true) then
			local wc = p:FindFirstChildOfClass("WeldConstraint")
			local o = root.CFrame:ToObjectSpace(p.CFrame)
			table.insert(P.open, {part = p, wc = wc, off = o, size = p.Size, weld = nil})
			if p.Name:match("_frill[LR]%da$") then sum += o.Position; n += 1 end
		elseif p:IsA("BasePart") and p.Name:find("_fold", 1, true) then
			table.insert(P.fold, p)
		end
	end
	local hub = n > 0 and sum / n or Vector3.zero
	P.hub = Vector3.new(hub.X, hub.Y, 0)
	local jaw = model:FindFirstChild("Jaw")
	local sac = jaw and jaw:FindFirstChild("Jaw_sac")
	if sac and sac:IsA("BasePart") then P.sac, P.sacSize, P.sacSc0 = sac, sac.Size, P.sc0 end
	frill.parts, frill.lastS = P, nil
	return P
end
local function setLTM(p, v)
	if p.LocalTransparencyModifier ~= v then p.LocalTransparencyModifier = v end
end
-- apply the frill at scale S (0 = folded) and the sac at its current swell
local function applyFrill(model, P, S, pop)
	local sc = model:IsA("Model") and model:GetScale() or 1
	local k = sc / P.sc0
	local scaleChanged = P.sc ~= sc
	P.sc = sc
	for _, e in ipairs(P.open) do setLTM(e.part, S > 0 and 0 or 1) end
	for _, p in ipairs(P.fold) do setLTM(p, S > 0 and 1 or 0) end
	if pop and S > 0 and (scaleChanged or frill.lastS == nil or math.abs(S - frill.lastS) > 1e-4) then
		local hub = P.hub * k
		for _, e in ipairs(P.open) do
			if not e.weld then
				local wld = Instance.new("Weld")
				wld.Name = "DiloFrillWeld"
				wld.Part0, wld.Part1 = P.root, e.part
				if e.wc then e.wc.Enabled = false end
				wld.Parent = e.part
				e.weld = wld
			end
			local op = e.off.Position * k
			e.weld.C0 = CFrame.new(hub + (op - hub) * S) * e.off.Rotation
			e.weld.C1 = CFrame.identity
			e.part.Size = e.size * (k * S)
		end
		frill.lastS = S
	end
	if P.sac and P.sac.Parent then
		local want = P.sacSize * (sc / P.sacSc0) * frill.sac
		if (P.sac.Size - want).Magnitude > 1e-3 then P.sac.Size = want end
	end
end

-- top layer: attack + root push + ground lock + frill / sac. ctx = {isOwner, serverNow, now, dt, moveW, show}
function DiloPose.top(model, pose, motors, hrp, ctx)
	local s = DiloPose.settings(model)
	local show = ctx.show
	show("DiloPoseVersion", DiloPose.Version)
	-- test hook: one key, exactly
	local testKey = model:GetAttribute("DiloPoseTestKey")
	local tested = false
	if typeof(testKey) == "string" and KEYS[testKey] then
		for _, n in ipairs(JOINTS) do
			if motors[n] then pose[n] = KEYS[testKey][n] and rot(KEYS[testKey][n]) or CFrame.identity end
		end
		show("DiloPoseState", "test:" .. testKey)
		tested = true
	end
	-- events
	local biteAt, dartAt, st, stAt, src
	if ctx.isOwner then
		biteAt, dartAt = num(model:GetAttribute("DiloLocalBiteAt")), num(model:GetAttribute("DiloLocalDartAt"))
		st, stAt, src = model:GetAttribute("DiloLocalState"), num(model:GetAttribute("DiloLocalAt")), "local"
	else
		biteAt, dartAt, src = num(model:GetAttribute("DiloBiteAt")), num(model:GetAttribute("DiloDartAt")), "server"
	end
	local function start(kind, at)
		atk.from = atk.target or keyPose("ZERO")
		atk.kind, atk.at = kind, at
	end
	if atk.seen == nil then
		atk.seen = {bite = biteAt, dart = dartAt, coil = num(model:GetAttribute("DiloCoilAt"))}
		atk.lastState = st
	else
		if biteAt and biteAt ~= atk.seen.bite then start("bite", biteAt) end
		if dartAt and dartAt ~= atk.seen.dart then start("spit", dartAt) end
		atk.seen.bite, atk.seen.dart = biteAt, dartAt
		if ctx.isOwner then
			local holding = st == "coil" or st == "armed"
			if st == "coil" and atk.lastState ~= "coil" and atk.lastState ~= "armed" then start("coil", stAt or ctx.serverNow) end
			if atk.kind == "coil" and not holding then start("release", ctx.serverNow) end
			atk.lastState = st
		elseif flareOn(model) then -- v1.1: other clients see the coil (DiloAttackServer 1.4 stamps)
			local cAt, cEnd = num(model:GetAttribute("DiloCoilAt")), num(model:GetAttribute("DiloCoilEndAt")) or 0
			if cAt and cAt ~= atk.seen.coil and cAt > cEnd and cAt > (dartAt or 0) then start("coil", cAt) end
			atk.seen.coil = cAt
			if atk.kind == "coil" then
				if cEnd >= atk.at - 1e-3 and not (dartAt and dartAt >= atk.at) then start("release", ctx.serverNow)
				elseif ctx.serverNow - atk.at > 3 then start("release", ctx.serverNow) end
			end
			st = atk.kind == "coil" and (ctx.serverNow - atk.at >= 0.25 and "armed" or "coil") or nil
			src = atk.kind == "coil" and "server" or src
		end
	end
	-- v1.2: the mecha part moves (server stamps, every client)
	if not tested then
		if partSeen == nil then
			partSeen = {}
			for _, ps in ipairs(PART_STAMPS) do partSeen[ps[2]] = num(model:GetAttribute(ps[2])) end
		end
		for _, ps in ipairs(PART_STAMPS) do
			local at = num(model:GetAttribute(ps[2]))
			if at and at ~= partSeen[ps[2]] and partPosesOn(model) and ctx.serverNow - at < 1.5 then start(ps[1], at) end
			partSeen[ps[2]] = at
		end
	end
	local tg
	local t = atk.at and max(0, ctx.serverNow - atk.at) or 0
	if atk.kind then
		local keys = TRACKS[trackKey(model, atk.kind)] -- v1.1: the picked versions
		if atk.kind ~= "coil" and t > keys[#keys][1] then
			atk.kind, atk.at = nil, nil
		else
			tg = sample(keys, t, atk.from)
			if atk.kind == "coil" and st == "armed" then
				for _, n in ipairs({"Neck", "Head"}) do
					local v = tg.a[n] or {0, 0, 0}
					tg.a[n] = {v[1] + sin(ctx.now * 80 + #n) * 1.6, v[2], v[3]}
				end
			end
			if atk.kind == "p_gatling" and t > 0.4 and t < 1.4 then -- v1.2: the recoil buzz
				local v = tg.a.Neck or {0, 0, 0}
				tg.a.Neck = {v[1] + sin(ctx.now * 70) * 1.5, v[2], v[3]}
			elseif atk.kind == "p_spine" and t > 0.05 and t < 0.42 then -- v1.2: the tremble before the burst
				for _, n in ipairs({"Neck", "Head"}) do
					local v = tg.a[n] or {0, 0, 0}
					tg.a[n] = {v[1] + sin(ctx.now * 80 + #n) * 1.6, v[2], v[3]}
				end
			end
			if atk.kind == "bite" and cobraOn(model) and t > 0.2 and t < 0.42 then -- v1.1: the clamp's head shake
				local w = 12 * sin(55 * (t - 0.2)) * (1 - (t - 0.2) / 0.22)
				local v = tg.a.Neck or {0, 0, 0}
				tg.a.Neck = {v[1], v[2] + w, v[3]}
				local h = tg.a.Head or {0, 0, 0}
				tg.a.Head = {h[1], h[2] + w * 0.6, h[3]}
			end
		end
	end
	atk.target = tg
	local aOut
	if not tested and (tg or not atk.springs.settled) then
		aOut = springStep(atk.springs, tg or keyPose("ZERO"), ctx.dt, false)
	end
	if not tested then
		local nm = atk.kind == "coil" and (st == "armed" and "armed" or "coil") or atk.kind or "none"
		if atk.kind == "coil" and not ctx.isOwner then nm ..= ":server" end -- v1.1
		show("DiloPoseState", nm)
		show("DiloPoseSet", "1.2")
	end
	show("DiloPoseSource", src)
	show("DiloLeapPhase", leapS.phase)
	if aOut then
		for n, v in pairs(aOut.a) do
			if motors[n] then pose[n] = (pose[n] or CFrame.identity) * rot(v) end
		end
	end
	-- frill + sac
	if s.DiloFrillEnabled then
		local P = frillParts(model)
		if P then
			local want = atk.kind == "coil" or (atk.kind == "spit" and t < SPIT_FRILL) or (s.DiloLeapPoseEnabled and leapS.frill)
				or (atk.kind == "bite" and cobraOn(model) and t >= 0.01 and t < 0.5) -- v1.1: Cobra Strike's hood
			if partPosesOn(model) then -- v1.2: the part moves' hood windows
				if (atk.kind == "p_gatling" and t >= 0.1 and t < 1.6) or (atk.kind == "p_spine" and t >= 0.08 and t < 1.22) then want = true end
				local oa, ou = num(model:GetAttribute("DiloOverdriveAt")), num(model:GetAttribute("DiloOverdriveUntil"))
				if oa and ou and ctx.serverNow >= oa + 0.6 and ctx.serverNow < ou then want = true end
			end
			local ft = model:GetAttribute("DiloFrillTest")
			if ft == "open" then want = true elseif ft == "fold" then want = false end
			frill.t += ctx.dt
			if want ~= frill.open then frill.open, frill.t = want, 0 end
			local S = frillScale()
			local flare = flareOn(model) and (atk.kind == "coil" or atk.kind == "spit") -- v1.1: Hood Flare
			if flare then S *= 1.25 end
			local coilSwell = atk.kind == "coil" and (not flareOn(model) or (t % 0.24) >= 0.03 and (t % 0.24) < 0.15)
			local swell = s.DiloSacEnabled and (coilSwell
				or (atk.kind == "spit" and t < (ctx.isOwner and SAC_SPIT_OWN or SAC_SPIT_OTHER))) and s.DiloSacSwell or 1
			frill.sac += (swell - frill.sac) * min(1, ctx.dt * 25)
			if math.abs(frill.sac - swell) < 0.002 then frill.sac = swell end
			applyFrill(model, P, S, s.DiloFrillPopEnabled)
			show("DiloFrillState", S > 0 and "open" or "folded")
			show("DiloFrillScale", math.floor(S * 100 + 0.5) / 100)
			show("DiloFrillParts", #P.open .. "/" .. #P.fold)
			show("DiloSacScale", math.floor(frill.sac * 100 + 0.5) / 100)
		end
	else
		show("DiloFrillState", "off")
	end
	if tested then return end
	-- root push + ground lock (RootJoint translation, HRP space)
	local rj = motors.RootJoint
	if not (rj and hrp) then return end
	local sc = model:IsA("Model") and model:GetScale() or 2
	local fwd = (aOut and aOut.fwd or 0) * sc / 2
	local aw = (atk.kind ~= nil or not atk.springs.settled) and 1 - clamp(ctx.moveW or 0, 0, 1) or 0 -- moving: WalkPose's feet
	local lockT = s.DiloGroundLockEnabled and max(aw, leapS.lockW) or 0
	lockSmooth += (lockT - lockSmooth) * min(1, ctx.dt * 20)
	if lockSmooth < 0.001 then lockSmooth = 0 end
	local up = 0
	if lockSmooth > 0 and ensureFK(model, motors, hrp) then
		local hrpCF = hrp.CFrame
		local d = footLow(motors, hrpCF, {}) - footLow(motors, hrpCF, pose)
		up = clamp(d, -3 * sc / 2, 3 * sc / 2) * lockSmooth
	end
	show("DiloGroundShift", math.floor(up * 10 + 0.5) / 10)
	if fwd ~= 0 or up ~= 0 then
		local v = hrp.CFrame:VectorToObjectSpace(Vector3.new(0, up, 0)) + Vector3.new(0, 0, -fwd)
		pose.RootJoint = CFrame.new(rj.restC0.Rotation:Inverse() * v) * (pose.RootJoint or CFrame.identity)
	end
end

return DiloPose
