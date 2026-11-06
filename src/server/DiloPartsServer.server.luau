-- DiloPartsServer v1.0 (Mecha Dino Arena) — puts the Dilophosaurus' mecha parts on (server-built, every client sees them) and
-- builds their Lab card models. Plan docs/plans/DILO_PARTS_v1.0.md Task 3 (MDA-316); the looks are Kepu's picks from
-- docs/mockups/dilo_parts_options.html v0.1 (tools/mockup/dilo_parts_looks.js, same numbers; Kepu 2026-11-06 01:20 "All
-- recommended except Venom Gatling - C, Toxin Mortar - C"):
--   dgatling C "Twin Hood Repeaters" (Neck, both sides), dmortar C "Chest Launcher" (Torso: tank under the chest, tube on the
--   +X neck base), dhiss A "Hood Speakers" (6 cones on the frill + an amp pack on the +X neck), dspine C "Frill Barbs" (12 rim
--   barbs + 2 neck magazines), dpump A "Back Pump" (Torso back), djets C "Tail Booster" (Tail1 top), dover A "Venom Reactor"
--   (chest core + back fins).
-- Who: player characters with Species "Dilo". Each look is built while the character attribute <Prefix>Enabled is true
--   (SkillEffects 1.45: bought AND slotted) and removed when it goes false: DiloPartGatlingEnabled -> Model "DPart_dgatling",
--   DiloPartMortarEnabled, DiloPartHissEnabled, DiloPartSpineEnabled, DiloPartPumpEnabled, DiloPartJetsEnabled,
--   DiloPartOverEnabled (Model "DPart_<id>").
-- Build: the mockup gives each piece in the rest model space (DiloModelData: CFrames relative to the HumanoidRootPart, scale 1)
--   on a segment (Neck / Torso / Tail1 / Head / Jaw ...). Here: pivot = segRoot^-1 * CFrame.new(pos) * Angles(rx, ry, rz)
--   (the mockup's three.js Euler XYZ, degrees), its position x the character's Model scale; the piece sits at
--   <seg>.Root.CFrame * pivot * anim(rest) * geometry offset * shape turn. Shapes: box -> Part; cylZ / cylY / cylX (the
--   mockup's cylinder axis Z / Y / X; radius the larger end) -> Part Cylinder turned to that axis; sph -> Part Ball; torus
--   (three.js TorusGeometry in its XY plane) -> TORUS_SEGMENTS (12) blocks; cone (axis Y, tip +Y) -> 4 WedgeParts as a
--   pyramid. Static pieces: WeldConstraint to the Root. Moving pieces (attribute DPartAnim: "recoil", "mortar", "extend",
--   "pump", "fins"): a Weld "DPartJoint" (Part0 = Root, C0 = pivot x anim(rest), C1 = the geometry offset inverse; attribute
--   DPartPivot = the pivot) that DiloMovesFX 1.0 moves locally (a Weld, not a Motor6D, because IdleAnimation adopts every
--   Motor6D). Pieces on the hood are welded to the frill part they ride (its rest CFrame from the model data) and carry
--   DPartFrill = that part's name, so they follow DiloPose's local hood pop; DiloMovesFX 1.0 shows them only while that
--   frill part shows (the hood is local per client). Muzzles: Attachments "DPartMuzzle_<n>" on the Root (rest).
--   Massless, CanCollide / CanQuery / CanTouch false, CastShadow false for Neon / Glass. Colours (the mockup's MAT): gun Metal
--   #3b4049, dark Metal #22252c, steel Metal #9aa1ac, yellow SmoothPlastic #ffc21a, copper Metal #c8843e, rubber SmoothPlastic
--   #16171a, lit / green Neon #9cf05a, glassG Glass #9cf05a, glassB Glass #8fd8ff, purple Neon #b8a6ff. Pieces carry
--   DPartRole (for DiloMovesFX) and DPartBaseColor.
-- Lab cards: BindableFunction "BuildPreview_<id>" under this script for each part (LabPreviewServer 1.2 plug-and-play; the
--   mannequin is the dilo's, ST.PATHS[id].dino).
-- Switches: script attribute DiloPartsServerEnabled (default true, read at start; false = no looks); per part
--   DiloParts_<id>Enabled (default true, read on each apply). Diagnostics: script DiloPartsServerVersion, DiloPartsSegRoots
--   (segment roots loaded); character DiloPartsBuilt ("<id>=<pieces>,...").
-- v1.1 (MDA-328, plan docs/plans/DILO_PARTS_FIT_v1.0.md Task 1; Kepu 2026-11-06 12:22 "parts of it that are sinking into the
--   body and it just looks sloppy" -> "Yes, reseat + screenshots"): seat layer. Measured in Studio (each part built by its
--   BuildPreview on a still Dilo, 125 points per piece, share of the part's volume inside visible body parts): Jets 50%,
--   Overdrive 42%, Mortar 24%, Hiss 20%, Spine 10%, Gatling 6%, Pump 0%. With the seat layer on, each part's pieces move as
--   rigid groups out to the body surface (SEAT: a shift per group in rest model space, scale 1; frill-riding pieces lift
--   along their frill plate's face normal), and dark mount brackets (role "bracket") are added where a part meets the
--   body. Same picked looks, sizes and colours; moving pieces keep their joints (the pivot moves with the group); muzzles move
--   with their group. Switch: script attribute DiloPartsSeatV2Enabled (default true, read at each build; false = the 1.0
--   seats, no brackets).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 seat layer (parts on the body surface + mount brackets)
if script:GetAttribute("DiloPartsSeatV2Enabled") == nil then script:SetAttribute("DiloPartsSeatV2Enabled", true) end -- v1.1
local TORUS_SEGMENTS = 12
local function hex(h) return Color3.fromRGB(math.floor(h / 65536) % 256, math.floor(h / 256) % 256, h % 256) end
local MAT = {
	gun = {hex(0x3b4049), Enum.Material.Metal}, dark = {hex(0x22252c), Enum.Material.Metal},
	steel = {hex(0x9aa1ac), Enum.Material.Metal}, yellow = {hex(0xffc21a), Enum.Material.SmoothPlastic},
	copper = {hex(0xc8843e), Enum.Material.Metal}, rubber = {hex(0x16171a), Enum.Material.SmoothPlastic},
	lit = {hex(0x9cf05a), Enum.Material.Neon}, green = {hex(0x8fe04a), Enum.Material.Neon},
	glassG = {hex(0x9cf05a), Enum.Material.Glass, 0.15}, glassB = {hex(0x8fd8ff), Enum.Material.Glass, 0.15},
	purple = {hex(0xb8a6ff), Enum.Material.Neon},
}
local PARTS = {
	{id = "dgatling", flag = "DiloPartGatlingEnabled"}, {id = "dmortar", flag = "DiloPartMortarEnabled"},
	{id = "dhiss", flag = "DiloPartHissEnabled"}, {id = "dspine", flag = "DiloPartSpineEnabled"},
	{id = "dpump", flag = "DiloPartPumpEnabled"}, {id = "djets", flag = "DiloPartJetsEnabled"},
	{id = "dover", flag = "DiloPartOverEnabled"},
}

script:SetAttribute("DiloPartsServerVersion", VERSION)
if script:GetAttribute("DiloPartsServerEnabled") == nil then script:SetAttribute("DiloPartsServerEnabled", true) end
local enabled = script:GetAttribute("DiloPartsServerEnabled") ~= false
for _, p in ipairs(PARTS) do
	if script:GetAttribute("DiloParts_" .. p.id .. "Enabled") == nil then script:SetAttribute("DiloParts_" .. p.id .. "Enabled", true) end
end

-- segment roots and part rest CFrames (scale 1, relative to the HumanoidRootPart) from DiloModelData
local SEG, PART = {}, {}
do
	local ok, data = pcall(function()
		local arc = ServerStorage:WaitForChild("DinoArcade", 10)
		local models = arc and arc:WaitForChild("Models", 10)
		local m = models and models:WaitForChild("DiloModelData", 10)
		return m and require(m)
	end)
	local n = 0
	if ok and type(data) == "table" then
		for _, seg in ipairs(data.segments or {}) do
			if type(seg.root) == "table" and #seg.root == 12 then
				SEG[seg.name] = CFrame.new(table.unpack(seg.root))
				n += 1
			end
			for _, p in ipairs(seg.parts or {}) do
				if type(p.cf) == "table" and #p.cf == 12 then PART[p.name] = CFrame.new(table.unpack(p.cf)) end
			end
		end
	end
	script:SetAttribute("DiloPartsSegRoots", n)
end
local function fp(name) -- a frill part's rest position (the mockup's FRILL_B(n))
	local cf = PART[name]
	return cf and cf.Position or Vector3.zero
end

-- ---------- pieces (the mockup's numbers) ----------
-- {seg, shape, dims, mat, {pos}, {rot deg}, opts}; opts: go = geometry offset {x, y, z}, anim = kind, frill = part name,
-- role = string, muzzle = true (an attachment instead of a piece)
local P = {}
local function add(list, seg, shape, dims, mat, pos, rot, o) table.insert(list, {seg, shape, dims, mat, pos, rot or {0, 0, 0}, o or {}}) end
P.dgatling = function()
	local L = {}
	for _, s in ipairs({1, -1}) do
		add(L, "Neck", "box", {0.3, 0.32, 0.72}, "gun", {0.6 * s, 1.85, -2.55}, nil, {role = "body"})
		add(L, "Neck", "box", {0.31, 0.07, 0.5}, "yellow", {0.6 * s, 2.03, -2.5})
		add(L, "Neck", "cylZ", {0.09, 1.15}, "steel", {0.6 * s, 1.85, -3.4}, nil, {anim = "recoil", role = "barrel"})
		add(L, "Neck", "cylZ", {0.14, 0.18}, "dark", {0.6 * s, 1.85, -3.9}, nil, {anim = "recoil", role = "barrel"})
		add(L, "Neck", "cylX", {0.24, 0.18}, "lit", {0.8 * s, 1.75, -2.3}, nil, {role = "drum"})
		add(L, "Neck", "muzzle", {}, nil, {0.6 * s, 1.85, -4.05})
	end
	return L
end
P.dmortar = function()
	local L = {}
	add(L, "Torso", "cylX", {0.34, 0.7}, "gun", {0, -0.6, -1.5}, nil, {role = "tank"})
	add(L, "Torso", "cylX", {0.26, 0.74}, "glassG", {0, -0.6, -1.5}, nil, {role = "fluid"})
	add(L, "Torso", "box", {0.76, 0.1, 0.16}, "dark", {0, -0.6, -1.5})
	add(L, "Torso", "box", {0.36, 0.3, 0.42}, "dark", {0.78, 0.9, -1.75})
	add(L, "Torso", "cylY", {0.2, 0.95}, "gun", {0.8, 1.0, -1.75}, {0, 0, -14}, {go = {0, 0.47, 0}, anim = "mortar", role = "tube"})
	add(L, "Torso", "cylY", {0.22, 0.1}, "yellow", {0.8, 1.0, -1.75}, {0, 0, -14}, {go = {0, 0.8, 0}, anim = "mortar", role = "tube"})
	add(L, "Torso", "box", {0.08, 0.08, 0.6}, "copper", {0.5, 0.2, -1.6}, {30, 0, 0})
	-- the muzzle at rest: pivot x rotX(-20) x (0, 1.0, 0)
	local mz = CFrame.new(0.8, 1.0, -1.75) * CFrame.Angles(0, 0, math.rad(-14)) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 1.0, 0)
	add(L, "Torso", "muzzle", {}, nil, {mz.X, mz.Y, mz.Z})
	return L
end
P.dhiss = function()
	local L = {}
	for _, n in ipairs({"L2b", "L4b", "L6b", "R2b", "R4b", "R6b"}) do
		local name = "Neck_frill" .. n
		local c = fp(name)
		add(L, "Neck", "cylZ", {0.27, 0.08}, "dark", {c.X, c.Y, c.Z - 0.07}, nil, {frill = name, role = "speaker"})
		add(L, "Neck", "cylZ", {0.2, 0.14}, "purple", {c.X, c.Y, c.Z - 0.14}, nil, {frill = name, role = "cone"})
		add(L, "Neck", "torus", {0.27, 0.035}, "steel", {c.X, c.Y, c.Z - 0.12}, nil, {frill = name, role = "speaker"})
	end
	add(L, "Neck", "box", {0.22, 0.6, 0.5}, "gun", {0.5, 1.6, -2.3}, nil, {role = "amp"})
	add(L, "Neck", "box", {0.23, 0.07, 0.5}, "yellow", {0.5, 1.94, -2.3})
	for j = 0, 2 do add(L, "Neck", "box", {0.235, 0.05, 0.36}, "purple", {0.5, 1.45 + j * 0.13, -2.3}, nil, {role = "meter"}) end
	add(L, "Neck", "box", {0.06, 0.06, 0.4}, "rubber", {0.42, 2.05, -2.45}, {-50, 0, 0})
	return L
end
P.dspine = function()
	local L = {}
	for _, sd in ipairs({"L", "R"}) do
		for i = 1, 6 do
			local name = "Neck_frill" .. sd .. "rim" .. i
			local c = fp(name)
			local ang = math.atan2(c.Y - 2.65, c.X)
			add(L, "Neck", "cone", {0.08, 0.5}, "green", {c.X, c.Y, c.Z - 0.02}, {0, 0, math.deg(ang) - 90},
				{go = {0, 0.25, 0}, anim = "extend", frill = name, role = "barb"})
		end
	end
	for _, s in ipairs({1, -1}) do
		add(L, "Neck", "box", {0.18, 0.5, 0.34}, "gun", {0.52 * s, 1.55, -2.35}, nil, {role = "magazine"})
		add(L, "Neck", "box", {0.19, 0.08, 0.35}, "yellow", {0.52 * s, 1.84, -2.35})
		for j = 0, 2 do add(L, "Neck", "cone", {0.05, 0.22}, "green", {0.52 * s, 1.92, -2.45 + j * 0.1}, nil, {role = "spare"}) end
	end
	return L
end
P.dpump = function()
	local L = {}
	add(L, "Torso", "box", {0.6, 0.12, 1.1}, "dark", {0, 1.1, 0.35})
	add(L, "Torso", "cylZ", {0.3, 0.95}, "gun", {0, 1.42, 0.35}, nil, {role = "tank"})
	add(L, "Torso", "cylZ", {0.25, 0.97}, "glassB", {0, 1.42, 0.35}, nil, {role = "fluid"})
	for _, z in ipairs({-0.05, 0.75}) do add(L, "Torso", "torus", {0.3, 0.04}, "yellow", {0, 1.42, z}) end
	add(L, "Torso", "cylY", {0.07, 0.5}, "steel", {0, 1.72, 0.35}, nil, {anim = "pump", role = "piston"})
	add(L, "Torso", "box", {0.32, 0.08, 0.14}, "dark", {0, 1.98, 0.35}, nil, {anim = "pump", role = "piston"})
	for _, s in ipairs({1, -1}) do add(L, "Torso", "box", {0.08, 0.08, 0.95}, "rubber", {0.2 * s, 1.24, -0.6}, {-12, 0, 0}) end
	return L
end
P.djets = function()
	local L = {}
	add(L, "Tail1", "cylZ", {0.3, 1.5}, "gun", {0, 0.82, 1.75}, nil, {role = "body"})
	add(L, "Tail1", "cylZ", {0.31, 0.16}, "yellow", {0, 0.82, 1.3})
	add(L, "Tail1", "cylZ", {0.34, 0.4}, "dark", {0, 0.82, 2.65}, nil, {role = "nozzle"})
	for _, r in ipairs({0, 90, 270}) do add(L, "Tail1", "box", {0.04, 0.34, 0.4}, "gun", {0, 0.82, 2.25}, {0, 0, r}, {go = {0, 0.42, 0}}) end
	add(L, "Tail1", "box", {0.2, 0.18, 0.5}, "dark", {0, 0.55, 1.6})
	for i = 0, 2 do add(L, "Tail1", "box", {0.04, 0.09, 0.14}, "lit", {0.31, 0.82, 1.55 + i * 0.2}, nil, {role = "pip" .. (i + 1)}) end
	add(L, "Tail1", "muzzle", {}, nil, {0, 0.82, 2.95})
	return L
end
P.dover = function()
	local L = {}
	add(L, "Torso", "cylZ", {0.4, 0.14}, "gun", {0, 0.45, -2.2})
	add(L, "Torso", "sph", {0.27}, "lit", {0, 0.45, -2.27}, nil, {role = "core"})
	add(L, "Torso", "torus", {0.36, 0.05}, "yellow", {0, 0.45, -2.3})
	for i = 0, 3 do add(L, "Torso", "box", {0.06, 0.06, 0.4}, "steel", {0, 0.45, -2.31}, {0, 0, 45 + i * 90}) end
	for i = 0, 3 do add(L, "Torso", "box", {0.5, 0.26, 0.06}, "gun", {0, 1.18, -1.55 + i * 0.2}, nil, {anim = "fins", role = "fin"}) end
	return L
end

-- ---------- v1.1 seat layer ----------
-- SEAT[id] = {group = function(piece) -> key, groups = {[key] = {move = Vector3 (rest model space, scale 1), tilt = {axis
--   Vector3, degrees, centre Vector3} | nil}}, lift = studs along the frill plate's face normal for frill-riding pieces,
--   extra = function() -> bracket pieces (P format; opts.grp = the group they move with, or "fixed")}. Order per piece:
--   tilt about its centre, then move. Numbers tuned in Studio with the plan's measurement (see the plan's build notes).
local SEAT = {}
local function sgn(v) return v >= 0 and 1 or -1 end
local CHEST_N = Vector3.new(0, 0.407, -0.914) -- the chest front face normal (DiloModelData Torso_chest)
local CHEST_DOWN = Vector3.new(0, -0.914, -0.407) -- down along that face (below Neck_1, which the 1.0 core cut into)
SEAT.dgatling = {
	group = function(pc) return pc[5][1] >= 0 and "L" or "R" end,
	-- 6 degrees muzzle-up about the gun body, 0.17 out, 0.13 back: the barrels clear Jaw_lower when the head comes back in
	-- the A_WIND / HISS_WIND keys and when it turns (p_mortar / p_hiss / p_spine / p_gatling poses; Play measure)
	groups = {L = {tilt = {Vector3.new(1, 0, 0), 6, Vector3.new(0.6, 1.85, -2.55)}, move = Vector3.new(0.17, 0, 0.13)},
		R = {tilt = {Vector3.new(1, 0, 0), 6, Vector3.new(-0.6, 1.85, -2.55)}, move = Vector3.new(-0.17, 0, 0.13)}},
	extra = function()
		local L = {}
		for _, s in ipairs({1, -1}) do
			add(L, "Neck", "box", {0.29, 0.26, 0.5}, "dark", {0.535 * s, 1.85, -2.37}, nil, {role = "bracket", grp = "fixed"})
		end
		return L
	end}
SEAT.dmortar = {
	group = function(pc) return pc[5][2] < 0 and "tank" or "tube" end,
	groups = {tank = {move = Vector3.new(0, -0.3, 0)}, tube = {move = Vector3.new(0.25, 0, 0)}},
	extra = function()
		local L = {}
		for _, x in ipairs({-0.22, 0.22}) do add(L, "Torso", "box", {0.1, 0.6, 0.5}, "dark", {x, -0.57, -1.5}, nil, {role = "bracket", grp = "fixed"}) end
		add(L, "Torso", "box", {0.35, 0.34, 0.46}, "dark", {0.705, 0.9, -1.75}, nil, {role = "bracket", grp = "fixed"})
		return L
	end}
SEAT.dhiss = {lift = 0.16,
	group = function() return "amp" end,
	groups = {amp = {move = Vector3.new(0.15, 0.2, 0.5)}}, -- back to the neck base: clear of the gatling, spine and mortar;
	-- y 0.2 (was 0.1): clear of Torso_chest in the p_mortar pose (Play measure)
	extra = function()
		local L = {}
		add(L, "Neck", "box", {0.32, 0.5, 0.4}, "dark", {0.41, 1.8, -1.8}, nil, {role = "bracket", grp = "fixed"})
		return L
	end}
SEAT.dspine = {lift = 0.12,
	group = function(pc) return pc[5][1] >= 0 and "L" or "R" end,
	-- lower: clear of the gatling; x 0.15 (was 0.1): clear of Jaw_lower in the p_mortar pose (Play measure)
	groups = {L = {move = Vector3.new(0.15, -0.4, 0.1)}, R = {move = Vector3.new(-0.15, -0.4, 0.1)}},
	extra = function()
		local L = {}
		for _, s in ipairs({1, -1}) do add(L, "Neck", "box", {0.28, 0.42, 0.3}, "dark", {0.47 * s, 1.15, -2.25}, nil, {role = "bracket", grp = "fixed"}) end
		return L
	end}
SEAT.djets = {
	group = function() return "booster" end,
	groups = {booster = {move = Vector3.new(0, 0.4, 0)}},
	extra = function()
		local L = {}
		for _, z in ipairs({1.45, 2.05}) do add(L, "Tail1", "box", {0.34, 0.62, 0.16}, "dark", {0, 0.72, z}, nil, {role = "bracket", grp = "fixed"}) end
		return L
	end}
SEAT.dover = {
	group = function(pc) return pc[5][3] < -2 and "core" or "fins" end,
	groups = {core = {tilt = {Vector3.new(1, 0, 0), 24, Vector3.new(0, 0.45, -2.2)}, move = CHEST_N * 0.1 + CHEST_DOWN * 0.45}, -- 0.45 (was 0.35): clear of Neck_1 in p_jets
		fins = {move = Vector3.new(0, 0.4, 0.5)}}, -- z 0.5: clear of Jaw_sac / Neck_1 in the p_over / p_pump poses (Play measure)
	extra = function()
		local L = {}
		add(L, "Torso", "box", {0.16, 0.54, 0.8}, "dark", {0, 1.25, -0.8}, nil, {role = "bracket", grp = "fixed"})
		add(L, "Torso", "cylZ", {0.3, 0.3}, "dark", {0, 0.45, -2.05}, nil, {role = "bracket", grp = "core"})
		return L
	end}
-- the pump sits 0.15 forward: its rear ring cleared the Tail Booster when the tail lifts in the p_pump pose (Play measure)
SEAT.dpump = {
	group = function() return "tank" end,
	groups = {tank = {move = Vector3.new(0, 0, -0.15)}}}
local function seatOn() return script:GetAttribute("DiloPartsSeatV2Enabled") ~= false end
local function seated(id)
	local list = P[id]()
	local S = seatOn() and SEAT[id]
	if not S then return list end
	if S.extra then for _, pc in ipairs(S.extra()) do table.insert(list, pc) end end
	for _, pc in ipairs(list) do
		local o = pc[7]
		if o.frill then
			local rest = PART[o.frill]
			if rest and (S.lift or 0) ~= 0 then
				local n = -rest.LookVector -- the plate's face normal (its +Z column)
				pc[5] = {pc[5][1] + n.X * S.lift, pc[5][2] + n.Y * S.lift, pc[5][3] + n.Z * S.lift}
			end
		elseif o.grp ~= "fixed" then
			local g = S.groups and S.groups[o.grp or (S.group and S.group(pc))]
			if g then
				local pos = Vector3.new(pc[5][1], pc[5][2], pc[5][3])
				if g.tilt then
					local turn = CFrame.fromAxisAngle(g.tilt[1], math.rad(g.tilt[2]))
					local c = g.tilt[3]
					pos = c + turn:VectorToWorldSpace(pos - c)
					local r = turn * CFrame.Angles(math.rad(pc[6][1]), math.rad(pc[6][2]), math.rad(pc[6][3]))
					local rx, ry, rz = r:ToEulerAnglesXYZ()
					pc[6] = {math.deg(rx), math.deg(ry), math.deg(rz)}
				end
				if g.move then pos += g.move end
				pc[5] = {pos.X, pos.Y, pos.Z}
			end
		end
	end
	return list
end

-- the rest pose of a moving piece (the mockup's MS values at rest)
local function animRest(kind)
	if kind == "mortar" then return CFrame.Angles(math.rad(-20), 0, 0) end
	if kind == "extend" then return CFrame.new(0, 0, 0) end
	return CFrame.identity
end

-- ---------- build / remove ----------
local function segRoot(model, seg)
	local s = model:FindFirstChild(seg)
	local r = s and s:FindFirstChild("Root")
	return r and r:IsA("BasePart") and r or nil
end
local function newPart(cls, m, matKey, size, cf, role)
	local mt = MAT[matKey] or MAT.gun
	local p = Instance.new(cls)
	p.Size = Vector3.new(math.max(0.02, size.X), math.max(0.02, size.Y), math.max(0.02, size.Z))
	p.Color, p.Material = mt[1], mt[2]
	p.Transparency = mt[3] or 0
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = mt[2] ~= Enum.Material.Neon and mt[2] ~= Enum.Material.Glass
	for _, f in ipairs({"Top", "Bottom", "Front", "Back", "Left", "Right"}) do p[f .. "Surface"] = Enum.SurfaceType.Smooth end
	p.CFrame = cf
	if role then p:SetAttribute("DPartRole", role) end
	p:SetAttribute("DPartBaseColor", p.Color)
	p.Parent = m
	return p
end
-- the shapes as (class, size, local frame) lists, scale sc, in the piece's own frame
local function shapes(shape, d, sc)
	local out = {}
	if shape == "box" then
		out[1] = {"Part", Vector3.new(d[1], d[2], d[3]) * sc, CFrame.identity}
	elseif shape == "cylZ" or shape == "cylY" or shape == "cylX" then
		local turn = shape == "cylZ" and CFrame.Angles(0, math.rad(90), 0) or (shape == "cylY" and CFrame.Angles(0, 0, math.rad(90)) or CFrame.identity)
		out[1] = {"Cyl", Vector3.new(d[2], d[1] * 2, d[1] * 2) * sc, turn}
	elseif shape == "sph" then
		out[1] = {"Ball", Vector3.one * d[1] * 2 * sc, CFrame.identity}
	elseif shape == "torus" then
		local rad, tube = d[1] * sc, d[2] * sc
		local seg = 2 * math.pi * rad / TORUS_SEGMENTS
		for k = 0, TORUS_SEGMENTS - 1 do
			local a = k / TORUS_SEGMENTS * 2 * math.pi
			out[#out + 1] = {"Part", Vector3.new(tube * 2, seg * 1.05, tube * 2), CFrame.Angles(0, 0, a) * CFrame.new(rad, 0, 0)}
		end
	elseif shape == "cone" then -- 4 wedges: back faces on the axis, slopes facing out, tip at +Y
		local sx, sy = d[1] * 2 * sc, d[2] * sc
		for k = 0, 3 do out[#out + 1] = {"WedgePart", Vector3.new(sx, sy, sx / 2), CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -sx / 4)} end
	end
	return out
end
local function buildPart(model, id)
	local sc = model:GetScale()
	local m = Instance.new("Model")
	m.Name = "DPart_" .. id
	local n, muzzles = 0, 0
	for _, pc in ipairs(seated(id)) do -- v1.1: seat layer
		local seg, shape, dims, matKey, pos, rot, o = pc[1], pc[2], pc[3], pc[4], pc[5], pc[6], pc[7]
		local root, rest = segRoot(model, seg), SEG[seg]
		if o.frill then -- ride the frill part itself (DiloPose moves it locally when the hood pops)
			local neck = model:FindFirstChild("Neck")
			local fpart = neck and neck:FindFirstChild(o.frill)
			root, rest = (fpart and fpart:IsA("BasePart")) and fpart or nil, PART[o.frill]
		end
		if root and rest then
			local at = CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
			local pivot = rest:Inverse() * at
			pivot = CFrame.new(pivot.Position * sc) * pivot.Rotation
			if shape == "muzzle" then
				muzzles += 1
				local a = Instance.new("Attachment")
				a.Name = "DPartMuzzle_" .. muzzles
				a.CFrame = pivot
				a:SetAttribute("DPartId", id)
				a.Parent = root
				m.Destroying:Connect(function() a:Destroy() end)
			else
				local go = o.go and CFrame.new(o.go[1] * sc, o.go[2] * sc, o.go[3] * sc) or CFrame.identity
				local rest0 = o.anim and animRest(o.anim) or CFrame.identity
				for _, sh in ipairs(shapes(shape, dims, sc)) do
					local cls, size, local0 = sh[1], sh[2], sh[3]
					local inner = go * local0 -- piece frame -> shape frame
					local cf = root.CFrame * pivot * rest0 * inner
					local p
					if cls == "Cyl" then
						p = newPart("Part", m, matKey, size, cf, o.role)
						p.Shape = Enum.PartType.Cylinder
					elseif cls == "Ball" then
						p = newPart("Part", m, matKey, size, cf, o.role)
						p.Shape = Enum.PartType.Ball
					else
						p = newPart(cls, m, matKey, size, cf, o.role)
					end
					p.Name = (o.role or "Piece") .. "_" .. seg
					if o.frill then p:SetAttribute("DPartFrill", o.frill) end
					if o.anim then
						local w = Instance.new("Weld")
						w.Name = "DPartJoint"
						w.Part0, w.Part1 = root, p
						w.C0 = pivot * rest0
						w.C1 = inner:Inverse()
						w:SetAttribute("DPartAnim", o.anim)
						w:SetAttribute("DPartPivot", pivot)
						w:SetAttribute("DPartBuiltScale", sc)
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
	end
	m:SetAttribute("DPartId", id)
	m.Parent = model
	return m, n
end

local function apply(char)
	if not char.Parent then return end
	local isD = enabled and char:GetAttribute("Species") == "Dilo"
	local built = {}
	for _, p in ipairs(PARTS) do
		local want = isD and char:GetAttribute(p.flag) == true and script:GetAttribute("DiloParts_" .. p.id .. "Enabled") ~= false
		local old = char:FindFirstChild("DPart_" .. p.id)
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
	char:SetAttribute("DiloPartsBuilt", table.concat(built, ","))
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
