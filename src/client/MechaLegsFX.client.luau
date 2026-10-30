-- MechaLegsFX v1.1 (Mecha Dino Arena) — the Mecha Legs double-jump effect on this client (LocalScript,
-- StarterPlayerScripts). MDA-123, plan docs/plans/PACHY_PARTS_v1.0.md Drop B Task 10 (mockup: heel vents puff + a ring).
-- For every player character: a fresh JumpDoubleAt (JumpServer 1.2; other players) or JumpDoublePredictedAt (own
--   character, set by JumpTest 1.1 at once) shows, under the feet: a white ring that widens and fades (0.35 s) and an
--   orange puff from each heel vent (Mecha_Legs Vent L / R, else the feet) falling away (0.3 s). One effect per jump
--   (the own character ignores its server stamp if the local one came first).
-- Created locally in Workspace.DinoFX_Local. Switch: character attribute MechaLegsFXEnabled (default true).
-- Diagnostic (character, this client): MechaLegsFXCount.
-- v1.1 (Kepu 2026-10-30: "This should be also have visuals to indicate it's strong whether it's small fire bursts through
--   the leg or speed animation lines when you jump"): both.
--   Leap (character with MechaLegsEnabled, SkillEffects 1.16): at takeoff (JumpPredictedAt on the own character,
--   JumpStartedAt for the others, + JumpWindup 0.12 s) a fire burst from each heel vent (a yellow core 1.5 studs and 3
--   orange / red neon flames 1.1 studs that stick to the heel for 0.12 s, then swell and fall away, 0.35 s) and 8 white
--   speed lines around
--   the body that stretch downward and fade (0.35 s), streaming down past the dino.
--   Double jump: the same burst at 1.6 x size and 10 speed lines, on top of the 1.0 ring and puffs.
--   Switch: character attribute MechaLegsFXLeapEnabled (default true; false = 1.0, double jump ring and puffs only).
--   Diagnostic: MechaLegsFXLeapCount.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
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

-- v1.1: fire bursts at the heels and speed lines
local FLAME = {Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 140, 40), Color3.fromRGB(240, 70, 30)}
local function fireBurst(char, side, big)
	local s = char:GetScale() * big
	local function heelPos() return heel(char, side) end
	local at0 = heelPos()
	if not at0 then return end
	local pieces = {}
	local core = fxPart("LegsFlameCore", Vector3.one * 1.5 * s, FLAME[1], CFrame.new(at0), Enum.PartType.Ball)
	table.insert(pieces, {p = core, off = Vector3.zero, base = 1.5, grow = 2.5, drop = 1.5})
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2 + math.random() * 0.6
		local off = Vector3.new(math.cos(a) * 0.7, -0.6, math.sin(a) * 0.7) * s
		local f = fxPart("LegsFlame", Vector3.one * 1.1 * s, FLAME[2], CFrame.new(at0 + off), Enum.PartType.Ball)
		f.Color = FLAME[i == 1 and 2 or 3]
		table.insert(pieces, {p = f, off = off, base = 1.1, grow = 3, drop = 3 + math.random()})
	end
	local stick = 0.12
	local t0 = os.clock()
	local last = at0
	animate(0.35, function(u)
		local el = os.clock() - t0
		if el < stick then last = heelPos() or last end
		for _, pc in ipairs(pieces) do
			local d = (pc.base + pc.grow * u) * s
			pc.p.Size = Vector3.new(d, d * 1.3, d)
			local fall = el < stick and 0 or (el - stick) * pc.drop * 10 * s * 0.25
			pc.p.CFrame = CFrame.new(last + pc.off * (1 + u) - Vector3.new(0, fall, 0))
			pc.p.Transparency = 0.05 + 0.95 * u * u
		end
	end, function() for _, pc in ipairs(pieces) do pc.p:Destroy() end end)
end
local function speedLines(char, n)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local s = char:GetScale()
	local center = hrp.Position
	local radius = 4.5 * s
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + math.random() * 0.4
		local base = center + Vector3.new(math.cos(a) * radius, (math.random() - 0.3) * 3 * s, math.sin(a) * radius)
		local line = fxPart("LegsSpeedLine", Vector3.new(0.12, 0.12, 1) * s, Color3.new(1, 1, 1), CFrame.new(base))
		line.Material = Enum.Material.Neon
		local len = (5 + math.random() * 4) * s
		animate(0.35, function(u)
			local l = len * (0.3 + 0.7 * math.sin(math.pi * math.min(1, u * 1.4)))
			line.Size = Vector3.new(0.12 * s, l, 0.12 * s)
			line.CFrame = CFrame.new(base - Vector3.new(0, 6 * s * u + l / 2, 0))
			line.Transparency = 0.2 + 0.8 * u
		end, function() line:Destroy() end)
	end
end
local function leapFX(char, big, lines)
	if char:GetAttribute("MechaLegsFXLeapEnabled") == false then return end
	fireBurst(char, "L", big)
	fireBurst(char, "R", big)
	speedLines(char, lines)
	char:SetAttribute("MechaLegsFXLeapCount", (char:GetAttribute("MechaLegsFXLeapCount") or 0) + 1)
end

local lastShown = setmetatable({}, {__mode = "k"})
local function maybe(char, at)
	if typeof(at) ~= "number" or math.abs(workspace:GetServerTimeNow() - at) > STALE then return end
	if lastShown[char] and math.abs(at - lastShown[char]) < 0.5 then return end -- one effect per jump
	lastShown[char] = at
	puff(char)
	leapFX(char, 1.6, 10) -- v1.1
end

-- v1.1: the leap itself (takeoff = stamp + windup)
local lastLeap = setmetatable({}, {__mode = "k"})
local function maybeLeap(char, at)
	if char:GetAttribute("MechaLegsEnabled") ~= true then return end
	if typeof(at) ~= "number" or math.abs(workspace:GetServerTimeNow() - at) > STALE then return end
	if lastLeap[char] and math.abs(at - lastLeap[char]) < 0.5 then return end
	lastLeap[char] = at
	local windup = tonumber(char:GetAttribute("JumpWindup")) or 0.12
	task.delay(math.max(0, at + windup - workspace:GetServerTimeNow()), function()
		if char.Parent then leapFX(char, 1, 8) end
	end)
end

local function onCharacter(char)
	char:SetAttribute("MechaLegsFXVersion", VERSION)
	char:GetAttributeChangedSignal("JumpDoubleAt"):Connect(function() maybe(char, char:GetAttribute("JumpDoubleAt")) end)
	char:GetAttributeChangedSignal("JumpDoublePredictedAt"):Connect(function()
		if char == player.Character then maybe(char, char:GetAttribute("JumpDoublePredictedAt")) end
	end)
	char:GetAttributeChangedSignal("JumpPredictedAt"):Connect(function() -- v1.1: own leap
		if char == player.Character then maybeLeap(char, char:GetAttribute("JumpPredictedAt")) end
	end)
	char:GetAttributeChangedSignal("JumpStartedAt"):Connect(function() -- v1.1: everyone's leap (server stamp)
		if char ~= player.Character then maybeLeap(char, char:GetAttribute("JumpStartedAt")) end
	end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
