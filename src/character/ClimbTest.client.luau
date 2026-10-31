-- ClimbTest v1.2 (Mecha Dino Arena) — the Herrerasaurus' auto-climb on the owner's client. MDA-138, plan
-- docs/plans/HERRERA_KIT_v1.0.md Task 6 (Kepu 2026-10-30: "climbing should just happen. If I walk up to a tree as a herra
-- it should automatically start climbing the tree vertically"; tree tops standable for the Herrera only).
-- Runs on characters with ClimbEnabled = true (HerreraModelData 1.2); does nothing on other dinos.
-- Each frame: reads the move input (PlayerModule controls: forward / back) and Space (JumpRequest), probes the world and
--   runs ClimbLogic.step (ReplicatedStorage.ClimbShared.ClimbLogic, copied there by ClimbServer 1.0):
--   trunkAhead  ray along the body's facing from the HumanoidRootPart, against the island's trunk parts (Trees
--               descendants named Trunk*), minus the HRP's half length
--   trunkEnds   the same ray from ClimbHeadReach x scale higher misses
--   topAbove    lowest underside of a tree-top proxy (Workspace.DinoIsland.TreeTops, TreeTopServer 1.0) whose
--               footprint holds the body, minus (HRP top + ClimbHeadReach x scale)
--   groundBelow ray down from the HRP (this model excluded) minus the HRP half height and HipHeight
--   onTop       a proxy whose footprint holds the body has its top within 1.5 studs of the feet
-- Holding on the trunk (climbing / clinging): Humanoid.PlatformStand, a LinearVelocity on the HRP (vertical speed from
--   ClimbLogic + a horizontal pull to the hold point ClimbGrabDist x scale off the trunk surface) and an
--   AlignOrientation facing the trunk; the character's TurnLimitEnabled is set false while held (TurnLimit 1.1's own
--   switch) and restored after. Letting go (hop, ground, mantle, lost trunk, death, stun, pin, menu) removes the forces,
--   ends PlatformStand and restores TurnLimitEnabled. Hop: the body gets ClimbHopSpeed x scale backward + 0.8 of it up.
--   Mantle: the HRP is moved onto ClimbLogic.mantleTarget (the highest proxy over the trunk) standing, facing the same way.
-- State changes go to the server (DinoClimbState) and to the local attribute ClimbLocalState (this client's pose).
-- Settings (character attributes, scale 1): ClimbSpeed 10, ClimbGrabDist 1.5, ClimbTopGap 2, ClimbHopSpeed 12,
--   ClimbHeadReach 4.5.
-- Diagnostics (local): ClimbLocalState, ClimbReason, ClimbTreeLocal, ClimbTestVersion.
-- v1.1 (Studio check of 1.0: the input never read "forward" — this game has no PlayerScripts.PlayerModule): the move
--   input is read like TurnLimit 1.1: StarterPlayer.PlayerModule.InputContexts.CharacterContext.MoveAction (Vector2,
--   y = forward), else the legacy PlayerModule controls. Off the trunk, "forward" = the camera-relative input points
--   along the body's facing (dot > 0.3; "back" < -0.3); on the trunk, forward / back = the raw input's y (W / S), so
--   the camera angle does not matter while climbing. Diagnostic ClimbInputSource ("inputAction" / "controlModule" /
--   "none").
-- v1.2 (Studio check of 1.1: running into a palm 1.9 studs off its axis slid past it without a grab — the thin ray
--   missed the 3-stud trunk the body hit): trunkAhead / trunkEnds use a sphere cast as wide as the HRP (radius =
--   HRP width / 2); trunkAhead = the sphere's travel + radius - the HRP's half length.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.2"
local char = script.Parent
if not char:IsA("Model") then return end
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local player = Players.LocalPlayer
if char:GetAttribute("ClimbEnabled") ~= true then return end
char:SetAttribute("ClimbTestVersion", VERSION)

local shared = ReplicatedStorage:WaitForChild("ClimbShared", 30)
local CL = shared and require(shared:WaitForChild("ClimbLogic"))
local remote = ReplicatedStorage:WaitForChild("DinoClimbState", 30)
if not CL then
	char:SetAttribute("ClimbLocalState", "noLogic")
	return
end

local DEFAULTS = {ClimbSpeed = 10, ClimbGrabDist = 1.5, ClimbTopGap = 2, ClimbHopSpeed = 12, ClimbHeadReach = 4.5}
local function setting(k)
	local v = char:GetAttribute(k)
	return type(v) == "number" and v or DEFAULTS[k]
end

-- trunk parts of the island (collected once)
local trunkParts = {}
local trunkTree = {} -- [part] = tree model
do
	local island = workspace:WaitForChild("DinoIsland", 30)
	local trees = island and island:WaitForChild("Trees", 30)
	if trees then
		for _, tree in ipairs(trees:GetChildren()) do
			for _, p in ipairs(tree:GetDescendants()) do
				if p:IsA("BasePart") and p.Name:match("^Trunk") then
					table.insert(trunkParts, p)
					trunkTree[p] = tree
				end
			end
		end
	end
end
local trunkParams = RaycastParams.new()
trunkParams.FilterType = Enum.RaycastFilterType.Include
trunkParams.FilterDescendantsInstances = trunkParts
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.FilterDescendantsInstances = {char}

local function proxies()
	local island = workspace:FindFirstChild("DinoIsland")
	local folder = island and island:FindFirstChild("TreeTops")
	return folder and folder:GetChildren() or {}
end
local function reachOf(p)
	if p.Shape == Enum.PartType.Cylinder then return p.Size.Y / 2 end
	return math.max(p.Size.X, p.Size.Z) / 2
end
local function topOf(p)
	return p:GetAttribute("TreeTopTopY") or (p.Position.Y + p.Size.Y / 2)
end

-- controls (v1.1: TurnLimit 1.1's reader) -> Vector2 (x = right, y = forward)
local readMove = function() return Vector2.zero end
task.spawn(function()
	local moveAction
	local pm = game:GetService("StarterPlayer"):WaitForChild("PlayerModule", 10)
	if pm then
		local ok, a = pcall(function()
			return pm:WaitForChild("InputContexts", 10):WaitForChild("CharacterContext", 10):WaitForChild("MoveAction", 10)
		end)
		if ok and a and a:IsA("InputAction") then moveAction = a end
	end
	if moveAction then
		readMove = function()
			local v = moveAction:GetState()
			return typeof(v) == "Vector2" and v or Vector2.zero
		end
		char:SetAttribute("ClimbInputSource", "inputAction")
		return
	end
	local ps = player:FindFirstChild("PlayerScripts")
	local legacy = ps and ps:FindFirstChild("PlayerModule")
	local ok, cm = pcall(function() return require(legacy):GetControls() end)
	if legacy and ok and cm then
		readMove = function()
			local v = cm:GetMoveVector()
			return Vector2.new(v.X, -v.Z)
		end
		char:SetAttribute("ClimbInputSource", "controlModule")
	else
		char:SetAttribute("ClimbInputSource", "none")
	end
end)
local function inputWorld(mv)
	if mv.Magnitude < 1e-3 then return Vector3.zero end
	local cam = workspace.CurrentCamera
	local cf = cam and cam.CFrame or CFrame.identity
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 1e-3 then return Vector3.zero end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	return right * mv.X + look * mv.Y
end
local hopQueued = false
UserInputService.JumpRequest:Connect(function() hopQueued = true end)

-- forces
local att = Instance.new("Attachment")
att.Name = "ClimbAttachment"
att.Parent = hrp
local lv = Instance.new("LinearVelocity")
lv.Name = "ClimbVelocity"
lv.Attachment0 = att
lv.RelativeTo = Enum.ActuatorRelativeTo.World
lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
lv.MaxForce = math.huge
lv.Enabled = false
lv.Parent = hrp
local ao = Instance.new("AlignOrientation")
ao.Name = "ClimbAlign"
ao.Attachment0 = att
ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
ao.RigidityEnabled = true
ao.Enabled = false
ao.Parent = hrp

local state = "ground"
local holding = false
local savedTurnLimit
local lastSentState, lastSentTree
local currentTree = ""

local function send(st, tree)
	if st == lastSentState and tree == lastSentTree then return end
	lastSentState, lastSentTree = st, tree
	char:SetAttribute("ClimbLocalState", st)
	char:SetAttribute("ClimbTreeLocal", tree)
	if remote then remote:FireServer(st, tree) end
end

local function hold(on)
	if on == holding then return end
	holding = on
	if on then
		savedTurnLimit = char:GetAttribute("TurnLimitEnabled")
		char:SetAttribute("TurnLimitEnabled", false)
		hum.PlatformStand = true
		lv.Enabled, ao.Enabled = true, true
	else
		lv.Enabled, ao.Enabled = false, false
		hum.PlatformStand = false
		char:SetAttribute("TurnLimitEnabled", savedTurnLimit ~= false)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function blocked()
	if hum.Health <= 0 then return true end
	local now = workspace:GetServerTimeNow()
	if (char:GetAttribute("StunnedUntil") or 0) > now then return true end
	if char:GetAttribute("PinHeld") == true then return true end
	if player:GetAttribute("InMenu") == true then return true end
	return false
end

RunService.Heartbeat:Connect(function()
	if not char.Parent then return end
	local scale = char:GetScale()
	local s = {grab = setting("ClimbGrabDist") * scale, topGap = setting("ClimbTopGap") * scale, speed = setting("ClimbSpeed") * scale}
	local headReach = setting("ClimbHeadReach") * scale
	if blocked() then
		if holding then hold(false) end
		state = "ground"
		send("ground", "")
		hopQueued = false
		return
	end
	-- probes
	local look = hrp.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.new(0, 0, -1)
	-- input (v1.1)
	local mv = readMove()
	local input
	if state == "climbing" or state == "clinging" then
		input = {forward = mv.Y > 0.3, back = mv.Y < -0.3, hop = hopQueued}
	else
		local along = inputWorld(mv):Dot(fwd)
		input = {forward = along > 0.3, back = along < -0.3, hop = hopQueued}
	end
	hopQueued = false
	local half = hrp.Size.Z / 2
	local probe = {}
	local radius = hrp.Size.X / 2 -- v1.2: as wide as the body
	local hit = workspace:Spherecast(hrp.Position, radius, fwd * (half + s.grab * 3), trunkParams)
	if hit then
		probe.trunkAhead = math.max(0, hit.Distance + radius - half)
		currentTree = trunkTree[hit.Instance] and trunkTree[hit.Instance].Name or currentTree
	end
	probe.trunkEnds = workspace:Spherecast(hrp.Position + Vector3.new(0, headReach, 0), radius, fwd * (half + s.grab * 3), trunkParams) == nil
	local feetY = hrp.Position.Y - (hrp.Size.Y / 2 + hum.HipHeight)
	local headY = hrp.Position.Y + hrp.Size.Y / 2 + headReach
	local plist = {}
	local topAbove, onTop
	for _, p in ipairs(proxies()) do
		local reach = reachOf(p)
		local d = Vector3.new(p.Position.X - hrp.Position.X, 0, p.Position.Z - hrp.Position.Z).Magnitude
		local top = topOf(p)
		table.insert(plist, {x = p.Position.X, z = p.Position.Z, top = top, reach = reach})
		if d <= reach then
			local bottom = top - 2 * (top - p.Position.Y)
			if bottom >= hrp.Position.Y then
				local gap = bottom - headY
				if not topAbove or gap < topAbove then topAbove = gap end
			end
			if math.abs(top - feetY) <= 1.5 then onTop = p end
		end
	end
	probe.topAbove = topAbove
	probe.onTop = onTop ~= nil
	local g = workspace:Raycast(hrp.Position, Vector3.new(0, -200, 0), groundParams)
	probe.groundBelow = g and (g.Distance - hrp.Size.Y / 2 - hum.HipHeight) or nil

	local nextState, out = CL.step(state, input, probe, s)
	char:SetAttribute("ClimbReason", out.reason)
	if out.mantle then
		local trunkPos = hit and hit.Position or hrp.Position
		local target = CL.mantleTarget(plist, trunkPos, hrp.Position.Y)
		hold(false)
		if target then
			local up = hrp.Size.Y / 2 + hum.HipHeight + 0.3
			hrp.CFrame = CFrame.lookAt(target + Vector3.new(0, up, 0), target + Vector3.new(0, up, 0) + fwd)
			hrp.AssemblyLinearVelocity = Vector3.zero
		else
			nextState = "ground"
		end
	elseif out.hold then
		hold(true)
		-- hold point: grab distance off the trunk surface along the facing; pull there horizontally
		local pull = Vector3.zero
		if hit then
			local want = hit.Position - fwd * (half + s.grab)
			local d = want - hrp.Position
			pull = Vector3.new(d.X, 0, d.Z) * 10
		end
		lv.VectorVelocity = pull + Vector3.new(0, out.vy, 0)
		ao.CFrame = CFrame.lookAt(Vector3.zero, fwd)
	else
		hold(false)
		if out.hop then
			local v = setting("ClimbHopSpeed") * scale
			hrp.AssemblyLinearVelocity = -fwd * v + Vector3.new(0, v * 0.8, 0)
		end
	end
	state = nextState
	local tree = ""
	if state == "climbing" or state == "clinging" then tree = currentTree end
	if state == "top" and onTop then tree = onTop:GetAttribute("TreeTopOf") or "" end
	if state == "top" and out.mantle then tree = currentTree end
	send(state, tree)
end)
