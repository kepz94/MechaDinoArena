# Mecha Dino Arena — Mecha parts v1.0: framework + Thrusters

**Goal:** buy a mecha part in the skill tree, put it in one of 2 loadout slots, see it on the dino, and use it from a button.
The first part is Thrusters (dash).
**Chosen direction (docs/mockups/mecha_thrusters_options.html):**
- Buttons **A · Thumb arc**: slot 1 in RUN's spot, slot 2 continues the arc.
- Loadout **L2 · Loadout bar** under the tree.

**Kepu's answers (2026-10-28):**
- "Mecha parts"; the first piece is the framework + 1 part. Thrusters first.
- Mecha weapons hit bots only, until PvP is its own piece.
- Thrusters numbers and PC keys 1 / 2 "OK as proposed".
- From the brainstorm (docs/plans/SKILLTREES_brainstorm.md):
  - 2 mecha buttons on screen, filled from loadout slots that you swap in a menu;
  - parts are blocky, built in code, mounted on the body;
  - the look changes with each upgrade.

**Architecture:**
- SkillTree 1.1 makes Thrusters buyable and adds the loadout maths.
- SkillServer 1.1 saves and serves the 2 slots.
- SkillEffects 1.1 turns the Thrusters steps into character settings.
- MechaServer 1.0 (new) validates the dash, tracks charges and mounts the visible part.
- MechaButtons 1.0 (new) draws the 2 slot buttons and the PC keys and does the dash physics on the owner's client.
- SkillScreen 1.1 adds the loadout bar.
- ArenaScope 1.4 expects the 2 new scripts on.

## Global constraints
- **Studio target:** the cloud place Mecha Dino Arena, **placeId 84022023159448**. Check `game.PlaceId` before every install.
- **Additive only.** Every change gets:
  - a header vX.Y and a changelog line;
  - a `<Name>Version` attribute;
  - a VERSIONS row and an ATTRIBUTES section.
- **Toggles and attributes:** every new behaviour has an on/off attribute, and every state change is an attribute.
- **Install check:** hash plus a loadstring compile.
- **Bots only:** nothing in this piece damages players.
- **Thrusters numbers** (attributes, all tunable):

| Step | Effect |
|---|---|
| I | dash 35 studs in 0.35 s; recharge 8 s; no stamina cost (Kepu red-team answer: free) |
| II | 2 charges (each recharges 8 s) |
| III | 50-stud dash |
| ★ | rocket hop: the dash also lifts about 25 studs |

- **PC keys:** 1 = slot 1, 2 = slot 2.

## Facts read in the code (MechaDinoArena @ 390c80c)
- **SkillTree 1.0**
  - `path("thrusters", "Thrusters", true, true, ...)` in area speed: mech = true, soon = true.
  - `sanitize` zeroes soon paths and `canBuy` refuses them ("soon").
- **SkillServer 1.0**
  - Save value `{v = 1, xp, steps}`.
  - SkillRequest ("buy", id) / ("respec").
  - Player attributes `SkillPath_<id>` and `SkillLastResult`.
- **SkillScreen 1.0**
  - `Root.Body` holds Rail (64 px), Cols (x 72, width 1 − (72 + detail + 8)) and Detail (220 px or 30%).
  - The detail sub-line says "passive / mecha part".
- **Movement physics** is done by the owner's client (JumpServer 1.0: "the server only gates the request and its stamina cost"). JumpServer checks, in order: badArg / dead / disabled / exhausted / stamina / cooldown.
- **StaminaServer 1.4** charges JumpStartedAt / PounceStartedAt / RamStartedAt.
  - Mecha runs StaminaPounceOnly = true, so stamina only shows while latched (ArenaStatus).
  - The pounce needs 15.
- **Free spots on the phone:** RUN's spot (ArenaTouch 1.2: right 21%, bottom 8%, 9.5% of the width) is free while AutoRun is true. ArenaRules 1.1 sets AutoRun on every device.
- **Free PC keys:** 1 and 2. In use: Q shoulder swap, E ram, F pounce, R roar, C creep, H hitboxes, K skills, Shift run.
- **Mount point:** `Torso_body` (Part) inside the `Torso` Model.
  - T-Rex size (4.5, 6.49, 7.8) at scale 1.
  - The raptor has the same names and is at scale 2 (RaptorScale 1.0).

## Do-not-touch
- ArenaTouch, StaminaServer, JumpTest / JumpServer, PounceServer, BiteServer, BotServer, StatServer, RaptorScale, ShoulderCam, IdleAnimation.
- The 4 passive paths' effects (SkillEffects 1.0 values).
- The other 9 mecha paths stay "soon".

## File structure
| File | Change |
|---|---|
| `src/shared/SkillTree.luau` | → 1.1: LIVE mecha set, BUTTON parts, `effects` dash fields, `sanitizeLoadout` / `autoSlot` |
| `tools/tests/SkillTree.spec.luau` | → 1.1: new cases |
| `src/server/SkillServer.server.luau` | → 1.1: loadout in the save, ("slot", n, id) request, `SkillSlot1` / `SkillSlot2` |
| `src/server/SkillEffects.server.luau` | → 1.1: Dash* character attributes from the build |
| `src/server/MechaServer.server.luau` | new: dash requests, charges, mounted Thrusters part, flame |
| `src/character/MechaButtons.client.luau` | new: 2 slot buttons (touch), keys 1 / 2, dash physics |
| `src/character/SkillScreen.client.luau` | → 1.1: loadout bar, Thrusters column live, "mecha button" sub-line |
| `src/server/ArenaScope.server.luau` | → 1.4 |

### Task 1 — SkillTree 1.1 · Mode: Logic
**Interfaces (Produces):**
- **`SkillTree.LIVE_MECH = {thrusters = true}`:** at load, `PATHS[id].soon = false` for these ids.
- **`SkillTree.BUTTONS = {thrusters = true}`:** mecha parts that take a loadout slot.
- **`SkillTree.SLOTS = 2`.**
- **`effects(steps)` adds:**
  - `dashCharges`: 0 when not bought, 1 at I, 2 from II;
  - `dashDist`: 35, or 50 from III;
  - `dashHop`: 0, or 25 at ★.
- **`sanitizeLoadout(raw, steps) -> {[1] = id or false, [2] = id or false}`:**
  - each entry is a BUTTONS id with steps ≥ 1;
  - no id appears twice (the first wins);
  - anything else becomes false.
- **`autoSlot(loadout, steps, pathId) -> loadout`:** when pathId is a BUTTONS id with steps ≥ 1 and is not slotted yet, it goes in the first false slot; otherwise the loadout is unchanged. Never changes its input.
- **`setSlot(loadout, steps, n, pathId or false) -> loadout or nil, reason`:**
  - reasons: "ok" / "badSlot" / "notOwned" / "notButton";
  - putting an id in slot n removes it from the other slot.

**Spec (fresh-clone run):**
- Thrusters buyable; I → II order; costs 1-2-3-4.
- effects at 0 / 1 / 2 / 3 / 4 steps.
- sanitizeLoadout: junk, duplicates, unowned, soon / passive ids.
- autoSlot: first free slot, already slotted, slots full.
- setSlot: swap between slots, clear, every reason.
- The 1.0 cases still pass.

### Task 2 — SkillServer 1.1 · Mode: Wired
- **Save value** `{v = 1, xp, steps, loadout}`. Loaded with `sanitizeLoadout(value.loadout, steps)`. A save without `loadout` → `{false, false}`.
- **Buying a BUTTONS path's first step** → `autoSlot`.
- **New request:** `("slot", n, pathId or "")`. "" = clear. Result in SkillLastResult.
- **Respec** clears both slots.
- **Player attributes:** `SkillSlot1`, `SkillSlot2` (path id or "").
- **Toggle:** `SkillLoadoutEnabled` (default true); false → requests "disabled", and slots stay as saved.

**Acceptance (Play):**
- buying Thrusters I → SkillSlot1 "thrusters";
- slot 2 request → it moves to slot 2;
- clear → "";
- respec → both "";
- an unowned id → "notOwned".

### Task 3 — SkillEffects 1.1 · Mode: Wired
Character attributes from `effects()`, re-applied on build or slot change:
- `DashEnabled`: true when dashCharges > 0 **and** "thrusters" is in a slot;
- `DashCharges`, `DashDistance`, `DashHop`;
- `DashTime` 0.35, `DashRecharge` 8: script attribute defaults, copied to the character.

`SkillEffectsEnabled` false → DashEnabled false.

### Task 4 — (cut) StaminaServer 1.5
Cut after the red-team: the dash is free (Kepu). StaminaServer is not changed.

### Task 5 — MechaServer 1.0 · Mode: Wired
**Remote** `ReplicatedStorage.DinoDashRequest:FireServer(stamp)`.

**Checks, in order:**
1. "badArg"
2. "dead"
3. "disabled" (DashEnabled ~= true)
4. "stunned" (StunnedUntil > now)
5. "latched" (PounceLatched)
6. "charges" (no charge left)
7. "ok"

**On "ok":**
- `DashStartedAt` = the stamp clamped to [now − 0.3, now];
- `DashCount` + 1;
- one charge is used.

**Charges:**
- `DashChargesLeft`, and `DashNextChargeAt` (server time; 0 when full);
- one charge comes back every DashRecharge s until full;
- a change in DashCharges clamps the count.

**On a deny:** `DashDenyReason`, `DashDeniedAt` = stamp, `DashServerResult`.

**Mounted part:**
- **Model `Mecha_Thrusters`** under the character: 2 blocky boosters welded to `Torso_body`.
  - Placed on top, at the back, left and right of the spine.
  - Sizes are fractions of Torso_body.Size, so they scale with the dino.
  - Parts are Massless, CanCollide / CanQuery / CanTouch false.
- **Look per step:** I small boosters; III bigger (×1.3); ★ adds orange fins.
- **Shown** while DashEnabled is true; removed otherwise.
- **Flame:** a ParticleEmitter on each nozzle, Enabled for DashTime after each DashStartedAt.

**Settings and diagnostics:**
- Toggle: script `MechaEnabled` (true); false → every request "disabled", and parts are removed.
- Diagnostics:
  - character `MechaThrustersLook` ("none" / "I" / "III" / "star");
  - script `MechaServerVersion`, `MechaDashes`.

**Acceptance (Play):**
- dash accepted, charge used, comes back after 8 s;
- the 2 charges at II;
- denials: stunned, latched, charges;
- the part is visible on the T-Rex and the 2x raptor and changes at III / ★;
- hitboxes and bites are unchanged (BiteServer kill on a bot still works with the part on).

### Task 6 — MechaButtons 1.0 · Mode: Wired
**Layout (option A; AnchorPoint (1, 1), fractions of the screen like ArenaTouch):**

| AutoRun | Slot 1 | Slot 2 |
|---|---|---|
| true | right 21%, bottom 8%, 9.5% of the width | right 32.5%, bottom 18%, 9.5% |
| false (RUN is shown) | right 33%, bottom 8%, 9.5% | right 33%, bottom 28%, 9.5% |

- **Button look:** a rounded square (corner 22%) on panel (20, 20, 26) at 0.3, with a 2.5 px Engineer-orange (255, 155, 46) stroke.
- **Full slot:** icon text "DASH", charge pips at the top right, and a dark cooldown fill (DashNextChargeAt) while it isn't full.
- **Empty slot:** dashed look, "+", "slot n". It does nothing.
- **ScreenGui:** `MechaButtons` (DisplayOrder 5), touch devices only. PC: no buttons; keys 1 / 2.
- **Press:** a full slot with "thrusters" → `DinoDashRequest:FireServer(serverNow)`.
- **Physics (owner client), on a new DashStartedAt:**
  - a LinearVelocity on the HumanoidRootPart, plane mode (X / Z), speed DashDistance / DashTime along the flat look direction, for DashTime;
  - with DashHop > 0, also AssemblyLinearVelocity.Y = sqrt(2 × gravity × DashHop) at the start.
- **Diagnostics:** `MechaButtonsVersion`, `MechaButtonsState` ("on" touch / "keys" PC), `MechaButtonsLastPress`, `MechaDashLocal` ("idle" / "dashing").

**Acceptance:**
- emulator: buttons in place, with no overlap with BITE / POUNCE / LEAP;
- the dash moves about 35 studs (50 at III); a hop rises about 25 studs;
- PC: keys 1 / 2.

### Task 7 — SkillScreen 1.1 · Mode: Wired
**Layout (option L2):**
- `Root.Body.Loadout`: x 72, height 44, at the bottom of the body, as wide as Cols.
- Cols height becomes body − 52.
- Contents:
  - an orange "LOADOUT" label;
  - `Slot_1` / `Slot_2` tiles (120 × 36, dashed when empty, orange stroke when full, text "Slot n · ⚙ Thrusters" / "Slot n · empty");
  - a hint "Tap a slot to change it".

**Behaviour:**
- **Tap a slot:** it cycles through the player's bought BUTTONS parts, then empty, and fires ("slot", n, id or "").
- **Thrusters column:** live (soon = false from SkillTree 1.1).
- **Detail sub-line:** "mecha button" for BUTTONS paths.
- **Toggle:** `SkillScreenLoadoutEnabled` (true).

**Acceptance:**
- the phone emulator and PC show the bar;
- a tap changes SkillSlot1 / SkillSlot2;
- the tree still fits on small phones (all 4 nodes visible).

### Task 8 — ArenaScope 1.4 · Mode: Wired
Expects MechaServer and MechaButtons on. Acceptance: ArenaScopeMismatches 0.

## Deterministic map (new states)
- **Slots:** each one is empty, or holds thrusters. Buying Thrusters I fills the first empty slot; with both full, nothing changes.
- **DashEnabled:**
  - false: no steps, not in a slot, SkillEffects off, MechaEnabled off;
  - true: otherwise.
- **Dash request:** the 7 results in order. Only "ok" moves the dino.
- **Charges:** full → used → recharging → full. A step change (I → II) adds the new charge as full.
- **Look:** none / I / III / star from the steps, shown only while DashEnabled is true.

## Build notes (measured in Play, 2026-10-28)
- **Sizing:** Torso_body alone is not the body's length (the T-Rex torso runs over several parts in the Torso segment), and
  the raptor's torso is slim (boosters sized from it were 0.5 stud wide). MechaServer measures the whole Torso segment for
  placement and sizes the boosters from the dino's height (0.09 / 0.13 / max(torso length x 0.35, height x 0.22)), welded
  to Torso.Root.
- **Slide:** without stopping the dash speed the dino slid ~60 studs after a 50-stud dash; MechaButtons zeroes the
  horizontal speed at the end (dash then measured 48.9 / 50.0 studs, slide 0).
- **Test hook:** MechaButtonsForceTouch (Studio has no phone emulator access from scripts here).

## Red-team (Kepu's answers 2026-10-28)
1. **Dash vs pounce stamina.** The raptor's pounce needs 15 stamina, and the dash costs 15. A dash right before a pounce can block the pounce ("stamina"), and in Mecha the stamina bar is hidden until a latch.
   - **Answer: free (0 stamina).** Charges and the 8 s recharge are the only limit. Task 4 is cut; MechaServer has no stamina checks.
2. **Part shown only while slotted.** A bought but unslotted Thrusters is not on the dino and can't be used.
   - **Answer: only while slotted** (as planned: DashEnabled needs a slot).
3. **The dash ignores walls.** LinearVelocity can push a dino into a tree or over the water edge, and the 50-stud ★ hop can land on high ground.
   - Accepted for now. StepAssist / the water rules still apply after landing.
4. **Two slots, one part.** Slot 2 can only ever be empty or hold Thrusters until the next part ships. The framework is exercised with swap and clear, not with two different parts.
5. **Scope.** 8 tasks, 2 new scripts, 6 changed. The smaller version (no loadout bar: Thrusters goes straight to slot 1) would save Task 7 and part of Task 2, but the loadout is what the next 9 parts need.
