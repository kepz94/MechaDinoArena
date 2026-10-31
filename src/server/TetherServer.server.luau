-- TetherServer v1.1 (Mecha Dino Arena) — the pachy's Tether Spike, an Engineering slot part (path "tether").
-- MDA-129, mockup docs/mockups/pachy_tether_options.html B "Tail-base launcher". Kepu 2026-10-30: "a tether spike where if
--   it lands it latches the person to a chain to the ground. Makes them not mobile past the chain for a couple seconds"
--   -> "this will not shoot straight like a gun tho. It will launch like a splash. So it will shoot vertical and do a
--   splash area that you're aiming at and if the other Dino gets caught they get hooked to the ground"; answers: hold to
--   aim a landing circle (drag to move it), release fires; 8-stud circle, 60 range; only the closest dino; 10 studs for
--   2.5 s; star yanks them to the spike; only the Energy Shield blocks it.
-- Settings come from the character (SkillEffects 1.25): TetherEnabled (bought AND slotted on a pachy), TetherRange (60),
--   TetherSplash (8), TetherReach (10), TetherTime (2.5; 3.5 from II), TetherCooldown (14; 10 from III), TetherYank +
--   TetherYankReach (star: true / 5), TetherLook.
-- Client -> server: ReplicatedStorage.DinoTetherRequest:FireServer(clientServerTime, landPos) (MechaButtons 1.20, the
--   centre of the landing circle on release). Checks, first failing wins: "badArg" (stamp not a number, landPos not a
--   finite Vector3), "dead", "disabled" (TetherServerEnabled false or TetherEnabled ~= true), "menu", "stunned"
--   (StunnedUntil > now), "pinned" (PinHeld), "cooldown" (now < TetherReadyAt), "ok". Every ok shot starts the cooldown
--   (TetherReadyAt = now + TetherCooldown). landPos is clamped to TetherRange (+ RANGE_SLACK 4) studs flat from the
--   pachy's root, then dropped onto the ground (ray down, characters / bots / tall grass / FX excluded).
-- Flight: a steel spike "TetherSpike" (Workspace.DinoFX.TetherFX, anchored, no collide / query / touch) with a yellow
--   chain Trail leaves the launcher's Muzzle and arcs (peak ARC_HEIGHT 22 studs above the higher end) onto the landing
--   point in FLIGHT (0.8 s), turned along its path. Owner stamps: TetherAimPos (the landing point), TetherLandAt,
--   TetherCount, TetherStartedAt (last).
-- Landing (at TetherLandAt): an impact (dust puffs, a flat yellow ring growing to the circle's size) and the spike stands
--   in the ground. Catch: of the dinos that may be affected (models in Workspace with Hitboxes, Bitable, a Species or
--   IsBot, not the shooter, not KO, alive; ModeRules.canAffect, same as the Shock Cannon / ink: player targets only in the
--   Arena, never a player in the menu) whose nearest hitbox is within TetherSplash studs (flat) of the landing point,
--   the closest is chained; one with EnergyShieldUntil in the future is skipped (owner TetherLastShielded = its name). No
--   one caught = "miss": the spike sinks after 0.6 s.
-- Chain: a RopeConstraint "TetherChain" (visible, yellow, thickness 0.3) from an Attachment in the spike to an Attachment
--   in the target's HumanoidRootPart, Length = sqrt(reach^2 + h^2) (h = the root's height above the spike, so reach is
--   the flat distance they can go). Star: the rope winches in to TetherYankReach at YANK_SPEED (60) studs/s. Target
--   stamps: TetheredUntil (server time), TetheredBy (pachy name), TetherAnchor (spike position), TetherReachNow, TetheredAt
--   (last). Owner: TetherResult ("hit" / "miss" / "shielded"), TetherHitTarget (or ""), TetherHits.
-- End: at TetheredUntil, or when the target dies / leaves -> rope and spike removed (the spike sinks 0.3 s); target
--   TetherEndReason ("time" / "dead" / "gone").
-- Look: while TetherLook is true the pachy carries "Mecha_TetherLauncher" on the Tail1 segment's Root (its box in Root's own
--   frame), on top of the tail base: "Base" (dark), "Barrel" (steel, tilted 35 degrees up, pointing forward over the back)
--   with an Attachment "Muzzle" at its tip, "Drum" (yellow chain drum on the side) and "Tip" (a steel spike head in the
--   barrel's mouth). Massless, no collide / query / touch, no shadow.
-- Lab card (plug and play, LabPreviewServer 1.2): BindableFunction "BuildPreview_tether".
-- Switch: script attribute TetherServerEnabled (default true). Mode rules: script attribute TetherModeRulesEnabled (default
--   true; false = players can always be chained).
-- Diagnostics: script TetherServerVersion, TetherShots, TetherHits, TetherMode; character TetherServerResult,
--   TetherLookBuilt.
-- v1.1 (Kepu 2026-10-30: "It was locking onto the top of trees too and everything"; range 90 from SkillTree 1.35): the
--   landing point's ground ray also skips DinoIsland.Trees, Rocks and EdgeWalls (it already skipped characters, Bots,
--   TallGrass, Prey and the FX folders), so the spike lands on the ground / mountain steps under the circle, never on a
--   treetop. Switch: script attribute TetherGroundOnly (default true, read each shot; false = 1.0).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.1"
local FLIGHT, ARC_HEIGHT, RANGE_SLACK, YANK_SPEED = 0.8, 22, 4, 60
local STEEL, DARK, YELLOW = Color3.fromRGB(154, 166, 184), Color3.fromRGB(58, 64, 76), Color3.fromRGB(255, 200, 50)

script:SetAttribute("TetherServerVersion", VERSION)
script:SetAttribute("TetherShots", 0)
script:SetAttribute("TetherHits", 0)
if script:GetAttribute("TetherServerEnabled") == nil then script:SetAttribute("TetherServerEnabled", true) end
if script:GetAttribute("TetherModeRulesEnabled") == nil then script:SetAttribute("TetherModeRulesEnabled", true) end
if script:GetAttribute("TetherGroundOnly") == nil then script:SetAttribute("TetherGroundOnly", true) end -- v1.1
local function enabled() return script:GetAttribute("TetherServerEnabled") ~= false end

local ModeRules = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TetherMode", MODE)
local function mayAffect(source, target)
	if script:GetAttribute("TetherModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end

local remote = ReplicatedStorage:FindFirstChild("DinoTetherRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoTetherRequest"
	remote.Parent = ReplicatedStorage
end

local function now() return workspace:GetServerTimeNow() end

local function fxFolder()
	local fx = workspace:FindFirstChild("DinoFX")
	if not fx then
		fx = Instance.new("Folder")
		fx.Name = "DinoFX"
		fx.Parent = workspace
	end
	local f = fx:FindFirstChild("TetherFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "TetherFX"
		f.Parent = fx
	end
	return f
end

-- look ---------------------------------------------------------------------------------------------------------------
local function part(name, size, cf, color, parent, mount, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Parent = parent
	if mount then
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = mount, p
		w.Parent = p
	end
	return p
end
local function rootBox(seg, root)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
				local q = root.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz))
				lo, hi = lo:Min(q), hi:Max(q)
			end end end
		end
	end
	if lo.X == math.huge then return nil end
	return lo, hi
end
local function extent(lo, hi, axis)
	local h = (hi - lo) / 2
	return math.abs(axis.X) * h.X + math.abs(axis.Y) * h.Y + math.abs(axis.Z) * h.Z
end
local function axisOf(root, dir)
	local v = root.CFrame:VectorToObjectSpace(dir)
	local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
	if a.X >= a.Y and a.X >= a.Z then return Vector3.new(v.X >= 0 and 1 or -1, 0, 0) end
	if a.Y >= a.Z then return Vector3.new(0, v.Y >= 0 and 1 or -1, 0) end
	return Vector3.new(0, 0, v.Z >= 0 and 1 or -1)
end

local function build(char)
	local seg = char:FindFirstChild("Tail1")
	local root = seg and seg:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then return nil end
	local lo, hi = rootBox(seg, root)
	if not lo then return nil end
	local ref = char:FindFirstChild("HumanoidRootPart") or root
	local x = axisOf(root, ref.CFrame.RightVector)
	local y = axisOf(root, ref.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, ref.CFrame.LookVector):Cross(x) end
	local back = x:Cross(y)
	local Hd = char:GetExtentsSize().Y
	local w, h, d = Hd * 0.09, Hd * 0.06, Hd * 0.13
	-- on top of the tail base, toward the body end (local -back = forward)
	local c = (lo + hi) / 2 + y * (extent(lo, hi, y) + h * 0.5) - back * (extent(lo, hi, back) * 0.35)
	local cf = root.CFrame * CFrame.fromMatrix(c, x, y, back)
	local m = Instance.new("Model")
	m.Name = "Mecha_TetherLauncher"
	local base = part("Base", Vector3.new(w, h, d), cf, DARK, m, root)
	local len = Hd * 0.16
	local bcf = cf * CFrame.new(0, h * 0.35, -d * 0.2) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -len * 0.5)
	local barrel = part("Barrel", Vector3.new(w * 0.4, w * 0.4, len), bcf, STEEL, m, base)
	local mz = Instance.new("Attachment")
	mz.Name = "Muzzle"
	mz.Position = Vector3.new(0, 0, -len * 0.5)
	mz.Parent = barrel
	part("Tip", Vector3.new(w * 0.22, w * 0.22, len * 0.22), bcf * CFrame.new(0, 0, -len * 0.55), STEEL, m, barrel, Enum.Material.DiamondPlate)
	local drum = part("Drum", Vector3.new(w * 0.35, h * 1.1, h * 1.1), cf * CFrame.new(w * 0.62, 0, d * 0.15), YELLOW, m, base)
	drum.Shape = Enum.PartType.Cylinder
	m.Parent = char
	char:SetAttribute("TetherLookBuilt", true)
	return m
end

local function setLook(char)
	local want = enabled() and char:GetAttribute("Species") == "Pachy" and char:GetAttribute("TetherLook") == true
	local old = char:FindFirstChild("Mecha_TetherLauncher")
	if not want then
		if old then old:Destroy() end
		char:SetAttribute("TetherLookBuilt", false)
		return
	end
	if old then return end
	build(char)
end

-- targets / ground ---------------------------------------------------------------------------------------------------
local function closestOnBox(p, pos)
	local lp = p.CFrame:PointToObjectSpace(pos)
	local hh = p.Size / 2
	local c = Vector3.new(math.clamp(lp.X, -hh.X, hh.X), math.clamp(lp.Y, -hh.Y, hh.Y), math.clamp(lp.Z, -hh.Z, hh.Z))
	return p.CFrame:PointToWorldSpace(c)
end
local function isTarget(m, self)
	if not (m:IsA("Model") and m ~= self and m:IsDescendantOf(workspace)) then return nil end
	local hb = m:FindFirstChild("Hitboxes")
	if not hb or m:GetAttribute("Bitable") ~= true then return nil end
	if m:GetAttribute("Species") == nil and m:GetAttribute("IsBot") ~= true then return nil end
	if m:GetAttribute("DummyState") == "ko" then return nil end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return nil end
	return hb
end
local function candidates(self)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c then local hb = isTarget(c, self) if hb and mayAffect(self, c) then table.insert(list, {m = c, hb = hb}) end end
	end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	if bots then
		for _, b in ipairs(bots:GetChildren()) do
			local hb = isTarget(b, self) if hb and mayAffect(self, b) then table.insert(list, {m = b, hb = hb}) end
		end
	end
	return list
end
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function ground(pos)
	local ex = {fxFolder()}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass", "Prey"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	if script:GetAttribute("TetherGroundOnly") ~= false then -- v1.1: no treetops / rocks / edge walls
		for _, n in ipairs({"Trees", "Rocks", "EdgeWalls"}) do
			local f = isl and isl:FindFirstChild(n)
			if f then table.insert(ex, f) end
		end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	groundParams.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -240, 0), groundParams)
	return hit and hit.Position or pos
end
local function muzzleOf(char)
	local m = char:FindFirstChild("Mecha_TetherLauncher")
	local barrel = m and m:FindFirstChild("Barrel")
	local mz = barrel and barrel:FindFirstChild("Muzzle")
	if mz then return mz.WorldPosition end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position + Vector3.new(0, 3, 0)
end

-- effects ------------------------------------------------------------------------------------------------------------
local function newSpike(pos)
	local s = Instance.new("Part")
	s.Name = "TetherSpike"
	s.Size = Vector3.new(0.7, 0.7, 3.2)
	s.CFrame = CFrame.new(pos)
	s.Color = STEEL
	s.Material = Enum.Material.DiamondPlate
	s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = true, false, false, false, false
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA"
	a0.Position = Vector3.new(0.2, 0, 1.4)
	a0.Parent = s
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailB"
	a1.Position = Vector3.new(-0.2, 0, 1.4)
	a1.Parent = s
	local tr = Instance.new("Trail")
	tr.Name = "ChainTrail"
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(YELLOW)
	tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	tr.Lifetime = 0.35
	tr.Parent = s
	s.Parent = fxFolder()
	return s
end
local function impact(pos, size)
	local ring = Instance.new("Part")
	ring.Name = "TetherRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = YELLOW
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Parent = fxFolder()
	TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.2, size * 2, size * 2), Transparency = 1}):Play()
	local a = Instance.new("Attachment")
	a.Parent = ring
	local dust = Instance.new("ParticleEmitter")
	dust.Enabled = false
	dust.Color = ColorSequence.new(Color3.fromRGB(190, 182, 168))
	dust.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.6)})
	dust.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
	dust.Speed = NumberRange.new(8, 16)
	dust.SpreadAngle = Vector2.new(180, 15)
	dust.EmissionDirection = Enum.NormalId.Right -- the ring's local X = world up
	dust.Lifetime = NumberRange.new(0.4, 0.8)
	dust.Drag = 4
	dust.Parent = a
	dust:Emit(26)
	Debris:AddItem(ring, 1)
end
local function sink(spike, t)
	if not spike.Parent then return end
	local tr = spike:FindFirstChild("ChainTrail")
	if tr then tr.Enabled = false end
	TweenService:Create(spike, TweenInfo.new(t), {CFrame = spike.CFrame * CFrame.new(0, 0, 3), Transparency = 1}):Play()
	Debris:AddItem(spike, t + 0.05)
end

local chains = {} -- [target model] = {spike, rope, att, untilT}

local function release(target, reason)
	local c = chains[target]
	if not c then return end
	chains[target] = nil
	if c.rope.Parent then c.rope:Destroy() end
	if c.att.Parent then c.att:Destroy() end
	sink(c.spike, 0.3)
	if target.Parent then
		target:SetAttribute("TetherEndReason", reason)
		if reason ~= "time" then target:SetAttribute("TetheredUntil", now()) end
	end
end

local function chain(char, target, spike, t)
	release(target, "replaced")
	local thrp = target:FindFirstChild("HumanoidRootPart")
	if not thrp then return false end
	local dur = math.max(0.2, tonumber(char:GetAttribute("TetherTime")) or 2.5)
	local reach = math.max(1, tonumber(char:GetAttribute("TetherReach")) or 10)
	local h = math.max(0, thrp.Position.Y - spike.Position.Y)
	local a0 = Instance.new("Attachment")
	a0.Name = "ChainAnchor"
	a0.Position = Vector3.new(0, 0, -1.2)
	a0.Parent = spike
	local a1 = Instance.new("Attachment")
	a1.Name = "TetherChainAttachment"
	a1.Parent = thrp
	local rope = Instance.new("RopeConstraint")
	rope.Name = "TetherChain"
	rope.Attachment0, rope.Attachment1 = a0, a1
	rope.Length = math.sqrt(reach * reach + h * h)
	rope.Visible = true
	rope.Color = BrickColor.new("Bright yellow")
	rope.Thickness = 0.3
	if char:GetAttribute("TetherYank") == true then -- star
		local yr = math.max(1, tonumber(char:GetAttribute("TetherYankReach")) or 5)
		local cur = (thrp.Position - spike.Position).Magnitude
		rope.Length = math.max(rope.Length, cur + 0.5)
		rope.WinchEnabled = true
		rope.WinchTarget = math.sqrt(yr * yr + h * h)
		rope.WinchSpeed = YANK_SPEED
		rope.WinchForce = 1e7
		rope.WinchResponsiveness = 60
		reach = yr
	end
	rope.Parent = spike
	chains[target] = {spike = spike, rope = rope, att = a1, untilT = t + dur}
	target:SetAttribute("TetheredUntil", t + dur)
	target:SetAttribute("TetheredBy", char.Name)
	target:SetAttribute("TetherAnchor", spike.Position)
	target:SetAttribute("TetherReachNow", reach)
	target:SetAttribute("TetheredAt", t) -- last
	return true
end

local function land(char, spike, landPos)
	local t = now()
	spike.CFrame = CFrame.lookAt(landPos + Vector3.new(0, 1.2, 0), landPos - Vector3.new(0, 5, 0))
	local tr = spike:FindFirstChild("ChainTrail")
	if tr then tr.Enabled = false end
	local splash = math.max(1, tonumber(char:GetAttribute("TetherSplash")) or 8)
	impact(landPos, splash)
	local best, bestD, shielded
	for _, c in ipairs(candidates(char)) do
		local near = math.huge
		for _, p in ipairs(c.hb:GetChildren()) do
			if p:IsA("BasePart") then
				local q = closestOnBox(p, landPos)
				near = math.min(near, Vector3.new(q.X - landPos.X, 0, q.Z - landPos.Z).Magnitude)
			end
		end
		if near <= splash then
			if (tonumber(c.m:GetAttribute("EnergyShieldUntil")) or 0) > t then
				shielded = c.m
			elseif not bestD or near < bestD then
				best, bestD = c.m, near
			end
		end
	end
	local result = "miss"
	if best and chain(char, best, spike, t) then
		result = "hit"
		script:SetAttribute("TetherHits", (script:GetAttribute("TetherHits") or 0) + 1)
		if char.Parent then char:SetAttribute("TetherHits", (char:GetAttribute("TetherHits") or 0) + 1) end
	elseif shielded then
		result = "shielded"
	end
	if char.Parent then
		char:SetAttribute("TetherResult", result)
		char:SetAttribute("TetherHitTarget", result == "hit" and best.Name or "")
		if shielded then char:SetAttribute("TetherLastShielded", shielded.Name) end
	end
	if result ~= "hit" then task.delay(0.6, function() sink(spike, 0.3) end) end
end

local function setResult(char, r)
	char:SetAttribute("TetherServerResult", r)
	char:SetAttribute("TetherServerResultAt", now())
end

local function finite(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

remote.OnServerEvent:Connect(function(player, stamp, landPos)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp or not finite(landPos) then
		r = "badArg"
	elseif not hum or hum.Health <= 0 or not hrp then
		r = "dead"
	elseif not enabled() or char:GetAttribute("TetherEnabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif t < (tonumber(char:GetAttribute("TetherReadyAt")) or 0) then
		r = "cooldown"
	end
	if r then setResult(char, r) return end
	setResult(char, "ok")
	setLook(char)
	-- clamp to range, then onto the ground
	local range = (tonumber(char:GetAttribute("TetherRange")) or 60) + RANGE_SLACK
	local flat = Vector3.new(landPos.X - hrp.Position.X, 0, landPos.Z - hrp.Position.Z)
	if flat.Magnitude > range then flat = flat.Unit * range end
	local target = ground(Vector3.new(hrp.Position.X + flat.X, landPos.Y, hrp.Position.Z + flat.Z))
	local from = muzzleOf(char) or hrp.Position
	char:SetAttribute("TetherReadyAt", t + math.max(0.5, tonumber(char:GetAttribute("TetherCooldown")) or 14))
	char:SetAttribute("TetherAimPos", target)
	char:SetAttribute("TetherLandAt", t + FLIGHT)
	char:SetAttribute("TetherCount", (char:GetAttribute("TetherCount") or 0) + 1)
	char:SetAttribute("TetherStartedAt", t) -- last
	script:SetAttribute("TetherShots", (script:GetAttribute("TetherShots") or 0) + 1)
	-- the lob: a parabola from the muzzle to the landing point
	local spike = newSpike(from)
	local peak = math.max(from.Y, target.Y) + ARC_HEIGHT
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local u = math.clamp((os.clock() - t0) / FLIGHT, 0, 1)
		if not spike.Parent then conn:Disconnect() return end
		local function at(k)
			local p = from:Lerp(target, k)
			local base = from.Y + (target.Y - from.Y) * k
			local y = base + 4 * (peak - math.max(from.Y, target.Y)) * k * (1 - k)
			return Vector3.new(p.X, y, p.Z)
		end
		local p = at(u)
		local ahead = at(math.min(1, u + 0.02))
		if (ahead - p).Magnitude > 1e-3 then spike.CFrame = CFrame.lookAt(p, ahead) else spike.CFrame = CFrame.new(p) end
		if u >= 1 then
			conn:Disconnect()
			land(char, spike, target)
		end
	end)
end)

RunService.Heartbeat:Connect(function()
	local t = now()
	for target, c in pairs(chains) do
		local hum = target.Parent and target:FindFirstChildOfClass("Humanoid")
		if not target.Parent or not c.spike.Parent then
			release(target, "gone")
		elseif (hum and hum.Health <= 0) or target:GetAttribute("DummyState") == "ko" then
			release(target, "dead")
		elseif t >= c.untilT then
			release(target, "time")
		end
	end
end)

local function onCharacter(char)
	char:GetAttributeChangedSignal("TetherLook"):Connect(function() setLook(char) end)
	char:GetAttributeChangedSignal("Species"):Connect(function() setLook(char) end)
	task.defer(setLook, char)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- the Lab card model (plug and play: LabPreviewServer 1.2 finds BuildPreview_<pathId>)
do
	local fn = Instance.new("BindableFunction")
	fn.Name = "BuildPreview_tether"
	fn.OnInvoke = function(model)
		if not enabled() or typeof(model) ~= "Instance" then return nil end
		return build(model)
	end
	fn.Parent = script
end
