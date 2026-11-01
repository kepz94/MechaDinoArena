# Mecha Dino Arena v1.0 — Tenontosaurus kit (playable tank, scratch + rear tail slam, rearing leap)

**Goal:** the teno is a pickable tank: tap ATTACK for a quick claw scratch, hold ATTACK and release for a huge rear tail slam that launches whatever is chasing it and bucks off raptors latched on its back; its jump is a rearing leap.
**Intent (Kepu 2026-10-31):** "two different types of attacks ... a scratch attack for low damage or a heavy tail slam attack" + video inspiration ("way more animated with more effects to really sell the power of the slam") · scope "Yes, playable + attacks" · controls "Tap = scratch, hold = slam" · "Tail slam should have 3 charges and a 8 second cool down" · "It'll be a tank, create its jump animation as well and make it selectable so I can test it" · slam "a rear slam it lifts and slams its tail in that back. It'll be good to run away and tail slam enemies chasing it as well as slam off pouncing raptors" · jump "I want the second leap" (J2 Rearing Leap) · numbers: no preference -> the mockup's tank proposal.
**Chosen direction:** mockup `docs/mockups/teno_attacks_options.html` v0.2: slam D "Rear Tail Slam", jump J2 "Rearing Leap", scratch as shown.
**Architecture:** the Herrera / pachy playable pattern. Numbers are model attributes (TenoModelData 1.1). New scripts own the new moves: TenoAttackServer (authority, damage, launch, buck-off through the ShakeOff protocol), TenoAttackTest (input: one CAS action with Begin / End for tap vs hold, local prediction), TenoPose (an IdleAnimation layer module), TenoFX (all clients: slam / scratch / landing effects), TenoJump (leap numbers, like HerreraJump). Species / scale / menu entries are small additive branches in the existing scripts.

## Global Constraints
- Additive: every change behind a switch; raptor / T-Rex / pachy / Herrera behaviour unchanged.
- Versions: TenoModelData 1.1 (generator 1.1), StatSheet 1.4, SpeciesServer 1.5, RaptorScale 1.4, MainMenu 1.12, TenoJump 1.0, TenoAttackServer 1.0, TenoAttackTest 1.0, TenoPose 1.0, IdleAnimation 1.37, TenoFX 1.0, ArenaTouch (overlay), AbilityBar (tile).
- Numbers (model attributes, tunable): DinoMaxHealth 150; MoveWalkSpeed 30 / MoveRunSpeed 52 (x arena scale like every dino); CameraStartZoom 24; TurnLimitRate 240. Scratch: TenoScratchDamage 8, TenoScratchGap 0.5 s, TenoScratchReach 5.5 (x scale = 11 studs in front), TenoScratchShove 6. Slam: TenoSlamDamage 40, TenoSlamCharges 3, TenoSlamRefill 8 s per charge, TenoSlamHoldMin 0.22 s, TenoSlamRange 15 (x scale = 30 studs, behind the hips), TenoSlamArc 220 (degrees, centred on the back), TenoSlamToss 35 studs, TenoSlamStun 1 s, TenoSlamDropTime 0.13 s (release -> impact). Leap: JumpEnabled with a ~9-stud hop (TenoJump), no stamina cost, cooldown 1 s.
- Hold rules: press = start the hold; release before TenoSlamHoldMin = scratch; release after = slam (needs a charge; no charge = a scratch). Max wind-up 1 s (held longer = still waiting, released = slam).
- Install via multi_edit / execute_luau, verify by hash + loadstring; test with Studio tools only; publish only on Kepu's "publish".

## Do-not-touch
DinoModelBuilder, the other dinos' model data, BiteServer / PounceServer / SlashServer / HeadbuttServer, WalkPose / IdlePose / ScurryPose / JumpPose (the teno's leap uses its own pose), ShakeOffServer (the slam uses its protocol, not its code), SkinServer, Lab, SkillTree (the teno has no skill paths yet).

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Tap | ATTACK pressed and released within TenoSlamHoldMin, not stunned / pinned / menu / dead, gap since last scratch >= TenoScratchGap | Scratch: front-right claw swipe; every allowed target whose root is within reach x scale in front (90° cone) takes TenoScratchDamage and a small shove |
| Scratch too soon | gap not passed | refused "cooldown" (no animation) |
| Hold | ATTACK held >= TenoSlamHoldMin, a charge left | wind-up: hips up, tail lifted high and glowing (owner local; others see TenoHoldSince) |
| Hold, no charge | held >= HoldMin, 0 charges | released = scratch; the pips flash |
| Release after hold | a charge left | Slam: charge used (refill timer starts if not running), tail drops in TenoSlamDropTime; impact: every allowed target in the rear zone (within range x scale of the hips, inside TenoSlamArc centred on the back) takes TenoSlamDamage, is tossed TenoSlamToss studs away from the teno and stunned TenoSlamStun s (players: StunClient toss; bots: BotServer toss) |
| Latched raptor | any PounceLatched model whose latch part is in the teno, at impact | shaken off: ShakeOffReason "slammed", ShakeOffAt, toss + stun as above (PounceServer releases), also damaged |
| Squadmate / mode-protected | SquadRules / ModeRules say no | not hit |
| Energy Shield up | EnergyShieldUntil > now | takes no damage, still tossed |
| Recharge | charges < max | +1 charge every TenoSlamRefill s |
| Stunned / pinned / menu / dead | any press | refused with a reason (TenoAttackServerResult) |
| Leap | JUMP, JumpEnabled (TenoJump) | rear-up crouch -> launch -> air -> landing squash + ground-thump effects (no damage) |

## Tasks
1. **TenoModelData 1.1** (Logic) — generator 1.1 adds the attributes above; geometry unchanged. Acceptance: only attribute / version lines differ; hash checked.
2. **StatSheet 1.4** (Logic) — SPECIES.Teno {class "Tank", start Health 9 / Attack 5 / Defense 8 / Speed 3 / Support 1, abilities "Scratch + tail slam", "Rearing leap"}; ATTACK_KEYS + TenoScratchDamage (1 / point), TenoSlamDamage (2 / point). Spec first.
3. **Selectable** (Wired) — SpeciesServer 1.5 (teno template, "Teno" known, respawn, remembered; SpeciesTenoEnabled), RaptorScale 1.4 (TenoScale 2), MainMenu 1.12 (DINOS entry "TENO", "150 HP · tank, tail slam"; MainMenuTenoEnabled). Acceptance: menu arrows reach TENO; DinoSpeciesRequest "Teno" ok; spawns 2x, 150 HP; death respawns a teno; others unchanged.
4. **TenoJump 1.0 + leap pose** (Wired) — leap numbers (JumpEnabled true, JumpWindup 0.28, launch for ~9 studs, JumpStaminaCost 0, JumpCooldown 1); TenoPose.leap (J2: rear-up crouch, air, landing squash) used by IdleAnimation 1.37's leap layer on Species "Teno"; TenoFX landing ring + dust + rocks on JumpLandedAt.
5. **TenoAttackServer 1.0** (Wired) — remote DinoTenoAttack(kind, stamp): "scratch" / "slam"; checks, charges (TenoSlamCharges / TenoSlamLeft / TenoSlamRefillAt), hits as the map, stamps (TenoScratchAt, TenoSlamAt, TenoSlamImpactAt, TenoSlamPoint, TenoSlamHits, TenoHoldSince); switch TenoAttackServerEnabled; SquadEnabled / SquadSkips like the others.
6. **TenoAttackTest 1.0 + ArenaTouch overlay + AbilityBar tile** (Wired) — CAS "DinoTenoAttack" (MouseButton1, ButtonR2, touch button) with Begin / End; tap vs hold; local prediction stamps (TenoLocalState, TenoLocalAt); the big yellow ATTACK on touch with 3 charge pips; PC bar tile with pips + refill.
7. **TenoPose 1.0 + IdleAnimation 1.37** (Wired) — scratch / hold / slam / leap angles from the mockup (D and J2), layered like SlashPose (owner local, others server stamps).
8. **TenoFX 1.0** (Wired) — slam: hit-stop on the owner, flash, double shockwave ring + wall, ground cracks behind, rocks, dust, camera shake for players near, tail glow while held; scratch: 3 claw streaks + number; leap landing thump.
9. **Studio check** — PC (+ forced touch layout): select, spawn, scratch on a dummy, slam behind on a bot chasing, latched raptor bot bucked off, charges + refill, leap; captures in docs/reference/teno/.

## Red-team (one paragraph per risk)
1. **IdleAnimation is a 1,337-line hot file**: the teno layer is one guarded block after the slash layer (Species "Teno" only), so every other dino's pose path is unchanged; hash + Play check of a raptor and Herrera after install.
2. **Quadruped on the T-Rex walk**: the teno walks with WalkPose (front legs as arms) until its own gait plan; accepted for this test build (Kepu asked to test the attacks and jump).
3. **Tap vs hold latency**: the hold decision is made on the client (release time) and the server only checks charges and the gap; a fake "slam" from a modified client still needs a charge, so the worst case is the normal slam.
4. **Toss on players** relies on StunClient's existing toss (ShakeOff protocol): the same path the T-Rex ram uses, already live.
