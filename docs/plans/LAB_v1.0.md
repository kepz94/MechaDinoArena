# Mecha Dino Arena — Lab v1.0 (workbench: buy, upgrade and equip in one screen)

**Goal:** one screen, the Lab, where you see your dino with every applied upgrade, every mech part as a card with its own 3D model, and buy / upgrade / equip from there. It replaces the skill tree screen and the main menu's tap-to-pick loadout.
**Intent (Kepu 2026-10-29):** "a dedicated screen for selecting the Dino upgrades with the actual visual for each mecha selection. Replace the skill tree and the way the selection works on the main menu. Maybe keep the main menu Dino select the same with a quick reference on what Dino you have and the mecha upgrades but a go to the lab option where you load up the full Dino model with every upgrade that's applied to it and load out them on the skills menu on the island it would be a compact version of that." Answers: the Lab does everything (buy, upgrade, equip; parts and stats); SKILLS on the island opens a compact Lab over the game; cards show the part's 3D model; menu = read-only slot row + GO TO THE LAB. "Let's do the work bench. Make sure everything is portioned and spaced correctly."
**Chosen direction:** mockup `docs/mockups/lab_options.html` — **A · Workbench**.
**Decisions (red-team, Kepu 2026-10-29):** card models from a preview builder in each part script (same build code; Scent Sense gets a small sensor model) — "Add a preview builder"; no RESPEC in the Lab — "Drop it"; the old SkillScreen is deleted — "Delete it".

## Current state (grounded)
- SkillScreen 1.4 (StarterCharacterScripts) = the SKILLS HUD button (left of the ArenaStatus pill, yellow points badge), K key, tier-row tree, detail panel with BUY, loadout strip + picker, RESPEC. Character attribute SkillScreenOpen is read by AbilityBar 1.1 (hides the bar).
- Data: SkillServer player attributes SkillLevel, SkillXPInto / SkillXPNext, SkillLeft, SkillPath_<id>, SkillSlot1..4; requests SkillRequest("buy", id) / ("slot", n, id) / ("respec"); shared ReplicatedStorage.SkillShared.SkillTree (pathsFor, seesPath, BUTTONS, MASTERY_MAX, COST, mastered).
- Part models are built on the character only while equipped: AdrenalineServer (Mecha_Adrenaline), ScreechServer buildCannon (Mecha_ShockCannon), EnergyShieldServer (Mecha_EnergyShield), CloakServer (Mecha_Cloak), BladeServer (Mecha_Blade), MechaServer (Mecha_Thrusters); MineServer builds the thrown mine; Scent Sense has no model.
- MainMenu 1.1 has the slot row + picker row and the preview stage.

## Global constraints
- Version tags: LabPreviewServer 1.0, Lab 1.0, MainMenu 1.2, ArenaScope 1.12, part servers +0.1 each (preview hook). Header changelog, VERSION attribute, docs/VERSIONS.md, docs/ATTRIBUTES.md.
- Every new behaviour behind a switch. SkillScreen is deleted by Kepu's command.
- Look and spacing = mockup A exactly (below); game colours; FredokaOne / Gotham; px minimums; clear of the Roblox top bar.

## Layout (from mockup A; ch = screen height / 100, cw = width / 100)
**Full Lab** (ScreenGui "Lab", DisplayOrder 45, over the menu):
- Top bar: padding 1.4ch top / 1.2ch bottom, left = clear of the Roblox buttons (max(10ch, TopbarInset + 2ch)), right 2cw; volt bottom line 0.35ch; items left to right, gap 1.6ch: "LAB" (volt, 0.55 x) + dino name (FredokaOne 3.4ch); "LV n" (max(1.8ch, 10 px)) + XP bar 12cw x 1.4ch; MASTERY n/3 chip (gold stroke); right-aligned points chip (yellow, FredokaOne 2.4ch) and ✕ (max(5ch, 30 px) square).
- Body: padding 1.6ch top, 2cw sides, 2ch bottom; three columns 31% | rest | 27%, gaps 1.6cw.
  - Left: tabs MECH PARTS / STATS (equal width, gap 0.8ch, text max(1.7ch, 10 px)), 1.2ch gap, then a scrolling 2-column card grid (gap 1ch). Card: padding 1ch, corner 1.4ch; 4:3 ViewportFrame with the part model turning; name (FredokaOne max(1.9ch, 11 px)); pips (1.6ch squares, star round) + step tag (I / II / III / ★ / NEW); badge top-right: slot key (orange) / ALWAYS ON (volt) / SOON (grey). Equipped = orange stroke; selected = white stroke. Stats tab: one row per stat (name, pips, area, "Next: n pts" / "Maxed").
  - Middle: stage (fills; panel, "ALL UPGRADES" tag, ViewportFrame with a copy of your live character, turning), 1.2ch gap, slot row (4 equal columns, gap 0.8cw, height max(6ch, 34 px): key + part icon (mini viewport) + name), 1.2ch gap, hint (max(1.5ch, 10 px)).
  - Right: detail panel (padding 1.6ch): area · kind line (area colour), name (FredokaOne 3ch), steps list (I / II / III / ★: got = area colour, next = white outline, rest grey; text max(1.6ch, 10 px)), buttons row (height max(5.6ch, 34 px)): BUY / UPGRADE · n PTS (yellow) or NEED n PTS / MAXED / MASTERY FULL / COMING SOON (greyed); EQUIP (orange) / UNEQUIP <key> (dark) for owned button parts.
**Compact Lab** (island): same pieces inside a panel inset max(10ch, Roblox top bar height + 1ch) top, 11cw sides, 6ch bottom (corner 2.4ch, volt stroke), columns 34% | rest | 30%; the game keeps running behind a 0.55 dim.

## Deterministic map
- Open full: MainMenu GO TO THE LAB -> `Lab.Open:Invoke("full")`; close ✕ -> back to the menu.
- Open compact: SKILLS button or K, only while InMenu ~= true; X / K closes (build: the SKILLS pill hides while the compact Lab is open — it sat under the panel and the dim). Character attribute SkillScreenOpen = true while the compact Lab is open (AbilityBar hides its bar, as with SkillScreen).
- Select a card: detail shows it. Buy: SkillRequest("buy", id); the screen redraws from the attributes. A newly bought button part is auto-slotted by SkillServer as today.
- Equip: with a slot selected -> SkillRequest("slot", n, id); else first empty slot; all full -> toast "Slots full · tap a slot to replace" and the slots pulse. Tap a slot then a card = equip there. Unequip -> ("slot", n, "").
- Stage: re-copied when the character, Species or its Mecha_* children change (as MainMenu).
- Card model: ReplicatedStorage.LabPreviews.<pathId> (Model) -> cloned into the card's ViewportFrame; missing -> a "?" card art; soon parts -> locked art.

## Tasks
### Task 1 — Preview hooks + LabPreviewServer 1.0 · Wired
- Each of AdrenalineServer, ScreechServer, EnergyShieldServer, CloakServer, BladeServer, MechaServer, MineServer gets BindableFunction `BuildPreview` (child of the script): Invoke(model) builds that part on the given dino model with the same build code and returns the Mecha_* model (MineServer returns a mine model). Switch per script `<Name>PreviewEnabled`.
- LabPreviewServer (new): builds one raptor mannequin per part (RaptorModelData via DinoModelBuilder, out of Workspace), calls BuildPreview, keeps only the part (anchored, joints to the body removed, pivot at the origin), and stores it as ReplicatedStorage.LabPreviews.<pathId>; Scent Sense = a small built sensor (nose clip + 3 volt fins). Diagnostics LabPreviewState, LabPreviewCount, LabPreviewMissing.
**Acceptance:** 8 previews (adrenaline, screech, shield, cloak, blade, thrusters, traps, scent) present; each looks like the part on the dino; no change to the live parts.

### Task 2 — Lab 1.0 client · Wired
StarterPlayerScripts LocalScript "Lab" with the layout above, full + compact, SKILLS button (place and look of SkillScreen's: left of the ArenaStatus pill, yellow points badge) and K. BindableFunction `Lab.Open(kind)`; switch LabEnabled.
**Acceptance:** PC and 844 x 390 screenshots match mockup A spacing; buy / upgrade / equip / unequip / slot-then-card / slots full; stats tab; T-Rex shows its stats and SOON cards; compact on the island hides the ability bar; mouse free while open.

### Task 3 — MainMenu 1.2 · Wired
Slot row read-only (no picker), GO TO THE LAB block button (volt) under it opening the full Lab; switch MainMenuLabEnabled (false = 1.1 picker).

### Task 4 — Delete SkillScreen; ArenaScope 1.12
Remove src/character/SkillScreen.client.luau and StarterCharacterScripts.SkillScreen; ArenaScope expects Lab + LabPreviewServer on and no SkillScreen entry.

### Task 5 — Publish both places (on Kepu's yes).

## Do-not-touch
SkillServer / SkillTree rules (points, costs, mastery, auto-slot), part behaviour (only the preview hook is added), ModeServer, EggLoader.
