-- TrooMovesServer v1.11 (Mecha Dino Arena) — the Troodon's mecha button parts, build 1 (server authority): Mender Drone, Arc
-- Lantern, Sap Wall, Feather Shed, Portal Feathers. Plan docs/plans/TROODON_PARTS_v1.0.md ticket 4 (MDA-348); numbers = the
-- plan's table (areas doubled, Kepu 2026-11-06 21:24 / 21:3x); timings = tools/mockup/troodon_parts_looks.js v0.2 tracks.
-- Settings (character attributes, SkillEffects 1.48, written while bought AND slotted): TrooPartMender* (Enabled, Heal, Time,
--   Range, Hop, Cooldown), TrooPartLantern* (Enabled, Range, Chain, Targets, Damage, Cooldown), TrooPartSap* (Enabled, Range,
--   Width, Time, Cooldown), TrooPartShed* (Enabled, Immune, Cooldown, KnockRadius, SlowMul, SlowTime), TrooPartPortal*
--   (Enabled, Range, Time, Squad, Cooldown). Studs are game studs (the Lab texts).
-- Remotes (ReplicatedStorage, client -> server, sent by MechaButtons): DinoTrooMenderRequest(stamp), DinoTrooLanternRequest(stamp,
--   aimDir, aimPoint), DinoTrooSapRequest(stamp, aimDir, aimPoint), DinoTrooShedRequest(stamp), DinoTrooPortalRequest(stamp,
--   aimDir, aimPoint).
-- Checks in order -> character <Prefix>ServerResult (+ ResultAt), prefix TrooPartMender / Lantern / Sap / Shed / Portal:
--   "badArg", "dead", "disabled" (script switches, <Prefix>Enabled ~= true or Species not Troodon), "menu", "stunned",
--   "pinned" (PinHeld), "dazed", "silenced" (SilencedUntil, the dilo's Sonic Hiss), "cooldown" (now < <Prefix>ReadyAt), then
--   the move's own ("occupied" / "blocked"); else "ok" and <Prefix>ReadyAt = now + <Prefix>Cooldown (from the press). Feather
--   Shed skips "stunned" / "pinned" / "dazed" (it breaks them). A wind-up cut short (dead / stunned / dazed / pinned when it
--   should fire) -> "cancelled" (the recharge stays). Bots never use these (player remotes only).
-- Targets (TrooAttackServer 1.0 rules): player characters and Workspace.DinoIsland.Bots models, Bitable with Hitboxes, alive,
--   not KO. Enemies: never squadmates (SquadRules.sameChar); players only where ModeRules.canAffect allows (the Arena); bots
--   always. Heals: squadmates and yourself only (Humanoid.Health; capped). Damage: DummyHealth minus the hit x takenMul (roar
--   debuff, daze, stun-break immunity), nothing through EnergyShieldUntil; kills stamped KilledBy / KilledWith / KilledAt.
--   Target stamps reuse TrooFX 1.x: TrooHitKind / TrooHitBy / TrooHitAt (hit flash), TrooHealAmount / TrooHealAt (heal pops).
-- * Mender Drone (wind-up TrooMoves_menderWindup 0.45, flight TrooMoves_menderFly 0.75): the most hurt (lowest Health /
--   MaxHealth, not full) of you and your live squadmates within TrooPartMenderRange studs; none hurt -> you. At arrival it
--   heals TrooPartMenderHeal per second (every TrooMoves_menderTick 0.25 s) for TrooPartMenderTime s. Star (Hop): when its
--   target is full it flies (TrooMoves_menderHopFly 0.5 s) to the next most hurt one within range of you, the time left goes
--   on. Stamps (troodon): TrooMenderTarget, TrooMenderArriveAt, TrooMenderUntil, TrooMenderAt (the press, last); per hop
--   TrooMenderHopTo / TrooMenderHopAt; TrooMenderEndAt.
-- * Arc Lantern (wind-up 0.42, flight 0.55): lands at aimPoint (flat distance clamped to TrooPartLanternRange; else straight
--   ahead), Y = the ground. TrooMoves_lanternZapDelay (0.32 s) after the landing it zaps the nearest enemy within
--   TrooMoves_lanternZapRadius (16) studs of it, then chains every TrooMoves_lanternChainStep (0.12 s) to the nearest not yet
--   hit enemy within TrooPartLanternChain studs of the last one, TrooPartLanternTargets in all: TrooPartLanternDamage each.
--   Stamps: TrooLanternFrom / TrooLanternTo / TrooLanternFlight, TrooLanternAt (press, last); TrooLanternLandAt;
--   TrooLanternChainList ("name|name"), TrooLanternZapAt (last of each zap); target TrooHitKind "zap".
-- * Sap Wall (wind-up 0.34, flight 0.5): the pod lands at aimPoint (clamped to TrooPartSapRange) and the wall rises there
--   across the throw (its long side square to the flat line from the troodon), TrooPartSapWidth studs wide,
--   TrooMoves_sapHeight (18) high, TrooMoves_sapThick (2) thick, for TrooPartSapTime s from the splat. A real wall: Model
--   "SapWall" in Workspace.TrooWalls, TrooMoves_sapSegments (5) anchored, CanCollide / CanQuery parts tagged with
--   CollectionService "SapWall" (attributes SapWallOwner, SapWallUntil). It never spawns on a dino: at the press a dino's root
--   inside the footprint (+ TrooMoves_sapClear 3 studs) -> "occupied" (no recharge used); at the splat the same -> the wall
--   is not raised, TrooSapResult "occupied" and the recharge is given back. Stamps: TrooSapFrom / TrooSapTo / TrooSapFlight /
--   TrooSapWidth / TrooSapTime, TrooSapAt (press, last); TrooSapSplatAt; TrooSapResult ("wall" / "occupied"); TrooSapEndAt.
-- * Feather Shed (wind-up TrooMoves_shedWindup 0.15 s for the burst): at the press StunnedUntil, TheriSnaredUntil (the bola)
--   and DazedUntil are set to now when in the future, and a pin is broken (PinnedBy's model gets ShakeOffReason "shed" +
--   ShakeOffAt: PounceServer / BotServer release it; no pinner found -> PinHeld cleared); TrooShedImmuneUntil = press +
--   TrooPartShedImmune. Its own watcher (not StunBreakImmuneUntil, which a dozen servers read as full damage immunity): while
--   TrooShedImmuneUntil > now, a StunnedUntil / TheriSnaredUntil / DazedUntil put into the future or PinHeld set true on the
--   troodon is undone at once (task.defer; TrooShedBlockAt). Star (KnockRadius > 0): at the burst every enemy within
--   TrooPartShedKnockRadius studs is pushed TrooPartShedKnockRadius studs away (players: HeadbuttShove stamps; bots: a slide)
--   and slowed (TrooSlowMul = TrooPartShedSlowMul, TrooSlowUntil = burst + TrooPartShedSlowTime; bots through
--   TrooAttackServer's BindableFunction TrooSlowApply when it is there). Stamps: TrooShedBroke ("stun|pin|snare|daze" or ""),
--   TrooShedAt (press, last); TrooShedBurstAt, TrooShedHits.
-- * Portal Feathers (wind-up 0.4 / 0.52 for the two rings; open at +0.75 / +1.32): ring A TrooMoves_portalNear (10) studs
--   ahead on the ground, ring B at aimPoint (flat distance clamped to TrooPartPortalRange, at least portalNear + 8). No
--   portal into terrain: each ring's spot needs a 6 x 8 x 6 stud box (TrooMoves_portalClearW / portalClearH) above the ground
--   free of collidable world parts (exact shapes, GetPartsInPart; players, bots, FX and sap walls left out);
--   B is pulled back towards A in 4-stud steps until free; none free -> "blocked" (no recharge used). Open from the
--   second ring's opening for TrooPartPortalTime s. Every TrooMoves_portalTick (0.1) s a user (you; your squadmates too with
--   TrooPartPortalSquad; never bots) whose root is within TrooMoves_portalRadius (6) studs of a ring (flat, 10 up / down) and
--   whose TrooPortalLockUntil has passed is moved to the other ring (root height kept above the ground, facing kept),
--   TrooPortalLockUntil = now + TrooMoves_portalLock (1 s). Stamps (owner): TrooPortalA / TrooPortalB, TrooPortalOpenAt /
--   TrooPortalOpen2At, TrooPortalUntil, TrooPortalAt (press, last); user: TrooPortalFrom / TrooPortalTo, TrooPortalUsedAt
--   (last); TrooPortalEndAt.
-- Test hook (Studio only, off by default, must be unset at publish): script attribute TrooMovesTestAllyName = a bot's name: that
--   bot counts as a squadmate (healed on DummyHealth, never harmed, may use the portals at star).
-- Switches: script TrooMovesServerEnabled, TrooMoves_<id>Enabled (omender / olantern / osapwall / oshed / oportal),
--   TrooMovesModeRulesEnabled, TrooMovesSquadEnabled, TrooMovesShedWatchEnabled (default true, read at each use); every
--   number above is a script attribute TrooMoves_<name> (read at each use). Diagnostics: script TrooMovesServerVersion,
--   TrooMovesHits, TrooMovesHeals, TrooMovesWalls, TrooMovesPortals, TrooMovesShedBlocks, TrooMovesSquadSkips, TrooMovesMode.
-- v1.12 (Bots v2, MDA-471, plan docs/plans/BOTS_V2_v1.0.md T7; Kepu 2026-11-11 20:39 "the damn bots don't even use their
--   attack buttons or their mecha"): a bot entrance. Every remote handler of this script is connected through botHook(remote)
--   (handler bodies unchanged), which also files it by the remote's name. Server-only BindableFunction "BotMechaUse" (child):
--   Invoke(model, remoteName, ...the remote's own arguments...) runs every handler filed for that remote, in order, with
--   ServerStorage.DinoArcade.BotProxy.of(model) as the player (the model is its Character; PracticeBot models only).
--   Returns "ok" (the handlers ran; their results land on the model as for a player), "off", "badArg", "noHandler" or
--   "botUnsupported" (a handler errored; script attribute TrooMovesServerBotMechaError keeps "<remote>: <error>").
--   Switch: script attribute TrooMovesServerBotMechaEnabled (default true, read per call).
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
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 Sap Wall stops the lantern zaps / the shed burst through it
-- v1.1 (MDA-353) Sap Wall: a live Sap Wall on the attacker (or splash centre) -> target line stops the hit (ServerStorage.DinoArcade
--   SapWallBlock.between). Switch: script attribute TrooMovesServerSapWallEnabled (default true, read at each hit). Diagnostics: script
--   TrooMovesServerSapWallBlocks (count), TrooMovesServerSapWallBlockedAt (server time).
local sapBlocked do
	local mod
	sapBlocked = function(from, to)
		if script:GetAttribute("TrooMovesServerSapWallEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.between and mod.between(from, to)) then return false end
		script:SetAttribute("TrooMovesServerSapWallBlocks", (script:GetAttribute("TrooMovesServerSapWallBlocks") or 0) + 1)
		script:SetAttribute("TrooMovesServerSapWallBlockedAt", workspace:GetServerTimeNow())
		return true
	end
	if script:GetAttribute("TrooMovesServerSapWallEnabled") == nil then script:SetAttribute("TrooMovesServerSapWallEnabled", true) end
end
VERSION = "1.2" -- v1.2 a lantern whose arc goes through a Sap Wall is stopped
-- v1.2 (MDA-353, Kepu 2026-11-07 lobbed shots "Can go over"): the Arc Lantern's real flight (TrooPartsFX 1.x: TrooLanternFrom -> TrooLanternTo + 0.8 x
--   scale / 2 up, 4 x TrooMoves_lanternArc (6) x scale / 2 x u x (1 - u) above the line) is checked at the landing by
--   SapWallBlock 1.2 arcBlocks: an arc through a live wall stops it (no zaps; character TrooLanternWallAt), an arc over the
--   wall lands and zaps as before (the zap line checks stay).
--   Switch: script attribute TrooMovesServerSapArcEnabled (default true, read at each shot; false = the previous behaviour: no check of the
--   flight itself). Diagnostics: script TrooMovesServerSapArcBlocks (count), TrooMovesServerSapArcBlockedAt (server time).
local sapArcBlocked do
	local mod
	sapArcBlocked = function(from, to, peak)
		if script:GetAttribute("TrooMovesServerSapArcEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.arcBlocks) then return false end
		local b, _, u, pos = mod.arcBlocks(from, to, peak)
		if not b then return false end
		script:SetAttribute("TrooMovesServerSapArcBlocks", (script:GetAttribute("TrooMovesServerSapArcBlocks") or 0) + 1)
		script:SetAttribute("TrooMovesServerSapArcBlockedAt", workspace:GetServerTimeNow())
		return true, u, pos
	end
	if script:GetAttribute("TrooMovesServerSapArcEnabled") == nil then script:SetAttribute("TrooMovesServerSapArcEnabled", true) end
end
VERSION = "1.3" -- v1.3 the Sap Wall's mockup look (opaque amber slabs, stepped tops)
-- v1.3 (MDA-351, the B1 captures: the wall read as a thin yellow line from the game camera; mockup v0.2 sapTrack): the wall parts
--   are SmoothPlastic D9821C (the mockup's set sap colour) at TrooMoves_sapTransparency (0.08) instead of Glass FFB43A at 0.25,
--   and the segment heights follow the mockup's stepped tops, TrooMoves_sapProfile "0.82,0.94,1,0.9,0.78" (x TrooMoves_sapHeight,
--   repeated if there are more segments; the tallest stays sapHeight). TrooPartsFX 1.1 draws the rise / wet -> set / rim on
--   every client. Switch: script attribute TrooMovesSapLookEnabled (default true, read at each wall; false = 1.2's parts).
VERSION = "1.4" -- v1.4 shot pass: faster shots, strong aim assist
-- v1.4 (Kepu 2026-11-09 "all the projectile shots need to be faster and more auto aim assist on it and longer range"
--   -> 1.5x faster, 2x range, "Strong" assist = snap to a target within 45 degrees of the aim; plan
--   docs/plans/SHOT_PASS_v1.0.md): the Arc Lantern and the sap pod fly 1.5x faster (lanternFly / sapFly / 1.5;
--   TrooLanternFlight / TrooSapFlight); when no enemy is within lanternZapRadius of the aimed spot, the lantern
--   lands on the nearest enemy within 45 degrees of the aim and within TrooPartLanternRange (diag TrooLanternAssist
--   = its name or ""). The Sap Wall does not snap (it is placed). Ranges come from SkillTree 1.74. Switch: script
--   attribute ShotPassEnabled (default true; false = 1.3).
VERSION = "1.5" -- v1.5 no movement moves while snared
-- v1.5 (MDA-356; Kepu 2026-11-08 "pachy headbutt when trapped by zino still works which defeats the purpose of throwing a trap" -> "No movement moves"): Portal Feathers (oportal) are refused "snared" while the character's
--   TheriSnaredUntil (Snare Wires bola) or HookHeldUntil (Reaper Hook / Grappling Hook hold) is after now (the PinHeld pattern;
--   bites and attacks that stay in place still work; the Troodon's Feather Shed still breaks out). Switch: script
--   attribute TrooMovesSnareBlockEnabled (default true, read at each request; false = 1.4). Diagnostic: script
--   TrooMovesSnareRefusals (count).
if script:GetAttribute("TrooMovesSnareBlockEnabled") == nil then script:SetAttribute("TrooMovesSnareBlockEnabled", true) end -- v1.5
local function snareBlocked(char) -- v1.5: Snare Wires bola / Reaper Hook hold
	if script:GetAttribute("TrooMovesSnareBlockEnabled") == false then return false end
	local t = workspace:GetServerTimeNow()
	local on = (tonumber(char:GetAttribute("TheriSnaredUntil")) or 0) > t or (tonumber(char:GetAttribute("HookHeldUntil")) or 0) > t
	if on then script:SetAttribute("TrooMovesSnareRefusals", (script:GetAttribute("TrooMovesSnareRefusals") or 0) + 1) end
	return on
end
local SNARE_MOVES = {oportal = true} -- v1.5: the movement parts
VERSION = "1.6" -- v1.6 always-on parts: Last Feather, Fortify / Plume refunds, plume on Mender heals
-- v1.6 (troodon parts build 2, MDA-349, plan docs/plans/TROODON_PARTS_v1.0.md ticket 5; Kepu 2026-11-09 17:17 "Build all of them" + "Use the references we chose from the previous mockups"):
--   * Health watcher (every player character, any species; in Studio also every bot, for the test ally): on each Humanoid
--     health drop (not this script's own write; bots: DummyHealth):
--     - Last Feather untouchable window (TrooLastFeatherUntil > now): the whole drop is given back;
--     - a drop to 0 while the troodon's Last Feather is ready (TrooLastFeatherReady): health = 1 (the hit does not kill: the
--       Humanoid's Dead state is switched off here and on the owner's client (TrooLastFeather 1.0) while the part is ready or
--       the window is open; Studio check 2026-11-09: a hit for 105 on 55 HP left 1 HP, no Died, the client alive);
--       TrooLastFeatherUsed = true (once per life; a respawn is a new character), the window TrooPartLastFeatherUntouch (0.7 /
--       1 s) with an invisible ForceField "TrooLastFeatherField" (blocks Humanoid:TakeDamage) and full refunds, then
--       TrooLastFeatherUntil, TrooLastFeatherGlide (TrooPartLastFeatherGlide, II: the owner's client launches into the glide),
--       TrooLastFeatherAt = now (last; client + TrooPartsFX); star (TrooPartLastFeatherZone): TrooAttackServer 1.4's
--       TrooZoneDrop(char, root) drops a glow zone where it stood. Note: an Arena attacker whose hit took the DummyHealth copy
--       to 0 still stamps its kill record (as Energy Shield / Pachy Last Stand);
--     - otherwise (health after > 0): Fortify (TrooFortifyUntil > now): refund f = drop x (1 - TrooFortifyMul); Plume
--       (TrooPlumeUntil > now, TrooPlume > 0): soak s = min(TrooPlume, drop - f), TrooPlume -= s; health = min(max, health + f +
--       s). Stamps: TrooFortifySaved (0.1 steps) + TrooFortifySavedAt; TrooPlumeSoak + TrooPlumeSoakAt (last; FX). A killing
--       blow is never refunded (a Humanoid at 0 is dead).
--     Switches: script attributes TrooMovesLastFeatherEnabled, TrooMovesRefundEnabled (default true, read at each drop;
--     false = 1.5: Dead state left on, no refunds). Diagnostics: script TrooLastFeatherSaves, TrooFortifyRefunds,
--     TrooPlumeSoaks; character TrooLastFeatherReady (true while it would save).
--   * Plume fade: a plume past its TrooPlumeUntil is cleared (TrooPlume 0) every 0.25 s.
--   * Overheal Plume on the Mender Drone's heals: the part that did not fit goes to TrooPassives.plumeAdd(the troodon, target,
--     overflow, now, test ally). Switch: script attribute TrooMovesPlumeEnabled (default true, read at each heal).
VERSION = "1.7" -- v1.7 armor on every hit (MDA-366)
-- v1.7 (MDA-366, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 "Every attack"): armor (Thick Hide / Armored Hide /
--   Wiry Frame = the victim's StatDamageTakenMul) now cuts Lantern and the other part hits (damage):
--   damage x BoneCrest.armor(victim) (ServerStorage.DinoArcade.BoneCrest 1.7, one shared call). Switch: script attribute
--   TrooMovesServerArmorAllEnabled (default true, read at each hit; false = 1.6). Diagnostic: script TrooMovesServerArmorCuts (count of hits cut).
VERSION = "1.8" -- v1.8 Arc Lantern tracks its target (MDA-376)
-- v1.8 (MDA-376; Kepu 2026-11-09 20:33 live test "The arc lantern didn't do shit"): 1.7 fixed the landing at the press and zapped only
--   within lanternZapRadius of that spot ~1.1 s later, so anything moving faster than ~12-15 studs/s escaped. Now the first target is
--   locked at the press: the assist-snapped enemy, else among the enemies in the 45 degree aim cone (roots, flat) within
--   TrooPartLanternRange + lanternZapRadius the one whose root is nearest the aimed spot when one is within lanternZapRadius of it,
--   else the nearest one within TrooPartLanternRange (diag character TrooLanternTrack = its name or ""). When the lantern leaves the
--   hand (end of the wind-up) the planned spot = the locked target's ground spot then (if it is still alive, an enemy and within
--   TrooPartLanternRange + lanternZapRadius of the troodon; else the lock is dropped and 1.7 runs); at the landing the lantern comes
--   down at the target's current ground spot when it is alive and within TrooMoves_lanternTrackLeash (1.5) x lanternZapRadius of
--   the planned spot (else on the planned spot, 1.7's zap search), and zaps it TrooMoves_lanternTrackZapDelay (0) s after the
--   landing (the Sap Wall arc check runs on the real flight to that spot, the zap line check from it), then chains as 1.7.
--   TrooLanternTo is re-stamped at the landing (the real spot); TrooPartsFX 1.3 homes the flying lantern on TrooLanternTrack.
--   Switch: script attribute TrooMovesLanternTrackEnabled (default true, read at each press; false = 1.7). Diagnostics: script
--   TrooMovesLanternTracked (count of tracked zaps), TrooMovesLanternTrackLost (count of locks dropped).
VERSION = "1.9" -- v1.9 Sap Wall height from the skill (MDA-373)
-- v1.9 (MDA-373; Kepu 2026-11-09 20:33 "100 wide, 30 tall, 8 s"; SkillTree 1.81 / SkillEffects 1.55): the wall is
--   TrooPartSapHeight studs tall when that is > 0 (30 at every rank), else TrooMoves_sapHeight (18) as 1.8; width / time come
--   from TrooPartSapWidth / TrooPartSapTime as before (now 74 / 100 wide, 4.2 / 5.8 / 8 s). The placement check (no wall on a
--   dino, at the press and at the splat) uses the same height; SapWallBlock (blocks / arcBlocks) and TrooPartsFX read the real
--   wall parts, so they follow. Stamp: character TrooSapHeight (before TrooSapAt). Switch: script attribute
--   TrooMovesSapHeightEnabled (default true, read at each throw; false = 1.8: always TrooMoves_sapHeight).
VERSION = "1.10" -- v1.10 Portal Feathers -> Apex-style rift (MDA-375)
-- v1.10 (MDA-375; Kepu 2026-11-09 20:33 "The portal is fucking stupid. It should work like the one on apex legends works" ->
--   "Everyone, like Apex", "250 studs, 30 s", 45 s recharge; SkillTree 1.82 / SkillEffects 1.56 give TrooPartPortalRiftLength /
--   RiftTime / RiftCooldown, star 250 / 30 / 45). While script attribute TrooPortalRiftEnabled (default true, read at each press;
--   false = 1.9's two rings) is on, DinoTrooPortalRequest is the rift:
--   * press 1 (the usual checks; the spot under the troodon must pass the 6 x 8 x 6 terrain box, else "blocked", nothing used):
--     end A on the ground under the troodon; placing mode (result "placing"; character TrooRiftPlacing true, TrooRiftA,
--     TrooRiftMax, TrooRiftSpeedMul, TrooRiftAt last): SprintTest 1.24 runs it TrooRiftSpeedMul faster, rising from
--     TrooMoves_riftBoostMin 1.25 to riftBoostMax 1.55 with the distance walked / the max (TrooRiftWalked); the other troodon
--     parts are refused "placing" and TrooAttackServer 1.6 refuses the pod; the path is recorded every TrooMoves_riftSample (3)
--     studs (root positions);
--   * press 2, the max distance walked (TrooPartPortalRiftLength, else riftLen 250) or riftPlaceMax (15) s -> end B at the last
--     point (walked back along the path to the first spot that passes the terrain box); under riftMinWalk (10) studs walked (or
--     no free end B, or the troodon dies) -> cancelled, nothing used (TrooPartPortalReadyAt = now, TrooRiftCancelWhy,
--     TrooRiftCancelAt);
--   * open for TrooPartPortalRiftTime (else riftTime 30) s from end B; the recharge TrooPartPortalRiftCooldown (else riftCooldown
--     45) s starts at end B (TrooPartPortalReadyAt; TrooPartPortalRechargeUsed = that recharge, for the HUD fill). Owner stamps:
--     TrooRiftB, TrooRiftLen, TrooRiftPath ("x,y,z;..." ground points, 0.1 stud), TrooRiftUntil, TrooRiftOpenAt (last);
--     TrooRiftEndAt at the close;
--   * travel: every Heartbeat any player's dino (owner, squadmates and enemies; bots only with TrooMoves_riftBotsEnabled, default
--     false; never an anchored / pinned one) whose root is within TrooMoves_riftRadius (6) studs (flat, 10 x scale up / down) of
--     an end, whose TrooPortalLockUntil has passed and who has left both ends since its last trip on this rift (the troodon
--     counts as just arrived at end B), is carried along the recorded path to the other end at TrooMoves_riftSpeedMul (5) x its
--     MoveRunSpeed (players; bots their WalkSpeed): server-owned anchored carry (root Anchored, the model pivoted along the path
--     every Heartbeat, facing along it, its height above the ground kept) - chosen over AlignPosition because the client owns a
--     player's physics: a constraint would be solved on the (phone) client with its lag and could be fought by its input, while
--     an anchored root cannot move on any client; un-anchored at the end, TrooPortalLockUntil = end + riftLock (1 s).
--     Untouchable while travelling: an invisible ForceField "TrooRiftField", the Dead state off, and every Humanoid health drop
--     given back while TrooRiftTravelUntil > now (switch TrooMovesRiftSafeEnabled); bots: StunBreakImmuneUntil. Traveller
--     stamps: TrooRiftTravelFrom / To / Speed / By / Until, TrooRiftTravelAt (last); TrooRiftTravelEndAt, TrooRiftTravelTime.
--   Diagnostics: script TrooMovesRifts, TrooMovesRiftTrips, TrooMovesRiftCancels, TrooRiftSaves. Numbers: TrooMoves_<name>.
VERSION = "1.11" -- v1.11 Arc Lantern stuns every zapped dino 1 s (MDA-377)
-- v1.11 (MDA-377; Kepu 2026-11-09 21:25 "It needs to shock them still and do more damage" -> "12 per zap" (SkillTree 1.83 gives
--   TrooPartLanternDamage 12), "1 s, every dino zapped", "Raptor shock look"): every dino the lantern zaps (the first target and
--   each chained one, picked by the zap's own rules: enemies only (squad + ModeRules), Sap Wall line check) is stunned through the
--   Shock Cannon's path (ScreechServer hit(), b.shock): StunnedUntil = max(current, zap + TrooLanternStunTime (1 s)). It is the
--   game's one stun, so everything that watches StunnedUntil applies exactly as for the cannon: Thick Hide III / star trims,
--   Brace / Head Down (SkillEffects), the Feather Shed and Antivenom Pump immunity watchers (TrooShedImmuneUntil /
--   DiloImmuneUntil undo it), Feather Shed / Adrenaline / Stun Breaker break it, StunClient + StunFX on players (no moves, dizzy
--   stars), BotServer lays a bot down and it does nothing until it ends. Armor (BoneCrest) cuts the damage only, never the stun.
--   Stamps (target, before the troodon's TrooLanternZapAt): TrooLanternStunUntil (the StunnedUntil written); 0.1 s later
--   TrooLanternStunned = the stun's length from the zap after those rules (s, 0 = immune / broken; like ScreechStunTime).
--   TrooPartsFX 1.5 draws the Shock Cannon stun look + body arcs while it lasts. Switch: script attribute
--   TrooMovesLanternStunEnabled (default true, read at each zap; false = 1.10: no stun). Number: script TrooLanternStunTime (1).
--   Diagnostic: script TrooMovesLanternStuns (count).
if script:GetAttribute("TrooMovesSapHeightEnabled") == nil then script:SetAttribute("TrooMovesSapHeightEnabled", true) end -- v1.9
if script:GetAttribute("TrooMovesLanternTrackEnabled") == nil then script:SetAttribute("TrooMovesLanternTrackEnabled", true) end -- v1.8
for _, k in ipairs({"TrooMovesLastFeatherEnabled", "TrooMovesRefundEnabled", "TrooMovesPlumeEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end -- v1.6
end
local SHOT_SPEED_MUL, SHOT_ASSIST_DEG = 1.5, 45 -- v1.4
local function shotPass() return script:GetAttribute("ShotPassEnabled") ~= false end -- v1.4
if script:GetAttribute("ShotPassEnabled") == nil then script:SetAttribute("ShotPassEnabled", true) end -- v1.4
if script:GetAttribute("TrooMovesSapLookEnabled") == nil then script:SetAttribute("TrooMovesSapLookEnabled", true) end
if script:GetAttribute("TrooMoves_sapProfile") == nil then script:SetAttribute("TrooMoves_sapProfile", "0.82,0.94,1,0.9,0.78") end
local CFG = {menderWindup = 0.45, menderFly = 0.75, menderTick = 0.25, menderHopFly = 0.5,
	lanternWindup = 0.42, lanternFly = 0.55, lanternZapDelay = 0.32, lanternZapRadius = 16, lanternChainStep = 0.12, lanternArc = 6,
	sapWindup = 0.34, sapFly = 0.5, sapHeight = 18, sapThick = 2, sapSegments = 5, sapClear = 3, sapTransparency = 0.08,
	lanternTrackLeash = 1.5, lanternTrackZapDelay = 0, -- v1.8
	shedWindup = 0.15, shedShoveTime = 0.3,
	portalWindup1 = 0.4, portalWindup2 = 0.52, portalOpen1 = 0.35, portalOpen2 = 0.8, portalNear = 10, portalRadius = 6,
	portalTick = 0.1, portalLock = 1, portalClearW = 6, portalClearH = 8, portalStep = 4}
local IDS = {"omender", "olantern", "osapwall", "oshed", "oportal"}

script:SetAttribute("TrooMovesServerVersion", VERSION)
for _, k in ipairs({"TrooMovesHits", "TrooMovesHeals", "TrooMovesWalls", "TrooMovesPortals", "TrooMovesShedBlocks",
	"TrooMovesSquadSkips"}) do script:SetAttribute(k, 0) end
for _, k in ipairs({"TrooMovesServerEnabled", "TrooMovesModeRulesEnabled", "TrooMovesSquadEnabled", "TrooMovesShedWatchEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
for _, id in ipairs(IDS) do
	if script:GetAttribute("TrooMoves_" .. id .. "Enabled") == nil then script:SetAttribute("TrooMoves_" .. id .. "Enabled", true) end
end
for k, v in pairs(CFG) do
	if script:GetAttribute("TrooMoves_" .. k) == nil then script:SetAttribute("TrooMoves_" .. k, v) end
end
local function cfg(k) return tonumber(script:GetAttribute("TrooMoves_" .. k)) or CFG[k] end
local function on(id)
	return script:GetAttribute("TrooMovesServerEnabled") ~= false and script:GetAttribute("TrooMoves_" .. id .. "Enabled") ~= false
end
local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end
local function v3s(v) return ("%.2f,%.2f,%.2f"):format(v.X, v.Y, v.Z) end

-- mode + squad rules (TrooAttackServer 1.0) --------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TrooMovesMode", MODE)
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
local function testAlly(m) -- Studio-only hook (see the header)
	if not RunService:IsStudio() then return false end
	local n = script:GetAttribute("TrooMovesTestAllyName")
	return type(n) == "string" and n ~= "" and m.Name == n and isBot(m)
end
local function squadmate(a, b)
	if not a or not b then return false end
	if testAlly(b) then return true end
	if script:GetAttribute("TrooMovesSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b) == true
end
local function mayHarm(source, target)
	if squadmate(source, target) then
		count("TrooMovesSquadSkips")
		return false
	end
	if script:GetAttribute("TrooMovesModeRulesEnabled") == false then return true end
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
local function shielded(m, t) return num(m, "EnergyShieldUntil", 0) > t end
local function takenMul(m, t)
	local mul = 1
	local u, dm = m:GetAttribute("DebuffUntil"), m:GetAttribute("DebuffDamageTakenMul")
	if typeof(u) == "number" and typeof(dm) == "number" and t < u then mul = dm end
	if num(m, "DazedUntil", 0) > t then mul *= math.max(1, num(m, "DazedDamageMul", 1)) end
	if num(m, "StunBreakImmuneUntil", 0) > t then mul = 0 end
	return mul
end
local armorMul do -- v1.7 (MDA-366): armor on every attack, ServerStorage.DinoArcade.BoneCrest 1.7 armor()
	local mod
	armorMul = function(victim)
		if script:GetAttribute("TrooMovesServerArmorAllEnabled") == false then return 1 end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end) end
		local a = mod and mod.armor and mod.armor(victim) or 1
		if a ~= 1 then script:SetAttribute("TrooMovesServerArmorCuts", (script:GetAttribute("TrooMovesServerArmorCuts") or 0) + 1) end
		return a
	end
	if script:GetAttribute("TrooMovesServerArmorAllEnabled") == nil then script:SetAttribute("TrooMovesServerArmorAllEnabled", true) end
end
local function damage(char, player, m, base, with, t)
	if shielded(m, t) then return 0 end
	local d = math.max(0, base) * takenMul(m, t) * armorMul(m) -- v1.7 (MDA-366): armor
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
	count("TrooMovesHits")
	return d
end
local function healthOf(m) -- current, max (players: Humanoid; the test ally: DummyHealth)
	if Players:GetPlayerFromCharacter(m) then
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then return hum.Health, hum.MaxHealth end
		return 0, 1
	end
	return num(m, "DummyHealth", 0), math.max(1, num(m, "DummyMaxHealth", 1))
end
local function heal(m, amount) -- TrooAttackServer 1.0 heal(); returns HP added
	if amount <= 0 then return 0 end
	if Players:GetPlayerFromCharacter(m) then
		local hum = m:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or hum.Health >= hum.MaxHealth then return 0 end
		local before = hum.Health
		hum.Health = math.min(hum.MaxHealth, before + amount)
		return hum.Health - before
	end
	local hp, mx = m:GetAttribute("DummyHealth"), m:GetAttribute("DummyMaxHealth")
	if typeof(hp) ~= "number" or typeof(mx) ~= "number" or hp <= 0 or hp >= mx then return 0 end
	local after = math.min(mx, hp + amount)
	m:SetAttribute("DummyHealth", after)
	return after - hp
end
local function stampHeal(m, added, t)
	if added <= 0 then return end
	m:SetAttribute("TrooHealAmount", math.floor(added * 10 + 0.5) / 10)
	m:SetAttribute("TrooHealAt", t) -- last: TrooFX "+N"
	count("TrooMovesHeals")
end
-- v1.6: Overheal Plume on the Mender Drone's heals
local passivesMod
local function passives()
	if passivesMod == nil then
		passivesMod = false
		pcall(function() passivesMod = require(ServerStorage:WaitForChild("DinoArcade", 5):WaitForChild("TrooPassives", 5)) end)
	end
	return passivesMod or nil
end
local function healBy(healer, target, amount)
	local added = heal(target, amount)
	if amount > added and script:GetAttribute("TrooMovesPlumeEnabled") ~= false then
		local P = passives()
		if P then pcall(P.plumeAdd, healer, target, amount - added, now(), testAlly(target)) end
	end
	return added
end
local function stampHit(m, kind, by, t)
	m:SetAttribute("TrooHitKind", kind)
	m:SetAttribute("TrooHitBy", by)
	m:SetAttribute("TrooHitAt", t) -- last: TrooFX hit flash
end

-- world --------------------------------------------------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
local function worldExclude()
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX", "PachyFX_Local", "DiloFX", "TrooFX", "TrooPartsFX", "TrooWalls"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rayParams.FilterDescendantsInstances = ex
	overlap.FilterDescendantsInstances = ex
	return rayParams
end
local function groundY(pos, fallback)
	local g = workspace:Raycast(Vector3.new(pos.X, pos.Y + 60, pos.Z), Vector3.new(0, -200, 0), worldExclude())
	return g and g.Position.Y or fallback
end

-- remotes + checks (DiloMovesServer 1.x) -------------------------------------------------------------------------------------
local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local function check(player, stamp, id, prefix, aimDir, aimPoint, breakFree)
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
	elseif num(char, "StunnedUntil", 0) > t and not breakFree then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true and not breakFree then
		r = "pinned"
	elseif id ~= "oportal" and char:GetAttribute("TrooRiftPlacing") == true then -- v1.10: placing a rift
		r = "placing"
	elseif SNARE_MOVES[id] and snareBlocked(char) then -- v1.5
		r = "snared"
	elseif num(char, "DazedUntil", 0) > t and not breakFree then
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
local function alive(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	return char.Parent ~= nil and hum ~= nil and hum.Health > 0 and rootOf(char) ~= nil
end
local function heading(char, aimDir)
	local d = typeof(aimDir) == "Vector3" and flat(aimDir) or Vector3.zero
	if d.Magnitude < 1e-3 then d = flat(rootOf(char).CFrame.LookVector) end
	return d.Magnitude > 1e-3 and d.Unit or -Vector3.zAxis
end
-- the landing point of a throw: aimPoint's flat distance clamped to range (else straight ahead), on the ground
local function landing(char, aimDir, aimPoint, range, minD)
	local root = rootOf(char)
	local p0 = root.Position
	local dir = heading(char, aimDir)
	local d = range
	if typeof(aimPoint) == "Vector3" then
		local v = flat(aimPoint - p0)
		if v.Magnitude > 1e-3 then dir = v.Unit; d = math.clamp(v.Magnitude, minD or 0, range) end
	end
	local p = p0 + dir * d
	return Vector3.new(p.X, groundY(p, p0.Y - 3 * char:GetScale()), p.Z), dir
end
local function handPos(char)
	local root = rootOf(char)
	return root.Position + Vector3.new(0, 1.5 * char:GetScale(), 0) + root.CFrame.LookVector * 2 * char:GetScale()
end

-- Mender Drone -------------------------------------------------------------------------------------------------------------
local function menderPick(char, range, except)
	local root = rootOf(char)
	local best, bestF = nil, math.huge
	local list = {char}
	for _, m in ipairs(everyone(char)) do if squadmate(char, m) then table.insert(list, m) end end
	for _, m in ipairs(list) do
		local r = rootOf(m)
		if r and m ~= except and (m == char or (r.Position - root.Position).Magnitude <= range) then
			local hp, mx = healthOf(m)
			if hp > 0 and hp < mx and hp / mx < bestF then best, bestF = m, hp / mx end
		end
	end
	return best
end
botHook(remote("DinoTrooMenderRequest")):Connect(function(player, stamp)
	local char, t = check(player, stamp, "omender", "TrooPartMender")
	if not char then return end
	ok(char, "TrooPartMender", t)
	local range = math.max(0, num(char, "TrooPartMenderRange", 40))
	local target = menderPick(char, range) or char
	local arrive = t + cfg("menderWindup") + cfg("menderFly")
	local untilT = arrive + math.max(0, num(char, "TrooPartMenderTime", 4))
	char:SetAttribute("TrooMenderTarget", target.Name)
	char:SetAttribute("TrooMenderArriveAt", arrive)
	char:SetAttribute("TrooMenderUntil", untilT)
	char:SetAttribute("TrooMenderAt", t) -- last: TrooPartsFX
	task.delay(cfg("menderWindup"), function()
		if not canStill(char) then result(char, "TrooPartMender", "cancelled", now()); char:SetAttribute("TrooMenderEndAt", now()) return end
		task.wait(cfg("menderFly"))
		local tick = math.max(0.05, cfg("menderTick"))
		local rate = math.max(0, num(char, "TrooPartMenderHeal", 4))
		local hop = char:GetAttribute("TrooPartMenderHop") == true
		while now() < untilT and alive(char) and target.Parent do
			local hp, mx = healthOf(target)
			if hp <= 0 then break end
			if hp >= mx and hop then
				local nxt = menderPick(char, range, target)
				if nxt then
					target = nxt
					char:SetAttribute("TrooMenderHopTo", target.Name)
					char:SetAttribute("TrooMenderHopAt", now()) -- last: the drone flies over
					task.wait(cfg("menderHopFly"))
				end
			end
			stampHeal(target, healBy(char, target, rate * tick), now()) -- v1.6: healBy (Overheal Plume)
			task.wait(tick)
		end
		char:SetAttribute("TrooMenderEndAt", now())
	end)
end)

-- Arc Lantern --------------------------------------------------------------------------------------------------------------
if script:GetAttribute("TrooMovesLanternStunEnabled") == nil then script:SetAttribute("TrooMovesLanternStunEnabled", true) end -- v1.11
if script:GetAttribute("TrooLanternStunTime") == nil then script:SetAttribute("TrooLanternStunTime", 1) end -- v1.11
local function lanternStun(m, t) -- v1.11 (MDA-377): the Shock Cannon's stun (ScreechServer hit(), b.shock)
	if script:GetAttribute("TrooMovesLanternStunEnabled") == false or not m.Parent then return end
	local dur = tonumber(script:GetAttribute("TrooLanternStunTime")) or 1
	if dur <= 0 then return end
	local u = math.max(num(m, "StunnedUntil", 0), t + dur)
	m:SetAttribute("TrooLanternStunUntil", u)
	m:SetAttribute("StunnedUntil", u)
	count("TrooMovesLanternStuns")
	task.delay(0.1, function() -- after Thick Hide (SkillEffects) and the immunity watchers have had their say
		if not m.Parent then return end
		local left = num(m, "StunnedUntil", 0) - t
		m:SetAttribute("TrooLanternStunned", math.max(0, math.floor(left * 100 + 0.5) / 100))
	end)
end
botHook(remote("DinoTrooLanternRequest")):Connect(function(player, stamp, aimDir, aimPoint)
	local char, t = check(player, stamp, "olantern", "TrooPartLantern", aimDir, aimPoint)
	if not char then return end
	ok(char, "TrooPartLantern", t)
	local lRange = math.max(1, num(char, "TrooPartLanternRange", 40))
	local to = landing(char, aimDir, aimPoint, lRange)
	local lFly = shotPass() and cfg("lanternFly") / SHOT_SPEED_MUL or cfg("lanternFly") -- v1.4
	if shotPass() then -- v1.4: strong aim assist
		local root, near, snap = rootOf(char), false, nil
		for _, m in ipairs(enemies(char)) do
			if (rootOf(m).Position - to).Magnitude <= cfg("lanternZapRadius") then near = true break end
		end
		if not near and root then
			local aimV = flat(to - root.Position)
			aimV = aimV.Magnitude > 1e-3 and aimV.Unit or heading(char, aimDir)
			local cosA, bestD = math.cos(math.rad(SHOT_ASSIST_DEG)), nil
			for _, m in ipairs(enemies(char)) do
				local v = flat(rootOf(m).Position - root.Position)
				local d = v.Magnitude
				if d > 1e-3 and d <= lRange and v.Unit:Dot(aimV) >= cosA and (not bestD or d < bestD) then snap, bestD = m, d end
			end
		end
		if snap then
			local sp = rootOf(snap).Position
			to = Vector3.new(sp.X, groundY(sp, sp.Y - 3 * char:GetScale()), sp.Z)
		end
		char:SetAttribute("TrooLanternAssist", snap and snap.Name or "")
	end
	local lock = nil -- v1.8: the locked first target
	if script:GetAttribute("TrooMovesLanternTrackEnabled") ~= false then
		local root = rootOf(char)
		local aimV = flat(to - root.Position)
		aimV = aimV.Magnitude > 1e-3 and aimV.Unit or heading(char, aimDir)
		local cosA, zr = math.cos(math.rad(SHOT_ASSIST_DEG)), cfg("lanternZapRadius")
		local aimedD, nearD, nearM = nil, nil, nil
		for _, m in ipairs(enemies(char)) do
			local rp = rootOf(m).Position
			local v = flat(rp - root.Position)
			local d = v.Magnitude
			if d > 1e-3 and v.Unit:Dot(aimV) >= cosA and d <= lRange + zr then
				local da = flat(rp - to).Magnitude
				if da <= zr and (not aimedD or da < aimedD) then lock, aimedD = m, da end
				if d <= lRange and (not nearD or d < nearD) then nearM, nearD = m, d end
			end
		end
		lock = lock or nearM
		if shotPass() and char:GetAttribute("TrooLanternAssist") ~= "" then -- the assist snap wins
			for _, m in ipairs(enemies(char)) do if m.Name == char:GetAttribute("TrooLanternAssist") then lock = m break end end
		end
	end
	char:SetAttribute("TrooLanternTrack", lock and lock.Name or "")
	char:SetAttribute("TrooLanternFrom", handPos(char))
	char:SetAttribute("TrooLanternTo", to)
	char:SetAttribute("TrooLanternFlight", lFly)
	char:SetAttribute("TrooLanternAt", t) -- last: TrooPartsFX
	task.delay(cfg("lanternWindup"), function()
		if not canStill(char) then result(char, "TrooPartLantern", "cancelled", now()) return end
		local zr = math.max(0, cfg("lanternZapRadius"))
		local function groundAt(m) -- v1.8
			local rp = rootOf(m).Position
			return Vector3.new(rp.X, groundY(rp, rp.Y - 3 * char:GetScale()), rp.Z)
		end
		local function lockOk(m)
			return m ~= nil and m.Parent ~= nil and isTarget(m, char) and mayHarm(char, m)
		end
		if lock then -- v1.8: plan on the target where it is as the lantern leaves the hand
			local root = rootOf(char)
			if lockOk(lock) and root and flat(rootOf(lock).Position - root.Position).Magnitude <= lRange + zr then
				to = groundAt(lock)
			else
				lock = nil
				count("TrooMovesLanternTrackLost")
			end
		end
		task.wait(lFly) -- v1.4 (was cfg("lanternFly"))
		local tracked = false
		if lock then -- v1.8: carry the landing to the target's current spot within the leash
			if lockOk(lock) and flat(rootOf(lock).Position - to).Magnitude <= math.max(0, cfg("lanternTrackLeash")) * zr then
				to = groundAt(lock)
				tracked = true
			else
				count("TrooMovesLanternTrackLost")
			end
			char:SetAttribute("TrooLanternTo", to)
		end
		local lf, sc = char:GetAttribute("TrooLanternFrom"), char:GetScale() -- v1.2: the lantern's real arc
		if typeof(lf) == "Vector3" and sapArcBlocked(lf, to + Vector3.new(0, 0.8 * sc / 2, 0), cfg("lanternArc") * sc / 2) then
			char:SetAttribute("TrooLanternChainList", "")
			char:SetAttribute("TrooLanternWallAt", now())
			return
		end
		char:SetAttribute("TrooLanternLandAt", now())
		task.wait(tracked and math.max(0, cfg("lanternTrackZapDelay")) or cfg("lanternZapDelay"))
		local hits, names = {}, {}
		local from = to
		local maxN = math.max(0, math.floor(num(char, "TrooPartLanternTargets", 2)))
		local reach = zr
		local first = nil -- v1.8: the tracked target is the first zap (if it is still a target and no wall is in the way)
		if tracked and lockOk(lock) and not sapBlocked(to + Vector3.yAxis * 2, lock) then first = lock end
		for i = 1, maxN do
			local best, bestD = nil, math.huge
			if i == 1 and first then best, bestD = first, 0 count("TrooMovesLanternTracked") end -- v1.8
			for _, m in ipairs(best and {} or enemies(char)) do
				if not hits[m] then
					local d = (rootOf(m).Position - from).Magnitude
					if d <= reach and d < bestD and not sapBlocked(i == 1 and to + Vector3.yAxis * 2 or from, m) then best, bestD = m, d end -- v1.1: Sap Wall
				end
			end
			if not best then break end
			hits[best] = true
			local tz = now()
			damage(char, player, best, num(char, "TrooPartLanternDamage", 8), "troolantern", tz)
			lanternStun(best, tz) -- v1.11 (MDA-377)
			stampHit(best, "zap", char.Name, tz)
			table.insert(names, best.Name)
			char:SetAttribute("TrooLanternChainList", table.concat(names, "|"))
			char:SetAttribute("TrooLanternZapAt", tz) -- last: the arc FX
			from = rootOf(best).Position
			reach = math.max(0, num(char, "TrooPartLanternChain", 24))
			if i < maxN then task.wait(cfg("lanternChainStep")) end
		end
		if #names == 0 then char:SetAttribute("TrooLanternChainList", "") end
	end)
end)

-- Sap Wall -----------------------------------------------------------------------------------------------------------------
local wallFolder = workspace:FindFirstChild("TrooWalls")
if not wallFolder then
	wallFolder = Instance.new("Folder")
	wallFolder.Name = "TrooWalls"
	wallFolder.Parent = workspace
end
local function wallFrame(center, along)
	-- X = along the wall (square to the throw), Z = the throw line
	return CFrame.fromMatrix(center, along, Vector3.yAxis)
end
local function occupied(cf, width, char, height)
	local half = Vector3.new(width / 2 + cfg("sapClear"), (height or cfg("sapHeight")) / 2 + 4, cfg("sapThick") / 2 + cfg("sapClear")) -- v1.9: + height
	local list = everyone(nil)
	if char and char.Parent then table.insert(list, char) end
	for _, m in ipairs(list) do
		local r = rootOf(m)
		if r then
			local q = cf:PointToObjectSpace(r.Position)
			if math.abs(q.X) <= half.X and math.abs(q.Y) <= half.Y and math.abs(q.Z) <= half.Z then return m end
		end
	end
	return nil
end
botHook(remote("DinoTrooSapRequest")):Connect(function(player, stamp, aimDir, aimPoint)
	local char, t = check(player, stamp, "osapwall", "TrooPartSap", aimDir, aimPoint)
	if not char then return end
	local width = math.max(4, num(char, "TrooPartSapWidth", 50))
	local to, dir = landing(char, aimDir, aimPoint, math.max(1, num(char, "TrooPartSapRange", 40)))
	local along = Vector3.yAxis:Cross(dir).Unit
	local H = math.max(2, cfg("sapHeight"))
	if script:GetAttribute("TrooMovesSapHeightEnabled") ~= false and num(char, "TrooPartSapHeight", 0) > 0 then H = math.max(2, num(char, "TrooPartSapHeight", 0)) end -- v1.9
	local cf = wallFrame(to + Vector3.new(0, H / 2, 0), along)
	if occupied(cf, width, char, H) then result(char, "TrooPartSap", "occupied", t) return end
	ok(char, "TrooPartSap", t)
	local life = math.max(0.1, num(char, "TrooPartSapTime", 2.1))
	char:SetAttribute("TrooSapFrom", handPos(char))
	char:SetAttribute("TrooSapTo", to)
	local sFly = shotPass() and cfg("sapFly") / SHOT_SPEED_MUL or cfg("sapFly") -- v1.4
	char:SetAttribute("TrooSapFlight", sFly)
	char:SetAttribute("TrooSapWidth", width)
	char:SetAttribute("TrooSapTime", life)
	char:SetAttribute("TrooSapHeight", H) -- v1.9
	char:SetAttribute("TrooSapAt", t) -- last: TrooPartsFX
	task.delay(cfg("sapWindup"), function()
		if not canStill(char) then result(char, "TrooPartSap", "cancelled", now()) return end
		task.wait(sFly) -- v1.4 (was cfg("sapFly"))
		local ts = now()
		char:SetAttribute("TrooSapSplatAt", ts)
		if occupied(cf, width, char, H) then -- v1.9: + height
			char:SetAttribute("TrooSapResult", "occupied")
			char:SetAttribute("TrooPartSapReadyAt", ts) -- the recharge is given back
			return
		end
		local m = Instance.new("Model")
		m.Name = "SapWall"
		m:SetAttribute("SapWallOwner", char.Name)
		m:SetAttribute("SapWallUntil", ts + life)
		local n = math.max(1, math.floor(cfg("sapSegments")))
		local segW = width / n
		local look = script:GetAttribute("TrooMovesSapLookEnabled") ~= false -- v1.3
		local prof = {}
		for v in string.gmatch(tostring(script:GetAttribute("TrooMoves_sapProfile") or ""), "[^,]+") do
			local x = tonumber(v)
			if x then table.insert(prof, math.clamp(x, 0.1, 1)) end
		end
		for i = 1, n do
			local h = H * (i % 2 == 1 and 1 or 0.9)
			if look and #prof > 0 then h = H * prof[(i - 1) % #prof + 1] end
			local p = Instance.new("Part")
			p.Name = "Sap_" .. i
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, true, true, false
			p.Size = Vector3.new(segW * 1.02, h, math.max(0.5, cfg("sapThick")))
			p.CFrame = cf * CFrame.new((i - 0.5) * segW - width / 2, (h - H) / 2, 0)
			p.Material = Enum.Material.Glass
			p.Color = Color3.fromRGB(255, 180, 58)
			p.Transparency = 0.25
			if look then -- v1.3
				p.Material = Enum.Material.SmoothPlastic
				p.Color = Color3.fromHex("D9821C")
				p.Transparency = math.clamp(cfg("sapTransparency"), 0, 0.9)
			end
			p.CastShadow = false
			p:SetAttribute("SapWallOwner", char.Name)
			p:SetAttribute("SapWallUntil", ts + life)
			CollectionService:AddTag(p, "SapWall")
			p.Parent = m
		end
		m.Parent = wallFolder
		count("TrooMovesWalls")
		char:SetAttribute("TrooSapResult", "wall")
		task.delay(life, function()
			if m.Parent then m:Destroy() end
			if char.Parent then char:SetAttribute("TrooSapEndAt", now()) end
		end)
	end)
end)

-- Feather Shed -------------------------------------------------------------------------------------------------------------
local function findModel(name)
	if type(name) ~= "string" or name == "" then return nil end
	local pl = Players:FindFirstChild(name)
	if pl and pl:IsA("Player") and pl.Character then return pl.Character end
	for _, b in ipairs(bots()) do if b.Name == name then return b end end
	return nil
end
local function breakPin(char, t)
	if char:GetAttribute("PinHeld") ~= true then return false end
	local by = findModel(char:GetAttribute("PinnedBy"))
	if by then
		by:SetAttribute("ShakeOffReason", "shed")
		by:SetAttribute("ShakeOffAt", t) -- last: PounceServer / BotServer release the pin
	else
		char:SetAttribute("PinHeld", nil)
	end
	return true
end
local SHED_TAGS = {StunnedUntil = "stun", TheriSnaredUntil = "snare", DazedUntil = "daze"}
local function shedImmune(char) return script:GetAttribute("TrooMovesShedWatchEnabled") ~= false and num(char, "TrooShedImmuneUntil", 0) > now() end
local function watchShed(char)
	for tag in pairs(SHED_TAGS) do
		char:GetAttributeChangedSignal(tag):Connect(function()
			if not shedImmune(char) then return end
			local t = now()
			if num(char, tag, 0) > t then
				task.defer(function()
					if num(char, tag, 0) > now() then char:SetAttribute(tag, now()) end
				end)
				char:SetAttribute("TrooShedBlockAt", t)
				count("TrooMovesShedBlocks")
			end
		end)
	end
	char:GetAttributeChangedSignal("PinHeld"):Connect(function()
		if shedImmune(char) and char:GetAttribute("PinHeld") == true then
			task.defer(function() breakPin(char, now()) end)
			char:SetAttribute("TrooShedBlockAt", now())
			count("TrooMovesShedBlocks")
		end
	end)
end
local function shove(src, m, dist, t) -- DiloMovesServer 1.1 shove (TenoAttackServer 1.4 pattern)
	local sRoot, mRoot = rootOf(src), rootOf(m)
	if not (sRoot and mRoot) or dist <= 0 then return false end
	if Players:GetPlayerFromCharacter(m) then
		m:SetAttribute("HeadbuttShoveFrom", sRoot.Position)
		m:SetAttribute("HeadbuttShoveDist", dist)
		m:SetAttribute("HeadbuttShoveTime", cfg("shedShoveTime"))
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
	local T = math.max(0.05, cfg("shedShoveTime"))
	mRoot.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < T do
			local u = math.clamp((os.clock() - t0) / T, 0, 1)
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
local slowFn
local function slow(m, mul, untilT)
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
botHook(remote("DinoTrooShedRequest")):Connect(function(player, stamp)
	local char, t = check(player, stamp, "oshed", "TrooPartShed", nil, nil, true)
	if not char then return end
	ok(char, "TrooPartShed", t)
	local broke = {}
	for tag, name in pairs(SHED_TAGS) do
		if num(char, tag, 0) > t then char:SetAttribute(tag, t); table.insert(broke, name) end
	end
	if breakPin(char, t) then table.insert(broke, "pin") end
	table.sort(broke)
	char:SetAttribute("TrooShedImmuneUntil", t + math.max(0, num(char, "TrooPartShedImmune", 1)))
	char:SetAttribute("TrooShedBroke", table.concat(broke, "|"))
	char:SetAttribute("TrooShedAt", t) -- last: TrooPartsFX
	task.delay(cfg("shedWindup"), function()
		if not alive(char) then return end
		local tb = now()
		local r = math.max(0, num(char, "TrooPartShedKnockRadius", 0))
		local n = 0
		if r > 0 then
			local root = rootOf(char)
			for _, m in ipairs(enemies(char)) do
				if (rootOf(m).Position - root.Position).Magnitude <= r and not shielded(m, tb) and not sapBlocked(root, m) then -- v1.1: Sap Wall
					shove(char, m, r, tb)
					slow(m, num(char, "TrooPartShedSlowMul", 0.75), tb + num(char, "TrooPartShedSlowTime", 2))
					stampHit(m, "shed", char.Name, tb)
					n += 1
				end
			end
		end
		char:SetAttribute("TrooShedHits", n)
		char:SetAttribute("TrooShedBurstAt", tb)
	end)
end)

-- Portal Feathers ----------------------------------------------------------------------------------------------------------
local portals = {} -- [owner char] = {a, b, untilT, squad}
local probe = Instance.new("Part") -- the exact-shape spot check (GetPartsInPart; a bounds box flags big rotated rocks)
probe.Name = "TrooPortalProbe"
probe.Anchored, probe.CanCollide, probe.CanQuery, probe.CanTouch, probe.Transparency = true, false, false, false, 1
probe.Parent = wallFolder
local function spotFree(p)
	worldExclude()
	local w, h = cfg("portalClearW"), cfg("portalClearH")
	probe.Size = Vector3.new(w, h, w)
	probe.CFrame = CFrame.new(p + Vector3.new(0, h / 2 + 0.5, 0))
	local parts = workspace:GetPartsInPart(probe, overlap)
	for _, q in ipairs(parts) do
		if q.CanCollide then return false end
	end
	return true
end
local riftPress -- v1.10 (set by the rift block below)
botHook(remote("DinoTrooPortalRequest")):Connect(function(player, stamp, aimDir, aimPoint)
	if script:GetAttribute("TrooPortalRiftEnabled") ~= false and riftPress then riftPress(player, stamp) return end -- v1.10
	local char, t = check(player, stamp, "oportal", "TrooPartPortal", aimDir, aimPoint)
	if not char then return end
	local root = rootOf(char)
	local near = cfg("portalNear")
	local range = math.max(near + 8, num(char, "TrooPartPortalRange", 40))
	local bPos, dir = landing(char, aimDir, aimPoint, range, near + 8)
	local aFlat = root.Position + dir * near
	local aPos = Vector3.new(aFlat.X, groundY(aFlat, root.Position.Y - 3), aFlat.Z)
	if not spotFree(aPos) then result(char, "TrooPartPortal", "blocked", t) return end
	local found = false
	local d = flat(bPos - root.Position).Magnitude
	while d >= near + 8 do
		local f = root.Position + dir * d
		local p = Vector3.new(f.X, groundY(f, root.Position.Y - 3), f.Z)
		if spotFree(p) then bPos, found = p, true break end
		d -= math.max(1, cfg("portalStep"))
	end
	if not found then result(char, "TrooPartPortal", "blocked", t) return end
	ok(char, "TrooPartPortal", t)
	local open1 = t + cfg("portalWindup1") + cfg("portalOpen1")
	local open2 = t + cfg("portalWindup2") + cfg("portalOpen2")
	local untilT = open2 + math.max(0.5, num(char, "TrooPartPortalTime", 6))
	char:SetAttribute("TrooPortalA", aPos)
	char:SetAttribute("TrooPortalB", bPos)
	char:SetAttribute("TrooPortalOpenAt", open1)
	char:SetAttribute("TrooPortalOpen2At", open2)
	char:SetAttribute("TrooPortalUntil", untilT)
	char:SetAttribute("TrooPortalAt", t) -- last: TrooPartsFX
	task.delay(cfg("portalWindup1"), function()
		if not canStill(char) then
			result(char, "TrooPartPortal", "cancelled", now())
			char:SetAttribute("TrooPortalUntil", now())
			return
		end
		portals[char] = {a = aPos, b = bPos, open = open2, untilT = untilT, squad = char:GetAttribute("TrooPartPortalSquad") == true, n = 0}
		count("TrooMovesPortals")
	end)
end)
local function usePortal(m, from, to, t)
	local r = rootOf(m)
	local lift = math.max(2, r.Position.Y - groundY(r.Position, r.Position.Y - 3))
	local out = Vector3.new(to.X, to.Y + lift, to.Z) -- the other ring's centre, the root's height above the ground kept
	m:PivotTo(CFrame.new(out) * (r.CFrame - r.Position))
	m:SetAttribute("TrooPortalLockUntil", t + math.max(0.1, cfg("portalLock")))
	m:SetAttribute("TrooPortalFrom", from)
	m:SetAttribute("TrooPortalTo", to)
	m:SetAttribute("TrooPortalUsedAt", t) -- last
end
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < cfg("portalTick") then return end
	acc = 0
	local t = now()
	for owner, p in pairs(portals) do
		if t >= p.untilT or not owner.Parent or script:GetAttribute("TrooMoves_oportalEnabled") == false then
			portals[owner] = nil
			if owner.Parent then owner:SetAttribute("TrooPortalEndAt", t) end
		elseif t >= p.open then
			local users = {owner}
			if p.squad then
				for _, m in ipairs(everyone(owner)) do
					if squadmate(owner, m) and (not isBot(m) or testAlly(m)) then table.insert(users, m) end
				end
			end
			for _, m in ipairs(users) do
				local r = rootOf(m)
				local hum = m:FindFirstChildOfClass("Humanoid")
				if r and hum and hum.Health > 0 and num(m, "TrooPortalLockUntil", 0) <= t and m:GetAttribute("PinHeld") ~= true
					and (Players:GetPlayerFromCharacter(m) or testAlly(m)) then
					local rad = math.max(1, cfg("portalRadius"))
					for _, pair in ipairs({{p.a, p.b}, {p.b, p.a}}) do
						local v = r.Position - pair[1]
						if flat(v).Magnitude <= rad and math.abs(v.Y) <= 10 * math.max(1, m:GetScale()) then
							usePortal(m, pair[1], pair[2], t)
							p.n += 1
							break
						end
					end
				end
			end
		end
	end
end)

-- Portal Rift (v1.10, MDA-375; see the v1.10 notes) ---------------------------------------------------------------------------
do
	local RIFT_CFG = {riftBoostMin = 1.25, riftBoostMax = 1.55, riftMinWalk = 10, riftSample = 3, riftPlaceMax = 15, riftRadius = 6,
		riftLock = 1, riftSpeedMul = 5, riftLen = 250, riftTime = 30, riftCooldown = 45}
	for k, v in pairs(RIFT_CFG) do
		CFG[k] = v
		if script:GetAttribute("TrooMoves_" .. k) == nil then script:SetAttribute("TrooMoves_" .. k, v) end
	end
	for k, v in pairs({TrooPortalRiftEnabled = true, TrooMoves_riftBotsEnabled = false, TrooMovesRiftSafeEnabled = true}) do
		if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
	end
	local rifts = {} -- [owner char] = {phase "placing" / "open", pts, cum, len, maxLen, a, b, t0, untilT, lift, users}
	local travelling = setmetatable({}, {__mode = "k"})
	local function groundOf(p) return Vector3.new(p.X, groundY(p, p.Y - 3), p.Z) end
	local function placingOff(char)
		char:SetAttribute("TrooRiftPlacing", false)
		char:SetAttribute("TrooRiftSpeedMul", nil)
	end
	local function cancel(char, rf, t, why)
		rifts[char] = nil
		if not char.Parent then return end
		placingOff(char)
		char:SetAttribute("TrooPartPortalReadyAt", t) -- nothing used
		result(char, "TrooPartPortal", "cancelled", t)
		char:SetAttribute("TrooRiftCancelWhy", why)
		char:SetAttribute("TrooRiftCancelAt", t) -- last: TrooPartsFX
		count("TrooMovesRiftCancels")
	end
	local function closeRift(char, t)
		local rf = rifts[char]
		if not rf then return end
		rifts[char] = nil
		if char.Parent then
			if rf.phase == "placing" then placingOff(char) end
			char:SetAttribute("TrooRiftEndAt", t) -- last: TrooPartsFX
		end
	end
	local function finish(char, rf, t)
		if rifts[char] ~= rf or rf.phase ~= "placing" then return end
		local root = rootOf(char)
		if root and alive(char) then
			local last = rf.pts[#rf.pts]
			local d = (root.Position - last).Magnitude
			if d > 0.5 then table.insert(rf.pts, root.Position); rf.len += d end
		end
		-- end B: walk back along the path to the first spot clear of terrain
		while #rf.pts > 1 and rf.len >= cfg("riftMinWalk") and not spotFree(groundOf(rf.pts[#rf.pts] - Vector3.new(0, rf.lift, 0))) do
			rf.len -= (rf.pts[#rf.pts] - rf.pts[#rf.pts - 1]).Magnitude
			table.remove(rf.pts)
		end
		if rf.len < cfg("riftMinWalk") or #rf.pts < 2 then cancel(char, rf, t, "short") return end
		rf.cum = {0}
		for i = 2, #rf.pts do rf.cum[i] = rf.cum[i - 1] + (rf.pts[i] - rf.pts[i - 1]).Magnitude end
		rf.len = rf.cum[#rf.cum]
		rf.b = groundOf(rf.pts[#rf.pts] - Vector3.new(0, rf.lift, 0))
		rf.phase = "open"
		rf.users[char] = "arrived" -- the troodon stands on end B: it must step out first
		local life = num(char, "TrooPartPortalRiftTime", 0)
		if life <= 0 then life = cfg("riftTime") end
		local cd = num(char, "TrooPartPortalRiftCooldown", 0)
		if cd <= 0 then cd = cfg("riftCooldown") end
		rf.untilT = t + life
		local enc = {}
		for _, p in ipairs(rf.pts) do
			local g = p - Vector3.new(0, rf.lift, 0)
			table.insert(enc, ("%.1f,%.1f,%.1f"):format(g.X, g.Y, g.Z))
		end
		placingOff(char)
		result(char, "TrooPartPortal", "ok", t)
		char:SetAttribute("TrooPartPortalRechargeUsed", cd)
		char:SetAttribute("TrooPartPortalReadyAt", t + cd)
		char:SetAttribute("TrooRiftB", rf.b)
		char:SetAttribute("TrooRiftLen", math.floor(rf.len * 10 + 0.5) / 10)
		char:SetAttribute("TrooRiftPath", table.concat(enc, ";"))
		char:SetAttribute("TrooRiftUntil", rf.untilT)
		char:SetAttribute("TrooRiftOpenAt", t) -- last: TrooPartsFX
		count("TrooMovesRifts")
	end
	riftPress = function(player, stamp)
		local c0 = player.Character
		local r0 = c0 and rifts[c0]
		if r0 and r0.phase == "placing" then -- press 2: end B now
			if typeof(stamp) == "number" then finish(c0, r0, now()) end
			return
		end
		local char, t = check(player, stamp, "oportal", "TrooPartPortal")
		if not char then return end
		local root = rootOf(char)
		local a = groundOf(root.Position)
		if not spotFree(a) then result(char, "TrooPartPortal", "blocked", t) return end
		closeRift(char, t) -- an older rift of this troodon closes
		local maxLen = num(char, "TrooPartPortalRiftLength", 0)
		if maxLen <= 0 then maxLen = cfg("riftLen") end
		rifts[char] = {phase = "placing", pts = {root.Position}, len = 0, maxLen = maxLen, a = a, t0 = t, lift = root.Position.Y - a.Y, users = {}}
		char:SetAttribute("TrooPartPortalRechargeUsed", nil)
		result(char, "TrooPartPortal", "placing", t)
		char:SetAttribute("TrooRiftA", a)
		char:SetAttribute("TrooRiftMax", maxLen)
		char:SetAttribute("TrooRiftSpeedMul", cfg("riftBoostMin"))
		char:SetAttribute("TrooRiftPlacing", true)
		char:SetAttribute("TrooRiftAt", t) -- last: TrooPartsFX
	end
	local function pointAt(rf, d)
		local pts, cum = rf.pts, rf.cum
		for i = 2, #pts do
			if d <= cum[i] or i == #pts then
				local segL = math.max(1e-3, cum[i] - cum[i - 1])
				local u = math.clamp((d - cum[i - 1]) / segL, 0, 1)
				return pts[i - 1]:Lerp(pts[i], u), (pts[i] - pts[i - 1])
			end
		end
		return pts[#pts], Vector3.zAxis
	end
	local function startTravel(m, owner, rf, dir, t)
		local r = rootOf(m)
		local hum = m:FindFirstChildOfClass("Humanoid")
		local isPl = Players:GetPlayerFromCharacter(m) ~= nil
		local run = isPl and num(m, "MoveRunSpeed", 0) or 0
		if run <= 0 then run = hum and hum.WalkSpeed or 30 end
		local speed = math.max(10, run * math.max(0.1, cfg("riftSpeedMul")))
		local L = rf.len
		local dur = L / speed
		local dLift = (r.Position.Y - groundY(r.Position, r.Position.Y - 3)) - rf.lift
		travelling[m] = true
		rf.users[m] = "arrived"
		local ff = Instance.new("ForceField")
		ff.Name, ff.Visible = "TrooRiftField", false
		ff.Parent = m
		if isPl and hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end) end
		if not isPl then m:SetAttribute("StunBreakImmuneUntil", t + dur + 0.2) end
		m:SetAttribute("TrooRiftTravelFrom", dir == 1 and rf.a or rf.b)
		m:SetAttribute("TrooRiftTravelTo", dir == 1 and rf.b or rf.a)
		m:SetAttribute("TrooRiftTravelSpeed", math.floor(speed * 10 + 0.5) / 10)
		m:SetAttribute("TrooRiftTravelBy", owner.Name)
		m:SetAttribute("TrooRiftTravelUntil", t + dur + 0.1)
		m:SetAttribute("TrooRiftTravelAt", t) -- last: TrooPartsFX streak
		task.spawn(function()
			local t0 = os.clock()
			local rot0 = r.CFrame - r.Position
			local lastF = nil
			while r.Parent and m.Parent do
				local sd = (os.clock() - t0) * speed
				if sd >= L then break end
				local p, fwd = pointAt(rf, dir == 1 and sd or (L - sd))
				local f = flat(fwd) * dir
				if f.Magnitude > 1e-3 then lastF = f.Unit end
				local pos = p + Vector3.new(0, dLift, 0)
				r.Anchored = true
				m:PivotTo(lastF and CFrame.lookAt(pos, pos + lastF) or (CFrame.new(pos) * rot0))
				RunService.Heartbeat:Wait()
			end
			if r.Parent then
				local e = (dir == 1 and rf.pts[#rf.pts] or rf.pts[1]) + Vector3.new(0, dLift, 0)
				m:PivotTo(lastF and CFrame.lookAt(e, e + lastF) or (CFrame.new(e) * rot0))
				r.Anchored = false
				r.AssemblyLinearVelocity = Vector3.zero
			end
			if ff.Parent then ff:Destroy() end
			if isPl and hum and hum.Parent and not (m:GetAttribute("TrooLastFeatherReady") == true or num(m, "TrooLastFeatherUntil", 0) > now()) then
				pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
			end
			travelling[m] = nil
			local te = now()
			m:SetAttribute("TrooPortalLockUntil", te + math.max(0, cfg("riftLock")))
			m:SetAttribute("TrooRiftTravelEndAt", te)
			m:SetAttribute("TrooRiftTravelTime", math.floor((os.clock() - t0) * 1000 + 0.5) / 1000)
			count("TrooMovesRiftTrips")
		end)
	end
	local function near(p, e, m)
		local v = p - e
		return flat(v).Magnitude <= math.max(1, cfg("riftRadius")) and math.abs(v.Y) <= 10 * math.max(1, m:GetScale())
	end
	RunService.Heartbeat:Connect(function()
		local t = now()
		for owner, rf in pairs(rifts) do
			if rf.phase == "placing" then
				local root = rootOf(owner)
				if not owner.Parent or not root or not alive(owner) then
					cancel(owner, rf, t, "dead")
				else
					local last = rf.pts[#rf.pts]
					local d = (root.Position - last).Magnitude
					if d >= math.max(0.5, cfg("riftSample")) then
						table.insert(rf.pts, root.Position)
						rf.len += d
						local u = math.clamp(rf.len / math.max(1, rf.maxLen), 0, 1)
						local mul = math.floor((cfg("riftBoostMin") + (cfg("riftBoostMax") - cfg("riftBoostMin")) * u) * 100 + 0.5) / 100
						if owner:GetAttribute("TrooRiftSpeedMul") ~= mul then owner:SetAttribute("TrooRiftSpeedMul", mul) end
						owner:SetAttribute("TrooRiftWalked", math.floor(rf.len))
					end
					if rf.len >= rf.maxLen or t - rf.t0 >= cfg("riftPlaceMax") then finish(owner, rf, t) end
				end
			elseif t >= rf.untilT or not owner.Parent or script:GetAttribute("TrooPortalRiftEnabled") == false then
				closeRift(owner, t)
			else
				local cands = {}
				for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(cands, pl.Character) end end
				if script:GetAttribute("TrooMoves_riftBotsEnabled") == true then
					for _, b in ipairs(bots()) do table.insert(cands, b) end
				end
				for _, m in ipairs(cands) do
					local r = rootOf(m)
					local hum = m:FindFirstChildOfClass("Humanoid")
					if r and hum and hum.Health > 0 and not travelling[m] then
						local nA, nB = near(r.Position, rf.a, m), near(r.Position, rf.b, m)
						if rf.users[m] == "arrived" then
							if not nA and not nB then rf.users[m] = nil end
						elseif (nA or nB) and num(m, "TrooPortalLockUntil", 0) <= t and m:GetAttribute("PinHeld") ~= true
							and not r.Anchored and m:GetAttribute("DummyState") ~= "ko" and not (m == owner and owner:GetAttribute("TrooRiftPlacing") == true) then
							startTravel(m, owner, rf, nA and 1 or -1, t)
						end
					end
				end
			end
		end
	end)
end
local function onCharacter(char) watchShed(char) end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(onCharacter)
	if pl.Character then onCharacter(pl.Character) end
end
botJoin(Players.PlayerAdded):Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end

-- v1.6: the health watcher (Last Feather, Fortify / Plume refunds) and the plume fade (see the v1.6 notes)
do
	local FIELD = "TrooLastFeatherField"
	local watched = setmetatable({}, {__mode = "k"})
	local function lfReady(char)
		return script:GetAttribute("TrooMovesLastFeatherEnabled") ~= false and char:GetAttribute("Species") == "Troodon"
			and char:GetAttribute("TrooPartLastFeatherEnabled") == true and char:GetAttribute("TrooLastFeatherUsed") ~= true
	end
	local function syncDead(char, st)
		if not st.hum then return end
		local ready = st.hum.Health > 0 and lfReady(char)
		local off = ready or (st.untilT ~= nil and now() < st.untilT)
		if st.deadOff ~= off then
			st.deadOff = off
			pcall(function() st.hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not off) end)
		end
		local cur = char:GetAttribute("TrooLastFeatherReady")
		if cur ~= ready and (ready or cur ~= nil) then char:SetAttribute("TrooLastFeatherReady", ready) end
	end
	local function zoneDrop(char, pos)
		local tas = game:GetService("ServerScriptService"):FindFirstChild("TrooAttackServer")
		local fn = tas and tas:FindFirstChild("TrooZoneDrop")
		if fn then pcall(function() fn:Invoke(char, pos) end) end
	end
	local function save(char, st, t)
		local untouch = math.max(0, num(char, "TrooPartLastFeatherUntouch", 0.7))
		char:SetAttribute("TrooLastFeatherUsed", true)
		st.untilT = t + untouch
		st.own, st.last = 1, 1
		st.hum.Health = 1
		local ff = Instance.new("ForceField")
		ff.Name = FIELD
		ff.Visible = false
		ff.Parent = char
		char:SetAttribute("TrooLastFeatherUntil", st.untilT)
		char:SetAttribute("TrooLastFeatherGlide", char:GetAttribute("TrooPartLastFeatherGlide") == true)
		char:SetAttribute("TrooLastFeatherAt", t) -- last: TrooLastFeather client + TrooPartsFX
		count("TrooLastFeatherSaves")
		local root = rootOf(char)
		if char:GetAttribute("TrooPartLastFeatherZone") == true and root then task.spawn(zoneDrop, char, root.Position) end
		task.delay(untouch, function()
			if ff.Parent then ff:Destroy() end
			syncDead(char, st)
		end)
	end
	local function refunds(m, drop, t)
		local refund = 0
		if num(m, "TrooFortifyUntil", 0) > t then
			local f = drop * (1 - math.clamp(num(m, "TrooFortifyMul", 1), 0, 1))
			if f > 0 then
				refund += f
				m:SetAttribute("TrooFortifySaved", math.floor(f * 10 + 0.5) / 10)
				m:SetAttribute("TrooFortifySavedAt", t) -- last: FX
				count("TrooFortifyRefunds")
			end
		end
		local plume = num(m, "TrooPlumeUntil", 0) > t and num(m, "TrooPlume", 0) or 0
		if plume > 0 then
			local sk = math.min(plume, drop - refund)
			if sk > 0 then
				refund += sk
				m:SetAttribute("TrooPlume", math.floor((plume - sk) * 10 + 0.5) / 10)
				m:SetAttribute("TrooPlumeSoak", math.floor(sk * 10 + 0.5) / 10)
				m:SetAttribute("TrooPlumeSoakAt", t) -- last: FX
				count("TrooPlumeSoaks")
			end
		end
		return refund
	end
	local function watchChar(char)
		if watched[char] then return end
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum or watched[char] then return end
		local st = {hum = hum, last = hum.Health}
		watched[char] = st
		hum.HealthChanged:Connect(function(h)
			if st.own and math.abs(h - st.own) < 1e-3 then st.own = nil st.last = h return end
			local drop = st.last - h
			st.last = h
			if drop <= 0 then syncDead(char, st) return end
			local t = now()
			if num(char, "TrooRiftTravelUntil", 0) > t and script:GetAttribute("TrooMovesRiftSafeEnabled") ~= false then -- v1.10: untouchable on the rift
				local v = math.min(hum.MaxHealth, math.max(h, 0) + drop)
				st.own, st.last = v, v
				hum.Health = v
				count("TrooRiftSaves")
				return
			end
			if st.untilT and t < st.untilT and script:GetAttribute("TrooMovesLastFeatherEnabled") ~= false then
				local v = math.min(hum.MaxHealth, math.max(h, 0) + drop)
				st.own, st.last = v, v
				hum.Health = v
				return
			end
			if h <= 0 then
				if st.deadOff and lfReady(char) then save(char, st, t) end
				return
			end
			if script:GetAttribute("TrooMovesRefundEnabled") == false then return end
			local refund = refunds(char, drop, t)
			if refund > 0 then
				local v = math.min(hum.MaxHealth, hum.Health + refund)
				st.own, st.last = v, v
				hum.Health = v
			end
		end)
		for _, k in ipairs({"TrooPartLastFeatherEnabled", "TrooLastFeatherUsed", "Species"}) do
			char:GetAttributeChangedSignal(k):Connect(function() syncDead(char, st) end)
		end
		syncDead(char, st)
	end
	local function onPl(pl)
		pl.CharacterAdded:Connect(function(c) task.spawn(watchChar, c) end)
		if pl.Character then task.spawn(watchChar, pl.Character) end
	end
	botJoin(Players.PlayerAdded):Connect(onPl)
	for _, pl in ipairs(Players:GetPlayers()) do onPl(pl) end
	-- Studio: bots (the test ally) on DummyHealth
	if RunService:IsStudio() then
		local botLast = setmetatable({}, {__mode = "k"})
		local function watchBot(b)
			if not b:IsA("Model") then return end
			botLast[b] = {last = b:GetAttribute("DummyHealth")}
			b:GetAttributeChangedSignal("DummyHealth"):Connect(function()
				local e = botLast[b]
				local h = b:GetAttribute("DummyHealth")
				if typeof(h) ~= "number" then return end
				if e.own and math.abs(h - e.own) < 1e-3 then e.own = nil e.last = h return end
				local drop = (typeof(e.last) == "number" and e.last or h) - h
				e.last = h
				if drop <= 0 or h <= 0 or script:GetAttribute("TrooMovesRefundEnabled") == false then return end
				local refund = refunds(b, drop, now())
				if refund > 0 then
					local v = math.min(num(b, "DummyMaxHealth", h + refund), h + refund)
					e.own, e.last = v, v
					b:SetAttribute("DummyHealth", v)
				end
			end)
		end
		task.spawn(function()
			local isl = workspace:WaitForChild("DinoIsland", 30)
			local f = isl and isl:WaitForChild("Bots", 30)
			if not f then return end
			f.ChildAdded:Connect(watchBot)
			for _, b in ipairs(f:GetChildren()) do watchBot(b) end
		end)
	end
	-- the plume fade
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then return end
		acc = 0
		local t = now()
		for _, pl in ipairs(Players:GetPlayers()) do
			local c = pl.Character
			if c and num(c, "TrooPlume", 0) > 0 and num(c, "TrooPlumeUntil", 0) <= t then c:SetAttribute("TrooPlume", 0) end
		end
		for _, b in ipairs(bots()) do
			if num(b, "TrooPlume", 0) > 0 and num(b, "TrooPlumeUntil", 0) <= t then b:SetAttribute("TrooPlume", 0) end
		end
	end)
end

-- v1.12: the bot entrance (see the header)
if script:GetAttribute("TrooMovesServerBotMechaEnabled") == nil then script:SetAttribute("TrooMovesServerBotMechaEnabled", true) end
do
	local proxyModule = game:GetService("ServerStorage"):WaitForChild("DinoArcade"):FindFirstChild("BotProxy")
	local BotProxy = proxyModule and require(proxyModule)
	local fn = script:FindFirstChild("BotMechaUse") or Instance.new("BindableFunction")
	fn.Name = "BotMechaUse"
	local joined = setmetatable({}, {__mode = "k"})
	fn.OnInvoke = function(model, remoteName, ...)
		if script:GetAttribute("TrooMovesServerBotMechaEnabled") == false then return "off" end
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
				script:SetAttribute("TrooMovesServerBotMechaError", tostring(remoteName) .. ": " .. tostring(err))
				return "botUnsupported"
			end
		end
		return "ok"
	end
	fn.Parent = script
end
script:SetAttribute("TrooMovesServerVersion", "1.12") -- v1.12 bot entrance
