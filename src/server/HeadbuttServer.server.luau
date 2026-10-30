-- HeadbuttServer v1.9 (Mecha Dino Arena) — the pachy's headbutt charge (server side). MDA-119, plan
-- docs/plans/PACHY_PLAYABLE_v1.0.md Task 5, mockup docs/mockups/pachy_charge_options.html (option A pips).
-- Kepu 2026-10-30: "a headbutt charge that speeds it up a bit and knocks opponents back with a debuff to their speed. it
--   should come with two charges and max out at 3 charges fully statted up. the downside is if you use all your headbutt
--   charges it debuffs your speed for a couple of seconds"; damage "at least 20"; knockback "shoved maybe 40 studs and the
--   opponent is debuffed at the same time"; numbers "yes".
-- Who: every character with HeadbuttEnabled = true (PachyModelData 1.1). Settings are character attributes (defaults in
--   DEFAULTS): HeadbuttCharges (max charges, 2), HeadbuttExtraCharges (added by upgrades, 0), HeadbuttWindup, HeadbuttMaxTime,
--   HeadbuttDamage, HeadbuttShove, HeadbuttShoveTime, HeadbuttSlowMul, HeadbuttSlowTime, HeadbuttRefill,
--   HeadbuttRefillMul (upgrades, 1), HeadbuttSelfSlowMul, HeadbuttSelfSlowTime, HeadbuttReach.
-- Charges (server-owned): published as HeadbuttChargesNow / HeadbuttChargesMax; a spent charge refills after
--   HeadbuttRefill x HeadbuttRefillMul s, one at a time (HeadbuttRefillStart / HeadbuttRefillAt = server times of the
--   charge that is refilling, 0 when full). A new character starts full.
-- Remotes (ReplicatedStorage):
--   DinoHeadbuttRequest(stamp) -> checks in order: "badArg" (stamp not a number), "dead", "disabled" (HeadbuttEnabled not
--     true or the script switch off), "menu" (player InMenu), "stunned" (StunnedUntil), "pinned" (PinHeld), "busy" (a charge
--     running), "empty" (no charge) -> "ok": a charge is spent, the charge runs until HeadbuttWindup + HeadbuttMaxTime +
--     END_SLACK s; HeadbuttStartedAt (server time) is set last. Result in HeadbuttServerResult (+ HeadbuttServerResultAt).
--   DinoHeadbuttHit(stamp, model) -> the client's contact claim. Accepted when: the charge with that stamp runs and has not
--     hit yet; model is a workspace Model with a Hitboxes folder, Bitable true, a Species or IsBot, not the attacker, not
--     KO (DummyState "ko"); the attacker's head (Hitboxes part with HitboxSegment "Head", else the HRP) is within
--     HIT_TOLERANCE x the attacker's scale of the closest point of one of the target's hitbox parts. Result in
--     HeadbuttHitResult ("hit" / "noCharge" / "used" / "badTarget" / "self" / "ko" / "far").
--     A hit: damage = HeadbuttDamage x the target's roar debuff (DebuffDamageTakenMul while DebuffUntil), rounded, off the
--     target's DummyHealth (ArenaPvP turns that into Humanoid damage for players; the Energy Shield's ForceField blocks it
--     there); a killing blow stamps KilledBy, KilledByUserId, KilledWith "headbutt", KilledAt (last). Unless the target's
--     Energy Shield is up (EnergyShieldUntil), it is shoved and slowed at the same time: a player's character gets
--     HeadbuttShoveFrom (attacker position), HeadbuttShoveDist, HeadbuttShoveTime, HeadbuttShoveAt (last; HeadbuttShove
--     client 1.0 pushes the body on its feet) and HeadbuttSlowMul / HeadbuttSlowUntil (SprintTest 1.9); a bot is slid on the
--     ground by this script (anchored glide over HeadbuttShoveTime, then released) and its WalkSpeed is scaled while
--     HeadbuttSlowUntil. Target diagnostics: HeadbuttHitBy, HeadbuttShoveResult ("shoved" / "shielded" / "botBusy").
--     Attacker: HeadbuttHitDamage, HeadbuttHitTarget (model name), HeadbuttHitCount, HeadbuttHitAt (last). The charge ends.
--   DinoHeadbuttEnd(stamp, reason) -> the client ended the charge (time out / cancelled); the server also ends it at the
--     deadline. End: HeadbuttEndedAt, HeadbuttResult ("hit" / "ended" / "timeout" / "died"). If no charge is left, the
--     pachy is slowed: HeadbuttSelfSlowMul / HeadbuttSelfSlowUntil (SprintTest 1.9), HeadbuttSelfSlowCount.
-- v1.1 (pachy Drop 2, Battering Dome; SkillEffects 1.13): with script attribute HeadbuttDomeEnabled (default true, read
--   at start) the hit damage is HeadbuttDamage x HeadbuttDamageMul (default 1) x the roar debuff, and the shove distance
--   HeadbuttShove x HeadbuttShoveMul (default 1). HeadbuttRefillMul / HeadbuttExtraCharges were already read (1.0).
--   false = 1.0 numbers.
-- v1.2 (Grappling Hook, MDA-122): a request while the pachy's hook shot runs (HookBusyUntil, HookServer 1.0, in the
--   future) is "busy". Switch: script attribute HeadbuttHookBusyEnabled (default true, read at start).
--   Tiered refill (Kepu 2026-10-30: "Base refill for the first ram used. Slightly longer once you use two and once you
--   use 3 it's longer to refill. This way it punishes spammers"; picked 1x / 1.3x / 1.6x, self-slow kept): a refill's
--   length = HeadbuttRefill x HeadbuttRefillMul x (1 while 1 charge is missing; character attribute HeadbuttRefillTier2
--   (default 1.3) while 2 are missing; HeadbuttRefillTier3 (default 1.6) while 3 are missing). Spending another charge
--   while a refill runs stretches that refill to the new tier (its start stays, progress kept); the next refill after it
--   is priced by the charges missing then. Studio check of the first version: a refill always started at "1 missing",
--   so the tiers never applied; fixed before release.
--   Diagnostic HeadbuttRefillTierUsed (2 / 3, the last tier above 1). Switch: script attribute HeadbuttRefillTiersEnabled
--   (default true, read at start; false = one refill time).
-- v1.3 (Kepu 2026-10-30: "if i headbutt right in front of someone it should be less damage cause theres no charge up so
--   lets set a reasonable range and damage for that"): the hit damage scales with the run-up, the flat distance the
--   pachy's HumanoidRootPart moved from the request to the hit (st.active.startPos): up to HeadbuttCloseRun (default 6)
--   studs x scale = HeadbuttCloseMul (default 0.5) of the damage (20 -> 10), from HeadbuttFullRun (default 15) studs x
--   scale = full damage, in between it climbs in a straight line. Applied before the dome and roar multipliers. The
--   shove and slow are unchanged. Diagnostics (attacker): HeadbuttHitRun (studs, 0.1), HeadbuttHitRunMul (0.01). Switch:
--   script attribute HeadbuttRunUpEnabled (default true, read at start; false = full damage at any distance, = 1.2).
-- v1.4 (Studio check of 1.3): the server sees the pachy's body late (it is moved by its own client), so the measured
--   run-up came out short: a hit after a real ~18-stud charge measured 0.4 studs (head 17.9 studs from the target on the
--   server) and got half damage. Now the run-up also counts by charge time: charged = hit time - (start + HeadbuttWindup);
--   up to HeadbuttCloseTime (default 0.15 s) = HeadbuttCloseMul, from HeadbuttFullTime (default 0.45 s, about 28 studs at
--   the 63 studs/s charge) = full, straight line between. The damage uses the larger of the distance and time values, so
--   lag never lowers it. Diagnostics: HeadbuttHitChargeTime (s, 0.01), HeadbuttHitRunMul (the one used). Switch: script
--   attribute HeadbuttRunTimeEnabled (default true, read at start; false = distance only, = 1.3).
-- v1.5 (pachy Blood Rush, MDA-124, plan docs/plans/PACHY_BLOODRUSH_v1.0.md; Kepu 2026-10-30: "you can sacrifice 25% of
--   your life for another headbutt. This caps out at 50% so you could get two extra head butts after emptying your
--   charges"): with 0 charges, a request is a sacrifice instead of "empty" when the character attribute BloodRushEnabled
--   is true (SkillEffects 1.17: Blood Rush bought and slotted). Checks, after the 1.4 ones: "empty" (Blood Rush off),
--   "spent" (BloodRushMax, default 2, sacrifices since the charges ran out), "lowHealth" (Humanoid.Health at or below
--   half of MaxHealth). Accepted: Humanoid.Health is set to Health - BloodRushCost (default 0.25) x MaxHealth, at least 1
--   (set directly: TakeDamage would be blocked by an Energy Shield ForceField); no charge is spent; the charge runs
--   like any other with st.active.sacrifice = true. Stamps: HeadbuttSacrificeCost (health taken, 0.1), HeadbuttSacrifices
--   (used since the charges ran out), HeadbuttSacrificeCount (total), HeadbuttSacrificeAt (before HeadbuttStartedAt).
--   The count resets to 0 when a charge refills. A sacrifice that misses still cost the health.
--   On a sacrifice hit: damage x BloodRushDamageMul (default 1; II 1.25), HeadbuttHitSacrifice = true (false on a normal
--   hit); when BloodRushSlowMul (★ 0.45) is below the normal slow, the target's slow is BloodRushSlowMul for
--   BloodRushSlowTime (★ 4) s instead (players and bots, the same headbutt slow). At the end of a sacrifice charge the
--   self-slow is skipped while BloodRushNoSelfSlow is true (III). Switch: script attribute HeadbuttSacrificeEnabled
--   (default true, read at start; false = 1.4, "empty" at 0 charges).
-- v1.6 (Kepu 2026-10-30: "don't allow for blood rush to be used again until full health is restored. I was spamming it
--   ... my health kept restoring quick" -> "2, then wait for full health"): the sacrifice count (HeadbuttSacrifices) no
--   longer resets when a charge refills; it resets to 0 only once Humanoid.Health is back at MaxHealth (checked every
--   frame). So 2 sacrifices, then none until the pachy is at full health again. Switch: script attribute
--   HeadbuttSacrificeFullResetEnabled (default true, read at start; false = 1.5, reset on a refill).
-- v1.7 (Kepu 2026-10-30: "when i click on the 4th and 5th headrush ... my base headrushes were filling in the background
--   so it allows for a 6th and maybe even 7th headrush ... refill should be only on the current empty slot"; answer "A
--   Blood Rush restarts the refill"): a sacrifice press restarts the running refill: refillStart = now, refillAt = now +
--   the refill time for the charges missing now (tiers as before). So the next normal charge comes a full refill after
--   the last Blood Rush press. Normal presses are unchanged. Switch: script attribute HeadbuttSacrificeRestartsRefill
--   (default true, read at start; false = 1.6, the refill keeps running). Diagnostic: character
--   HeadbuttRefillRestarts (count).
-- v1.8 (pachy Servo Dash star, MDA-126; ServoDashServer 1.0): a new character attribute HeadbuttGiveChargeAt gives one
--   charge back at once (capped at the max); when that fills the charges the running refill stops, otherwise the running
--   refill keeps going. Diagnostic: character HeadbuttChargesGiven (count). Switch: script attribute
--   HeadbuttGiveChargeEnabled (default true, read each time; false = 1.7, ignored).
-- v1.9 (pachy Dome Visor, MDA-127; BoneCrest 1.2): a headbutt that would hit a pachy whose visor is up, from the front
--   (BoneCrest.visorFront with the attacker's root position), does nothing: no damage, no shove, no slow; the charge
--   ends with HeadbuttHitResult / HeadbuttResult "visor" (the charge is spent, so the self-slow rule applies as for a
--   miss) and BoneCrest.visorBlock(target, attacker, "headbutt") runs (BLOCK look; star knockback). Switch: script
--   attribute HeadbuttVisorEnabled (default true, read each hit; false = 1.8).
-- Switch: script attribute HeadbuttServerEnabled (default true, read at start; false = every request "disabled").
-- Diagnostics: script HeadbuttServerVersion, HeadbuttRequests, HeadbuttHits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.9"
if script:GetAttribute("HeadbuttSacrificeFullResetEnabled") == nil then script:SetAttribute("HeadbuttSacrificeFullResetEnabled", true) end -- v1.6
local SAC_FULL_RESET = script:GetAttribute("HeadbuttSacrificeFullResetEnabled") ~= false
if script:GetAttribute("HeadbuttSacrificeRestartsRefill") == nil then script:SetAttribute("HeadbuttSacrificeRestartsRefill", true) end -- v1.7
local SAC_RESTARTS_REFILL = script:GetAttribute("HeadbuttSacrificeRestartsRefill") ~= false
if script:GetAttribute("HeadbuttSacrificeEnabled") == nil then script:SetAttribute("HeadbuttSacrificeEnabled", true) end -- v1.5
local SAC_ON = script:GetAttribute("HeadbuttSacrificeEnabled") ~= false
if script:GetAttribute("HeadbuttRunTimeEnabled") == nil then script:SetAttribute("HeadbuttRunTimeEnabled", true) end -- v1.4
local RUNTIME_ON = script:GetAttribute("HeadbuttRunTimeEnabled") ~= false
if script:GetAttribute("HeadbuttRunUpEnabled") == nil then script:SetAttribute("HeadbuttRunUpEnabled", true) end -- v1.3
local RUNUP_ON = script:GetAttribute("HeadbuttRunUpEnabled") ~= false
if script:GetAttribute("HeadbuttHookBusyEnabled") == nil then script:SetAttribute("HeadbuttHookBusyEnabled", true) end -- v1.2
local HOOK_BUSY = script:GetAttribute("HeadbuttHookBusyEnabled") ~= false
if script:GetAttribute("HeadbuttRefillTiersEnabled") == nil then script:SetAttribute("HeadbuttRefillTiersEnabled", true) end -- v1.2
local TIERS_ON = script:GetAttribute("HeadbuttRefillTiersEnabled") ~= false
local END_SLACK = 0.5     -- s after windup + max time the server waits for the client's end
local HIT_TOLERANCE = 16  -- studs (x attacker scale) between the head and the target's hitbox for a claim
local DEFAULTS = {HeadbuttEnabled = false, HeadbuttCharges = 2, HeadbuttExtraCharges = 0, HeadbuttWindup = 0.15,
	HeadbuttMaxTime = 1.8, HeadbuttDamage = 20, HeadbuttShove = 40, HeadbuttShoveTime = 0.35, HeadbuttSlowMul = 0.65,
	HeadbuttSlowTime = 3, HeadbuttRefill = 5, HeadbuttRefillMul = 1, HeadbuttSelfSlowMul = 0.65, HeadbuttSelfSlowTime = 2.5,
	HeadbuttReach = 2, HeadbuttCloseRun = 6, HeadbuttFullRun = 15, HeadbuttCloseMul = 0.5, -- v1.3: + run-up
	HeadbuttCloseTime = 0.15, HeadbuttFullTime = 0.45} -- v1.4: + run-up by charge time

script:SetAttribute("HeadbuttServerVersion", VERSION)
script:SetAttribute("HeadbuttRequests", 0)
script:SetAttribute("HeadbuttHits", 0)
if script:GetAttribute("HeadbuttServerEnabled") == nil then script:SetAttribute("HeadbuttServerEnabled", true) end
if script:GetAttribute("HeadbuttVisorEnabled") == nil then script:SetAttribute("HeadbuttVisorEnabled", true) end -- v1.9
local visorModCache -- v1.9: Dome Visor (ServerStorage.DinoArcade.BoneCrest 1.2), loaded on first use
local function visorMod()
	if visorModCache == nil then
		visorModCache = false
		pcall(function() visorModCache = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end)
	end
	return visorModCache or nil
end
if script:GetAttribute("HeadbuttDomeEnabled") == nil then script:SetAttribute("HeadbuttDomeEnabled", true) end -- v1.1
local DOME_ON = script:GetAttribute("HeadbuttDomeEnabled") ~= false
local function domeMul(char, k) -- v1.1
	if not DOME_ON then return 1 end
	return math.max(0, tonumber(char:GetAttribute(k)) or 1)
end
local enabled = script:GetAttribute("HeadbuttServerEnabled") ~= false

local function remoteOf(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local requestRemote = remoteOf("DinoHeadbuttRequest")
local hitRemote = remoteOf("DinoHeadbuttHit")
local endRemote = remoteOf("DinoHeadbuttEnd")

local function now() return workspace:GetServerTimeNow() end
local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local chars = {} -- [char] = {charges, active = {stamp, startAt, deadline, hit} or nil}

local function maxCharges(char)
	return math.max(1, math.floor((tonumber(get(char, "HeadbuttCharges")) or 2) + (tonumber(get(char, "HeadbuttExtraCharges")) or 0)))
end
local function refillTime(char, missing) -- v1.2: + missing (tiered refill)
	local base = math.max(0.5, (tonumber(get(char, "HeadbuttRefill")) or 5) * (tonumber(get(char, "HeadbuttRefillMul")) or 1))
	if not TIERS_ON or not missing or missing < 2 then return base end
	local k = missing >= 3 and (tonumber(char:GetAttribute("HeadbuttRefillTier3")) or 1.6)
		or (tonumber(char:GetAttribute("HeadbuttRefillTier2")) or 1.3)
	char:SetAttribute("HeadbuttRefillTierUsed", missing >= 3 and 3 or 2)
	return base * k
end

local function publish(char, st)
	char:SetAttribute("HeadbuttChargesMax", maxCharges(char))
	char:SetAttribute("HeadbuttChargesNow", st.charges)
	char:SetAttribute("HeadbuttRefillStart", st.refillStart or 0)
	char:SetAttribute("HeadbuttRefillAt", st.refillAt or 0)
end

local function track(char)
	if chars[char] or char:GetAttribute("HeadbuttEnabled") ~= true then return end
	local st = {charges = maxCharges(char), active = nil}
	chars[char] = st
	publish(char, st)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	for _, a in ipairs({"HeadbuttCharges", "HeadbuttExtraCharges"}) do
		char:GetAttributeChangedSignal(a):Connect(function()
			local m = maxCharges(char)
			if st.charges > m then st.charges = m end
			if st.charges < m and not st.refillAt then
				st.refillStart, st.refillAt = now(), now() + refillTime(char, m - st.charges)
			end
			publish(char, st)
		end)
	end
end

local function finish(char, st, result)
	if not st.active then return end
	local wasSacrifice = st.active.sacrifice == true -- v1.5
	st.active = nil
	local t = now()
	char:SetAttribute("HeadbuttResult", result)
	char:SetAttribute("HeadbuttEndedAt", t)
	if st.charges <= 0 and not (wasSacrifice and char:GetAttribute("BloodRushNoSelfSlow") == true) then -- the downside: every charge used (v1.5: not after a sacrifice with Blood Rush III)
		char:SetAttribute("HeadbuttSelfSlowMul", get(char, "HeadbuttSelfSlowMul"))
		char:SetAttribute("HeadbuttSelfSlowUntil", t + get(char, "HeadbuttSelfSlowTime"))
		char:SetAttribute("HeadbuttSelfSlowCount", (char:GetAttribute("HeadbuttSelfSlowCount") or 0) + 1)
	end
end

local function setResult(char, r)
	char:SetAttribute("HeadbuttServerResult", r)
	char:SetAttribute("HeadbuttServerResultAt", now())
end

requestRemote.OnServerEvent:Connect(function(player, stamp)
	script:SetAttribute("HeadbuttRequests", (script:GetAttribute("HeadbuttRequests") or 0) + 1)
	local char = player.Character
	if not char then return end
	track(char)
	local st = chars[char]
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local result
	local sacrifice = false -- v1.5
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif not enabled or not st or char:GetAttribute("HeadbuttEnabled") ~= true then
		result = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		result = "menu"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		result = "pinned"
	elseif st.active or (HOOK_BUSY and (tonumber(char:GetAttribute("HookBusyUntil")) or 0) > t) then -- v1.2: + hook
		result = "busy"
	elseif st.charges < 1 then
		result = "empty"
		if SAC_ON and char:GetAttribute("BloodRushEnabled") == true then -- v1.5: Blood Rush sacrifice
			if (st.sacrifices or 0) >= (tonumber(char:GetAttribute("BloodRushMax")) or 2) then
				result = "spent"
			elseif hum.Health <= hum.MaxHealth * 0.5 then
				result = "lowHealth"
			else
				result = nil
				sacrifice = true
			end
		end
	end
	if result then
		setResult(char, result)
		return
	end
	if sacrifice then -- v1.5: pay health, no charge
		local before = hum.Health
		hum.Health = math.max(1, before - (tonumber(char:GetAttribute("BloodRushCost")) or 0.25) * hum.MaxHealth)
		st.sacrifices = (st.sacrifices or 0) + 1
		char:SetAttribute("HeadbuttSacrificeCost", math.floor((before - hum.Health) * 10 + 0.5) / 10)
		char:SetAttribute("HeadbuttSacrifices", st.sacrifices)
		char:SetAttribute("HeadbuttSacrificeCount", (char:GetAttribute("HeadbuttSacrificeCount") or 0) + 1)
		char:SetAttribute("HeadbuttSacrificeAt", t)
		if SAC_RESTARTS_REFILL and st.refillAt then -- v1.7: a Blood Rush press puts the refilling charge back to 0 s
			st.refillStart, st.refillAt = t, t + refillTime(char, maxCharges(char) - st.charges)
			char:SetAttribute("HeadbuttRefillRestarts", (char:GetAttribute("HeadbuttRefillRestarts") or 0) + 1)
		end
	else
	st.charges -= 1
	if not st.refillAt then
		st.refillStart, st.refillAt = t, t + refillTime(char, maxCharges(char) - st.charges)
	elseif TIERS_ON then -- v1.2 fix: the running refill stretches to the tier of the charges missing now
		st.refillAt = st.refillStart + refillTime(char, maxCharges(char) - st.charges)
	end
	end
	st.active = {stamp = stamp, startAt = t, deadline = t + get(char, "HeadbuttWindup") + get(char, "HeadbuttMaxTime") + END_SLACK,
		hit = false}
	local hrp0 = char:FindFirstChild("HumanoidRootPart") -- v1.3: where the run-up starts
	st.active.startPos = hrp0 and hrp0.Position or nil
	st.active.sacrifice = sacrifice -- v1.5
	publish(char, st)
	char:SetAttribute("HeadbuttCount", (char:GetAttribute("HeadbuttCount") or 0) + 1)
	setResult(char, "ok")
	char:SetAttribute("HeadbuttStartedAt", t) -- last: clients react to this one
end)

endRemote.OnServerEvent:Connect(function(player, stamp, reason)
	local char = player.Character
	local st = char and chars[char]
	if not st or not st.active or st.active.stamp ~= stamp then return end
	finish(char, st, reason == "timeout" and "timeout" or "ended")
end)

-- target checks
local function targetOk(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model:IsDescendantOf(workspace) then return false end
	local hb = model:FindFirstChild("Hitboxes")
	if not hb then return false end
	if model:GetAttribute("Bitable") ~= true then return false end
	if model:GetAttribute("Species") == nil and model:GetAttribute("IsBot") ~= true then return false end
	return true, hb
end

local function headPos(char)
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxSegment") == "Head" then return p.Position end
		end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function gapTo(pos, hb)
	local best = math.huge
	for _, p in ipairs(hb:GetChildren()) do
		if p:IsA("BasePart") then
			local lp = p.CFrame:PointToObjectSpace(pos)
			local h = p.Size / 2
			local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
			best = math.min(best, (lp - c).Magnitude)
		end
	end
	return best
end

-- bots: slow (scale the AI's WalkSpeed while slowed) and ground glide
local botSlow = {} -- [model] = {hum, base, set}
local function slowBot(model, mul, untilT)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	model:SetAttribute("HeadbuttSlowMul", mul)
	model:SetAttribute("HeadbuttSlowUntil", untilT)
	if not botSlow[model] then botSlow[model] = {hum = hum} end
end
RunService.Stepped:Connect(function()
	local t = now()
	for model, s in pairs(botSlow) do
		local hum = s.hum
		if not model.Parent or not hum.Parent then
			botSlow[model] = nil
		else
			local cur = hum.WalkSpeed
			if s.set == nil or math.abs(cur - s.set) > 1e-3 then s.base = cur end
			if t < (tonumber(model:GetAttribute("HeadbuttSlowUntil")) or 0) then
				s.set = s.base * math.clamp(tonumber(model:GetAttribute("HeadbuttSlowMul")) or 1, 0.05, 1)
				hum.WalkSpeed = s.set
			else
				hum.WalkSpeed = s.base
				botSlow[model] = nil
			end
		end
	end
end)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function shoveBot(model, from, dist, time)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp or hrp.Anchored then return "botBusy" end
	local start = hrp.Position
	local away = Vector3.new(start.X - from.X, 0, start.Z - from.Z)
	if away.Magnitude < 0.5 then away = -Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z) end
	away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
	local isl = workspace:FindFirstChild("DinoIsland")
	local limit = (isl and isl:GetAttribute("IslandWanderLimit")) or 230
	local land = Vector3.new(start.X, 0, start.Z) + away * dist
	land = Vector3.new(math.clamp(land.X, -limit, limit), 0, math.clamp(land.Z, -limit, limit))
	local ex = {model}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local tg = isl and isl:FindFirstChild("TallGrass")
	if tg then table.insert(ex, tg) end
	local bots = isl and isl:FindFirstChild("Bots")
	if bots then table.insert(ex, bots) end
	rayParams.FilterDescendantsInstances = ex
	local g0 = workspace:Raycast(start + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), rayParams)
	local lift = g0 and (start.Y - g0.Position.Y) or 3
	local g1 = workspace:Raycast(Vector3.new(land.X, start.Y + 40, land.Z), Vector3.new(0, -140, 0), rayParams)
	local landPos = Vector3.new(land.X, (g1 and g1.Position.Y or (start.Y - lift)) + lift, land.Z)
	local rot = hrp.CFrame - hrp.Position
	hrp.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time do
			local u = math.clamp((os.clock() - t0) / time, 0, 1)
			local e = 1 - (1 - u) * (1 - u) -- ease out: fast push, then slows
			if not hrp.Parent then return end
			hrp.CFrame = CFrame.new(start:Lerp(landPos, e)) * rot
			RunService.Heartbeat:Wait()
		end
		if hrp.Parent then
			hrp.CFrame = CFrame.new(landPos) * rot
			hrp.Anchored = false
		end
	end)
	return "shoved"
end

hitRemote.OnServerEvent:Connect(function(player, stamp, model)
	local char = player.Character
	local st = char and chars[char]
	local t = now()
	local result
	local ok, hb = targetOk(model)
	if not st or not st.active or st.active.stamp ~= stamp or t > st.active.deadline then
		result = "noCharge"
	elseif st.active.hit then
		result = "used"
	elseif not ok then
		result = "badTarget"
	elseif model == char then
		result = "self"
	elseif model:GetAttribute("DummyState") == "ko" then
		result = "ko"
	else
		local hp = headPos(char)
		local scale = char:GetScale()
		local gap = hp and gapTo(hp, hb) or math.huge
		char:SetAttribute("HeadbuttHitGap", math.floor(gap * 10 + 0.5) / 10)
		if gap > (HIT_TOLERANCE + get(char, "HeadbuttReach")) * scale then result = "far" end
	end
	if not result and script:GetAttribute("HeadbuttVisorEnabled") ~= false then -- v1.9: Dome Visor
		local VM = visorMod()
		local aRoot = char:FindFirstChild("HumanoidRootPart")
		if VM and aRoot and VM.visorFront(model, aRoot.Position) then
			char:SetAttribute("HeadbuttHitResult", "visor")
			st.active.hit = true
			VM.visorBlock(model, char, "headbutt")
			finish(char, st, "visor")
			return
		end
	end
	char:SetAttribute("HeadbuttHitResult", result or "hit")
	if result then return end
	st.active.hit = true
	-- damage
	local mul = 1
	local untilT, dmul = model:GetAttribute("DebuffUntil"), model:GetAttribute("DebuffDamageTakenMul")
	if typeof(untilT) == "number" and typeof(dmul) == "number" and t < untilT then mul = dmul end
	local runMul = 1 -- v1.3: less damage without a run-up
	if RUNUP_ON then
		local hrpNow = char:FindFirstChild("HumanoidRootPart")
		local run = 0
		if st.active.startPos and hrpNow then
			local dv = hrpNow.Position - st.active.startPos
			run = Vector3.new(dv.X, 0, dv.Z).Magnitude
		end
		local sc = char:GetScale()
		local close, full = get(char, "HeadbuttCloseRun") * sc, math.max(get(char, "HeadbuttFullRun") * sc, get(char, "HeadbuttCloseRun") * sc + 0.01)
		local cm = math.clamp(get(char, "HeadbuttCloseMul"), 0, 1)
		runMul = cm + (1 - cm) * math.clamp((run - close) / (full - close), 0, 1)
		if RUNTIME_ON then -- v1.4: charge time too (the server sees the body late); the larger counts
			local charged = math.max(0, t - st.active.startAt - get(char, "HeadbuttWindup"))
			local ct, ft = get(char, "HeadbuttCloseTime"), math.max(get(char, "HeadbuttFullTime"), get(char, "HeadbuttCloseTime") + 0.01)
			runMul = math.max(runMul, cm + (1 - cm) * math.clamp((charged - ct) / (ft - ct), 0, 1))
			char:SetAttribute("HeadbuttHitChargeTime", math.floor(charged * 100 + 0.5) / 100)
		end
		char:SetAttribute("HeadbuttHitRun", math.floor(run * 10 + 0.5) / 10)
		char:SetAttribute("HeadbuttHitRunMul", math.floor(runMul * 100 + 0.5) / 100)
	end
	local sacMul = 1 -- v1.5: Blood Rush II
	if st.active.sacrifice then sacMul = math.max(0, tonumber(char:GetAttribute("BloodRushDamageMul")) or 1) end
	char:SetAttribute("HeadbuttHitSacrifice", st.active.sacrifice == true)
	local d = math.floor(get(char, "HeadbuttDamage") * runMul * sacMul * domeMul(char, "HeadbuttDamageMul") * mul + 0.5) -- v1.1: x dome; v1.3: x run-up; v1.5: x Blood Rush
	local hp = model:GetAttribute("DummyHealth")
	if typeof(hp) == "number" then model:SetAttribute("DummyHealth", math.max(0, hp - d)) end
	if typeof(hp) == "number" and hp > 0 and hp - d <= 0 then
		model:SetAttribute("KilledBy", char.Name)
		model:SetAttribute("KilledByUserId", player.UserId)
		model:SetAttribute("KilledWith", "headbutt")
		model:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
	end
	-- shove + slow at the same time (blocked by an Energy Shield)
	local root = char:FindFirstChild("HumanoidRootPart")
	local from = root and root.Position or model:GetPivot().Position
	local shielded = (tonumber(model:GetAttribute("EnergyShieldUntil")) or 0) > t
	local slowMul, slowUntil = get(char, "HeadbuttSlowMul"), t + get(char, "HeadbuttSlowTime")
	local bSlow = tonumber(char:GetAttribute("BloodRushSlowMul")) -- v1.5: Blood Rush star, a harder slow
	if st.active.sacrifice and bSlow and bSlow < slowMul then
		slowMul, slowUntil = bSlow, t + (tonumber(char:GetAttribute("BloodRushSlowTime")) or get(char, "HeadbuttSlowTime"))
	end
	local shoveResult
	if shielded then
		shoveResult = "shielded"
	elseif Players:GetPlayerFromCharacter(model) then
		model:SetAttribute("HeadbuttSlowMul", slowMul)
		model:SetAttribute("HeadbuttSlowUntil", slowUntil)
		model:SetAttribute("HeadbuttShoveFrom", from)
		model:SetAttribute("HeadbuttShoveDist", get(char, "HeadbuttShove") * domeMul(char, "HeadbuttShoveMul")) -- v1.1
		model:SetAttribute("HeadbuttShoveTime", get(char, "HeadbuttShoveTime"))
		model:SetAttribute("HeadbuttShoveAt", t) -- last: HeadbuttShove client reacts to this one
		shoveResult = "shoved"
	else
		slowBot(model, slowMul, slowUntil)
		shoveResult = shoveBot(model, from, get(char, "HeadbuttShove") * domeMul(char, "HeadbuttShoveMul"), get(char, "HeadbuttShoveTime")) -- v1.1
	end
	model:SetAttribute("HeadbuttShoveResult", shoveResult)
	model:SetAttribute("HeadbuttHitBy", char.Name)
	char:SetAttribute("HeadbuttHitDamage", d)
	char:SetAttribute("HeadbuttHitTarget", model.Name)
	char:SetAttribute("HeadbuttHitCount", (char:GetAttribute("HeadbuttHitCount") or 0) + 1)
	char:SetAttribute("HeadbuttHitAt", t) -- last: ArenaPvP / SkillEffects / clients react to this one
	script:SetAttribute("HeadbuttHits", (script:GetAttribute("HeadbuttHits") or 0) + 1)
	finish(char, st, "hit")
end)

-- refills and deadlines
RunService.Heartbeat:Connect(function()
	local t = now()
	for char, st in pairs(chars) do
		if st.refillAt and t >= st.refillAt then
			st.charges = math.min(maxCharges(char), st.charges + 1)
			if not SAC_FULL_RESET and (st.sacrifices or 0) > 0 then st.sacrifices = 0; char:SetAttribute("HeadbuttSacrifices", 0) end -- v1.5: a refill resets Blood Rush (v1.6: only with the switch off)
			if st.charges < maxCharges(char) then
				st.refillStart, st.refillAt = t, t + refillTime(char, maxCharges(char) - st.charges)
			else
				st.refillStart, st.refillAt = nil, nil
			end
			publish(char, st)
		end
		if st.active and t > st.active.deadline then finish(char, st, "timeout") end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if st.active and hum and hum.Health <= 0 then finish(char, st, "died") end
		if SAC_FULL_RESET and (st.sacrifices or 0) > 0 and hum and hum.Health > 0 and hum.Health >= hum.MaxHealth - 0.01 then -- v1.6
			st.sacrifices = 0
			char:SetAttribute("HeadbuttSacrifices", 0)
		end
	end
end)

-- characters
local function onCharacter(char)
	task.defer(function()
		if char.Parent then track(char) end
	end)
	char:GetAttributeChangedSignal("HeadbuttEnabled"):Connect(function() track(char) end)
	char:GetAttributeChangedSignal("HeadbuttGiveChargeAt"):Connect(function() -- v1.8: Servo Dash star
		if script:GetAttribute("HeadbuttGiveChargeEnabled") == false then return end
		local st = chars[char]
		if not st then return end
		local m = maxCharges(char)
		if st.charges >= m then return end
		st.charges += 1
		if st.charges >= m then st.refillStart, st.refillAt = nil, nil end
		char:SetAttribute("HeadbuttChargesGiven", (char:GetAttribute("HeadbuttChargesGiven") or 0) + 1)
		publish(char, st)
	end)
end
local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
