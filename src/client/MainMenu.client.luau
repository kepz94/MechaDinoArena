-- MainMenu v1.4 (Mecha Dino Arena) — the main menu: dino select with a 3D preview (plain / mech view), the loadout slots,
-- and SANDBOX / ARENA (LocalScript in StarterPlayerScripts, all devices; survives respawns). MDA-90, plan
-- docs/plans/MAIN_MENU_v1.0.md Task 6, ADR-005, mockup docs/mockups/main_menu_options.html option A "One-screen lobby"
-- (Kepu 2026-10-29: "a main menu that says sandbox and then arena ... a Dino select screen. It would show the current
-- selected Dino and if someone clicks on it it'll be the Dino with the attachments ... keep the same kinda block design and
-- just real simple but also gamey and correctly spaced out layout that takes into account how it looks both on pc and
-- phone" / "you can customize the Dino with the mecha parts or select other Dino's").
-- Shown while the player attribute InMenu == true (ModeServer 1.0: on join, and after DinoModeRequest("menu")), hidden
--   while it is not. The server parks the dino out of play while the menu is up.
-- Layout (sizes from the screen: ch = height / 100, cw = width / 100, with px minimums; ScreenGui "MainMenu",
--   DisplayOrder 40, IgnoreGuiInset, full-screen Root that takes every touch / click):
--   * backdrop: rgb(10, 12, 18), transparency 0.06 / 0.18 / 0.1 left -> middle -> right (UIGradient), and a BlurEffect
--     "MainMenuBlur" (size 18) on the camera while the menu is up;
--   * padding: top max(10ch, GuiService.TopbarInset height + 0.8ch) (clear of the Roblox top-left buttons on phones too),
--     sides 4cw, bottom 6ch; two columns 1.15 : 1, gap 3cw;
--   * left column, top to bottom (gap 1.6ch):
--       Stage (panel rgb(20, 20, 26) at 0.14, white stroke 0.88, corner 2.6ch; takes the rest of the height): a
--         ViewportFrame with a copy of your live character turning slowly (a camera orbit); tag top-left "DINO" (grey) /
--         "MECH VIEW" (volt rgb(127, 233, 255)); hint at the bottom "TAP TO SEE MECH" / "TAP FOR PLAIN DINO". Tap = flip:
--         mech view shows the character's Mecha_* models, plain view leaves them out. Re-copied when the character, its
--         Species or its Mecha_* children change.
--       Species row: ◀ (dark block button max(7.2ch, 40 px) square) | name (FredokaOne 4.6ch) + sub line (Gotham
--         max(1.9ch, 11 px)) | ▶. ◀ / ▶ fire DinoSpeciesRequest with the other dino (SpeciesServer respawns you behind the
--         menu); both are greyed for SWITCH_LOCK (2 s, the server cooldown) and until the new body arrives; the sub line
--         reads "SWITCHING..." meanwhile.
--       Slots row: SkillTree.SLOTS slot buttons (height max(4.6ch, 32 px), text max(1.8ch, 12 px), wraps to a second row
--         when too wide): orange key (PC R / C / T / V, touch R / C / R▼ / C▼) + the part's name, orange stroke; "empty"
--         with a faint stroke. No owned button part for this dino -> one grey "No mech parts yet" tag.
--       Picker / hint: tap a slot -> it gets a white stroke and a picker row (chips: every button part this dino owns, in
--         tree order, "· in <key>" when it sits in another slot, then "Empty") replaces the hint "Tap a slot to change its
--         part". A chip fires SkillRequest("slot", n, id) (or "") and closes the picker; tapping the slot again cancels.
--   * right column (centred): title "MECHA DINO" (yellow, 0.42 of the title size) over "ARENA" (FredokaOne 7.6ch),
--     3ch gap, then SANDBOX (yellow) and ARENA (orange) block buttons (13ch tall, name 5ch, sub max(2.1ch, 11 px), tag
--     max(1.9ch, 10 px) "BOTS" / "PVP"), gap 2.2ch. SANDBOX -> DinoModeRequest("sandbox"), ARENA -> ("arena"): the
--     button of this server's mode starts play here, the other one travels to the other place.
--   * Toast (top 12ch, centred, yellow stroke) from ModeLastResult when ModeLastAt changes: "saving" -> "SAVING YOUR
--     LOADOUT...", "teleporting" -> "TRAVELING...", "teleportFailed" -> "COULDN'T TRAVEL · TRY AGAIN", "studio" -> "ARENA
--     OPENS IN THE LIVE GAME" / "SANDBOX OPENS IN THE LIVE GAME", "noArenaPlace" -> "ARENA COMING SOON"; others none.
--     It stays while saving / traveling, else 3 s.
-- PC mouse: ShoulderCam locks the mouse every frame; while the menu is up this script sets MouseBehavior Default and shows
--   the cursor right after it (RenderStep "MainMenuMouse", Camera priority + 1), as SkillScreen does.
-- Switch: script attribute MainMenuEnabled (default true), read at start; false -> no menu.
-- Diagnostics (LocalPlayer attributes, this client): MainMenuVersion, MainMenuOpen, MainMenuView ("plain" / "mech"),
--   MainMenuPickSlot (0 = none), MainMenuLastPress ("flip" / "prev" / "next" / "slot:n" / "part:n:<id or empty>" /
--   "sandbox" / "arena"), MainMenuToast (text shown, "" = none), MainMenuPreviewParts (parts in the preview copy).
-- v1.1 (Egg Loader, MDA-94, plan docs/plans/EGG_LOADER_v1.0.md Task 2): the egg-hatch loading screen covers trips. When
--   ModeLastResult turns "saving" or "teleporting" (a SANDBOX / ARENA press for the other place), once per trip:
--   ReplicatedFirst.EggLoader.Show:Invoke("Sandbox" / "Arena") puts up the incubator ("TRAVELING TO ..."), and the gui it
--   returns goes to TeleportService:SetTeleportGui so it stays up during the teleport (EggLoader 1.0 picks it up on
--   arrival). "teleportFailed" -> EggLoader.Hide:Invoke() and the toast as before. "studio" never shows it. Script
--   attribute MainMenuTravelLoaderEnabled (default true; false = 1.0). Diagnostic: MainMenuTravelLoader ("shown" /
--   "hidden" / "none").
-- v1.2 (Lab, MDA-98, plan docs/plans/LAB_v1.0.md Task 3, mockup docs/mockups/lab_options.html "Main menu"; Kepu 2026-10-29:
--   "keep the main menu Dino select the same with a quick reference on what Dino you have and the mecha upgrades but a go to
--   the lab option"): the slot row is read-only (a tap does nothing, no picker row, no hint) and a volt block button
--   "GO TO THE LAB" (height max(7ch, 40 px), FredokaOne max(2.8ch, 15 px), full left-column width) sits under it, in the
--   hint / picker row's place. It calls LocalPlayer.PlayerScripts.Lab.Open:Invoke("full") (Lab 1.0). Script attribute
--   MainMenuLabEnabled (default true; false = the 1.1 picker). Diagnostic: MainMenuLastPress "lab".
-- v1.3 (Kepu 2026-10-29: "the menu is its own dedicated menu"; mockup docs/mockups/menu_lab_v2_options.html option A
--   "Hangar bay"): the menu is solid. A second ScreenGui "MainMenuHangar" (DisplayOrder 39, IgnoreGuiInset, shown with the
--   menu) holds a full-screen ViewportFrame "Scene" (background rgb(20, 27, 39)) with a hangar built from parts around the
--   dino copy, scaled by u = max(diagonal / 25, 0.6) (diagonal = the copy's X/Z bounding-box diagonal): floor (dark, volt
--   grid lines every 10u), back wall (panel ribs every 14u, a rib 18u up, two volt light bars 22u up, a yellow / black
--   hazard band 3u tall along its base) 0.5 x diagonal + 18u behind the dino, a pedestal (radius 0.42 x diagonal, a volt
--   neon ring, a faint volt glow disc 1.7 x its size on the floor) under its feet. The copy goes in this scene (not in the
--   Stage view) and turns on the pedestal (0.45 rad/s); the camera is fixed (looking down 0.12) and placed so the dino's
--   centre sits at the stage area's centre x and 0.45 of its height, the X/Z diagonal fitting 0.92 of its width and height + 0.12 x
--   diagonal 0.9 of its height. The Stage keeps its tap (flip), tag and hint but draws no panel, stroke or floor glow; the
--   Root backdrop is fully transparent (the scene covers the island and the HUD). A dark scrim over the right 55% of the
--   scene (transparency 1 -> 0.3 over its first 30%, 0.22 at the right edge) keeps the right column readable. Switch: script attribute
--   MainMenuHangarEnabled (default true, read at start; false = 1.2). Diagnostic: MainMenuHangarParts (parts in the room).
--   SANDBOX / ARENA for this server's mode (player attribute DinoMode) first calls ReplicatedFirst.EggLoader.Play("Sandbox"
--   / "Arena") (EggLoader 1.1: the egg until the dino stands on the island), then fires the request; "busy" / "badArg"
--   takes the egg down (EggLoader.Hide). Switch: script attribute MainMenuPlayLoaderEnabled (default true; false = no
--   egg). Diagnostic: MainMenuPlayLoader ("shown" / "hidden" / "none").
-- v1.4 (Kepu 2026-10-29, phone screenshot: "the mecha Dino should be the default view. Tap to see plain Dino should exist
--   above the Dino head because you can't even see it"): the menu opens in the mech view (the copy with its Mecha_*
--   parts; the tap still flips to the plain dino). Hangar on: the stage hint sits in a top row of the stage area, centred,
--   on the same line as the DINO / MECH VIEW tag (row = 2.4ch + tag height + 0.8ch), and the dino is fitted to the stage
--   area below that row, so the hint is always above its head. Switches: script attributes MainMenuMechFirstEnabled
--   (default true, read at start; false = plain view first) and MainMenuHintTopEnabled (default true; false = 1.3 hint
--   at the bottom).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local VERSION = "1.4"
local BIND = "MainMenuMouse"
local SWITCH_LOCK = 2
local PANEL = Color3.fromRGB(20, 20, 26)
local YELLOW = Color3.fromRGB(255, 200, 50)
local ORANGE = Color3.fromRGB(255, 155, 46)
local GREY = Color3.fromRGB(207, 211, 220)
local MUTED = Color3.fromRGB(143, 153, 170)
local VOLT = Color3.fromRGB(127, 233, 255)
local WHITE = Color3.new(1, 1, 1)
local DARK_TEXT = Color3.fromRGB(27, 20, 6)
local DINOS = {
	{id = "Raptor", name = "RAPTOR", sub = "60 HP · fast hunter"},
	{id = "TRex", name = "T-REX", sub = "200 HP · heavy hitter"},
}
local SLOT_KEYS = UserInputService.TouchEnabled and {"R", "C", "R▼", "C▼"} or {"R", "C", "T", "V"}

local player = Players.LocalPlayer
player:SetAttribute("MainMenuVersion", VERSION)
player:SetAttribute("MainMenuOpen", false)
if script:GetAttribute("MainMenuEnabled") == nil then script:SetAttribute("MainMenuEnabled", true) end
if script:GetAttribute("MainMenuEnabled") == false then return end

local modeRemote = ReplicatedStorage:WaitForChild("DinoModeRequest", 30)
local speciesRemote = ReplicatedStorage:WaitForChild("DinoSpeciesRequest", 30)
local skillRemote = ReplicatedStorage:WaitForChild("SkillRequest", 30)
local shared = ReplicatedStorage:WaitForChild("SkillShared", 30)
local ST = shared and require(shared:WaitForChild("SkillTree"))
local pg = player:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("MainMenu")
if old then old:Destroy() end

-- ---------- building blocks ----------
local function corner(p) local c = Instance.new("UICorner") c.Parent = p return c end
local function stroke(p, color, t, th)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color, s.Transparency, s.Thickness = color, t, th
	s.Parent = p
	return s
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
local function blockButton(parent, name, color) -- yellow / orange / dark game button with its bottom band and drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = name .. "Shadow"
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.65
	shadow.BorderSizePixel = 0
	shadow.Parent = parent
	local sc = corner(shadow)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = ""
	b.Parent = parent
	local bc = corner(b)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundColor3 = Color3.new(0, 0, 0)
	band.BackgroundTransparency = 0.78
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0, 1)
	band.Position = UDim2.fromScale(0, 1)
	band.Parent = b
	local bandc = corner(band)
	return {b = b, shadow = shadow, band = band, corners = {sc, bc, bandc}}
end
local function placeButton(bb, x, y, w, h, r, bandH, drop)
	bb.b.Position, bb.b.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	bb.shadow.Position, bb.shadow.Size = UDim2.fromOffset(x, y + drop), UDim2.fromOffset(w, h)
	bb.band.Size = UDim2.new(1, 0, 0, bandH)
	for _, c in ipairs(bb.corners) do c.CornerRadius = UDim.new(0, r) end
end

-- ---------- the screen ----------
local gui = Instance.new("ScreenGui")
gui.Name = "MainMenu"
gui.DisplayOrder = 40
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = pg

local root = Instance.new("TextButton") -- takes every touch / click so nothing underneath reacts
root.Name = "Root"
root.AutoButtonColor = false
root.Text = ""
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
root.BackgroundTransparency = 0
root.BorderSizePixel = 0
root.Parent = gui
local grad = Instance.new("UIGradient")
grad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(0.55, 0.18),
	NumberSequenceKeypoint.new(1, 0.1)}) -- dark enough that the HUD underneath does not read through
local blur = Instance.new("BlurEffect") -- the island behind the menu, blurred (local camera effect, this client only)
blur.Name = "MainMenuBlur"
blur.Size = 18
blur.Enabled = false
grad.Parent = root

-- left column
local stage = Instance.new("TextButton")
stage.Name = "Stage"
stage.AutoButtonColor = false
stage.Text = ""
stage.BackgroundColor3 = PANEL
stage.BackgroundTransparency = 0.14
stage.BorderSizePixel = 0
stage.ClipsDescendants = true
stage.Parent = root
local stageCorner = corner(stage)
local stageStroke = stroke(stage, WHITE, 0.88, 2)

local floor = Instance.new("Frame")
floor.Name = "Floor"
floor.AnchorPoint = Vector2.new(0.5, 0.5)
floor.Position = UDim2.fromScale(0.5, 0.84)
floor.Size = UDim2.fromScale(0.76, 0.08)
floor.BackgroundColor3 = YELLOW
floor.BackgroundTransparency = 0.7
floor.BorderSizePixel = 0
floor.Parent = stage
local floorCorner = corner(floor)
floorCorner.CornerRadius = UDim.new(0.5, 0)
local floorGrad = Instance.new("UIGradient")
floorGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35),
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

-- v1.3: the hangar scene behind the menu
if script:GetAttribute("MainMenuHangarEnabled") == nil then script:SetAttribute("MainMenuHangarEnabled", true) end
local hangarOn = script:GetAttribute("MainMenuHangarEnabled") ~= false
local hgui, scene, hcam
if hangarOn then
	local oldH = pg:FindFirstChild("MainMenuHangar")
	if oldH then oldH:Destroy() end
	hgui = Instance.new("ScreenGui")
	hgui.Name = "MainMenuHangar"
	hgui.DisplayOrder = 39
	hgui.IgnoreGuiInset = true
	hgui.ResetOnSpawn = false
	hgui.Enabled = false
	hgui.Parent = pg
	scene = Instance.new("ViewportFrame")
	scene.Name = "Scene"
	scene.Size = UDim2.fromScale(1, 1)
	scene.BackgroundColor3 = Color3.fromRGB(20, 27, 39)
	scene.BackgroundTransparency = 0
	scene.BorderSizePixel = 0
	scene.Ambient = Color3.fromRGB(120, 126, 140)
	scene.LightColor = Color3.fromRGB(255, 250, 240)
	scene.LightDirection = Vector3.new(-0.3, -1, -0.5)
	scene.Parent = hgui
	hcam = Instance.new("Camera")
	hcam.FieldOfView = 40
	hcam.Parent = scene
	scene.CurrentCamera = hcam
	local scrim = Instance.new("Frame") -- keeps the right column readable over the wall's hazard band
	scrim.Name = "Scrim"
	scrim.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	scrim.BorderSizePixel = 0
	scrim.Position, scrim.Size = UDim2.fromScale(0.45, 0), UDim2.fromScale(0.55, 1)
	scrim.Parent = hgui
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3),
		NumberSequenceKeypoint.new(1, 0.22)})
	sg.Parent = scrim
	root.BackgroundTransparency = 1
	stage.BackgroundTransparency = 1
	stageStroke.Transparency = 1
	floor.Visible = false
	view.Visible = false
end

local modeTag = label(stage, "ModeTag", Enum.Font.RobotoMono, GREY)
modeTag.BackgroundTransparency = 0.6
modeTag.BackgroundColor3 = Color3.new(0, 0, 0)
local modeTagCorner = corner(modeTag)
local stageHint = label(stage, "Hint", Enum.Font.GothamBlack, GREY)

local prevB = blockButton(root, "Prev", PANEL)
local nextB = blockButton(root, "Next", PANEL)
for _, bb in ipairs({prevB, nextB}) do
	stroke(bb.b, WHITE, 0.84, 2)
	bb.band.BackgroundTransparency = 0.65
end
local prevText = label(prevB.b, "Arrow", Enum.Font.SourceSansBold, WHITE) -- FredokaOne draws these glyphs blank, Gotham tiny
prevText.Size = UDim2.fromScale(1, 1)
prevText.Text = "◀"
local nextText = label(nextB.b, "Arrow", Enum.Font.SourceSansBold, WHITE)
nextText.Size = UDim2.fromScale(1, 1)
nextText.Text = "▶"
local dname = label(root, "DinoName", Enum.Font.FredokaOne, WHITE)
local dsub = label(root, "DinoSub", Enum.Font.GothamBlack, MUTED)

local slotsRow = Instance.new("Frame")
slotsRow.Name = "Slots"
slotsRow.BackgroundTransparency = 1
slotsRow.AutomaticSize = Enum.AutomaticSize.Y
slotsRow.Parent = root
local slotsList = Instance.new("UIListLayout")
slotsList.FillDirection = Enum.FillDirection.Horizontal
slotsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
slotsList.Wraps = true
slotsList.SortOrder = Enum.SortOrder.LayoutOrder
slotsList.Parent = slotsRow

local picker = Instance.new("ScrollingFrame")
picker.Name = "Picker"
picker.BackgroundColor3 = Color3.new(0, 0, 0)
picker.BackgroundTransparency = 0.55
picker.BorderSizePixel = 0
picker.ScrollingDirection = Enum.ScrollingDirection.X
picker.AutomaticCanvasSize = Enum.AutomaticSize.X
picker.CanvasSize = UDim2.new()
picker.ScrollBarThickness = 0
picker.Visible = false
picker.Parent = root
local pickerCorner = corner(picker)
stroke(picker, WHITE, 0.88, 2)
local pickList = Instance.new("UIListLayout")
pickList.FillDirection = Enum.FillDirection.Horizontal
pickList.VerticalAlignment = Enum.VerticalAlignment.Center
pickList.SortOrder = Enum.SortOrder.LayoutOrder
pickList.Parent = picker
local pickPad = Instance.new("UIPadding")
pickPad.Parent = picker
local slotHint = label(root, "SlotHint", Enum.Font.GothamBlack, MUTED)
slotHint.Text = "Tap a slot to change its part"
-- v1.2: GO TO THE LAB
if script:GetAttribute("MainMenuLabEnabled") == nil then script:SetAttribute("MainMenuLabEnabled", true) end
local labOn = script:GetAttribute("MainMenuLabEnabled") ~= false
local labB = blockButton(root, "LabGo", VOLT)
local labText = label(labB.b, "T", Enum.Font.FredokaOne, VOLT, "GO TO THE LAB")
labText.TextColor3 = Color3.fromRGB(6, 36, 48)
labText.Text = "GO TO THE LAB"
labText.Size = UDim2.fromScale(1, 1)
labB.b.Visible = labOn
labB.shadow.Visible = labOn

-- right column
local titleSmall = label(root, "TitleSmall", Enum.Font.FredokaOne, YELLOW)
titleSmall.Text = "MECHA DINO"
titleSmall.TextXAlignment = Enum.TextXAlignment.Left
local titleBig = label(root, "Title", Enum.Font.FredokaOne, WHITE)
titleBig.Text = "ARENA"
titleBig.TextXAlignment = Enum.TextXAlignment.Left
local titleShadow = label(root, "TitleShadow", Enum.Font.FredokaOne, Color3.new(0, 0, 0))
titleShadow.Text = "ARENA"
titleShadow.TextTransparency = 0.55
titleShadow.TextXAlignment = Enum.TextXAlignment.Left
titleShadow.ZIndex = 0

local function modeButton(name, color, title, sub, tag)
	local bb = blockButton(root, name, color)
	local t = label(bb.b, "Name", Enum.Font.FredokaOne, DARK_TEXT)
	t.Text = title
	t.TextXAlignment = Enum.TextXAlignment.Left
	local s = label(bb.b, "Sub", Enum.Font.GothamBlack, DARK_TEXT)
	s.Text = sub
	s.TextTransparency = 0.22
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.TextTruncate = Enum.TextTruncate.AtEnd
	local g = label(bb.b, "Tag", Enum.Font.GothamBlack, DARK_TEXT)
	g.Text = tag
	g.BackgroundColor3 = Color3.new(0, 0, 0)
	g.BackgroundTransparency = 0.72
	local gc = corner(g)
	return {bb = bb, t = t, s = s, g = g, gc = gc}
end
local sandboxB = modeButton("Sandbox", YELLOW, "SANDBOX", "Island with bots · no player damage", "BOTS")
local arenaB = modeButton("Arena", ORANGE, "ARENA", "Same island · no bots · player damage on", "PVP")

local toast = label(root, "Toast", Enum.Font.FredokaOne, YELLOW)
toast.BackgroundColor3 = PANEL
toast.BackgroundTransparency = 0.08
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.AutomaticSize = Enum.AutomaticSize.X
toast.Visible = false
toast.ZIndex = 5
local toastCorner = corner(toast)
local toastStroke = stroke(toast, YELLOW, 0, 2)
local toastPad = Instance.new("UIPadding")
toastPad.Parent = toast

-- ---------- state ----------
if script:GetAttribute("MainMenuMechFirstEnabled") == nil then script:SetAttribute("MainMenuMechFirstEnabled", true) end -- v1.4
if script:GetAttribute("MainMenuHintTopEnabled") == nil then script:SetAttribute("MainMenuHintTopEnabled", true) end -- v1.4
local mech = script:GetAttribute("MainMenuMechFirstEnabled") ~= false -- v1.4: mech view first (1.3: false)
local pickSlot = nil
local switchUntil = 0
local switchingTo = nil
local toastToken = 0
local lastPreviewKey = nil
local preview = nil
local orbit = 0
local center, radius = Vector3.zero, 20
local hSize, hBase, hDiag = Vector3.new(10, 10, 10), CFrame.new(), 10 -- v1.3: copy size, pivot, X/Z diagonal
local hRoom = nil -- v1.3

local function char() return player.Character end
local function species()
	local c = char()
	local sp = c and c:GetAttribute("Species")
	if type(sp) == "string" and sp ~= "" then return sp end
	sp = player:GetAttribute("DinoSpecies")
	if type(sp) == "string" and sp ~= "" then return sp end
	return "TRex"
end
local function dinoIndex()
	local sp = species()
	for i, d in ipairs(DINOS) do
		if d.id == sp then return i end
	end
	return 1
end
local function slotOf(n)
	local v = player:GetAttribute("SkillSlot" .. n)
	if type(v) == "string" and v ~= "" then return v else return nil end
end
local function ownedButtons()
	local list = {}
	if not ST then return list end
	for _, id in ipairs(ST.PATH_ORDER) do
		local p = ST.PATHS[id]
		local steps = player:GetAttribute("SkillPath_" .. id) or 0
		if ST.BUTTONS and ST.BUTTONS[id] and p and not p.soon and steps >= 1
			and (not ST.seesPath or ST.seesPath(id, species())) then
			table.insert(list, id)
		end
	end
	return list
end
local function press(what) player:SetAttribute("MainMenuLastPress", what) end

-- ---------- sizes ----------
local S = {}
local function measure()
	local W, H = root.AbsoluteSize.X, root.AbsoluteSize.Y
	local ch, cw = H / 100, W / 100
	S.W, S.H, S.ch, S.cw = W, H, ch, cw
	local ok, inset = pcall(function() return GuiService.TopbarInset.Height end) -- the Roblox top-left buttons
	if not ok or type(inset) ~= "number" then inset = 58 end
	S.top, S.side, S.bottom = math.max(10 * ch, inset + 0.8 * ch), 4 * cw, 6 * ch
	local inner = W - 2 * S.side - 3 * cw
	S.leftX, S.leftW = S.side, inner * 1.15 / 2.15
	S.rightX = S.side + S.leftW + 3 * cw
	S.rightW = W - S.side - S.rightX
	S.gap = 1.6 * ch
	S.arrow = math.max(7.2 * ch, 40)
	S.slotH = math.max(4.6 * ch, 32)
	S.slotText = math.max(1.8 * ch, 12)
	S.chipH = math.max(5 * ch, 36)
	S.hintText = math.max(1.9 * ch, 11)
end

-- ---------- slots + picker ----------
local relayout -- set below (layout() + once more after the automatic sizes settle)
local slotButtons = {}
local function drawSlots()
	for _, b in ipairs(slotButtons) do b:Destroy() end
	table.clear(slotButtons)
	for _, ch in ipairs(picker:GetChildren()) do
		if ch:IsA("GuiButton") then ch:Destroy() end
	end
	local owned = ownedButtons()
	slotsList.Padding = UDim.new(0, math.max(0.8 * S.cw, 6))
	if #owned == 0 then
		local none = Instance.new("TextLabel")
		none.Name = "NoParts"
		none.BackgroundColor3 = WHITE
		none.BackgroundTransparency = 0.93
		none.AutomaticSize = Enum.AutomaticSize.X
		none.Size = UDim2.fromOffset(0, S.slotH)
		none.Font = Enum.Font.GothamBlack
		none.TextSize = S.slotText
		none.TextColor3 = MUTED
		none.Text = "No mech parts yet"
		none.Parent = slotsRow
		corner(none).CornerRadius = UDim.new(0, S.ch)
		stroke(none, WHITE, 0.86, 2)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
		pad.Parent = none
		table.insert(slotButtons, none)
		pickSlot = nil
	else
		for n = 1, (ST and ST.SLOTS or 4) do
			local id = slotOf(n)
			local p = id and ST.PATHS[id]
			local b = Instance.new("TextButton")
			b.Name = "Slot_" .. n
			b.LayoutOrder = n
			b.AutoButtonColor = false
			b.RichText = true
			b.AutomaticSize = Enum.AutomaticSize.X
			b.Size = UDim2.fromOffset(0, S.slotH)
			b.BackgroundColor3 = WHITE
			b.BackgroundTransparency = 0.93
			b.Font = Enum.Font.GothamBlack
			b.TextSize = S.slotText
			b.TextColor3 = p and GREY or MUTED
			b.Text = ('<font color="#ff9b2e">%s</font>  %s'):format(SLOT_KEYS[n] or tostring(n), p and p.name or "empty")
			b.Parent = slotsRow
			corner(b).CornerRadius = UDim.new(0, S.ch)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, math.max(1.1 * S.ch, 9)), UDim.new(0, math.max(1.1 * S.ch, 9))
			pad.Parent = b
			if pickSlot == n then
				stroke(b, WHITE, 0, 3)
				b.TextColor3 = WHITE
			elseif p then
				stroke(b, ORANGE, 0.45, 2)
			else
				stroke(b, WHITE, 0.86, 2)
			end
			b.Activated:Connect(function()
				press("slot:" .. n)
				if labOn then return end -- v1.2: read-only, the Lab edits the loadout
				if pickSlot == n then pickSlot = nil else pickSlot = n end
				player:SetAttribute("MainMenuPickSlot", pickSlot or 0)
				drawSlots()
				relayout()
			end)
			table.insert(slotButtons, b)
		end
	end
	player:SetAttribute("MainMenuPickSlot", pickSlot or 0)
	-- picker chips
	picker.Visible = pickSlot ~= nil
	slotHint.Visible = pickSlot == nil and #owned > 0 and not labOn -- v1.2
	if pickSlot then
		pickList.Padding = UDim.new(0, math.max(0.8 * S.cw, 6))
		local function chip(order, text, id)
			local b = Instance.new("TextButton")
			b.Name = "Chip_" .. (id ~= "" and id or "empty")
			b.LayoutOrder = order
			b.AutoButtonColor = false
			b.RichText = true
			b.AutomaticSize = Enum.AutomaticSize.X
			b.Size = UDim2.fromOffset(0, S.chipH)
			b.BackgroundColor3 = PANEL
			b.Font = Enum.Font.GothamBlack
			b.TextSize = math.max(1.9 * S.ch, 12)
			b.TextColor3 = WHITE
			b.Text = text
			b.Parent = picker
			corner(b).CornerRadius = UDim.new(1, 0)
			stroke(b, id ~= "" and ORANGE or WHITE, id ~= "" and 0 or 0.7, 2)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, math.max(1.4 * S.ch, 12)), UDim.new(0, math.max(1.4 * S.ch, 12))
			pad.Parent = b
			b.Activated:Connect(function()
				local n = pickSlot
				if not n then return end
				press(("part:%d:%s"):format(n, id ~= "" and id or "empty"))
				if skillRemote then skillRemote:FireServer("slot", n, id) end
				pickSlot = nil
				drawSlots()
				relayout()
			end)
		end
		for i, id in ipairs(ownedButtons()) do
			local where = ""
			for m = 1, (ST and ST.SLOTS or 4) do
				if m ~= pickSlot and slotOf(m) == id then where = ('  <font color="#8f99aa">· in %s</font>'):format(SLOT_KEYS[m] or tostring(m)) end
			end
			chip(i, ST.PATHS[id].name .. where, id)
		end
		chip(99, "Empty", "")
	end
end

-- ---------- v1.3: hangar room ----------
local function hPart(parent, name, size, cf, color, neon, transp)
	local b = Instance.new("Part")
	b.Name = name
	b.Anchored = true
	b.CanCollide, b.CanQuery, b.CanTouch = false, false, false
	b.CastShadow = false
	b.Size = size
	b.CFrame = cf
	b.Color = color
	b.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	b.TopSurface, b.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	b.Transparency = transp or 0
	b.Parent = parent
	return b
end
local function buildRoom()
	if hRoom then hRoom:Destroy() end
	local room = Instance.new("Model")
	room.Name = "Room"
	local u = math.max(hDiag / 25, 0.6)
	local feet = center.Y - hSize.Y / 2
	local ph = math.max(hSize.Y * 0.08, 0.8 * u)
	local floorY = feet - ph
	local cx, cz = center.X, center.Z
	local wallZ = cz - (hDiag * 0.5 + 18 * u)
	local DARK = Color3.fromRGB(16, 20, 29)
	local WALL = Color3.fromRGB(30, 37, 52)
	local RIB = Color3.fromRGB(37, 45, 62)
	local VOLTC = Color3.fromRGB(127, 233, 255)
	hPart(room, "Floor", Vector3.new(2000, 1, 2000), CFrame.new(cx, floorY - 0.5, cz), DARK)
	for i = -15, 15 do
		hPart(room, "GridX", Vector3.new(0.25 * u, 0.05, 300 * u), CFrame.new(cx + i * 10 * u, floorY + 0.03, cz), VOLTC, false, 0.82)
		hPart(room, "GridZ", Vector3.new(300 * u, 0.05, 0.25 * u), CFrame.new(cx, floorY + 0.03, cz + i * 10 * u), VOLTC, false, 0.82)
	end
	hPart(room, "Wall", Vector3.new(2000, 1000, 2), CFrame.new(cx, floorY + 500, wallZ - 1), WALL)
	for i = -12, 12 do
		hPart(room, "Rib", Vector3.new(0.8 * u, 1000, 0.6), CFrame.new(cx + i * 14 * u, floorY + 500, wallZ + 0.3), RIB)
	end
	hPart(room, "RibH", Vector3.new(2000, 0.8 * u, 0.6), CFrame.new(cx, floorY + 18 * u, wallZ + 0.4), RIB)
	for _, x in ipairs({-30, 30}) do
		hPart(room, "LightBar", Vector3.new(40 * u, 0.7 * u, 0.4), CFrame.new(cx + x * u, floorY + 22 * u, wallZ + 0.6), VOLTC, true)
	end
	for i = -60, 60 do
		hPart(room, "Hazard", Vector3.new(3 * u, 3 * u, 0.5), CFrame.new(cx + i * 3 * u, floorY + 1.5 * u, wallZ + 0.7),
			(i % 2 == 0) and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(27, 20, 6))
	end
	local rp = hDiag * 0.42
	local vert = CFrame.Angles(0, 0, math.pi / 2) -- cylinders stand up
	hPart(room, "Glow", Vector3.new(0.1, rp * 1.7, rp * 1.7), CFrame.new(cx, floorY + 0.06, cz) * vert, VOLTC, true, 0.9).Shape = Enum.PartType.Cylinder
	hPart(room, "Pedestal", Vector3.new(ph, rp * 2, rp * 2), CFrame.new(cx, floorY + ph / 2, cz) * vert, Color3.fromRGB(44, 54, 72)).Shape = Enum.PartType.Cylinder
	hPart(room, "Ring", Vector3.new(ph * 0.3, rp * 2 + 0.8 * u, rp * 2 + 0.8 * u), CFrame.new(cx, floorY + ph * 0.45, cz) * vert, VOLTC, true).Shape = Enum.PartType.Cylinder
	hPart(room, "Top", Vector3.new(0.2, rp * 1.84, rp * 1.84), CFrame.new(cx, feet - 0.05, cz) * vert, Color3.fromRGB(57, 70, 92)).Shape = Enum.PartType.Cylinder
	room.Parent = scene
	hRoom = room
	local n = 0
	for _, d in ipairs(room:GetChildren()) do if d:IsA("BasePart") then n += 1 end end
	player:SetAttribute("MainMenuHangarParts", n)
end
local hStage = {x = 0, y = 0, w = 100, h = 100} -- the stage area on screen (set by layout)
local function placeHangarCam()
	if not hangarOn then return end
	local W, H = scene.AbsoluteSize.X, scene.AbsoluteSize.Y
	if W <= 0 or H <= 0 then return end
	local t = math.tan(math.rad(hcam.FieldOfView / 2))
	local A = W / H
	local hh = hSize.Y + 0.12 * hDiag -- the 0.12 camera tilt shows a little of the depth
	local d = math.max(hDiag * W / (2 * t * A * hStage.w * 0.92), hh * H / (2 * t * hStage.h * 0.9))
	local cx, cy = hStage.x + hStage.w / 2, hStage.y + hStage.h * 0.45 -- a little above the middle: room for the pedestal
	local nx = (cx - W / 2) / (W / 2)
	local ny = (H / 2 - cy) / (H / 2)
	local dir = Vector3.new(0, -0.12, -1).Unit
	local look = CFrame.lookAt(Vector3.zero, dir)
	local pos = center - dir * d - look.RightVector * (nx * d * t * A) - look.UpVector * (ny * d * t)
	hcam.CFrame = CFrame.lookAt(pos, pos + dir)
end

-- ---------- preview ----------
local function previewKey()
	local c = char()
	if not c then return "none" end
	local names = {}
	for _, ch in ipairs(c:GetChildren()) do
		if ch.Name:sub(1, 6) == "Mecha_" then table.insert(names, ch.Name) end
	end
	table.sort(names)
	return ("%s|%s|%s|%s"):format(tostring(c), species(), mech and "mech" or "plain", table.concat(names, ","))
end
local function rebuildPreview()
	local key = previewKey()
	if key == lastPreviewKey then return end
	lastPreviewKey = key
	if preview then preview:Destroy() preview = nil end
	local c = char()
	if not c then return end
	local was = c.Archivable
	c.Archivable = true
	local ok, copy = pcall(function() return c:Clone() end)
	c.Archivable = was
	if not ok or not copy then return end
	local parts = 0
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Beam")
			or d:IsA("Trail") or d:IsA("ForceField") then
			d:Destroy()
		end
	end
	for _, ch in ipairs(copy:GetChildren()) do
		if ch.Name == "Hitboxes" or (not mech and ch.Name:sub(1, 6) == "Mecha_") then ch:Destroy() end
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if d.Transparency < 1 then parts += 1 end
		end
	end
	local hrp = copy:FindFirstChild("HumanoidRootPart")
	local base = hrp and hrp.CFrame or copy:GetPivot()
	local flat = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
	if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
	copy:PivotTo(CFrame.lookAt(base.Position, base.Position + flat.Unit):Inverse() * copy:GetPivot()) -- facing -Z at the origin
	local cf, size = copy:GetBoundingBox()
	center = cf.Position
	radius = (math.max(size.X, size.Y, size.Z) * 0.5) / math.tan(math.rad(cam.FieldOfView / 2)) * 1.1
	if hangarOn then -- v1.3: into the hangar, on the pedestal
		hSize, hBase = size, copy:GetPivot()
		hDiag = math.sqrt(size.X ^ 2 + size.Z ^ 2)
		copy.Parent = scene
		buildRoom()
		placeHangarCam()
	else
		copy.Parent = view
	end
	preview = copy
	player:SetAttribute("MainMenuPreviewParts", parts)
end

local function drawStage()
	modeTag.Text = mech and "MECH VIEW" or "DINO"
	modeTag.TextColor3 = mech and VOLT or GREY
	stageHint.Text = mech and "TAP FOR PLAIN DINO" or "TAP TO SEE MECH"
	player:SetAttribute("MainMenuView", mech and "mech" or "plain")
end

local function drawSpecies()
	local d = DINOS[dinoIndex()]
	dname.Text = d.name
	local locked = os.clock() < switchUntil or switchingTo ~= nil
	dsub.Text = locked and "SWITCHING..." or d.sub
	for _, bb in ipairs({prevB, nextB}) do
		bb.b.Active = not locked
		bb.b.BackgroundTransparency = locked and 0.5 or 0
	end
	prevText.TextTransparency = locked and 0.6 or 0
	nextText.TextTransparency = locked and 0.6 or 0
end

-- ---------- layout ----------
local function layout()
	measure()
	if S.W <= 0 or S.H <= 0 then return end
	local ch, cw = S.ch, S.cw
	local lx, lw = S.leftX, S.leftW
	local bottomY = S.H - S.bottom
	-- bottom up: hint / picker, slots, species row, stage
	local hintH = math.max(S.hintText * 1.4, 16)
	local pickH = S.chipH + 2 * ch
	local lowH = pickSlot and pickH or hintH
	if labOn then -- v1.2: GO TO THE LAB in the hint / picker row's place
		local labH = math.max(7 * ch, 40)
		lowH = labH
		placeButton(labB, lx, bottomY - labH, lw, labH, 1.6 * ch, 0.9 * ch, 0.6 * ch)
		labText.TextSize = math.max(2.8 * ch, 15)
	end
	slotHint.Position, slotHint.Size = UDim2.fromOffset(lx, bottomY - hintH), UDim2.fromOffset(lw, hintH)
	slotHint.TextSize = S.hintText
	picker.Position, picker.Size = UDim2.fromOffset(lx, bottomY - pickH), UDim2.fromOffset(lw, pickH)
	pickerCorner.CornerRadius = UDim.new(0, 1.4 * ch)
	pickPad.PaddingLeft, pickPad.PaddingRight = UDim.new(0, ch), UDim.new(0, ch)
	slotsRow.Size = UDim2.fromOffset(lw, 0)
	local slotsH = math.max(slotsRow.AbsoluteSize.Y, S.slotH)
	local slotsY = bottomY - lowH - S.gap - slotsH
	slotsRow.Position = UDim2.fromOffset(lx, slotsY)
	local spY = slotsY - S.gap - S.arrow
	local nameW = math.max(22 * cw, 120)
	local rowW = S.arrow * 2 + nameW + 2 * 1.6 * cw
	local rx = lx + (lw - rowW) / 2
	local drop = 0.6 * ch
	placeButton(prevB, rx, spY, S.arrow, S.arrow, 1.6 * ch, 0.9 * ch, drop)
	placeButton(nextB, rx + rowW - S.arrow, spY, S.arrow, S.arrow, 1.6 * ch, 0.9 * ch, drop)
	prevText.TextSize, nextText.TextSize = S.arrow * 0.7, S.arrow * 0.7
	local nameSize = math.max(4.6 * ch, 18)
	local subSize = math.max(1.9 * ch, 11)
	local nx = rx + S.arrow + 1.6 * cw
	local block = nameSize + 0.7 * ch + subSize
	dname.Position, dname.Size = UDim2.fromOffset(nx, spY + (S.arrow - block) / 2), UDim2.fromOffset(nameW, nameSize)
	dname.TextSize = nameSize
	dsub.Position, dsub.Size = UDim2.fromOffset(nx, spY + (S.arrow - block) / 2 + nameSize + 0.7 * ch), UDim2.fromOffset(nameW, subSize)
	dsub.TextSize = subSize
	local stageH = math.max(spY - S.gap - S.top, 60)
	stage.Position, stage.Size = UDim2.fromOffset(lx, S.top), UDim2.fromOffset(lw, stageH)
	hStage.x, hStage.y, hStage.w, hStage.h = lx, S.top, lw, stageH -- v1.3
	placeHangarCam()
	stageCorner.CornerRadius = UDim.new(0, 2.6 * ch)
	stageStroke.Thickness = math.max(0.35 * ch, 1.5)
	local tagSize = math.max(1.9 * ch, 11)
	modeTag.TextSize = tagSize
	modeTag.AutomaticSize = Enum.AutomaticSize.X
	modeTag.Size = UDim2.fromOffset(0, tagSize + 1.6 * ch)
	modeTag.Position = UDim2.fromOffset(2.4 * ch, 2.4 * ch)
	modeTagCorner.CornerRadius = UDim.new(0, ch)
	local mpad = modeTag:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	mpad.PaddingLeft, mpad.PaddingRight = UDim.new(0, 1.2 * ch), UDim.new(0, 1.2 * ch)
	mpad.Parent = modeTag
	local hint = math.max(2.2 * ch, 11)
	stageHint.TextSize = hint
	stageHint.Size = UDim2.new(1, 0, 0, hint + 4)
	stageHint.Position = UDim2.new(0, 0, 1, -(3.2 * ch + hint))
	if hangarOn and script:GetAttribute("MainMenuHintTopEnabled") ~= false then -- v1.4: hint above the dino's head
		local tagH = tagSize + 1.6 * ch
		stageHint.Position = UDim2.new(0, 0, 0, 2.4 * ch + (tagH - (hint + 4)) / 2)
		local band = 2.4 * ch + tagH + 0.8 * ch
		hStage.y, hStage.h = S.top + band, math.max(stageH - band, 40)
		placeHangarCam()
	end
	-- right column, centred vertically
	local tBig = 7.6 * ch
	local tSmall = tBig * 0.42
	local btnH = 13 * ch
	local btnGap = 2.2 * ch
	local total = tSmall + 0.6 * ch + tBig + 3 * ch + btnH * 2 + btnGap
	local ry = S.top + ((S.H - S.top - S.bottom) - total) / 2
	local rx2, rw = S.rightX, S.rightW
	titleSmall.Position, titleSmall.Size = UDim2.fromOffset(rx2, ry), UDim2.fromOffset(rw, tSmall)
	titleSmall.TextSize = tSmall
	local by = ry + tSmall + 0.6 * ch
	titleBig.Position, titleBig.Size = UDim2.fromOffset(rx2, by), UDim2.fromOffset(rw, tBig)
	titleBig.TextSize = tBig
	titleShadow.Position, titleShadow.Size = UDim2.fromOffset(rx2, by + 0.5 * ch), UDim2.fromOffset(rw, tBig)
	titleShadow.TextSize = tBig
	local y = by + tBig + 3 * ch
	for _, mb in ipairs({sandboxB, arenaB}) do
		placeButton(mb.bb, rx2, y, rw, btnH, 1.6 * ch, 0.9 * ch, drop)
		local nameS = 5 * ch
		local subS = math.max(2.1 * ch, 11)
		local tagS = math.max(1.9 * ch, 10)
		local padX = 3 * ch
		local tagW = tagS * 3.2 + 2 * ch
		local tb = nameS + 0.4 * ch + subS
		mb.t.TextSize, mb.s.TextSize, mb.g.TextSize = nameS, subS, tagS
		mb.t.Position = UDim2.fromOffset(padX, (btnH - tb) / 2 - 0.45 * ch)
		mb.t.Size = UDim2.fromOffset(rw - 2 * padX - tagW - ch, nameS)
		mb.s.Position = UDim2.fromOffset(padX, (btnH - tb) / 2 - 0.45 * ch + nameS + 0.4 * ch)
		mb.s.Size = UDim2.fromOffset(rw - 2 * padX - tagW - ch, subS)
		mb.g.Size = UDim2.fromOffset(tagW, tagS + 1.4 * ch)
		mb.g.Position = UDim2.fromOffset(rw - padX - tagW, (btnH - (tagS + 1.4 * ch)) / 2 - 0.45 * ch)
		mb.gc.CornerRadius = UDim.new(0, 0.9 * ch)
		y += btnH + btnGap
	end
	-- toast
	local toastS = math.max(3 * ch, 14)
	toast.TextSize = toastS
	toast.Size = UDim2.fromOffset(0, toastS + 2.8 * ch)
	toast.Position = UDim2.new(0.5, 0, 0, 12 * ch)
	toastCorner.CornerRadius = UDim.new(0, 1.6 * ch)
	toastPad.PaddingLeft, toastPad.PaddingRight = UDim.new(0, 2.4 * ch), UDim.new(0, 2.4 * ch)
end

function relayout()
	layout()
	task.defer(layout) -- after the slot row's automatic size settles
end

local function redraw()
	measure()
	drawSlots()
	drawStage()
	drawSpecies()
	relayout()
end

-- ---------- toast ----------
local MESSAGES = {
	saving = "SAVING YOUR LOADOUT...",
	teleporting = "TRAVELING...",
	teleportFailed = "COULDN'T TRAVEL · TRY AGAIN",
	noArenaPlace = "ARENA COMING SOON",
}
local function showToast(text, stay)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.Visible = text ~= ""
	player:SetAttribute("MainMenuToast", text)
	if not stay and text ~= "" then
		task.delay(3, function()
			if toastToken == my then
				toast.Visible = false
				player:SetAttribute("MainMenuToast", "")
			end
		end)
	end
end
local lastPressedMode = "arena"
-- v1.1: the egg loader covers trips
if script:GetAttribute("MainMenuTravelLoaderEnabled") == nil then script:SetAttribute("MainMenuTravelLoaderEnabled", true) end
local travelShown = false
local function travelLoader(r)
	if script:GetAttribute("MainMenuTravelLoaderEnabled") == false then return end
	local loader = game:GetService("ReplicatedFirst"):FindFirstChild("EggLoader")
	local showFn = loader and loader:FindFirstChild("Show")
	local hideFn = loader and loader:FindFirstChild("Hide")
	if (r == "saving" or r == "teleporting") and not travelShown then
		if showFn then
			travelShown = true
			local target = lastPressedMode == "sandbox" and "Sandbox" or "Arena"
			local ok, g = pcall(function() return showFn:Invoke(target) end)
			if ok and g then pcall(function() game:GetService("TeleportService"):SetTeleportGui(g) end) end
			player:SetAttribute("MainMenuTravelLoader", "shown")
		else
			player:SetAttribute("MainMenuTravelLoader", "none")
		end
	elseif r == "teleportFailed" and travelShown then
		travelShown = false
		if hideFn then pcall(function() hideFn:Invoke() end) end
		player:SetAttribute("MainMenuTravelLoader", "hidden")
	end
end
player:GetAttributeChangedSignal("ModeLastAt"):Connect(function()
	local r = player:GetAttribute("ModeLastResult")
	travelLoader(r) -- v1.1
	if r == "studio" then
		showToast((lastPressedMode == "sandbox" and "SANDBOX" or "ARENA") .. " OPENS IN THE LIVE GAME", false)
	elseif r == "saving" or r == "teleporting" then
		showToast(MESSAGES[r], true)
	elseif MESSAGES[r] then
		showToast(MESSAGES[r], false)
	elseif r == "ok" then
		showToast("", false)
	end
end)

-- ---------- input ----------
stage.Activated:Connect(function()
	mech = not mech
	press("flip")
	drawStage()
	rebuildPreview()
end)
local function switchDino(step)
	if os.clock() < switchUntil or switchingTo ~= nil then return end
	local i = dinoIndex()
	local j = ((i - 1 + step) % #DINOS) + 1
	if j == i then return end
	press(step < 0 and "prev" or "next")
	switchingTo = DINOS[j].id
	switchUntil = os.clock() + SWITCH_LOCK
	pickSlot = nil
	if speciesRemote then speciesRemote:FireServer(switchingTo) end
	drawSpecies()
	task.delay(SWITCH_LOCK + 0.05, drawSpecies)
	task.delay(8, function() -- the server said no (cooldown / same): unlock anyway
		if switchingTo ~= nil then
			switchingTo = nil
			redraw()
		end
	end)
end
labB.b.Activated:Connect(function() -- v1.2
	press("lab")
	local ps = player:FindFirstChild("PlayerScripts")
	local lab = ps and ps:FindFirstChild("Lab")
	local open = lab and lab:FindFirstChild("Open")
	if open then pcall(function() open:Invoke("full") end) end
end)
prevB.b.Activated:Connect(function() switchDino(-1) end)
nextB.b.Activated:Connect(function() switchDino(1) end)
-- v1.3: the egg while the island loads (this server's mode only; a hop uses the travel loader)
if script:GetAttribute("MainMenuPlayLoaderEnabled") == nil then script:SetAttribute("MainMenuPlayLoaderEnabled", true) end
local playShown = false
local function playLoader(modeName)
	if script:GetAttribute("MainMenuPlayLoaderEnabled") == false then return end
	if player:GetAttribute("DinoMode") ~= modeName then return end
	local loader = game:GetService("ReplicatedFirst"):FindFirstChild("EggLoader")
	local playFn = loader and loader:FindFirstChild("Play")
	if playFn then
		playShown = true
		pcall(function() playFn:Invoke(modeName == "arena" and "Arena" or "Sandbox") end)
		player:SetAttribute("MainMenuPlayLoader", "shown")
	else
		player:SetAttribute("MainMenuPlayLoader", "none")
	end
end
player:GetAttributeChangedSignal("ModeLastAt"):Connect(function()
	local r = player:GetAttribute("ModeLastResult")
	if playShown and (r == "busy" or r == "badArg") then
		playShown = false
		local loader = game:GetService("ReplicatedFirst"):FindFirstChild("EggLoader")
		local hideFn = loader and loader:FindFirstChild("Hide")
		if hideFn then pcall(function() hideFn:Invoke() end) end
		player:SetAttribute("MainMenuPlayLoader", "hidden")
	elseif r == "ok" then
		playShown = false
	end
end)
sandboxB.bb.b.Activated:Connect(function()
	press("sandbox")
	lastPressedMode = "sandbox"
	playLoader("sandbox") -- v1.3
	if modeRemote then modeRemote:FireServer("sandbox") end
end)
arenaB.bb.b.Activated:Connect(function()
	press("arena")
	lastPressedMode = "arena"
	playLoader("arena") -- v1.3
	if modeRemote then modeRemote:FireServer("arena") end
end)

-- ---------- open / close ----------
local open = false
local function setOpen(on)
	if on == open then return end
	open = on
	gui.Enabled = on
	if hgui then hgui.Enabled = on end -- v1.3
	player:SetAttribute("MainMenuOpen", on)
	blur.Parent = workspace.CurrentCamera
	blur.Enabled = on
	if on then
		pickSlot = nil
		lastPreviewKey = nil
		redraw()
		rebuildPreview()
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		RunService:UnbindFromRenderStep(BIND)
		toast.Visible = false
	end
end

RunService.RenderStepped:Connect(function(dt)
	if not open then return end
	orbit += dt * 0.45
	if hangarOn then -- v1.3: the dino turns on the pedestal, the camera stays
		if preview and preview.Parent then
			preview:PivotTo(CFrame.new(center) * CFrame.Angles(0, orbit, 0) * CFrame.new(-center) * hBase)
		end
		return
	end
	local off = Vector3.new(math.sin(orbit), 0.32, math.cos(orbit)).Unit * radius
	cam.CFrame = CFrame.lookAt(center + off, center)
end)

local charConns = {}
local refreshQueued = false
local function queueRefresh()
	if refreshQueued then return end
	refreshQueued = true
	task.delay(0.25, function()
		refreshQueued = false
		if open then
			rebuildPreview()
			drawSpecies()
		end
	end)
end
local function onChar(c)
	for _, cn in ipairs(charConns) do cn:Disconnect() end
	table.clear(charConns)
	if switchingTo ~= nil then switchingTo = nil end
	table.insert(charConns, c.ChildAdded:Connect(function(ch) if ch.Name:sub(1, 6) == "Mecha_" then queueRefresh() end end))
	table.insert(charConns, c.ChildRemoved:Connect(function(ch) if ch.Name:sub(1, 6) == "Mecha_" then queueRefresh() end end))
	table.insert(charConns, c:GetAttributeChangedSignal("Species"):Connect(function() if open then redraw() queueRefresh() end end))
	if open then
		task.delay(0.5, function()
			if player.Character == c then
				redraw()
				queueRefresh()
			end
		end)
	end
end
player.CharacterAdded:Connect(onChar)
if player.Character then onChar(player.Character) end

player.AttributeChanged:Connect(function(name)
	if name == "InMenu" then
		setOpen(player:GetAttribute("InMenu") == true)
	elseif open and (name:sub(1, 9) == "SkillSlot" or name:sub(1, 10) == "SkillPath_") then
		drawSlots()
		relayout()
	end
end)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if open then redraw() end end)

setOpen(player:GetAttribute("InMenu") == true)
