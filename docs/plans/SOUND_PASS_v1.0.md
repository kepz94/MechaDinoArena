# Mecha Dino Arena — Sound pass v1.0 (build 1: core game sounds)

**Ask (Kepu 2026-11-16 14:38):** "okay lets do the sound pass".

**Picks:**
- Style: "Mixed". Combat sounds are punchy and real; menus, confirms and point events are 8-bit.
- Scope: "Core first, then dinos". Build 1 is the game events; each dino's abilities come after, one dino at a time.
- Audition: "Sound board in Studio".
- From the Sound Pick Board page (docs/mockups/sound_pick_board_v0.1.html), 14:50: "hit A, kill A, captured C, lost A, contested A, moving C, tick C, go B, click B, win A, lose A".
- Kepu did not use the Studio board. Getting hit and death sounds are left out of build 1.

## Today (code facts)
- About 10 scripts play any sound: the old Dino Arcade bite / roar / pounce / headbutt / level-up, plus mines, the hook and the mecha boost. Every game event below is silent.
- **Hits.** TrooStatsServer stamps `LastDealtAt` on the attacker for every LastHitAt / TrooHitAt / KilledAt it causes.
- **Kills.** Every kill path sets `KilledBy` (the killer's character name) and `KilledByUserId`, then `KilledAt`.
- **Hardpoint state** is replicated on the ReplicatedStorage.Hardpoint folder:
  - `HpPhase`: warmup / live / results.
  - `HpOcc`: N / A / B / C.
  - `HpIndex`, `HpPointEndsAt`, `HpWinner`.
  - The player's team is the player attribute `HardpointTeam`.

## The sounds
- 11 original 8-bit sounds made for this game, so there is no licence risk.
- Files: docs/sfx/MDA_SFX_<event>.wav. Generator: docs/sfx/gen_8bit_sfx.py.
- Copies are in Kepu's Music\MechaDinoArena_SFX folder for upload.

## Rules (GameSounds 1.0, new LocalScript in StarterPlayerScripts)
1. **How a sound plays.** Each event plays a 2D local sound, through SoundService:PlayLocalSound into the SoundGroup GameSFX. Only you hear it.
2. **Event triggers:**
   - **hit:** your LastDealtAt changes, at most once per 0.07 s.
   - **kill:** any dino's KilledAt changes with you as the killer (read a frame later).
   - **captured / lost / contested:** HpOcc while live, against your team. The same sound doesn't repeat within 1 s.
   - **moving:** 5 s before each point ends.
   - **tick:** countdown 3, 2, 1.
   - **go:** warmup → live.
   - **win / lose:** results vs HpWinner. A draw plays nothing.
   - **click:** buttons in the menu, Lab, pre-game, island and respawn screens. Not the ability or attack buttons.
3. **Not in the menu.** Nothing plays while InMenu, except click (and win / lose).
4. **Settings.** Every id, volume and switch is a script attribute. An empty id means silent until the uploads are wired in.

## Do-not-touch
Every server script, the existing sound scripts, Music, HardpointHUD, PrematchCountdown.

## Red-team (folded in)
- **"Hit spam."** One hit sound per 0.07 s at most, at volume 0.5.
- **"Kill sound for someone else's kill."** It plays only when KilledBy is your name or KilledByUserId is your id.
- **"Menu clicks on combat buttons."** Only a named list of menu ScreenGuis gets clicks (GameSoundsClickGuis).
- **"KilledBy arrives after KilledAt."** Seen once in testing. The check now runs a frame later.

## Studio test (2026-11-16, bots match, Raptor, PC)
- **Countdown and start:** tick 3, go 1.
- **Hits and kills:** 5 hit stamps, two of them 0.01 s apart → hit 4. An enemy-bot kill credited to me → kill 1. A kill by a bot → no sound.
- **Point:** over a live match captured / lost / contested fired as HpOcc changed. Moving fired once per point.
- **Match end:** the match ended with B winning while I was on A → lose 1.
- **Click:** a main-menu click → click 1.
- **Not yet heard:** the sounds are silent until their ids are set after the upload.

## Upload (GameSounds 1.1)
- **How:** Kepu was away from the PC ("You upload it"). An Open Cloud upload needs the folder approved in Studio Assistant settings, so the 11 files were imported through Studio's Asset Manager instead (Import, fee 0, rights confirmed: original sounds made for this game).
- **Ids:** they are now the defaults in GameSounds 1.1.
- **Test:** in Studio all 11 loaded with the right lengths, and tick and GO played in a bots match.
- **Also found:** the 4 Kevin MacLeod songs (MDA_LevelUp, MDA_AirshipSerenity, MDA_BitQuest, MDA_8bitDungeonLevel) are already uploaded to the same account (since 2026-11-02).
