-- MineServer v1.0 (Mecha Dino Arena) — Shock Mine, the raptor's trap part (path "traps"). MDA-80, plan
-- docs/plans/RAPTOR_TRAPS_v1.0.md Task 3, mockup docs/mockups/raptor_traps_options.html option B "Shock mine"
-- (Kepu 2026-10-29: "scrap it and introduce traps"; the damage hurts players too; bots trigger mines and are slowed).
-- Settings come from the character (SkillEffects 1.9): MineEnabled (bought AND slotted), MineDamage (15), MineSlow
--   (0.5 speed multiplier), MineSlowTime (2 s), MineCooldown (12; 8.8 from III), MineMax (1; 2 from II), MineJam (star).
-- Client -> server: ReplicatedStorage.DinoMineRequest:FireServer(clientServerTime) (MechaButtons 1.11). Checks, first
--   failing wins: "badArg", "dead", "disabled" (MineServerEnabled false or MineEnabled ~= true), "stunned"
--   (StunnedUntil > now), "latched" (PounceLatched), "cooldown" (now < MineReadyAt), "ok".
--   ok: MineReadyAt = now + MineCooldown, MineCount + 1, MineStartedAt = now (last; CloakServer 1.5 ends your cloak).
-- Throw: the landing point is THROW_DIST (30) studs ahead along the flat facing, pulled back to 2 studs before a wall
--   in the way (raycast that respects CanCollide), then dropped onto the ground below it. The mine flies there on an arc
--   (ARC_TIME 0.6 s, ARC_HEIGHT 8) and arms ARM_TIME (0.5) s after landing.
-- Mine: Model "ShockMine" (attributes MineOwner = owner name, MineState "flying" / "arming" / "armed"): "Base" (dark
--   disc, 3 studs), "Ring" (cyan neon ring, 3.6 studs), "Mast" (dark post 1.6 studs) with "Light" on top (cyan neon
--   ball 1.3 with a PointLight; steady while arming, blinking every 0.25 s once armed) and "TriggerRing" (faint cyan
--   ring on the ground, TRIGGER x 2 wide; Play: the flat disc alone was hard to see from the default camera at 30
--   studs); all anchored, no collide / query / touch.
-- Trigger: an armed mine goes off when a dino other than its owner (another player's character or a bot in
--   DinoIsland.Bots, alive) has its HumanoidRootPart within TRIGGER (6) studs + half its smaller width, flat, and
--   between 2 studs below and its height + 4 above the mine. Only the first dino found is hit.
--   * Damage MineDamage: a player: Humanoid:TakeDamage (Energy Shield's block applies), LastHitBy = owner name,
--     LastHitAt = now; a bot: DummyHealth -= damage, a killing blow stamps KilledBy / KilledByUserId / KilledWith "mine"
--     / KilledAt (last).
--   * Slow: MineSlowUntil = now + MineSlowTime, MineSlowMul = MineSlow on the target. Players: SprintTest 1.8 applies it.
--     Bots: this script scales the bot's Humanoid.WalkSpeed on every Stepped while slowed (it remembers the speed the
--     bot's AI last set, so the AI's own changes still land) and puts it back after; BotServer is not changed.
--   * star (owner's MineJam): PartsJammedAt = now on the target (AdrenalineServer / EnergyShieldServer / MechaButtons).
--   * Look: a cyan neon burst "MineBurst" (14 studs, 0.35 s) with sparks.
--   Target diagnostics: MineHitBy, MineHitCount; bots MineSlowed (true / false).
-- Removal: over MineMax the oldest is removed ("replaced"); after LIFETIME (60) s ("expired"); when the owner dies, leaves,
--   or MineEnabled turns false ("removed"); a hit ("hit").
-- Settings: script attribute MineServerEnabled (default true; false removes every mine and refuses throws).
-- Diagnostics: script MineServerVersion, MineRequests, MineThrown, MineHits; owner character MineServerResult,
--   MineCount, MineOut (mines on the ground), MineLastEnd ("hit" / "expired" / "replaced" / "removed"), MineLastHit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
local THROW_DIST, ARC_TIME, ARC_HEIGHT, ARM_TIME = 30, 0.6, 8, 0.5
local TRIGGER, LIFETIME, BLINK = 6, 60, 0.25
local VOLT, VOLT_CORE = Color3.fromRGB(127, 233, 255), Color3.fromRGB(225, 250, 255)
local DARK = Color3.fromRGB(46, 52, 62)

script:SetAttribute("MineServerVersion", VERSION)
if script:GetAttribute("MineServerEnabled") == nil then script:SetAttribute("MineServerEnabled", true) end
script:SetAttribute("MineRequests", 0)
script:SetAttribute("MineThrown", 0)
script:SetAttribute("MineHits", 0)
local function on() return script:GetAttribute("MineServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local remote = ReplicatedStorage:FindFirstChild("DinoMineRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoMineRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum, mines = {mine...}}
-- mine = {owner, model, light, from, to, t0, landAt, armAt, dieAt, dmg, slow, slowTime, jam, state}
local botSlow = {} -- [bot model] = {hum, base, set}

local function alive(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if Players:GetPlayerFromCharacter(model) then return hum ~= nil and hum.Health > 0 end
	local dh = model:GetAttribute("DummyHealth")
	if dh ~= nil then return (tonumber(dh) or 0) > 0 end
	return hum == nil or hum.Health > 0
end

local function targets(owner)
	local out = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and c ~= owner then table.insert(out, c) end
	end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") then table.insert(out, m) end
		end
	end
	return out
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function part(name, size, cf, color, parent, shape, neon)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if shape then p.Shape = shape end
	if neon then p.Material = Enum.Material.Neon else p.Material = Enum.Material.Metal end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

-- the mine's parts, placed around a ground point (pos = the disc's bottom centre)
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis is X; stand it up so the disc lies flat
local function placeMine(m, pos)
	m.base.CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * FLAT
	m.ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * FLAT
	m.mast.CFrame = CFrame.new(pos + Vector3.new(0, 1.1, 0)) * FLAT
	m.light.CFrame = CFrame.new(pos + Vector3.new(0, 2.0, 0))
	m.zone.CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0)) * FLAT
end
local function makeMine(owner, pos)
	local model = Instance.new("Model")
	model.Name = "ShockMine"
	model:SetAttribute("MineOwner", owner.Name)
	model:SetAttribute("MineState", "flying")
	local m = {model = model}
	m.base = part("Base", Vector3.new(0.5, 3, 3), CFrame.new(pos), DARK, model, Enum.PartType.Cylinder)
	m.ring = part("Ring", Vector3.new(0.12, 3.6, 3.6), CFrame.new(pos), VOLT, model, Enum.PartType.Cylinder, true)
	m.ring.Transparency = 0.4
	m.mast = part("Mast", Vector3.new(1.6, 0.25, 0.25), CFrame.new(pos), DARK, model, Enum.PartType.Cylinder)
	m.light = part("Light", Vector3.one * 1.3, CFrame.new(pos), VOLT_CORE, model, Enum.PartType.Ball, true)
	m.zone = part("TriggerRing", Vector3.new(0.06, TRIGGER * 2, TRIGGER * 2), CFrame.new(pos), VOLT, model,
		Enum.PartType.Cylinder, true)
	m.zone.Transparency = 0.8
	local li = Instance.new("PointLight")
	li.Color, li.Range, li.Brightness = VOLT, 10, 2
	li.Parent = m.light
	placeMine(m, pos)
	model.Parent = workspace
	return m
end

local function burst(pos)
	local p = part("MineBurst", Vector3.one * 2, CFrame.new(pos), VOLT, workspace, Enum.PartType.Ball, true)
	p.Transparency = 0.15
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(VOLT_CORE, VOLT)
	pe.LightEmission = 1
	pe.Lifetime = NumberRange.new(0.2, 0.45)
	pe.Speed = NumberRange.new(20, 34)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.8, 0)
	pe.Rate = 0
	pe.Parent = p
	pe:Emit(40)
	TweenService:Create(p, TweenInfo.new(0.35), {Size = Vector3.one * 14, Transparency = 1}):Play()
	Debris:AddItem(p, 0.5)
end

local function setOut(owner)
	local st = chars[owner]
	owner:SetAttribute("MineOut", st and #st.mines or 0)
end

local function removeMine(m, reason)
	if m.done then return end
	m.done = true
	if m.model then m.model:Destroy() end
	local st = chars[m.owner]
	if st then
		for i, x in ipairs(st.mines) do
			if x == m then table.remove(st.mines, i) break end
		end
	end
	if m.owner.Parent then
		m.owner:SetAttribute("MineLastEnd", reason)
		setOut(m.owner)
	end
end
local function removeAll(owner, reason)
	local st = chars[owner]
	if not st then return end
	for i = #st.mines, 1, -1 do removeMine(st.mines[i], reason) end
end

local function hit(m, target)
	local t = now()
	local owner = m.owner
	local pl = Players:GetPlayerFromCharacter(target)
	if pl then
		local hum = target:FindFirstChildOfClass("Humanoid")
		target:SetAttribute("LastHitBy", owner.Name)
		target:SetAttribute("LastHitAt", t)
		if hum then hum:TakeDamage(m.dmg) end
	else
		local hp = target:GetAttribute("DummyHealth")
		if typeof(hp) == "number" then
			target:SetAttribute("DummyHealth", math.max(0, hp - m.dmg))
			if hp > 0 and hp - m.dmg <= 0 then -- killing blow
				local killer = Players:GetPlayerFromCharacter(owner)
				target:SetAttribute("KilledBy", owner.Name)
				target:SetAttribute("KilledByUserId", killer and killer.UserId or 0)
				target:SetAttribute("KilledWith", "mine")
				target:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
			end
		end
		local hum = target:FindFirstChildOfClass("Humanoid")
		if hum and not botSlow[target] then botSlow[target] = {hum = hum} end
	end
	target:SetAttribute("MineSlowMul", m.slow)
	target:SetAttribute("MineSlowUntil", t + m.slowTime)
	if m.jam then target:SetAttribute("PartsJammedAt", t) end
	target:SetAttribute("MineHitBy", owner.Name)
	target:SetAttribute("MineHitCount", (target:GetAttribute("MineHitCount") or 0) + 1)
	if owner.Parent then
		owner:SetAttribute("MineLastHit", target.Name)
		owner:SetAttribute("MineHits", (owner:GetAttribute("MineHits") or 0) + 1)
	end
	script:SetAttribute("MineHits", (script:GetAttribute("MineHits") or 0) + 1)
end

RunService.Heartbeat:Connect(function()
	local t = now()
	for owner, st in pairs(chars) do
		for i = #st.mines, 1, -1 do
			local m = st.mines[i]
			if not m.done then
				if t >= m.dieAt then
					removeMine(m, "expired")
				elseif t < m.landAt then -- flying: an arc from the throw point to the ground point
					local k = math.clamp((t - m.t0) / ARC_TIME, 0, 1)
					local p = m.from:Lerp(m.to, k) + Vector3.new(0, ARC_HEIGHT * 4 * k * (1 - k), 0)
					placeMine(m, p)
				else
					if m.state == "flying" then
						placeMine(m, m.to)
						m.state = "arming"
						m.model:SetAttribute("MineState", "arming")
					end
					if m.state == "arming" and t >= m.armAt then
						m.state = "armed"
						m.model:SetAttribute("MineState", "armed")
					end
					if m.state == "armed" then
						local blinkOn = math.floor((t - m.armAt) / BLINK) % 2 == 0
						if blinkOn then m.light.Transparency = 0 else m.light.Transparency = 0.75 end
						for _, d in ipairs(targets(owner)) do
							local root = d:FindFirstChild("HumanoidRootPart")
							if root and alive(d) then
								local size = d:GetExtentsSize()
								local flat = Vector3.new(root.Position.X - m.to.X, 0, root.Position.Z - m.to.Z).Magnitude
								local dy = root.Position.Y - m.to.Y
								if flat <= TRIGGER + math.min(size.X, size.Z) / 2 and dy >= -2 and dy <= size.Y + 4 then
									burst(m.to + Vector3.new(0, 1, 0))
									hit(m, d)
									removeMine(m, "hit")
									break
								end
							end
						end
					end
				end
			end
		end
	end
end)

-- bots: scale the AI's WalkSpeed while slowed (BotServer untouched)
RunService.Stepped:Connect(function()
	local t = now()
	for model, s in pairs(botSlow) do
		local hum = s.hum
		if not model.Parent or not hum.Parent then
			botSlow[model] = nil
		else
			local cur = hum.WalkSpeed
			if s.set == nil or math.abs(cur - s.set) > 1e-3 then s.base = cur end -- the AI set a new speed
			local untilT = tonumber(model:GetAttribute("MineSlowUntil")) or 0
			if t < untilT then
				s.set = s.base * math.clamp(tonumber(model:GetAttribute("MineSlowMul")) or 1, 0.05, 1)
				hum.WalkSpeed = s.set
				if model:GetAttribute("MineSlowed") ~= true then model:SetAttribute("MineSlowed", true) end
			else
				hum.WalkSpeed = s.base
				model:SetAttribute("MineSlowed", false)
				botSlow[model] = nil
			end
		end
	end
end)

remote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	local st = char and chars[char]
	if not st then return end
	script:SetAttribute("MineRequests", (script:GetAttribute("MineRequests") or 0) + 1)
	local t = now()
	local hum = st.hum
	local root = char:FindFirstChild("HumanoidRootPart")
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 or not root then
		result = "dead"
	elseif not on() or char:GetAttribute("MineEnabled") ~= true then
		result = "disabled"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif t < (tonumber(char:GetAttribute("MineReadyAt")) or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("MineServerResult", result)
	if result ~= "ok" then return end
	-- landing point: ahead along the flat facing, short of walls, dropped onto the ground
	local look = root.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local ex = {char}
	for _, d in ipairs(targets(char)) do table.insert(ex, d) end
	for _, s in pairs(chars) do for _, m in ipairs(s.mines) do table.insert(ex, m.model) end end
	rayParams.FilterDescendantsInstances = ex
	local reach = THROW_DIST
	local wall = workspace:Raycast(root.Position, dir * THROW_DIST, rayParams)
	if wall then reach = math.max(2, (wall.Position - root.Position).Magnitude - 2) end
	local ahead = root.Position + dir * reach
	local ground = workspace:Raycast(ahead + Vector3.new(0, 40, 0), Vector3.new(0, -140, 0), rayParams)
	local to
	if ground then to = ground.Position else to = Vector3.new(ahead.X, root.Position.Y - 3, ahead.Z) end
	local from = root.Position + Vector3.new(0, 2, 0)
	local m = makeMine(char, from)
	m.owner, m.from, m.to, m.t0 = char, from, to, t
	m.landAt = t + ARC_TIME
	m.armAt = m.landAt + ARM_TIME
	m.dieAt = m.landAt + LIFETIME
	m.dmg = math.max(0, tonumber(char:GetAttribute("MineDamage")) or 15)
	m.slow = math.clamp(tonumber(char:GetAttribute("MineSlow")) or 0.5, 0.05, 1)
	m.slowTime = math.max(0, tonumber(char:GetAttribute("MineSlowTime")) or 2)
	local jam = false
	if char:GetAttribute("MineJam") == true then jam = true end
	m.jam = jam
	m.state = "flying"
	table.insert(st.mines, m)
	local max = math.max(1, tonumber(char:GetAttribute("MineMax")) or 1)
	while #st.mines > max do removeMine(st.mines[1], "replaced") end
	setOut(char)
	char:SetAttribute("MineReadyAt", t + (tonumber(char:GetAttribute("MineCooldown")) or 0))
	char:SetAttribute("MineCount", (char:GetAttribute("MineCount") or 0) + 1)
	script:SetAttribute("MineThrown", (script:GetAttribute("MineThrown") or 0) + 1)
	char:SetAttribute("MineStartedAt", t) -- last: readers react to this one
end)

local function onCharacter(char)
	if chars[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	chars[char] = {hum = hum, mines = {}}
	char:SetAttribute("MineReadyAt", 0)
	char:SetAttribute("MineOut", 0)
	char:GetAttributeChangedSignal("MineEnabled"):Connect(function()
		if char:GetAttribute("MineEnabled") ~= true then removeAll(char, "removed") end
	end)
	hum.Died:Connect(function() removeAll(char, "removed") end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeAll(char, "removed")
			chars[char] = nil
		end
	end)
end

script:GetAttributeChangedSignal("MineServerEnabled"):Connect(function()
	if on() then return end
	for char in pairs(chars) do removeAll(char, "removed") end
end)

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
