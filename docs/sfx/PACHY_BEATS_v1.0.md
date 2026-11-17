# Pachy sound beat sheet v1.0 (MDA-552, sound pass round 11)

The beats the Pachy sounds get rebuilt to, read from the game (HookServer, ServoDashServer 1.2, VisorServer, InkServer 1.7,
TetherServer 1.5, HeadbuttServer, MedStationServer 1.3, BoneCrest 1.6; PachyMovesPose 1.1) and the storyboard
(tools/mockup/pachy_moves_anim.js, the A versions: Kepu 2026-11-05 "A for everything"). Times: seconds after the press. The
live sounds (GameSounds 1.7: phook, pink, pmed, pdash, ptether, pvisor, pblood) are one sound per stamp, not split at these beats.

| Move | Game beats (stamps) | Storyboard A | Parts (schedule point: beats inside the clip) |
|---|---|---|---|
| Grappling Hook | brace 0..WINDUP 0.15; claw flies at HookLaunchAt; grabs at HookContactAt (= launch + distance / 220); pull 0.5 s; head smash at HookSmashAt (hit only; miss: the claw comes back) | brace 0–0.15, flies 0.15–0.29 (30 studs), reels 0.29–0.79, smash 0.79 | fire @ HookLaunchAt − 0.15 (shot ON 0.15) · reel @ HookContactAt, cut at HookSmashAt (the smash keeps HookFX's sound) |
| Servo Dash | squat 0..0.06 (SQUAT); BLAST at ServoDashBlastAt; 22 studs in 0.25 s then the boosted run to ServoDashUntil (moved to the end on an early end); brake 0.35 s | squat 0–0.06, blast 0.06–0.31, sprint to 1.31, skid 1.31–1.66 | blast @ BlastAt − 0.06 (BLAST ON 0.06) · burn (loop) BlastAt + 0.25 .. Until · skid @ Until |
| Dome Visor | brace in 0.1 s at VisorStartedAt, held to VisorUntil (VisorTime 1.5); each block VisorBlockAt (BoneCrest) | panels slam 0–0.10, bite blocked 0.80, folds at 1.60 | up @ VisorStartedAt (panels ON 0.10) · field (loop) +0.10 .. VisorUntil · block @ VisorBlockAt · down @ VisorUntil |
| Ink Shooter | turn + pump at InkStartedAt (the press), the shot at InkFireAt (+AIM_DELAY 0.1), the splat at InkArriveAt (distance / 160) at InkAimEnd | pump 0–0.10, FIRE 0.10, splat 0.325 (36 studs) | fire @ InkFireAt − 0.10 (shot ON 0.10) · splat @ InkArriveAt at InkAimEnd |
| Tether Spike | the tail cocks while aiming (TetherAimAt; own TetherAimLocalAt), the whip at TetherStartedAt (release), lands at TetherLandAt (+0.8) at TetherAnchor | aims 0–0.5, whip 0.5, lands 1.3 | cock @ the aim start · throw @ TetherStartedAt (whip ON 0) · land @ TetherLandAt at TetherAnchor |
| Blood Rush | HeadbuttSacrificeAt at the press, inside the headbutt's 0.15 s wind-up; the headbutt follows with its own sounds | jolt + roar + vials 0–0.15 | pact @ HeadbuttSacrificeAt |
| Med-Station | the capsule pops at MedDroppedAt, lands DROP_TIME 0.3 s later and unfolds; heals until MedActiveUntil (moved on an early end); folds FOLD_TIME 0.4 | pop 0, thud 0.30, unfold to 0.60, waves, folds at 3.30 | drop @ MedDroppedAt (thud ON 0.30) · hum (loop) +0.60 .. MedActiveUntil · fold @ MedActiveUntil |

Headbutt, Leap, Last Stand and Head Down are not in this pass (the headbutt and leap keep their sounds; the other two are passives).
