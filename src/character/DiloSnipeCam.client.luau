-- DiloSnipeCam v1.0 (Mecha Dino Arena) — the Dilo sniper spit's head camera and aim HUD, PC and phone (LocalScript,
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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
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
local function hud(mode, u)
	for i, d in ipairs(dots) do
		d.Visible = mode == "charge"
		d.BackgroundTransparency = (mode == "charge" and (i - 1) / 24 < u) and 0 or 0.75
	end
	for _, f in ipairs(cross) do f.Visible = mode == "aim" end
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
		icon = UserInputService.MouseIconEnabled, turnMode = char:GetAttribute("TurnLimitMode")}
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
	if saved then
		cam.CameraType = saved.type
		cam.FieldOfView = saved.fov
		UserInputService.MouseBehavior = saved.mouse
		UserInputService.MouseIconEnabled = saved.icon
		char:SetAttribute("TurnLimitMode", saved.turnMode)
	end
	char:SetAttribute("TurnLimitAimLook", nil)
	char:SetAttribute("ShoulderCamExternal", false)
	if lastEye and lastLook then char:SetAttribute("ShoulderCamLookAt", lastEye + lastLook * 100) end
	saved = nil
end

local BIND = "DinoDiloSnipeCam"
pcall(function() RunService:UnbindFromRenderStep(BIND) end)
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 5, function(dt)
	local on = cfg("DiloSnipeCamEnabled") ~= false and hum.Health > 0
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
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	if gui.Parent then gui:Destroy() end
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
