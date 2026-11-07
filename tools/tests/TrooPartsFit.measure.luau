-- TrooPartsFit.measure v1.0 (Mecha Dino Arena) — the troodon parts fit measurement (plan docs/plans/TROODON_PARTS_v1.0.md
-- ticket 3, MDA-347; the mockup's measure, tools/mockup/troodon_parts_looks.js "measurement"). A ModuleScript copy lives in
-- ServerStorage.DinoArcadeTools.TrooPartsFit_measure; in Play the server clones it into ReplicatedStorage (ZZ_TrooFit, gone
-- on Stop) and the client requires it. Each OPart_* piece (OPartIndex; all its BaseParts) is sampled at 125 points per
-- BasePart spread through its shape (block grid; cylinder: the grid mapped onto the disc; ball / SpecialMesh sphere:
-- the cube mapped onto the sphere). body = share inside any visible body part of the character (oriented boxes; Root /
-- HumanoidRootPart left out); clash = share inside another part's piece (shape-accurate). M.frame(char, tag) adds one frame
-- (max kept per piece), M.run(tag, seconds) samples every 0.03 s in the background, M.report() -> per part: worst piece,
-- worst bracket, worst clash (with the piece key and the frame tag).
local M = {}
local N = 5
local function g(i) return (i + 0.5) / N - 0.5 end
local function concentric(u, v)
	if u == 0 and v == 0 then return 0, 0 end
	local r, f
	if math.abs(u) > math.abs(v) then r = u; f = math.pi / 4 * (v / u) else r = v; f = math.pi / 2 - math.pi / 4 * (u / v) end
	return r * math.cos(f), r * math.sin(f)
end
local function kind(p)
	local sm = p:FindFirstChildOfClass("SpecialMesh")
	if sm and sm.MeshType == Enum.MeshType.Sphere then return "ell" end
	if p.Shape == Enum.PartType.Cylinder then return "cyl" end
	if p.Shape == Enum.PartType.Ball then return "ball" end
	return "box"
end
local function localSamples(p)
	local s, out, k = p.Size, {}, kind(p)
	for i = 0, N - 1 do for j = 0, N - 1 do for l = 0, N - 1 do
		if k == "box" then
			table.insert(out, Vector3.new(g(i) * s.X, g(j) * s.Y, g(l) * s.Z))
		elseif k == "cyl" then
			local a, b = concentric(2 * g(j), 2 * g(l))
			table.insert(out, Vector3.new(g(i) * s.X, a * s.Y / 2, b * s.Z / 2))
		else
			local v = Vector3.new(2 * g(i), 2 * g(j), 2 * g(l))
			local m, len = math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)), v.Magnitude
			if len > 1e-9 then v = v * (m / len) end
			table.insert(out, Vector3.new(v.X * s.X / 2, v.Y * s.Y / 2, v.Z * s.Z / 2))
		end
	end end end
	return out
end
local function inside(p, k, w)
	local q = p.CFrame:PointToObjectSpace(w)
	local s = p.Size / 2
	if k == "box" then return math.abs(q.X) <= s.X and math.abs(q.Y) <= s.Y and math.abs(q.Z) <= s.Z end
	if k == "cyl" then return math.abs(q.X) <= s.X and (q.Y / s.Y) ^ 2 + (q.Z / s.Z) ^ 2 <= 1 end
	return (q.X / s.X) ^ 2 + (q.Y / s.Y) ^ 2 + (q.Z / s.Z) ^ 2 <= 1
end
local function partOf(char, d)
	local a = d.Parent
	while a and a ~= char do
		if a.Name:sub(1, 6) == "OPart_" then return a.Name:sub(7) end
		a = a.Parent
	end
	return nil
end
M.acc = {}
function M.frame(char, tag)
	local body, pieces = {}, {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			local id = partOf(char, d)
			if id then
				if d.Transparency < 1 and d.LocalTransparencyModifier < 1 then
					local key = id .. "#" .. tostring(d:GetAttribute("OPartIndex"))
					pieces[key] = pieces[key] or {id = id, role = d:GetAttribute("OPartRole"), parts = {}}
					table.insert(pieces[key].parts, d)
				end
			elseif d.Name ~= "HumanoidRootPart" and d.Name ~= "Root" and d.Transparency < 1 then
				table.insert(body, {p = d, r = d.Size.Magnitude / 2})
			end
		end
	end
	local all = {}
	for _, pc in pairs(pieces) do
		for _, p in ipairs(pc.parts) do table.insert(all, {p = p, id = pc.id, k = kind(p), r = p.Size.Magnitude / 2}) end
	end
	for key, pc in pairs(pieces) do
		local n, inB, inP = 0, 0, 0
		for _, p in ipairs(pc.parts) do
			local pr = p.Size.Magnitude / 2
			local nearB, nearP = {}, {}
			for _, b in ipairs(body) do if (b.p.Position - p.Position).Magnitude <= b.r + pr then table.insert(nearB, b.p) end end
			for _, o in ipairs(all) do if o.id ~= pc.id and (o.p.Position - p.Position).Magnitude <= o.r + pr then table.insert(nearP, o) end end
			for _, v in ipairs(localSamples(p)) do
				local w = p.CFrame:PointToWorldSpace(v)
				n += 1
				for _, b in ipairs(nearB) do if inside(b, "box", w) then inB += 1 break end end
				for _, o in ipairs(nearP) do if inside(o.p, o.k, w) then inP += 1 break end end
			end
		end
		local a = M.acc[key] or {id = pc.id, role = pc.role, body = 0, clash = 0, tagB = "", tagC = ""}
		if inB / n > a.body then a.body = inB / n; a.tagB = tag end
		if inP / n > a.clash then a.clash = inP / n; a.tagC = tag end
		M.acc[key] = a
	end
end
function M.run(tag, dur)
	M.done = nil
	task.spawn(function()
		local t0 = os.clock()
		local c = game:GetService("Players").LocalPlayer.Character
		while os.clock() - t0 < dur do
			M.frame(c, tag .. string.format("%.2f", os.clock() - t0))
			task.wait(0.03)
		end
		M.done = tag
	end)
end
function M.report()
	local per = {}
	for key, a in pairs(M.acc) do
		local r = per[a.id] or {piece = 0, bracket = 0, clash = 0, wp = "", wb = "", wc = ""}
		if a.role == "bracket" then
			if a.body > r.bracket then r.bracket = a.body; r.wb = key .. "@" .. a.tagB end
		elseif a.body > r.piece then
			r.piece = a.body; r.wp = key .. "@" .. a.tagB
		end
		if a.clash > r.clash then r.clash = a.clash; r.wc = key .. "@" .. a.tagC end
		per[a.id] = r
	end
	local out = {}
	for id, r in pairs(per) do
		table.insert(out, ("%s piece %.1f%% (%s) bracket %.1f%% clash %.1f%% (%s)"):format(id, r.piece * 100, r.wp, r.bracket * 100, r.clash * 100, r.wc))
	end
	table.sort(out)
	return table.concat(out, "\n")
end
return M
