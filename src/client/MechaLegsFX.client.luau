-- MechaLegsFX v1.0 (Mecha Dino Arena) — the Mecha Legs double-jump effect on this client (LocalScript,
-- StarterPlayerScripts). MDA-123, plan docs/plans/PACHY_PARTS_v1.0.md Drop B Task 10 (mockup: heel vents puff + a ring).
-- For every player character: a fresh JumpDoubleAt (JumpServer 1.2; other players) or JumpDoublePredictedAt (own
--   character, set by JumpTest 1.1 at once) shows, under the feet: a white ring that widens and fades (0.35 s) and an
--   orange puff from each heel vent (Mecha_Legs Vent L / R, else the feet) falling away (0.3 s). One effect per jump
--   (the own character ignores its server stamp if the local one came first).
-- Created locally in Workspace.DinoFX_Local. Switch: character attribute MechaLegsFXEnabled (default true).
-- Diagnostic (character, this client): MechaLegsFXCount.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local STALE = 1
local ORANGE = Color3.fromRGB(255, 170, 60)
local player = Players.LocalPlayer

local fxFolder = workspace:FindFirstChild("DinoFX_Local")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DinoFX_Local"
	fxFolder.Parent = workspace
end

local function fxPart(name, size, color, cf, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size, p.Color, p.CFrame = size, color, cf
	p.Material = Enum.Material.Neon
	if shape then p.Shape = shape end
	p.Parent = fxFolder
	return p
end

local function animate(duration, fn, done)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - t0) / duration)
		fn(u)
		if u >= 1 then conn:Disconnect() if done then done() end end
	end)
end

local function heel(char, side)
	local m = char:FindFirstChild("Mecha_Legs")
	local v = m and m:FindFirstChild("Vent" .. side)
	if v then return v.Position end
	local seg = char:FindFirstChild("Foot" .. side)
	local p = seg and seg:FindFirstChildWhichIsA("BasePart", true)
	return p and p.Position
end

local function puff(char)
	if char:GetAttribute("MechaLegsFXEnabled") == false then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then return end
	local s = char:GetScale()
	local footY = hrp.Position.Y - hum.HipHeight - hrp.Size.Y / 2
	local ring = fxPart("LegsRing", Vector3.new(0.3, 1, 1), Color3.new(1, 1, 1),
		CFrame.new(hrp.Position.X, footY, hrp.Position.Z) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	ring.Material = Enum.Material.SmoothPlastic
	animate(0.35, function(u)
		local d = (2 + 10 * (1 - (1 - u) ^ 2)) * s
		ring.Size = Vector3.new(0.3, d, d)
		ring.Transparency = 0.3 + 0.7 * u
	end, function() ring:Destroy() end)
	for _, side in ipairs({"L", "R"}) do
		local at = heel(char, side)
		if at then
			local f = fxPart("LegsPuff", Vector3.one * 0.6 * s, ORANGE, CFrame.new(at), Enum.PartType.Ball)
			animate(0.3, function(u)
				local d = (0.6 + 1.8 * u) * s
				f.Size = Vector3.new(d, d, d)
				f.CFrame = CFrame.new(at - Vector3.new(0, 3 * u * s, 0))
				f.Transparency = 0.1 + 0.9 * u
			end, function() f:Destroy() end)
		end
	end
	char:SetAttribute("MechaLegsFXCount", (char:GetAttribute("MechaLegsFXCount") or 0) + 1)
end

local lastShown = setmetatable({}, {__mode = "k"})
local function maybe(char, at)
	if typeof(at) ~= "number" or math.abs(workspace:GetServerTimeNow() - at) > STALE then return end
	if lastShown[char] and math.abs(at - lastShown[char]) < 0.5 then return end -- one effect per jump
	lastShown[char] = at
	puff(char)
end

local function onCharacter(char)
	char:SetAttribute("MechaLegsFXVersion", VERSION)
	char:GetAttributeChangedSignal("JumpDoubleAt"):Connect(function() maybe(char, char:GetAttribute("JumpDoubleAt")) end)
	char:GetAttributeChangedSignal("JumpDoublePredictedAt"):Connect(function()
		if char == player.Character then maybe(char, char:GetAttribute("JumpDoublePredictedAt")) end
	end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
