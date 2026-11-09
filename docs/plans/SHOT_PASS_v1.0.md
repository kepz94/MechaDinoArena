# Shot Pass v1.0 (Mecha Dino Arena)

Request: Kepu 2026-11-09 "all the projectile shots need to be faster and more auto aim assist on it and longer range".
Picks: speed "1.5x faster", range "2x range", aim assist "Strong" (snap to a target within 45 degrees of the aim),
scope "Every projectile".

## Rules

| Setting | Value |
|---|---|
| Speed | flight time / 1.5, or speed x 1.5 |
| Range | x 2 (SkillTree 1.74 effect keys, model data ranges) |
| Aim assist | snap cone at least 45 degrees; parts without a snap get a 45 degree snap |
| Switch (servers / FX) | script attribute `ShotPassEnabled` (default true; false = previous version) |
| Switch (ranges / cones) | `SkillTree.SHOT_PASS` (default true; false = 1.73 effects) |
| Switch (base attacks) | rebuild model data with `--v15` (Dilo) / `--v16` (Troodon) |

## Coverage

| Shot | Script (version) | Speed | Range | Assist |
|---|---|---|---|---|
| Dilo Spit Dart (base) | DiloModelData 1.6 | DiloDartSpeed 45 -> 67.5 | DiloDartRange 30 -> 60 | DiloAssistAngle 30 -> 45, DiloAssistMax 30 -> 60 |
| Venom Gatling | dart data + SkillTree 1.74 | dart speed | dart range | dGatlingCone >= 45 |
| Toxin Mortar | DiloMovesServer 1.6 | flight / 1.5 | dMortarRange x2 | nearest enemy within 45 degrees (diag DiloMortarAssist) |
| Spine Burst | DiloMovesServer 1.6, DiloMovesFX 1.4 | flight / 1.5 (DiloSpineFlight) | dSpineRange x2 (DiloSpineRange) | radial burst (n/a) |
| Troodon Glow Pod (base) | TroodonModelData 1.7 | TrooPodFlight 0.55 -> 0.37 | TrooPodRange 40 -> 80 | TrooAssistAngle 30 -> 45, TrooAssistMax 40 -> 80 |
| Arc Lantern | TrooMovesServer 1.4 | flight / 1.5 | oLanternRange x2 | nearest enemy within 45 degrees (diag TrooLanternAssist) |
| Sap Wall throw | TrooMovesServer 1.4 | flight / 1.5 | oSapRange x2 | placement (n/a) |
| Quill Launcher | HerreraMovesServer 1.9, HerreraMovesFX 1.7 | 90 -> 135 (QuillSpeed) | quillRange x2 | cone >= 45 |
| Goo Blob | HerreraMovesServer 1.9 | flight / 1.5 | gooToss, gooAssistMax x2 | gooAssistAngle >= 45 |
| Grappling Hook | HookServer 1.11 | CLAW_SPEED x 1.5 | hookRange x2 | new 45 degree snap (diag HookAssistDeg) |
| Ink Shooter | InkServer 1.8 | INK_SPEED x 1.5 | inkRange x2 | max angle >= 45 |
| Tether Spike | TetherServer 1.5 | flight / 1.5 | tetherRange x2 | existing aim |
| Shock Cannon | ScreechServer 1.14 | SHOCK_SPEED, BOLT_SPEED x 1.5 | screechRange x2 | new 45 degree snap (diag ScreechAssistDeg) |
| Shock Mine | MineServer 1.10 | arc time / 1.5 | throw 30 -> 60 | throw (n/a) |
| Boulder Mortar | TenoMovesServer 1.15 | flight / 1.5 | mortarRange, mortarMiss x2 | nearest enemy within max(cone, 45) (TenoMortarAimMode "assist") |
| Feather Barrage | TheriMovesServer 1.9 | flight / 1.5 | featherRange x2 | volley fan |
| Reaper's Hook | TheriMovesServer 1.9 | claw x 1.5 | hookRange x2 | TheriHookCone >= 45 |
| Snare Wires | TheriMovesServer 1.9 | 80 -> 120 | snareRange x2 | cone 25 -> 45 |

Excluded (not projectiles): Portal, Mender, Hiss, Strobe, grapple / dash, Siphon.

## Lab texts

SkillTree 1.74 rewrites the stud numbers in the Lab step texts (x2). Misses are counted in `SkillTree.SHOT_TEXT_MISSES`
(expected 0).

## Test (Studio, bots, default camera)

1. Each shot: fire at a bot at the new range; check hit, flight time, and snap with the aim 30-40 degrees off.
2. `ShotPassEnabled = false` on each script and `SkillTree.SHOT_PASS = false`: previous behaviour.
3. Lab texts: SHOT_TEXT_MISSES == 0.
