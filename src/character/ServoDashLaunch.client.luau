-- ServoDashLaunch v1.0 (Mecha Dino Arena) — the instant forward shove of the pachy's Overclocked Servo Dash (owner's client).
-- MDA-126, plan docs/plans/PACHY_PARTS_B3_v1.0.md; Kepu 2026-10-30: "Launch + steerable speed".
-- ServoDashServer 1.0 stamps the owner's character ServoDashStartedAt (server time, set last). A fresh stamp (younger than
--   FRESH s) pushes the body forward along its flat facing with a LinearVelocity in plane mode: LAUNCH_DIST studs over
--   LAUNCH_TIME s (speed easing to 0), force limit = mass x ACCEL; then SprintTest 1.10 runs the dash speed you steer.
-- Settings (character attributes, defaults below): ServoDashLaunchDist (22), ServoDashLaunchTime (0.25).
-- Switch: character attribute ServoDashLaunchEnabled (default true; false = no shove, the speed still applies).
-- Diagnostics (character, this client): ServoDashLaunchVersion, ServoDashLaunchState ("idle" / "launching"),
--   ServoDashLaunchMoved (studs moved by the last shove, 0.1 steps).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
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

char:GetAttributeChangedSignal("ServoDashStartedAt"):Connect(launch)
