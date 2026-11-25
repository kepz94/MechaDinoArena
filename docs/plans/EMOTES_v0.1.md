# Battle Emotes v0.1 (plan, not built)

Status: research + mockup 2026-11-24. Waiting on Kepu's picks. Nothing in Studio.
Mockup: docs/mockups/battle_emotes_v0.1.html (artifact 6JSHpr6HG5nSTqorCFXWDZ). Plays all 10 on the real rigs parsed from
src/shared/Models/*ModelData (Raptor 1.14, TRex 2.2, Pachy 1.6, Herrera 1.5, Teno 1.6, Therizino 1.8, Dilo 1.14, Troodon 1.11).

## Ask (Kepu 2026-11-24 19:27)
"in battle animations for Dino's ... look at how other games handle animations like these and ways that we can do animations
for our Dino's ... authentic, unique, funny, cool ... 10 animations that would work across the board". Store context (19:11):
animations will be sold in the shop next to skins and accessories.

## Grounding
- Every dino has the same rig 1.3 joints: RootJoint, Neck, Head, Jaw, ArmL/R, Tail1-5, LegL/R, KneeL/R, AnkleL/R
  (Therizino adds ElbowL/R, WristL/R). Joint frames: X forward, Y up, Z side; rz = pitch (+ lifts the front), ry = yaw, rx = roll.
- Animation is procedural: src/character/IdleAnimation (init 1.47) layers pose modules (RoarPose, BitePose, ...) from
  attribute stamps. No emote code exists today.
- So an emote = one pose function on shared joint names. One emote works on all 8 dinos; no keyframes per dino.

## The 10 (mockup v0.1)
| # | Name | HUD tag | Vibe | Length | Proposed price |
|---|---|---|---|---|---|
| 1 | Threat Display | THREAT | cool, real | 2.2 s | free |
| 2 | Stomp Stomp | STOMP | cool | 2.1 s | 499 (dust rings) |
| 3 | Moon Call | MOON CALL | cool, real | 2.8 s | 499 (sound rings) |
| 4 | Shake Off | SHAKE | funny, real | 1.7 s | 499 (droplets) |
| 5 | Pigeon Mode | PIGEON | funny, real | 2.6 s | 149 |
| 6 | Tiny Arms | TINY ARMS | funny | 2.4 s | 149 |
| 7 | Play Dead | PLAY DEAD | funny | 3.3 s | 149 |
| 8 | Big Yawn | YAWN | funny | 2.7 s | 149 |
| 9 | Strut | STRUT | cool, real | 3.0 s | 149 |
| 10 | GG Bow | GG | social | 2.0 s | free |

## Research takeaways
- Fight emotes are short (1.5-3 s). Moving / attacking cancels (Fortnite, Rivals, Overwatch).
- Camera must not change (Black Ops 4 emote free-look let players peek corners; locked in competitive modes).
- One emote for every character sells (Fortnite). Mute + cooldown stop spam (Clash Royale).

## Proposed rules (to confirm)
- Cancel on move, jump, ability, bite, or taking damage; blend back 0.15 s. Cooldown 3 s. Settings: mute other players' emotes.
- Build like the roar: new EmotePose module + attributes EmoteId / EmoteStartedAt, every number an attribute, master switch.
- Selling: one CATEGORIES entry in ShopScreen + ShopServer receipt router (SHOP_v1.0 agreed direction). Equip in the Lab LOOKS tab.

## Open (Kepu)
1. Emotes you fire, or packs that replace walk / run / bite?
2. Keep / swap which of the 10.
3. Trigger: A wheel (recommended), B quick bar of 4, C auto after a kill.
4. Prices (proposal: 2 free, 149 plain, 499 with effects).
5. Sound later (no Freesound / Sonniss clips in the public repo).
