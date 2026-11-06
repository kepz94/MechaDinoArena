# Mecha Dino Arena — Herrera animation pass: nine moves (plan v1.0)

**Goal:** each Herrera move reads as wind-up → action → result → recovery, and the mecha part does the visible work.
**Chosen directions (Kepu 2026-11-05 20:40, "A for everything except B for glide and drop"):** Slash **A · Cross Rake**,
Glide + Drop **B · Banking Glide**, Quill Launcher **A · Anchor & Volley**, Smoke Pods **A · Vanish**, Strobe Frill
**A · Frill Display**, Stun Breaker **A · Shake-Off**, Razor Caltrops **A · Tail Lift Drop**, Goo Blob **A · Frill Spit**,
Adrenaline **A · Jab & Sprint**. Mockup `docs/mockups/herrera_moves_anim.html` v0.1 (artifact "Herrera Move Animations").
Looks: v472 (HERRERA_PARTS_LOOKS_v2.0) — unchanged by this plan.

## Grounding (current code, commit 3cf3943)
- Poses: IdleAnimation 1.44. SlashPose 1.1 (`phase` / `get`, kinds ground / dive / fade, IronClawPoseMul 1.35) layered at
  init ~1284. HerreraMovesPose 1.1: `glideWeight` / `getGlide` (lerp at ~1014; GlideArmRoll 55, GlideArmPitch 20,
  GlideLegTrail 45, GlideTailKeep 0.2, GlidePitch 14), `strobe` (StrobeStartedAt: up 0.15 / hold 0.2 / down 0.2,
  RootJoint +18, Neck +18, Jaw −20; ~1296), `gooKick` (GooFiredAt, RootJoint −7 over 0.35 s; ~1305). Offsets are
  multiplied on: pose[name] = pose[name] * off. No pose today for quills, smoke, breaker, caltrops, adrenaline.
- Server timing: HerreraMovesServer 1.4 `check()` sets `<P>ReadyAt` (cooldown) at the press. Quills: target + QuillStartedAt
  at the press, quills land at (i − 1) × QUILL_GAP 0.045 + flight. Smoke: cloud + SmokeStartedAt at the press. Strobe:
  StrobeStartedAt at the press, flash `task.delay(STROBE_WINDUP 0.15)` → StrobeAt (fires unless the root is gone).
  Breaker: StunnedUntil = now, pin release, push (BREAK_PUSH_TIME 0.3 slide), StunBreakImmuneUntil, BreakerAt — all at the
  press. Goo: GooFiredAt + flyBlob at the press. Caltrops: CaltropDroppedAt at the press (arm on land, ArmGap).
- AdrenalineServer 1.5 (shared with the Raptor's "adrenaline"; the Herrera's "hadren" uses the same remote): heal, speed,
  AdrenalineStartedAt, trails / plunge / glow / fluid at the press; "active" while AdrenalineUntil > now.
- Slash: SlashTest 1.5 starts the dash on the press (prediction), fires DinoSlashRequest at once; SlashServer 1.8 fixes the
  path from the HRP at the request. States ready / dash / recover.
- Glide: GliderTest 1.0 (GlideLocal, Gliding replicated); drop = a "dive" slash while gliding (SlashTest 1.4
  SlashGlideDiveEnabled + GliderDrop; SlashServer SlashGlideDive).
- FX / parts follow the stamps: HerreraMovesFX 1.5 (QuillStartedAt, SmokeStartedAt, StrobeAt, BreakerAt, CaltropDroppedAt,
  GooFiredAt), HerreraPartsAnim 1.0 (lids QuillStartedAt, fins SmokeStartedAt, sacs GooFiredAt, plunger
  AdrenalineStartedAt, door CaltropDroppedAt), SlashFX 1.0 (SlashStartedAt). Moving a fire stamp later moves its FX too.

## Global constraints
- Additive, every change behind a switch (default on; off = the previous version exactly). Version branding in headers,
  docs/VERSIONS.md, docs/ATTRIBUTES.md. Diagnostics in attributes. Commit + push each change.
- Studio HTTP off: multi_edit / execute_luau, verified by hash. Never test with a second player.
- Damage, ranges, durations, cooldowns, targets unchanged. Only the wind-up times on the picked cards change.
- No HUD change. Saved progress untouched (ZZ_TenoTestBefore save / restore). Publish only on Kepu's word.
- One-sided pieces on the camera side (+X = "…L").

## Do-not-touch
SlashServer (path, hits, bleed, charges), GliderTest (glide physics), the looks (HerreraPartsServer / HerreraPartsLooksV2),
BotServer, StunClient, MechaButtons, SkillEffects, the Raptor's Adrenaline (no wind-up, no pose), target rules of every
move, ScurryPose / WalkPose gaits.

## Tasks

### Task 1 — HerreraMovesServer 1.5: wind-ups · Wired
Script attrs (seconds): `HerreraMoves_quillWindup` 0.35, `_smokeWindup` 0.25, `_strobeWindup` 0.40, `_gooWindup` 0.35,
`_breakerWindup` 0.30. Switch `HerreraMoves_windupsEnabled` (default true; false = 1.4 timing, 0.15 strobe).
- At the press (after `check()` passes): `<P>WindupAt` = t (QuillWindupAt, SmokeWindupAt, StrobeStartedAt (as now),
  GooWindupAt, BreakerWindupAt) and `<P>WindupTime` = the wind-up.
- Quills: aimDir kept from the press; after the wind-up the 1.4 body runs (target, stamps, QuillStartedAt) from the root at
  that moment. Smoke / goo: the 1.4 body runs after the wind-up (cloud centre / blob muzzle at that moment).
  Strobe: the delay is `_strobeWindup`.
- Breaker: at the press StunnedUntil = now, the pin release, StunBreakImmuneUntil (star) — as now; after the wind-up the
  push + BreakerPushed + BreakerAt.
- Interrupt (per red-team Q2): after the wind-up the body runs only when the character is still in workspace and alive
  (Humanoid health > 0); else `<P>WindupResult` "cancelled" (cooldown stays spent). Otherwise `<P>WindupResult` "fired".
- Diagnostics: script `HerreraMovesWindups` (count), `HerreraMovesWindupCancels`.
- Acceptance: QuillStartedAt − QuillWindupAt 0.35, SmokeStartedAt − SmokeWindupAt 0.25, StrobeAt − StrobeStartedAt 0.40,
  GooFiredAt − GooWindupAt 0.35, BreakerAt − BreakerWindupAt 0.30 (± 0.03); StunnedUntil set at the press; switch off = 1.4.

### Task 2 — AdrenalineServer 1.6: the Herrera's jab wind-up · Wired
- When Species == "Herrera" and script `AdrenalineHerreraWindupEnabled` (default true): at "ok" stamp
  `AdrenalineWindupAt` = t, `AdrenalineWindupTime` = script `AdrenalineHerreraWindup` (0.45); the 1.5 "ok" body (stun
  clear, heal, speed, stamps, trails / plunge / glow / fluid) runs after it (alive + in workspace; else
  `AdrenalineWindupResult` "cancelled"). A press during the wind-up → result "windup" (new check before "active").
- Raptor and the switch off: 1.5 exactly.
- Acceptance: AdrenalineStartedAt − AdrenalineWindupAt 0.45 on a Herrera; a Raptor's 0; a second press in the wind-up →
  "windup".

### Task 3 — SlashTest 1.6 + SlashPose 1.2: the Cross Rake · Wired
- SlashTest (character `SlashCoilEnabled`, default true): a press that passes the local checks enters state "coil" for
  `SlashCoilTime` 0.15 s (local `SlashLocalCoilAt`), then the 1.5 dash start runs as now (facing, kind, target, request,
  pass-through all taken at the dash start). A stun / death / pin in the coil → state "ready", nothing sent
  (`SlashInputResult` "coilCancelled"). GliderTest already ends a glide on "dash" only; a coil from a glide keeps gliding
  until the dash.
- SlashPose 1.2 (model `SlashPoseCrossRakeEnabled`): phase "coil" (owner: SlashLocalState "coil", u over 0.15 s) →
  COCK by smoothstep(u): RootJoint −10, LegL/R +28, KneeL/R −40, AnkleL/R +12, Neck −6, Head +6, ArmL −45 / roll −10,
  ArmR −45 / roll +10, Jaw −10, Tail1 −6. Ground dash: COCK → RAKE_X by u 0.65 (easeOut) and held: RootJoint −18, ArmL +75 /
  roll −22, ArmR +75 / roll +22, Neck −10, Head +10, Jaw −26, LegL −18, LegR +24, KneeR −20, Tail1 −8 (the arms' and jaw's
  values × IronClawPoseMul as 1.1). Fade: RAKE_X → 0 over FADE_X 0.65 s. Dive kind: unchanged (Task 5 adds the roll).
- Other clients (red-team Q1): see the dash from SlashStartedAt (the coil happens before the request).
- HerreraPartsAnim 1.1 ironclaw: blades held folded (0) while "coil", then the 1.0 pulse.
- Acceptance: press → dash start 0.15 s (SlashPredictedAt − SlashLocalCoilAt); both arms forward at the hit frame
  (screenshot); dash distance / damage as 1.5; switch off = 1.5 / 1.1.

### Task 4 — HerreraMovesPose 1.2: ground move poses · Wired
`moves(model, serverNow)` → {[joint] = CFrame} (summed offsets, multiplied on after the strobe layer in IdleAnimation 1.45).
Per move a model switch `<Move>AnimPoseEnabled` (default true). Times from the stamps (W = the move's WindupAt, F = its fire
stamp; fallbacks the Task 1 / 2 times). Keys as the mockup's AT(): smooth (smoothstep) unless named.
- Quills (QuillAnim): W → ANCHOR by F (RootJoint −8, LegL +26 / yaw +16, LegR +26 / yaw −16, KneeL/R −36, AnkleL/R +12,
  ArmL +10 / roll −12, ArmR +10 / roll +12, Neck −10, Head +8, Tail1 +10, Tail2 +6); per quill i (F + (i − 1) × 0.045) a
  kick RootJoint +3, Neck +3 for 0.04 s; held to QuillLandedAt (else F + 0.6); → 0 over 0.7 s.
- Smoke (SmokeAnim): W → LOW + TAIL_UP by F + 0.05 (RootJoint −24, LegL/R +40, KneeL/R −62, AnkleL/R +22, ArmL/R +30 /
  roll ∓10, Neck −12, Head +6, Tail1 −4, Tail2 −6, Tail3 −8); held to SmokeUntil − 0.4; → 0 over 0.6 s.
- Strobe (StrobeAnim; the 1.1 rear-up is skipped while on): W → PULLBACK by F (RootJoint +10, Neck +28, Head −18, Jaw −10,
  ArmL/R +10); → SNAPFWD by F + 0.08 (easeOut; RootJoint −10, Neck −16, Head +8, Jaw −34, LegL +16, KneeL −16); held to
  F + 0.5; → 0 over 0.7 s.
- Breaker (BreakerAnim): W → SHAKE_OFF by W + 0.1 (easeOut), shaking to F: RootJoint roll 14 sin(40t), Neck yaw
  18 sin(40t + 1) / roll 10 sin(40t), Head yaw 14 sin(40t + 2), Tail1..3 yaw −14 / −18 / −20 sin(40t + 1..3); → ROARUP by
  F + 0.1 (easeOut; RootJoint +14, Neck +32, Head +10, Jaw −40, ArmL/R +20 / roll ∓20, Tail1 −10); held to F + 0.5;
  → 0 over 0.7 s.
- Caltrops (CaltropAnim): CaltropDroppedAt → TAIL_UP + RootJoint −4 by +0.2 (Tail1 −20, Tail2 −14, Tail3 −8,
  RootJoint −10 total); held to +0.7; → 0 over 0.6 s.
- Goo (GooAnim; the 1.1 gooKick is skipped while on): W → PULLBACK by F; → SNAPFWD by F + 0.07 (easeOut); → SNAPFWD +
  RECOIL (RootJoint +6, Neck +6) by F + 0.3; → 0 over 0.65 s.
- Adrenaline (AdrenAnim, Herrera only): W → LOOKSHOULDER by W + 0.25 (Neck −6 / yaw +34, Head −14 / yaw +20, ArmL +16,
  RootJoint −4); held to W + 0.3; → shiver (SHAKE_OFF at half rate) by W + 0.5; → ROARUP by F + 0.05 (easeOut); → 0 over
  0.4 s (the run gait takes over).
- Diagnostics: model `HerreraMovesPoseSet` ("1.2"), `HerreraMovesPoseLast` (move id while one plays, else "").
- Acceptance (Studio, flat pad, side camera, stamp-sampler): each move's frame at F matches the mockup (screenshot); the
  joint at F within ±3° of the listed value; switches off = 1.1.

### Task 5 — HerreraMovesPose 1.2 + IdleAnimation 1.45: Banking Glide + corkscrew drop · Wired
- Bank (model `GlideBankEnabled`): while glideWeight > 0, yaw rate ω = the HRP's flat facing change per second (smoothed
  over 0.15 s); roll = clamp(−ω × `GlideBankGain` 0.35, ±`GlideBankMax` 26°) × glideWeight on RootJoint (roll about X;
  turning left lowers the left wing). Works on every client (the HRP is replicated).
- Corkscrew (model `GlideCorkscrewEnabled`): a "dive" slash that started while gliding (owner: SlashLocalKind "dive" /
  "leap" with GlideLocal; others: SlashGlideDive true) adds RootJoint roll 360° × smoothstep(u) over the dive (u from
  SlashPose.phase); the STOOP offsets on top (RootJoint −40, ArmL/R −30 / roll ∓10, LegL/R −60, Neck −8, Head +10,
  Jaw −20, Tail1 −10, Tail2 −6) by u 0.6; then the 1.1 dive / fade. Only the model rolls (the camera follows the HRP).
- Diagnostics: model `GlideBankRoll` (degrees, 1 dp, owner only), `GlideCorkscrews` (count).
- Acceptance: steering left / right in a glide rolls ±(10..26)° (GlideBankRoll); a drop from a glide rolls one full turn
  and lands upright; hitboxes unchanged; switches off = 1.1.

### Task 6 — HerreraPartsAnim 1.1: parts on the wind-ups · Wired
Script `HerreraPartsAnimWindupEnabled` (default true; false = 1.0).
- quills: lids open from QuillWindupAt (over 0.15 s) instead of QuillStartedAt.
- smoke: fins fan from SmokeWindupAt.
- strobe: the 11 "led" bulbs light (white) one by one from StrobeStartedAt to StrobeAt, back to their colour at StrobeAt
  + 0.3 (HerreraMovesFX's flash plays on top).
- goo: sacs swell 1 → 1.25 from GooWindupAt to GooFiredAt, then the 1.0 squeeze.
- hadren: the plunger pushes in from AdrenalineWindupAt + 0.15 over 0.15 s.
- ironclaw: blades folded during SlashLocalState "coil" (owner).
- Acceptance: stamp-sampler values at W + half the wind-up (lids > 0, fins > 0, bulbs lit ≈ half, sacs ≈ 1.12, plunger
  in).

### Task 7 — HerreraMovesFX 1.6 + SlashFX 1.1: the new FX · Wired
Per effect a script switch (default true). All parts non-colliding, non-query, cleaned up.
- Quills `HerreraMovesFXAnchorEnabled`: 8 tan dust puffs at the feet from QuillWindupAt (0.5 s); per quill a small grey
  puff at the pod tip it leaves from (alternating L / R pods).
- Smoke `HerreraMovesFXHazeEnabled`: from SmokeWindupAt, 10 puffs pour from the HPart_smoke fins (0.85 s, before the
  1.5 cloud); while the owner is SmokeHidden, a faint blue (0x9fc4ff) shimmer sphere (radius 4 × scale, transparency
  0.85..0.9 pulsing) on other clients.
- Strobe `HerreraMovesFXConeEnabled`: at StrobeAt a flattened light cone (StrobeRange, StrobeAngle) from the head, its
  pitch clamped to ±0.15, fading 0.4 s.
- Breaker `HerreraMovesFXArcsEnabled`: BreakerWindupAt → BreakerAt bolts between the coil tips (5 per 0.05 s); at
  BreakerAt a cyan dome (to 4 × scale, 0.3 s) + 2 ground rings.
- Adrenaline `HerreraMovesFXStimEnabled` (Herrera): at AdrenalineStartedAt a green ground ring (to 4 × scale, 0.4 s) and
  10 green speed streaks behind the body while moving, until AdrenalineUntil.
- Slash `SlashFXCrossEnabled` (SlashFX 1.1, Herrera with SlashPoseCrossRakeEnabled): at the attacker's SlashHitAt two red
  crossed arcs at the target's root (0.3 s).
- Acceptance: each effect seen in Studio Play; part count back to the baseline 2 s after; no errors.

## Deterministic map
- Every move: switch on → the new path; off → the 1.4 / 1.5 / 1.1 / 1.0 path. Stamps missing → the fallbacks above.
- Wind-up then death / removal → "cancelled", no effect, cooldown spent; alive → "fired".
- Breaker: stun / pin / immunity at the press; push at +0.30 — a pinner released at the press is not pushed if it moved
  out of range by then.
- Second press in a wind-up: HerreraMovesServer "cooldown" (ReadyAt set at the press); Adrenaline "windup".
- Slash coil cancelled (stun / pin / death) → no request, no charge spent.
- Glide with no steering → roll eases to 0; a ground slash → no corkscrew.

## Red-team (resolved, Kepu 2026-11-05)
1. Slash coil: **others see the dash only** (the coil is local before the request; SlashServer untouched).
2. Interrupt: **still fires** after a stun in the wind-up; only death / removal cancels (as the strobe today).
3. Breaker: **free + immune at the press, push at 0.30**.
4. Adrenaline wind-up: **Herrera only** (Raptor instant, 1.5).
Accepted risks: the wind-ups add 0.25–0.45 s press-to-effect (on the picked cards); the quill target is picked at the
fire time from the press aim; the anchor / hunker poses play over the run gait (pose only, speed unchanged).

Tickets: MDA-291 (Task 1), MDA-292 (Task 2), MDA-293 (Task 3), MDA-294 (Task 4), MDA-295 (Task 5), MDA-296 (Task 6), MDA-297 (Task 7) — see Dev Hub.
