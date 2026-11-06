-- DiloAttackServer v1.4 (Mecha Dino Arena) — the Dilophosaurus' Bite + Spit Dart (server authority). MDA-224, plan
-- docs/plans/DILO_KIT_v1.0.md Task 4 (deterministic map), mockup docs/mockups/dilo_kit_options_v0.1.html attack C
-- (Kepu 2026-11-03: picks "C and J1"; dart "Weaker dart"; red-team "Bite on press", "Soft aim, near-sure hit").
-- Remote ReplicatedStorage.DinoDiloAttack (RemoteEvent), client -> server: (kind, stamp). kind "bite" = the ATTACK press
--   (DiloAttackTest 1.0 sends it on every press); kind "dart" = the release of a press held DiloHoldTime or longer.
--   Checks in order -> character DiloAttackServerResult (+ DiloAttackServerResultAt): "badArg" (kind not "bite" / "dart" or
--   stamp not a number), "dead", "disabled" (script DiloAttackServerEnabled false or character DiloAttackEnabled ~= true),
--   "menu" (player InMenu), "stunned" (StunnedUntil), "dazed" (DazedUntil), "pinned" (PinHeld), then for a bite "cooldown"
--   (< DiloMinGap since the last accepted bite) and for a dart "dartCooldown" (< DiloDartCooldown since the last dart);
--   else "ok".
-- Bite (accepted: character DiloBiteAt = server now, last): at the stamp (clamped to [now - delay, now]) + DiloBiteDelay
--   (0.18 s) every allowed target whose nearest hitbox is within DiloBiteReach (5) x scale studs of the snout tip (part
--   "Head_tip", else the root) and whose root is within DiloBiteCone (70) degrees of the flat facing takes DiloBiteDamage (10)
--   x takenMul x Back Plating (BoneCrest 1.5 plating from the root; none while EnergyShieldUntil is in the future).
--   Stamps: DiloHitKind "bite", DiloHitTargets ("|" joined names), DiloHitPoint (the snout tip), DiloHitAt (last).
-- Dart (accepted: DiloDartFrom, DiloDartTo, DiloDartTarget (name or ""), DiloDartFlight, then DiloDartAt = now, last):
--   from = the snout tip; soft aim (the Goo Blob Shooter's rule, HerreraMovesServer 1.2): the closest allowed target whose
--   root is within DiloAssistAngle (30) degrees of the flat facing and DiloAssistMin..DiloAssistMax (0..30) x scale studs
--   (flat) away. To = its root; else from + facing x DiloDartRange (30) x scale. Flight = distance / (DiloDartSpeed (60) x
--   scale) s. At the arrival, with a target that is still a target and whose root is within DART_TOLERANCE (4) x scale studs
--   of To: DiloDartDamage (6) x takenMul x Back Plating (from DiloDartFrom; none while shielded), then venom: the target's
--   VenomUntil = now + DiloVenomTime (3), VenomDps = DiloVenomDps (2), VenomBy = the dilo's name (refreshed by a new dart,
--   never stacked). No target = no hit. Stamps on the dilo: DiloHitKind "dart", DiloHitTargets, DiloHitPoint, DiloHitAt
--   (last); "" targets on a miss.
-- Venom ticks: every VENOM_TICK (0.5) s while VenomUntil is in the future: VenomDps x 0.5 x takenMul off DummyHealth (skipped
--   while shielded); a killing tick stamps KilledWith "dilovenom". Target diagnostic VenomTicks (count).
-- Kills: KilledBy / KilledByUserId / KilledWith ("dilobite" / "dilodart" / "dilovenom") / KilledAt (last), like every attack.
-- Targets, mode and squad rules: TheriAttackServer 1.0's (player characters and Workspace.DinoIsland.Bots; Bitable, Hitboxes,
--   alive, not KO; ModeRules.canAffect; SquadRules.sameChar).
-- Switches (script attributes): DiloAttackServerEnabled (default true, read at start), DiloAttackModeRulesEnabled,
--   DiloAttackSquadEnabled, DiloAttackPlatingEnabled (default true each, read at each use).
-- Diagnostics: script DiloAttackServerVersion, DiloAttackRequests, DiloAttackHits, DiloVenomTicks, DiloAttackSquadSkips,
--   DiloAttackMode; character DiloAttackServerResult, DiloAttackServerResultAt.
-- v1.1 (MDA-237, plan docs/plans/DILO_STATS_v1.0.md Task 3; SkillTree 1.60 dilo rows written by SkillEffects 1.41). Switch:
--   script attribute DiloAttackStatsEnabled (default true, read at each use; false = 1.0 everywhere below). All the dilo's
--   numbers are character attributes; off values (nothing bought) = 1.0's behaviour.
--   * Venom rule (Kepu 2026-11-04 "Stronger one wins"): a new venom on a target whose venom is still running keeps the higher
--     of the two VenomDps and the later VenomUntil; never stacked. VenomBy = the new dilo when its dps >= the running one,
--     else unchanged. (Dart after dart at the same dps = 1.0's refresh.)
--   * Venom Bite: a bite hit (not shielded) with the dilo's DiloVenomBiteDps > 0 applies venom DiloVenomBiteDps for
--     DiloVenomBiteTime s.
--   * Cold Blood: while the dilo's Humanoid health < DiloColdBelow x MaxHealth (DiloColdBelow > 0): dart damage x DiloColdMul;
--     with DiloColdVenom also every venom it applies (dart, bite, Toxic Blood) x DiloColdMul. Star (DiloColdReset): the first
--     drop of a life (each character is one life) from at or above the line to under it (health > 0) clears the server's dart
--     recharge and stamps the dilo's DiloDartResetAt = now (DiloAttackTest 1.1 clears its own recharge and stamps
--     DiloDartReadyAt for ArenaTouch 1.16 / AbilityBar 1.27).
--   * Toxic Blood (Kepu "Close hits only"): when a dilo's LastHitAt changes, with DiloToxicDps > 0 and LastHitBy naming a
--     player character or a Workspace.DinoIsland.Bots model whose root is within TOXIC_RANGE (12) x the dilo's scale studs of
--     the dilo's root, that is a target (isTarget) and mayAffect allows it: that model gets venom DiloToxicDps for
--     DiloToxicTime s (VenomBy the dilo).
--   * Venom Feast: each venom tick heals the dilo named in VenomBy (a player character, alive) by the damage the tick took off
--     DummyHealth x its DiloFeastFrac, never above MaxHealth.
--   Diagnostics: script DiloAttackStatsVersion, DiloToxicHits, DiloFeastHeals, DiloDartResets; dilo character
--   DiloVenomFeastHealed (total, 0.1 steps), DiloToxicHits (count), DiloColdActive (under the line now, with Cold Blood),
--   DiloDartResetCount, DiloDartResetAt.
-- v1.2 (Kepu 2026-11-04 11:53 "sometimes it appears to fly right through the Dino in front of me"; fix "Hits where it lands"):
--   cause: the dart flies to the locked target's root as it was at the spit and 1.0 only counted the hit when that root was
--   still within DART_TOLERANCE (4) x scale studs of To at the arrival; a dino moving during the flight (0.34 s at 40 studs)
--   kept its body on To while its root slid past 8 studs (Studio: bot moved 10 studs, To 1.4 studs from its hitboxes, miss).
--   Now the arrival also counts a hit when the locked target's nearest hitbox is within DART_BODY_REACH (1.5) x scale studs
--   of To (the glob lands on its body); then DiloHitPoint = To (where the glob landed). The root rule is unchanged and checked
--   first. A dino that fully left the spot still dodges. Switch: script attribute DiloAttackBodyHitEnabled (default true, read
--   at each arrival; false = 1.1). Diagnostics: script DiloDartBodyHits (count); character DiloDartHitRule ("root" / "body" /
--   "miss", the last locked dart).
-- v1.3 (therizino Deflector Claws, MDA-247, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7; Kepu "Yes, in build 2"): a locked
--   dart that would hit (root or body rule) asks DeflectRules 1.0 (kind "dart", from DiloDartFrom); blocked = no damage, no
--   venom, DiloDartHitRule "deflected", no hit target (DiloFX fizzles); reflect (the star) = the dart's damage (with Cold
--   Blood) comes off the dilo's DummyHealth instead (KilledWith "deflect", credit to the therizino). Switch: script attribute
--   DiloAttackDeflectEnabled (default true, read at each arrival; false = 1.2).
-- v1.4 (plan docs/plans/DILO_MOVES_ANIM_v1.0.md Task 1, MDA-299; Kepu 2026-11-05 22:32 "A for all of them"): stamps for the
--   animation pass (no rule changes). Kinds "coil" / "uncoil" (sent by DiloAttackTest 1.2 when a hold reaches the coil / ends
--   without a spit): with a number stamp, the character alive, DiloAttackEnabled and the player not InMenu (else ignored; at
--   most one of each kind per 0.1 s): character DiloCoilAt = now ("coil") or DiloCoilEndAt = now ("uncoil"); no result, no cooldown. An
--   accepted "dart" also stamps DiloCoilEndAt = now before the dart's stamps. Toxic Blood: each venom it applies stamps on the
--   dilo DiloToxicTarget (the model's name) then DiloToxicAt (last). Venom Feast: each heal stamps on the dilo DiloFeastFrom
--   (the ticking model's name), DiloFeastAmount (healed, 0.1 steps), then DiloFeastAt (last). DiloPose 1.1 / DiloFX 1.2 read
--   them. Switch: script attribute DiloAttackAnimStampsEnabled (default true, read at each use; false = 1.3). Diagnostic:
--   script DiloCoilStamps (count).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.1" -- v1.1 dilo stat rows
VERSION = "1.2" -- v1.2 dart hits where it lands (body rule)
VERSION = "1.3" -- v1.3 Deflector Claws
VERSION = "1.4" -- v1.4 animation stamps
local DEFAULTS = {DiloBiteDamage = 10, DiloBiteDelay = 0.18, DiloBiteReach = 5, DiloBiteCone = 70, DiloHoldTime = 0.4,
	DiloDartDamage = 6, DiloVenomDps = 2, DiloVenomTime = 3, DiloDartRange = 30, DiloDartSpeed = 60, DiloDartCooldown = 1.5,
	DiloAssistAngle = 30, DiloAssistMin = 0, DiloAssistMax = 30, DiloMinGap = 0.35}
local MAX_DELAY = 0.6
local DART_TOLERANCE = 4
local VENOM_TICK = 0.5

script:SetAttribute("DiloAttackServerVersion", VERSION)
for _, k in ipairs({"DiloAttackRequests", "DiloAttackHits", "DiloVenomTicks", "DiloAttackSquadSkips"}) do
	script:SetAttribute(k, 0)
end
for _, k in ipairs({"DiloAttackServerEnabled", "DiloAttackModeRulesEnabled", "DiloAttackSquadEnabled", "DiloAttackPlatingEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local enabled = script:GetAttribute("DiloAttackServerEnabled") ~= false
-- v1.1
if script:GetAttribute("DiloAttackStatsEnabled") == nil then script:SetAttribute("DiloAttackStatsEnabled", true) end
for _, k in ipairs({"DiloToxicHits", "DiloFeastHeals", "DiloDartResets"}) do script:SetAttribute(k, 0) end
script:SetAttribute("DiloAttackStatsVersion", "1.1")
local TOXIC_RANGE = 12
-- v1.2
if script:GetAttribute("DiloAttackBodyHitEnabled") == nil then script:SetAttribute("DiloAttackBodyHitEnabled", true) end
script:SetAttribute("DiloDartBodyHits", 0)
local DART_BODY_REACH = 1.5
local function statsOn() return script:GetAttribute("DiloAttackStatsEnabled") ~= false end

local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
-- v1.4
if script:GetAttribute("DiloAttackAnimStampsEnabled") == nil then script:SetAttribute("DiloAttackAnimStampsEnabled", true) end
script:SetAttribute("DiloCoilStamps", 0)
local function animStamps() return script:GetAttribute("DiloAttackAnimStampsEnabled") ~= false end
local function get(char, k) return num(char, k, DEFAULTS[k]) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

-- mode + squad rules (TheriAttackServer 1.0) -------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("DiloAttackMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("DiloAttackSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("DiloAttackSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("DiloAttackModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end

-- targets (TheriAttackServer 1.0 rules) -------------------------------------------------------------------------------------
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
local crestCache
local function plating(m, fromPos)
	if script:GetAttribute("DiloAttackPlatingEnabled") == false or typeof(fromPos) ~= "Vector3" then return 1 end
	if crestCache == nil then
		crestCache = false
		pcall(function() crestCache = require(ServerStorage:WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end)
	end
	if crestCache and crestCache.plating then return crestCache.plating(m, fromPos) end
	return 1
end
local function takeHealth(m, d, killerName, killerId, with, t)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", killerName)
		m:SetAttribute("KilledByUserId", killerId)
		m:SetAttribute("KilledWith", with)
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
	end
end

-- per-character state -----------------------------------------------------------------------------------------------------
local states = setmetatable({}, {__mode = "k"})
local function track(char)
	local st = states[char]
	if not st then
		st = {lastBite = -math.huge, lastDart = -math.huge}
		states[char] = st
	end
	return st
end
local function setResult(char, r, t)
	char:SetAttribute("DiloAttackServerResult", r)
	char:SetAttribute("DiloAttackServerResultAt", t)
end
local function blocked(player, char, t)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not rootOf(char) then return "dead" end
	if player:GetAttribute("InMenu") == true then return "menu" end
	if num(char, "StunnedUntil", 0) > t then return "stunned" end
	if num(char, "DazedUntil", 0) > t then return "dazed" end
	if char:GetAttribute("PinHeld") == true then return "pinned" end
	return nil
end
local function snout(char)
	local tip = char:FindFirstChild("Head_tip", true)
	if tip and tip:IsA("BasePart") then return tip.Position end
	local r = rootOf(char)
	return r and r.Position or Vector3.zero
end
local function facing(char)
	local r = rootOf(char)
	local f = r and flat(r.CFrame.LookVector) or Vector3.zero
	return f.Magnitude > 1e-3 and f.Unit or -Vector3.zAxis
end
local function stampHit(char, kind, names, point, t)
	char:SetAttribute("DiloHitKind", kind)
	char:SetAttribute("DiloHitTargets", table.concat(names, "|"))
	char:SetAttribute("DiloHitPoint", point)
	char:SetAttribute("DiloHitAt", t) -- last: DiloFX reacts to this one
end

-- venom ---------------------------------------------------------------------------------------------------------------------
-- v1.1: Venom Feast (the dilo named in VenomBy heals part of each tick)
local function diloChar(name)
	if type(name) ~= "string" or name == "" then return nil end
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and c.Name == name and c:GetAttribute("Species") == "Dilo" then return c end
	end
	return nil
end
local function feast(byName, dealt, fromModel) -- v1.4: + fromModel (the ticking model, for the stamps)
	local c = diloChar(byName)
	local frac = c and num(c, "DiloFeastFrac", 0) or 0
	if not c or frac <= 0 or dealt <= 0 then return end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local add = math.min(hum.MaxHealth - hum.Health, dealt * frac)
	if add <= 0 then return end
	hum.Health += add
	c:SetAttribute("DiloVenomFeastHealed", math.floor(((c:GetAttribute("DiloVenomFeastHealed") or 0) + add) * 10 + 0.5) / 10)
	count("DiloFeastHeals")
	if fromModel and animStamps() then -- v1.4
		c:SetAttribute("DiloFeastFrom", fromModel.Name)
		c:SetAttribute("DiloFeastAmount", math.floor(add * 10 + 0.5) / 10)
		c:SetAttribute("DiloFeastAt", now()) -- last: DiloFX motes
	end
end
local venomLoops = setmetatable({}, {__mode = "k"})
local function venomLoop(m, killerName, killerId)
	if venomLoops[m] then return end
	venomLoops[m] = true
	task.spawn(function()
		while m.Parent and num(m, "VenomUntil", 0) > now() do
			task.wait(VENOM_TICK)
			local t = now()
			if not m.Parent or not isTarget(m, nil) then break end
			if num(m, "VenomUntil", 0) + 1e-3 < t - VENOM_TICK then break end
			if not shielded(m, t) then
				local d = math.max(0, num(m, "VenomDps", 0)) * VENOM_TICK * takenMul(m, t)
				if d > 0 then
					local hpBefore = m:GetAttribute("DummyHealth") -- v1.1: Venom Feast
					takeHealth(m, d, m:GetAttribute("VenomBy") or killerName, killerId, "dilovenom", t)
					if statsOn() and typeof(hpBefore) == "number" then feast(m:GetAttribute("VenomBy"), math.min(d, math.max(0, hpBefore)), m) end
					m:SetAttribute("VenomTicks", (m:GetAttribute("VenomTicks") or 0) + 1)
					count("DiloVenomTicks")
				end
			end
		end
		venomLoops[m] = nil
	end)
end
-- v1.1: the venom rule (stronger one wins, later end, never stacked); switch off = 1.0's overwrite
local function applyVenom(m, dps, dur, char, player, t)
	if dps <= 0 or dur <= 0 then return end
	local untilT, by = t + dur, char.Name
	if statsOn() and num(m, "VenomUntil", 0) > t then
		local curDps = math.max(0, num(m, "VenomDps", 0))
		if curDps > dps then by = m:GetAttribute("VenomBy") or by end
		dps = math.max(curDps, dps)
		untilT = math.max(num(m, "VenomUntil", 0), untilT)
	end
	m:SetAttribute("VenomDps", dps)
	m:SetAttribute("VenomBy", by)
	m:SetAttribute("VenomUntil", untilT) -- last
	venomLoop(m, char.Name, player and player.UserId or 0)
end
-- v1.1: Cold Blood
local function coldLow(char)
	local below = num(char, "DiloColdBelow", 0)
	local hum = char:FindFirstChildOfClass("Humanoid")
	return statsOn() and below > 0 and hum ~= nil and hum.Health > 0 and hum.Health < below * hum.MaxHealth
end
local function coldDartMul(char) return coldLow(char) and math.max(1, num(char, "DiloColdMul", 1)) or 1 end
local function coldVenomMul(char)
	return (coldLow(char) and char:GetAttribute("DiloColdVenom") == true) and math.max(1, num(char, "DiloColdMul", 1)) or 1
end

-- bite ----------------------------------------------------------------------------------------------------------------------
local function resolveBite(player, char, at)
	local t = now()
	if not char.Parent then return end
	if blocked(player, char, t) then return end
	local root = rootOf(char)
	local s = char:GetScale()
	local fwd = facing(char)
	local origin = snout(char)
	local reach = math.max(0, get(char, "DiloBiteReach")) * s
	local half = math.rad(math.clamp(get(char, "DiloBiteCone"), 0, 360) / 2)
	local dmg = math.max(0, get(char, "DiloBiteDamage"))
	local names = {}
	for _, m in ipairs(candidates(char)) do
		local v = flat(rootOf(m).Position - root.Position)
		local inCone = v.Magnitude < 1e-3 or math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= half
		if inCone and gap(m, origin) <= reach then
			if not shielded(m, t) then
				takeHealth(m, dmg * takenMul(m, t) * plating(m, root.Position), char.Name, player.UserId, "dilobite", t)
				if statsOn() and num(char, "DiloVenomBiteDps", 0) > 0 and isTarget(m, char) then -- v1.1: Venom Bite
					applyVenom(m, num(char, "DiloVenomBiteDps", 0) * coldVenomMul(char), num(char, "DiloVenomBiteTime", 0), char, player, t)
				end
			end
			table.insert(names, m.Name)
		end
	end
	count("DiloAttackHits", #names)
	stampHit(char, "bite", names, origin, t)
end

-- dart ----------------------------------------------------------------------------------------------------------------------
-- v1.3: Deflector Claws
if script:GetAttribute("DiloAttackDeflectEnabled") == nil then script:SetAttribute("DiloAttackDeflectEnabled", true) end
local deflectMod -- DeflectRules 1.0 (ServerStorage.DinoArcade), loaded on first use
local function deflected(target, fromPos, kind, t, switch)
	if script:GetAttribute(switch) == false then return false, false end
	if deflectMod == nil then
		deflectMod = false
		pcall(function()
			local arc = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
			local m = arc and arc:FindFirstChild("DeflectRules")
			if m then deflectMod = require(m) end
		end)
	end
	if not deflectMod then return false, false end
	return deflectMod.check(target, fromPos, kind, t)
end
local function pickTarget(char, from, fwd)
	local s = char:GetScale()
	local half = math.rad(math.clamp(get(char, "DiloAssistAngle"), 0, 180))
	local lo, hi = math.max(0, get(char, "DiloAssistMin")) * s, math.max(0, get(char, "DiloAssistMax")) * s
	local best, bestD = nil, math.huge
	for _, m in ipairs(candidates(char)) do
		local v = flat(rootOf(m).Position - from)
		local d = v.Magnitude
		if d >= lo and d <= hi and d > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= half and d < bestD then
			best, bestD = m, d
		end
	end
	return best
end
local function fireDart(player, char, t)
	local s = char:GetScale()
	local from = snout(char)
	local fwd = facing(char)
	local target = pickTarget(char, from, fwd)
	local to = target and rootOf(target).Position or from + fwd * math.max(0, get(char, "DiloDartRange")) * s
	local speed = math.max(1, get(char, "DiloDartSpeed")) * s
	local flight = (to - from).Magnitude / speed
	char:SetAttribute("DiloDartFrom", from)
	char:SetAttribute("DiloDartTo", to)
	char:SetAttribute("DiloDartTarget", target and target.Name or "")
	char:SetAttribute("DiloDartFlight", flight)
	char:SetAttribute("DiloDartAt", t) -- last: poses + FX
	task.delay(flight, function()
		local ti = now()
		if not char.Parent then return end
		local names = {}
		local point = to
		if target and target.Parent and isTarget(target, char) then
			local tr = rootOf(target)
			local rule = "miss" -- v1.2: root rule first, then the body rule
			if tr and (tr.Position - to).Magnitude <= DART_TOLERANCE * s then
				rule = "root"
			elseif tr and script:GetAttribute("DiloAttackBodyHitEnabled") ~= false and gap(target, to) <= DART_BODY_REACH * s then
				rule = "body"
				count("DiloDartBodyHits")
			end
			if rule ~= "miss" then -- v1.3: Deflector Claws
				local defl, refl = deflected(target, from, "dart", ti, "DiloAttackDeflectEnabled")
				if defl then
					rule = "deflected"
					if refl then
						local tp = Players:GetPlayerFromCharacter(target)
						takeHealth(char, math.max(0, get(char, "DiloDartDamage")) * coldDartMul(char), target.Name, tp and tp.UserId or 0, "deflect", ti)
					end
				end
			end
			char:SetAttribute("DiloDartHitRule", rule)
			if rule ~= "miss" and rule ~= "deflected" then
				point = rule == "root" and tr.Position or to
				if not shielded(target, ti) then
					local dmg = math.max(0, get(char, "DiloDartDamage")) * coldDartMul(char) -- v1.1: Cold Blood
					takeHealth(target, dmg * takenMul(target, ti) * plating(target, from), char.Name, player.UserId, "dilodart", ti)
					if statsOn() then -- v1.1: the venom rule, Cold Blood venom
						if isTarget(target, char) then
							applyVenom(target, math.max(0, get(char, "DiloVenomDps")) * coldVenomMul(char), math.max(0, get(char, "DiloVenomTime")), char, player, ti)
						end
					else
						target:SetAttribute("VenomDps", math.max(0, get(char, "DiloVenomDps")))
						target:SetAttribute("VenomBy", char.Name)
						target:SetAttribute("VenomUntil", ti + math.max(0, get(char, "DiloVenomTime"))) -- last
						venomLoop(target, char.Name, player.UserId)
					end
				end
				table.insert(names, target.Name)
			end
		end
		count("DiloAttackHits", #names)
		stampHit(char, "dart", names, point, ti)
	end)
end

-- remote --------------------------------------------------------------------------------------------------------------------
local remote = ReplicatedStorage:FindFirstChild("DinoDiloAttack")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoDiloAttack"
	remote.Parent = ReplicatedStorage
end

remote.OnServerEvent:Connect(function(player, kind, stamp)
	count("DiloAttackRequests")
	local char = player.Character
	if not char then return end
	local t = now()
	local st = track(char)
	local r
	if (kind == "coil" or kind == "uncoil") and animStamps() then -- v1.4: animation stamps only
		local hum = char:FindFirstChildOfClass("Humanoid")
		if typeof(stamp) ~= "number" or stamp ~= stamp or not hum or hum.Health <= 0 or not enabled
			or char:GetAttribute("DiloAttackEnabled") ~= true or player:GetAttribute("InMenu") == true then return end
		if t - (st["last_" .. kind] or -1) < 0.1 then return end
		st["last_" .. kind] = t
		char:SetAttribute(kind == "coil" and "DiloCoilAt" or "DiloCoilEndAt", t)
		count("DiloCoilStamps")
		return
	end
	if (kind ~= "bite" and kind ~= "dart") or typeof(stamp) ~= "number" or stamp ~= stamp then
		r = "badArg"
	elseif not char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
		r = "dead"
	elseif not enabled or char:GetAttribute("DiloAttackEnabled") ~= true then
		r = "disabled"
	else
		r = blocked(player, char, t)
	end
	if not r and kind == "bite" and t - st.lastBite < math.max(0, get(char, "DiloMinGap")) then r = "cooldown" end
	if not r and kind == "dart" and t - st.lastDart < math.max(0, get(char, "DiloDartCooldown")) then r = "dartCooldown" end
	if r then
		setResult(char, r, t)
		return
	end
	setResult(char, "ok", t)
	if kind == "bite" then
		st.lastBite = t
		char:SetAttribute("DiloBiteAt", t) -- last: poses + FX
		local d = math.clamp(math.max(0, get(char, "DiloBiteDelay")), 0, MAX_DELAY)
		local delay = math.clamp(math.min(stamp, t) + d - t, 0, d)
		task.delay(delay, resolveBite, player, char, t)
	else
		st.lastDart = t
		if animStamps() then char:SetAttribute("DiloCoilEndAt", t) end -- v1.4
		fireDart(player, char, t)
	end
end)

-- v1.1: Toxic Blood + the Cold Blood star, per dilo character -----------------------------------------------------------------
local function findModel(name)
	if type(name) ~= "string" or name == "" then return nil end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character and pl.Character.Name == name then return pl.Character end
	end
	for _, b in ipairs(bots()) do
		if b.Name == name then return b end
	end
	return nil
end
local function watchDilo(player, char)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local last = hum.Health
	local resetUsed = false
	hum.HealthChanged:Connect(function(h)
		local prev = last
		last = h
		if char:GetAttribute("Species") ~= "Dilo" then return end
		local below = num(char, "DiloColdBelow", 0)
		local line = below * hum.MaxHealth
		local low = statsOn() and below > 0 and h > 0 and h < line
		if char:GetAttribute("DiloColdActive") ~= low then char:SetAttribute("DiloColdActive", low) end
		if low and prev >= line and not resetUsed and char:GetAttribute("DiloColdReset") == true then
			resetUsed = true
			local t = now()
			track(char).lastDart = -math.huge
			char:SetAttribute("DiloDartResetCount", (char:GetAttribute("DiloDartResetCount") or 0) + 1)
			char:SetAttribute("DiloDartResetAt", t)
			count("DiloDartResets")
		end
	end)
	char:GetAttributeChangedSignal("LastHitAt"):Connect(function()
		if not statsOn() or char:GetAttribute("Species") ~= "Dilo" then return end
		local dps, dur = num(char, "DiloToxicDps", 0), num(char, "DiloToxicTime", 0)
		if dps <= 0 or dur <= 0 or hum.Health <= 0 then return end
		local m = findModel(char:GetAttribute("LastHitBy"))
		local r, mr = rootOf(char), m and rootOf(m)
		if not m or m == char or not r or not mr then return end
		if (mr.Position - r.Position).Magnitude > TOXIC_RANGE * char:GetScale() then return end
		if not isTarget(m, char) or not mayAffect(char, m) then return end
		local t = now()
		applyVenom(m, dps * coldVenomMul(char), dur, char, player, t)
		char:SetAttribute("DiloToxicHits", (char:GetAttribute("DiloToxicHits") or 0) + 1)
		if animStamps() then -- v1.4
			char:SetAttribute("DiloToxicTarget", m.Name)
			char:SetAttribute("DiloToxicAt", t) -- last: DiloFX spines
		end
		count("DiloToxicHits")
	end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(function(c) task.defer(watchDilo, pl, c) end)
	if pl.Character then task.defer(watchDilo, pl, pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
