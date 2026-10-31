-- ScurryHitbox v1.0 (Mecha Dino Arena) — the Herrerasaurus' hitboxes follow its four-legged crouch (plan
-- docs/plans/HERRERA_SCURRY_v1.0.md Task 4; Kepu 2026-10-30 "The hitbox should adjust to the crouch").
-- Why: DinoHitboxes 1.1 welds each hitbox to its segment Root; the gait is animated on the clients only, so on the server
--   (where bites, pounces, headbutts and bots test hits) the boxes stay in the rest pose. For the Herrera the rest pose
--   stands on two legs while the scurry body is low and tipped forward.
-- What: on every model with GaitScurry = true that has a "Hitboxes" folder, each hitbox's WeldConstraint to its Root is
--   replaced by a Weld to the HumanoidRootPart whose C0 blends between
--     rest   = the box where DinoHitboxes put it (the two-legged rest pose), and
--     crouch = the box carried by ScurryPose.meanAngles fitted to the ground (the scurry pose with every swing at zero:
--              body tipped, neck / head up, limbs folded and splayed, tail level, average bounce)
--   by the scurry weight: horizontal HumanoidRootPart speed above MOVE_SPEED -> 1, else 0, eased at BLEND_RATE per second
--   (the client walk blend's rate). The weld is set on the server and replicates, so every client and the server test
--   the same boxes; the boxes no longer follow the per-frame swing of the limbs (accepted: the crouch is the average).
-- Scale: when the model's scale changes (RaptorScale / the Play harness), rest and crouch offsets are recomputed from
--   the current Weld at that scale.
-- ScurryPose comes from the model's own IdleAnimation copy, else StarterPlayer.StarterCharacterScripts.IdleAnimation.
-- Switch: script attribute ScurryHitboxEnabled (default true; false = models are left on the DinoHitboxes 1.1 welds).
-- Diagnostics (model): ScurryHitboxState ("ready" / "noPose" / "noGeo"), ScurryHitboxCount, ScurryHitboxBlend (0.1
--   steps), ScurryHitboxDrop (studs the Torso box centre sits lower at full crouch, 0.01 steps), ScurryHitboxVersion.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local MOVE_SPEED = 2   -- studs/s of horizontal HRP speed that counts as scurrying
local BLEND_RATE = 6   -- per second (IdleAnimation's BLEND_RATE)
local STEP = 0.02      -- weld C0 is rewritten when the weight moved this much (or reached 0 / 1)

if script:GetAttribute("ScurryHitboxEnabled") == nil then script:SetAttribute("ScurryHitboxEnabled", true) end
script:SetAttribute("ScurryHitboxVersion", VERSION)

local tracked = {} -- [model] = {hrp, boxes = {{weld, rest, crouch}}, w, lastW, scale}

local function scurryPoseFor(model)
	local ia = model:FindFirstChild("IdleAnimation")
	local src = ia and ia:FindFirstChild("ScurryPose")
	if not src then
		local scs = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
		ia = scs and scs:FindFirstChild("IdleAnimation")
		src = ia and ia:FindFirstChild("ScurryPose")
	end
	if not src then return nil end
	local ok, m = pcall(require, src)
	return ok and m or nil
end

local function motorsOf(model)
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then motors[d.Name] = {motor = d, restC0 = d.C0} end
	end
	return motors
end

-- a segment Root's CFrame in the HRP frame for a pose (forward kinematics through restC0 * pose * C1^-1)
local function rootInHrp(root, hrp, motors, pose)
	local chain, part, guard = {}, root, 0
	while part ~= hrp do
		guard += 1
		if guard > 12 then return nil end
		local found
		for name, e in pairs(motors) do
			if e.motor.Part1 == part then found = name break end
		end
		if not found then return nil end
		table.insert(chain, 1, found)
		part = motors[found].motor.Part0
		if not part then return nil end
	end
	local cf = CFrame.identity
	for _, name in ipairs(chain) do
		local e = motors[name]
		cf = cf * e.restC0 * (pose[name] or CFrame.identity) * e.motor.C1:Inverse()
	end
	return cf
end

local function setup(model)
	if tracked[model] or script:GetAttribute("ScurryHitboxEnabled") == false then return end
	if model:GetAttribute("GaitScurry") ~= true then return end
	local folder = model:FindFirstChild("Hitboxes")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not (folder and hrp) then return end
	local SP = scurryPoseFor(model)
	if not SP then model:SetAttribute("ScurryHitboxState", "noPose") return end
	local motors = motorsOf(model)
	local geo = SP.buildGeo(model, motors)
	if not geo then model:SetAttribute("ScurryHitboxState", "noGeo") return end
	local scale = model:GetScale()
	local pose = SP.fitted(SP.meanAngles(SP.settings(model)), geo, motors, scale)
	local boxes, torsoDrop = {}, 0
	for _, box in ipairs(folder:GetChildren()) do
		local wc = box:IsA("BasePart") and box:FindFirstChildOfClass("WeldConstraint")
		local root = wc and wc.Part0
		if root and root.Name == "Root" then
			-- rest: where the box is now (server = rest pose); crouch: the same box carried by its Root in the crouch
			local rest = hrp.CFrame:ToObjectSpace(box.CFrame)
			local rc = rootInHrp(root, hrp, motors, pose)
			if rc then
				local crouch = rc * root.CFrame:ToObjectSpace(box.CFrame)
				local weld = Instance.new("Weld")
				weld.Name = "ScurryHitboxWeld"
				weld.Part0, weld.Part1 = hrp, box
				weld.C0, weld.C1 = rest, CFrame.identity
				wc:Destroy()
				weld.Parent = box
				table.insert(boxes, {weld = weld, rest = rest, crouch = crouch})
				if box:GetAttribute("HitboxSegment") == "Torso" then torsoDrop = rest.Position.Y - crouch.Position.Y end
			end
		end
	end
	tracked[model] = {hrp = hrp, boxes = boxes, w = 0, lastW = 0, scale = scale}
	model:SetAttribute("ScurryHitboxState", "ready")
	model:SetAttribute("ScurryHitboxCount", #boxes)
	model:SetAttribute("ScurryHitboxDrop", math.floor(torsoDrop * 100 + 0.5) / 100)
	model:SetAttribute("ScurryHitboxBlend", 0)
	model:SetAttribute("ScurryHitboxVersion", VERSION)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then tracked[model] = nil end
	end)
end

-- a model whose Hitboxes folder arrives later (DinoHitboxes builds it after CharacterAdded / DescendantAdded)
local function watch(model)
	if not model:IsA("Model") then return end
	if model:FindFirstChild("Hitboxes") then
		task.defer(setup, model)
	end
	model.ChildAdded:Connect(function(c)
		if c.Name == "Hitboxes" then task.delay(0.1, setup, model) end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(watch)
	if player.Character then watch(player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("GaitScurry") == true then watch(d) end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") and d:GetAttribute("GaitScurry") == true and not Players:GetPlayerFromCharacter(d) then watch(d) end
end)

RunService.Heartbeat:Connect(function(dt)
	for model, t in pairs(tracked) do
		local sc = model:GetScale()
		if math.abs(sc - t.scale) > 1e-4 then
			-- the Weld C0s were scaled with the model; rescale the cached offsets the same way
			local k = sc / t.scale
			for _, b in ipairs(t.boxes) do
				b.rest = CFrame.new(b.rest.Position * k) * b.rest.Rotation
				b.crouch = CFrame.new(b.crouch.Position * k) * b.crouch.Rotation
			end
			t.scale = sc
			t.lastW = -1 -- rewrite the welds
		end
		local v = t.hrp.AssemblyLinearVelocity
		local target = Vector3.new(v.X, 0, v.Z).Magnitude > MOVE_SPEED * sc and 1 or 0
		t.w += (target - t.w) * math.min(1, dt * BLEND_RATE)
		if target == 0 and t.w < 0.01 then t.w = 0 elseif target == 1 and t.w > 0.99 then t.w = 1 end
		if math.abs(t.w - t.lastW) >= STEP or ((t.w == 0 or t.w == 1) and t.w ~= t.lastW) then
			for _, b in ipairs(t.boxes) do
				b.weld.C0 = b.rest:Lerp(b.crouch, t.w)
			end
			t.lastW = t.w
			model:SetAttribute("ScurryHitboxBlend", math.floor(t.w * 10 + 0.5) / 10)
		end
	end
end)
