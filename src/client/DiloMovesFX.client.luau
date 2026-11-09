-- DiloMovesFX v1.5 (Mecha Dino Arena) — the dilo's mecha part effects and part motion on this client (LocalScript,
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
-- v1.1 (dilo parts build 2, MDA-321, plan docs/plans/DILO_PARTS_v1.0.md Task 8; DiloMovesServer 1.1; the looks mockup's hiss /
--   pump / jets tracks). Script switches (default true, read at each event / frame):
--   PartsFXHissEnabled  from DiloHissAt the Hood Speakers' cones (role "cone") glow up over DiloHissWindup; at DiloHissBlastAt
--                       a flash at the cones and 6 sound-wave arcs (thin neon rings) rolling out along the facing to
--                       DiloHissRange studs over 0.55 s; every model named in DiloHissHits gets a "SILENCED" tag above it (a
--                       BillboardGui, this client only) until its SilencedUntil.
--   PartsFXPumpEnabled  piston (DPartAnim "pump", role "piston"): up 0.32 x scale x pump, pump 0 -> 1 over 0.45 s from
--                       DiloPumpAt, back down to the jolt (DiloPumpAt + DiloPumpWindup); at DiloPumpJoltAt a blue flash at the
--                       tank, a ground ring and "+N" (DiloPumpHealed) above the dilo; while DiloImmuneUntil a see-through blue
--                       shell round the dilo and an "IMMUNE" tag; each DiloImmuneBlockAt a white-blue flash on the shell.
--   PartsFXJetsEnabled  the Tail Booster's nozzle (role "nozzle") heats up orange from DiloJetsAt over DiloJetsDelay, then
--                       orange sparks stream from it (the muzzle Attachment on Tail1's Root) to the dash's end + 0.1 s; its
--                       charge lights (roles "pip1".."pip3") show DiloPartJetsLeft of DiloPartJetsCharges (unused: dark);
--                       while DiloJetsTrailUntil a green poison mist along DiloJetsFrom -> DiloJetsTo. No landing FX.
-- v1.2 (MDA-329, plan docs/plans/DILO_PARTS_FIT_v1.0.md Task 2; Kepu 2026-11-06 12:22 "the vfx for it IS TOTAL SHIT", "you're not
--   consistent" -> "Instant burst + Thrusters FX"): the Spring Jets burst uses the Raptor Thrusters' FX recipe (MechaServer
--   1.2 + MechaButtons 1.2), out of the Tail Booster: a ParticleEmitter "JetsFlame" with Roblox's fire texture, colours
--   FFE27A -> FF7A1A, size booster width x 2.4 -> 0.4, life 0.4-0.7 s, rate 150, speed 12-20, spread 8, light emission 1;
--   a PointLight (FF9632, range booster width x 4, brightness 3); a neon jet (FFBE3C, nozzle width x 0.8, booster length x
--   1.2) behind the nozzle at transparency 0.15; the boost roar (Sound rbxassetid://9114554567, the Thrusters' default,
--   volume 0.8, roll-off 300) - all on while the burst runs (+ 0.1 s), on every client (local copies on the Tail1 Root, at
--   the jets muzzle). The owner also gets the Thrusters' boost feel: FOV + 15 x k and a 0.6 degree shake, 40 speed lines
--   (ScreenGui "DiloJetsSpeedLines"), k 0 -> 1 in 0.15 s and back in 0.3 s. Burst = the owner's DiloJetsLaunchState "dash"
--   (from the press, DiloJetsLaunch 1.1); other clients: DiloJetsAt + DiloJetsDelay .. + DiloJetsTime. The 1.1 nozzle heat and
--   orange sparks are off while this is on; the poison trail mist and the charge lights stay. Switch: script attribute
--   DiloJetsThrusterFXEnabled (default true, read every frame; false = 1.1). Diagnostic: script DiloJetsFlameOn (count).
-- v1.3 (MDA-329 follow-up; review 2026-11-06: next to a Raptor Thrusters burst the jets flame was a small glow — measured in
--   Studio: the Raptor fires 2 nozzles x 150 particles/s of size 3.14 for its whole 1.85 s boost (~550), the dilo 1 nozzle x
--   150/s of size 2.88 for ~0.37 s (~55)): the jets flame uses the Raptor's measured size (3.14 x scale / 2), a 40-particle
--   puff at the burst start, rate 900/s while the burst runs and 300/s for a 0.45 s tail after it (the stretch the flame
--   would still burn on a Thrusters boost), so the trail along the 40-stud dash reads as dense as a Thrusters trail.
--   Switch: script attribute DiloJetsFlameV2Enabled (default true, read every frame; false = 1.2).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 hiss / pump / jets
VERSION = "1.2" -- v1.2 Spring Jets with the Thrusters' FX
VERSION = "1.3" -- v1.3 jets flame as dense as a Thrusters trail
VERSION = "1.4" -- v1.4 shot pass: faster shots, strong aim assist
-- v1.4 (Kepu 2026-11-09 "all the projectile shots need to be faster and more auto aim assist on it and longer range"
--   -> 1.5x faster, 2x range, "Strong" assist = snap to a target within 45 degrees of the aim; plan
--   docs/plans/SHOT_PASS_v1.0.md): the Spine Burst spines fly the server's reach DiloSpineRange (was a fixed 22)
--   over DiloSpineFlight (was 0.2 s) and the ground ring grows with the reach (40 x reach / 22). Switch: script
--   attribute ShotPassEnabled (default true; false = 1.3).
VERSION = "1.5" -- v1.5 big and bright gatling / mortar / spines
-- v1.5 (Kepu 2026-11-09 "the Gatling and spine ... the animation itself is so small you can barely notice WHAT THE FUCK IS
--   GOING ON", mortar "not big enough of a splatter" -> "Big and bright"): Venom Gatling darts 3x bigger with a glowing green
--   trail + light, muzzle flash 2.3x, hit splat 2.5x the bits at 2x size, barrel recoil 3x; Toxin Mortar canister 3x with a
--   trail + light, muzzle flash 2.4x, smoke 2x, landing splash 2x the bits at 2x size and 1.6x speed, a landing flash, ring
--   0.8 s, the cloud mist sized and dense in step with the radius (radius / 8), tube recoil 2.5x; Spine Burst spines 3x with
--   trails, flash 2x, a green burst at the chest, ring 0.8 s, barbs extend 3x. Switch: script attribute DiloFXBigEnabled
--   (default true, read at each event / frame; false = 1.4's sizes).
if script:GetAttribute("DiloJetsFlameV2Enabled") == nil then script:SetAttribute("DiloJetsFlameV2Enabled", true) end -- v1.3
if script:GetAttribute("DiloJetsThrusterFXEnabled") == nil then script:SetAttribute("DiloJetsThrusterFXEnabled", true) end -- v1.2
for _, k in ipairs({"PartsFXHissEnabled", "PartsFXPumpEnabled", "PartsFXJetsEnabled"}) do -- v1.1
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
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
if script:GetAttribute("DiloFXBigEnabled") == nil then script:SetAttribute("DiloFXBigEnabled", true) end -- v1.5
local function big() return script:GetAttribute("DiloFXBigEnabled") ~= false end -- v1.5
local function bigF(m) return big() and m or 1 end -- v1.5: m with the big look, 1 without
local function glowTrail(p, color, life, range) -- v1.5: a glowing trail + light on a flying part (big look only)
	if not big() then return end
	local half = math.max(p.Size.X, p.Size.Y) * 0.5
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, half, 0), Vector3.new(0, -half, 0)
	a0.Parent, a1.Parent = p, p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(color)
	tr.LightEmission = 1
	tr.Lifetime = life
	tr.FaceCamera = true
	tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)})
	tr.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2)})
	tr.Parent = p
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, 2
	l.Parent = p
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
		flash(from, 2.6 * k * bigF(2.3), Color3.fromRGB(216, 255, 138), 0.1 * bigF(1.5)) -- v1.5: x bigF
		local d = part(Vector3.new(0.35, 0.35, 1.2) * k * bigF(3), GREEN, Enum.Material.Neon, CFrame.lookAt(from, to), 0) -- v1.5: x3
		glowTrail(d, GREEN, 0.18, 8 * k) -- v1.5
		fly(d, from, to, tonumber(fl) or 0.3, 0.4 * k)
		ev()
	end)
	char:GetAttributeChangedSignal("DiloGatlingHit"):Connect(function()
		local s = char:GetAttribute("DiloGatlingHit")
		if typeof(s) ~= "string" or not on("PartsFXGatlingEnabled") then return end
		local name = s:match("^([^;]+);")
		local target = name and (workspace:FindFirstChild(name) or (workspace:FindFirstChild("DinoIsland") and workspace.DinoIsland:FindFirstChild("Bots") and workspace.DinoIsland.Bots:FindFirstChild(name)))
		local r = target and target:FindFirstChild("HumanoidRootPart")
		if r then burst(r.Position, GREEN, GREEN_D, math.floor(8 * bigF(2.5)), 14 * scaleK(char), 0.7 * scaleK(char) * bigF(2), 0.4, 180, nil, Vector3.new(0, -40, 0)) end -- v1.5: x bigF
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
		flash(from, 5 * k * bigF(2.4), Color3.fromRGB(216, 255, 176), 0.16 * bigF(1.5)) -- v1.5: x bigF
		burst(from, Color3.fromRGB(232, 232, 232), Color3.fromRGB(190, 190, 190), math.floor(10 * bigF(2)), 8 * k, 1.6 * k * bigF(1.8), 0.8, 50, Vector3.yAxis) -- v1.5
		local can = part(Vector3.one * 1.1 * k * bigF(3), GREEN, Enum.Material.Neon, CFrame.new(from), 0, Enum.PartType.Ball) -- v1.5: x3
		glowTrail(can, GREEN, 0.35, 14 * k) -- v1.5
		fly(can, from, to, num(char, "DiloMortarFlight") or 1.15, math.max(from.Y, to.Y) - math.min(from.Y, to.Y) + 6.5 * k)
		ev()
	end)
	char:GetAttributeChangedSignal("DiloMortarLandAt"):Connect(function()
		local to = char:GetAttribute("DiloMortarTo")
		if typeof(to) ~= "Vector3" or not on("PartsFXMortarEnabled") then return end
		if st.ring then st.ring:Destroy() st.ring = nil end
		local r, life = num(char, "DiloMortarRadius") or 8, num(char, "DiloMortarTime") or 3
		local k = scaleK(char)
		burst(to + Vector3.new(0, 1, 0), GREEN, GREEN_D, math.floor(30 * bigF(2)), 26 * k * bigF(1.6), 1.2 * k * bigF(2), 0.6 * bigF(1.3), 70, Vector3.yAxis, Vector3.new(0, -50, 0)) -- v1.5
		ring(to + Vector3.new(0, 0.3, 0), r * 2, Color3.fromRGB(184, 255, 112), 0.5 * bigF(1.6)) -- v1.5: 0.8 s
		if big() then flash(to + Vector3.new(0, 1, 0), r * 1.2, Color3.fromRGB(216, 255, 176), 0.25) end -- v1.5: a landing flash
		local disc = part(Vector3.new(0.1, r * 2, r * 2), Color3.fromRGB(126, 208, 64), Enum.Material.Neon, CFrame.new(to + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), 0.78, Enum.PartType.Cylinder)
		local holder = part(Vector3.new(r * 1.6, 2, r * 1.6), GREEN, Enum.Material.SmoothPlastic, CFrame.new(to + Vector3.new(0, 3 * k, 0)), 1)
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(GREEN, GREEN_D)
		pe.LightEmission = 0.2
		local mist = big() and math.max(1, r / 8) or 1 -- v1.5: the mist grows with the radius
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4 * k * mist), NumberSequenceKeypoint.new(1, 7 * k * mist)})
		pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(1, 1)})
		pe.Speed = NumberRange.new(0.5, 2)
		pe.Lifetime = NumberRange.new(1.2, 2)
		pe.Rate = 26 * mist -- v1.5 (was 26)
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
		local sReach, sFly, sRing = 22, 0.2, 40 -- v1.4: the server's reach / flight (shot pass)
		if script:GetAttribute("ShotPassEnabled") ~= false then
			sReach = num(char, "DiloSpineRange") or 22
			sFly = num(char, "DiloSpineFlight") or 0.2
			sRing = 40 * sReach / 22
		end
		for i = 0, n - 1 do
			local d = CFrame.Angles(0, i * 2 * math.pi / n, 0) * fwd
			local from = origin + d * 2 * k
			local sp = part(Vector3.new(0.25, 0.25, 1.6) * k * bigF(3), GREEN, Enum.Material.Neon, CFrame.lookAt(from, from + d), 0) -- v1.5: x3
			glowTrail(sp, GREEN, 0.2, 6 * k) -- v1.5
			fly(sp, from, origin + d * sReach + Vector3.new(0, -1.5 * k, 0), sFly, 0) -- v1.4 (was 22 studs, 0.2 s)
		end
		flash(origin, 7 * k * bigF(2), Color3.fromRGB(216, 255, 176), 0.18 * bigF(1.5)) -- v1.5: x bigF
		if big() then burst(origin, GREEN, GREEN_D, 24, 30 * k, 1.4 * k, 0.45, 180, nil, Vector3.zero) end -- v1.5
		local feet = r.Position.Y - r.Size.Y / 2 - ((char:FindFirstChildOfClass("Humanoid") or {HipHeight = 0}).HipHeight or 0)
		ring(Vector3.new(r.Position.X, feet + 0.2, r.Position.Z), sRing, Color3.fromRGB(184, 255, 112), 0.45 * bigF(1.8)) -- v1.4 (was 40); v1.5: 0.8 s
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
	if kind == "recoil" then return CFrame.new(0, 0, st.recoil * 0.2 * k * 2 * bigF(3)) end -- v1.5: x3
	if kind == "mortar" then return CFrame.Angles(math.rad(-20 - 30 * st.elev), 0, 0) * CFrame.new(0, -st.mRecoil * 0.2 * k * 2 * bigF(2.5), 0) end -- v1.5: x2.5
	if kind == "extend" then return CFrame.new(0, 0.08 * st.extend * k * 2 * bigF(3), 0) end -- v1.5: x3
	if kind == "fins" then return CFrame.Angles(math.rad(-22 * st.glow), 0, 0) end
	if kind == "pump" then return CFrame.new(0, 0.32 * (st.pump or 0) * k * 2, 0) end -- v1.1
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

-- ---------------------------------------------------------------- v1.1: build 2 (hiss, pump, jets)
local PURPLE, BLUE, ORANGE_HOT = Color3.fromRGB(201, 184, 255), Color3.fromRGB(159, 230, 255), Color3.fromRGB(255, 176, 80)
local function findModel(name)
	if type(name) ~= "string" or name == "" then return nil end
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character and pl.Character.Name == name then return pl.Character end end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end
local function tag(model, text, color, untilT, offsetY)
	local r = model:FindFirstChild("HumanoidRootPart")
	if not r then return end
	local g = Instance.new("BillboardGui")
	g.Name = "DiloFXTag"
	g.AlwaysOnTop = true
	g.Size = UDim2.fromOffset(150, 28)
	g.StudsOffsetWorldSpace = Vector3.new(0, offsetY or 14 * scaleK(model), 0)
	g.Adornee = r
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.Text = text
	l.Parent = g
	g.Parent = folder
	Debris:AddItem(g, math.max(0.2, untilT - now()))
	return g
end
local function rolePart(char, role)
	for _, p in ipairs(pieces(char)) do if p:GetAttribute("DPartRole") == role then return p end end
end
local function nozzleMuzzle(char)
	local t1 = char:FindFirstChild("Tail1")
	local root = t1 and t1:FindFirstChild("Root")
	if root then
		for _, a in ipairs(root:GetChildren()) do if a:IsA("Attachment") and a.Name:sub(1, 12) == "DPartMuzzle_" then return a end end
	end
	local n = rolePart(char, "nozzle")
	return n
end
local function watchB2(char)
	local st = W[char]
	if not st or st.b2 then return end
	st.b2 = true
	char:GetAttributeChangedSignal("DiloHissBlastAt"):Connect(function()
		local at = num(char, "DiloHissBlastAt")
		if not at or not on("PartsFXHissEnabled") or now() - at > 1 then return end
		local r = char:FindFirstChild("HumanoidRootPart")
		local k = scaleK(char)
		for _, p in ipairs(pieces(char)) do
			if p:GetAttribute("DPartRole") == "cone" then flash(p.Position, 3 * k, PURPLE, 0.18) end
		end
		if r then
			local fwd = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
			fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
			local range = num(char, "DiloHissRange") or 20
			local from = r.Position + Vector3.new(0, 3 * k, 0) + fwd * 3 * k
			for i = 0, 5 do
				task.delay(i * 0.05, function()
					local w = part(Vector3.new(0.2, 2, 2), PURPLE, Enum.Material.Neon, CFrame.lookAt(from, from + fwd) * CFrame.Angles(0, math.pi / 2, 0), 0.25, Enum.PartType.Cylinder)
					local to = from + fwd * range
					local d = range * math.tan(math.rad(num(char, "DiloHissAngle") or 35)) * 2
					TweenService:Create(w, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{CFrame = CFrame.lookAt(to, to + fwd) * CFrame.Angles(0, math.pi / 2, 0), Size = Vector3.new(0.2, d * 0.55, d), Transparency = 1}):Play()
					Debris:AddItem(w, 0.6)
				end)
			end
		end
		for name in string.gmatch(char:GetAttribute("DiloHissHits") or "", "[^|]+") do
			local m = findModel(name)
			if m then
				task.delay(0.08, function()
					local u = num(m, "SilencedUntil") or (now() + 1.5)
					local left = math.max(0, u - now())
					tag(m, ("SILENCED · %d s"):format(math.floor(left + 0.5)), PURPLE, u)
					local mr = m:FindFirstChild("HumanoidRootPart")
					if mr then flash(mr.Position, 6 * k, PURPLE, 0.18) end
				end)
			end
		end
		ev()
	end)
	char:GetAttributeChangedSignal("DiloPumpJoltAt"):Connect(function()
		local at = num(char, "DiloPumpJoltAt")
		if not at or not on("PartsFXPumpEnabled") or now() - at > 1 then return end
		local k = scaleK(char)
		local tank = rolePart(char, "fluid") or rolePart(char, "tank")
		if tank then flash(tank.Position, 12 * k, BLUE, 0.22) end
		local r = char:FindFirstChild("HumanoidRootPart")
		if r then
			local feet = r.Position.Y - r.Size.Y / 2 - ((char:FindFirstChildOfClass("Humanoid") or {HipHeight = 0}).HipHeight or 0)
			ring(Vector3.new(r.Position.X, feet + 0.2, r.Position.Z), 24 * k, BLUE, 0.5)
			local healed = num(char, "DiloPumpHealed") or 0
			if healed > 0 then tag(char, ("+%d"):format(math.floor(healed + 0.5)), Color3.fromRGB(184, 255, 112), now() + 1.2, 12 * k) end
		end
		ev()
	end)
	char:GetAttributeChangedSignal("DiloImmuneBlockAt"):Connect(function()
		if not on("PartsFXPumpEnabled") then return end
		local r = char:FindFirstChild("HumanoidRootPart")
		if r then flash(r.Position + Vector3.new(0, 2 * scaleK(char), 0), 14 * scaleK(char), Color3.fromRGB(220, 245, 255), 0.2) end
		ev()
	end)
	char:GetAttributeChangedSignal("DiloJetsAt"):Connect(function()
		if char:GetAttribute("DiloJetsResult") ~= "dash" or not on("PartsFXJetsEnabled") then return end
		ev()
	end)
end
local watchV10 = watch
watch = function(char)
	watchV10(char)
	watchB2(char)
end
local function ease2(u) u = math.clamp(u, 0, 1) return u * u * (3 - 2 * u) end
RunService.RenderStepped:Connect(function(dt)
	local T = now()
	for char, st in pairs(W) do
		if char.Parent then
			local k = scaleK(char)
			-- pump piston
			local pa = num(char, "DiloPumpAt")
			local pw = num(char, "DiloPumpWindup") or 0.62
			local pump = 0
			if pa and T >= pa and T < pa + pw then
				pump = T < pa + 0.45 and ease2((T - pa) / 0.45) or 1 - ((T - pa - 0.45) / math.max(0.05, pw - 0.45)) ^ 2
			end
			st.pump = on("PartsFXPumpEnabled") and math.clamp(pump, 0, 1) or 0
			-- immune shell
			local iu = num(char, "DiloImmuneUntil")
			local r = char:FindFirstChild("HumanoidRootPart")
			if on("PartsFXPumpEnabled") and iu and iu > T and r then
				if not (st.shell and st.shell.Parent) then
					st.shell = part(Vector3.one * 26 * k, BLUE, Enum.Material.ForceField, r.CFrame, 0.35, Enum.PartType.Ball)
					st.shell.Name = "DiloImmuneShell"
					st.shellTag = tag(char, "IMMUNE", BLUE, iu, 16 * k)
				end
				st.shell.CFrame = CFrame.new(r.Position)
			elseif st.shell then
				st.shell:Destroy()
				st.shell = nil
				if st.shellTag then st.shellTag:Destroy() st.shellTag = nil end
			end
			-- hiss cones glow
			local ha, hw = num(char, "DiloHissAt"), num(char, "DiloHissWindup") or 0.5
			local hot = (on("PartsFXHissEnabled") and ha and T >= ha and T < ha + hw + 0.3) and (T < ha + hw and (T - ha) / hw or 1 - (T - ha - hw) / 0.3) or 0
			-- jets heat + sparks
			local ja, jd, jt = num(char, "DiloJetsAt"), num(char, "DiloJetsDelay") or 0.34, num(char, "DiloJetsTime") or 0.25
			local heat = 0
			local dashing = false
			if on("PartsFXJetsEnabled") and script:GetAttribute("DiloJetsThrusterFXEnabled") == false -- v1.2: 1.1's heat only when off
				and ja and char:GetAttribute("DiloJetsResult") == "dash" and T >= ja then
				if T < ja + jd then heat = (T - ja) / jd
				elseif T < ja + jd + jt + 0.1 then heat, dashing = 1, true
				elseif T < ja + jd + jt + 0.6 then heat = 1 - (T - ja - jd - jt - 0.1) / 0.5 end
			end
			if dashing then
				local mz = nozzleMuzzle(char)
				if mz then
					local pos = mz:IsA("Attachment") and mz.WorldPosition or mz.Position
					local back = r and -r.CFrame.LookVector or Vector3.zAxis
					burst(pos, ORANGE_HOT, Color3.fromRGB(255, 120, 40), 3, 18 * k, 0.9 * k, 0.18, 20, back)
				end
			end
			-- trail mist
			local tu = num(char, "DiloJetsTrailUntil")
			local tf, tt = char:GetAttribute("DiloJetsFrom"), char:GetAttribute("DiloJetsTo")
			if on("PartsFXJetsEnabled") and tu and tu > T and typeof(tf) == "Vector3" and typeof(tt) == "Vector3" and math.random() < dt * 14 then
				local p = tf:Lerp(tt, math.random()) + Vector3.new((math.random() - 0.5) * 3 * k, -2 * k, (math.random() - 0.5) * 3 * k)
				burst(p, GREEN, GREEN_D, 2, 2 * k, 2.2 * k, 1.2, 60, Vector3.yAxis)
			end
			-- part colours: cones, nozzle, charge lights
			local left = num(char, "DiloPartJetsLeft")
			local maxC = num(char, "DiloPartJetsCharges") or 0
			for _, p in ipairs(pieces(char)) do
				local role = p:GetAttribute("DPartRole")
				local base = p:GetAttribute("DPartBaseColor")
				if typeof(base) == "Color3" then
					local c
					if role == "cone" then c = base:Lerp(Color3.fromRGB(240, 230, 255), math.clamp(hot, 0, 1))
					elseif role == "nozzle" then c = base:Lerp(ORANGE_HOT, math.clamp(heat, 0, 1))
					elseif role and role:match("^pip%d$") and on("PartsFXJetsEnabled") then
						local i = tonumber(role:sub(4))
						if i > maxC then c = Color3.fromRGB(40, 40, 46)
						elseif left and i > left then c = base:Lerp(Color3.fromRGB(40, 40, 46), 0.75)
						else c = base end
					end
					if c and p.Color ~= c then p.Color = c end
				end
			end
		else
			if st.shell then st.shell:Destroy() st.shell = nil end
		end
	end
end)

-- ---------------------------------------------------------------- v1.2: Spring Jets with the Thrusters' FX
local THR_SOUND = "rbxassetid://9114554567" -- MechaServer's MechaBoostSoundId default
local function thrOn() return on("PartsFXJetsEnabled") and script:GetAttribute("DiloJetsThrusterFXEnabled") ~= false end
local function jetsKit(char, st)
	local mz = nozzleMuzzle(char)
	if not (mz and mz:IsA("Attachment")) then return nil end
	if st.jk and st.jk.at.Parent and st.jk.src == mz then return st.jk end
	if st.jk then st.jk.at:Destroy() if st.jk.jet then st.jk.jet:Destroy() end end
	local sc = char:IsA("Model") and char:GetScale() or 2
	local bw, bl, nw = 0.6 * sc, 1.5 * sc, 0.68 * sc -- booster width / length, nozzle width (DiloPartsServer djets)
	local at = Instance.new("Attachment")
	at.Name = "DiloJetsFlameAt"
	at.CFrame = mz.CFrame
	at.Parent = mz.Parent
	local f = Instance.new("ParticleEmitter")
	f.Name = "JetsFlame"
	f.Enabled = false
	f.EmissionDirection = Enum.NormalId.Back
	f.Color = ColorSequence.new(Color3.fromRGB(255, 226, 122), Color3.fromRGB(255, 122, 26))
	f.Texture = "rbxasset://textures/particles/fire_main.dds"
	f.Size = NumberSequence.new(bw * 2.4, 0.4)
	f.Lifetime = NumberRange.new(0.4, 0.7)
	f.Rate = 150
	f.Speed = NumberRange.new(12, 20)
	f.SpreadAngle = Vector2.new(8, 8)
	f.LightEmission = 1
	f.LightInfluence = 0
	f.Parent = at
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 150, 50)
	glow.Range = bw * 4
	glow.Brightness = 3
	glow.Enabled = false
	glow.Parent = at
	local snd = Instance.new("Sound")
	snd.Name = "JetsRoar"
	snd.SoundId = THR_SOUND
	snd.Volume = 0.8
	snd.RollOffMaxDistance = 300
	snd.Parent = at
	local jet = part(Vector3.new(nw * 0.8, nw * 0.8, bl * 1.2), Color3.fromRGB(255, 190, 60), Enum.Material.Neon, at.WorldCFrame, 1)
	jet.Name = "DiloJetsJet"
	st.jk = {at = at, src = mz, f = f, glow = glow, snd = snd, jet = jet, len = bl * 1.2, on = false, offAt = 0}
	return st.jk
end
-- the owner's boost feel (MechaButtons 1.2's numbers)
local FXB = "DiloJetsBoostCam"
local fb = {boosting = false, k = 0, baseFov = nil, gui = nil, lines = nil, t = 0}
local function fbBuild()
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	local old = pg:FindFirstChild("DiloJetsSpeedLines")
	if old then old:Destroy() end
	fb.gui = Instance.new("ScreenGui")
	fb.gui.Name = "DiloJetsSpeedLines"
	fb.gui.ResetOnSpawn = true
	fb.gui.DisplayOrder = 4
	fb.gui.IgnoreGuiInset = true
	fb.lines = {}
	for i = 1, 40 do
		local fr = Instance.new("Frame")
		fr.Name = "Line_" .. i
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.BackgroundColor3 = Color3.new(1, 1, 1)
		fr.BorderSizePixel = 0
		fr.Parent = fb.gui
		fb.lines[i] = {f = fr, a = math.random() * math.pi * 2, r = 0.45 + math.random() * 0.55, len = 100 + math.random() * 120}
	end
	fb.gui.Parent = pg
end
local function fbStep(dt)
	fb.t += dt
	if fb.boosting then fb.k = math.min(1, fb.k + dt / 0.15) else fb.k = math.max(0, fb.k - dt / 0.3) end
	local cam = workspace.CurrentCamera
	if cam and fb.baseFov then
		cam.FieldOfView = fb.baseFov + 15 * fb.k
		local amp = math.rad(0.6) * fb.k
		cam.CFrame = cam.CFrame * CFrame.Angles(math.noise(fb.t * 18, 1.3) * amp, math.noise(fb.t * 18, 7.1) * amp, 0)
	end
	if fb.gui and fb.lines then
		local size = fb.gui.AbsoluteSize
		local half = math.sqrt(size.X * size.X + size.Y * size.Y) / 2
		for _, l in ipairs(fb.lines) do
			l.r += dt * 2.2
			if l.r > 1.05 then l.a, l.r, l.len = math.random() * math.pi * 2, 0.45 + math.random() * 0.2, 100 + math.random() * 120 end
			l.f.Position = UDim2.fromOffset(size.X / 2 + math.cos(l.a) * l.r * half, size.Y / 2 + math.sin(l.a) * l.r * half)
			l.f.Size = UDim2.fromOffset(l.len, 4)
			l.f.Rotation = math.deg(l.a)
			l.f.BackgroundTransparency = 1 - 0.65 * fb.k
		end
		fb.gui.Enabled = fb.k > 0
	end
	if fb.k <= 0 and not fb.boosting then
		if cam and fb.baseFov then cam.FieldOfView = fb.baseFov end
		fb.baseFov = nil
		pcall(function() RunService:UnbindFromRenderStep(FXB) end)
	end
end
local function fbSet(on2)
	fb.boosting = on2
	if on2 and not fb.baseFov then
		fb.baseFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
		if not (fb.gui and fb.gui.Parent) then fbBuild() end
		pcall(function() RunService:UnbindFromRenderStep(FXB) end)
		RunService:BindToRenderStep(FXB, Enum.RenderPriority.Camera.Value + 2, fbStep)
	end
end
RunService.RenderStepped:Connect(function()
	local T = now()
	local me = Players.LocalPlayer.Character
	for char, st in pairs(W) do
		if char.Parent then
			local burning = false
			if thrOn() then
				if char == me then
					burning = char:GetAttribute("DiloJetsLaunchState") == "dash"
				else
					local ja, jd, jt = num(char, "DiloJetsAt"), num(char, "DiloJetsDelay") or 0, num(char, "DiloJetsTime") or 0.25
					burning = ja ~= nil and char:GetAttribute("DiloJetsResult") == "dash" and T >= ja + jd and T < ja + jd + jt
				end
			end
			local kit = (burning or (st.jk and st.jk.on)) and jetsKit(char, st) or st.jk
			local v2 = script:GetAttribute("DiloJetsFlameV2Enabled") ~= false -- v1.3
			if kit then
				if v2 then
					local sz = 3.14 * ((char:IsA("Model") and char:GetScale() or 2) / 2)
					if kit.v2sz ~= sz then kit.v2sz = sz kit.f.Size = NumberSequence.new(sz, 0.4) end
					if burning and not kit.wasBurning then kit.f:Emit(40) end
					kit.f.Rate = burning and 900 or 300
					if burning then kit.offAt = os.clock() + 0.45 end
				elseif kit.v2sz then
					kit.v2sz = nil
					local sc = char:IsA("Model") and char:GetScale() or 2
					kit.f.Size = NumberSequence.new(0.6 * sc * 2.4, 0.4)
					kit.f.Rate = 150
				end
				kit.wasBurning = burning
				if burning and not v2 then kit.offAt = os.clock() + 0.1 end
				local want = os.clock() < kit.offAt
				if want ~= kit.on then
					kit.on = want
					kit.f.Enabled, kit.glow.Enabled = want, want
					kit.jet.Transparency = want and 0.15 or 1
					if want then
						kit.snd.TimePosition = 0
						kit.snd:Play()
						script:SetAttribute("DiloJetsFlameOn", (script:GetAttribute("DiloJetsFlameOn") or 0) + 1)
						ev()
					else
						kit.snd:Stop()
					end
				end
				if kit.on and kit.at.Parent then kit.jet.CFrame = kit.at.WorldCFrame * CFrame.new(0, 0, kit.len / 2) end
			end
			if char == me then
				local b = burning and thrOn()
				if b ~= fb.boosting then fbSet(b) end
			end
		elseif st.jk then
			st.jk.at:Destroy()
			if st.jk.jet then st.jk.jet:Destroy() end
			st.jk = nil
		end
	end
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
