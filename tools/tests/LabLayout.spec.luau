-- LabLayout.spec v1.0 (Mecha Dino Arena) — LabLayout 1.0 (Lab Revamp v1.0, plan docs/plans/LAB_REVAMP_v1.0.md Task 1, MDA-584).
-- Run in Studio Edit (clones StarterPlayer.StarterPlayerScripts.LabLayout); returns "PASS n" or "FAIL ...".
local src = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("LabLayout")
if not src then return "FAIL require: LabLayout missing" end
local c = src:Clone() c.Parent = src.Parent
local okR, M = pcall(require, c)
c:Destroy()
if not okR then return "FAIL require: " .. tostring(M) end
local fails, passes = {}, 0
local function ok(name, cond, info) if cond then passes += 1 else table.insert(fails, name .. (info and (" (" .. tostring(info) .. ")") or "")) end end
local function near(a, b) return math.abs(a - b) < 0.01 end

ok("version", M.VERSION == "1.0", M.VERSION)
local CASES = {
	{"phone 750x381", 750, 381, true, 58, 150},
	{"SE 667x375", 667, 375, true, 58, 150},
	{"pc 847x616", 847, 616, false, 36, 120},
	{"pc 1280x720", 1280, 720, false, 36, 120},
}
for _, cs in ipairs(CASES) do
	for _, mode in ipairs({"full", "compact"}) do
		for _, sel in ipairs({false, true}) do
			local tag = cs[1] .. " " .. mode .. (sel and " sel" or "")
			local L = M.compute(cs[2], cs[3], {mode = mode, touch = cs[4], topInset = cs[5], topLeftClear = cs[6], slotSel = sel})
			local T = L.minTap
			ok(tag .. " minTap 44", T == 44)
			ok(tag .. " slotW", L.slotW >= T, L.slotW)
			ok(tag .. " saveW", L.saveW >= T, L.saveW)
			ok(tag .. " slotRow.h", L.slotRow.h >= T, L.slotRow.h)
			ok(tag .. " tabs.h", L.tabs.h >= T, L.tabs.h)
			ok(tag .. " tabW", L.tabW >= T, L.tabW)
			ok(tag .. " btnH", L.btnH >= T, L.btnH)
			ok(tag .. " chipH", L.chipH >= T, L.chipH)
			ok(tag .. " close", L.closeS >= T, L.closeS)
			ok(tag .. " backH", L.backH >= T)
			ok(tag .. " rowH", L.rowH >= T, L.rowH)
			ok(tag .. " cellH", L.cellH >= T, L.cellH)
			ok(tag .. " cellW", L.cellW >= T, L.cellW)
			ok(tag .. " stripH", L.stripH >= T, L.stripH)
			ok(tag .. " infoW", L.infoW >= T)
			if sel then ok(tag .. " head holds CANCEL", L.headH >= T, L.headH) end
			-- chips: 4 equal chips across the LOOKS grid width
			ok(tag .. " chipW", (L.looksChips.w - 3 * L.chipGap) / 4 >= T, (L.looksChips.w - 3 * L.chipGap) / 4)
			-- dino strip: 2 rows of 4 across the stage
			ok(tag .. " stripW", (L.left.w - 2 * L.ch - 3 * 0.6 * L.ch) / 4 >= T)
			for k, v in pairs(L.text) do ok(tag .. " text " .. k, v >= L.minText, v) end
			ok(tag .. " widths add up", near(L.left.w + L.gap + L.right.w, L.body.w))
			ok(tag .. " slot row fits", L.slotW * 4 + L.saveW + 4 * L.slotGap <= L.left.w + 0.01)
			ok(tag .. " tabs fit", L.tabW * L.tabCount + (L.tabCount - 1) * L.tabGap <= L.right.w + 0.01)
			ok(tag .. " stage > 0", L.stage.h > 60, L.stage.h)
			ok(tag .. " list > 0", L.list.h > 2 * T, L.list.h)
			ok(tag .. " sheet > 0", L.sheet.h > 3 * T, L.sheet.h)
			ok(tag .. " looks grid > 0", L.looksGrid.h > 2 * T and L.looksDetail.w > 2 * T, L.looksDetail.w)
			ok(tag .. " body inside box", L.body.x >= 0 and L.body.y + L.body.h <= L.box.h + 0.01 and L.body.x + L.body.w <= L.box.w + 0.01)
			local nonneg = true
			for _, r in ipairs({L.box, L.body, L.left, L.right, L.stage, L.slotRow, L.tabs, L.head, L.list, L.sheet, L.looksGrid, L.looksDetail}) do
				if r.w < 0 or r.h < 0 then nonneg = false end
			end
			ok(tag .. " no negative", nonneg)
			ok(tag .. " tab count", L.tabCount == (mode == "compact" and 2 or 5))
			ok(tag .. " compact box", (mode == "compact" and not cs[4]) == L.inset)
		end
	end
end
local P = M.compute(750, 381, {mode = "full", touch = true, topInset = 58, topLeftClear = 150})
local B = M.compute(1280, 720, {mode = "full", touch = false, topInset = 36, topLeftClear = 120})
ok("cards per row phone", P.cardsPerRow == 1, P.cardsPerRow)
ok("cards per row pc", B.cardsPerRow == 2, B.cardsPerRow)
ok("grid cols phone", P.gridCols == 2)
ok("grid cols pc", B.gridCols == 3)
ok("left frac phone", near(P.left.w, math.floor(P.body.w * 0.42)))
ok("left frac pc", near(B.left.w, math.floor(B.body.w * 0.40)))
ok("compact touch is full screen", M.compute(750, 381, {mode = "compact", touch = true}).box.w == 750)
local O = M.compute(750, 381, {mode = "full", touch = true, topInset = 58, topLeftClear = 150, attrs = {LabLeftFrac = 0.5}})
ok("attrs override", O.left.w == math.floor(O.body.w * 0.5), O.left.w)
ok("bad input safe", M.compute(nil, nil, nil).box.w == 1)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ", 1, math.min(#fails, 12)) end
return "PASS " .. passes
