-- SlashServer v1.1 (Mecha Dino Arena) — the Herrerasaurus' dash-through slash (server side). MDA-140, plan
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
-- Switch: script attribute SlashServerEnabled (default true, read at start; false = every request "disabled").
-- Diagnostics: script SlashServerVersion, SlashRequests, SlashHits, SlashBleedTicks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
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
	elseif char:GetAttribute("PinHeld") == true then
		result = "pinned"
	elseif st.active then
		result = "busy"
	elseif st.charges < 1 then
		result = "empty"
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
	st.active = {stamp = stamp, startAt = t, endAt = t + dashTime, from = from, to = to, hit = {}}
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
	end
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
	local d = math.floor(get(char, "SlashDamage") * mul + 0.5)
	takeHealth(model, d, char.Name, player.UserId, "slash", t)
	-- bleed (no stacking: one per target, restarted by a new hit)
	local shielded = (tonumber(model:GetAttribute("EnergyShieldUntil")) or 0) > t
	if shielded then
		model:SetAttribute("SlashBleedResult", "shielded")
	else
		local tick = math.max(0.1, get(char, "SlashBleedTick"))
		bleeds[model] = {untilT = t + get(char, "SlashBleedTime"), nextTick = t + tick, by = char.Name, byId = player.UserId,
			dps = get(char, "SlashBleedDps"), tick = tick}
		model:SetAttribute("SlashBleedUntil", bleeds[model].untilT)
		model:SetAttribute("SlashBleedBy", char.Name)
		model:SetAttribute("SlashBleedDps", bleeds[model].dps)
		model:SetAttribute("SlashBleedResult", "bleeding")
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
					takeHealth(model, d, b.by, b.byId, "bleed", t)
					model:SetAttribute("SlashBleedTickDamage", d)
					model:SetAttribute("SlashBleedTickAt", t) -- last: SlashFX reacts to this one
					script:SetAttribute("SlashBleedTicks", (script:GetAttribute("SlashBleedTicks") or 0) + 1)
				end
			end
			if b.nextTick > b.untilT + 1e-3 then bleeds[model] = nil end -- v1.1: after the last tick
		end
	end
end)

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
