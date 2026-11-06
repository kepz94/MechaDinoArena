-- JumpTest v1.5 (Dino Arcade) — TEST input for the leap (owner's client only). Jump key / gamepad A / touch jump
-- button. Only active while the character attribute JumpEnabled is true (default false: the T-Rex keeps the
-- default Roblox jump untouched).
-- v1.1 (pachy Mecha Legs star, MDA-123): while JumpDoubleEnabled (SkillEffects 1.15) is true, a NEW jump press (the
--   key / button released and pressed again) in mid-air during a leap gives one double jump per leap: vertical speed set
--   to JumpLaunchPower x JumpDoubleMul (0.894 = 80% of a leap's height), horizontal speed kept, the air hold keeps going;
--   DinoJumpDoubleRequest(stamp) tells JumpServer 1.2 (JumpDoubleAt for every client). Local JumpDoublePredictedAt (this
--   client's FX). Diagnostics: JumpDoubleLocal ("ready" / "used"), JumpDoubleLocalCount. Switch: JumpDoubleEnabled.
-- v1.2 (Kepu 2026-10-30: "Leaping isn't powerful enough ... the second should be really strong too"): the double jump
--   also adds JumpDoubleForward studs/s (character attribute, SkillEffects 1.16; 0 / missing = none) along the body's
--   facing to the horizontal speed, and the air hold (input held) steers at that faster speed. Fix: doubleUsed /
--   wasHeld are declared before launch() (1.1 declared them after it, so launch() reset a global and only the first
--   leap of a life could double jump).
-- v1.3 (MDA-147, plan docs/plans/HERRERA_JUMP_v1.0.md Task 2: the Herrera's JUMP on a tree top fired both this leap and
--   ClimbTest's hop): while the character attribute JumpSuppressed is true (ClimbTest 1.13 sets it while the Herrera is on
--   a trunk / tree top), a press is refused (JumpInputResult "suppressed"), a crouch is cancelled, and a leap in the air
--   ends at once (air hold off, Jumping state off) so the climb owns the body. Nothing sets it on other dinos. Switch:
--   script attribute JumpSuppressEnabled (default true, read at start; false = 1.2).
-- v1.4 (leap charges, Kepu 2026-11-02: the teno's Hydraulic Leap fires through JUMP with "2 charges"; JumpServer 1.3):
--   while the character attribute JumpCharges is >= 1 a press needs a charge left (this client's own count, the same rule
--   as JumpServer 1.3: each used charge refills JumpCooldown s after the previous refill) and 0.5 s since the last local
--   leap, instead of the plain JumpCooldown; else "cooldown". A press uses a charge; a server "denied" sets the count to
--   the replicated JumpChargesLeft. Diagnostic: JumpChargesLocal. Switch: script attribute JumpChargesEnabled (default
--   true, read at start; false = 1.3).
-- v1.5 (Troodon Evade Hop, MDA-335, plan docs/plans/TROODON_KIT_v1.0.md Task 6; Kepu 2026-11-06 jump J2): while the character
--   attribute JumpHopBack is true (only TroodonModelData 1.1 sets it) a leap is an Evade Hop: the same press, charges and
--   DinoJumpRequest path as 1.4 (JumpServer 1.3), but the crouch lasts JumpHopWindup (0.1 s) and the launch is a quick low
--   hop straight BACK: the body's flat facing at the launch is kept for the whole hop (yaw re-set every frame, so W / S /
--   no input never turn it; Humanoid.AutoRotate off, put back on landing), vertical speed JumpHopPower, and this client's
--   own LinearVelocity "JumpHopDrive" (Plane mode, X/Z) holds -facing x JumpHopDistance x scale / JumpHopTime for
--   JumpHopTime s, then holds zero horizontal speed until landing (move input never steers or lengthens the hop). No
--   air-hold steering, no double jump during a hop; plain landing (no FX). Switch: script attribute
--   JumpHopBackEnabled (default true, read at each press; false = the 1.4 leap). Diagnostics: JumpHopLocal ("hop" /
--   "landed"), JumpHopMoved (flat studs launch -> landing, 0.1 steps), JumpHopYawDrift (deg the facing moved during the
--   hop, 0.1 steps).
--   Kepu 2026-11-06: hop ~5.3 studs high, JumpHopPower 40 (TroodonModelData 1.1); ~4 studs (power 36) made the Humanoid land
--   at the top of the arc (Landed 0.22 s after launch, the hop cut to ~9 studs).
-- While enabled, the Humanoid's built-in Jumping state is turned off, so a press never jumps straight away. Instead:
--   1. Press (when allowed): JumpPredictedAt = server time (this client only, so the crouch shows at once) and
--      DinoJumpRequest:FireServer(that time) (JumpServer 1.0 validates and sets the replicated JumpStartedAt).
--   2. Crouch: JumpWindup seconds (default 0.12). Movement continues as normal. If JumpServer denies this stamp
--      (JumpDeniedAt == the stamp) before the crouch ends, the leap is cancelled ("denied").
--   3. Launch: Jumping state on for this one jump, JumpPower = JumpLaunchPower (default 59: measured 11.0 studs
--      high, 0.67 s in the air at gravity 196.2 — the Humanoid's floor push adds speed during liftoff, so the
--      height is above JumpPower^2 / 2g), Humanoid:ChangeState(Jumping).
--      Forward boost: if the horizontal speed at takeoff is
--      above JumpBoostMinSpeed (default 2 studs/s), JumpBoost (default 10) studs/s is added along the body's
--      forward. Leap speed = the horizontal speed after the boost.
--   4. Air (JumpAirHold, default true): while move input is held, a LinearVelocity constraint (Plane mode, X/Z only,
--      this client's own instance "JumpAirHold" on the HumanoidRootPart) holds the horizontal velocity at the move
--      direction x leap speed (at least Humanoid.WalkSpeed) x input strength, so the boosted speed is kept and the
--      leap steers at the body's turn rate (TurnLimit 1.0 sets the move direction). Vertical motion is left to
--      gravity. Force limit = assembly mass x JUMP_HOLD_ACCEL. No input -> constraint off, Roblox air control
--      (slows down). Humanoid.WalkSpeed is not changed (Roblox air control pulls toward it inside each physics
--      step, and raising it also pulled the body down faster than gravity: peak 8.5 instead of 11 studs).
--      Jumping is turned off again once the body is airborne.
--   5. Landed (floor under the feet again after leaving the ground) -> ready. Holding the key re-leaps on landing
--      (each leap costs stamina).
-- Allowed only when: JumpEnabled, alive, standing on a floor, not Exhausted, stamina >= JumpStaminaCost
--   (when StaminaEnabled ~= false; read from StaminaServer's curve), JumpCooldown since the last local leap.
-- Input: StarterPlayer.PlayerModule.InputContexts.CharacterContext.JumpAction (Input Action System, boolean
--   state) when present; otherwise Humanoid.Jump (set by the control scripts while the key is held) and
--   UserInputService.JumpRequest.
-- Settings (character attributes): JumpEnabled, JumpWindup, JumpLaunchPower, JumpBoost, JumpBoostMinSpeed,
--   JumpAirHold, JumpStaminaCost, JumpCooldown.
-- Diagnostics (character attributes, this client): JumpTestState ("disabled" / "ready" / "crouch" / "air" /
--   "dead"), JumpInputResult ("sent" / "air" / "exhausted" / "stamina" / "cooldown" / "dead" / "denied" /
--   "noLiftoff"), JumpInputSource ("inputAction" / "humanoid"), JumpLaunchCount, JumpTakeoffSpeed,
--   JumpBoostApplied, JumpLeapSpeed, JumpAirSpeed (horizontal, 0.5 steps), JumpPeakHeight (studs above the
--   takeoff point, 0.1 steps), JumpAirTime (s, 0.01 steps), JumpAirHoldState ("off" / "holding" / "released"),
--   JumpAirDistance (horizontal studs from launch to landing, 0.1 steps).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local remote = ReplicatedStorage:WaitForChild("DinoJumpRequest", 10)

local DEFAULTS = {JumpEnabled = false, JumpWindup = 0.12, JumpLaunchPower = 59, JumpBoost = 10,
	JumpBoostMinSpeed = 2, JumpAirHold = true, JumpStaminaCost = 15, JumpCooldown = 0.5,
	StaminaEnabled = true, StaminaMax = 100}
local LIFTOFF_WAIT = 0.3   -- seconds after launch to leave the ground before giving up ("noLiftoff")
local REQUEST_FRESH = 0.1  -- seconds a JumpRequest event counts as "key pressed"
local JUMP_HOLD_ACCEL = 1000 -- studs/s^2 the air-hold constraint may use (force limit = mass x this)
local JUMPING = Enum.HumanoidStateType.Jumping
if script:GetAttribute("JumpSuppressEnabled") == nil then script:SetAttribute("JumpSuppressEnabled", true) end -- v1.3
local SUPPRESS_ON = script:GetAttribute("JumpSuppressEnabled") ~= false
local function suppressed() return SUPPRESS_ON and char:GetAttribute("JumpSuppressed") == true end
char:SetAttribute("JumpTestVersion", "1.3") -- v1.3 (the model data carries "1.0")
char:SetAttribute("JumpTestVersion", "1.5") -- v1.5 (1.4 did not bump this line)
if script:GetAttribute("JumpHopBackEnabled") == nil then script:SetAttribute("JumpHopBackEnabled", true) end -- v1.5
local function hopMode() return script:GetAttribute("JumpHopBackEnabled") ~= false and char:GetAttribute("JumpHopBack") == true end

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

-- jump input: Input Action System JumpAction when present, else Humanoid.Jump / JumpRequest
local jumpAction
do
	local pm = game:GetService("StarterPlayer"):FindFirstChild("PlayerModule")
	local ok, a = pcall(function()
		return pm and pm:WaitForChild("InputContexts", 5):WaitForChild("CharacterContext", 5):WaitForChild("JumpAction", 5)
	end)
	if ok and a and a:IsA("InputAction") then jumpAction = a end
end
show("JumpInputSource", jumpAction and "inputAction" or "humanoid")
local lastRequest = -math.huge
UserInputService.JumpRequest:Connect(function() lastRequest = os.clock() end)

local function jumpHeld()
	if jumpAction then
		local ok, v = pcall(function() return jumpAction:GetState() end)
		if ok and v == true then return true end
	end
	return hum.Jump or os.clock() - lastRequest < REQUEST_FRESH
end

local function staminaNow()
	local max = get("StaminaMax")
	local now = workspace:GetServerTimeNow()
	local value = char:GetAttribute("StaminaValue") or max
	local rate = char:GetAttribute("StaminaRate") or 0
	local at = char:GetAttribute("StaminaAt") or now
	return math.clamp(value + rate * (now - at), 0, max)
end

local function grounded()
	local st = hum:GetState()
	return hum.FloorMaterial ~= Enum.Material.Air and st ~= JUMPING and st ~= Enum.HumanoidStateType.Freefall
end

local state = "ready"
local stamp, crouchAt, launchAt, leftGround
local takeoffY, peakY, leapSpeed = 0, 0, 0
local launchPos -- HumanoidRootPart position at the launch
local airLV -- LinearVelocity holding the leap speed in the air (created on first use)

-- air hold on (with the horizontal target velocity) or off
local function airHold(target)
	if target then
		if not airLV then
			local att = Instance.new("Attachment")
			att.Name = "JumpAirAttachment"
			att.Parent = hrp
			airLV = Instance.new("LinearVelocity")
			airLV.Name = "JumpAirHold"
			airLV.Attachment0 = att
			airLV.RelativeTo = Enum.ActuatorRelativeTo.World
			airLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			airLV.PrimaryTangentAxis = Vector3.new(1, 0, 0)
			airLV.SecondaryTangentAxis = Vector3.new(0, 0, 1)
			airLV.ForceLimitsEnabled = true
			airLV.Enabled = false
			airLV.Parent = hrp
		end
		airLV.MaxForce = hrp.AssemblyMass * JUMP_HOLD_ACCEL
		airLV.PlaneVelocity = Vector2.new(target.X, target.Z)
		airLV.Enabled = true
		show("JumpAirHoldState", "holding")
	elseif airLV and airLV.Enabled then
		airLV.Enabled = false
		show("JumpAirHoldState", "released")
	end
end
local lastLeap = -math.huge
-- v1.4: leap charges
if script:GetAttribute("JumpChargesEnabled") == nil then script:SetAttribute("JumpChargesEnabled", true) end
local CHARGES_ON = script:GetAttribute("JumpChargesEnabled") ~= false
local cState = {max = 0, left = 0, refills = {}}
local function chargeMode() return CHARGES_ON and (tonumber(char:GetAttribute("JumpCharges")) or 0) >= 1 end
local function chargesNow()
	local mx = math.floor(tonumber(char:GetAttribute("JumpCharges")) or 0)
	if mx ~= cState.max then cState = {max = mx, left = mx, refills = {}} end
	local t = os.clock()
	while cState.refills[1] and t >= cState.refills[1] do
		table.remove(cState.refills, 1)
		cState.left = math.min(cState.max, cState.left + 1)
	end
	return cState.left
end
local function useCharge()
	chargesNow()
	cState.left -= 1
	local last = cState.refills[#cState.refills]
	local t = os.clock()
	table.insert(cState.refills, math.max(t, last or t) + math.max(0.5, tonumber(get("JumpCooldown")) or 0.5))
	char:SetAttribute("JumpChargesLocal", cState.left)
end
local enabledApplied -- last JumpEnabled value applied to the Humanoid

local function applyEnabled()
	local on = get("JumpEnabled") == true
	if on == enabledApplied then return end
	local first = enabledApplied == nil
	enabledApplied = on
	if first and not on then
		state = "disabled" -- never enabled: the Humanoid is left exactly as it is
		return
	end
	if on then
		hum:SetStateEnabled(JUMPING, false)
		hum.UseJumpPower = true
		hum.JumpPower = get("JumpLaunchPower")
		state = "ready"
	else
		hum:SetStateEnabled(JUMPING, true)
		state = "disabled"
	end
end

local function tryPress()
	local result
	if hum.Health <= 0 then
		result = "dead"
	elseif suppressed() then -- v1.3
		result = "suppressed"
	elseif not grounded() then
		result = "air"
	elseif char:GetAttribute("Exhausted") == true then
		result = "exhausted"
	elseif get("StaminaEnabled") ~= false and staminaNow() < get("JumpStaminaCost") then
		result = "stamina"
	elseif chargeMode() then -- v1.4
		if chargesNow() < 1 or os.clock() - lastLeap < 0.5 then result = "cooldown" end
	elseif os.clock() - lastLeap < get("JumpCooldown") then
		result = "cooldown"
	end
	if result then
		show("JumpInputResult", result)
		return
	end
	stamp = workspace:GetServerTimeNow()
	crouchAt = os.clock()
	lastLeap = crouchAt
	if chargeMode() then useCharge() end -- v1.4
	state = "crouch"
	char:SetAttribute("JumpPredictedAt", stamp)
	if remote then remote:FireServer(stamp) end
	show("JumpInputResult", "sent")
end

local doubleUsed, wasHeld = false, false -- v1.2: declared before launch() (see header)
local function launch()
	local v = hrp.AssemblyLinearVelocity
	local hv = Vector3.new(v.X, 0, v.Z)
	local takeoff = hv.Magnitude
	local boosted = takeoff > get("JumpBoostMinSpeed")
	if boosted then
		local fwd = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		if fwd.Magnitude > 1e-3 then hv += fwd.Unit * get("JumpBoost") end
	end
	leapSpeed = hv.Magnitude
	local power = get("JumpLaunchPower")
	hum.UseJumpPower = true
	hum.JumpPower = power
	hum:SetStateEnabled(JUMPING, true)
	hum:ChangeState(JUMPING)
	hrp.AssemblyLinearVelocity = Vector3.new(hv.X, power, hv.Z)
	launchAt = os.clock()
	leftGround = false
	takeoffY, peakY = hrp.Position.Y, hrp.Position.Y
	launchPos = hrp.Position
	state = "air"
	doubleUsed = false -- v1.1
	show("JumpDoubleLocal", "ready")
	show("JumpLaunchCount", (char:GetAttribute("JumpLaunchCount") or 0) + 1)
	show("JumpTakeoffSpeed", math.floor(takeoff * 2 + 0.5) / 2)
	show("JumpBoostApplied", boosted)
	show("JumpLeapSpeed", math.floor(leapSpeed * 2 + 0.5) / 2)
end

-- v1.1: Mecha Legs double jump
local doubleRemote
local function doubleJump()
	doubleUsed = true
	local v = hrp.AssemblyLinearVelocity
	local power = get("JumpLaunchPower") * (tonumber(char:GetAttribute("JumpDoubleMul")) or 0.894)
	local fwdAdd = tonumber(char:GetAttribute("JumpDoubleForward")) or 0 -- v1.2
	local hv = Vector3.new(v.X, 0, v.Z)
	local face = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if fwdAdd > 0 and face.Magnitude > 1e-3 then hv += face.Unit * fwdAdd end
	leapSpeed = math.max(leapSpeed, hv.Magnitude) -- v1.2: the air hold keeps the burst while steering
	hrp.AssemblyLinearVelocity = Vector3.new(hv.X, power, hv.Z) -- in the air: the velocity alone (no Jumping state)
	takeoffY = math.min(takeoffY, hrp.Position.Y)
	local s = workspace:GetServerTimeNow()
	char:SetAttribute("JumpDoublePredictedAt", s)
	doubleRemote = doubleRemote or ReplicatedStorage:FindFirstChild("DinoJumpDoubleRequest")
	if doubleRemote then doubleRemote:FireServer(s) end
	show("JumpDoubleLocal", "used")
	show("JumpDoubleLocalCount", (char:GetAttribute("JumpDoubleLocalCount") or 0) + 1)
end

-- v1.5: Evade Hop
local hopping, hopFace, hopUntil, hopYaw0, hopAutoRotate = false, nil, 0, 0, nil
local hopLV
local function hopDrive(v)
	if v then
		if not hopLV then
			local att = Instance.new("Attachment")
			att.Name = "JumpHopAttachment"
			att.Parent = hrp
			hopLV = Instance.new("LinearVelocity")
			hopLV.Name = "JumpHopDrive"
			hopLV.Attachment0 = att
			hopLV.RelativeTo = Enum.ActuatorRelativeTo.World
			hopLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			hopLV.PrimaryTangentAxis = Vector3.new(1, 0, 0)
			hopLV.SecondaryTangentAxis = Vector3.new(0, 0, 1)
			hopLV.ForceLimitsEnabled = true
			hopLV.Enabled = false
			hopLV.Parent = hrp
		end
		hopLV.MaxForce = hrp.AssemblyMass * JUMP_HOLD_ACCEL
		hopLV.PlaneVelocity = Vector2.new(v.X, v.Z)
		hopLV.Enabled = true
	elseif hopLV then
		hopLV.Enabled = false
	end
end
local function yawDeg(lv) return math.deg(math.atan2(-lv.Z, lv.X)) end
local function holdFacing()
	local pos = hrp.Position
	hrp.CFrame = CFrame.lookAt(pos, pos + hopFace)
end
local function launchHop()
	local f = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	hopFace = f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
	hopYaw0 = yawDeg(hopFace)
	local s = 1
	pcall(function() s = char:GetScale() end)
	local T = math.max(0.1, tonumber(char:GetAttribute("JumpHopTime")) or 0.42)
	local speed = math.max(0, tonumber(char:GetAttribute("JumpHopDistance")) or 9) * s / T
	local power = math.max(0, tonumber(char:GetAttribute("JumpHopPower")) or 40)
	hopAutoRotate = hum.AutoRotate
	hum.AutoRotate = false
	local hv = -hopFace * speed
	leapSpeed = speed
	hum.UseJumpPower = true
	hum.JumpPower = power
	hum:SetStateEnabled(JUMPING, true)
	hum:ChangeState(JUMPING)
	hrp.AssemblyLinearVelocity = Vector3.new(hv.X, power, hv.Z)
	hopDrive(hv)
	hopping, hopUntil = true, os.clock() + T
	launchAt = os.clock()
	leftGround = false
	takeoffY, peakY = hrp.Position.Y, hrp.Position.Y
	launchPos = hrp.Position
	state = "air"
	doubleUsed = true -- no double jump during a hop
	show("JumpHopLocal", "hop")
	show("JumpLaunchCount", (char:GetAttribute("JumpLaunchCount") or 0) + 1)
	show("JumpLeapSpeed", math.floor(speed * 2 + 0.5) / 2)
end
local function endHop()
	if not hopping then return end
	hopping = false
	hopDrive(nil)
	if hopAutoRotate ~= nil then hum.AutoRotate = hopAutoRotate end
	hopAutoRotate = nil
	local d = hrp.Position - launchPos
	show("JumpHopMoved", math.floor(Vector3.new(d.X, 0, d.Z).Magnitude * 10 + 0.5) / 10)
	local f = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if f.Magnitude > 1e-3 then
		local drift = (yawDeg(f.Unit) - hopYaw0 + 180) % 360 - 180
		show("JumpHopYawDrift", math.floor(math.abs(drift) * 10 + 0.5) / 10)
	end
	show("JumpHopLocal", "landed")
end

local function land(result)
	endHop() -- v1.5
	hum:SetStateEnabled(JUMPING, false)
	airHold(nil)
	show("JumpAirHoldState", "off")
	state = "ready"
	if result then show("JumpInputResult", result) end
end

local conn = RunService.PreSimulation:Connect(function()
	applyEnabled()
	if not enabledApplied then
		show("JumpTestState", "disabled")
		return
	end
	if hum.Health <= 0 then
		show("JumpTestState", "dead")
		return
	end
	local now = os.clock()
	local held = jumpHeld() -- v1.1: press edge for the double jump
	local pressed = held and not wasHeld
	wasHeld = held
	if state == "air" and leftGround and pressed and not doubleUsed and char:GetAttribute("JumpDoubleEnabled") == true then
		doubleJump()
	end
	if state ~= "ready" and suppressed() then -- v1.3: on a tree: the climb owns the body
		land("suppressed")
	elseif state == "ready" then
		if jumpHeld() then tryPress() end
	elseif state == "crouch" then
		if char:GetAttribute("JumpDeniedAt") == stamp then
			state = "ready"
			if chargeMode() then cState.left = math.floor(tonumber(char:GetAttribute("JumpChargesLeft")) or cState.left) end -- v1.4
			show("JumpInputResult", "denied")
		elseif now - crouchAt >= (hopMode() and (tonumber(char:GetAttribute("JumpHopWindup")) or 0.1) or get("JumpWindup")) then -- v1.5
			if hopMode() then launchHop() else launch() end
		end
	elseif state == "air" then
		if hopping then -- v1.5: facing held, drive for JumpHopTime, then no horizontal push until landing
			holdFacing()
			if os.clock() >= hopUntil and hopLV and hopLV.PlaneVelocity.Magnitude > 0 then hopDrive(Vector3.zero) end
		end
		local y = hrp.Position.Y
		if y > peakY then peakY = y end
		if not leftGround then
			if not grounded() then
				leftGround = true
				hum:SetStateEnabled(JUMPING, false) -- off again: only this one jump
			elseif now - launchAt > LIFTOFF_WAIT then
				land("noLiftoff")
			end
		else
			if grounded() then
				show("JumpAirTime", math.floor((now - launchAt) * 100 + 0.5) / 100)
				show("JumpPeakHeight", math.floor((peakY - takeoffY) * 10 + 0.5) / 10)
				local d = hrp.Position - launchPos
				show("JumpAirDistance", math.floor(Vector3.new(d.X, 0, d.Z).Magnitude * 10 + 0.5) / 10)
				land(nil)
			elseif get("JumpAirHold") and not hopping then -- v1.5: no air-hold steering during a hop
				-- keep the boosted leap speed while steering with input held
				local md = hum.MoveDirection
				local m = md.Magnitude
				if m > 0.05 then
					airHold(md.Unit * (math.max(leapSpeed, hum.WalkSpeed) * math.min(1, m)))
				else
					airHold(nil)
				end
			end
		end
		local v = hrp.AssemblyLinearVelocity
		show("JumpAirSpeed", math.floor(Vector3.new(v.X, 0, v.Z).Magnitude * 2 + 0.5) / 2)
	end
	show("JumpTestState", state)
end)

local function cleanup()
	conn:Disconnect()
	if airLV then airLV.Enabled = false end
	if hopLV then hopLV.Enabled = false end -- v1.5
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
