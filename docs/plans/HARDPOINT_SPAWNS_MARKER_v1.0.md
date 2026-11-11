# Mecha Dino Arena — Hardpoint spawns v2 + point marker v2 + bot size fix (v1.0)

**Goal:** Hardpoint plays like CoD: teams start an equal distance from the point and out of each other's sight with several
paths in, a death puts you back a fair distance away, a compass strip always shows which way the current point (and the next
one, before it opens) is, and practice bots are the same size as players.
**Picks (Kepu 2026-11-10):** spawns "B · Scored ring"; marker "B · Compass bar" (23:39: "Nah let's just go with the compass bar
forget the arrow"; replaces his first pick A). Bot size = bug MDA-420.
Mockup: docs/mockups/spawns_and_marker_v0.1.html (artifact "Spawns and Point Marker").

## What's live (v662) and why it plays badly
- HardpointRules 1.0 `ringSpots`: 12 directions round the current point, first good radius of {300, 260, 340, 220, 380};
  `pickSpawn`: skip spots within 150 studs of a living enemy, score = min(enemy dist, 350) + 0.4 x (300 − nearest mate).
  Both teams use the same ring and there is no sight check, so at the start teams can land ~150–300 apart in view; a T-Rex
  bot runs 74 studs/s, so 300 studs is ~4 s. Respawns (ArenaSpawnServer -> HardpointPickSpawn; practice bots and the player
  through PracticeServer.pick) use the same ring.
- HardpointHUD 1.3 marker: one marker on the current point only. Behind the camera it snaps to x = 70 or W − 70 at half
  height (flips sides as you turn); in the left column it is pushed under the pills / kill feed (`x - 60 < left` toggles,
  so it hops); at rotation it jumps to the new point in one frame; the next point is text only.
- RaptorScale 1.8: player characters of all 8 species are scaled (x2, T-Rex x1.63); bots only for Raptor, Pachy, T-Rex.

## Global constraints
- Additive; every number an attribute or rules constant; every change behind a switch; versions + VERSIONS / ATTRIBUTES.
- PC and phone together. The Arena (players) and the practice match use the same spawn and marker code.
- Do-not-touch: the 1.0 `ringSpots` / `pickSpawn` (kept for the switch-off path), the scoring, occupancy, phase rules,
  KillFeed, TeamTags, PracticeBrain.

## Rules
**Spawns (B · Scored ring)**
- Band: for each point, spots on 24 directions x radii {420, 480, 540, 600} that pass the 1.0 ground check (dry, flat, not
  in a tree / rock box). Diagnostic HpBandSpots per point.
- Respawn (any time after the warm-up): from the current point's band, skip spots within MIN_ENEMY 250 studs of a living
  enemy; a spot an enemy can see (server ray from the enemy's root + 6 studs to the spot + 6, dinos left out, only enemies
  within SIGHT_MAX 700) loses SEEN_PEN 400; score = min(enemy dist, ENEMY_CAP 600) + MATE_W 0.4 x max(0, MATE_RANGE 300 −
  nearest mate) − seen penalty; best wins. No spot left -> the 1.0 pick (ring) -> nothing (caller's fallback).
- Opening (the match's 5 s warm-up): one anchor per team, picked once per match: the pair of band spots of point 1 that are
  at least OPEN_MIN_APART 600 studs apart, whose distances to the point differ by at most 60 studs, and that can't see each
  other (ray); among those the pair furthest apart. Team A gets the first, B the second. Every spawn during the warm-up is the
  band spot nearest its team's anchor that is not already taken in the last 3 s (so a team arrives together, spread out).
  No pair found -> respawn rule.
- Switch HardpointScoredSpawnsEnabled (HardpointServer, default true; false = 1.1 ring pick).

**Marker (B · Compass bar)** — replaces the 1.3 edge / column placement; no edge arrow.
- Compass strip at the top centre (between the score card and the SKILLS / MENU buttons): COMPASS_FOV 180° wide (±90° from
  where the camera faces), ticks every 15°, a centre notch. PC 30% of the screen wide, 26 px tall; phone 34% wide, 22 px.
- Icons by bearing (camera yaw to the point, flat): current point = solid diamond with its number in the team-state colour
  (blue you hold / red they hold / yellow contested / white open / grey locked) and the distance under it ("212"); next point
  (while HpShowNext, last 10 s) = hollow grey diamond with its number and the countdown ("0:07"). A point outside ±90° sits
  at the strip's end with an arrowhead (◀ / ▶) on the side it is really on (no flip near 180°: a 10° hysteresis band).
- Icons ease along the strip (rate 14/s) so they never jump; at rotation the current icon starts from where the NEXT icon was.
- 3D marker over the point (1.3 look: label, diamond, studs) only while the point is on screen; off screen it is hidden (the
  compass carries direction). The left-column push and the edge snap of 1.1–1.3 are not used.
- Switch HardpointHUDCompassEnabled (default true; false = 1.3 marker).

## Tasks
### Task 1 — HardpointRules 1.1 + spec · Logic
Add (keep 1.0 API): BAND_DIRS 24, BAND_RADII {420,480,540,600}, MIN_ENEMY 250, ENEMY_CAP2 600, SEEN_PEN 400, SIGHT_MAX 700,
OPEN_MIN_APART 600, OPEN_MAX_DIFF 60; `bandSpots(centre, okFn) -> {Vector3}`; `scoreSpawn(spot, enemies, mates, seen) ->
number?` (nil = skipped); `pickScored(spots, enemies, mates, seenFn) -> Vector3?`; `pickOpening(spots, centre, seesFn) ->
a, b`. Spec: every rule above incl. no-spot, all-seen, equal-distance pair, ties.

### Task 2 — HardpointServer 1.2 · Wired
BANDS per point at start; pickFn: warm-up -> opening anchors; else pickScored with a ray-based seenFn; switch off -> 1.1.
Diagnostics HpBandSpots, HpSpawnLast ("open A" / "scored 512 seen=false" / "ring"), HpOpening ("A x,z | B x,z").

### Task 3 — HardpointHUD 1.4: compass bar · Wired
Compass strip (PC / phone sizes), current + NEXT icons by bearing with distance / countdown, end-of-strip arrowheads with
hysteresis, easing, take-over at rotation, 3D marker only on screen. Switch HardpointHUDCompassEnabled.

### Task 4 — RaptorScale 1.9 (MDA-420) · Wired
Bot branches for Herrera, Teno, Therizino, Dilo, Troodon with the player factors; switch RaptorScaleOtherBotsEnabled.

### Task 5 — QA + docs · Wired
Practice 5v5: opening anchors opposite and unseen (HpOpening), respawn distances (log 20 respawns: distance to point, to the
nearest enemy, seen), bot sizes = player sizes, compass turn test PC + forced touch (icons follow, no side flips), rotation without a jump. Docs + Dev Hub.

## Red-team (2026-11-10)
1. **Edge points lose half their band.** East Shore (x 450) and West Meadow (x −450) sit near the island edge (~±560); a
   420–600 band there is half sea, so both teams could get spots on the same land side. Mitigation: HpBandSpots logged per
   point; if a point has fewer than 8 band spots, its band also takes radii {360, 300}. Opening needs 600 apart or falls back.
2. **Longer runs.** 420–600 studs is 6–8 s for a T-Rex (74/s) but 13–18 s for a 33/s dino; CoD respawns are usually 5–10 s
   from the point. Decision for Kepu: keep 420–600, or 360–520.
3. **"Scored" means flips.** With no fixed sides, a push can make your next spawn swap sides (the CoD flip). That is the B
   pick; the mate weight (0.4) keeps teams together. Accepted unless Kepu wants a "prefer last side" weight.
4. **Ray cost.** Up to 96 spots x 10 enemies per spawn; enemies further than 700 studs are skipped, and spawns are a few per
   second at most. Measure server ms in QA.
5. **Compass on phones.** The top centre on phones already has the score card at the left and SKILLS / MENU at the right;
   the strip goes between them at 34% width. Check it doesn't overlap on a narrow phone (QA screenshot).

## Status (2026-11-10 23:39)
Kepu: "you're not connected to the pc. Just make note of these changes." Nothing built yet; tickets filed. Red-team 2
answered 23:41 ("Yes I do want that"): keep the 420–600 band. Ready for "Build" once Studio is linked.

## Build (2026-11-11)
All five tasks built and checked in Studio (commits 9cc9c47..061677b). Found in QA and fixed: ScaleTo doubled practice bots'
WalkSpeed (RaptorScale 1.9 keeps it); the compass covered SKILLS / MENU on a narrow window (HUD 1.5 placement).
Open observation: in two practice runs team A led (56–0, 46–2). The opening pair is always the same one (the furthest-apart
pair), and B's side (324, −464) is behind the Summit, so equal flat distance may not be an equal run. Not changed; raised to Kepu.
