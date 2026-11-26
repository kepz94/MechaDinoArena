-- QuestScreen v1.0 (Mecha Dino Arena) — the Quest Stand panel (LocalScript, StarterPlayerScripts). Plan docs/plans/QUEST_STAND_v1.0.md
-- Task 6, mockup docs/mockups/quest_stand_v0.1.html option "A · Board" (Kepu 2026-11-26 pick).
-- ScreenGui "Quests" (DisplayOrder 50, IgnoreGuiInset, hidden until opened). Opened by QuestStandClient 1.0 through the BindableFunction
--   "Open" under this script: Open:Invoke("stand") -> true when it opened (only while player QuestStandNear == true, out of the menu);
--   "Close" closes. Player attributes QuestOpen (bool) and QuestOpenFrom ("stand" / "").
-- Panel (design size QuestPanelW x QuestPanelH = 900 x 520 px, scaled by a UIScale to fit QuestFitW (0.92) x QuestFitH (0.92) of the
--   screen, never above 1.15): dark navy rgb(13,19,32), 3 px rgb(42,52,70) outline, corner 18.
--   * Header: "QUESTS" (Silkscreen Bold 34, white); cyan chip "NEW DAILIES IN <h>H <m>M" (counts down from the server's secsToDay);
--     right: "<n> READY · +<pts> PTS TODAY" (yellow) and a 56 px X.
--   * DAILY · 3 QUESTS: 3 cards (277 x 212) in a row: difficulty pips + EASY (green) / MEDIUM (yellow) / HARD (orange), the quest text,
--     a progress bar (cyan, yellow when done), "have / need", and on the right "+1 PT" / "+2 PTS" / "+3 PTS", a yellow CLAIM button
--     (130 x 64, a darker lip) when done, or "CLAIMED ✓" (green; the card dims).
--   * SPECIAL: 2 cards (423 x 138): the skin swatch (Zebra stripes / Storm Front blue with a light), "SPECIAL · SKIN" (violet), the
--     text, a bar, "BEST n / need", and the skin name / CLAIM / CLAIMED ✓.
-- Data: ReplicatedStorage.QuestRequest (QuestServer 1.0): InvokeServer("state") on open and every QuestRefresh (5) s while open;
--   CLAIM -> InvokeServer("claim", id) -> result, state. Toasts (2.2 s, bottom centre): "+<pts> SKILL POINT(S)", "<NAME> UNLOCKED",
--   and short words for the other results ("GET CLOSER TO THE STAND", "NOT DONE YET", "ALREADY CLAIMED", "TRY AGAIN").
-- Closes on X, on the menu (InMenu), on death, or when Close is invoked.
-- Switch: script attribute QuestScreenEnabled (true, read at start; false = Open returns false). Diagnostics: QuestScreenVersion,
--   QuestScreenShown (bool), QuestScreenLastResult.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 achievements tab
-- v1.1 (achievements, plan docs/plans/ACHIEVEMENTS_v1.0.md Task 3, mockup docs/mockups/achievements_v0.1.html "B · Three columns"):
--   the header title becomes two tabs, QUESTS (150 x 48) and ACHIEVEMENTS (250 x 48, a red count of ready achievements on its corner);
--   the active tab has the dark rgb(27,36,52) fill and white text, the other muted text. The quests page is unchanged except that
--   the "NEW DAILIES IN" chip moves to the right end of the DAILY line (300 x 26 at y 80). ACHIEVEMENTS page: a ScrollingFrame with
--   three columns ISLAND / ARENA / BOTH (headed "got / total"), rows 58 px with a 40 px medal disc (B / S / G in bronze / silver /
--   gold once done, grey "?" before), the name, a bar, "have / need", and on the right "+n PTS", a yellow "CLAIM +n" (84 x 44) or
--   "✓ +n" (the row dims). Header right: "<got> / 17 · +<pts> PTS". Claims go through the same QuestRequest("claim", "a_<id>")
--   (QuestServer 1.1). Switch: script attribute QuestAchTabEnabled (true, read at start; false = 1.0).
script:SetAttribute("QuestScreenVersion", VERSION)
for k, v in pairs({QuestScreenEnabled = true, QuestPanelW = 900, QuestPanelH = 520, QuestFitW = 0.92, QuestFitH = 0.92, QuestRefresh = 5}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function A(k, d) return tonumber(script:GetAttribute(k)) or d end
local player = Players.LocalPlayer
player:SetAttribute("QuestOpen", false)
player:SetAttribute("QuestOpenFrom", "")

local openFn = script:FindFirstChild("Open") or Instance.new("BindableFunction")
openFn.Name = "Open"
openFn.Parent = script
local closeFn = script:FindFirstChild("Close") or Instance.new("BindableFunction")
closeFn.Name = "Close"
closeFn.Parent = script

local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local C = {panel = Color3.fromRGB(13, 19, 32), line = Color3.fromRGB(42, 52, 70), card = Color3.fromRGB(21, 29, 43),
	cardLine = Color3.fromRGB(38, 48, 68), muted = Color3.fromRGB(138, 149, 168), white = Color3.new(1, 1, 1),
	yellow = Color3.fromRGB(255, 200, 50), lip = Color3.fromRGB(184, 138, 18), ink = Color3.fromRGB(27, 20, 6),
	cyan = Color3.fromRGB(127, 233, 255), chip = Color3.fromRGB(18, 35, 58), green = Color3.fromRGB(70, 224, 138),
	violet = Color3.fromRGB(184, 107, 255), track = Color3.fromRGB(42, 52, 70),
	diff = {Color3.fromRGB(70, 224, 138), Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 122, 60)}}
local DIFF = {"EASY", "MEDIUM", "HARD"}

local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("Quests")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "Quests"
gui.DisplayOrder = 50
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = pg

local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o return c end
local function stroke(o, col, t) local s = Instance.new("UIStroke") s.Color = col s.Thickness = t s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = o return s end
local function frame(parent, name, x, y, w, h, col)
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = col or C.card
	f.BackgroundTransparency = col and 0 or 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end
local function label(parent, name, x, y, w, h, text, size, col, font, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	if font == "silk" then l.FontFace = SILK else l.Font = Enum.Font.GothamBold end
	l:SetAttribute("FontSwap", "keep")
	l.TextSize = size
	l.TextColor3 = col
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

local scrim = Instance.new("TextButton")
scrim.Name = "Scrim"
scrim.Text = ""
scrim.AutoButtonColor = false
scrim.Size = UDim2.fromScale(1, 1)
scrim.BackgroundColor3 = Color3.fromRGB(5, 8, 13)
scrim.BackgroundTransparency = 0.25
scrim.Parent = gui
local PW, PH = A("QuestPanelW", 900), A("QuestPanelH", 520)
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(PW, PH)
panel.BackgroundColor3 = C.panel
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 18)
stroke(panel, C.line, 3)
local scale = Instance.new("UIScale")
scale.Parent = panel

-- header
label(panel, "Title", 24, 14, 200, 44, "QUESTS", 34, C.white, "silk")
local chip = frame(panel, "Timer", 210, 22, 300, 30, C.chip)
corner(chip, 8)
local timerL = label(chip, "Text", 0, 0, 300, 30, "", 15, C.cyan, "silk", Enum.TextXAlignment.Center)
local readyL = label(panel, "Ready", 470, 14, 340, 44, "", 16, C.yellow, "silk", Enum.TextXAlignment.Right)
local xBtn = Instance.new("TextButton")
xBtn.Name = "Close"
xBtn.Position = UDim2.fromOffset(PW - 76, 8)
xBtn.Size = UDim2.fromOffset(56, 56)
xBtn.BackgroundColor3 = Color3.fromRGB(27, 36, 52)
xBtn.FontFace = SILK
xBtn:SetAttribute("FontSwap", "keep")
xBtn.TextSize = 24
xBtn.TextColor3 = C.white
xBtn.Text = "X"
xBtn.Parent = panel
corner(xBtn, 12)
stroke(xBtn, C.line, 2)
frame(panel, "Divider", 0, 72, PW, 2, Color3.fromRGB(31, 40, 56))
label(panel, "DailyHead", 20, 82, 400, 22, "DAILY · 3 QUESTS", 15, C.muted, "silk")
local specHead = label(panel, "SpecialHead", 20, 336, 400, 22, "SPECIAL", 15, C.muted, "silk")

local function makeClaim(parent, x, y)
	local holder = frame(parent, "ClaimHolder", x, y, 130, 64)
	local lip = frame(holder, "Lip", 0, 5, 130, 64, C.lip)
	corner(lip, 12)
	local b = Instance.new("TextButton")
	b.Name = "Claim"
	b.Size = UDim2.fromOffset(130, 64)
	b.BackgroundColor3 = C.yellow
	b.FontFace = SILK
	b:SetAttribute("FontSwap", "keep")
	b.TextSize = 20
	b.TextColor3 = C.ink
	b.Text = "CLAIM"
	b.ZIndex = 2
	b.Parent = holder
	corner(b, 12)
	return holder, b
end
local function bar(parent, x, y, w)
	local t = frame(parent, "Track", x, y, w, 12, C.track)
	corner(t, 6)
	local f = frame(t, "Fill", 0, 0, 0, 12, C.cyan)
	corner(f, 6)
	return t, f
end

local cards = {}
for i = 1, 3 do
	local x = 20 + (i - 1) * (277 + 14)
	local cd = frame(panel, "Daily" .. i, x, 110, 277, 212, C.card)
	corner(cd, 14)
	local st = stroke(cd, C.cardLine, 2)
	local pips = {}
	for p = 1, 3 do pips[p] = frame(cd, "Pip" .. p, 14 + (p - 1) * 16, 18, 11, 11, C.track) corner(pips[p], 3) end
	local dl = label(cd, "Diff", 66, 12, 180, 22, "", 14, C.diff[1], "silk")
	local tl = label(cd, "Text", 14, 40, 249, 62, "", 21, C.white)
	tl.TextYAlignment = Enum.TextYAlignment.Top
	local tr, fill = bar(cd, 14, 112, 249)
	local pl = label(cd, "Prog", 14, 142, 110, 52, "", 16, C.muted, "silk")
	local rl = label(cd, "Reward", 123, 142, 140, 52, "", 18, C.yellow, "silk", Enum.TextXAlignment.Right)
	local holder, btn = makeClaim(cd, 133, 132)
	cards[i] = {f = cd, st = st, pips = pips, diff = dl, text = tl, fill = fill, track = tr, prog = pl, rew = rl, holder = holder, btn = btn}
end
local function swatch(parent, kind)
	local s = frame(parent, "Swatch", 14, 24, 90, 90, Color3.fromRGB(29, 29, 29))
	s.ClipsDescendants = true
	corner(s, 14)
	if kind == "zebra" then
		for k = -3, 6 do
			local st = frame(s, "Stripe", -20 + k * 22, -20, 11, 140, Color3.fromRGB(242, 242, 242))
			st.Rotation = 25
		end
	else
		s.BackgroundColor3 = Color3.new(1, 1, 1)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 92, 176)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(42, 49, 64)), ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 68, 88))})
		g.Rotation = 70
		g.Parent = s
		local dot = frame(s, "Light", 50, 18, 16, 16, Color3.fromRGB(159, 196, 255))
		corner(dot, 8)
	end
	return s
end
local specs = {}
for i = 1, 2 do
	local x = 20 + (i - 1) * (423 + 14)
	local cd = frame(panel, "Special" .. i, x, 362, 423, 138, C.card)
	corner(cd, 14)
	local st = stroke(cd, C.cardLine, 2)
	local sw = frame(cd, "SwatchSlot", 0, 0, 1, 1)
	label(cd, "Kind", 118, 12, 250, 20, "SPECIAL · SKIN", 13, C.violet, "silk")
	local tl = label(cd, "Text", 118, 32, 290, 30, "", 19, C.white)
	local tr, fill = bar(cd, 118, 72, 150)
	local pl = label(cd, "Prog", 118, 92, 150, 34, "", 15, C.muted, "silk")
	local rl = label(cd, "Reward", 250, 60, 160, 60, "", 16, C.yellow, "silk", Enum.TextXAlignment.Right)
	local holder, btn = makeClaim(cd, 279, 58)
	specs[i] = {f = cd, st = st, swSlot = sw, text = tl, fill = fill, track = tr, prog = pl, rew = rl, holder = holder, btn = btn, skin = nil}
end

-- v1.1: QUESTS / ACHIEVEMENTS tabs (see the v1.1 note)
local claimIdRef, drawRef -- set below, once claimId / draw exist
if script:GetAttribute("QuestAchTabEnabled") == nil then script:SetAttribute("QuestAchTabEnabled", true) end
local tabsOn = script:GetAttribute("QuestAchTabEnabled") ~= false
local tab = "quests"
local questPage = frame(panel, "QuestPage", 0, 0, PW, PH)
for _, ch in ipairs(panel:GetChildren()) do
	if ch.Name == "DailyHead" or ch.Name == "SpecialHead" or ch.Name:match("^Daily%d") or ch.Name:match("^Special%d") then ch.Parent = questPage end
end
local achPage = frame(panel, "AchPage", 0, 76, PW, PH - 76)
achPage.Visible = false
local MEDAL = {b = Color3.fromRGB(208, 138, 78), s = Color3.fromRGB(201, 211, 223), g = Color3.fromRGB(255, 210, 74)}
local MEDAL_L = {b = "B", s = "S", g = "G"}
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "List"
scroll.Position = UDim2.fromOffset(20, 8)
scroll.Size = UDim2.fromOffset(PW - 40, PH - 76 - 16)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.Parent = achPage
local COLW, ROWH, GAP = math.floor((PW - 40 - 2 * 14) / 3), 58, 8
local cols, achRows = {}, {}
for ci, where in ipairs({"ISLAND", "ARENA", "BOTH"}) do
	local x = (ci - 1) * (COLW + 14)
	local hd = label(scroll, "Head_" .. where, x, 0, COLW - 60, 22, where, 15, C.muted, "silk")
	local cnt = label(scroll, "Count_" .. where, x + COLW - 60, 0, 60, 22, "", 15, C.muted, "silk", Enum.TextXAlignment.Right)
	cols[where] = {x = x, head = hd, count = cnt, n = 0}
end
local function achRow(i)
	local r = achRows[i]
	if r then return r end
	local f = frame(scroll, "Ach" .. i, 0, 0, COLW, ROWH, C.card)
	corner(f, 10)
	local st = stroke(f, C.cardLine, 2)
	local md = frame(f, "Medal", 8, 9, 40, 40, C.track)
	corner(md, 20)
	local ml = label(md, "L", 0, 0, 40, 40, "?", 16, C.ink, "silk", Enum.TextXAlignment.Center)
	local nm = label(f, "Name", 56, 6, COLW - 56 - 90, 18, "", 14, C.white, "silk")
	nm.TextScaled = true
	local trk, fill = bar(f, 56, 28, COLW - 56 - 96)
	trk.Size = UDim2.fromOffset(COLW - 56 - 96, 8)
	fill.Size = UDim2.fromOffset(0, 8)
	local pr = label(f, "Prog", 56, 38, COLW - 56 - 96, 16, "", 12, C.muted, "silk")
	local rw = label(f, "Reward", COLW - 92, 0, 84, ROWH, "", 14, C.yellow, "silk", Enum.TextXAlignment.Right)
	local holder = frame(f, "ClaimHolder", COLW - 90, 7, 84, 44)
	local lip = frame(holder, "Lip", 0, 4, 84, 44, C.lip)
	corner(lip, 10)
	local b = Instance.new("TextButton")
	b.Name = "Claim"
	b.Size = UDim2.fromOffset(84, 44)
	b.BackgroundColor3 = C.yellow
	b.FontFace = SILK
	b:SetAttribute("FontSwap", "keep")
	b.TextSize = 13
	b.TextColor3 = C.ink
	b.ZIndex = 2
	b.Parent = holder
	corner(b, 10)
	r = {f = f, st = st, md = md, ml = ml, nm = nm, trk = trk, fill = fill, pr = pr, rw = rw, holder = holder, btn = b, id = nil, barW = COLW - 56 - 96}
	b.Activated:Connect(function() if r.id then claimIdRef(r.id) end end)
	achRows[i] = r
	return r
end
local tabQ = Instance.new("TextButton")
tabQ.Name = "TabQuests"
tabQ.Position = UDim2.fromOffset(16, 12)
tabQ.Size = UDim2.fromOffset(150, 48)
tabQ.FontFace = SILK
tabQ:SetAttribute("FontSwap", "keep")
tabQ.TextSize = 24
tabQ.Text = "QUESTS"
tabQ.Parent = panel
corner(tabQ, 10)
local tabA = tabQ:Clone()
tabA.Name = "TabAchievements"
tabA.Position = UDim2.fromOffset(172, 12)
tabA.Size = UDim2.fromOffset(250, 48)
tabA.Text = "ACHIEVEMENTS"
tabA.Parent = panel
local dot = Instance.new("TextLabel")
dot.Name = "Dot"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.new(1, -4, 0, 6)
dot.Size = UDim2.fromOffset(26, 26)
dot.BackgroundColor3 = Color3.fromRGB(255, 90, 110)
dot.FontFace = SILK
dot:SetAttribute("FontSwap", "keep")
dot.TextSize = 13
dot.TextColor3 = C.white
dot.Visible = false
dot.ZIndex = 3
dot.Parent = tabA
corner(dot, 13)
local titleL = panel:FindFirstChild("Title")
local function setTab(t)
	tab = t
	questPage.Visible = t == "quests"
	achPage.Visible = t == "ach"
	chip.Visible = t == "quests"
	for _, b in ipairs({tabQ, tabA}) do
		local on = (b == tabQ) == (t == "quests")
		b.BackgroundColor3 = Color3.fromRGB(27, 36, 52)
		b.BackgroundTransparency = on and 0 or 1
		b.TextColor3 = on and C.white or C.muted
	end
end
if tabsOn then
	if titleL then titleL.Visible = false end
	chip.Position = UDim2.fromOffset(PW - 320, 80)
	chip.Size = UDim2.fromOffset(300, 26)
	timerL.Size = UDim2.fromOffset(300, 26)
	tabQ.Activated:Connect(function() setTab("quests") drawRef() end)
	tabA.Activated:Connect(function() setTab("ach") drawRef() end)
	setTab("quests")
else
	tabQ.Visible, tabA.Visible = false, false
end
local function drawAch(v)
	if not tabsOn then return end
	local ready = tonumber(v.achReady) or 0
	dot.Visible = ready > 0
	dot.Text = tostring(ready)
	if tab ~= "ach" then return end
	readyL.Text = tostring(v.achGot or 0) .. " / " .. tostring(v.achievements and #v.achievements or 0) .. " · +" .. tostring(v.achPts or 0) .. " PTS"
	for _, c in pairs(cols) do c.n, c.got, c.total = 0, 0, 0 end
	local maxRows = 0
	for i, a in ipairs(v.achievements or {}) do
		local c = cols[a.where] or cols.BOTH
		local r = achRow(i)
		r.f.Position = UDim2.fromOffset(c.x, 30 + c.n * (ROWH + GAP))
		c.n += 1
		c.total += 1
		if a.claimed then c.got += 1 end
		maxRows = math.max(maxRows, c.n)
		local done = a.have >= a.need
		local canClaim = done and not a.claimed
		r.id = a.id
		r.md.BackgroundColor3 = (done or a.claimed) and (MEDAL[a.medal] or C.track) or C.track
		r.ml.Text = (done or a.claimed) and (MEDAL_L[a.medal] or "?") or "?"
		r.ml.TextColor3 = (done or a.claimed) and C.ink or C.muted
		r.nm.Text = a.name
		r.fill.Size = UDim2.fromOffset(math.floor(r.barW * math.clamp(a.have / math.max(1, a.need), 0, 1) + 0.5), 8)
		r.fill.BackgroundColor3 = done and C.yellow or C.cyan
		r.pr.Text = a.have .. " / " .. a.need
		r.holder.Visible = canClaim
		r.btn.Text = "CLAIM +" .. a.pts
		r.rw.Visible = not canClaim
		r.rw.Text = a.claimed and ("✓ +" .. a.pts) or ("+" .. a.pts .. " PTS")
		r.rw.TextColor3 = a.claimed and C.green or C.yellow
		r.st.Color = canClaim and C.yellow or C.cardLine
		r.f.BackgroundTransparency = a.claimed and 0.45 or 0
		r.f.Visible = true
	end
	for _, c in pairs(cols) do c.count.Text = c.got .. " / " .. c.total end
	scroll.CanvasSize = UDim2.fromOffset(0, 30 + maxRows * (ROWH + GAP))
end
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -24)
toast.Size = UDim2.fromOffset(340, 48)
toast.BackgroundColor3 = Color3.fromRGB(11, 15, 22)
toast.FontFace = SILK
toast:SetAttribute("FontSwap", "keep")
toast.TextSize = 20
toast.TextColor3 = C.white
toast.Visible = false
toast.ZIndex = 5
toast.Parent = gui
corner(toast, 12)
stroke(toast, C.yellow, 3)
local toastId = 0
local function showToast(t)
	toastId += 1
	local my = toastId
	toast.Text = t
	toast.Size = UDim2.fromOffset(math.max(260, #t * 15 + 40), 48)
	toast.Visible = true
	task.delay(2.2, function() if toastId == my then toast.Visible = false end end)
end

-- state
local remote = ReplicatedStorage:WaitForChild("QuestRequest", 30)
local view, viewAt, isOpen, busy = nil, 0, false, false
local function setOpen(on, from)
	isOpen = on
	gui.Enabled = on
	player:SetAttribute("QuestOpenFrom", on and (from or "stand") or "")
	player:SetAttribute("QuestOpen", on)
	script:SetAttribute("QuestScreenShown", on)
end

local function fit()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.min(1.15, vs.X * A("QuestFitW", 0.92) / PW, vs.Y * A("QuestFitH", 0.92) / PH)
end

local function draw()
	local v = view
	if not (v and v.ok) then
		readyL.Text = "LOADING"
		return
	end
	local ready = tonumber(v.ready) or 0
	readyL.Text = (ready > 0 and (ready .. " READY · ") or "") .. "+" .. tostring(v.ptsToday or 0) .. " PTS TODAY"
	for i = 1, 3 do
		local q, cd = v.dailies and v.dailies[i], cards[i]
		cd.f.Visible = q ~= nil
		if q then
			local done = q.have >= q.need
			for p = 1, 3 do cd.pips[p].BackgroundColor3 = p <= q.diff and C.diff[q.diff] or C.track end
			cd.diff.Text = DIFF[q.diff] or ""
			cd.diff.TextColor3 = C.diff[q.diff] or C.muted
			cd.text.Text = q.text
			cd.fill.Size = UDim2.fromOffset(math.floor(249 * math.clamp(q.have / math.max(1, q.need), 0, 1) + 0.5), 12)
			cd.fill.BackgroundColor3 = done and C.yellow or C.cyan
			cd.prog.Text = q.have .. " / " .. q.need
			local canClaim = done and not q.claimed
			cd.holder.Visible = canClaim
			cd.rew.Visible = not canClaim
			cd.rew.Text = q.claimed and "CLAIMED ✓" or ("+" .. q.pts .. (q.pts == 1 and " PT" or " PTS"))
			cd.rew.TextColor3 = q.claimed and C.green or C.yellow
			cd.st.Color = canClaim and C.yellow or C.cardLine
			cd.f.BackgroundTransparency = q.claimed and 0.45 or 0
			cd.id = q.id
		end
	end
	for i = 1, 2 do
		local s, cd = v.specials and v.specials[i], specs[i]
		cd.f.Visible = s ~= nil
		if s then
			if cd.skin ~= s.skin then
				for _, ch in ipairs(cd.f:GetChildren()) do if ch.Name == "Swatch" then ch:Destroy() end end
				swatch(cd.f, s.skin)
				cd.skin = s.skin
			end
			local done = s.have >= s.need
			cd.text.Text = s.text
			cd.fill.Size = UDim2.fromOffset(math.floor(150 * math.clamp(s.have / math.max(1, s.need), 0, 1) + 0.5), 12)
			cd.fill.BackgroundColor3 = done and C.yellow or C.cyan
			cd.prog.Text = "BEST " .. s.have .. " / " .. s.need
			local canClaim = done and not s.claimed
			cd.holder.Visible = canClaim
			cd.rew.Visible = not canClaim
			cd.rew.Text = s.claimed and "CLAIMED ✓" or s.name
			cd.rew.TextColor3 = s.claimed and C.green or C.yellow
			cd.st.Color = canClaim and C.yellow or C.cardLine
			cd.f.BackgroundTransparency = s.claimed and 0.45 or 0
			cd.id = s.id
		end
	end
	drawAch(v) -- v1.1
end

local function refresh()
	if not remote then return end
	local ok, v = pcall(function() return remote:InvokeServer("state") end)
	if ok and type(v) == "table" then view, viewAt = v, os.clock() end
	draw()
end

local WORDS = {notNear = "GET CLOSER TO THE STAND", notReady = "NOT DONE YET", claimed = "ALREADY CLAIMED", busy = "ONE MOMENT",
	failed = "TRY AGAIN", notHub = "ONLY ON THE ISLAND", notLoaded = "LOADING", unknown = "TRY AGAIN"}
local function claimId(id)
	if busy or not (remote and id) then return end
	busy = true
	local ok, r, v = pcall(function() return remote:InvokeServer("claim", id) end)
	busy = false
	if not ok then r = "failed" end
	script:SetAttribute("QuestScreenLastResult", tostring(r))
	if type(v) == "table" then view, viewAt = v, os.clock() end
	if r == "ok" then
		local msg = "CLAIMED"
		for _, q in ipairs(view and view.dailies or {}) do
			if q.id == id then msg = "+" .. q.pts .. (q.pts == 1 and " SKILL POINT" or " SKILL POINTS") end
		end
		for _, s in ipairs(view and view.specials or {}) do if s.id == id then msg = s.name .. " UNLOCKED" end end
		for _, a in ipairs(view and view.achievements or {}) do -- v1.1
			if a.id == id then msg = "+" .. a.pts .. " SKILL POINTS" end
		end
		showToast(msg)
	else
		showToast(WORDS[r] or "TRY AGAIN")
	end
	draw()
end
for i = 1, 3 do cards[i].btn.Activated:Connect(function() claimId(cards[i].id) end) end
for i = 1, 2 do specs[i].btn.Activated:Connect(function() claimId(specs[i].id) end) end
claimIdRef, drawRef = claimId, draw -- v1.1

xBtn.Activated:Connect(function() setOpen(false) end)
openFn.OnInvoke = function(from)
	if script:GetAttribute("QuestScreenEnabled") == false then return false end
	if player:GetAttribute("InMenu") == true or player:GetAttribute("QuestStandNear") ~= true then return false end
	fit()
	setOpen(true, from)
	view = nil
	draw()
	task.spawn(refresh)
	return true
end
closeFn.OnInvoke = function() setOpen(false) return true end

RunService.RenderStepped:Connect(function()
	if not isOpen then return end
	fit()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if player:GetAttribute("InMenu") == true or not (hum and hum.Health > 0) then setOpen(false) return end
	if view and view.ok then
		local left = math.max(0, (tonumber(view.secsToDay) or 0) - (os.clock() - viewAt))
		local t = ("NEW DAILIES IN %dH %dM"):format(math.floor(left / 3600), math.floor(left % 3600 / 60))
		if timerL.Text ~= t then timerL.Text = t end
	end
	if not busy and os.clock() - viewAt > A("QuestRefresh", 5) then
		viewAt = os.clock()
		task.spawn(refresh)
	end
end)
