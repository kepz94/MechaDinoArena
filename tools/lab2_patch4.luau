-- lab2_patch4 (Lab 2.0, Studio 2026-11-25 Tutorial test): the tip strip stayed up during the Tutorial's spend step (the coach
-- gui turned on after the Lab drew). Now also hidden while player TutStep > 0 (any Tutorial step). Pairs for
-- src/client/Lab.client.luau.
local PAIRS = {
{[=====[			and player:GetAttribute("LabTipDone") ~= true and not (coach and coach:IsA("ScreenGui") and coach.Enabled)]=====], [=====[			and player:GetAttribute("LabTipDone") ~= true and not (coach and coach:IsA("ScreenGui") and coach.Enabled)
			and (tonumber(player:GetAttribute("TutStep")) or 0) == 0 -- not during the Tutorial (its coach shows the way)]=====]},
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
