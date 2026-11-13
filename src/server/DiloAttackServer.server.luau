-- DiloAttackServer v1.9 (Mecha Dino Arena) — the Dilophosaurus' Bite + Spit Dart (1.7: spit only) (server authority). MDA-224, plan
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
-- v1.5 (plan docs/plans/DILO_PARTS_v1.0.md Task 4, MDA-317; red-team "Same venom system"): two guarded hooks for the dilo's mecha
--   parts (DiloMovesServer 1.0); bite / dart / leap rules otherwise unchanged.
--   * Venom API: a BindableFunction "DiloVenomApply" under this script; Invoke(target, char, mul) applies the dilo char's own
--     dart venom (DiloVenomDps x Cold Blood's venom mul x mul (default 1), for DiloVenomTime s) to target through applyVenom
--     (the stronger-wins rule, the venom ticks, Venom Feast) when the target is a target (isTarget) and mayAffect allows it;
--     returns true when applied. Switch: script attribute DiloAttackVenomApiEnabled (default true, read at each call; false =
--     returns false). Diagnostic: script DiloVenomApiCalls (applied count).
--   * Venom Overdrive (the dilo's DiloOverdriveUntil > now, stamped by DiloMovesServer; DiloPartOverEnabled true): a dart
--     request skips the "dartCooldown" check, and an accepted dart stamps DiloDartResetAt = now (DiloAttackTest 1.1 clears
--     its own recharge on it, so the dart is ready at once); with DiloPartOverVenomMul > 1 (III) every venom the dilo applies
--     while it runs (dart, bite, Toxic Blood, part venom) has its dps x that mul. Switch: script attribute
--     DiloAttackOverdriveEnabled (default true, read at each use; false = 1.4). Diagnostic: script DiloOverdriveDarts (count).
-- v1.7 (MDA-360, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 "for dilo make the spit the only attack method. remove the
--   bite and make it extra fast", confirmed: tap to spit, a spit every 0.35 s; Venom Bite "Becomes spit poison"). Spit only =
--   script attribute DiloAttackSpitOnlyEnabled ~= false (default true, read at each request / hit) and the dilo character's
--   DiloSpitOnly == true (DiloModelData 1.7):
--   * a "bite" request -> result "spitOnly" (no bite, no DiloBiteAt, no bite pose / FX anywhere);
--   * a "dart" request -> "dartCooldown" when less than DiloSpitGap (0.35; Quick Draw 0.26 / 0.19 / 0.14 / 0.14 through
--     SkillEffects 1.51) minus the script's DiloSpitGapGrace (default 0.05: the client checks the same gap on its own clock, so a
--     tap exactly on the gap may arrive a few ms early) since the last accepted dart; DiloDartCooldown / DiloHoldTime are not
--     used. Venom Overdrive still skips the check.
--   * the dart's venom = (DiloVenomDps + DiloSpitVenomAddDps) x Cold Blood's venom mul for DiloVenomTime + DiloSpitVenomAddTime
--     s (Venom Bite's spit poison, SkillTree 1.75), through the same applyVenom (stronger wins, never stacked). The parts'
--     venom API, Toxic Blood, Venom Feast, Cold Blood, Long Spit and the Deflector / Sap Wall rules are unchanged.
--   Off (switch false or no DiloSpitOnly) = 1.6. Diagnostics: script DiloSpitOnlyDarts, DiloSpitOnlyBiteRefusals (counts);
--   character DiloSpitVenomDps / DiloSpitVenomTime (the last spit dart's venom, before the venom rule).
-- v1.10 (spit ammo, MDA-436, plan docs/plans/DILO_TROO_TUNE_v1.0.md Task 2; Kepu 2026-11-11 "he's given 5 slots then reloads all 5
--   but it takes 3 seconds to reload", picks "Only when empty", Overdrive "Free shots while it runs", Cold Blood "Refills all 5"):
--   while script attribute DiloSpitAmmoEnabled ~= false (default true, read per request) and the character is spit-only with
--   DiloSpitMag > 0 (DiloModelData 1.14: 5; DiloSpitReload 3):
--   * ammo is per character (a new character starts full), published as character DiloSpitLeft (0..mag) and DiloSpitReloadAt
--     (server time the reload ends; 0 when not reloading).
--   * a "dart" request with 0 left -> "reloading" (after the 1.7 gap check); Venom Overdrive running -> no check.
--   * an accepted spit uses one (none while Overdrive runs); reaching 0 starts the reload: DiloSpitReloadAt = now + DiloSpitReload.
--     At that time: mag again, DiloSpitReloadAt 0 (checked every 0.1 s). The reload starts only at 0.
--   * refill to mag (and the reload ends): when the character's DiloDartResetAt changes (the Cold Blood star; Overdrive darts
--     stamp it too) and when DiloOverdriveUntil moves into the future (Overdrive starts).
--   Diagnostics: script DiloSpitAmmoUsed, DiloSpitReloads, DiloSpitRefills, DiloSpitReloadRefusals (counts); character
--   DiloSpitRefillWhy ("reset" / "overdrive").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.1" -- v1.1 dilo stat rows
VERSION = "1.2" -- v1.2 dart hits where it lands (body rule)
VERSION = "1.3" -- v1.3 Deflector Claws
VERSION = "1.4" -- v1.4 animation stamps
VERSION = "1.5" -- v1.5 dilo parts: venom API + Venom Overdrive
VERSION = "1.6" -- v1.6 Sap Wall stops bites / darts through it
VERSION = "1.7" -- v1.7 spit only (no bite; DiloSpitGap; Venom Bite = spit poison)
-- v1.6 (MDA-353) Sap Wall: a live Sap Wall on the attacker (or splash centre) -> target line stops the hit (ServerStorage.DinoArcade
--   SapWallBlock.between). Switch: script attribute DiloAttackServerSapWallEnabled (default true, read at each hit). Diagnostics: script
--   DiloAttackServerSapWallBlocks (count), DiloAttackServerSapWallBlockedAt (server time).
VERSION = "1.8" -- v1.8 armor on every hit (MDA-366)
-- v1.8 (MDA-366, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 "Every attack"): armor (Thick Hide / Armored Hide /
--   Wiry Frame = the victim's StatDamageTakenMul) now cuts spit darts, bites, deflected darts and every spit poison tick (takeHealth; takeHealth now returns what it dealt, Venom Feast heals from that):
--   damage x BoneCrest.armor(victim) (ServerStorage.DinoArcade.BoneCrest 1.7, one shared call). Switch: script attribute
--   DiloAttackServerArmorAllEnabled (default true, read at each hit; false = 1.7). Diagnostic: script DiloAttackServerArmorCuts (count of hits cut).
local sapBlocked do
	local mod
	sapBlocked = function(from, to)
		if script:GetAttribute("DiloAttackServerSapWallEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.between and mod.between(from, to)) then return false end
		script:SetAttribute("DiloAttackServerSapWallBlocks", (script:GetAttribute("DiloAttackServerSapWallBlocks") or 0) + 1)
		script:SetAttribute("DiloAttackServerSapWallBlockedAt", workspace:GetServerTimeNow())
		return true
	end
	if script:GetAttribute("DiloAttackServerSapWallEnabled") == nil then script:SetAttribute("DiloAttackServerSapWallEnabled", true) end
end
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
-- v1.7: spit only (see the header)
if script:GetAttribute("DiloAttackSpitOnlyEnabled") == nil then script:SetAttribute("DiloAttackSpitOnlyEnabled", true) end
if script:GetAttribute("DiloSpitGapGrace") == nil then script:SetAttribute("DiloSpitGapGrace", 0.05) end
for _, k in ipairs({"DiloSpitOnlyDarts", "DiloSpitOnlyBiteRefusals"}) do script:SetAttribute(k, 0) end
local function spitOnly(char)
	return script:GetAttribute("DiloAttackSpitOnlyEnabled") ~= false and char:GetAttribute("DiloSpitOnly") == true
end

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
local armorMul do -- v1.8 (MDA-366): armor on every attack, ServerStorage.DinoArcade.BoneCrest 1.7 armor()
	local mod
	armorMul = function(victim)
		if script:GetAttribute("DiloAttackServerArmorAllEnabled") == false then return 1 end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end) end
		local a = mod and mod.armor and mod.armor(victim) or 1
		if a ~= 1 then script:SetAttribute("DiloAttackServerArmorCuts", (script:GetAttribute("DiloAttackServerArmorCuts") or 0) + 1) end
		return a
	end
	if script:GetAttribute("DiloAttackServerArmorAllEnabled") == nil then script:SetAttribute("DiloAttackServerArmorAllEnabled", true) end
end
local function takeHealth(m, d, killerName, killerId, with, t)
	d *= armorMul(m) -- v1.8 (MDA-366): armor
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
	return d -- v1.8: what was dealt (after armor)
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
					local dealt = takeHealth(m, d, m:GetAttribute("VenomBy") or killerName, killerId, "dilovenom", t) -- v1.8: after armor
					if statsOn() and typeof(hpBefore) == "number" then feast(m:GetAttribute("VenomBy"), math.min(dealt or d, math.max(0, hpBefore)), m) end
					m:SetAttribute("VenomTicks", (m:GetAttribute("VenomTicks") or 0) + 1)
					count("DiloVenomTicks")
				end
			end
		end
		venomLoops[m] = nil
	end)
end
-- v1.5: Venom Overdrive (see the header)
for _, k in ipairs({"DiloAttackVenomApiEnabled", "DiloAttackOverdriveEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
for _, k in ipairs({"DiloVenomApiCalls", "DiloOverdriveDarts"}) do script:SetAttribute(k, 0) end
local function overdriveOn(char, t)
	return script:GetAttribute("DiloAttackOverdriveEnabled") ~= false and char:GetAttribute("DiloPartOverEnabled") == true
		and num(char, "DiloOverdriveUntil", 0) > t
end
-- v1.1: the venom rule (stronger one wins, later end, never stacked); switch off = 1.0's overwrite
local function applyVenom(m, dps, dur, char, player, t)
	if overdriveOn(char, t) then dps *= math.max(1, num(char, "DiloPartOverVenomMul", 1)) end -- v1.5
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
		if inCone and gap(m, origin) <= reach and not sapBlocked(root, m) then -- v1.6: Sap Wall
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
			if rule ~= "miss" and sapBlocked(from, target) then -- v1.6: Sap Wall: the dart stops at the wall
				rule = "miss"
				char:SetAttribute("DiloDartWallAt", ti)
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
							local vDps, vTime = math.max(0, get(char, "DiloVenomDps")), math.max(0, get(char, "DiloVenomTime"))
							if spitOnly(char) then -- v1.7: Venom Bite = spit poison
								vDps += math.max(0, num(char, "DiloSpitVenomAddDps", 0))
								vTime += math.max(0, num(char, "DiloSpitVenomAddTime", 0))
								char:SetAttribute("DiloSpitVenomDps", vDps)
								char:SetAttribute("DiloSpitVenomTime", vTime)
							end
							applyVenom(target, vDps * coldVenomMul(char), vTime, char, player, ti)
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

-- v1.10: spit ammo (see the header)
if script:GetAttribute("DiloSpitAmmoEnabled") == nil then script:SetAttribute("DiloSpitAmmoEnabled", true) end
local AMMO = setmetatable({}, {__mode = "k"}) -- [char] = {left, reloadAt}
local function ammoOn(char)
	return script:GetAttribute("DiloSpitAmmoEnabled") ~= false and spitOnly(char) and num(char, "DiloSpitMag", 0) >= 1
end
local function ammoMag(char) return math.max(1, math.floor(num(char, "DiloSpitMag", 5))) end
local function ammoPublish(char, a)
	if char:GetAttribute("DiloSpitLeft") ~= a.left then char:SetAttribute("DiloSpitLeft", a.left) end
	if char:GetAttribute("DiloSpitReloadAt") ~= a.reloadAt then char:SetAttribute("DiloSpitReloadAt", a.reloadAt) end
end
local function ammoOf(char)
	local a = AMMO[char]
	if a then return a end
	a = {left = ammoMag(char), reloadAt = 0}
	AMMO[char] = a
	local function refill(why)
		if not ammoOn(char) then return end
		a.left, a.reloadAt = ammoMag(char), 0
		ammoPublish(char, a)
		char:SetAttribute("DiloSpitRefillWhy", why)
		count("DiloSpitRefills")
	end
	char:GetAttributeChangedSignal("DiloDartResetAt"):Connect(function() refill("reset") end)
	char:GetAttributeChangedSignal("DiloOverdriveUntil"):Connect(function()
		if num(char, "DiloOverdriveUntil", 0) > now() then refill("overdrive") end
	end)
	ammoPublish(char, a)
	return a
end
task.spawn(function()
	while true do
		task.wait(0.1)
		local t = now()
		for char, a in pairs(AMMO) do
			if a.reloadAt > 0 and t >= a.reloadAt and char.Parent then
				a.left, a.reloadAt = ammoMag(char), 0
				ammoPublish(char, a)
			end
		end
	end
end)
-- spit-only dilos start full on screen too (a new character)
local function ammoWatch(char)
	task.defer(function()
		if char.Parent and ammoOn(char) then ammoOf(char) end
	end)
end
Players.PlayerAdded:Connect(function(pl) pl.CharacterAdded:Connect(ammoWatch) end)
for _, pl in ipairs(Players:GetPlayers()) do
	pl.CharacterAdded:Connect(ammoWatch)
	if pl.Character then ammoWatch(pl.Character) end
end

-- remote --------------------------------------------------------------------------------------------------------------------
local remote = ReplicatedStorage:FindFirstChild("DinoDiloAttack")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoDiloAttack"
	remote.Parent = ReplicatedStorage
end

local function onRemote(player, kind, stamp) -- v1.9: named so BotUse can call it (body unchanged)
	if kind == "snipe" and script:GetAttribute("DiloSnipeEnabled") ~= false then return end -- v1.11: the snipe handler below
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
	local so = not r and spitOnly(char) -- v1.7
	if so and kind == "bite" then
		r = "spitOnly"
		count("DiloSpitOnlyBiteRefusals")
	end
	if so and kind == "dart" and t - st.lastDart < math.max(0, num(char, "DiloSpitGap", 0.35) - math.max(0, num(script, "DiloSpitGapGrace", 0.05)))
		and not overdriveOn(char, t) then r = "dartCooldown" end
	if not r and so and kind == "dart" and ammoOn(char) and not overdriveOn(char, t) and ammoOf(char).left <= 0 then -- v1.10
		r = "reloading"
		count("DiloSpitReloadRefusals")
	end
	if not r and not so and kind == "bite" and t - st.lastBite < math.max(0, get(char, "DiloMinGap")) then r = "cooldown" end
	if not r and not so and kind == "dart" and t - st.lastDart < math.max(0, get(char, "DiloDartCooldown")) and not overdriveOn(char, t) then r = "dartCooldown" end -- v1.5: + Overdrive
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
		if so then count("DiloSpitOnlyDarts") end -- v1.7
		if animStamps() then char:SetAttribute("DiloCoilEndAt", t) end -- v1.4
		fireDart(player, char, t)
		if so and ammoOn(char) and not overdriveOn(char, t) then -- v1.10: one shot used; 0 starts the reload
			local a = ammoOf(char)
			a.left = math.max(0, a.left - 1)
			count("DiloSpitAmmoUsed")
			if a.left <= 0 and a.reloadAt <= 0 then
				a.reloadAt = t + math.max(0, num(char, "DiloSpitReload", 3))
				count("DiloSpitReloads")
			end
			ammoPublish(char, a)
		end
		if overdriveOn(char, t) then -- v1.5: the client's recharge clears too
			char:SetAttribute("DiloDartResetAt", t)
			count("DiloOverdriveDarts")
		end
	end
end
remote.OnServerEvent:Connect(onRemote) -- v1.9

-- v1.11 Sniper spit (MDA-509, plan docs/plans/DILO_SNIPER_SPIT_v1.0.md Task 1, mockup docs/mockups/dilo_sniper_spit_v0.1.html;
--   Kepu 2026-11-13 15:38 "hold the attack button for 1.5s ... no aim assist ... all the damage into one ball with twice the
--   range like a sniper shot", picks "Whole clip: 25, then reload", "Let go of attack"). Remote DinoDiloAttack("snipe", stamp,
--   dir) from DiloAttackTest 1.5 (dir = the head cam's look, a unit Vector3). Checks as the dart (dead / disabled / menu /
--   stunned / dazed / pinned, spit-only), the DiloSpitGap, then a FULL clip ("notFull" when DiloSpitLeft < DiloSpitMag or a
--   reload runs) and the aim within DiloSnipeMaxOff (100) degrees of the body's flat facing ("badAim"). The ball: from the
--   snout along dir (no aim assist), range DiloDartRange x DiloSnipeRangeMul (2) x scale, stopped by the world (a raycast that
--   leaves out every dino); speed DiloDartSpeed x DiloSnipeSpeedMul (2) x scale. At landing every target dino whose hitboxes
--   come within DiloSnipeRadius (1.5) x scale of the flight line (snout -> end) is a candidate and the nearest along the line
--   is hit (it flies straight: lead a moving dino). A Sap Wall between stops it; Deflector Claws / shields / plating as the
--   dart. Damage DiloSnipeDamage (25) x Cold Blood's dart mul; the spit's poison as a dart (Venom Bite + Cold Blood). Uses the
--   whole clip (DiloSpitLeft 0, the usual DiloSpitReload starts). Stamps: DiloDartFrom / To / Target / Flight, DiloSnipeAt (=
--   the shot's time, before) then DiloDartAt (DiloFX draws the dart; DiloFX 1.5 makes it the big ball when DiloSnipeAt ==
--   DiloDartAt); the hit through DiloHitAt as the dart (kind "dart"), DiloSnipeHitRule ("hit" / "miss" / "wall" /
--   "deflected"), DiloSnipeDmg (damage dealt, before the hit stamp). Switch: script attribute DiloSnipeEnabled (default true, read per request; false = 1.10: "snipe" is a
--   badArg). Numbers: script attributes DiloSnipeDamage, DiloSnipeRangeMul, DiloSnipeSpeedMul, DiloSnipeRadius,
--   DiloSnipeMaxOff. Diagnostics: script DiloSnipes, DiloSnipeHits.
do
	local SNIPE = {DiloSnipeEnabled = true, DiloSnipeDamage = 25, DiloSnipeRangeMul = 2, DiloSnipeSpeedMul = 6, DiloSnipeRadius = 1.5, -- v1.12: speed mul 6 (was 2)
		DiloSnipeMaxOff = 100}
	for k, v in pairs(SNIPE) do
		if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
	end
	local function sget(k) return tonumber(script:GetAttribute(k)) or SNIPE[k] end
	local function onLine(m, from, dir, len) -- distance along the line of the body point nearest to it, or nil
		local r = rootOf(m)
		if not r then return nil end
		local u = math.clamp((r.Position - from):Dot(dir), 0, len)
		local best, bestU = math.huge, nil
		for _, du in ipairs({-3, -1.5, 0, 1.5, 3}) do -- a few points along the line around the root's projection
			local uu = math.clamp(u + du, 0, len)
			local g = gap(m, from + dir * uu)
			if g < best then best, bestU = g, uu end
		end
		return best, bestU
	end
	local function snipe(player, char, stamp, dir)
		local t = now()
		local r
		if typeof(stamp) ~= "number" or stamp ~= stamp or typeof(dir) ~= "Vector3" or dir ~= dir or dir.Magnitude < 0.5 or dir.Magnitude > 1.5 then
			r = "badArg"
		elseif not char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
			r = "dead"
		elseif not enabled or char:GetAttribute("DiloAttackEnabled") ~= true or not spitOnly(char) then
			r = "disabled"
		else
			r = blocked(player, char, t)
		end
		local st = track(char)
		if not r and t - st.lastDart < math.max(0, num(char, "DiloSpitGap", 0.35) - math.max(0, num(script, "DiloSpitGapGrace", 0.05))) then
			r = "dartCooldown"
		end
		local a = (not r and ammoOn(char)) and ammoOf(char) or nil
		if not r and a and (a.left < ammoMag(char) or a.reloadAt > 0) then r = "notFull" end
		dir = dir.Unit
		if not r then
			local off = math.deg(math.acos(math.clamp(flat(dir).Magnitude > 1e-3 and flat(dir).Unit:Dot(facing(char)) or 1, -1, 1)))
			if off > sget("DiloSnipeMaxOff") then r = "badAim" end
		end
		if r then
			setResult(char, r, t)
			return
		end
		setResult(char, "ok", t)
		st.lastDart = t
		count("DiloSnipes")
		if animStamps() then char:SetAttribute("DiloCoilEndAt", t) end
		if a then -- the whole clip
			a.left = 0
			if a.reloadAt <= 0 then a.reloadAt = t + math.max(0, num(char, "DiloSpitReload", 3)) end
			ammoPublish(char, a)
		end
		local s = char:GetScale()
		local from = snout(char)
		local range = math.max(0, get(char, "DiloDartRange")) * sget("DiloSnipeRangeMul") * s
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ex = {char}
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
		for _, b in ipairs(bots()) do table.insert(ex, b) end
		for _, n in ipairs({"DiloFX", "TrooPartsFX", "TrooStatsFX"}) do local f = workspace:FindFirstChild(n) if f then table.insert(ex, f) end end
		params.FilterDescendantsInstances = ex
		local hit = workspace:Raycast(from, dir * range, params)
		local len = hit and (hit.Position - from).Magnitude or range
		-- the visual end: the dino on the line now (if any), else the world stop / full range
		local aimT, aimU = nil, len
		for _, m in ipairs(candidates(char)) do
			local g, u = onLine(m, from, dir, len)
			if g and g <= sget("DiloSnipeRadius") * s and u < aimU then aimT, aimU = m, u end
		end
		local to = from + dir * (aimT and aimU or len)
		local speed = math.max(1, get(char, "DiloDartSpeed")) * sget("DiloSnipeSpeedMul") * s
		local flight = (to - from).Magnitude / speed
		char:SetAttribute("DiloDartFrom", from)
		char:SetAttribute("DiloDartTo", to)
		char:SetAttribute("DiloDartTarget", aimT and aimT.Name or "")
		char:SetAttribute("DiloDartFlight", flight)
		char:SetAttribute("DiloSnipeAt", t)
		char:SetAttribute("DiloDartAt", t) -- last: poses + FX
		task.delay(flight, function()
			local ti = now()
			if not char.Parent then return end
			local target, tu = nil, len
			for _, m in ipairs(candidates(char)) do
				local g, u = onLine(m, from, dir, len)
				if g and g <= sget("DiloSnipeRadius") * s and u < tu then target, tu = m, u end
			end
			local names, point, rule = {}, to, "miss"
			if target then
				point = from + dir * tu
				rule = "hit"
				if sapBlocked(from, target) then
					rule = "wall"
					char:SetAttribute("DiloDartWallAt", ti)
				else
					local defl, refl = deflected(target, from, "dart", ti, "DiloAttackDeflectEnabled")
					if defl then
						rule = "deflected"
						if refl then
							local tp = Players:GetPlayerFromCharacter(target)
							takeHealth(char, sget("DiloSnipeDamage") * coldDartMul(char), target.Name, tp and tp.UserId or 0, "deflect", ti)
						end
					end
				end
				if rule == "hit" then
					if not shielded(target, ti) then
						local dmg = math.max(0, sget("DiloSnipeDamage")) * coldDartMul(char)
						local dealt = dmg * takenMul(target, ti) * plating(target, from)
						takeHealth(target, dealt, char.Name, player.UserId, "dilosnipe", ti)
						char:SetAttribute("DiloSnipeDmg", dealt) -- DiloFX 1.5's pop (before the hit stamp)
						if statsOn() and isTarget(target, char) then
							local vDps, vTime = math.max(0, get(char, "DiloVenomDps")), math.max(0, get(char, "DiloVenomTime"))
							vDps += math.max(0, num(char, "DiloSpitVenomAddDps", 0))
							vTime += math.max(0, num(char, "DiloSpitVenomAddTime", 0))
							applyVenom(target, vDps * coldVenomMul(char), vTime, char, player, ti)
						end
					end
					table.insert(names, target.Name)
					count("DiloSnipeHits")
				end
			end
			char:SetAttribute("DiloSnipeHitRule", rule)
			count("DiloAttackHits", #names)
			stampHit(char, "dart", names, point, ti)
		end)
	end
	remote.OnServerEvent:Connect(function(player, kind, stamp, dir)
		if kind ~= "snipe" or script:GetAttribute("DiloSnipeEnabled") == false then return end
		local char = player.Character
		if char then snipe(player, char, stamp, dir) end
	end)
end

-- v1.9 BotUse (practice bots, MDA-410, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 6, ADR-010; Kepu 2026-11-10 "Real abilities"):
--   server-only BindableFunction "BotUse" (child): Invoke(model, ...same arguments as the remote...) runs the remote handler above
--   (onRemote, its body unchanged) with ServerStorage.DinoArcade.BotProxy.of(model) for the player. Only models with
--   PracticeBot = true. Returns "ok" (the handler ran; its own result is on the model as usual), "off", "badArg" or
--   "botUnsupported" (the handler errored; script attribute DiloAttackBotUseError keeps the message). Switch: script attribute
--   DiloAttackBotUseEnabled (default true).
do
	if script:GetAttribute("DiloAttackBotUseEnabled") == nil then script:SetAttribute("DiloAttackBotUseEnabled", true) end
	script:SetAttribute("DiloAttackServerVersion", "1.9")
	local proxyModule = game:GetService("ServerStorage"):WaitForChild("DinoArcade"):FindFirstChild("BotProxy")
	local BotProxy = proxyModule and require(proxyModule)
	local fn = script:FindFirstChild("BotUse") or Instance.new("BindableFunction")
	fn.Name = "BotUse"
	fn.OnInvoke = function(model, ...)
		if script:GetAttribute("DiloAttackBotUseEnabled") == false then return "off" end
		if not BotProxy or typeof(model) ~= "Instance" or model:GetAttribute("PracticeBot") ~= true or not model.Parent then return "badArg" end
		local ok, err = pcall(onRemote, BotProxy.of(model), ...)
		if not ok then
			script:SetAttribute("DiloAttackBotUseError", tostring(err))
			return "botUnsupported"
		end
		return "ok"
	end
	fn.Parent = script
end


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

-- v1.5: the venom API for the dilo's mecha parts (see the header) --------------------------------------------------------------
do
	local fn = Instance.new("BindableFunction")
	fn.Name = "DiloVenomApply"
	fn.OnInvoke = function(target, char, mul)
		if script:GetAttribute("DiloAttackVenomApiEnabled") == false then return false end
		if typeof(target) ~= "Instance" or not target:IsA("Model") or typeof(char) ~= "Instance" or not char:IsA("Model") then return false end
		if target == char or not isTarget(target, char) or not mayAffect(char, target) then return false end
		local t = now()
		local m = tonumber(mul) or 1
		local dps = math.max(0, get(char, "DiloVenomDps")) * coldVenomMul(char) * math.max(0, m)
		local dur = math.max(0, get(char, "DiloVenomTime"))
		if dps <= 0 or dur <= 0 then return false end
		applyVenom(target, dps, dur, char, Players:GetPlayerFromCharacter(char), t)
		count("DiloVenomApiCalls")
		return true
	end
	fn.Parent = script
end
script:SetAttribute("DiloAttackServerVersion", "1.10") -- v1.10 spit ammo (after the 1.9 BotUse block's stamp)
script:SetAttribute("DiloAttackServerVersion", "1.11") -- v1.11 sniper spit (MDA-509)
-- v1.12 (Kepu 2026-11-13 16:10 "I don't like ... the travel speed of the shot", pick "Much faster: 240/s"): DiloSnipeSpeedMul
--   default 6 (was 2): the ball flies DiloDartSpeed 40 x 6 = 240 studs/s x scale (full range 120 studs in 0.5 s).
script:SetAttribute("DiloAttackServerVersion", "1.12") -- v1.12 sniper ball 240 studs/s
