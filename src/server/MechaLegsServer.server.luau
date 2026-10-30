-- MechaLegsServer v1.0 (Mecha Dino Arena) — puts the pachy's Mecha Legs on (Mecha Legs star). MDA-123, plan
-- docs/plans/PACHY_PARTS_v1.0.md Drop B Task 10, mockup docs/mockups/pachy_parts_options.html "A · Piston shins".
-- Who: player characters with Species "Pachy". While the character attribute MechaLegsLook (SkillEffects 1.15) is true
--   the model "Mecha_Legs" is built: on each shin (segment ShinL / ShinR, part "<seg>_shin") a steel cover wrapping it
--   (x1.25), a thin dark piston along it, and a dark heel vent on the foot (segment FootL / FootR, part "<seg>_meta",
--   lower end). Welded, massless, no collision, colours no skin role uses (SkinServer never paints them). Removed when
--   MechaLegsLook turns false. Built on the server, so every client sees it.
-- Diagnostics (character): MechaLegsBuilt (parts made). Switch: script attribute MechaLegsServerEnabled (default true).
local Players = game:GetService("Players")

local VERSION = "1.0"
local STEEL, DARK = Color3.fromRGB(154, 166, 184), Color3.fromRGB(93, 104, 120)
script:SetAttribute("MechaLegsServerVersion", VERSION)
if script:GetAttribute("MechaLegsServerEnabled") == nil then script:SetAttribute("MechaLegsServerEnabled", true) end
local enabled = script:GetAttribute("MechaLegsServerEnabled") ~= false

local function findPart(char, seg, suffix)
	local m = char:FindFirstChild(seg)
	if not m then return nil end
	local p = m:FindFirstChild(seg .. suffix, true)
	return p and p:IsA("BasePart") and p or nil
end

local function add(model, anchor, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Metal
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CFrame = anchor.CFrame * cf
	p.Parent = model
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = anchor, p
	w.Parent = p
	return p
end

local function apply(char)
	local want = enabled and char:GetAttribute("Species") == "Pachy" and char:GetAttribute("MechaLegsLook") == true
	local old = char:FindFirstChild("Mecha_Legs")
	if not want then
		if old then old:Destroy() end
		char:SetAttribute("MechaLegsBuilt", 0)
		return
	end
	if old then return end
	local m = Instance.new("Model")
	m.Name = "Mecha_Legs"
	local n = 0
	for _, side in ipairs({"L", "R"}) do
		local shin = findPart(char, "Shin" .. side, "_shin")
		if shin then
			local s = shin.Size
			add(m, shin, "Cover" .. side, Vector3.new(s.X * 1.25, s.Y * 0.8, s.Z * 1.25), CFrame.new(), STEEL)
			add(m, shin, "Piston" .. side, Vector3.new(s.X * 0.22, s.Y * 0.9, s.Z * 0.22), CFrame.new(0, 0, s.Z * 0.75), DARK)
			n += 2
		end
		local foot = findPart(char, "Foot" .. side, "_meta")
		if foot then
			local f = foot.Size
			add(m, foot, "Vent" .. side, Vector3.new(f.X * 1.15, f.Y * 0.3, f.Z * 1.15), CFrame.new(0, -f.Y * 0.35, 0), DARK)
			n += 1
		end
	end
	m.Parent = char
	char:SetAttribute("MechaLegsBuilt", n)
end

local function onCharacter(char)
	char:GetAttributeChangedSignal("MechaLegsLook"):Connect(function() apply(char) end)
	task.defer(apply, char)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
