-- spawnlock_patch_ArenaTouch (ArenaTouch): SPAWN_LOCK_v1.0.
local PAIRS = {
{[=====[VERSION = "1.21" -- v1.21 pre-match padlocks]=====], [=====[VERSION = "1.21" -- v1.21 pre-match padlocks
VERSION = "1.22" -- v1.22 island spawn padlocks
-- v1.22 (island spawn lock, plan docs/plans/SPAWN_LOCK_v1.0.md Task 3; Kepu 2026-11-26 "having attack buttons locked on spawn and up until the timer goes down",
--   picks "Island PROTECTED timer", "Attacks only"): while the character attribute HubSafe is true (islet + 3 s guard)
--   the main attack buttons (HubLockRules.ATTACK_BUTTONS: Bite, PounceMain, Ram, HeadbuttMain, SlashMain, TenoMain,
--   TheriMain, DiloMain, TrooMain) show the padlock; JUMP / RUN do not. The press itself is dropped by each attack script.
--   Same padlock as the Arena countdown. Switch: script attribute HubSafeAttackLockEnabled (default true, read per frame;
--   false = 1.21). Diagnostic: character attribute ArenaTouchHubLocked (true while any button shows it).]=====]},
{[=====[RunService.RenderStepped:Connect(function() -- v1.21
	local on = __prematchLocked()
]=====], [=====[local __HL = (function() -- HubLockRules 1.0 (StarterPlayerScripts); missing = no island padlocks
	local ps = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local m = ps and ps:WaitForChild("HubLockRules", 5)
	local ok, r = pcall(function() return m and require(m) end)
	return ok and r or nil
end)()
local function __hubLocked() -- the island spawn lock (HubSafe) is on for this character
	return __HL ~= nil and __HL.locked(char, script:GetAttribute("HubSafeAttackLockEnabled"))
end
RunService.RenderStepped:Connect(function() -- v1.21
	local on = __prematchLocked()
	local hub, hubAny = __hubLocked(), false -- v1.22
]=====]},
{[=====[			setLock(b, on, b:FindFirstChildOfClass("UICorner").CornerRadius)
		end
	end
	if char:GetAttribute("ArenaTouchLocked") ~= on then char:SetAttribute("ArenaTouchLocked", on) end
]=====], [=====[			local hubB = hub and __HL.isAttackButton(b.Name) -- v1.22
			if hubB then hubAny = true end
			setLock(b, on or hubB, b:FindFirstChildOfClass("UICorner").CornerRadius)
		end
	end
	if char:GetAttribute("ArenaTouchLocked") ~= on then char:SetAttribute("ArenaTouchLocked", on) end
	if char:GetAttribute("ArenaTouchHubLocked") ~= hubAny then char:SetAttribute("ArenaTouchHubLocked", hubAny) end -- v1.22
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
