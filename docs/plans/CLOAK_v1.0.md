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

| Area | Shared stat | Raptor | T-Rex (interim, until the T-Rex plan) |
|---|---|---|---|
| Health | Regeneration, Lifesteal | Adrenaline Injector (soon) | Med-Station (soon) |
| Attack | Jaws | Blade Claws (soon, passive), Dart Launcher (soon) | Back Turret (soon), Shoulder Rocket (soon) |
| Defense | Thick Hide | **Cloak Field (live)**, Energy Shield (soon) | Armor Plating (soon) |
| Speed | Sprint Legs | Thrusters (live), Grapple Hook (soon) | — (T-Rex speed part comes later) |
| Engineer | — | Pack Beacon (soon), Decoy Hologram (soon) | Sentry, Traps, Barricade (soon) |

- `path.dino` = nil (shared) / "Raptor" / "TRex".
- `SkillTree.pathsFor(areaId, dino)` = the area's paths a dino sees, in order: shared first.
- `sanitize(raw, dino)` also zeroes paths the dino doesn't own. The dino nil or "All" means no filter (1.4 behaviour).
- `canBuy(..., dino)` → "otherDino" for a path the dino doesn't own.
- The T-Rex loses Thrusters, which is now raptor-only. Kepu: "for the t-rex he won't get something like the thrusters". A T-Rex record that holds Thrusters is refunded when it loads (sanitize).

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
- sanitize({thrusters = 2}, "TRex") → thrusters 0.
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
