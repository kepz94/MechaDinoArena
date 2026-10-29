-- ScentFX v1.0 (Mecha Dino Arena) — draws Scent Sense on this client only (LocalScript, StarterPlayerScripts).
-- MDA-72, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 4, mockup docs/mockups/raptor_parts_b2_scent_screech.html
-- (Kepu 2026-10-29: A "Glowing paw prints"; cloaked raptors leave faint prints).
-- History: every SAMPLE_EVERY (0.25) s, for every other player's character and every bot under DinoIsland.Bots, the
--   ground point under its HumanoidRootPart (ray down, characters and prints excluded) is kept with the time, the
--   travel direction, whether it was cloaked (CloakedUntil > now) and whether it was bleeding (SkillBleedUntil > now).
--   A new point is kept only after PRINT_SPACING (6) studs of travel; points older than KEEP (10.8) s are dropped.
-- Pulse: when your own ScentStartedAt changes (ScentServer 1.0 accepted a sniff), every kept point not older than your
--   ScentMemory and within ScentRadius of you becomes a paw print for ScentTime s (then all are removed):
--   * print = a flat pad + 3 toes pointing the way the dino went, Neon, no collide / query / touch, anchored, in a
--     client-only Model "ScentTrails" under workspace; sized by species (T-Rex x1.6).
--   * colour by species: raptor orange (255, 155, 46), T-Rex red (240, 90, 79), any other dino violet.
--   * each print sits in a band Model with its own Highlight (DepthMode AlwaysOnTop, so prints show through tall grass):
--     the newest half of a trail "fresh" (FillTransparency 0.15), the older half "old" (0.6), cloaked points "faint"
--     (0.85); bands are per colour, made on demand (at most 9 + blood + ring, far under the Highlight limit).
--   * ScentFresh (III): a ring at the newest point of each trail pulses in size for the whole pulse.
--   * Cap: MAX_PRINTS (300) prints per pulse, newest first.
-- Blood (ScentBlood, star): while you have ScentBlood, every BLOOD_EVERY (0.5) s the prints of each dino that is
--   bleeding right now (its points kept while bleeding, within ScentRadius) are redrawn red in "ScentBlood" (no pulse
--   needed); removed when the bleed or the star ends.
-- Toggle: script attribute ScentFXEnabled (default true; false = nothing drawn, all prints removed).
-- Diagnostics (local character attributes): ScentFXVersion, ScentFXState ("idle" / "showing"), ScentFXPrints (prints of
--   the last pulse), ScentFXTracked (dinos with history), ScentFXBloodPrints, ScentFXPulses.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
local SAMPLE_EVERY, PRINT_SPACING, KEEP, MAX_PRINTS, BLOOD_EVERY = 0.25, 6, 10.8, 300, 0.5
local RAPTOR, TREX, OTHER, BLOOD = Color3.fromRGB(255, 155, 46), Color3.fromRGB(240, 90, 79), Color3.fromRGB(201, 162, 255),
	Color3.fromRGB(255, 40, 40)
local BAND_FILL = {fresh = 0.15, old = 0.6, faint = 0.85}

if script:GetAttribute("ScentFXEnabled") == nil then script:SetAttribute("ScentFXEnabled", true) end
local function on() return script:GetAttribute("ScentFXEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local player = Players.LocalPlayer
local hist = {} -- [model] = {points = {{p, t, dir, cloak, bleed}}, kind}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local trails, bloodModel -- client-only Models
local pulseToken

local function myChar() return player.Character end
local function setDiag(name, value)
	local c = myChar()
	if c then c:SetAttribute(name, value) end
end

local function kindOf(model)
	local pl = Players:GetPlayerFromCharacter(model)
	local sp = pl and pl:GetAttribute("DinoSpecies") or model.Name
	sp = tostring(sp)
	if sp:find("TRex") or sp:find("T%-Rex") then return "trex" end
	if sp:find("Raptor") then return "raptor" end
	return "other"
end
local function colorOf(kind) return kind == "trex" and TREX or kind == "raptor" and RAPTOR or OTHER end

-- the dinos to track: other players' characters and the island's bots
local function tracked()
	local out = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl.Character then table.insert(out, pl.Character) end
	end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") then table.insert(out, m) end
		end
	end
	return out
end

local function groundUnder(model, root)
	local ex = {model}
	if trails then table.insert(ex, trails) end
	if bloodModel then table.insert(ex, bloodModel) end
	local c = myChar()
	if c then table.insert(ex, c) end
	rayParams.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), rayParams)
	return hit and hit.Position or (root.Position - Vector3.new(0, model:GetExtentsSize().Y / 2, 0))
end

local function sample()
	local t = now()
	local seen = {}
	for _, m in ipairs(tracked()) do
		local root = m:FindFirstChild("HumanoidRootPart")
		if root then
			seen[m] = true
			local h = hist[m]
			if not h then
				h = {points = {}, kind = kindOf(m)}
				hist[m] = h
			end
			local pts = h.points
			local last = pts[#pts]
			local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
			if not last or (Vector3.new(last.p.X, 0, last.p.Z) - flat).Magnitude >= PRINT_SPACING then
				local dir = last and (flat - Vector3.new(last.p.X, 0, last.p.Z)) or root.CFrame.LookVector * Vector3.new(1, 0, 1)
				if dir.Magnitude < 1e-3 then dir = Vector3.new(0, 0, -1) end
				local cloak = (tonumber(m:GetAttribute("CloakedUntil")) or 0) > t
				local bleed = (tonumber(m:GetAttribute("SkillBleedUntil")) or 0) > t
				table.insert(pts, {p = groundUnder(m, root), t = t, dir = dir.Unit, cloak = cloak, bleed = bleed})
			end
			while pts[1] and t - pts[1].t > KEEP do table.remove(pts, 1) end
		end
	end
	for m in pairs(hist) do
		if not seen[m] then hist[m] = nil end
	end
	local n = 0
	for _ in pairs(hist) do n += 1 end
	setDiag("ScentFXTracked", n)
end

local function band(root, name, color, fill)
	local m = root:FindFirstChild(name)
	if m then return m end
	m = Instance.new("Model")
	m.Name = name
	local hl = Instance.new("Highlight")
	hl.FillColor, hl.OutlineColor = color, color
	hl.FillTransparency, hl.OutlineTransparency = fill, 1
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = m
	m.Parent = root
	return m
end

local function piece(parent, size, cf, color)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- one paw print: pad + 3 toes pointing along dir
local function print1(parent, pt, kind, color)
	local s = kind == "trex" and 1.6 or 1
	local look = Vector3.new(pt.dir.X, 0, pt.dir.Z)
	local cf = CFrame.lookAt(pt.p + Vector3.new(0, 0.12, 0), pt.p + Vector3.new(0, 0.12, 0) + look)
	piece(parent, Vector3.new(1.3 * s, 0.12, 1.1 * s), cf, color)
	for k = -1, 1 do
		local toe = cf * CFrame.new(k * 0.55 * s, 0, -(1.0 + (k == 0 and 0.25 or 0)) * s) * CFrame.Angles(0, -k * 0.35, 0)
		piece(parent, Vector3.new(0.32 * s, 0.12, 0.8 * s), toe, color)
	end
end

local function clearTrails()
	if trails then trails:Destroy() end
	trails = nil
	setDiag("ScentFXState", "idle")
end

local function pulse()
	local c = myChar()
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (on() and root) then return end
	clearTrails()
	local token = {}
	pulseToken = token
	local t = now()
	local radius = tonumber(c:GetAttribute("ScentRadius")) or 60
	local memory = tonumber(c:GetAttribute("ScentMemory")) or 8
	local dur = math.max(0.1, tonumber(c:GetAttribute("ScentTime")) or 6)
	local fresh = c:GetAttribute("ScentFresh") == true
	trails = Instance.new("Model")
	trails.Name = "ScentTrails"
	-- collect the points, newest first, then draw up to MAX_PRINTS
	local list = {}
	for m, h in pairs(hist) do
		local pts = h.points
		local kept = {}
		for i = #pts, 1, -1 do
			local pt = pts[i]
			if t - pt.t <= memory and (pt.p - root.Position).Magnitude <= radius then table.insert(kept, pt) end
		end
		for i, pt in ipairs(kept) do
			table.insert(list, {pt = pt, kind = h.kind, rank = i, count = #kept, m = m})
		end
	end
	table.sort(list, function(a, b) return a.pt.t > b.pt.t end)
	local drawn = 0
	local newest = {}
	for _, e in ipairs(list) do
		if drawn >= MAX_PRINTS then break end
		local color = colorOf(e.kind)
		local bandName = e.pt.cloak and "faint" or (e.rank <= math.ceil(e.count / 2) and "fresh" or "old")
		local b = band(trails, e.kind .. "_" .. bandName, color, BAND_FILL[bandName])
		print1(b, e.pt, e.kind, color)
		drawn += 1
		if e.rank == 1 then newest[e.m] = e end
	end
	if fresh then -- III: a pulsing ring at each trail's newest point
		local rb = band(trails, "ring", Color3.new(1, 1, 1), 0.3)
		for _, e in pairs(newest) do
			local ring = piece(rb, Vector3.new(0.15, 4, 4), CFrame.new(e.pt.p + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				colorOf(e.kind))
			ring.Shape = Enum.PartType.Cylinder
			ring.Transparency = 0.4
			TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Size = Vector3.new(0.15, 7, 7)}):Play()
		end
	end
	trails.Parent = workspace
	setDiag("ScentFXPrints", drawn)
	setDiag("ScentFXState", "showing")
	setDiag("ScentFXPulses", (c:GetAttribute("ScentFXPulses") or 0) + 1)
	task.delay(dur, function()
		if pulseToken == token then clearTrails() end
	end)
end

-- star: live blood trails (rebuilt only when the set of blood points changes)
local bloodSig = ""
local function blood()
	local c = myChar()
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (on() and root and c:GetAttribute("ScentBlood") == true) then
		if bloodModel then bloodModel:Destroy() bloodModel = nil end
		bloodSig = ""
		setDiag("ScentFXBloodPrints", 0)
		return
	end
	local t = now()
	local radius = tonumber(c:GetAttribute("ScentRadius")) or 81
	local sig = {}
	for m, h in pairs(hist) do
		if (tonumber(m:GetAttribute("SkillBleedUntil")) or 0) > t then
			local last = h.points[#h.points]
			table.insert(sig, m.Name .. ":" .. #h.points .. ":" .. (last and math.floor(last.t * 4) or 0))
		end
	end
	table.sort(sig)
	local s = table.concat(sig, "|") .. "@" .. math.floor(root.Position.X / 10) .. "," .. math.floor(root.Position.Z / 10)
	if s == bloodSig then return end
	bloodSig = s
	if bloodModel then bloodModel:Destroy() bloodModel = nil end
	local n = 0
	for m, h in pairs(hist) do
		if (tonumber(m:GetAttribute("SkillBleedUntil")) or 0) > t then
			for i = #h.points, 1, -1 do
				local pt = h.points[i]
				if n >= MAX_PRINTS then break end
				if pt.bleed and (pt.p - root.Position).Magnitude <= radius then
					if not bloodModel then
						bloodModel = Instance.new("Model")
						bloodModel.Name = "ScentBlood"
					end
					print1(band(bloodModel, "blood", BLOOD, 0.1), pt, h.kind, BLOOD)
					n += 1
				end
			end
		end
	end
	if bloodModel then bloodModel.Parent = workspace end
	setDiag("ScentFXBloodPrints", n)
end

local watched
local function watch(c)
	if watched == c then return end
	watched = c
	c:SetAttribute("ScentFXVersion", VERSION)
	c:SetAttribute("ScentFXState", "idle")
	c:GetAttributeChangedSignal("ScentStartedAt"):Connect(pulse)
	c:GetAttributeChangedSignal("ScentEnabled"):Connect(function()
		if c:GetAttribute("ScentEnabled") ~= true then pulseToken = nil clearTrails() end
	end)
end
if player.Character then watch(player.Character) end
player.CharacterAdded:Connect(function(c)
	pulseToken = nil
	clearTrails()
	watch(c)
end)

script:GetAttributeChangedSignal("ScentFXEnabled"):Connect(function()
	if not on() then
		pulseToken = nil
		clearTrails()
		if bloodModel then bloodModel:Destroy() bloodModel = nil end
	end
end)

local acc, bacc = 0, 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	bacc += dt
	if acc >= SAMPLE_EVERY then
		acc = 0
		if on() then sample() end
	end
	if bacc >= BLOOD_EVERY then
		bacc = 0
		blood()
	end
end)
