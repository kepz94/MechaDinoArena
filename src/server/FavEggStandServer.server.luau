-- FavEggStandServer v1.0 (Mecha Dino Arena) — the Favorite Egg incubator on the island plaza (Script, ServerScriptService).
-- Plan docs/plans/FAVORITE_EGG_v1.0.md Task 4 (MDA-610), mockup docs/mockups/favorite_egg_v0.1.html (stand, picked "B · Prize reel").
-- Hub servers only. Waits for Workspace.ShopStand (ShopStandServer) and Workspace.PortalIslet.Plaza, then builds Workspace.FavEggStand
--   at the shop's distance from the plaza centre c, at FavEggStandAngle (225) degrees from world +X toward +Z (across from the ARENA
--   portal at 45; shop 160, quests 290), on the ground (ray down), facing c.
-- Look (studs; the stand's front faces c): a dark metal base cylinder (10 wide, 1.6 tall, rgb(43,50,61)) with a cyan neon ring; a
--   glass column (8 wide, 9 tall, Glass rgb(127,233,255) at 0.55); a lid (9 wide, 1.4 tall, rgb(58,67,80)) with two orange neon
--   lights; inside the glass the egg (a sphere mesh 3.6 x 4.7 x 3.6, cream rgb(243,230,194), four spots green / cyan) at mid-height
--   (FavEggClient bobs it locally); over the lid a yellow sign "LIKE + FAVORITE / FREE EGG ROLL" (Silkscreen) and the odds line
--   "COMMON 60 · RARE 30 · EPIC 5 · LEGEND 2 · DINO 3" (from FavEggServer's odds); above it a BillboardGui "Timer" (dark plate, red
--   outline, "LIMITED TIME" + a clock that FavEggClient fills per player).
-- A ProximityPrompt on the base: ActionText "FREE ROLL", ObjectText "Favorite Egg", HoldDuration 0, MaxActivationDistance
--   FavEggPromptRange (14), RequiresLineOfSight false. Model attributes for the server / client: FavEggFront (6 studs in front of the
--   base, toward c), FavEggEgg (the egg's rest position).
-- Size: the stand is built at the sizes above, then Model:ScaleTo(FavEggStandScale (2.2)) about its ground point (Studio check
--   2026-11-26: at 1x it was 16 studs tall next to the 46-stud shop); the sign's PixelsPerStud is 40 / scale so its text keeps its
--   look; the timer billboard is sized in studs (6.6 x 1.45, times the scale) 3.4 x scale studs over the sign, so it no longer covers
--   the sign from far away. ModelStreamingMode Persistent (StreamingEnabled: FavEggClient needs the egg, clock and prompt).
-- Switches / numbers (script attributes, read at start): FavEggStandEnabled (true), FavEggStandAngle (225), FavEggPromptRange (20),
--   FavEggStandScale (2.2), FavEggStandRadius (45; unset = the shop's distance from c). Place (Kepu 2026-11-26 "By the quest stand"):
--   225 at the shop's distance is the bridge mouth (PortalIslet.Bridge at 225), so the default is 315 degrees at 45 studs, the inner
--   ring between the QUESTS stall (289) and the LOBBY board (347), off the bridge-to-portal line.
-- Diagnostics: FavEggStandServerVersion, FavEggStandState ("off" / "notHub" / "waiting" / "built" / "error: ...").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VERSION = "1.0"
script:SetAttribute("FavEggStandServerVersion", VERSION)
for k, v in pairs({FavEggStandEnabled = true, FavEggStandAngle = 315, FavEggStandRadius = 45, FavEggPromptRange = 20, FavEggStandScale = 2.2}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function state(s) script:SetAttribute("FavEggStandState", s) end
if script:GetAttribute("FavEggStandEnabled") == false then state("off") return end

state("waiting")
local shop, plaza
local t0 = os.clock()
while os.clock() - t0 < 180 do
	local kind = ReplicatedStorage:GetAttribute("ServerKind")
	if kind ~= nil and kind ~= "hub" then state("notHub") return end
	shop = workspace:FindFirstChild("ShopStand")
	local islet = workspace:FindFirstChild("PortalIslet")
	plaza = islet and islet:FindFirstChild("Plaza")
	if kind == "hub" and shop and plaza then break end
	task.wait(0.5)
end
if not (shop and plaza) then state("waiting: no shop / plaza") return end

local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local function part(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide = true, false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function cyl(parent, name, dia, h, baseCF, y, color, mat)
	-- a vertical cylinder: Roblox cylinders run along X, so turn it 90 degrees about Z
	return part(parent, name, Vector3.new(h, dia, dia), baseCF * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color, mat,
		Enum.PartType.Cylinder)
end
local function label(parent, text, size, color, y, h)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, h, 0)
	l.Position = UDim2.new(0, 0, y, 0)
	l.FontFace = SILK
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l:SetAttribute("FontSwap", "keep")
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.Parent = l
	l.Parent = parent
	return l
end

local ok, err = pcall(function()
	local old = workspace:FindFirstChild("FavEggStand")
	if old then old:Destroy() end
	local c = Vector3.new(plaza.Position.X, 0, plaza.Position.Z)
	local sp = shop:GetPivot()
	local r = tonumber(script:GetAttribute("FavEggStandRadius")) or (Vector3.new(sp.Position.X, 0, sp.Position.Z) - c).Magnitude
	local a = math.rad(tonumber(script:GetAttribute("FavEggStandAngle")) or 225)
	local x, z = c.X + math.cos(a) * r, c.Z + math.sin(a) * r
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {shop}
	local hit = workspace:Raycast(Vector3.new(x, sp.Position.Y + 60, z), Vector3.new(0, -200, 0), params)
	local gy = hit and hit.Position.Y or (sp.Position.Y - 4)
	local base = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(c.X, gy, c.Z))

	local m = Instance.new("Model")
	m.Name = "FavEggStand"
	local SC = math.clamp(tonumber(script:GetAttribute("FavEggStandScale")) or 2.2, 0.5, 5)
	local METAL, LID, CYAN, ORANGE = Color3.fromRGB(43, 50, 61), Color3.fromRGB(58, 67, 80), Color3.fromRGB(127, 233, 255),
		Color3.fromRGB(255, 155, 46)
	local baseP = cyl(m, "Base", 10, 1.6, base, 0, METAL, Enum.Material.Metal)
	cyl(m, "Ring", 10.3, 0.35, base, 1.45, CYAN, Enum.Material.Neon)
	local glass = cyl(m, "Glass", 8, 9, base, 1.6, CYAN, Enum.Material.Glass)
	glass.Transparency = 0.55
	cyl(m, "Lid", 9, 1.4, base, 10.6, LID, Enum.Material.Metal)
	for i, sx in ipairs({-2.2, 2.2}) do
		part(m, "Light" .. i, Vector3.new(0.9, 0.6, 0.9), base * CFrame.new(sx, 11.3, -4.3), ORANGE, Enum.Material.Neon)
	end
	-- the egg
	local eggCF = base * CFrame.new(0, 6.1, 0)
	local egg = part(m, "Egg", Vector3.new(3.6, 4.7, 3.6), eggCF, Color3.fromRGB(243, 230, 194))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	local spots = {{-0.9, 0.5, -1.55, Color3.fromRGB(168, 216, 106), 0.9}, {0.8, 1.2, -1.45, CYAN, 0.7},
		{0.6, -0.8, -1.6, Color3.fromRGB(168, 216, 106), 1}, {-1.1, -1.2, -1.3, CYAN, 0.6}}
	for i, s in ipairs(spots) do
		local sp2 = part(m, "Spot" .. i, Vector3.new(s[5], s[5] * 0.8, 0.3), eggCF * CFrame.new(s[1], s[2], s[3]), s[4], Enum.Material.SmoothPlastic,
			Enum.PartType.Ball)
		sp2:SetAttribute("EggSpot", true)
	end
	-- the sign over the lid
	local sign = part(m, "Sign", Vector3.new(11, 3.6, 0.4), base * CFrame.new(0, 14.4, 0), Color3.fromRGB(255, 200, 50))
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40 / SC
	sg.LightInfluence = 0
	sg.Parent = sign
	label(sg, "LIKE + FAVORITE", 70, Color3.fromRGB(27, 20, 6), 0.04, 0.36)
	label(sg, "FREE EGG ROLL", 80, Color3.fromRGB(122, 43, 0), 0.38, 0.38)
	local fe = ServerScriptService:FindFirstChild("FavEggServer")
	local function o(k, d) return fe and tonumber(fe:GetAttribute(k)) or d end
	label(sg, ("COMMON %d · RARE %d · EPIC %d · LEGEND %d · DINO %d"):format(o("FavEggOddsCommon", 60), o("FavEggOddsRare", 30),
		o("FavEggOddsEpic", 5), o("FavEggOddsLegend", 2), o("FavEggOddsDino", 3)), 26, Color3.fromRGB(27, 20, 6), 0.78, 0.18)
	-- the timer billboard (FavEggClient fills the clock per player)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Timer"
	bb.Size = UDim2.fromScale(6.6 * SC, 1.45 * SC) -- studs
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.4 * SC, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Adornee = sign
	bb.Parent = sign
	local plate = Instance.new("Frame")
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Color3.fromRGB(11, 15, 22)
	plate.BackgroundTransparency = 0.1
	plate.Parent = bb
	local cr = Instance.new("UICorner") cr.CornerRadius = UDim.new(0, 10) cr.Parent = plate
	local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(255, 90, 110) st.Thickness = 3 st.Parent = plate
	local top = label(plate, "LIMITED TIME", 60, Color3.fromRGB(255, 90, 110), 0.06, 0.34)
	top.Name = "Top"
	local clock = label(plate, "48:00:00", 110, Color3.new(1, 1, 1), 0.38, 0.56)
	clock.Name = "Clock"
	-- the prompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "FavEggPrompt"
	pp.ActionText = "FREE ROLL"
	pp.ObjectText = "Favorite Egg"
	pp.HoldDuration = 0
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.MaxActivationDistance = tonumber(script:GetAttribute("FavEggPromptRange")) or 20
	pp.RequiresLineOfSight = false
	pp.Parent = baseP
	m.PrimaryPart = baseP
	m.WorldPivot = base
	if SC ~= 1 then m:ScaleTo(SC) end
	pcall(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	m:SetAttribute("FavEggFront", (base * CFrame.new(0, 0, -6 * SC)).Position)
	m:SetAttribute("FavEggEgg", egg.Position)
	m.Parent = workspace
end)
state(ok and "built" or ("error: " .. tostring(err)))
