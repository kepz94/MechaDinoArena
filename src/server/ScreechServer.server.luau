-- ScreechServer v1.0 (Mecha Dino Arena) — Raptor Screech, a raptor button part (raptor parts batch 2): an aimed sonic
-- bolt that makes the first dino it hits flinch. MDA-73, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 5, mockup
-- docs/mockups/raptor_parts_b2_scent_screech.html option C "Hold to aim" (Kepu 2026-10-29: "Raptor screech is too
-- powerful it needs to be aimed"; Thick Hide counts; star jams all three parts).
-- Settings come from the character (SkillEffects 1.8): ScreechEnabled (bought AND slotted), ScreechRange (50; 67.5
--   from II: the longest the held aim can reach), ScreechFlinch (0.5 s), ScreechCooldown (14; 10.3 from III),
--   ScreechJam (star).
-- Client -> server: ReplicatedStorage.DinoScreechRequest:FireServer(clientServerTime, heldRange). The held range is
--   how far the aim line had grown when the button was let go (MechaButtons 1.8); it is clamped to
--   [MIN_RANGE (8), ScreechRange]. Checks, first failing wins: "badArg" (stamp or range not a number), "dead",
--   "disabled" (ScreechServerEnabled false or ScreechEnabled ~= true), "stunned" (StunnedUntil > now), "latched"
--   (PounceLatched), "cooldown" (now < ScreechReadyAt), "ok". ok: ScreechReadyAt = now + ScreechCooldown,
--   ScreechCount + 1, ScreechLastRange, ScreechStartedAt = now (last; CloakServer 1.4 ends your own cloak on it).
-- Bolt: starts BOLT_AHEAD (4) studs in front of the shooter's HumanoidRootPart at its height and flies along the
--   shooter's flat facing at BOLT_SPEED (70) studs/s until it has gone the held range, hits a dino, or hits anything
--   solid (raycast that respects CanCollide; tall grass does not stop it). Each step it hits the first dino (another
--   player's character or a bot in DinoIsland.Bots, alive) whose HumanoidRootPart is within HIT_RADIUS (4) studs +
--   half its smaller width of the step's path, flat, and within its height. Look: a red neon Ball "ScreechBolt" with
--   a Trail, anchored, no collide / query / touch; a hit or the end leaves a short expanding "ScreechBurst".
-- Hit (the target's character or bot model):
--   * raptor: StunnedUntil = max(current, now + ScreechFlinch) — the game's normal stun, so Thick Hide III shortens it
--     and Thick Hide star stops it above half health (SkillEffects); a bot lies down for it like any stun.
--     ScreechHitAt = now (CloakServer 1.4 ends its cloak with "screech").
--   * T-Rex: ScreechSlowUntil = now + ScreechFlinch (SprintTest 1.7 halves a player T-Rex's speed while it lasts; bots
--     do not read it). ScreechHitAt = now.
--   * star (shooter's ScreechJam): PartsJammedAt = now on the target (AdrenalineServer 1.3, EnergyShieldServer 1.3 and
--     MechaButtons 1.8 end the target's Adrenaline, Shield and boost).
--   Target diagnostics: ScreechHitBy (shooter name), ScreechHitCount.
-- Settings: script attribute ScreechServerEnabled (default true).
-- Diagnostics: script ScreechServerVersion, ScreechRequests, ScreechHits, ScreechMisses; shooter character
--   ScreechServerResult, ScreechCount, ScreechLastRange, ScreechLastHit (target name or "" for a miss), ScreechLastEnd
--   ("hit" / "range" / "wall").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
local MIN_RANGE, BOLT_SPEED, BOLT_AHEAD, HIT_RADIUS = 8, 70, 4, 4
local RED = Color3.fromRGB(240, 90, 79)

script:SetAttribute("ScreechServerVersion", VERSION)
if script:GetAttribute("ScreechServerEnabled") == nil then script:SetAttribute("ScreechServerEnabled", true) end
script:SetAttribute("ScreechRequests", 0)
script:SetAttribute("ScreechHits", 0)
script:SetAttribute("ScreechMisses", 0)
local function on() return script:GetAttribute("ScreechServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local remote = ReplicatedStorage:FindFirstChild("DinoScreechRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoScreechRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum}
local bolts = {} -- {shooter, part, pos, dir, left, flinch, jam}

local function isTRex(model)
	local pl = Players:GetPlayerFromCharacter(model)
	local sp = tostring(pl and pl:GetAttribute("DinoSpecies") or model.Name)
	return sp:find("TRex") ~= nil
end

local function alive(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if Players:GetPlayerFromCharacter(model) then return hum ~= nil and hum.Health > 0 end
	local dh = model:GetAttribute("DummyHealth")
	if dh ~= nil then return (tonumber(dh) or 0) > 0 end
	return hum == nil or hum.Health > 0
end

local function targets(shooter)
	local out = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and c ~= shooter then table.insert(out, c) end
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

local function burst(pos, size)
	local p = Instance.new("Part")
	p.Name = "ScreechBurst"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 2
	p.Position = pos
	p.Color = RED
	p.Material = Enum.Material.Neon
	p.Transparency = 0.2
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.3), {Size = Vector3.one * size, Transparency = 1}):Play()
	Debris:AddItem(p, 0.35)
end

local function hit(b, target)
	local t = now()
	local flinch = b.flinch
	if isTRex(target) then
		target:SetAttribute("ScreechSlowUntil", t + flinch)
	else
		target:SetAttribute("StunnedUntil", math.max(tonumber(target:GetAttribute("StunnedUntil")) or 0, t + flinch))
	end
	if b.jam then target:SetAttribute("PartsJammedAt", t) end
	target:SetAttribute("ScreechHitBy", b.shooter.Name)
	target:SetAttribute("ScreechHitCount", (target:GetAttribute("ScreechHitCount") or 0) + 1)
	target:SetAttribute("ScreechHitAt", t) -- last: CloakServer reacts to it
	b.shooter:SetAttribute("ScreechLastHit", target.Name)
	script:SetAttribute("ScreechHits", (script:GetAttribute("ScreechHits") or 0) + 1)
end

local function endBolt(b, reason)
	b.done = true
	b.shooter:SetAttribute("ScreechLastEnd", reason)
	if reason ~= "hit" then
		b.shooter:SetAttribute("ScreechLastHit", "")
		script:SetAttribute("ScreechMisses", (script:GetAttribute("ScreechMisses") or 0) + 1)
	end
	burst(b.pos, reason == "hit" and 10 or 6)
	b.part:Destroy()
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

RunService.Heartbeat:Connect(function(dt)
	for i = #bolts, 1, -1 do
		local b = bolts[i]
		if b.done then
			table.remove(bolts, i)
		else
			local step = math.min(b.left, BOLT_SPEED * dt)
			local a, z = b.pos, b.pos + b.dir * step
			-- first dino along this step
			local best, bestT
			for _, m in ipairs(targets(b.shooter)) do
				local root = m:FindFirstChild("HumanoidRootPart")
				if root and alive(m) then
					local size = m:GetExtentsSize()
					local rel = Vector3.new(root.Position.X - a.X, 0, root.Position.Z - a.Z)
					local seg = Vector3.new(z.X - a.X, 0, z.Z - a.Z)
					local len2 = seg:Dot(seg)
					local k = len2 > 0 and math.clamp(rel:Dot(seg) / len2, 0, 1) or 0
					local d = (rel - seg * k).Magnitude
					local reach = HIT_RADIUS + math.min(size.X, size.Z) / 2
					if d <= reach and math.abs(root.Position.Y - a.Y) <= size.Y / 2 + HIT_RADIUS and (not bestT or k < bestT) then
						best, bestT = m, k
					end
				end
			end
			-- anything solid first?
			local ex = {b.shooter, b.part}
			for _, m in ipairs(targets(b.shooter)) do table.insert(ex, m) end
			rayParams.FilterDescendantsInstances = ex
			local wall = step > 0 and workspace:Raycast(a, z - a, rayParams)
			local wallT = wall and (wall.Position - a).Magnitude / step or nil
			if best and (not wallT or bestT <= wallT) then
				b.pos = a + (z - a) * bestT
				b.part.Position = b.pos
				hit(b, best)
				endBolt(b, "hit")
			elseif wall then
				b.pos = wall.Position
				b.part.Position = b.pos
				endBolt(b, "wall")
			else
				b.pos = z
				b.left -= step
				b.part.Position = z
				if b.left <= 1e-3 then endBolt(b, "range") end
			end
		end
	end
end)

local function makeBolt(pos)
	local p = Instance.new("Part")
	p.Name = "ScreechBolt"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 2.4
	p.Position = pos
	p.Color = RED
	p.Material = Enum.Material.Neon
	p.Transparency = 0.15
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(RED)
	tr.LightEmission = 1
	tr.Lifetime = 0.25
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.Parent = p
	p.Parent = workspace
	return p
end

remote.OnServerEvent:Connect(function(player, stamp, held)
	local char = player.Character
	local st = char and chars[char]
	if not st then return end
	script:SetAttribute("ScreechRequests", (script:GetAttribute("ScreechRequests") or 0) + 1)
	local t = now()
	local hum = st.hum
	local root = char:FindFirstChild("HumanoidRootPart")
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp or typeof(held) ~= "number" or held ~= held then
		result = "badArg"
	elseif not hum or hum.Health <= 0 or not root then
		result = "dead"
	elseif not on() or char:GetAttribute("ScreechEnabled") ~= true then
		result = "disabled"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif t < (tonumber(char:GetAttribute("ScreechReadyAt")) or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("ScreechServerResult", result)
	if result ~= "ok" then return end
	local maxR = math.max(MIN_RANGE, tonumber(char:GetAttribute("ScreechRange")) or 50)
	local range = math.clamp(held, MIN_RANGE, maxR)
	local look = root.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local pos = root.Position + dir * BOLT_AHEAD
	local jam = false
	if char:GetAttribute("ScreechJam") == true then jam = true end
	table.insert(bolts, {shooter = char, part = makeBolt(pos), pos = pos, dir = dir, left = range,
		flinch = math.max(0.05, tonumber(char:GetAttribute("ScreechFlinch")) or 0.5), jam = jam})
	char:SetAttribute("ScreechReadyAt", t + (tonumber(char:GetAttribute("ScreechCooldown")) or 0))
	char:SetAttribute("ScreechCount", (char:GetAttribute("ScreechCount") or 0) + 1)
	char:SetAttribute("ScreechLastRange", math.floor(range * 10 + 0.5) / 10)
	char:SetAttribute("ScreechStartedAt", t) -- last: readers react to this one
end)

local function onCharacter(char)
	if chars[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	chars[char] = {hum = hum}
	char:SetAttribute("ScreechReadyAt", 0)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
