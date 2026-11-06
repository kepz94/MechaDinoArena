# Mecha Dino Arena — Teno Tail Grab "A · Scorpion Strike" (plan v1.0)

**Goal:** the Pincer Tail really reaches the grabbed dino (front or behind), snaps shut on it where it stands, carries it a
believable height over the back and slams / flings it out the other side: no yank through the air, no 32-stud lift, no pop
at the release.
**Chosen direction:** A · Scorpion Strike (Kepu 2026-11-05 18:10 "A"), mockup `docs/mockups/teno_moves_anim.html` v0.1
(artifact "Teno Move Animations"). Reference: Zoids Death Stinger (the Pincer Tail's own look) + a scorpion's sting.
**Why the current one looks wrong (grounded):** TenoPose 1.10 `grabTail` drives the clamp along wind → strike → lift to
`hips + (0, 23.2k, 0.5k)` (≈ 32 studs up) → whip; TenoGrabRange (12 studs) is measured from the head / the tail points
(TenoMovesServer `pickGrab`), so a target at the edge of range is further than the tail can reach: TenoBotMotion 1.2 then
slides the bot from where it stands to the jaws in PULL_TIME 0.12 s (Studio: ~40 studs front, ~22 back before v461). The
whip's IK misses its goal by up to 5.8 studs, so the bot leaves the jaws at the release.

## Global constraints
- Additive, every change behind a switch (default on; off = the previous version exactly). Version branding in headers,
  docs/VERSIONS.md, docs/ATTRIBUTES.md. Diagnostics in attributes. Commit + push each change.
- Studio HTTP off: install with multi_edit / execute_luau, verify by hash. Never test with a second player.
- Numbers unchanged: TenoGrabDamage 8, TenoGrabStun 1, TenoGrabRange 12, TenoGrabFling, TenoGrabCooldown 16, crash.
- No HUD change. Saved progress untouched. Publish only on Kepu's word.

## Do-not-touch
`pickGrab` target rules, the player-target path (StunClient toss; only its times move with the stamps), TenoPartsAnim (the
pincers already open at TenoGrabStartedAt, snap at TenoGrabCatchAt, open at the throw), the 1.9 Over-the-Top path (kept
behind the switches), every other Teno move, BotServer.

## Timeline (from the press t; server time)
| | wind-up (coil) | strike | catch (snap) | lift | slam / throw | flight |
|---|---|---|---|---|---|---|
| front | 0 – 0.40 | 0.40 – 0.55 | 0.55 | 0.55 – 1.00 | 1.00 – 1.15 | 1.15 → +0.6 s |
| behind | 0 – 0.25 | 0.25 – 0.40 | 0.40 | 0.40 – 0.85 | 0.85 – 1.00 | 1.00 → +0.6 s |
(was front 0.70 / 1.35 / 0.85, behind 0.45 / 1.10 / 0.85)

## Tasks

### Task 1 — TenoMovesServer 1.10: the Scorpion timeline · Wired
- `grabOverTop`: when script attribute `TenoMovesGrabScorpionEnabled` (default true) is on, times = `SC_TIMES` {front =
  {catch 0.55, throw 1.15}, back = {catch 0.40, throw 1.00}}, flight `SC_FLIGHT` 0.6; stamps `TenoGrabStyle` "scorpion" and
  `TenoGrabFlightPeak` `SC_PEAK` (8) before `TenoGrabStartedAt`. Off: OT_TIMES / OT_FLIGHT as 1.9, `TenoGrabStyle`
  "overtop", no peak stamp. Landing point / fling / damage / stun / crash unchanged.
- Diagnostic: script `TenoMovesGrabsScorpion`.
- Acceptance: stamps in Studio for a front and a back grab match the table; switch off = 1.9 stamps exactly.

### Task 2 — TenoPose 1.11: the Scorpion path + the reach step · Wired
- When `TenoGrabStyle` == "scorpion" and model attribute `TenoGrabScorpionEnabled` ~= false, `grabTail` / `attackAngles`
  use (k2 = |rest − hips| / 17.9, the v0.1 mockup's length; offsets from Torso_hips in HRP space, × k2):
  - body: front NOSE_DOWN {RootJoint −12, Neck −12, Head −8, Leg 24, Knee −24, Ankle 8, Arm −14}; behind REAR_BACK
    {RootJoint 10, Neck 8, Head −4, Leg −6, Knee −14, Arm 16}; carry = GRAB_BRACE; slam lean front RootJoint +6, behind
    RootJoint −10 / Neck −10; recover 0.7 s to 0.
  - goals: coil front (0.4, 10.08, 2.25) / behind (0.4, 7.58, 12.75), wind-up ease; strike = bezier(coil, coil + (0, 2, ∓6),
    target) easeIn; catch window: IK on the target, weights × 0.08 and +4 sweeps ("tight"); lift = bezier(target,
    mid + (0, 3, 0), carry) ease, carry front (0.4, 7.08, 2.75) / behind (0.4, 7.08, 0.75); slam to front (0.6, 1.58, 15.75)
    / behind (0.6, 1.58, −9.25) easeIn; recover to front (0.4, 3.58, 14.75) / behind (0.4, 4.58, 8.75), weight fading.
  - reach step (owner only): at a new grab, pre-solve the strike body pose to the target (tight); if the miss is over
    0.5 × k2 the character attribute `TenoGrabStepWant` (local, not replicated) = the flat HRP-space step toward the target
    = (miss − 0.5 k2), capped at STEP_MAX front 2 k2 / behind 5 k2 studs; else 0.
- Diagnostics: `TenoGrabIKMiss` (as now), `TenoGrabStepWant`.
- Acceptance (Studio, adult teno, parked bot unanchored at the edge of range, flat pad): IK miss at the catch ≤ 1.5 studs
  front and behind; highest clamp ≤ 24 studs over the ground; switch off = 1.10.

### Task 3 — TenoPoseFix 1.1: the owner's reach step · Wired
- While a scorpion grab is in its wind-up (TenoGrabStartedAt → TenoGrabCatchAt − 0.1) and `TenoGrabStepWant` is set, slide
  the local root along it (ease), each Heartbeat a raycast ahead (character + Hitboxes excluded) stops it 1 stud short of
  anything solid; never while FloorMaterial is Air. Switch: script attribute `TenoGrabStepEnabled` (default true).
  Diagnostic: character `TenoGrabStepDone` (studs moved).
- Acceptance: step ≤ cap, stops at a wall placed in the way, no step in the air; other clients see the move (replicated).

### Task 4 — TenoBotMotion 1.3: the flight arc · Wired
- The thrown bot's arc peak = the teno's `TenoGrabFlightPeak` when set, else FLING_PEAK 16. Switch: script attribute
  `TenoBotMotionPeakAttrEnabled` (default true).
- Acceptance (Studio, all 4 tasks): bot moves ≤ 3 studs in the 0.12 s before the catch; the gap between the jaws and the
  bot at the release ≤ 2 studs; it lands on TenoGrabLand; 60 FPS kept.

## Deterministic map
- style "scorpion" + switch on → Scorpion path; style "overtop" or switch off → 1.10 path; no style (old server) → 1.10.
- side front / back → the table rows; target gone mid-grab → `target()` fallback points (as 1.10) and the server's cancel.
- step: miss ≤ 0.5 k2 → no step; blocked → stops early (the catch then uses the 0.12 s pull for what is left).
- player target: same path for the tail; StunClient toss as now.

## Red-team (open — Kepu's call)
1. The reach step moves your dino during the grab (up to ~4 studs front / ~10 behind at adult size).
2. Fling distance: keep 45 studs (0.6 s, peak 8) or the mockup's shorter slam (~36 front / ~30 behind).
3. A player target can't be tested here (no second player): only the bot path is verified.
4. Uneven ground: the mockup is flat; Studio checks add a raptor on a 4-stud rock.
