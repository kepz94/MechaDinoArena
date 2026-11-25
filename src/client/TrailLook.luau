-- TrailLook v1.0 (Mecha Dino Arena) — the 10 trail looks (plan docs/plans/TRAILS_v1.0.md; looks from mockup docs/mockups/trails_v0.1.html,
-- Kepu 2026-11-24 23:31 "I love these"). ModuleScript under StarterPlayerScripts, used by TrailFX 1.0 (dinos in the world), ShopScreen 1.2
-- and Lab 1.20 (the walking preview in a ViewportFrame).
-- Two outputs, one set of looks:
--   * world   TL.world(char, id, opts) -> handle; handle:step(dt, soft) every frame. Ribbons are Roblox Trail objects between
--             Attachments on the segment Roots (moved every frame so the band stays upright); prints and bits are anchored local
--             Parts in workspace.TrailFXLocal (CanCollide / CanQuery / CanTouch false, CastShadow false). The trail draws while the
--             dino moves (flat speed > opts.moveSpeed, default 2 studs/s); ribbons stop emitting and fade when it stops.
--   * preview TL.preview(model, id) -> handle; handle:step(dt) walks the model in place (joints moved by hand, no physics in a
--             ViewportFrame) and draws the same look with Parts next to the model (ribbons are part chains: Trail objects don't draw
--             in a ViewportFrame). Everything slides back as if the dino walked forward. handle:destroy() puts the model back.
-- Scale: R.h = the hip height (HumanoidRootPart half height + Humanoid.HipHeight), so every look fits every dino.
-- Soft look (matches): opacity +45%, life x0.6, bits x0.5 (TrailFX passes soft = true on non-hub servers).
-- Bits are capped per dino (opts.maxBits, default 24) and by the caller in total.

local TL = {}
TL.VERSION = "1.0"
-- Studio tuning 2026-11-25 (before the first publish, still 1.0): Trail.MaxLength (7 x h, Comet 5 x h; x0.6 soft) so a running dino
-- never drags a long ribbon; Comet colours deeper and LightEmission 0.45 (it read white in daylight); Neon LightEmission 0.7;
-- leaves x1.5, pixels x1.4, bones and skulls x1.6 (they read as pebbles).

local rnd = function(a, b) return a + math.random() * (b - a) end
local V3, CF = Vector3.new, CFrame.new
local UP = Vector3.yAxis
local RGB = Color3.fromRGB

-- ---------- rig helpers ----------
local function segRoot(model, name)
	local m = model:FindFirstChild(name)
	return m and m:FindFirstChild("Root")
end
local function segBox(model, name) -- {root, lo, hi} in Root space (visible parts only)
	local m = model:FindFirstChild(name)
	local r = m and m:FindFirstChild("Root")
	if not r then return nil end
	local lo, hi
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p ~= r and p.Transparency < 1 then
			local rel = r.CFrame:ToObjectSpace(p.CFrame)
			local s = p.Size / 2
			for i = 0, 7 do
				local c = rel * V3((i % 2 == 1) and s.X or -s.X, (math.floor(i / 2) % 2 == 1) and s.Y or -s.Y, (i >= 4) and s.Z or -s.Z)
				lo = lo and lo:Min(c) or c
				hi = hi and hi:Max(c) or c
			end
		end
	end
	if not lo then lo, hi = V3(-0.5, -0.5, -0.5), V3(0.5, 0.5, 0.5) end
	return {root = r, lo = lo, hi = hi}
end
local function boxCenter(b) return b.root.CFrame * ((b.lo + b.hi) / 2) end
-- the box end farthest from a point (the tail tip, away from the body)
local function boxFar(b, from)
	local c = (b.lo + b.hi) / 2
	local best, bd
	for _, axis in ipairs({"X", "Y", "Z"}) do
		for _, s in ipairs({-1, 1}) do
			local v = V3(axis == "X" and (s < 0 and b.lo.X or b.hi.X) or c.X, axis == "Y" and (s < 0 and b.lo.Y or b.hi.Y) or c.Y,
				axis == "Z" and (s < 0 and b.lo.Z or b.hi.Z) or c.Z)
			local w = b.root.CFrame * v
			local d = (w - from).Magnitude
			if not bd or d > bd then best, bd = w, d end
		end
	end
	return best
end
local function hipOf(model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.HipHeight > 0 then return hrp.Size.Y / 2 + hum.HipHeight end
	if hrp then return hrp.Size.Y * 1.5 end
	return 3
end

-- ---------- part factory ----------
local function mkPart(parent, size, color, mat, shape, transp)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Transparency = transp or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local NEON, GLASS, PLASTIC = Enum.Material.Neon, Enum.Material.Glass, Enum.Material.SmoothPlastic
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder

-- ---------- the core (shared by world and preview) ----------
local Core = {}
Core.__index = Core

local function newCore(model, id, mode, opts)
	opts = opts or {}
	local self = setmetatable({}, Core)
	self.model, self.id, self.mode = model, id, mode
	self.parent = opts.parent
	self.maxBits = opts.maxBits or 24
	self.moveSpeed = opts.moveSpeed or 2
	self.bits, self.stamps, self.ribbons, self.trails = {}, {}, {}, {}
	self.acc, self.dist, self.side, self.t = 0, 0, 1, 0
	self.h = hipOf(model)
	self.boxes = {}
	self.soft = false
	self.conv = Vector3.zero
	return self
end
function Core:box(name)
	local b = self.boxes[name]
	if b == nil then b = segBox(self.model, name) or false self.boxes[name] = b end
	return b or nil
end
function Core:hrp() return self.model:FindFirstChild("HumanoidRootPart") end
function Core:groundY()
	local hrp = self:hrp()
	if not hrp then return 0 end
	return hrp.Position.Y - self.h
end
function Core:fwd()
	local hrp = self:hrp()
	local f = hrp and hrp.CFrame.LookVector or V3(0, 0, -1)
	f = V3(f.X, 0, f.Z)
	return f.Magnitude > 1e-3 and f.Unit or V3(0, 0, -1)
end
-- tail base centre (the emit point for ribbons and most bits)
function Core:tailBase()
	local b = self:box("Tail1") or self:box("Torso")
	if b then return boxCenter(b) end
	local hrp = self:hrp()
	return hrp and (hrp.Position - self:fwd() * self.h) or Vector3.zero
end
function Core:tailTip()
	local b = self:box("Tail5") or self:box("Tail4") or self:box("Tail3") or self:box("Tail1")
	local hrp = self:hrp()
	if b and hrp then return boxFar(b, hrp.Position) end
	return self:tailBase()
end
function Core:bitsCount() return #self.bits end
function Core:alpha(a) -- soft look: more see-through
	return self.soft and math.min(1, a + (1 - a) * 0.45) or a
end
function Core:life(l) return self.soft and l * 0.6 or l end
function Core:rate(r) return self.soft and r * 0.5 or r end

-- a bit: several parts moving together. spec = {parts = {{size, color, mat, shape, off CFrame, transp}}, p, v, life, grav, drag,
-- spin (Vector3 rad/s), bounce, grow, pop, blink, snap, wob, rot CFrame}
function Core:spawnBit(spec)
	if #self.bits >= self.maxBits then return end
	local b = {parts = {}, p = spec.p, v = spec.v or Vector3.zero, life = self:life(spec.life or 1), age = 0, grav = spec.grav or 0,
		drag = spec.drag or 0, spin = spec.spin or Vector3.zero, bounce = spec.bounce or 0, grow = spec.grow or 0, pop = spec.pop,
		blink = spec.blink, snap = spec.snap, wob = spec.wob or 0, ph = math.random() * 7, rot = spec.rot or CFrame.identity, bounced = 0}
	for _, d in ipairs(spec.parts) do
		local part = mkPart(self.parent, d.size, d.color, d.mat, d.shape, 1)
		table.insert(b.parts, {part = part, size = d.size, off = d.off or CFrame.identity, a = self:alpha(d.transp or 0)})
	end
	table.insert(self.bits, b)
end
-- a print flat on the ground: parts laid out in print space (X side, Z forward), turned to yaw
function Core:stampPrint(pos, yaw, parts, life)
	local s = {parts = {}, age = 0, life = self:life(life)}
	local base = CF(pos.X, self:groundY() + 0.03, pos.Z) * CFrame.Angles(0, yaw, 0)
	for _, d in ipairs(parts) do
		local part = mkPart(self.parent, d.size, d.color, d.mat, d.shape, 1)
		part.CFrame = base * (d.off or CFrame.identity)
		table.insert(s.parts, {part = part, a = self:alpha(d.transp or 0)})
	end
	table.insert(self.stamps, s)
end
function Core:stepBits(dt)
	local gy = self:groundY()
	for i = #self.bits, 1, -1 do
		local b = self.bits[i]
		b.age += dt
		local f = b.age / b.life
		if f >= 1 then
			for _, q in ipairs(b.parts) do q.part:Destroy() end
			table.remove(self.bits, i)
		else
			b.v = (b.v - UP * b.grav * dt) * math.max(0, 1 - b.drag * dt)
			b.p = b.p + (b.v + self.conv) * dt
			if b.wob > 0 then b.p = b.p + V3(math.sin(b.age * 5 + b.ph), 0, math.cos(b.age * 4 + b.ph)) * b.wob * dt end
			local half = (b.parts[1] and b.parts[1].size.Y or 0.2) * 0.4
			if b.bounce > 0 and b.p.Y < gy + half and b.v.Y < 0 then
				b.p = V3(b.p.X, gy + half, b.p.Z)
				b.v = V3(b.v.X * 0.6, -b.v.Y * b.bounce, b.v.Z * 0.6)
				b.bounce *= 0.4
			elseif b.p.Y < gy + half and b.grav > 0 then
				b.p = V3(b.p.X, gy + half, b.p.Z)
				b.v = V3(b.v.X * 0.8, 0, b.v.Z * 0.8)
			end
			b.rot = b.rot * CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
			local sc = 1 + b.grow * f
			local fade = math.min(1, b.age / 0.08) * (1 - math.max(0, (f - 0.7) / 0.3))
			if b.pop and f > 0.86 then
				local u = (f - 0.86) / 0.14
				sc *= 1 + 0.5 * u
				fade *= 1 - u
			end
			if b.blink and f > 0.6 and math.floor(b.age * 12 + b.ph) % 2 == 1 then fade *= 0.15 end
			local p = b.p
			if b.snap then
				local k = b.snap
				p = V3(math.round(p.X / k) * k, math.max(gy + half, math.round(p.Y / k) * k), math.round(p.Z / k) * k)
			end
			local base = CF(p) * b.rot
			for _, q in ipairs(b.parts) do
				if sc ~= 1 then q.part.Size = q.size * sc end
				q.part.CFrame = base * (sc ~= 1 and (q.off - q.off.Position + q.off.Position * sc) or q.off)
				q.part.Transparency = 1 - (1 - q.a) * fade
			end
		end
	end
	for i = #self.stamps, 1, -1 do
		local s = self.stamps[i]
		s.age += dt
		local f = s.age / s.life
		if f >= 1 then
			for _, q in ipairs(s.parts) do q.part:Destroy() end
			table.remove(self.stamps, i)
		else
			local fade = math.min(1, s.age / 0.1) * (1 - math.max(0, (f - 0.5) / 0.5))
			for _, q in ipairs(s.parts) do
				q.part.Transparency = 1 - (1 - q.a) * fade
				if self.conv ~= Vector3.zero then q.part.CFrame = q.part.CFrame + self.conv * dt end
			end
		end
	end
end

-- ---------- ribbons ----------
-- spec = {rows = {{lo, hi, color (Color3 or ColorSequence), transp, light}}, life, at = "base" | "tip", up = height above the
-- emit point (x h), down = height below (x h), floor = clamp the bottom to the ground}
-- world: one Roblox Trail per row; preview: a chain of thin parts per row.
function Core:addRibbon(spec)
	local r = {spec = spec, rows = {}}
	if self.mode == "world" then
		local root = segRoot(self.model, "Tail1") or self:hrp()
		for _, row in ipairs(spec.rows) do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "TrailLookA0", "TrailLookA1"
			a0.Parent, a1.Parent = root, root
			local tr = Instance.new("Trail")
			tr.Name = "TrailLook"
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.FaceCamera = false
			tr.MinLength = 0.05
			tr.MaxLength = self.h * (spec.maxLen or 7) -- a fast dino never drags a ribbon longer than this
			tr.LightEmission = row.light or 0
			tr.Color = typeof(row.color) == "ColorSequence" and row.color or ColorSequence.new(row.color)
			tr.Enabled = false
			tr.Parent = root
			table.insert(r.rows, {a0 = a0, a1 = a1, trail = tr, row = row})
		end
	else
		for _, row in ipairs(spec.rows) do table.insert(r.rows, {pts = {}, pool = {}, row = row}) end
	end
	table.insert(self.ribbons, r)
	return r
end
local function seqColor(c, f)
	if typeof(c) ~= "ColorSequence" then return c end
	local k = c.Keypoints
	for i = 1, #k - 1 do
		if f <= k[i + 1].Time then
			local u = (f - k[i].Time) / math.max(1e-4, k[i + 1].Time - k[i].Time)
			return k[i].Value:Lerp(k[i + 1].Value, u)
		end
	end
	return k[#k].Value
end
function Core:stepRibbons(dt, moving)
	for _, r in ipairs(self.ribbons) do
		local sp = r.spec
		local at = sp.at == "tip" and self:tailTip() or self:tailBase()
		local top = at + UP * (sp.up or 0.2) * self.h
		local bot = at - UP * (sp.down or 0.2) * self.h
		if sp.floor then bot = V3(bot.X, math.max(bot.Y, self:groundY() + 0.05), bot.Z) end
		local life = self:life(sp.life or 0.8)
		for _, rw in ipairs(r.rows) do
			local row = rw.row
			local p1, p0 = bot:Lerp(top, row.hi), bot:Lerp(top, row.lo)
			if self.mode == "world" then
				rw.a0.WorldPosition, rw.a1.WorldPosition = p1, p0
				rw.trail.Lifetime = life
				rw.trail.MaxLength = self.h * (sp.maxLen or 7) * (self.soft and 0.6 or 1)
				local a = self:alpha(row.transp or 0)
				rw.trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, 1)})
				rw.trail.Enabled = moving
			else
				local now = self.t
				if moving then table.insert(rw.pts, {a = p1, b = p0, t = now}) end
				for i = #rw.pts, 1, -1 do
					local q = rw.pts[i]
					if now - q.t > life then table.remove(rw.pts, i)
					else q.a += self.conv * dt q.b += self.conv * dt end
				end
				-- one thin part between each pair of samples
				local n = #rw.pts
				for i = 1, math.max(n - 1, 0) do
					local qa, qb = rw.pts[i], rw.pts[i + 1]
					local part = rw.pool[i]
					if not part then
						part = mkPart(self.parent, V3(0.1, 0.1, 0.1), RGB(255, 255, 255), row.light and row.light > 0.5 and NEON or PLASTIC, nil, 1)
						rw.pool[i] = part
					end
					local ma, mb = (qa.a + qa.b) / 2, (qb.a + qb.b) / 2
					local len = (mb - ma).Magnitude
					local hgt = ((qa.a - qa.b).Magnitude + (qb.a - qb.b).Magnitude) / 2
					if len > 1e-3 then
						local age = (now - qa.t) / life
						part.Size = V3(math.max(0.02, self.h * 0.03), math.max(0.02, hgt), len + 0.02)
						part.CFrame = CFrame.lookAt((ma + mb) / 2, mb)
						part.Color = seqColor(row.color, math.clamp(age, 0, 1))
						part.Transparency = 1 - (1 - self:alpha(row.transp or 0)) * (1 - math.clamp(age, 0, 1)) ^ 1.2
					else
						part.Transparency = 1
					end
				end
				for i = math.max(n, 1), #rw.pool do rw.pool[i].Transparency = 1 end
			end
		end
	end
end

-- ---------- prints (made of parts, in print space: Z = toes forward, X = side) ----------
local function dinoPrint(h, color, mat, glow)
	local s = h * 0.62
	local d = {}
	table.insert(d, {size = V3(s * 0.34, 0.06, s * 0.36), color = color, mat = mat, off = CF(0, 0, s * 0.12)})
	for _, a in ipairs({-0.5, 0, 0.5}) do
		table.insert(d, {size = V3(s * 0.11, 0.06, s * 0.46), color = color, mat = mat,
			off = CFrame.Angles(0, a, 0) * CF(0, 0, -s * 0.2)})
	end
	if glow then table.insert(d, {size = V3(s * 0.9, 0.02, s * 0.9), color = glow, mat = NEON, transp = 0.8, off = CF(0, -0.01, 0)}) end
	return d
end

-- ---------- the 10 looks ----------
local LOOKS = {}
LOOKS.neon = {
	start = function(c) c:addRibbon({rows = {{lo = 0, hi = 1, color = RGB(90, 220, 255), transp = 0.15, light = 0.7}}, life = 0.9, up = 0.2, down = 0.2}) end,
}
LOOKS.fossil = {
	plant = function(c, pos, yaw)
		c:stampPrint(pos, yaw, dinoPrint(c.h, RGB(246, 238, 214), NEON, RGB(255, 200, 96)), 4.5)
	end,
}
LOOKS.comet = {
	start = function(c)
		c:addRibbon({rows = {{lo = 0, hi = 1, color = ColorSequence.new({ColorSequenceKeypoint.new(0, RGB(255, 200, 70)),
			ColorSequenceKeypoint.new(0.4, RGB(255, 110, 30)), ColorSequenceKeypoint.new(1, RGB(200, 40, 20))}), transp = 0.05, light = 0.45}},
			life = 0.6, at = "tip", up = 0.16, down = 0.16, maxLen = 5})
	end,
	tick = function(c, dt)
		c.acc += dt * c:rate(22)
		while c.acc > 1 do
			c.acc -= 1
			local tip = c:tailTip()
			local h = c.h
			c:spawnBit({parts = {{size = V3(1, 1, 1) * h * rnd(0.12, 0.22), color = math.random() < 0.5 and RGB(255, 138, 46) or RGB(255, 210, 74), mat = NEON, shape = BALL}},
				p = tip + V3(rnd(-0.2, 0.2), rnd(-0.2, 0.2), rnd(-0.2, 0.2)) * h, v = V3(rnd(-1, 1), rnd(0.5, 2), rnd(-1, 1)) * h * 0.5,
				life = rnd(0.3, 0.6), grow = -0.6})
			if math.random() < 0.12 then
				c:spawnBit({parts = {{size = V3(1, 1, 1) * h * 0.08, color = RGB(90, 70, 54), mat = Enum.Material.Slate}}, p = tip,
					v = V3(rnd(-1, 1), rnd(1, 2.5), rnd(-1, 1)) * h * 0.6, life = 1, grav = h * 9, bounce = 0.3,
					spin = V3(rnd(-6, 6), rnd(-6, 6), rnd(-6, 6))})
			end
		end
	end,
}
LOOKS.rainbow = {
	start = function(c)
		local cols = {RGB(138, 91, 255), RGB(59, 184, 255), RGB(70, 224, 138), RGB(255, 226, 59), RGB(255, 155, 46), RGB(255, 59, 59)}
		local rows = {}
		for i, col in ipairs(cols) do table.insert(rows, {lo = (i - 1) / 6, hi = i / 6, color = col, transp = 0.05, light = 0.3}) end
		c:addRibbon({rows = rows, life = 1.1, up = 0.1, down = 0.4, floor = true})
	end,
}
LOOKS.bolt = {
	start = function(c)
		c:addRibbon({rows = {{lo = 0, hi = 1, color = ColorSequence.new(RGB(255, 255, 255), RGB(127, 233, 255)), transp = 0, light = 1}},
			life = 0.5, up = 0.05, down = 0.05})
		c.hist = {}
		c.jit = 0
	end,
	tick = function(c, dt)
		local h = c.h
		local base = c:tailBase() - UP * 0.25 * h
		local last = c.hist[#c.hist]
		if not last or (last - base).Magnitude > h * 0.3 then table.insert(c.hist, base) end
		while #c.hist > 7 do table.remove(c.hist, 1) end
		for i = 1, #c.hist do c.hist[i] += c.conv * dt end
		c.jit -= dt
		if c.jit <= 0 and #c.hist >= 2 then
			c.jit = 0.07
			-- a jagged neon line along the recent path, lives one flash
			for i = 1, #c.hist - 1 do
				local a = c.hist[i] + V3(rnd(-1, 1), rnd(-0.5, 0.5), rnd(-1, 1)) * h * 0.12
				local b = c.hist[i + 1] + V3(rnd(-1, 1), rnd(-0.5, 0.5), rnd(-1, 1)) * h * 0.12
				local len = (b - a).Magnitude
				if len > 1e-3 then
					c:spawnBit({parts = {{size = V3(h * 0.05, h * 0.05, len), color = RGB(191, 246, 255), mat = NEON}},
						p = (a + b) / 2, rot = CFrame.lookAt(Vector3.zero, b - a) - Vector3.zero, life = 0.09})
				end
			end
			if math.random() < 0.5 then
				c:spawnBit({parts = {{size = V3(1, 1, 1) * h * 0.08, color = RGB(255, 255, 255), mat = NEON, shape = BALL}},
					p = c.hist[#c.hist], v = V3(rnd(-1, 1), rnd(0, 1.5), rnd(-1, 1)) * h, life = 0.25})
			end
		end
	end,
}
LOOKS.lava = {
	plant = function(c, pos, yaw)
		local h = c.h
		c:stampPrint(pos, yaw, dinoPrint(h * 1.15, RGB(255, 140, 40), NEON, RGB(255, 70, 20)), 2.6)
		for _ = 1, math.max(1, math.floor(c:rate(4))) do
			c:spawnBit({parts = {{size = V3(1, 1, 1) * h * rnd(0.06, 0.1), color = math.random() < 0.5 and RGB(255, 122, 31) or RGB(255, 192, 74), mat = NEON, shape = BALL}},
				p = pos + V3(rnd(-0.2, 0.2) * h, h * 0.1, rnd(-0.2, 0.2) * h), v = V3(rnd(-0.3, 0.3), rnd(1, 2.2), rnd(-0.3, 0.3)) * h * 0.6,
				life = rnd(0.7, 1.3), wob = h * 0.6})
		end
		if math.random() < c:rate(0.6) then
			c:spawnBit({parts = {{size = V3(1, 1, 1) * h * 0.3, color = RGB(58, 51, 48), shape = BALL, transp = 0.45}},
				p = pos + UP * h * 0.15, v = UP * h * 0.5, life = 1.4, grow = 1.4})
		end
	end,
}
LOOKS.leaf = {
	tick = function(c, dt)
		c.acc += dt * c:rate(9)
		while c.acc > 1 do
			c.acc -= 1
			local h = c.h
			local col = ({RGB(155, 224, 90), RGB(95, 191, 74), RGB(63, 154, 69), RGB(200, 216, 74)})[math.random(1, 4)]
			c:spawnBit({parts = {{size = V3(h * 0.34, h * 0.03, h * 0.18), color = col}},
				p = c:tailBase() + V3(rnd(-0.3, 0.3), rnd(-0.2, 0.2), rnd(-0.3, 0.3)) * h, v = V3(rnd(-1, 1), rnd(1.2, 2.4), rnd(-1, 1)) * h * 0.55,
				life = rnd(1.4, 2.2), grav = h * 1.4, drag = 1.6, spin = V3(rnd(-5, 5), rnd(-5, 5), rnd(-5, 5)), wob = h * 1.2,
				rot = CFrame.Angles(rnd(0, 6), rnd(0, 6), 0)})
		end
	end,
}
LOOKS.bubble = {
	tick = function(c, dt)
		c.acc += dt * c:rate(6)
		while c.acc > 1 do
			c.acc -= 1
			local h = c.h
			local col = ({RGB(255, 255, 255), RGB(217, 246, 255), RGB(255, 214, 244)})[math.random(1, 3)]
			c:spawnBit({parts = {{size = V3(1, 1, 1) * h * rnd(0.2, 0.36), color = col, mat = GLASS, shape = BALL, transp = 0.55}},
				p = c:tailBase() + V3(rnd(-0.3, 0.3), rnd(0, 0.4), rnd(-0.3, 0.3)) * h, v = V3(rnd(-0.3, 0.3), rnd(0.6, 1.1), rnd(-0.3, 0.3)) * h * 0.6,
				life = rnd(1.1, 1.8), drag = 0.4, wob = h * 0.8, pop = true})
		end
	end,
}
LOOKS.pixel = {
	tick = function(c, dt)
		c.acc += dt * c:rate(16)
		while c.acc > 1 do
			c.acc -= 1
			local h = c.h
			local col = ({RGB(255, 200, 50), RGB(127, 233, 255), RGB(255, 90, 138), RGB(70, 224, 138)})[math.random(1, 4)]
			c:spawnBit({parts = {{size = V3(1, 1, 1) * h * 0.18, color = col, mat = NEON}},
				p = c:tailBase() + V3(rnd(-0.3, 0.3), rnd(-0.3, 0.3), rnd(-0.3, 0.3)) * h, v = V3(rnd(-0.4, 0.4), rnd(0.2, 0.8), rnd(-0.4, 0.4)) * h * 0.5,
				life = rnd(0.8, 1.3), grav = h * 1.5, snap = h * 0.18, blink = true})
		end
	end,
}
LOOKS.bones = {
	tick = function(c, dt)
		c.acc += dt * c:rate(4.5)
		while c.acc > 1 do
			c.acc -= 1
			local h = c.h
			local bone, skull = RGB(245, 239, 224), RGB(236, 229, 210)
			local parts
			if math.random() < 0.18 then -- a skull: round top, jaw block, two dark eyes
				local s = h * 0.32
				parts = {{size = V3(s, s, s), color = skull, shape = BALL},
					{size = V3(s * 0.7, s * 0.35, s * 0.6), color = skull, off = CF(0, -s * 0.45, -s * 0.05)},
					{size = V3(s * 0.2, s * 0.2, s * 0.1), color = RGB(43, 36, 24), off = CF(-s * 0.22, s * 0.02, -s * 0.46)},
					{size = V3(s * 0.2, s * 0.2, s * 0.1), color = RGB(43, 36, 24), off = CF(s * 0.22, s * 0.02, -s * 0.46)}}
			else -- a bone: a shaft and two knobs each end
				local L, w = h * 0.58, h * 0.11
				parts = {{size = V3(L, w, w), color = bone}}
				for _, x in ipairs({-L / 2, L / 2}) do
					for _, z in ipairs({-w * 0.6, w * 0.6}) do
						table.insert(parts, {size = V3(w * 1.4, w * 1.4, w * 1.4), color = bone, shape = BALL, off = CF(x, 0, z)})
					end
				end
			end
			c:spawnBit({parts = parts, p = c:tailBase(), v = V3(rnd(-1, 1), rnd(1.6, 2.6), rnd(-1, 1)) * h * 0.55, life = 1.6,
				grav = h * 7, bounce = 0.45, spin = V3(rnd(-8, 8), rnd(-8, 8), rnd(-8, 8)), rot = CFrame.Angles(rnd(0, 6), rnd(0, 6), 0)})
		end
	end,
}
TL.LOOKS = LOOKS

-- ---------- stepping ----------
-- prints: one every stride of travel, under the lower foot
function Core:stepLook(dt, moving, travelled)
	self.t += dt
	local look = LOOKS[self.id]
	if not look then return end
	if look.start and not self.started then self.started = true look.start(self) end
	if moving then
		if look.tick then look.tick(self, dt) end
		if look.plant then
			self.dist += travelled
			local stride = self.h * 1.1
			if self.dist >= stride then
				self.dist = 0
				local fl, fr = segRoot(self.model, "FootL"), segRoot(self.model, "FootR")
				local foot = (fl and fr) and ((fl.Position.Y < fr.Position.Y) and fl or fr) or fl or fr
				local hrp = self:hrp()
				local pos = foot and foot.Position or (hrp and hrp.Position) or Vector3.zero
				local f = self:fwd()
				look.plant(self, pos, math.atan2(-f.X, -f.Z))
			end
		end
	end
	self:stepRibbons(dt, moving)
	self:stepBits(dt)
end
function Core:clear()
	for _, b in ipairs(self.bits) do for _, q in ipairs(b.parts) do q.part:Destroy() end end
	for _, s in ipairs(self.stamps) do for _, q in ipairs(s.parts) do q.part:Destroy() end end
	for _, r in ipairs(self.ribbons) do
		for _, rw in ipairs(r.rows) do
			if rw.trail then rw.trail:Destroy() rw.a0:Destroy() rw.a1:Destroy() end
			if rw.pool then for _, p in ipairs(rw.pool) do p:Destroy() end end
		end
	end
	self.bits, self.stamps, self.ribbons = {}, {}, {}
end

-- ---------- world handle ----------
-- opts = {parent = Folder for local parts, maxBits, moveSpeed}
function TL.world(char, id, opts)
	if not LOOKS[id] then return nil end
	local c = newCore(char, id, "world", opts)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	c.lastPos = hrp and hrp.Position
	local h = {core = c}
	function h:step(dt, soft)
		c.soft = soft == true
		local r = c:hrp()
		if not r then return end
		local p = r.Position
		local flat = c.lastPos and V3(p.X - c.lastPos.X, 0, p.Z - c.lastPos.Z).Magnitude or 0
		c.lastPos = p
		local moving = dt > 0 and flat / dt > c.moveSpeed and flat / dt < 400 -- 400: a teleport is not a walk
		c:stepLook(dt, moving, moving and flat or 0)
	end
	function h:bits() return #c.bits + #c.stamps end
	function h:destroy() c:clear() end
	return h
end

-- ---------- preview handle (ViewportFrame) ----------
local function walkPose(ph, a, t, h)
	local P = {}
	local function add(n, rx, ry, rz, tx, ty, tz)
		local o = P[n] or {0, 0, 0, 0, 0, 0}
		o[1] += rx or 0 o[2] += ry or 0 o[3] += rz or 0 o[4] += tx or 0 o[5] += ty or 0 o[6] += tz or 0
		P[n] = o
	end
	local s, c = math.sin, math.cos
	add("RootJoint", 2 * s(ph) * a, 0, -3 * a, 0, 0.035 * h * math.abs(s(ph)) * a, 0)
	for side, q in pairs({L = ph, R = ph + math.pi}) do
		add("Leg" .. side, 0, 0, 28 * s(q) * a)
		add("Knee" .. side, 0, 0, -42 * math.max(0, c(q)) * a - 6 * a)
		add("Ankle" .. side, 0, 0, 18 * math.max(0, c(q)) * a)
		add("Arm" .. side, 0, 0, 10 * s(q + math.pi) * a)
	end
	add("Neck", 0, 0, 4 * a - 3 * math.abs(s(ph)) * a)
	add("Head", 0, 0, 2 * math.abs(s(ph)) * a)
	for k = 1, 5 do add("Tail" .. k, 0, (5 + k) * s(ph - k * 0.55) * a, k == 1 and 4 * a or 0) end
	local out = {}
	for n, o in pairs(P) do
		out[n] = CF(o[4], o[5], o[6]) * CFrame.fromEulerAnglesXYZ(math.rad(o[1]), math.rad(o[2]), math.rad(o[3]))
	end
	return out
end

function TL.preview(model, id, opts)
	opts = opts or {}
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local parent = opts.parent or model.Parent
	local c = newCore(model, id, "preview", {parent = parent, maxBits = opts.maxBits or 40})
	-- the joint chain (as ShopScreen 1.1's emote preview)
	local js = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then table.insert(js, d) end
	end
	local done, order = {[hrp] = true}, {}
	for _ = 1, 40 do
		if #order >= #js then break end
		for _, m in ipairs(js) do
			if not done[m.Part1] and done[m.Part0] then table.insert(order, {m = m, c0 = m.C0, c1i = m.C1:Inverse()}) done[m.Part1] = true end
		end
	end
	local parts = {}
	for _, j in ipairs(order) do
		local r = j.m.Part1
		local l = {}
		for _, p in ipairs(r.Parent:GetChildren()) do
			if p:IsA("BasePart") then table.insert(l, {p, r.CFrame:ToObjectSpace(p.CFrame)}) end
		end
		parts[r] = l
	end
	local base = hrp.CFrame
	local function apply(pose)
		local W = {[hrp] = base}
		for _, j in ipairs(order) do
			local m = j.m
			local w0 = W[m.Part0]
			if w0 then
				local w1 = w0 * j.c0 * (pose[m.Name] or CFrame.identity) * j.c1i
				W[m.Part1] = w1
				for _, e in ipairs(parts[m.Part1]) do e[1].CFrame = w1 * e[2] end
			end
		end
	end
	local ph, clock = 0, 0
	local h = {core = c}
	function h:step(dt)
		dt = math.min(dt, 0.05)
		clock += dt
		local v = c.h * 2.4
		ph += v * dt / (c.h * 2.6) * math.pi
		apply(walkPose(ph, 1, clock, c.h))
		c.conv = -c:fwd() * v
		c:stepLook(dt, true, v * dt)
	end
	function h:destroy()
		c:clear()
		pcall(apply, {})
	end
	return h
end

return TL
