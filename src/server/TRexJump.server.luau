-- TRexJump v1.0 (Mecha Dino Arena) — gives the T-Rex the shared leap (JumpTest / JumpServer / JumpPose). MDA-146, plan
-- docs/plans/PHONE_LAYOUT_v1.0.md Task 5, mockup docs/mockups/phone_layout_unified_options.html option A (Kepu
-- 2026-10-31 "A · T-Rex gets JUMP"; it replaces the 2026-10-28 "no T-Rex jump").
-- Who: every player character with the character attribute Species "TRex" (the StarterCharacter T-Rex). On spawn (and
--   when Species becomes "TRex") each setting below is written only where the character has no value yet, so a value
--   set elsewhere (skills, tests) wins:
--     JumpEnabled true, JumpWindup 0.2, JumpLaunchPower 50, JumpBoost 6, JumpBoostMinSpeed 2, JumpAirHold true,
--     JumpStaminaCost 0, JumpCooldown 1
--   = a lower, slower, heavier leap than the raptor / pachy (0.12 / 59 / 10 / 0.5). Tunable attributes (Kepu confirms
--   the feel). ArenaRules already gives JumpEnabled dinos their JumpPower back; the phone JUMP button (ArenaTouch 1.7)
--   and the PC JUMP tile (AbilityBar 1.15) follow JumpEnabled.
-- Switch: script attribute TRexJumpEnabled (default true, read at start; false = the T-Rex has no jump, as before).
-- Diagnostics: script TRexJumpVersion, TRexJumpApplied (count); character TRexJumpVersion.
local Players = game:GetService("Players")

local VERSION = "1.0"
local SETTINGS = {
	{"JumpEnabled", true}, {"JumpWindup", 0.2}, {"JumpLaunchPower", 50}, {"JumpBoost", 6}, {"JumpBoostMinSpeed", 2},
	{"JumpAirHold", true}, {"JumpStaminaCost", 0}, {"JumpCooldown", 1},
}

script:SetAttribute("TRexJumpVersion", VERSION)
script:SetAttribute("TRexJumpApplied", 0)
if script:GetAttribute("TRexJumpEnabled") == nil then script:SetAttribute("TRexJumpEnabled", true) end
local enabled = script:GetAttribute("TRexJumpEnabled") ~= false

local function apply(char)
	if not enabled or char:GetAttribute("Species") ~= "TRex" or char:GetAttribute("TRexJumpVersion") then return end
	for _, kv in ipairs(SETTINGS) do
		if char:GetAttribute(kv[1]) == nil then
			char:SetAttribute(kv[1], kv[2])
		end
	end
	char:SetAttribute("TRexJumpVersion", VERSION)
	script:SetAttribute("TRexJumpApplied", (script:GetAttribute("TRexJumpApplied") or 0) + 1)
end

local function onCharacter(char)
	task.defer(function()
		if char.Parent then apply(char) end
	end)
	char:GetAttributeChangedSignal("Species"):Connect(function() apply(char) end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
