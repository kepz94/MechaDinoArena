-- LabClipPlayer v1.0 (Mecha Dino Arena) — plays a mecha part's looping 3D clip inside the Lab's detail panel (ModuleScript,
-- StarterPlayerScripts, next to Lab; plan docs/plans/LAB_CLIPS_v1.0.md Task 3, MDA-443; mockup
-- docs/mockups/lab_part_preview_v0.1.html option A; Kepu 2026-11-11 "A · Live clip", "Built in the game").
-- API (client only):
--   M.new(recipe, opts) -> clip    recipe = LabClipRecipes[id]; opts = {id, step (1..4), character (Model or nil),
--                                  color (Color3: the part's area colour), visible (optional function -> bool)}
--   clip.view                      the ViewportFrame (size 1,1; the caller parents it into its box)
--   clip:setStep(n)                rebuilds the effects for step n (the dino stays)
--   clip:count()                   BaseParts in the scene (diagnostic)
--   clip:destroy()                 disconnects and destroys everything (0 left)
-- Scene (one WorldModel in the ViewportFrame): a dark pad with a faint grid, a copy of your dino (made like Lab's stage copy:
--   scripts / sounds / billboards / particles / beams / trails / force fields / Hitboxes removed, every part anchored),
--   facing -Z with its feet at y 0; the part's ReplicatedStorage.LabPreviews.<id> model is placed at recipe.attach x the
--   dino's scale when your dino doesn't wear "DPart_<id>"; grey practice dummies (3 x 6 x 3). The dino moves as a whole (its
--   IdleAnimation can't run in a ViewportFrame). Effects are anchored Neon parts (ViewportFrames draw no particles / beams);
--   numbers and words ("-3", "SILENCED 1.5 s") are TextLabels on a layer over the view, placed by projecting their 3D point
--   with the clip camera (FOV 40). Templates: burst, lob, cone, ring, self (pump / over), dash (see the plan's Rules).
-- Loop: each template has its own length (2.6–5 s); the last 0.3 s fades to dark and the clip restarts. Runs on
--   RenderStepped only while the view is parented, has a size, its ScreenGui is enabled and opts.visible() (if given) is true.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = {}
M.VERSION = "1.0"

local BG = Color3.fromRGB(11, 14, 20)
local PAD = Color3.fromRGB(22, 26, 36)
local GRID = Color3.fromRGB(127, 233, 255)
local DUMMY = Color3.fromRGB(200, 204, 214)
local VENOM = Color3.fromRGB(95, 209, 106)
local VENOM_L = Color3.fromRGB(156, 240, 90)
local VOLT = Color3.fromRGB(127, 233, 255)
local RED = Color3.fromRGB(255, 107, 94)
local YELLOW = Color3.fromRGB(255, 200, 50)
local WHITE = Color3.new(1, 1, 1)
local PURPLE = Color3.fromRGB(184, 166, 255)
local TRAIL = Color3.fromRGB(255, 226, 138)
local FADE = 0.3
-- camera framing (fractions of the scene size V; tuned 2026-11-11 in Studio): position = centre + (side, up x V + H x upH,
-- back x V + L x backL), looking at centre
M.CAM = {side = 0.55, up = 0.85, upH = 0.6, back = 0.72, backL = 0.9, minL = 1.8} -- minL: V >= the dino length x minL

local function ease(x) x = math.clamp(x, 0, 1) return 1 - (1 - x) ^ 3 end
local function F(x, f, y) return Vector3.new(x, y or 0, -f) end -- right, forward, up (the dino faces -Z)
local function dirOf(a) return Vector3.new(math.sin(a), 0, -math.cos(a)) end -- a = radians right of forward

local function part(parent, size, cf, color, transp, shape, mat)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = mat or Enum.Material.Neon
	if shape then p.Shape = shape end
	p.Size, p.CFrame, p.Color, p.Transparency = size, cf, color, transp or 0
	p.Parent = parent
	return p
end
local function ball(parent, d, pos, color, transp)
	return part(parent, Vector3.new(d, d, d), CFrame.new(pos), color, transp, Enum.PartType.Ball)
end
local function disc(parent, d, pos, color, transp) -- flat cylinder, axis up
	return part(parent, Vector3.new(0.3, d, d), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, transp, Enum.PartType.Cylinder)
end
local function strip(p, a, b, width, height) -- a flat bar from a to b
	local v = b - a
	local len = v.Magnitude
	if len < 0.05 then p.Transparency = 1 return end
	p.Size = Vector3.new(width, height or 0.1, len)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
end

local function cleanCopy(c)
	if not c then return nil end
	local was = c.Archivable
	c.Archivable = true
	local ok, copy = pcall(function() return c:Clone() end)
	c.Archivable = was
	if not ok or not copy then return nil end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter")
			or d:IsA("Beam") or d:IsA("Trail") or d:IsA("ForceField") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	local hb = copy:FindFirstChild("Hitboxes")
	if hb then hb:Destroy() end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	return copy
end

local Clip = {}
Clip.__index = Clip

function M.new(recipe, opts)
	opts = opts or {}
	local self = setmetatable({}, Clip)
	self.recipe, self.id, self.color, self.visibleFn = recipe, opts.id, opts.color or VOLT, opts.visible
	self.t, self.lastT, self.loop, self.alive = 0, 0, 3, true
	local vf = Instance.new("ViewportFrame")
	vf.Name = "ClipView"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundColor3, vf.BackgroundTransparency, vf.BorderSizePixel = BG, 0, 0
	vf.Ambient = Color3.fromRGB(150, 150, 160)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-0.4, -1, -0.6)
	self.view = vf
	local wm = Instance.new("WorldModel")
	wm.Parent = vf
	self.world = wm
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vf
	vf.CurrentCamera = cam
	self.cam = cam
	local layer = Instance.new("Frame")
	layer.Name = "Pops"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 2
	layer.Parent = vf
	self.layer = layer
	local fader = Instance.new("Frame")
	fader.Name = "Fade"
	fader.BackgroundColor3, fader.BackgroundTransparency, fader.BorderSizePixel = BG, 1, 0
	fader.Size = UDim2.fromScale(1, 1)
	fader.ZIndex = 4
	fader.Parent = vf
	self.fader = fader
	self.pops = {}
	self:_buildRig(opts.character)
	self:setStep(opts.step or 1)
	self.conn = RunService.RenderStepped:Connect(function(dt) self:_tick(dt) end)
	return self
end

-- ---------- the dino ----------
function Clip:_buildRig(char)
	local rig = Instance.new("Model")
	rig.Name = "Rig"
	local copy = cleanCopy(char)
	local scale, hrpY, size = 1, 3, Vector3.new(3, 6, 12)
	if copy then
		local hrp = copy:FindFirstChild("HumanoidRootPart")
		local base = hrp and hrp.CFrame or copy:GetPivot()
		local flat = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
		if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
		local hrpFlat = CFrame.lookAt(base.Position, base.Position + flat.Unit)
		copy:PivotTo(hrpFlat:Inverse() * copy:GetPivot()) -- the HRP at the origin, facing -Z
		local cf, sz = copy:GetBoundingBox()
		local bottom = cf.Position.Y - sz.Y / 2
		copy:PivotTo(CFrame.new(0, -bottom, 0) * copy:GetPivot())
		hrpY, size = -bottom, sz
		local ok, s = pcall(function() return copy:GetScale() end)
		scale = ok and tonumber(s) or 1
		copy.Parent = rig
	else -- no character (respawning): a plain stand-in body
		part(rig, Vector3.new(3, 4, 11), CFrame.new(0, 3, 0), Color3.fromRGB(80, 120, 90), 0, nil, Enum.Material.SmoothPlastic)
		part(rig, Vector3.new(2.2, 2.2, 3), CFrame.new(0, 6, -5), Color3.fromRGB(100, 150, 110), 0, nil, Enum.Material.SmoothPlastic)
	end
	self.scale, self.hrpY, self.size = scale, hrpY, size
	-- the part itself, when your dino doesn't wear it
	local id = self.id
	if id and self.recipe and typeof(self.recipe.attach) == "Vector3" and not (copy and copy:FindFirstChild("DPart_" .. id, true)) then
		local lp = ReplicatedStorage:FindFirstChild("LabPreviews")
		local src = lp and lp:FindFirstChild(id)
		if src then
			local pv = src:Clone()
			for _, d in ipairs(pv:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
			end
			if math.abs(scale - 1) > 1e-3 then pcall(function() pv:ScaleTo(pv:GetScale() * scale) end) end
			local pcf = pv:GetBoundingBox()
			local want = Vector3.new(0, hrpY, 0) + self.recipe.attach * scale
			pv:PivotTo(pv:GetPivot() + (want - pcf.Position))
			pv.Name = "Part_" .. id
			pv.Parent = rig
			self.addedPart = true
		end
	end
	rig.WorldPivot = CFrame.new()
	rig.Parent = self.world
	self.rig = rig
	self.rigCF = CFrame.new()
end
function Clip:_place(cf)
	if cf ~= self.rigCF then
		self.rigCF = cf
		self.rig:PivotTo(cf)
	end
end
function Clip:_local(v) -- a point in the dino's rest space (recipe units) -> world, with the rig where it is now
	return self.rigCF * (Vector3.new(0, self.hrpY, 0) + v * self.scale)
end
function Clip:_muzzle()
	local r = self.recipe
	local v = (r and (r.muzzle or r.attach)) or Vector3.new(0, 2, -3)
	return self:_local(v)
end

-- ---------- stage, camera, text ----------
function Clip:_stage(V, centre)
	if self.stage then self.stage:Destroy() end
	local st = Instance.new("Folder")
	st.Name = "Stage"
	local L = math.max(self.size.Z, 8)
	V = math.max(V, L * M.CAM.minL) -- big dinos: keep the whole dino and the targets in view
	local zFront, zBack = centre.Z - V * 0.9, centre.Z + V * 0.6 + L
	local w = V * 2.2
	part(st, Vector3.new(w, 0.4, zBack - zFront), CFrame.new(centre.X, -0.2, (zFront + zBack) / 2), PAD, 0, nil, Enum.Material.SmoothPlastic)
	local g = V <= 50 and 8 or (V <= 100 and 16 or 24)
	local n = 0
	for x = -math.floor(w / 2 / g) * g, w / 2, g do
		n += 1
		if n > 30 then break end
		part(st, Vector3.new(0.12, 0.04, zBack - zFront), CFrame.new(centre.X + x, 0.02, (zFront + zBack) / 2), GRID, 0.9)
	end
	for z = zBack - g / 2, zFront, -g do
		n += 1
		if n > 60 then break end
		part(st, Vector3.new(w, 0.04, 0.12), CFrame.new(centre.X, 0.02, z), GRID, 0.9)
	end
	st.Parent = self.world
	self.stage = st
	-- camera: behind, above and a little to the right of the dino, looking ahead at `centre`
	local H, Ld = math.max(self.size.Y, 4), math.max(self.size.Z, 8)
	local C = M.CAM
	local pos = centre + Vector3.new(V * C.side, V * C.up + H * C.upH, V * C.back + Ld * C.backL)
	self.cam.CFrame = CFrame.lookAt(pos, centre)
end
function Clip:_project(p)
	local q = self.cam.CFrame:PointToObjectSpace(p)
	if q.Z > -0.1 then return nil end
	local sz = self.view.AbsoluteSize
	if sz.X < 1 or sz.Y < 1 then return nil end
	local tv = math.tan(math.rad(self.cam.FieldOfView / 2))
	return Vector2.new(0.5 + (q.X / -q.Z) / (2 * tv * sz.X / sz.Y), 0.5 - (q.Y / -q.Z) / (2 * tv))
end
function Clip:_pop(text, color, pos, life)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = color
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.35
	l.TextSize = math.clamp(math.floor(self.view.AbsoluteSize.Y * 0.075), 9, 18)
	l.Text = text
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.Size = UDim2.fromOffset(10, 10)
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.ZIndex = 3
	l.Visible = false
	l.Parent = self.layer
	table.insert(self.pops, {l = l, pos = pos, t0 = self.t, life = life or 0.9})
end
function Clip:_fired(te) return self.lastT < te and te <= self.t end

-- ---------- templates ----------
local T = {}

function T.burst(self, n)
	local H = math.max(self.size.Y, 4)
	local V = 36
	local Lh = math.max(self.size.Z, 8) * 0.5 -- half the dino: targets start past its head
	self:_stage(V, F(0, Lh * 0.6 + 10))
	local dum = {self:_dummy(F(-5, Lh + 16)), self:_dummy(F(7, Lh + 21))}
	local darts = {}
	for i = 1, n.darts do darts[i] = ball(self.fx, 0.8 * math.max(1, self.scale), Vector3.zero, VENOM_L, 1) end
	self.loop = 3
	return function(t)
		local k = (t > 0.3 and t < 1.35) and math.sin(t * 45) * 0.015 or 0
		self:_place(CFrame.Angles(k, 0, 0))
		local from = self:_muzzle()
		for i, d in ipairs(darts) do
			local t0 = 0.3 + (i - 1) / n.darts
			local tg = dum[(i - 1) % 2 + 1]
			local f = (t - t0) / 0.22
			if f > 0 and f < 1 then
				d.Transparency = 0
				d.CFrame = CFrame.new(from:Lerp(tg.part.Position + Vector3.new(0, 1, 0), f))
			else
				d.Transparency = 1
			end
			if self:_fired(t0 + 0.22) then
				tg.part.Color = VENOM
				self:_pop("-" .. n.dmg, RED, tg.part.Position + Vector3.new((i % 3 - 1) * 1.2, 3.5, 0))
			end
		end
		return H
	end
end

function T.lob(self, n)
	local R, W = n.reach, n.cloud
	local V = R + W / 2 + 8
	self:_stage(V, F(0, R * 0.55))
	local land = F(0, R, 0.15)
	local dum = {self:_dummy(F(-W * 0.25, R + W * 0.1)), self:_dummy(F(W * 0.2, R - W * 0.2)), self:_dummy(F(W * 0.5 + 6, R + 2))}
	local can = ball(self.fx, 1.6 * math.max(1, self.scale), Vector3.zero, VENOM_L, 1)
	local cloud = disc(self.fx, W, land, VENOM, 1)
	local puffs = {}
	for i = 1, 6 do puffs[i] = ball(self.fx, W * 0.32, land, VENOM, 1) end
	local show = math.min(n.lasts, 3)
	self.loop = 1.3 + show + 0.9
	return function(t)
		self:_place(CFrame.Angles((t > 0.3 and t < 0.45) and -0.03 or 0, 0, 0))
		local f = (t - 0.3) / 1.0
		if f > 0 and f < 1 then
			can.Transparency = 0
			can.CFrame = CFrame.new(self:_muzzle():Lerp(land, f) + Vector3.new(0, math.sin(math.pi * f) * R * 0.35, 0))
		else
			can.Transparency = 1
		end
		local c = t - 1.3
		if c > 0 and c < show + 0.5 then
			local grow = ease(c / 0.3)
			local a = c > show and 1 - (c - show) / 0.5 or 1
			cloud.Size = Vector3.new(0.3, math.max(W * grow, 0.1), math.max(W * grow, 0.1))
			cloud.Transparency = 1 - 0.5 * a
			for i, p in ipairs(puffs) do
				local ang = i * 1.05 + t * 0.7
				local rr = W * (0.12 + 0.22 * ((i * 37) % 10) / 10) * grow
				p.CFrame = CFrame.new(land + Vector3.new(math.cos(ang) * rr, 1.2 + math.sin(i + t * 2) * 0.6, math.sin(ang) * rr))
				p.Transparency = 1 - 0.3 * a
			end
		else
			cloud.Transparency = 1
			for _, p in ipairs(puffs) do p.Transparency = 1 end
		end
		if self:_fired(1.5) then
			for i = 1, 2 do
				dum[i].part.Color = VENOM
				self:_pop("POISON", VENOM_L, dum[i].part.Position + Vector3.new(0, 3.5, 0), 1.2)
			end
		end
		return W
	end
end

function T.cone(self, n)
	local R, half = n.range, math.rad(n.cone / 2)
	local V = R * 1.25
	self:_stage(V, F(0, R * 0.45))
	local o = Vector3.new(0, 0.1, (self.recipe.attach and self.recipe.attach.Z or -2.4) * self.scale)
	local N = 15
	for i = 0, N - 1 do
		local a = -half + 2 * half * i / (N - 1)
		local d = dirOf(a)
		local edge = i == 0 or i == N - 1
		part(self.fx, Vector3.new(edge and 0.5 or 0.3, 0.06, R), CFrame.lookAt(o + d * R / 2, o + d * R), self.color, edge and 0.3 or 0.72)
	end
	local wave = {}
	for i = 1, N do wave[i] = part(self.fx, Vector3.new(1, 0.6, 0.9), CFrame.new(), VOLT, 1) end
	local spots = {{0.55, 18}, {0.85, -48}, {0.5, -12}, {0.75, 62}, {0.6, 96}, {1.18, 10}}
	local dum = {}
	for i, s in ipairs(spots) do
		local a = math.rad(s[2])
		local d = self:_dummy(o * Vector3.new(1, 0, 1) + dirOf(a) * (s[1] * R))
		d.dir = dirOf(a)
		d.inside = math.abs(a) <= half and s[1] <= 1
		d.hitAt = 0.45 + 0.45 * (1 - (1 - math.min(s[1], 1)) ^ (1 / 3))
		d.label = i == 1
		dum[i] = d
	end
	self.loop = 3.4
	return function(t)
		local pitch = t < 0.45 and -0.06 * (t / 0.45) or (t < 0.75 and 0.04 or 0)
		self:_place(CFrame.Angles(pitch, 0, 0))
		local w = ease((t - 0.45) / 0.45) * R
		local on = t > 0.45 and w < R - 0.05
		for i, p in ipairs(wave) do
			if on and w > 0.5 then
				local a = -half + 2 * half * (i - 0.5) / N
				local pos = o + dirOf(a) * w + Vector3.new(0, 0.6, 0)
				p.Size = Vector3.new(2 * w * math.sin(half / N) + 0.4, 0.6, 0.9)
				p.CFrame = CFrame.lookAt(pos, pos + dirOf(a))
				p.Transparency = 0.1
			else
				p.Transparency = 1
			end
		end
		for _, d in ipairs(dum) do
			if d.inside then
				local k = (t - d.hitAt) / 0.3
				if k > 0 then
					d.part.CFrame = CFrame.new(d.home + d.dir * 9 * ease(k) + Vector3.new(0, d.part.Size.Y / 2, 0))
					d.part.Color = VOLT
				end
				if d.label and self:_fired(d.hitAt) then
					self:_pop(("SILENCED %s s"):format(tostring(n.silence)), VOLT, d.part.Position + Vector3.new(0, 3.5, 0), 1.6)
				end
			end
		end
		return R
	end
end

function T.ring(self, n)
	local V = 30
	self:_stage(V, F(0, 2))
	local Lh = math.max(self.size.Z, 8) * 0.5
	local reach, hitR = Lh + 12, Lh + 7
	local spikes = {}
	local ks = math.max(1, self.scale)
	for k = 1, n.spines do spikes[k] = part(self.fx, Vector3.new(0.35, 0.35, 2.4) * ks, CFrame.new(), n.venom and VENOM_L or WHITE, 1) end
	local pick = {1, math.floor(n.spines / 3) + 1, math.floor(2 * n.spines / 3) + 1}
	local dum = {}
	for i, k in ipairs(pick) do
		local a = 2 * math.pi * (k - 1) / n.spines
		dum[i] = self:_dummy(Vector3.new(0, 0, -2.6 * self.scale) + dirOf(a) * hitR)
	end
	self.loop = 2.6
	return function(t)
		local hop = (t > 0.42 and t < 0.6) and math.sin((t - 0.42) / 0.18 * math.pi) * 0.5 or 0
		self:_place(CFrame.new(0, hop, 0))
		local o = self:_muzzle()
		local f = (t - 0.5) / 0.3
		for k, s in ipairs(spikes) do
			local d = dirOf(2 * math.pi * (k - 1) / n.spines)
			if f > 0 and f < 1.4 then
				local pos = o + d * (reach * math.min(f, 1)) - Vector3.new(0, f * 1.2, 0)
				s.CFrame = CFrame.lookAt(pos, pos + d)
				s.Transparency = f > 1 and (f - 1) / 0.4 or 0
			else
				s.Transparency = 1
			end
		end
		if self:_fired(0.5 + 0.3 * hitR / reach) then
			for _, d in ipairs(dum) do
				self:_pop("-" .. n.dmg, RED, d.part.Position + Vector3.new(0, 3.5, 0))
				if n.venom then d.part.Color = VENOM end
			end
		end
		if n.venom and self:_fired(0.95) then
			self:_pop("VENOM", VENOM_L, dum[1].part.Position + Vector3.new(0, 5.5, 0), 1)
		end
		return reach
	end
end

function T.self(self, n)
	local H, L = math.max(self.size.Y, 4), math.max(self.size.Z, 8)
	local mid = Vector3.new(0, self.hrpY + H * 0.1, self.size.Z * 0.05)
	if self.recipe.mode == "over" then
		local V = 34
		local Lh = L * 0.5
		self:_stage(V, F(0, Lh * 0.6 + 8))
		local show = math.min(n.lasts, 3)
		local dum = self:_dummy(F(4, Lh + 18))
		local flash = ball(self.fx, 1, mid, PURPLE, 1)
		local glow = ball(self.fx, L * 1.05, mid, PURPLE, 1)
		local shots = {}
		for i = 1, 10 do shots[i] = ball(self.fx, 0.8 * math.max(1, self.scale), Vector3.zero, VENOM_L, 1) end
		self.loop = 0.7 + show + 1.0
		local pips = self:_pips()
		return function(t)
			local a = (t - 0.4) / 0.3
			if a > 0 and a < 1 then
				flash.Size = Vector3.one * (L * (0.6 + a))
				flash.Transparency = 0.4 + 0.6 * a
			else
				flash.Transparency = 1
			end
			local on = t > 0.6 and t < 0.7 + show
			glow.Transparency = on and (0.9 + 0.04 * math.sin(t * 9)) or 1
			local from = self:_muzzle()
			local to = dum.part.Position + Vector3.new(0, 1, 0)
			for i, s in ipairs(shots) do s.Transparency = 1 end
			local k0 = math.max(0, math.floor((t - 0.7 - 0.25) / 0.12))
			for k = k0, k0 + 3 do
				local tk = 0.7 + k * 0.12
				local f = (t - tk) / 0.25
				if tk <= 0.7 + show and f > 0 and f < 1 then
					local s = shots[k % #shots + 1]
					s.Transparency = 0
					s.CFrame = CFrame.new(from:Lerp(to, f))
				end
			end
			if self:_fired(0.95) then
				dum.part.Color = VENOM
				self:_pop("NO AMMO USED", YELLOW, self:_local(Vector3.new(0, 4.5, 0)), 1.6)
			end
			for k = 1, 4 do
				if self:_fired(0.7 + k * 0.6) and 0.7 + k * 0.6 <= 0.7 + show then
					self:_pop(n.double and "VENOM x2" or "VENOM", VENOM_L, dum.part.Position + Vector3.new(0, 3.5, 0), 0.7)
				end
			end
			-- the 5 ammo pips stay full the whole time
			local sp = self:_project(self:_local(Vector3.new(0, 4.2, 0)))
			pips.Visible = sp ~= nil and t < 0.7 + show + 0.4
			if sp then pips.Position = UDim2.fromScale(sp.X, sp.Y) end
			return 22
		end
	end
	-- pump: debuffs orbit, the pump flushes them, heals (+ immune at the star)
	local V = 26
	self:_stage(V, F(0, 2))
	local orbs = {}
	for i = 1, 3 do orbs[i] = ball(self.fx, 1.1, mid, PURPLE, 0) end
	local shell = ball(self.fx, H, mid, VENOM_L, 1)
	local gold = ball(self.fx, L * 1.1, mid, YELLOW, 1)
	self.loop = 3
	return function(t)
		local bob = (t > 0.75 and t < 1.0) and math.sin((t - 0.75) / 0.25 * math.pi) * 0.4 or 0
		self:_place(CFrame.new(0, bob, 0))
		for i, o in ipairs(orbs) do
			local a = t * 3 + i * 2.1
			local s = t < 0.8 and 1 or math.max(0, 1 - (t - 0.8) / 0.2)
			o.Size = Vector3.one * (1.1 * s + 0.01)
			o.Transparency = s <= 0 and 1 or 0
			o.CFrame = CFrame.new(mid + Vector3.new(math.cos(a) * L * 0.45, H * 0.35 + math.sin(a * 2) * 0.5, math.sin(a) * L * 0.45))
		end
		local k = (t - 0.8) / 0.5
		if k > 0 and k < 1 then
			shell.Size = Vector3.one * (H * (0.8 + 1.2 * k))
			shell.Transparency = 0.6 + 0.4 * k
		else
			shell.Transparency = 1
		end
		gold.Transparency = (n.immune > 0 and t > 1.25) and (0.92 + 0.03 * math.sin(t * 8)) or 1
		if self:_fired(0.85) then self:_pop("CLEANSED", WHITE, self:_local(Vector3.new(0, 5, 0)), 1) end
		if self:_fired(1.05) then self:_pop("+" .. n.heal, VENOM_L, self:_local(Vector3.new(1.5, 3.5, 0)), 1.1) end
		if n.immune > 0 and self:_fired(1.3) then
			self:_pop(("IMMUNE %s s"):format(tostring(n.immune)), YELLOW, self:_local(Vector3.new(0, 6.5, 0)), 1.4)
		end
		return H
	end
end

function T.dash(self, n)
	local L, C = n.dist, n.charges
	local dirs = {0, math.rad(30), math.rad(-30)}
	local pts = {F(0, -L * C * 0.42)}
	for i = 1, C do pts[i + 1] = pts[i] + dirOf(dirs[(i - 1) % 3 + 1]) * L end
	local mid = (pts[1] + pts[C + 1]) / 2
	local V = L * C * 0.7 + 20
	self:_stage(V, mid + F(0, 4))
	local trails, poison = {}, {}
	for i = 1, C do
		trails[i] = part(self.fx, Vector3.new(1.2, 0.1, 1), CFrame.new(), TRAIL, 1)
		poison[i] = part(self.fx, Vector3.new(3.2, 0.12, 1), CFrame.new(), VENOM, 1)
	end
	self.loop = 0.5 + C * 0.85 + 0.7
	return function(t)
		local pos, lean = pts[1], 0
		local yaw = 0
		for i = 1, C do
			local t0 = 0.5 + (i - 1) * 0.85
			local a, b = pts[i], pts[i + 1]
			local f = (t - t0) / 0.25
			if f >= 1 then
				pos = b
				yaw = -dirs[(i - 1) % 3 + 1]
				strip(trails[i], a + Vector3.new(0, 0.15, 0), b + Vector3.new(0, 0.15, 0), 1.2)
				trails[i].Transparency = math.clamp(0.35 + (t - t0 - 0.25) / 0.6, 0.35, 1)
				if n.trail then
					strip(poison[i], a + Vector3.new(0, 0.08, 0), b + Vector3.new(0, 0.08, 0), 3.2, 0.12)
					poison[i].Transparency = 0.5
				end
			elseif f > 0 then
				local e = ease(f)
				pos = a:Lerp(b, e)
				yaw = -dirs[(i - 1) % 3 + 1]
				lean = -0.12
				strip(trails[i], a + Vector3.new(0, 0.15, 0), pos + Vector3.new(0, 0.15, 0), 1.2)
				trails[i].Transparency = 0.35
				if n.trail then
					strip(poison[i], a + Vector3.new(0, 0.08, 0), pos + Vector3.new(0, 0.08, 0), 3.2, 0.12)
					poison[i].Transparency = 0.5
				end
				break
			else
				trails[i].Transparency, poison[i].Transparency = 1, 1
				break
			end
		end
		self:_place(CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0))
		return L
	end
end

-- ---------- dummies, pips ----------
function Clip:_dummy(groundPos)
	local p = part(self.fx, Vector3.new(3, 6, 3), CFrame.new(groundPos + Vector3.new(0, 3, 0)), DUMMY, 0, nil, Enum.Material.SmoothPlastic)
	local d = {part = p, home = groundPos}
	table.insert(self.dummies, d)
	return d
end
function Clip:_pips()
	local f = Instance.new("Frame")
	f.Name = "Ammo"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.Size = UDim2.fromOffset(5 * 9 + 4 * 3, 9)
	f.ZIndex = 3
	f.Visible = false
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 3)
	l.Parent = f
	for i = 1, 5 do
		local p = Instance.new("Frame")
		p.BackgroundColor3 = YELLOW
		p.BorderSizePixel = 0
		p.Size = UDim2.fromOffset(9, 9)
		p.ZIndex = 3
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 2)
		c.Parent = p
		p.Parent = f
	end
	f.Parent = self.layer
	self.extraGui = f
	return f
end

-- ---------- step / loop ----------
function Clip:setStep(step)
	local r = self.recipe
	step = math.clamp(math.floor(tonumber(step) or 1), 1, (r and r.steps and #r.steps) or 1)
	self.step = step
	if self.fx then self.fx:Destroy() end
	if self.extraGui then self.extraGui:Destroy() self.extraGui = nil end
	for _, p in ipairs(self.pops) do p.l:Destroy() end
	self.pops = {}
	self.dummies = {}
	local fx = Instance.new("Folder")
	fx.Name = "Fx"
	fx.Parent = self.world
	self.fx = fx
	self:_place(CFrame.new())
	local build = r and T[r.template]
	self.frame = build and build(self, r.steps[step]) or function() return 0 end
	self.t, self.lastT = 0, -1
end
function Clip:_reset()
	for _, d in ipairs(self.dummies) do
		d.part.CFrame = CFrame.new(d.home + Vector3.new(0, 3, 0))
		d.part.Color = DUMMY
	end
	for _, p in ipairs(self.pops) do p.l:Destroy() end
	self.pops = {}
	self:_place(CFrame.new())
end
function Clip:_running()
	local vf = self.view
	if not self.alive or not vf.Parent or vf.AbsoluteSize.X < 2 then return false end
	local sg = vf:FindFirstAncestorWhichIsA("LayerCollector")
	if not sg or (sg:IsA("ScreenGui") and not sg.Enabled) then return false end
	if self.visibleFn and not self.visibleFn() then return false end
	return true
end
function Clip:_tick(dt)
	if not self:_running() then return end
	self.t += math.min(dt, 0.1)
	if self.t >= self.loop then
		self:_reset()
		self.t, self.lastT = 0, -1
	end
	self.frame(self.t)
	-- pops: rise 22 px and fade over their life
	for i = #self.pops, 1, -1 do
		local p = self.pops[i]
		local age = self.t - p.t0
		if age > p.life or age < 0 then
			p.l:Destroy()
			table.remove(self.pops, i)
		else
			local sp = self:_project(p.pos)
			p.l.Visible = sp ~= nil
			if sp then
				local k = age / p.life
				p.l.Position = UDim2.new(sp.X, 0, sp.Y, -22 * k)
				p.l.TextTransparency = k > 0.6 and (k - 0.6) / 0.4 or 0
				p.l.TextStrokeTransparency = 0.35 + 0.65 * (k > 0.6 and (k - 0.6) / 0.4 or 0)
			end
		end
	end
	-- fade in / out around the loop point
	local edge = math.min(self.t, self.loop - self.t)
	self.fader.BackgroundTransparency = edge < FADE and (0.35 + 0.65 * edge / FADE) or 1
	self.lastT = self.t
end
function Clip:count()
	local n = 0
	if self.world then
		for _, d in ipairs(self.world:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
	end
	return n
end
function Clip:destroy()
	self.alive = false
	if self.conn then self.conn:Disconnect() self.conn = nil end
	if self.view then self.view:Destroy() end
	self.pops, self.dummies = {}, {}
	self.world, self.fx, self.stage, self.rig = nil, nil, nil, nil
end

return M
