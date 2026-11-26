-- welcome_patch4 (Tutorial 1.7.1, Kepu 2026-11-26 03:05 live: "this didn't load the model all the way on the egg hatch, it's cut off
-- at the top", Therizino): the reveal's dino view keeps dinoView's 30 degree camera, too narrow for tall / long dinos. Measured in
-- Studio over a full turn (1.00 = the frame edge) at 30: Therizino top 1.20 / bottom 1.42, Pachy top 1.07 / side 1.17, Teno side
-- 1.23, Dilo top 1.06; at 44 every dino is inside (worst Therizino bottom 0.95). The reveal sets its camera to TutRevealFov.
local PAIRS = {
{[=====[VERSION = "1.7" -- v1.7 welcome screen, dino passives, JUMP parts in step 6]=====], [=====[VERSION = "1.7" -- v1.7 welcome screen, dino passives, JUMP parts in step 6
VERSION = "1.7.1" -- v1.7.1 the reveal's dino fits (wider camera)
-- v1.7.1 (Kepu 2026-11-26 03:05 live, Therizino "cut off at the top"): drawReveal sets its dino view's camera FieldOfView to the
--   script attribute TutRevealFov (default 44; dinoView's own 30 cut Therizino, Pachy, Teno and Dilo over a turn, measured in
--   Studio). Switch: script attribute TutorialRevealFitEnabled (default true, read per draw; false = 1.7).]=====]},
{[=====[	local vf, turn = dinoView(holder, rolled)
	-- the panel]=====], [=====[	local vf, turn = dinoView(holder, rolled)
	if script:GetAttribute("TutorialRevealFitEnabled") ~= false and vf.CurrentCamera then -- v1.7.1: tall / long dinos fit
		vf.CurrentCamera.FieldOfView = tonumber(script:GetAttribute("TutRevealFov")) or 44
	end
	-- the panel]=====]},
{[=====[if script:GetAttribute("TutJumpPartSkipAfter") == nil then script:SetAttribute("TutJumpPartSkipAfter", 20) end]=====], [=====[if script:GetAttribute("TutJumpPartSkipAfter") == nil then script:SetAttribute("TutJumpPartSkipAfter", 20) end
if script:GetAttribute("TutorialRevealFitEnabled") == nil then script:SetAttribute("TutorialRevealFitEnabled", true) end -- v1.7.1
if script:GetAttribute("TutRevealFov") == nil then script:SetAttribute("TutRevealFov", 44) end -- v1.7.1]=====]},
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
