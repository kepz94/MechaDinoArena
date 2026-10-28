-- ShoulderCam v1.3 (Dino Arcade) — over-the-shoulder aiming camera for the player's own dino (owner's client only).
-- The camera is Scriptable and placed every frame (RenderStep, Camera priority, after TurnLimit / PounceTest):
--   focus  = HumanoidRootPart position + ShoulderCamFocusHeight up (only the HRP position is used, so the view stays
--            steady while the body tilts, e.g. latched on a pounce target)
--   camera = focus + right * side * ShoulderCamSide + up * ShoulderCamHeight - look * ShoulderCamDistance * zoom,
--            rotated by yaw / pitch, pulled in to just before world geometry (other dinos, hitboxes and this dino are
--            ignored), plus Humanoid.CameraOffset applied in camera space (keeps BiteFX's punch and RoarFX's shake).
-- Aiming: mouse movement turns the camera (cursor locked to the centre, small centre dot); gamepad right stick;
--   touch drag on the right 60% of the screen. Pitch ShoulderCamPitchMin .. ShoulderCamPitchMax degrees. The body
--   turns toward the camera at its own turn rate: this script sets the character attribute TurnLimitMode = "aim"
--   for TurnLimit 1.1 (W/S move along the aim, A/D strafe).
-- Shoulder swap: Q / gamepad R3 / touch button "Shoulder"; the side slides over ~ShoulderCamSwapTime s. Starts right
--   (dino on the left of the screen).
-- Free cursor: hold Left Alt (cursor shown, camera stops turning, dot hidden); also while the Roblox menu is open.
-- Zoom: mouse wheel / pinch scales the distance between ShoulderCamZoomMin and ShoulderCamZoomMax (default 0.6-1.5).
-- Size-based defaults (measured once from the model at spawn; any of these attributes overrides):
--   ShoulderCamDistance = CameraStartZoom (T-Rex 35, raptor 16, else 35), ShoulderCamFocusHeight = 0.75 x the model
--   top above the HRP, ShoulderCamSide = max(0.6 x width, 0.9 x top + 1), ShoulderCamHeight = 0.35 x top.
-- Test / scripting hook: setting the character attribute ShoulderCamLookAt (Vector3) turns the camera to look at that
--   point once; the attribute is then cleared.
-- Off: ShoulderCamEnabled = false gives the camera back to Roblox (Custom), frees the mouse, TurnLimitMode = "move".
-- Diagnostics (character attributes, this client): ShoulderCamState ("aim" / "free" / "off"), ShoulderSide ("right" /
--   "left"), ShoulderCamYaw / ShoulderCamPitch (deg, whole), ShoulderCamZoom (0.05 steps), ShoulderCamBlocked (camera
--   pulled in by geometry), ShoulderCamNowDistance / ShoulderCamNowFocusHeight / ShoulderCamNowSide /
--   ShoulderCamNowHeight (the framing values in use, 0.1 steps).
-- A binding left by a previous character (its scripts are destroyed before their cleanup runs) is cleared at start.
-- v1.1: re-fit on scale (growth, DINO-6): the size-based framing (top, width) was measured once at spawn; when
--   Model:GetScale() changes (GrowthServer 1.0 stage-up) both are multiplied by new / spawn scale. The distance already
--   follows CameraStartZoom / ShoulderCamDistance, which GrowthServer scales. Diagnostics ShoulderCamScale (0.01
--   steps), ShoulderCamVersion.
-- v1.2 (MDA, mobile thumbstick turned the camera; Kepu 2026-10-28): on touch devices UserInputService:GetMouseDelta()
--   also returns the drag of a touch while MouseBehavior is LockCenter, so the movement thumbstick (and every other
--   touch) turned the camera through the mouse-aim path. The mouse delta is now applied only when
--   ShoulderCamMouseGate = "applied": no touch is down AND a MouseMovement InputChanged arrived since the last frame.
--   Touch look (right 60% drag, touch path above) is unchanged. Character attribute ShoulderCamMouseTouchGuard
--   (default true): false = v1.1 (mouse delta always applied). Diagnostic ShoulderCamMouseGate: "applied" (mouse delta
--   used), "touch" (a touch is down, delta ignored), "idle" (no mouse movement this frame, delta ignored), "off"
--   (guard off, v1.1), "free" (Left Alt / menu, no aiming).
-- v1.3 (MDA-10, Kepu 2026-10-28: "how about we just apply a vertical camera lock", phones / tablets only): on a touch
--   device without a mouse (UserInputService.TouchEnabled and not MouseEnabled) the pitch is set every frame to
--   ShoulderCamTouchPitch (degrees, default -20), after all look input, so no touch, drag or look-at hook tilts the
--   camera up or down there. Yaw (left / right turning) is unchanged. PC / touch laptops keep free pitch.
--   Character attributes ShoulderCamTouchPitchLock (default true; false = 1.2) and ShoulderCamTouchPitch.
--   Diagnostic ShoulderCamPitchLock: "locked" (touch device, pitch fixed), "free" (mouse device), "off" (lock off).
--   Test hook: ShoulderCamTouchPitchLockTest = true treats this device as touch-only (the Studio phone emulator keeps
--   MouseEnabled = true, so it would otherwise always be "free").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local player = Players.LocalPlayer

local BIND = "DinoShoulderCam"
local ACTION = "DinoShoulderSwap"
local DEFAULTS = {ShoulderCamEnabled = true, ShoulderCamSensitivity = 0.25, ShoulderCamPadSpeed = 240,
	ShoulderCamTouchSensitivity = 0.35, ShoulderCamPitchMin = -55, ShoulderCamPitchMax = 65, ShoulderCamPitchStart = -12,
	ShoulderCamZoomMin = 0.6, ShoulderCamZoomMax = 1.5, ShoulderCamSwapTime = 0.2,
	ShoulderCamMouseTouchGuard = true, -- v1.2
	ShoulderCamTouchPitchLock = true, ShoulderCamTouchPitch = -20} -- v1.3
local PAD_DEADZONE = 0.15
local WALL_PAD = 0.6      -- studs the camera stays in front of geometry it is pulled in by
local ZOOM_STEP = 0.1     -- zoom change per wheel notch

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local shown = {}
local function show(attr, value)
	if shown[attr] ~= value then
		shown[attr] = value
		char:SetAttribute(attr, value)
	end
end

local function round(x, step) return math.floor(x / step + 0.5) * step end

-- size-based framing, measured once at spawn (rest pose)
char:WaitForChild("Head", 5)
local boxCf, boxSize = char:GetBoundingBox()
local top = math.max(1, boxCf.Position.Y + boxSize.Y / 2 - hrp.Position.Y)
local width = char:GetExtentsSize().X
local spawnScale, spawnTop, spawnWidth, framedScale = char:GetScale(), top, width, char:GetScale() -- v1.1
char:SetAttribute("ShoulderCamVersion", "1.3")
local function framing()
	local sc = char:GetScale() -- v1.1: growth re-fit
	if math.abs(sc - framedScale) > 1e-4 then
		top = spawnTop * sc / spawnScale
		width = spawnWidth * sc / spawnScale
		framedScale = sc
		char:SetAttribute("ShoulderCamScale", math.floor(sc * 100 + 0.5) / 100)
	end
	local dist = char:GetAttribute("ShoulderCamDistance") or char:GetAttribute("CameraStartZoom") or 35
	local focusH = char:GetAttribute("ShoulderCamFocusHeight") or top * 0.75
	local side = char:GetAttribute("ShoulderCamSide") or math.max(width * 0.6, top * 0.9 + 1)
	local height = char:GetAttribute("ShoulderCamHeight") or top * 0.35
	return dist, focusH, side, height
end

-- camera state
local cam = workspace.CurrentCamera
local function lookYaw(v) return math.atan2(-v.X, -v.Z) end -- yaw of CFrame.Angles(0, yaw, 0) whose LookVector is v
local yaw = lookYaw(hrp.CFrame.LookVector)
local pitch = math.rad(get("ShoulderCamPitchStart"))
local zoom = 1
local sideTarget, sideNow = 1, 1 -- +1 = right shoulder
local padLook = Vector2.zero
local touchLook, touchDelta = nil, Vector2.zero
local wheelSteps = 0
local pinchStartZoom
local active = false
local touchesDown = {}     -- v1.2: [InputObject] = true for every touch currently down
local mouseMoved = false   -- v1.2: a MouseMovement InputChanged arrived since the last frame

-- crosshair dot
local gui = Instance.new("ScreenGui")
gui.Name = "ShoulderCamCrosshair"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = true
gui.DisplayOrder = 5
local dot = Instance.new("Frame")
dot.Name = "Dot"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(6, 6)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.BorderSizePixel = 0
dot.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = dot
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(20, 20, 20)
stroke.Thickness = 1
stroke.Transparency = 0.2
stroke.Parent = dot
gui.Parent = player:WaitForChild("PlayerGui")

-- inputs
UserInputService.InputChanged:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local p = Vector2.new(input.Position.X, input.Position.Y)
		padLook = p.Magnitude > PAD_DEADZONE and p or Vector2.zero
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		wheelSteps += input.Position.Z
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then -- v1.2
		mouseMoved = true
	elseif input == touchLook then
		touchDelta += Vector2.new(input.Delta.X, input.Delta.Y)
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch and not processed and not touchLook then
		local vp = cam.ViewportSize
		if input.Position.X > vp.X * 0.4 then touchLook = input end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input == touchLook then touchLook = nil end
end)
-- v1.2: touches down (any touch, processed or not), for the mouse-delta guard
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then touchesDown[input] = true end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then touchesDown[input] = nil end
end)
-- v1.2: "applied" / "touch" / "idle" / "off" (see header); clears the per-frame mouse flag
local function mouseGate()
	local moved = mouseMoved
	mouseMoved = false
	if get("ShoulderCamMouseTouchGuard") == false then return "off" end
	for t in pairs(touchesDown) do -- drop touches whose InputEnded was missed
		if t.UserInputState == Enum.UserInputState.End or t.UserInputState == Enum.UserInputState.Cancel then
			touchesDown[t] = nil
		end
	end
	if next(touchesDown) ~= nil then return "touch" end
	if not moved then return "idle" end
	return "applied"
end
UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
	if processed then return end
	if state == Enum.UserInputState.Begin then pinchStartZoom = zoom end
	if pinchStartZoom and scale > 0 then
		zoom = math.clamp(pinchStartZoom / scale, get("ShoulderCamZoomMin"), get("ShoulderCamZoomMax"))
	end
	if state == Enum.UserInputState.End then pinchStartZoom = nil end
end)

local function onSwap(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		sideTarget = -sideTarget
		show("ShoulderSide", sideTarget > 0 and "right" or "left")
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindActionAtPriority(ACTION, onSwap, true, Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.Q, Enum.KeyCode.ButtonR3)
ContextActionService:SetTitle(ACTION, "Shoulder")
show("ShoulderSide", "right")

-- world geometry between the focus and the wanted camera spot (ignores this dino, other dinos, hitboxes, FX)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function ignorable(part)
	if part:FindFirstAncestor("Hitboxes") then return true end
	local m = part:FindFirstAncestorWhichIsA("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then return true end
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return part.Transparency >= 1 or not part.CanCollide
end
local function clearSpot(from, to)
	local ignore = {char}
	local fx = workspace:FindFirstChild("DinoFX_Local")
	if fx then table.insert(ignore, fx) end
	local dir = to - from
	for _ = 1, 6 do
		rayParams.FilterDescendantsInstances = ignore
		local r = workspace:Raycast(from, dir, rayParams)
		if not r then return to, false end
		if ignorable(r.Instance) then
			table.insert(ignore, r.Instance)
		else
			local d = math.max(0, (r.Position - from).Magnitude - WALL_PAD)
			return from + dir.Unit * d, true
		end
	end
	return to, false
end

local function release()
	if active then
		active = false
		cam.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		char:SetAttribute("TurnLimitMode", "move")
	end
	gui.Enabled = false
end

local function step(dt)
	if not get("ShoulderCamEnabled") or hum.Health <= 0 then
		release()
		show("ShoulderCamState", "off")
		return
	end
	if not active then
		active = true
		yaw = lookYaw(hrp.CFrame.LookVector)
		char:SetAttribute("TurnLimitMode", "aim")
	end
	if cam ~= workspace.CurrentCamera then cam = workspace.CurrentCamera end
	if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end

	-- scripted look-at (test / cutscene hook)
	local lookAt = char:GetAttribute("ShoulderCamLookAt")
	if typeof(lookAt) == "Vector3" then
		local d = lookAt - (hrp.Position + Vector3.new(0, top * 0.75, 0))
		if d.Magnitude > 1e-3 then
			yaw = lookYaw(d)
			pitch = math.asin(math.clamp(d.Unit.Y, -1, 1))
		end
		char:SetAttribute("ShoulderCamLookAt", nil)
	end

	-- aim input
	local free = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or GuiService.MenuIsOpen
	UserInputService.MouseBehavior = free and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = free
	gui.Enabled = not free
	local gameSens = 1
	pcall(function() gameSens = UserSettings():GetService("UserGameSettings").MouseSensitivity end)
	local gate = mouseGate() -- v1.2
	show("ShoulderCamMouseGate", free and "free" or gate)
	if not free and (gate == "applied" or gate == "off") then
		local md = UserInputService:GetMouseDelta()
		local k = math.rad(get("ShoulderCamSensitivity")) * gameSens
		yaw -= md.X * k
		pitch -= md.Y * k
	end
	local padK = math.rad(get("ShoulderCamPadSpeed")) * dt
	yaw -= padLook.X * padK
	pitch += padLook.Y * padK
	local tk = math.rad(get("ShoulderCamTouchSensitivity"))
	yaw -= touchDelta.X * tk
	pitch -= touchDelta.Y * tk
	touchDelta = Vector2.zero
	-- v1.3: vertical lock on phones / tablets
	local pitchLock = "off"
	if get("ShoulderCamTouchPitchLock") then
		if (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
			or char:GetAttribute("ShoulderCamTouchPitchLockTest") == true then
			pitch = math.rad(get("ShoulderCamTouchPitch"))
			pitchLock = "locked"
		else
			pitchLock = "free"
		end
	end
	show("ShoulderCamPitchLock", pitchLock)
	pitch = math.clamp(pitch, math.rad(get("ShoulderCamPitchMin")), math.rad(get("ShoulderCamPitchMax")))
	yaw = (yaw + math.pi) % (2 * math.pi) - math.pi
	if wheelSteps ~= 0 then
		zoom = math.clamp(zoom * (1 - ZOOM_STEP * wheelSteps), get("ShoulderCamZoomMin"), get("ShoulderCamZoomMax"))
		wheelSteps = 0
	end

	-- shoulder side slides to the target
	local swap = math.max(0.02, get("ShoulderCamSwapTime"))
	sideNow += (sideTarget - sideNow) * math.min(1, dt * 4 / swap)

	-- place the camera
	local dist, focusH, side, height = framing()
	local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local focus = hrp.Position + Vector3.new(0, focusH, 0)
	local shoulder = focus + rot.RightVector * (side * sideNow) + Vector3.new(0, height, 0)
	local wanted = shoulder - rot.LookVector * (dist * zoom)
	local spot, blocked = clearSpot(focus, wanted)
	spot += rot:VectorToWorldSpace(hum.CameraOffset) -- bite punch / roar shake
	cam.CFrame = CFrame.new(spot) * rot.Rotation
	cam.Focus = CFrame.new(focus)

	show("ShoulderCamState", free and "free" or "aim")
	show("ShoulderCamYaw", math.floor(math.deg(yaw) + 0.5))
	show("ShoulderCamPitch", math.floor(math.deg(pitch) + 0.5))
	show("ShoulderCamZoom", round(zoom, 0.05))
	show("ShoulderCamBlocked", blocked)
	show("ShoulderCamNowDistance", round(dist, 0.1))
	show("ShoulderCamNowFocusHeight", round(focusH, 0.1))
	show("ShoulderCamNowSide", round(side, 0.1))
	show("ShoulderCamNowHeight", round(height, 0.1))
end

pcall(function() RunService:UnbindFromRenderStep(BIND) end) -- a previous character's binding
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, step)

local function cleanup()
	RunService:UnbindFromRenderStep(BIND)
	ContextActionService:UnbindAction(ACTION)
	release()
	gui:Destroy()
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
