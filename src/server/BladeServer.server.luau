-- BladeServer v1.0 (Mecha Dino Arena) — Blade Claws look: a mecha sickle claw on each foot of a raptor that owns the
-- Blade Claws path (passive part, raptor parts batch 1). MDA-61, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 4, mockup
-- docs/mockups/raptor_parts_b1_options.html option A "Sickle claws" (Kepu 2026-10-29). The numbers (landing bonus,
-- faster latch bites, bleed, pin-kill refund) live in PounceServer 1.6 / SkillEffects 1.6; this script is the look only.
-- Part: Model "Mecha_Blade" under the character while its BladeLook (SkillEffects 1.6) is true. For each foot segment
--   (Model "FootL" / "FootR" with a part "Root"): a steel blade "Sickle_L" / "Sickle_R" (foot length x 0.5 long, x 0.32
--   tall, x 0.07 thick) standing on the inner front of the foot, tipped 35 degrees forward, joined to the foot's Root by
--   a Weld "SickleHinge" (C0 = the blade's rest frame in Root's frame, attribute BaseC0), plus a red neon edge strip
--   "SickleEdge_L" / "_R" welded (WeldConstraint) to the blade. Massless, CanCollide / CanQuery / CanTouch false, no
--   shadow. Removed when BladeLook turns false or the switch is off.
-- Flick: a new PounceStartedAt turns both hinges up FLICK_DEG (50) over 0.12 s (TweenService); they go back down 0.6 s
--   after PounceLatched turns false, or 1.2 s after the pounce start when no latch came (the newest pounce wins).
-- Slash: a new PounceLatchedAt (a landing) puts 3 red neon strips across the latch part (PounceLatchPart value) for
--   0.3 s, fading out. Every client sees the parts (server-built).
-- Settings: script attribute BladeServerEnabled (default true; false = parts removed, no flick / slash).
-- Diagnostics: script BladeServerVersion, BladeSlashes; character BladeLookState ("none" / "on" / "noFeet"),
--   BladeFlick ("down" / "up").
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
local FLICK_DEG = 50
local STEEL, RED = Color3.fromRGB(201, 210, 220), Color3.fromRGB(240, 70, 60)

script:SetAttribute("BladeServerVersion", VERSION)
if script:GetAttribute("BladeServerEnabled") == nil then script:SetAttribute("BladeServerEnabled", true) end
script:SetAttribute("BladeSlashes", 0)
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

-- box of a segment's parts (Root excluded) in the HumanoidRootPart's frame
local function boxOf(seg, hrp, root)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
				local q = hrp.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz))
				lo, hi = lo:Min(q), hi:Max(q)
			end end end
		end
	end
	if lo.X == math.huge then return nil end
	return lo, hi
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
	local R, U, L = hrp.CFrame.RightVector, hrp.CFrame.UpVector, hrp.CFrame.LookVector
	local made = 0
	for _, side in ipairs({{"L", "FootL"}, {"R", "FootR"}}) do
		local seg = char:FindFirstChild(side[2])
		local root = seg and seg:FindFirstChild("Root")
		local lo, hi
		if root then lo, hi = boxOf(seg, hrp, root) end
		if root and lo then
			local Lf = math.max(hi.Z - lo.Z, 0.2) -- foot length (HRP frame: -Z forward)
			local size = Vector3.new(Lf * 0.07, Lf * 0.32, Lf * 0.5)
			-- inner side: the side nearer the body's centre line (x = 0)
			local innerX = (math.abs(lo.X) < math.abs(hi.X)) and lo.X or hi.X
			local x = innerX + (innerX < 0 and 1 or -1) * size.X * 0.5 -- just inside the foot's inner edge
			local base = Vector3.new(x, hi.Y + size.Y * 0.35, lo.Z + Lf * 0.3)
			local cf = CFrame.fromMatrix(hrp.CFrame:PointToWorldSpace(base), R, U, -L) * CFrame.Angles(math.rad(35), 0, 0)
			local blade = part("Sickle_" .. side[1], size, cf, STEEL, model, nil)
			local edge = part("SickleEdge_" .. side[1], Vector3.new(size.X * 1.1, size.Y * 0.18, size.Z * 0.95),
				cf * CFrame.new(0, size.Y * 0.45, 0), RED, model, blade)
			edge.Material = Enum.Material.Neon
			local hinge = Instance.new("Weld")
			hinge.Name = "SickleHinge"
			hinge.Part0, hinge.Part1 = root, blade
			hinge.C0 = root.CFrame:ToObjectSpace(cf)
			hinge.C1 = CFrame.new(0, -size.Y * 0.5, size.Z * 0.5) -- pivot: the blade's lower back corner
			hinge.C0 = hinge.C0 * hinge.C1 -- keep the blade where it was built
			hinge:SetAttribute("BaseC0", hinge.C0)
			hinge.Parent = blade
			made += 1
		end
	end
	if made == 0 then
		model:Destroy()
		char:SetAttribute("BladeLookState", "noFeet")
		return
	end
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
				local goal = up and base * CFrame.Angles(math.rad(-FLICK_DEG), 0, 0) or base
				TweenService:Create(h, TweenInfo.new(up and 0.12 or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {C0 = goal}):Play()
			end
		end
	end
	char:SetAttribute("BladeFlick", up and "up" or "down")
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
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	build(char)
end

script:GetAttributeChangedSignal("BladeServerEnabled"):Connect(function()
	for char in pairs(chars) do build(char) end
end)

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
