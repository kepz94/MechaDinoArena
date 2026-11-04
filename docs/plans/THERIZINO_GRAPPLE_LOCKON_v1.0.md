# Mecha Dino Arena — Therizino Grapple Zip lock-on (plan v1.0)

**Ask (Kepu 2026-11-04 15:53, after the v437 test):** "The yellow marker on the grappling looks so ugly. Only have it appear
when you press the button/hold the button. On press it'll pick the thing furthest away for distance. Have it auto lock on to
objects it can grapple on to so you can just easily transition."
**Mockup:** docs/mockups/therizino_grapple_lockon_v0.1.html (artifact DuQ67YC82VXAusr3xPQHw1). **Pick (15:56):** "A" (outline
the target). Air latch kept (Kepu did not say "no air latch").

## Global constraints
- Additive, each change behind a switch; versions in headers, VERSIONS.md, ATTRIBUTES.md.
- PC (key T/R/C/V hold) and phone (button hold) ship together.
- Server stays the judge: the client only chooses the aim direction; TheriMovesServer 1.3's ray, range and air latch are
  unchanged.

## Do-not-touch
TheriMovesServer (no change), Screech / Tether hold-to-aim (their branches untouched), AbilityBar, the Overclock work, the part
looks (TheriPartsServer / LooksV2 / TheriPartsAnim), TheriMovesFX.

## Changes
| File | Version | Change |
|---|---|---|
| src/character/TheriGrappleZip.client.luau | 1.2 | the 1.1 always-on ring goes (switch); lock-on: `pick()` + yellow outline (Highlight) on the target while held; BindableFunction `TheriGrapplePick` for MechaButtons |
| src/character/MechaButtons.client.luau | 1.32 | zgrapple becomes hold-to-aim: hold = lock shown, release (or a tap) = fire toward the pick |
| src/shared/SkillTree.luau | 1.64 | zgrapple text: hold to lock, let go to zip |
| tools/tests/SkillTreeTheriParts.spec.luau | 1.3 | the new text |

## Deterministic map
**Targets (client cache, rebuilt every 5 s):** each child of `DinoIsland.Trees` and `DinoIsland.Rocks` (a model or a part), each
part in `DinoIsland.MountainSteps` and `DinoIsland.EdgeWalls`. Centre = bounding-box centre (model) or position (part).
**pick()** (origin = root + 2 × scale up, range = TheriGrappleRange, flat camera look `f`):
1. Candidates: 6 ≤ distance(origin, centre) ≤ range and flat angle(f, centre − origin) ≤ CONE (30°).
2. Sorted furthest first; the first whose line-of-sight ray (same filter as the server) hits a part of that target wins;
   grab point = that hit. At most MAX_RAYS (12) rays per pick.
3. None → air: direction = `f` tilted up AIR_PITCH (3°); grab point = origin + dir × range.
Returns {dir, point, target (or nil)}.
**Hold (MechaButtons aim kind "zgrapple"):** character attribute `TheriGrappleHolding` true → TheriGrappleZip runs pick()
every frame: target → a Highlight on it (fill off, outline speed yellow #ffc21a, always on top); air → a faint small dashed
ring at the air point (70% see-through); nothing else shows.
**Release / tap:** MechaButtons calls `TheriGrapplePick` once more and fires DinoTheriGrappleRequest(stamp, dir). Holding ends,
the outline goes. A quick tap = the same pick at the moment of the tap.
- PC: key down = hold, key up = release (as Screech).
- Phone, plain button: touch down = hold, up = release. Pull button (slots 3 / 4): holding on the button locks at once;
  pulling down switches to the lower slot; a tap with no movement still fires.
- Part not slotted / dead / in a menu / out of charges: no lock shows; release sends the request (the server answers
  "cooldown" as now).
**Switch off** (`TheriGrappleLockOnEnabled` on the character, `MechaButtonsGrappleHoldEnabled` on MechaButtons): back to 1.1 /
1.31 (press fires along the camera look; the always-on ring).

## Red-team (synthesized)
1. **"Furthest" overshoots the tree right ahead you wanted.** That's what Kepu asked for; turning while holding moves the
   lock. Accepted.
2. **Client and server disagree** (leaves with gaps, streaming): the client sends the direction of its own line-of-sight hit,
   and the server casts the same ray with the same filter, so it hits the same part.
3. **Cost on phones:** ~1,500 cached centres, distance + angle only; at most 12 rays per frame while held, none otherwise.
4. **Mountain steps** are hundreds of small parts; the furthest visible step up the slope is a valid pick and helps climbing.
5. **Highlight limit (31 per client)**: one at a time, destroyed on release.
