# Mecha Dino Arena — Therizino Grapple Zip v2 + passive Overclock Joints (plan v1.0)

**Ask (Kepu 2026-11-04 15:21, after the v434 phone test):** "The grappling hook feels off, also the overclocked legs should
always be on but passive and take up a slot." Follow-up: the grapple is "useless. Barely even pulls you a significant
distance for the slot. Also it's not obvious where it's shooting to latch on to." Overclock: "Same numbers, always on".
**Mockup:** docs/mockups/therizino_grapple_overclock_v0.1.html (artifact Rq9Tm5183RKMV8XVu4JLdx).
**Picks (15:27 "Build", then "Yes, the recommended ones"):** Grapple-A "Always pulls", Overclock-A "Steady ON", legs: gears spin
while you move.

## Global constraints
- Additive, each change behind a switch; versions in headers, VERSIONS.md, ATTRIBUTES.md.
- No regen / lifesteal. Saved progress untouched (only numbers and text change; bought tiers keep their meaning).
- HUD change ships on PC (AbilityBar) and phone (MechaButtons) together.
- Camera-side rule unchanged (nothing one-sided is added).

## Do-not-touch
DeflectRules, the other dinos' parts and buttons, TheriPose, TheriPartsServer and TheriPartsLooksV2 (looks), the hook / feather /
harvest / snare / deflect moves, SprintTest / TheriAttackServer / TheriAttackTest (they already read TheriClockUntil).

## Changes
| File | Version | Change |
|---|---|---|
| src/shared/SkillTree.luau | 1.63 | grappleRange 90 / 110 (II) / 130 (III); new zgrapple + zclock texts. Switches THERI_GRAPPLE_V2, THERI_CLOCK_PASSIVE |
| src/server/TheriMovesServer.server.luau | 1.3 | grapple: ZIP_SPEED 150, time ≤ 1.0 s, nothing hit → latch in the air at full range; clock: passive while slotted (TheriClockUntil far ahead, TheriClockPassive true), clock remote ignored while passive |
| src/character/TheriGrappleZip.client.luau | 1.1 | keeps 60% of the speed after the zip; the latch marker (owner client) |
| src/character/AbilityBar.client.luau | 1.30 | passive Overclock tile: yellow border, "ON", no timer |
| src/character/MechaButtons.client.luau | 1.31 | passive Overclock phone button: yellow ring, "ON", a tap does nothing |
| src/client/TheriMovesFX.client.luau | 1.3 | passive Overclock rings: steady speed yellow (no pulse) |
| src/client/TheriPartsAnim.client.luau | 1.1 | passive Overclock legs: gears and fins follow how fast the dino moves |
| tools/tests/SkillTreeTheriParts.spec.luau | 1.2 | new numbers and texts |

## Deterministic map
**Grapple press (server, aimDir = camera look, origin = root + 2 × scale up, range = TheriGrappleRange):**
- Hit ≥ 6 studs away → zip to hit + normal × 3 × scale (as now), time = clamp(d / 150, 0.2, 1.0).
- Hit < 6 studs → "noAnchor", no charge used (as now).
- Nothing hit (V2 on) → "zip" to origin + aim × range, `TheriGrappleAir = true`, time = clamp(range / 150, 0.2, 1.0).
- Nothing hit (V2 off) → "noAnchor" (1.2).
- After the zip the body keeps 60% of its velocity (25% with the switch off).

**Latch marker (owner client, while TheriGrappleEnabled, alive, not in a menu):** the same ray every frame.
- Surface ≥ 6 studs → solid yellow ring + dot on the hit point.
- Nothing hit and the server's air latch on (`TheriGrappleAirLatch` true on the character) → hollow ring at full range.
- Hit < 6 studs, or nothing hit with air latch off → no marker.
- No charge left → the marker at half see-through.

**Overclock (server loop every 0.25 s, per therizino):**
- TheriClockEnabled true (bought + slotted) and passive switch on → TheriClockPassive = true, TheriClockUntil = now + 1e6,
  TheriClockAt = now (once, when it turns on).
- TheriClockEnabled false (unslotted / respawn before SkillEffects) or switch off while passive → TheriClockPassive = false,
  TheriClockUntil = now.
- DinoTheriClockRequest while passive → ServerResult "passive", nothing changes.
- Tier III (was "Lasts 5 s; recharges in 18 s") has no effect while passive: text says so; Kepu to say what III should give.

**Overclock HUD:** passive → PC tile yellow border (3), sub "ON", no timer; phone button yellow ring, "ON", tap does nothing.
Not passive → as before.
**Overclock legs:** passive → u = clamp(flat speed / 8, 0, 1), smoothed (rate 6/s): gears 12 rad/s × u + idle 0.3 × (1 − u),
fins out × u; rings steady yellow Neon while passive.

## Red-team (synthesized)
1. **Always-on +40% run is strong.** Kepu chose "Same numbers, always on"; it costs a slot. Accepted; numbers are switchable.
2. **Air latch makes the grapple a free long dash.** It's what option A shows; 12 s recharge stays. Accepted.
3. **Camera pitched down hits the ground close by → short zips.** The marker shows it before firing, so the player aims up.
   Watch in the phone test; a pitch floor is a follow-up if needed.
4. **Client marker and server ray could disagree** (streaming, a bot in the way). Same origin, filter and range; the server
   is the truth, the marker is a hint.
5. **A stale passive state after respawn.** The loop re-derives it from TheriClockEnabled every 0.25 s on the current
   character.
