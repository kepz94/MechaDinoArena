-- LeaderboardLooks preview builder v0.3 (mockup docs/mockups/leaderboard_looks_v0.3.html). Ran in a Studio Play server session only (via a temporary ModuleScript); nothing saved to the place. STYLE "A" fossil tablet, "B" mecha monitor, "C" rib cage arch.
local STYLE = _G.LB_STYLE or "A"
local old = workspace:FindFirstChild("ZZ_LBPreview")
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = "ZZ_LBPreview"
root.Parent = workspace

local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local C = {
	slateD = Color3.fromRGB(60, 70, 86), slate = Color3.fromRGB(74, 84, 102), steel = Color3.fromRGB(154, 166, 184),
	neon = Color3.fromRGB(255, 100, 18), bone = Color3.fromRGB(236, 224, 196), boneD = Color3.fromRGB(205, 190, 160),
	rock = Color3.fromRGB(96, 88, 80), rockD = Color3.fromRGB(70, 64, 58), stone = Color3.fromRGB(120, 110, 98),
	fern = Color3.fromRGB(64, 140, 72), fernD = Color3.fromRGB(44, 104, 56), screen = Color3.fromRGB(12, 16, 24),
	amber = Color3.fromRGB(255, 170, 40), gold = Color3.fromRGB(255, 200, 50), cyan = Color3.fromRGB(127, 233, 255),
}

local function P(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end
local function W(parent, size, cf, color, mat)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = mat or Enum.Material.SmoothPlastic
	w.Parent = parent
	return w
end
local function bone(parent, a, b, r, color)
	local mid, len = (a + b) / 2, (b - a).Magnitude
	local cyl = P(parent, Vector3.new(len, r * 2, r * 2), CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0), color or C.bone, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	P(parent, Vector3.new(r * 3.2, r * 3.2, r * 3.2), CFrame.new(a), color or C.bone, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	P(parent, Vector3.new(r * 3.2, r * 3.2, r * 3.2), CFrame.new(b), color or C.bone, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	return cyl
end

-- the screen's SurfaceGui (sample rows)
local ROWS_W = {{"DINOSLAYER", 142, 61}, {"T3NOTANK", 118, 70}, {"SKYCLAW", 97, 44}, {"MEGABYTE_RX", 90, 88}, {"PACHYPOWER", 77, 52},
	{"VENOMQUEEN", 64, 40}, {"KEPZ", 58, 19}, {"ROCKJAW", 51, 33}, {"QUILLSTORM", 47, 46}, {"HERRERA_HQ", 41, 22}}
local ROWS_L = {{"KEPZ", 58, 19, 7}, {"ROCKJAW", 51, 33, 8}, {"SPIKEDOG", 22, 30}, {"NEWBIE_99", 3, 1}, {"GLOWSTICK", 0, 0}}
local function screenGui(part, kind, showHeader)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.Parent = part
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = C.screen
	f.BorderSizePixel = 0
	f.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.05, 0), UDim.new(0.05, 0)
	pad.Parent = f
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0.012, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	local function label(txt, color, h, order, align)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, h, 0)
		l.FontFace = SILK
		l.TextScaled = true
		l.Text = txt
		l.TextColor3 = color
		l.TextXAlignment = align or Enum.TextXAlignment.Center
		l.LayoutOrder = order
		l.Parent = f
		return l
	end
	if showHeader then
		label(kind == "world" and "ALL TIME" or "THIS SERVER", kind == "world" and C.gold or C.cyan, 0.035, 1)
		label(kind == "world" and "WORLDWIDE" or "LOBBY", Color3.new(1, 1, 1), 0.075, 2)
	else
		label(kind == "world" and "ALL TIME · ARENA WINS" or "PLAYERS HERE NOW · ARENA WINS", kind == "world" and C.gold or C.cyan, 0.04, 1)
	end
	local rows = kind == "world" and ROWS_W or ROWS_L
	for i, r in ipairs(rows) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = (i == 1 and kind == "world") and 0.75 or 1
		row.BackgroundColor3 = C.gold
		row.Size = UDim2.new(1, 0, 0.068, 0)
		row.LayoutOrder = 10 + i
		row.Parent = f
		local cols = {{tostring(i), 0, 0.08, Color3.fromRGB(138, 149, 168), Enum.TextXAlignment.Right},
			{(r[4] and ("#" .. r[4] .. " ") or "") .. r[1], 0.11, 0.55, i == 1 and kind == "world" and C.gold or i == 2 and kind == "world" and Color3.fromRGB(207, 216, 230) or i == 3 and kind == "world" and Color3.fromRGB(224, 153, 90) or Color3.new(1, 1, 1), Enum.TextXAlignment.Left},
			{r[2] .. "W", 0.66, 0.16, Color3.fromRGB(70, 224, 138), Enum.TextXAlignment.Right},
			{r[2] .. "-" .. r[3], 0.84, 0.16, Color3.fromRGB(138, 149, 168), Enum.TextXAlignment.Right}}
		for _, c in ipairs(cols) do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.new(c[2], 0, 0.15, 0)
			l.Size = UDim2.new(c[3], 0, 0.7, 0)
			l.FontFace = SILK
			l.TextScaled = true
			l.Text = c[1]
			l.TextColor3 = c[4]
			l.TextXAlignment = c[5]
			l.Parent = row
		end
	end
	return sg
end
local function textPlate(part, txt, color, bg)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = bg and 0 or 1
	l.BackgroundColor3 = bg or Color3.new()
	l.FontFace = SILK
	l.TextScaled = true
	l.Text = txt
	l.TextColor3 = color
	l.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0.18, 0), UDim.new(0.18, 0), UDim.new(0.08, 0), UDim.new(0.08, 0)
	pad.Parent = l
end

-- blocky dino skull facing -Z of cf (front of the board), centered at cf
local function skull(parent, cf, s, color, eye)
	local c = color or C.bone
	P(parent, Vector3.new(6, 4.6, 6) * s, cf * CFrame.new(0, 0.6 * s, 1.2 * s), c)
	P(parent, Vector3.new(4.4, 3, 5) * s, cf * CFrame.new(0, 0.1 * s, -3.6 * s), c)
	P(parent, Vector3.new(4.2, 1.4, 6.6) * s, cf * CFrame.new(0, -2.2 * s, -1.6 * s), C.boneD)
	P(parent, Vector3.new(1.4, 1.3, 0.3) * s, cf * CFrame.new(-1.7, 1.2 * s, -1.8 * s), eye or Color3.fromRGB(30, 26, 22), eye and Enum.Material.Neon or nil)
	P(parent, Vector3.new(1.4, 1.3, 0.3) * s, cf * CFrame.new(1.7, 1.2 * s, -1.8 * s), eye or Color3.fromRGB(30, 26, 22), eye and Enum.Material.Neon or nil)
	P(parent, Vector3.new(0.9, 0.7, 0.3) * s, cf * CFrame.new(-0.8 * s, 0.6 * s, -6.15 * s), Color3.fromRGB(30, 26, 22))
	P(parent, Vector3.new(0.9, 0.7, 0.3) * s, cf * CFrame.new(0.8 * s, 0.6 * s, -6.15 * s), Color3.fromRGB(30, 26, 22))
	for i = -3, 3 do
		W(parent, Vector3.new(0.45, 1.1, 0.6) * s, cf * CFrame.new(i * 0.6 * s, -1.6 * s, -5.6 * s) * CFrame.Angles(math.rad(180), 0, 0), Color3.new(1, 1, 1))
	end
	-- crest horns
	W(parent, Vector3.new(0.8, 2.4, 2) * s, cf * CFrame.new(-2.6 * s, 3.4 * s, 2.4 * s), c)
	W(parent, Vector3.new(0.8, 2.4, 2) * s, cf * CFrame.new(2.6 * s, 3.4 * s, 2.4 * s), c)
end
local function fern(parent, cf, s)
	for i = 0, 5 do
		local a = math.rad(-75 + i * 30)
		W(parent, Vector3.new(0.4, 0.5, 5) * s, cf * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, 1.6 * s, -2.2 * s), i % 2 == 0 and C.fern or C.fernD, Enum.Material.Grass)
	end
end
local function rockLump(parent, cf, size)
	P(parent, size, cf, C.rock, Enum.Material.Slate)
	P(parent, size * Vector3.new(0.7, 0.8, 0.8), cf * CFrame.new(size.X * 0.25, size.Y * 0.15, size.Z * 0.1) * CFrame.Angles(0.15, 0.4, 0.1), C.rockD, Enum.Material.Slate)
	P(parent, size * Vector3.new(0.6, 0.7, 0.7), cf * CFrame.new(-size.X * 0.3, size.Y * 0.05, -size.Z * 0.1) * CFrame.Angles(-0.1, -0.5, 0.12), C.stone, Enum.Material.Slate)
end

-- STYLE A: fossil tablet
local function styleA(m, base, kind)
	-- plinth
	rockLump(m, base * CFrame.new(0, 2.5, 0), Vector3.new(34, 5, 12))
	-- the tablet, a little tilted back
	local tab = base * CFrame.new(0, 5 + 19, 1) * CFrame.Angles(math.rad(-4), 0, 0)
	P(m, Vector3.new(30, 38, 3.4), tab, C.stone, Enum.Material.Slate)
	-- chipped edges
	P(m, Vector3.new(4, 6, 3.6), tab * CFrame.new(-14, 17, 0) * CFrame.Angles(0, 0, 0.5), C.stone, Enum.Material.Slate)
	P(m, Vector3.new(5, 5, 3.6), tab * CFrame.new(14.5, -16, 0) * CFrame.Angles(0, 0, -0.4), C.stone, Enum.Material.Slate)
	-- screen inset
	local scr = P(m, Vector3.new(24, 28, 0.3), tab * CFrame.new(0, -1.5, -1.8), C.screen)
	screenGui(scr, kind, false)
	-- bone frame sides
	bone(m, (tab * CFrame.new(-14.2, -15, -2)).Position, (tab * CFrame.new(-14.2, 13, -2)).Position, 0.7)
	bone(m, (tab * CFrame.new(14.2, -15, -2)).Position, (tab * CFrame.new(14.2, 13, -2)).Position, 0.7)
	-- the bone title bar across the top
	local bar = bone(m, (tab * CFrame.new(-13, 16.2, -2.2)).Position, (tab * CFrame.new(13, 16.2, -2.2)).Position, 1.7)
	local plate = P(m, Vector3.new(22, 3.2, 0.2), tab * CFrame.new(0, 16.2, -3.95), C.bone)
	textPlate(plate, kind == "world" and "WORLDWIDE" or "LOBBY", Color3.fromRGB(70, 52, 30))
	-- ribs fanning out behind
	for i = 1, 4 do
		local y = 6 - i * 6
		bone(m, (tab * CFrame.new(-15, y, 1.5)).Position, (tab * CFrame.new(-22 - i * 0.6, y + 5, 3)).Position, 0.5)
		bone(m, (tab * CFrame.new(15, y, 1.5)).Position, (tab * CFrame.new(22 + i * 0.6, y + 5, 3)).Position, 0.5)
	end
	-- skull on top + amber
	skull(m, tab * CFrame.new(0, 23, 0) * CFrame.Angles(0, math.rad(180), 0) * CFrame.Angles(0, math.rad(180), 0), 1.2)
	P(m, Vector3.new(2.2, 2.2, 2.2), tab * CFrame.new(0, 19.6, -3.4), C.amber, Enum.Material.Neon, Enum.PartType.Ball)
	-- ferns
	fern(m, base * CFrame.new(-15, 4.5, -5), 1.3)
	fern(m, base * CFrame.new(15, 4.5, -5), 1.3)
	fern(m, base * CFrame.new(-6, 4.5, -6.5), 0.9)
end

-- STYLE B: mecha monitor on a rock
local function styleB(m, base, kind)
	rockLump(m, base * CFrame.new(0, 3, 0), Vector3.new(22, 6, 14))
	-- hydraulic post
	P(m, Vector3.new(10, 3, 8), base * CFrame.new(0, 7, 0), C.slateD, Enum.Material.Metal)
	P(m, Vector3.new(4, 10, 4), base * CFrame.new(-3, 13, 0), C.steel, Enum.Material.Metal, Enum.PartType.Cylinder).CFrame = base * CFrame.new(-3, 13, 0) * CFrame.Angles(0, 0, math.rad(90))
	P(m, Vector3.new(4, 10, 4), base * CFrame.new(3, 13, 0), C.steel, Enum.Material.Metal, Enum.PartType.Cylinder).CFrame = base * CFrame.new(3, 13, 0) * CFrame.Angles(0, 0, math.rad(90))
	P(m, Vector3.new(10, 10, 2.4), base * CFrame.new(0, 13, 0), C.slate, Enum.Material.Metal, Enum.PartType.Cylinder).CFrame = base * CFrame.new(0, 13, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, 0)
	-- monitor
	local mon = base * CFrame.new(0, 18 + 19, 0) * CFrame.Angles(math.rad(-6), 0, 0)
	P(m, Vector3.new(32, 38, 4), mon, C.slateD, Enum.Material.Metal)
	P(m, Vector3.new(34, 3, 5), mon * CFrame.new(0, 19.5, 0), C.slate, Enum.Material.DiamondPlate)
	P(m, Vector3.new(34, 3, 5), mon * CFrame.new(0, -19.5, 0), C.slate, Enum.Material.DiamondPlate)
	local scr = P(m, Vector3.new(27, 31, 0.3), mon * CFrame.new(0, -0.5, -2.1), C.screen)
	screenGui(scr, kind, true)
	-- neon trim like the Rift Gate
	for _, x in ipairs({-15.2, 15.2}) do
		P(m, Vector3.new(0.6, 30, 0.6), mon * CFrame.new(x, 0, -2.2), C.neon, Enum.Material.Neon)
	end
	P(m, Vector3.new(26, 0.6, 0.6), mon * CFrame.new(0, 17.4, -2.2), C.neon, Enum.Material.Neon)
	-- bolts
	for _, v in ipairs({{-15.5, 19.5}, {15.5, 19.5}, {-15.5, -19.5}, {15.5, -19.5}}) do
		P(m, Vector3.new(1.6, 1.6, 1.6), mon * CFrame.new(v[1], v[2], -2.6), C.steel, Enum.Material.Metal, Enum.PartType.Ball)
	end
	-- metal skull crest with neon eyes + claw slashes
	skull(m, mon * CFrame.new(0, 25, 0) * CFrame.Angles(0, math.rad(180), 0) * CFrame.Angles(0, math.rad(180), 0), 1.1, C.steel, C.neon)
	for i = 0, 2 do
		P(m, Vector3.new(0.5, 8, 0.3), mon * CFrame.new(11 + i * 1.3, -12, -2.3) * CFrame.Angles(0, 0, math.rad(25)), C.neon, Enum.Material.Neon)
	end
	-- side fins (dino plates)
	for i = 0, 3 do
		W(m, Vector3.new(1, 5 - i, 4), mon * CFrame.new(-17.5, 10 - i * 6, 0) * CFrame.Angles(0, math.rad(-90), 0), C.slate, Enum.Material.Metal)
		W(m, Vector3.new(1, 5 - i, 4), mon * CFrame.new(17.5, 10 - i * 6, 0) * CFrame.Angles(0, math.rad(90), 0), C.slate, Enum.Material.Metal)
	end
end

-- STYLE C: rib cage arch
local function styleC(m, base, kind)
	rockLump(m, base * CFrame.new(0, 2.5, 0), Vector3.new(40, 5, 16))
	-- spine arch: two curved rows of ribs rising from the rock and meeting overhead
	local H, Wd = 46, 18
	local function arc(t) -- t 0..1 along one side up to the top
		local a = t * math.pi / 2
		return Vector3.new(Wd * math.cos(a), 5 + H * math.sin(a) * 0.95, 0)
	end
	for _, z in ipairs({-3.5, 0, 3.5}) do
		for side = -1, 1, 2 do
			local prev
			for k = 0, 6 do
				local v = arc(k / 6)
				local p = (base * CFrame.new(side * v.X, v.Y, z)).Position
				if prev then bone(m, prev, p, z == 0 and 1.1 or 0.7) end
				prev = p
			end
		end
	end
	-- vertebrae along the top
	for i = -3, 3 do
		P(m, Vector3.new(2.6, 2.2, 2.6), base * CFrame.new(0, 5 + H * 0.95 + 1.2, i * 1.6), C.bone)
		W(m, Vector3.new(0.8, 2.6, 2), base * CFrame.new(0, 5 + H * 0.95 + 3.6, i * 1.6), C.boneD)
	end
	-- the hanging screen on chains
	local scr = P(m, Vector3.new(24, 26, 1.2), base * CFrame.new(0, 24, 0), C.slateD, Enum.Material.Metal)
	local face = P(m, Vector3.new(22, 23, 0.2), base * CFrame.new(0, 23.5, -0.75), C.screen)
	screenGui(face, kind, true)
	for _, x in ipairs({-9, 9}) do
		P(m, Vector3.new(0.4, 12, 0.4), base * CFrame.new(x, 43, 0), C.steel, Enum.Material.Metal)
	end
	P(m, Vector3.new(24, 0.6, 0.6), base * CFrame.new(0, 37.2, -0.8), C.neon, Enum.Material.Neon)
	skull(m, base * CFrame.new(0, 5 + H * 0.95 + 1, -5) * CFrame.Angles(math.rad(-20), 0, 0), 1)
	fern(m, base * CFrame.new(-17, 4.5, -6), 1.5)
	fern(m, base * CFrame.new(17, 4.5, -6), 1.5)
end

-- place both boards framing the gate
local isl = workspace:FindFirstChild("PortalIslet")
local gate = isl and isl:FindFirstChild("Portal_arena")
local g = gate and gate:GetPivot() or CFrame.new(965.4, 41.9, 965.4)
local F = Vector3.new(-0.7071, 0, -0.7071) -- the gate faces the bridge / spawns
local R = Vector3.new(-0.7071, 0, 0.7071) -- right, as seen by a player facing the gate
local groundY = 1.8
local build = STYLE == "A" and styleA or STYLE == "B" and styleB or styleC
for i, side in ipairs({-1, 1}) do
	local pos = Vector3.new(g.X, groundY, g.Z) + R * side * 60 + F * 14
	-- face the spawns, turned 14 degrees in toward the gate's front
	local look = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(side * 14)) * CFrame.new(Vector3.zero, F)).LookVector
	local base = CFrame.lookAt(pos, pos + look) -- LookVector (-Z, the front) faces the spawns
	local m = Instance.new("Model")
	m.Name = "Board_" .. (side < 0 and "lobby" or "world")
	m.Parent = root
	build(m, base, side < 0 and "lobby" or "world")
end
return STYLE .. " built: " .. #root:GetDescendants() .. " instances"
