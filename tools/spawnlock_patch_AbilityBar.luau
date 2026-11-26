-- spawnlock_patch_AbilityBar (AbilityBar): SPAWN_LOCK_v1.0.
local PAIRS = {
{[=====[VERSION = "1.44" -- v1.44 pre-match padlocks]=====], [=====[VERSION = "1.44" -- v1.44 pre-match padlocks
VERSION = "1.45" -- v1.45 island spawn padlocks
-- v1.45 (island spawn lock, plan docs/plans/SPAWN_LOCK_v1.0.md Task 3; Kepu 2026-11-26 "having attack buttons locked on spawn and up until the timer goes down",
--   picks "Island PROTECTED timer", "Attacks only"): while the character attribute HubSafe is true (islet + 3 s guard)
--   the attack move tiles (HubLockRules.ATTACK_MOVES; not LEAP / HOP / JUMP) and the slot tiles holding an ATTACK or
--   CONTROL part (HubLockRules.ATTACK_PARTS) show the padlock. The press itself is dropped by the attack / mecha scripts.
--   Same padlock as the Arena countdown. Switch: script attribute HubSafeAttackLockEnabled (default true, read per frame;
--   false = 1.44). Diagnostic: character attribute AbilityBarHubLocked (true while any tile shows it).]=====]},
{[=====[table.insert(conns, RunService.RenderStepped:Connect(function() -- v1.44
	local on = __prematchLocked()
	for _, e in ipairs(tiles) do setLock(e.t and e.t.f, on, UDim.new(0.22, 0)) end
]=====], [=====[local __HL = (function() -- HubLockRules 1.0 (StarterPlayerScripts); missing = no island padlocks
	local ps = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local m = ps and ps:WaitForChild("HubLockRules", 5)
	local ok, r = pcall(function() return m and require(m) end)
	return ok and r or nil
end)()
local function __hubLocked() -- the island spawn lock (HubSafe) is on for this character
	return __HL ~= nil and __HL.locked(char, script:GetAttribute("HubSafeAttackLockEnabled"))
end
table.insert(conns, RunService.RenderStepped:Connect(function() -- v1.44
	local on = __prematchLocked()
	local hub, hubAny = __hubLocked(), false -- v1.45
	for _, e in ipairs(tiles) do
		local hubT = hub and ((e.kind == "move" and __HL.isAttackMove(e.id)) or (e.kind == "slot" and __HL.isAttackPart(e.part)))
		if hubT then hubAny = true end
		setLock(e.t and e.t.f, on or hubT, UDim.new(0.22, 0))
	end
	show("AbilityBarHubLocked", hubAny) -- v1.45
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
