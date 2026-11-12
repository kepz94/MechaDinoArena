-- DiloMovesServer v1.10 (Mecha Dino Arena) — the Dilophosaurus' mecha button parts, build 1 (server authority): Venom Gatling,
-- Toxin Mortar, Spine Burst, Venom Overdrive. Plan docs/plans/DILO_PARTS_v1.0.md Task 5 (deterministic map), MDA-318; mockup
-- docs/mockups/dilo_parts_options.html v0.1 (timings from tools/mockup/dilo_parts_looks.js); Kepu 2026-11-06 picks + red-team
-- "Same venom system", "Use the proposals". Build 2 (Sonic Hiss, Antivenom Pump, Spring Jets) comes in 1.1.
-- Settings (character attributes, SkillEffects 1.45, written while bought AND slotted): DiloPartGatling* (Enabled, Count,
--   Damage, Cone, Time, Cooldown), DiloPartMortar* (Enabled, Range, Radius, Time, Cooldown), DiloPartSpine* (Enabled, Count,
--   Damage, Range, Venom, Cooldown), DiloPartOver* (Enabled, Time, VenomMul, Cooldown). Distances are studs in the game (the
--   Lab texts); only the gatling's dart reach is the dilo's own DiloDartRange x Model scale (Long Spit counts).
-- Remotes (ReplicatedStorage, client -> server, sent by MechaButtons 1.35): DinoDiloGatlingRequest(stamp, aimDir),
--   DinoDiloMortarRequest(stamp, aimDir, aimPoint), DinoDiloSpineRequest(stamp), DinoDiloOverRequest(stamp).
-- Checks in order -> character <Prefix>ServerResult (+ ResultAt), prefix DiloPartGatling / Mortar / Spine / Over: "badArg"
--   (stamp not a number, aimDir not a unit-ish Vector3, aimPoint not a Vector3), "dead", "disabled" (script switches or
--   <Prefix>Enabled ~= true), "menu", "stunned", "pinned", "dazed", "silenced" (SilencedUntil > now, Sonic Hiss, build 2),
--   "cooldown" (now < <Prefix>ReadyAt); else "ok" and <Prefix>ReadyAt = now + <Prefix>Cooldown (counted from the press).
--   A wind-up cut short (dead / stunned / dazed / pinned when it should fire) -> <Prefix>ServerResult "cancelled" (the
--   recharge stays). Targets: player characters and Workspace.DinoIsland.Bots models that are Bitable with Hitboxes, alive,
--   not KO; squadmates never (SquadRules.sameChar); players only where ModeRules.canAffect allows (the Arena); bots always.
-- Venom: every part venom goes through DiloAttackServer 1.5's BindableFunction DiloVenomApply(target, char) (the dilo's own
--   dart venom, the stronger-wins rule, the ticks, Venom Feast, Cold Blood, Overdrive x2). Damage: DummyHealth minus the
--   hit x the target's taken mul (roar debuff, daze), nothing through EnergyShieldUntil (TheriMovesServer's rule).
-- * Venom Gatling (wind-up GATLING_WINDUP 0.4 s: the barrels spin up): DiloPartGatlingCount darts over DiloPartGatlingTime s,
--   alternating the two hood barrels (Attachments DPartMuzzle_1 / _2 on the Neck Root, DiloPartsServer 1.0); each locks the
--   nearest target within DiloPartGatlingCone (25) degrees of the aim heading and the dart reach, else flies straight to the
--   reach; flight = distance / (DiloDartSpeed x scale); hit at the arrival by the dart's rules (root within 4 x scale of the
--   aim point, or a hitbox within 1.5 x scale): DiloPartGatlingDamage (3) + dart venom. Stamps: DiloGatlingAt (the press,
--   last of its group, with DiloGatlingCount / DiloGatlingWindup / DiloGatlingTime); per dart DiloGatlingShot =
--   "i;fx,fy,fz;tx,ty,tz;flight;target" (FX); per hit DiloGatlingHit = "name;i" (pops).
-- * Toxin Mortar (wind-up MORTAR_WINDUP 0.55 s, flight MORTAR_FLIGHT 1.15 s): the landing point is aimPoint (else the aim
--   heading x the reach), its flat distance from the root clamped to DiloPartMortarRange, Y = the ground under it. The cloud
--   (radius DiloPartMortarRadius studs, DiloPartMortarTime s from the landing): every CLOUD_TICK 0.5 s each target whose root
--   is within the radius (flat) and 12 studs up / down gets dart venom (refreshed, not stacked). Stamps: DiloMortarFrom /
--   DiloMortarTo / DiloMortarFlight / DiloMortarRadius / DiloMortarTime then DiloMortarAt (the press, last); DiloMortarFireAt;
--   DiloMortarLandAt (the cloud starts).
-- * Spine Burst (wind-up SPINE_WINDUP 0.42 s: the frill flares): DiloPartSpineCount spines evenly round the dilo (the first
--   straight ahead), DiloPartSpineRange studs each, judged at the burst like Feather Barrage lines (a target counts each
--   spine whose line passes within SPINE_WIDTH 1.5 studs of its hitboxes, at its root height); the damage lands
--   SPINE_FLIGHT 0.2 s later: DiloPartSpineDamage per spine; DiloPartSpineVenom (III) adds dart venom once per hit dino.
--   Stamps: DiloSpineCount, DiloSpineHits ("name=n|..."), DiloSpineAt (the press, last); DiloSpineBurstAt.
-- * Venom Overdrive (wind-up OVER_WINDUP 0.7 s: the reactor charges, a roar): DiloOverdriveAt (the press), DiloOverdriveStartAt
--   (= press + wind-up), DiloOverdriveUntil (= start + DiloPartOverTime, last). DiloAttackServer 1.5 reads it.
-- Switches: script DiloMovesServerEnabled, DiloMoves_<id>Enabled (dgatling / dmortar / dspine / dover), DiloMovesModeRulesEnabled,
--   DiloMovesSquadEnabled (default true, read at each use). Diagnostics: script DiloMovesServerVersion, DiloMovesHits,
--   DiloMovesVenoms, DiloMovesSquadSkips, DiloMovesMode.
-- v1.1 (dilo parts build 2, MDA-320, plan docs/plans/DILO_PARTS_v1.0.md Task 7; Kepu 2026-11-06 "Publish then build"; red-team
--   1 "Buttons + dilo server", 2 "One watcher", 3 "Same venom system"; timings from tools/mockup/dilo_parts_looks.js v0.1).
--   Settings (SkillEffects 1.45, live with SkillTree 1.70): DiloPartHiss* (Enabled, Range, Angle, Knock, Silence, Cooldown),
--   DiloPartPump* (Enabled, Heal, Immune, Cooldown), DiloPartJets* (Enabled, Dist, Charges, Trail, Cooldown). Same check()
--   order and results as 1.0. Remotes: DinoDiloHissRequest(stamp), DinoDiloPumpRequest(stamp), DinoDiloJetsRequest(stamp,
--   moveDir) (MechaButtons 1.36).
-- * Sonic Hiss (wind-up HISS_WINDUP 0.5 s: the hood flares, the speakers charge): at the blast, every target whose root is
--   within DiloPartHissRange studs (flat) and DiloPartHissAngle (35) degrees of the dilo's facing (or within 4 x scale/2 studs,
--   any angle) and 12 studs up / down: pushed DiloPartHissKnock studs straight away (players: HeadbuttShove 1.0's stamps
--   HeadbuttShoveFrom / Dist / Time HISS_SHOVE_TIME 0.3 / At, like TenoAttackServer 1.4; bots: an anchored glide over the
--   same time unless latched / anchored) and SilencedUntil = max(old, now + DiloPartHissSilence), SilencedBy (dilo name),
--   SilencedAt (last). No damage. Stamps: DiloHissWindup / DiloHissRange / DiloHissAngle, DiloHissAt (the press, last);
--   DiloHissHits ("name|..."), DiloHissBlastAt (the blast).
-- * Antivenom Pump (wind-up PUMP_WINDUP 0.62 s: the piston primes): at the jolt every clearable tag on the dilo still in the
--   future is set to now: VenomUntil, StunnedUntil, DazedUntil, InkedUntil and SprintTest 1.20's slow tags ScreechSlowUntil,
--   MineSlowUntil, HeadbuttSlowUntil, SmokeSlowUntil, CaltropSlowUntil, GooSlowUntil, TenoSlowUntil (the pachy's own
--   HeadbuttSelfSlowUntil is not a debuff and stays); Humanoid.Health += DiloPartPumpHeal (capped at MaxHealth); with
--   DiloPartPumpImmune > 0 (the star): DiloImmuneUntil = now + DiloPartPumpImmune. Stamps: DiloPumpWindup, DiloPumpAt (the
--   press, last); DiloPumpCleared ("Tag|..."), DiloPumpHealed (0.1 steps), DiloPumpJoltAt (the jolt).
--   Immunity watcher (red-team 2, the only place): while DiloImmuneUntil > now, any change that puts StunnedUntil, DazedUntil,
--   InkedUntil or one of the slow tags above into the future on that dilo is set back to now (task.defer) and DiloImmuneBlockAt
--   = now (FX). Venom is not blocked (the star text: slows, stuns and blinds).
-- * Spring Jets: DiloPartJetsCharges charges, each back DiloPartJetsCooldown s after its use (TheriMovesServer 1.4's grapple
--   refills): DiloPartJetsLeft, DiloPartJetsReadyAt (= now while a charge is left, else the next refill). Direction = flat
--   moveDir (the client sends its move direction, or the camera's flat look when standing), else the root's look. A world ray
--   from the root along it, DiloPartJetsDist studs: a hit -> the dash stops 3 x scale/2 short; under JETS_MIN (4) studs ->
--   DiloJetsResult "blocked", no charge used. The end keeps the start's height above the ground. Stamps: DiloJetsFrom,
--   DiloJetsTo, DiloJetsDelay (JETS_DELAY 0.34, the wind-up), DiloJetsTime (clamp(distance / JETS_SPEED 150, 0.15, 0.3)),
--   DiloJetsResult "dash", DiloJetsAt (last; DiloJetsLaunch 1.0 moves the owner). With DiloPartJetsTrail > 0 (III): a poison
--   trail along From -> To for DiloPartJetsTrail s from the dash's end: every TRAIL_TICK 0.5 s each target whose root is within
--   TRAIL_WIDTH (4) x scale/2 studs of the segment (flat, 12 up / down) gets dart venom (DiloVenomApply); DiloJetsTrailUntil.
-- Switches: script DiloMoves_dhissEnabled, DiloMoves_dpumpEnabled, DiloMoves_djetsEnabled, DiloMovesImmuneWatchEnabled (default
--   true, read at each use; false = 1.0 for that move). Diagnostics: DiloMovesSilenced, DiloMovesCleared, DiloMovesImmuneBlocks,
--   DiloMovesJets.
-- v1.2 (MDA-327, plan docs/plans/FIXES_2026-11-06_v1.0.md Fix 5; Kepu 2026-11-06 04:27 "Pump: work while stunned", 12:01
--   "Let's build it"): the Antivenom Pump breaks free.
--   * Break free: check() skips the "stunned" (StunnedUntil) and "dazed" (DazedUntil) refusals for dpump only (pinned /
--     silenced / dead / menu / cooldown unchanged), and the pump's wind-up is not cancelled by a stun / daze (death / pin
--     still cancel). The jolt then clears the stun / daze as before. Switch: script DiloPumpBreakFreeEnabled (default true,
--     read at each press; false = 1.1). Diagnostic: DiloMovesBreakFree (presses made while stunned or dazed).
--   * Clear more: the jolt also sets SkillBleedUntil, SlashBleedUntil, CaltropBleedUntil and the roar debuff DebuffUntil (RoarServer
--     applyDebuff) to now when in the future; clearing DebuffUntil also sets DebuffState "none" (RoarServer's own reset only
--     fires when DebuffUntil is unchanged). The immunity watcher list is unchanged. Switch: script DiloPumpClearMoreEnabled
--     (default true, read at each jolt; false = 1.1).
-- v1.3 (MDA-329, plan docs/plans/DILO_PARTS_FIT_v1.0.md Task 2; Kepu 2026-11-06 12:22 "This dash has a fucking pause before it
--   takes off" -> "Instant burst + Thrusters FX"): Spring Jets has no wind-up. The dash is stamped DiloJetsDelay 0 (was
--   JETS_DELAY 0.34) and the trail starts after the burst alone; distance, charges, recharge and trail unchanged. The owner's
--   client already starts the burst on the press (DiloJetsLaunch 1.1). Switch: script DiloJetsInstantEnabled (default true,
--   read at each press; false = the 0.34 s wind-up of 1.1).
-- v1.12 (Bots v2, MDA-471, plan docs/plans/BOTS_V2_v1.0.md T7; Kepu 2026-11-11 20:39 "the damn bots don't even use their
--   attack buttons or their mecha"): a bot entrance. Every remote handler of this script is connected through botHook(remote)
--   (handler bodies unchanged), which also files it by the remote's name. Server-only BindableFunction "BotMechaUse" (child):
--   Invoke(model, remoteName, ...the remote's own arguments...) runs every handler filed for that remote, in order, with
--   ServerStorage.DinoArcade.BotProxy.of(model) as the player (the model is its Character; PracticeBot models only).
--   Returns "ok" (the handlers ran; their results land on the model as for a player), "off", "badArg", "noHandler" or
--   "botUnsupported" (a handler errored; script attribute DiloMovesServerBotMechaError keeps "<remote>: <error>").
--   Switch: script attribute DiloMovesServerBotMechaEnabled (default true, read per call).
--   The first call for a bot also runs this script's player-join handlers (Players.PlayerAdded, filed through botJoin) with
--   the proxy and waits 0.2 s, so the bot's character is set up here like a player's (BotProxy 1.1 gives the proxy stub
--   CharacterAdded / CharacterRemoving signals).
local __botHandlers = {} -- v1.12: remote name -> handlers (see the header)
local function botHook(remote)
	return {Connect = function(_, fn)
		local list = __botHandlers[remote.Name] or {}
		__botHandlers[remote.Name] = list
		table.insert(list, fn)
		return remote.OnServerEvent:Connect(fn)
	end}
end
local __botJoiners = {} -- v1.12: player-join handlers (see the header)
local function botJoin(signal)
	return {Connect = function(_, fn)
		table.insert(__botJoiners, fn)
		return signal:Connect(fn)
	end}
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 Sonic Hiss, Antivenom Pump, Spring Jets
VERSION = "1.2" -- v1.2 the pump breaks free + clears bleeds / the roar debuff
VERSION = "1.3" -- v1.3 Spring Jets without the wind-up
VERSION = "1.4" -- v1.4 Sap Wall stops gatling darts / spines / the hiss through it
-- v1.4 (MDA-353) Sap Wall: a live Sap Wall on the attacker (or splash centre) -> target line stops the hit (ServerStorage.DinoArcade
--   SapWallBlock.between). Switch: script attribute DiloMovesServerSapWallEnabled (default true, read at each hit). Diagnostics: script
--   DiloMovesServerSapWallBlocks (count), DiloMovesServerSapWallBlockedAt (server time).
local sapBlocked do
	local mod
	sapBlocked = function(from, to)
		if script:GetAttribute("DiloMovesServerSapWallEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.between and mod.between(from, to)) then return false end
		script:SetAttribute("DiloMovesServerSapWallBlocks", (script:GetAttribute("DiloMovesServerSapWallBlocks") or 0) + 1)
		script:SetAttribute("DiloMovesServerSapWallBlockedAt", workspace:GetServerTimeNow())
		return true
	end
	if script:GetAttribute("DiloMovesServerSapWallEnabled") == nil then script:SetAttribute("DiloMovesServerSapWallEnabled", true) end
end
VERSION = "1.5" -- v1.5 a mortar canister whose arc goes through a Sap Wall is stopped; the cloud checks the wall
-- v1.5 (MDA-353, Kepu 2026-11-07 lobbed shots "Can go over"): the Toxin Mortar canister's real flight (DiloMovesFX 1.x: DiloMortarFrom -> DiloMortarTo,
--   4 x (|dY| + DiloMovesMortarArc (6.5) x scale / 2) x u x (1 - u) above the line) is checked at the landing by SapWallBlock
--   1.2 arcBlocks: an arc through a live wall stops it (no DiloMortarLandAt, no cloud; character DiloMortarWallAt), an arc
--   over the wall lands as before. The cloud's venom ticks now check the cloud centre -> target line too (the MDA-353 splash
--   rule the 1.4 hooks missed; switch DiloMovesSapCloudEnabled, default true).
--   Switch: script attribute DiloMovesServerSapArcEnabled (default true, read at each shot; false = the previous behaviour: no check of the
--   flight itself). Diagnostics: script DiloMovesServerSapArcBlocks (count), DiloMovesServerSapArcBlockedAt (server time).
VERSION = "1.6" -- v1.6 shot pass: faster shots, strong aim assist
-- v1.6 (Kepu 2026-11-09 "all the projectile shots need to be faster and more auto aim assist on it and longer range"
--   -> 1.5x faster, 2x range, "Strong" assist = snap to a target within 45 degrees of the aim; plan
--   docs/plans/SHOT_PASS_v1.0.md): Toxin Mortar flight MORTAR_FLIGHT / 1.5 (DiloMortarFlight); if no enemy is within
--   the cloud radius of the aimed spot, the canister lands on the nearest enemy within 45 degrees of the aim and
--   within DiloPartMortarRange (diag DiloMortarAssist = its name or ""); Spine Burst flight SPINE_FLIGHT / 1.5,
--   published as DiloSpineFlight with the reach DiloSpineRange (DiloMovesFX 1.4 flies the spines that far). Ranges
--   (mortar, spines) and the Gatling cone come from SkillTree 1.74; the Gatling darts use the dart speed / range
--   from DiloModelData 1.6. Switch: script attribute ShotPassEnabled (default true; false = 1.5).
VERSION = "1.7" -- v1.7 no movement moves while snared
-- v1.7 (MDA-356; Kepu 2026-11-08 "pachy headbutt when trapped by zino still works which defeats the purpose of throwing a trap" -> "No movement moves"): Spring Jets (djets) are refused "snared" while the character's
--   TheriSnaredUntil (Snare Wires bola) or HookHeldUntil (Reaper Hook / Grappling Hook hold) is after now (the PinHeld pattern;
--   bites and attacks that stay in place still work; the Troodon's Feather Shed still breaks out). Switch: script
--   attribute DiloMovesSnareBlockEnabled (default true, read at each request; false = 1.6). Diagnostic: script
--   DiloMovesSnareRefusals (count).
if script:GetAttribute("DiloMovesSnareBlockEnabled") == nil then script:SetAttribute("DiloMovesSnareBlockEnabled", true) end -- v1.7
local function snareBlocked(char) -- v1.7: Snare Wires bola / Reaper Hook hold
	if script:GetAttribute("DiloMovesSnareBlockEnabled") == false then return false end
	local t = workspace:GetServerTimeNow()
	local on = (tonumber(char:GetAttribute("TheriSnaredUntil")) or 0) > t or (tonumber(char:GetAttribute("HookHeldUntil")) or 0) > t
	if on then script:SetAttribute("DiloMovesSnareRefusals", (script:GetAttribute("DiloMovesSnareRefusals") or 0) + 1) end
	return on
end
local SNARE_MOVES = {djets = true} -- v1.7: the movement parts
VERSION = "1.8" -- v1.8 faster Spring Jets, the gatling keeps its dart speed
-- v1.8 (Kepu 2026-11-09 Spring Jets "a bit longer" -> "Longer + faster"; spit "Dart flies slower"): the Spring Jets burst
--   speed JETS_SPEED 150 -> JETS_SPEED_V18 200 (the dash time is still clamped 0.15..0.3 s; the distances 40 / 50 / 65 come from
--   SkillTree 1.76); the Venom Gatling's darts fly at the character attribute DiloGatlingDartSpeed (DiloModelData 1.8: 67.5,
--   the shot-pass speed) instead of DiloDartSpeed (now 45, the spit). Switch: script attribute DiloMovesV18Enabled (default
--   true, read at each dash / shot; false = 1.7).
local JETS_SPEED_V18 = 200 -- v1.8
if script:GetAttribute("DiloMovesV18Enabled") == nil then script:SetAttribute("DiloMovesV18Enabled", true) end -- v1.8
local function v18() return script:GetAttribute("DiloMovesV18Enabled") ~= false end -- v1.8
VERSION = "1.9" -- v1.9 faster Toxin Mortar
-- v1.9 (Kepu 2026-11-09 "the mortar it should be faster" -> both mortars, "2x flight + half wind-up"): the Toxin Mortar's
--   wind-up MORTAR_WINDUP / 2 (0.55 -> 0.275 s, DiloMortarWindup) and flight / 2 (0.77 -> 0.38 s, DiloMortarFlight). Switch:
--   script attribute DiloMortarFastEnabled (default true, read at each shot; false = 1.8).
VERSION = "1.10" -- v1.10 armor on every hit (MDA-366)
VERSION = "1.11" -- v1.11 bigger Sonic Hiss
-- v1.11 (MDA-438, plan docs/plans/DILO_TROO_TUNE_v1.0.md Task 4; Kepu 2026-11-11 "Dilo sonic his range doubled in both width and
--   length", pick "B · 2x long + 2x wider cone"): at each Sonic Hiss press the range x script attribute DiloPartHissRangeMul (2:
--   20 / 25 / 30 -> 40 / 50 / 60) and the half angle x DiloPartHissAngleMul (2: 35 -> 70, a 140° cone; at most 90). The
--   DiloHissRange / DiloHissAngle stamps carry the new numbers, so DiloMovesFX / DiloPartsVFX draw the new size. Knock, silence,
--   the near ring and the height rule unchanged. Switch: script attribute DiloHissBigEnabled (default true, read at each press;
--   false = 1.10).
for k, v in pairs({DiloHissBigEnabled = true, DiloPartHissRangeMul = 2, DiloPartHissAngleMul = 2}) do -- v1.11
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
-- v1.10 (MDA-366, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 "Every attack"): armor (Thick Hide / Armored Hide /
--   Wiry Frame = the victim's StatDamageTakenMul) now cuts Venom Gatling darts and spine bursts (damage):
--   damage x BoneCrest.armor(victim) (ServerStorage.DinoArcade.BoneCrest 1.7, one shared call). Switch: script attribute
--   DiloMovesServerArmorAllEnabled (default true, read at each hit; false = 1.9). Diagnostic: script DiloMovesServerArmorCuts (count of hits cut).
if script:GetAttribute("DiloMortarFastEnabled") == nil then script:SetAttribute("DiloMortarFastEnabled", true) end -- v1.9
local SHOT_SPEED_MUL, SHOT_ASSIST_DEG = 1.5, 45 -- v1.6
local function shotPass() return script:GetAttribute("ShotPassEnabled") ~= false end -- v1.6
if script:GetAttribute("ShotPassEnabled") == nil then script:SetAttribute("ShotPassEnabled", true) end -- v1.6
if script:GetAttribute("DiloMovesMortarArc") == nil then script:SetAttribute("DiloMovesMortarArc", 6.5) end
if script:GetAttribute("DiloMovesSapCloudEnabled") == nil then script:SetAttribute("DiloMovesSapCloudEnabled", true) end
local sapArcBlocked do
	local mod
	sapArcBlocked = function(from, to, peak)
		if script:GetAttribute("DiloMovesServerSapArcEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.arcBlocks) then return false end
		local b, _, u, pos = mod.arcBlocks(from, to, peak)
		if not b then return false end
		script:SetAttribute("DiloMovesServerSapArcBlocks", (script:GetAttribute("DiloMovesServerSapArcBlocks") or 0) + 1)
		script:SetAttribute("DiloMovesServerSapArcBlockedAt", workspace:GetServerTimeNow())
		return true, u, pos
	end
	if script:GetAttribute("DiloMovesServerSapArcEnabled") == nil then script:SetAttribute("DiloMovesServerSapArcEnabled", true) end
end
if script:GetAttribute("DiloJetsInstantEnabled") == nil then script:SetAttribute("DiloJetsInstantEnabled", true) end -- v1.3
local GATLING_WINDUP, MORTAR_WINDUP, MORTAR_FLIGHT, SPINE_WINDUP, SPINE_FLIGHT, OVER_WINDUP = 0.4, 0.55, 1.15, 0.42, 0.2, 0.7
local CLOUD_TICK, CLOUD_HEIGHT = 0.5, 12
local SPINE_WIDTH = 1.5
local DART_TOLERANCE, DART_BODY_REACH = 4, 1.5

script:SetAttribute("DiloMovesServerVersion", VERSION)
for _, k in ipairs({"DiloMovesHits", "DiloMovesVenoms", "DiloMovesSquadSkips"}) do script:SetAttribute(k, 0) end
for _, k in ipairs({"DiloMovesServerEnabled", "DiloMoves_dgatlingEnabled", "DiloMoves_dmortarEnabled", "DiloMoves_dspineEnabled",
	"DiloMoves_doverEnabled", "DiloMovesModeRulesEnabled", "DiloMovesSquadEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(id)
	return script:GetAttribute("DiloMovesServerEnabled") ~= false and script:GetAttribute("DiloMoves_" .. id .. "Enabled") ~= false
end
local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
for _, k in ipairs({"DiloPumpBreakFreeEnabled", "DiloPumpClearMoreEnabled"}) do -- v1.2
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
script:SetAttribute("DiloMovesBreakFree", 0) -- v1.2
local function breakFree(id) -- v1.2: the pump may be used while stunned / dazed
	return id == "dpump" and script:GetAttribute("DiloPumpBreakFreeEnabled") ~= false
end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end
local function v3s(v) return ("%.2f,%.2f,%.2f"):format(v.X, v.Y, v.Z) end

-- mode + squad rules (TheriMovesServer 1.0) --------------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("DiloMovesMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("DiloMovesSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("DiloMovesSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("DiloMovesModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
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
local gatlingRemote, mortarRemote = remote("DinoDiloGatlingRequest"), remote("DinoDiloMortarRequest")
local spineRemote, overRemote = remote("DinoDiloSpineRequest"), remote("DinoDiloOverRequest")

-- targets (TheriMovesServer 1.0 rules) ---------------------------------------------------------------------------------------------
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
local function stillTarget(char, m) return m.Parent ~= nil and isTarget(m, char) and mayAffect(char, m) end
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
local armorMul do -- v1.10 (MDA-366): armor on every attack, ServerStorage.DinoArcade.BoneCrest 1.7 armor()
	local mod
	armorMul = function(victim)
		if script:GetAttribute("DiloMovesServerArmorAllEnabled") == false then return 1 end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end) end
		local a = mod and mod.armor and mod.armor(victim) or 1
		if a ~= 1 then script:SetAttribute("DiloMovesServerArmorCuts", (script:GetAttribute("DiloMovesServerArmorCuts") or 0) + 1) end
		return a
	end
	if script:GetAttribute("DiloMovesServerArmorAllEnabled") == nil then script:SetAttribute("DiloMovesServerArmorAllEnabled", true) end
end
local function damage(char, player, m, base, with, t)
	if shielded(m, t) then return 0 end
	local d = math.max(0, base) * takenMul(m, t) * armorMul(m) -- v1.10 (MDA-366): armor
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return 0 end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", with)
		m:SetAttribute("KilledAt", t) -- last
	end
	count("DiloMovesHits")
	return d
end
-- the dart venom, through DiloAttackServer 1.5 (red-team "Same venom system")
local venomFn
local function venom(char, m)
	if not (venomFn and venomFn.Parent) then
		local s = ServerScriptService:FindFirstChild("DiloAttackServer")
		venomFn = s and s:FindFirstChild("DiloVenomApply")
	end
	if not venomFn or shielded(m, now()) then return false end
	local ok, res = pcall(function() return venomFn:Invoke(m, char, 1) end)
	if ok and res == true then
		count("DiloMovesVenoms")
		return true
	end
	return false
end

-- world -------------------------------------------------------------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function worldOnly()
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX", "PachyFX_Local", "DiloFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rayParams.FilterDescendantsInstances = ex
	return rayParams
end
local function groundY(pos, fallback)
	local g = workspace:Raycast(Vector3.new(pos.X, pos.Y + 60, pos.Z), Vector3.new(0, -200, 0), worldOnly())
	return g and g.Position.Y or fallback
end

-- request checks (TheriMovesServer 1.0 + silenced) -----------------------------------------------------------------------------------
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
	elseif not on(id) or char:GetAttribute(prefix .. "Enabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif num(char, "StunnedUntil", 0) > t and not breakFree(id) then -- v1.2: not for the pump
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif SNARE_MOVES[id] and snareBlocked(char) then -- v1.7
		r = "snared"
	elseif num(char, "DazedUntil", 0) > t and not breakFree(id) then -- v1.2: not for the pump
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
local function ok(char, prefix, t)
	char:SetAttribute(prefix .. "ServerResult", "ok")
	char:SetAttribute(prefix .. "ServerResultAt", t)
	char:SetAttribute(prefix .. "ReadyAt", t + math.max(0.5, num(char, prefix .. "Cooldown", 15)))
end
local function canStill(char, freeOk) -- v1.2: freeOk = a stun / daze doesn't cancel (the pump breaking free)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	return char.Parent ~= nil and hum ~= nil and hum.Health > 0 and rootOf(char) ~= nil and (freeOk or num(char, "StunnedUntil", 0) <= t)
		and (freeOk or num(char, "DazedUntil", 0) <= t) and char:GetAttribute("PinHeld") ~= true
end
local function cancel(char, prefix)
	char:SetAttribute(prefix .. "ServerResult", "cancelled")
	char:SetAttribute(prefix .. "ServerResultAt", now())
end
local function heading(char, aimDir)
	local d = typeof(aimDir) == "Vector3" and flat(aimDir) or Vector3.zero
	if d.Magnitude < 1e-3 then d = flat(rootOf(char).CFrame.LookVector) end
	return d.Magnitude > 1e-3 and d.Unit or -Vector3.zAxis
end
local function muzzles(char)
	local out = {}
	local neck = char:FindFirstChild("Neck")
	local root = neck and neck:FindFirstChild("Root")
	for i = 1, 2 do
		local a = root and root:FindFirstChild("DPartMuzzle_" .. i)
		if a and a:IsA("Attachment") then table.insert(out, a.WorldPosition) end
	end
	if #out == 0 then
		local r = rootOf(char)
		table.insert(out, r.Position + r.CFrame.LookVector * 4 * char:GetScale() + Vector3.new(0, 3 * char:GetScale(), 0))
	end
	return out
end

-- Venom Gatling ------------------------------------------------------------------------------------------------------------------------
botHook(gatlingRemote):Connect(function(player, stamp, aimDir)
	local char, t = check(player, stamp, "dgatling", "DiloPartGatling", aimDir)
	if not char then return end
	ok(char, "DiloPartGatling", t)
	local n = math.clamp(math.floor(num(char, "DiloPartGatlingCount", 4)), 1, 16)
	local span = math.max(0.1, num(char, "DiloPartGatlingTime", 1))
	local dmg = math.max(0, num(char, "DiloPartGatlingDamage", 3))
	local cone = math.rad(math.clamp(num(char, "DiloPartGatlingCone", 25), 0, 90))
	char:SetAttribute("DiloGatlingCount", n)
	char:SetAttribute("DiloGatlingWindup", GATLING_WINDUP)
	char:SetAttribute("DiloGatlingTime", span)
	char:SetAttribute("DiloGatlingAt", t) -- last: pose / FX (spin-up)
	task.wait(GATLING_WINDUP)
	if char:GetAttribute("DiloGatlingAt") ~= t then return end
	if not canStill(char) then cancel(char, "DiloPartGatling") return end
	local s = char:GetScale()
	for i = 1, n do
		if i > 1 then task.wait(span / n) end
		if char:GetAttribute("DiloGatlingAt") ~= t or not canStill(char) then return end
		local ti = now()
		local root = rootOf(char)
		local dir = heading(char, aimDir)
		local ms = muzzles(char)
		local from = ms[((i - 1) % #ms) + 1]
		local reach = math.max(1, num(char, "DiloDartRange", 30)) * s
		local best, bestD
		for _, m in ipairs(candidates(char)) do
			local v = flat(rootOf(m).Position - root.Position)
			local d = v.Magnitude
			if d > 1e-3 and d <= reach and math.acos(math.clamp(dir:Dot(v.Unit), -1, 1)) <= cone and (not bestD or d < bestD) then
				best, bestD = m, d
			end
		end
		local to = best and rootOf(best).Position or (from + dir * reach)
		local speed = math.max(1, num(char, "DiloDartSpeed", 45)) * s
		if v18() and num(char, "DiloGatlingDartSpeed", 0) > 0 then speed = num(char, "DiloGatlingDartSpeed", 67.5) * s end -- v1.8
		local flight = (to - from).Magnitude / speed
		char:SetAttribute("DiloGatlingShot", ("%d;%s;%s;%.3f;%s"):format(i, v3s(from), v3s(to), flight, best and best.Name or ""))
		local target = best
		task.delay(flight, function()
			if not (target and char.Parent and stillTarget(char, target)) then return end
			local tr = rootOf(target)
			local hit = (tr and (tr.Position - to).Magnitude <= DART_TOLERANCE * s) or gap(target, to) <= DART_BODY_REACH * s
			if not hit then return end
			if sapBlocked(from, target) then return end -- v1.4: Sap Wall
			local tt = now()
			damage(char, player, target, dmg, "dilogatling", tt)
			venom(char, target)
			char:SetAttribute("DiloGatlingHit", target.Name .. ";" .. i)
		end)
	end
end)

-- Toxin Mortar -------------------------------------------------------------------------------------------------------------------------
local clouds = {} -- [char] = true while its cloud runs (one per dilo; a new one replaces it)
botHook(mortarRemote):Connect(function(player, stamp, aimDir, aimPoint)
	local char, t = check(player, stamp, "dmortar", "DiloPartMortar", aimDir, aimPoint)
	if not char then return end
	ok(char, "DiloPartMortar", t)
	local root = rootOf(char)
	local dir = heading(char, aimDir)
	local range = math.max(1, num(char, "DiloPartMortarRange", 40))
	local radius = math.max(1, num(char, "DiloPartMortarRadius", 8))
	local life = math.max(0.5, num(char, "DiloPartMortarTime", 3))
	local goal = typeof(aimPoint) == "Vector3" and aimPoint or (root.Position + dir * range)
	local off = flat(goal - root.Position)
	if off.Magnitude > range then off = off.Unit * range end
	if off.Magnitude < 1e-3 then off = dir * range end
	local land = root.Position + off
	land = Vector3.new(land.X, groundY(land, root.Position.Y - 4 * char:GetScale()), land.Z)
	if shotPass() then -- v1.6: strong aim assist
		local near, snap = false, nil
		for _, m in ipairs(candidates(char)) do
			if flat(rootOf(m).Position - land).Magnitude <= radius then near = true break end
		end
		if not near then
			local aimV = off.Magnitude > 1e-3 and off.Unit or dir
			local cosA, bestD = math.cos(math.rad(SHOT_ASSIST_DEG)), nil
			for _, m in ipairs(candidates(char)) do
				local v = flat(rootOf(m).Position - root.Position)
				local d = v.Magnitude
				if d > 1e-3 and d <= range and v.Unit:Dot(aimV) >= cosA and (not bestD or d < bestD) then snap, bestD = m, d end
			end
		end
		if snap then
			local sp = rootOf(snap).Position
			land = Vector3.new(sp.X, groundY(sp, sp.Y - 4 * char:GetScale()), sp.Z)
		end
		char:SetAttribute("DiloMortarAssist", snap and snap.Name or "")
	end
	char:SetAttribute("DiloMortarTo", land)
	local mFlight = shotPass() and MORTAR_FLIGHT / SHOT_SPEED_MUL or MORTAR_FLIGHT -- v1.6
	local mWindup = MORTAR_WINDUP -- v1.9
	if script:GetAttribute("DiloMortarFastEnabled") ~= false then mFlight, mWindup = mFlight / 2, MORTAR_WINDUP / 2 end -- v1.9
	char:SetAttribute("DiloMortarFlight", mFlight)
	char:SetAttribute("DiloMortarWindup", mWindup) -- v1.9 (was MORTAR_WINDUP)
	char:SetAttribute("DiloMortarRadius", radius)
	char:SetAttribute("DiloMortarTime", life)
	char:SetAttribute("DiloMortarAt", t) -- last: pose / FX (the tube rises)
	task.wait(mWindup) -- v1.9 (was MORTAR_WINDUP)
	if char:GetAttribute("DiloMortarAt") ~= t then return end
	if not canStill(char) then cancel(char, "DiloPartMortar") return end
	local from = root.Position + Vector3.new(0, 4 * char:GetScale(), 0)
	local torso = char:FindFirstChild("Torso")
	local troot = torso and torso:FindFirstChild("Root")
	local mz = troot and troot:FindFirstChild("DPartMuzzle_1")
	if mz and mz:IsA("Attachment") then from = mz.WorldPosition end
	char:SetAttribute("DiloMortarFrom", from)
	char:SetAttribute("DiloMortarFireAt", now()) -- the canister leaves
	task.wait(mFlight) -- v1.6 (was MORTAR_FLIGHT)
	if char:GetAttribute("DiloMortarAt") ~= t or not char.Parent then return end
	if sapArcBlocked(from, land, math.abs(from.Y - land.Y) + (tonumber(script:GetAttribute("DiloMovesMortarArc")) or 6.5) * char:GetScale() / 2) then -- v1.5
		char:SetAttribute("DiloMortarWallAt", now())
		return
	end
	local t0 = now()
	char:SetAttribute("DiloMortarLandAt", t0) -- the cloud starts
	clouds[char] = t
	local untilT = t0 + life
	while char.Parent and clouds[char] == t and now() < untilT do
		for _, m in ipairs(candidates(char)) do
			local p = rootOf(m).Position
			if flat(p - land).Magnitude <= radius and math.abs(p.Y - land.Y) <= CLOUD_HEIGHT
				and not (script:GetAttribute("DiloMovesSapCloudEnabled") ~= false and sapBlocked(land + Vector3.yAxis * 2, m)) then venom(char, m) end -- v1.5
		end
		task.wait(CLOUD_TICK)
	end
	if clouds[char] == t then clouds[char] = nil end
end)

-- Spine Burst ---------------------------------------------------------------------------------------------------------------------------
botHook(spineRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "dspine", "DiloPartSpine")
	if not char then return end
	ok(char, "DiloPartSpine", t)
	local n = math.clamp(math.floor(num(char, "DiloPartSpineCount", 6)), 1, 24)
	char:SetAttribute("DiloSpineCount", n)
	char:SetAttribute("DiloSpineWindup", SPINE_WINDUP)
	char:SetAttribute("DiloSpineHits", "")
	char:SetAttribute("DiloSpineAt", t) -- last: pose / FX (the frill flares)
	task.wait(SPINE_WINDUP)
	if char:GetAttribute("DiloSpineAt") ~= t then return end
	if not canStill(char) then cancel(char, "DiloPartSpine") return end
	local root = rootOf(char)
	local origin = root.Position
	local fwd = flat(root.CFrame.LookVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
	local range = math.max(1, num(char, "DiloPartSpineRange", 22))
	local dmg = math.max(0, num(char, "DiloPartSpineDamage", 4))
	local withVenom = char:GetAttribute("DiloPartSpineVenom") == true
	local dirs = {}
	for i = 0, n - 1 do table.insert(dirs, (CFrame.Angles(0, i * 2 * math.pi / n, 0) * fwd).Unit) end
	local judged, hits = {}, {}
	for _, m in ipairs(candidates(char)) do
		local mr = rootOf(m)
		local k = 0
		for _, d in ipairs(dirs) do
			local along = math.clamp(flat(mr.Position - origin):Dot(d), 0, range)
			local pt = origin + d * along
			pt = Vector3.new(pt.X, mr.Position.Y, pt.Z)
			if gap(m, pt) <= SPINE_WIDTH then k += 1 end
		end
		if k > 0 and not sapBlocked(origin, m) then -- v1.4: Sap Wall
			table.insert(judged, {m = m, k = k})
			table.insert(hits, m.Name .. "=" .. k)
		end
	end
	char:SetAttribute("DiloSpineDir", fwd)
	char:SetAttribute("DiloSpineHits", table.concat(hits, "|"))
	local sFlight = shotPass() and SPINE_FLIGHT / SHOT_SPEED_MUL or SPINE_FLIGHT -- v1.6
	char:SetAttribute("DiloSpineFlight", sFlight) -- v1.6
	char:SetAttribute("DiloSpineRange", range) -- v1.6: DiloMovesFX flies the spines this far
	char:SetAttribute("DiloSpineBurstAt", now()) -- the spines leave
	task.wait(sFlight) -- v1.6 (was SPINE_FLIGHT)
	local t2 = now()
	for _, j in ipairs(judged) do
		if char.Parent and stillTarget(char, j.m) then
			for _ = 1, j.k do damage(char, player, j.m, dmg, "dilospine", t2) end
			if withVenom then venom(char, j.m) end
		end
	end
end)

-- Venom Overdrive -----------------------------------------------------------------------------------------------------------------------
botHook(overRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "dover", "DiloPartOver")
	if not char then return end
	ok(char, "DiloPartOver", t)
	local dur = math.max(0.5, num(char, "DiloPartOverTime", 4))
	char:SetAttribute("DiloOverdriveWindup", OVER_WINDUP)
	char:SetAttribute("DiloOverdriveStartAt", t + OVER_WINDUP)
	char:SetAttribute("DiloOverdriveUntil", t + OVER_WINDUP + dur)
	char:SetAttribute("DiloOverdriveAt", t) -- last: pose / FX
end)

-- v1.1: build 2 (see the header) ------------------------------------------------------------------------------------------------
local HISS_WINDUP, HISS_SHOVE_TIME, HISS_NEAR = 0.5, 0.3, 4
local PUMP_WINDUP = 0.62
local JETS_DELAY, JETS_SPEED, JETS_MIN = 0.34, 150, 4
local TRAIL_TICK, TRAIL_WIDTH = 0.5, 4
for _, k in ipairs({"DiloMoves_dhissEnabled", "DiloMoves_dpumpEnabled", "DiloMoves_djetsEnabled", "DiloMovesImmuneWatchEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
for _, k in ipairs({"DiloMovesSilenced", "DiloMovesCleared", "DiloMovesImmuneBlocks", "DiloMovesJets"}) do script:SetAttribute(k, 0) end
local hissRemote, pumpRemote, jetsRemote = remote("DinoDiloHissRequest"), remote("DinoDiloPumpRequest"), remote("DinoDiloJetsRequest")

-- Sonic Hiss -----------------------------------------------------------------------------------------------------------------------
local function shove(src, m, dist, t) -- TenoAttackServer 1.4 shove's pattern
	local sRoot, mRoot = rootOf(src), rootOf(m)
	if not (sRoot and mRoot) or dist <= 0 then return false end
	if Players:GetPlayerFromCharacter(m) then
		m:SetAttribute("HeadbuttShoveFrom", sRoot.Position)
		m:SetAttribute("HeadbuttShoveDist", dist)
		m:SetAttribute("HeadbuttShoveTime", HISS_SHOVE_TIME)
		m:SetAttribute("HeadbuttShoveAt", t) -- last: HeadbuttShove 1.0 pushes it
		return true
	elseif m:GetAttribute("PounceLatched") == true or mRoot.Anchored then
		return false
	end
	local start = mRoot.Position
	local away = flat(start - sRoot.Position)
	away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
	local land = start + away * dist
	local lift = start.Y - groundY(start, start.Y - 3)
	local landPos = Vector3.new(land.X, groundY(land, start.Y - lift) + lift, land.Z)
	local rot = mRoot.CFrame - mRoot.Position
	mRoot.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < HISS_SHOVE_TIME do
			local u = math.clamp((os.clock() - t0) / HISS_SHOVE_TIME, 0, 1)
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
botHook(hissRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "dhiss", "DiloPartHiss")
	if not char then return end
	ok(char, "DiloPartHiss", t)
	local range = math.max(1, num(char, "DiloPartHissRange", 20))
	local angle = math.clamp(num(char, "DiloPartHissAngle", 35), 1, 180)
	if script:GetAttribute("DiloHissBigEnabled") ~= false then -- v1.11: 2x reach, 2x cone
		range *= math.max(0, num(script, "DiloPartHissRangeMul", 2))
		angle = math.clamp(angle * math.max(0, num(script, "DiloPartHissAngleMul", 2)), 1, 90)
	end
	char:SetAttribute("DiloHissWindup", HISS_WINDUP)
	char:SetAttribute("DiloHissRange", range)
	char:SetAttribute("DiloHissAngle", angle)
	char:SetAttribute("DiloHissHits", "")
	char:SetAttribute("DiloHissAt", t) -- last: pose / FX (the speakers charge)
	task.wait(HISS_WINDUP)
	if char:GetAttribute("DiloHissAt") ~= t then return end
	if not canStill(char) then cancel(char, "DiloPartHiss") return end
	local root = rootOf(char)
	local fwd = flat(root.CFrame.LookVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
	local s = char:GetScale()
	local knock = math.max(0, num(char, "DiloPartHissKnock", 18))
	local silence = math.max(0, num(char, "DiloPartHissSilence", 1.5))
	local t2 = now()
	local hits = {}
	for _, m in ipairs(candidates(char)) do
		local p = rootOf(m).Position
		local v = flat(p - root.Position)
		local d = v.Magnitude
		local inCone = d <= HISS_NEAR * s / 2 or (d <= range and math.deg(math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1))) <= angle)
		if inCone and math.abs(p.Y - root.Position.Y) <= CLOUD_HEIGHT and not sapBlocked(root, m) then -- v1.4: Sap Wall
			shove(char, m, knock, t2)
			if silence > 0 then
				m:SetAttribute("SilencedUntil", math.max(num(m, "SilencedUntil", 0), t2 + silence))
				m:SetAttribute("SilencedBy", char.Name)
				m:SetAttribute("SilencedAt", t2) -- last: MechaButtons 1.36 / DiloMovesFX 1.1
				count("DiloMovesSilenced")
			end
			table.insert(hits, m.Name)
		end
	end
	char:SetAttribute("DiloHissHits", table.concat(hits, "|"))
	char:SetAttribute("DiloHissBlastAt", t2) -- the blast
end)

-- Antivenom Pump -------------------------------------------------------------------------------------------------------------------
local CLEAR_TAGS = {"VenomUntil", "StunnedUntil", "DazedUntil", "InkedUntil", "ScreechSlowUntil", "MineSlowUntil",
	"HeadbuttSlowUntil", "SmokeSlowUntil", "CaltropSlowUntil", "GooSlowUntil", "TenoSlowUntil"}
local CLEAR_MORE = {"SkillBleedUntil", "SlashBleedUntil", "CaltropBleedUntil", "DebuffUntil"} -- v1.2
local IMMUNE_TAGS = {"StunnedUntil", "DazedUntil", "InkedUntil", "ScreechSlowUntil", "MineSlowUntil", "HeadbuttSlowUntil",
	"SmokeSlowUntil", "CaltropSlowUntil", "GooSlowUntil", "TenoSlowUntil"}
local watched = setmetatable({}, {__mode = "k"})
local function watchImmune(char)
	if watched[char] then return end
	watched[char] = true
	for _, tag in ipairs(IMMUNE_TAGS) do
		char:GetAttributeChangedSignal(tag):Connect(function()
			if script:GetAttribute("DiloMovesImmuneWatchEnabled") == false or script:GetAttribute("DiloMovesServerEnabled") == false then return end
			local t = now()
			if num(char, "DiloImmuneUntil", 0) <= t or num(char, tag, 0) <= t then return end
			task.defer(function()
				local t2 = now()
				if num(char, "DiloImmuneUntil", 0) > t2 and num(char, tag, 0) > t2 then
					char:SetAttribute(tag, t2)
					char:SetAttribute("DiloImmuneBlockAt", t2) -- FX
					count("DiloMovesImmuneBlocks")
				end
			end)
		end)
	end
end
botHook(pumpRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "dpump", "DiloPartPump")
	if not char then return end
	ok(char, "DiloPartPump", t)
	local free = breakFree("dpump") -- v1.2
	if free and (num(char, "StunnedUntil", 0) > t or num(char, "DazedUntil", 0) > t) then count("DiloMovesBreakFree") end
	watchImmune(char)
	char:SetAttribute("DiloPumpWindup", PUMP_WINDUP)
	char:SetAttribute("DiloPumpAt", t) -- last: pose / FX (the piston primes)
	task.wait(PUMP_WINDUP)
	if char:GetAttribute("DiloPumpAt") ~= t then return end
	if not canStill(char, free) then cancel(char, "DiloPartPump") return end -- v1.2: free = a stun / daze doesn't cancel
	local t2 = now()
	local cleared = {}
	for _, tag in ipairs(CLEAR_TAGS) do
		if num(char, tag, 0) > t2 then
			char:SetAttribute(tag, t2)
			table.insert(cleared, tag)
		end
	end
	if script:GetAttribute("DiloPumpClearMoreEnabled") ~= false then -- v1.2: bleeds + the roar debuff
		for _, tag in ipairs(CLEAR_MORE) do
			if num(char, tag, 0) > t2 then
				char:SetAttribute(tag, t2)
				table.insert(cleared, tag)
				if tag == "DebuffUntil" then char:SetAttribute("DebuffState", "none") end
			end
		end
	end
	count("DiloMovesCleared", #cleared)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local healed = 0
	if hum and hum.Health > 0 then
		local before = hum.Health
		hum.Health = math.min(hum.MaxHealth, before + math.max(0, num(char, "DiloPartPumpHeal", 15)))
		healed = hum.Health - before
	end
	local immune = math.max(0, num(char, "DiloPartPumpImmune", 0))
	if immune > 0 then char:SetAttribute("DiloImmuneUntil", t2 + immune) end
	char:SetAttribute("DiloPumpCleared", table.concat(cleared, "|"))
	char:SetAttribute("DiloPumpHealed", math.floor(healed * 10 + 0.5) / 10)
	char:SetAttribute("DiloPumpJoltAt", t2) -- the jolt
end)

-- Spring Jets ----------------------------------------------------------------------------------------------------------------------
local jets = setmetatable({}, {__mode = "k"}) -- [char] = {refills = {times}}
local function jetsLeft(char, t)
	local st = jets[char]
	if not st then
		st = {refills = {}}
		jets[char] = st
	end
	for i = #st.refills, 1, -1 do
		if st.refills[i] <= t then table.remove(st.refills, i) end
	end
	local max = math.max(1, math.floor(num(char, "DiloPartJetsCharges", 1)))
	return max - #st.refills, st
end
local function jetsPublish(char, t)
	local left, st = jetsLeft(char, t)
	local nextAt = math.huge
	for _, r in ipairs(st.refills) do nextAt = math.min(nextAt, r) end
	char:SetAttribute("DiloPartJetsLeft", math.max(0, left))
	char:SetAttribute("DiloPartJetsReadyAt", left > 0 and t or nextAt)
	if nextAt < math.huge then
		task.delay(nextAt - t + 0.02, function() if char.Parent then jetsPublish(char, now()) end end)
	end
end
local function segGap(p, a, b) -- flat distance from p to the segment a-b
	local ab = flat(b - a)
	local ap = flat(p - a)
	local L2 = ab:Dot(ab)
	local u = L2 > 1e-6 and math.clamp(ap:Dot(ab) / L2, 0, 1) or 0
	return (ap - ab * u).Magnitude
end
botHook(jetsRemote):Connect(function(player, stamp, moveDir)
	local c0 = player.Character
	if c0 then jetsPublish(c0, now()) end
	if moveDir ~= nil and (typeof(moveDir) ~= "Vector3" or moveDir ~= moveDir) then
		if c0 then
			c0:SetAttribute("DiloPartJetsServerResult", "badArg")
			c0:SetAttribute("DiloPartJetsServerResultAt", now())
		end
		return
	end
	local char, t = check(player, stamp, "djets", "DiloPartJets")
	if not char then return end
	local left, st = jetsLeft(char, t)
	if left <= 0 then
		char:SetAttribute("DiloPartJetsServerResult", "cooldown")
		char:SetAttribute("DiloPartJetsServerResultAt", t)
		return
	end
	local root = rootOf(char)
	local s = char:GetScale()
	local dir = typeof(moveDir) == "Vector3" and flat(moveDir) or Vector3.zero
	if dir.Magnitude > 0.1 then dir = dir.Unit else
		dir = flat(root.CFrame.LookVector)
		dir = dir.Magnitude > 1e-3 and dir.Unit or -Vector3.zAxis
	end
	local range = math.max(0, num(char, "DiloPartJetsDist", 25))
	local from = root.Position
	local hit = workspace:Raycast(from, dir * range, worldOnly())
	local dist = hit and math.max(0, flat(hit.Position - from).Magnitude - 3 * s / 2) or range
	if dist < JETS_MIN then
		char:SetAttribute("DiloJetsResult", "blocked")
		char:SetAttribute("DiloPartJetsServerResult", "blocked")
		char:SetAttribute("DiloPartJetsServerResultAt", t)
		return
	end
	local to = from + dir * dist
	local g0, g1 = groundY(from, nil), groundY(to, nil)
	if g0 and g1 then to = Vector3.new(to.X, g1 + (from.Y - g0), to.Z) end
	table.insert(st.refills, t + math.max(0.5, num(char, "DiloPartJetsCooldown", 6)))
	char:SetAttribute("DiloPartJetsServerResult", "ok")
	char:SetAttribute("DiloPartJetsServerResultAt", t)
	jetsPublish(char, t)
	count("DiloMovesJets")
	local time = math.clamp(dist / (v18() and JETS_SPEED_V18 or JETS_SPEED), 0.15, 0.3) -- v1.8 (was JETS_SPEED)
	local delay = script:GetAttribute("DiloJetsInstantEnabled") ~= false and 0 or JETS_DELAY -- v1.3: no wind-up
	char:SetAttribute("DiloJetsFrom", from)
	char:SetAttribute("DiloJetsTo", to)
	char:SetAttribute("DiloJetsDelay", delay)
	char:SetAttribute("DiloJetsTime", time)
	char:SetAttribute("DiloJetsResult", "dash")
	char:SetAttribute("DiloJetsAt", t) -- last: DiloJetsLaunch 1.0 + FX + pose
	local trail = math.max(0, num(char, "DiloPartJetsTrail", 0))
	if trail <= 0 then return end
	task.wait(delay + time) -- v1.3: was JETS_DELAY + time
	if not char.Parent then return end
	local t0 = now()
	char:SetAttribute("DiloJetsTrailUntil", t0 + trail)
	local width = TRAIL_WIDTH * s / 2
	while char.Parent and now() < t0 + trail do
		for _, m in ipairs(candidates(char)) do
			local p = rootOf(m).Position
			if segGap(p, from, to) <= width and math.abs(p.Y - from.Y) <= CLOUD_HEIGHT then venom(char, m) end
		end
		task.wait(TRAIL_TICK)
	end
end)

-- v1.12: the bot entrance (see the header)
if script:GetAttribute("DiloMovesServerBotMechaEnabled") == nil then script:SetAttribute("DiloMovesServerBotMechaEnabled", true) end
do
	local proxyModule = game:GetService("ServerStorage"):WaitForChild("DinoArcade"):FindFirstChild("BotProxy")
	local BotProxy = proxyModule and require(proxyModule)
	local fn = script:FindFirstChild("BotMechaUse") or Instance.new("BindableFunction")
	fn.Name = "BotMechaUse"
	local joined = setmetatable({}, {__mode = "k"})
	fn.OnInvoke = function(model, remoteName, ...)
		if script:GetAttribute("DiloMovesServerBotMechaEnabled") == false then return "off" end
		if not BotProxy or typeof(model) ~= "Instance" or model:GetAttribute("PracticeBot") ~= true or not model.Parent then return "badArg" end
		local list = __botHandlers[remoteName]
		if not list then return "noHandler" end
		local proxy = BotProxy.of(model)
		if not joined[model] then
			joined[model] = true
			for _, j in ipairs(__botJoiners) do pcall(j, proxy) end
			task.wait(0.2)
		end
		for _, h in ipairs(list) do
			local ok, err = pcall(h, proxy, ...)
			if not ok then
				script:SetAttribute("DiloMovesServerBotMechaError", tostring(remoteName) .. ": " .. tostring(err))
				return "botUnsupported"
			end
		end
		return "ok"
	end
	fn.Parent = script
end
script:SetAttribute("DiloMovesServerVersion", "1.12") -- v1.12 bot entrance
