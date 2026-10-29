# Mecha Dino Arena — Thrusters boost lean + booster swivel (v1.0)

**Ticket:** MDA-57
**Goal:** during a Thrusters boost the flames point away from the travel direction (back, sideways and forward boosts), and the body leans with it.
**Chosen direction:** option B — "lean + swivel" (Kepu 2026-10-29: "I love B"). Mockup: docs/mockups/boost_lean_options.html (artifact https://claude.ai/artifact/9ycPzFnpmuq8CmMw2zehBA).
**Architecture:** the server builds each booster on a Weld hinge (MechaServer 1.3); every client turns the hinges and leans the RootJoint in its animator (IdleAnimation 1.27 + new module BoostPose 1.0). The server never moves the hinges, so the look is the same on every client and costs no network traffic.

## Global constraints
- Versions: MechaServer 1.3, IdleAnimation 1.27, BoostPose 1.0.
- Additive: the 1.2 build and the 1.26 animator are unchanged when the toggles are off (MechaSwivelHinge false; BoostLeanEnabled / BoostSwivelEnabled false).
- Cloud place 84022023159448 only; hash + compile check on every install.

## Do-not-touch
Dash physics and requests (MechaButtons, MechaServer request / charges code), flame / jet / glow / roar settings, booster sizes and places, CloakServer / CloakFX, all other IdleAnimation layers.

## Deterministic map
| State | Condition | Result |
|---|---|---|
| No boost | DashStartedAt missing, or now outside [start, start + DashTime + BoostEaseOut) | weight 0; lean none; hinge C0 = BaseC0 (restored once if it was moved) |
| Ease in | 0 ≤ t < BoostEaseIn | weight = smoothstep(t / 0.15) |
| Full | BoostEaseIn ≤ t ≤ DashTime | weight 1 |
| Ease out | DashTime < t < DashTime + 0.25 | weight = 1 − smoothstep |
| New boost during a boost | DashStartedAt changes | the window restarts from the new start |
| Forward travel | f = 1 | pitch −10 (chest down), boosters straight back |
| Backward travel | f = −1 | pitch +15 (chest up), boosters swing up and over 160° |
| Sideways travel | r = ±1 | roll −12·r (right travel = left side down), boosters turn 90° to fire out the other side, slid apart along the back |
| Diagonals | any (f, r) | mixed by the same formulas (BoostPose header) |
| Slow / no movement | speed < BoostDirMinSpeed | direction held; starts forward |
| No hinges | Mecha_Thrusters without BoosterHinge (MechaSwivelHinge false or older build) | lean only; BoostSwivel "noHinge" |
| Dead | Health ≤ 0 | the dead pose layer (after this one) wins |

## Red-team (one paragraph, single feature)
How this fails: (1) **the boosters clip into each other** when turned across the back — measured in Studio, their length (1.3–5.8 studs) is longer than the space between them (0.66–4.4 studs), so a plain 90° turn overlaps. Mitigation built in: they slide apart along the back until the gap between their axes is ≥ 1.15 × booster width (raptor III: 1.46 studs). (2) **The direction flips back and forth** at exactly-backward travel (atan2 wraps at ±180). Mitigation: the turn is the shortest rotation from "back" to the target, and a straight-back target is lifted 20° up, so the axis never flips — tested at ±0.02 lateral, both give the same 160° swing. (3) **Other players see something different** from the owner. Accepted risk: each client uses its own replicated position deltas, so the direction may lag by a frame or two on others; needs the open two-player check (same as MDA-52 #1). (4) **The camera script turns the dino** so "W" is not always forward — the swivel follows real travel, not the key, which is the intended behaviour.

## Verification (done in Play, raptor, Thrusters III, DashTime 1.35)
- Back: BoostLeanPitch 15, BoostSwivelAngle 160, nozzle·(−velocity) 0.87–0.95 (before: −1.00, i.e. firing the travel way).
- Right: BoostLeanRoll −12 (left side down), angle 90, BoostStagger 1.46, nozzle·(−velocity) 0.97–0.98.
- Forward: pitch −10, nozzle·(−velocity) 0.95.
- After the boost: hinge C0 = BaseC0 (offset 0.0000), BoostSwivel "none". No new output errors.

## Open for Kepu
- Live feel check on PC / phone (lean angles, swing speed). All numbers are model attributes, tunable without code.
- Two-player check: the other player sees the lean + swivel.
