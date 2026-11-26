-- PlaytimeClient v1.0 (Mecha Dino Arena) — the playtime gift chip and its reward track (LocalScript, StarterPlayerScripts).
-- Kepu 2026-11-26 16:31 "play time rewards ... skill points and a skin the longer you play in a session"; mockup
--   docs/mockups/playtime_rewards_v0.1.html, 16:35 pick "A" (gift chip + track). Works with PlaytimeServer 1.0.
-- Chip (ScreenGui "PlaytimeRewards", DisplayOrder 7, DeviceSafeInsets, ResetOnSpawn false): TextButton "Chip" at the top centre
--   (AnchorPoint (0.5, 0), y PlaytimeChipY 8), 44 tall, dark plate rgb(13, 18, 24) at 0.12, corner 10, white stroke (0.5): a drawn
--   gift (yellow box, red ribbon), "NEXT m:ss" (FredokaOne 18) and a 64 x 6 bar filling toward the next reward; when a reward is
--   ready: "REWARD READY", yellow stroke that pulses. Hidden when every reward is claimed.
-- Track (Frame "Panel", under the chip at y 60): width min(PlaytimePanelW 720, screen - 24); header "PLAYTIME REWARDS · m:ss PLAYED"
--   (Silkscreen-like GothamBlack) + X (44 x 44); 6 reward cards (6 a row from 640 px wide, else 3): time, reward (+N PT / +N PTS /
--   OVERTIME SKIN), button 44 tall: CLAIM (yellow) / CLAIMED (green text) / the time left (grey); a line "Keeps counting in Arena matches.
--   Resets when you leave the game." CLAIM -> PlaytimeRequest:InvokeServer("claim", i); the result shows as a toast under the chip
--   for 2.5 s ("+2 SKILL POINTS", "OVERTIME SKIN UNLOCKED", "TRY AGAIN").
-- Shown when: ReplicatedStorage ServerKind == "hub", player InMenu / PrInMatch / PrInLobby / IslandPickOpen not true, TutLane 0 or
--   unset, no enabled PlayerGui.Tutorial, the island Lab closed (character SkillScreenOpen not true), PlaytimeLoaded true. The chip
--   tap toggles the track; the track closes when the chip hides.
-- Played seconds = player PlaytimeBase + (server time - PlaytimeAt). While the track is open the mouse is free on PC (RenderStep
--   "PlaytimeMouse", Camera + 2).
-- Switches / numbers (script attributes): PlaytimeClientEnabled (true, read at start), PlaytimeChipY (8), PlaytimePanelW (720).
-- Diagnostics: PlaytimeClientVersion, PlaytimeChipShown, PlaytimeOpen, PlaytimeClaimPresses, PlaytimeLastToast.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 track capped at 30 min
-- v1.1 (Kepu 2026-11-26 16:44 "Nah this is too crazy, cap out at 30 minutes to get the overtime skin"; points spread: standing pick, recommended): the cards follow PlaytimeServer 1.1: 5 / 10 / 15 MIN +1 PT, 20 / 25 MIN +2 PTS, 30 MIN OVERTIME SKIN.
--   Switch: script attribute PlaytimeShortTrackEnabled (true, read at start; false = the 1.0 cards). Layout unchanged.
script:SetAttribute("PlaytimeClientVersion", VERSION)
for k, v in pairs({PlaytimeClientEnabled = true, PlaytimeChipY = 8, PlaytimePanelW = 720, PlaytimeClaimPresses = 0}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
if script:GetAttribute("PlaytimeClientEnabled") == false then return end
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local YELLOW, RED, GREEN, PLATE, CARD, MUTED = Color3.fromRGB(255, 200, 50), Color3.fromRGB(192, 57, 43), Color3.fromRGB(94, 224, 138),
	Color3.fromRGB(13, 18, 24), Color3.fromRGB(21, 29, 41), Color3.fromRGB(143, 162, 184)
local TRACK = {{t = 300, txt = "+1 PT"}, {t = 600, txt = "+1 PT"}, {t = 1200, txt = "+2 PTS"}, {t = 1800, txt = "+2 PTS"},
	{t = 2700, txt = "+3 PTS"}, {t = 3600, txt = "OVERTIME SKIN"}}
if script:GetAttribute("PlaytimeShortTrackEnabled") == nil then script:SetAttribute("PlaytimeShortTrackEnabled", true) end -- v1.1
if script:GetAttribute("PlaytimeShortTrackEnabled") ~= false then
	TRACK = {{t = 300, txt = "+1 PT"}, {t = 600, txt = "+1 PT"}, {t = 900, txt = "+1 PT"}, {t = 1200, txt = "+2 PTS"},
		{t = 1500, txt = "+2 PTS"}, {t = 1800, txt = "OVERTIME SKIN"}}
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) new("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function stroke(o, c, t, th) return new("UIStroke", {Color = c, Transparency = t, Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function mmss(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60) end
	return string.format("%d:%02d", s // 60, s % 60)
end

local old = pg:FindFirstChild("PlaytimeRewards")
if old then old:Destroy() end
local gui = new("ScreenGui", {Name = "PlaytimeRewards", DisplayOrder = 7, ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets}, pg)

-- chip
local chip = new("TextButton", {Name = "Chip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = PLATE, BackgroundTransparency = 0.12,
	Text = "", AutoButtonColor = true, Visible = false}, gui)
corner(chip, 10)
local chipStroke = stroke(chip, Color3.new(1, 1, 1), 0.5, 1.5)
new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, chip)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder}, chip)
local gift = new("Frame", {Name = "Gift", Size = UDim2.fromOffset(22, 22), BackgroundColor3 = YELLOW, LayoutOrder = 1}, chip)
corner(gift, 4)
new("Frame", {Size = UDim2.new(0, 4, 1, 0), Position = UDim2.new(0.5, -2, 0, 0), BackgroundColor3 = RED, BorderSizePixel = 0}, gift)
new("Frame", {Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0.42, 0), BackgroundColor3 = RED, BorderSizePixel = 0}, gift)
local chipText = new("TextLabel", {Name = "T", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X,
	Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.6, Text = "NEXT 0:00",
	LayoutOrder = 2}, chip)
local barBack = new("Frame", {Name = "Bar", Size = UDim2.fromOffset(64, 6), BackgroundColor3 = Color3.fromRGB(42, 50, 66),
	BorderSizePixel = 0, LayoutOrder = 3}, chip)
corner(barBack, 3)
local barFill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = YELLOW, BorderSizePixel = 0}, barBack)
corner(barFill, 3)

-- toast
local toast = new("TextLabel", {Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = PLATE, BackgroundTransparency = 0.05,
	Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Text = "", Visible = false, ZIndex = 5}, gui)
corner(toast, 10)
stroke(toast, YELLOW, 0, 2)
new("UIPadding", {PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)}, toast)
local toastTok = 0
local function showToast(s)
	toastTok += 1
	local my = toastTok
	toast.Text = s
	toast.Visible = true
	script:SetAttribute("PlaytimeLastToast", s)
	task.delay(2.5, function() if toastTok == my then toast.Visible = false end end)
end

-- track panel
local panel = new("Frame", {Name = "Panel", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.fromOffset(720, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = PLATE, BackgroundTransparency = 0.02,
	Visible = false, ZIndex = 2}, gui)
corner(panel, 14)
stroke(panel, YELLOW, 0, 2.5)
new("UIPadding", {PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, panel)
new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, panel)
local head = new("Frame", {Name = "Head", Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 2}, panel)
local title = new("TextLabel", {Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, -54, 1, 0), Font = Enum.Font.GothamBlack,
	TextSize = 16, TextColor3 = YELLOW, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, Text = "PLAYTIME REWARDS", ZIndex = 2}, head)
new("UITextSizeConstraint", {MaxTextSize = 16, MinTextSize = 10}, title)
title.TextScaled = true
local closeB = new("TextButton", {Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.fromRGB(27, 35, 48), Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Text = "X", ZIndex = 2}, head)
corner(closeB, 10)
local grid = new("Frame", {Name = "Grid", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
	LayoutOrder = 2, ZIndex = 2}, panel)
local gridLayout = new("UIGridLayout", {CellPadding = UDim2.fromOffset(8, 8), CellSize = UDim2.fromOffset(110, 124), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
new("TextLabel", {Name = "Note", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.Gotham, TextSize = 13,
	TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Text = "Keeps counting in Arena matches. Resets when you leave the game.",
	TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, ZIndex = 2}, panel)
local cards = {}
for i, r in ipairs(TRACK) do
	local c = new("Frame", {Name = "R" .. i, BackgroundColor3 = CARD, LayoutOrder = i, ZIndex = 2}, grid)
	corner(c, 10)
	local cs = stroke(c, Color3.fromRGB(42, 58, 80), 0, 2)
	new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, c)
	new("TextLabel", {Name = "Time", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = MUTED, Text = (r.t // 60) .. " MIN", ZIndex = 2}, c)
	local rl = new("TextLabel", {Name = "Reward", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 34),
		Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = i == #TRACK and YELLOW or Color3.new(1, 1, 1), Text = r.txt, TextWrapped = true, ZIndex = 2}, c)
	new("UITextSizeConstraint", {MaxTextSize = 18, MinTextSize = 10}, rl)
	rl.TextScaled = true
	local b = new("TextButton", {Name = "Btn", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44),
		Font = Enum.Font.GothamBlack, TextSize = 13, Text = "LOCKED", BackgroundColor3 = Color3.fromRGB(34, 44, 58), TextColor3 = MUTED,
		AutoButtonColor = true, ZIndex = 2}, c)
	corner(b, 8)
	cards[i] = {frame = c, stroke = cs, btn = b, state = "locked", waiting = false}
end

local function played()
	local base = tonumber(player:GetAttribute("PlaytimeBase")) or 0
	local at = tonumber(player:GetAttribute("PlaytimeAt"))
	if not at then return base end
	return base + math.max(0, workspace:GetServerTimeNow() - at)
end
local function claimedFlags()
	local s = player:GetAttribute("PlaytimeClaimed")
	local out = {}
	for i = 1, #TRACK do out[i] = type(s) == "string" and s:sub(i, i) == "1" end
	return out
end

local open = false
local function setOpen(v)
	open = v and true or false
	panel.Visible = open
	script:SetAttribute("PlaytimeOpen", open)
	local BIND = "PlaytimeMouse"
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	if open then
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 2, function()
			if UIS.MouseEnabled then
				UIS.MouseBehavior = Enum.MouseBehavior.Default
				UIS.MouseIconEnabled = true
			end
		end)
	end
end
chip.Activated:Connect(function() setOpen(not open) end)
closeB.Activated:Connect(function() setOpen(false) end)

for i, c in ipairs(cards) do
	c.btn.Activated:Connect(function()
		if c.state ~= "ready" or c.waiting then return end
		c.waiting = true
		c.btn.Text = "..."
		script:SetAttribute("PlaytimeClaimPresses", (script:GetAttribute("PlaytimeClaimPresses") or 0) + 1)
		task.spawn(function()
			local r = ReplicatedStorage:FindFirstChild("PlaytimeRequest")
			local ok, res, text = false, nil, nil
			if r then ok, res, text = pcall(function() return r:InvokeServer("claim", i) end) end
			c.waiting = false
			if ok and res == "ok" then showToast(text or "CLAIMED")
			elseif ok and res == "claimed" then showToast("ALREADY CLAIMED")
			else showToast("TRY AGAIN") end
		end)
	end)
end

local function shouldShow()
	if ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" then return false end
	if player:GetAttribute("PlaytimeLoaded") ~= true then return false end
	for _, a in ipairs({"InMenu", "PrInMatch", "PrInLobby", "IslandPickOpen"}) do
		if player:GetAttribute(a) == true then return false end
	end
	if (tonumber(player:GetAttribute("TutLane")) or 0) > 0 then return false end
	local tut = pg:FindFirstChild("Tutorial")
	if tut and tut:IsA("ScreenGui") and tut.Enabled then return false end
	local ch = player.Character
	if ch and ch:GetAttribute("SkillScreenOpen") == true then return false end
	return true
end

local pulseT = 0
local lastShown
RunService.RenderStepped:Connect(function(dt)
	local p = played()
	local cl = claimedFlags()
	local ready, nextI, allDone = false, nil, true
	for i, r in ipairs(TRACK) do
		if not cl[i] then
			allDone = false
			if p >= r.t then ready = true elseif not nextI then nextI = i end
		end
	end
	local show = shouldShow() and not allDone
	chip.Visible = show
	if show ~= lastShown then
		lastShown = show
		script:SetAttribute("PlaytimeChipShown", show)
	end
	if not show and open then setOpen(false) end
	chip.Position = UDim2.new(0.5, 0, 0, tonumber(script:GetAttribute("PlaytimeChipY")) or 8)
	if ready then
		chipText.Text = "REWARD READY"
		barFill.Size = UDim2.fromScale(1, 1)
		pulseT += dt
		chipStroke.Color = YELLOW
		chipStroke.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(pulseT * 5))
		chipStroke.Thickness = 2
	elseif nextI then
		local prev = 0
		for i = nextI - 1, 1, -1 do prev = TRACK[i].t break end
		local span = TRACK[nextI].t - prev
		chipText.Text = "NEXT " .. mmss(TRACK[nextI].t - p)
		barFill.Size = UDim2.fromScale(math.clamp((p - prev) / span, 0, 1), 1)
		chipStroke.Color = Color3.new(1, 1, 1)
		chipStroke.Transparency = 0.5
		chipStroke.Thickness = 1.5
	end
	if open then
		local vw = gui.AbsoluteSize.X
		local w = math.min(tonumber(script:GetAttribute("PlaytimePanelW")) or 720, vw - 24)
		panel.Size = UDim2.fromOffset(w, 0)
		local cols = w >= 640 and 6 or 3
		local inner = w - 28
		gridLayout.CellSize = UDim2.fromOffset(math.floor((inner - 8 * (cols - 1)) / cols), 124)
		title.Text = "PLAYTIME REWARDS · " .. mmss(p) .. " PLAYED"
		for i, c in ipairs(cards) do
			local st = cl[i] and "done" or (p >= TRACK[i].t and "ready" or "locked")
			c.state = st
			if not c.waiting then
				if st == "done" then
					c.btn.Text, c.btn.BackgroundTransparency, c.btn.TextColor3 = "CLAIMED", 1, GREEN
				elseif st == "ready" then
					c.btn.Text, c.btn.BackgroundTransparency, c.btn.BackgroundColor3, c.btn.TextColor3 = "CLAIM", 0, YELLOW, Color3.fromRGB(26, 19, 0)
				else
					c.btn.Text, c.btn.BackgroundTransparency, c.btn.BackgroundColor3, c.btn.TextColor3 = mmss(TRACK[i].t - p), 0, Color3.fromRGB(34, 44, 58), MUTED
				end
			end
			c.stroke.Color = st == "ready" and YELLOW or Color3.fromRGB(42, 58, 80)
		end
	end
	toast.Position = UDim2.new(0.5, 0, 0, open and (panel.AbsoluteSize.Y + 70) or 60)
end)
