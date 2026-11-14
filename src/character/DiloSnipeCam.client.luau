-- DiloSnipeCam v1.3 (Mecha Dino Arena) — the Dilo sniper spit's head camera and aim HUD, PC and phone (LocalScript,
-- StarterCharacterScripts, owner's client). MDA-511, plan docs/plans/DILO_SNIPER_SPIT_v1.0.md Task 3, mockup
-- docs/mockups/dilo_sniper_spit_v0.1.html "A · Head cam"; Kepu 2026-11-13 15:38 "it goes into fps mode where you're aiming the
-- head of the dilo manually no aim assist".
-- While the character attribute DiloSnipeAim is true (DiloAttackTest 1.5, a 1.5 s hold with a full clip):
--   * it takes the camera: character ShoulderCamExternal = true (ShoulderCam 1.10 steps aside, no Classic claim), CameraType
--     Scriptable, FieldOfView DiloSnipeFov (50); the camera sits DiloSnipeEyeUp (1.0) x k studs above the snout tip (the
--     "Head_tip" part; the dilo's Head is a Model) and DiloSnipeEyeBack (0.5) x k behind it along the aim (k = scale / 2),
--     looking along the aim (yaw from the camera at the start, pitch DiloSnipePitchStart 0; pitch DiloSnipePitchMin -40 ..
--     DiloSnipePitchMax 40), so nothing of the body blocks the view;
--   * look input: mouse (cursor locked to the centre; DiloSnipeMouseSens 0.2 degrees a pixel; only frames with a real mouse
--     move, the ShoulderCam 1.2 touch guard), touch drags that began on the right 65% of the screen (the thumb holding ATTACK
--     too; DiloSnipeTouchSens 0.25 degrees a pixel), gamepad right stick (DiloSnipePadSpeed 160 degrees a second);
--   * the body turns to the aim: TurnLimitMode "aim" + TurnLimitAimLook = the flat aim (TurnLimit 1.2);
--   * HUD (ScreenGui "DiloSnipeHUD", DisplayOrder 8): a green crosshair at the centre and "SNIPER SPIT · RELEASE TO FIRE" at
--     the top.
-- When it goes false (the shot, a cancel, death): everything is put back as it was (CameraType, FieldOfView, mouse,
--   TurnLimitMode / TurnLimitAimLook, ShoulderCamExternal) and ShoulderCamLookAt = a point along the last aim, so the usual
--   camera carries on facing where you aimed.
-- While DiloSnipeHolding is true and not yet aiming, from DiloSnipeRingAfter (0.25 s) a ring of 24 dots round the centre fills
--   over DiloSnipeHold (DiloAttackTest's script attribute, 1.5 s) (a tap shows nothing).
-- Switch: script attribute DiloSnipeCamEnabled (default true, read every frame; false = the camera is left alone, no HUD).
-- Diagnostics (character): DiloSnipeCamVersion, DiloSnipeCamState ("off" / "charge" / "aim"), DiloSnipeYaw / DiloSnipePitch.
-- v1.1 (Kepu 2026-11-13 16:10 "I don't like the cross hair ... when it shoots it changes my camera from before I shot it";
--   picks "B · Scope ring" (mockup docs/mockups/dilo_snipe_crosshair_v0.1.html), "Back to before you aimed"):
--   * crosshair (switch script attribute DiloSnipeScopeEnabled, default true, read every frame; false = 1.0's green plus): a
--     thin white ring (DiloSnipeScopeRadius 26 px, 1.5 px line), 4 short ticks just outside it, a red centre dot (4 px) and
--     dark screen edges (4 gradient bands, 0.45 at the edge);
--   * after the shot / cancel the camera goes back to the view from before the hold: the camera's CFrame saved when the aim
--     started is put back before the camera type is restored, and no ShoulderCamLookAt is set (the Shoulder / Shift framing
--     still has its own yaw / pitch from before). Switch: script attribute DiloSnipeReturnEnabled (default true, read at the
--     release; false = 1.0: turn to the last aim).
-- v1.2 (MDA-518, plan docs/plans/DILO_SNIPER_SCOPE_v1.0.md Task 6, mockup docs/mockups/dilo_sniper_scope_part_v0.1.html section 2;
--   Kepu 2026-11-13 16:19 "it'll be the classic sniper scope cross hair and animation", picks "Yes: 15 -> 40 over 1 s"): the Sniper
--   Scope view, while character DiloScopeAim is true (MechaButtons 1.47) and DiloScopeRecoilHold (0.3) s after the shot
--   (DiloScopeFiredAt): takes the camera as the snipe aim (own / release: ShoulderCamExternal, Scriptable, mouse locked, TurnLimit
--   "aim"; after: back to the view from before, as 1.1); the eye sits at the lens (the dscope muzzle on the Head root, else Head_tip +
--   DiloSnipeEyeUp) looking along the aim; look input as the snipe aim (mouse / pad x DiloScopeSensMul 0.6, finer while zoomed). Lens raise: over
--   DiloScopeRaise (0.2) s the FOV goes from the saved one to DiloScopeFov (30) and the black mask's hole grows to DiloScopeHole
--   (0.44) x the short screen side. Classic reticle (when raised): black mask outside the circle (ScreenGui "DiloScopeMask",
--   DisplayOrder -5, under the other HUDs so the buttons and stick stay on top), a dark lens ring, thick black posts from the edge to
--   45% in, thin black centre lines, 4 mil dots each way. Charge: 28 dots on a 270° arc under the centre fill over DiloPartScopeCharge
--   (1 s) from DiloScopeAimAt (white, venom green when full) and the damage it would deal now (DiloPartScopeMin -> Max) under it.
--   Banner "SNIPER SCOPE · LET GO TO FIRE". The shot: a pale flash (0.08 s) and a DiloScopeKick (4) degree recoil kick easing out
--   over the hold. A hit (DiloScopeShotAt with DiloScopeTarget set): 4 white hit-marker ticks + the damage dealt (DiloScopeDmg) at the
--   centre, fading over 0.9 s. Switch: script attribute DiloScopeViewEnabled (default true, read every frame; false = 1.1, no scope
--   view). Diagnostics (character): DiloSnipeCamState "scope", DiloScopeHoleNow (px).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 scope ring crosshair, camera back to before the aim
VERSION = "1.2" -- v1.2 Sniper Scope classic scope view (MDA-518)
VERSION = "1.3" -- v1.3 the scope stays up 0.5 s after the shot (MDA-519)
-- v1.3 (MDA-519, mockup docs/mockups/dilo_scope_shot_vfx_v0.1.html, Kepu 2026-11-13 pick "C · Bolt + beam ... scope stays up 0.5 s"):
--   after the shot the scope view holds DiloScopeShotHold (0.5) s instead of DiloScopeRecoilHold (0.3), so the bolt is seen landing
--   (DiloMovesFX 1.8). Switch: script attribute DiloScopeShotHoldEnabled (default true, read every frame; false = 1.2's 0.3 s).
if script:GetAttribute("DiloScopeShotHoldEnabled") == nil then script:SetAttribute("DiloScopeShotHoldEnabled", true) end -- v1.3
if script:GetAttribute("DiloScopeShotHold") == nil then script:SetAttribute("DiloScopeShotHold", 0.5) end -- v1.3
local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
local player = Players.LocalPlayer
if not (hum and hrp) then return end
char:SetAttribute("DiloSnipeCamVersion", VERSION)

local CFG = {DiloSnipeCamEnabled = true, DiloSnipeFov = 50, DiloSnipeEyeUp = 1.0, DiloSnipeEyeBack = 0.5, DiloSnipePitchMin = -40,
	DiloSnipePitchMax = 40, DiloSnipeMouseSens = 0.2, DiloSnipeTouchSens = 0.25, DiloSnipePadSpeed = 160, DiloSnipeRingAfter = 0.25,
	DiloSnipePitchStart = 0}
for k, v in pairs(CFG) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function cfg(k) local v = script:GetAttribute(k) if v == nil then v = CFG[k] end return v end
local function show(k, v) if char:GetAttribute(k) ~= v then char:SetAttribute(k, v) end end
local function now() return workspace:GetServerTimeNow() end
local VENOM, PALE, DARK = Color3.fromHex("9CF05A"), Color3.fromHex("D8FF8A"), Color3.fromRGB(13, 18, 24)
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)

-- HUD -------------------------------------------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DiloSnipeHUD"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 8
gui.ResetOnSpawn = true
gui.Parent = player:WaitForChild("PlayerGui")
local centre = Instance.new("Frame")
centre.AnchorPoint = Vector2.new(0.5, 0.5)
centre.Position = UDim2.fromScale(0.5, 0.5)
centre.Size = UDim2.fromOffset(80, 80)
centre.BackgroundTransparency = 1
centre.Parent = gui
local dots = {}
for i = 1, 24 do
	local a = (i - 1) / 24 * math.pi * 2 - math.pi / 2
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.new(0.5, math.cos(a) * 32, 0.5, math.sin(a) * 32)
	d.Size = UDim2.fromOffset(5, 5)
	d.BorderSizePixel = 0
	d.BackgroundColor3 = VENOM
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = d
	d.Parent = centre
	dots[i] = d
end
local cross = {}
for _, b in ipairs({{-24, 0, 14, 3}, {10, 0, 14, 3}, {0, -24, 3, 14}, {0, 10, 3, 14}, {0, 0, 4, 4}}) do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(b[1] == 0 and 0.5 or 0, b[2] == 0 and 0.5 or 0)
	f.Position = UDim2.new(0.5, b[1], 0.5, b[2])
	f.Size = UDim2.fromOffset(b[3], b[4])
	f.BorderSizePixel = 0
	f.BackgroundColor3 = VENOM
	local st = Instance.new("UIStroke")
	st.Color, st.Thickness, st.Transparency = Color3.new(0, 0, 0), 1, 0.4
	st.Parent = f
	f.Parent = centre
	table.insert(cross, f)
end
local banner = Instance.new("TextLabel")
banner:SetAttribute("FontSwap", "keep")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 64)
banner.AutomaticSize = Enum.AutomaticSize.X
banner.Size = UDim2.fromOffset(0, 30)
banner.BackgroundColor3 = DARK
banner.BackgroundTransparency = 0.25
banner.FontFace = SILK
banner.TextSize = 14
banner.TextColor3 = PALE
banner.Text = "SNIPER SPIT · RELEASE TO FIRE"
local bp = Instance.new("UIPadding")
bp.PaddingLeft, bp.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
bp.Parent = banner
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 6)
bc.Parent = banner
banner.Parent = gui
-- v1.1: the scope ring crosshair + dark edges (see the header)
if script:GetAttribute("DiloSnipeScopeEnabled") == nil then script:SetAttribute("DiloSnipeScopeEnabled", true) end
if script:GetAttribute("DiloSnipeScopeRadius") == nil then script:SetAttribute("DiloSnipeScopeRadius", 26) end
if script:GetAttribute("DiloSnipeReturnEnabled") == nil then script:SetAttribute("DiloSnipeReturnEnabled", true) end
local scope = {}
do
	local R = tonumber(script:GetAttribute("DiloSnipeScopeRadius")) or 26
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(R * 2, R * 2)
	ring.BackgroundTransparency = 1
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.Color, rs.Thickness, rs.Transparency = Color3.fromRGB(232, 245, 255), 1.5, 0.1
	rs.Parent = ring
	ring.Parent = centre
	table.insert(scope, ring)
	for _, t in ipairs({{0, -(R + 8), 1.5, 8}, {0, R + 8, 1.5, 8}, {-(R + 8), 0, 8, 1.5}, {R + 8, 0, 8, 1.5}}) do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(0.5, t[1] + (t[1] < 0 and 4 or (t[1] > 0 and -4 or 0)), 0.5, t[2] + (t[2] < 0 and 4 or (t[2] > 0 and -4 or 0)))
		f.Size = UDim2.fromOffset(t[3], t[4])
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(232, 245, 255)
		f.Parent = centre
		table.insert(scope, f)
	end
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = Color3.fromRGB(255, 90, 79)
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot
	dot.Parent = centre
	table.insert(scope, dot)
	for _, side in ipairs({{UDim2.fromScale(0, 0), UDim2.fromScale(0.22, 1), 0}, {UDim2.fromScale(0.78, 0), UDim2.fromScale(0.22, 1), 180},
		{UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.25), 90}, {UDim2.fromScale(0, 0.75), UDim2.fromScale(1, 0.25), 270}}) do
		local band = Instance.new("Frame")
		band.Position, band.Size = side[1], side[2]
		band.BorderSizePixel = 0
		band.BackgroundColor3 = Color3.new(0, 0, 0)
		band.BackgroundTransparency = 0
		local g = Instance.new("UIGradient")
		g.Rotation = side[3]
		g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
		g.Parent = band
		band.ZIndex = 0
		band.Parent = gui
		table.insert(scope, band)
	end
end
local function scopeOn() return script:GetAttribute("DiloSnipeScopeEnabled") ~= false end
local function hud(mode, u)
	for i, d in ipairs(dots) do
		d.Visible = mode == "charge"
		d.BackgroundTransparency = (mode == "charge" and (i - 1) / 24 < u) and 0 or 0.75
	end
	for _, f in ipairs(cross) do f.Visible = mode == "aim" and not scopeOn() end
	for _, f in ipairs(scope) do f.Visible = mode == "aim" and scopeOn() end -- v1.1
	banner.Visible = mode == "aim"
end
hud("off", 0)

-- look input ------------------------------------------------------------------------------------------------------------------
local yaw, pitch = 0, 0
local mouseMoved = false
local touchStart, touchLast = {}, {}
local pad = Vector2.zero
local owning = false
local saved = nil
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		mouseMoved = true
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		pad = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
UserInputService.TouchStarted:Connect(function(t)
	touchStart[t] = t.Position
	touchLast[t] = t.Position
end)
UserInputService.TouchMoved:Connect(function(t)
	local last = touchLast[t]
	touchLast[t] = t.Position
	if not owning or not last then return end
	local st = touchStart[t]
	local cam = workspace.CurrentCamera
	if not (st and cam) or st.X < cam.ViewportSize.X * 0.35 then return end -- the move stick side
	local d = t.Position - last
	local s = tonumber(cfg("DiloSnipeTouchSens")) or 0.25
	yaw -= d.X * s
	pitch -= d.Y * s
end)
UserInputService.TouchEnded:Connect(function(t)
	touchStart[t], touchLast[t] = nil, nil
end)
local function anyTouch() return next(touchStart) ~= nil end

-- own / release the camera --------------------------------------------------------------------------------------------------
local lastEye, lastLook = nil, nil
local function own()
	local cam = workspace.CurrentCamera
	saved = {type = cam.CameraType, fov = cam.FieldOfView, mouse = UserInputService.MouseBehavior,
		icon = UserInputService.MouseIconEnabled, turnMode = char:GetAttribute("TurnLimitMode"), cf = cam.CFrame} -- v1.1: + cf
	local lv = cam.CFrame.LookVector
	yaw = math.deg(math.atan2(-lv.X, -lv.Z))
	pitch = math.clamp(tonumber(cfg("DiloSnipePitchStart")) or 0, cfg("DiloSnipePitchMin"), cfg("DiloSnipePitchMax"))
	char:SetAttribute("ShoulderCamExternal", true)
	cam.CameraType = Enum.CameraType.Scriptable
	owning = true
end
local function release()
	if not owning then return end
	owning = false
	local cam = workspace.CurrentCamera
	local back = script:GetAttribute("DiloSnipeReturnEnabled") ~= false -- v1.1
	if saved then
		if back and saved.cf then cam.CFrame = saved.cf end -- v1.1: the view from before the hold
		cam.CameraType = saved.type
		cam.FieldOfView = saved.fov
		UserInputService.MouseBehavior = saved.mouse
		UserInputService.MouseIconEnabled = saved.icon
		char:SetAttribute("TurnLimitMode", saved.turnMode)
	end
	char:SetAttribute("TurnLimitAimLook", nil)
	char:SetAttribute("ShoulderCamExternal", false)
	if not back and lastEye and lastLook then char:SetAttribute("ShoulderCamLookAt", lastEye + lastLook * 100) end -- v1.1: only with the switch off
	saved = nil
end

-- v1.2: the Sniper Scope view (see the header) -----------------------------------------------------------------------------
local SCOPE_CFG = {DiloScopeViewEnabled = true, DiloScopeFov = 30, DiloScopeRaise = 0.2, DiloScopeHole = 0.44, DiloScopeSensMul = 0.6,
	DiloScopeRecoilHold = 0.3, DiloScopeKick = 4}
for k, v in pairs(SCOPE_CFG) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function scfg(k) return tonumber(script:GetAttribute(k)) or SCOPE_CFG[k] end
local BLACK = Color3.new(0, 0, 0)
local maskGui = Instance.new("ScreenGui")
maskGui.Name = "DiloScopeMask"
maskGui.IgnoreGuiInset = true
maskGui.DisplayOrder = -5
maskGui.ResetOnSpawn = true
maskGui.Enabled = false
maskGui.Parent = player:WaitForChild("PlayerGui")
local hole = Instance.new("Frame") -- the hole: a huge black stroke outside a circle
hole.Name = "Hole"
hole.AnchorPoint = Vector2.new(0.5, 0.5)
hole.Position = UDim2.fromScale(0.5, 0.5)
hole.BackgroundTransparency = 1
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = hole
	local st = Instance.new("UIStroke")
	st.Color, st.Thickness, st.Transparency = BLACK, 3000, 0
	st.Parent = hole
end
hole.Parent = maskGui
local lensRing = Instance.new("Frame") -- a dark ring just inside the edge
lensRing.AnchorPoint = Vector2.new(0.5, 0.5)
lensRing.Position = UDim2.fromScale(0.5, 0.5)
lensRing.BackgroundTransparency = 1
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = lensRing
	local st = Instance.new("UIStroke")
	st.Color, st.Thickness, st.Transparency = Color3.fromRGB(26, 26, 26), 12, 0.15
	st.Parent = lensRing
end
lensRing.Parent = maskGui
local reticle = Instance.new("Frame")
reticle.Name = "Reticle"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.BackgroundTransparency = 1
reticle.Parent = maskGui
local function bar(px, py, ax, ay, sx, ox, sy, oy, round)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(ax, ay)
	f.Position = UDim2.fromScale(px, py)
	f.Size = UDim2.new(sx, ox, sy, oy)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = BLACK
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
	end
	f.Parent = reticle
	return f
end
bar(0, 0.5, 0, 0.5, 0.275, 0, 0, 6) -- thick posts: edge -> 45% in (0.55 R of 2 R)
bar(1, 0.5, 1, 0.5, 0.275, 0, 0, 6)
bar(0.5, 0, 0.5, 0, 0, 6, 0.275, 0)
bar(0.5, 1, 0.5, 1, 0, 6, 0.275, 0)
bar(0.5, 0.5, 0.5, 0.5, 0.45, 0, 0, 1.5) -- thin centre lines (0.9 R)
bar(0.5, 0.5, 0.5, 0.5, 0, 1.5, 0.45, 0)
for i = 1, 4 do -- mil dots every 0.1 R
	for _, sg in ipairs({-1, 1}) do
		bar(0.5 + sg * i * 0.05, 0.5, 0.5, 0.5, 0, 5, 0, 5, true)
		bar(0.5, 0.5 + sg * i * 0.05, 0.5, 0.5, 0, 5, 0, 5, true)
	end
end
local fireFlash = Instance.new("Frame")
fireFlash.Size = UDim2.fromScale(1, 1)
fireFlash.BorderSizePixel = 0
fireFlash.BackgroundColor3 = PALE
fireFlash.BackgroundTransparency = 1
fireFlash.Parent = maskGui
local chargeBox = Instance.new("Frame")
chargeBox.AnchorPoint = Vector2.new(0.5, 0.5)
chargeBox.Position = UDim2.fromScale(0.5, 0.5)
chargeBox.Size = UDim2.fromOffset(200, 200)
chargeBox.BackgroundTransparency = 1
chargeBox.Visible = false
chargeBox.Parent = gui
local chargeDots = {}
for i = 1, 28 do
	local a = math.rad(135 + (i - 1) / 27 * 270)
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.new(0.5, math.cos(a) * 48, 0.5, math.sin(a) * 48)
	d.Size = UDim2.fromOffset(5, 5)
	d.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = d
	d.Parent = chargeBox
	chargeDots[i] = d
end
local dmgNow = Instance.new("TextLabel")
dmgNow:SetAttribute("FontSwap", "keep")
dmgNow.AnchorPoint = Vector2.new(0.5, 0.5)
dmgNow.Position = UDim2.new(0.5, 0, 0.5, 78)
dmgNow.Size = UDim2.fromOffset(80, 24)
dmgNow.BackgroundTransparency = 1
dmgNow.FontFace = SILK
dmgNow.TextSize = 18
dmgNow.TextStrokeTransparency = 0.4
dmgNow.Parent = chargeBox
local scopeBanner = banner:Clone()
scopeBanner.Text = "SNIPER SCOPE · LET GO TO FIRE"
scopeBanner.Visible = false
scopeBanner.Parent = gui
local hitBox = Instance.new("Frame")
hitBox.AnchorPoint = Vector2.new(0.5, 0.5)
hitBox.Position = UDim2.fromScale(0.5, 0.5)
hitBox.Size = UDim2.fromOffset(120, 120)
hitBox.BackgroundTransparency = 1
hitBox.Visible = false
hitBox.Parent = gui
local hitTicks = {}
for _, q in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(0.5, q[1] * 16, 0.5, q[2] * 16)
	f.Size = UDim2.fromOffset(14, 3)
	f.Rotation = q[1] * q[2] > 0 and 45 or -45
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = hitBox
	table.insert(hitTicks, f)
end
local hitNum = Instance.new("TextLabel")
hitNum:SetAttribute("FontSwap", "keep")
hitNum.AnchorPoint = Vector2.new(0, 1)
hitNum.Position = UDim2.new(0.5, 30, 0.5, -18)
hitNum.Size = UDim2.fromOffset(80, 30)
hitNum.BackgroundTransparency = 1
hitNum.FontFace = SILK
hitNum.TextSize = 26
hitNum.TextColor3 = PALE
hitNum.TextStrokeTransparency = 0.3
hitNum.TextXAlignment = Enum.TextXAlignment.Left
hitNum.Parent = hitBox
local hitAt = nil
char:GetAttributeChangedSignal("DiloScopeShotAt"):Connect(function()
	local tgt = char:GetAttribute("DiloScopeTarget")
	if script:GetAttribute("DiloScopeViewEnabled") == false or typeof(tgt) ~= "string" or tgt == "" then return end
	hitNum.Text = tostring(math.floor((tonumber(char:GetAttribute("DiloScopeDmg")) or 0) + 0.5))
	hitAt = os.clock()
end)
RunService.RenderStepped:Connect(function()
	local u = hitAt and (os.clock() - hitAt) / 0.9 or 2
	hitBox.Visible = u < 1
	if u < 1 then
		for _, f in ipairs(hitTicks) do f.BackgroundTransparency = u end
		hitNum.TextTransparency = u
		hitNum.TextStrokeTransparency = 0.3 + 0.7 * u
		hitNum.Position = UDim2.new(0.5, 30, 0.5, -18 - 30 * u)
	end
end)
local function scopeEye(k)
	local head = char:FindFirstChild("Head")
	local root = head and head:FindFirstChild("Root")
	if root then
		for _, a in ipairs(root:GetChildren()) do
			if a:IsA("Attachment") and a:GetAttribute("DPartId") == "dscope" then return a.WorldPosition end
		end
	end
	local tip = char:FindFirstChild("Head_tip", true)
	local base = (tip and tip:IsA("BasePart") and tip.Position) or (hrp.Position + Vector3.yAxis * 3 * k)
	return base + Vector3.yAxis * (tonumber(cfg("DiloSnipeEyeUp")) or 1) * k
end
local scopeOwned, scopeT0, scopeFiredSeen = false, 0, nil
local function scopeHide()
	maskGui.Enabled = false
	chargeBox.Visible = false
	scopeBanner.Visible = false
end
local function scopeStep(dt, on)
	if script:GetAttribute("DiloScopeViewEnabled") == false then
		if scopeOwned then scopeOwned = false release() scopeHide() end
		return false
	end
	local holding = char:GetAttribute("DiloScopeAim") == true
	local firedAt = tonumber(char:GetAttribute("DiloScopeFiredAt"))
	local since = firedAt and os.clock() - firedAt or math.huge
	local hold = scfg("DiloScopeRecoilHold")
	if script:GetAttribute("DiloScopeShotHoldEnabled") ~= false then hold = tonumber(script:GetAttribute("DiloScopeShotHold")) or 0.5 end -- v1.3
	if not (on and (holding or (scopeOwned and since < hold))) then
		if scopeOwned then
			scopeOwned = false
			release()
			scopeHide()
		end
		return false
	end
	if not scopeOwned then
		if owning then release() end
		own()
		scopeOwned, scopeT0 = true, os.clock()
	end
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
	local sens = scfg("DiloScopeSensMul")
	if UserInputService.MouseEnabled and not anyTouch() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		local d = UserInputService:GetMouseDelta()
		if mouseMoved then
			local s = (tonumber(cfg("DiloSnipeMouseSens")) or 0.2) * sens
			yaw -= d.X * s
			pitch -= d.Y * s
		end
	end
	mouseMoved = false
	if pad.Magnitude > 0.15 then
		local sp = (tonumber(cfg("DiloSnipePadSpeed")) or 160) * dt * sens
		yaw -= pad.X * sp
		pitch += pad.Y * sp
	end
	pitch = math.clamp(pitch, cfg("DiloSnipePitchMin"), cfg("DiloSnipePitchMax"))
	local kick = 0
	if not holding and since < hold then
		local u = since / math.max(0.05, hold)
		kick = scfg("DiloScopeKick") * (1 - u) * (1 - u)
	end
	local look = CFrame.fromOrientation(math.rad(pitch + kick), math.rad(yaw), 0).LookVector
	local aimLook = CFrame.fromOrientation(math.rad(pitch), math.rad(yaw), 0).LookVector
	local flatLook = Vector3.new(aimLook.X, 0, aimLook.Z)
	flatLook = flatLook.Magnitude > 1e-3 and flatLook.Unit or hrp.CFrame.LookVector
	local k = char:GetScale() / 2
	local eye = scopeEye(k)
	cam.CFrame = CFrame.lookAt(eye, eye + look)
	local raise = math.clamp((os.clock() - scopeT0) / math.max(0.01, scfg("DiloScopeRaise")), 0, 1)
	raise = raise * raise * (3 - 2 * raise)
	local baseFov = saved and saved.fov or 70
	cam.FieldOfView = baseFov + (scfg("DiloScopeFov") - baseFov) * raise
	lastEye, lastLook = eye, aimLook
	char:SetAttribute("TurnLimitMode", "aim")
	char:SetAttribute("TurnLimitAimLook", flatLook)
	hud("off", 0)
	-- the mask + reticle
	local vp = cam.ViewportSize
	local R = math.max(1, math.min(vp.X, vp.Y) * scfg("DiloScopeHole") * raise)
	maskGui.Enabled = true
	hole.Size = UDim2.fromOffset(R * 2, R * 2)
	lensRing.Size = UDim2.fromOffset(R * 2, R * 2)
	reticle.Size = UDim2.fromOffset(R * 2, R * 2)
	reticle.Visible = raise > 0.95
	fireFlash.BackgroundTransparency = (not holding and since < 0.08) and 0.45 or 1
	-- the charge (while holding)
	chargeBox.Visible = holding and raise > 0.95
	if holding then
		local ch = math.clamp((now() - (tonumber(char:GetAttribute("DiloScopeAimAt")) or now())) / math.max(0.05, tonumber(char:GetAttribute("DiloPartScopeCharge")) or 1), 0, 1)
		local full = ch >= 1
		for i, d in ipairs(chargeDots) do
			d.BackgroundColor3 = full and VENOM or Color3.fromRGB(232, 245, 255)
			d.BackgroundTransparency = (i - 1) / 27 <= ch and 0 or 0.8
		end
		local lo, hi = tonumber(char:GetAttribute("DiloPartScopeMin")) or 15, tonumber(char:GetAttribute("DiloPartScopeMax")) or 40
		dmgNow.Text = tostring(math.floor(lo + (hi - lo) * ch + 0.5))
		dmgNow.TextColor3 = full and VENOM or Color3.fromRGB(232, 245, 255)
	end
	scopeBanner.Visible = holding
	show("DiloSnipeCamState", "scope")
	show("DiloScopeHoleNow", math.floor(R + 0.5))
	show("DiloSnipeYaw", math.floor(yaw + 0.5))
	show("DiloSnipePitch", math.floor(pitch + 0.5))
	return true
end

local BIND = "DinoDiloSnipeCam"
pcall(function() RunService:UnbindFromRenderStep(BIND) end)
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 5, function(dt)
	local on = cfg("DiloSnipeCamEnabled") ~= false and hum.Health > 0
	if scopeStep(dt, on) then return end -- v1.2: the Sniper Scope view
	if on and char:GetAttribute("DiloSnipeAim") == true then
		if not owning then own() end
		local cam = workspace.CurrentCamera
		if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
		if UserInputService.MouseEnabled and not anyTouch() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			local d = UserInputService:GetMouseDelta()
			if mouseMoved then
				local s = tonumber(cfg("DiloSnipeMouseSens")) or 0.2
				yaw -= d.X * s
				pitch -= d.Y * s
			end
		end
		mouseMoved = false
		if pad.Magnitude > 0.15 then
			local sp = (tonumber(cfg("DiloSnipePadSpeed")) or 160) * dt
			yaw -= pad.X * sp
			pitch += pad.Y * sp
		end
		pitch = math.clamp(pitch, cfg("DiloSnipePitchMin"), cfg("DiloSnipePitchMax"))
		local look = CFrame.fromOrientation(math.rad(pitch), math.rad(yaw), 0).LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		flatLook = flatLook.Magnitude > 1e-3 and flatLook.Unit or hrp.CFrame.LookVector
		local k = char:GetScale() / 2
		local tip = char:FindFirstChild("Head_tip", true)
		local head = char:FindFirstChild("Head")
		local base = (tip and tip:IsA("BasePart") and tip.Position) or (head and head:IsA("BasePart") and head.Position)
			or (hrp.Position + Vector3.yAxis * 3 * k)
		local eye = base + Vector3.yAxis * (tonumber(cfg("DiloSnipeEyeUp")) or 1.2) * k - flatLook * (tonumber(cfg("DiloSnipeEyeBack")) or 1.6) * k
		cam.CFrame = CFrame.lookAt(eye, eye + look)
		cam.FieldOfView = tonumber(cfg("DiloSnipeFov")) or 50
		lastEye, lastLook = eye, look
		char:SetAttribute("TurnLimitMode", "aim")
		char:SetAttribute("TurnLimitAimLook", flatLook)
		hud("aim", 1)
		show("DiloSnipeCamState", "aim")
		show("DiloSnipeYaw", math.floor(yaw + 0.5))
		show("DiloSnipePitch", math.floor(pitch + 0.5))
		return
	end
	mouseMoved = false
	if owning then release() end
	local holdStart = tonumber(char:GetAttribute("DiloSnipeHoldStart")) or 0
	local hold = 1.5
	local att = char:FindFirstChild("DiloAttackTest")
	if att then hold = tonumber(att:GetAttribute("DiloSnipeHold")) or 1.5 end
	local held = now() - holdStart
	if on and char:GetAttribute("DiloSnipeHolding") == true and held >= (tonumber(cfg("DiloSnipeRingAfter")) or 0.25) then
		hud("charge", math.clamp(held / math.max(0.01, hold), 0, 1))
		show("DiloSnipeCamState", "charge")
	else
		hud("off", 0)
		show("DiloSnipeCamState", "off")
	end
end)

local function cleanup()
	release()
	if maskGui.Parent then maskGui:Destroy() end -- v1.2
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	if gui.Parent then gui:Destroy() end
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
