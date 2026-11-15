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
-- v1.1 (MDA-546, plan docs/plans/UNSTUCK_v1.0.md rule 1; Kepu 2026-11-15 11:22 "i was pushed into the ground from an attack and i
--   was in the map"): every knockback on a player (Pachy headbutt, Teno shove, Herrera Stun Breaker, Dilo hiss, Troodon shove)
--   comes through this push, which had no look-ahead and could drive the body through block edges into the map. Now each
--   Heartbeat of a push a Blockcast of the HumanoidRootPart (size x ShoveCastScaleXZ (0.9) / ShoveCastScaleY (0.6) / XZ, its own
--   rotation) runs along the push for this frame's travel + ShoveCastAhead (1.5) studs, against collidable parts of
--   Workspace.DinoIsland Ground / MountainSteps / Rocks / EdgeWalls / Trees (RespectCanCollide). A hit that is not floor-like
--   (normal.Y < ShoveFloorNormal (0.6)) ends the push at once (constraint off, HeadbuttShoveState "blocked", HeadbuttShoveMoved
--   as usual). Every number is a character attribute of that name. Switch: character attribute ShoveBlockEnabled (default
--   true, read per push; false = 1.0).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 the push stops before entering the map
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

-- v1.1: look-ahead (see the header)
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Include
castParams.RespectCanCollide = true
local function solidList()
	local isl = workspace:FindFirstChild("DinoIsland")
	local list = {}
	for _, n in ipairs({"Ground", "MountainSteps", "Rocks", "EdgeWalls", "Trees"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	return list
end
local function cfgN(k, d) return tonumber(char:GetAttribute(k)) or d end
local function blockedAhead(dir, step)
	if char:GetAttribute("ShoveBlockEnabled") == false then return false end
	local list = solidList()
	if #list == 0 then return false end
	castParams.FilterDescendantsInstances = list
	local xz, y = cfgN("ShoveCastScaleXZ", 0.9), cfgN("ShoveCastScaleY", 0.6)
	local size = Vector3.new(hrp.Size.X * xz, hrp.Size.Y * y, hrp.Size.Z * xz)
	local r = workspace:Blockcast(hrp.CFrame, size, dir * (step + cfgN("ShoveCastAhead", 1.5)), castParams)
	return r ~= nil and r.Normal.Y < cfgN("ShoveFloorNormal", 0.6)
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
	local blocked = false -- v1.1
	conn = RunService.Heartbeat:Connect(function(dt)
		local u = (os.clock() - t0) / time
		if not blocked and my == token and u < 1 and hrp.Parent and blockedAhead(away, peak * (1 - u) * dt) then blocked = true end -- v1.1
		if my ~= token or u >= 1 or hum.Health <= 0 or not hrp.Parent or blocked then
			conn:Disconnect()
			if my == token then
				c.Enabled = false
				char:SetAttribute("HeadbuttShoveState", blocked and "blocked" or "idle")
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
