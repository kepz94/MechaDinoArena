-- IslandDino v1.0 (Mecha Dino Arena) — the DINO pill on the island HUD: change dino where you stand (LocalScript,
-- StarterPlayerScripts). MDA-545, plan docs/plans/ISLAND_DINO_SWAP_v1.0.md rule 1, mockup docs/mockups/island_dino_swap_v0.1.html
-- "A · Dino button"; Kepu 2026-11-15 10:53 "when i load on to the main island there is no option at all to change dino, i have to
-- leave all the way to the home screen to do so which is not optimal" / 10:58 "this is for the main island not any game modes";
-- pick "Any time".
-- Shown only when: ReplicatedStorage ServerKind == "hub" (the main island), player InMenu ~= true, PrInMatch / PrInLobby ~= true,
--   the picker closed (player IslandPickOpen ~= true), your dino alive, and the SKILLS or MENU pill showing.
-- Look: a copy of the SKILLS pill (Lab 1.x): PANEL rgb(20, 20, 26) at 0.18, white stroke (0.5 transparency, 1.5 thick), corner
--   10, 36 tall, padding 12, FredokaOne 18 white "DINO" (text stroke 0.6). ScreenGui "IslandDino" (DisplayOrder 6, DeviceSafeInsets,
--   ResetOnSpawn false), like the SKILLS gui.
-- Spot (every frame): IslandDinoGap (8) px left of the leftmost visible pill of PlayerGui.LabButton.Skills and
--   PlayerGui.ArenaStatus.Pill, top-aligned with it (PC: left of SKILLS; phone HUD v2: those two sit in the ☰ drawer, so the pill
--   shows only while player PhoneMenuOpen is true, left of MENU, and hides with the drawer).
-- Tap: player attribute IslandPickOpen = true (local); PregameScreen 1.5 shows the SELECT screen (dino, then parts) and clears it
--   on CONFIRM / BACK. The swap itself: DinoSpeciesRequest (SpeciesServer); HubServer 1.6 keeps you where you stand.
-- Switch: script attribute IslandDinoEnabled (default true, read per frame). Diagnostics: IslandDinoVersion, IslandDinoShown,
--   IslandDinoPresses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("IslandDinoVersion", VERSION)
for k, v in pairs({IslandDinoEnabled = true, IslandDinoGap = 8, IslandDinoPresses = 0}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("IslandDino")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "IslandDino"
gui.DisplayOrder = 6
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Parent = pg

local pill = Instance.new("TextButton")
pill.Name = "Dino"
pill.AnchorPoint = Vector2.new(1, 0)
pill.AutomaticSize = Enum.AutomaticSize.X
pill.Size = UDim2.fromOffset(0, 36)
pill.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
pill.BackgroundTransparency = 0.18
pill.AutoButtonColor = true
pill.Font = Enum.Font.FredokaOne
pill.TextSize = 18
pill.TextColor3 = Color3.new(1, 1, 1)
pill.TextStrokeTransparency = 0.6
pill.Text = "DINO"
pill.Visible = false
pill.Parent = gui
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 10)
c.Parent = pill
local s = Instance.new("UIStroke")
s.Color = Color3.new(1, 1, 1)
s.Transparency = 0.5
s.Thickness = 1.5
s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
s.Parent = pill
local p = Instance.new("UIPadding")
p.PaddingLeft = UDim.new(0, 12)
p.PaddingRight = UDim.new(0, 12)
p.Parent = pill

pill.Activated:Connect(function()
	script:SetAttribute("IslandDinoPresses", (script:GetAttribute("IslandDinoPresses") or 0) + 1)
	player:SetAttribute("IslandPickOpen", true)
end)

local function shown(o)
	if not (o and o:IsA("GuiObject") and o.Visible) then return false end
	local g = o:FindFirstAncestorOfClass("ScreenGui")
	if not (g and g.Enabled) then return false end
	local a = o.Parent
	while a and a ~= g do
		if a:IsA("GuiObject") and not a.Visible then return false end
		a = a.Parent
	end
	-- off-screen (the phone drawer closed parks its pills 400 px above the screen); measured from its own ScreenGui's top
	return o.AbsolutePosition.Y + o.AbsoluteSize.Y > g.AbsolutePosition.Y
end

RunService.RenderStepped:Connect(function()
	local on = script:GetAttribute("IslandDinoEnabled") ~= false and ReplicatedStorage:GetAttribute("ServerKind") == "hub"
		and player:GetAttribute("InMenu") ~= true and player:GetAttribute("PrInMatch") ~= true and player:GetAttribute("PrInLobby") ~= true
		and player:GetAttribute("IslandPickOpen") ~= true
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	on = on and hum ~= nil and hum.Health > 0
	local anchor
	if on then
		local lb = pg:FindFirstChild("LabButton")
		local as = pg:FindFirstChild("ArenaStatus")
		for _, o in ipairs({lb and lb:FindFirstChild("Skills"), as and as:FindFirstChild("Pill")}) do
			if shown(o) and (not anchor or o.AbsolutePosition.X < anchor.AbsolutePosition.X) then anchor = o end
		end
		if player:GetAttribute("PhoneHudV2") == true and player:GetAttribute("PhoneMenuOpen") ~= true then anchor = nil end
	end
	pill.Visible = anchor ~= nil
	if script:GetAttribute("IslandDinoShown") ~= pill.Visible then script:SetAttribute("IslandDinoShown", pill.Visible) end
	if anchor then
		local gap = tonumber(script:GetAttribute("IslandDinoGap")) or 8
		local base = gui.AbsolutePosition
		pill.Position = UDim2.fromOffset(anchor.AbsolutePosition.X - base.X - gap, anchor.AbsolutePosition.Y - base.Y)
		pill.Size = UDim2.fromOffset(0, anchor.AbsoluteSize.Y)
	end
end)
