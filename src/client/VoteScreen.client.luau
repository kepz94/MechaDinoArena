-- VoteScreen v1.0 (Mecha Dino Arena) — the Arena mode vote, a quick screen before the dino lineup (LocalScript,
-- StarterPlayerScripts). Mockup docs/mockups/arena_modes_v0.3.html (built in-game and captured in Studio; Kepu 2026-11-26 17:00
--   "Vote mode should be a quick screen before we even go into the Dino lineups like this. Like 15 seconds max to vote";
--   19:21 "Build").
-- Reads ReplicatedStorage.Practice (PracticeServer 1.17): PgPhase ("vote" while the vote runs and for the 1 s winner flash),
--   PgEndsAt (server time the vote ends; = now during the flash), PgVoteModes ("hardpoint,tdm"; cards in that order), PgVotes
--   (JSON {mode = votes}), PgVoteWinner ("" while voting, then the mode), PgVoteHumans (real players voting), PrArena; player
--   PrInLobby, PgVote (your vote, set by the server). Sends RemoteEvent ReplicatedStorage.ModeVote(mode) on a card tap (switch
--   any time; the card you tapped shows at once).
-- ScreenGui "VoteScreen" (DisplayOrder 46, over PregameScreen 45; IgnoreGuiInset; ResetOnSpawn false), shown while PrInLobby ==
--   true and PgPhase == "vote". The lineup screen's canvas: 1000 x 562 on PC, 1000 x 463 on a phone (wider than 1.9:1; text x 1.4),
--   UIScale = min(screen X / 1000, screen Y / H), backdrop rgb(8,11,16), canvas gradient rgb(29,38,56) -> rgb(11,15,21).
--   * top bar (the lineup's): VOTE MODE (orange rgb(255,155,46), 23) at 30,18; "ARENA · PICK THE MODE · N PLAYERS" (10.5) at 30,46
--     (PRACTICE when not the Arena; N = PgVoteHumans, 1 PLAYER); the clock m:ss (32) right; LINEUP NEXT (9, muted) under it; the
--     bar at y 66 (4 high) filling orange with the time left / PgVoteSecs (15).
--   * one card per mode, 290 wide, 15 apart, centred (3 cards: x 50 / 355 / 660); y 100 and 360 high on PC, y 92 and 300 high on
--     a phone. Card rgb(17,24,33), border rgb(38,50,67) 1.5, corner 8. The art panel (10,10, 270 x 150 PC / 111 phone, rgb(13,18,24)):
--     HARDPOINT a ring (rgb(122,99,40) 2) round a yellow diamond with "1"; TEAM DEATHMATCH a blue and a red square with "4" and VS;
--     FREE FOR ALL 8 coloured squares in a ring. Name (15), line (Gotham 9), 3 chips (70 x 20 PC / 78 x 24 phone, rgb(27,37,50)),
--     vote pips (volt rgb(127,233,255) per vote, max(4, players) up to 8, 12 px, 17 apart), "N VOTES".
--   * your vote: yellow border 2.5 and a YOUR VOTE tag on the card's top edge. Winner (PgVoteWinner set): the winner keeps the
--     yellow border, its label reads "WINNER · N VOTES" in yellow, the tag goes; taps do nothing.
--   * footer: "TAP A MODE TO VOTE · ENDS EARLY WHEN EVERYONE HAS VOTED" (9, muted) 21 above the bottom.
--   * the mouse is free while it shows (BindToRenderStep "VoteMouse", Camera + 2).
-- Switch: script attribute VoteScreenEnabled (default true, read per frame; false = never shown; the server still runs the vote).
-- Diagnostics: VoteScreenVersion, VoteScreenState ("hidden" / "voting" / "winner"), VoteScreenLastPress (the mode last tapped).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.0"
script:SetAttribute("VoteScreenVersion", VERSION)
if script:GetAttribute("VoteScreenEnabled") == nil then script:SetAttribute("VoteScreenEnabled", true) end
script:SetAttribute("VoteScreenState", "hidden")

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("Practice", 60)
if not state then return end
local remote = ReplicatedStorage:WaitForChild("ModeVote", 60)

local C = {
	ink = Color3.fromRGB(13, 18, 24), plaque = Color3.fromRGB(17, 24, 33), chip = Color3.fromRGB(27, 37, 50),
	line = Color3.fromRGB(38, 50, 67), text = Color3.fromRGB(231, 237, 245), sub = Color3.fromRGB(201, 212, 226),
	muted = Color3.fromRGB(147, 162, 182), arena = Color3.fromRGB(255, 155, 46), yellow = Color3.fromRGB(255, 200, 50),
	volt = Color3.fromRGB(127, 233, 255), pipOff = Color3.fromRGB(38, 50, 67), ring = Color3.fromRGB(122, 99, 40),
	blue = Color3.fromRGB(90, 160, 255), red = Color3.fromRGB(224, 40, 74), dark = Color3.fromRGB(27, 20, 5),
}
local LOUD = Enum.Font.GothamBlack -- FontSwap turns it Silkscreen
local BODY = Enum.Font.Gotham
local MODES = {
	hardpoint = {name = "HARDPOINT", line = "Hold the moving point", chips = {"4V4", "250 PTS", "10 MIN"}},
	tdm = {name = "TEAM DEATHMATCH", line = "Take down the other team", chips = {"4V4", "30 KILLS", "10 MIN"}},
	ffa = {name = "FREE FOR ALL", line = "Every dino for itself", chips = {"8 DINOS", "20 KILLS", "10 MIN"}},
}
local CARD_W, CARD_GAP = 290, 15

local function now() return workspace:GetServerTimeNow() end
local function fmt(s)
	s = math.max(0, math.ceil((tonumber(s) or 0) - 1e-6))
	return ("%d:%02d"):format(s // 60, s % 60)
end
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(p, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 6)}, p) end

-- ---------- gui ----------
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("VoteScreen")
if old then old:Destroy() end
local gui = new("ScreenGui", {Name = "VoteScreen", DisplayOrder = 46, IgnoreGuiInset = true, ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false}, pg)
local back = new("Frame", {Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 11, 16),
	BorderSizePixel = 0, Active = true}, gui)
local canvas = new("Frame", {Name = "Canvas", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1000, 562), BackgroundColor3 = C.ink, BorderSizePixel = 0, ClipsDescendants = true}, back)
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(29, 38, 56), Color3.fromRGB(11, 15, 21)), Rotation = 90}, canvas)
local uiScale = new("UIScale", {}, canvas)

local ui = {phone = nil, H = 562, TF = 1, cards = {}, key = ""}
local myVote = nil -- the card tapped here (shown before the server answers)

local function text(parent, p)
	return new("TextLabel", {BackgroundTransparency = 1, Font = p.font or LOUD, TextColor3 = p.color or C.text,
		TextSize = (p.size or 10) * ui.TF, Text = p.text or "", TextXAlignment = p.x or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, Size = p.sz or UDim2.new(1, 0, 0, (p.size or 10) * ui.TF + 4),
		Position = p.pos or UDim2.new(), AnchorPoint = p.anchor or Vector2.zero, TextTruncate = Enum.TextTruncate.AtEnd,
		Name = p.name or "Text", ZIndex = p.z or 2}, parent)
end

local function art(panel, mode, ph)
	local s = math.min(ph - 4, 130) -- the ring
	local cx, cy = 135, ph / 2
	if mode == "hardpoint" then
		local ring = new("Frame", {Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1, ZIndex = 3}, panel)
		corner(ring, s)
		new("UIStroke", {Color = C.ring, Thickness = 2}, ring)
		local d = math.floor(s * 0.5 + 0.5)
		local dia = new("Frame", {Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(d, d), Rotation = 45, BackgroundColor3 = C.yellow, BorderSizePixel = 0, ZIndex = 3}, panel)
		corner(dia, 8)
		text(panel, {text = "1", size = 18, color = C.dark, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromOffset(cx, cy + 1),
			sz = UDim2.fromOffset(d, d), z = 4, name = "Num"})
	elseif mode == "tdm" then
		local q = math.floor(s * 0.5 + 0.5)
		local gap = math.floor(q * 0.72 + 0.5)
		for i, col in ipairs({C.blue, C.red}) do
			local x = cx + (i == 1 and -1 or 1) * (gap / 2 + q / 2)
			local sq = new("Frame", {Name = i == 1 and "Blue" or "Red", AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, cy), Size = UDim2.fromOffset(q, q), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 3}, panel)
			corner(sq, 8)
			text(sq, {text = "4", size = 13, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5), sz = UDim2.fromScale(1, 1), z = 4})
		end
		text(panel, {text = "VS", size = 12, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromOffset(cx, cy), sz = UDim2.fromOffset(gap, 20), z = 4})
	elseif mode == "ffa" then
		local r = s * 0.38
		local q = math.floor(s * 0.17 + 0.5)
		for i = 1, 8 do
			local a = math.rad(-90 + (i - 1) * 45)
			local dot = new("Frame", {Name = "Dot" .. i, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(cx + math.cos(a) * r, cy + math.sin(a) * r), Size = UDim2.fromOffset(q, q),
				BackgroundColor3 = Color3.fromHSV(((i - 1) / 8 + 0.75) % 1, 0.62, 1), BorderSizePixel = 0, ZIndex = 3}, panel)
			corner(dot, 4)
		end
	end
end

local top = {}
local function build(modes)
	for _, c in ipairs(canvas:GetChildren()) do
		if not c:IsA("UIGradient") and not c:IsA("UIScale") then c:Destroy() end
	end
	ui.cards = {}
	-- top bar
	top.title = text(canvas, {text = "VOTE MODE", size = 23, color = C.arena, x = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(30, 18), sz = UDim2.fromOffset(500, 26), name = "Title"})
	top.sub = text(canvas, {text = "", size = 10.5, color = C.sub, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(30, 46),
		sz = UDim2.fromOffset(600, 14), name = "Sub"})
	top.clock = text(canvas, {text = "0:15", size = 32, x = Enum.TextXAlignment.Right, pos = UDim2.new(1, -30, 0, 14),
		anchor = Vector2.new(1, 0), sz = UDim2.fromOffset(200, 34), name = "Clock"})
	top.note = text(canvas, {text = "LINEUP NEXT", size = 9, color = C.muted, x = Enum.TextXAlignment.Right,
		pos = UDim2.new(1, -30, 0, 48), anchor = Vector2.new(1, 0), sz = UDim2.fromOffset(300, 12), name = "Note"})
	top.bar = new("Frame", {Name = "Bar", Position = UDim2.fromOffset(30, 66), Size = UDim2.new(1, -60, 0, 4),
		BackgroundColor3 = Color3.fromRGB(40, 46, 56), BorderSizePixel = 0}, canvas)
	corner(top.bar, 2)
	top.fill = new("Frame", {Name = "Fill", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = C.arena}, top.bar)
	corner(top.fill, 2)
	top.foot = text(canvas, {text = "TAP A MODE TO VOTE · ENDS EARLY WHEN EVERYONE HAS VOTED", size = 9, color = C.muted,
		anchor = Vector2.new(0.5, 1), pos = UDim2.new(0.5, 0, 0, ui.H - 21), sz = UDim2.fromOffset(700, 14), name = "Footer"})
	-- cards
	local phone = ui.phone
	local y, h = phone and 92 or 100, phone and 300 or 360
	local ph = phone and 111 or 150
	local total = #modes * CARD_W + math.max(0, #modes - 1) * CARD_GAP
	local x0 = (1000 - total) / 2
	local cw, chh = phone and 78 or 70, phone and 24 or 20
	for i, mode in ipairs(modes) do
		local d = MODES[mode]
		local cx = x0 + (i - 1) * (CARD_W + CARD_GAP)
		local card = new("TextButton", {Name = "Card_" .. mode, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(cx, y),
			Size = UDim2.fromOffset(CARD_W, h), BackgroundColor3 = C.plaque, BorderSizePixel = 0, ZIndex = 2}, canvas)
		corner(card, 8)
		local st = new("UIStroke", {ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = C.line, Thickness = 1.5}, card)
		local panel = new("Frame", {Name = "Art", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(270, ph),
			BackgroundColor3 = C.ink, BorderSizePixel = 0, ZIndex = 2}, card)
		corner(panel, 6)
		art(panel, mode, ph)
		local ny = phone and 143 or 175
		text(card, {text = d.name, size = 15, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromOffset(CARD_W / 2, ny),
			sz = UDim2.fromOffset(270, 22), name = "Name"})
		text(card, {text = d.line, size = 9, font = BODY, color = C.sub, anchor = Vector2.new(0.5, 0.5),
			pos = UDim2.fromOffset(CARD_W / 2, ny + (phone and 20 or 18)), sz = UDim2.fromOffset(270, 16), name = "Line"})
		local chipY = phone and 190 or 214
		local cx0 = (CARD_W - (3 * cw + 12)) / 2
		for n, label in ipairs(d.chips) do
			local chip = new("Frame", {Name = "Chip" .. n, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(cx0 + (n - 1) * (cw + 6), chipY),
				Size = UDim2.fromOffset(cw, chh), BackgroundColor3 = C.chip, BorderSizePixel = 0, ZIndex = 2}, card)
			corner(chip, 4)
			text(chip, {text = label, size = 7, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5), sz = UDim2.fromScale(1, 1), z = 3})
		end
		local pips = new("Frame", {Name = "Pips", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CARD_W / 2, phone and 259 or 321),
			Size = UDim2.fromOffset(8 * 17, 12), BackgroundTransparency = 1, ZIndex = 2}, card)
		local votesL = text(card, {text = "0 VOTES", size = 7, color = C.muted, anchor = Vector2.new(0.5, 0.5),
			pos = UDim2.fromOffset(CARD_W / 2, phone and 283 or 343), sz = UDim2.fromOffset(270, 14), name = "Votes"})
		local tag = text(card, {text = "YOUR VOTE", size = 7, color = C.dark, anchor = Vector2.new(0.5, 0),
			pos = UDim2.fromOffset(CARD_W / 2, phone and -11 or -8), sz = UDim2.fromOffset(110, phone and 22 or 16), z = 5, name = "Tag"})
		tag.BackgroundTransparency, tag.BackgroundColor3 = 0, C.yellow
		corner(tag, 3)
		card.Activated:Connect(function()
			if (state:GetAttribute("PgVoteWinner") or "") ~= "" then return end
			myVote = mode
			script:SetAttribute("VoteScreenLastPress", mode)
			if remote then remote:FireServer(mode) end
		end)
		ui.cards[i] = {mode = mode, card = card, stroke = st, pips = pips, votes = votesL, tag = tag, pipN = -1}
	end
end

local function layout(modes)
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local phone = vp.X / math.max(1, vp.Y) >= 1.9
	ui.H = phone and 463 or 562
	canvas.Size = UDim2.fromOffset(1000, ui.H)
	uiScale.Scale = math.min(vp.X / 1000, vp.Y / ui.H)
	local key = (phone and "p" or "c") .. table.concat(modes, ",")
	if key ~= ui.key then
		ui.key, ui.phone, ui.TF = key, phone, phone and 1.4 or 1
		build(modes)
	end
end

local function readModes()
	local t = {}
	for m in string.gmatch(tostring(state:GetAttribute("PgVoteModes") or ""), "[%a]+") do
		if MODES[m] then table.insert(t, m) end
	end
	if #t == 0 then t = {"hardpoint", "tdm"} end
	return t
end

local function setState(s) if script:GetAttribute("VoteScreenState") ~= s then script:SetAttribute("VoteScreenState", s) end end

RunService.RenderStepped:Connect(function()
	local on = script:GetAttribute("VoteScreenEnabled") ~= false and player:GetAttribute("PrInLobby") == true
		and state:GetAttribute("PgPhase") == "vote"
	gui.Enabled = on
	if not on then
		myVote = nil
		setState("hidden")
		return
	end
	local modes = readModes()
	layout(modes)
	local left = math.max(0, (tonumber(state:GetAttribute("PgEndsAt")) or now()) - now())
	local secs = tonumber(state:GetAttribute("PgVoteSecs")) or 15
	top.clock.Text = fmt(left)
	top.fill.Size = UDim2.fromScale(math.clamp(left / math.max(1, secs), 0, 1), 1)
	local n = tonumber(state:GetAttribute("PgVoteHumans")) or 1
	top.sub.Text = ("%s · PICK THE MODE · %d %s"):format(state:GetAttribute("PrArena") == true and "ARENA" or "PRACTICE", n,
		n == 1 and "PLAYER" or "PLAYERS")
	local ok, votes = pcall(function() return HttpService:JSONDecode(state:GetAttribute("PgVotes") or "{}") end)
	if not ok or type(votes) ~= "table" then votes = {} end
	local winner = state:GetAttribute("PgVoteWinner") or ""
	local mine = player:GetAttribute("PgVote")
	if myVote and myVote ~= mine and winner == "" then mine = myVote end -- shown at once, before the server answers
	local pipMax = math.clamp(n, 4, 8)
	for _, c in ipairs(ui.cards) do
		local v = tonumber(votes[c.mode]) or 0
		local isWin = winner == c.mode
		local sel = (winner ~= "" and isWin) or (winner == "" and mine == c.mode)
		c.stroke.Color = sel and C.yellow or C.line
		c.stroke.Thickness = sel and 2.5 or 1.5
		c.tag.Visible = winner == "" and mine == c.mode
		c.votes.Text = (isWin and "WINNER · " or "") .. v .. (v == 1 and " VOTE" or " VOTES")
		c.votes.TextColor3 = isWin and C.yellow or C.muted
		local pk = v .. "/" .. pipMax
		if c.pipN ~= pk then
			c.pipN = pk
			for _, p in ipairs(c.pips:GetChildren()) do p:Destroy() end
			local w = pipMax * 12 + (pipMax - 1) * 5
			for i = 1, pipMax do
				local p = new("Frame", {Name = "Pip" .. i, Position = UDim2.fromOffset((8 * 17 - w) / 2 + (i - 1) * 17, 0),
					Size = UDim2.fromOffset(12, 12), BackgroundColor3 = i <= v and C.volt or C.pipOff, BorderSizePixel = 0, ZIndex = 3}, c.pips)
				corner(p, 3)
			end
		end
	end
	setState(winner ~= "" and "winner" or "voting")
end)

pcall(function() RunService:UnbindFromRenderStep("VoteMouse") end)
RunService:BindToRenderStep("VoteMouse", Enum.RenderPriority.Camera.Value + 2, function()
	if not gui.Enabled then return end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end)
