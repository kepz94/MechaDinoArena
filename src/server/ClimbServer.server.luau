-- ClimbServer v1.0 (Mecha Dino Arena) — the server side of the Herrerasaurus' auto-climb. MDA-138, plan
-- docs/plans/HERRERA_KIT_v1.0.md Task 6 (Kepu 2026-10-30: "climbing should just happen").
-- The climb itself runs on the owner's client (ClimbTest 1.0; the body is client-owned physics). This script:
--   * copies ServerStorage.DinoArcade.ClimbLogic to ReplicatedStorage.ClimbShared.ClimbLogic so the client can require it;
--   * stamps the state the owner reports, so every client's IdleAnimation (climb pose) and the server's ScurryHitbox
--     (climb hitboxes) and SlashServer (dive allowed) see it.
-- Remote ReplicatedStorage.DinoClimbState (RemoteEvent): FireServer(state, treeName)
--   state "ground" / "climbing" / "clinging" / "top"; treeName = a child of Workspace.DinoIsland.Trees or "" (ground).
--   Checks in order: "badArg" (not a known state / name not a string), "disabled" (script switch off or the character's
--   ClimbEnabled not true), "dead", "menu" (player InMenu), "noTree" (state other than ground and no such tree), "far"
--   (state other than ground and the body more than FAR_DIST x scale from that tree's bounding box) -> "ok": character
--   attributes ClimbState, ClimbTree, ClimbAt (server time, last). A refused report leaves the stamps as they were;
--   a death stamps ClimbState "ground".
-- Switch: script attribute ClimbServerEnabled (default true).
-- Diagnostics: script ClimbServerVersion, ClimbShared ("ready" / "missing"); player ClimbServerResult.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
local STATES = {ground = true, climbing = true, clinging = true, top = true}
local FAR_DIST = 12

script:SetAttribute("ClimbServerVersion", VERSION)
if script:GetAttribute("ClimbServerEnabled") == nil then script:SetAttribute("ClimbServerEnabled", true) end

-- shared logic for the client
do
	local da = ServerStorage:FindFirstChild("DinoArcade")
	local src = da and da:FindFirstChild("ClimbLogic")
	if src then
		local folder = ReplicatedStorage:FindFirstChild("ClimbShared") or Instance.new("Folder")
		folder.Name = "ClimbShared"
		local old = folder:FindFirstChild("ClimbLogic")
		if old then old:Destroy() end
		src:Clone().Parent = folder
		folder.Parent = ReplicatedStorage
		script:SetAttribute("ClimbShared", "ready")
	else
		script:SetAttribute("ClimbShared", "missing")
	end
end

local remote = ReplicatedStorage:FindFirstChild("DinoClimbState")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoClimbState"
	remote.Parent = ReplicatedStorage
end

local function trees()
	local island = workspace:FindFirstChild("DinoIsland")
	return island and island:FindFirstChild("Trees")
end

local function result(player, r)
	player:SetAttribute("ClimbServerResult", r)
end

remote.OnServerEvent:Connect(function(player, state, treeName)
	if type(state) ~= "string" or not STATES[state] or (treeName ~= nil and type(treeName) ~= "string") then
		return result(player, "badArg")
	end
	local char = player.Character
	if script:GetAttribute("ClimbServerEnabled") == false or not char or char:GetAttribute("ClimbEnabled") ~= true then
		return result(player, "disabled")
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not hrp then return result(player, "dead") end
	if player:GetAttribute("InMenu") == true then return result(player, "menu") end
	local name = treeName or ""
	if state ~= "ground" then
		local folder = trees()
		local tree = folder and name ~= "" and folder:FindFirstChild(name)
		if not tree then return result(player, "noTree") end
		local cf, size = tree:GetBoundingBox()
		local p = cf:PointToObjectSpace(hrp.Position)
		local h = size / 2
		local out = Vector3.new(math.max(0, math.abs(p.X) - h.X), math.max(0, math.abs(p.Y) - h.Y), math.max(0, math.abs(p.Z) - h.Z))
		if out.Magnitude > FAR_DIST * char:GetScale() then return result(player, "far") end
	else
		name = ""
	end
	char:SetAttribute("ClimbState", state)
	char:SetAttribute("ClimbTree", name)
	char:SetAttribute("ClimbAt", workspace:GetServerTimeNow())
	result(player, "ok")
end)

local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			if char.Parent and char:GetAttribute("ClimbState") and char:GetAttribute("ClimbState") ~= "ground" then
				char:SetAttribute("ClimbState", "ground")
				char:SetAttribute("ClimbTree", "")
				char:SetAttribute("ClimbAt", workspace:GetServerTimeNow())
			end
		end)
	end
end
local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
