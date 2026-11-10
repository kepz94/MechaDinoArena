-- TenoAttackServer v1.8 (Mecha Dino Arena) — the Tenontosaurus' scratch and rear tail slam (server authority). MDA-172,
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
-- v1.2 (Kepu 2026-11-01, plan docs/plans/TENO_SLAM_REWORK_v1.0.md: "The tail slam only damages Dino's behind the Dino within
--   the range of the tail not anywhere in the mid section or front of the teno. Also if a raptor latches on to the back half
--   of a teno allow the tail slam to kick them off ... If a raptor is at the front half of the teno then the tail slam won't
--   kick them off"; picks "Every dino in the tail zone", "Narrow"; "Have the teno's rear tail slam function like how the
--   t-Rex bite soft aim works"; 4th charge from Buck Off star). Switch: script attribute TenoAttackRearAimEnabled (default
--   true, read at each slam; false = the 1.1 arc / range zone and every latched raptor bucked):
--   * Aim at the slam request (TenoSlamAim 1.0, ServerStorage.DinoArcade; the bite's soft aim): candidates = the targets
--     above that are not latched on the teno, in HRP space (x left, z back) with gap = their nearest hitbox to the hips;
--     reach = TenoSlamReach (18.5) x scale, aim limit TenoSlamAimMax (35 deg), zone width TenoSlamCone (70 deg).
--     Character TenoSlamAimYaw (degrees, + = the tail swings to the teno's left; TenoPose 1.2 bends the tail) and
--     TenoSlamAimTarget (name or "") are set before TenoSlamAt.
--   * Impact: the members of the zone around that aimed yaw (positions re-read at the impact) are hit: behind the hips
--     only, within reach. Latched raptors: only the ones whose PounceLatchPart centre is behind the hips (HRP-space z > 0)
--     are slammed and shaken off; a raptor latched on the front half is not touched.
--   * Charges: max = TenoSlamCharges + TenoSlamExtraCharges (SkillEffects 1.33: Buck Off star = 1); a change of either
--     republishes TenoSlamChargesMax and starts the refill when below the new max.
--   * Damage / stun come from the model (TenoModelData 1.4: TenoSlamDamage 15, TenoSlamStun 0.5).
--   The module is copied to ReplicatedStorage.TenoSlamAimShared at start (TenoAttackTest 1.2 predicts the aim for its
--   pose). Diagnostics: character TenoSlamAimYaw, TenoSlamAimTarget, TenoSlamFrontLatched (count left on); script
--   TenoAttackAimMode ("aim" / "arc" at the last slam).
-- v1.3 (teno stats part 2, MDA-184, plan docs/plans/TENO_STATS_v1.1.md; SkillEffects 1.34 writes the Teno* attributes from
--   SkillTree 1.50). Switch: script attribute TenoAttackStats2Enabled (default true, read at each use; false = 1.2):
--   * Heavy Tail: slam damage + TenoHeavyBonus (I: 3); refill time x TenoHeavyRefillMul (II: 0.75); slam reach (aim
--     TenoSlamReach and the 1.1 TenoSlamRange) x TenoHeavyReachMul (III: 1.2); star: every slammed dino is slowed
--     (1 - TenoHeavySlow) for TenoHeavySlowTime s after its stun ends.
--   * Front Claws: scratch damage + TenoClawBonus (I: 3); cone TenoClawCone degrees (II: 130; 0 = the 90 default); the gap
--     between scratches TenoClawGap s (III: 0.35; 0 = TenoScratchGap); star: a scratch hit slows (1 - TenoClawSlow) for
--     TenoClawSlowTime s.
--   * Slows: a player target gets TenoSlowUntil / TenoSlowMul (SprintTest 1.18 multiplies its speed; the stronger / longer
--     of two slows is kept); a bot's WalkSpeed is scaled while slowed (HerreraMovesServer's pattern; BotServer untouched;
--     bot attribute TenoSlowed).
--   * BindableEvent script.TenoAddCharge:Fire(char): +1 slam charge, never above the max (Survivor star, TenoStatsServer 1.1).
--   Diagnostics: script TenoAttackSlows, TenoAttackAddCharges (counts).
-- v1.4 (Kepu 2026-11-02, slam camera "Swing behind" with the look nudging the aim): DinoTenoAttack "slam" takes a 4th
--   argument pref (degrees, + = left; TenoAttackTest 1.4 sends ShoulderCam 1.7's flipped view yaw). When it is a number
--   within +-90 the soft aim is centred on it: only candidates within +-TenoSlamAimMax keep, each candidate's yaw is
--   shifted by -pref for TenoSlamAim.pick (so the score favours dinos near pref), the chosen yaw = its yaw + pref clamped
--   to +-TenoSlamAimMax; no target -> the slam swings to pref. Switch: script attribute TenoAttackCamAimEnabled (default
--   true, read at each slam; false = 1.3). Diagnostic: character TenoSlamAimPref (the pref used, or nil).
-- v1.5 (MDA-153, Kepu 2026-11-03 "Yes respect back plates"): a scratch or tail-slam hit on a Herrera with Back Plating slotted, from behind
--   (the attacker's root in the target's back half-space) is x the target's PlatingRearMul (0.9 / 0.85 / 0.78 / 0.7) through
--   BoneCrest 1.5 plating() (stamps PlatingHits / PlatingLastMul / PlatingHitAt for HerreraPartsFX). Front hits unchanged.
--   Switch: script attribute TenoAttackPlatingEnabled (default true, read at each hit; false = 1.4).
-- v1.6 (MDA-326, plan docs/plans/FIXES_2026-11-06_v1.0.md Fix 4; Kepu 2026-11-06 "A" rake marks + both legs): scratches
--   alternate arms: the n-th accepted scratch (TenoScratchCount) uses ArmR when n is odd, ArmL when even. Before TenoScratchAt
--   the character gets TenoScratchArm ("R" / "L") and TenoScratchAlternate (true; TenoPose 1.13 mirrors the pose, TenoFX 1.x
--   draws the rake marks); the hit's claw point is that arm's joint. Reach, cone, damage, shove unchanged. Switch: script
--   attribute TenoScratchAlternateEnabled (default true, read at each scratch; false = 1.5: ArmR, TenoScratchArm "R",
--   TenoScratchAlternate false).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.4"
VERSION = "1.5" -- v1.5 Back Plating
VERSION = "1.6" -- v1.6 alternating scratch arms
VERSION = "1.7" -- v1.7 Sap Wall stops scratches / tail slams through it
-- v1.7 (MDA-353) Sap Wall: a live Sap Wall on the attacker (or splash centre) -> target line stops the hit (ServerStorage.DinoArcade
--   SapWallBlock.between). Switch: script attribute TenoAttackServerSapWallEnabled (default true, read at each hit). Diagnostics: script
--   TenoAttackServerSapWallBlocks (count), TenoAttackServerSapWallBlockedAt (server time).
VERSION = "1.8" -- v1.8 armor on every hit (MDA-366)
-- v1.8 (MDA-366, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 "Every attack"): armor (Thick Hide / Armored Hide /
--   Wiry Frame = the victim's StatDamageTakenMul) now cuts scratches and tail slams (damage):
--   damage x BoneCrest.armor(victim) (ServerStorage.DinoArcade.BoneCrest 1.7, one shared call). Switch: script attribute
--   TenoAttackServerArmorAllEnabled (default true, read at each hit; false = 1.7). Diagnostic: script TenoAttackServerArmorCuts (count of hits cut).
local sapBlocked do
	local mod
	sapBlocked = function(from, to)
		if script:GetAttribute("TenoAttackServerSapWallEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.between and mod.between(from, to)) then return false end
		script:SetAttribute("TenoAttackServerSapWallBlocks", (script:GetAttribute("TenoAttackServerSapWallBlocks") or 0) + 1)
		script:SetAttribute("TenoAttackServerSapWallBlockedAt", workspace:GetServerTimeNow())
		return true
	end
	if script:GetAttribute("TenoAttackServerSapWallEnabled") == nil then script:SetAttribute("TenoAttackServerSapWallEnabled", true) end
end
if script:GetAttribute("TenoScratchAlternateEnabled") == nil then script:SetAttribute("TenoScratchAlternateEnabled", true) end -- v1.6
local SCRATCH_HIT_AT = 0.17     -- s after the press: mockup T1 + T2 / 2
local SCRATCH_CONE = math.rad(45)
local SHOVE_TIME = 0.3
local TOSS_TIME, TOSS_HEIGHT = 0.6, 8 -- StunClient / MineServer toss
local HOLD_BACK = 1             -- s a hold stamp may be in the past
local DEFAULTS = {TenoScratchDamage = 8, TenoScratchGap = 0.5, TenoScratchReach = 5.5, TenoScratchShove = 6,
	TenoSlamDamage = 40, TenoSlamCharges = 3, TenoSlamRefill = 8, TenoSlamHoldMin = 0.22, TenoSlamRange = 15,
	TenoSlamArc = 220, TenoSlamToss = 35, TenoSlamStun = 1, TenoSlamDropTime = 0.13,
	TenoSlamReach = 18.5, TenoSlamAimMax = 35, TenoSlamCone = 70, TenoSlamExtraCharges = 0} -- v1.2

script:SetAttribute("TenoAttackServerVersion", VERSION)
for _, k in ipairs({"TenoAttackRequests", "TenoAttackScratches", "TenoAttackSlams", "TenoAttackHits", "TenoAttackBucked",
	"TenoAttackSquadSkips"}) do
	script:SetAttribute(k, 0)
end
for _, k in ipairs({"TenoAttackServerEnabled", "TenoAttackModeRulesEnabled", "TenoAttackSquadEnabled", "TenoAttackStatsEnabled", "TenoAttackRearAimEnabled"}) do -- v1.1: + Stats; v1.2: + RearAim
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local enabled = script:GetAttribute("TenoAttackServerEnabled") ~= false

local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function get(char, k) return num(char, k, DEFAULTS[k]) end
-- v1.3: teno stats part 2 helpers
if script:GetAttribute("TenoAttackStats2Enabled") == nil then script:SetAttribute("TenoAttackStats2Enabled", true) end
local function s2On() return script:GetAttribute("TenoAttackStats2Enabled") ~= false end
local function s2(char, k, off) if not s2On() then return off end return num(char, k, off) end
local function refillOf(char) return math.max(0.5, get(char, "TenoSlamRefill") * math.clamp(s2(char, "TenoHeavyRefillMul", 1), 0.1, 2)) end
local function reachMulOf(char) return math.clamp(s2(char, "TenoHeavyReachMul", 1), 0.5, 3) end
local function scratchGapOf(char) local g = s2(char, "TenoClawGap", 0) return g > 0 and g or get(char, "TenoScratchGap") end
local function scratchConeOf(char) local c = s2(char, "TenoClawCone", 0) return c > 0 and math.rad(math.clamp(c, 10, 359) / 2) or SCRATCH_CONE end
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
local armorMul do -- v1.8 (MDA-366): armor on every attack, ServerStorage.DinoArcade.BoneCrest 1.7 armor()
	local mod
	armorMul = function(victim)
		if script:GetAttribute("TenoAttackServerArmorAllEnabled") == false then return 1 end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end) end
		local a = mod and mod.armor and mod.armor(victim) or 1
		if a ~= 1 then script:SetAttribute("TenoAttackServerArmorCuts", (script:GetAttribute("TenoAttackServerArmorCuts") or 0) + 1) end
		return a
	end
	if script:GetAttribute("TenoAttackServerArmorAllEnabled") == nil then script:SetAttribute("TenoAttackServerArmorAllEnabled", true) end
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
	local d = math.max(0, base) * takenMul(m, t) * armorMul(m) -- v1.8 (MDA-366): armor
	if d > 0 then takeHealth(m, d, char, player, with, t) end
	return d
end
-- v1.5: Back Plating (MDA-153; see the header)
if script:GetAttribute("TenoAttackPlatingEnabled") == nil then script:SetAttribute("TenoAttackPlatingEnabled", true) end
do
	local crestCache
	local takeHealthV14 = takeHealth
	takeHealth = function(m, d, char, ...)
		if script:GetAttribute("TenoAttackPlatingEnabled") ~= false and typeof(d) == "number" and d > 0 and typeof(char) == "Instance" then
			if crestCache == nil then
				crestCache = false
				pcall(function() crestCache = require(ServerStorage:WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end)
			end
			local root = char:FindFirstChild("HumanoidRootPart")
			if crestCache and crestCache.plating and root then d = d * crestCache.plating(m, root.Position) end
		end
		return takeHealthV14(m, d, char, ...)
	end
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
local function maxCharges(char)
	local extra = script:GetAttribute("TenoAttackRearAimEnabled") ~= false and math.max(0, math.floor(get(char, "TenoSlamExtraCharges"))) or 0 -- v1.2: Buck Off star
	return math.max(1, math.floor(get(char, "TenoSlamCharges")) + extra)
end
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
	local function onMax() -- v1.2: the max can change (Buck Off star)
		local mx = maxCharges(char)
		st.charges = math.min(st.charges, mx)
		if st.charges < mx and not st.refillAt then
			local t = now()
			st.refillStart, st.refillAt = t, t + refillOf(char)
		end
		publish(char, st)
	end
	char:GetAttributeChangedSignal("TenoSlamExtraCharges"):Connect(onMax)
	char:GetAttributeChangedSignal("TenoSlamCharges"):Connect(onMax)
	return st
end
-- v1.3: +1 slam charge (Survivor star)
local addCharge = script:FindFirstChild("TenoAddCharge") or Instance.new("BindableEvent")
addCharge.Name = "TenoAddCharge"
addCharge.Parent = script
addCharge.Event:Connect(function(char)
	if typeof(char) ~= "Instance" then return end
	local st = chars[char]
	if not st then return end
	local mx = maxCharges(char)
	if st.charges >= mx then return end
	st.charges += 1
	count("TenoAttackAddCharges")
	if st.charges >= mx then st.refillStart, st.refillAt = nil, nil end
	publish(char, st)
end)
RunService.Heartbeat:Connect(function()
	local t
	for char, st in pairs(chars) do
		if st.refillAt then
			t = t or now()
			if t >= st.refillAt then
				st.charges = math.min(maxCharges(char), st.charges + 1)
				if st.charges < maxCharges(char) then
					st.refillStart, st.refillAt = st.refillAt, st.refillAt + refillOf(char)
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

-- v1.3: slows (players: TenoSlowUntil / TenoSlowMul for SprintTest 1.18; bots: WalkSpeed scaled here)
local botSlow = {} -- [model] = {hum, untilT, mul, base, set}
local function slow(m, mul, untilT)
	if not (mul and mul < 1 and untilT) then return end
	count("TenoAttackSlows")
	if Players:GetPlayerFromCharacter(m) then
		local t0 = now()
		local cu, cm = num(m, "TenoSlowUntil", 0), num(m, "TenoSlowMul", 1)
		if cu <= t0 then cm = 1 end
		m:SetAttribute("TenoSlowMul", math.min(cm, mul))
		m:SetAttribute("TenoSlowUntil", math.max(cu, untilT))
		return
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local e = botSlow[m]
	if e then
		e.untilT, e.mul = math.max(e.untilT, untilT), math.min(e.mul, mul)
	else
		botSlow[m] = {hum = hum, untilT = untilT, mul = mul}
	end
end
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
				if m:GetAttribute("TenoSlowed") ~= true then m:SetAttribute("TenoSlowed", true) end
			else
				hum.WalkSpeed = e.base
				m:SetAttribute("TenoSlowed", false)
				botSlow[m] = nil
			end
		end
	end
end)

local function doScratch(player, char, st, t, stamp)
	st.lastScratch = t
	char:SetAttribute("TenoScratchCount", (char:GetAttribute("TenoScratchCount") or 0) + 1)
	count("TenoAttackScratches")
	char:SetAttribute("TenoHoldSince", 0)
	local alt = script:GetAttribute("TenoScratchAlternateEnabled") ~= false -- v1.6
	local arm = (alt and (char:GetAttribute("TenoScratchCount") or 1) % 2 == 0) and "L" or "R"
	char:SetAttribute("TenoScratchArm", arm)
	char:SetAttribute("TenoScratchAlternate", alt)
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
		local claw = jointPos(char, arm == "L" and "ArmL" or "ArmR", root.Position + fwd * 4.7 * s) -- v1.6: the scratching arm
		local reach = math.max(0, get(char, "TenoScratchReach")) * s
		local shoveDist = math.max(0, get(char, "TenoScratchShove")) * s
		local n, names = 0, {}
		for _, m in ipairs(candidates(char)) do
			local v = flat(rootOf(m).Position - root.Position)
			if v.Magnitude > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= scratchConeOf(char) and gap(m, claw) <= reach and not sapBlocked(root, m) then -- v1.3: Front Claws II cone; v1.7: Sap Wall
				damage(char, player, m, get(char, "TenoScratchDamage") + math.max(0, s2(char, "TenoClawBonus", 0)), "scratch", ti) -- v1.3: + Front Claws I
				if not shielded(m, ti) then shove(char, m, shoveDist, ti) end
				local cs = s2(char, "TenoClawSlow", 0) -- v1.3: Front Claws star
				if cs > 0 and not shielded(m, ti) then slow(m, 1 - math.clamp(cs, 0, 0.95), ti + math.max(0, s2(char, "TenoClawSlowTime", 0))) end
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

-- v1.2: the soft aim (TenoSlamAim 1.0)
local aimMod
do
	local ok, m = pcall(function() return require(ServerStorage:WaitForChild("DinoArcade", 10):WaitForChild("TenoSlamAim", 10)) end)
	if ok and type(m) == "table" then aimMod = m end
	local src = ServerStorage:FindFirstChild("DinoArcade") and ServerStorage.DinoArcade:FindFirstChild("TenoSlamAim")
	if src and not ReplicatedStorage:FindFirstChild("TenoSlamAimShared") then
		local c = src:Clone()
		c.Name = "TenoSlamAimShared"
		c.Parent = ReplicatedStorage
	end
end
local function aimOn() return aimMod ~= nil and script:GetAttribute("TenoAttackRearAimEnabled") ~= false end
local function aimSettings(char)
	return {reach = math.max(0, get(char, "TenoSlamReach")) * char:GetScale() * reachMulOf(char), aimMax = math.clamp(get(char, "TenoSlamAimMax"), 0, 90),
		cone = math.clamp(get(char, "TenoSlamCone"), 0, 180)}
end
-- v1.4: the soft aim centred on a preferred yaw (the same rule as TenoAttackTest 1.4)
if script:GetAttribute("TenoAttackCamAimEnabled") == nil then script:SetAttribute("TenoAttackCamAimEnabled", true) end
local function pickPref(mod, cands, s, pref)
	if type(pref) ~= "number" then return mod.pick(cands, s) end
	pref = math.clamp(pref, -s.aimMax, s.aimMax)
	local c, sn = math.cos(math.rad(pref)), math.sin(math.rad(pref))
	local shifted, back = {}, {}
	for _, k in ipairs(cands) do
		if type(k.x) == "number" and type(k.z) == "number" and math.abs(math.deg(math.atan2(k.x, k.z))) <= s.aimMax then
			local n = table.clone(k)
			n.x, n.z = k.x * c - k.z * sn, k.z * c + k.x * sn
			table.insert(shifted, n)
			back[n] = k
		end
	end
	local r = mod.pick(shifted, s)
	local yaw = r.target and math.clamp(r.yaw + pref, -s.aimMax, s.aimMax) or pref
	return {yaw = yaw, target = r.target and back[r.target] or nil, members = mod.members(cands, yaw, s)}
end
local function latchedOn(m, char)
	if m:GetAttribute("PounceLatched") ~= true or m:GetAttribute("PounceMode") == "pin" then return nil end
	local v = m:FindFirstChild("PounceLatchPart")
	if v and v:IsA("ObjectValue") and v.Value ~= nil and v.Value:IsDescendantOf(char) then return v.Value end
	return nil
end
local function aimCands(char, root) -- HRP space: x = +left, z = +back
	local list = {}
	for _, m in ipairs(candidates(char)) do
		if not latchedOn(m, char) then
			local r = rootOf(m)
			local lp = root.CFrame:PointToObjectSpace(r.Position)
			table.insert(list, {id = m, x = -lp.X, z = lp.Z, gap = gap(m, root.Position)})
		end
	end
	return list
end

local function doSlam(player, char, st, t, hold)
	local free = freeSlam(char, t) -- v1.1: Buck Off II
	char:SetAttribute("TenoSlamFree", free)
	if not free then st.charges -= 1 end
	if not free and not st.refillAt then st.refillStart, st.refillAt = t, t + refillOf(char) end
	publish(char, st)
	local drop = math.max(0, get(char, "TenoSlamDropTime"))
	st.slamUntil = t + drop
	char:SetAttribute("TenoSlamCount", (char:GetAttribute("TenoSlamCount") or 0) + 1)
	count("TenoAttackSlams")
	char:SetAttribute("TenoSlamHold", math.clamp(tonumber(hold) or 1, 0, 2))
	char:SetAttribute("TenoHoldSince", 0)
	local aimYaw, aiming = 0, aimOn() -- v1.2
	script:SetAttribute("TenoAttackAimMode", aiming and "aim" or "arc")
	if aiming then
		local root0 = rootOf(char)
		local pref = st.aimPref -- v1.4
		st.aimPref = nil
		char:SetAttribute("TenoSlamAimPref", pref)
		local r = root0 and pickPref(aimMod, aimCands(char, root0), aimSettings(char), pref) or {yaw = 0}
		aimYaw = r.yaw
		char:SetAttribute("TenoSlamAimTarget", r.target and r.target.id.Name or "")
	end
	char:SetAttribute("TenoSlamAimYaw", aimYaw)
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
		local range = math.max(0, get(char, "TenoSlamRange")) * s * reachMulOf(char) -- v1.3: Heavy Tail III
		local half = math.rad(math.clamp(get(char, "TenoSlamArc"), 0, 360) / 2)
		local toss = math.max(0, get(char, "TenoSlamToss"))
		local stun = math.max(0, get(char, "TenoSlamStun"))
		local dmg = get(char, "TenoSlamDamage") + math.max(0, s2(char, "TenoHeavyBonus", 0)) -- v1.3: Heavy Tail I
		local heavySlow, heavySlowTime = s2(char, "TenoHeavySlow", 0), math.max(0, s2(char, "TenoHeavySlowTime", 0)) -- v1.3: Heavy Tail star
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
			if sapBlocked(char, m) then return end -- v1.7: Sap Wall
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
			if heavySlow > 0 and not shielded(m, ti) then slow(m, 1 - math.clamp(heavySlow, 0, 0.95), ti + TOSS_TIME + stun + heavySlowTime) end -- v1.3
			if latched then
				bucked += 1
				table.insert(buckedNames, m.Name)
			else
				table.insert(names, m.Name)
			end
		end
		local frontLatched = 0 -- v1.2
		-- latched raptors first (they may be inside the teno's own body, any side)
		local all = {}
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(all, pl.Character) end end
		for _, b in ipairs(bots()) do table.insert(all, b) end
		for _, m in ipairs(all) do
			if m ~= char and latchedOnMe(m) and mayAffect(char, m) then
				local part = aiming and latchedOn(m, char)
				if not aiming or (part and aimMod.backHalf(root.CFrame:PointToObjectSpace(part.Position).Z)) then
					apply(m, true)
				else
					frontLatched += 1 -- v1.2: the front half is not kicked off
				end
			end
		end
		char:SetAttribute("TenoSlamFrontLatched", frontLatched)
		if aiming then -- v1.2: the aimed tail zone, behind the hips only
			for _, c in ipairs(aimMod.members(aimCands(char, root), aimYaw, aimSettings(char))) do
				if not hit[c.id] then apply(c.id, false) end
			end
		else
		-- the rear zone
		for _, m in ipairs(candidates(char)) do
			if not hit[m] then
				local v = flat(rootOf(m).Position - hips)
				local inArc = v.Magnitude < 1e-3 or math.acos(math.clamp(back:Dot(v.Unit), -1, 1)) <= half
				if inArc and gap(m, hips) <= range then apply(m, false) end
			end
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

remote.OnServerEvent:Connect(function(player, kind, stamp, hold, pref)
	count("TenoAttackRequests")
	local char = player.Character
	if not char then return end
	local st = track(char)
	if st and kind == "slam" then -- v1.4: the camera nudge
		st.aimPref = (script:GetAttribute("TenoAttackCamAimEnabled") ~= false and typeof(pref) == "number" and pref == pref
			and math.abs(pref) <= 90) and pref or nil
	end
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
	if not r and kind == "scratch" and t - st.lastScratch < math.max(0, scratchGapOf(char)) then -- v1.3: Front Claws III
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
