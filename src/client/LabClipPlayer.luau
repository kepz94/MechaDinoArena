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
-- v1.1 (MDA-446, plan docs/plans/LAB_CLIPS_v1.0.md "Other dinos (v1.1)"; Kepu 2026-11-11 15:37 "Looks great keep going with
--   other Dino's"): new templates for the other 6 dinos, driven by recipe.fx (static) + the step numbers:
--   shot (one projectile: stun / pull / reel / hold / split), throw (lob kinds mine / spike / boulder / goo / dome / wall /
--   turret / lantern / heal), wave (ring from the dino: buff / mark / stomp / drag), buff (self modes heal / cloak / scan /
--   shield / front / smoke / free / drone / speed / zone / lunge / fling), move (boost / leap / glide), place (pad / caltrops /
--   portal). cone and burst read optional recipe.fx (hitLabel / hitKey / push / tint; fan) with the 1.0 values as defaults,
--   so the dilo clips are unchanged. Allies are blue dummies. The dino can fade (cloak). Dummies keep their own base colour.
-- Loop: each template has its own length (2.6–5 s); the last 0.3 s fades to dark and the clip restarts. Runs on
--   RenderStepped only while the view is parented, has a size, its ScreenGui is enabled and opts.visible() (if given) is true.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = {}
M.VERSION = "1.0"
M.VERSION = "1.1" -- v1.1 templates for the other dinos

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
	local bfx = (self.recipe and self.recipe.fx) or {} -- v1.1: fan = darts spread over a 70° fan to n.reach
	local dum
	if bfx.fan then
		local reach = math.min(n.reach or 40, Lh + 45)
		self:_stage(math.max(V, reach + 8), F(0, reach * 0.55))
		dum = {self:_dummy(dirOf(math.rad(-20)) * reach * 0.8), self:_dummy(dirOf(math.rad(4)) * reach * 0.9), self:_dummy(dirOf(math.rad(26)) * reach * 0.75)}
	else
		self:_stage(V, F(0, Lh * 0.6 + 10))
		dum = {self:_dummy(F(-5, Lh + 16)), self:_dummy(F(7, Lh + 21))}
	end
	local darts = {}
	for i = 1, n.darts do darts[i] = ball(self.fx, 0.8 * math.max(1, self.scale), Vector3.zero, VENOM_L, 1) end
	self.loop = 3
	return function(t)
		local k = (t > 0.3 and t < 1.35) and math.sin(t * 45) * 0.015 or 0
		self:_place(CFrame.Angles(k, 0, 0))
		local from = self:_muzzle()
		for i, d in ipairs(darts) do
			local t0 = bfx.fan and (0.3 + (i - 1) * 0.04) or (0.3 + (i - 1) / n.darts)
			local tg = dum[(i - 1) % #dum + 1]
			local f = (t - t0) / 0.22
			if f > 0 and f < 1 then
				d.Transparency = 0
				d.CFrame = CFrame.new(from:Lerp(tg.part.Position + Vector3.new(0, 1, 0), f))
			else
				d.Transparency = 1
			end
			if self:_fired(t0 + 0.22) then
				tg.part.Color = bfx.tint or VENOM
				self:_pop("-" .. n.dmg, RED, tg.part.Position + Vector3.new((i % 3 - 1) * 1.2, 3.5, 0))
				if bfx.hitLabel and i == 1 then
					self:_pop(bfx.hitLabel:format(tostring(n[bfx.hitKey or "slow"])), bfx.labelColor or VOLT, tg.part.Position + Vector3.new(0, 6, 0), 1.3)
				end
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
			for i = 1, 2 do dum[i].part.Color = VENOM end
			self:_pop("POISON", VENOM_L, land + Vector3.new(0, 7, 0), 1.4)
		end
		return W
	end
end

function T.cone(self, n)
	local cfx = (self.recipe and self.recipe.fx) or {} -- v1.1: optional label / push / tint (1.0 values by default)
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
					d.part.CFrame = CFrame.new(d.home + d.dir * (cfx.push or 9) * ease(k) + Vector3.new(0, d.part.Size.Y / 2, 0))
					d.part.Color = cfx.tint or VOLT
				end
				if d.label and self:_fired(d.hitAt) then
					self:_pop((cfx.hitLabel or "SILENCED %s s"):format(tostring(n[cfx.hitKey or "silence"])), cfx.tint or VOLT,
						d.part.Position + Vector3.new(0, 3.5, 0), 1.6)
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

-- ---------- v1.1 templates (the other dinos) ----------
local ALLY = Color3.fromRGB(90, 160, 255)
local STONE = Color3.fromRGB(150, 140, 128)
local GOO = Color3.fromRGB(200, 230, 70)
local INK = Color3.fromRGB(70, 40, 110)
local SMOKE = Color3.fromRGB(170, 175, 185)
local ORANGE = Color3.fromRGB(255, 155, 46)
local function fxOf(self) return (self.recipe and self.recipe.fx) or {} end
local function lab(fmt, v) -- "STUNNED %s s" + 1 -> "STUNNED 1 s"; no value -> the text without "%s"
	if not fmt then return nil end
	if v == nil or v == false then return (fmt:gsub("%%s ?", "")) end
	return fmt:format(tostring(v))
end
local function on(v) return v ~= nil and v ~= false and v ~= 0 end
local function halfL(self) return math.max(self.size.Z, 8) * 0.5 end
local function midOf(self)
	local H = math.max(self.size.Y, 4)
	return Vector3.new(0, self.hrpY + H * 0.1, self.size.Z * 0.05), H, math.max(self.size.Z, 8)
end
function Clip:_ally(groundPos)
	local d = self:_dummy(groundPos)
	d.part.Color, d.base = ALLY, ALLY
	return d
end
function Clip:_alpha(k) -- fade the dino (and its part) to k (0 = as built, 1 = gone)
	if self.alphaK ~= nil and math.abs(k - self.alphaK) < 0.02 then return end
	self.alphaK = k
	self.origT = self.origT or {}
	for _, p in ipairs(self.rig:GetDescendants()) do
		if p:IsA("BasePart") then
			local o = self.origT[p]
			if o == nil then o = p.Transparency self.origT[p] = o end
			p.Transparency = o + (1 - o) * k
		end
	end
end
function Clip:_streaks(n) -- white speed lines behind the dino
	local list = {}
	for i = 1, n or 4 do list[i] = part(self.fx, Vector3.new(0.2, 0.2, 6), CFrame.new(), WHITE, 1) end
	return function(show, t)
		for i, l in ipairs(list) do
			if show then
				local k = (t * 2.5 + i / #list) % 1
				local x = (i - (#list + 1) / 2) * 1.6
				local pos = self.rigCF * Vector3.new(x, 1 + (i % 2) * 2.5, self.size.Z * 0.5 + 3 + k * 10)
				l.CFrame = CFrame.lookAt(pos, pos + self.rigCF.LookVector)
				l.Transparency = 0.35 + 0.6 * k
			else
				l.Transparency = 1
			end
		end
	end
end
function Clip:_bolt(col, d) return ball(self.fx, (d or 1.1) * math.max(1, self.scale), Vector3.zero, col, 1) end
local function fly(b, a, z, f, arc) -- move ball b along a -> z at f (0..1), hidden outside
	if f > 0 and f < 1 then
		b.Transparency = 0
		b.CFrame = CFrame.new(a:Lerp(z, f) + Vector3.new(0, arc and math.sin(math.pi * f) * arc or 0, 0))
	else
		b.Transparency = 1
	end
end

-- shot: one projectile at a dummy ahead. fx: color, tint, hitLabel + hitKey, dmgKey, mode ("pull" / "reel"), second (a
-- step key: when on, a 2nd dummy gets the same hit: a split or a splash)
function T.shot(self, n)
	local fx = fxOf(self)
	local Lh = halfL(self)
	local d = math.min(n.range or 60, Lh + 38)
	self:_stage(36, F(0, d * 0.55))
	local tg = self:_dummy(F(0, d))
	local tg2 = (fx.second and on(n[fx.second])) and self:_dummy(F(9, d + 4)) or nil
	local col = fx.color or VOLT
	local b1, b2 = self:_bolt(col), self:_bolt(col)
	local rope = part(self.fx, Vector3.new(0.3, 0.3, 1), CFrame.new(), Color3.fromRGB(200, 200, 210), 1)
	local hitAt = 0.75
	local hitT = (fx.mode == "pull" or fx.mode == "reel") and hitAt + 0.35 or hitAt
	self.loop = 3
	local function hit(dm)
		if fx.tint then dm.part.Color = fx.tint end
		local hv = fx.hitKey and n[fx.hitKey]
		local text = (not fx.hitKey or on(hv)) and lab(fx.hitLabel, hv) or fx.missLabel
		if text then self:_pop(text, fx.labelColor or col, dm.part.Position + Vector3.new(0, 3.5, 0), 1.4) end
		local dmg = fx.dmgKey and n[fx.dmgKey]
		if on(dmg) then self:_pop("-" .. tostring(dmg), RED, dm.part.Position + Vector3.new(2, 6, 0), 1) end
	end
	return function(t)
		local from = self:_muzzle()
		local to = tg.part.Position + Vector3.new(0, 1, 0)
		local f = (t - 0.4) / 0.35
		fly(b1, from, to, f)
		if (fx.mode == "pull" or fx.mode == "reel") and t > 0.4 and t < hitT + 0.15 then
			strip(rope, from, f < 1 and from:Lerp(to, math.max(f, 0)) or to, 0.3, 0.3)
			rope.Transparency = 0
		else
			rope.Transparency = 1
		end
		local k = (t - hitAt) / 0.35
		if fx.mode == "pull" and k > 0 then
			tg.part.CFrame = CFrame.new(tg.home:Lerp(F(0, Lh + 5), ease(k)) + Vector3.new(0, 3, 0))
		elseif fx.mode == "reel" and k > 0 then
			self:_place(CFrame.new(Vector3.zero:Lerp(F(0, math.max(d - Lh - 4, 0)), ease(k))))
		end
		if self:_fired(hitT) then hit(tg) end
		if tg2 then
			fly(b2, to, tg2.part.Position + Vector3.new(0, 1, 0), (t - hitT - 0.05) / 0.3)
			if self:_fired(hitT + 0.35) then hit(tg2) end
		end
		return d
	end
end

-- throw: something lands ahead, then fx.kind plays (mine / spike / boulder / goo / dome / wall / turret / lantern / heal)
function T.throw(self, n)
	local fx = fxOf(self)
	local kind = fx.kind
	local Lh = halfL(self)
	local dist = math.min(n[fx.distKey or "reach"] or fx.at or 40, fx.cap or (Lh + 40))
	local size = (kind == "dome" and n.dome) or (kind == "wall" and n.wall) or (kind == "heal" and n.burst)
		or (kind == "goo" and n.puddle) or (kind == "boulder" and (n.splash or 10) * 2) or 20
	self:_stage(math.max(dist + size * 0.5 + 10, 36), F(0, dist * 0.6))
	local land = F(0, dist, 0.15)
	local count = math.max(1, math.floor(tonumber(fx.countKey and n[fx.countKey]) or 1))
	local spots = {}
	for i = 1, count do spots[i] = land + Vector3.new((i - (count + 1) / 2) * math.max(size * 0.45, 7), 0, 0) end
	local cans = {}
	for i = 1, count do cans[i] = self:_bolt(fx.color or VENOM_L, 1.4) end
	local K -- the landed part: function(c, t)
	if kind == "mine" then
		local mines = {}
		for i, sp in ipairs(spots) do mines[i] = disc(self.fx, 3, sp, ORANGE, 1) end
		local d = self:_dummy(spots[1] + F(0, 16))
		local flash = ball(self.fx, 1, spots[1], ORANGE, 1)
		K = function(c)
			for _, m in ipairs(mines) do m.Transparency = c > 0 and 0.2 or 1 end
			local w = math.clamp(c / 1.0, 0, 1)
			if c > 0 and c < 1 then d.part.CFrame = CFrame.new(d.home:Lerp(spots[1] + F(0, 3), w) + Vector3.new(0, 3, 0)) end
			local k = (c - 1) / 0.3
			if k > 0 then
				mines[1].Transparency = 1
				d.part.CFrame = CFrame.new((spots[1] + F(0, 3)):Lerp(spots[1] + F(0, 15), ease(k)) + Vector3.new(0, 3, 0))
				flash.Size, flash.Transparency = Vector3.one * (2 + 10 * math.min(k, 1)), math.min(1, 0.2 + k * 0.8)
			else
				flash.Transparency = 1
			end
			if self:_fired(1.1 + 1.0) then
				self:_pop("-" .. tostring(n.dmg or 25), RED, d.part.Position + Vector3.new(0, 4, 0), 1)
				self:_pop("DAZED 1 s", YELLOW, d.part.Position + Vector3.new(0, 7, 0), 1.2)
				if on(n.jam) then self:_pop("PARTS JAMMED", VOLT, d.part.Position + Vector3.new(0, 10, 0), 1.2) end
			end
		end
		self.loop = 3.8
	elseif kind == "spike" then
		local spike = part(self.fx, Vector3.new(0.8, 5, 0.8), CFrame.new(land + Vector3.new(0, 2.5, 0)), STONE, 1)
		local chain = part(self.fx, Vector3.new(0.3, 0.3, 1), CFrame.new(), Color3.fromRGB(220, 220, 230), 1)
		local rad = on(n.yank) and 5 or 10
		local ring = disc(self.fx, rad * 2, land, YELLOW, 1)
		local d = self:_dummy(land + Vector3.new(6, 0, 0))
		K = function(c)
			spike.Transparency = c > 0 and 0 or 1
			ring.Transparency = c > 0 and 0.75 or 1
			if c > 0 then
				local want = on(n.yank) and 5 or math.min(6 + 10 * c, rad)
				local pos = land + Vector3.new(want, 0, 0)
				d.part.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
				strip(chain, land + Vector3.new(0, 1, 0), pos + Vector3.new(0, 1.5, 0), 0.3, 0.3)
				chain.Transparency = 0
			else
				chain.Transparency = 1
			end
			if self:_fired(1.1 + 0.1) then
				d.part.Color = YELLOW
				self:_pop(lab("CHAINED %s s", n.chained), YELLOW, d.part.Position + Vector3.new(0, 4, 0), 1.6)
			end
		end
		self.loop = 3.4
	elseif kind == "boulder" or kind == "goo" then
		local col = kind == "goo" and GOO or STONE
		local r = kind == "goo" and (n.puddle or 21) / 2 or (n.splash or 10)
		local pads = {}
		for i, sp in ipairs(spots) do pads[i] = disc(self.fx, r * 2, sp, col, 1) end
		local enemies = {self:_dummy(land + Vector3.new(-r * 0.4, 0, -r * 0.3)), self:_dummy(land + Vector3.new(r * 0.5, 0, r * 0.2))}
		local stay = kind == "goo" and math.min(n.lasts or 5, 2.5) or (on(n.rubble) and 2.5 or 0.5)
		K = function(c)
			for _, pd in ipairs(pads) do
				if c > 0 and c < stay + 0.5 then
					local g = ease(c / 0.25)
					pd.Size = Vector3.new(0.3, math.max(r * 2 * g, 0.1), math.max(r * 2 * g, 0.1))
					pd.Transparency = c > stay and 0.45 + 0.55 * (c - stay) / 0.5 or 0.45
				else
					pd.Transparency = 1
				end
			end
			if self:_fired(1.1 + 0.15) then
				for i, e in ipairs(enemies) do
					e.part.Color = col
					if kind == "boulder" then self:_pop("-" .. tostring(n.dmg or 12), RED, e.part.Position + Vector3.new(0, 4, 0), 1) end
				end
				self:_pop(kind == "goo" and "SLOWED 50%" or "SLOWED 30%", col, land + Vector3.new(0, 9, 0), 1.4)
				if kind == "boulder" and on(n.rubble) then self:_pop("RUBBLE 4 s", col, land + Vector3.new(0, 12, 0), 1.4) end
			end
		end
		self.loop = 1.1 + stay + 1.2
	elseif kind == "dome" or kind == "wall" then
		local isDome = kind == "dome"
		local W = isDome and n.dome or n.wall
		local shield = isDome and part(self.fx, Vector3.new(W, W, W), CFrame.new(land), VOLT, 1, Enum.PartType.Ball)
			or part(self.fx, Vector3.new(W, n.height or 30, 2), CFrame.new(land + Vector3.new(0, (n.height or 30) / 2, 0)), Color3.fromRGB(230, 170, 70), 1)
		local edge = isDome and (land + F(0, W / 2)) or land
		local foe = self:_dummy(edge + F(0, 12))
		local dart = self:_bolt(RED, 0.9)
		K = function(c)
			local g = ease(c / 0.4)
			if c > 0 then
				if isDome then
					shield.Size = Vector3.one * math.max(W * g, 0.1)
					shield.Transparency = 0.82
				else
					local h = (n.height or 30) * g
					shield.Size = Vector3.new(W, math.max(h, 0.1), 2)
					shield.CFrame = CFrame.new(land + Vector3.new(0, h / 2, 0))
					shield.Transparency = 0.25
				end
			else
				shield.Transparency = 1
			end
			fly(dart, foe.part.Position + Vector3.new(0, 1, 0), edge + Vector3.new(0, 2, 0), (c - 0.7) / 0.3)
			if self:_fired(1.1 + 1.0) then self:_pop("BLOCKED", VOLT, edge + Vector3.new(0, 6, 0), 1.2) end
		end
		self.loop = 3.6
	elseif kind == "turret" then
		local guns = {}
		for i, sp in ipairs(spots) do guns[i] = part(self.fx, Vector3.new(2, 2, 2), CFrame.new(sp + Vector3.new(0, 1, 0)), Color3.fromRGB(120, 200, 160), 1, nil, Enum.Material.Metal) end
		local foes = {self:_dummy(land + F(-6, 14)), self:_dummy(land + F(8, 20))}
		local shots = {}
		for i = 1, 4 do shots[i] = self:_bolt(VENOM_L, 0.6) end
		K = function(c)
			for _, g in ipairs(guns) do g.Transparency = c > 0 and 0 or 1 end
			for i, sh in ipairs(shots) do
				local k = math.floor(c / 0.5)
				local tk = k * 0.5 + (i - 1) * 0.06
				local gi = ((i - 1) % #guns) + 1
				fly(sh, guns[gi].Position + Vector3.new(0, 1, 0), foes[1].part.Position + Vector3.new(0, 1, 0), (c - tk) / 0.2)
			end
			for k = 1, 4 do
				if self:_fired(1.1 + k * 0.5 + 0.2) then
					self:_pop("-" .. tostring(on(n.twin) and 2.5 or 1.25), RED, foes[1].part.Position + Vector3.new(0, 4, 0), 0.6)
				end
			end
		end
		self.loop = 4
	elseif kind == "lantern" then
		local lamp = part(self.fx, Vector3.new(1.4, 2, 1.4), CFrame.new(land + Vector3.new(0, 1, 0)), YELLOW, 1)
		local reach = n.chainReach or 24
		local foes = {self:_dummy(land + Vector3.new(5, 0, -3))}
		for i = 2, 5 do foes[i] = self:_dummy(foes[i - 1].home + Vector3.new(reach * 0.7, 0, -4 * (i % 2 == 0 and 1 or -1))) end
		local zaps = {}
		for i = 1, 5 do zaps[i] = part(self.fx, Vector3.new(0.35, 0.35, 1), CFrame.new(), Color3.fromRGB(255, 240, 150), 1) end
		local chains = math.max(0, math.floor(tonumber(n.chains) or 1))
		K = function(c)
			lamp.Transparency = c > 0 and 0 or 1
			for i = 1, chains + 1 do
				local ti = 0.2 + (i - 1) * 0.25
				local a = i == 1 and lamp.Position or foes[i - 1].part.Position + Vector3.new(0, 1, 0)
				if c > ti and c < ti + 0.3 then
					strip(zaps[i], a, foes[i].part.Position + Vector3.new(0, 1, 0), 0.35, 0.35)
					zaps[i].Transparency = 0
				else
					zaps[i].Transparency = 1
				end
				if self:_fired(1.1 + ti) then
					foes[i].part.Color = YELLOW
					self:_pop("-" .. tostring(n.dmg or 12), RED, foes[i].part.Position + Vector3.new(0, 4, 0), 1)
					if i == 1 then self:_pop("STUNNED 1 s", YELLOW, foes[i].part.Position + Vector3.new(0, 7, 0), 1.2) end
				end
			end
		end
		self.loop = 3.8
	else -- heal: a bud bursts; squadmates inside heal, enemies inside heal less
		local W = n.burst or 40
		local burst = disc(self.fx, 1, land, VENOM_L, 1)
		local allies = {self:_ally(land + Vector3.new(-W * 0.25, 0, 0)), self:_ally(land + Vector3.new(W * 0.15, 0, -W * 0.2))}
		local foe = self:_dummy(land + Vector3.new(W * 0.3, 0, W * 0.15))
		K = function(c)
			if c > 0 and c < 1.0 then
				local g = ease(c / 0.4)
				burst.Size = Vector3.new(0.3, math.max(W * g, 0.1), math.max(W * g, 0.1))
				burst.Transparency = 0.5 + 0.5 * math.max(0, (c - 0.6) / 0.4)
			else
				burst.Transparency = 1
			end
			if self:_fired(1.1 + 0.3) then
				for _, a in ipairs(allies) do self:_pop("+" .. tostring(n.heal or 20), VENOM_L, a.part.Position + Vector3.new(0, 4, 0), 1.2) end
				self:_pop("+50% HEALING", VENOM_L, allies[1].part.Position + Vector3.new(0, 7, 0), 1.4)
				self:_pop("-50% HEALING", RED, foe.part.Position + Vector3.new(0, 4, 0), 1.4)
			end
		end
		self.loop = 3.4
	end
	return function(t)
		local f = (t - 0.3) / 0.8
		for i, cn in ipairs(cans) do fly(cn, self:_muzzle(), spots[i], f, dist * 0.3) end
		self:_place(CFrame.Angles((t > 0.3 and t < 0.45) and -0.03 or 0, 0, 0))
		K(t - 1.1, t)
		return dist
	end
end

-- wave: a ring from the dino. fx.kind: "buff" (squadmates: fx.text), "mark" (enemies), "stomp" (damage + stun), "drag"
-- (enemies pulled in, bleed); radius from n[fx.radiusKey or "reach"] (fx.diameter: that number is a width)
function T.wave(self, n)
	local fx = fxOf(self)
	local kind = fx.kind
	local Rr = tonumber(n[fx.radiusKey or "reach"]) or 20
	if fx.diameter then Rr = Rr / 2 end
	local Lh = halfL(self)
	self:_stage(math.max(Rr * 2.2, 30), F(0, Rr * 0.25))
	local ring = disc(self.fx, 1, Vector3.new(0, 0.2, 0), fx.color or self.color, 1)
	local spots = {{0.7, 40}, {0.75, -55}, {0.65, 150}, {1.35, 15}}
	local dum = {}
	for i, sp in ipairs(spots) do
		local pos = dirOf(math.rad(sp[2])) * math.max(Rr * sp[1], i == 4 and Rr + 6 or 2)
		local dm = kind == "buff" and self:_ally(pos) or self:_dummy(pos)
		dm.inside = i ~= 4
		dum[i] = dm
	end
	local blades = {}
	if kind == "drag" then for i = 1, 6 do blades[i] = part(self.fx, Vector3.new(0.4, 0.4, 5), CFrame.new(), Color3.fromRGB(230, 230, 240), 1) end end
	local hold = kind == "drag" and math.min(n.lasts or 3, 2.5) or 0
	self.loop = 3.2 + hold
	return function(t)
		local hop = (kind == "stomp" and t > 0.25 and t < 0.5) and math.sin((t - 0.25) / 0.25 * math.pi) * 1.2 or 0
		self:_place(CFrame.new(0, hop, 0))
		local k = (t - 0.5) / 0.4
		if k > 0 and k < 2 + hold then
			local g = ease(math.min(k, 1))
			ring.Size = Vector3.new(0.3, math.max(Rr * 2 * g, 0.1), math.max(Rr * 2 * g, 0.1))
			ring.Transparency = (k > 1 + hold) and 0.6 + 0.4 * (k - 1 - hold) or 0.6
		else
			ring.Transparency = 1
		end
		for i, b in ipairs(blades) do
			if t > 0.5 and t < 0.9 + hold then
				local a = t * 3 + i * math.pi / 3
				local pos = Vector3.new(math.sin(a) * Rr * 0.8, 1, -math.cos(a) * Rr * 0.8)
				b.CFrame = CFrame.lookAt(pos, pos + Vector3.new(math.cos(a), 0, math.sin(a)))
				b.Transparency = 0
			else
				b.Transparency = 1
			end
		end
		for i, dm in ipairs(dum) do
			if dm.inside then
				if kind == "drag" and t > 0.9 then
					local w = math.min((t - 0.9) / math.max(hold, 0.5), 1) * 0.5
					dm.part.CFrame = CFrame.new(dm.home:Lerp(Vector3.zero, w) + Vector3.new(0, 3, 0))
				elseif kind == "stomp" then
					local h = (t > 0.7 and t < 0.95) and math.sin((t - 0.7) / 0.25 * math.pi) * 1.5 or 0
					dm.part.CFrame = CFrame.new(dm.home + Vector3.new(0, 3 + h, 0))
				end
				if self:_fired(0.7) then
					if kind == "buff" then
						dm.part.Color = Color3.fromRGB(150, 210, 255)
						if i == 1 then self:_pop(fx.text or "BUFFED", ALLY, dm.part.Position + Vector3.new(0, 4, 0), 1.6) end
						if i == 2 and on(n.clear) then self:_pop("STUNS CLEARED", YELLOW, dm.part.Position + Vector3.new(0, 4, 0), 1.6) end
					elseif kind == "mark" then
						dm.part.Color = RED
						if i == 1 then self:_pop(lab("MARKED %s s", n.mark), RED, dm.part.Position + Vector3.new(0, 4, 0), 1.6) end
						if i == 2 then self:_pop("-40% DAMAGE", RED, dm.part.Position + Vector3.new(0, 4, 0), 1.6) end
					elseif kind == "stomp" then
						dm.part.Color = YELLOW
						self:_pop("-" .. tostring(n.dmg or 6), RED, dm.part.Position + Vector3.new(0, 4, 0), 1)
						if i == 1 then self:_pop(lab("STUNNED %s s", n.stun), YELLOW, dm.part.Position + Vector3.new(0, 7, 0), 1.3) end
					else
						dm.part.Color = RED
						if i == 1 then self:_pop(lab("BLEED %s/s", n.bleed), RED, dm.part.Position + Vector3.new(0, 4, 0), 1.6) end
					end
				end
			end
		end
		return Rr
	end
end

-- buff: something on the dino itself. fx.mode: heal / cloak / scan / shield / front / smoke / free / drone / speed / zone /
-- lunge / fling
function T.buff(self, n)
	local fx = fxOf(self)
	local mode = fx.mode
	local mid, H, L = midOf(self)
	local Lh = L * 0.5
	local streak = self:_streaks(4)
	local pos = function(v) return self:_local(v) end
	if mode == "heal" or mode == "speed" then
		self:_stage(36, F(0, 10))
		local shell = ball(self.fx, H, mid, VENOM_L, 1)
		self.loop = 3.2
		return function(t)
			local go = (t > 0.5) and math.min((t - 0.5) / 2.2, 1) * 16 or 0
			self:_place(CFrame.new(F(0, go)))
			streak(t > 0.5 and t < 2.7, t)
			if mode == "heal" then
				local k = (t - 0.4) / 0.6
				if k > 0 and k < 1 then
					shell.CFrame = CFrame.new(self.rigCF * mid)
					shell.Size = Vector3.one * (H * (0.8 + 1.2 * k))
					shell.Transparency = 0.6 + 0.4 * k
				else
					shell.Transparency = 1
				end
				if self:_fired(0.6) then self:_pop("+" .. tostring(n.heal) .. "% HEALTH", VENOM_L, pos(Vector3.new(0, 5, 0)), 1.4) end
				if self:_fired(1.1) then self:_pop(tostring(n.speed or 1.4) .. "x SPEED", WHITE, pos(Vector3.new(0, 5, 0)), 1.2) end
				if fx.starKey and on(n[fx.starKey]) and self:_fired(1.7) then self:_pop(fx.starText, YELLOW, pos(Vector3.new(0, 6, 0)), 1.2) end
			else
				if self:_fired(0.6) then self:_pop(fx.text or "RUN +40%", WHITE, pos(Vector3.new(0, 5, 0)), 1.6) end
				local k = 1
				for _, key in ipairs({"cuts", "jump", "noslow"}) do
					if on(n[key]) and self:_fired(0.9 + k * 0.45) then self:_pop(fx[key .. "Text"] or key, YELLOW, pos(Vector3.new(0, 6, 0)), 1.1) end
					k += 1
				end
			end
			return L
		end
	elseif mode == "cloak" or mode == "smoke" then
		self:_stage(34, F(0, 10))
		local foe = self:_dummy(F(6, Lh + 16))
		local hold = math.min(n.lasts or 3, 2.2)
		local puffs = {}
		if mode == "smoke" then for i = 1, 8 do puffs[i] = ball(self.fx, (n.cloud or 28) * 0.4, Vector3.zero, SMOKE, 1) end end
		self.loop = 0.5 + hold + 1.4
		return function(t)
			local inT = t > 0.4 and t < 0.4 + hold
			if mode == "cloak" then
				local a = t < 0.4 and 0 or (t < 0.7 and (t - 0.4) / 0.3 or (t < 0.4 + hold and 1 or math.max(0, 1 - (t - 0.4 - hold) / 0.2)))
				self:_alpha(a * 0.85)
				local strike = on(n.ambush) and t > 0.4 + hold and t < 0.75 + hold
				self:_place(strike and CFrame.new(F(0, ease((t - 0.4 - hold) / 0.3) * (Lh + 6))) or CFrame.new())
				if on(n.ambush) and self:_fired(0.75 + hold) then self:_pop("+35% HIT", RED, foe.part.Position + Vector3.new(0, 4, 0), 1.2) end
			else
				for i, p in ipairs(puffs) do
					if inT or (t > 0.4 and t < 0.6 + hold) then
						local a = i * 0.8 + t * 0.4
						local r = (n.cloud or 28) * 0.3
						p.CFrame = CFrame.new(Vector3.new(math.cos(a) * r, 3 + (i % 3) * 2, math.sin(a) * r * 0.8))
						p.Transparency = 0.45
					else
						p.Transparency = 1
					end
				end
				streak(on(n.faster) and inT, t)
			end
			if self:_fired(0.8) then
				self:_pop(lab(fx.text or "CLOAKED %s s", n.lasts), VOLT, pos(Vector3.new(0, 5, 0)), 1.4)
				self:_pop("LOST YOU", WHITE, foe.part.Position + Vector3.new(0, 4, 0), 1.4)
			end
			if mode == "smoke" and on(n.slows) and self:_fired(1.3) then self:_pop("SLOWED 25%", SMOKE, foe.part.Position + Vector3.new(0, 7, 0), 1.2) end
			return L
		end
	elseif mode == "scan" then
		local Rr = n.radius or 60
		self:_stage(math.max(Rr * 1.4, 34), F(0, Rr * 0.3))
		local ringParts = {}
		for i = 1, 24 do ringParts[i] = part(self.fx, Vector3.new(2 * math.pi * Rr / 24, 0.15, 0.5), CFrame.new(), VOLT, 1) end
		local trails = {}
		local cols = {Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 200, 90), on(n.blood) and RED or Color3.fromRGB(150, 255, 160)}
		for j = 1, 3 do
			trails[j] = {}
			for i = 1, 6 do trails[j][i] = part(self.fx, Vector3.new(1, 0.2, 1), CFrame.new(), cols[j], 1) end
		end
		local paths = {}
		for j = 1, 3 do
			local pts = {}
			local a0 = math.rad(-60 + 55 * (j - 1))
			for i = 0, 6 do
				local rr = Rr * (0.2 + 0.13 * i)
				local a = a0 + math.sin(i * 1.3 + j) * 0.35
				pts[i + 1] = Vector3.new(math.sin(a) * rr, 0.3, -math.cos(a) * rr)
			end
			paths[j] = pts
		end
		self.loop = 3.4
		return function(t)
			local k = (t - 0.4) / 0.5
			for i, p in ipairs(ringParts) do
				if k > 0 and k < 1.6 then
					local a = (i - 0.5) / 24 * 2 * math.pi
					local rr = Rr * ease(math.min(k, 1))
					local q = Vector3.new(math.sin(a) * rr, 0.3, -math.cos(a) * rr)
					p.Size = Vector3.new(math.max(2 * math.pi * rr / 24, 0.1), 0.15, 0.5)
					p.CFrame = CFrame.lookAt(q, q + Vector3.new(math.cos(a), 0, math.sin(a)))
					p.Transparency = k > 1 and 0.4 + 0.6 * (k - 1) / 0.6 or 0.4
				else
					p.Transparency = 1
				end
			end
			for j = 1, 3 do
				for i = 1, 6 do
					strip(trails[j][i], paths[j][i], paths[j][i + 1], 0.9, 0.2)
					local pulse = (on(n.pulse) and i == 6) and (0.2 + 0.3 * math.abs(math.sin(t * 8))) or 0.25
					trails[j][i].Transparency = t > 0.9 and pulse or 1
				end
			end
			if self:_fired(0.95) then self:_pop(lab("TRAILS %s s", 6), VOLT, pos(Vector3.new(0, 5, 0)), 1.6) end
			return Rr
		end
	elseif mode == "shield" or mode == "front" then
		self:_stage(34, F(0, 10))
		local foe = self:_dummy(F(5, Lh + 18))
		local front = mode == "front"
		local wall = front and part(self.fx, Vector3.new(0.4, H * 1.3, H * 1.3), CFrame.new(F(0, Lh + 1.5, H * 0.55)) * CFrame.Angles(0, math.rad(90), 0),
			fx.color or VOLT, 1, Enum.PartType.Cylinder)
			or ball(self.fx, L * 1.15, mid, fx.color or VOLT, 1)
		local spin = {}
		if fx.spin then for i = 1, 3 do spin[i] = part(self.fx, Vector3.new(0.5, H * 1.1, 0.5), CFrame.new(), Color3.fromRGB(220, 230, 240), 1, nil, Enum.Material.Metal) end end
		local hold = math.min(n.lasts or 1.5, 2.4)
		local darts = {}
		for i = 1, 3 do darts[i] = self:_bolt(RED, 0.9) end
		local stopAt = front and F(0, Lh + 2, H * 0.55) or (mid + F(0, L * 0.55))
		self.loop = 0.4 + hold + 1.2
		return function(t)
			local up = t > 0.3 and t < 0.3 + hold
			if fx.spin then
				wall.Transparency = 1
				for i, sp in ipairs(spin) do
					sp.CFrame = CFrame.new(F(0, Lh + 1.5, H * 0.55)) * CFrame.Angles(0, 0, t * 14 + i * 2.1)
					sp.Transparency = up and 0 or 1
				end
			else
				wall.Transparency = up and (front and 0.45 or 0.75) or 1
			end
			for i, d in ipairs(darts) do
				local t0 = 0.45 + (i - 1) * 0.3
				fly(d, foe.part.Position + Vector3.new(0, 1, 0), stopAt, (t - t0) / 0.25)
				if self:_fired(t0 + 0.25) and t0 + 0.25 < 0.3 + hold then
					local text = fx.counter and (tostring(i) .. "/" .. tostring(n.blocks)) or "BLOCKED"
					self:_pop(text, fx.color or VOLT, stopAt + Vector3.new(0, 3, 0), 0.8)
				end
			end
			if self:_fired(0.5) and fx.text then self:_pop(fx.text, WHITE, pos(Vector3.new(0, 6, 0)), 1.4) end
			if fx.starKey and on(n[fx.starKey]) and self:_fired(1.4) then self:_pop(fx.starText, YELLOW, foe.part.Position + Vector3.new(0, 4, 0), 1.2) end
			return L
		end
	elseif mode == "free" then
		self:_stage(30, F(0, 4))
		local cage = {}
		for i = 1, 8 do cage[i] = part(self.fx, Vector3.new(0.4, H * 0.9, 0.4), CFrame.new(), YELLOW, 1) end
		local bits = {}
		for i = 1, 10 do bits[i] = part(self.fx, Vector3.new(0.6, 0.15, 1.6), CFrame.new(), fx.color or YELLOW, 1) end
		local push = n.push or 0
		local near = {self:_dummy(F(-Lh * 0.6 - 4, 3)), self:_dummy(F(Lh * 0.6 + 4, -2))}
		self.loop = 3.2
		return function(t)
			for i, c in ipairs(cage) do
				local a = i / 8 * 2 * math.pi + t
				c.CFrame = CFrame.new(Vector3.new(math.cos(a) * Lh * 0.7, self.hrpY, math.sin(a) * Lh * 0.9))
				c.Transparency = t < 1.0 and 0.2 or 1
			end
			local k = (t - 1.0) / 0.4
			for i, b in ipairs(bits) do
				if k > 0 and k < 1 then
					local a = i / 10 * 2 * math.pi
					local p = mid + Vector3.new(math.cos(a), 0.3, math.sin(a)) * (2 + 14 * k)
					b.CFrame = CFrame.lookAt(p, p + Vector3.new(math.cos(a), 0, math.sin(a)))
					b.Transparency = k
				else
					b.Transparency = 1
				end
			end
			if on(push) then
				for _, d in ipairs(near) do
					local w = math.clamp((t - 1.0) / 0.3, 0, 1)
					local dir = (d.home * Vector3.new(1, 0, 1)).Unit
					d.part.CFrame = CFrame.new(d.home + dir * math.min(push, 12) * ease(w) + Vector3.new(0, 3, 0))
				end
			end
			if self:_fired(0.25) then self:_pop(fx.stuckText or "STUNNED", YELLOW, pos(Vector3.new(0, 5, 0)), 0.7) end
			if self:_fired(1.05) then self:_pop("FREE!", WHITE, pos(Vector3.new(0, 5, 0)), 1.2) end
			local imm = n.immune or n.safe
			if on(imm) and self:_fired(1.4) then self:_pop(lab(fx.immuneText or "IMMUNE %s s", imm), VOLT, pos(Vector3.new(0, 7, 0)), 1.3) end
			if on(push) and self:_fired(1.3) then self:_pop(lab("PUSHED %s studs", push), WHITE, near[2].part.Position + Vector3.new(0, 4, 0), 1.2) end
			return L
		end
	elseif mode == "drone" then
		self:_stage(32, F(0, 8))
		local ally = self:_ally(F(10, Lh + 8))
		ally.part.Color = Color3.fromRGB(70, 110, 170)
		local drone = ball(self.fx, 1.6, Vector3.zero, Color3.fromRGB(150, 255, 200), 1)
		local beam = part(self.fx, Vector3.new(0.3, 0.3, 1), CFrame.new(), VENOM_L, 1)
		local hold = math.min(n.lasts or 4, 2.6)
		self.loop = 1.2 + hold + 0.8
		return function(t)
			local start = self:_local(Vector3.new(0, 3, 0))
			local spot = ally.part.Position + Vector3.new(0, 7, 0)
			local k = (t - 0.3) / 0.6
			if k > 0 then
				drone.Transparency = 0
				drone.CFrame = CFrame.new(start:Lerp(spot, ease(math.min(k, 1))) + Vector3.new(0, math.sin(t * 6) * 0.4, 0))
			else
				drone.Transparency = 1
			end
			local healing = t > 0.9 and t < 0.9 + hold
			if healing then strip(beam, drone.Position, ally.part.Position + Vector3.new(0, 2, 0), 0.3, 0.3) beam.Transparency = 0.2 else beam.Transparency = 1 end
			for i = 1, 6 do
				if self:_fired(0.9 + i * 0.45) and 0.9 + i * 0.45 < 0.9 + hold then
					self:_pop("+" .. tostring(n.heal or 4), VENOM_L, ally.part.Position + Vector3.new(0, 4, 0), 0.6)
				end
			end
			return L
		end
	elseif mode == "zone" then
		local W = n.zone or 44
		self:_stage(math.max(W * 1.2, 34), F(0, W * 0.35))
		local z = disc(self.fx, W, F(0, W * 0.45, 0.2), VENOM_L, 1)
		local ally = self:_ally(F(-W * 0.15, W * 0.45))
		local foe = self:_dummy(F(W * 0.2, W * 0.5))
		local hold = math.min(n.lasts or 3, 2.6)
		self.loop = 0.5 + hold + 1.2
		return function(t)
			local k = (t - 0.4) / 0.3
			if k > 0 and t < 0.4 + hold + 0.3 then
				local g = ease(math.min(k, 1))
				z.Size = Vector3.new(0.3, math.max(W * g, 0.1), math.max(W * g, 0.1))
				z.Transparency = t > 0.4 + hold and 0.55 + 0.45 * (t - 0.4 - hold) / 0.3 or 0.55
			else
				z.Transparency = 1
			end
			if self:_fired(0.7) then self:_pop(lab("ZONE %s studs", W), VENOM_L, z.Position + Vector3.new(0, 6, 0), 1.4) end
			if on(n.bloom) and self:_fired(0.45 + hold) then
				self:_pop("+5", VENOM_L, ally.part.Position + Vector3.new(0, 4, 0), 1)
				self:_pop("SLOWED 1.5 s", VOLT, foe.part.Position + Vector3.new(0, 4, 0), 1)
			end
			return W
		end
	elseif mode == "lunge" then
		self:_stage(34, F(0, 10))
		local foe = self:_dummy(F(0, Lh + 12))
		local shell = ball(self.fx, H, mid, RED, 1)
		self.loop = 3
		return function(t)
			local k = (t - 0.3) / 0.4
			if k > 0 and k < 1 then shell.Size = Vector3.one * (H * (0.8 + k)) shell.Transparency = 0.55 + 0.45 * k else shell.Transparency = 1 end
			local l = (t - 0.8) / 0.25
			self:_place(CFrame.new(F(0, (l > 0 and l < 1.6) and ease(math.min(l, 1)) * 9 or 0)))
			if self:_fired(0.35) then self:_pop(lab("-%s%% HP", n.cost or 25), RED, pos(Vector3.new(0, 5, 0)), 1.1) end
			if self:_fired(1.05) then
				foe.part.Color = RED
				self:_pop(on(n.harder) and "HEADBUTT +25%" or "HEADBUTT", WHITE, foe.part.Position + Vector3.new(0, 4, 0), 1.2)
				if on(n.slow) then self:_pop("SLOWED x0.45", VOLT, foe.part.Position + Vector3.new(0, 7, 0), 1.2) end
			end
			return L
		end
	end
	-- fling: the tail grabs a dino beside you and throws it ahead
	self:_stage(math.max((n.fling or 30) + 16, 34), F(0, (n.fling or 30) * 0.45))
	local foe = self:_dummy(F(-6, -Lh * 0.4))
	local other = on(n.crash) and self:_dummy(F(3, (n.fling or 30) + 3)) or nil
	local whip = part(self.fx, Vector3.new(0.5, 0.5, 1), CFrame.new(), Color3.fromRGB(220, 220, 230), 1)
	self.loop = 3.2
	return function(t)
		local k = (t - 0.6) / 0.6
		if t > 0.35 and t < 0.6 then
			strip(whip, self:_local(Vector3.new(0, 1, Lh / math.max(self.scale, 0.01) * 0.8)), foe.part.Position, 0.5, 0.5)
			whip.Transparency = 0
		else
			whip.Transparency = 1
		end
		if k > 0 then
			local a, z = foe.home, F(0, n.fling or 30)
			local w = ease(math.min(k, 1))
			foe.part.CFrame = CFrame.new(a:Lerp(z, w) + Vector3.new(0, 3 + math.sin(math.pi * math.min(k, 1)) * 14, 0))
		end
		if self:_fired(1.2) then
			foe.part.Color = YELLOW
			self:_pop("-8", RED, foe.part.Position + Vector3.new(0, 4, 0), 1)
			self:_pop("STUNNED 1 s", YELLOW, foe.part.Position + Vector3.new(0, 7, 0), 1.2)
			if other then other.part.Color = RED self:_pop("-8", RED, other.part.Position + Vector3.new(0, 4, 0), 1) end
		end
		return n.fling or 30
	end
end

-- move: the dino travels. fx.mode: boost (fast slide + flame, charges, hop), leap (arcs; slam / double jump), glide
function T.move(self, n)
	local fx = fxOf(self)
	local mode = fx.mode
	local mid, H, L = midOf(self)
	local Lh = L * 0.5
	local streak = self:_streaks(4)
	if mode == "glide" then
		local run = 40
		self:_stage(run + 20, F(0, run * 0.5))
		local foe = on(n.drop) and self:_dummy(F(0, run)) or nil
		local ringP = disc(self.fx, 1, F(0, run, 0.2), RED, 1)
		local fall = n.fall or 8
		self.loop = 3.4
		return function(t)
			local k = math.clamp((t - 0.2) / 2.2, 0, 1)
			local y = math.max(0, 22 - fall * (t - 0.2) * 1.0)
			local f = k * run
			local dropT = 1.6
			if foe and t > dropT then
				local d = math.clamp((t - dropT) / 0.25, 0, 1)
				f = (dropT - 0.2) / 2.2 * run + (run - (dropT - 0.2) / 2.2 * run) * d
				y = math.max(0, (22 - fall * (dropT - 0.2)) * (1 - d))
			end
			self:_place(CFrame.new(F(0, f - 6, y)) * CFrame.Angles(y > 0.5 and -0.08 or 0, 0, 0))
			streak(y > 0.5, t)
			if self:_fired(0.4) then self:_pop(lab("FALL %s studs/s", fall), WHITE, self:_local(Vector3.new(0, 5, 0)), 1.2) end
			if foe and self:_fired(dropT + 0.25) then
				foe.part.Color = RED
				self:_pop(on(n.dropMore) and "DROP ATTACK +30%" or "DROP ATTACK", RED, foe.part.Position + Vector3.new(0, 5, 0), 1.2)
			end
			if foe and on(n.bleed) then
				local b = (t - dropT - 0.25) / 0.4
				if b > 0 and b < 1 then ringP.Size = Vector3.new(0.3, 20 * b, 20 * b) ringP.Transparency = 0.4 + 0.6 * b else ringP.Transparency = 1 end
			end
			return run
		end
	end
	local C = math.max(1, math.floor(tonumber(n.charges) or 1))
	local D = tonumber(n.go or n.leap or n.dist) or 40
	if mode == "boost" then D = math.min(D, 140) end
	local start = F(0, -D * C * 0.4)
	local V = math.max(D * C * 0.7 + 20, 36)
	self:_stage(V, start + F(0, D * C * 0.5 + 4))
	local flames, ringP = {}, disc(self.fx, 1, Vector3.zero, YELLOW, 1)
	for i = 1, C do flames[i] = part(self.fx, Vector3.new(1.4, 0.1, 1), CFrame.new(), ORANGE, 1) end
	local hopH = mode == "leap" and math.max(8, D * 0.25) or (n.hop and on(n.hop) and 6 or 0)
	local dur = mode == "leap" and 0.7 or 0.45
	local gap = dur + 0.45
	self.loop = 0.5 + C * gap + 0.9
	return function(t)
		local p, y = start, 0
		for i = 1, C do
			local t0 = 0.5 + (i - 1) * gap
			local a, b = start + F(0, D * (i - 1)), start + F(0, D * i)
			local f = (t - t0) / dur
			if f >= 1 then
				p = b
				strip(flames[i], a + Vector3.new(0, 0.12, 0), b + Vector3.new(0, 0.12, 0), 1.4)
				flames[i].Transparency = mode == "leap" and 1 or math.clamp(0.3 + (t - t0 - dur) / 0.6, 0.3, 1)
			elseif f > 0 then
				local e = mode == "leap" and f or ease(f)
				p = a:Lerp(b, e)
				y = math.sin(math.pi * f) * hopH
				if fx.double and on(n.double) and f > 0.5 then y += math.sin(math.pi * (f - 0.5) * 2) * hopH * 0.6 end
				if mode ~= "leap" then strip(flames[i], a + Vector3.new(0, 0.12, 0), p + Vector3.new(0, 0.12, 0), 1.4) flames[i].Transparency = 0.3 end
				break
			else
				flames[i].Transparency = 1
				break
			end
		end
		self:_place(CFrame.new(p + Vector3.new(0, y, 0)) * CFrame.Angles(y > 0.5 and 0.1 or -0.05, 0, 0))
		streak(mode == "boost" and y < 0.5 and t > 0.5 and t < 0.5 + C * gap, t)
		-- landing slam
		if fx.slam then
			for i = 1, C do
				local tl = 0.5 + (i - 1) * gap + dur
				local k = (t - tl) / 0.35
				if k > 0 and k < 1 and i == C then
					ringP.CFrame = CFrame.new(p + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
					ringP.Size = Vector3.new(0.3, 24 * k, 24 * k)
					ringP.Transparency = 0.4 + 0.6 * k
				elseif i == C then
					ringP.Transparency = 1
				end
				if self:_fired(tl) then
					self:_pop("SLAM -10", RED, self:_local(Vector3.new(0, 5, 0)), 1)
					if on(n.stun) then self:_pop(lab("STUN %s s", n.stun), YELLOW, self:_local(Vector3.new(0, 8, 0)), 1) end
				end
			end
		end
		if fx.text and self:_fired(0.7) then self:_pop(lab(fx.text, n[fx.textKey or "x"]), WHITE, self:_local(Vector3.new(0, 6, 0)), 1.2) end
		return D
	end
end

-- place: something set down. fx.kind: pad (heal circle at your feet), caltrops (spikes behind), portal (two ends + a zip)
function T.place(self, n)
	local fx = fxOf(self)
	local kind = fx.kind
	local mid, H, L = midOf(self)
	local Lh = L * 0.5
	if kind == "pad" then
		local Rr = n.area or 12
		self:_stage(math.max(Rr * 2.4, 30), F(0, 2))
		local pad = disc(self.fx, Rr * 2, Vector3.new(0, 0.2, 0), VENOM_L, 1)
		local ally = self:_ally(F(Rr * 0.5, Rr * 0.3))
		local hold = math.min(n.lasts or 5, 2.6)
		self.loop = 0.6 + hold + 0.8
		return function(t)
			pad.Transparency = (t > 0.4 and t < 0.6 + hold) and (0.55 + 0.1 * math.sin(t * 6)) or 1
			for i = 1, 5 do
				local ti = 0.7 + (i - 1) * 0.55
				if ti < 0.6 + hold and self:_fired(ti) then
					self:_pop("+10%", VENOM_L, (i % 2 == 0 and ally.part.Position or self:_local(Vector3.new(0, 3, 0))) + Vector3.new(0, 4, 0), 0.7)
				end
			end
			return Rr
		end
	elseif kind == "caltrops" then
		local W = n.patch or 10
		local back = F(0, -Lh - W * 0.6)
		self:_stage(math.max(W * 2.4 + L, 36), F(0, -Lh * 0.5))
		local spikes = {}
		for i = 1, math.max(1, n.spikes or 6) do
			local a = i * 2.4
			local r = W * 0.45 * math.sqrt((i % 7 + 1) / 7)
			spikes[i] = part(self.fx, Vector3.new(0.9, 0.9, 0.9), CFrame.new(back + Vector3.new(math.cos(a) * r, 0.4, math.sin(a) * r)) * CFrame.Angles(0.7, 0.7, 0), Color3.fromRGB(210, 215, 225), 1, nil, Enum.Material.Metal)
		end
		local foe = self:_dummy(back + Vector3.new(-W - 8, 0, 0))
		self.loop = 3.4
		return function(t)
			for _, sp in ipairs(spikes) do sp.Transparency = t > 0.4 and (on(n.hidden) and 0.6 or 0) or 1 end
			local k = math.clamp((t - 0.7) / 2.0, 0, 1)
			foe.part.CFrame = CFrame.new(foe.home + Vector3.new((2 * W + 16) * k, 3, 0))
			if self:_fired(1.55) then
				foe.part.Color = RED
				self:_pop("BLEED 3/s", RED, foe.part.Position + Vector3.new(0, 4, 0), 1.2)
				self:_pop("SLOWED 30%", VOLT, foe.part.Position + Vector3.new(0, 7, 0), 1.2)
			end
			if on(n.hidden) and self:_fired(0.6) then self:_pop("HIDDEN FROM ENEMIES", WHITE, back + Vector3.new(0, 5, 0), 1.4) end
			return W
		end
	end
	-- portal: drop one end, run, drop the other; then a squadmate zips along the path
	local D = math.min(n.reach or 185, 70)
	self:_stage(D + 20, F(0, D * 0.5))
	local a, b = F(0, 0, 0.2), F(0, D, 0.2)
	local ends = {disc(self.fx, 8, a, PURPLE, 1), disc(self.fx, 8, b, PURPLE, 1)}
	local path = part(self.fx, Vector3.new(0.6, 0.1, 1), CFrame.new(), PURPLE, 1)
	local ally = self:_ally(F(-6, -6))
	self.loop = 4
	return function(t)
		local run = math.clamp((t - 0.5) / 1.2, 0, 1)
		self:_place(CFrame.new(a:Lerp(b, run) * Vector3.new(1, 0, 1)))
		ends[1].Transparency = t > 0.4 and 0.3 or 1
		ends[2].Transparency = t > 1.75 and 0.3 or 1
		if t > 0.5 then strip(path, a, a:Lerp(b, run), 0.6, 0.1) path.Transparency = 0.4 else path.Transparency = 1 end
		local z = math.clamp((t - 2.0) / 0.35, 0, 1)
		if t > 1.9 then ally.part.CFrame = CFrame.new((t < 2.0 and a or a:Lerp(b, z)) + Vector3.new(0, 3, 0)) end
		if self:_fired(2.0) then self:_pop("5x SPEED, UNTOUCHABLE", ALLY, a + Vector3.new(0, 6, 0), 1.4) end
		if self:_fired(1.8) then self:_pop(lab("OPEN %s s", n.open), PURPLE, b + Vector3.new(0, 6, 0), 1.4) end
		return D
	end
end

-- ---------- dummies, pips ----------
function Clip:_dummy(groundPos)
	local p = part(self.fx, Vector3.new(3, 6, 3), CFrame.new(groundPos + Vector3.new(0, 3, 0)), DUMMY, 0, nil, Enum.Material.SmoothPlastic)
	local d = {part = p, home = groundPos, base = DUMMY}
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
	if self.alphaK and self.alphaK > 0 then self:_alpha(0) end -- v1.1
	local build = r and T[r.template]
	self.frame = build and build(self, r.steps[step]) or function() return 0 end
	self.t, self.lastT = 0, -1
end
function Clip:_reset()
	for _, d in ipairs(self.dummies) do
		d.part.CFrame = CFrame.new(d.home + Vector3.new(0, 3, 0))
		d.part.Color = d.base or DUMMY
	end
	for _, p in ipairs(self.pops) do p.l:Destroy() end
	self.pops = {}
	self:_place(CFrame.new())
	if self.alphaK and self.alphaK > 0 then self:_alpha(0) end -- v1.1
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
