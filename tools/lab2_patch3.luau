-- lab2_patch3 (Lab 2.0 phone fixes, Studio iPhone 17 Pro emulation 2026-11-25): SAVE's second line on 2 lines when the tile is
-- narrow ("FOR PRE-GAME" showed as "FOR"); every detail button at least the tap size (the LOOKS detail buttons kept their own
-- max(5.6 ch, 34) = 34 px). Pairs for src/client/Lab.client.luau.
local PAIRS = {
{[=====[		local y0 = (sh - tS - sS - 0.4 * ch) / 2
		saveTop.Position, saveTop.Size = UDim2.fromOffset(0.3 * ch, y0), UDim2.new(1, -0.6 * ch, 0, tS + 2)
		saveSub.Position, saveSub.Size = UDim2.fromOffset(0.3 * ch, y0 + tS + 0.4 * ch), UDim2.new(1, -0.6 * ch, 0, sS + 2)]=====], [=====[		local subH = (L.saveW < 80 and 2 or 1) * sS * 1.1 -- a narrow tile (phone) wraps "FOR PRE-GAME" on 2 lines
		local y0 = (sh - tS - subH - 0.4 * ch) / 2
		saveSub.TextWrapped = true
		saveTop.Position, saveTop.Size = UDim2.fromOffset(0.3 * ch, y0), UDim2.new(1, -0.6 * ch, 0, tS + 2)
		saveSub.Position, saveSub.Size = UDim2.fromOffset(0.3 * ch, y0 + tS + 0.4 * ch), UDim2.new(1, -0.6 * ch, 0, subH + 2)]=====]},
{[=====[	player:SetAttribute("LabSheet", L2.sheet == true)
	local minT = tonumber(script:GetAttribute("LabMinText")) or 11]=====], [=====[	for _, c in ipairs(detail:GetChildren()) do -- detail buttons drawn with their own height (LOOKS): at least the tap size
		if c:IsA("GuiButton") and c.Size.Y.Scale == 0 and c.Size.Y.Offset < S.L.minTap then
			c.Size = UDim2.new(c.Size.X.Scale, c.Size.X.Offset, 0, S.L.btnH)
		end
	end
	player:SetAttribute("LabSheet", L2.sheet == true)
	local minT = tonumber(script:GetAttribute("LabMinText")) or 11]=====]},
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
