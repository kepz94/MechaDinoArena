-- PracticeKit v1.1 (Mecha Dino Arena) — practice bots use their mecha parts (ModuleScript, child of PracticeServer). MDA-472,
-- plan docs/plans/BOTS_V2_v1.0.md T8; Kepu 2026-11-11 20:39 "the damn bots don't even use their attack buttons or their mecha.
-- You need to have them use that shit like raptors using their mobility to fly over dashing and Troodon too".
-- How a part fires: the part's server has a bot entrance (BotMechaUse, MDA-471): Invoke(model, remoteName, ...the remote's own
--   arguments...) runs that server's real handler with the bot as the player. SkillEffects 1.61 gives the bot the same part
--   attributes as a player's character, so the real checks (enabled, cooldowns, charges) decide.
-- PARTS[id] = {remote, server, kind (PracticeRules 1.2 abilityWant kind), args ("stamp" / "dir" / "dirPoint" / "move" / "held" /
--   "land"), minR, maxR, radius, move (a bot move after an accepted use: "dash" / "leap" / "lerp" / "portal" / "boost"), cd (s
--   to wait after a use when no part cooldown can be read)}. Parts left out (not bot buttons): bloodrush, mechalegs (fired by
--   the attack / jump), glider (a held glide), breaker (pressed while stunned).
-- Accepted = a "...Result" attribute the handler wrote this call reads one of OK_RESULTS (ok, placing, hit, dash, zip, miss,
--   missed, fired, placed, open, landed, used, latched, on, onJump); when the handler wrote no "...Result", any attribute change
--   counts. Refused -> that part waits RETRY (2) s.
-- Studio check 2026-11-11 (all 51 parts on a bot vs a target bot): every part answers "ok" through its bot entrance except
--   hookarm (HookEnabled stays false: SkillTree's Therizino overlay sets e.hookRange = 0 for every other dino, players too ->
--   BROKEN, left out of bot loadouts; reported to Kepu), tgrab "noTarget" at 25 studs (needs 8), tleap "onJump" (armed until
--   the next jump: the bot jumps, then leaps).
-- think(b, ctx, info) -> true when a part was used this tick (the brain then skips its move). At most one part per
--   tier.abilDelay s; parts in a random order; want = PracticeRules.abilityWant(kind, info + the part's ranges); used when
--   rng < want x tier.abil. A mobility part also counts as wanted while info.wantMobility (the brain's stuck ladder step 3).
--   Aim: faces the target with the tier's aim error (lead for tier.lead) before firing; dir = the 3D unit vector to the
--   target's root (else the flat look); point = the target's root (else 40 studs ahead / the goal for a mobility part).
-- Bot moves (bots are moved by the server; players' clients move themselves):
--   dash   thrusters (DashDistance (40) over DashTime (0.6 s, at most 1.2), hop DashHop (8)), zgrapple (TheriGrappleRange (45)
--          over TheriGrappleTime (0.35)): the root's velocity is held along the direction each frame for the time.
--   lerp   djets: from DiloJetsFrom to DiloJetsTo after DiloJetsDelay over DiloJetsTime (anchored, like the dash slash).
--   leap   tleap: an arc of TenoLeapDistNow / TenoLeapDist (40) studs along the direction, 14 studs up, 0.8 s.
--   boost  servodash: velocity WalkSpeed x ServoDashSpeedMul (1.8) along the direction for ServoDashTime (0.6) s.
--   portal oportal: after 0.8 s the bot is moved to the aim point (the portal server moves players only).
--   The move direction: toward the target (fight) or the goal (else; the next path waypoint when the brain has one).
-- prepareSpec(spec, rng) -> spec with steps + loadout re-rolled so its slots hold parts from PARTS for its dino (a mobility
--   part first when the dino has one, PracticeRules 1.2 pickLoadout), its level's other points at random as before; marked
--   spec.kitReady. onSpawn(rec, model) resets the kit's per-life state.
-- Async fire (found in the Studio match test 2026-11-11: a part's Invoke yields (the bot entrance's first-use 0.2 s wait, some
--   handlers wait too), and a fire inside think held the whole bot tick: PrServerMs 230-350 ms about every 4 s, every bot
--   stalled): the chosen part fires on its own thread (task.spawn); think returns false at once and fires nothing more for that
--   bot until the result is in (k.pending); the result sets the cooldown as before (used -> p.cd, else RETRY). A move part sets
--   b.busy when it starts, so the brain stops steering then. A Lua error in a fire -> PracticeServer attribute PrKitError.
--   Switch: PracticeServer attribute PrKitAsyncEnabled (default true, read per fire; false = the waiting fire above).
-- v1.1 (2026-11-12, Kepu "Fix it" on #36): SkillTree 1.90 gives the pachy its hook back, so hookarm is in bot loadouts again
--   while SkillTree.HOOK_KEEP_OTHERS is on (off -> left out, as 1.0).
-- Model attributes: BotLastPart ("<id> <result>"), BotPartsUsed (count), BotPartsTried.
-- Switch: PracticeServer's PrKitEnabled (read per tick there); script attribute KIT_OFF list in PracticeServer attribute
--   PrKitDeny (comma list of part ids bots must not use, default "").
-- v1.2 (Kepu 2026-11-12 18:05 "Why are you not having dinos use all their abilities", 18:06 "Dino's should be using all their
--   abilities including their main attack"; Studio match 60 s: 1-3 part uses a bot a minute, Easy Herrera none): a part was
--   used only when PracticeRules.abilityWant said so (narrow: defend only hurt + just hit, heal under half HP, buff within 20,
--   stealth under 40% HP, ...) AND a roll under want x tier.abil (Easy 0.15) passed. Now, in a fight, every slot part is used
--   the moment it is ready and its target is in its range, with no roll: want = the 1.0 want, or (with a target) ranged /
--   melee / control within its maxR, aoe within its radius + 6, defend / buff / zone / trap within 35 studs (gap), heal under
--   85% HP or a mate low, stealth within 90, sense any time, mobility when the gap is over 25 (closing in) as well as 1.0's
--   cases. Still one part per tier.abilDelay s and the part's own cooldown. Switch: PracticeServer attribute PrKitAllEnabled
--   (default true, read per think; false = 1.1).
-- v1.3 (Kepu 2026-11-12 18:06 "Dino's should be using all their abilities"; pick "Yes, add all 4"): the 4 parts 1.0 left out
--   join bot loadouts (PARTS, so liveFor can roll them):
--   * bloodrush (Pachy, kind "passive"): never fired here; it works through the main attack (HeadbuttServer pays the HP for
--     one more headbutt when out of charges, as for a player).
--   * mechalegs (Pachy, mobility, in MOBILITY): fires the leap through JumpServer 1.7's bot entrance (DinoJumpRequest), then
--     the bot move "mleap": up at the model's JumpLaunchPower (Mecha Legs raises it), forward at WalkSpeed + JumpBoost, for the
--     flight time (2 x up / gravity, 0.5..2 s).
--   * glider (Herrera, kind "glide"): M.air(b) each brain tick: in the air, falling faster than GLIDE_START (14) studs/s and the
--     ground more than GLIDE_HEIGHT (12) studs below the feet (Studio: without it a bot glided off every small ledge, 14 times in
--     a minute) ->
--     DinoGlideRequest(true) (HerreraMovesServer's bot entrance); while the model's Gliding is true, every frame the fall is held
--     to GliderFall (8) studs/s and the body keeps its run speed along its move direction; on the ground -> (false).
--   * breaker (Herrera, kind "breaker"): M.breakFree(b, ctx) when the bot is stunned or pinned (the brain calls it before it
--     skips the tick): DinoBreakerRequest(stamp) through HerreraMovesServer's bot entrance.
--   think() never picks passive / glide / breaker (their want is 0). Switch: PracticeServer attribute PrKitLast4Enabled (default
--   true, read per use; false = these 4 are denied like PrKitDeny, = 1.2).
-- v1.4 (Elite combos, MDA-498; Kepu 2026-11-13 "let's do 1,2&5" -> 2 = Elite bot combos, pick "By ability type"): bots whose
--   tier has combo = true (PracticeRules: Elite only) chain a setup part into payoffs. Same parts, same cooldowns, same entrances.
--   * Setup: a part of kind "control" (stun, grab, hook, sleep, tether, challenge) or "mobility" used with a target (closing in).
--     When a setup part is ready and a payoff is ready (a "ranged" / "aoe" part off cooldown, or the main attack ready within
--     1 s: b.nextAttack), the ready setup parts go first this think (the other parts keep their random order behind them).
--   * Window: a used setup opens a combo window of PracticeServer attribute PrComboWindow (2) s and clears the tier's
--     abilDelay wait. In the window only payoff parts are tried, each the moment it is ready and in range (no abilDelay):
--     after "control": "ranged" / "aoe"; after "mobility": "ranged" / "aoe" / "control". The main attack needs no change: the
--     brain (PracticeBrain2 2.5) already fires it first whenever it is ready and in reach.
--   * Async fire (1.0): the window opens when the fire's result comes back "used".
--   Model attributes: BotCombos (setups that opened a window), BotComboHits (payoff parts used in a window), BotComboLast
--   ("<setup> >" / "<setup> > <payoff>"). Switch: PracticeServer attribute PrKitCombosEnabled (default true, read per think;
--   false = 1.3).
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local M = {}
M.Version = "1.0"
M.Version = "1.2" -- v1.2 every part, no roll (1.1 = hookarm back)
M.Version = "1.3" -- v1.3 Blood Rush, Mecha Legs, Glider, Stun Breaker
M.Version = "1.4" -- v1.4 Elite combos

local RETRY = 2
local OK_RESULTS = {ok = true, placing = true, hit = true, dash = true, zip = true, miss = true, missed = true, fired = true,
	placed = true, open = true, landed = true, used = true, latched = true, on = true, onJump = true}
local BROKEN = {hookarm = true} -- see the header (Studio check 2026-11-11)
local deps = {}

M.PARTS = {
	-- Raptor
	thrusters = {remote = "DinoDashRequest", server = "MechaServer", kind = "mobility", args = "stamp", maxR = 140, move = "dash", cd = 6},
	cloak = {remote = "DinoCloakRequest", server = "CloakServer", kind = "stealth", args = "stamp", cd = 12},
	screech = {remote = "DinoScreechRequest", server = "ScreechServer", kind = "ranged", args = "held", minR = 0, maxR = 60, cd = 8},
	shield = {remote = "DinoEnergyShieldRequest", server = "EnergyShieldServer", kind = "defend", args = "stamp", cd = 12},
	adrenaline = {remote = "DinoAdrenalineRequest", server = "AdrenalineServer", kind = "buff", args = "stamp", cd = 15},
	scent = {remote = "DinoScentRequest", server = "ScentServer", kind = "sense", args = "stamp", cd = 15},
	traps = {remote = "DinoMineRequest", server = "MineServer", kind = "trap", args = "stamp", cd = 8},
	-- Troodon
	omender = {remote = "DinoTrooMenderRequest", server = "TrooMovesServer", kind = "heal", args = "stamp", cd = 12},
	olantern = {remote = "DinoTrooLanternRequest", server = "TrooMovesServer", kind = "ranged", args = "dirPoint", minR = 0, maxR = 55, cd = 8},
	osapwall = {remote = "DinoTrooSapRequest", server = "TrooMovesServer", kind = "zone", args = "dirPoint", cd = 12},
	oshed = {remote = "DinoTrooShedRequest", server = "TrooMovesServer", kind = "defend", args = "stamp", cd = 12},
	oportal = {remote = "DinoTrooPortalRequest", server = "TrooMovesServer", kind = "mobility", args = "dirPoint", maxR = 90, move = "portal", cd = 12},
	oburst = {remote = "DinoTrooBurstRequest", server = "TrooSlotServer", kind = "heal", args = "dirPoint", cd = 12},
	odome = {remote = "DinoTrooDomeRequest", server = "TrooSlotServer", kind = "defend", args = "dirPoint", cd = 15},
	osleep = {remote = "DinoTrooSleepRequest", server = "TrooSlotServer", kind = "control", args = "dir", maxR = 60, cd = 10},
	osentry = {remote = "DinoTrooSentryRequest", server = "TrooSlotServer", kind = "zone", args = "dirPoint", cd = 15},
	-- Dilo
	dgatling = {remote = "DinoDiloGatlingRequest", server = "DiloMovesServer", kind = "ranged", args = "dir", minR = 0, maxR = 50, cd = 8},
	dmortar = {remote = "DinoDiloMortarRequest", server = "DiloMovesServer", kind = "ranged", args = "dirPoint", minR = 18, maxR = 90, cd = 8},
	dspine = {remote = "DinoDiloSpineRequest", server = "DiloMovesServer", kind = "aoe", args = "stamp", radius = 16, cd = 10},
	dover = {remote = "DinoDiloOverRequest", server = "DiloMovesServer", kind = "buff", args = "stamp", cd = 15},
	dhiss = {remote = "DinoDiloHissRequest", server = "DiloMovesServer", kind = "aoe", args = "stamp", radius = 20, cd = 12},
	dpump = {remote = "DinoDiloPumpRequest", server = "DiloMovesServer", kind = "heal", args = "stamp", cd = 15},
	djets = {remote = "DinoDiloJetsRequest", server = "DiloMovesServer", kind = "mobility", args = "move", maxR = 60, move = "lerp", cd = 5},
	-- Teno
	tgrab = {remote = "DinoTenoGrabRequest", server = "TenoMovesServer", kind = "control", args = "stamp", maxR = 8, cd = 10},
	tmortar = {remote = "DinoTenoMortarRequest", server = "TenoMovesServer", kind = "ranged", args = "dirPoint", minR = 18, maxR = 90, cd = 8},
	tstomp = {remote = "DinoTenoStompRequest", server = "TenoMovesServer", kind = "aoe", args = "stamp", radius = 18, cd = 10},
	tleap = {remote = "DinoTenoLeapRequest", server = "TenoMovesServer", kind = "mobility", args = "stamp", maxR = 60, move = "leap", cd = 8},
	tbellow = {remote = "DinoTenoBellowRequest", server = "TenoMovesServer", kind = "buff", args = "stamp", cd = 15},
	tchallenge = {remote = "DinoTenoChallengeRequest", server = "TenoMovesServer", kind = "control", args = "stamp", maxR = 30, cd = 15},
	tmud = {remote = "DinoTenoMudRequest", server = "TenoMovesServer", kind = "defend", args = "stamp", cd = 15},
	-- Therizino
	zhook = {remote = "DinoTheriHookRequest", server = "TheriMovesServer", kind = "control", args = "dir", maxR = 45, cd = 10},
	zfeather = {remote = "DinoTheriFeatherRequest", server = "TheriMovesServer", kind = "ranged", args = "dir", minR = 0, maxR = 55, cd = 8},
	zharvest = {remote = "DinoTheriFieldRequest", server = "TheriMovesServer", kind = "aoe", args = "stamp", radius = 18, cd = 12},
	zsnare = {remote = "DinoTheriSnareRequest", server = "TheriMovesServer", kind = "trap", args = "dir", cd = 10},
	zgrapple = {remote = "DinoTheriGrappleRequest", server = "TheriMovesServer", kind = "mobility", args = "move", maxR = 60, move = "dash", cd = 5},
	zdeflect = {remote = "DinoTheriDeflectRequest", server = "TheriMovesServer", kind = "defend", args = "stamp", cd = 10},
	zclock = {remote = "DinoTheriClockRequest", server = "TheriMovesServer", kind = "buff", args = "stamp", cd = 15},
	-- Herrera
	quills = {remote = "DinoQuillRequest", server = "HerreraMovesServer", kind = "ranged", args = "dir", minR = 0, maxR = 55, cd = 8},
	smoke = {remote = "DinoSmokeRequest", server = "HerreraMovesServer", kind = "stealth", args = "stamp", cd = 12},
	strobe = {remote = "DinoStrobeRequest", server = "HerreraMovesServer", kind = "aoe", args = "stamp", radius = 20, cd = 12},
	caltrops = {remote = "DinoCaltropRequest", server = "HerreraMovesServer", kind = "trap", args = "stamp", cd = 10},
	goo = {remote = "DinoGooRequest", server = "HerreraMovesServer", kind = "ranged", args = "stamp", minR = 0, maxR = 45, cd = 8},
	hadren = {remote = "DinoAdrenalineRequest", server = "AdrenalineServer", kind = "buff", args = "stamp", cd = 15},
	-- Pachy
	hookarm = {remote = "DinoHookRequest", server = "HookServer", kind = "control", args = "dir", maxR = 55, cd = 10},
	ink = {remote = "DinoInkRequest", server = "InkServer", kind = "ranged", args = "dir", minR = 0, maxR = 45, cd = 10},
	tether = {remote = "DinoTetherRequest", server = "TetherServer", kind = "control", args = "land", maxR = 45, cd = 12},
	servodash = {remote = "DinoServoDashRequest", server = "ServoDashServer", kind = "mobility", args = "stamp", maxR = 80, move = "boost", cd = 6},
	visor = {remote = "DinoVisorRequest", server = "VisorServer", kind = "defend", args = "stamp", cd = 12},
	medstation = {remote = "DinoMedRequest", server = "MedStationServer", kind = "heal", args = "stamp", cd = 15},
}
M.MOBILITY = {"thrusters", "oportal", "djets", "tleap", "zgrapple", "servodash"}
-- v1.3: the last 4 parts (see the header)
M.LAST4 = {
	bloodrush = {server = "HeadbuttServer", kind = "passive", cd = 99},
	mechalegs = {remote = "DinoJumpRequest", server = "JumpServer", kind = "mobility", args = "stamp", maxR = 70, move = "mleap", cd = 6},
	glider = {remote = "DinoGlideRequest", server = "HerreraMovesServer", kind = "glide", cd = 1},
	breaker = {remote = "DinoBreakerRequest", server = "HerreraMovesServer", kind = "breaker", args = "stamp", cd = 14},
}
for id, p in pairs(M.LAST4) do M.PARTS[id] = p end
table.insert(M.MOBILITY, "mechalegs")
local GLIDE_START = 14
local GLIDE_HEIGHT = 12
local glideRay = RaycastParams.new()
glideRay.FilterType = Enum.RaycastFilterType.Include
local function dropBelow(b)
	local island = workspace:FindFirstChild("DinoIsland")
	if not island then return math.huge end
	local list = {}
	for _, n in ipairs({"Ground", "MountainSteps", "Rocks"}) do local f = island:FindFirstChild(n) if f then table.insert(list, f) end end
	glideRay.FilterDescendantsInstances = list
	local feet = b.hrp.Position - Vector3.new(0, b.hrp.Size.Y / 2 + b.hum.HipHeight, 0)
	local hit = workspace:Raycast(feet, Vector3.new(0, -200, 0), glideRay)
	return hit and (feet.Y - hit.Position.Y) or math.huge
end

local function now() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m and m:FindFirstChild("HumanoidRootPart") end

local function denied(id)
	local ps = ServerScriptService:FindFirstChild("PracticeServer")
	if M.LAST4[id] and ps and ps:GetAttribute("PrKitLast4Enabled") == false then return true end -- v1.3
	local list = ps and ps:GetAttribute("PrKitDeny")
	if type(list) ~= "string" or list == "" then return false end
	for x in string.gmatch(list, "[^,%s]+") do if x == id then return true end end
	return false
end

local function asyncOn()
	local ps = ServerScriptService:FindFirstChild("PracticeServer")
	return not (ps and ps:GetAttribute("PrKitAsyncEnabled") == false)
end

-- v1.2: every part in a fight (see the header)
local function allOn()
	local ps = ServerScriptService:FindFirstChild("PracticeServer")
	return not (ps and ps:GetAttribute("PrKitAllEnabled") == false)
end
local function wantAll(R, kind, w)
	local base = R.abilityWant(kind, w)
	local has = w.hasTarget == true
	local gap = tonumber(w.gap) or math.huge
	local hp = tonumber(w.hpFrac) or 1
	local more = 0
	if kind == "ranged" or kind == "melee" or kind == "control" then
		if has and gap <= (tonumber(w.maxR) or 0) then more = 1 end
	elseif kind == "aoe" then
		if has and gap <= (tonumber(w.radius) or 0) + 6 then more = 1 end
	elseif kind == "defend" or kind == "buff" or kind == "zone" or kind == "trap" then
		if has and gap <= 35 then more = 1 end
	elseif kind == "heal" then
		if hp < 0.85 or w.mateLow == true then more = 1 end
	elseif kind == "stealth" then
		if has and gap <= 90 then more = 1 end
	elseif kind == "sense" then
		more = 1
	elseif kind == "mobility" then
		if has and gap > 25 and gap <= (tonumber(w.maxR) or 140) then more = 1 end
	end
	return math.max(base, more)
end

-- ---------- loadouts ----------
function M.liveFor(species, SkillTree)
	local out = {}
	for id in pairs(M.PARTS) do
		local p = SkillTree and SkillTree.PATHS[id]
		if p and not p.soon and SkillTree.LIVE_MECH[id] and SkillTree.BUTTONS[id] and SkillTree.seesPath(p, species) and not denied(id)
			and not (BROKEN[id] and not (id == "hookarm" and SkillTree.HOOK_KEEP_OTHERS)) then -- v1.1
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

function M.prepareSpec(spec, rng)
	local ST, R = deps.SkillTree, deps.R
	if not (ST and R and R.pickLoadout) or type(spec) ~= "table" or spec.kitReady then return spec end
	local species = spec.species
	local live = M.liveFor(species, ST)
	local chosen = R.pickLoadout(live, M.MOBILITY, ST.SLOTS or 4, rng)
	local points = ST.pointsOf(R.BOT_LEVEL or 30)
	local steps = ST.sanitize({}, species)
	local slotted = {}
	for _, id in ipairs(chosen) do
		local new = ST.buy(steps, id, points, species)
		if new then steps = new table.insert(slotted, id) end
	end
	local ids = {}
	for _, id in ipairs(ST.PATH_ORDER) do if ST.seesPath(id, species) then table.insert(ids, id) end end
	for _ = 1, 200 do
		local can = {}
		for _, id in ipairs(ids) do if ST.canBuy(steps, id, points, species) then table.insert(can, id) end end
		if #can == 0 then break end
		steps = ST.buy(steps, can[rng:NextInteger(1, #can)], points, species)
	end
	local loadout = {}
	for n = 1, ST.SLOTS or 4 do loadout[n] = false end
	for n, id in ipairs(slotted) do
		local out = ST.setSlot(loadout, steps, n, id, species)
		if out then loadout = out end
	end
	local copy = table.clone(spec)
	copy.steps, copy.loadout, copy.kitReady = steps, loadout, true
	return copy
end

function M.onSpawn(rec, model)
	rec.kit = nil
end

-- ---------- firing ----------
local function entrance(server)
	local s = ServerScriptService:FindFirstChild(server)
	return s and s:FindFirstChild("BotMechaUse")
end

local function snapshot(model)
	local out = {}
	for k, v in pairs(model:GetAttributes()) do
		if string.sub(k, 1, 3) ~= "Bot" then out[k] = v end
	end
	return out
end

local function changed(before, model)
	local any, sawResult, good = false, false, false
	for k, v in pairs(model:GetAttributes()) do
		if string.sub(k, 1, 3) ~= "Bot" and before[k] ~= v then
			any = true
			if string.sub(k, -6) == "Result" then
				sawResult = true
				if OK_RESULTS[tostring(v)] then good = true end
			end
		end
	end
	if sawResult then return good end
	return any
end

local function moveDir(b, info)
	local p = b.hrp.Position
	local to
	if info.target and rootOf(info.target) then
		to = rootOf(info.target).Position
	elseif b.v2 and b.v2.path and b.v2.wp and b.v2.path[b.v2.wp + 2] then
		to = b.v2.path[b.v2.wp + 2].Position
	elseif info.goal then
		to = info.goal
	end
	local d = to and flat(to - p) or flat(b.hrp.CFrame.LookVector)
	if d.Magnitude < 1e-3 then d = flat(b.hrp.CFrame.LookVector) end
	if d.Magnitude < 1e-3 then d = Vector3.new(0, 0, -1) end
	return d.Unit, to
end

local function faceDir(b, dir)
	local p = b.hrp.Position
	b.hrp.CFrame = CFrame.lookAt(p, p + Vector3.new(dir.X, 0, dir.Z))
end

local function aimAt(b, info, R, rng, tier)
	local t = info.target and rootOf(info.target)
	local p = b.hrp.Position
	if not t then
		local d = flat(b.hrp.CFrame.LookVector)
		d = d.Magnitude > 1e-3 and d.Unit or Vector3.new(0, 0, -1)
		return d, p + d * 40
	end
	local at = t.Position
	if tier.lead then at += flat(t.AssemblyLinearVelocity) * math.clamp(flat(at - p).Magnitude / 90, 0, 0.8) end
	local yaw = math.rad(R.aimError(rng, tier))
	local d = at - p
	local fd = flat(d)
	if fd.Magnitude < 1e-3 then fd = flat(b.hrp.CFrame.LookVector) end
	local rotated = (CFrame.Angles(0, yaw, 0) * CFrame.lookAt(Vector3.zero, fd.Unit)).LookVector
	faceDir(b, rotated)
	local dir3 = (Vector3.new(rotated.X * fd.Magnitude, d.Y, rotated.Z * fd.Magnitude))
	dir3 = dir3.Magnitude > 1e-3 and dir3.Unit or rotated
	return dir3, p + dir3 * d.Magnitude
end

local function holdVelocity(b, vel, time, upFirst)
	local hrp = b.hrp
	local t0 = os.clock()
	local first = true
	while os.clock() - t0 < time and hrp.Parent do
		local v = hrp.AssemblyLinearVelocity
		local vy = v.Y
		if first and upFirst then vy = upFirst first = false end
		hrp.AssemblyLinearVelocity = Vector3.new(vel.X, vy, vel.Z)
		RunService.Heartbeat:Wait()
	end
end

local function doMove(b, p, info, dir, point)
	local m = b.model
	if p.move == "dash" then
		local dist, time, hop
		if p.remote == "DinoDashRequest" then
			dist = tonumber(m:GetAttribute("DashDistance")) or 40
			time = math.clamp(tonumber(m:GetAttribute("DashTime")) or 0.6, 0.2, 1.2)
			hop = tonumber(m:GetAttribute("DashHop")) or 8
		else
			dist = math.min(tonumber(m:GetAttribute("TheriGrappleRange")) or 45, 60)
			time = math.clamp(tonumber(m:GetAttribute("TheriGrappleTime")) or 0.35, 0.15, 0.8)
			hop = 4
		end
		holdVelocity(b, dir * (dist / time), time, math.sqrt(2 * workspace.Gravity * math.max(hop, 1)))
	elseif p.move == "boost" then
		local mul = tonumber(m:GetAttribute("ServoDashSpeedMul")) or 1.8
		local time = math.clamp(tonumber(m:GetAttribute("ServoDashTime")) or 0.6, 0.2, 1.5)
		holdVelocity(b, dir * b.hum.WalkSpeed * mul, time)
	elseif p.move == "mleap" then -- v1.3: Mecha Legs' leap
		local up = math.clamp(tonumber(m:GetAttribute("JumpLaunchPower")) or 64, 30, 160)
		local fwd = b.hum.WalkSpeed + (tonumber(m:GetAttribute("JumpBoost")) or 14)
		local flight = math.clamp(2 * up / workspace.Gravity, 0.5, 2)
		b.hum.Jump = true
		holdVelocity(b, dir * fwd, flight, up)
	elseif p.move == "leap" then
		local dist = tonumber(m:GetAttribute("TenoLeapDistNow")) or tonumber(m:GetAttribute("TenoLeapDist")) or 40
		b.hum.Jump = true
		holdVelocity(b, dir * (dist / 0.8), 0.8, math.sqrt(2 * workspace.Gravity * 14))
	elseif p.move == "lerp" then
		local from, to = m:GetAttribute("DiloJetsFrom"), m:GetAttribute("DiloJetsTo")
		if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
			task.wait(math.clamp(tonumber(m:GetAttribute("DiloJetsDelay")) or 0.34, 0, 0.6))
			local dur = math.clamp(tonumber(m:GetAttribute("DiloJetsTime")) or 0.25, 0.1, 0.5)
			local hrp = b.hrp
			hrp.Anchored = true
			local t0 = os.clock()
			local d = flat(to - from)
			d = d.Magnitude > 1e-3 and d.Unit or dir
			while os.clock() - t0 < dur and hrp.Parent do
				local pos = from:Lerp(to, math.min(1, (os.clock() - t0) / dur))
				hrp.CFrame = CFrame.lookAt(pos, pos + d)
				RunService.Heartbeat:Wait()
			end
			hrp.Anchored = false
			pcall(function() hrp:SetNetworkOwner(nil) end)
		end
	elseif p.move == "portal" then
		task.wait(0.8)
		if point and b.hrp.Parent then
			local up = b.hrp.Size.Y / 2 + b.hum.HipHeight + 1
			b.model:PivotTo(CFrame.new(point + Vector3.new(0, up, 0)) * (b.hrp.CFrame - b.hrp.Position))
			pcall(function() b.hrp:SetNetworkOwner(nil) end)
		end
	end
end

-- v1.4: Elite combos (see the header)
local COMBO_SETUP = {control = true, mobility = true}
local COMBO_PAYOFF = {control = {ranged = true, aoe = true}, mobility = {ranged = true, aoe = true, control = true}}
local function combosOn(tier)
	if not (tier and tier.combo == true) then return false end
	local ps = ServerScriptService:FindFirstChild("PracticeServer")
	return not (ps and ps:GetAttribute("PrKitCombosEnabled") == false)
end
local function comboWindow()
	local ps = ServerScriptService:FindFirstChild("PracticeServer")
	return tonumber(ps and ps:GetAttribute("PrComboWindow")) or 2
end
local function bumpModel(m, name)
	if m and m.Parent then m:SetAttribute(name, (m:GetAttribute(name) or 0) + 1) end
end
-- after a used part: a payoff in the window is counted; a setup opens the window
local function comboUsed(k, b, id, p, tier, info)
	if not combosOn(tier) then return false end
	local inWin = k.comboUntil ~= nil and os.clock() < k.comboUntil
	if inWin and COMBO_PAYOFF[k.comboKind] and COMBO_PAYOFF[k.comboKind][p.kind] then
		bumpModel(b.model, "BotComboHits")
		if b.model and b.model.Parent then b.model:SetAttribute("BotComboLast", tostring(k.comboFrom) .. " > " .. id) end
		k.nextThink = os.clock()
		return true
	end
	if COMBO_SETUP[p.kind] and info and info.hasTarget == true then
		k.comboUntil, k.comboFrom, k.comboKind = os.clock() + comboWindow(), id, p.kind
		k.nextThink = os.clock()
		bumpModel(b.model, "BotCombos")
		if b.model and b.model.Parent then b.model:SetAttribute("BotComboLast", id .. " >") end
		return true
	end
	return false
end

local function fire(b, id, p, info, R, rng, tier)
	local fn = entrance(p.server)
	if not fn then return "noEntrance" end
	local m = b.model
	local stamp = now()
	local dir, point
	if p.kind == "mobility" then
		local d, to = moveDir(b, info)
		faceDir(b, d)
		dir = d
		point = to and (b.hrp.Position + d * math.min(flat(to - b.hrp.Position).Magnitude, p.maxR or 60)) or (b.hrp.Position + d * 40)
	else
		dir, point = aimAt(b, info, R, rng, tier)
	end
	if p.move == "portal" and point then
		local ok, g = pcall(function()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			local island = workspace:FindFirstChild("DinoIsland")
			params.FilterDescendantsInstances = {island and island:FindFirstChild("Ground"), island and island:FindFirstChild("MountainSteps")}
			return workspace:Raycast(point + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), params)
		end)
		if ok and g then point = g.Position end
	end
	local before = snapshot(m)
	local res
	if p.args == "stamp" then
		res = fn:Invoke(m, p.remote, stamp)
	elseif p.args == "dir" then
		res = fn:Invoke(m, p.remote, stamp, dir)
	elseif p.args == "dirPoint" then
		res = fn:Invoke(m, p.remote, stamp, dir, point)
	elseif p.args == "move" then
		res = fn:Invoke(m, p.remote, stamp, Vector3.new(dir.X, 0, dir.Z))
	elseif p.args == "held" then
		res = fn:Invoke(m, p.remote, stamp, 0.6, dir)
	elseif p.args == "land" then
		res = fn:Invoke(m, p.remote, stamp, point)
	end
	local used = res == "ok" and changed(before, m)
	m:SetAttribute("BotPartsTried", (m:GetAttribute("BotPartsTried") or 0) + 1)
	m:SetAttribute("BotLastPart", id .. " " .. tostring(res) .. (used and " used" or " refused"))
	if not used then return "refused" end
	m:SetAttribute("BotPartsUsed", (m:GetAttribute("BotPartsUsed") or 0) + 1)
	if p.move then
		b.busy = true
		task.spawn(function()
			pcall(doMove, b, p, info, dir, point)
			b.busy = false
			if b.hrp and b.hrp.Parent and b.hrp.Anchored then b.hrp.Anchored = false end
		end)
	end
	return "used"
end

-- ---------- think ----------
function M.think(b, ctx, info)
	if b.busy or not b.model then return false end
	local R = ctx.R
	local tier = info.tier or R.tierOf(b.tier)
	local k = b.kit
	if not k or k.model ~= b.model then
		k = {model = b.model, cd = {}, nextThink = 0, slots = {}}
		for n = 1, 4 do
			local id = b.model:GetAttribute("SkillSlot" .. n)
			if type(id) == "string" and M.PARTS[id] and not denied(id) then table.insert(k.slots, id) end
		end
		b.kit = k
	end
	local combo = combosOn(tier) -- v1.4
	local inWin = combo and k.comboUntil ~= nil and os.clock() < k.comboUntil and info.hasTarget == true
	if #k.slots == 0 or (os.clock() < k.nextThink and not inWin) or k.pending then return false end
	k.nextThink = os.clock() + 0.25
	local rng = ctx.rng
	local order = table.clone(k.slots)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	if inWin then -- v1.4: only payoff parts in the window
		local pay, keep = COMBO_PAYOFF[k.comboKind] or {}, {}
		for _, id in ipairs(order) do
			if pay[M.PARTS[id].kind] then table.insert(keep, id) end
		end
		order = keep
	elseif combo and info.hasTarget == true then -- v1.4: ready setup parts first when a payoff is ready
		local payReady = (b.nextAttack or 0) <= os.clock() + 1
		if not payReady then
			for _, id in ipairs(order) do
				local kind = M.PARTS[id].kind
				if (kind == "ranged" or kind == "aoe") and os.clock() >= (k.cd[id] or 0) then payReady = true break end
			end
		end
		if payReady then
			local first, rest = {}, {}
			for _, id in ipairs(order) do
				table.insert((COMBO_SETUP[M.PARTS[id].kind] and os.clock() >= (k.cd[id] or 0)) and first or rest, id)
			end
			for _, id in ipairs(rest) do table.insert(first, id) end
			order = first
		end
	end
	for _, id in ipairs(order) do
		local p = M.PARTS[id]
		if os.clock() >= (k.cd[id] or 0) then
			local w = table.clone(info)
			w.minR, w.maxR, w.radius = p.minR, p.maxR, p.radius
			if p.kind == "mobility" and info.wantMobility then w.stuckFor = 99 end
			local all = allOn() -- v1.2
			local want = all and wantAll(R, p.kind, w) or R.abilityWant(p.kind, w)
			local go = want > 0 and (all or rng:NextNumber() < want * (tier.abil or 0.5))
			if go and asyncOn() then
				-- async (see the header): the fire runs on its own thread; the brain goes on this tick
				k.pending = true
				k.cd[id] = os.clock() + RETRY
				local infoCopy = table.clone(info)
				task.spawn(function()
					local ok, r = pcall(fire, b, id, p, infoCopy, R, rng, tier)
					if ok and r == "used" then
						k.cd[id] = os.clock() + (p.cd or 8)
						k.nextThink = os.clock() + (tier.abilDelay or 0.5)
						comboUsed(k, b, id, p, tier, infoCopy) -- v1.4
					else
						k.cd[id] = os.clock() + RETRY
						if not ok then
							local ps = ServerScriptService:FindFirstChild("PracticeServer")
							if ps then ps:SetAttribute("PrKitError", id .. ": " .. string.sub(tostring(r), 1, 160)) end
						end
					end
					k.pending = false
				end)
				return false
			elseif go then
				local r = fire(b, id, p, info, R, rng, tier)
				if r == "used" then
					k.cd[id] = os.clock() + (p.cd or 8)
					k.nextThink = os.clock() + (tier.abilDelay or 0.5)
					comboUsed(k, b, id, p, tier, info) -- v1.4
					return p.move ~= nil
				else
					k.cd[id] = os.clock() + RETRY
				end
			end
		end
	end
	return false
end

-- v1.3: the slots of this life (think() builds the same list)
local function slotsOf(b)
	local k = b.kit
	if not k or k.model ~= b.model then
		k = {model = b.model, cd = {}, nextThink = 0, slots = {}}
		for n = 1, 4 do
			local id = b.model:GetAttribute("SkillSlot" .. n)
			if type(id) == "string" and M.PARTS[id] and not denied(id) then table.insert(k.slots, id) end
		end
		b.kit = k
	end
	return k
end
local function has(k, id)
	for _, x in ipairs(k.slots) do if x == id then return true end end
	return false
end

-- v1.3: Stun Breaker (see the header); the brain calls this while the bot is stunned or pinned
function M.breakFree(b, ctx)
	if not b.model or denied("breaker") then return false end
	local k = slotsOf(b)
	if not has(k, "breaker") or k.breaking or os.clock() < (k.cd.breaker or 0) then return false end
	k.breaking = true
	k.cd.breaker = os.clock() + RETRY
	task.spawn(function()
		local ok, r = pcall(fire, b, "breaker", M.PARTS.breaker, {}, ctx.R, ctx.rng or Random.new(), ctx.R.tierOf(b.tier))
		k.cd.breaker = os.clock() + ((ok and r == "used") and M.PARTS.breaker.cd or RETRY)
		k.breaking = false
	end)
	return true
end

-- v1.3: Glider Wings (see the header); the brain calls this every tick
function M.air(b, ctx)
	if not b.model or not b.hrp or denied("glider") then return end
	local k = slotsOf(b)
	if not has(k, "glider") or k.gliding == "asking" then return end
	local m, hrp, hum = b.model, b.hrp, b.hum
	local airborne = hum.FloorMaterial == Enum.Material.Air
	local fn = entrance("HerreraMovesServer")
	if not fn then return end
	if m:GetAttribute("Gliding") ~= true then
		if airborne and hrp.AssemblyLinearVelocity.Y < -GLIDE_START and m:GetAttribute("GliderEnabled") == true and dropBelow(b) > GLIDE_HEIGHT then
			k.gliding = "asking"
			task.spawn(function()
				pcall(function() fn:Invoke(m, "DinoGlideRequest", true) end)
				k.gliding = nil
				if m:GetAttribute("Gliding") ~= true then return end
				m:SetAttribute("BotGlides", (m:GetAttribute("BotGlides") or 0) + 1)
				m:SetAttribute("BotLastPart", "glider ok used")
				local conn
				conn = RunService.Heartbeat:Connect(function()
					if not hrp.Parent or m:GetAttribute("Gliding") ~= true then conn:Disconnect() return end
					if hum.FloorMaterial ~= Enum.Material.Air then
						conn:Disconnect()
						pcall(function() fn:Invoke(m, "DinoGlideRequest", false) end)
						return
					end
					local fall = math.max(1, tonumber(m:GetAttribute("GliderFall")) or 8)
					local v = hrp.AssemblyLinearVelocity
					local md = hum.MoveDirection
					local h = md.Magnitude > 0.1 and md.Unit * hum.WalkSpeed or Vector3.new(v.X, 0, v.Z)
					hrp.AssemblyLinearVelocity = Vector3.new(h.X, math.max(v.Y, -fall), h.Z)
				end)
			end)
		end
	elseif not airborne then
		task.spawn(function() pcall(function() fn:Invoke(m, "DinoGlideRequest", false) end) end)
	end
end

-- test hook: use one part now (Studio checks)
function M.useNow(b, id, info, R, rng, tier)
	local p = M.PARTS[id]
	if not p then return "noPart" end
	return fire(b, id, p, info or {}, R, rng or Random.new(), tier or R.tierOf("Elite"))
end

function M.init(d)
	deps = d or {}
end

return M
