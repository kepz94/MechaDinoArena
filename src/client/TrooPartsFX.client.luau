-- TrooPartsFX v1.0 (Mecha Dino Arena) — the Troodon's mecha button parts, build 1: the layered VFX on every client.
-- MDA-351, plan docs/plans/TROODON_PARTS_v1.0.md ticket 7; spec tools/mockup/troodon_parts_looks.js ("VFX, in Roblox
-- pieces" per part; Kepu 2026-11-06 20:11 "real vfx ... consistent w the rest of the rosters"). Reads TrooMovesServer 1.x's
-- stamps (server time) on every troodon character and draws locally in Workspace.TrooPartsFX (never replicated). Every move:
-- wind-up -> action -> result -> recovery; no landing FX. Effects only on troodons and their targets.
-- * Mender Drone (green 8DFFB6, the Med-Station heal look): wind-up (TrooMenderAt .. + TrooPartsFX_menderWindup 0.45) the
--   dock pieces light up (PointLight) and sparkle; action: the carried drone pieces hide and a drone (dark shell, green Neon
--   eye, plate wings, Trail, PointLight) flies on an arc to TrooMenderTarget, arriving at TrooMenderArriveAt; result: it
--   orbits the target (radius TrooPartsFX_menderOrbit 3.5 x scale, 4 x scale up) with a green Beam every 0.25 s and a
--   MedWave-style ground ring every 1 s until the end; TrooMenderHopAt: flies to TrooMenderHopTo; recovery: at TrooMenderEndAt
--   it flies back to the dock (0.75 s) and the pieces come back with a sparkle.
-- * Arc Lantern (the raptor Shock Mine look: VOLT 127,233,255 / core 225,250,255): wind-up (.. + 0.42) the lantern piece
--   flickers (PointLight) and crackles (sparks); action: the piece hides, a lantern (volt Neon core, Glass shell, brass cap,
--   Trail, PointLight) flies TrooLanternFrom -> TrooLanternTo over TrooLanternFlight on an arc; result: it lands, opens (the
--   shell clears, the light grows) and every TrooLanternZapAt draws a jagged arc (6 Beams, re-drawn every 0.06 s for 0.3 s)
--   from the lantern / the last target to the newest name in TrooLanternChainList, a MineBurst ball and sparks on it;
--   recovery: TrooPartsFX_lanternLinger (0.9 s) after the last zap the lantern fades and the piece comes back.
-- * Sap Wall (the TrooFX pod look: FFC35A pod, FFE2A0 flash, FFB43A embers): wind-up (.. + 0.34) the pod piece glows and drips;
--   action: a sap pod (Neon, Trail) flies TrooSapFrom -> TrooSapTo over TrooSapFlight; result: a splat flash + embers, and
--   each new wall in Workspace.TrooWalls gets a wet amber sheen that sets (Transparency 0.45 -> 1 over 0.8 s) and a Neon rim at
--   its base; a hit the wall stops (WallBlockedAt on a wall part, SapWallBlock 1.1) flashes at WallBlockedPos; recovery: when
--   the wall goes, its segments crumble (amber chunks fall and fade), and the pod piece comes back 1.15 s after the press.
-- * Feather Shed (the Energy Shield dome + a shockwave ring + feathers): wind-up (TrooShedAt .. + 0.15) the release bolts flash
--   (white light); action: the shed plates are flung off (local clones, spinning, fading 0.7 s), a feather burst (40) and a flat
--   Neon ring out to TrooPartShedKnockRadius (or 6 x scale); result: a ForceField-material shell round the troodon until
--   TrooShedImmuneUntil; recovery: the plates come back at its end.
-- * Portal Feathers (TrooFX teal 2FE6C8 / A8FFF0, brass vanes): wind-up (.. + 0.4) the tail rings glow; action: ring A flies
--   to TrooPortalA (0.35 s), ring B (from + 0.52) to TrooPortalB (0.8 s), each with a Trail; result: TrooPortalOpenAt /
--   TrooPortalOpen2At open them (flash + ring wave) into standing rings (12 teal Neon blocks, 8 brass vanes, a spinning swirl
--   film) until TrooPortalUntil; any character's TrooPortalUsedAt flashes both ends (TrooPortalFrom / TrooPortalTo) with
--   feathers; recovery: at the end the rings shrink and fade and the tail pieces come back.
-- Carried pieces (TrooPartsServer 1.0 OPart_<id>, OPartRole carry / carry1 / carry2 / shed) are hidden with
-- LocalTransparencyModifier only (the server weld and fit are untouched).
-- Switches (script attributes, read at each event): TrooPartsFXEnabled, TrooPartsFX_omenderEnabled, _olanternEnabled,
--   _osapwallEnabled, _oshedEnabled, _oportalEnabled (default true each). Numbers: script attributes TrooPartsFX_<name> (see
--   CFG). Diagnostics: script TrooPartsFXVersion, TrooPartsFXLast ("<id>:<phase>"), TrooPartsFXEvents (count).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
script:SetAttribute("TrooPartsFXVersion", VERSION)
local CFG = {menderWindup = 0.45, menderFly = 0.75, menderBack = 0.75, menderOrbit = 3.5, menderTick = 0.25, lanternWindup = 0.42,
	lanternLinger = 0.9, lanternArc = 6, sapWindup = 0.34, sapArc = 7, sapReturn = 1.15, shedWindup = 0.15, shedFling = 0.7,
	shedRadius = 6, portalWindup1 = 0.4, portalWindup2 = 0.52, portalFly1 = 0.35, portalFly2 = 0.8, portalRing = 3, portalUp = 3.5}
for k, v in pairs(CFG) do
	if script:GetAttribute("TrooPartsFX_" .. k) == nil then script:SetAttribute("TrooPartsFX_" .. k, v) end
end
for _, k in ipairs({"TrooPartsFXEnabled", "TrooPartsFX_omenderEnabled", "TrooPartsFX_olanternEnabled", "TrooPartsFX_osapwallEnabled",
	"TrooPartsFX_oshedEnabled", "TrooPartsFX_oportalEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function cfg(k) return tonumber(script:GetAttribute("TrooPartsFX_" .. k)) or CFG[k] end
local function on(id) return script:GetAttribute("TrooPartsFXEnabled") ~= false and script:GetAttribute("TrooPartsFX_" .. id .. "Enabled") ~= false end
local function now() return workspace:GetServerTimeNow() end
local function diag(id, phase)
	script:SetAttribute("TrooPartsFXLast", id .. ":" .. phase)
	script:SetAttribute("TrooPartsFXEvents", (script:GetAttribute("TrooPartsFXEvents") or 0) + 1)
end

local GREEN, GREEN_L = Color3.fromHex("8DFFB6"), Color3.fromHex("D8FFE6")
local VOLT, CORE = Color3.fromRGB(127, 233, 255), Color3.fromRGB(225, 250, 255)
local AMBER, FLASH, EMBER = Color3.fromHex("FFC35A"), Color3.fromHex("FFE2A0"), Color3.fromHex("FFB43A")
local TEAL, TEAL_L, BRASS = Color3.fromHex("2FE6C8"), Color3.fromHex("A8FFF0"), Color3.fromHex("C8913A")
local DARK, PLATE = Color3.fromHex("23262C"), Color3.fromHex("5D544A")
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local folder = workspace:FindFirstChild("TrooPartsFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TrooPartsFX"
	folder.Parent = workspace
end

-- helpers ------------------------------------------------------------------------------------------------------------------
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	if not props.Parent then p.Parent = folder end
	return p
end
local function ball(d, color, mat, tr)
	return part({Shape = Enum.PartType.Ball, Size = Vector3.one * d, Color = color, Material = mat or Enum.Material.Neon, Transparency = tr or 0})
end
local function light(p, color, range, br)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, br or 2, false
	l.Parent = p
	return l
end
local function trail(p, color, w)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, w / 2, 0), Vector3.new(0, -w / 2, 0)
	a0.Parent, a1.Parent = p, p
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new(color)
	t.Transparency = NumberSequence.new(0.2, 1)
	t.Lifetime, t.LightEmission, t.FaceCamera = 0.35, 1, true
	t.Parent = p
	return t
end
local function fade(p, dur, size)
	if not p or not p.Parent then return end
	local goal = {Transparency = 1}
	if size then goal.Size = size end
	TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	for _, l in ipairs(p:GetDescendants()) do
		if l:IsA("PointLight") then TweenService:Create(l, TweenInfo.new(dur), {Brightness = 0}):Play() end
	end
	Debris:AddItem(p, dur + 0.05)
end
local function burst(pos, color, n, speed, size, life)
	local p = part({Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos)})
	local e = Instance.new("ParticleEmitter")
	e.Texture, e.Color, e.LightEmission = SPARK_TEX, ColorSequence.new(color), 1
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0)})
	e.Transparency = NumberSequence.new(0, 1)
	e.Speed, e.SpreadAngle = NumberRange.new(speed * 0.5, speed), Vector2.new(180, 180)
	e.Lifetime, e.Drag, e.Rate, e.Enabled = NumberRange.new(life * 0.6, life), 2, 0, false
	e.Acceleration = Vector3.new(0, -8, 0)
	e.Parent = p
	e:Emit(n)
	Debris:AddItem(p, life + 0.2)
end
local function flashBall(pos, color, d0, d1, dur)
	local b = ball(d0, color)
	b.CFrame = CFrame.new(pos)
	b.Transparency = 0.1
	light(b, color, d1 * 2, 3)
	fade(b, dur, Vector3.one * d1)
end
local function groundRing(pos, color, r0, r1, dur)
	local d = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, r0 * 2, r0 * 2), Color = color, Transparency = 0.35,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))})
	fade(d, dur, Vector3.new(0.15, r1 * 2, r1 * 2))
end
local function arcFly(p, from, to, dur, height, done)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not p.Parent then conn:Disconnect() return end
		local u = math.min(1, (os.clock() - t0) / math.max(0.01, dur))
		local pos = from:Lerp(to, u) + Vector3.new(0, 4 * height * u * (1 - u), 0)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, u * 6, 0)
		if u >= 1 then
			conn:Disconnect()
			if done then done() end
		end
	end)
end
local function zapArc(a, b, dur)
	local holder = part({Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new()})
	local N = 7
	local atts, beams = {}, {}
	for i = 0, N do
		local at = Instance.new("Attachment")
		at.Parent = holder
		atts[i] = at
	end
	for i = 1, N do
		local bm = Instance.new("Beam")
		bm.Attachment0, bm.Attachment1 = atts[i - 1], atts[i]
		bm.Color = ColorSequence.new(CORE, VOLT)
		bm.Width0, bm.Width1, bm.LightEmission, bm.FaceCamera = 0.35, 0.25, 1, true
		bm.Parent = holder
		beams[i] = bm
	end
	local t0 = os.clock()
	local function redraw()
		local pa, pb = typeof(a) == "function" and a() or a, typeof(b) == "function" and b() or b
		if not (pa and pb) then return end
		for i = 0, N do
			local j = (i == 0 or i == N) and Vector3.zero or Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6
			atts[i].WorldPosition = pa:Lerp(pb, i / N) + j
		end
	end
	redraw()
	task.spawn(function()
		while os.clock() - t0 < dur and holder.Parent do
			task.wait(0.06)
			redraw()
		end
		holder:Destroy()
	end)
end
local function rootOf(m)
	if not m then return nil end
	local r = m:FindFirstChild("HumanoidRootPart")
	return r and r:IsA("BasePart") and r or nil
end
local function findModel(name)
	if typeof(name) ~= "string" or name == "" then return nil end
	local pl = Players:FindFirstChild(name)
	if pl and pl:IsA("Player") and pl.Character then return pl.Character end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end
local function pieces(char, id, roles)
	local out = {}
	local m = char:FindFirstChild("OPart_" .. id)
	if not m then return out end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and roles[d:GetAttribute("OPartRole") or ""] then table.insert(out, d) end
	end
	return out
end
local function hide(list, yes)
	for _, p in ipairs(list) do p.LocalTransparencyModifier = yes and 1 or 0 end
end
local function centre(list, char)
	if #list == 0 then local r = rootOf(char) return r and r.Position or char:GetPivot().Position end
	local s = Vector3.zero
	for _, p in ipairs(list) do s += p.Position end
	return s / #list
end
local function windupGlow(list, color, dur, char)
	local anchor = list[1] or rootOf(char)
	if not anchor then return end
	local l = light(anchor, color, 10, 0)
	TweenService:Create(l, TweenInfo.new(dur * 0.8), {Brightness = 4}):Play()
	burst(centre(list, char), color, 10, 4, 0.5, 0.5)
	task.delay(dur + 0.1, function() if l.Parent then l:Destroy() end end)
end
local function delayTo(at, fn)
	task.delay(math.max(0, at - now()), fn)
end
local function num(v) return typeof(v) == "number" and v or nil end

-- Mender Drone -----------------------------------------------------------------------------------------------------------
local drones = {} -- [char] = {model, target, mode, ...}
local function makeDrone(s)
	local m = Instance.new("Model")
	m.Name = "MenderDrone"
	local shell = ball(1.5 * s / 2, DARK, Enum.Material.Metal)
	shell.Name = "Shell"
	shell.Parent = m
	local eye = ball(0.8 * s / 2, GREEN)
	eye.Parent = m
	local wl = part({Size = Vector3.new(1.6, 0.12, 0.7) * s / 2, Color = PLATE, Material = Enum.Material.SmoothPlastic, Parent = m})
	local wr = part({Size = Vector3.new(1.6, 0.12, 0.7) * s / 2, Color = PLATE, Material = Enum.Material.SmoothPlastic, Parent = m})
	light(eye, GREEN, 12, 2)
	trail(shell, GREEN, 0.6 * s / 2)
	m.Parent = folder
	local function place(cf, t)
		local flap = math.sin(t * 30) * 0.5
		shell.CFrame = cf
		eye.CFrame = cf * CFrame.new(0, 0, -0.45 * s / 2)
		wl.CFrame = cf * CFrame.new(-1.1 * s / 2, 0.1, 0) * CFrame.Angles(0, 0, flap)
		wr.CFrame = cf * CFrame.new(1.1 * s / 2, 0.1, 0) * CFrame.Angles(0, 0, -flap)
	end
	return m, place
end
local function menderStart(char, at)
	if not on("omender") then return end
	diag("omender", "windup")
	local s = char:GetScale()
	local carry = pieces(char, "omender", {carry = true})
	windupGlow(carry, GREEN, cfg("menderWindup"), char)
	delayTo(at + cfg("menderWindup"), function()
		if not char.Parent or char:GetAttribute("TrooMenderAt") ~= at then return end
		diag("omender", "action")
		local old = drones[char]
		if old then old.model:Destroy() end
		hide(carry, true)
		local m, place = makeDrone(s)
		local st = {model = m, place = place, carry = carry, from = centre(carry, char), fromT = os.clock(),
			dur = math.max(0.1, (num(char:GetAttribute("TrooMenderArriveAt")) or (now() + cfg("menderFly"))) - now()),
			target = findModel(char:GetAttribute("TrooMenderTarget")) or char, mode = "fly", nextTick = 0, nextRing = 0}
		drones[char] = st
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if drones[char] ~= st or not m.Parent then conn:Disconnect() return end
			local t = os.clock()
			local tr = rootOf(st.target)
			local orbitPos = tr and (tr.Position + Vector3.new(math.cos(t * 2.2) * cfg("menderOrbit") * s / 2, 4 * s / 2,
				math.sin(t * 2.2) * cfg("menderOrbit") * s / 2)) or st.from
			if st.mode == "fly" or st.mode == "back" then
				local goal = st.mode == "back" and centre(carry, char) or orbitPos
				local u = math.min(1, (t - st.fromT) / st.dur)
				local pos = st.from:Lerp(goal, u) + Vector3.new(0, 3 * u * (1 - u) * s / 2, 0)
				place(CFrame.lookAt(pos, goal + Vector3.new(0, 0.01, 0)), t)
				if u >= 1 then
					if st.mode == "back" then
						conn:Disconnect()
						drones[char] = nil
						m:Destroy()
						hide(carry, false)
						burst(goal, GREEN_L, 12, 4, 0.4, 0.5)
						diag("omender", "recovery")
						return
					end
					st.mode = "orbit"
					diag("omender", "result")
				end
			else
				place(CFrame.lookAt(orbitPos, tr and tr.Position or orbitPos + Vector3.zAxis), t)
				if tr and t >= st.nextTick then
					st.nextTick = t + cfg("menderTick")
					local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
					a0.Parent, a1.Parent = m.Shell, tr
					local bm = Instance.new("Beam")
					bm.Attachment0, bm.Attachment1 = a0, a1
					bm.Color, bm.LightEmission, bm.FaceCamera = ColorSequence.new(GREEN_L, GREEN), 1, true
					bm.Width0, bm.Width1 = 0.3, 0.6
					bm.Parent = m.Shell
					task.delay(0.3, function() bm:Destroy() a0:Destroy() a1:Destroy() end)
				end
				if tr and t >= st.nextRing then
					st.nextRing = t + 1
					local g = tr.Position - Vector3.new(0, 3 * s / 2, 0)
					groundRing(g, GREEN, 1.5 * s / 2, 5 * s / 2, 0.6)
				end
			end
		end)
	end)
end
local function menderHop(char)
	local st = drones[char]
	if not st then return end
	local nt = findModel(char:GetAttribute("TrooMenderHopTo"))
	if not nt then return end
	st.from = st.model.Shell.Position
	st.fromT, st.dur, st.target, st.mode = os.clock(), 0.5, nt, "fly"
	diag("omender", "hop")
end
local function menderEnd(char)
	local st = drones[char]
	if not st then return end
	st.from = st.model.Shell.Position
	st.fromT, st.dur, st.mode = os.clock(), cfg("menderBack"), "back"
end

-- Arc Lantern ------------------------------------------------------------------------------------------------------------
local lanterns = {} -- [char] = {model core, lastZap, names}
local function lanternStart(char, at)
	if not on("olantern") then return end
	diag("olantern", "windup")
	local s = char:GetScale()
	local carry = pieces(char, "olantern", {carry = true})
	windupGlow(carry, VOLT, cfg("lanternWindup"), char)
	delayTo(at + cfg("lanternWindup"), function()
		if not char.Parent or char:GetAttribute("TrooLanternAt") ~= at then return end
		diag("olantern", "action")
		hide(carry, true)
		local old = lanterns[char]
		if old and old.core.Parent then old.core:Destroy() end
		local core = ball(0.9 * s / 2, VOLT)
		local shell = ball(1.5 * s / 2, CORE, Enum.Material.Glass, 0.45)
		local cap = part({Size = Vector3.new(0.9, 0.3, 0.9) * s / 2, Color = BRASS, Material = Enum.Material.Metal})
		local l = light(core, VOLT, 10, 2)
		trail(core, VOLT, 0.5 * s / 2)
		local st = {core = core, light = l, at = at, lastZap = 0, names = {}, carry = carry}
		lanterns[char] = st
		local from = centre(carry, char)
		local to = char:GetAttribute("TrooLanternTo")
		if typeof(to) ~= "Vector3" then to = from end
		to += Vector3.new(0, 0.8 * s / 2, 0)
		local follow = RunService.Heartbeat:Connect(function()
			if core.Parent then
				shell.CFrame = core.CFrame
				cap.CFrame = core.CFrame * CFrame.new(0, 0.8 * s / 2, 0)
			end
		end)
		local function finish()
			follow:Disconnect()
			fade(core, 0.4) fade(shell, 0.4) fade(cap, 0.4)
			if lanterns[char] == st then lanterns[char] = nil end
			hide(carry, false)
			diag("olantern", "recovery")
		end
		local flight = num(char:GetAttribute("TrooLanternFlight")) or 0.55
		arcFly(core, from, to, flight, cfg("lanternArc") * s / 2, function()
			diag("olantern", "result")
			core.CFrame = CFrame.new(to)
			TweenService:Create(shell, TweenInfo.new(0.25), {Transparency = 0.8}):Play()
			TweenService:Create(l, TweenInfo.new(0.25), {Range = 18, Brightness = 4}):Play()
			burst(to, VOLT, 14, 6, 0.4, 0.4)
			st.lastZap = os.clock()
			task.spawn(function()
				while core.Parent and os.clock() - st.lastZap < cfg("lanternLinger") + (st.names[1] and 0 or 0.6) do
					l.Brightness = 3 + math.random() * 2
					task.wait(0.05)
				end
				finish()
			end)
		end)
	end)
end
local function lanternZap(char)
	local st = lanterns[char]
	if not on("olantern") then return end
	local list = string.split(tostring(char:GetAttribute("TrooLanternChainList") or ""), "|")
	local name = list[#list]
	local tgt = findModel(name)
	local tr = rootOf(tgt)
	if not tr then return end
	local prev = list[#list - 1] and rootOf(findModel(list[#list - 1]))
	local fromFn = function()
		if prev and prev.Parent then return prev.Position end
		if st and st.core.Parent then return st.core.Position end
		return nil
	end
	zapArc(fromFn, function() return tr.Parent and tr.Position or nil end, 0.3)
	flashBall(tr.Position, VOLT, 1.5, 5, 0.3)
	burst(tr.Position, CORE, 16, 10, 0.35, 0.4)
	if st then
		st.lastZap = os.clock()
		table.insert(st.names, name)
	end
	diag("olantern", "zap")
end

-- Sap Wall ---------------------------------------------------------------------------------------------------------------
local function sapStart(char, at)
	if not on("osapwall") then return end
	diag("osapwall", "windup")
	local s = char:GetScale()
	local carry = pieces(char, "osapwall", {carry = true})
	windupGlow(carry, AMBER, cfg("sapWindup"), char)
	delayTo(at + cfg("sapWindup"), function()
		if not char.Parent or char:GetAttribute("TrooSapAt") ~= at then return end
		diag("osapwall", "action")
		hide(carry, true)
		local pod = ball(1.1 * s / 2, AMBER)
		light(pod, AMBER, 8, 2)
		trail(pod, EMBER, 0.6 * s / 2)
		local from = centre(carry, char)
		local to = char:GetAttribute("TrooSapTo")
		if typeof(to) ~= "Vector3" then to = from end
		arcFly(pod, from, to + Vector3.new(0, 0.5, 0), num(char:GetAttribute("TrooSapFlight")) or 0.5, cfg("sapArc") * s / 2, function()
			diag("osapwall", "result")
			flashBall(to + Vector3.new(0, 1, 0), FLASH, 2 * s / 2, 9 * s / 2, 0.35)
			groundRing(to, AMBER, 2 * s / 2, 10 * s / 2, 0.45)
			burst(to + Vector3.new(0, 1, 0), EMBER, 24, 12, 0.5, 0.7)
			pod:Destroy()
		end)
		delayTo(at + cfg("sapReturn"), function() hide(carry, false) end)
	end)
end
local function watchWall(m)
	if not (m:IsA("Model") and m.Name == "SapWall") or not on("osapwall") then return end
	local segs = {}
	local rims = {}
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(segs, {cf = p.CFrame, size = p.Size})
			local wet = part({Size = p.Size * 1.03, CFrame = p.CFrame, Color = FLASH, Material = Enum.Material.Glass, Transparency = 0.45})
			TweenService:Create(wet, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {Transparency = 1}):Play()
			Debris:AddItem(wet, 0.85)
			local rim = part({Size = Vector3.new(p.Size.X, 0.35, p.Size.Z + 0.3), Color = AMBER,
				CFrame = p.CFrame * CFrame.new(0, -p.Size.Y / 2 + 0.2, 0)})
			light(rim, AMBER, 6, 1)
			table.insert(rims, rim)
			p:GetAttributeChangedSignal("WallBlockedAt"):Connect(function()
				local pos = p:GetAttribute("WallBlockedPos")
				if typeof(pos) == "Vector3" and on("osapwall") then
					flashBall(pos, FLASH, 1, 4, 0.25)
					burst(pos, EMBER, 12, 8, 0.35, 0.4)
					diag("osapwall", "blocked")
				end
			end)
		end
	end
	m.AncestryChanged:Connect(function(_, parent)
		if parent then return end
		for _, r in ipairs(rims) do fade(r, 0.3) end
		for _, sg in ipairs(segs) do
			for i = 1, 3 do
				local c = part({Size = Vector3.new(sg.size.X / 3, sg.size.Y / 4, sg.size.Z), Color = AMBER, Material = Enum.Material.Glass,
					Transparency = 0.3, CFrame = sg.cf * CFrame.new((i - 2) * sg.size.X / 3, sg.size.Y * (0.35 - i * 0.12), 0)})
				local goal = c.CFrame * CFrame.new(0, -sg.size.Y * 0.4, 0) * CFrame.Angles(math.random() - 0.5, 0, math.random() - 0.5)
				TweenService:Create(c, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = goal, Transparency = 1}):Play()
				Debris:AddItem(c, 0.65)
			end
		end
		diag("osapwall", "recovery")
	end)
end

-- Feather Shed -----------------------------------------------------------------------------------------------------------
local function shedStart(char, at)
	if not on("oshed") then return end
	diag("oshed", "windup")
	local s = char:GetScale()
	local plates = pieces(char, "oshed", {shed = true})
	local root = rootOf(char)
	if root then
		local l = light(root, Color3.new(1, 1, 1), 12, 5)
		Debris:AddItem(l, cfg("shedWindup") + 0.05)
	end
	for _, p in ipairs(plates) do burst(p.Position, Color3.new(1, 1, 1), 3, 2, 0.3, 0.2) end
	delayTo(at + cfg("shedWindup"), function()
		if not char.Parent or char:GetAttribute("TrooShedAt") ~= at then return end
		diag("oshed", "action")
		local r = rootOf(char)
		local c = r and r.Position or char:GetPivot().Position
		for _, p in ipairs(plates) do
			local cl = part({Size = p.Size, CFrame = p.CFrame, Color = p.Color, Material = p.Material, Shape = p.Shape})
			local dir = (p.Position - c)
			dir = (dir.Magnitude > 1e-3 and dir.Unit or Vector3.yAxis) + Vector3.new(0, 0.8, 0)
			local goal = p.CFrame + dir * 6 * s / 2
			TweenService:Create(cl, TweenInfo.new(cfg("shedFling"), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{CFrame = goal * CFrame.Angles(math.random() * 4, math.random() * 4, 0), Transparency = 1}):Play()
			Debris:AddItem(cl, cfg("shedFling") + 0.05)
		end
		hide(plates, true)
		burst(c, Color3.fromHex("FFF4DC"), 40, 18, 0.7, 0.9)
		burst(c, AMBER, 14, 12, 0.5, 0.6)
		local kr = tonumber(char:GetAttribute("TrooPartShedKnockRadius")) or 0
		groundRing(c - Vector3.new(0, 3 * s / 2, 0), Color3.new(1, 1, 1), 1.5 * s / 2, kr > 0 and kr or cfg("shedRadius") * s / 2, 0.35)
		local untilT = num(char:GetAttribute("TrooShedImmuneUntil")) or (now() + 1)
		local ext = char:GetExtentsSize()
		local shell = part({Shape = Enum.PartType.Ball, Size = Vector3.one * math.max(ext.X, ext.Y, ext.Z) * 0.8, Color = TEAL_L,
			Material = Enum.Material.ForceField, Transparency = 0.1})
		diag("oshed", "result")
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local rr = rootOf(char)
			if not rr or now() >= untilT or not shell.Parent then
				conn:Disconnect()
				fade(shell, 0.2)
				hide(plates, false)
				diag("oshed", "recovery")
				return
			end
			shell.CFrame = rr.CFrame
		end)
	end)
end

-- Portal Feathers --------------------------------------------------------------------------------------------------------
local portals = {} -- [char] = {rings}
local function makeRing(s)
	local m = Instance.new("Model")
	m.Name = "FeatherRing"
	local R = cfg("portalRing") * s / 2
	local blocks = {}
	for i = 1, 12 do
		local b = part({Size = Vector3.new(0.45, R * 0.56, 0.45) * Vector3.new(s / 2, 1, s / 2), Color = TEAL, Parent = m})
		table.insert(blocks, {p = b, a = (i - 1) / 12 * math.pi * 2, kind = "rim"})
	end
	for i = 1, 8 do
		local v = part({Size = Vector3.new(0.25, 0.9, 0.12) * s, Color = BRASS, Material = Enum.Material.Metal, Parent = m})
		table.insert(blocks, {p = v, a = (i - 1) / 8 * math.pi * 2, kind = "vane"})
	end
	local film = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 1.9, R * 1.9), Color = TEAL_L, Transparency = 0.6, Parent = m})
	light(film, TEAL, 14, 1.5)
	trail(film, TEAL, 0.6 * s / 2)
	m.Parent = folder
	local scaleK = 0.25
	local function place(cf, spin, k)
		scaleK = k or scaleK
		for _, b in ipairs(blocks) do
			local rr = (b.kind == "rim" and R or R * 1.25) * scaleK
			b.p.CFrame = cf * CFrame.Angles(0, 0, b.a + (b.kind == "vane" and spin * 0.3 or 0)) * CFrame.new(0, rr, 0)
		end
		film.Size = Vector3.new(0.1, R * 1.9 * scaleK, R * 1.9 * scaleK)
		film.CFrame = cf * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(spin, 0, 0)
	end
	return m, place, film
end
local function portalStart(char, at)
	if not on("oportal") then return end
	diag("oportal", "windup")
	local s = char:GetScale()
	local c1, c2 = pieces(char, "oportal", {carry1 = true}), pieces(char, "oportal", {carry2 = true})
	local both = {}
	for _, p in ipairs(c1) do table.insert(both, p) end
	for _, p in ipairs(c2) do table.insert(both, p) end
	windupGlow(both, TEAL, cfg("portalWindup2"), char)
	local old = portals[char]
	if old then for _, rg in ipairs(old.rings) do rg.m:Destroy() end end
	local st = {rings = {}, at = at, carry = both}
	portals[char] = st
	local function fling(carry, key, openKey, wind, fly)
		delayTo(at + wind, function()
			if portals[char] ~= st or not char.Parent then return end
			diag("oportal", "action")
			hide(carry, true)
			local spot = char:GetAttribute(key)
			if typeof(spot) ~= "Vector3" then return end
			local m, place = makeRing(s)
			local rg = {m = m, place = place, k = 0.25, open = false}
			table.insert(st.rings, rg)
			local from = centre(carry, char)
			local up = Vector3.new(0, cfg("portalUp") * s / 2, 0)
			local r0 = rootOf(char)
			local look = r0 and Vector3.new(r0.CFrame.LookVector.X, 0, r0.CFrame.LookVector.Z) or Vector3.zAxis
			look = look.Magnitude > 1e-3 and look.Unit or Vector3.zAxis
			local t0 = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not m.Parent then conn:Disconnect() return end
				local u = math.min(1, (os.clock() - t0) / fly)
				local pos = u < 1 and (from:Lerp(spot + up, u) + Vector3.new(0, 4 * 3 * u * (1 - u), 0)) or (spot + up)
				local openAt = num(char:GetAttribute(openKey))
				if not rg.open and openAt and openAt >= at and now() >= openAt then
					rg.open = true
					flashBall(spot + up, TEAL_L, 2 * s / 2, 8 * s / 2, 0.3)
					groundRing(spot, TEAL, 1 * s / 2, 7 * s / 2, 0.5)
					diag("oportal", "result")
				end
				rg.k = rg.open and math.min(1, rg.k + 0.12) or 0.25
				place(CFrame.lookAt(pos, pos + look), os.clock() * 2.5, rg.k)
			end)
		end)
	end
	fling(c1, "TrooPortalA", "TrooPortalOpenAt", cfg("portalWindup1"), cfg("portalFly1"))
	fling(c2, "TrooPortalB", "TrooPortalOpen2At", cfg("portalWindup2"), cfg("portalFly2"))
end
local function portalEnd(char)
	local st = portals[char]
	if not st then return end
	portals[char] = nil
	for _, rg in ipairs(st.rings) do
		for _, p in ipairs(rg.m:GetDescendants()) do
			if p:IsA("BasePart") then fade(p, 0.4, p.Size * 0.3) end
		end
		Debris:AddItem(rg.m, 0.5)
	end
	hide(st.carry, false)
	diag("oportal", "recovery")
end
local function portalUsed(user)
	if not on("oportal") then return end
	local a, b = user:GetAttribute("TrooPortalFrom"), user:GetAttribute("TrooPortalTo")
	for _, p in ipairs({a, b}) do
		if typeof(p) == "Vector3" then
			flashBall(p + Vector3.new(0, 3, 0), TEAL_L, 2, 7, 0.3)
			burst(p + Vector3.new(0, 3, 0), TEAL, 20, 10, 0.5, 0.6)
		end
	end
	diag("oportal", "travel")
end

-- wiring -----------------------------------------------------------------------------------------------------------------
local function watch(char)
	local function hook(attr, fn)
		char:GetAttributeChangedSignal(attr):Connect(function()
			if script:GetAttribute("TrooPartsFXEnabled") == false then return end
			local v = char:GetAttribute(attr)
			if char:GetAttribute("Species") ~= "Troodon" and attr ~= "TrooPortalUsedAt" then return end
			if typeof(v) == "number" and now() - v > 2 then return end
			fn(char, v)
		end)
	end
	hook("TrooMenderAt", menderStart)
	hook("TrooMenderHopAt", function(c) menderHop(c) end)
	hook("TrooMenderEndAt", function(c) menderEnd(c) end)
	hook("TrooLanternAt", lanternStart)
	hook("TrooLanternZapAt", function(c) lanternZap(c) end)
	hook("TrooSapAt", sapStart)
	hook("TrooShedAt", shedStart)
	hook("TrooPortalAt", portalStart)
	hook("TrooPortalEndAt", function(c) portalEnd(c) end)
	hook("TrooPortalUsedAt", function(c) portalUsed(c) end)
	char.AncestryChanged:Connect(function(_, parent)
		if parent then return end
		local d = drones[char]
		if d then d.model:Destroy() drones[char] = nil end
		local l = lanterns[char]
		if l and l.core.Parent then l.core:Destroy() end
		lanterns[char] = nil
		portalEnd(char)
	end)
end
local function onPlayer(pl)
	if pl.Character then watch(pl.Character) end
	pl.CharacterAdded:Connect(watch)
end
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
Players.PlayerAdded:Connect(onPlayer)
local walls = workspace:FindFirstChild("TrooWalls") or workspace:WaitForChild("TrooWalls", 30)
if walls then
	for _, m in ipairs(walls:GetChildren()) do watchWall(m) end
	walls.ChildAdded:Connect(function(m) task.defer(watchWall, m) end)
end
