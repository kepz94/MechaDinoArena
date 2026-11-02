-- TRexModel2.spec v1.0 (Mecha Dino Arena) — TRexModelData 2.0 (MDA-192, plan docs/plans/TREX_REDESIGN_v1.0.md Task 1). Run in
-- Studio Edit (loadstring(Source)()); returns "PASS n" or "FAIL k/n" + the failures. Reads
-- ServerStorage.DinoArcade.Models.TRexModelData (a clone, so a fresh require).
-- Checks: the 17 rig 1.3 joints by name (and parent / child segments), all 17 segments, Head_mouth in Head and Torso_body in
-- Torso, every part colour a T-Rex role (666A4A / 50523A / B2A278) or never-paint (E8E2D2 / 111111 / F5F5F0 / 6E342E),
-- the attribute keys a superset of the place's StarterCharacter 1.2 set (tools/data/trex_starter_character_1.2_attrs.json),
-- gameplay numbers unchanged, TRexModelVersion "2.0", RigHipHeight = HipHeight + HRP half height and = the drop from the
-- HRP centre to the lowest point of the feet (feet on the ground).
local ok, D = pcall(function()
	local src = game.ServerStorage.DinoArcade.Models.TRexModelData
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(D) end
local fails, passes = {}, 0
local function check(name, cond, info)
	if cond then passes += 1 else table.insert(fails, name .. (info and (": " .. tostring(info)) or "")) end
end
local function near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= tol end

-- joints
local JOINTS = {
	RootJoint = {"HRP", "Torso"}, Neck = {"Torso", "Neck"}, Head = {"Neck", "Head"}, Jaw = {"Head", "Jaw"}, ArmL = {"Torso", "ArmL"},
	ArmR = {"Torso", "ArmR"}, Tail1 = {"Torso", "Tail1"}, Tail2 = {"Tail1", "Tail2"}, Tail3 = {"Tail2", "Tail3"}, Tail4 = {"Tail3", "Tail4"},
	Tail5 = {"Tail4", "Tail5"}, LegL = {"Torso", "LegL"}, LegR = {"Torso", "LegR"}, KneeL = {"LegL", "ShinL"}, KneeR = {"LegR", "ShinR"},
	AnkleL = {"ShinL", "FootL"}, AnkleR = {"ShinR", "FootR"},
}
local seen = {}
for _, j in ipairs(D.joints or {}) do
	seen[j.name] = true
	local want = JOINTS[j.name]
	check("joint " .. j.name .. " known", want ~= nil)
	if want then check("joint " .. j.name .. " parts", j.part0 == want[1] and j.part1 == want[2], j.part0 .. "->" .. j.part1) end
end
check("17 joints", #(D.joints or {}) == 17, #(D.joints or {}))
for n in pairs(JOINTS) do check("joint " .. n .. " present", seen[n]) end

-- segments, named parts, colours
local SEG = {"Torso", "Neck", "Head", "Jaw", "ArmL", "ArmR", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "LegL", "LegR", "ShinL", "ShinR", "FootL", "FootR"}
local segs = {}
for _, s in ipairs(D.segments or {}) do segs[s.name] = s end
for _, n in ipairs(SEG) do check("segment " .. n, segs[n] ~= nil) end
local function has(segName, partName)
	local s = segs[segName]
	if not s then return false end
	for _, p in ipairs(s.parts) do if p.name == partName then return true end end
	return false
end
check("Head_mouth in Head", has("Head", "Head_mouth"))
check("Torso_body in Torso", has("Torso", "Torso_body"))
local OKC = {["666A4A"] = true, ["50523A"] = true, ["B2A278"] = true, E8E2D2 = true, ["111111"] = true, F5F5F0 = true, ["6E342E"] = true}
local bad, lowest = {}, math.huge
for _, s in ipairs(D.segments or {}) do
	for _, p in ipairs(s.parts) do
		if not OKC[p.color] then table.insert(bad, p.name .. "=" .. p.color) end
		local cf = CFrame.new(table.unpack(p.cf))
		local h = Vector3.new(p.size[1], p.size[2], p.size[3]) / 2
		for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
			lowest = math.min(lowest, (cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y)
		end end end
	end
end
check("colours are roles / never-paint", #bad == 0, table.concat(bad, ", "))

-- attributes
local A = D.attributes or {}
local KEYS = {
	"BiteCooldown", "BiteDamage", "BiteDummyVersion", "BiteEnabled", "BiteFXVersion", "BiteHitStop", "BiteJawOpen", "BiteLunge",
	"BiteLungeDist", "BitePoseVersion", "BiteRange", "BiteReach", "BiteReachBack", "BiteRear", "BiteRecover", "BiteServerVersion",
	"BiteShake", "BiteShakeTime", "BiteSoundId", "BiteStrike", "BiteTestVersion", "BiteWindup", "BushViewVersion", "CameraStartZoom",
	"CameraZoomVersion", "CreepArmSwing", "CreepArmTuck", "CreepBodyRock", "CreepBounce", "CreepCrouch", "CreepDuty", "CreepEnabled",
	"CreepFootForward", "CreepHeadBob", "CreepLean", "CreepLift", "CreepNeckDrop", "CreepServerVersion", "CreepStepLength", "CreepSway",
	"CreepTailDrop", "CreepTailWhip", "CreepTestVersion", "CreepToeDrop", "DinoHitboxesVersion", "GaitAlwaysRun", "HeadLeadEnabled", "HeadLeadMax",
	"HeadLeadNeckShare", "HeadLeadPoseVersion", "HeadLeadSmooth", "HealthBarVersion", "HitZoneHeadMul", "HitZoneTailMul", "HitZoneTorsoMul", "HitboxViewVersion",
	"IdleAnimationVersion", "IdleBob", "IdleEnabled", "IdleHead", "IdleLookAngle", "IdleLookEnabled", "IdleLookHold", "IdleLookMaxGap",
	"IdleLookMinGap", "IdlePeriod", "IdlePoseVersion", "IdleTailPeriod", "IdleTailSway", "JumpPoseVersion", "JumpServerVersion", "JumpTestVersion",
	"KillRegenEnabled", "KillRegenFraction", "KillRegenServerVersion", "KillRegenTime", "MoveCreepSpeed", "MoveRoarSpeed", "MoveRunSpeed", "MoveWalkSpeed",
	"PounceFXVersion", "PouncePoseVersion", "PounceServerVersion", "PounceTestVersion", "RamCooldown", "RamEnabled", "RamMaxCharge", "RamPoseVersion",
	"RamRange", "RamServerVersion", "RamSpeedMul", "RamStaminaCost", "RamTestVersion", "RamWindup", "RigHipHeight", "RigVersion",
	"RoarConeAngle", "RoarCooldown", "RoarDebuffDamageTaken", "RoarDebuffDuration", "RoarDebuffEnabled", "RoarDebuffSpeed", "RoarDuration", "RoarEnabled",
	"RoarFXVersion", "RoarJawOpen", "RoarRadius", "RoarServerVersion", "RoarShake", "RoarShakeCamera", "RoarSoundId", "RoarSoundVersion",
	"RoarVersion", "RoarWaveSize", "RunBounce", "RunDuty", "RunLean", "RunStrideStretch", "ShoulderCamVersion", "Species",
	"SprintTestVersion", "StaminaBarVersion", "StaminaBiteCost", "StaminaEnabled", "StaminaMax", "StaminaPounceOnly", "StaminaRecoverFraction", "StaminaRefillTime",
	"StaminaRegenDelay", "StaminaRunTime", "StaminaServerVersion", "StaminaTiredBiteMul", "StarterCharacterVersion", "StatusBadgesVersion", "StunClientVersion", "StunFXVersion",
	"StyleVersion", "TurnHeadEnabled", "TurnHeadGain", "TurnHeadMax", "TurnHeadRoll", "TurnHeadSmooth", "TurnLimitEnabled", "TurnLimitRate",
	"TurnLimitVersion", "TurnPoseVersion", "TurnServerVersion", "WalkArmSwing", "WalkBodyRock", "WalkBounce", "WalkCrouch", "WalkDuty",
	"WalkEnabled", "WalkFootForward", "WalkHeadBob", "WalkLegSwing", "WalkLift", "WalkPoseVersion", "WalkStepLength", "WalkStrideStretch",
	"WalkSway", "WalkTailRate", "WalkTailWhip", "WalkToeDrop"
}
local missing = {}
for _, k in ipairs(KEYS) do if A[k] == nil then table.insert(missing, k) end end
check("attributes superset of StarterCharacter 1.2 (" .. #KEYS .. ")", #missing == 0, table.concat(missing, ", "))
check("TRexModelVersion 2.0", A.TRexModelVersion == "2.0", A.TRexModelVersion)
check("StarterCharacterVersion 1.3", A.StarterCharacterVersion == "1.3", A.StarterCharacterVersion)
check("Species TRex", A.Species == "TRex", A.Species)
for k, v in pairs({MoveWalkSpeed = 32, MoveRunSpeed = 60, BiteDamage = 25, BiteRange = 5, BiteReach = 1.2, BiteCooldown = 0.8,
	RoarRadius = 30, RoarConeAngle = 90, RamRange = 60, RamCooldown = 6, HitZoneHeadMul = 1.5, TurnLimitRate = 180, CameraStartZoom = 35}) do
	check("unchanged " .. k, A[k] == v, A[k])
end
check("RamEnabled / RoarEnabled / BiteEnabled", A.RamEnabled == true and A.RoarEnabled == true and A.BiteEnabled == true)

-- rig height
local hip = D.humanoid and D.humanoid.HipHeight
local hrpY = D.hrp and D.hrp.size and D.hrp.size[2]
check("RigHipHeight = HipHeight + HRP half height", near(A.RigHipHeight, (hip or 0) + (hrpY or 0) / 2, 0.01), A.RigHipHeight)
check("feet on the ground (lowest point = -RigHipHeight)", near(-lowest, A.RigHipHeight, 0.05), -lowest)

if #fails == 0 then return "PASS " .. passes end
return ("FAIL %d/%d\n"):format(#fails, #fails + passes) .. table.concat(fails, "\n")
