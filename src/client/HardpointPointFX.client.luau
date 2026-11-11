-- HardpointPointFX v1.0 (Mecha Dino Arena) — the Hardpoint point in the world: look C "Mecha pylons" (LocalScript,
-- StarterPlayerScripts). MDA-401, plan docs/plans/HARDPOINT_v1.0.md Task 6, mockup docs/mockups/hardpoint_point_look_v0.1.html
-- (Kepu 2026-11-10: "I like it let's do the pylons"; Call of Duty's animated border + marker as the inspiration).
-- Drawn on each client so the colours follow the viewer: own team blue rgb(90,160,255), enemy red rgb(224,40,74), nobody white,
--   contested yellow rgb(255,200,50) blinking with white at 4 Hz; the NEXT point in its last 10 s (and point 1 in the warmup)
--   LOCKED: grey rgb(184,190,200), every 3rd border block hidden, beams off, lamps dim.
-- Reads ReplicatedStorage.Hardpoint (HardpointServer 1.0): HpLive, HpPhase, HpIndex, HpNextIndex, HpShowNext, HpOcc, HpPoints;
--   own team = player attribute HardpointTeam. Hidden while HpLive is not true, in the results phase, or while InMenu.
-- One point (RADIUS from HardpointShared.HardpointRules, 45): 10 pylons on the circle, each standing on the ground under it
--   (DinoIsland.Ground / MountainSteps): base 4.4 x 1.2 x 4.4 dark rgb(35,42,51), column 3 x 7.5 x 3 metal rgb(58,66,80), hazard
--   band 3.3 x 1.1 x 3.3 (yellow rgb(242,194,48) with two black 0.22-stud stripes, no texture), cap 3.6 x 1
--   x 3.6 dark, lamp 2.2 x 1.6 x 2.2 Neon in the state colour; two Neon beams between neighbours, 8.4 and 3.2 studs above the
--   ground (0.45 x 0.45; top transparency 0.15, low 0.45, flicker); BORDER Neon blocks 2.6 x 0.7 x ~3.4 on the ground round the
--   circle with a brightness wave running round (sin(9a - 5t)).
-- Every part anchored, CanCollide / CanQuery / CanTouch false, CastShadow false, in Workspace.HardpointFX (this client only).
-- Built for the current point; the next point is built LOCKED for its last NEXT_SHOWN s. Colours refresh at 20 Hz.
-- Switches (script attributes): HardpointPointFXEnabled (default true), HardpointPointFX_detail (2 full; 1 = 36 border blocks
--   and the low beam off). Diagnostics: HardpointPointFXVersion, HardpointPointFXParts (parts alive).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.0"
script:SetAttribute("HardpointPointFXVersion", VERSION)
if script:GetAttribute("HardpointPointFXEnabled") == nil then script:SetAttribute("HardpointPointFXEnabled", true) end
if script:GetAttribute("HardpointPointFX_detail") == nil then script:SetAttribute("HardpointPointFX_detail", 2) end

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("Hardpoint", 60)
if not state then return end
local shared = ReplicatedStorage:WaitForChild("HardpointShared", 30)
local H = shared and require(shared:WaitForChild("HardpointRules"))
local RADIUS = H and H.RADIUS or 45
local NEXT_SHOWN = H and H.NEXT_SHOWN or 10

local C_YOU, C_FOE, C_OPEN = Color3.fromRGB(90, 160, 255), Color3.fromRGB(224, 40, 74), Color3.fromRGB(255, 255, 255)
local C_CONT, C_LOCK = Color3.fromRGB(255, 200, 50), Color3.fromRGB(184, 190, 200)
local DARK, METAL, HAZ_Y, HAZ_K = Color3.fromRGB(35, 42, 51), Color3.fromRGB(58, 66, 80), Color3.fromRGB(242, 194, 48), Color3.fromRGB(27, 27, 27)
local PYLONS = 10

local folder
local function holder()
	if folder and folder.Parent then return folder end
	folder = workspace:FindFirstChild("HardpointFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "HardpointFX"
		folder.Parent = workspace
	end
	return folder
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
local function groundY(x, z, fallback)
	local island = workspace:FindFirstChild("DinoIsland")
	if not island then return fallback end
	local list = {}
	for _, n in ipairs({"Ground", "MountainSteps"}) do
		local f = island:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	rp.FilterDescendantsInstances = list
	local hit = workspace:Raycast(Vector3.new(x, fallback + 120, z), Vector3.new(0, -400, 0), rp)
	return hit and hit.Position.Y or fallback
end

local partsAlive = 0
local function newPart(parent, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	partsAlive += 1
	return p
end

-- builds one point; returns a handle {model, lamps, beams, border}
local function build(centre, tag)
	local detail = tonumber(script:GetAttribute("HardpointPointFX_detail")) or 2
	local m = Instance.new("Model")
	m.Name = "HardpointPoint_" .. tag
	local h = {model = m, lamps = {}, beams = {}, border = {}, count = 0}
	local tops, lows = {}, {}
	for i = 0, PYLONS - 1 do
		local a = i / PYLONS * 2 * math.pi
		local x, z = centre.X + math.cos(a) * RADIUS, centre.Z + math.sin(a) * RADIUS
		local y = groundY(x, z, centre.Y)
		local base = CFrame.new(x, y, z) * CFrame.Angles(0, -a, 0)
		newPart(m, Vector3.new(4.4, 1.2, 4.4), base * CFrame.new(0, 0.6, 0), DARK)
		newPart(m, Vector3.new(3, 7.5, 3), base * CFrame.new(0, 4.9, 0), METAL, Enum.Material.Metal)
		-- hazard band: yellow with two black stripes (no texture)
		newPart(m, Vector3.new(3.3, 1.1, 3.3), base * CFrame.new(0, 3.2, 0), HAZ_Y)
		newPart(m, Vector3.new(3.34, 0.22, 3.34), base * CFrame.new(0, 2.95, 0), HAZ_K)
		newPart(m, Vector3.new(3.34, 0.22, 3.34), base * CFrame.new(0, 3.45, 0), HAZ_K)
		newPart(m, Vector3.new(3.6, 1, 3.6), base * CFrame.new(0, 9.1, 0), DARK)
		table.insert(h.lamps, newPart(m, Vector3.new(2.2, 1.6, 2.2), base * CFrame.new(0, 10.4, 0), C_OPEN, Enum.Material.Neon))
		tops[i + 1] = Vector3.new(x, y + 8.4, z)
		lows[i + 1] = Vector3.new(x, y + 3.2, z)
	end
	for i = 1, PYLONS do
		local j = i % PYLONS + 1
		for _, lvl in ipairs(detail >= 2 and {"top", "low"} or {"top"}) do
			local p, q = (lvl == "top" and tops or lows)[i], (lvl == "top" and tops or lows)[j]
			local b = newPart(m, Vector3.new(0.45, 0.45, (q - p).Magnitude), CFrame.lookAt((p + q) / 2, q), C_OPEN, Enum.Material.Neon,
				lvl == "top" and 0.15 or 0.45)
			table.insert(h.beams, {part = b, base = lvl == "top" and 0.15 or 0.45, ph = i * 1.7})
		end
	end
	local nb = detail >= 2 and 72 or 36
	local len = 2 * math.pi * RADIUS / nb * 0.86
	for i = 0, nb - 1 do
		local a = (i + 0.5) / nb * 2 * math.pi
		local x, z = centre.X + math.cos(a) * RADIUS, centre.Z + math.sin(a) * RADIUS
		local y = groundY(x, z, centre.Y)
		local b = newPart(m, Vector3.new(2.6, 0.7, len), CFrame.new(x, y + 0.35, z) * CFrame.Angles(0, -a, 0), C_OPEN, Enum.Material.Neon)
		table.insert(h.border, {part = b, a = a, i = i})
	end
	m.Parent = holder()
	return h
end

local function destroy(h)
	if h and h.model then
		for _, d in ipairs(h.model:GetDescendants()) do if d:IsA("BasePart") then partsAlive -= 1 end end
		h.model:Destroy()
	end
end

local points = {}
local function readPoints()
	local ok, list = pcall(function() return HttpService:JSONDecode(state:GetAttribute("HpPoints") or "[]") end)
	points = {}
	if ok and type(list) == "table" then
		for i, p in ipairs(list) do points[i] = Vector3.new(p.x, p.y, p.z) end
	end
end
readPoints()
state:GetAttributeChangedSignal("HpPoints"):Connect(readPoints)

local cur, curIdx, nxt, nxtIdx
local function clearAll()
	destroy(cur); destroy(nxt)
	cur, curIdx, nxt, nxtIdx = nil, nil, nil, nil
end

local function colourFor(occ, t)
	local mine = player:GetAttribute("HardpointTeam")
	if occ == "C" then return (math.floor(t * 4) % 2 == 0) and C_CONT or C_OPEN end
	if occ == "A" or occ == "B" then
		if mine == "A" or mine == "B" then return occ == mine and C_YOU or C_FOE end
		return C_OPEN
	end
	return C_OPEN
end

local function paint(h, color, locked, t)
	if not h then return end
	for _, l in ipairs(h.lamps) do
		l.Color = locked and C_LOCK or color
		l.Transparency = locked and 0.5 or 0
	end
	for _, b in ipairs(h.beams) do
		b.part.Color = color
		b.part.Transparency = locked and 1 or math.clamp(b.base + 0.12 * (1 + math.sin(t * 13 + b.ph)) / 2, 0, 1)
	end
	for _, b in ipairs(h.border) do
		if locked then
			b.part.Color = C_LOCK
			b.part.Transparency = (b.i % 3 == 0) and 1 or 0.35
		else
			local wave = 0.55 + 0.45 * math.max(0, math.sin(b.a * 9 - t * 5))
			b.part.Color = Color3.new(color.R * wave, color.G * wave, color.B * wave)
			b.part.Transparency = 0
		end
	end
end

local acc = 0
local t0 = os.clock()
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.05 then return end
	acc = 0
	local on = script:GetAttribute("HardpointPointFXEnabled") ~= false and state:GetAttribute("HpLive") == true
		and player:GetAttribute("InMenu") ~= true
	local phase = state:GetAttribute("HpPhase")
	if not on or (phase ~= "live" and phase ~= "warmup") or #points == 0 then
		if cur or nxt then clearAll() end
		script:SetAttribute("HardpointPointFXParts", partsAlive)
		return
	end
	local t = os.clock() - t0
	local idx = tonumber(state:GetAttribute("HpIndex")) or 1
	local warm = phase == "warmup"
	-- the point in play (in the warmup point 1 is shown LOCKED as the "next" one)
	local want = (not warm) and idx or nil
	if want ~= curIdx then
		destroy(cur)
		cur, curIdx = nil, nil
		if want and points[want] then cur, curIdx = build(points[want], "current"), want end
	end
	local showNext = warm or state:GetAttribute("HpShowNext") == true
	local ni = warm and 1 or (tonumber(state:GetAttribute("HpNextIndex")) or 1)
	local wantN = showNext and ni ~= curIdx and ni or nil
	if wantN ~= nxtIdx then
		destroy(nxt)
		nxt, nxtIdx = nil, nil
		if wantN and points[wantN] then nxt, nxtIdx = build(points[wantN], "next"), wantN end
	end
	paint(cur, colourFor(state:GetAttribute("HpOcc"), t), false, t)
	paint(nxt, C_LOCK, true, t)
	script:SetAttribute("HardpointPointFXParts", partsAlive)
end)
