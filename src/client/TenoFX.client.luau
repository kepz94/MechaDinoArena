-- TenoFX v1.2 (Mecha Dino Arena) — the Tenontosaurus' scratch, tail-slam and leap effects on this client (LocalScript,
-- StarterPlayerScripts). MDA-172, plan docs/plans/TENO_KIT_v1.0.md Task 8, mockup docs/mockups/teno_attacks_options.html
-- v0.2 (Kepu 2026-10-31: "way more animated with more effects to really sell the power of the slam"). Every size below is
-- the mockup's (studs at scale 2) x (character scale / 2). Runs for every player character with TenoAttackEnabled (yours and
-- others'). Everything is local (Workspace "TenoFX"), nothing is replicated.
-- Owner vs others: on your own teno the scratch / slam effects start from TenoAttackTest's local state (TenoLocalState
--   "scratch" / "slam", TenoLocalAt); on others' from TenoAttackServer's TenoScratchAt / TenoSlamAt. Damage pops always
--   come from the server (TenoScratchTargets at TenoScratchHitAt, TenoSlamTargets / TenoSlamBuckedNames at
--   TenoSlamImpactAt).
-- Hold (the model's TenoPoseState "hold", IdleAnimation 1.37): g = clamp((held - TenoSlamHoldMin) / 0.5); the tail
--   segments (Tail1..Tail5 models) glow GLOW (Highlights, fill transparency 1 - g x (0.55 + 0.225 x sin(18 t))) and a
--   GLOW ring lies on the ground under the hips (radius 6 + 6 g + 0.6 sin(10 t), transparency 1 - 0.8 g).
-- Scratch (0.17 s after the start): 3 claw streaks (0.25 x 0.25 x 6, colour FFF0B0, 0.3 s, 0.03 s apart) at the ArmR
--   claw, pointing forward and down; camera shake 0.25.
-- Slam impact (TenoSlamDropTime after the start; point = ground below the Tail4 joint): white flash sphere (size 7,
--   0.22 s); ring FFF1C8 2 -> 24 studs (0.7 s) and ring GLOW 1 -> 16 (0.9 s), each with a wall cylinder; 26 dust balls
--   (spread 18, up 7, size 1.8, CBB487); 18 rocks (speed 26, gravity 60, 1.6 s); 9 ground cracks (3 segments each, 14
--   studs, inside a 3.4 rad cone behind, 3A2E22, 2.4 s); camera shake 1.3 within SHAKE_RANGE; on your own teno a hit-stop
--   punch (the camera holds still 0.09 s, then shakes) and a field-of-view kick.
-- Leap: takeoff (JumpState crouch -> push / rise) 8 dust balls behind; landing (JumpState -> "land") ring FFF1C8 2 -> 14
--   (0.55 s), 16 dust balls, 6 rocks, camera shake 0.8 (only when you are within SHAKE_RANGE).
-- Pops: "-N" over each hit target (N = the teno's TenoScratchDamage / TenoSlamDamage; "BLOCKED" when its Energy Shield is
--   up), "-N BUCKED OFF" over a bucked raptor; 1 s, rising.
-- Switch: script attribute TenoFXEnabled (default true, read each event; false = no effects).
-- Diagnostics: script TenoFXVersion, TenoFXEvents (count), TenoFXLast ("scratch" / "slam" / "land" / "launch").
-- v1.1 (Kepu 2026-10-31 after v302: "take away all the extra dust and seismic effects when jumping keep that consistent
--   with other models"): the leap's takeoff dust and landing ring / dust / rocks / camera shake are off, like every other
--   dino's jump (no jump effects). Switch: script attribute TenoFXLeapEnabled (default false, read each jump; true = 1.0).
-- v1.2 (Kepu 2026-11-02: "remove the yellow circle when you hold the tail slam"): the GLOW ring under the hips during the hold
--   is not drawn (its segments stay transparent); the tail glow stays. Switch: script attribute TenoFXHoldRingEnabled
--   (default false, read each frame; true = 1.1 ring).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.2"
if script:GetAttribute("TenoFXHoldRingEnabled") == nil then script:SetAttribute("TenoFXHoldRingEnabled", false) end -- v1.2
local SHAKE_RANGE = 90
local DUST, ROCK, ROCK2, CRACK = Color3.fromHex("CBB487"), Color3.fromHex("7A6A50"), Color3.fromHex("5C4E3A"), Color3.fromHex("3A2E22")
local WAVE, GLOW, STREAK = Color3.fromHex("FFF1C8"), Color3.fromHex("FFD24A"), Color3.fromHex("FFF0B0")
local RING_SEGS = 28

script:SetAttribute("TenoFXVersion", VERSION)
script:SetAttribute("TenoFXEvents", 0)
if script:GetAttribute("TenoFXEnabled") == nil then script:SetAttribute("TenoFXEnabled", true) end
if script:GetAttribute("TenoFXLeapEnabled") == nil then script:SetAttribute("TenoFXLeapEnabled", false) end -- v1.1
local function on() return script:GetAttribute("TenoFXEnabled") ~= false end
local function note(what)
	script:SetAttribute("TenoFXEvents", (script:GetAttribute("TenoFXEvents") or 0) + 1)
	script:SetAttribute("TenoFXLast", what)
end

local player = Players.LocalPlayer
local folder = workspace:FindFirstChild("TenoFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TenoFX"
	folder.Parent = workspace
end
local function now() return workspace:GetServerTimeNow() end

-- effect list ----------------------------------------------------------------------------------------------------------------
local fx = {}
local function add(f) f.t = 0; table.insert(fx, f); return f end
local function part(shape, size, color, transp, material)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transp or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundAt(pos)
	local ex = {folder}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rayParams.FilterDescendantsInstances = ex
	local g = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -120, 0), rayParams)
	return g and Vector3.new(pos.X, g.Position.Y, pos.Z) or pos
end

local function dust(pos, n, spread, up, size, k)
	for _ = 1, n do
		local a = math.random() * math.pi * 2
		local r = math.random() * spread * 0.4 * k
		local d = size * (0.6 + math.random() * 0.8) * k * 2
		local p = part(Enum.PartType.Ball, Vector3.new(d, d, d), DUST, 0.15)
		p.Position = pos + Vector3.new(math.cos(a) * r, 0.5 * k, math.sin(a) * r)
		add({kind = "dust", p = p, d = d, life = 1.1 + math.random() * 0.6,
			v = Vector3.new(math.cos(a) * spread * (0.6 + math.random()), up * (0.5 + math.random()), math.sin(a) * spread * (0.6 + math.random())) * k})
	end
end
local function rocks(pos, n, speed, k)
	for i = 1, n do
		local s = (0.4 + math.random() * 0.9) * k
		local p = part(Enum.PartType.Block, Vector3.new(s, s, s), i % 2 == 1 and ROCK or ROCK2, 0)
		p.Position = pos + Vector3.new(0, 0.5 * k, 0)
		local a = math.random() * math.pi * 2
		add({kind = "rock", p = p, life = 1.6, floor = pos.Y + 0.3 * k, g = 60 * k,
			v = Vector3.new(math.cos(a) * speed * math.random(), speed * (0.8 + math.random()), math.sin(a) * speed * math.random()) * k,
			spin = Vector3.new(math.random() * 10, math.random() * 10, 0)})
	end
end
-- a flat ring of RING_SEGS neon blocks + a see-through wall cylinder
local function ring(pos, r0, r1, life, color, h, k)
	local segs = {}
	for i = 1, RING_SEGS do
		segs[i] = part(Enum.PartType.Block, Vector3.new(1, 0.12, 1), color, 0.1, Enum.Material.Neon)
	end
	add({kind = "ring", segs = segs, pos = pos + Vector3.new(0, (h or 0.15) * k, 0), r0 = r0 * k, r1 = r1 * k, life = life})
	local wall = part(Enum.PartType.Cylinder, Vector3.new(1, 1, 1), color, 0.65, Enum.Material.Neon)
	add({kind = "wall", p = wall, pos = pos, r0 = r0 * k, r1 = r1 * k, life = life * 0.8, k = k})
end
local function cracks(pos, n, len, coneDir, coneWidth, k)
	local base = math.atan2(coneDir.X, coneDir.Z)
	for _ = 1, n do
		local ang = base + (math.random() - 0.5) * coneWidth
		local p0 = pos
		for s = 1, 3 do
			local L = len * (0.4 + math.random() * 0.4) / s * k
			local dir = Vector3.new(math.sin(ang), 0, math.cos(ang))
			local w = (0.45 / s + 0.15) * k
			local c = part(Enum.PartType.Block, Vector3.new(w, 0.08, L), CRACK, 1)
			local mid = groundAt(p0 + dir * (L / 2))
			c.CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.05, 0), mid + Vector3.new(0, 0.05, 0) + dir)
			add({kind = "crack", p = c, life = 2.4, delay = (s - 1) * 0.04})
			p0 += dir * L
			ang += (math.random() - 0.5) * 0.9
		end
	end
end
local function flash(pos, size, k)
	local p = part(Enum.PartType.Ball, Vector3.new(1, 1, 1), Color3.new(1, 1, 1), 0.1, Enum.Material.Neon)
	p.Position = pos + Vector3.new(0, k, 0)
	add({kind = "flash", p = p, size = size * k, life = 0.22})
end
local function claws(from, dir, k)
	for i = 1, 3 do
		local p = part(Enum.PartType.Block, Vector3.new(0.25 * k, 0.25 * k, 6 * k), STREAK, 1, Enum.Material.Neon)
		local at = from + Vector3.new(0, (2 + (i - 1) * 1.1) * k * 0.5, 0)
		p.CFrame = CFrame.lookAt(at, at + dir) * CFrame.Angles(-0.6, (i - 2) * 0.1, 0)
		add({kind = "streak", p = p, life = 0.3, delay = (i - 1) * 0.03, len = 6 * k})
	end
end
local function pop(model, text, big)
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if not root then return end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 260 or 160, big and 60 or 40)
	bb.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y * 0.6 + 2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = root
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = big and GLOW or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.Parent = bb
	bb.Parent = folder
	add({kind = "pop", bb = bb, l = l, life = 1, y0 = bb.StudsOffsetWorldSpace.Y})
end

-- camera shake (+ hit-stop for the owner)
local shake, holdCam, holdCF, fovKick, fovBase = 0, 0, nil, 0, nil
local function shakeAt(pos, amount)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r and (r.Position - pos).Magnitude > SHAKE_RANGE then return end
	shake = math.max(shake, amount)
end
RunService:BindToRenderStep("TenoFXCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if holdCam > 0 and holdCF then
		holdCam -= dt
		cam.CFrame = holdCF
		return
	end
	if shake > 0.01 then
		local s = shake * 0.6
		cam.CFrame *= CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
			* CFrame.Angles((math.random() - 0.5) * s * 0.02, (math.random() - 0.5) * s * 0.02, 0)
		shake *= math.max(0, 1 - dt * 6)
	else
		shake = 0
	end
	if fovBase then
		if fovKick > 0.05 then
			cam.FieldOfView = fovBase - fovKick
			fovKick *= math.max(0, 1 - dt * 8)
		else
			cam.FieldOfView, fovBase, fovKick = fovBase, nil, 0
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for i = #fx, 1, -1 do
		local f = fx[i]
		local alive = true
		if f.delay and f.delay > 0 then
			f.delay -= dt
		else
			f.t += dt
			local u = f.t / f.life
			if u >= 1 then
				alive = false
			elseif f.kind == "dust" then
				f.p.Position += f.v * dt
				f.v *= math.max(0, 1 - dt * 2.2)
				local d = f.d * (1 + u * 1.8)
				f.p.Size = Vector3.new(d, d, d)
				f.p.Transparency = 0.15 + 0.85 * u
			elseif f.kind == "rock" then
				f.v -= Vector3.new(0, f.g * dt, 0)
				local p = f.p.Position + f.v * dt
				if p.Y < f.floor then
					p = Vector3.new(p.X, f.floor, p.Z)
					f.v = Vector3.new(f.v.X * 0.4, math.abs(f.v.Y) * 0.12, f.v.Z * 0.4)
				end
				f.p.CFrame = CFrame.new(p) * (f.p.CFrame - f.p.Position) * CFrame.Angles(f.spin.X * dt, f.spin.Y * dt, 0)
				if u > 0.75 then f.p.Transparency = (u - 0.75) / 0.25 end
			elseif f.kind == "ring" then
				local r = f.r0 + (f.r1 - f.r0) * (1 - (1 - u) ^ 3)
				local seg = 2 * math.pi * r / RING_SEGS * 1.05
				for j, s in ipairs(f.segs) do
					local a = (j - 1) / RING_SEGS * 2 * math.pi
					local at = f.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
					s.Size = Vector3.new(math.max(0.3, r * 0.08), 0.12, seg)
					s.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(a), 0, math.cos(a)))
					s.Transparency = 0.1 + 0.9 * u
				end
			elseif f.kind == "wall" then
				local r = f.r0 + (f.r1 - f.r0) * (1 - (1 - u) ^ 3)
				local h = (6 * (1 - u) + 0.5) * f.k
				f.p.Size = Vector3.new(h, r * 2, r * 2)
				f.p.CFrame = CFrame.new(f.pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				f.p.Transparency = 1 - 0.35 * (1 - u)
			elseif f.kind == "crack" then
				f.p.Transparency = u < 0.7 and 0 or (u - 0.7) / 0.3
			elseif f.kind == "flash" then
				local s = f.size * (0.4 + u) * 2
				f.p.Size = Vector3.new(s, s, s)
				f.p.Transparency = 0.1 + 0.9 * u
			elseif f.kind == "streak" then
				f.p.Transparency = u
				f.p.Size = Vector3.new(f.p.Size.X, f.p.Size.Y, f.len * (0.4 + u))
			elseif f.kind == "pop" then
				f.bb.StudsOffsetWorldSpace = Vector3.new(0, f.y0 + u * 5, 0)
				local tr = u < 0.7 and 0 or (u - 0.7) / 0.3
				f.l.TextTransparency, f.l.TextStrokeTransparency = tr, 0.2 + 0.8 * tr
			end
		end
		if not alive then
			if f.p then f.p:Destroy() end
			if f.segs then for _, s in ipairs(f.segs) do s:Destroy() end end
			if f.bb then f.bb:Destroy() end
			table.remove(fx, i)
		end
	end
end)

-- per-teno -----------------------------------------------------------------------------------------------------------------
local function jointPos(char, name)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == name and d.Part0 then return (d.Part0.CFrame * d.C0).Position end
	end
	return nil
end
local function scaleK(char) return char:GetScale() / 2 end
local function findModel(name)
	local pl = Players:FindFirstChild(name)
	if pl and pl:IsA("Player") and pl.Character then return pl.Character end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end
local function pops(list, text, big)
	if typeof(list) ~= "string" or list == "" then return end
	for name in string.gmatch(list, "[^|]+") do
		local m = findModel(name)
		if m then
			local blocked = (tonumber(m:GetAttribute("EnergyShieldUntil")) or 0) > now()
			pop(m, blocked and "BLOCKED" or text, big)
		end
	end
end

local function scratchFX(char)
	if not on() or not char.Parent then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local k = scaleK(char)
	local fwd = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zAxis
	local claw = jointPos(char, "ArmR") or (root.Position + fwd * 4.7 * k * 2)
	claws(claw + fwd * 2 * k, fwd, k)
	shakeAt(claw, 0.25)
	note("scratch")
end

local function slamFX(char, owner)
	if not on() or not char.Parent then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local k = scaleK(char)
	local back = -Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	back = back.Magnitude > 1e-3 and back.Unit or -Vector3.zAxis
	local tp = jointPos(char, "Tail4") or (root.Position + back * 15 * k)
	local point = groundAt(tp)
	flash(point, 7, k)
	ring(point, 2, 24, 0.7, WAVE, 0.15, k)
	ring(point, 1, 16, 0.9, GLOW, 0.25, k)
	dust(point, 26, 18, 7, 1.8, k)
	rocks(point, 18, 26, k)
	cracks(point, 9, 14, back, 3.4, k)
	if owner then
		local cam = workspace.CurrentCamera
		holdCF, holdCam = cam and cam.CFrame or nil, 0.09
		if cam and not fovBase then fovBase = cam.FieldOfView end
		fovKick = 6
		shake = math.max(shake, 1.3)
	else
		shakeAt(point, 1.3)
	end
	note("slam")
end

local function landFX(char)
	if not on() or not char.Parent then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local k = scaleK(char)
	local fwd = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zAxis
	local point = groundAt(root.Position + fwd * 2 * k)
	ring(point, 2, 14, 0.55, WAVE, 0.15, k)
	dust(point, 16, 10, 3, 1.5, k)
	rocks(point, 6, 14, k)
	shakeAt(point, 0.8)
	note("land")
end

local function launchFX(char)
	if not on() or not char.Parent then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local k = scaleK(char)
	local back = -Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	back = back.Magnitude > 1e-3 and back.Unit or -Vector3.zAxis
	dust(groundAt(root.Position + back * 4 * k), 8, 7, 3, 1.3, k)
	note("launch")
end

-- hold glow
local glows = {} -- [char] = {hl = {Highlight...}, ring = {segs}}
local function clearGlow(char)
	local g = glows[char]
	if not g then return end
	for _, h in ipairs(g.hl) do h:Destroy() end
	for _, s in ipairs(g.segs) do s:Destroy() end
	glows[char] = nil
end
local function glowStep(char, owner)
	local st = char:GetAttribute("TenoPoseState")
	if st ~= "hold" or not on() then
		clearGlow(char)
		return
	end
	local start = owner and tonumber(char:GetAttribute("TenoLocalAt")) or tonumber(char:GetAttribute("TenoHoldSince"))
	if not start then return clearGlow(char) end
	local held = now() - start
	local holdMin = tonumber(char:GetAttribute("TenoSlamHoldMin")) or 0.22
	local g = math.clamp((held - holdMin) / 0.5, 0, 1)
	local gl = glows[char]
	if not gl then
		gl = {hl = {}, segs = {}}
		for i = 1, 5 do
			local seg = char:FindFirstChild("Tail" .. i)
			if seg then
				local h = Instance.new("Highlight")
				h.Name = "TenoTailGlow"
				h.Adornee = seg
				h.FillColor = GLOW
				h.OutlineTransparency = 1
				h.FillTransparency = 1
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Parent = folder
				table.insert(gl.hl, h)
			end
		end
		for i = 1, RING_SEGS do
			table.insert(gl.segs, part(Enum.PartType.Block, Vector3.new(1, 0.1, 1), GLOW, 1, Enum.Material.Neon))
		end
		glows[char] = gl
	end
	local t = os.clock()
	for _, h in ipairs(gl.hl) do h.FillTransparency = 1 - g * (0.55 + 0.225 * math.sin(t * 18)) end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local k = scaleK(char)
	local c = groundAt(root.Position) + Vector3.new(0, 0.2 * k, 0)
	local r = (6 + g * 6 + math.sin(t * 10) * 0.6) * k
	local seg = 2 * math.pi * r / RING_SEGS * 1.05
	for j, s in ipairs(gl.segs) do
		local a = (j - 1) / RING_SEGS * 2 * math.pi
		local at = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		s.Size = Vector3.new(0.5 * k, 0.1, seg)
		s.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(a), 0, math.cos(a)))
		s.Transparency = script:GetAttribute("TenoFXHoldRingEnabled") == true and 1 - 0.8 * g or 1 -- v1.2: no ring by default
	end
end

local watched = setmetatable({}, {__mode = "k"})
local function watch(char, pl)
	if watched[char] then return end
	watched[char] = true
	local owner = pl == player
	local conns = {}
	local function c(sig, fn) table.insert(conns, sig:Connect(fn)) end
	local function isTeno() return char:GetAttribute("TenoAttackEnabled") == true end
	local function slamDrop() return math.max(0, tonumber(char:GetAttribute("TenoSlamDropTime")) or 0.13) end
	if owner then
		c(char:GetAttributeChangedSignal("TenoLocalState"), function()
			if not isTeno() then return end
			local st = char:GetAttribute("TenoLocalState")
			local at = char:GetAttribute("TenoLocalAt")
			if st == "scratch" then
				task.delay(0.17, function()
					if char:GetAttribute("TenoLocalState") == "scratch" and char:GetAttribute("TenoLocalAt") == at then scratchFX(char) end
				end)
			elseif st == "slam" then
				task.delay(slamDrop(), function()
					if char:GetAttribute("TenoLocalState") == "slam" and char:GetAttribute("TenoLocalAt") == at then slamFX(char, true) end
				end)
			end
		end)
	else
		c(char:GetAttributeChangedSignal("TenoScratchAt"), function()
			if not isTeno() then return end
			local at = tonumber(char:GetAttribute("TenoScratchAt")) or 0
			task.delay(math.clamp(at + 0.17 - now(), 0, 0.17), function() scratchFX(char) end)
		end)
		c(char:GetAttributeChangedSignal("TenoSlamAt"), function()
			if not isTeno() then return end
			local at = tonumber(char:GetAttribute("TenoSlamAt")) or 0
			task.delay(math.clamp(at + slamDrop() - now(), 0, slamDrop()), function() slamFX(char, false) end)
		end)
	end
	c(char:GetAttributeChangedSignal("TenoScratchHitAt"), function()
		if not on() or not isTeno() then return end
		local d = math.floor((tonumber(char:GetAttribute("TenoScratchDamage")) or 8) + 0.5)
		pops(char:GetAttribute("TenoScratchTargets"), "-" .. d, false)
	end)
	c(char:GetAttributeChangedSignal("TenoSlamImpactAt"), function()
		if not on() or not isTeno() then return end
		local d = math.floor((tonumber(char:GetAttribute("TenoSlamDamage")) or 40) + 0.5)
		pops(char:GetAttribute("TenoSlamTargets"), "-" .. d, true)
		pops(char:GetAttribute("TenoSlamBuckedNames"), "-" .. d .. " BUCKED OFF", true)
	end)
	local lastJump = "none"
	c(char:GetAttributeChangedSignal("JumpState"), function()
		if not isTeno() then return end
		local js = char:GetAttribute("JumpState")
		if script:GetAttribute("TenoFXLeapEnabled") ~= true then lastJump = js return end -- v1.1: no jump effects
		if (js == "push" or js == "rise") and lastJump == "crouch" then launchFX(char) end
		if js == "land" and lastJump ~= "land" then landFX(char) end
		lastJump = js
	end)
	c(RunService.Heartbeat, function()
		if isTeno() then glowStep(char, owner) elseif glows[char] then clearGlow(char) end
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if parent then return end
		clearGlow(char)
		for _, cn in ipairs(conns) do cn:Disconnect() end
	end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(function(ch) watch(ch, pl) end)
	if pl.Character then watch(pl.Character, pl) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
