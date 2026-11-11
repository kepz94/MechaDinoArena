# Mecha Dino Arena — Spawns further + fair start sides + top compass + slim HUD (v1.0)

**Goal:** you respawn much further from the point; both teams' match-start sides take the same time to run to point 1; the
compass sits in the empty top gap between the Roblox buttons and SKILLS and is more see-through; the score card and point
pills are smaller so more of the screen is free. Arena and practice match, PC and phone together.
**Kepu 2026-11-11 11:26:** "make the distance even further for spawns. theyre still very close. also fix the fucking compass
on mobile. theres so much space in the top middle of the screen between the roblox settings and the skills button. make it
more transparent and fit in that space. also make the point and score board smaller so we can have more screen space."
**Picks (2026-11-11):** spawns "700–900"; compass "A · See-through panel"; HUD "Smaller, 80%"; start sides "Equal running
distance". Mockup: docs/mockups/hud_slim_compass_v0.1.html (artifact "Slim HUD and Top Compass").

## What's live (v667) and why
- HardpointRules 1.1 band 24 directions x {420, 480, 540, 600} (+ {360, 300} under 8 spots); sight rays only from enemies
  within SIGHT_MAX 700; opening pair = furthest-apart pair of point 1's band spots that are >= 600 apart, differ <= 60 in
  straight-line distance to the point and can't see each other. Live pair A (−524, 384), B (324, −464); B runs round the
  Summit, so its run is longer; QA 56–0 and 46–2 for A.
- HardpointHUD 1.5 compass: in the score card's row (y 58) right of the card, else under the pills; panel transparency 0.25,
  stroke 0.75. Card at (16, 58), clamp(26% of the width, 220, 330) x 58; Status pill y 58 + 58 + 6 = 122, Next pill y 152,
  24 px tall, TextSize 15.
- Top row (phone and PC): Roblox buttons at the left (right edge = GuiService.TopbarInset.Max.X); at the right the SKILLS
  pill (PlayerGui.LabButton, button 36 px tall at y 8, DeviceSafeInsets) 8 px left of the MENU pill (PlayerGui.ArenaStatus.Pill).
  The camera button sits under MENU, not in the row.
- Dry spots per radius (24 directions, Studio 2026-11-11): Centre Meadow 700:10 800:5 900:8; East Shore 700:11 800:5 900:5;
  Summit 700:9 800:8 900:5; NW Foothills 700:11 800:7 900:3; West Meadow 700:8 800:5 900:6.

## Global constraints
- Additive; every number an attribute or rules constant; every change behind a switch; versions + VERSIONS / ATTRIBUTES.
- Do-not-touch: HardpointRules 1.0 / 1.1 functions and constants (the switch-off paths), scoring / occupancy / phases,
  PracticeServer, PracticeBrain, KillFeed, TeamTags, Lab (SKILLS), ArenaStatus (MENU), CameraModes, the compass's ticks /
  icons / easing / hysteresis (1.4), the 3D marker, the results board.

## Rules
**Spawn band 2 (700–900)**
- Band radii {700, 750, 800, 850, 900} x 24 directions, same ground check; under 8 spots the band also takes {650, 600}.
- Sight rays from enemies within SIGHT_MAX2 1000 (1.1: 700, which would miss an enemy on the point looking out at 700–900).
- Everything else as 1.1: MIN_ENEMY 250, ENEMY_CAP2 600, SEEN_PEN 400, mate weight 0.4 / 300.
- Opening needs OPEN_MIN_APART2 900 apart (1.1: 600; opposite sides of a 700–900 ring are 1400–1800 apart).

**Start sides by running distance**
- For each band spot of point 1: run length = the server path (PathfindingService, agent radius 4, height 10, can jump,
  waypoint spacing 8) from the spot to the point centre, summed waypoint to waypoint. No path = the spot can't be a start side.
- Pair rule: >= OPEN_MIN_APART2 apart, run lengths differ by <= OPEN_RUN_DIFF 60 studs, can't see each other (ray); among those
  the pair furthest apart. Team A first, B second. Same pair every match (paths are worked out once per server).
- Paths are computed once at server start in the background. Not done yet, or no pair -> the 1.2 straight-line pair -> the
  respawn rule.

**Compass in the top gap (A · See-through)**
- Left bound = TopbarInset.Min.X (the right edge of the Roblox top-left buttons, as Lab uses it; to this ScreenGui's frame) + 12, at least 16. Right bound = left edge of the SKILLS button − 12;
  no SKILLS -> left edge of the MENU pill − 12; neither -> screen width − 16. Room = right − left.
- Width = min(clamp(34% phone / 30% PC of the screen, 180, 420), room); centred on the screen, then moved inside the bounds.
  Top = the SKILLS button's top (fallback 8); height 22 phone / 26 PC as 1.4; the distance / countdown readouts stay under it.
- Room < 140 -> the 1.5 placement (card row, else under the pills).
- Look A: panel transparency 0.65 (1.4: 0.25), outline 0.85 (1.4: 0.75). Ticks, letters and icons unchanged.
- Bounds re-read every frame (the Roblox top bar can change width).

**Slim HUD (80%)**
- A UIScale 0.8 on the score card and the Status and Next pills; the card keeps its top-left at (16, 58).
- Status top = card bottom + 6 x 0.8; Next top = Status top + 30 x 0.8. The 1.5 column fallback for the compass uses the
  lowest visible pill's real bottom + 6 (not the fixed 122 / 152).
- The kill feed and the 3D marker already place themselves from real on-screen sizes, so they follow.

## Tasks
### Task 1 — HardpointRules 1.2 + spec · Logic (MDA-425)
Add (keep 1.0 / 1.1 API): BAND2_RADII {700,750,800,850,900}, BAND2_EXTRA_RADII {650,600}, SIGHT_MAX2 1000, OPEN_MIN_APART2 900,
OPEN_RUN_DIFF 60; `bandSpots(centre, okFn, radii?, extra?)` (new optional args; nil = 1.1 radii); `pickOpeningByRun(spots,
seesFn, runFn, minApart?, maxDiff?) -> a, b` (runFn(spot) -> number | nil). Spec tools/tests/HardpointSpawns2.spec.luau: band 2
counts and radii, extra radii under 8, run pair picked over a straight-line pair, no-path spot skipped, diff 61 rejected,
seen rejected, too close rejected, ties = first. 1.0 and 1.1 specs still pass.

### Task 2 — HardpointServer 1.3 · Wired (MDA-426)
Switches HardpointFarSpawnsEnabled (default true; false = 1.1 band, sight 700, apart 600) and HardpointRunOpeningEnabled
(default true; false = 1.2 straight-line pair). Background path pass for point 1 at start. Diagnostics HpRunPaths ("n ok / m"),
HpOpening ("A x,z run r | B x,z run r" or "flat ..."), HpBandSpots per point for band 2. Practice uses it through pickFn.

### Task 3 — HardpointHUD 1.6 · Wired (MDA-427)
Top-gap compass (switch HardpointHUDCompassTopEnabled, default true; false = 1.5 placement; place diag "top"), look A
(attributes HardpointHUDCompassBgT 0.65, HardpointHUDCompassStrokeT 0.85), slim HUD (attribute HardpointHUDScale 0.8; 1 = 1.5
size), column fallback from real pill bottoms.

### Task 4 — QA + docs · Wired (MDA-428)
Practice 5v5: 20 respawns logged (700–900 from the point, >= 250 from enemies, seen=false); HpRunPaths and HpOpening (run
lengths within 60); one bot run from each start side timed (within 15% of each other); server ms per spawn (< 2 ms);
screenshots PC 1280 wide and forced touch 844 x 390: compass between the Roblox buttons and SKILLS, not touching either; card
and pills at 80%; kill feed under the pills. Docs + Dev Hub.

## Red-team (2026-11-11)
1. **The sight check would go blind.** With spots 700–900 out and SIGHT_MAX 700, an enemy standing on the point could see your
   spawn and never be checked. Fixed in the rules: SIGHT_MAX2 1000.
2. **More rays per spawn.** Up to 168 spots x 10 enemies. Measured in QA (target < 2 ms per spawn); if over, only the 16 best
   spots by score get rays (an attribute, not built unless needed).
3. **Path length is not run time.** The path agent is radius 4; a T-Rex is wider and slopes slow dinos down, so equal path
   length may still not be an equal run. QA times a real bot run from both sides; over 15% apart -> raise to Kepu.
4. **Long trips back.** 700–900 is 21–27 s for the slowest dino and the point rotates; Kepu picked 700–900 knowing the times
   (mockup showed them). Accepted.
5. **The top gap can shrink.** The Roblox top bar widens when its menu opens and SKILLS moves when its badge grows; bounds are
   read every frame and under 140 px the compass drops back to the 1.5 place, so it never covers a button.

## Status (2026-11-11)
Plan + tickets filed 11:3x; Kepu "build" 11:41.

## Build (2026-11-11)
Commits 04faa1d (rules + spec), 7dd4396 (server), 908e638 (HUD); installed in Studio, hashes match.
- Rules: HardpointSpawns2 PASS 39 (one spec fix: 90° has x = 4e-14, guard x > 1e-3 as the 1.1 spec does); 1.1 PASS 55; 1.0 PASS 106.
- Server (practice 5v5): band 2 spots 40 / 37 / 35 / 32 / 29; paths 40 / 40 and 56 / 56 in a few seconds after start.
  Opening A (−550, 739) run 985, B (325, −776) run 1021. My character walked each path with MoveTo (WalkSpeed 32, no bots):
  A 33.4 s, B 35.1 s (5% apart, inside 15%). 20 respawn picks in a live match: 750–800 from the point, ≥ 756 from the nearest
  enemy, none seen; 0.8–2.4 ms per pick (first one 2.4, then ≤ 2.0).
- Bots: a 40 s watch from the start saw no bot reach the point (they fight on the way), so bot run times weren't usable; the
  scripted walk above is the timing check.
- HUD: 1.6 live; card 176 x 46, pills 19 px, compass panel 0.65. The Studio game window is 439 px wide: top gap 220..248 =
  28 px, so the compass used the column fallback (as designed). Not checked on a phone-size screen: Kepu's Roblox player was
  open and taking the screen would hide it. Expected on an 844-wide phone: gap ~173..559, strip 287 wide at x ~232.
- Not changed: respawn picks are deterministic, so back-to-back deaths can land on the same spot (as 1.2).
