-- PhoneMenu v1.0 (Mecha Dino Arena) — phone HUD v2: the ☰ button and its drawer state (LocalScript, StarterPlayerScripts).
-- MDA-532, plan docs/plans/PHONE_HUD_V2_v1.0.md rule 1, mockup docs/mockups/phone_hud_v0.1.html "A · your version"; Kepu
-- 2026-11-13 20:12 "really consider all the space being taken up on the phone screen and how it can be optimized", pick "I like
-- option A but keep the current button style that we use with the tap/swipe buttons".
-- Phone HUD v2 flag: player attribute PhoneHudV2 = true while script attribute PhoneHudV2Enabled ~= false (default true, read per
--   frame) and this is a touch device (UserInputService.TouchEnabled, or the character's ArenaTouchState == "on", the
--   ArenaTouchForceTouch Studio hook). Lab 1.17, ArenaStatus 1.9, HardpointHUD 1.13 and KillFeed 1.2 read it; false = today's
--   phone HUD everywhere.
-- ☰ (ScreenGui "PhoneMenu", DisplayOrder 7, DeviceSafeInsets, ResetOnSpawn false): TextButton "Burger" 44 x 36 at AnchorPoint
--   (1, 0), (1, -16, 0, 8) (MENU's spot), panel rgb(13, 18, 24) at 0.18, corner 10, yellow stroke 1.5, yellow "☰" (FredokaOne
--   22). Shown while PhoneHudV2 is on and the player is out of the menu (InMenu ~= true).
--   * a tap toggles player attribute PhoneMenuOpen;
--   * a touch / click that ends outside the ☰ closes the drawer PhoneMenuCloseDelay (0.15) s later (a drawer button's own tap
--     goes through first);
--   * badge: a yellow 10 px dot at the ☰'s top-right corner while the SKILLS pill's "Badge" (unspent points) is showing.
--   Drawer spots published as player attributes (screen offsets in a DeviceSafeInsets gui, AnchorPoint (1, 0) at (1, -16, 0, y)):
--   PhoneMenuY_Skills (50), PhoneMenuY_Menu (50) — script attributes of the same names. ArenaStatus puts MENU left of SKILLS;
--   SQUAD follows under SKILLS and the camera button under MENU on their own (SquadHUD / CameraModes): a 2 x 2 block
--   [MENU][SKILLS] / [CAMERA][SQUAD] that stays above JUMP.
-- Diagnostics: PhoneMenuVersion, player PhoneHudV2, PhoneMenuOpen, script PhoneMenuToggles (count).
-- v1.1 (Kepu 2026-11-25 12:05 "yes fix the box too", mockup docs/mockups/emote_button_v0.1.html "FIX: DRAW 3 BARS"; his iPhone
--   screenshot showed the ☰ as an empty box: the font has no ☰ glyph): the ☰ is drawn as 3 yellow bars (Frame "Bars", 3 Frames
--   PhoneMenuBarW (20) x PhoneMenuBarH (3) px, PhoneMenuBarGap (4) px apart, round ends, centred); the button text is empty.
--   Size, spot, dot, taps unchanged. Switch: script attribute PhoneMenuBarsEnabled (default true, read per frame; false = "☰" text).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 drawn bars
script:SetAttribute("PhoneMenuVersion", VERSION)
for k, v in pairs({PhoneHudV2Enabled = true, PhoneMenuY_Skills = 50, PhoneMenuY_Menu = 50, PhoneMenuCloseDelay = 0.15,
	PhoneMenuToggles = 0, PhoneMenuBarsEnabled = true, PhoneMenuBarW = 20, PhoneMenuBarH = 3, PhoneMenuBarGap = 4}) do -- v1.1 bars
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local YELLOW = Color3.fromRGB(255, 200, 50)

local function touchDevice()
	local c = player.Character
	return UserInputService.TouchEnabled or (c ~= nil and c:GetAttribute("ArenaTouchState") == "on")
end
local function setP(k, v) if player:GetAttribute(k) ~= v then player:SetAttribute(k, v) end end

local gui = Instance.new("ScreenGui")
gui.Name = "PhoneMenu"
gui.DisplayOrder = 7
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Enabled = false
gui.Parent = pg

local burger = Instance.new("TextButton")
burger.Name = "Burger"
burger.AnchorPoint = Vector2.new(1, 0)
burger.Position = UDim2.new(1, -16, 0, 8)
burger.Size = UDim2.fromOffset(44, 36)
burger.BackgroundColor3 = Color3.fromRGB(13, 18, 24)
burger.BackgroundTransparency = 0.18
burger.AutoButtonColor = false
burger.Font = Enum.Font.FredokaOne
burger.TextSize = 22
burger.TextColor3 = YELLOW
burger.Text = "☰"
burger.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = burger
	local s = Instance.new("UIStroke")
	s.Color = YELLOW
	s.Thickness = 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = burger
end
local dot = Instance.new("Frame")
dot.Name = "Dot"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.new(1, -2, 0, 2)
dot.Size = UDim2.fromOffset(10, 10)
dot.BackgroundColor3 = YELLOW
dot.Visible = false
dot.Parent = burger
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = dot
end

-- v1.1: the ☰ drawn as 3 bars (the font has no ☰ glyph on phones)
local bars = Instance.new("Frame")
bars.Name = "Bars"
bars.AnchorPoint = Vector2.new(0.5, 0.5)
bars.Position = UDim2.fromScale(0.5, 0.5)
bars.BackgroundTransparency = 1
bars.Visible = false
bars.Parent = burger
local barList = {}
for i = 1, 3 do
	local b = Instance.new("Frame")
	b.Name = "Bar" .. i
	b.BackgroundColor3 = YELLOW
	b.BorderSizePixel = 0
	b.Parent = bars
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	barList[i] = b
end
local barsKey = nil
local function drawBars()
	local on = script:GetAttribute("PhoneMenuBarsEnabled") ~= false
	local w = tonumber(script:GetAttribute("PhoneMenuBarW")) or 20
	local h = tonumber(script:GetAttribute("PhoneMenuBarH")) or 3
	local g = tonumber(script:GetAttribute("PhoneMenuBarGap")) or 4
	local key = tostring(on) .. "|" .. w .. "|" .. h .. "|" .. g
	if key == barsKey then return end
	barsKey = key
	bars.Visible = on
	burger.Text = on and "" or "☰"
	bars.Size = UDim2.fromOffset(w, 3 * h + 2 * g)
	for i, b in ipairs(barList) do
		b.Size = UDim2.fromOffset(w, h)
		b.Position = UDim2.fromOffset(0, (i - 1) * (h + g))
	end
end
drawBars()

local function setOpen(v)
	setP("PhoneMenuOpen", v == true)
end
burger.Activated:Connect(function()
	setOpen(player:GetAttribute("PhoneMenuOpen") ~= true)
	script:SetAttribute("PhoneMenuToggles", (script:GetAttribute("PhoneMenuToggles") or 0) + 1)
end)
local function inBurger(pos)
	local p, s = burger.AbsolutePosition, burger.AbsoluteSize
	local x, y = pos.X, pos.Y -- InputObject.Position is inset-relative, like AbsolutePosition
	return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
end
UserInputService.InputEnded:Connect(function(input)
	if player:GetAttribute("PhoneMenuOpen") ~= true then return end
	local t = input.UserInputType
	if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
	if inBurger(input.Position) then return end
	task.delay(tonumber(script:GetAttribute("PhoneMenuCloseDelay")) or 0.15, function() setOpen(false) end)
end)

RunService.RenderStepped:Connect(function()
	local on = script:GetAttribute("PhoneHudV2Enabled") ~= false and touchDevice()
	setP("PhoneHudV2", on)
	setP("PhoneMenuY_Skills", tonumber(script:GetAttribute("PhoneMenuY_Skills")) or 50)
	setP("PhoneMenuY_Menu", tonumber(script:GetAttribute("PhoneMenuY_Menu")) or 50)
	gui.Enabled = on and player:GetAttribute("InMenu") ~= true
	drawBars() -- v1.1 (only does work when a switch or size attribute changed)
	if not gui.Enabled and player:GetAttribute("PhoneMenuOpen") == true then setOpen(false) end
	local lb = pg:FindFirstChild("LabButton")
	local badge = lb and lb:FindFirstChild("Badge", true)
	dot.Visible = badge ~= nil and badge:IsA("GuiObject") and badge.Visible
end)
setOpen(false)
