-- TheriGrappleZip v1.0 (Mecha Dino Arena) — flies the owner's own therizino to its Grapple Zip anchor (owner's client).
-- MDA-247, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7; server TheriMovesServer 1.2 (pattern: HookPull 1.0).
-- TheriMovesServer stamps the character: TheriGrappleTo (where to stop), TheriGrappleTime (s), TheriGrappleResult "zip",
--   TheriGrappleAt (server time, set last). A fresh stamp (younger than FRESH (1) s) drives the root for TheriGrappleTime s
--   with a LinearVelocity (3D, gravity overridden) toward TheriGrappleTo (speed = distance left / time left, at most
--   MAX_SPEED 220), then lets go with the last velocity x KEEP (0.25). Stops early when within ARRIVE (2) studs, dead or
--   stunned.
-- Switch: character attribute TheriGrappleZipEnabled (default true; false = not moved). Diagnostics (character, this client):
--   TheriGrappleZipVersion, TheriGrappleZipState ("idle" / "zip"), TheriGrappleZipMoved (studs).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local FRESH, MAX_SPEED, ARRIVE, KEEP = 1, 220, 2, 0.25
local ACCEL = 20000

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
if not (hum and hrp) or Players:GetPlayerFromCharacter(char) ~= Players.LocalPlayer then return end
char:SetAttribute("TheriGrappleZipVersion", VERSION)
char:SetAttribute("TheriGrappleZipState", "idle")

local lv
local function ensure()
	if lv and lv.Parent then return lv end
	local att = hrp:FindFirstChild("TheriGrappleZipAttachment") or Instance.new("Attachment")
	att.Name = "TheriGrappleZipAttachment"
	att.Parent = hrp
	lv = Instance.new("LinearVelocity")
	lv.Name = "TheriGrappleZipVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.Enabled = false
	lv.Parent = hrp
	return lv
end

local token = 0
local function onZip()
	if char:GetAttribute("TheriGrappleZipEnabled") == false then return end
	if char:GetAttribute("TheriGrappleResult") ~= "zip" then return end
	local at, to, time = char:GetAttribute("TheriGrappleAt"), char:GetAttribute("TheriGrappleTo"), tonumber(char:GetAttribute("TheriGrappleTime"))
	if typeof(at) ~= "number" or typeof(to) ~= "Vector3" or not time or time <= 0 then return end
	if math.abs(workspace:GetServerTimeNow() - at) > FRESH or hum.Health <= 0 then return end
	token += 1
	local my = token
	local c = ensure()
	c.MaxForce = hrp.AssemblyMass * ACCEL
	c.Enabled = true
	char:SetAttribute("TheriGrappleZipState", "zip")
	local start = hrp.Position
	local t0 = os.clock()
	local last = Vector3.zero
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local left = time - (os.clock() - t0)
		local d = to - hrp.Position
		local stunned = (tonumber(char:GetAttribute("StunnedUntil")) or 0) > workspace:GetServerTimeNow()
		if my ~= token or left <= 0 or d.Magnitude <= ARRIVE or hum.Health <= 0 or stunned or not hrp.Parent then
			conn:Disconnect()
			if my == token then
				c.Enabled = false
				hrp.AssemblyLinearVelocity = last * KEEP
				char:SetAttribute("TheriGrappleZipState", "idle")
				char:SetAttribute("TheriGrappleZipMoved", math.floor((hrp.Position - start).Magnitude * 10 + 0.5) / 10)
			end
			return
		end
		local v = d / math.max(left, 0.05)
		if v.Magnitude > MAX_SPEED then v = v.Unit * MAX_SPEED end
		last = v
		c.VectorVelocity = v
	end)
end
char:GetAttributeChangedSignal("TheriGrappleAt"):Connect(onZip)
