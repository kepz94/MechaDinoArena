-- HerreraPartsServer v1.2 (Mecha Dino Arena) — puts the Herrera's mecha parts on (server-built, every client sees them)
-- and builds their Lab card models. Plan docs/plans/HERRERA_PARTS_v1.0.md (MDA-149..156), Kepu 2026-10-31 "Build"; the
-- looks are the picked mockups, same numbers: Iron Claw B "Hook Blades" (docs/mockups/herrera_ironclaw_options.html),
-- Glider Wings A "Bat Membranes", Quill Launcher B "Spine Quills", Smoke Pods B "Tail Vents", Back Plating A "Spine
-- Scutes" (herrera_parts_b1_options.html), Blood Siphon A "Throat Pump", Strobe Frill A "LED Frill", Stun Breaker B "Back
-- Capacitor" (herrera_parts_b2_options.html).
-- Who: player characters with Species "Herrera". Each part's look is built while the character attribute
--   <Prefix>Enabled is true (SkillEffects 1.27: bought AND slotted) and removed when it goes false:
--   ironclaw IronClawEnabled -> Model "HPart_ironclaw", glider GliderEnabled, quills QuillEnabled, smoke SmokeEnabled,
--   plating PlatingEnabled, siphon SiphonEnabled, strobe StrobeEnabled, breaker BreakerEnabled (Model "HPart_<id>").
-- Build: each piece is a Part welded (WeldConstraint) to a named part of the Herrera (found anywhere under the character),
--   CFrame = anchor.CFrame * CFrame.new(pos x scale) * CFrame.Angles(rx, ry, rz) (degrees), Size = size x scale
--   (scale = the character's Model scale; the numbers are HerreraModelData's scale-1 units), Massless, CanCollide /
--   CanQuery / CanTouch false, CastShadow false for Neon / Glass. Materials: steel Metal rgb(154, 166, 184), dark Metal
--   rgb(93, 104, 120), bright Metal rgb(211, 219, 230), Neon hot rgb(255, 138, 42) / blood rgb(208, 32, 42) / LED
--   rgb(255, 231, 176) / volt rgb(127, 233, 255), Glass rgb(207, 232, 255) at transparency 0.65, membrane canvas
--   SmoothPlastic rgb(224, 116, 42) at transparency 0.1. Pieces carry attribute HPartRole ("blade" / "glow" / "led" / ...)
--   for HerreraPartsFX.
-- Hidden body parts: Quill Launcher and Back Plating hide the 7 back quills (Torso_quill1..7: Transparency 1, the old value
--   kept in attribute HPartsOldTransparency, put back when no shown part hides them any more).
-- Iron Claw also gets two Attachments per blade on the hand (IronClawTip at (1.90, -0.80, 0), IronClawMid at
--   (1.78, -0.42, 0)) and a Trail "IronClawTrail" between them (Lifetime 0.11, hot orange, LightEmission 1, transparency
--   0.1 -> 1, Enabled false: HerreraPartsFX turns it on during a slash on each client).
-- Glider Wings on a player are built folded (membranes and spar at 5% span from the body edge, finger rods hidden);
--   HerreraPartsFX opens them while gliding (pass 2). The Lab card model is built open.
-- Lab cards: BindableFunction "BuildPreview_<id>" under this script for each part (LabPreviewServer 1.2 plug-and-play; its
--   body = the path's owner dino, a Herrera mannequin): Invoke(mannequin) builds that look on it (Glider open) and returns
--   the part Model.
-- Switches: script attribute HerreraPartsServerEnabled (default true, read at start; false = no looks); per part
--   HerreraParts_<id>Enabled (default true, read on each apply). Diagnostics: script HerreraPartsServerVersion; character
--   HerreraPartsBuilt ("<id>=<pieces>,..." of what is on).
-- v1.1 (Studio check of 1.0: the hot orange Neon rgb(255, 138, 42) renders yellow in Roblox, the mockups' edges are
--   orange): Neon "hot" pieces (Iron Claw blade edges, glider hub, quill tips, tail-vent ring, strobe rim lamps) use
--   rgb(255, 98, 18); the Iron Claw trail colour follows. Non-Neon orange (the coil rings) is unchanged.
-- v1.2 (Glider Wings glide, MDA-150, pass 2): while the character's Gliding is true (HerreraMovesServer 1.0) the glider is
--   rebuilt open (the Lab card look: full membranes, spar, finger rods); when it turns false it is rebuilt folded.
--   HPart_glider attribute HPartOpen (true / false). Switch: script attribute HerreraPartsGlideOpenEnabled (default true,
--   read on each change; false = 1.1, always folded on players).
local Players = game:GetService("Players")

local VERSION = "1.2"
local C = {
	steel = {Color3.fromRGB(154, 166, 184), Enum.Material.Metal}, dark = {Color3.fromRGB(93, 104, 120), Enum.Material.Metal},
	bright = {Color3.fromRGB(211, 219, 230), Enum.Material.Metal}, hot = {Color3.fromRGB(255, 98, 18), Enum.Material.Neon}, -- v1.1 (was 255, 138, 42: rendered yellow)
	hotSolid = {Color3.fromRGB(255, 138, 42), Enum.Material.SmoothPlastic},
	blood = {Color3.fromRGB(208, 32, 42), Enum.Material.Neon}, led = {Color3.fromRGB(255, 231, 176), Enum.Material.Neon},
	volt = {Color3.fromRGB(127, 233, 255), Enum.Material.Neon}, glass = {Color3.fromRGB(207, 232, 255), Enum.Material.Glass, 0.65},
	canvas = {Color3.fromRGB(224, 116, 42), Enum.Material.SmoothPlastic, 0.1},
}
local PARTS = {
	{id = "ironclaw", flag = "IronClawEnabled"}, {id = "glider", flag = "GliderEnabled"}, {id = "quills", flag = "QuillEnabled"},
	{id = "smoke", flag = "SmokeEnabled"}, {id = "plating", flag = "PlatingEnabled"}, {id = "siphon", flag = "SiphonEnabled"},
	{id = "strobe", flag = "StrobeEnabled"}, {id = "breaker", flag = "BreakerEnabled"},
}
local HIDES = {quills = true, plating = true} -- hide the 7 back quills

script:SetAttribute("HerreraPartsServerVersion", VERSION)
if script:GetAttribute("HerreraPartsServerEnabled") == nil then script:SetAttribute("HerreraPartsServerEnabled", true) end
local enabled = script:GetAttribute("HerreraPartsServerEnabled") ~= false
for _, p in ipairs(PARTS) do
	if script:GetAttribute("HerreraParts_" .. p.id .. "Enabled") == nil then script:SetAttribute("HerreraParts_" .. p.id .. "Enabled", true) end
end

-- ---------- pieces (the mockups' numbers) ----------
-- each entry: {anchor part name, {size}, {pos}, {rot degrees}, colour key, role}
local function ironclaw()
	local out = {}
	for _, sd in ipairs({"L", "R"}) do
		local A = "Arm" .. sd
		table.insert(out, {A .. "_hand", {0.72, 0.24, 0.6}, {0, 0.15, 0}, {0, 0, 0}, "dark"})
		table.insert(out, {A .. "_fore", {0.5, 0.26, 0.48}, {0, -0.52, 0}, {0, 0, 0}, "steel"})
		-- the sickle: a chain of boxes along a curve forward from the hand (hand local +X = forward), hooking down
		local pts = {{0.05, 0.0}, {0.75, 0.12}, {1.35, 0.0}, {1.75, -0.35}, {1.9, -0.8}}
		local th = {0.3, 0.26, 0.2, 0.15}
		for i = 1, 4 do
			local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
			local len, a = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2), math.atan2(y1 - y0, x1 - x0)
			local cx, cy, nx, ny = (x0 + x1) / 2, (y0 + y1) / 2, math.sin(a), -math.cos(a)
			table.insert(out, {A .. "_hand", {len + 0.1, th[i], 0.13}, {cx, cy, 0}, {0, 0, math.deg(a)}, "steel", "blade"})
			table.insert(out, {A .. "_hand", {len + 0.08, 0.07, 0.15}, {cx + nx * th[i] / 2, cy + ny * th[i] / 2, 0}, {0, 0, math.deg(a)}, "hot", "edge"})
		end
	end
	return out
end
local function glider(open)
	local out = {}
	local k = open and 1 or 0.05
	for _, sd in ipairs({"L", "R"}) do table.insert(out, {"Arm" .. sd .. "_fore", {0.22, 1.25, 0.22}, {0, -0.05, 0}, {0, 0, 0}, "steel"}) end
	local base, span = 0.62, 3.6
	for _, z in ipairs({1, -1}) do
		for _, pnl in ipairs({{0.25, 1.9, 1.3}, {0.0, 1.6, 2.4}, {-0.25, 1.15, span}}) do
			local x, chord, len = pnl[1], pnl[2], pnl[3]
			table.insert(out, {"Torso_chest", {chord, 0.05, len * k}, {x - chord / 2 + 0.4, 0.2, (base + len * k / 2) * z}, {0, 0, 0}, "canvas", "membrane"})
		end
		table.insert(out, {"Torso_chest", {0.16, 0.16, (span + 0.2) * k}, {0.55, 0.24, (base + (span + 0.2) * k / 2) * z}, {0, 0, 0}, "steel", "spar"})
		if open then
			for _, fr in ipairs({{-25, 3.4}, {-50, 2.6}, {-75, 1.7}}) do
				local a, len = fr[1], fr[2]
				local ra = math.rad(a)
				local cx, cz = 0.5 + math.sin(ra) * len / 2 * 0.9, (base + math.cos(ra) * len / 2) * z
				table.insert(out, {"Torso_chest", {0.1, 0.1, len}, {cx, 0.26, cz}, {0, -a * z, 0}, "dark", "rod"})
			end
		end
		table.insert(out, {"Torso_chest", {0.4, 0.4, 0.4}, {0.5, 0.25, base * z}, {0, 0, 0}, "hot", "glow"})
	end
	return out
end
local function quills(char)
	local out = {}
	for i = 1, 7 do
		local q = char:FindFirstChild("Torso_quill" .. i, true)
		if q and q:IsA("BasePart") then
			local sc = char:GetScale()
			local sz = q.Size / sc
			table.insert(out, {q.Name, {sz.X * 1.9, sz.Y * 1.15, sz.Z * 1.9}, {0, 0, 0}, {0, 0, 0}, "steel", "quill"})
			table.insert(out, {q.Name, {sz.X * 2.3, 0.12, sz.Z * 2.3}, {0, sz.Y * 0.58, 0}, {0, 0, 0}, "hot", "tip"})
			table.insert(out, {q.Name, {sz.X * 2.4, 0.1, sz.Z * 2.4}, {0, -sz.Y * 0.45, 0}, {0, 0, 0}, "dark"})
		end
	end
	return out
end
local function smoke()
	local out = {
		{"Tail1_main", {0.7, 0.62, 0.62}, {0.1, 0.32, 0}, {0, 0, 0}, "dark", "vent"},
		{"Tail1_main", {0.72, 0.1, 0.66}, {0.1, 0.05, 0}, {0, 0, 0}, "hot", "glow"},
	}
	for _, zz in ipairs({-0.2, 0, 0.2}) do table.insert(out, {"Tail1_main", {0.14, 0.38, 0.14}, {-0.15, 0.62, zz}, {0, 0, 25}, "steel", "nozzle"}) end
	return out
end
local function plating()
	local out = {}
	local plates = {{"Torso_hips", {0.95, 0.12, 0.85}, {0, 0.36, 0}}, {"Torso_waist", {0.95, 0.12, 0.85}, {0, 0.37, 0}},
		{"Torso_chest", {1.05, 0.12, 1.1}, {0, 0.68, 0}}, {"Torso_hump", {1.0, 0.12, 1.05}, {0, 0.3, 0}},
		{"Tail1_main", {1.2, 0.12, 0.6}, {0, 0.27, 0}}, {"Tail2_main", {1.0, 0.1, 0.46}, {0, 0.2, 0}}}
	for _, pl in ipairs(plates) do
		local a, s, p = pl[1], pl[2], pl[3]
		table.insert(out, {a, s, p, {0, 0, -6}, "steel", "plate"})
		table.insert(out, {a, {s[1] * 0.98, 0.05, s[3] + 0.06}, {p[1] - s[1] * 0.35, p[2] - 0.02, p[3]}, {0, 0, -6}, "dark"})
		for _, zz in ipairs({-s[3] * 0.35, s[3] * 0.35}) do table.insert(out, {a, {0.08, 0.06, 0.08}, {p[1], p[2] + 0.08, zz}, {0, 0, 0}, "bright"}) end
	end
	return out
end
local function siphon()
	local out = {
		{"Neck_main", {1.15, 0.85, 0.95}, {0, -0.62, 0}, {0, 0, 0}, "glass", "tank"},
		{"Neck_main", {0.88, 0.6, 0.7}, {0, -0.64, 0}, {0, 0, 0}, "blood", "core"},
		{"Neck_sac", {0.9, 0.1, 0.66}, {0, -0.3, 0}, {0, 0, 0}, "steel"},
		{"Neck_lower", {0.14, 0.14, 0.7}, {0, -0.32, 0}, {0, 90, 0}, "blood", "pipe"},
	}
	for _, y in ipairs({-1.08, -0.18}) do table.insert(out, {"Neck_main", {1.22, 0.12, 1.02}, {0, y, 0}, {0, 0, 0}, "steel"}) end
	for _, z in ipairs({0.6, -0.6}) do table.insert(out, {"Neck_main", {0.3, 0.5, 0.14}, {0, -0.62, z}, {0, 0, 0}, "dark"}) end
	return out
end
local function strobe()
	local out = {}
	for i = 1, 11 do
		for _, x in ipairs({0.07, -0.07}) do table.insert(out, {"Head_frill" .. i, {0.05, 0.62, 0.16}, {x, 0.04, 0}, {0, 0, 0}, "led", "led"}) end
		table.insert(out, {"Head_frillrim" .. i, {0.16, 0.16, 0.24}, {0, 0.1, 0}, {0, 0, 0}, "hot", "led"})
	end
	table.insert(out, {"Neck_main", {0.9, 0.16, 0.66}, {0, 0.05, 0}, {0, 0, 0}, "steel"})
	return out
end
local function breaker()
	local out = {
		{"Torso_hump", {0.95, 0.6, 0.85}, {0, 0.45, 0}, {0, 0, 0}, "dark", "box"},
		{"Torso_hump", {0.98, 0.08, 0.88}, {0, 0.6, 0}, {0, 0, 0}, "volt", "band"},
	}
	for _, z in ipairs({0.25, -0.25}) do
		table.insert(out, {"Torso_hump", {0.15, 1.1, 0.15}, {0, 1.25, z}, {0, 0, 0}, "steel", "prong"})
		for _, y in ipairs({0.95, 1.2, 1.45}) do table.insert(out, {"Torso_hump", {0.32, 0.06, 0.32}, {0, y, z}, {0, 0, 0}, "hotSolid"}) end
		table.insert(out, {"Torso_hump", {0.26, 0.26, 0.26}, {0, 1.85, z}, {0, 0, 0}, "volt", "tip"})
	end
	return out
end
local BUILD = {ironclaw = ironclaw, glider = glider, quills = quills, smoke = smoke, plating = plating, siphon = siphon,
	strobe = strobe, breaker = breaker}

-- ---------- build / remove ----------
local function find(char, name)
	local p = char:FindFirstChild(name, true)
	return p and p:IsA("BasePart") and p or nil
end
local function addTrail(char, model, sd, sc)
	local hand = find(char, "Arm" .. sd .. "_hand")
	if not hand then return end
	local a0 = Instance.new("Attachment")
	a0.Name, a0.Position = "IronClawTip", Vector3.new(1.9, -0.8, 0) * sc
	a0.Parent = hand
	local a1 = Instance.new("Attachment")
	a1.Name, a1.Position = "IronClawMid", Vector3.new(1.78, -0.42, 0) * sc
	a1.Parent = hand
	local tr = Instance.new("Trail")
	tr.Name = "IronClawTrail"
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime, tr.MinLength = 0.11, 0.05
	tr.Color = ColorSequence.new(Color3.fromRGB(255, 140, 50), Color3.fromRGB(255, 98, 18)) -- v1.1
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.LightEmission, tr.FaceCamera, tr.Enabled = 1, true, false
	tr.Parent = model
	-- the attachments live on the hand; remove them with the model
	model.Destroying:Connect(function() a0:Destroy(); a1:Destroy() end)
end
local function buildPart(char, id, preview)
	local sc = char:GetScale()
	local open = preview -- v1.2: open while gliding
	if id == "glider" and not preview and char:GetAttribute("Gliding") == true and script:GetAttribute("HerreraPartsGlideOpenEnabled") ~= false then open = true end
	local list = id == "glider" and glider(open) or (id == "quills" and quills(char) or BUILD[id]())
	local m = Instance.new("Model")
	m.Name = "HPart_" .. id
	local n = 0
	for _, pc in ipairs(list) do
		local anchor = find(char, pc[1])
		if anchor then
			local col = C[pc[5]]
			local p = Instance.new("Part")
			p.Name = (pc[6] or "Piece") .. "_" .. pc[1]
			p.Size = Vector3.new(math.max(0.02, pc[2][1] * sc), math.max(0.02, pc[2][2] * sc), math.max(0.02, pc[2][3] * sc))
			p.Color, p.Material = col[1], col[2]
			p.Transparency = col[3] or 0
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
			p.CastShadow = col[2] ~= Enum.Material.Neon and col[2] ~= Enum.Material.Glass
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.CFrame = anchor.CFrame * CFrame.new(pc[3][1] * sc, pc[3][2] * sc, pc[3][3] * sc)
				* CFrame.Angles(math.rad(pc[4][1]), math.rad(pc[4][2]), math.rad(pc[4][3]))
			if pc[6] then p:SetAttribute("HPartRole", pc[6]) end
			p:SetAttribute("HPartBaseColor", col[1])
			p.Parent = m
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = anchor, p
			w.Parent = p
			n += 1
		end
	end
	if id == "ironclaw" then
		for _, sd in ipairs({"L", "R"}) do addTrail(char, m, sd, sc) end
	end
	m:SetAttribute("HPartId", id)
	if id == "glider" then m:SetAttribute("HPartOpen", open) end -- v1.2
	m.Parent = char
	return m, n
end
local function setQuillsHidden(char, hide)
	for i = 1, 7 do
		local q = char:FindFirstChild("Torso_quill" .. i, true)
		if q and q:IsA("BasePart") then
			if hide then
				if q:GetAttribute("HPartsOldTransparency") == nil then q:SetAttribute("HPartsOldTransparency", q.Transparency) end
				q.Transparency = 1
			elseif q:GetAttribute("HPartsOldTransparency") ~= nil then
				q.Transparency = q:GetAttribute("HPartsOldTransparency")
				q:SetAttribute("HPartsOldTransparency", nil)
			end
		end
	end
end

local function apply(char)
	if not char.Parent then return end
	local isH = enabled and char:GetAttribute("Species") == "Herrera"
	local hide, built = false, {}
	for _, p in ipairs(PARTS) do
		local want = isH and char:GetAttribute(p.flag) == true and script:GetAttribute("HerreraParts_" .. p.id .. "Enabled") ~= false
		local old = char:FindFirstChild("HPart_" .. p.id)
		if want then
			if not old then
				local _, n = buildPart(char, p.id, false)
				table.insert(built, p.id .. "=" .. n)
			else
				table.insert(built, p.id .. "=" .. #old:GetChildren())
			end
			if HIDES[p.id] then hide = true end
		elseif old then
			old:Destroy()
		end
	end
	setQuillsHidden(char, hide)
	char:SetAttribute("HerreraPartsBuilt", table.concat(built, ","))
end

local function onCharacter(char)
	for _, p in ipairs(PARTS) do
		char:GetAttributeChangedSignal(p.flag):Connect(function() apply(char) end)
	end
	char:GetAttributeChangedSignal("Species"):Connect(function() apply(char) end)
	char:GetAttributeChangedSignal("Gliding"):Connect(function() -- v1.2: rebuild the glider open / folded
		local g = char:FindFirstChild("HPart_glider")
		local want = char:GetAttribute("Gliding") == true and script:GetAttribute("HerreraPartsGlideOpenEnabled") ~= false
		if g and g:GetAttribute("HPartOpen") ~= want then
			g:Destroy()
			apply(char)
		end
	end)
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
		local m = buildPart(model, p.id, true)
		if HIDES[p.id] then setQuillsHidden(model, true) end
		return m
	end
	fn.Parent = script
end
