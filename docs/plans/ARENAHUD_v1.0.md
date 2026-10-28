# Mecha Dino Arena — Arena HUD v1.0 (mobile-first)

**Goal:** a HUD that works on phones (Kepu 2026-10-28: "the layout is not streamlined for mobile rn … health should be at the top right of the screen along with the T-Rex drop down list").
**Chosen direction:** A · Stack + thumb arc (docs/mockups/mobile_hud_options.html).
**Kepu's answers:**
- No T-Rex jump.
- No shoulder-swap button on mobile (the PC key stays).
- Stamina bar only while latched.
- Hunger / thirst and the class card are already off (Arena scope 1.0).

## Facts read in the code (MechaDinoArena @ a611ea6)
- **Input handlers.** Every move's handler (BiteTest "DinoBiteTest", SprintTest "DinoRunTest", RamTest "DinoRam", PounceTest "DinoPounce", ShoulderCam "DinoShoulderSwap") reads only the input state, so `ContextActionService:CallFunction(action, state, inputObject)` runs the same code as the key.
- **Ram** is bound only while `RamLatchGate ~= "closed"`, i.e. a raptor is latched on the T-Rex (RamTest 1.1, RamRequiresLatchOn).
- **Pounce** is bound while `PounceEnabled`.
- **Leap** (JumpTest 1.0, raptor `JumpEnabled = true`) reads the Input Action System JumpAction when present (`JumpInputSource` = "inputAction"), else Humanoid.Jump / JumpRequest.
- **T-Rex jump:** the T-Rex has Roblox's default jump (JumpEnabled unset).
- **Touch buttons today:** CAS creates its touch buttons in PlayerGui.ContextActionGui. Roblox's jump button is PlayerGui.TouchGui.TouchControlFrame.JumpButton.
- **Current status HUD:**
  - HealthBar 1.1: bottom centre, `HealthHUD`.
  - SpeciesPicker 1.0: top-left buttons; fires `DinoSpeciesRequest`.
  - StaminaBar 1.1: bottom centre, shown only while latched; formula: stamina = clamp(StaminaValue + StaminaRate × (serverNow − StaminaAt), 0, StaminaMax).

## Do-not-touch
- BiteTest, SprintTest, RamTest, PounceTest, JumpTest, ShoulderCam: called, not changed.
- HealthBar / SpeciesPicker / StaminaBar: switched off in Mecha (scope), code unchanged.
- Server combat scripts.

### Task 1 — ArenaStatus 1.0 · Wired (`src/character/ArenaStatus.client.luau`)
Top-right status, all devices. ScreenGui "ArenaStatus", DisplayOrder 6, IgnoreGuiInset false.

**Layout:**
- **Pill:** AnchorPoint (1, 0), Position (1, −16, 0, 12). Panel (20, 20, 26) at 0.18, white stroke 0.5, corner 10, FredokaOne 18. Yellow species tag (255, 200, 50) with text "T-REX" / "RAPTOR" (30, 26, 10), then "v".
- **Menu:** tapping the pill opens it under the pill (same panel). One row per species; the current one is yellow. Tapping the other species fires `DinoSpeciesRequest:FireServer(species)` (SpeciesServer 1.0, 2 s cooldown) and closes the menu. Tapping outside closes it.
- **Health:** under the pill, AnchorPoint (1, 0), Position (1, −16, 0, 58), width 27% of the screen (min 200, max 320 px).
  - Label row "HEALTH" / "h / max".
  - Bar 16 px, green (95, 209, 106) → (63, 174, 75); below 30% red (240, 90, 79) → (201, 47, 38).
  - Updates on Health / MaxHealth change.
- **Stamina:** under health (Position y 96), same width. Visible only while `PounceLatched == true`. Label "STAMINA" / "LATCHED", bar yellow (255, 211, 77) → orange (255, 155, 46). Value from the StaminaBar formula each frame.

**Diagnostics:** `ArenaStatusVersion`, `ArenaStatusMenu` ("closed" / "open"), `ArenaStatusLastPick`, `ArenaStatusStamina` (shown / hidden).

**Acceptance:**
- Pill, health and (latched) stamina top-right on PC and the phone emulator.
- Switching species from the menu respawns as that dino.
- Health matches the Humanoid.
- Stamina is shown only while latched.

### Task 2 — ArenaTouch 1.0 · Wired (`src/character/ArenaTouch.client.luau`)
Only when `UserInputService.TouchEnabled`. ScreenGui "ArenaTouch", DisplayOrder 5.
- **Hides Roblox's own buttons:**
  - `PlayerGui.ContextActionGui.Enabled = false`, kept false; if it is created later, it is disabled when it appears.
  - TouchGui JumpButton `Visible = false`, kept false through its Visible-changed signal.
  - Diagnostics `ArenaTouchCASHidden`, `ArenaTouchJumpHidden` (true / "notFound").
- **Buttons** (circles; the panel colour at 0.4 transparency; white stroke 0.4; FredokaOne; percent of the screen like the mockup):
  - BITE: big yellow; right 5%, bottom 10%, 13.5% of the width.
  - RUN: hold; right 21%, bottom 8%.
  - Ability: right 19.5%, bottom 33%.
  - LEAP: raptor only; right 7%, bottom 43%.
  - The small buttons are 9.5% of the width.
- **Actions:**
  - BITE: `CallFunction("DinoBiteTest", Begin)` on press.
  - RUN: Begin on press, End on release or cancel.
  - Ability: T-Rex RAM (`"DinoRam"`, visible only while `RamEnabled` and `RamLatchGate ~= "closed"`); raptor POUNCE (`"DinoPounce"`, visible while `PounceEnabled`).
  - LEAP: the JumpAction when present (InputAction `Fire(true)` then `Fire(false)`), else `Humanoid.Jump = true`; visible while `JumpEnabled`.
  - Each call is wrapped in pcall. A failure sets `ArenaTouchLastError` and the button stays.
- **Dimmed** (0.5) while that move's state attribute is not ready: RamTestState / PounceTestState / JumpTestState ≠ "ready". BITE and RUN are never dimmed.
- **No shoulder button** (DinoShoulderSwap stays on the keyboard).

**Diagnostics:** `ArenaTouchVersion`, `ArenaTouchState` ("off" no touch / "on"), `ArenaTouchLastPress`.

**Acceptance (phone emulator):**
- Only our buttons are shown (no Roblox Bite / Run / Shoulder / jump buttons).
- Each button does its move:
  - BITE → BiteResult;
  - RUN → Sprinting while held;
  - RAM appears only while latched-on and charges;
  - POUNCE → latch;
  - LEAP → JumpLaunchCount + 1.
- PC is unchanged (no touch UI).

### Task 3 — ArenaRules 1.0 · Wired (`src/server/ArenaRules.server.luau`)
Mecha gameplay rules that are not in a move script.
- **No T-Rex jump:** every player character without `JumpEnabled == true` gets `Humanoid.UseJumpPower = true`, `JumpPower = 0` (it can't jump, and Roblox's jump button hides itself). Script attribute `ArenaNoDefaultJump` (default true; false leaves the Humanoid as spawned). Character attribute `ArenaJumpRule` ("blocked" / "leap" / "off").

**Acceptance:** the T-Rex can't jump (Space / jump do nothing). The raptor's leap still works.

### Task 4 — ArenaScope 1.1 + scope switches · Wired
- HealthBar, SpeciesPicker and StaminaBar: `Enabled = false` (place) + `.meta.json`.
- ArenaScope expects them off, and ArenaStatus / ArenaTouch / ArenaRules on.

**Acceptance:** `ArenaScopeMismatches 0`; only the new HUD is visible.

## Red-team (brief)
1. **Hiding Roblox's own UI** (ContextActionGui, the TouchGui JumpButton) depends on Roblox's PlayerModule layout, which Roblox can change. Mitigation: the "notFound" diagnostics; checked in the phone emulator every session.
2. **CallFunction on an action that isn't bound** (RAM while closed): the button is hidden then, and the call is in pcall with `ArenaTouchLastError`.
3. **The stamina formula is copied from StaminaBar** (could drift). It only reads the same attributes; checked against StaminaServer's value while latched.
4. **Touch laptops** get both the keys and the buttons (accepted).
