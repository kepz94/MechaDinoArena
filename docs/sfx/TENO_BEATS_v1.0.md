# Teno sound beat sheet v1.0 (MDA-552, sound pass round 10)

The beats the Teno sounds get rebuilt to, read from the game (TenoMovesServer 1.18, TenoPose 1.13) and checked against the
storyboard (tools/mockup/teno_moves_anim.js, variants Kepu picked 2026-11-05 18:47 + the grab 2026-11-05 18:10). Times are
seconds after the press (the move's StartedAt stamp). Storyboard times are press + offset (PRESS = 0.3).
The live sounds (GameSounds 1.8, v857) were timed off the stamps only: one sound per stamp, no split at these beats.

| Move (pick) | Game beats (after the press) | Storyboard (after its press) | Match |
|---|---|---|---|
| Tail Grab (A Scorpion) | front: strike from catch − 0.15 = 0.40, catch 0.55 (TenoGrabCatchAt), slam from throw − 0.15 = 1.00, throw 1.15 (TenoGrabThrowAt), flight 0.6 → land 1.75 (TenoGrabLandAt). back: catch 0.40, throw 1.00, land 1.60 | front: strike 0.40–0.55, snap 0.55, slam 1.00–1.15, flung 1.15–1.65 (0.5 flight), lands 1.65 | flight 0.1 s shorter on the storyboard |
| Boulder Mortar (A Anchored Shot) | brace 0 → ANCHOR 0.35 at the fire; fire 0.35 (TenoMortarFiredAt, v1.17 fast), recoil kick +0.06, flight ~0.23 s at mid range (variable; TenoMortarLandedAt / TenoMortarLand) | brace 0–0.35, charge 0.35–0.70, BOOM 0.70, flight 0.85–1.8 | **off**: the storyboard is the pre-1.17 timing (fire 0.70, ~0.95 s flight). The pick page time-warps the storyboard (press..BOOM ×0.5, flight to ~0.25 s) so it plays at the game's speed |
| Stomp Shockwave (A Quake Smash) | rear to 0.38, hang 0.38–0.52, smash 0.52–0.60, hit 0.60 (TenoStompAt), held to 0.95, back up by 1.8 | rear 0–0.38, hang 0.38–0.52, smash 0.52–0.60, ring 0.60–1.0 | yes |
| Herd Bellow (A Concussion Shriek) | inhale 0–0.40, shriek 0.40–0.50, the call 0.50 (TenoBellowAt), held to 1.1, back by 1.8 | inhale 0–0.40, shriek 0.40–0.50, rings 0.50–1.1 | yes |
| Challenge Call (A Watcher Alarm) | snap 0–0.20, scan 0.20–0.65, the call 0.50 (TenoChallengeAt), held to 1.3, back by 1.9 | snap 0–0.20, scan 0.20–0.65, alarm 0.65–1.3 | yes |
| Hydraulic Leap (A Piston Launch, JUMP) | crouch 0–0.12 (JumpWindup), lift-off 0.12 (TenoLeapStartedAt), air ~0.9 (LEAP_TIME; real flight varies), land (TenoLeapLandedAt / owner TenoLocalLandAt), tail slam land + 0.12 | crouch 0–0.25, rams fire 0.25–0.35, air 0.35–1.25, land 1.25, tail slam 1.45 | **off** by 0.13 s at lift-off: time-warp the crouch |
| Shield Armor (C Shield Pulse) | push 0–0.25, shield up 0.20, guard by 0.70, held to 1.2, back by 1.7; the shield stays its full time; blocks (MUD_BLOCK_GAP 0.15; block stamp to confirm in TenoMovesServer before the build) | push 0–0.50, disc snaps 0.15–0.30, pulse 0.30–0.70, guard | yes (disc 0.15–0.30 vs 0.20) |

Parts to build per option (same method as the Therizino, docs/sfx/gen_theri_v2_sfx.py):
- Grab: strike (whoosh into the snap at the catch), slam + throw, land (position event at TenoGrabLand).
- Mortar: brace + fire (boom on 0.35, casing after the kick), land (position event at TenoMortarLand).
- Stomp: rear + hang (rising tension to 0.52), smash (hit on 0.60).
- Bellow: inhale (0–0.40), shriek (on 0.40–0.50, the call body to 1.1).
- Challenge: snap (0), scan sweep (0.20–0.65), alarm (0.65).
- Leap: launch (rams fire on lift-off), land (touchdown + the tail slam at +0.12).
- Shield: pulse up (0.20), shield loop while it lasts (fade at its end), block per blocked shot.
