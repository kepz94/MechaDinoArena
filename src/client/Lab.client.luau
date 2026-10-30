-- Lab v1.3 (Mecha Dino Arena) — the workbench: your dino with every applied upgrade, every mech part as a card with its
-- own 3D model, and buying / upgrading / equipping in one screen (LocalScript in StarterPlayerScripts, all devices;
-- survives respawns). Replaces SkillScreen 1.4 (deleted, Kepu: "Delete it"). MDA-97, plan docs/plans/LAB_v1.0.md Task 2,
-- mockup docs/mockups/lab_options.html A "Workbench" (Kepu 2026-10-29: "a dedicated screen for selecting the Dino upgrades
-- with the actual visual for each mecha selection. Replace the skill tree ..."; "Let's do the work bench. Make sure
-- everything is portioned and spaced correctly"; answers: the Lab does everything, compact Lab on the island, cards with
-- the part's 3D model, no RESPEC).
-- Two sizes, same pieces (ch = screen height / 100, cw = screen width / 100; px minimums as noted):
--   * full (from the main menu: Lab.Open:Invoke("full"), MainMenu 1.2 GO TO THE LAB): the whole screen, backdrop
--     rgb(16, 20, 29) -> rgb(26, 33, 48) -> rgb(14, 18, 25); ✕ goes back to the menu.
--   * compact (on the island: the SKILLS button or K while InMenu ~= true): a panel inset max(10ch, Roblox top bar height
--     (GuiService.TopbarInset) + 1ch) top, 11cw sides, 6ch bottom
--     (corner 2.4ch, volt stroke) over a 0.55 black dim; the game keeps running. Character attribute SkillScreenOpen = true
--     while it is open (AbilityBar hides its bar, as with the old screen).
-- Top bar: padding 1.4ch top / 1.2ch bottom; left = max(10ch, right edge of the Roblox top-left buttons (GuiService.TopbarInset
--   Min.X) + 1.6ch) (full) or 2cw (compact); right 2cw; a 0.35ch
--   volt line under it. "LAB" (volt, 0.55 x) + dino name (FredokaOne 3.4ch) | "LV n" (max(1.8ch, 10)) + XP bar 12cw x 1.4ch
--   | MASTERY n/3 chip (gold stroke) ... points chip (yellow, FredokaOne 2.4ch) | X (max(5ch, 30) square). Gaps 1.6ch.
-- Body: padding 1.6ch top, 2cw sides, 2ch bottom; columns 31% | rest | 27% (compact 34% | rest | 30%), gaps 1.6cw.
--   * left: tabs MECH PARTS / STATS (equal, gap 0.8ch, text max(1.7ch, 10)), 1.2ch, a scrolling 2-column card grid (gap
--     1ch; 3 px inner padding so the 2 px strokes are not clipped). Card: padding 1ch, corner 1.4ch; 4:3 ViewportFrame with ReplicatedStorage.LabPreviews.<id> turning (LabPreviewServer
--     1.0; "?" when missing, "SOON" for parts not built yet); name (FredokaOne max(1.9ch, 11)); pips (1.6ch, area colour;
--     star round) + step tag (I / II / III / ★ / NEW); badge top-right: slot key (orange) / ALWAYS ON (volt) / SOON (grey).
--     Equipped = orange stroke, selected = white stroke. Stats tab: rows (name, pips, area, "Next: n pt(s)" / "Maxed").
--   * middle: stage (fills; "ALL UPGRADES" tag; ViewportFrame with a copy of your live character turning, so it shows the
--     equipped parts and Blade Claws; turntable fit: X/Z diagonal to the stage width, height + 0.3 x diagonal to the stage
--     height, 1.12 margin), 1.2ch, 4 slot buttons (equal, gap 0.8cw, height max(6ch, 34): key + part model icon + name
--     (wraps to 2 lines, shrinks to 8 px, then cuts with "..."); empty = faint; a slot too narrow for a 50 px name shows the key and a bigger model only), 1.2ch, hint
--     (max(1.5ch, 10)).
--   * right: detail panel (padding 1.6ch): area · kind (area colour), name (FredokaOne 3ch), steps I / II / III / ★ (got =
--     area colour, next = white outline, rest grey; text max(1.6ch, 10), first line centred on the badge; rows gap
--     max(0.9ch, 5)), buttons (height max(5.6ch, 34)): BUY / UPGRADE ·
--     n PTS (yellow) or NEED n PTS / MAXED / MASTERY FULL / COMING SOON (greyed), and EQUIP (orange) / UNEQUIP <key> (dark)
--     for owned button parts; hint.
-- Rules (SkillServer stays the judge): card -> detail; BUY -> SkillRequest("buy", id) (SkillTree.canBuy decides the label);
--   EQUIP -> ("slot", n, id) into the selected slot, else the first empty one, else toast "Slots full · tap a slot to
--   replace" and the slots pulse; UNEQUIP -> ("slot", n, ""). Tap a slot then an equippable card = equip there; tap a slot
--   with an equippable, unslotted card selected = equip there; otherwise a slot tap selects / deselects it.
--   Equippable = SkillTree.BUTTONS, not soon, this dino's, bought (steps >= 1). Everything redraws from the player
--   attributes (SkillLevel, SkillXPInto, SkillXPNext, SkillLeft, SkillPoints, SkillPath_<id>, SkillSlot1..4).
-- SKILLS button (ScreenGui "LabButton", DisplayOrder 6, the old SkillScreen button's place and look): a pill 8 px left of
--   ArenaStatus's pill (y 12, height 36; x -150 from the right when there is no pill), "SKILLS", yellow badge with the points
--   while SkillLeft > 0; hidden while InMenu and while the compact Lab is open (it would sit under
--   the panel; X / K close). PC key K toggles the compact Lab too (not while typing).
-- Mouse: while open, MouseBehavior Default and the cursor shown right after ShoulderCam (RenderStep "LabMouse", Camera + 1).
-- Switch: script attribute LabEnabled (default true), read at start; false -> no Lab, no SKILLS button.
-- Diagnostics (LocalPlayer attributes, this client): LabVersion, LabOpen ("closed" / "full" / "compact"), LabTab
--   ("parts" / "stats"), LabSelected (path id), LabSlotSel (0 / 1..4), LabLastPress, LabToast, LabCards, LabModels
--   (cards with a 3D model).
-- v1.1 (Kepu 2026-10-29, phone screenshot: "look part of the menu is blocked"): the full Lab's top bar is at least as tall
--   as the Roblox top bar (GuiService.TopbarInset height + 0.6ch; the Roblox buttons on phones reach below the 1.0 bar and
--   covered the MECH PARTS / STATS tabs); its items stay centred in it, so the body starts below the Roblox buttons.
--   Switch: script attribute LabBarClearEnabled (default true; false = the 1.0 bar height). Diagnostic: LabBarH (px).
-- v1.2 (Kepu 2026-10-29: "We need to have two sections. Stats. And mecha abilities. Anything passive goes to stats";
--   mockup docs/mockups/menu_lab_v2_options.html, STATS option 1 "Stat rows + part cards"): the tabs read MECHA ABILITIES /
--   STATS. MECHA ABILITIES = this dino's mech parts that are buttons (SkillTree.BUTTONS), as cards. STATS = the stat rows,
--   then (when this dino has any) a label "ALWAYS ON PARTS" (volt, RobotoMono max(1.5ch, 8)) and the always-on mech parts
--   (mech, not BUTTONS) as the same 3D cards in a 2-column grid. The STATS tab scrolls as one list (gap 1ch). LabTab values
--   stay "parts" / "stats". Switch: script attribute LabSplitTabsEnabled (default true, read at start; false = the 1.1
--   tabs: every mech part on MECH PARTS). The detail line of a button part reads "MECHA ABILITY · BUTTON". Diagnostic:
--   LabPassiveCards (always-on part cards on the STATS tab).
-- v1.3 (Kepu 2026-10-29: "when I select a weapon in the slots it doesn't tell me to the right what the weapon is"):
--   tapping a slot that holds a part (when the tap selects that slot) also selects that part: the detail panel on the
--   right shows it, its card gets the white stroke, and the MECHA ABILITIES tab opens if STATS was showing. The rest of
--   the slot tap is as before (equip a selected unslotted part there / select / deselect the slot; then a card tap
--   equips into the selected slot). Switch: script attribute LabSlotShowsPartEnabled (default true, read at start;
--   false = 1.2). Diagnostic: LabSelected follows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local VERSION = "1.3"
local BIND = "LabMouse"
local PANEL = Color3.fromRGB(20, 20, 26)
local PANEL2 = Color3.fromRGB(28, 34, 48)
local YELLOW = Color3.fromRGB(255, 200, 50)
local ORANGE = Color3.fromRGB(255, 155, 46)
local VOLT = Color3.fromRGB(127, 233, 255)
local GOLD = Color3.fromRGB(255, 214, 102)
local GREY = Color3.fromRGB(207, 211, 220)
local MUTED = Color3.fromRGB(143, 153, 170)
local WHITE = Color3.new(1, 1, 1)
local DARK_TEXT = Color3.fromRGB(27, 20, 6)
local ROMAN = {"I", "II", "III", "★"}
local SLOT_KEYS = UserInputService.TouchEnabled and {"R", "C", "R▼", "C▼"} or {"R", "C", "T", "V"}
local DINO_NAMES = {TRex = "T-REX", Raptor = "RAPTOR"}

local player = Players.LocalPlayer
player:SetAttribute("LabVersion", VERSION)
player:SetAttribute("LabOpen", "closed")
if script:GetAttribute("LabEnabled") == nil then script:SetAttribute("LabEnabled", true) end
if script:GetAttribute("LabBarClearEnabled") == nil then script:SetAttribute("LabBarClearEnabled", true) end -- v1.1
if script:GetAttribute("LabSplitTabsEnabled") == nil then script:SetAttribute("LabSplitTabsEnabled", true) end -- v1.2
local splitTabs = script:GetAttribute("LabSplitTabsEnabled") ~= false -- v1.2
if script:GetAttribute("LabSlotShowsPartEnabled") == nil then script:SetAttribute("LabSlotShowsPartEnabled", true) end -- v1.3
local slotShowsPart = script:GetAttribute("LabSlotShowsPartEnabled") ~= false -- v1.3
if script:GetAttribute("LabEnabled") == false then return end

local shared = ReplicatedStorage:WaitForChild("SkillShared", 30)
local remote = ReplicatedStorage:WaitForChild("SkillRequest", 30)
if not shared or not remote then return end
local ST = require(shared:WaitForChild("SkillTree"))
local pg = player:WaitForChild("PlayerGui")
for _, n in ipairs({"Lab", "LabButton"}) do
	local old = pg:FindFirstChild(n)
	if old then old:Destroy() end
end

-- ---------- helpers ----------
local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(0, 8) c.Parent = p return c end
local function stroke(p, color, t, th)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color, s.Transparency, s.Thickness = color, t, th
	s.Parent = p
	return s
end
local function frame(parent, name, color, transp)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	if color then
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transp or 0
	else
		f.BackgroundTransparency = 1
	end
	f.Parent = parent
	return f
end
local function label(parent, name, font, size, color, text)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text or ""
	l.Parent = parent
	return l
end
local function button(parent, name, color, transp)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = color or PANEL
	b.BackgroundTransparency = transp or 0
	b.Parent = parent
	return b
end
local function pad(p, l, r, t, b)
	local u = Instance.new("UIPadding")
	u.PaddingLeft, u.PaddingRight = UDim.new(0, l or 0), UDim.new(0, r or l or 0)
	u.PaddingTop, u.PaddingBottom = UDim.new(0, t or 0), UDim.new(0, b or t or 0)
	u.Parent = p
	return u
end
local function list(p, dir, gap, halign, valign)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if halign then l.HorizontalAlignment = halign end
	if valign then l.VerticalAlignment = valign end
	l.Parent = p
	return l
end
local function topInset()
	local ok, v = pcall(function() return GuiService.TopbarInset.Height end)
	if ok and type(v) == "number" then return v else return 58 end
end
local function topLeftClear() -- where the free top bar starts on the left (right of the Roblox buttons)
	local ok, v = pcall(function() return GuiService.TopbarInset.Min.X end)
	if ok and type(v) == "number" and v > 0 then return v else return 220 end
end

-- ---------- data ----------
local function species()
	local c = player.Character
	local sp = c and c:GetAttribute("Species")
	if type(sp) == "string" and sp ~= "" then return sp end
	sp = player:GetAttribute("DinoSpecies")
	if type(sp) == "string" and sp ~= "" then return sp end
	return "TRex"
end
local function stepsOf(id) return tonumber(player:GetAttribute("SkillPath_" .. id)) or 0 end
local function allSteps()
	local t = {}
	for _, id in ipairs(ST.PATH_ORDER) do t[id] = stepsOf(id) end
	return t
end
local function slotOf(n)
	local v = player:GetAttribute("SkillSlot" .. n)
	if type(v) == "string" and v ~= "" then return v else return nil end
end
local function slotIndex(id)
	for n = 1, ST.SLOTS do
		if slotOf(n) == id then return n end
	end
	return nil
end
local function areaOf(id)
	for _, a in ipairs(ST.AREAS) do
		for _, p in ipairs(a.paths) do
			if p.id == id then return a end
		end
	end
	return ST.AREAS[1]
end
local function pathsFor(dino, mech)
	local out = {}
	for _, a in ipairs(ST.AREAS) do
		local ps = ST.pathsFor and ST.pathsFor(a.id, dino) or a.paths
		for _, p in ipairs(ps) do
			if (p.mech == true) == mech then table.insert(out, p.id) end
		end
	end
	return out
end
local function equippable(id)
	local p = ST.PATHS[id]
	return p ~= nil and ST.BUTTONS[id] == true and not p.soon and stepsOf(id) >= 1
		and (not ST.seesPath or ST.seesPath(p, species()))
end
local function stepText(p, i)
	local s = p.steps[i]
	if type(s) == "table" then return s.text or s.desc or tostring(s[1] or "") end
	return tostring(s or "")
end

-- ---------- screen ----------
local gui = Instance.new("ScreenGui")
gui.Name = "Lab"
gui.DisplayOrder = 45
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = pg

local root = button(gui, "Root", Color3.new(0, 0, 0), 0.55) -- dim (compact) / backdrop (full); takes every touch
root.Size = UDim2.fromScale(1, 1)
local box = frame(root, "Box", WHITE, 0) -- the Lab itself (full screen or the compact panel)
local boxGrad = Instance.new("UIGradient")
boxGrad.Rotation = 90
boxGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 20, 29)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(26, 33, 48)), ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 18, 25))})
boxGrad.Parent = box
local boxCorner = corner(box)
local boxStroke = stroke(box, VOLT, 0.7, 2)
box.ClipsDescendants = true

-- top bar
local bar = frame(box, "Bar", Color3.fromRGB(14, 18, 26), 0.04)
local barLine = frame(bar, "Line", VOLT, 0.75)
barLine.AnchorPoint = Vector2.new(0, 1)
local barLeft = frame(bar, "Left")
local barLeftList = list(barLeft, Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center)
local nameL = label(barLeft, "Name", Enum.Font.FredokaOne, 24, WHITE)
nameL.RichText = true
nameL.AutomaticSize = Enum.AutomaticSize.X
nameL.LayoutOrder = 1
local lvL = label(barLeft, "Level", Enum.Font.GothamBlack, 12, GREY)
lvL.AutomaticSize = Enum.AutomaticSize.X
lvL.LayoutOrder = 2
local xpBack = frame(barLeft, "XP", WHITE, 0.88)
xpBack.LayoutOrder = 3
corner(xpBack, UDim.new(1, 0))
local xpFill = frame(xpBack, "Fill", YELLOW)
corner(xpFill, UDim.new(1, 0))
local masL = label(barLeft, "Mastery", Enum.Font.GothamBlack, 12, GOLD)
masL.AutomaticSize = Enum.AutomaticSize.X
masL.LayoutOrder = 4
local masCorner = corner(masL)
local masStroke = stroke(masL, GOLD, 0.4, 2)
local masPad = pad(masL, 8)
local barRight = frame(bar, "Right")
barRight.AnchorPoint = Vector2.new(1, 0)
local barRightList = list(barRight, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
local ptsL = label(barRight, "Points", Enum.Font.FredokaOne, 16, DARK_TEXT)
ptsL.BackgroundTransparency = 0
ptsL.BackgroundColor3 = YELLOW
ptsL.AutomaticSize = Enum.AutomaticSize.X
ptsL.LayoutOrder = 1
local ptsCorner = corner(ptsL)
local ptsPad = pad(ptsL, 10)
local closeB = button(barRight, "Close", PANEL)
closeB.LayoutOrder = 2
local closeCorner = corner(closeB)
stroke(closeB, WHITE, 0.84, 2)
local closeX = label(closeB, "X", Enum.Font.FredokaOne, 16, WHITE, "X") -- "✕" draws as a box in the game fonts
closeX.Size = UDim2.fromScale(1, 1)

-- body columns
local body = frame(box, "Body")
local left = frame(body, "Left")
local mid = frame(body, "Mid")
local right = frame(body, "Right")

-- left: tabs + grid
local tabs = frame(left, "Tabs")
local tabParts = button(tabs, "Parts", WHITE, 0.94)
local tabStats = button(tabs, "Stats", WHITE, 0.94)
local tabCorners, tabStrokes, tabLabels = {}, {}, {}
for i, t in ipairs({tabParts, tabStats}) do
	tabCorners[i] = corner(t)
	tabStrokes[i] = stroke(t, VOLT, 1, 2)
	tabLabels[i] = label(t, "T", Enum.Font.GothamBlack, 11, MUTED, i == 1 and (splitTabs and "MECHA ABILITIES" or "MECH PARTS") or "STATS")
	tabLabels[i].Size = UDim2.fromScale(1, 1)
end
local grid = Instance.new("ScrollingFrame")
grid.Name = "Grid"
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 4
grid.ScrollBarImageColor3 = VOLT
grid.ScrollingDirection = Enum.ScrollingDirection.Y
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.Parent = left
local gridLayout = Instance.new("UIGridLayout")
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
pad(grid, 3, 0, 3, 3) -- room for the 2 px selected / equipped stroke (the scrolling frame clips it otherwise)
local gridList = Instance.new("UIListLayout") -- v1.2: the STATS tab (rows, label, always-on part cards) as one list
gridList.SortOrder = Enum.SortOrder.LayoutOrder

-- middle: stage + slots + hint
local stage = frame(mid, "Stage", PANEL, 0.1)
local stageCorner = corner(stage)
stroke(stage, WHITE, 0.88, 2)
stage.ClipsDescendants = true
local floor = frame(stage, "Floor", VOLT, 0.72)
floor.AnchorPoint = Vector2.new(0.5, 0.5)
floor.Position = UDim2.fromScale(0.5, 0.86)
floor.Size = UDim2.fromScale(0.72, 0.07)
corner(floor, UDim.new(0.5, 0))
local floorGrad = Instance.new("UIGradient")
floorGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3),
	NumberSequenceKeypoint.new(1, 1)})
floorGrad.Parent = floor
local view = Instance.new("ViewportFrame")
view.Name = "View"
view.Size = UDim2.fromScale(1, 1)
view.BackgroundTransparency = 1
view.Ambient = Color3.fromRGB(150, 150, 160)
view.LightColor = Color3.fromRGB(255, 250, 240)
view.LightDirection = Vector3.new(-0.4, -1, -0.6)
view.Parent = stage
local cam = Instance.new("Camera")
cam.FieldOfView = 40
cam.Parent = view
view.CurrentCamera = cam
local stageTag = label(stage, "Tag", Enum.Font.RobotoMono, 11, VOLT, "ALL UPGRADES")
stageTag.BackgroundTransparency = 0.6
stageTag.BackgroundColor3 = Color3.new(0, 0, 0)
stageTag.AutomaticSize = Enum.AutomaticSize.X
local stageTagCorner = corner(stageTag)
local stageTagPad = pad(stageTag, 8)
local slotsRow = frame(mid, "Slots")
local slotBtns = {}
for n = 1, ST.SLOTS do
	local b = button(slotsRow, "Slot_" .. n, WHITE, 0.94)
	local c = corner(b)
	local s = stroke(b, ORANGE, 0.45, 2)
	local k = label(b, "Key", Enum.Font.GothamBlack, 12, ORANGE, SLOT_KEYS[n] or tostring(n))
	local icon = Instance.new("ViewportFrame")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Ambient = Color3.fromRGB(170, 170, 180)
	icon.Parent = b
	local icam = Instance.new("Camera")
	icam.FieldOfView = 30
	icam.Parent = icon
	icon.CurrentCamera = icam
	local nm = label(b, "Name", Enum.Font.GothamBlack, 11, GREY)
	nm.TextXAlignment = Enum.TextXAlignment.Left
	nm.TextTruncate = Enum.TextTruncate.AtEnd
	nm.TextWrapped, nm.TextScaled = true, true -- long names wrap to 2 lines / shrink to 8 px before cutting
	local fit = Instance.new("UITextSizeConstraint")
	fit.Name = "Fit"
	fit.MinTextSize, fit.MaxTextSize = 8, 11
	fit.Parent = nm
	slotBtns[n] = {b = b, corner = c, stroke = s, key = k, icon = icon, cam = icam, name = nm}
end
local hint = label(mid, "Hint", Enum.Font.GothamBlack, 10, MUTED, "Tap a card, then EQUIP · tap a slot to choose where it goes")
hint.TextWrapped = true

-- right: detail
local detail = Instance.new("ScrollingFrame")
detail.Name = "Detail"
detail.BackgroundColor3 = PANEL
detail.BackgroundTransparency = 0.1
detail.BorderSizePixel = 0
detail.ScrollBarThickness = 3
detail.ScrollBarImageColor3 = VOLT
detail.AutomaticCanvasSize = Enum.AutomaticSize.Y
detail.CanvasSize = UDim2.new()
detail.Parent = right
local detailCorner = corner(detail)
stroke(detail, WHITE, 0.88, 2)
local detailPad = pad(detail, 12)
local detailList = list(detail, Enum.FillDirection.Vertical, 8)

-- toast
local toast = label(box, "Toast", Enum.Font.FredokaOne, 16, YELLOW)
toast.BackgroundColor3 = PANEL
toast.BackgroundTransparency = 0.05
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.AutomaticSize = Enum.AutomaticSize.X
toast.Visible = false
toast.ZIndex = 10
local toastCorner = corner(toast)
stroke(toast, YELLOW, 0, 2)
local toastPad = pad(toast, 16)

-- ---------- state ----------
local mode = nil -- nil / "full" / "compact"
local tab = "parts"
local selected = nil
local slotSel = nil
local cards = {} -- {id, b, view, cam, model, angle}
local S = {}
local toastToken = 0
local stagePreview, stageKey = nil, nil
local center, radius, orbit = Vector3.zero, 20, 0
local stageSize = Vector3.new(20, 20, 20)
-- turntable fit: the widest the model gets while turning is its X/Z diagonal; fit that to the stage width (aspect) and
-- the height (plus the depth the 0.32 camera tilt shows) to the stage height; 1.12 margin
local function stageRadius()
	local a = view.AbsoluteSize
	local aspect = (a.Y > 0 and a.X > 0) and a.X / a.Y or 1
	local t = math.tan(math.rad(cam.FieldOfView / 2))
	local w = math.sqrt(stageSize.X ^ 2 + stageSize.Z ^ 2)
	local hNeed = ((stageSize.Y + 0.3 * w) * 0.5) / t
	local wNeed = (w * 0.5) / (t * aspect)
	return math.max(hNeed, wNeed) * 1.12
end
local pulseUntil = 0

local function press(v) player:SetAttribute("LabLastPress", v) end
local function showToast(text)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.Visible = true
	player:SetAttribute("LabToast", text)
	task.delay(1.8, function()
		if toastToken == my then
			toast.Visible = false
			player:SetAttribute("LabToast", "")
		end
	end)
end

-- ---------- measuring ----------
local function measure()
	local W, H = root.AbsoluteSize.X, root.AbsoluteSize.Y
	local ch, cw = H / 100, W / 100
	S.W, S.H, S.ch, S.cw = W, H, ch, cw
	if mode == "compact" then
		local top = math.max(10 * ch, topInset() + ch) -- below the Roblox top bar (58 px on phones, more than 10ch there)
		S.bx, S.by, S.bw, S.bh = 11 * cw, top, W - 22 * cw, H - top - 6 * ch
		S.barLeftPad = 2 * cw
		S.colL, S.colR = 0.34, 0.30
	else
		S.bx, S.by, S.bw, S.bh = 0, 0, W, H
		S.barLeftPad = math.max(10 * ch, topLeftClear() + 1.6 * ch)
		S.colL, S.colR = 0.31, 0.27
	end
	S.nameS = math.max(3.4 * ch, 16)
	S.small = math.max(1.8 * ch, 10)
	S.closeS = math.max(5 * ch, 30)
	S.barH = 1.4 * ch + math.max(S.closeS, S.nameS * 1.1) + 1.2 * ch
	if mode ~= "compact" and script:GetAttribute("LabBarClearEnabled") ~= false then -- v1.1: clear the Roblox top bar
		S.barH = math.max(S.barH, topInset() + 0.6 * ch)
	end
	player:SetAttribute("LabBarH", math.floor(S.barH + 0.5))
	S.tabText = math.max(1.7 * ch, 10)
	S.cardName = math.max(1.9 * ch, 11)
	S.pip = math.max(1.6 * ch, 7)
	S.tagS = math.max(1.6 * ch, 9)
	S.slotH = math.max(6 * ch, 34)
	S.hintS = math.max(1.5 * ch, 10)
	S.stepS = math.max(1.6 * ch, 10)
	S.btnH = math.max(5.6 * ch, 34)
end

-- ---------- pips / tags ----------
local function pips(parent, id, size)
	local holder = frame(parent, "Pips")
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Size = UDim2.fromOffset(0, size)
	list(holder, Enum.FillDirection.Horizontal, math.max(size * 0.3, 2), nil, Enum.VerticalAlignment.Center)
	local col = rgb(areaOf(id).color)
	local n = stepsOf(id)
	for i = 1, 4 do
		local p = frame(holder, "Pip" .. i, i <= n and col or WHITE, i <= n and 0 or 0.86)
		p.Size = UDim2.fromOffset(size, size)
		p.LayoutOrder = i
		corner(p, i == 4 and UDim.new(0.5, 0) or UDim.new(0.25, 0))
	end
	return holder
end

-- ---------- model views ----------
local function framing(model)
	local cf, size = model:GetBoundingBox()
	return cf.Position, math.max(size.X, size.Y, size.Z)
end
local function previewOf(id)
	local f = ReplicatedStorage:FindFirstChild("LabPreviews")
	local m = f and f:FindFirstChild(id)
	if m then return m:Clone() end
	return nil
end

-- ---------- drawing ----------
local redraw

local function equip(id, n)
	press(("equip:%s:%d"):format(id, n))
	remote:FireServer("slot", n, id)
	slotSel = nil
	showToast(("%s → %s"):format(ST.PATHS[id].name, SLOT_KEYS[n] or tostring(n)))
end

local function drawCards()
	for _, c in ipairs(cards) do c.b:Destroy() end
	table.clear(cards)
	for _, ch in ipairs(grid:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local dino = species()
	local ids = pathsFor(dino, tab == "parts")
	local cardOf = {} -- v1.2: id -> true when drawn as a 3D card
	local passive = {}
	if splitTabs then -- v1.2: MECHA ABILITIES = button parts; STATS = stats + always-on parts
		local mech = pathsFor(dino, true)
		if tab == "parts" then
			ids = {}
			for _, id in ipairs(mech) do
				if ST.BUTTONS[id] == true then table.insert(ids, id) end
			end
		else
			for _, id in ipairs(mech) do
				if ST.BUTTONS[id] ~= true then table.insert(passive, id) end
			end
		end
	end
	if tab == "parts" then
		for _, id in ipairs(ids) do cardOf[id] = true end
		gridList.Parent = nil
		gridLayout.Parent = grid
	else
		gridLayout.Parent = nil
		gridList.Parent = grid
	end
	local passiveBox
	if #passive > 0 then
		local sec = label(grid, "PassiveLabel", Enum.Font.RobotoMono, math.max(1.5 * S.ch, 8), VOLT, "ALWAYS ON PARTS")
		sec.TextXAlignment = Enum.TextXAlignment.Left
		sec.TextYAlignment = Enum.TextYAlignment.Bottom
		sec.LayoutOrder = #ids + 1
		sec.Size = UDim2.fromOffset(S.rowW, math.max(1.5 * S.ch, 8) + 0.6 * S.ch)
		passiveBox = frame(grid, "Passive")
		passiveBox.LayoutOrder = #ids + 2
		passiveBox.AutomaticSize = Enum.AutomaticSize.Y
		passiveBox.Size = UDim2.fromOffset(S.rowW, 0)
		local pg2 = Instance.new("UIGridLayout")
		pg2.SortOrder = Enum.SortOrder.LayoutOrder
		pg2.CellSize = S.cardCell
		pg2.CellPadding = UDim2.fromOffset(S.ch, S.ch)
		pg2.Parent = passiveBox
		for _, id in ipairs(passive) do
			table.insert(ids, id)
			cardOf[id] = true
		end
	end
	player:SetAttribute("LabPassiveCards", #passive)
	local models = 0
	if not selected or not table.find(ids, selected) then selected = ids[1] end
	for i, id in ipairs(ids) do
		local p = ST.PATHS[id]
		local area = areaOf(id)
		local col = rgb(area.color)
		local n = stepsOf(id)
		local eq = slotIndex(id)
		local asCard = cardOf[id] == true
		local b = button(asCard and tab ~= "parts" and passiveBox or grid, "Card_" .. id, PANEL2, 0)
		b.LayoutOrder = i
		if not asCard then b.Size = UDim2.fromOffset(S.rowW, S.rowH) end -- v1.2: rows sit in the STATS list
		corner(b, UDim.new(0, 1.4 * S.ch))
		local st
		if selected == id then
			st = stroke(b, WHITE, 0, 2.5)
		elseif eq then
			st = stroke(b, ORANGE, 0.1, 2)
		else
			st = stroke(b, WHITE, 0.9, 2)
		end
		local entry = {id = id, b = b}
		if asCard then
			local p1 = S.ch
			local artW = S.cellW - 2 * p1
			local artH = artW * 0.75
			local art = frame(b, "Art", Color3.fromRGB(10, 14, 22), 0.2)
			art.Position, art.Size = UDim2.fromOffset(p1, p1), UDim2.fromOffset(artW, artH)
			corner(art, UDim.new(0, S.ch))
			local glow = Instance.new("UIGradient")
			glow.Rotation = 90
			glow.Color = ColorSequence.new(Color3.fromRGB(14, 20, 30), Color3.fromRGB(30, 60, 72))
			glow.Parent = art
			local m = (not p.soon) and previewOf(id) or nil
			if m then
				local vf = Instance.new("ViewportFrame")
				vf.Name = "Model"
				vf.BackgroundTransparency = 1
				vf.Size = UDim2.fromScale(1, 1)
				vf.Ambient = Color3.fromRGB(160, 160, 170)
				vf.LightDirection = Vector3.new(-0.4, -1, -0.6)
				vf.Parent = art
				local c = Instance.new("Camera")
				c.FieldOfView = 30
				c.Parent = vf
				vf.CurrentCamera = c
				m.Parent = vf
				local ctr, size = framing(m)
				entry.cam, entry.center = c, ctr
				entry.radius = (size * 0.5) / math.tan(math.rad(15)) * 1.15
				entry.angle = i * 0.9
				models += 1
			else
				local q = label(art, "Q", Enum.Font.FredokaOne, math.max(artH * 0.3, 12), MUTED, p.soon and "SOON" or "?")
				q.Size = UDim2.fromScale(1, 1)
				q.TextTransparency = 0.3
			end
			local nm = label(b, "Name", Enum.Font.FredokaOne, S.cardName, WHITE, p.name)
			nm.TextXAlignment = Enum.TextXAlignment.Left
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			nm.Position = UDim2.fromOffset(p1, p1 + artH + 0.6 * S.ch)
			nm.Size = UDim2.fromOffset(artW, S.cardName * 1.15)
			local metaY = p1 + artH + 0.6 * S.ch + S.cardName * 1.15 + 0.6 * S.ch
			local pp = pips(b, id, S.pip)
			pp.Position = UDim2.fromOffset(p1, metaY + (S.metaH - S.pip) / 2)
			local tagText = n == 0 and "NEW" or ROMAN[n]
			local tg = label(b, "Step", Enum.Font.GothamBlack, S.tagS, n == 0 and YELLOW or col, tagText)
			tg.BackgroundTransparency = 0.65
			tg.BackgroundColor3 = Color3.new(0, 0, 0)
			tg.AutomaticSize = Enum.AutomaticSize.X
			tg.AnchorPoint = Vector2.new(1, 0)
			tg.Position = UDim2.fromOffset(p1 + artW, metaY)
			tg.Size = UDim2.fromOffset(0, S.metaH)
			corner(tg, UDim.new(0, 0.8 * S.ch))
			pad(tg, 0.8 * S.ch)
			local badgeText, badgeCol, badgeTxt
			if p.soon then
				badgeText, badgeCol, badgeTxt = "SOON", Color3.fromRGB(90, 96, 110), WHITE
			elseif ST.BUTTONS[id] ~= true then
				badgeText, badgeCol, badgeTxt = "ALWAYS ON", VOLT, Color3.fromRGB(6, 36, 48)
			elseif eq then
				badgeText, badgeCol, badgeTxt = SLOT_KEYS[eq] or tostring(eq), ORANGE, DARK_TEXT
			end
			if badgeText then
				local bd = label(b, "Badge", Enum.Font.GothamBlack, S.tagS, badgeTxt, badgeText)
				bd.BackgroundTransparency = 0
				bd.BackgroundColor3 = badgeCol
				bd.AutomaticSize = Enum.AutomaticSize.X
				bd.AnchorPoint = Vector2.new(1, 0)
				bd.Position = UDim2.fromOffset(p1 + artW - 0.6 * S.ch, p1 + 0.6 * S.ch)
				bd.Size = UDim2.fromOffset(0, S.tagS + 0.8 * S.ch)
				corner(bd, UDim.new(0, 0.7 * S.ch))
				pad(bd, 0.6 * S.ch)
			end
			if p.soon then b.BackgroundTransparency = 0.45 end
		else
			-- stats row
			local px = 1.4 * S.ch
			local nm = label(b, "Name", Enum.Font.FredokaOne, S.cardName, WHITE, p.name)
			nm.TextXAlignment = Enum.TextXAlignment.Left
			nm.Position = UDim2.fromOffset(px, 1.2 * S.ch)
			nm.Size = UDim2.new(1, -2 * px, 0, S.cardName * 1.15)
			local pp = pips(b, id, S.pip)
			pp.AnchorPoint = Vector2.new(1, 0)
			pp.Position = UDim2.new(1, -px, 0, 1.2 * S.ch + (S.cardName * 1.15 - S.pip) / 2)
			local ar = label(b, "Area", Enum.Font.GothamBlack, S.tagS, col, string.upper(area.name))
			ar.TextXAlignment = Enum.TextXAlignment.Left
			ar.Position = UDim2.fromOffset(px, 1.2 * S.ch + S.cardName * 1.15 + 0.6 * S.ch)
			ar.Size = UDim2.new(0.5, -px, 0, S.metaH)
			local nx = label(b, "Next", Enum.Font.GothamBlack, S.tagS, MUTED, n < 4 and ("Next: %d %s"):format(ST.COST[n + 1], ST.COST[n + 1] == 1 and "pt" or "pts") or "Maxed")
			nx.TextXAlignment = Enum.TextXAlignment.Right
			nx.AnchorPoint = Vector2.new(1, 0)
			nx.Position = UDim2.new(1, -px, 0, 1.2 * S.ch + S.cardName * 1.15 + 0.6 * S.ch)
			nx.Size = UDim2.new(0.5, -px, 0, S.metaH)
		end
		b.Activated:Connect(function()
			press("card:" .. id)
			if slotSel and equippable(id) then
				equip(id, slotSel)
			end
			selected = id
			redraw()
		end)
		table.insert(cards, entry)
	end
	player:SetAttribute("LabCards", #ids)
	player:SetAttribute("LabModels", models)
	player:SetAttribute("LabSelected", selected or "")
end

local function drawSlots()
	local selOk = selected and equippable(selected) and not slotIndex(selected)
	for n, s in ipairs(slotBtns) do
		local id = slotOf(n)
		local p = id and ST.PATHS[id]
		s.name.Text = p and p.name or "empty"
		s.name.TextColor3 = p and GREY or MUTED
		if slotSel == n then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0, 3
		elseif os.clock() < pulseUntil or selOk then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0.35, 2
		elseif p then
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = ORANGE, 0.45, 2
		else
			s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = WHITE, 0.86, 2
		end
		for _, ch in ipairs(s.icon:GetChildren()) do
			if ch:IsA("Model") then ch:Destroy() end
		end
		local m = id and previewOf(id)
		if m then
			m.Parent = s.icon
			local ctr, size = framing(m)
			s.cam.CFrame = CFrame.lookAt(ctr + Vector3.new(0.8, 0.5, -1).Unit * ((size * 0.5) / math.tan(math.rad(15)) * 1.1), ctr)
		end
	end
	player:SetAttribute("LabSlotSel", slotSel or 0)
end

local function detailButton(parent, text, color, txtColor, enabled, order)
	local b = button(parent, "Btn", color, enabled and 0 or 0.55)
	b.LayoutOrder = order
	corner(b, UDim.new(0, 1.6 * S.ch))
	local shade = frame(b, "Band", Color3.new(0, 0, 0), 0.78)
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.fromScale(0, 1)
	shade.Size = UDim2.new(1, 0, 0, 0.9 * S.ch)
	corner(shade, UDim.new(0, 1.6 * S.ch))
	local l = label(b, "T", Enum.Font.FredokaOne, math.max(2.1 * S.ch, 12), txtColor, text)
	l.Size = UDim2.fromScale(1, 1)
	l.TextTransparency = enabled and 0 or 0.35
	l.TextScaled = false
	l.TextWrapped = true
	return b
end

local function drawDetail()
	for _, ch in ipairs(detail:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	detailPad.PaddingLeft, detailPad.PaddingRight = UDim.new(0, 1.6 * S.ch), UDim.new(0, 1.6 * S.ch)
	detailPad.PaddingTop, detailPad.PaddingBottom = UDim.new(0, 1.6 * S.ch), UDim.new(0, 1.6 * S.ch)
	detailList.Padding = UDim.new(0, S.ch)
	local id = selected
	local p = id and ST.PATHS[id]
	if not p then
		local h = label(detail, "Empty", Enum.Font.GothamBlack, S.stepS, MUTED, "Pick a card to see its steps.")
		h.Size = UDim2.new(1, 0, 0, S.stepS * 2)
		return
	end
	local area = areaOf(id)
	local col = rgb(area.color)
	local n = stepsOf(id)
	local kind = p.mech ~= true and "Stat" or (ST.BUTTONS[id] == true and (splitTabs and "Mecha ability · button" or "Mech part · button") or "Mech part · always on") -- v1.2 wording
	local sub = label(detail, "Sub", Enum.Font.GothamBlack, S.stepS, col, string.upper(area.name .. " · " .. kind))
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Size = UDim2.new(1, 0, 0, S.stepS * 1.2)
	sub.LayoutOrder = 1
	local ttl = label(detail, "Title", Enum.Font.FredokaOne, math.max(3 * S.ch, 15), WHITE, p.name)
	ttl.TextXAlignment = Enum.TextXAlignment.Left
	ttl.TextWrapped = true
	ttl.AutomaticSize = Enum.AutomaticSize.Y
	ttl.Size = UDim2.new(1, 0, 0, 0)
	ttl.LayoutOrder = 2
	local stepsBox = frame(detail, "Steps")
	stepsBox.AutomaticSize = Enum.AutomaticSize.Y
	stepsBox.Size = UDim2.new(1, 0, 0, 0)
	stepsBox.LayoutOrder = 3
	list(stepsBox, Enum.FillDirection.Vertical, math.max(0.9 * S.ch, 5))
	for i = 1, 4 do
		local row = frame(stepsBox, "Step" .. i)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = i
		local bw = math.max(3.4 * S.ch, 20)
		local bd = label(row, "N", Enum.Font.GothamBlack, math.max(1.7 * S.ch, 10), MUTED, ROMAN[i])
		bd.BackgroundTransparency = 0.9
		bd.BackgroundColor3 = WHITE
		bd.Size = UDim2.fromOffset(bw, math.max(3 * S.ch, 18))
		corner(bd, UDim.new(0, 0.7 * S.ch))
		local tx = label(row, "Text", Enum.Font.GothamBold, S.stepS, MUTED, stepText(p, i))
		tx.TextXAlignment = Enum.TextXAlignment.Left
		tx.TextYAlignment = Enum.TextYAlignment.Top
		tx.TextWrapped = true
		tx.AutomaticSize = Enum.AutomaticSize.Y
		tx.Position = UDim2.fromOffset(bw + 0.8 * S.ch, 0)
		tx.Size = UDim2.new(1, -(bw + 0.8 * S.ch), 0, math.max(3 * S.ch, 18))
		-- first line centred on the badge; wrapped lines run on below it
		pad(tx, 0, 0, math.max((math.max(3 * S.ch, 18) - S.stepS * 1.15) / 2, 0), 0)
		if i <= n then
			bd.BackgroundColor3, bd.BackgroundTransparency, bd.TextColor3 = col, 0, DARK_TEXT
			tx.TextColor3 = GREY
		elseif i == n + 1 then
			stroke(bd, WHITE, 0, 2)
			bd.TextColor3 = WHITE
			tx.TextColor3 = WHITE
		end
	end
	-- buttons
	local acts = frame(detail, "Actions")
	acts.Size = UDim2.new(1, 0, 0, S.btnH)
	acts.LayoutOrder = 4
	local ok, why = ST.canBuy(allSteps(), id, tonumber(player:GetAttribute("SkillPoints")) or 0, species())
	local buyText
	if ok then
		local cost = ST.COST[n + 1]
		buyText = ("%s · %d PT%s"):format(n == 0 and "BUY" or "UPGRADE", cost, cost > 1 and "S" or "")
	elseif why == "maxed" then
		buyText = "MAXED"
	elseif why == "masteryFull" then
		buyText = "MASTERY FULL"
	elseif why == "noPoints" then
		buyText = ("NEED %d %s"):format(ST.COST[n + 1] or 0, ST.COST[n + 1] == 1 and "PT" or "PTS")
	elseif why == "soon" then
		buyText = "COMING SOON"
	else
		buyText = "LOCKED"
	end
	local eqBtn = nil
	local eqIdx = slotIndex(id)
	local showEquip = ST.BUTTONS[id] == true and not p.soon and n >= 1
	local gap = S.ch
	local buy = detailButton(acts, buyText, ok and YELLOW or PANEL, ok and DARK_TEXT or WHITE, ok, 1)
	if showEquip then
		buy.Size = UDim2.new(0.5, -gap / 2, 1, 0)
		if eqIdx then
			eqBtn = detailButton(acts, "UNEQUIP " .. (SLOT_KEYS[eqIdx] or tostring(eqIdx)), PANEL, WHITE, true, 2)
		else
			eqBtn = detailButton(acts, "EQUIP", ORANGE, DARK_TEXT, true, 2)
		end
		eqBtn.Position = UDim2.new(0.5, gap / 2, 0, 0)
		eqBtn.Size = UDim2.new(0.5, -gap / 2, 1, 0)
	else
		buy.Size = UDim2.fromScale(1, 1)
	end
	if not ok then stroke(buy, WHITE, 0.84, 2) end
	if eqBtn and eqIdx then stroke(eqBtn, WHITE, 0.84, 2) end
	buy.Activated:Connect(function()
		if not ok then return end
		press("buy:" .. id)
		remote:FireServer("buy", id)
		showToast(("%s %s"):format(p.name, ROMAN[n + 1]))
	end)
	if eqBtn then
		eqBtn.Activated:Connect(function()
			if eqIdx then
				press("unequip:" .. id)
				remote:FireServer("slot", eqIdx, "")
				showToast(p.name .. " taken off")
			else
				local target = slotSel
				if not target then
					for k = 1, ST.SLOTS do
						if not slotOf(k) then target = k break end
					end
				end
				if target then
					equip(id, target)
				else
					press("full")
					pulseUntil = os.clock() + 2
					showToast("Slots full · tap a slot to replace")
					drawSlots()
					task.delay(2.05, function() if mode then drawSlots() end end)
				end
			end
		end)
	end
	if showEquip and not eqIdx then
		local h = label(detail, "Hint", Enum.Font.GothamBlack, S.hintS, MUTED, "EQUIP fills the first empty slot, or tap a slot first to replace it.")
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.TextWrapped = true
		h.AutomaticSize = Enum.AutomaticSize.Y
		h.Size = UDim2.new(1, 0, 0, 0)
		h.LayoutOrder = 5
	end
end

local function drawBar()
	local dino = species()
	nameL.Text = ('<font color="#7fe9ff" size="%d">LAB</font>  %s'):format(math.floor(S.nameS * 0.55), DINO_NAMES[dino] or string.upper(dino))
	lvL.Text = "LV " .. tostring(player:GetAttribute("SkillLevel") or 1)
	local into, nxt = tonumber(player:GetAttribute("SkillXPInto")) or 0, tonumber(player:GetAttribute("SkillXPNext")) or 0
	xpFill.Size = UDim2.fromScale(nxt > 0 and math.clamp(into / nxt, 0, 1) or 1, 1)
	local mastered = ST.mastered and #ST.mastered(allSteps(), dino) or 0
	masL.Text = ("MASTERY %d/%d"):format(mastered, ST.MASTERY_MAX or 3)
	ptsL.Text = ("%d PTS"):format(tonumber(player:GetAttribute("SkillLeft")) or 0)
end

local function layout()
	measure()
	local ch, cw = S.ch, S.cw
	box.Position, box.Size = UDim2.fromOffset(S.bx, S.by), UDim2.fromOffset(S.bw, S.bh)
	-- bar
	bar.Size = UDim2.new(1, 0, 0, S.barH)
	barLine.Position, barLine.Size = UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, math.max(0.35 * ch, 2))
	barLeft.Position = UDim2.fromOffset(S.barLeftPad, 1.4 * ch)
	barLeft.Size = UDim2.new(1, -S.barLeftPad - 2 * cw, 0, S.barH - 2.6 * ch)
	barLeftList.Padding = UDim.new(0, 1.6 * ch)
	nameL.TextSize = S.nameS
	nameL.Size = UDim2.fromOffset(0, S.barH - 2.6 * ch)
	lvL.TextSize, lvL.Size = S.small, UDim2.fromOffset(0, S.barH - 2.6 * ch)
	xpBack.Size = UDim2.fromOffset(12 * cw, math.max(1.4 * ch, 6))
	masL.TextSize = math.max(1.7 * ch, 10)
	masL.Size = UDim2.fromOffset(0, math.max(1.7 * ch, 10) + 1.4 * ch)
	masCorner.CornerRadius = UDim.new(0, ch)
	masPad.PaddingLeft, masPad.PaddingRight = UDim.new(0, 1.2 * ch), UDim.new(0, 1.2 * ch)
	barRight.Position = UDim2.new(1, -2 * cw, 0, 1.4 * ch)
	barRight.Size = UDim2.fromOffset(40 * cw, S.barH - 2.6 * ch)
	barRightList.Padding = UDim.new(0, 1.6 * ch)
	ptsL.TextSize = math.max(2.4 * ch, 13)
	ptsL.Size = UDim2.fromOffset(0, math.max(2.4 * ch, 13) + 1.6 * ch)
	ptsCorner.CornerRadius = UDim.new(0, ch)
	ptsPad.PaddingLeft, ptsPad.PaddingRight = UDim.new(0, 1.4 * ch), UDim.new(0, 1.4 * ch)
	closeB.Size = UDim2.fromOffset(S.closeS, S.closeS)
	closeCorner.CornerRadius = UDim.new(0, 1.6 * ch)
	closeX.TextSize = math.max(2.4 * ch, 14)
	-- body
	local bx, by = 2 * cw, S.barH + 1.6 * ch
	local bw, bh = S.bw - 4 * cw, S.bh - S.barH - 1.6 * ch - 2 * ch
	body.Position, body.Size = UDim2.fromOffset(bx, by), UDim2.fromOffset(bw, bh)
	local gap = 1.6 * cw
	local lw, rw = bw * S.colL, bw * S.colR
	local mw = bw - lw - rw - 2 * gap
	left.Position, left.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(lw, bh)
	mid.Position, mid.Size = UDim2.fromOffset(lw + gap, 0), UDim2.fromOffset(mw, bh)
	right.Position, right.Size = UDim2.fromOffset(lw + gap + mw + gap, 0), UDim2.fromOffset(rw, bh)
	-- left
	local tabH = S.tabText + 1.8 * ch
	tabs.Size = UDim2.fromOffset(lw, tabH)
	local tg = 0.8 * ch
	tabParts.Position, tabParts.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset((lw - tg) / 2, tabH)
	tabStats.Position, tabStats.Size = UDim2.fromOffset((lw - tg) / 2 + tg, 0), UDim2.fromOffset((lw - tg) / 2, tabH)
	local tabBtns = {tabParts, tabStats}
	for i, t in ipairs({"parts", "stats"}) do
		tabCorners[i].CornerRadius = UDim.new(0, ch)
		tabLabels[i].TextSize = S.tabText
		local on = tab == t
		tabStrokes[i].Transparency = on and 0 or 1
		tabLabels[i].TextColor3 = on and WHITE or MUTED
		tabBtns[i].BackgroundTransparency = on and 0.86 or 0.94
		tabBtns[i].BackgroundColor3 = on and VOLT or WHITE
	end
	grid.Position, grid.Size = UDim2.fromOffset(0, tabH + 1.2 * ch), UDim2.fromOffset(lw, bh - tabH - 1.2 * ch)
	S.cellW = (lw - ch - 12) / 2 -- 3 px stroke room left, 9 px for the scroll bar
	S.metaH = math.max(S.tagS + 1 * ch, S.pip + 2)
	local artH = (S.cellW - 2 * ch) * 0.75
	S.cardCell = UDim2.fromOffset(S.cellW, ch + artH + 0.6 * ch + S.cardName * 1.15 + 0.6 * ch + S.metaH + ch) -- v1.2
	S.rowW, S.rowH = lw - 12, 1.2 * ch + S.cardName * 1.15 + 0.6 * ch + S.metaH + 1.2 * ch -- v1.2
	gridList.Padding = UDim.new(0, ch)
	if tab == "parts" then
		gridLayout.CellSize = UDim2.fromOffset(S.cellW, ch + artH + 0.6 * ch + S.cardName * 1.15 + 0.6 * ch + S.metaH + ch)
		gridLayout.CellPadding = UDim2.fromOffset(ch, ch)
	else
		gridLayout.CellSize = UDim2.fromOffset(lw - 12, 1.2 * ch + S.cardName * 1.15 + 0.6 * ch + S.metaH + 1.2 * ch)
		gridLayout.CellPadding = UDim2.fromOffset(ch, ch)
	end
	-- middle
	local hintH = S.hintS * 2.6
	local stageH = bh - 1.2 * ch - S.slotH - 1.2 * ch - hintH
	stage.Position, stage.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(mw, stageH)
	stageCorner.CornerRadius = UDim.new(0, 2 * ch)
	stageTag.TextSize = math.max(1.6 * ch, 10)
	stageTag.Position = UDim2.fromOffset(1.8 * ch, 1.8 * ch)
	stageTag.Size = UDim2.fromOffset(0, math.max(1.6 * ch, 10) + 1.2 * ch)
	stageTagCorner.CornerRadius = UDim.new(0, 0.8 * ch)
	stageTagPad.PaddingLeft, stageTagPad.PaddingRight = UDim.new(0, ch), UDim.new(0, ch)
	slotsRow.Position, slotsRow.Size = UDim2.fromOffset(0, stageH + 1.2 * ch), UDim2.fromOffset(mw, S.slotH)
	local sg = 0.8 * cw
	local sw = (mw - sg * (ST.SLOTS - 1)) / ST.SLOTS
	for n, s in ipairs(slotBtns) do
		s.b.Position, s.b.Size = UDim2.fromOffset((n - 1) * (sw + sg), 0), UDim2.fromOffset(sw, S.slotH)
		s.corner.CornerRadius = UDim.new(0, 1.2 * ch)
		local kS = math.max(1.9 * ch, 11)
		s.key.TextSize = kS
		s.key.Position, s.key.Size = UDim2.fromOffset(ch, 0), UDim2.fromOffset(kS * 1.6, S.slotH)
		local iz = math.min(S.slotH * 0.7, 4.4 * ch)
		s.icon.Position, s.icon.Size = UDim2.fromOffset(ch + kS * 1.6, (S.slotH - iz) / 2), UDim2.fromOffset(iz, iz)
		s.name.TextSize = math.max(1.6 * ch, 10)
		s.name.Fit.MaxTextSize = math.max(1.6 * ch, 10)
		local nameW = sw - (ch + kS * 1.6 + iz + 0.6 * ch) - ch
		if nameW >= 50 then
			s.name.Visible = true
			s.name.Size = UDim2.fromOffset(nameW, S.slotH - 0.8 * ch)
			s.name.Position = UDim2.fromOffset(ch + kS * 1.6 + iz + 0.6 * ch, 0.4 * ch)
		else -- narrow slot (compact Lab on a phone): key + a bigger part model, no name
			s.name.Visible = false
			local big = math.min(S.slotH * 0.86, sw - (ch + kS * 1.6) - ch)
			s.icon.Position = UDim2.fromOffset(ch + kS * 1.6 + (sw - (ch + kS * 1.6) - ch - big) / 2, (S.slotH - big) / 2)
			s.icon.Size = UDim2.fromOffset(big, big)
		end
	end
	hint.TextSize = S.hintS
	hint.Position, hint.Size = UDim2.fromOffset(0, stageH + 1.2 * ch + S.slotH + 1.2 * ch), UDim2.fromOffset(mw, hintH)
	-- right
	detail.Position, detail.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(rw, bh)
	detailCorner.CornerRadius = UDim.new(0, 2 * ch)
	-- toast
	toast.TextSize = math.max(2.4 * ch, 12)
	toast.Position = UDim2.new(0.5, 0, 1, -3 * ch)
	toast.Size = UDim2.fromOffset(0, math.max(2.4 * ch, 12) + 2.4 * ch)
	toastCorner.CornerRadius = UDim.new(0, 1.6 * ch)
	toastPad.PaddingLeft, toastPad.PaddingRight = UDim.new(0, 2.4 * ch), UDim.new(0, 2.4 * ch)
	-- compact vs full look
	if mode == "compact" then
		root.BackgroundTransparency = 0.55
		boxCorner.CornerRadius = UDim.new(0, 2.4 * ch)
		boxStroke.Transparency = 0.7
	else
		root.BackgroundTransparency = 1
		boxCorner.CornerRadius = UDim.new(0, 0)
		boxStroke.Transparency = 1
	end
end

local function rebuildStage()
	local c = player.Character
	local names = {}
	if c then
		for _, ch in ipairs(c:GetChildren()) do
			if ch.Name:sub(1, 6) == "Mecha_" then table.insert(names, ch.Name) end
		end
	end
	table.sort(names)
	local key = tostring(c) .. "|" .. species() .. "|" .. table.concat(names, ",")
	if key == stageKey then return end
	stageKey = key
	if stagePreview then stagePreview:Destroy() stagePreview = nil end
	if not c then return end
	local was = c.Archivable
	c.Archivable = true
	local ok, copy = pcall(function() return c:Clone() end)
	c.Archivable = was
	if not ok or not copy then return end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Beam")
			or d:IsA("Trail") or d:IsA("ForceField") then
			d:Destroy()
		end
	end
	local hb = copy:FindFirstChild("Hitboxes")
	if hb then hb:Destroy() end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	local hrp = copy:FindFirstChild("HumanoidRootPart")
	local base = hrp and hrp.CFrame or copy:GetPivot()
	local flat = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
	if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
	copy:PivotTo(CFrame.lookAt(base.Position, base.Position + flat.Unit):Inverse() * copy:GetPivot())
	local cf, size = copy:GetBoundingBox()
	center = cf.Position
	stageSize = size
	radius = stageRadius()
	copy.Parent = view
	stagePreview = copy
end

function redraw()
	if not mode then return end
	measure()
	layout()
	drawBar()
	drawCards()
	drawSlots()
	drawDetail()
	rebuildStage()
	player:SetAttribute("LabTab", tab)
end

-- ---------- input ----------
tabParts.Activated:Connect(function() press("tab:parts") tab = "parts" selected = nil redraw() end)
tabStats.Activated:Connect(function() press("tab:stats") tab = "stats" selected = nil slotSel = nil redraw() end)
for n, s in ipairs(slotBtns) do
	s.b.Activated:Connect(function()
		press("slot:" .. n)
		if selected and equippable(selected) and not slotIndex(selected) then
			equip(selected, n)
		elseif slotSel == n then
			slotSel = nil
		else
			slotSel = n
			local inSlot = slotOf(n) -- v1.3: show the part in this slot on the right
			if slotShowsPart and inSlot then
				selected = inSlot
				if tab ~= "parts" then tab = "parts" end
			end
		end
		if slotShowsPart then
			redraw()
		else
			drawSlots()
			drawCards()
		end
	end)
end

local labButton -- the SKILLS pill (set below)
local function setOpen(kind)
	if kind == mode then return end
	mode = kind
	gui.Enabled = kind ~= nil
	player:SetAttribute("LabOpen", kind or "closed")
	local c = player.Character
	if c then c:SetAttribute("SkillScreenOpen", kind == "compact") end
	-- the SKILLS pill hides while the compact Lab is open (the panel would sit over it under the dim; X / K close)
	if labButton then
		if kind == "compact" then
			labButton.Visible = false
		else
			labButton.Visible = player:GetAttribute("InMenu") ~= true
		end
	end
	if kind then
		slotSel = nil
		stageKey = nil
		redraw()
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		RunService:UnbindFromRenderStep(BIND)
		toast.Visible = false
	end
end
closeB.Activated:Connect(function() press("close") setOpen(nil) end)

-- API for MainMenu 1.2
local openFn = script:FindFirstChild("Open") or Instance.new("BindableFunction")
openFn.Name = "Open"
openFn.Parent = script
openFn.OnInvoke = function(kind)
	if kind == "compact" then setOpen("compact") else setOpen("full") end
	return true
end
local closeFn = script:FindFirstChild("Close") or Instance.new("BindableFunction")
closeFn.Name = "Close"
closeFn.Parent = script
closeFn.OnInvoke = function() setOpen(nil) return true end

-- turning models
RunService.RenderStepped:Connect(function(dt)
	if not mode then return end
	orbit += dt * 0.45
	radius = stageRadius()
	cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(orbit), 0.32, math.cos(orbit)).Unit * radius, center)
	for _, c in ipairs(cards) do
		if c.cam then
			c.angle += dt * 0.9
			c.cam.CFrame = CFrame.lookAt(c.center + Vector3.new(math.sin(c.angle), 0.45, math.cos(c.angle)).Unit * c.radius, c.center)
		end
	end
end)

-- redraw on data changes
local queued = false
local function queue()
	if queued or not mode then return end
	queued = true
	task.defer(function()
		queued = false
		redraw()
	end)
end
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 5) == "Skill" then queue() end
	if name == "InMenu" then
		if player:GetAttribute("InMenu") == true and mode == "compact" then setOpen(nil) end
		if player:GetAttribute("InMenu") ~= true and mode == "full" then setOpen(nil) end
		if labButton then labButton.Visible = player:GetAttribute("InMenu") ~= true and mode ~= "compact" end
	end
end)
local charConns = {}
local function onChar(c)
	for _, cn in ipairs(charConns) do cn:Disconnect() end
	table.clear(charConns)
	table.insert(charConns, c.ChildAdded:Connect(function(ch) if ch.Name:sub(1, 6) == "Mecha_" then task.delay(0.25, queue) end end))
	table.insert(charConns, c.ChildRemoved:Connect(function(ch) if ch.Name:sub(1, 6) == "Mecha_" then task.delay(0.25, queue) end end))
	table.insert(charConns, c:GetAttributeChangedSignal("Species"):Connect(queue))
	c:SetAttribute("SkillScreenOpen", mode == "compact")
	task.delay(0.5, queue)
end
player.CharacterAdded:Connect(onChar)
if player.Character then onChar(player.Character) end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue)

-- ---------- SKILLS button (island) ----------
local bgui = Instance.new("ScreenGui")
bgui.Name = "LabButton"
bgui.DisplayOrder = 6
bgui.ResetOnSpawn = false
bgui.Parent = pg
labButton = button(bgui, "Skills", PANEL, 0.18)
labButton.AnchorPoint = Vector2.new(1, 0)
labButton.AutomaticSize = Enum.AutomaticSize.X
labButton.Size = UDim2.fromOffset(0, 36)
labButton.Position = UDim2.new(1, -150, 0, 12)
corner(labButton, UDim.new(0, 10))
stroke(labButton, WHITE, 0.5, 1.5)
pad(labButton, 12)
local lbList = list(labButton, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
local lbText = label(labButton, "T", Enum.Font.FredokaOne, 18, WHITE, "SKILLS")
lbText.AutomaticSize = Enum.AutomaticSize.X
lbText.Size = UDim2.fromOffset(0, 36)
lbText.TextStrokeTransparency = 0.6
local lbBadge = label(labButton, "Badge", Enum.Font.FredokaOne, 14, DARK_TEXT, "0")
lbBadge.BackgroundTransparency = 0
lbBadge.BackgroundColor3 = YELLOW
lbBadge.Size = UDim2.fromOffset(22, 22)
lbBadge.LayoutOrder = 2
corner(lbBadge, UDim.new(1, 0))
labButton.Visible = player:GetAttribute("InMenu") ~= true
labButton.Activated:Connect(function()
	press("skills")
	if mode == "compact" then setOpen(nil) else setOpen("compact") end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.K then return end
	if player:GetAttribute("InMenu") == true then return end
	press("key:K")
	if mode == "compact" then setOpen(nil) else setOpen("compact") end
end)
task.spawn(function()
	while bgui.Parent do
		local ast = pg:FindFirstChild("ArenaStatus")
		local pill = ast and ast:FindFirstChild("Pill")
		if pill and pill.AbsoluteSize.X > 0 then
			labButton.Position = UDim2.new(1, -16 - pill.AbsoluteSize.X - 8, 0, 12)
		else
			labButton.Position = UDim2.new(1, -150, 0, 12)
		end
		local left = tonumber(player:GetAttribute("SkillLeft")) or 0
		lbBadge.Text = tostring(left)
		lbBadge.Visible = left > 0
		task.wait(0.5)
	end
end)
