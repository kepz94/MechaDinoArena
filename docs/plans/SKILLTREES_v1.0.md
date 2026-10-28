# Mecha Dino Arena — Skill trees v1.0: points + tree screen (first piece)

**Goal:** kills earn XP, levels give skill points, and a tree screen lets the player spend them on the passive paths. The build is saved and kept on death.
**Chosen direction:** A · Area rail + 3 path columns (docs/mockups/skill_tree_options.html).
**Kepu's answers (2026-10-28):**
- Layout A.
- The paths replace the class stat points: no separate +stat track.
- Jaws upgrades the dino's main attack: bite for the T-Rex, pounce for the raptor.
- Earlier answers, from the brainstorm (docs/plans/SKILLTREES_brainstorm.md):
  - XP and levels; 1 point per level; cap 60 points.
  - Free respec at any time; keep everything on death; builds saved.
  - Path costs 1-2-3-4; fast start, slower later.
- First piece = points + tree screen, starting with the passive paths.

**Architecture:**
- **SkillTree 1.0:** a pure data and maths module.
- **SkillServer 1.0:** XP from kills, levels, points, buy / respec, save.
- **SkillEffects 1.0:** turns bought steps into game effects, reusing the attributes existing scripts already read.
- **SkillScreen 1.0:** the client screen.

GrowthServer stays off (adult spawns), so it is not used for XP. This settles ADR-001 accepted risk #3: nothing splits GrowthServer.

## Global constraints
- **Studio target: the cloud place "Mecha Dino Arena", placeId 84022023159448** (universe 10773455700).
  - Never the local MechaDinoArena.rbxl (placeId 124745441973216). The old CLASSSTATS plan names that one by mistake.
  - Check `game.PlaceId` before every install.
- Additive only. Every new or changed script gets:
  - a vX.Y header and a changelog line;
  - a `<Name>Version` attribute;
  - a docs/VERSIONS.md row;
  - a docs/ATTRIBUTES.md section.
- Every state change is exposed as an attribute. Every new behaviour has an on/off attribute.
- Install check: hash (h = 7; h = (h × 31 + byte) % 2147483647) plus a loadstring compile.
- All numbers below are tunables (script attributes or SkillTree constants), set from Kepu's answers.

## Facts read in the code (MechaDinoArena @ 6992479)
| Need | Existing source |
|---|---|
| A kill | BiteServer 1.6 / PounceServer 1.3 stamp the killing blow on a bot: `KilledBy` (player name), `KilledByUserId`, `KilledWith`, then `KilledAt`. KillRegenServer 1.0 already watches every `IsBot` model this way. Player-vs-player kills don't exist yet (no PvP damage). |
| Bot health (for kill XP) | `DummyMaxHealth` on the bot: Raptor 60, TRex 200 |
| Attack / Defense / Speed | StatServer 1.0 reads **player** attributes `StatAdded_Attack` / `StatAdded_Defense` / `StatAdded_Speed` and re-applies when they change. Per point: Attack bite +2, land +2, tick +1; Defense −5% damage taken; Speed +10% walk / run. |
| Cooldowns | Character attributes with script defaults: `BiteCooldown` 0.8, `PounceCooldown` 3, `RamCooldown` 6, `JumpCooldown` 0.5 (read by both client and server move scripts) |
| Damage dealt | Character `BiteHitAt` + `BiteHitDamage`; `PounceBiteAt` + `PounceHitDamage` |
| Kill heal | KillRegenServer: character `KillRegenFraction` (default 0.25 of max health over 5 s) |
| Stun | Character `StunnedUntil` (server time), set only by ShakeOffServer (T-Rex rams a tree with a raptor latched on) |
| Saving | Studio cannot reach DataStores yet: "Studio access to APIs is not allowed". It works in the live game. |
| Client UI style | ArenaStatus 1.0: panel (20, 20, 26), yellow (255, 200, 50), FredokaOne, white stroke 0.5, corner 10 |

## Do-not-touch
- **Code read, not changed:** GrowthServer, GrowthBar, LevelUpFX, StatServer, StatSheet, KillRegenServer, BiteServer, PounceServer, ShakeOffServer, BotServer, all move scripts.
- **ArenaStatus and ArenaTouch are unchanged.** The SKILLS button is its own small ScreenGui.
- **Mecha parts, ability buttons, loadout slots, Engineering, PvP and squads are later pieces.** The screen shows those paths as "soon".

## File structure
- **Create `src/shared/SkillTree.luau`:** tree data, costs, level curve, buy / respec checks, effects of a build. Pure, no Instances.
- **Create `tools/tests/SkillTree.spec.luau`:** the Logic spec.
- **Create `src/server/SkillServer.server.luau`:** XP, levels, points, the request remote, saving. It also copies SkillTree into ReplicatedStorage for the client.
- **Create `src/server/SkillEffects.server.luau`:** effects only, so effects can be switched off without touching points.
- **Create `src/character/SkillScreen.client.luau`:** the SKILLS button and the screen.
- **Modify `src/server/ArenaScope.server.luau` → 1.2:** expects the three new scripts on.
- **Docs:** this plan, VERSIONS rows, ATTRIBUTES sections.

## Numbers (first piece)
**Level curve**
- XP to go from level L to L+1 = 30 + 10 × (L − 1).
- Points = level − 1, capped at 60 (level 61).
- Kill XP = bot `DummyMaxHealth` × 0.5: raptor bot 30 XP, T-Rex bot 100 XP.
- That's about 1 raptor-bot kill for the first level, about 21 for level 10, about 650 for level 61. Or one fifth as many T-Rex bots.

**Path steps.** Only the 5 passive paths are buyable in this piece:

| Path | I (1 pt) | II (2) | III (3) | ★ (4) |
|---|---|---|---|---|
| Regeneration | heal 2% max HP/s after 6 s without damage | after 5 s, 3%/s | after 4 s, 4%/s | kill heal `KillRegenFraction` +0.25 (0.25 → 0.5) |
| Lifesteal | heal 5% of damage you deal | 10% | 15% | heal 20% of damage dealt *(stand-in for "overheal shield", see red-team #1)* |
| Jaws (main attack) | +1 Attack point | main attack cooldown ×0.9 (`BiteCooldown` or `PounceCooldown`) | +1 Attack point *(stand-in for "bleed")* | main attack cooldown ×0.8 *(stand-in for "crushing stun")* |
| Thick Hide | +1 Defense point (−5%) | +1 Defense point *(stand-in for "less knockback")* | stuns 25% shorter (`StunnedUntil` trimmed) | no stun while above 50% health |
| Sprint Legs | +1 Speed point (+10%) | +1 Speed point *(stand-in for "acceleration")* | ×0.85 on `PounceCooldown` / `RamCooldown` / `JumpCooldown` | +1 Speed point |

The other 10 paths are on the screen, locked, marked "soon".

### Task 1 — SkillTree 1.0 · Mode: Logic
**Files:** Create `src/shared/SkillTree.luau`, `tools/tests/SkillTree.spec.luau`.

**Interfaces (Produces):**
- `SkillTree.AREAS`: `{ {id="health", name="Health", color={95,209,106}, paths={ {id="regen", name="Regeneration", mech=false, soon=false, steps={"...","...","...","..."}}, ... } }, ... }`. 5 areas, 3 paths each. Path ids: regen, medstation, lifesteal, jaws, turret, rocket, hide, armor, shield, legs, thrusters, grapple, sentry, traps, barricade.
- `SkillTree.COST = {1,2,3,4}`, `SkillTree.MAX_POINTS = 60`.
- `SkillTree.xpToNext(level) -> number`.
- `SkillTree.levelOf(totalXp) -> level, xpIntoLevel, xpNext`.
- `SkillTree.pointsOf(level) -> number`.
- `SkillTree.spent(steps) -> number`. `steps` is `{[pathId]=0..4}`.
- `SkillTree.canBuy(steps, pathId, pointsEarned) -> ok:boolean, reason:string`. Reasons: "ok", "unknownPath", "soon", "maxed", "noPoints".
- `SkillTree.buy(steps, pathId, pointsEarned) -> newSteps|nil, reason`. Never mutates its input.
- `SkillTree.effects(steps) -> {attackPts, defensePts, speedPts, regenDelay, regenRate, lifesteal, killRegenAdd, mainCdMul, moveCdMul, stunMul, stunImmuneAbove}`. All neutral for empty steps: 0 / nil / 1.

**Steps:**
1. Write the spec: costs; curve values for L = 1, 2, 10, 60; level 61 cap; buy order (I before II); "soon" refused; noPoints; maxed; respec = `{}`; effects for each path step and for an empty build.
2. Run it in Studio Edit and watch it fail.
3. Write the module.
4. Run until it passes.
5. Commit.

**Acceptance:**
- The spec passes.
- `effects({})` is neutral.
- `buy` never mutates its input.
- Every path id in the table above exists.

### Task 2 — SkillServer 1.0 · Mode: Wired
**Files:** Create `src/server/SkillServer.server.luau`.

**Interfaces:**
- **Consumes:** SkillTree.
- **Produces:**
  - Remote `ReplicatedStorage.SkillRequest` (RemoteEvent): client → server `("buy", pathId)` or `("respec")`.
  - Folder `ReplicatedStorage.SkillShared`, containing a copy of the SkillTree module.
  - Player attributes:
    - `SkillLevel`, `SkillXP` (total), `SkillXPInto`, `SkillXPNext`;
    - `SkillPoints` (earned), `SkillSpent`, `SkillLeft`;
    - `SkillPath_<pathId>` (0-4);
    - `SkillLastResult` ("ok" / reason / "badArg" / "busy");
    - `SkillLastXp` ("kill +30");
    - `SkillSaveState` ("loading" / "loaded" / "new" / "saved" / "failed" / "noApi");
    - `SkillLevelUpAt` (server time).
- **Script attributes:**
  - settings: `SkillEnabled` (true), `SkillKillXpFraction` (0.5), `SkillSaveEnabled` (true);
  - diagnostics: `SkillServerVersion`, `SkillKillsCounted`.

**Logic:**
- **XP.** Watch every `IsBot` model's `KilledAt` (the same pattern as KillRegenServer). The killer comes from `KilledByUserId`. XP = `DummyMaxHealth` × SkillKillXpFraction. Each model's `KilledAt` value is counted once.
- **Buy and respec.** Requests are validated with SkillTree. There's a 0.2 s debounce per player ("busy"). Respec is always free.
- **Saving.**
  - DataStore "MDA_Skills_v1", key `"u"..UserId`, value `{v=1, xp=number, steps={...}}`.
  - Load on join, and don't accept requests until loaded.
  - Save on change (at most once per 10 s), on PlayerRemoving and on BindToClose.
  - If the DataStore errors with "not allowed" in Studio, set `SkillSaveState` "noApi" and keep going for the session.
- **Death.** Nothing changes; all state lives on the Player.

**Acceptance (Play, real place):**
- Killing a raptor bot gives +30 XP and level 2 with 1 point.
- Buying Regeneration I leaves `SkillLeft` 0. Buying again gives "noPoints".
- Buying a "soon" path gives "soon".
- Respec gives back all points.
- Dying keeps everything.
- With Studio API access on, rejoining keeps the build. Without it, `SkillSaveState` is "noApi".

### Task 3 — SkillEffects 1.0 · Mode: Wired
**Files:** Create `src/server/SkillEffects.server.luau`.

**Interfaces:**
- **Consumes:** SkillTree.effects; the player `SkillPath_*` attributes.
- **Writes:**
  - player: `StatAdded_Attack` / `StatAdded_Defense` / `StatAdded_Speed` (StatServer re-applies them);
  - character: the cooldown attributes, `KillRegenFraction`, `StunnedUntil` (trim only).
- **Script attribute:** `SkillEffectsEnabled` (true). When false, every written value goes back to its base (`StatAdded_*` 0).

**Logic:**
- **Base values.** At spawn, capture the character's base cooldowns: the attribute, else the script default from the facts table. Store them as `SkillBase_<Cooldown>`.
- **Writes.** Write base × multiplier. The main attack is `BiteCooldown` when `BiteEnabled ~= false`, else `PounceCooldown`.
- **Regeneration.**
  - Every 0.25 s while health is below max and at least `regenDelay` s have passed since the last health drop: heal `regenRate` × MaxHealth × dt.
  - The last drop is tracked with HealthChanged going down.
- **Lifesteal.** On a new `BiteHitAt` / `PounceBiteAt`, heal `lifesteal` × the matching hit damage, never above MaxHealth.
- **Stun.**
  - When `StunnedUntil` changes and Health > `stunImmuneAbove` × MaxHealth, set it to now (no stun).
  - Otherwise shorten what's left by `stunMul`.
- **Diagnostics.** Character `SkillEffectsState` ("ready" / "off"), `SkillRegenActive`, `SkillLastHeal` ("regen +3" / "lifesteal +2"), `SkillStunTrimmed`.

**Acceptance (Play, real place):**
- Each path's 4 steps change the attribute in its row of the numbers table.
- Regeneration heals after the delay and stops while you take damage.
- Lifesteal heals on a bite hit (T-Rex) and on a pounce hit (raptor).
- Switching it off brings back every base value.
- T-Rex and raptor are both tested.

### Task 4 — SkillScreen 1.0 · Mode: Wired
**Files:** Create `src/character/SkillScreen.client.luau`.

**Layout (option A, phone landscape and PC):**
- **SKILLS button:**
  - A pill left of ArenaStatus's species pill: AnchorPoint (1, 0), Position (1, −150, 0, 12).
  - Text "SKILLS"; while `SkillLeft` > 0, a yellow badge with the count.
  - PC key: K.
- **Screen:** a full-screen dim (0, 0, 0 at 0.45) over everything (DisplayOrder 20). Inside, on a 12 px margin:
  - **Top bar:** "SKILLS", a LV pill with an XP bar, a yellow "N PTS" pill, a RESPEC button and an X button.
  - **Left rail:** 64 px, the 5 area buttons with colour dots: Health (95, 209, 106), Attack (240, 90, 79), Defense (90, 160, 255), Speed (255, 211, 77), Engineer (255, 155, 46).
  - **Centre:** 3 path columns. Nodes I, II, III, ★ go from bottom to top, 38 px, with cost badges. Bought nodes are filled in the area colour, the next one is outlined, locked ones are at 0.4. "Soon" paths are greyed with a "soon" tag.
  - **Right detail panel:** 220 px wide (30% of the width on screens under 700 px). It shows the name, "area · step n of 4 · passive", the effect text and the BUY button. The button shows "BUY · n PTS", "NEED n PTS", "BOUGHT", "COMING SOON" or "BUY THE ONE BEFORE".
- **Behaviour:**
  - Buttons fire SkillRequest; the screen redraws from the player attributes, never guessing.
  - RESPEC asks "Reset all points?" with YES / NO first.
  - While the screen is open, the touch buttons stay where they are under the dim.

**Diagnostics:** `SkillScreenVersion`, `SkillScreenOpen`, `SkillScreenArea`, `SkillScreenLastPress`.

**Acceptance:**
- In the phone emulator and on PC:
  - the button opens and closes the screen;
  - buy, respec and the "soon" paths behave as on the mockup;
  - points and the XP bar match the player attributes.
- Kepu checks it on his phone.

### Task 5 — ArenaScope 1.2 · Mode: Wired
Expects SkillServer, SkillEffects and SkillScreen to be on, and ClassCard still off.

**Acceptance:** `ArenaScopeMismatches` is 0.

## Deterministic map (new states)
- **Save:**
  - loading → loaded (data found) / new (no data) / noApi (Studio without API access) / failed (any other error; the session continues, and a save is retried every 30 s);
  - loaded / new → saved after each save.
- **Request:**
  - before loaded → "busy";
  - otherwise "ok" / "unknownPath" / "soon" / "maxed" / "noPoints" / "badArg", or "busy" (debounce).
- **Kill:**
  - killer left or unknown → not counted;
  - killer present → counted once per `KilledAt` value.
- **Effects:**
  - SkillEffectsEnabled false → base values;
  - species without a bite → main attack = pounce;
  - the character dies → nothing is written to the dead character, and the next one gets the same effects.
- **Screen:**
  - closed / open;
  - area selected;
  - node selected (default: the first not-yet-bought step of the first path).

## Red-team (to answer before filing)
See the chat reply. The surviving points get folded in here.
