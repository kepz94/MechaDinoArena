-- lab2_patch (Lab Revamp v1.0, Lab 1.20 -> 2.0). Applied to the repo by tools/lab2_patch.py and to Studio by running this file
-- with `sc` = the Lab LocalScript. Format: BLOCK = {start, stop, new} (text from start up to, not including, stop is replaced),
-- then PAIRS = {old, new}, each old found exactly once.
local BLOCK = {[=====[	-- body
	local bx, by = 2 * cw, S.barH + 1.6 * ch]=====], [=====[	-- compact vs full look]=====], [=====[	L2.layoutBody() -- v2.0: body, columns, tabs, list, sheet, LOOKS, toast (Lab Revamp v1.0)
]=====]}
local PAIRS = {
{[=====[VERSION = "1.20" -- v1.20 LOOKS: TRAILS
]=====], [=====[VERSION = "1.20" -- v1.20 LOOKS: TRAILS
VERSION = "2.0" -- v2.0 Lab Revamp v1.0: slots first
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
]=====]},
{[=====[TRL.fitW, TRL.fitP, TRL.fitS = nil, 1, 1
]=====], [=====[TRL.fitW, TRL.fitP, TRL.fitS = nil, 1, 1
L2 = {sheet = false, did = {slot = false, part = false, save = false}} -- v2.0: Lab Revamp state + helpers (script-global, as EMO / TRL)
pcall(function() L2.LL = require(script.Parent:WaitForChild("LabLayout", 10)) end)
if script:GetAttribute("LabTipsEnabled") == nil then script:SetAttribute("LabTipsEnabled", true) end -- v2.0
if script:GetAttribute("LabMinText") == nil then script:SetAttribute("LabMinText", 11) end -- v2.0
if script:GetAttribute("LabEmoteGridFrac") == nil then script:SetAttribute("LabEmoteGridFrac", 0.45) end -- v2.0
]=====]},
{[=====[	local top, sub = clean and "SAVED ✓" or "SAVE LOADOUT", clean and "LOADS IN THE PRE-GAME" or "FOR THE PRE-GAME"]=====],
 [=====[	local top, sub = clean and "SAVED ✓" or "SAVE", clean and "PRE-GAME" or "FOR PRE-GAME" -- v2.0 (1.16: SAVE LOADOUT / FOR THE PRE-GAME)]=====]},
{[=====[saveTile.Activated:Connect(function()
	if remote then remote:FireServer("saveLoadout") end]=====], [=====[saveTile.Activated:Connect(function()
	L2.did.save = true -- v2.0 tip strip
	if remote then remote:FireServer("saveLoadout") end]=====]},
{[=====[local function measure()
	local W, H = root.AbsoluteSize.X, root.AbsoluteSize.Y
	local ch, cw = H / 100, W / 100]=====], [=====[local function measure()
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
	local ch, cw = H / 100, W / 100]=====]},
{[=====[local function equip(id, n)
	press(("equip:%s:%d"):format(id, n))
	remote:FireServer("slot", n, id)
	slotSel = nil
	showToast(("%s → %s"):format(pathName(ST.PATHS[id]), SLOT_KEYS[n] or tostring(n)))]=====], [=====[local function equip(id, n)
	press(("equip:%s:%d"):format(id, n))
	remote:FireServer("slot", n, id)
	slotSel = nil
	L2.did.part = true -- v2.0 tip strip
	showToast(("%s ON %s"):format(string.upper(pathName(ST.PATHS[id])), SLOT_KEYS[n] or tostring(n))) -- v2.0 (1.x: "<Name> → <key>")]=====]},
{[=====[	if tab == "skins" then drawSkinCards() return end -- v1.6
]=====], [=====[	if tab == "skins" then drawSkinCards() return end -- v1.6
	if tab == "parts" and L2.drawPartCards then L2.drawPartCards() return end -- v2.0: row cards with their own buttons
]=====]},
{[=====[			nx.Size = UDim2.new(0.5, -px, 0, S.metaH)
		end
		b.Activated:Connect(function()
			press("card:" .. id)
			if slotSel and equippable(id) then
				equip(id, slotSel)
			end
			selected = id
			redraw()]=====], [=====[			nx.Size = UDim2.new(0.5, -px, 0, S.metaH)
			if L2.statRow then L2.statRow(b, id) end -- v2.0: the row's own UPGRADE / BUY button
		end
		b.Activated:Connect(function()
			press("card:" .. id)
			if slotSel and equippable(id) then
				equip(id, slotSel)
			end
			selected = id
			L2.sheet = true -- v2.0: the detail opens as a sheet over the list
			redraw()]=====]},
{[=====[		s.name.Text = p and pathName(p) or "empty"
		s.name.TextColor3 = p and GREY or MUTED
		if slotSel == n then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0, 3]=====], [=====[		s.name.Text = p and pathName(p) or "TAP TO FILL" -- v2.0 (1.x: "empty")
		s.name.TextColor3 = p and GREY or MUTED
		if slotSel == n then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = YELLOW, 0, 3 -- v2.0 (1.x: white)]=====]},
{[=====[		else
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0.86, 2
		end]=====], [=====[		else
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0.6, 2 -- v2.0 (1.x: 0.86)
		end]=====]},
{[=====[	player:SetAttribute("LabSlotSel", slotSel or 0)
end]=====], [=====[	if L2.slotLook then L2.slotLook() end -- v2.0
	player:SetAttribute("LabSlotSel", slotSel or 0)
end]=====]},
{[=====[	if not v or not v.Parent then return false end]=====], [=====[	if not v or not v.Parent or not right.Visible then return false end -- v2.0: no clip while the sheet is closed]=====]},
{[=====[			eqBtn = detailButton(acts, "UNEQUIP " .. (SLOT_KEYS[eqIdx] or tostring(eqIdx)), PANEL, WHITE, true, 2)]=====],
 [=====[			eqBtn = detailButton(acts, "TAKE OFF " .. (SLOT_KEYS[eqIdx] or tostring(eqIdx)), PANEL, WHITE, true, 2) -- v2.0 (1.x: UNEQUIP)]=====]},
{[=====[				showToast(pathName(p) .. " taken off")]=====], [=====[				showToast(string.upper(pathName(p)) .. " OFF") -- v2.0]=====]},
{[=====[					showToast("Slots full · tap a slot to replace")]=====], [=====[					showToast("SLOTS FULL · TAP A SLOT TO SWAP") -- v2.0]=====]},
{[=====[	if script:GetAttribute("LabClipEnabled") ~= false then clipMount(id, n, col) end -- v1.15
end]=====], [=====[	if script:GetAttribute("LabClipEnabled") ~= false then clipMount(id, n, col) end -- v1.15
	if L2.reorderDetail then L2.reorderDetail() end -- v2.0
end]=====]},
{[=====[	if mode == "compact" then
		root.BackgroundTransparency = 0.55]=====], [=====[	if mode == "compact" and (not S.L or S.L.inset) then -- v2.0: the island Lab on touch is full screen
		root.BackgroundTransparency = 0.55]=====]},
{[=====[local function rebuildUniStage(sp) -- v1.18: another dino on the SKINS stage]=====], [=====[-- ---------- v2.0: Lab Revamp v1.0 (slots first; see the header) ----------
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
		local y0 = (sh - tS - sS - 0.4 * ch) / 2
		saveTop.Position, saveTop.Size = UDim2.fromOffset(0.3 * ch, y0), UDim2.new(1, -0.6 * ch, 0, tS + 2)
		saveSub.Position, saveSub.Size = UDim2.fromOffset(0.3 * ch, y0 + tS + 0.4 * ch), UDim2.new(1, -0.6 * ch, 0, sS + 2)
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
		local iz = math.min(sh * 0.42, 3.4 * ch)
		s.icon.Visible = sw >= 70
		s.icon.Position, s.icon.Size = UDim2.fromOffset(sw - iz - 0.3 * ch, 0.3 * ch), UDim2.fromOffset(iz, iz)
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
		L2.cancel.Activated:Connect(function() press("cancelSlot") slotSel = nil redraw() end)
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
	if L2.tips then
		local empty = false
		for k = 1, ST.SLOTS do if not slotOf(k) then empty = true end end
		local coach = pg:FindFirstChild("TutorialCoach")
		L2.tips.Visible = script:GetAttribute("LabTipsEnabled") ~= false and tab == "parts" and empty
			and player:GetAttribute("LabTipDone") ~= true and not (coach and coach:IsA("ScreenGui") and coach.Enabled)
		local did = {L2.did.slot, L2.did.part, L2.did.save}
		for i, s in ipairs(L2.tipSteps) do
			s.l.Text = did[i] and ("<s>%d  %s</s>"):format(i, s.text) or ("%d  %s"):format(i, s.text)
			s.l.TextTransparency = did[i] and 0.5 or 0
		end
		script:SetAttribute("LabTipStepsDone", ("%d,%d,%d"):format(did[1] and 1 or 0, did[2] and 1 or 0, did[3] and 1 or 0))
	end
	local ring = detail:FindFirstChild("Wheel") -- emote wheel: slots are 0.24 x 0.19 of the ring; make them >= the tap size
	if ring then ring.Size = UDim2.new(1, 0, 0, math.max(ring.Size.Y.Offset, S.L.minTap / 0.19 + 2)) end
	player:SetAttribute("LabSheet", L2.sheet == true)
	local minT = tonumber(script:GetAttribute("LabMinText")) or 11
	for _, d in ipairs(gui:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and not d.TextScaled and d.TextSize < minT then d.TextSize = minT end
	end
end

local function rebuildUniStage(sp) -- v1.18: another dino on the SKINS stage]=====]},
{[=====[	player:SetAttribute("LabTab", tab)
	tabSkinsLabel.Text = EMO.on() and "LOOKS" or "SKINS" -- v1.19
	player:SetAttribute("LabLooks", EMO.on() and EMO.looks or "")
end]=====], [=====[	player:SetAttribute("LabTab", (tab == "skins" and EMO.on()) and EMO.looks or tab) -- v2.0: + "emotes" / "trails"
	tabSkinsLabel.Text = "SKINS" -- v2.0 (1.19: LOOKS)
	player:SetAttribute("LabLooks", EMO.on() and EMO.looks or "")
	L2.after() -- v2.0
end]=====]},
{[=====[tabParts.Activated:Connect(function() press("tab:parts") tab = "parts" selected = nil redraw() end)
tabStats.Activated:Connect(function() press("tab:stats") tab = "stats" selected = nil slotSel = nil redraw() end)]=====],
 [=====[tabParts.Activated:Connect(function() press("tab:parts") tab = "parts" selected = nil L2.sheet = false redraw() end)
tabStats.Activated:Connect(function() press("tab:stats") tab = "stats" selected = nil slotSel = nil L2.sheet = false redraw() end)]=====]},
{[=====[	press("tab:skins")
	tab = "skins"]=====], [=====[	press("tab:skins")
	EMO.looks, EMO.arm, L2.sheet = "skins", false, false -- v2.0: SKINS is its own tab
	tab = "skins"]=====]},
{[=====[		press("slot:" .. n)
		if selected and equippable(selected) and not slotIndex(selected) then
			equip(selected, n)
		elseif slotSel == n then]=====], [=====[		press("slot:" .. n)
		L2.did.slot = true -- v2.0
		if L2.sheet and tab == "parts" and selected and equippable(selected) and not slotIndex(selected) then -- v2.0: from the open sheet only
			equip(selected, n)
			L2.sheet = false
		elseif slotSel == n then]=====]},
{[=====[			if slotShowsPart and inSlot then
				selected = inSlot
				if tab ~= "parts" then tab = "parts" end
			end
		end]=====], [=====[			if slotShowsPart and inSlot then
				selected = inSlot
			end
			if tab ~= "parts" then tab = "parts" end -- v2.0: the list shows PUT ON <key>
			L2.sheet = false
		end]=====]},
{[=====[		slotSel = nil
		stageKey = nil
		redraw()]=====], [=====[		slotSel = nil
		stageKey = nil
		L2.sheet = false -- v2.0
		redraw()]=====]},
}
-- apply (Studio): sc = the Lab LocalScript
local s = sc.Source
local i1 = string.find(s, BLOCK[1], 1, true)
local i2 = i1 and string.find(s, BLOCK[2], i1, true)
assert(i1 and i2, "block markers")
s = s:sub(1, i1 - 1) .. BLOCK[3] .. s:sub(i2)
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
