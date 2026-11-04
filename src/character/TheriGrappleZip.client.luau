-- TheriGrappleZip v1.1 (Mecha Dino Arena) — flies the owner's own therizino to its Grapple Zip anchor (owner's client).
-- MDA-247, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7; server TheriMovesServer 1.2 (pattern: HookPull 1.0).
-- TheriMovesServer stamps the character: TheriGrappleTo (where to stop), TheriGrappleTime (s), TheriGrappleResult "zip",
--   TheriGrappleAt (server time, set last). A fresh stamp (younger than FRESH (1) s) drives the root for TheriGrappleTime s
--   with a LinearVelocity (3D, gravity overridden) toward TheriGrappleTo (speed = distance left / time left, at most
--   MAX_SPEED 220), then lets go with the last velocity x KEEP (0.25). Stops early when within ARRIVE (2) studs, dead or
--   stunned.
-- Switch: character attribute TheriGrappleZipEnabled (default true; false = not moved). Diagnostics (character, this client):
--   TheriGrappleZipVersion, TheriGrappleZipState ("idle" / "zip"), TheriGrappleZipMoved (studs).
-- v1.1 (Kepu 2026-11-04 Grapple-A "Always pulls", mockup docs/mockups/therizino_grapple_overclock_v0.1.html; plan
--   docs/plans/THERIZINO_GRAPPLE_CLOCK_v1.0.md, MDA-255 / MDA-256; TheriMovesServer 1.3):
--   * After the zip the body keeps KEEP_V2 (0.6) of its velocity (character attribute TheriGrappleZipV2Enabled, default true;
--     false = KEEP 0.25).
--   * The latch marker: while TheriGrappleEnabled (bought + slotted), alive, not zipping and not in a menu, every frame the
--     server's ray (root + 2 x scale up, along the camera look, TheriGrappleRange studs, the same filter: player characters,
--     DinoIsland.Bots / TallGrass, DinoFX_Local / DinoFX / TenoFX ignored). A surface at least MIN_D (6) studs away -> a solid
--     yellow ring with a dot on it; nothing hit and the character's TheriGrappleAirLatch true -> a hollow ring at full range;
--     otherwise no marker. No charge left (TheriGrappleLeft 0) -> half see-through. A BillboardGui (always on top, fixed
--     screen size) on an anchored, invisible part in Workspace.DinoFX_Local (this client only). Switch: character attribute
--     TheriGrappleMarkerEnabled (default true). Diagnostics: TheriGrappleMarkerState ("off" / "surface" / "air" / "none").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 keeps 60% speed, latch marker
local FRESH, MAX_SPEED, ARRIVE, KEEP = 1, 220, 2, 0.25
local ACCEL = 20000
local KEEP_V2, MIN_D = 0.6, 6 -- v1.1

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
				hrp.AssemblyLinearVelocity = last * (char:GetAttribute("TheriGrappleZipV2Enabled") ~= false and KEEP_V2 or KEEP) -- v1.1
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

-- v1.1: the latch marker (see the header) -------------------------------------------------------------------------------------
local YELLOW = Color3.fromRGB(255, 194, 26)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local function filter()
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rp.FilterDescendantsInstances = ex
	return rp
end
local mk -- {part, gui, ring, stroke, dot}
local function marker()
	if mk and mk.part.Parent then return mk end
	local root = workspace:FindFirstChild("DinoFX_Local")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX_Local"
		root.Parent = workspace
	end
	local p = Instance.new("Part")
	p.Name = "TheriGrappleMarker"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	local g = Instance.new("BillboardGui")
	g.Name = "Marker"
	g.AlwaysOnTop = true
	g.Size = UDim2.fromOffset(46, 46)
	g.LightInfluence = 0
	g.Adornee = p
	g.Parent = p
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.78, 0.78)
	ring.BackgroundTransparency = 1
	ring.Parent = g
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.5, 0)
	rc.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = YELLOW, 3
	stroke.Parent = ring
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.26, 0.26)
	dot.BackgroundColor3 = YELLOW
	dot.BorderSizePixel = 0
	dot.Parent = g
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(0.5, 0)
	dc.Parent = dot
	p.Parent = root
	mk = {part = p, gui = g, ring = ring, stroke = stroke, dot = dot}
	return mk
end
local lastState
local function state(v)
	if v ~= lastState then lastState = v; char:SetAttribute("TheriGrappleMarkerState", v) end
end
local player = Players.LocalPlayer
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local range = tonumber(char:GetAttribute("TheriGrappleRange")) or 0
	local on = char:GetAttribute("TheriGrappleMarkerEnabled") ~= false and char:GetAttribute("TheriGrappleEnabled") == true
		and range > 0 and hum.Health > 0 and hrp.Parent ~= nil and cam ~= nil and player:GetAttribute("InMenu") ~= true
		and char:GetAttribute("TheriGrappleZipState") ~= "zip"
	if not on then
		if mk then mk.gui.Enabled = false end
		state("off")
		return
	end
	local s = char:GetScale()
	local from = hrp.Position + Vector3.new(0, 2 * s, 0)
	local dir = cam.CFrame.LookVector
	local hit = workspace:Raycast(from, dir * range, filter())
	local m = marker()
	local at, solid
	if hit and (hit.Position - from).Magnitude >= MIN_D then
		at, solid = hit.Position, true
	elseif not hit and char:GetAttribute("TheriGrappleAirLatch") == true then
		at, solid = from + dir * range, false
	end
	if not at then
		m.gui.Enabled = false
		state("none")
		return
	end
	m.part.CFrame = CFrame.new(at)
	m.gui.Enabled = true
	m.dot.Visible = solid
	local k = 1 + 0.12 * math.sin(os.clock() * 6)
	m.ring.Size = UDim2.fromScale(0.78 * k, 0.78 * k)
	local empty = (tonumber(char:GetAttribute("TheriGrappleLeft")) or 1) <= 0
	m.stroke.Transparency = empty and 0.5 or 0
	m.dot.BackgroundTransparency = empty and 0.5 or 0
	state(solid and "surface" or "air")
end)
char.AncestryChanged:Connect(function() if not char.Parent and mk then mk.part:Destroy() end end)
