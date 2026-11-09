# Mecha Dino Arena v1.0 — Balance pass 1 ("everything feels super strong")

**Goal:** every dino feels strong. Buff the six weak dinos to a high power level (more speed / movement, more damage), shorten the Raptor latch, fix the Pachy headbutt, make armor work against every attack, and cut jump / movement / Dilo spit cooldowns.
**Intent (Kepu, live mobile test 2026-11-08):** "all the other dinosaurs need a buff aside from the pachy and raptor ... borderline unplayable" · "a bit more movement in their kits or base speed and a little higher damage" · "The herrerra needs more damage in its kit. It's way too weak" · 22:15 "like marvel rivals where everything feels super strong so if everything is super strong then everything is also balanced" (decision #11).
**Picks:** 2026-11-09 10:48 "very strong for everything" + "the cooldowns for things like jumping, and the dilo spitting need to be lowered" -> jump cooldown "Yes, every dino" · movement parts "Yes, about 30% shorter" · armor "Every attack". Raptor latch 22:36 "Make it 2.5 seconds", 22:47 "5 per hit = 33 total" (MDA-357).
**Source numbers:** balance sheet from main 0cca869 (live = v539), file:line in the sheet; spot-checked RaptorModelData 250/257/258/268/269, HerreraModelData 271/309/358/359/365, TherizinoModelData 410-412.

## Numbers ("Very strong")
Speeds are model values; in game x ArenaSpeedScale 0.65 (shown as eff). "Kill a Raptor" = ~seconds to kill a 60 HP raptor, every hit lands, no upgrades (estimate).

| Dino | Change | Before | After |
|---|---|---|---|
| Herrera | SlashDamage / SlashCharges / SlashRefill / bleed per s | 7 / 2 / 4 s / 2 | 15 / 3 / 2.5 s / 4 |
| Herrera | kill a Raptor | ~14 s | ~2.5 s |
| Troodon | TrooPodDamage / TrooZoneDps / TrooPodCharges / TrooPodRefill | 6 / 3 / 2 / 3 s | 12 / 6 / 3 / 2 s |
| Troodon | kill a Raptor | ~12 s | ~4 s |
| Dilo | bite / dart / venom per s | 10 / 6 / 2 | 15 / 10 / 4 |
| Dilo | run (eff) | 66 (42.9) | 78 (50.7) |
| Dilo | Cobra Leap charges | 1 | 2 |
| Dilo | DiloHoldTime / DiloDartCooldown | 0.4 / 1.5 s | 0.25 / 0.75 s |
| Teno | scratch / tail slam | 8 / 15 | 12 / 25 |
| Teno | run (eff) | 52 (33.8) | 66 (42.9) |
| Teno | leap | cooldown 1 s | higher leap (launch 54 -> 64) |
| Therizino | cuts | 9 / 9 / 20 | 11 / 11 / 24 |
| Therizino | Spin Dive charges / refill | 2 / 6 s | 3 / 3 s |
| Therizino | run (eff) | 66 (42.9) | 78 (50.7) |
| T-Rex | bite | 25 | 30 |
| T-Rex | run (eff) | 60 (39.0) | 74 (48.1) |
| Raptor | latch (MDA-357) | 5.67 s, 8 + 11 x 4 = 52 (Blade max ~93) | 2.5 s, 8 + 5 x 5 = 33 (Blade max ~54) |
| Pachy | headbutt reach / trapped (MDA-355 / 356) | 4-stud grow on every side; works while trapped | front, short reach (tail counts); no movement moves while trapped |
| Every dino | JumpCooldown (leap) | Raptor / Pachy / Dilo / Troodon 0.5 s, Teno / T-Rex 1 s | 0.25 s |
| Every dino | movement mecha parts / movement moves | (table to come, MDA ticket) | about 30% shorter cooldowns, 35% rule kept |
| Every dino | armor (Thick Hide / Armored Hide / Wiry Frame = StatDamageTakenMul) | bites + pounces only (BoneCrest.defense in BiteServer, PounceServer, BotServer) | every damage path |

Stat-tree rows and parts keep their current additions on top of the new base numbers.

## Global constraints
- Additive only; one switch per changed script; every number an attribute; version branding (headers, VERSIONS.md, ATTRIBUTES.md, ROSTER).
- Model numbers change through the generators (tools/*_generator.py) with a version flag that regenerates the old version byte-identical, like the Troodon kit versions.
- Bots that use the same model data get the same numbers (check BotServer for bot-only copies and list them).
- One-player Play tests with held bots; saved data switches set in Edit before Play; never a second player.
- Publish only on "Publish".

## Red-team (short)
1. **Very strong T-Rex kills a Raptor in ~2 bites (~1 s).** The T-Rex is not day-1 (decision #6), so it doesn't affect launch, but it's the biggest jump. Accepted by the pick.
2. **Armor on every attack lowers every buff for armored builds.** Thick Hide star = damage taken x0.70; armored Teno / Pachy builds become much tankier against the new damage. This is the intended "tank builds work" result; every attack server must read StatDamageTakenMul in one shared place (BoneCrest.defense), not 20 copies.
3. **0.25 s jump cooldown and flaps / double jumps.** The Troodon flaps and Pachy Mecha Legs reuse the jump path; the lower cooldown must not let a leap re-trigger mid-air. Play check of every dino's jump.
4. **Cooldown cuts vs the 35% rule.** x0.7 on every rank keeps each step's ratio; any part whose star is "recharge" must still be >= 35% better than III.
5. **Scope.** ~8 model data versions, ~20 attack servers for armor, the movement parts. Build order: data first (one ticket per dino), then armor, then cooldowns, then the Studio regression.

## Tickets
MDA-355 (headbutt reach), MDA-356 (trapped = no movement moves), MDA-357 (Raptor latch) + this pass's tickets (one per dino, armor, cooldowns, regression).
