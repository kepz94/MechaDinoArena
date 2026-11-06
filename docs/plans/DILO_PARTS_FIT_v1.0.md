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

## Build notes (2026-11-06, Studio session 1c3f1b6b)
- Installed (Studio hash = repo): DiloPartsServer 1.1 24676/828178339, DiloMovesServer 1.3 40716/354255161, MechaButtons
  1.38 103585/226667642, DiloJetsLaunch 1.1 10068/378073413, DiloPose 1.4 41884/445619975, DiloMovesFX 1.2 36776/976610925.
  All compile. Not published.
- Measurement (Play, owner client, steady state; 125 points per piece; share of the part's volume inside visible body parts;
  mount brackets excluded and listed; max over every sample taken while a part pose ran, combos A = Gatling / Mortar / Hiss /
  Spine and B = Overdrive / Mortar / Pump / Jets, each move pressed 1-3 times through the real keys R / C / T / V):

| Part | Before (1.0) | Idle | Own move pose | Max, any move pose | Part vs part max | Brackets in body |
|---|---|---|---|---|---|---|
| Gatling | 6% | 0% | 5.5% (p_gatling) | 5.5% | 3.8% (drum in the mortar tube) | 1.6-37.6% |
| Mortar | 24% | 0.1% | 0.1% | 0.2% | 2.2% | 32.6% |
| Hiss | 20% | 0% | 0.1% (p_hiss, frill open) | 0.4% | 0.2% | 2.4% |
| Spine | 10% | 0% | 0.2% (p_spine, frill open) | 1.3% (p_hiss) | 2.9% | 40-40.4% |
| Pump | 0% | 0.2% | 0.2% | 0.2% | 0% | - |
| Jets | 50% | 0% | 0% | 0% | 0% | 60% |
| Overdrive | 42% | 0% | 0% | 0.1% (p_jets) | 0% | 15.7% |

- Gatling: the same seat measured 1.1% (p_gatling) in the run before; it goes over 5% only while HeadLeadPose turns the head
  into a turn (Jaw_lower yawed 18 deg, 0.29 studs toward one gun in the worst frame) and the lower jaw swings over a barrel.
  Not solved by any seat tried (up, down, back, out, tilt -4..+10); needs a design call (gun further from the jaw line, or less
  head lead while the Gatling is slotted).
- Seats tuned in Play beyond the rest-pose fit (all inside 1.1, same switch): Overdrive fins z +0.5 (Jaw_sac / Neck_1 in
  p_over / p_pump), core 0.45 down the chest face (Neck_1 in p_jets); Pump 0.15 forward (new SEAT.dpump: its rear ring met
  the Tail Booster when the tail lifts in p_pump); Gatling 6 deg muzzle-up, 0.17 out, 0.13 back; Hiss amp y 0.2 (Torso_chest in
  p_mortar); Spine magazines x 0.15 (Jaw_lower in p_mortar).
- Jets (owner client, Heartbeat log): DiloJetsLaunchState "dash" and the flame on in the first frame after the press (0.015
  s), the root moving at the second (0.032 / 0.033 s); DiloJetsPressLag 0.015 / 0.018; moved 38.4 / 38.7 studs of 40 (stops
  2 studs short, as 1.0: 38.8); server delay 0. Switches off: DiloJetsInstantEnabled false -> delay 0.34, first move 0.415 s;
  DiloJetsThrusterFXEnabled false -> no flame (DiloJetsFlameOn unchanged); DiloPartsSeatV2Enabled false -> Overdrive rebuilt
  with 22 pieces (no brackets). Console: no script errors.
- Fixed in Play: the first Jets press after spawning was not started on the press (DiloPartJetsLeft is published after the
  first use only); DiloJetsLaunch 1.1 now reads a missing DiloPartJetsLeft as DiloPartJetsCharges. Verified: first press after
  spawn predicted, first move 0.033 s.
- Screenshots (Studio screen_capture): game camera dfit_A_gamecam, dfit_A_gamecam_zoomed; close-ups (camera held for the
  shot: ShoulderCam / TurnLimit off, root anchored on the client) dfit_A_neck_34front, dfit_A_side_X, dfit_A_top,
  dfit_A_frillopen_34_forced (DiloFrillTest "open"), dfit_B_chest_34front, dfit_B_side_X, dfit_B_top, dfit_B_tail_34rear; Lab
  dfit_lab_card; Jets djets_burst_gamecam_forced, djets_burst_side_forced (DiloJetsLaunchState held at "dash": the real burst
  is 0.27 s) next to thrusters_burst_gamecam_live (a real Raptor Thrusters press); Edit harness dfit_all7_side_X,
  dfit_all7_34front, dfit_all7_top.
- Deviations: MechaButtons 1.38 + DiloJetsLaunch 1.1 added (delay 0 alone still waits a network round trip); the Play-pose
  seat changes above; the jets FX shots are forced (state held), not a live burst.
- Test hygiene: SkillServer SkillSaveEnabled / SpeciesServer SpeciesRememberEnabled false for the Play sessions only (both
  back to unset); slots restored (Raptor adrenaline / screech / shield / cloak, Dilo dgatling / dmortar / dhiss / dspine); no
  ZZ_ objects left.
