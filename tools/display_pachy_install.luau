-- display_pachy_install v1.0 (Mecha Dino Arena) — Edit-mode builder for the pachy display models (plan
-- docs/plans/PACHY_MODEL_v1.0.md Task 3). Run once with execute_luau on the Edit datamodel; re-running replaces
-- Workspace.DinoArcade_Pachy.
-- Builds two anchored copies of ServerStorage.DinoArcade.Models.PachyModelData with DinoModelBuilder, scaled 2x (as the
-- raptor is in game, RaptorScale 2), standing on the ground north of the spawn and facing it:
--   Pachy_Display         the default look (knob ring)
--   Pachy_Display_Spikes  the fully upgraded attack look (Head_spike* shown, PachySpikes true)
-- Studio only: a Script in the folder destroys the folder on a live server (RunService:IsStudio() false), so publishing
-- the place never shows the displays to players.
local VERSION = "1.0"
local SCALE = 2
local SPOTS = {Vector3.new(116, 0, 880), Vector3.new(156, 0, 880)} -- x / z (flat grass, top 4); y from the ground
local FACE = Vector3.new(0, 0, 1) -- toward the south beach spawn (88, 904)

local SS = game:GetService("ServerStorage")
local da = SS:FindFirstChild("DinoArcade")
assert(da, "ServerStorage.DinoArcade missing")
local Builder = require(da.DinoModelBuilder)
local src = da.Models.PachyModelData
local c = src:Clone()
c.Parent = src.Parent
local data = require(c)
c:Destroy()

local old = workspace:FindFirstChild("DinoArcade_Pachy")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "DinoArcade_Pachy"
folder:SetAttribute("DisplayPachyVersion", VERSION)
local guard = Instance.new("Script")
guard.Name = "StudioOnly"
guard.Source = "-- display_pachy_install 1.0: the pachy display models are for Studio only\n"
	.. "if not game:GetService(\"RunService\"):IsStudio() then script.Parent:Destroy() end\n"
guard.Parent = folder

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {workspace.DinoIsland:FindFirstChild("Ground")} -- ground only (not trees)

local out = {}
for i, spot in ipairs(SPOTS) do
	local hit = workspace:Raycast(Vector3.new(spot.X, 400, spot.Z), Vector3.new(0, -800, 0), params)
	local groundY = hit and hit.Position.Y or 0
	local hipCentre = data.humanoid.HipHeight + data.hrp.size[2] / 2
	local pos = Vector3.new(spot.X, groundY + hipCentre, spot.Z)
	local name = i == 1 and "Pachy_Display" or "Pachy_Display_Spikes"
	local m = Builder.build(data, {name = name, pivot = CFrame.lookAt(pos, pos + FACE), anchored = true})
	m:ScaleTo(SCALE)
	if i == 2 then
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Name:match("^Head_spike") then p.Transparency = 0 end
		end
		m:SetAttribute("PachySpikes", true)
	end
	m:SetAttribute("DisplayPachyVersion", VERSION)
	m.Parent = folder
	-- stand on the ground: lowest visible point to groundY
	local lowest = math.huge
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local cf, size = p.CFrame, p.Size / 2
			for _, sx in ipairs({-1, 1}) do
				for _, sy in ipairs({-1, 1}) do
					for _, sz in ipairs({-1, 1}) do
						lowest = math.min(lowest, (cf * Vector3.new(sx * size.X, sy * size.Y, sz * size.Z)).Y)
					end
				end
			end
		end
	end
	m:PivotTo(m:GetPivot() + Vector3.new(0, groundY - lowest, 0))
	local _, bsize = m:GetBoundingBox()
	table.insert(out, ("%s ground %.1f lift %.2f size %.1f x %.1f x %.1f"):format(name, groundY, groundY - lowest, bsize.X, bsize.Y, bsize.Z))
end
folder.Parent = workspace
return table.concat(out, "\n")
