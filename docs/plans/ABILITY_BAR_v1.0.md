# Mecha Dino Arena v1.0 — Ability Bar (PC)

**Goal:** on PC, always show which mecha parts are in the two loadout slots and every move's cooldown.
**Chosen direction:** option B "Ability bar" — mockup docs/mockups/ability_hud_options.html (Kepu 2026-10-29 02:08: "i like the ability bar on pc").
**Architecture:** one new LocalScript in StarterCharacterScripts draws a display-only bar bottom-centre on non-touch devices. It reads the attributes the move scripts and servers already set (no new remotes, no input), so it can be switched off without touching any move.

## Global Constraints
- Cloud place "Mecha Dino Arena", placeId 84022023159448 only. Check `game.PlaceId` before every install.
- Version tags: AbilityBar 1.0, ArenaScope 1.5. Header vX.Y + changelog, `AbilityBarVersion` attribute, docs/VERSIONS.md row, docs/ATTRIBUTES.md section.
- Install verified by hash (h = 7; h = (h × 31 + byte) % 2147483647) and a loadstring compile.
- Touch devices (UserInputService.TouchEnabled) keep their current buttons (ArenaTouch 1.2 / MechaButtons 1.3); no bar there.
- The bar is display-only: Frames and TextLabels, no buttons, so a left click still bites.

## Do-not-touch
MechaButtons (slot keys R / C, boost physics, touch tiles), ArenaTouch, PounceTest, BiteTest, JumpTest, RamTest, SprintTest, MechaServer, SkillServer, SkillEffects, GrowthBar, ArenaStatus, SkillScreen.

## Grounded facts (repo 7260258 + live Studio 2026-10-29)
- Raptor in the arena has no bite: ArenaRules 1.2 sets BiteEnabled = false (ArenaRaptorNoBite). Its moves are Pounce (F) and Leap (Space, JumpTest, JumpEnabled).
  The mockup showed a raptor Bite tile, which is wrong for this game.
- T-Rex moves: Bite (left click, BiteTest) and Ram (E, RamTest 1.1). Ram is bound only while a raptor is latched on (RamLatchGate "open" / "closed").
- Cooldown clocks, all server time set by the owner client at the press: BitePredictedAt + BiteCooldown, PouncePredictedAt + PounceCooldown, JumpPredictedAt + JumpCooldown, RamPredictedAt + RamCooldown.
  The cooldown attributes are rewritten by SkillEffects (mainCdMul / moveCdMul), so they are read live.
- Thrusters: DashEnabled, DashCharges, DashChargesLeft, DashNextChargeAt (server time), DashRecharge; MechaDashLocal "dashing" while boosting. Slots: player SkillSlot1 / SkillSlot2 (path id or "").
- Bottom-centre on PC today: GrowthBar only, bottom edge 198 px above the screen bottom (SurvivalBars, HealthBar and StaminaBar are off). The space under it is empty.

## File structure
- Create `src/character/AbilityBar.client.luau` (StarterCharacterScripts LocalScript): the whole bar.
- Modify `src/server/ArenaScope.server.luau`: expect AbilityBar on (1.5).
- Docs: `docs/VERSIONS.md`, `docs/ATTRIBUTES.md`.

## Layout (PC)
- ScreenGui "AbilityBar" in PlayerGui, DisplayOrder 5. Any old "AbilityBar" is destroyed at start, and the bar is destroyed with the character.
- Holder: AnchorPoint (0.5, 1), Position (0.5, 0, 1, -24), one row, centred.
- Tile size T = clamp(viewport width × 0.045, 56, 84) px, square, re-computed on viewport change. Gap 8 px. Divider: 2 px wide, 0.8 T tall, white at 0.65 transparency, 12 px space either side.
- Order (left to right): Slot 1 (key R), Slot 2 (key C), divider, then the dino's own moves. The bar is different for every dino (Kepu 2026-10-29: "the abilities bar should be different for every dino").
  - A per-species table SPECIES_MOVES in the script holds the order:
    - Raptor = {Pounce F, Leap Space}
    - TRex = {Bite LMB, Ram E}
    - A new dino gets its own row.
  - A species with no row gets every enabled move in the fixed order Bite, Pounce, Leap, Ram.
  - A move whose Enabled attribute is false gets no tile.
  - Ram's tile exists only while it is usable (Kepu: "Only when usable"): RamLatchGate ~= "closed", or a ram is running.
- Tile look, the same family as the MechaButtons touch tiles:
  - Rounded square, corner 22%, panel rgb(20, 20, 26) at 0.3 transparency.
  - Stroke 2.5 px: Engineer orange rgb(255, 155, 46) for slots, white for moves, attack red rgb(240, 90, 79) for Bite. An empty slot gets a white stroke at 0.5.
  - Key hint top-left, 0.2 T, white at 0.2.
  - Name centred, 0.2 T, FredokaOne: "DASH", "POUNCE", "LEAP", "BITE", "RAM", or "+" for an empty slot.
  - Charge pips top-right (Thrusters only): circles 0.1 T, orange when charged, white at 0.75 when spent.
  - Cooldown fill: black at 0.38 transparency, rising from the bottom, height = remaining / total.
  - Seconds text bottom-centre, 0.17 T, rgb(255, 217, 168), one decimal ("2.4s").
  - Highest point of the bar = 24 + 84 = 108 px above the bottom, which stays under GrowthBar (198 px).

## Deterministic state map (per tile; first match wins)

| Tile | State | Condition | Look |
|---|---|---|---|
| Slot n | empty | SkillSlot<n> == "" or nil | "+", white stroke at 0.5, no timer |
| Slot n (thrusters) | off | DashEnabled ~= true | name dimmed (tile transparency +0.5) |
| | active | MechaDashLocal == "dashing" | stroke 4 px, white |
| | cooling | DashChargesLeft == 0 | fill = (DashNextChargeAt − now) / DashRecharge, seconds, tile dimmed 0.25 |
| | ready | DashChargesLeft ≥ 1 | pips = DashChargesLeft of DashCharges. If DashChargesLeft < DashCharges: fill + seconds to the next charge, not dimmed |
| Slot n (other id) | ready | any other path id | uppercase path name from ReplicatedStorage.SkillShared, no timer |
| Move | stunned | StunnedUntil > now | "STUN" sub-label, dimmed 0.25 |
| Move | active | its TestState is windup / lunge / latched (Pounce), crouch / air (Leap), charge / windup / recoil (Ram); BiteInputResult does not give a state, so Bite has no active state | stroke 4 px, white |
| Move | cooling | now < <Move>PredictedAt + <Move>Cooldown | fill + seconds |
| Ram | hidden | RamLatchGate == "closed" and RamTestState is "ready" / "off" (no tile; the row re-lays) | — |
| Move | ready | otherwise | plain |

`now` = workspace:GetServerTimeNow(), the clock the PredictedAt / DashNextChargeAt stamps use.

Whole bar:

| Bar state (AbilityBarState) | Condition |
|---|---|
| "off" | script attribute AbilityBarEnabled == false |
| "touch" | UserInputService.TouchEnabled (no bar) |
| "on" | otherwise |

## Task 1 — AbilityBar 1.0 · Mode: Wired
**Files:** Create `src/character/AbilityBar.client.luau`.

**Interfaces:**
- Consumes only existing attributes (listed above) and ReplicatedStorage.SkillShared (SkillTree.PATHS for names).
- Produces diagnostics on the character, set only when they change:
  - AbilityBarVersion "1.0".
  - AbilityBarState ("on" / "touch" / "off").
  - AbilityBarTiles: e.g. "R:DASH,C:+,F:POUNCE,Space:LEAP".
  - AbilityBar_<Name>: the tile state from the map ("empty" / "off" / "active" / "cooling" / "ready" / "stunned" / "hidden").
- Script attribute AbilityBarEnabled (default true).

**Steps:**
1. Write the script with the layout and state map above. Tiles are rebuilt when SkillSlot1/2, PounceEnabled, JumpEnabled, BiteEnabled, RamEnabled or Species change.
2. Timers and states update every RenderStepped.
3. Install, verify hash + compile, commit.

**Acceptance:**
- PC Raptor: R DASH (or +), C +, F POUNCE, Space LEAP. No BITE tile.
- PC T-Rex: R, C, LMB BITE; E RAM appears only while a raptor is latched on, and disappears after.
- Pounce press → fill + seconds count 3 → 0 (with SkillEffects multipliers, the live PounceCooldown).
- Thrusters: a dash spends a pip and the recharge fill + seconds run, and at 0 charges the tile is dimmed.
- Left click on empty ground still bites (T-Rex): the bar takes no input.
- Touch / emulator: no bar, AbilityBarState "touch".
- AbilityBarEnabled false → no bar, state "off".
- Respawn and species switch: exactly one bar, with the new dino's tiles.
- Bar top stays under GrowthBar at 1280 × 720 and 1920 × 1080.

**Out of scope:** MechaButtons slot keys and touch tiles; ArenaTouch; any move script.

## Task 2 — ArenaScope 1.5 · Mode: Wired
**Files:** Modify `src/server/ArenaScope.server.luau` (SCOPE += {SCS, "AbilityBar", true}; header 1.5).

**Acceptance:** ArenaScopeMismatches 0, ArenaScope_AbilityBar "on".

## Red-team (pre-filing) — synthesis after Kepu 2026-10-29
- #1 resolved: per-dino bars (SPECIES_MOVES). Raptor = Pounce + Leap, its two enabled moves; Bite stays off for it.
- #2 resolved: Ram only while usable.
- #3 to #5: accepted as proposed ("OK as proposed").

Original challenges:
1. **Raptor has no Bite.** The mockup was wrong for this game. Raptor tiles become F POUNCE + Space LEAP. Kepu confirms.
2. **Ram is usable only while a raptor is latched on.** Options: always show it with "locked", show it only while usable, or leave it out. Kepu picks.
3. **Predicted stamps vs server.** The timer starts at the client's press stamp. If the server then denies the move (rare: it uses the same checks), the tile counts a cooldown that did not happen.
   Accepted risk: worst case a false 3 s timer on Pounce or 6 s on Ram.
4. **Keyboard labels only.** A gamepad player on PC sees R / C / F / Space, not the pad buttons. Accepted for 1.0; a later version can switch labels on the last input type.
5. **A touchscreen laptop counts as touch.** It gets the touch buttons and no bar. This is the same rule MechaButtons already uses; accepted.
