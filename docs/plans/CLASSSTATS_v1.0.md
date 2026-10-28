# Mecha Dino Arena — Class stats v1.0 (MDA part 2)

**Goal:** every dino has the same 5-stat point sheet (Health, Attack, Defense, Speed, Support). A species' starting points are its natural build type (T-Rex = Bulky, Raptor = Roamer) and reproduce today's numbers exactly. Points added later (part 3, the stat trees) raise the real stats through one formula.
**Chosen direction:** C · Stat points (Kepu, 2026-10-27). Prototype: docs/mockups/class_stats_options.html.
**User answers:**
- C over A / B.
- Stamina is not a stat: "stamina isnt a tree because stamina is unlimited" (StaminaPounceOnly = true on both species).
- Speed alone is enough for Roamer.
- Class stats come before PvP.
- Growth XP will become skill points in part 3, with no size change.

**Red-team answers:**
- #1: cap the ADDED points (up to +10 per stat on top of the start).
- #2: Health and Attack points are flat (the same gain on every dino); Defense and Speed are percentages.
- #4: keep Task 3 (Defense on bot hits now).
- #5: the card is full for 8 s after spawn, then collapses to a one-line header; tap the header to toggle.

**Accepted risk (#3, ADR-001):** StatServer goes idle while growth is on. Part 3 (growth XP → skill points) must split GrowthServer into XP-only (no size or stat writes), or this plan's stats stop applying.

**Architecture:**
- **StatSheet 1.0** (pure module, `src/shared`): the species sheets and the stat → attribute formula.
- **StatServer 1.0:** captures each player character's own base values at spawn and writes the computed attributes. It also turns on adult spawns, through GrowthServer's existing `GrowthEnabled` switch.
- **BotServer 1.10:** applies Defense (damage taken) to bot hits on players, at the one place bot damage to players is computed (`hitDamage`).
- **ClassCard 1.0:** shows the sheet under the species picker.

## Global constraints
- Additive only. Every changed script gets: header vX.Y, changelog line, version attribute, a docs/VERSIONS.md row, and a docs/ATTRIBUTES.md section.
- Every state change is exposed as an attribute.
- With 0 added points every value equals today's value exactly, checked against the hashes of the installed scripts and the model data.
- Studio target: MechaDinoArena.rbxl (placeId 124745441973216; never plain Publish). Never the DinoBlox place.
- Install check: hash (h = 7; h = (h × 31 + byte) % 2147483647) and a loadstring compile.

## Do-not-touch
- GrowthServer / GrowthCurve code: switched off only through its existing `GrowthEnabled` attribute.
- DinoHealthServer, SpeciesServer, SprintTest, BiteServer, PounceServer, StaminaServer, RamServer, RoarServer: they already read the attributes StatServer writes; their code is not changed.
- Bots and prey stats: StatServer handles player characters only.
- SpeciesPicker: the card sits under it and does not change it.
- PvP (part after this), squads, trees (part 3).

## Facts read in the code (MechaDinoArena @ c6afd65)
| Stat | Today's source (base) | Read by |
|---|---|---|
| Health | Humanoid.MaxHealth set by DinoHealthServer 1.0 (MAX_BY_SPECIES TRex 200, Raptor 60); `DinoMaxHealthSet` marks done | HealthBar, KillRegenServer, BotServer cap |
| Attack | `BiteDamage` (T-Rex 25, Raptor 8), `PounceLandDamage` 8, `PounceTickDamage` 4 (raptor model data) | BiteServer `get(char,"BiteDamage")`, PounceServer `get(char,"PounceLandDamage"/"PounceTickDamage")` |
| Defense | none today | bot hits on players: BotServer `hitDamage(b, char, hum, dmg)` (bite, latch land, latch tick) |
| Speed | `MoveWalkSpeed` / `MoveRunSpeed` / `MoveCreepSpeed` (T-Rex 32 / 60 / 10 on the place's StarterCharacter — TRexModelData in the repo says 20 / 44, measured in Play 2026-10-28; Raptor 30 / 52 / 10) | SprintTest client, IdleAnimation gait |
| Support | none | nothing until squads |

- **Growth.** GrowthServer 1.2 is on by default: a new player spawns at level 1, scaled 0.4. With `GrowthEnabled = false`, a character keeps its adult values (GrowthState "disabled"; the script never writes at spawn while off).
- **Stamina.** StaminaServer 1.4 with `StaminaPounceOnly = true`: running never drains.

## File structure
- Create `src/shared/StatSheet.luau`: data plus pure functions. One responsibility: sheets and the formula.
- Create `tools/tests/StatSheet.spec.luau`: Logic spec, run in Studio Edit like the other specs.
- Create `src/server/StatServer.server.luau`: base capture, apply, adult spawns, live re-apply, diagnostics.
- Modify `src/server/BotServer.server.luau`, `hitDamage` only (v1.10).
- Create `src/character/ClassCard.client.luau`: the card UI.
- Docs: VERSIONS rows, ATTRIBUTES sections, this plan.

### Task 1 — StatSheet 1.0 · Mode: Logic
**Files:** Create `src/shared/StatSheet.luau`; Test `tools/tests/StatSheet.spec.luau`.

**Interfaces (produces):**
- `StatSheet.Version = "1.0"`, `StatSheet.STATS = {"Health","Attack","Defense","Speed","Support"}`
- `StatSheet.MAX_ADDED = 10` (cap per stat on ADDED points; starting points are not part of it)
- `StatSheet.HEALTH_PER_POINT = 15` (flat MaxHealth), `StatSheet.ATTACK_PER_POINT = {BiteDamage = 2, PounceLandDamage = 2, PounceTickDamage = 1}` (flat)
- `StatSheet.SPEED_RATE = 0.10` (per point, % of the species' own value), `StatSheet.DEFENSE_RATE = 0.05` (per point, off damage taken)
- These per-point values are placeholders. Part 3 tunes them with the tree.
- `StatSheet.SPECIES = { TRex = {class = "Bulky", start = {Health=9, Attack=7, Defense=7, Speed=4, Support=1}, abilities = {"Roar", "Ram"}}, Raptor = {class = "Roamer", start = {Health=3, Attack=4, Defense=3, Speed=9, Support=1}, abilities = {"Pounce + latch", "Jump"}} }`
- `StatSheet.ATTACK_KEYS = {"BiteDamage","PounceLandDamage","PounceTickDamage"}`, `StatSheet.SPEED_KEYS = {"MoveWalkSpeed","MoveRunSpeed","MoveCreepSpeed"}`
- `StatSheet.added(species, raw) -> {[stat] = int}, clampedAny`: each `raw[stat]` is converted with `math.floor`. A non-number or negative value becomes 0. Each value is capped at `MAX_ADDED`. Support is always 0 (no effect yet).
- `StatSheet.points(species, added) -> {[stat] = start + added}`
- `StatSheet.values(base, added) -> {[attr] = value}`, where `base` = `{MaxHealth = n, BiteDamage = n, ...}` (only the keys present):
  - `MaxHealth = base.MaxHealth + HEALTH_PER_POINT × added.Health` (flat)
  - each attack key present in base: `base[k] + ATTACK_PER_POINT[k] × added.Attack` (flat)
  - each speed key: `round1(base[k] × (1 + SPEED_RATE × added.Speed))`, to 0.1
  - `StatDamageTakenMul = round2(1 - DEFENSE_RATE × added.Defense)`
- An unknown species (`SPECIES[species] == nil`) → `added` returns `nil, false`, and the caller stops.

- [ ] Step 1: write the spec. Assert that both sheets sum to their table, that 0 added gives exactly the base (T-Rex 200 / 25 / 20 / 44 / 10, Raptor 60 / 8 / 8 / 4 / 30 / 52 / 10, mul 1), each formula row, the clamps (12 → 10 on any stat, negative → 0, "x" → 0, 2.7 → 2, Support → 0); flat Health / Attack give the same gain on both species, and that an unknown species gives nil.
- [ ] Step 2: run in Studio Edit and watch it fail (module missing).
- [ ] Step 3: write the module.
- [ ] Step 4: run, PASS n.
- [ ] Step 5: commit.

**Acceptance:**
- Spec PASS (every formula row, every clamp branch, unknown species).
- Pure module (no Instance access).
- Installed hash matches; docs updated.

### Task 2 — StatServer 1.0 · Mode: Wired
**Files:** Create `src/server/StatServer.server.luau`.

**Interfaces:**
- Consumes: StatSheet 1.0.
- Produces:
  - Character attributes: `StatClass` ("Bulky" / "Roamer"); `StatPoints_<Stat>` (int); `StatAdded_<Stat>` (int, after clamp); `StatBase_<key>`; `StatDamageTakenMul`; `StatState`; `StatAppliedAt`; `StatAddedClamped`.
  - Script attributes: `StatServerVersion`, `StatEnabled` (default true), `ArenaAdultSpawns` (default true).
  - Input for part 3: player attributes `StatAdded_<Stat>` (ints).

- [ ] Step 1: at start, if `ArenaAdultSpawns` is true, set `ServerScriptService.GrowthServer` attribute `GrowthEnabled = false`. Write script attribute `ArenaAdultSpawnsApplied` = true / false, or "noGrowthServer" if the script is missing.
- [ ] Step 2: CharacterAdded (also SpeciesServer's raptor body):
  - Wait for `DinoMaxHealthSet` (5 s max, as GrowthServer does).
  - Read `Species`, then capture the base from the character's own attributes (attack keys and speed keys present) plus `Humanoid.MaxHealth`, and write `StatBase_*`.
- [ ] Step 3: apply.
  - `values(base, added(species, player StatAdded_*))`: write each attribute (`set` only when changed).
  - `MaxHealth`: at spawn `Health = MaxHealth`; later, keep the health fraction.
  - Write `StatPoints_*`, `StatAdded_*`, `StatClass`, `StatAppliedAt`, `StatState = "ready"`.
- [ ] Step 4: live re-apply when any player `StatAdded_*` attribute changes, or `StatEnabled` changes.
- [ ] Step 5: commit.

**Deterministic map:**

| Condition | Result |
|---|---|
| species unknown | `StatState = "noSheet"`, nothing written |
| `StatEnabled == false` | base values written back, `StatDamageTakenMul = 1`, `StatState = "disabled"` |
| GrowthServer `GrowthState ~= "disabled"` on this character (growth on) | `StatState = "growthOn"`, nothing written (one writer only) |
| GrowthState becomes "disabled" later | apply (GrowthServer's restore wrote the base back) |
| GrowthState becomes "ready" later | stop writing; base values left to GrowthServer |
| `DinoMaxHealthSet` missing after 5 s | `StatState = "noHealth"`, apply anyway with the current MaxHealth |
| any raw added value clamped | `StatAddedClamped = true` |
| character respawns | captured from that character fresh, apply from the player attributes |
| player leaves | per-character state dropped |

**Acceptance:**
- 0 added on both species: every attribute and MaxHealth equals today's values.
- `ArenaAdultSpawns` gives scale 1 and level-free spawns (GrowthState "disabled").
- Player `StatAdded_Health = 2` → T-Rex MaxHealth 230, Raptor 90, health fraction kept. `StatAdded_Health = 12` → clamped to 10, `StatAddedClamped` true.
- Raptor `StatAdded_Speed = 1` → walk 33 / run 57.2 / creep 11, and SprintTest uses them.
- Raptor `StatAdded_Attack = 2` → bite 12, pounce 12 / 6. T-Rex `StatAdded_Attack = 2` → bite 29. BiteServer's `BiteHitBaseDamage` matches.
- `StatEnabled = false` restores the base values.
- No warnings; hash matches; docs updated.

### Task 3 — BotServer 1.10 Defense hook · Mode: Wired
**Files:** Modify `src/server/BotServer.server.luau` (`hitDamage`, lines 718–726 @ c6afd65).

**Change (additive):** after the growth cap, `dmg = dmg × (char:GetAttribute("StatDamageTakenMul") or 1)` when `get("BotDefenseEnabled") ~= false`.
- New script attribute DEFAULTS `BotDefenseEnabled = true`.
- Bot diagnostic `BotLastHitDefenseMul`.

**Acceptance:**
- A player with `StatDamageTakenMul` 0.85 (3 Defense points) takes 0.85 × a T-Rex bot bite (25 → 21.25).
- Missing attribute → ×1.
- Toggle off → ×1.
- The growth cap order is unchanged.
- Hash matches; docs updated.

### Task 4 — ClassCard 1.0 · Mode: Wired
**Files:** Create `src/character/ClassCard.client.luau` (StarterCharacterScripts).

**Layout (from the mockup, option C):**
- Card: ScreenGui DisplayOrder 6, position (16, 112) px, directly under the SpeciesPicker row at (16, 64), size 240 × 40. Width 300.
- Panel: background (20, 20, 26) at 0.14 transparency; UIStroke white at 0.5; corner radius 12; FredokaOne.
- Header: species name (20 px) and the class badge (pill; Bulky (92, 190, 255), Roamer (155, 227, 90), Assault (235, 85, 60), Vanguard (255, 176, 66), Healer (124, 224, 195); dark text).
- 5 rows in the order Health, Attack, Defense, Speed, Support. Each row has:
  - the label;
  - 10 pips for the starting points, in the stat colour (Health (95, 209, 106), Attack (235, 85, 60), Defense (92, 190, 255), Speed (155, 227, 90), Support (124, 224, 195));
  - right after the pips, gold (255, 226, 122) text "+N" for added points, only when N > 0;
  - the value, right-aligned: "200 HP", "bite 25", "takes ×1.00", "20 / 44", "—".
- The Support row is at 0.45 transparency.
- Ability chips: the species abilities, plus 2 dashed chips "Mecha skill · from trees" at 0.5 text transparency.
- No + buttons (the trees are part 3).

**Behaviour:**
- Reads the character attributes from Task 2 and refreshes on any change to them.
- Collapse (red-team #5):
  - Full card for `ClassCardFullTime` (8 s) after spawn, then collapsed to the header line only: name, badge, "+".
  - Clicking or tapping the header toggles full ("-") ↔ collapsed ("+"). A toggle cancels the 8 s timer. (Built: FredokaOne draws ▸ / ▾ blank, so the indicator is "+" / "-".)
  - Viewport narrower than 900 px (the GoalTracker breakpoint): the card starts collapsed, so it never covers the goal tracker unless opened. Mecha chips are outline-only (Roblox strokes cannot be dashed).
- Character attribute `ClassCardEnabled` (default true) hides the card when false.
- Diagnostic `ClassCardState` ("waiting" until `StatState` is set / "full" / "collapsed" / "hidden" / "noSheet").

**Acceptance:**
- Card visible under the picker on spawn for both species, values matching the attributes.
- Gold "+N" appears live when `StatAdded_*` changes.
- Collapses at 8 s; the header tap toggles it.
- Hidden with `ClassCardEnabled` false.
- No overlap with the picker, health HUD or goal tracker at 1280 × 720 and 390 px phone width (screenshots).
- No warnings; docs updated.

## Out of scope
Spending points, earning points, tree UI, the live "build type" label from where the points sit, PvP, Support effects, new species.
