-- LeaderboardBoards v1.0 (Mecha Dino Arena) — draws the LOBBY and WORLDWIDE leaderboard screens by the ARENA gate and makes
-- them scroll (LocalScript, StarterPlayerScripts). Kepu 2026-11-24 15:44 / 16:02 (style "B Mecha monitor", mockup
-- docs/mockups/leaderboard_looks_v0.4.html), 16:08 "Let's do a scroll the screen". Boards: LeaderboardServer 1.0
-- (Workspace.IsletBoards, parts "Screen" with attribute LbBoard "lobby" / "world"). Badges: RankBadge 1.0.
-- On while: script attribute LbBoardsClientEnabled ~= false and ReplicatedStorage ServerKind == "hub". One SurfaceGui per screen
--   in PlayerGui (so it takes touch / mouse input), Adornee = the screen part, Face Front, PixelsPerStud 30 (810 x 930 px),
--   LightInfluence 0, Brightness 1.4. Off: the SurfaceGuis are removed.
-- Screen, top to bottom: kicker ("THIS SERVER" blue / "ALL TIME" gold), title ("LOBBY" / "WORLDWIDE"), a ScrollingFrame of
--   rows (LbRowH (62) px each), then on WORLDWIDE a pinned YOU row, then a footer line.
--   * WORLDWIDE rows (ReplicatedStorage LbWorldTop, LeaderboardServer): place number, name (1 gold, 2 silver, 3 bronze, others
--     white), "<wins>W" green. Your own row: blue band.
--     YOU row (your screen only): in the list -> "#<place> YOU <wins>W"; not in it -> "NOT RANKED" and "<ArenaW>W" ("-" while
--     your record is not loaded).
--   * LOBBY rows: every player on this server; record loaded (ArenaRecordReady) first, by ArenaW high to low, then by name;
--     not loaded after them with "-". Row: place, rank badge (RankBadge) when ranked, name, "<W>W" green, "<W>-<L>" grey.
--     Your own row: blue band.
--   * Footers: LOBBY "ARENA WINS · PLAYERS HERE NOW", WORLDWIDE "TOP 100 EARN A RANK BADGE".
-- Scrolling: touch drag / mouse wheel on the screen, only while your HumanoidRootPart is within LbScrollRange (40) studs of the
--   screen part, measured flat (X / Z only; the screen is high up) (checked every 0.25 s; farther = ScrollingEnabled false, the list stays where it was). Lists refresh every
--   1 s when what they show changed.
-- Numbers: script attributes LbScrollRange, LbRowH (read per refresh). Diagnostics: LeaderboardBoardsVersion, LbBoardsState
--   ("off" / "on"), LbBoardsRows ("world <n> lobby <n>"), LbBoardsScroll ("near lobby" / "near world" / "far"), LbBoardsYou
--   (the YOU row text).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local VERSION = "1.0"
local DEFAULTS = {LbBoardsClientEnabled = true, LbScrollRange = 40, LbRowH = 62}
script:SetAttribute("LeaderboardBoardsVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("LbBoardsState", "off")

local RB
do
	local ok, m = pcall(function() return require(script.Parent:WaitForChild("RankBadge", 10)) end)
	RB = ok and m or nil
end

local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local C = {
	screen = Color3.fromRGB(12, 16, 24), gold = Color3.fromRGB(255, 200, 50), silver = Color3.fromRGB(207, 216, 230),
	bronze = Color3.fromRGB(224, 153, 90), cyan = Color3.fromRGB(127, 233, 255), green = Color3.fromRGB(70, 224, 138),
	muted = Color3.fromRGB(138, 149, 168), white = Color3.new(1, 1, 1), neon = Color3.fromRGB(255, 100, 18),
	line = Color3.fromRGB(42, 52, 70),
}
local W, H, PAD = 810, 930, 40

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local boards = {} -- [kind] = {sg, part, scroll, rows = {}, you, sig}

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = props.font or SILK
	l:SetAttribute("FontSwap", "keep")
	l.TextSize = props.size or 30
	l.TextColor3 = props.color or C.white
	l.Text = props.text or ""
	l.TextXAlignment = props.x or Enum.TextXAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Position = props.pos or UDim2.new()
	l.Size = props.sz or UDim2.new(1, 0, 0, (props.size or 30) + 6)
	l.Name = props.name or "Text"
	l.Parent = parent
	return l
end

local function newRow(parent, kind)
	local rh = tonumber(script:GetAttribute("LbRowH")) or 62
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.BackgroundColor3 = C.cyan
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, -16, 0, rh)
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = f
	local r = {frame = f}
	r.pos = label(f, {name = "Place", size = 28, color = C.muted, x = Enum.TextXAlignment.Right, pos = UDim2.fromOffset(0, 0), sz = UDim2.new(0, 56, 1, 0)})
	local nameBox = Instance.new("Frame")
	nameBox.Name = "NameBox"
	nameBox.BackgroundTransparency = 1
	nameBox.Position = UDim2.fromOffset(72, 0)
	nameBox.Size = UDim2.new(1, kind == "lobby" and -72 - 250 or -72 - 150, 1, 0)
	nameBox.ClipsDescendants = true
	nameBox.Parent = f
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.VerticalAlignment = Enum.VerticalAlignment.Center
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Padding = UDim.new(0, 10)
	lay.Parent = nameBox
	if RB and kind == "lobby" then
		r.badge = RB.new(24)
		r.badge.LayoutOrder = 1
		r.badge.Parent = nameBox
	end
	r.name = label(nameBox, {name = "Name", size = 32, x = Enum.TextXAlignment.Left, sz = UDim2.new(0, 0, 1, 0)})
	r.name.AutomaticSize = Enum.AutomaticSize.X
	r.name.LayoutOrder = 2
	if kind == "lobby" then
		r.wins = label(f, {name = "Wins", size = 28, color = C.green, x = Enum.TextXAlignment.Right, pos = UDim2.new(1, -250, 0, 0), sz = UDim2.new(0, 110, 1, 0)})
		r.wl = label(f, {name = "WL", size = 24, color = C.muted, x = Enum.TextXAlignment.Right, pos = UDim2.new(1, -130, 0, 0), sz = UDim2.new(0, 120, 1, 0)})
	else
		r.wins = label(f, {name = "Wins", size = 30, color = C.green, x = Enum.TextXAlignment.Right, pos = UDim2.new(1, -150, 0, 0), sz = UDim2.new(0, 140, 1, 0)})
	end
	f.Parent = parent
	return r
end

local function build(part, kind)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "LbScreen_" .. kind
	sg.Adornee = part
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.ResetOnSpawn = false
	sg.ClipsDescendants = true
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = C.screen
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local world = kind == "world"
	label(bg, {name = "Kicker", text = world and "ALL TIME" or "THIS SERVER", size = 28, color = world and C.gold or C.cyan, pos = UDim2.fromOffset(0, 28)})
	label(bg, {name = "Title", text = world and "WORLDWIDE" or "LOBBY", size = 64, pos = UDim2.fromOffset(0, 62)})
	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = world and C.gold or C.cyan
	rule.BackgroundTransparency = 0.6
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(PAD, 142)
	rule.Size = UDim2.new(1, -PAD * 2, 0, 3)
	rule.Parent = bg
	local foot = 52
	local youH = world and 76 or 0
	local sc = Instance.new("ScrollingFrame")
	sc.Name = "List"
	sc.BackgroundTransparency = 1
	sc.BorderSizePixel = 0
	sc.Position = UDim2.fromOffset(PAD - 8, 154)
	sc.Size = UDim2.new(1, -(PAD - 8) * 2, 1, -154 - youH - foot - 8)
	sc.CanvasSize = UDim2.new()
	sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sc.ScrollingDirection = Enum.ScrollingDirection.Y
	sc.ScrollBarThickness = 12
	sc.ScrollBarImageColor3 = C.neon
	sc.ScrollingEnabled = false
	sc.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	sc.Parent = bg
	local lay = Instance.new("UIListLayout")
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Padding = UDim.new(0, 4)
	lay.Parent = sc
	local b = {sg = sg, part = part, scroll = sc, rows = {}, kind = kind}
	if world then
		local you = Instance.new("Frame")
		you.Name = "You"
		you.BackgroundColor3 = C.cyan
		you.BackgroundTransparency = 0.82
		you.BorderSizePixel = 0
		you.Position = UDim2.new(0, PAD - 8, 1, -youH - foot)
		you.Size = UDim2.new(1, -(PAD - 8) * 2, 0, youH - 10)
		you.Parent = bg
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = you
		local s = Instance.new("UIStroke") s.Color = C.cyan s.Thickness = 3 s.Transparency = 0.3 s.Parent = you
		b.youPlace = label(you, {name = "Place", size = 30, color = C.cyan, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(18, 0), sz = UDim2.new(0, 330, 1, 0)})
		b.youName = label(you, {name = "Name", size = 32, color = C.cyan, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(150, 0), sz = UDim2.new(1, -330, 1, 0)})
		b.youWins = label(you, {name = "Wins", size = 30, color = C.green, x = Enum.TextXAlignment.Right, pos = UDim2.new(1, -170, 0, 0), sz = UDim2.new(0, 150, 1, 0)})
	end
	label(bg, {name = "Foot", text = world and "TOP 100 EARN A RANK BADGE" or "ARENA WINS · PLAYERS HERE NOW", size = 22, color = C.muted,
		pos = UDim2.new(0, 0, 1, -foot + 8)})
	sg.Parent = pg
	return b
end

local function rowAt(b, i)
	local r = b.rows[i]
	if not r then
		r = newRow(b.scroll, b.kind)
		r.frame.LayoutOrder = i
		b.rows[i] = r
	end
	r.frame.Visible = true
	return r
end
local function trim(b, n)
	for i = n + 1, #b.rows do b.rows[i].frame.Visible = false end
end

local function worldList()
	local raw = ReplicatedStorage:GetAttribute("LbWorldTop")
	if type(raw) ~= "string" or raw == "" then return {} end
	local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and type(t) == "table" and t or {}
end

local function drawWorld(b)
	local list = worldList()
	local sig = (ReplicatedStorage:GetAttribute("LbWorldTop") or "") .. "|" .. tostring(player:GetAttribute("ArenaW")) .. tostring(player:GetAttribute("ArenaRecordReady"))
	if b.sig == sig then return #list end
	b.sig = sig
	local mine
	for i, e in ipairs(list) do
		local r = rowAt(b, i)
		local id, name, wins = e[1], tostring(e[2] or "PLAYER"), tonumber(e[3]) or 0
		local me = id == player.UserId
		if me then mine = {i, wins} end
		r.pos.Text = tostring(i)
		r.name.Text = name
		r.name.TextColor3 = i == 1 and C.gold or i == 2 and C.silver or i == 3 and C.bronze or C.white
		r.wins.Text = wins .. "W"
		r.frame.BackgroundTransparency = me and 0.82 or 1
	end
	trim(b, #list)
	local ready = player:GetAttribute("ArenaRecordReady") == true
	if mine then
		b.youPlace.Text = "#" .. mine[1]
		b.youName.Text = "YOU"
		b.youWins.Text = mine[2] .. "W"
	else
		b.youPlace.Text = "NOT RANKED"
		b.youName.Text = ""
		b.youWins.Text = ready and ((tonumber(player:GetAttribute("ArenaW")) or 0) .. "W") or "-"
	end
	b.youName.Position = mine and UDim2.fromOffset(150, 0) or UDim2.fromOffset(330, 0)
	script:SetAttribute("LbBoardsYou", b.youPlace.Text .. " " .. b.youName.Text .. " " .. b.youWins.Text)
	return #list
end

local function drawLobby(b)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local ready = p:GetAttribute("ArenaRecordReady") == true
		table.insert(list, {p = p, ready = ready, w = ready and (tonumber(p:GetAttribute("ArenaW")) or 0) or -1,
			l = tonumber(p:GetAttribute("ArenaL")) or 0, name = string.upper(p.DisplayName), rank = RB and RB.rankOf(p) or nil})
	end
	table.sort(list, function(a, c)
		if a.w ~= c.w then return a.w > c.w end
		return a.name < c.name
	end)
	local parts = {}
	for _, e in ipairs(list) do table.insert(parts, ("%d:%d:%d:%s"):format(e.p.UserId, e.w, e.l, tostring(e.rank))) end
	local sig = table.concat(parts, ",")
	if b.sig == sig then return #list end
	b.sig = sig
	for i, e in ipairs(list) do
		local r = rowAt(b, i)
		r.pos.Text = tostring(i)
		r.name.Text = e.name
		if r.badge then RB.set(r.badge, e.rank, 24) end
		r.wins.Text = e.ready and (e.w .. "W") or "-"
		r.wl.Text = e.ready and (e.w .. "-" .. e.l) or ""
		r.frame.BackgroundTransparency = e.p == player and 0.82 or 1
		r.name.TextColor3 = e.p == player and C.cyan or C.white
	end
	trim(b, #list)
	return #list
end

local function clear()
	for k, b in pairs(boards) do
		b.sg:Destroy()
		boards[k] = nil
	end
end

local function on()
	return script:GetAttribute("LbBoardsClientEnabled") ~= false and ReplicatedStorage:GetAttribute("ServerKind") == "hub"
end

local acc = 0
while true do
	local ok, err = pcall(function()
		if not on() then
			if next(boards) then clear() end
			script:SetAttribute("LbBoardsState", "off")
			return
		end
		local folder = workspace:FindFirstChild("IsletBoards")
		if folder then
			for _, m in ipairs(folder:GetChildren()) do
				local scr = m:FindFirstChild("Screen")
				local kind = scr and scr:GetAttribute("LbBoard")
				if kind and (not boards[kind] or boards[kind].part ~= scr) then
					if boards[kind] then boards[kind].sg:Destroy() end
					boards[kind] = build(scr, kind)
				end
			end
		end
		for k, b in pairs(boards) do
			if not b.part.Parent then b.sg:Destroy() boards[k] = nil end
		end
		script:SetAttribute("LbBoardsState", next(boards) and "on" or "waiting")
		-- scrolling only up close
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local range = tonumber(script:GetAttribute("LbScrollRange")) or 40
		local near = "far"
		for k, b in pairs(boards) do
			local d = root and (root.Position - b.part.Position) or nil
			local close = d ~= nil and Vector3.new(d.X, 0, d.Z).Magnitude <= range -- flat distance (the screen is high up)
			b.scroll.ScrollingEnabled = close
			if close then near = "near " .. k end
		end
		script:SetAttribute("LbBoardsScroll", near)
		acc += 1
		if acc >= 4 then
			acc = 0
			local nw = boards.world and drawWorld(boards.world) or 0
			local nl = boards.lobby and drawLobby(boards.lobby) or 0
			script:SetAttribute("LbBoardsRows", ("world %d lobby %d"):format(nw, nl))
		end
	end)
	if not ok then script:SetAttribute("LbBoardsError", tostring(err)) end
	task.wait(0.25)
end
