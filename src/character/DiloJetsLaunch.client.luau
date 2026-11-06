-- DiloJetsLaunch v1.0 (Mecha Dino Arena) — moves the owner's own dilo on a Spring Jets dash (owner's client, LocalScript in
-- StarterCharacterScripts). MDA-321, plan docs/plans/DILO_PARTS_v1.0.md Task 8; server DiloMovesServer 1.1 (pattern:
-- TheriGrappleZip 1.3's Dash / ServoDashLaunch).
-- DiloMovesServer stamps the character: DiloJetsFrom, DiloJetsTo, DiloJetsDelay (the 0.34 s wind-up), DiloJetsTime (s),
--   DiloJetsResult "dash", DiloJetsAt (server time, set last). A fresh stamp (younger than FRESH 1 s) holds the root still
--   (LinearVelocity 0) until DiloJetsDelay s after the stamp, then drives it to DiloJetsTo in DiloJetsTime s (speed = distance
--   left / time left, at most DASH_MAX 450; within ARRIVE 2 studs it stops), then keeps DASH_KEEP 0.2 of the flat speed (the
--   skid; no landing FX). Stops early when dead or stunned.
-- Switch: character attribute DiloJetsLaunchEnabled (default true; false = not moved). Diagnostics (character, this client):
--   DiloJetsLaunchVersion, DiloJetsLaunchState ("idle" / "charge" / "dash"), DiloJetsMoved (studs, 0.1 steps).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local FRESH, ARRIVE, ACCEL, DASH_MAX, DASH_KEEP = 1, 2, 20000, 450, 0.2

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
if not (hum and hrp) or Players:GetPlayerFromCharacter(char) ~= Players.LocalPlayer then return end
char:SetAttribute("DiloJetsLaunchVersion", VERSION)
char:SetAttribute("DiloJetsLaunchState", "idle")

local lv
local function ensure()
	if lv and lv.Parent then return lv end
	local att = hrp:FindFirstChild("DiloJetsAttachment") or Instance.new("Attachment")
	att.Name = "DiloJetsAttachment"
	att.Parent = hrp
	lv = Instance.new("LinearVelocity")
	lv.Name = "DiloJetsVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.Enabled = false
	lv.Parent = hrp
	return lv
end

local token = 0
local function stunnedNow() return (tonumber(char:GetAttribute("StunnedUntil")) or 0) > workspace:GetServerTimeNow() end
local function drive(my, c, dur, velFn, onEnd)
	local t0 = os.clock()
	local last = Vector3.zero
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local e = os.clock() - t0
		local v = (my == token and e < dur and hum.Health > 0 and not stunnedNow() and hrp.Parent ~= nil) and velFn(e, dur - e) or nil
		if v == nil then
			conn:Disconnect()
			if my == token then
				c.Enabled = false
				onEnd(last)
			end
			return
		end
		last = v
		c.VectorVelocity = v
	end)
end
local function onDash()
	if char:GetAttribute("DiloJetsLaunchEnabled") == false or char:GetAttribute("DiloJetsResult") ~= "dash" then return end
	local at, to = char:GetAttribute("DiloJetsAt"), char:GetAttribute("DiloJetsTo")
	local delay, time = tonumber(char:GetAttribute("DiloJetsDelay")) or 0, tonumber(char:GetAttribute("DiloJetsTime"))
	if typeof(at) ~= "number" or typeof(to) ~= "Vector3" or not time or time <= 0 then return end
	local age = workspace:GetServerTimeNow() - at
	if math.abs(age) > FRESH or hum.Health <= 0 then return end
	token += 1
	local my = token
	local c = ensure()
	c.MaxForce = hrp.AssemblyMass * ACCEL
	c.VectorVelocity = Vector3.zero
	c.Enabled = true
	char:SetAttribute("DiloJetsLaunchState", "charge")
	local start = hrp.Position
	drive(my, c, math.max(0, delay - math.max(0, age)), function() return Vector3.zero end, function()
		c.Enabled = true
		char:SetAttribute("DiloJetsLaunchState", "dash")
		drive(my, c, time, function(_, left)
			local d = to - hrp.Position
			if d.Magnitude <= ARRIVE then return nil end
			local v = d / math.max(left, 0.03)
			if v.Magnitude > DASH_MAX then v = v.Unit * DASH_MAX end
			return v
		end, function(last)
			hrp.AssemblyLinearVelocity = Vector3.new(last.X, 0, last.Z) * DASH_KEEP
			char:SetAttribute("DiloJetsLaunchState", "idle")
			char:SetAttribute("DiloJetsMoved", math.floor((hrp.Position - start).Magnitude * 10 + 0.5) / 10)
		end)
	end)
end
char:GetAttributeChangedSignal("DiloJetsAt"):Connect(onDash)
