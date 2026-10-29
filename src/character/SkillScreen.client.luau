-- SkillScreen v1.3 (Mecha Dino Arena) — the SKILLS button and the skill tree screen (LocalScript, all devices). MDA-14,
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
-- v1.2 (skills per dino, MDA-45, plan docs/plans/SKILLS_PER_DINO_v1.0.md Task 2; Kepu 2026-10-29: "i dont think you need
--   the "skills" label to be there. just dino name and level and xp progress"): the top bar title shows the dino whose
--   level and points these are (SkillServer 1.2 keeps one record per dino): DINO_TITLES[Species] ("T-REX" / "RAPTOR"),
--   else the Species in capitals, else "SKILLS" when the character has no Species. Same label, place and size (90 x 34,
--   22). Updates when Species changes. Script attribute SkillScreenDinoTitleEnabled (default true; false = "SKILLS" as
--   1.1). Diagnostic (character): SkillScreenTitle (the text shown). The SKILLS button on the HUD is unchanged.
-- v1.3 (Cloak release, MDA-53, plan docs/plans/CLOAK_v1.0.md Tasks 5 + 5b and the Mastery section, docs/plans/LOADOUT4_v1.0.md
--   Task 3; Kepu 2026-10-29 "I love C's" = docs/mockups/skilltree_classic_options.html option C "Tier rows"; Mastery chip =
--   docs/mockups/mastery_options.html option A):
--   * Per dino: every area shows SkillTree.pathsFor(area, Species) (shared first, then the dino's own; soon parts greyed).
--   * Tier-row tree (script attribute SkillScreenTierRowsEnabled, default true; false = the 1.2 rail + columns, which also
--     use pathsFor, column width 1 / count). The rail is hidden and the tree pane (Cols) spans from x 0 to the detail
--     panel. Inside: ScrollingFrame Cols.Tree > Frame Canvas, drawn in design units (mockup C, y - 70) x scale s:
--       columns: x 40, +40 per line, +18 between areas, in AREAS order; design width W = the x after the last area;
--       rows (centre y): I 290, II 210, III 130, star 50; faint row bands (white 0.96, 30 tall, x 26 .. W - 20) and row
--         labels at x 10 (white 0.65, 11);
--       under each area: a 3-unit bar in the area colour (0.3) at y 335 from the first column - 14 to the last + 14, and
--         the area name (FredokaOne 12.5, area colour) at y 351;
--       root: a rounded bar x 20 .. W - 20, y 370 .. 396 (rgb(27, 36, 51), white stroke 0.65) with the dino name;
--       mastery line (BUILD_LIMITS): a gold dashed rule at y 170 (rgb(255, 214, 102), 0.65) labelled "mastery line: 3
--         lines can go above" (Gotham 10, right end at W - 20);
--       links: column line from the area bar to I and between steps; lit (area colour, 4) up to the bought step, else
--         white 0.88 (3); dashed for soon lines; a gold halo (9, 0.45) under the lit links of a mastered line;
--       nodes: dino stats are circles (r 12, star r 15), mecha parts hexagons (3 rects at 0 / 60 / 120 degrees);
--         bought = filled in the area colour, next = white outline, not yet = rgb(21, 27, 39) with a white 0.7 outline,
--         soon = dashed outline at 0.6 opacity, mastery-locked ("mlock": step III / star of an unmastered line while
--         MASTERY_MAX lines are mastered) = 0.4 opacity with a lock; mastered line = a gold ring (circle r + 5 / hexagon
--         r + 6) around each node; selected line = yellow ring r + 7 on its nodes (the selected step 3 px, others 2 px);
--         the selected line's name in yellow above its star (y 22).
--       Scale s = max(9 / 12, min(pane width / W, pane height / 410)); a canvas bigger than the pane scrolls (X and / or
--       Y) and the selected node is scrolled into view when the selection changes; a smaller canvas is centred.
--   * Mastery (SkillTree 1.5 MASTERY_MAX): a gold "MASTERY n/3" chip in the top bar after the level box (x 354, up to 110
--     wide; hidden when less than 56 px fit before the points pill); the detail panel shows "You have mastered n lines
--     (A, B, C). Only 3 lines can go past step II." in gold and BUY reads "MASTERY FULL · RESPEC TO CHANGE" (not
--     pressable) for an mlock step. Respec (free) clears all masteries.
--   * Loadout strip: 4 tiles in the order slot 1, 3, 2, 4 (Slot_1 / Slot_3 / Slot_2 / Slot_4), labels "R · tap",
--     "R · pull ▼", "C · tap", "C · pull ▼" (touch) / "R · tap", "T", "C · tap", "V" (PC); tile width
--     min(120, (strip width - 86 - 8 - 3 x 6) / 4), text scaled; the hint is hidden when the tiles are under 120. A tap
--     cycles that slot's part as 1.1 (only parts this dino owns).
--   Diagnostics (character, this client): SkillScreenLayout ("tiers" / "rail"), SkillScreenTreeLines (path ids in tree
--   order), SkillScreenTreeScale (0.01), SkillScreenTreeScroll ("none" / "x" / "y" / "xy"), SkillScreenMastery ("n/3").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local VERSION = "1.3"
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

-- v1.3: per-dino tree, tier rows, Mastery
local GOLD = Color3.fromRGB(255, 214, 102)
local SEL_YELLOW = Color3.fromRGB(255, 200, 50)
local NODE_BG = Color3.fromRGB(21, 27, 39)
local ROOT_BG = Color3.fromRGB(27, 36, 51)
local GLYPH = Color3.fromRGB(207, 214, 228)
if script:GetAttribute("SkillScreenTierRowsEnabled") == nil then script:SetAttribute("SkillScreenTierRowsEnabled", true) end
local function tiersOn() return script:GetAttribute("SkillScreenTierRowsEnabled") ~= false end
local function dino()
	local sp = char:GetAttribute("Species")
	return (type(sp) == "string" and sp ~= "") and sp or nil
end

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
-- v1.2: the dino's name instead of "SKILLS"
local DINO_TITLES = {TRex = "T-REX", Raptor = "RAPTOR"}
local function drawTitle()
	local sp = char:GetAttribute("Species")
	local text = "SKILLS"
	if script:GetAttribute("SkillScreenDinoTitleEnabled") ~= false and type(sp) == "string" and sp ~= "" then
		text = DINO_TITLES[sp] or string.upper(sp)
	end
	title.Text = text
	char:SetAttribute("SkillScreenTitle", text)
end
drawTitle()
char:GetAttributeChangedSignal("Species"):Connect(drawTitle)
script:GetAttributeChangedSignal("SkillScreenDinoTitleEnabled"):Connect(drawTitle)
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
-- v1.3: Mastery chip after the level box
local mchip = label(top, "MASTERY 0/3", 14, GOLD, Enum.TextXAlignment.Center)
mchip.Name = "Mastery"
mchip.BackgroundTransparency = 0.1
mchip.BackgroundColor3 = PANEL
mchip.Position = UDim2.fromOffset(354, 2)
mchip.Size = UDim2.fromOffset(110, 30)
mchip.TextScaled = true
do
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 14
	c.Parent = mchip
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = mchip
end
corner(mchip)
stroke(mchip, GOLD, 0, 1.5)
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
local dWhy = label(detail, "", 12, GOLD) -- v1.3: the Mastery reason
dWhy.Name = "Why"
dWhy.Font = Enum.Font.Gotham
dWhy.TextWrapped = true
dWhy.TextYAlignment = Enum.TextYAlignment.Bottom
dWhy.AnchorPoint = Vector2.new(0, 1)
dWhy.Position = UDim2.new(0, 0, 1, -48)
dWhy.Size = UDim2.new(1, 0, 0, 48)
dWhy.Visible = false
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
buyBtn.TextScaled = true -- v1.3: "MASTERY FULL · RESPEC TO CHANGE" fits; at most 16 as before
do
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 16
	c.Parent = buyBtn
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = buyBtn
end

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
local SLOT_ORDER = {1, 3, 2, 4} -- v1.3: R tap, R pull, C tap, C pull
local SLOT_LABELS = UserInputService.TouchEnabled and {"R · tap", "C · tap", "R · pull ▼", "C · pull ▼"}
	or {"R · tap", "C · tap", "T", "V"} -- v1.3: by slot number
for k, n in ipairs(SLOT_ORDER) do -- v1.3: 4 slots (was 1, 2)
	local b = button(loadout, "", 13)
	b.Name = "Slot_" .. n
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.Position = UDim2.new(0, 86 + (k - 1) * 128, 0.5, 0)
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
local treeScroll -- v1.3: Cols.Tree (made below)
local function layout()
	local w = sgui.AbsoluteSize.X
	local dw = (w > 0 and w < 700) and math.floor((w - 24) * 0.3) or 220
	detail.Size = UDim2.new(0, dw, 1, 0)
	local x0 = tiersOn() and 0 or 72 -- v1.3: no rail in the tier-row view
	rail.Visible = not tiersOn()
	if treeScroll then treeScroll.Visible = tiersOn() end
	cols.Position = UDim2.fromOffset(x0, 0)
	cols.Size = UDim2.new(1, -(x0 + dw + 8), 1, 0)
	-- v1.1: the loadout bar takes the bottom 44 px of the tree's column (+ 8 px gap)
	loadout.Visible = loadoutOn()
	if loadout.Visible then
		cols.Size = UDim2.new(1, -(x0 + dw + 8), 1, -52)
		loadout.Position = UDim2.new(0, x0, 1, 0)
		loadout.Size = UDim2.new(1, -(x0 + dw + 8), 0, 44)
		-- v1.3: 4 tiles share the strip
		local lw = (w > 0 and w - 24 or 800) - x0 - dw - 8
		local tw = math.clamp(math.floor((lw - 86 - 8 - 3 * 6) / 4), 40, 120)
		for k, n in ipairs(SLOT_ORDER) do
			local sb = slotBtns[n]
			if sb then
				sb.b.Position = UDim2.new(0, 86 + (k - 1) * (tw + 6), 0.5, 0)
				sb.b.Size = UDim2.fromOffset(tw, 36)
			end
		end
		loHint.Visible = tw >= 120
		loHint.Position = UDim2.fromOffset(86 + 4 * (tw + 6) + 4, 0)
		loHint.Size = UDim2.new(1, -(86 + 4 * (tw + 6) + 12), 1, 0)
	end
	-- v1.3: Mastery chip room (before the points pill, whose left edge is 214 px from the right)
	local avail = (w > 0 and w - 24 or 800) - 214 - 8 - 354
	mchip.Visible = ST.BUILD_LIMITS == true and avail >= 56
	mchip.Size = UDim2.fromOffset(math.min(110, math.max(56, avail)), 30)
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

-- v1.3: the paths this dino sees in an area (pathsFor), the mastered lines, and the Mastery lock
local function pathsOf(areaId)
	if ST.pathsFor then return ST.pathsFor(areaId, dino()) end
	return areaOf(areaId).paths
end
local function masteredList()
	local out = {}
	if not ST.BUILD_LIMITS then return out end
	for _, id in ipairs(ST.PATH_ORDER) do
		if (not ST.seesPath or ST.seesPath(id, dino())) and stepsOf(id) >= 3 then table.insert(out, id) end
	end
	return out
end
local function mlocked(p, i)
	if not ST.BUILD_LIMITS or i < 3 or stepsOf(p.id) >= 3 then return false end
	return #masteredList() >= (ST.MASTERY_MAX or 3)
end

local function nodeState(p, i) -- i = 1..4
	local n = stepsOf(p.id)
	if i <= n then return "own" end
	if p.soon then return "lock" end
	if mlocked(p, i) then return "mlock" end -- v1.3
	if i == n + 1 then return "next" end
	return "lock"
end

local colFrames = {}
local redraw

local function defaultSel()
	local list -- v1.3: the first line this dino sees (tier rows: in tree order; rail: in the open area)
	if tiersOn() then
		for _, a in ipairs(ST.AREAS) do
			local ps = pathsOf(a.id)
			if #ps > 0 then list = ps break end
		end
	else
		list = pathsOf(area)
	end
	local p = (list and list[1]) or areaOf(area).paths[1]
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
	local ps = pathsOf(area) -- v1.3: this dino's lines (was all 3)
	for c, p in ipairs(ps) do
		local col = Instance.new("Frame")
		col.Name = "Col_" .. p.id
		col.BackgroundColor3 = WHITE
		col.BackgroundTransparency = 0.97
		col.Position = UDim2.new((c - 1) / #ps, 8, 0, 8)
		col.Size = UDim2.new(1 / #ps, -12, 1, -16)
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
			if st == "lock" or st == "mlock" then -- v1.3: + mlock
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

-- v1.3: tier-row tree -------------------------------------------------------------------------------------------------
local D = {ROW = {290, 210, 130, 50}, BAR = 335, AREA_LABEL = 351, ROOT_Y = 370, ROOT_H = 26, H = 410, MASTERY = 170,
	X0 = 40, COL = 40, AREA_GAP = 18, R = 12, R_STAR = 15}
treeScroll = Instance.new("ScrollingFrame")
treeScroll.Name = "Tree"
treeScroll.BackgroundTransparency = 1
treeScroll.BorderSizePixel = 0
treeScroll.Position = UDim2.fromOffset(4, 4)
treeScroll.Size = UDim2.new(1, -8, 1, -8)
treeScroll.ScrollBarThickness = 6
treeScroll.ScrollingDirection = Enum.ScrollingDirection.XY
treeScroll.CanvasSize = UDim2.new()
treeScroll.Visible = tiersOn()
treeScroll.Parent = cols
local canvas
local lastScrollKey

local function alpha(t, op) return 1 - (1 - t) * op end
local function stripes(parent) -- dashed look for "soon" outlines (a striped transparency gradient)
	local g = Instance.new("UIGradient")
	local kp = {}
	for k = 0, 19 do table.insert(kp, NumberSequenceKeypoint.new(k / 19, k % 2 == 0 and 0 or 1)) end
	g.Transparency = NumberSequence.new(kp)
	g.Rotation = 90
	g.Parent = parent
end
local function centred(parent, name, w, h, color, t, z) -- a frame centred in its parent
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = t
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent
	return f
end
local function at(parent, name, cx, cy, w, h, color, t, z) -- a frame centred on (cx, cy) px
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = t
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent
	return f
end
local function ringAt(parent, name, radius, color, t, th, z, dashed)
	local f = centred(parent, name, radius * 2, radius * 2, color, 1, z)
	corner(f, UDim.new(1, 0))
	local st = stroke(f, color, t, th)
	if dashed then stripes(st) end
	return f
end
local function hexagon(parent, name, radius, color, t, z, dashed) -- pointy-top: 3 rects (sqrt3 R x R) at 0 / 60 / 120
	local h = centred(parent, name, radius * 2, radius * 2, color, 1, z)
	for k = 0, 2 do
		local r = centred(h, "Part_" .. k, radius * math.sqrt(3), radius, color, t, z)
		r.Rotation = 60 * k
		if dashed then stripes(r) end
	end
	return h
end
local function textAt(parent, name, text, cx, cy, w, h, size, color, t, z, font, align)
	local l = label(parent, text, size, color, align or Enum.TextXAlignment.Center)
	l.Name = name
	l.AnchorPoint = Vector2.new(align == Enum.TextXAlignment.Right and 1 or align == Enum.TextXAlignment.Left and 0 or 0.5, 0.5)
	l.Position = UDim2.fromOffset(cx, cy)
	l.Size = UDim2.fromOffset(w, h)
	l.TextTransparency = t
	l.ZIndex = z
	if font then l.Font = font end
	return l
end
local function vline(parent, name, x, y1, y2, w, color, t, z, dashed, sc) -- px coordinates
	local top, bot = math.min(y1, y2), math.max(y1, y2)
	if not dashed then
		local f = at(parent, name, x, (top + bot) / 2, w, bot - top, color, t, z)
		corner(f, UDim.new(1, 0))
		return
	end
	local dash, gap, y, k = 4 * sc, 5 * sc, top, 0
	while y < bot do
		local h = math.min(dash, bot - y)
		at(parent, name .. "_" .. k, x, y + h / 2, w, h, color, t, z)
		y += dash + gap
		k += 1
	end
end
local function hline(parent, name, x1, x2, y, th, color, t, z, dash, gap)
	local x, k = x1, 0
	while x < x2 do
		local w = math.min(dash, x2 - x)
		at(parent, name .. "_" .. k, x + w / 2, y, w, th, color, t, z)
		x += dash + gap
		k += 1
	end
end

local function buildTree()
	clearCols()
	if canvas then canvas:Destroy() canvas = nil end
	local fw, fh = treeScroll.AbsoluteSize.X, treeScroll.AbsoluteSize.Y
	if fw <= 0 or fh <= 0 then return end -- not laid out yet; the AbsoluteSize signal redraws
	-- columns in tree order
	local colsList, areasList, x = {}, {}, D.X0
	for _, a in ipairs(ST.AREAS) do
		local ps = pathsOf(a.id)
		if #ps > 0 then
			local start = x
			for _, p in ipairs(ps) do
				table.insert(colsList, {p = p, x = x, a = a})
				x += D.COL
			end
			table.insert(areasList, {a = a, x1 = start - 14, x2 = x - D.COL + 14, mid = (start + x - D.COL) / 2})
			x += D.AREA_GAP
		end
	end
	local W, H = x, D.H
	local sc = math.max(9 / D.R, math.min(fw / W, fh / H))
	local cw, chh = W * sc, H * sc
	local ox, oy = math.max(0, (fw - cw) / 2), math.max(0, (fh - chh) / 2)
	treeScroll.CanvasSize = UDim2.fromOffset(math.max(cw, fw), math.max(chh, fh))
	local scrollMode = (cw > fw + 0.5 and "x" or "") .. (chh > fh + 0.5 and "y" or "")
	char:SetAttribute("SkillScreenTreeScale", math.floor(sc * 100 + 0.5) / 100)
	char:SetAttribute("SkillScreenTreeScroll", scrollMode == "" and "none" or scrollMode)
	canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.Position = UDim2.fromOffset(ox, oy)
	canvas.Size = UDim2.fromOffset(cw, chh)
	local function P(v) return v * sc end
	-- row bands + labels
	local ROMANS = {"I", "II", "III", "★"}
	for i, y in ipairs(D.ROW) do
		at(canvas, "Band_" .. i, P((26 + W - 20) / 2), P(y), P(W - 46), P(30), WHITE, 0.96, 1)
		textAt(canvas, "Row_" .. i, ROMANS[i], P(10), P(y), P(16), P(14), 11 * sc, WHITE, 0.65, 2, nil, Enum.TextXAlignment.Left)
	end
	-- mastery line
	if ST.BUILD_LIMITS then
		hline(canvas, "MasteryLine", P(26), P(W - 20), P(D.MASTERY), math.max(1, 1.5 * sc), GOLD, 0.65, 2, P(6), P(5))
		textAt(canvas, "MasteryLabel", ("mastery line: %d lines can go above"):format(ST.MASTERY_MAX or 3),
			P(W - 20), P(D.MASTERY - 10), P(260), P(14), 10 * sc, GOLD, 0.2, 2, Enum.Font.Gotham, Enum.TextXAlignment.Right)
	end
	-- area bars + names
	for _, e in ipairs(areasList) do
		local c = rgb(e.a.color)
		at(canvas, "AreaBar_" .. e.a.id, P((e.x1 + e.x2) / 2), P(D.BAR), P(e.x2 - e.x1), math.max(2, P(3)), c, 0.3, 2)
		textAt(canvas, "AreaName_" .. e.a.id, string.upper(e.a.name), P(e.mid), P(D.AREA_LABEL), P(120), P(16), 12.5 * sc, c, 0, 2)
	end
	-- root bar with the dino name
	local rootBar = at(canvas, "Root", P(W / 2), P(D.ROOT_Y + D.ROOT_H / 2), P(W - 40), P(D.ROOT_H), ROOT_BG, 0, 2)
	corner(rootBar, UDim.new(0, P(13)))
	stroke(rootBar, WHITE, 0.65, 1)
	local sp = dino()
	local rootText = label(rootBar, sp and (DINO_TITLES[sp] or string.upper(sp)) or "SKILLS", 13 * sc, WHITE, Enum.TextXAlignment.Center)
	rootText.Size = UDim2.fromScale(1, 1)
	rootText.ZIndex = 3
	-- columns
	local mastered = {}
	for _, id in ipairs(masteredList()) do mastered[id] = true end
	local lines = {}
	for _, e in ipairs(colsList) do
		local p, cx = e.p, e.x
		table.insert(lines, p.id)
		local color = rgb(e.a.color)
		local n = stepsOf(p.id)
		local isM = mastered[p.id] == true
		local isSel = sel and sel.path == p.id
		local col = Instance.new("Frame")
		col.Name = "Col_" .. p.id
		col.BackgroundTransparency = 1
		col.Size = UDim2.fromScale(1, 1)
		col.ZIndex = 3
		col.Parent = canvas
		for k = 0, 3 do -- link k: area bar (k = 0) or step k -> step k + 1
			local yA, yB = k == 0 and D.BAR or D.ROW[k], D.ROW[k + 1]
			local lit = k < n
			if lit and isM then vline(col, "Halo_" .. k, P(cx), P(yA), P(yB), P(9), GOLD, 0.45, 1, false, sc) end
			vline(col, "Link_" .. k, P(cx), P(yA), P(yB), math.max(2, P(lit and 4 or 3)), lit and color or WHITE,
				lit and 0 or 0.88, 2, p.soon, sc)
		end
		for i = 1, 4 do
			local st = nodeState(p, i)
			local own, nxt, lk = st == "own", st == "next", st == "mlock"
			local op = lk and 0.4 or p.soon and 0.6 or 1
			local r0 = i == 4 and D.R_STAR or D.R
			local r = P(r0)
			local th = math.max(1, 2.2 * sc)
			local node = Instance.new("TextButton")
			node.Name = "Node_" .. i
			node.Text = ""
			node.AutoButtonColor = false
			node.BackgroundTransparency = 1
			node.AnchorPoint = Vector2.new(0.5, 0.5)
			node.Position = UDim2.fromOffset(P(cx), P(D.ROW[i]))
			node.Size = UDim2.fromOffset(P(2 * (r0 + 8)), P(2 * (r0 + 8)))
			node.ZIndex = 4
			node.Parent = col
			if isSel then
				local here = sel.i == i
				ringAt(node, "SelRing", r + P(7), SEL_YELLOW, alpha(here and 0 or 0.15, op), math.max(1, here and 3 * sc or 2 * sc), 5)
			end
			if isM then
				if p.mech then
					hexagon(node, "Mastered", r + P(6), GOLD, alpha(0, op), 5)
					hexagon(node, "MasteredGap", r + P(4), PANEL, 0, 6)
				else
					ringAt(node, "Mastered", r + P(5), GOLD, alpha(0, op), math.max(1, 2 * sc), 5)
				end
			end
			local fill = own and color or NODE_BG
			local sColor, sT
			if p.soon then sColor, sT = WHITE, 0.75
			elseif own then sColor, sT = color, 0
			elseif nxt then sColor, sT = WHITE, 0
			else sColor, sT = WHITE, 0.7 end
			if p.mech then
				hexagon(node, "Edge", r + P(1) + th, sColor, alpha(sT, op), 7, p.soon)
				hexagon(node, "Body", r + P(1), fill, alpha(0, op), 8)
			else
				local b = centred(node, "Body", 2 * r, 2 * r, fill, alpha(0, op), 8)
				corner(b, UDim.new(1, 0))
				local bs = stroke(b, sColor, alpha(sT, op), th)
				if p.soon then stripes(bs) end
			end
			local g = label(node, ROMAN[i], (i == 4 and 12 or 10) * sc, own and Color3.fromRGB(17, 17, 17) or GLYPH,
				Enum.TextXAlignment.Center)
			g.Name = "Glyph"
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.5)
			g.Size = UDim2.fromOffset(2 * r, 2 * r)
			g.TextTransparency = alpha(0, op)
			g.ZIndex = 9
			if lk then
				local l = label(node, "🔒", 10 * sc, WHITE, Enum.TextXAlignment.Center)
				l.Name = "Lock"
				l.AnchorPoint = Vector2.new(0.5, 0.5)
				l.Position = UDim2.new(0.5, P(13), 0.5, -P(10))
				l.Size = UDim2.fromOffset(P(14), P(14))
				l.TextTransparency = alpha(0, op)
				l.ZIndex = 10
			end
			node.MouseButton1Click:Connect(function()
				sel = {path = p.id, i = i}
				char:SetAttribute("SkillScreenArea", p.area)
				press(("node:%s:%d"):format(p.id, i))
				redraw()
			end)
		end
		if isSel then
			textAt(canvas, "SelName", p.name, P(cx), P(D.ROW[4] - 28), P(200), P(16), 12 * sc, SEL_YELLOW, 0, 10)
		end
	end
	char:SetAttribute("SkillScreenTreeLines", table.concat(lines, ","))
	canvas.Parent = treeScroll
	-- keep the selected node in view when the selection changes
	local key = sel and (sel.path .. ":" .. sel.i) or ""
	if key ~= lastScrollKey and sel then
		lastScrollKey = key
		for _, e in ipairs(colsList) do
			if e.p.id == sel.path then
				local maxX, maxY = math.max(0, cw - fw), math.max(0, chh - fh)
				treeScroll.CanvasPosition = Vector2.new(math.clamp(ox + P(e.x) - fw / 2, 0, maxX),
					math.clamp(oy + P(D.ROW[sel.i]) - fh / 2, 0, maxY))
			end
		end
	end
end

local function drawDetail()
	if not sel then defaultSel() end
	if ST.seesPath and not ST.seesPath(sel.path, dino()) then defaultSel() end -- v1.3: another dino's line
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
	local why = nil -- v1.3: Mastery reason
	if p.soon then text, ok = "COMING SOON", false
	elseif st == "own" then text, ok = "BOUGHT", false
	elseif st == "mlock" then -- v1.3
		text, ok = "MASTERY FULL · RESPEC TO CHANGE", false
		local names = {}
		for _, id in ipairs(masteredList()) do table.insert(names, ST.PATHS[id].name) end
		why = ("You have mastered %d lines (%s). Only %d lines can go past step II."):format(#names,
			table.concat(names, ", "), ST.MASTERY_MAX or 3)
	elseif st == "next" then
		if left() >= cost then text, ok = ("BUY · %d PTS"):format(cost), true else text, ok = ("NEED %d PTS"):format(cost), false end
	else text, ok = "BUY THE ONE BEFORE", false end
	dWhy.Text = why or "" -- v1.3
	dWhy.Visible = why ~= nil
	dText.Size = UDim2.new(1, 0, 1, why and -146 or -94)
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
	local mtext = ("%d/%d"):format(#masteredList(), ST.MASTERY_MAX or 3) -- v1.3
	mchip.Text = "MASTERY " .. mtext
	char:SetAttribute("SkillScreenMastery", mtext)
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
		if ST.BUTTONS and ST.BUTTONS[id] and not ST.PATHS[id].soon and stepsOf(id) >= 1
			and (not ST.seesPath or ST.seesPath(id, dino())) then table.insert(list, id) end -- v1.3: + this dino's
	end
	return list
end
local function drawLoadout()
	if not loadoutOn() then return end
	for n, s in ipairs(slotBtns) do
		local id = slotOf(n)
		local p = id and ST.PATHS[id]
		s.b.Text = p and ("%s · ⚙ %s"):format(SLOT_LABELS[n], p.name) or ("%s · empty"):format(SLOT_LABELS[n]) -- v1.3 (was "Slot n")
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
	if not sel or (ST.seesPath and not ST.seesPath(sel.path, dino())) then defaultSel() end -- v1.3
	if tiersOn() then -- v1.3
		char:SetAttribute("SkillScreenLayout", "tiers")
		buildTree()
	else
		char:SetAttribute("SkillScreenLayout", "rail")
		if canvas then canvas:Destroy() canvas = nil end
		for id, r in pairs(railButtons) do
			local on = id == area
			r.stroke.Transparency = on and 0 or 1
			r.button.BackgroundTransparency = on and 0.94 or 1
			r.label.TextColor3 = on and WHITE or GREY
		end
		buildCols()
	end
	drawDetail()
end
-- v1.3: the tree is drawn from the pane's real size; redraw when it changes or the layout toggle flips
treeScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if sgui.Enabled and tiersOn() then redraw() end
end)
script:GetAttributeChangedSignal("SkillScreenTierRowsEnabled"):Connect(function()
	layout()
	sel = nil
	redraw()
end)
char:GetAttributeChangedSignal("Species"):Connect(function() sel = nil redraw() end)

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
