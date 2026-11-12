-- HerreraMovesServer v1.10 (Mecha Dino Arena) — the moves of the Herrera's keyed mecha parts (pass 2): Quill Launcher
-- (MDA-151), Smoke Pods (MDA-152), Strobe Frill (MDA-155), Stun Breaker (MDA-156), and the Glider Wings' glide state
-- (MDA-150). Plan docs/plans/HERRERA_PARTS_v1.0.md (Parts 2, 3, 4, 7, 8 and "Pass 2 — build map"); Kepu 2026-10-31.
-- Settings come from the character (SkillEffects 1.27, a Herrera with the part bought AND slotted):
--   QuillEnabled / QuillCount / QuillDamage / QuillRange / QuillCooldown, SmokeEnabled / SmokeRadius / SmokeTime /
--   SmokeRunMul / SmokeSlowMul / SmokeCooldown, StrobeEnabled / StrobeAngle / StrobeRange / StrobeDaze / StrobeDazedMul /
--   StrobeCooldown, BreakerEnabled / BreakerPush / BreakerCooldown / BreakerImmune, GliderEnabled / GliderDrop.
-- Remotes (ReplicatedStorage, created here): DinoQuillRequest(stamp, aimDir), DinoSmokeRequest(stamp),
--   DinoStrobeRequest(stamp), DinoBreakerRequest(stamp) (MechaButtons 1.24), DinoGlideRequest(on) (GliderTest 1.0).
-- Request checks, first failing wins (character <Prefix>ServerResult + <Prefix>ServerResultAt):
--   quills / strobe: "badArg", "dead", "disabled", "menu", "stunned", "pinned", "dazed", "cooldown", "ok".
--   smoke:           "badArg", "dead", "disabled", "menu", "stunned", "pinned", "cooldown", "ok".
--   breaker:         "badArg", "dead", "disabled", "menu", "notStunned" (StunnedUntil <= now and PinHeld not true),
--                    "cooldown", "ok".
--   Every ok starts the cooldown: <Prefix>ReadyAt = now + <Prefix>Cooldown.
-- Who can be hit (quills, smoke slow, strobe, breaker push): Workspace models with a Hitboxes folder, Bitable true, a
--   Species or IsBot, not self, not KO, alive; players only where ModeRules.canAffect allows (the Arena), bots always.
-- Quill Launcher: target = the allowed dino whose root is nearest the aim inside a 35-degree flat cone around the camera
--   heading, within QuillRange x scale, in line of sight (the world blocks). None -> the quills fly straight ahead
--   QuillRange x scale ("miss"). QuillCount quills leave one every QUILL_GAP (0.045) s at QUILL_SPEED (90) studs/s; each
--   that arrives on a live, unshielded target does QuillDamage x roar debuff x daze star x Stun Breaker immunity off
--   DummyHealth (a killing blow stamps KilledBy / KilledByUserId / KilledWith "quills" / KilledAt). No bleed, no slow.
--   Shooter: QuillResult ("hit" / "miss"), QuillTarget (name or ""), QuillShot (count), QuillAimEnd, QuillFlightTime (s
--   for the first quill), QuillStartedAt (last; HerreraMovesFX draws the volley), then QuillLanded (hits),
--   QuillTotalDamage, QuillLandedAt (last). Target QuillHitAt / QuillHitBy.
-- Smoke Pods: the cloud stays at the drop point: SmokeCenter, SmokeRadiusNow (SmokeRadius x scale), SmokeUntil
--   (now + SmokeTime), SmokeStartedAt (last). Every SMOKE_TICK (0.1 s): the owner's root inside -> SmokeHidden true (bots
--   drop it, BotServer 1.22; other players' screens hide its BillboardGuis, TreeTopHide 1.1) and, with SmokeRunMul > 1,
--   SmokeRunUntil = the cloud's end (SprintTest 1.15); outside / over -> SmokeHidden false, SmokeRunUntil 0. When the owner
--   goes hidden, each bot whose BotTarget is this player gets SmokeLostAt (the "?" pop). Star (SmokeSlowMul < 1): every
--   allowed enemy inside: a player gets SmokeSlowUntil (the cloud's end) / SmokeSlowMul (SprintTest 1.15), cleared to 0
--   on leaving; a bot's WalkSpeed is scaled while inside (MineServer's pattern, BotServer untouched; SmokeSlowed).
-- Strobe Frill: the flash lands STROBE_WINDUP (0.15) s after the request (the rear-up), from the root's position and
--   facing at that moment: every allowed enemy whose root is within StrobeRange x scale and within StrobeAngle / 2 of the
--   facing (flat) and has no Energy Shield up is dazed: DazedUntil = max(old, now + StrobeDaze), DazedDamageMul =
--   StrobeDazedMul (1.2 at star; the higher one while an older daze runs), DazedBy, DazedAt (last). Dazed = the attack
--   servers refuse ("dazed") and bots start no attack; the damage multiplier is read by BoneCrest 1.4 / SlashServer 1.5
--   / HeadbuttServer 1.11 / HookServer 1.7 / the quills. Owner StrobeStartedAt (request), StrobeAt (flash, last),
--   StrobeHits (dinos dazed by the last flash).
-- Stun Breaker: StunnedUntil = now; when PinHeld, the pinner (PinnedBy, a player character) gets ShakeOffReason
--   "breaker" + ShakeOffAt now (PounceServer releases the pin); II (BreakerPush > 0): every allowed enemy within
--   BreakerPush x scale is pushed BreakerPush x scale straight away over BREAK_PUSH_TIME (0.3) s (a player:
--   HeadbuttShove*; a bot latched on someone: shaken off; another bot: slid); star (BreakerImmune > 0):
--   StunBreakImmuneUntil = now + BreakerImmune (BoneCrest 1.4 / SlashServer 1.5 / HeadbuttServer 1.11 / HookServer 1.7 /
--   the quills deal 0). Owner BreakerAt (last), BreakerPushed (count).
-- Glide: DinoGlideRequest(true) with GliderEnabled -> Gliding true, GlideStartedAt; (false), GliderEnabled off, death
--   -> Gliding false, GlideEndedAt. HerreraPartsServer 1.2 opens the wings; SlashServer 1.5 takes a dive while gliding.
-- Switches: script attributes HerreraMovesServerEnabled (default true, read at each request), HerreraMoves_quillsEnabled,
--   HerreraMoves_smokeEnabled, HerreraMoves_strobeEnabled, HerreraMoves_breakerEnabled, HerreraMoves_gliderEnabled
--   (default true each), HerreraMovesModeRulesEnabled (default true; false = players can always be hit).
-- Diagnostics: script HerreraMovesServerVersion, HerreraMovesMode, QuillVolleys, QuillHits, SmokeClouds, StrobeFlashes,
--   StrobeDazes, BreakerBreaks; character results above.
-- v1.1 (Arena squads, MDA-159, plan docs/plans/SQUADS_v1.0.md Task S2, ADR-006; Kepu 2026-10-31 "turning friendly fire off",
--   picked "Everything harmful"): mayAffect(source, target) is also false for a squadmate (wraps the ModeRules check), so no squadmate is ever picked, hit or slowed. Squadmates = SquadRules 1.0 sameChar (same Arena squad; a test target's
--   SquadTestId counts). Switch: script attribute HerreraMovesServerSquadEnabled (default true, read at each check; false = 1.0).
--   Diagnostic: script HerreraMovesServerSquadSkips (count of squadmate skips / refusals).
-- v1.2 (Herrera parts pass 3, MDA-165 / MDA-166, plan docs/plans/HERRERA_PARTS_v1.0.md Parts 9-10; Kepu 2026-10-31 picks):
--   Razor Caltrops: DinoCaltropRequest(stamp); check(..., "caltrops", "Caltrop", {}) (not refused by daze). The patch centre
--   is root - facing (flat) x (CaltropRadius + 4) x scale; CaltropCount spikes at sunflower spots within CaltropRadius x scale,
--   dropped on the ground. A new patch replaces the old one. Data for the clients: ReplicatedStorage.CaltropPatches (Folder),
--   one Configuration "Patch_<UserId>" per patch (Owner, OwnerUserId, Until, Hidden (star), Scale, Spikes = JSON
--   [[x, y, z, used], ...], DroppedAt); HerreraMovesFX 1.3 draws them (Hidden: only the owner and squadmates). Every 0.1 s an
--   allowed enemy (candidates: mode + squad rules) whose root is within (1.6 x patch scale + 1.5 x its own scale) studs flat
--   (and 12 x scale up or down) of an unused spike uses it up (at most one spike per 0.35 s per target; an Energy Shield
--   blocks it and the spike stays): bleed CaltropBleedDps every 1 s from now for CaltropBleedTime s (3 ticks of 3), each tick
--   x the damage-taken multiplier, KilledWith "caltrops"; slow: a player gets CaltropSlowMul / CaltropSlowUntil (now +
--   CaltropSlowTime; SprintTest 1.16), a bot's WalkSpeed is scaled (the smoke star's pattern). Target stamps:
--   CaltropBleedUntil, CaltropBleedBy, CaltropHitAt (last); owner CaltropHits. The patch ends at Until, or when the owner
--   dies / leaves / loses the part (running bleeds finish).
--   Goo Blob Shooter (Kepu 15:49 "Have the blobs just toss from a set distance and be dropped immediately under you when
--   gliding", 15:50 "Also soft aim to assist"): DinoGooRequest(stamp); check(..., "goo", "Goo", {}). Landing point: while
--   Gliding, the ground straight under the root; else the closest allowed enemy whose root is within GooAssistAngle (30)
--   degrees of the facing and GooAssistMin..GooAssistMax (15..45) x scale studs (GooAssistTarget = its name; switch
--   HerreraMoves_gooAssistEnabled), else root + facing x GooToss (30) x scale; then dropped on the ground. GooCount 2 (III):
--   two points +- right x GooRadius x 0.85 x scale. Each blob (Workspace.DinoFX.GooFX, lime Neon ball, anchored, no collide /
--   query / touch) flies 0.85 s on an arc (peak 14 studs above the higher end; 0.45 s straight down while gliding), the 2nd
--   0.12 s later, then a puddle "GooPuddle" (lime Neon disc, GooRadius x scale, with a darker rim) lasts GooTime s (fades
--   over the last 0.6 s). Every 0.2 s each allowed enemy whose root is inside a live puddle (flat, within 10 x scale up or
--   down) is slowed: player GooSlowMul / GooSlowUntil (now + 0.3), bot WalkSpeed x GooSlowMul. Owner stamps: GooLand,
--   GooAssistTarget, GooFiredAt (last). Switches: HerreraMoves_caltropsEnabled, HerreraMoves_gooEnabled,
--   HerreraMoves_gooAssistEnabled (default true each). Diagnostics: script CaltropDrops, CaltropTriggers, GooShots.
-- v1.3 (Kepu 2026-10-31 "the spikes need a better animation as it falls out they just appear"; mockup
--   docs/mockups/herrera_caltrops_drop_options.html, picked "A · Chute spray" + "When it lands"): each spike now arms only
--   when its drop animation (HerreraMovesFX 1.4) lands: spike i (0-based) armAt = DroppedAt + i x CALTROP_ARM_GAP (0.035 s)
--   + CALTROP_ARM_FLY (0.42 s); the trigger loop skips a spike while now < armAt. The patch publishes the two numbers as
--   Configuration attributes ArmGap / ArmFly so the clients animate on the same clock. Switch: script attribute
--   HerreraMoves_caltropArmOnLandEnabled (default true, read at each drop; false = 1.2, armed on press, ArmGap / ArmFly 0).
-- v1.4 (plan docs/plans/HERRERA_PARTS_LOOKS_v2.0.md Task 4, MDA-290; Kepu 2026-11-05 red-team "From the mouth"): a goo
--   blob starts at the character's HPart_goo piece with HPartRole "muzzle" (the Spit Sacs' jaw nozzle, HerreraPartsServer
--   1.4) when there is one, else above the hump as 1.3. Same arc, landing point, timing and puddle. Switch: script attribute
--   HerreraMoves_gooMuzzleEnabled (default true, read at each shot). Diagnostic: script GooMuzzleShots.
-- v1.5 (plan docs/plans/HERRERA_MOVES_ANIM_v1.0.md Task 1, MDA-291; Kepu 2026-11-05 20:40 picks "A for everything except
--   B for glide and drop"; red-team: wind-ups still fire through a stun, only death cancels; breaker free at the press):
--   each move gets a wind-up between the press and its effect, so the new poses (HerreraMovesPose 1.2) can show it.
--   Script attributes (seconds): HerreraMoves_quillWindup 0.35, HerreraMoves_smokeWindup 0.25, HerreraMoves_strobeWindup
--   0.40, HerreraMoves_gooWindup 0.35, HerreraMoves_breakerWindup 0.30. At the press (after the checks; the cooldown is
--   spent then, as 1.4): <P>WindupTime, then <P>WindupAt = now (QuillWindupAt, SmokeWindupAt, GooWindupAt,
--   BreakerWindupAt; the strobe keeps StrobeStartedAt + StrobeWindupTime). The request then waits the wind-up; when the
--   character is still in workspace, alive and has its root, <P>WindupResult "fired" and the 1.4 body runs with the time
--   of that moment (quills: the press's aim, the target from the root then; smoke: the cloud centred there; goo: the
--   muzzle there); else <P>WindupResult "cancelled" and nothing happens. Strobe: the flash delay is the strobe wind-up.
--   Breaker: StunnedUntil, the pin release and StunBreakImmuneUntil (press + BreakerImmune) stay at the press; the push,
--   BreakerPushed and BreakerAt come after the wind-up. Switch: script attribute HerreraMoves_windupsEnabled (default
--   true, read at each press; false = 1.4: no wait, strobe 0.15). Diagnostics: script HerreraMovesWindups,
--   HerreraMovesWindupCancels.
-- v1.6 (Kepu 2026-11-05 21:53 "Apply the slow badge as well as make it 50% slower and even when they step out they're
--   slow for 3 seconds. Make the splash area 1.3x bigger"; the 1.3x and 50% are SkillTree 1.68's goo numbers): a goo
--   puddle tick keeps an enemy slowed until now + HerreraMoves_gooLinger (3 s) instead of now + 0.3, so the slow lasts 3 s
--   after it steps out; a bot also gets GooSlowUntil / GooSlowMul stamped (StatusBadges 1.3 shows its SLOW badge; its speed
--   is still the botSlow walk-speed scale). Switch: script attribute HerreraMoves_gooLingerEnabled (default true, read at
--   each tick; false = 1.5). Diagnostic: script GooSlowTicks.
-- v1.11 (Bots v2, MDA-468, plan docs/plans/BOTS_V2_v1.0.md T3; found in Studio 2026-11-11: practice bots frozen at WalkSpeed
--   0.0055 / 0 because several scripts' bot-slow loops each took the other's slowed speed as their base every frame):
--   a practice bot (PracticeBot = true) in the bot-slow loop gets model attributes SlowMul_HerreraMoves / SlowUntil_HerreraMoves (this slow's
--   multiplier and end, server time) instead of a WalkSpeed write, any speed this loop had set is given back, and it leaves the
--   loop; PracticeBrain 2.0 owns the bot's WalkSpeed (base x the active SlowMul_*). Other bots and players: as before.
--   Switch: script attribute HerreraMovesServerBotSlowAttrEnabled (default true, read per frame; false = the previous version).
-- v1.12 (Bots v2, MDA-471, plan docs/plans/BOTS_V2_v1.0.md T7; Kepu 2026-11-11 20:39 "the damn bots don't even use their
--   attack buttons or their mecha"): a bot entrance. Every remote handler of this script is connected through botHook(remote)
--   (handler bodies unchanged), which also files it by the remote's name. Server-only BindableFunction "BotMechaUse" (child):
--   Invoke(model, remoteName, ...the remote's own arguments...) runs every handler filed for that remote, in order, with
--   ServerStorage.DinoArcade.BotProxy.of(model) as the player (the model is its Character; PracticeBot models only).
--   Returns "ok" (the handlers ran; their results land on the model as for a player), "off", "badArg", "noHandler" or
--   "botUnsupported" (a handler errored; script attribute HerreraMovesServerBotMechaError keeps "<remote>: <error>").
--   Switch: script attribute HerreraMovesServerBotMechaEnabled (default true, read per call).
local __botHandlers = {} -- v1.12: remote name -> handlers (see the header)
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
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.3"
VERSION = "1.4" -- v1.4 goo blob from the jaw nozzle
VERSION = "1.5" -- v1.5 move wind-ups
VERSION = "1.6" -- v1.6 goo slow lingers 3 s
VERSION = "1.7" -- v1.7 Sap Wall stops quills / caltrops / goo through it
-- v1.7 (MDA-353) Sap Wall: a live Sap Wall on the attacker (or splash centre) -> target line stops the hit (ServerStorage.DinoArcade
--   SapWallBlock.between). Switch: script attribute HerreraMovesServerSapWallEnabled (default true, read at each hit). Diagnostics: script
--   HerreraMovesServerSapWallBlocks (count), HerreraMovesServerSapWallBlockedAt (server time).
local sapBlocked do
	local mod
	sapBlocked = function(from, to)
		if script:GetAttribute("HerreraMovesServerSapWallEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.between and mod.between(from, to)) then return false end
		script:SetAttribute("HerreraMovesServerSapWallBlocks", (script:GetAttribute("HerreraMovesServerSapWallBlocks") or 0) + 1)
		script:SetAttribute("HerreraMovesServerSapWallBlockedAt", workspace:GetServerTimeNow())
		return true
	end
	if script:GetAttribute("HerreraMovesServerSapWallEnabled") == nil then script:SetAttribute("HerreraMovesServerSapWallEnabled", true) end
end
VERSION = "1.8" -- v1.8 a goo blob whose arc goes through a Sap Wall stops there
-- v1.8 (MDA-353, Kepu 2026-11-07 lobbed shots "Can go over"): each Goo Blob's real flight (flyBlob(): from:Lerp(to, u), y + 4 x (peak - (y0 + y1) / 2)
--   x u x (1 - u), peak = the higher end + 14 x scale; straight down while gliding) is checked when it leaves by SapWallBlock
--   1.2 arcBlocks: an arc through a live wall stops the blob at the wall (it flies only to the hit; no puddle; character
--   GooWallAt), an arc over the wall lands as before (the puddle centre -> target check stays).
--   Switch: script attribute HerreraMovesServerSapArcEnabled (default true, read at each shot; false = the previous behaviour: no check of the
--   flight itself). Diagnostics: script HerreraMovesServerSapArcBlocks (count), HerreraMovesServerSapArcBlockedAt (server time).
VERSION = "1.9" -- v1.9 shot pass: faster shots, strong aim assist
-- v1.9 (Kepu 2026-11-09 "all the projectile shots need to be faster and more auto aim assist on it and longer range"
--   -> 1.5x faster, 2x range, "Strong" assist = snap to a target within 45 degrees of the aim; plan
--   docs/plans/SHOT_PASS_v1.0.md): quills fly QUILL_SPEED x 1.5 (published as the character attribute QuillSpeed for
--   HerreraMovesFX 1.7) and lock on within 45 degrees (was QUILL_CONE 35); the goo blob flies 1.5x faster (0.85 /
--   0.45 s -> / 1.5). Quill range, goo toss and goo assist come from SkillTree 1.74. Switch: script attribute
--   ShotPassEnabled (default true; false = 1.8).
VERSION = "1.10" -- v1.10 armor on every hit (MDA-366)
VERSION = "1.11" -- v1.11 practice bot slows as attributes
-- v1.10 (MDA-366, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 "Every attack"): armor (Thick Hide / Armored Hide /
--   Wiry Frame = the victim's StatDamageTakenMul) now cuts quills and caltrop ticks (takeHealth):
--   damage x BoneCrest.armor(victim) (ServerStorage.DinoArcade.BoneCrest 1.7, one shared call). Switch: script attribute
--   HerreraMovesServerArmorAllEnabled (default true, read at each hit; false = 1.9). Diagnostic: script HerreraMovesServerArmorCuts (count of hits cut).
local SHOT_SPEED_MUL, SHOT_ASSIST_DEG = 1.5, 45 -- v1.9
local function shotPass() return script:GetAttribute("ShotPassEnabled") ~= false end -- v1.9
if script:GetAttribute("ShotPassEnabled") == nil then script:SetAttribute("ShotPassEnabled", true) end -- v1.9
local sapArcBlocked do
	local mod
	sapArcBlocked = function(from, to, peak)
		if script:GetAttribute("HerreraMovesServerSapArcEnabled") == false then return false end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage").DinoArcade.SapWallBlock) end) end
		if not (mod and mod.arcBlocks) then return false end
		local b, _, u, pos = mod.arcBlocks(from, to, peak)
		if not b then return false end
		script:SetAttribute("HerreraMovesServerSapArcBlocks", (script:GetAttribute("HerreraMovesServerSapArcBlocks") or 0) + 1)
		script:SetAttribute("HerreraMovesServerSapArcBlockedAt", workspace:GetServerTimeNow())
		return true, u, pos
	end
	if script:GetAttribute("HerreraMovesServerSapArcEnabled") == nil then script:SetAttribute("HerreraMovesServerSapArcEnabled", true) end
end
local QUILL_GAP, QUILL_SPEED, QUILL_CONE = 0.045, 90, math.rad(35)
local SMOKE_TICK = 0.1
local STROBE_WINDUP = 0.15
local BREAK_PUSH_TIME = 0.3

script:SetAttribute("HerreraMovesServerVersion", VERSION)
for _, k in ipairs({"HerreraMovesServerEnabled", "HerreraMoves_quillsEnabled", "HerreraMoves_smokeEnabled",
	"HerreraMoves_strobeEnabled", "HerreraMoves_breakerEnabled", "HerreraMoves_gliderEnabled", "HerreraMovesModeRulesEnabled",
	"HerreraMoves_caltropsEnabled", "HerreraMoves_gooEnabled", "HerreraMoves_gooAssistEnabled",
	"HerreraMoves_caltropArmOnLandEnabled", "HerreraMoves_gooMuzzleEnabled", "HerreraMoves_windupsEnabled", "HerreraMoves_gooLingerEnabled"}) do -- v1.2: + pass 3; v1.3: + arm on land; v1.4: + goo muzzle
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(id)
	return script:GetAttribute("HerreraMovesServerEnabled") ~= false and script:GetAttribute("HerreraMoves_" .. id .. "Enabled") ~= false
end
local function now() return workspace:GetServerTimeNow() end

local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("HerreraMovesMode", MODE)
local function mayAffect(source, target)
	if script:GetAttribute("HerreraMovesModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end
-- v1.1: squadmates are never targets (SquadRules 1.0, loaded on first use)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("HerreraMovesServerSquadEnabled") == false then return false end
	if not squadMod then
		local arc = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		script:SetAttribute("HerreraMovesServerSquadSkips", (script:GetAttribute("HerreraMovesServerSquadSkips") or 0) + 1)
		return true
	end
	return false
end
do -- v1.1: wrap the mode check with the squad check
	local modeOnly = mayAffect
	mayAffect = function(source, target)
		if squadmate(source, target) then return false end
		return modeOnly(source, target)
	end
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
local quillRemote, smokeRemote = remote("DinoQuillRequest"), remote("DinoSmokeRequest")
local strobeRemote, breakerRemote, glideRemote = remote("DinoStrobeRequest"), remote("DinoBreakerRequest"), remote("DinoGlideRequest")

local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end

-- targets (InkServer 1.4's rules) ------------------------------------------------------------------------------------
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

-- v1.5: move wind-ups -------------------------------------------------------------------------------------------------
local WINDUP_DEFAULTS = {quill = 0.35, smoke = 0.25, strobe = 0.40, goo = 0.35, breaker = 0.30}
for id, v in pairs(WINDUP_DEFAULTS) do
	if script:GetAttribute("HerreraMoves_" .. id .. "Windup") == nil then script:SetAttribute("HerreraMoves_" .. id .. "Windup", v) end
end
script:SetAttribute("HerreraMovesWindups", script:GetAttribute("HerreraMovesWindups") or 0)
script:SetAttribute("HerreraMovesWindupCancels", script:GetAttribute("HerreraMovesWindupCancels") or 0)
local function windupsOn() return script:GetAttribute("HerreraMoves_windupsEnabled") ~= false end
local function windupTime(id)
	local v = tonumber(script:GetAttribute("HerreraMoves_" .. id .. "Windup"))
	return math.clamp(v or WINDUP_DEFAULTS[id], 0, 2)
end
-- stamps the press, waits the wind-up; returns the fire time, or nil (cancelled). Switch off: returns t at once.
local function windup(char, prefix, id, t)
	if not windupsOn() then return t end
	local w = windupTime(id)
	char:SetAttribute(prefix .. "WindupTime", w)
	char:SetAttribute(prefix .. "WindupResult", "winding")
	char:SetAttribute(prefix .. "WindupAt", t) -- last: HerreraMovesPose / HerreraPartsAnim / HerreraMovesFX start the wind-up
	count("HerreraMovesWindups")
	if w > 0 then task.wait(w) end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not char:IsDescendantOf(workspace) or not hum or hum.Health <= 0 or not rootOf(char) then
		char:SetAttribute(prefix .. "WindupResult", "cancelled")
		count("HerreraMovesWindupCancels")
		return nil
	end
	char:SetAttribute(prefix .. "WindupResult", "fired")
	return now()
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
local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
local function worldExclude()
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "HerreraPartsFX", "HerreraMovesFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	worldParams.FilterDescendantsInstances = ex
	return worldParams
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function shielded(m, t) return num(m, "EnergyShieldUntil", 0) > t end

-- damage taken multiplier: roar debuff x daze star x Stun Breaker star
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
		if script:GetAttribute("HerreraMovesServerArmorAllEnabled") == false then return 1 end
		if mod == nil then mod = false; pcall(function() mod = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end) end
		local a = mod and mod.armor and mod.armor(victim) or 1
		if a ~= 1 then script:SetAttribute("HerreraMovesServerArmorCuts", (script:GetAttribute("HerreraMovesServerArmorCuts") or 0) + 1) end
		return a
	end
	if script:GetAttribute("HerreraMovesServerArmorAllEnabled") == nil then script:SetAttribute("HerreraMovesServerArmorAllEnabled", true) end
end
local function takeHealth(m, d, char, player, with, t)
	d *= armorMul(m) -- v1.10 (MDA-366): armor
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return false end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", with)
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
		return true
	end
	return false
end

-- common request checks -------------------------------------------------------------------------------------------------
local function check(player, stamp, id, prefix, opts)
	local char = player.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp or (opts.aim and (typeof(opts.aimDir) ~= "Vector3" or opts.aimDir.Magnitude < 0.5
		or opts.aimDir.Magnitude > 1.5)) then
		r = "badArg"
	elseif not hum or hum.Health <= 0 or not rootOf(char) then
		r = "dead"
	elseif not on(id) or char:GetAttribute(prefix .. "Enabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif opts.breaker then
		if num(char, "StunnedUntil", 0) <= t and char:GetAttribute("PinHeld") ~= true then r = "notStunned" end
	elseif num(char, "StunnedUntil", 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif opts.attack and num(char, "DazedUntil", 0) > t then
		r = "dazed"
	end
	if not r and t < num(char, prefix .. "ReadyAt", 0) then r = "cooldown" end
	char:SetAttribute(prefix .. "ServerResult", r or "ok")
	char:SetAttribute(prefix .. "ServerResultAt", t)
	if r then return nil end
	char:SetAttribute(prefix .. "ReadyAt", t + math.max(0.5, num(char, prefix .. "Cooldown", 15)))
	return char, t
end

-- Quill Launcher ------------------------------------------------------------------------------------------------------
botHook(quillRemote):Connect(function(player, stamp, aimDir)
	local char, t = check(player, stamp, "quills", "Quill", {attack = true, aim = true, aimDir = aimDir})
	if not char then return end
	t = windup(char, "Quill", "quill", t) -- v1.5
	if not t then return end
	local root = rootOf(char)
	local s = char:GetScale()
	local range = math.max(1, num(char, "QuillRange", 40)) * s
	local heading = flat(aimDir)
	if heading.Magnitude < 1e-3 then heading = flat(root.CFrame.LookVector) end
	heading = heading.Magnitude > 1e-3 and heading.Unit or Vector3.zAxis
	local origin = root.Position + Vector3.new(0, 1.2 * s, 0)
	local params = worldExclude()
	local best, bestAng
	local qCone = shotPass() and math.max(QUILL_CONE, math.rad(SHOT_ASSIST_DEG)) or QUILL_CONE -- v1.9
	for _, m in ipairs(candidates(char)) do
		local p = rootOf(m).Position
		local v = p - origin
		local fv = flat(v)
		if v.Magnitude <= range and fv.Magnitude > 1e-3 then
			local ang = math.acos(math.clamp(heading:Dot(fv.Unit), -1, 1))
			if ang <= qCone and (not bestAng or ang < bestAng) and not workspace:Raycast(origin, v, params) then -- v1.9 (was QUILL_CONE)
				best, bestAng = m, ang
			end
		end
	end
	local n = math.max(1, math.floor(num(char, "QuillCount", 5)))
	local dmg = math.max(0, num(char, "QuillDamage", 4))
	local aimEnd = best and rootOf(best).Position or (origin + heading * range)
	local qSpeed = shotPass() and QUILL_SPEED * SHOT_SPEED_MUL or QUILL_SPEED -- v1.9
	local fly = (aimEnd - origin).Magnitude / qSpeed
	char:SetAttribute("QuillSpeed", qSpeed) -- v1.9: HerreraMovesFX flies the quills at this speed
	char:SetAttribute("QuillResult", best and "hit" or "miss")
	char:SetAttribute("QuillTarget", best and best.Name or "")
	char:SetAttribute("QuillShot", n)
	char:SetAttribute("QuillAimEnd", aimEnd)
	char:SetAttribute("QuillFlightTime", math.floor(fly * 1000 + 0.5) / 1000)
	char:SetAttribute("QuillStartedAt", t) -- last: HerreraMovesFX draws the volley
	count("QuillVolleys")
	if not best then return end
	local target = best
	local landed, total = 0, 0
	for i = 1, n do
		local launch = (i - 1) * QUILL_GAP
		task.delay(launch + fly, function()
			local ta = now()
			if target.Parent and isTarget(target, char) and mayAffect(char, target) and not shielded(target, ta) and not sapBlocked(origin, target) then -- v1.1: + mayAffect (squad / mode) on arrival
				local d = math.floor(dmg * takenMul(target, ta) * 10 + 0.5) / 10
				if d > 0 then
					takeHealth(target, d, char, player, "quills", ta)
					landed += 1
					total += d
					count("QuillHits")
					target:SetAttribute("QuillHitBy", char.Name)
					target:SetAttribute("QuillHitAt", ta)
				end
			end
			if i == n and char.Parent then
				char:SetAttribute("QuillLanded", landed)
				char:SetAttribute("QuillTotalDamage", total)
				char:SetAttribute("QuillLandedAt", ta) -- last: the total pop
			end
		end)
	end
end)

-- Smoke Pods ----------------------------------------------------------------------------------------------------------
local clouds = {} -- [char] = {center, radius, untilT, player, runMul, slowMul, hidden, slowed = {[model] = true}}
local botSlow = {} -- [bot] = {hum, base, set, untilT, mul}
botHook(smokeRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "smoke", "Smoke", {})
	if not char then return end
	t = windup(char, "Smoke", "smoke", t) -- v1.5
	if not t then return end
	local root = rootOf(char)
	local s = char:GetScale()
	local c = {center = root.Position, radius = math.max(1, num(char, "SmokeRadius", 12)) * s,
		untilT = t + math.max(0.5, num(char, "SmokeTime", 4)), player = player, runMul = num(char, "SmokeRunMul", 1),
		slowMul = num(char, "SmokeSlowMul", 1), slowed = {}}
	local old = clouds[char]
	if old then for m in pairs(old.slowed) do if m.Parent and Players:GetPlayerFromCharacter(m) then m:SetAttribute("SmokeSlowUntil", 0) end end end
	clouds[char] = c
	char:SetAttribute("SmokeCenter", c.center)
	char:SetAttribute("SmokeRadiusNow", c.radius)
	char:SetAttribute("SmokeUntil", c.untilT)
	char:SetAttribute("SmokeStartedAt", t) -- last: HerreraMovesFX puffs the cloud
	count("SmokeClouds")
end)

local function setHidden(char, c, hidden, t)
	if char:GetAttribute("SmokeHidden") == hidden then return end
	char:SetAttribute("SmokeHidden", hidden)
	if hidden then
		for _, b in ipairs(bots()) do
			if b:GetAttribute("BotTarget") == c.player.Name then b:SetAttribute("SmokeLostAt", t) end
		end
	end
end
local smokeAcc = 0
RunService.Heartbeat:Connect(function(dt)
	smokeAcc += dt
	if smokeAcc < SMOKE_TICK then return end
	smokeAcc = 0
	local t = now()
	for char, c in pairs(clouds) do
		local live = char.Parent and t < c.untilT and on("smoke") and char:GetAttribute("SmokeEnabled") == true
		local root = live and rootOf(char)
		local inside = root and (root.Position - c.center).Magnitude <= c.radius
		setHidden(char, c, inside and true or false, t)
		local runU = (inside and c.runMul > 1) and c.untilT or 0
		if char.Parent and char:GetAttribute("SmokeRunUntil") ~= runU then char:SetAttribute("SmokeRunUntil", runU) end
		-- star: enemies inside
		local now_in = {}
		if live and c.slowMul < 1 then
			for _, m in ipairs(candidates(char)) do
				if (rootOf(m).Position - c.center).Magnitude <= c.radius then now_in[m] = true end
			end
		end
		for m in pairs(now_in) do
			if Players:GetPlayerFromCharacter(m) then
				if m:GetAttribute("SmokeSlowUntil") ~= c.untilT then
					m:SetAttribute("SmokeSlowMul", c.slowMul)
					m:SetAttribute("SmokeSlowUntil", c.untilT)
				end
			else
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum then
					local e = botSlow[m] or {hum = hum}
					e.untilT, e.mul = t + SMOKE_TICK * 2.5, c.slowMul
					botSlow[m] = e
				end
			end
		end
		for m in pairs(c.slowed) do
			if not now_in[m] and m.Parent and Players:GetPlayerFromCharacter(m) then m:SetAttribute("SmokeSlowUntil", 0) end
		end
		c.slowed = now_in
		if not live then
			for m in pairs(c.slowed) do if m.Parent and Players:GetPlayerFromCharacter(m) then m:SetAttribute("SmokeSlowUntil", 0) end end
			if char.Parent then
				char:SetAttribute("SmokeHidden", false)
				char:SetAttribute("SmokeRunUntil", 0)
			end
			clouds[char] = nil
		end
	end
end)
-- bots: scale the AI's WalkSpeed while inside a star cloud (MineServer 1.1's pattern, BotServer untouched)
RunService.Stepped:Connect(function()
	local t = now()
	for m, e in pairs(botSlow) do
		local hum = e.hum
		if not m.Parent or not hum.Parent then
			botSlow[m] = nil
		elseif m:GetAttribute("PracticeBot") == true and script:GetAttribute("HerreraMovesServerBotSlowAttrEnabled") ~= false then -- v1.11: practice bots
			m:SetAttribute("SlowMul_HerreraMoves", e.mul)
			m:SetAttribute("SlowUntil_HerreraMoves", e.untilT)
			if e.set ~= nil and e.base and math.abs(hum.WalkSpeed - e.set) <= 1e-3 then hum.WalkSpeed = e.base end
			botSlow[m] = nil
		else
			local cur = hum.WalkSpeed
			if e.set == nil or math.abs(cur - e.set) > 1e-3 then e.base = cur end
			if t < e.untilT then
				e.set = e.base * math.clamp(e.mul, 0.05, 1)
				hum.WalkSpeed = e.set
				if m:GetAttribute("SmokeSlowed") ~= true then m:SetAttribute("SmokeSlowed", true) end
			else
				hum.WalkSpeed = e.base
				m:SetAttribute("SmokeSlowed", false)
				botSlow[m] = nil
			end
		end
	end
end)

-- Strobe Frill --------------------------------------------------------------------------------------------------------
botHook(strobeRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "strobe", "Strobe", {attack = true})
	if not char then return end
	local strobeWait = STROBE_WINDUP -- v1.5
	if windupsOn() then
		strobeWait = windupTime("strobe")
		char:SetAttribute("StrobeWindupTime", strobeWait)
		count("HerreraMovesWindups")
	end
	char:SetAttribute("StrobeStartedAt", t) -- the rear-up (HerreraMovesPose)
	task.delay(strobeWait, function()
		local root = char.Parent and rootOf(char)
		if not root then return end
		local ta = now()
		local s = char:GetScale()
		local range = math.max(1, num(char, "StrobeRange", 20)) * s
		local half = math.rad(math.clamp(num(char, "StrobeAngle", 60), 1, 359) / 2)
		local face = flat(root.CFrame.LookVector)
		face = face.Magnitude > 1e-3 and face.Unit or Vector3.zAxis
		local daze = math.max(0.1, num(char, "StrobeDaze", 1))
		local dmul = math.max(1, num(char, "StrobeDazedMul", 1))
		local hits = 0
		for _, m in ipairs(candidates(char)) do
			local v = flat(rootOf(m).Position - root.Position)
			local d = (rootOf(m).Position - root.Position).Magnitude
			if d <= range and (v.Magnitude < 1e-3 or math.acos(math.clamp(face:Dot(v.Unit), -1, 1)) <= half) and not shielded(m, ta) then
				local old = num(m, "DazedUntil", 0)
				local keep = old > ta and math.max(1, num(m, "DazedDamageMul", 1)) or 1
				m:SetAttribute("DazedDamageMul", math.max(keep, dmul))
				m:SetAttribute("DazedUntil", math.max(old, ta + daze))
				m:SetAttribute("DazedBy", char.Name)
				m:SetAttribute("DazedAt", ta) -- last: HerreraMovesFX shows the stars
				hits += 1
			end
		end
		char:SetAttribute("StrobeHits", hits)
		char:SetAttribute("StrobeAt", ta) -- last: the flash
		count("StrobeFlashes")
		count("StrobeDazes", hits)
	end)
end)

-- Stun Breaker --------------------------------------------------------------------------------------------------------
local knockParams = RaycastParams.new()
knockParams.FilterType = Enum.RaycastFilterType.Exclude
local function push(src, m, dist, t) -- BoneCrest 1.2 visorKnock's pattern
	local sRoot, mRoot = rootOf(src), rootOf(m)
	if not (sRoot and mRoot) then return false end
	if Players:GetPlayerFromCharacter(m) then
		m:SetAttribute("HeadbuttShoveFrom", sRoot.Position)
		m:SetAttribute("HeadbuttShoveDist", dist)
		m:SetAttribute("HeadbuttShoveTime", BREAK_PUSH_TIME)
		m:SetAttribute("HeadbuttShoveAt", t) -- last: HeadbuttShove 1.0 pushes it
		return true
	elseif m:GetAttribute("PounceLatched") == true then
		m:SetAttribute("ShakeOffReason", "breaker")
		m:SetAttribute("ShakeOffAt", t)
		return true
	elseif mRoot.Anchored then
		return false
	end
	local start = mRoot.Position
	local away = flat(start - sRoot.Position)
	away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
	local land = start + away * dist
	local ex = {src, m}
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	knockParams.FilterDescendantsInstances = ex
	local g0 = workspace:Raycast(start + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), knockParams)
	local lift = g0 and (start.Y - g0.Position.Y) or 3
	local g1 = workspace:Raycast(Vector3.new(land.X, start.Y + 40, land.Z), Vector3.new(0, -140, 0), knockParams)
	local landPos = Vector3.new(land.X, (g1 and g1.Position.Y or (start.Y - lift)) + lift, land.Z)
	local rot = mRoot.CFrame - mRoot.Position
	mRoot.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < BREAK_PUSH_TIME do
			local u = math.clamp((os.clock() - t0) / BREAK_PUSH_TIME, 0, 1)
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
botHook(breakerRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "breaker", "Breaker", {breaker = true})
	if not char then return end
	char:SetAttribute("StunnedUntil", t)
	if char:GetAttribute("PinHeld") == true then
		local by = char:GetAttribute("PinnedBy")
		local pl = typeof(by) == "string" and Players:FindFirstChild(by)
		local pc = pl and pl:IsA("Player") and pl.Character
		if pc then
			pc:SetAttribute("ShakeOffReason", "breaker")
			pc:SetAttribute("ShakeOffAt", t) -- last: PounceServer releases the pin
		else
			char:SetAttribute("PinHeld", nil)
		end
	end
	local pressT = t -- v1.5: free + immune at the press, the push after the wind-up
	if windupsOn() then
		local imm0 = math.max(0, num(char, "BreakerImmune", 0))
		if imm0 > 0 then char:SetAttribute("StunBreakImmuneUntil", pressT + imm0) end
		t = windup(char, "Breaker", "breaker", t)
		if not t then return end
	end
	local s = char:GetScale()
	local dist = math.max(0, num(char, "BreakerPush", 0)) * s
	local n = 0
	if dist > 0 then
		local root = rootOf(char)
		for _, m in ipairs(candidates(char)) do
			if (rootOf(m).Position - root.Position).Magnitude <= dist and not shielded(m, t) and push(char, m, dist, t) then n += 1 end
		end
	end
	local imm = math.max(0, num(char, "BreakerImmune", 0))
	if imm > 0 then char:SetAttribute("StunBreakImmuneUntil", t + imm) end
	if pressT ~= t and imm > 0 then char:SetAttribute("StunBreakImmuneUntil", pressT + imm) end -- v1.5: counted from the press
	char:SetAttribute("BreakerPushed", n)
	char:SetAttribute("BreakerAt", t) -- last: HerreraMovesFX bolts
	count("BreakerBreaks")
end)

-- Glide state ---------------------------------------------------------------------------------------------------------
local function setGliding(char, v)
	if char:GetAttribute("Gliding") == v then return end
	char:SetAttribute("Gliding", v)
	char:SetAttribute(v and "GlideStartedAt" or "GlideEndedAt", now())
end
botHook(glideRemote):Connect(function(player, v)
	local char = player.Character
	if not char or typeof(v) ~= "boolean" then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local ok = v and on("glider") and char:GetAttribute("GliderEnabled") == true and hum ~= nil and hum.Health > 0
	setGliding(char, ok and true or false)
end)
local function onCharacter(char)
	char:GetAttributeChangedSignal("GliderEnabled"):Connect(function()
		if char:GetAttribute("GliderEnabled") ~= true then setGliding(char, false) end
	end)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then hum.Died:Connect(function() setGliding(char, false) end) end
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then task.spawn(onCharacter, p.Character) end
end
-- v1.2: Razor Caltrops ------------------------------------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local caltropRemote, gooRemote = remote("DinoCaltropRequest"), remote("DinoGooRequest")
local patchFolder = ReplicatedStorage:FindFirstChild("CaltropPatches")
if not patchFolder then
	patchFolder = Instance.new("Folder")
	patchFolder.Name = "CaltropPatches"
	patchFolder.Parent = ReplicatedStorage
end
local patches = {} -- [char] = {cfg, spikes = {{pos, used}}, untilT, scale, last = {[model] = t}, player}
local caltropBleeds = {} -- [model] = {untilT, nextTick, char, player, dps}
local function groundBelow(p, depth)
	local hit = workspace:Raycast(p + Vector3.new(0, 20, 0), Vector3.new(0, -(depth or 80), 0), worldExclude())
	return hit and hit.Position or Vector3.new(p.X, p.Y - 3, p.Z)
end
local function spikesJson(pt)
	local list = {}
	for _, sp in ipairs(pt.spikes) do
		table.insert(list, {math.floor(sp.pos.X * 100 + 0.5) / 100, math.floor(sp.pos.Y * 100 + 0.5) / 100,
			math.floor(sp.pos.Z * 100 + 0.5) / 100, sp.used and 1 or 0})
	end
	return HttpService:JSONEncode(list)
end
local function facing(root)
	local f = flat(root.CFrame.LookVector)
	return f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
end
botHook(caltropRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "caltrops", "Caltrop", {})
	if not char then return end
	local root = rootOf(char)
	local s = char:GetScale()
	local old = patches[char]
	if old then old.cfg:Destroy() patches[char] = nil end
	local n = math.clamp(math.floor(num(char, "CaltropCount", 6)), 1, 30)
	local r = math.max(1, num(char, "CaltropRadius", 5)) * s
	local center = root.Position - facing(root) * (r + 4 * s)
	local spikes = {}
	local armOn = script:GetAttribute("HerreraMoves_caltropArmOnLandEnabled") ~= false -- v1.3
	local armGap, armFly = armOn and 0.035 or 0, armOn and 0.42 or 0
	for i = 0, n - 1 do
		local a, d = i * 2.39996, r * math.sqrt((i + 0.5) / n)
		spikes[i + 1] = {pos = groundBelow(center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)), used = false,
			armAt = t + i * armGap + armFly} -- v1.3
	end
	local cfg = Instance.new("Configuration")
	cfg.Name = "Patch_" .. player.UserId
	local pt = {cfg = cfg, spikes = spikes, untilT = t + math.max(1, num(char, "CaltropTime", 8)), scale = s, last = {}, player = player}
	cfg:SetAttribute("Owner", char.Name)
	cfg:SetAttribute("OwnerUserId", player.UserId)
	cfg:SetAttribute("Until", pt.untilT)
	cfg:SetAttribute("Hidden", char:GetAttribute("CaltropHidden") == true)
	cfg:SetAttribute("Scale", s)
	cfg:SetAttribute("Spikes", spikesJson(pt))
	cfg:SetAttribute("DroppedAt", t)
	cfg:SetAttribute("ArmGap", armGap) -- v1.3
	cfg:SetAttribute("ArmFly", armFly)
	cfg.Parent = patchFolder
	patches[char] = pt
	char:SetAttribute("CaltropDroppedAt", t) -- last: HerreraMovesFX rattles the hopper
	count("CaltropDrops")
end)

-- v1.2: Goo Blob Shooter --------------------------------------------------------------------------------------------------
local LIME, LIME_DARK = Color3.fromRGB(166, 226, 46), Color3.fromRGB(95, 143, 18)
local puddles = {} -- {center, radius, untilT, owner, parts}
local function gooFolder()
	local fx = workspace:FindFirstChild("DinoFX")
	if not fx then
		fx = Instance.new("Folder")
		fx.Name = "DinoFX"
		fx.Parent = workspace
	end
	local f = fx:FindFirstChild("GooFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "GooFX"
		f.Parent = fx
	end
	return f
end
local function fxPart(name, shape, size, color, transp)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transp or 0
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	return p
end
local function makePuddle(owner, at, radius, life)
	local f = gooFolder()
	local flatCF = CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local disc = fxPart("GooPuddle", Enum.PartType.Cylinder, Vector3.new(0.25, radius * 2, radius * 2), LIME, 0.3)
	disc.CFrame = flatCF
	local rim = fxPart("GooRim", Enum.PartType.Cylinder, Vector3.new(0.18, radius * 2 + 1, radius * 2 + 1), LIME_DARK, 0.25)
	rim.CFrame = flatCF * CFrame.new(-0.04, 0, 0)
	rim.Parent, disc.Parent = f, f
	local pd = {center = at, radius = radius, untilT = now() + life, owner = owner, parts = {disc, rim}, life = life}
	table.insert(puddles, pd)
	return pd
end
local function flyBlob(char, from, to, glide, radius, life)
	local s = char:GetScale()
	local ball = fxPart("GooBlob", Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4) * s, LIME, 0)
	ball.CFrame = CFrame.new(from)
	ball.Parent = gooFolder()
	local T = (glide and 0.45 or 0.85) / (shotPass() and SHOT_SPEED_MUL or 1) -- v1.9: 1.5x faster
	local peak = math.max(from.Y, to.Y) + 14 * s
	local stopU -- v1.8: the arc fraction where a live Sap Wall stops the blob
	do
		local w, wu = sapArcBlocked(from, to, glide and 0 or (peak - (from.Y + to.Y) / 2))
		if w then stopU = wu or 0 end
	end
	local t0 = os.clock()
	while true do
		local u = math.min(stopU or 1, (os.clock() - t0) / T)
		local p = from:Lerp(to, u)
		if not glide then
			-- parabola through from, peak, to (y only)
			local y0, y1 = from.Y, to.Y
			p = Vector3.new(p.X, y0 + (y1 - y0) * u + 4 * (peak - (y0 + y1) / 2) * u * (1 - u), p.Z)
		end
		ball.CFrame = CFrame.new(p)
		if u >= (stopU or 1) then break end
		RunService.Heartbeat:Wait()
	end
	ball:Destroy()
	if stopU then char:SetAttribute("GooWallAt", now()) return end -- v1.8
	makePuddle(char, to, radius, life)
end
botHook(gooRemote):Connect(function(player, stamp)
	local char, t = check(player, stamp, "goo", "Goo", {})
	if not char then return end
	t = windup(char, "Goo", "goo", t) -- v1.5
	if not t then return end
	local root = rootOf(char)
	local s = char:GetScale()
	local fwd = facing(root)
	local glide = char:GetAttribute("Gliding") == true
	local land, target
	if glide then
		land = groundBelow(root.Position, 600)
	else
		if script:GetAttribute("HerreraMoves_gooAssistEnabled") ~= false then
			local cosA = math.cos(math.rad(num(char, "GooAssistAngle", 30)))
			local lo, hi = num(char, "GooAssistMin", 15) * s, num(char, "GooAssistMax", 45) * s
			local bestD
			for _, m in ipairs(candidates(char)) do
				local v = flat(rootOf(m).Position - root.Position)
				local d = v.Magnitude
				if d >= lo and d <= hi and v.Unit:Dot(fwd) >= cosA and (not bestD or d < bestD) then target, bestD = m, d end
			end
		end
		land = groundBelow((target and rootOf(target).Position) or (root.Position + fwd * num(char, "GooToss", 30) * s))
	end
	local radius = math.max(1, num(char, "GooRadius", 8)) * s
	local life = math.max(0.5, num(char, "GooTime", 5))
	local pts = {land}
	if math.floor(num(char, "GooCount", 1)) >= 2 then
		local right = fwd:Cross(Vector3.yAxis)
		pts = {groundBelow(land + right * radius * 0.85), groundBelow(land - right * radius * 0.85)}
	end
	local hump = char:FindFirstChild("Torso_hump", true)
	local from = hump and hump:IsA("BasePart") and (hump.Position + Vector3.new(0, 2 * s, 0)) or (root.Position + Vector3.new(0, 3 * s, 0))
	if script:GetAttribute("HerreraMoves_gooMuzzleEnabled") ~= false then -- v1.4: out of the Spit Sacs' jaw nozzle
		local gm = char:FindFirstChild("HPart_goo")
		if gm then
			for _, p in ipairs(gm:GetChildren()) do
				if p:IsA("BasePart") and p:GetAttribute("HPartRole") == "muzzle" then
					from = p.Position
					script:SetAttribute("GooMuzzleShots", (script:GetAttribute("GooMuzzleShots") or 0) + 1)
					break
				end
			end
		end
	end
	for i, pt in ipairs(pts) do
		task.delay((i - 1) * 0.12, flyBlob, char, from, pt, glide, radius, life)
	end
	char:SetAttribute("GooLand", land)
	char:SetAttribute("GooAssistTarget", target and target.Name or "")
	char:SetAttribute("GooFiredAt", t) -- last: HerreraMovesFX kicks the mortar
	count("GooShots")
end)

-- v1.2: caltrop triggers / bleeds and goo slows ---------------------------------------------------------------------------
local p3Acc, gooAcc = 0, 0
if script:GetAttribute("HerreraMoves_gooLinger") == nil then script:SetAttribute("HerreraMoves_gooLinger", 3) end -- v1.6
local function slowTarget(m, prefix, mul, untilT)
	if Players:GetPlayerFromCharacter(m) then
		m:SetAttribute(prefix .. "SlowMul", mul)
		m:SetAttribute(prefix .. "SlowUntil", untilT)
	else
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then
			local e = botSlow[m] or {hum = hum}
			e.untilT, e.mul = math.max(e.untilT or 0, untilT), mul
			botSlow[m] = e
		end
	end
end
local function scaleOf(m)
	local ok, v = pcall(function() return m:GetScale() end)
	return ok and v or 1
end
RunService.Heartbeat:Connect(function(dt)
	p3Acc += dt
	gooAcc += dt
	local t = now()
	if p3Acc >= 0.1 then
		p3Acc = 0
		for char, pt in pairs(patches) do
			local live = char.Parent and t < pt.untilT and on("caltrops") and char:GetAttribute("CaltropEnabled") == true
			if not live then
				pt.cfg:Destroy()
				patches[char] = nil
			else
				local changed = false
				for _, m in ipairs(candidates(char)) do
					local root = rootOf(m)
					if t - (pt.last[m] or -9) >= 0.35 and not shielded(m, t) then
						local reach = 1.6 * pt.scale + 1.5 * scaleOf(m)
						for _, sp in ipairs(pt.spikes) do
							if not sp.used and t >= (sp.armAt or 0) and flat(root.Position - sp.pos).Magnitude <= reach -- v1.3: armAt
								and math.abs(root.Position.Y - sp.pos.Y) <= 12 * pt.scale and not sapBlocked(sp.pos + Vector3.yAxis * 2, m) then
								sp.used, changed = true, true
								pt.last[m] = t
								local bt = math.max(0.5, num(char, "CaltropBleedTime", 3))
								caltropBleeds[m] = {untilT = t + bt, nextTick = t, char = char, player = pt.player,
									dps = math.max(0, num(char, "CaltropBleedDps", 3))}
								m:SetAttribute("CaltropBleedUntil", t + bt)
								m:SetAttribute("CaltropBleedBy", char.Name)
								slowTarget(m, "Caltrop", math.clamp(num(char, "CaltropSlowMul", 0.7), 0.05, 1), t + num(char, "CaltropSlowTime", 1))
								m:SetAttribute("CaltropHitAt", t) -- last
								char:SetAttribute("CaltropHits", (char:GetAttribute("CaltropHits") or 0) + 1)
								count("CaltropTriggers")
								break
							end
						end
					end
				end
				if changed then pt.cfg:SetAttribute("Spikes", spikesJson(pt)) end
			end
		end
		for m, b in pairs(caltropBleeds) do
			if not m.Parent or m:GetAttribute("DummyState") == "ko" or b.nextTick >= b.untilT - 1e-3 then
				caltropBleeds[m] = nil
			elseif t >= b.nextTick then
				local d = math.floor(b.dps * takenMul(m, t) * 10 + 0.5) / 10
				if d > 0 and b.player.Parent then takeHealth(m, d, b.char, b.player, "caltrops", t) end
				m:SetAttribute("CaltropBleedTickAt", t)
				b.nextTick += 1
			end
		end
	end
	if gooAcc >= 0.2 then
		gooAcc = 0
		for i = #puddles, 1, -1 do
			local pd = puddles[i]
			local left = pd.untilT - t
			if left <= 0 or not on("goo") then
				for _, part in ipairs(pd.parts) do part:Destroy() end
				table.remove(puddles, i)
			else
				if left < 0.6 then
					for _, part in ipairs(pd.parts) do part.Transparency = 1 - (1 - 0.3) * (left / 0.6) end
				end
				if pd.owner.Parent then
					local mul = math.clamp(num(pd.owner, "GooSlowMul", 0.6), 0.05, 1)
					local s = scaleOf(pd.owner)
					for _, m in ipairs(candidates(pd.owner)) do
						local r = rootOf(m).Position
						if flat(r - pd.center).Magnitude <= pd.radius and math.abs(r.Y - pd.center.Y) <= 10 * s and not sapBlocked(pd.center + Vector3.yAxis * 2, m) then
							if script:GetAttribute("HerreraMoves_gooLingerEnabled") ~= false then -- v1.6: 3 s after leaving
								local untilG = t + math.clamp(tonumber(script:GetAttribute("HerreraMoves_gooLinger")) or 3, 0.3, 10)
								slowTarget(m, "Goo", mul, untilG)
								if not Players:GetPlayerFromCharacter(m) then
									m:SetAttribute("GooSlowMul", mul)
									m:SetAttribute("GooSlowUntil", untilG)
								end
								count("GooSlowTicks")
							else
								slowTarget(m, "Goo", mul, t + 0.3)
							end
						end
					end
				end
			end
		end
	end
end)

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- v1.12: the bot entrance (see the header)
if script:GetAttribute("HerreraMovesServerBotMechaEnabled") == nil then script:SetAttribute("HerreraMovesServerBotMechaEnabled", true) end
do
	local proxyModule = game:GetService("ServerStorage"):WaitForChild("DinoArcade"):FindFirstChild("BotProxy")
	local BotProxy = proxyModule and require(proxyModule)
	local fn = script:FindFirstChild("BotMechaUse") or Instance.new("BindableFunction")
	fn.Name = "BotMechaUse"
	fn.OnInvoke = function(model, remoteName, ...)
		if script:GetAttribute("HerreraMovesServerBotMechaEnabled") == false then return "off" end
		if not BotProxy or typeof(model) ~= "Instance" or model:GetAttribute("PracticeBot") ~= true or not model.Parent then return "badArg" end
		local list = __botHandlers[remoteName]
		if not list then return "noHandler" end
		local proxy = BotProxy.of(model)
		for _, h in ipairs(list) do
			local ok, err = pcall(h, proxy, ...)
			if not ok then
				script:SetAttribute("HerreraMovesServerBotMechaError", tostring(remoteName) .. ": " .. tostring(err))
				return "botUnsupported"
			end
		end
		return "ok"
	end
	fn.Parent = script
end
script:SetAttribute("HerreraMovesServerVersion", "1.12") -- v1.12 bot entrance
