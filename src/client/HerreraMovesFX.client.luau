-- HerreraMovesFX v1.2 (Mecha Dino Arena) — the effects of the Herrera's pass-2 part moves on this client (LocalScript,
-- StarterPlayerScripts). Plan docs/plans/HERRERA_PARTS_v1.0.md Parts 3, 4, 7, 8 and "Pass 2 — build map"; the moves are
-- HerreraMovesServer 1.0, the looks HerreraPartsServer 1.2. Runs for every player character (yours and others') and for
-- Workspace.DinoIsland.Bots. Everything is local (Workspace "HerreraMovesFX"), nothing is replicated.
-- Quill Launcher (character QuillStartedAt): QuillShot quills (steel shaft, hot-orange tip, dark fletching; 1.3 x scale
--   long) leave the spine tubes (HPart_quills pieces "tip", in turn) one every 0.045 s and fly on a slight arc at 90
--   studs/s to the target (QuillTarget, followed while it moves) or QuillAimEnd; each arrival on a target shows a white
--   QuillDamage pop and a spark puff. QuillLandedAt shows the big yellow "N QUILLS × D" pop (N = QuillLanded).
-- Smoke Pods (character SmokeStartedAt): SMOKE_PUFFS (70) round cartoon puffs (Ball parts, white / light grey, radius
--   0.8-2.1 x scale) pop out of the tail vents (HPart_smoke "nozzle", else the root) to random spots inside the cloud
--   (SmokeCenter, SmokeRadiusNow) in 0.35 s, wobble gently, and fade over 0.6 s before SmokeUntil. Your own cloud is drawn
--   see-through (transparency 0.6) so you can see out; others' clouds are thick (0.1). A "POOF!" pop at the start.
-- Strobe Frill (character StrobeAt): the frill LEDs (HPart_strobe "led") strobe white 5 times in 0.35 s, a white flare
--   sphere at the head (0.3 s), 13 light rays across the cone (StrobeAngle, StrobeRange x scale, 0.4 s) and a "FLASH!" pop.
-- Dazed (any model's DazedUntil in the future): 4 yellow stars spin over its head until it ends; DazedAt shows a
--   "DAZED N s" pop.
-- Stun Breaker (character BreakerAt): a "BREAK!" pop, 10 zig-zag electric bolts (cyan / white Neon segments, 0.2 s) from
--   the coil tips (HPart_breaker "tip"), the capacitor band flashes white; while StunBreakImmuneUntil is in the future the
--   dino blinks white (a Highlight, 8 blinks per second).
-- Smoke lost (a bot's SmokeLostAt): a "?" pop over the bot.
-- Switch: script attribute HerreraMovesFXEnabled (default true, read each event; false = no effects).
-- Diagnostics: script HerreraMovesFXVersion, HerreraMovesFXEvents (count).
-- v1.1 (Kepu 2026-10-31: "We need the smoke cloud to be way bigger and thicker"): the smoke look is tunable by script
--   attributes, read at each cloud: HerreraMovesFX_SmokePuffs (count), HerreraMovesFX_SmokePuffScale (puff radius
--   multiplier), HerreraMovesFX_SmokeOwnTransparency (your own cloud), HerreraMovesFX_SmokeOtherTransparency (others'
--   clouds). Defaults = Kepu's pick from Studio captures (docs/reference/herrera/smoke_size_B.jpg, "B · 28 studs, 260
--   puffs"; own view "Half see-through"): 260 puffs, x2.2 puffs, own 0.4, others 0 (solid). 1.0 was 70 / x1 / 0.6 / 0.1.
--   The cloud radius itself is SkillTree 1.41 (28 studs).
-- v1.2 (Kepu 2026-10-31: "For the smoke allow me to see right through it just see the outline of the smoke"; picked
--   "Clear inside, white outline"): your OWN cloud's puffs are drawn at HerreraMovesFX_SmokeOwnOutlineTransparency
--   (default 0.92) inside a Model "OwnSmoke" with a Highlight (fill off, white outline, OutlineTransparency
--   HerreraMovesFX_SmokeOutlineTransparency default 0.15), so you see through it and only its outline shows. Other
--   players' clouds are unchanged (solid). Switch: script attribute HerreraMovesFXSmokeOutlineEnabled (default true, read
--   at each cloud; false = 1.1, own cloud at SmokeOwnTransparency).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.2"
local QUILL_GAP, QUILL_SPEED = 0.045, 90
local SMOKE_PUFFS = 70
local HOT = Color3.fromRGB(255, 98, 18)
local STEEL, DARK = Color3.fromRGB(154, 166, 184), Color3.fromRGB(42, 45, 56)
local WHITE, YELLOW, VOLT = Color3.new(1, 1, 1), Color3.fromRGB(255, 214, 64), Color3.fromRGB(127, 233, 255)
local me = Players.LocalPlayer
script:SetAttribute("HerreraMovesFXVersion", VERSION)
script:SetAttribute("HerreraMovesFXEvents", 0)
if script:GetAttribute("HerreraMovesFXEnabled") == nil then script:SetAttribute("HerreraMovesFXEnabled", true) end
local function on() return script:GetAttribute("HerreraMovesFXEnabled") ~= false end
local function count() script:SetAttribute("HerreraMovesFXEvents", (script:GetAttribute("HerreraMovesFXEvents") or 0) + 1) end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "HerreraMovesFX"
fxFolder.Parent = workspace

-- helpers (HerreraPartsFX 1.0's) ---------------------------------------------------------------------------------------
local function animate(dur, step, done)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - t0) / dur)
		step(u)
		if u >= 1 then
			conn:Disconnect()
			if done then done() end
		end
	end)
end
local function fxPart(size, color, cf, material, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	if shape then p.Shape = shape end
	p.Size, p.Color, p.CFrame = size, color, cf
	p.Material = material or Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = fxFolder
	return p
end
local function pop(text, color, pos, size, dur)
	local holder = fxPart(Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size or 6, (size or 6) / 2)
	gui.AlwaysOnTop, gui.LightInfluence, gui.Adornee = true, 0, holder
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.AnchorPoint, label.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	label.Font, label.TextScaled, label.Text = Enum.Font.FredokaOne, true, text
	label.TextColor3, label.TextStrokeColor3, label.TextStrokeTransparency = color, Color3.fromRGB(40, 20, 6), 0
	label.Parent = gui
	animate(dur or 0.7, function(u)
		local sc = u < 0.12 and (0.5 + 0.8 * u / 0.12) or (u < 0.25 and (1.3 - 0.3 * (u - 0.12) / 0.13) or 1)
		label.Size = UDim2.fromScale(sc, sc)
		holder.CFrame = CFrame.new(pos + Vector3.new(0, 3 * (1 - (1 - u) ^ 2), 0))
		local fade = u > 0.65 and (u - 0.65) / 0.35 or 0
		label.TextTransparency, label.TextStrokeTransparency = fade, fade
	end, function() holder:Destroy() end)
end
local function sparks(pos, color, n)
	local a = fxPart(Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
	a.Transparency = 1
	local att = Instance.new("Attachment")
	att.Parent = a
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = ColorSequence.new(color)
	e.LightEmission, e.Lifetime, e.Speed = 1, NumberRange.new(0.25, 0.45), NumberRange.new(10, 20)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.35, 0)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Parent = att
	e:Emit(n)
	task.delay(0.8, function() a:Destroy() end)
end
local function rootOf(m) return m and m:FindFirstChild("HumanoidRootPart") end
local function headOf(m)
	local h = m:FindFirstChild("Head_cranium", true)
	if h and h:IsA("BasePart") then return h end
	local hb = m:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxSegment") == "Head" then return p end
		end
	end
	return rootOf(m)
end
local function findTarget(name)
	if typeof(name) ~= "string" or name == "" then return nil end
	local p = Players:FindFirstChild(name)
	if p and p:IsA("Player") and p.Character then return p.Character end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end
local function pieces(char, id, role)
	local m = char:FindFirstChild("HPart_" .. id)
	local out = {}
	if not m then return out end
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and (not role or p:GetAttribute("HPartRole") == role) then table.insert(out, p) end
	end
	return out
end
local function headTop(m)
	local h = headOf(m)
	if not h then return nil end
	return h.Position + Vector3.new(0, h.Size.Y / 2 + 1.2 * (m:IsA("Model") and m:GetScale() or 1), 0)
end

-- Quill Launcher ------------------------------------------------------------------------------------------------------
local function quillVolley(char)
	if not on() then return end
	count()
	local n = math.max(1, tonumber(char:GetAttribute("QuillShot")) or 5)
	local dmg = tonumber(char:GetAttribute("QuillDamage")) or 4
	local target = findTarget(char:GetAttribute("QuillTarget"))
	local aimEnd = char:GetAttribute("QuillAimEnd")
	local s = char:GetScale()
	local tips = pieces(char, "quills", "tip")
	for i = 1, n do
		task.delay((i - 1) * QUILL_GAP, function()
			if not char.Parent then return end
			local tip = #tips > 0 and tips[(i - 1) % #tips + 1]
			local from = tip and tip.Parent and tip.Position or (rootOf(char) and rootOf(char).Position + Vector3.new(0, 1.5 * s, 0))
			if not from then return end
			local function goal()
				local r = target and target.Parent and rootOf(target)
				if r then return r.Position + Vector3.new((math.random() - 0.5) * s, (math.random() - 0.2) * s, (math.random() - 0.5) * s) end
				return typeof(aimEnd) == "Vector3" and aimEnd or from
			end
			local g0 = goal()
			local dur = math.max(0.05, (g0 - from).Magnitude / QUILL_SPEED)
			local len = 1.3 * s
			local shaft = fxPart(Vector3.new(0.12 * s, 0.12 * s, len), STEEL, CFrame.new(from), Enum.Material.Metal)
			local tipP = fxPart(Vector3.new(0.18 * s, 0.18 * s, 0.3 * s), HOT, CFrame.new(from))
			local fl = fxPart(Vector3.new(0.3 * s, 0.04 * s, 0.25 * s), DARK, CFrame.new(from), Enum.Material.SmoothPlastic)
			local arc = math.min(4, (g0 - from).Magnitude * 0.08) * (0.6 + math.random() * 0.8)
			local last = from
			animate(dur, function(u)
				local g = goal()
				local p = from:Lerp(g, u) + Vector3.new(0, arc * 4 * u * (1 - u), 0)
				local dir = (p - last).Magnitude > 1e-3 and (p - last).Unit or (g - from).Unit
				local cf = CFrame.lookAt(p, p + dir)
				shaft.CFrame = cf
				tipP.CFrame = cf * CFrame.new(0, 0, -len / 2)
				fl.CFrame = cf * CFrame.new(0, 0, len / 2 - 0.1 * s)
				last = p
			end, function()
				local endPos = shaft.Position
				shaft:Destroy(); tipP:Destroy(); fl:Destroy()
				if target and target.Parent then
					pop(tostring(dmg), WHITE, endPos + Vector3.new(0, 1, 0), 2.6, 0.5)
					sparks(endPos, HOT, 5)
				end
			end)
		end)
	end
end
local function quillTotal(char)
	if not on() then return end
	local landed = tonumber(char:GetAttribute("QuillLanded")) or 0
	if landed <= 0 then return end
	local target = findTarget(char:GetAttribute("QuillTarget"))
	local at = target and headTop(target) or (rootOf(char) and rootOf(char).Position)
	if not at then return end
	local dmg = tonumber(char:GetAttribute("QuillDamage")) or 4
	pop(("%d QUILLS × %s"):format(landed, tostring(dmg)), YELLOW, at + Vector3.new(0, 2, 0), 9, 1.1)
end

-- Smoke Pods ----------------------------------------------------------------------------------------------------------
local function smokeCloud(char)
	if not on() then return end
	count()
	local center, radius, untilT = char:GetAttribute("SmokeCenter"), char:GetAttribute("SmokeRadiusNow"), char:GetAttribute("SmokeUntil")
	if typeof(center) ~= "Vector3" or typeof(radius) ~= "number" or typeof(untilT) ~= "number" then return end
	local s = char:GetScale()
	local mine = me.Character == char
	local nozzles = pieces(char, "smoke", "nozzle")
	local life = math.max(0.5, untilT - workspace:GetServerTimeNow())
	pop("POOF!", WHITE, center + Vector3.new(0, 2 * s, 0), 7)
	local function tun(k, d) local v = script:GetAttribute("HerreraMovesFX_" .. k) return typeof(v) == "number" and v or d end -- v1.1
	local puffs = math.clamp(math.floor(tun("SmokePuffs", 260)), 1, 400)
	local puffScale = math.max(0.1, tun("SmokePuffScale", 2.2))
	local ownT, otherT = math.clamp(tun("SmokeOwnTransparency", 0.4), 0, 1), math.clamp(tun("SmokeOtherTransparency", 0), 0, 1)
	local holder -- v1.2: your own cloud, see-through with a white outline
	if mine and script:GetAttribute("HerreraMovesFXSmokeOutlineEnabled") ~= false then
		ownT = math.clamp(tun("SmokeOwnOutlineTransparency", 0.92), 0, 0.99)
		holder = Instance.new("Model")
		holder.Name = "OwnSmoke"
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = WHITE
		hl.OutlineTransparency = math.clamp(tun("SmokeOutlineTransparency", 0.15), 0, 1)
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = holder
		hl.Parent = holder
		holder.Parent = fxFolder
		task.delay(life + 0.5, function() holder:Destroy() end)
	end
	for i = 1, puffs do
		local nz = #nozzles > 0 and nozzles[(i - 1) % #nozzles + 1]
		local from = nz and nz.Parent and nz.Position or center
		-- a random spot in the sphere, biased toward the ground half
		local dir = Vector3.new(math.random() - 0.5, (math.random() - 0.35) * 0.8, math.random() - 0.5)
		dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.yAxis
		local spot = center + dir * radius * (0.25 + 0.75 * math.sqrt(math.random()))
		local r = (0.8 + math.random() * 1.3) * s * puffScale -- v1.1: x puffScale
		local grey = 0.86 + math.random() * 0.14
		local puff = fxPart(Vector3.one * 0.2, Color3.new(grey, grey, grey), CFrame.new(from), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		if holder then puff.Parent = holder end -- v1.2
		local baseT = mine and ownT or otherT -- v1.1 (1.0: 0.6 / 0.1)
		puff.Transparency = baseT
		local wob = math.random() * math.pi * 2
		local delayIn = (i / puffs) * 0.15
		task.delay(delayIn, function()
			local total = math.max(0.4, life - delayIn)
			animate(total, function(u)
				local t = u * total
				local k = math.min(1, t / 0.35)
				local e = 1 - (1 - k) ^ 3
				local over = k >= 1 and 1 + 0.12 * math.sin(math.pi * math.min(1, (t - 0.35) / 0.2)) or 1
				local w = math.sin(t * 2.2 + wob) * 0.25 * s
				puff.Size = Vector3.one * (2 * r * e * over)
				puff.CFrame = CFrame.new(from:Lerp(spot, e) + Vector3.new(w, w * 0.5, -w))
				local left = total - t
				puff.Transparency = left < 0.6 and baseT + (1 - baseT) * (1 - left / 0.6) or baseT
			end, function() puff:Destroy() end)
		end)
	end
end

-- Strobe Frill --------------------------------------------------------------------------------------------------------
local function strobeFlash(char)
	if not on() then return end
	count()
	local s = char:GetScale()
	local leds = pieces(char, "strobe", "led")
	local blinks = 0
	animate(0.35, function(u)
		local b = math.floor(u * 10)
		if b ~= blinks then
			blinks = b
			local white = b % 2 == 0
			for _, p in ipairs(leds) do
				if p.Parent then p.Color = white and WHITE or (p:GetAttribute("HPartBaseColor") or p.Color) end
			end
		end
	end, function()
		for _, p in ipairs(leds) do if p.Parent then p.Color = p:GetAttribute("HPartBaseColor") or p.Color end end
	end)
	local head = headOf(char)
	local root = rootOf(char)
	if not (head and root) then return end
	local hp = head.Position
	local flare = fxPart(Vector3.one * 0.5, WHITE, CFrame.new(hp), Enum.Material.Neon, Enum.PartType.Ball)
	animate(0.3, function(u)
		flare.Size = Vector3.one * (0.5 + 5.5 * s * math.sin(math.pi * math.min(1, u * 1.2)) + 0.01)
		flare.Transparency = u
	end, function() flare:Destroy() end)
	local range = (tonumber(char:GetAttribute("StrobeRange")) or 20) * s
	local half = math.rad((tonumber(char:GetAttribute("StrobeAngle")) or 60) / 2)
	local look = root.CFrame.LookVector
	local face = Vector3.new(look.X, 0, look.Z)
	face = face.Magnitude > 1e-3 and face.Unit or Vector3.zAxis
	for i = 0, 12 do
		local a = -half + 2 * half * i / 12
		local d = CFrame.fromAxisAngle(Vector3.yAxis, a):VectorToWorldSpace(face)
		local len = range * (0.75 + 0.25 * math.random())
		local ray = fxPart(Vector3.new(0.15 * s, 0.15 * s, 0.1), Color3.fromRGB(255, 244, 200), CFrame.new(hp), Enum.Material.Neon)
		animate(0.4, function(u)
			local l = len * math.min(1, u * 3)
			ray.Size = Vector3.new(0.18 * s * (1 - u * 0.6), 0.18 * s * (1 - u * 0.6), math.max(0.1, l))
			ray.CFrame = CFrame.lookAt(hp, hp + d) * CFrame.new(0, 0, -l / 2)
			ray.Transparency = u * u
		end, function() ray:Destroy() end)
	end
	pop("FLASH!", WHITE, hp + Vector3.new(0, 2.5 * s, 0), 7)
end

-- Dazed stars ---------------------------------------------------------------------------------------------------------
local stars = {} -- [model] = {parts}
local function clearStars(m)
	for _, p in ipairs(stars[m] or {}) do p:Destroy() end
	stars[m] = nil
end
local function starPart()
	local p = fxPart(Vector3.new(0.5, 0.5, 0.15), YELLOW, CFrame.new(), Enum.Material.Neon)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.AlwaysOnTop, gui.LightInfluence, gui.Adornee = UDim2.fromScale(1.2, 1.2), false, 0, p
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.Size = 1, UDim2.fromScale(1, 1)
	l.Font, l.TextScaled, l.Text = Enum.Font.FredokaOne, true, "★"
	l.TextColor3, l.TextStrokeColor3, l.TextStrokeTransparency = YELLOW, Color3.fromRGB(90, 60, 0), 0
	l.Parent = gui
	gui.Parent = p
	p.Transparency = 1
	return p
end

-- Stun Breaker --------------------------------------------------------------------------------------------------------
local function bolt(from, dir, len, s)
	local pts = {from}
	local n = 5
	local side = dir:Cross(Vector3.yAxis)
	side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
	local up = side:Cross(dir).Unit
	for i = 1, n do
		local p = from + dir * len * i / n
		if i < n then p += side * (math.random() - 0.5) * 0.9 * s + up * (math.random() - 0.5) * 0.9 * s end
		table.insert(pts, p)
	end
	local segs = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local seg = fxPart(Vector3.new(0.12 * s, 0.12 * s, (b - a).Magnitude), i % 2 == 0 and WHITE or VOLT,
			CFrame.lookAt((a + b) / 2, b), Enum.Material.Neon)
		table.insert(segs, seg)
	end
	animate(0.2, function(u) for _, sg in ipairs(segs) do sg.Transparency = u * u end end, function()
		for _, sg in ipairs(segs) do sg:Destroy() end
	end)
end
local function breakerFX(char)
	if not on() then return end
	count()
	local s = char:GetScale()
	local tips = pieces(char, "breaker", "tip")
	local root = rootOf(char)
	if not root then return end
	for i = 1, 10 do
		local tip = #tips > 0 and tips[(i - 1) % #tips + 1]
		local from = tip and tip.Parent and tip.Position or root.Position + Vector3.new(0, 2 * s, 0)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)
		dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.yAxis
		bolt(from, dir, (3 + math.random() * 3) * s, s)
	end
	for _, p in ipairs(pieces(char, "breaker", "band")) do
		p.Color = WHITE
		task.delay(0.25, function() if p.Parent then p.Color = p:GetAttribute("HPartBaseColor") or VOLT end end)
	end
	pop("BREAK!", VOLT, root.Position + Vector3.new(0, 4 * s, 0), 8)
	local immU = tonumber(char:GetAttribute("StunBreakImmuneUntil")) or 0
	if immU > workspace:GetServerTimeNow() then
		local hl = Instance.new("Highlight")
		hl.FillColor, hl.OutlineColor, hl.FillTransparency, hl.OutlineTransparency = WHITE, WHITE, 0.3, 0
		hl.Adornee = char
		hl.Parent = fxFolder
		local dur = immU - workspace:GetServerTimeNow()
		animate(dur, function(u)
			hl.Enabled = math.floor(u * dur * 16) % 2 == 0
		end, function() hl:Destroy() end)
	end
end

-- watchers ------------------------------------------------------------------------------------------------------------
local watched = setmetatable({}, {__mode = "k"})
local function watch(char)
	if watched[char] then return end
	watched[char] = true
	char:GetAttributeChangedSignal("QuillStartedAt"):Connect(function() quillVolley(char) end)
	char:GetAttributeChangedSignal("QuillLandedAt"):Connect(function() quillTotal(char) end)
	char:GetAttributeChangedSignal("SmokeStartedAt"):Connect(function() smokeCloud(char) end)
	char:GetAttributeChangedSignal("StrobeAt"):Connect(function() strobeFlash(char) end)
	char:GetAttributeChangedSignal("BreakerAt"):Connect(function() breakerFX(char) end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

local seen = setmetatable({}, {__mode = "k"}) -- [model] = {dazedAt, lostAt}
local function models()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	if bots then for _, b in ipairs(bots:GetChildren()) do table.insert(list, b) end end
	return list
end
RunService.Heartbeat:Connect(function()
	local t = workspace:GetServerTimeNow()
	local live = {}
	for _, m in ipairs(models()) do
		live[m] = true
		local sn = seen[m]
		if not sn then
			sn = {dazedAt = m:GetAttribute("DazedAt"), lostAt = m:GetAttribute("SmokeLostAt")}
			seen[m] = sn
		end
		local dz, lost = m:GetAttribute("DazedAt"), m:GetAttribute("SmokeLostAt")
		if dz ~= sn.dazedAt then
			sn.dazedAt = dz
			local top = headTop(m)
			local u = tonumber(m:GetAttribute("DazedUntil")) or 0
			if on() and top and u > t then
				count()
				pop(("DAZED %.1f s"):format(u - t), YELLOW, top + Vector3.new(0, 1.5, 0), 6)
			end
		end
		if lost ~= sn.lostAt then
			sn.lostAt = lost
			local top = headTop(m)
			if on() and top then
				count()
				pop("?", WHITE, top + Vector3.new(0, 1, 0), 4, 1)
			end
		end
		-- the spinning stars
		local dazedNow = on() and (tonumber(m:GetAttribute("DazedUntil")) or 0) > t
		if dazedNow then
			local top = headTop(m)
			if top then
				local list = stars[m]
				if not list then
					list = {}
					for i = 1, 4 do list[i] = starPart() end
					stars[m] = list
				end
				local s = m:IsA("Model") and m:GetScale() or 1
				for i, p in ipairs(list) do
					local a = os.clock() * 5 + i * math.pi / 2
					p.CFrame = CFrame.new(top + Vector3.new(math.cos(a) * 1.1 * s, 0.2 * math.sin(a * 2) * s, math.sin(a) * 1.1 * s))
				end
			end
		elseif stars[m] then
			clearStars(m)
		end
	end
	for m in pairs(stars) do if not live[m] then clearStars(m) end end
end)
