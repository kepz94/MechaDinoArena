-- InkBlind v1.0 (Mecha Dino Arena) — the black screen of the pachy's Ink Shooter on the inked player's own client.
-- MDA-128, plan docs/plans/PACHY_PARTS_B3_v1.0.md; Kepu 2026-10-30: "blinds your enemy for 2 seconds. Turns their
--   screen black" -> "fully black", the HUD stays (mockup docs/mockups/pachy_parts_b3_options.html "Get inked").
-- InkServer 1.0 sets this character's InkedUntil (server time) and InkedAt (last). While InkedUntil is in the future the
--   game view is covered: ScreenGui "InkBlind" (ResetOnSpawn, IgnoreGuiInset, DisplayOrder -2: under every HUD gui,
--   ArenaTouch -1 and the touch controls included) -> Frame "Black" (full screen, colour 11,11,18, Active false so
--   touches pass through) and TextLabel "Msg" ("INKED", white, 15% see-through, Fredoka, centre at 45% height). It shows
--   at once and fades out over FADE (0.25) s when InkedUntil passes; a new ink while it shows extends it.
-- Switch: character attribute InkBlindEnabled (default true; false = nothing shown).
-- Diagnostics (character, this client): InkBlindVersion, InkBlindShowing (true / false), InkBlindCount (times shown).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
local FADE = 0.25
local INK = Color3.fromRGB(11, 11, 18)

local char = script.Parent
local player = Players.LocalPlayer
if Players:GetPlayerFromCharacter(char) ~= player then return end
char:SetAttribute("InkBlindVersion", VERSION)
char:SetAttribute("InkBlindShowing", false)

local gui = Instance.new("ScreenGui")
gui.Name = "InkBlind"
gui.ResetOnSpawn = true
gui.IgnoreGuiInset = true
gui.DisplayOrder = -2
gui.Enabled = false
local black = Instance.new("Frame")
black.Name = "Black"
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = INK
black.BorderSizePixel = 0
black.Active = false
black.Parent = gui
local msg = Instance.new("TextLabel")
msg.Name = "Msg"
msg.AnchorPoint = Vector2.new(0.5, 0.5)
msg.Position = UDim2.fromScale(0.5, 0.45)
msg.Size = UDim2.fromOffset(240, 50)
msg.BackgroundTransparency = 1
msg.Font = Enum.Font.FredokaOne
msg.TextSize = 34
msg.TextColor3 = Color3.new(1, 1, 1)
msg.Text = "INKED"
msg.Active = false
msg.Parent = black
gui.Parent = player:WaitForChild("PlayerGui")

local showing = false
local fading
local function show(on)
	if on == showing then return end
	showing = on
	char:SetAttribute("InkBlindShowing", on)
	if fading then fading:Cancel() fading = nil end
	if on then
		black.BackgroundTransparency = 0
		msg.TextTransparency = 0.15
		gui.Enabled = true
		char:SetAttribute("InkBlindCount", (char:GetAttribute("InkBlindCount") or 0) + 1)
	else
		fading = TweenService:Create(black, TweenInfo.new(FADE), {BackgroundTransparency = 1})
		TweenService:Create(msg, TweenInfo.new(FADE), {TextTransparency = 1}):Play()
		fading.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not showing then gui.Enabled = false end
		end)
		fading:Play()
	end
end

RunService.RenderStepped:Connect(function()
	local u = char:GetAttribute("InkedUntil")
	local on = char:GetAttribute("InkBlindEnabled") ~= false and typeof(u) == "number" and u > workspace:GetServerTimeNow()
	show(on)
end)
