-- move_recorder.luau v1.0 (Mecha Dino Arena) — TEST TOOL, not part of the game (MDA-552; Kepu 2026-11-17 11:36 "How about you
-- actually use the fucking animation from the game"). Run in Studio Play on the Client data model (execute_luau): records the
-- local dino, a target model and the effects made near them, 30 times a second (every 2nd Heartbeat; the poses are applied on
-- PreSimulation, so the parts are where the game drew them), in the frame of the dino's root at the start (+X right, +Y up,
-- -Z forward). Also every attribute change on the dino / target (server-time stamps as seconds on the recording clock).
-- API (_G.MDAREC): start(name, seconds, targetModel or nil) -> starts; press(label) marks an input; busy(); stop();
--   export() -> length of the JSON (parts rigid on a Motor6D segment are stored once as {seg, rel}); chunk(i, size).
-- The pick-page workflow (2026-11-17) also used: export2 (drops effects farther than 40 studs from the dino / 25 from the
--   target, writes a frame equal to the one before as 1), get(k) (90 000-character chunks, padded), and a server pin (a
--   RemoteEvent the test created, MDARecPin) that held the target bot in place at its standing height until the press, with
--   PracticeServer disabled for the session so the bot did not attack. Packed for the page by tools/mockup/rec_pack.py.
-- v1.0 also records RopeConstraints (the tether chain) into beamFrames with a negative index.
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local me = game:GetService("Players").LocalPlayer
local R = {}
_G.MDAREC = R
local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
local function cfArr(cf)
	local x, y, z, a, b, c, d, e, f, g, h, i = cf:GetComponents()
	return {r3(x), r3(y), r3(z), r3(a), r3(b), r3(c), r3(d), r3(e), r3(f), r3(g), r3(h), r3(i)}
end
local function hex(c) return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local rec, conns, out

local function ownerOf(inst)
	if rec.char and inst:IsDescendantOf(rec.char) then return "me" end
	if rec.target and inst:IsDescendantOf(rec.target) then return "bot" end
	return "fx"
end
local function skip(inst)
	for _, m in ipairs({rec.char, rec.target}) do
		if m then local hb = m:FindFirstChild("Hitboxes") if hb and inst:IsDescendantOf(hb) then return true end end
	end
	return false
end
local function shapeOf(p)
	if p:IsA("WedgePart") then return "Wedge" end
	if p:IsA("Part") then
		if p.Shape == Enum.PartType.Ball then return "Ball" end
		if p.Shape == Enum.PartType.Cylinder then return "Cylinder" end
	end
	return "Block"
end
local function register(p)
	if rec.idx[p] or skip(p) then return end
	local i = #rec.parts + 1
	rec.idx[p] = i
	rec.parts[i] = {inst = p, n = p.Name, own = ownerOf(p), sh = shapeOf(p), mat = p.Material.Name, born = rec.f, last = {}}
	rec.tracks[i] = {}
end
local function emitterInfo(pe)
	local par = pe.Parent
	local cf = par and (par:IsA("Attachment") and par.WorldCFrame or (par:IsA("BasePart") and par.CFrame)) or nil
	if not cf then return nil end
	local col = pe.Color.Keypoints
	local sz = pe.Size.Keypoints
	local tr = pe.Transparency.Keypoints
	return {cf = cfArr(rec.B:ToObjectSpace(cf)), c0 = hex(col[1].Value), c1 = hex(col[#col].Value), s0 = r3(sz[1].Value), s1 = r3(sz[#sz].Value),
		t0 = r3(tr[1].Value), sp = r3(pe.Speed.Max), sp0 = r3(pe.Speed.Min), life = r3(pe.Lifetime.Max), life0 = r3(pe.Lifetime.Min),
		spread = r3(pe.SpreadAngle.X), dir = pe.EmissionDirection.Name, acc = {r3(pe.Acceleration.X), r3(pe.Acceleration.Y), r3(pe.Acceleration.Z)},
		drag = r3(pe.Drag), le = r3(pe.LightEmission), rate = r3(pe.Rate), on = pe.Enabled, own = ownerOf(pe), n = pe.Name}
end
local function sample()
	local t = os.clock() - rec.t0
	rec.f += 1
	local f = rec.f
	rec.times[f] = math.floor(t * 1000 + 0.5) / 1000
	for i, P in ipairs(rec.parts) do
		local p = P.inst
		if p.Parent and p:IsDescendantOf(workspace) then
			rec.tracks[i][f] = cfArr(rec.B:ToObjectSpace(p.CFrame))
			local sz, tr, c = p.Size, p.Transparency, hex(p.Color)
			local szA = {r3(sz.X), r3(sz.Y), r3(sz.Z)}
			local L = P.last
			if not L.sz or math.abs(L.sz[1] - szA[1]) + math.abs(L.sz[2] - szA[2]) + math.abs(L.sz[3] - szA[3]) > 0.005 or L.tr == nil or math.abs(L.tr - tr) > 0.01 or L.c ~= c or L.gone then
				table.insert(rec.changes, {f, i, szA, r3(tr), c})
				L.sz, L.tr, L.c, L.gone = szA, tr, c, false
			end
		elseif not P.last.gone and P.last.sz then
			table.insert(rec.changes, {f, i, 0}) -- gone
			P.last.gone = true
		end
	end
	-- continuous emitters + beams
	for _, E in ipairs(rec.emitters) do
		local pe = E.inst
		if pe.Parent and pe:IsDescendantOf(workspace) and pe.Enabled and pe.Rate > 0 then
			local info = emitterInfo(pe)
			if info then table.insert(rec.emits, {f, E.i, info.cf, info.rate}) end
		end
	end
	for bi, Bm in ipairs(rec.beams) do
		local b = Bm.inst
		if b.Parent and b:IsDescendantOf(workspace) and b.Enabled and b.Attachment0 and b.Attachment1 then
			local p0, p1 = rec.B:PointToObjectSpace(b.Attachment0.WorldPosition), rec.B:PointToObjectSpace(b.Attachment1.WorldPosition)
			table.insert(rec.beamFrames, {f, bi, r3(p0.X), r3(p0.Y), r3(p0.Z), r3(p1.X), r3(p1.Y), r3(p1.Z), r3(b.Width0), r3(b.Width1), hex(b.Color.Keypoints[1].Value), r3(b.Transparency.Keypoints[1].Value)})
		end
	end
	for ri, Rp in ipairs(rec.ropes) do
		local rp = Rp.inst
		if rp.Parent and rp:IsDescendantOf(workspace) and rp.Visible and rp.Attachment0 and rp.Attachment1 then
			local p0, p1 = rec.B:PointToObjectSpace(rp.Attachment0.WorldPosition), rec.B:PointToObjectSpace(rp.Attachment1.WorldPosition)
			table.insert(rec.beamFrames, {f, -ri, r3(p0.X), r3(p0.Y), r3(p0.Z), r3(p1.X), r3(p1.Y), r3(p1.Z), r3(rp.Thickness), r3(rp.Thickness), hex(rp.Color.Color), 0})
		end
	end
	if t >= rec.dur then R.stop() end
end
local function watchEmitter(pe)
	local info = emitterInfo(pe)
	if not info then return end
	local i = #rec.emitterInfo + 1
	rec.emitterInfo[i] = info
	table.insert(rec.emitters, {inst = pe, i = i})
	table.insert(rec.bursts, {rec.f, i}) -- created during the recording: a burst (Emit) is likely
end
local function onAdded(d)
	if not rec or rec.done then return end
	if d:IsA("BasePart") then register(d)
	elseif d:IsA("ParticleEmitter") then task.defer(function() if rec and not rec.done and d.Parent then watchEmitter(d) end end)
	elseif d:IsA("Beam") then table.insert(rec.beams, {inst = d, n = d.Name})
	elseif d:IsA("RopeConstraint") then table.insert(rec.ropes, {inst = d, n = d.Name})
	end
end

function R.start(name, dur, target)
	local char = me.Character
	local hrp = char.HumanoidRootPart
	local hum = char:FindFirstChildOfClass("Humanoid")
	local lv = hrp.CFrame.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z).Unit
	rec = {name = name, dur = dur, char = char, target = target, t0 = os.clock(), st0 = workspace:GetServerTimeNow(),
		B = CFrame.lookAt(hrp.Position, hrp.Position + flat), parts = {}, idx = {}, tracks = {}, times = {}, changes = {}, f = 0,
		emitters = {}, emitterInfo = {}, bursts = {}, emits = {}, beams = {}, ropes = {}, beamFrames = {}, stamps = {}, presses = {}, done = false}
	rec.ground = r3((hrp.Position.Y - hrp.Size.Y / 2 - hum.HipHeight) - hrp.Position.Y)
	for _, m in ipairs({char, target}) do
		if m then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then register(d)
				elseif d:IsA("ParticleEmitter") then local info = emitterInfo(d) if info then local i = #rec.emitterInfo + 1 rec.emitterInfo[i] = info table.insert(rec.emitters, {inst = d, i = i}) end
				elseif d:IsA("Beam") then table.insert(rec.beams, {inst = d, n = d.Name}) end
			end
		end
	end
	-- the joints (so the page knows the segments)
	rec.joints = {}
	for _, m in ipairs({char, target}) do
		if m then for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part0 and d.Part1 and rec.idx[d.Part0] and rec.idx[d.Part1] then table.insert(rec.joints, {d.Name, rec.idx[d.Part0], rec.idx[d.Part1]}) end
		end end
	end
	conns = {}
	table.insert(conns, workspace.DescendantAdded:Connect(onAdded))
	for _, m in ipairs({char, target}) do
		if m then table.insert(conns, m.AttributeChanged:Connect(function(a)
			if rec.done then return end
			local v = m:GetAttribute(a)
			if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
				table.insert(rec.stamps, {r3(os.clock() - rec.t0), m == char and "me" or "bot", a, type(v) == "number" and (v > 1e6 and r3(v - rec.st0) or r3(v)) or v, type(v) == "number" and v > 1e6})
			end
		end)) end
	end
	table.insert(conns, RunService.Heartbeat:Connect(function() if rec and not rec.done then rec.hb = (rec.hb or 0) + 1 if rec.hb % 2 == 1 then sample() end end end)) -- every 2nd 60 Hz step = 30 Hz (the pose runs on PreSimulation)
	out = nil
	return "rec " .. name .. " parts=" .. #rec.parts .. " joints=" .. #rec.joints .. " emitters=" .. #rec.emitters .. " beams=" .. #rec.beams
end
function R.press(label)
	table.insert(rec.presses, {r3(os.clock() - rec.t0), label})
end
function R.stop()
	if rec.done then return end
	rec.done = true
	for _, c in ipairs(conns) do c:Disconnect() end
end
function R.busy() return rec and not rec.done end

-- export: parts rigid on a segment part of their own model become static offsets
function R.export()
	local F = rec.f
	local seg = {}
	for _, j in ipairs(rec.joints) do seg[j[2]] = true seg[j[3]] = true end
	local samples = {}
	for k = 0, 9 do table.insert(samples, math.max(1, math.floor(1 + (F - 1) * k / 9))) end
	local function cfOf(a) return CFrame.new(a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12]) end
	local parts = {}
	for i, P in ipairs(rec.parts) do
		local e = {n = P.n, own = P.own, sh = P.sh, mat = P.mat}
		local tr = rec.tracks[i]
		local segOn = seg[i]
		if not segOn and P.own ~= "fx" then
			-- try every segment of the same model
			for s in pairs(seg) do
				if rec.parts[s].own == P.own then
					local rel0, ok, n = nil, true, 0
					for _, f in ipairs(samples) do
						local a, b = tr[f], rec.tracks[s][f]
						if a and b then
							local rel = cfOf(b):ToObjectSpace(cfOf(a))
							if not rel0 then rel0 = rel else
								if (rel.Position - rel0.Position).Magnitude > 0.03 or (rel.LookVector - rel0.LookVector).Magnitude + (rel.UpVector - rel0.UpVector).Magnitude > 0.012 then ok = false break end
							end
							n += 1
						elseif a or b then ok = false break end
					end
					if ok and rel0 and n >= 3 then e.seg = s e.rel = cfArr(rel0) break end
				end
			end
		end
		if not e.seg then
			local list = {}
			for f = 1, F do list[f] = tr[f] or 0 end
			e.tr = list
		end
		parts[i] = e
	end
	local beams = {}
	for bi, b in ipairs(rec.beams) do beams[bi] = b.n end
	local data = {name = rec.name, fps = 30, frames = F, times = rec.times, ground = rec.ground, joints = rec.joints, parts = parts,
		changes = rec.changes, emitters = rec.emitterInfo, bursts = rec.bursts, emits = rec.emits, beams = beams, beamFrames = rec.beamFrames,
		stamps = rec.stamps, presses = rec.presses}
	out = Http:JSONEncode(data)
	return #out
end
function R.chunk(i, size)
	size = size or 90000
	return string.sub(out, (i - 1) * size + 1, i * size)
end
return "recorder ready"
