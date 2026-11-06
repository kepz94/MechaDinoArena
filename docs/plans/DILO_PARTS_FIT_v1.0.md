# Mecha Dino Arena v1.0 — Dilo parts: sit on the body + Spring Jets like the other dashes

**Ask (Kepu 2026-11-06 12:22, Lab screenshot):** the Dilo mecha parts "are not sitting properly on its body ... parts of it
that are sinking into the body and it just looks sloppy"; the Spring Jets is "the only different dash ... a pause before it
takes off ... the vfx for it is total shit"; apply the lessons (quality game mech parts, integrated, checked from the game
camera and up close; consistent with the older dinos).
**Picks (12:2x):** Jets "Instant burst + Thrusters FX"; fit "Yes, reseat + screenshots".

## Measured (Studio Play 2026-11-06, session 1c3f1b6b, each part built by its BuildPreview on a still Dilo clone;
## share of the part's volume inside visible body parts, 125-point sample per piece)
| Part (look) | Inside body | Worst pieces |
|---|---|---|
| Spring Jets (C Tail Booster) | 50% | booster body / nozzle / pips 32–100% in Tail1 |
| Venom Overdrive (A Venom Reactor) | 42% | back fins 40–100%, core 36% (Torso) |
| Toxin Mortar (C Chest Launcher) | 24% | tank 36%, a piece 100% (Torso) |
| Sonic Hiss (A Hood Speakers) | 20% | 26 speaker pieces 30–82% (Neck) |
| Spine Burst (C Frill Barbs) | 10% | neck magazines 30% |
| Venom Gatling (C Twin Hood Repeaters) | 6% | — |
| Antivenom Pump (A Back Pump) | 0% | — |

## Dash grounding
- Raptor Thrusters (the game's dash): instant on press, MechaButtons client LinearVelocity, 2x run speed boost; FX in
  MechaServer (FlameAt + ParticleEmitter "Flame" with Roblox's fire texture, booster width x 2.4, life 0.4–0.7 s; neon jets;
  speed lines + sound, MechaServer 1.2) and the BoostPose lean. Pachy Servo Dash follows the same boost path.
- Dilo Spring Jets today: DiloMovesServer `JETS_DELAY 0.34` (:508) before the move, then DiloJetsLaunch slides the root
  40 studs at JETS_SPEED 150 (0.15–0.3 s); its own DiloMovesFX flame / mist.

## Global constraints
Additive, one switch per change, version branding (headers, VERSIONS.md, ATTRIBUTES.md); install by multi_edit + hash
verify + compile; one-player Play tests (slots saved / restored, saving off); publish only on "Publish". Re-read live versions.

## Do-not-touch
The picked looks themselves (same shapes, colours, parts), the Jets' numbers (40 studs, 3 charges, 6 s per charge, poison
trail), MechaServer / MechaButtons Thrusters code (the Jets reuse their FX recipe, they are not edited), other dinos.

## Task 1 — DiloPartsServer next: reseat every part (Wired) — MDA-328
- Move each part piece out of the body to sit on its surface, with a mount bracket (a flat plate / clamp) where it meets the
  body; keep the picked look. Target: every part ≤ 5% of its volume inside the body (brackets excluded), measured by the
  same Studio check, in the idle pose and in the move pose that moves the part (frill open for Hiss / Spine).
- Check from the default game camera (ShoulderCam, +X side) and up close (3/4, side, top), Lab card included; send Kepu the
  screenshots before publish. Switch `DiloPartsSeatV2Enabled` (false = today's seats).

## Task 2 — Spring Jets: instant burst + Thrusters FX (Wired) — MDA-329
- DiloMovesServer next: `JETS_DELAY` 0.34 -> 0 behind `DiloJetsInstantEnabled` (the burst starts on the press); distance,
  charges, recharge and trail unchanged. DiloPose next: the jets pose drops its wind-up (lean into the burst at once).
- DiloMovesFX next: the Jets flame = the Thrusters recipe (fire-texture ParticleEmitter sized and timed like MechaServer
  1.2's, out of the Tail Booster nozzle), plus the Thrusters speed lines + sound; the old jets flame / mist off behind
  `DiloJetsThrusterFXEnabled`. Poison trail kept.
- Play: press -> moving the same frame (no pause), 40 studs, FX side by side with a Raptor Thrusters press.

## Red-team
- Reseating moves parts outward: they can now poke out of the silhouette or clip each other on the busy neck / chest spots
  — the 4-slotted combinations are checked from the game camera, not just one part at a time.
- A 0-delay jets burst on a 0.27 s slide can feel like a teleport; the Thrusters flame / lines / sound carry the read (the
  same kit the other dashes use). Accepted with the pick.
