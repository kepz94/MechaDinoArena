# Mecha Dino Arena v1.0 — Cloak Field (first raptor part) + per-dino trees + 4 slots

**Goal:** the raptor's first own mecha part, Cloak Field: turn nearly invisible to ambush. It ships with two other changes:
- the per-dino tree, where the raptor only sees shared stat paths plus its own parts;
- the 4-slot tap-and-pull loadout (docs/plans/LOADOUT4_v1.0.md, MDA-46/47/48).

**Kepu's calls (2026-10-29):**
- Raptor parts: docs/mockups/raptor_tree_draft.html.
- Cloak Field first.
- Others see a faint shimmer.
- Bots lose you at once.
- The cloak breaks on pounce, on taking damage, and on using another part.
- Cooldown 12 s.

**Architecture:**
- SkillTree gains path ownership (shared / Raptor / TRex), the new raptor paths, 4 slots and the Cloak effects.
- A new CloakServer owns the cloak state (request, timer, breaks).
- A new CloakFX LocalScript draws the shimmer on every client.
- BotServer treats a cloaked player like a hidden one, and loses them at once.
- MechaButtons / AbilityBar / SkillScreen gain the 4 slots and the Cloak part.

## Global Constraints
- Cloud place 84022023159448 only. Check `game.PlaceId` before every install; verify by hash + loadstring compile.
- Versions:
  - SkillTree 1.5 (+ spec)
  - SkillServer 1.3
  - SkillEffects 1.5
  - CloakServer 1.0 (new)
  - CloakFX 1.0 (new)
  - BotServer 1.15
  - PounceServer 1.5
  - MechaButtons 1.4
  - SkillScreen 1.3
  - AbilityBar 1.2
  - ArenaScope 1.6
- 35% rule: every step's number is at least 1.35× the step before.
- Slot ↔ input (LOADOUT4): 1 = button 1 tap / R, 2 = button 2 tap / C, 3 = button 1 pull / T, 4 = button 2 pull / V.

## Do-not-touch
MechaServer (Thrusters), PounceTest, JumpTest, BiteTest / BiteServer, RamTest / RamServer, StatServer, ArenaTouch, ShoulderCam, Territory, the existing T-Rex parts' step texts.

## Path ownership (SkillTree 1.5)

| Area | Shared stat | Raptor | T-Rex (Kepu 2026-10-29 03:10, docs/mockups/trex_tree_draft.html) |
|---|---|---|---|
| Health | Regeneration (not T-Rex), Lifesteal | Adrenaline Injector (soon) | Repair Drone (soon), Bio-Battery Spine (soon, passive) |
| Attack | Jaws | Blade Claws (soon, passive), Dart Launcher (soon) | Shoulder Rocket (soon) |
| Defense | Thick Hide | **Cloak Field (live)**, Energy Shield (soon) | Armor Plating (soon), Reactive Armor (soon, passive) |
| Speed | Sprint Legs | Thrusters (live), Grapple Hook (soon) | Ramjet Charge (soon) |
| Engineer | — | Pack Beacon (soon), Decoy Hologram (soon) | Shield Projector (soon), Roar Amplifier (soon) |

- Med-Station, Back Turret, Sentry, Traps and Barricade belong to no dino yet: `path.dino = "none"`. They stay in the data for future dinos but are shown to nobody. Nothing is removed.
- Regeneration is a shared stat path, but the T-Rex doesn't get it. Kepu, 2026-10-29 03:13: "Remove regeneration from health", then "T-Rex only". This keeps the T-Rex Health area at 3 columns: Lifesteal, Repair Drone, Bio-Battery Spine.
  - Data: `path.notFor = {TRex = true}`. Shared paths without notFor stay for every dino, including future ones.
  - A T-Rex record holding Regeneration steps is refunded on load (sanitize). This is the same rule as Thrusters.
- `path.dino` = nil (shared) / "Raptor" / "TRex" / "none" (shown to nobody); `path.notFor` = dinos a shared path skips (regen: TRex).
- `SkillTree.pathsFor(areaId, dino)` = the area's paths a dino sees, in order: shared first.
- `sanitize(raw, dino)` also zeroes paths the dino doesn't own. The dino nil or "All" means no filter (1.4 behaviour).
- `canBuy(..., dino)` → "otherDino" for a path the dino doesn't own.
- The T-Rex loses Thrusters, which is now raptor-only. Kepu: "for the t-rex he won't get something like the thrusters". A T-Rex record that holds Thrusters is refunded when it loads (sanitize).

## Mastery 3 + additive bonuses (Kepu 2026-10-29 03:20–03:25)
Kepu: "limiting the player to only be able to fully fill some lines", then "what do you think is the best middle ground". He took the recommended Mastery 3 and "Yes, add them". Mockup docs/mockups/mastery_options.html, option A "Mastery chip".

**The rule (SkillTree 1.5):**
- A line (any path, stat or mecha) is **mastered** when its step is ≥ 3. MASTERY_MAX = 3.
- `canBuy(steps, id, points, dino)`: buying step 3 of a line that is not yet mastered while 3 lines are already mastered → "masteryFull". This is checked after "otherDino" / "soon" / "maxed" and before "noPoints".
- `mastered(steps)` returns the list of mastered ids in PATH_ORDER. `masteryOk(steps)` is true when the count ≤ MASTERY_MAX.
- Points stay at 60. Respec (free) clears all masteries.
- Spec cases:
  - The 4th line's step III → masteryFull.
  - A 3rd line's step III → ok.
  - The ★ of a mastered line → ok.
  - Steps I / II of any line → unaffected.

**Point budget (Kepu 2026-10-29 03:24):** "Doesn't step 2 of every skill still seem over powered. The point is you have to lean into a build not have every ability".
- At 60 points, Mastery 3 still left about 10 lines at step II.
- Picks: **40 points** and **level cap 41**.
- SkillTree 1.5: MAX_POINTS = 40, MAX_LEVEL = 41. pointsOf(level) = min(level − 1, 40). levelOf caps at 41, where xpNext = 0 and the bar shows "MAX".
- A maxed dino has 3 mastered lines (30 points) plus 10 points, e.g. 3 lines at step II and 1 at step I.
- Records over 40 spent points are refunded on load: SkillServer's existing "spent > points" rule, using the new cap.
- Spec: update the level-curve cases (cap 41) and add pointsOf(41) = 40, pointsOf(61) = 40.

**Old saves (SkillServer 1.3 cleanRecord):** a record with more than 3 mastered lines has every line cut back to step II. The refunded points come back; the player picks again.

**Same-hit bonuses add, not multiply:**
- Bonus damage on one hit is 1 + the sum of its bonus fractions.
- PounceServer 1.5 landing: 1 + (cloak 0.35 if CloakPounceArmed) + (blade bonus when Blade Claws ships) + (roar debuff − 1 when the target is debuffed).
- Today's roar debuff is the only multiplier, so for it alone nothing changes.
- Later parts on the same hit (Reactive Armor bite, Roar Amplifier) follow the same rule when they ship.
- Cooldown multipliers (mainCdMul × moveCdMul) are not damage and are unchanged.

**SKILLS screen (SkillScreen 1.3, option A):**
- A gold chip "MASTERY n/3" in the top bar, after the level box: rgb(255, 214, 102) stroke and text, panel background.
- Mastered lines get a gold ♛ before the column name and a gold 2 px inner outline at 0.45 transparency.
- When 3 lines are mastered, steps III and ★ of the other lines show at 0.35 with a 🔒.
- The detail panel shows the reason in gold: "You have mastered 3 lines (A, B, C). Only 3 lines can go past step II."
- Buy button: "MASTERY FULL · RESPEC TO CHANGE" (not pressable).

## Cloak Field steps (35% rule)

| Step | Text | Effect keys |
|---|---|---|
| I | Turn nearly invisible for 3 s. Bots lose you; ends when you pounce, get hit or use another part | cloakTime 3, cloakCooldown 12 |
| II | Lasts 4.1 s | cloakTime 4.1 |
| III | A pounce out of the cloak hits 35% harder | cloakPounceMul 1.35 |
| ★ | Standing still keeps you cloaked, up to twice as long | cloakStill true (cap: CloakedUntil ≤ CloakStartedAt + 2 × CloakTime) |

**Cooldown rule:** CloakReadyAt = the moment the cloak ends + cloakCooldown. Starting the cooldown at the cloak's start would let the ★ cloak, which can last forever, be re-used at once.

## Deterministic state map — CloakServer 1.0

Request `DinoCloakRequest:FireServer(stamp)`. Checks run in this order; the first that fails gives its result:

| Result | Condition |
|---|---|
| badArg | stamp is not a number |
| dead | Humanoid health ≤ 0 |
| disabled | CloakEnabled ~= true (SkillEffects: bought and slotted) |
| stunned | StunnedUntil > now |
| latched | PounceLatched == true |
| active | CloakedUntil > now |
| cooldown | now < CloakReadyAt |
| ok | otherwise: CloakedUntil = now + CloakTime, CloakStartedAt = now, CloakState "on" |

Every Heartbeat while CloakState == "on", the first matching row ends the cloak:

| End reason | Trigger |
|---|---|
| pounce | PounceStartedAt changes to a value ≥ CloakStartedAt. Also sets CloakPounceArmed = PounceStartedAt, used by PounceServer 1.5. |
| damage | Humanoid.Health drops below the last value seen. Healing doesn't count. |
| part | DashStartedAt changes (Thrusters), or any later part's start stamp. |
| still | CloakStill is on and flat speed < 1 stud/s: CloakedUntil = min(now + 0.25, CloakStartedAt + 2 × CloakTime). This keeps the cloak alive up to the cap; it does not end it. |
| time | now ≥ CloakedUntil |
| dead | health 0 or the character is removed |

On any end: CloakedUntil = now, CloakState "off", CloakEndReason = reason, CloakReadyAt = now + CloakCooldown.

## Task 1 — SkillTree 1.5 · Mode: Logic
**Files:** Modify `src/shared/SkillTree.luau`. Spec in the usual fresh-clone spec runner.

**Changes:**
- `path.dino`, `pathsFor`, a dino-aware `sanitize` / `spent` / `canBuy` / `buy` (a new optional last argument `dino`).
- New paths:
  - adrenaline, blade, dart, cloak, beacon, decoy, with draft texts from raptor_tree_draft.html.
  - shield and grapple become raptor-only.
- LIVE_MECH += cloak; BUTTONS += cloak (and every new button part).
- SLOTS = 4.
- effects adds cloakTime, cloakCooldown, cloakPounceMul (1 below III), cloakStill.

**Acceptance (spec):**
- pathsFor("defense", "Raptor") = {hide, cloak, shield}.
- pathsFor("defense", "TRex") = {hide, armor}.
- canBuy cloak as TRex → "otherDino"; as Raptor at 1 point → ok.
- sanitize({thrusters = 2, regen = 2}, "TRex") → thrusters 0, regen 0.
- pathsFor("health", "TRex") = {lifesteal, repairdrone, biobattery}.
- pathsFor("health", "Raptor") = {regen, adrenaline, lifesteal}.
- Cloak effects per step as in the table.
- 4-slot loadout cases from LOADOUT4 Task 1.
- Every existing spec case still passes.

## Task 2 — SkillServer 1.3 + SkillEffects 1.5 · Mode: Wired
**Files:** Modify `src/server/SkillServer.server.luau` and `src/server/SkillEffects.server.luau`.

**SkillServer:**
- Passes the active dino key to sanitize / buy / spent and cleanRecord.
- Empty loadouts are built from SLOTS.
- Result "otherDino" goes to SkillLastResult.

**SkillEffects** writes on the character:
- CloakEnabled: effects on, cloak step ≥ 1 and slotted in any of slots 1–4.
- CloakTime, CloakCooldown, CloakPounceMul, CloakStill.

**Acceptance:**
- A raptor buys Cloak and it auto-slots.
- A T-Rex buy of "cloak" → otherDino.
- CloakEnabled follows the slot.
- An old T-Rex save holding Thrusters loads refunded.

## Task 3 — CloakServer 1.0 (new) + PounceServer 1.5 + BotServer 1.15 · Mode: Wired
**Files:**
- Create `src/server/CloakServer.server.luau`.
- Modify `src/server/PounceServer.server.luau`: on landing, damage × CloakPounceMul when CloakPounceArmed == this pounce's PounceStartedAt; then clear it.
- Modify `src/server/BotServer.server.luau`: `visible(char)` also needs CloakedUntil ≤ now. A chase target whose CloakedUntil > now is dropped at once.

**Interfaces:**
- Produces character attributes: CloakedUntil, CloakStartedAt, CloakReadyAt, CloakState, CloakEndReason, CloakPounceArmed, CloakResult.
- Produces script attributes: CloakServerVersion, CloakEnabledScript (default true).

**Acceptance:**
- Request ok and the cloak lasts CloakTime. A second request while active → "active"; within the cooldown → "cooldown".
- Each end reason fires as mapped:
  - pounce, damage, part, time;
  - ★ standing still keeps the cloak alive.
- A bot chasing you drops you at once; idle bots don't notice you while cloaked.
- At III the pounce landing from cloak deals 1.35×.
- Hashes match; docs.

## Task 4 — CloakFX 1.0 (new) · Mode: Wired
**Files:** Create `src/client/CloakFX.client.luau` (StarterPlayerScripts).

**Look:**
- For each character with CloakedUntil > server now, set the LocalTransparencyModifier of every BasePart except HumanoidRootPart:
  - your own: 0.6;
  - others: 0.9, with a shimmer between 0.88 and 0.94 on a 0.6 s sine.
- Others' BillboardGuis (name / health tags) are switched off while they are cloaked.
- Everything is restored when the cloak ends.
- Diagnostic: CloakFXSeen (count) on the local character.

**Acceptance:**
- Own body ghosted at 0.6; another cloaked dino at about 0.9; restored afterwards.
- No leftover transparency after a death mid-cloak.

## Task 4b — Cloak hardware (visible part) · Mode: Wired
Added 2026-10-29 03:10 after Kepu's rule for every mecha part: "It needs an actual physically visible mecha part". Thrusters already follows it (MechaServer boosters).

**Files:** Modify `src/server/CloakServer.server.luau` (same release).

**Look:**
- While CloakEnabled is true, the raptor wears a "Mecha_Cloak" emitter pack: two thin fins on the Torso segment, welded like Mecha_Thrusters and sized from the dino's height. Grey metal with neon strips.
- The strips glow cyan (Neon, 0.2 transparency) while cloaked, and dim (0.7) otherwise.
- The pack is cloaked along with the body.
- Removed when CloakEnabled goes false.

**Acceptance:** fins visible on a raptor with Cloak slotted; they glow while cloaked; gone when unslotted.

## Task 5 — 4 slots + Cloak on the controls · Mode: Wired
This is LOADOUT4 Tasks 2 and 3 (MDA-47 / MDA-48), plus:
- **MechaButtons 1.4:** a press on a slot holding "cloak" fires DinoCloakRequest(server now). The button shows "CLOAK", dimmed while cooling, with the cooldown fill from CloakReadyAt. The sub-label shows "▼ CLOAK" when it is the pull part.
- **AbilityBar 1.2:** the cloak tile is
  - "active" while CloakedUntil > now;
  - "cooling" until CloakReadyAt (fill = left / CloakCooldown);
  - "off" while CloakEnabled ~= true.
- **SkillScreen 1.3:** each area shows `pathsFor(area, Species)`, so the raptor's Engineer area has 2 columns and the T-Rex's Speed area 1. Plus the 4-slot strip.

**Acceptance:**
- Phone: tap / pull triggers cloak or Thrusters as slotted.
- PC: R / T / C / V.
- The raptor tree shows only raptor + shared paths; the T-Rex tree shows no Thrusters / Cloak.
- Kepu's phone and PC check.

## Task 5b — SkillScreen 1.3 layout: classic tier rows
Kepu 2026-10-29 04:01: "I love C's". Mockup: docs/mockups/skilltree_classic_options.html, option C "Tier rows". Rejected along the way: the blueprint, circuit board, bone & bolt and garage mockups.

This replaces the 1.2 area rail + 3-column view. The top bar, the detail panel (right) and the loadout strip stay.

**Tree area:**
- One column per line the dino sees (`pathsFor(area, Species)` for each area in AREAS order), grouped by area.
  - Columns are 40 px apart, with an 18 px gap between areas.
  - Under each group: an area-coloured 3 px bar and the area name, FredokaOne 12.5.
- Rows bottom → top are I, II, III, ★, with faint row bands and a row label at the left.
- Under everything, a rounded bar with the dino name (T-REX / RAPTOR) acts as the root. Each column's line rises from its area bar to step I.
- **Nodes:**
  - Shape: dino stats are circles (r 12; ★ r 15), mecha parts are hexagons.
  - Bought: filled in the area colour.
  - Next buyable: white outline.
  - Not yet: dark with a faint outline.
  - Coming soon: dashed outline, 0.6 opacity.
  - Locked by mastery: 0.4 opacity with a 🔒.
  - Selected: yellow ring.
- **Links:** lit in the area colour up to the bought step; faint above it; dashed for soon lines.
- **Mastered line:** a gold ring around each node plus a gold glow under its links. This replaces the ♛ / outline of the mastery mockup A. The top-bar chip "MASTERY n/3" stays.
- **Mastery line:** a gold dashed rule between rows II and III, labelled "mastery line: 3 lines can go above".
- Only area names are written on the tree. The selected line's name shows above its ★ in yellow; the full name and steps are in the detail panel.
- **Fit:** the tree scales to its width, with the node radius at least 9.
  - Below that, the tree scrolls sideways inside its pane and the selected column is scrolled into view.
  - Acceptance: a small phone (568 px tall view) and PC.

**Acceptance:**
- Raptor and T-Rex trees match their part lists.
- Bought, next, soon, locked, mastered and selected states all show as above.
- The mastery rule appears between II and III.
- Tapping a node selects it; BUY works.
- It fits or scrolls on a small phone.
- Kepu checks it.

## Task 6 — ArenaScope 1.6 · Mode: Wired
Expects CloakServer and CloakFX on.

## Red-team synthesis (Kepu 2026-10-29 ~03:05)
- #2: **remove now.** Thrusters is raptor-only from this release; the T-Rex Speed area shows Sprint Legs only until its own part.
- #5: **show as "soon".** The raptor's unbuilt parts appear greyed with the "soon" tag.
- #3: **cap it.** The ★ keeps the cloak while still, up to 2 × CloakTime from its start (table and state map updated).
- #1 and #4 stand: build in task order with an install + verify after each; any health drop breaks the cloak.

## Red-team (pre-filing)
1. **Scope.** Three features in one release (per-dino tree, 4 slots, Cloak) and 10 scripts touched. If Cloak slips, the other two wait on it.
   - Mitigation: build in task order. Tasks 1–2 (tree + slots) are playable on their own with Thrusters; Cloak lands on top.
   - Each task is installed and verified before the next.
2. **The interim T-Rex tree is thin.** The T-Rex loses Thrusters, and its Speed area shows only Sprint Legs until its own speed part is planned.
   - Option: keep Thrusters on the T-Rex until its speed part exists. Kepu decides.
3. **The ★ step can cloak forever while standing still**, a strong camping tool once PvP comes.
   - Accepted now (bots only); revisit with PvP.
4. **"Damage" break triggers on any health drop.** Today that is bot bites. Later it also covers fall damage, if any.
   - Accepted.
5. **The raptor tree shows many "soon" parts** (7 of 9). That can look unfinished.
   - Option: hide "soon" parts in the raptor tree until built. Kepu decides.
