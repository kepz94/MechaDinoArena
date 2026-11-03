# Mecha Dino Arena v1.0 — Therizinosaurus kit (playable slasher: 3-hit claw combo, Diving Rake on JUMP)

**Goal:** the Therizino is a pickable 80 HP slasher: each tap of ATTACK is the next hit of a 3-hit claw combo (right cut, left cut, rear-up double chop), and JUMP is a forward leap that rakes both claws into the ground on landing.
**Intent (Kepu 2026-11-02):** "Therizino. Slasher build" · stance "open handed with the claws still hanging low like the iconic wolverine stance" (TherizinoModelData 1.2, live v361) · attack "3-hit combo" · payoff "Damage only" · health "80 HP" · jump "Pounce slash" · picks "A Reaper Sweeps" + "J1 Diving Rake" · animation "I like this one" (mockup v0.3).
**Chosen direction:** `docs/mockups/therizino_kit_options_v0.3.html` (video `docs/reference/therizino/therizino_kit_v0.3.mp4`); key poses + timings in `tools/therizino_kit_keys_v0.3.py` (solved arm angles: `keyposes.json` output, copied into TheriPose).
**Tickets:** MDA-197 (T1) · 198 (T2) · 199 (T3) · 200 (T3b) · 201 (T4) · 202 (T5) · 203 (T6) · 204 (T7) · 205 (T8); ADR-008.
**Architecture:** the teno / Herrera playable pattern. Numbers are model attributes (TherizinoModelData 1.3). The combo is a new server + input pair copied from TenoAttackServer / TenoAttackTest's scratch path (request → server checks → hit resolved at a fixed delay in a front cone). The leap reuses what is live: JumpServer 1.3 / JumpTest 1.4 leap charges and TenoMovesServer 1.4's attribute-driven landing slam (TenoLeapOnJump + TenoLeapEnabled + TenoLeapDamage / TenoLeapRadius on the character) — no new leap code. Poses are a TheriPose module layered in IdleAnimation like TenoPose; effects in TheriFX.

## Global Constraints
- Additive: every change behind a switch; raptor / T-Rex / pachy / Herrera / teno behaviour unchanged.
- Versions: TherizinoModelData 1.3 (therizino_generator 1.2), StatSheet 1.5 (+ spec 1.5), SpeciesServer 1.6, RaptorScale 1.6, MainMenu 1.16, SkillEffects 1.38, DinoHitboxes 1.2, TenoMovesServer 1.5, TheriAttackServer 1.0, TheriAttackTest 1.0, ArenaTouch 1.11, AbilityBar 1.23, TheriPose 1.0, IdleAnimation 1.39, TheriFX 1.0, display_models_install 1.1.
- Numbers (model attributes; distances at scale 1, x2 body in game): DinoMaxHealth 80; MoveRunSpeed 66 / MoveWalkSpeed 36; TheriAttackEnabled true; TheriHitDamage1 9, TheriHitDamage2 9, TheriHitDamage3 20; TheriHitDelay1 0.30, TheriHitDelay2 0.33, TheriHitDelay3 0.55 (press -> contact, from the mockup's measured contacts 0.33 / 0.74 / 1.34 s); TheriReach 7 (14 studs), TheriReach3 8 (16), TheriCone 100°; TheriMinGap 0.33 (earliest next tap), TheriChainWindow 0.8, TheriFinisherRecover 0.9. Leap: JumpEnabled true, JumpCharges 2, JumpCooldown 6 (refill per charge), JumpStaminaCost 0, JumpBoost / JumpLaunchPower tuned in Studio to a 30–34 stud leap at the 2x body; TenoLeapEnabled true, TenoLeapOnJump true, TenoLeapDamage 18, TenoLeapRadius 16, TenoLeapStun 0, TenoLeapArc 180 (front half only; Kepu "Front only"). HitboxSkipSegments "HandL|HandR" (no hitbox on the claws; Kepu "No hitbox on claws").
- Rig: generator 1.2 turns on the --elbows split by default for the data file: ArmL/R (shoulder + upper arm), ForeL/R (elbow + forearm + fringe, joint ElbowL/R), HandL/R (hand + claws, joint WristL/R). Same 171 blocks, same rest pose; 21 segments.
- Install via multi_edit / execute_luau, verify by hash; test with Studio tools only (no second player); publish only on Kepu's "publish" (both places).

## Do-not-touch
DinoModelBuilder (generic, builds the extra segments as is), JumpServer / JumpTest / TenoLeapLaunch (reused through attributes only), TenoMovesServer's other moves (only the jumpSlam target filter gains the arc check), TenoAttackServer / TenoAttackTest / TenoPose (copied patterns, not edited), BiteServer / PounceServer / SlashServer / HeadbuttServer, WalkPose / JumpPose, the other dinos' model data, SkinServer, SkillTree (no therizino skill paths yet), the Lab.

## File structure
| File | New / extend | Responsibility |
|---|---|---|
| tools/therizino_generator.py 1.2 | extend | rig split on by default; gameplay attributes; data VERSION 1.3 |
| src/shared/Models/TherizinoModelData.luau 1.3 | regenerated | model + attributes |
| src/shared/StatSheet.luau 1.5, tools/tests/StatSheet.spec.luau 1.5 | extend | SPECIES.Therizino |
| src/server/SpeciesServer 1.6, RaptorScale 1.6, src/client/MainMenu 1.16 | extend | pickable, 2x, menu entry |
| src/server/SkillEffects 1.38 | extend | its 1.37 leap writer leaves a therizino's JumpCharges / TenoLeapOnJump alone |
| src/server/DinoHitboxes 1.2 | extend | skips the segments named in the model attribute HitboxSkipSegments |
| src/server/TenoMovesServer 1.5 | extend | jumpSlam honours the character attribute TenoLeapArc (unset = all around, as 1.4) |
| src/server/TheriAttackServer.server.luau 1.0 | new | combo authority, hits, stamps |
| src/character/TheriAttackTest.client.luau 1.0 | new | ATTACK input, local prediction |
| src/character/ArenaTouch 1.11, AbilityBar 1.23 | extend | touch ATTACK pips, PC tiles |
| src/character/IdleAnimation/TheriPose.luau 1.0 + init 1.39 | new + extend | combo / leap poses, springs |
| src/client/TheriFX.client.luau 1.0 | new | trails, hit + impact effects |
| tools/display_models_install.luau 1.1 | extend | rebuild the display from 1.3 |

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Tap, step 0 | ATTACK, TheriAttackEnabled, alive, not menu / stunned / dazed / pinned, ≥ TheriFinisherRecover since a finisher | hit 1 (right cut): TheriComboStep 1; at press + TheriHitDelay1 every allowed target inside TheriReach x scale and TheriCone in front takes TheriHitDamage1 |
| Tap, chain | step 1 or 2, TheriMinGap ≤ time since the last tap ≤ TheriChainWindow | next step (2 = left cut, 3 = rear-up chop: TheriReach3, TheriHitDamage3, delay TheriHitDelay3) |
| Tap too soon | < TheriMinGap since the last tap | refused "cooldown" (no buffer in 1.0) |
| Chain dropped | > TheriChainWindow since the last tap | the tap is hit 1 again |
| After the finisher | step 3 done | next tap allowed TheriFinisherRecover after the step-3 press; it is hit 1 |
| Stunned / menu / pinned / dead mid-combo | any | step resets to 0; a pending hit is cancelled (TheriComboCancel) |
| Squadmate / mode-protected / shielded | SquadRules / ModeRules / EnergyShieldUntil | not hit / hit with no damage (TenoAttackServer rules) |
| JUMP | JumpEnabled, a charge left (JumpServer 1.3) | leap (JumpTest physics); TheriPose crouch → air (arms overhead) |
| Landing | TenoMovesServer 1.5 jumpSlam: rose ≥ 2 studs then back ≤ 1.5 | TenoLeapDamage to every allowed dino within TenoLeapRadius whose root is inside TenoLeapArc (180°) centred on the facing; TenoLeapLandedAt → TheriPose land rake + TheriFX impact |
| Landing, target behind | inside the radius, outside the arc | not hit |
| Claws hit by others | a bite / pounce / slash aimed at the claws | no hitbox there (HitboxSkipSegments): only body / arm / forearm boxes can be hit |
| No charge | JumpChargesLeft 0 | JUMP refused by JumpServer (existing) |
| Death | any | respawns as a therizino (SpeciesServer remembered choice) |

## Task 1 — TherizinoModelData 1.3 · Mode: Logic
**Files:** tools/therizino_generator.py 1.2; src/shared/Models/TherizinoModelData.luau.
**Interfaces:** Produces the attributes above (names exact) and segments ForeL/R, HandL/R with joints ElbowL/R, WristL/R (Part0 Arm*/Fore*).
**Steps:** default `--elbows` on for the data file (flag `--no-elbows` keeps 17 segments); add the attribute block (only these keys change vs 1.2); VERSION 1.3; regenerate; hash; install by string replace + hash.
**Acceptance:** body blocks unchanged (positions / sizes / colours identical to 1.2, only regrouped); 21 segments; attributes diff = the listed keys + TherizinoModelVersion; SkinCatalog.spec still PASS 957; display rebuilt with display_models_install 1.1 (171 parts).

## Task 2 — StatSheet 1.5 · Mode: Logic
**Files:** src/shared/StatSheet.luau, tools/tests/StatSheet.spec.luau (spec first: red, then green).
**Steps:** SPECIES.Therizino {class "Slasher", Health / Attack / Defense / Speed / Support start values (Attack high, Defense low), abilities "3-hit claw combo", "Diving Rake (JUMP)"}; ATTACK_KEYS + TheriHitDamage1/2/3 scaling like TenoScratchDamage.
**Acceptance:** spec red before, green after; other species' rows unchanged.

## Task 3 — Selectable · Mode: Wired
**Files:** SpeciesServer 1.6 (template from TherizinoModelData, "Therizino" known, respawn, remembered; SpeciesTherizinoEnabled), RaptorScale 1.6 (TherizinoScale 2; RaptorScaleTheriEnabled), MainMenu 1.16 (DINOS entry "THERIZINO", "80 HP · slasher, claw combo"; MainMenuTheriEnabled), SkillEffects 1.38 (the 1.37 leap writer returns early for Species "Therizino"; switch SkillEffectsTheriLeapKeepEnabled).
**Acceptance:** menu arrows reach THERIZINO; DinoSpeciesRequest "Therizino" ok; spawns 2x, 80 HP; after SkillEffects' refresh JumpCharges stays 2 and TenoLeapOnJump stays true; death respawns a therizino; the other five dinos spawn as before.

## Task 3b — DinoHitboxes 1.2 + TenoMovesServer 1.5 · Mode: Wired
**Files:** src/server/DinoHitboxes.server.luau, src/server/TenoMovesServer.server.luau.
**Steps:** DinoHitboxes: a segment whose name is in the model attribute HitboxSkipSegments ("|" joined) gets no box (switch DinoHitboxesSkipEnabled, default true; diagnostic HitboxSkipped). TenoMovesServer jumpSlam: when the character has TenoLeapArc, a target counts only if the flat angle between the root's LookVector and (target root - root) is ≤ arc / 2 (switch TenoMovesLeapArcEnabled, default true); unset = 1.4.
**Acceptance:** therizino Hitboxes folder has no Hitbox_HandL / HandR; every other dino's box count unchanged; a teno's leap still hits all around; a therizino landing hits a dummy in front, not one right behind.

## Task 4 — TheriAttackServer 1.0 · Mode: Wired
**Files:** new src/server/TheriAttackServer.server.luau.
**Interfaces:** remote ReplicatedStorage.DinoTheriAttack(stamp) -> TheriAttackServerResult ("ok" / "badArg" / "dead" / "disabled" / "menu" / "stunned" / "dazed" / "pinned" / "cooldown" / "recover"); character stamps TheriComboStep, TheriComboAt (server time of the accepted tap, set last), TheriHitAt, TheriHitStep, TheriHitTargets ("|" joined), TheriHitPoint; script diagnostics TheriAttackRequests / Hits / SquadSkips; KilledWith "thericlaw".
**Steps:** copy TenoAttackServer 1.4's target rules, shield / mode / squad checks and damage helper; combo state per character; hit resolved at stamp + TheriHitDelayN (clamped ≤ 0.6 s after the request).
**Acceptance:** every row of the map on a dummy and a bot; 9 / 9 / 20 numbers; a tap at 0.9 s restarts at hit 1; squadmate not hit.

## Task 5 — TheriAttackTest 1.0 + ArenaTouch 1.11 + AbilityBar 1.23 · Mode: Wired
**Steps:** CAS "DinoTheriAttack" (MouseButton1, ButtonR2, touch); local step prediction (TheriLocalStep, TheriLocalAt) so the pose starts on the press; touch ATTACK button with 3 step pips; PC tiles: ATTACK (combo step) and JUMP "Space" with 2 leap pips + refill (JumpChargesLeft / JumpChargeRefillAt).
**Layout:** the same slots and look as the teno's ATTACK / JUMP tiles (no new layout).
**Acceptance:** PC + forced touch; pips match the server step; no default Roblox touch button appears (MDA-146 lesson).

## Task 6 — TheriPose 1.0 + IdleAnimation 1.39 · Mode: Wired
**Steps:** the mockup v0.3 key poses (READY, R_W / R_S / R_F, L_W / L_S / L_F, REAR / REAR2 / CHOP / CHOP_SET, J_CROUCH / J_AIR / J_LAND) and timings as a Luau table; the mockup's [p, y, r] mapped to Motor6D CFrames once and checked; sub-stepped springs per joint group (arms 38 / 0.6, torso 30 / 0.85, legs 34 / 0.9, neck 20 / 0.6, head 16 / 0.55, jaw 28 / 0.45, tail 18→7 / 0.42); finisher claw tremble; leap layer from JumpStartedAt / TenoLeapLandedAt. Guarded by Species "Therizino" and TheriPoseEnabled; owner local stamps, others server stamps (TenoPose pattern).
**Acceptance:** numeric parity: for each key pose the right claw tip relative to the root is within 0.5 studs of the mockup's (`__tips`); Play capture of the combo and leap next to the mockup video; raptor / teno / Herrera poses unchanged (hash + Play).

**Run (Kepu 2026-11-02 "B Sidewinder", mockup docs/mockups/therizino_run_options.html v0.1, video docs/reference/therizino/therizino_run_options_v0.1.mp4, posture tools/therizino_run_keys_v0.1.py option B):** while running (IdleAnimation's gait blend toward MoveRunSpeed), TheriPose blends in the Sidewinder posture: body hunched forward (RootJoint pitch -24), neck low and pushed forward, the right arm swung out wide to the side with its claws dragging in the dirt, the left arm tucked to the chest; the run layer adds body bob / roll, a steady head and tail sway on top of WalkPose's legs (the legs stay WalkPose's). Each frame the right wrist bends (up to 4 tries) so the lowest right claw tip sits ~0.15 studs above the ground; walking blends back to the open stance. Switch TheriRunPoseEnabled.
**Run acceptance:** in Play the right claw tips stay within 0.5 studs of the ground while running on flat ground and lift clear on slopes / jumps (no claws through the floor); the left arm stays tucked; walking / idle show the open stance.

## Task 7 — TheriFX 1.0 · Mode: Wired
**Steps:** claw trails (Trail on claw-tip / mid attachments, white; orange on the finisher) during the strike windows; on TheriHitAt: flash, sparks, 3 red claw marks, damage number pop (white 9 / orange 20); owner-only hit-stop (pose clock x0.04 for 0.08 / 0.15 s) and camera shake; on the finisher impact and TenoLeapLandedAt: ground rings, dust, bouncing rubble, cracks. Switch TheriFXEnabled.
Run scrape (option B): while running and a right claw tip is within 1.6 studs of the ground: three grooves (thin dark parts laid along the tip path, fade after ~3 s, capped part count), sparks and dust puffs at the tips. All clients see it.
**Acceptance:** each effect seen in Studio Play captures; grooves follow the claw tips and fade; part count stays capped while running for 30 s; nothing on other dinos.

## Task 8 — Studio check · Mode: Wired
**Steps:** PC (+ forced touch): select, spawn, full combo on a dummy and on a bot, chain drop, recover, leap x2 + refill, landing damage, death / respawn, the display; Play check of a raptor, teno and Herrera after install; captures in docs/reference/therizino/.

## Red-team (Phase 4.5) — strongest challenges and mitigations
Kepu's answers (2026-11-02): hitboxes "No hitbox on claws" → Task 3b DinoHitboxes 1.2 (replaces item 3's measure-first); landing "Front only" → Task 3b TenoMovesServer 1.5 arc (replaces item 4's accepted radius); width "Keep the width" (item 5 accepted). Items 1 and 2 stand as written (mitigations in Tasks 3 and 6).
1. **The reused leap is switched off by SkillEffects.** SkillEffects 1.37's leap writer runs for every character that has a TenoLeapOnJump attribute: for a non-teno it writes JumpCharges 0 and TenoLeapOnJump false, which would silently kill the Diving Rake on every refresh. Mitigation: SkillEffects 1.38 returns early for Species "Therizino" (Task 3), with an acceptance check that the values survive a refresh.
2. **The game animation may not match the approved mockup.** The mockup's angle axes are not Roblox's, it runs springs at 300 Hz, and its hits fire on real claw contact while the server uses fixed delays. Mitigation: map once and prove it numerically (claw-tip parity ±0.5 studs per key), keep the spring sub-stepping, set the server delays from the mockup's measured contacts, and put a side-by-side capture against the mockup video in Task 8.
3. **The rig split changes hitboxes.** DinoHitboxes makes one box per segment, so the split gives HandL/R their own boxes around the open claw fan (in 1.2 the whole arm with its claws is one big box). The therizino may be easier (or harder) to bite and pounce than its 80 HP intends. Mitigation: Task 8 measures the hitbox sizes; if the hand boxes are larger than the old arm box, a DinoHitboxes 1.2 exclusion for Hand segments is Kepu's call (not in this plan).
4. **The reused landing is the teno's rule, not "in front".** jumpSlam hits everything within TenoLeapRadius around the root, credits KilledWith "leap", and TenoMovesFX 1.4 also draws its teno landing ring. Mitigation: radius 16 covers the rake's landing zone (accepted: it also hits right behind); TheriFX adds its own impact; the teno ring stays as is (TenoMovesFX not touched).
5. **Width.** About 33 studs claw tip to claw tip in game (visual parts don't collide, so it is a look / hitbox issue, not physics). Accepted for 1.0; the hitbox check in item 3 covers its gameplay side.
