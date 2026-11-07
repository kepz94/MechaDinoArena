-- GliderTest v1.1 (Mecha Dino Arena) — the Herrera's Glider Wings glide on the owner's client (LocalScript in
-- StarterCharacterScripts). MDA-150, plan docs/plans/HERRERA_PARTS_v1.0.md Part 2 (Kepu 2026-10-31 "Glide strike", look A
-- "Bat Membranes") and "Pass 2 — build map".
-- Runs only while the character attribute GliderEnabled is true (SkillEffects 1.27: Glider Wings bought AND slotted).
-- Glide starts when all hold: JUMP held (JumpTest's input: the Input Action System JumpAction, else Humanoid.Jump /
--   a JumpRequest in the last 0.1 s), airborne (FloorMaterial Air or state Freefall / Jumping), falling (vertical speed
--   < -1), not on a tree (ClimbLocalState not "climbing" / "clinging" / "top"), not in a slash dash (SlashLocalState
--   ~= "dash"), not stunned (StunnedUntil), not pinned (PinHeld), alive.
-- While gliding:
--   * fall: a LinearVelocity "GlideFall" (Line mode, world Y, -GliderFall studs/s, force limit mass x 2 x gravity) is on
--     whenever the vertical speed is at or below -GliderFall + 0.5, so the fall never gets faster than GliderFall (8);
--   * forward: with no stick input a LinearVelocity "GlideForward" (Plane mode, world X/Z) holds the facing direction x
--     the current Humanoid.WalkSpeed (the run speed after Iron Claw / Frenzy multipliers); with stick input it is off and
--     JumpTest's air hold / Roblox air control steer as usual.
-- Glide ends on landing, a trunk grab, JUMP released, a slash dash, a stun / pin, death or the part going off.
-- Each start / end sets the local attribute GlideLocal and fires ReplicatedStorage.DinoGlideRequest:FireServer(on)
--   (HerreraMovesServer 1.0 sets the replicated Gliding: the wings open, SlashServer 1.5 takes a dive while gliding).
-- Switch: script attribute GliderTestEnabled (default true, read each frame; false = no glide).
-- Diagnostics (character, this client): GliderTestVersion, GlideLocal, GlideLocalReason ("start" / "landed" / "tree" /
--   "released" / "slash" / "stunned" / "off" / "dead"), GlideCount, GlideFallSpeed (last vertical speed while gliding).
-- v1.1 (Troodon Flap & Glide, MDA-341, plan docs/plans/TROODON_FLAP_GLIDE_v1.0.md Task 2; Kepu 2026-11-06 17:38 "Glides by
--   itself after the 3rd flap"): auto mode while the character attribute GliderAuto is true (only TroodonModelData 1.3 sets
--   it) and the script attribute GliderAutoEnabled ~= false (default true, read each frame; false = 1.0's held mode for it):
--   * no held start: the glide is armed when JumpTest 1.6's JumpAirJumpsLocal reaches JumpAirJumps (the last air jump of this
--     leap) and starts at the top of that jump (airborne and vertical speed <= 0), JUMP held or not (reason "auto");
--   * it ends only on landing, a stun / pin, death, a tree / slash or the part going off (never on JUMP released);
--   * landing before the last air jump (or a fall without a leap) disarms it: no glide;
--   * forward with no stick input: the run speed (character MoveRunSpeed, the scaled run WalkSpeed; at least the current
--     Humanoid.WalkSpeed), so a glide from a standing leap still goes forward at run speed; fall / steering as 1.0.
--   The Herrera (no GliderAuto) keeps the 1.0 held mode exactly. Diagnostics: GliderAutoState ("off" / "armed" / "gliding"),
--   GlideForwardSpeed (the speed the forward hold uses).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.1"
local REQUEST_FRESH = 0.1
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
char:SetAttribute("GliderTestVersion", VERSION)
if script:GetAttribute("GliderTestEnabled") == nil then script:SetAttribute("GliderTestEnabled", true) end
if script:GetAttribute("GliderAutoEnabled") == nil then script:SetAttribute("GliderAutoEnabled", true) end -- v1.1
local function autoMode() -- v1.1
	return script:GetAttribute("GliderAutoEnabled") ~= false and char:GetAttribute("GliderAuto") == true
end
local armed, armedAt = false, 0 -- v1.1: the last air jump of this leap was used
local function airJumpLimit() return math.max(1, math.floor(tonumber(char:GetAttribute("JumpAirJumps")) or 1)) end
char:GetAttributeChangedSignal("JumpAirJumpsLocal"):Connect(function() -- v1.1 (JumpTest 1.6)
	local n = tonumber(char:GetAttribute("JumpAirJumpsLocal")) or 0
	if n >= airJumpLimit() then armed, armedAt = true, os.clock() elseif n == 0 then armed = false end
end)
local remote = ReplicatedStorage:WaitForChild("DinoGlideRequest", 20)

-- jump input (JumpTest 1.3's rule)
local jumpAction
task.spawn(function()
	local pm = game:GetService("StarterPlayer"):FindFirstChild("PlayerModule")
	local ok, a = pcall(function()
		return pm and pm:WaitForChild("InputContexts", 5):WaitForChild("CharacterContext", 5):WaitForChild("JumpAction", 5)
	end)
	if ok and a and a:IsA("InputAction") then jumpAction = a end
end)
local lastRequest = -math.huge
UserInputService.JumpRequest:Connect(function() lastRequest = os.clock() end)
local function jumpHeld()
	if jumpAction then
		local ok, v = pcall(function() return jumpAction:GetState() end)
		if ok and v == true then return true end
	end
	return hum.Jump or os.clock() - lastRequest < REQUEST_FRESH
end

local att = Instance.new("Attachment")
att.Name = "GlideAttachment"
att.Parent = hrp
local fallLV = Instance.new("LinearVelocity")
fallLV.Name = "GlideFall"
fallLV.Attachment0 = att
fallLV.RelativeTo = Enum.ActuatorRelativeTo.World
fallLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
fallLV.LineDirection = Vector3.new(0, 1, 0)
fallLV.ForceLimitsEnabled = true
fallLV.Enabled = false
fallLV.Parent = hrp
local fwdLV = Instance.new("LinearVelocity")
fwdLV.Name = "GlideForward"
fwdLV.Attachment0 = att
fwdLV.RelativeTo = Enum.ActuatorRelativeTo.World
fwdLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
fwdLV.PrimaryTangentAxis = Vector3.new(1, 0, 0)
fwdLV.SecondaryTangentAxis = Vector3.new(0, 0, 1)
fwdLV.ForceLimitsEnabled = true
fwdLV.Enabled = false
fwdLV.Parent = hrp

local gliding = false
local function airborne()
	local st = hum:GetState()
	return hum.FloorMaterial == Enum.Material.Air or st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
end
local function onTree()
	local cs = char:GetAttribute("ClimbLocalState")
	return cs == "climbing" or cs == "clinging" or cs == "top"
end
local function blocked(t)
	if hum.Health <= 0 then return "dead" end
	if script:GetAttribute("GliderTestEnabled") == false or char:GetAttribute("GliderEnabled") ~= true then return "off" end
	if onTree() then return "tree" end
	if char:GetAttribute("SlashLocalState") == "dash" then return "slash" end
	if (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t or char:GetAttribute("PinHeld") == true then return "stunned" end
	return nil
end
local function set(v, reason)
	char:SetAttribute("GlideLocalReason", reason)
	if gliding == v then return end
	gliding = v
	char:SetAttribute("GlideLocal", v)
	if v then char:SetAttribute("GlideCount", (char:GetAttribute("GlideCount") or 0) + 1) end
	if not v then
		fallLV.Enabled = false
		fwdLV.Enabled = false
	end
	if remote then remote:FireServer(v) end
end
char:SetAttribute("GlideLocal", false)

local conn = RunService.PreSimulation:Connect(function()
	local t = workspace:GetServerTimeNow()
	local why = blocked(t)
	local vy = hrp.AssemblyLinearVelocity.Y
	local auto = autoMode() -- v1.1
	if auto and armed and not gliding and not airborne() and os.clock() - armedAt > 0.15 then armed = false end -- landed first
	if gliding then
		if why then set(false, why)
		elseif not airborne() then set(false, "landed")
		elseif not auto and not jumpHeld() then set(false, "released") end -- v1.1: auto mode never ends on release
	elseif auto then -- v1.1: no held start; the glide starts at the top of the last air jump
		if armed and not why and airborne() and vy <= 0 then
			armed = false
			set(true, "auto")
		end
	elseif not why and jumpHeld() and airborne() and vy < -1 then
		set(true, "start")
	end
	if auto then char:SetAttribute("GliderAutoState", gliding and "gliding" or (armed and "armed" or "off")) end -- v1.1
	if not gliding then return end
	local fall = math.max(1, tonumber(char:GetAttribute("GliderFall")) or 8)
	local mass = hrp.AssemblyMass
	if vy <= -fall + 0.5 then
		fallLV.MaxForce = mass * workspace.Gravity * 2
		fallLV.LineVelocity = -fall
		fallLV.Enabled = true
	else
		fallLV.Enabled = false
	end
	local md = hum.MoveDirection
	if md.Magnitude < 0.05 then
		local look = hrp.CFrame.LookVector
		local f = Vector3.new(look.X, 0, look.Z)
		f = f.Magnitude > 1e-3 and f.Unit or Vector3.zAxis
		local speed = hum.WalkSpeed
		if auto then speed = math.max(speed, tonumber(char:GetAttribute("MoveRunSpeed")) or 0) end -- v1.1: run speed
		char:SetAttribute("GlideForwardSpeed", math.floor(speed * 10 + 0.5) / 10)
		local v = f * speed
		fwdLV.MaxForce = mass * 400
		fwdLV.PlaneVelocity = Vector2.new(v.X, v.Z)
		fwdLV.Enabled = true
	else
		fwdLV.Enabled = false
	end
	char:SetAttribute("GlideFallSpeed", math.floor(-vy * 10 + 0.5) / 10)
end)

local function cleanup()
	conn:Disconnect()
	if gliding then set(false, "dead") end
	fallLV.Enabled, fwdLV.Enabled = false, false
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
