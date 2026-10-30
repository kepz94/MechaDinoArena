# Mecha Dino Arena v1.0 — Playable Pachy + Headbutt Charge

**Goal:** the pachy is the third playable dino: picked in the menu, 2x like the raptor, with a headbutt charge as its ATTACK, charges, a self-slow downside, a leap, an attack line, and a charge pose.
**Intent (Kepu 2026-10-30, verbatim):** "i think its speed should be a bit slower than the raptor but faster than the t-rex. it should have a headbutt charge that speeds it up a bit and knocks opponents back with a debuff to their speed. it should come with two charges and max out at 3 charges fully statted up. the downside is if you use all your headbutt charges it debuffs your speed for a couple of seconds so you have to be wise with the charges once you get up to 3 it'll be a lot better. i think it should be able to leap as well as charge and leap for when it gets introduced to pvp when players try to jump out of the charge. when its in charge mode it should be pretty manueverable as well as have animations that indicate a speed up and the charge. the pachy should dip its head forward with intent like the inspo pick that i sent where its charging"
**Answers:** headbutt = ATTACK (left click / big yellow button) · health 90 · run 45 in the arena · 3rd charge from its own attack line · charge display A (pips) · damage "at least 20" -> 20 · other numbers "yes".
**Mockup:** `docs/mockups/pachy_charge_options.html` (option A pips). Model: `docs/plans/PACHY_MODEL_v1.0.md` (PachyModelData 1.0, approved "i like it").

## Numbers (all settings, tunable)
| Setting | Value |
|---|---|
| Arena run speed | 45 (base MoveRunSpeed 69.2 x ArenaSpeedScale 0.65); walk base 36.9 (raptor walk / run ratio) |
| Health | 90 |
| Charges | 2; 3 at the Battering Dome star |
| Charge | speed x1.4 of run, up to 1.8 s, ends early on a hit; turning about 2x the normal turn rate |
| Hit | 20 damage, knockback 30 studs, target speed -35% for 3 s |
| Refill | 5 s per charge, one at a time |
| Last charge used | self speed -35% for 2.5 s after that charge ends |
| Leap | the raptor's leap values; usable during a charge, keeps charge speed in the air |
| Battering Dome | I +25% damage · II +30% knockback · III refill 30% faster · star 3rd charge + spikes shown |
| Knockback | **shove 40 studs, stays on its feet, slowed at the same time** (Kepu: "It should be shoved maybe 40 studs and the opponent is debuffed at the same time") |

**More answers (red-team questions):** mecha parts: "Pachy parts later" (Drop 1 pachy has headbutt, leap and the shared stat lines) · knockback: shove 40 (above) · release: "Two drops".

## Drops
- **Drop 1 (this plan):** pickable pachy (menu), 2x in game, 90 HP, run 45, leap, headbutt charge with 2 charges, refill, self-slow, shove + slow on hit, ATTACK tile / button with pips, SLOWED tag, charge pose + speed FX, PvP credit, lifesteal hook.
- **Drop 2 (next plan):** Battering Dome line (I +25% damage, II +30% shove, III refill 30% faster, star 3rd charge + spikes shown).
- **Later:** pachy mecha parts; pachy bots.

## Global Constraints
- Additive; every new behaviour behind a switch. Versions per file (header changelog, VERSIONS.md row, ATTRIBUTES.md rows).
- Shield rule (precedent: the shock mine): Energy Shield up -> the shove and slow are blocked (damage is already blocked by the ForceField).
- Studio-tool testing only; Kepu publishes.

## Do-not-touch
- Raptor / T-Rex behaviour and numbers; RamServer / RamTest; PounceServer / BiteServer hit code; StunClient toss; BotServer (pachy bots out of scope); SkinServer (already knows Pachy).

## Tasks (Drop 1)
1. **PachyModelData 1.1** (generator 1.1, Logic: generator asserts) — gameplay attributes: DinoMaxHealth 90 (DinoHealthServer reads it first), MoveWalkSpeed 36.9 / MoveRunSpeed 69.2 (x0.65 = 24 / 45), GaitAlwaysRun true, TurnLimitRate 360, CameraStartZoom 18, raptor leap (JumpEnabled true, JumpWindup 0.12, JumpLaunchPower 59, JumpBoost 10, JumpBoostMinSpeed 2, JumpAirHold true, JumpStaminaCost 0, JumpCooldown 0.5), Headbutt* (Enabled true, Charges 2, Windup 0.15, SpeedMul 1.4, MaxTime 1.8, TurnMul 2, Damage 20, Shove 40, ShoveTime 0.35, SlowMul 0.65, SlowTime 3, Refill 5, SelfSlowMul 0.65, SelfSlowTime 2.5, Reach 2), gait scaled from the raptor by hip 4.0 / 3.3.
2. **StatSheet 1.2** — SPECIES.Pachy (class "Bruiser", abilities "Headbutt charge", "Leap"); ATTACK_PER_POINT.HeadbuttDamage 2 (+ ATTACK_KEYS) so the arena speed scale and stat points apply.
3. **SpeciesServer 1.2** — Pachy template from PachyModelData, spawn / respawn like the raptor (switch SpeciesPachyEnabled).
4. **RaptorScale 1.1** — Pachy scaled too (RaptorScalePachyEnabled, PachyScale 2).
5. **HeadbuttServer 1.0** — remotes DinoHeadbuttRequest / DinoHeadbuttHit / DinoHeadbuttEnd; server-owned charges (HeadbuttCharges, HeadbuttChargesMax, refill one at a time every HeadbuttRefill s), checks (disabled / dead / stunned / pinned / latched / busy / empty), HeadbuttStartedAt; hit claim validation (target Bitable with Hitboxes, not self, not KO, gap <= reach tolerance x scale, inside the charge window, one hit per charge); damage via DummyHealth with DebuffDamageTakenMul, Killed* stamps (KilledWith "headbutt"); shove + slow stamps on the target (players: HeadbuttShoveFrom / Dist / At + HeadbuttSlowMul / Until; bots: server shove + MineSlow-style slow); attacker HeadbuttHitDamage / HeadbuttHitTarget / HeadbuttHitAt (last); self-slow after the last charge ends; shield blocks shove + slow.
6. **HeadbuttTest 1.0** (client) — LMB (Pass, guarded like PounceTest 1.5) + CAS touch button "DinoHeadbutt"; prediction; windup; charge drive: WalkSpeed = run x SpeedMul, steering from the move input (TurnLimitRate x TurnMul during the charge); contact = own Hitboxes Head grown by Reach overlapping another dino's Hitboxes -> DinoHeadbuttHit; leap allowed during the charge (charge speed kept in the air).
7. **HeadbuttShove 1.0** (client, players) — reads the shove stamp, pushes the own body away 40 studs over 0.35 s on its feet. **SprintTest 1.9** — HeadbuttSlowUntil / HeadbuttSlowMul applied like MineSlow (also the self-slow).
8. **HeadbuttPose 1.0 + IdleAnimation layer + HeadbuttFX 1.0** — windup head dip, charge: body low, head dipped so the dome leads, tail straight; impact snap; speed lines + dust while charging.
9. **HUD** — AbilityBar 1.7 (Pachy moves Headbutt (ATTACK, LMB, pips) + Leap; SLOWED tag), ArenaTouch 1.5 (big ATTACK = headbutt with pips), MainMenu 1.8 (card "PACHY · 90 HP · headbutt charger"), ArenaStatus 1.5 (species entry).
10. **Hooks** — ArenaPvP 1.1 credit watcher on HeadbuttHitAt; SkillEffects 1.12 onHit for HeadbuttHitAt (lifesteal); SkillTree 1.19 jaws.notFor Pachy (Battering Dome is its attack line, Drop 2); ArenaScope 1.18 expects the new scripts.
