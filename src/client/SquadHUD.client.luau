-- SquadHUD v1.0 (Mecha Dino Arena) — the Arena squad HUD (LocalScript in StarterPlayerScripts, all devices). MDA-162, plan
-- docs/plans/SQUADS_v1.0.md Task S5, mockup docs/mockups/arena_squads_options.html option A "Under my health" (Kepu
-- 2026-10-31: "Just have a button under skills that allows me to send an invite to someone to squad up. Also lets me unsquad
-- with that person and shows me their health when we're squadded up").
-- Shows only while ReplicatedStorage.SquadsLive == true (SquadServer 1.0: the Arena) and the player's InMenu ~= true.
-- SQUAD pill: ScreenGui "SquadButton" (DisplayOrder 6, DeviceSafeInsets, ResetOnSpawn false); the SKILLS pill's look (PANEL
--   rgb(20, 20, 26) at 0.18, white stroke 0.5 / 1.5 px, corner 10, height 36, padding 12, FredokaOne 18 "SQUAD"); right edge
--   lined up with PlayerGui.LabButton.Skills, top = its bottom + 8 (followed every 0.25 s; shown only while that pill shows,
--   so it hides with the Lab open or in the menu). In a squad: 4 dots (8 px) after the text, green rgb(120, 200, 80) per
--   member, grey rgb(58, 69, 86) per free place. Tap / click (PC: with Left Alt held, like SKILLS) or the G key toggles the
--   panel.
-- Panel (under the pill, right-aligned, width min(40% of the screen, 330 px)): "SQUAD" + "n / 4" (yellow); "IN YOUR SQUAD"
--   rows (◆ name, "DINO · h / max HP", green SQUADMATE tag); a red rgb(224, 40, 74) LEAVE SQUAD button (in a squad only);
--   "ON THE ISLAND": every other player not in the menu, with INVITE (yellow), INVITED… (dark, 5 s), IN A SQUAD / SQUAD FULL
--   (grey, no action); a scroll list of at most 6 rows. While it is open the PC mouse is free (RenderStep "SquadMouse",
--   Camera + 1, the LeaveConfirm pattern). Buttons fire ReplicatedStorage.DinoSquadRequest ("invite", userId) / ("leave").
-- Invite card: ScreenGui "SquadInvite" (DisplayOrder 30, full screen, the LeaveConfirm look) while the player's
--   SquadInviteUntil is in the future: dim + card (80% wide, at most 340 px, yellow stroke): "SQUAD INVITE", "<name> wants
--   to squad up.", "No friendly fire, respawn together.", a yellow time bar, NO (dark) / JOIN (yellow) -> "decline" /
--   "accept". It closes when the invite ends (answered, expired, cleared).
-- Health rows: inside PlayerGui.ArenaStatus.BarsBL (ArenaStatus 1.3+ bottom-left bars), Frames "SquadRow_<UserId>" with
--   LayoutOrder -4..-1 (above HEALTH), one per squadmate (SquadRules.members order): label 12 px green rgb(156, 240, 138)
--   "◆ name", right "h / max" or "DOWN · respawning" (dead / no character); an 8 px bar in ArenaStatus' colours (green,
--   red below 30%). Re-added after ArenaStatus is rebuilt (respawn). Refreshed every 0.2 s.
-- Over-head tags: BillboardGuis "SquadTag_<UserId>" in a ScreenGui "SquadTags" (ResetOnSpawn false; this client only), Adornee =
--   the squadmate's Head (else HumanoidRootPart), AlwaysOnTop, StudsOffset (0, 4 x the character's scale, 0): green "◆ name"
--   (FredokaOne 14). Hidden while the squadmate is dead.
-- Toasts (top centre, 2.2 s): "Invite sent to X", "X is in another squad", "Your squad is full", "X is in the menu",
--   "X joined your squad", "You joined X's squad", "You left the squad", "Your squad ended".
-- Studio check: a Workspace model whose SquadTestId equals your SquadId (SquadServer's server-only SquadTest hook on ArenaPvP's
--   test target) gets a health row and a tag like a squadmate (name = the model name), so the rows can be checked without a
--   second player. Such models never exist in a live server.
-- Switch: script attribute SquadHUDEnabled (default true, read at start; false = nothing is built).
-- Diagnostics: player SquadHUDVersion, SquadHUDPanel ("open" / "closed"), SquadHUDRows (health rows shown), SquadHUDInvite
--   ("shown" / "hidden"), SquadHUDLastPress.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
local player = Players.LocalPlayer
player:SetAttribute("SquadHUDVersion", VERSION)
if script:GetAttribute("SquadHUDEnabled") == nil then script:SetAttribute("SquadHUDEnabled", true) end
if script:GetAttribute("SquadHUDEnabled") == false then return end

local PANEL = Color3.fromRGB(20, 20, 26)
local DARK = Color3.fromRGB(42, 51, 64)
local YELLOW, YELLOW_TEXT = Color3.fromRGB(255, 200, 50), Color3.fromRGB(27, 20, 6)
local RED = Color3.fromRGB(224, 40, 74)
local MATE = Color3.fromRGB(156, 240, 138)
local DOT_ON, DOT_OFF = Color3.fromRGB(120, 200, 80), Color3.fromRGB(58, 69, 86)
local GREEN_A, GREEN_B = Color3.fromRGB(95, 209, 106), Color3.fromRGB(63, 174, 75)
local RED_A, RED_B = Color3.fromRGB(240, 90, 79), Color3.fromRGB(201, 47, 38)
local GREY_TEXT = Color3.fromRGB(154, 166, 182)
local MAX_ROWS, ROW_H = 6, 40
local INVITED_SHOW = 5

local pg = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("DinoSquadRequest", 30)
local shared = ReplicatedStorage:WaitForChild("SquadShared", 30)
local R = shared and require(shared:WaitForChild("SquadRules", 30))
if not remote or not R then return end

local function press(v) player:SetAttribute("SquadHUDLastPress", v) end
local lastAction = ""
local function fire(action, ...) -- every request goes through here (the toasts need the last action)
	lastAction = action
	remote:FireServer(action, ...)
end
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = p end
local function stroke(p, t, th, color)
	local s = Instance.new("UIStroke")
	s.Color, s.Transparency, s.Thickness = color or Color3.new(1, 1, 1), t, th or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function label(parent, name, t, size, color, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.Text, l.TextSize = t, size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.6
	l.Parent = parent
	return l
end
local function pad(p, n)
	local u = Instance.new("UIPadding")
	for _, k in ipairs({"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"}) do u[k] = UDim.new(0, n) end
	u.Parent = p
end
local function vlist(p, gap)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	l.Parent = p
	return l
end
local function smallBtn(parent, text, bg, fg)
	local b = Instance.new("TextButton")
	b.Name = "Btn"
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, 0, 0.5, 0)
	b.Size = UDim2.fromOffset(104, 28)
	b.BackgroundColor3 = bg
	b.AutoButtonColor = true
	b.Font = Enum.Font.FredokaOne
	b.Text, b.TextSize, b.TextColor3 = text, 15, fg
	b.Parent = parent
	corner(b, 8)
	return b
end

-- toasts -----------------------------------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SquadButton"
gui.DisplayOrder = 6
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Parent = pg
local toastL = label(gui, "Toast", "", 17)
toastL.AnchorPoint = Vector2.new(0.5, 0)
toastL.Position = UDim2.new(0.5, 0, 0, 56)
toastL.Size = UDim2.fromOffset(0, 30)
toastL.AutomaticSize = Enum.AutomaticSize.X
toastL.BackgroundColor3 = PANEL
toastL.BackgroundTransparency = 0.1
toastL.TextXAlignment = Enum.TextXAlignment.Center
toastL.Visible = false
corner(toastL, 10)
stroke(toastL, 0.2, 2, DOT_ON)
local tp = Instance.new("UIPadding")
tp.PaddingLeft, tp.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
tp.Parent = toastL
local toastSeq = 0
local function toast(t)
	toastSeq += 1
	local my = toastSeq
	toastL.Text = t
	toastL.Visible = true
	task.delay(2.2, function() if toastSeq == my then toastL.Visible = false end end)
end

-- pill -------------------------------------------------------------------------------------------------------------------
local pill = Instance.new("TextButton")
pill.Name = "Squad"
pill.AnchorPoint = Vector2.new(1, 0)
pill.Size = UDim2.fromOffset(0, 36)
pill.AutomaticSize = Enum.AutomaticSize.X
pill.BackgroundColor3 = PANEL
pill.BackgroundTransparency = 0.18
pill.Text = ""
pill.AutoButtonColor = false
pill.Visible = false
pill.Parent = gui
corner(pill, 10)
local pillStroke = stroke(pill, 0.5, 1.5)
pad(pill, 0)
do
	local u = pill:FindFirstChildOfClass("UIPadding")
	u.PaddingLeft, u.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
end
local hl = Instance.new("UIListLayout")
hl.FillDirection = Enum.FillDirection.Horizontal
hl.VerticalAlignment = Enum.VerticalAlignment.Center
hl.SortOrder = Enum.SortOrder.LayoutOrder
hl.Padding = UDim.new(0, 6)
hl.Parent = pill
local pillText = label(pill, "T", "SQUAD", 18)
pillText.AutomaticSize = Enum.AutomaticSize.X
pillText.Size = UDim2.fromOffset(0, 36)
local dots = Instance.new("Frame")
dots.Name = "Dots"
dots.BackgroundTransparency = 1
dots.Size = UDim2.fromOffset(4 * 8 + 3 * 3, 8)
dots.LayoutOrder = 2
dots.Visible = false
dots.Parent = pill
local dotList = {}
for i = 1, 4 do
	local d = Instance.new("Frame")
	d.Size = UDim2.fromOffset(8, 8)
	d.Position = UDim2.fromOffset((i - 1) * 11, 0)
	d.BackgroundColor3 = DOT_OFF
	d.Parent = dots
	corner(d, 4)
	dotList[i] = d
end

-- panel ------------------------------------------------------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Size = UDim2.new(0.4, 0, 0, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.06
panel.Visible = false
panel.Parent = gui
corner(panel, 14)
stroke(panel, 0.55, 2)
pad(panel, 12)
vlist(panel, 8)
do
	local c = Instance.new("UISizeConstraint")
	c.MaxSize = Vector2.new(330, math.huge)
	c.MinSize = Vector2.new(250, 0)
	c.Parent = panel
end
local open = false
local invitedAt = {} -- [userId] = os.clock() of our last invite press
local lastInviteName = ""

local function setOpen(v)
	open = v and pill.Visible
	panel.Visible = open
	pillStroke.Color = open and YELLOW or Color3.new(1, 1, 1)
	pillStroke.Transparency = open and 0 or 0.5
	player:SetAttribute("SquadHUDPanel", open and "open" or "closed")
	if open then
		RunService:BindToRenderStep("SquadMouse", Enum.RenderPriority.Camera.Value + 1, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		pcall(function() RunService:UnbindFromRenderStep("SquadMouse") end)
	end
end
player:SetAttribute("SquadHUDPanel", "closed")

local function speciesOf(p)
	local c = p.Character
	local s = c and c:GetAttribute("Species")
	if s == "TRex" then return "T-REX" end
	return type(s) == "string" and string.upper(s) or "DINO"
end
local function hpOf(p)
	local c = p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return nil end
	return h.Health, math.max(1, h.MaxHealth)
end

local panelSig = ""
local function row(parent, order, title, sub, titleColor)
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.LayoutOrder = order
	f.Size = UDim2.new(1, 0, 0, ROW_H)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.94
	f.Parent = parent
	corner(f, 10)
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, -16, 1, 0)
	inner.Position = UDim2.fromOffset(8, 0)
	inner.Parent = f
	local t = label(inner, "Name", title, 16, titleColor)
	t.Size = UDim2.new(1, -110, 0, 20)
	t.Position = UDim2.fromOffset(0, 2)
	t.TextTruncate = Enum.TextTruncate.AtEnd
	local s = label(inner, "Sub", sub, 12, GREY_TEXT)
	s.Font = Enum.Font.GothamBold
	s.Size = UDim2.new(1, -110, 0, 14)
	s.Position = UDim2.fromOffset(0, 22)
	s.TextStrokeTransparency = 1
	return inner
end
local function section(order, t)
	local l = label(panel, "Section", t, 12, GREY_TEXT)
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, 14)
	l.TextStrokeTransparency = 1
	return l
end

local function rebuildPanel(force)
	local myId = R.idOfPlayer(player)
	local members = myId ~= "" and R.members(myId) or {}
	local size = math.max(1, #members)
	local others = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p:GetAttribute("InMenu") ~= true and not (myId ~= "" and R.idOfPlayer(p) == myId) then
			table.insert(others, p)
		end
	end
	table.sort(others, function(a, b) return a.Name < b.Name end)
	local now = os.clock()
	local sigParts = {myId, tostring(size)}
	for _, p in ipairs(members) do
		local h, m = hpOf(p)
		table.insert(sigParts, p.Name .. ":" .. speciesOf(p) .. ":" .. (h and math.floor(h + 0.5) or -1) .. "/" .. (m and math.floor(m) or 0))
	end
	for _, p in ipairs(others) do
		local inv = invitedAt[p.UserId] and now - invitedAt[p.UserId] < INVITED_SHOW
		table.insert(sigParts, p.Name .. ":" .. speciesOf(p) .. ":" .. R.idOfPlayer(p) .. ":" .. tostring(inv))
	end
	local sig = table.concat(sigParts, "|")
	if sig == panelSig and not force then return end
	panelSig = sig
	for _, ch in ipairs(panel:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local head = Instance.new("Frame")
	head.Name = "Header"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 24)
	head.LayoutOrder = 1
	head.Parent = panel
	local ht = label(head, "Title", "SQUAD", 20)
	ht.Size = UDim2.fromScale(0.6, 1)
	local hc = label(head, "Count", ("%d / %d"):format(size, R.MAX), 16, YELLOW, Enum.TextXAlignment.Right)
	hc.Size = UDim2.fromScale(0.4, 1)
	hc.Position = UDim2.fromScale(0.6, 0)
	local order = 2
	if myId ~= "" then
		section(order, "IN YOUR SQUAD") order += 1
		for _, p in ipairs(members) do
			if p ~= player then
				local h, m = hpOf(p)
				local sub = speciesOf(p) .. " · " .. (h and ("%d / %d HP"):format(math.floor(h + 0.5), math.floor(m + 0.5)) or "down")
				local inner = row(panel, order, "◆ " .. p.Name, sub, MATE)
				order += 1
				local tag = smallBtn(inner, "SQUADMATE", Color3.fromRGB(61, 138, 58), Color3.new(1, 1, 1))
				tag.AutoButtonColor = false
				tag.Active = false
			end
		end
		local leave = Instance.new("TextButton")
		leave.Name = "Leave"
		leave.LayoutOrder = order
		order += 1
		leave.Size = UDim2.new(1, 0, 0, 34)
		leave.BackgroundColor3 = RED
		leave.Font = Enum.Font.FredokaOne
		leave.Text, leave.TextSize, leave.TextColor3 = "LEAVE SQUAD", 17, Color3.new(1, 1, 1)
		leave.Parent = panel
		corner(leave, 10)
		leave.Activated:Connect(function()
			press("leave")
			fire("leave")
		end)
	end
	section(order, "ON THE ISLAND") order += 1
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Island"
	scroll.LayoutOrder = order
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.Size = UDim2.new(1, 0, 0, math.max(1, math.min(#others, MAX_ROWS)) * (ROW_H + 6))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	vlist(scroll, 6)
	if #others == 0 then
		local none = label(scroll, "None", "nobody else on the island", 14, GREY_TEXT)
		none.Size = UDim2.new(1, 0, 0, ROW_H)
		none.TextStrokeTransparency = 1
	end
	for i, p in ipairs(others) do
		local inner = row(scroll, i, p.Name, speciesOf(p))
		local theirs = R.idOfPlayer(p)
		local inv = invitedAt[p.UserId] and now - invitedAt[p.UserId] < INVITED_SHOW
		if theirs ~= "" then
			smallBtn(inner, "IN A SQUAD", DARK, GREY_TEXT).AutoButtonColor = false
		elseif size >= R.MAX then
			smallBtn(inner, "SQUAD FULL", DARK, GREY_TEXT).AutoButtonColor = false
		elseif inv then
			smallBtn(inner, "INVITED…", DARK, Color3.new(1, 1, 1)).AutoButtonColor = false
		else
			local b = smallBtn(inner, "INVITE", YELLOW, YELLOW_TEXT)
			b.Activated:Connect(function()
				press("invite:" .. p.Name)
				invitedAt[p.UserId] = os.clock()
				lastInviteName = p.Name
				fire("invite", p.UserId)
				rebuildPanel(true)
			end)
		end
	end
end

pill.Activated:Connect(function()
	press("pill")
	setOpen(not open)
	if open then rebuildPanel(true) end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.G then return end
	if not pill.Visible then return end
	press("key:G")
	setOpen(not open)
	if open then rebuildPanel(true) end
end)

-- results -> toasts ------------------------------------------------------------------------------------------------------
local RESULT_TEXT = {
	inSquad = function() return lastInviteName .. " is in another squad" end,
	full = function() return "Your squad is full" end,
	targetMenu = function() return lastInviteName .. " is in the menu" end,
	noTarget = function() return lastInviteName .. " left the island" end,
	cooldown = function() return "Wait a moment before inviting " .. lastInviteName .. " again" end,
	gone = function() return "That squad isn't there any more" end,
	noInvite = function() return "The invite ran out" end,
}
player:GetAttributeChangedSignal("SquadResultAt"):Connect(function()
	local r = player:GetAttribute("SquadResult")
	local f = RESULT_TEXT[r]
	if r == "ok" and lastAction == "invite" then
		toast("Invite sent to " .. lastInviteName)
	elseif f then
		toast(f())
		if lastAction == "invite" then
			for uid in pairs(invitedAt) do invitedAt[uid] = nil end
		end
	end
	panelSig = ""
end)

local knownMembers = {}
local lastId = R.idOfPlayer(player)
local function onSquadChange()
	local id = R.idOfPlayer(player)
	local members = id ~= "" and R.members(id) or {}
	local now = {}
	for _, p in ipairs(members) do now[p] = true end
	if id ~= lastId then
		if id == "" then
			local why = player:GetAttribute("SquadLeftReason")
			toast(why == "dissolved" and "Your squad ended" or "You left the squad")
		else
			local other
			for _, p in ipairs(members) do if p ~= player then other = other or p end end
			if lastAction == "accept" and other then toast("You joined " .. other.Name .. "'s squad") end
		end
		knownMembers = now
		lastId = id
	else
		for p in pairs(now) do
			if not knownMembers[p] and p ~= player then toast(p.Name .. " joined your squad") end
		end
		knownMembers = now
	end
	panelSig = ""
end

-- invite card ------------------------------------------------------------------------------------------------------------
local cardGui, cardBar
local function closeCard()
	if cardGui then cardGui:Destroy() cardGui = nil end
	pcall(function() RunService:UnbindFromRenderStep("SquadInviteMouse") end)
	player:SetAttribute("SquadHUDInvite", "hidden")
end
local function showCard(fromName)
	closeCard()
	local g = Instance.new("ScreenGui")
	g.Name = "SquadInvite"
	g.DisplayOrder = 30
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
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
	stroke(card, 0, 2, YELLOW)
	pad(card, 18)
	local lay = vlist(card, 10)
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local t = label(card, "Title", "SQUAD INVITE", 26, YELLOW, Enum.TextXAlignment.Center)
	t.Size = UDim2.new(1, 0, 0, 30)
	t.LayoutOrder = 1
	local b = label(card, "Body", fromName .. " wants to squad up.\nNo friendly fire, respawn together.", 16, Color3.fromRGB(207, 211, 220), Enum.TextXAlignment.Center)
	b.Font = Enum.Font.GothamBold
	b.TextWrapped = true
	b.Size = UDim2.new(1, 0, 0, 44)
	b.LayoutOrder = 2
	b.TextStrokeTransparency = 1
	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.new(1, 0, 0, 6)
	barBack.BackgroundColor3 = DARK
	barBack.LayoutOrder = 3
	barBack.Parent = card
	corner(barBack, 3)
	cardBar = Instance.new("Frame")
	cardBar.Size = UDim2.fromScale(1, 1)
	cardBar.BackgroundColor3 = YELLOW
	cardBar.BorderSizePixel = 0
	cardBar.Parent = barBack
	corner(cardBar, 3)
	local rowF = Instance.new("Frame")
	rowF.BackgroundTransparency = 1
	rowF.Size = UDim2.new(1, 0, 0, 46)
	rowF.LayoutOrder = 4
	rowF.Parent = card
	local function btn(name, text, bg, fg, x)
		local bb = Instance.new("TextButton")
		bb.Name = name
		bb.Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0)
		bb.Size = UDim2.new(0.5, -6, 1, 0)
		bb.BackgroundColor3 = bg
		bb.Font = Enum.Font.FredokaOne
		bb.Text, bb.TextSize, bb.TextColor3 = text, 22, fg
		bb.Parent = rowF
		corner(bb, 12)
		stroke(bb, 0.6, 2)
		return bb
	end
	btn("No", "NO", Color3.fromRGB(34, 36, 46), Color3.new(1, 1, 1), 0).Activated:Connect(function()
		press("decline")
		fire("decline")
		closeCard()
	end)
	btn("Join", "JOIN", YELLOW, YELLOW_TEXT, 0.5).Activated:Connect(function()
		press("accept")
		fire("accept")
		closeCard()
	end)
	g.Parent = pg
	cardGui = g
	player:SetAttribute("SquadHUDInvite", "shown")
	RunService:BindToRenderStep("SquadInviteMouse", Enum.RenderPriority.Camera.Value + 1, function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)
end
player:SetAttribute("SquadHUDInvite", "hidden")

-- health rows + tags -----------------------------------------------------------------------------------------------------
local tagFolder = Instance.new("ScreenGui") -- a ScreenGui with ResetOnSpawn false survives respawns (a Folder does not)
tagFolder.Name = "SquadTags"
tagFolder.ResetOnSpawn = false
tagFolder.Parent = pg
local function updateRows(mates)
	local status = pg:FindFirstChild("ArenaStatus")
	local holder = status and status:FindFirstChild("BarsBL", true)
	local keep = {}
	local shown = 0
	if holder then
		for i, p in ipairs(mates) do
			local name = "SquadRow_" .. p.UserId
			keep[name] = true
			local f = holder:FindFirstChild(name)
			if not f then
				f = Instance.new("Frame")
				f.Name = name
				f.BackgroundTransparency = 1
				f.Size = UDim2.new(1, 0, 0, 14 + 3 + 8)
				local l = label(f, "L", "", 12, MATE)
				l.Size = UDim2.new(0.6, 0, 0, 14)
				l.TextTruncate = Enum.TextTruncate.AtEnd
				local r = label(f, "R", "", 12, Color3.new(1, 1, 1), Enum.TextXAlignment.Right)
				r.Position = UDim2.new(0.6, 0, 0, 0)
				r.Size = UDim2.new(0.4, 0, 0, 14)
				local back = Instance.new("Frame")
				back.Name = "Back"
				back.Position = UDim2.fromOffset(0, 17)
				back.Size = UDim2.new(1, 0, 0, 8)
				back.BackgroundColor3 = PANEL
				back.Parent = f
				corner(back, 8)
				stroke(back, 0.55)
				local fill = Instance.new("Frame")
				fill.Name = "Fill"
				fill.Size = UDim2.fromScale(1, 1)
				fill.BackgroundColor3 = Color3.new(1, 1, 1)
				fill.BorderSizePixel = 0
				fill.Parent = back
				corner(fill, 8)
				local grad = Instance.new("UIGradient")
				grad.Rotation = 90
				grad.Parent = fill
				f.Parent = holder
			end
			f.LayoutOrder = -#mates - 1 + i
			local h, m = hpOf(p)
			f.L.Text = "◆ " .. p.Name
			f.R.Text = h and ("%d / %d"):format(math.floor(h + 0.5), math.floor(m + 0.5)) or "DOWN · respawning"
			f.Back.Fill.Size = UDim2.fromScale(h and h / m or 0, 1)
			local low = h and h / m < 0.3
			f.Back.Fill.UIGradient.Color = low and ColorSequence.new(RED_A, RED_B) or ColorSequence.new(GREEN_A, GREEN_B)
			shown += 1
		end
		for _, ch in ipairs(holder:GetChildren()) do
			if ch.Name:sub(1, 9) == "SquadRow_" and not keep[ch.Name] then ch:Destroy() end
		end
	end
	if player:GetAttribute("SquadHUDRows") ~= shown then player:SetAttribute("SquadHUDRows", shown) end
end
local function updateTags(mates)
	local keep = {}
	for _, p in ipairs(mates) do
		local name = "SquadTag_" .. p.UserId
		local c = p.Character
		local adorn = c and (c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart"))
		local alive = hpOf(p) ~= nil
		if adorn and alive then
			keep[name] = true
			local g = tagFolder:FindFirstChild(name)
			if not g then
				g = Instance.new("BillboardGui")
				g.Name = name
				g.AlwaysOnTop = true
				g.Size = UDim2.fromOffset(160, 24)
				g.LightInfluence = 0
				local l = label(g, "L", "", 14, MATE, Enum.TextXAlignment.Center)
				l.Size = UDim2.fromScale(1, 1)
				l.TextStrokeTransparency = 0.2
				g.Parent = tagFolder
			end
			g.Adornee = adorn
			local ok, s = pcall(function() return c:GetScale() end)
			g.StudsOffset = Vector3.new(0, 4 * (ok and s or 1), 0)
			g.L.Text = "◆ " .. p.Name
		end
	end
	for _, g in ipairs(tagFolder:GetChildren()) do
		if not keep[g.Name] then g:Destroy() end
	end
end

-- main loop --------------------------------------------------------------------------------------------------------------
local lastPlace = 0
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	if t - lastPlace < 0.2 then return end
	lastPlace = t
	local live = R.live() and player:GetAttribute("InMenu") ~= true
	-- pill place
	local lb = pg:FindFirstChild("LabButton")
	local skills = lb and lb:FindFirstChild("Skills")
	local skillsShown = skills and skills.Visible and lb.Enabled ~= false
	pill.Visible = live and skillsShown == true
	if pill.Visible then
		local o = gui.AbsolutePosition -- AbsolutePosition is screen space; Position offsets start at this gui's origin
		pill.Position = UDim2.fromOffset(skills.AbsolutePosition.X + skills.AbsoluteSize.X - o.X, skills.AbsolutePosition.Y + skills.AbsoluteSize.Y + 8 - o.Y)
		panel.Position = UDim2.fromOffset(pill.AbsolutePosition.X + pill.AbsoluteSize.X - o.X, pill.AbsolutePosition.Y + pill.AbsoluteSize.Y + 6 - o.Y)
	elseif open then
		setOpen(false)
	end
	-- squad state
	local id = R.idOfPlayer(player)
	if id ~= lastId then onSquadChange() end
	local members = (live and id ~= "") and R.members(id) or {}
	local mates = {}
	for _, p in ipairs(members) do if p ~= player then table.insert(mates, p) end end
	if live and id ~= "" then -- Studio check: the SquadTest model as a squadmate
		for _, m in ipairs(workspace:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("SquadTestId") == id then
				table.insert(mates, {Name = m.Name, UserId = "Test" .. m.Name, Character = m})
			end
		end
	end
	if #members ~= 0 then
		local now = {}
		for _, p in ipairs(members) do now[p] = true end
		for p in pairs(now) do if not knownMembers[p] then onSquadChange() break end end
	end
	dots.Visible = id ~= ""
	for i = 1, 4 do dotList[i].BackgroundColor3 = i <= #members and DOT_ON or DOT_OFF end
	updateRows(mates)
	updateTags(mates)
	if open then rebuildPanel(false) end
	-- invite card
	local untilT = tonumber(player:GetAttribute("SquadInviteUntil"))
	local from = player:GetAttribute("SquadInviteFromName")
	local srvNow = workspace:GetServerTimeNow()
	if live and untilT and untilT > srvNow and type(from) == "string" then
		if not cardGui or cardGui:GetAttribute("From") ~= from .. untilT then
			showCard(from)
			cardGui:SetAttribute("From", from .. untilT)
		end
		if cardBar then cardBar.Size = UDim2.fromScale(math.clamp((untilT - srvNow) / 15, 0, 1), 1) end
	elseif cardGui then
		closeCard()
	end
end)
