-- TenoLeapLaunch v1.0 (Mecha Dino Arena) — launches the teno's body for the Hydraulic Leap on the owner's client (the server
-- can't move a player's body smoothly; ServoDashLaunch 1.0's pattern). Plan docs/plans/TENO_ABILITIES_v1.0.md Task 5
-- (MDA-177). TenoMovesServer 1.0 stamps the owner's character TenoLeapStartedAt (server time, set last) with
--   TenoLeapDistNow (studs) and TenoLeapFlightTime (s). A fresh stamp (younger than FRESH 1 s) launches the body along its
--   flat facing: the horizontal speed TenoLeapDistNow / TenoLeapFlightTime held by a LinearVelocity in plane mode (force
--   limit = assembly mass x ACCEL) for the flight time, and an upward speed workspace.Gravity x flight time / 2 at the start
--   (Humanoid state Freefall), so the arc lands about TenoLeapDistNow studs ahead after the flight time.
-- Switch: character attribute TenoLeapLaunchEnabled (default true; false = no launch, the server still lands the slam).
-- Diagnostics (character, this client): TenoLeapLaunchVersion, TenoLeapLaunchState ("idle" / "launching"),
--   TenoLeapLaunchMoved (flat studs moved by the last launch, 0.1 steps).
local Players = game:GetService("Players")

local VERSION = "1.0"
local FRESH = 1
local ACCEL = 20000

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
if not (hum and hrp) or Players:GetPlayerFromCharacter(char) ~= Players.LocalPlayer then return end
char:SetAttribute("TenoLeapLaunchVersion", VERSION)
char:SetAttribute("TenoLeapLaunchState", "idle")

local lv
local function ensure()
	if lv then return lv end
	local att = Instance.new("Attachment")
	att.Name = "TenoLeapLaunchAttachment"
	att.Parent = hrp
	lv = Instance.new("LinearVelocity")
	lv.Name = "TenoLeapLaunchVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.Enabled = false
	lv.Parent = hrp
	return lv
end

local launchId = 0
char:GetAttributeChangedSignal("TenoLeapStartedAt"):Connect(function()
	if char:GetAttribute("TenoLeapLaunchEnabled") == false then return end
	local at = char:GetAttribute("TenoLeapStartedAt")
	if typeof(at) ~= "number" or math.abs(workspace:GetServerTimeNow() - at) > FRESH then return end
	local dist = tonumber(char:GetAttribute("TenoLeapDistNow")) or 40
	local T = math.max(0.2, tonumber(char:GetAttribute("TenoLeapFlightTime")) or 0.9)
	local look = hrp.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local v = dist / T
	local c = ensure()
	c.MaxForce = hrp.AssemblyMass * ACCEL
	c.PlaneVelocity = Vector2.new(dir.X * v, dir.Z * v)
	c.Enabled = true
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	hrp.AssemblyLinearVelocity = Vector3.new(dir.X * v, workspace.Gravity * T / 2, dir.Z * v)
	launchId += 1
	local id, start = launchId, hrp.Position
	char:SetAttribute("TenoLeapLaunchState", "launching")
	task.delay(T, function()
		if id ~= launchId then return end
		c.Enabled = false
		char:SetAttribute("TenoLeapLaunchState", "idle")
		local d = Vector3.new(hrp.Position.X - start.X, 0, hrp.Position.Z - start.Z).Magnitude
		char:SetAttribute("TenoLeapLaunchMoved", math.floor(d * 10 + 0.5) / 10)
	end)
end)
