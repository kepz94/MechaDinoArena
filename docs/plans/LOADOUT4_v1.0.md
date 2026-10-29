# Mecha Dino Arena v1.0 — 4 loadout slots with tap-and-pull mecha buttons

**Goal:** bring 4 mecha parts instead of 2. On a phone that is still 2 buttons: tap a button for its first part, tap and pull down for its second.
**Chosen direction (Kepu 2026-10-29 02:48–02:55):** eFootball-style flick buttons.
- Tap + pull down, on the mecha buttons only.
- More slots.
- Look A "Sub-label": the tap part big, "▼ PART" small at the bottom.
- PC keys T / V for the pull parts.

Mockup: docs/mockups/flick_buttons_options.html.

**Architecture:** SkillTree.SLOTS 2 → 4. Slots 1 and 2 keep their meaning (button 1 tap = R, button 2 tap = C), so old saves stay valid. New slot 3 = button 1 pull (T) and slot 4 = button 2 pull (V). Server code that already loops over SLOTS follows on its own. The client screens that hard-code 2 slots each get a small additive change.

## Global Constraints
- Cloud place 84022023159448 only. Check `game.PlaceId` before every install; verify by hash + loadstring compile.
- Versions:
  - SkillTree 1.5 (+ spec)
  - SkillServer 1.3
  - MechaButtons 1.4
  - SkillScreen 1.3
  - AbilityBar 1.2
- Each gets its header, changelog line, version attribute, docs/VERSIONS.md row and docs/ATTRIBUTES.md section.
- Slot n ↔ input:

  | Slot | Phone | PC |
  |---|---|---|
  | 1 | button 1 tap | R |
  | 2 | button 2 tap | C |
  | 3 | button 1 pull down | T |
  | 4 | button 2 pull down | V |

## Do-not-touch
- MechaServer: it checks DashEnabled, not slot numbers.
- SkillEffects: it already loops `for n = 1, ST.SLOTS`.
- ArenaTouch, PounceTest / BiteTest / JumpTest / RamTest, ShoulderCam.
- The tap-and-pull rule is mecha buttons only (Kepu).

## Grounded facts (repo 8616e05)
- SkillTree: SLOTS = 2. sanitizeLoadout / autoSlot / setSlot all loop over SkillTree.SLOTS, and setSlot rejects n > SLOTS ("badSlot").
- SkillServer 1.2:
  - publish writes SkillSlot1..SLOTS.
  - Fresh records, the load default and respec hard-code `{false, false}` (lines 131, 164, 274).
  - Saved loadouts go through sanitizeLoadout.
- SkillEffects 1.4: DashEnabled looks at SkillSlot1..ST.SLOTS (line 109), so it follows on its own.
- MechaButtons 1.3:
  - KEYS = {R, C}.
  - Touch Slot_1 / Slot_2 buttons press on InputBegan.
  - "NEW" popup slot lookup is `for n = 1, 2`.
- SkillScreen 1.2: the loadout strip has 2 tiles of 120 × 36 (`for n = 1, 2`).
- AbilityBar 1.1: 2 slot tiles (`for n = 1, 2`).

## Task 1 — SkillTree 1.5 + SkillServer 1.3 · Mode: Logic (SkillTree) + Wired (SkillServer)
**Files:**
- Modify `src/shared/SkillTree.luau` (SLOTS = 4).
- Modify `src/server/SkillServer.server.luau`: every `{false, false}` becomes a 4-slot empty loadout, built from SLOTS.
- Spec: the SkillTree spec gets cases for slots 3 / 4.

**Interfaces:** SkillSlot3 / SkillSlot4 player attributes (path id or ""). Request ("slot", 3 or 4, id) is accepted.

**Acceptance:**
- Spec:
  - sanitizeLoadout pads a 2-slot save to 4 (false, false).
  - setSlot(…, 3, "thrusters") moves Thrusters out of slot 1.
  - n = 5 gives "badSlot".
- Play: buying Thrusters fills slot 1 as before. Moving it to slot 3 works, and DashEnabled stays true.
- An old v2 save (2-slot loadout) loads with slots 3 / 4 empty.
- Hashes match; docs.

## Task 2 — MechaButtons 1.4 · Mode: Wired
**Files:** Modify `src/character/MechaButtons.client.luau`.

**Behaviour:**
- **PC:** R / C / T / V press slots 1 / 2 / 3 / 4.
- **Touch:** each button n (1, 2) has a tap part (slot n) and a pull part (slot n + 2).
  - **Pull part empty:** the button presses slot n on InputBegan, exactly as 1.3.
  - **Pull part set:**
    1. InputBegan stores the start position.
    2. InputChanged marks "pulling" once the touch is ≥ PULL_PX below the start. While pulling, the stroke turns white 4 px and the sub-label turns white.
    3. InputEnded presses slot n + 2 if pulling, else slot n.
  - PULL_PX = clamp(0.22 × button size, 14, 24) px.
  - A touch that started on the button never moves the camera.
- **Sub-label:** "▼ NAME" along the bottom of the button. Size 0.16 of the button, rgb(255, 217, 168); dimmed 0.5 while that part is not ready. No sub-label when the pull slot is empty.
- **NEW popup:** looks up slots 1..4 and says "Press R / C / T / V to use it", or "Tap its button" / "Tap and pull down its button".
- **Toggle:** script attribute MechaButtonsPullEnabled (default true; false = 1.3 behaviour, slots 3 / 4 PC keys only).
- **Diagnostics:** MechaButtonsLastPress gains "slot3:…" / "slot4:…"; MechaButtonsLastGesture "tap" / "pull".

**Acceptance:**
- PC: R / C / T / V each fire their slot.
- Emulator / phone:
  - A tap fires the tap part.
  - Tap and pull down fires the pull part.
  - A pull doesn't move the camera.
  - With the pull slot empty, a tap fires on press as in 1.3.
- The sub-label shows the pull part's name; nothing when that slot is empty.
- Kepu's phone check, including the pull room under slot 1 on a small phone.
- Hash matches; docs.

## Task 3 — SkillScreen 1.3 + AbilityBar 1.2 · Mode: Wired
**Files:** Modify `src/character/SkillScreen.client.luau` and `src/character/AbilityBar.client.luau`.

**Layout:**
- **SkillScreen loadout strip:** 4 tiles in the order slot 1, slot 3, slot 2, slot 4.
  - Labels: "R · tap", "R · pull ▼", "C · tap", "C · pull ▼"; on PC the pull labels say "T" / "V".
  - Each tile is (strip width − 70 − 3 × 6) / 4 px wide, capped at 120, with scaled text. The hint text is hidden when the tiles are under 120.
  - A tap on a tile cycles parts as in 1.1.
- **AbilityBar slot tiles:** R (slot 1), T (slot 3), C (slot 2), V (slot 4), then the divider and the moves. Other tile rules as 1.1.

**Acceptance:**
- The strip fits on a small phone (568 px tall view) and on PC.
- Each tile cycles its own slot.
- The PC bar shows R / T / C / V with each part's charges and cooldown.
- Hashes match; docs.
- Kepu checks it.

## Red-team synthesis (Kepu 2026-10-29)
- #1: **fire on release** (eFootball-style) for buttons with a pull part; buttons with an empty pull slot still fire on press.
- #3: **build with the next part.** This plan ships together with the first new raptor mecha part; tickets wait on it.
- #2, #4 and #5 stand as written (acceptance items).

## Red-team (pre-filing)
1. **Tap delay.** A button with a pull part can only fire its tap part on release, because it has to know you didn't pull. That adds about the length of the tap (~0.1–0.2 s) before DASH starts.
   - Mitigation: buttons without a pull part keep firing on press.
   - Alternative: fire the tap part at once and use the pull for the second part only after a hold. That is not what eFootball does. Kepu decides.
2. **Pull room under slot 1.** It sits 8% from the bottom. The thumb starts mid-button, so there are about 70 px below the touch on a 390-pt-tall phone. PULL_PX 14–24 fits; the phone check confirms it.
3. **Nothing to put in slots 3 / 4 yet.** Only Thrusters is built, so until the next raptor part ships, the extra slots are empty.
   - Option: build this now (the framework is ready for the next part), or build it together with the first new part.
4. **Small-phone SKILLS strip.** Four tiles at 120 px don't fit next to the tree on a phone. They shrink to fit and the hint text hides (acceptance item).
5. **Old saves.** The 2-slot loadouts in MDA_Skills_v2 are padded by sanitizeLoadout (spec case). Nothing is lost.
