-- tut_lab2_patch (Tutorial 1.5 -> 1.6, Lab Revamp v1.0 T7, MDA-590): the Lab coach on Lab 2.0. Pairs for
-- src/client/Tutorial.client.luau.
local PAIRS = {
{[=====[VERSION = "1.5" -- v1.5 showcase select screen + attack / ability cards
]=====], [=====[VERSION = "1.5" -- v1.5 showcase select screen + attack / ability cards
VERSION = "1.6" -- v1.6 Lab coach on Lab 2.0 (Lab Revamp v1.0)
-- v1.6 (Lab Revamp v1.0 Task 7, MDA-590, plan docs/plans/LAB_REVAMP_v1.0.md red-team R1): while the Lab is 2.0 or newer
--   (player LabVersion) and script attribute TutorialLab2Enabled ~= false (default true, read per frame), the equip and spend
--   coach steps point at Lab 2.0's buttons (the 1.3 / 1.4 targets stay for an older Lab):
--   * equip (ABILITIES): the detail sheet open (player LabSheet) -> "TAP BACK" on its Back button; a filled slot selected ->
--     "TAP CANCEL" (Lab 2.0 would put the part over it); else the first of this dino's button parts that is not in a slot and
--     whose card button (Card_<id>.Actions.Btn) reads EQUIP or PUT ON -> "TAP EQUIP" / "TAP PUT ON <key>" with "n/N EQUIPPED".
--     The slot tag after each equip (1.4: no finger, no tap) as before.
--   * spend (STATS): the sheet open -> "TAP BACK"; else the first stat row not maxed whose own button (Card_<id>.Actions.Btn)
--     reads BUY / UPGRADE -> "TAP BUY" / "TAP UPGRADE", "-1 PT".
--   The buttons are found under that card (Lab 2.0 has an Actions frame on every card; 1.3's labActionBtn took the first).
]=====]},
{[=====[local function drawCoach(s)
	coachStop()]=====], [=====[LC2 = {} -- v1.6: Lab 2.0 coach targets (script-global, so the main chunk gets no new locals)
function LC2.on()
	return script:GetAttribute("TutorialLab2Enabled") ~= false and (tonumber(player:GetAttribute("LabVersion")) or 0) >= 2
end
function LC2.cardBtn(id)
	local card = labFind("Card_" .. id, "GuiButton")
	local acts = card and card:FindFirstChild("Actions")
	local b = acts and acts:FindFirstChild("Btn")
	local t = b and b:FindFirstChild("T")
	return b, t and t:IsA("TextLabel") and t.Text or ""
end
function LC2.equip(dino, n, filled)
	if player:GetAttribute("LabSheet") == true then return labFind("Back", "GuiButton"), "TAP BACK" end
	local ss = tonumber(player:GetAttribute("LabSlotSel")) or 0
	if ss > 0 and slotOf(ss) ~= "" then return labFind("Cancel", "GuiButton"), "TAP CANCEL" end
	local inSlot = {}
	for k = 1, 4 do inSlot[slotOf(k)] = true end
	for _, id in ipairs(partsOf(dino, true)) do
		if not inSlot[id] then
			local b, txt = LC2.cardBtn(id)
			if b and (txt:sub(1, 5) == "EQUIP" or txt:sub(1, 6) == "PUT ON") then
				return b, "TAP " .. txt, ("%d/%d EQUIPPED"):format(filled, n)
			end
		end
	end
	return nil, "TAP A PART"
end
function LC2.spend(dino)
	if player:GetAttribute("LabSheet") == true then return labFind("Back", "GuiButton"), "TAP BACK" end
	for _, id in ipairs(statsOf(dino)) do
		if pathStep(id) < 4 then
			local b, txt = LC2.cardBtn(id)
			if b and (txt:sub(1, 3) == "BUY" or txt:sub(1, 7) == "UPGRADE") then
				return b, txt:sub(1, 3) == "BUY" and "TAP BUY" or "TAP UPGRADE", "-1 PT"
			end
		end
	end
	return nil, "TAP A STAT"
end
local function drawCoach(s)
	coachStop()]=====]},
{[=====[			elseif tab ~= "parts" then
				target, big = labFind("Parts", "GuiButton"), "TAP ABILITIES"
			else]=====], [=====[			elseif tab ~= "parts" then
				target, big = labFind("Parts", "GuiButton"), "TAP ABILITIES"
			elseif LC2.on() then -- v1.6: Lab 2.0
				target, big, small = LC2.equip(dino, n, filled)
			else]=====]},
{[=====[			elseif tab ~= "stats" then
				target, big = labFind("Stats", "GuiButton"), "TAP STATS"
			else]=====], [=====[			elseif tab ~= "stats" then
				target, big = labFind("Stats", "GuiButton"), "TAP STATS"
			elseif LC2.on() then -- v1.6: Lab 2.0
				target, big, small = LC2.spend(dino)
			else]=====]},
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
