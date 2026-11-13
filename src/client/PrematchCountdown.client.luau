-- PrematchCountdown v1.0 (Mecha Dino Arena) — the 10 s pre-match countdown after the pre-game intro, PC and phone (LocalScript,
-- StarterPlayerScripts). MDA-501, plan docs/plans/PREMATCH_AND_SAVED_LOADOUT_v1.0.md A3, mockup
-- docs/mockups/prematch_countdown_v0.1.html "A · Centre countdown"; Kepu 2026-11-13 "have a 10 second count down with the
-- objective of the game showing on the screen and where the first point is. Look at how cod does this", picks "A · Centre
-- countdown", "Held in place".
-- Shown while ReplicatedStorage.Practice PrPrematch == true and ReplicatedStorage.Hardpoint HpPhase == "warmup" (PracticeServer
--   1.11 starts the match with a lead; HardpointServer 1.8 then runs a 10 s warm-up) and you are out of the menu (InMenu ~= true);
--   then "GO" for GO_TIME (1) s once HpPhase turns "live". Seconds left = HpPointEndsAt - server time (rounded up).
-- Look (ScreenGui "PrematchCountdown", IgnoreGuiInset, DisplayOrder 7, over the HUD's 6), on a 1000 x 562 canvas scaled to the
--   screen (UIScale = min(width / 1000, height / 562)); phone (width / height >= 1.9) text x 1.3:
--   * a dim over the screen (black, 0.62 transparent);
--   * centred at 30% height: HARDPOINT (yellow, 14), CAPTURE AND HOLD THE HARDPOINT (white, 26), +1 PER SECOND PER DINO ON
--     THE POINT · FIRST TO <HardpointRules.LIMIT> (light, 12), MATCH BEGINS IN (light, 12), the number (white, 90; yellow at
--     3, 2, 1), a pill FIRST POINT · P1 <NAME> (dark, yellow outline, yellow diamond; name from HpPoints[1]);
--   * bottom centre: HELD UNTIL GO · LOOK AROUND (muted, 10, dark chip).
--   All text in Silkscreen Bold set here (attribute FontSwap "keep", so FontSwap 1.0 leaves the sizes alone).
--   The P1 marker in the world is HardpointHUD's (marker v3, P1 during the warm-up).
-- Switch: script attribute PrematchCountdownEnabled (default true, read per frame; false = nothing shown).
-- Diagnostics: PrematchCountdownVersion, PrematchCountdownState ("off" / "count <n>" / "go").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.0"
local CANVAS_W, CANVAS_H = 1000, 562
local GO_TIME = 1
local PHONE_ASPECT, PHONE_TF = 1.9, 1.3
local YELLOW = Color3.fromRGB(255, 200, 50)
local LIGHT = Color3.fromRGB(213, 221, 232)
local MUTED = Color3.fromRGB(147, 162, 182)
local DARK = Color3.fromRGB(13, 18, 24)
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)

script:SetAttribute("PrematchCountdownVersion", VERSION)
if script:GetAttribute("PrematchCountdownEnabled") == nil then script:SetAttribute("PrematchCountdownEnabled", true) end

local player = Players.LocalPlayer
local hp = ReplicatedStorage:WaitForChild("Hardpoint", 60)
if not hp then return end
local shared = ReplicatedStorage:FindFirstChild("HardpointShared")
local okH, H = pcall(function() return shared and require(shared:WaitForChild("HardpointRules", 10)) end)
local LIMIT = (okH and H and H.LIMIT) or 250

local gui = Instance.new("ScreenGui")
gui.Name = "PrematchCountdown"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 7
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.62
dim.BorderSizePixel = 0
dim.Parent = gui

local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.AnchorPoint = Vector2.new(0.5, 0.5)
canvas.Position = UDim2.fromScale(0.5, 0.5)
canvas.Size = UDim2.fromOffset(CANVAS_W, CANVAS_H)
canvas.BackgroundTransparency = 1
canvas.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = canvas

local labels = {} -- {label, base size}
local function label(name, size, color, y, h)
	local l = Instance.new("TextLabel")
	l.Name = name
	l:SetAttribute("FontSwap", "keep")
	l.BackgroundTransparency = 1
	l.FontFace = SILK
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.55
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextSize = size
	l.Size = UDim2.new(1, 0, 0, h or size + 8)
	l.Position = UDim2.fromOffset(0, y)
	l.Parent = canvas
	table.insert(labels, {l = l, size = size})
	return l
end
local mode = label("Mode", 14, YELLOW, 168)
mode.Text = "HARDPOINT"
local obj = label("Objective", 26, Color3.new(1, 1, 1), 190)
obj.Text = "CAPTURE AND HOLD THE HARDPOINT"
local how = label("Score", 12, LIGHT, 226)
how.Text = ("+1 PER SECOND PER DINO ON THE POINT · FIRST TO %d"):format(LIMIT)
local begins = label("Begins", 12, LIGHT, 262)
begins.Text = "MATCH BEGINS IN"
local num = label("Number", 90, Color3.new(1, 1, 1), 280, 100)
num.TextStrokeTransparency = 0.4

local pill = Instance.new("Frame")
pill.Name = "FirstPoint"
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Position = UDim2.fromOffset(CANVAS_W / 2, 392)
pill.AutomaticSize = Enum.AutomaticSize.X
pill.Size = UDim2.fromOffset(0, 30)
pill.BackgroundColor3 = DARK
pill.BackgroundTransparency = 0.18
pill.Parent = canvas
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(1, 0)
pc.Parent = pill
local ps = Instance.new("UIStroke")
ps.Color = YELLOW
ps.Thickness = 1.5
ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ps.Parent = pill
local pp = Instance.new("UIPadding")
pp.PaddingLeft, pp.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
pp.Parent = pill
local pl = Instance.new("UIListLayout")
pl.FillDirection = Enum.FillDirection.Horizontal
pl.VerticalAlignment = Enum.VerticalAlignment.Center
pl.Padding = UDim.new(0, 8)
pl.SortOrder = Enum.SortOrder.LayoutOrder
pl.Parent = pill
local diamond = Instance.new("Frame")
diamond.Name = "Diamond"
diamond.LayoutOrder = 1
diamond.Size = UDim2.fromOffset(11, 11)
diamond.Rotation = 45
diamond.BackgroundColor3 = YELLOW
diamond.BorderSizePixel = 0
diamond.Parent = pill
local pillText = Instance.new("TextLabel")
pillText.Name = "Text"
pillText:SetAttribute("FontSwap", "keep")
pillText.LayoutOrder = 2
pillText.BackgroundTransparency = 1
pillText.FontFace = SILK
pillText.TextColor3 = Color3.new(1, 1, 1)
pillText.TextSize = 12
pillText.AutomaticSize = Enum.AutomaticSize.X
pillText.Size = UDim2.fromOffset(0, 30)
pillText.Parent = pill
table.insert(labels, {l = pillText, size = 12})

local held = Instance.new("TextLabel")
held.Name = "Held"
held:SetAttribute("FontSwap", "keep")
held.AnchorPoint = Vector2.new(0.5, 1)
held.Position = UDim2.new(0.5, 0, 1, -24)
held.AutomaticSize = Enum.AutomaticSize.X
held.Size = UDim2.fromOffset(0, 22)
held.BackgroundColor3 = DARK
held.BackgroundTransparency = 0.25
held.FontFace = SILK
held.TextColor3 = MUTED
held.TextSize = 10
held.Text = "HELD UNTIL GO · LOOK AROUND"
held.Parent = canvas
local hc = Instance.new("UICorner")
hc.CornerRadius = UDim.new(0, 5)
hc.Parent = held
local hpad = Instance.new("UIPadding")
hpad.PaddingLeft, hpad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
hpad.Parent = held
table.insert(labels, {l = held, size = 10})

local function firstPointName()
	local ok, list = pcall(function() return HttpService:JSONDecode(hp:GetAttribute("HpPoints") or "[]") end)
	local p = ok and type(list) == "table" and list[1]
	return p and string.upper(tostring(p.name)) or ""
end

local goUntil = 0
local lastTf = nil
local wasWarm = false
local function setState(s) if script:GetAttribute("PrematchCountdownState") ~= s then script:SetAttribute("PrematchCountdownState", s) end end

RunService.RenderStepped:Connect(function()
	local pr = ReplicatedStorage:FindFirstChild("Practice")
	local on = script:GetAttribute("PrematchCountdownEnabled") ~= false and pr ~= nil and pr:GetAttribute("PrPrematch") == true
		and player:GetAttribute("InMenu") ~= true
	local phase = hp:GetAttribute("HpPhase")
	local t = workspace:GetServerTimeNow()
	if on and wasWarm and phase == "live" and goUntil == 0 then goUntil = t + GO_TIME end
	wasWarm = on and phase == "warmup"
	if phase ~= "live" then goUntil = 0 end
	local showCount = on and phase == "warmup"
	local showGo = on and goUntil > 0 and t < goUntil
	gui.Enabled = showCount or showGo
	if not gui.Enabled then setState("off") return end
	-- scale (phone text x 1.3)
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(CANVAS_W, CANVAS_H)
	scale.Scale = math.min(vp.X / CANVAS_W, vp.Y / CANVAS_H)
	local tf = (vp.X / math.max(vp.Y, 1) >= PHONE_ASPECT) and PHONE_TF or 1
	if tf ~= lastTf then
		lastTf = tf
		for _, e in ipairs(labels) do e.l.TextSize = math.floor(e.size * tf + 0.5) end
	end
	local left = math.max(0, math.ceil((hp:GetAttribute("HpPointEndsAt") or t) - t))
	local text = showGo and "GO" or tostring(math.max(left, 1))
	if num.Text ~= text then num.Text = text end
	num.TextColor3 = (showGo or left <= 3) and YELLOW or Color3.new(1, 1, 1)
	for _, l in ipairs({mode, obj, how, begins, pill, held}) do l.Visible = not showGo end
	dim.BackgroundTransparency = showGo and 0.85 or 0.62
	local pt = "FIRST POINT · P1 " .. firstPointName()
	if pillText.Text ~= pt then pillText.Text = pt end
	setState(showGo and "go" or ("count " .. text))
end)
