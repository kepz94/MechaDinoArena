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

## Trailer v0.2 cut (2026-11-25 16:50)

Kepu 16:11 order: portal walk-in, island pan with dinos fighting, Lab "unlock dinos and mecha parts" with base-skin dinos
getting full kits, Herrera gliding over the fight, Raptor Shock Cannon following the shot into a Pachy (stunned), Shop with
skins and trails, Raptor in a cool skin doing GG over a dead dino. Cut: 29.2 s, silent, 1920x1080 30 fps,
C:\Users\Kepu_\Videos\MechaDinoArena_Trailer_v0.2.mp4 (not in the repo). Sources: 14-42-04 (portal), 16-18-41 (island 19.6,
glide 113.3, cannon 165.85, Lab 195.5 x4.8, Shop 283.4 / 291.0 / 302.8, GG 487.0). Captions: "UNLOCK DINOS & MECHA PARTS",
"SKINS & TRAILS", end card MECHA DINO ARENA. Lab / Shop shots are the full viewport letterboxed (the 16:9 crop cut the UI).
Filming-only, Play session only (nothing saved): PracticeRequest "newbots" rerolls until a Pachy is on the other team;
ShopScreen script attribute ShopTestShowAll (existing Studio switch) lists owned skins / trails; HerreraMissileCam
CruiseThermalEnabled false; Shock Cannon fired through DinoScreechRequest(stamp, 0, aim) to aim at the Pachy; the GG target's
DummyHealth set to 0 (a practice bot body stays 2 s, PracticeServer BOT_BODY). Restored after: Play stopped,
ModeTestPractice nil, SkillTestMaxAllEnabled false, ShopTestShowAll nil, render quality Automatic, Output + Asset Manager
back, window snapped left. Studio account skins: Raptor set to glitch, Herrera to classic during the shoot.

## Trailer v0.3 cut (2026-11-25 17:08)

Kepu 16:39-16:42: Herrera jumps off the mountain and glides over ~40 dinos fighting across the island, a movie-like sun shot,
cinematic pull-out; Shock Cannon as a GoPro POV on the Raptor that rides the ball into the Pachy; better GG angle; "it doesn't
have to be in a match, do it on the main island". Cut: 29.97 s, silent, C:\Users\Kepu_\Videos\MechaDinoArena_Trailer_v0.3.mp4.
Sources: 14-42-04 (portal), 16-44-56 (island pan 17.5, GG 615.0 punched in 1.25x), 17-00-19 (glide 75.6 x1.45, cannon 140.2
with 140.6-141.5 slowed 2x), 16-18-41 (Lab, Shop). Crowd shot: 39 dinos (clones of each species' practice bot / player
character into Workspace.TrailerCrowd, Play session only) paired up across the island and, for the glide, along its path,
moving with Humanoid:MoveTo and stamping BiteStartedAt / BiteHitAt so the bite poses play. Not saved; Play stopped.
Downed dino in the GG shot: a crowd Pachy anchored on its side. Cannon at 100 studs, aimed via DinoScreechRequest.

## Trailer v0.4 cut (2026-11-25 17:37)

Kepu 17:14: dinos must really fight with combo abilities, better angles, the Lab must zoom in on the mecha part cards with a
highlight while selecting; research how scenes / fights / UI are shot. Research applied: 180-degree line kept per fight (the
camera stays on one side of the two fighters), wide shot to set the scene then medium shots on hits, one fight per shot
(no effect soup), UI shown by isolating one element (zoom / crop, highlight). Cut: 29.7 s, silent,
C:\Users\Kepu_\Videos\MechaDinoArena_Trailer_v0.4.mp4. Source recording 17-19-47 (+ 14-42-04 portal, 17-00-19 glide / cannon).
Fights: 32 dinos (clones of practice bots, Workspace.DinoIsland.Bots, Play only) in 16 pairs; each uses its REAL main attack
(PracticeBrain.ATTACK[species].fire) and REAL mecha parts through PracticeKit.useNow (the servers' BotMechaUse entrances),
ordered mobility > control > damage, every 2.5-4 s, health topped up under 35%. Not saved. Lab / Shop: tools/trailer/uicam.py
renders a virtual camera (keyframed centre + width, smoothstep) over the recorded UI and draws a yellow pop-in highlight box on
the card being picked. PracticeServer PracticeTeamSize was set to 5 for the shoot and cleared after (nil = code default 4).

## Trailer v0.5 cut (2026-11-25 18:26)

Kepu 17:46 / 17:49: gameplay looked glitchy and jumpy, shots unreadable to someone new to the game, the Raptor cannon angle
did not show where the shot came from, the GG angle was bad and the Glitch skin is hard to see. Causes found: Game Bar was
recording at 30 fps (now 60 fps, quality High, Kepu option "3"); bot mecha part FX only render for player characters (the
*FX client scripts watch Players only), so v0.4 fights showed moves with no effects. Cut: 28.9 s, silent, 1920x1080 30 fps,
C:\Users\Kepu_\Videos\MechaDinoArena_Trailer_v0.5.mp4 (not in the repo). Sources: 18-07-18 (battle, hero fight, cannon, GG;
file time = Studio clock - 18:07:14.3) and 18-14-22 (glide), v0.4 portal / Lab / Shop renders. Shot order: portal, battle
wide, battle medium, Teno leaps on a Dilo, Lab (UNLOCK DINOS & MECHA PARTS), Herrera leaves the mountain, Herrera crosses
the sun, Herrera over the battle, pull-out, Lava Raptor fires the Shock Cannon (side-on, both dinos in frame), ball ride into
the Pachy at 0.5x with the stun, Shop (SKINS & TRAILS), Lava Raptor GG over a downed Pachy (low 3/4 front), logo.
Filming-only (Play session, nothing saved to the place): runtime copies of 15 FX LocalScripts (CINE_<name>) with their
Players.PlayerAdded / GetPlayers hooks pointed at Workspace.DinoIsland.Bots TC_ / TH_ models so bot moves show FX; 24 bots
in 12 pairs (Studio 33 fps with them moving, 55 fps paused); practice match bots parked in ServerStorage; hero fights and
cannon on the meadow at (-95, 268); HardpointHUD script attribute HardpointHUDMarkerFeedGap false (stops an error spam while
the HUD is hidden). Account changes during the shoot: SkillSlot1 set to screech for the cannon, then cleared back to empty;
species switched to Herrera for the glide, then back to Raptor; Raptor skin stays lava. Restored after: Play stopped,
ModeTestPractice nil, SkillTestMaxAllEnabled false (checked), quality Automatic, Output + Asset Manager side by side again,
window snapped left. Game Bar left at 60 fps / High.

## Trailer v0.6 cut (2026-11-25 18:47)

Kepu 18:30 / 18:32: cut the Teno jumping on the Dilo; the Lab should equip the obvious parts (Shock Cannon, Adrenaline,
Thrusters on the Raptor); rework the Herrera jump transitions; the cannon shot had a second Pachy walking through it, went by
too fast, and did not follow the ball to the Pachy; the stare-down could be quicker. Cut: 29.3 s, silent,
C:\Users\Kepu_\Videos\MechaDinoArena_Trailer_v0.6.mp4 (not in the repo). New sources: 18-33-14 (Lab), 18-39-24 (cannon,
glide; file time = Studio clock - 18:39:19.8). Order: portal, battle wide, battle medium, Lab (base green Raptor: Adrenaline
Injector, Shock Cannon, Thrusters, each card highlighted then the part on the dino; uicam.py on a 30 fps resample),
Herrera on the summit leaps and the camera swings into the sun in one move (offsets blended over 1.3 s), white flash, over
the battle (v0.5 clip), pull-out over the battle, cannon: 0.7 s side-rear shot with the cannon on the shoulder, ball ride at
0.35x (minterpolate to 30 fps) all the way into the Pachy, 0.85 s of the stun at normal speed; Shop, GG (v0.5), logo
(cross-blur from the GG frame, no black frame). Cannon set: target Pachy 80 studs away on the meadow at z 268, a scan for
any other humanoid model in the lane before the take, practice bots parked. Shock Cannon recharge is longer than 9 s, so
takes 9 s apart were refused; only every other take fired.
Filming-only (Play session): practice match bots cloned into ServerStorage.TrailerBots across 3 rerolls (13 templates), the
crowd director, FX watcher copies, HUD hidden by reparenting ScreenGuis, SkillServer SkillTestMaxAllEnabled true (for the
Herrera glider slot). Account changes during the shoot: Raptor skin set to classic for the Lab then back to lava; Lab
equipped adrenaline / screech / thrusters, all three Raptor slots cleared again after; species Herrera for the glide, back
to Raptor. Restored after: SkillTestMaxAllEnabled false, Play stopped, ModeTestPractice nil, quality Automatic, Output +
Asset Manager back, window snapped left.

## Trailer v0.7 cut (2026-11-25 19:10)

Kepu 18:52 (screen recording of 7 Roblox game-page previews: PLS Donate, Ant Evolution, My Hero Academia Ultimate, Crazy 8
Ball, Territories, Fallen Survival, Hoop Jam): gameplay comes first; open on a Raptor with its mecha parts highlighted in
close camera sweeps, then it jumps into battle, then cuts (battles, equipping parts, etc.). Observed in the recording: 6 of 7
previews are in gameplay within ~0.7 s; the preview plays muted at about a third of the phone screen and is scrolled past
after 5-10 s; one large subject per frame; 1-2 s shots with a moving camera; real HUD kept. Kepu picks (19:00): part callout
= in-game outline + short label; keep Lab, Herrera glide, Shop, GG + logo.
Cut: 29.7 s, silent, C:\Users\Kepu_\Videos\MechaDinoArena_Trailer_v0.7.mp4 (not in the repo). New source 18-59-30 (file time
= Studio clock - 18:59:26.3). Order: Lava Raptor close sweeps with a gold Highlight (Roblox Highlight on the part model,
Occluded, faded in / out) and a tag (Silkscreen 700, gold on dark, bottom left): SHOCK CANNON, ADRENALINE, THRUSTERS (with a
far depth-of-field blur); Thrusters boost (DinoDashRequest, real hop) into the battle, camera trailing; two close fight
cuts (Troodon dome / lantern vs Pachy, Therizino harvest field vs Dilo); cannon side-rear, ball ride, stun (v0.6); Lab
(v0.6, trimmed to 4.8 s); Herrera summit leap into the sun (v0.6), white flash, pull-out over the battle; Shop (3.0 s); GG;
logo. Removed: portal and island crane / lateral battle shots.
Filming-only (Play session): same TrailerBots / crowd director / FX watcher copies as v0.6; Lighting DepthOfFieldEffect
"CINE_DOF" (Play only, gone after stop). Account: Raptor slots set to adrenaline / screech / thrusters for the shoot and
cleared after. Restored after: Play stopped, ModeTestPractice nil, SkillTestMaxAllEnabled false (checked), quality
Automatic, Output + Asset Manager back, window snapped left.

## Official trailer (2026-11-25 19:15)

Kepu 19:15: "This is perfect. This is our official trailer." Official = Trailer v0.7, C:\Users\Kepu_\Videos\
MechaDinoArena_Trailer_v0.7.mp4 (29.7 s, 1920x1080 30 fps, silent). Audio not added yet. Not uploaded to the game page
(Kepu uploads).

## Trailer v0.8 cut (2026-11-25 20:40)

Kepu 20:26: better cinematic angles for the Raptor's Thrusters dash into battle, a camera swing to a front-ish view; v0.7 only
showed the fire from behind. Change: the v0.7 hop shot (p4h, 2.8 s) is replaced by a swing shot of the same length; every
other shot is unchanged. 29.7 s, silent, C:\Users\Kepu_\Videos\MechaDinoArena_Trailer_v0.8.mp4 (not in the repo).
Shot: real dash (DinoDashRequest) from (-5, 178) facing -Z. Measured flight: airborne ~1.0 s, ground at z 72 to -22, stops at
about (-9, -22) after 2.0 s. Camera orbits the Torso centre (average of the Torso BaseParts), looks 40% of the way to the Head
centre, distance 18 to 18, height 3 to 2, FOV 55, yaw from 25 deg (behind-right) to 150 deg (front 3/4) with smoothstep from
1.0 s to 2.5 s after the take starts (dash fires at 0.8 s), spring half-life 0.04 s. Camera pulls in front of any solid part
or bot between it and the Raptor. Pick: recording 20-38-17, take 5, 22.25 s to 25.05 s: side flight with the rainbow trail
over the battle, swing to the front on landing, crowd behind. Takes 1-4 dropped (camera clipped through bots, dull skin
phase, target ring overhead, shield dome lines).
Filming-only (Play session): crowd director pairs 5, 7 and 10 moved off the landing path to (-42, 52), (32, 22), (-50, -30);
player kept at full health (DummyHealth, StatDamageTakenMul 0) by a server loop. Restored after: Raptor slots empty, Play
stopped, ModeTestPractice nil, SkillTestMaxAllEnabled false (checked), Output + Asset Manager back, window snapped left.
