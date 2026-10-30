# Mecha Dino Arena v1.0 — Pachy Blood Rush

**Goal:** when the pachy's headbutt charges are empty, it can pay health for more headbutts, so a player who runs dry can keep fighting at a cost.
**Chosen direction:** HUD look "C · Both" (hearts + striped health chunk), name "Blood Rush". Mockup: docs/mockups/pachy_sacrifice_options.html.
**Architecture:** a new pachy part line `bloodrush` in the Attack area, in a slot like Mecha Legs (it fires through ATTACK, not its slot key). HeadbuttServer accepts a press at 0 charges as a "sacrifice" when Blood Rush is on and health is above half, takes the health, and runs a normal charge flagged as a sacrifice. A new BloodRushServer applies the ★ bleed. The HUD and the FX read the attributes.

## Kepu's answers (2026-10-30)
- "For attack you can sacrifice 25% of your life for another headbutt. This caps out at 50% so you could get two extra head butts after emptying your charges"
- Own Attack line; same ATTACK button; "It should take up a slot. Just like the mecha legs do"
- Allowed while health is above 50% before the press (at 60% it may go to 35%); never takes the last point (leaves 1 HP).
- HUD: C · Both. Name: Blood Rush.
- Steps: II and III as proposed; ★ "I don't want the highest you give a heal payback. Have it make the other Dino bleed as well" -> "Bleed (3/s for 4 s)".
- "It should work against players too whatever works against bots works against players same mechanic": the bleed hits players with the same numbers wherever players can hurt players (the Arena; the Sandbox has no player damage, ModeRules 1.0).

## Steps (SkillTree)
| Step | Effect fields | What it does |
|---|---|---|
| I | bloodRush true, bloodCost 0.25 | At 0 charges, ATTACK pays 25% of max health for one more headbutt; only above 50% health; never the last point |
| II | bloodDamageMul 1.25 | Sacrifice headbutts hit 25% harder (on top of the run-up rule and the Dome) |
| III | bloodNoSelfSlow true | No self-slow after a sacrifice headbutt |
| ★ | bloodBleedDps 3, bloodBleedTime 4 | A sacrifice headbutt that lands makes the target bleed 3 a second for 4 s |

## Global constraints
- Additive only, each change behind a switch, version header + docs/VERSIONS.md + docs/ATTRIBUTES.md rows.
- Shipped maxed through the test layer (SkillTestCloakEnabled gives live parts at ★ and slots them).
- Install by multi_edit, verify by hash; Studio tests with own pachy and bots only.

## Do-not-touch
- Normal headbutt charges, refill tiers, run-up rule, shove / slow: unchanged when no sacrifice is involved.
- SkillEffects' existing bot bleed (Jaws / Blade): not reused or changed; Blood Rush has its own bleed.
- ArenaPvP bridge, ModeRules: read only.

## Tasks
1. **SkillTree 1.24** (Logic): path `bloodrush` "Blood Rush" (mecha, live, OWNER Pachy, BUTTONS, Attack area) with the step texts above; effects fields. Switch SkillTree.BLOOD_RUSH. Spec checks.
2. **SkillEffects 1.17** (Wired): while bought AND slotted on a pachy: BloodRushEnabled, BloodRushCost, BloodRushDamageMul, BloodRushNoSelfSlow, BloodRushBleedDps, BloodRushBleedTime (off values otherwise). Switch SkillEffectsBloodEnabled.
3. **HeadbuttServer 1.5** (Wired): at 0 charges, a request is a sacrifice when BloodRushEnabled and Humanoid.Health > 50% of MaxHealth: Humanoid.Health is set directly to Health - cost x MaxHealth, at least 1 (not TakeDamage, which the Energy Shield's ForceField would block), st.active.sacrifice = true, stamps HeadbuttSacrificeAt (last), HeadbuttSacrificeCost, HeadbuttSacrificeCount; else "empty" / "lowHealth". Hit: damage x BloodRushDamageMul, HeadbuttHitSacrifice true. Finish: self-slow skipped when BloodRushNoSelfSlow. Switch HeadbuttSacrificeEnabled.
4. **HeadbuttTest 1.1** (Wired): the local "empty" gate lets the press through when BloodRushEnabled and health > half.
5. **BloodRushServer 1.0** (new, Wired): on HeadbuttHitAt with HeadbuttHitSacrifice and bleed > 0: the target bleeds BleedDps / s for BleedTime s off DummyHealth (bots; players only where ModeRules.canAffect says so, through the ArenaPvP bridge); a new bleed restarts it; kill credit KilledWith "bleed" (KilledAt last). Target BloodBleedUntil / BloodBleedBy.
6. **HUD** (Wired): AbilityBar 1.10 (ATTACK tile: red border + hearts + "-25% HP" tag at 0 charges; bloodrush slot tile key "LMB"), HealthBar (striped cost chunk + half mark while a sacrifice is ready), ArenaTouch 1.6 (hearts under the big ATTACK button), MechaButtons 1.17 (slot button "BLOOD RUSH", readiness).
7. **HeadbuttFX 1.1** (Wired): on HeadbuttSacrificeAt: red flash + red "-22.5" over the pachy, red streak on the charge; a bleeding dino drips red (BloodBleedUntil).
8. **ArenaScope 1.21 + docs + Studio test**: ATTACK at 0 charges from full: 90 -> 67.5 -> 45, third press refused; damage x1.25; no self-slow at III; bot bleeds 12 over 4 s; HUD hearts and chunk; FX.

## Branches
| Condition | Result |
|---|---|
| charges >= 1 | normal headbutt (no change) |
| charges 0, Blood Rush off / not slotted / not a pachy | "empty" (no change) |
| charges 0, on, health > 50% | sacrifice: health -25% (never below 1), charge runs |
| charges 0, on, health <= 50% | "lowHealth", nothing happens; the HUD hearts are grey |
| sacrifice hit, ★ | target bleeds 3/s for 4 s (players: Arena only) |
| sacrifice miss | health is still spent (same as a spent charge) |
| stunned / pinned / busy / hook running | refused before any health is taken |

## Red-team (to answer before the build)
1. Regen can refill past half health (Regeneration, kill regen), so a pachy could sacrifice again and again over a long fight. Bounded by health, never by a timer. Mitigation option: none (accepted risk), or a cap per empty spell.
2. A sacrifice that misses still costs the health, like a spent charge. Option: keep, or refund the health on a miss.
3. "Whatever works against bots works against players": today the raptor's Jaws III and Blade Claws III bleed only hits bots (SkillEffects 1.x, bots only). Blood Rush bleed will hit players in the Arena. Option: a follow-up ticket to make those two bleeds hit players too, with the same bleed script.
4. Accepted: a sacrifice from 60% may drop the pachy to 35% (Kepu's pick); the hearts show how many are left from the current health.
