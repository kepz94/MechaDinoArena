# Mecha Dino Arena v1.0 — Dilo kit (playable ranged spitter: Bite + Spit Dart, Cobra Leap on JUMP)

**Goal:** the Dilo is a pickable 70 HP ranged spitter: a tap of ATTACK is a quick bite up close; holding ATTACK 0.4 s and letting go spits a fast straight venom dart (soft aim); JUMP is a forward Cobra Leap with the frill flared.
**Intent (Kepu 2026-11-02 / 11-03):** role "Ranged spitter", size "Raptor size (~26)", model E Bruiser Face (DiloModelData 1.0, live display v359) · picks "C and J1" from `docs/mockups/dilo_kit_options_v0.1.html` (artifact DpirXAuqWz7t4tEyghKJpi) · health "70 HP" · dart "Weaker dart" (6 + venom 2/s for 3 s) · leap "No refill just like the Raptor" (plain JUMP with the raptor's 0.5 s cooldown, no charges).
**Chosen direction:** attack C · Bite + Spit Dart, jump J1 · Cobra Leap (mockup v0.1; its source with the key poses and timings: `tools/dilo_kit_mockup/app.js`, rebuilt with `node tools/dilo_kit_mockup/build.js`).
**Architecture:** the therizino playable pattern (THERIZINO_KIT_v1.0). Numbers are model attributes (DiloModelData 1.1). The attack is a new server + input pair (DiloAttackServer / DiloAttackTest) built from TheriAttackServer / TheriAttackTest's request → checks → timed resolve pattern; the dart uses the Goo Blob Shooter's soft-aim rule (HerreraMovesServer 1.2). The leap reuses JumpServer / JumpTest exactly like the raptor (JumpEnabled, JumpCooldown 0.5, no charges, no landing slam). Poses are a DiloPose module layered in IdleAnimation like TheriPose; effects in DiloFX.

## Global Constraints
- Additive: every change behind a switch; raptor / T-Rex / pachy / Herrera / teno / therizino behaviour unchanged.
- Versions: DiloModelData 1.1 (dilo_generator 1.1), StatSheet 1.6 (+ spec), SpeciesServer 1.7, RaptorScale 1.7, MainMenu 1.17, DiloAttackServer 1.0, DiloAttackTest 1.0, ArenaTouch 1.13, AbilityBar 1.25, DiloPose 1.0, IdleAnimation 1.43, DiloFX 1.0, display_models_install 1.2 (each bumps from the live version found at build time).
- Numbers (model attributes; distances at scale 1, x2 body in game): DinoMaxHealth 70; DiloAttackEnabled true; bite DiloBiteDamage 10, DiloBiteDelay 0.18 (press → contact), DiloBiteReach 5 (10 studs), DiloBiteCone 70°; dart DiloHoldTime 0.4 (hold to arm), DiloDartDamage 6, DiloVenomDps 2, DiloVenomTime 3, DiloDartRange 30 (60 studs), DiloDartSpeed 60 (120 studs/s), DiloDartCooldown 1.5, DiloAssistAngle 30, DiloAssistMin 0, DiloAssistMax 30 (60 studs); DiloMinGap 0.35 (bite to bite). Leap: JumpEnabled true, JumpCooldown 0.5, JumpStaminaCost 0, JumpCharges 0, JumpBoost / JumpLaunchPower tuned in Studio to a ~30-stud leap at the 2x body (mockup J1), TenoLeapOnJump false (no landing slam; TenoFX 1.1 rule: no jump-landing dust / seismic FX).
- Frill: the model's 8 "_fold" parts show at rest; the 48 "_frill" parts show while the hood is open (hold, spit, leap), local Transparency on each client (DiloPose), never replicated part edits.
- Every HUD change ships on PC (AbilityBar) and phone (ArenaTouch) together; one phone layout (big yellow ATTACK + JUMP).
- Install via multi_edit / execute_luau, verify by hash; test with Studio tools only (no second player); publish only on Kepu's "Publish" (both places). Saved progress untouched.

## Do-not-touch
DinoModelBuilder, JumpServer / JumpTest (reused through attributes), BiteServer / PounceServer / SlashServer / HeadbuttServer / TheriAttackServer / TenoAttackServer (patterns copied, not edited), HerreraMovesServer (soft-aim rule copied), WalkPose / JumpPose, other dinos' model data, SkinServer / SkinCatalog roles (the model's colour groups already exist), SkillTree (no dilo skill paths yet), the Lab, BotServer (no dilo bots).

## File structure
| File | New / extend | Responsibility |
|---|---|---|
| tools/dilo_generator.py 1.1 → src/shared/Models/DiloModelData.luau 1.1 | extend / regenerated | the attribute block above; body unchanged |
| src/shared/StatSheet.luau + tools/tests/StatSheet.spec.luau | extend | SPECIES.Dilo (class "Spitter") |
| SpeciesServer, RaptorScale, MainMenu | extend | pickable, 2x, menu entry "DILO · 70 HP · ranged spitter" |
| src/server/DiloAttackServer.server.luau 1.0 | new | bite + dart authority, venom ticks, stamps |
| src/character/DiloAttackTest.client.luau 1.0 | new | ATTACK tap / hold input, local prediction |
| ArenaTouch, AbilityBar | extend | phone ATTACK with hold ring + dart cooldown; PC ATTACK tile + JUMP tile |
| src/character/IdleAnimation/DiloPose.luau 1.0 + init | new + extend | bite, coil / spit, leap, frill open / fold |
| src/client/DiloFX.client.luau 1.0 | new | spit dart flight, venom splat + drips, bite flash, damage pops |
| tools/display_models_install.luau | extend | rebuild the display from 1.1 |

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Tap | ATTACK pressed and released before DiloHoldTime; alive, not menu / stunned / dazed / pinned; ≥ DiloMinGap since the last bite | bite: at press + DiloBiteDelay every allowed target in DiloBiteReach x scale and DiloBiteCone in front takes DiloBiteDamage x takenMul (shield blocks) |
| Tap too soon | < DiloMinGap | refused "cooldown" |
| Hold | held ≥ DiloHoldTime | armed (frill opens, ring full); no damage yet |
| Release armed | dart cooldown ready | dart: target = closest allowed enemy within DiloAssistAngle of the facing and DiloAssistMax x scale; else straight ahead to DiloDartRange x scale. Hit at release + distance / speed if the target is still within 4 x scale studs of the predicted point: DiloDartDamage + venom (DiloVenomDps per second for DiloVenomTime, refreshed by a new dart, no stacking; ticks skipped while shielded) |
| Release armed, on cooldown | < DiloDartCooldown since the last dart | refused "dartCooldown" (no bite) |
| Release before armed | < DiloHoldTime | it was a tap (bite row) |
| Stunned / menu / pinned / dead while held or in flight | any | hold cancelled (no dart); a dart already in flight still lands |
| Squadmate / mode-protected / shielded | SquadRules / ModeRules / EnergyShieldUntil | not a target / no damage (TheriAttackServer rules) |
| Back Plating | target with PlatingRearMul, attacker root (bite) or the dart's start point (dart) behind it | x PlatingRearMul (BoneCrest.plating), as every other attack |
| JUMP | JumpEnabled, ≥ JumpCooldown since the last leap | Cobra Leap (JumpTest physics); DiloPose crouch → air (neck coiled, frill open) → plain landing |
| Death | any | respawns as a dilo (SpeciesServer remembered choice) |

## Tasks
### Task 1 — DiloModelData 1.1 · Logic
Generator adds the attribute block (only those keys + DiloModelVersion change); regenerate; spec SkinCatalog still PASS; display rebuilt.
**Acceptance:** body blocks identical to 1.0; attributes diff = the listed keys.

### Task 2 — StatSheet · Logic
SPECIES.Dilo {class "Spitter", start values (Attack mid, Defense low, Speed mid-high), abilities "Bite + Spit Dart", "Cobra Leap (JUMP)"}; ATTACK_KEYS + DiloBiteDamage / DiloDartDamage scaling like TheriHitDamage1. Spec red then green.

### Task 3 — Selectable · Wired
SpeciesServer (template from DiloModelData, "Dilo" known, respawn, remembered; switch SpeciesDiloEnabled), RaptorScale (DiloScale 2; switch RaptorScaleDiloEnabled), MainMenu (DINOS entry; switch MainMenuDiloEnabled). Check SkillEffects' 1.37 leap writer on a dilo (JumpCooldown must stay 0.5, JumpCharges 0); if it rewrites them, a guard like 1.38's (switch SkillEffectsDiloLeapKeepEnabled).
**Acceptance:** menu reaches DILO; spawns 2x at 70 HP; leap has no charges and a 0.5 s cooldown after SkillEffects' refresh; the other six dinos spawn as before.

### Task 4 — DiloAttackServer 1.0 · Wired
Remote ReplicatedStorage.DinoDiloAttack(kind "bite" / "dart", stamp) → DiloAttackServerResult ("ok" / "badArg" / "dead" / "disabled" / "menu" / "stunned" / "dazed" / "pinned" / "cooldown" / "dartCooldown"). Stamps: DiloBiteAt / DiloDartAt (accepted, last), DiloDartFrom, DiloDartTo, DiloDartTarget, DiloDartFlight; DiloHitAt, DiloHitKind, DiloHitTargets ("|"), DiloHitPoint; target VenomUntil, VenomDps, VenomBy. Diagnostics: script DiloAttackRequests, DiloAttackHits, DiloVenomTicks. Switch DiloAttackEnabled (script). Back Plating through BoneCrest.plating.
**Acceptance:** every map row on a held bot; bite 10; dart 6 + 2/s x 3 = 12 (shield blocks both); no target → no hit, dart flies 60 studs; squadmate not hit.

### Task 5 — DiloAttackTest 1.0 + ArenaTouch + AbilityBar · Wired
CAS "DinoDiloAttack" (MouseButton1 via click handler, ButtonR2, touch) with tap / hold timing on the client (DiloLocalState "bite" / "coil" / "spit", DiloLocalAt) so the pose starts on the press; phone ATTACK = the big yellow button with a hold ring and the dart cooldown sweep; PC ATTACK tile with the same ring + JUMP tile (no charges, cooldown flash).
**Layout:** the same slots and look as the therizino's ATTACK / JUMP tiles (no new layout).
**Acceptance:** PC + forced touch; ring fills in 0.4 s; no default Roblox touch button (MDA-146 lesson).

### Task 6 — DiloPose 1.0 + IdleAnimation · Wired
Mockup v0.1 key poses / timings (bite lunge, coil S-neck, spit snap, leap crouch / air / land) mapped to Motor6D CFrames once and checked (mouth position parity ±0.5 studs per key); sub-stepped springs like TheriPose; frill open / fold visibility (local); throat sac swell before the spit.
**Acceptance:** numeric parity; Play capture next to the mockup; other dinos' poses unchanged.

### Task 7 — DiloFX 1.0 · Wired
Dart (green glowing glob + trail) from the mouth along DiloDartFrom → DiloDartTo over DiloDartFlight; splat + green drips while VenomUntil; bite flash; damage pops (white bite / green venom ticks); soft-aim ring on the locked target for the owner only while armed. Switch DiloFXEnabled. No jump-landing effects.
**Acceptance:** each effect seen in Studio captures; nothing on other dinos.

### Task 8 — Docs + Studio check · Wired
VERSIONS / ATTRIBUTES rows; Play checks of every map row on a held bot; regression of the other six dinos; captures in docs/reference/dilo/.

## Red-team (Phase 4.5) — strongest challenges and proposed answers
1. **A dart that homes on the soft-aim target always hits.** With a 120 studs/s dart and the server deciding the hit at arrival, a target that keeps running sideways is still hit if it stays within 4 x scale studs of the predicted point. Proposed: keep it (it matches "no aim mode" on phones); the dodge window is the 0.4 s hold + flight time. Accepted risk unless Kepu wants a miss chance.
2. **Tap vs hold on one button can feel laggy.** The bite only fires on release before 0.4 s, so every bite is delayed by the press length. Proposed: the bite fires on press (like every other ATTACK) and holding past 0.4 s ALSO arms the dart — so a hold = bite + dart. Needs Kepu's call: "bite on press" (snappier, bite + dart combo) or "bite on release" (mockup behaviour).
3. **SkillEffects' leap writer may rewrite the dilo's jump numbers** (it wrote the therizino's to 0 before 1.38). Mitigation: Task 3 checks it in Play and adds a guard only if needed.
4. **Venom on players needs the ArenaPvP bridge.** Venom ticks lower DummyHealth; on players the ArenaPvP bridge turns that into Humanoid damage (Arena only), as for the Herrera's bleed. No new path; Task 8 checks a tick on a test player target only through the hook (no second player).
5. **Frill open / fold is 56 parts toggled per client per state change** — cheap (Transparency writes on change, not per frame). No risk worth a change.
