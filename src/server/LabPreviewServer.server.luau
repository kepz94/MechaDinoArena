-- LabPreviewServer v1.1 (Mecha Dino Arena) — builds the 3D part models the Lab's part cards show. MDA-96, plan
-- docs/plans/LAB_v1.0.md Task 1, mockup docs/mockups/lab_options.html A "Workbench" (Kepu 2026-10-29: "Card with the
-- part's 3D model"; "Add a preview builder").
-- For each part: a fresh raptor mannequin (ServerStorage.DinoArcade.Models.RaptorModelData built with DinoModelBuilder, as
--   BotServer / SpeciesServer do; never in Workspace, pivoted to the origin facing -Z) is handed to that part script's
--   BindableFunction "BuildPreview" (the same build code as on a player's dino), which returns the part's Model. The part
--   is kept, everything else is dropped: joints to the body removed, every part Anchored, CanCollide / CanQuery / CanTouch
--   false, scripts / sounds / particles / trails / beams / lights removed; the model is moved so its bounding box centre is
--   at the origin (facing as on the dino) and stored as ReplicatedStorage.LabPreviews.<pathId> with attributes PathId,
--   LabPreviewSize (bounding box size, Vector3).
--   adrenaline = AdrenalineServer, screech = ScreechServer, shield = EnergyShieldServer, cloak = CloakServer,
--   blade = BladeServer, thrusters = MechaServer, traps = MineServer (a mine, no body needed).
--   scent = built here (Scent Sense has no part on the dino): a dark nose clip with three volt fins and an orange tip.
-- Each part script is waited for up to WAIT (30) s; a part that fails is listed in LabPreviewMissing.
-- Switch: script attribute LabPreviewServerEnabled (default true), read at start; false -> no previews (the Lab shows "?").
-- Diagnostics (script attributes): LabPreviewServerVersion, LabPreviewState ("building" / "ready" / "off" /
--   "noTemplate"), LabPreviewCount, LabPreviewMissing (comma list, "" = none).
-- v1.1 (Scent Sense mask, ScentServer 1.1): scent comes from ScentServer's BuildPreview (the Breather mask on a
--   mannequin) like the other parts; when that fails, the 1.0 nose sensor built here is stored instead (scent is then not
--   listed as missing).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VERSION = "1.1"
local WAIT = 30
local SOURCES = {
	{id = "adrenaline", script = "AdrenalineServer", body = true},
	{id = "screech", script = "ScreechServer", body = true},
	{id = "shield", script = "EnergyShieldServer", body = true},
	{id = "cloak", script = "CloakServer", body = true},
	{id = "blade", script = "BladeServer", body = true},
	{id = "thrusters", script = "MechaServer", body = true},
	{id = "traps", script = "MineServer", body = false},
	{id = "scent", script = "ScentServer", body = true}, -- v1.1
}
local DROP = {"BaseScript", "Sound", "ParticleEmitter", "Trail", "Beam", "Light", "Fire", "Smoke", "Sparkles"}

script:SetAttribute("LabPreviewServerVersion", VERSION)
if script:GetAttribute("LabPreviewServerEnabled") == nil then script:SetAttribute("LabPreviewServerEnabled", true) end
if script:GetAttribute("LabPreviewServerEnabled") == false then
	script:SetAttribute("LabPreviewState", "off")
	return
end
script:SetAttribute("LabPreviewState", "building")
script:SetAttribute("LabPreviewCount", 0)

local folder = ReplicatedStorage:FindFirstChild("LabPreviews")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "LabPreviews"
	folder.Parent = ReplicatedStorage
end

-- the mannequin template
local template
do
	local ok, err = pcall(function()
		local da = ServerStorage:WaitForChild("DinoArcade", 10)
		local Builder = require(da:WaitForChild("DinoModelBuilder"))
		local data = require(da:WaitForChild("Models"):WaitForChild("RaptorModelData"))
		template = Builder.build(data, {name = "LabMannequin"})
	end)
	if not ok then warn("LabPreviewServer: raptor template: " .. tostring(err)) end
end

local function clean(model)
	model.Parent = nil
	for _, d in ipairs(model:GetDescendants()) do
		local drop = false
		for _, cls in ipairs(DROP) do
			if d:IsA(cls) then drop = true break end
		end
		if drop then
			d:Destroy()
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
			local a = d:IsA("Constraint") and nil or d.Part0
			local b = d:IsA("Constraint") and nil or d.Part1
			if d:IsA("Constraint") or not (a and a:IsDescendantOf(model) and b and b:IsDescendantOf(model)) then d:Destroy() end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		end
	end
	local cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position)
	model:PivotTo(CFrame.new())
	return size
end

local function store(id, model)
	local size = clean(model)
	model.Name = id
	model:SetAttribute("PathId", id)
	model:SetAttribute("LabPreviewSize", size)
	local old = folder:FindFirstChild(id)
	if old then old:Destroy() end
	model.Parent = folder
	script:SetAttribute("LabPreviewCount", #folder:GetChildren())
end

local function scentSensor()
	local model = Instance.new("Model")
	model.Name = "Mecha_Scent"
	local function p(name, size, cf, color, neon)
		local b = Instance.new("Part")
		b.Name = name
		b.Size = size
		b.CFrame = cf
		b.Color = color
		b.Material = neon and Enum.Material.Neon or Enum.Material.Metal
		b.TopSurface, b.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		b.Parent = model
		return b
	end
	p("Clip", Vector3.new(1.4, 0.5, 1.0), CFrame.new(0, 0, 0), Color3.fromRGB(58, 67, 80))
	p("Tip", Vector3.new(0.5, 0.35, 0.35), CFrame.new(0, 0, -0.65), Color3.fromRGB(255, 155, 46), true)
	for i, x in ipairs({-0.45, 0, 0.45}) do
		p("Fin" .. i, Vector3.new(0.12, 0.55 + (i == 2 and 0.2 or 0), 0.4), CFrame.new(x, 0.45 + (i == 2 and 0.1 or 0), 0.1),
			Color3.fromRGB(127, 233, 255), true)
	end
	return model
end

local missing = {}
for _, src in ipairs(SOURCES) do
	local s = ServerScriptService:FindFirstChild(src.script)
	local fn = s and s:WaitForChild("BuildPreview", WAIT)
	local built
	if fn and (template or not src.body) then
		local ok, res = pcall(function()
			if src.body then
				local m = template:Clone()
				m:PivotTo(CFrame.new())
				local r = fn:Invoke(m)
				if r then r.Parent = nil end
				m:Destroy()
				return r
			else
				return fn:Invoke()
			end
		end)
		if ok and typeof(res) == "Instance" and res:IsA("Model") then
			built = res
		elseif not ok then
			warn("LabPreviewServer: " .. src.id .. ": " .. tostring(res))
		end
	end
	if built then
		store(src.id, built)
	elseif src.id == "scent" then -- v1.1: fall back to the 1.0 sensor
		store("scent", scentSensor())
	else
		table.insert(missing, src.id)
	end
end

script:SetAttribute("LabPreviewMissing", table.concat(missing, ","))
if not template then
	script:SetAttribute("LabPreviewState", "noTemplate")
else
	script:SetAttribute("LabPreviewState", "ready")
end
