-- PracticeLobby v1.0 (Mecha Dino Arena) — the practice match team screen, PC and phone (LocalScript, StarterPlayerScripts).
-- MDA-412, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 8, mockup docs/mockups/practice_match_v0.1.html (v0.2, direction
-- "A · Practice lobby"; Kepu 2026-11-10 "A · Practice lobby (Recommended)", "Build").
-- Reads ReplicatedStorage.Practice (PracticeServer 1.1): PrPhase, PrStartAt, PrDifficulty, PrSize, PrRoster (JSON {A, B}),
--   PrResult; ReplicatedStorage.Hardpoint HpBoard / HpScoreA / HpScoreB (HardpointServer 1.1); player PrInLobby, PrInMatch,
--   PrSide, PrLastResult, PrLastAt, InMenu.
-- ScreenGui "PracticeLobby" (DisplayOrder 41, over the main menu's 40; IgnoreGuiInset; ResetOnSpawn false), shown while
--   PrInLobby == true. Full-screen backdrop rgb(10,12,18) at 0.08; content centred, at most 1000 px wide, side padding 4%.
--   * Title "PRACTICE MATCH" and the line "HARDPOINT · SUMMIT · STARTS IN m:ss" (PrStartAt; 0 -> "WAITING").
--   * Last match (PrResult "A" / "B" / "draw" not ""): "LAST MATCH · VICTORY / DEFEAT / DRAW  a – b" (you first, by PrSide)
--     and one line per team "BLUE  Name k/d · …" / "RED  …" from HpBoard (most kills first, you in yellow with ★). Until the
--     next match starts (the screen closes then).
--   * BLUE (side A) and RED (side B) columns of PrSize slots: a dino box (short species name), the name (+ BOT tag), the
--     line under it (a bot: its BOT_LIVE parts joined, none -> "Basic attack"; a player: "Player"). Your slot has a yellow
--     edge. Columns stay side by side on every screen.
--   * Button bar (wraps when narrow): JOIN BLUE / JOIN RED / AUTO · BOTS EASY / NORMAL / HARD (PrDifficulty outlined) ·
--     NEW BOTS · START · MAIN MENU -> PracticeRequest ("join" "A" / "B" / "auto"; "difficulty" name; "newbots"; "start";
--     "leave").
--   * Toast over the bar for 2.5 s when PrLastResult changes to something other than "ok": full -> "That team is full",
--     busy -> "Too fast, try again", notInLobby -> "Not in the lobby", nobody -> "Nobody to play", already -> "Already in",
--     anything else -> the raw text.
--   Sizes from the screen height (u = clamp(height / 720, 0.5, 1.4)): slot text 12 px at least, buttons 44 px tall at least;
--   the slot height takes what is left (down to 360 px tall screens).
-- Mode presses (always, whatever the switch): PrInMatch becomes true while InMenu == true -> DinoModeRequest("play");
--   PrInLobby becomes true while InMenu == false (a match just ended) -> DinoModeRequest("menu").
-- Switch: script attribute PracticeLobbyEnabled (default true, read per frame; false = the screen is not drawn).
-- Diagnostics: PracticeLobbyVersion, PracticeLobbyState ("hidden" / "shown"), PracticeLobbyLastPress (button id),
--   PracticeLobbyModeFired ("play" / "menu"), PracticeLobbyToast (last toast text).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.0"
local PANEL = Color3.fromRGB(20, 20, 26)
local YELLOW = Color3.fromRGB(255, 200, 50)
local MUTED = Color3.fromRGB(143, 153, 170)
local WHITE = Color3.new(1, 1, 1)
local DARK_TEXT = Color3.fromRGB(27, 20, 6)
local BLUE_BTN, RED_BTN, DARK_BTN = Color3.fromRGB(47, 111, 208), Color3.fromRGB(184, 29, 60), Color3.fromRGB(43, 53, 66)
local BLUE_HD, RED_HD = Color3.fromRGB(90, 160, 255), Color3.fromRGB(224, 40, 74)
local BLUE_T, RED_T = Color3.fromRGB(188, 216, 255), Color3.fromRGB(255, 194, 204)
local FONT = Enum.Font.FredokaOne
local SHORT = {TRex = "T-REX", Raptor = "RAPTOR", Pachy = "PACHY", Herrera = "HERRERA", Teno = "TENO", Therizino = "THERI",
	Dilo = "DILO", Troodon = "TROODON"}
local TOAST = {full = "That team is full", busy = "Too fast, try again", notInLobby = "Not in the lobby", nobody = "Nobody to play",
	already = "Already in"}
local MAX_SLOTS = 5

script:SetAttribute("PracticeLobbyVersion", VERSION)
if script:GetAttribute("PracticeLobbyEnabled") == nil then script:SetAttribute("PracticeLobbyEnabled", true) end

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("Practice", 60)
if not state then return end -- no practice match in this server
local request = ReplicatedStorage:WaitForChild("PracticeRequest", 30)
local modeRemote = ReplicatedStorage:WaitForChild("DinoModeRequest", 30)
local hp = ReplicatedStorage:FindFirstChild("Hardpoint")

-- ---------- mode presses ----------
local function fireMode(a)
	if modeRemote then modeRemote:FireServer(a) end
	script:SetAttribute("PracticeLobbyModeFired", a)
end
player:GetAttributeChangedSignal("PrInMatch"):Connect(function()
	if player:GetAttribute("PrInMatch") == true and player:GetAttribute("InMenu") == true then fireMode("play") end
end)
player:GetAttributeChangedSignal("PrInLobby"):Connect(function()
	if player:GetAttribute("PrInLobby") == true and player:GetAttribute("InMenu") == false then fireMode("menu") end
end)

-- ---------- helpers ----------
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 8) c.Parent = p return c end
local function stroke(p, color, tr, th)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color, s.Transparency, s.Thickness = color, tr, th
	s.Parent = p
	return s
end
local function label(parent, name, color, xAlign)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = color or WHITE
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Center
	l.Text = ""
	l.Parent = parent
	return l
end
local function fmt(s)
	s = math.max(0, math.ceil(s - 1e-6))
	return ("%d:%02d"):format(s // 60, s % 60)
end
local function now() return workspace:GetServerTimeNow() end

-- ---------- the gui ----------
local gui = Instance.new("ScreenGui")
gui.Name = "PracticeLobby"
gui.DisplayOrder = 41
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local back = Instance.new("TextButton") -- takes every click / touch so nothing under it reacts
back.Name = "Backdrop"
back.AutoButtonColor = false
back.Text = ""
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
back.BackgroundTransparency = 0.08
back.BorderSizePixel = 0
back.Parent = gui

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.AnchorPoint = Vector2.new(0.5, 0)
content.Parent = gui

local title = label(content, "Title")
title.Text = "PRACTICE MATCH"
local sub = label(content, "Sub", MUTED)

local last = Instance.new("Frame")
last.Name = "LastMatch"
last.BackgroundColor3 = PANEL
last.BackgroundTransparency = 0.1
last.Parent = content
corner(last, 8)
stroke(last, WHITE, 0.82, 1)
local lastHead = label(last, "Head", WHITE, Enum.TextXAlignment.Left)
lastHead.RichText = true
local lastA = label(last, "Blue", WHITE, Enum.TextXAlignment.Left)
lastA.RichText = true
lastA.TextTruncate = Enum.TextTruncate.AtEnd
local lastB = label(last, "Red", WHITE, Enum.TextXAlignment.Left)
lastB.RichText = true
lastB.TextTruncate = Enum.TextTruncate.AtEnd

local function column(name, hdColor, hdText, text)
	local hd = Instance.new("TextLabel")
	hd.Name = name .. "Head"
	hd.BackgroundColor3 = hdColor
	hd.BackgroundTransparency = 0.75
	hd.Font = FONT
	hd.TextColor3 = hdText
	hd.Text = text
	hd.Parent = content
	corner(hd, 6)
	local slots = {}
	for i = 1, MAX_SLOTS do
		local f = Instance.new("Frame")
		f.Name = name .. "Slot" .. i
		f.BackgroundColor3 = PANEL
		f.BackgroundTransparency = 0.1
		f.Parent = content
		local fc = corner(f, 7)
		local fs = stroke(f, WHITE, 0.82, 1.5)
		local box = Instance.new("TextLabel")
		box.Name = "Dino"
		box.BackgroundColor3 = Color3.fromRGB(43, 53, 66)
		box.Font = FONT
		box.TextColor3 = WHITE
		box.TextScaled = true
		box.Parent = f
		local bc = corner(box, 6)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 3), UDim.new(0, 3)
		pad.Parent = box
		local nm = label(f, "Name", WHITE, Enum.TextXAlignment.Left)
		nm.RichText = true
		nm.TextTruncate = Enum.TextTruncate.AtEnd
		local ld = label(f, "Loadout", Color3.fromRGB(170, 180, 194), Enum.TextXAlignment.Left)
		ld.TextTruncate = Enum.TextTruncate.AtEnd
		slots[i] = {f = f, fc = fc, fs = fs, box = box, bc = bc, nm = nm, ld = ld}
	end
	return hd, slots
end
local hdA, slotsA = column("Blue", BLUE_HD, BLUE_T, "BLUE")
local hdB, slotsB = column("Red", RED_HD, RED_T, "RED")
local vs = label(content, "VS", MUTED)
vs.Text = "VS"

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.BackgroundTransparency = 1
bar.Parent = content
local barList = Instance.new("UIListLayout")
barList.FillDirection = Enum.FillDirection.Horizontal
barList.HorizontalAlignment = Enum.HorizontalAlignment.Center
barList.VerticalAlignment = Enum.VerticalAlignment.Center
barList.SortOrder = Enum.SortOrder.LayoutOrder
barList.Wraps = true
barList.Parent = bar

local buttons = {} -- id -> {b, s (stroke)}
local function button(id, text, color, textColor, order)
	local b = Instance.new("TextButton")
	b.Name = id
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextColor3 = textColor or WHITE
	b.Text = text
	b.AutomaticSize = Enum.AutomaticSize.X
	b.LayoutOrder = order
	b.Parent = bar
	corner(b, 8)
	local s = stroke(b, Color3.fromRGB(26, 19, 0), 0, 2)
	local p = Instance.new("UIPadding")
	p.Parent = b
	buttons[id] = {b = b, s = s, p = p}
	return b
end
local botsLbl = label(bar, "BotsLabel", MUTED)
botsLbl.Text = "BOTS"
botsLbl.AutomaticSize = Enum.AutomaticSize.X
botsLbl.LayoutOrder = 4

local toast = label(content, "Toast", WHITE)
toast.BackgroundColor3 = PANEL
toast.BackgroundTransparency = 0.1
toast.AutomaticSize = Enum.AutomaticSize.X
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Visible = false
corner(toast, 8)
stroke(toast, YELLOW, 0.2, 1.5)
do local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 12) p.PaddingRight = UDim.new(0, 12) p.Parent = toast end
local toastUntil = 0

local function press(id, action, arg)
	script:SetAttribute("PracticeLobbyLastPress", id)
	if request then request:FireServer(action, arg) end
end
button("joinBlue", "JOIN BLUE", BLUE_BTN, WHITE, 1).Activated:Connect(function() press("joinBlue", "join", "A") end)
button("joinRed", "JOIN RED", RED_BTN, WHITE, 2).Activated:Connect(function() press("joinRed", "join", "B") end)
button("auto", "AUTO", DARK_BTN, WHITE, 3).Activated:Connect(function() press("auto", "join", "auto") end)
for i, d in ipairs({"Easy", "Normal", "Hard"}) do
	button("diff" .. d, string.upper(d), DARK_BTN, WHITE, 4 + i).Activated:Connect(function() press("diff" .. d, "difficulty", d) end)
end
button("newBots", "NEW BOTS", DARK_BTN, WHITE, 8).Activated:Connect(function() press("newBots", "newbots") end)
button("start", "START", YELLOW, DARK_TEXT, 9).Activated:Connect(function() press("start", "start") end)
button("leave", "MAIN MENU", DARK_BTN, WHITE, 10).Activated:Connect(function() press("leave", "leave") end)

-- ---------- data ----------
local roster = {A = {}, B = {}}
local function readRoster()
	local ok, r = pcall(function() return HttpService:JSONDecode(state:GetAttribute("PrRoster") or "{}") end)
	roster = (ok and type(r) == "table") and r or {}
	roster.A, roster.B = roster.A or {}, roster.B or {}
end

local function drawSlot(s, d, mine)
	if not d then
		s.f.Visible = false
		return
	end
	s.f.Visible = true
	local you = d.kind == "human" and d.userId == player.UserId
	s.fs.Color, s.fs.Transparency = you and YELLOW or WHITE, you and 0 or 0.82
	s.box.Text = SHORT[d.species] or string.upper(tostring(d.species or "?"))
	local name = tostring(d.name or "?")
	if you then name = "★ " .. name end
	if d.kind == "bot" then name = name .. '  <font color="#8f99aa" size="' .. math.floor(s.nm.TextSize * 0.7) .. '">BOT</font>' end
	s.nm.Text = name
	s.nm.TextColor3 = you and YELLOW or WHITE
	if d.kind == "bot" then
		local parts = type(d.parts) == "table" and d.parts or {}
		s.ld.Text = #parts > 0 and table.concat(parts, ", ") or "Basic attack"
	else
		s.ld.Text = "Player"
	end
end

local function boardLines()
	if not hp then hp = ReplicatedStorage:FindFirstChild("Hardpoint") end
	local res = state:GetAttribute("PrResult")
	if type(res) ~= "string" or res == "" or not hp then return nil end
	local ok, list = pcall(function() return HttpService:JSONDecode(hp:GetAttribute("HpBoard") or "[]") end)
	if not ok or type(list) ~= "table" then list = {} end
	local mine = player:GetAttribute("PrSide")
	local sa, sb = hp:GetAttribute("HpScoreA") or 0, hp:GetAttribute("HpScoreB") or 0
	local you, foe = sa, sb
	if mine == "B" then you, foe = sb, sa end
	local word = res == "draw" and "DRAW" or (res == mine and "VICTORY" or "DEFEAT")
	local col = word == "VICTORY" and "#5aa0ff" or (word == "DEFEAT" and "#e0284a" or "#ffc832")
	local head = ('LAST MATCH · <font color="%s">%s</font>  %d – %d'):format(col, word, you, foe)
	local rows = {A = {}, B = {}}
	for _, r in ipairs(list) do
		if r.team == "A" or r.team == "B" then table.insert(rows[r.team], r) end
	end
	local function line(side, tag, color)
		table.sort(rows[side], function(x, y) if x.k ~= y.k then return x.k > y.k end return tostring(x.name) < tostring(y.name) end)
		local bits = {}
		for _, r in ipairs(rows[side]) do
			local isMe = r.id == "u" .. player.UserId
			local t = ("%s %d/%d"):format(tostring(r.name), r.k or 0, r.d or 0)
			if isMe then t = '<font color="#ffc832">★ ' .. t .. "</font>" end
			table.insert(bits, t)
		end
		return ('<font color="%s">%s</font>  %s'):format(color, tag, #bits > 0 and table.concat(bits, " · ") or "—")
	end
	return head, line("A", "BLUE", "#bcd8ff"), line("B", "RED", "#ffc2cc")
end

-- ---------- layout ----------
local function layout()
	local vp = gui.AbsoluteSize
	local W, Hh = vp.X, vp.Y
	if W < 10 or Hh < 10 then return end
	local u = math.clamp(Hh / 720, 0.5, 1.4)
	local inset = game:GetService("GuiService"):GetGuiInset()
	local padX = math.max(16, W * 0.04)
	local cw = math.min(W - 2 * padX, 1000)
	local top = math.max(inset.Y, 8) + 6 * u
	local bottomPad = math.max(8, 14 * u)
	content.Position, content.Size = UDim2.new(0.5, 0, 0, 0), UDim2.fromOffset(cw, Hh)

	local titleS, subS = math.max(20, 34 * u), math.max(12, 15 * u)
	title.TextSize, sub.TextSize = titleS, subS
	title.Position, title.Size = UDim2.fromOffset(0, top), UDim2.fromOffset(cw, titleS)
	sub.Position, sub.Size = UDim2.fromOffset(0, top + titleS + 2), UDim2.fromOffset(cw, subS)
	local y = top + titleS + 2 + subS + 8 * u

	-- the bar: measure its rows (buttons 44 px at least)
	local btnH = math.max(44, 48 * u)
	local btnS = math.max(13, 16 * u)
	barList.Padding = UDim.new(0, math.max(6, 8 * u))
	for _, bt in pairs(buttons) do
		bt.b.Size = UDim2.fromOffset(0, btnH)
		bt.b.TextSize = btnS
		bt.p.PaddingLeft, bt.p.PaddingRight = UDim.new(0, math.max(10, 14 * u)), UDim.new(0, math.max(10, 14 * u))
	end
	botsLbl.Size, botsLbl.TextSize = UDim2.fromOffset(0, btnH), math.max(12, 14 * u)
	bar.Size = UDim2.fromOffset(cw, btnH)
	local barH = math.max(btnH, barList.AbsoluteContentSize.Y)
	bar.Size = UDim2.fromOffset(cw, barH)
	bar.Position = UDim2.fromOffset(0, Hh - bottomPad - barH)
	toast.TextSize = math.max(13, 16 * u)
	toast.Size = UDim2.fromOffset(0, math.max(28, 32 * u))
	toast.Position = UDim2.new(0.5, 0, 0, Hh - bottomPad - barH - 6 * u)

	-- the last match
	local head, la, lb = boardLines()
	last.Visible = head ~= nil
	if head then
		local ls = math.max(12, 14 * u)
		local lh = ls + 4
		lastHead.Text, lastA.Text, lastB.Text = head, la, lb
		for i, l in ipairs({lastHead, lastA, lastB}) do
			l.TextSize = i == 1 and ls + 2 or ls
			l.Position, l.Size = UDim2.fromOffset(10, 6 + (i - 1) * lh + (i > 1 and 2 or 0)), UDim2.fromOffset(cw - 20, lh)
		end
		local h = 6 + 3 * lh + 2 + 6
		last.Position, last.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(cw, h)
		y += h + 8 * u
	end

	-- the columns
	local vsW = math.max(30, 44 * u)
	local colW = (cw - vsW) / 2
	local hdH = math.max(20, 28 * u)
	for i, hd in ipairs({hdA, hdB}) do
		hd.TextSize = math.max(13, 18 * u)
		hd.Position, hd.Size = UDim2.fromOffset(i == 1 and 0 or colW + vsW, y), UDim2.fromOffset(colW, hdH)
	end
	y += hdH + 6 * u
	local size = math.clamp(tonumber(state:GetAttribute("PrSize")) or 5, 1, MAX_SLOTS)
	local gap = math.max(4, 6 * u)
	local avail = (Hh - bottomPad - barH - 10 * u) - y
	local slotH = math.clamp((avail - (size - 1) * gap) / size, 30, 64 * u + 8)
	vs.TextSize = math.max(14, 22 * u)
	vs.Position, vs.Size = UDim2.fromOffset(colW, y), UDim2.fromOffset(vsW, size * slotH + (size - 1) * gap)
	local nameS = math.max(12, math.min(18 * u, slotH * 0.42))
	local ldS = math.max(12, math.min(13 * u, slotH * 0.32))
	for side, list in pairs({A = slotsA, B = slotsB}) do
		local x = side == "A" and 0 or colW + vsW
		for i, s in ipairs(list) do
			local sy = y + (i - 1) * (slotH + gap)
			s.f.Position, s.f.Size = UDim2.fromOffset(x, sy), UDim2.fromOffset(colW, slotH)
			local box = slotH - 10
			s.box.Position, s.box.Size = UDim2.fromOffset(6, 5), UDim2.fromOffset(math.max(box * 1.5, 46), box)
			local tx = 6 + math.max(box * 1.5, 46) + 8
			local tw = colW - tx - 8
			local both = nameS + ldS + 2
			local ty = (slotH - both) / 2
			s.nm.TextSize, s.ld.TextSize = nameS, ldS
			s.nm.Position, s.nm.Size = UDim2.fromOffset(tx, ty), UDim2.fromOffset(tw, nameS)
			s.ld.Position, s.ld.Size = UDim2.fromOffset(tx, ty + nameS + 2), UDim2.fromOffset(tw, ldS)
		end
	end
	for side, list in pairs({A = slotsA, B = slotsB}) do
		for i, s in ipairs(list) do drawSlot(s, i <= size and roster[side][i] or nil) end
	end
end

-- ---------- updates ----------
readRoster()
state:GetAttributeChangedSignal("PrRoster"):Connect(function() readRoster() if gui.Enabled then layout() end end)
for _, k in ipairs({"PrSize", "PrResult"}) do
	state:GetAttributeChangedSignal(k):Connect(function() if gui.Enabled then layout() end end)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if gui.Enabled then layout() end end)
local lastBarH = 0
barList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	local h = barList.AbsoluteContentSize.Y
	if gui.Enabled and math.abs(h - lastBarH) > 1 then lastBarH = h layout() end
end)

player:GetAttributeChangedSignal("PrLastAt"):Connect(function()
	local r = player:GetAttribute("PrLastResult")
	if r == nil or r == "ok" then return end
	toast.Text = TOAST[r] or tostring(r)
	toastUntil = os.clock() + 2.5
	script:SetAttribute("PracticeLobbyToast", toast.Text)
end)

local wasShown = false
RunService.RenderStepped:Connect(function()
	local show = script:GetAttribute("PracticeLobbyEnabled") ~= false and player:GetAttribute("PrInLobby") == true
	gui.Enabled = show
	if show ~= wasShown then
		wasShown = show
		script:SetAttribute("PracticeLobbyState", show and "shown" or "hidden")
		if show then layout() end
	end
	if not show then return end
	local at = tonumber(state:GetAttribute("PrStartAt")) or 0
	sub.Text = "HARDPOINT · SUMMIT · " .. (at > 0 and ("STARTS IN " .. fmt(at - now())) or "WAITING")
	local diff = state:GetAttribute("PrDifficulty")
	for _, d in ipairs({"Easy", "Normal", "Hard"}) do
		local bt = buttons["diff" .. d]
		local on = diff == d
		bt.s.Color, bt.s.Thickness = on and WHITE or Color3.fromRGB(26, 19, 0), on and 3 or 2
	end
	toast.Visible = os.clock() < toastUntil
end)
