# Mecha Dino Arena v1.0 — Troodon Flap & Glide (JUMP: leap + 2 air flaps, then an automatic glide)

**Goal:** the troodon's JUMP becomes a triple jump on its feathered arms: a leap with a wing beat, two more beats in the air (each tap of JUMP), and after the 3rd beat it glides down by itself like the Herrera's Glider Wings. Replaces the Evade Hop.
**Intent (Kepu 2026-11-06 17:38):** "why is the leap only designed to be backwards. Matter of fact have it be able to flap up and basically start to fly but more like a triple jump and glide since it has feathers" · glide start "Glides by itself after the 3rd flap" · 17:50 "Yes do both recommended. Build".
**Chosen direction:** mockup `docs/mockups/troodon_kit_options_v0.2.html` J3 · Flap & Glide (artifact 5AsfWztKYHXu5dJjELAqtB v2; keys TF_UP / TF_DOWN / TF_GLIDE in `tools/troodon_kit_mockup/app_tail.js`).
**Tickets:** MDA-340 (T11) · 341 (T12) · 342 (T13) · 343 (T14).
**Architecture:** reuse, not new movers. The flaps are JumpTest / JumpServer's Mecha Legs double jump (JumpDoubleEnabled, 1 per leap) extended to N air jumps by a new attribute; the glide is GliderTest (the Herrera's Glider Wings) with a new auto-start mode. Poses in TrooPose; a feather puff per beat in TrooFX.

## Global Constraints
- Additive, one switch per change; other dinos unchanged (the pachy's 1 double jump and the Herrera's held-JUMP glide stay as they are).
- Versions bump from live: TroodonModelData 1.3 (generator 1.3), JumpTest 1.6, JumpServer 1.5, GliderTest 1.1, SkillEffects next, TrooPose 1.1, TrooFX 1.1, AbilityBar / ArenaTouch only if the troodon JUMP pips need hiding.
- Numbers (troodon model attributes): JumpHopBack false; JumpCharges 0; JumpCooldown 0.5; JumpLaunchPower 59 (the raptor's ~11 studs up at the 2x body); JumpDoubleEnabled true; JumpAirJumps 2 (new: air jumps per leap; missing = 1, the pachy rule); JumpDoubleMul 0.80 (~7 studs per flap); JumpDoubleForward 0; GliderEnabled true; GliderAuto true (new: the glide starts by itself at the top of the last air jump, no JUMP hold); GliderFall 8; JumpStaminaCost 0; TenoLeapOnJump false.
- No landing FX. Wind-up → action → result → recovery on each beat (up-stroke → down-stroke).
- Install via multi_edit, hash verify, one-player Play; publish only on "Publish".

## Do-not-touch
HerreraMovesServer / SlashServer / HerreraPartsServer behaviour on the Herrera (the troodon must not get the bat-membrane wings or the slash dive), MechaLegs on the pachy, BotServer, TrooAttackServer.

## Deterministic map
| State | Condition | Result |
|---|---|---|
| JUMP on the ground | JumpEnabled, ≥ 0.5 s since the last leap | leap (~11 studs), wing down-stroke pose + feather puff |
| JUMP in the air | a new press, air jumps used < JumpAirJumps | flap: vertical speed = JumpLaunchPower x JumpDoubleMul, up-stroke → down-stroke + puff; server JumpDoubleCount +1 |
| JUMP in the air, all used | 2 flaps used | nothing |
| Last flap's top | GliderAuto, vertical speed ≤ 0 after the 2nd flap | glide: fall capped at GliderFall, forward at run speed with no stick (GliderTest), steer with the stick; TF_GLIDE pose |
| Glide end | landing, stun / pin, death | glide off; flaps reset on landing |
| Fewer flaps | lands before the 2nd flap | no glide (plain landing) |
| Other dinos | JumpAirJumps / GliderAuto absent | exactly as today |

## Tasks
1. **Troodon T11 — data + air jumps · Wired:** TroodonModelData 1.3 (the numbers above); JumpTest 1.6: JumpAirJumps (default 1) air jumps per leap, each a new press, re-using the double jump code; JumpServer 1.5: accept up to JumpAirJumps double-jump requests per leap ("used" after that). SkillEffects: species Troodon keeps JumpDoubleEnabled / JumpAirJumps / JumpDoubleMul / GliderEnabled / GliderAuto / GliderFall (the leap writer and the Glider Wings / Mecha Legs writers reset them on dinos without the part). Switches JumpAirJumpsEnabled, JumpServerAirJumpsEnabled, SkillEffectsTrooFlapKeepEnabled. **Acceptance:** leap ~11 studs, flaps +7 ± 1.5 each, a 4th press does nothing; pachy still 1 double jump; raptor / dilo / therizino / teno / Herrera jumps unchanged.
2. **Troodon T12 — auto glide · Wired:** GliderTest 1.1: while GliderAuto is true the glide starts at the top of the last air jump with no hold, and ends only on landing / stun / pin / death (not on JUMP release); the Herrera's held mode unchanged. Check: no bat-membrane wings or slash dive on the troodon (HerreraPartsServer / SlashServer gate on species or parts; add a species gate behind a switch only if Play shows them). Switch GliderAutoEnabled. **Acceptance:** fall ≤ 8.5 studs/s, forward at run speed with no stick, steerable; Herrera glide unchanged.
3. **Troodon T13 — poses + puff · Wired:** TrooPose 1.1: TF_UP / TF_DOWN on each beat (leap + 2 flaps), TF_GLIDE while gliding (mockup keys, parity check); TrooFX 1.1: a puff of loose down on each beat. JUMP pips: hidden for the troodon (no charges). Switches TrooPoseFlapEnabled, TrooFXPuffEnabled. **Acceptance:** captures (held) from the game camera and up close next to the mockup frames; other dinos' poses unchanged.
4. **Troodon T14 — docs + check · Wired:** VERSIONS / ATTRIBUTES / ROSTER; full jump regression on all eight dinos; captures in docs/reference/troodon/.

## Red-team (one paragraph; Kepu said "Build" on the recommendation)
How it fails: (a) SkillEffects' part writers reset GliderEnabled / JumpDoubleEnabled on a dino that doesn't own the part, so the troodon silently loses the flaps or the glide after a skill refresh — covered by the T11 keep guard and a check after a refresh; (b) the glide reuses Herrera code that also drives the bat wings and the slash dive — T12 checks both never fire on the troodon; (c) a ~22-stud peak and ~170-stud glide is the most mobility in the game — every number is an attribute (flap height, fall rate) for tuning after play; (d) the backward hop (JumpHopBack) stays in JumpTest behind its switch, just unused by the troodon.
