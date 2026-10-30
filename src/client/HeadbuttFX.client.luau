-- HeadbuttFX v1.0 (Mecha Dino Arena) — the pachy headbutt charge effects on this client (LocalScript,
-- StarterPlayerScripts). MDA-119, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 8 (Kepu 2026-10-30: "animations that
-- indicate a speed up and the charge").
-- For every player character with HeadbuttEnabled = true (PachyModelData 1.1):
--   charging = own character: HeadbuttLocalState "charge" (HeadbuttTest 1.0); others: HeadbuttStartedAt + HeadbuttWindup
--     reached and no HeadbuttEndedAt / HeadbuttHitAt since, at most HeadbuttMaxTime + 1 s.
--   While charging: a dust cloud kicked up at the feet (ParticleEmitter, only while on the ground) and two pale speed
--     streaks off the sides of the dome (Trails on the Head hitbox). Own character only: the camera widens by
--     FOV_KICK degrees (eased in / out; applied as a delta so other camera effects keep theirs).
--   On a hit (HeadbuttHitAt, server; at most STALE s old): at the attacker's head a white flash, a dust ring and a
--     low thud (built-in collide sound, pitched down), and the damage number (HeadbuttHitDamage) popping up.
-- Switch: character attribute HeadbuttFXEnabled (default true; false = no effects for that dino).
-- Diagnostics (client-side character attributes): HeadbuttFXVersion, HeadbuttFXCharging (bool), HeadbuttFXHits.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local FOV_KICK = 8
local FOV_RATE = 10        -- per second, kick easing
local STALE = 1
local NUMBER_TIME = 0.8
local FLASH_TIME = 0.14
local RING_TIME = 0.45
local DUST_COLOR = Color3.fromRGB(196, 176, 132)
local STREAK_COLOR = Color3.fromRGB(255, 250, 235)
local NUMBER_COLOR = Color3.fromRGB(255, 214, 64)
local THUD_SOUND = "rbxasset://sounds/collide.wav"
local DEFAULTS = {HeadbuttWindup = 0.15, HeadbuttMaxTime = 1.8}

local player = Players.LocalPlayer

local fxFolder = workspace:FindFirstChild("DinoFX_Local")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DinoFX_Local"
	fxFolder.Parent = workspace
end

local function fxPart(name, size, color, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Parent = fxFolder
	return p
end

local function animate(duration, fn, done)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - t0) / duration)
		fn(u)
		if u >= 1 then
			conn:Disconnect()
			if done then done() end
		end
	end)
end

local function headPart(char)
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxSegment") == "Head" then return p end
		end
	end
	return nil
end

local function impact(char)
	local head = headPart(char) or char:FindFirstChild("HumanoidRootPart")
	if not head then return end
	local pos = head.Position + head.CFrame.LookVector * head.Size.Z * 0.3
	local scale = char:GetScale()
	-- flash
	local f = fxPart("HeadbuttFlash", Vector3.one, Color3.new(1, 1, 1), CFrame.new(pos))
	f.Shape = Enum.PartType.Ball
	f.Material = Enum.Material.Neon
	animate(FLASH_TIME, function(u)
		local d = (2 + 7 * u) * scale
		f.Size = Vector3.new(d, d, d)
		f.Transparency = 0.15 + 0.85 * u
	end, function() f:Destroy() end)
	-- dust ring on the ground under the head
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	local groundY = root and hum and (root.Position.Y - hum.HipHeight - root.Size.Y / 2) or pos.Y
	local ring = fxPart("HeadbuttRing", Vector3.new(0.4, 1, 1), DUST_COLOR,
		CFrame.new(pos.X, groundY + 0.3, pos.Z) * CFrame.Angles(0, 0, math.pi / 2))
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.SmoothPlastic
	animate(RING_TIME, function(u)
		local d = (3 + 16 * (1 - (1 - u) ^ 2)) * scale
		ring.Size = Vector3.new(0.4, d, d)
		ring.Transparency = 0.35 + 0.65 * u
	end, function() ring:Destroy() end)
	-- thud
	local s = Instance.new("Sound")
	s.SoundId = THUD_SOUND
	s.PlaybackSpeed = 0.55
	s.Volume = 0.9
	s.RollOffMaxDistance = 200
	s.Parent = f
	s:Play()
	-- damage number
	local dmg = char:GetAttribute("HeadbuttHitDamage")
	if typeof(dmg) == "number" then
		local holder = fxPart("HeadbuttNumber", Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
		holder.Transparency = 1
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(6, 3)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Adornee = holder
		gui.Parent = holder
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = "-" .. tostring(dmg)
		label.TextColor3 = NUMBER_COLOR
		label.TextStrokeColor3 = Color3.fromRGB(40, 24, 10)
		label.TextStrokeTransparency = 0
		label.Parent = gui
		animate(NUMBER_TIME, function(u)
			local sc = u < 0.12 and (0.5 + 0.8 * u / 0.12) or (u < 0.25 and (1.3 - 0.3 * (u - 0.12) / 0.13) or 1)
			label.Size = UDim2.fromScale(sc, sc)
			holder.CFrame = CFrame.new(pos + Vector3.new(0, 4 * (1 - (1 - u) ^ 2), 0))
			local fade = u > 0.65 and (u - 0.65) / 0.35 or 0
			label.TextTransparency = fade
			label.TextStrokeTransparency = fade
		end, function() holder:Destroy() end)
	end
	char:SetAttribute("HeadbuttFXHits", (char:GetAttribute("HeadbuttFXHits") or 0) + 1)
end

local tracked = {} -- [char] = {dust, trails = {}, charging}

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local function isCharging(char, own, now)
	if own then return char:GetAttribute("HeadbuttLocalState") == "charge" end
	local start = char:GetAttribute("HeadbuttStartedAt")
	if typeof(start) ~= "number" then return false end
	local t = now - start
	if t < get(char, "HeadbuttWindup") or t > get(char, "HeadbuttWindup") + get(char, "HeadbuttMaxTime") + 1 then return false end
	local e, h = char:GetAttribute("HeadbuttEndedAt"), char:GetAttribute("HeadbuttHitAt")
	if typeof(e) == "number" and e >= start - 0.001 then return false end
	if typeof(h) == "number" and h >= start - 0.001 then return false end
	return true
end

local function build(char)
	local st = {trails = {}, charging = false}
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if root and hum then
		local a = Instance.new("Attachment")
		a.Name = "HeadbuttDustAttachment"
		a.Position = Vector3.new(0, -(hum.HipHeight + root.Size.Y / 2) + 0.5, 0)
		a.Parent = root
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "HeadbuttDust"
		pe.Color = ColorSequence.new(DUST_COLOR)
		pe.LightEmission = 0
		pe.Lifetime = NumberRange.new(0.4, 0.7)
		pe.Speed = NumberRange.new(4, 9)
		pe.SpreadAngle = Vector2.new(60, 25)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4.5)})
		pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
		pe.Rate = 45
		pe.Enabled = false
		pe.Parent = a
		st.dust = pe
	end
	local head = headPart(char)
	if head then
		for _, side in ipairs({-1, 1}) do
			local a0 = Instance.new("Attachment")
			a0.Name = "HeadbuttStreak0"
			a0.Position = Vector3.new(side * head.Size.X * 0.5, head.Size.Y * 0.25, 0)
			a0.Parent = head
			local a1 = Instance.new("Attachment")
			a1.Name = "HeadbuttStreak1"
			a1.Position = Vector3.new(side * head.Size.X * 0.5, -head.Size.Y * 0.15, 0)
			a1.Parent = head
			local tr = Instance.new("Trail")
			tr.Name = "HeadbuttStreak"
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Color = ColorSequence.new(STREAK_COLOR)
			tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
			tr.Lifetime = 0.22
			tr.LightEmission = 0.6
			tr.FaceCamera = true
			tr.Enabled = false
			tr.Parent = head
			table.insert(st.trails, tr)
		end
	end
	return st
end

local function watch(char)
	if tracked[char] then return end
	if char:GetAttribute("HeadbuttEnabled") ~= true then return end
	local st = build(char)
	tracked[char] = st
	char:SetAttribute("HeadbuttFXVersion", VERSION)
	char:GetAttributeChangedSignal("HeadbuttHitAt"):Connect(function()
		local at = char:GetAttribute("HeadbuttHitAt")
		if char:GetAttribute("HeadbuttFXEnabled") == false then return end
		if typeof(at) == "number" and math.abs(workspace:GetServerTimeNow() - at) <= STALE then impact(char) end
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then tracked[char] = nil end
	end)
end

local function onCharacter(char)
	task.defer(function()
		local t0 = os.clock()
		while char.Parent and not char:FindFirstChild("Hitboxes") and os.clock() - t0 < 10 do task.wait(0.25) end
		if char.Parent then watch(char) end
	end)
	char:GetAttributeChangedSignal("HeadbuttEnabled"):Connect(function() watch(char) end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

local fovApplied = 0
RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local ownCharging = false
	for char, st in pairs(tracked) do
		local own = char == player.Character
		local on = char:GetAttribute("HeadbuttFXEnabled") ~= false and isCharging(char, own, now)
		if own then ownCharging = on end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local grounded = hum and hum.FloorMaterial ~= Enum.Material.Air
		if st.dust then st.dust.Enabled = on and grounded == true end
		if on ~= st.charging then
			st.charging = on
			for _, tr in ipairs(st.trails) do tr.Enabled = on end
			char:SetAttribute("HeadbuttFXCharging", on)
		end
	end
	-- own camera widen (delta so other camera effects keep theirs)
	local cam = workspace.CurrentCamera
	if cam then
		local target = ownCharging and FOV_KICK or 0
		local nextKick = fovApplied + (target - fovApplied) * math.min(1, dt * FOV_RATE)
		if target == 0 and math.abs(nextKick) < 0.05 then nextKick = 0 end
		if nextKick ~= fovApplied then
			cam.FieldOfView = cam.FieldOfView - fovApplied + nextKick
			fovApplied = nextKick
		end
	end
end)
