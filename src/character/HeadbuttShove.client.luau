-- HeadbuttShove v1.0 (Mecha Dino Arena) — pushes the owner's own dino back when a pachy headbutt hits it (owner's
-- client). MDA-119, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 7 (Kepu 2026-10-30: "It should be shoved maybe 40 studs
-- and the opponent is debuffed at the same time"; the slow is applied by SprintTest 1.9).
-- HeadbuttServer 1.0 stamps the hit dino's character: HeadbuttShoveFrom (Vector3, the pachy's position),
--   HeadbuttShoveDist (studs), HeadbuttShoveTime (s), HeadbuttShoveAt (server time, set last). A fresh stamp (younger
--   than FRESH s) pushes the body straight away from HeadbuttShoveFrom (flat) with a LinearVelocity in plane mode:
--   speed = dist / time, easing to 0 at the end, for HeadbuttShoveTime s; the dino stays on its feet (no stun) and its
--   own movement is overridden only while the push runs.
-- Diagnostics (character, this client): HeadbuttShoveVersion, HeadbuttShoveState ("idle" / "pushed"), HeadbuttShoveMoved
--   (studs moved by the last push, 0.1 steps).
-- Switch: character attribute HeadbuttShoveEnabled (default true; false = no push, the slow still applies).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local FRESH = 1
local ACCEL = 20000 -- studs/s^2 the push may use (force limit = mass x this); Studio test: 2500 moved 10.7 of 40 studs,
-- 8000 35.9, 20000 39.2 (the humanoid's ground grip fights the push). Override: character attribute HeadbuttShoveAccel.

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
if not (hum and hrp) or Players:GetPlayerFromCharacter(char) ~= Players.LocalPlayer then return end
char:SetAttribute("HeadbuttShoveVersion", VERSION)
char:SetAttribute("HeadbuttShoveState", "idle")

local lv
local function ensure()
	if lv then return lv end
	local att = Instance.new("Attachment")
	att.Name = "HeadbuttShoveAttachment"
	att.Parent = hrp
	lv = Instance.new("LinearVelocity")
	lv.Name = "HeadbuttShove"
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
local function onShove()
	if char:GetAttribute("HeadbuttShoveEnabled") == false then return end
	local at, from = char:GetAttribute("HeadbuttShoveAt"), char:GetAttribute("HeadbuttShoveFrom")
	local dist, time = tonumber(char:GetAttribute("HeadbuttShoveDist")), tonumber(char:GetAttribute("HeadbuttShoveTime"))
	if typeof(at) ~= "number" or typeof(from) ~= "Vector3" or not dist or not time or time <= 0 then return end
	if math.abs(workspace:GetServerTimeNow() - at) > FRESH or hum.Health <= 0 then return end
	local away = Vector3.new(hrp.Position.X - from.X, 0, hrp.Position.Z - from.Z)
	if away.Magnitude < 0.5 then away = -Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z) end
	if away.Magnitude < 1e-3 then return end
	away = away.Unit
	token += 1
	local my = token
	local c = ensure()
	c.MaxForce = hrp.AssemblyMass * (tonumber(char:GetAttribute("HeadbuttShoveAccel")) or ACCEL)
	c.Enabled = true
	char:SetAttribute("HeadbuttShoveState", "pushed")
	local start = hrp.Position
	local peak = 2 * dist / time -- linear ease to 0 covers dist over time
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local u = (os.clock() - t0) / time
		if my ~= token or u >= 1 or hum.Health <= 0 or not hrp.Parent then
			conn:Disconnect()
			if my == token then
				c.Enabled = false
				char:SetAttribute("HeadbuttShoveState", "idle")
				local moved = Vector3.new(hrp.Position.X - start.X, 0, hrp.Position.Z - start.Z).Magnitude
				char:SetAttribute("HeadbuttShoveMoved", math.floor(moved * 10 + 0.5) / 10)
			end
			return
		end
		local v = away * peak * (1 - u)
		c.PlaneVelocity = Vector2.new(v.X, v.Z)
	end)
end
char:GetAttributeChangedSignal("HeadbuttShoveAt"):Connect(onShove)
