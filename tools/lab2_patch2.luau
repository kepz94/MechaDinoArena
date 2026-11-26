-- lab2_patch2 (Lab 2.0 Studio fixes, 2026-11-25): slot names only on wide slots (phone / small PC show the part's 3D model under
-- the key: "STOMP SHOCKWA VE" split mid-word in a 63 px slot), STATS row white stroke only while its sheet is open.
local PAIRS = {
{[=====[if script:GetAttribute("LabEmoteGridFrac") == nil then script:SetAttribute("LabEmoteGridFrac", 0.45) end -- v2.0
]=====], [=====[if script:GetAttribute("LabEmoteGridFrac") == nil then script:SetAttribute("LabEmoteGridFrac", 0.45) end -- v2.0
if script:GetAttribute("LabSlotNameW") == nil then script:SetAttribute("LabSlotNameW", 90) end -- v2.0: slot width that shows part names
]=====]},
{[=====[		local iz = math.min(sh * 0.42, 3.4 * ch)
		s.icon.Visible = sw >= 70
		s.icon.Position, s.icon.Size = UDim2.fromOffset(sw - iz - 0.3 * ch, 0.3 * ch), UDim2.fromOffset(iz, iz)]=====], [=====[		-- a filled slot shows the part's name when the slot is >= LabSlotNameW px wide, else its 3D model under the key (L2.slotLook)
		L2.slotNames = sw >= (tonumber(script:GetAttribute("LabSlotNameW")) or 90)
		local iz = math.max(math.min(sh - kS * 1.15 - ch, sw - 0.8 * ch), 8)
		s.icon.Position, s.icon.Size = UDim2.fromOffset((sw - iz) / 2, 0.5 * ch + kS * 1.15), UDim2.fromOffset(iz, iz)]=====]},
{[=====[		s.key.TextColor3 = slotOf(n) and ORANGE or (on and YELLOW or MUTED)
	end]=====], [=====[		s.key.TextColor3 = slotOf(n) and ORANGE or (on and YELLOW or MUTED)
		local filled = slotOf(n) ~= nil
		s.name.Visible = (not filled) or L2.slotNames == true
		s.icon.Visible = filled and L2.slotNames ~= true
	end]=====]},
{[=====[		if selected == id then
			st = stroke(b, WHITE, 0, 2.5)]=====], [=====[		if selected == id and L2.sheet then -- v2.0: white only while its sheet is open
			st = stroke(b, WHITE, 0, 2.5)]=====]},
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
