-- spawnlock_patch_TheriAttackTest (TheriAttackTest 1.5): SPAWN_LOCK_v1.0.
local PAIRS = {
{[=====[VERSION = "1.4" -- v1.4 pre-match lock]=====], [=====[VERSION = "1.4" -- v1.4 pre-match lock
VERSION = "1.5" -- v1.5 island spawn lock
-- v1.5 (island spawn lock, plan docs/plans/SPAWN_LOCK_v1.0.md Task 2; Kepu 2026-11-26 "having attack buttons locked on spawn and up until the timer goes down",
--   picks "Island PROTECTED timer", "Attacks only"): the pre-match lock check also says locked while the character
--   attribute HubSafe is true (HubServer: on the islet or the 3 s PROTECTED guard after leaving it), so a press does
--   nothing there. Movement keeps working. Switch: script attribute HubSafeAttackLockEnabled (default true, read per
--   press; false = 1.4).
if script:GetAttribute("HubSafeAttackLockEnabled") == nil then script:SetAttribute("HubSafeAttackLockEnabled", true) end]=====]},
{[=====[	return (tonumber(char:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()
]=====], [=====[	return (tonumber(char:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()
		or (script:GetAttribute("HubSafeAttackLockEnabled") ~= false and char:GetAttribute("HubSafe") == true) -- island spawn lock
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
