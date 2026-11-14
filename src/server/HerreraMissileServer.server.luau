-- HerreraMissileServer v1.2 (Mecha Dino Arena) — the Herrera's Cruise Missile (mecha part cmissile): launch, the flown missile,
-- the blast and the star crater. MDA-521, plan docs/plans/HERRERA_CRUISE_MISSILE_v1.0.md Task 3, mockup
-- docs/mockups/herrera_cruise_missile_v0.1.html; Kepu 2026-11-13 17:23 "a cruise missile that works just like the call of duty one
-- ... where you're directing the missile as it's flying down on the map. Zero damage to teammates but does 40 damage to enemies with
-- a big splash radius maybe just around the size of the point or a little bigger", picks "Flat 40 everywhere", recharge 25 / 20 s.
-- Remote ReplicatedStorage.DinoCruiseMissileRequest(stamp, action, pos):
--   * action nil / "launch" (the usual timed-part press from MechaButtons 1.49): checks as every Herrera part (dead / disabled
--     (CruiseEnabled) / menu / stunned / pinned / dazed / cooldown CruiseReadyAt; already flying = "flying"); recharge starts now
--     (CruiseReadyAt = now + CruiseCooldown). The missile starts CruiseAhead (40) studs in front of the Herrera (flat facing) and
--     CruiseHeight (250) studs above the ground there. Character CruiseStart, CruisePos, CruiseLaunchAt, CruiseFlying = true (last).
--   * "steer" (pos): the owner's client flies the missile; the server moves its own position toward pos by at most CruiseSteer (30)
--     studs/s flat (x 0.5 after the boost) and down by at most CruiseFall (30) studs/s (x CruiseBoostMul (3) after the boost), never
--     up, +CruiseSlack (2) studs per update. CruisePos is published at most 10 times a second.
--   * "boost": once per flight, CruiseBoosted = true.
--   * "impact" (pos): clamped the same way, then the blast at the server's point.
--   A flight past CruiseMaxFlight (10) s, the Herrera dying / leaving / stunned / pinned, or the part going off: the missile falls
--   straight down from where it is at the boosted speed (the server moves it, CruiseDropping = true) and blows up on the ground.
-- The Herrera stands still while it flies the missile: its HumanoidRootPart is anchored at the launch (only if it was not anchored
--   already) and let go at the blast / drop (switch: script attribute CruiseHoldBodyEnabled, default true, read at the launch).
-- Blast: every target dino (players + bots; squad + mode rules = no teammates) whose hitboxes come within CruiseRadius (45; 55 at
--   II) studs of the blast point takes CruiseDamage (40) flat (energy shield = 0, the roar debuff / daze / Stun Breaker star taken
--   multipliers, armor as every part hit; KilledWith "cruisemissile"). Character stamps CruiseBoomPos, CruiseBoomRadius, CruiseHits
--   (names, comma separated), CruiseHitCount, CruiseCraterUntil, CruiseFlying = false, then CruiseBoomAt (last).
--   Star (CruiseCrater > 0): a burning crater for CruiseCrater (4) s: every 0.5 s CruiseCraterDps (8) x 0.5 to target dinos within the
--   radius (stamp CruiseCraterTicks).
-- Players only (no bot entrance; plan do-not-touch). Switch: script attribute HerreraMissileServerEnabled (default true, read per
--   request; false = the remote does nothing). Numbers: script attributes CruiseHeight, CruiseAhead, CruiseFall, CruiseSteer,
--   CruiseBoostMul, CruiseMaxFlight, CruiseSlack. Diagnostics: script HerreraMissileServerVersion, CruiseLaunches, CruiseBlasts,
--   CruiseHitsTotal, CruiseClamps (updates the server cut short); character CruiseServerResult / CruiseServerResultAt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 3x steering (MDA-525)
VERSION = "1.2" -- v1.2 pre-match lock
-- v1.2 (pre-match lock, MDA-528, plan docs/plans/PREMATCH_LOCK_PAN_v1.0.md rule 2; Kepu 2026-11-13 18:23 "all mecha abilities
--   and actions should be unplayable ... during the count down", pick "A · Locked everywhere"): every request from a player whose
--   character PrematchLockUntil (PracticeServer 1.12) is after the server time is dropped before the handler runs (handler
--   bodies unchanged; bots never locked: BotUse / BotMechaUse call the handlers directly).
-- v1.1 (MDA-525; Kepu 2026-11-13 17:59 "make the rocket more maneuverable like on Cod", pick "3x: 90 studs/s"): the flat steering
--   limit is CruiseSteerV2 (90) studs/s (x 0.5 after the boost) while script attribute CruiseSteerV2Enabled ~= false (default
--   true, read at each update; false = 1.0's CruiseSteer 30). HerreraMissileCam 1.1 steers at the same speed.
script:SetAttribute("HerreraMissileServerVersion", VERSION)
if script:GetAttribute("CruiseSteerV2Enabled") == nil then script:SetAttribute("CruiseSteerV2Enabled", true) end -- v1.1
if script:GetAttribute("CruiseSteerV2") == nil then script:SetAttribute("CruiseSteerV2", 90) end -- v1.1
local CFG = {HerreraMissileServerEnabled = true, CruiseHeight = 250, CruiseAhead = 40, CruiseFall = 30, CruiseSteer = 30,
	CruiseBoostMul = 3, CruiseMaxFlight = 10, CruiseSlack = 2, CruiseHoldBodyEnabled = true}
for k, v in pairs(CFG) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
for _, k in ipairs({"CruiseLaunches", "CruiseBlasts", "CruiseHitsTotal", "CruiseClamps"}) do script:SetAttribute(k, 0) end
local function cfg(k) return tonumber(script:GetAttribute(k)) or CFG[k] end
local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- rules (HerreraMovesServer's: mode + squad) -------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
local squadMod
local function squadmate(a, b)
	if not squadMod then
		local m = ServerStorage:FindFirstChild("DinoArcade") and ServerStorage.DinoArcade:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b)
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end
local function isTarget(m, self)
	if not (m:IsA("Model") and m ~= self and m:IsDescendantOf(workspace)) then return false end
	if not m:FindFirstChild("Hitboxes") or m:GetAttribute("Bitable") ~= true then return false end
	if m:GetAttribute("Species") == nil and m:GetAttribute("IsBot") ~= true then return false end
	if m:GetAttribute("DummyState") == "ko" then return false end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return false end
	return rootOf(m) ~= nil
end
local function bots()
	local isl = workspace:FindFirstChild("DinoIsland")
	local f = isl and isl:FindFirstChild("Bots")
	return f and f:GetChildren() or {}
end
local function candidates(self)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and isTarget(c, self) and mayAffect(self, c) then table.insert(list, c) end
	end
	for _, b in ipairs(bots()) do
		if isTarget(b, self) and mayAffect(self, b) then table.insert(list, b) end
	end
	return list
end
local function gap(m, pos) -- nearest distance from a point to the target's hitboxes
	local best = math.huge
	local hb = m:FindFirstChild("Hitboxes")
	for _, p in ipairs(hb and hb:GetChildren() or {}) do
		if p:IsA("BasePart") then
			local lp = p.CFrame:PointToObjectSpace(pos)
			local h = p.Size / 2
			local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
			best = math.min(best, (lp - c).Magnitude)
		end
	end
	if best == math.huge then
		local r = rootOf(m)
		best = r and (r.Position - pos).Magnitude or math.huge
	end
	return best
end
local function takenMul(m, t)
	local mul = 1
	local u, dm = m:GetAttribute("DebuffUntil"), m:GetAttribute("DebuffDamageTakenMul")
	if typeof(u) == "number" and typeof(dm) == "number" and t < u then mul = dm end
	if num(m, "DazedUntil", 0) > t then mul *= math.max(1, num(m, "DazedDamageMul", 1)) end
	if num(m, "StunBreakImmuneUntil", 0) > t then mul = 0 end
	return mul
end
local armorMod
local function armorMul(victim)
	if armorMod == nil then armorMod = false; pcall(function() armorMod = require(ServerStorage:WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end) end
	return armorMod and armorMod.armor and armorMod.armor(victim) or 1
end
local function damage(char, player, m, base, t)
	if num(m, "EnergyShieldUntil", 0) > t then return 0 end
	local d = math.max(0, base) * takenMul(m, t) * armorMul(m)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return 0 end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", "cruisemissile")
		m:SetAttribute("KilledAt", t) -- last
	end
	return d
end
local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
local function worldOnly()
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	for _, b in ipairs(bots()) do table.insert(ex, b) end
	local isl = workspace:FindFirstChild("DinoIsland")
	local tg = isl and isl:FindFirstChild("TallGrass")
	if tg then table.insert(ex, tg) end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "HerreraPartsFX", "HerreraMovesFX", "HerreraMissileFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	worldParams.FilterDescendantsInstances = ex
	return worldParams
end
local function groundY(pos)
	local g = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -2000, 0), worldOnly())
	return g and g.Position.Y or (pos.Y - 250)
end

-- the remote + state ------------------------------------------------------------------------------------------------------
local remote = ReplicatedStorage:FindFirstChild("DinoCruiseMissileRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoCruiseMissileRequest"
	remote.Parent = ReplicatedStorage
end
local flights = {} -- [char] = {player, pos, t, startAt, boosted, dropping, lastPub}
local function result(char, r) char:SetAttribute("CruiseServerResult", r) char:SetAttribute("CruiseServerResultAt", now()) end
local function publish(char, st, force)
	local t = os.clock()
	if force or t - (st.lastPub or 0) >= 0.1 then
		st.lastPub = t
		char:SetAttribute("CruisePos", st.pos)
	end
end
local function clampTo(st, want, t)
	local dt = math.max(0, t - st.t)
	local slack = cfg("CruiseSlack")
	local steer = (script:GetAttribute("CruiseSteerV2Enabled") ~= false and (tonumber(script:GetAttribute("CruiseSteerV2")) or 90)
		or cfg("CruiseSteer")) * (st.boosted and 0.5 or 1) -- v1.1
	local fall = cfg("CruiseFall") * (st.boosted and cfg("CruiseBoostMul") or 1)
	local d = flat(want - st.pos)
	local maxFlat = steer * dt + slack
	local clamped = false
	if d.Magnitude > maxFlat then d = d.Unit * maxFlat clamped = true end
	local y = want.Y
	if y > st.pos.Y then y = st.pos.Y clamped = true end
	if y < st.pos.Y - (fall * dt + slack) then y = st.pos.Y - (fall * dt + slack) clamped = true end
	if clamped then count("CruiseClamps") end
	st.pos = Vector3.new(st.pos.X + d.X, y, st.pos.Z + d.Z)
	st.t = t
end
local function letGo(st)
	if st.held and st.held.Parent then st.held.Anchored = false end
	st.held = nil
end
local function blast(char, st)
	if flights[char] ~= st then return end
	flights[char] = nil
	letGo(st)
	local t = now()
	local point = st.pos
	local radius = math.max(0, num(char, "CruiseRadius", 45))
	local dmg = math.max(0, num(char, "CruiseDamage", 40))
	local names = {}
	for _, m in ipairs(candidates(char)) do
		if gap(m, point) <= radius then
			damage(char, st.player, m, dmg, t)
			table.insert(names, m.Name)
		end
	end
	count("CruiseBlasts")
	count("CruiseHitsTotal", #names)
	local crater = math.max(0, num(char, "CruiseCrater", 0))
	char:SetAttribute("CruiseBoomPos", point)
	char:SetAttribute("CruiseBoomRadius", radius)
	char:SetAttribute("CruiseHits", table.concat(names, ","))
	char:SetAttribute("CruiseHitCount", #names)
	char:SetAttribute("CruiseCraterUntil", crater > 0 and t + crater or 0)
	char:SetAttribute("CruiseDropping", false)
	char:SetAttribute("CruiseFlying", false)
	char:SetAttribute("CruiseBoomAt", t) -- last
	if crater > 0 then
		local dps = math.max(0, num(char, "CruiseCraterDps", 8))
		local player = st.player
		task.spawn(function()
			local ticks = 0
			local untilT = t + crater
			while now() < untilT do
				task.wait(0.5)
				if not char.Parent then break end
				local tt = now()
				for _, m in ipairs(candidates(char)) do
					if gap(m, point) <= radius then damage(char, player, m, dps * 0.5, tt) end
				end
				ticks += 1
				char:SetAttribute("CruiseCraterTicks", ticks)
			end
		end)
	end
end
local function landIfLow(char, st)
	local gy = groundY(st.pos)
	if st.pos.Y <= gy + 0.5 then
		st.pos = Vector3.new(st.pos.X, gy, st.pos.Z)
		publish(char, st, true)
		blast(char, st)
		return true
	end
	return false
end
local function launch(player, stamp)
	if script:GetAttribute("HerreraMissileServerEnabled") == false then return end
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = rootOf(char)
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp then r = "badArg"
	elseif not hum or hum.Health <= 0 or not root then r = "dead"
	elseif char:GetAttribute("CruiseEnabled") ~= true then r = "disabled"
	elseif player:GetAttribute("InMenu") == true then r = "menu"
	elseif num(char, "StunnedUntil", 0) > t then r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then r = "pinned"
	elseif num(char, "DazedUntil", 0) > t then r = "dazed"
	elseif flights[char] then r = "flying"
	elseif t < num(char, "CruiseReadyAt", 0) then r = "cooldown" end
	if r then result(char, r) return end
	char:SetAttribute("CruiseReadyAt", t + math.max(0.5, num(char, "CruiseCooldown", 25)))
	local fwd = flat(root.CFrame.LookVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
	local base = root.Position + fwd * cfg("CruiseAhead")
	local start = Vector3.new(base.X, groundY(base) + cfg("CruiseHeight"), base.Z)
	local st = {player = player, pos = start, t = t, startAt = t, boosted = false, dropping = false}
	flights[char] = st
	if script:GetAttribute("CruiseHoldBodyEnabled") ~= false and not root.Anchored then
		root.Anchored = true
		st.held = root
	end
	count("CruiseLaunches")
	result(char, "ok")
	char:SetAttribute("CruiseBoosted", false)
	char:SetAttribute("CruiseDropping", false)
	char:SetAttribute("CruiseStart", start)
	publish(char, st, true)
	char:SetAttribute("CruiseLaunchAt", t)
	char:SetAttribute("CruiseFlying", true) -- last
end
local function __prematchLocked(player) -- v1.2: PracticeServer 1.12 pre-match lock (see VERSION 1.2)
	local c = player and player.Character
	return c ~= nil and (tonumber(c:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()
end
remote.OnServerEvent:Connect(function(player, stamp, action, pos)
	if __prematchLocked(player) then return end -- v1.2: dropped while pre-match locked
	if script:GetAttribute("HerreraMissileServerEnabled") == false then return end
	if action == nil or action == "launch" then launch(player, stamp) return end
	local char = player.Character
	local st = char and flights[char]
	if not st or st.dropping then return end
	local t = now()
	if action == "boost" then
		if not st.boosted then
			st.boosted = true
			char:SetAttribute("CruiseBoosted", true)
		end
	elseif action == "steer" or action == "impact" then
		if typeof(pos) ~= "Vector3" or pos ~= pos then return end
		clampTo(st, pos, t)
		publish(char, st, action == "impact")
		if action == "impact" then
			blast(char, st)
		else
			landIfLow(char, st)
		end
	end
end)

-- the drop: timeout, death, stun, leaving -------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local t = now()
	for char, st in pairs(flights) do
		if not st.dropping then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local bad = not char.Parent or not hum or hum.Health <= 0 or not st.player.Parent
				or num(char, "StunnedUntil", 0) > t or char:GetAttribute("PinHeld") == true or char:GetAttribute("CruiseEnabled") ~= true
				or t - st.startAt > cfg("CruiseMaxFlight")
			if bad then
				letGo(st)
				st.dropping = true
				st.t = t
				if char.Parent then char:SetAttribute("CruiseDropping", true) end
			end
		end
		if st.dropping then
			local fall = cfg("CruiseFall") * cfg("CruiseBoostMul")
			st.pos = st.pos - Vector3.new(0, fall * dt, 0)
			st.t = t
			if char.Parent then
				publish(char, st, false)
				landIfLow(char, st)
			else
				letGo(st)
				flights[char] = nil
			end
		end
	end
end)
