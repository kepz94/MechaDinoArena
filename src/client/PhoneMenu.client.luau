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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
script:SetAttribute("PhoneMenuVersion", VERSION)
for k, v in pairs({PhoneHudV2Enabled = true, PhoneMenuY_Skills = 50, PhoneMenuY_Menu = 50, PhoneMenuCloseDelay = 0.15,
	PhoneMenuToggles = 0}) do
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
	if not gui.Enabled and player:GetAttribute("PhoneMenuOpen") == true then setOpen(false) end
	local lb = pg:FindFirstChild("LabButton")
	local badge = lb and lb:FindFirstChild("Badge", true)
	dot.Visible = badge ~= nil and badge:IsA("GuiObject") and badge.Visible
end)
setOpen(false)
