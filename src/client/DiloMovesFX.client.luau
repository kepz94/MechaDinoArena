-- DiloMovesFX v1.0 (Mecha Dino Arena) — the dilo's mecha part effects and part motion on this client (LocalScript,
-- StarterPlayerScripts). Plan docs/plans/DILO_PARTS_v1.0.md Task 6 (MDA-319); mockup docs/mockups/dilo_parts_options.html
-- v0.1 (tools/mockup/dilo_parts_looks.js: the picked looks' motion and FX). Every player character with Species "Dilo" that
-- wears DPart_* models (DiloPartsServer 1.0) is watched; the stamps come from DiloMovesServer 1.0. No landing FX.
-- Part motion (local Weld C0 = DPartPivot x motion; the welds are DiloPartsServer's "DPartJoint", attribute DPartAnim):
--   recoil (Venom Gatling barrels): back 0.2 x scale/2 at each DiloGatlingShot, eased out at 9/s; mortar (Chest Launcher
--   tube): rotX(-20 - 30 x elev) and down 0.2 x recoil, elev 0 -> 1 over 0.4 s from DiloMortarAt, held to the fire + 0.7 s,
--   back over 0.5 s, recoil 1 at DiloMortarFireAt (4/s); extend (Frill Barbs): up 0.08 x extend x scale/2, extend eases 0 ->
--   1 over the wind-up (DiloSpineAt .. + DiloSpineWindup), 0 after; the barbs hide from the burst for 1.2 s (reloading);
--   fins (Venom Reactor): rotX(-22 x glow), glow 0 -> 1 over the wind-up (DiloOverdriveAt .. DiloOverdriveStartAt), 1 to
--   DiloOverdriveUntil, back over 0.6 s. Hood pieces (attribute DPartFrill): LocalTransparencyModifier = their frill part's
--   (DiloPose shows the hood locally). The Venom Reactor core (role "core") brightens with the glow; the Twin Hood Repeaters'
--   drums (role "drum") flash at each shot.
-- Effects (folder Workspace.DiloMovesFX_Local; everything has a life and is cleaned up):
--   PartsFXGatlingEnabled  a muzzle flash and a green dart from "i;from;to;flight" (DiloGatlingShot) along a low arc over its
--                          flight; DiloGatlingHit: a green splat at the target's root.
--   PartsFXMortarEnabled   from DiloMortarAt: a yellow target ring (DiloMortarRadius) at DiloMortarTo until the landing; at
--                          DiloMortarFireAt: a muzzle flash + smoke and a glowing canister on an arc (apex 6.5 x scale/2 above
--                          the higher end) over DiloMortarFlight; at DiloMortarLandAt: a green splash, a ring, and the cloud (a
--                          flat disc + a green mist emitter) for DiloMortarTime s.
--   PartsFXSpineEnabled    at DiloSpineBurstAt: DiloSpineCount green spines fly out flat from the dilo's chest (the first along
--                          DiloSpineDir) 22 studs over 0.2 s, plus a ground ring.
--   PartsFXOverEnabled     at DiloOverdriveStartAt: a green flash at the core and a ring; while it runs a green PointLight on
--                          the core.
--   Script switches (default true, read at each event / frame) plus PartsFXMotionEnabled (the part motion and the hood pieces).
-- Diagnostics: script DiloMovesFXVersion, DiloMovesFXEvents (count), DiloMovesFXParts (live effect parts).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
script:SetAttribute("DiloMovesFXVersion", VERSION)
for _, k in ipairs({"PartsFXGatlingEnabled", "PartsFXMortarEnabled", "PartsFXSpineEnabled", "PartsFXOverEnabled", "PartsFXMotionEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
script:SetAttribute("DiloMovesFXEvents", 0)
local function on(k) return script:GetAttribute("DiloMovesFXEnabled") ~= false and script:GetAttribute(k) ~= false end
local function ev() script:SetAttribute("DiloMovesFXEvents", (script:GetAttribute("DiloMovesFXEvents") or 0) + 1) end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k) local v = m:GetAttribute(k) return typeof(v) == "number" and v == v and v or nil end
local GREEN, GREEN_D, YELLOW = Color3.fromRGB(156, 240, 90), Color3.fromRGB(92, 194, 42), Color3.fromRGB(255, 242, 160)

local folder = workspace:FindFirstChild("DiloMovesFX_Local")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "DiloMovesFX_Local"
	folder.Parent = workspace
end
local live = 0
local function part(size, color, material, cf, transp, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = transp or 0
	if shape then p.Shape = shape end
	p.CFrame = cf
	p.Parent = folder
	live += 1
	p.Destroying:Connect(function() live -= 1 end)
	return p
end
local function flash(pos, size, color, life)
	local p = part(Vector3.one * size * 0.4, color, Enum.Material.Neon, CFrame.new(pos), 0.1, Enum.PartType.Ball)
	TweenService:Create(p, TweenInfo.new(life or 0.16), {Size = Vector3.one * size, Transparency = 1}):Play()
	Debris:AddItem(p, (life or 0.16) + 0.05)
end
local function ring(center, diameter, color, life)
	local p = part(Vector3.new(0.2, 2, 2), color, Enum.Material.Neon, CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), 0.2, Enum.PartType.Cylinder)
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.2, diameter, diameter), Transparency = 1}):Play()
	Debris:AddItem(p, life + 0.05)
end
local function burst(pos, c0, c1, n, speed, size, life, spread, dir, accel)
	local holder = part(Vector3.new(0.2, 0.2, 0.2), c0, Enum.Material.SmoothPlastic, dir and CFrame.lookAt(pos, pos + dir) or CFrame.new(pos), 1)
	local a = Instance.new("Attachment")
	a.Parent = holder
	local pe = Instance.new("ParticleEmitter")
	pe.Enabled = false
	pe.Color = ColorSequence.new(c0, c1 or c0)
	pe.LightEmission = 0.5
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.3)})
	pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)})
	pe.Speed = NumberRange.new(speed * 0.6, speed)
	pe.SpreadAngle = Vector2.new(spread or 180, spread or 180)
	pe.Lifetime = NumberRange.new(life * 0.6, life)
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Acceleration = accel or Vector3.zero
	pe.Drag = 3
	pe.Parent = a
	pe:Emit(n)
	Debris:AddItem(holder, life + 0.2)
end
local function parseV(s)
	local x, y, z = s:match("^([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)$")
	return x and Vector3.new(tonumber(x), tonumber(y), tonumber(z)) or nil
end
local function fly(p, from, to, flight, apex, onDone)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / math.max(0.01, flight), 0, 1)
		if not p.Parent then conn:Disconnect() return end
		local pos = from:Lerp(to, u) + Vector3.new(0, 4 * apex * u * (1 - u), 0)
		local u2 = math.min(1, u + 0.02)
		local nxt = from:Lerp(to, u2) + Vector3.new(0, 4 * apex * u2 * (1 - u2), 0)
		p.CFrame = (nxt - pos).Magnitude > 1e-3 and CFrame.lookAt(pos, nxt) or CFrame.new(pos)
		if u >= 1 then
			conn:Disconnect()
			p:Destroy()
			if onDone then onDone(to) end
		end
	end)
end

-- ---------------------------------------------------------------- per-dilo state
local W = setmetatable({}, {__mode = "k"}) -- [char] = state
local function scaleK(m) return (m:IsA("Model") and m:GetScale() or 2) / 2 end
local function pieces(char)
	local list = {}
	for _, m in ipairs(char:GetChildren()) do
		if m:IsA("Model") and m.Name:sub(1, 6) == "DPart_" then
			for _, p in ipairs(m:GetChildren()) do if p:IsA("BasePart") then table.insert(list, p) end end
		end
	end
	return list
end
local function watch(char)
	if W[char] then return end
	local st = {recoil = 0, mRecoil = 0, lastShot = nil}
	W[char] = st
	char:GetAttributeChangedSignal("DiloGatlingShot"):Connect(function()
		local s = char:GetAttribute("DiloGatlingShot")
		if typeof(s) ~= "string" or not on("PartsFXGatlingEnabled") then return end
		local i, fs, ts, fl = s:match("^(%d+);([^;]+);([^;]+);([^;]+);")
		local from, to = fs and parseV(fs), ts and parseV(ts)
		if not (from and to) then return end
		st.recoil = 1
		st.drumFlash = os.clock()
		local k = scaleK(char)
		flash(from, 2.6 * k, Color3.fromRGB(216, 255, 138), 0.1)
		local d = part(Vector3.new(0.35, 0.35, 1.2) * k, GREEN, Enum.Material.Neon, CFrame.lookAt(from, to), 0)
		fly(d, from, to, tonumber(fl) or 0.3, 0.4 * k)
		ev()
	end)
	char:GetAttributeChangedSignal("DiloGatlingHit"):Connect(function()
		local s = char:GetAttribute("DiloGatlingHit")
		if typeof(s) ~= "string" or not on("PartsFXGatlingEnabled") then return end
		local name = s:match("^([^;]+);")
		local target = name and (workspace:FindFirstChild(name) or (workspace:FindFirstChild("DinoIsland") and workspace.DinoIsland:FindFirstChild("Bots") and workspace.DinoIsland.Bots:FindFirstChild(name)))
		local r = target and target:FindFirstChild("HumanoidRootPart")
		if r then burst(r.Position, GREEN, GREEN_D, 8, 14 * scaleK(char), 0.7 * scaleK(char), 0.4, 180, nil, Vector3.new(0, -40, 0)) end
	end)
	-- mortar
	char:GetAttributeChangedSignal("DiloMortarAt"):Connect(function()
		local at = num(char, "DiloMortarAt")
		local to = char:GetAttribute("DiloMortarTo")
		if not at or typeof(to) ~= "Vector3" or not on("PartsFXMortarEnabled") or now() - at > 1 then return end
		local r = (num(char, "DiloMortarRadius") or 8)
		local rg = part(Vector3.new(0.15, r * 2, r * 2), YELLOW, Enum.Material.Neon, CFrame.new(to + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), 0.55, Enum.PartType.Cylinder)
		st.ringAt, st.ring = at, rg
		Debris:AddItem(rg, (num(char, "DiloMortarWindup") or 0.55) + (num(char, "DiloMortarFlight") or 1.15) + 0.3)
		ev()
	end)
	char:GetAttributeChangedSignal("DiloMortarFireAt"):Connect(function()
		local from, to = char:GetAttribute("DiloMortarFrom"), char:GetAttribute("DiloMortarTo")
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not on("PartsFXMortarEnabled") then return end
		st.mRecoil = 1
		local k = scaleK(char)
		flash(from, 5 * k, Color3.fromRGB(216, 255, 176), 0.16)
		burst(from, Color3.fromRGB(232, 232, 232), Color3.fromRGB(190, 190, 190), 10, 8 * k, 1.6 * k, 0.8, 50, Vector3.yAxis)
		local can = part(Vector3.one * 1.1 * k, GREEN, Enum.Material.Neon, CFrame.new(from), 0, Enum.PartType.Ball)
		fly(can, from, to, num(char, "DiloMortarFlight") or 1.15, math.max(from.Y, to.Y) - math.min(from.Y, to.Y) + 6.5 * k)
		ev()
	end)
	char:GetAttributeChangedSignal("DiloMortarLandAt"):Connect(function()
		local to = char:GetAttribute("DiloMortarTo")
		if typeof(to) ~= "Vector3" or not on("PartsFXMortarEnabled") then return end
		if st.ring then st.ring:Destroy() st.ring = nil end
		local r, life = num(char, "DiloMortarRadius") or 8, num(char, "DiloMortarTime") or 3
		local k = scaleK(char)
		burst(to + Vector3.new(0, 1, 0), GREEN, GREEN_D, 30, 26 * k, 1.2 * k, 0.6, 70, Vector3.yAxis, Vector3.new(0, -50, 0))
		ring(to + Vector3.new(0, 0.3, 0), r * 2, Color3.fromRGB(184, 255, 112), 0.5)
		local disc = part(Vector3.new(0.1, r * 2, r * 2), Color3.fromRGB(126, 208, 64), Enum.Material.Neon, CFrame.new(to + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), 0.78, Enum.PartType.Cylinder)
		local holder = part(Vector3.new(r * 1.6, 2, r * 1.6), GREEN, Enum.Material.SmoothPlastic, CFrame.new(to + Vector3.new(0, 3 * k, 0)), 1)
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(GREEN, GREEN_D)
		pe.LightEmission = 0.2
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4 * k), NumberSequenceKeypoint.new(1, 7 * k)})
		pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(1, 1)})
		pe.Speed = NumberRange.new(0.5, 2)
		pe.Lifetime = NumberRange.new(1.2, 2)
		pe.Rate = 26
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = holder
		task.delay(life, function() if pe.Parent then pe.Enabled = false end
			if disc.Parent then TweenService:Create(disc, TweenInfo.new(0.5), {Transparency = 1}):Play() end end)
		Debris:AddItem(disc, life + 0.6)
		Debris:AddItem(holder, life + 2.2)
		ev()
	end)
	-- spines
	char:GetAttributeChangedSignal("DiloSpineBurstAt"):Connect(function()
		if not on("PartsFXSpineEnabled") then return end
		local r = char:FindFirstChild("HumanoidRootPart")
		if not r then return end
		local n = math.clamp(math.floor(num(char, "DiloSpineCount") or 6), 1, 24)
		local fwd = char:GetAttribute("DiloSpineDir")
		if typeof(fwd) ~= "Vector3" or fwd.Magnitude < 1e-3 then fwd = r.CFrame.LookVector end
		fwd = Vector3.new(fwd.X, 0, fwd.Z).Unit
		local k = scaleK(char)
		local origin = r.Position + Vector3.new(0, 2.5 * k, 0)
		for i = 0, n - 1 do
			local d = CFrame.Angles(0, i * 2 * math.pi / n, 0) * fwd
			local from = origin + d * 2 * k
			local sp = part(Vector3.new(0.25, 0.25, 1.6) * k, GREEN, Enum.Material.Neon, CFrame.lookAt(from, from + d), 0)
			fly(sp, from, origin + d * 22 + Vector3.new(0, -1.5 * k, 0), 0.2, 0)
		end
		flash(origin, 7 * k, Color3.fromRGB(216, 255, 176), 0.18)
		local feet = r.Position.Y - r.Size.Y / 2 - ((char:FindFirstChildOfClass("Humanoid") or {HipHeight = 0}).HipHeight or 0)
		ring(Vector3.new(r.Position.X, feet + 0.2, r.Position.Z), 40, Color3.fromRGB(184, 255, 112), 0.45)
		st.barbsHiddenUntil = os.clock() + 1.2
		ev()
	end)
	-- overdrive
	char:GetAttributeChangedSignal("DiloOverdriveAt"):Connect(function()
		local at, start = num(char, "DiloOverdriveAt"), num(char, "DiloOverdriveStartAt")
		if not at or not start or not on("PartsFXOverEnabled") or now() - at > 1 then return end
		task.delay(math.max(0, start - now()), function()
			local core
			for _, p in ipairs(pieces(char)) do if p:GetAttribute("DPartRole") == "core" then core = p end end
			local r = char:FindFirstChild("HumanoidRootPart")
			local k = scaleK(char)
			if core then flash(core.Position, 14 * k, Color3.fromRGB(216, 255, 176), 0.22) end
			if r then
				local feet = r.Position.Y - r.Size.Y / 2 - ((char:FindFirstChildOfClass("Humanoid") or {HipHeight = 0}).HipHeight or 0)
				ring(Vector3.new(r.Position.X, feet + 0.2, r.Position.Z), 32 * k, Color3.fromRGB(184, 255, 112), 0.6)
			end
		end)
		ev()
	end)
end

-- ---------------------------------------------------------------- every frame: part motion, hood pieces, glow
local function animCF(kind, st, sc)
	local k = sc / 2
	if kind == "recoil" then return CFrame.new(0, 0, st.recoil * 0.2 * k * 2) end
	if kind == "mortar" then return CFrame.Angles(math.rad(-20 - 30 * st.elev), 0, 0) * CFrame.new(0, -st.mRecoil * 0.2 * k * 2, 0) end
	if kind == "extend" then return CFrame.new(0, 0.08 * st.extend * k * 2, 0) end
	if kind == "fins" then return CFrame.Angles(math.rad(-22 * st.glow), 0, 0) end
	return CFrame.identity
end
local function ease(u) u = math.clamp(u, 0, 1) return u * u * (3 - 2 * u) end
RunService.RenderStepped:Connect(function(dt)
	local T = now()
	for char, st in pairs(W) do
		if not char.Parent then
			if st.light then st.light:Destroy() end
			W[char] = nil
		else
			st.recoil = math.max(0, st.recoil - dt * 9)
			st.mRecoil = math.max(0, st.mRecoil - dt * 4)
			-- mortar elevation
			local ma, mf = num(char, "DiloMortarAt"), num(char, "DiloMortarFireAt")
			local elev = 0
			if ma and T >= ma and T < ma + 4 then
				local fireT = (mf and mf >= ma) and mf or ma + (num(char, "DiloMortarWindup") or 0.55)
				if T < ma + 0.4 then elev = ease((T - ma) / 0.4)
				elseif T < fireT + 0.7 then elev = 1
				else elev = math.max(0, 1 - (T - fireT - 0.7) / 0.5) end
			end
			st.elev = elev
			-- barbs
			local sa = num(char, "DiloSpineAt")
			local sw = num(char, "DiloSpineWindup") or 0.42
			st.extend = (sa and T >= sa and T < sa + sw) and ease((T - sa) / sw) or 0
			-- overdrive glow
			local oa, os_, ou = num(char, "DiloOverdriveAt"), num(char, "DiloOverdriveStartAt"), num(char, "DiloOverdriveUntil")
			local glow = 0
			if oa and os_ and ou and T >= oa then
				if T < os_ then glow = (T - oa) / math.max(0.05, os_ - oa)
				elseif T < ou then glow = 1
				else glow = math.max(0, 1 - (T - ou) / 0.6) end
			end
			st.glow = glow
			local motion = on("PartsFXMotionEnabled")
			local sc = char:IsA("Model") and char:GetScale() or 2
			local neck = char:FindFirstChild("Neck")
			local barbsHidden = st.barbsHiddenUntil and os.clock() < st.barbsHiddenUntil
			for _, p in ipairs(pieces(char)) do
				local w = p:FindFirstChild("DPartJoint")
				if w and w:IsA("Weld") then
					local pivot = w:GetAttribute("DPartPivot")
					if typeof(pivot) == "CFrame" then
						local cf = pivot * (motion and animCF(w:GetAttribute("DPartAnim"), st, sc) or animCF(w:GetAttribute("DPartAnim"), {recoil = 0, mRecoil = 0, elev = 0, extend = 0, glow = 0}, sc))
						if w.C0 ~= cf then w.C0 = cf end
					end
				end
				local fn = p:GetAttribute("DPartFrill")
				local ltm = 0
				if motion and typeof(fn) == "string" then
					local fpart = neck and neck:FindFirstChild(fn)
					ltm = fpart and fpart.LocalTransparencyModifier or 0
					if barbsHidden and p:GetAttribute("DPartRole") == "barb" then ltm = 1 end
				end
				if p.LocalTransparencyModifier ~= ltm then p.LocalTransparencyModifier = ltm end
				local role = p:GetAttribute("DPartRole")
				if role == "core" or role == "drum" then
					local base = p:GetAttribute("DPartBaseColor")
					if typeof(base) == "Color3" then
						local hot = role == "core" and glow * (0.6 + 0.4 * math.sin(os.clock() * 14)) or ((st.drumFlash and os.clock() - st.drumFlash < 0.08) and 1 or 0)
						local c = base:Lerp(Color3.fromRGB(230, 255, 200), math.clamp(hot, 0, 1) * 0.7)
						if p.Color ~= c then p.Color = c end
					end
					if role == "core" and on("PartsFXOverEnabled") then
						if glow > 0.05 and not st.light then
							st.light = Instance.new("PointLight")
							st.light.Color = GREEN
							st.light.Range = 14
							st.light.Parent = p
						end
						if st.light then
							st.light.Brightness = 3 * glow
							if glow <= 0.05 then st.light:Destroy() st.light = nil end
						end
					end
				end
			end
		end
	end
	script:SetAttribute("DiloMovesFXParts", live)
end)

-- ---------------------------------------------------------------- who to watch
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
