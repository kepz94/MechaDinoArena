-- ArenaSpawnServer v1.2 (Mecha Dino Arena) — spread spawn points for the Arena place (Kepu 2026-10-31: "allow different
-- spawn points on the arena map because im going to have an actual group test"; picked "8 spots around the island",
-- "Farthest from other players", "Arena: Play + respawn"). Map: docs/reference/arena/arena_spawns_map.jpg.
-- Spawn points: the BaseParts in Workspace.ArenaSpawns (ArenaSpawn1..8, invisible, anchored, no collide / query / touch;
--   placed in Studio on flat dry ground clear of trees / rocks in a ring around the island; ArenaSpawn1 = the beach
--   SpawnLocation spot). Drag them in Studio to move a spawn; add or remove parts to change the count.
-- Only in the Arena (ModeRules.currentMode() == "arena"; in Studio the Workspace attribute ModeTestArena = true).
--   The Sandbox keeps the SpawnLocation.
-- When a player is placed on a spawn point:
--   * Play: the player attribute InMenu turns false (ModeServer "play", which first stands the dino on the SpawnLocation):
--     SETTLE (0.15) s later the current character is moved.
--   * Respawn: after the character's Humanoid died, the next character that is the player's own dino (character
--     Species == player DinoSpecies, i.e. after SpeciesServer's swap) while not InMenu is moved SETTLE_RESPAWN (0.3) s
--     after it appears.
--   * First body of a session that starts outside the menu (a trip from the Sandbox, ModeServer 1.1 mdaPlay): the same.
-- Which point: the one whose nearest other player (alive, not in the menu, root known) is farthest away; with no other
--   players, a random one. Placed standing on the point (root height = part top + root half height + HipHeight), facing
--   the centre of Workspace.DinoIsland's bounding box, and the camera turned the same way through ShoulderCam's hook
--   (character ShoulderCamLookAt, cleared 1 s later), as ModeServer 1.2 does for the SpawnLocation.
-- Switch: script attribute ArenaSpawnsEnabled (default true, read at each placement; false = everyone on the SpawnLocation
--   as before).
-- Diagnostics: script ArenaSpawnServerVersion, ArenaSpawnMode, ArenaSpawnPoints (count), ArenaSpawnMoves; player
--   ArenaSpawnIndex (the point used), ArenaSpawnReason ("play" / "respawn" / "join"), ArenaSpawnAt (server time).
-- v1.1 (Kepu 2026-10-31 after the group test: "the spawns feel too far apart. When it's only a few people in the lobby keep
--   the spawns near"; picked "Spawn near another player" up to "4 players"): while the server has at most
--   ArenaSpawnNearMaxPlayers (script attribute, default 4) players and at least one other player is alive and out of the
--   menu, the player lands NEAR_MIN..NEAR_MAX (60..120) studs from one of those players (picked at random): up to
--   NEAR_TRIES (30) random spots around them are tried; a spot counts when the ground there is Workspace.DinoIsland.Ground,
--   dry (height >= 0) and flat (normal Y > 0.9), no Trees / Rocks / MountainSteps / EdgeWalls part is within 18 studs,
--   and every other live player is at least NEAR_MIN studs away. Facing: toward that player. No such spot, no other
--   live player, or more players than the limit -> the 1.0 ring rule. Diagnostics: player ArenaSpawnKind ("near" /
--   "ring"), ArenaSpawnIndex 0 for a near spawn, ArenaSpawnNearTo (the other player's name). Switch: script attribute
--   ArenaSpawnNearEnabled (default true, read at each placement; false = 1.0).
-- v1.2 (Arena squads, MDA-161, plan docs/plans/SQUADS_v1.0.md Task S4; Kepu 2026-10-31 picked "respawn near a squadmate"):
--   before the 1.1 rules, when the player has a live squadmate (SquadRules 1.0 same: alive, not in the menu, root known), up
--   to NEAR_TRIES random spots SQUAD_MIN..SQUAD_MAX (30..60) studs from one of them (picked at random) are tried with the
--   1.1 ground / clear checks (DinoIsland.Ground, dry, flat, no Trees / Rocks / MountainSteps / EdgeWalls within 18 studs);
--   every live NON-squad player must be at least NEAR_MIN (60) studs away. Facing: toward that squadmate. Any lobby size.
--   No spot / no live squadmate -> the 1.1 rules (near, then ring). Diagnostics: player ArenaSpawnKind "squad",
--   ArenaSpawnNearTo (the squadmate's name), ArenaSpawnIndex 0. Switch: script attribute ArenaSpawnSquadEnabled (default
--   true, read at each placement; false = 1.1).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.2"
local SETTLE, SETTLE_RESPAWN = 0.15, 0.3

script:SetAttribute("ArenaSpawnServerVersion", VERSION)
if script:GetAttribute("ArenaSpawnsEnabled") == nil then script:SetAttribute("ArenaSpawnsEnabled", true) end
for k, v in pairs({ArenaSpawnNearEnabled = true, ArenaSpawnNearMaxPlayers = 4}) do -- v1.1
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local NEAR_MIN, NEAR_MAX, NEAR_TRIES = 60, 120, 30 -- v1.1
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("ArenaSpawnMode", MODE)

local function points()
	local f = workspace:FindFirstChild("ArenaSpawns")
	local list = {}
	if f then
		for _, p in ipairs(f:GetChildren()) do
			if p:IsA("BasePart") then table.insert(list, p) end
		end
	end
	table.sort(list, function(a, b) return a.Name < b.Name end)
	script:SetAttribute("ArenaSpawnPoints", #list)
	return list
end
points()

local function on()
	return MODE == "arena" and script:GetAttribute("ArenaSpawnsEnabled") ~= false
end

local function standOffset(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp and hum then return hrp.Size.Y / 2 + hum.HipHeight end
	return 5
end

local function choose(player)
	local list = points()
	if #list == 0 then return nil end
	local others = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl ~= player and pl.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if r and hum and hum.Health > 0 and pl:GetAttribute("InMenu") ~= true then table.insert(others, r.Position) end
	end
	if #others == 0 then
		local i = math.random(1, #list)
		return list[i], i
	end
	local best, bestI, bestD
	for i, p in ipairs(list) do
		local near = math.huge
		for _, o in ipairs(others) do near = math.min(near, (o - p.Position).Magnitude) end
		if not bestD or near > bestD then best, bestI, bestD = p, i, near end
	end
	return best, bestI
end

-- v1.1: a spot near another player while the lobby is small; returns ground point, that player's name, their position
local function nearSpot(player)
	if script:GetAttribute("ArenaSpawnNearEnabled") == false then return nil end
	if #Players:GetPlayers() > (tonumber(script:GetAttribute("ArenaSpawnNearMaxPlayers")) or 4) then return nil end
	local island = workspace:FindFirstChild("DinoIsland")
	local groundF = island and island:FindFirstChild("Ground")
	if not groundF then return nil end
	local live = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl ~= player and pl.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if r and hum and hum.Health > 0 and pl:GetAttribute("InMenu") ~= true then table.insert(live, {pl = pl, pos = r.Position}) end
	end
	if #live == 0 then return nil end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = {groundF}
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	local block = {}
	for _, n in ipairs({"Trees", "Rocks", "MountainSteps", "EdgeWalls"}) do
		local f = island:FindFirstChild(n)
		if f then table.insert(block, f) end
	end
	op.FilterDescendantsInstances = block
	local anchor = live[math.random(1, #live)]
	for _ = 1, NEAR_TRIES do
		local a = math.random() * 2 * math.pi
		local d = NEAR_MIN + math.random() * (NEAR_MAX - NEAR_MIN)
		local x, z = anchor.pos.X + math.cos(a) * d, anchor.pos.Z + math.sin(a) * d
		local hit = workspace:Raycast(Vector3.new(x, anchor.pos.Y + 300, z), Vector3.new(0, -800, 0), rp)
		if hit and hit.Position.Y >= 0 and hit.Normal.Y > 0.9
			and #workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 12, 0)), Vector3.new(36, 22, 36), op) == 0 then
			local clear = true
			for _, o in ipairs(live) do
				if Vector3.new(o.pos.X - x, 0, o.pos.Z - z).Magnitude < NEAR_MIN then clear = false break end
			end
			if clear then return hit.Position, anchor.pl.Name, anchor.pos end
		end
	end
	return nil
end

-- v1.2: a spot near a live squadmate (any lobby size); returns ground point, squadmate name, their position
if script:GetAttribute("ArenaSpawnSquadEnabled") == nil then script:SetAttribute("ArenaSpawnSquadEnabled", true) end
local SQUAD_MIN, SQUAD_MAX = 30, 60
local squadMod
local function squadSpot(player)
	if script:GetAttribute("ArenaSpawnSquadEnabled") == false then return nil end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return nil end
		local ok, mod = pcall(require, m)
		if not ok then return nil end
		squadMod = mod
	end
	if not squadMod.live() then return nil end
	local island = workspace:FindFirstChild("DinoIsland")
	local groundF = island and island:FindFirstChild("Ground")
	if not groundF then return nil end
	local mates, others = {}, {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl ~= player and pl.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if r and hum and hum.Health > 0 and pl:GetAttribute("InMenu") ~= true then
			if squadMod.same(player, pl) then table.insert(mates, {pl = pl, pos = r.Position})
			else table.insert(others, r.Position) end
		end
	end
	if #mates == 0 then return nil end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = {groundF}
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	local block = {}
	for _, n in ipairs({"Trees", "Rocks", "MountainSteps", "EdgeWalls"}) do
		local f = island:FindFirstChild(n)
		if f then table.insert(block, f) end
	end
	op.FilterDescendantsInstances = block
	local anchor = mates[math.random(1, #mates)]
	for _ = 1, NEAR_TRIES do
		local a = math.random() * 2 * math.pi
		local d = SQUAD_MIN + math.random() * (SQUAD_MAX - SQUAD_MIN)
		local x, z = anchor.pos.X + math.cos(a) * d, anchor.pos.Z + math.sin(a) * d
		local hit = workspace:Raycast(Vector3.new(x, anchor.pos.Y + 300, z), Vector3.new(0, -800, 0), rp)
		if hit and hit.Position.Y >= 0 and hit.Normal.Y > 0.9
			and #workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 12, 0)), Vector3.new(36, 22, 36), op) == 0 then
			local clear = true
			for _, o in ipairs(others) do
				if Vector3.new(o.X - x, 0, o.Z - z).Magnitude < NEAR_MIN then clear = false break end
			end
			if clear then return hit.Position, anchor.pl.Name, anchor.pos end
		end
	end
	return nil
end

local moves = 0
local function place(player, char, reason)
	if not on() or player.Character ~= char or not char.Parent then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local pos, i, dir, nearTo
	local kind -- v1.2
	local g, who, whoPos = squadSpot(player) -- v1.2
	if g then kind = "squad" else g, who, whoPos = nearSpot(player) end -- v1.1
	if g then
		pos, i, nearTo = g + Vector3.new(0, standOffset(char), 0), 0, who
		local d = Vector3.new(whoPos.X - pos.X, 0, whoPos.Z - pos.Z)
		if d.Magnitude > 1 then dir = d.Unit end
	else
		local p, pi = choose(player)
		if not p then return end
		pos, i = p.Position + Vector3.new(0, p.Size.Y / 2 + standOffset(char), 0), pi
	end
	local island = workspace:FindFirstChild("DinoIsland")
	if not dir and island and island:IsA("Model") then
		local cf = island:GetBoundingBox()
		local d = Vector3.new(cf.Position.X - pos.X, 0, cf.Position.Z - pos.Z)
		if d.Magnitude > 1 then dir = d.Unit end
	end
	dir = dir or Vector3.new(0, 0, -1)
	char:PivotTo(CFrame.lookAt(pos, pos + dir))
	hrp.AssemblyLinearVelocity = Vector3.zero
	char:SetAttribute("ShoulderCamLookAt", pos + dir * 500)
	task.delay(1, function()
		if char.Parent then char:SetAttribute("ShoulderCamLookAt", nil) end
	end)
	moves += 1
	script:SetAttribute("ArenaSpawnMoves", moves)
	player:SetAttribute("ArenaSpawnIndex", i)
	player:SetAttribute("ArenaSpawnKind", kind or (nearTo and "near" or "ring")) -- v1.1; v1.2 "squad"
	player:SetAttribute("ArenaSpawnNearTo", nearTo or "")
	player:SetAttribute("ArenaSpawnReason", reason)
	player:SetAttribute("ArenaSpawnAt", workspace:GetServerTimeNow()) -- last
end

local function onPlayer(player)
	local pending = false -- a death is waiting for its respawn
	local first = true -- the first own body of the session
	player:GetAttributeChangedSignal("InMenu"):Connect(function()
		if player:GetAttribute("InMenu") == false then
			first = false
			task.delay(SETTLE, function()
				local c = player.Character
				if c then place(player, c, "play") end
			end)
		end
	end)
	local function onChar(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then hum.Died:Connect(function() pending = true end) end
		local want = player:GetAttribute("DinoSpecies")
		local own = want == nil or char:GetAttribute("Species") == want
		if not own or player:GetAttribute("InMenu") == true then return end
		if pending or first then
			local reason = pending and "respawn" or "join"
			pending, first = false, false
			task.delay(SETTLE_RESPAWN, function() place(player, char, reason) end)
		end
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then task.spawn(onChar, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
