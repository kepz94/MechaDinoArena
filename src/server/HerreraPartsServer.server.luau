-- HerreraPartsServer v1.5 (Mecha Dino Arena) — puts the Herrera's mecha parts on (server-built, every client sees them)
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
-- v1.3 (Herrera parts pass 3, MDA-165 / 166 / 167; mockup docs/mockups/herrera_parts_b3_options.html, Kepu picked A / A / A):
--   caltrops CaltropEnabled -> "Tail Spreader" (hopper, 2 bands, 5 spike tips, rear chute on Tail1_main); goo GooEnabled ->
--   "Hump Mortar" (base plate, tube tilted forward, lime muzzle ring, glass tank with a lime core on Torso_hump); hadren
--   HerreraAdrenEnabled (SkillEffects 1.30) -> "Back Tanks" (2 glass tanks with green cores, steel caps, green feed tube on
--   Torso_hump). Colours: lime Neon rgb(166, 226, 46), lime glass rgb(224, 255, 208), adrenaline Neon rgb(70, 224, 138),
--   green glass rgb(216, 255, 240). The tank cores ("fluid" pieces) empty and refill: on AdrenalineStartedAt (Back Tanks)
--   / GooFiredAt (mortar tank) their Transparency tweens to 0.8 over the boost (AdrenalineTime) / 0.3 s, then back to 0
--   over the cooldown (AdrenalineCooldown / GooCooldown). Lab cards BuildPreview_caltrops / _goo / _hadren come from the
--   same PARTS loop. Switch: HerreraParts_<id>Enabled for each (default true); HerreraPartsFluidEnabled (default true).
-- v1.4 (plan docs/plans/HERRERA_PARTS_LOOKS_v2.0.md Tasks 2 + 4, MDA-288 / MDA-290; Kepu 2026-11-05 19:39 picks from
--   docs/mockups/herrera_parts_redesign.html v0.2: A for every part, B for the Quill Launcher): while script attribute
--   HerreraPartsLooksV2Enabled is true (default, read at each build) the looks come from
--   ServerStorage.DinoArcade.HerreraPartsLooksV2 1.0 (generated by tools/mockup/export_herrera_parts_v2.js): the TenoPartsServer
--   1.3 build (each piece at anchor.CFrame x mount frame x piece frame, positions and sizes x the model's scale; stud =
--   Plastic with Studs, plain = SmoothPlastic, metal = Metal, neon = Neon in the part's area colour or the piece's own
--   colour; the engineer orange glow is rgb(255, 98, 18) as v1.1; box / wedge / cyl / ball (ellipsoid = Sphere mesh) / cone (4
--   wedges) / ring (16 blocks)). Same Model "HPart_<id>" and HPartRole attribute (every role the FX scripts read is kept:
--   blade, edge, plate, core, tip, nozzle, led, band, chute, tube, muzzle, fluid; new: membrane, lid, fin, door, sac, glass,
--   fang). A moving group = an invisible root Part "HPartGroup_<name>" on a Weld "HPartJoint_<name>" (Part0 = the anchor or
--   the parent group's root; C0 = the pivot; attributes HPartType / HPartAxis / HPartAmt / HPartRestC0 / HPartBuiltScale /
--   HPartPartId for HerreraPartsAnim 1.0). Film pieces (flag 2) start invisible (HPartFilm); alpha < 1 -> Transparency
--   1 - alpha (HPartAlpha); HPartBaseSize kept for the sac pulse. A beam row (the Fang Siphons' tubes) = an Attachment on each
--   of the two body parts + a dark Beam (removed with the model). The 7 back quills are hidden only for a look that lists them
--   (the Lamellar Armour; the Missile Pods keep them). The glider is no longer rebuilt on Gliding (HerreraPartsAnim spreads its
--   wings); its Lab card is posed open (joints at full, membranes shown). Model attributes HPartLooks "v2", HPartBuiltScale,
--   HPartBuiltAt (server time), HPartHidesQuills. Script attribute HerreraPartsDetail "full" (default) / "lite" (skips detail
--   pieces). Missing module or switch false = the 1.3 looks, quill hiding and glide rebuild exactly.
--   Task 4 (MDA-290): on the v2 Iron Claw the IronClawTip / IronClawMid attachments (and the trail between them) sit on the
--   tip of each arm's longest blade (blade_L1 / blade_R1: tip and 0.4 back along it), so the trail follows the swing. Switch:
--   script attribute HerreraPartsBladeTrailEnabled (default true; false = on the hand at the 1.3 points).
-- v1.5 (MDA-520, plan docs/plans/HERRERA_CRUISE_MISSILE_v1.0.md Task 2, mockup docs/mockups/herrera_cruise_missile_v0.1.html, Kepu
--   2026-11-13 pick "B · Backpack silo"): part cmissile (flag CruiseEnabled) -> Model "HPart_cmissile" on Torso_hump (its +X = forward,
--   +Y = up): a dark base plate + silo box, a yellow band, the yellow lid hinged at the back and flipped open 70°, the missile standing
--   in the silo (bright metal body, yellow stripe, red nose; role "missile"), a red light on the front (role "light") and a yellow
--   hazard strip. Pieces may give a 7th field shape "cyl" / "ball" (Part Shape Cylinder / Ball; only these new pieces use it). Built
--   with the 1.3 builder (no v2 look data for it). Lab card BuildPreview_cmissile from the same PARTS loop. Switch: script attribute
--   HerreraPartsCruiseEnabled (default true, read at start; false = 1.4, no cmissile look) + the usual HerreraParts_cmissileEnabled.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage") -- v1.4

local VERSION = "1.3"
VERSION = "1.4" -- v1.4 the redesigned looks (HerreraPartsLooksV2)
VERSION = "1.5" -- v1.5 Cruise Missile backpack silo (cmissile)
if script:GetAttribute("HerreraPartsCruiseEnabled") == nil then script:SetAttribute("HerreraPartsCruiseEnabled", true) end -- v1.5
local C = {
	steel = {Color3.fromRGB(154, 166, 184), Enum.Material.Metal}, dark = {Color3.fromRGB(93, 104, 120), Enum.Material.Metal},
	bright = {Color3.fromRGB(211, 219, 230), Enum.Material.Metal}, hot = {Color3.fromRGB(255, 98, 18), Enum.Material.Neon}, -- v1.1 (was 255, 138, 42: rendered yellow)
	hotSolid = {Color3.fromRGB(255, 138, 42), Enum.Material.SmoothPlastic},
	blood = {Color3.fromRGB(208, 32, 42), Enum.Material.Neon}, led = {Color3.fromRGB(255, 231, 176), Enum.Material.Neon},
	volt = {Color3.fromRGB(127, 233, 255), Enum.Material.Neon}, glass = {Color3.fromRGB(207, 232, 255), Enum.Material.Glass, 0.65},
	canvas = {Color3.fromRGB(224, 116, 42), Enum.Material.SmoothPlastic, 0.1},
	lime = {Color3.fromRGB(166, 226, 46), Enum.Material.Neon}, limeGlass = {Color3.fromRGB(224, 255, 208), Enum.Material.Glass, 0.65}, -- v1.3
	adr = {Color3.fromRGB(70, 224, 138), Enum.Material.Neon}, adrGlass = {Color3.fromRGB(216, 255, 240), Enum.Material.Glass, 0.65}, -- v1.3
}
C.yellow = {Color3.fromRGB(255, 194, 26), Enum.Material.SmoothPlastic} -- v1.5
C.redSolid = {Color3.fromRGB(255, 90, 79), Enum.Material.SmoothPlastic} -- v1.5
local PARTS = {
	{id = "ironclaw", flag = "IronClawEnabled"}, {id = "glider", flag = "GliderEnabled"}, {id = "quills", flag = "QuillEnabled"},
	{id = "smoke", flag = "SmokeEnabled"}, {id = "plating", flag = "PlatingEnabled"}, {id = "siphon", flag = "SiphonEnabled"},
	{id = "strobe", flag = "StrobeEnabled"}, {id = "breaker", flag = "BreakerEnabled"},
	{id = "caltrops", flag = "CaltropEnabled"}, {id = "goo", flag = "GooEnabled"}, {id = "hadren", flag = "HerreraAdrenEnabled"}, -- v1.3
}
if script:GetAttribute("HerreraPartsCruiseEnabled") ~= false then table.insert(PARTS, {id = "cmissile", flag = "CruiseEnabled"}) end -- v1.5
local HIDES = {quills = true, plating = true} -- hide the 7 back quills

script:SetAttribute("HerreraPartsServerVersion", VERSION)
if script:GetAttribute("HerreraPartsServerEnabled") == nil then script:SetAttribute("HerreraPartsServerEnabled", true) end
local enabled = script:GetAttribute("HerreraPartsServerEnabled") ~= false
if script:GetAttribute("HerreraPartsFluidEnabled") == nil then script:SetAttribute("HerreraPartsFluidEnabled", true) end -- v1.3
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
-- v1.3: pass 3 looks (look A each)
local function caltrops()
	local out = {
		{"Tail1_main", {0.85, 0.5, 0.6}, {0, 0.42, 0}, {0, 0, 0}, "dark", "hopper"},
		{"Tail1_main", {0.3, 0.26, 0.5}, {0.52, 0.32, 0}, {0, 0, -20}, "steel", "chute"},
	}
	for _, x in ipairs({-0.3, 0.3}) do table.insert(out, {"Tail1_main", {0.08, 0.54, 0.64}, {x, 0.42, 0}, {0, 0, 0}, "steel"}) end
	for i = 0, 4 do
		local x, z, r = -0.3 + i * 0.15, (i % 2 == 1) and 0.12 or -0.12, (i - 2) * 12
		table.insert(out, {"Tail1_main", {0.09, 0.26, 0.09}, {x, 0.78, z}, {0, 0, r}, "steel", "spike"})
		table.insert(out, {"Tail1_main", {0.07, 0.1, 0.07}, {x, 0.93, z}, {0, 0, r}, "blood", "spikeTip"})
	end
	return out
end
local function goo()
	local out = {
		{"Torso_hump", {0.9, 0.12, 0.8}, {0, 0.32, 0}, {0, 0, 0}, "dark", "base"},
		{"Torso_hump", {0.5, 1.0, 0.5}, {0.22, 0.85, 0}, {0, 0, -32}, "steel", "tube"},
		{"Torso_hump", {0.58, 0.14, 0.58}, {0.48, 1.27, 0}, {0, 0, -32}, "lime", "muzzle"},
		{"Torso_hump", {0.6, 0.55, 0.6}, {-0.42, 0.62, 0}, {0, 0, 0}, "limeGlass", "tank"},
		{"Torso_hump", {0.42, 0.4, 0.42}, {-0.42, 0.6, 0}, {0, 0, 0}, "lime", "fluid"},
	}
	for _, y in ipairs({0.36, 0.88}) do table.insert(out, {"Torso_hump", {0.64, 0.06, 0.64}, {-0.42, y, 0}, {0, 0, 0}, "steel"}) end
	return out
end
local function hadren()
	local out = {{"Torso_hump", {0.9, 0.1, 0.1}, {0.45, 1.0, 0}, {0, 0, -25}, "adr", "tube"}}
	for _, z in ipairs({0.27, -0.27}) do
		table.insert(out, {"Torso_hump", {0.34, 0.85, 0.34}, {-0.1, 0.72, z}, {0, 0, 0}, "adrGlass", "tank"})
		table.insert(out, {"Torso_hump", {0.24, 0.7, 0.24}, {-0.1, 0.66, z}, {0, 0, 0}, "adr", "fluid"})
		for _, y in ipairs({1.17, 0.28}) do table.insert(out, {"Torso_hump", {0.38, 0.1, 0.38}, {-0.1, y, z}, {0, 0, 0}, "steel"}) end
	end
	return out
end
local function cmissile() -- v1.5: Backpack Silo (Torso_hump: +X forward, +Y up)
	return {
		{"Torso_hump", {1.0, 0.12, 0.85}, {0, 0.32, 0}, {0, 0, 0}, "dark", "base"},
		{"Torso_hump", {0.8, 0.7, 0.7}, {0, 0.72, 0}, {0, 0, 0}, "dark", "silo"},
		{"Torso_hump", {0.82, 0.08, 0.72}, {0, 0.9, 0}, {0, 0, 0}, "yellow", "band"},
		{"Torso_hump", {0.84, 0.06, 0.74}, {-0.256, 1.465, 0}, {0, 0, 70}, "yellow", "lid"},
		{"Torso_hump", {0.75, 0.34, 0.34}, {0.05, 1.2, 0}, {0, 0, 90}, "bright", "missile", "cyl"},
		{"Torso_hump", {0.06, 0.36, 0.36}, {0.05, 1.42, 0}, {0, 0, 90}, "yellow", "missile", "cyl"},
		{"Torso_hump", {0.34, 0.34, 0.34}, {0.05, 1.58, 0}, {0, 0, 0}, "redSolid", "missile", "ball"},
		{"Torso_hump", {0.14, 0.14, 0.14}, {0.41, 0.72, 0.18}, {0, 0, 0}, "blood", "light", "ball"},
		{"Torso_hump", {0.02, 0.1, 0.6}, {0.405, 0.52, 0}, {0, 0, 0}, "yellow", "hazard"},
	}
end
local BUILD = {ironclaw = ironclaw, glider = glider, quills = quills, smoke = smoke, plating = plating, siphon = siphon,
	strobe = strobe, breaker = breaker, caltrops = caltrops, goo = goo, hadren = hadren} -- v1.3: + pass 3
BUILD.cmissile = cmissile -- v1.5

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
			if pc[7] == "cyl" then p.Shape = Enum.PartType.Cylinder elseif pc[7] == "ball" then p.Shape = Enum.PartType.Ball end -- v1.5
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

-- v1.4: the redesigned looks (see the header) ------------------------------------------------------------------------------
if script:GetAttribute("HerreraPartsLooksV2Enabled") == nil then script:SetAttribute("HerreraPartsLooksV2Enabled", true) end
if script:GetAttribute("HerreraPartsDetail") == nil then script:SetAttribute("HerreraPartsDetail", "full") end
if script:GetAttribute("HerreraPartsBladeTrailEnabled") == nil then script:SetAttribute("HerreraPartsBladeTrailEnabled", true) end
local V2
local function v2Data()
	if V2 == nil then
		V2 = false
		pcall(function()
			local arc = ServerStorage:FindFirstChild("DinoArcade")
			local m = arc and arc:FindFirstChild("HerreraPartsLooksV2")
			if m then V2 = require(m) end
		end)
	end
	return V2 or nil
end
local function hex(h) return Color3.fromRGB(math.floor(h / 65536) % 256, math.floor(h / 256) % 256, h % 256) end
local ENG_MOCK, ENG_GAME = Color3.fromRGB(255, 138, 26), Color3.fromRGB(255, 98, 18) -- the v1.1 rule: that orange renders yellow as Neon
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
	p.CastShadow = kind ~= "neon" and not (alpha and alpha < 1)
	if role and role ~= "" then p:SetAttribute("HPartRole", role) end
	p:SetAttribute("HPartBaseColor", p.Color)
	p:SetAttribute("HPartBaseSize", size)
	if alpha and alpha < 1 then
		p.Transparency = 1 - alpha
		p:SetAttribute("HPartAlpha", alpha)
	end
	if flags and math.floor(flags / 2) % 2 == 1 then
		p.Transparency = 1
		p:SetAttribute("HPartFilm", true)
	end
	if flags and math.floor(flags / 4) % 2 == 1 then
		p.Transparency = 1
		p:SetAttribute("HPartHidden", true)
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
	root.Name = "HPartGroup_" .. name
	root.Size = Vector3.one * 0.1 * sc
	root.Transparency = 1
	root.CanCollide, root.CanQuery, root.CanTouch, root.Massless = false, false, false, true
	root.CFrame = pivot
	root:SetAttribute("HPartGroup", name)
	local w = Instance.new("Weld") -- a Weld, not a Motor6D: IdleAnimation adopts every Motor6D
	w.Name = "HPartJoint_" .. name
	w.Part0, w.Part1 = part0, root
	w.C0 = part0.CFrame:ToObjectSpace(pivot)
	w.C1 = CFrame.identity
	w:SetAttribute("HPartType", gtype)
	w:SetAttribute("HPartAxis", axis)
	w:SetAttribute("HPartAmt", amt)
	w:SetAttribute("HPartRestC0", w.C0)
	w:SetAttribute("HPartBuiltScale", sc)
	w:SetAttribute("HPartPartId", id)
	root.Parent = m
	w.Parent = root
	return root, w
end
local function v2Piece(m, D, glow, pc, cf, sc, part0, anchorName)
	local kit = D.KIT[pc[12]]
	if not kit then return 0, {} end
	local shape, sx, sy, sz = pc[2], pc[3] * sc, pc[4] * sc, pc[5] * sc
	local flags, colour, alpha, role = pc[15], pc[16], pc[17], pc[13]
	local made = {}
	if shape == "wedge" then
		made[1] = v2Part("WedgePart", Vector3.new(sx, sy, sz), cf, kit, glow, role, flags, colour, alpha)
	elseif shape == "cyl" then
		local p = v2Part("Part", Vector3.new(math.max(0.02, sy), math.max(0.02, sx), math.max(0.02, sx)), cf * CFrame.Angles(0, 0, math.rad(90)), kit, glow, role, flags, colour, alpha)
		p.Shape = Enum.PartType.Cylinder
		made[1] = p
	elseif shape == "ball" then
		if math.abs(sx - sy) < 1e-3 and math.abs(sx - sz) < 1e-3 then
			local p = v2Part("Part", Vector3.one * sx, cf, kit, glow, role, flags, colour, alpha)
			p.Shape = Enum.PartType.Ball
			made[1] = p
		else
			local p = v2Part("Part", Vector3.new(math.max(0.02, sx), math.max(0.02, sy), math.max(0.02, sz)), cf, kit, glow, role, flags, colour, alpha)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			made[1] = p
		end
	elseif shape == "ring" then
		local rad, tube = sx, sy
		local seg = 2 * math.pi * rad / V2_RING_SEGMENTS
		for k = 0, V2_RING_SEGMENTS - 1 do
			local a = k / V2_RING_SEGMENTS * 2 * math.pi
			made[#made + 1] = v2Part("Part", Vector3.new(math.max(0.02, tube * 2), math.max(0.02, seg * 1.05), math.max(0.02, tube * 2)), cf * CFrame.Angles(0, 0, a) * CFrame.new(rad, 0, 0), kit, glow, role, flags, colour, alpha)
		end
	elseif shape == "cone" then
		for k = 0, 3 do
			made[#made + 1] = v2Part("WedgePart", Vector3.new(sx, sy, sx / 2), cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -sx / 4), kit, glow, role, flags, colour, alpha)
		end
	else
		made[1] = v2Part("Part", Vector3.new(math.max(0.02, sx), math.max(0.02, sy), math.max(0.02, sz)), cf, kit, glow, role, flags, colour, alpha)
	end
	for _, p in ipairs(made) do
		p.Name = (role ~= "" and role or "Piece") .. "_" .. anchorName
		p.Parent = m
		weldTo(p, part0)
	end
	return #made, made
end
-- the Iron Claw trail on the longest blade of each arm (MDA-290)
local function bladeTrail(m, blade, sc)
	local len = blade.Size.X
	local a0 = Instance.new("Attachment")
	a0.Name, a0.Position = "IronClawTip", Vector3.new(len / 2, 0, 0)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Name, a1.Position = "IronClawMid", Vector3.new(len / 2 - 0.4 * sc, 0, 0)
	a1.Parent = blade
	local tr = Instance.new("Trail")
	tr.Name = "IronClawTrail"
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime, tr.MinLength = 0.11, 0.05
	tr.Color = ColorSequence.new(Color3.fromRGB(255, 140, 50), Color3.fromRGB(255, 98, 18))
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.LightEmission, tr.FaceCamera, tr.Enabled = 1, true, false
	tr.Parent = m
end
local function buildV2(char, id, preview)
	local D = v2Data()
	local L = D and D.LOOKS[id]
	if not L then return buildPart(char, id, preview) end
	local sc = char:GetScale()
	local lite = script:GetAttribute("HerreraPartsDetail") == "lite"
	local glow = L.glow == ENG_MOCK and ENG_GAME or L.glow
	local m = Instance.new("Model")
	m.Name = "HPart_" .. id
	m:SetAttribute("HPartLooks", "v2")
	m:SetAttribute("HPartBuiltScale", sc)
	local mounts = {}
	for i, mt in ipairs(L.mounts) do
		local anchor = find(char, mt[1])
		if anchor then mounts[i] = {anchor = anchor, cf = anchor.CFrame * frameOf(mt, 2, sc)} end
	end
	local roots, joints = {}, {}
	for _, g in ipairs(L.groups) do -- parents come before their children in the data
		local mt = mounts[g[2]]
		if mt then
			local part0 = (g[12] ~= "" and roots[g[12]]) or mt.anchor
			local root, w = groupRoot(m, g[1], part0, mt.cf * frameOf(g, 3, sc), sc, id, g[9], g[10], g[11])
			roots[g[1]] = root
			table.insert(joints, w)
		end
	end
	local n, films = 0, {}
	for _, pc in ipairs(L.pieces) do
		local mt = mounts[pc[1]]
		if mt and not (lite and pc[15] % 2 == 1) then
			local k, made = v2Piece(m, D, glow, pc, mt.cf * frameOf(pc, 6, sc), sc, (pc[14] ~= "" and roots[pc[14]]) or mt.anchor, mt.anchor.Name)
			n += k
			if id == "ironclaw" and pc[13] == "blade" and (pc[14] == "blade_L1" or pc[14] == "blade_R1") and made[1]
				and script:GetAttribute("HerreraPartsBladeTrailEnabled") ~= false then bladeTrail(m, made[1], sc) end
			if math.floor(pc[15] / 2) % 2 == 1 then for _, p in ipairs(made) do table.insert(films, p) end end
		end
	end
	if id == "ironclaw" and script:GetAttribute("HerreraPartsBladeTrailEnabled") == false then
		for _, sd in ipairs({"L", "R"}) do addTrail(char, m, sd, sc) end
	end
	for i, b in ipairs(L.beams or {}) do
		local p0, p1 = find(char, b.a0), find(char, b.a1)
		if p0 and p1 then
			local a0 = Instance.new("Attachment")
			a0.Name, a0.Position = "HPartBeam_" .. id .. "_" .. i, Vector3.new(b.p0[1], b.p0[2], b.p0[3]) * sc
			a0.Parent = p0
			local a1 = Instance.new("Attachment")
			a1.Name, a1.Position = "HPartBeam_" .. id .. "_" .. i, Vector3.new(b.p1[1], b.p1[2], b.p1[3]) * sc
			a1.Parent = p1
			local bm = Instance.new("Beam")
			bm.Name = "HPartBeam_" .. i
			bm.Attachment0, bm.Attachment1 = a0, a1
			bm.Width0, bm.Width1 = b.d * sc, b.d * sc
			bm.Color = ColorSequence.new(hex(0x16171b))
			bm.LightInfluence, bm.FaceCamera, bm.Segments = 1, true, 4
			bm.Parent = m
			m.Destroying:Connect(function() a0:Destroy(); a1:Destroy() end)
		end
	end
	if preview and id == "glider" then -- the Lab card: wings spread, membranes shown
		for _, w in ipairs(joints) do
			local a, axis = math.rad(w:GetAttribute("HPartAmt") or 0), w:GetAttribute("HPartAxis")
			w.C0 = w.C0 * (axis == "X" and CFrame.Angles(a, 0, 0) or axis == "Y" and CFrame.Angles(0, a, 0) or CFrame.Angles(0, 0, a))
		end
		for _, p in ipairs(films) do p.Transparency = 0.45 end
	end
	m:SetAttribute("HPartId", id)
	m:SetAttribute("HPartHidesQuills", #(L.hides or {}) > 0)
	if id == "glider" then m:SetAttribute("HPartOpen", false) end
	m:SetAttribute("HPartBuiltAt", workspace:GetServerTimeNow()) -- HerreraPartsAnim ignores stamps older than this
	m.Parent = char
	return m, n
end
local function builder()
	return (script:GetAttribute("HerreraPartsLooksV2Enabled") ~= false and v2Data()) and buildV2 or buildPart
end
local function hidesQuills(m, id) -- v1.4
	if m and m:GetAttribute("HPartLooks") == "v2" then return m:GetAttribute("HPartHidesQuills") == true end
	return HIDES[id] == true
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
				local m, n = builder()(char, p.id, false) -- v1.4
				old = m
				table.insert(built, p.id .. "=" .. n)
			else
				table.insert(built, p.id .. "=" .. #old:GetChildren())
			end
			if hidesQuills(old, p.id) then hide = true end -- v1.4
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
		if g and g:GetAttribute("HPartLooks") == "v2" then return end -- v1.4: HerreraPartsAnim spreads the v2 wings
		local want = char:GetAttribute("Gliding") == true and script:GetAttribute("HerreraPartsGlideOpenEnabled") ~= false
		if g and g:GetAttribute("HPartOpen") ~= want then
			g:Destroy()
			apply(char)
		end
	end)
	-- v1.3: tank cores empty on use and refill over the cooldown
	local function drain(id, emptyTime, refillTime)
		if script:GetAttribute("HerreraPartsFluidEnabled") == false then return end
		local m = char:FindFirstChild("HPart_" .. id)
		if not m then return end
		for _, d in ipairs(m:GetChildren()) do
			if d:IsA("BasePart") and d:GetAttribute("HPartRole") == "fluid" then
				local down = TweenService:Create(d, TweenInfo.new(math.max(0.05, emptyTime), Enum.EasingStyle.Linear), {Transparency = 0.8})
				down.Completed:Connect(function()
					if d.Parent then TweenService:Create(d, TweenInfo.new(math.max(0.1, refillTime), Enum.EasingStyle.Linear), {Transparency = 0}):Play() end
				end)
				down:Play()
			end
		end
	end
	char:GetAttributeChangedSignal("AdrenalineStartedAt"):Connect(function()
		drain("hadren", tonumber(char:GetAttribute("AdrenalineTime")) or 3, tonumber(char:GetAttribute("AdrenalineCooldown")) or 20)
	end)
	char:GetAttributeChangedSignal("GooFiredAt"):Connect(function()
		drain("goo", 0.3, (tonumber(char:GetAttribute("GooCooldown")) or 14) - 0.3)
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
		local m = builder()(model, p.id, true) -- v1.4
		if hidesQuills(m, p.id) then setQuillsHidden(model, true) end
		return m
	end
	fn.Parent = script
end
