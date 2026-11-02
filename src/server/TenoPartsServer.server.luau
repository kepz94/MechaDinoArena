-- TenoPartsServer v1.0 (Mecha Dino Arena) — puts the Tenontosaurus' mecha parts on (server-built, every client sees them)
-- and builds their Lab card models. Plan docs/plans/TENO_ABILITIES_v1.0.md Task 4 (MDA-176); the looks are the picked
-- mockup looks, same numbers (docs/mockups/teno_abilities_options.html v0.3, tools/mockup/teno_abilities_app.js
-- buildLook; Kepu 2026-11-01: "3,4,7 - A", "5,9,14 - b", 11 "Let's go D"):
--   tgrab A "Clamp Tail" (Tail5_main), tmortar A "Tail Catapult" (Tail3_main), tstomp B "Iron Hoof Plates" (ArmL / ArmR
--   _hand), tbellow B "Crest Speakers" (Head_cranium), tchallenge D "Target Painter" (Torso_chest), tleap B "Spring Coils"
--   (ShinL / ShinR _shin), tmud A "Mud Tank" (Torso_barrel).
-- Who: player characters with Species "Teno". Each look is built while the character attribute <Prefix>Enabled is true
--   (SkillEffects 1.33: bought AND slotted) and removed when it goes false: TenoGrabEnabled -> Model "TPart_tgrab",
--   TenoMortarEnabled -> "TPart_tmortar", TenoStompEnabled, TenoBellowEnabled, TenoChallengeEnabled, TenoLeapEnabled,
--   TenoMudEnabled (Model "TPart_<id>").
-- Build: each piece is a Part welded (WeldConstraint) to a named part of the teno (found anywhere under the character),
--   CFrame = anchor.CFrame * CFrame.new(pos x scale) * R, Size = size x scale (scale = the character's Model scale; the
--   numbers are the mockup's scale-1 units on TenoModelData's parts). R = the mockup's rot(a, b, c) (three.js Euler "ZYX"
--   with x = c, y = b, z = a) = CFrame.Angles(0, 0, a) * CFrame.Angles(0, b, 0) * CFrame.Angles(c, 0, 0) (degrees). The
--   mockup's cylinders (axis Y) are Shape Cylinder parts turned 90 degrees about Z (Size = height, diameter, diameter;
--   cones use the mean diameter); spheres are Shape Ball. The animated mockup pieces are built at their rest pose (clamp
--   jaws 0.54 rad open, coils unsquashed); the stomp heat plate is built hidden (Transparency 1, role "heat") and the
--   catapult boulder shown (role "rock") for TenoMovesFX 1.0. Massless, CanCollide / CanQuery / CanTouch false,
--   CastShadow false for Neon / Glass. Colours (the mockup's): steel Metal #9aa3ad, dark Metal #3a3f47, red Neon #e02a2a,
--   rock Slate #8a8478, mud SmoothPlastic #5b3d22, mud nozzle tip #9b6b3a, heat Neon rgb(255, 98, 18) (HerreraPartsServer
--   1.1: the mockup's #ff7a1a renders yellow as Neon), cyan Neon #7fe9ff, coil glow Neon #ffd34d. Pieces carry attribute
--   TPartRole for TenoMovesFX.
-- Lab cards: BindableFunction "BuildPreview_<id>" under this script for each part (LabPreviewServer 1.2 plug-and-play; its
--   body = the path's owner dino, a teno mannequin): Invoke(mannequin) builds that look on it and returns the part Model.
-- Switches: script attribute TenoPartsServerEnabled (default true, read at start; false = no looks); per part
--   TenoParts_<id>Enabled (default true, read on each apply). Diagnostics: script TenoPartsServerVersion; character
--   TenoPartsBuilt ("<id>=<pieces>,..." of what is on).
local Players = game:GetService("Players")

local VERSION = "1.0"
local function hex(h) return Color3.fromRGB(math.floor(h / 65536) % 256, math.floor(h / 256) % 256, h % 256) end
local C = {
	steel = {hex(0x9aa3ad), Enum.Material.Metal}, dark = {hex(0x3a3f47), Enum.Material.Metal},
	red = {hex(0xe02a2a), Enum.Material.Neon}, rock = {hex(0x8a8478), Enum.Material.Slate},
	mud = {hex(0x5b3d22), Enum.Material.SmoothPlastic}, mudTip = {hex(0x9b6b3a), Enum.Material.SmoothPlastic},
	heat = {Color3.fromRGB(255, 98, 18), Enum.Material.Neon}, cyan = {hex(0x7fe9ff), Enum.Material.Neon},
	coil = {hex(0xffd34d), Enum.Material.Neon},
}
local PARTS = {
	{id = "tgrab", flag = "TenoGrabEnabled"}, {id = "tmortar", flag = "TenoMortarEnabled"}, {id = "tstomp", flag = "TenoStompEnabled"},
	{id = "tbellow", flag = "TenoBellowEnabled"}, {id = "tchallenge", flag = "TenoChallengeEnabled"},
	{id = "tleap", flag = "TenoLeapEnabled"}, {id = "tmud", flag = "TenoMudEnabled"},
}

script:SetAttribute("TenoPartsServerVersion", VERSION)
if script:GetAttribute("TenoPartsServerEnabled") == nil then script:SetAttribute("TenoPartsServerEnabled", true) end
local enabled = script:GetAttribute("TenoPartsServerEnabled") ~= false
for _, p in ipairs(PARTS) do
	if script:GetAttribute("TenoParts_" .. p.id .. "Enabled") == nil then script:SetAttribute("TenoParts_" .. p.id .. "Enabled", true) end
end

-- ---------- pieces (the mockup's numbers) ----------
-- each entry: {anchor, {size}, {pos}, {rot a, b, c (mockup)}, colour key, role, shape ("cyl" / "cone" / "ball"), offset CFrame}
local function rotM(r) return CFrame.Angles(0, 0, math.rad(r[1])) * CFrame.Angles(0, math.rad(r[2]), 0) * CFrame.Angles(math.rad(r[3]), 0, 0) end
local function grab()
	local out = {{"Tail5_main", {0.9, 0.55, 0.5}, {-1.2, 0, 0}, {0, 0, 0}, "steel", "base"}}
	local open = 0.6 * 0.9 -- rest: sc.clamp 0.6
	for _, s in ipairs({1, -1}) do
		local hinge = CFrame.new(-1.65, 0, 0) * CFrame.Angles(0, s * open, 0)
		table.insert(out, {"Tail5_main", {1.2, 0.18, 0.18}, {0, 0, 0}, {0, 0, 0}, "dark", "jaw", nil, hinge * CFrame.new(-0.55, 0, s * 0.18)})
		table.insert(out, {"Tail5_main", {0.25, 0.25, 0.25}, {0, 0, 0}, {0, 0, 0}, "red", "jawTip", nil, hinge * CFrame.new(-1.1, 0, s * 0.18)})
	end
	return out
end
local function mortar()
	local out = {{"Tail3_main", {1.2, 0.18, 1.1}, {0.1, 0.62, 0}, {0, 0, 0}, "steel", "bucket"}}
	for _, z in ipairs({0.55, -0.55}) do table.insert(out, {"Tail3_main", {1.2, 0.6, 0.12}, {0.1, 0.92, z}, {0, 0, 0}, "dark", "wall"}) end
	for _, x in ipairs({0.66, -0.46}) do table.insert(out, {"Tail3_main", {0.12, 0.6, 1.1}, {x, 0.92, 0}, {0, 0, 0}, "dark", "wall"}) end
	table.insert(out, {"Tail3_main", {0.85, 0.85, 0.85}, {0.1, 1.1, 0}, {20, 20, 0}, "rock", "rock"})
	return out
end
local function stomp()
	local out = {}
	for _, sd in ipairs({"L", "R"}) do
		local a = "Arm" .. sd .. "_hand"
		table.insert(out, {a, {0.95, 0.24, 0.85}, {0.08, -0.2, 0}, {0, 0, 0}, "steel", "plate"})
		table.insert(out, {a, {0.9, 0.08, 0.8}, {0.08, -0.36, 0}, {0, 0, 0}, "heat", "heat"})
		for _, x in ipairs({-0.3, 0.3}) do
			for _, zz in ipairs({-0.28, 0.28}) do table.insert(out, {a, {0.1, 0.06, 0.1}, {0.08 + x, -0.05, zz}, {0, 0, 0}, "dark", "rivet"}) end
		end
	end
	return out
end
local function bellow()
	local out = {}
	for _, z in ipairs({0.6, -0.6}) do
		table.insert(out, {"Head_cranium", {0.55, 0.6, 0.25}, {-0.05, 0.05, z}, {0, 0, 0}, "dark", "speakerBox"})
		table.insert(out, {"Head_cranium", {0.38, 0.38, 0.06}, {-0.05, 0.05, z + (z > 0 and 0.14 or -0.14)}, {0, 0, 0}, "cyan", "speaker"})
	end
	table.insert(out, {"Head_cranium", {0.2, 0.12, 1.25}, {-0.05, 0.42, 0}, {0, 0, 0}, "steel", "band"})
	return out
end
local function challenge()
	return {
		{"Torso_chest", {0.7, 0.35, 0.7}, {0.1, 1.05, 0.45}, {0, 0, 0}, "dark", "mount"},
		{"Torso_chest", {0.55, 0.45, 0.55}, {0.1, 1.42, 0.45}, {0, 0, 0}, "steel", "turret"},
		{"Torso_chest", {0.7, 0.16, 0.16}, {0.55, 1.45, 0.45}, {0, 0, 0}, "steel", "barrel"},
		{"Torso_chest", {0.22, 0.22, 0.22}, {0.92, 1.45, 0.45}, {0, 0, 0}, "red", "lens", "ball"},
	}
end
local function leap()
	local out = {}
	for _, sd in ipairs({"L", "R"}) do
		local z = sd == "L" and 0.3 or -0.3
		for i = 0, 5 do table.insert(out, {"Shin" .. sd .. "_shin", {0.62, 0.07, 0.62}, {0, -0.45 + i * 0.18, z}, {0, 0, 0}, "steel", "coil", "cyl"}) end
		table.insert(out, {"Shin" .. sd .. "_shin", {0.7, 0.1, 0.7}, {0, 0.62, z}, {0, 0, 0}, "coil", "coilGlow", "cyl"})
	end
	return out
end
local function mud()
	return {
		{"Torso_barrel", {1.5, 0.95, 1.0}, {0, 1.6, 0}, {0, 0, 90}, "steel", "tank", "cyl"},
		{"Torso_barrel", {1.3, 0.75, 0.8}, {0, 1.6, 0}, {0, 0, 90}, "mud", "mud", "cyl"},
		{"Torso_barrel", {0.2, 0.9, 0.2}, {0.75, 2.05, 0}, {-50, 0, 0}, "dark", "nozzle", "cyl"},
		{"Torso_barrel", {0.3, 0.2, 0.3}, {1.1, 2.35, 0}, {-50, 0, 0}, "mudTip", "nozzleTip", "cyl"},
	}
end
local BUILD = {tgrab = grab, tmortar = mortar, tstomp = stomp, tbellow = bellow, tchallenge = challenge, tleap = leap, tmud = mud}

-- ---------- build / remove ----------
local function find(char, name)
	local p = char:FindFirstChild(name, true)
	return p and p:IsA("BasePart") and p or nil
end
local function buildPart(char, id)
	local sc = char:GetScale()
	local m = Instance.new("Model")
	m.Name = "TPart_" .. id
	local n = 0
	for _, pc in ipairs(BUILD[id]()) do
		local anchor = find(char, pc[1])
		if anchor then
			local col = C[pc[5]]
			local shape = pc[7]
			local sz = pc[2]
			local p = Instance.new("Part")
			p.Name = (pc[6] or "Piece") .. "_" .. pc[1]
			local off = CFrame.new(pc[3][1] * sc, pc[3][2] * sc, pc[3][3] * sc) * rotM(pc[4])
			if pc[8] then
				local o = pc[8] -- the mockup's extra matrix; its translation in scale-1 units
				off = off * CFrame.new(o.Position * sc) * o.Rotation
			end
			if shape == "cyl" or shape == "cone" then
				local d = shape == "cone" and (sz[1] + sz[3]) / 2 or sz[1]
				p.Shape = Enum.PartType.Cylinder
				p.Size = Vector3.new(math.max(0.05, sz[2] * sc), math.max(0.05, d * sc), math.max(0.05, d * sc))
				off = off * CFrame.Angles(0, 0, math.rad(90))
			elseif shape == "ball" then
				p.Shape = Enum.PartType.Ball
				p.Size = Vector3.one * math.max(0.05, sz[1] * sc)
			else
				p.Size = Vector3.new(math.max(0.02, sz[1] * sc), math.max(0.02, sz[2] * sc), math.max(0.02, sz[3] * sc))
			end
			p.Color, p.Material = col[1], col[2]
			p.Transparency = pc[6] == "heat" and 1 or (col[3] or 0)
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
			p.CastShadow = col[2] ~= Enum.Material.Neon and col[2] ~= Enum.Material.Glass
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.CFrame = anchor.CFrame * off
			if pc[6] then p:SetAttribute("TPartRole", pc[6]) end
			p:SetAttribute("TPartBaseColor", col[1])
			p.Parent = m
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = anchor, p
			w.Parent = p
			n += 1
		end
	end
	m:SetAttribute("TPartId", id)
	m.Parent = char
	return m, n
end

local function apply(char)
	if not char.Parent then return end
	local isT = enabled and char:GetAttribute("Species") == "Teno"
	local built = {}
	for _, p in ipairs(PARTS) do
		local want = isT and char:GetAttribute(p.flag) == true and script:GetAttribute("TenoParts_" .. p.id .. "Enabled") ~= false
		local old = char:FindFirstChild("TPart_" .. p.id)
		if want then
			if not old then
				local _, n = buildPart(char, p.id)
				table.insert(built, p.id .. "=" .. n)
			else
				table.insert(built, p.id .. "=" .. #old:GetChildren())
			end
		elseif old then
			old:Destroy()
		end
	end
	char:SetAttribute("TenoPartsBuilt", table.concat(built, ","))
end

local function onCharacter(char)
	for _, p in ipairs(PARTS) do
		char:GetAttributeChangedSignal(p.flag):Connect(function() apply(char) end)
	end
	char:GetAttributeChangedSignal("Species"):Connect(function() apply(char) end)
	task.defer(apply, char)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- ---------- Lab cards (LabPreviewServer 1.2 finds BuildPreview_<pathId>) ----------
for _, p in ipairs(PARTS) do
	local fn = Instance.new("BindableFunction")
	fn.Name = "BuildPreview_" .. p.id
	fn.OnInvoke = function(model)
		if typeof(model) ~= "Instance" then return nil end
		return (buildPart(model, p.id))
	end
	fn.Parent = script
end
