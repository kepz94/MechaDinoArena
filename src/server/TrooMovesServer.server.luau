-- TrooMovesServer v1.0 (Mecha Dino Arena) — the Troodon's mecha button parts, build 1 (server authority): Mender Drone, Arc
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
--   portal into terrain: each ring's spot needs TrooMoves_portalClear (a box 6 x 8 x 6 studs above the ground, world only)
--   free; B is pulled back towards A in 4-stud steps until free; none free -> "blocked" (no recharge used). Open from the
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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local CFG = {menderWindup = 0.45, menderFly = 0.75, menderTick = 0.25, menderHopFly = 0.5,
	lanternWindup = 0.42, lanternFly = 0.55, lanternZapDelay = 0.32, lanternZapRadius = 16, lanternChainStep = 0.12,
	sapWindup = 0.34, sapFly = 0.5, sapHeight = 18, sapThick = 2, sapSegments = 5, sapClear = 3,
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
local function damage(char, player, m, base, with, t)
	if shielded(m, t) then return 0 end
	local d = math.max(0, base) * takenMul(m, t)
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
remote("DinoTrooMenderRequest").OnServerEvent:Connect(function(player, stamp)
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
			stampHeal(target, heal(target, rate * tick), now())
			task.wait(tick)
		end
		char:SetAttribute("TrooMenderEndAt", now())
	end)
end)

-- Arc Lantern --------------------------------------------------------------------------------------------------------------
remote("DinoTrooLanternRequest").OnServerEvent:Connect(function(player, stamp, aimDir, aimPoint)
	local char, t = check(player, stamp, "olantern", "TrooPartLantern", aimDir, aimPoint)
	if not char then return end
	ok(char, "TrooPartLantern", t)
	local to = landing(char, aimDir, aimPoint, math.max(1, num(char, "TrooPartLanternRange", 40)))
	char:SetAttribute("TrooLanternFrom", handPos(char))
	char:SetAttribute("TrooLanternTo", to)
	char:SetAttribute("TrooLanternFlight", cfg("lanternFly"))
	char:SetAttribute("TrooLanternAt", t) -- last: TrooPartsFX
	task.delay(cfg("lanternWindup"), function()
		if not canStill(char) then result(char, "TrooPartLantern", "cancelled", now()) return end
		task.wait(cfg("lanternFly"))
		char:SetAttribute("TrooLanternLandAt", now())
		task.wait(cfg("lanternZapDelay"))
		local hits, names = {}, {}
		local from = to
		local maxN = math.max(0, math.floor(num(char, "TrooPartLanternTargets", 2)))
		local reach = math.max(0, cfg("lanternZapRadius"))
		for i = 1, maxN do
			local best, bestD = nil, math.huge
			for _, m in ipairs(enemies(char)) do
				if not hits[m] then
					local d = (rootOf(m).Position - from).Magnitude
					if d <= reach and d < bestD then best, bestD = m, d end
				end
			end
			if not best then break end
			hits[best] = true
			local tz = now()
			damage(char, player, best, num(char, "TrooPartLanternDamage", 8), "troolantern", tz)
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
local function occupied(cf, width, char)
	local half = Vector3.new(width / 2 + cfg("sapClear"), cfg("sapHeight") / 2 + 4, cfg("sapThick") / 2 + cfg("sapClear"))
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
remote("DinoTrooSapRequest").OnServerEvent:Connect(function(player, stamp, aimDir, aimPoint)
	local char, t = check(player, stamp, "osapwall", "TrooPartSap", aimDir, aimPoint)
	if not char then return end
	local width = math.max(4, num(char, "TrooPartSapWidth", 50))
	local to, dir = landing(char, aimDir, aimPoint, math.max(1, num(char, "TrooPartSapRange", 40)))
	local along = Vector3.yAxis:Cross(dir).Unit
	local H = math.max(2, cfg("sapHeight"))
	local cf = wallFrame(to + Vector3.new(0, H / 2, 0), along)
	if occupied(cf, width, char) then result(char, "TrooPartSap", "occupied", t) return end
	ok(char, "TrooPartSap", t)
	local life = math.max(0.1, num(char, "TrooPartSapTime", 2.1))
	char:SetAttribute("TrooSapFrom", handPos(char))
	char:SetAttribute("TrooSapTo", to)
	char:SetAttribute("TrooSapFlight", cfg("sapFly"))
	char:SetAttribute("TrooSapWidth", width)
	char:SetAttribute("TrooSapTime", life)
	char:SetAttribute("TrooSapAt", t) -- last: TrooPartsFX
	task.delay(cfg("sapWindup"), function()
		if not canStill(char) then result(char, "TrooPartSap", "cancelled", now()) return end
		task.wait(cfg("sapFly"))
		local ts = now()
		char:SetAttribute("TrooSapSplatAt", ts)
		if occupied(cf, width, char) then
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
		for i = 1, n do
			local h = H * (i % 2 == 1 and 1 or 0.9)
			local p = Instance.new("Part")
			p.Name = "Sap_" .. i
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, true, true, false
			p.Size = Vector3.new(segW * 1.02, h, math.max(0.5, cfg("sapThick")))
			p.CFrame = cf * CFrame.new((i - 0.5) * segW - width / 2, (h - H) / 2, 0)
			p.Material = Enum.Material.Glass
			p.Color = Color3.fromRGB(255, 180, 58)
			p.Transparency = 0.25
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
remote("DinoTrooShedRequest").OnServerEvent:Connect(function(player, stamp)
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
				if (rootOf(m).Position - root.Position).Magnitude <= r and not shielded(m, tb) then
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
local function spotFree(p)
	worldExclude()
	local w, h = cfg("portalClearW"), cfg("portalClearH")
	local parts = workspace:GetPartBoundsInBox(CFrame.new(p + Vector3.new(0, h / 2 + 0.5, 0)), Vector3.new(w, h, w), overlap)
	for _, q in ipairs(parts) do
		if q.CanCollide then return false end
	end
	return true
end
remote("DinoTrooPortalRequest").OnServerEvent:Connect(function(player, stamp, aimDir, aimPoint)
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

local function onCharacter(char) watchShed(char) end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(onCharacter)
	if pl.Character then onCharacter(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
