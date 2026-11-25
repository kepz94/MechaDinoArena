# Mecha Dino Arena page video, plan v0.1 (2026-11-25)

Full plan (research, storyboard, camera playbook, rules, production): Claude Doc "Mecha Dino Arena Trailer Plan"
(https://claude.ai/artifact/1eg4g5yYmGXTysA1H3o4SR). Kepu 14:24: "make this a professional trailer ... research how other games run
little ads ... copy camera angles and strategies". Status: waiting for Kepu's sign-off; nothing built yet.

Rule of the cut: open on the biggest fight moment (hook under 3 s), gameplay first, cold open -> core idea -> escalation -> style ->
win -> title; 1-3 word captions for sound-off; 30 s max (Roblox video limit), real footage only, no promo text, catalog music only.

| # | Time (s) | Shot (who does it, in code) | Caption |
| --- | --- | --- | --- |
| 1 | 0.0-1.5 | Cruise Missile dive onto the point, blast on the bots (Herrera, part cmissile) | MECHA DINOS |
| 2 | 1.5-3.0 | T-Rex roars at the lens, rings hit two bots, DEF badges (T-Rex RoarEnabled; RoarServer / RoarFX) | 4v4 ARENA |
| 3 | 3.0-5.5 | Teams clash on the hardpoint, score ticking (PracticeServer) | HOLD THE POINT |
| 4 | 5.5-7.0 | Raptor pounce latches onto a bigger bot (PounceServer) | |
| 5 | 7.0-8.5 | Reaper's Hook yank + double slash, kill feed line (Therizino, part zhook) | |
| 6 | 8.5-10.0 | Sonic Hiss knocks back two bots (Dilo, part dhiss) | |
| 7 | 10.0-11.5 | Portal Feathers zip at 5x run speed (Troodon, part oportal) | |
| 8 | 11.5-14.0 | 8 dinos, 0.3 s hero pose each (UniversalSkins.DINOS) | 8 DINOS |
| 9 | 14.0-17.0 | Lab: Shock Cannon, Energy Shield, Thrusters (Raptor parts screech / shield / thrusters) | BUILD YOUR MECHA |
| 10 | 17.0-19.5 | Thrusters boost, Shock Cannon stun, Energy Shield blocks a bite (Raptor) | |
| 11 | 19.5-22.0 | Skin swaps x3, then Rainbow Road run-by | SKINS & TRAILS |
| 12 | 22.0-24.0 | Last capture tick, final KO | |
| 13 | 24.0-27.5 | Victory stage, winner's title (VictoryTitles) | |
| 14 | 27.5-30.0 | Fly through the Arena gate into the logo | logo |

Grounding (live SkillTree in Studio, 2026-11-25; Kepu 14:29 "The t-Rex doesn't have the shock cannon"): the T-Rex has no mecha
parts (bite + roar only); Shock Cannon / Energy Shield / Thrusters are Raptor parts. Practice bots carry no parts
(PracticeRules.BOT_LIVE = {}) and are never T-Rex, so every ability is fired by Kepu's test dino re-spawned per species.

Needs from Kepu: bigger Studio viewport while filming (now 847 x 541); access to
C:\Users\Kepu_\AppData\Local\Roblox\tmp-capture-storage\mcp (or clips copied to Downloads); audio choice; storyboard sign-off.

## Trailer v0.1 cut (2026-11-25)

Kepu 14:33: "1. Yes 2. Go ahead and max the screen ... 4. We won't do audio for now just the clips". Filmed with Windows Game
Bar (Win+Alt+R, 1920x1012 window capture) in Studio Play, practice match (workspace ModeTestPractice) and the island.
Cropped 1344x756 at (235,184) (victory: 1218x685 at (20,252), lab: 1244x700 at (36,230)), scaled to 1920x1080, 30 fps,
H.264, silent, exactly 30.0 s. Captions in Silkscreen Bold (game yellow 255,200,50, ink 26,19,0). File:
C:\Users\Kepu_\Videos\MechaDinoArena_Trailer_v0.1.mp4 (not in the repo).

| # | In (s) | Shot (source recording, seconds) | Caption |
|---|---|---|---|
| 1 | 0.0 | Herrera Cruise Missile dive + impact (14-54-55, 21.3) | MECHA DINOS |
| 2 | 2.7 | Teams clash on the Summit point (14-54-55, 658.6) | 4V4 ARENA |
| 3 | 4.7 | Raptor pounce onto a Pachy bot (14-54-55, 249.3) | |
| 4 | 6.7 | Therizino Reaper's Hook reel (14-54-55, 284.4) | |
| 5 | 8.1 | Dilo Sonic Hiss, two Pachys SILENCED (14-54-55, 355.9) | |
| 6 | 10.0 | Troodon Portal Rift zip (14-54-55, 425.3) | |
| 7 | 12.0 | Roster, 7 dinos x 0.35 s at the gate (14-48-01) | 8 DINOS |
| 8 | 14.6 | Lab, Raptor parts (14-48-01, 65.0) | BUILD YOUR MECHA |
| 9 | 16.8 | Shock Cannon shot (14-54-55, 530.7) | |
| 10 | 18.3 | Thrusters boost up the mountain (14-54-55, 577.0) | |
| 11 | 20.2 | Hellfire, ElementX, then Rainbow Road run (14-43-33, 14-42-45) | SKINS & TRAILS |
| 12 | 22.8 | Crane up over the Summit point (14-54-55, 661.0) | HOLD THE POINT |
| 13 | 25.3 | Victory stage, KING OF THE HILL (14-54-55, 739.6) | |
| 14 | 27.6 | Fly into the Arena gate, MECHA DINO ARENA card | logo |

Dropped from the storyboard: shot 2 T-Rex roar (no readable roar in the takes) and shot 12 final KO.
Filming notes: abilities aim where the camera looks (the dino turns to the camera's flat look), so aimed shots need the
target on the camera's look line; practice bots walk off within ~1 s, so stage them right before the key press.
Studio restored after filming: ModeTestPractice nil, SkillServer SkillTestMaxAllEnabled false, Output + Asset Manager
reopened, window back to the left-half snap.

## Trailer v0.2 angle mockup (2026-11-25 16:00)

Kepu 15:24 rejected v0.1 ("why would you start off with a black and white cruise missile frame"), 15:26 "selling the game,
more cinematic shots", 15:54 "send me the actual damn mockup". Research (his 3 reference clips + AppLovin, Unity, GMTK,
Derek Lieu, Roblox thumbnail rules): open on one big readable subject, film from outside the player, short action cuts
with slower hero beats, captions only say what you do. Moving 15.7 s angle reel (not in the repo):
C:\Users\Kepu_\Videos\trailer_work, source recording 15-54-47. Shots: 1 T-Rex hero push-in (Summit), 2 glitch Raptor +
Rainbow Road tracking, 3 Cruise Missile blast from outside (CruiseThermalEnabled false on HerreraMissileCam for filming
only, client side), 4 T-Rex charge at the lens, 5 slow orbit on Raptor mecha parts, 6 dolly past all 8 dinos (anchored
clones in Workspace.TrailerLineup, Play only). Found: ServerScriptService.RoarServer is disabled in the place, so no roar shot.
