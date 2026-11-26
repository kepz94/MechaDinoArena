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
VERSION = "1.1" -- v1.1 achievement pop-up
-- v1.1 (achievements, plan docs/plans/ACHIEVEMENTS_v1.0.md Task 4; Kepu 2026-11-26 pop-up "top centre 1 s", red-team "OK"): on player
--   AchDoneAt (QuestServer 1.1) the same plate shows "ACHIEVEMENT DONE" (yellow), the achievement name (white) and "CLAIM AT THE
--   QUEST STAND" (cyan, Silkscreen Bold 11), with a medal disc (B / S / G on bronze / silver / gold) instead of the swatch; plate
--   76 px tall. AchDoneList ("NAME|medal;...") queues: 1 s each, at most 3; when more were done the third line of the last one reads
--   "+n MORE · CLAIM AT THE QUEST STAND". Skin pop-ups keep the 1.0 look. Switch: script attribute AchPopupEnabled (true, per
--   signal). Diagnostic: AchPopupShown (count).
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
local sub = text("Sub", 54, 11, Color3.fromRGB(127, 233, 255)) -- v1.1: achievements only
sub.Visible = false

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
	top.Text = "SKIN UNLOCKED" -- v1.1: the achievement look changes these
	sub.Visible = false
	sw.Size = UDim2.fromOffset(40, 40)
	sw.Position = UDim2.fromOffset(10, 10)
	for _, c in ipairs(sw:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
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

-- v1.1: achievements
if script:GetAttribute("AchPopupEnabled") == nil then script:SetAttribute("AchPopupEnabled", true) end
script:SetAttribute("AchPopupShown", 0)
local MEDAL = {b = Color3.fromRGB(208, 138, 78), s = Color3.fromRGB(201, 211, 223), g = Color3.fromRGB(255, 210, 74)}
local achQueue, achBusy = {}, false
local function showAch(name, medal, third)
	for _, c in ipairs(sw:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
	sw.Size = UDim2.fromOffset(40, 40)
	local disc = Instance.new("Frame")
	disc.BorderSizePixel = 0
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = MEDAL[medal] or MEDAL.b
	disc.Parent = sw
	do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.5, 0) c.Parent = disc end
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.FontFace = SILK
	l:SetAttribute("FontSwap", "keep")
	l.TextSize = 18
	l.TextColor3 = Color3.fromRGB(27, 20, 6)
	l.Text = ({b = "B", s = "S", g = "G"})[medal] or "B"
	l.Parent = disc
	top.Text = "ACHIEVEMENT DONE"
	nm.Text = name
	sub.Text = third
	sub.Visible = true
	plate.Position = UDim2.new(0.5, 0, 0, tonumber(script:GetAttribute("SkinPopupTop")) or 10)
	plate.Size = UDim2.fromOffset(60 + #name * 16 + 16, 76)
	plate.Visible = true
	task.wait()
	local w = math.max(top.TextBounds.X, nm.TextBounds.X, sub.TextBounds.X)
	plate.Size = UDim2.fromOffset(60 + math.ceil(w) + 16, 76)
	sw.Position = UDim2.fromOffset(10, 18)
	if reducedMotion() then scale.Scale = 1 else
		scale.Scale = 0.8
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
	shownId += 1
	local my = shownId
	script:SetAttribute("AchPopupShown", (script:GetAttribute("AchPopupShown") or 0) + 1)
	task.wait(tonumber(script:GetAttribute("SkinPopupTime")) or 1)
	if shownId == my then plate.Visible = false sw.Position = UDim2.fromOffset(10, 10) end
end
local function runQueue()
	if achBusy then return end
	achBusy = true
	while #achQueue > 0 do
		local e = table.remove(achQueue, 1)
		showAch(e[1], e[2], e[3])
	end
	achBusy = false
end
player:GetAttributeChangedSignal("AchDoneAt"):Connect(function()
	if script:GetAttribute("AchPopupEnabled") == false then return end
	local list = {}
	for part in tostring(player:GetAttribute("AchDoneList") or ""):gmatch("[^;]+") do
		local n, m = part:match("^(.-)|(%a)$")
		if n then table.insert(list, {n, m}) end
	end
	local more = math.max(0, #list - 3)
	for i = 1, math.min(3, #list) do
		local third = (i == math.min(3, #list) and more > 0) and ("+" .. more .. " MORE · CLAIM AT THE QUEST STAND") or "CLAIM AT THE QUEST STAND"
		table.insert(achQueue, {list[i][1], list[i][2], third})
	end
	task.spawn(runQueue)
end)
player:GetAttributeChangedSignal("SkinUnlockedAt"):Connect(function()
	if script:GetAttribute("SkinPopupEnabled") == false then return end
	local lab = player:GetAttribute("LabOpen")
	if lab ~= nil and lab ~= "closed" then return end
	local id = player:GetAttribute("SkinUnlocked")
	if type(id) == "string" and id ~= "" then show(id) end
end)
