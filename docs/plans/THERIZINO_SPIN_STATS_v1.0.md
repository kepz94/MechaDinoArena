# Mecha Dino Arena v1.0 — Therizino Spin Dive (Corkscrew) + its own stat rows

**Goal:** the Therizino's JUMP becomes its own move, the Corkscrew Spin Dive, which cuts all along its flight path. Its Lab STATS tab shows five Therizino-only combo rows instead of the shared defaults.

**Intent (Kepu 2026-11-02 22:54):**
- "That therizino jump animation is butt ugly. It should look different and function different than the teno animation, show more slicing animation and even a different jump."
- "You gave it the default stats and didn't make it unique."

**Answers:**
- Shared rows: "None, all its own".
- Theme: "Combo flow".
- Jump idea: "Spin Dive", then style "Corkscrew" (2026-11-03 15:19).
- Rows: "Keep all five".

**Chosen direction:** mockup `docs/mockups/therizino_spin_dive_v0.1.html`, style B Corkscrew, and the five rows as shown. Video `docs/reference/therizino/therizino_spin_dive_v0.1.mp4`.

**Architecture:**
- **JUMP:** keeps JumpServer 1.3's charges and JumpTest's leap. The teno landing slam (TenoMovesServer `jumpSlam`) is switched off for the therizino by model attributes. A new **TheriSpinServer 1.0** cuts targets along the flight.
- **Pose:** TheriPose's leap layer gets the Corkscrew body (S_SCREW) and a whole-body roll about the torso.
- **Stats:** the TENO_STATS_2 pattern:
  - SkillTree paths with `dino = "Therizino"`;
  - shared rows get `notFor.Therizino`;
  - SkillEffects writes `THERI_ATTRS`;
  - TheriAttackServer / TheriAttackTest / TheriSpinServer act on them.

## Global Constraints
- Additive, every change behind a switch; other dinos unchanged.
- Versions:
  - TherizinoModelData 1.5 (therizino_generator 1.3), TheriSpinServer 1.0, TheriPose 1.3 (1.4 for the 4th cut).
  - SkillTree 1.57 + SkillTreeTheri.spec 1.0, SkillEffects 1.39.
  - TheriAttackServer 1.1, TheriAttackTest 1.1, JumpServer 1.4, AbilityBar 1.24 (if the tile text changes).
- Install by multi_edit / execute_luau and verify by hash.
- Publish only on Kepu's "publish" (both places).
- Never test with a second player. Never change saved progress (SkillPath_ / SkillSlot).

## Do-not-touch
- TenoMovesServer's jumpSlam and the teno's leap: off for the therizino by its own attributes only, not by code.
- The teno / Herrera / raptor / pachy / T-Rex rows.
- JumpServer's charge rules for other dinos.
- The combo's base numbers (9 / 9 / 20, 0.33 / 0.8 / 0.9).

## Spin Dive (Corkscrew), numbers as in the mockup
- **JUMP:** crouch 0.27 s (JumpWindup), then the leap (JumpTest; ~32 studs moving).
- **In the air:** the body rolls 2 full turns about its torso's forward axis, arms straight out (S_SCREW), neck forward.
- **Damage:** any allowed dino whose nearest hitbox comes within `TheriSpinRadius` × scale of the root's path takes `TheriSpinDamage` 7. Each dino can be cut up to `TheriSpinMaxCuts` 3 times, at least `TheriSpinCutGap` 0.16 s apart.
- **Landing:** no slam. Claws-down landing into CHOP_SET, with a skid.

## Rows (Lab texts)
| Row (id, area) | I | II | III | ★ |
|---|---|---|---|---|
| Flowing Cuts (`flow`, speed) | Chain window 0.8 → 1.0 s | Taps 0.33 → 0.26 s apart | Finisher recovery 0.9 → 0.55 s | A finisher that lands refills one Spin Dive charge |
| Building Fury (`fury`, attack) | Cut 2 9 → 12 | Finisher 20 → 26 | Each landed cut on the same dino adds +2 to the next | Full 3-hit chain on one dino: finisher ×1.5 |
| Fourth Cut (`fourth`, sig) | Tap after the finisher: spinning sweep, 10 all around | Sweep 14 | Sweep reach +30% | The sweep comes out faster and chains back into cut 1 |
| Flow Guard (`guard`, defense) | 15% less damage while a chain is going | Not stunned during the finisher | Shoves push half as far mid-chain | A hit mid-chain does not break the chain |
| Reaper's Harvest (`harvest`, health) | Each finisher hit heals 4% max health | 6% | A combo kill heals 15% over 3 s | Combo heals doubled under 30% health |

The shared rows Regeneration, Lifesteal, Jaws, Thick Hide and Sprint Legs all get `notFor.Therizino`.

## Tasks (Dev Hub MDA-207 T1, MDA-208 T2, MDA-209 T3, MDA-210 T4, MDA-211 T5, MDA-212 T6, MDA-213 T7, MDA-214 T8+T9)
1. **TherizinoModelData 1.5** (generator 1.3; Wired):
   - TenoLeapOnJump false, TenoLeapEnabled false.
   - TheriSpinEnabled true, plus TheriSpinDamage 7, TheriSpinMaxCuts 3, TheriSpinCutGap 0.16, TheriSpinRadius 7, TheriSpinTurns 2.
   - Install by hash. Check that the leap still launches with charges and that no landing slam fires.
2. **TheriSpinServer 1.0** (Wired):
   - Trigger: `JumpStartedAt` while Species "Therizino" and TheriSpinEnabled.
   - Flight tracking copied from jumpSlam (left the ground, then landed). Each Heartbeat, sweep the root's segment against the candidates.
   - Damage rules copied from TheriAttackServer 1.0 (shield, mode, squad).
   - Stamps: TheriSpinCuts, TheriSpinCutPoint, TheriSpinCutAt (last), TheriSpinLandedAt. KilledWith "therispin".
   - Script switch `TheriSpinServerEnabled`.
3. **TheriPose 1.3** (Wired):
   - The leap layer's air phase becomes S_SCREW, plus a RootJoint roll about the torso pivot (`TheriSpinTurns` turns, ease to the landing).
   - Landing J_LAND → CHOP_SET → READY.
   - Tip parity check for S_SCREW (within 0.5 studs). Switch `TheriSpinPoseEnabled` (false = 1.2's Diving Rake).
4. **SkillTree 1.57 + SkillTreeTheri.spec 1.0** (Logic): red spec first, then the five rows, `notFor.Therizino` on the shared rows, and the effects fields. Switch `SkillTree.THERI_STATS`.
5. **SkillEffects 1.39** (Wired): THERI_ATTRS written to the character (switch `SkillEffectsTheriStatsEnabled`).
6. **TheriAttackServer 1.1 + TheriAttackTest 1.1 + JumpServer 1.4** (Wired):
   - Flowing Cuts, Building Fury, Flow Guard and Reaper's Harvest.
   - JumpServer 1.4: BindableEvent `JumpAddCharge`, for the Flowing Cuts ★ refill.
7. **Fourth Cut** (Wired, needs a mockup + Kepu's pick first): the 4th tap sweep (server step 4, local step 4, TheriPose 1.4 sweep pose).
8. **TheriFX** (MDA-204, extended): spin trails and cut sparks along the flight, the skid dust.
9. **Studio check:** leap distance (30–34 studs), cuts on bots along the path, every row at I and ★, other dinos unchanged. Then captures for Kepu.

## Red-team (answered by Kepu 2026-11-03)
1. **Fourth Cut has no animation design yet.** The 4th sweep needs its own pose. Mitigation: a small mockup for that one hit before Task 7, and Tasks 1–6 ship without it.
2. **Spin Dive damage vs. the old slam.** The old Diving Rake did 18 to everything in front. The Spin Dive does up to 21 to each dino it passes, but only along its line, so it can whiff more. Mitigation: the radius is an attribute (7 × scale), tuned in the Studio check.
3. **The Lab's MECHA ABILITIES tab is still the shared default for the therizino.** It was not in the ask. Mitigation: a question for Kepu ("leave it, or plan therizino mecha abilities next?"). Out of scope here.
4. **Flowing Cuts ★ refills a JUMP charge.** That needs a JumpServer hook (1.4) that other dinos never use. Mitigation: a BindableEvent that does nothing unless called; the JumpServer spec is unchanged for other dinos.

**Kepu's answers:**
1. "Mock it up first": Task 7 waits for a Fourth Cut mockup and Kepu's pick. Tasks 1–6, 8 and 9 build without it, and the Fourth Cut row shows in the Lab only once Task 7 lands (`SkillTree.THERI_FOURTH`, default false until then).
2. "Yes, tune it in Studio": 7 per cut, max 3; `TheriSpinRadius` is tuned in Task 9. No landing hit.
3. "Leave it for now": the Mecha Abilities tab is out of scope (a later plan).
4. Accepted risk: JumpServer 1.4 gets a do-nothing-unless-called `JumpAddCharge` hook.

Also: Kepu approved the Sidewinder run from the Studio stills ("Looks right", MDA-206).
