-- spawnlock_patch_MechaButtons (MechaButtons): SPAWN_LOCK_v1.0.
local PAIRS = {
{[=====[VERSION = "1.53" -- v1.53 tether aim stamps on PC too (MDA-552)]=====], [=====[VERSION = "1.53" -- v1.53 tether aim stamps on PC too (MDA-552)
VERSION = "1.54" -- v1.54 island spawn lock
-- v1.54 (island spawn lock, plan docs/plans/SPAWN_LOCK_v1.0.md Task 3; Kepu 2026-11-26 "having attack buttons locked on spawn and up until the timer goes down",
--   picks "Island PROTECTED timer", "Attacks only"): while the character attribute HubSafe is true (islet + 3 s guard)
--   a press / aim / tactical start of a slot holding an ATTACK or CONTROL part (HubLockRules.ATTACK_PARTS) is dropped
--   (keys and touch), and a touch slot button shows the padlock when its tap part is one. MOVE / DEFENSE / HEAL /
--   STEALTH / SCOUT / SUPPORT parts keep working. A pull-down attack part sharing a button with a non-attack tap part
--   is blocked but that button shows no padlock (plan red-team, accepted).
--   Same padlock as the Arena countdown. Switch: script attribute HubSafeAttackLockEnabled (default true, read per frame;
--   false = 1.53). Diagnostic: character attribute MechaButtonsHubLockedPresses (count of dropped presses).]=====]},
{[=====[	press, aimStart, tacStart = guard(press), guard(aimStart), guard(tacStart) -- a touch gesture ends in press / aimStart
end
]=====], [=====[	press, aimStart, tacStart = guard(press), guard(aimStart), guard(tacStart) -- a touch gesture ends in press / aimStart
end
local __HL = (function() -- HubLockRules 1.0 (StarterPlayerScripts); missing = no island padlocks
	local ps = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local m = ps and ps:WaitForChild("HubLockRules", 5)
	local ok, r = pcall(function() return m and require(m) end)
	return ok and r or nil
end)()
local function __hubLocked() -- the island spawn lock (HubSafe) is on for this character
	return __HL ~= nil and __HL.locked(char, script:GetAttribute("HubSafeAttackLockEnabled"))
end
do -- v1.54: no attack / control part on the islet or in the 3 s guard
	local function hubGuard(fn)
		return function(n, ...)
			if __hubLocked() and __HL.isAttackPart(slotPart(n)) then
				char:SetAttribute("MechaButtonsHubLockedPresses", (char:GetAttribute("MechaButtonsHubLockedPresses") or 0) + 1)
				return
			end
			return fn(n, ...)
		end
	end
	press, aimStart, tacStart = hubGuard(press), hubGuard(aimStart), hubGuard(tacStart)
end
]=====]},
{[=====[	local on = __prematchLocked()
	for _, sl in ipairs(slots) do setLock(sl.b, on, UDim.new(0.22, 0)) end
]=====], [=====[	local on = __prematchLocked()
	local hub = __hubLocked() -- v1.54
	for n, sl in ipairs(slots) do setLock(sl.b, on or (hub and __HL.isAttackPart(slotPart(n))), UDim.new(0.22, 0)) end
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
