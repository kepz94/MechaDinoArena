# Mecha Dino Arena v1.0 — Troodon kit (playable area control + support: Glow Pod Toss, Evade Hop on JUMP)

**Goal:** the Troodon is a pickable 55 HP area-control support: tapping ATTACK flings a glowing pod with both long arms; it splats into a 3 s glow zone that hurts and slows enemies and heals squadmates, and the troodon heals a little per enemy the splat hits. JUMP is a quick low hop backward that keeps it facing the fight.
**Intent (Kepu 2026-11-06):** roster gap review (no Support / Controller / Recon dino) → "How about an area control type instead" → "a projectile that damages enemies and heals teammates" · shape "Shot that splashes a zone" · solo "Small self-heal on hit" · HP / speed / jump "no preference" · 15:38 "Let's go with your recommendations" (mockup v0.1: attack A, jump J2, the proposed numbers). This replaces the ROSTER 1.1 role "skirmisher".
**Chosen direction:** attack A · Glow Pod Toss, jump J2 · Evade Hop — `docs/mockups/troodon_kit_options_v0.1.html` (artifact 5AsfWztKYHXu5dJjELAqtB; source `tools/troodon_kit_mockup/app_tail.js` with the key poses and timings, built with `node tools/troodon_kit_mockup/build.js`).
**Tickets:** MDA-330 (T1) · 331 (T2) · 332 (T3) · 333 (T4) · 334 (T5) · 335 (T6) · 336 (T7) · 337 (T8) · 338 (T9) · 339 (T10).
**Architecture:** the Dilo playable pattern (DILO_KIT_v1.0). Numbers are model attributes (TroodonModelData 1.1). The attack is a new server + input pair (TrooAttackServer / TrooAttackTest) built from DiloAttackServer / DiloAttackTest's request → checks → timed resolve pattern and the Dilo's soft aim; the zone copies HerreraMovesServer's Goo puddle pattern (players slowed through SprintTest attributes, bots by WalkSpeed scaling, SLOW badge); squad heals copy MedStationServer (SquadRules, Humanoid.Health, the ArenaPvP bridge copies it into DummyHealth). The hop is an additive mode of the existing leap (JumpTest + JumpServer 1.3 charges), so the JUMP button, its server checks and its charge pips are reused. Poses are a TrooPose module layered in IdleAnimation; effects in TrooFX.

## Global Constraints
- Additive: every change behind a switch; raptor / T-Rex / pachy / Herrera / teno / therizino / dilo behaviour unchanged.
- Versions: TroodonModelData 1.1 (troodon_generator 1.1), StatSheet 1.7 (+ spec), SpeciesServer 1.8, RaptorScale 1.8, MainMenu next, SkillEffects next, TrooAttackServer 1.0, TrooAttackTest 1.0, JumpTest 1.5, SprintTest 1.22, StatusBadges next, ArenaTouch next, AbilityBar next, TrooPose 1.0, IdleAnimation next, TrooFX 1.0, display_models_install next, ROSTER 1.27. Each bumps from the live version re-read at build time.
- Numbers (model attributes; distances at scale 1, x2 body in game): DinoMaxHealth 55; WalkSpeed 39; RunSpeed 74. Attack: TrooAttackEnabled true; TrooPodWindup 0.34 (press → pod leaves the hands); TrooPodFlight 0.55; TrooPodRange 22.5 (45 studs); TrooPodCharges 2; TrooPodRefill 3 (each charge, after the previous refill: JumpServer 1.3's rule); TrooMinGap 0.35; TrooAssistAngle 30; TrooAssistMax 22.5; TrooPodLead true (lead the target). Zone: TrooZoneRadius 5 (20 studs wide); TrooZoneTime 3; TrooPodDamage 6 (splat, enemies); TrooZoneDps 3 (ticks at +1 / +2 / +3 s, enemies); TrooZoneSlowMul 0.75; TrooZoneHeal 5 (splat + each tick, squadmates); TrooSelfHeal 2 (per enemy the splat hits). Totals: enemy 15, squadmate +20, troodon +2 per enemy. Hop: JumpEnabled true; JumpHopBack true; JumpCharges 2; JumpCooldown 4 (per charge); JumpHopDistance 9 (18 studs); JumpHopTime 0.42; JumpHopWindup 0.1; JumpHopPower tuned in Studio to ~4 studs high at the 2x body; JumpStaminaCost 0; TenoLeapOnJump false (no landing slam; no landing dust).
- One zone per target: a dino inside two troodon zones takes the ticks of the newest one only.
- Squad heals reach squadmates only (SquadRules.sameChar, Arena squads); never enemies, never bots. With no squad the self-heal is the heal side.
- Every HUD change ships on PC (AbilityBar) and phone (ArenaTouch) together; one phone layout (big yellow ATTACK + JUMP), reusing the Dilo's ATTACK pips and the therizino / teno JUMP pips looks.
- Every move: wind-up → action → result → recovery. No landing FX.
- Install via multi_edit / execute_luau, verify by hash; one-player Play tests (slots saved / restored, saving off); publish only on Kepu's "Publish" (both places). Saved progress untouched.

## Do-not-touch
DinoModelBuilder, JumpServer (reused through attributes; only touched if the Play check shows a hop refused), DiloAttackServer / DiloAttackTest / HerreraMovesServer / MedStationServer (patterns copied, not edited), WalkPose / JumpPose, other dinos' model data, SkinServer / SkinCatalog roles (the model's colour groups already exist), SkillTree (no troodon parts yet: the mecha parts are a later plan), the Lab, BotServer (no troodon bots), StatSheet's Support stat (still no effect: a later plan), ArenaPvP.

## File structure
| File | New / extend | Responsibility |
|---|---|---|
| tools/troodon_generator.py 1.1 → src/shared/Models/TroodonModelData.luau 1.1 | extend / regenerated | the attribute block above; body unchanged |
| src/shared/StatSheet.luau + tools/tests/StatSheet.spec.luau | extend | SPECIES.Troodon (class "Support") |
| SpeciesServer, RaptorScale, MainMenu | extend | pickable, 2x, menu entry "TROODON · 55 HP · area control + support" |
| SkillEffects | extend | keep the troodon's JumpCharges / JumpCooldown / JumpHopBack (the leap writer resets them on non-teno dinos) |
| src/server/TrooAttackServer.server.luau 1.0 | new | pod authority, zones, damage / slow / heal ticks, stamps |
| src/character/TrooAttackTest.client.luau 1.0 | new | ATTACK input, local prediction (pose on the press), charges |
| src/character/JumpTest.client.luau | extend | Evade Hop mode (JumpHopBack) |
| src/character/SprintTest.client.luau | extend | TrooSlowUntil / TrooSlowMul |
| src/character/StatusBadges.server.luau | extend | the existing SLOW badge for TrooSlowUntil |
| ArenaTouch, AbilityBar | extend | ATTACK pips (2 pod charges); JUMP pips (2 hop charges) |
| src/character/IdleAnimation/TrooPose.luau 1.0 + init | new + extend | throw, hop, eyes flare |
| src/client/TrooFX.client.luau 1.0 | new | pod flight, splat, zone, heal pops, hit flashes |
| tools/display_models_install.luau, docs/ROSTER.md | extend | display rebuilt from 1.1; roster role + playable status |

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Press | ATTACK; alive, not menu / stunned / dazed / pinned; a pod charge left; ≥ TrooMinGap since the last throw | throw: charge used; aim point = the closest allowed enemy within TrooAssistAngle of facing and TrooAssistMax x scale led: its position at release + its ground velocity x TrooPodFlight, clamped to TrooPodRange x scale (Kepu: "Lead the target"; TrooPodLead), else straight ahead at TrooPodRange x scale; pod leaves at press + TrooPodWindup, splats at + TrooPodFlight |
| Press, no charge | 0 charges | refused "charges" (button dimmed, pips empty) |
| Press too soon | < TrooMinGap | refused "cooldown" |
| Stunned / menu / pinned / dead during the wind-up | any | throw cancelled, charge refunded; a pod already in the air still splats |
| Splat | pod lands | zone at the landing point (ground) for TrooZoneTime. Enemies inside (radius x scale + their root): TrooPodDamage x takenMul x Back Plating (from the landing point; none while shielded); troodon heals TrooSelfHeal per enemy hit (cap MaxHealth). Squadmates inside: +TrooZoneHeal |
| Tick | +1 / +2 / +3 s | enemies inside: TrooZoneDps x takenMul (skipped while shielded); squadmates inside: +TrooZoneHeal (cap MaxHealth) |
| Inside the zone (every 0.2 s) | enemy inside | player: TrooSlowUntil = now + 0.3, TrooSlowMul; bot: WalkSpeed x TrooSlowMul while inside, back on leaving (Goo pattern) |
| Two zones | a target inside both | ticks / slow of the newest zone only |
| Squadmate / mode-protected | SquadRules / ModeRules | never damaged or slowed; squadmate healed; non-squad players never healed |
| Bot | any bot | damaged and slowed, never healed |
| JUMP | JumpEnabled + JumpHopBack; a hop charge left; ≥ 0.5 s since the last hop | Evade Hop: JumpHopWindup crouch, then JumpHopTime in the air moving straight back (-facing) JumpHopDistance x scale, facing held, ~4 studs high; plain landing; charge refills after JumpCooldown |
| JUMP, no charge | 0 left | refused "cooldown" (pips empty, button dimmed) |
| Death | any | zones already down keep running for their time; respawns as a troodon (remembered choice) |

## Tasks
### Task 1 — TroodonModelData 1.1 · Logic
Generator 1.1 adds the attribute block (only those keys + TroodonModelVersion change; the T-Rex attribute copy's move switches stay off); regenerate; SkinCatalog spec still PASS.
**Acceptance:** body blocks identical to 1.0 (188 parts, same names / colours / CFrames); attribute diff = the listed keys.

### Task 2 — StatSheet · Logic
SPECIES.Troodon {class "Support", start {Health 3, Attack 4, Defense 3, Speed 8, Support 9}, abilities "Glow Pod Toss", "Evade Hop (JUMP)"}; ATTACK_KEYS + TrooPodDamage (1 per point). Spec red then green.

### Task 3 — Selectable · Wired
SpeciesServer (template from TroodonModelData, "Troodon" known, respawn, remembered; switch SpeciesTroodonEnabled), RaptorScale (TroodonScale 2; switch RaptorScaleTroodonEnabled), MainMenu (DINOS entry; switch MainMenuTroodonEnabled), SkillEffects (species "Troodon" keeps its JumpCharges / JumpCooldown / JumpHopBack like the therizino guard; switch SkillEffectsTrooLeapKeepEnabled).
**Acceptance:** menu reaches TROODON; spawns 2x at 55 HP, run 74; after SkillEffects' refresh JumpCharges 2 / JumpCooldown 4 / JumpHopBack true; the other seven dinos spawn as before.

### Task 4 — TrooAttackServer 1.0 · Wired
Remote ReplicatedStorage.DinoTrooAttack(stamp) → TrooAttackServerResult ("ok" / "badArg" / "dead" / "disabled" / "menu" / "stunned" / "dazed" / "pinned" / "cooldown" / "charges"). Server-owned charges (TrooPodLeft, TrooPodRefillAt). Stamps: TrooPodAt, TrooPodFrom, TrooPodTo, TrooPodFlight, TrooPodTarget; TrooZoneAt, TrooZoneCenter, TrooZoneUntil, TrooZoneId; target TrooHitAt / TrooHealAt (last), TrooSlowUntil / TrooSlowMul, TrooZoneOf (newest zone id). Kills: KilledWith "troopod" / "troozone". Diagnostics (script): TrooAttackRequests, TrooZoneHits, TrooZoneHeals, TrooSelfHeals. Switches: TrooAttackServerEnabled, TrooAttackModeRulesEnabled, TrooAttackSquadEnabled, TrooAttackPlatingEnabled. Test hook (Studio only, off by default, never published on): script attribute TrooTestAllyName — that bot counts as a squadmate for the heal path, so the heal is checked without a second player.
**Acceptance:** every map row on held bots and on a bot walking across the aim (the pod lands on its path: led point within 4 x scale studs of where it is at the splat); TrooPodLead false -> lands where it stood; enemy 6 + 3 x 3 = 15; slowed 25% while inside; troodon +2 per enemy hit; the test ally +5 x 4 = 20, capped at max; shielded target: no damage; two zones: one tick per second; squad heal never reaches a non-squad player (code path read + the hook off).

### Task 5 — TrooAttackTest 1.0 + ArenaTouch + AbilityBar · Wired
CAS "DinoTrooAttack" (MouseButton1 via the click handler, ButtonR2, touch ATTACK) with local prediction (TrooLocalState "throw", TrooLocalAt, TrooLocalLeft) so the pose starts on the press; phone ATTACK = the big yellow button with 2 charge pips (the Dilo / therizino pip look); PC ATTACK tile with the same pips; JUMP pips (2 hop charges) on both, extending the therizino / teno JUMP pips rule to the troodon (switches ArenaTouchTrooPipsEnabled, AbilityBarTrooEnabled).
**Layout:** the same slots and looks as the Dilo / therizino ATTACK and JUMP tiles (no new layout).
**Acceptance:** PC + forced touch; pips drain and refill (3 s / 4 s); no default Roblox touch button (MDA-146 lesson).

### Task 6 — Evade Hop: JumpTest 1.5 · Wired
While the character attribute JumpHopBack is true: after JumpHopWindup, a LinearVelocity (this client's own, like the air hold) moves the root along -facing at JumpHopDistance x scale / JumpHopTime for JumpHopTime, with JumpHopPower up; AutoRotate off for the hop (facing held), restored on landing; no air-hold steering and no double jump during a hop. Charges and the server request are the 1.4 path (JumpServer 1.3 untouched). Switch: script attribute JumpHopBackEnabled (default true; false = 1.4 leap). Diagnostics: JumpHopLocal ("hop" / "landed"), JumpHopMoved (studs).
**Acceptance:** 18 ± 2 studs back, ~4 studs high, facing unchanged with W / S / no input held; 2 charges, 4 s each; raptor / dilo / therizino / teno / pachy leaps unchanged (JumpHopBack absent).

### Task 7 — Slow: SprintTest 1.22 + StatusBadges · Wired
SprintTest: while TrooSlowUntil > now the speed is x TrooSlowMul with the other part multipliers (MoveSpeedParts "trooSlow"; switch SprintTestTrooSlowEnabled). StatusBadges: the existing SLOW badge also shows while TrooSlowUntil (switch StatusBadgesTrooSlowEnabled).
**Acceptance:** a slowed player runs at 0.75x while inside, back 0.3 s after leaving; the SLOW badge shows on players and bots.

### Task 8 — TrooPose 1.0 + IdleAnimation · Wired
Mockup v0.1 key poses / timings (TA_WIND / TA_HOLD / TA_THROW / TA_FOLLOW; TH_SET / TH_AIR / TJ_LAND) mapped to Motor6D CFrames once and checked (hand position parity ±0.5 studs per key); sub-stepped springs like DiloPose; eyes flare during the throw (local: Head_eyeL / R Neon + brighter, restored).
**Acceptance:** numeric parity; Play capture next to the mockup; other dinos' poses unchanged.

### Task 9 — TrooFX 1.0 · Wired
Pod (glowing amber ball + trail) from the hands along TrooPodFrom → TrooPodTo over TrooPodFlight (arc); splat flash + burst; zone: teal disc + bright rim + spores rising for TrooZoneTime; enemy hit flash; heal "+N" on squadmates and the troodon in the Med-Station's MedHealPop look; soft-aim cone / ring for the owner while it throws (the Dilo's). Switch TrooFXEnabled. No jump-landing effects.
**Acceptance:** each effect seen in Studio captures, from the game camera and up close; nothing on other dinos.

### Task 10 — Docs + display + Studio check · Wired
VERSIONS / ATTRIBUTES rows; ROSTER 1.27 (troodon role "Area control + support", playable; therizino and dilo marked playable); display model rebuilt from 1.1; Play checks of every map row on held bots (and the test ally); regression of the other seven dinos; captures in docs/reference/troodon/.

## Red-team (Phase 4.5) — strongest challenges and proposed answers
Kepu's answers (2026-11-06): item 2 "Lead the target" (built into Task 4, switch attribute TrooPodLead); items 1, 3, 4, 5 "All as written".
1. **The squad heal can't be tested with a real squadmate** (house rule: never a second player). Mitigation: the Studio-only TrooTestAllyName hook makes one bot count as a squadmate for the heal path only; the real SquadRules call is the same one MedStationServer already uses in the Arena. Pre-publish check: the hook attribute is unset. Accepted risk: the first real squad heal happens in a live Arena.
2. **A pod aimed at where the target is lands after it has moved.** A raptor running at 78 covers ~43 studs in the 0.55 s flight, more than the 20-stud zone. Options: (a) **lead the target** — aim point = its position + its ground velocity x flight time, clamped to range (recommended: the zone lands where it's going; still dodgeable by turning); (b) aim where it was (easy to dodge, like a lobbed grenade). Needs Kepu's call.
3. **Heal strength.** One pod gives a squadmate +20 over 3 s; with 2 charges / 3 s refill a troodon can keep a zone up most of the time (~6.7 HP/s on a 60 HP raptor). Mitigation: zones don't stack, heals only inside the zone, all numbers are attributes; tune after the first Arena session. Accepted unless Kepu wants it weaker now.
4. **Changing the shared JumpTest.** The hop rides on the leap code every jumping dino uses. Mitigation: the hop runs only while JumpHopBack is true (only the troodon sets it), one switch turns it off, and Task 6 re-checks the five other leaps. A separate launcher (like DiloJetsLaunch) is the fallback if the Humanoid jump fights the backward velocity.
5. **Scope.** 10 tasks, 4 new scripts, ~11 extended. The troodon's mecha parts, a moves-animation polish pass and giving the Support stat an effect are separate later plans (the Dilo went the same way).
