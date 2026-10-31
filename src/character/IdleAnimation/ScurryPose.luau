-- ScurryPose v1.0 (Mecha Dino Arena) — the Herrerasaurus' four-legged iguana scurry (plan docs/plans/HERRERA_SCURRY_v1.0.md
-- Task 1; mockup docs/mockups/herrera_scurry_options.html option A, Kepu 2026-10-30 "Wow I love A"; "He stands on two legs
-- when idle but does a scurry type of run like a regular iguana does"). Used by IdleAnimation 1.31 instead of WalkPose on
-- models with GaitScurry = true; the idle pose is unchanged (two legs).
-- Joint frames: every rig 1.3 joint pose is restC0 * pose and the segment Roots are in dino space (x forward, y up,
--   z = the ArmL / LegL side), so pitch = about Z (+ lifts the front / swings a limb forward), yaw = about Y, roll = about X.
--   rotation = Rz(pitch) * Ry(yaw) * Rx(roll) = CFrame.fromEulerAngles(roll, yaw, pitch, Enum.RotationOrder.ZYX).
-- The pose (the mockup's gaitA): body tipped nose-down (ScurryBodyPitch) with neck / head lifted to look ahead, arms
--   counter-tipped to hang under the shoulders, legs folded under the hips, tail counter-tipped level; diagonal pairs
--   (ArmL with LegR, ArmR with LegL) swing opposite each other; arms and legs splay out to their own side (roll), more
--   on the arm's forward swing; feet lift on the forward swing (knee folds, foot tips); the body yaws and rolls in an S
--   (ScurryBodyYaw / ScurryBodyRoll), neck and head counter-yaw so the head stays on target; the tail whips with a lag
--   per segment (ScurryTailLag) and a growing amplitude (ScurryTailWhip + i x ScurryTailWhipGrow); a small bounce.
-- Ground fit: get() runs forward kinematics of every visible block of the hand (ArmL / ArmR) and foot (FootL / FootR)
--   segments through restC0 * pose and moves the RootJoint down / up so the lowest one sits at the rest ground height
--   (the lowest foot block in the rest pose), plus the bounce.
-- API:
--   Defaults; settings(model) -> Defaults overridden by model attributes of the same names
--   angles(phase, s) -> {[joint] = {pitch, yaw, roll}} + body = {pitch, yaw, roll, bounce} (degrees / studs at scale 1)
--   meanAngles(s) -> the same with every swing / wave at zero (the crouch the hitboxes use; bounce = mean bounce)
--   buildGeo(model, motors) -> geo or nil (needs the HRP chain to ArmL / ArmR / FootL / FootR)
--   fk(geo, motors, pose) -> lowest point (HRP-space Y) of the hand / foot blocks for that pose
--   get(phase, s, geo, motors, scale) -> pose {[joint] = CFrame}, drop (studs, the ground fit incl. bounce)
--   toPose(a, scale) -> pose CFrames for an angles table (RootJoint without the drop)
local ScurryPose = {}
ScurryPose.Version = "1.0"

ScurryPose.Defaults = {
	ScurryBodyPitch = -24, ScurryNeck = 6, ScurryHead = 16, ScurryJaw = -3,
	ScurryArmTuck = 30, ScurryLegTuck = 48, ScurryKnee = -48, ScurryFoot = 24,
	ScurryTail1 = 26, ScurryTail2 = 4, ScurryTail3 = 8, ScurryTail4 = 14, ScurryTail5 = 20,
	ScurryArmSwing = 34, ScurryArmSprawl = 18, ScurryArmLiftSprawl = 10,
	ScurryLegSwing = 30, ScurryLegSprawl = 16, ScurryKneeLift = -34, ScurryFootLift = 20,
	ScurryBodyYaw = 11, ScurryBodyRoll = 4, ScurryNeckYaw = -9, ScurryHeadYaw = -6,
	ScurryTailWhip = 8, ScurryTailWhipGrow = 4, ScurryTailLag = 0.75,
	ScurryBounce = 0.12, ScurryStride = 3.2, ScurryMaxHz = 5,
}

local JOINTS = {"RootJoint", "Neck", "Head", "Jaw", "ArmL", "ArmR", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5",
	"LegL", "LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"}
ScurryPose.JOINTS = JOINTS
local TIP_SEGS = {"ArmL", "ArmR", "FootL", "FootR"}

local rad, sin, cos, abs, max, pi = math.rad, math.sin, math.cos, math.abs, math.max, math.pi

function ScurryPose.settings(model)
	local s = {}
	for k, v in pairs(ScurryPose.Defaults) do
		local a = model and model:GetAttribute(k)
		s[k] = type(a) == "number" and a or v
	end
	return s
end

local function blank()
	local o = {}
	for _, n in ipairs(JOINTS) do o[n] = {0, 0, 0} end
	o.body = {0, 0, 0, 0}
	return o
end
local function add(o, n, p, y, r)
	o[n][1] += p
	o[n][2] += (y or 0)
	o[n][3] += (r or 0)
end

-- the crouch every frame starts from (no swing): body tipped, neck / head up, limbs folded under, tail level
local function base(o, s)
	add(o, "RootJoint", s.ScurryBodyPitch)
	add(o, "Neck", s.ScurryNeck); add(o, "Head", s.ScurryHead); add(o, "Jaw", s.ScurryJaw)
	add(o, "ArmL", s.ScurryArmTuck); add(o, "ArmR", s.ScurryArmTuck)
	add(o, "LegL", s.ScurryLegTuck); add(o, "LegR", s.ScurryLegTuck)
	add(o, "KneeL", s.ScurryKnee); add(o, "KneeR", s.ScurryKnee)
	add(o, "AnkleL", s.ScurryFoot); add(o, "AnkleR", s.ScurryFoot)
	for i = 1, 5 do add(o, "Tail" .. i, s["ScurryTail" .. i]) end
end

function ScurryPose.angles(phase, s)
	local o = blank()
	base(o, s)
	-- diagonal pairs: ArmL + LegR at phase, ArmR + LegL half a cycle later
	local pairsAt = {ArmL = phase, LegR = phase, ArmR = phase + pi, LegL = phase + pi}
	for n, p in pairs(pairsAt) do
		local sw, lift = sin(p), max(0, cos(p))
		local side = n:sub(-1) == "L" and 1 or -1
		if n:sub(1, 3) == "Arm" then
			add(o, n, s.ScurryArmSwing * sw, 0, -side * (s.ScurryArmSprawl + s.ScurryArmLiftSprawl * lift))
		else
			local sfx = n:sub(-1)
			add(o, n, s.ScurryLegSwing * sw, 0, -side * s.ScurryLegSprawl)
			add(o, "Knee" .. sfx, s.ScurryKneeLift * lift)
			add(o, "Ankle" .. sfx, s.ScurryFootLift * lift)
		end
	end
	local w = sin(phase)
	o.body[2] = s.ScurryBodyYaw * w
	o.body[3] = s.ScurryBodyRoll * sin(phase + pi / 2)
	add(o, "Neck", 0, s.ScurryNeckYaw * w)
	add(o, "Head", 0, s.ScurryHeadYaw * w)
	for i = 1, 5 do
		add(o, "Tail" .. i, 0, (s.ScurryTailWhip + i * s.ScurryTailWhipGrow) * sin(phase - i * s.ScurryTailLag))
	end
	o.body[4] = s.ScurryBounce * abs(cos(phase))
	return o
end

function ScurryPose.meanAngles(s)
	local o = blank()
	base(o, s)
	for _, n in ipairs({"ArmL", "ArmR"}) do
		local side = n:sub(-1) == "L" and 1 or -1
		-- mean roll over a cycle: sprawl + lift sprawl x mean(max(0, cos)) = 1 / pi
		add(o, n, 0, 0, -side * (s.ScurryArmSprawl + s.ScurryArmLiftSprawl / pi))
	end
	for _, sfx in ipairs({"L", "R"}) do
		local side = sfx == "L" and 1 or -1
		add(o, "Leg" .. sfx, 0, 0, -side * s.ScurryLegSprawl)
		add(o, "Knee" .. sfx, s.ScurryKneeLift / pi)
		add(o, "Ankle" .. sfx, s.ScurryFootLift / pi)
	end
	o.body[4] = s.ScurryBounce * 2 / pi -- mean of |cos|
	return o
end

local function rot(p, y, r)
	return CFrame.fromEulerAngles(rad(r), rad(y), rad(p), Enum.RotationOrder.ZYX)
end

-- angles -> joint CFrames; the RootJoint carries the body rotation then the torso pitch (no translation here)
function ScurryPose.toPose(a)
	local pose = {}
	for _, n in ipairs(JOINTS) do
		local v = a[n]
		if n == "RootJoint" then
			pose[n] = rot(a.body[1], a.body[2], a.body[3]) * rot(v[1], v[2], v[3])
		else
			pose[n] = rot(v[1], v[2], v[3])
		end
	end
	return pose
end

-- chain of motor names from the HumanoidRootPart to each tip segment's Root + its visible blocks (offset, half size)
function ScurryPose.buildGeo(model, motors)
	local hrpPart = model:FindFirstChild("HumanoidRootPart")
	if not hrpPart then return nil end
	local segs = {}
	for _, segName in ipairs(TIP_SEGS) do
		local seg = model:FindFirstChild(segName)
		local root = seg and seg:FindFirstChild("Root")
		if not root then return nil end
		local chain, part, guard = {}, root, 0
		while part ~= hrpPart do
			guard += 1
			if guard > 8 then return nil end
			local found
			for name, e in pairs(motors) do
				if e.motor.Part1 == part then found = name break end
			end
			if not found then return nil end
			table.insert(chain, 1, found)
			part = motors[found].motor.Part0
			if not part then return nil end
		end
		local blocks = {}
		for _, p in ipairs(seg:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and p ~= root then
				table.insert(blocks, {off = root.CFrame:Inverse() * p.CFrame, half = p.Size / 2})
			end
		end
		segs[segName] = {chain = chain, blocks = blocks}
	end
	local geo = {segs = segs}
	geo.ground = ScurryPose.fk(geo, motors, {}) -- rest pose: the lowest foot block
	return geo
end

function ScurryPose.fk(geo, motors, pose)
	local low = math.huge
	for _, sg in pairs(geo.segs) do
		local cf = CFrame.identity
		for _, name in ipairs(sg.chain) do
			local e = motors[name]
			cf = cf * e.restC0 * (pose[name] or CFrame.identity) * e.motor.C1:Inverse()
		end
		for _, b in ipairs(sg.blocks) do
			local w = cf * b.off
			local h = b.half
			local ext = abs(w.RightVector.Y) * h.X + abs(w.UpVector.Y) * h.Y + abs(w.LookVector.Y) * h.Z
			low = math.min(low, w.Position.Y - ext)
		end
	end
	return low
end

-- pose for the scurry phase with the ground fit on the RootJoint (studs; the drop is in the RootJoint frame, whose Y is
-- the HumanoidRootPart's Y because the rest RootJoint C0 only turns about Y)
function ScurryPose.fitted(a, geo, motors, scale)
	local pose = ScurryPose.toPose(a)
	local drop = geo.ground - ScurryPose.fk(geo, motors, pose) + a.body[4] * (scale or 1)
	pose.RootJoint = CFrame.new(0, drop, 0) * pose.RootJoint
	return pose, drop
end

function ScurryPose.get(phase, s, geo, motors, scale)
	return ScurryPose.fitted(ScurryPose.angles(phase, s), geo, motors, scale)
end

return ScurryPose
