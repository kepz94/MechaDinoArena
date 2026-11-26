-- lablayout_patch1 (LabLayout 1.0 phone fix, Studio iPhone emulation 2026-11-25): the LOOKS filter chips span the whole right
-- column (on EMOTES the grid is 45% wide and the chips were 42 px); grid and detail start under them. Pairs for
-- src/client/LabLayout.luau.
local PAIRS = {
{[=====[	local gw = math.floor(rw * A("LabLooksGridFrac"))
	L.looksGrid = rect(0, ly + L.chipH + 0.8 * ch, gw, bh - (ly + L.chipH + 0.8 * ch))
	L.looksChips = rect(0, ly, gw, L.chipH)
	L.looksDetail = rect(gw + L.gap, ly, rw - gw - L.gap, bh - ly)]=====], [=====[	local gw = math.floor(rw * A("LabLooksGridFrac"))
	local gy = ly + L.chipH + 0.8 * ch
	L.looksChips = rect(0, ly, rw, L.chipH) -- the chips span the column; grid and detail start under them
	L.looksGrid = rect(0, gy, gw, bh - gy)
	L.looksDetail = rect(gw + L.gap, gy, rw - gw - L.gap, bh - gy)]=====]},
{[=====[--   LabTwoCardsW 560 (right column width for 2 cards a row), LabLooksGridFrac 0.6, LabArtFrac 0.26 (row card art width / card).
]=====], [=====[--   LabTwoCardsW 560 (right column width for 2 cards a row), LabLooksGridFrac 0.6, LabArtFrac 0.26 (row card art width / card).
-- Studio fix 2026-11-25: the LOOKS chips span the whole right column (EMOTES grid at 45% left them 42 px wide on a phone).
]=====]},
}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
