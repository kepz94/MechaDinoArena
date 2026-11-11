-- HardpointHUD v1.0 (Mecha Dino Arena) — the Arena Hardpoint HUD, PC and phone (LocalScript, StarterPlayerScripts). MDA-402,
-- plan docs/plans/HARDPOINT_v1.0.md Task 7, mockups docs/mockups/arena_hardpoint_v0.1.html (Kepu 2026-11-10: the HUD "Look at how
-- Call of Duty Mobile does it") + hardpoint_point_look_v0.1.html (the marker and name tags).
-- Reads ReplicatedStorage.Hardpoint (HardpointServer 1.0) and the player attribute HardpointTeam; draws only while HpLive, the
--   player is out of the menu (InMenu ~= true) and HpPhase is warmup / live / results.
-- ScreenGui "HardpointHUD" (DisplayOrder 6, ScreenInsets DeviceSafeInsets, ResetOnSpawn false), FredokaOne, the HUD panel look
--   (rgb(20,20,26) at 0.18, white stroke 0.5 / 1.5 px, corner 10). Your team is always blue rgb(90,160,255), the enemy red
--   rgb(224,40,74) (Call of Duty).
--   * Score card, top left under Roblox's top bar: AnchorPoint (0, 0) at (0, 16, 0, 58), width clamp(26% of the screen, 220,
--     330), 58 tall: team emblem (blue), your score row (blue bar + number) over the enemy row (red), and on the right the
--     match clock m:ss ("II" while paused, the point is held) and "P{n} · m:ss" (yellow).
--   * Status line 6 px under the card: GET READY / POINT OPEN / SECURED · +1 / s / ENEMY HAS THE POINT / CONTESTED.
--   * Next notice under it while HpShowNext: "NEXT: P{n} {NAME} IN m:ss".
--   * Marker: projected every frame from the point centre + 34 studs: label (CAPTURE / DEFEND / CONTESTED, LOCKED m:ss in the
--     warmup), a diamond with the point number, and the distance ("ON POINT" when you count); clamped to the screen edge
--     (smaller) when off screen or behind the camera.
--   * Name tags: a BillboardGui over every other counted player (team set, out of the menu, alive), own team blue, enemy red.
--   * Results: a centre panel VICTORY / DEFEAT / DRAW, "you – them" and "NEXT MATCH IN m:ss".
-- Switch: script attribute HardpointHUDEnabled (default true). Diagnostics: HardpointHUDVersion, HardpointHUDState.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.0"
script:SetAttribute("HardpointHUDVersion", VERSION)
if script:GetAttribute("HardpointHUDEnabled") == nil then script:SetAttribute("HardpointHUDEnabled", true) end

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("Hardpoint", 60)
if not state then return end
local shared = ReplicatedStorage:WaitForChild("HardpointShared", 30)
local H = shared and require(shared:WaitForChild("HardpointRules"))

local BLUE, RED, YELLOW = Color3.fromRGB(90, 160, 255), Color3.fromRGB(224, 40, 74), Color3.fromRGB(255, 200, 50)
local BLUE_T, RED_T = Color3.fromRGB(188, 216, 255), Color3.fromRGB(255, 194, 204)
local PANEL = Color3.fromRGB(20, 20, 26)
local FONT = Enum.Font.FredokaOne

local function now() return workspace:GetServerTimeNow() end
local function fmt(s)
	s = math.max(0, math.ceil(s - 1e-6))
	return ("%d:%02d"):format(s // 60, s % 60)
end
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = p return c end
local function stroke(p, color, tr, th)
	local s = Instance.new("UIStroke") s.Color = color s.Transparency = tr s.Thickness = th
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = p return s
end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end

-- ---------- the gui ----------
local gui = Instance.new("ScreenGui")
gui.Name = "HardpointHUD"
gui.DisplayOrder = 6
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "ScoreCard"
card.AnchorPoint = Vector2.new(0, 0)
card.Position = UDim2.new(0, 16, 0, 58)
card.Size = UDim2.fromOffset(260, 58)
card.BackgroundColor3 = PANEL
card.BackgroundTransparency = 0.18
corner(card, 10)
stroke(card, Color3.new(1, 1, 1), 0.5, 1.5)
card.Parent = gui

local emblem = Instance.new("Frame")
emblem.Name = "Emblem"
emblem.Position = UDim2.fromOffset(9, 13)
emblem.Size = UDim2.fromOffset(32, 32)
emblem.BackgroundColor3 = BLUE
corner(emblem, 7)
stroke(emblem, Color3.new(1, 1, 1), 0.3, 1.5)
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(110, 175, 255), Color3.fromRGB(42, 95, 174))
grad.Rotation = 45
grad.Parent = emblem
emblem.Parent = card

local function row(y, fill)
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 50, 0, y)
	back.Size = UDim2.new(1, -150, 0, 9)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BackgroundTransparency = 0.86
	corner(back, 5)
	back.Parent = card
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(0, 1)
	f.BackgroundColor3 = fill
	corner(f, 5)
	f.Parent = back
	return back, f
end
local youBack, youFill = row(15, BLUE)
local foeBack, foeFill = row(34, RED)
local youNum = label(card, {Position = UDim2.new(1, -98, 0, 9), Size = UDim2.fromOffset(40, 20), TextSize = 17, TextColor3 = BLUE_T,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "0"})
local foeNum = label(card, {Position = UDim2.new(1, -98, 0, 28), Size = UDim2.fromOffset(40, 20), TextSize = 17, TextColor3 = RED_T,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "0"})
local sep = Instance.new("Frame")
sep.Position = UDim2.new(1, -52, 0, 9)
sep.Size = UDim2.fromOffset(1, 40)
sep.BackgroundColor3 = Color3.new(1, 1, 1)
sep.BackgroundTransparency = 0.75
sep.BorderSizePixel = 0
sep.Parent = card
local clockL = label(card, {Position = UDim2.new(1, -50, 0, 8), Size = UDim2.fromOffset(46, 20), TextSize = 16, Text = "10:00"})
local pointL = label(card, {Position = UDim2.new(1, -50, 0, 30), Size = UDim2.fromOffset(46, 18), TextSize = 13, TextColor3 = YELLOW, Text = "P1"})

local function pill(name)
	local l = label(gui, {Name = name, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), TextSize = 15,
		BackgroundTransparency = 0.45, BackgroundColor3 = PANEL, Text = ""})
	l.Position = UDim2.new(0, 16, 0, 0)
	corner(l, 6)
	local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 8) pad.PaddingRight = UDim.new(0, 8) pad.Parent = l
	return l
end
local status = pill("Status")
local nextL = pill("Next")
nextL.TextColor3 = YELLOW

-- marker
local marker = Instance.new("Frame")
marker.Name = "Marker"
marker.AnchorPoint = Vector2.new(0.5, 1)
marker.Size = UDim2.fromOffset(120, 74)
marker.BackgroundTransparency = 1
marker.Parent = gui
local mLabel = label(marker, {Size = UDim2.new(1, 0, 0, 18), TextSize = 14, Text = "CAPTURE", TextStrokeTransparency = 0.5})
local dia = Instance.new("Frame")
dia.AnchorPoint = Vector2.new(0.5, 0.5)
dia.Position = UDim2.new(0.5, 0, 0, 37)
dia.Size = UDim2.fromOffset(26, 26)
dia.Rotation = 45
dia.BackgroundColor3 = PANEL
dia.BackgroundTransparency = 0.4
corner(dia, 4)
local diaStroke = stroke(dia, Color3.new(1, 1, 1), 0, 3)
dia.Parent = marker
local diaNum = label(dia, {Size = UDim2.fromScale(1, 1), Rotation = -45, TextSize = 15, Text = "1"})
local mDist = label(marker, {Position = UDim2.new(0, 0, 0, 54), Size = UDim2.new(1, 0, 0, 18), TextSize = 13, Text = "",
	TextStrokeTransparency = 0.5})

-- results
local results = Instance.new("Frame")
results.Name = "Results"
results.AnchorPoint = Vector2.new(0.5, 0.5)
results.Position = UDim2.fromScale(0.5, 0.4)
results.Size = UDim2.fromOffset(320, 120)
results.BackgroundColor3 = PANEL
results.BackgroundTransparency = 0.12
corner(results, 12)
local resStroke = stroke(results, BLUE, 0.1, 2)
results.Visible = false
results.Parent = gui
local resTitle = label(results, {Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 44), TextSize = 40, Text = "VICTORY"})
local resScore = label(results, {Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 24), TextSize = 20,
	TextColor3 = Color3.fromRGB(207, 211, 220), Text = ""})
local resNext = label(results, {Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = YELLOW, Text = ""})

-- ---------- data ----------
local points = {}
local function readPoints()
	local ok, list = pcall(function() return HttpService:JSONDecode(state:GetAttribute("HpPoints") or "[]") end)
	points = {}
	if ok and type(list) == "table" then
		for i, p in ipairs(list) do points[i] = {name = tostring(p.name), centre = Vector3.new(p.x, p.y, p.z)} end
	end
end
readPoints()
state:GetAttributeChangedSignal("HpPoints"):Connect(readPoints)

local tags = {} -- [player] = BillboardGui
local function tagFor(pl)
	local g = tags[pl]
	if g and g.Parent then return g end
	g = Instance.new("BillboardGui")
	g.Name = "HardpointTag"
	g.AlwaysOnTop = true
	g.Size = UDim2.fromOffset(180, 24)
	g.LightInfluence = 0
	g.MaxDistance = 600
	local l = label(g, {Name = "Label", Size = UDim2.fromScale(1, 1), TextSize = 15, TextStrokeTransparency = 0.4, Text = pl.DisplayName})
	l.TextColor3 = Color3.new(1, 1, 1)
	g.Parent = gui
	tags[pl] = g
	return g
end
local function dropTag(pl)
	if tags[pl] then tags[pl]:Destroy() tags[pl] = nil end
end
Players.PlayerRemoving:Connect(dropTag)

local function updateTags(mine, live)
	for _, pl in ipairs(Players:GetPlayers()) do
		local t = pl:GetAttribute("HardpointTeam")
		local c = pl.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if live and pl ~= player and (t == "A" or t == "B") and hrp and hum and hum.Health > 0 and pl:GetAttribute("InMenu") ~= true then
			local g = tagFor(pl)
			g.Adornee = hrp
			local ok, size = pcall(function() return c:GetExtentsSize() end)
			g.StudsOffsetWorldSpace = Vector3.new(0, (ok and size.Y or 8) * 0.6 + 3, 0)
			g.Label.TextColor3 = (t == mine) and BLUE or RED
		else
			dropTag(pl)
		end
	end
end

local lastTags = 0
RunService.RenderStepped:Connect(function()
	local phase = state:GetAttribute("HpPhase")
	local show = script:GetAttribute("HardpointHUDEnabled") ~= false and state:GetAttribute("HpLive") == true
		and player:GetAttribute("InMenu") ~= true and (phase == "warmup" or phase == "live" or phase == "results")
	gui.Enabled = show
	if os.clock() - lastTags > 0.5 then
		lastTags = os.clock()
		updateTags(player:GetAttribute("HardpointTeam"), show and phase ~= "results")
	end
	if not show then
		script:SetAttribute("HardpointHUDState", "hidden")
		return
	end
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	card.Size = UDim2.fromOffset(math.clamp(vp.X * 0.26, 220, 330), 58)
	status.Position = UDim2.new(0, 16, 0, 58 + 58 + 6)
	nextL.Position = UDim2.new(0, 16, 0, 58 + 58 + 6 + 30)

	local mine = player:GetAttribute("HardpointTeam")
	local sa, sb = state:GetAttribute("HpScoreA") or 0, state:GetAttribute("HpScoreB") or 0
	local you, foe = sa, sb
	if mine == "B" then you, foe = sb, sa end
	local limit = H and H.LIMIT or 250
	youNum.Text, foeNum.Text = tostring(you), tostring(foe)
	youFill.Size = UDim2.fromScale(math.clamp(you / limit, 0, 1), 1)
	foeFill.Size = UDim2.fromScale(math.clamp(foe / limit, 0, 1), 1)
	clockL.Text = fmt(state:GetAttribute("HpClock") or 600) .. (state:GetAttribute("HpClockPaused") and " II" or "")

	local idx = tonumber(state:GetAttribute("HpIndex")) or 1
	local remaining = (state:GetAttribute("HpPointEndsAt") or now()) - now()
	local occ = state:GetAttribute("HpOcc") or "N"
	local rel = occ == "C" and "C" or ((occ == "A" or occ == "B") and (occ == mine and "you" or "foe") or "N")

	if phase == "results" then
		results.Visible = true
		marker.Visible, status.Visible, nextL.Visible = false, false, false
		local w = state:GetAttribute("HpWinner")
		local title = (w == "draw") and "DRAW" or (w == mine and "VICTORY" or "DEFEAT")
		resTitle.Text = title
		resStroke.Color = title == "VICTORY" and BLUE or (title == "DEFEAT" and RED or YELLOW)
		resScore.Text = ("%d – %d"):format(you, foe)
		resNext.Text = "NEXT MATCH IN " .. fmt((state:GetAttribute("HpResultsEndAt") or now()) - now())
		pointL.Text = ""
		script:SetAttribute("HardpointHUDState", "results")
		return
	end
	results.Visible = false
	status.Visible = true
	local warm = phase == "warmup"
	pointL.Text = warm and ("P1 IN " .. fmt(remaining)) or ("P%d · %s"):format(idx, fmt(remaining))
	if warm then
		status.Text, status.TextColor3 = "GET READY", Color3.new(1, 1, 1)
	elseif rel == "you" then
		status.Text, status.TextColor3 = "SECURED · +1 / s", BLUE_T
	elseif rel == "foe" then
		status.Text, status.TextColor3 = "ENEMY HAS THE POINT", RED_T
	elseif rel == "C" then
		status.Text, status.TextColor3 = "CONTESTED", YELLOW
	else
		status.Text, status.TextColor3 = "POINT OPEN", Color3.new(1, 1, 1)
	end
	local showNext = (not warm) and state:GetAttribute("HpShowNext") == true
	nextL.Visible = showNext
	if showNext then
		local ni = tonumber(state:GetAttribute("HpNextIndex")) or 1
		nextL.Text = ("NEXT: P%d %s IN %s"):format(ni, points[ni] and string.upper(points[ni].name) or "", fmt(remaining))
	end

	-- marker
	local p = points[warm and 1 or idx]
	marker.Visible = p ~= nil
	if p then
		local blink = rel == "C" and (math.floor(os.clock() * 4) % 2 == 1)
		local col = warm and Color3.fromRGB(201, 206, 216) or (rel == "you" and BLUE or (rel == "foe" and RED or (rel == "C" and YELLOW or Color3.new(1, 1, 1))))
		mLabel.Text = warm and ("LOCKED " .. fmt(remaining)) or (rel == "you" and "DEFEND" or (rel == "C" and "CONTESTED" or "CAPTURE"))
		mLabel.TextColor3 = (rel == "you" and BLUE_T) or (rel == "foe" and RED_T) or (rel == "C" and YELLOW) or Color3.new(1, 1, 1)
		diaStroke.Color = col
		diaStroke.Transparency = blink and 0.6 or 0
		diaNum.Text = tostring(warm and 1 or idx)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local inside = H and H.inPoint(hrp.Position, p.centre)
			mDist.Text = (inside and not warm) and "ON POINT" or (math.floor((hrp.Position - p.centre).Magnitude + 0.5) .. " studs")
		end
		local sp, onScreen = cam:WorldToViewportPoint(p.centre + Vector3.new(0, 34, 0))
		local x, y, edge = sp.X, sp.Y, false
		if sp.Z < 0 then x, y, edge = vp.X - x, vp.Y * 0.85, true end
		local inset = gui.AbsolutePosition
		if not onScreen or sp.Z < 0 then edge = true end
		x = math.clamp(x, 70, vp.X - 70)
		y = math.clamp(y, 150, vp.Y - 40)
		marker.Position = UDim2.fromOffset(x - inset.X, y - inset.Y)
		marker.Size = edge and UDim2.fromOffset(100, 62) or UDim2.fromOffset(120, 74)
	end
	script:SetAttribute("HardpointHUDState", rel)
end)
