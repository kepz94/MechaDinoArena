# Mecha Dino Arena v1.0 — Teno rear tail slam rework

**Goal:** the tail slam hits only what's behind the teno, within the tail's reach, aimed like the T-Rex bite, and it bucks off only raptors latched on the back half.

**Intent (Kepu 2026-11-01):**
- "It's currently an area splash damage instead of a tail slam at a specific enemy from the rear."
- "The tail slam only damages Dino's behind the Dino within the range of the tail not anywhere in the mid section or front of the teno."
- "if a raptor latches on to the back half of a teno allow the tail slam to kick them off ... If a raptor is at the front half of the teno then the tail slam won't kick them off."
- "make the teno tail slam be 15 damage instead of 20 with 4 charges at max along with the .5 s stun."
- "Have the teno's rear tail slam function like how the t-Rex bite soft aim works."
- Answers:
  - "Every dino in the tail zone";
  - "3 base, 4 with an upgrade" -> "Buck Off ★ adds it";
  - "Narrow".

## Global Constraints
- Additive, behind switches. The model numbers are attributes.
- Versions:
  - New: TenoSlamAim 1.0 (shared, pure) + TenoSlamAim.spec 1.0.
  - TenoAttackServer 1.2, TenoAttackTest 1.2, TenoPose 1.2.
  - TenoModelData 1.4 (teno_generator 1.4).
  - SkillTree 1.48 + SkillTreeTeno.spec 1.1, SkillEffects 1.32.
  - ArenaTouch 1.10, AbilityBar 1.21.
- Install by multi_edit / execute_luau and verify by hash. Publish only on "publish". Test PC + gamepad + phone. Never test with a second player.

## Do-not-touch
- The scratch (tap), the hold / wind-up, the charge refill time (8 s), the toss distance (35).
- Brace / Charge Up and Buck Off I–III.
- Other dinos.

## Deterministic map (TenoAttackServer 1.2, switch `TenoAttackRearAimEnabled`)
| Case | Condition | Result |
|---|---|---|
| Aim (at the slam request) | targets (players where ModeRules allows, bots; never a squadmate; not latched on the teno) in HRP space (x left, z back) with gap = nearest hitbox to the hips | TenoSlamAim.pick: in reach = z > 0 and gap <= TenoSlamReach (18.5) × scale; among them yaw = atan2(x, z) within ±TenoSlamAimMax (35°), the lowest score gap + 0.05·\|yaw\| + 0.02·distance (the bite's weights) is the aim |
| No one to aim at | — | yaw 0 (straight back) |
| Publish | before TenoSlamAt | TenoSlamAimYaw (+ = left), TenoSlamAimTarget |
| Impact (TenoSlamDropTime later) | positions re-read | hit = every in-reach target within TenoSlamCone / 2 (35°) of the aimed yaw. Front and mid section are never hit (z > 0 only) |
| Latched raptor | its PounceLatchPart centre is behind the hips (HRP-space z > 0) | slammed: damage (+ Buck Off I bonus), shaken off ("slammed"), tossed |
| Latched raptor | latched on the front half | not hit, not shaken off; TenoSlamFrontLatched counts it |
| Damage / stun | — | TenoSlamDamage 15 (+ Brace III bonus), stun TenoSlamStun 0.5 s |
| Charges | — | max = TenoSlamCharges (3) + TenoSlamExtraCharges (Buck Off ★ = 1, SkillEffects 1.32); when the max rises, refill starts |
| Switch off | TenoAttackRearAimEnabled false | 1.1: arc 220° / range 15, every latched raptor bucked, max 3 |

The client (TenoAttackTest 1.2) predicts the same aim with `ReplicatedStorage.TenoSlamAimShared` and sets TenoLocalSlamYaw. TenoPose 1.2 then bends Tail1..Tail5 toward the aim right away (shares 0.3 / 0.25 / 0.2 / 0.15 / 0.1). Other players see the server's TenoSlamAimYaw.

HUD: the 4th pip appears (ArenaTouch 1.10 / AbilityBar 1.21) only while the max is 4. It's a copy of the existing pip, so it's the same look.

## Tasks
1. **TenoSlamAim 1.0 + spec** (Logic): spec red first, then PASS.
2. **TenoAttackServer 1.2 + TenoModelData 1.4** (Wired): aim, zone, back-half latch rule, 15 dmg / 0.5 s, extra charge.
3. **SkillTree 1.48 + SkillTreeTeno.spec 1.1 + SkillEffects 1.32** (Logic + Wired): the Buck Off ★ text and TenoSlamExtraCharges.
4. **TenoAttackTest 1.2 + TenoPose 1.2** (Wired): predicted yaw and tail bend. Check the yaw sign in Studio, since the joint-frame derivation needs to be confirmed against the real rig.
5. **ArenaTouch 1.10 + AbilityBar 1.21** (Wired): 4 pips.
6. **Studio check:**
   - a dummy straight behind / 30° off / beside / in front / out of reach;
   - a raptor latched on the hips vs the chest;
   - damage 15, stun 0.5;
   - 4 pips with Buck Off ★;
   - PC / gamepad / phone.

## Red-team (single-ticket-sized change, one paragraph)
The risks are the yaw sign of the tail bend (it's derived, not measured; Task 4 checks it) and the latch half test. A raptor latched right at the hips (z ≈ 0) counts as front (z > 0 is required). The latch point is the PounceLatchPart centre, so a raptor on the hind thigh counts as back. A dino straddling the hips line is judged by its root, so a big dino whose root is beside the teno but whose tail sticks out behind is not hit. That's accepted, because Kepu wants the back only.
