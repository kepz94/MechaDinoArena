-- TrooFX v1.1 (Mecha Dino Arena) — the Troodon's Glow Pod Toss effects on this client (LocalScript, StarterPlayerScripts).
-- MDA-338, plan docs/plans/TROODON_KIT_v1.0.md Task 9; mockup docs/mockups/troodon_kit_options_v0.1.html attack A (Kepu
-- 2026-11-06 15:38; source tools/troodon_kit_mockup/app_tail.js: throwPod / updatePods / zoneBurst / updateZones). Server:
-- TrooAttackServer 1.0. Pattern copied from DiloFX 1.2 (not edited): effect list, flash / spark parts, the lock ring.
-- Everything is local (Workspace "TrooFX"), nothing is replicated. Sizes are the mockup's (studs at the 2x body) x k =
-- the troodon's scale / 2. Colours are the mockup's: pod FFC35A + glow FFD27A, embers FFB43A / FFE7A8, splat flash FFE2A0,
-- zone disc 2FE6C8, rim A8FFF0, splat wave FFF2C8, spores A8FFF0 / 6DFF8A.
-- Pod (each new TrooPodAt on a troodon character): a glowing amber ball (2.3 x k, Neon, PointLight, Trail) from the
--   troodon's hands (ArmL_hand / ArmR_hand midpoint now, else TrooPodFrom) to TrooPodTo over TrooPodFlight, lobbed in the
--   mockup's arc (height 9 x k at the middle), shedding embers (40 / s); a stamp older than the flight shows nothing.
-- Splat + zone (each new TrooZoneAt): a flash (11 x k) and 22 amber embers flung out at TrooZoneCenter; then the zone for
--   TrooZoneUntil - TrooZoneAt s: a teal disc (radius TrooZoneRadius x scale, transparency 0.66-0.8 pulsing), a bright rim
--   ring (0.7 x k wide), a pale ring wave spreading over 0.35 s, and spores rising out of the disc (26 / s); fades in over
--   0.12 s and out over the last 12 %.
-- Hit flash (each new TrooHitAt on a player character or a bot): an orange Highlight on the target (0.14 s for "splat",
--   0.07 s darker for "tick").
-- Heal pop (each new TrooHealAt, squadmates and the troodon's self-heal): "+N" (TrooHealAmount) over the model in the
--   Med-Station's MedHealPop look (90 x 34 BillboardGui, FredokaOne 26, green 46E08A, dark stroke, rises 3 studs and fades
--   over 0.8 s).
-- Lock ring (your own troodon only, from the press until the pod leaves the hands: TrooLocalState "throw" and no newer
--   TrooPodAt): DiloFX's pale yellow ring (FFF2A0) at the feet of the target TrooAttackServer would pick (closest allowed
--   target within TrooAssistAngle of the flat facing and TrooAssistMax x scale studs of the root); no target = no ring.
-- No jump-landing effects (house rule).
-- Switches: script attributes TrooFXEnabled (default true, read each event / frame), TrooFXPodEnabled, TrooFXZoneEnabled,
--   TrooFXHitEnabled, TrooFXHealEnabled, TrooFXRingEnabled (default true each).
-- Diagnostics: script TrooFXVersion, TrooFXEvents (count), TrooFXLast ("pod" / "zone" / "hit" / "heal"), TrooFXParts (effect
--   parts alive), TrooFXZones (zones showing), TrooFXRingTarget (name or "").
-- v1.1 (Troodon Flap & Glide, MDA-342, plan docs/plans/TROODON_FLAP_GLIDE_v1.0.md Task 3; mockup v0.2 J3 puff()): on each wing
--   beat of a troodon in flap mode (JumpHopBack ~= true) a puff of loose down falls away under the body: the leap (the
--   JumpPredictedAt press on your own troodon, JumpStartedAt for others, + JumpWindup, at takeoff) and each flap
--   (JumpDoublePredictedAt on your own, JumpDoubleAt for others; one puff per beat, stamps within 0.2 s of the last are the
--   same beat, older than 1 s are skipped). 10 soft balls (SmoothPlastic, D9CDB6, 1.6 x k growing to 4.6 x k, transparency
--   0.5 -> 1 over 0.5 s) from the torso, offset (+-3, -2..-4, +-2) x k, drifting (+-4, -6..-12, +-4) x k studs/s. No landing
--   effect. Switch: script attribute TrooFXPuffEnabled (default true). Diagnostic: TrooFXLast "puff", TrooFXPuffs (count).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = "1.1"
VERSION = "1.2" -- v1.2 green lock ring on a double-tapped teammate
-- v1.2 (MDA-439, plan docs/plans/DILO_TROO_TUNE_v1.0.md Task 5): while your own throw is in the hands and its double tap came
--   (TrooLocalAllyAt >= TrooLocalAt, TrooAttackTest 1.2), the lock ring goes to the closest living squadmate / Hardpoint teammate
--   (SquadRules.sameChar) within TrooAllyAngle (45, this script's attribute) degrees and TrooPodRange x scale studs, in green
--   (7BE37B); none -> the 1.1 enemy ring. Switch: script attribute TrooFXAllyRingEnabled (default true). Diagnostic:
--   TrooFXRingAlly (true / false).
local SCAN, MAX_PARTS, EMBER_RATE, SPORE_RATE = 0.1, 360, 40, 26
local ARENA_PLACE_ID = 75433819286625 -- ModeRules 1.0
local POD, POD_GLOW, AMBER, AMBER_L = Color3.fromHex("FFC35A"), Color3.fromHex("FFD27A"), Color3.fromHex("FFB43A"), Color3.fromHex("FFE7A8")
local FLASH, ZONE, RIM, WAVE, HEALC = Color3.fromHex("FFE2A0"), Color3.fromHex("2FE6C8"), Color3.fromHex("A8FFF0"),
	Color3.fromHex("FFF2C8"), Color3.fromHex("6DFF8A")
local HIT, HIT_TICK = Color3.new(1, 0.62, 0.12), Color3.new(0.55, 0.32, 0.05)
local MED_GREEN, MED_STROKE = Color3.fromRGB(70, 224, 138), Color3.fromRGB(10, 42, 20) -- MedStationServer's MedHealPop
local RING = Color3.fromHex("FFF2A0") -- DiloFX's lock ring

script:SetAttribute("TrooFXVersion", VERSION)
script:SetAttribute("TrooFXEvents", 0)
for _, k in ipairs({"TrooFXEnabled", "TrooFXPodEnabled", "TrooFXZoneEnabled", "TrooFXHitEnabled", "TrooFXHealEnabled", "TrooFXRingEnabled",
	"TrooFXPuffEnabled"}) do -- v1.1: + TrooFXPuffEnabled
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(k) return script:GetAttribute("TrooFXEnabled") ~= false and script:GetAttribute(k) ~= false end
local function note(what)
	script:SetAttribute("TrooFXEvents", (script:GetAttribute("TrooFXEvents") or 0) + 1)
	script:SetAttribute("TrooFXLast", what)
end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k) local v = m:GetAttribute(k) return typeof(v) == "number" and v == v and v or nil end

local folder = workspace:FindFirstChild("TrooFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TrooFX"
	folder.Parent = workspace
end

-- effect list (DiloFX 1.2's) -------------------------------------------------------------------------------------------------
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
local function custom(p, life, update, onEnd) return add({kind = "custom", p = p, life = life, update = update, onEnd = onEnd}) end
local function flash(pos, size, color)
	if full() then return end
	local p = part(Enum.PartType.Ball, Vector3.one, color, 0.1)
	p.Position = pos
	custom(p, 0.16, function(f, _, u)
		local s = size * (0.6 + u * 1.2)
		f.p.Size = Vector3.new(s, s, s)
		f.p.Transparency = 0.1 + 0.9 * u
	end)
end
local function ember(pos, v, size, life, g, floorY)
	if full() then return end
	local p = part(Enum.PartType.Ball, Vector3.one * size, math.random() < 0.5 and AMBER or AMBER_L, 0)
	p.Position = pos
	custom(p, life, function(f, dt, u)
		v -= Vector3.new(0, g * dt, 0)
		local np = f.p.Position + v * dt
		if floorY and np.Y < floorY then np = Vector3.new(np.X, floorY, np.Z); v = Vector3.zero end
		f.p.Position = np
		local s = size * (1 - u * 0.6)
		f.p.Size = Vector3.new(s, s, s)
		f.p.Transparency = u
	end)
end
-- a flat ring (DiloFX's lock-ring build: a SurfaceGui circle with a UIStroke) on a thin part
local function ringPart(name, color, transp)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(4, 0.1, 4)
	p.Parent = folder
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.Parent = p
	local fr = Instance.new("Frame")
	fr.AnchorPoint = Vector2.new(0.5, 0.5)
	fr.Position = UDim2.fromScale(0.5, 0.5)
	fr.Size = UDim2.fromScale(0.97, 0.97)
	fr.BackgroundTransparency = 1
	fr.Parent = g
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = fr
	local st = Instance.new("UIStroke")
	st.Color = color
	st.Thickness = 8
	st.Transparency = transp
	st.Parent = fr
	nParts += 1
	return p, st, g
end

RunService.Heartbeat:Connect(function(dt)
	for i = #fx, 1, -1 do
		local f = fx[i]
		f.t += dt
		local u = f.t / f.life
		if u >= 1 then
			if f.p then f.p:Destroy(); nParts -= 1 end
			if f.extra then for _, e in ipairs(f.extra) do e:Destroy(); nParts -= 1 end end
			if f.bb then f.bb:Destroy() end
			if f.hl then f.hl:Destroy() end
			if f.onEnd then f.onEnd() end
			table.remove(fx, i)
		elseif f.update then
			f.update(f, dt, u)
		end
	end
	script:SetAttribute("TrooFXParts", nParts)
end)

-- models -----------------------------------------------------------------------------------------------------------------------
local function bots()
	local isl = workspace:FindFirstChild("DinoIsland")
	local b = isl and isl:FindFirstChild("Bots")
	return b and b:GetChildren() or {}
end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart end
local function scaleK(m) return (m:IsA("Model") and m:GetScale() or 2) / 2 end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function hands(char)
	local a, b = char:FindFirstChild("ArmL_hand", true), char:FindFirstChild("ArmR_hand", true)
	if a and b and a:IsA("BasePart") and b:IsA("BasePart") then return (a.Position + b.Position) / 2 end
	return nil
end

-- pod --------------------------------------------------------------------------------------------------------------------------
local function spawnPod(char)
	if not on("TrooFXPodEnabled") then return end
	local at, flight = num(char, "TrooPodAt"), num(char, "TrooPodFlight")
	local from, to = char:GetAttribute("TrooPodFrom"), char:GetAttribute("TrooPodTo")
	if not at or not flight or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or flight <= 0 then return end
	if now() - at >= flight then return end
	from = hands(char) or from
	local k = scaleK(char)
	local H = 9 * k
	local ball = part(Enum.PartType.Ball, Vector3.one * 2.3 * k, POD, 0)
	ball.Name = "TrooPod"
	ball.Position = from
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = POD_GLOW, 14 * k, 2.5
	light.Parent = ball
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.6 * k, 0), Vector3.new(0, -0.6 * k, 0)
	a0.Parent, a1.Parent = ball, ball
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.22
	tr.Color = ColorSequence.new(POD_GLOW, AMBER)
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Parent = ball
	local emit, prev = 0, from
	note("pod")
	custom(ball, math.max(0.05, flight - (now() - at)), function(f, dt)
		local uu = math.clamp((now() - at) / flight, 0, 1)
		local p = from:Lerp(to, uu) + Vector3.new(0, 4 * H * uu * (1 - uu), 0)
		f.p.CFrame = CFrame.new(p) * CFrame.Angles(0, 0, f.t * 8)
		emit += dt * EMBER_RATE
		while emit >= 1 do
			emit -= 1
			local q = prev:Lerp(p, math.random())
			ember(q, Vector3.new((math.random() - 0.5) * 3, 1.5 + math.random() * 2, (math.random() - 0.5) * 3) * k,
				(0.55 + math.random() * 0.4) * k, 0.5, 0)
		end
		prev = p
	end)
end

-- splat + zone -------------------------------------------------------------------------------------------------------------------
local zonesShowing = 0
local function spawnZone(char)
	if not on("TrooFXZoneEnabled") then return end
	local at, untilT, c = num(char, "TrooZoneAt"), num(char, "TrooZoneUntil"), char:GetAttribute("TrooZoneCenter")
	if not at or not untilT or typeof(c) ~= "Vector3" or now() >= untilT then return end
	local k = scaleK(char)
	local R = math.max(0.5, num(char, "TrooZoneRadius") or 5) * char:GetScale()
	local life = untilT - at
	local center = c + Vector3.new(0, 0.12, 0)
	note("zone")
	if now() - at < 0.3 then -- the splat
		local burst = center + Vector3.new(0, 1.5 * k, 0)
		flash(burst, 11 * k, FLASH)
		for _ = 1, 22 do
			local a, sp = math.random() * math.pi * 2, (10 + math.random() * 18) * k
			ember(burst, Vector3.new(math.cos(a) * sp, (6 + math.random() * 12) * k, math.sin(a) * sp), (0.9 + math.random() * 0.9) * k,
				0.45 + math.random() * 0.25, 50 * k, c.Y + 0.3)
		end
	end
	local disc = part(Enum.PartType.Cylinder, Vector3.new(0.2, R * 2, R * 2), ZONE, 0.7)
	disc.Name = "TrooZoneDisc"
	disc.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	local rim, rimStroke, rimGui = ringPart("TrooZoneRim", RIM, 0.05)
	rim.Size = Vector3.new(R * 2, 0.1, R * 2)
	rim.CFrame = CFrame.new(center + Vector3.new(0, 0.06, 0))
	rimStroke.Thickness = math.max(4, 0.7 * k * rimGui.PixelsPerStud)
	local wave, waveStroke, waveGui = ringPart("TrooZoneWave", WAVE, 0.1)
	wave.CFrame = CFrame.new(center + Vector3.new(0, 0.08, 0))
	waveStroke.Thickness = math.max(4, 0.8 * k * waveGui.PixelsPerStud)
	local spore = 0
	zonesShowing += 1
	script:SetAttribute("TrooFXZones", zonesShowing)
	local f = custom(disc, math.max(0.1, untilT - now()), function(f, dt)
		local el = now() - at
		local u = math.clamp(el / life, 0, 1)
		local fade = u > 0.88 and math.max(0, (1 - u) / 0.12) or math.min(1, el / 0.12)
		f.p.Transparency = 1 - (0.27 + 0.07 * math.sin(el * 7)) * fade
		rimStroke.Transparency = 1 - 0.95 * fade
		local wv = math.min(1, el / 0.35)
		local wd = 2 * (0.7 * k + wv * R) -- the mockup's ring wave: outer radius 1.4 x (0.5 + wv x R / 1.4)
		wave.Size = Vector3.new(wd, 0.1, wd)
		waveStroke.Transparency = 1 - 0.9 * (1 - wv)
		spore += dt * SPORE_RATE
		while spore >= 1 and not full() do
			spore -= 1
			local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * R
			local sz = (0.8 + math.random() * 0.8) * k * 0.5
			local sp = part(Enum.PartType.Ball, Vector3.one * sz, math.random() < 0.6 and RIM or HEALC, 1)
			sp.Position = Vector3.new(c.X + math.cos(a) * r, c.Y + 0.4 * k, c.Z + math.sin(a) * r)
			local vy = (4 + math.random() * 5) * k
			custom(sp, 0.9, function(g, ddt, uu)
				g.p.Position += Vector3.new(0, vy * ddt, 0)
				g.p.Transparency = 1 - (uu < 0.2 and uu / 0.2 or 1 - uu) * fade
			end)
		end
	end, function()
		zonesShowing -= 1
		script:SetAttribute("TrooFXZones", zonesShowing)
	end)
	f.extra = {rim, wave}
end

-- hit flash + heal pops (players' characters and bots, scanned) -------------------------------------------------------------------
local seenHit = setmetatable({}, {__mode = "k"})
local seenHeal = setmetatable({}, {__mode = "k"})
local function hitFlash(m)
	if not on("TrooFXHitEnabled") then return end
	local tick = m:GetAttribute("TrooHitKind") == "tick"
	local hl = Instance.new("Highlight")
	hl.Name = "TrooHitFlash"
	hl.FillColor = tick and HIT_TICK or HIT
	hl.FillTransparency = tick and 0.55 or 0.35
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = m
	hl.Parent = folder
	note("hit")
	add({kind = "hit", hl = hl, life = tick and 0.07 or 0.14, update = function(f, _, u)
		f.hl.FillTransparency = (tick and 0.55 or 0.35) + (1 - (tick and 0.55 or 0.35)) * u
	end})
end
local function healPop(m)
	if not on("TrooFXHealEnabled") then return end
	local amount = num(m, "TrooHealAmount") or 0
	if amount <= 0 then return end
	local head = m:FindFirstChild("Head") or rootOf(m)
	if not head then return end
	local _, size = m:GetBoundingBox()
	local g = Instance.new("BillboardGui")
	g.Name = "TrooHealPop"
	g.Size = UDim2.fromOffset(90, 34)
	g.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.35, 0)
	g.AlwaysOnTop = true
	g.Adornee = head
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 26
	l.TextColor3 = MED_GREEN
	l.TextStrokeColor3 = MED_STROKE
	l.TextStrokeTransparency = 0
	l.Text = "+" .. tostring(math.floor(amount + 0.5))
	l.Parent = g
	g.Parent = folder
	local y0 = g.StudsOffsetWorldSpace.Y
	note("heal")
	add({kind = "heal", bb = g, life = 0.8, update = function(f, _, u)
		f.bb.StudsOffsetWorldSpace = Vector3.new(0, y0 + 3 * u, 0)
		l.TextTransparency, l.TextStrokeTransparency = u, u
	end})
end
local scanAcc = 0
RunService.Heartbeat:Connect(function(dt)
	scanAcc += dt
	if scanAcc < SCAN then return end
	scanAcc = 0
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	for _, b in ipairs(bots()) do table.insert(list, b) end
	local t = now()
	for _, m in ipairs(list) do
		local h = num(m, "TrooHitAt")
		if h and h ~= seenHit[m] then
			local first = seenHit[m] == nil
			seenHit[m] = h
			if not first or t - h < 0.5 then hitFlash(m) end
		end
		local e = num(m, "TrooHealAt")
		if e and e ~= seenHeal[m] then
			local first = seenHeal[m] == nil
			seenHeal[m] = e
			if not first or t - e < 0.5 then healPop(m) end
		end
	end
end)

-- v1.1: a puff of loose down on each wing beat ----------------------------------------------------------------------------------
local DOWN = Color3.fromHex("D9CDB6")
local lastPuff = setmetatable({}, {__mode = "k"})
script:SetAttribute("TrooFXPuffs", 0)
local function puff(char)
	local tb = char:FindFirstChild("Torso_body", true)
	local base = tb and tb:IsA("BasePart") and tb.Position or (rootOf(char) and rootOf(char).Position)
	if not base then return end
	local k = scaleK(char)
	note("puff")
	script:SetAttribute("TrooFXPuffs", (script:GetAttribute("TrooFXPuffs") or 0) + 1)
	for _ = 1, 10 do
		if full() then return end
		local p = part(Enum.PartType.Ball, Vector3.one * 1.6 * k, DOWN, 0.5, Enum.Material.SmoothPlastic)
		p.Position = base + Vector3.new((math.random() - 0.5) * 6, -2 - math.random() * 2, (math.random() - 0.5) * 4) * k
		local v = Vector3.new((math.random() - 0.5) * 8, -6 - math.random() * 6, (math.random() - 0.5) * 8) * k
		custom(p, 0.5, function(f, dt, u)
			f.p.Position += v * dt
			local sz = (1.6 + u * 3) * k
			f.p.Size = Vector3.new(sz, sz, sz)
			f.p.Transparency = 0.5 + 0.5 * u
		end)
	end
end
local function maybePuff(char, at, delay)
	if not on("TrooFXPuffEnabled") or char:GetAttribute("Species") ~= "Troodon" or char:GetAttribute("JumpHopBack") == true then return end
	if typeof(at) ~= "number" or math.abs(now() - at) > 1 then return end
	if lastPuff[char] and math.abs(at - lastPuff[char]) < 0.2 then return end
	lastPuff[char] = at
	if delay and delay > 0 then
		task.delay(delay, function() if char.Parent then puff(char) end end)
	else
		puff(char)
	end
end
local function watchBeats(char)
	local mine = char == Players.LocalPlayer.Character
	local function leap(attr)
		local at = char:GetAttribute(attr)
		if typeof(at) ~= "number" then return end
		local w = tonumber(char:GetAttribute("JumpWindup")) or 0.12
		maybePuff(char, at + w, math.max(0, at + w - now()))
	end
	if mine then
		char:GetAttributeChangedSignal("JumpPredictedAt"):Connect(function() leap("JumpPredictedAt") end)
		char:GetAttributeChangedSignal("JumpDoublePredictedAt"):Connect(function() maybePuff(char, char:GetAttribute("JumpDoublePredictedAt")) end)
	end
	char:GetAttributeChangedSignal("JumpStartedAt"):Connect(function() leap("JumpStartedAt") end)
	char:GetAttributeChangedSignal("JumpDoubleAt"):Connect(function() maybePuff(char, char:GetAttribute("JumpDoubleAt")) end)
end

-- troodon characters: pod + zone ------------------------------------------------------------------------------------------------
local function watch(char)
	watchBeats(char) -- v1.1
	char:GetAttributeChangedSignal("TrooPodAt"):Connect(function()
		if script:GetAttribute("TrooFXEnabled") ~= false and char:GetAttribute("Species") == "Troodon" then spawnPod(char) end
	end)
	char:GetAttributeChangedSignal("TrooZoneAt"):Connect(function()
		if script:GetAttribute("TrooFXEnabled") ~= false and char:GetAttribute("Species") == "Troodon" then spawnZone(char) end
	end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(watch)
	if pl.Character then watch(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end

-- lock ring (owner only; DiloFX 1.2's) -------------------------------------------------------------------------------------------
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
local function pickTarget(char)
	local hrp = rootOf(char)
	if not hrp then return nil end
	local fwd = flat(hrp.CFrame.LookVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
	local s = char:GetScale()
	local half = math.rad(math.clamp(num(char, "TrooAssistAngle") or 30, 0, 180))
	local hi = math.max(0, num(char, "TrooAssistMax") or 22.5) * s
	local best, bestD = nil, math.huge
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	for _, b in ipairs(bots()) do table.insert(list, b) end
	for _, m in ipairs(list) do
		if isTarget(m, char) then
			local v = flat(rootOf(m).Position - hrp.Position)
			local d = v.Magnitude
			if d <= hi and d > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= half and d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end
-- v1.2: the closest teammate in front (see the header)
if script:GetAttribute("TrooFXAllyRingEnabled") == nil then script:SetAttribute("TrooFXAllyRingEnabled", true) end
if script:GetAttribute("TrooAllyAngle") == nil then script:SetAttribute("TrooAllyAngle", 45) end
local ALLY_RING = Color3.fromHex("7BE37B")
local function pickAlly(char)
	local hrp = rootOf(char)
	if not hrp then return nil end
	local fwd = flat(hrp.CFrame.LookVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
	local s = char:GetScale()
	local half = math.rad(math.clamp(tonumber(script:GetAttribute("TrooAllyAngle")) or 45, 0, 180))
	local hi = math.max(0, num(char, "TrooPodRange") or 22.5) * s
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	for _, b in ipairs(bots()) do table.insert(list, b) end
	local best, bestD = nil, math.huge
	for _, m in ipairs(list) do
		local r = m ~= char and rootOf(m)
		local hum = m:FindFirstChildOfClass("Humanoid")
		local hp = m:GetAttribute("DummyHealth")
		local live = (not hum or hum.Health > 0) and m:GetAttribute("DummyState") ~= "ko" and (typeof(hp) ~= "number" or hp > 0)
		if r and live and squadmate(char, m) then
			local v = flat(r.Position - hrp.Position)
			local d = v.Magnitude
			if d <= hi and d > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= half and d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end
local ring, ringStroke, ringGui
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
RunService.RenderStepped:Connect(function()
	local char = me.Character
	local want = nil
	if char and on("TrooFXRingEnabled") and char:GetAttribute("Species") == "Troodon" and char:GetAttribute("TrooLocalState") == "throw"
		and (num(char, "TrooPodAt") or 0) < (num(char, "TrooLocalAt") or 0) then
		want = pickTarget(char)
	end
	local allyShown = false -- v1.2
	if want ~= nil or (char and char:GetAttribute("TrooLocalState") == "throw") then
		if char and script:GetAttribute("TrooFXAllyRingEnabled") ~= false and on("TrooFXRingEnabled")
			and char:GetAttribute("TrooLocalState") == "throw" and (num(char, "TrooPodAt") or 0) < (num(char, "TrooLocalAt") or 0)
			and (num(char, "TrooLocalAllyAt") or -math.huge) >= (num(char, "TrooLocalAt") or 0) then
			local a = pickAlly(char)
			if a then want, allyShown = a, true end
		end
	end
	if script:GetAttribute("TrooFXRingAlly") ~= allyShown then script:SetAttribute("TrooFXRingAlly", allyShown) end
	script:SetAttribute("TrooFXRingTarget", want and want.Name or "")
	if not want then
		if ring then ring.Parent = nil end
		return
	end
	if not ring then
		ring, ringStroke, ringGui = ringPart("TrooLockRing", RING, 0.2)
		nParts -= 1 -- the ring is kept, not an effect
	end
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
	ringStroke.Color = allyShown and ALLY_RING or RING -- v1.2
end)
