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

## Round 10 — Teno rebuilt against the animation (2026-11-16)
- Beat sheet docs/sfx/TENO_BEATS_v1.0.md. Parts per move (schedule point): grab wind (press) / snap (catch − 0.15) /
  throw (throw − 0.15) / land (landing, at TenoGrabLand); mortar brace (press) / fire (TenoMortarFiredAt) / boom (landing);
  stomp rear (press) / smash (TenoStompAt); bellow inhale (press) / shriek (press + 0.40); challenge call (press, alarm 0.65);
  leap launch (lift-off) / land (TenoLeapLandedAt, tail slam +0.12); shield up (press) / loop (TenoMudCoatAt..TenoMudEndedAt) /
  block (TenoMudBlockAt) / down (TenoMudEndedAt). Option A of each is built on the round 8 pick where one fits; the
  Shield gets energy-shield sounds (round 8's tmud were mud sounds from before the move became Shield Armor).
- Recipe docs/sfx/gen_teno_v2_sfx.py; page tools/mockup/build_teno_sound_pick.py v0.1 (the storyboard is time-warped to
  the game: Mortar fire 0.35 + ~0.25 s flight, Leap lift-off 0.12, Grab flight 0.6, Shield disc 0.20). Sound Pick Board
  version 14.
- Found while reading for the beat sheet: GameSounds 1.8's tleap listens to TenoLeapStartedAt, which TenoMovesServer only
  stamps on the old button path; the JUMP leap (TenoLeapOnJump) never stamps it, so the live launch sound likely never
  plays. The round 10 wiring anchors the launch to the JUMP leap's own start (to verify in Studio before the build).

## Round 11 — Pachy rebuilt against the animation (2026-11-17)
- Beat sheet docs/sfx/PACHY_BEATS_v1.0.md (7 moves: Hook, Servo Dash, Dome Visor, Ink Shooter, Tether Spike, Blood Rush,
  Med-Station; Headbutt / Leap keep their sounds, Last Stand / Head Down are passives).
- Recipe docs/sfx/gen_pachy_v2_sfx.py; page tools/mockup/build_pachy_sound_pick.py v0.1 (the Pachy storyboard is
  event-driven, so it is stepped to the audio clock with hit-stops skipped). Sound Pick Board version 16.

## Round 11 — the Pachy page plays the game's own animation (2026-11-17)
- Kepu 11:33 "the mockup you sent still shows a skid to a stop", 11:36 "How about you actually use the fucking animation from
  the game": the storyboard is replaced on this page by recordings of the live game. Every Pachy move with a sound (Headbutt,
  Leap + double jump, Grappling Hook, Servo Dash, Dome Visor, Ink Shooter, Tether Spike, Blood Rush, Med-Station) was played
  in Studio (Play, practice match, real key presses or the remotes MechaButtons sends) and recorded with
  tools/studio/move_recorder.luau v1.0: the Pachy, the target bot and the effects, 30 times a second, plus every attribute
  stamp. Packed by tools/mockup/rec_pack.py v1.0 into tools/mockup/pachy_rec/<move>.json; played by
  tools/mockup/pachy_rec_player.js v1.0; page tools/mockup/build_pachy_rec_pick.py v1.0. Sound Pick Board version 22.
- The sound parts sit on the beats stamped in the same recording (clip time, press at 0.30 s): Headbutt hit 0.51; Leap jump
  0.434 (JumpStartedAt + 0.12) and 0.714 (JumpDoubleAt); Hook fire 0.315 (launch - 0.15), reel 0.523-1.023, smash 1.023;
  Servo Dash blast 0.31, burn 0.62-1.87, steam 1.87 (the game: dust + steam, no skid); Visor up 0.329, field 0.429-2.329,
  down 2.329 (no block: nothing hit it); Ink fire 0.33, splat 0.542; Tether cock 0.30, throw 0.848, land 1.382 (the bot is
  chained); Blood Rush pact 0.325; Med drop 0.329, hum 0.929-10.632, fold 10.632 (its full time).
- Test setup only (nothing saved): skill saving off for the session, loadout slots swapped to record Ink / Tether / Visor /
  Med and put back (hookarm, servodash, mechalegs, bloodrush), PracticeServer disabled so the target bot stayed passive,
  the bot held at its standing height until the press. Visor and Blood Rush have no bot (it was a bystander).
- The storyboard page (build_pachy_sound_pick.py, last v0.7: the skid removed from Servo Dash A) is kept, not used.


## Round 12 — Hardpoint voice callouts (2026-11-17)
- Kepu 12:42 "I don't like the point sounds switching over and all that, it sounds stupid and does call of duty even do that?".
  GameSounds 1.0 plays captured / lost / contested on every HpOcc change (only a 1 s gap per same sound), so a fight on the
  point fires them over and over. Kepu picked "Voice callouts" (an announcer, not too often) and "Keep them" (the moving
  warning, the 3-2-1 ticks and the go stay).
- Lines match the HUD's status words: "Hardpoint secured." / "Enemy has the hardpoint." / "Hardpoint contested.". Three voices
  (A Field radio, B Commander, C Mech AI), synthesized with Kokoro-82M (Apache-2.0), recipe docs/sfx/gen_point_vo.sh; page
  tools/mockup/build_point_voice_pick.py v1.0. Sound Pick Board version 23.
- Planned rules (shown on the page): speak only once the new state has held about 1 s, a few seconds between callouts, never
  the same line twice in a row; 2D, only you. Built after Kepu picks a voice.
- 12:53 "Point voice A" -> GameSounds 1.16 (VERSIONS.md). Not published yet.

## Round 13 — the match intro voice line (2026-11-17)
- Kepu 12:58 "how about a voice playing in the background for the brief intro to like get to the Hardpoint. Use your mecha
  upgrades to your advantage. Some type of dialogue like that". The intro is the 10 s pre-match countdown (PrematchCam 1.0:
  pan out at 9 s left, orbit 7-5, back 5-3; GameSounds ticks 3-2-1, go at 0). Five lines in voice A (4.3-4.8 s), each starting
  with the pan at 9 s left and ending before the first tick; pick one or several (several: a different one each match).
- Recipe docs/sfx/gen_point_vo.sh v1.1; page tools/mockup/build_intro_voice_pick.py v1.0. Sound Pick Board version 24.
- 13:02 picks lines 1 and 2 -> GameSounds 1.17 (VERSIONS.md). Not published yet.

## Round 14 — post-game title voice lines (2026-11-17)
- Kepu 13:05 "How about some voice lines during the post game titles for the winning team. Couple for each title to make them
  really pop out". The titles are VictoryTitles 1.1 (HpTitles from the server; each title shows for its len, about 5.5 s, the
  lower third slams in at 0.3 s). Planned: the announcer says the title as it slams in, 2D.
- Three lines per title (24) in voice A, two treatments: R radio (the point-callout voice) and S stadium (clean, big echo);
  1.7-4.1 s, so each fits inside its title. Keep two or more per title and a show picks one at random.
- Recipe docs/sfx/gen_point_vo.sh v1.2; page tools/mockup/build_title_voice_pick.py v1.0. Sound Pick Board version 25.
- 13:11 "Not like that, look at how call of duty speaks during these types of screens. It's like a commander talking to
  you. This is just a narrator." -> round 14b.

## Round 14b — the title lines as a commander (2026-11-17)
- Rewritten: a commander on the radio talking to the squad about the player who earned the title (praise for the five good
  titles, a dressing-down for the three roasts), e.g. "Command here. Our apex predator owned that field. Outstanding." /
  "Extinct. Respawns aren't free, soldier. Lucky we won." Three per title. Third person ("they", "our medic") because every
  player on the winning team hears each title, not only the one who earned it.
- Two voices through the radio filter: A am_michael 0.97 (the point-callout voice), B bm_george 0.95 (British). 2.7-4.6 s,
  so each ends inside its title (slam-in at 0.3 s, about 5.5 s shown).
- Recipe docs/sfx/gen_point_vo.sh v1.3; page tools/mockup/build_title_voice_pick.py v1.1. Sound Pick Board version 26.
- 13:16 Kepu asked how the screen should sound ("Make a decision based on how other games handle those screens"):
  four layers, each behind a switch: the win / lose sting + a commander result line, results music (victory / defeat) in
  place of the island music, the title lines (winning team only) with the music ducked under them, nothing that makes the
  show longer (a skip cuts the line). 13:18 "Send me a mock up of the actual presentation" -> round 14c.

## Round 14c — the presentation mockup (2026-11-17)
- The real show, recorded in Studio (tools/studio/show_recorder.luau 1.0): a practice match won 999-120 with test stats
  (titles APEX PREDATOR Kepz, BUTTON MASHER Wrench, EXTINCT Yuki, CARRIED Fang); every part above 2000 studs (the stage,
  the clones, their effects), the camera and every visible on-screen element, 30 times a second. A second run with
  VictoryTitles off recorded the scoreboard.
- Found while recording: in Studio (window not focused, about 15 frames a second) the titles run at about 75% speed,
  because VictoryTitles caps each step at 0.05 s; the four titles took 7.0 / 7.5 / 8.1 / 8.5 s instead of 5.4-6.4 and ran
  over the scoreboard's 7 s. Players at a normal frame rate are not affected; under 20 frames a second they would be. The
  page stretches each recorded title back to its real length.
- Page tools/mockup/build_results_show_mock.py 1.0 (Results Show Mockup artifact): Today vs Proposed; switches for the
  result line, the victory music (placeholder, tools/mockup/gen_results_music.py 1.0), the title lines and the ducking;
  commander A / B; line picks; the losing side's audio on its own. Result lines in gen_point_vo.sh v1.4.
- 15:05 "Nah these are ass, I think it would be better to have better music and sound effects during these" -> round 15.

## Round 15 — hero / clown music and sound effects on the title show (2026-11-17)
- Kepu 15:05 "Nah these are ass, I think it would be better to have better music and sound effects during these"; 15:10
  "Clown music for the crappy title cards and hero music for the good ones" / "With the appropriate sound effects". The
  commander lines (rounds 14-14c) and the placeholder music are dropped from the proposal.
- Sound effects: 31 cues from the Sonniss GDC 2026 bundle, one on every beat of APEX PREDATOR, BUTTON MASHER, EXTINCT and
  CARRIED (the titles in the recording), a slam hit per title card (cinematic for the good ones, cartoon for the roasts),
  crowd + fireworks under the banner and the scoreboard. Cue sheet docs/sfx/TITLES_SFX_v1.0.md, renders
  docs/sfx/gen_titles_sfx.py v1.0 (trims from loudness every 0.1 s, checked by spectrogram).
- Music: Roblox's licensed APM library (free in Roblox games; plays only inside Roblox). 8 hero and 8 clown candidates
  (all load in Studio; lengths 4.9-14.5 s) listed with Creator Store links on the Results Show Mockup v1.1 for Kepu to
  listen to and keep.
- Waiting on Kepu's music picks and his word on the sound effects; then the other four titles get cued and it all goes in
  the game behind switches.

## Round 16 — the title music and sound effects in the game (2026-11-17)

Kepu 16:48 kept all 16 music tracks (hero: All Action Hero (f), Day Of The Election Sting 2, Global Success StingA, Herald of
Freedom (Sting 1), Forging The Army StingA, Wings of Destiny (Sting 2), The Ultimate Challenge StingA, Triumph; clown: Clown
Parade Sting 1 and 2, Circus And Clowns Link, Clown Parade Link, Circus And Clowns Sting 2, Round Up Round Up Link 2, Cheerful
Tuba, Funny Cut D3).
- New: VictoryTitlesAudio 1.0 (ModuleScript), VictoryTitles 1.3, VictoryTitlesAnim 1.3 (`runner.time()`). Each title starts a
  random track from its list and the card hit; the beats play on the title's own clock; the music fades at the next title,
  a skip or the end; the crowd cheers at the results start and when the show ends. A switch per part (attributes in
  docs/ATTRIBUTES.md).
- gen_titles_sfx.py 1.1: cues for KING OF THE HILL, UNKILLABLE, MEDIC and PACIFIST (14 more Sonniss sources) and the game's
  card hits; cue sheet docs/sfx/TITLES_SFX_v1.1.md. 47 cues rendered, copied to Kepu's Music\MechaDinoArena_SFX\titles_vt.
- Studio Play test (VictoryTitlesTest "apex,carried"): apex played hero track 9042409054, carried clown track 9042030749, the
  first faded as the second started, the last faded when the show ended; no errors.
- Waiting: the 47 sound effects need uploading (Open Cloud refused the folder: not an approved upload folder in Studio's
  Assistant Settings -> MCP Permissions). Until their ids are filled in, the sound effects are silent and the music plays.
- 17:52 Kepu "You do it": the 47 cues imported through Asset Manager, ids checked with GetProductInfo and filled in
  (VictoryTitlesAudio 1.1). Studio Play test of all 8 titles: every beat plays on its animation time, the music changes per
  title, the board cheer plays at the end; no errors.

## Round 17 — the Raptor on the game's own animation (2026-11-17)
- Kepu 18:40 "1. Okay let's do this now": the Raptor, Dilo, Herrera and Troodon get the Pachy's record-the-game pick page,
  one dino at a time; the Raptor first (the default dino).
- Recorded in Studio (Play, sandbox island, out of the menu, real key presses: T cloak, V shield, R adrenaline, C held 0.8 s
  for the Shock Cannon, T scent) with tools/studio/move_recorder.luau v1.1 (export2 / get written down; packed tracks; a
  part's transparency now includes LocalTransparencyModifier, which is all the cloak changes on your own client; Highlights
  recorded, which is how the Energy Shield shell is drawn; a long aim laser is kept). Packed by rec_pack.py 1.1 into
  tools/mockup/raptor_rec; played by pachy_rec_player.js 1.1 (draws a recorded Highlight as a tint).
- Test setup only (nothing saved): SkillSaveEnabled off for the session, slot 3 / 4 swapped to Scent / Energy Shield and put
  back (adrenaline, screech, cloak, thrusters); a passive Pachy target spawned with PracticeBots 30 studs ahead, anchored,
  ArenaPvPTestTarget so PlaceGate (hub) keeps it, in DinoIsland.Bots; ScreechServerSquadEnabled off for the session (with no
  team the squad check skipped the bot). Species back to Therizino.
- Beats (clip time, press at 0.30 s): Cloak on 0.33, off 8.57 (standing still kept it on 8.2 s); Shield up 0.33, hum
  0.43-3.10, down 3.10; Adrenaline inject 0.33, rush 0.63-3.33, end 3.33; Shock Cannon charge 0.30-1.20 (the aim laser),
  fire 1.20, hit 1.33 (the bot 30 studs ahead, stunned); Scent sniff 0.33, aura 0.93-6.33, end 6.33.
- Sounds: docs/sfx/gen_raptor_v2_sfx.py (Sonniss; 16 more sources extracted from the bundle into Kepu's
  _work_titles_sonniss/mono_flac3), three options per move: Cloak A light bend / B electro camo / C ghost fade; Shield A
  hard-light shell / B force bubble / C wobble dome (each with a block part); Adrenaline A injector + heartbeat / B pressure
  shot / C raptor rush; Shock Cannon A tesla / B plasma ball / C shock whip; Scent A snort + chime / B deep breath / C tracker.
- Page: tools/mockup/build_raptor_rec_pick.py v1.0, Sound Pick Board version 27. Checked headless: every move loads, the
  three options play on the beats, picks save; no errors.
- Waiting: Kepu's picks. Then upload, GameSounds on the beats, Studio test.

