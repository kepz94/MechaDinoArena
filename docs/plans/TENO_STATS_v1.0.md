# Mecha Dino Arena v1.0 — Tenontosaurus stat rows (Charge Up, Brace, Buck Off)

**Goal:** the teno's Lab STATS tab has its own three rows: Charge Up (speed), Brace (defense), Buck Off (signature), and no Lifesteal / Regeneration / Jaws / Thick Hide / Sprint Legs.
**Intent (Kepu 2026-10-31):** "No life steal and no regeneration for this one" · speed "C" (Charge Up) · defense "C" (Brace) · signature "number 2" (Buck Off) "This only works when latched. If you're stunned and then latched it doesn't work" · attack row: "No attack row" · stun rule: "Off only while stunned".
**Chosen direction:** mockup `docs/mockups/teno_stats_options.html` v0.1 (switches: No attack row, Off only while stunned).
**Architecture:** the Herrera pattern (SkillTree 1.37): teno-only paths (`dino = "Teno"`), shared rows hidden with `notFor.Teno`, effect fields from `SkillTree.effects`, written to the character by SkillEffects, acted on by a new TenoStatsServer plus small additive hooks in TenoAttackServer / TenoAttackTest / SprintTest.

## Global Constraints
- Additive, every change behind a switch; other dinos unchanged (their effect fields stay at off values).
- Versions: SkillTree 1.45, SkillEffects 1.31, SprintTest 1.17, TenoStatsServer 1.0, TenoAttackServer 1.1, TenoAttackTest 1.1, SkillTreeTeno.spec 1.0.
- Install by multi_edit / execute_luau, verify by hash + loadstring; publish only on "publish".

## Rows (step texts as shown in the Lab)
| Row (area) | I | II | III | ★ |
|---|---|---|---|---|
| Charge Up (Speed) | After 2 s of running: run 10% faster | After 3 s of running: run 20% faster, and you can't be shoved | Running into a dino at full speed bumps it 10 studs aside | Full-speed hits stun 0.5 s |
| Brace (Defense) | While holding a slam: take 20% less damage | While holding: can't be stunned or knocked back | While holding: every hit you take adds +3 damage to that slam | Releasing a slam heals 5% of max health per enemy hit |
| Buck Off (Signature, new area) | Latched raptors take +10 slam damage | A slam while something is latched on costs no charge | After a buck-off, nothing can latch on for 2 s | A raptor that latches on takes 3 damage per second until it lets go |

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Running | flat speed >= 0.8 x MoveRunSpeed; a dip below for > 0.3 s, a stun or death resets the timer | TenoChargeLevel 1 after 2 s (x TenoChargeMul1), 2 after 3 s (x TenoChargeMul2); SprintTest multiplies WalkSpeed by TenoChargeMul |
| Charged, II | level 2 and TenoChargeNoShove | HeadbuttShoveEnabled = false (pachy headbutt / scratch / visor shoves do nothing) |
| Bump, III | level 2, TenoChargeBump > 0, an allowed target (mode / squad rules) in a 70° cone ahead with its hitboxes within 3 x scale of the point 5 x scale ahead | target shoved TenoChargeBump studs to the side it is on (players HeadbuttShove*, bots slide); once per target per 1.5 s; ★ StunnedUntil = max(it, now + 0.5) |
| Holding | TenoHoldSince > 0 | Brace active |
| Brace I | holding, a Humanoid health drop | refund drop x (1 - TenoBraceMul) |
| Brace II | holding and TenoBraceNoStun | SkillEffects: StunnedUntil set by anyone -> now ("braced"); HeadbuttShoveEnabled = false |
| Brace III | holding, each health drop | TenoBraceBonus += TenoBraceStack (reset at each new hold and after the impact); TenoAttackServer adds it to every target's slam damage |
| Brace ★ | at TenoSlamImpactAt | heal TenoBraceHeal x MaxHealth x TenoSlamHits |
| Stunned teno | StunnedUntil > now | every Buck Off effect off (no bonus, no free slam, no repel, no ticks) |
| Buck Off I | slam impact, latched raptor, teno not stunned | + TenoBuckBonus damage |
| Buck Off II | hold / slam with a raptor latched on, TenoBuckFree, not stunned | allowed at 0 charges; no charge used (TenoSlamFree true) |
| Buck Off III | a slam bucked >= 1 raptor | TenoLatchImmuneUntil = impact + TenoBuckImmune; a latch on the teno before then (teno not stunned) is shaken off at once (ShakeOffReason "buckoff", no damage / toss) |
| Buck Off ★ | a raptor latched on, teno not stunned | it loses TenoBuckDps DummyHealth every second (KilledWith "buckoff") |
| Not a teno / row not bought | — | off values: muls 1, flags false, numbers 0 |

## Tasks
1. **SkillTreeTeno.spec 1.0 + SkillTree 1.45** (Logic): spec red first; area "sig" (Signature), paths chargeup / brace / buckoff (dino Teno), notFor Teno on regen / lifesteal / jaws / hide / legs, effects fields as the map. Switch SkillTree.TENO_STATS.
2. **SkillEffects 1.31** (Wired): writes the Teno* attributes on Species "Teno" characters; Brace II in the stun handler. Switch SkillEffectsTenoEnabled.
3. **TenoStatsServer 1.0** (Wired): charge timer + bump, shove switch, Brace refund / bonus / heal, Buck Off repel / ticks, TenoLatchedCount. Switch TenoStatsServerEnabled.
4. **TenoAttackServer 1.1 / TenoAttackTest 1.1 / SprintTest 1.17** (Wired): bonus damage, free slam; client hold at 0 charges while latched; TenoChargeMul in the speed.
5. **Studio check**: Lab rows on the teno (and none of the 5 shared rows), each step's effect with Studio test steps.

## Red-team
1. **Brace I as a refund**: works for every damage source (bites, pounces, slashes, mines) because it reads the Humanoid, but a killing blow is not refunded. Accepted.
2. **Speed measured on the server**: replicated velocity lags ~0.1 s; the 0.3 s dip grace keeps the timer steady.
3. **HeadbuttShoveEnabled** is owned by TenoStatsServer only on teno characters (set false / back to nil); no other script writes it.
