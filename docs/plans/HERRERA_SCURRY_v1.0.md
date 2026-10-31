# Mecha Dino Arena v1.0 — Herrerasaurus scurry gait

**Goal:** the Herrerasaurus stands on two legs when idle and drops onto all fours to scurry like an iguana whenever it moves.
**Intent (Kepu 2026-10-30):** "This Dino will have a gallop run not a two legged walk. He stands on two legs when idle but does a scurry type of run like a regular iguana does" · mockup pick "Wow I love A".
**Chosen direction:** A · Iguana scurry — prototype `docs/mockups/herrera_scurry_options.html` (live render of HerreraModelData 1.0). Diagonal pairs (ArmL with LegR, ArmR with LegL), arms and legs splayed out, body S-wave (body yaw + roll, neck counter-yaw), tail whip travelling down the tail, body tipped nose-down with neck / head lifted, limbs folded under, ground fit so the lowest hand / toe touches the ground.
**Architecture:** one new pose module `ScurryPose` under IdleAnimation (pure: settings, geometry, pose per phase), used by IdleAnimation instead of WalkPose on models with `GaitScurry = true`. Every other model takes the existing WalkPose path unchanged. The pose is client-side like every gait (each client animates from the replicated movement), so everyone sees the scurry.

## Global Constraints
- Additive. WalkPose, IdlePose and every other pose layer unchanged; raptor / T-Rex / pachy keep the WalkPose path (they have no GaitScurry).
- Versions: ScurryPose 1.0, IdleAnimation 1.31, HerreraModelData 1.1 (generator 1.1), ScurryHitbox 1.0, ScurryPose.spec 1.0, herrera Play harness 1.0.
- Kepu 2026-10-30 on the plan: "The hitbox should adjust to the crouch" -> Task 4 (ScurryHitbox).
- Switches: model attribute `GaitScurry` (HerreraModelData true; absent elsewhere = off), `ScurryPoseEnabled` (default true; false = WalkPose path even on the Herrera).
- Joint frames: every rig 1.3 joint pose is `restC0 * pose`, and the segment Roots are in dino space (x forward, y up, z left), so pitch = about Z, yaw = about Y, roll = about X: `CFrame.fromEulerAngles(roll, yaw, pitch, Enum.RotationOrder.ZYX)` = the mockup's `Euler(roll, yaw, pitch, 'ZYX')`.
- Not in this plan: making the Herrera pickable (SpeciesServer / MainMenu), its kit (40 HP, top speed, slash, climbing), Lab card. Those come with the Herrera playable plan; this plan is tested through a Studio-only harness.
- Install via multi_edit, verify by hash; test with Studio tools only; Kepu publishes.

## Do-not-touch
WalkPose, IdlePose, JumpPose / PouncePose / BitePose / RoarPose / HeadbuttPose / HookPose / BoostPose / TurnPose / HeadLeadPose, RaptorModelData / TRexModelData / PachyModelData, SpeciesServer, MainMenu, Lab, hitbox scripts.

## Deterministic map
| State | Condition | Pose |
|---|---|---|
| Off | `GaitScurry ~= true` or `ScurryPoseEnabled == false` | v1.30 path (WalkPose), ScurryState "off" |
| Idle | scurry model, walk blend 0 | IdlePose (two legs, rest pose + breathing / head turns), ScurryState "idle" |
| Dropping / standing up | blend between 0 and 1 (speed crosses WALK_START_SPEED, BLEND_RATE as today) | IdlePose lerped to ScurryPose by the blend, ScurryState "blend" |
| Scurry | blend 1 | ScurryPose at the scurry phase, ScurryState "scurry" |
| Turning in place | effDist from the turn term (as today) | scurry steps in place |
| No knees / geometry not built | geo nil | Idle only (same rule as WalkPose), ScurryState "noGeo" |
| Other layers (jump, stun, dead) | as today, after the gait | unchanged order; they replace / multiply on the scurry pose exactly as they do on the walk pose |

## Task 1 — ScurryPose 1.0 · Mode: Logic
**Files:** Create `src/character/IdleAnimation/ScurryPose.luau`; Test `tools/tests/ScurryPose.spec.luau`.
**Interfaces (produces):**
- `ScurryPose.Defaults` = {ScurryBodyPitch = -24, ScurryNeck = 6, ScurryHead = 16, ScurryArmTuck = 30, ScurryLegTuck = 48, ScurryKnee = -48, ScurryFoot = 24, ScurryTail = {26, 4, 8, 14, 20} (as ScurryTail1..5), ScurryArmSwing = 34, ScurryArmSprawl = 18, ScurryArmLiftSprawl = 10, ScurryLegSwing = 30, ScurryLegSprawl = 16, ScurryKneeLift = -34, ScurryFootLift = 20, ScurryBodyYaw = 11, ScurryBodyRoll = 4, ScurryNeckYaw = -9, ScurryHeadYaw = -6, ScurryTailWhip = 8, ScurryTailWhipGrow = 4, ScurryTailLag = 0.75, ScurryBounce = 0.12, ScurryStride = 3.2, ScurryMaxHz = 5} (the mockup A numbers; degrees, studs at scale 1).
- `ScurryPose.settings(model)` -> the Defaults overridden by model attributes of the same names.
- `ScurryPose.buildGeo(model, motors)` -> {tips = {[segmentName] = {Vector3 ...}}} the lowest corner points of the hand (ArmL / ArmR) and toe (FootL / FootR) blocks in their segment Root frames, measured once from the model.
- `ScurryPose.angles(phase, s)` -> {[jointName] = {pitch, yaw, roll}, body = {pitch, yaw, roll, bounce}} (pure, degrees; the mockup's `gaitA`).
- `ScurryPose.get(phase, s, geo, motors)` -> pose table {[jointName] = CFrame} with the RootJoint carrying the body rotation and the ground fit drop: forward kinematics of the tips through restC0 * pose, lowest tip brought to the rest ground height (rest hip height), plus the bounce.
**Steps:** spec first (fails: module missing) -> module -> spec PASS -> commit.
**Acceptance (spec):**
- Diagonal pairing: ArmL and LegR swing angles equal at 16 phases; ArmR and LegL equal; the pairs opposite (sum 0 at every phase).
- Sprawl signs: ArmL / LegL roll < 0 (foot out to +z, the left), ArmR / LegR roll > 0, at every phase.
- S-wave: body yaw = ScurryBodyYaw * sin(phase); neck yaw opposite sign to body yaw; Tail5 yaw lags Tail1 by 4 x ScurryTailLag.
- Ground fit on a synthetic two-segment rig: lowest tip within 0.02 studs of the ground at 16 phases; settings override by attribute; Defaults complete (every key a number).
**Out of scope:** IdleAnimation wiring.

## Task 2 — IdleAnimation 1.31 · Mode: Wired
**Files:** Modify `src/character/IdleAnimation/init.server.luau` (header v1.31, require ScurryPose, the walk-blend block and the phase update only).
**Interfaces (consumes):** ScurryPose.settings / buildGeo / get from Task 1.
**Steps:**
1. `local scurryOn = model:GetAttribute("GaitScurry") == true and model:GetAttribute("ScurryPoseEnabled") ~= false` each frame.
2. Phase: when scurryOn and effDist > 0: `scurryPhase += 2 * pi * min(effDist / (ScurryStride * scale), ScurryMaxHz * dt)`.
3. In the `if blend > 0.001 and geo then` block: when scurryOn and scurryGeo, the moving pose is `ScurryPose.get(scurryPhase, ss, scurryGeo, motors)` instead of `WalkPose.get(...)`; same lerp by `blend`. Otherwise the v1.30 line, unchanged.
4. Diagnostics: ScurryState ("off" / "idle" / "blend" / "scurry" / "noGeo"), ScurryBlend (0.1 steps), ScurryHz (0.1 steps), ScurryDrop (studs, 0.01 steps).
5. Install (multi_edit), hash check, commit.
**Acceptance:** raptor / T-Rex / pachy in Play: ScurryState "off", MoveState / WalkBlend behave as before (walk + run). Herrera: Task 4.
**Out of scope:** every other layer.

## Task 3 — HerreraModelData 1.1 · Mode: Logic
**Files:** `tools/herrera_generator.py` 1.1, `src/shared/Models/HerreraModelData.luau`.
**Steps:** attributes GaitScurry = true, GaitAlwaysRun = true, ScurryPoseVersion "1.0"; geometry unchanged (diff = attributes + version lines only) -> install -> hash -> commit.
**Acceptance:** generator asserts still pass; only the attribute block and version lines differ from 1.0.

## Task 4 — ScurryHitbox 1.0 · Mode: Wired
**Why:** DinoHitboxes 1.1 welds each box to its segment Root; poses run on the clients only, so on the server (where bites / pounces / headbutts / bots test hits) the boxes stay in the two-legged rest pose.
**Files:** Create `src/server/ScurryHitbox.server.luau` (ServerScriptService).
**Interfaces (consumes):** ScurryPose.settings / meanAngles / buildGeo / fitted (Task 1), the "Hitboxes" folder and boxes of DinoHitboxes 1.1 (WeldConstraint Part0 = segment Root).
**Steps:** on GaitScurry models with Hitboxes: each box's WeldConstraint -> Weld to the HumanoidRootPart; C0 = rest:Lerp(crouch, w), rest = the box now (server rest pose), crouch = the box carried by ScurryPose.meanAngles fitted to the ground; w -> 1 while the horizontal HRP speed > 2 studs/s x scale, eased at 6 / s (the client walk blend). Server-set welds replicate, so server and clients test the same boxes. Scale change -> offsets rescaled. Switch: script attribute ScurryHitboxEnabled (default true). Diagnostics: ScurryHitboxState / Count / Blend / Drop / Version.
**Acceptance:** Play: standing, the Torso box is where DinoHitboxes put it; scurrying, ScurryHitboxBlend 1 and the Torso box centre is ScurryHitboxDrop lower (server); back to rest within 1 s of stopping; the blocking boxes (Torso, Neck, Head, Tail) stay above the ground at full crouch; raptor / pachy boxes untouched (no ScurryHitboxState).
**Out of scope:** DinoHitboxes, the hit tests themselves.

## Task 5 — Studio Play check · Mode: Wired
**Files:** Create `tools/tests/herrera_play_harness.luau` (Studio-only test tool, server context in Play: builds a Herrera character from HerreraModelData, scaled 2x, with copies of StarterCharacterScripts, and sets it as the test player's character; nothing installed in the place).
**Acceptance:**
- Standing: ScurryState "idle", two-legged rest pose (side capture).
- Moving (character_navigation): ScurryState "scurry", ScurryHz > 0; hands and toes within 0.3 studs of the ground on 10 samples (raycast under each tip); body S-wave visible in a top capture.
- Stop: back to "idle" within 0.4 s, standing on two legs.
- Turning in place: steps in place.
- Output: no errors from IdleAnimation.
- Raptor and pachy still walk / run as before (ScurryState "off").
- Captures go to docs/reference/herrera/.

## Red-team (single feature, one paragraph per risk)
1. **Hitboxes and camera.** The HumanoidRootPart stays at the bipedal hip height (physics unchanged); only the visual body drops by the ground fit. Kepu: "The hitbox should adjust to the crouch" -> Task 4 moves the hitboxes to the average crouch on the server (replicated). They follow the average crouch, not each limb swing (accepted). Anything that uses the HRP height (the camera) stays at the standing height.
2. **Step rate at the fastest speed.** The Herrera will be the fastest dino; distance-driven phase would make the legs blur. ScurryMaxHz (5) caps the step rate; above it the body slides further per step (stride stretches), the same trade WalkPose makes.
3. **Later layers on a quadruped.** Jump / stun / dead and the future slash were authored on upright bodies. They keep their order and are applied on top of the scurry pose; the kit plan reviews each one on the Herrera.
4. **Harness drift.** The test harness builds the character by hand, not through SpeciesServer, so RaptorScale / StatServer may not see it. Only the gait is under test here; the playable plan re-tests through SpeciesServer.
