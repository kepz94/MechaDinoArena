-- HerreraPartsLooksV2.spec v1.0 (Mecha Dino Arena) — data checks for ServerStorage.DinoArcade.HerreraPartsLooksV2 1.0
-- (generated from the redesign mockup v0.2 by tools/mockup/export_herrera_parts_v2.js 1.0). Plan
-- docs/plans/HERRERA_PARTS_LOOKS_v2.0.md Task 1 (MDA-287). Run in Studio Edit (copy in
-- ServerStorage.DinoArcadeTools.HerreraPartsLooksV2_spec, clone + require); returns "PASS n" or "FAIL ...". Built from
-- TenoPartsLooksV2.spec 1.0.
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local ok, D = pcall(function()
	local src = game.ServerStorage.DinoArcade.HerreraPartsLooksV2
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(D) end
local okM, MD = pcall(function() return require(game.ServerStorage.DinoArcade.Models.HerreraModelData) end)
if not okM then return "FAIL model: " .. tostring(MD) end
local PARTNAMES = {}
for _, seg in ipairs(MD.segments) do for _, p in ipairs(seg.parts) do PARTNAMES[p.name] = true end end

eq("version", D.Version, "1.0")
local LOOK = {ironclaw = "Wing Blades", glider = "Sword Wings", quills = "Missile Pods", smoke = "Stealth Generator", plating = "Lamellar Armour",
	siphon = "Fang Siphons", strobe = "Flash Crest", breaker = "Tesla Coils", caltrops = "Drop Chute", goo = "Spit Sacs", hadren = "Stim Shot"}
local COUNT = {ironclaw = 30, glider = 32, quills = 30, smoke = 11, plating = 50, siphon = 15, strobe = 33, breaker = 18, caltrops = 11, goo = 11, hadren = 8}
local GROUPS = {ironclaw = {}, glider = {}, quills = {lid_L = {"swing", "X", 58}, lid_R = {"swing", "X", 58}}, smoke = {}, plating = {},
	siphon = {}, strobe = {}, breaker = {}, caltrops = {door = {"swing", "Z", -68.7549}}, goo = {}, hadren = {plunger = {"slide", "Y"}}}
for i, a in ipairs({92, 68, 44}) do GROUPS.ironclaw["blade_L" .. i] = {"swing", "Z", a}; GROUPS.ironclaw["blade_R" .. i] = {"swing", "Z", a} end
for i, a in ipairs({78, 61, 44, 27}) do
	GROUPS.glider["wing_L" .. i] = {"swing", "Y", a}; GROUPS.glider["wing_R" .. i] = {"swing", "Y", -a}
	GROUPS.glider["droop_L" .. i] = {"swing", "Z", 19 - i}; GROUPS.glider["droop_R" .. i] = {"swing", "Z", 19 - i}
end
for k = 1, 4 do GROUPS.smoke["fin_" .. k] = {"swing", "X", k % 2 == 0 and 40 or -40} end
for k = 1, 6 do GROUPS.plating["row_" .. k] = {"slide", "Y"} end
-- every role an FX script reads (HerreraPartsFX 1.0 / HerreraMovesFX 1.5 / HerreraPartsServer fluid) + the new ones
local ROLES = {ironclaw = {"blade", "edge"}, glider = {"blade", "membrane"}, quills = {"tip", "lid"}, smoke = {"nozzle"}, plating = {"plate"},
	siphon = {"core", "glass", "fang"}, strobe = {"led"}, breaker = {"band", "tip"}, caltrops = {"chute", "door"}, goo = {"sac", "tube", "muzzle"},
	hadren = {"fluid", "glass"}}
local BEAMS = {siphon = 2}
local HIDES = {plating = 7}
local STRUTS = {}
local SHAPES = {box = true, wedge = true, cyl = true, ball = true, cone = true, ring = true}
local n = 0
for id, want in pairs(COUNT) do
	local L = D.LOOKS[id]
	eq(id .. " exists", L ~= nil, true)
	if L then
		n += 1
		eq(id .. " look", L.look, LOOK[id])
		eq(id .. " pieces", #L.pieces, want)
		eq(id .. " pieces <= 60", #L.pieces <= 60, true)
		eq(id .. " beams", #(L.beams or {}), BEAMS[id] or 0)
		eq(id .. " hides", #(L.hides or {}), HIDES[id] or 0)
		for _, h in ipairs(L.hides or {}) do eq(id .. " hide " .. h, PARTNAMES[h] == true, true) end
		for i, b in ipairs(L.beams or {}) do eq(id .. " beam " .. i, PARTNAMES[b.a0] == true and PARTNAMES[b.a1] == true and b.d > 0, true) end
		eq(id .. " glow", typeof(L.glow), "Color3")
		eq(id .. " struts", #(L.struts or {}), STRUTS[id] or 0)
		local roles, gnames, inGroup = {}, {}, {}
		local function anchorOf(mi) return L.mounts[mi] and L.mounts[mi][1] end
		for i, mt in ipairs(L.mounts) do eq(id .. " mount " .. i, PARTNAMES[mt[1]] == true and #mt == 7, true) end
		local ng = 0
		for _, g in ipairs(L.groups) do
			ng += 1
			gnames[g[1]] = g
			local w = GROUPS[id][g[1]]
			eq(id .. " group listed " .. g[1], w ~= nil, true)
			if w then
				eq(id .. " group type " .. g[1], g[9], w[1])
				eq(id .. " group axis " .. g[1], g[10], w[2])
				if w[3] then eq(id .. " group amt " .. g[1], math.abs(g[11] - w[3]) < 1e-3, true) end
			end
			eq(id .. " group anchor " .. g[1], PARTNAMES[anchorOf(g[2])] == true, true)
			if g[12] ~= "" then eq(id .. " parent " .. g[1], gnames[g[12]] ~= nil and anchorOf(gnames[g[12]][2]) == anchorOf(g[2]), true) end
		end
		local nw = 0 for _ in pairs(GROUPS[id]) do nw += 1 end
		eq(id .. " group count", ng, nw)
		local bad = 0
		for i, p in ipairs(L.pieces) do
			if not PARTNAMES[anchorOf(p[1])] then bad += 1; table.insert(fails, id .. " piece " .. i .. " mount " .. tostring(p[1])) end
			if not SHAPES[p[2]] then bad += 1; table.insert(fails, id .. " piece " .. i .. " shape " .. tostring(p[2])) end
			if not D.KIT[p[12]] then bad += 1; table.insert(fails, id .. " piece " .. i .. " mat " .. tostring(p[12])) end
			if #p ~= 17 then bad += 1; table.insert(fails, id .. " piece " .. i .. " row length " .. #p) end
			if p[13] ~= "" then roles[p[13]] = true end
			if p[14] ~= "" then
				inGroup[p[14]] = (inGroup[p[14]] or 0) + 1
				if not gnames[p[14]] then bad += 1; table.insert(fails, id .. " piece " .. i .. " group " .. p[14]) end
				if gnames[p[14]] and anchorOf(gnames[p[14]][2]) ~= anchorOf(p[1]) then bad += 1; table.insert(fails, id .. " piece " .. i .. " group on another anchor") end
			end
			if typeof(p[16]) ~= "number" or typeof(p[17]) ~= "number" or p[17] <= 0 or p[17] > 1 then bad += 1; table.insert(fails, id .. " piece " .. i .. " colour / alpha") end
		end
		eq(id .. " pieces valid", bad, 0)
		for _, r in ipairs(ROLES[id]) do eq(id .. " role " .. r, roles[r] == true, true) end
		for name in pairs(gnames) do
			local hasChild = false
			for _, g in ipairs(L.groups) do if g[12] == name then hasChild = true end end
			eq(id .. " group has pieces " .. name, (inGroup[name] or 0) > 0 or hasChild, true)
		end
		for i, s in ipairs(L.struts or {}) do
			eq(id .. " strut " .. i .. " anchors", PARTNAMES[s.a0] == true and PARTNAMES[s.a1] == true, true)
			eq(id .. " strut " .. i .. " span", s.f0 >= 0 and s.f1 <= 1 and s.f1 > s.f0 and D.KIT[s.mat] ~= nil, true)
		end
	end
end
eq("11 looks", n, 11)
-- nothing one-sided on the far side only (the camera is over the model's "...L" parts)
for id, L in pairs(D.LOOKS) do
	local l, r = 0, 0
	for _, mt in ipairs(L.mounts) do if mt[1]:find("R_") then r += 1 elseif mt[1]:find("L_") then l += 1 end end
	eq(id .. " not far-side only", r == 0 or l > 0, true)
end

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
