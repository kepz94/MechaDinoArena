-- ForceLandscape v1.0 (Mecha Dino Arena) — phones always play sideways (LocalScript, StarterPlayerScripts).
-- Kepu 2026-11-11 19:24: "on mobile I want the game to flip to horizontal on the phone cause sometimes it plays vertical and it
-- might make someone think that's how you play it".
-- Read in Studio 2026-11-11: StarterGui.ScreenOrientation is Sensor (portrait allowed); no script sets an orientation.
-- This script sets this player's PlayerGui.ScreenOrientation = LandscapeSensor (landscape either way round, following how the
-- phone is held; never portrait) at start and again if anything changes it. The place's StarterGui setting is not touched.
-- PC / console are not affected (orientation only applies to phones and tablets).
-- Switch: script attribute ForceLandscapeEnabled (default true, read at start and live; false = the orientation goes back to
--   StarterGui.ScreenOrientation). Diagnostic: LocalPlayer attribute ForceLandscapeVersion, ForceLandscapeOrientation.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local VERSION = "1.0"
local WANT = Enum.ScreenOrientation.LandscapeSensor
local player = Players.LocalPlayer
player:SetAttribute("ForceLandscapeVersion", VERSION)
if script:GetAttribute("ForceLandscapeEnabled") == nil then script:SetAttribute("ForceLandscapeEnabled", true) end

local pg = player:WaitForChild("PlayerGui")

local function apply()
	local want = script:GetAttribute("ForceLandscapeEnabled") ~= false and WANT or StarterGui.ScreenOrientation
	if pg.ScreenOrientation ~= want then pg.ScreenOrientation = want end
	player:SetAttribute("ForceLandscapeOrientation", pg.ScreenOrientation.Name)
end

apply()
pg:GetPropertyChangedSignal("ScreenOrientation"):Connect(apply)
script:GetAttributeChangedSignal("ForceLandscapeEnabled"):Connect(apply)
