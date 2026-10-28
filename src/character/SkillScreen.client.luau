-- SkillScreen v1.1 (Mecha Dino Arena) — the SKILLS button and the skill tree screen (LocalScript, all devices). MDA-14,
-- plan docs/plans/SKILLTREES_v1.0.md Task 4, mockup docs/mockups/skill_tree_options.html option A (Kepu's pick).
-- Data: ReplicatedStorage.SkillShared.SkillTree (copied there by SkillServer 1.0) for names, steps and costs; the
--   player's attributes (SkillServer 1.0) for everything that changes: SkillLevel, SkillXPInto, SkillXPNext, SkillLeft,
--   SkillPath_<pathId>. The screen only redraws from those; buttons fire ReplicatedStorage.SkillRequest ("buy", pathId)
--   or ("respec") and wait for the attributes to change.
-- SKILLS button: ScreenGui "SkillButton" (DisplayOrder 6, like ArenaStatus), a pill left of ArenaStatus's species pill
--   (8 px gap, same row: y 12, height 36; follows the pill's width; x -150 if the pill is missing). Text "SKILLS"; while
--   SkillLeft > 0 a yellow badge with the number. PC key K toggles the screen too.
-- Screen (option A): ScreenGui "SkillScreen" (DisplayOrder 21) over a full-screen dim (ScreenGui "SkillScreenDim",
--   DisplayOrder 20, black at 0.45, takes the touches so the camera and buttons underneath don't react). 12 px margin:
--   * top bar (34 px): "SKILLS", LV n with an XP bar and "into / next XP" ("MAX" at the cap), yellow "n PTS",
--     RESPEC, X;
--   * left rail (64 px): the 5 areas (colour dot + name), the open one outlined in its colour; buttons share the
--     rail's height (at most 46 px each, at least 30) so all 5 fit on small phones;
--   * centre: the open area's 3 paths as columns; steps I, II, III, star evenly spaced from bottom to top (38 px circles, the star a
--     rounded square, cost badge); bought = filled in the area colour, next = outlined, locked = 0.4; "soon" paths
--     are greyed with a "soon" tag;
--   * right detail panel (220 px; 30% of the width when the screen is under 700 px): name + step, "area - step n of 4 -
--     passive / mecha part", the step's text, and BUY: "BUY - n PTS" / "NEED n PTS" / "BOUGHT" / "COMING SOON" /
--     "BUY THE ONE BEFORE" (only the first is pressable).
--   RESPEC opens "Reset all points?" YES / NO first. Default selection: the first path's next step.
-- PC mouse: ShoulderCam keeps the mouse locked to the centre every frame; while the screen is open this script sets
--   MouseBehavior Default and shows the cursor right after it (RenderStep, Camera priority + 1), so the screen can be
--   clicked. Nothing else of ShoulderCam is touched.
-- Instances are named for tests and diagnostics: SkillButton.Skills; SkillScreen.Root.Top.Close / Respec;
--   Root.Body.Rail.Area_<id>; Root.Body.Cols.Col_<pathId>.Stack.Node_<n>; Root.Body.Detail.Buy; Root.Confirm.Yes / No.
-- Diagnostics (character attributes, this client): SkillScreenVersion, SkillScreenOpen, SkillScreenArea,
--   SkillScreenLastPress ("open" / "close" / "area:<id>" / "node:<pathId>:<n>" / "buy:<pathId>" / "respec" /
--   "respecYes" / "respecNo").
-- v1.1 (mecha loadout, MDA-29, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 7, mockup docs/mockups/mecha_thrusters_options.html
--   option L2 "Loadout bar"; Kepu 2026-10-28): Root.Body.Loadout, a bar under the tree (x 72, height 44, bottom of the body,
--   as wide as Cols; Cols height = body - 52): an orange "LOADOUT" label, Slot_1 / Slot_2 tiles (120 x 36; "Slot n ·
--   ⚙ <name>" with an orange stroke when full, "Slot n · empty" with a faint stroke when empty) and a hint. A tap on a
--   slot fires ("slot", n, id) with the next of the player's bought loadout parts (SkillTree.BUTTONS, steps >= 1, in tree
--   order) after the one in the slot, then empty ("") after the last; with none bought it does nothing. The slots come
--   from the player attributes SkillSlot1 / SkillSlot2 (SkillServer 1.1). Thrusters is buyable (SkillTree 1.1 soon =
--   false). The detail sub-line says "mecha button" for loadout parts (else "mecha part" / "passive").
--   Script attribute SkillScreenLoadoutEnabled (default true; false = no bar, Cols full height as 1.0).
--   Diagnostics: SkillScreenLastPress "slot:<n>:<id or empty or none>".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
local BIND = "SkillScreenMouse"
local PANEL = Color3.fromRGB(20, 20, 26)
local YELLOW, YELLOW_TEXT = Color3.fromRGB(255, 200, 50), Color3.fromRGB(30, 26, 10)
local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(207, 211, 220)

local char = script.Parent
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
char:SetAttribute("SkillScreenVersion", VERSION)
char:SetAttribute("SkillScreenOpen", false)

local shared = ReplicatedStorage:WaitForChild("SkillShared", 20)
local remote = ReplicatedStorage:WaitForChild("SkillRequest", 20)
if not shared or not remote then
	char:SetAttribute("SkillScreenOpen", "noServer")
	return
end
local ST = require(shared:WaitForChild("SkillTree"))

for _, n in ipairs({"SkillButton", "SkillScreen", "SkillScreenDim"}) do
	local old = pg:FindFirstChild(n)
	if old then old:Destroy() end
end

local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(0, 10) c.Parent = p return c end
local function stroke(p, color, t, th)
	local s = Instance.new("UIStroke")
	s.Color, s.Transparency, s.Thickness = color or WHITE, t or 0.5, th or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function label(parent, t, size, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.Text, l.TextSize = t, size
	l.TextColor3 = color or WHITE
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end
local function button(parent, t, size)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Font = Enum.Font.FredokaOne
	b.Text, b.TextSize = t, size or 14
	b.TextColor3 = WHITE
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = 0.18
	b.Parent = parent
	corner(b)
	stroke(b, WHITE, 0.5)
	return b
end
local function press(name) char:SetAttribute("SkillScreenLastPress", name) end

-- SKILLS button
local bgui = Instance.new("ScreenGui")
bgui.Name = "SkillButton"
bgui.ResetOnSpawn = true
bgui.DisplayOrder = 6
local skillsBtn = button(bgui, "SKILLS", 18)
skillsBtn.Name = "Skills"
skillsBtn.AnchorPoint = Vector2.new(1, 0)
skillsBtn.Position = UDim2.new(1, -150, 0, 12)
skillsBtn.Size = UDim2.fromOffset(92, 36)
local badge = label(skillsBtn, "0", 14, YELLOW_TEXT, Enum.TextXAlignment.Center)
badge.BackgroundTransparency = 0
badge.BackgroundColor3 = YELLOW
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Position = UDim2.new(1, -2, 0, 2)
badge.Size = UDim2.fromOffset(22, 22)
badge.Visible = false
corner(badge, UDim.new(1, 0))
bgui.Parent = pg

local function followPill()
	local status = pg:FindFirstChild("ArenaStatus")
	local pill = status and status:FindFirstChild("Pill")
	if pill then
		skillsBtn.Position = UDim2.new(1, -(16 + pill.AbsoluteSize.X + 8), 0, 12)
	end
end
task.spawn(function()
	local status = pg:WaitForChild("ArenaStatus", 10)
	local pill = status and status:WaitForChild("Pill", 5)
	if pill then
		pill:GetPropertyChangedSignal("AbsoluteSize"):Connect(followPill)
		followPill()
	end
end)

-- screen
local dgui = Instance.new("ScreenGui")
dgui.Name = "SkillScreenDim"
dgui.ResetOnSpawn = true
dgui.DisplayOrder = 20
dgui.IgnoreGuiInset = true
dgui.ScreenInsets = Enum.ScreenInsets.None
dgui.Enabled = false
local dim = Instance.new("TextButton") -- a button so touches and clicks stop here
dim.Text = ""
dim.AutoButtonColor = false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.45
dim.Parent = dgui
dgui.Parent = pg

local sgui = Instance.new("ScreenGui")
sgui.Name = "SkillScreen"
sgui.ResetOnSpawn = true
sgui.DisplayOrder = 21
sgui.Enabled = false
local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Position = UDim2.fromOffset(12, 12)
root.Size = UDim2.new(1, -24, 1, -24)
root.Parent = sgui

-- top bar
local top = Instance.new("Frame")
top.Name = "Top"
top.BackgroundTransparency = 1
top.Size = UDim2.new(1, 0, 0, 34)
top.Parent = root
local title = label(top, "SKILLS", 22)
title.Size = UDim2.fromOffset(90, 34)
local lv = Instance.new("Frame")
lv.BackgroundColor3 = PANEL
lv.BackgroundTransparency = 0.1
lv.Position = UDim2.fromOffset(96, 2)
lv.Size = UDim2.fromOffset(250, 30)
lv.Parent = top
corner(lv)
stroke(lv, WHITE, 0.6)
local lvText = label(lv, "LV 1", 15)
lvText.Position = UDim2.fromOffset(10, 0)
lvText.Size = UDim2.fromOffset(52, 30)
local xpBack = Instance.new("Frame")
xpBack.BackgroundColor3 = Color3.new(0, 0, 0)
xpBack.Position = UDim2.fromOffset(64, 11)
xpBack.Size = UDim2.fromOffset(90, 8)
xpBack.Parent = lv
corner(xpBack, UDim.new(1, 0))
local xpFill = Instance.new("Frame")
xpFill.BackgroundColor3 = YELLOW
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.Parent = xpBack
corner(xpFill, UDim.new(1, 0))
local xpGrad = Instance.new("UIGradient")
xpGrad.Color = ColorSequence.new(YELLOW, Color3.fromRGB(255, 155, 46))
xpGrad.Parent = xpFill
local xpText = label(lv, "0 / 30 XP", 13, GREY)
xpText.Position = UDim2.fromOffset(160, 0)
xpText.Size = UDim2.fromOffset(86, 30)
local closeBtn = button(top, "X", 16)
closeBtn.Name = "Close"
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, 0, 0, 0)
closeBtn.Size = UDim2.fromOffset(34, 34)
local respecBtn = button(top, "RESPEC", 14)
respecBtn.Name = "Respec"
respecBtn.AnchorPoint = Vector2.new(1, 0)
respecBtn.Position = UDim2.new(1, -42, 0, 0)
respecBtn.Size = UDim2.fromOffset(84, 34)
local pts = label(top, "0 PTS", 17, YELLOW_TEXT, Enum.TextXAlignment.Center)
pts.BackgroundTransparency = 0
pts.BackgroundColor3 = YELLOW
pts.AnchorPoint = Vector2.new(1, 0)
pts.Position = UDim2.new(1, -134, 0, 2)
pts.Size = UDim2.fromOffset(80, 30)
corner(pts)

-- body
local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(0, 42)
body.Size = UDim2.new(1, 0, 1, -42)
body.Parent = root
local function pane(parent)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.06
	f.Parent = parent
	corner(f, UDim.new(0, 14))
	stroke(f, WHITE, 0.82, 2)
	return f
end
local rail = pane(body)
rail.Name = "Rail"
rail.Size = UDim2.new(0, 64, 1, 0)
local railList = Instance.new("UIListLayout")
railList.Padding = UDim.new(0, 4)
railList.HorizontalAlignment = Enum.HorizontalAlignment.Center
railList.SortOrder = Enum.SortOrder.LayoutOrder
railList.Parent = rail
local railPad = Instance.new("UIPadding")
railPad.PaddingTop = UDim.new(0, 6)
railPad.Parent = rail
local cols = pane(body)
cols.Name = "Cols"
local detail = pane(body)
detail.Name = "Detail"
detail.AnchorPoint = Vector2.new(1, 0)
detail.Position = UDim2.fromScale(1, 0)
local dPad = Instance.new("UIPadding")
for _, k in ipairs({"PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom"}) do dPad[k] = UDim.new(0, 10) end
dPad.Parent = detail
local dName = label(detail, "", 17)
dName.Size = UDim2.new(1, 0, 0, 22)
local dSub = label(detail, "", 11, GREY)
dSub.Font = Enum.Font.Gotham
dSub.Position = UDim2.fromOffset(0, 24)
dSub.Size = UDim2.new(1, 0, 0, 14)
local dText = label(detail, "", 13)
dText.Font = Enum.Font.Gotham
dText.TextWrapped = true
dText.TextYAlignment = Enum.TextYAlignment.Top
dText.Position = UDim2.fromOffset(0, 44)
dText.Size = UDim2.new(1, 0, 1, -94)
local buyBtn = Instance.new("TextButton")
buyBtn.Name = "Buy"
buyBtn.AutoButtonColor = false
buyBtn.Font = Enum.Font.FredokaOne
buyBtn.TextSize = 16
buyBtn.AnchorPoint = Vector2.new(0, 1)
buyBtn.Position = UDim2.fromScale(0, 1)
buyBtn.Size = UDim2.new(1, 0, 0, 40)
buyBtn.Parent = detail
corner(buyBtn)

-- v1.1: loadout bar
local ORANGE = Color3.fromRGB(255, 155, 46)
local function loadoutOn() return script:GetAttribute("SkillScreenLoadoutEnabled") ~= false and ST.BUTTONS ~= nil end
local loadout = pane(body)
loadout.Name = "Loadout"
loadout.AnchorPoint = Vector2.new(0, 1)
local loTitle = label(loadout, "LOADOUT", 14, ORANGE)
loTitle.Position = UDim2.fromOffset(12, 0)
loTitle.Size = UDim2.new(0, 70, 1, 0)
local slotBtns = {}
for n = 1, 2 do
	local b = button(loadout, "", 13)
	b.Name = "Slot_" .. n
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.Position = UDim2.new(0, 86 + (n - 1) * 128, 0.5, 0)
	b.Size = UDim2.fromOffset(120, 36)
	b.TextScaled = true
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = 13
	tc.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = b
	slotBtns[n] = {b = b, stroke = b:FindFirstChildOfClass("UIStroke")}
end
local loHint = label(loadout, "Tap a slot to change it", 11, GREY)
loHint.Font = Enum.Font.Gotham
loHint.Position = UDim2.fromOffset(86 + 2 * 128 + 4, 0)
loHint.Size = UDim2.new(1, -(86 + 2 * 128 + 12), 1, 0)
loHint.TextTruncate = Enum.TextTruncate.AtEnd

local railButtons = {}
local function layout()
	local w = sgui.AbsoluteSize.X
	local dw = (w > 0 and w < 700) and math.floor((w - 24) * 0.3) or 220
	detail.Size = UDim2.new(0, dw, 1, 0)
	cols.Position = UDim2.fromOffset(72, 0)
	cols.Size = UDim2.new(1, -(72 + dw + 8), 1, 0)
	-- v1.1: the loadout bar takes the bottom 44 px of the tree's column (+ 8 px gap)
	loadout.Visible = loadoutOn()
	if loadout.Visible then
		cols.Size = UDim2.new(1, -(72 + dw + 8), 1, -52)
		loadout.Position = UDim2.new(0, 72, 1, 0)
		loadout.Size = UDim2.new(1, -(72 + dw + 8), 0, 44)
	end
	-- area buttons share the rail's height (46 px each at most; 30 at least)
	local rh = rail.AbsoluteSize.Y
	local bh = rh > 0 and math.clamp(math.floor((rh - 6 - 4 * 4) / 5), 30, 46) or 46
	for _, r in pairs(railButtons) do
		r.button.Size = UDim2.fromOffset(56, bh)
		r.label.Position = UDim2.new(0, 0, 1, -19)
		r.dot.Size = UDim2.fromOffset(bh < 40 and 12 or 16, bh < 40 and 12 or 16)
		r.dot.Position = UDim2.new(0.5, 0, 0, bh < 40 and 3 or 6)
	end
end
sgui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

-- respec confirm
local confirm = pane(root)
confirm.Name = "Confirm"
confirm.AnchorPoint = Vector2.new(0.5, 0.5)
confirm.Position = UDim2.fromScale(0.5, 0.5)
confirm.Size = UDim2.fromOffset(260, 120)
confirm.ZIndex = 10
confirm.Active = true -- taps on the box do not reach the nodes behind it
confirm.Visible = false
local cText = label(confirm, "Reset all points?", 18, WHITE, Enum.TextXAlignment.Center)
cText.Size = UDim2.new(1, 0, 0, 56)
cText.ZIndex = 11
local yesBtn = button(confirm, "YES", 16)
yesBtn.Name = "Yes"
yesBtn.Position = UDim2.new(0, 16, 1, -52)
yesBtn.Size = UDim2.new(0.5, -24, 0, 38)
yesBtn.BackgroundColor3 = YELLOW
yesBtn.BackgroundTransparency = 0
yesBtn.TextColor3 = YELLOW_TEXT
yesBtn.ZIndex = 11
local noBtn = button(confirm, "NO", 16)
noBtn.Name = "No"
noBtn.Position = UDim2.new(0.5, 8, 1, -52)
noBtn.Size = UDim2.new(0.5, -24, 0, 38)
noBtn.ZIndex = 11

sgui.Parent = pg

-- state
local area = ST.AREAS[1].id
local sel = nil -- {path = id, i = 1..4}
local function stepsOf(id) return player:GetAttribute("SkillPath_" .. id) or 0 end
local function left() return player:GetAttribute("SkillLeft") or 0 end
local function areaOf(id) for _, a in ipairs(ST.AREAS) do if a.id == id then return a end end end
local ROMAN = {"I", "II", "III", "★"}

local function nodeState(p, i) -- i = 1..4
	local n = stepsOf(p.id)
	if i <= n then return "own" end
	if p.soon then return "lock" end
	if i == n + 1 then return "next" end
	return "lock"
end

local colFrames = {}
local redraw

local function defaultSel()
	local a = areaOf(area)
	local p = a.paths[1]
	sel = {path = p.id, i = math.min(stepsOf(p.id) + 1, 4)}
end

local function buildRail()
	for _, a in ipairs(ST.AREAS) do
		local b = Instance.new("TextButton")
		b.Name = "Area_" .. a.id
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundColor3 = WHITE
		b.BackgroundTransparency = 1
		b.Size = UDim2.fromOffset(56, 46)
		b.Parent = rail
		corner(b)
		local s = stroke(b, rgb(a.color), 1, 2)
		local dot = Instance.new("Frame")
		dot.BackgroundColor3 = rgb(a.color)
		dot.AnchorPoint = Vector2.new(0.5, 0)
		dot.Position = UDim2.new(0.5, 0, 0, 6)
		dot.Size = UDim2.fromOffset(16, 16)
		dot.Parent = b
		corner(dot, UDim.new(1, 0))
		local l = label(b, a.name, 11, GREY, Enum.TextXAlignment.Center)
		l.Position = UDim2.fromOffset(0, 24)
		l.Size = UDim2.new(1, 0, 0, 18)
		b.MouseButton1Click:Connect(function()
			area = a.id
			press("area:" .. a.id)
			char:SetAttribute("SkillScreenArea", a.id)
			defaultSel()
			redraw()
		end)
		railButtons[a.id] = {button = b, stroke = s, label = l, dot = dot}
	end
end

local function clearCols()
	for _, f in ipairs(colFrames) do f:Destroy() end
	table.clear(colFrames)
end

local function buildCols()
	clearCols()
	local a = areaOf(area)
	local color = rgb(a.color)
	for c, p in ipairs(a.paths) do
		local col = Instance.new("Frame")
		col.Name = "Col_" .. p.id
		col.BackgroundColor3 = WHITE
		col.BackgroundTransparency = 0.97
		col.Position = UDim2.new((c - 1) / 3, 8, 0, 8)
		col.Size = UDim2.new(1 / 3, -12, 1, -16)
		col.Parent = cols
		corner(col)
		table.insert(colFrames, col)
		local name = label(col, (p.mech and "⚙ " or "") .. p.name, 13, WHITE, Enum.TextXAlignment.Center)
		name.Position = UDim2.fromOffset(0, 4)
		name.Size = UDim2.new(1, 0, 0, 18)
		name.TextScaled = true
		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = 13
		tc.Parent = name
		if p.soon then
			local soon = label(col, "soon", 10, GREY, Enum.TextXAlignment.Center)
			soon.Font = Enum.Font.Gotham
			soon.Position = UDim2.fromOffset(0, 22)
			soon.Size = UDim2.new(1, 0, 0, 12)
		end
		-- nodes bottom (I) to top (star), evenly spaced in the area below the name
		local stack = Instance.new("Frame")
		stack.Name = "Stack"
		stack.BackgroundTransparency = 1
		stack.Position = UDim2.fromOffset(0, 38)
		stack.Size = UDim2.new(1, 0, 1, -46)
		stack.Parent = col
		local owned = stepsOf(p.id)
		local function yOf(i) -- node centre, evenly spaced: I at the bottom (H - 19), star at the top (19)
			local k = 4 - i
			return k / 3, 19 - 38 * k / 3
		end
		local track = Instance.new("Frame") -- the path line behind the nodes
		track.BorderSizePixel = 0
		track.AnchorPoint = Vector2.new(0.5, 0)
		track.Position = UDim2.new(0.5, 0, 0, 19)
		track.Size = UDim2.new(0, 3, 1, -38)
		track.BackgroundColor3 = WHITE
		track.BackgroundTransparency = 0.85
		track.Parent = stack
		if owned >= 2 then -- the bought part, from step I up to the highest bought step
			local ys, yo = yOf(owned)
			local fill = Instance.new("Frame")
			fill.BorderSizePixel = 0
			fill.AnchorPoint = Vector2.new(0.5, 1)
			fill.Position = UDim2.new(0.5, 0, 1, -19)
			fill.Size = UDim2.new(0, 3, 1 - ys, -19 - yo)
			fill.BackgroundColor3 = color
			fill.Parent = stack
		end
		for i = 1, 4 do
			local yScale, yOff = yOf(i)
			local st = nodeState(p, i)
			local node = Instance.new("TextButton")
			node.Name = "Node_" .. i
			node.AutoButtonColor = false
			node.AnchorPoint = Vector2.new(0.5, 0.5)
			node.Position = UDim2.new(0.5, 0, yScale, yOff)
			node.Size = UDim2.fromOffset(38, 38)
			node.Font = Enum.Font.FredokaOne
			node.TextSize = 13
			node.Text = ROMAN[i]
			node.BackgroundColor3 = st == "own" and color or WHITE
			node.BackgroundTransparency = st == "own" and 0 or 0.94
			node.TextColor3 = st == "own" and Color3.fromRGB(17, 17, 17) or WHITE
			node.Parent = stack
			corner(node, i == 4 and UDim.new(0, 10) or UDim.new(1, 0))
			local ns = stroke(node, st == "next" and color or WHITE, st == "next" and 0 or 0.65, 2)
			if st == "lock" then
				node.TextTransparency = 0.6
				node.BackgroundTransparency = 0.97
				ns.Transparency = 0.8
			end
			if sel and sel.path == p.id and sel.i == i then
				local outline = stroke(node, WHITE, 0, 3)
				outline.Name = "Selected"
				ns:Destroy()
			end
			local cost = label(node, tostring(ST.COST[i]), 10, WHITE, Enum.TextXAlignment.Center)
			cost.BackgroundTransparency = 0
			cost.BackgroundColor3 = PANEL
			cost.AnchorPoint = Vector2.new(0.5, 0.5)
			cost.Position = UDim2.new(1, -2, 1, -2)
			cost.Size = UDim2.fromOffset(16, 14)
			corner(cost, UDim.new(0, 5))
			node.MouseButton1Click:Connect(function()
				sel = {path = p.id, i = i}
				press(("node:%s:%d"):format(p.id, i))
				redraw()
			end)
		end
	end
end

local function drawDetail()
	if not sel then defaultSel() end
	local p = ST.PATHS[sel.path]
	local a = areaOf(p.area)
	local color = rgb(a.color)
	local i = sel.i
	dName.Text = p.name .. " " .. ROMAN[i]
	dName.TextColor3 = color
	local kind = p.mech and ((ST.BUTTONS and ST.BUTTONS[p.id]) and "mecha button" or "mecha part") or "passive" -- v1.1
	dSub.Text = ("%s · step %d of 4 · %s"):format(a.name, i, kind)
	dText.Text = p.steps[i]
	local st = nodeState(p, i)
	local cost = ST.COST[i]
	local text, ok
	if p.soon then text, ok = "COMING SOON", false
	elseif st == "own" then text, ok = "BOUGHT", false
	elseif st == "next" then
		if left() >= cost then text, ok = ("BUY · %d PTS"):format(cost), true else text, ok = ("NEED %d PTS"):format(cost), false end
	else text, ok = "BUY THE ONE BEFORE", false end
	buyBtn.Text = text
	buyBtn.Active = ok
	buyBtn.BackgroundColor3 = ok and YELLOW or Color3.fromRGB(68, 68, 68)
	buyBtn.TextColor3 = ok and YELLOW_TEXT or Color3.fromRGB(153, 153, 153)
end

local function drawTop()
	local level = player:GetAttribute("SkillLevel") or 1
	local into, nxt = player:GetAttribute("SkillXPInto") or 0, player:GetAttribute("SkillXPNext") or 0
	lvText.Text = "LV " .. level
	xpFill.Size = UDim2.fromScale(nxt > 0 and math.clamp(into / nxt, 0, 1) or 1, 1)
	xpText.Text = nxt > 0 and ("%d / %d XP"):format(into, nxt) or "MAX"
	pts.Text = left() .. " PTS"
	badge.Text = tostring(left())
	badge.Visible = left() > 0
end

-- v1.1: loadout bar
local function slotOf(n)
	local v = player:GetAttribute("SkillSlot" .. n)
	return (type(v) == "string" and v ~= "") and v or nil
end
local function ownedButtons()
	local list = {}
	for _, id in ipairs(ST.PATH_ORDER) do
		if ST.BUTTONS and ST.BUTTONS[id] and not ST.PATHS[id].soon and stepsOf(id) >= 1 then table.insert(list, id) end
	end
	return list
end
local function drawLoadout()
	if not loadoutOn() then return end
	for n, s in ipairs(slotBtns) do
		local id = slotOf(n)
		local p = id and ST.PATHS[id]
		s.b.Text = p and ("Slot %d · ⚙ %s"):format(n, p.name) or ("Slot %d · empty"):format(n)
		s.stroke.Color = p and ORANGE or WHITE
		s.stroke.Transparency = p and 0 or 0.6
		s.b.TextColor3 = p and WHITE or GREY
	end
end
for n, s in ipairs(slotBtns) do
	s.b.MouseButton1Click:Connect(function()
		local list = ownedButtons()
		if #list == 0 then
			press(("slot:%d:none"):format(n))
			return
		end
		local cur, nextId = slotOf(n), list[1]
		for k, id in ipairs(list) do
			if id == cur then nextId = list[k + 1] or "" end
		end
		press(("slot:%d:%s"):format(n, nextId ~= "" and nextId or "empty"))
		remote:FireServer("slot", n, nextId)
	end)
end

function redraw()
	drawTop()
	if not sgui.Enabled then return end
	drawLoadout() -- v1.1
	for id, r in pairs(railButtons) do
		local on = id == area
		r.stroke.Transparency = on and 0 or 1
		r.button.BackgroundTransparency = on and 0.94 or 1
		r.label.TextColor3 = on and WHITE or GREY
	end
	buildCols()
	drawDetail()
end

-- open / close
local function setOpen(open)
	sgui.Enabled = open
	dgui.Enabled = open
	bgui.Enabled = not open -- the SKILLS button hides while the screen is open
	confirm.Visible = false
	char:SetAttribute("SkillScreenOpen", open)
	press(open and "open" or "close")
	if open then
		layout()
		if not sel then defaultSel() end
		char:SetAttribute("SkillScreenArea", area)
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	end
	redraw()
end

buildRail()
skillsBtn.MouseButton1Click:Connect(function() setOpen(not sgui.Enabled) end)
closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)
buyBtn.MouseButton1Click:Connect(function()
	if not buyBtn.Active or not sel then return end
	press("buy:" .. sel.path)
	remote:FireServer("buy", sel.path)
end)
respecBtn.MouseButton1Click:Connect(function()
	press("respec")
	confirm.Visible = true
end)
yesBtn.MouseButton1Click:Connect(function()
	press("respecYes")
	confirm.Visible = false
	remote:FireServer("respec")
end)
noBtn.MouseButton1Click:Connect(function()
	press("respecNo")
	confirm.Visible = false
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.K then setOpen(not sgui.Enabled) end
end)

-- redraw from the server's attributes; after a buy, move the selection to the path's next step
local queued = false
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 5) ~= "Skill" then return end
	if sel and name == "SkillPath_" .. sel.path then
		sel.i = math.min(stepsOf(sel.path) + 1, 4)
	end
	if not queued then -- one buy changes ~20 attributes: redraw once
		queued = true
		task.defer(function() queued = false redraw() end)
	end
end)

local function cleanup()
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
end
char.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then hum.Died:Connect(function() setOpen(false) cleanup() end) end

redraw()
