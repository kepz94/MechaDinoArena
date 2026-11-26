-- Lab v1.14 (Mecha Dino Arena) — the workbench: your dino with every applied upgrade, every mech part as a card with its
-- own 3D model, and buying / upgrading / equipping in one screen (LocalScript in StarterPlayerScripts, all devices;
-- survives respawns). Replaces SkillScreen 1.4 (deleted, Kepu: "Delete it"). MDA-97, plan docs/plans/LAB_v1.0.md Task 2,
-- mockup docs/mockups/lab_options.html A "Workbench" (Kepu 2026-10-29: "a dedicated screen for selecting the Dino upgrades
-- with the actual visual for each mecha selection. Replace the skill tree ..."; "Let's do the work bench. Make sure
-- everything is portioned and spaced correctly"; answers: the Lab does everything, compact Lab on the island, cards with
-- the part's 3D model, no RESPEC).
-- Two sizes, same pieces (ch = screen height / 100, cw = screen width / 100; px minimums as noted):
--   * full (from the main menu: Lab.Open:Invoke("full"), MainMenu 1.2 GO TO THE LAB): the whole screen, backdrop
--     rgb(16, 20, 29) -> rgb(26, 33, 48) -> rgb(14, 18, 25); ✕ goes back to the menu.
--   * compact (on the island: the SKILLS button or K while InMenu ~= true): a panel inset max(10ch, Roblox top bar height
--     (GuiService.TopbarInset) + 1ch) top, 11cw sides, 6ch bottom
--     (corner 2.4ch, volt stroke) over a 0.55 black dim; the game keeps running. Character attribute SkillScreenOpen = true
--     while it is open (AbilityBar hides its bar, as with the old screen).
-- Top bar: padding 1.4ch top / 1.2ch bottom; left = max(10ch, right edge of the Roblox top-left buttons (GuiService.TopbarInset
--   Min.X) + 1.6ch) (full) or 2cw (compact); right 2cw; a 0.35ch
--   volt line under it. "LAB" (volt, 0.55 x) + dino name (FredokaOne 3.4ch) | "LV n" (max(1.8ch, 10)) + XP bar 12cw x 1.4ch
--   | MASTERY n/3 chip (gold stroke) ... points chip (yellow, FredokaOne 2.4ch) | X (max(5ch, 30) square). Gaps 1.6ch.
-- Body: padding 1.6ch top, 2cw sides, 2ch bottom; columns 31% | rest | 27% (compact 34% | rest | 30%), gaps 1.6cw.
--   * left: tabs MECH PARTS / STATS (equal, gap 0.8ch, text max(1.7ch, 10)), 1.2ch, a scrolling 2-column card grid (gap
--     1ch; 3 px inner padding so the 2 px strokes are not clipped). Card: padding 1ch, corner 1.4ch; 4:3 ViewportFrame with ReplicatedStorage.LabPreviews.<id> turning (LabPreviewServer
--     1.0; "?" when missing, "SOON" for parts not built yet); name (FredokaOne max(1.9ch, 11)); pips (1.6ch, area colour;
--     star round) + step tag (I / II / III / ★ / NEW); badge top-right: slot key (orange) / ALWAYS ON (volt) / SOON (grey).
--     Equipped = orange stroke, selected = white stroke. Stats tab: rows (name, pips, area, "Next: n pt(s)" / "Maxed").
--   * middle: stage (fills; "ALL UPGRADES" tag; ViewportFrame with a copy of your live character turning, so it shows the
--     equipped parts and Blade Claws; turntable fit: X/Z diagonal to the stage width, height + 0.3 x diagonal to the stage
--     height, 1.12 margin), 1.2ch, 4 slot buttons (equal, gap 0.8cw, height max(6ch, 34): key + part model icon + name
--     (wraps to 2 lines, shrinks to 8 px, then cuts with "..."); empty = faint; a slot too narrow for a 50 px name shows the key and a bigger model only), 1.2ch, hint
--     (max(1.5ch, 10)).
--   * right: detail panel (padding 1.6ch): area · kind (area colour), name (FredokaOne 3ch), steps I / II / III / ★ (got =
--     area colour, next = white outline, rest grey; text max(1.6ch, 10), first line centred on the badge; rows gap
--     max(0.9ch, 5)), buttons (height max(5.6ch, 34)): BUY / UPGRADE ·
--     n PTS (yellow) or NEED n PTS / MAXED / MASTERY FULL / COMING SOON (greyed), and EQUIP (orange) / UNEQUIP <key> (dark)
--     for owned button parts; hint.
-- Rules (SkillServer stays the judge): card -> detail; BUY -> SkillRequest("buy", id) (SkillTree.canBuy decides the label);
--   EQUIP -> ("slot", n, id) into the selected slot, else the first empty one, else toast "Slots full · tap a slot to
--   replace" and the slots pulse; UNEQUIP -> ("slot", n, ""). Tap a slot then an equippable card = equip there; tap a slot
--   with an equippable, unslotted card selected = equip there; otherwise a slot tap selects / deselects it.
--   Equippable = SkillTree.BUTTONS, not soon, this dino's, bought (steps >= 1). Everything redraws from the player
--   attributes (SkillLevel, SkillXPInto, SkillXPNext, SkillLeft, SkillPoints, SkillPath_<id>, SkillSlot1..4).
-- SKILLS button (ScreenGui "LabButton", DisplayOrder 6, the old SkillScreen button's place and look): a pill 8 px left of
--   ArenaStatus's pill (y 12, height 36; x -150 from the right when there is no pill), "SKILLS", yellow badge with the points
--   while SkillLeft > 0; hidden while InMenu and while the compact Lab is open (it would sit under
--   the panel; X / K close). PC key K toggles the compact Lab too (not while typing).
-- Mouse: while open, MouseBehavior Default and the cursor shown right after ShoulderCam (RenderStep "LabMouse", Camera + 1).
-- Switch: script attribute LabEnabled (default true), read at start; false -> no Lab, no SKILLS button.
-- Diagnostics (LocalPlayer attributes, this client): LabVersion, LabOpen ("closed" / "full" / "compact"), LabTab
--   ("parts" / "stats"), LabSelected (path id), LabSlotSel (0 / 1..4), LabLastPress, LabToast, LabCards, LabModels
--   (cards with a 3D model).
-- v1.1 (Kepu 2026-10-29, phone screenshot: "look part of the menu is blocked"): the full Lab's top bar is at least as tall
--   as the Roblox top bar (GuiService.TopbarInset height + 0.6ch; the Roblox buttons on phones reach below the 1.0 bar and
--   covered the MECH PARTS / STATS tabs); its items stay centred in it, so the body starts below the Roblox buttons.
--   Switch: script attribute LabBarClearEnabled (default true; false = the 1.0 bar height). Diagnostic: LabBarH (px).
-- v1.2 (Kepu 2026-10-29: "We need to have two sections. Stats. And mecha abilities. Anything passive goes to stats";
--   mockup docs/mockups/menu_lab_v2_options.html, STATS option 1 "Stat rows + part cards"): the tabs read MECHA ABILITIES /
--   STATS. MECHA ABILITIES = this dino's mech parts that are buttons (SkillTree.BUTTONS), as cards. STATS = the stat rows,
--   then (when this dino has any) a label "ALWAYS ON PARTS" (volt, RobotoMono max(1.5ch, 8)) and the always-on mech parts
--   (mech, not BUTTONS) as the same 3D cards in a 2-column grid. The STATS tab scrolls as one list (gap 1ch). LabTab values
--   stay "parts" / "stats". Switch: script attribute LabSplitTabsEnabled (default true, read at start; false = the 1.1
--   tabs: every mech part on MECH PARTS). The detail line of a button part reads "MECHA ABILITY · BUTTON". Diagnostic:
--   LabPassiveCards (always-on part cards on the STATS tab).
-- v1.3 (Kepu 2026-10-29: "when I select a weapon in the slots it doesn't tell me to the right what the weapon is"):
--   tapping a slot that holds a part (when the tap selects that slot) also selects that part: the detail panel on the
--   right shows it, its card gets the white stroke, and the MECHA ABILITIES tab opens if STATS was showing. The rest of
--   the slot tap is as before (equip a selected unslotted part there / select / deselect the slot; then a card tap
--   equips into the selected slot). Switch: script attribute LabSlotShowsPartEnabled (default true, read at start;
--   false = 1.2). Diagnostic: LabSelected follows.
-- v1.4 (bug, Kepu 2026-10-30: "it isn't letting me upgrade the stat tree on the test raptor"): the BUY / UPGRADE label
--   came from SkillTree.canBuy over the published SkillPath_ values, where the test layer's given parts sit at star, so
--   they counted as spent points and mastered lines ("NEED .. PTS" / "MASTERY FULL" on every stat). The ids in the player
--   attribute SkillTestParts are now set to 0 for that check (SkillServer 1.7 judges buys the same way), and a given part
--   itself reads MAXED. Script attribute LabTestFreeGivenEnabled (default true; false = 1.3).
-- v1.5 (Kepu 2026-10-30: "move the menu and skills to the top right of the screen it's floating mid right"; mockup
--   docs/mockups/menu_corner_confirm_options.html): the SKILLS ScreenGui "LabButton" uses ScreenInsets DeviceSafeInsets
--   and the button's y is CORNER_Y (8), level with ArenaStatus 1.4's MENU pill in the top-right corner (x unchanged: 8 px
--   left of the pill). Script attribute LabCornerEnabled (default true, read at start; false = 1.4, y 12 under Roblox's
--   top bar).
-- v1.6 (MDA-107, plan docs/plans/SKINS_v1.0.md Task 3, mockup docs/mockups/skins_lab_tab.html; Kepu 2026-10-30: "the skins
--   locker belongs in the lab with the other tab", "menu only"): a third tab SKINS (stroke SKIN rgb(201, 162, 255) when
--   on) in the FULL Lab only (opened from the main menu; the compact Lab on the island keeps two tabs). With three tabs
--   the tabs share the row equally and their labels shrink to fit (TextScaled, max S.tabText).
--   * cards (the same grid cell as MECHA ABILITIES): a 4:3 ViewportFrame with a plain copy of your character (no
--     Mecha_*, no hitboxes) painted in that skin (parts tagged SkinRole by SkinServer 1.0; colours / materials from
--     ReplicatedStorage.SkinShared.SkinCatalog), turning; name (FredokaOne); rarity (RobotoMono, rarity colour: STARTER /
--     COMMON grey, RARE volt, EPIC SKIN, LEGENDARY yellow); badge "ON" (SKIN, equipped) or "R$<price>" (ROBUX rgb(0,
--     176, 111), locked). Stroke: selected white, equipped SKIN.
--   * stage: tag "PREVIEW", the stage copy painted in the selected skin while the tab is open (in the equipped skin on
--     the other tabs); hint "Tap a skin to preview it on your dino".
--   * detail: "<DINO> SKIN · <RARITY>" (rarity colour), name, a row of the skin's colours, a line ("Owned. Equip it and you
--     spawn in it every time." / "Locked."), then EQUIP (SKIN, dark text) -> ReplicatedStorage.DinoSkinRequest:
--     FireServer("equip", id) / EQUIPPED (greyed) / "GET · R$<price>" (ROBUX, greyed) + "Buying comes in the next step.".
--     Toast "<NAME> EQUIPPED" when SkinServerResult turns "ok".
--   Selection starts on the equipped skin (player attribute SkinEquipped_<Dino>). Switch: script attribute
--   LabSkinsEnabled (default true, read at start; false = no SKINS tab). LabTab gains "skins". Diagnostics:
--   LabSkinSelected, LabSkinCards.
-- v1.7 (MDA-112, plan docs/plans/SKINS_BUY_v1.0.md Task 3, mockup docs/mockups/skins_buy_options.html option A "Buy &
--   wear"; Kepu 2026-10-30: prices "149 / 499 / 999"): buying skins on the SKINS tab (SkinServer 1.1).
--   * owned = free or listed in player attribute SkinOwned_<Dino>; price = SkinPrice_<RARITY> (live), else the catalog
--     price (card badge "R$<price>" and the button).
--   * detail button for a locked skin: "UNLOCK · 1 CREDIT" (ROBUX) when SkinCredits_<RARITY> > 0; greyed "LOADING" while
--     the skin save is not loaded (SkinSaveState nil / "loading" / "loadFailed" / "noApi"); greyed "SOON" when its rarity
--     has no product; else "GET · R$<price>" (ROBUX). Pressing it -> DinoSkinRequest:FireServer("buy", id); the button is
--     greyed "…" until the next SkinServerResult (at most BUY_WAIT s). Line: "Buy it once, keep it for good."
--   * SkinServerResult "bought" / "boughtNotEquipped" -> toast "<NAME> UNLOCKED!" (SkinLastBought) and that card's stroke
--     YELLOW for 1 s; "credit" -> toast "<RARITY> UNLOCK READY · PICK A SKIN"; "cancelled" -> nothing.
--   * Redraws on SkinOwned_* / SkinCredits_* / SkinPrice_* / SkinSaveState. Switch: script attribute LabSkinBuyEnabled
--     (default true, read at start; false = 1.6: greyed GET + "Buying comes in the next step."). Diagnostic: LabSkinBuy
--     (last button state shown: "credit" / "loading" / "soon" / "get" / "wait").
-- v1.9 (Kepu 2026-10-31: "you wouldn't call it jaws here because the herera doesn't use jaws at all"; SkillTree 1.37,
--   plan docs/plans/STAT_LINES_v1.0.md): a row's name comes from path.nameFor[<your dino>] when that exists (the Herrera:
--   Blood Drinker / Razor Claws / Wiry Frame / Scurry Legs), else path.name as before: cards, the detail title, the
--   slot names and the toasts. The new Herrera rows (Tree Stalker in the new Hunt area, Blood Frenzy) show through
--   ST.pathsFor like any dino-only row. Switch: script attribute LabNameForEnabled (default true, read each draw;
--   false = 1.8 names). Diagnostic: player attribute LabNameFor (the last renamed row "<id>=<name>", or "").
-- v1.8 (Kepu 2026-10-30: "Health steal for raptor should be stronger then"; SkillTree 1.28): a step's text comes from
--   path.stepsFor[<your dino>][i] when that exists (raptor Lifesteal 20% / 35% / 50%), else path.steps[i] as before.
--   Switch: script attribute LabStepsForEnabled (default true, read each draw; false = 1.7).
-- v1.10 (bug, Kepu 2026-11-01, Lab screenshot: "It has the stun breaker appearing on my herrera even tho it's not
--   equipped"): the same cause MainMenu 1.11 fixed in the menu, here in the Lab. The stage copy is re-taken only when its
--   key changes, and the key and the ChildAdded / ChildRemoved watchers looked at "Mecha_*" children only; the Herrera's
--   parts are Models "HPart_<id>" (HerreraPartsServer), so equipping / unequipping a Herrera part never re-copied (the
--   stage kept the parts the Herrera wore when the copy was taken) and the SKINS plain view kept HPart_* pieces. A mecha
--   part child is now "Mecha_*" or "HPart_*" for the stage key, the watchers and the plain view. Raptor / pachy parts
--   ("Mecha_*") and the teno (no parts) unchanged. Switch: script attribute LabHPartsEnabled (default true, read at each
--   check; false = 1.9).
-- v1.11 (teno mecha abilities, plan docs/plans/TENO_ABILITIES_v1.0.md Task 4, MDA-176): the teno's parts are Models
--   "TPart_<id>" (TenoPartsServer 1.0), so a mecha part child is also "TPart_*" for the stage key, the watchers and the plain
--   view. Switch: script attribute LabTPartsEnabled (default true, read at each check; false = 1.10).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local VERSION = "1.11"
VERSION = "1.12" -- v1.12 therizino parts (ZPart_*)
VERSION = "1.13" -- v1.13 dilo parts (DPart_*)
VERSION = "1.14" -- v1.14 troodon parts (OPart_*)
VERSION = "1.15" -- v1.15 part clips (live clip + what line + chips + step preview)
VERSION = "1.16" -- v1.16 SAVE LOADOUT tile
VERSION = "1.17" -- v1.17 phone HUD v2: SKILLS in the ☰ drawer
VERSION = "1.18" -- v1.18 universal SKINS tab
VERSION = "1.19" -- v1.19 LOOKS (SKINS / EMOTES)
VERSION = "1.20" -- v1.20 LOOKS: TRAILS
VERSION = "2.0" -- v2.0 Lab Revamp v1.0: slots first
VERSION = "2.1" -- v2.1 Looks Lab v1.0: owned first, locked tiles say why, emote wheel on the left
VERSION = "2.2" -- v2.2 island streak progress
VERSION = "2.3" -- v2.3 no STATS tab while every stat is maxed
-- v2.3 (Kepu 2026-11-26 11:14 "lets remove stats entirely. everyone should be automatically maxed out."; SkillServer 1.18): while the player attribute SkillAllStatsMax is true the
--   STATS tab is hidden (the tab row lays out without it), a stats view falls back to the parts view, and its button does nothing.
--   A SkillAllStatsMax change redraws an open Lab. Switch: script attribute LabHideStatsEnabled (true, read per draw).
-- v2.2 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 4): uniStats() also carries istreak = max(StatIslandBest,
--   IslandStreak) (SkinStats 1.1), so the Zebra and Storm Front cards (UniversalSkins 1.4) show their island streak progress through
--   the existing earn card path. No layout change.
-- v2.1 (Looks Lab v1.0; Kepu 2026-11-26 01:06 "Instead of having a second row of tabs for owned/earned/robux and all, just have the
--   owned skins show up first, the rest locked and showing why it's locked, if it's for Robux have it say buy, if it's for a
--   challenge have it show the challenge when you click on it and the progression" / "It makes more sense to just click on the
--   wheel and replace from my list. Also make the wheel more properly spaced out and even sections"; picks on mockup
--   docs/mockups/looks_lab_v0.1: "A: Big wheel on the left", "SKINS, EMOTES and TRAILS", "Select it, BUY in the detail",
--   "No upload: lit label + lines"). Code in the script-global table L3.
--   * SKINS / EMOTES / TRAILS (switch LabLooksSortEnabled, default true, read per draw; false = 2.0 with the filter row): no
--     ALL / OWNED / EARN / ROBUX row (filter "all"); tiles in groups (LayoutOrder group x 1000 + catalog order): equipped / on the
--     wheel / on, owned, challenge, Robux. Locked tiles get the lock (as skins) and say why: Robux -> a yellow pill "BUY ·
--     R$<price>"; challenge -> the progress bar plus "<have> / <need>". The detail shows the challenge and its progress (as
--     before) or a BUY · R$<price> button (skins: "GET" became "BUY").
--   * EMOTES wheel (switch LabWheelLeftEnabled, default true, read per draw; false = 2.0 wheel in the detail): on the EMOTES tab
--     the left column shows a big wheel instead of the stage: a round base, 8 even sections split by 8 lines from a hub, each
--     section a button WSlot_<n> (>= 44 px) with its number and the emote's word ("+ EMPTY" when empty). Tap a section -> it
--     lights (yellow fill, its 2 lines yellow), the hub reads "SLOT n / PICK AN EMOTE", the head line "PICK AN EMOTE FOR SLOT
--     n" + CANCEL, owned tiles say "PUT ON n"; tap an owned emote -> DinoEmoteRequest("equip", n, id) (as the 2.0 slot
--     tap). Tap the section again or CANCEL -> off. The detail drops the old ring and PUT ON WHEEL: "On your wheel, slot n." /
--     "Owned. Tap a wheel slot on the left, then this emote."; BUY / LOCKED stay.
--   Diagnostics (player): LabWheelSlot (0 / 1..8).
-- v2.0 (Lab Revamp v1.0, plan docs/plans/LAB_REVAMP_v1.0.md Tasks 2-6, MDA-585..589, ADR-015, mockup docs/mockups/lab_revamp_v0.1
--   option "B · Slots first"; Kepu 2026-11-25 22:46 "revamp the lab screen for mobile optimization. Some buttons are too small, for
--   a first time user I wouldn't know how to equip slots. The looks buttons are way too small", picks "B", "Replace it", red-team
--   "Replace now", "Full screen on phones", "While a slot is empty", "One release"). Replaces the 3-column layout (no switch back).
--   Sizes come from LabLayout 1.0 (StarterPlayerScripts, pure, spec tools/tests/LabLayout.spec.luau): every tap target >= 44 px
--   and ch = max(H / 100, LabChMin 6), so phones (H 381) get bigger text and paddings; PC sizes are as before above H 600.
--   * LEFT column (the old middle frame "Mid", 42% of the body, 40% when the screen is >= 1000 px wide): the stage (fills), then
--     the slot row: Slot_1..4 (key on top, orange when filled; the part name or "TAP TO FILL" under it; the part model only when
--     the slot is >= 70 px wide; the selected slot yellow, fill rgb(58, 47, 10)) and SAVE (1.25 x a slot: "SAVE" / "FOR PRE-GAME"
--     yellow, "SAVED ✓" / "PRE-GAME" green). On the LOOKS tabs the stage fills the column with the dino strip (2 rows of 4,
--     44 px) at its bottom. The 1.x hint line is gone.
--   * RIGHT column (the old "Left" frame): tabs ABILITIES (Tabs.Parts) / STATS (Tabs.Stats) / SKINS (Tabs.Skins) / EMOTES
--     (Tabs.Emotes) / TRAILS (Tabs.Trails) (the island Lab: ABILITIES / STATS), each >= 44 px; the old SKINS / EMOTES / TRAILS
--     pills are hidden. ABILITIES: a head line ("PICK A PART FOR SLOT <key>" + CANCEL while a slot is selected, else "TAP A SLOT
--     ON THE LEFT, OR EQUIP A PART BELOW" / "TAP A SLOT TO SWAP ITS PART"), then row cards Card_<id> (1 a row, 2 when the column
--     is >= 560 px): the part's 3D model, name, pips, "ON <key>" / "NOT ON A SLOT" / "NEW" / "SOON", and Actions: one button Btn
--     (label T: EQUIP / PUT ON <key> / ALREADY ON <key> / TAKE OFF <key> / BUY · n PTS / NEED n PTS / MASTERY FULL / COMING
--     SOON) and INFO. STATS: rows >= 56 px with their own Actions.Btn (UPGRADE / BUY / MAXED / NEED ..); always-on parts as
--     before. LOOKS (SKINS / EMOTES / TRAILS): one row of 4 equal filter chips (>= 44 px), the grid (2 a row on phones, 3 on
--     wide screens) and the detail beside it (grid 60% of the column; EMOTES 45% so the wheel slots reach 44 px).
--   * Detail sheet (ABILITIES / STATS): INFO or a card tap (no slot selected) opens the detail over the list with "< BACK" on
--     top; order: kind, name, Actions, clip, what, chips, steps, hint.
--   * Slot-first flow: tap a slot -> it is selected and every card shows PUT ON <key> (a card tap equips there too); tap it
--     again or CANCEL -> off. EQUIP on a card fills the first empty slot, else the slots pulse and "SLOTS FULL · TAP A SLOT
--     TO SWAP". A slot tap equips the selected part there only while its sheet is open (1.x: whenever a card was selected).
--     Toasts "<NAME> ON <key>", "<NAME> OFF".
--   * Tip strip (first-time help) over the bottom of the stage on ABILITIES: "1 TAP A SLOT / 2 PICK A PART / 3 SAVE" (each
--     struck through when done this session) and GOT IT (player LabTipDone = true for the session); shown while any slot is
--     empty, GOT IT not tapped, and the Tutorial coach (PlayerGui.TutorialCoach) is not up. Switch LabTipsEnabled (true).
--   * Island (compact) Lab: full screen on touch devices (the inset panel on PC), still LabOpen "compact".
--   * Text floor: after each draw every non-scaled text in the Lab under LabMinText (11) px is raised to it.
--   Attributes (script, read per draw): LabTipsEnabled, LabMinText, LabEmoteGridFrac (0.45) and LabLayout's (LabChMin,
--   LabMinTap, LabLeftFrac, LabLeftFracWide, LabWideW, LabSlotH, LabSaveW, LabTwoCardsW, LabLooksGridFrac, LabArtFrac).
--   Removed (Kepu: replace): the 3-column placement; the 1.20 pill fit (LabPillFitEnabled no longer does anything).
--   Diagnostics (player): LabTab ("parts" / "stats" / "skins" / "emotes" / "trails"), LabSheet, LabTipDone; script
--   LabTipStepsDone ("slot,part,save" as 0/1).
-- v1.20 (Kepu 2026-11-25 11:00 "Build", plan docs/plans/TRAILS_v1.0.md; mockup docs/mockups/trails_shop_lab_v0.1.html, picks 23:55
--   "2. Yes", "3. A"): a third pill TRAILS after SKINS / EMOTES (when ReplicatedStorage.TrailShared.TrailCatalog exists, TrailServer
--   1.0). TRAILS view, same layout:
--   * left: NO TRAIL + the 10 trails in TrailCatalog.ORDER, 3 a row: a strip of the trail's colours, name, state: ON (orange stroke) /
--     FREE · OWNED / OWNED / R$149 / a progress bar (earn, not owned). Filters ALL / OWNED / EARN / ROBUX apply (NO TRAIL: ALL, OWNED).
--   * middle: the stage dino (yours or ◀ another, in its equipped skin) walks in place with the selected trail (TrailLook 1.0: walk
--     pose on this Lab's rig so welded mecha parts follow; the trail drawn with parts). Tag "PREVIEW".
--   * right: "TRAIL · ON / FREE / OWNED / EARN / R$149" (NO TRAIL: "TRAIL · OFF"), name, the colour strip, "✓ WORKS ON ALL 8 DINOS",
--     the line (earn: challenge + "<have> / <need>" bar), a button: EQUIP (-> DinoTrailRequest("equip", id)) / EQUIPPED (green,
--     off) / TURN TRAIL OFF (NO TRAIL -> "equip", "none") / BUY · R$149 (-> "buy", id) / LOCKED · KEEP PLAYING, and "One trail for
--     every dino you play." (pick A). Toasts: "<NAME> ON", "TRAIL OFF", "<NAME> UNLOCKED!".
--   New code lives in the script-global table TRL (the main chunk is at the 200-local limit, as EMO in 1.19).
--   Switch: script attribute LabTrailsEnabled (default true, read at start; needs LabEmotesEnabled; false = the 1.19 LOOKS tab).
--   Diagnostics: LabTrailCards, LabTrailSelected.
--   Pill fit (Studio test 2026-11-25: SKINS EMOTES TRAILS + ALL OWNED EARN ROBUX ran past the left column, ROBUX cut off): when the
--   row is wider than the column, the pills go tight as in the mockup's phone row (padding x LabPillFitPad, then text down in 0.1
--   steps to x LabPillFitTextMin). Row height and the grid below do not move. Resets when the column width changes.
--   Switch: script attribute LabPillFitEnabled (default true, read at start). Diagnostic: LabPillFit ("<pad>/<text>").
-- v1.19 (Kepu 2026-11-24 20:27 "1 · SKINS becomes LOOKS", "Build next"; plan docs/plans/EMOTES_v1.0.md, mockup
--   docs/mockups/emote_wheel_v0.1.html Lab option 1): when ReplicatedStorage.EmoteShared.EmoteCatalog exists (EmoteServer 1.0) the
--   universal SKINS tab reads LOOKS and the filter row starts with two pills, SKINS / EMOTES (yellow = on). EMOTES view, same layout:
--   * left: the filters (ALL / OWNED / EARN / ROBUX) apply to emotes; 3 tiles a row in EmoteCatalog.ORDER: the emote's pop-up word
--     (Bangers on dark), name, state: ON WHEEL (orange stroke) / OWNED / R$149 / a progress bar (earn, not owned).
--   * middle: the stage dino (yours or ◀ another, in its equipped skin) does the selected emote on a loop (EmotePose 1.0; joints
--     moved by hand, welded mecha parts follow their segment). Tag "PREVIEW".
--   * right: "EMOTE · FREE / OWNED / EARN / R$149", name, the word, "✓ WORKS ON ALL 8 DINOS", the line (earn: challenge + "<have> /
--     <need>" bar), YOUR WHEEL (8 slots on a ring, the selected emote outlined orange), then a button: PUT ON WHEEL / MOVE ON WHEEL
--     (yellow) -> the slots blink -> tap a slot -> DinoEmoteRequest("equip", slot, id); BUY · R$149 -> ("buy", id); LOCKED · KEEP
--     PLAYING. Toasts: "<TAG> ON YOUR WHEEL", "<NAME> UNLOCKED!".
--   Switch: script attribute LabEmotesEnabled (default true, read at start; false = the 1.18 SKINS tab). Diagnostics: LabLooks,
--   LabEmoteCards, LabEmoteSelected.
-- v1.18 (universal skins, MDA-570, plan docs/plans/UNIVERSAL_SKINS_v0.1.md Task 5, mockup docs/mockups/universal_skins_plan_v0.4.html;
--   Kepu 2026-11-24 "Yes, as shown"): when ReplicatedStorage.SkinShared.UniversalSkins exists (SkinServer 1.2) the SKINS tab (full
--   Lab) shows the universal skins, laid out as the mockup:
--   * left: filter pills ALL / OWNED / EARN / ROBUX under the tabs, then 3 tiles per row in UniversalSkins.ORDER: a strip of the
--     skin's colours, name, and a state line: EQUIPPED (green, on the dino on the stage) / OWNED / R$<price> (ROBUX) / a progress
--     bar (earn skins not owned); a lock on locked tiles. Stroke: selected white, equipped green.
--   * middle: the stage fills the column (no slot row, no hint) with the dino strip at its bottom (8 dinos, yours outlined green,
--     the shown one yellow; two rows of 4 when a button would be under 44 px wide, as on phones; tile names shrink to fit). Your dino is the live copy; another dino is ReplicatedStorage.PregameModels.<Dino>.Body, tagged here
--     with UniversalSkins.tagModel. The shown dino wears the selected skin (UniversalSkins.paintModel; animated blocks via SkinFX).
--     Tag "PREVIEW" / "PREVIEW · LOCKED".
--   * right: "SKIN · FREE / OWNED / EARN / R$<price>" (+ " · ANIMATED"), name, colours, "✓ WORKS ON ALL 8 DINOS", a line (owned:
--     "Owned. Your <DINO> is wearing it." / "Owned. Works on every dino."; Robux: "Unlock it once and every dino can wear it.";
--     earn: the challenge + "<have> / <need>" and a bar), "Wearing it now: <DINOS>" / "No dino is wearing it yet.", then a button:
--     EQUIPPED ON <DINO> (outlined) / EQUIP ON <DINO> (green) -> DinoSkinRequest("equipFor", id, dino) / GET · R$<price> (yellow;
--     "UNLOCK · 1 CREDIT" with a credit; "…" while waiting; LOADING before the save loads) -> ("buy", id, dino) / LOCKED · KEEP
--     PLAYING (grey).
--   * owned = player SkinOwnedU, or free, or SkinAllUnlocked; progress from ArenaW + ArenaL, ArenaW, StatKills, max(StatBestStreak,
--     ArenaStreak). Toasts: "<NAME> ON <DINO>" (equip ok), "<NAME> UNLOCKED!" (bought / earned).
--   Switch: script attribute LabUniversalSkinsEnabled (default true, read at start; false = the 1.17 tab). Diagnostics: LabSkinCards,
--   LabSkinSelected, LabSkinView (dino on the stage), LabSkinFilter.
-- v1.17 (phone HUD v2, MDA-533, plan docs/plans/PHONE_HUD_V2_v1.0.md rule 2, mockup docs/mockups/phone_hud_v0.1.html "A · your
--   version"): while player attribute PhoneHudV2 is true (PhoneMenu 1.0) and script attribute LabPhoneDrawerEnabled ~= false
--   (default true, read per frame), a late render step (Last + 40) places the SKILLS pill at (1, -16, 0, PhoneMenuY_Skills (50))
--   while PhoneMenuOpen is true, else 400 px above the screen (not drawn, not tappable). SQUAD (SquadHUD) follows under it.
--   The 0.5 s corner loop does not move the pill while this is on (else SQUAD caught the old spot between frames).
-- v1.16 (saved loadout, MDA-503, plan docs/plans/PREMATCH_AND_SAVED_LOADOUT_v1.0.md B2, mockup docs/mockups/save_loadout_v0.1.html
--   "A · SAVE button in the slot row"; Kepu 2026-11-13 pick "A · Tile in the slot row"): a fifth tile after the 4 slots,
--   width max(20% of the middle column, 70 px) (the slots share the rest): while SkillSlot1..4 differ from the player
--   attribute SkillSavedLoadout (SkillServer 1.12): yellow, "SAVE LOADOUT" over "FOR THE PRE-GAME" (dark text); when they
--   match: dark green rgb(36,64,47) with a green rgb(70,224,138) outline, "SAVED ✓" over "LOADS IN THE PRE-GAME" (green).
--   Press -> SkillRequest("saveLoadout"); SkillLastResult "saved" -> toast "<DINO> LOADOUT SAVED". Full and compact Lab.
--   Both lines are TextScaled inside the tile (side padding 0.4 cw), capped at 1.7 ch / 1.2 ch (min 10 / 8) by a
--   UITextSizeConstraint, so the words fit a narrow tile (Studio test: fixed sizes ran past a 70 px tile).
--   Switch: script attribute LabSaveLoadoutEnabled (default true, read per layout / draw; false = 1.15: no tile, 4 slots).
-- v1.15 (MDA-444, plan docs/plans/LAB_CLIPS_v1.0.md Task 4, mockup docs/mockups/lab_part_preview_v0.1.html option A; Kepu
--   2026-11-11 "each mecha part to have a preview of what it does in the lab menu with a short explanation" -> "A · Live
--   clip", "Built in the game", "Dilo first"): for a selected part (MECHA ABILITIES or STATS part cards; not skins, not stat
--   rows) that has a LabClipRecipes 1.0 entry, the detail panel shows under the Title:
--   * Clip (LayoutOrder 3): width 100%, height min(width x 10 / 16, 38% of the panel height); background 0B0E14, corner
--     1.2ch, 1 px white stroke 0.92; LabClipPlayer 1.0's ViewportFrame inside; tags "LIVE CLIP" (volt on 06242F, top-left) and
--     "STEP I / II / III / ★" (yellow, top-right), GothamBlack max(1.15ch, 7).
--   * What (4): the recipe's sentence, GothamBlack max(1.75ch, 10), white, wraps.
--   * Chips (5): wrapping row, gap 0.6ch; chip "LABEL value" GothamBlack max(1.35ch, 8), PANEL2, corner 0.8ch; a value that
--     goes up from the owned step reads "old → new" in yellow on 3A2F0A with a yellow 0.6 stroke (LabClipRecipes.chips).
--   * The 1.14 Steps / Actions / Hint move to 13 / 14 / 15.
--   Step preview: each step row is a tap target; tapping it shows that step in the clip and chips and outlines the row
--   (yellow 0.4 stroke; the panel keeps its scroll); tapping it again, picking another part or closing the Lab goes back to
--   the owned step (step I when not owned).
--   The scene is kept across redraws while the part, the step and the character are the same (parked during the
--   redraw); it is destroyed when the part / dino changes, on the SKINS tab, on stat rows and when the Lab closes.
--   Switch: script attribute LabClipEnabled (default true, read at each redraw; false = the 1.14 panel). Diagnostics
--   (LocalPlayer): LabClipVersion, LabClipState ("off" / "none" / "playing" / "error"), LabClipPart, LabClipStep (1-4),
--   LabClipParts (BaseParts in the scene; 0 when none).
-- v1.14 (MDA-347, plan docs/plans/TROODON_PARTS_v1.0.md ticket 3): isMechaPart also knows "OPart_*" (TrooPartsServer 1.0, the
--   troodon's parts): stage key, watchers and plain view as for DPart_*. Switch: script attribute LabOPartsEnabled (default
--   true, read at each check; false = 1.13).
if script:GetAttribute("LabOPartsEnabled") == nil then script:SetAttribute("LabOPartsEnabled", true) end
-- v1.13 (MDA-316, plan docs/plans/DILO_PARTS_v1.0.md Task 3): isMechaPart also knows "DPart_*" (DiloPartsServer 1.0, the
--   dilo's parts): stage key, watchers and plain view as for ZPart_*. Switch: script attribute LabDPartsEnabled (default
--   true, read at each check; false = 1.12).
if script:GetAttribute("LabDPartsEnabled") == nil then script:SetAttribute("LabDPartsEnabled", true) end
-- v1.12 (MDA-243, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 3): isMechaPart also knows "ZPart_*" (TheriPartsServer 1.0, the
--   therizino's parts): stage key, watchers and plain view as for TPart_*. Switch: script attribute LabZPartsEnabled (default
--   true, read at each check; false = 1.11).
if script:GetAttribute("LabZPartsEnabled") == nil then script:SetAttribute("LabZPartsEnabled", true) end
if script:GetAttribute("LabHPartsEnabled") == nil then script:SetAttribute("LabHPartsEnabled", true) end -- v1.10
if script:GetAttribute("LabTPartsEnabled") == nil then script:SetAttribute("LabTPartsEnabled", true) end -- v1.11
local function isMechaPart(name) -- v1.10: "Mecha_*" (raptor / pachy) or "HPart_*" (Herrera); v1.11: + "TPart_*" (teno)
	if name:sub(1, 6) == "Mecha_" then return true end
	if script:GetAttribute("LabTPartsEnabled") ~= false and name:sub(1, 6) == "TPart_" then return true end -- v1.11
	if script:GetAttribute("LabZPartsEnabled") ~= false and name:sub(1, 6) == "ZPart_" then return true end -- v1.12
	if script:GetAttribute("LabDPartsEnabled") ~= false and name:sub(1, 6) == "DPart_" then return true end -- v1.13
	if script:GetAttribute("LabOPartsEnabled") ~= false and name:sub(1, 6) == "OPart_" then return true end -- v1.14
	return script:GetAttribute("LabHPartsEnabled") ~= false and name:sub(1, 6) == "HPart_"
end
local SKIN = Color3.fromRGB(201, 162, 255) -- v1.6
local ROBUX = Color3.fromRGB(0, 176, 111) -- v1.6
if script:GetAttribute("LabTestFreeGivenEnabled") == nil then script:SetAttribute("LabTestFreeGivenEnabled", true) end -- v1.4
local BIND = "LabMouse"
local PANEL = Color3.fromRGB(20, 20, 26)
local PANEL2 = Color3.fromRGB(28, 34, 48)
local YELLOW = Color3.fromRGB(255, 200, 50)
local ORANGE = Color3.fromRGB(255, 155, 46)
local VOLT = Color3.fromRGB(127, 233, 255)
local GOLD = Color3.fromRGB(255, 214, 102)
local GREY = Color3.fromRGB(207, 211, 220)
local MUTED = Color3.fromRGB(143, 153, 170)
local WHITE = Color3.new(1, 1, 1)
local DARK_TEXT = Color3.fromRGB(27, 20, 6)
local ROMAN = {"I", "II", "III", "★"}
local SLOT_KEYS = UserInputService.TouchEnabled and {"R", "C", "R▼", "C▼"} or {"R", "C", "T", "V"}
local DINO_NAMES = {TRex = "T-REX", Raptor = "RAPTOR"}

local player = Players.LocalPlayer
player:SetAttribute("LabVersion", VERSION)
player:SetAttribute("LabNameFor", "") -- v1.9
player:SetAttribute("LabOpen", "closed")
if script:GetAttribute("LabEnabled") == nil then script:SetAttribute("LabEnabled", true) end
if script:GetAttribute("LabBarClearEnabled") == nil then script:SetAttribute("LabBarClearEnabled", true) end -- v1.1
if script:GetAttribute("LabSplitTabsEnabled") == nil then script:SetAttribute("LabSplitTabsEnabled", true) end -- v1.2
local splitTabs = script:GetAttribute("LabSplitTabsEnabled") ~= false -- v1.2
if script:GetAttribute("LabSlotShowsPartEnabled") == nil then script:SetAttribute("LabSlotShowsPartEnabled", true) end -- v1.3
local slotShowsPart = script:GetAttribute("LabSlotShowsPartEnabled") ~= false -- v1.3
if script:GetAttribute("LabSkinsEnabled") == nil then script:SetAttribute("LabSkinsEnabled", true) end -- v1.6
local skinsOn = script:GetAttribute("LabSkinsEnabled") ~= false -- v1.6
if script:GetAttribute("LabSkinBuyEnabled") == nil then script:SetAttribute("LabSkinBuyEnabled", true) end -- v1.7
local skinBuyOn = script:GetAttribute("LabSkinBuyEnabled") ~= false -- v1.7
local BUY_WAIT = 60 -- v1.7
if script:GetAttribute("LabUniversalSkinsEnabled") == nil then script:SetAttribute("LabUniversalSkinsEnabled", true) end -- v1.18
local uniSkinsOn = skinsOn and script:GetAttribute("LabUniversalSkinsEnabled") ~= false -- v1.18
if script:GetAttribute("LabEmotesEnabled") == nil then script:SetAttribute("LabEmotesEnabled", true) end -- v1.19
EMO = {} -- v1.19: emote state + helpers in one script-global table (the main chunk is at the 200-local limit; a local would not compile)
EMO.switch = uniSkinsOn and script:GetAttribute("LabEmotesEnabled") ~= false -- v1.19
if script:GetAttribute("LabTrailsEnabled") == nil then script:SetAttribute("LabTrailsEnabled", true) end -- v1.20
TRL = {} -- v1.20: trail state + helpers (script-global, as EMO)
TRL.switch = EMO.switch and script:GetAttribute("LabTrailsEnabled") ~= false -- v1.20
if script:GetAttribute("LabPillFitEnabled") == nil then script:SetAttribute("LabPillFitEnabled", true) end -- v1.20 pill fit
if script:GetAttribute("LabPillFitPad") == nil then script:SetAttribute("LabPillFitPad", 0.5) end
if script:GetAttribute("LabPillFitTextMin") == nil then script:SetAttribute("LabPillFitTextMin", 0.7) end
TRL.fitOn = TRL.switch and script:GetAttribute("LabPillFitEnabled") ~= false
TRL.fitW, TRL.fitP, TRL.fitS = nil, 1, 1
L2 = {sheet = false, did = {slot = false, part = false, save = false}} -- v2.0: Lab Revamp state + helpers (script-global, as EMO / TRL)
pcall(function() L2.LL = require(script.Parent:WaitForChild("LabLayout", 10)) end)
if script:GetAttribute("LabTipsEnabled") == nil then script:SetAttribute("LabTipsEnabled", true) end -- v2.0
if script:GetAttribute("LabMinText") == nil then script:SetAttribute("LabMinText", 11) end -- v2.0
if script:GetAttribute("LabEmoteGridFrac") == nil then script:SetAttribute("LabEmoteGridFrac", 0.45) end -- v2.0
if script:GetAttribute("LabSlotNameW") == nil then script:SetAttribute("LabSlotNameW", 90) end -- v2.0: slot width that shows part names
L3 = {wslot = nil} -- v2.1: Looks Lab state + helpers (script-global)
if script:GetAttribute("LabLooksSortEnabled") == nil then script:SetAttribute("LabLooksSortEnabled", true) end -- v2.1
if script:GetAttribute("LabWheelLeftEnabled") == nil then script:SetAttribute("LabWheelLeftEnabled", true) end -- v2.1
if script:GetAttribute("LabEnabled") == false then return end

local shared = ReplicatedStorage:WaitForChild("SkillShared", 30)
local remote = ReplicatedStorage:WaitForChild("SkillRequest", 30)
if not shared or not remote then return end
local ST = require(shared:WaitForChild("SkillTree"))
local pg = player:WaitForChild("PlayerGui")
for _, n in ipairs({"Lab", "LabButton"}) do
	local old = pg:FindFirstChild(n)
	if old then old:Destroy() end
end

-- ---------- helpers ----------
local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(0, 8) c.Parent = p return c end
local function stroke(p, color, t, th)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color, s.Transparency, s.Thickness = color, t, th
	s.Parent = p
	return s
end
local function frame(parent, name, color, transp)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	if color then
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transp or 0
	else
		f.BackgroundTransparency = 1
	end
	f.Parent = parent
	return f
end
local function label(parent, name, font, size, color, text)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text or ""
	l.Parent = parent
	return l
end
local function button(parent, name, color, transp)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = color or PANEL
	b.BackgroundTransparency = transp or 0
	b.Parent = parent
	return b
end
local function pad(p, l, r, t, b)
	local u = Instance.new("UIPadding")
	u.PaddingLeft, u.PaddingRight = UDim.new(0, l or 0), UDim.new(0, r or l or 0)
	u.PaddingTop, u.PaddingBottom = UDim.new(0, t or 0), UDim.new(0, b or t or 0)
	u.Parent = p
	return u
end
local function list(p, dir, gap, halign, valign)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if halign then l.HorizontalAlignment = halign end
	if valign then l.VerticalAlignment = valign end
	l.Parent = p
	return l
end
local function topInset()
	local ok, v = pcall(function() return GuiService.TopbarInset.Height end)
	if ok and type(v) == "number" then return v else return 58 end
end
local function topLeftClear() -- where the free top bar starts on the left (right of the Roblox buttons)
	local ok, v = pcall(function() return GuiService.TopbarInset.Min.X end)
	if ok and type(v) == "number" and v > 0 then return v else return 220 end
end

-- ---------- data ----------
local function species()
	local c = player.Character
	local sp = c and c:GetAttribute("Species")
	if type(sp) == "string" and sp ~= "" then return sp end
	sp = player:GetAttribute("DinoSpecies")
	if type(sp) == "string" and sp ~= "" then return sp end
	return "TRex"
end
local function stepsOf(id) return tonumber(player:GetAttribute("SkillPath_" .. id)) or 0 end
local function allSteps()
	local t = {}
	for _, id in ipairs(ST.PATH_ORDER) do t[id] = stepsOf(id) end
	return t
end
local function slotOf(n)
	local v = player:GetAttribute("SkillSlot" .. n)
	if type(v) == "string" and v ~= "" then return v else return nil end
end
local function slotIndex(id)
	for n = 1, ST.SLOTS do
		if slotOf(n) == id then return n end
	end
	return nil
end
local function areaOf(id)
	for _, a in ipairs(ST.AREAS) do
		for _, p in ipairs(a.paths) do
			if p.id == id then return a end
		end
	end
	return ST.AREAS[1]
end
local function pathsFor(dino, mech)
	local out = {}
	for _, a in ipairs(ST.AREAS) do
		local ps = ST.pathsFor and ST.pathsFor(a.id, dino) or a.paths
		for _, p in ipairs(ps) do
			if (p.mech == true) == mech then table.insert(out, p.id) end
		end
	end
	return out
end
local function equippable(id)
	local p = ST.PATHS[id]
	return p ~= nil and ST.BUTTONS[id] == true and not p.soon and stepsOf(id) >= 1
		and (not ST.seesPath or ST.seesPath(p, species()))
end
local function stepText(p, i)
	local s = p.steps[i]
	if script:GetAttribute("LabStepsForEnabled") ~= false and type(p.stepsFor) == "table" then -- v1.8
		local alt = p.stepsFor[species()]
		if type(alt) == "table" and alt[i] ~= nil then s = alt[i] end
	end
	if type(s) == "table" then return s.text or s.desc or tostring(s[1] or "") end
	return tostring(s or "")
end
local function pathName(p) -- v1.9
	if not p then return "" end
	if script:GetAttribute("LabNameForEnabled") ~= false and type(p.nameFor) == "table" then
		local alt = p.nameFor[species()]
		if type(alt) == "string" and alt ~= "" then
			player:SetAttribute("LabNameFor", p.id .. "=" .. alt)
			return alt
		end
	end
	return p.name
end

-- ---------- screen ----------
local gui = Instance.new("ScreenGui")
gui.Name = "Lab"
gui.DisplayOrder = 45
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = pg

local root = button(gui, "Root", Color3.new(0, 0, 0), 0.55) -- dim (compact) / backdrop (full); takes every touch
root.Size = UDim2.fromScale(1, 1)
local box = frame(root, "Box", WHITE, 0) -- the Lab itself (full screen or the compact panel)
local boxGrad = Instance.new("UIGradient")
boxGrad.Rotation = 90
boxGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 20, 29)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(26, 33, 48)), ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 18, 25))})
boxGrad.Parent = box
local boxCorner = corner(box)
local boxStroke = stroke(box, VOLT, 0.7, 2)
box.ClipsDescendants = true

-- top bar
local bar = frame(box, "Bar", Color3.fromRGB(14, 18, 26), 0.04)
local barLine = frame(bar, "Line", VOLT, 0.75)
barLine.AnchorPoint = Vector2.new(0, 1)
local barLeft = frame(bar, "Left")
local barLeftList = list(barLeft, Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center)
local nameL = label(barLeft, "Name", Enum.Font.FredokaOne, 24, WHITE)
nameL.RichText = true
nameL.AutomaticSize = Enum.AutomaticSize.X
nameL.LayoutOrder = 1
local lvL = label(barLeft, "Level", Enum.Font.GothamBlack, 12, GREY)
lvL.AutomaticSize = Enum.AutomaticSize.X
lvL.LayoutOrder = 2
local xpBack = frame(barLeft, "XP", WHITE, 0.88)
xpBack.LayoutOrder = 3
corner(xpBack, UDim.new(1, 0))
local xpFill = frame(xpBack, "Fill", YELLOW)
corner(xpFill, UDim.new(1, 0))
local masL = label(barLeft, "Mastery", Enum.Font.GothamBlack, 12, GOLD)
masL.AutomaticSize = Enum.AutomaticSize.X
masL.LayoutOrder = 4
local masCorner = corner(masL)
local masStroke = stroke(masL, GOLD, 0.4, 2)
local masPad = pad(masL, 8)
local barRight = frame(bar, "Right")
barRight.AnchorPoint = Vector2.new(1, 0)
local barRightList = list(barRight, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
local ptsL = label(barRight, "Points", Enum.Font.FredokaOne, 16, DARK_TEXT)
ptsL.BackgroundTransparency = 0
ptsL.BackgroundColor3 = YELLOW
ptsL.AutomaticSize = Enum.AutomaticSize.X
ptsL.LayoutOrder = 1
local ptsCorner = corner(ptsL)
local ptsPad = pad(ptsL, 10)
local closeB = button(barRight, "Close", PANEL)
closeB.LayoutOrder = 2
local closeCorner = corner(closeB)
stroke(closeB, WHITE, 0.84, 2)
local closeX = label(closeB, "X", Enum.Font.FredokaOne, 16, WHITE, "X") -- "✕" draws as a box in the game fonts
closeX.Size = UDim2.fromScale(1, 1)

-- body columns
local body = frame(box, "Body")
local left = frame(body, "Left")
local mid = frame(body, "Mid")
local right = frame(body, "Right")

-- left: tabs + grid
local tabs = frame(left, "Tabs")
local tabParts = button(tabs, "Parts", WHITE, 0.94)
local tabStats = button(tabs, "Stats", WHITE, 0.94)
local tabCorners, tabStrokes, tabLabels = {}, {}, {}
for i, t in ipairs({tabParts, tabStats}) do
	tabCorners[i] = corner(t)
	tabStrokes[i] = stroke(t, VOLT, 1, 2)
	tabLabels[i] = label(t, "T", Enum.Font.GothamBlack, 11, MUTED, i == 1 and (splitTabs and "MECHA ABILITIES" or "MECH PARTS") or "STATS")
	tabLabels[i].Size = UDim2.fromScale(1, 1)
end
-- v1.6: SKINS tab (full Lab only)
local tabSkins = button(tabs, "Skins", WHITE, 0.94)
tabSkins.Visible = false
local tabSkinsCorner = corner(tabSkins)
local tabSkinsStroke = stroke(tabSkins, SKIN, 1, 2)
local tabSkinsLabel = label(tabSkins, "T", Enum.Font.GothamBlack, 11, MUTED, "SKINS")
tabSkinsLabel.Size = UDim2.fromScale(1, 1)
local grid = Instance.new("ScrollingFrame")
grid.Name = "Grid"
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 4
grid.ScrollBarImageColor3 = VOLT
grid.ScrollingDirection = Enum.ScrollingDirection.Y
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.Parent = left
local gridLayout = Instance.new("UIGridLayout")
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
pad(grid, 3, 0, 3, 3) -- room for the 2 px selected / equipped stroke (the scrolling frame clips it otherwise)
local gridList = Instance.new("UIListLayout") -- v1.2: the STATS tab (rows, label, always-on part cards) as one list
gridList.SortOrder = Enum.SortOrder.LayoutOrder

-- middle: stage + slots + hint
local stage = frame(mid, "Stage", PANEL, 0.1)
local stageCorner = corner(stage)
stroke(stage, WHITE, 0.88, 2)
stage.ClipsDescendants = true
local floor = frame(stage, "Floor", VOLT, 0.72)
floor.AnchorPoint = Vector2.new(0.5, 0.5)
floor.Position = UDim2.fromScale(0.5, 0.86)
floor.Size = UDim2.fromScale(0.72, 0.07)
corner(floor, UDim.new(0.5, 0))
local floorGrad = Instance.new("UIGradient")
floorGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3),
	NumberSequenceKeypoint.new(1, 1)})
floorGrad.Parent = floor
local view = Instance.new("ViewportFrame")
view.Name = "View"
view.Size = UDim2.fromScale(1, 1)
view.BackgroundTransparency = 1
view.Ambient = Color3.fromRGB(150, 150, 160)
view.LightColor = Color3.fromRGB(255, 250, 240)
view.LightDirection = Vector3.new(-0.4, -1, -0.6)
view.Parent = stage
local cam = Instance.new("Camera")
cam.FieldOfView = 40
cam.Parent = view
view.CurrentCamera = cam
local stageTag = label(stage, "Tag", Enum.Font.RobotoMono, 11, VOLT, "ALL UPGRADES")
stageTag.BackgroundTransparency = 0.6
stageTag.BackgroundColor3 = Color3.new(0, 0, 0)
stageTag.AutomaticSize = Enum.AutomaticSize.X
local stageTagCorner = corner(stageTag)
local stageTagPad = pad(stageTag, 8)
local slotsRow = frame(mid, "Slots")
local slotBtns = {}
for n = 1, ST.SLOTS do
	local b = button(slotsRow, "Slot_" .. n, WHITE, 0.94)
	local c = corner(b)
	local s = stroke(b, ORANGE, 0.45, 2)
	local k = label(b, "Key", Enum.Font.GothamBlack, 12, ORANGE, SLOT_KEYS[n] or tostring(n))
	local icon = Instance.new("ViewportFrame")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Ambient = Color3.fromRGB(170, 170, 180)
	icon.Parent = b
	local icam = Instance.new("Camera")
	icam.FieldOfView = 30
	icam.Parent = icon
	icon.CurrentCamera = icam
	local nm = label(b, "Name", Enum.Font.GothamBlack, 11, GREY)
	nm.TextXAlignment = Enum.TextXAlignment.Left
	nm.TextTruncate = Enum.TextTruncate.AtEnd
	nm.TextWrapped, nm.TextScaled = true, true -- long names wrap to 2 lines / shrink to 8 px before cutting
	local fit = Instance.new("UITextSizeConstraint")
	fit.Name = "Fit"
	fit.MinTextSize, fit.MaxTextSize = 8, 11
	fit.Parent = nm
	slotBtns[n] = {b = b, corner = c, stroke = s, key = k, icon = icon, cam = icam, name = nm}
end
local hint = label(mid, "Hint", Enum.Font.GothamBlack, 10, MUTED, "Tap a card, then EQUIP · tap a slot to choose where it goes")
hint.TextWrapped = true

-- v1.16: SAVE LOADOUT tile (see the header)
if script:GetAttribute("LabSaveLoadoutEnabled") == nil then script:SetAttribute("LabSaveLoadoutEnabled", true) end
local saveTile = button(slotsRow, "SaveLoadout", YELLOW, 0)
local saveCorner = corner(saveTile)
local saveStroke = stroke(saveTile, Color3.fromRGB(70, 224, 138), 1, 2)
local saveTop = label(saveTile, "Top", Enum.Font.GothamBlack, 12, DARK_TEXT, "SAVE LOADOUT")
local saveSub = label(saveTile, "Sub", Enum.Font.GothamBlack, 9, DARK_TEXT, "FOR THE PRE-GAME")
for _, l in ipairs({saveTop, saveSub}) do -- fit the tile's width (a UITextSizeConstraint caps the size per layout)
	l.TextScaled = true
	Instance.new("UITextSizeConstraint").Parent = l
end
local function saveOn() return script:GetAttribute("LabSaveLoadoutEnabled") ~= false end
local function drawSave()
	saveTile.Visible = saveOn()
	if not saveTile.Visible then return end
	local cur = {}
	for n = 1, ST.SLOTS do cur[n] = tostring(player:GetAttribute("SkillSlot" .. n) or "") end
	local saved = tostring(player:GetAttribute("SkillSavedLoadout") or "")
	local clean = saved ~= "" and table.concat(cur, ",") == saved
	saveTile.BackgroundColor3 = clean and Color3.fromRGB(36, 64, 47) or YELLOW
	saveStroke.Transparency = clean and 0 or 1
	local green = Color3.fromRGB(70, 224, 138)
	saveTop.TextColor3, saveSub.TextColor3 = clean and green or DARK_TEXT, clean and green or DARK_TEXT
	local top, sub = clean and "SAVED ✓" or "SAVE", clean and "PRE-GAME" or "FOR PRE-GAME" -- v2.0 (1.16: SAVE LOADOUT / FOR THE PRE-GAME)
	if saveTop.Text ~= top then saveTop.Text = top end
	if saveSub.Text ~= sub then saveSub.Text = sub end
end
for _, a in ipairs({"SkillSlot1", "SkillSlot2", "SkillSlot3", "SkillSlot4", "SkillSavedLoadout"}) do
	player:GetAttributeChangedSignal(a):Connect(drawSave)
end
saveTile.Activated:Connect(function()
	L2.did.save = true -- v2.0 tip strip
	if remote then remote:FireServer("saveLoadout") end
end)

-- right: detail
local detail = Instance.new("ScrollingFrame")
detail.Name = "Detail"
detail.BackgroundColor3 = PANEL
detail.BackgroundTransparency = 0.1
detail.BorderSizePixel = 0
detail.ScrollBarThickness = 3
detail.ScrollBarImageColor3 = VOLT
detail.AutomaticCanvasSize = Enum.AutomaticSize.Y
detail.CanvasSize = UDim2.new()
detail.Parent = right
local detailCorner = corner(detail)
stroke(detail, WHITE, 0.88, 2)
local detailPad = pad(detail, 12)
local detailList = list(detail, Enum.FillDirection.Vertical, 8)

-- toast
local toast = label(box, "Toast", Enum.Font.FredokaOne, 16, YELLOW)
toast.BackgroundColor3 = PANEL
toast.BackgroundTransparency = 0.05
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.AutomaticSize = Enum.AutomaticSize.X
toast.Visible = false
toast.ZIndex = 10
local toastCorner = corner(toast)
stroke(toast, YELLOW, 0, 2)
local toastPad = pad(toast, 16)

-- ---------- state ----------
local mode = nil -- nil / "full" / "compact"
local tab = "parts"
local skinSel = nil -- v1.6: selected skin id on the SKINS tab
local selected = nil
local slotSel = nil
local cards = {} -- {id, b, view, cam, model, angle}
local S = {}
local toastToken = 0
local stagePreview, stageKey = nil, nil
local center, radius, orbit = Vector3.zero, 20, 0
local stageSize = Vector3.new(20, 20, 20)
-- turntable fit: the widest the model gets while turning is its X/Z diagonal; fit that to the stage width (aspect) and
-- the height (plus the depth the 0.32 camera tilt shows) to the stage height; 1.12 margin
local function stageRadius()
	local a = view.AbsoluteSize
	local aspect = (a.Y > 0 and a.X > 0) and a.X / a.Y or 1
	local t = math.tan(math.rad(cam.FieldOfView / 2))
	local w = math.sqrt(stageSize.X ^ 2 + stageSize.Z ^ 2)
	local hNeed = ((stageSize.Y + 0.3 * w) * 0.5) / t
	local wNeed = (w * 0.5) / (t * aspect)
	return math.max(hNeed, wNeed) * 1.12
end
local pulseUntil = 0

local function press(v) player:SetAttribute("LabLastPress", v) end
local function showToast(text)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.Visible = true
	player:SetAttribute("LabToast", text)
	task.delay(1.8, function()
		if toastToken == my then
			toast.Visible = false
			player:SetAttribute("LabToast", "")
		end
	end)
end

-- ---------- measuring ----------
local function measure()
	local W, H = root.AbsoluteSize.X, root.AbsoluteSize.Y
	if L2.LL then -- v2.0: LabLayout 1.0 (the 1.x math below stays only for a missing module)
		local at = script:GetAttributes()
		if tab == "skins" and EMO.view() then at.LabLooksGridFrac = tonumber(script:GetAttribute("LabEmoteGridFrac")) or 0.45 end
		local L = L2.LL.compute(W, H, {mode = mode or "full", touch = UserInputService.TouchEnabled, topInset = topInset(),
			topLeftClear = topLeftClear(), slotSel = slotSel ~= nil and tab == "parts", attrs = at})
		S.L = L
		S.W, S.H, S.ch, S.cw = W, H, L.ch, L.cw
		S.bx, S.by, S.bw, S.bh = L.box.x, L.box.y, L.box.w, L.box.h
		S.barLeftPad = L.barLeftPad
		S.colL, S.colR = L.left.w / math.max(L.body.w, 1), 0
		S.nameS, S.small, S.closeS, S.barH = L.text.name, L.text.small, L.closeS, L.barH
		player:SetAttribute("LabBarH", math.floor(S.barH + 0.5))
		S.tabText, S.cardName, S.pip, S.tagS = L.text.tab, L.text.card, math.max(1.6 * L.ch, 9), L.text.tag
		S.slotH, S.hintS, S.stepS, S.btnH = L.slotRowH, L.text.hint, L.text.step, L.btnH
		S.metaH = L.metaH
		return
	end
	local ch, cw = H / 100, W / 100
	S.W, S.H, S.ch, S.cw = W, H, ch, cw
	if mode == "compact" then
		local top = math.max(10 * ch, topInset() + ch) -- below the Roblox top bar (58 px on phones, more than 10ch there)
		S.bx, S.by, S.bw, S.bh = 11 * cw, top, W - 22 * cw, H - top - 6 * ch
		S.barLeftPad = 2 * cw
		S.colL, S.colR = 0.34, 0.30
	else
		S.bx, S.by, S.bw, S.bh = 0, 0, W, H
		S.barLeftPad = math.max(10 * ch, topLeftClear() + 1.6 * ch)
		S.colL, S.colR = 0.31, 0.27
	end
	S.nameS = math.max(3.4 * ch, 16)
	S.small = math.max(1.8 * ch, 10)
	S.closeS = math.max(5 * ch, 30)
	S.barH = 1.4 * ch + math.max(S.closeS, S.nameS * 1.1) + 1.2 * ch
	if mode ~= "compact" and script:GetAttribute("LabBarClearEnabled") ~= false then -- v1.1: clear the Roblox top bar
		S.barH = math.max(S.barH, topInset() + 0.6 * ch)
	end
	player:SetAttribute("LabBarH", math.floor(S.barH + 0.5))
	S.tabText = math.max(1.7 * ch, 10)
	S.cardName = math.max(1.9 * ch, 11)
	S.pip = math.max(1.6 * ch, 7)
	S.tagS = math.max(1.6 * ch, 9)
	S.slotH = math.max(6 * ch, 34)
	S.hintS = math.max(1.5 * ch, 10)
	S.stepS = math.max(1.6 * ch, 10)
	S.btnH = math.max(5.6 * ch, 34)
end

-- ---------- pips / tags ----------
local function pips(parent, id, size)
	local holder = frame(parent, "Pips")
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Size = UDim2.fromOffset(0, size)
	list(holder, Enum.FillDirection.Horizontal, math.max(size * 0.3, 2), nil, Enum.VerticalAlignment.Center)
	local col = rgb(areaOf(id).color)
	local n = stepsOf(id)
	for i = 1, 4 do
		local p = frame(holder, "Pip" .. i, i <= n and col or WHITE, i <= n and 0 or 0.86)
		p.Size = UDim2.fromOffset(size, size)
		p.LayoutOrder = i
		corner(p, i == 4 and UDim.new(0.5, 0) or UDim.new(0.25, 0))
	end
	return holder
end

-- ---------- model views ----------
local function framing(model)
	local cf, size = model:GetBoundingBox()
	return cf.Position, math.max(size.X, size.Y, size.Z)
end
local function previewOf(id)
	local f = ReplicatedStorage:FindFirstChild("LabPreviews")
	local m = f and f:FindFirstChild(id)
	if m then return m:Clone() end
	return nil
end

-- ---------- drawing ----------
local redraw

local function equip(id, n)
	press(("equip:%s:%d"):format(id, n))
	remote:FireServer("slot", n, id)
	slotSel = nil
	L2.did.part = true -- v2.0 tip strip
	showToast(("%s ON %s"):format(string.upper(pathName(ST.PATHS[id])), SLOT_KEYS[n] or tostring(n))) -- v2.0 (1.x: "<Name> → <key>")
end

-- v1.6: skins
local SC -- SkinCatalog (client copy), loaded on first use
local function skinCatalog()
	if SC then return SC end
	local f = ReplicatedStorage:FindFirstChild("SkinShared")
	local m = f and f:FindFirstChild("SkinCatalog")
	if m then
		local ok, r = pcall(require, m)
		if ok then SC = r end
	end
	return SC
end
local RARITY_COLOR = {STARTER = GREY, COMMON = GREY, RARE = VOLT, EPIC = SKIN, LEGENDARY = YELLOW}
-- v1.7: buying
local buyPendingAt = nil
local flashId, flashUntil = nil, 0
local function ownedSet()
	if not skinBuyOn then return nil end
	local set = {}
	local v = player:GetAttribute("SkinOwned_" .. species())
	if type(v) == "string" then
		for id in v:gmatch("[^,]+") do set[id] = true end
	end
	return set
end
local function skinPrice(sk)
	local live = skinBuyOn and player:GetAttribute("SkinPrice_" .. tostring(sk.rarity))
	if type(live) == "number" then return live end
	return sk.price
end
local function skinSaveReady()
	local s = player:GetAttribute("SkinSaveState")
	return s ~= nil and s ~= "loading" and s ~= "loadFailed" and s ~= "noApi"
end
local function equippedSkin()
	local cat = skinCatalog()
	local id = player:GetAttribute("SkinEquipped_" .. species())
	if cat then return cat.sanitize(species(), id) end
	return type(id) == "string" and id or "classic"
end
local function paintModel(model, id)
	local cat = skinCatalog()
	local sk = cat and cat.get(species(), id)
	if not sk then return end
	for _, d in ipairs(model:GetDescendants()) do
		local role = d:IsA("BasePart") and d:GetAttribute("SkinRole")
		if role then
			local hex = sk.colors[role]
			if hex then d.Color = Color3.fromHex(hex) end
			local mat = sk.materials and sk.materials[role] or d:GetAttribute("SkinBaseMaterial")
			if type(mat) == "string" then
				local ok, m = pcall(function() return Enum.Material[mat] end)
				if ok and m then d.Material = m end
			end
		end
	end
end
local function plainCopy() -- the live character without scripts, effects, hitboxes or mech parts, anchored, facing -Z
	local c = player.Character
	if not c then return nil end
	local was = c.Archivable
	c.Archivable = true
	local ok, copy = pcall(function() return c:Clone() end)
	c.Archivable = was
	if not ok or not copy then return nil end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Beam")
			or d:IsA("Trail") or d:IsA("ForceField") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	for _, ch in ipairs(copy:GetChildren()) do
		if ch.Name == "Hitboxes" or isMechaPart(ch.Name) then ch:Destroy() end -- v1.10: + HPart_*
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	local hrp = copy:FindFirstChild("HumanoidRootPart")
	local base = hrp and hrp.CFrame or copy:GetPivot()
	local flat = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
	if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
	copy:PivotTo(CFrame.lookAt(base.Position, base.Position + flat.Unit):Inverse() * copy:GetPivot())
	return copy
end
-- v1.18: universal skins (see the header)
local GREEN = Color3.fromRGB(70, 224, 138)
local USM -- UniversalSkins (client copy)
local function uniMod()
	if USM then return USM end
	local f = ReplicatedStorage:FindFirstChild("SkinShared")
	local m = f and f:FindFirstChild("UniversalSkins")
	if m then
		local ok, r = pcall(require, m)
		if ok then USM = r end
	end
	return USM
end
local function useUni() return uniSkinsOn and uniMod() ~= nil end
local function uniTab() return useUni() and tab == "skins" and mode == "full" end
local uniView = nil -- dino shown on the SKINS stage (nil = yours)
local uniFilter = "all"
local function uniStageSpecies()
	if uniTab() and uniView then return uniView end
	return species()
end
local function uniOwnedSet()
	local set = {}
	local v = player:GetAttribute("SkinOwnedU")
	if type(v) == "string" then
		for id in v:gmatch("[^,]+") do set[id] = true end
	end
	return set
end
local function uniOwns(id) return uniMod().owns(id, uniOwnedSet(), player:GetAttribute("SkinAllUnlocked") == true) end
local function uniEquipped(sp) return uniMod().sanitize(player:GetAttribute("SkinEquipped_" .. sp)) end
local function uniStats()
	return {w = player:GetAttribute("ArenaW"), l = player:GetAttribute("ArenaL"), kills = player:GetAttribute("StatKills"),
		best = math.max(tonumber(player:GetAttribute("StatBestStreak")) or 0, tonumber(player:GetAttribute("ArenaStreak")) or 0),
		istreak = math.max(tonumber(player:GetAttribute("StatIslandBest")) or 0, tonumber(player:GetAttribute("IslandStreak")) or 0)} -- v2.2
end
local function uniPrice(sk)
	local live = player:GetAttribute("SkinPrice_" .. tostring(sk.unlock.rarity))
	if type(live) == "number" then return live end
	return sk.unlock.price
end
local function uniState(sk, sp) -- "eq" / "own" / "buy" / "earn"
	if uniOwns(sk.id) then return uniEquipped(sp) == sk.id and "eq" or "own" end
	return sk.unlock.kind == "earn" and "earn" or "buy"
end
local function uniName(sp) return uniMod().DINO_NAMES[sp] or string.upper(sp) end
local function uniPaint(model, id, sp)
	local US, cat = uniMod(), skinCatalog()
	local classic = cat and cat.get(sp, "classic")
	US.paintModel(model, id, classic and classic.colors)
end
local function swatchStrip(parent, sk, h)
	local s = frame(parent, "Colors")
	s.Size = UDim2.new(1, 0, 0, h)
	s.ClipsDescendants = true
	corner(s, UDim.new(0, 0.8 * S.ch))
	local n = math.max(1, math.min(4, #sk.sw))
	for i = 1, n do
		local c = frame(s, "C" .. i, Color3.fromHex(sk.sw[i]), 0)
		c.Position, c.Size = UDim2.fromScale((i - 1) / n, 0), UDim2.fromScale(1 / n, 1)
	end
	return s
end
local uniFilterRow, uniFilterBtns, uniStrip, uniStripBtns = nil, {}, nil, {}
EMO.lookBtns = {} -- v1.19
EMO.looks = "skins" -- v1.19: "skins" / "emotes" on the LOOKS tab
EMO.sel, EMO.arm = nil, false -- v1.19
local function uniBuild() -- the filter row and the dino strip, made once
	if uniFilterRow then return end
	uniFilterRow = frame(left, "UniFilters")
	list(uniFilterRow, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
	if TRL.fitOn then -- v1.20 pill fit: re-check whenever the row's content width changes
		uniFilterRow:FindFirstChildOfClass("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TRL.fitCheck() end)
		uniFilterRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() TRL.fitCheck() end)
	end
	if EMO.switch then -- v1.19: SKINS / EMOTES pills first
		for i, f in ipairs(TRL.switch and {{"skins", "SKINS"}, {"emotes", "EMOTES"}, {"trails", "TRAILS"}} or {{"skins", "SKINS"}, {"emotes", "EMOTES"}}) do -- v1.20: + TRAILS
			local b = button(uniFilterRow, "L_" .. f[1], PANEL2, 0)
			b.LayoutOrder = i - 10
			b.AutomaticSize = Enum.AutomaticSize.X
			local c = corner(b, UDim.new(1, 0))
			local l = label(b, "T", Enum.Font.GothamBlack, 10, MUTED, f[2])
			l.AutomaticSize = Enum.AutomaticSize.X
			l.Size = UDim2.fromScale(0, 1)
			local pd = pad(b, 8)
			EMO.lookBtns[f[1]] = {b = b, l = l, c = c, pd = pd}
			b.Activated:Connect(function()
				press("looks:" .. f[1])
				EMO.looks = f[1]
				EMO.arm = false
				redraw()
			end)
		end
	end
	for i, f in ipairs({{"all", "ALL"}, {"own", "OWNED"}, {"earn", "EARN"}, {"buy", "ROBUX"}}) do
		local b = button(uniFilterRow, "F_" .. f[1], PANEL2, 0)
		b.LayoutOrder = i
		b.AutomaticSize = Enum.AutomaticSize.X
		local c = corner(b, UDim.new(1, 0))
		local l = label(b, "T", Enum.Font.GothamBlack, 10, MUTED, f[2])
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.fromScale(0, 1)
		local pd = pad(b, 8)
		uniFilterBtns[f[1]] = {b = b, l = l, c = c, pd = pd}
		b.Activated:Connect(function()
			press("skinFilter:" .. f[1])
			uniFilter = f[1]
			redraw()
		end)
	end
	uniStrip = frame(stage, "UniStrip")
	uniStrip.ZIndex = 3
	for i, sp in ipairs(uniMod().DINOS) do
		local b = button(uniStrip, "D_" .. sp, PANEL, 0.15)
		b.ZIndex = 3
		local c = corner(b, UDim.new(0, 6))
		local st = stroke(b, WHITE, 0.8, 1.5)
		local l = label(b, "T", Enum.Font.GothamBlack, 10, GREY, uniName(sp))
		l.ZIndex = 3
		l.Size = UDim2.new(1, -4, 1, 0)
		l.Position = UDim2.fromOffset(2, 0)
		l.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MinTextSize, fit.MaxTextSize = 6, 12
		fit.Parent = l
		uniStripBtns[i] = {sp = sp, b = b, c = c, st = st, l = l, fit = fit}
		b.Activated:Connect(function()
			press("skinDino:" .. sp)
			uniView = sp ~= species() and sp or nil
			redraw()
		end)
	end
end
-- ---------- v1.19: EMOTES on the LOOKS tab ----------
function EMO.cat()
	if EMO.cat_ then return EMO.cat_ end
	local f = ReplicatedStorage:FindFirstChild("EmoteShared")
	local m = f and f:FindFirstChild("EmoteCatalog")
	if m then
		local ok, r = pcall(require, m)
		if ok then EMO.cat_ = r end
	end
	return EMO.cat_
end
function EMO.on() return EMO.switch and useUni() and EMO.cat() ~= nil end
function EMO.view() return EMO.on() and EMO.looks == "emotes" end
function EMO.wheel()
	local out, i = {}, 0
	for v in (tostring(player:GetAttribute("EmoteWheel") or "") .. ","):gmatch("([^,]*),") do
		i += 1
		if i <= 8 then out[i] = v ~= "" and v or nil end
	end
	return out
end
function EMO.state(id) -- "wheel" / "own" / "buy" / "earn"
	local e = EMO.cat().get(id)
	for v in tostring(player:GetAttribute("EmoteOwned") or ""):gmatch("[^,]+") do
		if v == id then
			local w = EMO.wheel()
			for i = 1, 8 do if w[i] == id then return "wheel" end end
			return "own"
		end
	end
	return e.unlock.kind == "earn" and "earn" or "buy"
end
function EMO.progress(id)
	local e = EMO.cat().get(id)
	local have = tonumber(player:GetAttribute(e.unlock.stat)) or 0
	return math.min(have, e.unlock.need), e.unlock.need
end
function EMO.wordStrip(parent, word, h)
	local s = frame(parent, "Word", Color3.fromRGB(27, 35, 51), 0)
	s.Size = UDim2.new(1, 0, 0, h)
	corner(s, UDim.new(0, 0.8 * S.ch))
	local w = label(s, "W", Enum.Font.Bangers, h * 0.6, YELLOW, word)
	w.Size, w.Position = UDim2.fromScale(0.92, 0.84), UDim2.fromScale(0.04, 0.08)
	w.TextScaled = true
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = w
	return s
end
function EMO.cards()
	gridList.Parent = nil
	gridLayout.Parent = grid
	local EC = EMO.cat()
	if not EMO.sel or not EC.get(EMO.sel) then EMO.sel = EMO.wheel()[1] or EC.ORDER[1] end
	local p1 = 0.8 * S.ch
	local cw3 = S.uniCellW or S.cellW
	local swH = math.max(3.2 * S.ch, 14)
	local nS = math.max(1.5 * S.ch, 9)
	local tS = math.max(1.3 * S.ch, 8)
	local shown = 0
	for i, id in ipairs(EC.ORDER) do
		local e = EC.get(id)
		local st = EMO.state(id)
		local keep = uniFilter == "all" or (uniFilter == "own" and (st == "wheel" or st == "own"))
			or (uniFilter == "earn" and e.unlock.kind == "earn") or (uniFilter == "buy" and e.unlock.kind == "robux")
		if keep then
			shown += 1
			local b = button(grid, "Emote_" .. id, PANEL2, 0)
			b.LayoutOrder = i
			corner(b, UDim.new(0, 1.2 * S.ch))
			if EMO.sel == id then
				stroke(b, WHITE, 0, 2.5)
			elseif st == "wheel" then
				stroke(b, ORANGE, 0, 2)
			else
				stroke(b, WHITE, 0.9, 2)
			end
			local sw = EMO.wordStrip(b, e.word, swH)
			sw.Position, sw.Size = UDim2.fromOffset(p1, p1), UDim2.fromOffset(cw3 - 2 * p1, swH)
			if st == "buy" or st == "earn" then sw.BackgroundTransparency = 0.45 end
			local nm = label(b, "Name", Enum.Font.FredokaOne, nS, WHITE, e.name)
			nm.TextXAlignment = Enum.TextXAlignment.Left
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			nm.Position = UDim2.fromOffset(p1, p1 + swH + 0.6 * S.ch)
			nm.Size = UDim2.fromOffset(cw3 - 2 * p1, nS * 1.2)
			nm.TextScaled = true
			local nfit = Instance.new("UITextSizeConstraint")
			nfit.MinTextSize, nfit.MaxTextSize = 6, nS
			nfit.Parent = nm
			local y = p1 + swH + 0.6 * S.ch + nS * 1.2 + 0.4 * S.ch
			if st == "earn" then
				local have, need = EMO.progress(id)
				local bar = frame(b, "Bar", Color3.fromRGB(42, 52, 70), 0)
				bar.Position, bar.Size = UDim2.fromOffset(p1, y + tS * 0.3), UDim2.fromOffset(cw3 - 2 * p1, math.max(0.9 * S.ch, 4))
				corner(bar, UDim.new(1, 0))
				local fill = frame(bar, "Fill", GREEN, 0)
				fill.Size = UDim2.fromScale(need > 0 and math.clamp(have / need, 0, 1) or 0, 1)
				corner(fill, UDim.new(1, 0))
			else
				local txt, col = "OWNED", MUTED
				if st == "wheel" then txt, col = "ON WHEEL", ORANGE
				elseif st == "buy" then txt, col = "R$" .. tostring(e.unlock.price), YELLOW end
				local sl = label(b, "State", Enum.Font.GothamBlack, tS, col, txt)
				sl.TextXAlignment = Enum.TextXAlignment.Left
				sl.TextTruncate = Enum.TextTruncate.AtEnd
				sl.Position, sl.Size = UDim2.fromOffset(p1, y), UDim2.fromOffset(cw3 - 2 * p1, tS * 1.2)
			end
			b.Activated:Connect(function()
				if L3.pick and L3.pick(id) then return end -- v2.1: a wheel section is selected -> put this emote there
				press("emote:" .. id)
				EMO.sel = id
				EMO.arm = false
				redraw()
			end)
			table.insert(cards, {id = id, b = b})
		end
	end
	player:SetAttribute("LabEmoteCards", shown)
	player:SetAttribute("LabEmoteSelected", EMO.sel or "")
	player:SetAttribute("LabCards", shown)
	player:SetAttribute("LabModels", 0)
end
-- ---------- v1.20: TRAILS on the LOOKS tab ----------
function TRL.cat()
	if TRL.cat_ then return TRL.cat_ end
	local f = ReplicatedStorage:FindFirstChild("TrailShared")
	local m = f and f:FindFirstChild("TrailCatalog")
	if m then
		local ok, r = pcall(require, m)
		if ok then TRL.cat_ = r end
	end
	return TRL.cat_
end
function TRL.on() return TRL.switch and EMO.on() and TRL.cat() ~= nil end
function TRL.view() return TRL.on() and EMO.looks == "trails" end
function TRL.fitCheck() -- v1.20 pill fit: row wider than the column -> tight padding, then smaller text, one step a redraw
	if not (mode and uniFilterRow and uniFilterRow.Visible) then return end
	local over = uniFilterRow:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize.X - uniFilterRow.AbsoluteSize.X
	if over <= 0.5 then return end
	local padMin = tonumber(script:GetAttribute("LabPillFitPad")) or 0.5
	local textMin = tonumber(script:GetAttribute("LabPillFitTextMin")) or 0.7
	if TRL.fitP > padMin then TRL.fitP = padMin
	elseif TRL.fitS > textMin + 0.001 then TRL.fitS = math.max(textMin, TRL.fitS - 0.1)
	else return end
	player:SetAttribute("LabPillFit", ("%.2f/%.2f"):format(TRL.fitP, TRL.fitS))
	task.defer(redraw)
end
function TRL.equipped()
	local e = player:GetAttribute("TrailEquipped")
	return type(e) == "string" and e ~= "" and e or "neon"
end
function TRL.state(id) -- "on" / "own" / "buy" / "earn"; id "none" = NO TRAIL
	if id == "none" then return TRL.equipped() == "none" and "on" or "own" end
	local t = TRL.cat().get(id)
	for v in tostring(player:GetAttribute("TrailOwned") or ""):gmatch("[^,]+") do
		if v == id then return TRL.equipped() == id and "on" or "own" end
	end
	return t.unlock.kind == "earn" and "earn" or "buy"
end
function TRL.progress(id)
	local t = TRL.cat().get(id)
	local have = tonumber(player:GetAttribute(t.unlock.stat)) or 0
	return math.min(have, t.unlock.need), t.unlock.need
end
function TRL.strip(parent, id, h) -- the trail's colours left to right (NO TRAIL: dark, "OFF")
	local s = frame(parent, "Colors", Color3.fromRGB(27, 35, 51), 0)
	s.Size = UDim2.new(1, 0, 0, h)
	corner(s, UDim.new(0, 0.8 * S.ch))
	if id ~= "none" then
		s.BackgroundColor3 = Color3.new(1, 1, 1)
		local g = Instance.new("UIGradient")
		g.Color = TRL.cat().colorSequence(id)
		g.Parent = s
	else
		local d = label(s, "D", Enum.Font.GothamBlack, h * 0.5, MUTED, "OFF")
		d.Size = UDim2.fromScale(1, 1)
	end
	return s
end
function TRL.cards()
	gridList.Parent = nil
	gridLayout.Parent = grid
	local TC = TRL.cat()
	if not TRL.sel or (TRL.sel ~= "none" and not TC.get(TRL.sel)) then TRL.sel = TRL.equipped() end
	local p1 = 0.8 * S.ch
	local cw3 = S.uniCellW or S.cellW
	local swH = math.max(3.2 * S.ch, 14)
	local nS = math.max(1.5 * S.ch, 9)
	local tS = math.max(1.3 * S.ch, 8)
	local shown = 0
	local ids = {"none"}
	for _, id in ipairs(TC.ORDER) do table.insert(ids, id) end
	for i, id in ipairs(ids) do
		local t = id ~= "none" and TC.get(id) or nil
		local st = TRL.state(id)
		local kind = t and t.unlock.kind or "free"
		local keep = uniFilter == "all" or (uniFilter == "own" and (st == "on" or st == "own"))
			or (uniFilter == "earn" and kind == "earn") or (uniFilter == "buy" and kind == "robux")
		if keep then
			shown += 1
			local b = button(grid, "Trail_" .. id, PANEL2, 0)
			b.LayoutOrder = i
			corner(b, UDim.new(0, 1.2 * S.ch))
			if TRL.sel == id then
				stroke(b, WHITE, 0, 2.5)
			elseif st == "on" then
				stroke(b, ORANGE, 0, 2)
			else
				stroke(b, WHITE, 0.9, 2)
			end
			local sw = TRL.strip(b, id, swH)
			sw.Position, sw.Size = UDim2.fromOffset(p1, p1), UDim2.fromOffset(cw3 - 2 * p1, swH)
			if st == "buy" or st == "earn" then sw.BackgroundTransparency = 0.45 end
			local nm = label(b, "Name", Enum.Font.FredokaOne, nS, WHITE, t and t.name or "No Trail")
			nm.TextXAlignment = Enum.TextXAlignment.Left
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			nm.Position = UDim2.fromOffset(p1, p1 + swH + 0.6 * S.ch)
			nm.Size = UDim2.fromOffset(cw3 - 2 * p1, nS * 1.2)
			nm.TextScaled = true
			local nfit = Instance.new("UITextSizeConstraint")
			nfit.MinTextSize, nfit.MaxTextSize = 6, nS
			nfit.Parent = nm
			local y = p1 + swH + 0.6 * S.ch + nS * 1.2 + 0.4 * S.ch
			if st == "earn" then
				local have, need = TRL.progress(id)
				local bar = frame(b, "Bar", Color3.fromRGB(42, 52, 70), 0)
				bar.Position, bar.Size = UDim2.fromOffset(p1, y + tS * 0.3), UDim2.fromOffset(cw3 - 2 * p1, math.max(0.9 * S.ch, 4))
				corner(bar, UDim.new(1, 0))
				local fill = frame(bar, "Fill", GREEN, 0)
				fill.Size = UDim2.fromScale(need > 0 and math.clamp(have / need, 0, 1) or 0, 1)
				corner(fill, UDim.new(1, 0))
			else
				local txt, col = "OWNED", MUTED
				if st == "on" then txt, col = "ON", ORANGE
				elseif st == "buy" then txt, col = "R$" .. tostring(t.unlock.price), YELLOW
				elseif id == "none" then txt = "OFF"
				elseif kind == "free" then txt, col = "FREE · OWNED", GREEN end
				local sl = label(b, "State", Enum.Font.GothamBlack, tS, col, txt)
				sl.TextXAlignment = Enum.TextXAlignment.Left
				sl.TextTruncate = Enum.TextTruncate.AtEnd
				sl.Position, sl.Size = UDim2.fromOffset(p1, y), UDim2.fromOffset(cw3 - 2 * p1, tS * 1.2)
			end
			b.Activated:Connect(function()
				press("trail:" .. id)
				TRL.sel = id
				redraw()
			end)
			table.insert(cards, {id = id, b = b})
		end
	end
	player:SetAttribute("LabTrailCards", shown)
	player:SetAttribute("LabTrailSelected", TRL.sel or "")
	player:SetAttribute("LabCards", shown)
	player:SetAttribute("LabModels", 0)
end
local function drawUniCards()
	if TRL.view() then TRL.cards() return end -- v1.20
	if EMO.view() then EMO.cards() return end -- v1.19
	gridList.Parent = nil
	gridLayout.Parent = grid
	local US = uniMod()
	local sp = uniStageSpecies()
	if not skinSel or not US.get(skinSel) then skinSel = uniEquipped(species()) end
	local p1 = 0.8 * S.ch
	local cw3 = S.uniCellW or S.cellW
	local swH = math.max(3.2 * S.ch, 14)
	local nS = math.max(1.5 * S.ch, 9)
	local tS = math.max(1.3 * S.ch, 8)
	local shown = 0
	for i, id in ipairs(US.ORDER) do
		local sk = US.SKINS[id]
		local st = uniState(sk, sp)
		local keep = uniFilter == "all" or (uniFilter == "own" and (st == "eq" or st == "own"))
			or (uniFilter == "earn" and sk.unlock.kind == "earn") or (uniFilter == "buy" and sk.unlock.kind == "robux")
		if keep then
			shown += 1
			local b = button(grid, "Skin_" .. id, PANEL2, 0)
			b.LayoutOrder = i
			corner(b, UDim.new(0, 1.2 * S.ch))
			if flashId == id and os.clock() < flashUntil then
				stroke(b, YELLOW, 0, 3)
			elseif skinSel == id then
				stroke(b, WHITE, 0, 2.5)
			elseif st == "eq" then
				stroke(b, GREEN, 0, 2)
			else
				stroke(b, WHITE, 0.9, 2)
			end
			local sw = swatchStrip(b, sk, swH)
			sw.Position, sw.Size = UDim2.fromOffset(p1, p1), UDim2.fromOffset(cw3 - 2 * p1, swH)
			if st == "buy" or st == "earn" then
				for _, c in ipairs(sw:GetChildren()) do
					if c:IsA("Frame") then c.BackgroundTransparency = 0.5 end
				end
				local lk = label(b, "Lock", Enum.Font.GothamBlack, math.max(1.6 * S.ch, 9), WHITE, "🔒")
				lk.AnchorPoint = Vector2.new(1, 0)
				lk.Position = UDim2.fromOffset(cw3 - p1 - 2, p1 + 1)
				lk.Size = UDim2.fromOffset(math.max(1.8 * S.ch, 10), math.max(1.8 * S.ch, 10))
			end
			local nm = label(b, "Name", Enum.Font.FredokaOne, nS, WHITE, sk.name)
			nm.TextXAlignment = Enum.TextXAlignment.Left
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			nm.Position = UDim2.fromOffset(p1, p1 + swH + 0.6 * S.ch)
			nm.Size = UDim2.fromOffset(cw3 - 2 * p1, nS * 1.2)
			nm.TextScaled = true -- long names shrink to fit a phone tile (Studio phone test: "DESERT…")
			local nfit = Instance.new("UITextSizeConstraint")
			nfit.MinTextSize, nfit.MaxTextSize = 6, nS
			nfit.Parent = nm
			local y = p1 + swH + 0.6 * S.ch + nS * 1.2 + 0.4 * S.ch
			if st == "earn" then
				local have, need = US.progress(id, uniStats())
				local bar = frame(b, "Bar", Color3.fromRGB(42, 52, 70), 0)
				bar.Position, bar.Size = UDim2.fromOffset(p1, y + tS * 0.3), UDim2.fromOffset(cw3 - 2 * p1, math.max(0.9 * S.ch, 4))
				corner(bar, UDim.new(1, 0))
				local fill = frame(bar, "Fill", GREEN, 0)
				fill.Size = UDim2.fromScale(need and need > 0 and math.clamp(have / need, 0, 1) or 0, 1)
				corner(fill, UDim.new(1, 0))
			else
				local txt, col = "OWNED", MUTED
				if st == "eq" then txt, col = "EQUIPPED", GREEN
				elseif st == "buy" then txt, col = "R$" .. tostring(uniPrice(sk) or "?"), YELLOW end
				local sl = label(b, "State", Enum.Font.GothamBlack, tS, col, txt)
				sl.TextXAlignment = Enum.TextXAlignment.Left
				sl.TextTruncate = Enum.TextTruncate.AtEnd
				sl.Position, sl.Size = UDim2.fromOffset(p1, y), UDim2.fromOffset(cw3 - 2 * p1, tS * 1.2)
			end
			b.Activated:Connect(function()
				press("skin:" .. id)
				skinSel = id
				redraw()
			end)
			table.insert(cards, {id = id, b = b})
		end
	end
	player:SetAttribute("LabSkinCards", shown)
	player:SetAttribute("LabSkinSelected", skinSel or "")
	player:SetAttribute("LabSkinView", sp)
	player:SetAttribute("LabSkinFilter", uniFilter)
	player:SetAttribute("LabCards", shown)
	player:SetAttribute("LabModels", 0)
end
local function drawSkinCards()
	if useUni() then drawUniCards() return end -- v1.18
	gridList.Parent = nil
	gridLayout.Parent = grid
	local cat = skinCatalog()
	local list = cat and cat.SKINS[species()] or {}
	local eqId = equippedSkin()
	if not skinSel or not (cat and cat.get(species(), skinSel)) then skinSel = eqId end
	local base = plainCopy()
	local models = 0
	for i, sk in ipairs(list) do
		local b = button(grid, "Skin_" .. sk.id, PANEL2, 0)
		b.LayoutOrder = i
		corner(b, UDim.new(0, 1.4 * S.ch))
		if flashId == sk.id and os.clock() < flashUntil then -- v1.7: just unlocked
			stroke(b, YELLOW, 0, 3)
		elseif skinSel == sk.id then
			stroke(b, WHITE, 0, 2.5)
		elseif eqId == sk.id then
			stroke(b, SKIN, 0.1, 2)
		else
			stroke(b, WHITE, 0.9, 2)
		end
		local entry = {id = sk.id, b = b}
		local p1 = S.ch
		local artW = S.cellW - 2 * p1
		local artH = artW * 0.75
		local art = frame(b, "Art", Color3.fromRGB(10, 14, 22), 0.2)
		art.Position, art.Size = UDim2.fromOffset(p1, p1), UDim2.fromOffset(artW, artH)
		corner(art, UDim.new(0, S.ch))
		local glow = Instance.new("UIGradient")
		glow.Rotation = 90
		glow.Color = ColorSequence.new(Color3.fromRGB(14, 20, 30), Color3.fromRGB(44, 34, 66))
		glow.Parent = art
		if base then
			local m = base:Clone()
			paintModel(m, sk.id)
			local vf = Instance.new("ViewportFrame")
			vf.Name = "Model"
			vf.BackgroundTransparency = 1
			vf.Size = UDim2.fromScale(1, 1)
			vf.Ambient = Color3.fromRGB(160, 160, 170)
			vf.LightDirection = Vector3.new(-0.4, -1, -0.6)
			vf.Parent = art
			local c = Instance.new("Camera")
			c.FieldOfView = 30
			c.Parent = vf
			vf.CurrentCamera = c
			m.Parent = vf
			local ctr, size = framing(m)
			entry.cam, entry.center = c, ctr
			entry.radius = (size * 0.5) / math.tan(math.rad(15)) * 1.05
			entry.angle = i * 0.9
			models += 1
		end
		local nm = label(b, "Name", Enum.Font.FredokaOne, S.cardName, WHITE, sk.name)
		nm.TextXAlignment = Enum.TextXAlignment.Left
		nm.TextTruncate = Enum.TextTruncate.AtEnd
		nm.Position = UDim2.fromOffset(p1, p1 + artH + 0.6 * S.ch)
		nm.Size = UDim2.fromOffset(artW, S.cardName * 1.15)
		local metaY = p1 + artH + 0.6 * S.ch + S.cardName * 1.15 + 0.6 * S.ch
		local rar = label(b, "Rarity", Enum.Font.RobotoMono, S.tagS, RARITY_COLOR[sk.rarity] or GREY, sk.rarity)
		rar.TextXAlignment = Enum.TextXAlignment.Left
		rar.Position = UDim2.fromOffset(p1, metaY)
		rar.Size = UDim2.fromOffset(artW, S.metaH)
		local owned = cat.owns(species(), sk.id, ownedSet()) -- v1.7: owned paid skins
		local badgeText, badgeCol, badgeTxt
		if eqId == sk.id then
			badgeText, badgeCol, badgeTxt = "ON", SKIN, Color3.fromRGB(26, 16, 48)
		elseif not owned and sk.price then
			badgeText, badgeCol, badgeTxt = "R$" .. tostring(skinPrice(sk)), ROBUX, WHITE
		end
		if badgeText then
			local bd = label(b, "Badge", Enum.Font.GothamBlack, S.tagS, badgeTxt, badgeText)
			bd.BackgroundTransparency = 0
			bd.BackgroundColor3 = badgeCol
			bd.AutomaticSize = Enum.AutomaticSize.X
			bd.AnchorPoint = Vector2.new(1, 0)
			bd.Position = UDim2.fromOffset(p1 + artW - 0.6 * S.ch, p1 + 0.6 * S.ch)
			bd.Size = UDim2.fromOffset(0, S.tagS + 0.8 * S.ch)
			corner(bd, UDim.new(0, 0.7 * S.ch))
			pad(bd, 0.6 * S.ch)
		end
		b.Activated:Connect(function()
			press("skin:" .. sk.id)
			skinSel = sk.id
			redraw()
		end)
		table.insert(cards, entry)
	end
	if base then base:Destroy() end
	player:SetAttribute("LabSkinCards", #list)
	player:SetAttribute("LabSkinSelected", skinSel or "")
	player:SetAttribute("LabCards", #list)
	player:SetAttribute("LabModels", models)
end

local function drawCards()
	for _, c in ipairs(cards) do c.b:Destroy() end
	table.clear(cards)
	for _, ch in ipairs(grid:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	if tab == "skins" then drawSkinCards() return end -- v1.6
	if tab == "parts" and L2.drawPartCards then L2.drawPartCards() return end -- v2.0: row cards with their own buttons
	local dino = species()
	local ids = pathsFor(dino, tab == "parts")
	local cardOf = {} -- v1.2: id -> true when drawn as a 3D card
	local passive = {}
	if splitTabs then -- v1.2: MECHA ABILITIES = button parts; STATS = stats + always-on parts
		local mech = pathsFor(dino, true)
		if tab == "parts" then
			ids = {}
			for _, id in ipairs(mech) do
				if ST.BUTTONS[id] == true then table.insert(ids, id) end
			end
		else
			for _, id in ipairs(mech) do
				if ST.BUTTONS[id] ~= true then table.insert(passive, id) end
			end
		end
	end
	if tab == "parts" then
		for _, id in ipairs(ids) do cardOf[id] = true end
		gridList.Parent = nil
		gridLayout.Parent = grid
	else
		gridLayout.Parent = nil
		gridList.Parent = grid
	end
	local passiveBox
	if #passive > 0 then
		local sec = label(grid, "PassiveLabel", Enum.Font.RobotoMono, math.max(1.5 * S.ch, 8), VOLT, "ALWAYS ON PARTS")
		sec.TextXAlignment = Enum.TextXAlignment.Left
		sec.TextYAlignment = Enum.TextYAlignment.Bottom
		sec.LayoutOrder = #ids + 1
		sec.Size = UDim2.fromOffset(S.rowW, math.max(1.5 * S.ch, 8) + 0.6 * S.ch)
		passiveBox = frame(grid, "Passive")
		passiveBox.LayoutOrder = #ids + 2
		passiveBox.AutomaticSize = Enum.AutomaticSize.Y
		passiveBox.Size = UDim2.fromOffset(S.rowW, 0)
		local pg2 = Instance.new("UIGridLayout")
		pg2.SortOrder = Enum.SortOrder.LayoutOrder
		pg2.CellSize = S.cardCell
		pg2.CellPadding = UDim2.fromOffset(S.ch, S.ch)
		pg2.Parent = passiveBox
		for _, id in ipairs(passive) do
			table.insert(ids, id)
			cardOf[id] = true
		end
	end
	player:SetAttribute("LabPassiveCards", #passive)
	local models = 0
	if not selected or not table.find(ids, selected) then selected = ids[1] end
	for i, id in ipairs(ids) do
		local p = ST.PATHS[id]
		local area = areaOf(id)
		local col = rgb(area.color)
		local n = stepsOf(id)
		local eq = slotIndex(id)
		local asCard = cardOf[id] == true
		local b = button(asCard and tab ~= "parts" and passiveBox or grid, "Card_" .. id, PANEL2, 0)
		b.LayoutOrder = i
		if not asCard then b.Size = UDim2.fromOffset(S.rowW, S.rowH) end -- v1.2: rows sit in the STATS list
		corner(b, UDim.new(0, 1.4 * S.ch))
		local st
		if selected == id and L2.sheet then -- v2.0: white only while its sheet is open
			st = stroke(b, WHITE, 0, 2.5)
		elseif eq then
			st = stroke(b, ORANGE, 0.1, 2)
		else
			st = stroke(b, WHITE, 0.9, 2)
		end
		local entry = {id = id, b = b}
		if asCard then
			local p1 = S.ch
			local artW = S.cellW - 2 * p1
			local artH = artW * 0.75
			local art = frame(b, "Art", Color3.fromRGB(10, 14, 22), 0.2)
			art.Position, art.Size = UDim2.fromOffset(p1, p1), UDim2.fromOffset(artW, artH)
			corner(art, UDim.new(0, S.ch))
			local glow = Instance.new("UIGradient")
			glow.Rotation = 90
			glow.Color = ColorSequence.new(Color3.fromRGB(14, 20, 30), Color3.fromRGB(30, 60, 72))
			glow.Parent = art
			local m = (not p.soon) and previewOf(id) or nil
			if m then
				local vf = Instance.new("ViewportFrame")
				vf.Name = "Model"
				vf.BackgroundTransparency = 1
				vf.Size = UDim2.fromScale(1, 1)
				vf.Ambient = Color3.fromRGB(160, 160, 170)
				vf.LightDirection = Vector3.new(-0.4, -1, -0.6)
				vf.Parent = art
				local c = Instance.new("Camera")
				c.FieldOfView = 30
				c.Parent = vf
				vf.CurrentCamera = c
				m.Parent = vf
				local ctr, size = framing(m)
				entry.cam, entry.center = c, ctr
				entry.radius = (size * 0.5) / math.tan(math.rad(15)) * 1.15
				entry.angle = i * 0.9
				models += 1
			else
				local q = label(art, "Q", Enum.Font.FredokaOne, math.max(artH * 0.3, 12), MUTED, p.soon and "SOON" or "?")
				q.Size = UDim2.fromScale(1, 1)
				q.TextTransparency = 0.3
			end
			local nm = label(b, "Name", Enum.Font.FredokaOne, S.cardName, WHITE, pathName(p))
			nm.TextXAlignment = Enum.TextXAlignment.Left
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			nm.Position = UDim2.fromOffset(p1, p1 + artH + 0.6 * S.ch)
			nm.Size = UDim2.fromOffset(artW, S.cardName * 1.15)
			local metaY = p1 + artH + 0.6 * S.ch + S.cardName * 1.15 + 0.6 * S.ch
			local pp = pips(b, id, S.pip)
			pp.Position = UDim2.fromOffset(p1, metaY + (S.metaH - S.pip) / 2)
			local tagText = n == 0 and "NEW" or ROMAN[n]
			local tg = label(b, "Step", Enum.Font.GothamBlack, S.tagS, n == 0 and YELLOW or col, tagText)
			tg.BackgroundTransparency = 0.65
			tg.BackgroundColor3 = Color3.new(0, 0, 0)
			tg.AutomaticSize = Enum.AutomaticSize.X
			tg.AnchorPoint = Vector2.new(1, 0)
			tg.Position = UDim2.fromOffset(p1 + artW, metaY)
			tg.Size = UDim2.fromOffset(0, S.metaH)
			corner(tg, UDim.new(0, 0.8 * S.ch))
			pad(tg, 0.8 * S.ch)
			local badgeText, badgeCol, badgeTxt
			if p.soon then
				badgeText, badgeCol, badgeTxt = "SOON", Color3.fromRGB(90, 96, 110), WHITE
			elseif ST.BUTTONS[id] ~= true then
				badgeText, badgeCol, badgeTxt = "ALWAYS ON", VOLT, Color3.fromRGB(6, 36, 48)
			elseif eq then
				badgeText, badgeCol, badgeTxt = SLOT_KEYS[eq] or tostring(eq), ORANGE, DARK_TEXT
			end
			if badgeText then
				local bd = label(b, "Badge", Enum.Font.GothamBlack, S.tagS, badgeTxt, badgeText)
				bd.BackgroundTransparency = 0
				bd.BackgroundColor3 = badgeCol
				bd.AutomaticSize = Enum.AutomaticSize.X
				bd.AnchorPoint = Vector2.new(1, 0)
				bd.Position = UDim2.fromOffset(p1 + artW - 0.6 * S.ch, p1 + 0.6 * S.ch)
				bd.Size = UDim2.fromOffset(0, S.tagS + 0.8 * S.ch)
				corner(bd, UDim.new(0, 0.7 * S.ch))
				pad(bd, 0.6 * S.ch)
			end
			if p.soon then b.BackgroundTransparency = 0.45 end
		else
			-- stats row
			local px = 1.4 * S.ch
			local nm = label(b, "Name", Enum.Font.FredokaOne, S.cardName, WHITE, pathName(p))
			nm.TextXAlignment = Enum.TextXAlignment.Left
			nm.Position = UDim2.fromOffset(px, 1.2 * S.ch)
			nm.Size = UDim2.new(1, -2 * px, 0, S.cardName * 1.15)
			local pp = pips(b, id, S.pip)
			pp.AnchorPoint = Vector2.new(1, 0)
			pp.Position = UDim2.new(1, -px, 0, 1.2 * S.ch + (S.cardName * 1.15 - S.pip) / 2)
			local ar = label(b, "Area", Enum.Font.GothamBlack, S.tagS, col, string.upper(area.name))
			ar.TextXAlignment = Enum.TextXAlignment.Left
			ar.Position = UDim2.fromOffset(px, 1.2 * S.ch + S.cardName * 1.15 + 0.6 * S.ch)
			ar.Size = UDim2.new(0.5, -px, 0, S.metaH)
			local nx = label(b, "Next", Enum.Font.GothamBlack, S.tagS, MUTED, n < 4 and ("Next: %d %s"):format(ST.COST[n + 1], ST.COST[n + 1] == 1 and "pt" or "pts") or "Maxed")
			nx.TextXAlignment = Enum.TextXAlignment.Right
			nx.AnchorPoint = Vector2.new(1, 0)
			nx.Position = UDim2.new(1, -px, 0, 1.2 * S.ch + S.cardName * 1.15 + 0.6 * S.ch)
			nx.Size = UDim2.new(0.5, -px, 0, S.metaH)
			if L2.statRow then L2.statRow(b, id) end -- v2.0: the row's own UPGRADE / BUY button
		end
		b.Activated:Connect(function()
			press("card:" .. id)
			if slotSel and equippable(id) then
				equip(id, slotSel)
			end
			selected = id
			L2.sheet = true -- v2.0: the detail opens as a sheet over the list
			redraw()
		end)
		table.insert(cards, entry)
	end
	player:SetAttribute("LabCards", #ids)
	player:SetAttribute("LabModels", models)
	player:SetAttribute("LabSelected", selected or "")
end

local function drawSlots()
	local selOk = selected and equippable(selected) and not slotIndex(selected)
	for n, s in ipairs(slotBtns) do
		local id = slotOf(n)
		local p = id and ST.PATHS[id]
		s.name.Text = p and pathName(p) or "TAP TO FILL" -- v2.0 (1.x: "empty")
		s.name.TextColor3 = p and GREY or MUTED
		if slotSel == n then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = YELLOW, 0, 3 -- v2.0 (1.x: white)
		elseif os.clock() < pulseUntil or selOk then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0.35, 2
		elseif p then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = ORANGE, 0.45, 2
		else
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0.6, 2 -- v2.0 (1.x: 0.86)
		end
		for _, ch in ipairs(s.icon:GetChildren()) do
			if ch:IsA("Model") then ch:Destroy() end
		end
		local m = id and previewOf(id)
		if m then
			m.Parent = s.icon
			local ctr, size = framing(m)
			s.cam.CFrame = CFrame.lookAt(ctr + Vector3.new(0.8, 0.5, -1).Unit * ((size * 0.5) / math.tan(math.rad(15)) * 1.1), ctr)
		end
	end
	if L2.slotLook then L2.slotLook() end -- v2.0
	player:SetAttribute("LabSlotSel", slotSel or 0)
end

local function detailButton(parent, text, color, txtColor, enabled, order)
	local b = button(parent, "Btn", color, enabled and 0 or 0.55)
	b.LayoutOrder = order
	corner(b, UDim.new(0, 1.6 * S.ch))
	local shade = frame(b, "Band", Color3.new(0, 0, 0), 0.78)
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.fromScale(0, 1)
	shade.Size = UDim2.new(1, 0, 0, 0.9 * S.ch)
	corner(shade, UDim.new(0, 1.6 * S.ch))
	local l = label(b, "T", Enum.Font.FredokaOne, math.max(2.1 * S.ch, 12), txtColor, text)
	l.Size = UDim2.fromScale(1, 1)
	l.TextTransparency = enabled and 0 or 0.35
	l.TextScaled = false
	l.TextWrapped = true
	return b
end

-- v1.15: part clips (see the header)
if script:GetAttribute("LabClipEnabled") == nil then script:SetAttribute("LabClipEnabled", true) end
local ClipRecipes, ClipPlayer = nil, nil
pcall(function()
	local rm, pm = script.Parent:WaitForChild("LabClipRecipes", 5), script.Parent:WaitForChild("LabClipPlayer", 5)
	if rm and pm then ClipRecipes, ClipPlayer = require(rm), require(pm) end
end)
player:SetAttribute("LabClipVersion", "1.0")
player:SetAttribute("LabClipState", "off")
player:SetAttribute("LabClipParts", 0)
local clip = nil -- {c = LabClipPlayer clip, id, step, char, parked}
local clipStep, clipStepFor = nil, nil
local redrawDetail = nil
local function clipDrop()
	if clip then clip.c:destroy() clip = nil end
	player:SetAttribute("LabClipParts", 0)
end
local function clipPark()
	if not clip then return end
	clip.parked = true
	if clip.c.view then clip.c.view.Parent = nil end
	task.defer(function()
		if clip and clip.parked then
			clipDrop()
			if player:GetAttribute("LabClipState") == "playing" then player:SetAttribute("LabClipState", "off") end
		end
	end)
end
local function clipVisible()
	local v = clip and clip.c.view
	if not v or not v.Parent or not right.Visible then return false end -- v2.0: no clip while the sheet is closed
	local top, bot = detail.AbsolutePosition.Y, detail.AbsolutePosition.Y + detail.AbsoluteSize.Y
	return v.AbsolutePosition.Y + v.AbsoluteSize.Y > top and v.AbsolutePosition.Y < bot
end
local function clipMount(id, n, col)
	local rec = ClipRecipes and ClipRecipes[id]
	if not rec or not ClipPlayer then
		player:SetAttribute("LabClipState", "none")
		return
	end
	if clipStepFor ~= id then clipStep, clipStepFor = nil, id end
	local shown = math.clamp(clipStep or math.max(1, n), 1, #rec.steps)
	for _, ch in ipairs(detail:GetChildren()) do
		if ch:IsA("GuiObject") and ch.LayoutOrder >= 3 then ch.LayoutOrder += 10 end
	end
	local w = math.max(detail.AbsoluteSize.X - 3.2 * S.ch - 4, 40)
	local h = math.max(math.min(w * 10 / 16, 0.38 * detail.AbsoluteSize.Y), 40)
	local box = frame(detail, "Clip", Color3.fromRGB(11, 14, 20), 0)
	box.Size = UDim2.new(1, 0, 0, math.floor(h))
	box.LayoutOrder = 3
	box.ClipsDescendants = true
	corner(box, UDim.new(0, 1.2 * S.ch))
	stroke(box, WHITE, 0.92, 1)
	local char = player.Character
	if clip and (clip.id ~= id or clip.char ~= char) then clipDrop() end
	if not clip then
		local ok, c = pcall(ClipPlayer.new, rec, {id = id, step = shown, character = char, color = col, visible = clipVisible})
		if not ok or not c then
			warn("Lab: clip " .. id .. ": " .. tostring(c))
			player:SetAttribute("LabClipState", "error")
			return
		end
		clip = {c = c, id = id, step = shown, char = char}
	elseif clip.step ~= shown then
		clip.c:setStep(shown)
		clip.step = shown
	end
	clip.parked = false
	clip.c.view.Parent = box
	local tagS = math.max(1.15 * S.ch, 7)
	local function tag(name, text, fg, bg, right)
		local t = label(box, name, Enum.Font.GothamBlack, tagS, fg, text)
		t.BackgroundColor3, t.BackgroundTransparency = bg, right and 0 or 0.2
		t.AutomaticSize = Enum.AutomaticSize.XY
		t.Size = UDim2.fromOffset(0, 0)
		t.AnchorPoint = Vector2.new(right and 1 or 0, 0)
		t.Position = right and UDim2.new(1, -0.8 * S.ch, 0, 0.8 * S.ch) or UDim2.fromOffset(0.8 * S.ch, 0.8 * S.ch)
		t.ZIndex = 6
		corner(t, UDim.new(0, 0.5 * S.ch))
		pad(t, 0.5 * S.ch, 0.5 * S.ch, 0.25 * S.ch, 0.25 * S.ch)
		return t
	end
	tag("Live", "LIVE CLIP", VOLT, Color3.fromRGB(6, 36, 47), false)
	tag("StepTag", "STEP " .. ROMAN[shown], DARK_TEXT, YELLOW, true)
	local what = label(detail, "What", Enum.Font.GothamBlack, math.max(1.75 * S.ch, 10), WHITE, rec.what)
	what.TextXAlignment = Enum.TextXAlignment.Left
	what.TextWrapped = true
	what.AutomaticSize = Enum.AutomaticSize.Y
	what.Size = UDim2.new(1, 0, 0, 0)
	what.LayoutOrder = 4
	local chips = frame(detail, "Chips")
	chips.AutomaticSize = Enum.AutomaticSize.Y
	chips.Size = UDim2.new(1, 0, 0, 0)
	chips.LayoutOrder = 5
	local cl = list(chips, Enum.FillDirection.Horizontal, 0.6 * S.ch)
	cl.Wraps = true
	local chipS = math.max(1.35 * S.ch, 8)
	local chipH = math.floor(chipS * 1.9)
	for i, c in ipairs(ClipRecipes.chips(rec, shown, n)) do
		local holder = frame(chips, "Chip" .. i)
		holder.AutomaticSize = Enum.AutomaticSize.X
		holder.Size = UDim2.fromOffset(0, chipH + math.floor(0.6 * S.ch))
		holder.LayoutOrder = i
		local up = c[3] == true
		local t = label(holder, "Text", Enum.Font.GothamBlack, chipS, up and YELLOW or GREY,
			("%s <font color=\"#%s\">%s</font>"):format(c[1], up and "FFC832" or "FFFFFF", c[2]))
		t.RichText = true
		t.BackgroundColor3 = up and Color3.fromRGB(58, 47, 10) or PANEL2
		t.BackgroundTransparency = 0
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromOffset(0, chipH)
		corner(t, UDim.new(0, 0.8 * S.ch))
		pad(t, 0.8 * S.ch, 0.8 * S.ch, 0, 0)
		if up then stroke(t, YELLOW, 0.6, 1) end
	end
	local sb = detail:FindFirstChild("Steps")
	for i = 1, 4 do
		local row = sb and sb:FindFirstChild("Step" .. i)
		if row then
			if clipStep == i then
				corner(row, UDim.new(0, 0.7 * S.ch))
				stroke(row, YELLOW, 0.4, 2)
			end
			local b = Instance.new("TextButton")
			b.Name = "Preview"
			b.Text = ""
			b.AutoButtonColor = false
			b.BackgroundTransparency = 1
			b.Size = UDim2.fromScale(1, 1)
			b.ZIndex = 3
			b.Parent = row
			b.Activated:Connect(function()
				press("clipstep:" .. i)
				if clipStep == i then clipStep = nil else clipStep = i end -- (a second tap goes back)
				clipStepFor = id
				local keep = detail.CanvasPosition -- the panel stays scrolled where it was
				if redrawDetail then redrawDetail() end
				task.defer(function() detail.CanvasPosition = keep end)
			end)
		end
	end
	player:SetAttribute("LabClipState", "playing")
	player:SetAttribute("LabClipPart", id)
	player:SetAttribute("LabClipStep", shown)
	player:SetAttribute("LabClipParts", clip.c:count())
end

-- v1.18: universal skin detail
EMO.detail = function() -- v1.19
	local EC = EMO.cat()
	local e = EMO.sel and EC.get(EMO.sel)
	if not e then
		local h = label(detail, "Empty", Enum.Font.GothamBlack, S.stepS, MUTED, "Pick an emote.")
		h.Size = UDim2.new(1, 0, 0, S.stepS * 2)
		return
	end
	local id = EMO.sel
	local st = EMO.state(id)
	local kindTxt
	if e.unlock.kind == "free" then kindTxt = "FREE"
	elseif st == "wheel" or st == "own" then kindTxt = "OWNED"
	elseif e.unlock.kind == "earn" then kindTxt = "EARN"
	else kindTxt = "R$" .. tostring(e.unlock.price) end
	local sub = label(detail, "Sub", Enum.Font.GothamBlack, S.stepS, YELLOW, "EMOTE · " .. kindTxt)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Size = UDim2.new(1, 0, 0, S.stepS * 1.2)
	sub.LayoutOrder = 1
	local ttl = label(detail, "Title", Enum.Font.FredokaOne, math.max(3 * S.ch, 15), WHITE, e.name)
	ttl.TextXAlignment = Enum.TextXAlignment.Left
	ttl.TextWrapped = true
	ttl.AutomaticSize = Enum.AutomaticSize.Y
	ttl.Size = UDim2.new(1, 0, 0, 0)
	ttl.LayoutOrder = 2
	local ws = EMO.wordStrip(detail, e.word, math.max(3.6 * S.ch, 16))
	ws.LayoutOrder = 3
	local all = label(detail, "All", Enum.Font.GothamBlack, S.stepS, GREEN, "✓ WORKS ON ALL 8 DINOS")
	all.TextXAlignment = Enum.TextXAlignment.Left
	all.Size = UDim2.new(1, 0, 0, S.stepS * 1.3)
	all.LayoutOrder = 4
	local how = e.desc
	if st == "buy" then how = e.desc .. " Unlock it once and every dino can do it."
	elseif st == "earn" then how = e.unlock.text .. "." end
	local line = label(detail, "Line", Enum.Font.GothamBlack, S.stepS, GREY, how)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextWrapped = true
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.Size = UDim2.new(1, 0, 0, 0)
	line.LayoutOrder = 5
	if st == "earn" then
		local have, need = EMO.progress(id)
		local row = frame(detail, "Progress")
		row.LayoutOrder = 6
		row.Size = UDim2.new(1, 0, 0, S.stepS * 1.4 + math.max(1.2 * S.ch, 6) + 0.6 * S.ch)
		local n = label(row, "N", Enum.Font.GothamBlack, S.stepS, GREEN, ("%d / %d"):format(have, need))
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.Size = UDim2.new(1, 0, 0, S.stepS * 1.4)
		local bar = frame(row, "Bar", Color3.fromRGB(42, 52, 70), 0)
		bar.Position, bar.Size = UDim2.new(0, 0, 0, S.stepS * 1.4 + 0.3 * S.ch), UDim2.new(1, 0, 0, math.max(1.2 * S.ch, 6))
		corner(bar, UDim.new(1, 0))
		local fill = frame(bar, "Fill", GREEN, 0)
		fill.Size = UDim2.fromScale(need > 0 and math.clamp(have / need, 0, 1) or 0, 1)
		corner(fill, UDim.new(1, 0))
	end
	-- your wheel: 8 slots on a ring
	local wheel = EMO.wheel()
	local wh = label(detail, "WheelTitle", Enum.Font.GothamBlack, S.stepS, EMO.arm and YELLOW or MUTED, EMO.arm and "TAP A SLOT" or "YOUR WHEEL")
	wh.TextXAlignment = Enum.TextXAlignment.Left
	wh.Size = UDim2.new(1, 0, 0, S.stepS * 1.3)
	wh.LayoutOrder = 7
	local ring = frame(detail, "Wheel")
	ring.LayoutOrder = 8
	ring.Size = UDim2.new(1, 0, 0, math.max(20 * S.ch, 96))
	local hub = label(ring, "Hub", Enum.Font.GothamBlack, math.max(1.2 * S.ch, 8), YELLOW, "☻")
	hub.AnchorPoint, hub.Position, hub.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.16, 0.24)
	for i = 1, 8 do
		local a = math.rad((i - 1) * 45 - 90)
		local sid = wheel[i]
		local se = sid and EC.get(sid)
		local sb = button(ring, "Slot" .. i, PANEL2, 0)
		sb.AnchorPoint = Vector2.new(0.5, 0.5)
		sb.Position = UDim2.fromScale(0.5 + 0.36 * math.cos(a), 0.5 + 0.38 * math.sin(a))
		sb.Size = UDim2.fromScale(0.24, 0.19) -- 0.24 < the 0.255 gap between neighbour slots, so no overlap at any width
		corner(sb, UDim.new(0, 0.7 * S.ch))
		if EMO.arm then stroke(sb, YELLOW, 0, 2)
		elseif sid == id then stroke(sb, ORANGE, 0, 2)
		else stroke(sb, WHITE, 0.85, 1.5) end
		local sl = label(sb, "T", Enum.Font.GothamBlack, math.max(1.15 * S.ch, 7), se and WHITE or MUTED, se and se.tag or "EMPTY")
		sl.Size = UDim2.fromScale(0.94, 0.9)
		sl.Position = UDim2.fromScale(0.03, 0.05)
		sl.TextScaled = true
		local f = Instance.new("UITextSizeConstraint")
		f.MinTextSize, f.MaxTextSize = 6, math.max(1.3 * S.ch, 9)
		f.Parent = sl
		sb.Activated:Connect(function()
			if not EMO.arm then return end
			press("emoteSlot:" .. i .. ":" .. id)
			EMO.arm = false
			local r = ReplicatedStorage:FindFirstChild("DinoEmoteRequest")
			if r then r:FireServer("equip", i, id) end
			redraw()
		end)
	end
	local b
	if st == "wheel" or st == "own" then
		if EMO.arm then
			b = detailButton(detail, "TAP A SLOT ABOVE", PANEL2, YELLOW, false, 9)
			stroke(b, YELLOW, 0, 2)
		else
			b = detailButton(detail, st == "wheel" and "MOVE ON WHEEL" or "PUT ON WHEEL", YELLOW, DARK_TEXT, true, 9)
			b.Activated:Connect(function()
				press("emotePut:" .. id)
				EMO.arm = true
				redraw()
			end)
		end
	elseif st == "buy" then
		local waiting = buyPendingAt ~= nil and os.clock() - buyPendingAt < BUY_WAIT
		local s = player:GetAttribute("EmoteSaveState")
		local ready = s ~= nil and s ~= "loading" and s ~= "loadFailed" and s ~= "noApi"
		if waiting then
			b = detailButton(detail, "…", YELLOW, DARK_TEXT, false, 9)
		elseif not ready then
			b = detailButton(detail, "LOADING", YELLOW, DARK_TEXT, false, 9)
		else
			b = detailButton(detail, "BUY · R$" .. tostring(e.unlock.price), YELLOW, DARK_TEXT, true, 9)
			b.Activated:Connect(function()
				press("emoteBuy:" .. id)
				local r = ReplicatedStorage:FindFirstChild("DinoEmoteRequest")
				if not r then return end
				buyPendingAt = os.clock()
				r:FireServer("buy", id)
				redraw()
			end)
		end
	else
		b = detailButton(detail, "LOCKED · KEEP PLAYING", PANEL2, MUTED, false, 9)
	end
	b.Size = UDim2.new(1, 0, 0, math.max(5.6 * S.ch, 34))
end
TRL.detail = function() -- v1.20
	local TC = TRL.cat()
	local id = TRL.sel or TRL.equipped()
	local t = id ~= "none" and TC.get(id) or nil
	if id ~= "none" and not t then
		local h = label(detail, "Empty", Enum.Font.GothamBlack, S.stepS, MUTED, "Pick a trail.")
		h.Size = UDim2.new(1, 0, 0, S.stepS * 2)
		return
	end
	local st = TRL.state(id)
	local kindTxt
	if id == "none" then kindTxt = st == "on" and "OFF" or "NONE"
	elseif st == "on" then kindTxt = "ON"
	elseif t.unlock.kind == "free" then kindTxt = "FREE"
	elseif st == "own" then kindTxt = "OWNED"
	elseif t.unlock.kind == "earn" then kindTxt = "EARN"
	else kindTxt = "R$" .. tostring(t.unlock.price) end
	local sub = label(detail, "Sub", Enum.Font.GothamBlack, S.stepS, YELLOW, "TRAIL · " .. kindTxt)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Size = UDim2.new(1, 0, 0, S.stepS * 1.2)
	sub.LayoutOrder = 1
	local ttl = label(detail, "Title", Enum.Font.FredokaOne, math.max(3 * S.ch, 15), WHITE, t and t.name or "No Trail")
	ttl.TextXAlignment = Enum.TextXAlignment.Left
	ttl.TextWrapped = true
	ttl.AutomaticSize = Enum.AutomaticSize.Y
	ttl.Size = UDim2.new(1, 0, 0, 0)
	ttl.LayoutOrder = 2
	local ws = TRL.strip(detail, id, math.max(2.4 * S.ch, 12))
	ws.LayoutOrder = 3
	local all = label(detail, "All", Enum.Font.GothamBlack, S.stepS, GREEN, "✓ WORKS ON ALL 8 DINOS")
	all.TextXAlignment = Enum.TextXAlignment.Left
	all.Size = UDim2.new(1, 0, 0, S.stepS * 1.3)
	all.LayoutOrder = 4
	local how = t and t.desc or "Nothing follows your dino."
	if t and st == "buy" then how = t.desc .. " Unlock it once and every dino can wear it."
	elseif t and st == "earn" then how = t.unlock.text .. "." end
	local line = label(detail, "Line", Enum.Font.GothamBlack, S.stepS, GREY, how)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextWrapped = true
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.Size = UDim2.new(1, 0, 0, 0)
	line.LayoutOrder = 5
	if t and st == "earn" then
		local have, need = TRL.progress(id)
		local row = frame(detail, "Progress")
		row.LayoutOrder = 6
		row.Size = UDim2.new(1, 0, 0, S.stepS * 1.4 + math.max(1.2 * S.ch, 6) + 0.6 * S.ch)
		local n = label(row, "N", Enum.Font.GothamBlack, S.stepS, GREEN, ("%d / %d"):format(have, need))
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.Size = UDim2.new(1, 0, 0, S.stepS * 1.4)
		local bar = frame(row, "Bar", Color3.fromRGB(42, 52, 70), 0)
		bar.Position, bar.Size = UDim2.new(0, 0, 0, S.stepS * 1.4 + 0.3 * S.ch), UDim2.new(1, 0, 0, math.max(1.2 * S.ch, 6))
		corner(bar, UDim.new(1, 0))
		local fill = frame(bar, "Fill", GREEN, 0)
		fill.Size = UDim2.fromScale(need > 0 and math.clamp(have / need, 0, 1) or 0, 1)
		corner(fill, UDim.new(1, 0))
	end
	local b
	local function equip(to)
		press("trailEquip:" .. to)
		local r = ReplicatedStorage:FindFirstChild("DinoTrailRequest")
		if r then r:FireServer("equip", to) end
	end
	if st == "on" then
		b = detailButton(detail, id == "none" and "TRAIL OFF" or "EQUIPPED", PANEL2, GREEN, false, 9)
		stroke(b, GREEN, 0, 2)
	elseif st == "own" then
		b = detailButton(detail, id == "none" and "TURN TRAIL OFF" or "EQUIP", YELLOW, DARK_TEXT, true, 9)
		b.Activated:Connect(function() equip(id) end)
	elseif st == "buy" then
		local waiting = buyPendingAt ~= nil and os.clock() - buyPendingAt < BUY_WAIT
		local s = player:GetAttribute("TrailSaveState")
		local ready = s ~= nil and s ~= "loading" and s ~= "loadFailed" and s ~= "noApi"
		if waiting then
			b = detailButton(detail, "…", YELLOW, DARK_TEXT, false, 9)
		elseif not ready then
			b = detailButton(detail, "LOADING", YELLOW, DARK_TEXT, false, 9)
		else
			b = detailButton(detail, "BUY · R$" .. tostring(t.unlock.price), YELLOW, DARK_TEXT, true, 9)
			b.Activated:Connect(function()
				press("trailBuy:" .. id)
				local r = ReplicatedStorage:FindFirstChild("DinoTrailRequest")
				if not r then return end
				buyPendingAt = os.clock()
				r:FireServer("buy", id)
				redraw()
			end)
		end
	else
		b = detailButton(detail, "LOCKED · KEEP PLAYING", PANEL2, MUTED, false, 9)
	end
	b.Size = UDim2.new(1, 0, 0, math.max(5.6 * S.ch, 34))
	local note = label(detail, "One", Enum.Font.GothamBlack, S.stepS, MUTED, "One trail for every dino you play.")
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextWrapped = true
	note.AutomaticSize = Enum.AutomaticSize.Y
	note.Size = UDim2.new(1, 0, 0, 0)
	note.LayoutOrder = 10
end
local function drawUniDetail()
	if TRL.view() then TRL.detail() return end -- v1.20
	if EMO.view() then EMO.detail() return end -- v1.19
	local US = uniMod()
	local sk = skinSel and US.get(skinSel)
	if not sk then
		local h = label(detail, "Empty", Enum.Font.GothamBlack, S.stepS, MUTED, "Pick a skin.")
		h.Size = UDim2.new(1, 0, 0, S.stepS * 2)
		return
	end
	local sp = uniStageSpecies()
	local dn = uniName(sp)
	local st = uniState(sk, sp)
	local kindTxt
	if sk.unlock.kind == "free" then kindTxt = "FREE"
	elseif st == "eq" or st == "own" then kindTxt = "OWNED"
	elseif sk.unlock.kind == "earn" then kindTxt = "EARN"
	else kindTxt = "R$" .. tostring(uniPrice(sk) or "?") end
	local sub = label(detail, "Sub", Enum.Font.GothamBlack, S.stepS, SKIN, "SKIN · " .. kindTxt .. (sk.anim and " · ANIMATED" or ""))
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Size = UDim2.new(1, 0, 0, S.stepS * 1.2)
	sub.LayoutOrder = 1
	local ttl = label(detail, "Title", Enum.Font.FredokaOne, math.max(3 * S.ch, 15), WHITE, sk.name)
	ttl.TextXAlignment = Enum.TextXAlignment.Left
	ttl.TextWrapped = true
	ttl.AutomaticSize = Enum.AutomaticSize.Y
	ttl.Size = UDim2.new(1, 0, 0, 0)
	ttl.LayoutOrder = 2
	local sw = swatchStrip(detail, sk, math.max(3.6 * S.ch, 16))
	sw.LayoutOrder = 3
	local all = label(detail, "All", Enum.Font.GothamBlack, S.stepS, GREEN, "✓ WORKS ON ALL 8 DINOS")
	all.TextXAlignment = Enum.TextXAlignment.Left
	all.Size = UDim2.new(1, 0, 0, S.stepS * 1.3)
	all.LayoutOrder = 4
	local how
	if st == "eq" then how = "Owned. Your " .. dn .. " is wearing it."
	elseif st == "own" then how = "Owned. Works on every dino."
	elseif st == "buy" then how = "Unlock it once and every dino can wear it."
	else how = sk.unlock.text .. "." end
	local line = label(detail, "Line", Enum.Font.GothamBlack, S.stepS, GREY, how)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextWrapped = true
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.Size = UDim2.new(1, 0, 0, 0)
	line.LayoutOrder = 5
	if st == "earn" then
		local have, need = US.progress(sk.id, uniStats())
		local row = frame(detail, "Progress")
		row.LayoutOrder = 6
		row.Size = UDim2.new(1, 0, 0, S.stepS * 1.4 + math.max(1.2 * S.ch, 6) + 0.6 * S.ch)
		local n = label(row, "N", Enum.Font.GothamBlack, S.stepS, GREEN, ("%d / %d"):format(have or 0, need or 0))
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.Size = UDim2.new(1, 0, 0, S.stepS * 1.4)
		local bar = frame(row, "Bar", Color3.fromRGB(42, 52, 70), 0)
		bar.Position, bar.Size = UDim2.new(0, 0, 0, S.stepS * 1.4 + 0.3 * S.ch), UDim2.new(1, 0, 0, math.max(1.2 * S.ch, 6))
		corner(bar, UDim.new(1, 0))
		local fill = frame(bar, "Fill", GREEN, 0)
		fill.Size = UDim2.fromScale(need and need > 0 and math.clamp((have or 0) / need, 0, 1) or 0, 1)
		corner(fill, UDim.new(1, 0))
	end
	local wear = {}
	for _, d in ipairs(US.DINOS) do
		if uniEquipped(d) == sk.id then table.insert(wear, uniName(d)) end
	end
	local w = label(detail, "Wear", Enum.Font.GothamBlack, S.hintS, MUTED,
		#wear > 0 and ("Wearing it now: " .. table.concat(wear, ", ")) or "No dino is wearing it yet.")
	w.TextXAlignment = Enum.TextXAlignment.Left
	w.TextWrapped = true
	w.AutomaticSize = Enum.AutomaticSize.Y
	w.Size = UDim2.new(1, 0, 0, 0)
	w.LayoutOrder = 7
	local dark = Color3.fromRGB(6, 32, 20)
	local b
	if st == "eq" then
		b = detailButton(detail, "EQUIPPED ON " .. dn, PANEL2, GREEN, false, 8)
		stroke(b, GREEN, 0, 2)
	elseif st == "own" then
		b = detailButton(detail, "EQUIP ON " .. dn, GREEN, dark, true, 8)
		b.Activated:Connect(function()
			press("skinEquip:" .. sk.id .. ":" .. sp)
			local r = ReplicatedStorage:FindFirstChild("DinoSkinRequest")
			if r then r:FireServer("equipFor", sk.id, sp) end
		end)
	elseif st == "buy" then
		local credits = tonumber(player:GetAttribute("SkinCredits_" .. tostring(sk.unlock.rarity))) or 0
		local waiting = buyPendingAt ~= nil and os.clock() - buyPendingAt < BUY_WAIT
		local state
		if waiting then
			state = "wait"
			b = detailButton(detail, "…", YELLOW, DARK_TEXT, false, 8)
		elseif not skinSaveReady() then
			state = "loading"
			b = detailButton(detail, "LOADING", YELLOW, DARK_TEXT, false, 8)
		elseif credits > 0 then
			state = "credit"
			b = detailButton(detail, "UNLOCK · 1 CREDIT", YELLOW, DARK_TEXT, true, 8)
		else
			state = "get"
			b = detailButton(detail, (L3.sortOn and L3.sortOn() and "BUY · R$" or "GET · R$") .. tostring(uniPrice(sk) or "?"), YELLOW, DARK_TEXT, true, 8) -- v2.1: BUY
		end
		player:SetAttribute("LabSkinBuy", state)
		if state == "credit" or state == "get" then
			b.Activated:Connect(function()
				press("skinBuy:" .. sk.id)
				local r = ReplicatedStorage:FindFirstChild("DinoSkinRequest")
				if not r then return end
				buyPendingAt = os.clock()
				r:FireServer("buy", sk.id, sp)
				redraw()
			end)
		end
	else
		b = detailButton(detail, "LOCKED · KEEP PLAYING", PANEL2, MUTED, false, 8)
	end
	b.Size = UDim2.new(1, 0, 0, math.max(5.6 * S.ch, 34))
end

local function drawDetail()
	clipPark() -- v1.15
	for _, ch in ipairs(detail:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	detailPad.PaddingLeft, detailPad.PaddingRight = UDim.new(0, 1.6 * S.ch), UDim.new(0, 1.6 * S.ch)
	detailPad.PaddingTop, detailPad.PaddingBottom = UDim.new(0, 1.6 * S.ch), UDim.new(0, 1.6 * S.ch)
	detailList.Padding = UDim.new(0, S.ch)
	if tab == "skins" and useUni() then drawUniDetail() return end -- v1.18
	if tab == "skins" then -- v1.6: the selected skin
		local cat = skinCatalog()
		local sk = cat and skinSel and cat.get(species(), skinSel)
		if not sk then
			local h = label(detail, "Empty", Enum.Font.GothamBlack, S.stepS, MUTED, "Pick a skin.")
			h.Size = UDim2.new(1, 0, 0, S.stepS * 2)
			return
		end
		local rc = RARITY_COLOR[sk.rarity] or GREY
		local sub = label(detail, "Sub", Enum.Font.GothamBlack, S.stepS, rc, ("%s SKIN · %s"):format(DINO_NAMES[species()] or string.upper(species()), sk.rarity))
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Size = UDim2.new(1, 0, 0, S.stepS * 1.2)
		sub.LayoutOrder = 1
		local ttl = label(detail, "Title", Enum.Font.FredokaOne, math.max(3 * S.ch, 15), WHITE, sk.name)
		ttl.TextXAlignment = Enum.TextXAlignment.Left
		ttl.TextWrapped = true
		ttl.AutomaticSize = Enum.AutomaticSize.Y
		ttl.Size = UDim2.new(1, 0, 0, 0)
		ttl.LayoutOrder = 2
		local chips = frame(detail, "Colors")
		chips.LayoutOrder = 3
		chips.Size = UDim2.new(1, 0, 0, 3.6 * S.ch)
		local cl = list(chips, Enum.FillDirection.Horizontal, 0.6 * S.ch)
		cl.Wraps = true
		local roles = {}
		for role in pairs(sk.colors) do table.insert(roles, role) end
		table.sort(roles)
		for _, role in ipairs(roles) do
			local sw = frame(chips, "C_" .. role, Color3.fromHex(sk.colors[role]), 0)
			sw.Size = UDim2.fromOffset(3.6 * S.ch, 3.6 * S.ch)
			corner(sw, UDim.new(0, 0.8 * S.ch))
			stroke(sw, WHITE, 0.8, 1.5)
		end
		local owned = cat.owns(species(), sk.id, ownedSet()) -- v1.7
		local eq = equippedSkin() == sk.id
		local lockedLine = skinBuyOn and "Buy it once, keep it for good." or "Locked." -- v1.7
		local line = label(detail, "Line", Enum.Font.GothamBlack, S.stepS, GREY, owned and "Owned. Equip it and you spawn in it every time." or lockedLine)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextWrapped = true
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.Size = UDim2.new(1, 0, 0, 0)
		line.LayoutOrder = 4
		local btnH = math.max(5.6 * S.ch, 34)
		local b
		if not owned and skinBuyOn then -- v1.7
			local credits = tonumber(player:GetAttribute("SkinCredits_" .. tostring(sk.rarity))) or 0
			local hasProduct = cat.productFor and cat.productFor(species(), sk.id) ~= nil
			local waiting = buyPendingAt ~= nil and os.clock() - buyPendingAt < BUY_WAIT
			local state
			if waiting then
				state = "wait"
				b = detailButton(detail, "…", ROBUX, WHITE, false, 5)
			elseif not skinSaveReady() then
				state = "loading"
				b = detailButton(detail, "LOADING", ROBUX, WHITE, false, 5)
			elseif credits > 0 then
				state = "credit"
				b = detailButton(detail, "UNLOCK · 1 CREDIT", ROBUX, WHITE, true, 5)
			elseif not hasProduct then
				state = "soon"
				b = detailButton(detail, "SOON", ROBUX, WHITE, false, 5)
			else
				state = "get"
				b = detailButton(detail, ("GET · R$%s"):format(tostring(skinPrice(sk) or "?")), ROBUX, WHITE, true, 5)
			end
			player:SetAttribute("LabSkinBuy", state)
			if state == "credit" or state == "get" then
				b.Activated:Connect(function()
					press("skinBuy:" .. sk.id)
					local r = ReplicatedStorage:FindFirstChild("DinoSkinRequest")
					if not r then return end
					buyPendingAt = os.clock()
					r:FireServer("buy", sk.id)
					redraw()
				end)
			end
		elseif not owned then
			b = detailButton(detail, ("GET · R$%s"):format(tostring(sk.price or "?")), ROBUX, WHITE, false, 5)
		elseif eq then
			b = detailButton(detail, "EQUIPPED", PANEL2, MUTED, false, 5)
		else
			b = detailButton(detail, "EQUIP", SKIN, Color3.fromRGB(26, 16, 48), true, 5)
			b.Activated:Connect(function()
				press("skinEquip:" .. sk.id)
				local r = ReplicatedStorage:FindFirstChild("DinoSkinRequest")
				if r then r:FireServer("equip", sk.id) end
			end)
		end
		b.Size = UDim2.new(1, 0, 0, btnH)
		if not owned and not skinBuyOn then -- v1.7: 1.6 hint only with buying off
			local h = label(detail, "Hint", Enum.Font.GothamBlack, S.hintS, MUTED, "Buying comes in the next step.")
			h.TextXAlignment = Enum.TextXAlignment.Left
			h.TextWrapped = true
			h.AutomaticSize = Enum.AutomaticSize.Y
			h.Size = UDim2.new(1, 0, 0, 0)
			h.LayoutOrder = 6
		end
		return
	end
	local id = selected
	local p = id and ST.PATHS[id]
	if not p then
		local h = label(detail, "Empty", Enum.Font.GothamBlack, S.stepS, MUTED, "Pick a card to see its steps.")
		h.Size = UDim2.new(1, 0, 0, S.stepS * 2)
		return
	end
	local area = areaOf(id)
	local col = rgb(area.color)
	local n = stepsOf(id)
	local kind = p.mech ~= true and "Stat" or (ST.BUTTONS[id] == true and (splitTabs and "Mecha ability · button" or "Mech part · button") or "Mech part · always on") -- v1.2 wording
	local sub = label(detail, "Sub", Enum.Font.GothamBlack, S.stepS, col, string.upper(area.name .. " · " .. kind))
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Size = UDim2.new(1, 0, 0, S.stepS * 1.2)
	sub.LayoutOrder = 1
	local ttl = label(detail, "Title", Enum.Font.FredokaOne, math.max(3 * S.ch, 15), WHITE, pathName(p))
	ttl.TextXAlignment = Enum.TextXAlignment.Left
	ttl.TextWrapped = true
	ttl.AutomaticSize = Enum.AutomaticSize.Y
	ttl.Size = UDim2.new(1, 0, 0, 0)
	ttl.LayoutOrder = 2
	local stepsBox = frame(detail, "Steps")
	stepsBox.AutomaticSize = Enum.AutomaticSize.Y
	stepsBox.Size = UDim2.new(1, 0, 0, 0)
	stepsBox.LayoutOrder = 3
	list(stepsBox, Enum.FillDirection.Vertical, math.max(0.9 * S.ch, 5))
	for i = 1, 4 do
		local row = frame(stepsBox, "Step" .. i)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = i
		local bw = math.max(3.4 * S.ch, 20)
		local bd = label(row, "N", Enum.Font.GothamBlack, math.max(1.7 * S.ch, 10), MUTED, ROMAN[i])
		bd.BackgroundTransparency = 0.9
		bd.BackgroundColor3 = WHITE
		bd.Size = UDim2.fromOffset(bw, math.max(3 * S.ch, 18))
		corner(bd, UDim.new(0, 0.7 * S.ch))
		local tx = label(row, "Text", Enum.Font.GothamBold, S.stepS, MUTED, stepText(p, i))
		tx.TextXAlignment = Enum.TextXAlignment.Left
		tx.TextYAlignment = Enum.TextYAlignment.Top
		tx.TextWrapped = true
		tx.AutomaticSize = Enum.AutomaticSize.Y
		tx.Position = UDim2.fromOffset(bw + 0.8 * S.ch, 0)
		tx.Size = UDim2.new(1, -(bw + 0.8 * S.ch), 0, math.max(3 * S.ch, 18))
		-- first line centred on the badge; wrapped lines run on below it
		pad(tx, 0, 0, math.max((math.max(3 * S.ch, 18) - S.stepS * 1.15) / 2, 0), 0)
		if i <= n then
			bd.BackgroundColor3, bd.BackgroundTransparency, bd.TextColor3 = col, 0, DARK_TEXT
			tx.TextColor3 = GREY
		elseif i == n + 1 then
			stroke(bd, WHITE, 0, 2)
			bd.TextColor3 = WHITE
			tx.TextColor3 = WHITE
		end
	end
	-- buttons
	local acts = frame(detail, "Actions")
	acts.Size = UDim2.new(1, 0, 0, S.btnH)
	acts.LayoutOrder = 4
	-- v1.4: the given test parts (SkillTestParts) are left out of the points / mastery counts, as SkillServer 1.7 does
	local judge = allSteps()
	local givenIds = player:GetAttribute("SkillTestParts")
	local isGiven = false
	if type(givenIds) == "string" and givenIds ~= "" and script:GetAttribute("LabTestFreeGivenEnabled") ~= false then
		for gid in string.gmatch(givenIds, "[^,]+") do
			if gid == id then isGiven = true end
			judge[gid] = 0
		end
	end
	local ok, why = ST.canBuy(judge, id, tonumber(player:GetAttribute("SkillPoints")) or 0, species())
	if isGiven then ok, why = false, "maxed" end
	local buyText
	if ok then
		local cost = ST.COST[n + 1]
		buyText = ("%s · %d PT%s"):format(n == 0 and "BUY" or "UPGRADE", cost, cost > 1 and "S" or "")
	elseif why == "maxed" then
		buyText = "MAXED"
	elseif why == "masteryFull" then
		buyText = "MASTERY FULL"
	elseif why == "noPoints" then
		buyText = ("NEED %d %s"):format(ST.COST[n + 1] or 0, ST.COST[n + 1] == 1 and "PT" or "PTS")
	elseif why == "soon" then
		buyText = "COMING SOON"
	else
		buyText = "LOCKED"
	end
	local eqBtn = nil
	local eqIdx = slotIndex(id)
	local showEquip = ST.BUTTONS[id] == true and not p.soon and n >= 1
	local gap = S.ch
	local buy = detailButton(acts, buyText, ok and YELLOW or PANEL, ok and DARK_TEXT or WHITE, ok, 1)
	if showEquip then
		buy.Size = UDim2.new(0.5, -gap / 2, 1, 0)
		if eqIdx then
			eqBtn = detailButton(acts, "TAKE OFF " .. (SLOT_KEYS[eqIdx] or tostring(eqIdx)), PANEL, WHITE, true, 2) -- v2.0 (1.x: UNEQUIP)
		else
			eqBtn = detailButton(acts, "EQUIP", ORANGE, DARK_TEXT, true, 2)
		end
		eqBtn.Position = UDim2.new(0.5, gap / 2, 0, 0)
		eqBtn.Size = UDim2.new(0.5, -gap / 2, 1, 0)
	else
		buy.Size = UDim2.fromScale(1, 1)
	end
	if not ok then stroke(buy, WHITE, 0.84, 2) end
	if eqBtn and eqIdx then stroke(eqBtn, WHITE, 0.84, 2) end
	buy.Activated:Connect(function()
		if not ok then return end
		press("buy:" .. id)
		remote:FireServer("buy", id)
		showToast(("%s %s"):format(pathName(p), ROMAN[n + 1]))
	end)
	if eqBtn then
		eqBtn.Activated:Connect(function()
			if eqIdx then
				press("unequip:" .. id)
				remote:FireServer("slot", eqIdx, "")
				showToast(string.upper(pathName(p)) .. " OFF") -- v2.0
			else
				local target = slotSel
				if not target then
					for k = 1, ST.SLOTS do
						if not slotOf(k) then target = k break end
					end
				end
				if target then
					equip(id, target)
				else
					press("full")
					pulseUntil = os.clock() + 2
					showToast("SLOTS FULL · TAP A SLOT TO SWAP") -- v2.0
					drawSlots()
					task.delay(2.05, function() if mode then drawSlots() end end)
				end
			end
		end)
	end
	if showEquip and not eqIdx then
		local h = label(detail, "Hint", Enum.Font.GothamBlack, S.hintS, MUTED, "EQUIP fills the first empty slot, or tap a slot first to replace it.")
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.TextWrapped = true
		h.AutomaticSize = Enum.AutomaticSize.Y
		h.Size = UDim2.new(1, 0, 0, 0)
		h.LayoutOrder = 5
	end
	if script:GetAttribute("LabClipEnabled") ~= false then clipMount(id, n, col) end -- v1.15
	if L2.reorderDetail then L2.reorderDetail() end -- v2.0
end
redrawDetail = drawDetail -- v1.15

local function drawBar()
	local dino = species()
	nameL.Text = ('<font color="#7fe9ff" size="%d">LAB</font>  %s'):format(math.floor(S.nameS * 0.55), DINO_NAMES[dino] or string.upper(dino))
	lvL.Text = "LV " .. tostring(player:GetAttribute("SkillLevel") or 1)
	local into, nxt = tonumber(player:GetAttribute("SkillXPInto")) or 0, tonumber(player:GetAttribute("SkillXPNext")) or 0
	xpFill.Size = UDim2.fromScale(nxt > 0 and math.clamp(into / nxt, 0, 1) or 1, 1)
	local mastered = ST.mastered and #ST.mastered(allSteps(), dino) or 0
	masL.Text = ("MASTERY %d/%d"):format(mastered, ST.MASTERY_MAX or 3)
	ptsL.Text = ("%d PTS"):format(tonumber(player:GetAttribute("SkillLeft")) or 0)
end

local function layout()
	measure()
	local ch, cw = S.ch, S.cw
	box.Position, box.Size = UDim2.fromOffset(S.bx, S.by), UDim2.fromOffset(S.bw, S.bh)
	-- bar
	bar.Size = UDim2.new(1, 0, 0, S.barH)
	barLine.Position, barLine.Size = UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, math.max(0.35 * ch, 2))
	barLeft.Position = UDim2.fromOffset(S.barLeftPad, 1.4 * ch)
	barLeft.Size = UDim2.new(1, -S.barLeftPad - 2 * cw, 0, S.barH - 2.6 * ch)
	barLeftList.Padding = UDim.new(0, 1.6 * ch)
	nameL.TextSize = S.nameS
	nameL.Size = UDim2.fromOffset(0, S.barH - 2.6 * ch)
	lvL.TextSize, lvL.Size = S.small, UDim2.fromOffset(0, S.barH - 2.6 * ch)
	xpBack.Size = UDim2.fromOffset(12 * cw, math.max(1.4 * ch, 6))
	masL.TextSize = math.max(1.7 * ch, 10)
	masL.Size = UDim2.fromOffset(0, math.max(1.7 * ch, 10) + 1.4 * ch)
	masCorner.CornerRadius = UDim.new(0, ch)
	masPad.PaddingLeft, masPad.PaddingRight = UDim.new(0, 1.2 * ch), UDim.new(0, 1.2 * ch)
	barRight.Position = UDim2.new(1, -2 * cw, 0, 1.4 * ch)
	barRight.Size = UDim2.fromOffset(40 * cw, S.barH - 2.6 * ch)
	barRightList.Padding = UDim.new(0, 1.6 * ch)
	ptsL.TextSize = math.max(2.4 * ch, 13)
	ptsL.Size = UDim2.fromOffset(0, math.max(2.4 * ch, 13) + 1.6 * ch)
	ptsCorner.CornerRadius = UDim.new(0, ch)
	ptsPad.PaddingLeft, ptsPad.PaddingRight = UDim.new(0, 1.4 * ch), UDim.new(0, 1.4 * ch)
	closeB.Size = UDim2.fromOffset(S.closeS, S.closeS)
	closeCorner.CornerRadius = UDim.new(0, 1.6 * ch)
	closeX.TextSize = math.max(2.4 * ch, 14)
	L2.layoutBody() -- v2.0: body, columns, tabs, list, sheet, LOOKS, toast (Lab Revamp v1.0)
	-- compact vs full look
	if mode == "compact" and (not S.L or S.L.inset) then -- v2.0: the island Lab on touch is full screen
		root.BackgroundTransparency = 0.55
		boxCorner.CornerRadius = UDim.new(0, 2.4 * ch)
		boxStroke.Transparency = 0.7
	else
		root.BackgroundTransparency = 1
		boxCorner.CornerRadius = UDim.new(0, 0)
		boxStroke.Transparency = 1
	end
end

-- ---------- v2.0: Lab Revamp v1.0 (slots first; see the header) ----------
function L2.layoutBody()
	local L, ch = S.L, S.ch
	local looks = tab == "skins"
	body.Position, body.Size = UDim2.fromOffset(L.body.x, L.body.y), UDim2.fromOffset(L.body.w, L.body.h)
	local lw, rw, bh = L.left.w, L.right.w, L.body.h
	-- the old middle frame (stage + slots) is the left column; the old left frame (tabs + list) is the right column
	mid.Position, mid.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(lw, bh)
	left.Position, left.Size = UDim2.fromOffset(L.right.x, 0), UDim2.fromOffset(rw, bh)
	-- tabs
	if not L2.tabEmotes then
		for _, k in ipairs({"Emotes", "Trails"}) do
			local t = button(tabs, k, WHITE, 0.94)
			t.Visible = false
			local c = corner(t)
			local st = stroke(t, SKIN, 1, 2)
			local l = label(t, "T", Enum.Font.GothamBlack, 11, MUTED, string.upper(k))
			L2["tab" .. k] = {b = t, c = c, st = st, l = l}
			t.Activated:Connect(function() L2.openLooks(string.lower(k)) end)
		end
	end
	local full = skinsOn and mode == "full"
	local view = EMO.on() and EMO.looks or "skins"
	local tl = {{tabParts, tabCorners[1], tabStrokes[1], tabLabels[1], "ABILITIES", tab == "parts", VOLT},
		{tabStats, tabCorners[2], tabStrokes[2], tabLabels[2], "STATS", tab == "stats", VOLT}}
	if script:GetAttribute("LabHideStatsEnabled") ~= false and player:GetAttribute("SkillAllStatsMax") == true then -- v2.3
		table.remove(tl, 2)
		tabStats.Visible = false
		if tab == "stats" then tab = "parts" end
	else
		tabStats.Visible = true
	end
	if full then
		table.insert(tl, {tabSkins, tabSkinsCorner, tabSkinsStroke, tabSkinsLabel, "SKINS", looks and view == "skins", SKIN})
		if EMO.on() then table.insert(tl, {L2.tabEmotes.b, L2.tabEmotes.c, L2.tabEmotes.st, L2.tabEmotes.l, "EMOTES", looks and view == "emotes", SKIN}) end
		if TRL.on() then table.insert(tl, {L2.tabTrails.b, L2.tabTrails.c, L2.tabTrails.st, L2.tabTrails.l, "TRAILS", looks and view == "trails", SKIN}) end
	end
	tabSkins.Visible = full
	L2.tabEmotes.b.Visible = full and EMO.on()
	L2.tabTrails.b.Visible = full and TRL.on()
	local n = #tl
	local tw = (rw - (n - 1) * L.tabGap) / n
	tabs.Position, tabs.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(rw, L.tabs.h)
	for i, t in ipairs(tl) do
		local b, c, st, l, text, on, col = t[1], t[2], t[3], t[4], t[5], t[6], t[7]
		b.Position, b.Size = UDim2.fromOffset((i - 1) * (tw + L.tabGap), 0), UDim2.fromOffset(tw, L.tabs.h)
		c.CornerRadius = UDim.new(0, ch)
		l.Text = text
		l.TextScaled = true
		local fit = l:FindFirstChild("Fit") or Instance.new("UITextSizeConstraint")
		fit.Name = "Fit"
		fit.MinTextSize, fit.MaxTextSize = math.min(10, L.text.tab), L.text.tab
		fit.Parent = l
		l.Position, l.Size = UDim2.fromOffset(0.5 * ch, 0), UDim2.new(1, -ch, 1, 0)
		st.Color = col
		st.Transparency = on and 0 or 1
		l.TextColor3 = on and WHITE or MUTED
		b.BackgroundColor3 = on and col or WHITE
		b.BackgroundTransparency = on and 0.86 or 0.94
	end
	-- left column: stage + slot row (+ SAVE)
	stage.Position, stage.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(lw, looks and bh or L.stage.h)
	stageCorner.CornerRadius = UDim.new(0, 1.6 * ch)
	stageTag.TextSize = L.text.tag
	stageTag.Position = UDim2.fromOffset(1.2 * ch, 1.2 * ch)
	stageTag.Size = UDim2.fromOffset(0, L.text.tag + 1.2 * ch)
	stageTagCorner.CornerRadius = UDim.new(0, 0.8 * ch)
	stageTagPad.PaddingLeft, stageTagPad.PaddingRight = UDim.new(0, ch), UDim.new(0, ch)
	hint.Visible = false
	slotsRow.Visible = not looks
	slotsRow.Position, slotsRow.Size = UDim2.fromOffset(0, L.slotRow.y), UDim2.fromOffset(lw, L.slotRow.h)
	local sw, sg, sh = L.slotW, L.slotGap, L.slotRow.h
	if saveOn() then
		saveTile.Position, saveTile.Size = UDim2.fromOffset(4 * (sw + sg), 0), UDim2.fromOffset(L.saveW, sh)
		saveCorner.CornerRadius = UDim.new(0, 1.2 * ch)
		local tS, sS = L.text.btn, L.text.hint
		saveTop.UITextSizeConstraint.MaxTextSize, saveSub.UITextSizeConstraint.MaxTextSize = tS, sS
		saveTop.UITextSizeConstraint.MinTextSize, saveSub.UITextSizeConstraint.MinTextSize = 9, 8
		local subH = (L.saveW < 80 and 2 or 1) * sS * 1.1 -- a narrow tile (phone) wraps "FOR PRE-GAME" on 2 lines
		local y0 = (sh - tS - subH - 0.4 * ch) / 2
		saveSub.TextWrapped = true
		saveTop.Position, saveTop.Size = UDim2.fromOffset(0.3 * ch, y0), UDim2.new(1, -0.6 * ch, 0, tS + 2)
		saveSub.Position, saveSub.Size = UDim2.fromOffset(0.3 * ch, y0 + tS + 0.4 * ch), UDim2.new(1, -0.6 * ch, 0, subH + 2)
		drawSave()
	else
		saveTile.Visible = false
	end
	for i, s in ipairs(slotBtns) do
		s.b.Position, s.b.Size = UDim2.fromOffset((i - 1) * (sw + sg), 0), UDim2.fromOffset(sw, sh)
		s.corner.CornerRadius = UDim.new(0, 1.2 * ch)
		local kS = L.text.key
		s.key.TextSize = kS
		s.key.TextXAlignment = Enum.TextXAlignment.Center
		s.key.Position, s.key.Size = UDim2.fromOffset(0, 0.5 * ch), UDim2.fromOffset(sw, kS * 1.15)
		s.name.Visible = true
		s.name.TextXAlignment = Enum.TextXAlignment.Center
		s.name.Position = UDim2.fromOffset(0.3 * ch, 0.5 * ch + kS * 1.15)
		s.name.Size = UDim2.fromOffset(sw - 0.6 * ch, math.max(sh - kS * 1.15 - ch, 8))
		s.name.Fit.MinTextSize, s.name.Fit.MaxTextSize = 9, L.text.small
		-- a filled slot shows the part's name when the slot is >= LabSlotNameW px wide, else its 3D model under the key (L2.slotLook)
		L2.slotNames = sw >= (tonumber(script:GetAttribute("LabSlotNameW")) or 90)
		local iz = math.max(math.min(sh - kS * 1.15 - ch, sw - 0.8 * ch), 8)
		s.icon.Position, s.icon.Size = UDim2.fromOffset((sw - iz) / 2, 0.5 * ch + kS * 1.15), UDim2.fromOffset(iz, iz)
	end
	-- right column: head line (ABILITIES)
	if not L2.head then
		L2.head = label(left, "Head", Enum.Font.GothamBlack, 11, MUTED, "")
		L2.head.TextXAlignment = Enum.TextXAlignment.Left
		L2.head.TextTruncate = Enum.TextTruncate.AtEnd
		L2.cancel = button(left, "Cancel", PANEL2, 0)
		L2.cancelC = corner(L2.cancel)
		stroke(L2.cancel, WHITE, 0.8, 2)
		local cl = label(L2.cancel, "T", Enum.Font.GothamBlack, 11, GREY, "CANCEL")
		cl.Size = UDim2.fromScale(1, 1)
		L2.cancel.Activated:Connect(function() press("cancelSlot") slotSel = nil L3.wslot = nil redraw() end) -- v2.1: + the wheel section
	end
	local parts = tab == "parts"
	local sel = parts and slotSel ~= nil
	L2.head.Visible, L2.cancel.Visible = parts, sel
	L2.head.TextSize = L.text.hdr
	local cancelW = sel and math.max(10 * ch, 96) or 0
	L2.head.Position, L2.head.Size = UDim2.fromOffset(0, L.head.y), UDim2.fromOffset(rw - cancelW - (sel and ch or 0), L.head.h)
	L2.cancel.Position, L2.cancel.Size = UDim2.fromOffset(rw - cancelW, L.head.y), UDim2.fromOffset(cancelW, L.head.h)
	L2.cancelC.CornerRadius = UDim.new(0, ch)
	L2.cancel.T.TextSize = L.text.hdr
	if sel then
		L2.head.Text, L2.head.TextColor3 = "PICK A PART FOR SLOT " .. (SLOT_KEYS[slotSel] or tostring(slotSel)), YELLOW
	else
		local empty = false
		for k = 1, ST.SLOTS do if not slotOf(k) then empty = true end end
		L2.head.Text = empty and "TAP A SLOT ON THE LEFT, OR EQUIP A PART BELOW" or "TAP A SLOT TO SWAP ITS PART"
		L2.head.TextColor3 = MUTED
	end
	-- list
	gridList.Padding = UDim.new(0, ch)
	if parts then
		grid.Position, grid.Size = UDim2.fromOffset(0, L.list.y), UDim2.fromOffset(rw, L.list.h)
		gridLayout.CellSize = UDim2.fromOffset(L.cardW, L.cardH)
		gridLayout.CellPadding = UDim2.fromOffset(L.cardGap, L.cardGap)
	elseif not looks or not uniTab() then -- STATS (and the old per-dino SKINS tab)
		grid.Position, grid.Size = UDim2.fromOffset(0, L.listPlain.y), UDim2.fromOffset(rw, L.listPlain.h)
		S.rowW, S.rowH = L.rowW, L.rowH
		S.cellW = (rw - ch - 12) / 2
		local artH = (S.cellW - 2 * ch) * 0.75
		S.cardCell = UDim2.fromOffset(S.cellW, ch + artH + 0.6 * ch + S.cardName * 1.15 + 0.6 * ch + S.metaH + ch)
		gridLayout.CellSize = S.cardCell
		gridLayout.CellPadding = UDim2.fromOffset(ch, ch)
	end
	if looks and uniTab() then
		uniBuild()
		uniFilterRow.Visible = true
		uniFilterRow.Position, uniFilterRow.Size = UDim2.fromOffset(L.looksChips.x, L.looksChips.y), UDim2.fromOffset(L.looksChips.w, L.chipH)
		uniFilterRow:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, L.chipGap)
		local cw4 = (L.looksChips.w - 3 * L.chipGap) / 4
		for k, f in pairs(uniFilterBtns) do
			local on = uniFilter == k
			f.b.AutomaticSize = Enum.AutomaticSize.None
			f.b.Size = UDim2.fromOffset(cw4, L.chipH)
			f.b.BackgroundColor3 = on and SKIN or PANEL2
			f.c.CornerRadius = UDim.new(0, ch)
			f.l.AutomaticSize = Enum.AutomaticSize.None
			f.l.Position, f.l.Size = UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1)
			f.l.TextScaled = true
			local fit = f.l:FindFirstChild("Fit") or Instance.new("UITextSizeConstraint")
			fit.Name = "Fit"
			fit.MinTextSize, fit.MaxTextSize = math.min(10, L.text.tab), L.text.tab
			fit.Parent = f.l
			f.l.TextColor3 = on and Color3.fromRGB(26, 16, 48) or MUTED
			f.pd.PaddingLeft, f.pd.PaddingRight = UDim.new(0, 0.3 * ch), UDim.new(0, 0.3 * ch)
		end
		for _, f in pairs(EMO.lookBtns) do f.b.Visible = false end
		grid.Position, grid.Size = UDim2.fromOffset(L.looksGrid.x, L.looksGrid.y), UDim2.fromOffset(L.looksGrid.w, L.looksGrid.h)
		S.uniCellW = L.cellW
		gridLayout.CellSize = UDim2.fromOffset(L.cellW, L.cellH)
		gridLayout.CellPadding = UDim2.fromOffset(ch, ch)
		-- dino strip: 2 rows of 4 at the bottom of the stage
		uniStrip.Visible = true
		local g = 0.6 * ch
		local nB = #uniStripBtns
		local perRow = math.ceil(nB / 2)
		local bwS = (lw - 2 * ch - g * (perRow - 1)) / perRow
		local sH = L.stripH
		local rows = math.ceil(nB / perRow)
		local stripH = rows * sH + (rows - 1) * g
		uniStrip.Position, uniStrip.Size = UDim2.new(0, ch, 1, -ch - stripH), UDim2.new(1, -2 * ch, 0, stripH)
		local shown = uniStageSpecies()
		for i, s in ipairs(uniStripBtns) do
			local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
			s.b.Position, s.b.Size = UDim2.fromOffset(col * (bwS + g), row * (sH + g)), UDim2.fromOffset(bwS, sH)
			s.c.CornerRadius = UDim.new(0, 0.8 * ch)
			s.fit.MinTextSize, s.fit.MaxTextSize = 8, L.text.tab
			local on = s.sp == shown
			s.b.BackgroundColor3 = on and YELLOW or PANEL
			s.b.BackgroundTransparency = on and 0 or 0.15
			s.l.TextColor3 = on and DARK_TEXT or GREY
			s.st.Color = s.sp == species() and GREEN or WHITE
			s.st.Transparency = s.sp == species() and 0 or 0.8
		end
	else
		if uniFilterRow then uniFilterRow.Visible = false end
		if uniStrip then uniStrip.Visible = false end
	end
	-- detail: a sheet over the list (ABILITIES / STATS) or beside the grid (LOOKS)
	if not L2.back then
		L2.back = button(right, "Back", PANEL2, 0)
		L2.backC = corner(L2.back)
		stroke(L2.back, WHITE, 0.8, 2)
		local bl = label(L2.back, "T", Enum.Font.GothamBlack, 12, WHITE, "< BACK")
		bl.Size = UDim2.fromScale(1, 1)
		L2.back.Activated:Connect(function() press("sheetBack") L2.sheet = false redraw() end)
		right.ZIndex = 5
		right.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	end
	if looks then
		right.Visible = true
		right.BackgroundTransparency = 1
		right.Position = UDim2.fromOffset(L.right.x + L.looksDetail.x, L.looksDetail.y)
		right.Size = UDim2.fromOffset(L.looksDetail.w, L.looksDetail.h)
		L2.back.Visible = false
		detail.Position, detail.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(L.looksDetail.w, L.looksDetail.h)
	else
		right.Visible = L2.sheet == true
		right.BackgroundTransparency = 0
		right.Position, right.Size = UDim2.fromOffset(L.right.x, L.sheet.y), UDim2.fromOffset(rw, L.sheet.h)
		L2.back.Visible = true
		L2.back.Position, L2.back.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(math.max(12 * ch, 110), L.backH)
		L2.backC.CornerRadius = UDim.new(0, ch)
		L2.back.T.TextSize = L.text.btn
		local dy = L.backH + 0.6 * ch
		detail.Position, detail.Size = UDim2.fromOffset(0, dy), UDim2.fromOffset(rw, L.sheet.h - dy)
	end
	detailCorner.CornerRadius = UDim.new(0, 1.6 * ch)
	-- toast
	toast.TextSize = L.text.btn
	toast.Position = UDim2.new(0.5, 0, 1, -3 * ch)
	toast.Size = UDim2.fromOffset(0, L.text.btn + 2.4 * ch)
	toastCorner.CornerRadius = UDim.new(0, 1.6 * ch)
	toastPad.PaddingLeft, toastPad.PaddingRight = UDim.new(0, 2.4 * ch), UDim.new(0, 2.4 * ch)
	L2.layoutTips()
	if L3.layout then L3.layout() end -- v2.1
end

function L2.openLooks(kind)
	if not (skinsOn and mode == "full") then return end
	press("tab:" .. kind)
	tab = "skins"
	slotSel = nil
	L2.sheet = false
	EMO.looks = kind
	EMO.arm = false
	skinSel = equippedSkin()
	if useUni() then skinSel = uniEquipped(species()) uniView = nil end
	redraw()
end

function L2.slotLook()
	for n, s in ipairs(slotBtns) do
		local on = slotSel == n
		s.b.BackgroundColor3 = on and Color3.fromRGB(58, 47, 10) or WHITE
		s.b.BackgroundTransparency = on and 0 or 0.94
		s.key.TextColor3 = slotOf(n) and ORANGE or (on and YELLOW or MUTED)
		local filled = slotOf(n) ~= nil
		s.name.Visible = (not filled) or L2.slotNames == true
		s.icon.Visible = filled and L2.slotNames ~= true
	end
end

function L2.buyState(id) -- the BUY / UPGRADE label (the detail's 1.4 rules)
	local n = stepsOf(id)
	local judge = allSteps()
	local givenIds = player:GetAttribute("SkillTestParts")
	local isGiven = false
	if type(givenIds) == "string" and givenIds ~= "" and script:GetAttribute("LabTestFreeGivenEnabled") ~= false then
		for gid in string.gmatch(givenIds, "[^,]+") do
			if gid == id then isGiven = true end
			judge[gid] = 0
		end
	end
	local ok, why = ST.canBuy(judge, id, tonumber(player:GetAttribute("SkillPoints")) or 0, species())
	if isGiven then ok, why = false, "maxed" end
	if ok then
		local cost = ST.COST[n + 1]
		return true, ("%s · %d PT%s"):format(n == 0 and "BUY" or "UPGRADE", cost, cost > 1 and "S" or "")
	elseif why == "maxed" then return false, "MAXED"
	elseif why == "masteryFull" then return false, "MASTERY FULL"
	elseif why == "noPoints" then return false, ("NEED %d %s"):format(ST.COST[n + 1] or 0, ST.COST[n + 1] == 1 and "PT" or "PTS")
	elseif why == "soon" then return false, "COMING SOON"
	end
	return false, "LOCKED"
end

function L2.cardAct(id, act)
	local p = ST.PATHS[id]
	if act == "buy" then
		press("buy:" .. id)
		remote:FireServer("buy", id)
		showToast(("%s %s"):format(string.upper(pathName(p)), ROMAN[stepsOf(id) + 1] or ""))
	elseif act == "put" then
		if slotSel then equip(id, slotSel) end
	elseif act == "off" then
		local k = slotIndex(id)
		if k then
			press("unequip:" .. id)
			remote:FireServer("slot", k, "")
			showToast(string.upper(pathName(p)) .. " OFF")
		end
	elseif act == "equip" then
		press("cardEquip:" .. id)
		local target
		for k = 1, ST.SLOTS do
			if not slotOf(k) then target = k break end
		end
		if target then
			equip(id, target)
		else
			press("full")
			pulseUntil = os.clock() + 2
			showToast("SLOTS FULL · TAP A SLOT TO SWAP")
			drawSlots()
			task.delay(2.05, function() if mode then drawSlots() end end)
		end
	end
	redraw()
end

function L2.drawPartCards()
	local L, ch = S.L, S.ch
	gridList.Parent = nil
	gridLayout.Parent = grid
	local ids = {}
	for _, id in ipairs(pathsFor(species(), true)) do
		if not splitTabs or ST.BUTTONS[id] == true then table.insert(ids, id) end
	end
	player:SetAttribute("LabPassiveCards", 0)
	if not selected or not table.find(ids, selected) then selected = ids[1] end
	local models = 0
	local p1 = L.cardPad
	local artW, artH = L.artW, L.cardH - 2 * p1
	local x0 = p1 + artW + 0.8 * ch
	local tw = L.cardW - x0 - p1
	local infoW = math.max(L.minTap, 6 * ch)
	local mainW = tw - infoW - 0.6 * ch
	local pw = 4 * S.pip + 3 * math.max(S.pip * 0.3, 2)
	for i, id in ipairs(ids) do
		local p = ST.PATHS[id]
		local n = stepsOf(id)
		local eq = slotIndex(id)
		local b = button(grid, "Card_" .. id, PANEL2, 0)
		b.LayoutOrder = i
		corner(b, UDim.new(0, 1.2 * ch))
		if L2.sheet and selected == id then
			stroke(b, WHITE, 0, 2.5)
		elseif eq then
			stroke(b, ORANGE, 0.1, 2)
		else
			stroke(b, WHITE, 0.9, 2)
		end
		local entry = {id = id, b = b}
		local art = frame(b, "Art", Color3.fromRGB(10, 14, 22), 0.2)
		art.Position, art.Size = UDim2.fromOffset(p1, p1), UDim2.fromOffset(artW, artH)
		corner(art, UDim.new(0, ch))
		local glow = Instance.new("UIGradient")
		glow.Rotation = 90
		glow.Color = ColorSequence.new(Color3.fromRGB(14, 20, 30), Color3.fromRGB(30, 60, 72))
		glow.Parent = art
		local m = (not p.soon) and previewOf(id) or nil
		if m then
			local vf = Instance.new("ViewportFrame")
			vf.Name = "Model"
			vf.BackgroundTransparency = 1
			vf.Size = UDim2.fromScale(1, 1)
			vf.Ambient = Color3.fromRGB(160, 160, 170)
			vf.LightDirection = Vector3.new(-0.4, -1, -0.6)
			vf.Parent = art
			local c = Instance.new("Camera")
			c.FieldOfView = 30
			c.Parent = vf
			vf.CurrentCamera = c
			m.Parent = vf
			local ctr, size = framing(m)
			entry.cam, entry.center = c, ctr
			entry.radius = (size * 0.5) / math.tan(math.rad(15)) * 1.15
			entry.angle = i * 0.9
			models += 1
		else
			local q = label(art, "Q", Enum.Font.FredokaOne, math.max(artH * 0.3, 12), MUTED, p.soon and "SOON" or "?")
			q.Size = UDim2.fromScale(1, 1)
			q.TextTransparency = 0.3
		end
		local nm = label(b, "Name", Enum.Font.FredokaOne, L.text.card, WHITE, pathName(p))
		nm.TextXAlignment = Enum.TextXAlignment.Left
		nm.TextTruncate = Enum.TextTruncate.AtEnd
		nm.Position, nm.Size = UDim2.fromOffset(x0, p1), UDim2.fromOffset(tw, L.text.card * 1.15)
		local my = p1 + L.text.card * 1.15 + 0.4 * ch
		local pp = pips(b, id, S.pip)
		pp.Position = UDim2.fromOffset(x0, my + (L.metaH - S.pip) / 2)
		local stText, stCol
		if p.soon then stText, stCol = "SOON", MUTED
		elseif n == 0 then stText, stCol = "NEW", YELLOW
		elseif eq then stText, stCol = "ON " .. (SLOT_KEYS[eq] or tostring(eq)), ORANGE
		else stText, stCol = "NOT ON A SLOT", MUTED end
		local sl = label(b, "State", Enum.Font.GothamBlack, L.text.tag, stCol, stText)
		sl.TextXAlignment = Enum.TextXAlignment.Left
		sl.TextTruncate = Enum.TextTruncate.AtEnd
		sl.Position = UDim2.fromOffset(x0 + pw + 0.8 * ch, my)
		sl.Size = UDim2.fromOffset(math.max(tw - pw - 0.8 * ch, 10), L.metaH)
		-- the card's own buttons
		local acts = frame(b, "Actions")
		acts.Position, acts.Size = UDim2.fromOffset(x0, L.cardH - p1 - L.btnH), UDim2.fromOffset(tw, L.btnH)
		local key = slotSel and (SLOT_KEYS[slotSel] or tostring(slotSel))
		local text, colr, tcol, enabled, act
		if p.soon then
			text, colr, tcol, enabled = "COMING SOON", PANEL, WHITE, false
		elseif n == 0 or not equippable(id) then
			local ok, bt = L2.buyState(id)
			text, colr, tcol, enabled = bt, ok and YELLOW or PANEL, ok and DARK_TEXT or WHITE, ok
			act = ok and "buy" or nil
		elseif slotSel then
			if eq == slotSel then
				text, colr, tcol, enabled = "ALREADY ON " .. key, PANEL, WHITE, false
			else
				text, colr, tcol, enabled, act = "PUT ON " .. key, ORANGE, DARK_TEXT, true, "put"
			end
		elseif eq then
			text, colr, tcol, enabled, act = "TAKE OFF " .. (SLOT_KEYS[eq] or tostring(eq)), PANEL, WHITE, true, "off"
		else
			text, colr, tcol, enabled, act = "EQUIP", ORANGE, DARK_TEXT, true, "equip"
		end
		local mb = detailButton(acts, text, colr, tcol, enabled, 1)
		mb.Size = UDim2.fromOffset(mainW, L.btnH)
		mb.T.TextSize = L.text.btn
		if act == "off" or not enabled then stroke(mb, WHITE, 0.84, 2) end
		local ib = button(acts, "Info", PANEL, 0)
		ib.Position, ib.Size = UDim2.fromOffset(mainW + 0.6 * ch, 0), UDim2.fromOffset(infoW, L.btnH)
		corner(ib, UDim.new(0, 1.2 * ch))
		stroke(ib, WHITE, 0.84, 2)
		local il = label(ib, "T", Enum.Font.GothamBlack, L.text.tag, WHITE, "INFO")
		il.Size = UDim2.fromScale(1, 1)
		mb.Activated:Connect(function() if act then L2.cardAct(id, act) end end)
		ib.Activated:Connect(function()
			press("info:" .. id)
			selected = id
			L2.sheet = true
			slotSel = nil
			redraw()
		end)
		b.Activated:Connect(function()
			press("card:" .. id)
			if slotSel and equippable(id) then
				equip(id, slotSel)
			else
				selected = id
				L2.sheet = true
			end
			redraw()
		end)
		if p.soon then b.BackgroundTransparency = 0.45 end
		table.insert(cards, entry)
	end
	player:SetAttribute("LabCards", #ids)
	player:SetAttribute("LabModels", models)
	player:SetAttribute("LabSelected", selected or "")
end

function L2.statRow(b, id)
	local L, ch = S.L, S.ch
	if not L then return end
	local px = 1.4 * ch
	local bw = L.rowBtnW
	local bh = math.max(L.minTap, math.min(L.btnH, L.rowH - 1.2 * ch))
	local nm = b:FindFirstChild("Name")
	if nm then nm.Size = UDim2.new(1, -2 * px - bw - ch, 0, nm.Size.Y.Offset) end
	local ar = b:FindFirstChild("Area")
	if ar then ar.Size = UDim2.new(1, -2 * px - bw - ch - 6 * S.pip, 0, ar.Size.Y.Offset) end
	local pp = b:FindFirstChild("Pips")
	if pp then pp.Position = UDim2.new(1, -px - bw - ch, 0, 1.2 * ch + S.cardName * 1.15 + 0.6 * ch + (S.metaH - S.pip) / 2) end
	local nx = b:FindFirstChild("Next")
	if nx then nx.Visible = false end
	local acts = frame(b, "Actions")
	acts.AnchorPoint = Vector2.new(1, 0.5)
	acts.Position, acts.Size = UDim2.new(1, -px, 0.5, 0), UDim2.fromOffset(bw, bh)
	local ok, txt = L2.buyState(id)
	local mb = detailButton(acts, txt, ok and YELLOW or PANEL, ok and DARK_TEXT or WHITE, ok, 1)
	mb.Size = UDim2.fromScale(1, 1)
	mb.T.TextSize = L.text.tag
	if not ok then stroke(mb, WHITE, 0.84, 2) end
	mb.Activated:Connect(function() if ok then L2.cardAct(id, "buy") end end)
end

function L2.reorderDetail()
	if tab == "skins" then return end
	local order = {Sub = 1, Title = 2, Actions = 3, Clip = 4, What = 5, Chips = 6, Steps = 7, Hint = 8}
	for _, c in ipairs(detail:GetChildren()) do
		if c:IsA("GuiObject") and order[c.Name] then c.LayoutOrder = order[c.Name] end
	end
end

function L2.layoutTips()
	local L, ch = S.L, S.ch
	if not L2.tips then
		local t = frame(stage, "Tips", Color3.fromRGB(11, 42, 51), 0.06)
		t.ZIndex = 4
		L2.tipsC = corner(t)
		stroke(t, VOLT, 0, 2)
		L2.tipSteps = {}
		for i, s in ipairs({"TAP A SLOT", "PICK A PART", "SAVE"}) do
			local l = label(t, "Step" .. i, Enum.Font.GothamBlack, 11, WHITE, s)
			l.RichText = true
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.ZIndex = 5
			L2.tipSteps[i] = {l = l, text = s}
		end
		local ok = button(t, "GotIt", VOLT, 0)
		ok.ZIndex = 5
		L2.tipOkC = corner(ok)
		local ol = label(ok, "T", Enum.Font.GothamBlack, 11, Color3.fromRGB(6, 36, 47), "GOT IT")
		ol.Size = UDim2.fromScale(1, 1)
		ol.ZIndex = 6
		ok.Activated:Connect(function()
			press("tipsOk")
			player:SetAttribute("LabTipDone", true)
			L2.after()
		end)
		L2.tips, L2.tipOk = t, ok
	end
	local okW = math.max(9 * ch, 80)
	local lineH = L.text.small * 1.3
	local h = math.max(3 * lineH + 1.6 * ch, L.minTap + 1.6 * ch)
	L2.tips.Position, L2.tips.Size = UDim2.new(0, ch, 1, -ch - h), UDim2.new(1, -2 * ch, 0, h)
	L2.tipsC.CornerRadius = UDim.new(0, 1.2 * ch)
	for i, s in ipairs(L2.tipSteps) do
		s.l.TextSize = L.text.small
		s.l.Position = UDim2.fromOffset(1.2 * ch, 0.8 * ch + (i - 1) * lineH)
		s.l.Size = UDim2.new(1, -okW - 3.2 * ch, 0, lineH)
	end
	L2.tipOk.AnchorPoint = Vector2.new(1, 0.5)
	L2.tipOk.Position, L2.tipOk.Size = UDim2.new(1, -ch, 0.5, 0), UDim2.fromOffset(okW, L.minTap)
	L2.tipOkC.CornerRadius = UDim.new(0, ch)
	L2.tipOk.T.TextSize = L.text.small
end

function L2.after() -- after every draw: tips, emote wheel size, text floor, diagnostics
	if not mode or not S.L then return end
	if L3.after then L3.after() end -- v2.1: tile order / locked labels / emote detail
	if L2.tips then
		local empty = false
		for k = 1, ST.SLOTS do if not slotOf(k) then empty = true end end
		local coach = pg:FindFirstChild("TutorialCoach")
		L2.tips.Visible = script:GetAttribute("LabTipsEnabled") ~= false and tab == "parts" and empty
			and player:GetAttribute("LabTipDone") ~= true and not (coach and coach:IsA("ScreenGui") and coach.Enabled)
			and (tonumber(player:GetAttribute("TutStep")) or 0) == 0 -- not during the Tutorial (its coach shows the way)
		local did = {L2.did.slot, L2.did.part, L2.did.save}
		for i, s in ipairs(L2.tipSteps) do
			s.l.Text = did[i] and ("<s>%d  %s</s>"):format(i, s.text) or ("%d  %s"):format(i, s.text)
			s.l.TextTransparency = did[i] and 0.5 or 0
		end
		script:SetAttribute("LabTipStepsDone", ("%d,%d,%d"):format(did[1] and 1 or 0, did[2] and 1 or 0, did[3] and 1 or 0))
	end
	local ring = detail:FindFirstChild("Wheel") -- emote wheel: slots are 0.24 x 0.19 of the ring; make them >= the tap size
	if ring then ring.Size = UDim2.new(1, 0, 0, math.max(ring.Size.Y.Offset, S.L.minTap / 0.19 + 2)) end
	for _, c in ipairs(detail:GetChildren()) do -- detail buttons drawn with their own height (LOOKS): at least the tap size
		if c:IsA("GuiButton") and c.Size.Y.Scale == 0 and c.Size.Y.Offset < S.L.minTap then
			c.Size = UDim2.new(c.Size.X.Scale, c.Size.X.Offset, 0, S.L.btnH)
		end
	end
	player:SetAttribute("LabSheet", L2.sheet == true)
	local minT = tonumber(script:GetAttribute("LabMinText")) or 11
	for _, d in ipairs(gui:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and not d.TextScaled and d.TextSize < minT then d.TextSize = minT end
	end
end

-- ---------- v2.1: Looks Lab v1.0 (see the header) ----------
function L3.on() return script:GetAttribute("LabWheelLeftEnabled") ~= false and EMO.on() end
function L3.sortOn() return script:GetAttribute("LabLooksSortEnabled") ~= false end

function L3.buildWheel()
	if L3.wheelF then return end
	local f = frame(mid, "EmoteWheelEdit")
	f.ZIndex = 2
	local base = frame(f, "Base", Color3.fromRGB(15, 20, 29), 0)
	base.Size = UDim2.fromScale(1, 1)
	corner(base, UDim.new(0.5, 0))
	stroke(base, Color3.fromRGB(42, 51, 68), 0, 2)
	L3.spokes, L3.slots = {}, {}
	for i = 1, 8 do
		local sp = frame(f, "Spoke" .. i, Color3.fromRGB(58, 69, 86), 0)
		sp.AnchorPoint = Vector2.new(0.5, 0.5)
		sp.ZIndex = 3
		L3.spokes[i] = sp
	end
	for i = 1, 8 do
		local b = button(f, "WSlot_" .. i, Color3.fromRGB(58, 47, 10), 1)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.ZIndex = 4
		local c = corner(b)
		local st = stroke(b, YELLOW, 1, 2)
		local n = label(b, "N", Enum.Font.GothamBlack, 11, MUTED, tostring(i))
		n.ZIndex = 5
		local w = label(b, "W", Enum.Font.GothamBlack, 12, WHITE, "")
		w.ZIndex = 5
		w.TextScaled = true
		w.TextWrapped = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MinTextSize, fit.MaxTextSize = 8, 14
		fit.Parent = w
		L3.slots[i] = {b = b, c = c, st = st, n = n, w = w, fit = fit}
		b.Activated:Connect(function()
			press("wheelSlot:" .. i)
			L3.wslot = L3.wslot ~= i and i or nil
			redraw()
		end)
	end
	local hub = frame(f, "Hub", Color3.fromRGB(11, 14, 20), 0)
	hub.AnchorPoint, hub.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	hub.ZIndex = 4
	corner(hub, UDim.new(0.5, 0))
	stroke(hub, Color3.fromRGB(42, 51, 68), 0, 2)
	local hl = label(hub, "T", Enum.Font.GothamBlack, 11, MUTED, "")
	hl.Size = UDim2.fromScale(1, 1)
	hl.TextWrapped = true
	hl.ZIndex = 5
	L3.hub, L3.hubL = hub, hl
	L3.wheelF = f
end

function L3.drawWheel(d)
	local R = d / 2
	local r0 = R * 0.3
	local len = R - r0
	local EC = EMO.cat()
	local wheel = EMO.wheel()
	local ch = S.ch
	L3.hub.Size = UDim2.fromOffset(2 * r0, 2 * r0)
	L3.hubL.TextSize = S.L.text.small
	L3.hubL.Text = L3.wslot and ("SLOT %d\nPICK AN EMOTE"):format(L3.wslot) or "YOUR\nWHEEL"
	L3.hubL.TextColor3 = L3.wslot and YELLOW or MUTED
	for i = 1, 8 do -- line i runs between section i-1 and section i
		local a = math.rad((i - 1) * 45 - 112.5)
		local m = r0 + len / 2
		local sp = L3.spokes[i]
		sp.Position = UDim2.fromOffset(R + m * math.cos(a), R + m * math.sin(a))
		sp.Size = UDim2.fromOffset(len, 2)
		sp.Rotation = math.deg(a)
		local lit = L3.wslot ~= nil and (L3.wslot == i or L3.wslot % 8 + 1 == i)
		sp.BackgroundColor3 = lit and YELLOW or Color3.fromRGB(58, 69, 86)
		sp.ZIndex = lit and 6 or 3
	end
	local rr = r0 + len * 0.55
	local bs = math.max(S.L.minTap, math.min(R * 0.42, 2 * rr * math.sin(math.rad(22.5)) - 6))
	local tS = S.L.text.tag
	for i, s in ipairs(L3.slots) do
		local a = math.rad((i - 1) * 45 - 90)
		s.b.Position = UDim2.fromOffset(R + rr * math.cos(a), R + rr * math.sin(a))
		s.b.Size = UDim2.fromOffset(bs, bs)
		s.c.CornerRadius = UDim.new(0, 0.8 * ch)
		local on = L3.wslot == i
		s.b.BackgroundTransparency = on and 0 or 1
		s.st.Transparency = on and 0 or 1
		local sid = wheel[i]
		local se = sid and EC.get(sid)
		s.n.Text = tostring(i)
		s.n.TextSize = tS
		s.n.TextColor3 = on and YELLOW or MUTED
		s.n.Position, s.n.Size = UDim2.fromOffset(0, 0.08 * bs), UDim2.new(1, 0, 0, tS * 1.1)
		s.w.Text = se and se.word or "+ EMPTY"
		s.w.TextColor3 = on and YELLOW or (se and WHITE or MUTED)
		s.w.Position = UDim2.fromOffset(0.05 * bs, 0.1 * bs + tS * 1.15)
		s.w.Size = UDim2.fromOffset(0.9 * bs, math.max(bs * 0.82 - tS * 1.15, 8))
		s.fit.MaxTextSize = S.L.text.btn
	end
end

function L3.layout()
	local L, ch = S.L, S.ch
	local looks = tab == "skins" and uniTab()
	local wheelView = looks and EMO.view() and L3.on()
	if not (looks and EMO.view()) then L3.wslot = nil end
	player:SetAttribute("LabWheelSlot", L3.wslot or 0)
	stage.Visible = true
	if L3.wheelF then L3.wheelF.Visible = false end
	if not looks then return end
	local y = L.sheet.y
	if L3.sortOn() then
		uniFilter = "all"
		if uniFilterRow then uniFilterRow.Visible = false end
		if wheelView then -- the head line takes the filter row's place
			local sel = L3.wslot ~= nil
			local hh = sel and L.minTap or math.max(L.text.hdr + 1.2 * ch, 22)
			local cancelW = sel and math.max(10 * ch, 96) or 0
			L2.head.Visible, L2.cancel.Visible = true, sel
			L2.head.TextSize = L.text.hdr
			L2.head.Position, L2.head.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(L.right.w - cancelW - (sel and ch or 0), hh)
			L2.cancel.Position, L2.cancel.Size = UDim2.fromOffset(L.right.w - cancelW, y), UDim2.fromOffset(cancelW, hh)
			L2.head.Text = sel and ("PICK AN EMOTE FOR SLOT %d"):format(L3.wslot) or "TAP A WHEEL SLOT, THEN AN EMOTE"
			L2.head.TextColor3 = sel and YELLOW or MUTED
			y += hh + 0.6 * ch
		end
		local h = L.body.h - y
		grid.Position, grid.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(L.looksGrid.w, h)
		right.Position = UDim2.fromOffset(L.right.x + L.looksDetail.x, y)
		right.Size = UDim2.fromOffset(L.looksDetail.w, h)
		detail.Size = UDim2.fromOffset(L.looksDetail.w, h)
	end
	if wheelView then
		L3.buildWheel()
		stage.Visible = false
		local lw, bh = L.left.w, L.body.h
		local d = math.min(lw, bh) - 2 * ch
		L3.wheelF.Visible = true
		L3.wheelF.Position, L3.wheelF.Size = UDim2.fromOffset((lw - d) / 2, (bh - d) / 2), UDim2.fromOffset(d, d)
		L3.drawWheel(d)
	end
end

function L3.pick(id) -- an emote tile tapped while a wheel section is selected
	if not (L3.on() and L3.wslot and EMO.view()) then return false end
	local st = EMO.state(id)
	if st ~= "own" and st ~= "wheel" then return false end
	local n = L3.wslot
	press("emoteSlot:" .. n .. ":" .. id)
	local r = ReplicatedStorage:FindFirstChild("DinoEmoteRequest")
	if r then r:FireServer("equip", n, id) end
	EMO.sel = id
	L3.wslot = nil
	redraw()
	return true
end

function L3.after()
	if not (tab == "skins" and uniTab()) then return end
	local view = TRL.view() and "trail" or (EMO.view() and "emote" or "skin")
	local US, EC, TC = uniMod(), EMO.cat(), TRL.cat()
	local sp = uniStageSpecies()
	local tS = S.L.text.tag
	if L3.sortOn() then
		for _, b in ipairs(grid:GetChildren()) do
			if b:IsA("GuiButton") then
				local kind, id = b.Name:match("^(%a+)_(.+)$")
				local st, price, have, need
				if kind == "Skin" and US and US.SKINS[id] then
					local sk = US.SKINS[id]
					st = uniState(sk, sp)
					price = uniPrice(sk)
					if st == "earn" then have, need = US.progress(id, uniStats()) end
					if st == "eq" then st = "on" end
				elseif kind == "Emote" and EC and EC.get(id) then
					st = EMO.state(id)
					price = EC.get(id).unlock.price
					if st == "earn" then have, need = EMO.progress(id) end
					if st == "wheel" then st = "on" end
				elseif kind == "Trail" and TC then
					st = TRL.state(id)
					local t = id ~= "none" and TC.get(id) or nil
					price = t and t.unlock.price
					if st == "earn" then have, need = TRL.progress(id) end
				end
				if st then
					local g = (st == "on" and 0) or (st == "own" and 1) or (st == "earn" and 2) or 3
					b.LayoutOrder = g * 1000 + (b.LayoutOrder % 1000)
					if (st == "buy" or st == "earn") and not b:FindFirstChild("Lock") then -- emotes / trails get the skins' lock
						local cw3 = S.uniCellW or S.cellW
						local p1 = 0.8 * S.ch
						local lk = label(b, "Lock", Enum.Font.GothamBlack, math.max(1.6 * S.ch, 9), WHITE, "🔒")
						lk.AnchorPoint = Vector2.new(1, 0)
						lk.Position = UDim2.fromOffset(cw3 - p1 - 2, p1 + 1)
						lk.Size = UDim2.fromOffset(math.max(1.8 * S.ch, 10), math.max(1.8 * S.ch, 10))
						lk.ZIndex = 3
					end
					local sl = b:FindFirstChild("State")
					if st == "buy" and sl then
						sl.Text = "BUY · R$" .. tostring(price or "?")
						sl.TextColor3 = DARK_TEXT
						sl.BackgroundTransparency = 0
						sl.BackgroundColor3 = YELLOW
						sl.TextXAlignment = Enum.TextXAlignment.Center
						sl.AutomaticSize = Enum.AutomaticSize.X
						sl.Size = UDim2.fromOffset(0, sl.Size.Y.Offset)
						if not sl:FindFirstChildOfClass("UICorner") then
							corner(sl, UDim.new(0, 0.5 * S.ch))
							pad(sl, 0.5 * S.ch)
						end
					elseif st == "earn" and have and need and not b:FindFirstChild("Prog") then
						local bar = b:FindFirstChild("Bar")
						if bar then
							local w = bar.Size.X.Offset
							bar.Size = UDim2.fromOffset(w * 0.55, bar.Size.Y.Offset)
							local pl = label(b, "Prog", Enum.Font.GothamBlack, tS, YELLOW, ("%d / %d"):format(have, need))
							pl.TextXAlignment = Enum.TextXAlignment.Right
							pl.Position = UDim2.fromOffset(bar.Position.X.Offset + w * 0.58, bar.Position.Y.Offset - tS * 0.45)
							pl.Size = UDim2.fromOffset(w * 0.42, tS * 1.2)
						end
					elseif view == "emote" and L3.on() and L3.wslot and sl and (st == "own" or st == "on") then
						sl.Text = "PUT ON " .. L3.wslot -- Studio: "TAP TO PUT ON n" was cut on a tile
						sl.TextColor3 = YELLOW
					end
				end
			end
		end
	end
	if view == "emote" and L3.on() and not detail:FindFirstChild("WheelLine") then -- the wheel is on the left now
		for _, n in ipairs({"WheelTitle", "Wheel"}) do
			local x = detail:FindFirstChild(n)
			if x then x:Destroy() end
		end
		local id = EMO.sel
		local st = id and EMO.state(id)
		if st == "own" or st == "wheel" then
			for _, c in ipairs(detail:GetChildren()) do
				if c:IsA("GuiButton") and c.Name == "Btn" then c:Destroy() end
			end
			local w = table.find(EMO.wheel(), id)
			local ln = label(detail, "WheelLine", Enum.Font.GothamBlack, S.stepS, w and ORANGE or GREY,
				w and ("On your wheel, slot %d."):format(w) or "Owned. Tap a wheel slot on the left, then this emote.")
			ln.TextXAlignment = Enum.TextXAlignment.Left
			ln.TextWrapped = true
			ln.AutomaticSize = Enum.AutomaticSize.Y
			ln.Size = UDim2.new(1, 0, 0, 0)
			ln.LayoutOrder = 7
		end
	end
end

local function rebuildUniStage(sp) -- v1.18: another dino on the SKINS stage
	local key = "uni|" .. sp
	if key == stageKey then return end
	if stagePreview then stagePreview:Destroy() stagePreview = nil end
	local f = ReplicatedStorage:FindFirstChild("PregameModels")
	local holder = f and f:FindFirstChild(sp)
	local src = holder and holder:FindFirstChild("Body")
	if not src then stageKey = nil return end
	stageKey = key
	local copy = src:Clone()
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	local cat = skinCatalog()
	if cat then uniMod().tagModel(copy, sp, cat.roleOf) end
	local cf, size = copy:GetBoundingBox()
	center = cf.Position
	stageSize = size
	radius = stageRadius()
	copy.Parent = view
	stagePreview = copy
end
local function rebuildStage()
	if uniTab() and uniView and uniView ~= species() then rebuildUniStage(uniView) return end -- v1.18
	local c = player.Character
	local names = {}
	if c then
		for _, ch in ipairs(c:GetChildren()) do
			if isMechaPart(ch.Name) then table.insert(names, ch.Name) end -- v1.10: + HPart_*
		end
	end
	table.sort(names)
	local key = tostring(c) .. "|" .. species() .. "|" .. table.concat(names, ",")
	if key == stageKey then return end
	stageKey = key
	if stagePreview then stagePreview:Destroy() stagePreview = nil end
	if not c then return end
	local was = c.Archivable
	c.Archivable = true
	local ok, copy = pcall(function() return c:Clone() end)
	c.Archivable = was
	if not ok or not copy then return end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Beam")
			or d:IsA("Trail") or d:IsA("ForceField") then
			d:Destroy()
		end
	end
	local hb = copy:FindFirstChild("Hitboxes")
	if hb then hb:Destroy() end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	local hrp = copy:FindFirstChild("HumanoidRootPart")
	local base = hrp and hrp.CFrame or copy:GetPivot()
	local flat = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
	if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
	copy:PivotTo(CFrame.lookAt(base.Position, base.Position + flat.Unit):Inverse() * copy:GetPivot())
	local cf, size = copy:GetBoundingBox()
	center = cf.Position
	stageSize = size
	radius = stageRadius()
	copy.Parent = view
	stagePreview = copy
end

function redraw()
	if not mode then return end
	measure()
	layout()
	drawBar()
	drawCards()
	drawSlots()
	drawDetail()
	rebuildStage()
	-- v1.6: stage colours (selected skin on the SKINS tab, the equipped one elsewhere), tag and hint
	if skinsOn then
		if useUni() then -- v1.18
			local sp = uniStageSpecies()
			if stagePreview then uniPaint(stagePreview, (tab == "skins" and not EMO.view() and not TRL.view()) and skinSel or uniEquipped(sp), sp) end -- v1.19, v1.20
		elseif stagePreview then paintModel(stagePreview, tab == "skins" and skinSel or equippedSkin()) end
		stageTag.Text = tab == "skins" and "PREVIEW" or "ALL UPGRADES"
		if uniTab() and skinSel and uniMod().get(skinSel) and not uniOwns(skinSel) then stageTag.Text = "PREVIEW · LOCKED" end -- v1.18
		if uniTab() and (EMO.view() or TRL.view()) then stageTag.Text = "PREVIEW" end -- v1.19, v1.20
		hint.Text = tab == "skins" and "Tap a skin to preview it on your dino" or "Tap a card, then EQUIP · tap a slot to choose where it goes"
	end
	player:SetAttribute("LabTab", (tab == "skins" and EMO.on()) and EMO.looks or tab) -- v2.0: + "emotes" / "trails"
	tabSkinsLabel.Text = "SKINS" -- v2.0 (1.19: LOOKS)
	player:SetAttribute("LabLooks", EMO.on() and EMO.looks or "")
	L2.after() -- v2.0
end

-- ---------- input ----------
tabParts.Activated:Connect(function() press("tab:parts") tab = "parts" selected = nil L2.sheet = false redraw() end)
tabStats.Activated:Connect(function()
	if script:GetAttribute("LabHideStatsEnabled") ~= false and player:GetAttribute("SkillAllStatsMax") == true then return end -- v2.3
	press("tab:stats") tab = "stats" selected = nil slotSel = nil L2.sheet = false redraw()
end)
player:GetAttributeChangedSignal("SkillAllStatsMax"):Connect(function() if mode then redraw() end end) -- v2.3
tabSkins.Activated:Connect(function() -- v1.6
	if not (skinsOn and mode == "full") then return end
	press("tab:skins")
	EMO.looks, EMO.arm, L2.sheet = "skins", false, false -- v2.0: SKINS is its own tab
	tab = "skins"
	slotSel = nil
	skinSel = equippedSkin()
	if useUni() then skinSel = uniEquipped(species()) uniView = nil end -- v1.18
	redraw()
end)
for n, s in ipairs(slotBtns) do
	s.b.Activated:Connect(function()
		press("slot:" .. n)
		L2.did.slot = true -- v2.0
		if L2.sheet and tab == "parts" and selected and equippable(selected) and not slotIndex(selected) then -- v2.0: from the open sheet only
			equip(selected, n)
			L2.sheet = false
		elseif slotSel == n then
			slotSel = nil
		else
			slotSel = n
			local inSlot = slotOf(n) -- v1.3: show the part in this slot on the right
			if slotShowsPart and inSlot then
				selected = inSlot
			end
			if tab ~= "parts" then tab = "parts" end -- v2.0: the list shows PUT ON <key>
			L2.sheet = false
		end
		if slotShowsPart then
			redraw()
		else
			drawSlots()
			drawCards()
		end
	end)
end

local labButton -- the SKILLS pill (set below)
local function setOpen(kind)
	if kind == mode then return end
	mode = kind
	gui.Enabled = kind ~= nil
	player:SetAttribute("LabOpen", kind or "closed")
	local c = player.Character
	if c then c:SetAttribute("SkillScreenOpen", kind == "compact") end
	-- the SKILLS pill hides while the compact Lab is open (the panel would sit over it under the dim; X / K close)
	if labButton then
		if kind == "compact" then
			labButton.Visible = false
		else
			labButton.Visible = player:GetAttribute("InMenu") ~= true
		end
	end
	if kind then
		if kind ~= "full" and tab == "skins" then tab = "parts" end -- v1.6: SKINS only in the full Lab
		slotSel = nil
		stageKey = nil
		L2.sheet = false -- v2.0
		redraw()
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		RunService:UnbindFromRenderStep(BIND)
		toast.Visible = false
		clipDrop() -- v1.15
		clipStep, clipStepFor = nil, nil
		player:SetAttribute("LabClipState", "off")
	end
end
closeB.Activated:Connect(function() press("close") setOpen(nil) end)

-- API for MainMenu 1.2
local openFn = script:FindFirstChild("Open") or Instance.new("BindableFunction")
openFn.Name = "Open"
openFn.Parent = script
openFn.OnInvoke = function(kind)
	if kind == "compact" then setOpen("compact") else setOpen("full") end
	return true
end
local closeFn = script:FindFirstChild("Close") or Instance.new("BindableFunction")
closeFn.Name = "Close"
closeFn.Parent = script
closeFn.OnInvoke = function() setOpen(nil) return true end

-- turning models
-- v1.19: the selected emote on the stage dino (joints moved by hand; welded parts follow their segment)
EMO.rig, EMO.clock, EMO.shown = nil, 0, false
function EMO.poseModule()
	local c = player.Character
	local m = c and c:FindFirstChild("IdleAnimation") and c.IdleAnimation:FindFirstChild("EmotePose")
	if not m then
		local scs = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
		local ia = scs and scs:FindFirstChild("IdleAnimation")
		m = ia and ia:FindFirstChild("EmotePose")
	end
	if not m then return nil end
	local ok, r = pcall(require, m)
	return ok and r or nil
end
function EMO.buildRig(model)
	EMO.rig = {model = model}
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local js, roots = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 and d.Part1.Name == "Root" then table.insert(js, d) roots[d.Part1] = true end
	end
	local done, order = {[hrp] = true}, {}
	for _ = 1, 40 do
		if #order >= #js then break end
		for _, m in ipairs(js) do
			if not done[m.Part1] and done[m.Part0] then table.insert(order, {m = m, c0 = m.C0, c1i = m.C1:Inverse()}) done[m.Part1] = true end
		end
	end
	-- each part follows a segment root: its own segment, or the segment it is welded to (mecha parts)
	local owner = {}
	for r in pairs(roots) do
		for _, p in ipairs(r.Parent:GetChildren()) do if p:IsA("BasePart") then owner[p] = r end end
	end
	local links = {}
	for _, d in ipairs(model:GetDescendants()) do
		if (d:IsA("JointInstance") or d:IsA("WeldConstraint")) and not (d:IsA("Motor6D") and roots[d.Part1]) and d.Part0 and d.Part1 then
			table.insert(links, {d.Part0, d.Part1})
		end
	end
	for _ = 1, 6 do
		local grew = false
		for _, l in ipairs(links) do
			local a, b = l[1], l[2]
			if owner[a] and not owner[b] and b ~= hrp then owner[b] = owner[a] grew = true
			elseif owner[b] and not owner[a] and a ~= hrp then owner[a] = owner[b] grew = true end
		end
		if not grew then break end
	end
	local parts = {}
	for p, r in pairs(owner) do
		parts[r] = parts[r] or {}
		table.insert(parts[r], {p, r.CFrame:ToObjectSpace(p.CFrame)})
	end
	local P = EMO.poseModule()
	EMO.rig = {model = model, hrp = hrp, base = hrp.CFrame, order = order, parts = parts, P = P, R = P and P.rig(model, nil)}
end
function EMO.pose(dt)
	local EC = EMO.on() and EMO.cat()
	local e = EC and EMO.sel and EC.get(EMO.sel)
	local want = mode ~= nil and uniTab() and EMO.view() and e ~= nil and stagePreview ~= nil
	if not want and not EMO.shown then return end
	if not stagePreview then EMO.shown = false return end
	if not EMO.rig or EMO.rig.model ~= stagePreview then EMO.buildRig(stagePreview) end
	local r = EMO.rig
	if not (r and r.order and r.P and r.R) then return end
	local pose = {}
	if want then
		EMO.clock += dt
		local cycle = e.dur + 0.8
		local et = EMO.clock % cycle
		if et <= e.dur then pose = r.P.get(EMO.sel, et / e.dur, et, r.R) or {} end
	end
	local W = {[r.hrp] = r.base}
	for _, j in ipairs(r.order) do
		local m = j.m
		local w0 = W[m.Part0]
		if w0 then
			local w1 = w0 * j.c0 * (pose[m.Name] or CFrame.identity) * j.c1i
			W[m.Part1] = w1
			for _, x in ipairs(r.parts[m.Part1] or {}) do x[1].CFrame = w1 * x[2] end
		end
	end
	EMO.shown = want
end
-- v1.20: the selected trail on the stage dino: the walk pose on EMO's rig (mecha parts follow) + TrailLook draws the trail
TRL.prev, TRL.ph, TRL.clock = nil, 0, 0
function TRL.pose(dt)
	local id = TRL.view() and (TRL.sel or TRL.equipped()) or nil
	local want = mode ~= nil and uniTab() and id ~= nil and stagePreview ~= nil
	local look = want and id ~= "none" and id or nil
	if TRL.prev and (TRL.prev.model ~= stagePreview or TRL.prev.id ~= look) then
		pcall(function() TRL.prev.h:destroy() end)
		TRL.prev = nil
	end
	if not want then
		if TRL.walking and stagePreview and EMO.rig and EMO.rig.model == stagePreview and not EMO.view() then
			EMO.shown = true -- EMO.pose puts the dino back in its rest pose on its next frame
		end
		TRL.walking = false
		return
	end
	if not EMO.rig or EMO.rig.model ~= stagePreview then EMO.buildRig(stagePreview) end
	local r = EMO.rig
	if not (r and r.order) then return end
	if not TRL.mod then
		local m = script.Parent:FindFirstChild("TrailLook")
		local ok, res = pcall(function() return m and require(m) end)
		TRL.mod = ok and res or false
	end
	if not TRL.mod then return end
	dt = math.min(dt, 0.05)
	TRL.clock += dt
	local hrp = r.hrp
	local hum = stagePreview:FindFirstChildOfClass("Humanoid")
	local h = (hum and hum.HipHeight > 0) and (hrp.Size.Y / 2 + hum.HipHeight) or hrp.Size.Y * 1.5
	TRL.ph += 2.4 * h * dt / (2.6 * h) * math.pi
	local pose = TRL.mod.walkPose(TRL.ph, 1, TRL.clock, h)
	local W = {[r.hrp] = r.base}
	for _, j in ipairs(r.order) do
		local m = j.m
		local w0 = W[m.Part0]
		if w0 then
			local w1 = w0 * j.c0 * (pose[m.Name] or CFrame.identity) * j.c1i
			W[m.Part1] = w1
			for _, x in ipairs(r.parts[m.Part1] or {}) do x[1].CFrame = w1 * x[2] end
		end
	end
	TRL.walking = true
	if look and not TRL.prev then
		local hd = TRL.mod.preview(stagePreview, look, {pose = false})
		if hd then TRL.prev = {h = hd, model = stagePreview, id = look} end
	end
	if TRL.prev then
		local ok = pcall(TRL.prev.h.step, TRL.prev.h, dt)
		if not ok then pcall(function() TRL.prev.h:destroy() end) TRL.prev = nil end
	end
end
RunService.RenderStepped:Connect(function(dt)
	if not mode then
		if TRL.prev then pcall(function() TRL.prev.h:destroy() end) TRL.prev = nil end -- v1.20
		return
	end
	orbit += dt * 0.45
	radius = stageRadius()
	cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(orbit), 0.32, math.cos(orbit)).Unit * radius, center)
	EMO.pose(dt) -- v1.19
	TRL.pose(dt) -- v1.20
	for _, c in ipairs(cards) do
		if c.cam then
			c.angle += dt * 0.9
			c.cam.CFrame = CFrame.lookAt(c.center + Vector3.new(math.sin(c.angle), 0.45, math.cos(c.angle)).Unit * c.radius, c.center)
		end
	end
end)

-- redraw on data changes
local queued = false
local function queue()
	if queued or not mode then return end
	queued = true
	task.defer(function()
		queued = false
		redraw()
	end)
end
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 5) == "Skill" then queue() end
	if name:sub(1, 12) == "SkinEquipped" then queue() end -- v1.6
	if skinBuyOn and (name:sub(1, 9) == "SkinOwned" or name:sub(1, 11) == "SkinCredits" or name:sub(1, 9) == "SkinPrice"
		or name == "SkinSaveState") then queue() end -- v1.7
	if skinBuyOn and name == "SkinServerResultAt" then -- v1.7: buying results
		local res = player:GetAttribute("SkinServerResult")
		if res ~= "prompted" then buyPendingAt = nil end
		if mode and (res == "bought" or res == "boughtNotEquipped") then
			local cat = skinCatalog()
			local id = player:GetAttribute("SkinLastBought")
			local sk = cat and cat.get(species(), id)
			if sk then
				showToast(string.upper(sk.name) .. " UNLOCKED!")
				flashId, flashUntil = sk.id, os.clock() + 1
				task.delay(1.05, queue)
			end
		elseif mode and res == "credit" then
			local r = "SKIN"
			for _, rarity in ipairs({"RARE", "EPIC", "LEGENDARY"}) do
				if (tonumber(player:GetAttribute("SkinCredits_" .. rarity)) or 0) > 0 then r = rarity break end
			end
			showToast(r .. " UNLOCK READY · PICK A SKIN")
		end
		queue()
	end
	if useUni() and (name == "SkinOwnedU" or name == "SkinAllUnlocked" or name == "StatKills" or name == "ArenaW" or name == "ArenaL"
		or name == "StatBestStreak" or name == "ArenaStreak") then queue() end -- v1.18
	if EMO.switch and (name == "EmoteOwned" or name == "EmoteWheel" or name == "EmoteAllUnlocked" or name == "EmoteSaveState") then queue() end -- v1.19
	if TRL.switch and (name == "TrailOwned" or name == "TrailEquipped" or name == "TrailAllUnlocked" or name == "TrailSaveState") then queue() end -- v1.20
	if TRL.switch and name == "TrailResult" then -- v1.20
		local res = player:GetAttribute("TrailResult")
		if res ~= "prompted" then buyPendingAt = nil end
		local TC = TRL.cat()
		if mode and TC and TRL.view() then
			if res == "equipped" then
				local t = TC.get(player:GetAttribute("TrailEquipped"))
				if t then showToast(string.upper(t.name) .. " ON") end
			elseif res == "off" then showToast("TRAIL OFF")
			elseif res == "bought" then
				local t = TC.get(player:GetAttribute("TrailUnlocked"))
				if t then showToast(string.upper(t.name) .. " UNLOCKED!") end
			elseif res == "promptFailed" or res == "noProduct" or res == "notLoaded" then showToast("TRY AGAIN IN A MOMENT") end
		end
		queue()
	end
	if EMO.switch and name == "EmoteResult" then -- v1.19
		local res = player:GetAttribute("EmoteResult")
		if res ~= "prompted" then buyPendingAt = nil end
		local EC = EMO.cat()
		if mode and EC and EMO.view() then
			if res == "equipped" and EMO.sel and EC.get(EMO.sel) then showToast(EC.get(EMO.sel).tag .. " ON YOUR WHEEL")
			elseif res == "bought" then
				local e = EC.get(player:GetAttribute("EmoteUnlocked"))
				if e then showToast(string.upper(e.name) .. " UNLOCKED!") end
			elseif res == "promptFailed" or res == "noProduct" or res == "notLoaded" then showToast("TRY AGAIN IN A MOMENT") end
		end
		queue()
	end
	if useUni() and name == "SkinServerResultAt" and mode then -- v1.18: universal toasts
		local res = player:GetAttribute("SkinServerResult")
		local US = uniMod()
		if res == "ok" then
			local sp = player:GetAttribute("SkinLastEquipFor")
			sp = (type(sp) == "string" and sp ~= "") and sp or species()
			local sk = US.get(player:GetAttribute("SkinEquipped_" .. sp))
			if sk then showToast(string.upper(sk.name) .. " ON " .. uniName(sp)) end
		elseif res == "bought" or res == "earned" then
			local sk = US.get(player:GetAttribute(res == "bought" and "SkinLastBought" or "SkinUnlocked"))
			if sk then
				showToast(string.upper(sk.name) .. " UNLOCKED!")
				flashId, flashUntil = sk.id, os.clock() + 1
				task.delay(1.05, queue)
			end
		end
		queue()
	end
	if name == "SkinServerResultAt" and mode and player:GetAttribute("SkinServerResult") == "ok" and not useUni() then -- v1.6 (v1.18: not with universal skins)
		local cat = skinCatalog()
		local sk = cat and cat.get(species(), equippedSkin())
		if sk then showToast(string.upper(sk.name) .. " EQUIPPED") end
	end
	if name == "InMenu" then
		if player:GetAttribute("InMenu") == true and mode == "compact" then setOpen(nil) end
		if player:GetAttribute("InMenu") ~= true and mode == "full" then setOpen(nil) end
		if labButton then labButton.Visible = player:GetAttribute("InMenu") ~= true and mode ~= "compact" end
	end
end)
local charConns = {}
local function onChar(c)
	for _, cn in ipairs(charConns) do cn:Disconnect() end
	table.clear(charConns)
	table.insert(charConns, c.ChildAdded:Connect(function(ch) if isMechaPart(ch.Name) then task.delay(0.25, queue) end end)) -- v1.10: + HPart_*
	table.insert(charConns, c.ChildRemoved:Connect(function(ch) if isMechaPart(ch.Name) then task.delay(0.25, queue) end end))
	table.insert(charConns, c:GetAttributeChangedSignal("Species"):Connect(queue))
	table.insert(charConns, c:GetAttributeChangedSignal("SkinApplied"):Connect(function() stageKey = nil queue() end)) -- v1.6
	c:SetAttribute("SkillScreenOpen", mode == "compact")
	task.delay(0.5, queue)
end
player.CharacterAdded:Connect(onChar)
if player.Character then onChar(player.Character) end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue)

-- ---------- SKILLS button (island) ----------
local bgui = Instance.new("ScreenGui")
bgui.Name = "LabButton"
bgui.DisplayOrder = 6
bgui.ResetOnSpawn = false
if script:GetAttribute("LabCornerEnabled") == nil then script:SetAttribute("LabCornerEnabled", true) end -- v1.5
local labY = 12
if script:GetAttribute("LabCornerEnabled") ~= false then -- v1.5: top-right corner
	bgui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	labY = 8
end
bgui.Parent = pg
labButton = button(bgui, "Skills", PANEL, 0.18)
labButton.AnchorPoint = Vector2.new(1, 0)
labButton.AutomaticSize = Enum.AutomaticSize.X
labButton.Size = UDim2.fromOffset(0, 36)
labButton.Position = UDim2.new(1, -150, 0, labY)
corner(labButton, UDim.new(0, 10))
stroke(labButton, WHITE, 0.5, 1.5)
pad(labButton, 12)
local lbList = list(labButton, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
local lbText = label(labButton, "T", Enum.Font.FredokaOne, 18, WHITE, "SKILLS")
lbText.AutomaticSize = Enum.AutomaticSize.X
lbText.Size = UDim2.fromOffset(0, 36)
lbText.TextStrokeTransparency = 0.6
local lbBadge = label(labButton, "Badge", Enum.Font.FredokaOne, 14, DARK_TEXT, "0")
lbBadge.BackgroundTransparency = 0
lbBadge.BackgroundColor3 = YELLOW
lbBadge.Size = UDim2.fromOffset(22, 22)
lbBadge.LayoutOrder = 2
corner(lbBadge, UDim.new(1, 0))
labButton.Visible = player:GetAttribute("InMenu") ~= true
labButton.Activated:Connect(function()
	press("skills")
	if mode == "compact" then setOpen(nil) else setOpen("compact") end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.K then return end
	if player:GetAttribute("InMenu") == true then return end
	press("key:K")
	if mode == "compact" then setOpen(nil) else setOpen("compact") end
end)
task.spawn(function()
	while bgui.Parent do
		local ast = pg:FindFirstChild("ArenaStatus")
		local pill = ast and ast:FindFirstChild("Pill")
		if player:GetAttribute("PhoneHudV2") == true and script:GetAttribute("LabPhoneDrawerEnabled") ~= false then
			-- v1.17: the phone drawer places it (the render step below); not reset here, so SQUAD never sees the old spot
		elseif pill and pill.AbsoluteSize.X > 0 then
			labButton.Position = UDim2.new(1, -16 - pill.AbsoluteSize.X - 8, 0, labY)
		else
			labButton.Position = UDim2.new(1, -150, 0, labY)
		end
		local left = tonumber(player:GetAttribute("SkillLeft")) or 0
		lbBadge.Text = tostring(left)
		lbBadge.Visible = left > 0
		task.wait(0.5)
	end
end)

-- v1.17: phone HUD v2 drawer (see the header)
do
	local BIND = "LabPhoneDrawer"
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value + 40, function()
		if player:GetAttribute("PhoneHudV2") ~= true or script:GetAttribute("LabPhoneDrawerEnabled") == false then return end
		local open = player:GetAttribute("PhoneMenuOpen") == true
		labButton.Position = UDim2.new(1, -16, 0, open and (tonumber(player:GetAttribute("PhoneMenuY_Skills")) or 50) or -400)
	end)
end

-- v1.16: toast after a save
player:GetAttributeChangedSignal("SkillLastResult"):Connect(function()
	if player:GetAttribute("SkillLastResult") == "saved" and saveOn() then
		showToast(string.upper(tostring(player:GetAttribute("SkillDino") or "")) .. " LOADOUT SAVED")
	end
end)
