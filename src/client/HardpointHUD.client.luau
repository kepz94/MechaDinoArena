-- HardpointHUD v1.1 (Mecha Dino Arena) — the Arena Hardpoint HUD, PC and phone (LocalScript, StarterPlayerScripts). MDA-402,
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
-- v1.1 (MDA-402, found in Play 2026-11-10), three marker fixes under one switch, script attribute HardpointHUDMarkerFix
--   (default true; false = 1.0):
--   * position: 1.0 placed the marker GuiInset (58 px) too low (WorldToViewportPoint is screen pixels; this ScreenGui's
--     AbsolutePosition is (0, -58)); now the inset is taken off;
--   * a point behind the camera: 1.0 put the marker at 85% of the screen height, on the ability bar; now it goes to the
--     side edge (left or right, the side the point is on) at half height;
--   * the top limit stays where 1.0 showed it (150 px under the top bar), and a marker in the left column (on screen or
--     clamped to the edge) is pushed below the status / next pills (6 px gap) instead of covering them or the score card.
-- v1.2 (practice match, MDA-414, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 10, mockup docs/mockups/practice_match_v0.1.html
--   end screen; Kepu 2026-11-10 "Build"): the results panel becomes a scoreboard (Arena and practice). Panel "Board" in the
--   middle, designed 720 x 316 and scaled by a UIScale = min(1.2, 94% of the width / 720, 86% of the height / 316):
--   VICTORY / DEFEAT / DRAW (40), a line "PRACTICE · <DIFFICULTY> BOTS" (ReplicatedStorage.Practice exists) or "HARDPOINT",
--   two tables side by side from HpBoard (HardpointServer 1.1): your team on the left "BLUE · <score>", the other "RED ·
--   <score>" (no team of yours: A left); columns name (★ you, BOT tag), dino, K, D, on point (m:ss); most kills first, at most
--   6 rows each; your row yellow. Under them "TEAM SCREEN IN m:ss" (practice) / "NEXT MATCH IN m:ss" (HpResultsEndAt), PLAY
--   AGAIN (yellow; closes the board until the next results: the Arena's next match / practice's team screen come by
--   themselves when the results end) and MAIN MENU (DinoModeRequest "menu").
--   Switch: script attribute HardpointHUDBoardEnabled (default true, read at start; false = 1.1's small results panel).
--   Diagnostics: HardpointHUDBoard ("shown" / "dismissed" / "hidden"), HardpointHUDBoardPress ("again" / "menu").
--   Also in 1.2 (QA 2026-11-10: the CONTESTED marker sat on the kill feed): a marker in the left column is pushed below the
--   kill feed's lines too (PlayerGui.KillFeed.Lines, KillFeed 1.0) while they show. Switch: script attribute
--   HardpointHUDMarkerFeedGap (default true, read per frame; false = only below the pills, as 1.1).
-- v1.3 (Team Tags, MDA-418, plan docs/plans/TEAM_TAGS_v1.0.md Task 3; Kepu 2026-11-10 "Both, Arena too"): the 1.0 name tags
--   over players step aside while TeamTags 1.0 is on (the sibling LocalScript "TeamTags" has TeamTagsState "on"), so a
--   player never has both. Switch: script attribute HardpointHUDTagsYieldEnabled (default true, read every 0.5 s; false =
--   1.2: tags always). Diagnostic: HardpointHUDTagsYielding (true / false).
-- v1.4 (marker v2, MDA-423, plan docs/plans/HARDPOINT_SPAWNS_MARKER_v1.0.md Task 3; Kepu 2026-11-10 "the point indicator when
--   it transitions doesn't really accurately show me where the next one is, it's pretty glitchy"; 23:39 "just go with the
--   compass bar forget the arrow"): a compass strip, Frame "Compass" in this ScreenGui.
--   * Place: in the score card's row (y 58, 26 px tall; phone 22) centred in the space right of the card (from the card's
--     right + 12 to the screen's right − 16), 30% of the screen wide (phone 34%), 180 to 420 px; if that space is narrower
--     than 180 px, at the top centre (y 10). Shows ±90° round where the camera faces (flat).
--   * World ticks every 15° that slide as you turn; N / E / S / W letters (north = −Z); a notch at the centre.
--   * Current point (warm-up: point 1): solid diamond with its number, in the point colour (blue you hold, red they hold,
--     yellow contested (blinks), white open, grey locked) and the distance in studs under it. Next point (HpShowNext, last
--     10 s): hollow grey diamond with its number and the countdown ("0:07").
--   * A point outside ±90° sits at the strip's end with ◀ / ▶ on the side it really is; beyond ±170° it keeps the side it
--     had (hysteresis), so it never flips across behind you. Icons glide to their spot (rate 14 / s); when HpIndex changes,
--     the current icon starts from where the NEXT icon was.
--   * The 3D marker over the point shows only while the point is on screen (no edge placement).
--   Phone = UserInputService.TouchEnabled or the character's ArenaTouchState == "on" (the ArenaTouchForceTouch hook).
--   Switch: script attribute HardpointHUDCompassEnabled (default true, read at start; false = 1.3 marker, no compass).
--   Diagnostics: HardpointHUDCompass ("" / "cur:<rel>° next:<rel>°"), HardpointHUDCompassPlace ("row" / "top").
-- v1.5 (MDA-423, found in the QA run 2026-11-11 on a 439 px wide window): the strip's row space now ends 96 px from the right
--   (the CLASSIC camera button sits there) and needs 140 px (1.4: 16 px, 180); when there is no room it goes under the pills in
--   the left column (x 16, the score card's width, 6 px under the lowest visible of Status / Next; place "column") instead
--   of the top centre, where it covered SKILLS / MENU. KillFeed 1.1 keeps its lines under it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService") -- v1.1

local VERSION = "1.5"
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

-- v1.2: the scoreboard (see the header)
if script:GetAttribute("HardpointHUDBoardEnabled") == nil then script:SetAttribute("HardpointHUDBoardEnabled", true) end
local boardOn = script:GetAttribute("HardpointHUDBoardEnabled") ~= false
local BOARD_W, BOARD_H, BOARD_ROWS, ROW_H = 720, 316, 6, 22
local SHORT = {TRex = "T-Rex", Raptor = "Raptor", Pachy = "Pachy", Herrera = "Herrera", Teno = "Teno", Therizino = "Therizino",
	Dilo = "Dilo", Troodon = "Troodon"}
local MUTED_C = Color3.fromRGB(143, 153, 170)
local boardDismissed = false
local bp = Instance.new("Frame")
bp.Name = "Board"
bp.AnchorPoint = Vector2.new(0.5, 0.5)
bp.Position = UDim2.fromScale(0.5, 0.5)
bp.Size = UDim2.fromOffset(BOARD_W, BOARD_H)
bp.BackgroundColor3 = PANEL
bp.BackgroundTransparency = 0.08
bp.Visible = false
bp.Parent = gui
corner(bp, 12)
local bpStroke = stroke(bp, BLUE, 0.1, 2)
local bpScale = Instance.new("UIScale")
bpScale.Parent = bp
local bTitle = label(bp, {Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 42), TextSize = 40, Text = "VICTORY"})
local bSub = label(bp, {Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = MUTED_C, Text = ""})
local COLS = {{x = 0, w = 0.40, a = Enum.TextXAlignment.Left}, {x = 0.40, w = 0.22, a = Enum.TextXAlignment.Left},
	{x = 0.62, w = 0.08, a = Enum.TextXAlignment.Right}, {x = 0.70, w = 0.08, a = Enum.TextXAlignment.Right},
	{x = 0.78, w = 0.22, a = Enum.TextXAlignment.Right}}
local bTables = {}
for t = 1, 2 do
	local f = Instance.new("Frame")
	f.Name = t == 1 and "Mine" or "Theirs"
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(t == 1 and 18 or 366, 84)
	f.Size = UDim2.fromOffset(336, ROW_H * (BOARD_ROWS + 1))
	f.Parent = bp
	local rowsT = {}
	for r = 0, BOARD_ROWS do
		local cells = {}
		for c, col in ipairs(COLS) do
			local l = label(f, {Position = UDim2.new(col.x, 0, 0, r * ROW_H), Size = UDim2.new(col.w, -4, 0, ROW_H), TextSize = r == 0 and 13 or 15,
				TextXAlignment = col.a, TextColor3 = r == 0 and MUTED_C or Color3.new(1, 1, 1), Text = "", RichText = true,
				TextTruncate = Enum.TextTruncate.AtEnd})
			cells[c] = l
		end
		if r > 0 then
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.BackgroundColor3 = Color3.new(1, 1, 1)
			line.BackgroundTransparency = 0.92
			line.Position = UDim2.fromOffset(0, r * ROW_H)
			line.Size = UDim2.new(1, 0, 0, 1)
			line.Parent = f
		end
		rowsT[r] = cells
	end
	bTables[t] = rowsT
end
local bNext = label(bp, {Position = UDim2.fromOffset(18, 248), Size = UDim2.fromOffset(250, 52), TextSize = 15, TextColor3 = YELLOW,
	TextXAlignment = Enum.TextXAlignment.Left, Text = ""})
local function boardButton(name, text, x, w, color, tc)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Position, b.Size = UDim2.fromOffset(x, 248), UDim2.fromOffset(w, 52)
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextSize = 18
	b.TextColor3 = tc
	b.Text = text
	b.Parent = bp
	corner(b, 8)
	stroke(b, Color3.fromRGB(26, 19, 0), 0, 2)
	return b
end
local againB = boardButton("PlayAgain", "PLAY AGAIN", 362, 172, YELLOW, Color3.fromRGB(27, 20, 6))
local menuB = boardButton("MainMenu", "MAIN MENU", 546, 156, Color3.fromRGB(43, 53, 66), Color3.new(1, 1, 1))
againB.Activated:Connect(function()
	boardDismissed = true
	bp.Visible = false
	script:SetAttribute("HardpointHUDBoardPress", "again")
end)
menuB.Activated:Connect(function()
	script:SetAttribute("HardpointHUDBoardPress", "menu")
	local mr = ReplicatedStorage:FindFirstChild("DinoModeRequest")
	if mr then mr:FireServer("menu") end
end)
local function mss(s) s = math.max(0, math.floor((tonumber(s) or 0) + 0.5)) return ("%d:%02d"):format(s // 60, s % 60) end
local function drawBoard(mine, you, foe, title)
	local vp = workspace.CurrentCamera.ViewportSize
	bpScale.Scale = math.min(1.2, vp.X * 0.94 / BOARD_W, vp.Y * 0.86 / BOARD_H)
	bTitle.Text = title
	bTitle.TextColor3 = title == "VICTORY" and BLUE_T or (title == "DEFEAT" and RED_T or YELLOW)
	bpStroke.Color = title == "VICTORY" and BLUE or (title == "DEFEAT" and RED or YELLOW)
	local pr = ReplicatedStorage:FindFirstChild("Practice")
	bSub.Text = pr and ("PRACTICE · " .. string.upper(tostring(pr:GetAttribute("PrDifficulty") or "")) .. " BOTS") or "HARDPOINT"
	bNext.Text = (pr and "TEAM SCREEN IN " or "NEXT MATCH IN ") .. fmt((state:GetAttribute("HpResultsEndAt") or now()) - now())
	local ok, list = pcall(function() return HttpService:JSONDecode(state:GetAttribute("HpBoard") or "[]") end)
	if not ok or type(list) ~= "table" then list = {} end
	local left = (mine == "A" or mine == "B") and mine or "A"
	local right = left == "A" and "B" or "A"
	local scores = {A = state:GetAttribute("HpScoreA") or 0, B = state:GetAttribute("HpScoreB") or 0}
	for t, side in ipairs({left, right}) do
		local rows = {}
		for _, r in ipairs(list) do if r.team == side then table.insert(rows, r) end end
		table.sort(rows, function(x, y) if x.k ~= y.k then return x.k > y.k end return tostring(x.name) < tostring(y.name) end)
		local T = bTables[t]
		local hdCol = t == 1 and "#5aa0ff" or "#e0284a"
		T[0][1].Text = ('<font color="%s">%s · %d</font>'):format(hdCol, t == 1 and "BLUE" or "RED", scores[side])
		T[0][2].Text, T[0][3].Text, T[0][4].Text, T[0][5].Text = "Dino", "K", "D", "On point"
		for i = 1, BOARD_ROWS do
			local r = rows[i]
			local cells = T[i]
			if r then
				local me = r.id == "u" .. player.UserId
				local nm = (me and "★ " or "") .. tostring(r.name)
				if r.bot then nm = nm .. ' <font size="10" color="#8f99aa">BOT</font>' end
				cells[1].Text, cells[2].Text = nm, SHORT[r.species] or tostring(r.species or "")
				cells[3].Text, cells[4].Text, cells[5].Text = tostring(r.k or 0), tostring(r.d or 0), mss(r.pt)
				for _, c in ipairs(cells) do c.TextColor3 = me and YELLOW or Color3.new(1, 1, 1) end
			else
				for _, c in ipairs(cells) do c.Text = "" end
			end
		end
	end
end

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

-- v1.4: the compass (see the header)
if script:GetAttribute("HardpointHUDCompassEnabled") == nil then script:SetAttribute("HardpointHUDCompassEnabled", true) end
local compassOn = script:GetAttribute("HardpointHUDCompassEnabled") ~= false
local UIS = game:GetService("UserInputService")
local GREY = Color3.fromRGB(201, 206, 216)
local cmp = Instance.new("Frame")
cmp.Name = "Compass"
cmp.BackgroundColor3 = PANEL
cmp.BackgroundTransparency = 0.25
cmp.ClipsDescendants = true
cmp.Visible = false
cmp.Parent = gui
corner(cmp, 6)
stroke(cmp, Color3.new(1, 1, 1), 0.75, 1)
local cmpTicks = {}
for i = 0, 23 do
	local deg = i * 15
	local t
	local letter = ({[0] = "N", [90] = "E", [180] = "S", [270] = "W"})[deg]
	if letter then
		t = label(cmp, {Size = UDim2.fromOffset(16, 14), AnchorPoint = Vector2.new(0.5, 0), TextSize = 12, Text = letter,
			TextColor3 = Color3.fromRGB(230, 236, 245)})
	else
		t = Instance.new("Frame")
		t.BorderSizePixel = 0
		t.BackgroundColor3 = Color3.new(1, 1, 1)
		t.BackgroundTransparency = deg % 45 == 0 and 0.35 or 0.6
		t.AnchorPoint = Vector2.new(0.5, 0)
		t.Parent = cmp
	end
	cmpTicks[i] = {g = t, deg = deg, letter = letter ~= nil}
end
local notch = label(cmp, {Size = UDim2.fromOffset(12, 10), AnchorPoint = Vector2.new(0.5, 1), TextSize = 10, Text = "▲",
	TextColor3 = YELLOW})
local function cmpIcon(name)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Size = UDim2.fromOffset(60, 26)
	f.ZIndex = 3
	f.Parent = cmp
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Rotation = 45
	d.BorderSizePixel = 0
	d.ZIndex = 3
	d.Parent = f
	local ds = stroke(d, Color3.new(1, 1, 1), 0, 2)
	local n = label(f, {AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 11, Text = "1", ZIndex = 4})
	local side = label(f, {AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 12, Text = "", ZIndex = 4})
	local sub = label(cmp, {AnchorPoint = Vector2.new(0.5, 0), TextSize = 10, Text = "", ZIndex = 3,
		TextStrokeTransparency = 0.4})
	return {f = f, d = d, ds = ds, n = n, side = side, sub = sub, x = nil, edgeSide = 0}
end
local curIcon, nextIcon = cmpIcon("Current"), cmpIcon("Next")
local cmpLastIdx, cmpLastT = nil, os.clock()
local function flatYaw(v) return math.deg(math.atan2(v.X, -v.Z)) end -- 0 = north (−Z), 90 = east (+X)
local function wrap(a) return (a + 180) % 360 - 180 end
local function cmpPhone()
	local c = player.Character
	return UIS.TouchEnabled or (c ~= nil and c:GetAttribute("ArenaTouchState") == "on")
end
-- place one icon; returns the relative bearing used
local function cmpPlace(ic, target, camPos, camYaw, W, Hh, dt, look)
	local rel = wrap(flatYaw(target - camPos) - camYaw)
	local x
	if math.abs(rel) <= 90 then
		ic.edgeSide = 0
		x = (0.5 + rel / 180) * W
		ic.side.Text = ""
	else
		local s = rel > 0 and 1 or -1
		if math.abs(rel) > 170 and ic.edgeSide ~= 0 then s = ic.edgeSide end -- hysteresis behind you
		ic.edgeSide = s
		x = s > 0 and (W - 10) or 10
		ic.side.Text = s > 0 and "▶" or "◀"
	end
	if not ic.x then ic.x = x end
	ic.x += (x - ic.x) * (1 - math.exp(-14 * dt))
	local dsz = math.floor(Hh * 0.55)
	ic.f.Size = UDim2.fromOffset(dsz + 24, Hh)
	ic.f.Position = UDim2.fromOffset(ic.x, 0)
	ic.d.Size = UDim2.fromOffset(dsz, dsz)
	ic.d.Position = UDim2.new(0.5, 0, 0, Hh * 0.45)
	ic.n.Position = UDim2.new(0.5, 0, 0, Hh * 0.45)
	ic.n.Size = UDim2.fromOffset(dsz, dsz)
	ic.side.Position = UDim2.new(0.5, ic.edgeSide * (dsz * 0.5 + 7), 0, Hh * 0.45)
	ic.side.Size = UDim2.fromOffset(10, dsz)
	ic.sub.Position = UDim2.fromOffset(ic.x, Hh * 0.45 + dsz * 0.5 + 1)
	ic.sub.Size = UDim2.fromOffset(60, 10)
	return rel
end
local function drawCompass(dt, cam, vp, idx, warm, rel, remaining, showNext)
	local phone = cmpPhone()
	local Hh = phone and 22 or 26
	local W = math.clamp(vp.X * (phone and 0.34 or 0.30), 180, 420)
	local left = card.AbsolutePosition.X - gui.AbsolutePosition.X + card.AbsoluteSize.X + 12
	local room = (vp.X - 96) - left -- v1.5: 96 (1.4: 16)
	local x, y
	if room >= 140 then -- v1.5: 140 (1.4: 180)
		W = math.min(W, room)
		x, y = left + (room - W) / 2, 58 + (58 - Hh) / 2
		script:SetAttribute("HardpointHUDCompassPlace", "row")
	else -- v1.5: under the pills (1.4: the top centre)
		W = card.AbsoluteSize.X
		x, y = 16, (nextL.Visible and 152 or 122) + 24 + 6
		script:SetAttribute("HardpointHUDCompassPlace", "column")
	end
	cmp.Position, cmp.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(W, Hh)
	cmp.Visible = true
	local camPos = cam.CFrame.Position
	local camYaw = flatYaw(cam.CFrame.LookVector)
	for _, t in pairs(cmpTicks) do
		local r = wrap(t.deg - camYaw)
		t.g.Visible = math.abs(r) <= 90
		if t.g.Visible then
			if t.letter then
				t.g.Position = UDim2.fromOffset((0.5 + r / 180) * W, 1)
			else
				local tall = t.deg % 45 == 0
				t.g.Size = UDim2.fromOffset(1, tall and Hh * 0.35 or Hh * 0.2)
				t.g.Position = UDim2.fromOffset((0.5 + r / 180) * W, 1)
			end
		end
	end
	notch.Position = UDim2.fromOffset(W / 2, Hh + 1)
	-- current point
	local ci = warm and 1 or idx
	local p = points[ci]
	if cmpLastIdx and cmpLastIdx ~= ci and nextIcon.x then curIcon.x = nextIcon.x end -- take over from NEXT
	cmpLastIdx = ci
	local diag = ""
	if p then
		local blink = rel == "C" and (math.floor(os.clock() * 4) % 2 == 1)
		local col = warm and GREY or (rel == "you" and BLUE or (rel == "foe" and RED or (rel == "C" and YELLOW or Color3.new(1, 1, 1))))
		curIcon.d.BackgroundColor3 = col
		curIcon.d.BackgroundTransparency = blink and 0.5 or 0
		curIcon.ds.Color = Color3.new(1, 1, 1)
		curIcon.n.Text = tostring(ci)
		curIcon.n.TextColor3 = (col == Color3.new(1, 1, 1) or col == GREY or col == YELLOW) and Color3.fromRGB(26, 19, 0) or Color3.new(1, 1, 1)
		local r = cmpPlace(curIcon, p.centre, camPos, camYaw, W, Hh, dt)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		curIcon.sub.Text = hrp and tostring(math.floor((hrp.Position - p.centre).Magnitude + 0.5)) or ""
		curIcon.f.Visible, curIcon.sub.Visible = true, false -- the distance shows under the strip below
		diag = ("cur:%d"):format(math.floor(r + 0.5))
	else
		curIcon.f.Visible, curIcon.sub.Visible = false, false
	end
	-- next point
	local ni = tonumber(state:GetAttribute("HpNextIndex")) or 1
	local np = showNext and points[ni] or nil
	if np then
		nextIcon.d.BackgroundColor3 = PANEL
		nextIcon.d.BackgroundTransparency = 0.2
		nextIcon.ds.Color = GREY
		nextIcon.n.Text = tostring(ni)
		nextIcon.n.TextColor3 = GREY
		local r = cmpPlace(nextIcon, np.centre, camPos, camYaw, W, Hh, dt)
		nextIcon.f.Visible = true
		diag ..= (" next:%d"):format(math.floor(r + 0.5))
	else
		nextIcon.f.Visible = false
		nextIcon.x = nil
	end
	script:SetAttribute("HardpointHUDCompass", diag)
	return curIcon, nextIcon
end
-- the readouts under the strip (distance / countdown), outside the clipped strip
local cmpUnder = Instance.new("Frame")
cmpUnder.Name = "CompassUnder"
cmpUnder.BackgroundTransparency = 1
cmpUnder.Visible = false
cmpUnder.Parent = gui
local curDist = label(cmpUnder, {AnchorPoint = Vector2.new(0.5, 0), TextSize = 12, Text = "", TextStrokeTransparency = 0.35})
local nextCount = label(cmpUnder, {AnchorPoint = Vector2.new(0.5, 0), TextSize = 12, Text = "", TextColor3 = GREY,
	TextStrokeTransparency = 0.35})

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
	local tt = script.Parent:FindFirstChild("TeamTags") -- v1.3
	local yielding = script:GetAttribute("HardpointHUDTagsYieldEnabled") ~= false and tt ~= nil and tt:GetAttribute("TeamTagsState") == "on"
	script:SetAttribute("HardpointHUDTagsYielding", yielding)
	if yielding then live = false end
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

	if phase == "results" and boardOn then -- v1.2: the scoreboard
		cmp.Visible, cmpUnder.Visible = false, false -- v1.4
		results.Visible = false
		marker.Visible, status.Visible, nextL.Visible = false, false, false
		pointL.Text = ""
		local w = state:GetAttribute("HpWinner")
		local title = (w == "draw") and "DRAW" or (w == mine and "VICTORY" or "DEFEAT")
		bp.Visible = not boardDismissed
		if not boardDismissed then drawBoard(mine, you, foe, title) end
		script:SetAttribute("HardpointHUDBoard", boardDismissed and "dismissed" or "shown")
		script:SetAttribute("HardpointHUDState", "results")
		return
	end
	if bp.Visible or boardDismissed then -- v1.2: out of the results
		bp.Visible, boardDismissed = false, false
		script:SetAttribute("HardpointHUDBoard", "hidden")
	end
	if phase == "results" then
		cmp.Visible, cmpUnder.Visible = false, false -- v1.4
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
		-- v1.1 (see the header): x / y are viewport (screen) pixels; AbsolutePosition is GuiInset pixels higher
		local fix = script:GetAttribute("HardpointHUDMarkerFix") ~= false
		if fix then
			local gi = GuiService:GetGuiInset()
			inset = inset + gi
			if sp.Z < 0 then
				x = (x < vp.X / 2) and 70 or (vp.X - 70)
				y = vp.Y * 0.5
			end
			y = math.max(y, 150 + gi.Y) -- the 1.0 top limit as it showed (150 under the top bar)
			local left = card.AbsolutePosition.X + card.AbsoluteSize.X
			if x - 60 < left then
				local low = nextL.Visible and nextL or status
				y = math.max(y, low.AbsolutePosition.Y + gi.Y + low.AbsoluteSize.Y + 6 + 74)
				local kfg = script:GetAttribute("HardpointHUDMarkerFeedGap") ~= false and gui.Parent:FindFirstChild("KillFeed") -- v1.2
				local lines = kfg and kfg.Enabled and kfg:FindFirstChild("Lines")
				if lines and lines.AbsoluteSize.Y > 1 then
					y = math.max(y, lines.AbsolutePosition.Y + gi.Y + lines.AbsoluteSize.Y + 6 + 74)
				end
			end
		end
		marker.Position = UDim2.fromOffset(x - inset.X, y - inset.Y)
		marker.Size = edge and UDim2.fromOffset(100, 62) or UDim2.fromOffset(120, 74)
		if compassOn and edge then marker.Visible = false end -- v1.4: the compass shows the way; 3D marker only on screen
	end
	-- v1.4: the compass
	if compassOn then
		local t = os.clock()
		local dt = math.clamp(t - cmpLastT, 0, 0.1)
		cmpLastT = t
		local c1, c2 = drawCompass(dt, cam, vp, idx, warm, rel, remaining, showNext)
		local cp, cs = cmp.Position, cmp.Size
		cmpUnder.Visible = true
		cmpUnder.Position, cmpUnder.Size = UDim2.fromOffset(cp.X.Offset, cp.Y.Offset + cs.Y.Offset + 1), UDim2.fromOffset(cs.X.Offset, 14)
		curDist.Visible = c1.f.Visible
		curDist.Text = c1.sub.Text
		curDist.Position, curDist.Size = UDim2.fromOffset(c1.x or 0, 0), UDim2.fromOffset(60, 14)
		nextCount.Visible = c2.f.Visible
		nextCount.Text = "NEXT " .. fmt(remaining)
		nextCount.Position, nextCount.Size = UDim2.fromOffset(c2.x or 0, 0), UDim2.fromOffset(70, 14)
	else
		cmp.Visible, cmpUnder.Visible = false, false
	end
	script:SetAttribute("HardpointHUDState", rel)
end)
