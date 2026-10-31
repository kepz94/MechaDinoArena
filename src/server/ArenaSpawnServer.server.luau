-- ArenaSpawnServer v1.0 (Mecha Dino Arena) — spread spawn points for the Arena place (Kepu 2026-10-31: "allow different
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
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
local SETTLE, SETTLE_RESPAWN = 0.15, 0.3

script:SetAttribute("ArenaSpawnServerVersion", VERSION)
if script:GetAttribute("ArenaSpawnsEnabled") == nil then script:SetAttribute("ArenaSpawnsEnabled", true) end
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

local moves = 0
local function place(player, char, reason)
	if not on() or player.Character ~= char or not char.Parent then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local p, i = choose(player)
	if not p then return end
	local pos = p.Position + Vector3.new(0, p.Size.Y / 2 + standOffset(char), 0)
	local dir
	local island = workspace:FindFirstChild("DinoIsland")
	if island and island:IsA("Model") then
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
