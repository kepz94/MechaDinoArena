-- ClassCard v1.0 (Mecha Dino Arena) — the stat card under the species picker (LocalScript, player's own character).
-- MDA-4, plan docs/plans/CLASSSTATS_v1.0.md Task 4, ADR-001, mockup docs/mockups/class_stats_options.html (option C).
-- Shows what StatServer 1.0 publishes on the character: species name + class badge (StatClass), 5 rows Health / Attack /
--   Defense / Speed / Support (10 pips = the species' starting points in the stat colour, then gold "+N" for added points
--   when N > 0, then the value: "<MaxHealth> HP", "bite <BiteDamage>", "takes x<StatDamageTakenMul>", "<walk> / <run>",
--   "—"), the species abilities (StatAbilities) and 2 outline chips "Mecha skill · from trees" (Roblox strokes have no
--   dashes, so the mockup's dashed chips are outline-only with muted text). The Support row is at 0.45 transparency.
-- Layout: ScreenGui "ClassCard", DisplayOrder 6, holder at (16, 112) px (under SpeciesPicker's row at (16, 64), 40 high),
--   width 300, dark panel (20, 20, 26) at 0.14, white stroke 0.5, corner 12, FredokaOne.
-- Collapse (red-team #5): full for ClassCardFullTime s (character attribute, default 8) from when the card first appears
--   (StatState set) after spawn, then header only
--   (name, badge, arrow); clicking / tapping the header toggles full <-> collapsed and cancels the timer. The arrow is
--   text "+" while collapsed and "-" while full (measured in Play: FredokaOne draws "▸" / "▾" blank, and a rotated ">"
--   in the header rendered unrotated). Viewport
--   narrower than NARROW_WIDTH (900, the GoalTracker 1.0 breakpoint) -> starts collapsed, so the full card never covers
--   the goal tracker on phones unless the player opens it.
-- Character attribute ClassCardEnabled (default true): false hides the card.
-- Diagnostics (character attributes, this client): ClassCardVersion, ClassCardState ("waiting" until StatState is set,
--   "noSheet", "hidden", "full", "collapsed").
local Players = game:GetService("Players")

local VERSION = "1.0"
local NARROW_WIDTH = 900
local WIDTH, PAD = 300, 12
local STATS = {"Health", "Attack", "Defense", "Speed", "Support"}
local STAT_COLOR = {
	Health = Color3.fromRGB(95, 209, 106), Attack = Color3.fromRGB(235, 85, 60), Defense = Color3.fromRGB(92, 190, 255),
	Speed = Color3.fromRGB(155, 227, 90), Support = Color3.fromRGB(124, 224, 195),
}
local CLASS_COLOR = {
	Bulky = Color3.fromRGB(92, 190, 255), Roamer = Color3.fromRGB(155, 227, 90), Assault = Color3.fromRGB(235, 85, 60),
	Vanguard = Color3.fromRGB(255, 176, 66), Healer = Color3.fromRGB(124, 224, 195),
}
local NAMES = {TRex = "T-REX", Raptor = "RAPTOR"}
local GOLD = Color3.fromRGB(255, 226, 122)
local PANEL = Color3.fromRGB(20, 20, 26)
local CHIP = Color3.fromRGB(43, 43, 53)
local PIP_OFF = Color3.fromRGB(43, 43, 53)

local char = script.Parent
local player = Players.LocalPlayer
local hum = char:WaitForChild("Humanoid", 10)
char:SetAttribute("ClassCardVersion", VERSION)
char:SetAttribute("ClassCardState", "waiting")

local old = player:WaitForChild("PlayerGui"):FindFirstChild("ClassCard")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "ClassCard"
gui.ResetOnSpawn = true
gui.DisplayOrder = 6
gui.Enabled = false

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end
local function stroke(parent, t)
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(1, 1, 1)
	s.Transparency = t
	s.Thickness = 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end
local function label(parent, text, size, xAlign)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end
local function list(parent, dir, pad)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir
	l.Padding = UDim.new(0, pad)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = parent
	return l
end

local holder = Instance.new("Frame")
holder.Name = "Card"
holder.Position = UDim2.fromOffset(16, 112)
holder.Size = UDim2.fromOffset(WIDTH, 0)
holder.AutomaticSize = Enum.AutomaticSize.Y
holder.BackgroundColor3 = PANEL
holder.BackgroundTransparency = 0.14
holder.Parent = gui
corner(holder, 12)
stroke(holder, 0.5)
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, PAD), UDim.new(0, PAD)
padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
padding.Parent = holder
local vlist = list(holder, Enum.FillDirection.Vertical, 6)
vlist.VerticalAlignment = Enum.VerticalAlignment.Top

-- header (a button: toggles full / collapsed)
local head = Instance.new("TextButton")
head.Name = "Header"
head.LayoutOrder = 1
head.Size = UDim2.new(1, 0, 0, 28)
head.BackgroundTransparency = 1
head.Text = ""
head.AutoButtonColor = false
head.Parent = holder
list(head, Enum.FillDirection.Horizontal, 8)
local nameL = label(head, "", 20)
nameL.LayoutOrder = 1
nameL.AutomaticSize = Enum.AutomaticSize.X
nameL.Size = UDim2.new(0, 0, 1, 0)
local badge = Instance.new("TextLabel")
badge.LayoutOrder = 2
badge.Font = Enum.Font.FredokaOne
badge.TextSize = 12
badge.TextColor3 = Color3.fromRGB(17, 17, 17)
badge.AutomaticSize = Enum.AutomaticSize.X
badge.Size = UDim2.fromOffset(0, 20)
badge.Parent = head
corner(badge, 10)
local bpad = Instance.new("UIPadding")
bpad.PaddingLeft, bpad.PaddingRight = UDim.new(0, 9), UDim.new(0, 9)
bpad.Parent = badge
local arrow = label(head, "-", 18)
arrow.TextXAlignment = Enum.TextXAlignment.Center
arrow.LayoutOrder = 3
arrow.Size = UDim2.fromOffset(16, 28)

-- body
local body = Instance.new("Frame")
body.Name = "Body"
body.LayoutOrder = 2
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, 0, 0, 0)
body.AutomaticSize = Enum.AutomaticSize.Y
body.Parent = holder
list(body, Enum.FillDirection.Vertical, 4).VerticalAlignment = Enum.VerticalAlignment.Top

local rows = {}
for i, s in ipairs(STATS) do
	local row = Instance.new("CanvasGroup")
	row.Name = s
	row.LayoutOrder = i
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 20)
	row.GroupTransparency = s == "Support" and 0.45 or 0
	row.Parent = body
	local lab = label(row, s, 14)
	lab.Size = UDim2.fromOffset(56, 20)
	local pips = Instance.new("Frame")
	pips.BackgroundTransparency = 1
	pips.Position = UDim2.fromOffset(60, 5)
	pips.Size = UDim2.fromOffset(108, 10)
	pips.Parent = row
	local pipList = {}
	for j = 1, 10 do
		local p = Instance.new("Frame")
		p.BorderSizePixel = 0
		p.Position = UDim2.fromOffset((j - 1) * 11, 0)
		p.Size = UDim2.fromOffset(9, 10)
		p.BackgroundColor3 = PIP_OFF
		p.Parent = pips
		corner(p, 3)
		pipList[j] = p
	end
	local plus = label(row, "", 12)
	plus.Position = UDim2.fromOffset(170, 0)
	plus.Size = UDim2.fromOffset(24, 20)
	plus.TextColor3 = GOLD
	local val = label(row, "", 13, Enum.TextXAlignment.Right)
	val.Position = UDim2.fromOffset(196, 0)
	val.Size = UDim2.new(1, -196, 0, 20)
	rows[s] = {pips = pipList, plus = plus, val = val}
end

local chips = Instance.new("Frame")
chips.Name = "Abilities"
chips.LayoutOrder = 10
chips.BackgroundTransparency = 1
chips.Size = UDim2.new(1, 0, 0, 0)
chips.AutomaticSize = Enum.AutomaticSize.Y
chips.Parent = body
local chipList = list(chips, Enum.FillDirection.Horizontal, 6)
chipList.Wraps = true
chipList.VerticalAlignment = Enum.VerticalAlignment.Top
local chipTop = Instance.new("UIPadding")
chipTop.PaddingTop = UDim.new(0, 6)
chipTop.Parent = chips

local function chip(text, mecha, order)
	local c = label(chips, text, 12)
	c.LayoutOrder = order
	c.AutomaticSize = Enum.AutomaticSize.X
	c.Size = UDim2.fromOffset(0, 22)
	c.BackgroundColor3 = CHIP
	c.BackgroundTransparency = mecha and 1 or 0
	c.TextTransparency = mecha and 0.45 or 0
	corner(c, 8)
	stroke(c, mecha and 0.55 or 0.85)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	p.Parent = c
	return c
end

local function fmt(n)
	if type(n) ~= "number" then return "?" end
	if math.abs(n - math.floor(n + 0.5)) < 1e-6 then return tostring(math.floor(n + 0.5)) end
	return string.format("%.1f", n)
end

local abilitiesShown = nil
local function refresh()
	local species = char:GetAttribute("Species")
	nameL.Text = NAMES[species] or tostring(species or "?")
	local cls = char:GetAttribute("StatClass")
	badge.Text = string.upper(tostring(cls or "?"))
	badge.BackgroundColor3 = CLASS_COLOR[cls] or Color3.fromRGB(180, 180, 180)
	for _, s in ipairs(STATS) do
		local r = rows[s]
		local total = char:GetAttribute("StatPoints_" .. s) or 0
		local added = char:GetAttribute("StatAdded_" .. s) or 0
		local start = math.clamp(total - added, 0, 10)
		for j = 1, 10 do r.pips[j].BackgroundColor3 = j <= start and STAT_COLOR[s] or PIP_OFF end
		r.plus.Text = added > 0 and ("+" .. added) or ""
	end
	rows.Health.val.Text = (hum and fmt(hum.MaxHealth) or "?") .. " HP"
	rows.Attack.val.Text = "bite " .. fmt(char:GetAttribute("BiteDamage"))
	rows.Defense.val.Text = "takes ×" .. string.format("%.2f", char:GetAttribute("StatDamageTakenMul") or 1)
	rows.Speed.val.Text = fmt(char:GetAttribute("MoveWalkSpeed")) .. " / " .. fmt(char:GetAttribute("MoveRunSpeed"))
	rows.Support.val.Text = "—"
	local abil = char:GetAttribute("StatAbilities") or ""
	if abil ~= abilitiesShown then
		abilitiesShown = abil
		for _, c in ipairs(chips:GetChildren()) do
			if c:IsA("TextLabel") then c:Destroy() end
		end
		local n = 0
		for a in string.gmatch(abil, "[^,]+") do
			n += 1
			chip(a, false, n)
		end
		chip("Mecha skill · from trees", true, n + 1)
		chip("Mecha skill · from trees", true, n + 2)
	end
end

-- visibility + collapse
local full = true
local timerToken = 0
local shownOnce = false
local show
local function startTimer()
	timerToken += 1
	local token = timerToken
	local t = char:GetAttribute("ClassCardFullTime")
	if type(t) ~= "number" then t = 8 end
	task.delay(t, function()
		if timerToken == token and full then
			full = false
			show()
		end
	end)
end
function show()
	local enabled = char:GetAttribute("ClassCardEnabled") ~= false
	local st = char:GetAttribute("StatState")
	if st == nil or st == "waiting" then
		gui.Enabled = false
		char:SetAttribute("ClassCardState", "waiting")
		return
	end
	if st == "noSheet" then
		gui.Enabled = false
		char:SetAttribute("ClassCardState", "noSheet")
		return
	end
	if not enabled then
		gui.Enabled = false
		char:SetAttribute("ClassCardState", "hidden")
		return
	end
	gui.Enabled = true
	if not shownOnce then -- the full-time countdown starts when the card first appears
		shownOnce = true
		if full then startTimer() end
	end
	body.Visible = full
	arrow.Text = full and "-" or "+"
	char:SetAttribute("ClassCardState", full and "full" or "collapsed")
end

head.Activated:Connect(function()
	timerToken += 1 -- cancels the 8 s timer
	full = not full
	show()
end)

local cam = workspace.CurrentCamera
local narrow = cam and cam.ViewportSize.X < NARROW_WIDTH
full = not narrow

local WATCH = {Species = true, StatClass = true, StatAbilities = true, StatDamageTakenMul = true, BiteDamage = true,
	MoveWalkSpeed = true, MoveRunSpeed = true, StatState = true, ClassCardEnabled = true}
char.AttributeChanged:Connect(function(name)
	if WATCH[name] or string.sub(name, 1, 10) == "StatPoints" or string.sub(name, 1, 9) == "StatAdded" then
		refresh()
		if name == "StatState" or name == "ClassCardEnabled" then show() end
	end
end)
if hum then hum:GetPropertyChangedSignal("MaxHealth"):Connect(refresh) end

gui.Parent = player.PlayerGui
refresh()
show()
