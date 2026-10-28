-- ArenaStatus v1.1 (Mecha Dino Arena) — top-right status for the player's own dino (LocalScript, all devices).
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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
local SHIELD = Color3.fromRGB(90, 160, 255) -- v1.1
local LOW_FRACTION = 0.3
local SPECIES = {{id = "TRex", label = "T-REX"}, {id = "Raptor", label = "RAPTOR"}}
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
pill.Activated:Connect(function() setMenu(not menu.Visible) end)
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
