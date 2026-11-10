# Mecha Dino Arena v1.0 — Dilo part effects rework + Cobra Spring

**Goal:** the Dilo's 7 mecha parts get the effects Kepu picked from `docs/mockups/dilo_vfx_v0.1.html`, and every Dilo leaps sooner, turns faster and leaps ~57 studs (today ~39).
**Intent (Kepu 2026-11-10):**
- 13:49: "the dilo vfx for the mecha animations need a total rework", mobility "currently its trash", "all the vfx of the mecha parts are straight ass". Then "Dilo's parts only" and "Show me both kinds".
- 15:05 picks:
  - Venom Gatling **A** · Toxin Mortar **C** · Sonic Hiss **B** · Spine Burst **A** · Antivenom Pump **B** · Spring Jets **B** · Venom Overdrive **A**.
  - **Cobra Spring "but make it jump even further"**, then "~57 studs, same height".
- Not picked: Tail Thrusters, Frill Glide, Venom Rush, Spring Jets+, Venom Tether. Spring Jets keeps its rules; only its effects change.

**Chosen direction:**
- The mockup is v0.1 (artifact MkwRiVnDzmYuEzh5VJhCU4, commit 6d3dc37). The source is `tools/dilo_vfx_mockup/dilovfx_fx.js`: the kits KA / KB / KC, with the timings in `dilovfx_tracks.js`.
- Each pick is that part's track in the mockup. It plays wind-up → action → result → recovery, with no landing FX.

**Tickets:** MDA-390 (T1) · 391 (T2) · 392 (T3) · 393 (T4) · 394 (T5) · 395 (T6).
**Architecture:**
- One new client script, **DiloPartsVFX 1.0**, draws the 7 new effects.
  - It reads the same server stamps DiloMovesFX 1.5 reads (DiloMovesServer 1.10). The server is unchanged.
- **DiloMovesFX 1.6** gets one check per old effect spawn. When the new script's switch for that part is on, the old effect is not drawn.
  - The part motion stays in DiloMovesFX: recoil, tube, barbs, piston, fins, cones, pips and the core glow.
- **DiloFX 1.3** hands the spit dart's look to DiloPartsVFX while the owner is in Venom Overdrive (Overdrive A: goo darts).
- Cobra Spring is numbers only: **DiloModelData 1.13** (generator v1.13).

## Global Constraints
- Additive: every change is behind a switch, and every number is an attribute.
  - `DiloPartsVFXEnabled` = false, or a part's `DiloPartsVFX_<id>Enabled` = false, restores DiloMovesFX 1.5's effect for that part exactly.
  - `dilo_generator.py --v112` regenerates 1.12 byte-identical.
- Versions: DiloModelData 1.13 (dilo_generator 1.13), DiloPartsVFX 1.0 (new), DiloMovesFX 1.6, DiloFX 1.3, plus a spec `tools/tests/DiloPartsVFX.spec.luau` 1.0.
- No image uploads: everything uses Parts, Beams, Trails, Highlights and the built-in particle textures.
  - The hazard ring (Mortar C) is 28 alternating yellow / dark wedge parts.
  - The mockup's hex decals become Neon ring parts.
- Budget (phone): at most **350 live effect parts** per client. The oldest effect is trimmed first, and the diagnostic is `DiloPartsVFXParts`.
  - ParticleEmitter rates are multiplied by `DiloPartsVFX_rateMul` (1; set 0.6 on a low-end client if needed).
- Everything is local to each client (Workspace.DiloPartsVFX_Local): no collision, no queries, no shadows on Neon / Glass, and nothing is replicated.
- Sizes are the mockup's studs at scale 2 × (character scale / 2).
- No landing FX (house rule). Cobra Spring's take-off dust is at the take-off only.
- Install via multi_edit / execute_luau and verify by hash.
  - Test with Studio tools only (no second player).
  - Before Play, set SpeciesRememberEnabled / SkillSaveEnabled false in Edit, and nil after.
  - Publish only on Kepu's "Publish".

## Do-not-touch
- DiloMovesServer (stamps, rules, damage), DiloPartsServer (the part models), DiloJetsLaunch (the dash), DiloAttackServer (spit rules).
- SkillTree / SkillEffects (no number changes except Cobra Spring's model data).
- The part motion code in DiloMovesFX, JumpServer / JumpTest (they read JumpBoost / JumpWindup / TurnLimit attributes as they are).
- Every other dino's FX scripts.

## Numbers
| Thing | Now | New |
|---|---|---|
| Cobra Leap wind-up `JumpWindup` | 0.27 s | 0.12 s (Raptor) |
| Turn rate `TurnLimitRate` | 360°/s (Kepu 2026-11-09 "360 (Pachy)") | 540°/s (Raptor; Cobra Spring) |
| Leap push `JumpBoost` | 14 (64.5 studs/s in the air) | 45 (95.7 studs/s) |
| Leap height / air time `JumpLaunchPower` | 54 (~9 studs, 0.6 s) | 54, unchanged |
| Leap length (measured / expected) | ~39 studs | ~57 studs |

Measured in Studio Play 2026-11-10 (flat pad, Dilo at scale 2):
- Run 50.7 studs/s (78 × StatSpeedScale 0.65).
- Leap launch ~0.3 s after the press, with the run speed kept.
- 0.6 s in the air at 64.5 studs/s.

## File structure
| File | New / extend | Responsibility |
|---|---|---|
| tools/dilo_generator.py 1.13 → src/shared/Models/DiloModelData.luau 1.13 | extend | KIT_V113: JumpWindup 0.12, TurnLimitRate 540, JumpBoost 45 |
| src/client/DiloPartsVFX.client.luau 1.0 | new | the 7 picked effects, the budget, the switches |
| src/client/DiloMovesFX.client.luau 1.6 | extend | the old effect spawn returns early when DiloPartsVFX owns that part; motion untouched |
| src/client/DiloFX.client.luau 1.3 | extend | during the owner's Overdrive (DiloOverdriveUntil > now) with DiloPartsVFX over on: no glob, DiloPartsVFX draws the goo dart (same From / To / flight) |
| tools/tests/DiloPartsVFX.spec.luau 1.0 | new | headless checks (Edit): the switch map, the budget trim, the ring wedge count |

## Effect specs (each = the mockup track; stamps from DiloMovesServer 1.10)
- **Venom Gatling A · Liquid Venom.**
  - Wind-up (DiloGatlingAt + 0.4 s): a goo blob swells at each repeater muzzle (Ball, Glass green, wobbling Size) and green drops are drawn into it.
  - Each `DiloGatlingShot`: a muzzle spurt (a green Ball pop, 12 droplets in a cone, 3 mist puffs).
  - The dart is a glossy goo Ball stretched along its flight, with a dripping trail, flying From → To over the flight.
  - Each `DiloGatlingHit`: a splash crown (14 droplets ring + 8 random, a squashed goo Ball, 4 sizzle puffs).
  - Recovery (end + 1.3 s): the barrels drip and steam.
- **Toxin Mortar C · Chem Warfare.**
  - Wind-up (DiloMortarAt): a spinning hazard-stripe ring at DiloMortarTo, DiloMortarRadius wide, a blinking red dot at its centre, and a red laser Beam from the tube. The tank's alarm light flashes and steam jets come off the tube.
  - Fire (DiloMortarFireAt): a flash, a smoke burst and a casing.
  - The canister is a dark cylinder with a hazard band and a green tip, spinning, with a thick smoke trail on the DiloMortarFrom → To arc.
  - Land (DiloMortarLandAt): a flash, 14 debris chunks, sparks, and 16 smoke rolls out to 3 × radius. Then the cloud for DiloMortarTime: ~50 big drifting yellow-green / grey smoke puffs inside the hazard ring.
  - Recovery: the tube smokes for 1.4 s.
- **Sonic Hiss B · Reactor Glow.**
  - Wind-up (DiloHissAt .. + DiloHissWindup): sparks spiral into the speakers, a shrinking ring and a growing glow.
  - Blast (DiloHissBlastAt): a star flash, 6 neon arc fronts (alternating green / cyan) rolling out to DiloHissRange inside DiloHissAngle, a shock half-shell, a glowing ground cone and sparks.
  - Every name in DiloHissHits: a spinning violet ring with a red X over its head until its SilencedUntil.
  - Recovery: heat shimmer and motes off the speakers.
- **Spine Burst A · Liquid Venom.**
  - Wind-up (DiloSpineAt .. + 0.42 s): the barbs drip venom (30/s).
  - Burst (DiloSpineBurstAt): 12 glossy venom quills (stretched Balls) with dripping trails fly DiloSpineRange over DiloSpineFlight, and a splash ring goes round the dilo.
  - Each hit in DiloSpineHits gets a splash crown.
  - Recovery: drips and steam off the frill.
- **Antivenom Pump B · Reactor Glow (blue).**
  - Wind-up (DiloPumpAt .. + DiloPumpWindup): light spirals into the Back Pump and a ring shrinks round it.
  - Jolt (DiloPumpJoltAt): a star flash, a shock sphere, 4 scan rings sweeping down the body, purge sparks flying off, and a ground ring.
  - While DiloImmuneUntil: a blue shell (ForceField Ball + Highlight edge + a wireframe-look outline of thin Neon rings) that flickers in its last 15%.
  - Each DiloImmuneBlockAt: a star, a ring at the hit and sparks.
- **Spring Jets B · Reactor Glow.**
  - Burst (the owner's DiloJetsPredictedAt, else DiloJetsAt + DiloJetsDelay, for DiloJetsTime + 0.45 s): a plasma cone out of the Tail Booster (outer green Neon cone + white core cone, flickering), 3 shock-diamond glows and sparks.
  - Trail (DiloJetsTrailUntil): a glowing chevron strip along DiloJetsFrom → To (a Beam with a moving texture made from Neon chevron parts), with rising sparks.
  - The charge pips keep DiloMovesFX's code.
  - It replaces DiloMovesFX 1.3's orange flame (DiloJetsThrusterFXEnabled path) only while DiloPartsVFX_djetsEnabled.
- **Venom Overdrive A · Liquid Venom.**
  - Wind-up (DiloOverdriveAt .. StartAt): a goo blob swells at the Venom Reactor core, drops are drawn in, and it drips.
  - On (StartAt): a big splash (impact × 2.2), a splash ring of 18 studs and a flash.
  - Until DiloOverdriveUntil: venom drips off the body (34/s × 1.8) and fumes from the mouth.
  - Spit darts during it are goo darts (DiloFX 1.3 hand-off).
  - Recovery (Until): the core drips and steams for 1.2 s.
- **Cobra Spring take-off** (DiloFX 1.3, switch DiloFXTakeoffEnabled): at the leap launch (the owner's JumpLaunchCount change; others: JumpStartedAt + JumpWindup), 6 sand dust puffs at the feet.
  - This replaces the mockup's B-style ring: the Dilo's leap is not a part, so no family colour.

## Tasks
### Task 1 — Cobra Spring numbers · Mode: Wired (data)
- **Files:** tools/dilo_generator.py (KIT_V113, VERSION 1.13, `--v112`), src/shared/Models/DiloModelData.luau.
- [ ] Generator: KIT_V113 = {JumpWindup "0.12", TurnLimitRate "540", JumpBoost "45"} on top of 1.12. Header line v1.13. `--v112` gives 1.12 byte-identical.
- [ ] Install DiloModelData in Studio, then verify the hash.
- [ ] Play measurement on the flat pad:
  - Press → launch ≤ 0.15 s, air ~0.6 s, horizontal 95–96 studs/s, leap ≥ 55 studs, height 8–10.
  - TurnLimitRate attribute 540.
  - DiloPose crouch follows JumpWindup (it reads the attribute).
- **Acceptance:** the numbers above. The Raptor, Pachy and Therizino jump numbers are unchanged.

### Task 2 — DiloPartsVFX 1.0 frame + DiloMovesFX 1.6 hand-off · Mode: Logic + Wired
- **Files:** src/client/DiloPartsVFX.client.luau (new), src/client/DiloMovesFX.client.luau, tools/tests/DiloPartsVFX.spec.luau.
- **Interfaces:** the DiloPartsVFX script attributes:
  - `DiloPartsVFXEnabled`, `DiloPartsVFX_<id>Enabled` for dgatling, dmortar, dhiss, dspine, dpump, djets, dover (default true).
  - Numbers: `DiloPartsVFX_maxParts` 350, `DiloPartsVFX_rateMul` 1.
  - DiloMovesFX 1.6: `local function owned(id)` = the sibling DiloPartsVFX exists, `DiloPartsVFXEnabled` ~= false and `DiloPartsVFX_<id>Enabled` ~= false.
  - Each old spawn returns early when owned. Lines 211 / 226 gatling, 236 / 245 / 257 mortar, 285 spine, 317 over burst, 473 hiss, 511 / 525 pump effects, 531 / 593 jets spark + trail, the thrOn flame.
  - Motion, pips, piston, cones and core keep running.
- [ ] The watcher (every Dilo character's attribute signals), the part budget, the helpers (Ball / Neon pieces, Beams, emitters with the built-in textures), and the spec.
- **Acceptance:**
  - Each part switch off → the old 1.5 effect for that part shows again.
  - Spec PASS.
  - No new console errors.

### Task 3 — Liquid Venom family: Gatling A, Spine A, Overdrive A (+ DiloFX 1.3 goo darts and the take-off dust) · Mode: Wired
- [ ] Build the three tracks to the specs above. DiloFX 1.3 adds the Overdrive dart hand-off (switch `DiloFXOverDartHandoff`) and the take-off dust (switch `DiloFXTakeoffEnabled`).
- **Acceptance:**
  - Play with each part slotted (test layer): every phase draws.
  - Screenshots next to the mockup frames.
  - Parts stay under the budget with all 3 firing.

### Task 4 — Reactor Glow family: Hiss B, Pump B, Jets B · Mode: Wired
- [ ] Build the three tracks to the specs above.
- **Acceptance:**
  - Every phase draws.
  - The silence ring follows each silenced dino and ends at SilencedUntil.
  - The shell blocks flash.
  - The jets plasma follows the dash on the owner and on another client.

### Task 5 — Chem Warfare: Mortar C · Mode: Wired
- [ ] Build to the spec, including the hazard ring wedges, laser, canister and cloud.
- **Acceptance:**
  - The cloud lasts DiloPartMortarTime and matches DiloPartMortarRadius (36 studs wide at max).
  - It lands where the server says.

### Task 6 — Studio check + docs · Mode: Wired
- [ ] All 7 in one Play, the budget check, and the Edit hash = repo.
- [ ] VERSIONS.md, ATTRIBUTES.md.
- [ ] Ticket notes, then report to Kepu (not published).

## Deterministic map
- Per part, the stamp arrives:
  - Owned (switches on) → the new effect.
  - Not owned → the old one.
  - The stamp is older than 1 s (late join) → nothing, as 1.5 does today.
- Character not a Dilo / part not slotted → nothing (no DPart model, same as now).
- Budget reached → the oldest effect parts are destroyed first. The effect keeps running with fewer pieces.
- Overdrive dart:
  - Owner in Overdrive and DiloPartsVFX over on → a goo dart.
  - Overdrive ended mid-flight → the dart keeps the look it started with.
- Cobra Spring: data only. JumpTest / JumpServer / DiloPose read the attributes; there are no new branches.

## Red-team (plan-red-team pass)
1. **The phone budget.**
   - Risk: Mortar C's smoke cloud (~50 big puffs for 5 s) and Overdrive A's drips (8 s) are the heaviest pieces. Two Dilos in a fight could drop phone FPS.
   - Mitigation: the 350-part cap and `DiloPartsVFX_rateMul`. The cloud uses ParticleEmitters, not parts, for the puffs. The Task 6 acceptance includes a part count with all 7 firing.
2. **The turn rate goes against an earlier pick.**
   - Risk: on 2026-11-09 Kepu picked "360 (Pachy)" for the Dilo turn rate. Cobra Spring sets 540 (the Raptor's).
   - Mitigation: flagged to Kepu before "Build". A 360 fallback is one attribute.
3. **Leap balance.**
   - Risk: +45 push makes the Dilo the longest ground leaper (Raptor ~10 push). With a 0.25 s cooldown it can chain leaps at 95.7 studs/s in the air (run 50.7).
   - Mitigation: Kepu picked the number. JumpBoost is one attribute to tune after playing.
4. **Two scripts drawing one part.**
   - Risk: if the hand-off check misses a spawn, both effects draw.
   - Mitigation: the spec lists every gated line. Task 2 acceptance toggles each part's switch both ways in Play.
5. **Mockup → Roblox look gap.**
   - Risk: the mockup uses additive glow sprites that Roblox can't match exactly.
   - Mitigation: Neon + Highlight + LightEmission emitters. A screenshot comparison per part is in Tasks 3–5. Kepu judges after the build.
