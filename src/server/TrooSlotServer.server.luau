-- TrooSlotServer v1.1 (Mecha Dino Arena) — the Troodon's slot parts (server authority): Bloom Tank (passive), Bloom Burst,
-- Shield Dome, Sleep Dart, Sentry Pod. Plan docs/plans/TROODON_SLOTPARTS_v1.0.md T2 (MDA-379); mockup
-- docs/mockups/troodon_slotparts_v0.1.html (Kepu 2026-11-10 01:40 picks, 09:46 "Then build"); timings = the mockup's tracks.
-- Settings (character attributes, SkillEffects 1.58): TrooPartBloom* (Enabled, Radius, Time, End, EndHeal, EndSlow; bought, no
--   slot), TrooPartBurst* (Enabled, Range, Heal, Radius, Boost, Time, Cut, Cooldown), TrooPartDome* (Enabled, Range, Radius, Time,
--   Cooldown), TrooPartSleep* (Enabled, Range, Time, Cooldown, Split), TrooPartSentry* (Enabled, Range, Reach, Time, Damage, Rate,
--   Shots, Cooldown); buttons only while bought AND slotted. Studs are game studs.
-- Remotes (ReplicatedStorage, client -> server, sent by MechaButtons 1.45): DinoTrooBurstRequest(stamp, aimDir, aimPoint),
--   DinoTrooDomeRequest(stamp, aimDir, aimPoint), DinoTrooSleepRequest(stamp, aimDir), DinoTrooSentryRequest(stamp, aimDir,
--   aimPoint).
-- Checks (TrooMovesServer 1.11's check(), same order and results) -> character <Prefix>ServerResult (+ ResultAt), prefix
--   TrooPartBurst / Dome / Sleep / Sentry: "badArg", "dead", "disabled", "menu", "stunned", "pinned", "placing" (a Portal Rift
--   being placed), "dazed", "silenced", "cooldown"; else "ok" and <Prefix>ReadyAt = now + <Prefix>Cooldown (from the press).
--   A wind-up cut short (dead / stunned / dazed / pinned at the release) -> "cancelled" (the recharge stays). Bots never use
--   these. Targets / squad / ModeRules / damage (armor, shields, takenMul, kill stamps) = TrooMovesServer 1.11's rules.
-- * Bloom Tank (passive): while TrooPartBloomEnabled on a troodon, the character's TrooZoneRadius = TrooPartBloomRadius /
--   scale and TrooZoneTime = TrooPartBloomTime (TrooAttackServer 1.x and TrooFX 1.x read those for every zone); the model
--   values are saved first in TrooBloomBaseRadius / TrooBloomBaseTime and put back when it goes off. Star (TrooPartBloomEnd):
--   when each zone ends (its TrooZoneUntil), squadmates and you inside heal TrooPartBloomEndHeal (5) and enemies inside are
--   slowed (TrooZoneSlowMul) TrooPartBloomEndSlow (1.5) s more; stamps TrooBloomPulseCenter, TrooBloomPulseRadius, then
--   TrooBloomPulseAt (last, TrooSlotFX).
-- * Bloom Burst (wind-up TrooSlot_throwWindup 0.34 + flight TrooSlot_burstFly 0.45): a bud to the aim point (<=
--   TrooPartBurstRange); at the landing you and squadmates within TrooPartBurstRadius heal TrooPartBurstHeal and get
--   TrooBoostUntil / TrooBoostMul (1 + Boost) for TrooPartBurstTime s; enemies inside get TrooHealCutUntil / TrooHealCutMul
--   (1 - Cut). A health watcher on each of them adds the boost to / takes the cut from every heal that lands in the window,
--   whatever its source (rises above TrooSlot_healWatchMaxFrac x max are ignored: respawns / max-health changes). Stamps
--   TrooBurstFrom, TrooBurstTo, TrooBurstFlight, TrooBurstAt (press, last); TrooBurstLandAt (the burst).
-- * Shield Dome (wind-up 0.34 + TrooSlot_domeFly 0.45 + TrooSlot_domeOpen 0.2): a Ball part (Workspace.TrooDomes, tag
--   "TrooDome", CanCollide / CanQuery / CanTouch false, ForceField blue) on the ground at the aim point (<= TrooPartDomeRange),
--   grown to TrooPartDomeRadius x 2 in TrooSlot_domeGrow 0.35 s, TrooDomeUntil = open + TrooPartDomeTime. SapWallBlock 1.3
--   blocks every attack line / arc that enters it (from outside); you walk through it. Stamps TrooDomeFrom / To / Flight, then
--   TrooDomeAt; the troodon's TrooDomeUntil (HUD active).
-- * Sleep Dart (wind-up TrooSlot_sleepWindup 0.3): a straight dart from the head along the aim (flat) to the best enemy in
--   SHOT_ASSIST_DEG (45) within TrooPartSleepRange with a clear line (world + Sap Walls / domes); speed TrooSlot_sleepSpeed 150
--   studs/s. On arrival: the target's StunnedUntil = max(current, now + TrooPartSleepTime) (the game's one stun: every move
--   server, BotServer, StunClient already honour it), TrooSleepUntil / TrooSleepBy / TrooSleepAt; the first health drop wakes
--   it (StunnedUntil back to now if it is still the sleep's, TrooSleepUntil 0, TrooSleepWokeAt). Star (Split > 0): the
--   nearest other enemy within Split studs of the target sleeps too (TrooSlot_sleepSplitDelay 0.2 s later). Stamps on the
--   troodon TrooSleepAt (press); TrooSleepFrom, TrooSleepTo, TrooSleepFlight, TrooSleepTarget, then TrooSleepFireAt (the dart);
--   TrooSleepSplitFrom / To, then TrooSleepSplitAt.
-- * Sentry Pod (wind-up 0.34 + TrooSlot_sentryFly 0.5): a turret (Workspace.TrooSentries, the look's carried pieces from
--   TrooSlotLooks 1.0 x TrooSlot_sentryScale 7 x the body scale, legs out, barrel level) at the aim point (<=
--   TrooPartSentryRange); from open + TrooSlot_sentryFirstShot 0.5 s every TrooPartSentryRate s until open +
--   TrooPartSentryTime it turns to the nearest enemy within TrooPartSentryReach (flat) with a clear line and fires
--   TrooPartSentryShots pods (0.07 s apart, speed TrooSlot_sentryShotSpeed 220) of TrooPartSentryDamage each. Stamps on the
--   turret model TrooSentryShotFrom / To / Flight / Target, then TrooSentryShotAt; TrooSentryEndAt at the end. The troodon's
--   TrooSentryUntil (HUD active). Stops early if the troodon leaves.
-- Switches: script TrooSlotServerEnabled, TrooSlot_<id>Enabled (obloom / oburst / odome / osleep / osentry),
--   TrooSlotModeRulesEnabled, TrooSlotSquadEnabled, TrooSlotHealWatchEnabled, TrooSlotSleepWakeEnabled, TrooSlotArmorAllEnabled
--   (all default true). Studio-only: TrooSlotTestAllyName (a bot treated as a squadmate). Diagnostics (script): TrooSlotHits,
--   TrooSlotHeals, TrooSlotBoosts, TrooSlotCuts, TrooSlotSleeps, TrooSlotWakes, TrooSlotDomes, TrooSlotSentries,
--   TrooSlotSentryShots, TrooSlotBloomPulses, TrooSlotSquadSkips.
-- v1.1 (SkillTree 1.86 / SkillEffects 1.59, Kepu 2026-11-10 10:38 "The sentry only deals 20 total damage"): a Sentry Pod throw
--   deals at most TrooPartSentryTotal (20; 0 = no cap) in all, counted before armor on hits that land (a pod in flight holds
--   its share; a miss / block gives it back). The last pod is cut to what is left; once the 20 is dealt the turret folds away
--   (TrooSentryEndAt). Turret diagnostics: TrooSentryDealt, TrooSentryCap. Switch: script TrooSlotSentryCapEnabled (default
--   true; false = 1.0, no cap). Script diagnostic TrooSlotSentryCapped (turrets that hit the cap).
-- v1.2 (Bots v2, MDA-471, plan docs/plans/BOTS_V2_v1.0.md T7; Kepu 2026-11-11 20:39 "the damn bots don't even use their
--   attack buttons or their mecha"): a bot entrance. Every remote handler of this script is connected through botHook(remote)
--   (handler bodies unchanged), which also files it by the remote's name. Server-only BindableFunction "BotMechaUse" (child):
--   Invoke(model, remoteName, ...the remote's own arguments...) runs every handler filed for that remote, in order, with
--   ServerStorage.DinoArcade.BotProxy.of(model) as the player (the model is its Character; PracticeBot models only).
--   Returns "ok" (the handlers ran; their results land on the model as for a player), "off", "badArg", "noHandler" or
--   "botUnsupported" (a handler errored; script attribute TrooSlotServerBotMechaError keeps "<remote>: <error>").
--   Switch: script attribute TrooSlotServerBotMechaEnabled (default true, read per call).
local __botHandlers = {} -- v1.2: remote name -> handlers (see the header)
local function botHook(remote)
	return {Connect = function(_, fn)
		local list = __botHandlers[remote.Name] or {}
		__botHandlers[remote.Name] = list
		table.insert(list, fn)
		return remote.OnServerEvent:Connect(fn)
	end}
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.1"
local SHOT_ASSIST_DEG = 45
local CFG = {throwWindup = 0.34, burstFly = 0.45, domeFly = 0.45, domeOpen = 0.2, domeGrow = 0.35, domeShrink = 0.3,
	sleepWindup = 0.3, sleepSpeed = 150, sleepHitRadius = 3, sleepSplitDelay = 0.2,
	sentryFly = 0.5, sentryOpen = 0.15, sentryFirstShot = 0.5, sentryScale = 7, sentryShotSpeed = 220, sentryPair = 0.07,
	healWatchMaxFrac = 0.6}
local IDS = {"obloom", "oburst", "odome", "osleep", "osentry"}

script:SetAttribute("TrooSlotServerVersion", VERSION)
for _, k in ipairs({"TrooSlotHits", "TrooSlotHeals", "TrooSlotBoosts", "TrooSlotCuts", "TrooSlotSleeps", "TrooSlotWakes",
	"TrooSlotDomes", "TrooSlotSentries", "TrooSlotSentryShots", "TrooSlotBloomPulses", "TrooSlotSquadSkips", "TrooSlotSentryCapped"}) do script:SetAttribute(k, 0) end
for _, k in ipairs({"TrooSlotServerEnabled", "TrooSlotModeRulesEnabled", "TrooSlotSquadEnabled", "TrooSlotHealWatchEnabled",
	"TrooSlotSleepWakeEnabled", "TrooSlotArmorAllEnabled", "TrooSlotSentryCapEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
for _, id in ipairs(IDS) do
	if script:GetAttribute("TrooSlot_" .. id .. "Enabled") == nil then script:SetAttribute("TrooSlot_" .. id .. "Enabled", true) end
end
for k, v in pairs(CFG) do
	if script:GetAttribute("TrooSlot_" .. k) == nil then script:SetAttribute("TrooSlot_" .. k, v) end
end
local function cfg(k) return tonumber(script:GetAttribute("TrooSlot_" .. k)) or CFG[k] end
local function on(id)
	return script:GetAttribute("TrooSlotServerEnabled") ~= false and script:GetAttribute("TrooSlot_" .. id .. "Enabled") ~= false
end
local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end
local function scaleOf(m)
	local ok, v = pcall(function() return m:GetScale() end)
	return ok and v or 1
end

-- mode + squad rules (TrooMovesServer 1.11) ---------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
local SapWall = require(ServerStorage.DinoArcade:WaitForChild("SapWallBlock"))
local squadMod
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
local function testAlly(m) -- Studio-only hook
	if not RunService:IsStudio() then return false end
	local n = script:GetAttribute("TrooSlotTestAllyName")
	return type(n) == "string" and n ~= "" and m.Name == n and isBot(m)
end
local function squadmate(a, b)
	if not a or not b then return false end
	if testAlly(b) then return true end
	if script:GetAttribute("TrooSlotSquadEnabled") == false then return false end
	if not squadMod then
		local m = ServerStorage.DinoArcade:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b) == true
end
local function mayHarm(source, target)
	if squadmate(source, target) then
		count("TrooSlotSquadSkips")
		return false
	end
	if script:GetAttribute("TrooSlotModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(Players:GetPlayerFromCharacter(source) ~= nil, tpl ~= nil, inMenu, MODE)
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
local function enemies(self)
	local out = {}
	for _, m in ipairs(everyone(self)) do if mayHarm(self, m) then table.insert(out, m) end end
	return out
end
local function allies(self) -- you + your live squadmates
	local out = {self}
	for _, m in ipairs(everyone(self)) do if squadmate(self, m) then table.insert(out, m) end end
	return out
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
local armorMod
local function armorMul(victim)
	if script:GetAttribute("TrooSlotArmorAllEnabled") == false then return 1 end
	if armorMod == nil then armorMod = false; pcall(function() armorMod = require(ServerStorage.DinoArcade:WaitForChild("BoneCrest", 5)) end) end
	return armorMod and armorMod.armor and armorMod.armor(victim) or 1
end
local function damage(char, player, m, base, with, t)
	if shielded(m, t) then return 0 end
	local d = math.max(0, base) * takenMul(m, t) * armorMul(m)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return 0 end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player and player.UserId or 0)
		m:SetAttribute("KilledWith", with)
		m:SetAttribute("KilledAt", t) -- last
	end
	count("TrooSlotHits")
	return d
end
local function healthOf(m)
	if Players:GetPlayerFromCharacter(m) then
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then return hum.Health, hum.MaxHealth end
		return 0, 1
	end
	return num(m, "DummyHealth", 0), math.max(1, num(m, "DummyMaxHealth", 1))
end
local function setHealth(m, v) -- players: Humanoid; bots / the test ally: DummyHealth
	if Players:GetPlayerFromCharacter(m) then
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = v end
	else
		m:SetAttribute("DummyHealth", v)
	end
end
local function heal(m, amount)
	if amount <= 0 then return 0 end
	local hp, mx = healthOf(m)
	if hp <= 0 or hp >= mx then return 0 end
	local after = math.min(mx, hp + amount)
	setHealth(m, after)
	return after - hp
end
local function stampHeal(m, added, t)
	if added <= 0 then return end
	m:SetAttribute("TrooHealAmount", math.floor(added * 10 + 0.5) / 10)
	m:SetAttribute("TrooHealAt", t) -- last: TrooFX "+N"
	count("TrooSlotHeals")
end
local function stampHit(m, kind, by, t)
	m:SetAttribute("TrooHitKind", kind)
	m:SetAttribute("TrooHitBy", by)
	m:SetAttribute("TrooHitAt", t) -- last: TrooFX hit flash
end
local slowFn
local function slow(m, mul, untilT) -- TrooMovesServer 1.11 slow()
	m:SetAttribute("TrooSlowMul", mul)
	m:SetAttribute("TrooSlowUntil", untilT)
	if not Players:GetPlayerFromCharacter(m) then
		if not (slowFn and slowFn.Parent) then
			local s = ServerScriptService:FindFirstChild("TrooAttackServer")
			slowFn = s and s:FindFirstChild("TrooSlowApply")
		end
		if slowFn then pcall(function() slowFn:Invoke(m, mul, untilT) end) end
	end
end

-- world ------------------------------------------------------------------------------------------------------------------------
local function folder(name)
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function worldExclude()
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX", "PachyFX_Local", "DiloFX", "TrooFX", "TrooPartsFX", "TrooWalls",
		"TrooDomes", "TrooSentries", "TrooSlotFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rayParams.FilterDescendantsInstances = ex
	return rayParams
end
local function groundY(pos, fallback)
	local g = workspace:Raycast(Vector3.new(pos.X, pos.Y + 60, pos.Z), Vector3.new(0, -200, 0), worldExclude())
	return g and g.Position.Y or fallback
end
local function clearLine(a, b) -- nothing solid and no Sap Wall / dome between a and b
	local d = b - a
	if d.Magnitude < 1e-3 then return true end
	if workspace:Raycast(a, d, worldExclude()) then return false end
	return not (SapWall.blocks(a, b))
end
local function chestOf(m)
	local r = rootOf(m)
	return r and r.Position + Vector3.new(0, 0.5 * scaleOf(m), 0)
end

-- remotes + checks (TrooMovesServer 1.11) ---------------------------------------------------------------------------------------
local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local function check(player, stamp, id, prefix, aimDir, aimPoint)
	local char = player.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp or (aimDir ~= nil and (typeof(aimDir) ~= "Vector3"
		or aimDir.Magnitude < 0.5 or aimDir.Magnitude > 1.5)) or (aimPoint ~= nil and typeof(aimPoint) ~= "Vector3") then
		r = "badArg"
	elseif not hum or hum.Health <= 0 or not rootOf(char) then
		r = "dead"
	elseif not on(id) or char:GetAttribute(prefix .. "Enabled") ~= true or char:GetAttribute("Species") ~= "Troodon" then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif num(char, "StunnedUntil", 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif char:GetAttribute("TrooRiftPlacing") == true then
		r = "placing"
	elseif num(char, "DazedUntil", 0) > t then
		r = "dazed"
	elseif num(char, "SilencedUntil", 0) > t then
		r = "silenced"
	end
	if not r and t < num(char, prefix .. "ReadyAt", 0) then r = "cooldown" end
	if r then
		char:SetAttribute(prefix .. "ServerResult", r)
		char:SetAttribute(prefix .. "ServerResultAt", t)
		return nil
	end
	return char, t
end
local function result(char, prefix, r, t)
	char:SetAttribute(prefix .. "ServerResult", r)
	char:SetAttribute(prefix .. "ServerResultAt", t)
end
local function ok(char, prefix, t)
	result(char, prefix, "ok", t)
	char:SetAttribute(prefix .. "ReadyAt", t + math.max(0.5, num(char, prefix .. "Cooldown", 15)))
end
local function canStill(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	return char.Parent ~= nil and hum ~= nil and hum.Health > 0 and rootOf(char) ~= nil and num(char, "StunnedUntil", 0) <= t
		and num(char, "DazedUntil", 0) <= t and char:GetAttribute("PinHeld") ~= true
end
local function heading(char, aimDir)
	local d = typeof(aimDir) == "Vector3" and flat(aimDir) or Vector3.zero
	if d.Magnitude < 1e-3 then d = flat(rootOf(char).CFrame.LookVector) end
	return d.Magnitude > 1e-3 and d.Unit or -Vector3.zAxis
end
local function landing(char, aimDir, aimPoint, range)
	local root = rootOf(char)
	local p0 = root.Position
	local dir = heading(char, aimDir)
	local d = range
	if typeof(aimPoint) == "Vector3" then
		local v = flat(aimPoint - p0)
		if v.Magnitude > 1e-3 then dir = v.Unit; d = math.clamp(v.Magnitude, 0, range) end
	end
	local p = p0 + dir * d
	return Vector3.new(p.X, groundY(p, p0.Y - 3 * scaleOf(char)), p.Z), dir
end
local function handPos(char)
	local root = rootOf(char)
	return root.Position + Vector3.new(0, 1.5 * scaleOf(char), 0) + root.CFrame.LookVector * 2 * scaleOf(char)
end
local function headPos(char)
	local h = char:FindFirstChild("Head")
	local r = h and h:FindFirstChild("Root")
	if r and r:IsA("BasePart") then return r.Position + r.CFrame.LookVector * 0.6 * scaleOf(char) end
	local root = rootOf(char)
	return root.Position + Vector3.new(0, 2.4 * scaleOf(char), 0) + root.CFrame.LookVector * 3 * scaleOf(char)
end
local function within(a, m, R) local r = rootOf(m); return r ~= nil and flat(r.Position - a).Magnitude <= R end

-- the heal boost / cut watcher (Bloom Burst) --------------------------------------------------------------------------------------
local watched = setmetatable({}, {__mode = "k"})
local function watchHeals(m)
	if watched[m] or script:GetAttribute("TrooSlotHealWatchEnabled") == false then return end
	local isPlayer = Players:GetPlayerFromCharacter(m) ~= nil
	local hum = m:FindFirstChildOfClass("Humanoid")
	local last = (healthOf(m))
	local adjusting = false
	local conn
	local function onChange()
		local hp, mx = healthOf(m)
		local delta = hp - last
		last = hp
		if adjusting or delta <= 0 then return end
		local t = now()
		local boostOn, cutOn = num(m, "TrooBoostUntil", 0) > t, num(m, "TrooHealCutUntil", 0) > t
		if not boostOn and not cutOn then
			if conn then conn:Disconnect() end
			watched[m] = nil
			return
		end
		if delta > cfg("healWatchMaxFrac") * mx then return end
		local mul = (boostOn and num(m, "TrooBoostMul", 1) or 1) * (cutOn and num(m, "TrooHealCutMul", 1) or 1)
		if math.abs(mul - 1) < 1e-3 then return end
		local want = math.clamp(hp - delta + delta * mul, 0, mx)
		adjusting = true
		setHealth(m, want)
		last = (healthOf(m))
		adjusting = false
		if mul > 1 then count("TrooSlotBoosts") else count("TrooSlotCuts") end
		m:SetAttribute("TrooHealMulLast", ("%+.1f"):format(want - hp))
	end
	if isPlayer and hum then conn = hum.HealthChanged:Connect(onChange)
	else conn = m:GetAttributeChangedSignal("DummyHealth"):Connect(onChange) end
	watched[m] = conn
end

-- Bloom Tank ------------------------------------------------------------------------------------------------------------------
local function applyBloom(char)
	if not char.Parent then return end
	local want = on("obloom") and char:GetAttribute("Species") == "Troodon" and char:GetAttribute("TrooPartBloomEnabled") == true
	local s = scaleOf(char)
	if want then
		if char:GetAttribute("TrooBloomBaseRadius") == nil then
			char:SetAttribute("TrooBloomBaseRadius", num(char, "TrooZoneRadius", 10))
			char:SetAttribute("TrooBloomBaseTime", num(char, "TrooZoneTime", 3))
		end
		local R, T = num(char, "TrooPartBloomRadius", 0), num(char, "TrooPartBloomTime", 0)
		if R > 0 then char:SetAttribute("TrooZoneRadius", math.floor(R / s * 1000 + 0.5) / 1000) end
		if T > 0 then char:SetAttribute("TrooZoneTime", T) end
	elseif char:GetAttribute("TrooBloomBaseRadius") ~= nil then
		char:SetAttribute("TrooZoneRadius", char:GetAttribute("TrooBloomBaseRadius"))
		char:SetAttribute("TrooZoneTime", char:GetAttribute("TrooBloomBaseTime"))
		char:SetAttribute("TrooBloomBaseRadius", nil)
		char:SetAttribute("TrooBloomBaseTime", nil)
	end
end
local function bloomPulse(char, center, R)
	if not (char.Parent and on("obloom") and char:GetAttribute("TrooPartBloomEnabled") == true and char:GetAttribute("TrooPartBloomEnd") == true) then return end
	local t = now()
	local healAmt, slowT = num(char, "TrooPartBloomEndHeal", 5), num(char, "TrooPartBloomEndSlow", 1.5)
	for _, m in ipairs(allies(char)) do
		if within(center, m, R) then stampHeal(m, heal(m, healAmt), t) end
	end
	local mul = math.clamp(num(char, "TrooZoneSlowMul", 0.75), 0.05, 1)
	for _, m in ipairs(enemies(char)) do
		if within(center, m, R) then slow(m, mul, math.max(num(m, "TrooSlowUntil", 0), t + slowT)) end
	end
	char:SetAttribute("TrooBloomPulseCenter", center)
	char:SetAttribute("TrooBloomPulseRadius", R)
	char:SetAttribute("TrooBloomPulseAt", t) -- last: TrooSlotFX
	count("TrooSlotBloomPulses")
end
local function watchZones(char)
	char:GetAttributeChangedSignal("TrooZoneAt"):Connect(function()
		if char:GetAttribute("TrooPartBloomEnd") ~= true then return end
		local c, u = char:GetAttribute("TrooZoneCenter"), num(char, "TrooZoneUntil", 0)
		if typeof(c) ~= "Vector3" then return end
		local R = num(char, "TrooZoneRadius", 10) * scaleOf(char)
		task.delay(math.max(0, u - now()), bloomPulse, char, c, R)
	end)
end

-- Bloom Burst ------------------------------------------------------------------------------------------------------------------
botHook(remote("DinoTrooBurstRequest")):Connect(function(player, stamp, aimDir, aimPoint)
	local char, t = check(player, stamp, "oburst", "TrooPartBurst", aimDir, aimPoint)
	if not char then return end
	ok(char, "TrooPartBurst", t)
	local to = landing(char, aimDir, aimPoint, math.max(1, num(char, "TrooPartBurstRange", 40)))
	local fly = cfg("burstFly")
	char:SetAttribute("TrooBurstFrom", handPos(char))
	char:SetAttribute("TrooBurstTo", to)
	char:SetAttribute("TrooBurstFlight", fly)
	char:SetAttribute("TrooBurstAt", t) -- last: poses + TrooSlotFX
	task.delay(cfg("throwWindup"), function()
		if not canStill(char) then result(char, "TrooPartBurst", "cancelled", now()) return end
		task.wait(fly)
		if not char.Parent then return end
		local tl = now()
		local R = math.max(1, num(char, "TrooPartBurstRadius", 20))
		local dur = math.max(0, num(char, "TrooPartBurstTime", 4))
		local boost, cut = 1 + math.max(0, num(char, "TrooPartBurstBoost", 0.5)), 1 - math.clamp(num(char, "TrooPartBurstCut", 0.5), 0, 1)
		local healed, cutN = 0, 0
		for _, m in ipairs(allies(char)) do
			if within(to, m, R) then
				stampHeal(m, heal(m, num(char, "TrooPartBurstHeal", 20)), tl)
				m:SetAttribute("TrooBoostMul", boost)
				m:SetAttribute("TrooBoostUntil", tl + dur)
				watchHeals(m)
				healed += 1
			end
		end
		for _, m in ipairs(enemies(char)) do
			if within(to, m, R) then
				m:SetAttribute("TrooHealCutMul", cut)
				m:SetAttribute("TrooHealCutUntil", tl + dur)
				watchHeals(m)
				cutN += 1
			end
		end
		char:SetAttribute("TrooBurstLast", ("allies %d, enemies %d"):format(healed, cutN))
		char:SetAttribute("TrooBurstLandAt", tl) -- TrooSlotFX: the burst
	end)
end)

-- Shield Dome ------------------------------------------------------------------------------------------------------------------
local DOME_BLUE = Color3.fromRGB(108, 196, 255)
botHook(remote("DinoTrooDomeRequest")):Connect(function(player, stamp, aimDir, aimPoint)
	local char, t = check(player, stamp, "odome", "TrooPartDome", aimDir, aimPoint)
	if not char then return end
	ok(char, "TrooPartDome", t)
	local to = landing(char, aimDir, aimPoint, math.max(1, num(char, "TrooPartDomeRange", 30)))
	local fly = cfg("domeFly")
	char:SetAttribute("TrooDomeFrom", handPos(char))
	char:SetAttribute("TrooDomeTo", to)
	char:SetAttribute("TrooDomeFlight", fly)
	char:SetAttribute("TrooDomeAt", t) -- last
	task.delay(cfg("throwWindup"), function()
		if not canStill(char) then result(char, "TrooPartDome", "cancelled", now()) return end
		task.wait(fly + cfg("domeOpen"))
		if not char.Parent then return end
		local topen = now()
		local R = math.max(1, num(char, "TrooPartDomeRadius", 15))
		local life = math.max(0.5, num(char, "TrooPartDomeTime", 5))
		local p = Instance.new("Part")
		p.Name = "TrooDome"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(to)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.ForceField
		p.Color = DOME_BLUE
		p.CastShadow = false
		p:SetAttribute("TrooDomeOwner", char.Name)
		p:SetAttribute("TrooDomeUntil", topen + life)
		p:SetAttribute("TrooDomeRadius", R)
		p.Parent = folder("TrooDomes")
		CollectionService:AddTag(p, "TrooDome")
		char:SetAttribute("TrooDomeUntil", topen + life)
		count("TrooSlotDomes")
		TweenService:Create(p, TweenInfo.new(cfg("domeGrow"), Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = Vector3.one * R * 2}):Play()
		task.delay(life, function()
			if not p.Parent then return end
			p:SetAttribute("TrooDomeUntil", 0)
			TweenService:Create(p, TweenInfo.new(cfg("domeShrink")), {Size = Vector3.one * 0.5}):Play()
			task.delay(cfg("domeShrink") + 0.05, function() p:Destroy() end)
		end)
	end)
end)

-- Sleep Dart -------------------------------------------------------------------------------------------------------------------
local function sleep(m, dur, by, t)
	if not m.Parent or dur <= 0 then return end
	local u = math.max(num(m, "StunnedUntil", 0), t + dur)
	m:SetAttribute("StunnedUntil", u)
	m:SetAttribute("TrooSleepUntil", u)
	m:SetAttribute("TrooSleepBy", by)
	m:SetAttribute("TrooSleepAt", t) -- last: TrooSlotFX Zz
	count("TrooSlotSleeps")
	if script:GetAttribute("TrooSlotSleepWakeEnabled") == false then return end
	local hum = m:FindFirstChildOfClass("Humanoid")
	local lastD, lastH = num(m, "DummyHealth", 0), hum and hum.Health or 0
	local conns = {}
	local function done() for _, c in ipairs(conns) do c:Disconnect() end end
	local function wake()
		local tw = now()
		if num(m, "TrooSleepUntil", 0) ~= u or tw >= u then done() return end
		local su = num(m, "StunnedUntil", 0)
		if su > tw and su <= u + 1e-3 then m:SetAttribute("StunnedUntil", tw) end
		m:SetAttribute("TrooSleepUntil", 0)
		m:SetAttribute("TrooSleepWokeAt", tw)
		count("TrooSlotWakes")
		done()
	end
	table.insert(conns, m:GetAttributeChangedSignal("DummyHealth"):Connect(function()
		local v = num(m, "DummyHealth", 0)
		if v < lastD - 1e-3 then wake() end
		lastD = v
	end))
	if hum then
		table.insert(conns, hum.HealthChanged:Connect(function(v)
			if v < lastH - 1e-3 then wake() end
			lastH = v
		end))
	end
	task.delay(math.max(0, u - t) + 0.1, done)
end
local function sleepPick(char, from, dir, range)
	local cosA = math.cos(math.rad(SHOT_ASSIST_DEG))
	local best, bestScore
	for _, m in ipairs(enemies(char)) do
		local c = chestOf(m)
		local v = c and flat(c - from)
		local d = v and v.Magnitude or 0
		if c and d > 1e-3 and d <= range then
			local dot = v.Unit:Dot(dir)
			if dot >= cosA and clearLine(from, c) then
				local score = d * (2 - dot) -- nearer and closer to the aim wins
				if not bestScore or score < bestScore then best, bestScore = m, score end
			end
		end
	end
	return best
end
botHook(remote("DinoTrooSleepRequest")):Connect(function(player, stamp, aimDir)
	local char, t = check(player, stamp, "osleep", "TrooPartSleep", aimDir, nil)
	if not char then return end
	ok(char, "TrooPartSleep", t)
	char:SetAttribute("TrooSleepAt", t) -- last: poses (the neck coil + snap)
	task.delay(cfg("sleepWindup"), function()
		if not canStill(char) then result(char, "TrooPartSleep", "cancelled", now()) return end
		local tf = now()
		local range = math.max(1, num(char, "TrooPartSleepRange", 120))
		local from = headPos(char)
		local dir = heading(char, aimDir)
		local target = sleepPick(char, from, dir, range)
		local to
		if target then
			to = chestOf(target)
		else
			to = from + dir * range
			local hit = workspace:Raycast(from, dir * range, worldExclude())
			if hit then to = hit.Position end
			local wall, _ = SapWall.blocks(from, to)
			if wall then to = from:Lerp(to, 0.5) end
		end
		local flight = (to - from).Magnitude / math.max(1, cfg("sleepSpeed"))
		char:SetAttribute("TrooSleepFrom", from)
		char:SetAttribute("TrooSleepTo", to)
		char:SetAttribute("TrooSleepFlight", flight)
		char:SetAttribute("TrooSleepTarget", target and target.Name or "")
		char:SetAttribute("TrooSleepFireAt", tf) -- last: TrooSlotFX dart
		if not target then return end
		task.wait(flight)
		local th = now()
		if not (target.Parent and isTarget(target, char) and mayHarm(char, target)) or shielded(target, th) then return end
		local dur = num(char, "TrooPartSleepTime", 2.5)
		sleep(target, dur, char.Name, th)
		stampHit(target, "sleep", char.Name, th)
		local split = num(char, "TrooPartSleepSplit", 0)
		if split > 0 then
			local tp = chestOf(target)
			local best, bd
			for _, m in ipairs(enemies(char)) do
				local c = m ~= target and chestOf(m)
				local d = c and (c - tp).Magnitude
				if d and d <= split and (not bd or d < bd) then best, bd = m, d end
			end
			if best then
				char:SetAttribute("TrooSleepSplitFrom", tp)
				char:SetAttribute("TrooSleepSplitTo", chestOf(best))
				char:SetAttribute("TrooSleepSplitAt", th) -- last
				task.delay(cfg("sleepSplitDelay"), function()
					local ts = now()
					if best.Parent and isTarget(best, char) and mayHarm(char, best) and not shielded(best, ts) then
						sleep(best, dur, char.Name, ts)
						stampHit(best, "sleep", char.Name, ts)
					end
				end)
			end
		end
	end)
end)

-- Sentry Pod -------------------------------------------------------------------------------------------------------------------
local LOOK = {}
local SEG = {}
do
	pcall(function()
		local L = require(ServerStorage.DinoArcade:WaitForChild("TrooSlotLooks", 10))
		LOOK = L.LOOKS.osentry or {}
		script:SetAttribute("TrooSlotLooksVersion", tostring(L.Version))
	end)
	pcall(function()
		local data = require(ServerStorage.DinoArcade.Models.TroodonModelData)
		for _, seg in ipairs(data.segments or {}) do
			if type(seg.root) == "table" and #seg.root == 12 then SEG[seg.name] = CFrame.new(table.unpack(seg.root)) end
		end
	end)
end
-- the turret's rest geometry (TrooSlotLooks 1.0's carried osentry pieces), model space at scale 1, relative to the carry mark;
-- the head pieces (anim "sentYaw") come out of the folded pose (barrel up 90 deg about the head pivot) to level
local SENT_HEAD_PIVOT = Vector3.new(0, 1.06, 0.42) -- slotparts.js Ch (model space)
local SENT_LEG_TILT = math.rad(38)
local MATS = {gun = {Color3.fromHex("3a3f47"), Enum.Material.Metal}, dark = {Color3.fromHex("23262c"), Enum.Material.Metal},
	steel = {Color3.fromHex("9aa1ac"), Enum.Material.Metal}, brass = {Color3.fromHex("c8913a"), Enum.Material.Metal},
	plate = {Color3.fromHex("5d544a"), Enum.Material.SmoothPlastic}, amber = {Color3.fromHex("ffc35a"), Enum.Material.Neon}}
local function sentryPieces()
	local mark
	for _, mk in ipairs(LOOK.marks or {}) do if mk[1] == "carry" then mark = mk end end
	if not mark or not SEG[mark[2]] then return nil end
	local C = (SEG[mark[2]] * CFrame.new(mark[3], mark[4], mark[5])).Position
	local out = {}
	for _, r in ipairs(LOOK.pieces or {}) do
		if r[24] == "carry" and SEG[r[1]] then
			local cf = SEG[r[1]] * CFrame.new(r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15], r[16], r[17], r[18]):Orthonormalize()
			local anim = r[25]
			if anim == "sentYaw" then
				cf = CFrame.new(SENT_HEAD_PIVOT) * CFrame.Angles(-math.rad(90), 0, 0) * CFrame.new(-SENT_HEAD_PIVOT) * cf
			elseif anim == "sentLeg" then
				local hinge = cf.Position - cf.ZVector * 0.15
				cf = CFrame.new(hinge) * cf.Rotation * CFrame.Angles(SENT_LEG_TILT, 0, 0) * CFrame.new(0, 0, 0.15)
			end
			table.insert(out, {t = r[2], d = {r[3], r[4], r[5]}, s = {r[19], r[20], r[21]}, mat = r[22], head = anim == "sentYaw",
				rel = CFrame.new(-C) * cf})
		end
	end
	return out
end
local function buildSentry(at, k, yaw)
	local pieces = sentryPieces()
	local m = Instance.new("Model")
	m.Name = "TrooSentry"
	local heads = {}
	if pieces then
		for _, pc in ipairs(pieces) do
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			local mt = MATS[pc.mat] or MATS.gun
			p.Color, p.Material = mt[1], mt[2]
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			local inner = CFrame.identity
			if pc.t == "box" then
				p.Size = Vector3.new(pc.d[1], pc.d[2], pc.d[3]) * k
			elseif pc.t == "cyl" then
				p.Shape = Enum.PartType.Cylinder
				local r = math.max(pc.d[1], pc.d[2])
				p.Size = Vector3.new(pc.d[3], r * 2, r * 2) * k
				inner = CFrame.Angles(0, 0, math.rad(90))
			else
				p.Shape = Enum.PartType.Ball
				p.Size = Vector3.one * pc.d[1] * 2 * k
			end
			local rel = CFrame.new(pc.rel.Position * k) * pc.rel.Rotation
			p:SetAttribute("TrooSentryRel", rel)
			p:SetAttribute("TrooSentryInner", inner)
			p:SetAttribute("TrooSentryHead", pc.head)
			p.Parent = m
			if pc.head then table.insert(heads, p) end
		end
	end
	local base = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local function place(headYaw)
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") then
				local rel, inner = p:GetAttribute("TrooSentryRel"), p:GetAttribute("TrooSentryInner")
				local turn = p:GetAttribute("TrooSentryHead") and CFrame.Angles(0, headYaw, 0) or CFrame.identity
				p.CFrame = base * turn * rel * inner
			end
		end
	end
	place(0)
	m:SetAttribute("TrooSentryParts", #m:GetChildren())
	return m, place, base
end
botHook(remote("DinoTrooSentryRequest")):Connect(function(player, stamp, aimDir, aimPoint)
	local char, t = check(player, stamp, "osentry", "TrooPartSentry", aimDir, aimPoint)
	if not char then return end
	ok(char, "TrooPartSentry", t)
	local to, dir = landing(char, aimDir, aimPoint, math.max(1, num(char, "TrooPartSentryRange", 30)))
	local fly = cfg("sentryFly")
	char:SetAttribute("TrooSentryFrom", handPos(char))
	char:SetAttribute("TrooSentryTo", to)
	char:SetAttribute("TrooSentryFlight", fly)
	char:SetAttribute("TrooSentryAt", t) -- last
	task.delay(cfg("throwWindup"), function()
		if not canStill(char) then result(char, "TrooPartSentry", "cancelled", now()) return end
		task.wait(fly + cfg("sentryOpen"))
		if not char.Parent then return end
		local topen = now()
		local s = scaleOf(char)
		local k = cfg("sentryScale") * s
		local yaw = math.atan2(-dir.X, -dir.Z)
		local stand = to + Vector3.new(0, 0.23 * k, 0) -- base + legs (mockup: (0.04 + 0.19) x k)
		local m, place, base = buildSentry(stand, k, yaw)
		local life = math.max(0.5, num(char, "TrooPartSentryTime", 8))
		m:SetAttribute("TrooSentryOwner", char.Name)
		m:SetAttribute("TrooSentryUntil", topen + life)
		m:SetAttribute("TrooSentryOpenAt", topen)
		m.Parent = folder("TrooSentries")
		char:SetAttribute("TrooSentryUntil", topen + life)
		count("TrooSlotSentries")
		local muzzleRel = Vector3.new(0, (SENT_HEAD_PIVOT.Y - 0.93) * k, -0.5 * k) -- slotparts.js NK.sentMuzzle relative to C
		local headYaw = 0
		local reach = math.max(1, num(char, "TrooPartSentryReach", 60))
		local rate = math.max(0.1, num(char, "TrooPartSentryRate", 0.5))
		local tNext = topen + cfg("sentryFirstShot")
		-- v1.1: the damage cap per throw (0 = none)
		local cap = script:GetAttribute("TrooSlotSentryCapEnabled") ~= false and math.max(0, num(char, "TrooPartSentryTotal", 0)) or 0
		local spent, held = 0, 0
		m:SetAttribute("TrooSentryCap", cap)
		m:SetAttribute("TrooSentryDealt", 0)
		local function capped() return cap > 0 and spent >= cap - 1e-6 end
		local function full() return cap > 0 and spent + held >= cap - 1e-6 end
		while char.Parent and m.Parent and now() < topen + life and not capped() do
			if now() >= tNext and not full() then
				tNext += rate
				local muzzle0 = (base * CFrame.Angles(0, headYaw, 0) * CFrame.new(muzzleRel)).Position
				local best, bd
				for _, e in ipairs(enemies(char)) do
					local c = chestOf(e)
					local d = c and flat(c - stand).Magnitude
					if d and d <= reach and (not bd or d < bd) and clearLine(muzzle0, c) then best, bd = e, d end
				end
				if best then
					local c = chestOf(best)
					local v = flat(c - stand)
					local want = math.atan2(-v.X, -v.Z) - yaw
					headYaw = want
					place(headYaw)
					local shots = math.max(1, math.floor(num(char, "TrooPartSentryShots", 1) + 0.5))
					for i = 1, shots do
						task.delay((i - 1) * cfg("sentryPair"), function()
							if not (m.Parent and best.Parent) then return end
							local per = num(char, "TrooPartSentryDamage", 6)
							if cap > 0 then
								per = math.min(per, cap - spent - held)
								if per <= 1e-6 then return end
								held += per
							end
							local function settle(hit)
								if cap <= 0 then return end
								held = math.max(0, held - per)
								if hit then
									spent += per
									m:SetAttribute("TrooSentryDealt", spent)
									if capped() then count("TrooSlotSentryCapped") end
								end
							end
							local ts = now()
							local muzzle = (base * CFrame.Angles(0, headYaw, 0) * CFrame.new(muzzleRel)).Position
							local aim = chestOf(best) or c
							local flight = (aim - muzzle).Magnitude / math.max(1, cfg("sentryShotSpeed"))
							m:SetAttribute("TrooSentryShotFrom", muzzle)
							m:SetAttribute("TrooSentryShotTo", aim)
							m:SetAttribute("TrooSentryShotFlight", flight)
							m:SetAttribute("TrooSentryShotTarget", best.Name)
							m:SetAttribute("TrooSentryShotAt", ts) -- last: TrooSlotFX bolt
							count("TrooSlotSentryShots")
							task.delay(flight, function()
								local th = now()
								if not (char.Parent and best.Parent and isTarget(best, char) and mayHarm(char, best)) then settle(false) return end
								if SapWall.blocks(muzzle, chestOf(best) or aim) then settle(false) return end
								local dmg = damage(char, player, best, per, "troosentry", th)
								settle(dmg > 0)
								if dmg > 0 then stampHit(best, "sentry", char.Name, th) end
							end)
						end)
					end
				end
			end
			task.wait(0.05)
		end
		m:SetAttribute("TrooSentryEndAt", now()) -- TrooSlotFX: fold + dissolve
		char:SetAttribute("TrooSentryUntil", math.min(num(char, "TrooSentryUntil", 0), now()))
		task.delay(0.4, function() m:Destroy() end)
	end)
end)

-- characters -------------------------------------------------------------------------------------------------------------------
local function onCharacter(char)
	for _, k in ipairs({"TrooPartBloomEnabled", "TrooPartBloomRadius", "TrooPartBloomTime", "Species"}) do
		char:GetAttributeChangedSignal(k):Connect(function() applyBloom(char) end)
	end
	watchZones(char)
	task.defer(applyBloom, char)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(onCharacter)
	if pl.Character then onCharacter(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end

-- v1.2: the bot entrance (see the header)
if script:GetAttribute("TrooSlotServerBotMechaEnabled") == nil then script:SetAttribute("TrooSlotServerBotMechaEnabled", true) end
do
	local proxyModule = game:GetService("ServerStorage"):WaitForChild("DinoArcade"):FindFirstChild("BotProxy")
	local BotProxy = proxyModule and require(proxyModule)
	local fn = script:FindFirstChild("BotMechaUse") or Instance.new("BindableFunction")
	fn.Name = "BotMechaUse"
	fn.OnInvoke = function(model, remoteName, ...)
		if script:GetAttribute("TrooSlotServerBotMechaEnabled") == false then return "off" end
		if not BotProxy or typeof(model) ~= "Instance" or model:GetAttribute("PracticeBot") ~= true or not model.Parent then return "badArg" end
		local list = __botHandlers[remoteName]
		if not list then return "noHandler" end
		local proxy = BotProxy.of(model)
		for _, h in ipairs(list) do
			local ok, err = pcall(h, proxy, ...)
			if not ok then
				script:SetAttribute("TrooSlotServerBotMechaError", tostring(remoteName) .. ": " .. tostring(err))
				return "botUnsupported"
			end
		end
		return "ok"
	end
	fn.Parent = script
end
script:SetAttribute("TrooSlotServerVersion", "1.2") -- v1.2 bot entrance
