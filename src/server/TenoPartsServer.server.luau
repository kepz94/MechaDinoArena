-- TenoPartsServer v1.4 (Mecha Dino Arena) — puts the Tenontosaurus' mecha parts on (server-built, every client sees them)
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
-- v1.1 (Kepu 2026-11-02 visual check, "fix all the failed ones": the hoof plates were "barely visible": the 1.0 sole sat
--   below the hand, mostly under the ground): Stomp Shockwave look = an iron boot around each front hand (same B "Iron Hoof
--   Plates" idea, same colours): a steel shell {0.78, 0.46, 0.7} around the hand, a dark rim {0.84, 0.1, 0.76} at its foot,
--   4 dark rivets on each side, and the heat strip {0.8, 0.08, 0.72} on top of the shell (role "heat", hidden until the
--   stomp; TenoMovesFX glows it). Lab cards use it too. Switch: script attribute TenoPartsStompBootEnabled (default true,
--   read at each build; false = 1.0 plates).
-- v1.2 (Kepu 2026-11-02 16:43: "Change the mud armor to be a purple shield armor" -> "Look only", picked look "B Energy
--   Armor" from the Studio captures): the "tmud" part is twin shield pylons on the shoulders instead of the mud tank: on
--   Torso_dorsalShoulder, at x -0.45 and +0.45: a dark pylon {0.225, 0.65, 0.225} (role "pylon"), a lilac Neon band
--   {0.275, 0.06, 0.275} (role "band") and a purple Neon ball tip 0.25 (role "tip"). Lab cards use it too. Switch: script
--   attribute TenoPartsShieldPylonsEnabled (default true, read at each build; false = 1.1 mud tank).
-- v1.3 (plan docs/plans/TENO_PARTS_LOOKS_v2.0.md Task 2, MDA-274; Kepu 2026-11-05 16:48 picks from
--   docs/mockups/teno_parts_redesign.html: Grab-B Pincer Tail, Mortar-B Back Cannon, Stomp-A Quake Hooves, Bellow-A Shriek
--   Sacs, Challenge-C Alarm Beacon, Leap-A Chicken-Leg Rams, Shield-B Shield Mane): while script attribute
--   TenoPartsLooksV2Enabled is true (default, read at each build) the looks come from ServerStorage.DinoArcade.TenoPartsLooksV2
--   1.0 (generated from the mockup by tools/mockup/export_teno_parts_v2.js): the TheriPartsServer 1.1 build (each piece at
--   anchor.CFrame x mount frame x piece frame, positions and sizes x the model's scale; stud = Plastic with Studs on every
--   face, plain = SmoothPlastic, metal = Metal, neon = Neon in the part's area colour or the piece's own colour; box -> Part,
--   wedge -> WedgePart, cyl -> Part Cylinder, ball -> Part Ball (an ellipsoid when its sizes differ: a Block with a Sphere
--   SpecialMesh), cone -> 4 WedgeParts, ring -> 16 blocks). Same Model name "TPart_<id>" and TPartRole attribute (TenoMovesFX
--   reads "rock" / "lens"; new roles muzzle, charge1..4, flash, puff, sac, dome, gauge1..5, disc, rim, pincer, tip). A moving
--   group = an invisible root Part "TPartGroup_<name>" on a Weld "TPartJoint_<name>" (Part0 = the anchor or the parent group's
--   root; C0 = the pivot; attributes TPartType / TPartAxis / TPartAmt / TPartRestC0 / TPartBuiltScale / TPartPartId for
--   TenoPartsAnim 1.0; a Weld, not a Motor6D: IdleAnimation adopts every Motor6D). A strut (the leg rams) = a group of
--   TPartType "aim" on the end nearer its middle ((f0 + f1) / 2 < 0.6 -> the a0 end, else the a1 end), its Y pointing at the
--   other end's point (attributes TPartAimAnchor, TPartAimPoint (scale 1)); TenoPartsAnim re-aims it every frame so the rams
--   telescope with the legs. Pieces: film (flag 2) start invisible (TPartFilm); hidden (flag 4) start invisible (TPartHidden);
--   alpha < 1 -> Transparency 1 - alpha (TPartAlpha); TPartBaseSize kept for TenoPartsAnim's pulses. Model attributes
--   TPartLooks "v2", TPartBuiltScale, TPartBuiltAt (server time). Script attribute TenoPartsDetail "full" (default) / "lite" (skips detail pieces). Lab
--   cards use the same build. Missing module or switch false = the 1.2 looks.
-- v1.4 (Kepu 2026-11-05 17:40 tail grab "ain't looking good": the grab's clamp point was the Clamp Tail's): while a
--   character has the v2 "tgrab" look (Pincer Tail) its attribute TenoGrabClampX = GRIP_X (-3.7: the middle of the pincer
--   jaws, Tail5_main frame, scale 1; from TenoPartsLooksV2: the jaws' first segments span mount x -3.3 .. -4.9, mount at
--   Tail5 x +1.12, so -2.2 .. -3.8, and close past it), read by TenoPose 1.10 (the tail IK) and TenoBotMotion 1.2 (where the
--   held bot hangs); nil otherwise (they use the Clamp Tail's -2.6). Switch: script attribute TenoPartsGrabClampEnabled
--   (default true, read at each apply).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.1"
VERSION = "1.2" -- v1.2 shield pylons
VERSION = "1.3" -- v1.3 the redesigned looks (TenoPartsLooksV2)
VERSION = "1.4" -- v1.4 TenoGrabClampX for the Pincer Tail
local GRIP_X = -3.7
if script:GetAttribute("TenoPartsGrabClampEnabled") == nil then script:SetAttribute("TenoPartsGrabClampEnabled", true) end
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
-- v1.1: the stomp's iron boots
if script:GetAttribute("TenoPartsStompBootEnabled") == nil then script:SetAttribute("TenoPartsStompBootEnabled", true) end
BUILD.tstomp = function()
	if script:GetAttribute("TenoPartsStompBootEnabled") == false then return stomp() end
	local out = {}
	for _, sd in ipairs({"L", "R"}) do
		local a = "Arm" .. sd .. "_hand"
		table.insert(out, {a, {0.78, 0.46, 0.7}, {0.04, 0.03, 0}, {0, 0, 0}, "steel", "plate"})
		table.insert(out, {a, {0.84, 0.1, 0.76}, {0.04, -0.17, 0}, {0, 0, 0}, "dark", "plate"})
		table.insert(out, {a, {0.8, 0.08, 0.72}, {0.04, 0.29, 0}, {0, 0, 0}, "heat", "heat"})
		for _, x in ipairs({-0.24, 0.24}) do
			for _, zz in ipairs({-0.36, 0.36}) do
				table.insert(out, {a, {0.1, 0.1, 0.05}, {0.04 + x, 0.08, zz}, {0, 0, 0}, "dark", "rivet"})
				table.insert(out, {a, {0.1, 0.1, 0.05}, {0.04 + x, -0.06, zz}, {0, 0, 0}, "dark", "rivet"})
			end
		end
	end
	return out
end
-- v1.2: Shield Armor pylons
C.purple = {Color3.fromRGB(150, 70, 255), Enum.Material.Neon}
C.lilac = {Color3.fromRGB(205, 160, 255), Enum.Material.Neon}
if script:GetAttribute("TenoPartsShieldPylonsEnabled") == nil then script:SetAttribute("TenoPartsShieldPylonsEnabled", true) end
do
	local mudV11 = BUILD.tmud
	BUILD.tmud = function()
		if script:GetAttribute("TenoPartsShieldPylonsEnabled") == false then return mudV11() end
		local out = {}
		for _, x in ipairs({-0.45, 0.45}) do
			table.insert(out, {"Torso_dorsalShoulder", {0.225, 0.65, 0.225}, {x, 0.434, -0.2}, {0, 0, 0}, "dark", "pylon"})
			table.insert(out, {"Torso_dorsalShoulder", {0.275, 0.06, 0.275}, {x, 0.634, -0.2}, {0, 0, 0}, "lilac", "band"})
			table.insert(out, {"Torso_dorsalShoulder", {0.25}, {x, 0.859, -0.2}, {0, 0, 0}, "purple", "tip", "ball"})
		end
		return out
	end
end

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

-- v1.3: the redesigned looks (see the header) ------------------------------------------------------------------------------
if script:GetAttribute("TenoPartsLooksV2Enabled") == nil then script:SetAttribute("TenoPartsLooksV2Enabled", true) end
if script:GetAttribute("TenoPartsDetail") == nil then script:SetAttribute("TenoPartsDetail", "full") end
local V2
local function v2Data()
	if V2 == nil then
		V2 = false
		pcall(function()
			local arc = ServerStorage:FindFirstChild("DinoArcade")
			local m = arc and arc:FindFirstChild("TenoPartsLooksV2")
			if m then V2 = require(m) end
		end)
	end
	return V2 or nil
end
local V2_RING_SEGMENTS = 16
local KIND_MAT = {stud = Enum.Material.Plastic, plain = Enum.Material.SmoothPlastic, metal = Enum.Material.Metal, neon = Enum.Material.Neon}
local FACES = {"Top", "Bottom", "Front", "Back", "Left", "Right"}
local function frameOf(t, i, sc) -- t[i .. i + 5] = x, y, z, rx, ry, rz (degrees); position x sc
	return CFrame.new(t[i] * sc, t[i + 1] * sc, t[i + 2] * sc) * CFrame.Angles(math.rad(t[i + 3]), math.rad(t[i + 4]), math.rad(t[i + 5]))
end
local function v2Part(cls, size, cf, kit, glow, role, flags, colour, alpha)
	local p = Instance.new(cls)
	p.Size = size
	p.CFrame = cf
	local kind = kit[2]
	p.Material = KIND_MAT[kind] or Enum.Material.SmoothPlastic
	p.Color = (colour and colour ~= 0) and hex(colour) or (kind == "neon" and glow or hex(kit[1]))
	local surf = kind == "stud" and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
	for _, f in ipairs(FACES) do p[f .. "Surface"] = surf end
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = kind ~= "neon"
	if role and role ~= "" then p:SetAttribute("TPartRole", role) end
	p:SetAttribute("TPartBaseColor", p.Color)
	p:SetAttribute("TPartBaseSize", size)
	if alpha and alpha < 1 then
		p.Transparency = 1 - alpha
		p:SetAttribute("TPartAlpha", alpha)
	end
	if flags and math.floor(flags / 2) % 2 == 1 then
		p.Transparency = 1
		p:SetAttribute("TPartFilm", true)
	end
	if flags and math.floor(flags / 4) % 2 == 1 then
		p.Transparency = 1
		p:SetAttribute("TPartHidden", true)
	end
	return p
end
local function weldTo(p, part0)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = part0, p
	w.Parent = p
end
local function groupRoot(m, name, part0, pivot, sc, id, gtype, axis, amt)
	local root = Instance.new("Part")
	root.Name = "TPartGroup_" .. name
	root.Size = Vector3.one * 0.1 * sc
	root.Transparency = 1
	root.CanCollide, root.CanQuery, root.CanTouch, root.Massless = false, false, false, true
	root.CFrame = pivot
	root:SetAttribute("TPartGroup", name)
	local w = Instance.new("Weld")
	w.Name = "TPartJoint_" .. name
	w.Part0, w.Part1 = part0, root
	w.C0 = part0.CFrame:ToObjectSpace(pivot)
	w.C1 = CFrame.identity
	w:SetAttribute("TPartType", gtype)
	w:SetAttribute("TPartAxis", axis)
	w:SetAttribute("TPartAmt", amt)
	w:SetAttribute("TPartRestC0", w.C0)
	w:SetAttribute("TPartBuiltScale", sc)
	w:SetAttribute("TPartPartId", id)
	root.Parent = m
	w.Parent = root
	return root, w
end
-- one piece row -> the parts that make it (welded to part0)
local function v2Piece(m, D, L, pc, cf, sc, part0, anchorName)
	local kit = D.KIT[pc[12]]
	if not kit then return 0 end
	local shape, sx, sy, sz = pc[2], pc[3] * sc, pc[4] * sc, pc[5] * sc
	local flags, colour, alpha, role = pc[15], pc[16], pc[17], pc[13]
	local made = {}
	if shape == "wedge" then
		made[1] = v2Part("WedgePart", Vector3.new(sx, sy, sz), cf, kit, L.glow, role, flags, colour, alpha)
	elseif shape == "cyl" then
		local p = v2Part("Part", Vector3.new(math.max(0.02, sy), math.max(0.02, sx), math.max(0.02, sx)), cf * CFrame.Angles(0, 0, math.rad(90)), kit, L.glow, role, flags, colour, alpha)
		p.Shape = Enum.PartType.Cylinder
		made[1] = p
	elseif shape == "ball" then
		if math.abs(sx - sy) < 1e-3 and math.abs(sx - sz) < 1e-3 then
			local p = v2Part("Part", Vector3.one * sx, cf, kit, L.glow, role, flags, colour, alpha)
			p.Shape = Enum.PartType.Ball
			made[1] = p
		else -- an ellipsoid: a Block with a Sphere mesh
			local p = v2Part("Part", Vector3.new(math.max(0.02, sx), math.max(0.02, sy), math.max(0.02, sz)), cf, kit, L.glow, role, flags, colour, alpha)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			made[1] = p
		end
	elseif shape == "ring" then -- torus (radius sx, tube sy) about the piece's Z: a ring of blocks
		local rad, tube = sx, sy
		local seg = 2 * math.pi * rad / V2_RING_SEGMENTS
		for k = 0, V2_RING_SEGMENTS - 1 do
			local a = k / V2_RING_SEGMENTS * 2 * math.pi
			made[#made + 1] = v2Part("Part", Vector3.new(math.max(0.02, tube * 2), math.max(0.02, seg * 1.05), math.max(0.02, tube * 2)), cf * CFrame.Angles(0, 0, a) * CFrame.new(rad, 0, 0), kit, L.glow, role, flags, colour, alpha)
		end
	elseif shape == "cone" then -- 4 wedges: back faces on the axis, slopes facing out, tip at +Y
		for k = 0, 3 do
			made[#made + 1] = v2Part("WedgePart", Vector3.new(sx, sy, sx / 2), cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -sx / 4), kit, L.glow, role, flags, colour, alpha)
		end
	else
		made[1] = v2Part("Part", Vector3.new(math.max(0.02, sx), math.max(0.02, sy), math.max(0.02, sz)), cf, kit, L.glow, role, flags, colour, alpha)
	end
	for _, p in ipairs(made) do
		p.Name = (role ~= "" and role or "Piece") .. "_" .. anchorName
		p.Parent = m
		weldTo(p, part0)
	end
	return #made
end
local function buildV2(char, id)
	local D = v2Data()
	local L = D and D.LOOKS[id]
	if not L then return buildPart(char, id) end
	local sc = char:GetScale()
	local lite = script:GetAttribute("TenoPartsDetail") == "lite"
	local m = Instance.new("Model")
	m.Name = "TPart_" .. id
	m:SetAttribute("TPartLooks", "v2")
	m:SetAttribute("TPartBuiltScale", sc)
	local mounts = {}
	for i, mt in ipairs(L.mounts) do
		local anchor = find(char, mt[1])
		if anchor then mounts[i] = {anchor = anchor, cf = anchor.CFrame * frameOf(mt, 2, sc)} end
	end
	local roots = {}
	for _, g in ipairs(L.groups) do -- parents come before their children in the data
		local mt = mounts[g[2]]
		if mt then
			local part0 = (g[12] ~= "" and roots[g[12]]) or mt.anchor
			roots[g[1]] = groupRoot(m, g[1], part0, mt.cf * frameOf(g, 3, sc), sc, id, g[9], g[10], g[11])
		end
	end
	local n = 0
	for _, pc in ipairs(L.pieces) do
		local mt = mounts[pc[1]]
		if mt and not (lite and pc[15] % 2 == 1) then
			n += v2Piece(m, D, L, pc, mt.cf * frameOf(pc, 6, sc), sc, (pc[14] ~= "" and roots[pc[14]]) or mt.anchor, mt.anchor.Name)
		end
	end
	for i, s in ipairs(L.struts or {}) do
		local a0, a1 = find(char, s.a0), find(char, s.a1)
		if a0 and a1 then
			local A = a0.CFrame * (Vector3.new(s.p0[1], s.p0[2], s.p0[3]) * sc)
			local B = a1.CFrame * (Vector3.new(s.p1[1], s.p1[2], s.p1[3]) * sc)
			local nearA = (s.f0 + s.f1) / 2 < 0.6
			local base, aimAt, aimName, aimPoint, from = a0, B, s.a1, s.p1, A:Lerp(B, s.f0)
			if not nearA then base, aimAt, aimName, aimPoint, from = a1, A, s.a0, s.p0, B:Lerp(A, 1 - s.f1) end
			local len = (s.f1 - s.f0) * (B - A).Magnitude
			local pivot = CFrame.lookAt(from, aimAt, base.CFrame.RightVector) * CFrame.Angles(-math.pi / 2, 0, 0) -- Y toward the other end (up hint = the anchor's X: the legs are near vertical)
			local root, w = groupRoot(m, "strut_" .. i, base, pivot, sc, id, "aim", "Y", 0)
			w:SetAttribute("TPartAimAnchor", aimName)
			w:SetAttribute("TPartAimPoint", Vector3.new(aimPoint[1], aimPoint[2], aimPoint[3]))
			local kit = D.KIT[s.mat]
			if kit then
				local p = v2Part("Part", Vector3.new(math.max(0.02, len), s.d * sc, s.d * sc), pivot * CFrame.new(0, len / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), kit, L.glow, "ram", 0, 0, 1)
				p.Shape = Enum.PartType.Cylinder
				p.Name = "ram_" .. base.Name
				p.Parent = m
				weldTo(p, root)
				n += 1
			end
		end
	end
	m:SetAttribute("TPartId", id)
	m:SetAttribute("TPartBuiltAt", workspace:GetServerTimeNow()) -- TenoPartsAnim ignores stamps older than this
	m.Parent = char
	return m, n
end
local function builder()
	return (script:GetAttribute("TenoPartsLooksV2Enabled") ~= false and v2Data()) and buildV2 or buildPart
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
				local _, n = builder()(char, p.id) -- v1.3
				table.insert(built, p.id .. "=" .. n)
			else
				table.insert(built, p.id .. "=" .. #old:GetChildren())
			end
		elseif old then
			old:Destroy()
		end
	end
	char:SetAttribute("TenoPartsBuilt", table.concat(built, ","))
	-- v1.4: the Pincer Tail's clamp point
	local g = char:FindFirstChild("TPart_tgrab")
	local pincer = g and g:GetAttribute("TPartLooks") == "v2" and script:GetAttribute("TenoPartsGrabClampEnabled") ~= false
	char:SetAttribute("TenoGrabClampX", pincer and GRIP_X or nil)
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
		return (builder()(model, p.id)) -- v1.3
	end
	fn.Parent = script
end
