-- ArenaStatus v1.8 (Mecha Dino Arena) — top-right status for the player's own dino (LocalScript, all devices).
-- MDA-6, plan docs/plans/ARENAHUD_v1.0.md Task 1, mockup docs/mockups/mobile_hud_options.html option A (Kepu 2026-10-28:
--   "health should be at the top right of the screen along with the T-Rex drop down list"; stamina bar only while latched).
-- Replaces HealthBar 1.1 / SpeciesPicker 1.0 / StaminaBar 1.1 in Mecha (those are switched off by Arena scope 1.1).
-- Pill: AnchorPoint (1, 0) at (1, -16, 0, 12): yellow species tag ("T-REX" / "RAPTOR") + "v". Tapping it opens the menu
--   under it (one row per species, the current one yellow); tapping the other species fires
--   ReplicatedStorage.DinoSpeciesRequest:FireServer(species) (SpeciesServer 1.0 respawns; 2 s cooldown there) and closes
--   the menu; tapping the pill again closes it. The menu also closes on respawn (ResetOnSpawn).
-- Health: AnchorPoint (1, 0) at (1, -16, 0, 58), width 27% of the screen clamped to 200..320 px; "HEALTH" / "h / max";
--   green bar, red below LOW_FRACTION (0.3) of max; Health / MaxHealth changes.
-- Stamina: under health (y 96), same width, only while PounceLatched == true: "STAMINA" / "LATCHED", value each frame
--   = clamp(StaminaValue + StaminaRate x (server now - StaminaAt), 0, StaminaMax) (StaminaServer 1.x attributes, the same
--   formula StaminaBar 1.1 draws).
-- Diagnostics (character attributes, this client): ArenaStatusVersion, ArenaStatusMenu ("closed" / "open"),
--   ArenaStatusLastPick (species sent), ArenaStatusStamina ("shown" / "hidden").
-- v1.1 (skill trees, MDA-16, Kepu: the overheal shield shows "inside the health bar"): while the character's SkillShield
--   (SkillEffects 1.0, Lifesteal star) is above 0, a blue (90, 160, 255) section SkillShield / MaxHealth of the bar wide
--   is drawn in the health bar: right after the green fill, moved left just enough to stay inside the bar (the shield
--   fills while health is full, so it then sits over the right end of the green); the label reads "h / max +s". At 0
--   it hides. Character attribute ArenaStatusShieldEnabled (default true; false = 1.0). Diagnostic ArenaStatusShield
--   ("shown" / "hidden").
-- v1.2 (Main Menu, MDA-91, plan docs/plans/MAIN_MENU_v1.0.md Task 7, mockup docs/mockups/main_menu_options.html; Kepu
--   2026-10-29: "MENU button replaces the dino pill"): the pill keeps its place and look but reads "MENU" (no "v") and a tap
--   fires ReplicatedStorage.DinoModeRequest:FireServer("menu") (ModeServer 1.0 parks the dino and MainMenu 1.0 opens;
--   dinos are switched there). The species drop-down is not opened. Script attribute ArenaMenuButtonEnabled (default true;
--   false, or no DinoModeRequest, = the 1.1 species pill). Diagnostic: ArenaStatusLastPick "menu". PC: the M key does the
--   same (ShoulderCam keeps the mouse locked to the centre, so the pill is only clickable while Left Alt is held), like K
--   for SKILLS; typing in chat does not trigger it.
-- v1.3 (Kepu 2026-10-29: "my healthy and stamina can go bottom left of the screen"; mockup
--   docs/mockups/hud_target_slash_options.html option A "Bottom-left edge, slim"): the health and stamina bars move into a
--   frame "BarsBL" at the bottom-left edge, under the phone thumb area: AnchorPoint (0, 1) at (0, 16, 1, -8), width 36% of
--   the screen clamped to 200..340 px, a vertical list from the bottom: HEALTH then STAMINA under it (stamina still only
--   while latched; with it hidden, health sits on the bottom edge). Slim: labels 12 px (row 14 px), bars 10 px (health) /
--   8 px (stamina), 3 px between label and bar, 4 px between the two blocks. Colours, texts, shield and values as 1.2. The
--   MENU pill stays top right. Script attribute ArenaStatusBottomLeftEnabled (default true; false = the 1.2 top-right
--   bars). Diagnostic: character ArenaStatusLayout ("bottomLeft" / "topRight").
-- v1.4 (Kepu 2026-10-30: "move the menu and skills to the top right of the screen it's floating mid right. Also ask for a
--   confirmation when clicking menu button because it will kick you out the lobby"; mockup
--   docs/mockups/menu_corner_confirm_options.html, pick A "Centre card"):
--   * corner: the ScreenGui uses ScreenInsets DeviceSafeInsets (the whole screen except the phone's notch / rounded
--     corners; 1.3 used the default CoreUISafeInsets, which starts under Roblox's top bar) and the MENU pill sits at
--     (1, -16, 0, CORNER_Y (8)). The bottom-left bars keep their place. Script attribute ArenaCornerEnabled (default true,
--     read at start; false = 1.3 placement). Diagnostic: character ArenaStatusCorner (true / false).
--   * leave check: a MENU tap (or the M key) opens ScreenGui "LeaveConfirm" (DisplayOrder 30, full screen) instead of
--     leaving: a dark full-screen dim and a centre card (width 80% of the screen, at most 340 px): "Leave the island?",
--     "You'll go back to the main menu.", buttons STAY (dark) and LEAVE (yellow). LEAVE = the 1.2 action
--     (DinoModeRequest "menu", ArenaStatusLastPick "menu"); STAY or a tap on the dim closes it. While it is open the PC
--     mouse is free (RenderStep "LeaveConfirmMouse", Camera + 1). It closes with the character (ResetOnSpawn). The game
--     keeps running behind it. Script attribute ArenaLeaveConfirmEnabled (default true; false = 1.2, MENU leaves at once).
--     Diagnostics: character ArenaLeaveConfirm ("open" / "stay" / "leave"), ArenaLeaveAsks (count).
-- v1.5 (MDA-118, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 9): SPECIES gains {id = "Pachy", label = "PACHY"} (used by
--   the 1.0 species menu and the status tag when the MENU pill is off).
-- v1.6 (pachy Blood Rush, MDA-124, mockup docs/mockups/pachy_sacrifice_options.html "C · Both"): while a sacrifice is
--   ready (BloodRushEnabled, HeadbuttChargesNow 0, health above half, HeadbuttSacrifices < BloodRushMax) the health bar
--   shows the health the next press takes: a red (224, 40, 74) chunk from max(1, h - BloodRushCost x max) to h, its
--   transparency pulsing 0.05 .. 0.45 (0.8 s), and a thin white mark at half the bar. Hidden otherwise. Switch: script
--   attribute ArenaStatusBloodEnabled (default true, read at start). Diagnostic: character ArenaStatusBlood
--   ("shown" / "hidden").
-- v1.7 (Kepu 2026-10-30: "I'm sacrificing health on my 3rd head rush. It shouldn't be sacrificed till I press the 4th";
--   the server only takes health on the press at 0 charges, the solid red chunk over the green read as health already
--   gone; answer "Outline only"): the BloodCost chunk has no fill (BackgroundTransparency 1) and a red (224, 40, 74)
--   UIStroke "BloodCostOutline" (2 px) whose transparency pulses 0.05 .. 0.45 (0.8 s), so the green under it stays
--   visible; the half mark is unchanged. Switch: script attribute ArenaStatusBloodOutline (default true, read at start;
--   false = 1.6 solid chunk).
-- v1.8 (Kepu 2026-10-30: "fix the preview to make it more obvious"; mockup docs/mockups/pachy_bloodrush_preview_options.html,
--   picked "A · Hatched + tag"): with the 1.7 outline on, the outline is 3 px; a Frame "BloodCostStripes" (ClipsDescendants)
--   fills the chunk with red (224, 40, 74) diagonal stripes drawn as steps of small squares (4 rows of a quarter of the bar
--   height, 4 px wide, each row 4 px further left, a stripe every 9 px; Studio: rotated stripes are not clipped, steps
--   are), so the green shows between them; a red tag "BloodCostTag" just right of the health bar reads "NEXT -<HP the
--   press takes>" with a pointer to the bar (the bar sits at the screen's bottom edge, so under it is off screen).
--   Stripes and outline pulse together (0.05 .. 0.45, 0.8 s); the tag stays solid and shows only with the preview.
--   Switch: script attribute ArenaStatusBloodHatched (default true, read at start; false = 1.7 outline only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.8"
local CORNER_Y = 8 -- v1.4
local SHIELD = Color3.fromRGB(90, 160, 255) -- v1.1
local LOW_FRACTION = 0.3
local SPECIES = {{id = "TRex", label = "T-REX"}, {id = "Raptor", label = "RAPTOR"}}
table.insert(SPECIES, {id = "Pachy", label = "PACHY"}) -- v1.5
local PANEL = Color3.fromRGB(20, 20, 26)
local YELLOW, YELLOW_TEXT = Color3.fromRGB(255, 200, 50), Color3.fromRGB(30, 26, 10)
local GREEN_A, GREEN_B = Color3.fromRGB(95, 209, 106), Color3.fromRGB(63, 174, 75)
local RED_A, RED_B = Color3.fromRGB(240, 90, 79), Color3.fromRGB(201, 47, 38)
local STAM_A, STAM_B = Color3.fromRGB(255, 211, 77), Color3.fromRGB(255, 155, 46)
local BACK = Color3.fromRGB(20, 20, 26)

local char = script.Parent
local player = Players.LocalPlayer
local hum = char:WaitForChild("Humanoid", 10)
local remote = ReplicatedStorage:WaitForChild("DinoSpeciesRequest", 10)
char:SetAttribute("ArenaStatusVersion", VERSION)

local old = player:WaitForChild("PlayerGui"):FindFirstChild("ArenaStatus")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "ArenaStatus"
gui.ResetOnSpawn = true
gui.DisplayOrder = 6

local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = p end
local function stroke(p, t, th)
	local s = Instance.new("UIStroke")
	s.Color, s.Transparency, s.Thickness = Color3.new(1, 1, 1), t, th or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
end
local function text(parent, t, size, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.Text, l.TextSize = t, size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.6
	l.Parent = parent
	return l
end

-- pill
local pill = Instance.new("TextButton")
pill.Name = "Pill"
pill.AnchorPoint = Vector2.new(1, 0)
pill.Position = UDim2.new(1, -16, 0, 12)
pill.Size = UDim2.fromOffset(0, 36)
pill.AutomaticSize = Enum.AutomaticSize.X
pill.BackgroundColor3 = PANEL
pill.BackgroundTransparency = 0.18
pill.Text = ""
pill.AutoButtonColor = false
pill.Parent = gui
corner(pill, 10)
stroke(pill, 0.5)
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 10)
pad.Parent = pill
local row = Instance.new("UIListLayout")
row.FillDirection = Enum.FillDirection.Horizontal
row.VerticalAlignment = Enum.VerticalAlignment.Center
row.Padding = UDim.new(0, 8)
row.SortOrder = Enum.SortOrder.LayoutOrder
row.Parent = pill
local tag = text(pill, "", 18, Enum.TextXAlignment.Center)
tag.LayoutOrder = 1
tag.AutomaticSize = Enum.AutomaticSize.X
tag.Size = UDim2.fromOffset(0, 26)
tag.BackgroundTransparency = 0
tag.BackgroundColor3 = YELLOW
tag.TextColor3 = YELLOW_TEXT
tag.TextStrokeTransparency = 1
corner(tag, 7)
local tpad = Instance.new("UIPadding")
tpad.PaddingLeft, tpad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
tpad.Parent = tag
local caret = text(pill, "v", 16, Enum.TextXAlignment.Center)
caret.LayoutOrder = 2
caret.Size = UDim2.fromOffset(12, 26)

-- menu
local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.AnchorPoint = Vector2.new(1, 0)
menu.Position = UDim2.new(1, -16, 0, 54)
menu.Size = UDim2.fromOffset(150, 0)
menu.AutomaticSize = Enum.AutomaticSize.Y
menu.BackgroundColor3 = PANEL
menu.BackgroundTransparency = 0.12
menu.Visible = false
menu.ZIndex = 5
menu.Parent = gui
corner(menu, 10)
stroke(menu, 0.5)
local mpad = Instance.new("UIPadding")
for _, k in ipairs({"PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom"}) do mpad[k] = UDim.new(0, 5) end
mpad.Parent = menu
local mlist = Instance.new("UIListLayout")
mlist.Padding = UDim.new(0, 4)
mlist.SortOrder = Enum.SortOrder.LayoutOrder
mlist.Parent = menu

local current = char:GetAttribute("Species") or "TRex"
local function setMenu(open)
	menu.Visible = open
	char:SetAttribute("ArenaStatusMenu", open and "open" or "closed")
end
for i, s in ipairs(SPECIES) do
	local b = Instance.new("TextButton")
	b.Name = s.id
	b.LayoutOrder = i
	b.Size = UDim2.new(1, 0, 0, 32)
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 17
	b.Text = s.label
	b.AutoButtonColor = s.id ~= current
	b.BackgroundColor3 = s.id == current and YELLOW or PANEL
	b.BackgroundTransparency = s.id == current and 0 or 1
	b.TextColor3 = s.id == current and YELLOW_TEXT or Color3.new(1, 1, 1)
	b.ZIndex = 6
	b.Parent = menu
	corner(b, 7)
	b.Activated:Connect(function()
		setMenu(false)
		if s.id == current then return end
		if remote then remote:FireServer(s.id) end
		char:SetAttribute("ArenaStatusLastPick", s.id)
	end)
end
-- v1.2: MENU button
if script:GetAttribute("ArenaMenuButtonEnabled") == nil then script:SetAttribute("ArenaMenuButtonEnabled", true) end
local modeRemote = ReplicatedStorage:FindFirstChild("DinoModeRequest")
local menuButton = script:GetAttribute("ArenaMenuButtonEnabled") ~= false and modeRemote ~= nil
if menuButton then caret.Visible = false end
-- v1.4: top-right corner + leave check
if script:GetAttribute("ArenaCornerEnabled") == nil then script:SetAttribute("ArenaCornerEnabled", true) end
if script:GetAttribute("ArenaLeaveConfirmEnabled") == nil then script:SetAttribute("ArenaLeaveConfirmEnabled", true) end
local cornerOn = script:GetAttribute("ArenaCornerEnabled") ~= false
if cornerOn then
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	pill.Position = UDim2.new(1, -16, 0, CORNER_Y)
end
char:SetAttribute("ArenaStatusCorner", cornerOn)
local confirmGui
local CONFIRM_BIND = "LeaveConfirmMouse"
local function closeConfirm(how)
	if confirmGui then confirmGui:Destroy() confirmGui = nil end
	pcall(function() RunService:UnbindFromRenderStep(CONFIRM_BIND) end)
	if how then char:SetAttribute("ArenaLeaveConfirm", how) end
end
local function leaveNow()
	char:SetAttribute("ArenaStatusLastPick", "menu")
	modeRemote:FireServer("menu")
end
local function askLeave()
	if script:GetAttribute("ArenaLeaveConfirmEnabled") == false then leaveNow() return end
	if confirmGui then return end
	local g = Instance.new("ScreenGui")
	g.Name = "LeaveConfirm"
	g.DisplayOrder = 30
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = true
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Parent = g
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(0.8, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = PANEL
	card.Parent = g
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(340, math.huge)
	lim.Parent = card
	corner(card, 16)
	stroke(card, 0.7, 2)
	local pad = Instance.new("UIPadding")
	for _, k in ipairs({"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"}) do pad[k] = UDim.new(0, 18) end
	pad.Parent = card
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 12)
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = card
	local function text(name, t, size, font, color, order)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, size + 6)
		l.Font = font
		l.Text = t
		l.TextSize = size
		l.TextColor3 = color
		l.TextWrapped = true
		l.LayoutOrder = order
		l.Parent = card
	end
	text("Title", "Leave the island?", 26, Enum.Font.FredokaOne, Color3.new(1, 1, 1), 1)
	text("Body", "You'll go back to the main menu.", 16, Enum.Font.GothamBold, Color3.fromRGB(207, 211, 220), 2)
	local row = Instance.new("Frame")
	row.Name = "Buttons"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 48)
	row.LayoutOrder = 3
	row.Parent = card
	local function btn(name, t, bg, fg, x)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0)
		b.Size = UDim2.new(0.5, -6, 1, 0)
		b.BackgroundColor3 = bg
		b.Font = Enum.Font.FredokaOne
		b.Text = t
		b.TextSize = 22
		b.TextColor3 = fg
		b.Parent = row
		corner(b, 12)
		stroke(b, 0.6, 2)
		return b
	end
	local stay = btn("Stay", "STAY", Color3.fromRGB(34, 36, 46), Color3.new(1, 1, 1), 0)
	local leave = btn("Leave", "LEAVE", YELLOW, YELLOW_TEXT, 0.5)
	stay.Activated:Connect(function() closeConfirm("stay") end)
	dim.Activated:Connect(function() closeConfirm("stay") end)
	leave.Activated:Connect(function()
		closeConfirm("leave")
		leaveNow()
	end)
	g.Parent = player.PlayerGui
	confirmGui = g
	char:SetAttribute("ArenaLeaveConfirm", "open")
	char:SetAttribute("ArenaLeaveAsks", (char:GetAttribute("ArenaLeaveAsks") or 0) + 1)
	RunService:BindToRenderStep(CONFIRM_BIND, Enum.RenderPriority.Camera.Value + 1, function()
		local UIS = game:GetService("UserInputService")
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	end)
end
char.AncestryChanged:Connect(function() if not char.Parent then closeConfirm() end end)
pill.Activated:Connect(function()
	if menuButton then
		askLeave() -- v1.4 (1.2 left at once)
	else
		setMenu(not menu.Visible)
	end
end)
if menuButton then
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.M then return end
		askLeave() -- v1.4 (1.2 left at once)
	end)
end
setMenu(false)

-- bars
local function barBlock(name, y, labelL, height)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(1, 0)
	f.Position = UDim2.new(1, -16, 0, y)
	f.BackgroundTransparency = 1
	f.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize, constraint.MaxSize = Vector2.new(200, 0), Vector2.new(320, math.huge)
	constraint.Parent = f
	f.Size = UDim2.new(0.27, 0, 0, height + 18)
	local l = text(f, labelL, 14)
	l.Size = UDim2.new(0.5, 0, 0, 16)
	local r = text(f, "", 14, Enum.TextXAlignment.Right)
	r.Position = UDim2.new(0.5, 0, 0, 0)
	r.Size = UDim2.new(0.5, 0, 0, 16)
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 18)
	back.Size = UDim2.new(1, 0, 0, height)
	back.BackgroundColor3 = BACK
	back.Parent = f
	corner(back, height)
	stroke(back, 0.55)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner(fill, height)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Parent = fill
	return f, r, fill, grad
end
local healthF, healthR, healthFill, healthGrad = barBlock("Health", 58, "HEALTH", 16)
local stamF, stamR, stamFill, stamGrad = barBlock("Stamina", 96, "STAMINA", 12)
-- v1.1: shield section inside the health bar
local shieldFill = Instance.new("Frame")
shieldFill.Name = "Shield"
shieldFill.BackgroundColor3 = SHIELD
shieldFill.BorderSizePixel = 0
shieldFill.Visible = false
shieldFill.ZIndex = 2
shieldFill.Parent = healthFill.Parent
corner(shieldFill, 16)
-- v1.3: bottom-left edge, slim
if script:GetAttribute("ArenaStatusBottomLeftEnabled") == nil then script:SetAttribute("ArenaStatusBottomLeftEnabled", true) end
if script:GetAttribute("ArenaStatusBottomLeftEnabled") ~= false then
	local holder = Instance.new("Frame")
	holder.Name = "BarsBL"
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, 16, 1, -8)
	holder.Size = UDim2.new(0.36, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local hc = Instance.new("UISizeConstraint")
	hc.MinSize, hc.MaxSize = Vector2.new(200, 0), Vector2.new(340, math.huge)
	hc.Parent = holder
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = holder
	local function slim(f, order, height)
		local c = f:FindFirstChildOfClass("UISizeConstraint")
		if c then c:Destroy() end
		f.LayoutOrder = order
		f.AnchorPoint = Vector2.new(0, 0)
		f.Position = UDim2.new()
		f.Size = UDim2.new(1, 0, 0, 14 + 3 + height)
		for _, ch in ipairs(f:GetChildren()) do
			if ch:IsA("TextLabel") then
				ch.TextSize = 12
				ch.Size = UDim2.new(0.5, 0, 0, 14)
			elseif ch:IsA("Frame") then -- the bar back
				ch.Position = UDim2.fromOffset(0, 17)
				ch.Size = UDim2.new(1, 0, 0, height)
				for _, k in ipairs(ch:GetDescendants()) do
					if k:IsA("UICorner") then k.CornerRadius = UDim.new(0, height) end
				end
				local c2 = ch:FindFirstChildOfClass("UICorner")
				if c2 then c2.CornerRadius = UDim.new(0, height) end
			end
		end
		f.Parent = holder
	end
	slim(healthF, 1, 10)
	slim(stamF, 2, 8)
	char:SetAttribute("ArenaStatusLayout", "bottomLeft")
else
	char:SetAttribute("ArenaStatusLayout", "topRight")
end
stamR.Text = "LATCHED"
stamGrad.Rotation = 0
stamGrad.Color = ColorSequence.new(STAM_A, STAM_B)

local function refreshHealth()
	if not hum then return end
	local max = math.max(hum.MaxHealth, 1)
	local h = math.clamp(hum.Health, 0, max)
	healthR.Text = ("%d / %d"):format(math.floor(h + 0.5), math.floor(max + 0.5))
	healthFill.Size = UDim2.fromScale(h / max, 1)
	local low = h / max < LOW_FRACTION
	healthGrad.Color = low and ColorSequence.new(RED_A, RED_B) or ColorSequence.new(GREEN_A, GREEN_B)
	-- v1.1: overheal shield
	local shield = char:GetAttribute("SkillShield")
	local on = char:GetAttribute("ArenaStatusShieldEnabled") ~= false and type(shield) == "number" and shield > 0
	if on then
		local w = math.min(shield / max, 1)
		shieldFill.Position = UDim2.fromScale(math.min(h / max, 1 - w), 0)
		shieldFill.Size = UDim2.fromScale(w, 1)
		healthR.Text ..= (" +%d"):format(math.floor(shield + 0.5))
	end
	shieldFill.Visible = on
	if char:GetAttribute("ArenaStatusShield") ~= (on and "shown" or "hidden") then
		char:SetAttribute("ArenaStatusShield", on and "shown" or "hidden")
	end
end
local function refreshSpecies()
	current = char:GetAttribute("Species") or current
	for _, s in ipairs(SPECIES) do
		if s.id == current then tag.Text = s.label end
	end
	if menuButton then tag.Text = "MENU" end -- v1.2
end

-- v1.6: Blood Rush cost preview in the health bar
if script:GetAttribute("ArenaStatusBloodEnabled") == nil then script:SetAttribute("ArenaStatusBloodEnabled", true) end
if script:GetAttribute("ArenaStatusBloodEnabled") ~= false then
	local barBack = healthFill.Parent
	local cost = Instance.new("Frame")
	cost.Name = "BloodCost"
	cost.BackgroundColor3 = Color3.fromRGB(224, 40, 74)
	cost.BorderSizePixel = 0
	cost.Visible = false
	cost.ZIndex = 3
	cost.Parent = barBack
	if script:GetAttribute("ArenaStatusBloodOutline") == nil then script:SetAttribute("ArenaStatusBloodOutline", true) end -- v1.7
	local OUTLINE = script:GetAttribute("ArenaStatusBloodOutline") ~= false
	local costStroke
	if OUTLINE then
		costStroke = Instance.new("UIStroke")
		costStroke.Name = "BloodCostOutline"
		costStroke.Color = Color3.fromRGB(224, 40, 74)
		costStroke.Thickness = 2
		costStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		costStroke.Parent = cost
	end
	if script:GetAttribute("ArenaStatusBloodHatched") == nil then script:SetAttribute("ArenaStatusBloodHatched", true) end -- v1.8
	local stripes, costTag
	if costStroke and script:GetAttribute("ArenaStatusBloodHatched") ~= false then
		costStroke.Thickness = 3
		stripes = Instance.new("Frame")
		stripes.Name = "BloodCostStripes"
		stripes.BackgroundTransparency = 1
		stripes.BorderSizePixel = 0
		stripes.ClipsDescendants = true
		stripes.Size = UDim2.fromScale(1, 1)
		stripes.ZIndex = 3
		stripes.Parent = cost
		for i = 0, 17 do
			for row = 0, 3 do
				local b = Instance.new("Frame")
				b.Name = ("Stripe%d_%d"):format(i, row)
				b.Position = UDim2.new(0, -12 + i * 9 + (3 - row) * 4, row * 0.25, 0)
				b.Size = UDim2.new(0, 4, 0.25, 0)
				b.BackgroundColor3 = Color3.fromRGB(224, 40, 74)
				b.BorderSizePixel = 0
				b.ZIndex = 3
				b.Parent = stripes
			end
		end
		costTag = Instance.new("TextLabel")
		costTag.Name = "BloodCostTag"
		costTag.AnchorPoint = Vector2.new(0, 0.5)
		costTag.Position = UDim2.new(1, 12, 0.5, 0)
		costTag.Size = UDim2.fromOffset(78, 20)
		costTag.BackgroundColor3 = Color3.fromRGB(224, 40, 74)
		costTag.BorderSizePixel = 0
		costTag.Font = Enum.Font.FredokaOne
		costTag.TextSize = 14
		costTag.TextColor3 = Color3.new(1, 1, 1)
		costTag.Text = "NEXT -22"
		costTag.Visible = false
		costTag.ZIndex = 5
		costTag.Parent = barBack
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1, 0)
		tc.Parent = costTag
		local tip = Instance.new("Frame")
		tip.Name = "Pointer"
		tip.AnchorPoint = Vector2.new(0.5, 0.5)
		tip.Position = UDim2.fromScale(0, 0.5)
		tip.Size = UDim2.fromOffset(8, 8)
		tip.Rotation = 45
		tip.BackgroundColor3 = Color3.fromRGB(224, 40, 74)
		tip.BorderSizePixel = 0
		tip.ZIndex = 4
		tip.Parent = costTag
	end
	local half = Instance.new("Frame")
	half.Name = "HalfMark"
	half.AnchorPoint = Vector2.new(0.5, 0)
	half.Position = UDim2.fromScale(0.5, 0)
	half.Size = UDim2.new(0, 2, 1, 0)
	half.BackgroundColor3 = Color3.new(1, 1, 1)
	half.BorderSizePixel = 0
	half.Visible = false
	half.ZIndex = 4
	half.Parent = barBack
	local shownState = nil
	RunService.RenderStepped:Connect(function()
		if not hum then return end
		local max = math.max(hum.MaxHealth, 1)
		local h = math.clamp(hum.Health, 0, max)
		local ready = char:GetAttribute("BloodRushEnabled") == true
			and (tonumber(char:GetAttribute("HeadbuttChargesNow")) or 1) < 1
			and h > max * 0.5
			and (tonumber(char:GetAttribute("HeadbuttSacrifices")) or 0) < (tonumber(char:GetAttribute("BloodRushMax")) or 2)
		if ready then
			local after = math.max(1, h - (tonumber(char:GetAttribute("BloodRushCost")) or 0.25) * max)
			cost.Position = UDim2.fromScale(after / max, 0)
			cost.Size = UDim2.fromScale((h - after) / max, 1)
			if costStroke then -- v1.7: outline only, the green stays visible
				cost.BackgroundTransparency = 1
				costStroke.Transparency = 0.25 + 0.2 * math.sin(os.clock() * math.pi * 2 / 0.8)
				if stripes then -- v1.8: stripes pulse with the outline, the tag names the cost
					local tr = costStroke.Transparency
					for _, b in ipairs(stripes:GetChildren()) do b.BackgroundTransparency = tr end
					costTag.Text = ("NEXT -%d"):format(math.floor(h - after + 0.5))
				end
			else
				cost.BackgroundTransparency = 0.25 + 0.2 * math.sin(os.clock() * math.pi * 2 / 0.8)
			end
		end
		cost.Visible, half.Visible = ready, ready
		if costTag then costTag.Visible = ready end -- v1.8
		local st = ready and "shown" or "hidden"
		if st ~= shownState then shownState = st; char:SetAttribute("ArenaStatusBlood", st) end
	end)
end

local stamShown = nil
RunService.RenderStepped:Connect(function()
	local latched = char:GetAttribute("PounceLatched") == true
	if latched ~= stamShown then
		stamShown = latched
		stamF.Visible = latched
		char:SetAttribute("ArenaStatusStamina", latched and "shown" or "hidden")
	end
	if latched then
		local value, at = char:GetAttribute("StaminaValue"), char:GetAttribute("StaminaAt")
		local max = char:GetAttribute("StaminaMax") or 100
		local rate = char:GetAttribute("StaminaRate") or 0
		local s = max
		if type(value) == "number" and type(at) == "number" then
			s = math.clamp(value + rate * (workspace:GetServerTimeNow() - at), 0, max)
		end
		stamFill.Size = UDim2.fromScale(max > 0 and s / max or 0, 1)
	end
end)

if hum then
	hum.HealthChanged:Connect(refreshHealth)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(refreshHealth)
end
char:GetAttributeChangedSignal("Species"):Connect(refreshSpecies)
char:GetAttributeChangedSignal("SkillShield"):Connect(refreshHealth) -- v1.1
char:GetAttributeChangedSignal("ArenaStatusShieldEnabled"):Connect(refreshHealth) -- v1.1
refreshSpecies()
refreshHealth()
gui.Parent = player.PlayerGui
