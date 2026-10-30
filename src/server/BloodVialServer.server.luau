-- BloodVialServer v1.0 (Mecha Dino Arena) — the pachy's Blood Rush look: two blood vials, one on each side of the neck.
-- MDA-124. Kepu 2026-10-30: "Let's have it be 2 blood vials that go on each side of the pachy's neck" -> "When he uses it
--   blood Rushes out the side".
-- Who: player characters with Species "Pachy" while the character attribute BloodRushEnabled (SkillEffects 1.17: Blood
--   Rush bought AND slotted) is true. Built on the server, so every client sees it; removed when it turns false.
-- Look: Model "Mecha_BloodVials" welded to the Neck segment's Root (the neck's box in Root's own frame, so the pose at build
--   time doesn't matter; same way AdrenalineServer 1.0 found the neck): per side ("L" = the dino's left, "R" = right):
--   "Glass_<s>" (clear glass, Hd x 0.045 wide, Hd x 0.13 tall, tilted 30 degrees along the neck), "Blood_<s>" (dark red
--   blood inside, joined by a Weld "FluidHinge" so its level can change from the bottom up), "CapTop_<s>" / "CapBottom_<s>"
--   (steel) and "Nozzle_<s>" (dark, on the outer side, half-way up) holding a ParticleEmitter "Spray" (red drops, off).
--   Hd = the dino's height (GetExtentsSize().Y).
-- Level: each vial is one Blood Rush (vial 1 = the dino's left, vial 2 = right; BloodRushMax 2). Full = the sacrifices
--   still allowed before the count resets: vial i is full while HeadbuttSacrifices < i. A new HeadbuttSacrificeAt drains
--   vial n (n = HeadbuttSacrifices after the press) in 0.3 s and sprays blood out of that vial's nozzle, sideways away
--   from the neck (Spray on for SPRAY_TIME 0.45 s: 220 drops/s thrown 18-28 studs/s, falling, 0.4-0.8 s). When HeadbuttSacrifices
--   goes back to 0 (HeadbuttServer 1.6: back at full health) both vials refill in 0.6 s.
-- Lab card (plug and play, LabPreviewServer 1.2): BindableFunction "BuildPreview_bloodrush" builds the same model, both
--   vials full, on a pachy mannequin and returns it.
-- Switch: script attribute BloodVialServerEnabled (default true, read at start; false = no vials, no card model).
-- Diagnostics (character): BloodVialsBuilt (parts made, 0 when off), BloodVialsFull (vials full now), BloodVialSprays.
local Players = game:GetService("Players")

local VERSION = "1.0"
local SPRAY_TIME = 0.45
local GLASS = Color3.fromRGB(214, 226, 236)
local BLOOD = Color3.fromRGB(150, 12, 30)
local STEEL = Color3.fromRGB(154, 166, 184)
local DARK = Color3.fromRGB(58, 64, 76)

script:SetAttribute("BloodVialServerVersion", VERSION)
if script:GetAttribute("BloodVialServerEnabled") == nil then script:SetAttribute("BloodVialServerEnabled", true) end
local enabled = script:GetAttribute("BloodVialServerEnabled") ~= false

local function part(name, size, cf, color, parent, mount, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
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

-- the neck's box in Root's own frame (corners of every part but Root)
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
local function extent(lo, hi, axis)
	local h = (hi - lo) / 2
	return math.abs(axis.X) * h.X + math.abs(axis.Y) * h.Y + math.abs(axis.Z) * h.Z
end
local function axisOf(root, dir)
	local v = root.CFrame:VectorToObjectSpace(dir)
	local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
	if a.X >= a.Y and a.X >= a.Z then return Vector3.new(v.X >= 0 and 1 or -1, 0, 0) end
	if a.Y >= a.Z then return Vector3.new(0, v.Y >= 0 and 1 or -1, 0) end
	return Vector3.new(0, 0, v.Z >= 0 and 1 or -1)
end

local function setLevel(vial, frac, time)
	local blood, glass = vial.blood, vial.glass
	if not (blood and blood.Parent and glass and glass.Parent) then return end
	local full = blood:GetAttribute("FullHeight")
	local hinge = blood:FindFirstChild("FluidHinge")
	if not (full and hinge) then return end
	vial.token = (vial.token or 0) + 1
	local token = vial.token
	local from = vial.level or 1
	frac = math.clamp(frac, 0, 1)
	vial.level = frac
	task.spawn(function()
		local t0 = os.clock()
		repeat
			local a = time > 0 and math.clamp((os.clock() - t0) / time, 0, 1) or 1
			local f = from + (frac - from) * a
			local h = math.max(0.02, full * f)
			blood.Size = Vector3.new(blood.Size.X, h, blood.Size.Z)
			hinge.C0 = CFrame.new(0, -(full - h) / 2, 0)
			blood.Transparency = f <= 0.001 and 1 or 0
			if a >= 1 then break end
			task.wait()
		until token ~= vial.token or not blood.Parent
	end)
end

local looks = {} -- [char] = {vials = {[1] = {glass, blood, spray, level, token}, [2] = ...}}

local function build(char)
	local seg = char:FindFirstChild("Neck")
	local root = seg and seg:FindFirstChild("Root")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return nil end
	local lo, hi = rootBox(seg, root)
	if not lo then return nil end
	local Hd = char:GetExtentsSize().Y
	local ref = hrp or root
	local x = axisOf(root, ref.CFrame.RightVector)
	local y = axisOf(root, ref.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, ref.CFrame.LookVector):Cross(x) end
	local z = x:Cross(y)
	local w, h = Hd * 0.045, Hd * 0.13
	local model = Instance.new("Model")
	model.Name = "Mecha_BloodVials"
	local vials = {}
	local n = 0
	for i, side in ipairs({-1, 1}) do -- 1 = the dino's left (-x), 2 = right (+x)
		local s = side < 0 and "L" or "R"
		local pLocal = (lo + hi) / 2 + x * side * (extent(lo, hi, x) + w * 0.6)
		local cf = root.CFrame * CFrame.fromMatrix(pLocal, x, y, z) * CFrame.Angles(math.rad(-30), 0, 0) -- along the neck
		local glass = part("Glass_" .. s, Vector3.new(w, h, w), cf, GLASS, model, root, Enum.Material.Glass)
		glass.Transparency = 0.55
		local full = h * 0.86
		local blood = part("Blood_" .. s, Vector3.new(w * 0.82, full, w * 0.82), cf, BLOOD, model, nil)
		blood:SetAttribute("FullHeight", full)
		local hinge = Instance.new("Weld")
		hinge.Name = "FluidHinge"
		hinge.Part0, hinge.Part1 = glass, blood
		hinge.C0 = CFrame.new()
		hinge.Parent = blood
		part("CapTop_" .. s, Vector3.new(w * 1.2, h * 0.1, w * 1.2), cf * CFrame.new(0, h * 0.52, 0), STEEL, model, glass, Enum.Material.Metal)
		part("CapBottom_" .. s, Vector3.new(w * 1.2, h * 0.1, w * 1.2), cf * CFrame.new(0, -h * 0.52, 0), STEEL, model, glass, Enum.Material.Metal)
		-- the nozzle on the outer side; its +X faces away from the neck (x * side in Root space)
		local nozzle = part("Nozzle_" .. s, Vector3.new(w * 0.6, w * 0.35, w * 0.35),
			cf * CFrame.new(side * w * 0.75, 0, 0), DARK, model, glass, Enum.Material.Metal)
		local spray = Instance.new("ParticleEmitter")
		spray.Name = "Spray"
		spray.Enabled = false
		spray.EmissionDirection = side > 0 and Enum.NormalId.Right or Enum.NormalId.Left
		spray.Color = ColorSequence.new(Color3.fromRGB(170, 10, 30), Color3.fromRGB(110, 0, 18))
		spray.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, w * 1.0), NumberSequenceKeypoint.new(1, w * 0.3)})
		spray.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1)})
		spray.Speed = NumberRange.new(18, 28)
		spray.SpreadAngle = Vector2.new(18, 18)
		spray.Acceleration = Vector3.new(0, -60, 0)
		spray.Drag = 1.5
		spray.Lifetime = NumberRange.new(0.4, 0.8)
		spray.Rate = 220
		spray.LightEmission = 0
		spray.Parent = nozzle
		vials[i] = {glass = glass, blood = blood, spray = spray, level = 1}
		n += 6
	end
	model.Parent = char
	char:SetAttribute("BloodVialsBuilt", n)
	return model, vials
end

local function refresh(char)
	local st = looks[char]
	if not st then return end
	local used = tonumber(char:GetAttribute("HeadbuttSacrifices")) or 0
	local fullCount = 0
	for i, v in ipairs(st.vials) do
		local want = used < i and 1 or 0
		if want == 1 then fullCount += 1 end
		if v.level ~= want then setLevel(v, want, want == 1 and 0.6 or 0.3) end
	end
	char:SetAttribute("BloodVialsFull", fullCount)
end

local function apply(char)
	local want = enabled and char:GetAttribute("Species") == "Pachy" and char:GetAttribute("BloodRushEnabled") == true
	local old = char:FindFirstChild("Mecha_BloodVials")
	if not want then
		if old then old:Destroy() end
		looks[char] = nil
		char:SetAttribute("BloodVialsBuilt", 0)
		return
	end
	if old and looks[char] then return end
	if old then old:Destroy() end
	local model, vials = build(char)
	if not model then return end
	looks[char] = {model = model, vials = vials}
	for _, v in ipairs(vials) do v.level = nil end
	refresh(char)
end

local function spray(char)
	local st = looks[char]
	if not st then return end
	local used = tonumber(char:GetAttribute("HeadbuttSacrifices")) or 0
	local v = st.vials[math.clamp(used, 1, #st.vials)]
	if not (v and v.spray and v.spray.Parent) then return end
	v.spray.Enabled = true
	task.delay(SPRAY_TIME, function() if v.spray.Parent then v.spray.Enabled = false end end)
	char:SetAttribute("BloodVialSprays", (char:GetAttribute("BloodVialSprays") or 0) + 1)
	refresh(char)
end

local function onCharacter(char)
	char:GetAttributeChangedSignal("BloodRushEnabled"):Connect(function() apply(char) end)
	char:GetAttributeChangedSignal("Species"):Connect(function() apply(char) end)
	char:GetAttributeChangedSignal("HeadbuttSacrifices"):Connect(function() refresh(char) end)
	char:GetAttributeChangedSignal("HeadbuttSacrificeAt"):Connect(function() spray(char) end)
	char.AncestryChanged:Connect(function(_, parent) if not parent then looks[char] = nil end end)
	task.defer(apply, char)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- the Lab card model (plug and play: LabPreviewServer 1.2 finds BuildPreview_<pathId>)
do
	local fn = Instance.new("BindableFunction")
	fn.Name = "BuildPreview_bloodrush"
	fn.OnInvoke = function(model)
		if not enabled or typeof(model) ~= "Instance" then return nil end
		local m = build(model)
		return m
	end
	fn.Parent = script
end
