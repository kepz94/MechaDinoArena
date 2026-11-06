-- TrooAttackServer v1.0 (Mecha Dino Arena) — the Troodon's Glow Pod Toss (server authority). MDA-333, plan
-- docs/plans/TROODON_KIT_v1.0.md Task 4 (deterministic map), mockup docs/mockups/troodon_kit_options_v0.1.html attack A
-- (Kepu 2026-11-06 15:38: "Let's go with your recommendations": attack A, the proposed numbers; red-team "Lead the target").
-- Patterns copied, not edited: DiloAttackServer 1.5 (request -> checks -> timed resolve, soft aim, targets, mode / squad
-- rules, takenMul, Back Plating, kills), HerreraMovesServer 1.6 Goo puddle (players slowed through SprintTest attributes,
-- bots by WalkSpeed scaling on Stepped, BotServer untouched), MedStationServer 1.3 (SquadRules squad heal on Humanoid.Health,
-- capped at MaxHealth; the ArenaPvP bridge copies it into DummyHealth), JumpServer 1.3 (charges: each refills after the
-- previous refill).
-- Remote ReplicatedStorage.DinoTrooAttack (RemoteEvent), client -> server: (stamp) on every ATTACK press (TrooAttackTest 1.0).
--   Checks in order -> character TrooAttackServerResult (+ TrooAttackServerResultAt): "badArg" (stamp not a number), "dead",
--   "disabled" (script TrooAttackServerEnabled false or character TrooAttackEnabled ~= true), "menu" (player InMenu),
--   "stunned" (StunnedUntil), "dazed" (DazedUntil), "pinned" (PinHeld), "cooldown" (< TrooMinGap since the last accepted
--   throw), "charges" (no pod charge left); else "ok".
-- Charges (server-owned): TrooPodCharges (2) max; an accepted throw uses one; each used charge refills TrooPodRefill (3) s
--   after the previous refill (one at a time). Published: character TrooPodLeft, TrooPodRefillAt (server time of the next
--   refill, 0 when full). A new character starts full.
-- Throw (accepted): character TrooThrowAt = now (the press, for other clients' poses). At press + TrooPodWindup (0.34 s): if
--   the troodon is dead / gone / in the menu / stunned / dazed / pinned the throw is cancelled and the charge refunded
--   (character TrooThrowCancelAt; script TrooThrowCancels). Else the pod leaves the hands: aim = the closest allowed enemy whose
--   root is within TrooAssistAngle (30) degrees of the flat facing and TrooAssistMax (22.5) x scale studs (flat) of the root;
--   led (TrooPodLead true, Kepu "Lead the target"): its root + its flat velocity x TrooPodFlight; TrooPodLead false: its root;
--   the point is clamped to TrooPodRange (22.5) x scale studs (flat) from the root; no target: root + facing x TrooPodRange x
--   scale. To = the ground under that point. Stamps (the pod): TrooPodFrom (the hands' midpoint, ArmL_hand / ArmR_hand), TrooPodTo,
--   TrooPodFlight (TrooPodFlight s), TrooPodTarget (name or ""), then TrooPodAt = now (last).
-- Splat (TrooPodFlight s later; a pod in the air always splats, even if the troodon died): a zone at To for TrooZoneTime (3) s,
--   radius TrooZoneRadius (5) x scale + the target's root (half its larger flat size; flat distance to the root's centre;
--   |dy| <= 10 x scale). Owner stamps TrooZoneId, TrooZoneCenter,
--   TrooZoneUntil, then TrooZoneAt (last). Enemies inside: TrooPodDamage (6) x takenMul x Back Plating (from To) off
--   DummyHealth (none while EnergyShieldUntil > now); the troodon heals TrooSelfHeal (2) per enemy it damaged (Humanoid.Health,
--   capped at MaxHealth). Allies inside: +TrooZoneHeal (5).
-- Ticks at +1 / +2 / +3 s: enemies inside: TrooZoneDps (3) x takenMul (skipped while shielded); allies inside: +TrooZoneHeal.
-- Slow (every 0.2 s): an enemy inside: player TrooSlowUntil = now + 0.3, TrooSlowMul = TrooZoneSlowMul (0.75) (SprintTest
--   1.22); bot: the same two stamps (StatusBadges' SLOW badge) and WalkSpeed x TrooSlowMul while inside, put back 0.3 s after
--   it leaves (HerreraMovesServer's botSlow pattern).
-- One zone per target: a target inside several zones gets the ticks and the slow of the newest one only (target TrooZoneOf =
--   that zone's id; nil when in none). Splat damage / heal always come from the zone that splatted.
-- Allies = squadmates (SquadRules 1.0 sameChar, the Arena squads; MedStationServer's rule): never damaged or slowed, healed on
--   Humanoid.Health (capped at MaxHealth). Non-squad players are never healed; bots are never healed. Mode rules: ModeRules
--   canAffect (DiloAttackServer's mayAffect).
-- Target stamps: TrooHitKind ("splat" / "tick"), TrooHitBy, then TrooHitAt (last); TrooHealAmount, then TrooHealAt (last; also on
--   the troodon for its self-heal). Kills: KilledBy / KilledByUserId / KilledWith ("troopod" splat / "troozone" tick) / KilledAt.
-- Test hook (Studio only, off by default, must be unset at publish): script attribute TrooTestAllyName = a bot's name: that
--   bot counts as an ally (never damaged or slowed; healed on its DummyHealth, capped at DummyMaxHealth) so the heal path is
--   checked without a second player. Ignored on a live server (RunService:IsStudio() false).
-- Switches (script attributes): TrooAttackServerEnabled (default true, read at start), TrooAttackModeRulesEnabled,
--   TrooAttackSquadEnabled, TrooAttackPlatingEnabled (default true each, read at each use).
-- Diagnostics: script TrooAttackServerVersion, TrooAttackRequests, TrooZoneHits (enemy damage events), TrooZoneHeals (ally heal
--   events), TrooSelfHeals, TrooThrowCancels, TrooAttackMode; character TrooAttackServerResult, TrooAttackServerResultAt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local DEFAULTS = {TrooPodWindup = 0.34, TrooPodFlight = 0.55, TrooPodRange = 22.5, TrooPodCharges = 2, TrooPodRefill = 3,
	TrooMinGap = 0.35, TrooAssistAngle = 30, TrooAssistMax = 22.5, TrooZoneRadius = 5, TrooZoneTime = 3, TrooPodDamage = 6,
	TrooZoneDps = 3, TrooZoneSlowMul = 0.75, TrooZoneHeal = 5, TrooSelfHeal = 2}
local SLOW_TICK = 0.2
local SLOW_HOLD = 0.3
local MAX_WINDUP = 1

script:SetAttribute("TrooAttackServerVersion", VERSION)
for _, k in ipairs({"TrooAttackRequests", "TrooZoneHits", "TrooZoneHeals", "TrooSelfHeals", "TrooThrowCancels"}) do
	script:SetAttribute(k, 0)
end
for _, k in ipairs({"TrooAttackServerEnabled", "TrooAttackModeRulesEnabled", "TrooAttackSquadEnabled", "TrooAttackPlatingEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local enabled = script:GetAttribute("TrooAttackServerEnabled") ~= false

local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function get(char, k) return num(char, k, DEFAULTS[k]) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end
local function scaleOf(m)
	local ok, v = pcall(function() return m:GetScale() end)
	return ok and v or 1
end

-- mode + squad rules (DiloAttackServer 1.5) -------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TrooAttackMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TrooAttackSquadEnabled") == false or not a then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b) == true
end
local function bots()
	local isl = workspace:FindFirstChild("DinoIsland")
	local f = isl and isl:FindFirstChild("Bots")
	return f and f:GetChildren() or {}
end
local function isBot(m)
	local isl = workspace:FindFirstChild("DinoIsland")
	local f = isl and isl:FindFirstChild("Bots")
	return f ~= nil and m.Parent == f
end
local function testAlly(m) -- Studio-only hook (see the header)
	if not RunService:IsStudio() then return false end
	local n = script:GetAttribute("TrooTestAllyName")
	return type(n) == "string" and n ~= "" and m.Name == n and isBot(m)
end
-- z: the zone (or throw) context {owner = character, player = Player}; the owner may have died since
local function srcChar(z)
	if z.owner and z.owner.Parent then return z.owner end
	return z.player and z.player.Character or nil
end
local function isAlly(z, m)
	if testAlly(m) then return true end
	return squadmate(srcChar(z), m)
end
local function mayHarm(z, target)
	if isAlly(z, target) then return false end
	if script:GetAttribute("TrooAttackModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(z.player ~= nil, tpl ~= nil, inMenu, MODE)
end

-- targets (DiloAttackServer 1.5 rules) --------------------------------------------------------------------------------------
local function isTarget(m, self)
	if not (m:IsA("Model") and m ~= self and m:IsDescendantOf(workspace)) then return false end
	if not m:FindFirstChild("Hitboxes") or m:GetAttribute("Bitable") ~= true then return false end
	if m:GetAttribute("Species") == nil and m:GetAttribute("IsBot") ~= true then return false end
	if m:GetAttribute("DummyState") == "ko" then return false end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return false end
	return rootOf(m) ~= nil
end
local function everyone(self)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and c ~= self and isTarget(c, self) then table.insert(list, c) end
	end
	for _, b in ipairs(bots()) do
		if isTarget(b, self) then table.insert(list, b) end
	end
	return list
end
local function shielded(m, t) return num(m, "EnergyShieldUntil", 0) > t end
local function takenMul(m, t)
	local mul = 1
	local u, dm = m:GetAttribute("DebuffUntil"), m:GetAttribute("DebuffDamageTakenMul")
	if typeof(u) == "number" and typeof(dm) == "number" and t < u then mul = dm end
	if num(m, "DazedUntil", 0) > t then mul *= math.max(1, num(m, "DazedDamageMul", 1)) end
	if num(m, "StunBreakImmuneUntil", 0) > t then mul = 0 end
	return mul
end
local crestCache
local function plating(m, fromPos)
	if script:GetAttribute("TrooAttackPlatingEnabled") == false or typeof(fromPos) ~= "Vector3" then return 1 end
	if crestCache == nil then
		crestCache = false
		pcall(function() crestCache = require(ServerStorage:WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end)
	end
	if crestCache and crestCache.plating then return crestCache.plating(m, fromPos) end
	return 1
end
local function takeHealth(m, d, killerName, killerId, with, t)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return false end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", killerName)
		m:SetAttribute("KilledByUserId", killerId)
		m:SetAttribute("KilledWith", with)
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
	end
	return true
end
-- heal: a player character on Humanoid.Health (MedStationServer), the Studio test ally on DummyHealth; returns HP added
local function heal(m, amount)
	if amount <= 0 then return 0 end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if Players:GetPlayerFromCharacter(m) then
		if not hum or hum.Health <= 0 or hum.Health >= hum.MaxHealth then return 0 end
		local before = hum.Health
		hum.Health = math.min(hum.MaxHealth, before + amount)
		return hum.Health - before
	end
	local hp, mx = m:GetAttribute("DummyHealth"), m:GetAttribute("DummyMaxHealth")
	if typeof(hp) ~= "number" or typeof(mx) ~= "number" or hp <= 0 or hp >= mx then return 0 end
	local after = math.min(mx, hp + amount)
	m:SetAttribute("DummyHealth", after)
	return after - hp
end
local function stampHeal(m, added, t)
	if added <= 0 then return end
	m:SetAttribute("TrooHealAmount", math.floor(added * 10 + 0.5) / 10)
	m:SetAttribute("TrooHealAt", t) -- last: TrooFX "+N"
end
local function stampHit(m, kind, by, t)
	m:SetAttribute("TrooHitKind", kind)
	m:SetAttribute("TrooHitBy", by)
	m:SetAttribute("TrooHitAt", t) -- last: TrooFX hit flash
end

-- world -----------------------------------------------------------------------------------------------------------------------
local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
local function worldExclude()
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "HerreraPartsFX", "HerreraMovesFX", "TrooFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	worldParams.FilterDescendantsInstances = ex
	return worldParams
end
local function groundBelow(p)
	local hit = workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -120, 0), worldExclude())
	return hit and hit.Position or Vector3.new(p.X, p.Y - 3, p.Z)
end
local function facing(char)
	local r = rootOf(char)
	local f = r and flat(r.CFrame.LookVector) or Vector3.zero
	return f.Magnitude > 1e-3 and f.Unit or -Vector3.zAxis
end
local function hands(char)
	local a, b = char:FindFirstChild("ArmL_hand", true), char:FindFirstChild("ArmR_hand", true)
	if a and b and a:IsA("BasePart") and b:IsA("BasePart") then return (a.Position + b.Position) / 2 end
	local r = rootOf(char)
	return r and r.Position or Vector3.zero
end

-- charges (JumpServer 1.3's rule) -------------------------------------------------------------------------------------------
local states = setmetatable({}, {__mode = "k"})
local function publish(char, st)
	char:SetAttribute("TrooPodLeft", st.left)
	char:SetAttribute("TrooPodRefillAt", st.refills[1] or 0)
end
local function stateOf(char)
	local mx = math.max(1, math.floor(get(char, "TrooPodCharges")))
	local st = states[char]
	if not st or st.max ~= mx then
		st = {max = mx, left = mx, refills = {}, last = -math.huge}
		states[char] = st
		publish(char, st)
	end
	return st
end
local function refund(char, st)
	if st.left >= st.max then return end
	st.left += 1
	table.remove(st.refills) -- the furthest pending refill (later ones keep their times)
	publish(char, st)
end
RunService.Heartbeat:Connect(function()
	local t
	for char, st in pairs(states) do
		if char.Parent and st.refills[1] then
			t = t or now()
			if t >= st.refills[1] then
				table.remove(st.refills, 1)
				st.left = math.min(st.max, st.left + 1)
				publish(char, st)
			end
		end
	end
end)
local function setResult(char, r, t)
	char:SetAttribute("TrooAttackServerResult", r)
	char:SetAttribute("TrooAttackServerResultAt", t)
end
local function blocked(player, char, t)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not rootOf(char) then return "dead" end
	if player:GetAttribute("InMenu") == true then return "menu" end
	if num(char, "StunnedUntil", 0) > t then return "stunned" end
	if num(char, "DazedUntil", 0) > t then return "dazed" end
	if char:GetAttribute("PinHeld") == true then return "pinned" end
	return nil
end

-- zones -------------------------------------------------------------------------------------------------------------------------
local zones = {} -- {id, owner, player, ownerName, ownerId, center, radius, dyMax, startT, untilT, ticks, maxTicks, dps, heal, slowMul}
local nextId = 0
local function inside(z, m) -- the map's "radius x scale + their root": + half the root's larger flat size
	local r = rootOf(m)
	if not r then return false end
	local reach = z.radius + math.max(r.Size.X, r.Size.Z) / 2
	return flat(r.Position - z.center).Magnitude <= reach and math.abs(r.Position.Y - z.center.Y) <= z.dyMax
end
local function newestZoneOf(m)
	local best
	for _, z in ipairs(zones) do
		if (not best or z.id > best.id) and inside(z, m) then best = z end
	end
	return best
end
local function splat(z, t)
	local hits = 0
	for _, m in ipairs(everyone(z.owner)) do
		if inside(z, m) then
			if isAlly(z, m) then
				local added = heal(m, z.heal)
				if added > 0 then
					stampHeal(m, added, t)
					count("TrooZoneHeals")
				end
			elseif mayHarm(z, m) and not shielded(m, t) then
				local d = z.podDamage * takenMul(m, t) * plating(m, z.center)
				if takeHealth(m, d, z.ownerName, z.ownerId, "troopod", t) then
					hits += 1
					stampHit(m, "splat", z.ownerName, t)
					count("TrooZoneHits")
				end
			end
		end
	end
	local o = z.owner
	if hits > 0 and o and o.Parent then -- the self-heal
		local added = heal(o, hits * z.selfHeal)
		if added > 0 then
			stampHeal(o, added, t)
			count("TrooSelfHeals")
		end
	end
	return hits
end
local function tick(z, t)
	for _, m in ipairs(everyone(z.owner)) do
		if inside(z, m) and newestZoneOf(m) == z then
			if isAlly(z, m) then
				local added = heal(m, z.heal)
				if added > 0 then
					stampHeal(m, added, t)
					count("TrooZoneHeals")
				end
			elseif mayHarm(z, m) and not shielded(m, t) then
				if takeHealth(m, z.dps * takenMul(m, t), z.ownerName, z.ownerId, "troozone", t) then
					stampHit(m, "tick", z.ownerName, t)
					count("TrooZoneHits")
				end
			end
		end
	end
end
local function makeZone(c, to, t)
	nextId += 1
	local owner = c.owner
	local s = c.scale
	local life = math.max(0.5, c.zoneTime)
	local z = {id = nextId, owner = owner, player = c.player, ownerName = owner.Name, ownerId = c.player and c.player.UserId or 0,
		center = to, radius = math.max(0.5, c.radius) * s, dyMax = 10 * s, startT = t, untilT = t + life, ticks = 0,
		maxTicks = math.floor(life + 1e-6), dps = math.max(0, c.dps), heal = math.max(0, c.heal), podDamage = math.max(0, c.podDamage),
		selfHeal = math.max(0, c.selfHeal), slowMul = math.clamp(c.slowMul, 0.05, 1)}
	table.insert(zones, z)
	if owner.Parent then
		owner:SetAttribute("TrooZoneId", z.id)
		owner:SetAttribute("TrooZoneCenter", to)
		owner:SetAttribute("TrooZoneUntil", z.untilT)
		owner:SetAttribute("TrooZoneAt", t) -- last: TrooFX zone
	end
	splat(z, t)
	return z
end

-- bot slow (HerreraMovesServer's botSlow pattern) ----------------------------------------------------------------------------
local botSlow = {} -- [bot] = {hum, base, set, untilT, mul}
RunService.Stepped:Connect(function()
	local t = now()
	for m, e in pairs(botSlow) do
		local hum = e.hum
		if not m.Parent or not hum.Parent then
			botSlow[m] = nil
		else
			local cur = hum.WalkSpeed
			if e.set == nil or math.abs(cur - e.set) > 1e-3 then e.base = cur end
			if t < e.untilT then
				e.set = e.base * math.clamp(e.mul, 0.05, 1)
				hum.WalkSpeed = e.set
			else
				hum.WalkSpeed = e.base
				botSlow[m] = nil
			end
		end
	end
end)
local function slowTarget(m, mul, untilT)
	m:SetAttribute("TrooSlowMul", mul)
	m:SetAttribute("TrooSlowUntil", untilT)
	if not Players:GetPlayerFromCharacter(m) then
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then
			local e = botSlow[m] or {hum = hum}
			e.untilT, e.mul = math.max(e.untilT or 0, untilT), mul
			botSlow[m] = e
		end
	end
end

-- zone loop: ticks at +1 / +2 / +3 s, the slow every 0.2 s, TrooZoneOf ----------------------------------------------------------
local slowAcc = 0
local zoneOf = setmetatable({}, {__mode = "k"})
RunService.Heartbeat:Connect(function(dt)
	if #zones == 0 and next(zoneOf) == nil then return end
	local t = now()
	for _, z in ipairs(zones) do
		while z.ticks < z.maxTicks and t >= z.startT + z.ticks + 1 do
			z.ticks += 1
			tick(z, z.startT + z.ticks)
		end
	end
	slowAcc += dt
	if slowAcc >= SLOW_TICK then
		slowAcc = 0
		local seen = {}
		for _, m in ipairs(everyone(nil)) do
			local z = newestZoneOf(m)
			if z then
				seen[m] = true
				if m:GetAttribute("TrooZoneOf") ~= z.id then m:SetAttribute("TrooZoneOf", z.id) end
				zoneOf[m] = true
				if m ~= z.owner and not isAlly(z, m) and mayHarm(z, m) then slowTarget(m, z.slowMul, t + SLOW_HOLD) end
			end
		end
		for m in pairs(zoneOf) do
			if not seen[m] then
				zoneOf[m] = nil
				if m.Parent then m:SetAttribute("TrooZoneOf", nil) end
			end
		end
	end
	for i = #zones, 1, -1 do
		local z = zones[i]
		if t >= z.untilT and z.ticks >= z.maxTicks then table.remove(zones, i) end
	end
end)

-- the throw ---------------------------------------------------------------------------------------------------------------------
local function pickTarget(char, root, fwd)
	local s = scaleOf(char)
	local half = math.rad(math.clamp(get(char, "TrooAssistAngle"), 0, 180))
	local hi = math.max(0, get(char, "TrooAssistMax")) * s
	local z = {owner = char, player = Players:GetPlayerFromCharacter(char)}
	local best, bestD = nil, math.huge
	for _, m in ipairs(everyone(char)) do
		if mayHarm(z, m) then
			local v = flat(rootOf(m).Position - root.Position)
			local d = v.Magnitude
			if d <= hi and d > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= half and d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end
local function release(player, char, st)
	local t = now()
	if not char.Parent or blocked(player, char, t) then
		refund(char, st)
		char:SetAttribute("TrooThrowCancelAt", t)
		count("TrooThrowCancels")
		return
	end
	local root = rootOf(char)
	local s = scaleOf(char)
	local fwd = facing(char)
	local flight = math.clamp(get(char, "TrooPodFlight"), 0.05, 3)
	local range = math.max(0, get(char, "TrooPodRange")) * s
	local target = pickTarget(char, root, fwd)
	local aim
	if target then
		local tr = rootOf(target)
		aim = tr.Position
		if char:GetAttribute("TrooPodLead") ~= false then aim += flat(tr.AssemblyLinearVelocity) * flight end
	else
		aim = root.Position + fwd * range
	end
	local off = flat(aim - root.Position)
	if off.Magnitude > range then aim = Vector3.new(root.Position.X, aim.Y, root.Position.Z) + off.Unit * range end
	local to = groundBelow(aim)
	local from = hands(char)
	char:SetAttribute("TrooPodFrom", from)
	char:SetAttribute("TrooPodTo", to)
	char:SetAttribute("TrooPodFlight", flight)
	char:SetAttribute("TrooPodTarget", target and target.Name or "")
	char:SetAttribute("TrooPodAt", t) -- last: poses + TrooFX pod
	local c = {owner = char, player = player, scale = s, radius = get(char, "TrooZoneRadius"), zoneTime = get(char, "TrooZoneTime"),
		dps = get(char, "TrooZoneDps"), heal = get(char, "TrooZoneHeal"), podDamage = get(char, "TrooPodDamage"),
		selfHeal = get(char, "TrooSelfHeal"), slowMul = get(char, "TrooZoneSlowMul")}
	task.delay(flight, function() makeZone(c, to, now()) end)
end

-- remote ------------------------------------------------------------------------------------------------------------------------
local remote = ReplicatedStorage:FindFirstChild("DinoTrooAttack")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoTrooAttack"
	remote.Parent = ReplicatedStorage
end
remote.OnServerEvent:Connect(function(player, stamp)
	count("TrooAttackRequests")
	local char = player.Character
	if not char then return end
	local t = now()
	local r
	local hum = char:FindFirstChildOfClass("Humanoid")
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		r = "badArg"
	elseif not hum or hum.Health <= 0 then
		r = "dead"
	elseif not enabled or char:GetAttribute("TrooAttackEnabled") ~= true then
		r = "disabled"
	else
		r = blocked(player, char, t)
	end
	local st = (not r) and stateOf(char) or nil
	if not r and t - st.last < math.max(0, get(char, "TrooMinGap")) then r = "cooldown" end
	if not r and st.left < 1 then r = "charges" end
	if r then
		setResult(char, r, t)
		return
	end
	setResult(char, "ok", t)
	st.last = t
	st.left -= 1
	local lastRefill = st.refills[#st.refills]
	table.insert(st.refills, math.max(t, lastRefill or t) + math.max(0.1, get(char, "TrooPodRefill")))
	publish(char, st)
	char:SetAttribute("TrooThrowAt", t) -- the press: other clients' poses
	local w = math.clamp(get(char, "TrooPodWindup"), 0, MAX_WINDUP)
	local delay = math.clamp(math.min(stamp, t) + w - t, 0, w)
	task.delay(delay, release, player, char, st)
end)

-- a new character starts with full charges
local function onCharacter(char)
	task.defer(function()
		if char.Parent and char:GetAttribute("TrooAttackEnabled") == true then stateOf(char) end
	end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(onCharacter)
	if pl.Character then onCharacter(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
