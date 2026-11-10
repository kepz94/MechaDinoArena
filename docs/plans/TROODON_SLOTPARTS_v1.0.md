# Mecha Dino Arena v1.0 — Troodon slot parts (Bloom Tank + Bloom Burst, Shield Dome, Sleep Dart, Sentry Pod)

**Goal:** replace the Troodon's 4 removed passives (SkillTree 1.84) with Kepu's picks: 1 passive (no slot) and 4 slot parts (buttons).
**Intent (Kepu 2026-11-10):** 00:21 "remove the 4 for the troodon and let's cook up 4 new ones"; 01:33 "Bloom bank [Tank] for sure. We need to look at the actual mecha slots tho"; 01:40 from the 20-idea list "Let's do 1,37, and 14" (= #1 Bloom Burst, #3 Shield Dome, #7 Sleep Dart, #14 Sentry Pod); 09:46 "Publish" -> "Then build".
**Chosen direction:** mockup docs/mockups/troodon_slotparts_v0.1.html (artifact 4WkFiNgyg9dXN91LfYBkdW), looks exported by tools/troodon_slotparts_mockup/export_looks.js to src/shared/TrooSlotLooks.luau. Fit measured in the mockup: 0% in body, 0% clashes with each other and the 5 live button looks.
**Rule (Kepu 2026-11-10):** a passive has no button and takes NO slot; a part with a button takes a slot.

## Numbers (game studs; the 35% rule)
| Part | I | II | III | star | Recharge |
|---|---|---|---|---|---|
| Bloom Tank (passive) | glow zone 54 wide (today 40) | zones last 4.05 s (today 3) | 73 wide | a zone's end blooms: squadmates inside +5, enemies inside slowed 1.5 s more | — |
| Bloom Burst | throw a bud up to 40: squad within 20 +20 HP and 50% more healing 4 s; enemies inside heal 50% less 4 s | boost 5.4 s | recharge 13.3 | 54 wide (radius 27) | 18 / 13.3 (III) |
| Shield Dome | throw a canister up to 30: a dome 30 wide for 5 s; enemy shots stop on it | lasts 6.75 s | recharge 18.5 | 40.5 wide | 25 / 18.5 (III) |
| Sleep Dart | dart up to 120 studs: the first enemy hit sleeps 2.5 s (no move / attack / parts); any damage wakes it | 3.4 s | recharge 8.9 | splits: 1 more enemy within 15 studs sleeps too | 12 / 8.9 (III) |
| Sentry Pod | throw a turret up to 30: for 8 s it shoots the nearest enemy within 60 studs, 6 damage every 0.5 s | lasts 10.8 s | recharge 16.3 | 2 pods per shot | 22 / 16.3 (III) |

## Architecture (additive; every change behind a switch; every number an attribute)
- **SkillTree 1.85** `TROO_SLOT_PARTS` (default true): paths obloom (health, NOT in BUTTONS = no slot), oburst (health), odome (defense), osleep (attack), osentry (attack); owner Troodon, LIVE_MECH. effects() writes only new o* fields.
- **SkillEffects 1.58** `SkillEffectsTrooSlotEnabled`: TrooPartBloom* written when bought (no slot), TrooPartBurst* / Dome* / Sleep* / Sentry* when bought AND slotted (the 1.48 rule).
- **TrooSlotServer 1.0** (new, ServerScriptService): the 4 button rules + Bloom Tank (writes the character's TrooZoneRadius / TrooZoneTime from TrooPartBloom*, base restored when off; star end pulse). Remotes DinoTrooBurstRequest / DinoTrooDomeRequest / DinoTrooSleepRequest / DinoTrooSentryRequest. Checks = TrooMovesServer 1.11's check(). Heal boost / cut = a health watcher on the affected models (every heal source, no other script edited). Dome = an invisible-to-collision Ball tagged "SapWall" (SapWallBlock 1.2 already blocks every attack whose straight line or arc enters it; a ray that starts inside does not hit it, so shots from inside go out). Sleep = StunnedUntil (every move server already honours it) + TrooSleepUntil; a health drop wakes it. Sentry = a server turret model (the look's carry pieces, scaled), shots through damage() (armor, shields, walls).
- **TrooPartsServer 1.2** `TrooPartsSlotLooksEnabled`: also builds the 5 looks from TrooSlotLooks 1.0 + their Lab cards (BuildPreview_<id>); MAT + blue / violet / glassT.
- **TrooSlotFX 1.0** (new, StarterPlayerScripts): throw arcs, burst, dome canister + hit ripples, dart trail + Zz, sentry bolts, bloom pulse; hides the thrown on-body pieces until they regrow.
- **TrooPose 1.7**: PART_STAMPS += TrooBurstAt / TrooDomeAt / TrooSentryAt -> the wide throw, TrooSleepAt -> new sleep track (SLEEP_COIL 0.22, SLEEP_SNAP 0.3, READY 0.8).
- **MechaButtons 1.45 / AbilityBar 1.38**: TIMED_PARTS for the 4 buttons (PC keys, gamepad, phone slots together); throws send (stamp, flat look, point), the dart (stamp, flat look).

## Do-not-touch
TrooMovesServer, TrooAttackServer, TrooPartsFX, TrooFX, SapWallBlock (read only, used as is), the other dinos.

## Red-team
1. **Dome blocks your own squad's shots from outside into it** (SapWallBlock has no owner rule; Gibraltar's blocks both ways). Accepted for v1.0: from inside, shots go out (the pick). Named in the report.
2. **Heal boost / cut watcher** sees every Health rise, including respawn-time sets and max-health changes. Mitigation: only inside the 4 / 5.4 s window, only rises <= 60% of max, its own adjustments flagged.
3. **Sentry 96 damage over 8 s** (more than a 60 HP raptor). Kepu's pick ("very strong" pass); flagged in the report, number is an attribute.
4. **Sleep vs other stuns:** waking only clears StunnedUntil when it is still the sleep's own value, so a later Lantern stun keeps running.
5. **Bloom Tank and the zone base:** TrooZoneRadius is a model-data attribute; the server saves the base (TrooBloomBaseRadius / BaseTime) before the first write and restores it when Bloom is off or the species changes.

## Tickets
T1 SkillTree 1.85 + SkillEffects 1.58 + spec (Logic). T2 TrooSlotServer 1.0 (Wired). T3 TrooPartsServer 1.2 + TrooSlotLooks 1.0 (Wired). T4 TrooSlotFX 1.0 + TrooPose 1.7 (Wired). T5 MechaButtons 1.45 + AbilityBar 1.38, PC + phone (Wired). T6 Studio check + docs; not published until Kepu says Publish.
