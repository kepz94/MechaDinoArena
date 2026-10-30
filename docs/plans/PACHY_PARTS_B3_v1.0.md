# Mecha Dino Arena v1.0 — Pachy parts batch 3 (Dome Visor, Ink Shooter, Overclocked Servo Dash)

**Goal:** the pachy gets 7 button parts for its 4 slots (like the raptor), so players pick different builds.
**Chosen direction:** mockup docs/mockups/pachy_parts_b3_options.html, Kepu 2026-10-30 "All the recommended ones":
Visor A "Armored faceplate", Ink A "Neck ink tank + barrel", Dash A "Hip thrusters", steps as listed there.
**Architecture:** three new pachy-only live slot parts (SkillTree OWNER Pachy, LIVE_MECH, BUTTONS), each with its own server
script (request remote, look on the dino, Lab card through BuildPreview_<id>), SkillEffects writing their attributes while
bought AND slotted, MechaButtons / AbilityBar timed-part entries. Shared hit rules go through the BoneCrest module.

## Kepu's answers (2026-10-30)
- "Okay let's do the dome visor for sure"; "How about an ink shooter that blinds your enemy for 2 seconds. Turns their screen
  black"; Overclocked Servo Dash (Burst Sprint): "An active thruster burn that gives an instantaneous burst of top-speed
  forward velocity. It instantly overrides the headbutt empty-charge speed debuff for 1.5 seconds, letting you quickly escape
  after missing a charge."
- Ink: fully black screen; aimed shot like the Grappling Hook, first dino hit; bots lose you; steps II 80 studs, III 11 s,
  star splash 6 studs; same mode rule as the Shock Cannon (Sandbox: bots only; Arena: players and bots).
- Visor blocks melee from the front (bites, pounces, headbutts, hook smash) AND the Shock Cannon.
- Dash: "Launch + steerable speed": an instant shove forward, then 1.6x run speed for 1.5 s you can steer.

## Steps
| Part | I | II | III | star |
|---|---|---|---|---|
| Dome Visor (visor, Defense) | blocks all front hits for 1.5 s, recharge 14 s | 2 s | recharge 10 s | a blocked hit knocks the attacker back |
| Ink Shooter (ink, Engineering) | 60 studs, blind 2 s, recharge 15 s | 80 studs | recharge 11 s | splash: everyone within 6 studs of the hit |
| Servo Dash (servodash, Speed) | launch + 1.6x run for 1.5 s, cancels the headbutt self-slow, recharge 12 s | 2 s | recharge 8 s | ending the dash refills one headbutt charge |

## Tasks (build order: Dash, Visor, Ink)
1. SkillTree 1.32: paths servodash / visor / ink (+ effects fields). Switch per part.
2. SkillEffects 1.24: ServoDash*, Visor*, Ink* attributes (bought AND slotted on a pachy).
3. ServoDashServer 1.0 + SprintTest (speed + self-slow cancel) + launch client + HeadbuttServer refill hook (star).
4. VisorServer 1.0 + BoneCrest 1.2 (visor = front hits do nothing) + HeadbuttServer / HookServer / ScreechServer checks.
5. InkServer 1.0 + InkBlind client (black screen) + BotServer (inked bots drop and can't pick targets) + ModeRules.
6. MechaButtons / AbilityBar entries; BuildPreview_<id> for all three (LabPreviewMissing must stay empty).
7. Studio test, docs rows, commit / push. Not published until Kepu says so.

## Red-team (folded in from the answers)
- "Front" = the BoneCrest cone (60 degrees of where the pachy faces), so Visor and Bone Crest agree on what the dome covers.
- A blind can't stack forever: a new ink hit sets InkedUntil = max(current, now + 2).
- Ink on players follows ModeRules.canAffect like the Shock Cannon (no player blinding in the Sandbox).
- Slots: the test layer will re-slot 7 live parts into 4 slots; which 4 it picks is its own rule (not changed here).
