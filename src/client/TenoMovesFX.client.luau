-- TenoMovesFX v1.0 (Mecha Dino Arena) — the client effects of the teno's mecha moves, build 1 (LocalScript in
-- StarterPlayerScripts; every client draws every teno). Plan docs/plans/TENO_ABILITIES_v1.0.md Task 7 (MDA-179), mockup
-- docs/mockups/teno_abilities_options.html v0.3 (rings, dust, heat glow, the catapult boulder leaving the bucket).
-- Reads TenoMovesServer 1.0's character stamps (the server also draws the boulders and rubble patches itself):
--   * Tail Grab: TenoGrabStartedAt + 0.3 s -> a white flash at the tail tip (Tail5_main * (-1.6 x scale, 0, 0));
--     TenoGrabLandAt -> a ring at TenoGrabLand, radius TenoGrabCrashRadius (6 when 0), plus dust.
--   * Boulder Mortar: TenoMortarFiredAt -> the TPart_tmortar "rock" piece hides (Transparency 1) and comes back after
--     ROCK_RELOAD (2.4) s; TenoMortarLandedAt -> a ring at TenoMortarLand, radius TenoMortarSplash, plus dust.
--   * Stomp Shockwave: TenoStompStartedAt -> the TPart_tstomp "heat" plates glow in over 0.5 s and fade out over 0.6 s
--     after the hit; TenoStompAt -> a ring at TenoStompCenter, radius TenoStompRange, plus dust.
--   * Hydraulic Leap: TenoLeapLandedAt -> a ring under the root, radius TenoLeapRadius, plus dust.
--   Ring: a flat Neon cylinder in Workspace.DinoFX_Local.TenoMovesFX growing from 2 studs to 2 x radius over RING_TIME
--   (0.5) s while fading out; dust: 10 grey puffs thrown out flat and fading over 0.8 s. Nothing collides or is queried.
-- Switch: script attribute TenoMovesFXEnabled (default true, read at each event; false = none of the above).
-- Diagnostics (LocalPlayer): TenoMovesFXVersion, TenoMovesFXEvents (count), TenoMovesFXLast (event name).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
local RING_TIME, ROCK_RELOAD = 0.5, 2.4
local player = Players.LocalPlayer
player:SetAttribute("TenoMovesFXVersion", VERSION)
if script:GetAttribute("TenoMovesFXEnabled") == nil then script:SetAttribute("TenoMovesFXEnabled", true) end
local function on() return script:GetAttribute("TenoMovesFXEnabled") ~= false end

local folder
local function fx()
	if folder and folder.Parent then return folder end
	local root = workspace:FindFirstChild("DinoFX_Local")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX_Local"
		root.Parent = workspace
	end
	folder = root:FindFirstChild("TenoMovesFX") or Instance.new("Folder")
	folder.Name = "TenoMovesFX"
	folder.Parent = root
	return folder
end
local function part(name, shape, size, cf, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transparency or 0
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = fx()
	return p
end
local function count(name)
	player:SetAttribute("TenoMovesFXEvents", (player:GetAttribute("TenoMovesFXEvents") or 0) + 1)
	player:SetAttribute("TenoMovesFXLast", name)
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function ground(pos)
	local ex = {fx()}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	rayParams.FilterDescendantsInstances = ex
	local g = workspace:Raycast(pos + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), rayParams)
	return g and g.Position or pos
end
local function ring(pos, radius, color)
	local at = ground(pos) + Vector3.new(0, 0.2, 0)
	local r = part("TenoRing", Enum.PartType.Cylinder, Vector3.new(0.3, 2, 2), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), color, 0.15)
	local d = math.max(2, radius * 2)
	TweenService:Create(r, TweenInfo.new(RING_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.3, d, d), Transparency = 1}):Play()
	task.delay(RING_TIME + 0.1, function() r:Destroy() end)
end
local function dust(pos, spread)
	local at = ground(pos)
	for i = 1, 10 do
		local a = i * 0.628 + math.random() * 0.4
		local s = 1.5 + math.random() * 1.5
		local p = part("TenoDust", Enum.PartType.Ball, Vector3.one * s, CFrame.new(at + Vector3.new(0, s / 2, 0)),
			Color3.fromRGB(205, 196, 176), 0.35)
		p.Material = Enum.Material.SmoothPlastic
		local to = at + Vector3.new(math.cos(a) * spread, s * 0.8, math.sin(a) * spread)
		TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CFrame = CFrame.new(to), Size = Vector3.one * s * 1.8, Transparency = 1}):Play()
		task.delay(0.9, function() p:Destroy() end)
	end
end
local function flash(pos, size)
	local p = part("TenoFlash", Enum.PartType.Ball, Vector3.one * size * 0.4, CFrame.new(pos), Color3.new(1, 1, 1), 0.15)
	TweenService:Create(p, TweenInfo.new(0.3), {Size = Vector3.one * size * 1.4, Transparency = 1}):Play()
	task.delay(0.35, function() p:Destroy() end)
end
local function roles(char, id, role)
	local out = {}
	local m = char:FindFirstChild("TPart_" .. id)
	if m then
		for _, d in ipairs(m:GetChildren()) do
			if d:IsA("BasePart") and d:GetAttribute("TPartRole") == role then table.insert(out, d) end
		end
	end
	return out
end
local function num(char, k, d) return tonumber(char:GetAttribute(k)) or d end
local function fresh(char, k) -- a stamp younger than 2 s
	local at = char:GetAttribute(k)
	return typeof(at) == "number" and math.abs(workspace:GetServerTimeNow() - at) < 2
end

local function watch(char)
	char:GetAttributeChangedSignal("TenoGrabStartedAt"):Connect(function()
		if not on() or not fresh(char, "TenoGrabStartedAt") then return end
		task.delay(0.3, function()
			local tip = char:FindFirstChild("Tail5_main", true)
			if tip and tip:IsA("BasePart") then
				flash((tip.CFrame * CFrame.new(-1.6 * char:GetScale(), 0, 0)).Position, 4)
				count("grab")
			end
		end)
	end)
	char:GetAttributeChangedSignal("TenoGrabLandAt"):Connect(function()
		local land = char:GetAttribute("TenoGrabLand")
		if not on() or not fresh(char, "TenoGrabLandAt") or typeof(land) ~= "Vector3" then return end
		local r = num(char, "TenoGrabCrashRadius", 0)
		ring(land, r > 0 and r or 6, Color3.fromRGB(255, 226, 160))
		dust(land, 8)
		count("grabLand")
	end)
	char:GetAttributeChangedSignal("TenoMortarFiredAt"):Connect(function()
		if not on() or not fresh(char, "TenoMortarFiredAt") then return end
		for _, rock in ipairs(roles(char, "tmortar", "rock")) do
			rock.Transparency = 1
			task.delay(ROCK_RELOAD, function() if rock.Parent then rock.Transparency = 0 end end)
		end
		count("mortarFire")
	end)
	char:GetAttributeChangedSignal("TenoMortarLandedAt"):Connect(function()
		local land = char:GetAttribute("TenoMortarLand")
		if not on() or not fresh(char, "TenoMortarLandedAt") or typeof(land) ~= "Vector3" then return end
		ring(land, num(char, "TenoMortarSplash", 10), Color3.fromRGB(255, 226, 160))
		dust(land, 10)
		count("mortarLand")
	end)
	char:GetAttributeChangedSignal("TenoStompStartedAt"):Connect(function()
		if not on() or not fresh(char, "TenoStompStartedAt") then return end
		for _, h in ipairs(roles(char, "tstomp", "heat")) do
			h.Transparency = 1
			local up = TweenService:Create(h, TweenInfo.new(0.5), {Transparency = 0})
			up.Completed:Connect(function()
				if h.Parent then TweenService:Create(h, TweenInfo.new(0.6), {Transparency = 1}):Play() end
			end)
			up:Play()
		end
		count("stompRear")
	end)
	char:GetAttributeChangedSignal("TenoStompAt"):Connect(function()
		local c = char:GetAttribute("TenoStompCenter")
		if not on() or not fresh(char, "TenoStompAt") or typeof(c) ~= "Vector3" then return end
		ring(c, num(char, "TenoStompRange", 14), Color3.fromRGB(255, 241, 200))
		dust(c, 12)
		count("stomp")
	end)
	char:GetAttributeChangedSignal("TenoLeapLandedAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not on() or not fresh(char, "TenoLeapLandedAt") or not root then return end
		ring(root.Position, num(char, "TenoLeapRadius", 12), Color3.fromRGB(255, 211, 77))
		dust(root.Position, 10)
		count("leapLand")
	end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
