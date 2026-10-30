-- HookPull v1.0 (Mecha Dino Arena) — reels the owner's own dino in when a pachy's Grappling Hook grabs it (owner's
-- client). MDA-122, plan docs/plans/PACHY_PARTS_v1.0.md Drop A Task 5.
-- HookServer 1.0 stamps the grabbed dino's character: HookPullBy (the pachy character's name), HookPullGap (studs in
--   front of that pachy's root), HookPullTime (s), HookPullAt (server time, set last). A fresh stamp (younger than FRESH
--   s) drives the body every frame for HookPullTime s with a plane LinearVelocity toward the point HookPullGap studs in
--   front of the pachy (followed live; speed = distance left / time left, at most MAX_SPEED), overriding the own
--   movement; gravity still applies. Then the smash (HookServer) knocks it back through HeadbuttShove 1.0.
-- Diagnostics (character, this client): HookPullVersion, HookPullState ("idle" / "pulled"), HookPullMoved (studs).
-- Switch: character attribute HookPullEnabled (default true; false = not moved, the smash range check then decides).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local FRESH = 1
local MAX_SPEED = 260
local ACCEL = 20000 -- studs/s^2 x mass force limit (as HeadbuttShove 1.0)

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
if not (hum and hrp) or Players:GetPlayerFromCharacter(char) ~= Players.LocalPlayer then return end
char:SetAttribute("HookPullVersion", VERSION)
char:SetAttribute("HookPullState", "idle")

local lv
local function ensure()
	if lv then return lv end
	local att = Instance.new("Attachment")
	att.Name = "HookPullAttachment"
	att.Parent = hrp
	lv = Instance.new("LinearVelocity")
	lv.Name = "HookPull"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.ForceLimitsEnabled = true
	lv.Enabled = false
	lv.Parent = hrp
	return lv
end

local token = 0
local function onPull()
	if char:GetAttribute("HookPullEnabled") == false then return end
	local at, by = char:GetAttribute("HookPullAt"), char:GetAttribute("HookPullBy")
	local gap, time = tonumber(char:GetAttribute("HookPullGap")), tonumber(char:GetAttribute("HookPullTime"))
	if typeof(at) ~= "number" or type(by) ~= "string" or not gap or not time or time <= 0 then return end
	if math.abs(workspace:GetServerTimeNow() - at) > FRESH or hum.Health <= 0 then return end
	local puller = workspace:FindFirstChild(by, true)
	local proot = puller and puller:IsA("Model") and puller:FindFirstChild("HumanoidRootPart")
	if not proot then return end
	token += 1
	local my = token
	local c = ensure()
	c.MaxForce = hrp.AssemblyMass * ACCEL
	c.Enabled = true
	char:SetAttribute("HookPullState", "pulled")
	local start = hrp.Position
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local left = time - (os.clock() - t0)
		if my ~= token or left <= 0 or hum.Health <= 0 or not hrp.Parent or not proot.Parent then
			conn:Disconnect()
			if my == token then
				c.Enabled = false
				char:SetAttribute("HookPullState", "idle")
				local moved = Vector3.new(hrp.Position.X - start.X, 0, hrp.Position.Z - start.Z).Magnitude
				char:SetAttribute("HookPullMoved", math.floor(moved * 10 + 0.5) / 10)
			end
			return
		end
		local f = proot.CFrame.LookVector * Vector3.new(1, 0, 1)
		f = f.Magnitude > 1e-3 and f.Unit or Vector3.zAxis
		local goal = proot.Position + f * gap
		local d = Vector3.new(goal.X - hrp.Position.X, 0, goal.Z - hrp.Position.Z)
		local v = d / math.max(left, 0.05)
		if v.Magnitude > MAX_SPEED then v = v.Unit * MAX_SPEED end
		c.PlaneVelocity = Vector2.new(v.X, v.Z)
	end)
end
char:GetAttributeChangedSignal("HookPullAt"):Connect(onPull)
