# Mecha Dino Arena v1.0 — T-Rex redesign (X: true to life, roster scale)

**Goal:** the T-Rex in the game looks like a real T-Rex and is the biggest dino on the roster, without breaking any of its moves, skins or mecha parts.

**Intent (Kepu 2026-11-02):**
- "the t-Rex needs a redesign. It looks way too cartoonish with its portions"
- "Is the museum t-Rex accurate to real life ..." -> "Okay do it" -> "Let's go with X that looks way cooler"
- Standing rule: "always design the dinosaurs carefully from now on".

**Chosen direction:** X = A2 "Apex, true to life" at roster scale (62 studs). Mockup: `docs/mockups/trex_redesign_options.html` v0.2 (tab X).

**Architecture:** two parts, each behind its own switch.
1. **New model.** `tools/trex_generator.py` 2.0 writes `TRexModelData` 2.0 with the A2 geometry, built at 38 studs (today's length). That keeps every distance attribute in the same ballpark as today. It carries over all 1.24 attributes unchanged, except the rig numbers the new body sets (`RigHipHeight`, the HRP size, `HipHeight`).
2. **Roster scale.** `RaptorScale` 1.5 scales T-Rex characters and T-Rex bots by `TRexScale` = 62 / 38 = 1.63. It uses the same pipeline as the raptor, pachy, Herrera and teno: `Model:ScaleTo`, the GrowthCurve distance keys, ground lift, and IdleAnimation / ShoulderCam re-fit.

Turning the scale switch off gives a true-to-life T-Rex at today's size (A2). Reverting `TRexModelData` to 1.24 gives today's T-Rex back.

## Global Constraints
- Additive and switchable.
- Versions:
  - `TRexModelData` 2.0 / `trex_generator` 2.0.
  - `RaptorScale` 1.5 (its `VERSION` constant still reads "1.2", so set it to 1.5 here).
  - `StarterCharacter` 1.3 (rebuilt from the data file in Studio).
  - `SkinCatalog` unchanged.
- Keep exactly:
  - the rig 1.3 segment and joint names (17 joints);
  - `Head_mouth` (bite / roar / hitbox / bot code) and `Torso_body` (Mecha / Cloak fallback);
  - the three skin roles (main `666A4A`, dark `50523A`, belly `B2A278`) and the never-paint colours (`E8E2D2`, `111111`, `F5F5F0`, `6E342E`).
- Install by multi_edit / execute_luau and verify by hash.
- Publish only on "publish".
- Test on PC + gamepad + phone. Never test with a second player.

## Do-not-touch
- Bite / roar / ram / creep / stamina / kill-regen behaviour and numbers. They're attributes carried over as-is; only the scale multiplies the GrowthCurve distance keys, as it already does for the other dinos.
- The other dinos.
- `SkinCatalog`: the three T-Rex roles are unchanged, so every T-Rex skin keeps working.
- `GrowthServer`'s curve.

## Tasks
1. **`trex_generator` 2.0 -> `TRexModelData` 2.0** (Logic + data).
   - Write the data file with the A2 geometry.
   - Carry over every 1.24 attribute; set `TRexModelVersion` 2.0, `RigHipHeight` and the HRP size from the new body.
   - Spec (red first): all 17 joints present, `Head_mouth` / `Torso_body` present, every colour a T-Rex role or never-paint, and the attribute set is a superset of 1.24.
2. **`RaptorScale` 1.5** (Wired): Species "TRex" players and BotSpecies "TRex" bots scaled by `TRexScale` (1.63). Switches `RaptorScaleTRexEnabled` and `RaptorScaleTRexBotsEnabled`.
3. **Studio install + rebuild `StarterCharacter` 1.3** (Wired).
   - Hash-verified data and spec run.
   - Play checks:
     - walk / run gait (feet planted, no sliding past today's level) and the camera;
     - bite on a dummy (reach, `Head_mouth`), roar cone, ram, creep;
     - hit zones (head / torso / tail);
     - every T-Rex mecha part and skin on the new body;
     - the Lab stage and main-menu hangar framing;
     - spawning, doors, caves and tight spots in the arena / island at 62 studs.
   - PC + gamepad + phone.
4. **Fixes found in 3** (Wired, if any): each its own small change behind a switch, raised with Kepu first when it touches feel or balance.

## Red-team (3–5 strongest)
1. **Map fit at 62 studs.** Caves, bushes, doors, the arena edges and spawn points were sized around a ~38-stud T-Rex.
   - Risk: a 1.63x T-Rex may get stuck or clip.
   - Mitigation: a walk-through in Task 3 at both scales. If places fail, Kepu picks one: smaller `TRexScale` (e.g. 1.4 = 53 studs) or map changes.
2. **PvP balance.** A 62-stud body is a much bigger target (hit boxes scale with it), and its reach grows with the distance keys.
   - Risk: the T-Rex gets easier to hit and longer-reaching at the same time.
   - Mitigation: record bite reach and hit-box size before and after in Task 3; no balance change without Kepu.
3. **Gait.** The new legs are longer and the hip is higher than today's (`RigHipHeight` changes).
   - Risk: `WalkStepLength` / `WalkLift` were tuned for the old legs, so the IK may over-reach or slide.
   - Mitigation: check in Play; any re-tune goes through the attributes (additive), never by editing WalkPose.
4. **Mecha parts.** They're welded to segment roots with offsets made for the old body shape.
   - Risk: parts may float inside or outside the new body.
   - Mitigation: Task 3 checks each one. A per-part offset fix for the T-Rex is its own ticket.
5. **Growth.** GrowthServer may also scale a growing T-Rex.
   - Risk: two scales stacking.
   - Mitigation: confirm in Task 3 how RaptorScale and growth combine for the raptor today, and copy that.
