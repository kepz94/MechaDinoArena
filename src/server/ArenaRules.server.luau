-- ArenaRules v1.2 (Mecha Dino Arena) — Mecha gameplay rules that belong to no single move script.
-- MDA-8, plan docs/plans/ARENAHUD_v1.0.md Task 3 (Kepu 2026-10-28: "No T-Rex jump").
-- No default jump: every player character without JumpEnabled == true (the T-Rex; the raptor's leap is JumpTest 1.0 with
--   JumpEnabled = true) gets Humanoid.UseJumpPower = true and JumpPower = 0 at spawn, so it cannot jump and Roblox hides
--   its touch jump button. Script attribute ArenaNoDefaultJump (default true): false leaves the Humanoid as it spawned
--   (characters already in the game get their spawn values back when it is switched off).
-- Character attribute ArenaJumpRule: "blocked" (JumpPower 0), "leap" (JumpEnabled, left to JumpTest), "off" (rule off).
-- Script attributes: ArenaRulesVersion, ArenaNoDefaultJump, ArenaAutoRun (1.1), ArenaRaptorNoBite (1.2).
-- v1.1 (auto-run; Kepu 2026-10-28: "Let's make it auto run. Forget walking there's no point in creep and walk speed"):
--   script attribute ArenaAutoRun (default true) sets the character attribute AutoRun = true on every player character
--   (SprintTest 1.5 then always runs; ArenaTouch 1.1 hides RUN); false sets AutoRun = false (hold-to-run as before).
-- v1.2 (Kepu 2026-10-28: "for the raptor the main button should be pounce. remove the bite for the raptor", "no bite at
--   all"; rule: "each dino will have one attack button, the rest will be mecha add ons"): script attribute
--   ArenaRaptorNoBite (default true) sets BiteEnabled = false on player characters whose Species is "Raptor" (BiteTest
--   and BiteServer already refuse bites while BiteEnabled is false; ArenaTouch 1.2 then shows POUNCE as the main
--   button). false gives the raptor its bite back (BiteEnabled = true). Other species are not touched. Character
--   attribute ArenaBiteRule: "raptorNoBite" (bite removed), "raptorBite" (rule off), "notRaptor".
local Players = game:GetService("Players")

local VERSION = "1.2"
local DEFAULTS = {ArenaNoDefaultJump = true, ArenaAutoRun = true, ArenaRaptorNoBite = true}
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

-- v1.2: the raptor has one attack (pounce); its bite is off while ArenaRaptorNoBite
local function applyBite(char)
	if char:GetAttribute("Species") ~= "Raptor" then
		char:SetAttribute("ArenaBiteRule", "notRaptor")
		return
	end
	local noBite = script:GetAttribute("ArenaRaptorNoBite") ~= false
	char:SetAttribute("BiteEnabled", not noBite)
	char:SetAttribute("ArenaBiteRule", noBite and "raptorNoBite" or "raptorBite")
end

local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum or not char.Parent then return end
	local st = {hum = hum, useJumpPower = hum.UseJumpPower, jumpPower = hum.JumpPower}
	chars[char] = st
	char:SetAttribute("AutoRun", script:GetAttribute("ArenaAutoRun") ~= false) -- v1.1
	applyBite(char) -- v1.2
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

script:GetAttributeChangedSignal("ArenaAutoRun"):Connect(function() -- v1.1
	for char in pairs(chars) do char:SetAttribute("AutoRun", script:GetAttribute("ArenaAutoRun") ~= false) end
end)
script:GetAttributeChangedSignal("ArenaRaptorNoBite"):Connect(function() -- v1.2
	for char in pairs(chars) do applyBite(char) end
end)
script:GetAttributeChangedSignal("ArenaNoDefaultJump"):Connect(function()
	for char, st in pairs(chars) do apply(char, st) end
end)
