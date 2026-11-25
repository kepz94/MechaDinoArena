-- EmoteWheel v1.0 (Mecha Dino Arena) — how a player fires a battle emote. Plan docs/plans/EMOTES_v1.0.md; mockup
-- docs/mockups/emote_wheel_v0.1.html, Kepu 2026-11-24 20:27 picks: phone "A · Pill next to ☰", PC "B", empty slots "Greyed shop slots".
-- Phone (player PhoneHudV2, PhoneMenu 1.0): a ☻ pill 44 x 36 (ScreenGui "EmoteWheel", DeviceSafeInsets) at AnchorPoint (1, 0),
--   (1, -68, 0, 8): left of ☰ with an 8 px gap, same panel / yellow stroke look. Tap -> the wheel opens in the middle; tap a slot ->
--   plays. Or hold the pill, slide onto a slot, let go. Tap outside closes. While EmoteCooldownUntil is ahead the pill shows the seconds.
-- PC: hold B -> the wheel opens; the mouse direction from the middle picks a slot; let go of B -> plays it (no pick = close). A click
--   on a slot also plays. During RespawnScreen's pick window (RespawnHold, RespawnGraceUntil) B stays the spawn picker.
-- Wheel: 8 slots from player EmoteWheel (EmoteServer 1.0) on an ellipse round a hub. An empty slot shows the next paid emote the
--   player does not own, greyed with 149 R$; tapping it says where to get it (the Shop is in the main menu). Nothing left -> EMPTY.
-- Owner cancel: while the own character has EmoteId, moving or jumping sends ("stop") at once (the server also cancels).
-- Shown only out of the menu, alive, and while ReplicatedStorage.EmoteShared exists (EmoteServer on).
-- Switches (script attributes): EmoteWheelEnabled (true), EmoteWheelKey ("B"), EmoteWheelRadius (0.336 x screen height).
-- Diagnostics: EmoteWheelVersion, player EmoteWheelOpen, script EmoteWheelPlays, EmoteWheelPick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
local function default(name, v) if script:GetAttribute(name) == nil then script:SetAttribute(name, v) end end
script:SetAttribute("EmoteWheelVersion", VERSION)
default("EmoteWheelEnabled", true)
default("EmoteWheelKey", "B")
default("EmoteWheelRadius", 0.336)
script:SetAttribute("EmoteWheelPlays", 0)
if script:GetAttribute("EmoteWheelEnabled") == false then return end

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local YELLOW = Color3.fromRGB(255, 200, 50)
local PANEL = Color3.fromRGB(13, 18, 24)
local INK = Color3.fromRGB(27, 20, 5)
local MUTED = Color3.fromRGB(143, 162, 184)

local function EC()
	local s = ReplicatedStorage:FindFirstChild("EmoteShared")
	local m = s and s:FindFirstChild("EmoteCatalog")
	if not m then return nil end
	local ok, r = pcall(require, m)
	return ok and r or nil
end
local function remote() return ReplicatedStorage:FindFirstChild("DinoEmoteRequest") end
local function touchDevice()
	local c = player.Character
	return UserInputService.TouchEnabled or (c ~= nil and c:GetAttribute("ArenaTouchState") == "on")
end
local function csv(s)
	local out = {}
	if type(s) ~= "string" then return out end
	for v in (s .. ","):gmatch("([^,]*),") do table.insert(out, v) end
	return out
end

local old = pg:FindFirstChild("EmoteWheel")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "EmoteWheel"
gui.DisplayOrder = 8
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Parent = pg
local over = Instance.new("ScreenGui") -- the wheel itself, full screen
over.Name = "EmoteWheelOpen"
over.DisplayOrder = 30
over.ResetOnSpawn = false
over.IgnoreGuiInset = true
over.Enabled = false
over.Parent = pg

local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = r c.Parent = o return c end
local function stroke(o, col, th) local s = Instance.new("UIStroke") s.Color = col s.Thickness = th s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = o return s end

local pill = Instance.new("TextButton")
pill.Name = "Pill"
pill.AnchorPoint = Vector2.new(1, 0)
pill.Position = UDim2.new(1, -68, 0, 8)
pill.Size = UDim2.fromOffset(44, 36)
pill.BackgroundColor3 = PANEL
pill.BackgroundTransparency = 0.18
pill.AutoButtonColor = false
pill.Font = Enum.Font.FredokaOne
pill.TextSize = 22
pill.TextColor3 = YELLOW
pill.Text = "☻"
pill.Visible = false
pill.Parent = gui
corner(pill, UDim.new(0, 10))
stroke(pill, YELLOW, 1.5)

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(5, 8, 12)
dim.BackgroundTransparency = 0.55
dim.Text = ""
dim.AutoButtonColor = false
dim.Parent = over
local hub = Instance.new("TextLabel")
hub.Name = "Hub"
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, 0.515)
hub.BackgroundColor3 = Color3.fromRGB(7, 9, 14)
hub.BackgroundTransparency = 0.05
hub.Font = Enum.Font.FredokaOne
hub.TextColor3 = YELLOW
hub.TextWrapped = true
hub.Text = "PICK AN\nEMOTE"
hub.Parent = over
corner(hub, UDim.new(1, 0))
local hubStroke = stroke(hub, YELLOW, 2)
hubStroke.Transparency = 0.4
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 60)
toast.AutomaticSize = Enum.AutomaticSize.X
toast.Size = UDim2.fromOffset(0, 30)
toast.BackgroundColor3 = PANEL
toast.Font = Enum.Font.FredokaOne
toast.TextSize = 16
toast.TextColor3 = YELLOW
toast.Visible = false
toast.Parent = gui
corner(toast, UDim.new(0, 10))
stroke(toast, YELLOW, 1.5)
do local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 12) p.PaddingRight = UDim.new(0, 12) p.Parent = toast end
local toastAt = 0
local function say(t) toast.Text = t toast.Visible = true toastAt = os.clock() end

local slots = {}
for i = 1, 8 do
	local b = Instance.new("TextButton")
	b.Name = "Slot" .. i
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = 0.08
	b.AutoButtonColor = false
	b.Text = ""
	b.Parent = over
	corner(b, UDim.new(0.25, 0))
	local s = stroke(b, Color3.fromRGB(232, 238, 246), 2)
	s.Transparency = 0.6
	local t = Instance.new("TextLabel")
	t.Name = "T"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.92, 0.55)
	t.Position = UDim2.fromScale(0.04, 0.08)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = b
	local n = Instance.new("TextLabel")
	n.Name = "N"
	n.BackgroundTransparency = 1
	n.Size = UDim2.fromScale(0.92, 0.3)
	n.Position = UDim2.fromScale(0.04, 0.64)
	n.Font = Enum.Font.GothamBold
	n.TextScaled = true
	n.TextColor3 = MUTED
	n.Parent = b
	slots[i] = {b = b, s = s, t = t, n = n, id = nil, buy = nil}
end

local openState, hot, holdInput = false, nil, nil
local function setHot(i)
	hot = i
	for j, sl in ipairs(slots) do
		local on = j == i and sl.id ~= nil
		sl.s.Color = on and YELLOW or Color3.fromRGB(232, 238, 246)
		sl.s.Transparency = on and 0 or 0.6
		sl.t.TextColor3 = (sl.id and (on and YELLOW or Color3.new(1, 1, 1))) or Color3.fromRGB(120, 130, 145)
		sl.b.BackgroundColor3 = on and Color3.fromRGB(36, 29, 8) or PANEL
	end
	script:SetAttribute("EmoteWheelPick", i and slots[i].id or "")
end
local function fill()
	local ec = EC()
	if not ec then return end
	local wheel = csv(player:GetAttribute("EmoteWheel"))
	local owned = {}
	for _, id in ipairs(csv(player:GetAttribute("EmoteOwned"))) do owned[id] = true end
	local shown = {}
	for i = 1, 8 do if ec.get(wheel[i]) then shown[wheel[i]] = true end end
	for i, sl in ipairs(slots) do
		local id = wheel[i]
		local e = ec.get(id)
		sl.id, sl.buy = nil, nil
		if e then
			sl.id = id
			sl.t.Text, sl.n.Text = e.tag, e.name
			sl.b.BackgroundTransparency = 0.08
		else
			local pick
			for _, cid in ipairs(ec.ORDER) do
				local ce = ec.get(cid)
				if not owned[cid] and not shown[cid] and ce.unlock.kind == "robux" then pick = cid break end
			end
			if pick then
				shown[pick] = true
				sl.buy = pick
				sl.t.Text, sl.n.Text = ec.get(pick).tag, ec.get(pick).unlock.price .. " R$"
			else
				sl.t.Text, sl.n.Text = "EMPTY", ""
			end
			sl.b.BackgroundTransparency = 0.35
		end
	end
end
local function layout()
	local vs = over.AbsoluteSize
	local H = vs.Y
	local r = (tonumber(script:GetAttribute("EmoteWheelRadius")) or 0.336) * H
	local cx, cy = vs.X / 2, vs.Y * 0.515
	hub.Size = UDim2.fromOffset(0.245 * H, 0.245 * H)
	hub.TextSize = math.max(12, 0.034 * H)
	for i, sl in ipairs(slots) do
		local a = math.rad((i - 1) * 45 - 90)
		sl.b.Position = UDim2.fromOffset(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.82)
		sl.b.Size = UDim2.fromOffset(0.275 * H, 0.105 * H)
	end
end
local function setOpen(v)
	openState = v
	over.Enabled = v
	player:SetAttribute("EmoteWheelOpen", v)
	if v then fill() layout() setHot(nil) end
end
local function slotAt(pos)
	for i, sl in ipairs(slots) do
		local p, s = sl.b.AbsolutePosition, sl.b.AbsoluteSize
		if pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y then return i end
	end
	return nil
end
local function pick(i)
	local sl = i and slots[i]
	if not sl then return end
	if sl.id then
		local r = remote()
		if r then r:FireServer("play", sl.id) end
		script:SetAttribute("EmoteWheelPlays", (script:GetAttribute("EmoteWheelPlays") or 0) + 1)
		setOpen(false)
	elseif sl.buy then
		say("GET IT IN THE SHOP · MAIN MENU")
	end
end
for i, sl in ipairs(slots) do
	sl.b.Activated:Connect(function() pick(i) end)
	sl.b.MouseEnter:Connect(function() if openState then setHot(i) end end)
end
dim.Activated:Connect(function() setOpen(false) end)

-- phone: tap = open; hold + slide + release on a slot = play
pill.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if (tonumber(player:GetAttribute("EmoteCooldownUntil")) or 0) > workspace:GetServerTimeNow() then say("WAIT") return end
	setOpen(true)
	holdInput = input
end)
UserInputService.InputChanged:Connect(function(input)
	if holdInput and input == holdInput and openState then
		-- the wheel gui ignores the top inset; touch positions do not, so add it back
		local inset = game:GetService("GuiService"):GetGuiInset()
		setHot(slotAt(Vector2.new(input.Position.X, input.Position.Y) + inset))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if holdInput and input == holdInput then
		holdInput = nil
		if openState and hot then pick(hot) end
	end
end)

-- PC: hold the key
local keyDown = false
local function keyCode()
	local k = script:GetAttribute("EmoteWheelKey")
	local ok, v = pcall(function() return Enum.KeyCode[k] end)
	return ok and v or Enum.KeyCode.B
end
local function respawnWindow()
	return player:GetAttribute("RespawnHold") == true or (tonumber(player:GetAttribute("RespawnGraceUntil")) or 0) > workspace:GetServerTimeNow()
		or player:GetAttribute("RespawnPickOpen") == true
end
local function canEmote()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	return EC() ~= nil and player:GetAttribute("InMenu") ~= true and hum ~= nil and hum.Health > 0
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == keyCode() and canEmote() and not respawnWindow() then
		if (tonumber(player:GetAttribute("EmoteCooldownUntil")) or 0) > workspace:GetServerTimeNow() then say("WAIT") return end
		keyDown = true
		setOpen(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if keyDown and input.KeyCode == keyCode() then
		keyDown = false
		if openState then
			if hot then pick(hot) else setOpen(false) end
		end
	end
end)

local lastStop = 0
RunService.RenderStepped:Connect(function()
	local able = canEmote()
	pill.Visible = able and touchDevice() and player:GetAttribute("PhoneHudV2") == true
	if openState and not able then setOpen(false) end
	-- PC: pick by mouse direction while the key is held
	if keyDown and openState then
		local m = UserInputService:GetMouseLocation()
		local vs = over.AbsoluteSize
		local d = Vector2.new(m.X - vs.X / 2, m.Y - vs.Y * 0.515)
		if d.Magnitude > 0.12 * vs.Y then
			local a = math.deg(math.atan2(d.Y, d.X)) + 90
			setHot(math.floor(((a % 360) + 22.5) / 45) % 8 + 1)
		end
	end
	-- cooldown on the pill
	local left = (tonumber(player:GetAttribute("EmoteCooldownUntil")) or 0) - workspace:GetServerTimeNow()
	pill.Text = left > 0 and tostring(math.ceil(left)) or "☻"
	pill.TextTransparency = left > 0 and 0.3 or 0
	if toast.Visible and os.clock() - toastAt > 1.4 then toast.Visible = false end
	-- owner cancel: moving or jumping ends the emote at once
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum and c:GetAttribute("EmoteId") ~= nil and os.clock() - lastStop > 0.3 then
		if hum.MoveDirection.Magnitude > 0.1 or hum.Jump then
			lastStop = os.clock()
			local r = remote()
			if r then r:FireServer("stop") end
		end
	end
end)
player:GetAttributeChangedSignal("EmoteResult"):Connect(function()
	local r = player:GetAttribute("EmoteResult")
	if r == "moving" then say("STAND STILL TO EMOTE") elseif r == "cooldown" then say("WAIT") end
end)
player:GetAttributeChangedSignal("EmoteWheel"):Connect(function() if openState then fill() end end)
over:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if openState then layout() end end)
setOpen(false)
