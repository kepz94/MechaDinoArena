-- HerreraMissileFX v1.0 (Mecha Dino Arena) — the Herrera Cruise Missile's effects on every client (LocalScript,
-- StarterPlayerScripts). MDA-523, plan docs/plans/HERRERA_CRUISE_MISSILE_v1.0.md Task 5, mockup
-- docs/mockups/herrera_cruise_missile_v0.1.html (picks "B · Backpack silo", "A · Thermal (CoD)"); stamps from HerreraMissileServer
-- 1.0, the silo from HerreraPartsServer 1.5 (HPart_cmissile, role "missile" pieces).
-- For every player character:
--   * launch (CruiseLaunchAt, within 1 s): the silo's missile pieces hide (LocalTransparencyModifier 1) until CruiseReadyAt; a
--     copy of the missile (bright body, red nose, a flame + smoke trail, an orange light) shoots up out of the silo 80 x k studs
--     over 0.7 s and is gone; a flash + a little smoke puff at the silo;
--   * flight (others only; your own view is HerreraMissileCam): while CruiseFlying / CruiseDropping, a missile (2.6 x k long,
--     nose down, red nose, fins) follows CruisePos (eased, 12 / s) with a fire + smoke trail and an orange light;
--   * blast (CruiseBoomAt, within 2 s, at CruiseBoomPos): an orange fireball that swells to 0.7 x the radius over 0.35 s with a
--     yellow core, then fades over 0.7 s; a white flash; a flat shock ring growing to the blast diameter (0.5 s); 60 fire bits +
--     16 debris; ground flames over the blast area for 1.2 s; a smoke column (2.5 s); a "-<CruiseDamage>" tag over every hit dino
--     (CruiseHits);
--   * star crater (CruiseCraterUntil in the future): a dark scorch disc the blast's size with an orange flickering glow and embers
--     until then.
-- k = the Herrera's scale / 2. Switch: script attribute HerreraMissileFXEnabled (default true, read at each event / frame; false =
--   no effects). Diagnostics: script HerreraMissileFXVersion, HerreraMissileFXEvents.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
script:SetAttribute("HerreraMissileFXVersion", VERSION)
if script:GetAttribute("HerreraMissileFXEnabled") == nil then script:SetAttribute("HerreraMissileFXEnabled", true) end
script:SetAttribute("HerreraMissileFXEvents", 0)
local function on() return script:GetAttribute("HerreraMissileFXEnabled") ~= false end
local function ev() script:SetAttribute("HerreraMissileFXEvents", (script:GetAttribute("HerreraMissileFXEvents") or 0) + 1) end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k) local v = m:GetAttribute(k) return typeof(v) == "number" and v == v and v or nil end
local ORANGE, FIRE, SMOKE = Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 190, 80), Color3.fromRGB(70, 70, 70)
local BRIGHT, NOSE = Color3.fromRGB(211, 219, 230), Color3.fromRGB(255, 90, 79)

local folder = workspace:FindFirstChild("HerreraMissileFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "HerreraMissileFX"
	folder.Parent = workspace
end
local function part(size, color, material, cf, transp, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material, p.Transparency, p.CFrame = size, color, material or Enum.Material.Neon, transp or 0, cf
	if shape then p.Shape = shape end
	p.Parent = folder
	return p
end
local function emitter(parent, c0, c1, size, life, rate, speed, transp0)
	local a = Instance.new("Attachment")
	a.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(c0, c1)
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size)})
	pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, transp0 or 0.1), NumberSequenceKeypoint.new(1, 1)})
	pe.Lifetime = NumberRange.new(life * 0.6, life)
	pe.Rate = rate
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.SpreadAngle = Vector2.new(20, 20)
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.LightEmission = c0 == SMOKE and 0 or 0.8
	pe.Parent = a
	return pe
end
local function burst(pos, c0, c1, n, speed, size, life)
	local holder = part(Vector3.one * 0.2, c0, Enum.Material.SmoothPlastic, CFrame.new(pos), 1)
	local pe = emitter(holder, c0, c1, size, life, 0, speed)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Acceleration = Vector3.new(0, -30, 0)
	pe.Enabled = false
	pe:Emit(n)
	Debris:AddItem(holder, life + 0.2)
end
local function scaleK(m) return (m:IsA("Model") and m:GetScale() or 2) / 2 end
local function findModel(name)
	if type(name) ~= "string" or name == "" then return nil end
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character and pl.Character.Name == name then return pl.Character end end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end
local function tag(model, text)
	local r = model:FindFirstChild("HumanoidRootPart")
	if not r then return end
	local g = Instance.new("BillboardGui")
	g.AlwaysOnTop = true
	g.Size = UDim2.fromOffset(120, 34)
	g.StudsOffsetWorldSpace = Vector3.new(0, 10 * scaleK(model), 0)
	g.Adornee = r
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 170, 60)
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.Parent = g
	g.Parent = folder
	TweenService:Create(g, TweenInfo.new(1.1), {StudsOffsetWorldSpace = g.StudsOffsetWorldSpace + Vector3.new(0, 5, 0)}):Play()
	TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(g, 1.2)
end
local function makeMissile(k)
	local m = Instance.new("Model")
	m.Name = "CruiseMissile"
	local body = part(Vector3.new(2.0 * k, 0.6 * k, 0.6 * k), BRIGHT, Enum.Material.Metal, CFrame.new(), 0, Enum.PartType.Cylinder)
	body.Name = "Body"
	body.Parent = m
	local nose = part(Vector3.one * 0.6 * k, NOSE, Enum.Material.SmoothPlastic, CFrame.new(), 0, Enum.PartType.Ball)
	nose.Name = "Nose"
	nose.Parent = m
	local fins = {}
	for i = 0, 1 do
		local f = part(Vector3.new(0.5 * k, 0.05 * k, 1.0 * k), NOSE, Enum.Material.SmoothPlastic, CFrame.new(), 0)
		f.Name = "Fin" .. i
		f.Parent = m
		fins[i + 1] = f
	end
	local flame = part(Vector3.one * 0.5 * k, FIRE, Enum.Material.Neon, CFrame.new(), 0.1, Enum.PartType.Ball)
	flame.Name = "Flame"
	flame.Parent = m
	emitter(flame, FIRE, ORANGE, 1.2 * k, 0.35, 60, 6 * k)
	emitter(flame, SMOKE, SMOKE, 2.5 * k, 1.4, 30, 3 * k, 0.4)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = ORANGE, 14 * k, 3
	light.Parent = flame
	m.Parent = folder
	-- pose: the missile's axis along dir, nose at tip
	local function pose(tip, dir)
		local cf = CFrame.lookAt(tip, tip + dir)
		local back = cf * CFrame.new(0, 0, 1.0 * k)
		body.CFrame = back * CFrame.Angles(0, math.pi / 2, 0)
		nose.CFrame = cf * CFrame.new(0, 0, 0.05 * k)
		fins[1].CFrame = cf * CFrame.new(0, 0, 1.8 * k)
		fins[2].CFrame = cf * CFrame.new(0, 0, 1.8 * k) * CFrame.Angles(0, 0, math.pi / 2)
		flame.CFrame = cf * CFrame.new(0, 0, 2.2 * k)
	end
	return m, pose
end

local W = setmetatable({}, {__mode = "k"}) -- [char] = {missile, pose, at}
local function siloMissile(char, hide)
	local m = char:FindFirstChild("HPart_cmissile")
	if not m then return end
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("HPartRole") == "missile" then p.LocalTransparencyModifier = hide and 1 or 0 end
	end
end
local function watch(char)
	if W[char] then return end
	local st = {}
	W[char] = st
	char:GetAttributeChangedSignal("CruiseLaunchAt"):Connect(function()
		local at = num(char, "CruiseLaunchAt")
		if not at or now() - at > 1 or not on() then return end
		st.hiddenUntil = num(char, "CruiseReadyAt") or (at + 25)
		siloMissile(char, true)
		local k = scaleK(char)
		local silo = char:FindFirstChild("HPart_cmissile")
		local nose
		for _, p in ipairs(silo and silo:GetChildren() or {}) do if p:GetAttribute("HPartRole") == "missile" then nose = p end end
		local from = nose and nose.Position or ((char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position or Vector3.zero) + Vector3.new(0, 3 * k, 0))
		local m, pose = makeMissile(k)
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local u = (os.clock() - t0) / 0.7
			if u >= 1 or not m.Parent then conn:Disconnect() m:Destroy() return end
			pose(from + Vector3.new(0, 80 * k * u * u + 2 * k, 0), Vector3.yAxis)
		end)
		local fl = part(Vector3.one * 2 * k, FIRE, Enum.Material.Neon, CFrame.new(from), 0.2, Enum.PartType.Ball)
		TweenService:Create(fl, TweenInfo.new(0.25), {Size = Vector3.one * 6 * k, Transparency = 1}):Play()
		Debris:AddItem(fl, 0.3)
		burst(from, SMOKE, SMOKE, 12, 6 * k, 2.5 * k, 1.2)
		ev()
	end)
	char:GetAttributeChangedSignal("CruiseBoomAt"):Connect(function()
		local at = num(char, "CruiseBoomAt")
		local p = char:GetAttribute("CruiseBoomPos")
		if not at or now() - at > 2 or typeof(p) ~= "Vector3" or not on() then return end
		if st.missile then st.missile:Destroy() st.missile = nil end
		local r = num(char, "CruiseBoomRadius") or 45
		local ball = part(Vector3.one * 4, ORANGE, Enum.Material.Neon, CFrame.new(p), 0.05, Enum.PartType.Ball)
		local core = part(Vector3.one * 3, FIRE, Enum.Material.Neon, CFrame.new(p), 0, Enum.PartType.Ball)
		local grow = TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.one * r * 1.4})
		grow.Completed:Connect(function()
			if ball.Parent then TweenService:Create(ball, TweenInfo.new(0.7), {Transparency = 1, Size = Vector3.one * r * 1.6}):Play() end
		end)
		grow:Play()
		local cg = TweenService:Create(core, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.one * r * 0.8})
		cg.Completed:Connect(function()
			if core.Parent then TweenService:Create(core, TweenInfo.new(0.5), {Transparency = 1}):Play() end
		end)
		cg:Play()
		local bl = Instance.new("PointLight")
		bl.Color, bl.Range, bl.Brightness = ORANGE, r * 1.2, 6
		bl.Parent = core
		Debris:AddItem(ball, 1.1)
		Debris:AddItem(core, 0.9)
		local fl = part(Vector3.one * 6, Color3.new(1, 1, 1), Enum.Material.Neon, CFrame.new(p), 0, Enum.PartType.Ball)
		TweenService:Create(fl, TweenInfo.new(0.15), {Size = Vector3.one * r * 0.5, Transparency = 1}):Play()
		Debris:AddItem(fl, 0.2)
		local ring = part(Vector3.new(0.4, 4, 4), FIRE, Enum.Material.Neon, CFrame.new(p + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), 0.2, Enum.PartType.Cylinder)
		TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.4, r * 2, r * 2), Transparency = 1}):Play()
		Debris:AddItem(ring, 0.55)
		burst(p + Vector3.new(0, 2, 0), FIRE, ORANGE, 60, 50, 4, 1.2)
		burst(p + Vector3.new(0, 2, 0), Color3.fromRGB(90, 80, 70), SMOKE, 16, 24, 2.5, 1.6)
		local flames = part(Vector3.new(r * 1.4, 1, r * 1.4), ORANGE, Enum.Material.SmoothPlastic, CFrame.new(p + Vector3.new(0, 1, 0)), 1)
		local fe = emitter(flames, FIRE, ORANGE, 5, 0.8, 120, 10)
		fe.EmissionDirection = Enum.NormalId.Top
		fe.SpreadAngle = Vector2.new(30, 30)
		task.delay(1.2, function() if fe.Parent then fe.Enabled = false end end)
		Debris:AddItem(flames, 2.2)
		local col = part(Vector3.new(r * 0.6, 2, r * 0.6), SMOKE, Enum.Material.SmoothPlastic, CFrame.new(p + Vector3.new(0, 2, 0)), 1)
		local pe = emitter(col, SMOKE, SMOKE, r * 0.4, 2.6, 40, 14, 0.35)
		pe.EmissionDirection = Enum.NormalId.Top
		task.delay(1.5, function() if pe.Parent then pe.Enabled = false end end)
		Debris:AddItem(col, 4.2)
		local dmg = math.floor((num(char, "CruiseDamage") or 40) + 0.5)
		for name in string.gmatch(tostring(char:GetAttribute("CruiseHits") or ""), "[^,]+") do
			local m = findModel(name)
			if m then tag(m, "-" .. dmg) end
		end
		local cu = num(char, "CruiseCraterUntil") or 0
		if cu > now() then
			local scorch = part(Vector3.new(0.2, r * 2, r * 2), Color3.fromRGB(30, 22, 18), Enum.Material.SmoothPlastic, CFrame.new(p + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), 0.2, Enum.PartType.Cylinder)
			local glow = part(Vector3.new(0.2, r * 1.6, r * 1.6), ORANGE, Enum.Material.Neon, CFrame.new(p + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2), 0.7, Enum.PartType.Cylinder)
			local em = emitter(glow, FIRE, ORANGE, 1.2, 1, 25, 6)
			em.EmissionDirection = Enum.NormalId.Top
			em.SpreadAngle = Vector2.new(60, 60)
			local left = cu - now()
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not glow.Parent then conn:Disconnect() return end
				glow.Transparency = 0.6 + 0.25 * math.sin((os.clock() - t0) * 12)
			end)
			task.delay(left, function()
				if scorch.Parent then TweenService:Create(scorch, TweenInfo.new(0.5), {Transparency = 1}):Play() end
				if glow.Parent then glow:Destroy() end
			end)
			Debris:AddItem(scorch, left + 0.6)
		end
		ev()
	end)
end
-- flight (others) + the silo missile coming back
RunService.RenderStepped:Connect(function(dt)
	local me = Players.LocalPlayer.Character
	for char, st in pairs(W) do
		if not char.Parent then
			if st.missile then st.missile:Destroy() end
			W[char] = nil
		else
			local flying = (char:GetAttribute("CruiseFlying") == true or char:GetAttribute("CruiseDropping") == true) and on()
			local p = char:GetAttribute("CruisePos")
			if flying and char ~= me and typeof(p) == "Vector3" then
				if not st.missile then
					st.missile, st.pose = makeMissile(scaleK(char))
					st.at = p
				end
				local prev = st.at
				st.at = st.at:Lerp(p, math.clamp(dt * 12, 0, 1))
				local dir = st.at - prev
				dir = dir.Magnitude > 0.05 and dir.Unit or Vector3.new(0, -1, 0)
				st.pose(st.at, dir)
			elseif st.missile then
				st.missile:Destroy()
				st.missile = nil
			end
			if st.hiddenUntil and now() >= st.hiddenUntil then
				st.hiddenUntil = nil
				siloMissile(char, false)
			end
		end
	end
end)
local function onModel(m)
	watch(m)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(onModel)
	if pl.Character then onModel(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
