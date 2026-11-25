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
	local top, sub = clean and "SAVED ✓" or "SAVE LOADOUT", clean and "LOADS IN THE PRE-GAME" or "FOR THE PRE-GAME"
	if saveTop.Text ~= top then saveTop.Text = top end
	if saveSub.Text ~= sub then saveSub.Text = sub end
end
for _, a in ipairs({"SkillSlot1", "SkillSlot2", "SkillSlot3", "SkillSlot4", "SkillSavedLoadout"}) do
	player:GetAttributeChangedSignal(a):Connect(drawSave)
end
saveTile.Activated:Connect(function()
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
	showToast(("%s → %s"):format(pathName(ST.PATHS[id]), SLOT_KEYS[n] or tostring(n)))
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
		best = math.max(tonumber(player:GetAttribute("StatBestStreak")) or 0, tonumber(player:GetAttribute("ArenaStreak")) or 0)}
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
	if EMO.switch then -- v1.19: SKINS / EMOTES pills first
		for i, f in ipairs({{"skins", "SKINS"}, {"emotes", "EMOTES"}}) do
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
local function drawUniCards()
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
		if selected == id then
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
		end
		b.Activated:Connect(function()
			press("card:" .. id)
			if slotSel and equippable(id) then
				equip(id, slotSel)
			end
			selected = id
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
		s.name.Text = p and pathName(p) or "empty"
		s.name.TextColor3 = p and GREY or MUTED
		if slotSel == n then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0, 3
		elseif os.clock() < pulseUntil or selOk then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0.35, 2
		elseif p then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = ORANGE, 0.45, 2
		else
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0.86, 2
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
	if not v or not v.Parent then return false end
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
local function drawUniDetail()
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
			b = detailButton(detail, "GET · R$" .. tostring(uniPrice(sk) or "?"), YELLOW, DARK_TEXT, true, 8)
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
			eqBtn = detailButton(acts, "UNEQUIP " .. (SLOT_KEYS[eqIdx] or tostring(eqIdx)), PANEL, WHITE, true, 2)
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
				showToast(pathName(p) .. " taken off")
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
					showToast("Slots full · tap a slot to replace")
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
	-- body
	local bx, by = 2 * cw, S.barH + 1.6 * ch
	local bw, bh = S.bw - 4 * cw, S.bh - S.barH - 1.6 * ch - 2 * ch
	body.Position, body.Size = UDim2.fromOffset(bx, by), UDim2.fromOffset(bw, bh)
	local gap = 1.6 * cw
	local lw, rw = bw * S.colL, bw * S.colR
	local mw = bw - lw - rw - 2 * gap
	left.Position, left.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(lw, bh)
	mid.Position, mid.Size = UDim2.fromOffset(lw + gap, 0), UDim2.fromOffset(mw, bh)
	right.Position, right.Size = UDim2.fromOffset(lw + gap + mw + gap, 0), UDim2.fromOffset(rw, bh)
	-- left
	local tabH = S.tabText + 1.8 * ch
	tabs.Size = UDim2.fromOffset(lw, tabH)
	local tg = 0.8 * ch
	tabParts.Position, tabParts.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset((lw - tg) / 2, tabH)
	tabStats.Position, tabStats.Size = UDim2.fromOffset((lw - tg) / 2 + tg, 0), UDim2.fromOffset((lw - tg) / 2, tabH)
	local tabBtns = {tabParts, tabStats}
	for i, t in ipairs({"parts", "stats"}) do
		tabCorners[i].CornerRadius = UDim.new(0, ch)
		tabLabels[i].TextSize = S.tabText
		local on = tab == t
		tabStrokes[i].Transparency = on and 0 or 1
		tabLabels[i].TextColor3 = on and WHITE or MUTED
		tabBtns[i].BackgroundTransparency = on and 0.86 or 0.94
		tabBtns[i].BackgroundColor3 = on and VOLT or WHITE
	end
	-- v1.6: three equal tabs when SKINS shows (full Lab only)
	local showSkins = skinsOn and mode == "full"
	tabSkins.Visible = showSkins
	for i = 1, 2 do
		local fit = tabLabels[i]:FindFirstChild("Fit")
		if showSkins and not fit then
			fit = Instance.new("UITextSizeConstraint")
			fit.Name = "Fit"
			fit.Parent = tabLabels[i]
		end
		if fit then fit.MinTextSize, fit.MaxTextSize = 7, S.tabText end
		tabLabels[i].TextScaled = showSkins
	end
	if showSkins then
		local w3 = (lw - 2 * tg) / 3
		tabParts.Position, tabParts.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(w3, tabH)
		tabStats.Position, tabStats.Size = UDim2.fromOffset(w3 + tg, 0), UDim2.fromOffset(w3, tabH)
		tabSkins.Position, tabSkins.Size = UDim2.fromOffset(2 * (w3 + tg), 0), UDim2.fromOffset(w3, tabH)
		tabSkinsCorner.CornerRadius = UDim.new(0, ch)
		tabSkinsLabel.TextSize = S.tabText
		local on = tab == "skins"
		tabSkinsStroke.Transparency = on and 0 or 1
		tabSkinsLabel.TextColor3 = on and WHITE or MUTED
		tabSkins.BackgroundTransparency = on and 0.86 or 0.94
		tabSkins.BackgroundColor3 = on and SKIN or WHITE
	end
	grid.Position, grid.Size = UDim2.fromOffset(0, tabH + 1.2 * ch), UDim2.fromOffset(lw, bh - tabH - 1.2 * ch)
	S.cellW = (lw - ch - 12) / 2 -- 3 px stroke room left, 9 px for the scroll bar
	S.metaH = math.max(S.tagS + 1 * ch, S.pip + 2)
	local artH = (S.cellW - 2 * ch) * 0.75
	S.cardCell = UDim2.fromOffset(S.cellW, ch + artH + 0.6 * ch + S.cardName * 1.15 + 0.6 * ch + S.metaH + ch) -- v1.2
	S.rowW, S.rowH = lw - 12, 1.2 * ch + S.cardName * 1.15 + 0.6 * ch + S.metaH + 1.2 * ch -- v1.2
	gridList.Padding = UDim.new(0, ch)
	if tab == "parts" or tab == "skins" then -- v1.6: skin cards use the part card cell
		gridLayout.CellSize = UDim2.fromOffset(S.cellW, ch + artH + 0.6 * ch + S.cardName * 1.15 + 0.6 * ch + S.metaH + ch)
		gridLayout.CellPadding = UDim2.fromOffset(ch, ch)
	else
		gridLayout.CellSize = UDim2.fromOffset(lw - 12, 1.2 * ch + S.cardName * 1.15 + 0.6 * ch + S.metaH + 1.2 * ch)
		gridLayout.CellPadding = UDim2.fromOffset(ch, ch)
	end
	-- middle
	local hintH = S.hintS * 2.6
	local stageH = bh - 1.2 * ch - S.slotH - 1.2 * ch - hintH
	stage.Position, stage.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(mw, stageH)
	stageCorner.CornerRadius = UDim.new(0, 2 * ch)
	stageTag.TextSize = math.max(1.6 * ch, 10)
	stageTag.Position = UDim2.fromOffset(1.8 * ch, 1.8 * ch)
	stageTag.Size = UDim2.fromOffset(0, math.max(1.6 * ch, 10) + 1.2 * ch)
	stageTagCorner.CornerRadius = UDim.new(0, 0.8 * ch)
	stageTagPad.PaddingLeft, stageTagPad.PaddingRight = UDim.new(0, ch), UDim.new(0, ch)
	slotsRow.Position, slotsRow.Size = UDim2.fromOffset(0, stageH + 1.2 * ch), UDim2.fromOffset(mw, S.slotH)
	local sg = 0.8 * cw
	local sw = (mw - sg * (ST.SLOTS - 1)) / ST.SLOTS
	if saveOn() then -- v1.16: the SAVE tile takes the end of the row
		local saveW = math.max(mw * 0.2, 70)
		sw = (mw - saveW - sg * ST.SLOTS) / ST.SLOTS
		saveTile.Position, saveTile.Size = UDim2.fromOffset(ST.SLOTS * (sw + sg), 0), UDim2.fromOffset(saveW, S.slotH)
		saveCorner.CornerRadius = UDim.new(0, 1.2 * ch)
		local tS, sS = math.max(1.7 * ch, 10), math.max(1.2 * ch, 8)
		saveTop.UITextSizeConstraint.MaxTextSize, saveSub.UITextSizeConstraint.MaxTextSize = tS, sS
		saveTop.Size = UDim2.new(1, -0.8 * cw, 0, tS + 2)
		saveTop.Position = UDim2.fromOffset(0.4 * cw, (S.slotH - tS - sS - 0.4 * ch) / 2)
		saveSub.Size = UDim2.new(1, -0.8 * cw, 0, sS + 2)
		saveSub.Position = UDim2.fromOffset(0.4 * cw, (S.slotH - tS - sS - 0.4 * ch) / 2 + tS + 0.4 * ch)
		drawSave()
	else
		saveTile.Visible = false
	end
	for n, s in ipairs(slotBtns) do
		s.b.Position, s.b.Size = UDim2.fromOffset((n - 1) * (sw + sg), 0), UDim2.fromOffset(sw, S.slotH)
		s.corner.CornerRadius = UDim.new(0, 1.2 * ch)
		local kS = math.max(1.9 * ch, 11)
		s.key.TextSize = kS
		s.key.Position, s.key.Size = UDim2.fromOffset(ch, 0), UDim2.fromOffset(kS * 1.6, S.slotH)
		local iz = math.min(S.slotH * 0.7, 4.4 * ch)
		s.icon.Position, s.icon.Size = UDim2.fromOffset(ch + kS * 1.6, (S.slotH - iz) / 2), UDim2.fromOffset(iz, iz)
		s.name.TextSize = math.max(1.6 * ch, 10)
		s.name.Fit.MaxTextSize = math.max(1.6 * ch, 10)
		local nameW = sw - (ch + kS * 1.6 + iz + 0.6 * ch) - ch
		if nameW >= 50 then
			s.name.Visible = true
			s.name.Size = UDim2.fromOffset(nameW, S.slotH - 0.8 * ch)
			s.name.Position = UDim2.fromOffset(ch + kS * 1.6 + iz + 0.6 * ch, 0.4 * ch)
		else -- narrow slot (compact Lab on a phone): key + a bigger part model, no name
			s.name.Visible = false
			local big = math.min(S.slotH * 0.86, sw - (ch + kS * 1.6) - ch)
			s.icon.Position = UDim2.fromOffset(ch + kS * 1.6 + (sw - (ch + kS * 1.6) - ch - big) / 2, (S.slotH - big) / 2)
			s.icon.Size = UDim2.fromOffset(big, big)
		end
	end
	hint.TextSize = S.hintS
	hint.Position, hint.Size = UDim2.fromOffset(0, stageH + 1.2 * ch + S.slotH + 1.2 * ch), UDim2.fromOffset(mw, hintH)
	-- v1.18: universal SKINS tab: filter row, 3 tiles a row, stage fills the column with the dino strip
	if uniTab() then
		uniBuild()
		local fS = math.max(1.4 * ch, 9)
		local fH = fS + 1.4 * ch
		uniFilterRow.Visible = true
		uniFilterRow.Position, uniFilterRow.Size = UDim2.fromOffset(0, tabH + 1.2 * ch), UDim2.fromOffset(lw, fH)
		uniFilterRow:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 0.8 * ch)
		for k, f in pairs(uniFilterBtns) do
			local on = uniFilter == k
			f.b.Size = UDim2.fromOffset(0, fH)
			f.b.BackgroundColor3 = on and SKIN or PANEL2
			f.l.TextSize = fS
			f.l.TextColor3 = on and Color3.fromRGB(26, 16, 48) or MUTED
			f.pd.PaddingLeft, f.pd.PaddingRight = UDim.new(0, 1.2 * ch), UDim.new(0, 1.2 * ch)
		end
		for k, f in pairs(EMO.lookBtns) do -- v1.19
			local on = EMO.looks == k
			f.b.Visible = EMO.on()
			f.b.Size = UDim2.fromOffset(0, fH)
			f.b.BackgroundColor3 = on and YELLOW or PANEL2
			f.l.TextSize = fS
			f.l.TextColor3 = on and DARK_TEXT or MUTED
			f.pd.PaddingLeft, f.pd.PaddingRight = UDim.new(0, 1.2 * ch), UDim.new(0, 1.2 * ch)
		end
		local gy = tabH + 1.2 * ch + fH + ch
		grid.Position, grid.Size = UDim2.fromOffset(0, gy), UDim2.fromOffset(lw, bh - gy)
		S.uniCellW = (lw - 2 * ch - 12) / 3
		local swH, nS, tS = math.max(3.2 * ch, 14), math.max(1.5 * ch, 9), math.max(1.3 * ch, 8)
		gridLayout.CellSize = UDim2.fromOffset(S.uniCellW, 0.8 * ch + swH + 0.6 * ch + nS * 1.2 + 0.4 * ch + tS * 1.2 + 0.8 * ch)
		gridLayout.CellPadding = UDim2.fromOffset(ch, ch)
		stage.Size = UDim2.fromOffset(mw, bh)
		slotsRow.Visible, hint.Visible = false, false
		uniStrip.Visible = true
		local sH = math.max(1.4 * ch, 9) + 1.8 * ch
		local g = 0.6 * ch
		local n = #uniStripBtns
		local perRow = n
		local bw = (mw - 2 * ch - g * (n - 1)) / n
		if bw < 44 then -- narrow stage (phone): two rows of 4 so names and taps fit (Studio phone test: 31 px buttons)
			perRow = math.ceil(n / 2)
			bw = (mw - 2 * ch - g * (perRow - 1)) / perRow
			sH = math.max(sH, 18)
		end
		local rows = math.ceil(n / perRow)
		local stripH = rows * sH + (rows - 1) * g
		uniStrip.Position, uniStrip.Size = UDim2.new(0, ch, 1, -ch - stripH), UDim2.new(1, -2 * ch, 0, stripH)
		local shown = uniStageSpecies()
		for i, s in ipairs(uniStripBtns) do
			local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
			s.b.Position, s.b.Size = UDim2.fromOffset(col * (bw + g), row * (sH + g)), UDim2.fromOffset(bw, sH)
			s.c.CornerRadius = UDim.new(0, 0.8 * ch)
			s.fit.MaxTextSize = math.max(1.4 * ch, 9)
			local on = s.sp == shown
			s.b.BackgroundColor3 = on and YELLOW or PANEL
			s.b.BackgroundTransparency = on and 0 or 0.15
			s.l.TextColor3 = on and DARK_TEXT or GREY
			s.st.Color = s.sp == species() and GREEN or WHITE
			s.st.Transparency = s.sp == species() and 0 or 0.8
		end
	else
		slotsRow.Visible, hint.Visible = true, true
		if uniFilterRow then uniFilterRow.Visible = false end
		if uniStrip then uniStrip.Visible = false end
	end
	-- right
	detail.Position, detail.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(rw, bh)
	detailCorner.CornerRadius = UDim.new(0, 2 * ch)
	-- toast
	toast.TextSize = math.max(2.4 * ch, 12)
	toast.Position = UDim2.new(0.5, 0, 1, -3 * ch)
	toast.Size = UDim2.fromOffset(0, math.max(2.4 * ch, 12) + 2.4 * ch)
	toastCorner.CornerRadius = UDim.new(0, 1.6 * ch)
	toastPad.PaddingLeft, toastPad.PaddingRight = UDim.new(0, 2.4 * ch), UDim.new(0, 2.4 * ch)
	-- compact vs full look
	if mode == "compact" then
		root.BackgroundTransparency = 0.55
		boxCorner.CornerRadius = UDim.new(0, 2.4 * ch)
		boxStroke.Transparency = 0.7
	else
		root.BackgroundTransparency = 1
		boxCorner.CornerRadius = UDim.new(0, 0)
		boxStroke.Transparency = 1
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
			if stagePreview then uniPaint(stagePreview, (tab == "skins" and not EMO.view()) and skinSel or uniEquipped(sp), sp) end -- v1.19
		elseif stagePreview then paintModel(stagePreview, tab == "skins" and skinSel or equippedSkin()) end
		stageTag.Text = tab == "skins" and "PREVIEW" or "ALL UPGRADES"
		if uniTab() and skinSel and uniMod().get(skinSel) and not uniOwns(skinSel) then stageTag.Text = "PREVIEW · LOCKED" end -- v1.18
		if uniTab() and EMO.view() then stageTag.Text = "PREVIEW" end -- v1.19
		hint.Text = tab == "skins" and "Tap a skin to preview it on your dino" or "Tap a card, then EQUIP · tap a slot to choose where it goes"
	end
	player:SetAttribute("LabTab", tab)
	tabSkinsLabel.Text = EMO.on() and "LOOKS" or "SKINS" -- v1.19
	player:SetAttribute("LabLooks", EMO.on() and EMO.looks or "")
end

-- ---------- input ----------
tabParts.Activated:Connect(function() press("tab:parts") tab = "parts" selected = nil redraw() end)
tabStats.Activated:Connect(function() press("tab:stats") tab = "stats" selected = nil slotSel = nil redraw() end)
tabSkins.Activated:Connect(function() -- v1.6
	if not (skinsOn and mode == "full") then return end
	press("tab:skins")
	tab = "skins"
	slotSel = nil
	skinSel = equippedSkin()
	if useUni() then skinSel = uniEquipped(species()) uniView = nil end -- v1.18
	redraw()
end)
for n, s in ipairs(slotBtns) do
	s.b.Activated:Connect(function()
		press("slot:" .. n)
		if selected and equippable(selected) and not slotIndex(selected) then
			equip(selected, n)
		elseif slotSel == n then
			slotSel = nil
		else
			slotSel = n
			local inSlot = slotOf(n) -- v1.3: show the part in this slot on the right
			if slotShowsPart and inSlot then
				selected = inSlot
				if tab ~= "parts" then tab = "parts" end
			end
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
RunService.RenderStepped:Connect(function(dt)
	if not mode then return end
	orbit += dt * 0.45
	radius = stageRadius()
	cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(orbit), 0.32, math.cos(orbit)).Unit * radius, center)
	EMO.pose(dt) -- v1.19
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
