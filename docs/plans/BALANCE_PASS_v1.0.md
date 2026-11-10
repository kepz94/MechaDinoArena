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
| Every dino | movement mecha parts / movement moves | see the table below | about 30% shorter cooldowns, 35% rule kept |
| Every dino | armor (Thick Hide / Armored Hide / Wiry Frame = StatDamageTakenMul) | bites + pounces only (BoneCrest.defense in BiteServer, PounceServer, BotServer) | every damage path |

## Movement parts, x0.7 (source: SkillTree / SkillEffects / model data, main 74200b6)
| Dino | Part / move | Attribute (file:line) | Before I / II / III / star | After |
|---|---|---|---|---|
| Raptor | Thrusters recharge | SkillDashRecharge (SkillEffects:480) | 8 | 5.6 |
| Raptor | Adrenaline Injector | adrenCooldown (SkillTree:1290 / 1292) | 20 / 20 / 14.8 / 14.8 | 14 / 14 / 10.3 / 10.3 |
| Pachy | Mecha Legs | legsCooldown (SkillTree:1347; legsCdMul 0.65 at :1349 kept) | 6 / 6 / 3.9 / 3.9 | 4.2 / 4.2 / 2.73 / 2.73 |
| Pachy | Servo Dash | servoCd (SkillTree:1179 / 1181) | 12 / 12 / 8 / 8 | 8.4 / 8.4 / 5.6 / 5.6 |
| Herrera | Adrenaline Injector | adrenCooldown (SkillTree:1522) | 20 / 20 / 14.8 / 14.8 | 14 / 14 / 10.3 / 10.3 |
| Teno | Hydraulic Leap | leapCooldown (SkillTree:1876) | 6 | 4.2 |
| Therizino | Dash | grappleCooldown (SkillTree:2382) | 6 / 6 / 5 / 5 (fails the 35% rule: 1.2) | 4.2 / 4.2 / 3.0 / 3.0 (1.4) |
| Dilo | Spring Jets | dJetsCooldown (SkillTree:2563) | 6 | 4.2 |
| Troodon | Portal Feathers (not live) | oPortalCooldown (SkillTree:2689) | 20 | 14 |
Jump: JumpCooldown 0.25 for Raptor / Pachy / Dilo / Troodon (model data 0.5), Teno (1), T-Rex (TRexJump:19 default 1); Therizino Spin Dive JumpCharges 3 / JumpCooldown 3 (very strong); Herrera stays 0 (HerreraJump:19). Step texts to update: SkillTree:673, 675, 726, 844, 998, 1857, 2356-2357, 2504, 2637. Floors: JumpServer clamps charged refills to >= 0.5 s; Dilo / Troo / Theri moves servers clamp to >= 0.5 s (none of the new values hit them).

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

## Changes after this plan (live, from the other session 013tDtc, audited 2026-11-09 18:0x by session claude-09)
- v582: MDA-355 / 356 headbutt fixes + Dilo spit only (f649fc6) published.
- v583 Dilo pass (c43ea7e): spit dart speed 45, Spring Jets 40/50/65 at 200, mortar cloud x1.5, bigger FX. v584: spit speed 30 (c7b6315).
- v585: part shots fire along the dino's facing in every camera mode (MechaButtons 1.42), mortars 2x faster (DiloMovesServer 1.9, TenoMovesServer 1.17).
- v586 / v587: turn rates Dilo 360, Troodon + Therizino 540 (were the T-Rex 180 inherited by the generators).
- v588: Dilo spit hit 10 -> 5. v589: spit poison 1.5 s at base (was 3), Venom Spit extra time halved.
- v592: Teno Tail Grab fix (StunClient 1.4, TenoMovesServer 1.18, MechaButtons 1.43, AbilityBar 1.37).
- v593: Troodon glow zone 6 -> 1 per second (TroodonModelData 1.9).
- Not live: Troodon parts build 2 (3e48b11, 2c2634c) parked with SkillTree.TROO_PARTS_B2_LIVE = false.
So the plan table's Dilo dart 10 / 3 s venom and Troodon zone 6/s are superseded by these.
Built 2026-11-09 (not published): MDA-366 armor on every attack (BoneCrest 1.7 + 17 attack servers), MDA-365 movement parts x0.7 (SkillTree 1.79, SkillEffects 1.54). See VERSIONS.md.
