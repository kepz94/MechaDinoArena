-- TheriMovesServer v1.14 (Mecha Dino Arena) — the moves of the Therizinosaurus' mecha button parts, build 1: Reaper's Hook,
-- Feather Barrage, Harvest Field, Snare Wires. Plan docs/plans/THERIZINO_PARTS_v1.0.md Task 4 (MDA-244, deterministic map),
-- mockup docs/mockups/therizino_parts_options.html v0.1 (Kepu 2026-11-04 picks; red-team "Across", "Reuse the Tether chain").
-- Settings come from the character (SkillEffects 1.42, a therizino with the part bought AND slotted): TheriHook* (Enabled,
--   Range, Cone, Stun, Cut, Cooldown), TheriFeather* (Enabled, Count, Range, Fan, Damage, SlowMul, SlowTime, Cooldown),
--   TheriField* (Enabled, Radius, Time, Bleed, SlowMul, Cooldown), TheriSnare* (Enabled, Max, Damage, Root, Radius,
--   Cooldown). Distances are world studs except the ones marked "x scale".
-- Remotes (client -> server, MechaButtons): DinoTheriHookRequest(stamp, aimDir), DinoTheriFeatherRequest(stamp, aimDir),
--   DinoTheriFieldRequest(stamp), DinoTheriSnareRequest(stamp). Checks in order (first wins) -> <Prefix>ServerResult (+
--   <Prefix>ServerResultAt): "badArg", "dead", "disabled" (switch or <Prefix>Enabled ~= true), "menu", "stunned", "pinned",
--   "dazed", "cooldown" (<Prefix>ReadyAt). ok -> <Prefix>ReadyAt = now + <Prefix>Cooldown (the hook: only when it fired).
-- Who can be hit: player characters and Workspace.DinoIsland.Bots (Hitboxes, Bitable, Species / IsBot, alive, not KO), never
--   the user, never a squadmate (SquadRules.sameChar), players only where ModeRules.canAffect allows (the Arena). Damage
--   comes off DummyHealth (ArenaPvP bridges players) x the debuff / daze multipliers; none while EnergyShieldUntil is in the
--   future; a killing blow stamps KilledBy / KilledByUserId / KilledWith ("therihook" / "therifeather" / "therifield" /
--   "therisnare") / KilledAt (last).
-- Slows (feather, field): a player gets TenoSlowUntil / TenoSlowMul (SprintTest reads them; the stronger / longer kept, as
--   TenoMovesServer 1.0); a bot's Humanoid WalkSpeed x mul from this script while it lasts (it waits while TenoAttackServer
--   (TenoSlowed) or TenoMovesServer (TenoMoveSlowed) is slowing the same bot; TheriMoveSlowed while this script does).
-- Reaper's Hook: heading = the flat aimDir (else the root's look). Target = the nearest allowed dino whose root is within
--   TheriHookCone (20) degrees of that heading and TheriHookRange studs (flat) of the root. The world between the jib tip
--   (ZPart_zhook "jib", else the root) and the target root blocks ("blocked"). None -> "noTarget"; both: no recharge,
--   TheriHookResult stamped. A shielded target -> "shielded" (recharge, no pull). A hit: the target is pulled over
--   pullTime = clamp(distance / HOOK_SPEED (140), 0.25, 0.8) s to HOOK_GAP (5) x scale studs in front of the root: a player
--   through HookPull 1.0 (HookPullBy = this therizino, HookPullGap, HookPullTime, HookPullAt last), a bot slid by this
--   script (root anchored, moved each step, then released); both get HookHeldUntil. Star (TheriHookCut): at the pull's
--   end the target is stunned TheriHookStun s (StunnedUntil, the later one kept) and TheriAttackServer 1.4's TheriStartCut
--   runs cut 1. Stamps (therizino): TheriHookAimEnd, TheriHookTarget (or ""), TheriHookResult ("hit" / "noTarget" /
--   "blocked" / "shielded"), TheriHookPullTime, TheriHookCutResult, TheriHookAt (last).
-- Feather Barrage: heading as the hook; TheriFeatherCount blades spread evenly over TheriFeatherFan degrees, each a line
--   TheriFeatherRange studs from the root. A blade hits a dino when a point on its line is within BLADE_WIDTH (1.5) studs of
--   its hitboxes; every blade that hits deals TheriFeatherDamage, and a hit dino is slowed x TheriFeatherSlowMul for
--   TheriFeatherSlowTime s. Stamps: TheriFeatherDir, TheriFeatherHits ("name=n|..."), TheriFeatherAt (last).
-- Harvest Field: a circle of radius TheriFieldRadius studs (Kepu "Across": 12 / 16 / 20 wide) on the ground under the root
--   for TheriFieldTime s; every FIELD_TICK (0.5) s each allowed dino with a hitbox within the radius (flat, at its own
--   height) takes TheriFieldBleed x 0.5 and is slowed x TheriFieldSlowMul until 0.6 s later. One field per therizino (a new
--   one replaces it). Stamps: TheriFieldCenter, TheriFieldRadiusNow, TheriFieldUntil, TheriFieldAt (last).
-- Snare Wires: a trap (Model "TheriSnare_<name>" in Workspace.DinoFX.TheriMovesFX: two steel posts and a red wire, no
--   collision) on the ground SNARE_AHEAD (8) x scale studs ahead of the root; at most TheriSnareMax alive (the oldest goes),
--   each for SNARE_LIFE (60) s. The first allowed dino (not shielded) whose root comes within TheriSnareRadius x scale studs
--   (flat) of it: TheriSnareDamage, and it is held (Kepu "Reuse the Tether chain": TetherServer's rope) by a RopeConstraint
--   from an anchored stake at the trap to its root, Length = the distance then + 0.5, for TheriSnareRoot s; stamps on it
--   TheriSnaredUntil, TheriSnaredBy; the trap is gone. Stamps (therizino): TheriSnareCount (alive), TheriSnareAt (last lay),
--   TheriSnareHitAt / TheriSnareHitTarget.
-- Switches (script attributes): TheriMovesServerEnabled, TheriMoves_<id>Enabled (zhook / zfeather / zharvest / zsnare),
--   TheriMovesModeRulesEnabled, TheriMovesSquadEnabled (default true each, read at each use).
-- Diagnostics: script TheriMovesServerVersion, TheriMovesHits, TheriMovesSlows, TheriMovesSquadSkips, TheriMovesMode,
--   TheriMovesTraps (alive, all owners).
-- v1.1 (MDA-246 Studio check: a raptor bot 22 studs straight ahead took no blade): the blade test measured from the root's
--   height, and a smaller dino's hitboxes sit lower than the therizino's root, so a blade passed over it. A blade's point is
--   now taken at the target root's height (flat fan, as the mockup draws it). Switch: script attribute
--   TheriMovesFlatBladesEnabled (default true, read at each fire; false = 1.0).
-- v1.2 (therizino parts build 2, MDA-247, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7; SkillTree 1.62): three more remotes,
--   same checks (prefixes TheriGrapple / TheriDeflect / TheriClock):
--   * Grapple Zip: DinoTheriGrappleRequest(stamp, aimDir). A ray from the root (+ 2 x scale up) along aimDir (the camera look,
--     3D) up to TheriGrappleRange studs against the world only (characters, bots, tall grass, FX ignored). A hit at least
--     GRAPPLE_MIN (6) studs away -> TheriGrappleTo = hit point + normal x 3 x scale, TheriGrappleTime = clamp(distance /
--     ZIP_SPEED (120), 0.2, 0.9) s, TheriGrappleResult "zip", TheriGrappleAt (last): the owner's client (TheriGrappleZip 1.0)
--     flies the body there. Nothing hit / too close -> "noAnchor" (no charge used). Charges: TheriGrappleCharges (1; 2 at the
--     star); each zip uses one, which comes back TheriGrappleCooldown s later; TheriGrappleReadyAt = now while a charge is
--     left, else the next refill (MechaButtons reads it); TheriGrappleLeft (charges left).
--   * Deflector Claws: DinoTheriDeflectRequest(stamp) -> TheriDeflectUntil = now + TheriDeflectTime, TheriDeflectAt (last).
--     DeflectRules 1.0 (ServerStorage.DinoArcade) does the blocking inside DiloAttackServer 1.3, TenoMovesServer 1.8 and
--     ScreechServer 1.12.
--   * Overclock Joints: DinoTheriClockRequest(stamp) -> TheriClockUntil = now + TheriClockTime, TheriClockAt (last); SprintTest
--     1.20 runs faster (and drops slows at the star), TheriAttackServer 1.5 / TheriAttackTest 1.3 shorten the tap gap.
--   Switches: TheriMoves_zgrappleEnabled, TheriMoves_zdeflectEnabled, TheriMoves_zclockEnabled (default true, read at each use).
-- v1.3 (Kepu 2026-11-04 15:21: the grapple "Barely even pulls you a significant distance for the slot. Also it's not obvious
--   where it's shooting to latch on to"; "overclocked legs should always be on but passive and take up a slot", "Same numbers,
--   always on"; mockup docs/mockups/therizino_grapple_overclock_v0.1.html picks Grapple-A, Overclock-A; plan
--   docs/plans/THERIZINO_GRAPPLE_CLOCK_v1.0.md, MDA-255 / MDA-257; SkillTree 1.63 ranges 90 / 110 / 130):
--   * Grapple v2 (script attribute TheriMovesGrappleV2Enabled, default true, read at each use; false = 1.2): zip time =
--     clamp(distance / ZIP_SPEED_V2 (150), 0.2, ZIP_MAX_V2 (1.0)) s; nothing hit inside the range -> it latches in the air:
--     TheriGrappleTo = TheriGrappleAnchor = the ray's end (origin + aim x range), TheriGrappleAir = true (false on a surface).
--     A hit closer than GRAPPLE_MIN is still "noAnchor". Characters get TheriGrappleAirLatch (= the switch) for the client
--     marker (TheriGrappleZip 1.1).
--   * Passive Overclock (script attribute TheriMovesClockPassiveEnabled, default true; false = 1.2 button): every
--     CLOCK_TICK (0.25) s, for each player's character: TheriClockEnabled true (bought + slotted, SkillEffects) -> TheriClockPassive
--     true, TheriClockUntil = now + 1e6 and TheriClockAt = now when it turns on (SprintTest / TheriAttackServer / TheriAttackTest
--     read TheriClockUntil as before); otherwise, if it was passive -> TheriClockPassive false, TheriClockUntil = now. A clock
--     request while passive -> TheriClockServerResult "passive", nothing changes.
-- v1.4 (therizino moves rework, Kepu 2026-11-04 picks "Harvest-C, Snare-B, Dash-C, Hook-B", "Storm Core + 30 studs";
--   storyboard tools/mockup/therizino_moves_anim.js v0.3 = the timings; plan docs/plans/THERIZINO_MOVES_REWORK_v1.0.md
--   "Deterministic map", MDA-263; SkillTree 1.65, SkillEffects 1.43). Same remotes and part ids; each rework has its own script
--   switch (default true, read at each request; false = the 1.3 move, whose handler returns early while its rework is on):
--   * TheriMovesVortexEnabled — Reaper Vortex (DinoTheriFieldRequest): centre VORTEX_AHEAD (5) x scale studs ahead of the root
--     on the ground, radius TheriFieldRadius; active from t + VORTEX_START (0.95) to + TheriFieldTime. While active: every
--     Heartbeat each allowed, unshielded dino with a hitbox inside is moved VORTEX_PULL (6) studs/s (flat) toward the centre,
--     stopping 3 x its scale from it (bot: root CFrame here; player: its own client, TheriVortexPull 1.0, from the stamps
--     TheriVortexBy / TheriVortexCenter / TheriVortexPull / TheriVortexUntil, Until = now when it leaves or it ends); every
--     FIELD_TICK s bleed x 0.5 ("therifield") and slowed x TheriFieldSlowMul until 0.6 s later. One per therizino. Stamps:
--     TheriVortexCenter, TheriVortexRadius, TheriVortexStart, TheriFieldUntil, TheriVortexAt (last).
--   * TheriMovesBolaEnabled — Bola (DinoTheriSnareRequest(stamp, aimDir?)): heading as the hook; target = the nearest allowed dino
--     within TheriSnareRange studs (flat) and BOLA_CONE (25) degrees. Charges TheriSnareMax, each back TheriSnareCooldown s
--     after use (TheriSnareLeft, TheriSnareReadyAt = now while one is left). None -> TheriBolaResult "noTarget" (thrown to
--     TheriBolaEnd at full reach, no charge used). Else a charge; flight = clamp(distance / BOLA_SPEED (80), 0.25, 0.6); at
--     t + BOLA_WIND (0.6) + flight: target gone / not allowed / further than reach + 15 -> "missed"; shielded -> "shielded";
--     else TheriSnareDamage ("therisnare"), held TheriSnareRoot s (1.3's rope from a stake at its root + slowed x 0.1),
--     TheriSnaredUntil / TheriSnaredBy on it, "hit", TheriBolaHitAt + TheriSnareHitTarget / TheriSnareHitAt. Stamps:
--     TheriBolaTarget, TheriBolaEnd, TheriBolaFlight, TheriBolaResult, TheriBolaAt (last, at the throw).
--   * TheriMovesDashEnabled — Dash (DinoTheriGrappleRequest(stamp, moveDir)): characters get TheriDashMode = the switch (read by
--     MechaButtons 1.33). Direction = flat moveDir (else the root's look). Charges / refills = 1.3's grapple ones. A world ray at
--     root height along it for TheriGrappleRange studs; a hit -> stop 3 x scale short. Shorter than DASH_MIN (4) -> "blocked"
--     (no charge). The end keeps the start's height above the ground. Stamps: TheriDashFrom, TheriDashTo, TheriDashDelay
--     (DASH_DELAY 0.16), TheriDashTime (clamp(distance / DASH_SPEED (330), 0.08, 0.16)), TheriDashResult "dash" / "blocked",
--     TheriDashAt (last); TheriGrappleZip 1.3 moves the owner.
--   * TheriMovesReelEnabled — Reaper Reel (DinoTheriHookRequest): target as the hook (TheriHookCone 35, TheriHookRange); from the
--     chest muzzle (role "muzzle", else "jib", else the root) the world blocks. None / blocked -> TheriReelResult "noTarget" /
--     "blocked", no recharge. Else recharge; fly = clamp(d / REEL_CLAW_SPEED (220), 0.12, 0.35), reel = clamp((d - gap) /
--     REEL_SPEED (90), 0.3, 0.8), gap = REEL_GAP (7) x scale. Shielded -> "shielded" (nothing more). "hit": the target is held
--     for REEL_BRACE (0.3) + fly + reel + REEL_SETTLE (0.3) (bot: root held in place; player: slowed x 0.1; HookHeldUntil); then
--     (REEL_SETTLE after the reel's end, so the owner's reel has replicated), if it is within
--     gap + REEL_REACH (12) studs (flat) of the root: REEL_SLASH (10) damage ("therihook"), TheriReelHitAt, star -> stunned
--     TheriHookStun s + TheriStartCut (as 1.3); else TheriReelResult "missed". Stamps: TheriReelTarget, TheriReelEnd,
--     TheriReelBrace, TheriReelFly, TheriReelTime, TheriReelGap, TheriReelResult, TheriReelAt (last).
--   Diagnostics: script TheriMovesVortexes (alive), TheriMovesBolaHits, TheriMovesReelHits, TheriMovesDashes.
-- v1.5 (Kepu 2026-11-04 17:54 "Make it overclock tier 3 to give you an extra jump"; SkillTree 1.66, SkillEffects 1.44): every
--   CLOCK_TICK (0.25) s, for each player's character: Overclock passive (TheriClockPassive true) and TheriClockJump >= 1 ->
--   JumpCharges = TheriClockJumpBase + TheriClockJump, where TheriClockJumpBase is the character's own JumpCharges when the
--   extra is first added (taken again if something else rewrites JumpCharges while it is added); TheriClockJumpAdded true.
--   Otherwise, if it was added -> JumpCharges = TheriClockJumpBase, TheriClockJumpAdded false. JumpServer 1.3 / JumpTest 1.4 /
--   AbilityBar / ArenaTouch read JumpCharges as before (pips up to 3). Switch: script attribute TheriMovesClockJumpEnabled
--   (default true, read each tick; false = the extra is taken back).
-- v1.6 (Kepu 2026-11-04 18:03 "The feather animation can barely even be fucking seen", pick 19:08 "A", "Build" 2026-11-05
--   13:38; plan docs/plans/THERIZINO_FEATHER_VOLLEY_v1.0.md, MDA-265; storyboard tools/mockup/therizino_moves_anim.js v0.4 A):
--   Feather Barrage -> Wing Volley. Switch: script attribute TheriMovesFeatherVolleyEnabled (default true). Off -> the 1.5
--   handler, which now also stamps TheriFeatherVolley false. On -> the 1.5 handler returns at its top and the volley runs: the
--   same check() / ok() (recharge at the press), dir = heading(aimDir), origin = the root at the press; stamps
--   TheriFeatherVolley true, TheriFeatherDir, TheriFeatherOrigin, TheriVolleyRelease (VOLLEY_RELEASE 0.42), TheriVolleyFlight
--   (VOLLEY_FLIGHT 0.6), TheriVolleyResult "windup", TheriVolleyDarts "", TheriFeatherHits "", TheriFeatherAt (last). After
--   the release, t1: the therizino gone / dead / StunnedUntil > t1 -> TheriVolleyResult "cancelled", TheriVolleyFiredAt t1;
--   else the 1.5 blade test from origin + dir against candidates() at t1; each dart i that touches a dino is given the one
--   nearest along its line -> TheriFeatherHits ("name=blades|..."), TheriVolleyDarts ("i=name|..."), TheriVolleyResult
--   "fired", TheriVolleyFiredAt t1 (last). After the flight, t2: each judged dino still a target (stillTarget) takes damage x
--   its blades ("therifeather"; none while shielded) and the slow -> TheriVolleyLanded ("name=blades|..."),
--   TheriVolleyLandedAt t2 (last). Diagnostics: script TheriMovesVolleys, TheriMovesVolleyHits.
-- v1.7 (Deflector Shield Wall, Kepu 2026-11-05 15:52 picks, "Build" 15:55; plan docs/plans/THERIZINO_DEFLECT_CLOCK_v2.0.md,
--   MDA-269): each Deflector press stamps the character's TheriDeflectWall (= script switch TheriMovesDeflectWallEnabled,
--   default true) before TheriDeflectAt, so every client draws the same look (TheriPose 1.11, TheriPartsAnim 1.4, TheriMovesFX2
--   1.2). Nothing else of the move changes (DeflectRules 1.0 still judges every block).
-- v1.12 (Bots v2, MDA-468, plan docs/plans/BOTS_V2_v1.0.md T3; found in Studio 2026-11-11: practice bots frozen at WalkSpeed
--   0.0055 / 0 because several scripts' bot-slow loops each took the other's slowed speed as their base every frame):
--   a practice bot (PracticeBot = true) in the bot-slow loop gets model attributes SlowMul_TheriMoves / SlowUntil_TheriMoves (this slow's
--   multiplier and end, server time) instead of a WalkSpeed write, any speed this loop had set is given back, and it leaves the
--   loop; PracticeBrain 2.0 owns the bot's WalkSpeed (base x the active SlowMul_*). Other bots and players: as before.
--   Switch: script attribute TheriMovesServerBotSlowAttrEnabled (default true, read per frame; false = the previous version).
-- v1.13 (Bots v2, MDA-471, plan docs/plans/BOTS_V2_v1.0.md T7; Kepu 2026-11-11 20:39 "the damn bots don't even use their
--   attack buttons or their mecha"): a bot entrance. Every remote handler of this script is connected through botHook(remote)
--   (handler bodies unchanged), which also files it by the remote's name. Server-only BindableFunction "BotMechaUse" (child):
--   Invoke(model, remoteName, ...the remote's own arguments...) runs every handler filed for that remote, in order, with
--   ServerStorage.DinoArcade.BotProxy.of(model) as the player (the model is its Character; PracticeBot models only).
--   Returns "ok" (the handlers ran; their results land on the model as for a player), "off", "badArg", "noHandler" or
--   "botUnsupported" (a handler errored; script attribute TheriMovesServerBotMechaError keeps "<remote>: <error>").
--   Switch: script attribute TheriMovesServerBotMechaEnabled (default true, read per call).
--   The first call for a bot also runs this script's player-join handlers (Players.PlayerAdded, filed through botJoin) with
--   the proxy and waits 0.2 s, so the bot's character is set up here like a player's (BotProxy 1.1 gives the proxy stub
--   CharacterAdded / CharacterRemoving signals).
local function __prematchLocked(player) -- v1.14: PracticeServer 1.12 pre-match lock (see VERSION 1.14)
	local c = player and player.Character
	return c ~= nil and (tonumber(c:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()
end
local __botHandlers = {} -- v1.13: remote name -> handlers (see the header)
local function botHook(remote)
	return {Connect = function(_, fn)
		local list = __botHandlers[remote.Name] or {}
		__botHandlers[remote.Name] = list
		table.insert(list, fn)
		return remote.OnServerEvent:Connect(function(player, ...) -- v1.14: dropped while pre-match locked
			if __prematchLocked(player) then return end
			return fn(player, ...)
		end)
	end}
end
local __botJoiners = {} -- v1.13: player-join handlers (see the header)
local function botJoin(signal)
	return {Connect = function(_, fn)
		table.insert(__botJoiners, fn)
		return signal:Connect(fn)
	end}
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 flat feather blades
VERSION = "1.2" -- v1.2 build 2: Grapple Zip, Deflector Claws, Overclock Joints
VERSION = "1.3" -- v1.3 grapple v2 (air latch, faster), passive Overclock
VERSION = "1.4" -- v1.4 moves rework: vortex, bola, dash, reel
VERSION = "1.5" -- v1.5 Overclock III: extra jump charge
VERSION = "1.6" -- v1.6 Wing Volley (Feather Barrage rework)
VERSION = "1.7" -- v1.7 Deflector Shield Wall stamp
VERSION = "1.8" -- v1.8 Sap Wall stops feathers / fields / snares / vortex / bola / reel through it
-- v1.8 (MDA-353) Sap Wall: a live Sap Wall on the attacker (or splash centre) -> target line stops the hit (ServerStorage.DinoArcade
--   SapWallBlock.between). Switch: script attribute TheriMovesServerSapWallEnabled (default true, read at each hit). Diagnostics: script
--   TheriMovesServerSapWallBlocks (count), TheriMovesServerSapWallBlockedAt (server time).
VERSION = "1.9" -- v1.9 shot pass: faster shots, strong aim assist
-- v1.9 (Kepu 2026-11-09 "all the projectile shots need to be faster and more auto aim assist on it and longer range"
--   -> 1.5x faster, 2x range, "Strong" assist = snap to a target within 45 degrees of the aim; plan
--   docs/plans/SHOT_PASS_v1.0.md): Snare Wires bola locks on within 45 degrees (was BOLA_CONE 25) and flies
--   BOLA_SPEED x 1.5 (flight clamp 0.25..0.6 -> / 1.5); the Reaper Reel claw flies REEL_CLAW_SPEED x 1.5 (fly clamp
--   0.12..0.35 -> / 1.5) and locks on within at least 45 degrees (TheriHookCone); the Feather Barrage blades fly
--   VOLLEY_FLIGHT / 1.5 (0.6 -> 0.4 s; TheriVolleyFlight). Ranges / cones come from SkillTree 1.74. Switch: script
--   attribute ShotPassEnabled (default true; false = 1.8).
VERSION = "1.10" -- v1.10 no movement moves while snared
-- v1.10 (MDA-356; Kepu 2026-11-08 "pachy headbutt when trapped by zino still works which defeats the purpose of throwing a trap" -> "No movement moves"): Grapple Zip and the Therizino Dash (zgrapple) are refused "snared" while the character's
--   TheriSnaredUntil (Snare Wires bola) or HookHeldUntil (Reaper Hook / Grappling Hook hold) is after now (the PinHeld pattern;
--   bites and attacks that stay in place still work; the Troodon's Feather Shed still breaks out). Switch: script
--   attribute TheriMovesSnareBlockEnabled (default true, read at each request; false = 1.9). Diagnostic: script
--   TheriMovesSnareRefusals (count).
VERSION = "1.11" -- v1.11 armor on every hit (MDA-366)
VERSION = "1.12" -- v1.12 practice bot slows as attributes
-- v1.11 (MDA-366, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 "Every attack"): armor (Thick Hide / Armored Hide /
--   Wiry Frame = the victim's StatDamageTakenMul) now cuts feathers, field bleed ticks, snares and the reel slash (damage):
--   damage x BoneCrest.armor(victim) (ServerStorage.DinoArcade.BoneCrest 1.7, one shared call). Switch: script attribute
--   TheriMovesServerArmorAllEnabled (default true, read at each hit; false = 1.10). Diagnostic: script TheriMovesServerArmorCuts (count of hits cut).
if script:GetAttribute("TheriMovesSnareBlockEnabled") == nil then script:SetAttribute("TheriMovesSnareBlockEnabled", true) end -- v1.10
local function snareBlocked(char) -- v1.10: Snare Wires bola / Reaper Hook hold
	if script:GetAttribute("TheriMovesSnareBlockEnabled") == false then return false end
	local t = workspace:GetServerTimeNow()
	local on = (tonumber(char:GetAttribute("TheriSnaredUntil")) or 0) > t or (tonumber(char:GetAttribute("HookHeldUntil")) or 0) > t
	if on then script:SetAttribute("TheriMovesSnareRefusals", (script:GetAttribute("TheriMovesSnareRefusals") or 0) + 1) end
	return on
end
local SNARE_MOVES = {zgrapple = true} -- v1.10: the movement parts
local SHOT_SPEED_MUL, SHOT_ASSIST_DEG = 1.5, 45 -- v1.9
local function shotPass() return script:GetAttribute("ShotPassEnabled") ~= false end -- v1.9
if script:GetAttribute("ShotPassEnabled") == nil then script:SetAttribute("ShotPassEnabled", true) end -- v1.9
local sapBlocked do
	local mod
	sapBlocked = function(from, to)
		if script:GetAttribute("TheriMovesServerSapWallEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.between and mod.between(from, to)) then return false end
		script:SetAttribute("TheriMovesServerSapWallBlocks", (script:GetAttribute("TheriMovesServerSapWallBlocks") or 0) + 1)
		script:SetAttribute("TheriMovesServerSapWallBlockedAt", workspace:GetServerTimeNow())
		return true
	end
	if script:GetAttribute("TheriMovesServerSapWallEnabled") == nil then script:SetAttribute("TheriMovesServerSapWallEnabled", true) end
end
local HOOK_SPEED, HOOK_GAP = 140, 5
local BLADE_WIDTH = 1.5
local FIELD_TICK = 0.5
local SNARE_AHEAD, SNARE_LIFE = 8, 60

script:SetAttribute("TheriMovesServerVersion", VERSION)
for _, k in ipairs({"TheriMovesHits", "TheriMovesSlows", "TheriMovesSquadSkips", "TheriMovesTraps"}) do script:SetAttribute(k, 0) end
for _, k in ipairs({"TheriMovesServerEnabled", "TheriMoves_zhookEnabled", "TheriMoves_zfeatherEnabled", "TheriMoves_zharvestEnabled",
	"TheriMoves_zsnareEnabled", "TheriMovesModeRulesEnabled", "TheriMovesSquadEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
if script:GetAttribute("TheriMovesFlatBladesEnabled") == nil then script:SetAttribute("TheriMovesFlatBladesEnabled", true) end -- v1.1
local function on(id)
	return script:GetAttribute("TheriMovesServerEnabled") ~= false and script:GetAttribute("TheriMoves_" .. id .. "Enabled") ~= false
end
for _, k in ipairs({"Vortex", "Bola", "Dash", "Reel"}) do -- v1.4
	if script:GetAttribute("TheriMoves" .. k .. "Enabled") == nil then script:SetAttribute("TheriMoves" .. k .. "Enabled", true) end
end
local function rework(k) return script:GetAttribute("TheriMoves" .. k .. "Enabled") ~= false end -- v1.4
local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

-- mode + squad rules (TenoMovesServer 1.0) ------------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TheriMovesMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TheriMovesSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("TheriMovesSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("TheriMovesModeRulesEnabled") == false then return true end
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
local hookRemote, featherRemote = remote("DinoTheriHookRequest"), remote("DinoTheriFeatherRequest")
local fieldRemote, snareRemote = remote("DinoTheriFieldRequest"), remote("DinoTheriSnareRequest")

-- targets (TenoMovesServer 1.0 rules) -----------------------------------------------------------------------------------------
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
local armorMul do -- v1.11 (MDA-366): armor on every attack, ServerStorage.DinoArcade.BoneCrest 1.7 armor()
	local mod
	armorMul = function(victim)
		if script:GetAttribute("TheriMovesServerArmorAllEnabled") == false then return 1 end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end) end
		local a = mod and mod.armor and mod.armor(victim) or 1
		if a ~= 1 then script:SetAttribute("TheriMovesServerArmorCuts", (script:GetAttribute("TheriMovesServerArmorCuts") or 0) + 1) end
		return a
	end
	if script:GetAttribute("TheriMovesServerArmorAllEnabled") == nil then script:SetAttribute("TheriMovesServerArmorAllEnabled", true) end
end
local function damage(char, player, m, base, with, t)
	if shielded(m, t) then return 0 end
	local d = math.max(0, base) * takenMul(m, t) * armorMul(m) -- v1.11 (MDA-366): armor
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
	count("TheriMovesHits")
	return d
end
local function stun(m, untilT)
	m:SetAttribute("StunnedUntil", math.max(num(m, "StunnedUntil", 0), untilT))
end

-- world / fx -------------------------------------------------------------------------------------------------------------------
local fxFolder
local function fx()
	local root = workspace:FindFirstChild("DinoFX")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX"
		root.Parent = workspace
	end
	if not (fxFolder and fxFolder.Parent) then
		fxFolder = root:FindFirstChild("TheriMovesFX") or Instance.new("Folder")
		fxFolder.Name = "TheriMovesFX"
		fxFolder.Parent = root
	end
	return fxFolder
end
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
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX"}) do
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

-- slows (TenoMovesServer 1.0's rule) -----------------------------------------------------------------------------------------------
local botSlow = {} -- [model] = {hum, untilT, mul, base, set}
local function slow(m, mul, untilT, t)
	if not (mul and mul < 1 and untilT and untilT > t) or shielded(m, t) then return end
	count("TheriMovesSlows")
	if Players:GetPlayerFromCharacter(m) then
		local cu, cm = num(m, "TenoSlowUntil", 0), num(m, "TenoSlowMul", 1)
		if cu <= t then cm = 1 end
		m:SetAttribute("TenoSlowMul", math.min(cm, mul))
		m:SetAttribute("TenoSlowUntil", math.max(cu, untilT))
		return
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local e = botSlow[m]
	if e then
		e.untilT, e.mul = math.max(e.untilT, untilT), math.min(e.mul, mul)
	else
		botSlow[m] = {hum = hum, untilT = untilT, mul = mul}
	end
end
RunService.Stepped:Connect(function()
	local t = now()
	for m, e in pairs(botSlow) do
		local hum = e.hum
		if not m.Parent or not hum.Parent then
			botSlow[m] = nil
		elseif m:GetAttribute("PracticeBot") == true and script:GetAttribute("TheriMovesServerBotSlowAttrEnabled") ~= false then -- v1.12: practice bots
			m:SetAttribute("SlowMul_TheriMoves", e.mul)
			m:SetAttribute("SlowUntil_TheriMoves", e.untilT)
			if e.set ~= nil and e.base and math.abs(hum.WalkSpeed - e.set) <= 1e-3 then hum.WalkSpeed = e.base end
			botSlow[m] = nil
		elseif m:GetAttribute("TenoSlowed") == true or m:GetAttribute("TenoMoveSlowed") == true then -- another slower: give it back, wait
			if e.set ~= nil and e.base and math.abs(hum.WalkSpeed - e.set) <= 1e-3 then hum.WalkSpeed = e.base end
			e.set = nil
			if t >= e.untilT then
				botSlow[m] = nil
				m:SetAttribute("TheriMoveSlowed", false)
			end
		else
			local cur = hum.WalkSpeed
			if e.set == nil or math.abs(cur - e.set) > 1e-3 then e.base = cur end
			if t < e.untilT then
				e.set = e.base * math.clamp(e.mul, 0.05, 1)
				hum.WalkSpeed = e.set
				if m:GetAttribute("TheriMoveSlowed") ~= true then m:SetAttribute("TheriMoveSlowed", true) end
			else
				hum.WalkSpeed = e.base
				m:SetAttribute("TheriMoveSlowed", false)
				botSlow[m] = nil
			end
		end
	end
end)

-- request checks -------------------------------------------------------------------------------------------------------------------
local function check(player, stamp, id, prefix, aimDir, needAim)
	local char = player.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp or (needAim and aimDir ~= nil and (typeof(aimDir) ~= "Vector3"
		or aimDir.Magnitude < 0.5 or aimDir.Magnitude > 1.5)) then
		r = "badArg"
	elseif not hum or hum.Health <= 0 or not rootOf(char) then
		r = "dead"
	elseif not on(id) or char:GetAttribute(prefix .. "Enabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif num(char, "StunnedUntil", 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif SNARE_MOVES[id] and snareBlocked(char) then -- v1.10
		r = "snared"
	elseif num(char, "DazedUntil", 0) > t then
		r = "dazed"
	end
	if not r and t < num(char, prefix .. "ReadyAt", 0) then r = "cooldown" end
	if r then
		char:SetAttribute(prefix .. "ServerResult", r)
		char:SetAttribute(prefix .. "ServerResultAt", t)
		return nil
	end
	return char, t
end
local function ok(char, prefix, t, setCooldown)
	char:SetAttribute(prefix .. "ServerResult", "ok")
	char:SetAttribute(prefix .. "ServerResultAt", t)
	if setCooldown ~= false then char:SetAttribute(prefix .. "ReadyAt", t + math.max(0.5, num(char, prefix .. "Cooldown", 15))) end
end
local function heading(char, aimDir)
	local d = typeof(aimDir) == "Vector3" and flat(aimDir) or Vector3.zero
	if d.Magnitude < 1e-3 then d = flat(rootOf(char).CFrame.LookVector) end
	return d.Magnitude > 1e-3 and d.Unit or -Vector3.zAxis
end

-- Reaper's Hook -------------------------------------------------------------------------------------------------------------------
local function jibTip(char)
	local m = char:FindFirstChild("ZPart_zhook")
	if m then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("ZPartRole") == "jib" then return p.Position end
		end
	end
	return rootOf(char).Position
end
local function slideBot(m, goalFn, dur)
	local r = rootOf(m)
	if not r then return end
	local wasAnchored = r.Anchored
	r.Anchored = true
	local start = r.Position
	local t0 = os.clock()
	while os.clock() - t0 < dur and m.Parent and r.Parent do
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local goal = goalFn()
		local p = start:Lerp(goal, k)
		r.CFrame = CFrame.new(p) * r.CFrame.Rotation
		RunService.Heartbeat:Wait()
	end
	if m.Parent and r.Parent then
		r.CFrame = CFrame.new(goalFn()) * r.CFrame.Rotation
		r.Anchored = wasAnchored
	end
end
local startCut
local function cutFn()
	if startCut and startCut.Parent then return startCut end
	local s = game:GetService("ServerScriptService"):FindFirstChild("TheriAttackServer")
	startCut = s and s:FindFirstChild("TheriStartCut")
	return startCut
end
botHook(hookRemote):Connect(function(player, stamp, aimDir)
	if rework("Reel") then return end -- v1.4: the Reaper Reel below
	local char, t = check(player, stamp, "zhook", "TheriHook", aimDir, true)
	if not char then return end
	local root = rootOf(char)
	local dir = heading(char, aimDir)
	local range = math.max(0, num(char, "TheriHookRange", 50))
	local half = math.rad(math.clamp(num(char, "TheriHookCone", 20), 0, 90))
	local best, bestD = nil, math.huge
	for _, m in ipairs(candidates(char)) do
		local v = flat(rootOf(m).Position - root.Position)
		local d = v.Magnitude
		if d > 1e-3 and d <= range and math.acos(math.clamp(dir:Dot(v.Unit), -1, 1)) <= half and d < bestD then best, bestD = m, d end
	end
	local from = jibTip(char)
	local result, aimEnd = "noTarget", root.Position + dir * range
	if best then
		local to = rootOf(best).Position
		aimEnd = to
		local hit = workspace:Raycast(from, to - from, worldOnly())
		if hit then
			result, aimEnd = "blocked", hit.Position
		elseif shielded(best, t) then
			result = "shielded"
		else
			result = "hit"
		end
	end
	char:SetAttribute("TheriHookAimEnd", aimEnd)
	char:SetAttribute("TheriHookTarget", (result == "hit" or result == "shielded") and best.Name or "")
	char:SetAttribute("TheriHookResult", result)
	if result == "noTarget" or result == "blocked" then
		char:SetAttribute("TheriHookPullTime", 0)
		char:SetAttribute("TheriHookAt", t) -- last
		char:SetAttribute("TheriHookServerResult", result)
		char:SetAttribute("TheriHookServerResultAt", t)
		return
	end
	ok(char, "TheriHook", t)
	local s = char:GetScale()
	local pullTime = result == "hit" and math.clamp(bestD / HOOK_SPEED, 0.25, 0.8) or 0
	char:SetAttribute("TheriHookPullTime", pullTime)
	char:SetAttribute("TheriHookAt", t) -- last: FX
	if result ~= "hit" then return end
	local gapStuds = HOOK_GAP * s
	best:SetAttribute("HookHeldUntil", t + pullTime)
	if Players:GetPlayerFromCharacter(best) then
		best:SetAttribute("HookPullBy", char.Name)
		best:SetAttribute("HookPullGap", gapStuds)
		best:SetAttribute("HookPullTime", pullTime)
		best:SetAttribute("HookPullAt", t) -- last: HookPull 1.0
		task.wait(pullTime)
	else
		slideBot(best, function()
			local r = rootOf(char)
			local f = r and flat(r.CFrame.LookVector) or dir
			f = f.Magnitude > 1e-3 and f.Unit or dir
			local p = (r and r.Position or root.Position) + f * gapStuds
			local br = rootOf(best)
			return Vector3.new(p.X, br and br.Position.Y or p.Y, p.Z)
		end, pullTime)
	end
	if char:GetAttribute("TheriHookCut") == true and best.Parent and char.Parent then
		stun(best, now() + math.max(0, num(char, "TheriHookStun", 1)))
		local fn = cutFn()
		local r = "noCut"
		if fn then
			local okCall, res = pcall(function() return fn:Invoke(player) end)
			r = okCall and tostring(res) or "error"
		end
		char:SetAttribute("TheriHookCutResult", r)
	end
end)

-- Feather Barrage -----------------------------------------------------------------------------------------------------------------
botHook(featherRemote):Connect(function(player, stamp, aimDir)
	if script:GetAttribute("TheriMovesFeatherVolleyEnabled") ~= false then return end -- v1.6: the Wing Volley below
	local char, t = check(player, stamp, "zfeather", "TheriFeather", aimDir, true)
	if not char then return end
	ok(char, "TheriFeather", t)
	local root = rootOf(char)
	local dir = heading(char, aimDir)
	local n = math.max(1, math.floor(num(char, "TheriFeatherCount", 8)))
	local range = math.max(0, num(char, "TheriFeatherRange", 20))
	local fan = math.rad(math.clamp(num(char, "TheriFeatherFan", 60), 0, 180))
	local dmg = math.max(0, num(char, "TheriFeatherDamage", 3))
	local slowMul, slowT = num(char, "TheriFeatherSlowMul", 1), math.max(0, num(char, "TheriFeatherSlowTime", 0))
	local origin = root.Position
	local dirs = {}
	for i = 1, n do
		local a = n == 1 and 0 or (-fan / 2 + fan * (i - 1) / (n - 1))
		table.insert(dirs, (CFrame.Angles(0, a, 0) * dir).Unit)
	end
	local hits = {}
	for _, m in ipairs(candidates(char)) do
		local mr = rootOf(m)
		local blades = 0
		for _, d in ipairs(dirs) do
			local along = math.clamp(flat(mr.Position - origin):Dot(d), 0, range)
			local pt = origin + d * along
			if script:GetAttribute("TheriMovesFlatBladesEnabled") ~= false then pt = Vector3.new(pt.X, mr.Position.Y, pt.Z) end -- v1.1
			if gap(m, pt) <= BLADE_WIDTH then blades += 1 end
		end
		if blades > 0 and not sapBlocked(origin, m) then -- v1.8: Sap Wall
			for _ = 1, blades do damage(char, player, m, dmg, "therifeather", t) end
			slow(m, slowMul, t + slowT, t)
			table.insert(hits, m.Name .. "=" .. blades)
		end
	end
	char:SetAttribute("TheriFeatherDir", dir)
	char:SetAttribute("TheriFeatherHits", table.concat(hits, "|"))
	char:SetAttribute("TheriFeatherVolley", false) -- v1.6: clients draw the 1.5 look
	char:SetAttribute("TheriFeatherAt", t) -- last: FX
end)

-- Harvest Field ---------------------------------------------------------------------------------------------------------------------
local fields = {} -- [char] = {center, radius, untilT, nextTick, player, bleed, slowMul}
botHook(fieldRemote):Connect(function(player, stamp)
	if rework("Vortex") then return end -- v1.4: the Reaper Vortex below
	local char, t = check(player, stamp, "zharvest", "TheriField", nil, false)
	if not char then return end
	ok(char, "TheriField", t)
	local root = rootOf(char)
	local c = Vector3.new(root.Position.X, groundY(root.Position, root.Position.Y - 6), root.Position.Z)
	local f = {center = c, radius = math.max(0, num(char, "TheriFieldRadius", 6)), untilT = t + math.max(0, num(char, "TheriFieldTime", 3)),
		nextTick = t, player = player, bleed = math.max(0, num(char, "TheriFieldBleed", 4)), slowMul = num(char, "TheriFieldSlowMul", 1)}
	fields[char] = f
	char:SetAttribute("TheriFieldCenter", c)
	char:SetAttribute("TheriFieldRadiusNow", f.radius)
	char:SetAttribute("TheriFieldUntil", f.untilT)
	char:SetAttribute("TheriFieldAt", t) -- last: FX
end)

-- Snare Wires -----------------------------------------------------------------------------------------------------------------------
local traps = {} -- [char] = {{model, pos, bornAt, player}...}
local function trapCount()
	local n = 0
	for _, list in pairs(traps) do n += #list end
	script:SetAttribute("TheriMovesTraps", n)
end
local function buildTrap(char, pos, s)
	local m = Instance.new("Model")
	m.Name = "TheriSnare_" .. char.Name
	local fwd = flat(rootOf(char).CFrame.RightVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.xAxis
	local span = 3 * s
	local function piece(name, size, cf, color, mat)
		local p = Instance.new("Part")
		p.Name = name
		p.Size, p.CFrame = size, cf
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Color, p.Material = color, mat
		p.CastShadow = mat ~= Enum.Material.Neon
		p.Parent = m
		return p
	end
	local steel = Color3.fromRGB(154, 163, 173)
	for _, sd in ipairs({-1, 1}) do
		piece("Post", Vector3.new(0.3, 1.2, 0.3) * s / 2, CFrame.new(pos + fwd * sd * span / 2 + Vector3.new(0, 0.3 * s, 0)), steel, Enum.Material.Metal)
	end
	piece("Wire", Vector3.new(span, 0.08 * s, 0.08 * s), CFrame.lookAt(pos + Vector3.new(0, 0.45 * s, 0), pos + Vector3.new(0, 0.45 * s, 0) + fwd)
		* CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(224, 42, 42), Enum.Material.Neon)
	m:SetAttribute("TheriSnareOwner", char.Name)
	m.Parent = fx()
	return m
end
local function hold(char, m, pos, rootT, t)
	local mr = rootOf(m)
	if not mr then return end
	local stake = Instance.new("Part")
	stake.Name = "TheriSnareStake"
	stake.Size = Vector3.new(0.5, 0.5, 0.5)
	stake.Anchored, stake.CanCollide, stake.CanQuery, stake.CanTouch = true, false, false, false
	stake.Transparency = 1
	stake.CFrame = CFrame.new(pos)
	stake.Parent = fx()
	local a0 = Instance.new("Attachment")
	a0.Parent = stake
	local a1 = Instance.new("Attachment")
	a1.Name = "TheriSnareAttachment"
	a1.Parent = mr
	local rope = Instance.new("RopeConstraint")
	rope.Name = "TheriSnareRope"
	rope.Attachment0, rope.Attachment1 = a0, a1
	rope.Length = (mr.Position - pos).Magnitude + 0.5
	rope.Visible = true
	rope.Color = BrickColor.new("Really red")
	rope.Thickness = 0.15 * char:GetScale()
	rope.Parent = stake
	m:SetAttribute("TheriSnaredUntil", t + rootT)
	m:SetAttribute("TheriSnaredBy", char.Name)
	task.delay(rootT, function()
		stake:Destroy()
		if a1.Parent then a1:Destroy() end
	end)
end
botHook(snareRemote):Connect(function(player, stamp)
	if rework("Bola") then return end -- v1.4: the Bola below
	local char, t = check(player, stamp, "zsnare", "TheriSnare", nil, false)
	if not char then return end
	ok(char, "TheriSnare", t)
	local root = rootOf(char)
	local s = char:GetScale()
	local f = flat(root.CFrame.LookVector)
	f = f.Magnitude > 1e-3 and f.Unit or -Vector3.zAxis
	local p = root.Position + f * SNARE_AHEAD * s
	p = Vector3.new(p.X, groundY(p, root.Position.Y - 6), p.Z)
	local list = traps[char] or {}
	traps[char] = list
	local max = math.max(1, math.floor(num(char, "TheriSnareMax", 1)))
	while #list >= max do
		local old = table.remove(list, 1)
		if old.model then old.model:Destroy() end
	end
	table.insert(list, {model = buildTrap(char, p, s), pos = p, bornAt = t, player = player})
	char:SetAttribute("TheriSnareCount", #list)
	char:SetAttribute("TheriSnareAt", t) -- last
	trapCount()
end)

-- ticks: fields + traps ---------------------------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local t = now()
	for char, f in pairs(fields) do
		if not char.Parent or t >= f.untilT or not on("zharvest") then
			fields[char] = nil
		elseif t >= f.nextTick then
			f.nextTick = t + FIELD_TICK
			for _, m in ipairs(candidates(char)) do
				local mr = rootOf(m)
				if gap(m, Vector3.new(f.center.X, mr.Position.Y, f.center.Z)) <= f.radius and not sapBlocked(f.center + Vector3.yAxis * 2, m) then
					damage(char, f.player, m, f.bleed * FIELD_TICK, "therifield", t)
					slow(m, f.slowMul, t + 0.6, t)
				end
			end
		end
	end
	local changed = false
	for char, list in pairs(traps) do
		local s = char.Parent and char:GetScale() or 1
		local radius = num(char, "TheriSnareRadius", 4) * s
		for i = #list, 1, -1 do
			local tr = list[i]
			local gone = not char.Parent or t - tr.bornAt >= SNARE_LIFE or not on("zsnare")
			if not gone then
				for _, m in ipairs(candidates(char)) do
					local mr = rootOf(m)
					if flat(mr.Position - tr.pos).Magnitude <= radius and not shielded(m, t) and not sapBlocked(tr.pos + Vector3.yAxis * 2, m) then
						damage(char, tr.player, m, num(char, "TheriSnareDamage", 12), "therisnare", t)
						hold(char, m, tr.pos, math.max(0, num(char, "TheriSnareRoot", 1)), t)
						char:SetAttribute("TheriSnareHitTarget", m.Name)
						char:SetAttribute("TheriSnareHitAt", t)
						gone = true
						break
					end
				end
			end
			if gone then
				if tr.model then tr.model:Destroy() end
				table.remove(list, i)
				changed = true
			end
		end
		if char.Parent then
			if char:GetAttribute("TheriSnareCount") ~= #list then char:SetAttribute("TheriSnareCount", #list) end
		elseif #list == 0 then
			traps[char] = nil
		end
	end
	if changed then trapCount() end
end)

-- v1.2: build 2 (see the header) ---------------------------------------------------------------------------------------------------
for _, k in ipairs({"TheriMoves_zgrappleEnabled", "TheriMoves_zdeflectEnabled", "TheriMoves_zclockEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local GRAPPLE_MIN, ZIP_SPEED = 6, 120
local ZIP_SPEED_V2, ZIP_MAX_V2 = 150, 1.0 -- v1.3
if script:GetAttribute("TheriMovesGrappleV2Enabled") == nil then script:SetAttribute("TheriMovesGrappleV2Enabled", true) end -- v1.3
if script:GetAttribute("TheriMovesClockPassiveEnabled") == nil then script:SetAttribute("TheriMovesClockPassiveEnabled", true) end -- v1.3
local grappleRemote, deflectRemote, clockRemote = remote("DinoTheriGrappleRequest"), remote("DinoTheriDeflectRequest"), remote("DinoTheriClockRequest")
local zips = setmetatable({}, {__mode = "k"}) -- [char] = {refills = {times}}
local function grappleLeft(char, t)
	local st = zips[char]
	if not st then
		st = {refills = {}}
		zips[char] = st
	end
	for i = #st.refills, 1, -1 do
		if st.refills[i] <= t then table.remove(st.refills, i) end
	end
	local max = math.max(1, math.floor(num(char, "TheriGrappleCharges", 1)))
	return max - #st.refills, st, max
end
local function grapplePublish(char, t)
	local left, st = grappleLeft(char, t)
	local nextAt = math.huge
	for _, r in ipairs(st.refills) do nextAt = math.min(nextAt, r) end
	char:SetAttribute("TheriGrappleLeft", left)
	char:SetAttribute("TheriGrappleReadyAt", left > 0 and t or nextAt)
	if left <= 0 and nextAt < math.huge then
		task.delay(nextAt - t + 0.02, function() if char.Parent then grapplePublish(char, now()) end end)
	end
end
botHook(grappleRemote):Connect(function(player, stamp, aimDir)
	if rework("Dash") then return end -- v1.4: the Dash below
	local c0 = player.Character
	if c0 then grappleLeft(c0, now()) grapplePublish(c0, now()) end -- refills first, so ReadyAt is current for check()
	local char, t = check(player, stamp, "zgrapple", "TheriGrapple", aimDir, true)
	if not char then return end
	local left, st = grappleLeft(char, t)
	if left <= 0 then
		char:SetAttribute("TheriGrappleServerResult", "cooldown")
		char:SetAttribute("TheriGrappleServerResultAt", t)
		return
	end
	local root = rootOf(char)
	local s = char:GetScale()
	local dir = typeof(aimDir) == "Vector3" and aimDir.Magnitude > 0.5 and aimDir.Unit or root.CFrame.LookVector
	local from = root.Position + Vector3.new(0, 2 * s, 0)
	local range = math.max(0, num(char, "TheriGrappleRange", 40))
	local hit = workspace:Raycast(from, dir * range, worldOnly())
	local v2 = script:GetAttribute("TheriMovesGrappleV2Enabled") ~= false -- v1.3
	if v2 and not hit and range > 0 then -- v1.3: nothing to grab -> latch in the air at full range
		local to = from + dir * range
		table.insert(st.refills, t + math.max(0.5, num(char, "TheriGrappleCooldown", 12)))
		char:SetAttribute("TheriGrappleServerResult", "ok")
		char:SetAttribute("TheriGrappleServerResultAt", t)
		grapplePublish(char, t)
		char:SetAttribute("TheriGrappleAir", true)
		char:SetAttribute("TheriGrappleAnchor", to)
		char:SetAttribute("TheriGrappleTo", to)
		char:SetAttribute("TheriGrappleTime", math.clamp((to - root.Position).Magnitude / ZIP_SPEED_V2, 0.2, ZIP_MAX_V2))
		char:SetAttribute("TheriGrappleResult", "zip")
		char:SetAttribute("TheriGrappleAt", t) -- last: TheriGrappleZip + FX
		return
	end
	if not hit or (hit.Position - from).Magnitude < GRAPPLE_MIN then
		char:SetAttribute("TheriGrappleResult", "noAnchor")
		char:SetAttribute("TheriGrappleServerResult", "noAnchor")
		char:SetAttribute("TheriGrappleServerResultAt", t)
		return
	end
	local to = hit.Position + hit.Normal * 3 * s
	local dist = (to - root.Position).Magnitude
	table.insert(st.refills, t + math.max(0.5, num(char, "TheriGrappleCooldown", 12)))
	char:SetAttribute("TheriGrappleServerResult", "ok")
	char:SetAttribute("TheriGrappleServerResultAt", t)
	grapplePublish(char, t)
	char:SetAttribute("TheriGrappleAnchor", hit.Position)
	char:SetAttribute("TheriGrappleTo", to)
	char:SetAttribute("TheriGrappleAir", false) -- v1.3
	if v2 then -- v1.3: faster, up to 1 s
		char:SetAttribute("TheriGrappleTime", math.clamp(dist / ZIP_SPEED_V2, 0.2, ZIP_MAX_V2))
	else
		char:SetAttribute("TheriGrappleTime", math.clamp(dist / ZIP_SPEED, 0.2, 0.9))
	end
	char:SetAttribute("TheriGrappleResult", "zip")
	char:SetAttribute("TheriGrappleAt", t) -- last: TheriGrappleZip + FX
end)
botHook(deflectRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "zdeflect", "TheriDeflect", nil, false)
	if not char then return end
	ok(char, "TheriDeflect", t)
	char:SetAttribute("TheriDeflectUntil", t + math.max(0, num(char, "TheriDeflectTime", 1)))
	if script:GetAttribute("TheriMovesDeflectWallEnabled") == nil then script:SetAttribute("TheriMovesDeflectWallEnabled", true) end -- v1.7
	char:SetAttribute("TheriDeflectWall", script:GetAttribute("TheriMovesDeflectWallEnabled") ~= false) -- v1.7
	char:SetAttribute("TheriDeflectAt", t) -- last: FX + poses
end)
botHook(clockRemote):Connect(function(player, stamp)
	local c0 = player.Character -- v1.3: passive -> the button does nothing
	if c0 and c0:GetAttribute("TheriClockPassive") == true and script:GetAttribute("TheriMovesClockPassiveEnabled") ~= false then
		c0:SetAttribute("TheriClockServerResult", "passive")
		c0:SetAttribute("TheriClockServerResultAt", now())
		return
	end
	local char, t = check(player, stamp, "zclock", "TheriClock", nil, false)
	if not char then return end
	ok(char, "TheriClock", t)
	char:SetAttribute("TheriClockUntil", t + math.max(0, num(char, "TheriClockTime", 3)))
	char:SetAttribute("TheriClockAt", t) -- last: FX
end)

-- v1.3: passive Overclock + the air-latch flag for the marker (see the header) -----------------------------------------------------
local CLOCK_TICK = 0.25
task.spawn(function()
	while true do
		task.wait(CLOCK_TICK)
		local t = now()
		local passiveOn = script:GetAttribute("TheriMovesClockPassiveEnabled") ~= false and on("zclock")
		local air = script:GetAttribute("TheriMovesGrappleV2Enabled") ~= false
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			if char and char.Parent then
				if char:GetAttribute("TheriGrappleEnabled") ~= nil and char:GetAttribute("TheriGrappleAirLatch") ~= air then
					char:SetAttribute("TheriGrappleAirLatch", air)
				end
				local want = passiveOn and char:GetAttribute("TheriClockEnabled") == true
				if want then
					if char:GetAttribute("TheriClockPassive") ~= true or num(char, "TheriClockUntil", 0) < t + 1e5 then
						char:SetAttribute("TheriClockPassive", true)
						char:SetAttribute("TheriClockUntil", t + 1e6)
						char:SetAttribute("TheriClockAt", t) -- last: FX
					end
				elseif char:GetAttribute("TheriClockPassive") == true then
					char:SetAttribute("TheriClockPassive", false)
					char:SetAttribute("TheriClockUntil", t)
				end
			end
		end
	end
end)

-- v1.4: the moves rework (see the header) ------------------------------------------------------------------------------------------
local VORTEX_AHEAD, VORTEX_START, VORTEX_PULL = 5, 0.95, 6
local BOLA_CONE, BOLA_WIND, BOLA_SPEED = 25, 0.6, 80
local DASH_MIN, DASH_DELAY, DASH_SPEED = 4, 0.16, 330
local REEL_BRACE, REEL_CLAW_SPEED, REEL_SPEED, REEL_GAP, REEL_REACH, REEL_SLASH = 0.3, 220, 90, 7, 12, 10
local REEL_SETTLE = 0.3 -- the owner's reel replicates late: judge the slash this long after the reel ends
for _, k in ipairs({"TheriMovesVortexes", "TheriMovesBolaHits", "TheriMovesReelHits", "TheriMovesDashes"}) do script:SetAttribute(k, 0) end
local function forward(char)
	local f = flat(rootOf(char).CFrame.LookVector)
	return f.Magnitude > 1e-3 and f.Unit or -Vector3.zAxis
end
local function nearestInCone(char, dir, range, coneDeg)
	local root = rootOf(char)
	local half = math.rad(math.clamp(coneDeg, 0, 90))
	local best, bestD = nil, math.huge
	for _, m in ipairs(candidates(char)) do
		local v = flat(rootOf(m).Position - root.Position)
		local d = v.Magnitude
		if d > 1e-3 and d <= range and math.acos(math.clamp(dir:Dot(v.Unit), -1, 1)) <= half and d < bestD then best, bestD = m, d end
	end
	return best, bestD
end
local function stillTarget(char, m)
	return m.Parent ~= nil and isTarget(m, char) and mayAffect(char, m)
end

-- Reaper Vortex --------------------------------------------------------------------------------------------------------------------
local vortexes = {} -- [char] = {center, radius, startT, untilT, nextTick, player, bleed, slowMul, victims = {[model] = true}}
local function vortexCount()
	local n = 0
	for _ in pairs(vortexes) do n += 1 end
	script:SetAttribute("TheriMovesVortexes", n)
end
local function vortexRelease(v, m, t)
	v.victims[m] = nil
	if m.Parent and Players:GetPlayerFromCharacter(m) then m:SetAttribute("TheriVortexUntil", t) end
end
botHook(fieldRemote):Connect(function(player, stamp)
	if not rework("Vortex") then return end
	local char, t = check(player, stamp, "zharvest", "TheriField", nil, false)
	if not char then return end
	ok(char, "TheriField", t)
	local root = rootOf(char)
	local s = char:GetScale()
	local p = root.Position + forward(char) * VORTEX_AHEAD * s
	local c = Vector3.new(p.X, groundY(p, root.Position.Y - 6 * s), p.Z)
	local old = vortexes[char]
	if old then for m in pairs(old.victims) do vortexRelease(old, m, t) end end
	local start = t + VORTEX_START
	local v = {center = c, radius = math.max(0, num(char, "TheriFieldRadius", 15)), startT = start,
		untilT = start + math.max(0, num(char, "TheriFieldTime", 3)), nextTick = start, player = player,
		bleed = math.max(0, num(char, "TheriFieldBleed", 4)), slowMul = num(char, "TheriFieldSlowMul", 1), victims = {}}
	vortexes[char] = v
	vortexCount()
	char:SetAttribute("TheriVortexCenter", c)
	char:SetAttribute("TheriVortexRadius", v.radius)
	char:SetAttribute("TheriVortexStart", start)
	char:SetAttribute("TheriFieldUntil", v.untilT)
	char:SetAttribute("TheriVortexAt", t) -- last: FX + pose
end)
RunService.Heartbeat:Connect(function(dt)
	local t = now()
	local changed = false
	for char, v in pairs(vortexes) do
		if not char.Parent or t >= v.untilT or not on("zharvest") or not rework("Vortex") then
			for m in pairs(v.victims) do vortexRelease(v, m, t) end
			vortexes[char] = nil
			changed = true
		elseif t >= v.startT then
			local tick = t >= v.nextTick
			if tick then v.nextTick = t + FIELD_TICK end
			local inside = {}
			for _, m in ipairs(candidates(char)) do
				local mr = rootOf(m)
				if gap(m, Vector3.new(v.center.X, mr.Position.Y, v.center.Z)) <= v.radius and not shielded(m, t) and not sapBlocked(v.center + Vector3.yAxis * 2, m) then
					inside[m] = true
					if Players:GetPlayerFromCharacter(m) then
						if not v.victims[m] or num(m, "TheriVortexUntil", 0) ~= v.untilT then
							m:SetAttribute("TheriVortexBy", char.Name)
							m:SetAttribute("TheriVortexCenter", v.center)
							m:SetAttribute("TheriVortexPull", VORTEX_PULL)
							m:SetAttribute("TheriVortexUntil", v.untilT) -- last: TheriVortexPull 1.0
						end
					else
						local d = flat(v.center - mr.Position)
						local stop = 3 * m:GetScale()
						if d.Magnitude > stop then
							mr.CFrame += d.Unit * math.min(VORTEX_PULL * dt, d.Magnitude - stop)
						end
					end
					v.victims[m] = true
					if tick then
						damage(char, v.player, m, v.bleed * FIELD_TICK, "therifield", t)
						slow(m, v.slowMul, t + 0.6, t)
					end
				end
			end
			for m in pairs(v.victims) do if not inside[m] then vortexRelease(v, m, t) end end
		end
	end
	if changed then vortexCount() end
end)

-- Bola -----------------------------------------------------------------------------------------------------------------------------
local bolas = setmetatable({}, {__mode = "k"}) -- [char] = {refills = {times}}
local function bolaLeft(char, t)
	local st = bolas[char]
	if not st then
		st = {refills = {}}
		bolas[char] = st
	end
	for i = #st.refills, 1, -1 do
		if st.refills[i] <= t then table.remove(st.refills, i) end
	end
	return math.max(1, math.floor(num(char, "TheriSnareMax", 1))) - #st.refills, st
end
local function bolaPublish(char, t)
	local left, st = bolaLeft(char, t)
	local nextAt = math.huge
	for _, r in ipairs(st.refills) do nextAt = math.min(nextAt, r) end
	char:SetAttribute("TheriSnareLeft", left)
	char:SetAttribute("TheriSnareReadyAt", left > 0 and t or nextAt)
	if left <= 0 and nextAt < math.huge then
		task.delay(nextAt - t + 0.02, function() if char.Parent then bolaPublish(char, now()) end end)
	end
end
botHook(snareRemote):Connect(function(player, stamp, aimDir)
	if not rework("Bola") then return end
	local c0 = player.Character
	if c0 then bolaPublish(c0, now()) end -- refills first, so ReadyAt is current for check()
	local char, t = check(player, stamp, "zsnare", "TheriSnare", aimDir, true)
	if not char then return end
	local left, st = bolaLeft(char, t)
	if left <= 0 then
		char:SetAttribute("TheriSnareServerResult", "cooldown")
		char:SetAttribute("TheriSnareServerResultAt", t)
		return
	end
	local root = rootOf(char)
	local dir = heading(char, aimDir)
	local range = math.max(0, num(char, "TheriSnareRange", 35))
	local sp = shotPass() -- v1.9
	local bolaSpeed, fMin, fMax = sp and BOLA_SPEED * SHOT_SPEED_MUL or BOLA_SPEED, sp and 0.25 / SHOT_SPEED_MUL or 0.25, sp and 0.6 / SHOT_SPEED_MUL or 0.6
	local best, d = nearestInCone(char, dir, range, sp and math.max(BOLA_CONE, SHOT_ASSIST_DEG) or BOLA_CONE) -- v1.9
	if not best then
		local e = root.Position + dir * range
		char:SetAttribute("TheriBolaTarget", "")
		char:SetAttribute("TheriBolaEnd", Vector3.new(e.X, groundY(e, root.Position.Y - 6), e.Z))
		char:SetAttribute("TheriBolaFlight", math.clamp(range / bolaSpeed, fMin, fMax)) -- v1.9
		char:SetAttribute("TheriBolaResult", "noTarget")
		char:SetAttribute("TheriSnareServerResult", "noTarget")
		char:SetAttribute("TheriSnareServerResultAt", t)
		char:SetAttribute("TheriBolaAt", t) -- last: FX (a miss, no charge used)
		return
	end
	table.insert(st.refills, t + math.max(0.5, num(char, "TheriSnareCooldown", 14)))
	bolaPublish(char, t)
	char:SetAttribute("TheriSnareServerResult", "ok")
	char:SetAttribute("TheriSnareServerResultAt", t)
	local flight = math.clamp(d / bolaSpeed, fMin, fMax) -- v1.9
	char:SetAttribute("TheriBolaTarget", best.Name)
	char:SetAttribute("TheriBolaEnd", rootOf(best).Position)
	char:SetAttribute("TheriBolaFlight", flight)
	char:SetAttribute("TheriBolaResult", "thrown")
	char:SetAttribute("TheriBolaAt", t) -- last: FX + pose
	task.wait(BOLA_WIND + flight)
	local t2 = now()
	local r, br = rootOf(char), rootOf(best)
	local result
	if not (char.Parent and r and br and stillTarget(char, best)) or flat(br.Position - r.Position).Magnitude > range + 15 then
		result = "missed"
	elseif sapBlocked(r, best) then -- v1.8: Sap Wall
		result = "wall"
	elseif shielded(best, t2) then
		result = "shielded"
	else
		result = "hit"
		local rootT = math.max(0, num(char, "TheriSnareRoot", 1))
		damage(char, player, best, num(char, "TheriSnareDamage", 12), "therisnare", t2)
		hold(char, best, br.Position, rootT, t2)
		slow(best, 0.1, t2 + rootT, t2)
		count("TheriMovesBolaHits")
		char:SetAttribute("TheriSnareHitTarget", best.Name)
		char:SetAttribute("TheriSnareHitAt", t2)
		char:SetAttribute("TheriBolaHitAt", t2)
	end
	char:SetAttribute("TheriBolaResult", result)
end)

-- Dash -----------------------------------------------------------------------------------------------------------------------------
botHook(grappleRemote):Connect(function(player, stamp, moveDir)
	if not rework("Dash") then return end
	local c0 = player.Character
	if c0 then grappleLeft(c0, now()) grapplePublish(c0, now()) end
	local char, t = check(player, stamp, "zgrapple", "TheriGrapple", nil, false)
	if not char then return end
	local left, st = grappleLeft(char, t)
	if left <= 0 then
		char:SetAttribute("TheriGrappleServerResult", "cooldown")
		char:SetAttribute("TheriGrappleServerResultAt", t)
		return
	end
	local root = rootOf(char)
	local s = char:GetScale()
	local dir = typeof(moveDir) == "Vector3" and moveDir == moveDir and flat(moveDir) or Vector3.zero
	dir = dir.Magnitude > 0.1 and dir.Unit or forward(char)
	local range = math.max(0, num(char, "TheriGrappleRange", 30))
	local from = root.Position
	local hit = workspace:Raycast(from, dir * range, worldOnly())
	local dist = hit and math.max(0, flat(hit.Position - from).Magnitude - 3 * s) or range
	if dist < DASH_MIN then
		char:SetAttribute("TheriDashResult", "blocked")
		char:SetAttribute("TheriGrappleServerResult", "blocked")
		char:SetAttribute("TheriGrappleServerResultAt", t)
		return
	end
	local to = from + dir * dist
	local g0 = groundY(from, nil)
	local g1 = groundY(to, nil)
	if g0 and g1 then to = Vector3.new(to.X, g1 + (from.Y - g0), to.Z) end
	table.insert(st.refills, t + math.max(0.5, num(char, "TheriGrappleCooldown", 6)))
	char:SetAttribute("TheriGrappleServerResult", "ok")
	char:SetAttribute("TheriGrappleServerResultAt", t)
	grapplePublish(char, t)
	count("TheriMovesDashes")
	char:SetAttribute("TheriDashFrom", from)
	char:SetAttribute("TheriDashTo", to)
	char:SetAttribute("TheriDashDelay", DASH_DELAY)
	char:SetAttribute("TheriDashTime", math.clamp(dist / DASH_SPEED, 0.08, 0.16))
	char:SetAttribute("TheriDashResult", "dash")
	char:SetAttribute("TheriDashAt", t) -- last: TheriGrappleZip 1.3 + FX + pose
end)
task.spawn(function() -- TheriDashMode for MechaButtons
	while true do
		task.wait(0.5)
		local mode = rework("Dash")
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			if char and char:GetAttribute("TheriGrappleEnabled") ~= nil and char:GetAttribute("TheriDashMode") ~= mode then
				char:SetAttribute("TheriDashMode", mode)
			end
		end
	end
end)

-- Reaper Reel ----------------------------------------------------------------------------------------------------------------------
local function muzzleOf(char)
	local m = char:FindFirstChild("ZPart_zhook")
	if m then
		local jib
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") then
				local role = p:GetAttribute("ZPartRole")
				if role == "muzzle" then return p.Position end
				if role == "jib" then jib = p.Position end
			end
		end
		if jib then return jib end
	end
	return rootOf(char).Position
end
botHook(hookRemote):Connect(function(player, stamp, aimDir)
	if not rework("Reel") then return end
	local char, t = check(player, stamp, "zhook", "TheriHook", aimDir, true)
	if not char then return end
	local root = rootOf(char)
	local s = char:GetScale()
	local dir = heading(char, aimDir)
	local range = math.max(0, num(char, "TheriHookRange", 50))
	local hookCone = num(char, "TheriHookCone", 35)
	if shotPass() then hookCone = math.max(hookCone, SHOT_ASSIST_DEG) end -- v1.9
	local best, d = nearestInCone(char, dir, range, hookCone)
	local from = muzzleOf(char)
	local result, aimEnd = "noTarget", from + dir * range
	if best then
		local to = rootOf(best).Position
		aimEnd = to
		local hit = workspace:Raycast(from, to - from, worldOnly())
		if hit then
			result, aimEnd = "blocked", hit.Position
		elseif shielded(best, t) then
			result = "shielded"
		else
			result = "hit"
		end
	end
	local gapS = REEL_GAP * s
	local fly = math.clamp((aimEnd - from).Magnitude / REEL_CLAW_SPEED, 0.12, 0.35)
	if shotPass() then fly = math.clamp((aimEnd - from).Magnitude / (REEL_CLAW_SPEED * SHOT_SPEED_MUL), 0.12 / SHOT_SPEED_MUL, 0.35 / SHOT_SPEED_MUL) end -- v1.9
	local reel = (result == "hit") and math.clamp(math.max(0, d - gapS) / REEL_SPEED, 0.3, 0.8) or 0
	char:SetAttribute("TheriReelTarget", (result == "hit" or result == "shielded") and best.Name or "")
	char:SetAttribute("TheriReelEnd", aimEnd)
	char:SetAttribute("TheriReelBrace", REEL_BRACE)
	char:SetAttribute("TheriReelFly", fly)
	char:SetAttribute("TheriReelTime", reel)
	char:SetAttribute("TheriReelGap", gapS)
	char:SetAttribute("TheriReelResult", result)
	if result == "noTarget" or result == "blocked" then
		char:SetAttribute("TheriHookServerResult", result)
		char:SetAttribute("TheriHookServerResultAt", t)
		char:SetAttribute("TheriReelAt", t) -- last: FX (claw out and back, no recharge)
		return
	end
	ok(char, "TheriHook", t)
	char:SetAttribute("TheriReelAt", t) -- last: TheriGrappleZip 1.3 + FX + pose
	if result ~= "hit" then return end
	local total = REEL_BRACE + fly + reel
	best:SetAttribute("HookHeldUntil", t + total + REEL_SETTLE)
	if Players:GetPlayerFromCharacter(best) then
		slow(best, 0.1, t + total + REEL_SETTLE, t)
	else
		local br = rootOf(best)
		local at = br.Position
		task.spawn(slideBot, best, function()
			local r2 = rootOf(best)
			return Vector3.new(at.X, r2 and r2.Position.Y or at.Y, at.Z)
		end, total + REEL_SETTLE)
	end
	task.wait(total + REEL_SETTLE)
	local t2 = now()
	local r, br = rootOf(char), rootOf(best)
	if not (char.Parent and r and br and stillTarget(char, best)) or flat(br.Position - r.Position).Magnitude > gapS + REEL_REACH then
		char:SetAttribute("TheriReelResult", "missed")
		return
	end
	if sapBlocked(char, best) then -- v1.8: Sap Wall
		char:SetAttribute("TheriReelResult", "wall")
		return
	end
	if shielded(best, t2) then
		char:SetAttribute("TheriReelResult", "shielded")
		return
	end
	damage(char, player, best, REEL_SLASH, "therihook", t2)
	count("TheriMovesReelHits")
	char:SetAttribute("TheriReelHitAt", t2)
	if char:GetAttribute("TheriHookCut") == true then
		stun(best, t2 + math.max(0, num(char, "TheriHookStun", 1)))
		local fn = cutFn()
		local cr = "noCut"
		if fn then
			local okCall, res = pcall(function() return fn:Invoke(player) end)
			cr = okCall and tostring(res) or "error"
		end
		char:SetAttribute("TheriHookCutResult", cr)
	end
end)

-- v1.5: Overclock III's extra jump charge (see the header) -------------------------------------------------------------------------
if script:GetAttribute("TheriMovesClockJumpEnabled") == nil then script:SetAttribute("TheriMovesClockJumpEnabled", true) end
task.spawn(function()
	while true do
		task.wait(CLOCK_TICK)
		local switchOn = script:GetAttribute("TheriMovesClockJumpEnabled") ~= false
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			if char and char.Parent then
				local add = math.max(0, math.floor(num(char, "TheriClockJump", 0)))
				local want = switchOn and add >= 1 and char:GetAttribute("TheriClockPassive") == true
				local added = char:GetAttribute("TheriClockJumpAdded") == true
				local cur = math.floor(num(char, "JumpCharges", 0))
				if want then
					local base = math.floor(num(char, "TheriClockJumpBase", cur))
					if not added or cur ~= base + add then
						if added and cur ~= base + add then base = cur end -- something else rewrote JumpCharges: that is the new base
						char:SetAttribute("TheriClockJumpBase", base)
						char:SetAttribute("JumpCharges", base + add)
						char:SetAttribute("TheriClockJumpAdded", true)
					end
				elseif added then
					char:SetAttribute("JumpCharges", math.floor(num(char, "TheriClockJumpBase", cur)))
					char:SetAttribute("TheriClockJumpAdded", false)
				end
			end
		end
	end
end)

-- v1.6: Wing Volley (see the header) -----------------------------------------------------------------------------------------------
if script:GetAttribute("TheriMovesFeatherVolleyEnabled") == nil then script:SetAttribute("TheriMovesFeatherVolleyEnabled", true) end
local VOLLEY_RELEASE, VOLLEY_FLIGHT = 0.42, 0.6
script:SetAttribute("TheriMovesVolleys", 0)
script:SetAttribute("TheriMovesVolleyHits", 0)
botHook(featherRemote):Connect(function(player, stamp, aimDir)
	if script:GetAttribute("TheriMovesFeatherVolleyEnabled") == false then return end
	local char, t = check(player, stamp, "zfeather", "TheriFeather", aimDir, true)
	if not char then return end
	ok(char, "TheriFeather", t)
	local root = rootOf(char)
	local dir = heading(char, aimDir)
	local origin = root.Position
	local n = math.max(1, math.floor(num(char, "TheriFeatherCount", 8)))
	local range = math.max(0, num(char, "TheriFeatherRange", 20))
	local fan = math.rad(math.clamp(num(char, "TheriFeatherFan", 60), 0, 180))
	local dmg = math.max(0, num(char, "TheriFeatherDamage", 3))
	local slowMul, slowT = num(char, "TheriFeatherSlowMul", 1), math.max(0, num(char, "TheriFeatherSlowTime", 0))
	count("TheriMovesVolleys")
	char:SetAttribute("TheriFeatherVolley", true)
	char:SetAttribute("TheriFeatherDir", dir)
	char:SetAttribute("TheriFeatherOrigin", origin)
	char:SetAttribute("TheriVolleyRelease", VOLLEY_RELEASE)
	local vFlight = shotPass() and VOLLEY_FLIGHT / SHOT_SPEED_MUL or VOLLEY_FLIGHT -- v1.9
	char:SetAttribute("TheriVolleyFlight", vFlight)
	char:SetAttribute("TheriVolleyResult", "windup")
	char:SetAttribute("TheriVolleyDarts", "")
	char:SetAttribute("TheriFeatherHits", "")
	char:SetAttribute("TheriFeatherAt", t) -- last: pose / FX / wings
	task.wait(VOLLEY_RELEASE)
	if char:GetAttribute("TheriFeatherAt") ~= t then return end -- a newer press took over
	local t1 = now()
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (char.Parent and hum and hum.Health > 0 and rootOf(char)) or num(char, "StunnedUntil", 0) > t1 then
		char:SetAttribute("TheriVolleyResult", "cancelled")
		char:SetAttribute("TheriVolleyFiredAt", t1)
		return
	end
	local dirs = {}
	for i = 1, n do
		local a = n == 1 and 0 or (-fan / 2 + fan * (i - 1) / (n - 1))
		table.insert(dirs, (CFrame.Angles(0, a, 0) * dir).Unit)
	end
	local judged, hits, dartOf, dartAlong = {}, {}, {}, {}
	for _, m in ipairs(candidates(char)) do
		local mr = rootOf(m)
		local blades = 0
		for i, d in ipairs(dirs) do
			local along = math.clamp(flat(mr.Position - origin):Dot(d), 0, range)
			local pt = origin + d * along
			if script:GetAttribute("TheriMovesFlatBladesEnabled") ~= false then pt = Vector3.new(pt.X, mr.Position.Y, pt.Z) end
			if gap(m, pt) <= BLADE_WIDTH then
				blades += 1
				if dartAlong[i] == nil or along < dartAlong[i] then dartOf[i], dartAlong[i] = m, along end
			end
		end
		if blades > 0 then
			table.insert(judged, {m = m, blades = blades})
			table.insert(hits, m.Name .. "=" .. blades)
		end
	end
	local darts = {}
	for i = 1, n do
		if dartOf[i] then table.insert(darts, i .. "=" .. dartOf[i].Name) end
	end
	char:SetAttribute("TheriFeatherHits", table.concat(hits, "|"))
	char:SetAttribute("TheriVolleyDarts", table.concat(darts, "|"))
	char:SetAttribute("TheriVolleyResult", "fired")
	char:SetAttribute("TheriVolleyFiredAt", t1) -- last: the darts leave
	task.wait(vFlight) -- v1.9 (was VOLLEY_FLIGHT)
	local t2 = now()
	local landed = {}
	for _, j in ipairs(judged) do
		if char.Parent and stillTarget(char, j.m) and not sapBlocked(char, j.m) then -- v1.8: Sap Wall
			for _ = 1, j.blades do damage(char, player, j.m, dmg, "therifeather", t2) end
			slow(j.m, slowMul, t2 + slowT, t2)
			count("TheriMovesVolleyHits")
			table.insert(landed, j.m.Name .. "=" .. j.blades)
		end
	end
	char:SetAttribute("TheriVolleyLanded", table.concat(landed, "|"))
	char:SetAttribute("TheriVolleyLandedAt", t2) -- last: the darts land
end)

-- v1.13: the bot entrance (see the header)
if script:GetAttribute("TheriMovesServerBotMechaEnabled") == nil then script:SetAttribute("TheriMovesServerBotMechaEnabled", true) end
do
	local proxyModule = game:GetService("ServerStorage"):WaitForChild("DinoArcade"):FindFirstChild("BotProxy")
	local BotProxy = proxyModule and require(proxyModule)
	local fn = script:FindFirstChild("BotMechaUse") or Instance.new("BindableFunction")
	fn.Name = "BotMechaUse"
	local joined = setmetatable({}, {__mode = "k"})
	fn.OnInvoke = function(model, remoteName, ...)
		if script:GetAttribute("TheriMovesServerBotMechaEnabled") == false then return "off" end
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
				script:SetAttribute("TheriMovesServerBotMechaError", tostring(remoteName) .. ": " .. tostring(err))
				return "botUnsupported"
			end
		end
		return "ok"
	end
	fn.Parent = script
end
script:SetAttribute("TheriMovesServerVersion", "1.13") -- v1.13 bot entrance
script:SetAttribute("TheriMovesServerVersion", "1.14") -- v1.14 pre-match lock
-- v1.14 (pre-match lock, MDA-528, plan docs/plans/PREMATCH_LOCK_PAN_v1.0.md rule 2; Kepu 2026-11-13 18:23 "all mecha abilities
--   and actions should be unplayable ... during the count down", pick "A · Locked everywhere"): every request from a player whose
--   character PrematchLockUntil (PracticeServer 1.12) is after the server time is dropped before the handler runs (handler
--   bodies unchanged; bots never locked: BotUse / BotMechaUse call the handlers directly).
