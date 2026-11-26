# Mecha Dino Arena v1.0 — Welcome Screen + Special Moves (first-time flow)

**Goal:** a new player learns what the game is before the roster, and learns each dino's moves that are not a normal button press (Herrera: climb a tree, drop attack, glide on JUMP) before they play.
**Chosen direction:** Welcome **A · Title card**, Special moves **B · Reveal card** (Kepu 2026-11-26 02:03 "A / B") — prototype `docs/mockups/welcome_moves_v0.1.html` (published artifact "Welcome and Special Moves").
**Architecture:** client-only screens inside the existing Tutorial LocalScript (step 1 and step 2 scenes), fed by a new pure data table in TutorialRules. No server, DataStore, or gameplay change. Every new piece sits behind its own script attribute.

**Intent (Kepu 2026-11-26 01:51):** "the tutorial didn't explain that wings work through the jump button, the Herrera also didn't come with an explanation that it can climb up trees and deals extra damage attacking from trees … a welcome to mecha Dino, then a here's our roster screen. Let's look at other Dino's who have hidden abilities".

**Tree damage (unanswered in the pick → Do-Not-Touch default):** the game is not changed. In code a drop attack from a tree does normal slash damage (SlashServer 1.8 line 546: only `st.active.glide` applies GliderDropMul 1.3). The copy says only what the game does. A tree-drop damage bonus is a separate change if Kepu asks for it.

## Global Constraints
- Version tags: TutorialRules **1.3**, Tutorial (client) **1.7**. Header, docs/VERSIONS.md, docs/ATTRIBUTES.md for each.
- Additive only; every new screen / section behind a script attribute (default true; false = the 1.6 / 1.2 behaviour, byte-for-byte the same screens).
- Mobile-first: every tap target ≥ 44 px on the emulated iPhone 17 Pro (750 × 381). Text never under the helper's minimum pixel size.
- Game copy: no em dashes, short HUD tags, Silkscreen titles via FontSwap "silk", body GothamBold / GothamBlack with FontSwap "keep".
- Install flow: pairs patch file → `tools/lab_pairs.py` on the repo → same pairs into Studio → compile check → srchash match.
- Studio Play tests write to Kepu's freshly wiped account: run Play only with the save scripts switched off (as the 2026-11-26 DataStore check), and say so in the report.
- Publish only when Kepu says "Publish".

## Do-not-touch
- TutorialServer (steps, lanes, bot, TutNeed / TutUsed), the training lessons (TutorialRules LESSONS / lessonsFor), the egg / incubator (drawCharge, drawWait), the Lab coach (steps 5 / 8).
- drawShowcase (1.4) and the 1.1 egg / reveal fallbacks.
- SlashServer, ClimbLogic / ClimbTest, JumpServer, SkillTree, SkillEffects — no gameplay numbers change.
- PregameScreen (the in-game dino select outside the tutorial).

## File structure
| File | Change | Responsibility |
|---|---|---|
| `src/shared/TutorialRules.luau` | extend (1.3) | `M.MOVES` data + `M.movesFor(dino, max)` (pure) |
| `tools/tests/TutorialRules.spec.luau` | extend | specs for `movesFor` and the MOVES table |
| `src/client/Tutorial.client.luau` | extend (1.7) | `drawWelcome()`, roster title + SPECIAL MOVES section in `drawShowcase2()`, SPECIAL MOVES rows in `drawReveal()` |
| `tools/welcome_patch*.luau` | new | install pairs |
| `docs/VERSIONS.md`, `docs/ATTRIBUTES.md` | extend | version + switch entries |

Tutorial.client's main chunk has 121 top-level locals (limit 200): the new functions may be locals, but new tables go in one script-global table `WM` to keep room.

---

### Task 1 — TutorialRules 1.3: special moves data · Mode: Logic

**Files:**
- Modify: `src/shared/TutorialRules.luau` (after `M.lessonsFor`)
- Test: `tools/tests/TutorialRules.spec.luau`

**Interfaces:**
- Produces: `M.MOVES[dino] = { {n = string, badge = string, kind = "native" | "part" | "stat", id = string?, line = string}, ... }` (order = importance); `M.movesFor(dino: string?, max: number?) -> {move}` (a new list: the first `max` (default all) of `M.MOVES[dino]`, `{}` for nil / unknown dino / max ≤ 0); `M.MOVE_KIND_COLOR_KEY = {native = "green", part = "cyan", stat = "yellow"}` (keys into Tutorial's `C`).

**Data (copy approved in the mockup; `id` = SkillTree path id for part / stat rows):**
| Dino | n | badge | kind | id | line |
|---|---|---|---|---|---|
| Raptor | Leap | JUMP | native | | Every jump is a long leap. |
| Raptor | Thrusters Up | AIR | part | thrusters | Boost in the air with no stick: straight up. |
| Pachy | Leap | JUMP | native | | Every jump is a leap. |
| Pachy | Mecha Legs | JUMP x2 | part | mechalegs | Leap farther. JUMP again in the air to leap again. |
| Pachy | Blood Rush | ATTACK | part | bloodrush | Out of headbutts? ATTACK again: pay 25% HP for one more. |
| Pachy | Tether Spike | TAP x2 | part | tether | Tap to aim the circle, tap again to throw. |
| Herrera | Climb | TREE | native | | Walk into a tree to climb. Pull back to slide down, JUMP to hop off. |
| Herrera | Drop Attack | SLASH | native | | On a tree? SLASH drops onto the dino below. |
| Herrera | Glide | HOLD JUMP | part | glider | Hold JUMP in the air to glide. SLASH mid-glide: +30% drop. |
| Herrera | Stun Breaker | STUNNED | part | breaker | Only works while you are stunned or pinned. |
| Herrera | Goo Blob | GLIDING | part | goo | Fires straight down while you glide. |
| Herrera | Cruise Missile | STEER | part | cmissile | You fly the missile in yourself. You stand still meanwhile. |
| Teno | Hydraulic Leap | JUMP | part | tleap | Every jump is a 40-stud leap that lands with a tail slam. |
| Therizino | Spin Dive | JUMP | native | | JUMP spins you forward. 3 charges. |
| Therizino | Fourth Cut | TAP | stat | fourth | Tap again after the 3rd hit: a spinning sweep. |
| Dilo | Cobra Leap | JUMP | native | | Every jump is a quick leap. |
| Dilo | Sniper Scope | HOLD | part | dscope | Hold to scope in, let go to fire. |
| Troodon | Flap & Glide | JUMP x3 | native | | JUMP, then JUMP twice more in the air. Then it glides. |
| Troodon | Glow Feeder | STAND | stat | tfeeder | Stand in your own glow to heal. |
| Troodon | Portal Feathers | TAP x2 | part | oportal | Drop one end, run, press again to drop the other. |

TRex: no entry (not in ROLL_POOL) → `movesFor("TRex")` = `{}`.

- [ ] Step 1: add specs: every ROLL_POOL dino has ≥ 1 move; every move has non-empty n / badge / line, kind in the 3 values, `id` present iff kind ≠ "native"; no line contains "—"; badge ≤ 9 chars; `movesFor("Herrera", 3)` = Climb, Drop Attack, Glide; `movesFor("Herrera")` length 6; `movesFor("TRex")`, `movesFor(nil)`, `movesFor("Herrera", 0)` = `{}`; the result is a copy (mutating it leaves `M.MOVES` unchanged).
- [ ] Step 2: run the spec in Studio Edit (require a clone) → watch the new cases fail.
- [ ] Step 3: add `M.MOVES`, `M.movesFor`, `M.MOVE_KIND_COLOR_KEY`; header v1.3 block.
- [ ] Step 4: run → PASS (count = 35 + new); push the module source to Studio (ReplicatedStorage.TutorialShared.TutorialRules), hash match.
- [ ] Step 5: commit + push.

**Acceptance:** spec PASS in Studio Edit; every `id` exists in `ST.PATHS` (checked in the spec run via SkillTree in Studio); LESSONS / lessonsFor / ROLL_POOL / ROLE unchanged (hash of those lines unchanged).
**Out of scope:** LESSONS, TutorialServer.

### Task 2 — Tutorial 1.7: Welcome screen · Mode: Wired

**Files:** Modify `src/client/Tutorial.client.luau` (new `drawWelcome()` before `drawShowcase2`; `incubatorKey`; the step-1 branch in the draw function at "elseif s == 1 and showcaseOn() and not pod.showcased").

**Interfaces:** Consumes `backdrop()`, `text()`, `cta()`, `px()`, `C`, `pod`, `render()`. Produces `pod.welcomed` (bool, client only, once per join) and scene key `"welcome"`.

**Layout (mockup A, full screen, opaque backdrop as the showcase):**
- Below the Roblox buttons (`topH`), centred: "WELCOME TO" (GothamBlack, cyan, letter-spaced, ≈1.6 cqw, min 10 px); then "MECHA DINO ARENA" (title font, white, ≈6.4 cqw, min 32 px) with "DINO" in yellow (RichText font color).
- Middle: 3 tiles in one row, centred, each ≈19 cqw wide, gap ≈1.6 cqw, card colour `C.card`, `C.line` stroke, rounded: icon (yellow; ⚔ / ⚙ / ★), title (FIGHT / UPGRADE / COLLECT, title font, white), line (GothamBold, muted): "Squad battles on the island" / "Mecha parts and skill points" / "7 dinos, skins, emotes, trails". Tiles deal in left to right (0.12 s apart, 0.45 s fade + rise).
- Bottom centre: CTA "LET'S GO" (`cta()`, ≥ 44 px tall).
- LET'S GO → `pod.welcomed = true`, `pod.sceneKey = nil`, `render()` → the roster.

**Deterministic map:**
| Condition | Scene |
|---|---|
| step 1, TutRolled "", phase ≠ "open", `TutorialWelcomeEnabled` ≠ false, `showcaseOn()`, not `pod.welcomed` | welcome |
| same, `pod.welcomed` and not `pod.showcased` | showcase (roster) |
| same, `TutorialWelcomeEnabled` == false | showcase (1.6 behaviour) |
| `showcaseOn()` false | charge (welcome skipped too: it leads into the roster) |
| step ≥ 2, or a rejoin mid-tutorial (step ≥ 2) | unchanged (no welcome) |
| rejoin at step 1 | welcome again (client state, once per join, same as the showcase) |
| screen resize at welcome | redraw (scene key includes W×H) without replaying the deal-in? → deal-in replays; acceptable (same as the showcase cards) |

- [ ] Step 1: pairs patch `tools/welcome_patch1.luau`: `drawWelcome`, `welcomeOn()` (reads the script attribute per draw, default set to true at start), the scene-key line, the draw branch.
- [ ] Step 2: apply to repo + Studio; compile check; hash match.
- [ ] Step 3: Studio check, PC and iPhone 17 Pro emulation (Play with the save scripts off): welcome draws, glyphs ⚔ ⚙ ★ render (if ⚔ or ⚙ shows a box: drop the icon line on all 3 tiles), nothing under the Roblox buttons, LET'S GO ≥ 44 px and opens the roster; `TutorialWelcomeEnabled = false` gives the 1.6 roster first.
- [ ] Step 4: commit + push.

**Acceptance:** the 6 rows of the map; no text clipped at 750 × 381; the 1.6 showcase cycle timer does not start until the roster shows.
**Out of scope:** the egg, the server step (stays 1).

### Task 3 — Tutorial 1.7: Roster title + SPECIAL MOVES on the roster · Mode: Wired

**Files:** Modify `drawShowcase2()` (title block lines "YOUR FIRST DINO" / "1 OF THESE %d · FREE"; inside `show(i)` between the MAIN ATTACK cards and the ABILITIES section; `openAbility`).

**Interfaces:** Consumes `R.movesFor(key, 4)`, `R.MOVE_KIND_COLOR_KEY`. Produces nothing for other tasks.

**Layout:**
- Title (switch `TutorialRosterTitleEnabled`): kicker "MECHA DINO ARENA" (unchanged), title "MEET THE ROSTER", sub "1 OF THESE 7 IS YOURS FREE" (`#R.ROLL_POOL`). If the sub wraps past one line at 750 × 381 in Studio, use "7 DINOS · 1 IS FREE".
- Right panel, under MAIN ATTACK (switch `TutorialRosterMovesEnabled`): section header "SPECIAL MOVES" (same `section()` helper, cyan text), then up to 4 rows in the same 2-column grid cell size as ABILITIES: a left colour bar (kind colour), the move name (white), the badge (e.g. "HOLD JUMP") right-aligned in yellow — the same cell anatomy as an ability row. The ABILITIES list keeps its min height (px(6, 40)); it gets what is left.
- Tapping a move row opens it in the existing detail card: name, a chip "SPECIAL" (cyan), the line, one stat chip "HOW" = badge. Tapping an ability still opens the ability (unchanged).
- On `show(i)` the first SPECIAL MOVE opens in the detail card (was: the first ability). With the switch off: first ability (1.6).

**Deterministic map:** dino with 0 moves → no section, layout 1.6; 1–2 moves → 1 grid row; 3–4 → 2 rows; > 4 → first 4 (the rest are still in their ability cards); switch off → 1.6 panel; auto-cycle (TutShowcaseCycle) and tap-hold unchanged; a move tap sets `pod.scHoldUntil` like an ability tap.

- [ ] Step 1: pairs patch `tools/welcome_patch2.luau`.
- [ ] Step 2: apply repo + Studio; compile; hash.
- [ ] Step 3: Studio check, all 7 dinos on PC and iPhone emulation: no overlap with the detail card, ABILITIES still scrolls, every row ≥ 44 px tap height on the phone or the row cell is the tap target of the same size as an ability row (as 1.5; record the measured px).
- [ ] Step 4: commit + push.

**Acceptance:** map rows above; Herrera shows Climb, Drop Attack, Glide, Stun Breaker; Teno shows 1 row next to its 2 attack cards without clipping.
**Out of scope:** SC_ATK / SC_INFO numbers, the roster tiles, NEXT, dots.

### Task 4 — Tutorial 1.7: SPECIAL MOVES on the reveal ("FREE DINO UNLOCKED") · Mode: Wired

**Files:** Modify `drawReveal()` after the lessons loop, before the unlock text / NEXT (LayoutOrder 12–19).

**Layout:** header "SPECIAL MOVES" (title font, cyan, same size as "MAIN ATTACK"); up to 3 rows from `R.movesFor(rolled, 3)`: a rounded pill badge (kind colour, ink text, the badge word) instead of the round lesson badge, then name (black, white, smaller than the lesson name) and line (body, muted, wraps). Switch `TutorialRevealMovesEnabled`.

**Fit rule (deterministic):** after layout (`task.defer`), while the panel's UIListLayout `AbsoluteContentSize.Y` > panel height and more than 1 move row is left, destroy the last move row. NEXT is never removed (it is LayoutOrder 21, after the rows).

**Map:** 0 moves → no header; switch off → 1.6 panel; animate on/off unchanged (rows are inside the CanvasGroup, they fade with it).

- [ ] Step 1: pairs patch `tools/welcome_patch3.luau`.
- [ ] Step 2: apply; compile; hash.
- [ ] Step 3: Studio check: roll each of the 7 dinos (Play, save scripts off; force the roll via the TutorialServer test attribute if one exists, else repeat) on PC + iPhone emulation; record rows kept per dino on the phone; NEXT visible and ≥ 44 px.
- [ ] Step 4: commit + push; VERSIONS.md / ATTRIBUTES.md entries; Dev Hub session log.

**Acceptance:** Herrera reveal shows Climb, Drop Attack, Glide (or the fit-rule subset, recorded); Teno (2 lessons) keeps NEXT on screen.
**Out of scope:** the reveal animation, pod base, scan line.

---

## Self-review
- Coverage: welcome (T2), roster (T3 title + moves), wings-on-JUMP and tree climb / drop explained (T1 data, T3, T4), other dinos' hidden moves (T1 table covers all 7). Tree damage: no change, recorded above.
- No placeholders; names consistent: `movesFor`, `MOVES`, `MOVE_KIND_COLOR_KEY`, `pod.welcomed`, switches `TutorialWelcomeEnabled`, `TutorialRosterTitleEnabled`, `TutorialRosterMovesEnabled`, `TutorialRevealMovesEnabled`.
- Fence: no task touches TutorialServer, LESSONS, gameplay scripts.

## Red-team (pending Kepu)
1. **Moves only shown, never practised.** B is a list you read once; the Herrera climb was the complaint. Pre-mortem: a new Herrera player taps NEXT past the reveal and still never climbs. Mitigation options: keep as picked (accepted risk), or add island hints (option C) later as a follow-on.
2. **Roster gets denser on a phone.** The right panel already holds attack cards, an ability grid and a detail card; 2 more rows shrink the ability list to about 2 visible rows on 750 × 381. Mitigation: 4-row cap, first move opens in the detail card; if the Studio phone check shows the ability list under 2 rows, drop the roster to 2 moves.
3. **Reveal may not fit 3 rows on the phone** (Teno has 2 lessons). Mitigation: the fit rule drops rows, never NEXT.
4. **Verifying needs Play on the wiped account.** Mitigation: Play with the save scripts switched off; nothing saved; reported.
5. **The +30% line.** Glide copy says "SLASH mid-glide: +30% drop", true only at Glider Wings step 3 (the free dino is maxed; a bought Herrera at step 1–2 does not have it). Mitigation: keep (the tutorial dino is maxed), or cut the second sentence.
