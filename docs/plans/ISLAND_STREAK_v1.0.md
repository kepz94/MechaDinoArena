# Mecha Dino Arena v1.0 — Island Kill Streak (roadmap piece 3)

**Goal:** kills on the main island count up into a streak while you stay alive. A fire emblem on your name tag shows it to everyone nearby. A 10 streak unlocks Zebra and a 25 streak unlocks Storm Front.
**Kepu 2026-11-26 03:55:** "a fire streak emblem once you go on a killing spree on the main island. 25 kills streak unlocks the thunder storm skin. 10 kill streak unlocks the zebra." Roadmap decisions:
- D3: the streaks replace the old unlocks (Zebra "Win 15 Arena matches", Storm Front 999 Robux).
- D4: kills of players and bots count, main island only, reset on death.

**Picks (05:1x, mockup `docs/mockups/island_streak_v0.1.html`, artifact "Island Kill Streak"):**
- Look: "A · Tag flame" (on the island name tag; others see it, nothing new on your own HUD).
- Flame at: "After first kill".
- Reset: "Death or menu".
- Storm Front: "Earn only".

**Architecture:** additive steps in the existing kill-stats chain.
- **SkinStats 1.1** already receives every credited kill (KillFeedServer / KillRegenServer KillCredit, deduplicated). It now also keeps the current island streak and the saved best island streak.
- **UniversalSkins 1.4** gives Zebra and Storm Front a new earn stat, `istreak`.
- **SkinServer** passes that stat into its existing earn check.
- **Lab** shows progress the same way it does for the other earn skins.
- **IslandTags 1.7** draws the flame badge from the player attribute `IslandStreak`.

## Grounding (repo = Studio after v1020)
- **SkinStats 1.0** (`onKill(userId, victim, at)`):
  - Listens to KillCredit on KillFeedServer (player kills on bridged servers, practice and persona bots) and KillRegenServer (IsBot models: the island's filler bots).
  - Counts one death once (victim + KilledAt).
  - Saves `{v = 1, k, best}` with UpdateAsync (merge).
  - Publishes StatKills and StatBestStreak.
  - Save switch: SkinStatsSaveEnabled.
- **UniversalSkins 1.3:**
  - `zebra = earn("wins", 15, "Win 15 Arena matches")`; `storm = robux("LEGENDARY", 999)`.
  - `US.progress(id, stats)` reads stats.w / l / kills / best.
- **SkinServer:**
  - `statsOf(player)` builds those stats.
  - `checkEarn` writes every met earn skin to owned, and runs when the player attributes in `WATCH` change (ArenaW, ArenaL, ArenaStreak, StatKills, StatBestStreak, ArenaRecordReady, SkinStatsReady).
  - A "buy" of an earn skin is refused ("earnOnly"). Skins already owned stay owned (buyers of Storm Front keep it).
- **Lab:** `uniStats()` (line ~988) holds the same stats for the earn cards. The card text is `unlock.text`.
- **ShopScreen** lists only robux skins, so Storm Front drops out of the shop by itself.
- **Island server and bots:**
  - The island is the server where ReplicatedStorage `ServerKind == "hub"` (HubServer).
  - The only bots on the island are FillerServer's fighting persona bots. BotServer is disabled. Tutorial lanes are marked by the player attribute `TutLane > 0`.
- **IslandTags 1.6:**
  - One line, `[rank badge] NAME 1W 0L`, centred over the head.
  - Silkscreen; filler bots tagged too.
  - The group is laid out per frame (v1.4): the badge width plus the name width plus the record.

## Global Constraints
- Additive. Every piece has its own switch (default on; off = the old behaviour exactly). Every number is an attribute.
- Versions: UniversalSkins 1.4, SkinStats 1.1, SkinServer (next), Lab (next), IslandTags 1.7.
- Phone first; the flame and count are readable at the tag's phone sizes. Game copy: no em dashes, short.
- Studio tests with the save switches off. Never a second player. Publish only on "Publish".

## Do-not-touch
- Kill credit sources (KillFeedServer, KillRegenServer), KilledAt stamping, HubServer / HubSafe.
- The Arena win streak (ArenaStreak, StatBestStreak, Ink War).
- Every other skin's unlock and price; ShopScreen; ORDER (Storm Front keeps its place in the list).
- Kill feed; own HUD (no streak pill, by the pick).

## Tasks

### Task 1 — UniversalSkins 1.4 · Mode: Logic
**Files:** `src/shared/UniversalSkins.luau` (Studio: ServerStorage.DinoArcade.UniversalSkins + the ReplicatedStorage.SkinShared copy made by SkinServer), test `tools/tests/UniversalSkins14.spec.luau`.
**Produces:**
- `US.ISLAND_STREAK_UNLOCKS = true` (module flag; false = 1.3).
- When true:
  - `zebra.unlock = earn("istreak", 10, "Get a 10 kill streak on the island")`
  - `storm.unlock = earn("istreak", 25, "Get a 25 kill streak on the island")`
- `US.progress` reads `stats.istreak` for stat "istreak".
- Storm Front's look, `anim` and ORDER place stay the same.

**Spec:**
- zebra progress with istreak 4 → 4 / 10, unlocked false; with 10 → true.
- storm with 25 → true; storm is earn.
- Desert / Riverstone / Ink War are unchanged.
- No other skin's unlock changed (compare kinds and needs for every id against the 1.3 list).

### Task 2 — SkinStats 1.1 · Mode: Wired
**Files:** `src/server/SkinStats.server.luau`.
**Produces:**
- Player attribute `IslandStreak` (current, whole number) and `StatIslandBest` (saved best).
- Script attributes:
  - `SkinStatsIslandStreakEnabled` (true)
  - `IslandStreakCounted` (count)
  - `IslandStreakResets` (count)
- **Counting** (in `onKill`, after the dedupe, only when): the switch is on, `ServerKind == "hub"`, the killer's `TutLane` is not > 0, and the killer's character is alive. Then:
  - IslandStreak += 1.
  - `StatIslandBest = max(StatIslandBest, IslandStreak)`; marks best dirty.
- **Reset to 0** on each of these (`IslandStreakResets` counts them):
  - the killer's Humanoid.Died;
  - a new character;
  - the player's InMenu turning true.
- **Save:**
  - UpdateAsync also writes `ib = max(stored ib, ours)`; the load reads `ib`.
  - v stays 1. A save made by 1.0 keeps the field, since the update merges.

### Task 3 — SkinServer (next version) · Mode: Wired
`statsOf` adds `istreak = max(StatIslandBest, IslandStreak)`. `WATCH` adds `IslandStreak` and `StatIslandBest`. Switch `SkinIslandStreakEarnEnabled` (true; false = istreak 0, so streak skins stay locked).

### Task 4 — Lab (next version) · Mode: Wired
`uniStats()` adds the same `istreak`. The Zebra / Storm Front cards then show the new text and progress through the existing earn card path. No layout change.

### Task 5 — IslandTags 1.7 · Mode: Wired
**Layout:**
- The flame badge goes first in the one line, left of the rank badge: `[flame N] [rank] NAME 1W 0L`. The whole group stays centred.
- Badge: a dark plate (#0B0F16, 0.2 transparent) with a 2 px tier-coloured outline and round corners. In it, a pixel flame (7 × 9 cells, drawn as row runs of Frames) and the count, in Silkscreen Bold white.
- Height = the name line height. Gap 5 px, as the rank badge.

**Tiers:**
- 1–9 orange (flame #FF5A1E / #FF9B2E / #FFE45C, outline #FF8A1E);
- 10–24 blue (#2B7BFF / #4FB6FF / #D8F3FF, outline #4FB6FF);
- 25+ violet (#7A2BFF / #B86BFF / #F2E3FF, outline #B86BFF).

**Behaviour:**
- Shown when that player's `IslandStreak >= IslandTagsStreakMin` (1).
- A short scale pop (1.4 → 1 over 0.3 s) when the count goes up.
- The flame flickers (two-step, 0.25 s) unless the player's reduced-motion setting is on.
- Players only (filler bots never have IslandStreak).

**Switch:** `IslandTagsStreakEnabled` (true). Numbers: `IslandTagsStreakMin` (1), `IslandTagsStreakTier2` (10), `IslandTagsStreakTier3` (25).

### Task 6 — Check, docs · Mode: Wired
**Studio, hub Play, save switches off:**
- A bot kill off the islet → IslandStreak 1 and the flame on your tag (phone and PC).
- 9 more → 10 → Zebra earned ("earned" toast, Lab card UNLOCKED).
- Set the streak to 25 by test attribute → Storm Front earned.
- Death → 0 and the flame gone; menu → 0; a kill in a tutorial lane → not counted.

Then VERSIONS / ATTRIBUTES, commit, Dev Hub ticket.

## Red-team (to answer before build)
1. **Storm Front becomes free.** A 999 Robux skin turns into a reward for 25 island kills in one life. With 8 fighting filler bots that is a real grind, but a bot kill counts the same as a player kill. Options:
   - accept;
   - only player kills count toward the 25 (bots still count for the flame and Zebra).
2. **The flame is on almost everyone.** "After first kill" means nearly every living player carries a flame. Accepted by the pick; the tier colours (10 blue, 25 violet) carry the "spree" meaning.
3. **Player kills can't be tested in Studio.** We never test with a second player, so only bot kills are checked there. Player kills use the same KillCredit path (KillFeedServer → SkinStats), so the first live player kill is the real check.
4. **Order next to the rank badge.** The flame goes left of the rank badge (`[flame] [rank] NAME`). The other way round is `[rank] [flame] NAME`.
