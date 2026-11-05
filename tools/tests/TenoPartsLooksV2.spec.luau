-- TenoPartsLooksV2.spec v1.0 (Mecha Dino Arena) — data checks for ServerStorage.DinoArcade.TenoPartsLooksV2 1.0 (generated
-- from the redesign mockup v0.2 by tools/mockup/export_teno_parts_v2.js 1.0). Plan docs/plans/TENO_PARTS_LOOKS_v2.0.md
-- Task 1 (MDA-273). Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.TenoPartsLooksV2_spec, clone + require);
-- returns "PASS n" or "FAIL ...". (The rest offsets were checked against the mockup by the export round-trip, worst 0.001.)
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local ok, D = pcall(function()
	local src = game.ServerStorage.DinoArcade.TenoPartsLooksV2
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(D) end
local okM, MD = pcall(function() return require(game.ServerStorage.DinoArcade.Models.TenoModelData) end)
if not okM then return "FAIL model: " .. tostring(MD) end
local PARTNAMES = {}
for _, seg in ipairs(MD.segments) do for _, p in ipairs(seg.parts) do PARTNAMES[p.name] = true end end

eq("version", D.Version, "1.0")
local LOOK = {tgrab = "Pincer Tail", tmortar = "Back Cannon", tstomp = "Quake Hooves", tbellow = "Shriek Sacs", tchallenge = "Alarm Beacon",
	tleap = "Chicken-Leg Rams", tmud = "Shield Mane"}
local COUNT = {tgrab = 37, tmortar = 28, tstomp = 60, tbellow = 18, tchallenge = 22, tleap = 36, tmud = 38}
local GROUPS = {
	tgrab = {pincer_L = {"swing", "Y", 38}, pincer_R = {"swing", "Y", -38}},
	tmortar = {barrel = {"swing", "X", 26}, kick = {"slide", "Y"}},
	tstomp = {ring_L = {"spin", "Y", 13}, ring_R = {"spin", "Y", 13}, ram_L = {"slide", "Y"}, ram_R = {"slide", "Y"}},
	tbellow = {},
	tchallenge = {ant_L = {"swing", "Z", -35}, ant_R = {"swing", "Z", -35}, reflector = {"spin", "Y", 11.5}},
	tleap = {gear_L = {"spin", "Y", 8}, gear_R = {"spin", "Y", 8}},
	tmud = {},
}
for k = 1, 10 do GROUPS.tmud["blade_" .. k] = {"swing", "X", -82} end
local ROLES = {tgrab = {"pincer", "tip"}, tmortar = {"muzzle", "rock", "flash", "charge1", "charge2", "charge3", "charge4"}, tstomp = {"puff"},
	tbellow = {"sac"}, tchallenge = {"lens", "dome"}, tleap = {"gauge1", "gauge2", "gauge3", "gauge4", "gauge5"}, tmud = {"disc", "rim"}}
local STRUTS = {tleap = 6}
local SHAPES = {box = true, wedge = true, cyl = true, ball = true, cone = true, ring = true}
local n = 0
for id, want in pairs(COUNT) do
	local L = D.LOOKS[id]
	eq(id .. " exists", L ~= nil, true)
	if L then
		n += 1
		eq(id .. " look", L.look, LOOK[id])
		eq(id .. " pieces", #L.pieces, want)
		eq(id .. " pieces <= 90", #L.pieces <= 90, true)
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
eq("7 looks", n, 7)
-- nothing one-sided on the far side only (the camera is over the model's "...L" parts)
for id, L in pairs(D.LOOKS) do
	local l, r = 0, 0
	for _, mt in ipairs(L.mounts) do if mt[1]:find("R_") then r += 1 elseif mt[1]:find("L_") then l += 1 end end
	eq(id .. " not far-side only", r == 0 or l > 0, true)
end
-- one look on the forearms (Quake Hooves' rams)
local fore = {}
for id, L in pairs(D.LOOKS) do for _, mt in ipairs(L.mounts) do if mt[1]:find("_fore") then fore[id] = true end end end
local nf = 0 for _ in pairs(fore) do nf += 1 end
eq("one look on the forearms", nf, 1)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
