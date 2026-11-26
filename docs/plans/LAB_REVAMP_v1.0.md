# Mecha Dino Arena — Lab 2.0 (Lab Revamp v1.0) — plan (red-teamed 2026-11-25)

**Goal:** The Lab works on a phone and on PC. Every button is at least 44 px tall and wide on a phone, and a first-time player can see how to put a part in a slot.
**Chosen direction:** B · SLOTS FIRST. Prototype at docs/mockups/lab_revamp_v0.1/index.html (artifact https://claude.ai/artifact/QVp5s7e9VGgV72PGZAS89F). Kepu 2026-11-25 22:46 asked for the revamp; at about 23:05 he picked "B: Slots first" and "Replace it" (no switch back to the 3-column Lab).
**Architecture:** Lab.client.luau keeps its data, rules, remotes, 3D previews, clips, skin / emote / trail logic and element names. Its **placement** code (`measure()`, `layout()`) and the card / slot / detail drawing change to the B arrangement:
- **Left half:** the stage, with 4 big slots and SAVE under it.
- **Right half:** 5 big tabs over a list, and a detail sheet that slides over the list.

New size math lives in a new ModuleScript `LabLayout` (pure, spec-tested), because the Lab's main chunk is at the 200-local limit (see the `EMO` / `TRL` notes in the Lab header).

## Grounding (read 2026-11-25)

**Lab.client.luau v1.20**
- 3188 lines. Full mode (main menu) and compact mode (island SKILLS / K).
- Today's layout is 3 columns, 31% | rest | 27% (compact 34% | rest | 30%).
- Sizes come from `ch` = H / 100, with px floors of 10–34. On a 381 px tall phone that gives:

| Element | Measured in Studio (iPhone 17 Pro emulation, 750 × 381) |
|---|---|
| Tabs | 72 × 16 |
| SKINS / EMOTES / TRAILS pills | 28–35 × 14, 7 px text |
| ALL / OWNED / EARN / ROBUX pills | 19–31 × 14 |
| Skin tiles | 67 × 44 |
| Dino buttons | 65 × 18 |
| Slots | 46 × 34 |
| SAVE | 70 × 34 |
| Main button | 182 × 34 |
| X | 30 × 30 |

**Touch slot keys:** `SLOT_KEYS` = R / C / R▼ / C▼ on touch, R / C / T / V on PC.

**Tutorial 1.x** (`Tutorial.client.luau` ~1357–1560, v1.3 / v1.4 "Lab coach")
- Drives the real compact Lab and finds its buttons by name anywhere under PlayerGui.Lab: `Card_<id>`, `Tabs.Parts` / `Tabs.Stats`, `Actions` > `Btn` whose child `T` starts with "EQUIP" / "BUY" / "UPGRADE", `Slot_<n>`, `Close`.
- Reads player `LabOpen`, `LabTab`, `LabSelected`, `LabSlotSel` and `LabLastPress` ("card:<id>").
- Relies on "EQUIP fills the selected slot, else the first empty one".

**Other readers**
- Music.client.luau reads `LabOpen == "full"`.
- Attack test scripts read `LabOpen ~= "closed"`.
- MainMenu calls `Lab.Open:Invoke("full")`; the SKILLS pill calls compact; IslandDino / SquadHUD / HardpointHUD read the `PlayerGui.LabButton.Skills` spot.
- ArenaScope lists the Lab as a client script.

**Modules the Lab uses:** LabClipPlayer, LabClipRecipes, TrailLook, EmotePose, SkinFX (through BotChars), UniversalSkins.

**Remotes (unchanged):** SkillRequest, DinoSkinRequest, DinoEmoteRequest, DinoTrailRequest.

## Global constraints

- Version: Lab **2.0**; LabLayout **1.0**; Tutorial **1.x + 0.1** (the build session reads the current Tutorial VERSION first and adds 0.1).
- Every header and docs/VERSIONS.md + docs/ATTRIBUTES.md entry says "Lab Revamp v1.0".
- Every number is a script attribute. New switches default on. No switch back to the 3-column layout (Kepu: "Replace it").
- Phone floor: every tappable thing is at least 44 × 44 px at 750 × 381 **and** at 667 × 375 (iPhone SE). Text is at least 11 px on phone.
- Game copy: no em dashes, short HUD tags, uppercase pixel font as today (Silkscreen FontSwap rules unchanged).
- Element names the Tutorial uses are kept: `Card_<id>`, `Tabs.Parts`, `Tabs.Stats`, `Actions` > `Btn` > `T`, `Slot_<n>`, `Close`, `SaveLoadout`.
- Player attributes kept with the same meaning: `LabOpen`, `LabTab` ("parts" / "stats" / "skins", plus new "emotes" / "trails"), `LabSelected`, `LabSlotSel`, `LabLastPress`, `LabToast`.
- Server code is not touched.

## Do-not-touch

- SkillServer and its remotes: buy / slot / saveLoadout rules.
- SkinServer, EmoteServer, TrailServer: buy and equip.
- LabPreviewServer. The LabClipPlayer and LabClipRecipes clips.
- UniversalSkins, EmoteCatalog, TrailCatalog.
- MainMenu's GO TO THE LAB, the SKILLS pill (LabButton) and its spot, PhoneMenu drawer.
- Music's lab track rule. The attack scripts' `LabOpen` checks.
- PregameScreen loadout.

## Files

| File | Change | Job |
|---|---|---|
| `src/client/LabLayout.luau` (StarterPlayerScripts, new) | Create | Pure size math: `LabLayout.compute(W, H, opts)` returns every rect and text size for both modes. No Instances. |
| `tools/tests/LabLayout.spec.luau` | Create | Spec, run in Studio Edit like FillerRules.spec: returns "PASS n". |
| `src/client/Lab.client.luau` | Modify | 2.0: uses LabLayout; B arrangement; row cards with inline buttons; slot-first flow; detail sheet; 5 tabs; 44 px chips; tip strip. |
| `src/client/Tutorial.client.luau` | Modify | Coach targets for the B flow (inline EQUIP on the card, the sheet). |
| `docs/VERSIONS.md`, `docs/ATTRIBUTES.md` | Modify | Entries. |

## Layout (exact; full mode, landscape)

Units: `u = clamp(H / 38.1, 9, 14)` px. That is 10 at H 381 (phone) and 14 at H ≥ 533 (PC). Every size below is `n·u` with the px floor stated. LabLayout returns pixels.

**Top bar**
- Height max(5u, Roblox top inset + 0.6u).
- Left padding max(10u, topLeftClear() + 1.6u).
- Items as today: LAB, name, LV + XP, MASTERY chip, points chip.
- X: 44 × 44 floor (3.7u at font 1.2).
- Volt line 0.3u under it.

**Body:** padding 1u, gap 1u.
- **Left column:** 42% of width (PC 40%), as a vertical stack:
  - Stage pane: fills, corner 1.2u, tag "YOUR <DINO>" (LOOKS tabs: "PREVIEW").
  - Slot row: height max(5.6u, 56 px).
    - 4 slot buttons, then SAVE (1.25 × slot width), gap 0.6u.
    - Each slot shows the key (orange, 1.5u) over the part name (0.9u, ellipsis) or "TAP TO FILL" (muted). Empty slots get a dashed-look stroke (white 0.73). The selected slot: yellow stroke 3 px, fill rgb(58, 47, 10).
    - SAVE as Lab 1.16, re-sized: "SAVE" / "FOR PRE-GAME" yellow, or "SAVED ✓" / "PRE-GAME" green.
  - On SKINS only, the dino strip replaces the slot row: 8 buttons, 2 rows of 4, each at least 44 px tall.
- **Right column:** the rest.
  - Tab row: height max(4.4u, 44).
    - Full mode: 5 equal tabs: ABILITIES (`Tabs.Parts`), STATS (`Tabs.Stats`), SKINS (`Tabs.Skins`), EMOTES (`Tabs.Emotes`), TRAILS (`Tabs.Trails`).
    - Compact: ABILITIES / STATS only.
    - On: volt stroke, fill rgb(22, 48, 58). LOOKS tabs: purple (201, 162, 255) stroke, fill rgb(42, 33, 64).
  - Under it, the list area (fills):
    - **ABILITIES**
      - Header line (1.05u text, 2.4u tall):
        - "PICK A PART FOR SLOT <key>" (yellow) + CANCEL (44 px) while a slot is selected.
        - Else "TAP A SLOT ON THE LEFT, OR EQUIP A PART BELOW" when a slot is empty.
        - Else "TAP A SLOT TO SWAP ITS PART" (muted).
      - Then a scrolling list of row cards. 1 per row on phone; 2 per row when the column is at least 560 px wide.
      - Row card `Card_<id>`, corner 1u, stroke 2:
        - Art 7.6u wide, 4:3: the 3D preview ViewportFrame as today.
        - Name 1.15u.
        - Pips and the state "ON <key>" (orange) / "NOT ON A SLOT" (muted).
        - A row of inline buttons in a frame named `Actions`, each `Btn` with label `T`, height max(4.4u, 44):
          - EQUIP (orange) / TAKE OFF <key> (dark) / PUT ON <key> (orange, while a slot is selected).
          - INFO (dark, square 44).
        - Equipped cards: orange stroke.
    - **Detail sheet** (INFO, or a card tap while no slot is selected)
      - Covers the list area. BACK (44 px) at the top-left.
      - Then today's detail, in this order: kind line; name; the action buttons (the `Actions` frame of 1.15: BUY / UPGRADE / MAXED and EQUIP / TAKE OFF); the live clip (LabClipPlayer, width 100%, 16:8); the what line; chips; steps I / II / III / ★ (each row a tap target at least 44 px tall, step preview as 1.15).
      - Scrolls.
    - **STATS:** one row per stat, at least 56 px tall: name, pips, area, and an UPGRADE · n PT / MAXED button (44 px) on the row. Always-on parts below, as row cards without slot buttons.
    - **SKINS / EMOTES / TRAILS**
      - Filter chips ALL / OWNED / EARN / ROBUX: one row, equal width, at least 44 px tall, purple when on.
      - Then the grid (2 per row on phone, 3 on PC, cells at least 44 px tall) with the LOOKS detail beside it (40% of the right column).
      - Today's states, buttons and flows: equip / buy / credit / wheel.

**Tip strip (first-time help):** volt panel over the bottom of the stage.
- "1 TAP A SLOT · 2 PICK A PART · 3 SAVE". Each step is crossed out when done.
- GOT IT button (44 px).
- Shows on ABILITIES while any slot is empty and GOT IT has not been tapped this session (see red-team R3).

**Compact mode (island):** 2 tabs, no LOOKS. On touch devices it opens full screen (the full-mode box), because the inset panel left about 585 × 300 px on a 750 × 381 phone (red-team R3). On PC it stays the inset panel. The game keeps running behind it, and `LabOpen` stays "compact" either way.

**Portrait / very wide screens:** LabLayout clamps `u` and keeps landscape math (the game is landscape-only today; not changed).

## Deterministic map (ABILITIES)

| State | Trigger | End state |
|---|---|---|
| No slot selected, slot tapped (empty) | tap `Slot_n` | `slotSel = n`, header "PICK A PART FOR SLOT <key>", every card shows PUT ON <key> |
| No slot selected, slot tapped (filled) | tap `Slot_n` | `slotSel = n`, `LabSelected` = that part (1.3 rule), header as above, that part's card shows "ALREADY ON <key>" (greyed) |
| Slot selected, same slot tapped | tap `Slot_n` | `slotSel = 0`, header back |
| Slot selected, PUT ON tapped | inline Btn | `SkillRequest("slot", n, id)`; if the part sat in another slot, the server moves it (as today); `slotSel = 0`; toast "<NAME> ON <key>" |
| Slot selected, card body tapped | tap `Card_<id>` | same as PUT ON (Tutorial 1.4 rule kept) |
| Slot selected, CANCEL | tap | `slotSel = 0` |
| No slot selected, EQUIP | inline Btn | first empty slot; none -> toast "SLOTS FULL · TAP A SLOT TO SWAP", slots pulse (today's rule) |
| TAKE OFF <key> | inline Btn | `("slot", n, "")`, toast "<NAME> OFF" |
| Card body tapped, no slot selected | tap | `LabSelected = id`, sheet opens |
| Sheet BACK | tap | sheet closes, list scroll kept |
| Part not owned | (any) | inline shows BUY · n PTS / NEED n PTS (as detail labels today) instead of EQUIP; PUT ON hidden |
| Part SOON | (any) | inline "COMING SOON" greyed, no PUT ON |
| Tab change | tap tab | `slotSel = 0`, sheet closed |
| Lab closed / reopened | X / K / Open | `slotSel = 0`, sheet closed, tip strip as rule |
| Screen resize | AbsoluteSize change | LabLayout.compute again, redraw (today's rule) |

## Tasks

### Task 1 — LabLayout module + spec  ·  Mode: Logic
**Files:** create `src/client/LabLayout.luau`, `tools/tests/LabLayout.spec.luau`.
**Interfaces:**
- Produces `LabLayout.VERSION = "1.0"`.
- Produces `LabLayout.compute(W: number, H: number, opts: {mode: "full" | "compact", touch: boolean, topInset: number, topLeftClear: number, looks: boolean}) -> L`. `L` has these fields:
  - `u`; `bar = {x, y, w, h}`; `close = {w, h}`; `left`, `right`, `stage`, `slotRow`, `tabs`, `list` (rects); `slotW`, `saveW`, `tabW`; `cardsPerRow`; `cardH`; `btnH`; `chipH`; `gridCols`.
  - `text = {name, tab, card, small, btn, hdr}`.
- Every rect is in px relative to the Lab box.

**Steps:**
1. Write the spec first. Assert for (750, 381, touch, full), (667, 375, touch, full), (1280, 720, mouse, full), (847, 616, mouse, full) and the compact versions:
   - `slotW`, `slotRow.h`, `tabs.h`, `btnH`, `chipH`, `close.w`, `close.h` ≥ 44.
   - `tabW` ≥ 44.
   - `text.*` ≥ 11.
   - The left + right + gaps width equals the body width.
   - Nothing negative.
   - `cardsPerRow` is 1 at 750 and 2 at 1280.
   - `gridCols` is 2 / 3.
2. Run it in Studio Edit and watch it fail (module missing).
3. Write `compute` with the numbers in the Layout section, every number from an `opts.attrs` table with defaults.
4. Run → PASS. Commit.

**Acceptance:** PASS on all 8 screen cases; `L` matches the mockup's proportions (left 42% phone / 40% PC).
**Out of scope:** no Instances; Lab.client.luau not touched in this task.

### Task 2 — Lab 2.0 frame: left stage + slot row, right tabs + list area  ·  Mode: Wired
**Files:** modify `src/client/Lab.client.luau` (`measure()` 717–746, `layout()` 2433–2666, the bar / body / column frames built near 470–620, `drawSlots()` 1625).
**Interfaces:** consumes `LabLayout.compute`. Produces frames `Box.Body.Left` (Stage, SlotRow), `Box.Body.Right` (Tabs, List, Sheet); `slotBtns[n]` keep names `Slot_n`.
**Layout:** as the Layout section (top bar, left column, right column, slot row with SAVE, 5 tabs full / 2 compact).

**Steps:**
1. Require LabLayout. `measure()` fills `S` from `L` (keep the `S.*` names other code reads; add `S.u`).
2. Move the stage and the slot row under Left; move tabs and grid under Right; the old Mid column frame is removed (Kepu: replace).
3. Slots: key 1.5u orange, name or "TAP TO FILL", empty stroke rule, selected stroke yellow, 3D icon only when the slot is at least 70 px wide (today's narrow rule).
4. Tabs: 5 buttons `Parts`, `Stats`, `Skins`, `Emotes`, `Trails`; Emotes / Trails set `EMO.looks` and `LabTab` "emotes" / "trails"; the old SKINS / EMOTES / TRAILS pills are removed.
5. Studio Play at 750 × 381 emulation and PC: every target ≥ 44 (measure script as in the mockup check). Commit.

**Acceptance:**
- Phone emulation: every tappable element is at least 44 × 44 (printed list empty).
- PC 1280 × 720 is unchanged in function.
- Compact on the island opens with 2 tabs: full screen on touch (R3), the inset panel on PC.
- `LabOpen` / `LabTab` values as before.
- Music still plays the lab track in full.

**Out of scope:** card and detail drawing (Task 3), LOOKS (Task 5).

### Task 3 — ABILITIES: row cards with inline buttons, slot-first flow, detail sheet  ·  Mode: Wired
**Files:** modify `src/client/Lab.client.luau` (`drawCards()` 1441, `drawDetail()` 2166, `equip()` 781, the slot tap handler, `detailButton()` 1654).
**Interfaces:**
- Consumes Task 2 frames and `S.btnH`.
- Produces `Card_<id>` with child `Actions` (Btn / T), the sheet frame `Sheet` with `Back`, `Detail` and the detail's `Actions`.
- The player attribute `LabSheet` (bool) is new.

**Layout:**
- Row card as the Layout section.
- Header line above the list.
- Sheet over the list area.
- Detail order: kind, name, Actions, clip, what, chips, steps.

**Steps:**
1. Row card build, with inline Actions per the state map.
2. Slot-first flow per the deterministic map.
3. Sheet: INFO / card tap opens; BACK closes; the scroll is kept.
4. The detail moves into the sheet, reordered. The clip is kept across redraws as 1.15. Step rows at least 44 px tall.
5. Toasts "<NAME> ON <key>", "<NAME> OFF", "SLOTS FULL · TAP A SLOT TO SWAP".
6. Studio Play: every row of the deterministic map, on PC and in phone emulation (the user_mouse_input tool does not reach touch emulation; phone rows are checked by size and by Kepu live). Commit.

**Acceptance:**
- Each row of the deterministic map.
- Clips still play (`LabClipState` "playing").
- Save tile goes yellow after a change, then green after SAVE.
- `LabSlotSel` / `LabSelected` / `LabLastPress` are set as before.

**Out of scope:** SkillServer rules.

### Task 4 — STATS rows  ·  Mode: Wired
**Files:** modify the `drawCards()` stats branch.
**Interfaces:** each row keeps the name it has today. Each row gets an inline `Actions.Btn` whose `T` reads "UPGRADE · n PT" / "BUY · n PTS" / "MAXED" / "NEED n PTS".
**Layout:** row at least 56 px tall: name 1.15u, pips, area. Button on the right, at least 44 px tall and 11u wide. Always-on parts follow as row cards without slot buttons.
**Steps:** build the rows; tapping the button sends the same SkillRequest("buy", id) as the detail today; the row body opens the sheet. Commit.
**Acceptance:** an upgrade spends a point and the pips update; MAXED rows are greyed; the Tutorial "spend" step finds `UPGRADE` / `BUY`.

### Task 5 — SKINS / EMOTES / TRAILS as tabs, 44 px chips and tiles  ·  Mode: Wired
**Files:** modify `uniBuild()` 938, `drawUniCards()` 1258, `EMO.cards()` 1053, `TRL.cards()` 1182, `drawUniDetail()` 2049, `EMO.detail` 1819, `TRL.fitCheck` (no longer needed: the pills are gone; the switch `LabPillFitEnabled` is removed).
**Layout:**
- Chips row, then grid + detail split 60 / 40 in the right column.
- Dino strip under the stage (SKINS only), 2 × 4 buttons at least 44 px.
- Tile cells at least 44 px tall, names at least 11 px.
- The EMOTES wheel (8 slots) in the detail, each slot at least 44 px.

**Steps:** move each view into the right column; resize; keep every state and flow. Commit.
**Acceptance:** for skins, emotes and trails, each works: equip, buy (shows the Robux prompt; never completed in tests), earn bar, wheel put / move, NO TRAIL, filters, dino strip preview.

### Task 6 — Tip strip  ·  Mode: Wired
**Files:** modify the Lab (ABILITIES stage overlay).
**Interfaces:**
- Player attribute `LabTipDone` (session) is new.
- Script attributes `LabTipsEnabled` (true) and `LabTipStepsDone` (diagnostic, "slot,part,save").

**Layout:** as the Layout section.
**Steps:** steps cross out on a slot tap, an equip and a save; GOT IT hides it for the session; it shows again next join while a slot is empty (R3). Commit.
**Acceptance:**
- A fresh player sees it.
- All 4 slots filled and saved: it does not show.
- Hidden while the Tutorial coach is on (`TutorialCoach` gui enabled).

### Task 7 — Tutorial coach on Lab 2.0  ·  Mode: Wired
**Files:** modify `src/client/Tutorial.client.luau` (`labActionBtn`, the equip / spend steps ~1500–1560).
**Interfaces:** consumes `Card_<id>.Actions.Btn` (inline EQUIP / PUT ON), `Slot_n`, `Sheet`.
**Steps:**
1. Equip step targets: TAP A PART's inline EQUIP (`Card_<id>` > `Actions` > Btn with T "EQUIP").
2. Then the 1.6 s slot tag, as today.
3. When a filled slot is selected, point at the first empty slot (1.4 rule) or PUT ON.
4. Spend step: STATS tab, then the stat row's inline UPGRADE / BUY.
5. Run the tutorial from a fresh test player in Studio (TutorialTest attributes as in earlier tutorial QA, restored after). Commit.

**Acceptance:**
- The equip step reaches 4/4 without looping on one slot (1.4 bug stays fixed).
- The spend step ends with STAT +1.
- No coach target is ever missing (`TutorialCoachTarget` never "none" while the Lab is open).

### Task 8 — QA + docs  ·  Mode: Wired
- Hashes in Studio equal the repo for Lab, LabLayout and Tutorial.
- VERSIONS / ATTRIBUTES entries.
- Phone-size audit printout (every target ≥ 44) at 750 × 381 and 667 × 375.
- PC run of every tab.
- The island compact Lab during a live hub (filler bots on): no input leak (attacks blocked while `LabOpen ~= "closed"`).
- Live check by Kepu on his phone after "Publish".

## Self-review

- **Coverage:** small buttons (T2–T5); first-timer equip (T3 slot-first + T6 tips + T7 tutorial); LOOKS buttons (T5); both menu and island (T2 compact); PC and phone (T1 spec + T8).
- **Placeholders:** none.
- **Names:** `Card_<id>`, `Actions`, `Btn`, `T`, `Slot_n`, `Sheet`, `LabSheet`, `LabTipDone` are the same across tasks.
- **Fence:** server scripts untouched; Music / attack scripts read the same `LabOpen` values.

## Red-team (2026-11-25) and Kepu's rulings

| # | Challenge | Ruling | Effect on the plan |
|---|---|---|---|
| R1 | The Tutorial's Lab coach finds Lab buttons by name (`Actions` > EQUIP). An EQUIP on every card would mis-target. | Accepted (fix in the same release) | Task 7; Task 3 keeps the names. |
| R2 | "Replace it" leaves no fallback while the Lab also sells skins, emotes and trails. | Kepu: "Replace now" | Accepted risk, recorded in the ADR. Task 8 QA covers every buy flow (prompt shown, never completed) before publish. |
| R3 | The island compact panel on a phone is too small for 44 px slots. | Kepu: "Full screen on phones" | Compact mode is full screen on touch (Layout section); the LabLayout spec covers compact touch at 750 × 381 and 667 × 375. |
| R4 | "First time" needs memory across joins, which means a server save. | Kepu: "While a slot is empty" | Task 6: no server change; GOT IT lasts for the session. |
| R5 | Scope: a 3188-line script at the local limit; splitting into two releases would be safer. | Kepu: "One release" | All 8 tasks ship together; publish only on "Publish". |

## Filed (Dev Hub, 2026-11-25)

ADR-015. Mockup "Lab Revamp v0.1 (picked B · Slots first)". Tickets MDA-584 (T1) through MDA-591 (T8), blocked in build order.
