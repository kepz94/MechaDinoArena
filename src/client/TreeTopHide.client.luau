-- TreeTopHide v1.2 (Mecha Dino Arena) — Tree Stalker III: "On a tree top, enemies cannot see your name or health bar"
-- (LocalScript in StarterPlayerScripts, all devices). SkillTree 1.37 / SkillEffects 1.26, plan docs/plans/STAT_LINES_v1.0.md
-- (Kepu 2026-10-31 picked the new row Tree Stalker).
-- Every frame, for every OTHER player's character with the character attribute TreeTopHidden = true (SkillEffects 1.26)
--   and ClimbState = "top" (ClimbServer): each BillboardGui under that character gets PlayerToHideFrom = this player (so
--   this client does not draw it; Enabled is left alone, so CloakFX's own hide / restore of Enabled is not disturbed). The
--   value it had is kept, and put back as soon as the character is no longer hidden (or the gui is new and was never
--   touched). The Humanoid name / health display is left alone (the Herrera's is already None).
-- Your own dino is never hidden on your own screen.
-- Switch: script attribute TreeTopHideEnabled (default true, read each frame; false = everything put back, nothing hidden).
-- Diagnostics: script TreeTopHideVersion, TreeTopHidCount (characters hidden right now); player TreeTopHideVersion.
-- v1.1 (Herrera Smoke Pods, MDA-152, HerreraMovesServer 1.0): a character with SmokeHidden = true (inside its own smoke
--   cloud) is hidden the same way. Switch: script attribute TreeTopHideSmokeEnabled (default true, read each frame; false
--   = 1.0).
-- v1.2 (Arena squads, MDA-160, plan docs/plans/SQUADS_v1.0.md Task S3, ADR-006; Kepu 2026-10-31 "turning friendly fire off"): a squadmate's name / health bar is never hidden from you (tree
--   top or smoke): wantsHide is false for your squadmates.
--   Squadmates = ReplicatedStorage.SquadShared.SquadRules (SquadServer 1.0's copy) sameChar. Switch: script attribute
--   TreeTopHideSquadEnabled (default true, read at each check; false = 1.1).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.2"
local me = Players.LocalPlayer
script:SetAttribute("TreeTopHideVersion", VERSION)
me:SetAttribute("TreeTopHideVersion", VERSION)
if script:GetAttribute("TreeTopHideEnabled") == nil then script:SetAttribute("TreeTopHideEnabled", true) end
script:SetAttribute("TreeTopHidCount", 0)

local hidden = {} -- [char] = {[BillboardGui] = PlayerToHideFrom before}

local function restore(char)
	local guis = hidden[char]
	if not guis then return end
	for g, before in pairs(guis) do
		if g.Parent and g.PlayerToHideFrom == me then g.PlayerToHideFrom = before or nil end -- false = was nil
	end
	hidden[char] = nil
end

-- v1.2: squadmates are never targets (ReplicatedStorage.SquadShared.SquadRules, loaded on first use)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TreeTopHideSquadEnabled") == false then return false end
	if not squadMod then
		local sh = game:GetService("ReplicatedStorage"):FindFirstChild("SquadShared")
		local m = sh and sh:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b)
end
local function wantsHide(char)
	if me.Character and squadmate(me.Character, char) then return false end -- v1.2
	if script:GetAttribute("TreeTopHideSmokeEnabled") ~= false and char:GetAttribute("SmokeHidden") == true then return true end -- v1.1
	return char:GetAttribute("TreeTopHidden") == true and char:GetAttribute("ClimbState") == "top"
end

RunService.Heartbeat:Connect(function()
	local on = script:GetAttribute("TreeTopHideEnabled") ~= false
	local seen = {}
	local count = 0
	if on then
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p ~= me and p.Character
			if char and char.Parent and wantsHide(char) then
				seen[char] = true
				count += 1
				local guis = hidden[char]
				if not guis then
					guis = {}
					hidden[char] = guis
				end
				for _, d in ipairs(char:GetDescendants()) do
					if d:IsA("BillboardGui") and guis[d] == nil then
						guis[d] = d.PlayerToHideFrom or false
						d.PlayerToHideFrom = me
					end
				end
			end
		end
	end
	for char in pairs(hidden) do
		if not seen[char] then restore(char) end
	end
	if script:GetAttribute("TreeTopHidCount") ~= count then script:SetAttribute("TreeTopHidCount", count) end
end)
