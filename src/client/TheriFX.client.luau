-- TheriFX v1.0 (Mecha Dino Arena) — the Therizinosaurus' Spin Dive effects on this client (LocalScript, StarterPlayerScripts).
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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
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
local function onPlayer(pl)
	pl.CharacterAdded:Connect(watch)
	if pl.Character then watch(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
