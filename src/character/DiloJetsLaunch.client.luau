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
-- v1.1 (MDA-329, plan docs/plans/DILO_PARTS_FIT_v1.0.md Task 2; Kepu 2026-11-06 12:22 "a pause before it takes off" -> "Instant
--   burst + Thrusters FX"): the burst starts on the press, like the Thrusters. MechaButtons 1.38 sets the local attributes
--   DiloJetsPressDir / DiloJetsPressAt; when the dash is instant (the last server stamp DiloJetsDelay is under 0.05 s, or none
--   yet), a charge is left (DiloPartJetsLeft > 0), the part is on and the dilo is not dead / stunned / dazed / pinned /
--   silenced, this client works out the same end as DiloMovesServer 1.3 (raycast DiloPartJetsDist studs along the press
--   direction, stop 3 x scale / 2 short of a hit, under JETS_MIN 4 studs no dash; keep the height above the ground) and drives
--   there at once in clamp(distance / 150, 0.15, 0.3) s. The server's stamp for that press (DiloJetsAt within FRESH s of the
--   press) only moves the end to the server's DiloJetsTo; it does not start a second burst. Stamps without a press (switch off,
--   another client) work as 1.0. Switch: character attribute DiloJetsPredictEnabled (default true, read at each press; false
--   = 1.0). Diagnostics: DiloJetsLaunchState "dash" from the press, DiloJetsPressLag (s, 0.001 steps: press -> first move
--   frame, this client), DiloJetsPredicted (count); DiloJetsPredictedAt (= the press stamp, set when the burst starts; read by
--   DiloPose 1.4 / DiloMovesFX 1.2).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 the burst starts on the press
local JETS_SPEED, JETS_MIN = 150, 4 -- v1.1: DiloMovesServer 1.3's numbers
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
-- v1.1: the press path -------------------------------------------------------------------------------------------------
local pressed = {at = nil, running = false, to = nil, done = false} -- the newest predicted burst
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local function worldOnly() -- DiloMovesServer's list
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX", "PachyFX_Local", "DiloFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rp.FilterDescendantsInstances = ex
	return rp
end
local function groundY(pos)
	local g = workspace:Raycast(Vector3.new(pos.X, pos.Y + 60, pos.Z), Vector3.new(0, -200, 0), worldOnly())
	return g and g.Position.Y or nil
end
local function num(k) local v = char:GetAttribute(k) return typeof(v) == "number" and v == v and v or nil end
local function onPress()
	if char:GetAttribute("DiloJetsPredictEnabled") == false or char:GetAttribute("DiloJetsLaunchEnabled") == false then return end
	local pressAt = num("DiloJetsPressAt")
	if not pressAt then return end
	local T = workspace:GetServerTimeNow()
	local lastDelay = num("DiloJetsDelay")
	if lastDelay and lastDelay >= 0.05 then return end -- the wind-up mode (server switch off): 1.0 path
	if char:GetAttribute("DiloPartJetsEnabled") ~= true or (num("DiloPartJetsLeft") or 0) <= 0 then return end
	if hum.Health <= 0 or stunnedNow() or char:GetAttribute("PinHeld") == true or (num("DazedUntil") or 0) > T
		or (num("SilencedUntil") or 0) > T then return end
	local d = char:GetAttribute("DiloJetsPressDir")
	d = typeof(d) == "Vector3" and Vector3.new(d.X, 0, d.Z) or Vector3.zero
	if d.Magnitude < 0.1 then
		local lv = hrp.CFrame.LookVector
		d = Vector3.new(lv.X, 0, lv.Z)
	end
	if d.Magnitude < 1e-3 then return end
	d = d.Unit
	local s = char:GetScale()
	local range = math.max(0, num("DiloPartJetsDist") or 25)
	local from = hrp.Position
	local hit = workspace:Raycast(from, d * range, worldOnly())
	local dist = hit and math.max(0, Vector3.new(hit.Position.X - from.X, 0, hit.Position.Z - from.Z).Magnitude - 3 * s / 2) or range
	if dist < JETS_MIN then return end
	local to = from + d * dist
	local g0, g1 = groundY(from), groundY(to)
	if g0 and g1 then to = Vector3.new(to.X, g1 + (from.Y - g0), to.Z) end
	local time = math.clamp(dist / JETS_SPEED, 0.15, 0.3)
	token += 1
	local my = token
	local c = ensure()
	c.MaxForce = hrp.AssemblyMass * ACCEL
	pressed.at, pressed.running, pressed.to, pressed.done = pressAt, true, to, false
	char:SetAttribute("DiloJetsPredicted", (char:GetAttribute("DiloJetsPredicted") or 0) + 1)
	char:SetAttribute("DiloJetsPredictedAt", pressAt) -- last: DiloPose 1.4 / DiloMovesFX 1.2 start here
	char:SetAttribute("DiloJetsLaunchState", "dash")
	local start = hrp.Position
	local first = true
	c.Enabled = true
	drive(my, c, time, function(_, left)
		if first then
			first = false
			char:SetAttribute("DiloJetsPressLag", math.floor((workspace:GetServerTimeNow() - pressAt) * 1000 + 0.5) / 1000)
		end
		local dd = pressed.to - hrp.Position
		if dd.Magnitude <= ARRIVE then return nil end
		local v = dd / math.max(left, 0.03)
		if v.Magnitude > DASH_MAX then v = v.Unit * DASH_MAX end
		return v
	end, function(last)
		pressed.running, pressed.done = false, true
		hrp.AssemblyLinearVelocity = Vector3.new(last.X, 0, last.Z) * DASH_KEEP
		char:SetAttribute("DiloJetsLaunchState", "idle")
		char:SetAttribute("DiloJetsMoved", math.floor((hrp.Position - start).Magnitude * 10 + 0.5) / 10)
	end)
end
char:GetAttributeChangedSignal("DiloJetsPressAt"):Connect(onPress)

local function onDash()
	if char:GetAttribute("DiloJetsLaunchEnabled") == false or char:GetAttribute("DiloJetsResult") ~= "dash" then return end
	local sAt = char:GetAttribute("DiloJetsAt")
	if typeof(sAt) == "number" and pressed.at and sAt - pressed.at > -0.05 and sAt - pressed.at < FRESH then -- v1.1: our press
		local sTo = char:GetAttribute("DiloJetsTo")
		if pressed.running and typeof(sTo) == "Vector3" then pressed.to = sTo end
		pressed.at = nil
		return
	end
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
