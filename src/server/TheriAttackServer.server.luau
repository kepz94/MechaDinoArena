-- TheriAttackServer v1.6 (Mecha Dino Arena) — the Therizinosaurus' 3-hit claw combo (server authority). MDA-201, plan
-- docs/plans/THERIZINO_KIT_v1.0.md Task 4 (deterministic map), mockup docs/mockups/therizino_kit_options_v0.3.html
-- (Kepu 2026-11-02: attack "3-hit combo", payoff "Damage only", picks "A Reaper Sweeps"; animation "I like this one").
-- Pattern: TenoAttackServer 1.4's scratch path (request -> server checks -> hit resolved at a fixed delay in a front zone),
-- its target / mode / squad / shield / damage rules copied (not shared: TenoAttackServer is untouched).
-- Who: player characters with the model attribute TheriAttackEnabled == true (TherizinoModelData 1.3).
-- Remote ReplicatedStorage.DinoTheriAttack (RemoteEvent), client -> server: (stamp) = one ATTACK tap (TheriAttackTest 1.0).
--   Checks in order -> TheriAttackServerResult (+ TheriAttackServerResultAt): "badArg" (stamp not a number), "dead",
--   "disabled" (TheriAttackEnabled not true or the script switch off), "menu" (player InMenu), "stunned" (StunnedUntil),
--   "dazed" (DazedUntil), "pinned" (PinHeld), "recover" (within TheriFinisherRecover s of the finisher tap), "cooldown"
--   (within TheriMinGap s of the last tap) -> "ok".
-- Combo (server-owned, per character): step 0 = ready. An accepted tap is the next step when the last tap was step 1 or 2
--   and at most TheriChainWindow s ago; otherwise it is step 1 (also after the finisher's recovery). Step 1 = right cut,
--   2 = left cut, 3 = rear-up double chop (finisher).
-- Hit: at the tap's stamp (clamped to [now - delay, now]) + TheriHitDelayN (N = the step): every allowed target whose nearest
--   hitbox is within TheriReach x scale (step 3: TheriReach3) of the root and whose root is inside TheriCone degrees centred
--   on the facing takes TheriHitDamageN x takenMul (none while EnergyShieldUntil > now). Damage only (no shove, no stun).
--   A pending hit is cancelled (TheriComboCancelAt) when the therizino is dead / stunned / dazed / pinned at the hit time;
--   the combo then restarts at step 1.
-- Targets (TenoAttackServer 1.4 rules): players' characters and Workspace.DinoIsland.Bots models with Hitboxes, Bitable,
--   Species or IsBot, not self, not KO, alive; players only where ModeRules.canAffect allows; never a squadmate.
-- Numbers (model attributes; defaults below): TheriHitDamage1 / 2 / 3 9 / 9 / 20, TheriHitDelay1 / 2 / 3 0.30 / 0.33 / 0.55,
--   TheriReach 7, TheriReach3 8 (x the character's scale), TheriCone 100, TheriMinGap 0.33, TheriChainWindow 0.8,
--   TheriFinisherRecover 0.9.
-- Stamps (character): TheriComboStep (1-3), TheriComboAt (server time of the accepted tap, set last: poses / FX react to it);
--   at the hit: TheriHitStep, TheriHitTargets ("|" joined names), TheriHitPoint (in front of the root, for FX), TheriHitCount,
--   TheriHitAt (last). Kills: KilledWith "thericlaw".
-- Switches (script attributes): TheriAttackServerEnabled (default true, read at start), TheriAttackModeRulesEnabled (default
--   true; false = players can always be hit), TheriAttackSquadEnabled (default true).
-- Diagnostics: script TheriAttackServerVersion, TheriAttackRequests, TheriAttackTaps, TheriAttackHits, TheriAttackCancels,
--   TheriAttackSquadSkips, TheriAttackMode.
-- v1.1 (MDA-212, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 6; SkillTree 1.57 / SkillEffects 1.39 THERI_ATTRS): the
--   therizino's stat rows act on the combo. Every field is a character attribute; 0 / 1 / false (not bought) = 1.0.
--   Switch: script attribute TheriAttackStatsEnabled (default true, read at each use; false = 1.0). Species "Therizino" only.
--   Chain live (Flow Guard): steps 1-2 from the tap to tap + chain window; step 3 from the tap to tap + TheriHitDelay3 +
--   finisher recovery (the windows below, after Flowing Cuts).
--   * Flowing Cuts: TheriFlowWindow > 0 replaces TheriChainWindow, TheriFlowGap > 0 replaces TheriMinGap, TheriFlowRecover > 0
--     replaces TheriFinisherRecover. Star (TheriFlowRefill): a finisher that takes health from >= 1 target fires the
--     BindableEvent ServerStorage.JumpAddCharge (JumpServer 1.4: +1 JUMP charge, never above the max).
--   * Building Fury: TheriFuryHit2 > 0 replaces TheriHitDamage2, TheriFuryFinisher > 0 replaces TheriHitDamage3. III: each
--     earlier cut of this chain that took health from the same target adds TheriFuryStack to this hit. Star: a finisher on a
--     target that cuts 1 and 2 of this chain both hit deals x TheriFuryFullMul. Hit = (base + stack) x full x takenMul.
--   * Flow Guard: I each Humanoid health drop while the chain is live is refunded drop x (1 - TheriGuardTakenMul) (a killing
--     blow is not refunded; TenoStatsServer 1.1's Brace I rule). II (TheriGuardFinisherNoStun): a stun set between the
--     finisher tap and its hit is cleared (StunnedUntil = now). III: a HeadbuttShoveDist / StunTossDistance written on the
--     therizino while the chain is live is scaled by TheriGuardShoveMul. Star (TheriGuardKeepChain): a pending hit cancelled
--     by a stun / daze keeps the chain step (1.0 resets it to 0; the cancelled hit still deals nothing).
--   * Reaper's Harvest: each finisher hit that takes health heals TheriHarvestHeal x MaxHealth; a combo kill (KilledWith
--     "thericlaw") heals TheriHarvestKillHeal x MaxHealth over 3 s; star (TheriHarvestLowDouble): x2 while below 30% health.
--   Diagnostics: script TheriAttackStatsRefills, TheriAttackStatsRefunds, TheriAttackStatsHeals; character TheriFuryLastBonus
--   ("+stack xfull" of the last hit), TheriChainLive, TheriGuardRefunded (total), TheriGuardStunCleared (count),
--   TheriGuardShoved (last scaled distance), TheriHarvestHealed (total), TheriKeepChainCount, TheriRefillResult.
-- v1.2 (MDA-213, plan Task 7; mockup docs/mockups/therizino_fourth_cut_v0.1.html, Kepu 2026-11-03 picked "C" Ground Scythe):
--   the Fourth Cut (step 4). Only for a therizino with TheriFourthDamage > 0 (SkillTree 1.58 THERI_FOURTH + the row bought;
--   SkillEffects 1.39 writes TheriFourthDamage / TheriFourthReachMul / TheriFourthFast). A tap (checked before the 1.0 rules)
--   while the last accepted tap was the finisher (step 3) and its time is from the finisher's hit (finisher tap +
--   TheriHitDelay3) - 0.05 s to + FOURTH_WINDOW (0.8) s: the blocks as 1.0 ("dead" / "menu" / "stunned" / "dazed" /
--   "pinned"), else accepted -> step 4: TheriComboStep 4, TheriComboAt (last), "ok". Hit at the stamp + TheriFourthDelay (0.3
--   s; / 1.5 with TheriFourthFast): every allowed target (1.0's rules) whose nearest hitbox is within TheriReach3 x scale x
--   TheriFourthReachMul of the root, all around (no cone), takes TheriFourthDamage x takenMul (none while shielded), once;
--   through 1.1's takeHealth (Building Fury stack, Reaper's Harvest kill heal apply; the finisher heal does not); cancelled
--   like 1.0 when blocked at the hit (TheriComboCancelAt). Stamps TheriHitStep 4, TheriHitTargets, TheriHitPoint (the root),
--   TheriHitCount, TheriHitAt (last). After it: without TheriFourthFast a tap within TheriFourthRecover (0.8) s of the 4th tap
--   is refused "recover"; after that (or at once, past TheriMinGap, with TheriFourthFast = the star) the next tap is cut 1.
--   Switch: script attribute TheriAttackFourthEnabled (default true, read at each tap; false = 1.1: no step 4). Diagnostic:
--   script TheriAttackFourths (count).
-- v1.3 (MDA-153, Kepu 2026-11-03 "Yes respect back plates"): a claw cut (steps 1-3) or the Fourth Cut sweep on a Herrera with Back Plating slotted, from behind
--   (the attacker's root in the target's back half-space) is x the target's PlatingRearMul (0.9 / 0.85 / 0.78 / 0.7) through
--   BoneCrest 1.5 plating() (stamps PlatingHits / PlatingLastMul / PlatingHitAt for HerreraPartsFX). Front hits unchanged.
--   Switch: script attribute TheriAttackPlatingEnabled (default true, read at each hit; false = 1.2).
-- v1.4 (MDA-244, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 4; Reaper's Hook star "cut 1 starts on it"): BindableFunction
--   "TheriStartCut" under this script (server only; TheriMovesServer 1.0 invokes it after a hook pull): Invoke(player) runs a
--   cut 1 for that player's therizino exactly as a tap would start one (TheriComboStep 1, TheriComboAt = now, resolve after
--   TheriHitDelay1), when TheriAttackEnabled is true and the shared checks pass (blocked()); it skips the tap gap / recover
--   checks. Returns "ok" or the reason. Switch: script attribute TheriAttackHookCutEnabled (default true, read at each call;
--   false = returns "off", nothing happens). Diagnostic: script TheriAttackHookCuts (count).
-- v1.5 (MDA-247, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7; Overclock Joints II+ "cut taps come 30% faster too"): while
--   the character's TheriClockUntil (TheriMovesServer 1.2) is in the future, TheriMinGap (after Flowing Cuts) is x
--   TheriClockTapMul (0.7). Switch: script attribute TheriAttackClockEnabled (default true, read at each tap; false = 1.4).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 therizino stat rows
VERSION = "1.2" -- v1.2 the Fourth Cut (step 4)
VERSION = "1.3" -- v1.3 Back Plating
VERSION = "1.4" -- v1.4 TheriStartCut (Reaper's Hook star)
VERSION = "1.5" -- v1.5 Overclock tap gap
VERSION = "1.6" -- v1.6 Sap Wall stops claw hits through it
-- v1.6 (MDA-353) Sap Wall: a live Sap Wall on the attacker (or splash centre) -> target line stops the hit (ServerStorage.DinoArcade
--   SapWallBlock.between). Switch: script attribute TheriAttackServerSapWallEnabled (default true, read at each hit). Diagnostics: script
--   TheriAttackServerSapWallBlocks (count), TheriAttackServerSapWallBlockedAt (server time).
local sapBlocked do
	local mod
	sapBlocked = function(from, to)
		if script:GetAttribute("TheriAttackServerSapWallEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.between and mod.between(from, to)) then return false end
		script:SetAttribute("TheriAttackServerSapWallBlocks", (script:GetAttribute("TheriAttackServerSapWallBlocks") or 0) + 1)
		script:SetAttribute("TheriAttackServerSapWallBlockedAt", workspace:GetServerTimeNow())
		return true
	end
	if script:GetAttribute("TheriAttackServerSapWallEnabled") == nil then script:SetAttribute("TheriAttackServerSapWallEnabled", true) end
end
local DEFAULTS = {TheriHitDamage1 = 9, TheriHitDamage2 = 9, TheriHitDamage3 = 20, TheriHitDelay1 = 0.3, TheriHitDelay2 = 0.33,
	TheriHitDelay3 = 0.55, TheriReach = 7, TheriReach3 = 8, TheriCone = 100, TheriMinGap = 0.33, TheriChainWindow = 0.8,
	TheriFinisherRecover = 0.9}
local MAX_DELAY = 0.6
DEFAULTS.TheriFourthDelay, DEFAULTS.TheriFourthRecover = 0.3, 0.8 -- v1.2
local FOURTH_WINDOW = 0.8 -- v1.2
local fourthTap -- v1.2: set below, called first by the remote handler

script:SetAttribute("TheriAttackServerVersion", VERSION)
for _, k in ipairs({"TheriAttackRequests", "TheriAttackTaps", "TheriAttackHits", "TheriAttackCancels", "TheriAttackSquadSkips"}) do
	script:SetAttribute(k, 0)
end
for _, k in ipairs({"TheriAttackServerEnabled", "TheriAttackModeRulesEnabled", "TheriAttackSquadEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local enabled = script:GetAttribute("TheriAttackServerEnabled") ~= false

local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function get(char, k) return num(char, k, DEFAULTS[k]) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

-- mode + squad rules (TenoAttackServer 1.4) ------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TheriAttackMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TheriAttackSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("TheriAttackSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("TheriAttackModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end

-- targets (TenoAttackServer 1.4 rules) -------------------------------------------------------------------------------------
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
local function shielded(m, t) return num(m, "EnergyShieldUntil", 0) > t end
local function takenMul(m, t)
	local mul = 1
	local u, dm = m:GetAttribute("DebuffUntil"), m:GetAttribute("DebuffDamageTakenMul")
	if typeof(u) == "number" and typeof(dm) == "number" and t < u then mul = dm end
	if num(m, "DazedUntil", 0) > t then mul *= math.max(1, num(m, "DazedDamageMul", 1)) end
	if num(m, "StunBreakImmuneUntil", 0) > t then mul = 0 end
	return mul
end
local function takeHealth(m, d, char, player, t)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", "thericlaw")
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
	end
end

-- combo -------------------------------------------------------------------------------------------------------------------
local states = setmetatable({}, {__mode = "k"})
local function track(char)
	local st = states[char]
	if not st then
		st = {step = 0, lastTap = -math.huge, finisherAt = -math.huge}
		states[char] = st
	end
	return st
end
local function setResult(char, r, t)
	char:SetAttribute("TheriAttackServerResult", r)
	char:SetAttribute("TheriAttackServerResultAt", t)
end
local function blocked(player, char, t) -- the checks shared by the tap and the hit
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not rootOf(char) then return "dead" end
	if player:GetAttribute("InMenu") == true then return "menu" end
	if num(char, "StunnedUntil", 0) > t then return "stunned" end
	if num(char, "DazedUntil", 0) > t then return "dazed" end
	if char:GetAttribute("PinHeld") == true then return "pinned" end
	return nil
end

local function resolve(player, char, st, step)
	local ti = now()
	if not char.Parent then return end
	if blocked(player, char, ti) then
		st.step = 0
		count("TheriAttackCancels")
		char:SetAttribute("TheriComboCancelAt", ti)
		return
	end
	local root = rootOf(char)
	local s = char:GetScale()
	local fwd = flat(root.CFrame.LookVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zAxis
	local reach = math.max(0, get(char, step == 3 and "TheriReach3" or "TheriReach")) * s
	local half = math.rad(math.clamp(get(char, "TheriCone"), 0, 360) / 2)
	local dmg = math.max(0, get(char, "TheriHitDamage" .. step))
	local n, names = 0, {}
	for _, m in ipairs(candidates(char)) do
		local v = flat(rootOf(m).Position - root.Position)
		if v.Magnitude > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= half and gap(m, root.Position) <= reach and not sapBlocked(root, m) then -- v1.6: Sap Wall
			if not shielded(m, ti) then takeHealth(m, dmg * takenMul(m, ti), char, player, ti) end
			n += 1
			table.insert(names, m.Name)
		end
	end
	count("TheriAttackHits", n)
	char:SetAttribute("TheriHitStep", step)
	char:SetAttribute("TheriHitTargets", table.concat(names, "|"))
	char:SetAttribute("TheriHitPoint", root.Position + fwd * reach * 0.6)
	char:SetAttribute("TheriHitCount", (char:GetAttribute("TheriHitCount") or 0) + 1)
	char:SetAttribute("TheriHitAt", ti) -- last: TheriFX reacts to this one
end


local guards -- v1.1: Flow Guard state, set below
-- v1.1: the therizino's stat rows (see the header) --------------------------------------------------------------------------
for _, k in ipairs({"TheriAttackStatsRefills", "TheriAttackStatsRefunds", "TheriAttackStatsHeals"}) do script:SetAttribute(k, 0) end
if script:GetAttribute("TheriAttackStatsEnabled") == nil then script:SetAttribute("TheriAttackStatsEnabled", true) end
local function statsOn(char)
	return script:GetAttribute("TheriAttackStatsEnabled") ~= false and char:GetAttribute("Species") == "Therizino"
end
local ROW_OVER = {TheriChainWindow = "TheriFlowWindow", TheriMinGap = "TheriFlowGap", TheriFinisherRecover = "TheriFlowRecover",
	TheriHitDamage2 = "TheriFuryHit2", TheriHitDamage3 = "TheriFuryFinisher"}
do
	local getV10 = get
	get = function(char, k)
		local over = ROW_OVER[k]
		if over and statsOn(char) then
			local v = num(char, over, 0)
			if v > 0 then return v end
		end
		return getV10(char, k)
	end
end
local function chainLive(char, t)
	local st = states[char]
	if not st or not statsOn(char) then return false end
	if st.step == 1 or st.step == 2 then return t - st.lastTap <= math.max(0, get(char, "TheriChainWindow")) end
	if st.step == 3 then
		return t - st.finisherAt <= math.clamp(get(char, "TheriHitDelay3"), 0, MAX_DELAY) + math.max(0, get(char, "TheriFinisherRecover"))
	end
	return false
end
local function healBy(char, amount, why)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or amount <= 0 then return end
	if char:GetAttribute("TheriHarvestLowDouble") == true and hum.Health < 0.3 * hum.MaxHealth then amount *= 2 end
	local new = math.min(hum.MaxHealth, hum.Health + amount)
	local got = new - hum.Health
	if got <= 0 then return end
	local g = guards and guards[char]
	if g then g.own, g.last = new, new end
	hum.Health = new
	count("TheriAttackStatsHeals")
	char:SetAttribute("TheriHarvestHealed", math.floor(((char:GetAttribute("TheriHarvestHealed") or 0) + got) * 10 + 0.5) / 10)
	char:SetAttribute("TheriHarvestLast", why)
end
local cur -- the resolve in progress: {char, step, st, base, landed}
do
	local takeHealthV10 = takeHealth
	takeHealth = function(m, d, char, player, t)
		local c = cur
		if not (c and c.char == char and statsOn(char)) then return takeHealthV10(m, d, char, player, t) end
		local st = c.st
		st.chainHits = st.chainHits or {}
		local prior = st.chainHits[m] or 0
		local stack = math.max(0, num(char, "TheriFuryStack", 0)) * prior
		local full = 1
		if c.step == 3 and prior >= 2 then full = math.max(1, num(char, "TheriFuryFullMul", 1)) end
		if c.base > 0 and (stack > 0 or full ~= 1) then d = d * (c.base + stack) / c.base * full end
		char:SetAttribute("TheriFuryLastBonus", ("+%g x%g"):format(stack, full))
		local before = m:GetAttribute("DummyHealth")
		takeHealthV10(m, d, char, player, t)
		local after = m:GetAttribute("DummyHealth")
		if typeof(before) ~= "number" or typeof(after) ~= "number" or after >= before then return end
		st.chainHits[m] = prior + 1
		c.landed += 1
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		if c.step == 3 then healBy(char, math.max(0, num(char, "TheriHarvestHeal", 0)) * hum.MaxHealth, "finisher") end
		local kh = math.max(0, num(char, "TheriHarvestKillHeal", 0))
		if before > 0 and after <= 0 and kh > 0 then -- a combo kill: heal over 3 s
			local total = kh * hum.MaxHealth
			task.spawn(function()
				for _ = 1, 6 do
					task.wait(0.5)
					if not char.Parent or hum.Health <= 0 then return end
					healBy(char, total / 6, "kill")
				end
			end)
		end
	end
end
do
	local resolveV10 = resolve
	resolve = function(player, char, st, step)
		if not statsOn(char) then return resolveV10(player, char, st, step) end
		if step == 1 then st.chainHits = {} end
		local prevStep, cancelBefore = st.step, char:GetAttribute("TheriComboCancelAt")
		cur = {char = char, step = step, st = st, base = math.max(0, get(char, "TheriHitDamage" .. step)), landed = 0}
		local ok, err = pcall(resolveV10, player, char, st, step)
		local c = cur
		cur = nil
		if not ok then warn("TheriAttackServer resolve: " .. tostring(err)) return end
		if char:GetAttribute("TheriComboCancelAt") ~= cancelBefore then -- cancelled
			local why = blocked(player, char, now())
			if char:GetAttribute("TheriGuardKeepChain") == true and (why == "stunned" or why == "dazed") then
				st.step = prevStep
				char:SetAttribute("TheriKeepChainCount", (char:GetAttribute("TheriKeepChainCount") or 0) + 1)
			end
			return
		end
		if step == 3 and c.landed > 0 and char:GetAttribute("TheriFlowRefill") == true then
			local ev = ServerStorage:FindFirstChild("JumpAddCharge")
			if ev and ev:IsA("BindableEvent") then
				ev:Fire(char)
				count("TheriAttackStatsRefills")
				char:SetAttribute("TheriRefillResult", "fired")
			else
				char:SetAttribute("TheriRefillResult", "noHook")
			end
		end
	end
end
-- Flow Guard watchers (per therizino character)
guards = setmetatable({}, {__mode = "k"}) -- [char] = {last, own, HeadbuttShoveDist / StunTossDistance own writes}
local function guard(char)
	if guards[char] then return end
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local g = {last = hum.Health}
	guards[char] = g
	hum.HealthChanged:Connect(function(h)
		if g.own and math.abs(h - g.own) < 1e-3 then g.own = nil g.last = h return end
		local drop = g.last - h
		g.last = h
		if drop <= 0 or h <= 0 or not chainLive(char, now()) then return end
		local mul = math.clamp(num(char, "TheriGuardTakenMul", 1), 0, 1)
		if mul >= 1 then return end
		local new = math.min(hum.MaxHealth, h + drop * (1 - mul))
		g.own, g.last = new, new
		hum.Health = new
		count("TheriAttackStatsRefunds")
		char:SetAttribute("TheriGuardRefunded", math.floor(((char:GetAttribute("TheriGuardRefunded") or 0) + drop * (1 - mul)) * 10 + 0.5) / 10)
	end)
	char:GetAttributeChangedSignal("StunnedUntil"):Connect(function()
		local t, u = now(), num(char, "StunnedUntil", 0)
		if u <= t or char:GetAttribute("TheriGuardFinisherNoStun") ~= true or not statsOn(char) then return end
		local st = states[char]
		if not (st and st.step == 3 and t - st.finisherAt <= math.clamp(get(char, "TheriHitDelay3"), 0, MAX_DELAY) + 0.05) then return end
		char:SetAttribute("StunnedUntil", t)
		char:SetAttribute("TheriGuardStunCleared", (char:GetAttribute("TheriGuardStunCleared") or 0) + 1)
	end)
	for _, k in ipairs({"HeadbuttShoveDist", "StunTossDistance"}) do
		char:GetAttributeChangedSignal(k):Connect(function()
			local d = char:GetAttribute(k)
			if typeof(d) ~= "number" or d <= 0 or g[k] == d then return end
			local mul = math.clamp(num(char, "TheriGuardShoveMul", 1), 0, 1)
			if mul >= 1 or not chainLive(char, now()) then return end
			g[k] = d * mul
			char:SetAttribute(k, d * mul)
			char:SetAttribute("TheriGuardShoved", math.floor(d * mul * 10 + 0.5) / 10)
		end)
	end
	char:SetAttribute("TheriChainLive", false)
end
local function onChar(char)
	if char:GetAttribute("Species") == "Therizino" then task.spawn(guard, char) end
	char:GetAttributeChangedSignal("Species"):Connect(function()
		if char:GetAttribute("Species") == "Therizino" then task.spawn(guard, char) end
	end)
end
for _, pl in ipairs(Players:GetPlayers()) do
	if pl.Character then onChar(pl.Character) end
	pl.CharacterAdded:Connect(onChar)
end
Players.PlayerAdded:Connect(function(pl) pl.CharacterAdded:Connect(onChar) end)
game:GetService("RunService").Heartbeat:Connect(function()
	local t
	for char in pairs(guards) do
		if char.Parent then
			t = t or now()
			local live = chainLive(char, t)
			if char:GetAttribute("TheriChainLive") ~= live then char:SetAttribute("TheriChainLive", live) end
		end
	end
end)

-- v1.3: Back Plating (MDA-153; see the header)
if script:GetAttribute("TheriAttackPlatingEnabled") == nil then script:SetAttribute("TheriAttackPlatingEnabled", true) end
do
	local crestCache
	local takeHealthV12 = takeHealth
	takeHealth = function(m, d, char, ...)
		if script:GetAttribute("TheriAttackPlatingEnabled") ~= false and typeof(d) == "number" and d > 0 and typeof(char) == "Instance" then
			if crestCache == nil then
				crestCache = false
				pcall(function() crestCache = require(ServerStorage:WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end)
			end
			local root = char:FindFirstChild("HumanoidRootPart")
			if crestCache and crestCache.plating and root then d = d * crestCache.plating(m, root.Position) end
		end
		return takeHealthV12(m, d, char, ...)
	end
end

-- v1.2: the Fourth Cut (see the header) --------------------------------------------------------------------------------------
script:SetAttribute("TheriAttackFourths", 0)
if script:GetAttribute("TheriAttackFourthEnabled") == nil then script:SetAttribute("TheriAttackFourthEnabled", true) end
local function fourthOn(char)
	return script:GetAttribute("TheriAttackFourthEnabled") ~= false and statsOn(char) and num(char, "TheriFourthDamage", 0) > 0
end
local function sweep(player, char, st, at)
	local ti = now()
	if not char.Parent or st.step ~= 4 or st.fourthAt ~= at then return end
	if blocked(player, char, ti) then
		st.step = 0
		count("TheriAttackCancels")
		char:SetAttribute("TheriComboCancelAt", ti)
		return
	end
	local root = rootOf(char)
	local reach = math.max(0, get(char, "TheriReach3")) * char:GetScale() * math.max(0, num(char, "TheriFourthReachMul", 1))
	local dmg = math.max(0, num(char, "TheriFourthDamage", 0))
	cur = {char = char, step = 4, st = st, base = dmg, landed = 0}
	local n, names = 0, {}
	local ok, err = pcall(function()
		for _, m in ipairs(candidates(char)) do
			if gap(m, root.Position) <= reach and not sapBlocked(root, m) then -- v1.6: Sap Wall
				if not shielded(m, ti) then takeHealth(m, dmg * takenMul(m, ti), char, player, ti) end
				n += 1
				table.insert(names, m.Name)
			end
		end
	end)
	cur = nil
	if not ok then warn("TheriAttackServer sweep: " .. tostring(err)) end
	count("TheriAttackHits", n)
	char:SetAttribute("TheriHitStep", 4)
	char:SetAttribute("TheriHitTargets", table.concat(names, "|"))
	char:SetAttribute("TheriHitPoint", root.Position)
	char:SetAttribute("TheriHitCount", (char:GetAttribute("TheriHitCount") or 0) + 1)
	char:SetAttribute("TheriHitAt", ti) -- last
end
fourthTap = function(player, stamp)
	local char = player.Character
	if not char or typeof(stamp) ~= "number" or stamp ~= stamp then return false end
	if not enabled or char:GetAttribute("TheriAttackEnabled") ~= true or not fourthOn(char) then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	local st = track(char)
	local t = now()
	local fast = char:GetAttribute("TheriFourthFast") == true
	if st.step == 4 then
		if not fast and t - (st.fourthAt or -math.huge) < math.max(0, get(char, "TheriFourthRecover")) and not blocked(player, char, t) then
			setResult(char, "recover", t)
			return true
		end
		return false
	end
	if st.step ~= 3 then return false end
	local hitAt = st.finisherAt + math.clamp(get(char, "TheriHitDelay3"), 0, MAX_DELAY)
	if t < hitAt - 0.05 or t > hitAt + FOURTH_WINDOW then return false end
	local r = blocked(player, char, t)
	if r then
		setResult(char, r, t)
		return true
	end
	st.step, st.lastTap, st.fourthAt = 4, t, t
	count("TheriAttackTaps")
	count("TheriAttackFourths")
	setResult(char, "ok", t)
	char:SetAttribute("TheriComboStep", 4)
	char:SetAttribute("TheriComboAt", t) -- last: poses + FX
	local d = math.clamp(math.max(0, get(char, "TheriFourthDelay")) / (fast and 1.5 or 1), 0, MAX_DELAY)
	local delay = math.clamp(math.min(stamp, t) + d - t, 0, d)
	task.delay(delay, sweep, player, char, st, t)
	return true
end

local remote = ReplicatedStorage:FindFirstChild("DinoTheriAttack")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoTheriAttack"
	remote.Parent = ReplicatedStorage
end

remote.OnServerEvent:Connect(function(player, stamp)
	count("TheriAttackRequests")
	if fourthTap and fourthTap(player, stamp) then return end -- v1.2: the Fourth Cut first
	local char = player.Character
	if not char then return end
	local t = now()
	local st = track(char)
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		r = "badArg"
	elseif not char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
		r = "dead"
	elseif not enabled or char:GetAttribute("TheriAttackEnabled") ~= true then
		r = "disabled"
	else
		r = blocked(player, char, t)
	end
	local since = t - st.lastTap
	if not r and st.step == 3 and t - st.finisherAt < math.max(0, get(char, "TheriFinisherRecover")) then
		r = "recover"
	elseif not r and since < math.max(0, get(char, "TheriMinGap")) then
		r = "cooldown"
	end
	if r then
		setResult(char, r, t)
		return
	end
	local step = 1
	if (st.step == 1 or st.step == 2) and since <= math.max(0, get(char, "TheriChainWindow")) then step = st.step + 1 end
	st.step, st.lastTap = step, t
	if step == 3 then st.finisherAt = t end
	count("TheriAttackTaps")
	setResult(char, "ok", t)
	char:SetAttribute("TheriComboStep", step)
	char:SetAttribute("TheriComboAt", t) -- last: poses + FX
	local d = math.clamp(get(char, "TheriHitDelay" .. step), 0, MAX_DELAY)
	local delay = math.clamp(math.min(stamp, t) + d - t, 0, d)
	task.delay(delay, resolve, player, char, st, step)
end)

-- v1.4: TheriStartCut (see the header) ----------------------------------------------------------------------------------------
if script:GetAttribute("TheriAttackHookCutEnabled") == nil then script:SetAttribute("TheriAttackHookCutEnabled", true) end
script:SetAttribute("TheriAttackHookCuts", 0)
do
	local fn = Instance.new("BindableFunction")
	fn.Name = "TheriStartCut"
	fn.OnInvoke = function(player)
		if script:GetAttribute("TheriAttackHookCutEnabled") == false then return "off" end
		local char = typeof(player) == "Instance" and player:IsA("Player") and player.Character or nil
		if not char then return "noChar" end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return "dead" end
		if not enabled or char:GetAttribute("TheriAttackEnabled") ~= true then return "disabled" end
		local t = now()
		local r = blocked(player, char, t)
		if r then return r end
		local st = track(char)
		st.step, st.lastTap = 1, t
		count("TheriAttackTaps")
		count("TheriAttackHookCuts")
		setResult(char, "ok", t)
		char:SetAttribute("TheriComboStep", 1)
		char:SetAttribute("TheriComboAt", t) -- last: poses + FX
		task.delay(math.clamp(get(char, "TheriHitDelay1"), 0, MAX_DELAY), resolve, player, char, st, 1)
		return "ok"
	end
	fn.Parent = script
end

-- v1.5: Overclock Joints tap gap (see the header) -----------------------------------------------------------------------------
if script:GetAttribute("TheriAttackClockEnabled") == nil then script:SetAttribute("TheriAttackClockEnabled", true) end
do
	local getV14 = get
	get = function(char, k)
		local v = getV14(char, k)
		if k == "TheriMinGap" and script:GetAttribute("TheriAttackClockEnabled") ~= false and num(char, "TheriClockUntil", 0) > now() then
			local m = num(char, "TheriClockTapMul", 1)
			if m > 0 and m < 1 then v *= m end
		end
		return v
	end
end
