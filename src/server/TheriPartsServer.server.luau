-- TheriPartsServer v1.1 (Mecha Dino Arena) — puts the Therizinosaurus' mecha parts on (server-built, every client sees them)
-- and builds their Lab card models. Plan docs/plans/THERIZINO_PARTS_v1.0.md Task 3 (MDA-243); the looks are Kepu's picks
-- from docs/mockups/therizino_parts_options.html v0.1 (tools/mockup/therizino_parts_app.js buildLook, same numbers; Kepu
-- 2026-11-04 11:07 "1-C, 3-A, 5-B, 12-C, 16-A, 18-C, 19-A"):
--   zhook C "Back Crane" (Torso_body), zfeather A "Arm Racks" (ArmL / ArmR _fore), zharvest B "Arm Pistons" (ArmL / ArmR
--   _fore), zgrapple C "Belly Winch" (Torso_body, Torso_chest), zdeflect A "Spinner Hubs" (ArmL / ArmR _hand), zclock C
--   "Joint Rings" (shoulders, haunches, knees, elbows), zsnare A "Tail Spools" (Tail2 / Tail3 / Tail4 _main).
-- Who: player characters with Species "Therizino". Each look is built while the character attribute <Prefix>Enabled is true
--   (SkillEffects 1.42: bought AND slotted) and removed when it goes false: TheriHookEnabled -> Model "ZPart_zhook",
--   TheriFeatherEnabled, TheriFieldEnabled (zharvest), TheriGrappleEnabled, TheriDeflectEnabled, TheriClockEnabled,
--   TheriSnareEnabled (Model "ZPart_<id>").
-- Build: the mockup gives each piece's position in the rest model space (TherizinoModelData: CFrames relative to the
--   HumanoidRootPart, scale 1) on a named part. Here: off = rest(part)^-1 * CFrame.new(pos) * R (scale-1 units), then the
--   offset's position x the character's Model scale; each piece is a Part welded (WeldConstraint) to that named part at
--   anchor.CFrame * off. R = the mockup's rot(a, b, c) = CFrame.Angles(0, 0, a) * CFrame.Angles(0, b, 0) * CFrame.Angles(c,
--   0, 0) (degrees; TenoPartsServer 1.0's rule). The mockup's cylinders (axis Y; size = diameter, height) are Shape
--   Cylinder parts turned 90 degrees about Z; its tori (Joint Rings) are rings of RING_SEGMENTS (10) blocks. Animated pieces
--   are built at rest. Massless, CanCollide / CanQuery / CanTouch false, CastShadow false for Neon. Colours (the mockup's):
--   steel Metal #9aa3ad, dark Metal #3a3f47, brass Metal #c9a24a, red Neon #e02a2a, feather SmoothPlastic #f0ead8, blade
--   SmoothPlastic #e2dccb. Pieces carry attribute ZPartRole for TheriMovesFX 1.0 (hook: base / jib / boom / reel; feather:
--   rack / blade; harvest: sleeve / ram / foot; grapple: box / drum / nozzle; deflect: hub / cap; clock: ring; snare: spool /
--   core).
-- Lab cards: BindableFunction "BuildPreview_<id>" under this script for each part (LabPreviewServer 1.2 plug-and-play).
-- Switches: script attribute TheriPartsServerEnabled (default true, read at start; false = no looks); per part
--   TheriParts_<id>Enabled (default true, read on each apply). Diagnostics: script TheriPartsServerVersion,
--   TheriPartsRestParts (rest CFrames loaded); character TheriPartsBuilt ("<id>=<pieces>,...").
-- v1.1 (MDA-250, plan docs/plans/THERIZINO_PARTS_LOOKS_v2.0.md Task 2; Kepu 2026-11-04 14:13 picks from the redesign mockup
--   docs/mockups/therizino_parts_redesign.html): while script attribute TheriPartsLooksV2Enabled is true (default) the looks
--   come from ServerStorage.DinoArcade.TheriPartsLooksV2 1.0 (generated from the mockup): each piece at anchor.CFrame x
--   mount frame x piece frame (positions x the model's scale), the style kit (stud = Plastic with Studs on every face, plain =
--   SmoothPlastic, metal = Metal, neon = Neon in the part's area colour), shapes box -> Part, wedge -> WedgePart, cyl -> Part
--   Cylinder (axis turned to the mockup's Y), ball -> Part Ball, cone -> 4 WedgeParts as a pyramid. A moving group is an
--   invisible root Part "ZPartGroup_<name>" hung on a Weld "ZPartJoint_<name>" (Part0 = the anchor or the parent group's
--   root, C0 = the pivot; attributes ZPartType / ZPartAxis / ZPartAmt / ZPartRestC0 / ZPartBuiltScale for TheriPartsAnim
--   1.0; a Weld, not a Motor6D, because IdleAnimation adopts every Motor6D); its pieces are welded to the root. Film pieces
--   start invisible (ZPartFilm). Beams "ZPartBeam_<n>" (rubber, straight) join two anchors. Model attribute ZPartLooks
--   "v2"; Lab cards use the same build. Script attribute TheriPartsDetail: "full" (default) / "lite" (skips the pieces the
--   data marks as detail: bolts, teeth, stripes). Missing module or switch false = the v1.0 looks.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 the redesigned looks (TheriPartsLooksV2)
local RING_SEGMENTS = 10
local function hex(h) return Color3.fromRGB(math.floor(h / 65536) % 256, math.floor(h / 256) % 256, h % 256) end
local C = {
	steel = {hex(0x9aa3ad), Enum.Material.Metal}, dark = {hex(0x3a3f47), Enum.Material.Metal},
	brass = {hex(0xc9a24a), Enum.Material.Metal}, red = {hex(0xe02a2a), Enum.Material.Neon},
	feather = {hex(0xf0ead8), Enum.Material.SmoothPlastic}, blade = {hex(0xe2dccb), Enum.Material.SmoothPlastic},
}
local PARTS = {
	{id = "zhook", flag = "TheriHookEnabled"}, {id = "zfeather", flag = "TheriFeatherEnabled"},
	{id = "zharvest", flag = "TheriFieldEnabled"}, {id = "zgrapple", flag = "TheriGrappleEnabled"},
	{id = "zdeflect", flag = "TheriDeflectEnabled"}, {id = "zclock", flag = "TheriClockEnabled"},
	{id = "zsnare", flag = "TheriSnareEnabled"},
}

script:SetAttribute("TheriPartsServerVersion", VERSION)
if script:GetAttribute("TheriPartsServerEnabled") == nil then script:SetAttribute("TheriPartsServerEnabled", true) end
local enabled = script:GetAttribute("TheriPartsServerEnabled") ~= false
for _, p in ipairs(PARTS) do
	if script:GetAttribute("TheriParts_" .. p.id .. "Enabled") == nil then script:SetAttribute("TheriParts_" .. p.id .. "Enabled", true) end
end

-- rest CFrames (scale 1, relative to the HumanoidRootPart) from TherizinoModelData
local REST = {}
do
	local ok, data = pcall(function()
		local arc = ServerStorage:WaitForChild("DinoArcade", 10)
		local models = arc and arc:WaitForChild("Models", 10)
		local m = models and models:WaitForChild("TherizinoModelData", 10)
		return m and require(m)
	end)
	local n = 0
	if ok and type(data) == "table" then
		for _, seg in ipairs(data.segments or {}) do
			for _, p in ipairs(seg.parts or {}) do
				if type(p.cf) == "table" and #p.cf == 12 then
					REST[p.name] = CFrame.new(table.unpack(p.cf))
					n += 1
				end
			end
		end
	end
	script:SetAttribute("TheriPartsRestParts", n)
end
local function restPos(name, i) -- the mockup's theri.byName[name].cf.elements[12 + i] (translation x / y / z)
	local cf = REST[name]
	if not cf then return 0 end
	return i == 0 and cf.X or (i == 1 and cf.Y or cf.Z)
end

-- ---------- pieces (the mockup's numbers) ----------
-- each entry: {part name, {size}, {pos (rest model space)}, {rot a, b, c}, colour key, role, shape ("cyl" / "torus")}
local function hook()
	return {
		{"Torso_body", {1.6, 0.8, 1.6}, {0, 2.45, -0.6}, {0, 0, 0}, "dark", "base"},
		{"Torso_body", {0.6, 4.4, 0.6}, {0, 4.5, -1.4}, {-28, 0, 0}, "steel", "boom"},
		{"Torso_body", {0.7, 0.7, 2.6}, {0, 6.6, -3.2}, {0, 0, 0}, "brass", "jib"},
		{"Torso_body", {0.9, 0.9, 0.9}, {0, 2.95, -0.6}, {0, 0, 90}, "steel", "reel", "cyl"},
	}
end
local function feather()
	local out = {}
	for _, sa in ipairs({{1, "ArmL_fore"}, {-1, "ArmR_fore"}}) do
		local s, arm = sa[1], sa[2]
		table.insert(out, {arm, {0.35, 1.7, 0.75}, {s * 4.15, 0.2, -2.8}, {0, 0, 0}, "dark", "rack"})
		for k = 0, 5 do table.insert(out, {arm, {0.08, 0.18, 1.1}, {s * 4.35, -0.45 + k * 0.26, -2.8}, {0, 0, 0}, "feather", "blade"}) end
	end
	return out
end
local function harvest()
	local out = {}
	for _, side in ipairs({"L", "R"}) do
		local s = side == "L" and 1 or -1
		local arm = "Arm" .. side .. "_fore"
		table.insert(out, {arm, {0.7, 1.5, 0.7}, {s * 4.25, 0.2, -2.7}, {0, 0, 0}, "dark", "sleeve"})
		table.insert(out, {arm, {0.4, 2.2, 0.4}, {s * 4.25, -0.9, -2.7}, {0, 0, 0}, "steel", "ram", "cyl"})
		table.insert(out, {arm, {0.9, 0.3, 0.9}, {s * 4.25, -2.1, -2.7}, {0, 0, 0}, "brass", "foot"})
	end
	return out
end
local function grapple()
	return {
		{"Torso_body", {1.9, 1.0, 1.8}, {0, -0.75, -1.2}, {0, 0, 0}, "dark", "box"},
		{"Torso_body", {1.2, 1.4, 1.2}, {0, -0.75, -1.2}, {0, 0, 90}, "steel", "drum", "cyl"},
		{"Torso_chest", {0.5, 0.5, 1.2}, {0, 1.4, -3.5}, {0, 0, 0}, "brass", "nozzle"},
	}
end
local function deflect()
	local out = {}
	for _, ss in ipairs({{1, "L"}, {-1, "R"}}) do
		local s, side = ss[1], ss[2]
		table.insert(out, {"Arm" .. side .. "_hand", {0.9, 0.5, 0.9}, {s * 4.39, 0.05, -3.39}, {90, 0, 0}, "steel", "hub", "cyl"})
		table.insert(out, {"Arm" .. side .. "_hand", {0.4, 0.4, 0.4}, {s * 4.39, 0.05, -3.9}, {0, 0, 0}, "brass", "cap"})
	end
	return out
end
local function clock()
	local R = {{"ArmL_shoulder", {1.54, 1.62, -2.62}}, {"ArmR_shoulder", {-1.54, 1.62, -2.62}}, {"LegL_haunch", {0.85, -0.54, -0.15}},
		{"LegR_haunch", {-0.85, -0.54, -0.15}}, {"ShinL_knee", {0.85, -2.62, -0.85}}, {"ShinR_knee", {-0.85, -2.62, -0.85}},
		{"ArmL_elbow", {3.39, 0.31, -2.23}}, {"ArmR_elbow", {-3.39, 0.31, -2.23}}}
	local out = {}
	for _, r in ipairs(R) do
		table.insert(out, {r[1], {r[1]:find("elbow") and 0.38 or 0.62, 0.11}, r[2], {90, 0, 0}, "steel", "ring", "torus"})
	end
	return out
end
local function snare()
	local out = {}
	for _, tail in ipairs({"Tail2_main", "Tail3_main", "Tail4_main"}) do
		local y, z = restPos(tail, 1), restPos(tail, 2)
		table.insert(out, {tail, {0.9, 0.6, 0.9}, {0, y + 0.55, z}, {0, 0, 90}, "steel", "spool", "cyl"})
		table.insert(out, {tail, {0.5, 0.65, 0.5}, {0, y + 0.55, z}, {0, 0, 90}, "red", "core", "cyl"})
	end
	return out
end
local BUILD = {zhook = hook, zfeather = feather, zharvest = harvest, zgrapple = grapple, zdeflect = deflect, zclock = clock, zsnare = snare}

-- ---------- build / remove ----------
local function rotM(r) return CFrame.Angles(0, 0, math.rad(r[1])) * CFrame.Angles(0, math.rad(r[2]), 0) * CFrame.Angles(math.rad(r[3]), 0, 0) end
local function find(model, name)
	local p = model:FindFirstChild(name, true)
	return p and p:IsA("BasePart") and p or nil
end
local function newPiece(m, col, role, size, cf, anchor, shape)
	local p = Instance.new("Part")
	p.Name = (role or "Piece") .. "_" .. anchor.Name
	if shape == "cyl" then p.Shape = Enum.PartType.Cylinder end
	p.Size = size
	p.Color, p.Material = col[1], col[2]
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = col[2] ~= Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CFrame = cf
	if role then p:SetAttribute("ZPartRole", role) end
	p:SetAttribute("ZPartBaseColor", col[1])
	p.Parent = m
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = anchor, p
	w.Parent = p
end
local function buildPart(model, id)
	local sc = model:GetScale()
	local m = Instance.new("Model")
	m.Name = "ZPart_" .. id
	local n = 0
	for _, pc in ipairs(BUILD[id]()) do
		local anchor, rest = find(model, pc[1]), REST[pc[1]]
		if anchor and rest then
			local off = rest:Inverse() * CFrame.new(pc[3][1], pc[3][2], pc[3][3]) * rotM(pc[4])
			off = CFrame.new(off.Position * sc) * off.Rotation
			local col, shape, sz = C[pc[5]], pc[7], pc[2]
			local base = anchor.CFrame * off
			if shape == "cyl" then
				newPiece(m, col, pc[6], Vector3.new(math.max(0.05, sz[2] * sc), math.max(0.05, sz[1] * sc), math.max(0.05, sz[1] * sc)),
					base * CFrame.Angles(0, 0, math.rad(90)), anchor, "cyl")
				n += 1
			elseif shape == "torus" then -- three.js TorusGeometry(radius, tube) lies in its XY plane
				local rad, tube = sz[1] * sc, sz[2] * sc
				local seg = 2 * math.pi * rad / RING_SEGMENTS
				for k = 0, RING_SEGMENTS - 1 do
					local a = k / RING_SEGMENTS * 2 * math.pi
					local cf = base * CFrame.Angles(0, 0, a) * CFrame.new(rad, 0, 0)
					newPiece(m, col, pc[6], Vector3.new(math.max(0.05, tube * 2), math.max(0.05, seg * 1.05), math.max(0.05, tube * 2)), cf, anchor)
					n += 1
				end
			else
				newPiece(m, col, pc[6], Vector3.new(math.max(0.02, sz[1] * sc), math.max(0.02, sz[2] * sc), math.max(0.02, sz[3] * sc)), base, anchor)
				n += 1
			end
		end
	end
	m:SetAttribute("ZPartId", id)
	m.Parent = model
	return m, n
end

-- v1.1: the redesigned looks (see the header) ------------------------------------------------------------------------------
if script:GetAttribute("TheriPartsLooksV2Enabled") == nil then script:SetAttribute("TheriPartsLooksV2Enabled", true) end
if script:GetAttribute("TheriPartsDetail") == nil then script:SetAttribute("TheriPartsDetail", "full") end
local V2
local function v2Data()
	if V2 == nil then
		V2 = false
		pcall(function()
			local arc = ServerStorage:FindFirstChild("DinoArcade")
			local m = arc and arc:FindFirstChild("TheriPartsLooksV2")
			if m then V2 = require(m) end
		end)
	end
	return V2 or nil
end
local KIND_MAT = {stud = Enum.Material.Plastic, plain = Enum.Material.SmoothPlastic, metal = Enum.Material.Metal, neon = Enum.Material.Neon}
local FACES = {"Top", "Bottom", "Front", "Back", "Left", "Right"}
local function frameOf(t, i, sc) -- t[i .. i + 5] = x, y, z, rx, ry, rz (degrees); position x sc
	return CFrame.new(t[i] * sc, t[i + 1] * sc, t[i + 2] * sc) * CFrame.Angles(math.rad(t[i + 3]), math.rad(t[i + 4]), math.rad(t[i + 5]))
end
local function v2Part(cls, size, cf, kit, glow, role, film)
	local p = Instance.new(cls)
	p.Size = size
	p.CFrame = cf
	local kind = kit[2]
	p.Material = KIND_MAT[kind] or Enum.Material.SmoothPlastic
	p.Color = kind == "neon" and glow or hex(kit[1])
	local surf = kind == "stud" and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
	for _, f in ipairs(FACES) do p[f .. "Surface"] = surf end
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = kind ~= "neon"
	if role and role ~= "" then p:SetAttribute("ZPartRole", role) end
	p:SetAttribute("ZPartBaseColor", p.Color)
	if film then
		p.Transparency = 1
		p:SetAttribute("ZPartFilm", true)
	end
	return p
end
local function weldTo(p, part0)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = part0, p
	w.Parent = p
end
local function buildV2(model, id)
	local D = v2Data()
	local L = D and D.LOOKS[id]
	if not L then return buildPart(model, id) end
	local sc = model:GetScale()
	local lite = script:GetAttribute("TheriPartsDetail") == "lite"
	local m = Instance.new("Model")
	m.Name = "ZPart_" .. id
	m:SetAttribute("ZPartLooks", "v2")
	m:SetAttribute("ZPartBuiltScale", sc)
	local mounts = {}
	for i, mt in ipairs(L.mounts) do
		local anchor = find(model, mt[1])
		if anchor then mounts[i] = {anchor = anchor, cf = anchor.CFrame * frameOf(mt, 2, sc)} end
	end
	-- groups: an invisible root on a Weld (parents come before their children in the data)
	local roots = {}
	for _, g in ipairs(L.groups) do
		local mt = mounts[g[2]]
		if mt then
			local pivot = mt.cf * frameOf(g, 3, sc)
			local root = Instance.new("Part")
			root.Name = "ZPartGroup_" .. g[1]
			root.Size = Vector3.one * 0.1 * sc
			root.Transparency = 1
			root.CanCollide, root.CanQuery, root.CanTouch, root.Massless = false, false, false, true
			root.CFrame = pivot
			root:SetAttribute("ZPartGroup", g[1])
			local part0 = (g[12] ~= "" and roots[g[12]]) or mt.anchor
			local w = Instance.new("Weld")
			w.Name = "ZPartJoint_" .. g[1]
			w.Part0, w.Part1 = part0, root
			w.C0 = part0.CFrame:ToObjectSpace(pivot)
			w.C1 = CFrame.identity
			w:SetAttribute("ZPartType", g[9])
			w:SetAttribute("ZPartAxis", g[10])
			w:SetAttribute("ZPartAmt", g[11])
			w:SetAttribute("ZPartRestC0", w.C0)
			w:SetAttribute("ZPartBuiltScale", sc)
			w:SetAttribute("ZPartPartId", id)
			root.Parent = m
			w.Parent = root
			roots[g[1]] = root
		end
	end
	local n = 0
	for _, pc in ipairs(L.pieces) do
		local mt = mounts[pc[1]]
		local kit = D.KIT[pc[12]]
		local flags = pc[15]
		if mt and kit and not (lite and flags % 2 == 1) then
			local cf = mt.cf * frameOf(pc, 6, sc)
			local shape, sx, sy, sz = pc[2], pc[3] * sc, pc[4] * sc, pc[5] * sc
			local film = flags >= 2
			local made = {}
			if shape == "wedge" then
				made[1] = v2Part("WedgePart", Vector3.new(sx, sy, sz), cf, kit, L.glow, pc[13], film)
			elseif shape == "cyl" then
				local p = v2Part("Part", Vector3.new(math.max(0.02, sy), math.max(0.02, sx), math.max(0.02, sx)), cf * CFrame.Angles(0, 0, math.rad(90)), kit, L.glow, pc[13], film)
				p.Shape = Enum.PartType.Cylinder
				made[1] = p
			elseif shape == "ball" then
				local p = v2Part("Part", Vector3.one * sx, cf, kit, L.glow, pc[13], film)
				p.Shape = Enum.PartType.Ball
				made[1] = p
			elseif shape == "cone" then -- 4 wedges: back faces on the axis, slopes facing out, tip at +Y
				for k = 0, 3 do
					made[#made + 1] = v2Part("WedgePart", Vector3.new(sx, sy, sx / 2), cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -sx / 4), kit, L.glow, pc[13], film)
				end
			else
				made[1] = v2Part("Part", Vector3.new(math.max(0.02, sx), math.max(0.02, sy), math.max(0.02, sz)), cf, kit, L.glow, pc[13], film)
			end
			for _, p in ipairs(made) do
				p.Name = (pc[13] ~= "" and pc[13] or "Piece") .. "_" .. mt.anchor.Name
				p.Parent = m
				weldTo(p, (pc[14] ~= "" and roots[pc[14]]) or mt.anchor)
				n += 1
			end
		end
	end
	for i, b in ipairs(L.beams or {}) do
		local a0, a1 = find(model, b.a0), find(model, b.a1)
		if a0 and a1 then
			local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
			t0.Name, t1.Name = "ZPartBeamA_" .. i, "ZPartBeamB_" .. i
			t0.Position = Vector3.new(b.p0[1], b.p0[2], b.p0[3]) * sc
			t1.Position = Vector3.new(b.p1[1], b.p1[2], b.p1[3]) * sc
			t0.Parent, t1.Parent = a0, a1
			local beam = Instance.new("Beam")
			beam.Name = "ZPartBeam_" .. i
			beam.Attachment0, beam.Attachment1 = t0, t1
			beam.Color = ColorSequence.new(hex(D.KIT.rubber[1]))
			beam.Width0, beam.Width1 = b.width * sc, b.width * sc
			beam.FaceCamera = true
			beam.LightInfluence = 1
			beam.Segments = 1
			beam.Parent = m
			-- the attachments live on the body parts: remove them with the look
			m.Destroying:Connect(function() t0:Destroy() t1:Destroy() end)
		end
	end
	m:SetAttribute("ZPartId", id)
	m.Parent = model
	return m, n
end
local function builder()
	return (script:GetAttribute("TheriPartsLooksV2Enabled") ~= false and v2Data()) and buildV2 or buildPart
end

local function apply(char)
	if not char.Parent then return end
	local isT = enabled and char:GetAttribute("Species") == "Therizino"
	local built = {}
	for _, p in ipairs(PARTS) do
		local want = isT and char:GetAttribute(p.flag) == true and script:GetAttribute("TheriParts_" .. p.id .. "Enabled") ~= false
		local old = char:FindFirstChild("ZPart_" .. p.id)
		if want then
			if not old then
				local _, n = builder()(char, p.id) -- v1.1
				table.insert(built, p.id .. "=" .. n)
			else
				table.insert(built, p.id .. "=" .. #old:GetChildren())
			end
		elseif old then
			old:Destroy()
		end
	end
	char:SetAttribute("TheriPartsBuilt", table.concat(built, ","))
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
		return (builder()(model, p.id)) -- v1.1
	end
	fn.Parent = script
end
