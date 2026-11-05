-- TheriMovesFX v1.4 (Mecha Dino Arena) — client effects for the Therizinosaurus' mecha button parts, build 1 (every client
-- draws them for every therizino). Plan docs/plans/THERIZINO_PARTS_v1.0.md Task 5 (MDA-245); looks from the mockup
-- docs/mockups/therizino_parts_options.html v0.1 (chain links, feather blades, red field); server TheriMovesServer 1.0.
--   * Reaper's Hook: TheriHookAt -> a steel chain (alternating light / dark links, CHAIN_STEP studs apart) from the
--     ZPart_zhook "jib" (else the root) to TheriHookAimEnd: it shoots out over SHOOT_TIME (0.15) s; on "hit" it then
--     follows the hooked dino (TheriHookTarget) back for TheriHookPullTime s and goes; on "noTarget" / "blocked" /
--     "shielded" it falls back over 0.25 s.
--   * Feather Barrage: TheriFeatherAt -> one white feather blade per direction (count from the owner's TheriFeatherCount,
--     spread over TheriFeatherFan around TheriFeatherDir) flies from the chest to TheriFeatherRange studs in BLADE_TIME
--     (0.3) s and fades; the ZPart_zfeather "blade" pieces hide until the next fire is ready (TheriFeatherReadyAt).
--   * Harvest Field: TheriFieldAt -> a flat red ring (Neon, 0.6 transparent) of radius TheriFieldRadiusNow at
--     TheriFieldCenter that grows in 0.25 s and pulses until TheriFieldUntil, with blood-red specks rising.
--   * Snare Wires: the trap models are server-built (TheriMovesServer 1.0); nothing here.
-- Everything lives in Workspace.DinoFX_Local.TheriMovesFX (no collision / query / touch, anchored). Switches: script
-- attributes TheriMovesFXEnabled (default true), TheriMovesFX_<hook | feather | field>Enabled (default true; read at each
-- event). Diagnostics: script TheriMovesFXVersion, TheriMovesFXEvents (count), TheriMovesFXLast.
-- v1.1 (therizino parts build 2, MDA-248, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 8; mockup v0.1 looks 12-C, 16-A, 18-C):
--   * Grapple Zip: TheriGrappleAt (result "zip") -> a thin wire (WIRE colour, Neon) from the ZPart_zgrapple "nozzle" (else the
--     root) to TheriGrappleAnchor, shooting out in 0.12 s, held while the body zips (TheriGrappleTime), then gone; a brass
--     claw head sits on the anchor.
--   * Deflector Claws: while TheriDeflectUntil is in the future, a spinning rotor in front of each ZPart_zdeflect "hub"
--     (a translucent disc + 4 claw blades, 1.6 x scale studs across, 22 rad/s, opposite ways); TheriDeflectBlockAt -> a white
--     flash and sparks at the nearer rotor.
--   * Overclock Joints: while TheriClockUntil is in the future the ZPart_zclock "ring" pieces turn hot orange Neon (pulsing),
--     back to their own colour / material after.
--   Switches: TheriMovesFX_<grapple | deflect | clock>Enabled (default true; read at each event).
-- v1.2 (therizino parts looks v2, MDA-252, plan docs/plans/THERIZINO_PARTS_LOOKS_v2.0.md Task 4; looks TheriPartsServer 1.1,
-- motion TheriPartsAnim 1.0), only on a part model with ZPartLooks "v2" (the v1 looks keep the v1.1 FX):
--   * Hook: the chain leaves the role "muzzle" piece if there is one, else "jib" (the Reaper Crane's pulley) as before; a copy
--     of the crane's own claw (its "hookhead" pieces, which TheriPartsAnim hides while the chain is out) rides the chain's tip,
--     pointing along the chain.
--   * Deflect: no FX rotors (the Mane Rotor's own fins are the rotor); the block flash stays at the "hub" piece.
--   * Overclock: the "ring" pieces pulse between the speed yellow (#ffc21a) and white instead of orange.
--   * Feathers: the Blade Wings' "blade" pieces are not hidden after a fire (they are the wings, and fan open instead).
--   Switch: TheriMovesFXV2Enabled (default true; false = the v1.1 FX on the v2 looks too). Diagnostics: TheriMovesFXLast
--   gets "hook:<result>:v2" when the claw copy rides the chain.
-- v1.3 (passive Overclock, Kepu 2026-11-04 Overclock-A, plan docs/plans/THERIZINO_GRAPPLE_CLOCK_v1.0.md, MDA-258;
--   TheriMovesServer 1.3): while the character's TheriClockPassive is true the v2 "ring" pieces glow a steady speed yellow
--   (no pulse) and go back to their own colour when it ends. Switch TheriMovesFXClockSteadyEnabled (default true; false =
--   the 1.2 pulse).
-- v1.4 (Wing Volley, plan docs/plans/THERIZINO_FEATHER_VOLLEY_v1.0.md, MDA-267; TheriMovesServer 1.6): feathers() draws
--   nothing when the character's TheriFeatherVolley is true (TheriMovesFX2 1.1 draws the volley); false / nil = the 1.3 blades.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 grapple wire, deflect rotors, overclock rings
VERSION = "1.2" -- v1.2 FX for the v2 looks (hook claw at the chain tip, no rotors on v2 deflect, yellow v2 overclock)
VERSION = "1.3" -- v1.3 steady rings while Overclock is passive
VERSION = "1.4" -- v1.4 no feather blades while the Wing Volley draws
if script:GetAttribute("TheriMovesFXClockSteadyEnabled") == nil then script:SetAttribute("TheriMovesFXClockSteadyEnabled", true) end -- v1.3
local CHAIN_STEP, SHOOT_TIME, BLADE_TIME = 1.7, 0.15, 0.3
local LIGHT, DARK = Color3.fromRGB(184, 192, 200), Color3.fromRGB(124, 132, 142)
local FEATHER = Color3.fromRGB(240, 234, 216)
local BLOOD = Color3.fromRGB(192, 24, 42)

script:SetAttribute("TheriMovesFXVersion", VERSION)
script:SetAttribute("TheriMovesFXEvents", 0)
for _, k in ipairs({"TheriMovesFXEnabled", "TheriMovesFX_hookEnabled", "TheriMovesFX_featherEnabled", "TheriMovesFX_fieldEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(k) return script:GetAttribute("TheriMovesFXEnabled") ~= false and script:GetAttribute("TheriMovesFX_" .. k .. "Enabled") ~= false end
local function note(s)
	script:SetAttribute("TheriMovesFXEvents", (script:GetAttribute("TheriMovesFXEvents") or 0) + 1)
	script:SetAttribute("TheriMovesFXLast", s)
end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end

local folder
local function fx()
	if folder and folder.Parent then return folder end
	local root = workspace:FindFirstChild("DinoFX_Local")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX_Local"
		root.Parent = workspace
	end
	folder = root:FindFirstChild("TheriMovesFX") or Instance.new("Folder")
	folder.Name = "TheriMovesFX"
	folder.Parent = root
	return folder
end
local function part(size, color, mat, transp)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.Metal
	p.Transparency = transp or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = fx()
	return p
end
if script:GetAttribute("TheriMovesFXV2Enabled") == nil then script:SetAttribute("TheriMovesFXV2Enabled", true) end -- v1.2
local function isV2(char, id) -- v1.2: the part on this dino is a v2 look and the v2 FX are on
	local m = char:FindFirstChild("ZPart_" .. id)
	return m ~= nil and m:GetAttribute("ZPartLooks") == "v2" and script:GetAttribute("TheriMovesFXV2Enabled") ~= false
end
local function zpiece(char, id, role)
	local m = char:FindFirstChild("ZPart_" .. id)
	local out = {}
	if m then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("ZPartRole") == role then table.insert(out, p) end
		end
	end
	return out
end

-- Reaper's Hook --------------------------------------------------------------------------------------------------------------
local function chain(char, s)
	local at = num(char, "TheriHookAt", 0)
	local result = char:GetAttribute("TheriHookResult")
	local aimEnd = char:GetAttribute("TheriHookAimEnd")
	if typeof(aimEnd) ~= "Vector3" then return end
	local pull = num(char, "TheriHookPullTime", 0)
	local target = char:GetAttribute("TheriHookTarget")
	local tm = (result == "hit" and type(target) == "string" and target ~= "") and workspace:FindFirstChild(target, true) or nil
	local troot = tm and tm:IsA("Model") and tm:FindFirstChild("HumanoidRootPart") or nil
	local links = {}
	local t0 = os.clock()
	local total = SHOOT_TIME + (result == "hit" and pull or 0.25)
	-- v1.2: the v2 crane's claw rides the tip (copies of its "hookhead" pieces, kept in the claw's frame at the fire)
	local head = {}
	local v2 = isV2(char, "zhook")
	local function origin()
		local o = v2 and zpiece(char, "zhook", "muzzle")[1] or nil
		o = o or zpiece(char, "zhook", "jib")[1]
		return o and o.Position or (char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position)
	end
	if v2 then
		local hp = zpiece(char, "zhook", "hookhead")
		local o = origin()
		if #hp > 0 and o then
			local c = Vector3.zero
			for _, p in ipairs(hp) do c += p.Position end
			c /= #hp
			local down = (c - o).Magnitude > 0.01 and (c - o).Unit or Vector3.new(0, -1, 0)
			local base = CFrame.lookAt(c, c + down)
			for _, p in ipairs(hp) do
				local k = p:Clone()
				k:ClearAllChildren() -- drop its WeldConstraint (it would weld the anchored copy to the dino)
				k.Anchored, k.CanCollide, k.CanQuery, k.CanTouch, k.Massless = true, false, false, false, true
				k.LocalTransparencyModifier = 0
				for name in pairs(k:GetAttributes()) do k:SetAttribute(name, nil) end
				k.Parent = fx()
				table.insert(head, {p = k, rel = base:ToObjectSpace(p.CFrame)})
			end
		end
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - t0
		local from = origin()
		if e >= total or not from or not char.Parent then
			conn:Disconnect()
			for _, l in ipairs(links) do l:Destroy() end
			for _, h in ipairs(head) do h.p:Destroy() end
			return
		end
		local tip
		if e < SHOOT_TIME then
			tip = from:Lerp(aimEnd, e / SHOOT_TIME)
		elseif result == "hit" and troot and troot.Parent then
			tip = troot.Position
		else
			local k = (e - SHOOT_TIME) / 0.25
			tip = aimEnd:Lerp(from, math.clamp(k, 0, 1)) - Vector3.new(0, 3 * k * s, 0)
		end
		local d = tip - from
		local n = math.clamp(math.floor(d.Magnitude / (CHAIN_STEP * s / 2)), 1, 90)
		for i = #links + 1, n do
			links[i] = part(Vector3.new(0.42, 0.42, 0.9) * s / 2 * 1.4, i % 2 == 0 and LIGHT or DARK, Enum.Material.Metal)
		end
		for i, l in ipairs(links) do
			if i <= n then
				local p = from + d * ((i - 0.5) / n)
				l.CFrame = CFrame.lookAt(p, tip) * CFrame.Angles(0, 0, i % 2 == 0 and math.rad(90) or 0)
				l.Transparency = 0
			else
				l.Transparency = 1
			end
		end
		if #head > 0 and d.Magnitude > 0.01 then -- v1.2
			local at = CFrame.lookAt(tip, tip + d.Unit)
			for _, h in ipairs(head) do h.p.CFrame = at * h.rel end
		end
	end)
	note("hook:" .. tostring(result) .. (#head > 0 and ":v2" or ""))
end

-- Feather Barrage -----------------------------------------------------------------------------------------------------------
local function feathers(char, s)
	if char:GetAttribute("TheriFeatherVolley") == true then return end -- v1.4: TheriMovesFX2 1.1 draws the Wing Volley
	local dir = char:GetAttribute("TheriFeatherDir")
	local root = char:FindFirstChild("HumanoidRootPart")
	if typeof(dir) ~= "Vector3" or not root then return end
	local n = math.max(1, math.floor(num(char, "TheriFeatherCount", 8)))
	local range = num(char, "TheriFeatherRange", 20)
	local fan = math.rad(num(char, "TheriFeatherFan", 60))
	local origin = root.Position + Vector3.new(0, 1.5 * s, 0)
	local blades = {}
	for i = 1, n do
		local a = n == 1 and 0 or (-fan / 2 + fan * (i - 1) / (n - 1))
		local d = (CFrame.Angles(0, a, 0) * dir).Unit
		local b = part(Vector3.new(0.12, 0.3, 1.6) * s / 2 * 1.5, FEATHER, Enum.Material.SmoothPlastic)
		table.insert(blades, {p = b, d = d})
	end
	-- v1.2: the v2 Blade Wings' blades are the wings themselves (they fan open, TheriPartsAnim) and stay shown, as in the mockup
	local racks = isV2(char, "zfeather") and {} or zpiece(char, "zfeather", "blade")
	for _, r in ipairs(racks) do r.Transparency = 1 end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / BLADE_TIME
		if k >= 1.3 then
			conn:Disconnect()
			for _, b in ipairs(blades) do b.p:Destroy() end
			return
		end
		for _, b in ipairs(blades) do
			local pos = origin + b.d * range * math.min(k, 1)
			b.p.CFrame = CFrame.lookAt(pos, pos + b.d) * CFrame.Angles(0, 0, os.clock() * 20)
			b.p.Transparency = k > 1 and (k - 1) / 0.3 or 0
		end
	end)
	task.spawn(function() -- the rack blades come back when the part is ready again
		local readyAt = num(char, "TheriFeatherReadyAt", now() + 1)
		while char.Parent and now() < readyAt do task.wait(0.25) end
		for _, r in ipairs(racks) do if r.Parent then r.Transparency = 0 end end
	end)
	note("feather")
end

-- Harvest Field -------------------------------------------------------------------------------------------------------------
local function field(char, s)
	local c = char:GetAttribute("TheriFieldCenter")
	if typeof(c) ~= "Vector3" then return end
	local r = num(char, "TheriFieldRadiusNow", 6)
	local untilT = num(char, "TheriFieldUntil", now() + 3)
	local ring = part(Vector3.new(0.3, r * 2, r * 2), BLOOD, Enum.Material.Neon, 0.6)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(c + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local edge = part(Vector3.new(0.35, r * 2 + 0.6, r * 2 + 0.6), Color3.fromRGB(255, 60, 60), Enum.Material.Neon, 0.3)
	edge.Shape = Enum.PartType.Cylinder
	edge.CFrame = ring.CFrame * CFrame.new(-0.02, 0, 0)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = now()
		if t >= untilT or not char.Parent then
			conn:Disconnect()
			ring:Destroy()
			edge:Destroy()
			return
		end
		local e = os.clock() - t0
		local grow = math.min(1, e / 0.25)
		ring.Size = Vector3.new(0.36, r * 2 * grow, r * 2 * grow)
		edge.Size = Vector3.new(0.3, (r * 2 + 0.6) * grow, (r * 2 + 0.6) * grow)
		ring.Transparency = 0.55 + 0.15 * math.sin(e * 8)
		if math.random() < 0.25 then
			local a, rr = math.random() * math.pi * 2, math.random() * r
			local sp = part(Vector3.new(0.25, 0.25, 0.25) * s, BLOOD, Enum.Material.Neon, 0.2)
			sp.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * rr, 0.3, math.sin(a) * rr))
			task.spawn(function()
				for i = 1, 12 do
					if not sp.Parent then return end
					sp.CFrame += Vector3.new(0, 0.25 * s, 0)
					sp.Transparency = 0.2 + i / 15
					task.wait(0.04)
				end
				sp:Destroy()
			end)
		end
	end)
	note("field")
end

-- v1.1: Grapple Zip ----------------------------------------------------------------------------------------------------------
for _, k in ipairs({"TheriMovesFX_grappleEnabled", "TheriMovesFX_deflectEnabled", "TheriMovesFX_clockEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local WIRE = Color3.fromRGB(223, 230, 238)
local BRASS = Color3.fromRGB(201, 162, 74)
local function grapple(char, s)
	if char:GetAttribute("TheriGrappleResult") ~= "zip" then return end
	local anchor = char:GetAttribute("TheriGrappleAnchor")
	if typeof(anchor) ~= "Vector3" then return end
	local dur = num(char, "TheriGrappleTime", 0.5)
	local wire = part(Vector3.new(0.15 * s, 0.15 * s, 1), WIRE, Enum.Material.Neon)
	local head = part(Vector3.new(0.6, 0.6, 0.6) * s, BRASS, Enum.Material.Metal)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - t0
		local nz = zpiece(char, "zgrapple", "nozzle")[1]
		local from = nz and nz.Position or (char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position)
		if e >= 0.12 + dur or not from or not char.Parent then
			conn:Disconnect()
			wire:Destroy()
			head:Destroy()
			return
		end
		local tip = e < 0.12 and from:Lerp(anchor, e / 0.12) or anchor
		local d = tip - from
		wire.Size = Vector3.new(0.15 * s, 0.15 * s, math.max(0.1, d.Magnitude))
		wire.CFrame = CFrame.lookAt(from + d / 2, tip)
		head.CFrame = CFrame.new(tip)
	end)
	note("grapple")
end

-- v1.1: Deflector Claws -----------------------------------------------------------------------------------------------------
local BLADE = Color3.fromRGB(226, 220, 203)
local rotors = setmetatable({}, {__mode = "k"}) -- [char] = {parts, conn}
local function deflect(char, s)
	local untilT = num(char, "TheriDeflectUntil", 0)
	if rotors[char] then return end
	if isV2(char, "zdeflect") then note("deflect:v2") return end -- v1.2: the Mane Rotor's own fins turn (TheriPartsAnim)
	local hubs = zpiece(char, "zdeflect", "hub")
	if #hubs == 0 then return end
	local set = {}
	for i, h in ipairs(hubs) do
		local disc = part(Vector3.new(0.1 * s, 1.6 * s, 1.6 * s), Color3.fromRGB(200, 230, 255), Enum.Material.Neon, 0.7)
		disc.Shape = Enum.PartType.Cylinder
		local blades = {}
		for b = 1, 4 do blades[b] = part(Vector3.new(0.12 * s, 0.14 * s, 1.5 * s), BLADE, Enum.Material.SmoothPlastic) end
		set[i] = {hub = h, disc = disc, blades = blades, dir = i % 2 == 0 and -1 or 1}
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if now() >= num(char, "TheriDeflectUntil", untilT) or not char.Parent then
			conn:Disconnect()
			for _, r in ipairs(set) do
				r.disc:Destroy()
				for _, b in ipairs(r.blades) do b:Destroy() end
			end
			rotors[char] = nil
			return
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		local fwd = root and root.CFrame.LookVector or Vector3.zAxis
		for _, r in ipairs(set) do
			if r.hub.Parent then
				local c = r.hub.Position + fwd * 0.8 * s
				local face = CFrame.lookAt(c, c + fwd)
				r.disc.CFrame = face * CFrame.Angles(0, math.rad(90), 0)
				local a = os.clock() * 22 * r.dir
				for b, bl in ipairs(r.blades) do
					bl.CFrame = face * CFrame.Angles(0, 0, a + b * math.pi / 2) * CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(math.rad(90), 0, 0)
				end
			end
		end
	end)
	rotors[char] = {set = set, conn = conn}
	note("deflect")
end
local function deflectBlock(char, s)
	local from = char:GetAttribute("TheriDeflectBlockFrom")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local hubs = zpiece(char, "zdeflect", "hub")
	local at = root.Position
	if #hubs > 0 then
		at = hubs[1].Position
		if typeof(from) == "Vector3" and hubs[2] and (hubs[2].Position - from).Magnitude < (at - from).Magnitude then at = hubs[2].Position end
	end
	local f = part(Vector3.one * 2 * s, Color3.new(1, 1, 1), Enum.Material.Neon, 0.1)
	f.Shape = Enum.PartType.Ball
	f.CFrame = CFrame.new(at)
	task.spawn(function()
		for i = 1, 8 do
			if not f.Parent then return end
			f.Size = Vector3.one * (2 + i * 0.5) * s
			f.Transparency = 0.1 + i / 9
			task.wait(0.03)
		end
		f:Destroy()
	end)
	note("deflectBlock")
end

-- v1.1: Overclock Joints ----------------------------------------------------------------------------------------------------
local HOT = Color3.fromRGB(255, 98, 18)
local SPEED_YELLOW = Color3.fromRGB(255, 194, 26) -- v1.2: the v2 looks' speed glow
local glowing = setmetatable({}, {__mode = "k"}) -- [char] = true while the rings glow (one glow at a time)
local function clock(char)
	if glowing[char] then return end
	local rings = zpiece(char, "zclock", "ring")
	if #rings == 0 then return end
	glowing[char] = true
	local v2 = isV2(char, "zclock") -- v1.2
	local keep = {}
	for i, r in ipairs(rings) do keep[i] = {r.Color, r.Material} end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local untilT = num(char, "TheriClockUntil", 0)
		if now() >= untilT or not char.Parent then
			conn:Disconnect()
			glowing[char] = nil
			for i, r in ipairs(rings) do
				if r.Parent then r.Color, r.Material = keep[i][1], keep[i][2] end
			end
			return
		end
		if v2 and rings[1] and rings[1].Parent == nil then -- v1.3: the part was rebuilt (passive lasts): take the new rings
			local fresh = zpiece(char, "zclock", "ring")
			if #fresh > 0 then
				rings, keep = fresh, {}
				for i, r in ipairs(rings) do keep[i] = {r.Color, r.Material} end
			end
		end
		local k = 0.5 + 0.5 * math.sin(os.clock() * 14)
		if v2 and char:GetAttribute("TheriClockPassive") == true and script:GetAttribute("TheriMovesFXClockSteadyEnabled") ~= false then k = 0 end -- v1.3: steady
		for _, r in ipairs(rings) do
			if r.Parent then
				r.Material = Enum.Material.Neon
				r.Color = v2 and SPEED_YELLOW:Lerp(Color3.new(1, 1, 1), k) or HOT:Lerp(Color3.fromRGB(255, 200, 80), k)
			end
		end
	end)
	note("clock")
end

-- watch every character ------------------------------------------------------------------------------------------------------
local function watch(char)
	local function s() return char:GetScale() end
	char:GetAttributeChangedSignal("TheriGrappleAt"):Connect(function() if on("grapple") then grapple(char, s()) end end) -- v1.1
	char:GetAttributeChangedSignal("TheriDeflectAt"):Connect(function() if on("deflect") then deflect(char, s()) end end) -- v1.1
	char:GetAttributeChangedSignal("TheriDeflectBlockAt"):Connect(function() if on("deflect") then deflectBlock(char, s()) end end) -- v1.1
	char:GetAttributeChangedSignal("TheriClockAt"):Connect(function() if on("clock") then clock(char) end end) -- v1.1
	char:GetAttributeChangedSignal("TheriClockPassive"):Connect(function() if on("clock") then clock(char) end end) -- v1.3
	task.delay(2, function() if char.Parent and char:GetAttribute("TheriClockPassive") == true and on("clock") then clock(char) end end) -- v1.3: already passive when seen
	char:GetAttributeChangedSignal("TheriHookAt"):Connect(function() if on("hook") then chain(char, s()) end end)
	char:GetAttributeChangedSignal("TheriFeatherAt"):Connect(function() if on("feather") then feathers(char, s()) end end)
	char:GetAttributeChangedSignal("TheriFieldAt"):Connect(function() if on("field") then field(char, s()) end end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
