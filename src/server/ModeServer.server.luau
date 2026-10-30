-- ModeServer v1.1 (Mecha Dino Arena) — main menu state, the lobby pad and the hop between the Sandbox and Arena places.
-- MDA-87, plan docs/plans/MAIN_MENU_v1.0.md Task 3, ADR-005, mockup docs/mockups/main_menu_options.html (layout A).
-- Kepu 2026-10-29: menu on join in both places; ◀ ▶ respawn behind the menu; Arena = a second place (75433819286625).
-- Mode of this server: ServerStorage.DinoArcade.ModeRules 1.0 currentMode() -> player attribute DinoMode.
-- Client -> server: ReplicatedStorage.DinoModeRequest:FireServer(action), action = "play" / "sandbox" / "arena" / "menu".
--   "play", or the action naming this server's mode -> leave the menu: InMenu = false, the character is unanchored and
--     moved standing onto the SpawnLocation. Already playing -> nothing moves.
--   "menu" -> InMenu = true, the character is parked on the lobby pad. Already in the menu -> nothing moves.
--   the other mode -> hop: Studio -> "studio" (teleports do not run in Studio); target place id 0 -> "noArenaPlace";
--     else save wait (below) then TeleportService:TeleportAsync(target, {player}) -> "teleporting", error ->
--     "teleportFailed" (the player stays in the menu; also on TeleportService.TeleportInitFailed).
--   anything else -> "badArg". A hop still in progress -> "busy" for every new request.
-- Result: player attribute ModeLastResult ("ok" / "badArg" / "busy" / "saving" / "teleporting" / "teleportFailed" /
--   "studio" / "noArenaPlace"), then ModeLastAt (server time, last: clients react to it).
-- Save wait (SkillServer is not changed): skill data is saved at most every 10 s and on leave. ModeServer notes the last
--   change it can see (a SkillRequest from the player, or the player attribute SkillLastXp changing). If that was less
--   than SAVE_WAIT (12) s ago, ModeLastResult = "saving" until SkillSaveState becomes "saved" after it, or SAVE_WAIT s
--   have passed since it; then the teleport.
-- Lobby pad: Part "MenuLobbyPad" in Workspace, PAD_HEIGHT (600) studs above the SpawnLocation, 400 x 2 x 400, anchored,
--   Transparency 1, CanCollide true, CanQuery / CanTouch false. Each player in the menu gets a parking slot (lowest free
--   number n): pad top + (n - 1) x SLOT_GAP (40) along X, standing, HumanoidRootPart anchored. CharacterAdded while
--   InMenu (dino switch, death respawn) -> parked again.
-- On join: InMenu = true (the menu opens; MainMenu 1.0 reads it).
-- Switch: script attribute ModeServerEnabled (default true), read at start. false -> no pad, InMenu never set, the remote
--   answers nothing: today's spawn.
-- Diagnostics: script attributes ModeServerVersion, ModeServerState ("on" / "off"), ModeServerMode; player attributes
--   DinoMode, InMenu, ModeLastResult, ModeLastAt, ModeParkSlot (0 = not parked).
-- v1.1 (Kepu 2026-10-29: pressing ARENA in the Sandbox goes "Straight into play"): a hop sends TeleportOptions with
--   teleport data {mdaPlay = true, mdaFrom = this mode}. On join, when the player's GetJoinData().TeleportData is a table
--   with mdaPlay == true, the menu is skipped: InMenu = false, nothing is parked (normal spawn); EggLoader 1.1 keeps the
--   egg up until the dino stands on the island. Teleport data only skips the menu (nothing else reads it). Switch:
--   script attribute ModeTripPlayEnabled (default true, read at start; false = 1.0: menu on every join, no teleport
--   data). Diagnostic: player attribute ModeArrivedPlay (true when the menu was skipped for a trip).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")

local VERSION = "1.1"
local PAD_HEIGHT = 600
local PAD_SIZE = Vector3.new(400, 2, 400)
local SLOT_GAP = 40
local SAVE_WAIT = 12

script:SetAttribute("ModeServerVersion", VERSION)
if script:GetAttribute("ModeTripPlayEnabled") == nil then script:SetAttribute("ModeTripPlayEnabled", true) end -- v1.1
local tripPlay = script:GetAttribute("ModeTripPlayEnabled") ~= false -- v1.1
if script:GetAttribute("ModeServerEnabled") == nil then script:SetAttribute("ModeServerEnabled", true) end

local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("ModeServerMode", MODE)

local remote = ReplicatedStorage:FindFirstChild("DinoModeRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoModeRequest"
	remote.Parent = ReplicatedStorage
end

if script:GetAttribute("ModeServerEnabled") == false then
	script:SetAttribute("ModeServerState", "off")
	return
end
script:SetAttribute("ModeServerState", "on")

local function now() return workspace:GetServerTimeNow() end

local function spawnPart()
	return workspace:FindFirstChildWhichIsA("SpawnLocation", true)
end

local pad = workspace:FindFirstChild("MenuLobbyPad")
if not pad then
	local sp = spawnPart()
	local base = sp and sp.Position or Vector3.zero
	pad = Instance.new("Part")
	pad.Name = "MenuLobbyPad"
	pad.Size = PAD_SIZE
	pad.Anchored = true
	pad.Transparency = 1
	pad.CanCollide = true
	pad.CanQuery = false
	pad.CanTouch = false
	pad.Position = base + Vector3.new(0, PAD_HEIGHT, 0)
	pad.Parent = workspace
end

local slots = {} -- [n] = player
local busy = {} -- [player] = true while a hop runs
local lastChange = {} -- [player] = os.clock() of the last skill change seen
local savedAt = {} -- [player] = os.clock() of the last SkillSaveState "saved"

local function result(player, r)
	player:SetAttribute("ModeLastResult", r)
	player:SetAttribute("ModeLastAt", now())
end

local function freeSlot(player)
	for n, p in pairs(slots) do
		if p == player then slots[n] = nil end
	end
	player:SetAttribute("ModeParkSlot", 0)
end

local function slotOf(player)
	for n, p in pairs(slots) do
		if p == player then return n end
	end
	local n = 1
	while slots[n] do n += 1 end
	slots[n] = player
	return n
end

local function standOffset(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp and hum then
		return hrp.Size.Y / 2 + hum.HipHeight
	else
		return 5
	end
end

local function park(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local n = slotOf(player)
	player:SetAttribute("ModeParkSlot", n)
	local x = -PAD_SIZE.X / 2 + 20 + (n - 1) * SLOT_GAP
	local pos = pad.Position + Vector3.new(x, PAD_SIZE.Y / 2 + standOffset(char), 0)
	hrp.Anchored = true
	char:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
end

local function unpark(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	freeSlot(player)
	if not hrp then return end
	local sp = spawnPart()
	local base = sp and (sp.Position + Vector3.new(0, sp.Size.Y / 2, 0)) or Vector3.zero
	local pos = base + Vector3.new(0, standOffset(char), 0)
	char:PivotTo(CFrame.new(pos))
	hrp.Anchored = false
end

local function hop(player, target)
	if RunService:IsStudio() then
		result(player, "studio")
		return
	elseif target == 0 then
		result(player, "noArenaPlace")
		return
	end
	busy[player] = true
	local last = lastChange[player]
	if last and os.clock() - last < SAVE_WAIT then
		result(player, "saving")
		while player.Parent and os.clock() - last < SAVE_WAIT and not ((savedAt[player] or 0) > last) do
			task.wait(0.25)
		end
	end
	if not player.Parent then
		busy[player] = nil
		return
	end
	result(player, "teleporting")
	local ok = pcall(function()
		if tripPlay then -- v1.1: the arriving server skips the menu
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData({mdaPlay = true, mdaFrom = MODE})
			TeleportService:TeleportAsync(target, {player}, options)
		else
			TeleportService:TeleportAsync(target, {player})
		end
	end)
	if not ok then
		result(player, "teleportFailed")
	end
	busy[player] = nil
end

remote.OnServerEvent:Connect(function(player, action)
	if busy[player] then
		result(player, "busy")
		return
	end
	if action == "play" or action == MODE then
		if player:GetAttribute("InMenu") == true then
			player:SetAttribute("InMenu", false)
			unpark(player)
		end
		result(player, "ok")
	elseif action == "menu" then
		if player:GetAttribute("InMenu") ~= true then
			player:SetAttribute("InMenu", true)
			park(player)
		end
		result(player, "ok")
	elseif action == "sandbox" then
		task.spawn(hop, player, ModeRules.SANDBOX_PLACE_ID)
	elseif action == "arena" then
		task.spawn(hop, player, ModeRules.ARENA_PLACE_ID)
	else
		result(player, "badArg")
	end
end)

-- a teleport that was sent but failed on the way (place not published, full, ...) -> the player stays in the menu
TeleportService.TeleportInitFailed:Connect(function(player)
	if player and player.Parent then result(player, "teleportFailed") end
end)

-- skill changes the save wait looks at (read only)
task.spawn(function() -- does not hold up the join handling below
	local skillRemote = ReplicatedStorage:WaitForChild("SkillRequest", 30)
	if skillRemote then
		skillRemote.OnServerEvent:Connect(function(player)
			lastChange[player] = os.clock()
		end)
	end
end)

local function onPlayer(player)
	player:SetAttribute("DinoMode", MODE)
	player:SetAttribute("ModeParkSlot", 0)
	local arrivedPlay = false -- v1.1
	if tripPlay then
		local okJd, jd = pcall(function() return player:GetJoinData() end)
		local td = okJd and type(jd) == "table" and jd.TeleportData or nil
		if type(td) == "table" and td.mdaPlay == true then arrivedPlay = true end
	end
	player:SetAttribute("ModeArrivedPlay", arrivedPlay)
	if arrivedPlay then
		player:SetAttribute("InMenu", false)
	else
		player:SetAttribute("InMenu", true)
	end
	player:GetAttributeChangedSignal("SkillLastXp"):Connect(function()
		lastChange[player] = os.clock()
	end)
	player:GetAttributeChangedSignal("SkillSaveState"):Connect(function()
		if player:GetAttribute("SkillSaveState") == "saved" then savedAt[player] = os.clock() end
	end)
	local function onChar(char)
		if player:GetAttribute("InMenu") ~= true then return end
		char:WaitForChild("HumanoidRootPart", 10)
		task.defer(function()
			if player.Character == char and player:GetAttribute("InMenu") == true then park(player) end
		end)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then onChar(player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(player)
	freeSlot(player)
	busy[player], lastChange[player], savedAt[player] = nil, nil, nil
end)
