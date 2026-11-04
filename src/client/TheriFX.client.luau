-- TheriFX v1.1 (Mecha Dino Arena) — the Therizinosaurus' Spin Dive effects on this client (LocalScript, StarterPlayerScripts).
-- MDA-214, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 8, mockup docs/mockups/therizino_spin_dive_v0.1.html (Kepu
-- 2026-11-03 "Corkscrew": "Cuts along the whole flight ... The last cut gets a bigger hit flash"; "No landing slam ... it lands
-- claws-down into a skid, dust only"). The combo's effects (MDA-204) are not in this version.
-- Runs for every player character with Species "Therizino" and TheriSpinEnabled (yours and others'). Everything is local
-- (Workspace "TheriFX"), nothing is replicated. Sizes are the mockup's (studs at scale 2) x (character scale / 2).
-- Trails: from TheriSpinStartedAt + JumpWindup (the lift-off) until TheriSpinLandedAt is stamped or LIVE_MAX (1.6 s), a Trail
--   on each of the six claw tips (parts named "*_claw%dd": from the claw's middle to its tip), lifetime TRAIL_LIFE 0.2 s, white
--   at the claw fading to HOT orange (the mockup's hot trail).
-- Cut (each TheriSpinCutAt; point TheriSpinCutPoint): a white flash (size 11; 16 on that target's last allowed cut,
--   TheriSpinMaxCuts), SPARK sparks flung away from the therizino (16; 26 on the last cut, 0.35 s, gravity) and a "-N" pop
--   over the target (N = TheriSpinDamage; "BLOCKED" while its Energy Shield is up).
-- Landing (TheriSpinLandedAt > 0): skid dust for 0.35 s behind the feet (small puffs) and 6 dust balls; no ring, no rocks, no
--   camera shake (TenoFX 1.1 rule, Kepu 2026-10-31: no extra jump dust / seismic effects on any dino's jump).
-- Switches: script attributes TheriFXEnabled (default true, read each event; false = no effects) and TheriFXSpinEnabled
--   (default true, read each event).
-- Diagnostics: script TheriFXVersion, TheriFXEvents (count), TheriFXLast ("dive" / "cut" / "cutBig" / "land"),
--   TheriFXTrails (trails on right now).
-- v1.1 (MDA-204, plan docs/plans/THERIZINO_KIT_v1.0.md Task 7; mockups docs/mockups/therizino_kit_options_v0.3.html (Kepu
--   2026-11-02 "I like this one") and docs/mockups/therizino_fourth_cut_v0.1.html style C "Ground Scythe"): the combo's effects,
--   for every character with Species "Therizino" (yours and others'). Sizes / speeds: the mockups' (studs at scale 2) x k.
--   * Step stamps: your own therizino TheriLocalStep / TheriLocalAt (TheriAttackTest), others TheriComboStep / TheriComboAt
--     (TheriAttackServer; none once TheriComboCancelAt >= TheriComboAt) - the same ones TheriPose plays. Each new (step, at)
--     less than 1.5 s old starts that step's effects; t = server time - at (step 4 x 1.5 faster with TheriFourthFast).
--   * Claw trails (the 1.0 Trails on "*_claw%dd", shared with the Spin Dive): step 1 the right claws (ArmR_*) 0.20-0.40 s,
--     step 2 the left (ArmL_*) 0.17-0.37 s, white, lifetime COMBO_TRAIL_LIFE 0.13; step 3 both 0.45-0.66 s, orange (FFB347 ->
--     FF7A1A); step 4 both 0.14-0.66 s, white, lifetime 0.2. When they turn off the 1.0 spin look (0.2 s, white -> HOT) is put
--     back. The Spin Dive starting turns the combo trails off.
--   * Hit (TheriHitAt, less than 1 s old, TheriHitTargets not empty; at most 5 targets): on each target (its bounding box
--     centre moved toward the therizino by 0.35 x its smaller flat size) a white flash (11 / finisher 18 / Fourth Cut 13),
--     sparks flung away from the therizino (16 / 30 / 20; orange FFB347 on the finisher and the Fourth Cut, else FFF4C8; speed
--     18-44 + random, gravity 60, 0.35-0.65 s), three red (FF2A2A) claw marks facing the camera (width 0.4 / finisher 0.55,
--     length 7 / 9, 1.3 / 1.6 apart, tilted 0.9 rad (step 1), -0.9 (step 2), 0.05 (finisher), 0.5 (Fourth Cut); they grow in
--     over 1/16 of their 0.9 s and fade after 0.1) and a damage number over it ("BLOCKED" while its Energy Shield is up):
--     TheriHitDamage1 / 2 / 3 (9 / 9 / 20; TheriFuryHit2 / TheriFuryFinisher > 0 replace 2 / 3), step 4 TheriFourthDamage -
--     the base number (the server's Fury stack, full-chain multiplier and damage-taken multipliers are not shown); white ->
--     FFD23A, the finisher FFE08A -> FF7A1A and bigger.
--   * Finisher impact (step 3, at + IMPACT_AT 0.55 = the CHOP key, hit or miss; not after a cancel): on the ground 9 x k ahead
--     of the root: rings 24 (FFF0C0, 0.55 s) and 14 (white, 0.35 s), 22 dust balls, 16 bouncing rubble blocks (A99167, 1.4 s),
--     8 cracks of 3 segments (3B2C1C, length 10, grow in fast, fade after 0.6 of 1.8 s).
--   * Fourth Cut (step 4): a ring 20 (FFF0C0, 0.5 s) under it at 0.2 s, and small dust puffs 14 x k around it from 0.16 to
--     0.62 s (no ground impact: style C has none).
--   * Your own therizino only: camera shake (hit 0.8 / finisher 1.7 / Fourth Cut 1.0; impact 1.9) and a field-of-view punch
--     (2.2 / 5 / 2.6 degrees narrower, easing back), the mockups' numbers. The hit-stop itself is TheriPose 1.5's.
--   Switches: script attributes TheriFXComboEnabled (default true, read at each event; false = 1.0) and TheriFXCameraEnabled
--   (default true; false = no shake / FOV punch). TheriFXEnabled false turns these off too.
--   Diagnostics: script TheriFXComboHits (count of hit events with targets), TheriFXComboTrails (therizinos with combo trails
--   on now), TheriFXLive (combo effect objects alive), TheriFXLast "combo1".."combo4" / "hit" / "hitBig" / "hitSweep" /
--   "impact" / "scytheRing".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 combo effects (MDA-204)
local LIVE_MAX = 1.6
local TRAIL_LIFE = 0.2
local DUST, SPARK, HOT = Color3.fromHex("CBB487"), Color3.fromHex("FFF0B0"), Color3.fromHex("FF9A3C")

script:SetAttribute("TheriFXVersion", VERSION)
script:SetAttribute("TheriFXEvents", 0)
script:SetAttribute("TheriFXTrails", 0)
for _, k in ipairs({"TheriFXEnabled", "TheriFXSpinEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on() return script:GetAttribute("TheriFXEnabled") ~= false and script:GetAttribute("TheriFXSpinEnabled") ~= false end
local function note(what)
	script:SetAttribute("TheriFXEvents", (script:GetAttribute("TheriFXEvents") or 0) + 1)
	script:SetAttribute("TheriFXLast", what)
end

local folder = workspace:FindFirstChild("TheriFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TheriFX"
	folder.Parent = workspace
end
local function now() return workspace:GetServerTimeNow() end

-- effect list (TenoFX 1.2's helpers) ------------------------------------------------------------------------------------------
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
		add({kind = "dust", p = p, d = d, life = 0.9 + math.random() * 0.5,
			v = Vector3.new(math.cos(a) * spread * (0.6 + math.random()), up * (0.5 + math.random()), math.sin(a) * spread * (0.6 + math.random())) * k})
	end
end
local function flash(pos, size, k)
	local p = part(Enum.PartType.Ball, Vector3.new(1, 1, 1), Color3.new(1, 1, 1), 0.1, Enum.Material.Neon)
	p.Position = pos
	add({kind = "flash", p = p, size = size * k * 0.5, life = 0.16})
end
local function sparks(pos, dir, n, k)
	for _ = 1, n do
		local s = (0.18 + math.random() * 0.22) * k
		local p = part(Enum.PartType.Block, Vector3.new(s, s, s * 4), math.random() < 0.5 and SPARK or HOT, 0, Enum.Material.Neon)
		p.Position = pos
		local v = (dir + Vector3.new((math.random() - 0.5) * 1.6, math.random() * 0.9, (math.random() - 0.5) * 1.6)).Unit * (24 + math.random() * 22) * k
		add({kind = "spark", p = p, v = v, life = 0.3 + math.random() * 0.15, g = 70 * k})
	end
end
local function pop(model, text, big)
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if not root then return end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 200 or 140, big and 52 or 38)
	bb.StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 3, model:GetExtentsSize().Y * 0.6 + 2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = root
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = big and HOT or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.Parent = bb
	bb.Parent = folder
	add({kind = "pop", bb = bb, l = l, life = 0.9, y0 = bb.StudsOffsetWorldSpace.Y})
end

RunService.Heartbeat:Connect(function(dt)
	for i = #fx, 1, -1 do
		local f = fx[i]
		f.t += dt
		local u = f.t / f.life
		if u >= 1 then
			if f.p then f.p:Destroy() end
			if f.bb then f.bb:Destroy() end
			table.remove(fx, i)
		elseif f.kind == "dust" then
			f.p.Position += f.v * dt
			f.v *= math.max(0, 1 - dt * 2.2)
			local d = f.d * (1 + u * 1.8)
			f.p.Size = Vector3.new(d, d, d)
			f.p.Transparency = 0.15 + 0.85 * u
		elseif f.kind == "flash" then
			local s = f.size * (0.6 + u * 1.2) * 2
			f.p.Size = Vector3.new(s, s, s)
			f.p.Transparency = 0.1 + 0.9 * u
		elseif f.kind == "spark" then
			f.v -= Vector3.new(0, f.g * dt, 0)
			local pos = f.p.Position + f.v * dt
			f.p.CFrame = CFrame.lookAt(pos, pos + f.v)
			f.p.Transparency = u * u
		elseif f.kind == "pop" then
			f.bb.StudsOffsetWorldSpace = Vector3.new(f.bb.StudsOffsetWorldSpace.X, f.y0 + u * 5, 0)
			local tr = u < 0.7 and 0 or (u - 0.7) / 0.3
			f.l.TextTransparency, f.l.TextStrokeTransparency = tr, 0.2 + 0.8 * tr
		end
	end
end)

-- per-therizino --------------------------------------------------------------------------------------------------------------
local function scaleK(char) return char:GetScale() / 2 end
local function findModel(name)
	local pl = Players:FindFirstChild(name)
	if pl and pl:IsA("Player") and pl.Character then return pl.Character end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end
local trailsOn = 0
local function makeTrails(char)
	local list = {}
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.Name:match("_claw%dd$") then
			local a0 = Instance.new("Attachment")
			a0.Name = "TheriFXTip"
			a0.Position = Vector3.new(0, p.Size.Y / 2, 0)
			a0.Parent = p
			local a1 = Instance.new("Attachment")
			a1.Name = "TheriFXMid"
			a1.Position = Vector3.new(0, 0, 0)
			a1.Parent = p
			local tr = Instance.new("Trail")
			tr.Name = "TheriFXTrail"
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Lifetime = TRAIL_LIFE
			tr.FaceCamera = false
			tr.LightEmission = 0.8
			tr.Color = ColorSequence.new(Color3.new(1, 1, 1), HOT)
			tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1)})
			tr.WidthScale = NumberSequence.new(1, 0.3)
			tr.Enabled = false
			tr.Parent = p
			table.insert(list, tr)
		end
	end
	return list
end

local watched = setmetatable({}, {__mode = "k"})
local function watch(char)
	if watched[char] then return end
	watched[char] = true
	local conns = {}
	local function c(sig, fn) table.insert(conns, sig:Connect(fn)) end
	local function isTheri() return char:GetAttribute("Species") == "Therizino" and char:GetAttribute("TheriSpinEnabled") == true end
	local trails, live, diveAt, perTarget = nil, false, nil, {}
	local function setTrails(v)
		if v == live then return end
		live = v
		if v and not trails then trails = makeTrails(char) end
		for _, tr in ipairs(trails or {}) do tr.Enabled = v end
		trailsOn += v and 1 or -1
		script:SetAttribute("TheriFXTrails", trailsOn)
	end
	c(char:GetAttributeChangedSignal("TheriSpinStartedAt"), function()
		if not on() or not isTheri() then return end
		local t0 = tonumber(char:GetAttribute("TheriSpinStartedAt")) or 0
		diveAt, perTarget = t0, {}
		local lift = t0 + math.max(0, tonumber(char:GetAttribute("JumpWindup")) or 0.27)
		note("dive")
		task.delay(math.max(0, lift - now()), function()
			if diveAt ~= t0 then return end
			setTrails(true)
			task.delay(LIVE_MAX, function() if diveAt == t0 then setTrails(false) end end)
		end)
	end)
	c(char:GetAttributeChangedSignal("TheriSpinCutAt"), function()
		if not on() or not isTheri() then return end
		local p = char:GetAttribute("TheriSpinCutPoint")
		if typeof(p) ~= "Vector3" then return end
		local k = scaleK(char)
		local name = char:GetAttribute("TheriSpinCutTarget")
		local n = (perTarget[name or ""] or 0) + 1
		perTarget[name or ""] = n
		local big = n >= math.max(1, math.floor(tonumber(char:GetAttribute("TheriSpinMaxCuts")) or 3))
		local root = char:FindFirstChild("HumanoidRootPart")
		local dir = root and Vector3.new(p.X - root.Position.X, 0, p.Z - root.Position.Z) or Vector3.zero
		dir = dir.Magnitude > 1e-3 and dir.Unit + Vector3.new(0, 0.3, 0) or Vector3.yAxis
		flash(p, big and 16 or 11, k)
		sparks(p, dir, big and 26 or 16, k)
		local m = name and findModel(name)
		if m then
			local blocked = (tonumber(m:GetAttribute("EnergyShieldUntil")) or 0) > now()
			local d = math.floor((tonumber(char:GetAttribute("TheriSpinDamage")) or 7) + 0.5)
			pop(m, blocked and "BLOCKED" or ("-" .. d), big)
		end
		note(big and "cutBig" or "cut")
	end)
	c(char:GetAttributeChangedSignal("TheriSpinLandedAt"), function()
		setTrails(false)
		diveAt = nil
		if not on() or not isTheri() or (tonumber(char:GetAttribute("TheriSpinLandedAt")) or 0) <= 0 then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local k = scaleK(char)
		local back = -Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		back = back.Magnitude > 1e-3 and back.Unit or Vector3.zAxis
		local g = groundAt(root.Position)
		dust(g + back * 3 * k, 6, 9, 3, 1, k)
		local t = 0
		local conn
		conn = RunService.Heartbeat:Connect(function(dt) -- skid: small puffs behind the feet for 0.35 s
			t += dt
			if t > 0.35 or not root.Parent then conn:Disconnect() return end
			if math.random() < dt * 40 then
				local gp = groundAt(root.Position)
				dust(gp + back * 3 * k + Vector3.new((math.random() - 0.5) * 8 * k, 0, (math.random() - 0.5) * 8 * k), 1, 2, 3, 0.8, k)
			end
		end)
		note("land")
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if parent then return end
		if live then trailsOn -= 1 script:SetAttribute("TheriFXTrails", trailsOn) end
		for _, cn in ipairs(conns) do cn:Disconnect() end
	end)
end
-- v1.1: the combo's effects (MDA-204; see the header) ------------------------------------------------------------------------
local LP = Players.LocalPlayer
for _, k in ipairs({"TheriFXComboEnabled", "TheriFXCameraEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
script:SetAttribute("TheriFXComboHits", 0)
script:SetAttribute("TheriFXComboTrails", 0)
script:SetAttribute("TheriFXLive", 0)
local function comboOn() return script:GetAttribute("TheriFXEnabled") ~= false and script:GetAttribute("TheriFXComboEnabled") ~= false end
local function camOn() return comboOn() and script:GetAttribute("TheriFXCameraEnabled") ~= false end
local MARK, CREAM, RUBBLE, CRACK = Color3.fromHex("FF2A2A"), Color3.fromHex("FFF0C0"), Color3.fromHex("A99167"), Color3.fromHex("3B2C1C")
local SPARK_C, SPARK_HOT = Color3.fromHex("FFF4C8"), Color3.fromHex("FFB347")
local TRAIL_HOT_A, TRAIL_HOT_B = Color3.fromHex("FFB347"), Color3.fromHex("FF7A1A")
local COMBO_TRAIL_LIFE, FOURTH_TRAIL_LIFE, IMPACT_AT, MAX_TARGET_FX, RING_SEGS = 0.13, 0.2, 0.55, 5, 24
local WINDOWS = { -- claw trails, s after the step's stamp
	{a = 0.2, b = 0.4, side = "ArmR"},
	{a = 0.17, b = 0.37, side = "ArmL"},
	{a = 0.45, b = 0.66, hot = true},
	{a = 0.14, b = 0.66, life = FOURTH_TRAIL_LIFE},
}
local HIT = {
	{flash = 11, sparks = 16, hot = false, angle = 0.9, big = false, shake = 0.8, fov = 2.2, last = "hit"},
	{flash = 11, sparks = 16, hot = false, angle = -0.9, big = false, shake = 0.8, fov = 2.2, last = "hit"},
	{flash = 18, sparks = 30, hot = true, angle = 0.05, big = true, shake = 1.7, fov = 5, last = "hitBig"},
	{flash = 13, sparks = 20, hot = true, angle = 0.5, big = false, shake = 1.0, fov = 2.6, last = "hitSweep"},
}
local function numA(m, k) local v = m:GetAttribute(k) return typeof(v) == "number" and v == v and v or nil end

-- combo effect list (its own updater; the 1.0 kinds dust / flash / spark / pop still go through add)
local fx2 = {}
local function add2(f) f.t = 0; table.insert(fx2, f); return f end
local function sparksC(pos, dir, n, hot, k)
	for _ = 1, n do
		local sz = (0.16 + math.random() * 0.2) * k
		local p = part(Enum.PartType.Block, Vector3.new(sz, sz, sz * 4), hot and SPARK_HOT or SPARK_C, 0, Enum.Material.Neon)
		p.Position = pos
		local v = (dir * (18 + math.random() * 26) + Vector3.new((math.random() - 0.5) * 26, 8 + math.random() * 18, (math.random() - 0.5) * 26)) * k
		add({kind = "spark", p = p, v = v, life = 0.35 + math.random() * 0.3, g = 60 * k})
	end
end
local function marks(center, off, angle, big, k)
	local w, L, gap = (big and 0.55 or 0.4) * k, (big and 9 or 7) * k, (big and 1.6 or 1.3) * k
	local ps = {}
	for i = 1, 3 do ps[i] = part(Enum.PartType.Block, Vector3.new(w, 0.05, 0.05), MARK, 0, Enum.Material.Neon) end
	add2({kind = "marks", ps = ps, c = center, off = off, angle = angle, w = w, L = L, gap = gap, life = 0.9})
end
local function popC(model, text, big)
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if not root then return end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 200 or 140, big and 56 or 40)
	bb.StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 3, model:GetExtentsSize().Y * 0.6 + 2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = root
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeColor3 = Color3.fromHex("2A1504")
	l.TextStrokeTransparency = 0.1
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = big and ColorSequence.new(Color3.fromHex("FFE08A"), Color3.fromHex("FF7A1A")) or ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("FFD23A"))
	g.Parent = l
	l.Parent = bb
	bb.Parent = folder
	add({kind = "pop", bb = bb, l = l, life = 0.95, y0 = bb.StudsOffsetWorldSpace.Y})
end
local function ringC(pos, r1, color, life, k)
	local segs = {}
	for i = 1, RING_SEGS do segs[i] = part(Enum.PartType.Block, Vector3.new(1, 0.12, 1), color, 0.1, Enum.Material.Neon) end
	add2({kind = "ring", segs = segs, pos = pos + Vector3.new(0, 0.25 * k, 0), r1 = r1, k = k, life = life})
end
local function rubble(pos, n, k)
	for _ = 1, n do
		local sz = (0.5 + math.random() * 1.1) * k
		local p = part(Enum.PartType.Block, Vector3.new(sz, sz, sz), RUBBLE, 0, Enum.Material.Slate)
		local a = math.random() * math.pi * 2
		p.Position = pos + Vector3.new(math.cos(a) * 2 * k, 0.5 * k, math.sin(a) * 2 * k)
		local sp = 8 + math.random() * 14
		add2({kind = "rubble", p = p, sz = sz, floor = pos.Y + sz / 2, g = 55 * k, life = 1.4,
			v = Vector3.new(math.cos(a) * sp, 14 + math.random() * 16, math.sin(a) * sp) * k,
			w = Vector3.new(math.random() * 12, math.random() * 12, math.random() * 12)})
	end
end
local function cracksC(pos, n, len, k)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + math.random() * 0.5
		local L = len * (0.6 + math.random() * 0.6) * k
		local x = pos
		for sgm = 0, 2 do
			local aa = a + (math.random() - 0.5) * 0.7
			local l = L / 3
			local dir = Vector3.new(math.cos(aa), 0, math.sin(aa))
			local mid = groundAt(x + dir * (l / 2))
			local w = (0.5 - sgm * 0.12) * k
			local p = part(Enum.PartType.Block, Vector3.new(w, 0.08, 0.05), CRACK, 0)
			add2({kind = "crack", p = p, c = pos, mid = mid, dir = dir, L = l, w = w, life = 1.8})
			x += dir * l
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	for i = #fx2, 1, -1 do
		local f = fx2[i]
		f.t += dt
		local u = f.t / f.life
		if u >= 1 then
			if f.p then f.p:Destroy() end
			for _, q in ipairs(f.ps or f.segs or {}) do q:Destroy() end
			table.remove(fx2, i)
		elseif f.kind == "marks" then
			local camPos = cam and cam.CFrame.Position or f.c + Vector3.zAxis
			local to = camPos - f.c
			local c = f.c + (to.Magnitude > 1e-3 and to.Unit * math.min(f.off, to.Magnitude * 0.5) or Vector3.zero)
			local cf = CFrame.lookAt(c, camPos)
			local L = f.L * math.min(1, u * 16)
			local tr = u < 0.1 and 0 or (u - 0.1) / 0.9
			for j, q in ipairs(f.ps) do
				q.Size = Vector3.new(f.w, math.max(0.05, L), 0.05)
				q.CFrame = cf * CFrame.new((j - 2) * f.gap, 0, 0) * CFrame.Angles(0, 0, -f.angle)
				q.Transparency = tr
			end
		elseif f.kind == "ring" then
			local r = (1 + (1 - (1 - u) ^ 3) * f.r1) * f.k
			local seg = 2 * math.pi * r / RING_SEGS * 1.05
			for j, q in ipairs(f.segs) do
				local a = (j - 1) / RING_SEGS * 2 * math.pi
				local at = f.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				q.Size = Vector3.new(math.max(0.2, r * 0.15), 0.12, seg)
				q.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(a), 0, math.cos(a)))
				q.Transparency = 0.1 + 0.9 * u
			end
		elseif f.kind == "rubble" then
			f.v -= Vector3.new(0, f.g * dt, 0)
			local p = f.p.Position + f.v * dt
			if p.Y < f.floor then
				p = Vector3.new(p.X, f.floor, p.Z)
				f.v = Vector3.new(f.v.X * 0.6, math.abs(f.v.Y) * 0.35, f.v.Z * 0.6)
				f.w *= 0.6
			end
			f.p.CFrame = CFrame.new(p) * f.p.CFrame.Rotation * CFrame.Angles(f.w.X * dt, f.w.Y * dt, f.w.Z * dt)
			if u > 0.75 then
				local sz = math.max(0.05, f.sz * (1 - u) / 0.25)
				f.p.Size = Vector3.new(sz, sz, sz)
			end
		elseif f.kind == "crack" then
			local g = math.min(1, u * 14)
			local m = f.c + (f.mid - f.c) * g
			m = Vector3.new(m.X, f.mid.Y + 0.06, m.Z)
			f.p.Size = Vector3.new(f.w, 0.08, math.max(0.05, f.L * g))
			f.p.CFrame = CFrame.lookAt(m, m + f.dir)
			f.p.Transparency = u > 0.6 and (u - 0.6) / 0.4 or 0
		end
	end
	if script:GetAttribute("TheriFXLive") ~= #fx2 then script:SetAttribute("TheriFXLive", #fx2) end
end)

-- your own camera: shake + field-of-view punch (TenoFX 1.x's way)
local shakeC, fovKickC, fovBaseC = 0, 0, nil
RunService:BindToRenderStep("TheriFXCamera", Enum.RenderPriority.Camera.Value + 3, function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if shakeC > 0.01 then
		local sv = shakeC * 0.6
		cam.CFrame *= CFrame.new((math.random() - 0.5) * sv, (math.random() - 0.5) * sv, 0)
			* CFrame.Angles((math.random() - 0.5) * sv * 0.02, (math.random() - 0.5) * sv * 0.02, 0)
		shakeC *= math.max(0, 1 - dt * 6)
	else
		shakeC = 0
	end
	if fovBaseC then
		if fovKickC > 0.05 then
			cam.FieldOfView = fovBaseC - fovKickC
			fovKickC *= math.max(0, 1 - dt * 8)
		else
			cam.FieldOfView, fovBaseC, fovKickC = fovBaseC, nil, 0
		end
	end
end)
local function camPunch(amount, fov)
	if not camOn() then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	shakeC = math.max(shakeC, amount)
	if fov and fov > 0 then
		if not fovBaseC then fovBaseC = cam.FieldOfView end
		fovKickC = math.max(fovKickC, fov)
	end
end

local function existingTrails(char)
	local list = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Trail") and d.Name == "TheriFXTrail" then table.insert(list, d) end
	end
	return list
end
do -- the spin and the combo share one set of claw trails
	local makeTrailsV10 = makeTrails
	makeTrails = function(char)
		local list = existingTrails(char)
		if #list > 0 then return list end
		return makeTrailsV10(char)
	end
end
local function hitDamage(char, step)
	if step == 4 then return numA(char, "TheriFourthDamage") or 0 end
	if step == 2 and (numA(char, "TheriFuryHit2") or 0) > 0 then return numA(char, "TheriFuryHit2") end
	if step == 3 and (numA(char, "TheriFuryFinisher") or 0) > 0 then return numA(char, "TheriFuryFinisher") end
	return numA(char, "TheriHitDamage" .. step) or (step == 3 and 20 or 9)
end

local comboOnCount = 0
local comboWatched = setmetatable({}, {__mode = "k"})
local function watchCombo(char)
	if comboWatched[char] then return end
	comboWatched[char] = true
	local conns = {}
	local function c(sig, fn) table.insert(conns, sig:Connect(fn)) end
	local function isTheri() return char:GetAttribute("Species") == "Therizino" end
	local function mine() return LP ~= nil and LP.Character == char end
	local cur, trailsLive = nil, false
	local function setComboTrails(w)
		local list = (w or trailsLive) and makeTrails(char) or {}
		for _, tr in ipairs(list) do
			if w then
				tr.Lifetime = w.life or COMBO_TRAIL_LIFE
				tr.Color = w.hot and ColorSequence.new(TRAIL_HOT_A, TRAIL_HOT_B) or ColorSequence.new(Color3.new(1, 1, 1), SPARK_C)
				tr.Enabled = (w.side == nil or (tr.Parent and tr.Parent.Name:sub(1, 4) == w.side)) and true or false
			else
				tr.Enabled = false
				tr.Lifetime = TRAIL_LIFE -- the 1.0 spin look back
				tr.Color = ColorSequence.new(Color3.new(1, 1, 1), HOT)
			end
		end
		local on2 = w ~= nil
		if on2 ~= trailsLive then
			trailsLive = on2
			comboOnCount += on2 and 1 or -1
			script:SetAttribute("TheriFXComboTrails", comboOnCount)
		end
	end
	local function stamp()
		if mine() then return numA(char, "TheriLocalStep"), numA(char, "TheriLocalAt") end
		local st, at = numA(char, "TheriComboStep"), numA(char, "TheriComboAt")
		local cx = numA(char, "TheriComboCancelAt")
		if cx and at and cx >= at then st = 0 end
		return st, at
	end
	local function onStamp()
		local st, at = stamp()
		st = st and math.floor(st) or 0
		if st < 1 or st > 4 or not at then
			if cur then cur = nil setComboTrails(nil) end
			return
		end
		if cur and cur.step == st and cur.at == at then return end
		if not comboOn() or not isTheri() or now() - at > 1.5 then return end
		local token = {step = st, at = at}
		cur = token
		local mul = (st == 4 and char:GetAttribute("TheriFourthFast") == true) and 1 / 1.5 or 1
		local w = WINDOWS[st]
		local function live() return cur == token and comboOn() and char.Parent ~= nil end
		task.delay(math.max(0, at + w.a * mul - now()), function() if live() then setComboTrails(w) end end)
		task.delay(math.max(0, at + w.b * mul - now()), function() if cur == token then setComboTrails(nil) end end)
		local root = char:FindFirstChild("HumanoidRootPart")
		if st == 3 then
			task.delay(math.max(0, at + IMPACT_AT - now()), function()
				local r = char:FindFirstChild("HumanoidRootPart")
				if not (live() and r) then return end
				local k = scaleK(char)
				local fwd = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
				fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
				local g = groundAt(r.Position + fwd * 9 * k)
				ringC(g, 24, CREAM, 0.55, k)
				ringC(g, 14, Color3.new(1, 1, 1), 0.35, k)
				dust(g, 22, 10, 11, 1.2, k)
				rubble(g, 16, k)
				cracksC(g, 8, 10, k)
				if mine() then camPunch(1.9) end
				note("impact")
			end)
		elseif st == 4 and root then
			task.delay(math.max(0, at + 0.2 * mul - now()), function()
				local r = char:FindFirstChild("HumanoidRootPart")
				if not (live() and r) then return end
				ringC(groundAt(r.Position), 20, CREAM, 0.5, scaleK(char))
				note("scytheRing")
			end)
			task.delay(math.max(0, at + 0.16 * mul - now()), function()
				local t, conn = 0, nil
				local dur = (0.62 - 0.16) * mul
				conn = RunService.Heartbeat:Connect(function(dt)
					t += dt
					local r = char:FindFirstChild("HumanoidRootPart")
					if t > dur or not (live() and r) then conn:Disconnect() return end
					if math.random() < dt * 60 then
						local k = scaleK(char)
						local a = math.random() * math.pi * 2
						dust(groundAt(r.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 14 * k), 1, 2, 3, 0.8, k)
					end
				end)
			end)
		end
		note("combo" .. st)
	end
	local function onHit()
		if not comboOn() or not isTheri() then return end
		local ha = numA(char, "TheriHitAt")
		if not ha or now() - ha > 1 then return end
		local step = math.floor(numA(char, "TheriHitStep") or 0)
		local spec = HIT[step]
		local names = char:GetAttribute("TheriHitTargets")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not (spec and root and typeof(names) == "string" and names ~= "") then return end
		local k = scaleK(char)
		local n = 0
		for name in names:gmatch("[^|]+") do
			if n >= MAX_TARGET_FX then break end
			local m = findModel(name)
			if m and m:IsA("Model") and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart) then
				n += 1
				local cf, size = m:GetBoundingBox()
				local toMe = Vector3.new(root.Position.X - cf.Position.X, 0, root.Position.Z - cf.Position.Z)
				toMe = toMe.Magnitude > 1e-3 and toMe.Unit or Vector3.zero
				local p = cf.Position + toMe * math.min(size.X, size.Z) * 0.35
				local dir = (-toMe + Vector3.new(0, 0.3, 0))
				flash(p, spec.flash, k)
				sparksC(p, dir, spec.sparks, spec.hot, k)
				marks(p, math.max(size.X, size.Z) * 0.3, spec.angle, spec.big, k)
				local blocked = (numA(m, "EnergyShieldUntil") or 0) > now()
				popC(m, blocked and "BLOCKED" or tostring(math.floor(hitDamage(char, step) + 0.5)), spec.big)
			end
		end
		if n == 0 then return end
		script:SetAttribute("TheriFXComboHits", (script:GetAttribute("TheriFXComboHits") or 0) + 1)
		if mine() then camPunch(spec.shake, spec.fov) end
		note(spec.last)
	end
	local function later() task.defer(onStamp) end -- after the writer has set both step and time
	c(char:GetAttributeChangedSignal("TheriLocalStep"), later)
	c(char:GetAttributeChangedSignal("TheriLocalAt"), later)
	c(char:GetAttributeChangedSignal("TheriComboAt"), later)
	c(char:GetAttributeChangedSignal("TheriComboCancelAt"), later)
	c(char:GetAttributeChangedSignal("TheriHitAt"), onHit)
	c(char:GetAttributeChangedSignal("TheriSpinStartedAt"), function()
		if cur then cur = nil end
		if trailsLive then setComboTrails(nil) return end
		for _, tr in ipairs(existingTrails(char)) do -- the 1.0 spin look, whatever happened before
			tr.Lifetime = TRAIL_LIFE
			tr.Color = ColorSequence.new(Color3.new(1, 1, 1), HOT)
		end
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if parent then return end
		if trailsLive then comboOnCount -= 1 script:SetAttribute("TheriFXComboTrails", comboOnCount) end
		for _, cn in ipairs(conns) do cn:Disconnect() end
	end)
end
do
	local watchV10 = watch
	watch = function(char)
		watchV10(char)
		watchCombo(char)
	end
end

local function onPlayer(pl)
	pl.CharacterAdded:Connect(watch)
	if pl.Character then watch(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
