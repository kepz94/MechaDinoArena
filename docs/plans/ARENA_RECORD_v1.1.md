# Mecha Dino Arena v1.1: Arena W-L outside the pre-game (drafted 2026-11-13)

**Goal:** your Arena W-L shows on the main menu (record, win %, last 10, streak), on the match results (record before → after) and under your name on the island so other players see it.
**Chosen direction:** C · B + name tag (Kepu 2026-11-13), mockup docs/mockups/wl_record_v0.1.html (artifact FzB5jtwdeFgaLo1W7UkMLQ).
**Architecture:** the record (ArenaRecordRules / ArenaRecordServer, v1.0 plan docs/plans/PREGAME_LINEUP_v1.0.md) gains a last-10 string and a streak. ArenaRecordServer publishes them as player attributes and, per Arena result, the outcome and the record before it. Three client pieces read those attributes: MainMenu (record block), HardpointHUD (a line on the results banner) and a new IslandTags script (name + W-L over each player's dino on the hub island).

## Global Constraints
- Additive only; every change behind its own switch (script attribute); every number an attribute.
- Version-brand script headers, docs/VERSIONS.md, docs/ATTRIBUTES.md.
- PC and phone ship together. Player-facing text: only the record, nothing explanatory.
- Studio test: ArenaRecordSaveEnabled=false, SkillSaveEnabled=false, SpeciesRememberEnabled=false; no second player.
- W-L counts Arena 4v4 matches only (D1). Bots matches and public Hardpoint show no record line.

## Do-not-touch
- ArenaRecordRules.outcome / eligible and the D5 / D9 / D11 / D12 rules (PREGAME_LINEUP_v1.0).
- PracticeServer 1.10 (its "result" / "left" calls stay as they are).
- PregameScreen 1.1 plaques (they already read ArenaW / ArenaL).
- MainMenu's PLAY, chip, BACK TO ISLAND, dino picker and slots. HardpointHUD's spotlight and board beats.
- TeamTags 1.1 (Hardpoint markers) and BiteTargetHealth plates.

## Impact map
| Script (current) | Change | New |
|---|---|---|
| src/shared/ArenaRecordRules.luau 1.0 | record gets `last` ("w"/"l" string, newest last, ≤ LAST_N 10) and `s` (streak: +n wins / −n losses); clean keeps them; apply updates them; new streakText | 1.1 |
| src/server/ArenaRecordServer.server.luau 1.1 | player ArenaLast, ArenaStreak; per result ArenaMatchId, ArenaMatchOut ("w"/"l"/"n"), ArenaMatchFrom ("w-l" before) | 1.2 |
| src/client/MainMenu.client.luau 1.25 | record block in the right column under the title (where the hidden SANDBOX / ARENA buttons sat) | 1.26 |
| src/client/HardpointHUD.client.luau 1.10 | banner beat: a record line + last-10 squares, Arena 4v4 only (Practice PrArena == true) | 1.11 |
| src/client/IslandTags.client.luau | NEW: name + W-L over every player's dino on the hub (ServerKind "hub") | NEW 1.0 |

## Deterministic map
**Record fields (ArenaRecordRules 1.1 apply(record, out, matchId)):**

| Case | w / l | last | s | lastMatch |
|---|---|---|---|---|
| out not "w"/"l" | same | same | same | same |
| matchId == lastMatch (≠ "") | same | same | same | same |
| out "w" | w+1 | last .. "w", keep the last 10 | s > 0 → s+1, else 1 | matchId |
| out "l" | l+1 | last .. "l", keep the last 10 | s < 0 → s−1, else −1 | matchId |
| old record without last / s | as above, from "" and 0 | | | |

clean: `last` = only the letters w / l, the last 10; `s` = whole number, clamped to ±9999; bad → "" / 0.

**Result attributes (ArenaRecordServer 1.2, on "result" for each listed player):**

| Condition | ArenaMatchOut | ArenaMatchFrom |
|---|---|---|
| outcome "w" | "w" | ArenaW-ArenaL before the write ("-" when not loaded) |
| outcome "l" | "l" | same |
| outcome nil (not eligible, draw, team had a leaver) | "n" | same |
| writes off / no store (Studio) | the same outcome as above (shown, not saved) | same |
ArenaMatchId = the matchId, set last (clients key on it). Set before the DataStore write, so the banner never waits on it.

**Results banner line (HardpointHUD 1.11, banner beat):**

| Condition | Shown |
|---|---|
| Practice PrArena ~= true, or ArenaMatchId is still the value this client saw when HpPhase was last "live" (no result for this match yet) | nothing (banner as 1.10) |
| out "w" | RECORD  31-12 → 32-12  [+1 W green] + squares (new one last) |
| out "l" | RECORD  31-12 → 31-13  [+1 L pink] + squares |
| out "n" | RECORD  31-12  [RECORD UNCHANGED grey] + squares unchanged |
| ArenaMatchFrom "-" | RECORD  —  + tag only |

**Main menu block (MainMenu 1.26):**

| Condition | Shown |
|---|---|
| ArenaRecordReady ~= true | block hidden |
| ready, 0-0 | ARENA RECORD / 0-0 / no squares, no streak |
| ready | ARENA RECORD / w-l, "nn% WINS" / up to 10 squares (oldest left) / "n WIN STREAK" (green) when s ≥ 2, else no streak line (Kepu Q2: win streaks only) |

**Island tag (IslandTags 1.0):**

| Condition | Shown |
|---|---|
| ServerKind ~= "hub" or switch off | nothing |
| a player's dino within IslandTagsMax (80) studs, on screen, in front of the camera | name (DisplayName) + W-L under it in orange |
| that player's ArenaRecordReady ~= true | name only |
| your own dino | shown too (Kepu Q3: "Yourself too") |
| player in the menu (InMenu) / no character | nothing |
Drawn as screen Frames projected each frame (TeamTags 1.1 found AlwaysOnTop BillboardGuis did not draw).

## Tasks
| T | Name | Mode | Depends |
|---|---|---|---|
| T1 | ArenaRecordRules 1.1 + spec: last / s in clean, apply, streakText(s) | Logic | — |
| T2 | ArenaRecordServer 1.2: ArenaLast / ArenaStreak on load and write; ArenaMatchOut / From / Id on "result"; switch ArenaRecordMatchAttrsEnabled | Wired | T1 |
| T3 | MainMenu 1.26 record block; switch MainMenuArenaRecordEnabled | Wired | T2 |
| T4 | HardpointHUD 1.11 banner record line; switch HardpointHUDRecordLineEnabled | Wired | T2 |
| T5 | IslandTags 1.0; switches IslandTagsEnabled, IslandTagsMax (80), IslandTagsMaxCount (12) | Wired | T2 |

Studio test: Arena test match (PrArenaMatchTest) with saves off → ArenaMatchOut "n" (not eligible) → banner shows RECORD UNCHANGED; test hook sets ArenaW/L/Last/Streak to fake values to check the menu and the tag on PC and phone sizes.

## Kepu's answers (2026-11-13)
| # | Answer |
|---|---|
| Q2 | Streak: win streaks only (shown at 2+). A losing run shows no streak line. |
| Q3 | Island tag: you see your own tag too. |

## Red-team (2026-11-13), outcome
| Challenge | Outcome |
|---|---|
| The banner beat is 2 s, so the record line can be missed | Accepted: Kepu picked the mockup with the line on the first beat. The menu shows the saved record after. |
| The banner shows "→ 32-12" before the DataStore write is done; a failed write would show a +1 W that was not saved | Accepted: the banner is computed from ArenaMatchFrom + ArenaMatchOut; the menu (ArenaW / ArenaL) changes only on a saved write. |
| Mixed servers right after publish: an old ArenaRecordServer 1.1 write uses ArenaRecordRules 1.0 clean, which drops last / s | Accepted: at worst one player's last-10 / streak restarts; w / l are never lost. |
| Island clutter: every dino gets a tag | Mitigated: IslandTagsMax 80 studs and IslandTagsMaxCount 12 (nearest first). |
| Bots (practice) and public Hardpoint must not show a record line | Mitigated: the line needs Practice PrArena == true and a new ArenaMatchId. |
