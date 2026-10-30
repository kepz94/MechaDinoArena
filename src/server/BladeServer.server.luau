-- BladeServer v1.3 (Mecha Dino Arena) — Blade Claws look: a mecha sickle claw on each foot of a raptor that owns the
-- Blade Claws path (passive part, raptor parts batch 1). MDA-61, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 4, mockup
-- docs/mockups/raptor_parts_b1_options.html option A "Sickle claws" (Kepu 2026-10-29). The numbers (landing bonus,
-- faster latch bites, bleed, pin-kill refund) live in PounceServer 1.6 / SkillEffects 1.6; this script is the look only.
-- Part: Model "Mecha_Blade" under the character while its BladeLook (SkillEffects 1.6) is true. For each foot segment
--   (Model "FootL" / "FootR" with a part "Root"): a hooked mecha sickle of 3 pieces growing from the lower end of the
--   dino's own sickle claw (part "<Foot>_sickle", size S = its longest side): "Sickle_L" (steel, S x 0.85 long, rising
--   25 degrees), "SickleMid_L" (steel, S x 0.7, 60 degrees) and "SickleTip_L" (red neon, S x 0.5, 105 degrees: curls
--   back), S x 0.3 thick ("_R" on the right foot). Without a "<Foot>_sickle": on top of the foot box, inner edge, a
--   quarter back from the toes, S = foot length x 0.3. Placed in the foot Root's own frame (axes nearest the body's
--   right / up), so the walk pose at build time doesn't matter. The first piece is joined to the foot's Root by a Weld
--   "SickleHinge" (pivot at the hook's base; attribute BaseC0); the other pieces are welded (WeldConstraint) to it.
--   Massless, CanCollide / CanQuery / CanTouch false, no shadow. Removed when BladeLook turns false or the switch is off.
-- Flick: a new PounceStartedAt raises both hooks FLICK_DEG (40) over 0.12 s (TweenService); they go back down 0.6 s
--   after PounceLatched turns false, or 1.2 s after the pounce start when no latch came (the newest pounce wins).
-- Slash: a new PounceLatchedAt (a landing) puts 3 red neon strips across the latch part (PounceLatchPart value) for
--   0.3 s, fading out. Every client sees the parts (server-built).
-- v1.1 (Kepu 2026-10-29: "Did you even make blade claws a visible upgrade?" - from the game camera the 1.0 hooks were a
--   red dot): the hook is BladeSizeMul (script attribute, default 3) times bigger, sits on the OUTER side of each foot
--   (the natural sickle's spot mirrored across the foot's middle, so the leg doesn't hide it from the camera behind),
--   and each steel piece gets a red neon edge strip along its top ("SickleEdge*"), so the claw reads as a glowing mecha
--   blade. Everything else as 1.0. BladeSizeMul 1 + the 1.0 side = set BladeOuterSide false.
-- v1.2 (Kepu 2026-10-29: "the ability themselves don't seem obvious enough" -> mockup
--   docs/mockups/raptor_parts_b1_looks.html, picked A "Foot sickles+"): by the player's SkillPath_blade (rebuilt when it
--   changes): from III a forearm blade on each arm segment ("ArmL" / "ArmR" Root): "ArmBlade_L" (steel, dino height x
--   ARM_BLADE_LEN long, pointing forward and a little down from the front of the arm's middle (forearm), outer side) with a red
--   neon edge "ArmBladeEdge_L", WeldConstraint to the arm's Root. Star: every red neon piece turns HOT (brighter red)
--   and each sickle tip and arm blade carries a red Trail "BladeTrail" (attachments "BladeTrailA" / "BladeTrailB"), on
--   from PounceStartedAt until the hooks go back down. Script attribute BladeArmBladesEnabled (default true).
--   Diagnostics: character BladeLookStep, BladeArmBlades (0 / 2), BladeTrails ("off" / "on").
-- Settings: script attribute BladeServerEnabled (default true; false = parts removed, no flick / slash).
-- Diagnostics: script BladeServerVersion, BladeSlashes; character BladeLookState ("none" / "on" / "noFeet"),
--   BladeFlick ("down" / "up").
-- v1.3 (Lab, MDA-96, plan docs/plans/LAB_v1.0.md Task 1; Kepu 2026-10-29: "Add a preview builder"): BindableFunction
--   "BuildPreview" under this script (server only). Invoke(model) builds this part on the given dino model (a Lab
--   mannequin, not a player) with the same build code (BladeLook = true, then build(model)) and returns its Model "Mecha_Blade" (nil when
--   nothing was built). LabPreviewServer 1.0 turns it into the Lab card model. The live part is unchanged. Switch: script
--   attribute BladeServerPreviewEnabled (default true; false -> returns nil).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.3"
local FLICK_DEG = 40
local STEEL, RED = Color3.fromRGB(201, 210, 220), Color3.fromRGB(240, 70, 60)
local HOT = Color3.fromRGB(255, 120, 95) -- v1.2: star
local ARM_BLADE_LEN = 0.25 -- v1.2: x dino height

script:SetAttribute("BladeServerVersion", VERSION)
if script:GetAttribute("BladeServerEnabled") == nil then script:SetAttribute("BladeServerEnabled", true) end
script:SetAttribute("BladeSlashes", 0)
if script:GetAttribute("BladeSizeMul") == nil then script:SetAttribute("BladeSizeMul", 3) end -- v1.1
if script:GetAttribute("BladeOuterSide") == nil then script:SetAttribute("BladeOuterSide", true) end -- v1.1
if script:GetAttribute("BladeArmBladesEnabled") == nil then script:SetAttribute("BladeArmBladesEnabled", true) end -- v1.2
local function stepOf(char) -- v1.2
	local pl = Players:GetPlayerFromCharacter(char)
	return pl and tonumber(pl:GetAttribute("SkillPath_blade")) or 0
end
-- v1.2: a red trail between two attachments on a part (off until a pounce)
local function addTrail(p, half)
	local a0 = Instance.new("Attachment")
	a0.Name = "BladeTrailA"
	a0.Position = Vector3.new(0, half, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Name = "BladeTrailB"
	a1.Position = Vector3.new(0, -half, 0)
	a1.Parent = p
	local t = Instance.new("Trail")
	t.Name = "BladeTrail"
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new(HOT)
	t.LightEmission = 1
	t.Lifetime = 0.3
	t.Transparency = NumberSequence.new(0.1, 1)
	t.Enabled = false
	t.Parent = p
end
local function on() return script:GetAttribute("BladeServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local chars = {} -- [char] = {flickToken}

local function part(name, size, cf, color, parent, mount)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Parent = parent
	if mount then
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = mount, p
		w.Parent = p
	end
	return p
end

-- the segment's box in its Root's own frame (so the pose at build time doesn't matter)
local function rootBox(seg, root)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
				local q = root.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz))
				lo, hi = lo:Min(q), hi:Max(q)
			end end end
		end
	end
	if lo.X == math.huge then return nil end
	return lo, hi
end
-- the Root-space axis (unit +-X / Y / Z) nearest to a world direction
local function axisOf(root, dir)
	local v = root.CFrame:VectorToObjectSpace(dir)
	local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
	if a.X >= a.Y and a.X >= a.Z then return Vector3.new(v.X >= 0 and 1 or -1, 0, 0) end
	if a.Y >= a.Z then return Vector3.new(0, v.Y >= 0 and 1 or -1, 0) end
	return Vector3.new(0, 0, v.Z >= 0 and 1 or -1)
end
-- distance from the box centre to its face along a unit axis
local function extent(lo, hi, axis)
	local h = (hi - lo) / 2
	return math.abs(axis.X) * h.X + math.abs(axis.Y) * h.Y + math.abs(axis.Z) * h.Z
end
-- Root-space right / up / back axes that follow the body's right / up (z = x cross y = back)
local function bodyAxes(root, hrp)
	local x = axisOf(root, hrp.CFrame.RightVector)
	local y = axisOf(root, hrp.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, hrp.CFrame.LookVector):Cross(x) end
	return x, y, x:Cross(y)
end

local function build(char)
	local old = char:FindFirstChild("Mecha_Blade")
	if old then old:Destroy() end
	if not on() or char:GetAttribute("BladeLook") ~= true then
		char:SetAttribute("BladeLookState", "none")
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then char:SetAttribute("BladeLookState", "noFeet") return end
	local model = Instance.new("Model")
	model.Name = "Mecha_Blade"
	local made = 0
	for _, side in ipairs({{"L", "FootL", 1}, {"R", "FootR", -1}}) do -- inner side: +right for the left foot
		local seg = char:FindFirstChild(side[2])
		local root = seg and seg:FindFirstChild("Root")
		local lo, hi
		if root then lo, hi = rootBox(seg, root) end
		if root and lo then
			local x, y, z = bodyAxes(root, hrp)
			local c = (lo + hi) / 2
			-- the dino's own sickle claw ("<Foot>_sickle"): the mecha hook grows from its lower end and is sized from it;
			-- without one: the top of the foot box, inner edge, a quarter back from the toes, sized from the foot length
			local nat = seg:FindFirstChild(side[2] .. "_sickle", true)
			local S, pLocal
			if nat and nat:IsA("BasePart") then
				S = math.max(nat.Size.X, nat.Size.Y, nat.Size.Z)
				pLocal = root.CFrame:PointToObjectSpace(nat.CFrame:PointToWorldSpace(Vector3.new(0, -nat.Size.Y / 2, 0)))
			else
				S = math.max(2 * extent(lo, hi, z), 0.2) * 0.3
				pLocal = c + y * extent(lo, hi, y) - z * (extent(lo, hi, z) * 0.5) + x * side[3] * math.max(0, extent(lo, hi, x) - S * 0.15)
			end
			local mul = tonumber(script:GetAttribute("BladeSizeMul")) or 3 -- v1.1
			S *= math.clamp(mul, 0.5, 6)
			if script:GetAttribute("BladeOuterSide") ~= false then -- v1.1: mirror to the foot's outer side
				local dx = (pLocal - c):Dot(x)
				pLocal -= x * (2 * dx)
			end
			local t = S * 0.3
			local F = root.CFrame * CFrame.fromMatrix(pLocal, x, y, z)
			-- the hook: 3 pieces rising forward and curling back (angles from forward, upward positive)
			local pieces = {{S * 0.85, 25, S * 0.45}, {S * 0.7, 60, S * 0.35}, {S * 0.5, 105, S * 0.25}}
			local cur = F.Position
			local first, firstLen
			for k, pc in ipairs(pieces) do
				local th = math.rad(pc[2])
				local rot = F.Rotation * CFrame.Angles(th, 0, 0)
				local dir = rot:VectorToWorldSpace(Vector3.new(0, 0, -1))
				local cf = rot + cur + dir * (pc[1] / 2)
				cur += dir * pc[1]
				local isTip = k == #pieces
				local pp = part(isTip and ("SickleTip_" .. side[1]) or (k == 1 and ("Sickle_" .. side[1]) or ("SickleMid_" .. side[1])),
					Vector3.new(t, pc[3], pc[1]), cf, isTip and RED or STEEL, model, first)
				if isTip then pp.Material = Enum.Material.Neon end
				if k == 1 then first, firstLen = pp, pc[1] end
				if not isTip then -- v1.1: red neon edge along the piece's top
					local e = part("SickleEdge" .. k .. "_" .. side[1], Vector3.new(t * 1.08, pc[3] * 0.22, pc[1] * 0.98),
						cf * CFrame.new(0, pc[3] * 0.42, 0), RED, model, first)
					e.Material = Enum.Material.Neon
				end
			end
			local hinge = Instance.new("Weld")
			hinge.Name = "SickleHinge"
			hinge.Part0, hinge.Part1 = root, first
			hinge.C1 = CFrame.new(0, 0, firstLen / 2) -- pivot: the hook's base (the piece's back end)
			hinge.C0 = root.CFrame:ToObjectSpace(first.CFrame) * hinge.C1
			hinge:SetAttribute("BaseC0", hinge.C0)
			hinge.Parent = first
			made += 1
		end
	end
	if made == 0 then
		model:Destroy()
		char:SetAttribute("BladeLookState", "noFeet")
		return
	end
	-- v1.2: arm blades from III, hot + trails at star
	local step = stepOf(char)
	char:SetAttribute("BladeLookStep", step)
	local arms = 0
	if step >= 3 and script:GetAttribute("BladeArmBladesEnabled") ~= false then
		local Hd = char:GetExtentsSize().Y
		for _, side in ipairs({{"L", "ArmL", -1}, {"R", "ArmR", 1}}) do -- outer side: -right for the left arm
			local seg = char:FindFirstChild(side[2])
			local root = seg and seg:FindFirstChild("Root")
			local lo, hi
			if root then lo, hi = rootBox(seg, root) end
			if root and lo then
				local x, y, z = bodyAxes(root, hrp)
				local L = Hd * ARM_BLADE_LEN
				local th = L * 0.1
				-- middle of the arm (the forearm: raptor arms hang down, so the lower end is at the hand), front, outer
				-- side; the blade points forward, tilted 20 degrees down
				local pLocal = (lo + hi) / 2 - z * extent(lo, hi, z)
					+ x * side[3] * (extent(lo, hi, x) + th * 0.5)
				local F = root.CFrame * CFrame.fromMatrix(pLocal, x, y, z) * CFrame.Angles(math.rad(-20), 0, 0)
				local cf = F * CFrame.new(0, 0, -L * 0.35) -- most of the blade in front of the arm
				local b = part("ArmBlade_" .. side[1], Vector3.new(th, L * 0.22, L), cf, STEEL, model, root)
				local e = part("ArmBladeEdge_" .. side[1], Vector3.new(th * 1.1, L * 0.05, L * 0.98),
					cf * CFrame.new(0, -L * 0.1, 0), RED, model, root)
				e.Material = Enum.Material.Neon
				if step >= 4 then addTrail(b, L * 0.1) end
				arms += 1
			end
		end
	end
	char:SetAttribute("BladeArmBlades", arms)
	if step >= 4 then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon then d.Color = HOT end
			if d:IsA("BasePart") and d.Name:sub(1, 10) == "SickleTip_" then addTrail(d, d.Size.Y * 0.5) end
		end
	end
	char:SetAttribute("BladeTrails", "off")
	model.Parent = char
	char:SetAttribute("BladeLookState", "on")
	char:SetAttribute("BladeFlick", "down")
end

local function setFlick(char, up)
	local m = char:FindFirstChild("Mecha_Blade")
	if not m then return end
	for _, h in ipairs(m:GetDescendants()) do
		if h:IsA("Weld") and h.Name == "SickleHinge" then
			local base = h:GetAttribute("BaseC0")
			if typeof(base) == "CFrame" then
				local goal = up and base * CFrame.Angles(math.rad(FLICK_DEG), 0, 0) or base
				TweenService:Create(h, TweenInfo.new(up and 0.12 or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {C0 = goal}):Play()
			end
		end
	end
	char:SetAttribute("BladeFlick", up and "up" or "down")
	local any = false -- v1.2: star trails follow the flick
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Trail") and d.Name == "BladeTrail" then d.Enabled = up any = true end
	end
	if any then char:SetAttribute("BladeTrails", up and "on" or "off") end
end

local function slash(char)
	if not on() or not char:FindFirstChild("Mecha_Blade") then return end
	local v = char:FindFirstChild("PounceLatchPart")
	local target = v and v:IsA("ObjectValue") and v.Value
	if not (target and target:IsA("BasePart")) then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local s = math.max(target.Size.X, target.Size.Y, target.Size.Z)
	local base = target.CFrame
	if hrp then base = CFrame.lookAt(target.Position, target.Position + hrp.CFrame.LookVector) end
	for i = -1, 1 do
		local p = Instance.new("Part")
		p.Name = "BladeSlash"
		p.Size = Vector3.new(s * 0.06, s * 0.9, s * 0.06)
		p.CFrame = base * CFrame.new(i * s * 0.18, 0, -s * 0.3) * CFrame.Angles(0, 0, math.rad(35))
		p.Color = RED
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CastShadow = false
		p.Parent = workspace
		TweenService:Create(p, TweenInfo.new(0.3), {Transparency = 1}):Play()
		Debris:AddItem(p, 0.35)
	end
	script:SetAttribute("BladeSlashes", (script:GetAttribute("BladeSlashes") or 0) + 1)
end

local function onCharacter(char)
	if chars[char] then return end
	local st = {}
	chars[char] = st
	char:SetAttribute("BladeLookState", "none")
	char:SetAttribute("BladeFlick", "down")
	char:GetAttributeChangedSignal("BladeLook"):Connect(function() build(char) end)
	char:GetAttributeChangedSignal("PounceStartedAt"):Connect(function()
		if not on() or not char:FindFirstChild("Mecha_Blade") then return end
		local token = {}
		st.token = token
		setFlick(char, true)
		task.delay(1.2, function()
			if st.token == token and char:GetAttribute("PounceLatched") ~= true then setFlick(char, false) end
		end)
	end)
	char:GetAttributeChangedSignal("PounceLatched"):Connect(function()
		if char:GetAttribute("PounceLatched") == true then return end
		local token = {}
		st.token = token
		task.delay(0.6, function()
			if st.token == token then setFlick(char, false) end
		end)
	end)
	char:GetAttributeChangedSignal("PounceLatchedAt"):Connect(function() slash(char) end)
	local pl = Players:GetPlayerFromCharacter(char) -- v1.2: the look follows the step
	if pl then
		local conn = pl:GetAttributeChangedSignal("SkillPath_blade"):Connect(function()
			if char.Parent then build(char) end
		end)
		char.AncestryChanged:Connect(function(_, parent) if not parent then conn:Disconnect() end end)
	end
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	build(char)
end

for _, a in ipairs({"BladeServerEnabled", "BladeSizeMul", "BladeOuterSide", "BladeArmBladesEnabled"}) do -- v1.1: + size / side; v1.2: + arms
	script:GetAttributeChangedSignal(a):Connect(function()
		for char in pairs(chars) do build(char) end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- v1.3: Lab card preview (LabPreviewServer 1.0)
if script:GetAttribute("BladeServerPreviewEnabled") == nil then script:SetAttribute("BladeServerPreviewEnabled", true) end
local previewFn = script:FindFirstChild("BuildPreview") or Instance.new("BindableFunction")
previewFn.Name = "BuildPreview"
previewFn.Parent = script
previewFn.OnInvoke = function(model)
	if script:GetAttribute("BladeServerPreviewEnabled") == false or typeof(model) ~= "Instance" then return nil end
	model:SetAttribute("BladeLook", true)
	build(model)
	return model:FindFirstChild("Mecha_Blade")
end
