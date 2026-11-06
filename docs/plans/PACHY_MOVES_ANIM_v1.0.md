# Mecha Dino Arena — Pachy animation pass: eleven moves + victim stagger (plan v1.0)

**Goal:** every Pachy move reads as wind-up → action → result → recovery; the mecha parts move with it; a dino hit by a
headbutt or a hook smash staggers instead of sliding.
**Chosen (Kepu 2026-11-05 23:34, "A for everything"; scope 23:0x "All 11" + "Yes, headbutt + hook smash"):** Headbutt
**A · Bull Charge**, Leap + double jump **A · Coiled Spring**, Grappling Hook **A · Brace & Reel**, Servo Dash **A · Thruster
Kick**, Dome Visor **A · Turtle Brace**, Ink Shooter **A · Shoulder Cannon**, Tether Spike **A · Tail Sling**, Blood Rush
**A · Blood Pact**, Med-Station **A · Deploy Drop**, Last Stand **A · Battle Roar**, Head Down **A · Steel Dome**.
Mockup `docs/mockups/pachy_moves_anim.html` v0.1 (artifact "Pachy Move Animations"; key poses and times in
`tools/mockup/pachy_moves_anim.js`, part geometry `tools/mockup/pachy_parts.json`).

## Grounding (current code, v479, commit ae4c698)
- IdleAnimation 1.45 has no pachy branch: the pachy gets Idle / Walk / Turn / HeadLead, the biped JumpPose (JumpEnabled),
  HeadbuttPose 1.0 (HeadbuttEnabled; :1220-1226 phase, :1277-1286 apply), HookPose 1.2 (HookStartedAt; :1227-1232,
  :1287-1293), RamPose.stun, DeadPose, EatPose. BoostPose reads DashStartedAt only (Thrusters). No layer reads
  JumpDoubleAt, ServoDash*, Visor*, Ink*, Tether*, Med*, PachyLastStand*. Bots carry IdleAnimation clones (BotServer :5), so a
  layer in IdleAnimation also plays on bots.
- HeadbuttPose 1.0: wind-up 0.15 s (rear 40% then low), charge (Root -8, Neck -26, Head -38, arms -35, bob), impact 0.3 s
  (snap up + 9° shake), fade 0.25 s. Owner: HeadbuttLocal* (HeadbuttTest 1.2); others: HeadbuttStartedAt / HitAt / EndedAt.
  Blood Rush stamps HeadbuttSacrificeAt before StartedAt (HeadbuttServer 1.5+).
- HookPose 1.2: raise 0.15 s (ArmL = HookArmSeg, ARM_LEVEL 56 + aim), hold, smash 0.3 s (Neck -30 / Head -40), lower
  0.25 s. Stamps HookStartedAt / LaunchAt / ContactAt / SmashAt / BusyUntil (HookServer 1.8 :539-554). HookFX 1.2 hides
  the Hook sub-model (Shank / Bend / Barb / Point) while the claw is out.
- JumpServer 1.4: JumpStartedAt; double jump JumpDoubleAt (:195). MechaLegsServer 1.1 builds CoverL/R, PistonL/R, VentL/R
  (static welds, star only). MechaLegsFX 1.1: heel fire + speed lines; double jump burst + ring.
- ServoDashServer 1.1 stamps ServoDashStartedAt / Until (:339-341); ServoDashLaunch 1.1 (owner) pushes the body with a
  LinearVelocity (22 studs / 0.25 s). Housings + Bell_L / Bell_R on Torso.Root (static).
- VisorServer 1.1: goggles always; 9 ForceField panels on Head.Root, ±60°, fade in 0.1 s / out 0.2 s (setField :162);
  VisorUntil (:311). BoneCrest 1.5 visorLook (:239-275) = BLOCK sparks; no stamp on the pachy.
- InkServer 1.6: glob from the Barrel muzzle at the press (remote :556; InkStartedAt / InkArriveAt :657-659).
- TetherServer 1.3: release remote (:460) → TetherStartedAt / TetherLandAt (+0.8). The aim is owner-only (MechaButtons
  1.33 :145-168); nothing is sent while aiming. Launcher Base / Barrel / Drum / Tip on Tail1.Root (static).
- BloodVialServer 1.1: vials on Neck.Root drain 0.3 s, spray 0.45 s at HeadbuttSacrificeAt.
- MedStationServer 1.2: the pad is built at once under the pachy (build :113, drop :282), waves every 1 s (:146), destroyed
  at the end (stop :242).
- PachyStatsServer 1.0: PachyLastStandUsed / PachyLastStandUntil (star, :102-103); SkillEffects 1.44 writes
  PachyLastStandBelow / Mul / Star / Time and PachyHeadDownMul (:835-837). LastHitAt is on every character (Toxic Blood uses it).

## Global constraints
- Additive, every change behind a switch (default on; off = the previous version exactly). Version branding in headers,
  docs/VERSIONS.md, docs/ATTRIBUTES.md. Diagnostics in attributes. Commit + push each change.
- Studio HTTP off: multi_edit / execute_luau, verified by hash. Never test with a second player.
- Damage, range, recharge, shove, chain, heal numbers unchanged. Timing changes only where a pick says so (Servo Dash
  +0.06 s, Ink +0.1 s, Med-Station waves +0.3 s).
- No HUD change. Saved progress untouched. Publish only on Kepu's word. No landing FX (see red-team Q1).
- One-sided parts stay where they are (hook ArmL = right, ink tank left, tether drum right).

## Do-not-touch
Hit / target / shove / damage rules (HeadbuttServer hit path, HookServer pull + smash maths, BoneCrest maths), JumpServer
physics, DeflectRules, ModeRules / squads, SkillTree / SkillEffects numbers, AbilityBar / ArenaTouch, the other species'
layers in IdleAnimation, saved data.

## Tasks

### Task 1 — Victim stagger (StaggerPose 1.0, IdleAnimation 1.46, HeadbuttServer 1.16, HookServer 1.9) · Wired
- HeadbuttServer: on each accepted headbutt hit, stamp on the hit model StaggerFrom (pachy name), StaggerPower ("big"),
  StaggerAt (server time, last). HookServer: same at the smash ("mid"). Switches: script HeadbuttStaggerStampEnabled,
  HookStaggerStampEnabled.
- StaggerPose 1.0 (new module): 0.9 s from StaggerAt: head snapped back + away from StaggerFrom, arms flung, two stumble
  steps back (legs), then a wobble that fades (mockup rapPose stagger). Multiplied on top for every model (players + bots),
  after the dead / stun layers are checked (no stagger while dead). Model switch StaggerPoseEnabled. Pose only: no control
  loss, the shove stays HeadbuttShove / HookPull.
- Diagnostics: StaggerPoseState ("on" / "none").
- Acceptance: a headbutt and a hook smash on Bot_TRex_1 / a raptor bot show the stagger; dead bots don't; switches off = now.

### Task 2 — HeadbuttPose 1.1 + HeadbuttFX 1.3: Bull Charge and Blood Pact · Wired
- Bull Charge (model BullChargeEnabled): wind-up {0 READY, 0.10 PAW (io), 0.15 BULL_LOW (io)}; charge BULL_LOW (+ the bob);
  impact {0 CRUNCH (0.04, in2), 0.16 RECOIL_UP (out), 0.5 ready-ish (io)}, a head shake-off 0.5–0.95 s (yaw 14° decaying);
  keys from the mockup (PAW / BULL_LOW / CRUNCH / RECOIL_UP). The leg keys of PAW apply only while standing (wind-up).
- Blood Pact (model BloodPactEnabled): when HeadbuttSacrificeAt is within 0.2 s of the start, the wind-up is
  {0.07 PACT (out5), 0.15 BULL_LOW (in2)} instead of PAW.
- HeadbuttFX 1.3 (script switches HeadbuttFXBullEnabled, HeadbuttFXPactEnabled): snort puff from the nostrils at +0.03 s,
  back-foot dust at +0.08 s, dust kicked up while charging (as now), crunch sparks on the dome at the hit; Blood Pact: a red
  vignette for your own pachy, red streaks while charging.
- Acceptance: side frames at 0.1 s / charge / hit +0.05 / +0.6 match the mockup; Blood Rush shows the roar; owner and server
  paths (owner local stamps / others' server stamps); switches off = 1.0 / 1.2.

### Task 3 — PachyLeapPose 1.0 + MechaLegsFX 1.2: Coiled Spring · Wired
- New module (IdleAnimation 1.46 runs it for models with PachyLeapPoseEnabled ~= false and Species "Pachy", replacing the
  biped JumpPose like DiloPose.leap): crouch J_COIL (JumpWindup 0.12), push J_FIRE (0.06 s out5), air J_BALL, double jump
  (JumpDoubleAt / JumpDoublePredictedAt) J_KICK (0.05 s out5) → J_BALL (0.17 s), reach before touchdown, land J_ABSORB
  (0.08 s out) → ready 0.4 s. Same heights / timing (physics untouched).
- MechaLegsFX 1.2 (switch MechaLegsFXPistonEnabled): PistonL / PistonR slide along the shin on each client (weld C0
  offset, local): compress in the crouch, punch out at the push and the double jump, compress 0.25 s at touchdown; vents
  glow while firing. No steam / dust at landing (house rule).
- Acceptance: crouch / push / double-jump / landing frames; pistons move only with the star look built; non-pachy models
  untouched; switches off = JumpPose / 1.1.

### Task 4 — HookPose 1.3 + HookFX 1.3: Brace & Reel · Wired
- HookPose (model HookBraceEnabled): raise → H_BRACE (wide stance, lean); launch kick H_KICK 0.05 s; reel = three tugs
  (H_REEL / H_BRACE every 0.08 s from ContactAt); cock H_COCK from SmashAt − 0.12; smash H_SMASH (0.06 in2) held 0.24 s;
  back to ready 0.4 s. Same stamps; the arm keeps ARM_LEVEL + aim pitch.
- HookFX 1.3 (switch HookFXBraceEnabled): spool spins (local) while reeling; a white launch flash at the claw.
- Acceptance: frames at launch, reel, cock, smash; miss path still lowers; switches off = 1.2.

### Task 5 — PachyMovesPose 1.0 (new module, IdleAnimation 1.46) · Wired
One module, one function per move, multiplied on top for Species "Pachy" (model switch PachyMovesPoseEnabled + one per
move): Servo Dash (SQUAT 0.06 s → BLAST → DASH_RUN lean → BRAKE 0.35 s), Visor (BRACE in 0.1 s, BRACE_HIT on VisorBlockAt,
head shake after VisorUntil), Ink (INK_TURN 0.1 s, INK_KICK at the shot), Tether (SLING_COCK while TetherAimAt is newer
than TetherAimEndAt / TetherStartedAt, SLING_WHIP at the release, SLING_FLICK at TetherLandAt), Med-Station (LAY 0.3 s),
Last Stand (HURT → ROAR on PachyLastStandAt). Keys from the mockup. Diagnostics PachyMovesPoseState ("<move>:<phase>").
- Acceptance: one side frame per move matches the mockup; head lead / walk still play; switches off = no layer.

### Task 6 — Servo Dash 0.06 s squat (ServoDashServer 1.2, ServoDashLaunch 1.2) · Wired
- Server: ServoDashStartedAt = the press (as now); new ServoDashBlastAt = press + 0.06 (switch ServoDashSquatEnabled). The
  2x speed window starts at the blast. ServoDashLaunch: the LinearVelocity starts at ServoDashBlastAt (missing = now).
- FX (PachyMovesFX, Task 11): bell glow ramps during the squat; blast as now at the blast; skid dust + bell steam at the end.
- Acceptance: blast 0.06 s after the press; 22 studs / 2x unchanged; switch off = 1.1.

### Task 7 — Visor (VisorServer 1.2, BoneCrest 1.6) · Wired
- VisorServer (switch VisorSequenceEnabled): panels appear from the middle out inside the same 0.1 s (panel i delay =
  0.06 × |i − 5| / 4, fade 0.04 s), fold away edge-first in 0.25 s (was 0.2). BoneCrest visorLook stamps VisorBlockAt on
  the pachy (switch BoneCrestVisorStampEnabled).
- Acceptance: block window unchanged (VisorUntil); the panel order is seen; switch off = 1.1 / 1.5.

### Task 8 — Ink 0.1 s aim (InkServer 1.7) · Wired
- InkStartedAt = the press; the glob leaves at press + 0.1 (InkFireAt; switch InkAimDelayEnabled), its flight / blind
  unchanged. A press while stunned / dead during the 0.1 s cancels the shot (no recharge spent).
- FX (PachyMovesFX): tank pump (local scale), muzzle flash + black smoke ring at InkFireAt.
- Acceptance: glob 0.1 s after the press; blind 2 s; cancel path; switch off = 1.6.

### Task 9 — Tether aim stamps (MechaButtons 1.34, TetherServer 1.4) · Wired
- MechaButtons (switch MechaTetherAimStampEnabled): when the tether aim opens, FireServer on a new remote
  DinoTetherAim("aim", stamp); when it closes without a release, ("cancel", stamp). TetherServer: TetherAimAt /
  TetherAimEndAt (alive, tether owned, not in menu, 0.1 s per kind; switch TetherAimStampsEnabled). A release stamps
  TetherAimEndAt first.
- FX (PachyMovesFX): launcher kick + Tip hidden while the spike is out.
- Acceptance: aim / cancel / release stamps; switch off = 1.3 / 1.33.

### Task 10 — Med-Station drop (MedStationServer 1.3) · Wired
- (switch MedDeployEnabled) MedDroppedAt = the press; a capsule (3 × 2.4 × 3) flies from the pachy's back to the ground
  behind it in 0.3 s; the pad unfolds over 0.3 s (scale from the base, edges fade in); waves start at +0.3 s after the
  landing; MedActiveUntil moved by +0.3 s so the heal time is the same; at the end the pad folds and sinks 0.4 s, then
  is destroyed. Heal numbers / radius unchanged.
- Acceptance: drop → unfold → waves → fold; heals counted as now; switch off = 1.2.

### Task 11 — PachyMovesFX 1.0 (new client script) + PachyStatsServer 1.1 · Wired
- PachyStatsServer: PachyLastStandAt (server time) when the pachy first drops below PachyLastStandBelow (each time it
  crosses; switch PachyLastStandStampEnabled).
- PachyMovesFX (script switches per move): Last Stand ring (red-gold, 16 studs, 0.6 s) at PachyLastStandAt, the dome's
  red glow while below the line, the gold shell while PachyLastStandUntil runs; Head Down steel-blue dome glow while charging
  with PachyHeadDownMul < 1 and blue sparks on LastHitAt while charging; Servo Dash / Ink / Tether FX listed above.
- Acceptance: each effect seen in Studio Play; parts back to baseline 2 s after; no errors; switches off = none.

## Deterministic map
- Stagger: StaggerAt newer than the last seen → play 0.9 s; dead / KO → none; a new stamp restarts it.
- Headbutt: no sacrifice → PAW wind-up; sacrifice within 0.2 s of the start → PACT; miss → fade (as now) without the
  shake-off; hit → crunch + recoil + shake-off.
- Leap: JumpDoubleAt newer than the leap start and before landing → kick; none → ball until reach.
- Hook: miss → lower (as now, no cock); hit → tugs from ContactAt, cock at SmashAt − 0.12.
- Servo Dash: stun / death during the 0.06 s squat → no blast (cooldown already spent, as a press now).
- Visor: no block → no BRACE_HIT; VisorUntil cut short (reason) → the fold starts then.
- Ink: cancel during the 0.1 s → InkCancelAt, no glob, no recharge.
- Tether: lost "cancel" → the cock ends 3 s after TetherAimAt.
- Med-Station: pachy dies during the drop → the capsule still lands and runs (as the pad does now).
- Last Stand: healed back over the line → the glow stops; a new crossing → a new roar; the star shell only with
  PachyLastStandUntil.
- Every switch off → the 1.x path.

## Red-team (resolved, Kepu 2026-11-05)
1. Leap landing: **drop the steam**; the pistons still squash at touchdown (no landing FX).
2. Timing: **keep the delays** (Servo Dash +0.06 s, Ink +0.1 s, Med-Station waves +0.3 s).
3. Tells: **keep both** (others see the cocked tail while aiming; the red dome glow while under the Last Stand line).
4. Stagger: **look only** (no control loss; the shove works as now).
Accepted risks: one extra remote message per tether aim (+ one per cancelled aim); a lost "cancel" leaves the cocked tail on
others' screens for up to 3 s; the dome glow shows enemies the pachy is low.

Tickets: MDA-303 (Task 1), MDA-304 (Task 2), MDA-305 (Task 3), MDA-306 (Task 4), MDA-307 (Task 5), MDA-308 (Task 6), MDA-309 (Task 7),
MDA-310 (Task 8), MDA-311 (Task 9), MDA-312 (Task 10), MDA-313 (Task 11) — see Dev Hub.

## Build notes (2026-11-06, commits ce2f11c + next)
- Installed by multi_edit, hashes = repo (len/hash): HeadbuttServer 41122/995823300, HookServer 32900/918424504, StaggerPose
  3881/210241083, HeadbuttPose 11843/592343380, HookPose 8837/612874345, PachyMovesPose 16828/90183671, IdleAnimation
  90900/195617738, ServoDashServer 18283/450428923, ServoDashLaunch 8381/974322498, VisorServer 18168/193246418, BoneCrest
  22165/404483879, InkServer 36930/45160794, TetherServer 27800/433416279, MechaButtons 94607/919231889, MedStationServer
  22721/171847968, PachyStatsServer 8693/236307216, PachyMovesFX 22759/920501141. All 17 compile (loadstring) in Studio.
- Deviations from the plan: Task 3's PachyLeapPose is folded into PachyMovesPose.leap (one module); the FX of Tasks 2 / 3 / 4
  live in the new PachyMovesFX instead of HeadbuttFX / MechaLegsFX / HookFX (those stay untouched).
- Fixes from the Play test: PachyMovesPose 1.1 body drop (the bent legs lifted the feet up to 1.42 studs in LAY; now 0.00-0.04);
  PachyMovesFX 1.1 ink window restores its own colour + material.
- Play-tested as Pachy (Sandbox, test pad, slots saved / restored): stagger on Bot_TRex_1 (0.9 s, "big", attacker named),
  Bull Charge FX, Blood Pact (4th press, red edge), leap + double jump accents, Servo blast +0.06 s, ink fire +0.1 s, visor
  panels + fold, tether cock / whip / flick + tip hidden, med drop -> pad (heal from landing), Last Stand ring + shell + red
  dome (local stamps; Last Stand not bought on the test profile). No script errors.
- Not run: the Grappling Hook (Brace & Reel, hook stagger "mid", reel sparks): HookEnabled is false for every pachy since
  SkillTree 1.61 (c8abd36, MDA-241) — its therizino wrapper sets e.hookRange to 0 for every non-therizino dino. Separate bug,
  not touched. Head Down (not bought). The other-client paths (no second player, house rule).
