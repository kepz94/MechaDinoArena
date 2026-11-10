-- TrooSlotFX v1.1 (Mecha Dino Arena) — the Troodon slot parts' effects on every client (StarterPlayerScripts). Plan
-- docs/plans/TROODON_SLOTPARTS_v1.0.md T4 (MDA-381); looks + timings = docs/mockups/troodon_slotparts_v0.1.html (Kepu
-- 2026-11-10 picks); server stamps = TrooSlotServer 1.0. Everything lives in a local Workspace.TrooSlotFX folder (Neon, no
-- collision, no queries, no shadows). Each move reads wind-up -> action -> result -> recovery; no landing FX on the troodon.
-- * Throws (Bloom Burst / Shield Dome / Sentry Pod): at <X>At + TrooSlot_throwWindup (0.34, the pose's release) the carried
--   piece leaves the hand (its on-body OPart_<id> "carry" pieces go see-through from the press until they regrow) and flies a
--   pod arc (TrooFX's: peak 9 x scale / 2) from <X>From to <X>To over <X>Flight.
--   Bloom Burst: TrooBurstLandAt -> a green flash, two flat rings out to TrooPartBurstRadius, green sparks; the bud regrows on
--   the sling 0.8 s later. Boosted dinos (TrooBoostUntil ahead) wear a green Highlight; cut ones (TrooHealCutUntil ahead) a
--   purple Highlight + a "NO HEAL" tag.
--   Shield Dome: the landing ring (blue); the dome is the server's ForceField ball; every blocked hit on it (WallBlockedAt,
--   SapWallBlock 1.3) flashes a blue ripple + sparks at WallBlockedPos; the canister regrows when the dome ends.
--   Sentry Pod: the turret (server) fires; each TrooSentryShotAt on it -> a muzzle flash + an amber bolt over the shot's flight
--   + a hit flash; TrooSentryEndAt -> teal sparks; the folded turret regrows on the saddle.
-- * Sleep Dart: TrooSleepFireAt -> a violet muzzle flash at the head and a violet dart with a trail From -> To over Flight;
--   TrooSleepSplitAt -> a second dart from the target to the next one. Sleeping dinos (TrooSleepUntil ahead) wear a violet
--   Highlight + a "Zz" tag with the seconds left; TrooSleepWokeAt -> a white flash.
-- * Bloom Tank (star): TrooBloomPulseAt -> a teal-green ring out to TrooBloomPulseRadius + a flash at TrooBloomPulseCenter.
-- Switches (script attributes, read at each event): TrooSlotFXEnabled, TrooSlotFX_<id>Enabled (obloom / oburst / odome /
--   osleep / osentry). Diagnostic: script TrooSlotFXLast ("<id>:<phase>").
-- v1.1 (plan docs/plans/TROODON_SLOTVFX_v1.0.md, MDA-384 / MDA-385; mockup docs/mockups/troodon_slotvfx_v0.1.html, Kepu
--   2026-11-10 11:36 picks "Lattice Bastion" + "Blossom Nova", 11:38 "Build"). Client only; the server, blocking and numbers are
--   unchanged.
--   * Shield Dome · Lattice Bastion (switch TrooSlotFX_domeLatticeEnabled, default true; false = 1.0): for each TrooDome part a
--     geodesic frame (icosahedron, TrooSlotFX_latticeDetail 2 = 135 beams on the upper half, TrooSlotFX_latticeThick 0.5 studs)
--     at TrooDomeRadius turns on from the ground up in TrooSlotFX_latticeBuild 0.55 s, TrooSlotFX_latticePillars 10 base pillars
--     flare, a base ring and a scan band (TrooSlotFX_latticeRingSegs 48 segments each) climbing every TrooSlotFX_latticeScan
--     1.4 s; edge glow = a Highlight on the ball (fill 5AB4FF 0.85, outline BFE6FF, Occluded). A blocked hit (WallBlockedAt)
--     also lights the struck triangle (2 WedgeParts, 0.45 s) + a ring on the surface; all beams pulse. The frame drops away
--     top-down in the last TrooSlotFX_latticeFall 0.45 s (TrooDomeUntil), then is destroyed (also when the ball goes).
--     Diagnostics: TrooSlotFXLast "odome:lattice" / "odome:panel", script TrooSlotFXLatticeParts (parts in the last frame).
--   * Bloom Burst · Blossom Nova (switch TrooSlotFX_burstNovaEnabled, default true; false = 1.0 flash + rings + sparks): at
--     TrooBurstLandAt (the server heals then) a flash, TrooSlotFX_novaPetals 6 Neon petals (Sphere SpecialMesh) unfold flat to
--     1.1 x TrooPartBurstRadius long in TrooSlotFX_novaOpen 0.28 s, a light column TrooSlotFX_novaColumn 40 studs up, the white +
--     green rings, TrooSlotFX_novaDrift 26 petals drifting out over the area (1.6 s); each boosted squadmate inside gets
--     TrooSlotFX_novaSwirl 6 petals swirling 1.1 s, each cut enemy inside a violet disc shrinking at its feet + a dark puff.
--     Diagnostic: TrooSlotFXLast "oburst:nova".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local VERSION = "1.1"
script:SetAttribute("TrooSlotFXVersion", VERSION)
for _, k in ipairs({"TrooSlotFXEnabled", "TrooSlotFX_obloomEnabled", "TrooSlotFX_oburstEnabled", "TrooSlotFX_odomeEnabled",
	"TrooSlotFX_osleepEnabled", "TrooSlotFX_osentryEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
-- v1.1 switches + numbers
for _, k in ipairs({"TrooSlotFX_domeLatticeEnabled", "TrooSlotFX_burstNovaEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
for k, v in pairs({latticeDetail = 2, latticeThick = 0.5, latticeBuild = 0.55, latticeFall = 0.45, latticeScan = 1.4, latticePillars = 10,
	latticeRingSegs = 48, novaPetals = 6, novaOpen = 0.28, novaSize = 0.55, novaColumn = 40, novaDrift = 26, novaSwirl = 6}) do
	if script:GetAttribute("TrooSlotFX_" .. k) == nil then script:SetAttribute("TrooSlotFX_" .. k, v) end
end
local function cfgN(k, d) local v = script:GetAttribute("TrooSlotFX_" .. k); return typeof(v) == "number" and v or d end
local THROW_WINDUP = 0.34
local GREEN, BLUE, VIOLET, AMBER, TEAL = Color3.fromHex("8dffb6"), Color3.fromHex("6cc4ff"), Color3.fromHex("b88cff"),
	Color3.fromHex("ffc35a"), Color3.fromHex("2fe6c8")
local function on(id) return script:GetAttribute("TrooSlotFXEnabled") ~= false and script:GetAttribute("TrooSlotFX_" .. id .. "Enabled") ~= false end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k) local v = m:GetAttribute(k); return typeof(v) == "number" and v or nil end
local function diag(id, ph) script:SetAttribute("TrooSlotFXLast", id .. ":" .. ph) end
local function scaleOf(m) local ok, v = pcall(function() return m:GetScale() end); return ok and v or 1 end

local fx = workspace:FindFirstChild("TrooSlotFX")
if not fx then fx = Instance.new("Folder"); fx.Name = "TrooSlotFX"; fx.Parent = workspace end
local function part(shape, size, color, cf, transp)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transp or 0
	if shape then p.Shape = shape end
	p.CFrame = cf
	p.Parent = fx
	return p
end
local function animate(dur, fn, done)
	local t0 = os.clock()
	local c
	c = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / math.max(1e-3, dur), 0, 1)
		local ok = pcall(fn, u)
		if u >= 1 or not ok then c:Disconnect(); if done then done() end end
	end)
end
local function flash(pos, size, color, life)
	local p = part(Enum.PartType.Ball, Vector3.one * size * 0.3, color, CFrame.new(pos), 0.1)
	animate(life or 0.3, function(u) p.Size = Vector3.one * size * (0.3 + 0.7 * u); p.Transparency = 0.1 + 0.9 * u end, function() p:Destroy() end)
end
local function ring(center, R, color, life, thick)
	local p = part(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), color, CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.2)
	animate(life or 0.5, function(u)
		local r = math.max(0.5, R * (0.15 + 0.85 * (1 - (1 - u) ^ 2)))
		p.Size = Vector3.new(thick or 0.25, r * 2, r * 2)
		p.Transparency = 0.35 + 0.65 * u
	end, function() p:Destroy() end)
end
local function sparks(pos, color, n, speed)
	local a = Instance.new("Attachment")
	local holder = part(nil, Vector3.one * 0.2, color, CFrame.new(pos), 1)
	a.Parent = holder
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new((speed or 20) * 0.5, speed or 20)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = a
	e:Emit(n or 16)
	Debris:AddItem(holder, 1)
end
local function arc(from, to, flight, peak, color, size, trailColor, done)
	local p = part(Enum.PartType.Ball, Vector3.one * size, color, CFrame.new(from), 0)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, size * 0.3, 0), Vector3.new(0, -size * 0.3, 0)
	a0.Parent, a1.Parent = p, p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(trailColor or color)
	tr.LightEmission = 1
	tr.Lifetime = 0.25
	tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	tr.Parent = p
	animate(flight, function(u)
		local pos = from:Lerp(to, u) + Vector3.new(0, 4 * peak * u * (1 - u), 0)
		p.CFrame = CFrame.new(pos)
	end, function() p:Destroy(); if done then done() end end)
end

-- v1.1 helpers ---------------------------------------------------------------------------------------------------------------------
local SH_BLUE, SH_PALE, SH_WHITE = Color3.fromHex("5ab4ff"), Color3.fromHex("bfe6ff"), Color3.fromHex("eaf7ff")
local LEAF, LEAF_PALE, NOHEAL = Color3.fromHex("46e08a"), Color3.fromHex("c8ffd8"), Color3.fromHex("b36bff")
local function outBack(u) local c = 1.9; return 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2 end
local function outCubic(u) return 1 - (1 - u) ^ 3 end
-- a flat ring standing on a surface, facing n (the Cylinder's axis = n)
local function axisRing(pos, n, R, color, life)
	local p = part(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), color, CFrame.lookAt(pos, pos + n) * CFrame.Angles(0, math.rad(90), 0), 0.2)
	animate(life or 0.4, function(u) local r = math.max(0.3, R * outCubic(u)); p.Size = Vector3.new(0.2, r * 2, r * 2); p.Transparency = 0.3 + 0.7 * u end, function() p:Destroy() end)
end
-- a filled triangle a, b, c from two WedgeParts (the standard right-triangle split)
local function triangle(a, b, c, color, thick)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then c, a = a, c elseif acd > bcd and acd > abd then a, b = b, a end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local h = math.abs(ab:Dot(up))
	local out = {}
	for i, w in ipairs({{(a + b) / 2, right, math.abs(ab:Dot(back)), back}, {(a + c) / 2, -right, math.abs(ac:Dot(back)), -back}}) do
		local p = Instance.new("WedgePart")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material, p.Color = Enum.Material.Neon, color
		p.Size = Vector3.new(thick, h, w[3])
		p.CFrame = CFrame.fromMatrix(w[1], w[2], up, w[4])
		p.Parent = fx
		out[i] = p
	end
	return out
end
-- a petal: a Neon ellipsoid (Part + Sphere SpecialMesh, no image)
local function petal(size, color, cf)
	local p = part(nil, size, color, cf, 0)
	local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
	return p
end
-- the geodesic half-sphere (icosahedron subdivided like three.js IcosahedronGeometry(1, detail), the mockup's frame): unit
-- faces with every corner at y > -0.02 and their unique edges; built once per detail
local GEO = {}
local function geodesic(detail)
	if GEO[detail] then return GEO[detail] end
	local t = (1 + math.sqrt(5)) / 2
	local V = {{-1, t, 0}, {1, t, 0}, {-1, -t, 0}, {1, -t, 0}, {0, -1, t}, {0, 1, t}, {0, -1, -t}, {0, 1, -t}, {t, 0, -1}, {t, 0, 1}, {-t, 0, -1}, {-t, 0, 1}}
	local I = {0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1}
	local cols = detail + 1
	local faces = {}
	local function add(a, b, c)
		a, b, c = a.Unit, b.Unit, c.Unit
		if math.min(a.Y, b.Y, c.Y) > -0.02 then table.insert(faces, {a, b, c}) end
	end
	for f = 0, 19 do
		local A = Vector3.new(table.unpack(V[I[f * 3 + 1] + 1])); local B = Vector3.new(table.unpack(V[I[f * 3 + 2] + 1])); local C = Vector3.new(table.unpack(V[I[f * 3 + 3] + 1]))
		local v = {}
		for i = 0, cols do
			v[i] = {}
			local aj, bj = A:Lerp(C, i / cols), B:Lerp(C, i / cols)
			local rows = cols - i
			for j = 0, rows do v[i][j] = (j == 0 and i == cols) and aj or aj:Lerp(bj, j / math.max(1, rows)) end
		end
		for i = 0, cols - 1 do
			for j = 0, 2 * (cols - i) - 2 do
				local k = math.floor(j / 2)
				if j % 2 == 0 then add(v[i][k + 1], v[i + 1][k], v[i][k]) else add(v[i][k + 1], v[i + 1][k + 1], v[i + 1][k]) end
			end
		end
	end
	local seen, edges = {}, {}
	local function key(p) return ("%.4f,%.4f,%.4f"):format(p.X, p.Y, p.Z) end
	for _, f in ipairs(faces) do
		for i = 1, 3 do
			local a, b = f[i], f[i % 3 + 1]
			local ka, kb = key(a), key(b)
			local k = ka < kb and ka .. "|" .. kb or kb .. "|" .. ka
			if not seen[k] then seen[k] = true; table.insert(edges, {a, b}) end
		end
	end
	GEO[detail] = {faces = faces, edges = edges}
	return GEO[detail]
end
-- the on-body carried pieces of a part (TrooPartsServer 1.2 OPart_<id>, role "carry"): see-through while away
local function carryHide(char, id, hidden)
	local m = char:FindFirstChild("OPart_" .. id)
	if not m then return end
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("OPartRole") == "carry" then p.LocalTransparencyModifier = hidden and 1 or 0 end
	end
end
local function regrow(char, id, at)
	task.delay(math.max(0, at - now()), function()
		if not char.Parent then return end
		local m = char:FindFirstChild("OPart_" .. id)
		if not m then return end
		animate(0.4, function(u)
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") and p:GetAttribute("OPartRole") == "carry" then p.LocalTransparencyModifier = 1 - u end
			end
		end)
	end)
end

-- throws ------------------------------------------------------------------------------------------------------------------------
local function throwFx(char, id, prefix, color, size)
	local at, from, to, flight = num(char, prefix .. "At"), char:GetAttribute(prefix .. "From"), char:GetAttribute(prefix .. "To"), num(char, prefix .. "Flight")
	if not (at and typeof(from) == "Vector3" and typeof(to) == "Vector3" and flight) or now() - at > 2 then return end
	local s = scaleOf(char)
	diag(id, "windup")
	carryHide(char, id, true)
	task.delay(math.max(0, at + THROW_WINDUP - now()), function()
		diag(id, "action")
		arc(from, to, flight, 9 * s / 2, color, size * s, color, function()
			diag(id, "result")
			ring(to, 4 * s, color, 0.35, 0.2)
		end)
	end)
end

-- highlights: boost / cut / sleep -----------------------------------------------------------------------------------------------
local marks = {}
local function tagGui(m, text, color)
	local root = m:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local b = Instance.new("BillboardGui")
	b.Name = "TrooSlotTag"
	b.Size = UDim2.fromOffset(110, 34)
	b.StudsOffsetWorldSpace = Vector3.new(0, 6 * scaleOf(m), 0)
	b.AlwaysOnTop = true
	b.Adornee = root
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.Parent = b
	b.Parent = fx
	return b, l
end
local function setMark(m, kind, want, color, text)
	marks[m] = marks[m] or {}
	local mk = marks[m][kind]
	if want and not mk then
		local h = Instance.new("Highlight")
		h.FillColor, h.OutlineColor = color, color
		h.FillTransparency, h.OutlineTransparency = 0.7, 0.2
		h.Adornee = m
		h.Parent = fx
		local g, l = nil, nil
		if text then g, l = tagGui(m, text, color) end
		mk = {h = h, g = g, l = l}
		marks[m][kind] = mk
	elseif not want and mk then
		mk.h:Destroy()
		if mk.g then mk.g:Destroy() end
		marks[m][kind] = nil
	end
	return mk
end
local function watchedModels()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	if bots then for _, b in ipairs(bots:GetChildren()) do table.insert(list, b) end end
	return list
end
task.spawn(function()
	while true do
		local t = now()
		local seen = {}
		for _, m in ipairs(watchedModels()) do
			seen[m] = true
			setMark(m, "boost", on("oburst") and (num(m, "TrooBoostUntil") or 0) > t, GREEN, nil)
			setMark(m, "cut", on("oburst") and (num(m, "TrooHealCutUntil") or 0) > t, VIOLET, "NO HEAL")
			local su = num(m, "TrooSleepUntil") or 0
			local mk = setMark(m, "sleep", on("osleep") and su > t, VIOLET, "Zz")
			if mk and mk.l then mk.l.Text = ("Zz %.1f"):format(math.max(0, su - t)) end
		end
		for m, kinds in pairs(marks) do
			if not seen[m] or not m.Parent then
				for k in pairs(kinds) do setMark(m, k, false) end
				marks[m] = nil
			end
		end
		task.wait(0.1)
	end
end)


-- v1.1 Bloom Burst · Blossom Nova ------------------------------------------------------------------------------------------------------
local function novaOn() return on("oburst") and script:GetAttribute("TrooSlotFX_burstNovaEnabled") ~= false end
local function blossomNova(to, R, s)
	diag("oburst", "nova")
	local g = Vector3.new(to.X, to.Y + 0.3, to.Z)
	flash(g + Vector3.new(0, 1.5 * s, 0), 14 * s, Color3.fromHex("eaffea"), 0.3)
	-- petals: unfold flat (Back), turn slowly, fade
	local n, L = math.max(3, math.floor(cfgN("novaPetals", 6))), 2 * cfgN("novaSize", 0.55) * R
	local W, open = 0.46 * L, cfgN("novaOpen", 0.28)
	local ps = {}
	for i = 1, n do ps[i] = petal(Vector3.new(0.1, 0.1, 0.1), i % 2 == 0 and Color3.fromHex("baffd0") or LEAF_PALE, CFrame.new(g)) end
	local disc = part(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), Color3.new(1, 1, 1), CFrame.new(g + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0)
	animate(1.3, function(u)
		local tt = u * 1.3
		local k = outBack(math.min(1, tt / open))
		local tilt = (1 - math.min(1, tt / open)) * 1.3
		for i, p in ipairs(ps) do
			local yaw = (i - 1) / n * math.pi * 2 + tt * 0.6
			local base = CFrame.new(g) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
			p.Size = Vector3.new(math.max(0.1, W * k), 0.3, math.max(0.1, L * k))
			p.CFrame = base * CFrame.new(0, 0, -L * k / 2)
			p.Transparency = 0.05 + 0.95 * math.clamp((tt - 0.6) / 0.7, 0, 1)
		end
		local dr = math.max(0.3, 0.45 * L / 2 * k * 2)
		disc.Size = Vector3.new(0.2, dr, dr)
		disc.Transparency = math.clamp((tt - 0.2) / 0.7, 0, 1)
	end, function() for _, p in ipairs(ps) do p:Destroy() end; disc:Destroy() end)
	-- the light column
	local colH = cfgN("novaColumn", 40)
	local col = part(Enum.PartType.Cylinder, Vector3.new(1, 7, 7), Color3.fromHex("d8ffe0"), CFrame.new(g), 0.1)
	animate(0.7, function(u)
		local h = math.max(0.5, colH * outCubic(math.min(1, u * 2.5)))
		local d = 7 * (1 - 0.6 * u)
		col.Size = Vector3.new(h, d, d)
		col.CFrame = CFrame.new(g + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		col.Transparency = 0.1 + 0.9 * u
	end, function() col:Destroy() end)
	-- shockwave rings (the 1.0 rings, wider)
	ring(to, R, Color3.new(1, 1, 1), 0.55, 0.35)
	task.delay(0.08, function() ring(to, R * 1.02, LEAF, 0.7, 0.3) end)
	-- drifting petals
	local drift = {}
	for i = 1, math.max(0, math.floor(cfgN("novaDrift", 26))) do
		local a, r = math.random() * math.pi * 2, math.random() * R
		local sz = 1.6 + math.random()
		drift[i] = {p = petal(Vector3.new(sz * 0.6, 0.15, sz), i % 3 == 0 and Color3.new(1, 1, 1) or LEAF_PALE, CFrame.new(g)),
			to = g + Vector3.new(math.cos(a) * r, 8 + math.random() * 8, math.sin(a) * r), spin = math.random() * 6}
	end
	local from = g + Vector3.new(0, 3, 0)
	animate(1.6, function(u)
		for _, d in ipairs(drift) do
			local pos = from:Lerp(d.to, outCubic(math.min(1, u * 1.6))) - Vector3.new(0, u * u * 7, 0)
			d.p.CFrame = CFrame.new(pos) * CFrame.Angles(u * 4 + d.spin, u * 6 + d.spin, 0)
			d.p.Transparency = math.clamp((u - 0.7) / 0.3, 0, 1)
		end
	end, function() for _, d in ipairs(drift) do d.p:Destroy() end end)
	-- the squad / enemies inside (the server stamps TrooBoostUntil / TrooHealCutUntil before TrooBurstLandAt)
	local t = now()
	task.delay(0.1, function()
		for _, m in ipairs(watchedModels()) do
			local root = m:FindFirstChild("HumanoidRootPart")
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(to.X, 0, to.Z)).Magnitude <= R + 1.5 then
				local ms = scaleOf(m)
				if (num(m, "TrooBoostUntil") or 0) > t then
					local sw = {}
					for i = 1, math.max(0, math.floor(cfgN("novaSwirl", 6))) do sw[i] = petal(Vector3.new(0.8 * ms, 0.12, 1.4 * ms), LEAF_PALE, root.CFrame) end
					animate(1.1, function(u)
						if not root.Parent then return end
						for i, p in ipairs(sw) do
							local a = u * 9 + i
							p.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * 4 * ms, (-1.5 + u * 4) * ms, math.sin(a) * 4 * ms)) * CFrame.Angles(0, -a, 0.5)
							p.Transparency = u
						end
					end, function() for _, p in ipairs(sw) do p:Destroy() end end)
				elseif (num(m, "TrooHealCutUntil") or 0) > t then
					local feet = root.Position - Vector3.new(0, 2.5 * ms, 0)
					local d = part(Enum.PartType.Cylinder, Vector3.new(0.2, 12 * ms, 12 * ms), NOHEAL, CFrame.new(feet) * CFrame.Angles(0, 0, math.rad(90)), 0.2)
					animate(1.2, function(u) local r = 12 * ms * (1 - 0.5 * u); d.Size = Vector3.new(0.2, r, r); d.Transparency = 0.2 + 0.8 * u end, function() d:Destroy() end)
					sparks(root.Position, Color3.fromHex("6a3a8a"), 14, 8)
				end
			end
		end
	end)
end

-- per character --------------------------------------------------------------------------------------------------------------------
local function watchChar(char)
	char:GetAttributeChangedSignal("TrooBurstAt"):Connect(function()
		if on("oburst") then throwFx(char, "oburst", "TrooBurst", GREEN, 0.8) end
	end)
	char:GetAttributeChangedSignal("TrooBurstLandAt"):Connect(function()
		if not on("oburst") then return end
		local to = char:GetAttribute("TrooBurstTo")
		if typeof(to) ~= "Vector3" then return end
		local R = num(char, "TrooPartBurstRadius") or 20
		local s = scaleOf(char)
		if novaOn() then -- v1.1
			blossomNova(to, R, s)
		else
			diag("oburst", "burst")
			flash(to + Vector3.new(0, 2 * s, 0), 8 * s, GREEN, 0.35)
			ring(to, R, GREEN, 0.55, 0.3)
			task.delay(0.12, function() ring(to, R * 0.75, Color3.fromHex("d6ffe6"), 0.5, 0.2) end)
			sparks(to + Vector3.new(0, 1.5 * s, 0), GREEN, 26, 26)
		end
		regrow(char, "oburst", now() + 0.8)
	end)
	char:GetAttributeChangedSignal("TrooDomeAt"):Connect(function()
		if not on("odome") then return end
		throwFx(char, "odome", "TrooDome", BLUE, 0.9)
	end)
	char:GetAttributeChangedSignal("TrooDomeUntil"):Connect(function()
		local u = num(char, "TrooDomeUntil")
		if u and u > now() then regrow(char, "odome", u) end
	end)
	char:GetAttributeChangedSignal("TrooSentryAt"):Connect(function()
		if on("osentry") then throwFx(char, "osentry", "TrooSentry", AMBER, 1) end
	end)
	char:GetAttributeChangedSignal("TrooSentryUntil"):Connect(function()
		local u = num(char, "TrooSentryUntil")
		if u then regrow(char, "osentry", u + 0.4) end
	end)
	char:GetAttributeChangedSignal("TrooSleepFireAt"):Connect(function()
		if not on("osleep") then return end
		local from, to, flight = char:GetAttribute("TrooSleepFrom"), char:GetAttribute("TrooSleepTo"), num(char, "TrooSleepFlight")
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not flight then return end
		local s = scaleOf(char)
		diag("osleep", "action")
		flash(from, 3 * s, VIOLET, 0.2)
		arc(from, to, flight, 0, VIOLET, 0.45 * s, VIOLET, function()
			diag("osleep", "result")
			flash(to, 5 * s, Color3.fromHex("e2ccff"), 0.3)
			sparks(to, VIOLET, 12, 14)
		end)
	end)
	char:GetAttributeChangedSignal("TrooSleepSplitAt"):Connect(function()
		if not on("osleep") then return end
		local from, to = char:GetAttribute("TrooSleepSplitFrom"), char:GetAttribute("TrooSleepSplitTo")
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then return end
		arc(from, to, 0.2, 0, VIOLET, 0.4 * scaleOf(char), VIOLET, function() flash(to, 4 * scaleOf(char), Color3.fromHex("e2ccff"), 0.3) end)
	end)
	char:GetAttributeChangedSignal("TrooBloomPulseAt"):Connect(function()
		if not on("obloom") then return end
		local c, R = char:GetAttribute("TrooBloomPulseCenter"), num(char, "TrooBloomPulseRadius")
		if typeof(c) ~= "Vector3" or not R then return end
		diag("obloom", "pulse")
		ring(c, R, TEAL, 0.6, 0.35)
		ring(c, R * 0.6, GREEN, 0.5, 0.25)
		flash(c + Vector3.new(0, 1, 0), 6 * scaleOf(char), GREEN, 0.3)
	end)
end
local function watchWoken(m)
	m:GetAttributeChangedSignal("TrooSleepWokeAt"):Connect(function()
		if not on("osleep") then return end
		local r = m:FindFirstChild("HumanoidRootPart")
		if r then flash(r.Position, 5 * scaleOf(m), Color3.new(1, 1, 1), 0.25) end
	end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(function(c) watchChar(c); watchWoken(c) end)
	if pl.Character then watchChar(pl.Character); watchWoken(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 30)
	local bots = isl and isl:WaitForChild("Bots", 30)
	if not bots then return end
	bots.ChildAdded:Connect(watchWoken)
	for _, b in ipairs(bots:GetChildren()) do watchWoken(b) end
end)

-- v1.1 Shield Dome · Lattice Bastion -----------------------------------------------------------------------------------------------
local function latticeOn() return on("odome") and script:GetAttribute("TrooSlotFX_domeLatticeEnabled") ~= false end
local LATTICE = {} -- dome part -> {hit = fn}
local function latticeBastion(ball)
	local R = num(ball, "TrooDomeRadius")
	local untilT = num(ball, "TrooDomeUntil") or 0
	if not R or untilT <= now() then return end
	diag("odome", "lattice")
	local c = ball.Position
	local geo = geodesic(math.clamp(math.floor(cfgN("latticeDetail", 2)), 0, 3))
	local th, BUILD, FALL = cfgN("latticeThick", 0.5), cfgN("latticeBuild", 0.55), cfgN("latticeFall", 0.45)
	local lateJoin = ball.Size.X > R * 1.5 -- joined mid-dome: show it built
	local t0 = lateJoin and (now() - BUILD - 1) or now()
	local model = Instance.new("Model"); model.Name = "TrooDomeLattice"; model.Parent = fx
	local function mk(shape, size, color, cf, tr) local p = part(shape, size, color, cf, tr); p.Parent = model; return p end
	local beams = {}
	for _, e in ipairs(geo.edges) do
		local a, b = c + e[1] * R, c + e[2] * R
		local p = mk(nil, Vector3.new(th, th, (b - a).Magnitude + th * 0.5), Color3.fromHex("7cc4ff"), CFrame.lookAt((a + b) / 2, b), 1)
		table.insert(beams, {p = p, h = math.max(e[1].Y, e[2].Y), lit = false})
	end
	local SEG = math.max(12, math.floor(cfgN("latticeRingSegs", 48)))
	local segL = 2 * math.pi * R / SEG * 1.05
	local base, band = {}, {}
	for i = 1, SEG do
		local a = (i - 0.5) / SEG * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * R, 0.3, math.sin(a) * R)
		base[i] = mk(nil, Vector3.new(th * 1.6, th * 0.8, segL), SH_WHITE, CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))), 1)
		band[i] = mk(nil, Vector3.new(th * 0.8, th * 0.8, segL), SH_WHITE, CFrame.new(c), 1)
	end
	local pillars = {}
	for i = 1, math.max(0, math.floor(cfgN("latticePillars", 10))) do
		local a = (i - 1) / math.max(1, cfgN("latticePillars", 10)) * math.pi * 2
		pillars[i] = mk(nil, Vector3.new(th, R * 0.5, th), SH_PALE, CFrame.new(c + Vector3.new(math.cos(a) * R, R * 0.25, math.sin(a) * R)), 1)
	end
	local hl = Instance.new("Highlight")
	hl.FillColor, hl.FillTransparency, hl.OutlineColor, hl.OutlineTransparency = SH_BLUE, 0.85, SH_PALE, 0.1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = ball
	hl.Parent = model
	script:SetAttribute("TrooSlotFXLatticeParts", #model:GetChildren())
	local pulse, lastBand, gone = 0, 0, false
	local conn
	local function finish()
		if gone then return end
		gone = true
		if conn then conn:Disconnect() end
		LATTICE[ball] = nil
		model:Destroy()
	end
	local endAt = untilT
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = now()
		local u0 = num(ball, "TrooDomeUntil") or 0
		if u0 == 0 and endAt > t + 0.2 then endAt = t + 0.2 end -- the server ended it early
		if not ball.Parent or t > endAt + 0.1 then finish() return end
		local e = t - t0
		local hb
		if t > endAt - FALL then hb = 1.02 * (1 - math.clamp((t - (endAt - FALL)) / FALL, 0, 1))
		elseif e < BUILD then hb = 1.02 * outCubic(math.clamp(e / BUILD, 0, 1))
		else hb = 1.02 end
		pulse = math.max(0, pulse - dt * 3)
		local tr = 0.15 - 0.15 * pulse
		for _, b in ipairs(beams) do
			local want = b.h <= hb
			if want ~= b.lit or (want and pulse > 0) then b.lit = want; b.p.Transparency = want and tr or 1 end
		end
		local baseT = (t > endAt - 0.1) and 1 or 0.05
		if base[1].Transparency ~= baseT then for _, p in ipairs(base) do p.Transparency = baseT end end
		if t - lastBand > 1 / 30 then -- the scan band, 30 times a second
			lastBand = t
			local sw = e < BUILD and math.min(0.999, hb) or ((e - BUILD) / cfgN("latticeScan", 1.4)) % 1
			local rr = math.sqrt(math.max(0, 1 - sw * sw)) * R
			local bt = (t > endAt - FALL) and 1 or (e < BUILD and 0 or 1 - 0.6 * math.sin(math.pi * sw))
			local parts, cfs = {}, {}
			for i, p in ipairs(band) do
				local a = (i - 0.5) / SEG * math.pi * 2
				local pos = c + Vector3.new(math.cos(a) * rr, sw * R, math.sin(a) * rr)
				parts[i], cfs[i] = p, CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
				p.Size = Vector3.new(th * 0.8, th * 0.8, math.max(0.2, 2 * math.pi * rr / SEG * 1.05))
				p.Transparency = bt
			end
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			local pt = e < BUILD + 0.3 and 0.1 + 0.9 * math.clamp((e - BUILD) / 0.3, 0, 1) or 0.7
			if t > endAt - FALL then pt = 1 end
			for _, p in ipairs(pillars) do p.Transparency = pt end
		end
		hl.FillTransparency = 0.85 - 0.25 * pulse
	end)
	LATTICE[ball] = {hit = function(pos)
		pulse = 1
		local q = (pos - c) / R
		local best, bd = nil, math.huge
		for _, f in ipairs(geo.faces) do local d = ((f[1] + f[2] + f[3]) / 3 - q).Magnitude; if d < bd then bd, best = d, f end end
		if best then
			local ws = triangle(c + best[1] * R * 1.004, c + best[2] * R * 1.004, c + best[3] * R * 1.004, SH_WHITE, th * 0.6)
			for _, w in ipairs(ws) do w.Transparency = 0 end
			animate(0.45, function(u) for _, w in ipairs(ws) do w.Transparency = u end end, function() for _, w in ipairs(ws) do w:Destroy() end end)
		end
		local nrm = (pos - c).Magnitude > 1e-3 and (pos - c).Unit or Vector3.yAxis
		axisRing(pos, nrm, 6, SH_PALE, 0.4)
		diag("odome", "panel")
	end}
	ball.Destroying:Connect(finish)
end

-- domes: blocked hits ------------------------------------------------------------------------------------------------------------------
local function watchDome(p)
	if not p:IsA("BasePart") then return end
	if latticeOn() then task.defer(latticeBastion, p) end -- v1.1
	p:GetAttributeChangedSignal("WallBlockedAt"):Connect(function()
		if not on("odome") then return end
		local pos = p:GetAttribute("WallBlockedPos")
		if typeof(pos) ~= "Vector3" then return end
		diag("odome", "blocked")
		flash(pos, 4, Color3.fromHex("cfe8ff"), 0.3)
		sparks(pos, BLUE, 10, 16)
		if LATTICE[p] and latticeOn() then LATTICE[p].hit(pos) end -- v1.1
	end)
	p:GetAttributeChangedSignal("TrooDomeUntil"):Connect(function()
		if (p:GetAttribute("TrooDomeUntil") or 0) == 0 and on("odome") then sparks(p.Position + Vector3.new(0, 2, 0), BLUE, 20, 22) end
	end)
end
-- sentries: shots ------------------------------------------------------------------------------------------------------------------
local function watchSentry(m)
	if not m:IsA("Model") then return end
	m:GetAttributeChangedSignal("TrooSentryShotAt"):Connect(function()
		if not on("osentry") then return end
		local from, to, flight = m:GetAttribute("TrooSentryShotFrom"), m:GetAttribute("TrooSentryShotTo"), num(m, "TrooSentryShotFlight")
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not flight then return end
		diag("osentry", "shot")
		flash(from, 2.5, Color3.fromHex("ffe2a0"), 0.15)
		arc(from, to, flight, 0.3, AMBER, 0.7, AMBER, function() flash(to, 3, AMBER, 0.2) end)
	end)
	m:GetAttributeChangedSignal("TrooSentryEndAt"):Connect(function()
		if not on("osentry") then return end
		local pv = m:GetPivot().Position
		sparks(pv + Vector3.new(0, 2, 0), TEAL, 24, 18)
		diag("osentry", "end")
	end)
end
task.spawn(function()
	local function hook(name, fn)
		local f = workspace:FindFirstChild(name) or workspace:WaitForChild(name, 1e6)
		f.ChildAdded:Connect(fn)
		for _, c in ipairs(f:GetChildren()) do fn(c) end
	end
	task.spawn(hook, "TrooDomes", watchDome)
	task.spawn(hook, "TrooSentries", watchSentry)
end)
