-- ClimbTest v1.13 (Mecha Dino Arena) — the Herrerasaurus' auto-climb on the owner's client. MDA-138, plan
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
-- v1.3 (Studio check of 1.2: the body stopped 5 studs short of the trunk and slid around it — the head's blocking hitbox
--   (DinoHitboxes, CanCollide) sticks out ~6.7 studs ahead of the HRP at 2x and hits the bark first): trunkAhead is
--   measured from the body's front-most blocking point: the largest reach along the facing of any corner of a
--   "Hitboxes" part with HitboxBlocks = true (else the HRP's half length).
-- v1.4 (Studio check of 1.3: climbing worked, palm mantle onto the top at y 45.9; the first 4 frames after a grab
--   flickered grab / lostTrunk because on the trunk the distance was measured from the HRP's half length while the
--   head box still stuck out): the front-most blocking point is used on the trunk too.
-- v1.5 (Studio check of 1.4: Space on a tree top did nothing — JumpRequest does not fire in this game's input setup):
--   hop = a press of StarterPlayer.PlayerModule.InputContexts.CharacterContext.JumpAction (Input Action System, read
--   like JumpTest 1.x; edge: down now, up last frame), plus JumpRequest when that action is missing.
-- v1.6 (Studio check of 1.5: running into CoconutPalm_219 slid around it, ClimbReason "ground" with the trunk 0.1 stud
--   ahead — Workspace.StreamingEnabled is true, the trunk list was collected once at spawn, so trees streamed in later
--   were not in the ray filter): the trunk list follows Trees.DescendantAdded / DescendantRemoving; the ray filter is
--   rebuilt on the next frame after a change. Diagnostic: ClimbTrunkCount.
-- v1.7 (Studio check of 1.6: Space on the palm top read "hopOffTop" and the body rose ~16 studs/s, but the Humanoid's
--   own ground / air control cancelled the backward speed, so it landed back on the pad): the hop's backward part is
--   held for ClimbHopTime (0.35 s) by a second LinearVelocity "ClimbHopVelocity" in Plane mode (world X / Z only, so
--   gravity and the hop's upward speed are untouched); the Humanoid is put in Freefall at the hop. A grab during the
--   push ends it. Setting (character attribute): ClimbHopTime.
-- v1.8 (Studio check of 1.7: the push worked, 9.3 studs back, but from near the pad centre it still landed on the pad):
--   off a tree top ("hopOffTop") the push lasts until the HRP is half its length + 1 stud past the proxy's edge along
--   the hop direction (at least ClimbHopTime, at most HOP_TOP_MAX_TIME 1 s), so the hop clears the pad from anywhere on it
--   (CoconutPalm_219's pad is 8.85 studs in radius).
-- v1.9 (MDA-141, plan docs/plans/HERRERA_KIT_v1.0.md Task 9; SlashTest 1.0): while the character attribute
--   SlashLocalState is "dash" (the slash / dive / leap runs) the trunk is let go (forces off, PlatformStand off,
--   TurnLimitEnabled restored), a running hop push stops, the state is "ground" and nothing is probed, so the dash is not
--   caught by the trunk again; after the dash the probes run as before. ClimbReason "slash".
-- v1.10 (MDA-145, Kepu 2026-10-31 live on a phone: stuck clinging under a palm crown; Studio repro on CoconutPalm_7,
--   which leans: the vertical climb lost the trunk at y 37, ~15 studs under the crown, and clung at "trunkEnd"):
--   with ClimbLogic 1.1 forward at the trunk end mantles. The mantle target is ClimbLogic.mantleTarget (a proxy over the
--   trunk) as before, else ClimbLogic.treeTopTarget over the climbed tree's own proxies (TreeTopOf = ClimbTreeLocal; a
--   leaning palm's crown is off the trunk line). With no target at all a trunk-end mantle keeps clinging (held, vy 0)
--   instead of letting go (1.9 dropped to "ground"). Diagnostic: ClimbMantleTarget ("trunk" / "tree" / "none").
-- v1.11 (MDA-146 / MDA-145: a phone had no way off a tree — no Space, and the hop only read the JumpAction): a hop is
--   also a rising edge of Humanoid.Jump, which ArenaTouch 1.7's JUMP button sets on phones (this game has no PlayerModule
--   control scripts, so nothing else sets it). PC Space (JumpAction) unchanged. Diagnostic: ClimbHopSource ("action" /
--   "humanoid").
-- v1.12 (Kepu 2026-10-31 "Fix the bug": walking into the base of a leaning palm threw the Herrera up to the crown;
--   Studio CoconutPalm_7, lean +z, scale 2: from +x / -x the climb mantled after 0.27 / 0.15 s, y 13 -> 53; from +z at
--   y 29.5 -> 53.5): the trunk-end probe is one sphere cast along the facing at head height, and a leaning trunk drifts
--   off that line long before its top, so "trunk ends" fired low on the trunk and ClimbLogic 1.1 mantled to the crown.
--   Now, while climbing / clinging, a missed head probe only counts as the trunk's end when the probe point is at or
--   above the climbed tree's trunk top (highest point of its Trunk* parts, cached per tree); below it the probe miss is
--   ignored and the climb goes on. Switch: script attribute ClimbTrunkTopEnabled (default true, read at start; false =
--   1.11). Diagnostics: ClimbTrunkTopY (the climbed tree's trunk top), ClimbEndCheck ("probe" / "belowTop").
--   Same cause at body height (Studio CoconutPalm_24, lean 15 studs +x, climbed from +z: with only the rule above the
--   body lost the trunk at y 45.5 and fell): while climbing / clinging, the climbed tree's trunk centre at body height
--   comes from its Trunk* parts' axes (the part whose long axis is Y and spans the body's height; centre = Position +
--   UpVector * t, radius = half its thickness). trunkAhead = distance along the facing from the body's front to that
--   trunk's surface (when the trunk is in front: along > 0, sideways offset <= radius + body width), and the hold pulls
--   the body to (centre - facing * (radius + half length + grab)) plus the trunk's lean per stud climbed times the climb
--   speed, so the body follows a leaning trunk. No such part (or a non-Y-axis trunk) = the probes as before. Switch:
--   script attribute ClimbTrunkFollowEnabled (default true, read at start; false = probes only). Diagnostic:
--   ClimbFollow ("on" / "off").
-- v1.13 (MDA-147, plan docs/plans/HERRERA_JUMP_v1.0.md Task 3: the Herrera now has the JumpTest leap too, and JUMP on a
--   tree top fired both the leap and the hop): the character attribute JumpSuppressed is true while ClimbLocalState is
--   climbing / clinging / top and false otherwise (JumpTest 1.3 then refuses / ends its leap, so JUMP on a tree is only the
--   hop, and a leap that grabs a trunk mid-air hands the body to the climb). Switch: script attribute
--   ClimbJumpSuppressEnabled (default true, read at start; false = 1.12, JumpSuppressed never written).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.13"
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

local DEFAULTS = {ClimbSpeed = 10, ClimbGrabDist = 1.5, ClimbTopGap = 2, ClimbHopSpeed = 12, ClimbHeadReach = 4.5, ClimbHopTime = 0.35}
local function setting(k)
	local v = char:GetAttribute(k)
	return type(v) == "number" and v or DEFAULTS[k]
end

-- trunk parts of the island (collected once)
local trunkParts = {}
local trunkTree = {} -- [part] = tree model
local trunkParams = RaycastParams.new()
trunkParams.FilterType = Enum.RaycastFilterType.Include
trunkParams.FilterDescendantsInstances = trunkParts
-- v1.6: the list follows streaming (trees arrive / leave after spawn)
local trunkDirty = false
local trunkTopCache = {} -- v1.12: [tree name] = trunk top Y
if script:GetAttribute("ClimbTrunkTopEnabled") == nil then script:SetAttribute("ClimbTrunkTopEnabled", true) end
local TRUNK_TOP_ON = script:GetAttribute("ClimbTrunkTopEnabled") ~= false
local trunkSegCache = {} -- v1.12: [tree name] = {trunk parts}
if script:GetAttribute("ClimbTrunkFollowEnabled") == nil then script:SetAttribute("ClimbTrunkFollowEnabled", true) end
local TRUNK_FOLLOW_ON = script:GetAttribute("ClimbTrunkFollowEnabled") ~= false
do
	local island = workspace:WaitForChild("DinoIsland", 30)
	local trees = island and island:WaitForChild("Trees", 30)
	if trees then
		local function treeOf(p)
			local t = p
			while t and t.Parent ~= trees do t = t.Parent end
			return t
		end
		local function add(p)
			if p:IsA("BasePart") and p.Name:match("^Trunk") and not trunkTree[p] then
				local tree = treeOf(p)
				if tree then
					trunkTree[p] = tree
					trunkDirty = true
				end
			end
		end
		for _, p in ipairs(trees:GetDescendants()) do add(p) end
		trees.DescendantAdded:Connect(add)
		trees.DescendantRemoving:Connect(function(p)
			if trunkTree[p] then
				trunkTree[p] = nil
				trunkDirty = true
			end
		end)
	end
end
local function refreshTrunks()
	if not trunkDirty then return end
	trunkDirty = false
	table.clear(trunkParts)
	for p in pairs(trunkTree) do table.insert(trunkParts, p) end
	trunkParams.FilterDescendantsInstances = trunkParts
	char:SetAttribute("ClimbTrunkCount", #trunkParts)
	if trunkTopCache then table.clear(trunkTopCache) end -- v1.12
	if trunkSegCache then table.clear(trunkSegCache) end -- v1.12
end
refreshTrunks()
-- v1.12: highest point of a tree's Trunk* parts (world Y), nil when the tree has none in the list
local function trunkTopOf(treeName)
	if treeName == "" then return nil end
	local cached = trunkTopCache[treeName]
	if cached then return cached end
	local top
	for p, tree in pairs(trunkTree) do
		if tree.Name == treeName then
			local cf, sz = p.CFrame, p.Size
			local ext = math.abs(cf.RightVector.Y) * sz.X / 2 + math.abs(cf.UpVector.Y) * sz.Y / 2 + math.abs(cf.LookVector.Y) * sz.Z / 2
			local t = p.Position.Y + ext
			if not top or t > top then top = t end
		end
	end
	trunkTopCache[treeName] = top
	return top
end
-- v1.12: the tree's trunk centre at height y: {c = Vector3, r = radius, up = axis (up.Y > 0)} or nil
local function trunkCentreAt(treeName, y)
	if treeName == "" then return nil end
	local list = trunkSegCache[treeName]
	if not list then
		list = {}
		for p, tree in pairs(trunkTree) do
			if tree.Name == treeName then table.insert(list, p) end
		end
		trunkSegCache[treeName] = list
	end
	local best, bestOver
	for _, p in ipairs(list) do
		local sz = p.Size
		if p.Parent and sz.Y >= sz.X and sz.Y >= sz.Z then
			local up = p.CFrame.UpVector
			if up.Y < 0 then up = -up end
			if up.Y > 0.2 then
				local t = (y - p.Position.Y) / up.Y
				local over = math.abs(t) - sz.Y / 2
				if not bestOver or over < bestOver then
					best, bestOver = {c = p.Position + up * t, r = math.min(sz.X, sz.Z) / 2, up = up}, over
				end
			end
		end
	end
	if best and bestOver <= 1 then return best end
	return nil
end
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
-- v1.5: the Input Action System jump (JumpTest's reader)
local jumpAction
task.spawn(function()
	local pm = game:GetService("StarterPlayer"):FindFirstChild("PlayerModule")
	local ok, a = pcall(function()
		return pm and pm:WaitForChild("InputContexts", 5):WaitForChild("CharacterContext", 5):WaitForChild("JumpAction", 5)
	end)
	if ok and a and a:IsA("InputAction") then jumpAction = a end
end)
local jumpWasDown = false
local humJumpWas = false -- v1.11
local function jumpPressed()
	local hj = hum.Jump == true -- v1.11: the phone JUMP button (ArenaTouch 1.7)
	local hjPressed = hj and not humJumpWas
	humJumpWas = hj
	if hjPressed then char:SetAttribute("ClimbHopSource", "humanoid") end
	if not jumpAction then return hjPressed end
	local ok, v = pcall(function() return jumpAction:GetState() end)
	local down = ok and v == true
	local pressed = down and not jumpWasDown
	jumpWasDown = down
	if pressed then char:SetAttribute("ClimbHopSource", "action") end
	return pressed or hjPressed
end

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
-- v1.7: the hop's horizontal push (Plane: world X / Z only)
local hopLv = Instance.new("LinearVelocity")
hopLv.Name = "ClimbHopVelocity"
hopLv.Attachment0 = att
hopLv.RelativeTo = Enum.ActuatorRelativeTo.World
hopLv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
hopLv.PrimaryTangentAxis = Vector3.xAxis
hopLv.SecondaryTangentAxis = Vector3.zAxis
hopLv.MaxForce = math.huge
hopLv.Enabled = false
hopLv.Parent = hrp
local hopUntil = 0
local HOP_TOP_MAX_TIME = 1 -- v1.8

local state = "ground"
local holding = false
local savedTurnLimit
local lastSentState, lastSentTree
local currentTree = ""

if script:GetAttribute("ClimbJumpSuppressEnabled") == nil then script:SetAttribute("ClimbJumpSuppressEnabled", true) end -- v1.13
local JUMP_SUPPRESS_ON = script:GetAttribute("ClimbJumpSuppressEnabled") ~= false
if JUMP_SUPPRESS_ON then char:SetAttribute("JumpSuppressed", false) end
local function send(st, tree)
	if st == lastSentState and tree == lastSentTree then return end
	lastSentState, lastSentTree = st, tree
	if JUMP_SUPPRESS_ON then -- v1.13
		char:SetAttribute("JumpSuppressed", st == "climbing" or st == "clinging" or st == "top")
	end
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

-- v1.3: how far the body's blocking hitboxes reach ahead of the HRP centre along fwd
local function frontReach(fwd, half)
	local folder = char:FindFirstChild("Hitboxes")
	local reach = half
	if not folder then return reach end
	for _, b in ipairs(folder:GetChildren()) do
		if b:IsA("BasePart") and b:GetAttribute("HitboxBlocks") == true then
			local h = b.Size / 2
			local cf = b.CFrame
			local ext = math.abs(cf.RightVector:Dot(fwd)) * h.X + math.abs(cf.UpVector:Dot(fwd)) * h.Y + math.abs(cf.LookVector:Dot(fwd)) * h.Z
			reach = math.max(reach, (b.Position - hrp.Position):Dot(fwd) + ext)
		end
	end
	return reach
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
		hopLv.Enabled = false -- v1.7
		state = "ground"
		send("ground", "")
		hopQueued = false
		return
	end
	if char:GetAttribute("SlashLocalState") == "dash" then -- v1.9: the slash dash owns the body
		if holding then hold(false) end
		hopLv.Enabled = false
		state = "ground"
		send("ground", "")
		hopQueued = false
		char:SetAttribute("ClimbReason", "slash")
		return
	end
	-- probes
	refreshTrunks() -- v1.6
	local look = hrp.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.new(0, 0, -1)
	-- input (v1.1)
	if jumpPressed() then hopQueued = true end -- v1.5
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
	local front = frontReach(fwd, half) -- v1.3 (v1.4: on the trunk too)
	local hit = workspace:Spherecast(hrp.Position, radius, fwd * (front + s.grab * 3), trunkParams)
	if hit then
		probe.trunkAhead = math.max(0, hit.Distance + radius - front)
		currentTree = trunkTree[hit.Instance] and trunkTree[hit.Instance].Name or currentTree
	end
	probe.trunkEnds = workspace:Spherecast(hrp.Position + Vector3.new(0, headReach, 0), radius, fwd * (half + s.grab * 3), trunkParams) == nil
	if TRUNK_TOP_ON and probe.trunkEnds and (state == "climbing" or state == "clinging") then -- v1.12
		local topY = trunkTopOf(currentTree)
		char:SetAttribute("ClimbTrunkTopY", topY or -1)
		if topY and hrp.Position.Y + headReach < topY then
			probe.trunkEnds = false -- the trunk goes on above the head; it only leans off the probe line
			char:SetAttribute("ClimbEndCheck", "belowTop")
		else
			char:SetAttribute("ClimbEndCheck", "probe")
		end
	end
	local follow -- v1.12: the climbed trunk at body height
	if TRUNK_FOLLOW_ON and (state == "climbing" or state == "clinging") then
		follow = trunkCentreAt(currentTree, hrp.Position.Y)
		if follow then
			local rel = Vector3.new(follow.c.X - hrp.Position.X, 0, follow.c.Z - hrp.Position.Z)
			local along = rel:Dot(fwd)
			local lateral = (rel - fwd * along).Magnitude
			if along > 0 and lateral <= follow.r + hrp.Size.X then
				probe.trunkAhead = math.max(0, along - follow.r - front)
			else
				follow = nil
			end
		end
	end
	if TRUNK_FOLLOW_ON then
		local f = follow and "on" or "off"
		if char:GetAttribute("ClimbFollow") ~= f then char:SetAttribute("ClimbFollow", f) end
	end
	local feetY = hrp.Position.Y - (hrp.Size.Y / 2 + hum.HipHeight)
	local headY = hrp.Position.Y + hrp.Size.Y / 2 + headReach
	local plist = {}
	local topAbove, onTop
	for _, p in ipairs(proxies()) do
		local reach = reachOf(p)
		local d = Vector3.new(p.Position.X - hrp.Position.X, 0, p.Position.Z - hrp.Position.Z).Magnitude
		local top = topOf(p)
		table.insert(plist, {x = p.Position.X, z = p.Position.Z, top = top, reach = reach, tree = p:GetAttribute("TreeTopOf")}) -- v1.10: + tree
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
		local how = target and "trunk" or "none" -- v1.10
		if not target and CL.treeTopTarget and currentTree ~= "" then -- v1.10: the climbed tree's own top
			local own = {}
			for _, q in ipairs(plist) do
				if q.tree == currentTree then table.insert(own, q) end
			end
			target = CL.treeTopTarget(own, hrp.Position.Y)
			if target then how = "tree" end
		end
		char:SetAttribute("ClimbMantleTarget", how)
		if not target and out.reason == "trunkEnd" then -- v1.10: nowhere to go: keep clinging, do not drop
			hold(true)
			lv.VectorVelocity = Vector3.zero
			ao.CFrame = CFrame.lookAt(Vector3.zero, fwd)
			nextState = "clinging"
		else
		hold(false)
		if target then
			local up = hrp.Size.Y / 2 + hum.HipHeight + 0.3
			hrp.CFrame = CFrame.lookAt(target + Vector3.new(0, up, 0), target + Vector3.new(0, up, 0) + fwd)
			hrp.AssemblyLinearVelocity = Vector3.zero
		else
			nextState = "ground"
		end
		end -- v1.10
	elseif out.hold then
		hopLv.Enabled = false -- v1.7
		hopUntil = 0
		hold(true)
		-- hold point: grab distance off the trunk surface along the facing; pull there horizontally
		local pull = Vector3.zero
		if follow then -- v1.12: stay at the leaning trunk
			local want = follow.c - fwd * (follow.r + half + s.grab)
			local d = want - hrp.Position
			pull = Vector3.new(d.X, 0, d.Z) * 10 + Vector3.new(follow.up.X, 0, follow.up.Z) / follow.up.Y * out.vy
		elseif hit then
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
			-- v1.7: hold the backward part for ClimbHopTime
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
			hopLv.PlaneVelocity = Vector2.new(-fwd.X * v, -fwd.Z * v)
			hopLv.Enabled = true
			local pushTime = setting("ClimbHopTime")
			if out.reason == "hopOffTop" and onTop and v > 0 then
				-- distance along -fwd from the HRP to the proxy's edge, + half the HRP length + 1
				local c = Vector3.new(onTop.Position.X, 0, onTop.Position.Z)
				local rel = Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - c
				local d = -fwd
				local b = rel:Dot(d)
				local disc = b * b - (rel:Dot(rel) - reachOf(onTop) ^ 2)
				local toEdge = disc > 0 and (-b + math.sqrt(disc)) or 0
				pushTime = math.max(pushTime, math.min((toEdge + half + 1) / v, HOP_TOP_MAX_TIME))
			end
			hopUntil = os.clock() + pushTime
		end
		if hopLv.Enabled and os.clock() >= hopUntil then hopLv.Enabled = false end
	end
	state = nextState
	local tree = ""
	if state == "climbing" or state == "clinging" then tree = currentTree end
	if state == "top" and onTop then tree = onTop:GetAttribute("TreeTopOf") or "" end
	if state == "top" and out.mantle then tree = currentTree end
	send(state, tree)
end)
