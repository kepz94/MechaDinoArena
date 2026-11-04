-- DiloFX v1.0 (Mecha Dino Arena) — the Dilophosaurus' effects on this client (LocalScript, StarterPlayerScripts). MDA-227,
-- plan docs/plans/DILO_KIT_v1.0.md Task 7; mockup docs/mockups/dilo_kit_options_v0.1.html attack C (Kepu 2026-11-03 "C and
-- J1"; source tools/dilo_kit_mockup/app.js: spawnShot / splash / droplet / numberPop). Server: DiloAttackServer 1.0.
-- Runs for every player character with Species "Dilo" (yours and others'). Everything is local (Workspace "DiloFX"),
-- nothing is replicated. Sizes are the mockup's (studs at scale 2) x k = character scale / 2.
-- Dart (each new DiloDartAt): a green neon glob (9CF05A, 1.3 x k) with a light, a Trail (D8FF8A -> 5CC22A, 0.22 s) and a
--   short stretch, flying straight DiloDartFrom -> DiloDartTo over DiloDartFlight from DiloDartAt (a late stamp starts it
--   part-way; a stamp older than the flight shows no glob). At the end: DiloDartTarget "" -> a small green fizzle at To; else
--   the splash comes with the hit stamp below; no hit stamp within HIT_WAIT (0.6) s after the arrival -> the fizzle.
-- Hit (each new DiloHitAt; DiloHitKind, DiloHitTargets "|" names, DiloHitPoint):
--   "bite" with targets: a white flash (6 x k) and 8 pale sparks at the point; over each target a pop "-N" (N = the dilo's
--     DiloBiteDamage, default 10; "BLOCKED" while the target's EnergyShieldUntil is in the future). No targets: nothing
--     (the pose shows the snap).
--   "dart" with targets: the splash (green-white flash 9 x k, SPLASH_DROPS 26 droplets flung out, 6 mist puffs; nothing is
--     left on the ground) and a green pop "-N" (DiloDartDamage, default 6; "BLOCKED" as above). No targets: the fizzle.
-- Venom (every VENOM_SCAN 0.2 s over players' characters and DinoIsland.Bots): a model whose VenomUntil is in the future
--   gets a green Highlight "DiloVenomGlow" (FillTransparency 0.7 +- 0.08 pulse, no outline) and drips green droplets off
--   random visible parts (DRIP_RATE 14 / s; they fall and fade before they could pool); each VenomTicks increase pops a
--   small green "-N" (N = VenomDps x 0.5, the server's tick). Off at VenomUntil.
-- Lock ring (your own dilo only, while DiloLocalState is "armed"): the soft-aim pick of DiloAttackServer 1.0 run here (the
--   closest target whose root is within DiloAssistAngle (30) degrees of your flat facing and DiloAssistMin..DiloAssistMax
--   (0..30) x scale studs flat from the snout tip; targets = players' characters and bots with Hitboxes, Bitable, a Species
--   or IsBot, not KO, alive; never a squadmate (ReplicatedStorage.SquadShared.SquadRules); players only where the mode
--   allows (ModeRules 1.0's rule: Arena place or Studio with Workspace ModeTestArena; never one in the menu)). A pale yellow
--   ring (FFF2A0, radius 5.6 x k) lies at that target's feet, pulsing; no target = no ring.
-- No jump-landing effects (house rule).
-- Switches: script attributes DiloFXEnabled (default true, read each event), DiloFXDartEnabled, DiloFXHitEnabled,
--   DiloFXVenomEnabled, DiloFXRingEnabled (default true each).
-- Diagnostics: script DiloFXVersion, DiloFXEvents (count), DiloFXLast ("dart" / "fizzle" / "bite" / "splash" / "venomTick"),
--   DiloFXParts (effect parts alive), DiloFXVenomed (models glowing now), DiloFXRingTarget (name or "").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = "1.0"
local HIT_WAIT, VENOM_SCAN, DRIP_RATE, SPLASH_DROPS, MAX_PARTS = 0.6, 0.2, 14, 26, 320
local ARENA_PLACE_ID = 75433819286625 -- ModeRules 1.0
local GREEN, GREEN_D, PALE, GLOW = Color3.fromHex("9CF05A"), Color3.fromHex("5CC22A"), Color3.fromHex("D8FF8A"),
	Color3.fromHex("D8FFB0")
local RING = Color3.fromHex("FFF2A0")

script:SetAttribute("DiloFXVersion", VERSION)
script:SetAttribute("DiloFXEvents", 0)
for _, k in ipairs({"DiloFXEnabled", "DiloFXDartEnabled", "DiloFXHitEnabled", "DiloFXVenomEnabled", "DiloFXRingEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(k) return script:GetAttribute("DiloFXEnabled") ~= false and script:GetAttribute(k) ~= false end
local function note(what)
	script:SetAttribute("DiloFXEvents", (script:GetAttribute("DiloFXEvents") or 0) + 1)
	script:SetAttribute("DiloFXLast", what)
end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k) local v = m:GetAttribute(k) return typeof(v) == "number" and v == v and v or nil end

local folder = workspace:FindFirstChild("DiloFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "DiloFX"
	folder.Parent = workspace
end

-- effect list ------------------------------------------------------------------------------------------------------------
local fx, nParts = {}, 0
local function add(f) f.t = 0; table.insert(fx, f); return f end
local function part(shape, size, color, transp, material)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = shape or Enum.PartType.Ball
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = transp or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = folder
	nParts += 1
	return p
end
local function full() return nParts >= MAX_PARTS end
local function flash(pos, size, color)
	if full() then return end
	local p = part(Enum.PartType.Ball, Vector3.one, color, 0.1)
	p.Position = pos
	add({kind = "flash", p = p, size = size, life = 0.16})
end
local function droplet(pos, v, size, life, g)
	if full() then return end
	local p = part(Enum.PartType.Ball, Vector3.one * size, math.random() < 0.5 and GREEN or GREEN_D, 0)
	p.Position = pos
	add({kind = "drop", p = p, v = v, size = size, life = life, g = g})
end
local function mist(pos, size, grow, life)
	if full() then return end
	local p = part(Enum.PartType.Ball, Vector3.one * size, GLOW, 0.45, Enum.Material.SmoothPlastic)
	p.Position = pos
	add({kind = "mist", p = p, size = size, grow = grow, life = life})
end
local function sparks(pos, n, k)
	for _ = 1, n do
		if full() then return end
		local s = (0.15 + math.random() * 0.15) * k
		local p = part(Enum.PartType.Block, Vector3.new(s, s, s * 4), math.random() < 0.6 and Color3.new(1, 1, 1) or PALE, 0)
		p.Position = pos
		local v = Vector3.new((math.random() - 0.5) * 2, 0.4 + math.random() * 0.8, (math.random() - 0.5) * 2).Unit * (16 + math.random() * 16) * k
		add({kind = "spark", p = p, v = v, life = 0.25 + math.random() * 0.12, g = 60 * k})
	end
end
local function splash(pos, k)
	flash(pos, 9 * k, GLOW)
	for _ = 1, SPLASH_DROPS do
		local a, e = math.random() * math.pi * 2, math.random() * 1.2 - 0.2
		local sp = (10 + math.random() * 22) * k
		droplet(pos, Vector3.new(math.cos(a) * math.cos(e) * sp, math.sin(e) * sp + 8 * k, math.sin(a) * math.cos(e) * sp),
			(0.4 + math.random() * 0.55) * k, 0.5 + math.random() * 0.35, 50 * k)
	end
	for _ = 1, 6 do
		mist(pos + Vector3.new((math.random() - 0.5) * 3, (math.random() - 0.5) * 2, (math.random() - 0.5) * 3) * k, 1.5 * k, 3.5 * k, 0.55)
	end
end
local function fizzle(pos, k)
	flash(pos, 3 * k, GLOW)
	for _ = 1, 3 do mist(pos, 0.8 * k, 1.6 * k, 0.4) end
end
local function pop(model, text, style)
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if not root then return end
	local small = style == "venom"
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(small and 90 or 130, small and 30 or 40)
	bb.StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 3, model:GetExtentsSize().Y * 0.6 + 2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = root
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = style == "bite" and Color3.fromHex("FFE58A") or (style == "dart" and Color3.fromHex("E6FFC2") or Color3.fromHex("9CF05A"))
	l.TextStrokeColor3 = style == "bite" and Color3.fromHex("2A1504") or Color3.fromHex("0F2A06")
	l.TextStrokeTransparency = 0.15
	l.Parent = bb
	bb.Parent = folder
	add({kind = "pop", bb = bb, l = l, life = small and 0.8 or 0.95, y0 = bb.StudsOffsetWorldSpace.Y, x0 = bb.StudsOffsetWorldSpace.X})
end

RunService.Heartbeat:Connect(function(dt)
	for i = #fx, 1, -1 do
		local f = fx[i]
		f.t += dt
		local u = f.t / f.life
		if u >= 1 then
			if f.p then f.p:Destroy(); nParts -= 1 end
			if f.bb then f.bb:Destroy() end
			if f.onEnd then f.onEnd() end
			table.remove(fx, i)
		elseif f.kind == "flash" then
			local s = f.size * (0.6 + u * 1.2)
			f.p.Size = Vector3.new(s, s, s)
			f.p.Transparency = 0.1 + 0.9 * u
		elseif f.kind == "drop" then
			f.v -= Vector3.new(0, f.g * dt, 0)
			f.p.Position += f.v * dt
			local s = f.size * (1 - u * 0.5)
			f.p.Size = Vector3.new(s, s, s)
			f.p.Transparency = u > 0.6 and (u - 0.6) / 0.4 or 0
		elseif f.kind == "mist" then
			local s = f.size + f.grow * u
			f.p.Size = Vector3.new(s, s, s)
			f.p.Transparency = 0.45 + 0.55 * u
		elseif f.kind == "spark" then
			f.v -= Vector3.new(0, f.g * dt, 0)
			local pos = f.p.Position + f.v * dt
			f.p.CFrame = CFrame.lookAt(pos, pos + f.v)
			f.p.Transparency = u * u
		elseif f.kind == "pop" then
			local sc = u < 0.12 and (0.6 + 0.4 * u / 0.12) or 1
			f.l.Size = UDim2.fromScale(sc, sc)
			f.l.Position = UDim2.fromScale((1 - sc) / 2, (1 - sc) / 2)
			f.bb.StudsOffsetWorldSpace = Vector3.new(f.x0, f.y0 + u * 5, 0)
			local tr = u < 0.65 and 0 or (u - 0.65) / 0.35
			f.l.TextTransparency, f.l.TextStrokeTransparency = tr, 0.15 + 0.85 * tr
		elseif f.kind == "dart" then
			f.update(f, dt)
		end
	end
	script:SetAttribute("DiloFXParts", nParts)
end)

-- models -------------------------------------------------------------------------------------------------------------------
local function bots()
	local isl = workspace:FindFirstChild("DinoIsland")
	local b = isl and isl:FindFirstChild("Bots")
	return b and b:GetChildren() or {}
end
local function findModel(name)
	local pl = Players:FindFirstChild(name)
	if pl and pl:IsA("Player") and pl.Character then return pl.Character end
	for _, b in ipairs(bots()) do if b.Name == name then return b end end
	return nil
end
local function scaleK(m) return (m:IsA("Model") and m:GetScale() or 2) / 2 end
local function shielded(m) return (num(m, "EnergyShieldUntil") or 0) > now() end

-- dart + hits -------------------------------------------------------------------------------------------------------------
local pending = setmetatable({}, {__mode = "k"}) -- [char] = {at, to, k, arrived (clock), hit = bool}
local function spawnDart(char)
	if char:GetAttribute("Species") ~= "Dilo" then return end
	local from, to = char:GetAttribute("DiloDartFrom"), char:GetAttribute("DiloDartTo")
	local flight, at = num(char, "DiloDartFlight"), num(char, "DiloDartAt")
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not flight or not at then return end
	local k = scaleK(char)
	local target = char:GetAttribute("DiloDartTarget")
	local pend = {at = at, to = to, k = k, hasTarget = typeof(target) == "string" and target ~= "", arrived = nil, hit = false}
	pending[char] = pend
	note("dart")
	local function arrive()
		pend.arrived = os.clock()
		if not pend.hasTarget then
			fizzle(to, k)
			note("fizzle")
			pend.hit = true
		else
			task.delay(HIT_WAIT, function()
				if not pend.hit then
					pend.hit = true
					fizzle(to, k)
					note("fizzle")
				end
			end)
		end
	end
	if not on("DiloFXDartEnabled") or now() - at >= flight then
		arrive()
		return
	end
	local glob = part(Enum.PartType.Ball, Vector3.one * 1.3 * k, GREEN, 0)
	local tail = part(Enum.PartType.Ball, Vector3.one * 0.8 * k, PALE, 0.35)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.45 * k, 0)
	a0.Parent = glob
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.45 * k, 0)
	a1.Parent = glob
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.22
	tr.FaceCamera = true
	tr.LightEmission = 1
	tr.Color = ColorSequence.new(PALE, GREEN_D)
	tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	tr.WidthScale = NumberSequence.new(1, 0.2)
	tr.Parent = glob
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = GREEN, 10 * k, 2
	light.Parent = glob
	local dir = (to - from).Magnitude > 1e-3 and (to - from).Unit or Vector3.zAxis
	local done = false
	add({kind = "dart", p = glob, life = flight + 0.3, update = function(f)
		if done then return end
		local u = math.clamp((now() - at) / flight, 0, 1)
		local pos = from:Lerp(to, u)
		glob.CFrame = CFrame.lookAt(pos, pos + dir)
		tail.CFrame = CFrame.new(pos - dir * 0.9 * k)
		if u >= 1 then
			done = true
			glob.Transparency, tail.Transparency = 1, 1
			light.Enabled = false
			arrive()
		end
	end, onEnd = function()
		if tail.Parent then tail:Destroy(); nParts -= 1 end
		if not done then arrive() end
	end})
end
local function onHit(char)
	if char:GetAttribute("Species") ~= "Dilo" then return end
	local kind, names, point = char:GetAttribute("DiloHitKind"), char:GetAttribute("DiloHitTargets"), char:GetAttribute("DiloHitPoint")
	if typeof(point) ~= "Vector3" then return end
	local k = scaleK(char)
	local list = {}
	if typeof(names) == "string" and names ~= "" then
		for n in names:gmatch("[^|]+") do table.insert(list, n) end
	end
	if kind == "dart" then
		local pend = pending[char]
		if pend then pend.hit = true end
		if not on("DiloFXHitEnabled") then return end
		if #list == 0 then
			fizzle(point, k)
			note("fizzle")
			return
		end
		splash(point, k)
		note("splash")
		local d = math.floor((num(char, "DiloDartDamage") or 6) + 0.5)
		for _, n in ipairs(list) do
			local m = findModel(n)
			if m then pop(m, shielded(m) and "BLOCKED" or ("-" .. d), "dart") end
		end
	elseif kind == "bite" and #list > 0 then
		if not on("DiloFXHitEnabled") then return end
		flash(point, 6 * k, Color3.new(1, 1, 1))
		sparks(point, 8, k)
		note("bite")
		local d = math.floor((num(char, "DiloBiteDamage") or 10) + 0.5)
		for _, n in ipairs(list) do
			local m = findModel(n)
			if m then pop(m, shielded(m) and "BLOCKED" or ("-" .. d), "bite") end
		end
	end
end

local watched = setmetatable({}, {__mode = "k"})
local function watch(char)
	if watched[char] then return end
	watched[char] = true
	char:GetAttributeChangedSignal("DiloDartAt"):Connect(function()
		if script:GetAttribute("DiloFXEnabled") ~= false then spawnDart(char) end
	end)
	char:GetAttributeChangedSignal("DiloHitAt"):Connect(function()
		if script:GetAttribute("DiloFXEnabled") ~= false then onHit(char) end
	end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(watch)
	if pl.Character then watch(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end

-- venom --------------------------------------------------------------------------------------------------------------------
local venom = {} -- [model] = {hl, acc, ticks, parts}
local function visibleParts(m)
	local list = {}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.9 and p.Name ~= "HumanoidRootPart" and p.Parent.Name ~= "Hitboxes" then
			table.insert(list, p)
		end
	end
	return list
end
local function stopVenom(m)
	local v = venom[m]
	if not v then return end
	if v.hl then v.hl:Destroy() end
	venom[m] = nil
end
local scanAcc = 0
RunService.Heartbeat:Connect(function(dt)
	scanAcc += dt
	if scanAcc >= VENOM_SCAN then
		scanAcc = 0
		local t = now()
		local seen = {}
		local models = {}
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(models, pl.Character) end end
		for _, b in ipairs(bots()) do table.insert(models, b) end
		for _, m in ipairs(models) do
			if (num(m, "VenomUntil") or 0) > t and on("DiloFXVenomEnabled") and m.Parent then
				seen[m] = true
				if not venom[m] then
					local hl = Instance.new("Highlight")
					hl.Name = "DiloVenomGlow"
					hl.FillColor = GREEN
					hl.FillTransparency = 0.7
					hl.OutlineTransparency = 1
					hl.DepthMode = Enum.HighlightDepthMode.Occluded
					hl.Adornee = m
					hl.Parent = folder
					venom[m] = {hl = hl, acc = 0, ticks = num(m, "VenomTicks") or 0, parts = visibleParts(m)}
				end
				local v = venom[m]
				local ticks = num(m, "VenomTicks") or 0
				if ticks > v.ticks then
					local per = (num(m, "VenomDps") or 2) * 0.5
					local txt = per == math.floor(per) and tostring(math.floor(per)) or string.format("%.1f", per)
					for _ = 1, math.min(3, ticks - v.ticks) do pop(m, "-" .. txt, "venom") end
					note("venomTick")
				end
				v.ticks = ticks
			end
		end
		for m in pairs(venom) do if not seen[m] then stopVenom(m) end end
		local n = 0
		for _ in pairs(venom) do n += 1 end
		script:SetAttribute("DiloFXVenomed", n)
	end
	local clock = os.clock()
	for m, v in pairs(venom) do
		v.hl.FillTransparency = 0.7 + math.sin(clock * 9) * 0.08
		v.acc += dt * DRIP_RATE
		local k = scaleK(m)
		while v.acc >= 1 do
			v.acc -= 1
			local p = #v.parts > 0 and v.parts[math.random(1, #v.parts)]
			if p and p.Parent then
				droplet(p.Position, Vector3.new((math.random() - 0.5) * 2, -3, (math.random() - 0.5) * 2) * k,
					(0.55 + math.random() * 0.35) * k, 0.6 + math.random() * 0.3, 30 * k)
			end
		end
	end
end)

-- lock ring (owner only) ---------------------------------------------------------------------------------------------------
local me = Players.LocalPlayer
local squadMod
local function squadmate(a, b)
	if not squadMod then
		local sh = ReplicatedStorage:FindFirstChild("SquadShared")
		local m = sh and sh:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b)
end
local function arenaMode()
	if game.PlaceId == ARENA_PLACE_ID then return true end
	return RunService:IsStudio() and workspace:GetAttribute("ModeTestArena") == true
end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart end
local function isTarget(m, self)
	if not (m:IsA("Model") and m ~= self and m:IsDescendantOf(workspace)) then return false end
	if not m:FindFirstChild("Hitboxes") or m:GetAttribute("Bitable") ~= true then return false end
	if m:GetAttribute("Species") == nil and m:GetAttribute("IsBot") ~= true then return false end
	if m:GetAttribute("DummyState") == "ko" then return false end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return false end
	local pl = Players:GetPlayerFromCharacter(m)
	if pl then
		if not arenaMode() or pl:GetAttribute("InMenu") == true then return false end
		if squadmate(self, m) then return false end
	end
	return rootOf(m) ~= nil
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function pickTarget(char)
	local hrp = rootOf(char)
	if not hrp then return nil end
	local tip = char:FindFirstChild("Head_tip", true)
	local from = tip and tip:IsA("BasePart") and tip.Position or hrp.Position
	local fwd = flat(hrp.CFrame.LookVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
	local s = char:GetScale()
	local half = math.rad(math.clamp(num(char, "DiloAssistAngle") or 30, 0, 180))
	local lo, hi = math.max(0, num(char, "DiloAssistMin") or 0) * s, math.max(0, num(char, "DiloAssistMax") or 30) * s
	local best, bestD = nil, math.huge
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	for _, b in ipairs(bots()) do table.insert(list, b) end
	for _, m in ipairs(list) do
		if isTarget(m, char) then
			local v = flat(rootOf(m).Position - from)
			local d = v.Magnitude
			if d >= lo and d <= hi and d > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= half and d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end
local ring, ringGui, ringFrame, ringStroke
local function makeRing()
	ring = Instance.new("Part")
	ring.Name = "DiloLockRing"
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Transparency = 1
	ring.Size = Vector3.new(12, 0.1, 12)
	ring.Parent = folder
	ringGui = Instance.new("SurfaceGui")
	ringGui.Face = Enum.NormalId.Top
	ringGui.LightInfluence = 0
	ringGui.AlwaysOnTop = false
	ringGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	ringGui.PixelsPerStud = 20
	ringGui.Parent = ring
	ringFrame = Instance.new("Frame")
	ringFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	ringFrame.Position = UDim2.fromScale(0.5, 0.5)
	ringFrame.Size = UDim2.fromScale(0.94, 0.94)
	ringFrame.BackgroundTransparency = 1
	ringFrame.Parent = ringGui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = ringFrame
	ringStroke = Instance.new("UIStroke")
	ringStroke.Color = RING
	ringStroke.Thickness = 16
	ringStroke.Transparency = 0.2
	ringStroke.Parent = ringFrame
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
RunService.RenderStepped:Connect(function()
	local char = me.Character
	local want = nil
	if char and on("DiloFXRingEnabled") and char:GetAttribute("Species") == "Dilo" and char:GetAttribute("DiloLocalState") == "armed" then
		want = pickTarget(char)
	end
	script:SetAttribute("DiloFXRingTarget", want and want.Name or "")
	if not want then
		if ring then ring.Parent = nil end
		return
	end
	if not ring then makeRing() end
	ring.Parent = folder
	local k = scaleK(char)
	local r = rootOf(want)
	rayParams.FilterDescendantsInstances = {folder, want, char}
	local hit = workspace:Raycast(r.Position, Vector3.new(0, -60, 0), rayParams)
	local y = hit and hit.Position.Y or (r.Position.Y - want:GetExtentsSize().Y / 2)
	local d = 11.2 * k * (1 + math.sin(os.clock() * 8) * 0.04)
	ring.Size = Vector3.new(d, 0.1, d)
	ring.CFrame = CFrame.new(r.Position.X, y + 0.15, r.Position.Z)
	ringStroke.Thickness = math.max(4, 0.8 * k * ringGui.PixelsPerStud)
end)
