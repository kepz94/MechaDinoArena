-- FillerServer v1.0 (Mecha Dino Arena) — filler bots on the hub island (Script, ServerScriptService). Filler Bots v1.0 T4
-- (MDA-577), plan docs/plans/FILLER_BOTS_v1.0.md, ADR-014, mockup docs/mockups/filler_bots_v0.1 (option A · Full disguise).
-- Kepu 2026-11-25: "I want the first set of players to join to feel like they're loading into a lobby against other people";
--   picks: the island fills to 8 dinos, bots fight players too, made-up W-L, no BOT tag; R3 kills count, no new-player
--   protection; R4 names checked against real usernames.
-- Runs when: ReplicatedStorage ServerKind (HubServer) is "hub" and script attribute FillerEnabled ~= false (read at start).
--   Waits for ServerKind to be set. Otherwise FillerState "notHub" / "off" and nothing else.
-- Count (every second): real = #Players (Studio: script attribute FillerTestReal when it is a number); wanted =
--   FillerRules.wanted(real, FillerFillTo (8)). Bots = the ones not leaving.
--   * first fill (no bot yet): wanted bots at once, spread over the roam area (the island is busy on the first frame).
--   * more wanted: one bot after FillerRules.joinDelay (8..20 s), on the HubSpawn islet marker farthest from players, facing
--     the portals; it stands FillerSpawnHold (2..6 s) like a player choosing a loadout, then walks to the roam area.
--   * fewer wanted: the bot with the least time on the island that is not fighting leaves: it walks (PathfindingService,
--     MoveTo waypoints) to the ARENA portal Trigger; within LEAVE_NEAR (14) studs the portal model gets PortalFlareAt =
--     server time (PortalFX) and the bot is removed. After FillerRules.leaveWalkMax (25) s: removed where it stands when no
--     player is within FillerLeaveHideDist (120) studs, else at its next death or at 2 x leaveWalkMax (50 s) wherever it is.
--     FillerLeaveViaPortal false -> removed at once.
--   * real 0 -> every bot removed.
-- A bot: species from PracticeRules.BOT_SPECIES (no T-Rex); loadout PracticeRules.rollBot + PracticeKit.prepareSpec; persona
--   = FillerNameCheck.pick name, FillerRules.record, FillerRules.look (UniversalSkins ORDER, TrailCatalog ORDER); body =
--   PracticeBots.spawn(spec, "F<n>", ..., {persona, xpMul = PrBotXpMul of PracticeServer (0.1), noCollide}); tier =
--   FillerRules.tier (Normal 60% / Hard 40%); PracticeKit.onSpawn.
-- Brain (every FillerTick (0.1) s): PracticeBrain2.step per bot with its own ctx: centre = home = its roam spot (a random dry
--   spot within FillerRoamRadius (200) of FillerRoamCentre (640, 0, 640), the land past the islet bridge; a new one every
--   25..45 s or when reached), bots = the filler bots outside the safe area + one stand-in per player whose character is
--   alive, out of the menu, HubSafe ~= true and not PrParked ({team = "P<UserId>", model, hrp, hum}); each bot is its own
--   team ("F<n>"), so everyone fights everyone. pathBudget FillerPathBudget (3), kit = PracticeKit. Spike 2026-11-25: 4 bots
--   roamed, fought, retreated, no stuck step, no error in 30 s.
-- Emotes: FillerRules.emote: after its target dies (within 2 s of losing it) or after FillerRules.idleGap s still on the
--   islet; EmoteId / EmoteStartedAt / EmoteDuration (EmoteCatalog dur) on the model, the bot stands (busy) for the length.
-- Death: DummyHealth <= 0 -> removed after FillerBody (2) s, back after FillerRules.respawnDelay (5) s on an islet marker
--   with the same persona (unless it was leaving). Lost (no root or below -150): removed and back the same way.
-- Switches / numbers (script attributes): FillerEnabled (true), FillerFillTo (8), FillerTick (0.1), FillerLeaveViaPortal
--   (true), FillerRoamCentre (Vector3 640, 0, 640), FillerRoamRadius (200), FillerPathBudget (3), FillerBody (2),
--   FillerLeaveHideDist (120), FillerTestReal (nil; Studio only).
-- Diagnostics: FillerServerVersion, FillerState ("waiting" / "notHub" / "off" / "on" / "noModules"), FillerBots, FillerWanted,
--   FillerReal, FillerLast, FillerMs (think time per tick), FillerBrainError, FillerSpawned, FillerLeft.
-- v1.1 (found in the T5 Studio check 2026-11-25: a bot's tag never came back after it emoted): EmoteId is cleared when the emote's
--   length is over (as EmoteServer does for players; IslandTags 1.5 hides a tag while EmoteId is set).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 EmoteId cleared after the emote
VERSION = "1.2" -- v1.2 safe guard: no fights on / right off the islet
-- v1.2 (island spawn lock, plan docs/plans/SPAWN_LOCK_v1.0.md Task 4; Kepu 2026-11-26 "the bots are just fighting right at
--   spawn even without damage", pick "Fighting each other"): a bot inside the safe area gets safeUntil = now + FillerSafeGuard
--   (default HubRules.GUARD, 3) s, renewed every tick while inside, so it keeps the protection for 3 s after leaving like a player.
--   While os.clock() < safeUntil the bot is not a target for other bots and steps with no enemies (it walks, it does not
--   swing) and its old target is dropped. Switch: script attribute FillerSafeGuardEnabled (default true, read per tick;
--   false = 1.1). Diagnostic: script attribute FillerSafeBots (bots guarded this tick).
script:SetAttribute("FillerServerVersion", VERSION)
local DEFAULTS = {FillerEnabled = true, FillerFillTo = 8, FillerTick = 0.1, FillerLeaveViaPortal = true,
	FillerRoamCentre = Vector3.new(640, 0, 640), FillerRoamRadius = 200, FillerPathBudget = 3, FillerBody = 2,
	FillerLeaveHideDist = 120}
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function get(k) local v = script:GetAttribute(k) if v == nil then return DEFAULTS[k] end return v end
script:SetAttribute("FillerSpawned", 0)
script:SetAttribute("FillerLeft", 0)

if script:GetAttribute("FillerEnabled") == false then
	script:SetAttribute("FillerState", "off")
	return
end
script:SetAttribute("FillerState", "waiting")
while ReplicatedStorage:GetAttribute("ServerKind") == nil do task.wait(0.5) end
if ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" then
	script:SetAttribute("FillerState", "notHub")
	return
end

local DA = ServerStorage:WaitForChild("DinoArcade")
local PS = ServerScriptService:WaitForChild("PracticeServer")
local ok, mods = pcall(function()
	return {
		FR = require(DA:WaitForChild("FillerRules")), NC = require(DA:WaitForChild("FillerNameCheck")),
		R = require(DA:WaitForChild("PracticeRules")), H = require(DA:WaitForChild("HardpointRules")),
		HR = require(DA:WaitForChild("HubRules")), ST = require(DA:WaitForChild("SkillTree")),
		US = require(DA:WaitForChild("UniversalSkins")), TC = require(DA:WaitForChild("TrailCatalog")),
		EC = require(DA:WaitForChild("EmoteCatalog")),
		Bots = require(PS:WaitForChild("PracticeBots")), Brain = require(PS:WaitForChild("PracticeBrain")),
		Brain2 = require(PS:WaitForChild("PracticeBrain2")), Kit = require(PS:WaitForChild("PracticeKit")),
	}
end)
if not ok then
	script:SetAttribute("FillerState", "noModules")
	script:SetAttribute("FillerLast", tostring(mods))
	return
end
local FR, NC, R, H, HR, ST = mods.FR, mods.NC, mods.R, mods.H, mods.HR, mods.ST
local Bots, Brain, Brain2, Kit = mods.Bots, mods.Brain, mods.Brain2, mods.Kit
-- the hub's PracticeServer stops before it sets these up, so this script does
Brain.init()
Brain2.init(Brain, Bots)
pcall(Kit.init, {Brain = Brain, Bots = Bots, R = R, SkillTree = ST})

local SPECIES = R.BOT_SPECIES or {"Raptor", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}
local SKINS = mods.US.ORDER or {"classic"}
local TRAILS = mods.TC.ORDER or {}
local EMOTES = mods.EC.ORDER or {}
local LEAVE_NEAR = 14
local rng = Random.new()
local used = {}
local recs = {}
local nextTeam = 0

local island = workspace:WaitForChild("DinoIsland")
local folder = island:FindFirstChild("Bots")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = island
end
local islet = workspace:WaitForChild("PortalIslet", 60)

local function now() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function set(k, v) if script:GetAttribute(k) ~= v then script:SetAttribute(k, v) end end
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end

-- ground, roam spots, islet markers, safe zones, the portal
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function refreshGround()
	local list = {workspace.Terrain}
	for _, n in ipairs({"Ground", "MountainSteps"}) do
		local g = island:FindFirstChild(n)
		if g then table.insert(list, g) end
	end
	if islet then table.insert(list, islet) end
	groundParams.FilterDescendantsInstances = list
end
refreshGround()
local function dryTop(x, z)
	local r = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), groundParams)
	if r and r.Material ~= Enum.Material.Water and r.Position.Y > -0.8 and r.Position.Y < 20 then return r.Position end
	return nil
end
local function roamSpot()
	local c = get("FillerRoamCentre")
	if typeof(c) ~= "Vector3" then c = DEFAULTS.FillerRoamCentre end
	local rad = tonumber(get("FillerRoamRadius")) or 200
	for _ = 1, 40 do
		local a = rng:NextNumber() * math.pi * 2
		local d = math.sqrt(rng:NextNumber()) * rad
		local p = dryTop(c.X + math.cos(a) * d, c.Z + math.sin(a) * d)
		if p then return p end
	end
	return dryTop(c.X, c.Z) or Vector3.new(c.X, 2, c.Z)
end

local markers, zones, trigger, portalModel = {}, {}, nil, nil
if islet then
	for _, d in ipairs(islet:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:match("^IsletSpawn") then table.insert(markers, d) end
		if d:IsA("BasePart") and d:GetAttribute("HubSafeZone") ~= nil then table.insert(zones, d) end
		if d:IsA("BasePart") and d.Name == "Trigger" and d:GetAttribute("HubPortal") == "arena" then
			trigger = d
			portalModel = d:FindFirstAncestorWhichIsA("Model")
		end
	end
	table.sort(markers, function(a, b) return a.Name < b.Name end)
end
local function inSafe(pos)
	for _, z in ipairs(zones) do
		if HR.inShape(pos, z.CFrame, z.Size, z:GetAttribute("HubZoneShape") or "box") then return true end
	end
	return false
end

local function playerRoots()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then table.insert(list, r.Position) end
	end
	return list
end
local function nearestPlayer(pos)
	local best = math.huge
	for _, p in ipairs(playerRoots()) do best = math.min(best, (p - pos).Magnitude) end
	return best
end
local function islePlace()
	if #markers == 0 then return nil end
	local best, bestD
	for _, m in ipairs(markers) do
		local d = nearestPlayer(m.Position)
		for _, r in ipairs(recs) do
			if r.hrp and r.hrp.Parent then d = math.min(d, (r.hrp.Position - m.Position).Magnitude) end
		end
		if not bestD or d > bestD then best, bestD = m, d end
	end
	return best
end

-- one persona per bot; its spec (loadout) is rolled once
local function newRec()
	nextTeam += 1
	local rec = {team = "F" .. nextTeam, busy = false, state = "new"}
	local species = SPECIES[rng:NextInteger(1, #SPECIES)]
	local name = NC.pick(rng, used) -- yields (web check)
	local w, l = FR.record(name)
	local skin, trail = FR.look(rng, SKINS, TRAILS)
	local spec = R.rollBot(rng, {}, ST, R.BOT_LEVEL or 30, species)
	spec.name = name
	if Kit.prepareSpec then
		local okP, s2 = pcall(Kit.prepareSpec, spec, rng)
		if okP and s2 then spec = s2 end
	end
	rec.spec, rec.species = spec, species
	rec.persona = {name = name, w = w, l = l, skin = skin, trail = trail}
	rec.tier = FR.tier(rng)
	return rec
end

local function spawnRec(rec, cf, hold)
	local xp = tonumber(PS:GetAttribute("PrBotXpMul")) or 0.1
	local model = Bots.spawn(rec.spec, rec.team, cf, folder, {persona = rec.persona, xpMul = xp, noCollide = true})
	if not model then
		set("FillerLast", "spawnFailed " .. rec.persona.name)
		return false
	end
	rec.model, rec.hrp, rec.hum = model, model:FindFirstChild("HumanoidRootPart"), model:FindFirstChildOfClass("Humanoid")
	rec.deadAt, rec.respawnAt, rec.busy, rec.target, rec.v2 = nil, nil, false, nil, nil
	rec.roam, rec.roamAt = roamSpot(), os.clock()
	rec.bornAt = rec.bornAt or os.clock()
	rec.holdUntil = hold and (os.clock() + hold) or nil
	rec.idleSince = os.clock()
	model:SetAttribute("BotTier", rec.tier)
	model:SetAttribute("FillerHub", true)
	if Kit.onSpawn then pcall(Kit.onSpawn, rec, model) end
	bump("FillerSpawned")
	set("FillerLast", "spawn " .. rec.persona.name .. " " .. rec.species)
	return true
end

local function islePos()
	local m = islePlace()
	if not m then return nil end
	local p = m.Position + Vector3.new(0, -m.Size.Y / 2, 0)
	local face = trigger and flat(trigger.Position - p) or Vector3.new(1, 0, 1)
	if face.Magnitude < 1e-3 then face = Vector3.new(1, 0, 1) end
	return CFrame.lookAt(p, p + face.Unit)
end

local function despawn(rec)
	if rec.model then rec.model:Destroy() end
	rec.model, rec.hrp, rec.hum = nil, nil, nil
end

local function removeRec(rec)
	despawn(rec)
	local i = table.find(recs, rec)
	if i then table.remove(recs, i) end
	used[rec.persona.name] = true -- the name is not used again this server session
end

-- leaving: walk to the ARENA portal
local function startLeave(rec)
	rec.leaving, rec.leaveAt, rec.path, rec.wp, rec.pathAt = true, os.clock(), nil, nil, 0
	if get("FillerLeaveViaPortal") == false or not trigger or not rec.model then
		removeRec(rec)
		bump("FillerLeft")
		return
	end
	if rec.model then rec.model:SetAttribute("BotState", "leaving") end
end

local function leaveStep(rec)
	if not (rec.model and rec.hrp and rec.hrp.Parent and rec.hum) then removeRec(rec) bump("FillerLeft") return end
	local p = rec.hrp.Position
	if flat(trigger.Position - p).Magnitude <= LEAVE_NEAR then
		if portalModel then portalModel:SetAttribute("PortalFlareAt", now()) end
		set("FillerLast", "left " .. rec.persona.name)
		removeRec(rec)
		bump("FillerLeft")
		return
	end
	if os.clock() - rec.leaveAt > FR.leaveWalkMax() then
		-- hard cap at twice the time (found in Studio: a bot stuck at the bridge 85 studs from a player never left)
		if nearestPlayer(p) > (tonumber(get("FillerLeaveHideDist")) or 120) or os.clock() - rec.leaveAt > 2 * FR.leaveWalkMax() then
			removeRec(rec)
			bump("FillerLeft")
		end
		return -- else it is removed at its next death or at the cap
	end
	if not rec.path or os.clock() - rec.pathAt > 2.5 then
		rec.pathAt = os.clock()
		local path = PathfindingService:CreatePath({AgentRadius = 3, AgentHeight = 8, AgentCanJump = true, Costs = {Water = 3}})
		local okC = pcall(function() path:ComputeAsync(p, trigger.Position) end)
		if okC and path.Status == Enum.PathStatus.Success then
			rec.path, rec.wp = path:GetWaypoints(), 2
		else
			rec.path, rec.wp = nil, nil
		end
	end
	local goal = trigger.Position
	if rec.path and rec.wp then
		while rec.path[rec.wp] and flat(rec.path[rec.wp].Position - p).Magnitude < 5 do rec.wp += 1 end
		local w = rec.path[rec.wp]
		if w then
			goal = w.Position
			if w.Action == Enum.PathWaypointAction.Jump then rec.hum.Jump = true end
		end
	end
	rec.hum:MoveTo(goal)
end

-- stand-ins for players the bots may fight
local function standIns()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if r and hum and hum.Health > 0 and pl:GetAttribute("InMenu") ~= true and c:GetAttribute("HubSafe") ~= true
			and pl:GetAttribute("PrParked") ~= true then
			table.insert(list, {team = "P" .. pl.UserId, model = c, hrp = r, hum = hum, isPlayer = true})
		end
	end
	return list
end

local function emoteNow(rec, id)
	local e = mods.EC.get and mods.EC.get(id) or (mods.EC.EMOTES and mods.EC.EMOTES[id])
	local dur = (e and tonumber(e.dur)) or 2.6
	local m = rec.model
	if not m then return end
	rec.busy = true
	if rec.hum and rec.hrp then rec.hum:MoveTo(rec.hrp.Position) end
	m:SetAttribute("EmoteDuration", dur)
	m:SetAttribute("EmoteStartedAt", now())
	m:SetAttribute("EmoteId", id)
	local at = m:GetAttribute("EmoteStartedAt")
	task.delay(dur, function()
		if rec.model == m then rec.busy = false end
		if m.Parent and m:GetAttribute("EmoteStartedAt") == at then m:SetAttribute("EmoteId", nil) end -- v1.1
	end)
	rec.lastEmote = os.clock()
end

-- ---------- count ----------
local firstFill = false
local joinAt = nil
local spawning = 0

local function realCount()
	local t = script:GetAttribute("FillerTestReal")
	if RunService:IsStudio() and type(t) == "number" then return t end
	return #Players:GetPlayers()
end

local function activeCount()
	local n = 0
	for _, r in ipairs(recs) do if not r.leaving then n += 1 end end
	return n + spawning
end

local function addBot(atIslet)
	spawning += 1
	task.spawn(function()
		local rec = newRec()
		spawning -= 1
		local cf
		if atIslet then cf = islePos() end
		if not cf then cf = CFrame.new(roamSpot()) end
		table.insert(recs, rec)
		if not spawnRec(rec, cf, atIslet and (2 + rng:NextNumber() * 4) or nil) then
			local i = table.find(recs, rec)
			if i then table.remove(recs, i) end
		end
	end)
end

task.spawn(function()
	while true do
		local real = realCount()
		local wanted = FR.wanted(real, tonumber(get("FillerFillTo")) or 8)
		set("FillerReal", real)
		set("FillerWanted", wanted)
		local have = activeCount()
		if wanted == 0 and real <= 0 then
			for i = #recs, 1, -1 do removeRec(recs[i]) end
			joinAt, firstFill = nil, false
		elseif have < wanted then
			if not firstFill then
				firstFill = true
				for _ = 1, wanted - have do addBot(false) end
			elseif not joinAt then
				joinAt = os.clock() + FR.joinDelay(rng)
			elseif os.clock() >= joinAt then
				joinAt = nil
				addBot(true)
			end
		else
			joinAt = nil
			if have > wanted then
				local pick, pickAge
				for _, r in ipairs(recs) do
					if not r.leaving and r.model then
						local st = r.model:GetAttribute("BotState")
						local fighting = st == "fight" or st == "attack"
						local age = os.clock() - (r.bornAt or os.clock())
						local score = age + (fighting and 1e6 or 0)
						if not pickAge or score < pickAge then pick, pickAge = r, score end
					end
				end
				if pick then startLeave(pick) end
			end
		end
		local n = 0
		for _, r in ipairs(recs) do if r.model and r.model.Parent then n += 1 end end
		set("FillerBots", n)
		set("FillerState", "on")
		task.wait(1)
	end
end)

-- ---------- brain ----------
task.spawn(function()
	while true do
		local dt = tonumber(get("FillerTick")) or 0.1
		task.wait(dt)
		local t0 = os.clock()
		local ins = standIns()
		local safeOn, safeNow, safeN = get("FillerSafeGuardEnabled") ~= false, os.clock(), 0 -- v1.2
		for _, r in ipairs(recs) do
			if safeOn and r.hrp and r.hrp.Parent and not r.deadAt and inSafe(r.hrp.Position) then
				r.safeUntil = safeNow + (tonumber(get("FillerSafeGuard")) or HR.GUARD or 3)
			end
			if safeOn and r.safeUntil and safeNow < r.safeUntil then safeN += 1 end
		end
		set("FillerSafeBots", safeN)
		local eligible = {}
		for _, r in ipairs(recs) do
			if r.model and r.model.Parent and r.hrp and r.hrp.Parent and not r.deadAt and not r.leaving
				and not inSafe(r.hrp.Position)
				and not (safeOn and r.safeUntil and safeNow < r.safeUntil) then -- v1.2
				table.insert(eligible, r)
			end
		end
		for _, s in ipairs(ins) do table.insert(eligible, s) end
		local budget = {n = tonumber(get("FillerPathBudget")) or 3}
		for _, rec in ipairs(table.clone(recs)) do
			local m = rec.model
			if m then
				local dead = not m.Parent or (tonumber(m:GetAttribute("DummyHealth")) or 0) <= 0
				local lost = not (rec.hrp and rec.hrp:IsDescendantOf(workspace)) or rec.hrp.Position.Y < -150
				if dead or lost then
					if not rec.deadAt then
						rec.deadAt = os.clock()
						if m.Parent then m:SetAttribute("BotState", "dead") end
					elseif os.clock() - rec.deadAt > (tonumber(get("FillerBody")) or 2) or lost then
						despawn(rec)
						if rec.leaving then
							removeRec(rec)
							bump("FillerLeft")
						else
							rec.respawnAt = os.clock() + FR.respawnDelay()
						end
					end
				elseif rec.leaving then
					leaveStep(rec)
				elseif rec.holdUntil and os.clock() < rec.holdUntil then
					-- standing on the islet like a player picking a loadout
					if not rec.lastEmote and rng:NextNumber() < 0.01 then
						local id = FR.emote(rng, {inSafe = true, idleFor = 99, idleNeed = 0, emoteIds = EMOTES})
						if id then emoteNow(rec, id) end
					end
				else
					rec.holdUntil = nil
					if (rec.roam and flat(rec.hrp.Position - rec.roam).Magnitude < 15) or os.clock() - (rec.roamAt or 0) > 25 + rng:NextNumber() * 20 then
						rec.roam, rec.roamAt = roamSpot(), os.clock()
					end
					-- emote after a kill: the target it had just died
					local tgt = rec.target
					if tgt then rec.lastTarget, rec.lastTargetAt = tgt, os.clock() end
					local lt = rec.lastTarget
					if lt and not rec.busy and os.clock() - (rec.lastTargetAt or 0) < 2 then
						local th = lt:FindFirstChildOfClass("Humanoid")
						local gone = not lt.Parent or (tonumber(lt:GetAttribute("DummyHealth")) or 1) <= 0 or (th and th.Health <= 0)
						if gone then
							rec.lastTarget = nil
							local id = FR.emote(rng, {afterKill = true, emoteIds = EMOTES})
							if id then emoteNow(rec, id) end
						end
					end
					local guarded = safeOn and rec.safeUntil and os.clock() < rec.safeUntil -- v1.2
					if guarded then rec.target = nil end
					if not rec.busy then
						local ctx = {bots = guarded and {} or eligible, R = R, H = H, diff = R.diffOf("Normal"), rng = rng, centre = rec.roam,
							home = rec.roam, index = 1, into = 0, pointTime = 60, pathBudget = budget, kit = Kit, tiered = true}
						local okS, err = pcall(Brain2.step, rec, ctx)
						if not okS then set("FillerBrainError", tostring(err)) end
					end
				end
			elseif rec.respawnAt and os.clock() >= rec.respawnAt then
				rec.respawnAt = nil
				local cf = islePos() or CFrame.new(roamSpot())
				spawnRec(rec, cf, 1 + rng:NextNumber() * 2)
			end
		end
		set("FillerMs", math.floor((os.clock() - t0) * 10000 + 0.5) / 10)
	end
end)
