-- HerreraMissileCam v1.1 (Mecha Dino Arena) — flying the Herrera's Cruise Missile on the owner's client: the CoD-style thermal
-- missile view, steering, the boost and the impact (LocalScript, StarterCharacterScripts). MDA-522, plan
-- docs/plans/HERRERA_CRUISE_MISSILE_v1.0.md Task 4, mockup docs/mockups/herrera_cruise_missile_v0.1.html section 2; Kepu 2026-11-13
-- 17:23 "it will go into the same animation basically that the call of duty one goes into where you're directing the missile as it's
-- flying down on the map", pick "A · Thermal (CoD)".
-- When the character's CruiseFlying turns true (HerreraMissileServer 1.0) this client flies the missile from CruiseStart:
--   * flight: falls CruiseFall (30) studs/s; steering up to CruiseSteer (30) studs/s flat, in the camera's frame (screen up =
--     the Herrera's facing at the launch); BOOST once: fall x CruiseBoostMul (3), steering x 0.5 (server "boost"). The move is
--     raycast each frame (own character and FX folders left out; the world and other dinos stop it) -> "impact" at the hit point;
--     every CruiseSendGap (0.1) s a "steer" with the position (DinoCruiseMissileRequest). These numbers mirror the server's.
--   * input: PC mouse (cursor locked; CruiseMouseSens 0.12 studs a pixel) and WASD / arrows; gamepad left stick; touch: any finger
--     (the move stick too) works as a joystick: its offset from where it touched down (full speed at CruiseTouchFull 70 px).
--     BOOST: Space, a mouse click, gamepad R2 / A, or the BOOST button.
--   * view: the camera at the missile looking down (CruisePitch -72°) toward the facing, FOV CruiseFov (70); the camera is taken
--     the Dilo scope way (character ShoulderCamExternal = true, Scriptable; all put back after). Thermal (CruiseThermalEnabled):
--     a ColorCorrectionEffect on the camera (grey: Saturation -1, Contrast 0.45, Brightness 0.03), every dino lit white-hot
--     (Highlight, white fill), red boxes on enemies and blue diamonds on teammates (BillboardGuis, always on top; SquadShared
--     SquadRules.sameChar), a red blast ring (a GUI ring sized to CruiseRadius on the ground where the view's centre meets it;
--     a GUI so the grey look doesn't wash it out), HUD (ScreenGui "CruiseHUD", DisplayOrder 9): "CRUISE MISSILE" and the height
--     above the ground at the top centre, an altitude bar, a crosshair box, faint scan lines, the BOOST button (USED after).
--   * launch moment: for CruiseLaunchView (0.6) s after CruiseFlying the camera stays as it is (you see the missile pop out of the
--     silo, HerreraMissileFX), then it jumps into the missile (the missile waits at CruiseStart meanwhile).
--   * end: at the impact (or the server's drop / blast) the grey look, markers, ring and HUD go off at once (the blast is seen in
--     full colour), a white flash (0.15 s) and a shake (CruiseShake 1.5 studs, easing out) play, and the view stays CruiseAfter
--     (1.6) s on the blast from CruiseAfterUp (70) studs up and CruiseAfterBack (70) back (the whole blast in view), then the camera and everything else go back as before. Death / the character leaving
--     = put back at once.
-- Switch: script attribute HerreraMissileCamEnabled (default true, read at each launch; false = no view, the server's drop flies
--   it). Diagnostics (character): CruiseCamState ("off" / "launch" / "fly" / "after"), CruiseLocalImpact ("world" / "dino" / "ground").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 phone 8-way pad, the rest of the screen hidden, 3x steering, keys only on PC
-- v1.1 (MDA-525; Kepu 2026-11-13 17:59 "When the cruise missile screen comes on hide the other buttons. Also give it a direction pad
--   to the left and make the rocket more maneuverable like on Cod ... This is for mobile only with the direction pad, it'll just be
--   your keys on mnk", mockup docs/mockups/herrera_cruise_dpad_v0.1.html, picks "B · Round 8-way pad", "3x: 90 studs/s", "Hide it
--   too" (the health bar)). While script attribute CruiseV11Enabled ~= false (default true, read at each launch / frame):
--   * every other ScreenGui in PlayerGui that is on (mecha slots, ATTACK / JUMP, the touch move stick, SKILLS / MENU / SQUAD, the
--     compass, the health bar, ...) is turned off when the view jumps into the missile and turned back on at the end (only the ones
--     this script turned off); left on screen: the missile HUD, the pad, BOOST; screens that turn themselves back on every frame
--     (AbilityBar, HardpointHUD, KillFeed, ...) or come on mid-flight are held off until the end (CruiseHideHoldEnabled, default
--     true; a render step after every other one + an Enabled watch);
--   * phone (TouchEnabled): a round 8-way pad on the left (CruisePadRadius 80 px; 8 arrows, the one you steer toward lights
--     yellow): a finger that touches down on it steers toward where it is from the pad's centre, full speed from 60% of the radius
--     out (further out = faster); other touches don't steer;
--   * PC: WASD / arrows steer; the mouse no longer steers (the cursor stays free; a click is still BOOST);
--   * steering CruiseSteerV2 (90) studs/s (x 0.5 after the boost), matching HerreraMissileServer 1.1.
local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
local player = Players.LocalPlayer
if not (hum and hrp) then return end
char:SetAttribute("HerreraMissileCamVersion", VERSION)
for k, v in pairs({CruiseV11Enabled = true, CruiseSteerV2 = 90, CruisePadRadius = 80, CruiseHideHoldEnabled = true}) do -- v1.1
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function v11() return script:GetAttribute("CruiseV11Enabled") ~= false end
local GuiService = game:GetService("GuiService")
local CFG = {HerreraMissileCamEnabled = true, CruiseFall = 30, CruiseSteer = 30, CruiseBoostMul = 3, CruiseSendGap = 0.1,
	CruiseMouseSens = 0.12, CruiseTouchFull = 70, CruisePitch = -72, CruiseFov = 70, CruiseAfter = 1.6, CruiseThermalEnabled = true,
	CruiseMaxFlight = 10, CruiseLaunchView = 0.6, CruiseShake = 1.5, CruiseAfterUp = 70, CruiseAfterBack = 70}
for k, v in pairs(CFG) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function cfg(k) local v = script:GetAttribute(k) if v == nil then v = CFG[k] end return v end
local function show(k, v) if char:GetAttribute(k) ~= v then char:SetAttribute(k, v) end end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local RED, BLUE = Color3.fromRGB(255, 59, 48), Color3.fromRGB(79, 182, 255)

-- HUD ----------------------------------------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CruiseHUD"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9
gui.ResetOnSpawn = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local function label(text, pos, anchor, size)
	local l = Instance.new("TextLabel")
	l:SetAttribute("FontSwap", "keep")
	l.BackgroundTransparency = 1
	l.FontFace = SILK
	l.TextSize = size or 18
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.AnchorPoint = anchor
	l.Position = pos
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Text = text
	l.Parent = gui
	return l
end
label("CRUISE MISSILE", UDim2.new(0.5, 0, 0, 104), Vector2.new(0.5, 0), 20)
local altText = label("250 STUDS", UDim2.new(0.5, 0, 0, 132), Vector2.new(0.5, 0), 18)
local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(1, 0.5)
barBack.Position = UDim2.new(1, -40, 0.5, 0)
barBack.Size = UDim2.new(0, 14, 0.55, 0)
barBack.BackgroundColor3 = Color3.new(0, 0, 0)
barBack.BackgroundTransparency = 0.5
barBack.BorderSizePixel = 0
barBack.Parent = gui
local barMark = Instance.new("Frame")
barMark.AnchorPoint = Vector2.new(0.5, 0.5)
barMark.Size = UDim2.new(1, 6, 0, 4)
barMark.BackgroundColor3 = Color3.new(1, 1, 1)
barMark.BorderSizePixel = 0
barMark.Parent = barBack
local box = Instance.new("Frame")
box.AnchorPoint = Vector2.new(0.5, 0.5)
box.Position = UDim2.fromScale(0.5, 0.5)
box.Size = UDim2.fromOffset(80, 80)
box.BackgroundTransparency = 1
box.Parent = gui
do
	local st = Instance.new("UIStroke")
	st.Color, st.Thickness = Color3.new(1, 1, 1), 2
	st.Parent = box
	for _, t in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(0.5, t[1] * 58, 0.5, t[2] * 58)
		f.Size = t[1] ~= 0 and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 24)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Parent = box
	end
end
for i = 0, 59 do -- faint scan lines
	local f = Instance.new("Frame")
	f.Position = UDim2.fromScale(0, i / 60)
	f.Size = UDim2.new(1, 0, 0, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.94
	f.BorderSizePixel = 0
	f.ZIndex = 0
	f.Parent = gui
end
local ring = Instance.new("Frame") -- the blast ring on the ground
ring.Name = "BlastRing"
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.BackgroundColor3 = RED
ring.BackgroundTransparency = 0.88
ring.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = ring
	local st = Instance.new("UIStroke")
	st.Color, st.Thickness, st.Transparency = RED, 3, 0.1
	st.Parent = ring
end
local flashGui = Instance.new("ScreenGui") -- the impact flash (shown while the HUD is off)
flashGui.Name = "CruiseFlash"
flashGui.IgnoreGuiInset = true
flashGui.DisplayOrder = 9
flashGui.ResetOnSpawn = true
flashGui.Parent = player:WaitForChild("PlayerGui")
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BorderSizePixel = 0
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.Parent = flashGui
local boostBtn = Instance.new("TextButton")
boostBtn:SetAttribute("FontSwap", "keep")
boostBtn.AnchorPoint = Vector2.new(1, 1)
boostBtn.Position = UDim2.new(1, -28, 1, -40)
boostBtn.Size = UDim2.fromOffset(104, 104)
boostBtn.BackgroundColor3 = Color3.fromRGB(13, 18, 24)
boostBtn.BackgroundTransparency = 0.2
boostBtn.FontFace = SILK
boostBtn.TextSize = 18
boostBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
boostBtn.Text = "BOOST"
boostBtn.AutoButtonColor = false
boostBtn.ZIndex = 5
boostBtn.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = boostBtn
	local st = Instance.new("UIStroke")
	st.Name = "Ring"
	st.Color, st.Thickness = Color3.fromRGB(255, 200, 50), 3
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = boostBtn
end

-- v1.1: the round 8-way pad (phone)
local PAD_R = tonumber(script:GetAttribute("CruisePadRadius")) or 80
local pad = Instance.new("Frame")
pad.Name = "CruisePad"
pad.AnchorPoint = Vector2.new(0.5, 0.5)
pad.Position = UDim2.new(0, 40 + PAD_R, 1, -40 - PAD_R)
pad.Size = UDim2.fromOffset(PAD_R * 2, PAD_R * 2)
pad.BackgroundColor3 = Color3.fromRGB(13, 18, 24)
pad.BackgroundTransparency = 0.3
pad.Visible = false
pad.ZIndex = 5
pad.Parent = gui
local padArrows = {}
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = pad
	local st = Instance.new("UIStroke")
	st.Color, st.Thickness, st.Transparency = Color3.fromRGB(232, 238, 246), 2, 0.6
	st.Parent = pad
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(30, 30)
	dot.BackgroundColor3 = Color3.fromRGB(232, 238, 246)
	dot.BackgroundTransparency = 0.75
	dot.ZIndex = 6
	dot.Parent = pad
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 -- 0 = up, clockwise
		local l = Instance.new("TextLabel")
		l:SetAttribute("FontSwap", "keep")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new(0.5, math.sin(a) * PAD_R * 0.72, 0.5, -math.cos(a) * PAD_R * 0.72)
		l.Size = UDim2.fromOffset(26, 26)
		l.BackgroundTransparency = 1
		l.Text = "▲"
		l.TextSize = 22
		l.Font = Enum.Font.GothamBlack
		l.TextColor3 = Color3.fromRGB(232, 238, 246)
		l.Rotation = math.deg(a)
		l.ZIndex = 6
		l.Parent = pad
		padArrows[i + 1] = {label = l, dir = Vector2.new(math.sin(a), -math.cos(a))}
	end
end
local padTouches = {} -- [InputObject] = true while a finger that started on the pad is down
pad.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then padTouches[input] = true end
end)
UserInputService.TouchEnded:Connect(function(t) padTouches[t] = nil end)
local function padVector() -- the pad's steer (screen x right, y down), 0..1 long
	local inset = GuiService:GetGuiInset()
	local centre = pad.AbsolutePosition + pad.AbsoluteSize / 2 - inset
	local v = Vector2.zero
	for t in pairs(padTouches) do
		local off = Vector2.new(t.Position.X, t.Position.Y) - centre
		if off.Magnitude > 8 then
			v = off.Unit * math.clamp(off.Magnitude / (PAD_R * 0.6), 0, 1)
		end
	end
	for _, a in ipairs(padArrows) do
		local lit = v.Magnitude > 0.05 and a.dir:Dot(v.Unit) > 0.92
		a.label.TextColor3 = lit and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(232, 238, 246)
	end
	return v
end
-- v1.1: the rest of the screen off while flying
local hidden = {}
-- v1.1: some screens turn themselves back on every frame (AbilityBar, HardpointHUD, KillFeed, ...): hold them off while hidden
local holding, holdConns = false, {}
local function holdOff(g)
	if not g:IsA("ScreenGui") or g == gui or g.Name == "CruiseFlash" then return end
	if g.Enabled then g.Enabled = false end
	if holdConns[g] then return end
	holdConns[g] = g:GetPropertyChangedSignal("Enabled"):Connect(function()
		if holding and g.Enabled then g.Enabled = false end
	end)
end
local function hideOthers()
	if not v11() then return end
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui and g.Name ~= "CruiseFlash" and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	holding = script:GetAttribute("CruiseHideHoldEnabled") ~= false
	if holding then for _, g in ipairs(player.PlayerGui:GetChildren()) do holdOff(g) end end
end
local function showOthers()
	holding = false
	for _, c in pairs(holdConns) do c:Disconnect() end
	table.clear(holdConns)
	for _, g in ipairs(hidden) do if g.Parent then g.Enabled = true end end
	table.clear(hidden)
end
local HOLD_BIND = "DinoCruiseMissileHold" -- v1.1: runs after every other render step, catches screens shown mid-flight
pcall(function() RunService:UnbindFromRenderStep(HOLD_BIND) end)
RunService:BindToRenderStep(HOLD_BIND, Enum.RenderPriority.Last.Value + 50, function()
	if not holding then return end
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled then holdOff(g) end
	end
end)

-- state ----------------------------------------------------------------------------------------------------------------------
local fx = {} -- instances made for the flight
local saved, flying, after = nil, false, nil
local takeAt, afterStart = nil, 0 -- the launch moment ends at takeAt; the blast view started at afterStart
local pos, heading, boosted, lastSend, startClock, impactSent = nil, nil, false, 0, 0, false
local mouseMoved = false
local touches = {} -- [InputObject] = start position
local boostTouch = nil
local remote = ReplicatedStorage:WaitForChild("DinoCruiseMissileRequest", 10)
local function send(action, p)
	if remote then remote:FireServer(workspace:GetServerTimeNow(), action, p) end
end
local function doBoost()
	if not flying or boosted then return end
	boosted = true
	send("boost")
	boostBtn.Text = "USED"
	boostBtn.TextColor3 = Color3.fromRGB(143, 162, 184)
	boostBtn.Ring.Color = Color3.fromRGB(143, 162, 184)
end
boostBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then boostTouch = input end
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then doBoost() end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not flying then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonA
		or (input.UserInputType == Enum.UserInputType.MouseButton1 and not processed) then
		doBoost()
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then mouseMoved = true end
end)
UserInputService.TouchStarted:Connect(function(t) touches[t] = t.Position end)
UserInputService.TouchEnded:Connect(function(t) touches[t] = nil if t == boostTouch then boostTouch = nil end end)

local function squadMod()
	local sh = ReplicatedStorage:FindFirstChild("SquadShared")
	local m = sh and sh:FindFirstChild("SquadRules")
	if not m then return nil end
	local ok, mod = pcall(require, m)
	return ok and mod or nil
end
local function dinos()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and c ~= char and c:FindFirstChild("HumanoidRootPart") then table.insert(list, c) end
	end
	local isl = workspace:FindFirstChild("DinoIsland")
	local b = isl and isl:FindFirstChild("Bots")
	for _, m in ipairs(b and b:GetChildren() or {}) do
		if m:FindFirstChild("HumanoidRootPart") then table.insert(list, m) end
	end
	return list
end
local function marker(m, mate)
	local g = Instance.new("BillboardGui")
	g.Name = "CruiseMarker"
	g.AlwaysOnTop = true
	g.Size = UDim2.fromOffset(34, 34)
	g.Adornee = m.HumanoidRootPart
	g.LightInfluence = 0
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundTransparency = 1
	f.Parent = g
	if mate then
		f.Size = UDim2.fromOffset(14, 14)
		f.Rotation = 45
		f.BackgroundTransparency = 0
		f.BackgroundColor3 = BLUE
		f.BorderSizePixel = 0
	else
		f.Size = UDim2.fromOffset(28, 28)
		local st = Instance.new("UIStroke")
		st.Color, st.Thickness = RED, 2.5
		st.Parent = f
	end
	g.Parent = gui
	return g
end
local function exclude()
	local ex = {char}
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "HerreraPartsFX", "HerreraMovesFX", "HerreraMissileFX", "CruiseLocal"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = ex
	return p
end
local function groundExclude()
	local ex = {}
	for _, d in ipairs(dinos()) do table.insert(ex, d) end
	table.insert(ex, char)
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "HerreraMissileFX", "CruiseLocal"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = ex
	return p
end

local function cleanupFx()
	for _, i in ipairs(fx) do if i and i.Parent then i:Destroy() end end
	table.clear(fx)
	gui.Enabled = false
end
local function release()
	flying, after, takeAt = false, nil, nil
	flash.BackgroundTransparency = 1
	cleanupFx()
	showOthers() -- v1.1
	if saved then
		local cam = workspace.CurrentCamera
		if saved.cf then cam.CFrame = saved.cf end
		cam.CameraType = saved.type
		cam.FieldOfView = saved.fov
		UserInputService.MouseBehavior = saved.mouse
		UserInputService.MouseIconEnabled = saved.icon
		saved = nil
	end
	char:SetAttribute("ShoulderCamExternal", false)
	show("CruiseCamState", "off")
end
local function begin()
	if script:GetAttribute("HerreraMissileCamEnabled") == false then return end
	local start = char:GetAttribute("CruiseStart")
	if typeof(start) ~= "Vector3" then return end
	if flying or after then release() end
	pos = start
	heading = flat(hrp.CFrame.LookVector)
	heading = heading.Magnitude > 1e-3 and heading.Unit or -Vector3.zAxis
	boosted, impactSent, lastSend, startClock = false, false, 0, os.clock()
	boostBtn.Text = "BOOST"
	boostBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
	boostBtn.Ring.Color = Color3.fromRGB(255, 200, 50)
	flying, after = true, nil
	takeAt = os.clock() + (tonumber(cfg("CruiseLaunchView")) or 0.6) -- the launch moment first
	show("CruiseCamState", "launch")
end
local function take() -- the view jumps into the missile
	takeAt = nil
	local cam = workspace.CurrentCamera
	saved = {type = cam.CameraType, fov = cam.FieldOfView, cf = cam.CFrame, mouse = UserInputService.MouseBehavior,
		icon = UserInputService.MouseIconEnabled}
	char:SetAttribute("ShoulderCamExternal", true)
	cam.CameraType = Enum.CameraType.Scriptable
	gui.Enabled = true
	hideOthers() -- v1.1
	pad.Visible = v11() and UserInputService.TouchEnabled -- v1.1
	table.clear(padTouches)
	-- thermal look
	if cfg("CruiseThermalEnabled") ~= false then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CruiseThermal"
		cc.Saturation, cc.Contrast, cc.Brightness = -1, 0.45, 0.03
		cc.Parent = cam
		table.insert(fx, cc)
	end
	local folder = Instance.new("Folder")
	folder.Name = "CruiseLocal"
	folder.Parent = workspace
	table.insert(fx, folder)
	local sm = squadMod()
	for _, m in ipairs(dinos()) do
		local mate = sm ~= nil and sm.sameChar(char, m) == true
		if cfg("CruiseThermalEnabled") ~= false then
			local h = Instance.new("Highlight")
			h.Name = "CruiseHot"
			h.FillColor, h.FillTransparency = Color3.new(1, 1, 1), 0.05
			h.OutlineColor, h.OutlineTransparency = Color3.new(1, 1, 1), 0.3
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Adornee = m
			h.Parent = folder
			table.insert(fx, h)
		end
		table.insert(fx, marker(m, mate))
	end
	show("CruiseCamState", "fly")
end

local function toBlast() -- the impact / the server's end: colour back, flash, shake, watch the blast
	flying = false
	cleanupFx()
	after = os.clock() + (tonumber(cfg("CruiseAfter")) or 1.6)
	afterStart = os.clock()
	show("CruiseCamState", "after")
end
local BIND = "DinoCruiseMissileCam"
pcall(function() RunService:UnbindFromRenderStep(BIND) end)
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 6, function(dt)
	if not (flying or after) then return end
	if takeAt then
		if os.clock() < takeAt then return end
		take()
	end
	if not saved then return end
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
	if after then -- watching the blast
		if os.clock() >= after then release() return end
		local cp = char:GetAttribute("CruisePos") -- the server's missile (its last point = the blast)
		local at = typeof(cp) == "Vector3" and cp or pos
		local u = os.clock() - afterStart
		flash.BackgroundTransparency = math.clamp(u / 0.15, 0, 1)
		local sh = (tonumber(cfg("CruiseShake")) or 1.5) * math.max(0, 1 - u / 0.8)
		local jig = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * sh
		local up, back = tonumber(cfg("CruiseAfterUp")) or 70, tonumber(cfg("CruiseAfterBack")) or 70
		cam.CFrame = CFrame.lookAt(at + Vector3.new(0, up, 0) - heading * back + jig, at)
		cam.FieldOfView = 70
		return
	end
	-- steering
	local right = Vector3.new(-heading.Z, 0, heading.X)
	local steer = (tonumber(cfg(v11() and "CruiseSteerV2" or "CruiseSteer")) or 30) * (boosted and 0.5 or 1) -- v1.1: V2 90
	local fall = (tonumber(cfg("CruiseFall")) or 30) * (boosted and (tonumber(cfg("CruiseBoostMul")) or 3) or 1)
	local disp = Vector3.zero
	if v11() then -- v1.1: the pad only (phone)
		local pv = padVector()
		disp += (right * pv.X - heading * pv.Y) * steer * dt
	end
	for t, st in pairs(touches) do
		if t ~= boostTouch and not v11() then
			local off = Vector2.new(t.Position.X, t.Position.Y) - Vector2.new(st.X, st.Y)
			if off.Magnitude > 6 then
				local k = math.clamp(off.Magnitude / (tonumber(cfg("CruiseTouchFull")) or 70), 0, 1)
				local d = off.Unit
				disp += (right * d.X - heading * d.Y) * steer * dt * k
			end
		end
	end
	if UserInputService.MouseEnabled and next(touches) == nil and not v11() then -- v1.1: keys only on PC
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		local md = UserInputService:GetMouseDelta()
		if mouseMoved then
			local s = tonumber(cfg("CruiseMouseSens")) or 0.12
			disp += (right * md.X - heading * md.Y) * s
		end
	end
	mouseMoved = false
	local kx, ky = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then ky += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then ky -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then kx += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then kx -= 1 end
	for _, st in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		if st.KeyCode == Enum.KeyCode.Thumbstick1 and st.Position.Magnitude > 0.15 then kx += st.Position.X ky += st.Position.Y end
	end
	if kx ~= 0 or ky ~= 0 then
		local v = Vector2.new(kx, ky)
		if v.Magnitude > 1 then v = v.Unit end
		disp += (right * v.X + heading * v.Y) * steer * dt
	end
	local maxStep = steer * dt
	if disp.Magnitude > maxStep then disp = disp.Unit * maxStep end
	local nextPos = pos + disp - Vector3.new(0, fall * dt, 0)
	local hit = workspace:Raycast(pos, nextPos - pos, exclude())
	local g = workspace:Raycast(nextPos + Vector3.new(0, 1, 0), Vector3.new(0, -2000, 0), groundExclude())
	local groundYv = g and g.Position.Y or (nextPos.Y - 200)
	if hit then
		pos = hit.Position
		local m = hit.Instance and hit.Instance:FindFirstAncestorOfClass("Model")
		show("CruiseLocalImpact", (m and m:FindFirstChild("HumanoidRootPart")) and "dino" or "world")
	elseif nextPos.Y <= groundYv then
		pos = Vector3.new(nextPos.X, groundYv, nextPos.Z)
		show("CruiseLocalImpact", "ground")
		hit = true
	else
		pos = nextPos
	end
	if hit and not impactSent then
		impactSent = true
		send("impact", pos)
		toBlast()
		return
	end
	if os.clock() - lastSend >= (tonumber(cfg("CruiseSendGap")) or 0.1) then
		lastSend = os.clock()
		send("steer", pos)
	end
	-- the view
	local pitch = math.rad(tonumber(cfg("CruisePitch")) or -72)
	local look = (heading * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)).Unit
	cam.CFrame = CFrame.lookAt(pos, pos + look)
	cam.FieldOfView = tonumber(cfg("CruiseFov")) or 70
	-- the blast ring where the view's centre meets the ground (screen ellipse of the CruiseRadius circle)
	local gl = workspace:Raycast(pos, look * 2000, groundExclude())
	local at = gl and gl.Position or Vector3.new(pos.X, groundYv, pos.Z)
	local r = tonumber(char:GetAttribute("CruiseRadius")) or 45
	local c0, on0 = cam:WorldToViewportPoint(at)
	local cx = cam:WorldToViewportPoint(at + right * r)
	local cz = cam:WorldToViewportPoint(at + heading * r)
	ring.Visible = on0
	if on0 then
		local rx = (Vector2.new(cx.X, cx.Y) - Vector2.new(c0.X, c0.Y)).Magnitude
		local rz = (Vector2.new(cz.X, cz.Y) - Vector2.new(c0.X, c0.Y)).Magnitude
		ring.Position = UDim2.fromOffset(c0.X, c0.Y)
		ring.Size = UDim2.fromOffset(rx * 2, rz * 2)
	end
	local height = math.max(0, pos.Y - groundYv)
	altText.Text = math.floor(height + 0.5) .. " STUDS"
	barMark.Position = UDim2.fromScale(0.5, math.clamp(1 - height / 250, 0, 1))
end)

char:GetAttributeChangedSignal("CruiseFlying"):Connect(function()
	if char:GetAttribute("CruiseFlying") == true then
		begin()
	elseif flying then -- the server ended it (drop / blast) before this client hit anything
		if takeAt then release() else toBlast() end
	end
end)
char:GetAttributeChangedSignal("CruiseDropping"):Connect(function()
	if char:GetAttribute("CruiseDropping") == true and flying then -- the server took the missile (stun / timeout): watch it fall
		if takeAt then release() return end
		toBlast()
		after = os.clock() + 3
	end
end)
hum.Died:Connect(release)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then
		release()
		pcall(function() RunService:UnbindFromRenderStep(BIND) end)
		pcall(function() RunService:UnbindFromRenderStep(HOLD_BIND) end) -- v1.1
		if gui.Parent then gui:Destroy() end
		if flashGui.Parent then flashGui:Destroy() end
	end
end)
show("CruiseCamState", "off")
