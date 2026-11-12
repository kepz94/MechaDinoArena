-- HubServer v1.0 (Mecha Dino Arena) — the island hub: the portal islet, the safe area, islet spawns and portal trips (Script,
-- ServerScriptService; MDA-457, plan docs/plans/ISLAND_HUB_v1.0.md Task 6, ADR-011, mockup docs/mockups/island_portals_v0.1.html
-- layout "C · Portal Islet"). Kepu 2026-11-11: "when you spawn on the main island there will be portals that lead you to arena,
-- hard point v bots ... if you're squaded up and enter into a game mode your squad queues with you"; picks: PvP on outside,
-- the leader walks in and the whole squad goes, 3 s guard both ways, no hub bots, private bots match.
-- Rules and numbers: ServerStorage.DinoArcade.HubRules 1.0 (cloned to ReplicatedStorage.HubShared for clients). Trips:
--   child module HubTravel 1.0.
-- At start (every kind): ReplicatedStorage attributes ServerKind = ModeRules 1.2 serverKind() ("hub" / "practice" / "arena")
--   and HubOn = ModeRules.hubOn() (this script on). Kind "hub" with ServerStorage.PortalIslet present: a copy goes into
--   Workspace ("PortalIslet") and ReplicatedStorage HubLive = true (ModeRules 1.2 canAffect: players hurt players; SquadRules
--   1.3: a HubSafe character can't hurt or be hurt). Other kinds: HubState "notHub", nothing else (HubTravel still serves
--   ModeServer).
-- Safe area (every HubRules.POLL (0.2) s, each player's character): HubInZone = the HumanoidRootPart is inside a SafeZone part
--   of the islet (attribute HubSafeZone; HubZoneShape "cyl" / "box"), alive, not InMenu. Leaving the zone sets HubGuardUntil =
--   now + HubRules.GUARD (3). HubSafe = HubRules.protected(HubInZone, HubGuardUntil, now). Character attributes HubInZone,
--   HubGuardUntil, HubSafe (written when they change).
-- Islet spawns: InMenu turning false (PLAY) -> after PLACE_DELAY (0.15) s, and every new character while not InMenu (respawn,
--   dino swap, the first body after a trip) -> after RESPAWN_DELAY (0.3) s: the character stands on a HubSpawn marker (the one
--   farthest from other players; ties / alone -> the marker after the last one used), facing the portals, camera turned the
--   same way (character ShoulderCamLookAt, cleared 1 s later). A fresh body starts with HubGuardUntil cleared. Player
--   attributes HubSpawnIndex, HubSpawnAt.
-- Portals: a root inside a portal Trigger (attribute HubPortal "arena" / "bots") — on entering it:
--   * already in a trip -> nothing;
--   * HubRules.tripParty(player, the squad: SquadRules SquadId / members / leaderOf) -> nil "notLeader": player HubLastResult
--     "notLeader", HubLastLeader (the leader's name); else a trip: every listed player on this server gets HubTripMode (mode),
--     HubTripEndsAt (now + HubRules.TRIP_TIME (5)), HubTripLeader (the starter's name when in a squad, else ""), HubTripMembers
--     (names, comma list), HubTripState "count".
--   * cancel ("cancelled" for everyone in it): the starter's root leaves the trigger, the starter dies / opens the menu, its
--     SquadId changes, or it quits. A member whose SquadId changes or who quits is dropped (HubTripState ""); the rest go.
--   * at 0: HubTripState "saving" while HubTravel.saveWait waits, then "teleporting" and HubTravel.go(players, mode,
--     HubRules.tripData(mode, key, leader UserId, member UserIds, "hub")). Studio -> "studio"; errors -> "failed" (also on
--     TeleportService.TeleportInitFailed). HubLastResult = the same word. Trip attributes stay until the next trip.
-- Switch: script attribute HubEnabled (default true, read at start; false = today's Sandbox: ModeRules.hubOn() is false, so
--   the server is "practice"). Diagnostics: script HubServerVersion, HubState ("off" / "notHub" / "noIslet" / "on"), HubKind,
--   HubTrips, HubTripsFailed, HubPlaced.
-- Test hook (server-only BindableFunction HubTest): Invoke("trip", player, mode) starts a trip as if the player walked into
--   that portal (no "left the portal" cancel); Invoke("cancel", player); Invoke("state") -> a one-line summary.
-- v1.1 (Kepu 2026-11-11 18:48: "When you step in a portal in Fortnite it goes straight to the loading"): with HubRules 1.1
--   TRIP_TIME 0 a portal goes straight to "saving" / "teleporting" (no countdown). Once the countdown part is over the trip is
--   in its "go" phase: the cancel / drop rules above apply only during the countdown, and every traveller who is not in the
--   menu has its HumanoidRootPart anchored where it stands (so walking through the portal doesn't carry it away while the
--   loading screen is up). "studio" / "failed" / "cancelled", and a teleport that hasn't happened 20 s after it was sent,
--   un-anchor them again. Switch: script attribute HubAnchorTripEnabled (default true, read per trip; false = no anchoring).
-- v1.2 (Kepu 2026-11-11 19:02: the bots trip landed on a hub): ModeRules 1.3 decides the kind on live servers after the first
--   player's trip (so this script may start once the first player is in); ReplicatedStorage ServerKindWhy =
--   ModeRules.serverKindWhy() ("reservedId" / "tripBots" / "public" / ...), for checking a server in the live console.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.2"
local PLACE_DELAY, RESPAWN_DELAY = 0.15, 0.3

script:SetAttribute("HubServerVersion", VERSION)
if script:GetAttribute("HubEnabled") == nil then script:SetAttribute("HubEnabled", true) end
if script:GetAttribute("HubAnchorTripEnabled") == nil then script:SetAttribute("HubAnchorTripEnabled", true) end -- v1.1
script:SetAttribute("HubTrips", 0)
script:SetAttribute("HubTripsFailed", 0)
script:SetAttribute("HubPlaced", 0)

local arcade = ServerStorage:WaitForChild("DinoArcade")
local ModeRules = require(arcade:WaitForChild("ModeRules"))
local HubRules = require(arcade:WaitForChild("HubRules"))
local SquadRules = require(arcade:WaitForChild("SquadRules"))
local Travel = require(script:WaitForChild("HubTravel"))

local KIND = ModeRules.serverKind()
script:SetAttribute("HubKind", KIND)
ReplicatedStorage:SetAttribute("ServerKind", KIND)
ReplicatedStorage:SetAttribute("ServerKindWhy", ModeRules.serverKindWhy and ModeRules.serverKindWhy() or "") -- v1.2
ReplicatedStorage:SetAttribute("HubOn", ModeRules.hubOn())

-- client copy of the rules
local shared = ReplicatedStorage:FindFirstChild("HubShared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "HubShared"
	shared.Parent = ReplicatedStorage
end
if shared:FindFirstChild("HubRules") then shared.HubRules:Destroy() end
arcade.HubRules:Clone().Parent = shared

if script:GetAttribute("HubEnabled") == false then
	script:SetAttribute("HubState", "off")
	return
end
Travel.track()
if KIND ~= "hub" then
	script:SetAttribute("HubState", "notHub")
	return
end
local src = ServerStorage:FindFirstChild("PortalIslet")
if not src then
	script:SetAttribute("HubState", "noIslet")
	return
end
local islet = src:Clone()
islet.Parent = workspace
ReplicatedStorage:SetAttribute("HubLive", true)
script:SetAttribute("HubState", "on")

local zones, portals, spawns = {}, {}, {}
for _, d in ipairs(islet:GetDescendants()) do
	if d:IsA("BasePart") then
		if d:GetAttribute("HubSafeZone") == true then
			table.insert(zones, {cf = d.CFrame, size = d.Size, shape = d:GetAttribute("HubZoneShape") == "cyl" and "cyl" or "box"})
		elseif d.Name == "Trigger" and type(d:GetAttribute("HubPortal")) == "string" then
			table.insert(portals, {part = d, mode = d:GetAttribute("HubPortal")})
		elseif d:GetAttribute("HubSpawn") == true then
			table.insert(spawns, d)
		end
	end
end
table.sort(spawns, function(a, b) return a.Name < b.Name end)

local function now() return workspace:GetServerTimeNow() end
local function setIf(inst, k, v) if inst:GetAttribute(k) ~= v then inst:SetAttribute(k, v) end end
local function rootOf(p)
	local c = p.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r and hum and hum.Health > 0 then return r, c end
	return nil, c
end

-- ---------- islet spawns ----------
local lastSpawn = 0
local function place(p)
	local c = p.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) or #spawns == 0 or p:GetAttribute("InMenu") == true then return end
	local best, bestD = nil, -1
	for i, s in ipairs(spawns) do
		local nearest = math.huge
		for _, o in ipairs(Players:GetPlayers()) do
			local r = o ~= p and rootOf(o)
			if r then nearest = math.min(nearest, (r.Position - s.Position).Magnitude) end
		end
		if nearest ~= math.huge and nearest > bestD then best, bestD = i, nearest end
	end
	if not best then best = lastSpawn % #spawns + 1 end
	lastSpawn = best
	local s = spawns[best]
	local pos = s.Position + Vector3.new(0, s.Size.Y / 2 + hrp.Size.Y / 2 + hum.HipHeight, 0)
	local look = Vector3.new(s.CFrame.LookVector.X, 0, s.CFrame.LookVector.Z).Unit
	c:PivotTo(CFrame.lookAt(pos, pos + look))
	c:SetAttribute("HubGuardUntil", nil)
	c:SetAttribute("ShoulderCamLookAt", pos + look * 500)
	task.delay(1, function()
		if c.Parent then c:SetAttribute("ShoulderCamLookAt", nil) end
	end)
	p:SetAttribute("HubSpawnIndex", best)
	p:SetAttribute("HubSpawnAt", now())
	script:SetAttribute("HubPlaced", (script:GetAttribute("HubPlaced") or 0) + 1)
end

-- ---------- trips ----------
local tripOf = {} -- [player] = trip
local function clearTrip(p, state)
	tripOf[p] = nil
	p:SetAttribute("HubTripState", state)
end
local function unanchor(trip) -- v1.1
	for p, hrp in pairs(trip.anchored or {}) do
		if hrp.Parent and p.Parent and p:GetAttribute("InMenu") ~= true then hrp.Anchored = false end
	end
	trip.anchored = {}
end
local function finish(trip, state)
	trip.dead = true
	unanchor(trip) -- v1.1
	for _, p in ipairs(trip.players) do
		if tripOf[p] == trip then clearTrip(p, state) end
		if p.Parent then
			p:SetAttribute("HubLastResult", state)
			p:SetAttribute("HubLastAt", now())
		end
	end
end
local function drop(trip, p)
	for i, q in ipairs(trip.players) do
		if q == p then table.remove(trip.players, i) break end
	end
	if tripOf[p] == trip then clearTrip(p, "") end
	if p == trip.starter then finish(trip, "cancelled") end
end

local function runTrip(trip)
	while not trip.dead and now() < trip.endsAt do task.wait(0.1) end
	if trip.dead then return end
	trip.phase = "go" -- v1.1: no more cancels; hold the travellers where they stand
	trip.anchored = {}
	if script:GetAttribute("HubAnchorTripEnabled") ~= false then
		for _, p in ipairs(trip.players) do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp and p:GetAttribute("InMenu") ~= true and not hrp.Anchored then
				hrp.Anchored = true
				trip.anchored[p] = hrp
			end
		end
	end
	for _, p in ipairs(trip.players) do p:SetAttribute("HubTripState", "saving") end
	local here = Travel.saveWait(trip.players)
	if trip.dead then return end
	trip.players = here
	for _, p in ipairs(here) do p:SetAttribute("HubTripState", "teleporting") end
	local ids = {}
	for _, p in ipairs(here) do table.insert(ids, p.UserId) end
	local leader = trip.squadId ~= "" and trip.starter.UserId or nil
	local ok, why = Travel.go(here, trip.mode, HubRules.tripData(trip.mode, trip.key, leader, ids, "hub"))
	script:SetAttribute("HubTrips", (script:GetAttribute("HubTrips") or 0) + 1)
	if ok then
		trip.dead = true
		for _, p in ipairs(here) do
			p:SetAttribute("HubLastResult", "teleporting")
			p:SetAttribute("HubLastAt", now())
		end
		task.delay(20, function() -- still here after 20 s: free them for a new trip
			unanchor(trip) -- v1.1
			for _, p in ipairs(here) do
				if p.Parent and tripOf[p] == trip then clearTrip(p, "failed") end
			end
		end)
	else
		if why ~= "studio" then script:SetAttribute("HubTripsFailed", (script:GetAttribute("HubTripsFailed") or 0) + 1) end
		finish(trip, why == "studio" and "studio" or "failed")
	end
end

local function startTrip(p, mode, noPortal)
	if tripOf[p] or not HubRules.MODES[mode] or mode == "island" then return "busy" end
	local sid = SquadRules.idOfPlayer(p)
	local ids, members = {}, {}
	if sid ~= "" then
		for _, m in ipairs(SquadRules.members(sid)) do table.insert(ids, m.UserId) end
	end
	local leader = sid ~= "" and SquadRules.leaderOf(sid) or nil
	local party, why = HubRules.tripParty(p.UserId, {squadId = sid, leaderId = leader and leader.UserId, members = ids})
	if not party then
		p:SetAttribute("HubLastLeader", leader and leader.Name or "")
		p:SetAttribute("HubLastResult", why)
		p:SetAttribute("HubLastAt", now())
		return why
	end
	for _, id in ipairs(party) do
		local m = Players:GetPlayerByUserId(id)
		if m and not tripOf[m] then table.insert(members, m) end
	end
	local names = {}
	for _, m in ipairs(members) do table.insert(names, m.Name) end
	local trip = {mode = mode, starter = p, players = members, endsAt = now() + HubRules.TRIP_TIME, squadId = sid,
		key = HttpService:GenerateGUID(false), noPortal = noPortal == true, phase = "count"} -- v1.1: phase
	for _, m in ipairs(members) do
		tripOf[m] = trip
		m:SetAttribute("HubTripMode", mode)
		m:SetAttribute("HubTripEndsAt", trip.endsAt)
		m:SetAttribute("HubTripLeader", sid ~= "" and p.Name or "")
		m:SetAttribute("HubTripMembers", table.concat(names, ","))
		m:SetAttribute("HubTripState", "count")
	end
	task.spawn(runTrip, trip)
	return "ok"
end

TeleportService.TeleportInitFailed:Connect(function(p)
	if p and p.Parent and p:GetAttribute("HubTripState") == "teleporting" then
		local t = tripOf[p] -- v1.1: free this one
		local hrp = t and t.anchored and t.anchored[p]
		if hrp and hrp.Parent and p:GetAttribute("InMenu") ~= true then hrp.Anchored = false end
		if t and t.anchored then t.anchored[p] = nil end
		clearTrip(p, "failed")
		p:SetAttribute("HubLastResult", "failed")
		p:SetAttribute("HubLastAt", now())
		script:SetAttribute("HubTripsFailed", (script:GetAttribute("HubTripsFailed") or 0) + 1)
	end
end)

-- ---------- players ----------
local inPortal = {} -- [player] = mode or nil
local wasIn = {} -- [player] = inZone last poll
local function onPlayer(p)
	p:GetAttributeChangedSignal("InMenu"):Connect(function()
		if p:GetAttribute("InMenu") ~= true then
			task.delay(PLACE_DELAY, function()
				if p.Parent and p:GetAttribute("InMenu") ~= true then place(p) end
			end)
		end
	end)
	p.CharacterAdded:Connect(function(c)
		wasIn[p] = nil
		task.delay(RESPAWN_DELAY, function()
			if p.Parent and p.Character == c and p:GetAttribute("InMenu") ~= true then place(p) end
		end)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p)
	local t = tripOf[p]
	if t then drop(t, p) end
	inPortal[p], wasIn[p] = nil, nil
end)

-- ---------- the poll ----------
task.spawn(function()
	while script.Parent do
		local t = now()
		for _, p in ipairs(Players:GetPlayers()) do
			local root, c = rootOf(p)
			local menu = p:GetAttribute("InMenu") == true
			local inZone = root ~= nil and not menu and HubRules.inZone(root.Position, zones)
			if c then
				if wasIn[p] == true and not inZone and root then c:SetAttribute("HubGuardUntil", t + HubRules.GUARD) end
				wasIn[p] = inZone
				setIf(c, "HubInZone", inZone)
				setIf(c, "HubSafe", HubRules.protected(inZone, c:GetAttribute("HubGuardUntil"), t))
			end
			-- portals
			local here
			if root and not menu then
				for _, po in ipairs(portals) do
					if HubRules.inShape(root.Position, po.part.CFrame, po.part.Size, "box") then here = po.mode break end
				end
			end
			if here and inPortal[p] ~= here then startTrip(p, here) end
			inPortal[p] = here
			-- cancels / drops
			local trip = tripOf[p]
			if trip and not trip.dead and trip.phase == "count" then -- v1.1: only during the countdown
				if p == trip.starter then
					if (not trip.noPortal and here ~= trip.mode) or not root or menu
						or SquadRules.idOfPlayer(p) ~= trip.squadId then
						finish(trip, "cancelled")
					end
				elseif SquadRules.idOfPlayer(p) ~= trip.squadId then
					drop(trip, p)
				end
			end
		end
		task.wait(HubRules.POLL)
	end
end)

-- ---------- test hook (server only) ----------
local hook = script:FindFirstChild("HubTest")
if not hook then
	hook = Instance.new("BindableFunction")
	hook.Name = "HubTest"
	hook.Parent = script
end
hook.OnInvoke = function(action, p, mode)
	if action == "trip" then
		if typeof(p) ~= "Instance" or not p:IsA("Player") then return "badArg" end
		return startTrip(p, mode, true)
	elseif action == "cancel" then
		local t = typeof(p) == "Instance" and tripOf[p]
		if t then finish(t, "cancelled") return "ok" end
		return "noTrip"
	elseif action == "state" then
		local n = 0
		for _ in pairs(tripOf) do n += 1 end
		return ("state %s kind %s zones %d portals %d spawns %d inTrips %d"):format(script:GetAttribute("HubState"), KIND, #zones,
			#portals, #spawns, n)
	end
	return "badArg"
end
