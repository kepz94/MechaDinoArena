# Mecha Dino Arena v1.0 — Tenontosaurus model

**Goal:** the fifth dino's body: a cartoon, instantly recognisable block-style Tenontosaurus with a giant tail (its future attack), skin-ready from the first build.
**Intent (Kepu 2026-10-31):** "I want to add the teno. I want you to make a model for it that's full of character and true to the build of the teno with character. A long tail that will be used for its attack." · size "~34 studs" · stance "4 legs, rears up" · v0.1 -> "The tail isn't long enough. I want this to be cartoonish with a lot of character super easily identifiable" · v0.2 -> "I like the goofy one but I need the tail to be more longer and thicker" · v0.3 -> "Yes, build v0.3".
**Chosen direction:** C "Goofy Noodle" v0.3 — prototype `docs/mockups/teno_model_options.html` (three.js, the generator's own export). Huge googly eyes with raised brows, yellow grin beak, little head crest, neck held up, teal back with red stripes, tail swept up in a big S-curve with a hooked tip; tail x1.22 longer / x1.45 thicker than v0.2 (about two-thirds of the length).
**Architecture:** same pipeline as the raptor / pachy / Herrera: `tools/teno_generator.py` writes `src/shared/Models/TenoModelData.luau` (rig 1.3: the 17 segments / joint names, so poses, hitboxes and mecha mounts keep working; Arm segments are the front legs); `DinoModelBuilder` builds it. Every visible block uses one colour of a role; SkinCatalog gets the Teno roles.

## Global Constraints
- Additive. No change to the raptor / T-Rex / pachy / Herrera data, DinoModelBuilder or any gameplay script.
- Versions: TenoModelData 1.0 (generator 1.0), SkinCatalog 1.7, SkinCatalog.spec 1.6, display installer 1.0.
- Model only: gameplay attributes are the T-Rex's (inherited like the others) with every move off (Bite, Pounce, Ram, Roar, Jump, Creep false), Species "Teno", DisplayName "Tenontosaurus". Kit (tail attack, health, speeds), playable species, quadruped gait + rear-up, Lab and skins come in later plans.
- Size: body kept at the v0.2 scale (BODY_K 0.84); 24.9 studs long at scale 1 (tail 16.4 = 66%), hip 3.3; doubled in game like the others (~50 studs; the T-Rex is 40, most of the teno's length is tail).
- Skin rule: each colour group has its own hex, no hex shared, none equal to a never-paint colour (pupil 111111, mouth 6E342E, eye shine F5F5F0, HRP A3A2A5, E8E2D2, 963C3C).
- Install via Studio tools, verify by hash + loadstring; test in Studio only. Publish only on Kepu's "publish".

## Do-not-touch
- DinoModelBuilder, the other dinos' ModelData, SpeciesServer (the teno is not playable yet), SkinServer, Lab, MainMenu.

## Colour groups (Classic = Goofy Noodle)
main D99A4A · dorsal 2E8C8A (back, head top, neck top, brows) · belly F6E6BE · bands C83A3A (flank + tail stripes, head crest) · limbs B87A36 · claws 3A2A1E (hooves) · eyes FFFFFF · beak F2D04A · scutes 1E6462 (spine knobs) · mask F2B8A0 (cheeks, nostrils) · never-paint: pupil 111111, mouth 6E342E, eye shine F5F5F0.

## Task 1 — Generator 1.0 + TenoModelData 1.0 · Mode: Logic
**Files:** `tools/teno_generator.py`, Create `src/shared/Models/TenoModelData.luau`.
**Acceptance:** 122 parts, 17 segments, 17 joints with the shared names; length 24.92, tail 16.40, hip 3.298, lowest point on the ground; generator asserts 10 distinct role hexes, none never-paint, every block colour a role or never-paint.

## Task 2 — SkinCatalog 1.7 · Mode: Logic
**Files:** `src/shared/SkinCatalog.luau`, `tools/tests/SkinCatalog.spec.luau`.
**Steps:** spec 1.6 first (Version 1.7; Teno roles; every TenoModelData colour covered; 10 roles, no hex shared, none never-paint; classic round trip) -> FAIL on 1.6 -> ROLES.Teno + SKINS.Teno {classic} -> PASS.

## Task 3 — Display model · Mode: Wired
**Files:** Create `tools/display_teno_install.luau`.
**Steps:** Workspace.DinoArcade_Teno with "Teno_Display" anchored, scaled 2x, on flat grass near the other displays, facing the spawn; StudioOnly script destroys it on live servers. Data module in ServerStorage.DinoArcade.Models.
**Acceptance:** feet on the grass, Kepu looks at it in Studio (captures in docs/reference/teno/).

## Deterministic map
| State | Condition | End state |
|---|---|---|
| Studio Edit | installer run | DinoArcade_Teno / Teno_Display on the ground, 2x |
| Live server | RunService:IsStudio() false | StudioOnly destroys the folder |
| SkinCatalog roleOf("Teno", c) | c = a role hex / never-paint / other | role / nil / nil |

## Red-team (single-ticket-sized model step, one paragraph)
1. **Size:** ~50 studs in game is longer than the T-Rex; the hitbox / camera for a long tail are kit-plan questions (accepted: Kepu asked for longer and thicker twice).
2. **Quadruped on a biped rig:** the Arm segments are the front legs and reach the ground at rest; walk / rear-up poses are the gait plan's job (the display is static).
3. **Pure white eyes (FFFFFF)** sit next to the never-paint eye shine F5F5F0 — different hexes, so roleOf stays exact; the spec checks it.
