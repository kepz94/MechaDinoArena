-- DiloPartsVFX v1.0 (Mecha Dino Arena) — the Dilophosaurus' mecha part EFFECTS, reworked (LocalScript, StarterPlayerScripts).
-- Plan docs/plans/DILO_VFX_v1.0.md Tasks 2-5 (MDA-391..394); mockup docs/mockups/dilo_vfx_v0.1.html (tools/dilo_vfx_mockup/dilovfx_fx.js
-- kits KA / KB / KC, timings in dilovfx_tracks.js). Kepu 2026-11-10 15:05 picks: Venom Gatling A, Toxin Mortar C, Sonic Hiss B,
-- Spine Burst A, Antivenom Pump B, Spring Jets B, Venom Overdrive A; 16:02 "build".
-- Reads the same character stamps DiloMovesFX 1.5 reads (DiloMovesServer 1.10, DiloJetsLaunch 1.2, DiloAttackServer); the server
-- is not touched. DiloMovesFX 1.6 skips its own effect for a part while this script owns it (owned = this script is running
-- (DiloPartsVFXVersion set), DiloPartsVFXEnabled ~= false and DiloPartsVFX_<id>Enabled ~= false); the part motion (recoil, tube,
-- barbs, piston, fins, cones, pips, core glow), the SILENCED / IMMUNE / +N tags and the owner's jets boost feel (FOV, speed lines,
-- roar) stay in DiloMovesFX. Everything here is local (Workspace.DiloPartsVFX_Local), Anchored, no collision / query / touch /
-- shadow; sizes are the mockup's (studs at scale 2) x k = Model scale / 2. No landing FX. No image uploads (built-in particle
-- textures, Neon / SmoothPlastic / ForceField parts, Beams, Trails, a Highlight).
--   A · Liquid Venom (dgatling, dspine, dover): glossy goo (a Block with a SpecialMesh Sphere, SmoothPlastic, Reflectance 0.3,
--     stretched along its flight), dripping trails, splash crowns, sizzle; Overdrive: drips off the body + mouth fumes for its
--     time, and the spit darts fly as goo darts (DiloFX 1.3 hands them over while DiloOverdriveUntil > now).
--   B · Reactor Glow (dhiss, dpump, djets): Neon flashes, Beam rings / arc fronts, sparkle bursts; Hiss: 6 arc fronts, a shock
--     shell, ground rays, a mute ring over each silenced dino; Pump (blue): spiral charge, scan rings down the body, a ForceField
--     shell with a Highlight edge and 3 turning rings while DiloImmuneUntil; Jets: a plasma jet (Neon core + glow, 3 shock
--     diamonds, green fire particles) while the dash burns, a chevron strip + rising sparks while DiloJetsTrailUntil.
--   C · Chem Warfare (dmortar): a turning hazard-stripe ring of 28 wedges at DiloMortarTo, a blinking red dot, a red laser Beam
--     from the tube, an alarm light + steam on the tube; fire flash + smoke + a casing; a smoking canister with a hazard band;
--     the land blast (flash, debris, sparks, smoke rolls) and the chem smoke cloud (a Box ParticleEmitter, DiloMortarRadius
--     wide) for DiloMortarTime inside the ring.
-- Switches (script attributes, default true, read at each event / frame): DiloPartsVFXEnabled, DiloPartsVFX_<id>Enabled for
--   dgatling, dmortar, dhiss, dspine, dpump, djets, dover. Numbers: DiloPartsVFX_maxParts (350: live effect parts; at the cap
--   the oldest effects end first), DiloPartsVFX_rateMul (1: every particle count / rate x this).
-- Diagnostics (script): DiloPartsVFXVersion, DiloPartsVFXParts (live parts), DiloPartsVFXEffects (live effects),
--   DiloPartsVFXEvents (count), DiloPartsVFXLast ("<id>:<phase>"), DiloPartsVFXTrims (effects ended by the cap).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local Lib = require(script.Parent:WaitForChild("DiloPartsVFXLib"))
local IDS = {"dgatling", "dmortar", "dhiss", "dspine", "dpump", "djets", "dover"}
if script:GetAttribute("DiloPartsVFXEnabled") == nil then script:SetAttribute("DiloPartsVFXEnabled", true) end
for _, id in ipairs(IDS) do
	if script:GetAttribute("DiloPartsVFX_" .. id .. "Enabled") == nil then script:SetAttribute("DiloPartsVFX_" .. id .. "Enabled", true) end
end
for k, v in pairs({maxParts = 350, rateMul = 1}) do
	if script:GetAttribute("DiloPartsVFX_" .. k) == nil then script:SetAttribute("DiloPartsVFX_" .. k, v) end
end
for _, k in ipairs({"DiloPartsVFXEvents", "DiloPartsVFXTrims"}) do script:SetAttribute(k, 0) end
script:SetAttribute("DiloPartsVFXVersion", VERSION)
local function on(id) return script:GetAttribute("DiloPartsVFXEnabled") ~= false and script:GetAttribute("DiloPartsVFX_" .. id .. "Enabled") ~= false end
local function cfg(k, d) local v = script:GetAttribute("DiloPartsVFX_" .. k) return typeof(v) == "number" and v or d end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k) local v = m:GetAttribute(k) return typeof(v) == "number" and v == v and v or nil end
local function note(what) script:SetAttribute("DiloPartsVFXEvents", (script:GetAttribute("DiloPartsVFXEvents") or 0) + 1) script:SetAttribute("DiloPartsVFXLast", what) end
local function rnd(a) return (math.random() - 0.5) * 2 * (a or 1) end
local function scaleK(m) return (m:IsA("Model") and m:GetScale() or 2) / 2 end

local C = {
	gMain = Color3.fromHex("8FE04A"), gHi = Color3.fromHex("EAFFB0"), gDeep = Color3.fromHex("3D8F14"), gGlow = Color3.fromHex("B8FF70"),
	bMain = Color3.fromHex("5CFF7E"), bHi = Color3.fromHex("F0FFF4"), bAcc = Color3.fromHex("45E0FF"),
	pMain = Color3.fromHex("55C8FF"), pHi = Color3.fromHex("F0FBFF"), pAcc = Color3.fromHex("B8F0FF"),
	cMain = Color3.fromHex("C8FF3A"), cHi = Color3.fromHex("FFF6C8"), cHaz = Color3.fromHex("FFC21A"), cDark = Color3.fromHex("1C1D16"),
	cSmoke = Color3.fromHex("9AA47A"), cGrey = Color3.fromHex("B9BCAE"), cFire = Color3.fromHex("FF8A2A"), red = Color3.fromHex("FF3B30"),
	violet = Color3.fromHex("B8A6FF"), xRed = Color3.fromHex("FF6B8A"), white = Color3.new(1, 1, 1), sand = Color3.fromHex("C2AD7A"),
}
local TEX = {smoke = "rbxasset://textures/particles/smoke_main.dds", spark = "rbxasset://textures/particles/sparkles_main.dds", fire = "rbxasset://textures/particles/fire_main.dds"}

local folder = workspace:FindFirstChild("DiloPartsVFX_Local")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "DiloPartsVFX_Local"
	folder.Parent = workspace
end

-- ============================================================================================================== effect engine
local FX, live = {}, 0
local function finish(f)
	if f.done then return end
	f.done = true
	if f.onEnd then pcall(f.onEnd, f) end
	for _, p in ipairs(f.parts) do if p.Parent then p:Destroy() end end
	live -= #f.parts
	f.parts = {}
end
local function trim(need)
	local list = {}
	for i, f in ipairs(FX) do list[i] = {parts = #f.parts} end
	for _, i in ipairs(Lib.pickTrim(list, need)) do
		finish(FX[i])
		script:SetAttribute("DiloPartsVFXTrims", (script:GetAttribute("DiloPartsVFXTrims") or 0) + 1)
	end
end
local function effect(life, update, onEnd)
	local f = {parts = {}, t = 0, life = math.max(0.01, life), update = update, onEnd = onEnd}
	table.insert(FX, f)
	return f
end
local function newPart(f, shape, size, color, transp, material, cf)
	if live >= cfg("maxParts", 350) then trim(1 + math.floor(cfg("maxParts", 350) * 0.1)) end
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = shape or Enum.PartType.Ball
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = transp or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if cf then p.CFrame = cf end
	p.Parent = folder
	live += 1
	table.insert(f.parts, p)
	return p
end
local function holder(f, cf, size) return newPart(f, Enum.PartType.Block, size or Vector3.one * 0.2, C.white, 1, Enum.Material.SmoothPlastic, cf) end
RunService.RenderStepped:Connect(function(dt)
	local i = 1
	while i <= #FX do
		local f = FX[i]
		if f.done then
			table.remove(FX, i)
		else
			f.t += dt
			local u = math.min(1, f.t / f.life)
			if f.update then
				local ok, err = pcall(f.update, f, dt, u)
				if not ok then script:SetAttribute("DiloPartsVFXError", tostring(err)) finish(f) end
			end
			if u >= 1 then finish(f) end
			i += 1
		end
	end
	script:SetAttribute("DiloPartsVFXParts", live)
	script:SetAttribute("DiloPartsVFXEffects", #FX)
end)

-- ---------------------------------------------------------------- particles (built-in textures)
-- o: tex, c0, c1, s0, s1, life {a, b}, speed {a, b}, spread, accel, drag, light, t0, rot
local function emitterOn(parent, o)
	local pe = Instance.new("ParticleEmitter")
	pe.Enabled = false
	pe.Texture = TEX[o.tex or "spark"]
	pe.Color = ColorSequence.new(o.c0, o.c1 or o.c0)
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, o.s0), NumberSequenceKeypoint.new(1, o.s1 or o.s0 * 0.3)})
	pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, o.t0 or 0.1), NumberSequenceKeypoint.new(1, 1)})
	pe.Lifetime = NumberRange.new(o.life[1], o.life[2])
	pe.Speed = NumberRange.new(o.speed[1], o.speed[2])
	pe.SpreadAngle = Vector2.new(o.spread or 180, o.spread or 180)
	pe.Acceleration = o.accel or Vector3.zero
	pe.Drag = o.drag or 0
	pe.LightEmission = o.light or 0
	pe.LightInfluence = o.light and o.light > 0.5 and 0 or 1
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-(o.rot or 40), o.rot or 40)
	if o.shape then pe.Shape, pe.ShapeStyle = o.shape, o.shapeStyle or Enum.ParticleEmitterShapeStyle.Volume end
	if o.inward then pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward end
	pe.Parent = parent
	return pe
end
local function burst(pos, dir, n, o)
	n = math.floor(n * cfg("rateMul", 1) + 0.5)
	if n <= 0 then return end
	local f = effect(o.life[2] + 0.15)
	local d = (dir and dir.Magnitude > 1e-4) and dir.Unit or Vector3.yAxis
	local h = holder(f, CFrame.lookAt(pos, pos + d))
	local pe = emitterOn(h, o)
	pe:Emit(n)
end
-- a continuous emitter following pFn for life s; rate r per s (x rateMul); dirFn optional
local function stream(life, pFn, r, o, dirFn, rateFn)
	local f
	f = effect(life + o.life[2] + 0.1, function(_, dt, u)
		local p = pFn()
		if not p then return end
		local d = dirFn and dirFn() or Vector3.yAxis
		f.h.CFrame = CFrame.lookAt(p, p + ((d.Magnitude > 1e-4) and d.Unit or Vector3.yAxis))
		local alive = f.t < life
		f.pe.Rate = alive and (rateFn and rateFn(f.t / life) or r) * cfg("rateMul", 1) or 0
	end)
	local p0 = pFn() or Vector3.zero
	f.h = holder(f, CFrame.new(p0), o.box)
	f.pe = emitterOn(f.h, o)
	f.pe.Rate = r * cfg("rateMul", 1)
	f.pe.Enabled = true
	return f
end

-- ---------------------------------------------------------------- shapes
local function flash(pos, size, color, life, transp)
	local f = effect(life or 0.16, function(f, _, u)
		local p = f.parts[1]
		if p then local s = size * (0.2 + 0.45 * u) p.Size = Vector3.one * s p.Transparency = (transp or 0.1) + (1 - (transp or 0.1)) * u end
	end)
	newPart(f, Enum.PartType.Ball, Vector3.one * size * 0.2, color, transp or 0.1, Enum.Material.Neon, CFrame.new(pos))
end
local function gooPart(f, cf, scale, color)
	local p = newPart(f, Enum.PartType.Block, Vector3.one, color or C.gMain, 0, Enum.Material.SmoothPlastic, cf)
	p.Reflectance = 0.3
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale = scale
	m.Parent = p
	return p, m
end
local function bar(f, a, b, w, color, transp)
	local d = b - a
	local L = math.max(0.05, d.Magnitude)
	return newPart(f, Enum.PartType.Block, Vector3.new(w, w, L), color, transp or 0, Enum.Material.Neon, CFrame.lookAt(a:Lerp(b, 0.5), b + (d.Magnitude < 1e-4 and Vector3.zAxis or Vector3.zero)))
end
local function setBar(p, a, b, w)
	local d = b - a
	if d.Magnitude < 1e-4 then return end
	p.Size = Vector3.new(w, w, d.Magnitude)
	p.CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b)
end
-- a Beam circle (4 Bezier Beams on an invisible holder); r:set(R, transp, width) moves it
local function beamRing(f, cf, R, width, color, transp, light)
	local h = holder(f, cf)
	local atts = {}
	for i = 1, 4 do local a = Instance.new("Attachment") a.Parent = h atts[i] = a end
	local beams = {}
	for i = 1, 4 do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = atts[i], atts[i % 4 + 1]
		b.FaceCamera = true
		b.Segments = 12
		b.Color = ColorSequence.new(color)
		b.LightEmission = light or 1
		b.LightInfluence = 0
		b.Parent = h
		beams[i] = b
	end
	local r = {h = h}
	function r:set(R2, tr, w)
		local cfs, c = Lib.ringPoints(math.max(0.05, R2))
		for i = 1, 4 do atts[i].CFrame = cfs[i] end
		for _, b in ipairs(beams) do
			b.CurveSize0, b.CurveSize1 = c, c
			b.Width0, b.Width1 = w or width, w or width
			b.Transparency = NumberSequence.new(math.clamp(tr, 0, 1))
		end
	end
	r:set(R, transp or 0)
	return r
end
-- a flat arc (2 Beams) of radius R spanning +- half around a flat direction
local function beamArc(f, center, dir, R, half, width, color)
	local h = holder(f, CFrame.new(center))
	local atts = {}
	for i = 1, 3 do local a = Instance.new("Attachment") a.Parent = h atts[i] = a end
	local beams = {}
	for i = 1, 2 do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = atts[i], atts[i + 1]
		b.FaceCamera = true
		b.Segments = 10
		b.Color = ColorSequence.new(color)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Parent = h
		beams[i] = b
	end
	local ang = math.atan2(dir.Z, dir.X)
	local r = {h = h}
	function r:set(R2, tr)
		local cfs, c = Lib.arcPoints(math.max(0.05, R2), half, ang)
		for i = 1, 3 do atts[i].CFrame = cfs[i] end
		for _, b in ipairs(beams) do b.CurveSize0, b.CurveSize1 = c, c b.Width0, b.Width1 = width, width b.Transparency = NumberSequence.new(math.clamp(tr, 0, 1)) end
	end
	r:set(R, 0)
	return r
end
local function groundRing(center, R, color, life, width)
	local f
	f = effect(life, function(_, _, u) f.r:set(math.max(0.05, R * (1 - (1 - u) ^ 3)), u) end)
	f.r = beamRing(f, CFrame.new(center), 0.05, width or 0.6, color, 0)
end
local function axisRing(pos, normal, R, color, life, width)
	local f
	local n = normal.Magnitude > 1e-4 and normal.Unit or Vector3.yAxis
	local cf = CFrame.lookAt(pos, pos + n) * CFrame.Angles(math.pi / 2, 0, 0) -- the ring's plane is perpendicular to n
	f = effect(life, function(_, _, u) f.r:set(math.max(0.05, R * (1 - (1 - u) ^ 3)), u) end)
	f.r = beamRing(f, cf, 0.05, width or 0.4, color, 0)
end
local function shell(pos, R, color, life, material)
	local f = effect(life, function(f, _, u)
		local p = f.parts[1]
		if p then p.Size = Vector3.one * math.max(0.1, 2 * R * (1 - (1 - u) ^ 3)) p.Transparency = 0.3 + 0.7 * u end
	end)
	newPart(f, Enum.PartType.Ball, Vector3.one * 0.2, color, 0.3, material or Enum.Material.ForceField, CFrame.new(pos))
end
local function bolt(a, b, color, life, jit, w)
	local f = effect(life, function(f, _, u) for _, p in ipairs(f.parts) do p.Transparency = u end end)
	local prev = a
	for i = 1, 6 do
		local q = i == 6 and b or a:Lerp(b, i / 6) + Vector3.new(rnd(jit), rnd(jit), rnd(jit))
		bar(f, prev, q, w or 0.18, color, 0)
		prev = q
	end
end

-- ---------------------------------------------------------------- the families' shared pieces
local SPARK = function(c0, c1, s, sp, life) return {tex = "spark", c0 = c0, c1 = c1, s0 = s, life = {life * 0.6, life}, speed = {sp * 0.5, sp}, light = 1, drag = 3} end
local DROP = function(c0, c1, s, sp) return {tex = "smoke", c0 = c0, c1 = c1, s0 = s, s1 = s * 0.6, life = {0.4, 0.6}, speed = {sp * 0.5, sp}, accel = Vector3.new(0, -55, 0), drag = 1, t0 = 0, light = 0.25, rot = 20} end
local MIST = function(c0, s, life, sp) return {tex = "smoke", c0 = c0, s0 = s, s1 = s * 2.4, life = {life * 0.7, life}, speed = {sp * 0.4, sp}, drag = 2, t0 = 0.45, light = 0.2, rot = 30} end

-- A · liquid venom
local A = {}
function A.impact(pos, s)
	flash(pos, 7 * s, C.gHi, 0.18)
	local f = effect(0.28, function(f, _, u) local m = f.mesh if m then local e = 1 - (1 - u) ^ 3 m.Scale = Vector3.new(3.4 * s * e + 0.01, 1.8 * s * (1 - u) + 0.01, 3.4 * s * e + 0.01) f.parts[1].Transparency = u end end)
	local _, m = gooPart(f, CFrame.new(pos), Vector3.one * 0.01)
	f.mesh = m
	burst(pos, Vector3.yAxis, 14 * s, {tex = "smoke", c0 = C.gMain, c1 = C.gHi, s0 = 0.9 * s, s1 = 0.4 * s, life = {0.45, 0.6}, speed = {14 * math.sqrt(s), 26 * math.sqrt(s)}, spread = 55, accel = Vector3.new(0, -55, 0), drag = 0.5, t0 = 0, light = 0.25})
	burst(pos, Vector3.yAxis, 8 * s, DROP(C.gDeep, C.gMain, 0.8 * s, 22 * s))
	burst(pos + Vector3.new(0, 0.5, 0), Vector3.yAxis, 4, {tex = "smoke", c0 = Color3.fromHex("E8FFD8"), s0 = 1.8 * s, s1 = 4 * s, life = {0.7, 0.9}, speed = {3, 6}, spread = 30, accel = Vector3.new(0, 2, 0), t0 = 0.5, rot = 30})
end
function A.charge(pFn, dur, s)
	local f = effect(dur, function(f, dt, u)
		local p = pFn()
		if not p then return end
		local e = 1 - (1 - u) ^ 3
		local w = 1 + 0.15 * math.sin(os.clock() * 26)
		f.parts[1].CFrame = CFrame.new(p)
		f.mesh.Scale = Vector3.new(1.8 * s * e * w + 0.01, 1.8 * s * e / w + 0.01, 1.8 * s * e + 0.01)
	end)
	local _, m = gooPart(f, CFrame.new(pFn() or Vector3.zero), Vector3.one * 0.01)
	f.mesh = m
	stream(dur, pFn, 40 * s, {tex = "smoke", c0 = C.gMain, c1 = C.gHi, s0 = 0.6 * s, s1 = 0.2 * s, life = {0.2, 0.25}, speed = {20 * s, 26 * s}, t0 = 0, light = 0.3,
		shape = Enum.ParticleEmitterShape.Sphere, shapeStyle = Enum.ParticleEmitterShapeStyle.Surface, inward = true, box = Vector3.one * 10 * s})
	stream(dur, pFn, 10, DROP(C.gDeep, C.gMain, 0.6 * s, 3))
end
-- a goo projectile; o: from, to (Vector3 or fn), flight, apex, s, kind ("dart" | "quill"), onArrive(pos)
function A.shot(o)
	local s = o.s
	local L = o.kind == "quill" and 3.2 or 1.9
	local f
	f = effect(o.flight, function(_, dt, u)
		local to = typeof(o.to) == "function" and o.to() or o.to
		local p = o.from:Lerp(to, u) + Vector3.new(0, 4 * (o.apex or 0) * u * (1 - u), 0)
		local u2 = math.min(1, u + 0.03)
		local q = o.from:Lerp(to, u2) + Vector3.new(0, 4 * (o.apex or 0) * u2 * (1 - u2), 0)
		local cf = (q - p).Magnitude > 1e-3 and CFrame.lookAt(p, q) or CFrame.new(p)
		f.parts[1].CFrame = cf
		local w = 1 + 0.18 * math.sin(os.clock() * 30 + f.ph)
		f.mesh.Scale = Vector3.new(1.44 * s * w, 1.44 * s / w, 2 * L * s)
		f.h.CFrame = cf
		f.last = p
	end, function() if o.onArrive then o.onArrive(f.last or o.to) end end)
	f.ph = math.random() * 6
	local body, m = gooPart(f, CFrame.new(o.from), Vector3.new(1.44 * s, 1.44 * s, 2 * L * s))
	f.mesh = m
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.3 * s, 0), Vector3.new(0, -0.3 * s, 0)
	a0.Parent, a1.Parent = body, body
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(C.gMain, C.gDeep)
	tr.Lifetime = 0.14
	tr.LightEmission = 0.3
	tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	tr.FaceCamera = true
	tr.Parent = body
	f.h = holder(f, CFrame.new(o.from))
	local pe = emitterOn(f.h, DROP(C.gMain, C.gDeep, 0.55 * s, 3))
	pe.Rate = 45 * s * cfg("rateMul", 1)
	pe.Enabled = true
end
function A.muzzle(pos, dir, s)
	flash(pos, 4.5 * s, C.gHi, 0.14)
	local f = effect(0.16, function(f, _, u) f.mesh.Scale = Vector3.one * (2.6 * s * (1 - (1 - u) ^ 3) + 0.01) f.parts[1].Transparency = u end)
	local _, m = gooPart(f, CFrame.new(pos), Vector3.one * 0.01)
	f.mesh = m
	burst(pos, dir, 12 * s, {tex = "smoke", c0 = C.gMain, c1 = C.gDeep, s0 = 0.9 * s, s1 = 0.4 * s, life = {0.4, 0.5}, speed = {22, 48}, spread = 25, accel = Vector3.new(0, -55, 0), t0 = 0, light = 0.25})
	burst(pos, dir, 3, MIST(C.gGlow, 1.6 * s, 0.5, 16))
end
function A.vent(pFn, life, s)
	stream(life, pFn, 16, DROP(C.gMain, C.gDeep, 0.7 * s, 2), nil, function(u) return 16 * (1 - u) end)
	stream(life, pFn, 10, {tex = "smoke", c0 = Color3.fromHex("F0FFF0"), s0 = 1.2 * s, s1 = 3.6 * s, life = {0.7, 0.8}, speed = {2, 3}, spread = 20, accel = Vector3.new(0, 2, 0), t0 = 0.6, rot = 30},
		nil, function(u) return 10 * (1 - u) end)
end
function A.ring(center, R)
	groundRing(center, R, C.gMain, 0.5, 0.9)
	burst(center + Vector3.new(0, 2, 0), Vector3.yAxis, 22, {tex = "smoke", c0 = C.gMain, c1 = C.gHi, s0 = 1, s1 = 0.4, life = {0.45, 0.5}, speed = {R * 1.6, R * 2}, spread = 80, accel = Vector3.new(0, -40, 0), t0 = 0, light = 0.25})
end

-- B · reactor glow
local B = {}
function B.star(pos, size, color, life)
	flash(pos, size * 0.6, color, life or 0.14, 0)
	burst(pos, Vector3.yAxis, 10, SPARK(color, color, size * 0.12, size * 3, 0.18))
end
function B.charge(pFn, dur, s, main, hi, acc)
	local f
	f = effect(dur, function(_, _, u)
		local p = pFn()
		if not p then return end
		local g = f.parts[1]
		g.CFrame = CFrame.new(p)
		g.Size = Vector3.one * (0.5 + 2.5 * u * u) * s
		g.Transparency = 0.2 + 0.25 * math.sin(os.clock() * 40)
		f.r.h.CFrame = CFrame.new(p) * CFrame.Angles(os.clock() * 5, os.clock() * 3, 0)
		f.r:set(math.max(0.05, 4 * s * (1 - u * u * (3 - 2 * u))), 0)
	end)
	newPart(f, Enum.PartType.Ball, Vector3.one * s, main, 0.3, Enum.Material.Neon, CFrame.new(pFn() or Vector3.zero))
	f.r = beamRing(f, CFrame.new(pFn() or Vector3.zero), 4 * s, 0.25 * s, acc or hi, 0)
	stream(dur, pFn, 70 * s, {tex = "spark", c0 = main, c1 = hi, s0 = 0.9 * s, s1 = 0.2, life = {0.25, 0.3}, speed = {22 * s, 26 * s}, light = 1,
		shape = Enum.ParticleEmitterShape.Sphere, shapeStyle = Enum.ParticleEmitterShapeStyle.Surface, inward = true, box = Vector3.one * 14 * s})
end
function B.vent(pFn, life, s, main)
	stream(life, pFn, 14, {tex = "smoke", c0 = C.white, s0 = 1.4 * s, s1 = 4 * s, life = {0.6, 0.7}, speed = {4, 5}, spread = 15, t0 = 0.75, rot = 20}, nil, function(u) return 14 * (1 - u) end)
	stream(life, pFn, 20, SPARK(main, main, 0.7 * s, 6, 0.5), nil, function(u) return 20 * (1 - u) end)
end

-- C · chem warfare
local Cc = {}
function Cc.smokeBurst(pos, dir, n, s, color, sp)
	burst(pos, dir, n, {tex = "smoke", c0 = color or C.cGrey, s0 = 2 * s, s1 = 6 * s, life = {0.8, 1.0}, speed = {(sp or 14) * 0.5, sp or 14}, spread = 35, drag = 2, accel = Vector3.new(0, 1.5, 0), t0 = 0.4, rot = 40})
end
function Cc.casing(pos, side)
	local f
	local v = side * (14 + math.random() * 6) + Vector3.new(rnd(3), 12 + math.random() * 5, rnd(3))
	local w = Vector3.new(rnd(20), rnd(20), rnd(20))
	f = effect(0.7, function(_, dt, u)
		local p = f.parts[1]
		v += Vector3.new(0, -60 * dt, 0)
		p.CFrame = (p.CFrame + v * dt) * CFrame.Angles(w.X * dt, w.Y * dt, w.Z * dt)
		p.Transparency = u > 0.7 and (u - 0.7) / 0.3 or 0
	end)
	newPart(f, Enum.PartType.Cylinder, Vector3.new(0.55, 0.32, 0.32), Color3.fromHex("D9A441"), 0, Enum.Material.Metal, CFrame.new(pos))
end
function Cc.debris(pos, n, color, sp)
	for _ = 1, n do
		local f
		local v = Vector3.new(rnd(sp), sp * (0.5 + math.random()), rnd(sp))
		local w = Vector3.new(rnd(12), rnd(12), rnd(12))
		f = effect(0.8, function(_, dt, u)
			local p = f.parts[1]
			v += Vector3.new(0, -70 * dt, 0)
			p.CFrame = (p.CFrame + v * dt) * CFrame.Angles(w.X * dt, w.Y * dt, w.Z * dt)
			p.Transparency = u > 0.6 and (u - 0.6) / 0.4 or 0
		end)
		local s = 0.5 + math.random() * 0.6
		newPart(f, Enum.PartType.Block, Vector3.one * s, color, 0, Enum.Material.Slate, CFrame.new(pos))
	end
end

-- ============================================================================================================== per-dilo watch
local W = setmetatable({}, {__mode = "k"})
local function pieces(char, role)
	local list = {}
	for _, m in ipairs(char:GetChildren()) do
		if m:IsA("Model") and m.Name:sub(1, 6) == "DPart_" then
			for _, p in ipairs(m:GetChildren()) do if p:IsA("BasePart") and (not role or p:GetAttribute("DPartRole") == role) then table.insert(list, p) end end
		end
	end
	return list
end
local function rolePos(char, role)
	local list = pieces(char, role)
	if #list == 0 then return nil end
	local s = Vector3.zero
	for _, p in ipairs(list) do s += p.Position end
	return s / #list
end
local function muzzles(char, segName)
	local seg = char:FindFirstChild(segName)
	local root = seg and seg:FindFirstChild("Root")
	local out = {}
	if root then for _, a in ipairs(root:GetChildren()) do if a:IsA("Attachment") and a.Name:sub(1, 12) == "DPartMuzzle_" then table.insert(out, a) end end end
	table.sort(out, function(a, b) return a.Name < b.Name end)
	return out
end
local function findModel(name)
	if type(name) ~= "string" or name == "" then return nil end
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character and pl.Character.Name == name then return pl.Character end end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end
local function feetY(char)
	local r = char:FindFirstChild("HumanoidRootPart")
	if not r then return 0 end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return r.Position.Y - r.Size.Y / 2 - (hum and hum.HipHeight or 0)
end
local function rootPos(m) local r = m and m:FindFirstChild("HumanoidRootPart") return r and r.Position or nil end
local function headPos(m) local h = m and m:FindFirstChild("Head") local r = h and h:FindFirstChild("Root") return r and r.Position or rootPos(m) end
local function fresh(at) return at and now() - at <= 1 end

-- ---------------------------------------------------------------- Venom Gatling · A
local function watchGatling(char, st)
	char:GetAttributeChangedSignal("DiloGatlingAt"):Connect(function()
		local at = num(char, "DiloGatlingAt")
		if not on("dgatling") or not fresh(at) then return end
		local k = scaleK(char)
		local wind = num(char, "DiloGatlingWindup") or 0.4
		local left = math.max(0.05, at + wind - now())
		for _, mz in ipairs(muzzles(char, "Neck")) do A.charge(function() return mz.Parent and mz.WorldPosition or nil end, left, 0.7 * k) end
		local endT = wind + (num(char, "DiloGatlingTime") or 1)
		task.delay(math.max(0, at + endT - now()), function()
			if not char.Parent or not on("dgatling") then return end
			for _, mz in ipairs(muzzles(char, "Neck")) do A.vent(function() return mz.Parent and mz.WorldPosition or nil end, 1.3, 0.8 * k) end
			note("dgatling:vent")
		end)
		note("dgatling:windup")
	end)
	char:GetAttributeChangedSignal("DiloGatlingShot"):Connect(function()
		if not on("dgatling") then return end
		local sh = Lib.parseShot(char:GetAttribute("DiloGatlingShot"))
		if not sh then return end
		local k = scaleK(char)
		local s = 1.6 * k
		st.shotTo[sh.i] = sh.to
		A.muzzle(sh.from, (sh.to - sh.from), 1.2 * k)
		A.shot({from = sh.from, to = sh.to, flight = sh.flight, apex = 0.4 * k, s = s, kind = "dart", onArrive = function(p)
			if sh.target == "" then A.impact(p, 0.5 * k) end
		end})
		note("dgatling:shot")
	end)
	char:GetAttributeChangedSignal("DiloGatlingHit"):Connect(function()
		if not on("dgatling") then return end
		local s = char:GetAttribute("DiloGatlingHit")
		if typeof(s) ~= "string" then return end
		local name, i = s:match("^([^;]+);(%d+)")
		local p = (i and st.shotTo[tonumber(i)]) or rootPos(findModel(name))
		if p then A.impact(p, 1.1 * scaleK(char)) note("dgatling:hit") end
	end)
end

-- ---------------------------------------------------------------- Toxin Mortar · C
local function hazardRing(f, center, R)
	local list = Lib.wedges(R, 28, math.max(0.6, 0.08 * R))
	local base = {}
	for i, w in ipairs(list) do
		local p = newPart(f, Enum.PartType.Block, w.size, w.dark and C.cDark or C.cHaz, 0, Enum.Material.SmoothPlastic, CFrame.new(center) * w.cf)
		base[i] = w.cf
		p.Name = "HazardWedge"
	end
	return base
end
local function watchMortar(char, st)
	char:GetAttributeChangedSignal("DiloMortarAt"):Connect(function()
		local at = num(char, "DiloMortarAt")
		local to, from = char:GetAttribute("DiloMortarTo"), char:GetAttribute("DiloMortarFrom")
		if not on("dmortar") or not fresh(at) or typeof(to) ~= "Vector3" then return end
		local k = scaleK(char)
		local R = num(char, "DiloMortarRadius") or 12
		local wind, flight, cloudT = num(char, "DiloMortarWindup") or 0.275, num(char, "DiloMortarFlight") or 0.38, num(char, "DiloMortarTime") or 5
		local life = wind + flight + cloudT + 0.4
		local centre = Vector3.new(to.X, to.Y + 0.2, to.Z)
		local ring
		ring = effect(life, function(f, _, u)
			local t = f.t
			local spin = CFrame.Angles(0, -t * 0.6, 0)
			local a = t < 0.15 and t / 0.15 or (t > life - 0.5 and (life - t) / 0.5 or 1)
			for i, p in ipairs(f.parts) do
				if p.Name == "HazardWedge" then p.CFrame = CFrame.new(centre) * spin * f.base[i] p.Transparency = 1 - a * 0.95
				elseif p.Name == "Dot" then p.Transparency = (t < wind + flight and math.sin(os.clock() * 25) > 0) and 0 or (t < wind + flight and 0.7 or 1) end
			end
		end)
		ring.base = hazardRing(ring, centre, R)
		newPart(ring, Enum.PartType.Ball, Vector3.one * 2.2 * k, C.red, 0, Enum.Material.Neon, CFrame.new(centre + Vector3.new(0, 0.6, 0))).Name = "Dot"
		st.mortarRing = ring
		-- laser + alarm light + steam on the tube
		local tubeFn = function() local mz = muzzles(char, "Torso")[1] return (mz and mz.Parent and mz.WorldPosition) or (typeof(char:GetAttribute("DiloMortarFrom")) == "Vector3" and char:GetAttribute("DiloMortarFrom")) or rootPos(char) end
		local lz
		lz = effect(wind + flight * 0.6, function(f, _, u) local a = tubeFn() if a then setBar(f.parts[1], a, centre + Vector3.new(0, 0.6, 0), 0.16 * k) f.parts[1].Transparency = 0.3 + 0.7 * u end end)
		bar(lz, typeof(from) == "Vector3" and from or centre, centre, 0.16 * k, C.red, 0.3)
		local al
		al = effect(wind, function(f) local p = tubeFn() if p then local l = f.parts[1] l.CFrame = CFrame.new(p + Vector3.new(0, 1.2 * k, 0)) l.Color = math.sin(os.clock() * 15) > 0 and C.red or C.cHaz l.Transparency = math.sin(os.clock() * 30) > 0 and 0 or 0.85 end end)
		newPart(al, Enum.PartType.Ball, Vector3.one * 1.4 * k, C.red, 0, Enum.Material.Neon, CFrame.new(tubeFn() or centre))
		stream(wind, tubeFn, 40 * k, {tex = "smoke", c0 = Color3.fromHex("F4F4EC"), s0 = 0.9 * k, s1 = 3 * k, life = {0.4, 0.45}, speed = {8, 11}, spread = 70, t0 = 0.45, rot = 30})
		note("dmortar:windup")
	end)
	char:GetAttributeChangedSignal("DiloMortarFireAt"):Connect(function()
		local from, to = char:GetAttribute("DiloMortarFrom"), char:GetAttribute("DiloMortarTo")
		if not on("dmortar") or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then return end
		local k = scaleK(char)
		local flight = num(char, "DiloMortarFlight") or 0.38
		local dir = (Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit + Vector3.new(0, 1.1, 0)).Unit
		flash(from, 8 * k, C.cHi, 0.09, 0)
		flash(from, 5 * k, C.cHaz, 0.12)
		Cc.smokeBurst(from, dir, 4, k, C.cGrey, 20)
		burst(from, dir, 5, SPARK(C.cFire, C.cFire, 0.8 * k, 36, 0.25))
		local side = Vector3.new(dir.Z, 0, -dir.X)
		Cc.casing(from, side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis)
		-- the canister
		local s = 1.35 * k
		local apex = math.max(from.Y, to.Y) - math.min(from.Y, to.Y) + 6.5 * k
		local f
		f = effect(flight, function(_, dt, u)
			local p = from:Lerp(to, u) + Vector3.new(0, 4 * apex * u * (1 - u), 0)
			local u2 = math.min(1, u + 0.03)
			local q = from:Lerp(to, u2) + Vector3.new(0, 4 * apex * u2 * (1 - u2), 0)
			local cf = ((q - p).Magnitude > 1e-3 and CFrame.lookAt(p, q) or CFrame.new(p)) * CFrame.Angles(0, 0, f.t * 10)
			f.parts[1].CFrame = cf * CFrame.Angles(0, math.pi / 2, 0)
			f.parts[2].CFrame = cf * CFrame.Angles(0, math.pi / 2, 0)
			f.parts[3].CFrame = cf * CFrame.new(0, 0, -1.3 * s)
			f.h.CFrame = cf
		end)
		newPart(f, Enum.PartType.Cylinder, Vector3.new(2.6 * s, 1.8 * s, 1.8 * s), Color3.fromHex("4A5040"), 0, Enum.Material.Metal, CFrame.new(from))
		newPart(f, Enum.PartType.Cylinder, Vector3.new(0.7 * s, 1.9 * s, 1.9 * s), C.cHaz, 0, Enum.Material.Neon, CFrame.new(from))
		newPart(f, Enum.PartType.Ball, Vector3.one * 1.8 * s, C.cMain, 0, Enum.Material.Neon, CFrame.new(from))
		f.h = holder(f, CFrame.new(from))
		local pe = emitterOn(f.h, {tex = "smoke", c0 = C.cGrey, s0 = 2.4 * s, s1 = 5 * s, life = {1.0, 1.2}, speed = {0.5, 1}, drag = 2, t0 = 0.45, rot = 30})
		pe.Rate = 70 * s * cfg("rateMul", 1)
		pe.Enabled = true
		local pe2 = emitterOn(f.h, {tex = "smoke", c0 = C.cMain, s0 = 1.6 * s, s1 = 3 * s, life = {0.7, 0.8}, speed = {0.5, 1}, t0 = 0.5})
		pe2.Rate = 20 * cfg("rateMul", 1)
		pe2.Enabled = true
		-- tube smoke after the shot
		task.delay(0.35, function()
			if not char.Parent or not on("dmortar") then return end
			local fn = function() local mz = muzzles(char, "Torso")[1] return mz and mz.Parent and mz.WorldPosition or nil end
			stream(1.4, fn, 26, {tex = "smoke", c0 = Color3.fromHex("E8E8E0"), s0 = 1.4 * k, s1 = 4.4 * k, life = {1.0, 1.1}, speed = {5, 9}, spread = 20, t0 = 0.45, rot = 30}, nil, function(u) return 26 * (1 - u) end)
		end)
		note("dmortar:fire")
	end)
	char:GetAttributeChangedSignal("DiloMortarLandAt"):Connect(function()
		local to = char:GetAttribute("DiloMortarTo")
		if not on("dmortar") or typeof(to) ~= "Vector3" then return end
		local k = scaleK(char)
		local R, life = num(char, "DiloMortarRadius") or 12, num(char, "DiloMortarTime") or 5
		local c3 = to + Vector3.new(0, 3, 0)
		flash(c3, R * 2.2, C.cHi, 0.14, 0)
		flash(c3, R * 1.6, C.cHaz, 0.25)
		Cc.debris(to + Vector3.new(0, 1, 0), 14, Color3.fromHex("4A5040"), 26)
		burst(to + Vector3.new(0, 2, 0), Vector3.yAxis, 26, SPARK(C.cFire, C.cHaz, 1.2 * k, 46, 0.5))
		burst(to + Vector3.new(0, 2, 0), Vector3.yAxis, 16, {tex = "smoke", c0 = C.cMain, c1 = C.cSmoke, s0 = 6 * k, s1 = 12 * k, life = {1.0, 1.2}, speed = {R * 2, R * 3}, spread = 85, drag = 2.5, t0 = 0.3, rot = 40})
		-- the cloud: a Box emitter over the circle
		local f
		f = effect(life + 3.2, function(_, _, u)
			local alive = f.t < life
			f.pe.Rate = alive and 30 * (R / 18) * cfg("rateMul", 1) or 0
			f.pe2.Rate = alive and 12 * cfg("rateMul", 1) or 0
		end)
		f.h = holder(f, CFrame.new(to + Vector3.new(0, 4 * k, 0)), Vector3.new(R * 1.8, 6 * k, R * 1.8))
		f.pe = emitterOn(f.h, {tex = "smoke", c0 = C.cMain, c1 = C.cSmoke, s0 = 9 * k, s1 = 17 * k, life = {2.2, 3.0}, speed = {0.3, 1.2}, spread = 180, drag = 0.5, t0 = 0.35, rot = 15,
			shape = Enum.ParticleEmitterShape.Box})
		f.pe.Enabled = true
		f.pe:Emit(math.floor(20 * cfg("rateMul", 1)))
		f.pe2 = emitterOn(f.h, {tex = "spark", c0 = C.cMain, s0 = 0.8 * k, life = {0.4, 0.5}, speed = {6, 12}, light = 1, shape = Enum.ParticleEmitterShape.Box})
		f.pe2.Enabled = true
		note("dmortar:land")
	end)
end

-- ---------------------------------------------------------------- Sonic Hiss · B
local function watchHiss(char, st)
	local spk = function() return rolePos(char, "cone") or headPos(char) end
	char:GetAttributeChangedSignal("DiloHissAt"):Connect(function()
		local at = num(char, "DiloHissAt")
		if not on("dhiss") or not fresh(at) then return end
		local k = scaleK(char)
		B.charge(spk, math.max(0.05, at + (num(char, "DiloHissWindup") or 0.5) - now()), 2.2 * k, C.bMain, C.bHi, C.bAcc)
		note("dhiss:windup")
	end)
	char:GetAttributeChangedSignal("DiloHissBlastAt"):Connect(function()
		local at = num(char, "DiloHissBlastAt")
		if not on("dhiss") or not fresh(at) then return end
		local k = scaleK(char)
		local r = char:FindFirstChild("HumanoidRootPart")
		if not r then return end
		local fwd = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
		fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
		local range, half = num(char, "DiloHissRange") or 30, num(char, "DiloHissAngle") or 35
		local from = spk() or (r.Position + Vector3.new(0, 3 * k, 0))
		B.star(from, 16 * k, C.bHi, 0.16)
		flash(from, 12 * k, C.bMain, 0.2)
		for i = 0, 5 do
			task.delay(i * 0.05, function()
				local f
				local y0 = from.Y - 2 * k
				f = effect(0.55, function(_, _, u) local e = 1 - (1 - u) ^ 3 f.a.h.CFrame = CFrame.new(Vector3.new(from.X, y0 - u * 4 * k, from.Z)) f.a:set(math.max(0.5, range * e), u) end)
				f.a = beamArc(f, Vector3.new(from.X, y0, from.Z), fwd, 1, half, 0.6 * k, i % 2 == 1 and C.bAcc or C.bMain)
			end)
		end
		-- shock half-shell along the facing
		local sh
		sh = effect(0.45, function(_, _, u) local e = 1 - (1 - u) ^ 3 sh.mesh.Scale = Vector3.new(range * 0.6 * e + 0.1, range * 0.35 * e + 0.1, range * e + 0.1) sh.parts[1].Transparency = 0.6 + 0.4 * u
			sh.parts[1].CFrame = CFrame.lookAt(from, from + fwd) * CFrame.new(0, 0, -range * 0.5 * e) end)
		local p = newPart(sh, Enum.PartType.Block, Vector3.one, C.bMain, 0.6, Enum.Material.ForceField, CFrame.new(from))
		local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Sphere m.Scale = Vector3.one * 0.1 m.Parent = p
		sh.mesh = m
		-- ground rays (the glowing cone)
		local gy = feetY(char) + 0.25
		local base = Vector3.new(from.X, gy, from.Z)
		local rays
		rays = effect(0.6, function(_, _, u)
			local e = 1 - (1 - math.min(1, u * 2.2)) ^ 3
			for i, q in ipairs(rays.parts) do
				local a = math.rad(-half + (i - 1) * (2 * half) / (#rays.parts - 1))
				local d = Vector3.new(fwd.X * math.cos(a) - fwd.Z * math.sin(a), 0, fwd.X * math.sin(a) + fwd.Z * math.cos(a))
				setBar(q, base, base + d * math.max(0.2, range * e), 0.35 * k)
				q.Transparency = 0.2 + 0.8 * u
			end
		end)
		for _ = 1, 7 do bar(rays, base, base + fwd, 0.35 * k, C.bMain, 0.2) end
		burst(from, fwd, 26, SPARK(C.bHi, C.bMain, 1.2 * k, range * 2.2, 0.45))
		-- the mute ring over each silenced dino
		for _, name in ipairs(Lib.names(char:GetAttribute("DiloHissHits"))) do
			local mdl = findModel(name)
			if mdl then
				task.delay(0.08, function()
					local untilT = num(mdl, "SilencedUntil") or (now() + 3)
					local life = math.max(0.3, untilT - now())
					local mk = scaleK(mdl)
					local f
					f = effect(life, function(_, _, u)
						local h = headPos(mdl)
						if not h then return end
						local c = h + Vector3.new(0, 3.5 * mk, 0)
						local a = u > 0.9 and (u - 0.9) / 0.1 or 0
						f.r.h.CFrame = CFrame.new(c)
						f.r:set(3.2 * mk, a)
						local rot = CFrame.new(c) * CFrame.Angles(0, os.clock() * 2, 0)
						local blink = 0.2 + 0.4 * (math.sin(os.clock() * 10) > 0 and 0 or 1)
						f.x1.CFrame = rot * CFrame.Angles(0, math.rad(45), 0) f.x1.Transparency = math.max(blink, a)
						f.x2.CFrame = rot * CFrame.Angles(0, math.rad(-45), 0) f.x2.Transparency = math.max(blink, a)
					end)
					f.r = beamRing(f, CFrame.new(headPos(mdl) or Vector3.zero), 3.2 * mk, 0.3 * mk, C.violet, 0)
					f.x1 = newPart(f, Enum.PartType.Block, Vector3.new(0.3 * mk, 0.3 * mk, 6.2 * mk), C.xRed, 0.2, Enum.Material.Neon)
					f.x2 = newPart(f, Enum.PartType.Block, Vector3.new(0.3 * mk, 0.3 * mk, 6.2 * mk), C.xRed, 0.2, Enum.Material.Neon)
				end)
			end
		end
		task.delay(0.55, function() if char.Parent and on("dhiss") then B.vent(spk, 0.9, k, C.bMain) end end)
		note("dhiss:blast")
	end)
end

-- ---------------------------------------------------------------- Spine Burst · A
local function watchSpine(char, st)
	char:GetAttributeChangedSignal("DiloSpineAt"):Connect(function()
		local at = num(char, "DiloSpineAt")
		if not on("dspine") or not fresh(at) then return end
		local k = scaleK(char)
		local wind = num(char, "DiloSpineWindup") or 0.42
		local f
		f = effect(math.max(0.05, at + wind - now()), function(_, dt, u)
			f.acc = (f.acc or 0) + dt * (30 + 40 * u) * cfg("rateMul", 1)
			local barbs = pieces(char, "barb")
			while f.acc >= 1 and #barbs > 0 do
				f.acc -= 1
				local b = barbs[math.random(1, #barbs)]
				if b.LocalTransparencyModifier < 0.9 then
					f.h.CFrame = CFrame.lookAt(b.Position, b.Position - Vector3.yAxis)
					f.pe:Emit(1)
				end
			end
		end)
		f.h = holder(f, CFrame.new(rootPos(char) or Vector3.zero))
		f.pe = emitterOn(f.h, DROP(C.gMain, C.gDeep, 0.6 * k, 3))
		note("dspine:windup")
	end)
	char:GetAttributeChangedSignal("DiloSpineBurstAt"):Connect(function()
		if not on("dspine") then return end
		local r = char:FindFirstChild("HumanoidRootPart")
		if not r then return end
		local k = scaleK(char)
		local n = math.clamp(math.floor(num(char, "DiloSpineCount") or 12), 1, 24)
		local fwd = char:GetAttribute("DiloSpineDir")
		if typeof(fwd) ~= "Vector3" or fwd.Magnitude < 1e-3 then fwd = r.CFrame.LookVector end
		fwd = Vector3.new(fwd.X, 0, fwd.Z).Unit
		local reach, flight = num(char, "DiloSpineRange") or 44, math.max(0.13, num(char, "DiloSpineFlight") or 0.13)
		local origin = r.Position + Vector3.new(0, 2.5 * k, 0)
		for i = 0, n - 1 do
			local d = CFrame.Angles(0, i * 2 * math.pi / n, 0) * fwd
			local from = origin + d * 2 * k
			A.muzzle(from, d, 0.35 * k)
			A.shot({from = from, to = origin + d * reach + Vector3.new(0, -1.5 * k, 0), flight = flight, apex = 0, s = 0.8 * k, kind = "quill", onArrive = function(p) flash(p, 2 * k, C.white, 0.1) end})
		end
		A.ring(Vector3.new(r.Position.X, feetY(char) + 0.25, r.Position.Z), 22 * k)
		for _, h in ipairs(Lib.parseSpineHits(char:GetAttribute("DiloSpineHits"))) do
			local m = findModel(h.name)
			if m then task.delay(flight, function() local p = rootPos(m) if p then A.impact(p, 0.9 * k) end end) end
		end
		task.delay(0.3, function()
			if not char.Parent or not on("dspine") then return end
			A.vent(function() local nk = char:FindFirstChild("Neck") local rr = nk and nk:FindFirstChild("Root") return rr and rr.Position or nil end, 1.0, 0.8 * k)
		end)
		note("dspine:burst")
	end)
end

-- ---------------------------------------------------------------- Antivenom Pump · B (blue)
local function watchPump(char, st)
	local tankFn = function() return rolePos(char, "fluid") or rolePos(char, "tank") or rootPos(char) end
	char:GetAttributeChangedSignal("DiloPumpAt"):Connect(function()
		local at = num(char, "DiloPumpAt")
		if not on("dpump") or not fresh(at) then return end
		local k = scaleK(char)
		B.charge(tankFn, math.max(0.05, at + (num(char, "DiloPumpWindup") or 0.62) - now()), 1.6 * k, C.pMain, C.pHi, C.pAcc)
		note("dpump:windup")
	end)
	char:GetAttributeChangedSignal("DiloPumpJoltAt"):Connect(function()
		local at = num(char, "DiloPumpJoltAt")
		if not on("dpump") or not fresh(at) then return end
		local k = scaleK(char)
		local p = tankFn()
		local r = char:FindFirstChild("HumanoidRootPart")
		if not (p and r) then return end
		B.star(p, 22 * k, C.pHi, 0.2)
		flash(p, 16 * k, C.pMain, 0.25)
		shell(r.Position + Vector3.new(0, 1 * k, 0), 14 * k, C.pMain, 0.45)
		local gy = feetY(char)
		for i = 0, 3 do
			task.delay(i * 0.06, function()
				local f
				f = effect(0.45, function(_, _, u)
					local rp = rootPos(char) or r.Position
					local y = gy + (20 * k - 19 * k * (u * u * (3 - 2 * u)))
					f.r.h.CFrame = CFrame.new(rp.X, y, rp.Z)
					f.r:set((9 + 3 * math.sin(u * math.pi)) * k, u * 0.6)
				end)
				f.r = beamRing(f, CFrame.new(r.Position), 9 * k, 0.35 * k, i % 2 == 1 and C.pAcc or C.pMain, 0)
			end)
		end
		local f
		f = effect(0.6, nil)
		local hb = holder(f, CFrame.new(r.Position + Vector3.new(0, 1 * k, 0)), Vector3.new(6 * k, 8 * k, 14 * k))
		local pe = emitterOn(hb, {tex = "spark", c0 = C.bMain, c1 = C.white, s0 = 1.2 * k, life = {0.45, 0.5}, speed = {20, 32}, light = 1, drag = 2, shape = Enum.ParticleEmitterShape.Box})
		pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		pe:Emit(math.floor(40 * cfg("rateMul", 1)))
		groundRing(Vector3.new(r.Position.X, gy + 0.2, r.Position.Z), 16 * k, C.pHi, 0.5, 0.5 * k)
		note("dpump:jolt")
	end)
	-- the immune shell (follows the dilo while DiloImmuneUntil)
	local function shellOn()
		local untilT = num(char, "DiloImmuneUntil")
		if not on("dpump") or not untilT or untilT <= now() then return end
		if st.pShell and not st.pShell.done then st.pShell.untilT = untilT return end
		local k = scaleK(char)
		local R = 11.5 * k
		local f
		f = effect(untilT - now() + 0.05, function(_, _, u)
			local rp = rootPos(char)
			if not rp then return end
			local left = (f.untilT or untilT) - now()
			if left <= 0 then f.t = f.life return end
			local total = (f.untilT or untilT) - f.t0
			local flick = left < total * 0.15 and (math.sin(os.clock() * 40) > 0 and 1 or 0.3) or 1
			local grow = math.min(1, f.t / 0.2)
			local c = rp + Vector3.new(0, 1 * k, 0)
			f.ball.CFrame = CFrame.new(c)
			f.ball.Size = Vector3.one * 2 * R * (1 - (1 - grow) ^ 3) + Vector3.one * 0.1
			f.ball.Transparency = 1 - (0.5 + 0.4 * f.j) * flick
			f.j = math.max(0, f.j - 1 / 60 * 3)
			for i, rr in ipairs(f.rings) do
				rr.h.CFrame = CFrame.new(c) * CFrame.Angles(0, os.clock() * 0.5 + i, 0) * CFrame.Angles(math.rad(-60 + i * 30), 0, 0)
				rr:set(R * (1 - (1 - grow) ^ 3) * 0.98, 1 - 0.75 * flick)
			end
		end)
		f.t0, f.j, f.untilT = now(), 0, untilT
		f.ball = newPart(f, Enum.PartType.Ball, Vector3.one, C.pMain, 0.5, Enum.Material.ForceField)
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = C.pMain
		hl.OutlineTransparency = 0.2
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = f.ball
		hl.Parent = f.ball
		f.rings = {}
		for i = 1, 3 do f.rings[i] = beamRing(f, CFrame.new(f.ball.Position), R, 0.25 * k, C.pAcc, 0.5) end
		st.pShell = f
		note("dpump:shell")
	end
	char:GetAttributeChangedSignal("DiloImmuneUntil"):Connect(shellOn)
	char:GetAttributeChangedSignal("DiloImmuneBlockAt"):Connect(function()
		if not on("dpump") then return end
		local k = scaleK(char)
		local r = char:FindFirstChild("HumanoidRootPart")
		if not r then return end
		local cam = workspace.CurrentCamera
		local toCam = cam and (cam.CFrame.Position - r.Position) or r.CFrame.LookVector
		local n = Vector3.new(toCam.X, 0, toCam.Z)
		n = n.Magnitude > 1e-3 and n.Unit or r.CFrame.LookVector
		local p = r.Position + Vector3.new(0, 1 * k, 0) + n * 11.5 * k
		B.star(p, 12 * k, C.pHi, 0.16)
		axisRing(p, n, 5 * k, C.pHi, 0.35, 0.3 * k)
		burst(p, n, 10, SPARK(C.pMain, C.pHi, 0.9 * k, 26, 0.35))
		if st.pShell then st.pShell.j = 1 end
		note("dpump:block")
	end)
end

-- ---------------------------------------------------------------- Spring Jets · B
local function jetsKit(char, st)
	if st.jk and not st.jk.done then return st.jk end
	local k = scaleK(char)
	local f
	f = effect(1e9, function(_, dt)
		local mzs = muzzles(char, "Tail1")
		local mz = mzs[1]
		local want = os.clock() < (f.offAt or 0) and mz ~= nil and mz.Parent ~= nil
		local kk = want and math.min(1, (f.k or 0) + dt / 0.05) or math.max(0, (f.k or 0) - dt / 0.12)
		f.k = kk
		for _, p in ipairs(f.parts) do if p ~= f.h then p.Transparency = 1 end end
		f.pe.Rate, f.ps.Rate = 0, 0
		if kk <= 0 or not mz then return end
		local base = mz.WorldCFrame
		local back = (char:FindFirstChild("HumanoidRootPart") and -char.HumanoidRootPart.CFrame.LookVector or base.LookVector)
		local pos = base.Position
		local cf = CFrame.lookAt(pos, pos + back)
		local fl = 1 + 0.15 * math.sin(os.clock() * 70)
		local L1, L2 = 11 * k * 1.5 * kk * fl, 6 * k * 1.5 * kk / fl
		f.outer.Size = Vector3.new(3.6 * 1.5 * k * kk, 3.6 * 1.5 * k * kk, L1) f.outer.CFrame = cf * CFrame.new(0, 0, -L1 / 2) f.outer.Transparency = 1 - 0.55 * kk
		f.inner.Size = Vector3.new(1.6 * 1.5 * k * kk, 1.6 * 1.5 * k * kk, L2) f.inner.CFrame = cf * CFrame.new(0, 0, -L2 / 2) f.inner.Transparency = 1 - 0.9 * kk
		for i, d in ipairs(f.dia) do d.CFrame = cf * CFrame.new(0, 0, -(2 + i * 2.6) * 1.5 * k * kk) d.Transparency = 1 - (0.9 - i * 0.2) * kk * (0.6 + 0.4 * math.sin(os.clock() * 60 + i)) end
		f.h.CFrame = CFrame.lookAt(pos, pos + back)
		f.pe.Rate, f.ps.Rate = 400 * kk * cfg("rateMul", 1), 60 * kk * cfg("rateMul", 1)
	end)
	f.outer = newPart(f, Enum.PartType.Ball, Vector3.one, C.bMain, 1, Enum.Material.Neon)
	f.inner = newPart(f, Enum.PartType.Ball, Vector3.one, C.bHi, 1, Enum.Material.Neon)
	f.outer.Shape, f.inner.Shape = Enum.PartType.Block, Enum.PartType.Block
	for _, p in ipairs({f.outer, f.inner}) do local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Sphere m.Parent = p end
	f.dia = {}
	for i = 1, 3 do f.dia[i] = newPart(f, Enum.PartType.Ball, Vector3.one * (2.2 - i * 0.4) * 1.5 * k, C.bHi, 1, Enum.Material.Neon) end
	f.h = holder(f, CFrame.new())
	f.pe = emitterOn(f.h, {tex = "fire", c0 = C.bHi, c1 = C.bMain, s0 = 2.6 * 1.5 * k, s1 = 0.6, life = {0.22, 0.3}, speed = {26, 42}, spread = 6, light = 1})
	f.ps = emitterOn(f.h, SPARK(C.bMain, C.bAcc, 1 * k, 60, 0.3))
	f.pe.Enabled, f.ps.Enabled = true, true
	st.jk = f
	return f
end
local function chevronTrail(char, untilT)
	local from, to = char:GetAttribute("DiloJetsFrom"), char:GetAttribute("DiloJetsTo")
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then return end
	local k = scaleK(char)
	local gy = feetY(char) + 0.25
	local a, b = Vector3.new(from.X, gy, from.Z), Vector3.new(to.X, gy, to.Z)
	local d = b - a
	local L = d.Magnitude
	if L < 2 then return end
	local dirU = d.Unit
	local side = Vector3.new(-dirU.Z, 0, dirU.X)
	local life = math.max(0.3, untilT - now())
	local f
	f = effect(life, function(_, _, u)
		local fade = math.min(1, f.t / 0.05) * math.min(1, (1 - u) * 5)
		for i, c in ipairs(f.chev) do
			local w = 0.5 + 0.5 * math.sin(c.d / 6 * math.pi - os.clock() * 9)
			local tr = 1 - fade * (0.35 + 0.6 * w)
			c.l.Transparency, c.r.Transparency = tr, tr
		end
	end)
	f.chev = {}
	for _, dd in ipairs(Lib.chevrons(L, 6 * k)) do
		local tip = a + dirU * dd
		local back = tip - dirU * 1.8 * k
		f.chev[#f.chev + 1] = {d = dd, l = bar(f, back + side * 1.8 * k, tip, 0.4 * k, C.bMain, 1), r = bar(f, back - side * 1.8 * k, tip, 0.4 * k, C.bMain, 1)}
	end
	local sp
	sp = effect(life + 0.8, function() sp.pe.Rate = sp.t < life and 30 * (1 - sp.t / life) * cfg("rateMul", 1) or 0 end)
	local hb = holder(sp, CFrame.lookAt(a:Lerp(b, 0.5), b), Vector3.new(3.6 * k, 0.4, L))
	sp.pe = emitterOn(hb, {tex = "spark", c0 = C.bMain, c1 = C.bAcc, s0 = 1 * k, life = {0.6, 0.7}, speed = {5, 9}, light = 1, shape = Enum.ParticleEmitterShape.Box})
	sp.pe.Acceleration = Vector3.new(0, 4, 0)
	sp.pe.Enabled = true
	note("djets:trail")
end
local function watchJets(char, st)
	char:GetAttributeChangedSignal("DiloJetsTrailUntil"):Connect(function()
		local u = num(char, "DiloJetsTrailUntil")
		if on("djets") and u and u > now() then chevronTrail(char, u) end
	end)
end
RunService.RenderStepped:Connect(function()
	local T = now()
	local me = Players.LocalPlayer.Character
	for char, st in pairs(W) do
		if char.Parent and on("djets") then
			local burning
			if char == me then burning = char:GetAttribute("DiloJetsLaunchState") == "dash"
			else
				local ja, jd, jt = num(char, "DiloJetsAt"), num(char, "DiloJetsDelay") or 0, num(char, "DiloJetsTime") or 0.25
				burning = ja ~= nil and char:GetAttribute("DiloJetsResult") == "dash" and T >= ja + jd and T < ja + jd + jt
			end
			if burning then
				local kit = jetsKit(char, st)
				if (kit.offAt or 0) < os.clock() then note("djets:burn") end
				kit.offAt = os.clock() + 0.45
			end
		elseif st.jk and not char.Parent then
			finish(st.jk)
			st.jk = nil
		end
	end
end)

-- ---------------------------------------------------------------- Venom Overdrive · A (+ goo darts)
local function watchOver(char, st)
	local coreFn = function() return rolePos(char, "core") or rootPos(char) end
	char:GetAttributeChangedSignal("DiloOverdriveAt"):Connect(function()
		local at, start = num(char, "DiloOverdriveAt"), num(char, "DiloOverdriveStartAt")
		if not on("dover") or not fresh(at) or not start then return end
		local k = scaleK(char)
		A.charge(coreFn, math.max(0.05, start - now()), 2.4 * k)
		task.delay(math.max(0, start - now()), function()
			if not char.Parent or not on("dover") then return end
			local p = coreFn()
			if p then
				A.impact(p, 2.2 * k)
				flash(p, 22 * k, C.gHi, 0.3)
			end
			A.ring(Vector3.new((rootPos(char) or p).X, feetY(char) + 0.25, (rootPos(char) or p).Z), 18 * k)
			local untilT = num(char, "DiloOverdriveUntil") or (now() + 4)
			local life = math.max(0.2, untilT - now())
			-- the aura: drips off the body, fumes from the mouth
			local f
			f = effect(life + 0.7, function()
				local r = char:FindFirstChild("HumanoidRootPart")
				if not r then return end
				f.h.CFrame = r.CFrame
				local alive = f.t < life and (num(char, "DiloOverdriveUntil") or 0) > now()
				f.pe.Rate = alive and 60 * cfg("rateMul", 1) or 0
				local tip = char:FindFirstChild("Head_tip", true)
				if tip and tip:IsA("BasePart") then f.h2.CFrame = CFrame.new(tip.Position) end
				f.pe2.Rate = alive and 14 * cfg("rateMul", 1) or 0
			end)
			f.h = holder(f, CFrame.new(p or Vector3.zero), Vector3.new(4 * k, 6 * k, 16 * k))
			f.pe = emitterOn(f.h, {tex = "smoke", c0 = C.gMain, c1 = C.gHi, s0 = 0.9 * k, s1 = 0.4 * k, life = {0.5, 0.6}, speed = {0, 1}, accel = Vector3.new(0, -30, 0), t0 = 0, light = 0.25, shape = Enum.ParticleEmitterShape.Box})
			f.pe.Enabled = true
			f.h2 = holder(f, CFrame.new(p or Vector3.zero))
			f.pe2 = emitterOn(f.h2, {tex = "smoke", c0 = C.gGlow, s0 = 1.6 * k, s1 = 3.8 * k, life = {0.8, 0.9}, speed = {2, 3}, spread = 25, accel = Vector3.new(0, 1, 0), t0 = 0.55, rot = 30})
			f.pe2.EmissionDirection = Enum.NormalId.Top
			f.pe2.Enabled = true
			task.delay(life, function() if char.Parent and on("dover") then A.vent(coreFn, 1.2, 1.6 * k) end end)
			note("dover:on")
		end)
		note("dover:windup")
	end)
	-- goo darts while in Overdrive (DiloFX 1.3 draws no glob then)
	char:GetAttributeChangedSignal("DiloDartAt"):Connect(function()
		if not on("dover") or (num(char, "DiloOverdriveUntil") or 0) <= now() then return end
		local from, to = char:GetAttribute("DiloDartFrom"), char:GetAttribute("DiloDartTo")
		local flight, at = num(char, "DiloDartFlight"), num(char, "DiloDartAt")
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not flight or not at then return end
		local left = flight - (now() - at)
		if left <= 0.02 then return end
		local k = scaleK(char)
		local start = from:Lerp(to, math.clamp((now() - at) / flight, 0, 1))
		A.muzzle(from, to - from, 0.7 * k)
		local tg = char:GetAttribute("DiloDartTarget")
		A.shot({from = start, to = to, flight = left, apex = 0.25 * k, s = 1.0 * k, kind = "dart", onArrive = function(p) if not (typeof(tg) == "string" and tg ~= "") then A.impact(p, 0.6 * k) end end})
		note("dover:dart")
	end)
end

-- ---------------------------------------------------------------- who to watch
local function watch(char)
	if W[char] then return end
	local st = {shotTo = {}}
	W[char] = st
	watchGatling(char, st)
	watchMortar(char, st)
	watchHiss(char, st)
	watchSpine(char, st)
	watchPump(char, st)
	watchJets(char, st)
	watchOver(char, st)
end
local function onModel(m)
	if m:GetAttribute("Species") == "Dilo" then watch(m) end
	m:GetAttributeChangedSignal("Species"):Connect(function() if m:GetAttribute("Species") == "Dilo" then watch(m) end end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(onModel)
	if pl.Character then onModel(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
