# Mecha Dino Arena v1.0 — Pachy Mecha Parts: Mecha Legs + Grappling Hook

**Goal:** the pachy gets its first two mecha parts: a passive Speed line (better leap, double jump at the star, mecha legs shown) and an Attack button part (right-arm grappling hook that pulls a dino in for a head smash).
**Intent (Kepu 2026-10-30, verbatim):** "one of them will be under speed it can gain mecha legs after fully leveling it up. this will allow it to leap forward and higher as well as unlock a double jump in the air. the other actual mecha ability would be a grappling hook that can hook to players and bring them in for a headsmash at 10 damage instead of 20 because youre not charging. in that animation it would pull them in then the pachy would dip its head for a smash which knocks them back without the slowed effect." · "i want the grappling to be connected to its right arm. something thats not too bulky looking but it will be something he lifts his arm to shoot" · "dont allow the grappling hook to work on objects tho like you cant pull yourself up to a tree this will be strictly for pvp or bots"
**Answers:** Mecha Legs = new pachy Speed line · hook grabs players and bots · hook in Attack · own cooldown (not a headbutt charge) · "yes i like these" = mockup picks A Piston shins, A Wrist claw, crosshair + aim help, step numbers as shown.
**Mockup:** `docs/mockups/pachy_parts_options.html`.

## Numbers (tunable attributes)
| Part | Step | Effect |
|---|---|---|
| Mecha Legs | I | leap forward boost x1.25 (JumpBoost) |
| | II | leap launch power x1.2 (JumpLaunchPower) |
| | III | leap cooldown x0.65 (stacks with Sprint Legs III) |
| | ★ | double jump: 1 extra jump in the air at 80% of a leap's height (vertical speed x0.89), also out of a headbutt charge; piston shins shown |
| Grappling Hook | I | button: arm up 0.15 s, fire along the aim, range 60, aim help radius 4 studs; grab -> 0.5 s pull to 1 body length in front; head smash 10 damage + shove 30 (HeadbuttShove, no slow); cooldown 8 s |
| | II | range 80 |
| | III | cooldown 6 s |
| | ★ | smash 15 damage |

## Rules
- The hook only grabs dino hitboxes (players' dinos and bots: Bitable, Hitboxes, Species or IsBot; not self, not KO). Terrain, trees, rocks and props are never targets; a world hit before a dino along the line ends the shot as a miss (no pulling through walls, no pulling yourself anywhere). Miss = the claw reels back, cooldown still starts.
- Energy Shield on the target blocks the grab ("shielded"; cooldown starts).
- Hook and headbutt can't overlap: hook refused while charging ("busy"); charge refused while hooking.
- Stunned / pinned / dead / in menu refused, like the other parts.
- Paths are pachy-only (OWNER Pachy) and their effects are written only while the character's Species is "Pachy".

## Drops
- Order (Kepu 2026-10-30 "lets do battering dome first. then address these two"): Battering Dome (PACHY_PLAYABLE Drop 2) -> **Drop A — Grappling Hook** -> **Drop B — Mecha Legs**.

## Red-team (2026-10-30) — Kepu's answers
1. Pachy upgrades leaking to other dinos: Kepu "man all these skill trees and abilites should be dino specific" / "I always thought it was Dino specific". **Correction (checked in code 2026-10-30): it already is.** SkillServer 1.2+ (MDA-44, docs/plans/SKILLS_PER_DINO_v1.0.md) keeps XP, level, points, bought steps and loadout per dino (DataStore MDA_Skills_v2, `dinos[species]`; SkillPerDinoEnabled default true) and publishes only the active dino's SkillPath_* / SkillSlot*, so a pachy line never reaches the raptor. The challenge was wrong; no new plan. The Species == "Pachy" gate on writes stays as a cheap guard only.
2. Fresh ids `hookarm` / `mechalegs`, `grapple` stays dead: "okay sounds good".
3. Mecha parts in colours no skin paints: "okay".
4. Server distance check before the smash on player targets (laggy / exploit escape = miss); walls block the hook: "okay".
5. Split into two drops: "lets do battering dome first. then address these two".

## Global Constraints
- Additive; every new behaviour behind a switch. Versions per file (header changelog, VERSIONS.md row, ATTRIBUTES.md rows). Studio-tool testing only (never a second player: player-side pull / shove tested by stamping the own pachy, as Drop 1); Kepu publishes.
- New path ids `hookarm` and `mechalegs` (`legs` is Sprint Legs; `grapple` is a deleted id whose old saves are dropped by sanitize and must stay dropped).
- New mecha parts are runtime models with colours outside every skin role (SkinServer never paints them).

## Do-not-touch
- Raptor / T-Rex moves and numbers; Sprint Legs (`legs`) texts and effects; Thrusters / MechaAirUp; HeadbuttServer charge rules; StunClient; BotServer AI.

## Tasks
### Drop A — Grappling Hook
1. **SkillTree 1.20** (Logic, spec 1.17) — PATHS.hookarm "Grappling Hook" in attack, OWNER Pachy, LIVE_MECH, BUTTONS; step texts; effects hookRange (0 / 60 / 80), hookCooldown (0 / 8 / 6), hookDamage (0 / 10 / 15), hookEnabled; `grapple` stays unknown.
2. **SkillEffects 1.13** — HookEnabled (bought, in a slot, Species Pachy), HookRange, HookCooldown, HookDamage, HookLook.
3. **HookServer 1.0** — remote DinoHookRequest(stamp, aimDir); checks badArg / dead / disabled / menu / stunned / pinned / busy (headbutt or hook running) / cooldown; aim from the right wrist along aimDir: world raycast (blocks) + sphere sweep radius 4 against dino hitboxes only; result hit / miss / shielded / blocked; HookStartedAt, HookTarget, HookReadyAt; pull: player target gets HookPullFrom / HookPullTo / HookPullTime / HookPullAt (last), bot target anchored glide; at pull end smash: gap check, damage via DummyHealth (KilledWith "hook"), shove via the HeadbuttShove stamps (no slow; bots shoveBot-style), attacker HookHitDamage / HookHitTarget / HookHitAt (last); HookResult.
4. **HookArm 1.0** (client, pachy) — slot press via MechaButtons TIMED_PARTS.hookarm {"Hook", "DinoHookRequest", "GRAPPLING HOOK"}, sends the camera look; local arm-raise state.
5. **HookPull 1.0** (client, victim) — pulls the own body to HookPullTo over HookPullTime (held: no own movement).
6. **Look + pose + FX** — HookArmServer 1.0 builds the slim wrist claw on ArmR while HookLook; HookPose (IdleAnimation 1.30: arm up, reel, head dip smash); HookFX 1.0 (chain line + claw flying, clamp flash, smash flash, damage number).
7. **HUD + hooks** — AbilityBar TIMED_PARTS.hookarm, MechaButtons entry, ArenaTouch slot button (MechaButtons touch), HeadbuttServer 1.1 "busy" while hooking, HeadbuttTest refuses while hooking, ArenaPvP credit on HookHitAt, SkillEffects onHit (lifesteal), LabPreviewServer source, ArenaScope.
### Drop B — Mecha Legs
8. **SkillTree / SkillEffects** — PATHS.mechalegs in speed, OWNER Pachy, LIVE_MECH (passive, not BUTTONS); effects leapBoostMul, leapPowerMul, leapCdMul, doubleJump, legsLook; SkillEffects writes JumpBoost / JumpLaunchPower from SkillBase_ values x the muls, JumpCooldown x leapCdMul, JumpDoubleEnabled, MechaLegsLook (Species Pachy only).
9. **JumpTest 1.1 + JumpServer 1.2** — one air jump while JumpDoubleEnabled and not used since leaving the ground (Space / jump button again in "air"); server accepts kind "double" (once per airtime, no cooldown wait); JumpDoubleAt / JumpDoubleCount; IdleAnimation JumpPose replays the launch.
10. **MechaLegsServer 1.0 + FX** — piston shin covers + heel vents on the shins while MechaLegsLook; heel vent puff + ring on the double jump; Lab preview.
