-- FirstSteps v1.0 (Mecha Dino Arena) — the island lobby's PLAY button and the FIRST STEPS card (LocalScript, StarterPlayerScripts).
-- Kepu 2026-11-27 14:15 pick "A · corner PLAY + side checklist" on docs/mockups/first_steps_v0.1.html (captures
--   docs/mockups/first_steps_v0.1/phone_A_*.jpg, pc_A_corner_play.jpg). Works with FirstStepsServer 1.0 and HubServer 1.10
--   (HubQueueRequest "join").
-- Shown on hub servers (ReplicatedStorage ServerKind "hub") while: not InMenu, not PrInMatch / PrInLobby / IslandPickOpen, TutLane 0,
--   no enabled PlayerGui.Tutorial, the island Lab closed (character SkillScreenOpen not true), no portal trip phase (HubTripState
--   "count" / "saving" / "teleporting"). ScreenGui "FirstSteps" (DisplayOrder 30, IgnoreGuiInset, ResetOnSpawn false, Sibling).
-- PLAY (always, while shown): phone (TouchEnabled) 138 x 58 at the top right, its top edge 60 px down, 16 px from the right (under
--   EMOTE); PC 270 x 96 at the bottom right, 28 px in. Yellow, "▶ PLAY" over "ARENA · 4V4" (PC "ARENA · 4V4 · HARDPOINT / TDM /
--   FFA"), white outline pulsing. Press -> ReplicatedStorage.HubQueueRequest("join"). While player HubQueueState is "queued" it reads
--   "QUEUED" over "TAP TO LEAVE" (dark, yellow text) and a press sends "leave"; "found" -> "MATCH FOUND" (no press).
-- FIRST STEPS card (while FsLoaded and not FsFinished): left, 16 px in, top 98 px (phone, 222 wide) / 150 px (PC, 300 wide).
--   Header "FIRST STEPS" + "<done>/4"; 4 rows (number dot, text, reward chip): done = green tick, faded text, "GOT"; the first
--   not-done step = yellow ring and tinted row; the rest grey. Footer "ALL 4 DONE: +3 BONUS PTS". Tap the header -> folds to one
--   line "FIRST STEPS n/4 · <next step>" (and back); remembered for this session.
-- Toast (FsLast changes, hub only): green-outlined panel top centre (112 px phone / 130 PC down) "STEP DONE" / "+<n> SKILL POINT(S)"
--   (bonus: "FIRST STEPS COMPLETE" / "+<n> BONUS POINTS"), 2.6 s.
-- Tutorial hand-off: Tutorial 1.8's PLAY YOUR FIRST MATCH sets the LOCAL player attribute FsAutoQueue = true (not replicated); once
--   this server is a hub, TutStep is 0, not InMenu and the character stands in the safe area (HubInZone) -> one "join"; the flag is
--   cleared (also after FsAutoQueueWait (40) s).
-- Switches (script attributes): FirstStepsEnabled (true, read per frame; false = nothing shown), FirstStepsPlayEnabled (true, per
--   frame; false = no PLAY button), FirstStepsCardEnabled (true, per frame), FsAutoQueueWait (40).
-- Diagnostics (player): FirstStepsVersion, FirstStepsShown ("play+card" / "play" / "hidden"), FirstStepsLastPress ("join" /
--   "leave" / "auto"), FirstStepsToast (last toast text).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 card starts folded, toast on every server
-- v1.1 (Kepu 2026-11-27 14:41 "The play button being constantly there and the list being constantly open is annoying ... Remove the
--   play button"): the PLAY button is off through FirstStepsPlayEnabled = false (set on this script in Edit; the 1.0 switch). While
--   script attribute FirstStepsStartFolded ~= false (default true, read at start) the card starts folded to one line ("FIRST STEPS
--   n/4" + the next step; tap the header to open / fold). While FirstStepsToastEverywhere ~= false (default true, read per toast) a
--   step finished on the Arena match server shows its toast there too (1.0: hub servers only).
local player = Players.LocalPlayer
player:SetAttribute("FirstStepsVersion", VERSION)
for k, v in pairs({FirstStepsEnabled = true, FirstStepsPlayEnabled = true, FirstStepsCardEnabled = true, FsAutoQueueWait = 40}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local pg = player:WaitForChild("PlayerGui")
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local C = {plate = Color3.fromRGB(13, 18, 24), plate2 = Color3.fromRGB(24, 31, 42), yellow = Color3.fromRGB(255, 200, 50),
	ink = Color3.fromRGB(26, 19, 0), white = Color3.new(1, 1, 1), muted = Color3.fromRGB(147, 162, 182), green = Color3.fromRGB(70, 224, 138),
	line = Color3.fromRGB(46, 58, 76), volt = Color3.fromRGB(127, 233, 255)}
local STEPS = {{"PLAY YOUR FIRST MATCH", "+1 PT"}, {"SPEND A POINT IN THE LAB", "+1 PT"}, {"CLAIM A QUEST AT THE STAND", "+1 PT"},
	{"WIN AN ARENA MATCH", "+2 PTS"}}

local function new(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(p, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, p) end
local function stroke(p, col, th, tr)
	return new("UIStroke", {Color = col, Thickness = th or 2, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p)
end
local function txt(parent, t, size, col, props)
	local l = new("TextLabel", {BackgroundTransparency = 1, FontFace = SILK, Text = t, TextSize = size, TextColor3 = col or C.white,
		Size = UDim2.new(1, 0, 0, size + 4), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center}, parent)
	l:SetAttribute("FontSwap", "keep")
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function glyph(parent, t, size, col)
	local l = new("TextLabel", {BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = t, TextSize = size, TextColor3 = col,
		Size = UDim2.fromScale(1, 1)}, parent)
	l:SetAttribute("FontSwap", "keep")
	return l
end

local gui = new("ScreenGui", {Name = "FirstSteps", DisplayOrder = 30, ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false}, pg)
local toastGui = new("ScreenGui", {Name = "FirstStepsToast", DisplayOrder = 62, ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, pg) -- v1.1: the toast shows while the lobby UI is hidden (Arena server)

-- ---------- PLAY ----------
local play = new("TextButton", {Name = "Play", BackgroundColor3 = C.yellow, Text = "", AutoButtonColor = true}, gui)
local playCorner = corner(play, 12)
local playStroke = stroke(play, C.white, 3, 0.1)
TweenService:Create(playStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.85}):Play()
local playBig = txt(play, "▶ PLAY", 22, C.ink, {TextXAlignment = Enum.TextXAlignment.Center})
local playSub = txt(play, "ARENA · 4V4", 8, C.ink, {AnchorPoint = Vector2.new(0, 1), TextXAlignment = Enum.TextXAlignment.Center,
	TextTransparency = 0.25})

local layoutPhone
local function layoutPlay(phone)
	if phone then
		play.AnchorPoint = Vector2.new(1, 0)
		play.Position = UDim2.new(1, -16, 0, 60)
		play.Size = UDim2.fromOffset(138, 58)
		playCorner.CornerRadius = UDim.new(0, 12)
		playBig.TextSize = 22
		playBig.Position = UDim2.fromOffset(0, 6)
		playBig.Size = UDim2.new(1, 0, 0, 24)
		playSub.TextSize = 8
		playSub.Position = UDim2.new(0, 0, 1, -6)
		playSub.Size = UDim2.new(1, 0, 0, 10)
	else
		play.AnchorPoint = Vector2.new(1, 1)
		play.Position = UDim2.new(1, -28, 1, -28)
		play.Size = UDim2.fromOffset(270, 96)
		playCorner.CornerRadius = UDim.new(0, 16)
		playBig.TextSize = 34
		playBig.Position = UDim2.fromOffset(0, 10)
		playBig.Size = UDim2.new(1, 0, 0, 36)
		playSub.TextSize = 11
		playSub.Position = UDim2.new(0, 0, 1, -10)
		playSub.Size = UDim2.new(1, 0, 0, 13)
	end
end
local playMode = ""
local function drawPlay(phone)
	local qs = player:GetAttribute("HubQueueState")
	local mode = qs == "queued" and "queued" or qs == "found" and "found" or "play"
	if mode == playMode then return end
	playMode = mode
	if mode == "play" then
		play.BackgroundColor3 = C.yellow
		playBig.Text, playSub.Text = "▶ PLAY", phone and "ARENA · 4V4" or "ARENA · 4V4 · HARDPOINT / TDM / FFA"
		playBig.TextColor3, playSub.TextColor3 = C.ink, C.ink
		playStroke.Color = C.white
	else
		play.BackgroundColor3 = C.plate2
		playBig.Text = mode == "queued" and "QUEUED" or "MATCH FOUND"
		playSub.Text = mode == "queued" and "TAP TO LEAVE" or "GET READY"
		playBig.TextColor3, playSub.TextColor3 = C.yellow, C.yellow
		playStroke.Color = C.yellow
	end
	playBig.TextSize = (phone and 22 or 34) * (mode == "play" and 1 or 0.8)
end
local lastPress = 0
play.Activated:Connect(function()
	if os.clock() - lastPress < 0.5 then return end
	lastPress = os.clock()
	local r = ReplicatedStorage:FindFirstChild("HubQueueRequest")
	if not r then return end
	local qs = player:GetAttribute("HubQueueState")
	if qs == "queued" then
		r:FireServer("leave")
		player:SetAttribute("FirstStepsLastPress", "leave")
	elseif qs ~= "found" then
		r:FireServer("join")
		player:SetAttribute("FirstStepsLastPress", "join")
	end
end)

-- ---------- card ----------
local folded = script:GetAttribute("FirstStepsStartFolded") ~= false -- v1.1 (1.0: false)
local card
local cardKey = ""
local function drawCard(phone)
	local done = tostring(player:GetAttribute("FsDone") or "0000")
	local key = done .. (phone and "p" or "c") .. (folded and "f" or "")
	if key == cardKey and card then return end
	cardKey = key
	if card then card:Destroy() end
	local w = phone and 222 or 300
	card = new("Frame", {Name = "Card", Position = UDim2.fromOffset(16, phone and 98 or 150), Size = UDim2.fromOffset(w, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.plate, BackgroundTransparency = 0.08}, gui)
	corner(card, 10)
	stroke(card, C.yellow, 2)
	new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, folded and 6 or 7)}, card)
	new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, card)
	local n, cur = 0, nil
	for i = 1, 4 do
		if done:sub(i, i) == "1" then n += 1 elseif not cur then cur = i end
	end
	local head = new("TextButton", {Name = "Head", Size = UDim2.new(1, 0, 0, phone and 18 or 22), BackgroundTransparency = 1, Text = "",
		LayoutOrder = 0}, card)
	txt(head, "FIRST STEPS", phone and 11 or 14, C.yellow, {Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -60, 1, 0)})
	txt(head, n .. "/4", phone and 10 or 12, C.muted, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.new(0, 60, 1, 0), TextXAlignment = Enum.TextXAlignment.Right})
	head.Activated:Connect(function() folded = not folded cardKey = "" end)
	if folded then
		if cur then
			txt(card, STEPS[cur][1], phone and 9 or 11, C.white, {LayoutOrder = 1, Size = UDim2.new(1, 0, 0, phone and 14 or 16),
				Position = UDim2.fromOffset(4, 0)})
		end
		return
	end
	local h = phone and 28 or 34
	for i = 1, 4 do
		local state = done:sub(i, i) == "1" and "done" or (i == cur and "now" or "todo")
		local r = new("Frame", {Name = "Row" .. i, Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.yellow,
			BackgroundTransparency = state == "now" and 0.86 or 1, LayoutOrder = i}, card)
		corner(r, 6)
		local dot = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(h - 10, h - 10),
			BackgroundColor3 = state == "done" and C.green or C.plate2}, r)
		corner(dot, h)
		if state == "now" then stroke(dot, C.yellow, 2) elseif state == "todo" then stroke(dot, C.line, 2) end
		if state == "done" then
			glyph(dot, "✓", phone and 13 or 16, C.ink)
		else
			txt(dot, tostring(i), phone and 10 or 12, state == "now" and C.yellow or C.muted, {Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center})
		end
		local label = txt(r, STEPS[i][1], phone and 9 or 11, state == "todo" and C.muted or C.white, {Position = UDim2.fromOffset(h + 2, 0),
			Size = UDim2.new(1, -(h + 2) - 52, 1, 0), TextWrapped = true})
		if state == "done" then label.TextTransparency = 0.35 end
		local chip = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(phone and 44 or 52, phone and 18 or 22), BackgroundColor3 = state == "done" and C.plate2 or C.yellow}, r)
		corner(chip, 9)
		txt(chip, state == "done" and "GOT" or STEPS[i][2], phone and 8 or 10, state == "done" and C.green or C.ink,
			{Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center})
	end
	txt(card, "ALL 4 DONE: +3 BONUS PTS", phone and 8 or 10, C.volt, {LayoutOrder = 9, Size = UDim2.new(1, 0, 0, phone and 14 or 16),
		TextXAlignment = Enum.TextXAlignment.Center})
end

-- ---------- toast ----------
local toast
local function showToast(t1, t2, phone)
	if toast then toast:Destroy() end
	toast = new("Frame", {Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, phone and 112 or 130),
		Size = UDim2.fromOffset(phone and 250 or 340, phone and 52 or 64), BackgroundColor3 = C.plate}, toastGui) -- v1.1: own gui
	corner(toast, 12)
	stroke(toast, C.green, 3)
	txt(toast, t1, phone and 9 or 11, C.green, {Position = UDim2.fromOffset(0, phone and 7 or 9), Size = UDim2.new(1, 0, 0, 12),
		TextXAlignment = Enum.TextXAlignment.Center})
	txt(toast, t2, phone and 16 or 22, C.white, {Position = UDim2.fromOffset(0, phone and 22 or 28), Size = UDim2.new(1, 0, 0, phone and 20 or 26),
		TextXAlignment = Enum.TextXAlignment.Center})
	player:SetAttribute("FirstStepsToast", t1 .. " / " .. t2)
	local mine = toast
	task.delay(2.6, function() if mine.Parent then mine:Destroy() end end)
end
local seenLast = player:GetAttribute("FsLast")
player:GetAttributeChangedSignal("FsLast"):Connect(function()
	local v = player:GetAttribute("FsLast")
	if v == seenLast then return end
	seenLast = v
	if type(v) ~= "string" then return end
	if ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" and script:GetAttribute("FirstStepsToastEverywhere") == false then return end -- v1.1
	local what, pts = v:match("^([^|]+)|(%d+)|")
	pts = tonumber(pts)
	if not what or not pts then return end
	local phone = UIS.TouchEnabled
	if what == "bonus" then
		showToast("FIRST STEPS COMPLETE", "+" .. pts .. " BONUS POINTS", phone)
	else
		showToast("STEP DONE", "+" .. pts .. (pts == 1 and " SKILL POINT" or " SKILL POINTS"), phone)
	end
end)

-- ---------- visibility ----------
local function hubShown()
	if script:GetAttribute("FirstStepsEnabled") == false then return false end
	if ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" then return false end
	for _, a in ipairs({"InMenu", "PrInMatch", "PrInLobby", "IslandPickOpen"}) do
		if player:GetAttribute(a) == true then return false end
	end
	if (tonumber(player:GetAttribute("TutLane")) or 0) > 0 then return false end
	if (tonumber(player:GetAttribute("TutStep")) or 0) > 0 then return false end
	local tut = pg:FindFirstChild("Tutorial")
	if tut and tut:IsA("ScreenGui") and tut.Enabled then return false end
	local ts = player:GetAttribute("HubTripState")
	if ts == "count" or ts == "saving" or ts == "teleporting" then return false end
	local ch = player.Character
	if ch and ch:GetAttribute("SkillScreenOpen") == true then return false end
	return true
end

-- tutorial hand-off: one join once standing on the islet
local autoSince
local function autoQueue()
	if player:GetAttribute("FsAutoQueue") ~= true then autoSince = nil return end
	autoSince = autoSince or os.clock()
	if os.clock() - autoSince > (tonumber(script:GetAttribute("FsAutoQueueWait")) or 40) then
		player:SetAttribute("FsAutoQueue", nil)
		return
	end
	if ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" then return end
	if (tonumber(player:GetAttribute("TutStep")) or 0) > 0 or player:GetAttribute("InMenu") == true then return end
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0 and ch:GetAttribute("HubInZone") == true) then return end
	player:SetAttribute("FsAutoQueue", nil)
	local r = ReplicatedStorage:FindFirstChild("HubQueueRequest")
	if r and player:GetAttribute("HubQueueState") ~= "queued" then
		r:FireServer("join")
		player:SetAttribute("FirstStepsLastPress", "auto")
	end
end

local lastShown
RunService.RenderStepped:Connect(function()
	autoQueue()
	local phone = UIS.TouchEnabled
	if phone ~= layoutPhone then
		layoutPhone = phone
		layoutPlay(phone)
		playMode = ""
		cardKey = ""
	end
	local base = hubShown()
	local showPlay = base and script:GetAttribute("FirstStepsPlayEnabled") ~= false
	local showCard = base and script:GetAttribute("FirstStepsCardEnabled") ~= false and player:GetAttribute("FsLoaded") == true
		and player:GetAttribute("FsFinished") ~= true
	gui.Enabled = base
	play.Visible = showPlay
	if showPlay then drawPlay(phone) end
	if showCard then drawCard(phone) end
	if card then card.Visible = showCard end
	local s = (showPlay and showCard) and "play+card" or showPlay and "play" or showCard and "card" or "hidden"
	if s ~= lastShown then
		lastShown = s
		player:SetAttribute("FirstStepsShown", s)
	end
end)
