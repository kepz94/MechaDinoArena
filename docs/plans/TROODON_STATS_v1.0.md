# Mecha Dino Arena v1.0 — Troodon stat rows (own rows, the 1.37 rule)

**Goal:** the Troodon stops using the default stat rows and gets its own (Kepu 2026-11-10 11:54: "Why do you have the troodon stats on the default names?").
**Picks (Kepu 2026-11-10 12:00, mockup docs/mockups/troodon_stats_v0.1.html, artifact EZGqToxiZRTogurQB6ap3m; 12:03 "Build"):** Glow Feeder + Spore Leech (Health), Hunter's Eyes (Attack), Zone Ward (Defense), Quick Feet (Speed), Night Watcher (Signature).
**Architecture:** SkillTree 1.88 `TROO_STATS` (notFor.Troodon on regen / lifesteal / jaws / hide / legs, 6 Troodon paths tfeeder / tleech / teyes / tward / tfeet / twatch, effects). SkillEffects 1.60 writes `TrooStat<Row><Field>` on a Troodon when bought (stat rows: no slot), plus JumpDoubleForward / JumpAirJumps for Quick Feet. Effects live in the scripts that already own each system; every change behind a switch.

## Rows (I / II / III / ★)
| Row | I | II | III | ★ | Where |
|---|---|---|---|---|---|
| Glow Feeder | heal 2/s in your own (newest) zone | 2.7/s | squadmates' zone heal x1.35 (5 -> 6.75) | zone heals keep going 1 s after leaving | TrooAttackServer 1.7 (tick / makeZone wrappers) |
| Spore Leech | each zone tick that hurts an enemy heals you 1 | 1.35 | squadmates in that zone get it too | an enemy that dies in your zone heals you 10 | TrooAttackServer 1.7 |
| Hunter's Eyes | pods lock on and reach 35% farther (80 -> 108) | a pod splat marks the enemy 3 s | marked enemies take 10% more damage | marked enemies show through walls for your squad | TrooAttackServer 1.7 (get wrapper, splat wrapper), BoneCrest 1.8 (armor x TrooMarkedMul), TrooStatsFX 1.0 |
| Zone Ward | 10% less damage inside your own zones | 13.5% | squadmates in your zones too | lasts 1 s after leaving | TrooAttackServer 1.7 stamps TrooFortifyMul / Until (TrooMovesServer's live refund) |
| Quick Feet | run x1.05 (86 -> 90.3) | flaps +30 studs/s forward (~35%) | a 3rd flap (JumpAirJumps 2 -> 3) | a glide landing drops a 3 s trail: squadmates on it run x1.1 for 3 s | SprintTest 1.25, SkillEffects 1.60, TrooStatsServer 1.0 + TrooStatsFX 1.0 (landing remote) |
| Night Watcher | enemies within 40 studs outlined through walls | 54 studs | your squad sees them too | your first pod on an enemy that hasn't hit anyone in 5 s (and wasn't hit by a troodon zone in 5 s) splats double | TrooStatsServer 1.0 (TrooSeen* stamps, LastDealtAt tracker), TrooStatsFX 1.0, TrooAttackServer 1.7 |

## Do-not-touch
The other dinos' rows, the Troodon's mecha parts, TrooSlotServer / TrooSlotFX, the pod and zone numbers, saved progress (points on the 5 hidden rows come back through sanitize, the Teno / Therizino way).

## Tasks
1. SkillTree 1.88 + spec SkillTreeTrooStats 1.0 (Logic). 2. SkillEffects 1.60 (Wired). 3. TrooAttackServer 1.7 + BoneCrest 1.8 (Wired). 4. TrooStatsServer 1.0 + TrooStatsFX 1.0 + SprintTest 1.25 (Wired). 5. Studio check + docs (not published).

## Red-team
1. **Hunter's Eyes III hits from everyone.** "+10% from your squad" needs the attacker on every hit; the shared hook every damage script calls (BoneCrest.armor) only knows the victim. Built as +10% from every hit while marked. Named in the report.
2. **Night Watcher ★ "hasn't hit anyone".** Built from the LastHitBy / LastHitAt stamps the damage scripts write on their victims; scripts that don't write them make their attackers look "unaware". Best effort, named.
3. **Outlines through walls are strong.** Up to 54 studs, squad-wide at III. Capped at the 10 nearest (Highlight limit 31 per player). Numbers are attributes.
4. **The Troodon loses the hidden rows' stat points.** Jaws / Thick Hide gave Attack / Defense points (+1 pod damage per Jaws step). Spent points come back to re-spend. Fits "lower the damage".
5. **Quick Feet ★ trusts the client's glide landing.** The server can't see the glide; the request is checked (Troodon, ★, 1.5 s gap, within 12 studs of the root).
6. **Hunter's Eyes I also raises the throw range** (80 -> 108), otherwise a longer lock-on does nothing.
