-- ServoDashLaunch v1.1 (Mecha Dino Arena) — the instant forward shove of the pachy's Overclocked Servo Dash (owner's client).
-- MDA-126, plan docs/plans/PACHY_PARTS_B3_v1.0.md; Kepu 2026-10-30: "Launch + steerable speed".
-- ServoDashServer 1.0 stamps the owner's character ServoDashStartedAt (server time, set last). A fresh stamp (younger than
--   FRESH s) pushes the body forward along its flat facing with a LinearVelocity in plane mode: LAUNCH_DIST studs over
--   LAUNCH_TIME s (speed easing to 0), force limit = mass x ACCEL; then SprintTest 1.10 runs the dash speed you steer.
-- Settings (character attributes, defaults below): ServoDashLaunchDist (22), ServoDashLaunchTime (0.25).
-- Switch: character attribute ServoDashLaunchEnabled (default true; false = no shove, the speed still applies).
-- Diagnostics (character, this client): ServoDashLaunchVersion, ServoDashLaunchState ("idle" / "launching"),
--   ServoDashLaunchMoved (studs moved by the last shove, 0.1 steps).
-- v1.1 (Kepu 2026-10-30: "make the animation better for the burst"): the owner's own screen during the dash, the same
--   feel as the raptor's Thrusters boost (MechaButtons 1.2): an envelope k goes 0 -> 1 in 0.1 s at the press, stays 1
--   while ServoDashUntil is in the future and back to 0 in 0.3 s after:
--   * camera punch: RenderStep "ServoDashCam" at Camera priority + 2: FieldOfView = the FOV at the press + FOV_PUNCH (20)
--     x k, plus a shake (pitch / yaw up to 0.8 degrees x k, from math.noise); the FOV is put back when k is 0;
--   * speed lines: ScreenGui "ServoDashSpeedLines" (DisplayOrder 4, IgnoreGuiInset) with 40 white streaks flying out
--     from the middle of the screen toward the edges, transparency 1 - 0.65 x k (hidden at k 0).
--   Switch: character attribute ServoDashFxEnabled (default true; false = no punch, no lines). Diagnostic ServoDashFx (k,
--   0.1 steps).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
local FRESH = 1
local ACCEL = 20000

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
if not (hum and hrp) or Players:GetPlayerFromCharacter(char) ~= Players.LocalPlayer then return end
char:SetAttribute("ServoDashLaunchVersion", VERSION)
char:SetAttribute("ServoDashLaunchState", "idle")

local lv
local function ensure()
	if lv then return lv end
	local att = Instance.new("Attachment")
	att.Name = "ServoDashLaunchAttachment"
	att.Parent = hrp
	lv = Instance.new("LinearVelocity")
	lv.Name = "ServoDashLaunchVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.Enabled = false
	lv.Parent = hrp
	return lv
end

local token = 0
local function launch()
	if char:GetAttribute("ServoDashLaunchEnabled") == false then return end
	local stamp = char:GetAttribute("ServoDashStartedAt")
	if typeof(stamp) ~= "number" or workspace:GetServerTimeNow() - stamp > FRESH then return end
	local look = hrp.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude < 1e-3 then return end
	dir = dir.Unit
	local dist = tonumber(char:GetAttribute("ServoDashLaunchDist")) or 22
	local time = math.max(0.05, tonumber(char:GetAttribute("ServoDashLaunchTime")) or 0.25)
	local v = ensure()
	v.MaxForce = hrp.AssemblyMass * (tonumber(char:GetAttribute("ServoDashLaunchAccel")) or ACCEL)
	token += 1
	local my = token
	local start = hrp.Position
	local t0 = os.clock()
	char:SetAttribute("ServoDashLaunchState", "launching")
	v.Enabled = true
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = (os.clock() - t0) / time
		if my ~= token or a >= 1 or not char.Parent then
			conn:Disconnect()
			if my == token then
				v.Enabled = false
				char:SetAttribute("ServoDashLaunchState", "idle")
				local moved = Vector3.new(hrp.Position.X - start.X, 0, hrp.Position.Z - start.Z).Magnitude
				char:SetAttribute("ServoDashLaunchMoved", math.floor(moved * 10 + 0.5) / 10)
			end
			return
		end
		local speed = 2 * dist / time * (1 - a) -- linear ease to 0: total = dist
		v.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	end)
end

-- v1.1: camera punch + speed lines (see the header)
local FX_BIND, FOV_PUNCH = "ServoDashCam", 20
local fxGui, fxLines, fxBase
local fxK, fxT = 0, 0
local function dashing()
	local u = char:GetAttribute("ServoDashUntil")
	return typeof(u) == "number" and u > workspace:GetServerTimeNow()
end
local function fxBuild()
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	local old = pg:FindFirstChild("ServoDashSpeedLines")
	if old then old:Destroy() end
	fxGui = Instance.new("ScreenGui")
	fxGui.Name = "ServoDashSpeedLines"
	fxGui.ResetOnSpawn = true
	fxGui.DisplayOrder = 4
	fxGui.IgnoreGuiInset = true
	fxLines = {}
	for i = 1, 40 do
		local f = Instance.new("Frame")
		f.Name = "Line_" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Parent = fxGui
		fxLines[i] = {f = f, a = math.random() * math.pi * 2, r = 0.45 + math.random() * 0.55, len = 100 + math.random() * 120}
	end
	fxGui.Parent = pg
end
local function fxStep(dt)
	fxT += dt
	if dashing() then fxK = math.min(1, fxK + dt / 0.1) else fxK = math.max(0, fxK - dt / 0.3) end
	local cam = workspace.CurrentCamera
	if cam and fxBase then
		cam.FieldOfView = fxBase + FOV_PUNCH * fxK
		local amp = math.rad(0.8) * fxK
		cam.CFrame = cam.CFrame * CFrame.Angles(math.noise(fxT * 20, 2.3) * amp, math.noise(fxT * 20, 5.9) * amp, 0)
	end
	if fxGui and fxLines then
		local size = fxGui.AbsoluteSize
		local half = math.sqrt(size.X * size.X + size.Y * size.Y) / 2
		for _, l in ipairs(fxLines) do
			l.r += dt * 2.6
			if l.r > 1.05 then l.a, l.r, l.len = math.random() * math.pi * 2, 0.45 + math.random() * 0.2, 100 + math.random() * 120 end
			l.f.Position = UDim2.fromOffset(size.X / 2 + math.cos(l.a) * l.r * half, size.Y / 2 + math.sin(l.a) * l.r * half)
			l.f.Size = UDim2.fromOffset(l.len, 4)
			l.f.Rotation = math.deg(l.a)
			l.f.BackgroundTransparency = 1 - 0.65 * fxK
		end
		fxGui.Enabled = fxK > 0
	end
	local shown = math.floor(fxK * 10 + 0.5) / 10
	if char:GetAttribute("ServoDashFx") ~= shown then char:SetAttribute("ServoDashFx", shown) end
	if fxK <= 0 and not dashing() then
		if cam and fxBase then cam.FieldOfView = fxBase end
		fxBase = nil
		pcall(function() RunService:UnbindFromRenderStep(FX_BIND) end)
	end
end
local function fxStart()
	if char:GetAttribute("ServoDashFxEnabled") == false then return end
	local stamp = char:GetAttribute("ServoDashStartedAt")
	if typeof(stamp) ~= "number" or workspace:GetServerTimeNow() - stamp > FRESH then return end
	if fxBase then return end -- already running
	fxBase = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
	if not (fxGui and fxGui.Parent) then fxBuild() end
	pcall(function() RunService:UnbindFromRenderStep(FX_BIND) end)
	RunService:BindToRenderStep(FX_BIND, Enum.RenderPriority.Camera.Value + 2, fxStep)
end
char.AncestryChanged:Connect(function(_, parent)
	if parent then return end
	pcall(function() RunService:UnbindFromRenderStep(FX_BIND) end)
	local cam = workspace.CurrentCamera
	if cam and fxBase then cam.FieldOfView = fxBase end
	if fxGui then fxGui:Destroy() end
end)

char:GetAttributeChangedSignal("ServoDashStartedAt"):Connect(launch)
char:GetAttributeChangedSignal("ServoDashStartedAt"):Connect(fxStart) -- v1.1
