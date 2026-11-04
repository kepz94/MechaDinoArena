-- TheriPartsLooksV2.spec v1.1 (Mecha Dino Arena) — data checks for ServerStorage.DinoArcade.TheriPartsLooksV2 1.1 (generated
-- from the redesign mockup v0.3 by tools/mockup/export_theri_parts_v2.js). Plan docs/plans/THERIZINO_PARTS_LOOKS_v2.0.md
-- Task 1 (MDA-249). Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.TheriPartsLooksV2_spec, clone + require);
-- returns "PASS n" or "FAIL ...".
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local ok, D = pcall(function()
	local src = game.ServerStorage.DinoArcade.TheriPartsLooksV2
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(D) end
local okM, MD = pcall(function() return require(game.ServerStorage.DinoArcade.Models.TherizinoModelData) end)
if not okM then return "FAIL model: " .. tostring(MD) end
local PARTNAMES = {}
for _, seg in ipairs(MD.segments) do for _, p in ipairs(seg.parts) do PARTNAMES[p.name] = true end end

eq("version", D.Version, "1.1") -- v1.1: Kepu 2026-11-04 14:49 final picks (Hook-B, Harvest-B claws only, Deflect-B)
-- the mockup's pieces at rest (+ the see-through shield film)
local COUNT = {zhook = 55, zfeather = 78, zharvest = 78, zgrapple = 50, zdeflect = 27, zclock = 56, zsnare = 66}
local GROUPS = {zhook = 6, zfeather = 12, zharvest = 0, zgrapple = 4, zdeflect = 9, zclock = 10, zsnare = 3}
local SHAPES = {box = true, wedge = true, cyl = true, ball = true, cone = true, ring = true}
local ROLES = {zhook = {"jib", "hookhead", "drum"}, zfeather = {"blade"}, zharvest = {}, zgrapple = {"nozzle", "drum", "prong"},
	zdeflect = {"hub", "fin", "film"}, zclock = {"ring", "gear", "fin"}, zsnare = {"spool"}}
local n = 0
for id, want in pairs(COUNT) do
	local L = D.LOOKS[id]
	eq(id .. " exists", L ~= nil, true)
	if L then
		n += 1
		eq(id .. " pieces", #L.pieces, want)
		eq(id .. " groups", #L.groups, GROUPS[id])
		eq(id .. " glow", typeof(L.glow), "Color3")
		local roles, gnames, inGroup = {}, {}, {}
		local function anchorOf(mi) return L.mounts[mi] and L.mounts[mi][1] end
		for i, mt in ipairs(L.mounts) do eq(id .. " mount " .. i, PARTNAMES[mt[1]] == true and #mt == 7, true) end
		for _, g in ipairs(L.groups) do
			gnames[g[1]] = g
			eq(id .. " group anchor " .. g[1], PARTNAMES[anchorOf(g[2])] == true, true)
			eq(id .. " group type " .. g[1], g[9] == "spin" or g[9] == "swing" or g[9] == "slide", true)
			eq(id .. " group axis " .. g[1], g[10] == "X" or g[10] == "Y" or g[10] == "Z", true)
		end
		for _, g in ipairs(L.groups) do
			if g[12] ~= "" then eq(id .. " parent " .. g[1], gnames[g[12]] ~= nil and anchorOf(gnames[g[12]][2]) == anchorOf(g[2]), true) end
		end
		local bad = 0
		for i, p in ipairs(L.pieces) do
			if not PARTNAMES[anchorOf(p[1])] then bad += 1; table.insert(fails, id .. " piece " .. i .. " mount " .. tostring(p[1])) end
			if not SHAPES[p[2]] then bad += 1; table.insert(fails, id .. " piece " .. i .. " shape " .. tostring(p[2])) end
			if not D.KIT[p[12]] then bad += 1; table.insert(fails, id .. " piece " .. i .. " mat " .. tostring(p[12])) end
			if p[13] ~= "" then roles[p[13]] = true end
			if p[14] ~= "" then
				inGroup[p[14]] = (inGroup[p[14]] or 0) + 1
				if not gnames[p[14]] then bad += 1; table.insert(fails, id .. " piece " .. i .. " group " .. p[14]) end
				if gnames[p[14]] and anchorOf(gnames[p[14]][2]) ~= anchorOf(p[1]) then bad += 1; table.insert(fails, id .. " piece " .. i .. " group on another anchor") end
			end
			if #p ~= 15 then bad += 1; table.insert(fails, id .. " piece " .. i .. " row length " .. #p) end
		end
		eq(id .. " pieces valid", bad, 0)
		for _, r in ipairs(ROLES[id]) do eq(id .. " role " .. r, roles[r] == true, true) end
		for name in pairs(gnames) do
			local hasChild = false
			for _, g in ipairs(L.groups) do if g[12] == name then hasChild = true end end
			eq(id .. " group has pieces " .. name, (inGroup[name] or 0) > 0 or hasChild, true)
		end
	end
end
eq("7 looks", n, 7)
-- no look sits on the far side only: nothing one-sided on the model's "...R" parts (the camera is over "...L" = +X)
for id, L in pairs(D.LOOKS) do
	local l, r = 0, 0
	for _, mt in ipairs(L.mounts) do if mt[1]:find("R_") then r += 1 elseif mt[1]:find("L_") then l += 1 end end
	eq(id .. " not far-side only", r == 0 or l > 0, true)
end
-- no two looks share a forearm (Kepu 2026-11-04 "Move some off the arms")
local fore = {}
for id, L in pairs(D.LOOKS) do for _, mt in ipairs(L.mounts) do if mt[1]:find("_fore") then fore[id] = true end end end
local nf = 0 for _ in pairs(fore) do nf += 1 end
eq("one look on the forearms", nf, 1)
for _, b in ipairs(D.LOOKS.zhook.beams) do eq("hook beam camera side", b.a0:find("L_") ~= nil and b.a1:find("L_") ~= nil, true) end

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
