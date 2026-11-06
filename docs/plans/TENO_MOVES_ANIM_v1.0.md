# Mecha Dino Arena — Teno animation pass: six moves (plan v1.0)

**Goal:** each Teno move reads as wind-up → action → result → recovery, and the mecha part does the visible work.
**Chosen directions (Kepu 2026-11-05 18:47):** Boulder Mortar **A · Anchored Shot**, Stomp Shockwave **A · Quake Smash**,
Herd Bellow **A · Concussion Shriek**, Challenge Call **A · Watcher Alarm**, Hydraulic Leap **A · Piston Launch**, Shield
Armor **C · Shield Pulse**. Mockup `docs/mockups/teno_moves_anim.html` v0.2 (artifact "Teno Move Animations").
(Tail Grab A shipped in v465, plan TENO_GRAB_SCORPION_v1.0.)

## Grounding (current code)
- Poses: TenoPose 1.11 `attackAngles` — tmortar (1.8: 0.5 s MORTAR_COIL → 0.1 s MORTAR_WHIP, held to 0.75, 0.7 s → 0);
  tstomp (1.6: 0.4 s REAR → 0.1 s STOMP2, held 0.3, 0.9 s → 0); tbellow (1.5: 0.5 s BELLOW, held to 1.7, 0.6 s → 0;
  SUPPORT_END 2.3); tchallenge (0.4 × BELLOW, held to 1.4; SUPPORT_END 2.0); tmud (1.7: 0.25 s BRACE, held to 0.9, 0.5 s →
  0; SUPPORT_END 1.7); JUMP leap `leapSmoothAngles` (crouch = J_REAR over JumpWindup 0.12 s, air J_REAR → J_AIR, land
  J_LAND) + "tland" SLAM_DOWN2.
- Timing: TenoMovesServer 1.10 MORTAR_FIRE3 0.55 (TenoMortarFiredAt), STOMP_HIT 0.5 (TenoStompAt), BELLOW_AT /
  CHALLENGE_AT 0.5 (TenoBellowAt / TenoChallengeAt), shield coat TenoMovesShieldCoatAt 0.2 (TenoMudCoatAt, TenoMudUntil).
- Parts: TenoPartsAnim 1.0 already keys the cannon charge / kick / flash to TenoMortarFiredAt, the stomp rams / puffs to
  TenoStompAt, the beacon to TenoChallengeAt, the mane to TenoMudCoatAt — moving the server times moves them too.
- FX: TenoMovesFX 1.6 listens to the same stamps.

## Global constraints
- Additive, every change behind a switch (default on; off = the previous version exactly). Version branding in headers,
  docs/VERSIONS.md, docs/ATTRIBUTES.md. Diagnostics in attributes. Commit + push each change.
- Studio HTTP off: multi_edit / execute_luau, verified by hash. Never test with a second player.
- Damage, ranges, durations, cooldowns unchanged. Only the two timing moves below (Kepu picked them on the cards).
- No HUD change. Saved progress untouched. Publish only on Kepu's word.

## Do-not-touch
The grab (all of TENO_GRAB_SCORPION), target rules of every move, StunClient, BotServer, JumpServer / JumpTest launch,
the 7 looks' geometry (TenoPartsServer / TenoPartsLooksV2), TenoPoseFix's tail clip (it already covers "tland" / "tmortar").

## Tasks

### Task 1 — TenoMovesServer 1.11: timings + the challenge aim · Wired
- Mortar release MORTAR_FIRE_A 0.70 (was 0.55) while script `TenoMovesMortarAnchorEnabled` (default true).
- Stomp hit STOMP_HIT_A 0.60 (was 0.5) while script `TenoMovesStompQuakeEnabled` (default true).
- Challenge: at the press, `TenoChallengeAimYaw` = the flat HRP-space yaw (degrees, clamped ±40) to the nearest candidate
  within TenoChallengeRange (0 if none), stamped before TenoChallengeStartedAt. Switch `TenoMovesChallengeAimEnabled`.
- Acceptance: stamps in Studio (FiredAt − StartedAt 0.70, StompAt − StartedAt 0.60, AimYaw sign matches a bot placed left /
  right); each switch off = 1.10.

### Task 2 — TenoPose 1.12: Mortar, Stomp, Bellow, Challenge, Shield poses · Wired
(times t from the move's StartedAt; F = TenoMortarFiredAt − start, H = TenoStompAt − start, fallbacks 0.70 / 0.60)
- Mortar (model `TenoMortarAnchorPoseEnabled`): 0 → ANCHOR by 0.35 (smooth; legs splayed yaw ±18, knees −34, tail flat on
  the ground Tail1 22 / Tail2 12 / Tail3 4); held to F; F → ANCHOR + KICK (RootJoint +9, Neck +8, Head −6, arms +10) in
  0.06 (easeOut); → ANCHOR by F + 0.4 (smooth); held to F + 1.2; → 0 by F + 1.8. ABILITY_END.tmortar = F + 1.85.
- Stomp (`TenoStompQuakePoseEnabled`): 0 → REAR_HI by H − 0.22 (smooth; RootJoint 52, legs −50, arms 85 / 80, jaw −28);
  hang (+3 RootJoint) to H − 0.08; → SMASH by H (easeIn; RootJoint −18, neck −20, arms −16); held to H + 0.35;
  → 0 by H + 1.2. ABILITY_END.tstomp = H + 1.25.
- Bellow (`TenoBellowShriekPoseEnabled`): 0 → INHALE by 0.4 (smooth; Neck 24, Head 26, RootJoint 8); → SHRIEK by 0.5
  (easeIn; Jaw −46, Neck −4, RootJoint −6); held to 1.1; → 0 by 1.8.
- Challenge (`TenoChallengeAlarmPoseEnabled`): yaw Y = TenoChallengeAimYaw; 0 → 0.3 × BELLOW + Neck yaw Y, Head yaw Y/2
  by 0.2 (easeOut, the snap); the yaw sweeps Y → −Y by 0.65 (smooth, the scan); 0.5 × BELLOW held to 1.3; → 0 by 1.9.
- Shield (`TenoShieldPulsePoseEnabled`): 0 → PUSH by 0.25 (easeOut; arms 30, legs 24 / −10, RootJoint −4); → GUARD
  (0.6 × LIGER: head −11, neck −11, arms splayed) by 0.7 (smooth); held to 1.2; → 0 by 1.7 (inside SUPPORT_END 1.7; the
  purple shield itself stays as now).
- Diagnostic: model `TenoPoseMoveSet` ("1.12").
- Acceptance (Studio, adult, flat pad): each move's frame at its hit / release matches the mockup's (screenshot); switches
  off = 1.11.

### Task 3 — TenoPose 1.12: Piston Launch leap · Wired
- `leapSmoothAngles` (model `TenoLeapPistonEnabled`): crouch = LOWCROUCH (RootJoint −14, legs 40, knees −66, ankles 24)
  instead of J_REAR; air: LOWCROUCH → J_AIR over 0.1 s (the push), → TUCK (legs 40, knees −70, ankles 30, arms 40) by
  0.35 s, the existing reach toward J_LAND before the touchdown; land: → SQUAT (legs 36, knees −62) over the first 0.3 of
  the landing (the absorb), then the fade. "tland" (tail slam) plays on top unchanged.
- Acceptance: crouch visibly lower than the rest pose at 0.12 s; no foot through the ground on landing (feet ≥ ground − 0.5);
  switch off = 1.11.

### Task 4 — TenoPartsAnim 1.1: the sacs inhale / squeeze · Wired
- tbellow (script `TenoPartsAnimShriekEnabled`): sac pulse f × inflate, inflate = 1 + 0.5 × smooth(t / 0.4) up to the
  BellowAt, then 0.8 at BellowAt (0.06 s squeeze), back to 1 over 0.5 s.
- Acceptance: sacs at 0.4 s ≥ 1.4 × rest size, at 0.55 s ≤ 0.9 × rest.

### Task 5 — TenoMovesFX 1.7: the new FX · Wired
- Mortar (TenoMortarFiredAt): 6 grey smoke puffs from the TPart_tmortar "muzzle" along its look (0.9 s), a brass casing
  ejected from the hopper side (0.7 s arc, fades), 6 dust puffs at the Tail4_main ground point.
- Stomp (TenoStompAt): 10 blue crack strips fanning 40° forward from the hit centre, growing to TenoStompRange over 0.45 s,
  fading over 0.6 s.
- Challenge (TenoChallengeStartedAt + 0.2 → + 0.65): a blue scan cone (70° wide, TenoChallengeRange) from the head sweeping
  Y → −Y; at TenoChallengeAt a "!" billboard over each TenoChallengeTargets name (0.8 s) + a blue ground ring (0.7 s).
- Leap (JumpStartedAt + JumpWindup on a teno with TenoLeapOnJump; and the landing): 4 steam puffs at each FootL/R_meta.
- Shield (TenoMudCoatAt): one lilac ring from the "disc" growing to 10 studs × scale over 0.75 s (look only).
- Switch per effect: script `TenoMovesFXMortarSmokeEnabled`, `…StompCracksEnabled`, `…ChallengeScanEnabled`,
  `…LeapSteamEnabled`, `…ShieldPulseEnabled`. All parts non-colliding, non-query, cleaned up.
- Acceptance: each effect seen in Studio Play; part count back to the baseline 2 s after; 60 FPS.

## Deterministic map
- Each move: switch on → new path; off → 1.11 / 1.10 path; stamps missing → fallbacks above.
- Challenge with no candidate in range: AimYaw 0 → the snap and sweep are centred ahead.
- Shield ended before 1.7 s (TenoMudEndedAt) → the pose still finishes its 1.7 s (pose only).
- Leap with TenoLeapOnJump false → untouched (other jumps).

## Red-team (resolved, Kepu 2026-11-05)
1. Mortar 0.70 / stomp 0.60: on the picked cards — accepted.
2. Leap crouch: **keep JumpWindup 0.12 s** (a quick dip; take-off unchanged).
3. Shield: **guard ~1 s, then normal** (pose ends at 1.7 s; the shield stays).
4. Mortar recoil: **pose only** (no root move).

Tickets: MDA-282 (Task 1), MDA-283 (Task 2), MDA-284 (Task 3), MDA-285 (Task 4), MDA-286 (Task 5) — see Dev Hub.
