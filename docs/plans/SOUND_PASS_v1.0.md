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

## Round 2: getting hit and death (GameSounds 1.2)
- **Picks:** from the Sound Pick Board round 2 (docs/mockups/sound_pick_board_v0.2.html), 15:27: "hurt C, died C".
  - hurt C: crunchy punch with a metal tick, 0.30 s.
  - died C: low dying growl and thud, 1.50 s.
  - Original sounds in the punchy real style (generator docs/sfx/gen_real_sfx.py).
- **Code facts:** every damage path to a player ends at the Humanoid (ArenaPvP bridges DummyHealth to Humanoid:TakeDamage; RespawnServer already treats a Humanoid health drop as "hit"). Death is Humanoid.Died.
- **Rules:**
  - hurt: your Humanoid health drops to above 0 and below MaxHealth. Not within 1 s of spawning (a MaxHealth set on spawn also lowers Health). At most once per 0.15 s.
  - died: your Humanoid.Died, once per character. A killing blow plays died only.
- **Upload:** Asset Manager Import (fee 0): hurt 75565630737484, died 97374555569398.
- **Studio test (bots match, Raptor 60/60):** 4 hits through the bridge, two of them 0.05 s apart → hurt 3. Killing blow → died 1, no hurt. Respawn back to 60/60 → no hurt.

## Round 3: the Raptor's ability sounds (GameSounds 1.3)
- **Which dino:** Kepu said "Next" to "tell me which dino you want first", so the Raptor went first (the default dino for every new player).
- **Picks:** from the Sound Pick Board round 3 (docs/mockups/sound_pick_board_v0.3.html), 15:50: "cloak C, shield B, adren A, cannon A, scent A".
  - Cloak Field C: quick stealth whoosh. Energy Shield B: wobbling energy bubble. Adrenaline A: injector hiss and fast heartbeat.
  - Shock Cannon A: charge zap and boom. Scent Sense A: two sniffs and a soft chime.
  - Generator docs/sfx/gen_raptor_sfx.py.
- **Who hears:** "Nearby, Scent only you".
- **Code facts:** each part's server stamps a start on the character, last: CloakStartedAt, EnergyShieldStartedAt, AdrenalineStartedAt, ScreechStartedAt (Shock Cannon), ScentStartedAt. Nothing played a sound for them.
- **Rules:**
  - cloak / shield / adren / cannon: when any dino's start stamp changes, each client plays a 3D copy at that dino's root (heard within 200 studs, full volume within 10).
  - scent: your own ScentStartedAt, 2D, only you.
  - Unchanged: bite, pounce, roar, the Thrusters boost and the Shock Mine keep their own sounds. No server script changed.
- **Upload:** Asset Manager Import (fee 0).
- **Studio test (bots match, Raptor, max-all test mode):** the 4 buttons through their real remotes → 1 sound each, a 3D copy in the root. Scent → 1, 2D. A bot's shield stamp → the shield sound at that bot.

## Round 4: the Dilophosaurus' ability sounds (GameSounds 1.4)
- **Which dino:** Kepu said "next"; the Dilophosaurus went next (the most silent buttons: 7 of 8). The T-Rex has no live buttons.
- **Picks:** from the Sound Pick Board round 4 (docs/mockups/sound_pick_board_v0.4.html), 16:02: "gatling B, mortar B, spine B, over A, hiss B, pump A, scope C". Generator docs/sfx/gen_dilo_sfx.py.
- **Who hears:** like the Raptor's ("Nearby"): 3D at the dilo.
- **Triggers (DiloMovesServer stamps, set at the moment of the action):**
  - Venom Gatling: DiloGatlingAt (the press; the 1.5 s sound covers the 0.4 s spin-up and the 1 s burst).
  - Toxin Mortar: DiloMortarFireAt (the canister leaves).
  - Spine Burst: DiloSpineBurstAt (the spines leave).
  - Venom Overdrive: DiloOverdriveAt (the press; the sound covers the 0.7 s charge).
  - Sonic Hiss: DiloHissBlastAt. Antivenom Pump: DiloPumpJoltAt. Sniper Scope: DiloScopeShotAt.
- **Unchanged:** Spring Jets keeps its thruster sound (DiloMovesFX). The dilo's bite and spit stay silent (a later round). No server script changed.
- **Studio test (bots match, Dilo, max-all):** all 7 parts through their real remotes, result "ok" → 1 sound each, a 3D copy in the root.

## Round 5: the Herrera's ability sounds (GameSounds 1.5)
- **Which dino:** Kepu said "next"; the Herrera went next (9 silent rows).
- **Picks:** from the Sound Pick Board round 5 (docs/mockups/sound_pick_board_v0.5.html), 16:27: "quills A, smoke A, strobe A, breaker A, caltrops A, goo B, glider B, cmlaunch A, cmboom A". Generator docs/sfx/gen_herrera_sfx.py.
- **Who hears:** "Nearby", 3D at the Herrera.
- **Triggers (HerreraMovesServer / HerreraMissileServer stamps):**
  - Quill Launcher QuillStartedAt; Smoke Pods SmokeStartedAt; Strobe Frill StrobeAt (the flash); Stun Breaker BreakerAt; Razor Caltrops CaltropDroppedAt; Goo Blob Shooter GooFiredAt; Glider Wings GlideStartedAt (the wings open); Cruise Missile CruiseLaunchAt.
  - Cruise Missile blast: CruiseBoomAt, played at CruiseBoomPos (the blast point, far from the Herrera), heard within 400 studs.
- **Unchanged:** the Herrera's Adrenaline Injector already plays the Raptor's Adrenaline sound (it runs on AdrenalineServer). No server script changed.
- **Studio test (bots match, Herrera, max-all):** quills, smoke, strobe, caltrops, goo, glide, missile launch and impact through their real remotes → 1 sound each. Stun Breaker: a stun set for the test was cleared at once ("notStunned"), so BreakerAt was stamped from the server → 1 sound. Bots' glides and shields also played their sounds.

## Round 6: the Troodon's ability sounds (GameSounds 1.6)
- **Which dino:** Kepu said "next"; the Troodon went next (9 silent buttons).
- **Picks:** from the Sound Pick Board round 6 (docs/mockups/sound_pick_board_v0.6.html), 16:43: "oburst B, odome B, olantern C, omender B, oportal C, osapwall A, osentry B, oshed B, osleep B". A lighter tech-meets-nature style for the support dino. Generator docs/sfx/gen_troodon_sfx.py.
- **Who hears:** "Nearby", 3D at the Troodon, at the press (for thrown parts, the throw).
- **Triggers:** TrooBurstAt, TrooDomeAt, TrooLanternAt, TrooMenderAt, TrooSapAt, TrooSentryAt, TrooShedAt, TrooSleepFireAt (not TrooSleepAt: the sleeping target gets that one too).
  - Portal Feathers: code fact found while wiring it: since TrooMovesServer 1.10 the part is the Apex-style rift (press, walk, press), so the sound plays on TrooRiftOpenAt (the rift opens at end B, where the Troodon stands). The old two-ring mode (TrooPortalAt, switch off by default) stays silent. The Lab text still describes the rings.
- **Studio test (bots match, Troodon, max-all):** burst, dome, lantern, mender, sap wall, sentry, sleep dart and the rift (press, walk 14 studs, press) through their real remotes → each played. Feather Shed by a server TrooShedAt stamp → 1. Troodon bots' rifts, sentries and domes also played at the bots.

## Change of source: real recordings (GameSounds 1.7 on)
- **Kepu 17:05**, on the synthesized Pachy options: "These are starting to fucking feel lazy. Don't even have any correlation to the fucking ability and what it should sound like these are just 8bit sounds." Pick: "Real sounds, redo all": Pachy, Teno, Therizino, then redo the live Raptor, Dilophosaurus, Herrera and Troodon sounds.
- **Sources tried:** Openverse (refused by the session's network; Kepu's page did not load). Roblox Creator Store search: mostly sounds ripped from other games, except that a "<family> (SFX)" query returns Roblox's licensed **Pro Sound Effects** library (free to use in Roblox). Chosen 17:14: "1. Let's do that".
- **Audition:** the pick page links each option to its Creator Store page (plays on the phone). The ids are used directly, so nothing is uploaded.
- **Limits:** I cannot hear library audio myself; picks come from the library's own descriptions. Files with several takes would be cut to one with Sound.PlaybackRegion. Fallback if the library falls short: the Sonniss GDC bundle in Kepu's Music folder.

## Round 7: the Pachy (GameSounds 1.7)
- **Picks (17:19):** "hookarm A, ink A, medstation C, servodash C, tether B, visor C, bloodrush A" (page docs/mockups/sound_pick_board_v0.7b.html). The rejected synthesized round is docs/mockups/sound_pick_board_v0.7.html.
- **Triggers:** HookStartedAt (the claw fires; the head smash keeps HookFX's sound), InkStartedAt, MedDroppedAt, ServoDashStartedAt, TetherStartedAt, VisorStartedAt, HeadbuttSacrificeAt (Blood Rush). Mecha Legs has no press.
- **Studio test:** six parts through their real remotes played; Blood Rush by a server stamp (test headbutt presses returned "timeout").

## Round 8, redone: the Teno from the Sonniss GDC 2026 bundle (2026-11-16 20:13, Kepu "Okay let's move forward then with the sounds")
- **Why:** the library round 8 (picked blind from descriptions) was "straight ass" (17:32). The Sonniss GDC 2026 bundle (5 zips, ~6.9 GB, ~480 real recordings) finished downloading into Kepu's Downloads; Claude reads it through the shell on Kepu's PC.
- **How:** 46 candidate recordings extracted and converted to mono 48 kHz FLAC (Music\MechaDinoArena_SFX\_work_teno_sonniss). Each option = one take trimmed, varispeed pitch, EQ, layered with offsets; then subsonic cut, bass held to at most 6 dB over the >= 200 Hz band, level-matched on that band (-18 dB, what a phone speaker plays), soft-limited at -1 dBFS. Checked by spectrograms (no clicks, gaps or wrong takes) and a phone-band loudness table (all options -18..-24 dB). Recipe: docs/sfx/gen_teno_sonniss_sfx.py (run against the FLAC folder).
- **Licence:** the Sonniss GDC bundle is royalty-free for use in games, but the raw sounds may not be redistributed, so neither the renders nor the pick page's embedded audio are committed to this public repo; the WAVs go to Kepu's Music folder for the Roblox upload.
- **Rows (3 options each):** tbellow (TenoBellowAt), tchallenge (TenoChallengeAt), tgrab (TenoGrabStartedAt), tgrabland (TenoGrabLandAt at TenoGrabLand, new), tleap (TenoLeapStartedAt), tleapland (TenoLeapLandedAt, new), tmortar (TenoMortarFiredAt), tmortarboom (TenoMortarLandedAt at TenoMortarLand, new), tmud (TenoMudStartedAt), tstomp (TenoStompAt). No Teno sound plays today; no server change needed.
- **Pick page:** the Sound Pick Board artifact (same link), version 10. Waiting for Kepu's picks.
- **Picks (20:23):** "tbellow C, tchallenge B, tgrab C, tgrabland A, tleap B, tleapland C, tmortar B, tmortarboom C, tmud A, tstomp B". Uploaded through Asset Manager (two imports of five: the file box takes ~260 characters); ids in GameSounds 1.8 (docs/VERSIONS.md).
- **Studio test:** mortar (throw + boom at the impact), stomp and mud through their real remotes played once each; a Teno bot's bellow, mortar and stomp played at the bot. Tail grab had no grabbable enemy in the test match (enemies Dilo, Dilo, Therizino), so grab, grab landing, leap, leap landing and challenge were checked by server stamps (the Blood Rush method): each played once, the grab landing at TenoGrabLand. Leap / Bellow / Challenge aren't on a player's buttons yet (SkillTree TENO_PARTS_SUPPORT_SOON; leap not given by max-all here), but bots use them.

## Round 9: the Therizino from the Sonniss bundle (2026-11-16 20:54, Kepu "Next")
- **Code facts (TheriMovesServer 1.14, every rework switch on by default):** Reaper Reel TheriReelAt (the press) + TheriReelHitAt (the slash on the pulled dino); Wing Volley TheriFeatherAt (the press; darts leave at +0.42 s, TheriVolleyFiredAt); Reaper Vortex TheriVortexAt; Bola TheriBolaAt (the press; thrown at +0.6 s) + TheriBolaHitAt (the catch; TheriBolaEnd = the target's spot); Dash TheriDashAt; Deflector Claws TheriDeflectAt. Overclock Joints is a passive (no button; its TheriClockAt fires when the passive turns on), so no sound. No Therizino ability sound plays today.
- **Rows (3 options each):** zreel, zreelhit, zvolley, zvortex, zbola, zbolahit (at TheriBolaEnd), zdash, zdeflect. 36 more sources extracted (Music\MechaDinoArena_SFX\_work_theri_sonniss) plus the round 8 ones; recipe docs/sfx/gen_theri_sonniss_sfx.py (same engine and levelling as round 8). Spectrogram check fixed two: Reel Slash B started 0.5 s before its cut (now starts at the cut); Bola C's "spin" source was a synthetic vibrato tone (rebuilt from rope / carabiner whirls).
- **Pick page:** the Sound Pick Board artifact, version 11. Waiting for Kepu's picks.

## Round 9 v2 — Therizino rebuilt against the animation (2026-11-16)
Kepu: "These sound options don't even line up with the damn animation timing" / "You did the same shit for all the other
dinos too". Round 8 (Teno, live v857) and round 9 v1 were timed off the server stamps only, never against the poses.
- Beat sheet first (TheriPose 1.11, TheriMovesFX2 1.2, storyboard v0.5). Sounds are split into parts at those beats:
  Hook fire 0.30 / winch 0.52–1.00 / slash 1.00; Vortex start 0 / loop 0.95–Until / end; Bola throw 0 / hit 1.05;
  Dash one clip (jolt 0.16, land 0.29, skid 0.42); Volley 0 / hit per target 0.97; Deflect up 0 / loop 0.15–Until /
  block per BlockAt / down.
- Recipe docs/sfx/gen_theri_v2_sfx.py; pick page tools/mockup/build_theri_sound_pick.py v0.1 (storyboard + sound panel,
  the animation clock follows the audio clock). Published to the Sound Pick Board (version 12).
- After picks: GameSounds v1.9 schedules sub-parts from the stamps (TheriReelBrace/Fly/Time, TheriVortexStart/
  TheriFieldUntil, TheriBolaEnd, TheriVolleyLanded, TheriDeflectUntil/BlockAt), then a Studio timing test.
- Then the same process per dino: Teno (re-time live v857), Pachy, Raptor, Dilo, Herrera, Troodon.
