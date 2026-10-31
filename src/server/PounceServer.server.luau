-- PounceServer v1.11 (Dino Arcade) — TEST. Validates raptor pounces, latches the raptor onto a larger dino and
-- deals the latch damage.
-- Client -> server (sent by PounceTest 1.0):
--   DinoPounceRequest:FireServer(clientServerTime)              at the key press
--   DinoPounceClaim:FireServer(stamp, hitboxPart, offset)       when the lunge touches a target hitbox;
--                                                               offset = latch CFrame relative to hitboxPart
--   DinoPounceRelease:FireServer()                              jump key while latched (leap off)
-- Request checks, in order: "badArg", "dead", "disabled" (PounceEnabled ~= true), "latched" (already on),
--   "exhausted", "stamina" (stamina < PounceStaminaCost, StaminaEnabled ~= false), "cooldown"
--   (PounceCooldown since the last accepted pounce) -> "ok": PounceStartedAt = stamp clamped to
--   [now - MAX_LAG, now] (replicates; StaminaServer 1.2 charges PounceStaminaCost for each new value).
--   Denied: PounceDeniedAt = the client stamp, PounceDenyReason.
-- Claim checks: "badArg", "noPounce" (stamp is not the pending pounce), "late" (more than PounceClaimWindow s after
--   the start), "badTarget" (part is not in the "Hitboxes" folder of a Workspace model with Bitable = true and a
--   Species attribute, or that model is knocked out, or it is the raptor itself), "busy" (v1.1: already pinned),
--   "far" (part more than CLAIM_TOLERANCE studs from the raptor's body as
--   the server sees it), "badOffset" (offset farther than OFFSET_MAX studs from the part) -> "ok".
-- Latched (replicated, read by PounceTest and IdleAnimation 1.16 on every client):
--   ObjectValue "PounceLatchPart" (child of the character) = the hitbox part, attribute PounceLatchOffset (CFrame
--   relative to that part), PounceLatched = true, PounceLatchedAt (server time), PounceLatchTarget (model name),
--   PounceLatchSegment (HitboxSegment of the part).
-- Damage (target DummyHealth, BiteTargetHealth): PounceLandDamage (8) at the latch, then PounceTickDamage (4) every
--   PounceTickInterval (0.5 s) while latched; each x the target's DebuffDamageTakenMul while DebuffUntil is in the
--   future (roar debuff), rounded. No hit-zone multiplier. Each hit sets PounceBiteAt (server time; chomp pose)
--   and PounceHitDamage.
-- Release (PounceLatched = false, PounceReleasedAt, PounceReleaseReason): "jump" (release request), "stamina"
--   (stamina reached 0; StaminaServer 1.2 drains PounceLatchDrain per second while latched), "ko" (target knocked
--   out), "gone" (target or part removed), "dead", "disabled", "timeout" (MAX_LATCH s safety).
-- v1.1: pin. A claim on a dino SMALLER than PounceSizeRatio x the raptor's size (same size or smaller, e.g. the display
--   raptor) pins it instead of latching: PounceMode = "pin" (latch: "latch"), PounceLatchPart = the target's
--   HumanoidRootPart (PounceTest stands the raptor on top of it), and the target gets PinnedAt (server time) +
--   PinnedBy (raptor name); WalkTest 1.5 stops its walk and rolls it onto its side. A target that is already pinned
--   is refused ("busy"). Damage, ticks and stamina drain are the same as a latch. A pin ends only on "jump" or
--   "stamina" (and the safety reasons "gone" / "dead" / "disabled" / "timeout"), not on the target's KO. On release
--   the target's PinnedAt / PinnedBy are cleared and PinReleasedAt (server time) is set (WalkTest: it gets up).
--   The "small" claim result is no longer used.
-- v1.2: shake-off (ShakeOffServer 1.0). A latch is released with the raptor's ShakeOffReason ("water" / "rammed") when
--   its ShakeOffAt (server time) is at or after the latch start. A pounce request while StunnedUntil (server time,
--   set by a ram) is in the future is denied ("stunned").
-- v1.3: killing blow (for KillRegenServer 1.0). When a landing or tick hit takes a target's DummyHealth from above 0
--   to 0, the target gets KilledBy (raptor character name = player name), KilledByUserId, KilledWith = "pounce" and,
--   last, KilledAt (server time). Damage is unchanged.
-- v1.4: claim distances scale with the raptor (user: "its not pouncing consistently ... other wise it dismounts me").
--   RaptorScale 1.0 (2x raptors) doubled the body and the lunge (PounceDistance 40 -> 140 studs/s) but CLAIM_TOLERANCE
--   / OFFSET_MAX stayed at scale-1 values: a tail contact on a still target measured 17.8 studs, a target running
--   at 33.8 studs/s gave 24.1 (behind) / 26.8 (head-on) -> "far" -> PounceTest let go ("rejected") 0.6 s later.
--   Now "far" uses CLAIM_TOLERANCE x the raptor's Model:GetScale() and "badOffset" uses OFFSET_MAX x the same factor
--   (factor never below 1). Script attribute PounceScaleClaimEnabled (default true; false = the 1.3 constants).
--   Diagnostics: script PounceServerVersion; raptor PounceClaimTolerance (studs used for the last claim).
-- v1.5: Cloak Field ambush bonus (MDA-51, plan CLOAK_v1.0 Task 3). CloakServer 1.0 sets the raptor's CloakPounceArmed
--   to the PounceStartedAt of a pounce started while cloaked. When the claim of that same pounce succeeds, the landing
--   hit's multiplier is 1 + (CloakPounceMul - 1) + (DebuffDamageTakenMul - 1 while the roar debuff is on), additive;
--   CloakPounceArmed is then cleared. Ticks are unchanged. Script attribute PounceCloakBonusEnabled (default true;
--   false = no bonus). Diagnostics: raptor PounceCloakBonus (the added part used for the last landing, 0 = none).
-- v1.6: Blade Claws (raptor parts batch 1, MDA-60, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 3; SkillEffects 1.6
--   writes the raptor's Blade* attributes). While script attribute PounceBladeEnabled ~= false:
--   * landing hit: + BladeLandBonus (0 / 0.35), added like the cloak bonus (1 + cloak + blade + debuff - 1, additive);
--     diagnostic PounceBladeBonus (the part used for the last landing).
--   * latch / pin bite interval = PounceTickInterval x BladeTickMul (1 / 0.74; clamped 0.2 .. 1), first tick included.
--   * pin kill: when a landing or tick hit of a "pin" takes the target's DummyHealth from above 0 to 0 and
--     BladePinRefund > 0, the raptor gets StaminaRefundAmount = BladePinRefund x PounceStaminaCost, then
--     StaminaRefundAt = now (StaminaServer 1.5 adds it); diagnostic PounceBladeRefunds (count).
-- v1.7: slash timing (Kepu 2026-10-29: "we need to see visible slashing with the arm claws" ... "the slashes need to be
--   animated and show some wind up ... and be accurate to the damage taken. I can't have 2 slashes only but then -4 health
--   appears in between all those slashes"; mockup docs/mockups/hud_target_slash_options.html "Claw slashes only"). While
--   script attribute PounceSlashTimingEnabled ~= false the raptor also gets:
--   * PounceHitCount: 0 at each latch / pin start, + 1 on every hit (landing = 1), set before PounceBiteAt, so a client
--     reading PounceBiteAt sees the matching count. Clients (IdleAnimation 1.28 / PounceSlash 1.0, PounceFX 1.1) slash
--     with the left arm on odd counts and the right arm on even counts: one slash per hit, never more or fewer.
--   * PounceNextHitAt (server time of the next tick hit): set at the latch start (= now + the tick interval) and after
--     every tick; the next arm winds up so it is cocked by then and strikes when the hit arrives.
--   Damage, timing and release rules are unchanged.
-- v1.8 (PvP pin, Kepu 2026-10-30: "When I pounce it makes you hang on the other raptor" -> "Pinned down, no escape"; "The counters for Pounce is to shield and use adrenaline mid pounce" -> only Shield + Adrenaline while pinned): a pin's
--   target that is a player's character was held by nothing (bots stop and roll over by reading PinnedBy; a player kept
--   full control), so the pouncer rode a running raptor. While script attribute PouncePinHoldEnabled ~= false, a pin on
--   a player also sets the target's PinHeld = true (cleared with PinnedBy on release): StunClient 1.3 lays it on its
--   side and holds it still (no move, turn or leap); this script refuses its pounce requests ("pinned", checked after
--   "stunned"); JumpServer 1.1, MechaServer 1.5 (Thrusters), CloakServer 1.7, ScreechServer 1.6, MineServer 1.6 and
--   ScentServer 1.2 refuse theirs ("pinned"). Energy Shield and Adrenaline still work (the counters); Adrenaline does
--   not end the pin. No escape: the pin still ends only on the pouncer's leap ("jump"), stamina 0 or the safety
--   reasons. Damage is unchanged. Diagnostics: raptor PouncePinPlayer (true while pinning a player).
-- Settings (raptor attributes): PounceEnabled (default false), PounceStaminaCost 15, PounceCooldown 3,
--   PounceClaimWindow 0.9, PounceSizeRatio 1.5, PounceLandDamage 8, PounceTickDamage 4, PounceTickInterval 0.5.
-- Diagnostics (raptor attributes): PounceServerResult, PounceClaimResult, PounceCount, PounceLatchCount,
--   PounceDamageTotal (this latch), PounceClaimDist.
-- v1.9 (pachy Bone Crest, SkillTree 1.30; Kepu 2026-10-30 + Thick Hide vs players): every landing / tick hit d =
--   round(d x BoneCrest.defense(target) x mul), mul = BoneCrest.factor(target, raptor root position) (a raptor latched on
--   the front of a pachy with Bone Crest: 0.80 / 0.70 / 0.60); a reduced hit calls BoneCrest.after (CLANK, star reflect at
--   most once per 0.4 s). Raptor diagnostics PounceHitCrestMul, PounceHitDefenseMul. Switch: script attribute
--   PounceCrestEnabled (default true, read each hit; false = 1.8 damage).
-- v1.10 (pachy Dome Visor, MDA-127; BoneCrest 1.2): a claim on a dino whose visor is up, with the raptor in front
--   (BoneCrest.visorFront with the raptor's root position), is refused: PounceClaimResult "visor" (no latch, no pin, no
--   damage) and BoneCrest.visorBlock(target, raptor, "pounce") runs (BLOCK look; star knockback). Latch ticks already
--   do 0 through BoneCrest.factor while the visor faces the raptor. Switch: script attribute PounceVisorEnabled
--   (default true, read each claim; false = 1.9).
-- v1.11 (Kepu 2026-10-30: "a pachy headbutt beats a raptor pounce if they're both going head on" -> "Both rules"):
--   * charge blocks a front pounce: a claim on a dino whose headbutt charge is running (HeadbuttStartedAt, until
--     HeadbuttWindup + HeadbuttMaxTime + 0.5 s, no HeadbuttEndedAt / HeadbuttHitAt since; player pachies (HeadbuttServer)
--     and pachy bots (BotServer 1.19) both stamp these) with the raptor's root inside the target's front cone
--     (BoneCrest.CONE, 60 degrees) is refused: PounceClaimResult "charging" (no latch, no pin, no damage; the pachy's own
--     headbutt hits the raptor).
--   * a headbutt cancels the pounce: a claim from a raptor whose HeadbuttShoveAt (set by a pachy headbutt hit that was
--     not blocked by its Energy Shield) is at or after its pounce start is refused: "headbutted"; the pending pounce is
--     dropped. PounceTest 1.6 ends the leap on the client when the shove lands.
--   Diagnostics: raptor PounceHeadbuttCancels; target PounceChargeBlocks. Switches (script, read each claim):
--   PounceChargeBlockEnabled, PounceHeadbuttCancelEnabled (default true; false = 1.10).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local crestMod -- v1.9: Bone Crest / Thick Hide vs players (ServerStorage.DinoArcade.BoneCrest), loaded on first hit
local function crest()
	if crestMod == nil then
		crestMod = false
		pcall(function() crestMod = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end)
	end
	return crestMod or nil
end

local DEFAULTS = {PounceEnabled = false, PounceStaminaCost = 15, PounceCooldown = 3, PounceClaimWindow = 0.9,
	PounceSizeRatio = 1.5, PounceLandDamage = 8, PounceTickDamage = 4, PounceTickInterval = 0.5,
	StaminaEnabled = true, StaminaMax = 100}
local MAX_LAG = 0.3         -- seconds a client stamp may lag behind the server clock
local CLAIM_TOLERANCE = 24  -- studs between the claimed part and the raptor body (the server sees a 70 studs/s lunge
                            -- late and targets in rest pose; 14 rejected a latch on a walking T-Rex at 15.1)
local OFFSET_MAX = 8        -- studs the latch spot may sit from the part's centre beyond its half size
local MAX_LATCH = 30        -- safety: seconds a latch may last

script:SetAttribute("PounceServerVersion", "1.11")
if script:GetAttribute("PounceChargeBlockEnabled") == nil then script:SetAttribute("PounceChargeBlockEnabled", true) end -- v1.11
if script:GetAttribute("PounceHeadbuttCancelEnabled") == nil then script:SetAttribute("PounceHeadbuttCancelEnabled", true) end -- v1.11
if script:GetAttribute("PounceVisorEnabled") == nil then script:SetAttribute("PounceVisorEnabled", true) end -- v1.10
if script:GetAttribute("PouncePinHoldEnabled") == nil then script:SetAttribute("PouncePinHoldEnabled", true) end -- v1.8
if script:GetAttribute("PounceSlashTimingEnabled") == nil then script:SetAttribute("PounceSlashTimingEnabled", true) end -- v1.7
local function slashTiming() return script:GetAttribute("PounceSlashTimingEnabled") ~= false end
if script:GetAttribute("PounceCloakBonusEnabled") == nil then script:SetAttribute("PounceCloakBonusEnabled", true) end -- v1.5
if script:GetAttribute("PounceBladeEnabled") == nil then script:SetAttribute("PounceBladeEnabled", true) end -- v1.6
if script:GetAttribute("PounceScaleClaimEnabled") == nil then script:SetAttribute("PounceScaleClaimEnabled", true) end -- v1.4

-- v1.4: claim distances grow with the raptor's model scale (RaptorScale / growth); 1 when off or smaller
local function claimScale(char)
	if script:GetAttribute("PounceScaleClaimEnabled") ~= true then return 1 end
	return math.max(1, char:GetScale())
end

local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local requestRemote = remote("DinoPounceRequest")
local claimRemote = remote("DinoPounceClaim")
local releaseRemote = remote("DinoPounceRelease")

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

local function stamina(char, now)
	local max = get(char, "StaminaMax")
	local value = char:GetAttribute("StaminaValue") or max
	local rate = char:GetAttribute("StaminaRate") or 0
	local at = char:GetAttribute("StaminaAt") or now
	return math.clamp(value + rate * (now - at), 0, max)
end

local function alive(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- the latchable model a hitbox part belongs to (nil if none)
local function targetOf(part)
	local folder = part.Parent
	if not (folder and folder.Name == "Hitboxes") then return nil end
	local model = folder.Parent
	if not (model and model:IsA("Model") and model:IsDescendantOf(workspace)) then return nil end
	if model:GetAttribute("Bitable") ~= true or model:GetAttribute("Species") == nil then return nil end
	return model
end

local function sizeOf(model)
	return model:GetExtentsSize().Magnitude
end

local function closestPoint(part, p)
	local lp = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return part.CFrame * Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
end

local pending = {}   -- [char] = {stamp, start}
local latches = {}   -- [char] = {model, part, nextTick, at, mode}
local lastAccepted = setmetatable({}, {__mode = "k"})

local function latchValue(char)
	local v = char:FindFirstChild("PounceLatchPart")
	if not v then
		v = Instance.new("ObjectValue")
		v.Name = "PounceLatchPart"
		v.Parent = char
	end
	return v
end

-- v1.6: Blade Claws numbers (neutral when the switch is off)
local function bladeOn() return script:GetAttribute("PounceBladeEnabled") ~= false end
local function tickInterval(char)
	local mul = 1
	if bladeOn() then mul = math.clamp(tonumber(char:GetAttribute("BladeTickMul")) or 1, 0.2, 1) end
	return get(char, "PounceTickInterval") * mul
end

local function hit(char, model, dmg, now, extra)
	local mul = 1
	local untilT, dmul = model:GetAttribute("DebuffUntil"), model:GetAttribute("DebuffDamageTakenMul")
	if typeof(untilT) == "number" and typeof(dmul) == "number" and now < untilT then mul = dmul end
	mul += extra or 0 -- v1.5: cloak ambush bonus, added to the debuff (not multiplied)
	local d = math.floor(dmg * mul + 0.5)
	local rawD, crestMul, crestFront, defMul = d, 1, false, 1 -- v1.9
	local BC = script:GetAttribute("PounceCrestEnabled") ~= false and crest()
	if BC then
		local aRoot = char:FindFirstChild("HumanoidRootPart")
		defMul = BC.defense(model)
		crestMul, crestFront = BC.factor(model, aRoot and aRoot.Position)
		d = math.floor(d * defMul * crestMul + 0.5)
	end
	char:SetAttribute("PounceHitCrestMul", crestMul)
	char:SetAttribute("PounceHitDefenseMul", defMul)
	local hp = model:GetAttribute("DummyHealth")
	if typeof(hp) == "number" then model:SetAttribute("DummyHealth", math.max(0, hp - d)) end
	if typeof(hp) == "number" and hp > 0 and hp - d <= 0 then -- v1.3: killing blow
		local killer = Players:GetPlayerFromCharacter(char)
		model:SetAttribute("KilledBy", char.Name)
		model:SetAttribute("KilledByUserId", killer and killer.UserId or 0)
		model:SetAttribute("KilledWith", "pounce")
		model:SetAttribute("KilledAt", now) -- last: KillRegenServer reacts to this one
		local l = latches[char] -- v1.6: Blade Claws star, pin kill refund
		local refund = bladeOn() and (tonumber(char:GetAttribute("BladePinRefund")) or 0) or 0
		if l and l.mode == "pin" and l.model == model and refund > 0 then
			char:SetAttribute("StaminaRefundAmount", refund * get(char, "PounceStaminaCost"))
			char:SetAttribute("StaminaRefundAt", now) -- last: StaminaServer reacts to this one
			char:SetAttribute("PounceBladeRefunds", (char:GetAttribute("PounceBladeRefunds") or 0) + 1)
		end
	end
	char:SetAttribute("PounceHitDamage", d)
	char:SetAttribute("PounceDamageTotal", (char:GetAttribute("PounceDamageTotal") or 0) + d)
	if slashTiming() then char:SetAttribute("PounceHitCount", (char:GetAttribute("PounceHitCount") or 0) + 1) end -- v1.7
	char:SetAttribute("PounceBiteAt", now)
	if BC and crestFront and crestMul < 1 then BC.after(model, char, math.floor(rawD * defMul + 0.5), d, "pounce") end -- v1.9
end

local function release(char, reason)
	local l = latches[char]
	if not l then return end
	latches[char] = nil
	if l.mode == "pin" and l.model and l.model:GetAttribute("PinnedBy") == char.Name then -- v1.1
		l.model:SetAttribute("PinnedAt", nil)
		l.model:SetAttribute("PinnedBy", nil)
		l.model:SetAttribute("PinReleasedAt", workspace:GetServerTimeNow())
	end
	if l.pinHold then -- v1.8: the pinned player can move again
		if l.model then l.model:SetAttribute("PinHeld", nil) end
		char:SetAttribute("PouncePinPlayer", false)
	end
	local v = char:FindFirstChild("PounceLatchPart")
	if v then v.Value = nil end
	char:SetAttribute("PounceLatched", false)
	char:SetAttribute("PounceReleasedAt", workspace:GetServerTimeNow())
	char:SetAttribute("PounceReleaseReason", reason)
end

-- v1.11: a headbutt charge running on model, with pos inside its front cone
local function chargingFront(model, pos, now)
	local s = model:GetAttribute("HeadbuttStartedAt")
	if typeof(s) ~= "number" or now < s - 0.05 then return false end
	local windup = tonumber(model:GetAttribute("HeadbuttWindup")) or 0.15
	local maxT = tonumber(model:GetAttribute("HeadbuttMaxTime")) or 1.8
	if now > s + windup + maxT + 0.5 then return false end
	local e, h = model:GetAttribute("HeadbuttEndedAt"), model:GetAttribute("HeadbuttHitAt")
	if typeof(e) == "number" and e >= s - 0.001 then return false end
	if typeof(h) == "number" and h >= s - 0.001 then return false end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or typeof(pos) ~= "Vector3" then return false end
	local d = pos - root.Position
	d = Vector3.new(d.X, 0, d.Z)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 1e-3 then return false end
	local cone = (crest() and tonumber(crest().CONE)) or 60
	return d.Magnitude < 1e-3 or look.Unit:Dot(d.Unit) >= math.cos(math.rad(cone))
end

requestRemote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not alive(char) then
		result = "dead"
	elseif get(char, "PounceEnabled") ~= true then
		result = "disabled"
	elseif latches[char] then
		result = "latched"
	elseif (char:GetAttribute("StunnedUntil") or 0) > now then -- v1.2
		result = "stunned"
	elseif char:GetAttribute("PinHeld") == true then -- v1.8: pinned by another player
		result = "pinned"
	elseif char:GetAttribute("Exhausted") == true then
		result = "exhausted"
	elseif get(char, "StaminaEnabled") ~= false and stamina(char, now) < get(char, "PounceStaminaCost") then
		result = "stamina"
	elseif lastAccepted[char] and now - lastAccepted[char] < get(char, "PounceCooldown") then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("PounceServerResult", result)
	if result == "ok" then
		lastAccepted[char] = now
		local start = math.clamp(stamp, now - MAX_LAG, now)
		pending[char] = {stamp = stamp, start = start}
		char:SetAttribute("PounceCount", (char:GetAttribute("PounceCount") or 0) + 1)
		char:SetAttribute("PounceStartedAt", start)
	elseif result ~= "badArg" then
		char:SetAttribute("PounceDenyReason", result)
		char:SetAttribute("PounceDeniedAt", stamp)
	end
end)

claimRemote.OnServerEvent:Connect(function(player, stamp, part, offset)
	local char = player.Character
	if not char then return end
	local now = workspace:GetServerTimeNow()
	local p = pending[char]
	local result, model
	if typeof(stamp) ~= "number" or typeof(part) ~= "Instance" or not part:IsA("BasePart") or typeof(offset) ~= "CFrame" then
		result = "badArg"
	elseif not p or p.stamp ~= stamp then
		result = "noPounce"
	elseif now - p.start > get(char, "PounceClaimWindow") then
		result = "late"
	elseif script:GetAttribute("PounceHeadbuttCancelEnabled") ~= false and typeof(char:GetAttribute("HeadbuttShoveAt")) == "number"
		and char:GetAttribute("HeadbuttShoveAt") >= p.start - 0.001 then
		result = "headbutted" -- v1.11: knocked out of the pounce
		pending[char] = nil
		char:SetAttribute("PounceHeadbuttCancels", (char:GetAttribute("PounceHeadbuttCancels") or 0) + 1)
	else
		model = targetOf(part)
		if not model or model == char or model:GetAttribute("DummyState") == "ko" then
			result = "badTarget"
		elseif model:GetAttribute("PinnedAt") ~= nil then -- v1.1: already pinned
			result = "busy"
		else
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local dist = hrp and (closestPoint(part, hrp.Position) - hrp.Position).Magnitude or math.huge
			local k = claimScale(char) -- v1.4
			char:SetAttribute("PounceClaimDist", math.floor(dist * 10 + 0.5) / 10)
			char:SetAttribute("PounceClaimTolerance", math.floor(CLAIM_TOLERANCE * k * 10 + 0.5) / 10)
			if dist > CLAIM_TOLERANCE * k then
				result = "far"
			elseif offset.Position.Magnitude > part.Size.Magnitude / 2 + OFFSET_MAX * k then
				result = "badOffset"
			elseif not alive(char) then
				result = "dead"
			elseif script:GetAttribute("PounceVisorEnabled") ~= false and crest() and hrp and crest().visorFront(model, hrp.Position) then
				result = "visor" -- v1.10: Dome Visor
			elseif script:GetAttribute("PounceChargeBlockEnabled") ~= false and hrp and chargingFront(model, hrp.Position, now) then
				result = "charging" -- v1.11: head-on into a headbutt charge
				model:SetAttribute("PounceChargeBlocks", (model:GetAttribute("PounceChargeBlocks") or 0) + 1)
			else
				result = "ok"
			end
		end
	end
	char:SetAttribute("PounceClaimResult", result)
	if result == "visor" then crest().visorBlock(model, char, "pounce") end -- v1.10
	if result ~= "ok" then return end
	pending[char] = nil
	-- v1.1: latch onto larger dinos, pin same-size or smaller ones
	local mode = sizeOf(model) >= sizeOf(char) * get(char, "PounceSizeRatio") and "latch" or "pin"
	if mode == "pin" then
		part = model:FindFirstChild("HumanoidRootPart") or part
		model:SetAttribute("PinnedBy", char.Name)
		model:SetAttribute("PinnedAt", now)
	end
	char:SetAttribute("PounceMode", mode)
	latches[char] = {model = model, part = part, at = now, nextTick = now + tickInterval(char), mode = mode} -- v1.6: tickInterval
	if mode == "pin" and Players:GetPlayerFromCharacter(model) and script:GetAttribute("PouncePinHoldEnabled") ~= false then
		latches[char].pinHold = true -- v1.8: hold a pinned player down
		model:SetAttribute("PinHeld", true)
		char:SetAttribute("PouncePinPlayer", true)
	end
	latchValue(char).Value = part
	char:SetAttribute("PounceLatchOffset", offset)
	char:SetAttribute("PounceLatchTarget", model.Name)
	char:SetAttribute("PounceLatchSegment", part:GetAttribute("HitboxSegment"))
	char:SetAttribute("PounceDamageTotal", 0)
	if slashTiming() then -- v1.7
		char:SetAttribute("PounceHitCount", 0)
		char:SetAttribute("PounceNextHitAt", latches[char].nextTick)
	end
	char:SetAttribute("PounceLatchedAt", now)
	char:SetAttribute("PounceLatchCount", (char:GetAttribute("PounceLatchCount") or 0) + 1)
	char:SetAttribute("PounceLatched", true) -- last: clients read the rest from here
	-- v1.5: this pounce began under the cloak -> landing bonus once
	local extra = 0
	local armed = char:GetAttribute("CloakPounceArmed")
	if typeof(armed) == "number" and math.abs(armed - p.start) < 1e-4 then
		if script:GetAttribute("PounceCloakBonusEnabled") ~= false then
			extra = math.max(0, (tonumber(char:GetAttribute("CloakPounceMul")) or 1) - 1)
		end
		char:SetAttribute("CloakPounceArmed", nil)
	end
	char:SetAttribute("PounceCloakBonus", extra)
	local blade = bladeOn() and math.max(0, tonumber(char:GetAttribute("BladeLandBonus")) or 0) or 0 -- v1.6
	char:SetAttribute("PounceBladeBonus", blade)
	hit(char, model, get(char, "PounceLandDamage"), now, extra + blade)
end)

releaseRemote.OnServerEvent:Connect(function(player)
	local char = player.Character
	if char then release(char, "jump") end
end)

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for char, l in pairs(latches) do
		if not char.Parent or not alive(char) then
			release(char, "dead")
		elseif get(char, "PounceEnabled") ~= true then
			release(char, "disabled")
		elseif not l.part.Parent or not l.model:IsDescendantOf(workspace) then
			release(char, "gone")
		elseif typeof(char:GetAttribute("ShakeOffAt")) == "number" and char:GetAttribute("ShakeOffAt") >= l.at then -- v1.2
			release(char, char:GetAttribute("ShakeOffReason") or "shaken")
		elseif l.mode ~= "pin" and (l.model:GetAttribute("DummyState") == "ko" or (l.model:GetAttribute("DummyHealth") or 1) <= 0) then
			release(char, "ko") -- v1.1: latches only; a pin holds through the target's KO
		elseif get(char, "StaminaEnabled") ~= false and stamina(char, now) <= 0 then
			release(char, "stamina")
		elseif now - l.at > MAX_LATCH then
			release(char, "timeout")
		elseif now >= l.nextTick then
			l.nextTick += tickInterval(char) -- v1.6 (was PounceTickInterval)
			if slashTiming() then char:SetAttribute("PounceNextHitAt", l.nextTick) end -- v1.7: before the hit
			hit(char, l.model, get(char, "PounceTickDamage"), now)
		end
	end
	for char, p in pairs(pending) do
		if not char.Parent or now - p.start > get(char, "PounceClaimWindow") + 0.5 then pending[char] = nil end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		release(player.Character, "gone") -- v1.1: also frees a pinned target
		pending[player.Character] = nil
	end
end)
