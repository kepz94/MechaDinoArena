-- PortalRift.build v1.0 (Mecha Dino Arena) — adds the Rift Gate look to the islet portals in ServerStorage.PortalIslet
-- (MDA-474, plan docs/plans/RIFT_GATES_v1.0.md T1; Kepu 2026-11-12 16:20 pick A · Rift Gate, mockup
-- docs/mockups/portal_look_v0.1.html). Run in Studio Edit through execute_luau after tools/build/PortalIslet.build.luau
-- (1.1). It changes only ServerStorage.PortalIslet; HubServer clones that model on hub servers. Running it again replaces its
-- own parts (folder Rift) and keeps the saved 1.1 values.
-- Per portal model (Portal_arena / Portal_bots), in its face frame (the Step part: x right, y up, -z toward the island):
--   * the 1.1 look parts (Pillar, Trim, Glow, Arch, ArchGlow, Swirl, SwirlTop, Core, SignPost) get attribute Legacy = true,
--     their Transparency / CanCollide are kept as LegacyTransparency / LegacyCollide and set to 1 / false (the 1.1 light in
--     Swirl gets Enabled false, kept as LegacyLight); PortalFX 1.0 puts them back on the client when its switch is off.
--   * Sign + SignEdge go up SIGN_UP (8) studs (old CFrame kept as LegacyCFrame) to clear the ring.
--   * folder Rift:
--     - Plinth: Metal block 64 x 1.4 x 14 on the Step (collidable), rgb(60, 70, 86).
--     - Ring: an octagon around an ellipse (inner half sizes RX 27 x RY 31, centre 33.2 up, so the opening is 54 x 62 and
--       starts on the plinth): 8 Metal blocks rgb(74, 84, 102) T (6) thick and 6 deep (collidable), 8 bolts (rgb(154, 166,
--       184)) at the corners, 8 Neon conduits Conduit1..8 on the front of the blocks (the portal's neon tone, Transparency 0.6).
--     - VortexDisc: an ellipse (SpecialMesh Sphere) 54 x 62 x 0.4, Neon, Transparency 0.35, 1 stud behind the ring front;
--       VortexCore: white Neon ellipse 12 x 14, Transparency 0.4, in front of it.
--     - VortexHub: invisible part 54 x 62 x 1 at the centre with Attachment Centre (2 studs behind) and Rim1..6 on the
--       ellipse x 0.92; Beams Arm1..6 Rim -> Centre (Width0 8, Width1 1, CurveSize0 14, FaceCamera, LightEmission 1,
--       Transparency 0.15 -> 0.9, Segments 16, the neon tone); ParticleEmitter Sparks (Shape Disc, ShapeInOut Inward,
--       Rate 22, Speed 14, Lifetime 1.2, Size 0.6 -> 0, LightEmission 1, the HUD colour; attribute BaseRate 22);
--       PointLight Light (Range 60, Brightness 2, the neon tone).
--     - RuneRing / RuneHole and RuneInner / RuneInnerHole: flat Neon rings (48 / 42 and 30 / 26 across, the hole discs in the
--       plaza stone) on the plaza 14 studs in front of the portal (the step-in mark).
--     - SignPost2: a short post from the ring top to the sign.
--   Model attribute RiftVersion "1.0"; PortalIslet attribute PortalRiftVersion "1.0".
local ServerStorage = game:GetService("ServerStorage")
local VERSION = "1.0"
local islet = ServerStorage:FindFirstChild("PortalIslet")
if not islet then return "no ServerStorage.PortalIslet" end

local RX, RY, T, DEPTH = 27, 31, 6, 6
local PLINTH_H = 1.4
local SIGN_UP = 8
local METAL = Color3.fromRGB(74, 84, 102)
local PLINTH = Color3.fromRGB(60, 70, 86)
local BOLT = Color3.fromRGB(154, 166, 184)
local STONE = Color3.fromRGB(196, 190, 178)
local NEON = {arena = Color3.fromRGB(255, 100, 18), bots = Color3.fromRGB(255, 196, 40)}
local HUD = {arena = Color3.fromRGB(255, 155, 46), bots = Color3.fromRGB(255, 214, 64)}
local LEGACY = {Pillar = true, Trim = true, Glow = true, Arch = true, ArchGlow = true, Swirl = true, SwirlTop = true, Core = true,
	SignPost = true}

local function part(name, size, cf, props, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = parent
	return p
end
local GLOW = function(color, extra)
	local t = {Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}
	for k, v in pairs(extra or {}) do t[k] = v end
	return t
end
local DISC = CFrame.Angles(0, 0, math.rad(90))

local built = {}
for _, m in ipairs(islet:GetChildren()) do
	local id = m:IsA("Model") and m:GetAttribute("HubPortal")
	local step = id and m:FindFirstChild("Step")
	if step then
		local neon, hud = NEON[id] or Color3.new(1, 1, 1), HUD[id] or Color3.new(1, 1, 1)
		local face = step.CFrame * CFrame.new(0, -0.4, 0)
		-- 1.1 parts -> Legacy (kept, hidden)
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and LEGACY[p.Name] then
				p:SetAttribute("Legacy", true)
				if p:GetAttribute("LegacyTransparency") == nil then p:SetAttribute("LegacyTransparency", p.Transparency) end
				if p:GetAttribute("LegacyCollide") == nil then p:SetAttribute("LegacyCollide", p.CanCollide) end
				p.Transparency = 1
				p.CanCollide = false
				for _, l in ipairs(p:GetChildren()) do
					if l:IsA("Light") then
						if l:GetAttribute("LegacyLight") == nil then l:SetAttribute("LegacyLight", l.Enabled) end
						l.Enabled = false
					end
				end
			elseif p:IsA("BasePart") and (p.Name == "Sign" or p.Name == "SignEdge") then
				if p:GetAttribute("LegacyCFrame") == nil then p:SetAttribute("LegacyCFrame", p.CFrame) end
				p.CFrame = p:GetAttribute("LegacyCFrame") + Vector3.new(0, SIGN_UP, 0)
			end
		end
		local old = m:FindFirstChild("Rift")
		if old then old:Destroy() end
		local rift = Instance.new("Folder")
		rift.Name = "Rift"
		rift.Parent = m
		-- plinth
		part("Plinth", Vector3.new(64, PLINTH_H, 14), face * CFrame.new(0, 0.8 + PLINTH_H / 2, 0),
			{Color = PLINTH, Material = Enum.Material.Metal}, rift)
		-- ring
		local cy = 0.8 + PLINTH_H + RY
		local function vert(i, extra)
			local a = math.rad(22.5 + 45 * i)
			return Vector2.new(math.cos(a) * (RX + extra), cy + math.sin(a) * (RY + extra))
		end
		for i = 0, 7 do
			local a, b = vert(i, T / 2), vert(i + 1, T / 2)
			local mid, dv = (a + b) / 2, b - a
			local ang = math.atan2(dv.Y, dv.X)
			local cf = face * CFrame.new(mid.X, mid.Y, 0) * CFrame.Angles(0, 0, ang)
			part("RingSeg" .. (i + 1), Vector3.new(dv.Magnitude + T * 0.55, T, DEPTH), cf, {Color = METAL, Material = Enum.Material.Metal}, rift)
			local c = part("Conduit" .. (i + 1), Vector3.new(dv.Magnitude * 0.5, 1.4, 0.4), cf * CFrame.new(0, 0, -(DEPTH / 2 + 0.2)),
				GLOW(neon, {Transparency = 0.6}), rift)
			c:SetAttribute("Conduit", i + 1)
			local bolt = vert(i, T / 2)
			part("Bolt" .. (i + 1), Vector3.new(0.8, 2.2, 2.2), face * CFrame.new(bolt.X, bolt.Y, -(DEPTH / 2 + 0.4)) * CFrame.Angles(0, math.rad(90), 0),
				{Shape = Enum.PartType.Cylinder, Color = BOLT, Material = Enum.Material.Metal, CanCollide = false}, rift)
		end
		-- vortex
		local centre = face * CFrame.new(0, cy, 0)
		local disc = part("VortexDisc", Vector3.new(RX * 2, RY * 2, 0.4), centre * CFrame.new(0, 0, 1), GLOW(neon, {Transparency = 0.35}), rift)
		local dm = Instance.new("SpecialMesh") dm.MeshType = Enum.MeshType.Sphere dm.Parent = disc
		local core = part("VortexCore", Vector3.new(12, 14, 0.3), centre * CFrame.new(0, 0, 0.4), GLOW(Color3.new(1, 1, 1), {Transparency = 0.4}), rift)
		local cm = Instance.new("SpecialMesh") cm.MeshType = Enum.MeshType.Sphere cm.Parent = core
		local hub = part("VortexHub", Vector3.new(RX * 2, RY * 2, 1), centre, GLOW(neon, {Transparency = 1}), rift)
		hub:SetAttribute("BaseCFrame", hub.CFrame)
		local ac = Instance.new("Attachment") ac.Name = "Centre" ac.Position = Vector3.new(0, 0, 2) ac.Parent = hub
		for k = 1, 6 do
			local a = math.rad(k * 60)
			local at = Instance.new("Attachment")
			at.Name = "Rim" .. k
			at.Position = Vector3.new(math.cos(a) * RX * 0.92, math.sin(a) * RY * 0.92, -0.3)
			at.Parent = hub
			local bm = Instance.new("Beam")
			bm.Name = "Arm" .. k
			bm.Attachment0, bm.Attachment1 = at, ac
			bm.Width0, bm.Width1 = 8, 1
			bm.CurveSize0, bm.CurveSize1 = 14, 0
			bm.FaceCamera = true
			bm.LightEmission = 1
			bm.Segments = 16
			bm.Color = ColorSequence.new(neon, Color3.new(1, 0.95, 0.85))
			bm.Transparency = NumberSequence.new(0.15, 0.9)
			bm.Parent = hub
		end
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Sparks"
		pe.Shape = Enum.ParticleEmitterShape.Disc
		pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		pe.Rate = 22
		pe.Speed = NumberRange.new(14)
		pe.Lifetime = NumberRange.new(1.2)
		pe.Size = NumberSequence.new(0.6, 0)
		pe.LightEmission = 1
		pe.Color = ColorSequence.new(hud)
		pe.Parent = hub
		pe:SetAttribute("BaseRate", 22)
		local light = Instance.new("PointLight") light.Name = "Light" light.Range = 60 light.Brightness = 2 light.Color = neon light.Parent = hub
		-- rune rings on the plaza in front
		local runeAt = face * CFrame.new(0, 0, -16)
		local function ring(name, outer, inner, y)
			part(name, Vector3.new(0.15, outer, outer), runeAt * CFrame.new(0, y, 0) * DISC, GLOW(neon, {Transparency = 0.3}), rift)
			part(name .. "Hole", Vector3.new(0.16, inner, inner), runeAt * CFrame.new(0, y + 0.005, 0) * DISC,
				{Shape = Enum.PartType.Cylinder, Color = STONE, Material = Enum.Material.Plastic, CanCollide = false, CanQuery = false,
					CanTouch = false, CastShadow = false}, rift)
		end
		ring("RuneRing", 48, 42, 0.09)
		ring("RuneInner", 30, 26, 0.1)
		for _, n in ipairs({"RuneRing", "RuneInner"}) do rift[n].Shape = Enum.PartType.Cylinder end
		-- short post from the ring top to the sign
		local top = cy + RY + T
		local signBottom = (m:FindFirstChild("Sign") and (m.Sign.Position.Y - m.Sign.Size.Y / 2 - face.Position.Y)) or (top + 4)
		if signBottom > top then
			part("SignPost2", Vector3.new(2, signBottom - top + 1, 2), face * CFrame.new(0, (top + signBottom) / 2, 0.6),
				{Color = METAL, Material = Enum.Material.Metal}, rift)
		end
		m:SetAttribute("RiftVersion", VERSION)
		table.insert(built, id)
	end
end
islet:SetAttribute("PortalRiftVersion", VERSION)
local n = 0
for _, x in ipairs(islet:GetDescendants()) do if x:IsA("BasePart") then n += 1 end end
return ("PortalRift %s on %s: islet now %d parts"):format(VERSION, table.concat(built, ", "), n)
