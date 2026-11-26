# Mecha Dino Arena v1.0 — Universal Skill Points (roadmap piece 2)

**Goal:** one account level and one points pool for every dino, plus bonus skill points that the Quest Stand (piece 4) can pay out.
**Kepu 2026-11-26:** "the daily quest rewards will be skill points for the basic daily quest"; "Skill points are universal"; "Make all points universal"; "move to piece 2". Picks (04:4x): "Full pool on every dino", "Highest dino's XP", quest points "Yes, past 40".
**Chosen direction:** Full pool on every dino. There is one account XP, so one level. Every dino can spend all the account's points on its own build. Builds, loadouts and saved loadouts stay per dino. Bonus points from quests stack on top of the level points and can go past 40. Mastery 3 still applies.
**Architecture:** a new pure module SkillPool 1.0 (ServerStorage.DinoArcade) holds the maths: migration, points earned, bonus checks. SkillServer 1.15 keeps one account XP in the same d.xp field. It does not swap d.xp when the dino changes. Saves keep v = 2 and add two top-level fields, uxp and bonus, so the 1.14 code path still reads them. A new BindableFunction, SkillGrantPoints, is the only way to add bonus points. Everything sits behind the switch SkillUniversalEnabled.

## Grounding (repo = Studio, SkillServer 1.14 hash 38997 / 1828759021; Studio SkillTestMaxAllEnabled false, SkillTestCloakEnabled false)
- **Points today.** `publish` and `buy` compute `earned = ST.pointsOf(ST.levelOf(d.xp))`. pointsOf = min(level − 1, MAX_POINTS 40), MAX_LEVEL 41, xpToNext(L) = 30 + 10 (L − 1), so level 41 = 9000 XP. A full starred line costs 1 + 2 + 3 + 4 = 10.
- **Per-dino records today (1.2).** `d.dinos[key] = {xp, steps, loadout}`. `switchTo` stashes the active fields into the record and loads the new dino's `xp`, `steps` and `loadout`. Kill XP (`credit`) and `SkillGrantXp` add to `d.xp`, the active dino's record.
- **Save today (1.14).** Store = SkillSaveStoreName ("MDA_Skills_v3"), value `{v = 2, dinos = {[key] = {xp, steps, loadout, saved}}}`. `cleanRecord` resets a build that costs more than `pointsOf(levelOf(record xp))`. Any value without v = 2 counts as "new".
- **Readers of the player attributes.** SkillLevel, SkillPoints, SkillSpent, SkillLeft are read by:
  - Lab 1.x: LV / PTS labels; `ST.canBuy(..., SkillPoints, ...)`.
  - Tutorial and TutorialServer: step 8 SkillSpent / SkillLeft; LEVEL text.
  - PracticeServer: roster `lv`.

  None of them assume per dino; they read the active values. GrowthServer is off and uses its own GrowthSkillPoints.
- **Copy.** Tutorial step 9 says "1 every level. Kills give XP." That stays true. The text "Points from any dino count." is behind TutUnlockTextOn (off). No UI layout or text changes.

## Global Constraints
- Additive. Switches default true; false gives 1.14 behaviour exactly. Every number is an attribute.
- Version tags: SkillPool 1.0, SkillServer 1.15.
- Studio tests use a test save store (SkillSaveStoreName = "MDA_Skills_test_up") and the standing save switches. Never Kepu's real store; restore after.
- Publish only on "Publish".

## Do-not-touch
SkillTree (maths, costs, caps, Mastery 3), Lab, Tutorial, TutorialServer, PracticeServer, GrowthServer, DinoOwnership, the test layers (1.4–1.13 stepsFor / buyBase / testParts), saved loadouts (1.12), the per-dino builds and loadouts, the store name.

## Tasks

### Task 1 — SkillPool 1.0 · Mode: Logic
**Files:** create `src/shared/SkillPool.luau` (Studio: ServerStorage.DinoArcade.SkillPool), test `tools/tests/SkillPool.spec.luau`.
**Interfaces (produces):**
- `SkillPool.accountXp(value) -> number`. Returns the max of `value.uxp` and every `value.dinos[k].xp` (each floored; non-numbers and negatives count as 0). A nil or bad value gives 0.
- `SkillPool.cleanBonus(n) -> number`: a whole number ≥ 0, clamped to `BONUS_MAX` (default `math.huge`, i.e. no cap, per "Yes, past 40"); anything else gives 0.
- `SkillPool.earned(xp, bonus, ST) -> number` = `ST.pointsOf((ST.levelOf(xp))) + SkillPool.cleanBonus(bonus)`.
- `SkillPool.grantOk(amount) -> bool`: a whole number, 1 .. `GRANT_MAX` (100).
- `SkillPool.Version = "1.0"`.

**Steps:** write the spec first (fails: no module), then the module, then the spec passes in Studio Edit.

**Spec cases:**
- accountXp: {} → 0; one dino 500 → 500; dinos 500 / 2000 → 2000; uxp 3000 with dinos 500 → 3000; uxp "x" → dinos' max; negative and NaN values → 0.
- cleanBonus: 5 → 5; −1 → 0; 2.5 → 0; "3" → 0.
- earned: (0, 0) → 0; (9000, 0) → 40; (9000, 7) → 47; (180, 2) → 4 + 2 = 6, where 180 XP is exactly level 5 (30 + 40 + 50 + 60 = 180).
- grantOk: 1 and 100 pass; 0, 101, 1.5 and "1" fail.

### Task 2 — SkillServer 1.15 · Mode: Wired
**Files:** modify `src/server/SkillServer.server.luau` (pairs patch `tools/universalpoints_patch1.luau`).
**Interfaces:** consumes SkillPool 1.0. Produces:
- **BindableFunction `SkillGrantPoints`** (child of SkillServer):
  - Call: `Invoke(player, amount, reason)`.
  - Returns `"ok", before, after` (bonus totals), or `"disabled"` (SkillEnabled, SkillGrantPointsEnabled or universal off), `"notLoaded"`, or `"badArg"`.
- **Player attributes:**
  - `SkillBonusPoints` (the bonus total)
  - `SkillLastPoints` (e.g. `"quest +3"`)
  - `SkillUniversal` ("on" / "off")
  - `SkillAccountFrom` (e.g. `"max of 3 dinos"` or `"uxp"`)
- **Script attributes:**
  - `SkillUniversalEnabled` (true, read at each player's load)
  - `SkillGrantPointsEnabled` (true)
  - `SkillPointGrants` (count)
- Piece 4 (Quest Stand) pays through `SkillGrantPoints` only.

**Behaviour (each bullet = one patch point):**
1. **load:** `d.universal = SkillUniversalEnabled ~= false`. If universal and a v = 2 value is found:
   - `d.uxp = SkillPool.accountXp(value)`.
   - `d.bonus = SkillPool.cleanBonus(value.bonus)`.
   - `cleanRecord(raw, key, cap)` with `cap = SkillPool.earned(d.uxp, d.bonus, ST)`. The build-over-points reset uses cap in place of the record's own level points.
   - A "new" value gives uxp 0 and bonus 0.
2. **switchTo:** when `d.universal`, after loading the new record, set `d.xp = d.uxp`. `stash` keeps writing `xp = d.xp` into the record. Before the swap, set `d.uxp = d.xp` (it picks up kills and grants made since).
3. **publish:** `earned = d.universal and SkillPool.earned(d.xp, d.bonus, ST) or ST.pointsOf(level)`. It writes:
   - SkillBonusPoints
   - SkillUniversal
   - SkillPoints, SkillLeft (from earned, so the Lab's canBuy works unchanged)
4. **buy:** the same `earned` as publish.
5. **save:** add `uxp = d.universal and d.xp or nil` and `bonus = d.universal and d.bonus or nil` at the top level of the value. v stays 2.
6. **SkillGrantPoints:** validate with SkillPool.grantOk, then `d.bonus += amount`, `d.dirty = true`, publish, write SkillLastPoints and count SkillPointGrants.
7. **Unchanged:** kill XP and SkillGrantXp stay as they are (they add to d.xp, which is now the account XP).

**Deterministic map:**

| State | Condition | End |
|---|---|---|
| Universal, saved v2 with N dinos | SkillUniversalEnabled ≠ false at load | account XP = max(uxp, dino XPs); every build kept (each ≤ its old points ≤ account points) |
| Universal, new player | no value / not v2 | XP 0, bonus 0, level 1 |
| Universal, no API / save off | SkillSaveState noApi / off | same as new, session only |
| Dino switch | character Species changes | level, XP, points unchanged; build + loadout swap to that dino's |
| Kill / match XP | credit / SkillGrantXp | account XP up, every dino's points up |
| Quest points | SkillGrantPoints ok | bonus up, SkillPoints up on every dino |
| Grant refused | SkillEnabled false / SkillGrantPointsEnabled false / universal off | "disabled", nothing changes |
| Grant bad | amount not whole 1..100 / not a Player | "badArg" |
| Grant early | data not loaded | "notLoaded" |
| Switch off | SkillUniversalEnabled false at load | 1.14 exactly (per-dino XP from each record, bonus ignored but kept in the save) |

**Acceptance (Studio, test store, save switches otherwise off):**
- A seeded v2 save {Raptor 500 XP with 3 points spent, TRex 2000 XP} joins as level 18 on both dinos (17 points). Raptor's build is kept, and Raptor now has 17 points (was 7).
- A kill on the Raptor raises the TRex's level too (switch dinos and check).
- SkillGrantPoints(player, 3, "quest") gives "ok". SkillPoints goes up by 3 on both dinos, and a buy past 40 works at level 41 with bonus.
- The save holds uxp and bonus. A rejoin restores them.
- Switch off: 1.14 values come back (per-dino levels).
- Restore the store name and switches.

### Task 3 — Docs · Mode: Wired
VERSIONS.md (SkillPool 1.0, SkillServer 1.15 with hashes), ATTRIBUTES.md (the switches, diagnostics, grant API), and a SkillServer header note.

## How this fails (red-team)
1. **The switch is not a clean undo.** While universal is on, a dino played after the switch-over stores the account XP in its record. A switch back to off gives that dino the account level, not its old one. Bonus points are ignored when off. A build that used bonus points would be reset by 1.14's over-points check on the next load. Mitigation: the switch is for emergencies; saves keep everything (uxp, bonus, records). Accept?
2. **Buying a new dino gives a fully levelled dino.** With one level, a player at level 41 who unlocks a dino can spend 40+ points on it straight away. The per-dino grind you set up on Nov 22 ("see how hard it is to grind") goes away. That is what "Full pool on every dino" means; I flag it so it is a choice, not a surprise.
3. **No ceiling on quest points.** "Yes, past 40" with no cap means a daily player keeps gaining points forever. Each dino is still held by Mastery 3, but over time every dino buys every step it can. Options:
   - no cap (as chosen), with BONUS_MAX left as an attribute in case it's needed later;
   - a cap such as 20 bonus points (60 total, the old 1.0 tree maximum).
4. **Two servers, one save.** Island and Arena use the same key. Bonus points granted on the island must be saved before a teleport. The existing hand-off already waits for the skill save (HubRules SAVE_WAIT 12 s). It is unchanged, so this works only if that wait holds. The Studio check can't run a teleport; the live check after publish confirms it.
