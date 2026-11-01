-- TenoAttackServer v1.1 (Mecha Dino Arena) — the Tenontosaurus' scratch and rear tail slam (server authority). MDA-172,
-- plan docs/plans/TENO_KIT_v1.0.md Task 5 (deterministic map), mockup docs/mockups/teno_attacks_options.html v0.2
-- (Kepu 2026-10-31: "Tap = scratch, hold = slam"; "Tail slam should have 3 charges and a 8 second cool down"; "a rear slam
-- it lifts and slams its tail in that back. It'll be good to run away and tail slam enemies chasing it as well as slam off
-- pouncing raptors").
-- Who: player characters with the model attribute TenoAttackEnabled == true (TenoModelData 1.1).
-- Remote ReplicatedStorage.DinoTenoAttack (RemoteEvent), client -> server: (kind, stamp[, hold])
--   kind "hold"    the ATTACK press is being held (TenoAttackTest sends it at TenoSlamHoldMin with a charge left):
--                  TenoHoldSince = stamp (clamped to [now - 1, now]) — the wind-up others see.
--   kind "cancel"  the hold ended without an attack (death, stun, menu): TenoHoldSince = 0.
--   kind "scratch" a tap: front claw swipe.
--   kind "slam"    a release after the hold (hold = held seconds): rear tail slam; with no charge left it is a scratch.
--   Every kind is refused with a reason in TenoAttackServerResult (+ TenoAttackServerResultAt): "badArg", "dead",
--   "disabled", "menu", "stunned", "dazed", "pinned", "busy" (a slam impact pending), "cooldown" (scratch within
--   TenoScratchGap of the last one), "empty" (hold with no charge); accepted = "ok" / "emptyScratch" (slam -> scratch).
--   A refused "hold" / scratch / slam also clears TenoHoldSince.
-- Numbers (model attributes, TenoModelData 1.1; x = character scale): TenoScratchDamage 8, TenoScratchGap 0.5,
--   TenoScratchReach 5.5 (x), TenoScratchShove 6 (x), TenoSlamDamage 40, TenoSlamCharges 3, TenoSlamRefill 8,
--   TenoSlamHoldMin 0.22, TenoSlamRange 15 (x), TenoSlamArc 220, TenoSlamToss 35 (studs, not scaled), TenoSlamStun 1,
--   TenoSlamDropTime 0.13.
-- Targets (HerreraMovesServer 1.1's rules): players' characters and Workspace.DinoIsland.Bots models with Hitboxes,
--   Bitable, Species or IsBot, not self, not KO, alive; players only where ModeRules.canAffect allows; never a squadmate
--   (SquadRules 1.0 sameChar). Distance = the nearest point of the target's Hitboxes.
--   Scratch: at stamp + 0.17 s (the claw's down-stroke; at most 0.17 s after the request), every target within
--     TenoScratchReach x scale of the claw point (the ArmR joint) whose root is inside a 90° cone in front (HRP
--     LookVector): TenoScratchDamage x takenMul (none while EnergyShieldUntil > now) and a TenoScratchShove x scale shove
--     away (players: HeadbuttShove*, bots: anchored slide; latched raptors: no shove). TenoScratchAt = now (last).
--   Slam: a charge is used (refill timer starts if not running), TenoSlamAt = now, TenoSlamHold = hold; impact
--     TenoSlamDropTime s later: every target within TenoSlamRange x scale of the hips (HRP) whose root is inside
--     TenoSlamArc degrees centred on the back (-LookVector), plus every raptor latched on the teno (PounceLatched, its
--     PounceLatchPart inside the teno; not pins): damage TenoSlamDamage x takenMul (none while shielded), tossed
--     TenoSlamToss studs away from the hips and stunned TenoSlamStun s:
--       players: StunTossFrom = hips, StunTossDistance, StunTossAt = impact, StunnedUntil = max(it, impact + 0.6 + stun)
--                (StunClient 1.1's toss); latched ones also ShakeOffReason "slammed", ShakeOffAt = impact (last;
--                PounceServer releases).
--       bots:    latched: ShakeOffReason "slammed", ShakeOffAt (BotServer releases), then (after the release) the toss;
--                the toss = MineServer 1.1 launchBot's arc (anchored, 0.6 s, one backward flip), then
--                StunnedUntil = max(it, landing + stun).
--     Impact stamps on the teno: TenoSlamPoint (ground below the rest Tail3 / Tail4 joint), TenoSlamHits, TenoSlamBucked,
--     TenoSlamTargets / TenoSlamBuckedNames (hit model names joined by "|", for TenoFX's number pops),
--     TenoSlamImpactAt (last; TenoFX reacts to this one).
--   Charges: TenoSlamChargesMax, TenoSlamLeft, TenoSlamRefillStart, TenoSlamRefillAt (server times; 0 = full): +1 every
--     TenoSlamRefill s until full.
-- Switches (script attributes): TenoAttackServerEnabled (default true, read at start), TenoAttackModeRulesEnabled
--   (default true; false = players can always be hit), TenoAttackSquadEnabled (default true).
-- Diagnostics: script TenoAttackServerVersion, TenoAttackRequests, TenoAttackScratches, TenoAttackSlams, TenoAttackHits,
--   TenoAttackBucked, TenoAttackSquadSkips, TenoAttackMode; character TenoScratchCount, TenoSlamCount, TenoScratchHits,
--   TenoScratchTargets (names joined by "|"),
--   TenoAttackServerVersion.
-- v1.1 (Tenontosaurus stat rows, plan docs/plans/TENO_STATS_v1.0.md; SkillEffects 1.31 writes the attributes). Switch: script
--   attribute TenoAttackStatsEnabled (default true, read at each use; false = 1.0):
--   * Brace III: every slam target also takes the character's TenoBraceBonus (TenoStatsServer 1.0: +TenoBraceStack per hit
--     taken while holding), read at the impact.
--   * Buck Off I: a latched raptor also takes TenoBuckBonus, unless the teno is stunned at the impact.
--   * Buck Off II (TenoBuckFree true, a raptor latched on the teno, the teno not stunned): "hold" is accepted at 0 charges
--     and a "slam" at 0 charges stays a slam; no charge is used (character TenoSlamFree true; false otherwise).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
local SCRATCH_HIT_AT = 0.17     -- s after the press: mockup T1 + T2 / 2
local SCRATCH_CONE = math.rad(45)
local SHOVE_TIME = 0.3
local TOSS_TIME, TOSS_HEIGHT = 0.6, 8 -- StunClient / MineServer toss
local HOLD_BACK = 1             -- s a hold stamp may be in the past
local DEFAULTS = {TenoScratchDamage = 8, TenoScratchGap = 0.5, TenoScratchReach = 5.5, TenoScratchShove = 6,
	TenoSlamDamage = 40, TenoSlamCharges = 3, TenoSlamRefill = 8, TenoSlamHoldMin = 0.22, TenoSlamRange = 15,
	TenoSlamArc = 220, TenoSlamToss = 35, TenoSlamStun = 1, TenoSlamDropTime = 0.13}

script:SetAttribute("TenoAttackServerVersion", VERSION)
for _, k in ipairs({"TenoAttackRequests", "TenoAttackScratches", "TenoAttackSlams", "TenoAttackHits", "TenoAttackBucked",
	"TenoAttackSquadSkips"}) do
	script:SetAttribute(k, 0)
end
for _, k in ipairs({"TenoAttackServerEnabled", "TenoAttackModeRulesEnabled", "TenoAttackSquadEnabled", "TenoAttackStatsEnabled"}) do -- v1.1: + Stats
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local enabled = script:GetAttribute("TenoAttackServerEnabled") ~= false

local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function get(char, k) return num(char, k, DEFAULTS[k]) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

-- mode + squad rules (HerreraMovesServer 1.1) --------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TenoAttackMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TenoAttackSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("TenoAttackSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("TenoAttackModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end

-- targets (HerreraMovesServer 1.1 / InkServer 1.4 rules) ----------------------------------------------------------------
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
-- nearest distance from a point to the target's hitboxes
local function gap(m, pos)
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
local function shielded(m, t) return num(m, "EnergyShieldUntil", 0) > t end
-- damage taken multiplier: roar debuff x daze star x Stun Breaker star (HerreraMovesServer 1.1)
local function takenMul(m, t)
	local mul = 1
	local u, dm = m:GetAttribute("DebuffUntil"), m:GetAttribute("DebuffDamageTakenMul")
	if typeof(u) == "number" and typeof(dm) == "number" and t < u then mul = dm end
	if num(m, "DazedUntil", 0) > t then mul *= math.max(1, num(m, "DazedDamageMul", 1)) end
	if num(m, "StunBreakImmuneUntil", 0) > t then mul = 0 end
	return mul
end
local function takeHealth(m, d, char, player, with, t)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return false end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", with)
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
		return true
	end
	return false
end
local function damage(char, player, m, base, with, t)
	if shielded(m, t) then return 0 end
	local d = math.max(0, base) * takenMul(m, t)
	if d > 0 then takeHealth(m, d, char, player, with, t) end
	return d
end

-- ground rays -------------------------------------------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function setExclude(extra)
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, e in ipairs(extra or {}) do table.insert(ex, e) end
	rayParams.FilterDescendantsInstances = ex
end
local function groundY(pos, fallback)
	local g = workspace:Raycast(Vector3.new(pos.X, pos.Y + 40, pos.Z), Vector3.new(0, -160, 0), rayParams)
	return g and g.Position.Y or fallback
end

-- shove (scratch) and toss (slam) ------------------------------------------------------------------------------------------
local function shove(src, m, dist, t) -- HerreraMovesServer 1.1 push's pattern
	local sRoot, mRoot = rootOf(src), rootOf(m)
	if not (sRoot and mRoot) or dist <= 0 then return false end
	if Players:GetPlayerFromCharacter(m) then
		m:SetAttribute("HeadbuttShoveFrom", sRoot.Position)
		m:SetAttribute("HeadbuttShoveDist", dist)
		m:SetAttribute("HeadbuttShoveTime", SHOVE_TIME)
		m:SetAttribute("HeadbuttShoveAt", t) -- last: HeadbuttShove 1.0 pushes it
		return true
	elseif m:GetAttribute("PounceLatched") == true or mRoot.Anchored then
		return false
	end
	local start = mRoot.Position
	local away = flat(start - sRoot.Position)
	away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
	local land = start + away * dist
	setExclude({src, m})
	local lift = start.Y - groundY(start, start.Y - 3)
	local landPos = Vector3.new(land.X, groundY(land, start.Y - lift) + lift, land.Z)
	local rot = mRoot.CFrame - mRoot.Position
	mRoot.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < SHOVE_TIME do
			local u = math.clamp((os.clock() - t0) / SHOVE_TIME, 0, 1)
			if not mRoot.Parent then return end
			mRoot.CFrame = CFrame.new(start:Lerp(landPos, 1 - (1 - u) * (1 - u))) * rot
			task.wait()
		end
		if mRoot.Parent then
			mRoot.CFrame = CFrame.new(landPos) * rot
			mRoot.Anchored = false
		end
	end)
	return true
end

-- bot thrown away from `from` (MineServer 1.1 launchBot's arc)
local function tossBot(m, from, dist, stun)
	local hrp = rootOf(m)
	if not hrp or m:GetAttribute("DummyState") == "ko" then return "none" end
	local t = now()
	if hrp.Anchored then
		m:SetAttribute("StunnedUntil", math.max(num(m, "StunnedUntil", 0), t + stun))
		m:SetAttribute("TenoTossResult", "stunOnly")
		return "stunOnly"
	end
	local start = hrp.Position
	local away = flat(start - from)
	if away.Magnitude < 0.5 then away = -flat(hrp.CFrame.LookVector) end
	away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
	local isl = workspace:FindFirstChild("DinoIsland")
	local limit = (isl and isl:GetAttribute("IslandWanderLimit")) or 230
	local land = flat(start) + away * dist
	land = Vector3.new(math.clamp(land.X, -limit, limit), 0, math.clamp(land.Z, -limit, limit))
	setExclude({m})
	local lift = start.Y - groundY(start, start.Y - 3)
	local landPos = Vector3.new(land.X, groundY(Vector3.new(land.X, start.Y, land.Z), start.Y - lift) + lift, land.Z)
	local rot = CFrame.lookAt(Vector3.zero, -away) -- faces the teno, flies backward
	hrp.Anchored = true
	m:SetAttribute("StunnedUntil", math.max(num(m, "StunnedUntil", 0), t + TOSS_TIME + stun))
	m:SetAttribute("TenoTossResult", "tossed")
	task.spawn(function()
		local t0 = os.clock()
		while m.Parent do
			local u = math.min(1, (os.clock() - t0) / TOSS_TIME)
			local e = u * u * (3 - 2 * u)
			local pos = start:Lerp(landPos, u) + Vector3.new(0, 4 * TOSS_HEIGHT * u * (1 - u), 0)
			hrp.CFrame = CFrame.new(pos) * rot * CFrame.Angles(2 * math.pi * e, 0, 0) -- one backward flip
			if u >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if m.Parent then
			hrp.CFrame = CFrame.new(landPos) * rot
			hrp.Anchored = false
			m:SetAttribute("StunnedUntil", math.max(num(m, "StunnedUntil", 0), now() + stun))
		end
	end)
	return "tossed"
end

-- per-character state ------------------------------------------------------------------------------------------------------
local chars = {} -- [char] = {charges, refillStart, refillAt, lastScratch, slamUntil}
local function maxCharges(char) return math.max(1, math.floor(get(char, "TenoSlamCharges"))) end
local function publish(char, st)
	char:SetAttribute("TenoSlamChargesMax", maxCharges(char))
	char:SetAttribute("TenoSlamLeft", st.charges)
	char:SetAttribute("TenoSlamRefillStart", st.refillStart or 0)
	char:SetAttribute("TenoSlamRefillAt", st.refillAt or 0)
end
local function track(char)
	if chars[char] or char:GetAttribute("TenoAttackEnabled") ~= true then return chars[char] end
	local st = {charges = maxCharges(char), lastScratch = -math.huge, slamUntil = 0}
	chars[char] = st
	char:SetAttribute("TenoAttackServerVersion", VERSION)
	char:SetAttribute("TenoHoldSince", 0)
	publish(char, st)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	return st
end
RunService.Heartbeat:Connect(function()
	local t
	for char, st in pairs(chars) do
		if st.refillAt then
			t = t or now()
			if t >= st.refillAt then
				st.charges = math.min(maxCharges(char), st.charges + 1)
				if st.charges < maxCharges(char) then
					st.refillStart, st.refillAt = st.refillAt, st.refillAt + math.max(0.5, get(char, "TenoSlamRefill"))
				else
					st.refillStart, st.refillAt = nil, nil
				end
				publish(char, st)
			end
		end
	end
end)

local function setResult(char, r, t)
	char:SetAttribute("TenoAttackServerResult", r)
	char:SetAttribute("TenoAttackServerResultAt", t)
end

local remote = ReplicatedStorage:FindFirstChild("DinoTenoAttack")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoTenoAttack"
	remote.Parent = ReplicatedStorage
end

-- the claw point (ArmR joint) and the rear impact point (rest Tail4 joint = end of Tail3), world space
local function jointPos(char, name, fallback)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == name and d.Part0 then return (d.Part0.CFrame * d.C0).Position end
	end
	return fallback
end

-- v1.1: raptors latched on the teno (not pins) and Buck Off II
local function statsOn() return script:GetAttribute("TenoAttackStatsEnabled") ~= false end
local function latchersOn(char)
	local list = {}
	local all = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(all, pl.Character) end end
	for _, b in ipairs(bots()) do table.insert(all, b) end
	for _, m in ipairs(all) do
		if m ~= char and m:GetAttribute("PounceLatched") == true and m:GetAttribute("PounceMode") ~= "pin" then
			local v = m:FindFirstChild("PounceLatchPart")
			if v and v:IsA("ObjectValue") and v.Value ~= nil and v.Value:IsDescendantOf(char) then table.insert(list, m) end
		end
	end
	return list
end
local function freeSlam(char, t)
	return statsOn() and char:GetAttribute("TenoBuckFree") == true and num(char, "StunnedUntil", 0) <= t and #latchersOn(char) > 0
end

local function doScratch(player, char, st, t, stamp)
	st.lastScratch = t
	char:SetAttribute("TenoScratchCount", (char:GetAttribute("TenoScratchCount") or 0) + 1)
	count("TenoAttackScratches")
	char:SetAttribute("TenoHoldSince", 0)
	char:SetAttribute("TenoScratchAt", t) -- last: poses + TenoFX
	local delay = math.clamp(math.min(stamp, t) + SCRATCH_HIT_AT - t, 0, SCRATCH_HIT_AT)
	task.delay(delay, function()
		local root = rootOf(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not char.Parent or not root or not hum or hum.Health <= 0 then return end
		local ti = now()
		local s = char:GetScale()
		local fwd = flat(root.CFrame.LookVector)
		fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zAxis
		local claw = jointPos(char, "ArmR", root.Position + fwd * 4.7 * s)
		local reach = math.max(0, get(char, "TenoScratchReach")) * s
		local shoveDist = math.max(0, get(char, "TenoScratchShove")) * s
		local n, names = 0, {}
		for _, m in ipairs(candidates(char)) do
			local v = flat(rootOf(m).Position - root.Position)
			if v.Magnitude > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= SCRATCH_CONE and gap(m, claw) <= reach then
				damage(char, player, m, get(char, "TenoScratchDamage"), "scratch", ti)
				if not shielded(m, ti) then shove(char, m, shoveDist, ti) end
				n += 1
				table.insert(names, m.Name)
			end
		end
		count("TenoAttackHits", n)
		char:SetAttribute("TenoScratchHits", n)
		char:SetAttribute("TenoScratchTargets", table.concat(names, "|"))
		char:SetAttribute("TenoScratchHitAt", ti)
	end)
end

local function doSlam(player, char, st, t, hold)
	local free = freeSlam(char, t) -- v1.1: Buck Off II
	char:SetAttribute("TenoSlamFree", free)
	if not free then st.charges -= 1 end
	if not free and not st.refillAt then st.refillStart, st.refillAt = t, t + math.max(0.5, get(char, "TenoSlamRefill")) end
	publish(char, st)
	local drop = math.max(0, get(char, "TenoSlamDropTime"))
	st.slamUntil = t + drop
	char:SetAttribute("TenoSlamCount", (char:GetAttribute("TenoSlamCount") or 0) + 1)
	count("TenoAttackSlams")
	char:SetAttribute("TenoSlamHold", math.clamp(tonumber(hold) or 1, 0, 2))
	char:SetAttribute("TenoHoldSince", 0)
	char:SetAttribute("TenoSlamAt", t) -- last: poses + TenoFX wind-down
	task.delay(drop, function()
		local root = rootOf(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not char.Parent or not root or not hum or hum.Health <= 0 then return end
		local ti = now()
		local s = char:GetScale()
		local hips = root.Position
		local back = -flat(root.CFrame.LookVector)
		back = back.Magnitude > 1e-3 and back.Unit or -Vector3.zAxis
		local range = math.max(0, get(char, "TenoSlamRange")) * s
		local half = math.rad(math.clamp(get(char, "TenoSlamArc"), 0, 360) / 2)
		local toss = math.max(0, get(char, "TenoSlamToss"))
		local stun = math.max(0, get(char, "TenoSlamStun"))
		local dmg = get(char, "TenoSlamDamage")
		local braceBonus = statsOn() and math.max(0, num(char, "TenoBraceBonus", 0)) or 0 -- v1.1: Brace III
		local buckBonus = (statsOn() and num(char, "StunnedUntil", 0) <= ti) and math.max(0, num(char, "TenoBuckBonus", 0)) or 0 -- v1.1: Buck Off I
		local hit, bucked, names, buckedNames = {}, 0, {}, {}
		local function latchedOnMe(m)
			if m:GetAttribute("PounceLatched") ~= true or m:GetAttribute("PounceMode") == "pin" then return false end
			local v = m:FindFirstChild("PounceLatchPart")
			return v and v:IsA("ObjectValue") and v.Value ~= nil and v.Value:IsDescendantOf(char)
		end
		local function apply(m, latched)
			if hit[m] then return end
			hit[m] = true
			damage(char, player, m, dmg + braceBonus + (latched and buckBonus or 0), "tailslam", ti) -- v1.1: + bonuses
			local isPlayer = Players:GetPlayerFromCharacter(m) ~= nil
			if isPlayer then
				m:SetAttribute("StunTossFrom", hips)
				m:SetAttribute("StunTossDistance", toss)
				m:SetAttribute("StunTossAt", ti)
				m:SetAttribute("StunnedUntil", math.max(num(m, "StunnedUntil", 0), ti + TOSS_TIME + stun))
				if latched then
					m:SetAttribute("ShakeOffReason", "slammed")
					m:SetAttribute("ShakeOffAt", ti) -- last: PounceServer releases the latch
				end
			elseif latched then
				m:SetAttribute("ShakeOffReason", "slammed")
				m:SetAttribute("ShakeOffAt", ti) -- BotServer releases the latch, then the toss
				task.spawn(function()
					local t0 = os.clock()
					while m.Parent and m:GetAttribute("PounceLatched") == true and os.clock() - t0 < 0.5 do
						RunService.Heartbeat:Wait()
					end
					RunService.Heartbeat:Wait()
					if m.Parent then tossBot(m, hips, toss, stun) end
				end)
			else
				tossBot(m, hips, toss, stun)
			end
			if latched then
				bucked += 1
				table.insert(buckedNames, m.Name)
			else
				table.insert(names, m.Name)
			end
		end
		-- latched raptors first (they may be inside the teno's own body, any side)
		local all = {}
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(all, pl.Character) end end
		for _, b in ipairs(bots()) do table.insert(all, b) end
		for _, m in ipairs(all) do
			if m ~= char and latchedOnMe(m) and mayAffect(char, m) then apply(m, true) end
		end
		-- the rear zone
		for _, m in ipairs(candidates(char)) do
			if not hit[m] then
				local v = flat(rootOf(m).Position - hips)
				local inArc = v.Magnitude < 1e-3 or math.acos(math.clamp(back:Dot(v.Unit), -1, 1)) <= half
				if inArc and gap(m, hips) <= range then apply(m, false) end
			end
		end
		local n = 0
		for _ in pairs(hit) do n += 1 end
		count("TenoAttackHits", n)
		count("TenoAttackBucked", bucked)
		-- impact point: ground below the end of Tail3 (rest pose)
		setExclude({char})
		local tp = jointPos(char, "Tail4", hips + back * range * 0.5)
		char:SetAttribute("TenoSlamPoint", Vector3.new(tp.X, groundY(tp, hips.Y - 4 * s), tp.Z))
		char:SetAttribute("TenoSlamHits", n)
		char:SetAttribute("TenoSlamBucked", bucked)
		char:SetAttribute("TenoSlamTargets", table.concat(names, "|"))
		char:SetAttribute("TenoSlamBuckedNames", table.concat(buckedNames, "|"))
		char:SetAttribute("TenoSlamImpactAt", ti) -- last: TenoFX reacts to this one
	end)
end

remote.OnServerEvent:Connect(function(player, kind, stamp, hold)
	count("TenoAttackRequests")
	local char = player.Character
	if not char then return end
	local st = track(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp or (kind ~= "hold" and kind ~= "cancel" and kind ~= "scratch" and kind ~= "slam") then
		r = "badArg"
	elseif not hum or hum.Health <= 0 or not rootOf(char) then
		r = "dead"
	elseif not enabled or not st or char:GetAttribute("TenoAttackEnabled") ~= true then
		r = "disabled"
	elseif kind == "cancel" then
		char:SetAttribute("TenoHoldSince", 0)
		setResult(char, "ok", t)
		return
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif num(char, "StunnedUntil", 0) > t then
		r = "stunned"
	elseif num(char, "DazedUntil", 0) > t then
		r = "dazed"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif t < st.slamUntil then
		r = "busy"
	end
	if not r and kind == "hold" then
		if st.charges < 1 and not freeSlam(char, t) then -- v1.1: Buck Off II
			r = "empty"
		else
			char:SetAttribute("TenoHoldSince", math.clamp(stamp, t - HOLD_BACK, t))
			setResult(char, "ok", t)
			return
		end
	end
	local result = "ok"
	if not r and kind == "slam" and st.charges < 1 and not freeSlam(char, t) then -- v1.1: Buck Off II
		kind, result = "scratch", "emptyScratch"
	end
	if not r and kind == "scratch" and t - st.lastScratch < math.max(0, get(char, "TenoScratchGap")) then
		r = "cooldown"
	end
	if r then
		if st then char:SetAttribute("TenoHoldSince", 0) end
		setResult(char, r, t)
		return
	end
	setResult(char, result, t)
	if kind == "scratch" then
		doScratch(player, char, st, t, stamp)
	else
		doSlam(player, char, st, t, hold)
	end
end)

local function onCharacter(char)
	task.defer(function()
		if char.Parent then track(char) end
	end)
	char:GetAttributeChangedSignal("TenoAttackEnabled"):Connect(function() track(char) end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
