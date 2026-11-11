# Mecha Dino Arena v1.0 — Arena Hardpoint

**Goal:** the Arena plays Hardpoint: two auto-balanced teams fight over one point at a time; standing on it scores; the point
moves every 60 s around the island; first to 250 wins.

**Kepu's words (2026-11-10):** "implementing control where there are parts of the map that you have to take control of and
that's how you score points, basically like how call of duty does it but with dinos. This will really give a chance for team
collaboration" → "the game mode I was thinking of is called hardpoint". Picks the same evening:
- Teams: **2 teams, auto-balanced** on join.
- Spawns: **"in relation to the hard point like how call of duty does it"**.
- Name: it is a **point**, never a "hill".
- Layout: **B · Summit** (5 points; point 3 on the mountain top).
- Point size: **radius 45** (90 studs across).
- Cloak: a cloaked dino on the point **counts** for its team; the point then reads CONTESTED when both teams are on it.
- HUD: **like Call of Duty: Mobile** (score + clock card top left; marker over the point).
- Point look: **C · Mecha pylons**.
- Score limit: no preference → **250** (Black Ops 6).
- Mountain: **"Fix the seven stud steps to be walkable"** (measured 2026-11-10: a Raptor walking at the summit stops at the
  first 7-stud MountainStep; the sand trail up is ~1,900–2,400 studs, ~40–45 s for a Raptor).
- Free-for-all: **out of scope** ("We're focusing on hard point rn").

**Mockups:** docs/mockups/arena_hardpoint_v0.1.html (layout, spawns, HUD, size, rules; artifact Qk6zd1dNxbmqqAiCo8ZRaW) and
docs/mockups/hardpoint_point_look_v0.1.html (the point in 3D, look C; artifact 9REkS7jGKSsyEgphVDL7ay). Sources:
tools/hardpoint_mockup, tools/hardpoint_look_mockup.

**Architecture:** one pure shared module holds every number and rule (`HardpointRules`), one Arena-only server runs the match
and publishes its state as attributes (`HardpointServer`), and two client scripts draw it (`HardpointPointFX` for the pylons in
the world, `HardpointHUD` for the screen). Teams reuse the squad friendly-fire checks through one additive branch in
`SquadRules`; spawns plug into `ArenaSpawnServer` through a BindableFunction; the mountain gets walkable through
`StepAssistCore`. Each piece has its own switch.

## Global constraints
- Additive only. Every changed script: new version (header + VERSION), its own switch attribute (default true; false = the
  old behaviour), rows in docs/VERSIONS.md and docs/ATTRIBUTES.md.
- Arena only: `ModeRules.currentMode() == "arena"` (Studio: Workspace attribute ModeTestArena = true). The Sandbox is
  unchanged except Task 3 (mountain steps, Kepu's ask is for the island).
- Every number lives in HardpointRules (an attribute override where marked).
- Colours: own team blue rgb(90,160,255), enemy red rgb(224,40,74), open white, contested yellow rgb(255,200,50) blinking
  with white at 4 Hz, locked grey rgb(184,190,200). Always relative to the viewer.
- Font FredokaOne; panels rgb(20,20,26) at 0.18, white stroke 0.5 / 1.5 px, corner 10 (the HUD look).
- PC and phone ship together; check both on screen (ArenaTouch force-touch hook).
- Testing: never with a second player. Two-team situations use the server-only test hook (Task 4) with dummy models counted as a
  team. Before Play: SpeciesRememberEnabled = false and SkillSaveEnabled = false in Edit; nil after. No saved progress changed.
- Install by multi_edit, verify by hash, commit + push each change. Publish only on Kepu's "Publish".

## Do-not-touch
- `ModeRules.canAffect` (signature and rows); `SquadServer` invites / joins / leaves; ArenaPvP's bridge maths.
- ArenaSpawnServer 1.0–1.2 rules (they still run when Hardpoint is off or has no spot).
- Today's HUD positions: TargetHUD (top centre), SKILLS / MENU / SQUAD pills (top right), AbilityBar, health, ArenaTouch buttons.
- SkillServer XP (player kills still give none; not in this plan).
- Island parts: Ground, Trees, Rocks, MountainSteps, Trail are not edited. Pylons sit on the ground as it is.
- Free-for-all rotation (deferred).

## Files
| File | New / changed | Job |
|---|---|---|
| src/shared/HardpointRules.luau | new ModuleScript (ServerStorage.DinoArcade; cloned to ReplicatedStorage.HardpointShared) | numbers, layout, phase maths, occupancy, scoring, team pick, spawn pick |
| tools/tests/HardpointRules.spec.luau | new | Logic tests |
| src/shared/SquadRules.luau | 1.0 → 1.1 | team branch: same team = no harm while Hardpoint is live |
| src/character/StepAssist/StepAssistCore.luau | 1.0 → 1.1 | MountainSteps ledges up to 7.5 studs |
| src/character/StepAssist/StepAssist.client.luau, src/server/StepAssistServer.server.luau | version bump if the core's call changes | pass the new filter |
| src/server/HardpointServer.server.luau | new | match, teams, occupancy, score, clock, state, test hook, spawn pick |
| src/server/ArenaSpawnServer.server.luau | 1.2 → 1.3 | ask HardpointPickSpawn first while Hardpoint is live |
| src/client/HardpointPointFX.client.luau | new LocalScript (StarterPlayerScripts) | the pylons look, current + next point |
| src/client/HardpointHUD.client.luau | new LocalScript (StarterPlayerScripts) | score card, status, next notice, marker, name tags, results |
| any damage server found without a squad check (Task 2 audit) | version bump each | add the SquadRules check |

## Deterministic map (every state)
- **Mode:** not Arena or HardpointEnabled false → nothing from this plan runs; ReplicatedStorage.Hardpoint.HpLive = false;
  every client script hides; SquadRules / ArenaSpawnServer behave as 1.0 / 1.2.
- **Phase** (`HpPhase`): `waiting` (fewer than HpMinPlayers 1 player out of the menu; nothing scores) → `warmup` (match start
  → +5 s, P1 shown LOCKED) → `live` → `results` (15 s; VICTORY / DEFEAT / DRAW) → `warmup` of a new match (teams rebalanced,
  scores 0, clock 10:00, P1).
- **Point in play:** k = floor((t − 5) / 60); index = k mod 5; into = (t − 5) mod 60; next = (k + 1) mod 5; next shown when
  into ≥ 50.
- **Occupancy** (every 0.25 s): counted = alive (Health > 0), InMenu ~= true, HardpointTeam set, HumanoidRootPart flat distance
  ≤ 45 from the centre and |dy| ≤ 40. Cloaked dinos count. (A test dummy with HardpointTestTeam counts the same.)
  0 + 0 → N; A only → A; B only → B; both → C.
- **Scoring:** each whole second of A (or B) gives that team +1. N and C give nothing.
- **Match clock:** 600 s; it runs only while occupancy is N (CoD: paused while the point is held or contested).
- **End:** a score reaches 250 → that team wins. Clock 0 → higher score wins; equal → DRAW.
- **Team pick** (join, or leaving the menu with no team): a squadmate already on a team → that team, unless that makes the gap
  greater than 2 (then the smaller team); else the smaller team; equal → the team behind on score; equal → A. Leaving the
  game removes the team. At match start every player is re-picked in squad groups, largest group first, onto the smaller team.
- **Friendly fire:** while HpLive, `SquadRules.same / sameChar` answer "same team" for two players with the same
  HardpointTeam (and ignore SquadId, so squadmates split across teams can hurt each other). HpLive false → 1.0 behaviour.
- **Spawn:** on respawn / play with HpLive and a team: the current point's spot ring (12 directions; first of radii 300, 260,
  340, 220, 380 studs whose ground is DinoIsland.Ground or MountainSteps, dry, flat (normal Y > 0.9), no Trees / Rocks /
  EdgeWalls within 18 studs); spots within 150 studs of a living enemy are skipped; best score = min(enemy distance, 350) +
  0.4 × max(0, 300 − nearest teammate distance); facing the point. No spot → ArenaSpawnServer 1.2 rules.
- **Point look** (client, relative to the viewer): N white; own team holds → blue; enemy holds → red; C → yellow / white blink;
  next point in its last 10 s before opening → LOCKED (grey, every 3rd border block hidden, beams off).
- **Marker:** label CAPTURE (N or enemy) / DEFEND (own) / CONTESTED / LOCKED m:ss; distance in studs, "ON POINT" when counted;
  clamped to the screen edge when off screen.

## Task 1 — HardpointRules 1.0 · Mode: Logic
**Files:** create `src/shared/HardpointRules.luau`, `tools/tests/HardpointRules.spec.luau` (Studio copy
ServerStorage.DinoArcadeTools.HardpointRules_spec).
**Interfaces (produces):**
- `VERSION = "1.0"`; `RADIUS = 45`, `DY = 40`, `FIRST = 5`, `POINT_TIME = 60`, `NEXT_SHOWN = 10`, `LIMIT = 250`, `CLOCK = 600`,
  `RESULTS = 15`, `TICK = 0.25`; spawn `RING_DIRS = 12`, `RING_RADII = {300, 260, 340, 220, 380}`, `NEAR_ENEMY = 150`,
  `ENEMY_CAP = 350`, `MATE_RANGE = 300`, `MATE_W = 0.4`, `MAX_GAP = 2`.
- `LAYOUT_B = {{name = "Centre Meadow", x = -100, z = -40}, {name = "East Shore", x = 450, z = 150}, {name = "Summit", x = 285,
  z = -240}, {name = "NW Foothills", x = -280, z = -270}, {name = "West Meadow", x = -450, z = 270}}` (Summit centre re-measured in
  Task 4 on the top flat; the plan's number is the grid's).
- `phaseAt(elapsed, n) -> {warmup: bool, index, into, remaining, nextIndex, showNext}`
- `occupancy(nA, nB) -> "N" | "A" | "B" | "C"`
- `inPoint(rootPos: Vector3, centre: Vector3) -> bool`
- `step(state, occ, dt) -> state` with `state = {scoreA, scoreB, clock, carryA, carryB}` (whole points from carried fractions)
- `winner(state) -> "A" | "B" | "draw" | nil`
- `pickTeam(nA, nB, scoreA, scoreB, squadTeam) -> "A" | "B"`
- `ringSpots(centre, okFn) -> {Vector3}`; `pickSpawn(spots, enemies, mates) -> Vector3?`
- [ ] Step 1: write the spec: every branch above (warmup edge 4.99 / 5.0; into 49.99 / 50; point 5 → 1 wrap; N/A/B/C; 0.25 s
  ticks → 4 per point; clock frozen while A/B/C; 250 exactly; clock 0 with tie → draw; pickTeam all rows; pickSpawn: enemy at
  149 skipped, cap, teammate bonus, no spot → nil; the three mockup situations give the mockup's sides on all 5 points).
- [ ] Step 2: run it in Studio Edit, see it fail. Step 3: write the module. Step 4: PASS n. Step 5: install + hash, commit.
**Acceptance:** spec PASS; module has no Instance writes.

## Task 2 — SquadRules 1.1 team branch + damage-path audit · Mode: Logic + Wired
**Files:** modify `src/shared/SquadRules.luau`; audit every server that lowers health / DummyHealth.
**Interfaces:** consumes player attribute `HardpointTeam` ("A" / "B" / nil) and ReplicatedStorage attribute `HardpointLive`.
`same` / `sameChar` 1.1: if `HardpointLive == true` and the switch ReplicatedStorage `HardpointTeamRules ~= false` → answer by
team (both teams non-empty and equal; a model's team = its player's, else its `HardpointTestTeam`); otherwise 1.0.
- [ ] Spec rows in tools/squad_rules_test.luau for the team branch (live / not live / switch off / split squad).
- [ ] Audit: list every damage server; for each, whether it calls SquadRules before harming a player. Found 2026-11-10 without
  a SquadRules mention: PachyStatsServer, EnergyShieldServer (plus BotServer / BiteDummy / BiteTargetHealth / DinoHealthServer /
  ArenaPvP, which are bot / bridge paths). Each real player-harm path missing the check gets one, behind its own switch.
- [ ] Play: a team-B test dummy next to your dino: every attack of the 8 dinos that can hit it does 0 damage to a team-A dummy
  and normal damage to a team-B dummy.
**Acceptance:** spec PASS; the audit table in a ticket note; Play results per dino.

## Task 3 — StepAssistCore 1.1 walkable mountain steps · Mode: Wired
**Files:** modify `src/character/StepAssist/StepAssistCore.luau` (and the two callers only if the call signature changes).
**Change:** the ledge rays also hit `Workspace.DinoIsland.MountainSteps`; a ledge on a MountainSteps part may be up to
`StepAssistMountainMax` (DinoIsland attribute, default 7.5) high; lift time grows with height (0.12 s per 2.6 studs, at most
0.3 s). Switch: DinoIsland attribute `StepAssistMountainEnabled` (default true; false = 1.0).
- [ ] Play: each of the 8 dinos walks (no jump) from the summit point's spawn ring to the top. Time each run; screenshot a lift
  from the game camera.
**Acceptance:** every dino reaches the top without jumping; times in a ticket note; Sandbox and Arena both; switch off = 1.0.
**Decision gate:** if the slowest dino needs more than 20 s, show Kepu the numbers before Task 4's summit timing is final.

## Task 4 — HardpointServer 1.0 · Mode: Wired (+ Logic from Task 1)
**Files:** create `src/server/HardpointServer.server.luau`.
**Interfaces (produces):** ReplicatedStorage folder `Hardpoint` with attributes `HpLive`, `HpPhase`, `HpMatchStartAt`,
`HpIndex`, `HpNextIndex`, `HpShowNext`, `HpPointEndsAt`, `HpOcc` ("N"/"A"/"B"/"C"), `HpScoreA`, `HpScoreB`, `HpClock`,
`HpWinner`, `HpResultsEndAt`, `HpPoints` (JSON: name, x, y, z per point; y = ground under the centre); ReplicatedStorage
`HardpointLive` (mirror of HpLive) and `HardpointShared` (module copy); player attribute `HardpointTeam`; BindableFunction
`HardpointPickSpawn` (player) -> CFrame?; server-only BindableFunction `HardpointTest` (action, ...) for Studio tests:
`"team", model, "A"/"B"` (sets HardpointTestTeam on a dummy), `"skip"` (next point), `"score", a, b`, `"clock", s`.
Script attributes: `HardpointEnabled` (true), `HpMinPlayers` (1), diagnostics `HardpointServerVersion`, `HpTicks`.
- [ ] Phases, occupancy, scoring, clock, end, results, new match exactly as the deterministic map.
- [ ] Teams: pick on join / play; rebalance at match start; clear on leave.
- [ ] Spawn pick through HardpointRules.ringSpots / pickSpawn with the ground check above.
- [ ] Play (Arena test switch): a full scripted pass with the hook: warmup → P1 → skip through all 5 → contested with a team-B
  dummy → score to 250 → results → new match.
**Acceptance:** each attribute changes as mapped (logged numbers in a ticket note); switch off → HpLive false, nothing runs.

## Task 5 — ArenaSpawnServer 1.3 · Mode: Wired
**Files:** modify `src/server/ArenaSpawnServer.server.luau`.
**Change:** before the 1.2 squad rule, while ReplicatedStorage.HardpointLive and the player has a HardpointTeam, call
`HardpointPickSpawn`; a CFrame → place there (same standing / facing / camera hook as today; facing the point); nil → 1.2.
Switch `ArenaSpawnHardpointEnabled` (default true). Diagnostics: player ArenaSpawnKind "hardpoint".
**Acceptance:** Play: dying with a team-B dummy placed on the west side respawns you on the far side; dummy moved → spawn flips;
switch off → 1.2.

## Task 6 — HardpointPointFX 1.0 (look C) · Mode: Wired
**Files:** create `src/client/HardpointPointFX.client.luau`.
**Layout (from the mockup, studs):** 10 pylons on the radius-45 circle, each on the ground under it: base 4.4×1.2×4.4 (dark
rgb(35,42,51)), column 3×7.5×3 (metal rgb(58,66,80)), hazard band 3.3×1.1×3.3 (yellow / black), cap 3.6×1×3.6 (dark), lamp
2.2×1.6×2.2 Neon (state colour); two Neon beams between neighbours at 8.4 and 3.2 studs above the ground (0.45×0.45, top
transparency 0.15, low 0.45, flicker); 72 Neon border blocks 2.6×0.7×3.4 on the ground, brightness wave running round
(sin(9a − 5t)). All parts anchored, CanCollide / CanQuery / CanTouch false, CastShadow false, in a client-only folder.
Built for the current point; the next point is built in LOCKED look for its last 10 s. Colour refresh 20 Hz.
Switches: `HardpointPointFXEnabled`, `HardpointPointFX_detail` (2 = full, 1 = 36 border blocks and the low beam off).
**Acceptance:** every state looks like the mockup from the game camera (screenshots); ~150 parts per point; PC FPS steady;
phone check by Kepu (fallback detail 1).

## Task 7 — HardpointHUD 1.0 (PC + phone) · Mode: Wired
**Files:** create `src/client/HardpointHUD.client.luau`.
**Layout:** ScreenGui `HardpointHUD` (DisplayOrder 6, ScreenInsets DeviceSafeInsets, ResetOnSpawn false), shown only while
HpLive and InMenu ~= true.
- Score card: AnchorPoint (0, 0) at (0, 16, 0, 58) (under Roblox's top bar); width clamp(26% of the screen, 220, 330) px. Emblem
  square (own team blue), two rows: own score (blue bar + number), enemy score (red); right column: match clock m:ss (+ ❚❚
  while paused) and "P{n} · m:ss" (yellow).
- Status line under the card (8 px gap): GET READY / POINT OPEN / SECURED · +1 / s / ENEMY HAS THE POINT / CONTESTED.
- Next notice under it in the last 10 s: "NEXT: P{n} {NAME} IN 0:0s".
- Marker: screen-projected each frame from the point centre + 34 studs: label, diamond with the number, distance; clamped to
  the screen edge (smaller) when off screen or behind.
- Name tags: BillboardGui over every other counted player's head, own team blue / enemy red (FredokaOne 14).
- Results: centre panel VICTORY / DEFEAT / DRAW + "a – b" + "NEXT MATCH IN 0:ss".
**Acceptance:** PC and forced-touch screenshots for warmup, open, held, enemy, contested, next notice, results; no overlap with
SKILLS / MENU / SQUAD, TargetHUD, AbilityBar, health or the touch buttons.

## Task 8 — Docs + Studio check · Mode: Wired
VERSIONS / ATTRIBUTES rows; Studio = repo by hash; no ZZ_ leftovers; test switches unset; not published until "Publish".

## Accepted risks / open (red-team below)
See the red-team section added after Kepu's review.
