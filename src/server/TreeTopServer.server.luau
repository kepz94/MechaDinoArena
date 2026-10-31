-- TreeTopServer v1.0 (Mecha Dino Arena) — Herrera-only standable tree tops. MDA-136, plan docs/plans/HERRERA_KIT_v1.0.md
-- Task 4, mockup docs/mockups/herrera_kit_options.html (Kepu 2026-10-30: "make the top of the trees and palms itself be
-- able to stand on" -> "Herrera only").
-- The island's own tree parts are not touched (their leaves stay CanCollide false for every dino). Instead each tree gets
-- invisible proxy parts in Workspace.DinoIsland.TreeTops, in the collision group "TreeTop", which collides only with the
-- group "HerreraBody"; a Herrera's HumanoidRootPart (its only body part that collides) is put in "HerreraBody".
--   JungleTree_*   one proxy per Canopy / Canopy2 / Canopy3 / CanopySide (same CFrame and size)
--   Pine_*         one proxy per Leaves1-4 (same CFrame and size; LeavesTip is too small to stand on)
--   CoconutPalm_*  one flat round pad (cylinder, axis vertical) centred on the Crown: diameter PALM_PAD_SPAN x the
--                  furthest frond centre's horizontal distance x 2, PAD_THICK thick, top at the highest frond / tuft
--                  centre + FROND_HALF
-- Proxies: Anchored, Transparency 1, CanCollide true, CanQuery false (no raycast in the game sees them), CanTouch false,
--   CastShadow false, attributes TreeTopOf (tree name), TreeTopKind ("jungle" / "pine" / "palm"), TreeTopTopY (world Y of
--   the top face, for ClimbTest's mantle).
-- "HerreraBody" collides with every registered group exactly like "Default" (copied at start and again after
--   GROUP_RECOPY s for groups registered later, e.g. DinoHitbox), so a Herrera stands, walks and is blocked like any dino
--   everywhere else; "TreeTop" collides with nothing but "HerreraBody".
-- Herrera characters: CharacterAdded (and characters already there) with Species "Herrera" -> HumanoidRootPart
--   CollisionGroup "HerreraBody".
-- Switch: script attribute TreeTopEnabled (default true, read at start; false = no proxies, no group change).
-- Diagnostics (script): TreeTopVersion, TreeTopState ("ready" / "off" / "noTrees"), TreeTopCountJungle / Pine / Palm,
--   TreeTopTrees (trees that got at least one proxy); character TreeTopBody (true once its HRP is in HerreraBody).
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local VERSION = "1.0"
local BODY, TOP = "HerreraBody", "TreeTop"
local JUNGLE_PARTS = {Canopy = true, Canopy2 = true, Canopy3 = true, CanopySide = true}
local PINE_PARTS = {Leaves1 = true, Leaves2 = true, Leaves3 = true, Leaves4 = true}
local PALM_PAD_SPAN = 0.8
local PAD_THICK = 0.6
local FROND_HALF = 0.25
local GROUP_RECOPY = 3

script:SetAttribute("TreeTopVersion", VERSION)
if script:GetAttribute("TreeTopEnabled") == nil then script:SetAttribute("TreeTopEnabled", true) end
if script:GetAttribute("TreeTopEnabled") == false then
	script:SetAttribute("TreeTopState", "off")
	return
end

pcall(function() PhysicsService:RegisterCollisionGroup(BODY) end)
pcall(function() PhysicsService:RegisterCollisionGroup(TOP) end)
local function copyGroups()
	for _, g in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
		local name = g.name
		if name ~= BODY and name ~= TOP then
			PhysicsService:CollisionGroupSetCollidable(BODY, name, PhysicsService:CollisionGroupsAreCollidable("Default", name))
			PhysicsService:CollisionGroupSetCollidable(TOP, name, false)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(BODY, BODY, PhysicsService:CollisionGroupsAreCollidable("Default", "Default"))
	PhysicsService:CollisionGroupSetCollidable(TOP, TOP, false)
	PhysicsService:CollisionGroupSetCollidable(BODY, TOP, true)
end
copyGroups()
task.delay(GROUP_RECOPY, copyGroups)

local island = workspace:FindFirstChild("DinoIsland")
local trees = island and island:FindFirstChild("Trees")
if not trees then
	script:SetAttribute("TreeTopState", "noTrees")
	return
end
local old = island:FindFirstChild("TreeTops")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "TreeTops"

local function proxy(tree, kind, cf, size, shape)
	local p = Instance.new("Part")
	p.Name = "TreeTop_" .. tree.Name
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.CollisionGroup = TOP
	p:SetAttribute("TreeTopOf", tree.Name)
	p:SetAttribute("TreeTopKind", kind)
	-- top face: the highest corner of the box (a cylinder pad is level, so its centre + half thickness)
	local top
	if shape == Enum.PartType.Cylinder then
		top = cf.Position.Y + PAD_THICK / 2
	else
		local h = size / 2
		top = cf.Position.Y + math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z
	end
	p:SetAttribute("TreeTopTopY", math.floor(top * 100 + 0.5) / 100)
	p.Parent = folder
	return p
end

local counts = {jungle = 0, pine = 0, palm = 0}
local treeCount = 0
for _, tree in ipairs(trees:GetChildren()) do
	local kind = tree.Name:match("^JungleTree_") and "jungle" or tree.Name:match("^Pine_") and "pine"
		or tree.Name:match("^CoconutPalm_") and "palm" or nil
	local made = 0
	if kind == "jungle" or kind == "pine" then
		local names = kind == "jungle" and JUNGLE_PARTS or PINE_PARTS
		for _, part in ipairs(tree:GetDescendants()) do
			if part:IsA("BasePart") and names[part.Name] then
				proxy(tree, kind, part.CFrame, part.Size)
				made += 1
			end
		end
	elseif kind == "palm" then
		local crown = tree:FindFirstChild("Crown", true)
		if crown then
			local c = crown.Position
			local reach, topY = 0, -math.huge
			for _, part in ipairs(tree:GetDescendants()) do
				if part:IsA("BasePart") and (part.Name == "Frond" or part.Name == "Tuft") then
					local d = Vector3.new(part.Position.X - c.X, 0, part.Position.Z - c.Z).Magnitude
					reach = math.max(reach, d)
					topY = math.max(topY, part.Position.Y)
				end
			end
			if topY > -math.huge then
				local dia = math.max(4, reach * 2 * PALM_PAD_SPAN)
				local top = topY + FROND_HALF
				-- cylinder axis is the part's X: turn it upright
				local cf = CFrame.new(c.X, top - PAD_THICK / 2, c.Z) * CFrame.Angles(0, 0, math.rad(90))
				proxy(tree, kind, cf, Vector3.new(PAD_THICK, dia, dia), Enum.PartType.Cylinder)
				made += 1
			end
		end
	end
	if made > 0 then
		counts[kind] += made
		treeCount += 1
	end
end
folder.Parent = island
script:SetAttribute("TreeTopCountJungle", counts.jungle)
script:SetAttribute("TreeTopCountPine", counts.pine)
script:SetAttribute("TreeTopCountPalm", counts.palm)
script:SetAttribute("TreeTopTrees", treeCount)
script:SetAttribute("TreeTopState", "ready")

-- Herrera bodies
local function onCharacter(char)
	if char:GetAttribute("Species") ~= "Herrera" then return end
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if hrp then
		hrp.CollisionGroup = BODY
		char:SetAttribute("TreeTopBody", true)
	end
end
local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
