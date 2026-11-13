-- JumpServer v1.6 (Dino Arcade) — TEST. Validates leap requests and stamps the start time for every client.
-- Client -> server: ReplicatedStorage.DinoJumpRequest:FireServer(clientServerTime) (sent by JumpTest 1.0 at the
--   key press, i.e. the start of the crouch).
-- Start time = the client's stamp clamped to [now - MAX_LAG, now], written to the character attribute
--   JumpStartedAt (replicates; IdleAnimation 1.15 / JumpPose 1.0 draw the crouch from it, StaminaServer 1.1
--   charges JumpStaminaCost for each new value).
-- Checks, in order (first failing one is the result):
--   "badArg"    stamp is not a number
--   "dead"      no character / Humanoid health <= 0
--   "disabled"  JumpEnabled ~= true (default false: only species that turn it on, e.g. Raptor, can leap)
--   "exhausted" Exhausted == true (StaminaServer)
--   "stamina"   current stamina < JumpStaminaCost (StaminaEnabled ~= false only)
--   "cooldown"  less than JumpCooldown seconds since the last accepted leap
--   accepted -> "ok"
-- Denied: JumpDeniedAt = the client stamp (unclamped, so JumpTest can match it) + JumpDenyReason; JumpTest
--   cancels the launch if this arrives during the crouch.
-- Physics (launch height, forward boost, air speed) is done by the owner's client (network owner); the server
--   only gates the request and its stamina cost.
-- Settings (character attributes): JumpEnabled (default false), JumpStaminaCost (15), JumpCooldown (0.5).
-- Diagnostics (character attributes): JumpServerResult (last result above), JumpCount (accepted leaps),
--   JumpDenyCount, JumpDeniedAt, JumpDenyReason.
-- v1.1 (PvP pin, Kepu 2026-10-30: "When I pounce it makes you hang on the other raptor" -> "Pinned down, no escape"; "The counters for Pounce is to shield and use adrenaline mid pounce" -> only Shield + Adrenaline while pinned): "pinned"
--   (character PinHeld == true, set by PounceServer 1.8 while another player pins you) is refused, checked after
--   "disabled". Script attribute JumpPinnedBlockEnabled (default true; false = 1.0). Diagnostic: JumpServerVersion.
-- v1.2 (pachy Mecha Legs star, MDA-123): remote DinoJumpDoubleRequest(stamp) (JumpTest 1.1, a press in mid-air). Checks:
--   "badArg", "dead", "disabled" (JumpDoubleEnabled ~= true, SkillEffects 1.15), "pinned", "noLeap" (no accepted leap in
--   the last DOUBLE_WINDOW s), "used" (a double jump already since that leap) -> "ok": JumpDoubleAt (server time, the
--   stamp clamped like a leap), JumpDoubleCount. It is part of the same leap: no cooldown or stamina check of its own
--   (one shared cooldown). Result in JumpDoubleResult. Switch: script attribute JumpDoubleServerEnabled (default true).
-- v1.3 (leap charges, Kepu 2026-11-02: the teno's Hydraulic Leap fires through JUMP with "2 charges"; SkillEffects 1.37):
--   while the character attribute JumpCharges is >= 1 the leap uses charges instead of the plain cooldown: a leap is
--   accepted when a charge is left (and at least CHARGE_GAP 0.5 s since the last accepted leap; else "cooldown"); each used
--   charge refills JumpCooldown s after the previous refill (one at a time, like the teno's slam / leap charges). Published
--   (replicated): JumpChargesLeft, JumpChargeRefillAt (server time of the next refill, 0 when full). JumpCharges 0 / missing
--   = the 1.2 cooldown rule. Switch: script attribute JumpChargesServerEnabled (default true, read at each request;
--   false = 1.2).
-- v1.4 (MDA-212, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 6, red-team item 4: "a do-nothing-unless-called hook"):
--   BindableEvent ServerStorage.JumpAddCharge (created here). :Fire(character) gives that character one leap charge back:
--   "ok" when the 1.3 charges are on for it (JumpCharges >= 1) and a charge is used (the furthest pending refill is dropped,
--   so later refills keep their times); "full" when every charge is left; "noCharges" (JumpCharges 0 / missing: the 1.2
--   cooldown rule); "disabled" (switch off); a non-Model argument is ignored. Never above the max. Only TheriAttackServer 1.1 (Flowing
--   Cuts star) fires it today; nothing changes for a dino it is not fired for. Switch: script attribute JumpAddChargeEnabled
--   (default true, read at each fire). Diagnostics: script JumpAddCharges (count of "ok"); character JumpAddChargeResult,
--   JumpAddChargeAt.
-- v1.5 (Troodon Flap & Glide, MDA-340, plan docs/plans/TROODON_FLAP_GLIDE_v1.0.md Task 1): the 1.2 double jump accepts up
--   to JumpAirJumps requests per accepted leap (character attribute; missing / below 1 = 1, the 1.2 rule for the pachy); the
--   one after the last is "used". Each "ok" stamps JumpDoubleAt / JumpDoubleCount as 1.2 and sets JumpAirJumpsUsed (count in
--   this leap). Only TroodonModelData 1.3 sets JumpAirJumps (2). Switch: script attribute JumpServerAirJumpsEnabled (default
--   true, read at each request; false = 1.4: one per leap).
-- v1.7 (Kepu 2026-11-12 18:06 "Dino's should be using all their abilities" + pick "Yes, add all 4": practice bots get Mecha Legs,
--   which fires through the leap): the leap request handler is named (onLeap, body unchanged) and a server-only BindableFunction
--   "BotMechaUse" (child) runs it for a practice bot: Invoke(model, "DinoJumpRequest", stamp) -> onLeap(BotProxy.of(model), stamp)
--   -> "ok" (the result is on the model as JumpServerResult, as for a player), "off", "badArg", "noHandler" or "botUnsupported"
--   (error kept in JumpServerBotMechaError). The bot's motion is PracticeKit 1.3's. Only models with PracticeBot = true.
--   Switch: script attribute JumpServerBotMechaEnabled (default true, read per call).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULTS = {JumpEnabled = false, JumpStaminaCost = 15, JumpCooldown = 0.5, StaminaEnabled = true,
	StaminaMax = 100}
script:SetAttribute("JumpServerVersion", "1.3") -- v1.1; v1.2; v1.3
script:SetAttribute("JumpServerVersion", "1.4") -- v1.4 JumpAddCharge hook
script:SetAttribute("JumpServerVersion", "1.5") -- v1.5 JumpAirJumps
script:SetAttribute("JumpServerVersion", "1.6") -- v1.6 no leaps while snared
script:SetAttribute("JumpServerVersion", "1.7") -- v1.7 bot entrance
-- v1.6 (MDA-356; Kepu 2026-11-08 "pachy headbutt when trapped by zino still works which defeats the purpose of throwing a trap" -> "No movement moves"): a leap (DinoJumpRequest) and an air jump / flap (DinoJumpDoubleRequest) are refused "snared" while the character's
--   TheriSnaredUntil (Snare Wires bola) or HookHeldUntil (Reaper Hook / Grappling Hook hold) is after now (the PinHeld pattern;
--   bites and attacks that stay in place still work; the Troodon's Feather Shed still breaks out). JumpTest 1.7 refuses them locally too. Switch: script
--   attribute JumpSnareBlockEnabled (default true, read at each request; false = 1.5). Diagnostic: script
--   JumpSnareRefusals (count).
if script:GetAttribute("JumpSnareBlockEnabled") == nil then script:SetAttribute("JumpSnareBlockEnabled", true) end -- v1.6
local function snareBlocked(char) -- v1.6: Snare Wires bola / Reaper Hook hold
	if script:GetAttribute("JumpSnareBlockEnabled") == false then return false end
	local t = workspace:GetServerTimeNow()
	local on = (tonumber(char:GetAttribute("TheriSnaredUntil")) or 0) > t or (tonumber(char:GetAttribute("HookHeldUntil")) or 0) > t
	if on then script:SetAttribute("JumpSnareRefusals", (script:GetAttribute("JumpSnareRefusals") or 0) + 1) end
	return on
end
if script:GetAttribute("JumpServerAirJumpsEnabled") == nil then script:SetAttribute("JumpServerAirJumpsEnabled", true) end -- v1.5
if script:GetAttribute("JumpPinnedBlockEnabled") == nil then script:SetAttribute("JumpPinnedBlockEnabled", true) end
local MAX_LAG = 0.3 -- seconds a client stamp may lag behind the server clock (same as BiteServer)

local remote = ReplicatedStorage:FindFirstChild("DinoJumpRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoJumpRequest"
	remote.Parent = ReplicatedStorage
end

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

-- stamina now, from StaminaServer's replicated curve (same formula as StaminaServer 1.0)
local function stamina(char, now)
	local max = get(char, "StaminaMax")
	local value = char:GetAttribute("StaminaValue") or max
	local rate = char:GetAttribute("StaminaRate") or 0
	local at = char:GetAttribute("StaminaAt") or now
	return math.clamp(value + rate * (now - at), 0, max)
end

local lastAccepted = {} -- character -> server time of the last accepted leap (weak keys)
setmetatable(lastAccepted, {__mode = "k"})

-- v1.3: leap charges ------------------------------------------------------------------------------------------------------
if script:GetAttribute("JumpChargesServerEnabled") == nil then script:SetAttribute("JumpChargesServerEnabled", true) end
local CHARGE_GAP = 0.5
local chargeState = setmetatable({}, {__mode = "k"}) -- character -> {max, left, refills = {server times}}
local function chargesOn(char)
	return script:GetAttribute("JumpChargesServerEnabled") ~= false and (tonumber(char:GetAttribute("JumpCharges")) or 0) >= 1
end
local function chargePublish(char, st)
	char:SetAttribute("JumpChargesLeft", st.left)
	char:SetAttribute("JumpChargeRefillAt", st.refills[1] or 0)
end
local function chargeStateOf(char)
	local mx = math.floor(tonumber(char:GetAttribute("JumpCharges")) or 0)
	local st = chargeState[char]
	if not st or st.max ~= mx then
		st = {max = mx, left = mx, refills = {}}
		chargeState[char] = st
		chargePublish(char, st)
	end
	return st
end
game:GetService("RunService").Heartbeat:Connect(function()
	local t
	for char, st in pairs(chargeState) do
		if char.Parent and st.refills[1] then
			t = t or workspace:GetServerTimeNow()
			if t >= st.refills[1] then
				table.remove(st.refills, 1)
				st.left = math.min(st.max, st.left + 1)
				chargePublish(char, st)
			end
		end
	end
end)

local function onLeap(player, stamp) -- v1.7: named so the bot entrance can call it (body unchanged)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	local result
	local hum = char:FindFirstChildOfClass("Humanoid")
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif get(char, "JumpEnabled") ~= true then
		result = "disabled"
	elseif char:GetAttribute("PinHeld") == true and script:GetAttribute("JumpPinnedBlockEnabled") ~= false then -- v1.1
		result = "pinned"
	elseif snareBlocked(char) then -- v1.6
		result = "snared"
	elseif char:GetAttribute("Exhausted") == true then
		result = "exhausted"
	elseif get(char, "StaminaEnabled") ~= false and stamina(char, now) < get(char, "JumpStaminaCost") then
		result = "stamina"
	elseif chargesOn(char) then -- v1.3
		local st = chargeStateOf(char)
		if st.left < 1 or (lastAccepted[char] and now - lastAccepted[char] < CHARGE_GAP) then result = "cooldown" else result = "ok" end
	elseif lastAccepted[char] and now - lastAccepted[char] < get(char, "JumpCooldown") then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("JumpServerResult", result)
	if result == "ok" then
		lastAccepted[char] = now
		if chargesOn(char) then -- v1.3: use a charge
			local st = chargeStateOf(char)
			st.left -= 1
			local last = st.refills[#st.refills]
			table.insert(st.refills, math.max(now, last or now) + math.max(0.5, tonumber(get(char, "JumpCooldown")) or 0.5))
			chargePublish(char, st)
		end
		char:SetAttribute("JumpCount", (char:GetAttribute("JumpCount") or 0) + 1)
		char:SetAttribute("JumpStartedAt", math.clamp(stamp, now - MAX_LAG, now))
	elseif result ~= "badArg" then
		char:SetAttribute("JumpDenyCount", (char:GetAttribute("JumpDenyCount") or 0) + 1)
		char:SetAttribute("JumpDenyReason", result)
		char:SetAttribute("JumpDeniedAt", stamp)
	end
end
remote.OnServerEvent:Connect(onLeap) -- v1.7

-- v1.2: Mecha Legs double jump (one per accepted leap)
local DOUBLE_WINDOW = 4
if script:GetAttribute("JumpDoubleServerEnabled") == nil then script:SetAttribute("JumpDoubleServerEnabled", true) end
local doubleRemote = ReplicatedStorage:FindFirstChild("DinoJumpDoubleRequest")
if not doubleRemote then
	doubleRemote = Instance.new("RemoteEvent")
	doubleRemote.Name = "DinoJumpDoubleRequest"
	doubleRemote.Parent = ReplicatedStorage
end
local doubleFor = setmetatable({}, {__mode = "k"}) -- character -> the leap time its double jump was used on
local airCount = setmetatable({}, {__mode = "k"}) -- v1.5: character -> air jumps accepted since doubleFor's leap
local function airLimit(char) -- v1.5
	if script:GetAttribute("JumpServerAirJumpsEnabled") == false then return 1 end
	return math.max(1, math.floor(tonumber(char:GetAttribute("JumpAirJumps")) or 1))
end
doubleRemote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	local hum = char:FindFirstChildOfClass("Humanoid")
	local leap = lastAccepted[char]
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif script:GetAttribute("JumpDoubleServerEnabled") == false or char:GetAttribute("JumpDoubleEnabled") ~= true then
		result = "disabled"
	elseif char:GetAttribute("PinHeld") == true then
		result = "pinned"
	elseif snareBlocked(char) then -- v1.6
		result = "snared"
	elseif not leap or now - leap > DOUBLE_WINDOW then
		result = "noLeap"
	elseif doubleFor[char] == leap and (airCount[char] or 1) >= airLimit(char) then -- v1.5: up to JumpAirJumps
		result = "used"
	else
		result = "ok"
	end
	char:SetAttribute("JumpDoubleResult", result)
	if result == "ok" then
		airCount[char] = (doubleFor[char] == leap and (airCount[char] or 1) or 0) + 1 -- v1.5
		char:SetAttribute("JumpAirJumpsUsed", airCount[char])
		doubleFor[char] = leap
		char:SetAttribute("JumpDoubleCount", (char:GetAttribute("JumpDoubleCount") or 0) + 1)
		char:SetAttribute("JumpDoubleAt", math.clamp(stamp, now - MAX_LAG, now))
	end
end)

-- v1.4: JumpAddCharge (see the header)
if script:GetAttribute("JumpAddChargeEnabled") == nil then script:SetAttribute("JumpAddChargeEnabled", true) end
script:SetAttribute("JumpAddCharges", 0)
do
	local SS = game:GetService("ServerStorage")
	local addEv = SS:FindFirstChild("JumpAddCharge")
	if not (addEv and addEv:IsA("BindableEvent")) then
		addEv = Instance.new("BindableEvent")
		addEv.Name = "JumpAddCharge"
		addEv.Parent = SS
	end
	addEv.Event:Connect(function(char)
		if typeof(char) ~= "Instance" or not char:IsA("Model") then return end
		local result
		if script:GetAttribute("JumpAddChargeEnabled") == false then
			result = "disabled"
		elseif not chargesOn(char) then
			result = "noCharges"
		else
			local st = chargeStateOf(char)
			if st.left >= st.max then
				result = "full"
			else
				st.left += 1
				table.remove(st.refills) -- the furthest pending refill
				chargePublish(char, st)
				script:SetAttribute("JumpAddCharges", (script:GetAttribute("JumpAddCharges") or 0) + 1)
				result = "ok"
			end
		end
		char:SetAttribute("JumpAddChargeResult", result)
		char:SetAttribute("JumpAddChargeAt", workspace:GetServerTimeNow())
	end)
end

-- v1.7: the bot entrance (see the header)
if script:GetAttribute("JumpServerBotMechaEnabled") == nil then script:SetAttribute("JumpServerBotMechaEnabled", true) end
do
	local proxyModule = game:GetService("ServerStorage"):WaitForChild("DinoArcade"):FindFirstChild("BotProxy")
	local BotProxy = proxyModule and require(proxyModule)
	local fn = script:FindFirstChild("BotMechaUse") or Instance.new("BindableFunction")
	fn.Name = "BotMechaUse"
	fn.OnInvoke = function(model, remoteName, stamp)
		if script:GetAttribute("JumpServerBotMechaEnabled") == false then return "off" end
		if not BotProxy or typeof(model) ~= "Instance" or model:GetAttribute("PracticeBot") ~= true or not model.Parent then return "badArg" end
		if remoteName ~= "DinoJumpRequest" then return "noHandler" end
		local ok, err = pcall(onLeap, BotProxy.of(model), stamp)
		if not ok then
			script:SetAttribute("JumpServerBotMechaError", tostring(err))
			return "botUnsupported"
		end
		return "ok"
	end
	fn.Parent = script
end
