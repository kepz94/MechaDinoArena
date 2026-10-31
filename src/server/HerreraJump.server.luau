-- HerreraJump v1.0 (Mecha Dino Arena) — gives the Herrerasaurus its own leap numbers (JumpTest / JumpServer). MDA-147,
-- plan docs/plans/HERRERA_JUMP_v1.0.md Task 1, mockup docs/mockups/herrera_jump_options.html (Kepu 2026-10-31: option C
-- "Branch reach", 18 studs, no stamina cost; "most mobile yet fragile Dino so no cool down on jumps you can just hold the
-- button and it will spam it", "a strong jump and it will be high for it's size since it climbs trees").
-- Who: every player character with the character attribute Species "Herrera". On spawn (and when Species becomes
--   "Herrera") these are written (the model data has JumpEnabled false, so they are written even where set):
--     JumpEnabled true, JumpWindup 0.08, JumpLaunchPower 75 (tuned in Studio to an 18-stud peak), JumpBoost 10,
--     JumpBoostMinSpeed 2, JumpAirHold true, JumpStaminaCost 0, JumpCooldown 0, SkillBase_JumpCooldown 0
--   (SkillEffects writes JumpCooldown = SkillBase_JumpCooldown x the skill multiplier; base 0 keeps every write 0).
--   Holding JUMP re-leaps on every landing (JumpTest), so no cooldown = a jump per landing.
-- Switch: script attribute HerreraJumpEnabled (default true, read at start; false = the Herrera has no ground jump).
--   The numbers are script attributes too (HerreraJump_<name>), read on each apply, for Studio tuning.
-- Diagnostics: script HerreraJumpVersion, HerreraJumpApplied (count); character HerreraJumpVersion.
local Players = game:GetService("Players")

local VERSION = "1.0"
local SETTINGS = {
	{"JumpEnabled", true}, {"JumpWindup", 0.08}, {"JumpLaunchPower", 75}, {"JumpBoost", 10}, {"JumpBoostMinSpeed", 2},
	{"JumpAirHold", true}, {"JumpStaminaCost", 0}, {"JumpCooldown", 0}, {"SkillBase_JumpCooldown", 0},
}

script:SetAttribute("HerreraJumpVersion", VERSION)
script:SetAttribute("HerreraJumpApplied", 0)
if script:GetAttribute("HerreraJumpEnabled") == nil then script:SetAttribute("HerreraJumpEnabled", true) end
local enabled = script:GetAttribute("HerreraJumpEnabled") ~= false
for _, kv in ipairs(SETTINGS) do
	if script:GetAttribute("HerreraJump_" .. kv[1]) == nil then script:SetAttribute("HerreraJump_" .. kv[1], kv[2]) end
end

local function apply(char)
	if not enabled or char:GetAttribute("Species") ~= "Herrera" then return end
	for _, kv in ipairs(SETTINGS) do
		local v = script:GetAttribute("HerreraJump_" .. kv[1])
		if v == nil then v = kv[2] end
		if char:GetAttribute(kv[1]) ~= v then char:SetAttribute(kv[1], v) end
	end
	char:SetAttribute("HerreraJumpVersion", VERSION)
	script:SetAttribute("HerreraJumpApplied", (script:GetAttribute("HerreraJumpApplied") or 0) + 1)
end

local function onCharacter(char)
	task.defer(function()
		if char.Parent then apply(char) end
	end)
	char:GetAttributeChangedSignal("Species"):Connect(function() apply(char) end)
	-- SkillEffects may write JumpCooldown from its base after the spawn: keep the Herrera's at its setting
	char:GetAttributeChangedSignal("JumpCooldown"):Connect(function()
		if enabled and char:GetAttribute("Species") == "Herrera" then
			local want = script:GetAttribute("HerreraJump_JumpCooldown") or 0
			if char:GetAttribute("JumpCooldown") ~= want then char:SetAttribute("JumpCooldown", want) end
		end
	end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
