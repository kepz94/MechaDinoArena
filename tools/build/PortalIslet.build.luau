-- PortalIslet.build v1.0 (Mecha Dino Arena) — builds ServerStorage.PortalIslet, the hub's safe portal islet (MDA-456, plan
-- docs/plans/ISLAND_HUB_v1.0.md Task 5, ADR-011, mockup docs/mockups/island_portals_v0.1.html layout "C · Portal Islet").
-- Run in Studio Edit through execute_luau. Replaces an older ServerStorage.PortalIslet. Nothing in Workspace is touched;
-- HubServer 1.0 clones the model into Workspace on hub servers only.
-- Site (read in Studio 2026-11-11): the south-east sea corner. Sea floor y -8, water top y -0.8, beach sand y -0.4; the
--   invisible map walls are at x / z = ±1085. Islet centre (930, 930), radius 95 (edge 1025 < 1060). The bridge runs north-west
--   from the islet edge to dry sand at about (782, 782).
-- Model children (all anchored; looks in the map's Plastic style):
--   IsletSand (sand cylinder, top y 1.5), Plaza (stone disc, top y 1.8), EdgeRing (cyan neon segments on the safe edge),
--   Bridge (deck + rails + posts), BridgeEdge (cyan neon line across the bridge's island end),
--   Portal_arena / Portal_bots (Models: pillars, arch, neon swirl, PointLight, Sign with a SurfaceGui, Trigger),
--   SafeZone_Islet (cylinder) + SafeZone_Bridge (box): invisible, no collide / query / touch, attribute HubSafeZone = true,
--     HubZoneShape "cyl" / "box",
--   IsletSpawn1..8 (invisible 4 x 1 x 4 markers on the plaza, facing the portals; attribute HubSpawn = true).
--   Each portal Trigger: invisible box 18 x 24 x 8, attribute HubPortal = "arena" / "bots".
-- Model attributes: PortalIsletVersion "1.0", IsletCentre (Vector3), IsletRadius 95, IsletFacing (Vector3, toward the island).
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
local C = Vector3.new(930, 0, 930)
local R = 95
local TOP = 1.5 -- sand top
local PLAZA_TOP = 1.8
local LAND = Vector3.new(782, -0.4, 782)
local SAND = Color3.fromRGB(230, 210, 154)
local STONE = Color3.fromRGB(196, 190, 178)
local STONE2 = Color3.fromRGB(150, 146, 138)
local WOOD = Color3.fromRGB(150, 108, 66)
local WOOD2 = Color3.fromRGB(110, 78, 48)
local CYAN = Color3.fromRGB(95, 224, 200)
local ORANGE = Color3.fromRGB(255, 155, 46)
local YELLOW = Color3.fromRGB(255, 200, 50)
local NEON = {[ORANGE] = Color3.fromRGB(255, 100, 18), [YELLOW] = Color3.fromRGB(255, 196, 40)} -- neon blooms lighter: deeper tones
local d = (Vector3.new(LAND.X, 0, LAND.Z) - C).Unit -- toward the island (north-west)
local UP = Vector3.new(0, 1, 0)

local old = ServerStorage:FindFirstChild("PortalIslet")
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "PortalIslet"

local function part(name, size, cf, props, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = parent or model
	return p
end
local function ghost(p) -- invisible helper part
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end
local DISC = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis (X) turned to point up

-- islet + plaza
part("IsletSand", Vector3.new(TOP + 9, R * 2, R * 2), CFrame.new(C.X, (TOP - 9) / 2, C.Z) * DISC,
	{Shape = Enum.PartType.Cylinder, Color = SAND, Material = Enum.Material.Plastic})
part("Plaza", Vector3.new(0.6, 150, 150), CFrame.new(C.X, PLAZA_TOP - 0.3, C.Z) * DISC,
	{Shape = Enum.PartType.Cylinder, Color = STONE, Material = Enum.Material.Plastic})
part("PlazaRing", Vector3.new(0.5, 154, 154), CFrame.new(C.X, PLAZA_TOP - 0.35, C.Z) * DISC,
	{Shape = Enum.PartType.Cylinder, Color = STONE2, Material = Enum.Material.Plastic})

-- cyan edge ring on the safe edge
local ring = Instance.new("Folder") ring.Name = "EdgeRing" ring.Parent = model
local N = 64
for i = 1, N do
	local a = (i - 0.5) / N * math.pi * 2
	local pos = C + Vector3.new(math.cos(a) * (R - 1.5), TOP + 0.1, math.sin(a) * (R - 1.5))
	local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
	local seg = part("Seg" .. i, Vector3.new(0.6, 0.25, 2 * math.pi * (R - 1.5) / N - 0.6), CFrame.lookAt(pos, pos + tangent),
		{Color = CYAN, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}, ring)
	seg.Transparency = 0.15
end

-- bridge (deck from the islet edge to the land)
local bridge = Instance.new("Model") bridge.Name = "Bridge" bridge.Parent = model
local startP = C + d * (R - 6)
local a3 = Vector3.new(startP.X, TOP - 0.5, startP.Z)
local b3 = Vector3.new(LAND.X, LAND.Y + 0.6, LAND.Z)
local len = (b3 - a3).Magnitude
local mid = (a3 + b3) / 2
local deckCF = CFrame.lookAt(mid, b3)
part("Deck", Vector3.new(16, 1, len), deckCF, {Color = WOOD, Material = Enum.Material.WoodPlanks}, bridge)
for _, side in ipairs({-1, 1}) do
	part("Rail" .. (side < 0 and "L" or "R"), Vector3.new(0.8, 0.8, len), deckCF * CFrame.new(side * 7.6, 3, 0),
		{Color = WOOD2, Material = Enum.Material.Wood}, bridge)
	local posts = math.floor(len / 12)
	for k = 0, posts do
		local z = -len / 2 + k * (len / posts)
		part("Post", Vector3.new(0.8, 3, 0.8), deckCF * CFrame.new(side * 7.6, 1.5, z), {Color = WOOD2, Material = Enum.Material.Wood}, bridge)
		if k % 2 == 0 then
			local top = deckCF * CFrame.new(side * 7.6, -0.5, z)
			local h = top.Position.Y - (-8)
			part("Pile", Vector3.new(1.4, h, 1.4), CFrame.new(top.Position - Vector3.new(0, h / 2, 0)),
				{Color = WOOD2, Material = Enum.Material.Wood}, bridge)
		end
	end
end
-- cyan line across the bridge's island end (the safe edge)
part("BridgeEdge", Vector3.new(16, 0.25, 0.8), deckCF * CFrame.new(0, 0.55, -(len / 2 - 0.6)), -- -Z = toward the land
	{Color = CYAN, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})

-- portals: behind the plaza centre (away from the bridge), side by side, facing the island
local function portal(id, color, title, sub, tag, offset)
	local m = Instance.new("Model")
	m.Name = "Portal_" .. id
	m.Parent = model
	local base = C - d * 30 + offset
	local face = CFrame.lookAt(Vector3.new(base.X, PLAZA_TOP, base.Z), Vector3.new(base.X, PLAZA_TOP, base.Z) + d)
	local W, H = 9, 16 -- half width, pillar height
	local ui = color
	color = NEON[color] or color -- parts glow in the deeper tone; the sign text keeps the HUD colour
	part("Step", Vector3.new(W * 2 + 8, 0.6, 10), face * CFrame.new(0, 0.3, 0), {Color = STONE2, Material = Enum.Material.Plastic}, m)
	for _, s in ipairs({-1, 1}) do
		part("Pillar", Vector3.new(3, H, 3), face * CFrame.new(s * (W + 1.5), H / 2 + 0.6, 0), {Color = Color3.fromRGB(58, 66, 80), Material = Enum.Material.Plastic}, m)
		part("Trim", Vector3.new(3.2, 0.6, 3.2), face * CFrame.new(s * (W + 1.5), H + 0.6, 0), {Color = color, Material = Enum.Material.Neon}, m)
	end
	local K = 11
	for i = 0, K do
		local a = math.pi * i / K
		local r = W + 1.5
		local p = face * CFrame.new(math.cos(a) * r, H + 0.6 + math.sin(a) * r, 0) * CFrame.Angles(0, 0, a)
		part("Arch", Vector3.new(2.4, 3, 3), p, {Color = Color3.fromRGB(58, 66, 80), Material = Enum.Material.Plastic}, m)
		part("ArchGlow", Vector3.new(0.5, 3.2, 3.2), p * CFrame.new(-1.3, 0, 0), {Color = color, Material = Enum.Material.Neon,
			CanCollide = false, CanQuery = false, CastShadow = false}, m)
	end
	local glow = {Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 0.35}
	local sw = part("Swirl", Vector3.new(W * 2, H, 0.4), face * CFrame.new(0, H / 2 + 0.6, 0), glow, m)
	part("SwirlTop", Vector3.new(0.4, W * 2, W * 2), face * CFrame.new(0, H + 0.6, 0) * CFrame.Angles(0, math.rad(90), 0),
		{Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false,
			CanTouch = false, CastShadow = false, Transparency = 0.35}, m)
	local core = part("Core", Vector3.new(W * 1.2, H * 0.9, 0.3), face * CFrame.new(0, H / 2 + 2, -0.1),
		{Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false,
			CastShadow = false, Transparency = 0.75}, m)
	local light = Instance.new("PointLight") light.Color = color light.Range = 28 light.Brightness = 2 light.Parent = sw
	local att = Instance.new("Attachment") att.Parent = core
	-- sign
	local sign = part("Sign", Vector3.new(W * 2 + 6, 8, 0.6), face * CFrame.new(0, H + W + 8.5, 0),
		{Color = Color3.fromRGB(20, 20, 26), Material = Enum.Material.Plastic}, m)
	part("SignEdge", Vector3.new(W * 2 + 6.6, 8.6, 0.4), face * CFrame.new(0, H + W + 8.5, 0.2),
		{Color = color, Material = Enum.Material.Neon, CanQuery = false, CastShadow = false}, m)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local function lbl(text, y, h, size, col)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -20, h, 0)
		t.Position = UDim2.new(0, 10, y, 0)
		t.Font = Enum.Font.GothamBlack
		t.Text = text
		t.TextColor3 = col
		t.TextScaled = true
		t.Parent = gui
		local c = Instance.new("UITextSizeConstraint") c.MaxTextSize = size c.Parent = t
		return t
	end
	lbl(title, 0.06, 0.42, 120, ui)
	lbl(sub, 0.5, 0.26, 70, Color3.new(1, 1, 1))
	lbl(tag, 0.77, 0.2, 56, Color3.fromRGB(170, 180, 196))
	-- trigger
	local trig = ghost(part("Trigger", Vector3.new(W * 2, 24, 8), face * CFrame.new(0, 12.6, 0), {}, m))
	trig:SetAttribute("HubPortal", id)
	m:SetAttribute("HubPortal", id)
	return m
end
local view = CFrame.lookAt(Vector3.zero, -d) -- a player on the plaza looking at the portals
local left = -view.RightVector
portal("arena", ORANGE, "ARENA", "HARDPOINT · PLAYERS", "PVP", left * 17)
portal("bots", YELLOW, "HARDPOINT VS BOTS", "5V5 · YOUR SQUAD", "BOTS", -left * 17)

-- safe zones
local zi = ghost(part("SafeZone_Islet", Vector3.new(80, R * 2, R * 2), CFrame.new(C.X, 20, C.Z) * DISC, {Shape = Enum.PartType.Cylinder}))
zi:SetAttribute("HubSafeZone", true) zi:SetAttribute("HubZoneShape", "cyl")
local zb = ghost(part("SafeZone_Bridge", Vector3.new(18, 80, len), deckCF * CFrame.new(0, 20, 0), {}))
zb:SetAttribute("HubSafeZone", true) zb:SetAttribute("HubZoneShape", "box")

-- spawn spots: an arc on the bridge side of the plaza, facing the portals
for i = 1, 8 do
	local a = math.rad(-56 + (i - 1) * 16)
	local dir = (CFrame.fromAxisAngle(UP, a) * CFrame.new(d)).Position
	local pos = C + dir * 34 + Vector3.new(0, PLAZA_TOP + 0.5, 0)
	local target = C - d * 30 + Vector3.new(0, PLAZA_TOP + 0.5, 0)
	local s = ghost(part("IsletSpawn" .. i, Vector3.new(4, 1, 4), CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z)), {}))
	s:SetAttribute("HubSpawn", true)
end

model:SetAttribute("PortalIsletVersion", VERSION)
model:SetAttribute("IsletCentre", C)
model:SetAttribute("IsletRadius", R)
model:SetAttribute("IsletFacing", d)
model.PrimaryPart = model:FindFirstChild("Plaza")
model.Parent = ServerStorage
local n = 0
for _, x in ipairs(model:GetDescendants()) do if x:IsA("BasePart") then n += 1 end end
return ("PortalIslet %s built: %d parts, bridge %.0f studs"):format(VERSION, n, len)
