# Mecha Dino Arena v1.0 — Herrerasaurus model

**Goal:** the fourth dino's body: a block-style Herrerasaurus that looks nothing like the raptor and is skin-ready from the first build.
**Intent (Kepu 2026-10-30):** "a utility Dino someone that's a Pain in the ass to deal with but easy to kill" · "the most mecha utility and the fastest in the game" · 40 HP, a bit smaller than the raptor; ATTACK = hit-and-run slash; hard to catch + climber; day 1 · look rejected twice as raptor-like ("It should look really different not even closely the same") -> picked "Hunched goblin" + "Frill-necked trickster" -> v0.4 "Wow I love this so much let's choose C just to keep it somewhat realistic".
**Chosen direction:** v0.4 goblin + frill body, Classic = C Swamp olive. Mockup `docs/mockups/herrera_model_options.html` (Studio renders at 2x).
**Architecture:** same pipeline as the raptor / pachy: `tools/herrera_generator.py` writes `src/shared/Models/HerreraModelData.luau` (rig 1.3: the 17 segments / joint names, so poses, hitboxes and mecha mounts keep working); `DinoModelBuilder` builds it. Every visible block uses exactly one colour of a role; SkinCatalog gets the Herrera roles.

## Global Constraints
- Additive. No change to the raptor / T-Rex / pachy data, DinoModelBuilder or any gameplay script.
- Versions: HerreraModelData 1.0 (generator 1.0), SkinCatalog 1.4, spec 1.4, display installer 1.0.
- Model only: gameplay attributes are the T-Rex's (inherited like the raptor / pachy) with every move off (Bite, Pounce, Ram, Roar, Jump, Creep false), DisplayName "Herrera". Kit (40 HP, fastest, hit-and-run slash, climbing), playable species, scaling, gait and Lab come in the next plans.
- Skin rule: each colour group has its own hex, no hex shared, none equal to a never-paint colour (teeth E8E2D2, pupils 111111, mouth 6E342E, HRP A3A2A5).
- Test in Studio with the tools only; Kepu publishes.

## Colour groups (Classic = Swamp olive)
main 6E6A3A · stripes 2F3320 (stripes, quills, tail band 1, snout line) · belly D3C89A · markings B8414A (throat sac, horns, frill rim, spots) · limbs 5A5530 · claws 2C2620 · eyes E8C547 · tailbands B9B26A · mask 262A1A (cheeks, nostrils, frill spokes) · frill C9572E · never-paint: teeth E8E2D2, pupils 111111, mouth 6E342E.

## Task 1 — Generator 1.0 + HerreraModelData 1.0 · Mode: Logic
**Files:** `tools/herrera_generator.py` (v0.4 mockup geometry kept; default palette olive; full data output), Create `src/shared/Models/HerreraModelData.luau`.
**Acceptance:** 153 parts, 17 segments, 17 joints with the raptor names; length 11.2 (22.4 at 2x vs the raptor's 25.4), hip 2.975, lowest point on the ground; generator asserts: 10 distinct role hexes, none never-paint, every block colour a role or never-paint.

## Task 2 — SkinCatalog 1.4 · Mode: Logic
**Files:** `src/shared/SkinCatalog.luau`, `tools/tests/SkinCatalog.spec.luau`.
**Steps:** spec 1.4 first (Herrera roles; every HerreraModelData colour covered; 10 roles, no hex shared, none never-paint; classic round trip; a missing species list fails instead of erroring) -> FAIL on 1.3 -> ROLES.Herrera + SKINS.Herrera {classic} -> PASS.
**Acceptance:** spec PASS.

## Task 3 — Display model · Mode: Wired
**Files:** Create `tools/display_herrera_install.luau`.
**Steps:** Workspace.DinoArcade_Herrera with "Herrera_Display" anchored, scaled 2x, on flat grass west of the pachy displays (90, 876) facing the spawn; StudioOnly script destroys it on live servers. Data module in ServerStorage.DinoArcade.Models.
**Acceptance:** feet and toes on the grass (raycast), Kepu looks at it in Studio.

## Next: scurry gait (separate plan, mockup first)
Kepu 2026-10-30: "This Dino will have a gallop run not a two legged walk. He stands on two legs when idle but does a scurry type of run like a regular iguana does." Reading: idle = bipedal stance (this model's rest pose); any movement = on all fours. Options for the animated mockup: A iguana scurry (sprawled, diagonal pairs, body S-wave, tail whip) / B bounding gallop (front pair then back pair, back arches). The model needs no change for it: the dangling arms (claw tips ~0.8 studs above the ground at scale 1) reach the ground with ~25 degrees of forward body pitch; the rig's single-segment arms swing from the shoulder.

## Red-team (single-ticket change, one paragraph)
1. **Herrera colours vs another dino's** -> roleOf is per species; the spec checks no hex shared inside Herrera and none never-paint.
2. **Frill plates are thin (0.09 studs at scale 1)** -> at 2x they are 0.18 thick; visible in every Studio capture so far; a skin can only change Color / Material.
3. **Inherited T-Rex gait on a hunched body** -> accepted for the model step (display is static); the scurry gait plan replaces it.
