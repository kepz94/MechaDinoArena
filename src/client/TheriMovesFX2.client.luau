-- TheriMovesFX2 v1.0 (Mecha Dino Arena) — client effects for the Therizinosaurus' reworked moves (every client draws them for
-- every therizino). Plan docs/plans/THERIZINO_MOVES_REWORK_v1.0.md (MDA-264); server TheriMovesServer 1.4; looks
-- TheriPartsLooksV2 1.2 (Reaper Launcher, Storm Core). Timings and shapes = the storyboard tools/mockup/therizino_moves_anim.js
-- v0.3 (U = 2 x scale studs per storyboard unit). t = server now - the stamp.
--   * Reaper Vortex (TheriVortexAt; TheriVortexCenter / TheriVortexRadius / TheriVortexStart / TheriFieldUntil): 0.48..0.75 six red
--     cracks race out from the centre to the ring's edge (dust puffs 0.48..1.1); 0.7..0.95 a soft red disc, a red edge ring and a
--     3-arm spiral grow to the radius (the spiral turns at -2.2 rad/s); 0.58..0.95 six bone sickles (red edge, brass hub) fly
--     from the wrist cuffs (ArmL_hand / ArmR_hand) out to the ring, orbit it at 3.2 rad/s while it lasts, then fly back over
--     0.35 s; every dino inside drips blood. All fade at the end.
--   * Bola (TheriBolaAt; TheriBolaTarget / TheriBolaEnd / TheriBolaFlight / TheriBolaResult): 0.05..0.55 the bola (two brass
--     weights, an orange core each, a wire) whirls at the tail tip (Tail5_main) on its wire; 0.55..0.6 + flight it arcs (4 U
--     high) to the target's feet (or TheriBolaEnd); "hit" -> four wire loops wrap the legs, a "HELD" tag, until
--     TheriSnaredUntil, then they drop; a miss -> it lands and fades.
--   * Dash (TheriDashAt; TheriDashFrom / TheriDashTo / TheriDashDelay / TheriDashTime): while charging, lightning arcs between
--     the Storm Core's hornL, hornR and core pieces; the dino flashes yellow-white (Highlight) around the jolt; two lightning
--     bolts along the path and three yellow afterimages (copies of the dino's visible parts) at 1/4, 1/2, 3/4; on landing a
--     yellow shock ring and three sparks to the ground.
--   * Reaper Reel (TheriReelAt; TheriReelTarget / TheriReelEnd / TheriReelBrace / TheriReelFly / TheriReelTime /
--     TheriReelResult): after the brace a copy of the launcher's claw (its "hookhead" pieces; TheriPartsAnim hides the real ones)
--     flies on a chain from the "muzzle" to the target (fly s), stays clamped on it while the drum reels the dino in (speed
--     lines), then two white claw arcs (the slash) and a red flash on the target (TheriReelHitAt), and the claw reels back into
--     the muzzle (0.22..0.5 s after the end). No target / blocked -> out to TheriReelEnd and back.
-- Everything lives in Workspace.DinoFX_Local.TheriMovesFX2 (anchored, no collision / query / touch). Switches: script attributes
-- TheriMovesFX2Enabled, TheriMovesFX2_<vortex | bola | dash | reel>Enabled (default true; read at each event). Diagnostics:
-- script TheriMovesFX2Version, TheriMovesFX2Events (count), TheriMovesFX2Last.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("TheriMovesFX2Version", VERSION)
script:SetAttribute("TheriMovesFX2Events", 0)
for _, k in ipairs({"TheriMovesFX2Enabled", "TheriMovesFX2_vortexEnabled", "TheriMovesFX2_bolaEnabled", "TheriMovesFX2_dashEnabled",
	"TheriMovesFX2_reelEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(k) return script:GetAttribute("TheriMovesFX2Enabled") ~= false and script:GetAttribute("TheriMovesFX2_" .. k .. "Enabled") ~= false end
local function note(s)
	script:SetAttribute("TheriMovesFX2Events", (script:GetAttribute("TheriMovesFX2Events") or 0) + 1)
	script:SetAttribute("TheriMovesFX2Last", s)
end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function clamp01(u) return math.clamp(u, 0, 1) end
local function seg(t, a, b) return clamp01((t - a) / (b - a)) end
local function easeOut(u) u = clamp01(u) return 1 - (1 - u) ^ 3 end
local function easeIn(u) u = clamp01(u) return u * u end

local RED, RED_SOFT, BONE, BRASS = Color3.fromRGB(255, 59, 48), Color3.fromRGB(192, 24, 42), Color3.fromRGB(226, 220, 203), Color3.fromRGB(201, 162, 74)
local WIRE, ORANGE, YELLOW, PALE = Color3.fromRGB(223, 230, 238), Color3.fromRGB(255, 138, 26), Color3.fromRGB(255, 194, 26), Color3.fromRGB(255, 251, 224)
local DUST, STEEL, DARK = Color3.fromRGB(216, 201, 160), Color3.fromRGB(184, 192, 200), Color3.fromRGB(109, 115, 124)

local folder
local function fx()
	if folder and folder.Parent then return folder end
	local root = workspace:FindFirstChild("DinoFX_Local")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX_Local"
		root.Parent = workspace
	end
	folder = root:FindFirstChild("TheriMovesFX2") or Instance.new("Folder")
	folder.Name = "TheriMovesFX2"
	folder.Parent = root
	return folder
end
local function part(size, color, mat, transp, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.SmoothPlastic
	p.Transparency = transp or 0
	if shape then p.Shape = shape end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = fx()
	return p
end
local function hide(p) p.Transparency = 1 end
local function kill(list) for _, p in ipairs(list) do if typeof(p) == "Instance" then p:Destroy() end end end
local function setSeg(p, a, b, th) -- a box from a to b
	local d = b - a
	if d.Magnitude < 1e-3 then p.Transparency = 1 return end
	p.Size = Vector3.new(th, th, d.Magnitude)
	p.CFrame = CFrame.lookAt(a + d / 2, b)
end
local function zpiece(char, id, role)
	local m = char:FindFirstChild("ZPart_" .. id)
	if m then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("ZPartRole") == role then return p end
		end
	end
	return nil
end
local function bodyPart(char, name)
	local p = char:FindFirstChild(name, true)
	return (p and p:IsA("BasePart")) and p or nil
end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(pos, fallback)
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	for _, n in ipairs({"DinoFX_Local", "DinoFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rp.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), rp)
	return hit and hit.Position.Y or fallback
end
local function findModel(name)
	if type(name) ~= "string" or name == "" then return nil end
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character and pl.Character.Name == name then return pl.Character end end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	local m = bots and bots:FindFirstChild(name)
	if not m then m = workspace:FindFirstChild(name, true) end
	return (m and m:IsA("Model")) and m or nil
end
local function flash(model, color, dur, peak)
	if not model then return end
	local h = Instance.new("Highlight")
	h.FillColor, h.OutlineColor = color, color
	h.FillTransparency, h.OutlineTransparency = 1, 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = fx()
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / dur
		if k >= 1 or not model.Parent then
			conn:Disconnect()
			h:Destroy()
			return
		end
		local a = 1 - math.abs(k * 2 - 1)
		h.FillTransparency = 1 - (peak or 0.7) * a
		h.OutlineTransparency = 1 - a
	end)
end
-- a ring of n boxes (radius r, flat on the XZ plane of cf)
local function ringParts(n, color, mat, transp)
	local list = {}
	for i = 1, n do list[i] = part(Vector3.one * 0.2, color, mat, transp) end
	return list
end
local function placeRing(list, cf, r, th, height)
	local n = #list
	local len = 2 * math.pi * r / n * 1.08
	for i, p in ipairs(list) do
		local a = (i - 0.5) / n * 2 * math.pi
		p.Size = Vector3.new(th, height, math.max(0.05, len))
		p.CFrame = cf * CFrame.Angles(0, -a, 0) * CFrame.new(r, 0, 0)
	end
end
-- lightning: n segments (core + glow) from a to b, jagged by amp, re-randomised by seed
local function newBolt(n)
	local b = {core = {}, glow = {}}
	for i = 1, n do
		b.core[i] = part(Vector3.one * 0.1, PALE, Enum.Material.Neon, 0)
		b.glow[i] = part(Vector3.one * 0.1, YELLOW, Enum.Material.Neon, 0.6)
	end
	return b
end
local function rnd(n) local x = math.sin(n * 127.1 + 311.7) * 43758.5453 return x - math.floor(x) end
local function drawBolt(b, a, c, amp, seed, th)
	local n = #b.core
	local d = c - a
	if d.Magnitude < 1e-3 then return end
	local side = d:Cross(Vector3.yAxis)
	side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
	local up2 = side:Cross(d).Unit
	local prev = a
	for i = 1, n do
		local u, j = i / n, (i == n) and 0 or 1
		local p = a + d * u + side * ((rnd(seed * 13 + i) - 0.5) * 2 * amp * j) + up2 * ((rnd(seed * 7 + i * 3) - 0.5) * 2 * amp * j)
		b.core[i].Transparency, b.glow[i].Transparency = 0, 0.6
		setSeg(b.core[i], prev, p, th)
		setSeg(b.glow[i], prev, p, th * 3.5)
		prev = p
	end
end
local function hideBolt(b) for i = 1, #b.core do b.core[i].Transparency, b.glow[i].Transparency = 1, 1 end end
local function killBolt(b) kill(b.core) kill(b.glow) end
local function puffSet(n) local l = {} for i = 1, n do l[i] = part(Vector3.one, DUST, Enum.Material.SmoothPlastic, 1, Enum.PartType.Ball) end return l end
local function drawPuffs(list, centre, k, spread, U)
	for i, m in ipairs(list) do
		if k <= 0 or k >= 1 then m.Transparency = 1 else
			local a = i / #list * math.pi * 2 + i
			m.Size = Vector3.one * (0.6 + k * 1.2) * U
			m.CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * spread * k * U, (0.3 + k * 0.8 + (i % 3) * 0.15) * U, math.sin(a) * spread * k * U))
			m.Transparency = 0.3 + 0.7 * k
		end
	end
end

-- Reaper Vortex ----------------------------------------------------------------------------------------------------------------
local function sickle(U)
	local g = {}
	g.blade = part(Vector3.new(1.5, 0.12, 0.42) * 1.8 * U / 2, BONE)
	g.tip = part(Vector3.new(0.45, 0.12, 0.3) * 1.8 * U / 2, BONE)
	g.edge = part(Vector3.new(1.5, 0.13, 0.06) * 1.8 * U / 2, RED, Enum.Material.Neon)
	g.hub = part(Vector3.one * 0.32 * 1.8 * U / 2, BRASS, Enum.Material.Metal, 0, Enum.PartType.Ball)
	return g
end
local function placeSickle(g, cf, k) -- cf = the sickle's frame (Y up); k = sickle scale unit (1.8 x U / 2)
	g.blade.CFrame = cf * CFrame.new(0.5 * k, 0, 0)
	g.tip.CFrame = cf * CFrame.new(1.35 * k, 0, -0.25 * k) * CFrame.Angles(0, 0.6, 0)
	g.edge.CFrame = cf * CFrame.new(0.5 * k, 0, -0.22 * k)
	g.hub.CFrame = cf
end
local function sickleShow(g, v) for _, p in pairs(g) do p.Transparency = v and 0 or 1 end end
local function vortex(char)
	local at = num(char, "TheriVortexAt", 0)
	local c = char:GetAttribute("TheriVortexCenter")
	if typeof(c) ~= "Vector3" then return end
	local s = char:GetScale()
	local U = 2 * s
	local R = num(char, "TheriVortexRadius", 15)
	local start = num(char, "TheriVortexStart", at + 0.95) - at
	local stop = num(char, "TheriFieldUntil", at + 4) - at
	local cracks = {}
	for i = 1, 6 do cracks[i] = part(Vector3.one, RED, Enum.Material.Neon, 1) end
	local dust = puffSet(10)
	local disc = part(Vector3.new(0.1, 1, 1), RED_SOFT, Enum.Material.Neon, 1, Enum.PartType.Cylinder)
	local edge = ringParts(40, RED, Enum.Material.Neon, 1)
	local spiral = {}
	for arm = 0, 2 do
		for i = 0, 13 do table.insert(spiral, {p = part(Vector3.one, RED, Enum.Material.Neon, 1), arm = arm, u = i / 14}) end
	end
	local sickles = {}
	for i = 1, 6 do sickles[i] = sickle(U) sickleShow(sickles[i], false) end
	local drops = {}
	for i = 1, 16 do drops[i] = part(Vector3.one * 0.35 * U / 2, RED_SOFT, Enum.Material.Neon, 1, Enum.PartType.Ball) end
	local cuffL, cuffR = bodyPart(char, "ArmL_hand"), bodyPart(char, "ArmR_hand")
	local floor = CFrame.new(c)
	local victims, nextScan = {}, 0
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = now() - at
		if t > stop + 0.45 or not char.Parent or num(char, "TheriVortexAt", at) ~= at then
			conn:Disconnect()
			kill(cracks) kill(dust) disc:Destroy() kill(edge) kill(drops)
			for _, e in ipairs(spiral) do e.p:Destroy() end
			for _, g in ipairs(sickles) do for _, p in pairs(g) do p:Destroy() end end
			return
		end
		local fade = 1 - seg(t, stop, stop + 0.1)
		-- cracks
		local kc = seg(t, 0.48, 0.75)
		for i, m in ipairs(cracks) do
			local a = (i - 1) / 6 * math.pi * 2 + 0.3
			local L = R * kc
			if t > 0.48 and t < stop and L > 0.05 then
				m.Transparency = 0.1 + 0.9 * (1 - fade)
				m.Size = Vector3.new(L, 0.08 * U, 0.16 * U)
				m.CFrame = floor * CFrame.Angles(0, -a, 0) * CFrame.new(L / 2, 0.04 * U, 0)
			else
				m.Transparency = 1
			end
		end
		drawPuffs(dust, c, seg(t, 0.48, 1.1), 2.2, U)
		-- disc, edge ring, spiral
		local grow = seg(t, 0.7, 0.95)
		local shown = t > 0.7 and t < stop + 0.1 and grow > 0
		if shown then
			disc.Size = Vector3.new(0.06, 2 * R * grow, 2 * R * grow)
			disc.CFrame = floor * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
			disc.Transparency = 1 - 0.25 * fade
			placeRing(edge, floor * CFrame.new(0, 0.1, 0), R * grow, 0.08 * R / 15 * 2 + 0.3, 0.12)
			for _, p in ipairs(edge) do p.Transparency = 1 - 0.9 * fade end
			local spin = -t * 2.2
			for _, e in ipairs(spiral) do
				local a = e.arm * math.pi * 2 / 3 + e.u * 2.4 + spin
				local r = (0.15 + e.u * 0.85) * R * grow
				e.p.Size = Vector3.new((0.05 + 0.08 * e.u) * R, 0.06, 0.12 * R * 0.5)
				e.p.CFrame = floor * CFrame.Angles(0, -a, 0) * CFrame.new(r, 0.08, 0)
				e.p.Transparency = 1 - (0.35 + 0.4 * e.u) * fade
			end
		else
			disc.Transparency = 1
			for _, p in ipairs(edge) do p.Transparency = 1 end
			for _, e in ipairs(spiral) do e.p.Transparency = 1 end
		end
		-- sickles: cuffs -> ring -> orbit -> back
		local k = 1.8 * U / 2
		for i, g in ipairs(sickles) do
			local a0 = (i - 1) / 6 * math.pi * 2
			local ang = a0 + (t > start and (t - start) * 3.2 or 0)
			local ringPos = c + Vector3.new(math.cos(ang) * R, 1.4 * U, math.sin(ang) * R)
			local cuff = (i % 2 == 1 and cuffL or cuffR)
			local from = cuff and cuff.Position or (c + Vector3.new(0, 2 * U, 0))
			local pos
			if t < 0.58 then pos = nil
			elseif t < start then pos = from:Lerp(ringPos, easeOut(seg(t, 0.58, start)))
			elseif t < stop then pos = ringPos
			elseif t < stop + 0.35 then pos = ringPos:Lerp(from, easeIn(seg(t, stop, stop + 0.35)))
			end
			if pos then
				sickleShow(g, true)
				placeSickle(g, CFrame.new(pos) * CFrame.Angles(0, -ang - t * 12.8, 0), k)
			else
				sickleShow(g, false)
			end
		end
		-- blood on everyone inside (this client's guess; the server deals the damage)
		if os.clock() >= nextScan then
			nextScan = os.clock() + 0.25
			victims = {}
			local list = {}
			for _, pl in ipairs(Players:GetPlayers()) do if pl.Character and pl.Character ~= char then table.insert(list, pl.Character) end end
			local isl = workspace:FindFirstChild("DinoIsland")
			local bots = isl and isl:FindFirstChild("Bots")
			for _, b in ipairs(bots and bots:GetChildren() or {}) do table.insert(list, b) end
			for _, m in ipairs(list) do
				local r = m:IsA("Model") and m:FindFirstChild("HumanoidRootPart")
				if r and Vector3.new(r.Position.X - c.X, 0, r.Position.Z - c.Z).Magnitude <= R then table.insert(victims, r) end
			end
		end
		for j, d in ipairs(drops) do
			local r = victims[(j - 1) % math.max(1, #victims) + 1]
			if r and r.Parent and t > start and t < stop then
				local ph = (t * 1.6 + j * 0.13) % 1
				d.CFrame = CFrame.new(r.Position + Vector3.new(((j * 7) % 5 - 2) * 0.25 * U, (1 - ph * 2) * U, ((j * 3) % 5 - 2) * 0.25 * U))
				d.Transparency = 0.1 + 0.6 * ph
			else
				d.Transparency = 1
			end
		end
	end)
	note("vortex")
end

-- Bola -------------------------------------------------------------------------------------------------------------------------
local function wireLoop(n, U)
	local l = {}
	for i = 1, n do l[i] = part(Vector3.one * 0.1, WIRE, Enum.Material.Neon, 1) end
	return l
end
local function heldTag(model)
	local r = model:FindFirstChild("HumanoidRootPart")
	if not r then return nil end
	local g = Instance.new("BillboardGui")
	g.Name = "TheriBolaHeld"
	g.AlwaysOnTop = true
	g.Size = UDim2.fromOffset(90, 30)
	g.StudsOffsetWorldSpace = Vector3.new(0, 6 * model:GetScale() + 3, 0)
	g.LightInfluence = 0
	g.Adornee = r
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "HELD"
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.TextColor3 = WIRE
	tl.TextStrokeTransparency = 0.2
	tl.Parent = g
	g.Parent = fx()
	return g
end
local function bola(char)
	local at = num(char, "TheriBolaAt", 0)
	local s = char:GetScale()
	local U = 2 * s
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local flight = num(char, "TheriBolaFlight", 0.4)
	local tm = findModel(char:GetAttribute("TheriBolaTarget"))
	local troot = tm and tm:FindFirstChild("HumanoidRootPart")
	local endPos = char:GetAttribute("TheriBolaEnd")
	if typeof(endPos) ~= "Vector3" then endPos = root.Position + root.CFrame.LookVector * 35 end
	local k = 1.8 * U / 2
	local w = {}
	for e = 1, 2 do
		w[e] = part(Vector3.one * 0.55 * k, BRASS, Enum.Material.Metal, 1, Enum.PartType.Ball)
		w[e + 2] = part(Vector3.one * 0.25 * k, ORANGE, Enum.Material.Neon, 1, Enum.PartType.Ball)
	end
	local cord = part(Vector3.one * 0.1, WIRE, Enum.Material.Neon, 1)
	local tether = part(Vector3.one * 0.1, WIRE, Enum.Material.Neon, 1)
	local loops = {}
	for i = 1, 4 do loops[i] = wireLoop(12, U) end
	local tail = bodyPart(char, "Tail5_main")
	local hitT = 0.6 + flight
	local tag, hitDone, result, snapAt
	local landAt
	local function placeBola(cf)
		for e = 1, 2 do
			local x = (e == 1 and -1 or 1) * 1.1 * k
			w[e].CFrame = cf * CFrame.new(x, 0, 0)
			w[e + 2].CFrame = cf * CFrame.new(x, 0.22 * k, 0)
			w[e].Transparency, w[e + 2].Transparency = 0, 0
		end
		setSeg(cord, (cf * CFrame.new(-1.1 * k, 0, 0)).Position, (cf * CFrame.new(1.1 * k, 0, 0)).Position, 0.06 * k)
		cord.Transparency = 0
	end
	local function hideBola() for _, p in ipairs(w) do p.Transparency = 1 end cord.Transparency = 1 end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = now() - at
		local snaredUntil = tm and num(tm, "TheriSnaredUntil", 0) or 0
		local done = t > 6 or not char.Parent or num(char, "TheriBolaAt", at) ~= at
		if not done and hitDone then
			if result == "hit" then done = snapAt ~= nil and t > snapAt + 0.4 else done = landAt ~= nil and t > landAt + 0.6 end
		end
		if done then
			conn:Disconnect()
			kill(w) cord:Destroy() tether:Destroy()
			for _, l in ipairs(loops) do kill(l) end
			if tag then tag:Destroy() end
			return
		end
		local rcf = root.CFrame
		local tip = tail and (tail.Position + rcf:VectorToWorldSpace(Vector3.new(0, 0.3, 1.2) * U)) or (rcf * CFrame.new(0, 0, 6 * U)).Position
		if t < 0.05 then return end
		if t < 0.55 then -- whirl at the tail tip, in the dino's side plane
			local a = t * 22
			local p = tip + rcf.RightVector * math.cos(a) * 1.4 * U + Vector3.new(0, (1.2 + math.sin(a) * 1.4) * U, 0)
			placeBola(CFrame.new(p) * rcf.Rotation * CFrame.Angles(0, 0, a * 1.5))
			tether.Transparency = 0
			setSeg(tether, tip, p, 0.05 * U)
			return
		end
		tether.Transparency = 1
		local to = (troot and troot.Parent) and (troot.Position - Vector3.new(0, 1.5 * tm:GetScale(), 0)) or endPos
		if t < hitT then -- the throw: an arc to the feet
			local u = clamp01((t - 0.55) / (hitT - 0.55))
			local from = tip + Vector3.new(0, 1.2 * U, 0)
			local p = from:Lerp(to, u) + Vector3.new(0, math.sin(u * math.pi) * 4 * U, 0)
			placeBola(CFrame.new(p) * CFrame.Angles(0, u * 30, 0))
			return
		end
		if not hitDone then
			result = char:GetAttribute("TheriBolaResult")
			if result == "thrown" and t < hitT + 0.35 then -- wait for the server's call a moment
				placeBola(CFrame.new(to) * CFrame.Angles(0, t * 30, 0))
				return
			end
			hitDone = true
			if result == "hit" then
				hideBola()
				tag = heldTag(tm)
				flash(tm, WIRE, 0.25, 0.6)
				note("bola:hit")
			else
				landAt = t
				note("bola:" .. tostring(result))
			end
		end
		if result == "hit" then
			local r = troot and troot.Parent and troot
			local held = snaredUntil > now()
			if not held and not snapAt then snapAt = t end
			local ts = tm and tm:GetScale() or 1
			for i, l in ipairs(loops) do
				local drop = snapAt and seg(t, snapAt, snapAt + 0.4) or 0
				if r then
					local cf = CFrame.new(r.Position + Vector3.new(0, (-1.6 + i * 0.35) * ts * 1.4 - drop * 2 * ts, 0))
						* CFrame.Angles((i % 2 == 0) and 0.35 or -0.35, t * 0.5, 0)
					placeRing(l, cf, 0.55 * 1.6 * ts * 1.6 * (0.6 + 0.4 * seg(t, hitT, hitT + 0.12)), 0.09 * ts, 0.09 * ts)
					for _, p in ipairs(l) do p.Transparency = drop end
				else
					for _, p in ipairs(l) do p.Transparency = 1 end
				end
			end
			if snapAt and tag then tag:Destroy() tag = nil end
		else -- a miss: it lands and fades
			local u = seg(t, landAt, landAt + 0.6)
			placeBola(CFrame.new(Vector3.new(to.X, groundBelow(to, to.Y) + 0.3 * U, to.Z)) * CFrame.Angles(0, 0.4, 0))
			for _, p in ipairs(w) do p.Transparency = u end
			cord.Transparency = u
		end
	end)
	note("bola")
end

-- Dash (Storm Core) -----------------------------------------------------------------------------------------------------------
local function ghostSnapshot(char, root)
	local list = {}
	local rcf = root.CFrame
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root and d.Transparency < 0.9 and not d:IsDescendantOf(char:FindFirstChild("Hitboxes") or root) then
			table.insert(list, {size = d.Size, rel = rcf:ToObjectSpace(d.CFrame), shape = d:IsA("Part") and d.Shape or nil})
			if #list >= 160 then break end
		end
	end
	return list
end
local function dash(char)
	local at = num(char, "TheriDashAt", 0)
	if char:GetAttribute("TheriDashResult") ~= "dash" then return end
	local from, to = char:GetAttribute("TheriDashFrom"), char:GetAttribute("TheriDashTo")
	local root = char:FindFirstChild("HumanoidRootPart")
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not root then return end
	local s = char:GetScale()
	local U = 2 * s
	local D, T = num(char, "TheriDashDelay", 0.16), num(char, "TheriDashTime", 0.12)
	local jolt0, jolt1 = D, D + T
	local arcs = {newBolt(9), newBolt(9), newBolt(9)}
	local path = {newBolt(16), newBolt(14)}
	local sparks = {newBolt(6), newBolt(6), newBolt(6)}
	local shock = ringParts(36, YELLOW, Enum.Material.Neon, 1)
	local snap = ghostSnapshot(char, root)
	local rot0 = root.CFrame.Rotation
	local ghosts = {}
	for g = 1, 3 do
		local set = {}
		for i, e in ipairs(snap) do
			local p = part(e.size, YELLOW, Enum.Material.Neon, 1, e.shape)
			set[i] = p
		end
		ghosts[g] = set
	end
	local gy = groundBelow(to, to.Y - 3 * U)
	local flashed = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = now() - at
		if t > jolt1 + 0.75 or not char.Parent or num(char, "TheriDashAt", at) ~= at then
			conn:Disconnect()
			for _, b in ipairs(arcs) do killBolt(b) end
			for _, b in ipairs(path) do killBolt(b) end
			for _, b in ipairs(sparks) do killBolt(b) end
			kill(shock)
			for _, set in ipairs(ghosts) do kill(set) end
			return
		end
		local seed = math.floor(t * 30)
		-- charge: arcs horn <-> horn <-> core
		local hL, hR, core = zpiece(char, "zgrapple", "hornL"), zpiece(char, "zgrapple", "hornR"), zpiece(char, "zgrapple", "core")
		if t < jolt0 + 0.02 and hL and hR then
			drawBolt(arcs[1], hL.Position, hR.Position, 0.5 * U / 2, seed, 0.06 * U)
			if core then
				drawBolt(arcs[2], hL.Position, core.Position, 0.45 * U / 2, seed + 1, 0.06 * U)
				drawBolt(arcs[3], hR.Position, core.Position, 0.45 * U / 2, seed + 2, 0.06 * U)
			end
		else
			for _, b in ipairs(arcs) do hideBolt(b) end
		end
		-- the flash
		if not flashed and t >= jolt0 - 0.04 then
			flashed = true
			flash(char, Color3.fromRGB(255, 240, 170), (jolt1 - jolt0) + 0.2, 0.75)
		end
		-- bolts along the path
		if t > jolt0 and t < jolt1 + 0.3 then
			local f = 1 - seg(t, jolt1 + 0.12, jolt1 + 0.3)
			drawBolt(path[1], from + Vector3.new(0, 1.5 * U, 0), to + Vector3.new(0, 1.5 * U, 0), (1.2 * f + 0.2) * U / 2, seed, 0.1 * U)
			drawBolt(path[2], from - Vector3.new(0, 1.0 * U, 0), to - Vector3.new(0, 0.8 * U, 0), (0.9 * f + 0.2) * U / 2, seed + 7, 0.08 * U)
		else
			for _, b in ipairs(path) do hideBolt(b) end
		end
		-- afterimages at 1/4, 1/2, 3/4 of the path
		local k = clamp01((t - jolt0) / math.max(0.01, jolt1 - jolt0))
		local alpha = 1 - seg(t, jolt1 + 0.05, jolt1 + 0.3)
		for g, set in ipairs(ghosts) do
			local fr = g / 4
			local vis = t > jolt0 and k >= fr and alpha > 0
			local base = CFrame.new(from:Lerp(to, fr)) * rot0
			for i, p in ipairs(set) do
				if vis then
					p.CFrame = base * snap[i].rel
					p.Transparency = 1 - 0.32 * alpha * (0.5 + (g - 1) * 0.25)
				else
					p.Transparency = 1
				end
			end
		end
		-- landing: shock ring + sparks
		if t > jolt1 and t < jolt1 + 0.67 then
			local u = seg(t, jolt1, jolt1 + 0.67)
			local here = root.Position
			local floorCF = CFrame.new(here.X, gy + 0.15, here.Z)
			placeRing(shock, floorCF, (0.5 + 6 * easeOut(u)) * U / 2 * 1.6, 0.25 * U / 2, 0.08)
			for _, p in ipairs(shock) do p.Transparency = 0.1 + 0.9 * u end
			for a = 1, 3 do
				local r = (2 + a) * U / 2
				local ang = a * 2.1 + t * 3
				drawBolt(sparks[a], here + Vector3.new(0, 0.5 * U, 0), Vector3.new(here.X + math.cos(ang) * r, gy + 0.1, here.Z + math.sin(ang) * r), 0.35 * U / 2, math.floor(t * 24) + a * 5, 0.05 * U)
			end
		else
			for _, p in ipairs(shock) do p.Transparency = 1 end
			for _, b in ipairs(sparks) do hideBolt(b) end
		end
	end)
	note("dash")
end

-- Reaper Reel ------------------------------------------------------------------------------------------------------------------
local CHAIN_MAX = 90
local function reel(char)
	local at = num(char, "TheriReelAt", 0)
	local s = char:GetScale()
	local U = 2 * s
	local brace, fly = num(char, "TheriReelBrace", 0.3), num(char, "TheriReelFly", 0.2)
	local result = char:GetAttribute("TheriReelResult")
	local isHit = result == "hit"
	local finish = brace + fly + (isHit and num(char, "TheriReelTime", 0.5) or 0)
	local outEnd = isHit and finish + 0.22 or brace + fly + (result == "shielded" and 0.1 or 0)
	local backEnd = outEnd + (isHit and 0.28 or fly)
	local aimEnd = char:GetAttribute("TheriReelEnd")
	local tm = findModel(char:GetAttribute("TheriReelTarget"))
	local troot = tm and tm:FindFirstChild("HumanoidRootPart")
	if typeof(aimEnd) ~= "Vector3" then return end
	-- the claw copy (the launcher's own "hookhead" pieces, in the claw's frame at the fire)
	local head = {}
	local zm = char:FindFirstChild("ZPart_zhook")
	local muz = zpiece(char, "zhook", "muzzle")
	if zm and muz then
		local hp = {}
		for _, p in ipairs(zm:GetChildren()) do if p:IsA("BasePart") and p:GetAttribute("ZPartRole") == "hookhead" then table.insert(hp, p) end end
		if #hp > 0 then
			local c = Vector3.zero
			for _, p in ipairs(hp) do c += p.Position end
			c /= #hp
			local fwd = (c - muz.Position).Magnitude > 0.01 and (c - muz.Position).Unit or char.HumanoidRootPart.CFrame.LookVector
			local base = CFrame.lookAt(c, c + fwd)
			for _, p in ipairs(hp) do
				local k = p:Clone()
				k:ClearAllChildren()
				k.Anchored, k.CanCollide, k.CanQuery, k.CanTouch, k.Massless = true, false, false, false, true
				k.LocalTransparencyModifier = 0
				k.Transparency = 1
				for name in pairs(k:GetAttributes()) do k:SetAttribute(name, nil) end
				k.Parent = fx()
				table.insert(head, {p = k, rel = base:ToObjectSpace(p.CFrame)})
			end
		end
	end
	local links = {}
	local slashes = {{}, {}}
	for a = 1, 2 do for i = 1, 14 do slashes[a][i] = part(Vector3.one * 0.1, Color3.new(1, 1, 1), Enum.Material.Neon, 1) end end
	local speed = {}
	for i = 1, 10 do speed[i] = part(Vector3.one * 0.1, Color3.new(1, 1, 1), Enum.Material.Neon, 1) end
	local dust = puffSet(8)
	local flashed = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = now() - at
		local root = char:FindFirstChild("HumanoidRootPart")
		if t > math.max(backEnd, finish + 0.65) + 0.05 or not char.Parent or not root or num(char, "TheriReelAt", at) ~= at then
			conn:Disconnect()
			kill(links)
			for _, h in ipairs(head) do h.p:Destroy() end
			for _, l in ipairs(slashes) do kill(l) end
			kill(speed) kill(dust)
			return
		end
		local m = zpiece(char, "zhook", "muzzle")
		local from = m and m.Position or root.Position
		local grip = (troot and troot.Parent and (isHit or result == "shielded")) and troot.Position or aimEnd
		local tip
		if t < brace then tip = nil
		elseif t < brace + fly then tip = from:Lerp(grip, easeOut((t - brace) / fly))
		elseif t < outEnd then tip = grip
		elseif t < backEnd then tip = grip:Lerp(from, easeIn((t - outEnd) / math.max(0.01, backEnd - outEnd)))
		end
		-- chain + claw
		if tip then
			local d = tip - from
			local n = math.clamp(math.floor(d.Magnitude / (0.75 * U / 2 * 1.8)), 1, CHAIN_MAX)
			for i = #links + 1, n do links[i] = part(Vector3.new(0.3, 0.1, 0.9) * U / 2 * 1.8, i % 2 == 0 and STEEL or DARK, Enum.Material.Metal) end
			for i, l in ipairs(links) do
				if i <= n and d.Magnitude > 0.05 then
					local p = from + d * ((i - 0.5) / n)
					l.CFrame = CFrame.lookAt(p, tip) * CFrame.Angles(0, 0, i % 2 == 0 and math.rad(90) or 0)
					l.Transparency = 0
				else
					l.Transparency = 1
				end
			end
			local dir = (grip - from).Magnitude > 0.01 and (grip - from).Unit or root.CFrame.LookVector
			local cf = CFrame.lookAt(tip, tip + dir)
			for _, h in ipairs(head) do h.p.CFrame = cf * h.rel h.p.Transparency = 0 end
		else
			for _, l in ipairs(links) do l.Transparency = 1 end
			for _, h in ipairs(head) do h.p.Transparency = 1 end
		end
		-- speed lines while reeling
		local reeling = isHit and t > brace + fly + 0.08 and t < finish
		local rcf = root.CFrame
		for i, l in ipairs(speed) do
			if reeling then
				local off = Vector3.new(-2 + (i % 5) * 1.0, (i * 1.3) % 5 - 1, 4 + (i * 1.1) % 4) * U / 2 * 1.4
				local p = (rcf * CFrame.new(off)).Position
				l.Size = Vector3.new(0.06, 0.06, 3) * U / 2 * 1.4
				l.CFrame = CFrame.lookAt(p, p + rcf.LookVector)
				l.Transparency = 0.5
			else
				l.Transparency = 1
			end
		end
		-- the slash: two white claw arcs in front, then the target flashes red
		local ks = seg(t, finish, finish + 0.25)
		for a, arc in ipairs(slashes) do
			if isHit and ks > 0 and ks < 1 then
				local sgn = a == 1 and -1 or 1
				local c = (rcf * CFrame.new(0, 1 * U, -5 * U)).Position
				local cf = CFrame.new(c) * rcf.Rotation * CFrame.Angles(0.4, sgn * 0.5, sgn * -(0.6 + ks * 2.2))
				local r = 4 * U / 2 * 1.2
				for i, p in ipairs(arc) do
					local u0, u1 = (i - 1) / #arc * math.pi * 0.9, i / #arc * math.pi * 0.9
					local a0 = (cf * CFrame.new(math.cos(u0) * r, math.sin(u0) * r, 0)).Position
					local a1 = (cf * CFrame.new(math.cos(u1) * r, math.sin(u1) * r, 0)).Position
					setSeg(p, a0, a1, 0.25 * U / 2 * (1 - math.abs((i - 0.5) / #arc - 0.5)))
					p.Transparency = 0.1 + 0.9 * ks
				end
			else
				for _, p in ipairs(arc) do p.Transparency = 1 end
			end
		end
		if isHit and not flashed and num(char, "TheriReelHitAt", 0) >= at then
			flashed = true
			flash(tm, RED, 0.3, 0.8)
		end
		local gy = groundBelow(root.Position, root.Position.Y - 3 * U)
		drawPuffs(dust, Vector3.new(root.Position.X, gy, root.Position.Z) + rcf.LookVector * 3 * U / 2, isHit and seg(t, finish, finish + 0.6) or 0, 2.2, U / 2 * 1.6)
	end)
	note("reel:" .. tostring(result) .. (#head > 0 and ":claw" or ""))
end

-- watch every character ------------------------------------------------------------------------------------------------------
local function watch(char)
	char:GetAttributeChangedSignal("TheriVortexAt"):Connect(function() if on("vortex") then vortex(char) end end)
	char:GetAttributeChangedSignal("TheriBolaAt"):Connect(function() if on("bola") then bola(char) end end)
	char:GetAttributeChangedSignal("TheriDashAt"):Connect(function() if on("dash") then dash(char) end end)
	char:GetAttributeChangedSignal("TheriReelAt"):Connect(function() if on("reel") then reel(char) end end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
