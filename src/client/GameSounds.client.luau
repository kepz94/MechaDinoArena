-- GameSounds v1.0 (Mecha Dino Arena) — the arcade layer of core game sounds, played only for you (LocalScript,
-- StarterPlayerScripts). MDA-552, plan docs/plans/SOUND_PASS_v1.0.md; Kepu 2026-11-16 14:38 "okay lets do the sound pass",
-- picks "Mixed", "Core first, then dinos", "Sound board in Studio"; 14:50 picks from the Sound Pick Board page
-- (docs/mockups/sound_pick_board_v0.1.html): "hit A, kill A, captured C, lost A, contested A, moving C, tick C, go B, click B,
-- win A, lose A". The 11 sounds are original 8-bit sounds made for this game (files docs/sfx/MDA_SFX_<event>.wav).
-- Every sound is 2D (SoundService:PlayLocalSound of a template Sound in the SoundGroup "GameSFX"), so it does not fade with
-- distance, and only you hear it. Nothing on the server changes; everything is read from state the game already replicates.
-- Events (each one: script attribute GameSounds_<event>Enabled (default true), GameSoundsId_<event> (the asset id; "" = silent),
-- GameSoundsVol_<event>):
--   * hit       your character's LastDealtAt changes (TrooStatsServer stamps the attacker on every LastHitAt / TrooHitAt /
--               KilledAt it causes); at most once per GameSoundsHitGap (0.07) s.
--   * kill      any dino's KilledAt changes (players' characters, DinoIsland.Bots) with KilledBy == your name or KilledByUserId ==
--               your UserId (read one frame after KilledAt changes); at most once per model per KilledAt value.
--   * captured / lost / contested
--               ReplicatedStorage.Hardpoint HpOcc changes while HpPhase is "live" and you have a HardpointTeam: your team letter =
--               captured, the other letter = lost, "C" = contested, "N" = nothing; the same sound not again within
--               GameSoundsOccGap (1) s.
--               v1.16: while GameSoundsPointVoiceEnabled (default true) these three do not play; an announcer says it instead:
--   * vosecured / volost / vocontested
--               (v1.16, the Hardpoint voice callouts, round 12 voice A "Field radio": "Hardpoint secured." / "Enemy has the
--               hardpoint." / "Hardpoint contested.") 2D, only you, from the same HpOcc changes (your team / the other team / "C";
--               "N" says nothing), but only once the new HpOcc has held GameSoundsVoiceSettle (1) s with HpPhase "live" (a newer
--               change cancels it), at least GameSoundsVoiceGap (4) s after the last callout (a settled change waits out the gap
--               and is said only if it still holds), and never the same line twice in a row (the point moving to a new spot,
--               HpIndex, clears that). false = 1.15 (the three sounds on every change).
--   * vointro1 / vointro2
--               (v1.17, the match intro line, round 13 lines 1 + 2 in voice A: "Hardpoint's up. Get there first, and use your
--               mecha upgrades to your advantage." / "All units, move to the hardpoint. Your mecha upgrades are your edge. Use
--               them.") 2D, only you, once per warm-up (per HpPointEndsAt) when the seconds left (HpPointEndsAt - server time)
--               drop to GameSoundsIntroAt (9: the PrematchCam fly-over starts there; the 4.7 / 4.8 s line ends before the first
--               tick at 3). Joined later than GameSoundsIntroLate (0.5) s past that: no line this warm-up. The line is one of
--               GameSoundsIntroLines ("vointro1,vointro2"), at random but not the one before. Switch GameSoundsIntroEnabled
--               (default true).
--   * moving    while HpPhase "live": once per point (HpIndex) when HpPointEndsAt - server time drops to GameSoundsMoveWarn (5) s.
--   * tick      while HpPhase "warmup": when the whole seconds left (ceil(HpPointEndsAt - server time)) become 3, 2 or 1
--               (from GameSoundsTickFrom, 3).
--   * go        HpPhase changes from "warmup" to "live".
--   * win / lose HpPhase changes to "results": HpWinner == your team -> win, the other team -> lose; "draw" -> nothing.
--   * click     a GuiButton's Activated inside one of the ScreenGuis named in GameSoundsClickGuis (menus, Lab, pre-game, island and
--               respawn screens; not the ability / attack buttons).
--   * hurt      (v1.2) your character's Humanoid health drops (every damage path ends there: ArenaPvP bridges DummyHealth to
--               Humanoid:TakeDamage) to a value above 0 and below MaxHealth; not within GameSoundsHurtSpawnIgnore (1) s of the
--               character spawning (a MaxHealth set on spawn also lowers Health); at most once per GameSoundsHurtGap (0.15) s.
--   * died      (v1.2) your character's Humanoid.Died; once per character.
--   * cloak / shield / adren / cannon
--               (v1.3, the Raptor's buttons) any dino's (players' characters, DinoIsland.Bots) CloakStartedAt /
--               EnergyShieldStartedAt / AdrenalineStartedAt / ScreechStartedAt (Shock Cannon) changes to a number: a 3D copy of
--               the sound at that dino's HumanoidRootPart (else PrimaryPart), heard by everyone near it (each client plays its
--               own copy; RollOffMaxDistance GameSoundsAbilityRange (200), RollOffMinDistance GameSoundsAbilityNear (10)).
--   * scent     (v1.3) your character's ScentStartedAt changes to a number: 2D, only you (only you see the trails).
--   * dgatling / dmortar / dspine / dover / dhiss / dpump / dscope
--               (v1.4, the Dilophosaurus' buttons) like cloak: 3D at the dino, heard by everyone near it, on DiloGatlingAt (the
--               press; the sound covers the spin-up and the burst) / DiloMortarFireAt (the canister leaves) / DiloSpineBurstAt
--               (the spines leave) / DiloOverdriveAt (the press; the sound covers the 0.7 s charge) / DiloHissBlastAt (the blast)
--               / DiloPumpJoltAt (the jolt) / DiloScopeShotAt (the shot).
--   * hquills / hsmoke / hstrobe / hbreaker / hcaltrops / hgoo / hglider / hcmlaunch
--               (v1.5, the Herrera's buttons) like cloak: 3D at the dino, on QuillStartedAt (the volley) / SmokeStartedAt (the
--               cloud) / StrobeAt (the flash) / BreakerAt (breaking free) / CaltropDroppedAt / GooFiredAt / GlideStartedAt (the
--               wings open) / CruiseLaunchAt (the missile leaves).
--   * hcmboom   (v1.5) any dino's CruiseBoomAt changes to a number: 3D at its CruiseBoomPos (the blast point, not the dino),
--               heard within GameSoundsBlastRange (400) studs, full volume within GameSoundsBlastNear (20).
--   * oburst / odome / olantern / omender / oportal / osapwall / osentry / oshed / osleep
--               (v1.6, the Troodon's buttons) like cloak: 3D at the dino, on TrooBurstAt / TrooDomeAt / TrooLanternAt /
--               TrooMenderAt / TrooRiftOpenAt (Portal Feathers is the Apex-style rift since TrooMovesServer 1.10: the rift opens
--               at end B) / TrooSapAt / TrooSentryAt (the throws and the drone) / TrooShedAt (breaking free) / TrooSleepFireAt (the
--               dart; not TrooSleepAt, which the sleeping target also gets).
--   * phook / pink / pmed / pdash / ptether / pvisor / pblood
--               (v1.7, the Pachy's buttons) like cloak: 3D at the dino, on HookStartedAt (the claw fires; the head smash keeps
--               HookFX's sound) / InkStartedAt (the press) / MedDroppedAt / ServoDashStartedAt / TetherStartedAt / VisorStartedAt /
--               HeadbuttSacrificeAt (Blood Rush pays health for a headbutt).
--   * tbellow / tchallenge / tgrab / tleap / tleapland / tmortar / tmud / tstomp
--               (v1.8, the Tenontosaurus' buttons) like cloak: 3D at the dino, on TenoBellowAt / TenoChallengeAt /
--               TenoGrabStartedAt (the press; the sound covers the swing, the catch and the fling) / TenoLeapStartedAt (the launch) /
--               TenoLeapLandedAt (the landing) / TenoMortarFiredAt (the boulder leaves) / TenoMudStartedAt / TenoStompAt (the hit).
--   * tgrabland (v1.8) any dino's TenoGrabLandAt changes to a number: 3D at its TenoGrabLand (where the flung dino lands),
--               heard within GameSoundsAbilityRange (200) studs, full volume within GameSoundsAbilityNear (10).
--   * tmortarboom (v1.8) any dino's TenoMortarLandedAt changes to a number: 3D at its TenoMortarLand (the impact), heard like
--               hcmboom (GameSoundsBlastRange 400 / GameSoundsBlastNear 20).
--   * zhookfire / zhookwinch / zhookslash / zvortexstart / zvortexloop / zvortexend / zbolathrow / zbolahit / zdash / zvolley /
--     zvolleyhit / zwallup / zwallloop / zwallblock / zwalldown
--               (v1.9, the Therizino's buttons; sound pass round 9 v2, each move split into parts on its animation beats) 3D at
--               the dino like cloak, each part at a server time worked out from the move's own stamps (late parts start part-way
--               in; a one-shot later than its length is skipped):
--               Reaper's Hook (TheriReelAt t): zhookfire at t + TheriReelBrace (the claw flies); on TheriReelResult "hit" with
--                 TheriReelTime > 0, zhookwinch from t + Brace + TheriReelFly, cut (GameSoundsTheriCutFade 0.04 s) at the finish
--                 f = t + Brace + Fly + ReelTime, and zhookslash at f.
--               Reaper Vortex (TheriVortexAt t): zvortexstart at t; zvortexloop (looped) from TheriVortexStart until
--                 TheriFieldUntil (read live, so a cut-short field stops it), faded over GameSoundsTheriLoopFade (0.08) s;
--                 zvortexend at TheriFieldUntil.
--               Bola (TheriBolaAt t): zbolathrow at t; zbolahit on TheriBolaHitAt (the catch) at the caught dino
--                 (TheriSnareHitTarget), else at TheriBolaEnd.
--               Dash (TheriDashAt t, TheriDashResult "dash"): zdash at t (built to TheriDashDelay 0.16).
--               Feather volley (TheriFeatherAt t with TheriFeatherVolley true): zvolley at t (darts at TheriVolleyRelease 0.42);
--                 on TheriVolleyLandedAt, zvolleyhit at each dino named in TheriVolleyLanded ("name=blades|..."), at most
--                 GameSoundsTheriHitMax (6).
--               Shield Wall (TheriDeflectAt t): zwallup at t; zwallloop (looped) from t + GameSoundsTheriWallLoopAt (0.15) until
--                 TheriDeflectUntil (live), faded; zwalldown at TheriDeflectUntil; zwallblock on each TheriDeflectBlockAt.
--               A new cast of the same move ends the old loop (no end sound for it). Overclock Joints is a passive: no sound.
--               Switch: GameSoundsTheriBeatsEnabled (default true; false = 1.8, the Therizino silent). Diagnostics:
--               GameSoundsTheriLog (the last 24 parts: "<event>@<ms late>", ms = how late the part started vs its beat).
--   * tngrabwind / tngrabsnap / tngrabthrow / tngrabland / tnmortarbrace / tnmortarfire / tnmortarboom / tnstomprear /
--     tnstompsmash / tnbellowinhale / tnbellowshriek / tnchallenge / tnleaplaunch / tnleapland / tnshieldup / tnshieldloop /
--     tnshieldblock / tnshielddown
--               (v1.10, the Tenontosaurus' buttons; sound pass round 10, each move split into parts on its animation beats)
--               like the Therizino's 1.9 parts (3D at the dino, scheduled at server times from the stamps):
--               Tail Grab (TenoGrabStartedAt t): tngrabwind at t; tngrabsnap at TenoGrabCatchAt - GameSoundsTenoStrikeLead
--                 (0.15; the clamp is 0.15 s into the clip) and tngrabthrow at TenoGrabThrowAtPlan - the same lead (when those
--                 stamps belong to this grab, >= t); tngrabland on TenoGrabLandAt at TenoGrabLand (ability range).
--               Boulder Mortar: tnmortarbrace on TenoMortarStartedAt, tnmortarfire on TenoMortarFiredAt, tnmortarboom on
--                 TenoMortarLandedAt at TenoMortarLand (blast range).
--               Stomp: tnstomprear on TenoStompStartedAt, tnstompsmash on TenoStompAt.
--               Herd Bellow: tnbellowinhale on TenoBellowStartedAt t, tnbellowshriek at t + GameSoundsTenoShriekAt (0.40).
--               Challenge Call: tnchallenge on TenoChallengeStartedAt (the alarm is 0.65 s into the clip).
--               Hydraulic Leap: tnleaplaunch at the lift-off = JumpStartedAt + the character's JumpWindup (0.12) when it has
--                 TenoLeapOnJump and TenoLeapEnabled (the JUMP leap; 1.8's tleap listened to TenoLeapStartedAt, which only the
--                 old button path stamps), or on TenoLeapStartedAt (the button path); tnleapland on TenoLeapLandedAt, and on
--                 your own Teno on the local touchdown TenoLocalLandAt (TenoPoseFix), one per landing (stamps closer than
--                 GameSoundsTenoLandDedupe 1 s are the same landing); the tail slam is 0.12 s into the clip.
--               Shield Armor: tnshieldup on TenoMudStartedAt; tnshieldloop (looped) from TenoMudCoatAt until TenoMudUntil (live:
--                 the server moves it to the end on an early end), faded; tnshielddown at that end; tnshieldblock on each
--                 TenoMudBlockAt.
--               While GameSoundsTenoBeatsEnabled (default true) the 1.8 Teno events (tbellow, tchallenge, tgrab, tgrabland,
--                 tleap, tleapland, tmortar, tmortarboom, tmud, tstomp) do not play; false = 1.9 (the 1.8 Teno sounds).
--   * phbhit    (v1.11, the Pachy's headbutt) like cloak: 3D at the dino, on HeadbuttHitAt (the hit; HeadbuttServer stamps it on
--               the pachy that hit). HeadbuttFX's own thud (the built-in collide sound) still plays under it.
--   * pjump     (v1.12, the Pachy's jump) like cloak: 3D at the dino, at the lift-off: JumpStartedAt (JumpServer, the press) +
--               the character's JumpWindup (0.12), on models with Species "Pachy". Not on the double jump.
--               v1.13: and again on the double jump: JumpDoubleAt (JumpServer), on your own Pachy JumpDoublePredictedAt (JumpTest,
--               this client, the moment you press), one per double jump (stamps closer than GameSoundsPachyDoubleDedupe 0.5 s
--               are the same double jump); a stamp more than 0.3 s old is skipped.
--   * phookfire / phookreel
--               (v1.14, the Pachy's Grappling Hook, sound pass round 11 option C, each part on its beat) 3D at the dino,
--               scheduled from HookServer's stamps (set before HookStartedAt): phookfire at HookLaunchAt - GameSoundsPachyHookLead
--               (0.15: the shot is 0.15 s into the clip, the arm-raise before it); on HookResult "hit": phookreel from
--               HookContactAt (the clamp), cut (GameSoundsTheriCutFade 0.04) at HookSmashAt, and phbhit (the headbutt hit) at
--               HookSmashAt (the reel ends in a headbutt). While GameSoundsPachyBeatsEnabled (default true) the 1.7 phook does
--               not play; false = 1.13.
--               v1.15: option A (Kepu 2026-11-17 12:20 "Hook A"): phookfire 94784187848873, phookreel 130597595260324 (the C ids
--               127660704971301 / 73058958917716 were 1.14's).
--   * the rest of the Pachy's parts (v1.15, sound pass round 11 picks "Dash A, Visor C, Ink C, Tether C, Blood Rush C, Med A",
--               chosen on the game's own recorded animation), 3D like the hook, each on its beat, while GameSoundsPachyBeatsEnabled:
--               Servo Dash: pdashblast at ServoDashBlastAt - GameSoundsPachyDashBlastLead (0.06, the blast is that far into the
--                 clip); pdashburn (looped) from ServoDashBlastAt + GameSoundsPachyDashBurnAt (0.25, the 22-stud burst done) until
--                 ServoDashUntil (read live: an early end moves it), faded; pdashsteam at that end (the game's dust + steam).
--               Dome Visor: pvisorup on VisorStartedAt; pvisorfield (looped) from VisorStartedAt + GameSoundsPachyVisorFieldAt
--                 (0.10, the panels in) until VisorUntil, faded; pvisordown at that end; pvisorblock on each VisorBlockAt.
--               Ink Shooter: pinkfire at InkFireAt - GameSoundsPachyInkLead (0.10: the pump, the shot 0.10 s into the clip);
--                 pinksplat on InkArriveAt (stamped when the shot resolves, after InkStartedAt) at InkAimEnd.
--               Tether Spike: ptethercock when the aim starts: TetherAimAt (TetherServer), on your own Pachy also
--                 TetherAimLocalAt and TetherAiming turning true (one per aim: stamps closer than GameSoundsPachyCockDedupe 0.5 s
--                 are the same aim); ptetherthrow on TetherStartedAt; ptetherland at TetherLandAt (at the dino).
--               Blood Rush: pbloodpact on HeadbuttSacrificeAt.
--               Med-Station: pmeddrop on MedDroppedAt; pmedhum (looped) from MedDroppedAt + GameSoundsPachyMedHumAt (0.60, landed
--                 and unfolded) until MedActiveUntil (read live), faded; pmedfold at that end; all three where the dino was at the
--                 drop (the station stays there).
--               While GameSoundsPachyBeatsEnabled the 1.7 pink / pmed / pdash / ptether / pvisor / pblood do not play; false = 1.14.
--   Not while you are in the menu (player InMenu), except click.
-- Switch: script attribute GameSoundsEnabled (default true, read per event). SoundGroup GameSFX volume: GameSoundsVolume (1).
-- Diagnostics: GameSoundsVersion, GameSoundsLast ("<event>"), GameSoundsCount_<event>; v1.3 GameSoundsLast3D ("<event>:<dino>").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 the uploaded sound ids are the defaults
-- v1.1 (MDA-552; Kepu 2026-11-16 15:04 "You upload it. I'm away from the PC"): the 11 sounds were imported through Studio's Asset
--   Manager to BloxSolidYT's inventory; their ids are now the GameSoundsId_<event> defaults (IDS below).
VERSION = "1.2" -- v1.2 getting hit and death sounds
VERSION = "1.3" -- v1.3 the Raptor's ability sounds
VERSION = "1.4" -- v1.4 the Dilophosaurus' ability sounds
VERSION = "1.5" -- v1.5 the Herrera's ability sounds
VERSION = "1.6" -- v1.6 the Troodon's ability sounds
VERSION = "1.7" -- v1.7 the Pachy's ability sounds (real recordings)
VERSION = "1.8" -- v1.8 the Tenontosaurus' ability sounds (Sonniss real recordings)
VERSION = "1.9" -- v1.9 the Therizino's ability sounds, timed to the animation beats
VERSION = "1.10" -- v1.10 the Tenontosaurus' ability sounds re-timed to the animation beats
VERSION = "1.11" -- v1.11 the Pachy's headbutt hit sound
VERSION = "1.12" -- v1.12 the Pachy's jump sound
VERSION = "1.13" -- v1.13 the Pachy's jump sound on the double jump too
VERSION = "1.14" -- v1.14 the Pachy's Grappling Hook on its beats, ending in the headbutt hit
VERSION = "1.15" -- v1.15 the rest of the Pachy's parts on their beats (round 11 picks), the hook on option A
VERSION = "1.16" -- v1.16 Hardpoint voice callouts replace the captured / lost / contested sounds
VERSION = "1.17" -- v1.17 the match intro voice line over the pre-match countdown
VERSION = "1.18" -- v1.18 the Raptor's buttons on their beats (round 17 picks)
-- v1.2 (MDA-552; Kepu 2026-11-16 15:27 picks from the Sound Pick Board round 2: "hurt C, died C"): two original sounds in the punchy
--   real style (hurt = crunchy punch with a metal tick, 0.30 s; died = low dying growl and thud, 1.50 s), files
--   docs/sfx/MDA_SFX_hurt.wav / MDA_SFX_died.wav, imported through Studio's Asset Manager. New events "hurt" and "died" (header).
-- v1.3 (MDA-552; Kepu 2026-11-16 15:45 "Next" -> the Raptor first (the default dino); 15:50 picks from the Sound Pick Board round 3:
--   "cloak C, shield B, adren A, cannon A, scent A"; who hears: "Nearby, Scent only you"): five original sounds (files
--   docs/sfx/MDA_SFX_<event>.wav), imported through Studio's Asset Manager. New events cloak, shield, adren, cannon (3D at the dino)
--   and scent (2D, yours only) (header). Bite, pounce, roar, the Thrusters boost and the Shock Mine keep their own sounds.
-- v1.4 (MDA-552; Kepu 2026-11-16 15:57 "next" -> the Dilophosaurus (the most silent buttons); 16:02 picks from the Sound Pick Board
--   round 4: "gatling B, mortar B, spine B, over A, hiss B, pump A, scope C"): seven original sounds (files
--   docs/sfx/MDA_SFX_dilo_<part>.wav), imported through Studio's Asset Manager, heard like the Raptor's (3D at the dino). Spring Jets
--   keeps its thruster sound (DiloMovesFX); the dilo's bite and spit stay silent.
-- v1.5 (MDA-552; Kepu 2026-11-16 16:17 "next" -> the Herrera; 16:27 picks from the Sound Pick Board round 5: "quills A, smoke A,
--   strobe A, breaker A, caltrops A, goo B, glider B, cmlaunch A, cmboom A"): nine original sounds (files
--   docs/sfx/MDA_SFX_herr_<part>.wav), imported through Studio's Asset Manager, heard like the Raptor's; the Cruise Missile blast
--   plays at the blast point. The Herrera's Adrenaline Injector already plays "adren" (it runs on AdrenalineServer).
-- v1.6 (MDA-552; Kepu 2026-11-16 16:37 "next" -> the Troodon; 16:43 picks from the Sound Pick Board round 6: "oburst B, odome B,
--   olantern C, omender B, oportal C, osapwall A, osentry B, oshed B, osleep B"): nine original sounds (files
--   docs/sfx/MDA_SFX_troo_<part>.wav), imported through Studio's Asset Manager, heard like the Raptor's (3D at the dino, at the press).
-- v1.7 (MDA-552; Kepu 2026-11-16 17:05 the synthesized options "feel lazy" -> "Real sounds, redo all"; 17:14 "1. Let's do that" (the
--   Roblox licensed library); 17:19 picks from the Sound Pick Board round 7 v2: "hookarm A, ink A, medstation C, servodash C,
--   tether B, visor C, bloodrush A"): real recordings from Roblox's Pro Sound Effects library (free to use in Roblox games), used by
--   their library ids (no upload): Chain Movement 1, Wet Newspaper Squish 14, Phasey Synth Power Up 2, Servo Pig Motor Burst 3,
--   Sci-Fi Weapon 12, Robot Servo Synth, Blood Spurt 2. Heard like the Raptor's (3D at the dino).
-- v1.8 (MDA-552; Kepu 2026-11-16 17:32 the blind library picks for the Teno were "straight ass"; 20:13 "Okay let's move forward then
--   with the sounds" once the Sonniss GDC 2026 bundle had downloaded; 20:23 picks from the Sound Pick Board round 8 (Sonniss):
--   "tbellow C, tchallenge B, tgrab C, tgrabland A, tleap B, tleapland C, tmortar B, tmortarboom C, tmud A, tstomp B"): ten sounds
--   built from real recordings in the Sonniss GDC 2026 bundle (royalty-free for games; recipe docs/sfx/gen_teno_sonniss_sfx.py),
--   imported through Studio's Asset Manager. Eight play at the Teno like the Raptor's; tgrabland at TenoGrabLand and tmortarboom
--   at TenoMortarLand (header). playAt takes an optional range (maxDist, minDist); without it the blast range as in 1.5.
-- v1.9 (MDA-552; Kepu 2026-11-16 21:21 "These sound options don't even line up with the damn animation timing"; 21:36 picks from
--   the Sound Pick Board round 9 v2, the sounds played on the real move animation: Harvest C, Snare B, Dash B, Hook B, Feather A,
--   Deflector A): fifteen sound parts built from the Sonniss GDC 2026 bundle to the move beats (TheriPose 1.11, TheriMovesFX2
--   1.2; recipe docs/sfx/gen_theri_v2_sfx.py), imported through Studio's Asset Manager, scheduled from TheriMovesServer 1.14's
--   stamps (header). The Teno's 1.8 sounds are unchanged (their re-time is the next round).
-- v1.10 (MDA-552; Kepu 2026-11-16 21:21 "You did the same shit for all the other dinos too"; 22:08 picks from the Sound Pick Board
--   round 10, the sounds played on the Teno move animation (docs/sfx/TENO_BEATS_v1.0.md): "Grab A, Mortar B, Stomp A,
--   Bellow C, Challenge C, Leap A, Shield B"): eighteen parts built from the Sonniss bundle to the move beats (recipe
--   docs/sfx/gen_teno_v2_sfx.py), imported through Studio's Asset Manager, scheduled from TenoMovesServer 1.18's stamps
--   (header); the 1.8 Teno sounds step aside while GameSoundsTenoBeatsEnabled. startPart / partAt take an optional range.
-- v1.11 (MDA-552; Kepu 2026-11-17 10:40 "there is no sound for the headbutt", 10:51 "use this for the headbutt" with
--   180663__mixedupmoviestuff__headbutt.wav (Freesound)): phbhit, that file trimmed to 0.37 s and levelled for phone speakers
--   (mono 48 kHz, the same levelling as the round 9-10 parts), imported through Studio's Asset Manager, on HeadbuttHitAt.
-- v1.12 (MDA-552; Kepu 2026-11-17 10:40 "or for the double jump" (no sound), 11:06 "use that for jump" with
--   399095__plasterbrain__8bit-jump.flac (Freesound)): pjump, that file (0.11 s) levelled like phbhit, imported through Asset
--   Manager, at the Pachy's lift-off (header).
-- v1.13 (Kepu 2026-11-17 11:13 "the double jump should have the jump sound just play again on the second jump"): pjump
--   also on the double jump (header).
-- v1.14 (Kepu 2026-11-17 11:17 "i like c for the grappling hook sound but make sure you add the headbutt sound at the end when
--   the dino is reeled in since it ends with a headbutt"): Sound Pick Board round 11 hook C (recipe docs/sfx/gen_pachy_v2_sfx.py,
--   the Sonniss sampler), imported through Asset Manager, scheduled from the hook stamps, phbhit at the smash (header).
-- v1.15 (Kepu 2026-11-17 11:36 "How about you actually use the fucking animation from the game" -> the pick page plays Studio
--   recordings of the game; 12:20 picks "Headbutt A, Jump A, Hook A, Dash A, Visor C, Ink C, Tether C, Blood Rush C, Med A"):
--   sixteen new parts (recipe docs/sfx/gen_pachy_v2_sfx.py) and the hook's option A, imported through Asset Manager, each on the
--   beat the game stamps (header; beats checked against the recordings, docs/sfx/PACHY_BEATS_v1.0.md v1.2). Headbutt A and
--   Jump A are the 1.11 / 1.12 sounds (unchanged).
-- v1.16 (Kepu 2026-11-17 12:42 "I don't like the point sounds switching over and all that, it sounds stupid and does call of
--   duty even do that?"; picked "Voice callouts" and "Keep them" (moving / tick / go stay); 12:53 "Point voice A"): three
--   announcer lines (Kokoro-82M text to speech, Apache-2.0, radio-styled; recipe docs/sfx/gen_point_vo.sh), imported through
--   Asset Manager, said once the point has settled (header).
-- v1.17 (Kepu 2026-11-17 12:58 "how about a voice playing in the background for the brief intro to like get to the Hardpoint.
--   Use your mecha upgrades to your advantage"; 13:02 picks lines 1 and 2): two lines in voice A (recipe gen_point_vo.sh v1.1),
--   imported through Asset Manager, over the countdown fly-over (header).
-- v1.18 (MDA-552, sound pass round 17; Kepu 2026-11-17 19:18 "Cloak B, Shield B, Adrenaline A, Cannon A, Scent A" on the
--   Raptor pick page that plays Studio recordings of the game): the Raptor's five buttons get real sounds (recipe
--   docs/sfx/gen_raptor_v2_sfx.py, Sonniss; 15 parts imported through Asset Manager, ids checked with GetProductInfo), each part
--   on the beat the game stamps (3D at the dino unless noted):
--     Cloak Field   rcloakon at CloakStartedAt; rcloakoff when CloakState turns "off" (the cloak drops).
--     Energy Shield rshieldup at EnergyShieldStartedAt; rshieldhum (loop) from + GameSoundsRaptorShieldHumAt (0.10) until
--                   EnergyShieldUntil, then rshielddown; rshieldblock at every EnergyShieldBlockAt.
--     Adrenaline    radreninject at AdrenalineStartedAt; radrenrush (loop, a heartbeat) from + GameSoundsRaptorRushAt (0.30)
--                   until AdrenalineUntil, then radrenend.
--     Shock Cannon  rcannoncharge (loop) on your own dino while you hold the aim (MechaScreechAim "aiming", set by your client;
--                   other players don't see your aim, so they don't hear it); rcannonfire at ScreechStartedAt; rcannonhit at
--                   the target's ScreechHitAt (on the dino that was hit).
--     Scent Sense   your own dino only, as 1.3: rscentsniff at ScentStartedAt; rscentaura (loop) from + GameSoundsRaptorAuraAt
--                   (0.60) until ScentUntil, then rscentend.
--   While GameSoundsRaptorBeatsEnabled (default true) these replace the 1.3 cloak / shield / adren / cannon / scent sounds;
--   false = 1.17. The loops fade over GameSoundsTheriLoopFade (0.08) s, as every beat-timed loop.
script:SetAttribute("GameSoundsVersion", VERSION)
local player = Players.LocalPlayer

local EVENTS = {"hit", "kill", "captured", "lost", "contested", "moving", "tick", "go", "click", "win", "lose",
	"hurt", "died", -- v1.2 hurt, died
	"cloak", "shield", "adren", "cannon", "scent", -- v1.3 Raptor buttons
	"dgatling", "dmortar", "dspine", "dover", "dhiss", "dpump", "dscope", -- v1.4 Dilophosaurus buttons
	"hquills", "hsmoke", "hstrobe", "hbreaker", "hcaltrops", "hgoo", "hglider", "hcmlaunch", "hcmboom", -- v1.5 Herrera buttons
	"oburst", "odome", "olantern", "omender", "oportal", "osapwall", "osentry", "oshed", "osleep", -- v1.6 Troodon buttons
	"phook", "pink", "pmed", "pdash", "ptether", "pvisor", "pblood", -- v1.7 Pachy buttons
	"tbellow", "tchallenge", "tgrab", "tgrabland", "tleap", "tleapland", "tmortar", "tmortarboom", "tmud", "tstomp"} -- v1.8 Teno
local IDS = {hit = "123580812773962", kill = "76655662060940", captured = "113513728853752", lost = "124135883749071",
	contested = "101864400003768", moving = "136030860049130", tick = "86647331351122", go = "122207388352651",
	click = "100987841683034", win = "71840308309828", lose = "81529780885336",
	hurt = "75565630737484", died = "97374555569398", -- v1.1; v1.2 hurt, died
	cloak = "71499307467716", shield = "127396962777997", adren = "127472396863191", cannon = "103381972237825",
	scent = "73289725571120", -- v1.3
	dgatling = "78744560071574", dmortar = "88561547660478", dspine = "70381297668849", dover = "139341624407479",
	dhiss = "91279059395796", dpump = "75209586059891", dscope = "123275908451380", -- v1.4
	hquills = "99387893346374", hsmoke = "95015917968676", hstrobe = "89385419107010", hbreaker = "132408189699355",
	hcaltrops = "122877492518576", hgoo = "76868818068463", hglider = "99551154658790", hcmlaunch = "78951828583998",
	hcmboom = "111468500071162", -- v1.5
	oburst = "117236886371898", odome = "122437822830255", olantern = "130563682814012", omender = "113309575050749",
	oportal = "128803735549174", osapwall = "91446054650325", osentry = "134001878124782", oshed = "102472464366448",
	osleep = "90715155100654", -- v1.6
	phook = "9113760085", pink = "9126209045", pmed = "9117297453", pdash = "9118999657", ptether = "9118792593",
	pvisor = "9118462554", pblood = "9113464577", -- v1.7 (Pro Sound Effects library ids)
	tbellow = "123619163891690", tchallenge = "114717093655552", tgrab = "88873267601305", tgrabland = "76525307110011",
	tleap = "112730494776189", tleapland = "88753782496487", tmortar = "99493915731747", tmortarboom = "85790097999139",
	tmud = "86971682244323", tstomp = "133614043199990"} -- v1.8 (Sonniss, uploaded)
local VOL = {hit = 0.5, kill = 0.7, captured = 0.6, lost = 0.6, contested = 0.5, moving = 0.6, tick = 0.6, go = 0.7,
	click = 0.4, win = 0.7, lose = 0.7, hurt = 0.6, died = 0.8,
	cloak = 0.7, shield = 0.7, adren = 0.7, cannon = 0.8, scent = 0.6, -- v1.3
	dgatling = 0.6, dmortar = 0.8, dspine = 0.7, dover = 0.7, dhiss = 0.8, dpump = 0.7, dscope = 0.7, -- v1.4
	hquills = 0.7, hsmoke = 0.7, hstrobe = 0.6, hbreaker = 0.8, hcaltrops = 0.6, hgoo = 0.7, hglider = 0.6, hcmlaunch = 0.8,
	hcmboom = 1, -- v1.5
	oburst = 0.6, odome = 0.7, olantern = 0.7, omender = 0.6, oportal = 0.7, osapwall = 0.7, osentry = 0.6, oshed = 0.7,
	osleep = 0.6, -- v1.6
	phook = 0.7, pink = 0.7, pmed = 0.6, pdash = 0.7, ptether = 0.7, pvisor = 0.7, pblood = 0.7, -- v1.7
	tbellow = 0.8, tchallenge = 0.8, tgrab = 0.7, tgrabland = 0.8, tleap = 0.7, tleapland = 0.8, tmortar = 0.7, tmortarboom = 1,
	tmud = 0.7, tstomp = 0.9} -- v1.8
for e, v in pairs({ -- v1.9 the Therizino's parts: {id, volume}
	zhookfire = {"131988444170332", 0.7}, zhookwinch = {"131501209791943", 0.6}, zhookslash = {"85268010968406", 0.8},
	zvortexstart = {"91084196333840", 0.8}, zvortexloop = {"135068714785438", 0.6}, zvortexend = {"117745071258163", 0.7},
	zbolathrow = {"122613590025358", 0.7}, zbolahit = {"99760597011860", 0.8}, zdash = {"118434882177264", 0.8},
	zvolley = {"130759604256921", 0.7}, zvolleyhit = {"92654761874896", 0.7}, zwallup = {"135596427314350", 0.7},
	zwallloop = {"94762016615713", 0.5}, zwallblock = {"140711257394199", 0.8}, zwalldown = {"71150551434238", 0.6}}) do
	table.insert(EVENTS, e)
	IDS[e], VOL[e] = v[1], v[2]
end
local TENO_PART = {} -- v1.10 the Teno's parts: {id, volume}
for e, v in pairs({
	tngrabwind = {"77520438511156", 0.6}, tngrabsnap = {"131540155210065", 0.8}, tngrabthrow = {"132641824036451", 0.7},
	tngrabland = {"75053608742552", 0.8}, tnmortarbrace = {"113038213084372", 0.6}, tnmortarfire = {"125080238294976", 0.8},
	tnmortarboom = {"114145194421823", 1}, tnstomprear = {"105601397792894", 0.6}, tnstompsmash = {"131108377319807", 0.9},
	tnbellowinhale = {"119435326057632", 0.5}, tnbellowshriek = {"107982074709205", 0.8}, tnchallenge = {"139212929992682", 0.8},
	tnleaplaunch = {"110603309882911", 0.7}, tnleapland = {"129593000710169", 0.8}, tnshieldup = {"77299946481525", 0.7},
	tnshieldloop = {"127604914238828", 0.4}, tnshieldblock = {"104230393846785", 0.8}, tnshielddown = {"110028649285192", 0.6}}) do
	table.insert(EVENTS, e)
	IDS[e], VOL[e] = v[1], v[2]
	TENO_PART[e] = true
end
local TENO_OLD = {tbellow = true, tchallenge = true, tgrab = true, tgrabland = true, tleap = true, tleapland = true, tmortar = true,
	tmortarboom = true, tmud = true, tstomp = true} -- v1.10: the 1.8 Teno events, superseded while GameSoundsTenoBeatsEnabled
local function tenoOn() return script:GetAttribute("GameSoundsTenoBeatsEnabled") ~= false end
for e, v in pairs({vosecured = {"136123722053492", 0.8}, volost = {"125590664814127", 0.8}, vocontested = {"112060909723099", 0.8}, -- v1.16
	vointro1 = {"86878168682330", 0.8}, vointro2 = {"110246063668098", 0.8}}) do -- v1.17
	table.insert(EVENTS, e)
	IDS[e], VOL[e] = v[1], v[2]
end
table.insert(EVENTS, "phbhit") -- v1.11 the Pachy's headbutt hit
IDS.phbhit, VOL.phbhit = "108009591584705", 0.9
table.insert(EVENTS, "pjump") -- v1.12 the Pachy's jump
IDS.pjump, VOL.pjump = "70558141231443", 0.7
local PACHY_PART = {phbhit = true} -- v1.14 the Pachy's beat-timed parts (startPart's switch)
for e, v in pairs({phookfire = {"94784187848873", 0.7}, phookreel = {"130597595260324", 0.6}, -- v1.15 option A (1.14: C)
	pdashblast = {"126810324831290", 0.8}, pdashburn = {"108611388528002", 0.5}, pdashsteam = {"119034673718501", 0.7}, -- v1.15
	pvisorup = {"95515746698004", 0.7}, pvisorfield = {"86884477049579", 0.4}, pvisorblock = {"86631190160444", 0.8},
	pvisordown = {"120963791844379", 0.6}, pinkfire = {"105959170413554", 0.7}, pinksplat = {"94524176200767", 0.8},
	ptethercock = {"127114367228594", 0.6}, ptetherthrow = {"121222580398449", 0.7}, ptetherland = {"139847071392979", 0.8},
	pbloodpact = {"124393868939241", 0.8}, pmeddrop = {"80475095684327", 0.7}, pmedhum = {"82731615993453", 0.4},
	pmedfold = {"129929373362813", 0.6}}) do
	table.insert(EVENTS, e)
	IDS[e], VOL[e] = v[1], v[2]
	PACHY_PART[e] = true
end
local function pachyOn() return script:GetAttribute("GameSoundsPachyBeatsEnabled") ~= false end
local RAPTOR_PART = {} -- v1.18 the Raptor's beat-timed parts: {id, volume}
for e, v in pairs({rcloakon = {"81803825775341", 0.7}, rcloakoff = {"103454044172705", 0.7},
	rshieldup = {"139909059107220", 0.7}, rshieldhum = {"92451753596567", 0.4}, rshielddown = {"78402630525991", 0.6},
	rshieldblock = {"102231576226042", 0.8}, radreninject = {"125435868847109", 0.7}, radrenrush = {"110717663054124", 0.5},
	radrenend = {"136450310078265", 0.6}, rcannoncharge = {"108134095342460", 0.45}, rcannonfire = {"139668904289876", 0.8},
	rcannonhit = {"127154078035843", 0.8}, rscentsniff = {"86346147369461", 0.6}, rscentaura = {"106240258427764", 0.35},
	rscentend = {"136991527467745", 0.5}}) do
	table.insert(EVENTS, e)
	IDS[e], VOL[e] = v[1], v[2]
	RAPTOR_PART[e] = true
end
local function raptorOn() return script:GetAttribute("GameSoundsRaptorBeatsEnabled") ~= false end -- v1.18
local RAPTOR_OLD = {cloak = true, shield = true, adren = true, cannon = true} -- v1.18 (scent: its own 2D call)
local PACHY_OLD = {phook = true, pink = true, pmed = true, pdash = true, ptether = true, pvisor = true, pblood = true} -- v1.15
for k, v in pairs({GameSoundsEnabled = true, GameSoundsVolume = 1, GameSoundsHitGap = 0.07, GameSoundsOccGap = 1,
	GameSoundsMoveWarn = 5, GameSoundsTickFrom = 3, GameSoundsHurtGap = 0.15, GameSoundsHurtSpawnIgnore = 1, -- v1.2
	GameSoundsAbilityRange = 200, GameSoundsAbilityNear = 10, -- v1.3
	GameSoundsBlastRange = 400, GameSoundsBlastNear = 20, -- v1.5
	GameSoundsTheriBeatsEnabled = true, GameSoundsTheriLoopFade = 0.08, GameSoundsTheriCutFade = 0.04, -- v1.9
	GameSoundsTheriWallLoopAt = 0.15, GameSoundsTheriHitMax = 6, -- v1.9
	GameSoundsTenoBeatsEnabled = true, GameSoundsTenoStrikeLead = 0.15, GameSoundsTenoShriekAt = 0.40, GameSoundsTenoLandDedupe = 1, -- v1.10
	GameSoundsPachyDoubleDedupe = 0.5, -- v1.13
	GameSoundsPachyBeatsEnabled = true, GameSoundsPachyHookLead = 0.15, -- v1.14
	GameSoundsPachyDashBlastLead = 0.06, GameSoundsPachyDashBurnAt = 0.25, GameSoundsPachyVisorFieldAt = 0.10, -- v1.15
	GameSoundsPachyInkLead = 0.10, GameSoundsPachyCockDedupe = 0.5, GameSoundsPachyMedHumAt = 0.60, -- v1.15
	GameSoundsPointVoiceEnabled = true, GameSoundsVoiceSettle = 1, GameSoundsVoiceGap = 4, -- v1.16
	GameSoundsIntroEnabled = true, GameSoundsIntroAt = 9, GameSoundsIntroLate = 0.5, GameSoundsIntroLines = "vointro1,vointro2", -- v1.17
	GameSoundsRaptorBeatsEnabled = true, GameSoundsRaptorShieldHumAt = 0.10, GameSoundsRaptorRushAt = 0.30, -- v1.18
	GameSoundsRaptorAuraAt = 0.60, GameSoundsRaptorChargeMax = 10, -- v1.18
	GameSoundsClickGuis = "MainMenu,Lab,LabButton,PregameScreen,IslandDino,PhoneMenu,RespawnScreen,CameraButton,SquadButton,PortalHUD,ArenaQueue,ArenaStatus,HardpointHUD"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
for _, e in ipairs(EVENTS) do
	if script:GetAttribute("GameSounds_" .. e .. "Enabled") == nil then script:SetAttribute("GameSounds_" .. e .. "Enabled", true) end
	if script:GetAttribute("GameSoundsId_" .. e) == nil then script:SetAttribute("GameSoundsId_" .. e, IDS[e] or "") end
	if script:GetAttribute("GameSoundsVol_" .. e) == nil then script:SetAttribute("GameSoundsVol_" .. e, VOL[e]) end
end
local function num(k, d) return tonumber(script:GetAttribute(k)) or d end

local group = SoundService:FindFirstChild("GameSFX")
if not (group and group:IsA("SoundGroup")) then
	group = Instance.new("SoundGroup")
	group.Name = "GameSFX"
	group.Parent = SoundService
end
local templates = {}
local function template(e)
	local id = script:GetAttribute("GameSoundsId_" .. e)
	id = type(id) == "string" and id or tostring(id or "")
	if id == "" or id == "0" then return nil end
	if not id:find("^rbxasset") then id = "rbxassetid://" .. id end
	local s = templates[e]
	if not s then
		s = Instance.new("Sound")
		s.Name = "GameSounds_" .. e
		s.SoundGroup = group
		s.Parent = script
		templates[e] = s
	end
	if s.SoundId ~= id then s.SoundId = id end
	s.Volume = num("GameSoundsVol_" .. e, VOL[e])
	return s
end
local function play(e, inMenuOk)
	if script:GetAttribute("GameSoundsEnabled") == false or script:GetAttribute("GameSounds_" .. e .. "Enabled") == false then return end
	if not inMenuOk and player:GetAttribute("InMenu") == true then return end
	group.Volume = num("GameSoundsVolume", 1)
	local s = template(e)
	script:SetAttribute("GameSoundsLast", e)
	script:SetAttribute("GameSoundsCount_" .. e, (script:GetAttribute("GameSoundsCount_" .. e) or 0) + 1)
	if s then SoundService:PlayLocalSound(s) end
end
for _, e in ipairs(EVENTS) do template(e) end -- preload the ones that have ids

-- hit (your character's LastDealtAt) ---------------------------------------------------------------------------------------
local lastHit = 0
local function hookChar(char)
	char:GetAttributeChangedSignal("LastDealtAt"):Connect(function()
		if os.clock() - lastHit < num("GameSoundsHitGap", 0.07) then return end
		lastHit = os.clock()
		play("hit")
	end)
end
player.CharacterAdded:Connect(hookChar)
if player.Character then hookChar(player.Character) end

-- v1.2 hurt / died (your character's Humanoid) ------------------------------------------------------------------------------
local lastHurt = 0
local function hookHealth(char)
	local spawnedAt = os.clock()
	local hum = char:WaitForChild("Humanoid", 10)
	if not (hum and hum:IsA("Humanoid")) then return end
	local last = hum.Health
	local diedPlayed = false
	hum.HealthChanged:Connect(function(h)
		local prev = last
		last = h
		if h >= prev - 0.01 or h <= 0 or h >= hum.MaxHealth then return end
		if os.clock() - spawnedAt < num("GameSoundsHurtSpawnIgnore", 1) then return end
		if os.clock() - lastHurt < num("GameSoundsHurtGap", 0.15) then return end
		lastHurt = os.clock()
		play("hurt")
	end)
	hum.Died:Connect(function()
		if diedPlayed then return end
		diedPlayed = true
		play("died")
	end)
end
player.CharacterAdded:Connect(hookHealth)
if player.Character then task.spawn(hookHealth, player.Character) end

-- v1.3 the Raptor's ability sounds: 3D at the dino for cloak / shield / adren / cannon, 2D yours only for scent ---------------
local Debris = game:GetService("Debris")
local ABILITY = {cloak = "CloakStartedAt", shield = "EnergyShieldStartedAt", adren = "AdrenalineStartedAt",
	cannon = "ScreechStartedAt"}
for e, attr in pairs({dgatling = "DiloGatlingAt", dmortar = "DiloMortarFireAt", dspine = "DiloSpineBurstAt", -- v1.4 Dilophosaurus
	dover = "DiloOverdriveAt", dhiss = "DiloHissBlastAt", dpump = "DiloPumpJoltAt", dscope = "DiloScopeShotAt"}) do
	ABILITY[e] = attr
end
for e, attr in pairs({hquills = "QuillStartedAt", hsmoke = "SmokeStartedAt", hstrobe = "StrobeAt", hbreaker = "BreakerAt", -- v1.5
	hcaltrops = "CaltropDroppedAt", hgoo = "GooFiredAt", hglider = "GlideStartedAt", hcmlaunch = "CruiseLaunchAt"}) do
	ABILITY[e] = attr
end
for e, attr in pairs({oburst = "TrooBurstAt", odome = "TrooDomeAt", olantern = "TrooLanternAt", omender = "TrooMenderAt", -- v1.6
	oportal = "TrooRiftOpenAt", osapwall = "TrooSapAt", osentry = "TrooSentryAt", oshed = "TrooShedAt", osleep = "TrooSleepFireAt"}) do
	ABILITY[e] = attr
end
for e, attr in pairs({phook = "HookStartedAt", pink = "InkStartedAt", pmed = "MedDroppedAt", pdash = "ServoDashStartedAt", -- v1.7
	ptether = "TetherStartedAt", pvisor = "VisorStartedAt", pblood = "HeadbuttSacrificeAt"}) do
	ABILITY[e] = attr
end
for e, attr in pairs({tbellow = "TenoBellowAt", tchallenge = "TenoChallengeAt", tgrab = "TenoGrabStartedAt", -- v1.8 Teno
	tleap = "TenoLeapStartedAt", tleapland = "TenoLeapLandedAt", tmortar = "TenoMortarFiredAt", tmud = "TenoMudStartedAt",
	tstomp = "TenoStompAt"}) do
	ABILITY[e] = attr
end
ABILITY.phbhit = "HeadbuttHitAt" -- v1.11
local function play3D(e, m)
	if TENO_OLD[e] and tenoOn() then return end -- v1.10
	if e == "phook" and pachyOn() then return end -- v1.14: the beat-timed hook replaces it
	if PACHY_OLD[e] and pachyOn() then return end -- v1.15: the beat-timed parts replace the 1.7 Pachy sounds
	if RAPTOR_OLD[e] and raptorOn() then return end -- v1.18: the beat-timed parts replace the 1.3 Raptor sounds
	if script:GetAttribute("GameSoundsEnabled") == false or script:GetAttribute("GameSounds_" .. e .. "Enabled") == false then return end
	if player:GetAttribute("InMenu") == true then return end
	local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	if not (root and root:IsA("BasePart")) then return end
	group.Volume = num("GameSoundsVolume", 1)
	local tpl = template(e)
	script:SetAttribute("GameSoundsLast", e)
	script:SetAttribute("GameSoundsLast3D", e .. ":" .. m.Name)
	script:SetAttribute("GameSoundsCount_" .. e, (script:GetAttribute("GameSoundsCount_" .. e) or 0) + 1)
	if not tpl then return end
	local s = tpl:Clone()
	s.RollOffMaxDistance = num("GameSoundsAbilityRange", 200)
	s.RollOffMinDistance = num("GameSoundsAbilityNear", 10)
	s.Parent = root
	s:Play()
	Debris:AddItem(s, math.max(tpl.TimeLength, 1) + 0.5)
end

-- v1.9 the Therizino's ability sounds, each part on its animation beat (header) ----------------------------------------------
local TweenService = game:GetService("TweenService")
local function serverNow() return workspace:GetServerTimeNow() end
local function theriOn() return script:GetAttribute("GameSoundsTheriBeatsEnabled") ~= false end
local theriLog = {}
local function logPart(e, lateMs)
	table.insert(theriLog, e .. "@" .. tostring(lateMs))
	while #theriLog > 24 do table.remove(theriLog, 1) end
	script:SetAttribute("GameSoundsTheriLog", table.concat(theriLog, " "))
end
local function findDino(name)
	if type(name) ~= "string" or name == "" then return nil end
	local pl = Players:FindFirstChild(name)
	if pl and pl:IsA("Player") and pl.Character then return pl.Character end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	local b = bots and bots:FindFirstChild(name)
	return (b and b:IsA("Model")) and b or nil
end
local function fadeOut(s, fade)
	if not (s and s.Parent) then return end
	local tw = TweenService:Create(s, TweenInfo.new(math.max(0.01, fade), Enum.EasingStyle.Linear), {Volume = 0})
	tw:Play()
	task.delay(fade + 0.05, function() local p = s.Parent; s:Destroy(); if p and p:IsA("Attachment") then p:Destroy() end end)
end
-- start part e at server time startAt at `where` (a dino model or a Vector3); looped = a loop; returns the Sound (or nil)
local function startPart(e, where, startAt, looped, maxD, minD) -- v1.10: optional range (default the ability range)
	if TENO_PART[e] then if not tenoOn() then return nil end
	elseif PACHY_PART[e] then if not pachyOn() then return nil end -- v1.14: the Pachy's switch
	elseif RAPTOR_PART[e] then if not raptorOn() then return nil end -- v1.18: the Raptor's switch
	elseif not theriOn() then return nil end -- v1.10: the Teno's switch
	if script:GetAttribute("GameSoundsEnabled") == false or script:GetAttribute("GameSounds_" .. e .. "Enabled") == false then return nil end
	if player:GetAttribute("InMenu") == true then return nil end
	group.Volume = num("GameSoundsVolume", 1)
	local tpl = template(e)
	if not tpl then return nil end
	local late = serverNow() - startAt
	if not looped and tpl.TimeLength > 0 and late > tpl.TimeLength then logPart(e, "skip"); return nil end
	local parent
	if typeof(where) == "Vector3" then
		parent = Instance.new("Attachment")
		parent.Name = "GameSounds_" .. e .. "_At"
		parent.WorldPosition = where
		parent.Parent = workspace.Terrain
	elseif typeof(where) == "Instance" and where.Parent then
		local root = where:FindFirstChild("HumanoidRootPart") or where.PrimaryPart
		if not (root and root:IsA("BasePart")) then return nil end
		parent = root
	else
		return nil
	end
	local s = tpl:Clone()
	s.Looped = looped == true
	s.RollOffMaxDistance = maxD or num("GameSoundsAbilityRange", 200)
	s.RollOffMinDistance = minD or num("GameSoundsAbilityNear", 10)
	s.Parent = parent
	if late > 0.02 then s.TimePosition = looped and (late % math.max(tpl.TimeLength, 0.05)) or late end
	s:Play()
	script:SetAttribute("GameSoundsLast", e)
	script:SetAttribute("GameSoundsCount_" .. e, (script:GetAttribute("GameSoundsCount_" .. e) or 0) + 1)
	logPart(e, math.floor(math.max(0, late) * 1000 + 0.5))
	if not looped then
		if parent:IsA("Attachment") then Debris:AddItem(parent, math.max(tpl.TimeLength, 1) + 0.5) else Debris:AddItem(s, math.max(tpl.TimeLength, 1) + 0.5) end
	end
	return s
end
-- a one-shot at server time `at` (cut at `cutAt` when given)
local function partAt(e, where, at, cutAt, maxD, minD)
	local function go()
		local s = startPart(e, where, at, false, maxD, minD)
		if s and cutAt then
			local fade = num("GameSoundsTheriCutFade", 0.04)
			task.delay(math.max(0, cutAt - fade - serverNow()), fadeOut, s, fade)
		end
	end
	local d = at - serverNow()
	if d > 0.005 then task.delay(d, go) else go() end
end
-- a loop from loopAt until untilFn() (read live), then endE at that time; alive() false = a newer cast: fade, no end sound
local function loopPart(m, loopE, endE, loopAt, untilFn, alive)
	task.spawn(function()
		while alive() and serverNow() < loopAt and serverNow() < (tonumber(untilFn()) or 0) do task.wait() end -- ends first: no loop
		if not alive() then return end
		local fade = num("GameSoundsTheriLoopFade", 0.08)
		local s = (serverNow() < (tonumber(untilFn()) or 0)) and startPart(loopE, m, loopAt, true) or nil
		local guard = serverNow() + 60
		while alive() and serverNow() < (tonumber(untilFn()) or 0) - fade and serverNow() < guard do task.wait() end
		if s then fadeOut(s, fade) end
		if not alive() then return end
		local u = tonumber(untilFn()) or serverNow()
		local d = u - serverNow()
		if d > 0.005 then task.wait(d) end
		if alive() then startPart(endE, m, u, false) end
	end)
end
local hookedTheri = setmetatable({}, {__mode = "k"})
local function hookTheri(m)
	if hookedTheri[m] or not m:IsA("Model") then return end
	hookedTheri[m] = true
	local function n(k, d) return tonumber(m:GetAttribute(k)) or d end
	local function on(attr, fn)
		m:GetAttributeChangedSignal(attr):Connect(function()
			local t = m:GetAttribute(attr)
			if typeof(t) == "number" and theriOn() then fn(t) end
		end)
	end
	on("TheriReelAt", function(t) -- Reaper's Hook
		local brace, fly, reel = n("TheriReelBrace", 0.3), n("TheriReelFly", 0.22), n("TheriReelTime", 0)
		partAt("zhookfire", m, t + brace)
		if m:GetAttribute("TheriReelResult") == "hit" and reel > 0 then
			local finish = t + brace + fly + reel
			partAt("zhookwinch", m, t + brace + fly, finish)
			partAt("zhookslash", m, finish)
		end
	end)
	on("TheriVortexAt", function(t) -- Reaper Vortex
		partAt("zvortexstart", m, t)
		loopPart(m, "zvortexloop", "zvortexend", n("TheriVortexStart", t + 0.95),
			function() return m:GetAttribute("TheriFieldUntil") end,
			function() return m.Parent ~= nil and m:GetAttribute("TheriVortexAt") == t end)
	end)
	on("TheriBolaAt", function(t) partAt("zbolathrow", m, t) end) -- Bola
	on("TheriBolaHitAt", function(t)
		local target = findDino(m:GetAttribute("TheriSnareHitTarget"))
		partAt("zbolahit", target or m:GetAttribute("TheriBolaEnd"), t)
	end)
	on("TheriDashAt", function(t) -- Dash
		if m:GetAttribute("TheriDashResult") == "dash" then partAt("zdash", m, t) end
	end)
	on("TheriFeatherAt", function(t) -- Feather Barrage (the volley)
		if m:GetAttribute("TheriFeatherVolley") == true then partAt("zvolley", m, t) end
	end)
	on("TheriVolleyLandedAt", function(t)
		local k = 0
		for name in string.gmatch(tostring(m:GetAttribute("TheriVolleyLanded") or ""), "([^|=]+)=[^|]*") do
			local target = findDino(name)
			if target and k < num("GameSoundsTheriHitMax", 6) then
				k += 1
				partAt("zvolleyhit", target, t)
			end
		end
	end)
	on("TheriDeflectAt", function(t) -- Deflector Claws (Shield Wall)
		partAt("zwallup", m, t)
		loopPart(m, "zwallloop", "zwalldown", t + num("GameSoundsTheriWallLoopAt", 0.15),
			function() return m:GetAttribute("TheriDeflectUntil") end,
			function() return m.Parent ~= nil and m:GetAttribute("TheriDeflectAt") == t end)
	end)
	on("TheriDeflectBlockAt", function(t) partAt("zwallblock", m, t) end)
end
-- v1.10 the Tenontosaurus' ability sounds, each part on its animation beat (header) ------------------------------------------
local hookedTeno = setmetatable({}, {__mode = "k"})
local function hookTeno(m)
	if hookedTeno[m] or not m:IsA("Model") then return end
	hookedTeno[m] = true
	local function n(k, d) return tonumber(m:GetAttribute(k)) or d end
	local function on(attr, fn)
		m:GetAttributeChangedSignal(attr):Connect(function()
			local t = m:GetAttribute(attr)
			if typeof(t) == "number" and tenoOn() then fn(t) end
		end)
	end
	on("TenoGrabStartedAt", function(t) -- Tail Grab
		partAt("tngrabwind", m, t)
		local lead = num("GameSoundsTenoStrikeLead", 0.15)
		local c, w = n("TenoGrabCatchAt", 0), n("TenoGrabThrowAtPlan", 0)
		if c >= t then partAt("tngrabsnap", m, c - lead) end
		if w >= t then partAt("tngrabthrow", m, w - lead) end
	end)
	on("TenoGrabLandAt", function(t) partAt("tngrabland", m:GetAttribute("TenoGrabLand"), t) end)
	on("TenoMortarStartedAt", function(t) partAt("tnmortarbrace", m, t) end) -- Boulder Mortar
	on("TenoMortarFiredAt", function(t) partAt("tnmortarfire", m, t) end)
	on("TenoMortarLandedAt", function(t)
		partAt("tnmortarboom", m:GetAttribute("TenoMortarLand"), t, nil, num("GameSoundsBlastRange", 400), num("GameSoundsBlastNear", 20))
	end)
	on("TenoStompStartedAt", function(t) partAt("tnstomprear", m, t) end) -- Stomp Shockwave
	on("TenoStompAt", function(t) partAt("tnstompsmash", m, t) end)
	on("TenoBellowStartedAt", function(t) -- Herd Bellow
		partAt("tnbellowinhale", m, t)
		partAt("tnbellowshriek", m, t + num("GameSoundsTenoShriekAt", 0.40))
	end)
	on("TenoChallengeStartedAt", function(t) partAt("tnchallenge", m, t) end) -- Challenge Call
	on("JumpStartedAt", function(t) -- Hydraulic Leap on JUMP: the lift-off after the crouch
		if m:GetAttribute("TenoLeapOnJump") == true and m:GetAttribute("TenoLeapEnabled") == true then
			partAt("tnleaplaunch", m, t + n("JumpWindup", 0.12))
		end
	end)
	on("TenoLeapStartedAt", function(t) partAt("tnleaplaunch", m, t) end) -- the button path
	local lastLand = -math.huge
	local function land(t)
		if math.abs(t - lastLand) < num("GameSoundsTenoLandDedupe", 1) then return end
		lastLand = t
		partAt("tnleapland", m, t)
	end
	on("TenoLeapLandedAt", land)
	if m == player.Character then on("TenoLocalLandAt", land) end
	on("TenoMudStartedAt", function(t) partAt("tnshieldup", m, t) end) -- Shield Armor
	on("TenoMudCoatAt", function(t)
		loopPart(m, "tnshieldloop", "tnshielddown", t,
			function() return m:GetAttribute("TenoMudUntil") end,
			function() return m.Parent ~= nil and m:GetAttribute("TenoMudCoatAt") == t end)
	end)
	on("TenoMudBlockAt", function(t) partAt("tnshieldblock", m, t) end)
end
-- v1.14 the Pachy's Grappling Hook, each part on its beat (header)
local hookedPachyHook = setmetatable({}, {__mode = "k"})
local function hookPachyHook(m)
	if hookedPachyHook[m] or not m:IsA("Model") then return end
	hookedPachyHook[m] = true
	m:GetAttributeChangedSignal("HookStartedAt"):Connect(function()
		local t = m:GetAttribute("HookStartedAt")
		if typeof(t) ~= "number" or not pachyOn() then return end
		local launch = tonumber(m:GetAttribute("HookLaunchAt")) or t
		if launch < t then launch = t end
		partAt("phookfire", m, launch - num("GameSoundsPachyHookLead", 0.15))
		local contact, smash = tonumber(m:GetAttribute("HookContactAt")) or 0, tonumber(m:GetAttribute("HookSmashAt")) or 0
		if m:GetAttribute("HookResult") == "hit" and contact >= t and smash > contact then
			partAt("phookreel", m, contact, smash)
			partAt("phbhit", m, smash)
		end
	end)
end
-- v1.15 the rest of the Pachy's parts, each on its beat (header)
local hookedPachyParts = setmetatable({}, {__mode = "k"})
local function hookPachyParts(m)
	if hookedPachyParts[m] or not m:IsA("Model") then return end
	hookedPachyParts[m] = true
	local function n(k, d) return tonumber(m:GetAttribute(k)) or d end
	local function on(attr, fn)
		m:GetAttributeChangedSignal(attr):Connect(function()
			local t = m:GetAttribute(attr)
			if typeof(t) == "number" and pachyOn() then fn(t) end
		end)
	end
	on("ServoDashStartedAt", function(t) -- Servo Dash
		local blast = n("ServoDashBlastAt", t)
		if blast < t then blast = t end
		partAt("pdashblast", m, blast - num("GameSoundsPachyDashBlastLead", 0.06))
		loopPart(m, "pdashburn", "pdashsteam", blast + num("GameSoundsPachyDashBurnAt", 0.25),
			function() return m:GetAttribute("ServoDashUntil") end,
			function() return m.Parent ~= nil and m:GetAttribute("ServoDashStartedAt") == t end)
	end)
	on("VisorStartedAt", function(t) -- Dome Visor
		partAt("pvisorup", m, t)
		loopPart(m, "pvisorfield", "pvisordown", t + num("GameSoundsPachyVisorFieldAt", 0.10),
			function() return m:GetAttribute("VisorUntil") end,
			function() return m.Parent ~= nil and m:GetAttribute("VisorStartedAt") == t end)
	end)
	on("VisorBlockAt", function(t) partAt("pvisorblock", m, t) end)
	on("InkStartedAt", function(t) -- Ink Shooter
		local fire = n("InkFireAt", t)
		if fire < t then fire = t end
		partAt("pinkfire", m, math.max(t, fire - num("GameSoundsPachyInkLead", 0.10)))
	end)
	on("InkArriveAt", function(t) -- stamped when the shot resolves (after InkStartedAt)
		if t < n("InkStartedAt", math.huge) then return end
		local where = m:GetAttribute("InkAimEnd")
		partAt("pinksplat", typeof(where) == "Vector3" and where or m, t)
	end)
	local lastCock = -math.huge -- Tether Spike
	local function cock(t)
		if math.abs(t - lastCock) < num("GameSoundsPachyCockDedupe", 0.5) then return end
		lastCock = t
		partAt("ptethercock", m, t)
	end
	on("TetherAimAt", cock)
	if m == player.Character then
		on("TetherAimLocalAt", cock)
		m:GetAttributeChangedSignal("TetherAiming"):Connect(function()
			if m:GetAttribute("TetherAiming") == true and pachyOn() then cock(serverNow()) end
		end)
	end
	on("TetherStartedAt", function(t)
		partAt("ptetherthrow", m, t)
		local land = n("TetherLandAt", 0)
		if land >= t then partAt("ptetherland", m, land) end
	end)
	on("HeadbuttSacrificeAt", function(t) partAt("pbloodpact", m, t) end) -- Blood Rush
	on("MedDroppedAt", function(t) -- Med-Station: where the dino was at the drop
		local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
		local spot = (root and root:IsA("BasePart")) and root.Position or m
		partAt("pmeddrop", spot, t)
		local alive = function() return m.Parent ~= nil and m:GetAttribute("MedDroppedAt") == t end
		local loopAt = t + num("GameSoundsPachyMedHumAt", 0.60)
		task.spawn(function() -- loopPart plays at a dino; the station stays put, so the same loop at the spot
			while alive() and serverNow() < loopAt and serverNow() < n("MedActiveUntil", 0) do task.wait() end
			if not alive() then return end
			local fade = num("GameSoundsTheriLoopFade", 0.08)
			local s = (serverNow() < n("MedActiveUntil", 0)) and startPart("pmedhum", spot, loopAt, true) or nil
			local guard = serverNow() + 60
			while alive() and serverNow() < n("MedActiveUntil", 0) - fade and serverNow() < guard do task.wait() end
			if s then fadeOut(s, fade) end
			if not alive() then return end
			local u = n("MedActiveUntil", serverNow())
			local d = u - serverNow()
			if d > 0.005 then task.wait(d) end
			if alive() then startPart("pmedfold", spot, u, false) end
		end)
	end)
end
-- v1.18 the Raptor's buttons, each on its beat (header)
local hookedRaptor = setmetatable({}, {__mode = "k"})
local function hookRaptorParts(m)
	if hookedRaptor[m] or not m:IsA("Model") then return end
	hookedRaptor[m] = true
	local function n(k, d) return tonumber(m:GetAttribute(k)) or d end
	local function on(attr, fn)
		m:GetAttributeChangedSignal(attr):Connect(function()
			local t = m:GetAttribute(attr)
			if typeof(t) == "number" and raptorOn() then fn(t) end
		end)
	end
	on("CloakStartedAt", function(t) partAt("rcloakon", m, t) end) -- Cloak Field
	m:GetAttributeChangedSignal("CloakState"):Connect(function()
		if m:GetAttribute("CloakState") == "off" and raptorOn() and serverNow() - n("CloakStartedAt", -math.huge) < 120 then
			partAt("rcloakoff", m, serverNow())
		end
	end)
	on("EnergyShieldStartedAt", function(t) -- Energy Shield
		partAt("rshieldup", m, t)
		loopPart(m, "rshieldhum", "rshielddown", t + num("GameSoundsRaptorShieldHumAt", 0.10),
			function() return m:GetAttribute("EnergyShieldUntil") end,
			function() return m.Parent ~= nil and m:GetAttribute("EnergyShieldStartedAt") == t end)
	end)
	on("EnergyShieldBlockAt", function(t) partAt("rshieldblock", m, t) end)
	on("AdrenalineStartedAt", function(t) -- Adrenaline Injector
		partAt("radreninject", m, t)
		loopPart(m, "radrenrush", "radrenend", t + num("GameSoundsRaptorRushAt", 0.30),
			function() return m:GetAttribute("AdrenalineUntil") end,
			function() return m.Parent ~= nil and m:GetAttribute("AdrenalineStartedAt") == t end)
	end)
	on("ScreechStartedAt", function(t) partAt("rcannonfire", m, t) end) -- Shock Cannon: the shot
	on("ScreechHitAt", function(t) partAt("rcannonhit", m, t) end) -- ... and the hit, on the dino that was hit
	if m == player.Character then
		local charge
		m:GetAttributeChangedSignal("MechaScreechAim"):Connect(function() -- your own aim (client-side)
			if m:GetAttribute("MechaScreechAim") == "aiming" and raptorOn() then
				if charge and charge.Parent then return end -- already charging (MechaButtons sets "aiming" twice)
				local s = startPart("rcannoncharge", m, serverNow(), true)
				charge = s
				if s then task.delay(num("GameSoundsRaptorChargeMax", 10), function() if charge == s then fadeOut(s, 0.1) charge = nil end end) end
			elseif charge then
				fadeOut(charge, num("GameSoundsTheriLoopFade", 0.08))
				charge = nil
			end
		end)
		on("ScentStartedAt", function(t) -- Scent Sense: you only
			partAt("rscentsniff", m, t)
			loopPart(m, "rscentaura", "rscentend", t + num("GameSoundsRaptorAuraAt", 0.60),
				function() return m:GetAttribute("ScentUntil") end,
				function() return m.Parent ~= nil and m:GetAttribute("ScentStartedAt") == t end)
		end)
	end
end
-- v1.12 the Pachy's jump: at the lift-off (JumpStartedAt + JumpWindup)
local hookedPachyJump = setmetatable({}, {__mode = "k"})
local function hookPachyJump(m)
	if hookedPachyJump[m] or not m:IsA("Model") then return end
	hookedPachyJump[m] = true
	m:GetAttributeChangedSignal("JumpStartedAt"):Connect(function()
		local t = m:GetAttribute("JumpStartedAt")
		if typeof(t) ~= "number" or m:GetAttribute("Species") ~= "Pachy" then return end
		local d = t + (tonumber(m:GetAttribute("JumpWindup")) or 0.12) - workspace:GetServerTimeNow()
		if d > 0.005 then task.delay(d, play3D, "pjump", m) elseif d > -0.3 then play3D("pjump", m) end -- later than 0.3 s: skipped
	end)
	local lastDouble = -math.huge -- v1.13 the double jump
	local function double(attr)
		local t = m:GetAttribute(attr)
		if typeof(t) ~= "number" or m:GetAttribute("Species") ~= "Pachy" then return end
		if math.abs(t - lastDouble) < num("GameSoundsPachyDoubleDedupe", 0.5) then return end
		if workspace:GetServerTimeNow() - t > 0.3 then return end
		lastDouble = t
		play3D("pjump", m)
	end
	m:GetAttributeChangedSignal("JumpDoubleAt"):Connect(function() double("JumpDoubleAt") end)
	if m == player.Character then
		m:GetAttributeChangedSignal("JumpDoublePredictedAt"):Connect(function() double("JumpDoublePredictedAt") end)
	end
end
local hookedAbility = setmetatable({}, {__mode = "k"})
local function hookAbility(m)
	if hookedAbility[m] or not m:IsA("Model") then return end
	hookedAbility[m] = true
	hookTheri(m) -- v1.9
	hookTeno(m) -- v1.10
	hookPachyJump(m) -- v1.12
	hookPachyHook(m) -- v1.14
	hookPachyParts(m) -- v1.15
	hookRaptorParts(m) -- v1.18
	for e, attr in pairs(ABILITY) do
		m:GetAttributeChangedSignal(attr):Connect(function()
			if typeof(m:GetAttribute(attr)) == "number" then play3D(e, m) end
		end)
	end
	if m == player.Character then
		m:GetAttributeChangedSignal("ScentStartedAt"):Connect(function()
			if typeof(m:GetAttribute("ScentStartedAt")) == "number" and not raptorOn() then play("scent") end -- v1.18: off while the beat-timed scent plays
		end)
	end
end
local function watchAbility(pl)
	pl.CharacterAdded:Connect(hookAbility)
	if pl.Character then hookAbility(pl.Character) end
end
Players.PlayerAdded:Connect(watchAbility)
for _, pl in ipairs(Players:GetPlayers()) do watchAbility(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 60)
	local bots = isl and isl:WaitForChild("Bots", 60)
	if not bots then return end
	bots.ChildAdded:Connect(hookAbility)
	for _, b in ipairs(bots:GetChildren()) do hookAbility(b) end
end)

-- v1.5 the Cruise Missile blast: 3D at CruiseBoomPos --------------------------------------------------------------------------
local function playAt(e, pos, maxDist, minDist) -- v1.8: optional range (default the blast range)
	if TENO_OLD[e] and tenoOn() then return end -- v1.10
	if script:GetAttribute("GameSoundsEnabled") == false or script:GetAttribute("GameSounds_" .. e .. "Enabled") == false then return end
	if player:GetAttribute("InMenu") == true then return end
	if typeof(pos) ~= "Vector3" then return end
	group.Volume = num("GameSoundsVolume", 1)
	local tpl = template(e)
	script:SetAttribute("GameSoundsLast", e)
	script:SetAttribute("GameSoundsLast3D", e .. ":" .. string.format("%.0f,%.0f,%.0f", pos.X, pos.Y, pos.Z))
	script:SetAttribute("GameSoundsCount_" .. e, (script:GetAttribute("GameSoundsCount_" .. e) or 0) + 1)
	if not tpl then return end
	local a = Instance.new("Attachment")
	a.Name = "GameSounds_" .. e .. "_At"
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local s = tpl:Clone()
	s.RollOffMaxDistance = maxDist or num("GameSoundsBlastRange", 400)
	s.RollOffMinDistance = minDist or num("GameSoundsBlastNear", 20)
	s.Parent = a
	s:Play()
	Debris:AddItem(a, math.max(tpl.TimeLength, 1) + 0.5)
end
local hookedBlast = setmetatable({}, {__mode = "k"})
local function hookBlast(m)
	if hookedBlast[m] or not m:IsA("Model") then return end
	hookedBlast[m] = true
	m:GetAttributeChangedSignal("CruiseBoomAt"):Connect(function()
		if typeof(m:GetAttribute("CruiseBoomAt")) == "number" then playAt("hcmboom", m:GetAttribute("CruiseBoomPos")) end
	end)
	m:GetAttributeChangedSignal("TenoGrabLandAt"):Connect(function() -- v1.8: where the flung dino lands
		if typeof(m:GetAttribute("TenoGrabLandAt")) == "number" then
			playAt("tgrabland", m:GetAttribute("TenoGrabLand"), num("GameSoundsAbilityRange", 200), num("GameSoundsAbilityNear", 10))
		end
	end)
	m:GetAttributeChangedSignal("TenoMortarLandedAt"):Connect(function() -- v1.8: the boulder impact
		if typeof(m:GetAttribute("TenoMortarLandedAt")) == "number" then playAt("tmortarboom", m:GetAttribute("TenoMortarLand")) end
	end)
end
local function watchBlast(pl)
	pl.CharacterAdded:Connect(hookBlast)
	if pl.Character then hookBlast(pl.Character) end
end
Players.PlayerAdded:Connect(watchBlast)
for _, pl in ipairs(Players:GetPlayers()) do watchBlast(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 60)
	local bots = isl and isl:WaitForChild("Bots", 60)
	if not bots then return end
	bots.ChildAdded:Connect(hookBlast)
	for _, b in ipairs(bots:GetChildren()) do hookBlast(b) end
end)

-- kill (any dino's KilledAt with you as the killer) ------------------------------------------------------------------------
local killSeen = setmetatable({}, {__mode = "k"})
local hookedKill = setmetatable({}, {__mode = "k"})
local function hookKill(m)
	if hookedKill[m] or not m:IsA("Model") then return end
	hookedKill[m] = true
	m:GetAttributeChangedSignal("KilledAt"):Connect(function()
		task.wait() -- KilledBy / KilledByUserId can land after KilledAt in the same update; read them a frame later
		local at = m:GetAttribute("KilledAt")
		if at == nil or killSeen[m] == at then return end
		local by, byId = m:GetAttribute("KilledBy"), m:GetAttribute("KilledByUserId")
		if by == player.Name or (tonumber(byId) or 0) == player.UserId then
			killSeen[m] = at
			play("kill")
		end
	end)
end
local function watchPlayer(pl)
	pl.CharacterAdded:Connect(hookKill)
	if pl.Character then hookKill(pl.Character) end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, pl in ipairs(Players:GetPlayers()) do watchPlayer(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 60)
	local bots = isl and isl:WaitForChild("Bots", 60)
	if not bots then return end
	bots.ChildAdded:Connect(hookKill)
	for _, b in ipairs(bots:GetChildren()) do hookKill(b) end
end)

-- menu clicks ---------------------------------------------------------------------------------------------------------------
local clickHooked = setmetatable({}, {__mode = "k"})
local function clickGuiNamed(name)
	for n in string.gmatch(tostring(script:GetAttribute("GameSoundsClickGuis") or ""), "[^,%s]+") do
		if n == name then return true end
	end
	return false
end
local function hookButton(b)
	if clickHooked[b] or not b:IsA("GuiButton") then return end
	local sg = b:FindFirstAncestorWhichIsA("LayerCollector")
	if not (sg and clickGuiNamed(sg.Name)) then return end
	clickHooked[b] = true
	b.Activated:Connect(function() play("click", true) end)
end
task.spawn(function()
	local pg = player:WaitForChild("PlayerGui")
	pg.DescendantAdded:Connect(function(d) task.defer(hookButton, d) end) -- a ScreenGui can be named after it is parented
	for _, d in ipairs(pg:GetDescendants()) do hookButton(d) end
end)

-- hardpoint: point, countdown, GO, win / lose -------------------------------------------------------------------------------
task.spawn(function()
	local hp = ReplicatedStorage:WaitForChild("Hardpoint", 120)
	if not hp then return end
	local lastOcc = {}
	local VOICE = {captured = "vosecured", lost = "volost", contested = "vocontested"} -- v1.16
	local voiceSeq, voiceLast, voiceAt = 0, nil, -math.huge
	hp:GetAttributeChangedSignal("HpIndex"):Connect(function() voiceLast = nil end) -- a new spot: any line may be said again
	hp:GetAttributeChangedSignal("HpOcc"):Connect(function()
		voiceSeq += 1 -- v1.16: any change cancels a pending callout
		if hp:GetAttribute("HpPhase") ~= "live" then return end
		local team = player:GetAttribute("HardpointTeam")
		if team ~= "A" and team ~= "B" then return end
		local occ = hp:GetAttribute("HpOcc")
		local e = (occ == team and "captured") or (occ == "C" and "contested") or ((occ == "A" or occ == "B") and "lost") or nil
		if not e then return end
		if script:GetAttribute("GameSoundsPointVoiceEnabled") ~= false then -- v1.16: the announcer, once it has settled
			local my, line = voiceSeq, VOICE[e]
			task.spawn(function()
				local function holds() return my == voiceSeq and hp:GetAttribute("HpPhase") == "live" and hp:GetAttribute("HpOcc") == occ end
				task.wait(num("GameSoundsVoiceSettle", 1))
				while holds() and os.clock() - voiceAt < num("GameSoundsVoiceGap", 4) do task.wait(0.1) end
				if not holds() or line == voiceLast then return end
				voiceLast, voiceAt = line, os.clock()
				play(line)
			end)
			return
		end
		if os.clock() - (lastOcc[e] or -math.huge) < num("GameSoundsOccGap", 1) then return end
		lastOcc[e] = os.clock()
		play(e)
	end)
	local prevPhase = hp:GetAttribute("HpPhase")
	hp:GetAttributeChangedSignal("HpPhase"):Connect(function()
		local ph = hp:GetAttribute("HpPhase")
		if prevPhase == "warmup" and ph == "live" then play("go") end
		if ph == "results" and prevPhase ~= "results" then
			local team, w = player:GetAttribute("HardpointTeam"), hp:GetAttribute("HpWinner")
			if (team == "A" or team == "B") and (w == "A" or w == "B") then play(w == team and "win" or "lose", true) end
		end
		prevPhase = ph
	end)
	local warnedIndex, lastTick = nil, nil
	local introFor, introLast = nil, nil -- v1.17
	RunService.Heartbeat:Connect(function()
		local ph = hp:GetAttribute("HpPhase")
		local ends = tonumber(hp:GetAttribute("HpPointEndsAt"))
		if not ends then return end
		local left = ends - workspace:GetServerTimeNow()
		if ph == "warmup" and introFor ~= ends and script:GetAttribute("GameSoundsIntroEnabled") ~= false -- v1.17 the intro line
			and left <= num("GameSoundsIntroAt", 9) then
			introFor = ends
			if left >= num("GameSoundsIntroAt", 9) - num("GameSoundsIntroLate", 0.5) then
				local pool = {}
				for e in string.gmatch(tostring(script:GetAttribute("GameSoundsIntroLines") or ""), "[^,%s]+") do table.insert(pool, e) end
				local ok = {}
				for _, e in ipairs(pool) do if e ~= introLast then table.insert(ok, e) end end
				if #ok == 0 then ok = pool end
				if #ok > 0 then
					introLast = ok[math.random(1, #ok)]
					play(introLast)
				end
			end
		end
		if ph == "warmup" then
			local s = math.ceil(left)
			if s >= 1 and s <= num("GameSoundsTickFrom", 3) and s ~= lastTick then play("tick") end
			lastTick = s
		else
			lastTick = nil
		end
		if ph == "live" then
			local idx = hp:GetAttribute("HpIndex")
			if left > 0 and left <= num("GameSoundsMoveWarn", 5) and warnedIndex ~= idx then
				warnedIndex = idx
				play("moving")
			end
		end
	end)
end)
