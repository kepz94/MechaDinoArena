-- LabLayout v1.0 (Mecha Dino Arena) — size math for Lab 2.0 (ModuleScript, StarterPlayerScripts). Lab Revamp v1.0, plan
-- docs/plans/LAB_REVAMP_v1.0.md Task 1 (MDA-584), ADR-015, mockup docs/mockups/lab_revamp_v0.1 option "B · Slots first" (Kepu
-- 2026-11-25). Pure: no Instances, no services; every number can be overridden through opts.attrs (the Lab passes its script
-- attributes).
-- LabLayout.compute(W, H, opts) -> L. opts = {mode = "full" | "compact", touch = bool, topInset = px (Roblox top bar height),
--   topLeftClear = px (right edge of the Roblox top-left buttons), slotSel = bool (a slot is selected: the head line holds CANCEL),
--   attrs = {name = value}}. Rects are {x, y, w, h} in px; box is in screen px, everything else is relative to the box (bar) or
--   to the body (cols, stage, slots, tabs, head, list, sheet, looks).
-- Arrangement (full screen; compact on touch = full screen too, red-team R3; compact with a mouse = today's inset panel):
--   bar on top; body below: LEFT column (stage, then the slot row: 4 slots + SAVE 1.25 x a slot) and RIGHT column (tab row, a
--   head line (ABILITIES), then the list). The detail sheet covers the right column below the tabs (ABILITIES / STATS); on the
--   LOOKS tabs the right column splits grid | detail (looksGrid / looksDetail) under a chip row.
-- Minimums (phone): every tap target >= LabMinTap (44) px; every text >= LabMinText (11) px.
-- Attributes (defaults): LabChMin 6 (the Lab's ch unit floor: ch = max(H / 100, LabChMin)), LabMinTap 44, LabMinText 11,
--   LabLeftFrac 0.42, LabLeftFracWide 0.40 (body width >= LabWideW 1000), LabSlotH 6 (ch), LabSaveW 1.25 (x slot),
--   LabTwoCardsW 560 (right column width for 2 cards a row), LabLooksGridFrac 0.6, LabArtFrac 0.26 (row card art width / card).
local LabLayout = {}
LabLayout.VERSION = "1.0"

local DEFAULTS = {LabChMin = 6, LabMinTap = 44, LabMinText = 11, LabLeftFrac = 0.42, LabLeftFracWide = 0.40, LabWideW = 1000,
	LabSlotH = 6, LabSaveW = 1.25, LabTwoCardsW = 560, LabLooksGridFrac = 0.6, LabArtFrac = 0.26}

local function rect(x, y, w, h) return {x = x, y = y, w = w, h = h} end

function LabLayout.compute(W, H, opts)
	opts = opts or {}
	local at = opts.attrs or {}
	local function A(k)
		local v = tonumber(at[k])
		if v == nil then return DEFAULTS[k] end
		return v
	end
	W, H = math.max(tonumber(W) or 0, 1), math.max(tonumber(H) or 0, 1)
	local TAP, TXT = A("LabMinTap"), A("LabMinText")
	local ch = math.max(H / 100, A("LabChMin"))
	local cw = W / 100
	local L = {ch = ch, cw = cw, minTap = TAP, minText = TXT}
	-- box
	local inset = opts.mode == "compact" and not opts.touch
	if inset then
		local top = math.max(10 * ch, (opts.topInset or 0) + ch)
		L.box = rect(11 * cw, top, W - 22 * cw, H - top - 6 * ch)
		L.barLeftPad = 2 * cw
	else
		L.box = rect(0, 0, W, H)
		L.barLeftPad = math.max(10 * ch, (opts.topLeftClear or 0) + 1.6 * ch)
	end
	L.inset = inset
	-- text
	L.text = {
		name = math.max(3.4 * ch, 16),
		small = math.max(1.8 * ch, TXT),
		tab = math.max(1.7 * ch, TXT),
		card = math.max(1.9 * ch, TXT + 1),
		tag = math.max(1.6 * ch, TXT),
		step = math.max(1.6 * ch, TXT),
		hint = math.max(1.5 * ch, TXT),
		btn = math.max(1.9 * ch, TXT + 2),
		key = math.max(2.4 * ch, 16),
		hdr = math.max(1.6 * ch, TXT),
	}
	-- bar
	L.closeS = math.max(5 * ch, TAP)
	L.barH = 1.4 * ch + math.max(L.closeS, L.text.name * 1.1) + 1.2 * ch
	if not inset then L.barH = math.max(L.barH, (opts.topInset or 0) + 0.6 * ch) end
	-- body
	local bx, by = 2 * cw, L.barH + 1.6 * ch
	local bw, bh = L.box.w - 4 * cw, L.box.h - L.barH - 1.6 * ch - 2 * ch
	L.body = rect(bx, by, bw, bh)
	L.gap = math.max(1.6 * cw, 8)
	local frac = W >= A("LabWideW") and A("LabLeftFracWide") or A("LabLeftFrac")
	local lw = math.floor(bw * frac)
	local rw = bw - lw - L.gap
	L.left = rect(0, 0, lw, bh)
	L.right = rect(lw + L.gap, 0, rw, bh)
	-- left: stage + slot row
	L.slotGap = 0.8 * ch
	L.slotRowH = math.max(A("LabSlotH") * ch, TAP + 12)
	L.slotW = (lw - 4 * L.slotGap) / (4 + A("LabSaveW"))
	L.saveW = L.slotW * A("LabSaveW")
	L.stage = rect(0, 0, lw, bh - L.slotRowH - 1.2 * ch)
	L.slotRow = rect(0, bh - L.slotRowH, lw, L.slotRowH)
	L.stripH = math.max(1.4 * ch + 1.8 * ch, TAP) -- dino strip buttons (SKINS), 2 rows of 4
	-- right: tabs, head, list
	L.tabCount = (opts.mode == "compact") and 2 or 5
	L.tabGap = 0.8 * ch
	L.tabs = rect(0, 0, rw, math.max(L.text.tab + 1.8 * ch, TAP))
	L.tabW = (rw - (L.tabCount - 1) * L.tabGap) / L.tabCount
	L.headH = opts.slotSel and TAP or math.max(L.text.hdr + 1.2 * ch, 22)
	local ly = L.tabs.h + 0.8 * ch
	L.head = rect(0, ly, rw, L.headH)
	L.list = rect(0, ly + L.headH + 0.6 * ch, rw, bh - (ly + L.headH + 0.6 * ch))
	L.listPlain = rect(0, ly, rw, bh - ly) -- STATS (no head line)
	L.sheet = rect(0, ly, rw, bh - ly)
	L.btnH = math.max(5.6 * ch, TAP)
	L.backH = TAP
	-- row cards (ABILITIES)
	L.cardsPerRow = rw >= A("LabTwoCardsW") and 2 or 1
	L.cardGap = ch
	L.cardW = (rw - 12 - (L.cardsPerRow - 1) * L.cardGap) / L.cardsPerRow -- 12: scroll bar + stroke room
	L.cardPad = ch
	L.metaH = math.max(L.text.tag + ch, 1.6 * ch + 2)
	L.cardH = L.cardPad + L.text.card * 1.15 + 0.4 * ch + L.metaH + 0.6 * ch + L.btnH + L.cardPad
	L.artW = math.min(L.cardW * A("LabArtFrac"), (L.cardH - 2 * L.cardPad) * 4 / 3)
	L.infoW = TAP + 0.8 * ch
	-- STATS rows
	L.rowW = rw - 12
	L.rowH = math.max(1.2 * ch + L.text.card * 1.15 + 0.6 * ch + L.metaH + 1.2 * ch, TAP + 12)
	L.rowBtnW = math.max(11 * ch, 110)
	-- LOOKS
	L.chipH = math.max(3.6 * ch, TAP)
	L.chipGap = 0.6 * ch
	local gw = math.floor(rw * A("LabLooksGridFrac"))
	L.looksGrid = rect(0, ly + L.chipH + 0.8 * ch, gw, bh - (ly + L.chipH + 0.8 * ch))
	L.looksChips = rect(0, ly, gw, L.chipH)
	L.looksDetail = rect(gw + L.gap, ly, rw - gw - L.gap, bh - ly)
	L.gridCols = W >= A("LabWideW") and 3 or 2
	L.cellW = (gw - 12 - (L.gridCols - 1) * ch) / L.gridCols
	L.cellH = math.max(0.8 * ch + math.max(3.2 * ch, 14) + 0.6 * ch + L.text.card * 1.2 + 0.4 * ch + L.text.tag * 1.2 + 0.8 * ch, TAP)
	return L
end

return LabLayout
