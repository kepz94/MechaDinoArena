# Mecha Dino Arena v1.0 — Pachycephalosaurus model

**Goal:** the third dino's body: a block-style Pachycephalosaurus that is skin-ready from the first build.
**Intent (Kepu 2026-10-30):** "lets work on the next down. the pachy. lets work on the model remember these models were making from this point forward have to be made with skins in mind." · inspo `docs/reference/pachy/inspo_1_olive_knobs.webp`, `inspo_2_ember_spikes.jpg` · "we'll do number 1 as he default, the spikes can be the fully upgraded attack stat. lets keep it at 15 studs" · size: "A bit bigger than raptor" (built at 15 studs, doubled in game like the raptor -> ~30; raptor 25.7, T-Rex 40).
**Chosen direction:** knob ring head (photo 1) by default; spike set built in but hidden; mockup `docs/mockups/pachy_model_options.html`.
**Architecture:** same pipeline as the raptor: `tools/pachy_generator.py` writes `src/shared/Models/PachyModelData.luau` (rig 1.3: the 17 segments / joint names of the T-Rex and raptor, so poses, hitboxes and mecha mounts keep working); `DinoModelBuilder` builds it. Every visible block uses exactly one colour of a role; SkinCatalog gets the Pachy roles.

## Global Constraints
- Additive. No change to the raptor / T-Rex data, DinoModelBuilder or any gameplay script.
- Versions: PachyModelData 1.0 (generator 1.0), SkinCatalog 1.2, spec 1.2, display installer 1.0.
- Model only: gameplay attributes are the T-Rex's (inherited like the raptor's) with every move off (Bite, Pounce, Ram, Roar, Jump, Creep false). Abilities, playable species, scaling and Lab come in the next plan.
- Skin rule (for every new dino from now on): each colour group has its own authored hex, no hex shared between groups, and never-paint colours (pupils 111111, mouth 6E342E) are not used by any group.
- Test in Studio with the tools only; Kepu publishes.

## Colour groups (Classic)
main 7A6A4E · stripes 3E5A55 · belly C8B898 · dome E6DCC4 · knobs 8C7A5A (knobs and spikes) · mask 3F6F7A · limbs 5E5240 · claws 2E2620 · eyes 8A2A1E · never-paint: pupils 111111, mouth 6E342E.

## Spikes
Parts named `Head_spike*` (colour group knobs), Transparency 1 and CanCollide false in the data. Model attribute `PachySpikes` (false). Showing them when the attack line is maxed is wired in the abilities plan (the pachy's attack path does not exist yet).

## Task 1 — Generator + PachyModelData 1.0 · Mode: Logic
**Files:** Create `tools/pachy_generator.py`, `src/shared/Models/PachyModelData.luau`.
**Steps:** dino-space layout (x forward, y up, z left, hip at origin, HIP 4.0): thick upright torso, thick neck, big head with 3-tier bone dome, knob ring (back, sides, cheeks, snout), small jaw, short arms, strong legs, 5-segment level tail with stripes; joints as the raptor. Run -> bounds printed.
**Acceptance:** length 14.5..15.5, ground at -HIP (toes bottom), 17 segments, 17 joints with raptor names, every colour in the role list or never-paint, spikes transparent.

## Task 2 — SkinCatalog 1.2 · Mode: Logic
**Files:** `src/shared/SkinCatalog.luau`, `tools/tests/SkinCatalog.spec.luau`.
**Steps:** spec first (Pachy roles; every PachyModelData colour covered; Pachy classic round trip; no hex shared between groups) -> fail -> ROLES.Pachy + SKINS.Pachy {classic} -> PASS.
**Acceptance:** spec PASS; SkinServer paints a Pachy body by roles (checked on the display model with SkinCatalog.roleOf).

## Task 3 — Display model · Mode: Wired
**Files:** Create `tools/display_pachy_install.luau`.
**Steps:** build Workspace.DinoArcade_Pachy with two anchored copies scaled 2x (as in game) next to the spawn: "Pachy_Display" (knob ring) and "Pachy_Display_Spikes" (spikes shown). Install the data module in ServerStorage.DinoArcade.Models.
**Acceptance:** both copies stand on the ground; Kepu looks at them in Studio.

## Red-team
1. **Pachy colours collide with another dino's roles** -> roleOf is per species, so no clash; spec checks no hex shared between Pachy groups and none equal to never-paint.
2. **Spikes shown by accident** (e.g. a skin painting them visible) -> SkinServer only sets Color / Material, never Transparency; spikes stay hidden until the abilities plan wires PachySpikes.
3. **Inherited T-Rex gait on a smaller body looks wrong** -> accepted for the model step (display is static); gait tuning is part of the abilities / playable plan.
