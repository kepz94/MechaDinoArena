# Mecha Dino Arena — Territories + bigger raptors v1.0

**Goal:** you only meet T-Rex bots in one part of the island and raptor bots in another. Bots don't fight each other. Raptors are big enough to see from the T-Rex camera.

**Kepu's answers (2026-10-28):**
- Layout **A, left / right halves** (docs/mockups/territory_options.png).
- Raptors **2x** (5.4 → about 11 studs tall), **bots and players**.
- A chasing bot **stops at the border**.
- Bots never fight each other: "turn off bots fighting against each other".

## Global constraints
- Studio target: the cloud place Mecha Dino Arena, **placeId 84022023159448**. Check `game.PlaceId` before every install.
- Additive only. Every change gets a header vX.Y, a changelog line, a version attribute, a VERSIONS row and an ATTRIBUTES section.
- Every change has an on/off attribute.
- Install check: hash plus a loadstring compile.

## Facts read in the code (MechaDinoArena @ 60e70e8)
- **Island:** IslandHalfSize 940 (x and z from −940 to 940). SpawnLocation at (88, 0, 904), near the +z edge.
- **Marker bots (DinoIsland.BotSpawns):**
  - Raptor at (238, 446): right side.
  - Raptor at (−90, −462): left side.
  - Raptor at (−153, 477): left side.
  - T-Rex at (60, 350): right side.
- **Roaming groups (BotServer 1.8):** 4 raptor groups and 1 T-Rex group. Their spots come from BotRoam.pickSpot / respawnSpot, with `opts` carrying `limit` and `avoid`.
- **Bot vs bot fights:** BotServer 1.9 has script attribute `BotFightEnabled` (default true). `BotHuntEnabled` covers prey, and prey is off in Mecha.
- **Raptor size:** 12.7 long × 5.4 tall (DinoModelBuilder build of RaptorModelData). T-Rex: 40 × 20.
  - Player raptors: SpeciesServer builds `raptorTemplate` and clones it.
  - Raptor bots: BotServer builds them the same way.
  - Both have `Species` / `BotSpecies` "Raptor".
- **What already follows Model:ScaleTo** (built for growth): hitboxes (inside the model), IdleAnimation 1.24 re-fit, ShoulderCam 1.1 re-fit, CameraZoom 1.1 (on a `CameraStartZoom` change). The growth distance keys (GrowthCurve.DISTANCE_KEYS) are BiteReachBack, BiteLungeDist, PounceDistance, PounceReach, PounceLatchStandoff, EatRange, EatHeight, CameraStartZoom, ShoulderCamDistance.
- **Pounce rule:** PounceSizeRatio 1.5 decides latch vs pin. A 2x raptor (25 long) on the T-Rex (40) is a ratio of 1.6, so it still latches; two raptors still pin.

## Do-not-touch
- BotServer's player bite, pounce, pack and shake-off code. GrowthServer stays off. SpeciesServer / DinoModelBuilder code.
- Bot health and speeds. Player stats are left to StatServer and SkillEffects.

### Task 1 — Territory 1.0 · Mode: Logic
**Files:** Create `src/shared/Territory.luau` and `tools/tests/Territory.spec.luau`.

**Interfaces (Produces):**
- `Territory.ZONES`:
  - TRex: `x <= -40`;
  - Raptor: `x >= 40` and `z <= 560`;
  - both: not within `SPAWN_SAFE` 300 studs of `SPAWN` (88, 904).
- `Territory.inside(species, x, z) -> boolean`. A species that isn't in ZONES → true (no limit).
- `Territory.home(species, pos) -> Vector3`. pos when it's inside. Otherwise the x-mirrored point when that's inside. Otherwise nil (the caller then picks a spot).
- `Territory.pathInside(species, from, to) -> boolean`. Every 8 studs along the flat line is inside.

**Acceptance:** the spec covers both zones, the gap at x ±40, the spawn circle, the mirrors of the 4 markers, and an unknown species.

### Task 2 — BotRoam 1.1 · Mode: Logic
**Files:** Modify `src/shared/BotRoam.luau` (additive).
- `opts.inside(x, z)` is optional.
- pickSpot / respawnSpot candidates must be inside, and pathOk samples must be inside (else the reason is "outside").
- Without `opts.inside`, everything works as in 1.0.

**Acceptance:** the BotRoam spec still passes, and new cases pass.

### Task 3 — BotServer 1.12 · Mode: Wired
**Files:** Modify `src/server/BotServer.server.luau` and `src/server/BotServer.meta.json`.
- **Switch:** script attribute `BotTerritoryEnabled` (default true). Everything below happens only while it's on.
- **Home.** A marker bot's home goes to `Territory.home`; if that's nil, a respawnSpot inside its zone.
- **Wander.** A wander point outside the zone is replaced by the home.
- **Roam.** `roamOpts().inside` is set per group species.
- **Chase.**
  - A player is only picked while inside the bot's zone.
  - A chased player who leaves the zone is dropped (BotState "border"), and the bot walks back.
  - Animal targets are already off (no fights).
- **Fights off.** `BotFightEnabled = false` in the place and in meta.json.
- **Diagnostics:** bot `BotTerritory` ("TRex" / "Raptor"), `BotBorderDrops`; script `BotTerritoryState`.

**Acceptance (Play):**
- After 2 minutes, every bot is inside its zone.
- Leading a chasing bot over the border makes it stop.
- No bot fights (`BotFightBites` stays 0).

### Task 4 — RaptorScale 1.0 · Mode: Wired
**Files:** Create `src/server/RaptorScale.server.luau`.
- Every player character with Species "Raptor", and every bot with BotSpecies "Raptor", gets `Model:ScaleTo(RaptorScale)` once at spawn (default 2).
- The distance keys present (GrowthCurve.DISTANCE_KEYS, else GrowthServer's FALLBACK) are multiplied by the same factor.
- Diagnostics: model `RaptorScaleApplied`; script `RaptorScaleVersion`.
- Settings: `RaptorScaleEnabled` (default true), `RaptorScale` (2).

**Acceptance (Play):**
- Player raptor and raptor bot are both about 11 studs tall.
- The camera frames the bigger raptor.
- Pounce still latches on a T-Rex bot and pins a raptor bot.
- Bites and hitboxes line up.

### Task 5 — ArenaScope 1.3 · Mode: Wired
Expects RaptorScale on, and reports bot fights off (`ArenaScope_BotFight`).

## Red-team (brief)
1. **Bigger raptor, same leap and speed.** Leap height and run speed stay in studs, so a 2x raptor jumps relatively lower and looks slower. Accepted for now; tune later if Kepu wants.
2. **Border camping.** Players can stand just over the border and bots won't follow (Kepu's choice: stop at the border). Accepted.
3. **T-Rex zone near spawn.** The left half reaches the spawn side, so `SPAWN_SAFE` 300 keeps T-Rex bots at least 300 studs from spawn.
4. **Pounce ratio 1.6 vs 1.5.** A raptor-on-T-Rex latch is close to the limit. A future raptor size above 2.1x would turn latches into pins; checked in the Task 4 acceptance.
