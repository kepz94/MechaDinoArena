# Mecha Dino Arena v1.1 — Tenontosaurus stat rows, part 2 (Survivor, Heavy Tail, Front Claws, Armored Hide)

**Goal:** the teno gets 7 stat rows like the Herrera. It gets heals on kills, slam / scratch growth and always-on armour, so its builds have to choose under Mastery 3.

**Intent (Kepu 2026-11-01):**
- "what about stat trees for the teno. How does it stack up against the current rosters and where is it lacking?"
- "Let's do heals on kills. Add heavy tail and look for one more" -> "Add a and b" (A Front Claws, B Armored Hide) -> mockup "I like it".

**Chosen direction:** mockup `docs/mockups/teno_stats_v0.2.html` (the numbers as shown).

**Architecture:** the TENO_STATS pattern (SkillTree 1.45):
- teno-only paths via `add(id, name, area, steps)` with `dino = "Teno"`;
- the shared Thick Hide path re-opened for the teno with `nameFor` / `stepsFor` (like the Herrera's Wiry Frame);
- effects fields written by SkillEffects (TENO_ATTRS), acted on by TenoAttackServer / TenoAttackTest / TenoStatsServer.

## Global Constraints
- Additive and behind switches; other dinos unchanged (their fields stay at the off values).
- Versions:
  - SkillTree 1.50 + SkillTreeTeno.spec 1.2, SkillEffects 1.34.
  - TenoAttackServer 1.3, TenoAttackTest 1.3, TenoStatsServer 1.1.
  - The Slow tag readers SprintTest 1.18 / BotServer 1.23 are shared with the abilities plan, MDA-174 / MDA-179. Whichever lands first builds them.
- Numbering after the tail slam rework (SkillTree 1.48) and the abilities plan (SkillTree 1.49). If the build order changes, renumber at build time.
- Install by multi_edit / execute_luau and verify by hash. Publish only on "publish". Test PC + gamepad + phone. Never test with a second player.

## Do-not-touch
- Charge Up, Brace and Buck Off (only Buck Off ★'s 4th charge from the rework).
- The other dinos' rows.
- KillRegenServer's global switch: kill heals stay off for every other dino.

## Rows (step texts as shown in the Lab)
| Row (id, area) | I | II | III | ★ |
|---|---|---|---|---|
| Survivor (`survivor`, health) | A kill heals 15% of your max health over 4 s | Kill heal 25% | Any enemy that dies within 25 studs of you heals you 10% (whoever killed it) | A kill also refills one tail slam charge |
| Heavy Tail (`heavytail`, attack) | Tail slam +3 damage (15 -> 18) | Slam charges refill 25% faster (8 s -> 6 s) | Your tail reaches 20% further | Slammed dinos are slowed 30% for 3 s after the stun |
| Front Claws (`frontclaws`, attack) | Scratch hits harder (8 -> 11) | A wider swipe in front (90° -> 130°) | Scratch faster (0.5 s -> 0.35 s between scratches) | A scratch hit slows the target 30% for 1.5 s |
| Armored Hide (shared `hide`, defense; nameFor / stepsFor Teno) | Take 10% less damage, always | Thrown half as far by rams and shoves | Stuns are 30% shorter | No stuns while above 50% health |

The teno's Lab order is Survivor, Heavy Tail, Front Claws, Armored Hide, Brace, Charge Up, Buck Off (AREAS order).

## Effects fields (off values on every other dino / unbought)
| Field | Values | Read by |
|---|---|---|
| survivorKillHeal | 0.15 / 0.25 (II+) | TenoStatsServer 1.1 → TenoSurvivorKillHeal |
| survivorNearHeal / survivorNearRange | 0.10 / 25 (III+) | TenoStatsServer 1.1 |
| survivorRefill | true (★) | TenoStatsServer 1.1 → TenoSlamRefillAt bump (TenoAttackServer 1.3 BindableEvent `TenoAddCharge`) |
| heavyBonus / heavyRefillMul / heavyReachMul / heavySlow | 3 / 0.75 (II+) / 1.2 (III+) / 0.3 for 3 s (★) | TenoAttackServer 1.3 |
| clawBonus / clawCone / clawGap / clawSlow | 3 / 130° (II+) / 0.35 s (III+) / 0.3 for 1.5 s (★) | TenoAttackServer 1.3 (+ TenoAttackTest 1.3 for the gap) |
| Armored Hide | defensePts 2 (10%), tossMul 0.5, stunMul 0.7, stunImmuneAbove 0.5 | the existing hide plumbing (StatServer Defense points, SkillEffects), with defensePts 2 for the teno instead of 6 |

## Deterministic map
| Case | Condition | Result |
|---|---|---|
| Kill | a model's KilledAt changes with KilledBy = the teno's name (any move) | the teno heals survivorKillHeal × MaxHealth over 4 s (its own stream; capped at MaxHealth); ★ +1 slam charge (not above max) |
| Near death | an allowed enemy (not a squadmate) goes KO / dies within 25 studs of the teno's root and the kill is not the teno's | +10% over 4 s (III+) |
| Kill + near | the teno's own kill | the kill heal only (no double) |
| Slam (Heavy Tail) | at impact | damage + heavyBonus; reach × heavyReachMul (the aim zone with it); ★ each hit: Slow tag TenoSlowUntil = stun end + 3, TenoSlowMul 0.7 |
| Refill | each refill timer | TenoSlamRefill × heavyRefillMul |
| Scratch (Front Claws) | at the claw hit | damage + clawBonus; cone clawCone; gap clawGap (server cooldown + client); ★ Slow tag 0.7 for 1.5 s |
| Armored Hide | as Thick Hide | 10% less damage (StatDamageTakenMul via Defense points), toss × 0.5, stuns × 0.7, no stuns above 50% |
| Switch off / not a teno | — | off values; 1.x behaviour |

## Tasks
Dev Hub tickets: MDA-182 (T1) … MDA-186 (T5).

1. **SkillTree 1.50 + SkillTreeTeno.spec 1.2** (Logic):
   - Spec red first.
   - 3 new teno paths + hide re-opened for the teno (`notFor.Teno` cleared, nameFor / stepsFor), and the effects fields.
   - The spec checks that the teno's rows read `survivor, heavytail, frontclaws, hide, brace, chargeup, buckoff`, and that other dinos are unchanged.
   - Switch: `SkillTree.TENO_STATS_2`.
2. **SkillEffects 1.34** (Wired): TENO_ATTRS + the new fields. Switch: `SkillEffectsTenoStats2Enabled`.
3. **TenoAttackServer 1.3 + TenoAttackTest 1.3** (Wired):
   - Heavy Tail and Front Claws.
   - BindableEvent `TenoAddCharge`.
   - Switch: `TenoAttackStats2Enabled`.
   - If the Slow tag readers aren't in yet, they come with this task.
4. **TenoStatsServer 1.1** (Wired): Survivor kill / near heals and the ★ refill. Switch: `TenoStatsSurvivorEnabled`.
5. **Studio check:**
   - each row at I and ★ (test layer);
   - a bot kill heal and a near-death heal;
   - slam 18, refill 6 s, reach ×1.2;
   - scratch 11 / 130° / 0.35 s;
   - the slows;
   - Armored Hide 10% / toss / stun;
   - Lab rows + Mastery 3 on PC / gamepad / phone.

## Red-team (single plan, one paragraph)
- **Survivor depends on kill credit.** Every damage server stamps KilledBy on a killing blow (bots, and players in the Arena through the bridge). A kill without a stamp is treated as "someone else's" and falls back to the 25-stud near-death heal at III. No tracking is added.
- **Heavy Tail II plus Buck Off ★** gives 4 charges at 6 s each. Watch it in play.
- **The Slow tag** is shared with the abilities plan, so it must be built once.
- **Armored Hide's 10%** goes through Defense points. Some damage paths may not apply the defense multiplier; re-ground which ones read it and list them as gaps in VERSIONS.
