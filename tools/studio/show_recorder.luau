-- show_recorder.luau v1.0 (Mecha Dino Arena) — TEST TOOL, not part of the game (MDA-552; Kepu 2026-11-17 13:18 "Send me a mock
-- up of the actual presentation that we have plus all the new stuff we're proposing to add on to it so I can see it for
-- myself"). Run in Studio Play on the Client data model (execute_luau). Records the end-of-match presentation exactly as this
-- client draws it, 30 times a second (every 2nd Heartbeat):
--   * the camera (CFrame, FieldOfView, CameraType) and the viewport size;
--   * every BasePart above MinY (the VictoryTitles stage is VictoryStageY 3000 studs up: the stage, the title clones and their
--     effects), its CFrame / Size / Color / Transparency (changes only), and ParticleEmitters there (bursts + rates);
--   * every visible GuiObject of every enabled ScreenGui in PlayerGui (the HUD's VICTORY banner, the lower third, the board):
--     absolute position / size / rotation, colours, transparencies, text, font, text size (times the UIScales above it),
--     corner radius, stroke, gradient, draw order. Changes only.
--   * Hardpoint state stamps (HpPhase, HpWinner, HpResultsEndAt, HpTitles) and VictoryTitlesState changes, on the recording
--     clock.
-- API (_G.MDASHOW): start(seconds, minY) / busy() / stop() / export() -> length / get(i) -> 90 000-character chunk, padded.
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local me = game:GetService("Players").LocalPlayer
local S = {}
_G.MDASHOW = S
local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
local function r1(v) return math.floor(v * 10 + 0.5) / 10 end
local function hex(c) return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local function cfArr(cf)
	local x, y, z, a, b, c, d, e, f, g, h, i = cf:GetComponents()
	return {r3(x), r3(y), r3(z), r3(a), r3(b), r3(c), r3(d), r3(e), r3(f), r3(g), r3(h), r3(i)}
end
local rec, conns, out

local function shapeOf(p)
	if p:IsA("WedgePart") then return "Wedge" end
	if p:IsA("CornerWedgePart") then return "Block" end
	if p:IsA("Part") then
		if p.Shape == Enum.PartType.Ball then return "Ball" end
		if p.Shape == Enum.PartType.Cylinder then return "Cylinder" end
	end
	return "Block"
end
local function register(p)
	if rec.pidx[p] then return end
	local i = #rec.parts + 1
	rec.pidx[p] = i
	rec.parts[i] = {inst = p, n = p.Name, sh = shapeOf(p), mat = p.Material.Name, born = rec.f}
	rec.plast[i] = {}
end
local function emitterInfo(pe)
	local par = pe.Parent
	local cf = par and (par:IsA("Attachment") and par.WorldCFrame or (par:IsA("BasePart") and par.CFrame)) or nil
	if not cf then return nil end
	local col, sz, tr = pe.Color.Keypoints, pe.Size.Keypoints, pe.Transparency.Keypoints
	return {cf = cfArr(cf), c0 = hex(col[1].Value), c1 = hex(col[#col].Value), s0 = r3(sz[1].Value), s1 = r3(sz[#sz].Value),
		t0 = r3(tr[1].Value), sp = r3(pe.Speed.Max), sp0 = r3(pe.Speed.Min), life = r3(pe.Lifetime.Max), life0 = r3(pe.Lifetime.Min),
		spread = r3(pe.SpreadAngle.X), dir = pe.EmissionDirection.Name, acc = {r3(pe.Acceleration.X), r3(pe.Acceleration.Y), r3(pe.Acceleration.Z)},
		drag = r3(pe.Drag), le = r3(pe.LightEmission), rate = r3(pe.Rate)}
end
local function above(inst)
	local p = inst:IsA("BasePart") and inst or inst:FindFirstAncestorWhichIsA("BasePart")
	return p and p.Position.Y > rec.minY
end
local function watchEmitter(pe, burst)
	if rec.eidx[pe] then return end
	local info = emitterInfo(pe)
	if not info then return end
	local i = #rec.emitters + 1
	rec.eidx[pe] = i
	rec.emitters[i] = {inst = pe, info = info}
	if burst then table.insert(rec.bursts, {rec.f, i, info.cf}) end
end

-- ---------- gui ----------
local FONT = {}
local function fontOf(o)
	local ok, f = pcall(function() return o.Font.Name end)
	return ok and f or "Gotham"
end
local function scaleOf(o, root)
	local s, p = 1, o
	while p and p ~= root do
		local u = p:FindFirstChildOfClass("UIScale")
		if u then s *= u.Scale end
		p = p.Parent
	end
	return s
end
local function visibleChain(o, root)
	local p = o
	while p and p ~= root do
		if p:IsA("GuiObject") and not p.Visible then return false end
		p = p.Parent
	end
	return true
end
local function guiKey(o)
	local k = rec.gidx[o]
	if not k then
		k = #rec.gobjs + 1
		rec.gidx[o] = k
		rec.gobjs[k] = {cls = o.ClassName, n = o.Name}
		rec.glast[k] = ""
	end
	return k
end
local function sampleGui(f)
	local pg = me:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	local seen = {}
	local order = 0
	for _, g in ipairs(pg:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled then
			for _, o in ipairs(g:GetDescendants()) do
				if o:IsA("GuiObject") and visibleChain(o, g) then
					order += 1
					local k = guiKey(o)
					seen[k] = true
					local ap, as = o.AbsolutePosition, o.AbsoluteSize
					local corner = o:FindFirstChildOfClass("UICorner")
					local cr = corner and (corner.CornerRadius.Scale * math.min(as.X, as.Y) + corner.CornerRadius.Offset * scaleOf(o, g)) or 0
					local st = o:FindFirstChildOfClass("UIStroke")
					local gr = o:FindFirstChildOfClass("UIGradient")
					local rec1 = {r1(ap.X + (g.IgnoreGuiInset and 0 or rec.inset)), r1(ap.Y + (g.IgnoreGuiInset and 0 or rec.inset)), r1(as.X), r1(as.Y), r1(o.AbsoluteRotation),
						hex(o.BackgroundColor3), r3(o.BackgroundTransparency), r1(cr), g.DisplayOrder * 100000 + o.ZIndex * 1000 + order}
					if st and st.Enabled then table.insert(rec1, {r1(st.Thickness * scaleOf(o, g)), hex(st.Color), r3(st.Transparency), st.ApplyStrokeMode.Name}) else table.insert(rec1, 0) end
					if gr and gr.Enabled then
						local kp = gr.Color.Keypoints
						table.insert(rec1, {hex(kp[1].Value), hex(kp[#kp].Value), r1(gr.Rotation)})
					else table.insert(rec1, 0) end
					if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
						table.insert(rec1, {o.Text, hex(o.TextColor3), r3(o.TextTransparency), r3(o.TextStrokeTransparency), hex(o.TextStrokeColor3),
							fontOf(o), r1(o.TextSize * scaleOf(o, g)), o.TextXAlignment.Name, o.TextYAlignment.Name, o.TextWrapped, o.RichText})
					else table.insert(rec1, 0) end
					local enc = Http:JSONEncode(rec1)
					if enc ~= rec.glast[k] then
						table.insert(rec.gch, {f, k, rec1})
						rec.glast[k] = enc
					end
				end
			end
		end
	end
	for k in pairs(rec.gon) do
		if not seen[k] then table.insert(rec.gch, {f, k, 0}) rec.glast[k] = "" end
	end
	rec.gon = seen
end

-- ---------- sampling ----------
local function sample()
	local t = os.clock() - rec.t0
	rec.f += 1
	local f = rec.f
	rec.times[f] = r3(t)
	for d, until_ in pairs(rec.pending) do
		if not d.Parent or os.clock() > until_ then rec.pending[d] = nil
		elseif d:IsA("BasePart") and d.Position.Y > rec.minY then register(d) rec.pending[d] = nil
		elseif d:IsA("ParticleEmitter") and above(d) then watchEmitter(d, true) rec.pending[d] = nil end
	end
	local cam = workspace.CurrentCamera
	rec.cams[f] = {cfArr(cam.CFrame), r3(cam.FieldOfView), cam.CameraType.Name}
	for i, P in ipairs(rec.parts) do
		local p = P.inst
		local L = rec.plast[i]
		if p.Parent and p:IsDescendantOf(workspace) then
			local cfv, sz, tr, col = p.CFrame, p.Size, p.Transparency, p.Color
			local lookCh = sz ~= L.sz or tr ~= L.tr or col ~= L.col
			if cfv ~= L.cfv or lookCh then
				local row = {f, i, cfArr(cfv)}
				if lookCh then
					table.insert(row, {r3(sz.X), r3(sz.Y), r3(sz.Z)}) table.insert(row, r3(tr)) table.insert(row, hex(col))
					L.sz, L.tr, L.col = sz, tr, col
				end
				table.insert(rec.pch, row)
				L.cfv = cfv
			end
			L.gone = false
		elseif not L.gone and L.cfv then
			table.insert(rec.pch, {f, i, 0})
			L.gone, L.cfv, L.sz, L.tr, L.col = true, nil, nil, nil, nil
		end
	end
	for i, E in ipairs(rec.emitters) do
		local pe = E.inst
		if pe.Parent and pe:IsDescendantOf(workspace) and pe.Enabled and pe.Rate > 0 then
			local info = emitterInfo(pe)
			if info then table.insert(rec.emits, {f, i, info.cf, info.rate}) end
		end
	end
	sampleGui(f)
	if t >= rec.dur then S.stop() end
end
local function onAdded(d)
	if not rec or rec.done then return end
	if d:IsA("BasePart") or d:IsA("ParticleEmitter") then rec.pending[d] = os.clock() + 2 end -- checked each sample for 2 s
end
local function scan()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Position.Y > rec.minY then register(d)
		elseif d:IsA("ParticleEmitter") and above(d) then watchEmitter(d, false) end
	end
end

function S.start(dur, minY)
	local cam = workspace.CurrentCamera
	rec = {dur = dur or 40, minY = minY or 2000, t0 = os.clock(), f = 0, times = {}, cams = {}, parts = {}, pidx = {}, plast = {}, pch = {},
		emitters = {}, eidx = {}, bursts = {}, emits = {}, gobjs = {}, gidx = {}, glast = {}, gch = {}, gon = {}, stamps = {}, pending = {}, done = false,
		vp = {r1(cam.ViewportSize.X), r1(cam.ViewportSize.Y)}, inset = game:GetService("GuiService"):GetGuiInset().Y}
	scan()
	conns = {}
	table.insert(conns, workspace.DescendantAdded:Connect(onAdded))
	local hp = RS:FindFirstChild("Hardpoint")
	local function stamp(src, a, v) table.insert(rec.stamps, {r3(os.clock() - rec.t0), src, a, typeof(v) == "number" and (v > 1e6 and r3(v - workspace:GetServerTimeNow() + (os.clock() - rec.t0)) or r3(v)) or tostring(v)}) end
	if hp then
		for _, a in ipairs({"HpPhase", "HpWinner", "HpResultsEndAt", "HpResultsLen", "HpTitles"}) do stamp("hp", a, hp:GetAttribute(a)) end
		table.insert(conns, hp.AttributeChanged:Connect(function(a)
			if a == "HpPhase" or a == "HpWinner" or a == "HpResultsEndAt" or a == "HpResultsLen" or a == "HpTitles" or a == "HpTitlesLen" then stamp("hp", a, hp:GetAttribute(a)) end
		end))
	end
	table.insert(conns, me.AttributeChanged:Connect(function(a)
		if a == "VictoryTitlesState" or a == "GameSoundsLast" or a == "HardpointTeam" then stamp("me", a, me:GetAttribute(a)) end
	end))
	local rescan = 0
	table.insert(conns, RunService.Heartbeat:Connect(function()
		if rec and not rec.done then
			rec.hb = (rec.hb or 0) + 1
			if rec.hb % 2 == 1 then sample() end
			rescan += 1
			if rescan % 30 == 0 then scan() end
		end
	end))
	out = nil
	return ("show rec parts=%d emitters=%d vp=%sx%s inset=%s"):format(#rec.parts, #rec.emitters, rec.vp[1], rec.vp[2], rec.inset)
end
function S.stop()
	if not rec or rec.done then return end
	rec.done = true
	for _, c in ipairs(conns) do c:Disconnect() end
end
function S.busy() return rec and not rec.done end
function S.status() return rec and ("f=%d t=%.1f parts=%d pch=%d gobjs=%d gch=%d em=%d done=%s"):format(rec.f, os.clock() - rec.t0, #rec.parts, #rec.pch, #rec.gobjs, #rec.gch, #rec.emitters, tostring(rec.done)) or "none" end
function S.export()
	local parts = {}
	for i, P in ipairs(rec.parts) do parts[i] = {n = P.n, sh = P.sh, m = P.mat} end
	local em = {}
	for i, E in ipairs(rec.emitters) do em[i] = E.info end
	out = Http:JSONEncode({fps = 30, frames = rec.f, vp = rec.vp, times = rec.times, cams = rec.cams, parts = parts, pch = rec.pch,
		emitters = em, bursts = rec.bursts, emits = rec.emits, gobjs = rec.gobjs, gch = rec.gch, stamps = rec.stamps})
	return #out
end
function S.get(i)
	local s = string.sub(out, (i - 1) * 90000 + 1, i * 90000)
	return s .. string.rep(" ", 95000 - #s)
end
return "show recorder ready"
