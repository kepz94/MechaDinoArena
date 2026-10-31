-- ScurryPose.spec v1.0 (Mecha Dino Arena) — tests for StarterPlayer.StarterCharacterScripts.IdleAnimation.ScurryPose (plan
-- docs/plans/HERRERA_SCURRY_v1.0.md Task 1). Run in Studio Edit through execute_luau (or loadstring of this source);
-- returns "PASS n" or "FAIL ...". Builds a Herrera from ServerStorage.DinoArcade.Models.HerreraModelData with
-- DinoModelBuilder (anchored, far away), checks the ground fit with its real joints, then destroys it.
local SCS = game.StarterPlayer.StarterCharacterScripts
local src = SCS:FindFirstChild("IdleAnimation") and SCS.IdleAnimation:FindFirstChild("ScurryPose")
if not src then return "FAIL ScurryPose missing" end
local SP = loadstring(src.Source)()
local fails, passes = {}, 0
local function ok(name, cond, info)
	if cond then passes += 1 else table.insert(fails, name .. (info and (" (" .. tostring(info) .. ")") or "")) end
end
local function near(a, b, e) return math.abs(a - b) <= (e or 1e-6) end

ok("Version", SP.Version == "1.0", SP.Version)
for k, v in pairs(SP.Defaults) do ok("default " .. k .. " number", type(v) == "number") end
local s = SP.settings(nil)
ok("settings nil model = defaults", s.ScurryArmSwing == SP.Defaults.ScurryArmSwing)

local N = 16
for i = 0, N - 1 do
	local ph = i / N * 2 * math.pi
	local a = SP.angles(ph, s)
	-- diagonal pairs swing together, the two pairs opposite
	ok("pair L-arm/R-leg " .. i, near(a.ArmL[1] - s.ScurryArmTuck, (a.LegR[1] - s.ScurryLegTuck) * s.ScurryArmSwing / s.ScurryLegSwing, 1e-6))
	ok("pair R-arm/L-leg " .. i, near(a.ArmR[1] - s.ScurryArmTuck, (a.LegL[1] - s.ScurryLegTuck) * s.ScurryArmSwing / s.ScurryLegSwing, 1e-6))
	ok("pairs opposite " .. i, near(a.ArmL[1] - s.ScurryArmTuck + a.ArmR[1] - s.ScurryArmTuck, 0, 1e-6))
	-- sprawl: each limb rolls out to its own side
	ok("ArmL out " .. i, a.ArmL[3] < 0); ok("ArmR out " .. i, a.ArmR[3] > 0)
	ok("LegL out " .. i, a.LegL[3] < 0); ok("LegR out " .. i, a.LegR[3] > 0)
	-- S-wave: body yaw, neck counter-yaw, tail lag
	ok("body yaw " .. i, near(a.body[2], s.ScurryBodyYaw * math.sin(ph), 1e-6))
	ok("neck counter " .. i, a.body[2] == 0 or (a.Neck[2] * a.body[2] < 0))
	ok("tail5 lag " .. i, near(a.Tail5[2], (s.ScurryTailWhip + 5 * s.ScurryTailWhipGrow) * math.sin(ph - 5 * s.ScurryTailLag), 1e-6))
	ok("bounce >= 0 " .. i, a.body[4] >= 0)
end
-- the crouch for the hitboxes: no yaw anywhere, sprawl kept
local m = SP.meanAngles(s)
ok("mean body yaw 0", m.body[2] == 0)
ok("mean tail yaw 0", m.Tail3[2] == 0)
ok("mean arm swing 0", m.ArmL[1] == s.ScurryArmTuck)
ok("mean sprawl L", m.LegL[3] < 0)
ok("mean bounce", near(m.body[4], s.ScurryBounce * 2 / math.pi, 1e-9))

-- override by attribute
local probe = Instance.new("Model")
probe:SetAttribute("ScurryArmSwing", 10)
ok("attribute override", SP.settings(probe).ScurryArmSwing == 10)
probe:Destroy()

-- ground fit with the real Herrera joints
local da = game.ServerStorage:FindFirstChild("DinoArcade")
local Builder = loadstring(da.DinoModelBuilder.Source)()
local data = loadstring(da.Models.HerreraModelData.Source)()
local model = Builder.build(data, {name = "ZZ_ScurrySpec", pivot = CFrame.new(0, 2000, 0), anchored = true})
model.Parent = workspace
local motors = {}
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then motors[d.Name] = {motor = d, restC0 = d.C0} end
end
local geo = SP.buildGeo(model, motors)
ok("geo built", geo ~= nil)
if geo then
	local hip = data.humanoid.HipHeight + data.hrp.size[2] / 2
	ok("rest ground = feet", near(geo.ground, -hip, 0.02), geo.ground)
	local worst = 0
	for i = 0, N - 1 do
		local a = SP.angles(i / N * 2 * math.pi, s)
		local pose, drop = SP.fitted(a, geo, motors, 1)
		local low = SP.fk(geo, motors, pose)
		worst = math.max(worst, math.abs(low - (geo.ground + a.body[4])))
		ok("drop finite " .. i, drop == drop and math.abs(drop) < 3, drop)
	end
	ok("lowest tip on the ground (16 phases)", worst <= 0.02, worst)
	local mp, mdrop = SP.fitted(m, geo, motors, 1)
	ok("mean crouch drops the body", mdrop < 0, mdrop)
	-- scale 2: the same pose fits after scaling the model
	model:ScaleTo(2)
	local motors2 = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then motors2[d.Name] = {motor = d, restC0 = d.C0} end
	end
	local geo2 = SP.buildGeo(model, motors2)
	ok("ground x2", near(geo2.ground, -2 * hip, 0.04), geo2.ground)
	local a = SP.angles(1.1, s)
	local pose2 = SP.fitted(a, geo2, motors2, 2)
	ok("x2 lowest tip on the ground", near(SP.fk(geo2, motors2, pose2), geo2.ground + 2 * a.body[4], 0.04))
end
model:Destroy()

if #fails > 0 then return "FAIL " .. #fails .. " / " .. (passes + #fails) .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
