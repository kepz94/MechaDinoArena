-- PachyLook v1.0 (Mecha Dino Arena) — shows the pachy's dome spikes for the Battering Dome star. Pachy Drop 2, plan
-- docs/plans/PACHY_PLAYABLE_v1.0.md "Drop 2" (Kepu 2026-10-30: "the spikes can be the fully upgraded attack stat").
-- Who: every player character with Species "Pachy". PachyModelData builds 10 parts named "Head_spike*" with
--   Transparency 1. While the character attribute PachySpikes (SkillEffects 1.13) is true they get Transparency 0,
--   otherwise 1. Set on the server, so every client sees it. Re-checked when PachySpikes changes and on spawn.
-- Diagnostics (character): PachyLookVersion, PachySpikesShown (count of spikes now visible).
-- Switch: script attribute PachyLookEnabled (default true, read at start; false = spikes stay hidden).
local Players = game:GetService("Players")

local VERSION = "1.0"
if script:GetAttribute("PachyLookEnabled") == nil then script:SetAttribute("PachyLookEnabled", true) end
local enabled = script:GetAttribute("PachyLookEnabled") ~= false
script:SetAttribute("PachyLookVersion", VERSION)

local function spikes(char)
	local list = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:sub(1, 10) == "Head_spike" then table.insert(list, d) end
	end
	return list
end

local function apply(char)
	if char:GetAttribute("Species") ~= "Pachy" then return end
	local show = enabled and char:GetAttribute("PachySpikes") == true
	local n = 0
	for _, p in ipairs(spikes(char)) do
		p.Transparency = show and 0 or 1
		if show then n += 1 end
	end
	char:SetAttribute("PachyLookVersion", VERSION)
	char:SetAttribute("PachySpikesShown", n)
end

local function onCharacter(char)
	char:GetAttributeChangedSignal("PachySpikes"):Connect(function() apply(char) end)
	char:GetAttributeChangedSignal("Species"):Connect(function() apply(char) end)
	task.defer(apply, char)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
