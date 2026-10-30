-- EggLoader v1.0 (Mecha Dino Arena) — the loading screen: a blocky egg in a mecha incubator that keeps cracking while
-- the game loads, then a baby T-Rex hatches and, 2 s later, the screen fades into the main menu (LocalScript in
-- ReplicatedFirst, all devices). MDA-93, plan docs/plans/EGG_LOADER_v1.0.md Task 1, mockup docs/mockups/egg_loading_options.html
-- option C "Mecha incubator" (Kepu 2026-10-29: "a load screen in between with a Dino egg hatching and a baby Dino sitting
-- inside looking all cute. The egg should keep cracking until the Dino baby comes out then 2 seconds after that the game
-- should be fully loaded in the background"; "I like the incubator"; answers: join + every place hop, cracks until loaded,
-- always a baby T-Rex, at least 3 seconds, hatch anyway after 45 s, check the trip live).
-- Drawn only from Frames / TextLabels (no images), so it shows on the first frame of a join; Roblox's default loading
--   screen is removed (ReplicatedFirst:RemoveDefaultLoadingScreen).
-- Layout (ScreenGui "EggLoader", DisplayOrder 100, IgnoreGuiInset, ResetOnSpawn false; ch = height / 100, cw = width / 100):
--   backdrop rgb(16, 20, 29) -> rgb(26, 33, 48) -> rgb(14, 18, 25) (top to bottom) with a faint volt grid every 6ch;
--   left (x 6cw, centred, max 30cw): "MECHA DINO" (yellow, 0.42 x title) over "ARENA" (FredokaOne 6ch), caption (volt,
--     GothamBlack max(2.2ch, 11 px)), tip (grey-blue, max(2ch, 11 px));
--   centre pod 46ch x 70ch (top max(13ch, top bar + 8ch)): lid (x 2ch .. 44ch, 7ch tall, rgb(58, 67, 80), two orange
--     2ch lights), glass (x 6ch .. 40ch, y 7ch .. 60ch, 0.6ch frame, volt glow), base (bottom 3ch, 8ch tall); the egg box
--     26ch x 34ch, 11ch above the pod bottom;
--   right gauge (x 7cw from the right, centred): tube 4ch x 44ch with a volt fill, the % under it (FredokaOne).
-- Egg (the mockup's 18 x 24 grid of 8-unit cells, canvas -40 .. 184 x -60 .. 202 units, scaled to the box): shaded
--   cream cells with spots; the top cells above a zigzag split line form two halves (TopL / TopR); the inside of the shell
--   (3 dark rows under the split) is hidden until the hatch; the baby T-Rex (big head, big blinking eyes, blush, tiny
--   arms) sits 60 units down behind the lower shell; 5 crack lines (dark, 3 units thick).
-- Sequence:
--   * loading: progress p (0..1) every frame, never going down: before Loaded p = min(0.95, max(timeCurve, assetPart)),
--     timeCurve = 0.95 (1 - e^(-t / 6)), assetPart = 0.95 (1 - ContentProvider.RequestQueueSize / largest queue seen)
--     (0 while no queue was seen). Cracks appear at p >= 0.12 / 0.3 / 0.5 / 0.7 / 0.9; the egg rocks on its bottom
--     (level 1 above 0.1: +-2 degrees every 1.6 s, level 2 above 0.45: every 0.9 s, level 3 above 0.8: +-5 every 0.7 s).
--   * Loaded = game:IsLoaded(), LocalPlayer.Character exists, and (when ModeServer is on: the player attribute InMenu is
--     set within 10 s) MainMenuOpen == true. Or 45 s (TIMEOUT) after the screen appeared: EggLoaderLoadReason "timeout".
--   * once Loaded and at least MIN_CRACK (3) s after the screen appeared: p rises to 1 over 0.4 s, then the hatch: the
--     cracks go, the lid lifts 10ch (0.9 s, bounce), the two top halves fly off and fade (0.9 s), the inside shows, the
--     baby rises to sit in the shell (0.7 s, bounce) and starts bobbing / blinking; caption "HATCHED!" (join) or
--     "WELCOME TO THE ARENA!" / "WELCOME TO THE SANDBOX!" (after a trip); 2 s (HOLD); then a dark cover fades in (0.3 s),
--     the screen is removed and the cover fades out (0.3 s) onto the menu.
-- Trips (MainMenu 1.1): BindableFunction ReplicatedFirst.EggLoader.Show(target) ("Arena" / "Sandbox") puts up a fresh
--   egg with the caption "TRAVELING TO ARENA" / "TRAVELING TO SANDBOX" that keeps cracking (time curve only, no hatch)
--   and returns the ScreenGui for TeleportService:SetTeleportGui (its attribute EggLoaderTarget = target);
--   Hide() takes it down (teleport failed). On arrival TeleportService:GetArrivingTeleportGui() (if any) gives the target:
--   the caption reads "TRAVELING TO ..." while loading and "WELCOME TO THE ..." when it hatches; the arriving gui is
--   destroyed. Replay() runs the join sequence again (test).
-- Switch: script attribute EggLoaderEnabled (default true), read at start; false -> Roblox's default loading screen.
-- Diagnostics (LocalPlayer attributes, this client): EggLoaderVersion, EggLoaderState ("loading" / "hatching" /
--   "hatched" / "fading" / "done" / "travel" / "off"), EggLoaderProgress (0.01), EggLoaderCracks (0..5),
--   EggLoaderLoadReason ("loaded" / "timeout"), EggLoaderShownFor (s, at the hatch), EggLoaderTrip ("" / "Arena" /
--   "Sandbox").
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

local VERSION = "1.0"
local MIN_CRACK = 3
local TIMEOUT = 45
local HOLD = 2
local MENU_WAIT = 10
local CRACK_AT = {0.12, 0.3, 0.5, 0.7, 0.9}
local VOLT = Color3.fromRGB(127, 233, 255)
local YELLOW = Color3.fromRGB(255, 200, 50)
local ORANGE = Color3.fromRGB(255, 155, 46)
local METAL = Color3.fromRGB(58, 67, 80)
local TIP_GREY = Color3.fromRGB(143, 153, 170)
local TIPS = {
	'Tip: tap your dino in the menu to see its <font color="#ffc832">mech parts</font>.',
	'Tip: in the Arena there are <font color="#ffc832">no bots</font>. Watch for other dinos.',
	'Tip: <font color="#ffc832">Energy Shield</font> blocks a Shock Mine if it was up first.',
}

if script:GetAttribute("EggLoaderEnabled") == nil then script:SetAttribute("EggLoaderEnabled", true) end
local player = Players.LocalPlayer
player:SetAttribute("EggLoaderVersion", VERSION)
if script:GetAttribute("EggLoaderEnabled") == false then
	player:SetAttribute("EggLoaderState", "off")
	return
end
ReplicatedFirst:RemoveDefaultLoadingScreen()
local pg = player:WaitForChild("PlayerGui")

-- ---------- egg data (same numbers as the mockup) ----------
local COLS, ROWS, CELL = 18, 24, 8
local CX0, CY0, CW, CH = -40, -60, 224, 262 -- canvas in egg units
local function splitAt(c)
	local m = c % 4
	local v = 10
	if m >= 2 then v += 1 end
	if m == 1 then v -= 1 end
	return v
end
local SPOTS = {["5,6"] = true, ["6,6"] = true, ["11,8"] = true, ["12,8"] = true, ["12,9"] = true, ["4,14"] = true,
	["13,15"] = true, ["14,15"] = true, ["8,18"] = true, ["9,18"] = true, ["6,11"] = true, ["10,4"] = true}
local function eggCells()
	local cells = {}
	local cx, cy, b = COLS / 2, ROWS * 0.56, ROWS * 0.5
	for r = 0, ROWS - 1 do
		local dy = (r + 0.5 - cy) / b
		if math.abs(dy) < 1 then
			local half = (COLS / 2) * math.sqrt(1 - dy * dy)
			if r + 0.5 < cy then half *= 1 - 0.18 * ((cy - r - 0.5) / b) end
			for c = 0, COLS - 1 do
				local dx = c + 0.5 - cx
				if math.abs(dx) <= half then table.insert(cells, {c, r, dx / half, dy}) end
			end
		end
	end
	return cells
end
local function shade(c, r, nx, ny)
	if SPOTS[c .. "," .. r] then return Color3.fromRGB(215, 185, 138) end
	local light = -nx * 0.6 - ny * 0.4
	if light > 0.45 then
		return Color3.fromRGB(255, 250, 240)
	elseif light > 0.05 then
		return Color3.fromRGB(246, 236, 216)
	elseif light > -0.4 then
		return Color3.fromRGB(234, 220, 191)
	else
		return Color3.fromRGB(217, 199, 164)
	end
end
local CRACKS = {
	{{64, 40}, {72, 56}, {64, 64}, {76, 80}},
	{{104, 96}, {96, 108}, {108, 116}, {100, 132}},
	{{40, 120}, {52, 128}, {44, 140}},
	{{116, 60}, {106, 72}, {118, 84}},
}
do -- the main crack along the split line (the one that opens)
	local main = {{8, 84}}
	for c = 0, COLS do table.insert(main, {c * CELL, splitAt(math.min(c, COLS - 1)) * CELL}) end
	table.insert(CRACKS, main)
end

-- ---------- building ----------
local function frame(parent, name, color, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	if color then
		f.BackgroundColor3 = color
	else
		f.BackgroundTransparency = 1
	end
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end
local function label(parent, name, font, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextColor3 = color
	l.Text = ""
	l.Parent = parent
	return l
end
-- a rect in egg units inside a full-canvas group
local function unitRect(parent, x, y, w, h, color, name)
	local f = frame(parent, name or "B", color)
	f.Position = UDim2.fromScale((x - CX0) / CW, (y - CY0) / CH)
	f.Size = UDim2.fromScale((w + 0.4) / CW, (h + 0.4) / CH)
	return f
end
local function group(parent, name, z)
	local g = frame(parent, name, nil, z)
	g.Size = UDim2.fromScale(1, 1)
	return g
end

local current -- the screen on show: {gui, root, parts..., mode = "join" / "travel", target}

local function build(mode, target)
	local s = {mode = mode, target = target, t0 = os.clock(), p = 0, cracks = 0, maxQueue = 0, level = 0}
	local gui = Instance.new("ScreenGui")
	gui.Name = "EggLoader"
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if target then gui:SetAttribute("EggLoaderTarget", target) end
	s.gui = gui

	local root = Instance.new("TextButton") -- takes every touch / click while the screen is up
	root.Name = "Root"
	root.AutoButtonColor = false
	root.Text = ""
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.new(1, 1, 1)
	root.BorderSizePixel = 0
	root.Parent = gui
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 20, 29)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(26, 33, 48)), ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 18, 25))})
	bg.Parent = root
	s.root = root
	s.grid = frame(root, "Grid", nil, 1)
	s.grid.Size = UDim2.fromScale(1, 1)

	-- left text
	s.titleSmall = label(root, "TitleSmall", Enum.Font.FredokaOne, YELLOW)
	s.titleSmall.Text = "MECHA DINO"
	s.titleSmall.TextXAlignment = Enum.TextXAlignment.Left
	s.title = label(root, "Title", Enum.Font.FredokaOne, Color3.new(1, 1, 1))
	s.title.Text = "ARENA"
	s.title.TextXAlignment = Enum.TextXAlignment.Left
	s.titleShadow = label(root, "TitleShadow", Enum.Font.FredokaOne, Color3.new(0, 0, 0))
	s.titleShadow.Text = "ARENA"
	s.titleShadow.TextTransparency = 0.55
	s.titleShadow.TextXAlignment = Enum.TextXAlignment.Left
	s.titleShadow.ZIndex = 0
	s.caption = label(root, "Caption", Enum.Font.GothamBlack, VOLT)
	s.caption.TextXAlignment = Enum.TextXAlignment.Left
	s.tip = label(root, "Tip", Enum.Font.GothamBold, TIP_GREY)
	s.tip.RichText = true
	s.tip.TextWrapped = true
	s.tip.TextXAlignment = Enum.TextXAlignment.Left
	s.tip.TextYAlignment = Enum.TextYAlignment.Top
	s.tip.Text = TIPS[math.random(1, #TIPS)]
	if mode == "travel" or target then
		s.caption.Text = "TRAVELING TO " .. string.upper(target or "ARENA")
	else
		s.caption.Text = "LOADING THE ISLAND"
	end

	-- pod
	local pod = frame(root, "Pod", nil, 2)
	s.pod = pod
	s.glass = frame(pod, "Glass", VOLT, 2)
	s.glass.BackgroundTransparency = 0.82
	local gg = Instance.new("UIGradient")
	gg.Rotation = 90
	gg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 0.5)})
	gg.Parent = s.glass
	s.glassStroke = Instance.new("UIStroke")
	s.glassStroke.Color = METAL
	s.glassStroke.Parent = s.glass
	s.base = frame(pod, "Base", METAL, 6)
	s.baseShade = frame(s.base, "Shade", Color3.new(0, 0, 0), 6)
	s.baseShade.BackgroundTransparency = 0.7
	s.baseShade.AnchorPoint = Vector2.new(0, 1)
	s.baseShade.Position = UDim2.fromScale(0, 1)
	s.lid = frame(pod, "Lid", METAL, 6)
	s.lidShade = frame(s.lid, "Shade", Color3.new(0, 0, 0), 6)
	s.lidShade.BackgroundTransparency = 0.7
	s.lidShade.AnchorPoint = Vector2.new(0, 1)
	s.lidShade.Position = UDim2.fromScale(0, 1)
	s.lightL = frame(s.lid, "LightL", ORANGE, 7)
	s.lightR = frame(s.lid, "LightR", ORANGE, 7)

	-- egg: wobble container (centre = the egg's bottom), canvas inside at its top
	s.wob = frame(pod, "EggWob", nil, 3)
	s.wob.AnchorPoint = Vector2.new(0.5, 0.5)
	local canvas = frame(s.wob, "Egg", nil, 3)
	canvas.Size = UDim2.fromScale(1, CH / (2 * 237))
	s.canvas = canvas
	s.inner = group(canvas, "Inner", 1)
	s.baby = group(canvas, "Baby", 2)
	s.bot = group(canvas, "Bottom", 3)
	s.topL = group(canvas, "TopL", 4)
	s.topR = group(canvas, "TopR", 4)
	s.crackG = group(canvas, "Cracks", 5)
	s.topCells = {}
	for _, cell in ipairs(eggCells()) do
		local c, r, nx, ny = cell[1], cell[2], cell[3], cell[4]
		local x, y = c * CELL, r * CELL
		if r < splitAt(c) then
			local g = x < (COLS * CELL) / 2 and s.topL or s.topR
			table.insert(s.topCells, unitRect(g, x, y, CELL, CELL, shade(c, r, nx, ny)))
		else
			unitRect(s.bot, x, y, CELL, CELL, shade(c, r, nx, ny))
			if r < splitAt(c) + 3 and c > 1 and c < COLS - 2 then
				unitRect(s.inner, x, y, CELL, CELL, Color3.fromRGB(107, 90, 62))
			end
		end
	end
	s.inner.Visible = false
	-- baby T-Rex (unit coords of the mockup)
	local G, D, L, B = Color3.fromRGB(124, 192, 74), Color3.fromRGB(91, 154, 51), Color3.fromRGB(168, 221, 114), Color3.fromRGB(244, 227, 176)
	local K, Wt, P = Color3.fromRGB(26, 26, 26), Color3.new(1, 1, 1), Color3.fromRGB(255, 157, 176)
	local bb = s.baby
	for _, t in ipairs({
		{40, 64, 64, 40, G}, {48, 72, 48, 24, B}, {28, 12, 88, 60, G}, {36, 4, 64, 12, G}, {36, 16, 72, 8, L},
		{100, 40, 28, 28, G}, {104, 60, 24, 8, D}, {112, 64, 4, 4, Wt}, {120, 64, 4, 4, Wt},
		{40, 54, 10, 6, P}, {98, 54, 10, 6, P}, {64, 58, 4, 4, K}, {68, 62, 12, 4, K}, {80, 58, 4, 4, K},
		{26, 70, 16, 8, G}, {102, 70, 16, 8, G}, {22, 74, 8, 6, D}, {114, 74, 8, 6, D},
	}) do unitRect(bb, t[1], t[2], t[3], t[4], t[5]) end
	s.eyes = {}
	for _, ex in ipairs({48, 84}) do
		local eye = unitRect(bb, ex, 28, 20, 24, K, "Eye")
		eye.AnchorPoint = Vector2.new(0, 0.5)
		eye.Position = UDim2.fromScale((ex - CX0) / CW, (28 + 12 - CY0) / CH)
		local shine = frame(eye, "Shine", Wt, 1)
		shine.Position = UDim2.fromScale(4 / 20, 2 / 24)
		shine.Size = UDim2.fromScale(8 / 20, 8 / 24)
		table.insert(s.eyes, eye)
	end
	s.baby.Position = UDim2.fromScale(0, 60 / CH)
	-- cracks: one thin frame per segment, hidden until that crack appears
	s.crackSegs = {}
	for i, pts in ipairs(CRACKS) do
		local segs = {}
		for k = 1, #pts - 1 do
			local a, b2 = pts[k], pts[k + 1]
			local mx, my = (a[1] + b2[1]) / 2, (a[2] + b2[2]) / 2
			local len = math.sqrt((b2[1] - a[1]) ^ 2 + (b2[2] - a[2]) ^ 2) + 3
			local f = frame(s.crackG, ("Crack%d_%d"):format(i, k), Color3.fromRGB(59, 43, 26))
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale((mx - CX0) / CW, (my - CY0) / CH)
			f.Size = UDim2.fromScale(len / CW, 3.2 / CH)
			f.Rotation = math.deg(math.atan2(b2[2] - a[2], b2[1] - a[1]))
			f.Visible = false
			table.insert(segs, f)
		end
		s.crackSegs[i] = segs
	end

	-- gauge
	s.tube = frame(root, "Tube", Color3.new(0, 0, 0), 2)
	s.tube.BackgroundTransparency = 0.65
	s.tubeStroke = Instance.new("UIStroke")
	s.tubeStroke.Color = METAL
	s.tubeStroke.Parent = s.tube
	s.fill = frame(s.tube, "Fill", Color3.new(1, 1, 1), 2)
	s.fill.AnchorPoint = Vector2.new(0, 1)
	s.fill.Position = UDim2.fromScale(0, 1)
	s.fill.Size = UDim2.fromScale(1, 0)
	local fg = Instance.new("UIGradient")
	fg.Rotation = 90
	fg.Color = ColorSequence.new(VOLT, Color3.fromRGB(43, 181, 216))
	fg.Parent = s.fill
	s.pct = label(root, "Percent", Enum.Font.FredokaOne, VOLT)
	s.pct.Text = "0%"

	s.cover = frame(gui, "Cover", Color3.fromRGB(10, 12, 18), 20)
	s.cover.Size = UDim2.fromScale(1, 1)
	s.cover.BackgroundTransparency = 1
	gui.Parent = pg
	return s
end

-- ---------- layout ----------
local function layout(s)
	local W, H = s.root.AbsoluteSize.X, s.root.AbsoluteSize.Y
	if W <= 0 or H <= 0 then return end
	local ch, cw = H / 100, W / 100
	-- grid
	if s.gridKey ~= W .. "x" .. H then
		s.gridKey = W .. "x" .. H
		s.grid:ClearAllChildren()
		local step = 6 * ch
		local x = step
		while x < W do
			local l = frame(s.grid, "V", VOLT, 1)
			l.BackgroundTransparency = 0.94
			l.Position, l.Size = UDim2.fromOffset(x, 0), UDim2.new(0, 2, 1, 0)
			x += step
		end
		local y = step
		while y < H do
			local l = frame(s.grid, "H", VOLT, 1)
			l.BackgroundTransparency = 0.94
			l.Position, l.Size = UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 2)
			y += step
		end
	end
	-- pod
	local ok, inset = pcall(function() return GuiService.TopbarInset.Height end)
	if not ok or type(inset) ~= "number" then inset = 58 end
	local podW, podH = 46 * ch, 70 * ch
	local podTop = math.max(13 * ch, inset + 8 * ch)
	if podTop + podH > H - 2 * ch then podTop = math.max(inset + ch, H - 2 * ch - podH) end
	s.pod.Position, s.pod.Size = UDim2.fromOffset((W - podW) / 2, podTop), UDim2.fromOffset(podW, podH)
	s.glass.Position, s.glass.Size = UDim2.fromOffset(6 * ch, 7 * ch), UDim2.fromOffset(podW - 12 * ch, podH - 17 * ch)
	s.glassStroke.Thickness = math.max(0.6 * ch, 2)
	s.lidY = 0
	if not s.lidOpen then s.lid.Position = UDim2.fromOffset(2 * ch, 0) end
	s.lid.Size = UDim2.fromOffset(podW - 4 * ch, 7 * ch)
	s.lidShade.Size = UDim2.new(1, 0, 0, ch)
	s.lightL.Position, s.lightL.Size = UDim2.fromOffset(4 * ch, 2.4 * ch), UDim2.fromOffset(2 * ch, 2 * ch)
	s.lightR.Position, s.lightR.Size = UDim2.fromOffset(podW - 4 * ch - 4 * ch - 2 * ch, 2.4 * ch), UDim2.fromOffset(2 * ch, 2 * ch)
	s.base.Position, s.base.Size = UDim2.fromOffset(2 * ch, podH - 11 * ch), UDim2.fromOffset(podW - 4 * ch, 8 * ch)
	s.baseShade.Size = UDim2.new(1, 0, 0, ch)
	-- egg box 26ch x 34ch, 11ch above the pod bottom; canvas fitted inside (width-limited), centred vertically
	local boxW, boxH = 26 * ch, 34 * ch
	local boxX, boxY = (podW - boxW) / 2, podH - 11 * ch - boxH
	local u = math.min(boxW / CW, boxH / CH)
	local canW, canH = CW * u, CH * u
	local canX, canY = boxX + (boxW - canW) / 2, boxY + (boxH - canH) / 2
	local pivotY = canY + (237 / CH) * canH
	s.wob.Size = UDim2.fromOffset(canW, 2 * (pivotY - canY))
	s.wob.Position = UDim2.fromOffset(canX + canW / 2, pivotY)
	-- left text
	local tBig = 6 * ch
	local tSmall = tBig * 0.42
	local capS = math.max(2.2 * ch, 11)
	local tipS = math.max(2 * ch, 11)
	local lx = 6 * cw
	local lw = math.max(math.min(30 * cw, (W - podW) / 2 - lx - 2 * cw), 80)
	local tipH = tipS * 1.35 * 3
	local total = tSmall + 0.5 * ch + tBig + 1.4 * ch + capS + 1.4 * ch + tipH
	local ty = H / 2 - total / 2
	s.titleSmall.Position, s.titleSmall.Size = UDim2.fromOffset(lx, ty), UDim2.fromOffset(lw, tSmall)
	s.titleSmall.TextSize = tSmall
	ty += tSmall + 0.5 * ch
	s.title.Position, s.title.Size = UDim2.fromOffset(lx, ty), UDim2.fromOffset(lw, tBig)
	s.title.TextSize = tBig
	s.titleShadow.Position, s.titleShadow.Size = UDim2.fromOffset(lx, ty + 0.5 * ch), UDim2.fromOffset(lw, tBig)
	s.titleShadow.TextSize = tBig
	ty += tBig + 1.4 * ch
	s.caption.Position, s.caption.Size = UDim2.fromOffset(lx, ty), UDim2.fromOffset(lw, capS)
	s.caption.TextSize = capS
	s.caption.TextWrapped = true
	ty += capS + 1.4 * ch
	s.tip.Position, s.tip.Size = UDim2.fromOffset(lx, ty), UDim2.fromOffset(lw, tipH)
	s.tip.TextSize = tipS
	-- gauge
	local tubeW, tubeH = 4 * ch, 44 * ch
	local pctS = math.max(2.6 * ch, 13)
	local gx = W - 7 * cw - tubeW
	local gy = H / 2 - (tubeH + 1.2 * ch + pctS) / 2
	s.tube.Position, s.tube.Size = UDim2.fromOffset(gx, gy), UDim2.fromOffset(tubeW, tubeH)
	s.tubeStroke.Thickness = math.max(0.5 * ch, 2)
	s.pct.Position, s.pct.Size = UDim2.fromOffset(gx - 4 * ch, gy + tubeH + 1.2 * ch), UDim2.fromOffset(tubeW + 8 * ch, pctS)
	s.pct.TextSize = pctS
	s.ch = ch
end

-- ---------- running ----------
local function setState(v) player:SetAttribute("EggLoaderState", v) end

local function showCracks(s, n)
	for i = s.cracks + 1, n do
		for k, seg in ipairs(s.crackSegs[i]) do
			task.delay((k - 1) * 0.08, function() if seg.Parent then seg.Visible = true end end)
		end
	end
	s.cracks = n
	player:SetAttribute("EggLoaderCracks", n)
end

local function rockLevel(p)
	if p > 0.8 then return 3 elseif p > 0.45 then return 2 elseif p > 0.1 then return 1 else return 0 end
end

local function isLoaded(s)
	if not game:IsLoaded() or not player.Character then return false end
	local inMenu = player:GetAttribute("InMenu")
	if inMenu == nil then
		return os.clock() - s.t0 >= MENU_WAIT -- ModeServer off: nothing more to wait for
	elseif inMenu == true then
		return player:GetAttribute("MainMenuOpen") == true
	else
		return true
	end
end

local function finish(s)
	setState("fading")
	local tin = TweenService:Create(s.cover, TweenInfo.new(0.3), {BackgroundTransparency = 0})
	tin:Play()
	tin.Completed:Wait()
	s.root:Destroy()
	local tout = TweenService:Create(s.cover, TweenInfo.new(0.3), {BackgroundTransparency = 1})
	tout:Play()
	tout.Completed:Wait()
	s.gui:Destroy()
	if current == s then current = nil end
	setState("done")
end

local function hatch(s)
	s.hatching = true
	setState("hatching")
	player:SetAttribute("EggLoaderShownFor", math.floor((os.clock() - s.t0) * 10 + 0.5) / 10)
	s.wob.Rotation = 0
	s.crackG.Visible = false
	s.inner.Visible = true
	s.lidOpen = true
	TweenService:Create(s.lid, TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.fromOffset(2 * s.ch, -10 * s.ch)}):Play()
	local fly = TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(s.topL, fly, {Position = UDim2.fromScale(-70 / CW, -90 / CH), Rotation = -38}):Play()
	TweenService:Create(s.topR, fly, {Position = UDim2.fromScale(70 / CW, -80 / CH), Rotation = 34}):Play()
	for _, cell in ipairs(s.topCells) do
		TweenService:Create(cell, fly, {BackgroundTransparency = 1}):Play()
	end
	task.wait(0.25)
	TweenService:Create(s.baby, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.fromScale(0, -4 / CH)}):Play()
	if s.target then
		s.caption.Text = "WELCOME TO THE " .. string.upper(s.target) .. "!"
	else
		s.caption.Text = "HATCHED!"
	end
	task.wait(0.7)
	setState("hatched")
	s.hatched = true -- bob + blink run in the frame loop
	task.wait(HOLD)
	finish(s)
end

local function start(s)
	layout(s)
	s.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() layout(s) end)
	setState(s.mode == "travel" and "travel" or "loading")
	player:SetAttribute("EggLoaderTrip", s.target or "")
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not s.gui.Parent then conn:Disconnect() return end
		local t = os.clock() - s.t0
		if s.hatched then
			s.baby.Position = UDim2.fromScale(0, (-4 - 3 * math.abs(math.sin(t * 2.2))) / CH)
			local blink = (t % 3.2) > 3.05
			for _, e in ipairs(s.eyes) do e.Size = UDim2.fromScale(20.4 / CW, (blink and 3 or 24.4) / CH) end
			return
		end
		if s.hatching then return end
		-- progress
		local q = ContentProvider.RequestQueueSize
		if q > s.maxQueue then s.maxQueue = q end
		local timeCurve = 0.95 * (1 - math.exp(-t / 6))
		local assetPart = 0
		if s.mode ~= "travel" and s.maxQueue > 0 then assetPart = 0.95 * (1 - q / s.maxQueue) end
		local target = math.min(0.95, math.max(timeCurve, assetPart))
		local ready = false
		if s.mode ~= "travel" and t >= MIN_CRACK then
			if isLoaded(s) then
				ready = true
				player:SetAttribute("EggLoaderLoadReason", "loaded")
			elseif t >= TIMEOUT then
				ready = true
				player:SetAttribute("EggLoaderLoadReason", "timeout")
			end
		end
		if ready then
			s.readyAt = s.readyAt or os.clock()
			local k = math.min(1, (os.clock() - s.readyAt) / 0.4)
			target = s.pFromReady and (s.pFromReady + (1 - s.pFromReady) * k) or s.p
			s.pFromReady = s.pFromReady or s.p
		end
		s.p = math.max(s.p, target)
		s.fill.Size = UDim2.fromScale(1, s.p)
		s.pct.Text = math.floor(s.p * 100) .. "%"
		player:SetAttribute("EggLoaderProgress", math.floor(s.p * 100) / 100)
		local n = 0
		for i, at in ipairs(CRACK_AT) do if s.p >= at then n = i end end
		if n > s.cracks then showCracks(s, n) end
		-- rocking on its bottom
		local lv = rockLevel(s.p)
		if lv == 1 then
			s.wob.Rotation = 2 * math.sin(t * 2 * math.pi / 1.6)
		elseif lv == 2 then
			s.wob.Rotation = 2 * math.sin(t * 2 * math.pi / 0.9)
		elseif lv == 3 then
			s.wob.Rotation = 5 * math.sin(t * 2 * math.pi / 0.7)
		else
			s.wob.Rotation = 0
		end
		if ready and s.p >= 1 then
			s.hatching = true
			task.spawn(hatch, s)
		end
	end)
end

local function show(mode, target)
	if current and current.gui.Parent then current.gui:Destroy() end
	local s = build(mode, target)
	current = s
	start(s)
	return s
end

-- trips (MainMenu 1.1) and the test replay
local api = script:FindFirstChild("Show") or Instance.new("BindableFunction")
api.Name = "Show"
api.Parent = script
api.OnInvoke = function(target)
	local t = (target == "Sandbox") and "Sandbox" or "Arena"
	return show("travel", t).gui
end
local hideApi = script:FindFirstChild("Hide") or Instance.new("BindableFunction")
hideApi.Name = "Hide"
hideApi.Parent = script
hideApi.OnInvoke = function()
	if current and current.mode == "travel" and current.gui.Parent then
		current.gui:Destroy()
		current = nil
		setState("done")
	end
	return true
end
local replayApi = script:FindFirstChild("Replay") or Instance.new("BindableFunction")
replayApi.Name = "Replay"
replayApi.Parent = script
replayApi.OnInvoke = function()
	show("join", nil)
	return true
end

-- join (or arrival after a trip)
local arriving
pcall(function() arriving = TeleportService:GetArrivingTeleportGui() end)
local arrivedFrom = arriving and arriving:GetAttribute("EggLoaderTarget")
if arriving then arriving:Destroy() end
show("join", (arrivedFrom == "Arena" or arrivedFrom == "Sandbox") and arrivedFrom or nil)
