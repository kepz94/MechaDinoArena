-- SlashServer v1.5 (Mecha Dino Arena) — the Herrerasaurus' dash-through slash (server side). MDA-140, plan
-- docs/plans/HERRERA_KIT_v1.0.md Task 8, mockup docs/mockups/herrera_kit_options.html (look A).
-- Kepu 2026-10-30: slash "Dash-through slash", payoff "Bleed"; drop attack "should be able to happen if I press the dash
--   aimed at a nearby target but not be its own dedicated button".
-- Pattern: HeadbuttServer 1.x (request -> server-owned charges -> client hit claims checked on the server).
-- Who: every character with SlashEnabled = true (HerreraModelData 1.2). Settings are character attributes (defaults in
--   DEFAULTS; distances at scale 1, multiplied by the character's scale): SlashCharges 2, SlashRefill 4 s (one charge at a
--   time), SlashDist 12.5 (dash length), SlashTime 0.3 (dash time), SlashDamage 8, SlashBleedDps 3, SlashBleedTime 4,
--   SlashBleedTick 1 s, SlashBurstMul 1.4, SlashBurstTime 0.5, SlashDiveRange 20, SlashReach 2.
-- Charges (server-owned): SlashChargesNow / SlashChargesMax; SlashRefillStart / SlashRefillAt = server times of the
--   charge that is refilling (0 when full). A new character starts full.
-- Remotes (ReplicatedStorage):
--   DinoSlashRequest(stamp, kind, target?) -> checks in order: "badArg" (stamp not a number, or kind not "ground" /
--     "dive"), "dead", "disabled" (SlashEnabled not true or the script switch off), "menu" (player InMenu), "stunned"
--     (StunnedUntil), "pinned" (PinHeld), "busy" (a dash running), "empty" (no charge), "noTree" (kind "dive" while the
--     character's ClimbState (ClimbServer 1.0) is not "climbing" / "clinging" / "top") -> "ok": a charge is spent and the
--     dash path is fixed on the server (the Herrera's body is moved by its own client and seen late here, so hits are
--     checked against this path, not the body):
--       from = the HumanoidRootPart position now (SlashFrom), dir = its horizontal facing (SlashDir).
--       ground: the segment from + dir x SlashDist x scale; length L = SlashDist x scale.
--       dive with a target (a Model passing the target checks below, its root within SlashDiveRange x scale + DIVE_SLACK
--         x scale of from and lower than from): the segment from -> the target's root; SlashDiveTarget = its name.
--       dive without a valid target (nil / failing a check; SlashDiveCheck says which): a leap, the segment from ->
--         from + dir x L, dropped to the ground found below that point (raycast; else from.Y - L).
--     Dash time = SlashTime x max(1, path length / (SlashDist x scale)) (same speed as the ground dash).
--     Stamps: SlashKind, SlashFrom, SlashDir, SlashTo (path end), SlashDashTime, SlashCount, SlashServerResult (+ At),
--     SlashStartedAt (server time, last: clients react to this one).
--   DinoSlashHit(stamp, model) -> the client's claim that the dash passed through model. Accepted when: the dash with that
--     stamp runs (server time <= start + dash time + TIME_SLACK); model passes the target checks (workspace Model with a
--     Hitboxes folder, Bitable true, a Species or IsBot, not the attacker, not KO (DummyState "ko")); it was not hit by
--     this dash yet; the closest point of one of its hitbox parts is within (SlashReach + PATH_TOLERANCE) x scale of the
--     dash path. Result in SlashHitResult: "hit" / "noDash" / "used" / "badTarget" / "self" / "ko" / "far"
--     (+ SlashHitGap, studs to the path, 0.1).
--     A hit: damage = SlashDamage x the target's roar debuff (DebuffDamageTakenMul while DebuffUntil), rounded, off the
--     target's DummyHealth (ArenaPvP turns that into Humanoid damage for players); a killing blow stamps KilledBy,
--     KilledByUserId, KilledWith "slash", KilledAt (last). Bleed unless the target's Energy Shield is up
--     (EnergyShieldUntil): SlashBleedUntil = now + SlashBleedTime, SlashBleedBy = attacker name, SlashBleedDps; a new
--     hit restarts the timer (no stacking: one bleed per target, the latest attacker's). Target: SlashHitBy,
--     SlashBleedResult ("bleeding" / "shielded"), SlashTakenDamage, SlashTakenAt (last). Attacker: SlashHitDamage,
--     SlashHitTarget, SlashHitCount, SlashHitAt (last). The dash keeps running (it claws every dino it passes, once each).
-- Bleed ticks (every SlashBleedTick s from the hit, while now <= SlashBleedUntil): SlashBleedDps x SlashBleedTick off
--   DummyHealth (rounded to 0.1); a tick while the target's Energy Shield is up is skipped (the timer runs on); a killing
--   tick stamps KilledBy / KilledByUserId / KilledWith "bleed" / KilledAt. Target: SlashBleedTickDamage,
--   SlashBleedTickAt (last). The bleed ends at SlashBleedUntil, on KO (DummyState "ko"), or when the target leaves.
--   Bleed tick note: the plan text said 0.5 s ticks; Kepu's picked mockup ticks every 1 s with "-3" (same 12 total), so
--   SlashBleedTick defaults to 1.
-- Speed burst: when a dash ends (start + dash time) the attacker gets SlashBurstMul and SlashBurstUntil = end +
--   SlashBurstTime (SprintTest 1.11 multiplies the run speed while it lasts); SlashEndedAt (last).
-- v1.1 (Studio check of 1.0: a bleed on Bot_TRex_1 took 3 ticks (9), not 4 — the last tick is due exactly at
--   SlashBleedUntil and the expiry test ran first): a tick is taken when due and not later than SlashBleedUntil (+1 ms);
--   the bleed is dropped after its last tick (next tick past SlashBleedUntil).
-- v1.2 (Studio check of SlashTest 1.0: the ground dash into an anchored T-Rex bot hit it, but the body slid around the
--   bot's blocking hitboxes instead of passing through; the plan's dash is "through"): registers the collision group
--   "SlashDash" = the collisions of "HerreraBody" (TreeTopServer 1.0; "Default" when it is missing) with every registered
--   group, except "DinoHitbox" (DinoHitboxes' boxes) and itself: not collidable. SlashTest 1.1 puts the dashing Herrera's
--   own parts in it for the dash only. Copied at start and again after 4 s (TreeTopServer re-copies HerreraBody after 3 s).
--   Switch: script attribute SlashPassThroughEnabled (default true, read at start; false = no group, 1.1). Diagnostic:
--   script SlashDashGroup ("ready" / "off" / "failed").
-- v1.3 (Herrera stat rows, SkillTree 1.37 / SkillEffects 1.26, plan docs/plans/STAT_LINES_v1.0.md; Kepu 2026-10-31 picked
--   the new rows Tree Stalker and Blood Frenzy): reads these attacker character attributes (SkillEffects writes them;
--   missing = off):
--     SlashDiveRefill (bool): the first hit of a dive gives back one charge (capped at SlashChargesMax).
--     SlashDiveStun (s): a dive hit sets the target's StunnedUntil = max(its value, now + SlashDiveStun).
--     SlashBleedBonus (damage): a hit on a target already bleeding from a slash adds this to the hit (before the debuff
--       multiplier); the new bleed then restarts as before.
--     SlashKillRefill (bool): a kill by this attacker's slash on a bleeding target, or by this attacker's bleed tick, refills
--       every charge.
--     SlashFrenzyMul (number > 1): every 0.25 s, while a slash-bleeding dino other than this one has its root within
--       SlashFrenzyRange (default 40) x scale of this one's root, SlashFrenzyUntil = now + 0.5 (SprintTest 1.13 multiplies
--       the speed by SlashFrenzyMul until then).
--   Bleed ticks are credited to the attacker: SlashBleedDealt (damage of the tick) then SlashBleedDealtAt (last; SkillEffects
--   1.26 heals Blood Drinker from it). takeHealth now returns true on a killing blow (callers that ignore it are unchanged).
--   Diagnostics: attacker SlashSkillLast ("diveRefill" / "diveStun" / "bleedBonus" / "killRefill"), SlashFrenzyActive (bool);
--   script SlashSkillEvents (count). Switch: script attribute SlashSkillsEnabled (default true, read at start; false = 1.2:
--   none of the above, no SlashBleedDealt stamps).
-- v1.4 (Herrera Iron Claw, MDA-149, plan docs/plans/HERRERA_PARTS_v1.0.md Part 1): a slash hit's damage is also
--   multiplied by the attacker's IronClawDamageMul while its IronClawEnabled is true (SkillEffects 1.27: 1.1 / 1.2 / 1.3 /
--   1.5): d = round((SlashDamage + bleed bonus) x debuff x IronClawDamageMul). Bleed ticks are unchanged. Attacker
--   diagnostic SlashIronClawMul (the multiplier used on the last hit). Switch: script attribute SlashIronClawEnabled
--   (default true, read at start; false = 1.3).
-- v1.5 (Herrera parts pass 2, plan docs/plans/HERRERA_PARTS_v1.0.md "Pass 2 — build map"):
--   * Strobe Frill daze (MDA-155): a request while the character's DazedUntil is in the future is refused ("dazed", right
--     after "stunned"). A hit's damage is also x the target's DazedDamageMul while its DazedUntil is in the future (star
--     1.2) and x 0 while its StunBreakImmuneUntil is in the future (Stun Breaker star, MDA-156). Switch: script attribute
--     SlashDazeEnabled (default true, read at each request / hit; false = 1.4).
--   * Glider Wings (MDA-150): a "dive" request off a tree is accepted while the character's Gliding is true (replicated,
--     HerreraMovesServer 1.0) and GliderDrop is true (step II); the dash is marked as a glide dive (attacker SlashGlideDive
--     true, false on other dashes). A glide-dive hit's damage is x GliderDropMul (III: 1.3). Star (GliderBurst > 0): that
--     hit also starts the slash bleed (the attacker's SlashBleedDps / SlashBleedTime, same rules as a hit's bleed) on every
--     other dino (player characters and Workspace.DinoIsland.Bots, Bitable, Hitboxes, not KO, no Energy Shield) whose root
--     is within GliderBurst x scale of the landing point (the hit target's root); attacker SlashGlideBurstCount. Switch:
--     script attribute SlashGlideEnabled (default true, read at each request / hit; false = 1.4).
-- Switch: script attribute SlashServerEnabled (default true, read at start; false = every request "disabled").
-- Diagnostics: script SlashServerVersion, SlashRequests, SlashHits, SlashBleedTicks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.5"
local TIME_SLACK = 0.6      -- s after the dash time a claim is still accepted (client -> server lag)
local PATH_TOLERANCE = 6    -- studs (x scale) between the target's hitboxes and the dash path, on top of SlashReach
local DIVE_SLACK = 3        -- studs (x scale) added to SlashDiveRange for the request check (the target moves)
local SAMPLE_STEP = 1       -- studs between points sampled along the path for the distance test
local DEFAULTS = {SlashEnabled = false, SlashCharges = 2, SlashRefill = 4, SlashDist = 12.5, SlashTime = 0.3,
	SlashDamage = 8, SlashBleedDps = 3, SlashBleedTime = 4, SlashBleedTick = 1, SlashBurstMul = 1.4, SlashBurstTime = 0.5,
	SlashDiveRange = 20, SlashReach = 2}

script:SetAttribute("SlashServerVersion", VERSION)
script:SetAttribute("SlashRequests", 0)
script:SetAttribute("SlashHits", 0)
script:SetAttribute("SlashBleedTicks", 0)
if script:GetAttribute("SlashServerEnabled") == nil then script:SetAttribute("SlashServerEnabled", true) end
local enabled = script:GetAttribute("SlashServerEnabled") ~= false
if script:GetAttribute("SlashSkillsEnabled") == nil then script:SetAttribute("SlashSkillsEnabled", true) end -- v1.3
local SKILLS = script:GetAttribute("SlashSkillsEnabled") ~= false
script:SetAttribute("SlashSkillEvents", 0)
local FRENZY_STEP, FRENZY_HOLD, FRENZY_RANGE = 0.25, 0.5, 40
if script:GetAttribute("SlashIronClawEnabled") == nil then script:SetAttribute("SlashIronClawEnabled", true) end -- v1.4
local IRONCLAW = script:GetAttribute("SlashIronClawEnabled") ~= false
for _, k in ipairs({"SlashDazeEnabled", "SlashGlideEnabled"}) do -- v1.5
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function dazeOn() return script:GetAttribute("SlashDazeEnabled") ~= false end -- v1.5
local function glideDive(char) -- v1.5: gliding with Glider Wings II
	return script:GetAttribute("SlashGlideEnabled") ~= false and char:GetAttribute("Gliding") == true and char:GetAttribute("GliderDrop") == true
end
local function takenMul(model, t) -- v1.5: daze star x Stun Breaker star
	if not dazeOn() then return 1 end
	local m = 1
	if (tonumber(model:GetAttribute("DazedUntil")) or 0) > t then m *= math.max(1, tonumber(model:GetAttribute("DazedDamageMul")) or 1) end
	if (tonumber(model:GetAttribute("StunBreakImmuneUntil")) or 0) > t then m = 0 end
	return m
end

-- v1.2: pass-through collision group for the dash
do
	if script:GetAttribute("SlashPassThroughEnabled") == nil then script:SetAttribute("SlashPassThroughEnabled", true) end
	if script:GetAttribute("SlashPassThroughEnabled") == false then
		script:SetAttribute("SlashDashGroup", "off")
	else
		local PhysicsService = game:GetService("PhysicsService")
		local GROUP, HITBOX = "SlashDash", "DinoHitbox"
		local function copyGroups()
			local ok = pcall(function()
				if not PhysicsService:IsCollisionGroupRegistered(GROUP) then PhysicsService:RegisterCollisionGroup(GROUP) end
				local src = PhysicsService:IsCollisionGroupRegistered("HerreraBody") and "HerreraBody" or "Default"
				for _, g in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
					local name = g.name
					if name ~= GROUP then
						PhysicsService:CollisionGroupSetCollidable(GROUP, name, PhysicsService:CollisionGroupsAreCollidable(src, name))
					end
				end
				PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
				if PhysicsService:IsCollisionGroupRegistered(HITBOX) then
					PhysicsService:CollisionGroupSetCollidable(GROUP, HITBOX, false)
				end
			end)
			script:SetAttribute("SlashDashGroup", ok and "ready" or "failed")
		end
		copyGroups()
		task.delay(4, copyGroups)
	end
end

local function remoteOf(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local requestRemote = remoteOf("DinoSlashRequest")
local hitRemote = remoteOf("DinoSlashHit")

local function now() return workspace:GetServerTimeNow() end
local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return tonumber(v) or DEFAULTS[k]
end

local chars = {} -- [char] = {charges, refillStart, refillAt, active = {stamp, startAt, endAt, from, to, hit = {}} or nil}

local function maxCharges(char)
	return math.max(1, math.floor(get(char, "SlashCharges")))
end
local function refillTime(char)
	return math.max(0.5, get(char, "SlashRefill"))
end
local function publish(char, st)
	char:SetAttribute("SlashChargesMax", maxCharges(char))
	char:SetAttribute("SlashChargesNow", st.charges)
	char:SetAttribute("SlashRefillStart", st.refillStart or 0)
	char:SetAttribute("SlashRefillAt", st.refillAt or 0)
end

local function track(char)
	if chars[char] or char:GetAttribute("SlashEnabled") ~= true then return end
	local st = {charges = maxCharges(char), active = nil}
	chars[char] = st
	publish(char, st)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	char:GetAttributeChangedSignal("SlashCharges"):Connect(function()
		local m = maxCharges(char)
		if st.charges > m then st.charges = m end
		if st.charges < m and not st.refillAt then st.refillStart, st.refillAt = now(), now() + refillTime(char) end
		if st.charges >= m then st.refillStart, st.refillAt = nil, nil end
		publish(char, st)
	end)
end

local function setResult(char, r)
	char:SetAttribute("SlashServerResult", r)
	char:SetAttribute("SlashServerResultAt", now())
end

-- target checks (HeadbuttServer's)
local function targetOk(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model:IsDescendantOf(workspace) then return false end
	local hb = model:FindFirstChild("Hitboxes")
	if not hb then return false end
	if model:GetAttribute("Bitable") ~= true then return false end
	if model:GetAttribute("Species") == nil and model:GetAttribute("IsBot") ~= true then return false end
	return true, hb
end

local function rootOf(model)
	local r = model:FindFirstChild("HumanoidRootPart")
	return r and r.Position or model:GetPivot().Position
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function climbing(char)
	local cs = char:GetAttribute("ClimbState")
	return cs == "climbing" or cs == "clinging" or cs == "top"
end

requestRemote.OnServerEvent:Connect(function(player, stamp, kind, target)
	script:SetAttribute("SlashRequests", (script:GetAttribute("SlashRequests") or 0) + 1)
	local char = player.Character
	if not char then return end
	track(char)
	local st = chars[char]
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local t = now()
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp or (kind ~= "ground" and kind ~= "dive") then
		result = "badArg"
	elseif not hum or hum.Health <= 0 or not hrp then
		result = "dead"
	elseif not enabled or not st or char:GetAttribute("SlashEnabled") ~= true then
		result = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		result = "menu"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif dazeOn() and (tonumber(char:GetAttribute("DazedUntil")) or 0) > t then -- v1.5: Strobe Frill daze
		result = "dazed"
	elseif char:GetAttribute("PinHeld") == true then
		result = "pinned"
	elseif st.active then
		result = "busy"
	elseif st.charges < 1 then
		result = "empty"
	elseif kind == "dive" and not climbing(char) and glideDive(char) then -- v1.5: a dive from a glide is accepted
		char:SetAttribute("SlashGlideDive", true)
	elseif kind == "dive" and not climbing(char) then
		result = "noTree"
	end
	if result then
		setResult(char, result)
		return
	end
	-- charge
	st.charges -= 1
	if not st.refillAt then st.refillStart, st.refillAt = t, t + refillTime(char) end
	-- path
	local scale = char:GetScale()
	local L = get(char, "SlashDist") * scale
	local from = hrp.Position
	local look = hrp.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local to = from + dir * L
	local diveTarget = ""
	if kind == "dive" then
		local check
		local ok = targetOk(target)
		if target == nil then
			check = "none"
		elseif not ok then
			check = "badTarget"
		elseif target == char then
			check = "self"
		elseif target:GetAttribute("DummyState") == "ko" then
			check = "ko"
		else
			local tp = rootOf(target)
			if (tp - from).Magnitude > (get(char, "SlashDiveRange") + DIVE_SLACK) * scale then
				check = "far"
			elseif tp.Y >= from.Y then
				check = "notBelow"
			else
				check = "ok"
				to = tp
				diveTarget = target.Name
			end
		end
		char:SetAttribute("SlashDiveCheck", check)
		if check ~= "ok" then -- leap: forward, then down to the ground below the end point
			groundParams.FilterDescendantsInstances = {char}
			local g = workspace:Raycast(to + Vector3.new(0, 2, 0), Vector3.new(0, -400, 0), groundParams)
			to = Vector3.new(to.X, g and g.Position.Y or (from.Y - L), to.Z)
		end
	end
	local pathLen = (to - from).Magnitude
	local dashTime = get(char, "SlashTime") * math.max(1, pathLen / math.max(L, 1e-3))
	st.active = {stamp = stamp, startAt = t, endAt = t + dashTime, from = from, to = to, hit = {}, kind = kind} -- v1.3: + kind
	st.active.glide = kind == "dive" and not climbing(char) and glideDive(char) -- v1.5
	char:SetAttribute("SlashGlideDive", st.active.glide)
	publish(char, st)
	char:SetAttribute("SlashKind", kind)
	char:SetAttribute("SlashFrom", from)
	char:SetAttribute("SlashDir", dir)
	char:SetAttribute("SlashTo", to)
	char:SetAttribute("SlashDiveTarget", diveTarget)
	char:SetAttribute("SlashDashTime", math.floor(dashTime * 100 + 0.5) / 100)
	char:SetAttribute("SlashCount", (char:GetAttribute("SlashCount") or 0) + 1)
	setResult(char, "ok")
	char:SetAttribute("SlashStartedAt", t) -- last: clients react to this one
end)

-- distance from the target's hitboxes to the dash path (sampled along the segment)
local function gapToPath(hb, a, b)
	local parts = {}
	for _, p in ipairs(hb:GetChildren()) do
		if p:IsA("BasePart") then table.insert(parts, p) end
	end
	local len = (b - a).Magnitude
	local n = math.max(1, math.ceil(len / SAMPLE_STEP))
	local best = math.huge
	for i = 0, n do
		local pos = a:Lerp(b, i / n)
		for _, p in ipairs(parts) do
			local lp = p.CFrame:PointToObjectSpace(pos)
			local h = p.Size / 2
			local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
			best = math.min(best, (lp - c).Magnitude)
		end
	end
	return best
end

local function takeHealth(model, d, killer, killerId, with, t)
	local hp = model:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" then return end
	local after = math.max(0, hp - d)
	model:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		model:SetAttribute("KilledBy", killer)
		model:SetAttribute("KilledByUserId", killerId)
		model:SetAttribute("KilledWith", with)
		model:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
		return true -- v1.3
	end
	return false
end

-- v1.3: skill rows
local function skillEvent(char, what)
	char:SetAttribute("SlashSkillLast", what)
	script:SetAttribute("SlashSkillEvents", (script:GetAttribute("SlashSkillEvents") or 0) + 1)
end
local function addCharges(char, st, n)
	local m = maxCharges(char)
	st.charges = math.min(m, st.charges + n)
	if st.charges >= m then st.refillStart, st.refillAt = nil, nil end
	publish(char, st)
end

local bleeds = {} -- [model] = {untilT, nextTick, by, byId, dps, tick}

hitRemote.OnServerEvent:Connect(function(player, stamp, model)
	local char = player.Character
	local st = char and chars[char]
	local t = now()
	local result
	local ok, hb = targetOk(model)
	if not st or not st.active or st.active.stamp ~= stamp or t > st.active.endAt + TIME_SLACK then
		result = "noDash"
	elseif not ok then
		result = "badTarget"
	elseif model == char then
		result = "self"
	elseif st.active.hit[model] then
		result = "used"
	elseif model:GetAttribute("DummyState") == "ko" then
		result = "ko"
	else
		local scale = char:GetScale()
		local gap = gapToPath(hb, st.active.from, st.active.to)
		char:SetAttribute("SlashHitGap", math.floor(gap * 10 + 0.5) / 10)
		if gap > (get(char, "SlashReach") + PATH_TOLERANCE) * scale then result = "far" end
	end
	char:SetAttribute("SlashHitResult", result or "hit")
	if result then return end
	st.active.hit[model] = true
	-- damage
	local mul = 1
	local untilT, dmul = model:GetAttribute("DebuffUntil"), model:GetAttribute("DebuffDamageTakenMul")
	if typeof(untilT) == "number" and typeof(dmul) == "number" and t < untilT then mul = dmul end
	local wasBleeding = SKILLS and bleeds[model] ~= nil and t <= bleeds[model].untilT + 1e-3 -- v1.3
	local bonus = wasBleeding and math.max(0, tonumber(char:GetAttribute("SlashBleedBonus")) or 0) or 0 -- v1.3
	local icMul = 1 -- v1.4: Iron Claw
	if IRONCLAW and char:GetAttribute("IronClawEnabled") == true then icMul = math.max(0, tonumber(char:GetAttribute("IronClawDamageMul")) or 1) end
	char:SetAttribute("SlashIronClawMul", icMul)
	mul *= takenMul(model, t) -- v1.5
	if st.active.glide then icMul *= math.max(0, tonumber(char:GetAttribute("GliderDropMul")) or 1) end -- v1.5: glide dive
	local d = math.floor((get(char, "SlashDamage") + bonus) * mul * icMul + 0.5)
	local killed = takeHealth(model, d, char.Name, player.UserId, "slash", t)
	if bonus > 0 then skillEvent(char, "bleedBonus") end
	if SKILLS and st.active.kind == "dive" then -- v1.3: Tree Stalker
		if char:GetAttribute("SlashDiveRefill") == true and not st.active.refilled then
			st.active.refilled = true
			addCharges(char, st, 1)
			skillEvent(char, "diveRefill")
		end
		local stun = tonumber(char:GetAttribute("SlashDiveStun")) or 0
		if stun > 0 and not killed then
			model:SetAttribute("StunnedUntil", math.max(tonumber(model:GetAttribute("StunnedUntil")) or 0, t + stun))
			skillEvent(char, "diveStun")
		end
	end
	if killed and wasBleeding and char:GetAttribute("SlashKillRefill") == true then -- v1.3: Blood Frenzy star
		addCharges(char, st, maxCharges(char))
		skillEvent(char, "killRefill")
	end
	-- bleed (no stacking: one per target, restarted by a new hit)
	local shielded = (tonumber(model:GetAttribute("EnergyShieldUntil")) or 0) > t
	if shielded then
		model:SetAttribute("SlashBleedResult", "shielded")
	else
		local tick = math.max(0.1, get(char, "SlashBleedTick"))
		bleeds[model] = {untilT = t + get(char, "SlashBleedTime"), nextTick = t + tick, by = char.Name, byId = player.UserId,
			dps = get(char, "SlashBleedDps"), tick = tick, char = char} -- v1.3: + char
		model:SetAttribute("SlashBleedUntil", bleeds[model].untilT)
		model:SetAttribute("SlashBleedBy", char.Name)
		model:SetAttribute("SlashBleedDps", bleeds[model].dps)
		model:SetAttribute("SlashBleedResult", "bleeding")
	end
	if st.active.glide and script:GetAttribute("SlashGlideEnabled") ~= false then -- v1.5: Glider Wings star bleed burst
		local burst = (tonumber(char:GetAttribute("GliderBurst")) or 0) * char:GetScale()
		local n = 0
		local land = rootOf(model)
		if burst > 0 and land then
			local list = {}
			for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
			local isl = workspace:FindFirstChild("DinoIsland")
			local bf = isl and isl:FindFirstChild("Bots")
			if bf then for _, b in ipairs(bf:GetChildren()) do table.insert(list, b) end end
			for _, m in ipairs(list) do
				if m ~= char and m ~= model and targetOk(m) and m:GetAttribute("DummyState") ~= "ko"
					and (tonumber(m:GetAttribute("EnergyShieldUntil")) or 0) <= t and (rootOf(m) - land).Magnitude <= burst then
					local tick = math.max(0.1, get(char, "SlashBleedTick"))
					bleeds[m] = {untilT = t + get(char, "SlashBleedTime"), nextTick = t + tick, by = char.Name, byId = player.UserId,
						dps = get(char, "SlashBleedDps"), tick = tick, char = char}
					m:SetAttribute("SlashBleedUntil", bleeds[m].untilT)
					m:SetAttribute("SlashBleedBy", char.Name)
					m:SetAttribute("SlashBleedDps", bleeds[m].dps)
					m:SetAttribute("SlashBleedResult", "burst")
					n += 1
				end
			end
		end
		char:SetAttribute("SlashGlideBurstCount", n)
	end
	model:SetAttribute("SlashHitBy", char.Name)
	model:SetAttribute("SlashTakenDamage", d)
	model:SetAttribute("SlashTakenAt", t) -- last on the target: SlashFX reacts to this one
	char:SetAttribute("SlashHitDamage", d)
	char:SetAttribute("SlashHitTarget", model.Name)
	char:SetAttribute("SlashHitCount", (char:GetAttribute("SlashHitCount") or 0) + 1)
	char:SetAttribute("SlashHitAt", t) -- last: clients react to this one
	script:SetAttribute("SlashHits", (script:GetAttribute("SlashHits") or 0) + 1)
end)

-- refills, dash ends (speed burst), bleed ticks
RunService.Heartbeat:Connect(function()
	local t = now()
	for char, st in pairs(chars) do
		if st.refillAt and t >= st.refillAt then
			st.charges = math.min(maxCharges(char), st.charges + 1)
			if st.charges < maxCharges(char) then
				st.refillStart, st.refillAt = t, t + refillTime(char)
			else
				st.refillStart, st.refillAt = nil, nil
			end
			publish(char, st)
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if st.active and (t >= st.active.endAt or (hum and hum.Health <= 0)) then
			local endT = st.active.endAt
			local alive = hum and hum.Health > 0
			st.active = nil
			if alive then
				char:SetAttribute("SlashBurstMul", get(char, "SlashBurstMul"))
				char:SetAttribute("SlashBurstUntil", endT + get(char, "SlashBurstTime"))
			end
			char:SetAttribute("SlashEndedAt", t) -- last
		end
	end
	for model, b in pairs(bleeds) do
		if not model.Parent or model:GetAttribute("DummyState") == "ko" then
			bleeds[model] = nil
		else
			if t >= b.nextTick and b.nextTick <= b.untilT + 1e-3 then -- v1.1: the last tick (due at untilT) counts
				b.nextTick += b.tick
				if (tonumber(model:GetAttribute("EnergyShieldUntil")) or 0) <= t then
					local d = math.floor(b.dps * b.tick * 10 + 0.5) / 10
					local killed = takeHealth(model, d, b.by, b.byId, "bleed", t)
					local by = b.char
					if SKILLS and by and by.Parent then -- v1.3: credit the attacker
						by:SetAttribute("SlashBleedDealt", d)
						by:SetAttribute("SlashBleedDealtAt", t) -- last: SkillEffects reacts to this one
						local bst = chars[by]
						if killed and bst and by:GetAttribute("SlashKillRefill") == true then
							addCharges(by, bst, maxCharges(by))
							skillEvent(by, "killRefill")
						end
					end
					model:SetAttribute("SlashBleedTickDamage", d)
					model:SetAttribute("SlashBleedTickAt", t) -- last: SlashFX reacts to this one
					script:SetAttribute("SlashBleedTicks", (script:GetAttribute("SlashBleedTicks") or 0) + 1)
				end
			end
			if b.nextTick > b.untilT + 1e-3 then bleeds[model] = nil end -- v1.1: after the last tick
		end
	end
end)

-- v1.3: Blood Frenzy I (speed while a bleeding dino is near)
if SKILLS then
	task.spawn(function()
		while true do
			task.wait(FRENZY_STEP)
			local t = now()
			for char in pairs(chars) do
				local m = tonumber(char:GetAttribute("SlashFrenzyMul")) or 1
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local active = false
				if m ~= 1 and hrp and char.Parent then
					local range = (tonumber(char:GetAttribute("SlashFrenzyRange")) or FRENZY_RANGE) * char:GetScale()
					for model, b in pairs(bleeds) do
						if model ~= char and model.Parent and t <= b.untilT + 1e-3 and (rootOf(model) - hrp.Position).Magnitude <= range then
							active = true
							break
						end
					end
				end
				if active then char:SetAttribute("SlashFrenzyUntil", t + FRENZY_HOLD) end
				if char:GetAttribute("SlashFrenzyActive") ~= active then char:SetAttribute("SlashFrenzyActive", active) end
			end
		end
	end)
end

-- characters
local function onCharacter(char)
	task.defer(function()
		if char.Parent then track(char) end
	end)
	char:GetAttributeChangedSignal("SlashEnabled"):Connect(function() track(char) end)
end
local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
