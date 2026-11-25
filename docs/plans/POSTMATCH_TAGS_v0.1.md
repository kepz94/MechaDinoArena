# Post-match backdrop, island tag without the bar, top-10 rainbow badge (picks log v0.1)

Kepu 2026-11-24 22:21: "Post match screen the last presentation cuts to a dinosaur playing on the island still. The game is
still running in the background. When I got my post match results it showed me respawning in the background. Also remove the
green/red bar that shows above your name because it confuses other players for a health bar. Just keep the name and record.
Also for people ranked in the top 10 let the border for their number be rainbow. The pc is off but send me some mock ups".

Mockup: docs/mockups/postmatch_tags_v0.1.html (artifact TJZRUMVkr4jCQ1ib7bLKcW). Not checked live (PC off, Studio unreachable).

## 1 · Post-match (code reading, to verify in Studio)
- VictoryTitles 1.3: when the show ends, the camera goes back to Custom on your character.
- HardpointHUD 1.14: the board beat has no dim (endDim hidden for "board" and "titles"); the 760 x 400 board sits on the live game.
- RespawnServer 1.0: "the match ending -> RespawnHold false at once", so a dino that died at the end is placed on a spawn during
  the results (PracticeServer places it) = "respawning in the background".
- Options on the mockup: A stay on the sky stage (rec), B solid backdrop, C blur + dim. All: no respawn during results, respawn
  screen + HUD hidden until the trip.

## 2 · Island tag (IslandTags 1.2)
- Remove the ratio bar. A: "12W 4L" green / red under the name (rec), B: orange "12-4" (= IslandTagsBarEnabled false today).

## 3 · Rank badge (RankBadge 1.0, shared by island tag, match tags, lineup, kill feed, boards)
- Ranks 1-10: rainbow outline (thicker than today's), chip colour unchanged. Spins (rec) or still; everywhere (rec) or tags only.

## Picks
- 22:27 "A A and spins": 1 A · Stay on the stage, 2 A · 12W 4L, 3 spins; "Everywhere" (rainbow wherever the badge shows).

## Built in the repo 2026-11-24 (PC off: NOT INSTALLED, no compile check yet)
- VictoryTitles 1.4 + VictoryTitlesAnim 1.4 (stage hold), RespawnServer 1.1 (no release during results), IslandTags 1.3 (no bar),
  RankBadge 1.1 (rainbow 1-10).
- To do when the PC is on: install (hash-checked), loadstring compile, Studio Play: a test results (titles + hold, draw = empty
  stage), die at the end -> stays parked, phone emulator tag + badge, kill feed / lineup / boards badge, then report.

## 4th title cuts to the live game (Kepu 22:34)
- Most likely cause (code): RespawnScreen's death cam (render step Camera + 9) overrides VictoryTitles' camera (Camera + 2)
  whenever RespawnHold is true. The match keeps running during the results, so dying mid-show (bots still fight) swaps the title
  shot for the killer cam ("the Dino fighting"). RespawnServer 1.1 would make it last longer (held through the results).
- Fix: RespawnScreen 1.1 yields while VictoryCamOwned (VictoryTitles 1.4). Not proven live: in Studio also read
  VictoryTitlesLast after a real 4-title show (a step error on the 4th title would also end the show early).

## Presentation mode (Kepu 22:37 "once the game is done then it just goes into presentation mode and no more fighting")
- PracticeServer 1.15: at "results" every living dino (humans + bots) is anchored where it stands, humans get the combat lock,
  bots stop thinking and don't respawn; thawed when the results end. With RespawnServer 1.1 (no respawn) and VictoryTitles 1.4
  (camera on the stage) nothing in the match moves or fights after the win. RespawnScreen 1.1 stays as a guard (a damage-over-
  time tick can still finish someone).

## Installed + Studio Play 2026-11-25 (not published)
- All 7 scripts installed with base + new hash checks and a compile check. Test: Workspace ModeTestPractice = true (restored to
  nil after), PracticeRequest lobby / join A / start, HardpointTest score 3-1 + clock 2.
- Results: banner on the empty stage; PrResultsFrozen 8, player anchored + locked; killed in the results -> RespawnHold held,
  RespawnCamTarget "yield"; 4 titles; hold "dino" with the board over the stage; lobby -> camera back, hold off.
- Found + fixed: titles drifted past their slots under 20 FPS (dt clamp) so the 4th was cut by the results end -> late cut.
  RankBadge spin stopped (weak-key list) -> strong list.
