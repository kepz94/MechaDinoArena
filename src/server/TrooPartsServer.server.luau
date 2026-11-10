-- TrooPartsServer v1.2 (Mecha Dino Arena) — puts the Troodon's mecha parts on (server-built, every client sees them) and builds
-- their Lab card models. Plan docs/plans/TROODON_PARTS_v1.0.md ticket 3 (MDA-347); the looks are Kepu's picks from
-- docs/mockups/troodon_parts_options.html v0.2 (Kepu 2026-11-06 21:24 "I like all the recommended"), exported piece by piece by
-- tools/mockup/export_troodon_parts.js into ServerStorage.DinoArcade.TrooPartsLooks 1.0 (src/shared/TrooPartsLooks.luau):
--   omender A "Shoulder Dock" (Torso, between the shoulder blades), olantern A "Hip Lantern" (LegL, back of the +X haunch),
--   osapwall B "Shoulder Pod" (Torso, +X side behind the shoulder), oshed A "Flank Plates" (Torso, both flanks), oportal A "Tail
--   Rings" (Tail2), olastfeather A "Tail-Base Cell" (Tail1), oplume A "Tail Plume" (Tail4), ofortify B "Neck Pylon" (Torso, behind
--   the neck), oricochet A "Spring Cups" (ArmL / ArmR hands).
-- Who: player characters with Species "Troodon". Each look is built while the character attribute <flag> is true (SkillEffects
--   1.48: bought AND slotted) and removed when it goes false: TrooPartMenderEnabled -> Model "OPart_omender",
--   TrooPartLanternEnabled, TrooPartSapEnabled, TrooPartShedEnabled, TrooPartPortalEnabled; build 2 (MDA-349, not written yet):
--   TrooPartLastFeatherEnabled, TrooPartPlumeEnabled, TrooPartFortifyEnabled, TrooPartRicochetEnabled.
-- Build: each piece's frame is relative to its segment's rest Root CFrame (TroodonModelData, scale 1); here its position x the
--   character's Model scale, at <seg>.Root.CFrame * frame. Shapes: box -> Part; cyl (radius r1 at +Y, r2 at -Y, length along Y)
--   -> a Part Cylinder turned to Y when r1 = r2, else CYL_SLICES (3) stacked cylinders, each at the radius of its middle (a cone
--   gets 4); sph -> Part Ball (uniform) or a Part with a SpecialMesh Sphere (the mockup's scaled spheres); tor (ring radius R,
--   tube r, arc, XY plane) -> blocks round the arc (TORUS_SEGMENTS 14 for a full ring). Static pieces: WeldConstraint to the
--   Root. Pieces with a role (carry / carry1 / carry2 / shed) or a mockup animation (spin / open / spring): a Weld "OPartJoint"
--   (Part0 = Root, C0 = the piece frame, C1 = the shape's own offset inverse; attribute OPartFrame) that TrooPartsFX moves
--   locally (a Weld, not a Motor6D, because IdleAnimation adopts every Motor6D). Marks (launch points / centres): Attachments
--   "OPartMark_<name>" on the segment Root. Massless, CanCollide / CanQuery / CanTouch false, CastShadow false for Neon /
--   Glass. Colours (the mockup's MAT / GLOWDEF): gun Metal #3a3f47, dark Metal #23262c, steel Metal #9aa1ac, brass Metal
--   #c8913a, plate SmoothPlastic #5d544a, rubber SmoothPlastic #17181b; glows Neon: amber #ffc35a, teal #8ff7e6, green
--   #8dffb6, volt #c8f8ff, white #ffffff; gold Metal #ffd772 (the plume feathers, lit by the FX); glassA Glass #ffc35a 0.18.
--   Pieces carry OPartRole, OPartAnim, OPartGlow (glow key, "" = none), OPartBaseColor, OPartIndex.
-- Fit (plan: <= 5% of any piece inside the body, all 9 together 0% part-vs-part): the mockup seated every piece on the body
--   surface by ray casts against the rest-pose body boxes (worst 3.2%, mockup v0.2); FIT[id] (a shift for the whole part in
--   rest model space, scale 1, turned into each segment's rest frame) is the Studio-measured correction layer, switch
--   TrooPartsFitEnabled (default true, read at each build). Measured in Play (client, the live troodon at scale 2, idle /
--   walk / throw / flaps + glide, 125 samples per piece against the visible body boxes and the other parts' shapes): every
--   piece 0% in the body except Ricochet's hand cups (the hands swing through the shins in the walk; build 2), brackets
--   40-48% (set into the surface by design); the one clash was the Hip Lantern's hook arm touching the rear Flank Plate in
--   the idle sway (4%): FIT.olantern = 0.08 down -> 0%.
-- Lab cards: BindableFunction "BuildPreview_<id>" under this script for each part (LabPreviewServer 1.2 plug-and-play; the
--   mannequin is the troodon's, ST.PATHS[id].dino).
-- Switches: script attribute TrooPartsServerEnabled (default true, read at start; false = no looks); per part
--   TrooParts_<id>Enabled (default true, read on each apply). Diagnostics: script TrooPartsServerVersion, TrooPartsLooksVersion,
--   TrooPartsSegRoots (segment roots loaded); character TrooPartsBuilt ("<id>=<pieces>,...").
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 Studio fit tryout attribute
VERSION = "1.2" -- v1.2 the troodon slot parts' looks (TrooSlotLooks 1.0)
-- v1.2 (troodon slot parts, plan docs/plans/TROODON_SLOTPARTS_v1.0.md T3, MDA-380): ServerStorage.DinoArcade.TrooSlotLooks 1.0
--   (generated from docs/mockups/troodon_slotparts_v0.1.html) joins LOOKS, and PARTS gains obloom (TrooPartBloomEnabled: the
--   passive, on when bought), oburst (TrooPartBurstEnabled), odome (TrooPartDomeEnabled), osleep (TrooPartSleepEnabled),
--   osentry (TrooPartSentryEnabled) (SkillEffects 1.58 flags), each with TrooParts_<id>Enabled and its Lab card
--   (BuildPreview_<id>, the same loop). MAT gains blue (6CC4FF neon), violet (B88CFF neon) and glassT (the Bloom Tank's glass,
--   9FF6E8, transparency 0.45). Switch: script attribute TrooPartsSlotLooksEnabled (default true, read at start; false = 1.1).
-- v1.1 (MDA-349, build 2 fit of Ricochet's Spring Cups): in Studio only (RunService:IsStudio()), a script attribute
--   TrooPartsFitTry_<id> (Vector3, rest model space, scale 1) replaces FIT[id] at the next build of that part (toggle its
--   TrooPart<Name>Enabled), so fit shifts can be measured in one Play session; ignored on a live server. Must be unset at
--   publish (the found value goes into FIT). Also per segment: TrooPartsFitTry_<id>_<seg> (Vector3) for that segment's pieces
--   only, and the baked table FITSEG[id][seg] (added to FIT[id]): a mirrored left / right shift (Ricochet's two hand cups).
local RunService = game:GetService("RunService")
local FITSEG = {} -- v1.1: {[id] = {[segment] = Vector3}}, rest model space, scale 1
local CYL_SLICES = 3
local TORUS_SEGMENTS = 14
local function hex(h) return Color3.fromRGB(math.floor(h / 65536) % 256, math.floor(h / 256) % 256, h % 256) end
local MAT = {
	gun = {hex(0x3a3f47), Enum.Material.Metal}, dark = {hex(0x23262c), Enum.Material.Metal},
	steel = {hex(0x9aa1ac), Enum.Material.Metal}, brass = {hex(0xc8913a), Enum.Material.Metal},
	plate = {hex(0x5d544a), Enum.Material.SmoothPlastic}, rubber = {hex(0x17181b), Enum.Material.SmoothPlastic},
	amber = {hex(0xffc35a), Enum.Material.Neon}, teal = {hex(0x8ff7e6), Enum.Material.Neon},
	green = {hex(0x8dffb6), Enum.Material.Neon}, volt = {hex(0xc8f8ff), Enum.Material.Neon},
	white = {hex(0xffffff), Enum.Material.Neon}, gold = {hex(0xffd772), Enum.Material.Metal},
	glassA = {hex(0xffc35a), Enum.Material.Glass, 0.18},
}
MAT.blue, MAT.violet = {hex(0x6cc4ff), Enum.Material.Neon}, {hex(0xb88cff), Enum.Material.Neon} -- v1.2
MAT.glassT = {hex(0x9ff6e8), Enum.Material.Glass, 0.45} -- v1.2
local PARTS = {
	{id = "omender", flag = "TrooPartMenderEnabled"}, {id = "olantern", flag = "TrooPartLanternEnabled"},
	{id = "osapwall", flag = "TrooPartSapEnabled"}, {id = "oshed", flag = "TrooPartShedEnabled"},
	{id = "oportal", flag = "TrooPartPortalEnabled"},
	{id = "olastfeather", flag = "TrooPartLastFeatherEnabled"}, {id = "oplume", flag = "TrooPartPlumeEnabled"},
	{id = "ofortify", flag = "TrooPartFortifyEnabled"}, {id = "oricochet", flag = "TrooPartRicochetEnabled"},
}
-- the Studio-measured fit layer: {[id] = Vector3 shift for the whole part, rest model space, scale 1}
local FIT = {olantern = Vector3.new(0, -0.08, 0)}

script:SetAttribute("TrooPartsServerVersion", VERSION)
if script:GetAttribute("TrooPartsServerEnabled") == nil then script:SetAttribute("TrooPartsServerEnabled", true) end
if script:GetAttribute("TrooPartsFitEnabled") == nil then script:SetAttribute("TrooPartsFitEnabled", true) end
local enabled = script:GetAttribute("TrooPartsServerEnabled") ~= false
for _, p in ipairs(PARTS) do
	if script:GetAttribute("TrooParts_" .. p.id .. "Enabled") == nil then script:SetAttribute("TrooParts_" .. p.id .. "Enabled", true) end
end

local LOOKS = {}
do
	local ok, data = pcall(function()
		local arc = ServerStorage:WaitForChild("DinoArcade", 10)
		local m = arc and arc:WaitForChild("TrooPartsLooks", 10)
		return m and require(m)
	end)
	if ok and type(data) == "table" and type(data.LOOKS) == "table" then
		LOOKS = data.LOOKS
		script:SetAttribute("TrooPartsLooksVersion", tostring(data.Version))
	else
		script:SetAttribute("TrooPartsLooksVersion", "missing")
		warn("TrooPartsServer: TrooPartsLooks not loaded: " .. tostring(data))
	end
end
-- v1.2: the troodon slot parts' looks
if script:GetAttribute("TrooPartsSlotLooksEnabled") == nil then script:SetAttribute("TrooPartsSlotLooksEnabled", true) end
if script:GetAttribute("TrooPartsSlotLooksEnabled") ~= false then
	local ok, data = pcall(function()
		local m = ServerStorage:WaitForChild("DinoArcade", 10):WaitForChild("TrooSlotLooks", 10)
		return m and require(m)
	end)
	if ok and type(data) == "table" and type(data.LOOKS) == "table" then
		for id, lk in pairs(data.LOOKS) do LOOKS[id] = lk end
		for _, p in ipairs({{id = "obloom", flag = "TrooPartBloomEnabled"}, {id = "oburst", flag = "TrooPartBurstEnabled"},
			{id = "odome", flag = "TrooPartDomeEnabled"}, {id = "osleep", flag = "TrooPartSleepEnabled"},
			{id = "osentry", flag = "TrooPartSentryEnabled"}}) do
			table.insert(PARTS, p)
			if script:GetAttribute("TrooParts_" .. p.id .. "Enabled") == nil then script:SetAttribute("TrooParts_" .. p.id .. "Enabled", true) end
		end
		script:SetAttribute("TrooSlotLooksVersion", tostring(data.Version))
	else
		script:SetAttribute("TrooSlotLooksVersion", "missing")
		warn("TrooPartsServer: TrooSlotLooks not loaded: " .. tostring(data))
	end
end
-- the segment roots' rest CFrames (TroodonModelData, scale 1): the fit layer's model-space shift is turned into them
local SEG = {}
do
	local n = 0
	pcall(function()
		local data = require(ServerStorage.DinoArcade.Models.TroodonModelData)
		for _, seg in ipairs(data.segments or {}) do
			if type(seg.root) == "table" and #seg.root == 12 then SEG[seg.name] = CFrame.new(table.unpack(seg.root)); n += 1 end
		end
	end)
	script:SetAttribute("TrooPartsSegRoots", n)
end

local function segRoot(model, seg)
	local s = model:FindFirstChild(seg)
	local r = s and s:FindFirstChild("Root")
	return r and r:IsA("BasePart") and r or nil
end
local function newPart(m, matKey, size, cf)
	local mt = MAT[matKey] or MAT.gun
	local p = Instance.new("Part")
	p.Size = Vector3.new(math.max(0.02, size.X), math.max(0.02, size.Y), math.max(0.02, size.Z))
	p.Color, p.Material = mt[1], mt[2]
	p.Transparency = mt[3] or 0
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = mt[2] ~= Enum.Material.Neon and mt[2] ~= Enum.Material.Glass
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CFrame = cf
	p:SetAttribute("OPartBaseColor", p.Color)
	p.Parent = m
	return p
end
-- a piece as {kind ("Block" | "Cyl" | "Ball" | "Ellipsoid"), size, shape-local frame} entries, scale sc
local TURN_Y = CFrame.Angles(0, 0, math.rad(90)) -- a Roblox cylinder's axis X onto Y
-- a flat TrooPartsLooks row -> a piece table
local function row(r)
	return {seg = r[1], t = r[2], d = {r[3], r[4], r[5], r[6]}, cf = {table.unpack(r, 7, 18)}, s = {r[19], r[20], r[21]},
		mat = r[22], glow = r[23] == 1, role = r[24] or "", anim = r[25] or ""}
end
local function shapes(pc, sc)
	local d, out = pc.d, {}
	if pc.t == "box" then
		out[1] = {"Block", Vector3.new(d[1], d[2], d[3]) * sc, CFrame.identity}
	elseif pc.t == "cyl" then
		local r1, r2, h = d[1], d[2], d[3]
		if math.abs(r1 - r2) <= 0.01 then
			local r = math.max(r1, r2)
			out[1] = {"Cyl", Vector3.new(h, r * 2, r * 2) * sc, TURN_Y}
		else
			local n = (math.min(r1, r2) < 0.3 * math.max(r1, r2)) and 4 or CYL_SLICES
			for i = 1, n do
				local y = (-0.5 + (i - 0.5) / n) * h -- slice centre along Y
				local r = r2 + (r1 - r2) * (y / h + 0.5)
				out[#out + 1] = {"Cyl", Vector3.new(h / n * 1.02, math.max(0.02, r * 2), math.max(0.02, r * 2)) * sc, CFrame.new(0, y * sc, 0) * TURN_Y}
			end
		end
	elseif pc.t == "sph" then
		local s = pc.s or {1, 1, 1}
		local size = Vector3.new(s[1], s[2], s[3]) * d[1] * 2 * sc
		local uniform = math.abs(s[1] - s[2]) < 1e-3 and math.abs(s[2] - s[3]) < 1e-3
		out[1] = {uniform and "Ball" or "Ellipsoid", size, CFrame.identity}
	elseif pc.t == "tor" then
		local R, r, arc = d[1] * sc, d[2] * sc, d[3]
		local n = math.max(4, math.ceil(TORUS_SEGMENTS * arc / (2 * math.pi)))
		local segLen = 2 * R * math.sin(arc / n / 2) * 1.08
		for k = 0, n - 1 do
			local a = (k + 0.5) / n * arc
			out[#out + 1] = {"Block", Vector3.new(r * 2, segLen, r * 2), CFrame.Angles(0, 0, a) * CFrame.new(R, 0, 0)}
		end
	end
	return out
end
local function fitShift(id, seg)
	if script:GetAttribute("TrooPartsFitEnabled") == false then return Vector3.zero end
	if RunService:IsStudio() then -- v1.1: the Studio tryout
		local trySeg = script:GetAttribute("TrooPartsFitTry_" .. id .. "_" .. tostring(seg))
		if typeof(trySeg) == "Vector3" then return SEG[seg] and SEG[seg]:VectorToObjectSpace(trySeg) or Vector3.zero end
		local try = script:GetAttribute("TrooPartsFitTry_" .. id)
		if typeof(try) == "Vector3" then return SEG[seg] and SEG[seg]:VectorToObjectSpace(try) or Vector3.zero end
	end
	local fs = FITSEG[id] and FITSEG[id][seg]
	if fs and SEG[seg] then return SEG[seg]:VectorToObjectSpace(fs + (FIT[id] or Vector3.zero)) end
	local f, rest = FIT[id], SEG[seg]
	if not f or not rest then return Vector3.zero end
	return rest:VectorToObjectSpace(f)
end
local function buildPart(model, id)
	local look = LOOKS[id]
	if not look then return nil, 0 end
	local sc = model:GetScale()
	local m = Instance.new("Model")
	m.Name = "OPart_" .. id
	local n = 0
	for i, r in ipairs(look.pieces) do
		local pc = row(r)
		local root = segRoot(model, pc.seg)
		if root then
			local c = pc.cf
			local frame = CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]):Orthonormalize()
			local pos = (frame.Position + fitShift(id, pc.seg)) * sc
			frame = CFrame.new(pos) * frame.Rotation
			local moving = pc.role ~= "" and pc.role ~= "bracket" or pc.anim ~= ""
			for _, sh in ipairs(shapes(pc, sc)) do
				local kind, size, inner = sh[1], sh[2], sh[3]
				local p = newPart(m, pc.mat, size, root.CFrame * frame * inner)
				if kind == "Cyl" then
					p.Shape = Enum.PartType.Cylinder
				elseif kind == "Ball" then
					p.Shape = Enum.PartType.Ball
				elseif kind == "Ellipsoid" then
					local mesh = Instance.new("SpecialMesh")
					mesh.MeshType = Enum.MeshType.Sphere
					mesh.Parent = p
				end
				p.Name = (pc.role ~= "" and pc.role or (pc.anim ~= "" and pc.anim or "Piece")) .. "_" .. pc.seg
				p:SetAttribute("OPartRole", pc.role)
				p:SetAttribute("OPartAnim", pc.anim)
				p:SetAttribute("OPartGlow", pc.glow and pc.mat or "")
				p:SetAttribute("OPartIndex", i)
				if moving then
					local w = Instance.new("Weld")
					w.Name = "OPartJoint"
					w.Part0, w.Part1 = root, p
					w.C0 = frame
					w.C1 = inner:Inverse()
					w:SetAttribute("OPartFrame", frame)
					w:SetAttribute("OPartBuiltScale", sc)
					w.Parent = p
				else
					local w = Instance.new("WeldConstraint")
					w.Part0, w.Part1 = root, p
					w.Parent = p
				end
				n += 1
			end
		end
	end
	for _, mk in ipairs(look.marks or {}) do
		local root = segRoot(model, mk[2])
		if root then
			local a = Instance.new("Attachment")
			a.Name = "OPartMark_" .. mk[1]
			a.Position = (Vector3.new(mk[3], mk[4], mk[5]) + fitShift(id, mk[2])) * sc
			a:SetAttribute("OPartId", id)
			a.Parent = root
			m.Destroying:Connect(function() a:Destroy() end)
		end
	end
	m:SetAttribute("OPartId", id)
	m.Parent = model
	return m, n
end

local function apply(char)
	if not char.Parent then return end
	local isT = enabled and char:GetAttribute("Species") == "Troodon"
	local built = {}
	for _, p in ipairs(PARTS) do
		local want = isT and char:GetAttribute(p.flag) == true and script:GetAttribute("TrooParts_" .. p.id .. "Enabled") ~= false
		local old = char:FindFirstChild("OPart_" .. p.id)
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
	char:SetAttribute("TrooPartsBuilt", table.concat(built, ","))
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
for _, p in ipairs(PARTS) do
	script:GetAttributeChangedSignal("TrooParts_" .. p.id .. "Enabled"):Connect(function()
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then apply(pl.Character) end end
	end)
end

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
