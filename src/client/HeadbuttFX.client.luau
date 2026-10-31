-- HeadbuttFX v1.1 (Mecha Dino Arena) — the pachy headbutt charge effects on this client (LocalScript,
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
-- v1.1 (pachy Blood Rush, MDA-124, mockup "C · Both"): on a fresh HeadbuttSacrificeAt (HeadbuttServer 1.5, at most STALE
--   s old): a red Highlight on the pachy fading out over 0.35 s (fill 0.35 -> 1, outline 0 -> 1) and the health it paid
--   (HeadbuttSacrificeCost) popping up over the head in red (224, 40, 74) like the damage number. A sacrifice charge
--   (HeadbuttSacrificeAt within 0.05 s of HeadbuttStartedAt) draws the dust and the streaks red instead of tan / white.
--   Switch: character attribute HeadbuttFXBloodEnabled (default true; false = 1.0). Diagnostic: HeadbuttFXSacrifices.
-- Diagnostics (client-side character attributes): HeadbuttFXVersion, HeadbuttFXCharging (bool), HeadbuttFXHits.
-- v1.2 (pachy bots, BotServer 1.19): models in Workspace.DinoIsland.Bots with HeadbuttEnabled = true (Pachy Bot) get the
--   same effects as another player's pachy (dust, streaks, impact flash / ring / thud / damage number from the bot's
--   HeadbuttStartedAt / HeadbuttEndedAt / HeadbuttHitAt / HeadbuttHitDamage). Switch: this script's attribute
--   HeadbuttFXBotsEnabled (default true, read at start; false = 1.1, players only).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.2"
local BLOOD_COLOR = Color3.fromRGB(224, 40, 74) -- v1.1
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

-- v1.1: Blood Rush sacrifice
local function sacrificeFX(char)
	local hl = Instance.new("Highlight")
	hl.Name = "BloodRushFlash"
	hl.FillColor, hl.OutlineColor = BLOOD_COLOR, BLOOD_COLOR
	hl.FillTransparency, hl.OutlineTransparency = 0.35, 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = char
	hl.Parent = char
	animate(0.35, function(u)
		hl.FillTransparency = 0.35 + 0.65 * u
		hl.OutlineTransparency = u
	end, function() hl:Destroy() end)
	local cost = char:GetAttribute("HeadbuttSacrificeCost")
	local head = headPart(char)
	if typeof(cost) == "number" and head then
		local pos = head.Position + Vector3.new(0, head.Size.Y, 0)
		local holder = fxPart("BloodRushNumber", Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
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
		label.Text = "-" .. tostring(cost)
		label.TextColor3 = BLOOD_COLOR
		label.TextStrokeColor3 = Color3.fromRGB(42, 6, 16)
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
	char:SetAttribute("HeadbuttFXSacrifices", (char:GetAttribute("HeadbuttFXSacrifices") or 0) + 1)
end
local function isSacrificeCharge(char)
	local sa, sb = char:GetAttribute("HeadbuttSacrificeAt"), char:GetAttribute("HeadbuttStartedAt")
	return typeof(sa) == "number" and typeof(sb) == "number" and math.abs(sa - sb) < 0.05
end

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
	char:GetAttributeChangedSignal("HeadbuttSacrificeAt"):Connect(function() -- v1.1
		local at = char:GetAttribute("HeadbuttSacrificeAt")
		if char:GetAttribute("HeadbuttFXEnabled") == false or char:GetAttribute("HeadbuttFXBloodEnabled") == false then return end
		if typeof(at) == "number" and math.abs(workspace:GetServerTimeNow() - at) <= STALE then sacrificeFX(char) end
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
if script:GetAttribute("HeadbuttFXBotsEnabled") ~= false then -- v1.2: pachy bots
	task.spawn(function()
		local isl = workspace:WaitForChild("DinoIsland", 30)
		local bots = isl and isl:WaitForChild("Bots", 30)
		if not bots then return end
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") then onCharacter(m) end
		end
		bots.ChildAdded:Connect(function(m)
			if m:IsA("Model") then onCharacter(m) end
		end)
	end)
end

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
			local blood = on and char:GetAttribute("HeadbuttFXBloodEnabled") ~= false and isSacrificeCharge(char) -- v1.1
			for _, tr in ipairs(st.trails) do tr.Color = ColorSequence.new(blood and BLOOD_COLOR or STREAK_COLOR) end
			if st.dust then st.dust.Color = ColorSequence.new(blood and BLOOD_COLOR or DUST_COLOR) end
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
