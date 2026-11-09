-- TRexJump v1.1 (Mecha Dino Arena) — gives the T-Rex the shared leap (JumpTest / JumpServer / JumpPose). MDA-146, plan
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
-- v1.1 (MDA-364, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 "the cooldowns for things like jumping ... need to be
--   lowered" -> "Yes, every dino"): JumpCooldown 1 -> script attribute TRexJumpCooldown (default 0.25). Because SkillEffects
--   captures SkillBase_JumpCooldown at spawn (its own default 0.5 when the character has none yet) and then writes JumpCooldown
--   = base x Sprint Legs III's moveCdMul, the apply also writes SkillBase_JumpCooldown = TRexJumpCooldown and JumpCooldown =
--   it x SkillEffects' last multiplier (JumpCooldown / old SkillBase_JumpCooldown, 1 when unknown), even where set (the
--   HerreraJump pattern), so the T-Rex's base is 0.25 whichever script runs first. Switch: script attribute
--   TRexJumpBalanceEnabled (default true, read at each apply; false = 1.0: JumpCooldown 1 only where unset).
local Players = game:GetService("Players")

local VERSION = "1.1"
local SETTINGS = {
	{"JumpEnabled", true}, {"JumpWindup", 0.2}, {"JumpLaunchPower", 50}, {"JumpBoost", 6}, {"JumpBoostMinSpeed", 2},
	{"JumpAirHold", true}, {"JumpStaminaCost", 0}, {"JumpCooldown", 1},
}

script:SetAttribute("TRexJumpVersion", VERSION)
script:SetAttribute("TRexJumpApplied", 0)
if script:GetAttribute("TRexJumpEnabled") == nil then script:SetAttribute("TRexJumpEnabled", true) end
if script:GetAttribute("TRexJumpBalanceEnabled") == nil then script:SetAttribute("TRexJumpBalanceEnabled", true) end -- v1.1
if script:GetAttribute("TRexJumpCooldown") == nil then script:SetAttribute("TRexJumpCooldown", 0.25) end -- v1.1
local enabled = script:GetAttribute("TRexJumpEnabled") ~= false

local function apply(char)
	if not enabled or char:GetAttribute("Species") ~= "TRex" or char:GetAttribute("TRexJumpVersion") then return end
	local balance = script:GetAttribute("TRexJumpBalanceEnabled") ~= false -- v1.1
	for _, kv in ipairs(SETTINGS) do
		if char:GetAttribute(kv[1]) == nil and not (balance and kv[1] == "JumpCooldown") then
			char:SetAttribute(kv[1], kv[2])
		end
	end
	if balance then -- v1.1: the T-Rex's own base, kept through SkillEffects' multiplier
		local cd = tonumber(script:GetAttribute("TRexJumpCooldown")) or 0.25
		local oldBase, cur = tonumber(char:GetAttribute("SkillBase_JumpCooldown")), tonumber(char:GetAttribute("JumpCooldown"))
		local mul = (oldBase and oldBase > 0 and cur) and cur / oldBase or 1
		char:SetAttribute("SkillBase_JumpCooldown", cd)
		char:SetAttribute("JumpCooldown", math.floor(cd * mul * 100 + 0.5) / 100)
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
