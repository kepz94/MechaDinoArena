-- ArenaRules v1.0 (Mecha Dino Arena) — Mecha gameplay rules that belong to no single move script.
-- MDA-8, plan docs/plans/ARENAHUD_v1.0.md Task 3 (Kepu 2026-10-28: "No T-Rex jump").
-- No default jump: every player character without JumpEnabled == true (the T-Rex; the raptor's leap is JumpTest 1.0 with
--   JumpEnabled = true) gets Humanoid.UseJumpPower = true and JumpPower = 0 at spawn, so it cannot jump and Roblox hides
--   its touch jump button. Script attribute ArenaNoDefaultJump (default true): false leaves the Humanoid as it spawned
--   (characters already in the game get their spawn values back when it is switched off).
-- Character attribute ArenaJumpRule: "blocked" (JumpPower 0), "leap" (JumpEnabled, left to JumpTest), "off" (rule off).
-- Script attributes: ArenaRulesVersion, ArenaNoDefaultJump.
local Players = game:GetService("Players")

local VERSION = "1.0"
local DEFAULTS = {ArenaNoDefaultJump = true}
script:SetAttribute("ArenaRulesVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local chars = {} -- [char] = {hum, useJumpPower, jumpPower}

local function apply(char, st)
	if char:GetAttribute("JumpEnabled") == true then
		char:SetAttribute("ArenaJumpRule", "leap")
		return
	end
	if script:GetAttribute("ArenaNoDefaultJump") == false then
		st.hum.UseJumpPower = st.useJumpPower
		st.hum.JumpPower = st.jumpPower
		char:SetAttribute("ArenaJumpRule", "off")
		return
	end
	st.hum.UseJumpPower = true
	st.hum.JumpPower = 0
	char:SetAttribute("ArenaJumpRule", "blocked")
end

local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum or not char.Parent then return end
	local st = {hum = hum, useJumpPower = hum.UseJumpPower, jumpPower = hum.JumpPower}
	chars[char] = st
	apply(char, st)
	char:GetAttributeChangedSignal("JumpEnabled"):Connect(function() apply(char, st) end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

script:GetAttributeChangedSignal("ArenaNoDefaultJump"):Connect(function()
	for char, st in pairs(chars) do apply(char, st) end
end)
