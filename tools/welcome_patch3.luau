-- welcome_patch3 (Studio check 2026-11-26, Tutorial 1.7): the swords / gear drew as colour emoji (the star stayed yellow), so the
-- icon line is dropped on all 3 tiles (plan fallback); tiles get a fitted height (they were half empty) and bigger text.
local PAIRS = {
{[=====[	local th = cq(13.5, 96)]=====], [=====[	local th = cq(9.5, 66) -- Studio check: fitted (13.5 cqw left the tiles half empty)]=====]},
{[=====[		list(card, nil, px(0.4, 3)).VerticalAlignment = Enum.VerticalAlignment.Top
		local parts = {
			text(card, t[1], "black", cq(3.2, 22), C.yellow, {LayoutOrder = 1, TextWrapped = false, TextTransparency = 1}),
			text(card, t[2], "title", cq(1.9, 14), C.white, {LayoutOrder = 2, TextTransparency = 1}),
			text(card, t[3], "body", cq(1.15, 10), C.muted, {LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
				TextTransparency = 1}),
		}]=====], [=====[		list(card, nil, px(0.5, 4)) -- Studio check: centred, no icon line (the emoji ignored the yellow)
		local parts = {
			text(card, t[2], "title", cq(2.2, 15), C.yellow, {LayoutOrder = 2, TextTransparency = 1}),
			text(card, t[3], "body", cq(1.4, 11), C.text, {LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
				TextTransparency = 1}),
		}]=====]},
{[=====[	local TILES = {{"\u{2694}", "FIGHT", "Squad battles on the island"}, {"\u{2699}", "UPGRADE", "Mecha parts and skill points"},
		{"\u{2605}", "COLLECT", "7 dinos, skins, emotes, trails"}}]=====], [=====[	local TILES = {{"", "FIGHT", "Squad battles on the island"}, {"", "UPGRADE", "Mecha parts and skill points"},
		{"", "COLLECT", "7 dinos, skins, emotes, trails"}} -- Studio check: no icons (see the tile text below)]=====]},
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
