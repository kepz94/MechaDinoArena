-- IslandRespawnClient v1.0 (Mecha Dino Arena) — the "RETURN TO SPAWN PAD" pop-up after an island respawn (LocalScript,
--   StarterPlayerScripts). Kepu 2026-11-26 12:11 "GIVE A POP UP AFTER A RESPAWN FOR 2 SECONDS TO RETURN TO SPAWN PAD"; works
--   with HubServer 1.9 (player IslandRespawnAt, RemoteEvent ReplicatedStorage.HubIslandRequest).
-- When the player attribute IslandRespawnAt changes to a number: a button shows for IslandPadShow (2) s, bottom centre above the
--   ability bar: dark plate, yellow outline, "RETURN TO SPAWN PAD", a yellow bar that empties over the 2 s; on a keyboard device
--   the key hint "X" is on its left. 300 x 64 (scaled down to fit narrow screens, never under 44 tall). Tap / click / X ->
--   HubIslandRequest:FireServer("pad") once, the button hides. Any of: the time running out, the menu opening (InMenu), death,
--   or IslandRespawnAt clearing hides it.
-- Switches / numbers (script attributes): IslandRespawnClientEnabled (true, read at start), IslandPadShow (2, read per show).
-- v1.1 (Kepu 2026-11-27 12:38 "Why is this button covering my whole screen. Make it smaller" + "And not in the center of the
--   screen"): while IslandPadCompact ~= false (read per show) the button is IslandPadW (230) x IslandPadH (44, never under 44)
--   at the top centre, top edge at IslandPadY (60, under the playtime chip), label one line (20 tall, max 15); the key hint "X" 32 x 32 on its left.
--   IslandPadCompact false = the v1.0 layout (300 x 64, bottom centre 150 up). Diagnostics: IslandPadLayout ("compact" / "v1.0").
-- Diagnostics: IslandRespawnClientVersion, IslandPadShown (count), IslandPadPressed (count).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
script:SetAttribute("IslandRespawnClientVersion", VERSION)
for k, v in pairs({IslandRespawnClientEnabled = true, IslandPadShow = 2, IslandPadCompact = true, IslandPadW = 230, IslandPadH = 44, IslandPadY = 60}) do -- v1.1: + compact
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
if script:GetAttribute("IslandRespawnClientEnabled") == false then return end
local player = Players.LocalPlayer
local YELLOW, INK, PLATE = Color3.fromRGB(255, 200, 50), Color3.fromRGB(26, 19, 0), Color3.fromRGB(13, 18, 24)

local gui = Instance.new("ScreenGui")
gui.Name = "IslandRespawnPad"
gui.DisplayOrder = 60
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local btn = Instance.new("TextButton")
btn.Name = "Pad"
btn.AnchorPoint = Vector2.new(0.5, 1)
btn.Position = UDim2.new(0.5, 0, 1, -150)
btn.Size = UDim2.fromOffset(300, 64)
btn.BackgroundColor3 = PLATE
btn.BackgroundTransparency = 0.05
btn.AutoButtonColor = true
btn.Text = ""
btn.Parent = gui
do
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 14) c.Parent = btn
	local s = Instance.new("UIStroke") s.Color = YELLOW s.Thickness = 3 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = btn
	local sz = Instance.new("UISizeConstraint") sz.MinSize = Vector2.new(200, 48) sz.Parent = btn
end
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.new(1, -24, 1, -14)
label.Position = UDim2.fromOffset(12, 2)
label.Font = Enum.Font.GothamBlack
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.Text = "RETURN TO SPAWN PAD"
label.Parent = btn
do local t = Instance.new("UITextSizeConstraint") t.MaxTextSize = 20 t.Parent = label end
local key = Instance.new("TextLabel")
key.Name = "Key"
key.AnchorPoint = Vector2.new(1, 0.5)
key.Position = UDim2.new(0, -8, 0.5, 0)
key.Size = UDim2.fromOffset(40, 40)
key.BackgroundColor3 = YELLOW
key.TextColor3 = INK
key.Font = Enum.Font.GothamBlack
key.TextSize = 20
key.Text = "X"
key.Visible = UIS.KeyboardEnabled
key.Parent = btn
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = key end
local barBack = Instance.new("Frame")
barBack.BackgroundColor3 = Color3.fromRGB(40, 46, 56)
barBack.BorderSizePixel = 0
barBack.AnchorPoint = Vector2.new(0.5, 1)
barBack.Position = UDim2.new(0.5, 0, 1, -6)
barBack.Size = UDim2.new(1, -24, 0, 5)
barBack.Parent = btn
local bar = Instance.new("Frame")
bar.BackgroundColor3 = YELLOW
bar.BorderSizePixel = 0
bar.Size = UDim2.fromScale(1, 1)
bar.Parent = barBack

local sizeCon = btn:FindFirstChildOfClass("UISizeConstraint")
local textCon = label:FindFirstChildOfClass("UITextSizeConstraint")
local function layout() -- v1.1: compact at the top centre, or the v1.0 layout
	if script:GetAttribute("IslandPadCompact") ~= false then
		local w = math.max(160, tonumber(script:GetAttribute("IslandPadW")) or 230)
		local h = math.max(44, tonumber(script:GetAttribute("IslandPadH")) or 44)
		btn.AnchorPoint = Vector2.new(0.5, 0)
		btn.Position = UDim2.new(0.5, 0, 0, tonumber(script:GetAttribute("IslandPadY")) or 60)
		btn.Size = UDim2.fromOffset(w, h)
		sizeCon.MinSize = Vector2.new(160, 44)
		label.Size = UDim2.new(1, -20, 0, 20) -- one line tall, so the scaled text never wraps to two lines
		label.Position = UDim2.fromOffset(10, 8)
		textCon.MaxTextSize = 15
		key.Size = UDim2.fromOffset(32, 32)
		key.TextSize = 16
		script:SetAttribute("IslandPadLayout", "compact")
	else
		btn.AnchorPoint = Vector2.new(0.5, 1)
		btn.Position = UDim2.new(0.5, 0, 1, -150)
		btn.Size = UDim2.fromOffset(300, 64)
		sizeCon.MinSize = Vector2.new(200, 48)
		label.Size = UDim2.new(1, -24, 1, -14)
		label.Position = UDim2.fromOffset(12, 2)
		textCon.MaxTextSize = 20
		key.Size = UDim2.fromOffset(40, 40)
		key.TextSize = 20
		script:SetAttribute("IslandPadLayout", "v1.0")
	end
end
layout()

local showId, untilT, total = 0, 0, 2
local function hide() gui.Enabled = false untilT = 0 end
local function press()
	if not gui.Enabled then return end
	hide()
	script:SetAttribute("IslandPadPressed", (script:GetAttribute("IslandPadPressed") or 0) + 1)
	local r = ReplicatedStorage:FindFirstChild("HubIslandRequest")
	if r then r:FireServer("pad") end
end
btn.Activated:Connect(press)
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.X then press() end
end)
player:GetAttributeChangedSignal("IslandRespawnAt"):Connect(function()
	local at = player:GetAttribute("IslandRespawnAt")
	if type(at) ~= "number" or player:GetAttribute("InMenu") == true then hide() return end
	showId += 1
	total = math.max(0.5, tonumber(script:GetAttribute("IslandPadShow")) or 2)
	untilT = os.clock() + total
	key.Visible = UIS.KeyboardEnabled
	layout() -- v1.1
	gui.Enabled = true
	script:SetAttribute("IslandPadShown", (script:GetAttribute("IslandPadShown") or 0) + 1)
end)
player:GetAttributeChangedSignal("InMenu"):Connect(function() if player:GetAttribute("InMenu") == true then hide() end end)
RunService.RenderStepped:Connect(function()
	if not gui.Enabled then return end
	local left = untilT - os.clock()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if left <= 0 or not hum or hum.Health <= 0 then hide() return end
	bar.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
end)
