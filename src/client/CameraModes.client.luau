-- CameraModes v1.0 (Mecha Dino Arena) — the player's CAMERA choice: Classic / Shift Lock / Shoulder (LocalScript,
-- StarterPlayerScripts, all devices). MDA-371, plan docs/plans/CAMERA_MODES_v1.0.md tickets 2 + 4; mockup
-- docs/mockups/camera_options_v0.1.html direction C "Both" (Kepu 2026-11-08: "My players want options to have the regular
-- player camera & a shift lock option"; 2026-11-09: "Both", phone start Classic, "regular camera" = Classic, Classic aim =
-- where the camera looks).
-- The mode: device type = "touch" (TouchEnabled and not MouseEnabled, or the test hook player attribute CameraTouchTest =
--   true: the Studio phone emulator keeps MouseEnabled) else "mouse". Mode = this session's pick for that type, else the
--   saved player attribute CameraModeTouch / CameraModeMouse (CameraSettings 1.0), else the default: touch "classic",
--   mouse "shoulder". It is written to the character attribute CameraMode on every spawn and change (this client only;
--   ShoulderCam 1.9 frames by it, MechaButtons 1.40 aims by it). Roblox's camera movement mode is set to Classic by
--   CameraSettings 1.0 on the server (a client may not set it).
-- A pick fires ReplicatedStorage.CameraSetting:FireServer(type, mode); the on-screen button's on / off fires
--   CameraSetting("button", off).
-- UI (PC and phone together):
--   * Camera button: ScreenGui "CameraButton" (DisplayOrder 6, ResetOnSpawn false; ScreenInsets / IgnoreGuiInset copied
--     from ArenaStatus): a round 44 px button (PANEL rgb(20, 20, 26) at 0.18, white stroke 0.5 / 1.5 px) with the mode's
--     icon, the mode's name under it (GothamBlack 10, white, dark text stroke); right edge = ArenaStatus's MENU pill's
--     right edge, top = its bottom + 8 (followed every 0.25 s); shown only while that pill shows, InMenu ~= true and the
--     button is on (player attribute CameraButtonOff ~= true). A tap cycles Classic -> Shift Lock -> Shoulder (PC: with
--     Left Alt held while the mouse is locked, like SKILLS).
--   * MENU card: when ArenaStatus opens ScreenGui "LeaveConfirm", a "CameraSection" (LayoutOrder 0, above "Leave the
--     island?") is added to its Card: "CAMERA" (volt), three tiles (icon + name; the one in use yellow stroke / text) and
--     "Camera button on screen" with an ON / OFF pill, then a divider.
--   * SETTINGS: a "SETTINGS" pill left of the main menu's MUSIC pill (a clone of its look, following its size and place);
--     a tap opens ScreenGui "CameraSettingsCard" (DisplayOrder 41): "SETTINGS" (yellow) + X, a yellow line, "CAMERA", three
--     big tiles (icon, name, one-line description; badges PHONE DEFAULT / PC DEFAULT / IN USE), "Camera button on screen:
--     one tap cycles the three" + ON / OFF, and a footnote. UIScale = clamp(screen height / 640, 0.55, 1).
-- Switches (script attributes, read at start): CameraModesEnabled (default true; false = nothing set, no UI: Shoulder
--   everywhere as before), CameraModesButtonEnabled, CameraModesMenuCardEnabled, CameraModesSettingsEnabled (default true).
-- Diagnostics: script CameraModesVersion; player attributes (this client) CameraModeNow, CameraModeKind ("touch" /
--   "mouse"), CameraModeSource ("pick" / "saved" / "default"), CameraModesLastPress ("button:<mode>" / "card:<mode>" /
--   "settings:<mode>" / "toggle:<on|off>"), CameraButtonShown, CameraSettingsCard ("open" / "closed"), CameraMenuCardHooks,
--   CameraSettingsPill ("hooked" / "noMusic").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
script:SetAttribute("CameraModesVersion", VERSION)
for _, k in ipairs({"CameraModesEnabled", "CameraModesButtonEnabled", "CameraModesMenuCardEnabled", "CameraModesSettingsEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
if script:GetAttribute("CameraModesEnabled") == false then return end
local BUTTON_ON = script:GetAttribute("CameraModesButtonEnabled") ~= false
local MENU_CARD_ON = script:GetAttribute("CameraModesMenuCardEnabled") ~= false
local SETTINGS_ON = script:GetAttribute("CameraModesSettingsEnabled") ~= false

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PANEL = Color3.fromRGB(20, 20, 26)
local TILE = Color3.fromRGB(30, 33, 44)
local TILE_ON = Color3.fromRGB(52, 46, 22)
local YELLOW = Color3.fromRGB(255, 200, 50)
local VOLT = Color3.fromRGB(127, 233, 255)
local GREY = Color3.fromRGB(207, 211, 220)
local MUTED = Color3.fromRGB(143, 153, 170)
local WHITE = Color3.new(1, 1, 1)
local DARK_TEXT = Color3.fromRGB(27, 20, 6)
local ICON_BG = Color3.fromRGB(34, 46, 70)

local ORDER = {"classic", "shift", "shoulder"}
local NEXT = {classic = "shift", shift = "shoulder", shoulder = "classic"}
local NAMES = {classic = "CLASSIC", shift = "SHIFT LOCK", shoulder = "SHOULDER"}
local DESC = {classic = "Roblox's camera. The dino faces where it walks; drag to look around.",
	shift = "Camera centred behind. The dino always faces where you look.",
	shoulder = "Over the right shoulder, dino on the left. Q swaps sides."}
local DEFAULT = {touch = "classic", mouse = "shoulder"}
local VALID = {classic = true, shift = true, shoulder = true}

local function remote() return ReplicatedStorage:FindFirstChild("CameraSetting") end

-- ---------- state ----------
local function kind()
	if player:GetAttribute("CameraTouchTest") == true then return "touch" end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return "touch" end
	return "mouse"
end
local picks = {} -- [kind] = mode picked this session (wins over the saved value until it echoes back)
local buttonPick -- nil = the saved value
local function currentMode()
	local k = kind()
	if VALID[picks[k]] then return picks[k], "pick" end
	local saved = player:GetAttribute(k == "touch" and "CameraModeTouch" or "CameraModeMouse")
	if VALID[saved] then return saved, "saved" end
	return DEFAULT[k], "default"
end
local function buttonOff()
	if buttonPick ~= nil then return buttonPick end
	return player:GetAttribute("CameraButtonOff") == true
end

local drawers = {} -- functions redrawn on every change; [fn] = true
local function apply()
	local m, src = currentMode()
	player:SetAttribute("CameraModeNow", m)
	player:SetAttribute("CameraModeKind", kind())
	player:SetAttribute("CameraModeSource", src)
	local c = player.Character
	if c and c:GetAttribute("CameraMode") ~= m then c:SetAttribute("CameraMode", m) end
	for fn in pairs(drawers) do task.spawn(fn) end
end
local function pick(m, from)
	if not VALID[m] then return end
	local k = kind()
	picks[k] = m
	player:SetAttribute("CameraModesLastPress", from .. ":" .. m)
	local r = remote()
	if r then r:FireServer(k, m) end
	apply()
end
local function setButtonOff(off)
	buttonPick = off
	player:SetAttribute("CameraModesLastPress", "toggle:" .. (off and "off" or "on"))
	local r = remote()
	if r then r:FireServer("button", off) end
	apply()
end
for _, a in ipairs({"CameraModeTouch", "CameraModeMouse", "CameraButtonOff", "CameraTouchTest"}) do
	player:GetAttributeChangedSignal(a):Connect(apply)
end
player.CharacterAdded:Connect(function(c)
	c:SetAttribute("CameraMode", (currentMode()))
	task.defer(apply)
end)

-- ---------- shared drawing ----------
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(1, 0)
	c.Parent = p
	return c
end
local function stroke(p, color, t, th)
	local s = Instance.new("UIStroke")
	s.Color, s.Transparency, s.Thickness = color, t, th or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function label(parent, name, t, size, font, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBlack
	l.Text = t
	l.TextSize = size
	l.TextColor3 = color or WHITE
	l.Parent = parent
	return l
end
local function dot(parent, x, y, s, color, rot)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(s, s)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rot or 0
	f.Parent = parent
	return f
end
-- the mode's icon (a dino arrow and the camera) inside a round frame
local function drawIcon(holder, m)
	for _, ch in ipairs(holder:GetChildren()) do
		if ch.Name == "Art" then ch:Destroy() end
	end
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.Parent = holder
	if m == "classic" then
		local ring = dot(art, 0.5, 0.5, 0.7, ICON_BG)
		ring.BackgroundTransparency = 1
		corner(ring)
		stroke(ring, VOLT, 0.45, 1.5)
		dot(art, 0.5, 0.5, 0.26, YELLOW, 45)
		corner(dot(art, 0.82, 0.68, 0.16, VOLT))
	else
		local cx = (m == "shift") and 0.5 or 0.4
		local line = dot(art, (m == "shift") and 0.5 or 0.6, 0.45, 0.04, VOLT)
		line.Size = UDim2.fromScale(0.04, 0.6)
		line.BackgroundTransparency = 0.35
		dot(art, cx, 0.42, 0.26, YELLOW, 45)
		corner(dot(art, (m == "shift") and 0.5 or 0.6, 0.8, 0.16, VOLT), UDim.new(0.2, 0))
	end
end
local function iconHolder(parent, px)
	local h = Instance.new("Frame")
	h.Name = "Icon"
	h.Size = UDim2.fromOffset(px, px)
	h.BackgroundColor3 = ICON_BG
	h.BorderSizePixel = 0
	h.Parent = parent
	corner(h)
	return h
end
-- a pill ON / OFF toggle
local function toggle(parent, w, h)
	local b = Instance.new("TextButton")
	b.Name = "Toggle"
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(w, h)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, 0, 0.5, 0)
	b.Font = Enum.Font.GothamBlack
	b.TextSize = math.floor(h * 0.55)
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b)
	local s = stroke(b, WHITE, 0.8, 1.5)
	local function draw()
		local on = not buttonOff()
		b.Text = on and "ON" or "OFF"
		b.BackgroundColor3 = on and VOLT or TILE
		b.TextColor3 = on and DARK_TEXT or MUTED
		s.Transparency = on and 1 or 0.8
	end
	b.Activated:Connect(function() setButtonOff(not buttonOff()) end)
	return b, draw
end

-- ---------- the camera button ----------
if BUTTON_ON then
	local gui = Instance.new("ScreenGui")
	gui.Name = "CameraButton"
	gui.DisplayOrder = 6
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Parent = playerGui
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Size = UDim2.fromOffset(84, 58)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local btn = Instance.new("TextButton")
	btn.Name = "Button"
	btn.AutoButtonColor = true
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.new(1, 0, 0, 0)
	btn.Size = UDim2.fromOffset(44, 44)
	btn.BackgroundColor3 = PANEL
	btn.BackgroundTransparency = 0.18
	btn.Text = ""
	btn.Parent = holder
	corner(btn)
	stroke(btn, WHITE, 0.5, 1.5)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(32, 32)
	icon.BackgroundTransparency = 1
	icon.Parent = btn
	local name = label(holder, "Mode", "", 10)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(1, -22, 0, 46)
	name.Size = UDim2.fromOffset(84, 12)
	name.TextStrokeTransparency = 0.35
	local function draw()
		local m = currentMode()
		drawIcon(icon, m)
		name.Text = NAMES[m]
	end
	drawers[draw] = true
	btn.Activated:Connect(function()
		pick(NEXT[currentMode()], "button")
	end)
	task.spawn(function()
		while gui.Parent do
			local st = playerGui:FindFirstChild("ArenaStatus")
			local pill = st and st:FindFirstChild("Pill", true)
			local show = not buttonOff() and player:GetAttribute("InMenu") ~= true and player.Character ~= nil
				and pill ~= nil and pill.Visible and st.Enabled
			if show then
				gui.ScreenInsets = st.ScreenInsets
				gui.IgnoreGuiInset = st.IgnoreGuiInset
				local o = gui.AbsolutePosition -- AbsolutePosition is inset-relative; Position is in this gui's frame
				holder.Position = UDim2.fromOffset(pill.AbsolutePosition.X + pill.AbsoluteSize.X - o.X,
					pill.AbsolutePosition.Y + pill.AbsoluteSize.Y + 8 - o.Y)
			end
			holder.Visible = show
			if player:GetAttribute("CameraButtonShown") ~= show then player:SetAttribute("CameraButtonShown", show) end
			task.wait(0.25)
		end
	end)
end

-- ---------- tiles (MENU card and SETTINGS card) ----------
local function tiles(parent, big, from)
	local row = Instance.new("Frame")
	row.Name = "Tiles"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, big and 168 or 78)
	row.Parent = parent
	local parts = {}
	for i, m in ipairs(ORDER) do
		local t = Instance.new("TextButton")
		t.Name = "Tile_" .. m
		t.AutoButtonColor = false
		t.Text = ""
		t.Size = UDim2.new(1 / 3, -8, 1, big and -12 or 0)
		t.Position = UDim2.new((i - 1) / 3, (i - 1) * 4, 0, big and 12 or 0)
		t.BackgroundColor3 = TILE
		t.Parent = row
		corner(t, UDim.new(0, big and 14 or 10))
		local s = stroke(t, WHITE, 0.8, 2)
		local ic = iconHolder(t, big and 54 or 32)
		ic.AnchorPoint = Vector2.new(0.5, 0)
		ic.Position = UDim2.new(0.5, 0, 0, big and 14 or 8)
		local nm = label(t, "Name", NAMES[m], big and 20 or 13, Enum.Font.FredokaOne)
		nm.Position = UDim2.new(0, 4, 0, big and 72 or 46)
		nm.Size = UDim2.new(1, -8, 0, big and 24 or 18)
		nm.TextScaled = not big
		local ds
		if big then
			ds = label(t, "Desc", DESC[m], 12, Enum.Font.GothamBold, GREY)
			ds.Position = UDim2.new(0, 8, 0, 98)
			ds.Size = UDim2.new(1, -16, 1, -104)
			ds.TextWrapped = true
			ds.TextYAlignment = Enum.TextYAlignment.Top
			local badges = Instance.new("Frame")
			badges.Name = "Badges"
			badges.BackgroundTransparency = 1
			badges.AnchorPoint = Vector2.new(0.5, 0.5)
			badges.Position = UDim2.new(0.5, 0, 0, 0)
			badges.Size = UDim2.new(1, 0, 0, 18)
			badges.Parent = t
			local bl = Instance.new("UIListLayout")
			bl.FillDirection = Enum.FillDirection.Horizontal
			bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
			bl.Padding = UDim.new(0, 4)
			bl.Parent = badges
			local function badge(txt, bg)
				local b = label(badges, "Badge", txt, 10, Enum.Font.GothamBlack, DARK_TEXT)
				b.BackgroundTransparency = 0
				b.BackgroundColor3 = bg
				b.AutomaticSize = Enum.AutomaticSize.X
				b.Size = UDim2.fromOffset(0, 18)
				local p = Instance.new("UIPadding")
				p.PaddingLeft, p.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
				p.Parent = b
				corner(b, UDim.new(0, 5))
				return b
			end
			if m == DEFAULT.touch then badge("PHONE DEFAULT", VOLT) end
			if m == DEFAULT.mouse then badge("PC DEFAULT", VOLT) end
			parts[m] = {t = t, s = s, nm = nm, inUse = badge("IN USE", YELLOW)}
		else
			parts[m] = {t = t, s = s, nm = nm}
		end
		drawIcon(ic, m)
		t.Activated:Connect(function() pick(m, from) end)
	end
	local function draw()
		local cur = currentMode()
		for m, p in pairs(parts) do
			local on = m == cur
			p.t.BackgroundColor3 = on and TILE_ON or TILE
			p.s.Color = on and YELLOW or WHITE
			p.s.Transparency = on and 0 or 0.8
			p.nm.TextColor3 = on and YELLOW or WHITE
			if p.inUse then p.inUse.Visible = on end
		end
	end
	return row, draw
end

-- ---------- MENU card section ----------
if MENU_CARD_ON then
	local function inject(g)
		local card = g:FindFirstChild("Card")
		if not card or card:FindFirstChild("CameraSection") then return end
		local sec = Instance.new("Frame")
		sec.Name = "CameraSection"
		sec.BackgroundTransparency = 1
		sec.Size = UDim2.new(1, 0, 0, 0)
		sec.AutomaticSize = Enum.AutomaticSize.Y
		sec.LayoutOrder = 0
		sec.Parent = card
		local lay = Instance.new("UIListLayout")
		lay.Padding = UDim.new(0, 8)
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		lay.Parent = sec
		local head = label(sec, "Head", "CAMERA", 13, Enum.Font.GothamBlack, VOLT)
		head.Size = UDim2.new(1, 0, 0, 16)
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.LayoutOrder = 1
		local row, drawTiles = tiles(sec, false, "card")
		row.LayoutOrder = 2
		local trow = Instance.new("Frame")
		trow.Name = "ButtonRow"
		trow.BackgroundTransparency = 1
		trow.Size = UDim2.new(1, 0, 0, 30)
		trow.LayoutOrder = 3
		trow.Parent = sec
		local tl = label(trow, "Text", "Camera button on screen", 14, Enum.Font.GothamBold, GREY)
		tl.Size = UDim2.new(1, -80, 1, 0)
		tl.TextXAlignment = Enum.TextXAlignment.Left
		local _, drawToggle = toggle(trow, 70, 28)
		local line = Instance.new("Frame")
		line.Name = "Divider"
		line.Size = UDim2.new(1, 0, 0, 2)
		line.BackgroundColor3 = WHITE
		line.BackgroundTransparency = 0.85
		line.BorderSizePixel = 0
		line.LayoutOrder = 4
		line.Parent = sec
		local function draw()
			if not sec.Parent then return end
			drawTiles()
			drawToggle()
		end
		drawers[draw] = true
		g.AncestryChanged:Connect(function() if not g.Parent then drawers[draw] = nil end end)
		draw()
		player:SetAttribute("CameraMenuCardHooks", (player:GetAttribute("CameraMenuCardHooks") or 0) + 1)
	end
	playerGui.ChildAdded:Connect(function(g)
		if g.Name == "LeaveConfirm" then task.defer(inject, g) end
	end)
end

-- ---------- SETTINGS (main menu) ----------
if SETTINGS_ON then
	local cardGui
	local function closeCard()
		if cardGui then cardGui:Destroy() cardGui = nil end
		player:SetAttribute("CameraSettingsCard", "closed")
	end
	local function openCard()
		if cardGui then return end
		local g = Instance.new("ScreenGui")
		g.Name = "CameraSettingsCard"
		g.DisplayOrder = 41
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		local dim = Instance.new("TextButton")
		dim.Name = "Dim"
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundColor3 = Color3.fromRGB(5, 6, 10)
		dim.BackgroundTransparency = 0.38
		dim.Text = ""
		dim.AutoButtonColor = false
		dim.Parent = g
		dim.Activated:Connect(closeCard)
		local card = Instance.new("Frame")
		card.Name = "Card"
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.Size = UDim2.fromOffset(660, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.BackgroundColor3 = PANEL
		card.Parent = g
		corner(card, UDim.new(0, 18))
		stroke(card, WHITE, 0.84, 2)
		local scale = Instance.new("UIScale")
		scale.Parent = card
		local function rescale()
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 640)
			scale.Scale = math.clamp(math.min(vp.Y / 640, (vp.X * 0.94) / 660), 0.45, 1)
		end
		rescale()
		local pad = Instance.new("UIPadding")
		for _, k in ipairs({"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"}) do pad[k] = UDim.new(0, 22) end
		pad.Parent = card
		local lay = Instance.new("UIListLayout")
		lay.Padding = UDim.new(0, 12)
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		lay.Parent = card
		local top = Instance.new("Frame")
		top.Name = "Top"
		top.BackgroundTransparency = 1
		top.Size = UDim2.new(1, 0, 0, 40)
		top.LayoutOrder = 1
		top.Parent = card
		local title = label(top, "Title", "SETTINGS", 32, Enum.Font.FredokaOne, YELLOW)
		title.Size = UDim2.new(1, -50, 1, 0)
		title.TextXAlignment = Enum.TextXAlignment.Left
		local x = Instance.new("TextButton")
		x.Name = "Close"
		x.AnchorPoint = Vector2.new(1, 0)
		x.Position = UDim2.new(1, 0, 0, 0)
		x.Size = UDim2.fromOffset(40, 40)
		x.BackgroundColor3 = TILE
		x.Font = Enum.Font.GothamBlack
		x.Text = "X"
		x.TextSize = 18
		x.TextColor3 = WHITE
		x.Parent = top
		corner(x, UDim.new(0, 10))
		stroke(x, WHITE, 0.8, 1.5)
		x.Activated:Connect(closeCard)
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.Size = UDim2.new(1, 0, 0, 2)
		line.BackgroundColor3 = YELLOW
		line.BorderSizePixel = 0
		line.LayoutOrder = 2
		line.Parent = card
		local head = label(card, "Head", "CAMERA", 14, Enum.Font.GothamBlack, VOLT)
		head.Size = UDim2.new(1, 0, 0, 16)
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.LayoutOrder = 3
		local row, drawTiles = tiles(card, true, "settings")
		row.LayoutOrder = 4
		local trow = Instance.new("Frame")
		trow.Name = "ButtonRow"
		trow.BackgroundTransparency = 1
		trow.Size = UDim2.new(1, 0, 0, 36)
		trow.LayoutOrder = 5
		trow.Parent = card
		local tl = label(trow, "Text", "Camera button on screen: one tap cycles the three", 15, Enum.Font.GothamBold, WHITE)
		tl.Size = UDim2.new(1, -100, 1, 0)
		tl.TextXAlignment = Enum.TextXAlignment.Left
		tl.TextWrapped = true
		local _, drawToggle = toggle(trow, 84, 34)
		local foot = label(card, "Foot", "Saved to your account (like MUSIC), one choice for phones and one for PC.", 12,
			Enum.Font.GothamBold, MUTED)
		foot.Size = UDim2.new(1, 0, 0, 16)
		foot.TextWrapped = true
		foot.LayoutOrder = 6
		local function draw()
			if not card.Parent then return end
			drawTiles()
			drawToggle()
		end
		drawers[draw] = true
		g.AncestryChanged:Connect(function() if not g.Parent then drawers[draw] = nil end end)
		draw()
		g.Parent = playerGui
		cardGui = g
		player:SetAttribute("CameraSettingsCard", "open")
	end

	local function hookMenu(mg)
		local music
		for _ = 1, 40 do
			music = mg:FindFirstChild("Music", true)
			if music then break end
			task.wait(0.25)
		end
		if not (music and music:IsA("TextButton")) then
			player:SetAttribute("CameraSettingsPill", "noMusic")
			return
		end
		if music.Parent:FindFirstChild("CameraSettingsPill") then return end
		local sb = music:Clone()
		sb.Name = "CameraSettingsPill"
		sb.Text = "SETTINGS"
		sb.TextColor3 = WHITE
		sb.Parent = music.Parent
		local function follow()
			sb.AnchorPoint = music.AnchorPoint
			sb.Size = music.Size
			sb.TextSize = music.TextSize
			sb.Visible = music.Visible
			local gap = math.max(6, music.AbsoluteSize.Y * 0.25)
			sb.Position = music.Position - UDim2.fromOffset(music.AbsoluteSize.X + gap, 0)
			local mp, sp = music:FindFirstChildOfClass("UIPadding"), sb:FindFirstChildOfClass("UIPadding")
			if mp and sp then sp.PaddingLeft, sp.PaddingRight = mp.PaddingLeft, mp.PaddingRight end
			local mc, sc = music:FindFirstChildOfClass("UICorner"), sb:FindFirstChildOfClass("UICorner")
			if mc and sc then sc.CornerRadius = mc.CornerRadius end
		end
		for _, prop in ipairs({"AbsoluteSize", "Position", "Visible", "TextSize", "AnchorPoint"}) do
			music:GetPropertyChangedSignal(prop):Connect(follow)
		end
		follow()
		sb.Activated:Connect(openCard)
		player:SetAttribute("CameraSettingsPill", "hooked")
	end
	playerGui.ChildAdded:Connect(function(g)
		if g.Name == "MainMenu" then task.spawn(hookMenu, g) end
	end)
	local mg = playerGui:FindFirstChild("MainMenu")
	if mg then task.spawn(hookMenu, mg) end
	player:GetAttributeChangedSignal("InMenu"):Connect(function()
		if player:GetAttribute("InMenu") ~= true then closeCard() end
	end)
end

apply()
