-- SkinUnlockPopup v1.0 (Mecha Dino Arena) — "SKIN UNLOCKED" pop-up at the top centre (LocalScript, StarterPlayerScripts).
-- Kepu 2026-11-26 06:40 "yes skin unlocked pop up top center for 1 second then dissapear" (the toast of mockup
-- docs/mockups/island_streak_v0.1.html, moved to the top centre). Before this an earned skin only showed a toast while the Lab was open.
-- When the player attribute SkinUnlockedAt changes (SkinServer: an earned skin, or a Quest Stand claim through SkinGrant) and
--   SkinUnlocked names a skin of ReplicatedStorage.SkinShared.UniversalSkins, a pop-up shows for SkinPopupTime (1) s, then hides.
--   Not while the Lab is open (player LabOpen ~= "closed": the Lab shows its own toast).
-- Look: ScreenGui "SkinUnlockPopup" (DisplayOrder 60, DeviceSafeInsets), centred at the top, SkinPopupTop (10) px down: a dark plate
--   rgb(11,15,22) at 0.05, 3 px yellow rgb(255,200,50) outline, corner 12; a 40 px swatch (the skin's sw colours as vertical stripes,
--   rounded); "SKIN UNLOCKED" (Silkscreen Bold 13, yellow) over the skin name in capitals (Silkscreen Bold 20, white). Width fits the
--   name. A quick pop in (scale 0.8 -> 1 over 0.12 s; none with Reduced Motion).
-- Switch: script attribute SkinPopupEnabled (true, read per unlock). Diagnostics: SkinUnlockPopupVersion, SkinPopupShown (count),
--   SkinPopupLast (skin id).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
script:SetAttribute("SkinUnlockPopupVersion", VERSION)
for k, v in pairs({SkinPopupEnabled = true, SkinPopupTime = 1, SkinPopupTop = 10, SkinPopupShown = 0}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local player = Players.LocalPlayer
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local YELLOW = Color3.fromRGB(255, 200, 50)

local gui = Instance.new("ScreenGui")
gui.Name = "SkinUnlockPopup"
gui.DisplayOrder = 60
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Parent = player:WaitForChild("PlayerGui")
local plate = Instance.new("Frame")
plate.Name = "Plate"
plate.AnchorPoint = Vector2.new(0.5, 0)
plate.BackgroundColor3 = Color3.fromRGB(11, 15, 22)
plate.BackgroundTransparency = 0.05
plate.BorderSizePixel = 0
plate.Visible = false
plate.Parent = gui
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 12) c.Parent = plate end
do local s = Instance.new("UIStroke") s.Color = YELLOW s.Thickness = 3 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = plate end
local scale = Instance.new("UIScale")
scale.Parent = plate
local sw = Instance.new("Frame")
sw.Name = "Swatch"
sw.Position = UDim2.fromOffset(10, 10)
sw.Size = UDim2.fromOffset(40, 40)
sw.BackgroundTransparency = 1
sw.ClipsDescendants = true
sw.Parent = plate
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = sw end
local function text(name, y, size, col)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(60, y)
	l.FontFace = SILK
	l:SetAttribute("FontSwap", "keep")
	l.TextSize = size
	l.TextColor3 = col
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, size + 4)
	l.Parent = plate
	return l
end
local top = text("Top", 10, 13, YELLOW)
top.Text = "SKIN UNLOCKED"
local nm = text("Name", 29, 20, Color3.new(1, 1, 1))

local US
local function skins()
	if US then return US end
	local f = ReplicatedStorage:FindFirstChild("SkinShared")
	local m = f and f:FindFirstChild("UniversalSkins")
	local ok, r = pcall(function() return m and require(m) end)
	if ok and r then US = r end
	return US
end
local function reducedMotion()
	local ok, v = pcall(function() return game:GetService("GuiService").ReducedMotionEnabled end)
	return ok and v == true
end

local shownId = 0
local function show(id)
	local lib = skins()
	local sk = lib and lib.get(id)
	if not sk then return end
	for _, c in ipairs(sw:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local cols = type(sk.sw) == "table" and #sk.sw > 0 and sk.sw or {"5E943E"}
	for i, hex in ipairs(cols) do
		local s = Instance.new("Frame")
		s.BorderSizePixel = 0
		s.BackgroundColor3 = Color3.fromHex(hex)
		s.Position = UDim2.fromScale((i - 1) / #cols, 0)
		s.Size = UDim2.fromScale(1 / #cols + 0.01, 1)
		s.Parent = sw
	end
	nm.Text = string.upper(sk.name)
	plate.Position = UDim2.new(0.5, 0, 0, tonumber(script:GetAttribute("SkinPopupTop")) or 10)
	plate.Size = UDim2.fromOffset(60 + #nm.Text * 16 + 16, 60) -- a first guess; fitted to the text below
	plate.Visible = true
	task.wait() -- TextBounds are measured on the next frame
	local w = math.max(top.TextBounds.X, nm.TextBounds.X)
	plate.Size = UDim2.fromOffset(60 + math.ceil(w) + 16, 60)
	if reducedMotion() then
		scale.Scale = 1
	else
		scale.Scale = 0.8
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
	shownId += 1
	local my = shownId
	script:SetAttribute("SkinPopupShown", (script:GetAttribute("SkinPopupShown") or 0) + 1)
	script:SetAttribute("SkinPopupLast", id)
	task.delay(tonumber(script:GetAttribute("SkinPopupTime")) or 1, function()
		if shownId == my then plate.Visible = false end
	end)
end

player:GetAttributeChangedSignal("SkinUnlockedAt"):Connect(function()
	if script:GetAttribute("SkinPopupEnabled") == false then return end
	local lab = player:GetAttribute("LabOpen")
	if lab ~= nil and lab ~= "closed" then return end
	local id = player:GetAttribute("SkinUnlocked")
	if type(id) == "string" and id ~= "" then show(id) end
end)
