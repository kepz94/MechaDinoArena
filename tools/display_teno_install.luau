-- display_teno_install v1.0 (Mecha Dino Arena) — Edit-mode builder for the Tenontosaurus display model (plan
-- docs/plans/TENO_MODEL_v1.0.md Task 3, MDA-171). Run once with execute_luau on the Edit datamodel; re-running replaces
-- Workspace.DinoArcade_Teno.
-- Builds one anchored copy of ServerStorage.DinoArcade.Models.TenoModelData with DinoModelBuilder, scaled 2x (as the
-- raptor / pachy / Herrera are in game), standing on the flat beach east of the south spawn, side-on to it:
--   Teno_Display   the Classic look (Goofy Noodle), standing on all fours (the rest stance); its long tail runs east, away from the spawn
-- Studio only: a Script in the folder destroys the folder on a live server (RunService:IsStudio() false), so publishing
-- the place never shows the display to players.
local VERSION = "1.0"
local SCALE = 2
local SPOT = Vector3.new(132, 0, 918) -- x / z: flat beach east of the south spawn (88, 904); the ~50-stud body runs east-west; y from the ground
local FACE = Vector3.new(-1, 0, 0) -- head toward the spawn side, so a player at the spawn sees it side-on

local SS = game:GetService("ServerStorage")
local da = SS:FindFirstChild("DinoArcade")
assert(da, "ServerStorage.DinoArcade missing")
local Builder = require(da.DinoModelBuilder)
local src = da.Models.TenoModelData
local c = src:Clone()
c.Parent = src.Parent
local data = require(c)
c:Destroy()

local old = workspace:FindFirstChild("DinoArcade_Teno")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "DinoArcade_Teno"
folder:SetAttribute("DisplayTenoVersion", VERSION)
local guard = Instance.new("Script")
guard.Name = "StudioOnly"
guard.Source = "-- display_teno_install 1.0: the teno display model is for Studio only\n"
	.. "if not game:GetService(\"RunService\"):IsStudio() then script.Parent:Destroy() end\n"
guard.Parent = folder

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {workspace.DinoIsland:FindFirstChild("Ground")} -- ground only (not trees)

local hit = workspace:Raycast(Vector3.new(SPOT.X, 400, SPOT.Z), Vector3.new(0, -800, 0), params)
local groundY = hit and hit.Position.Y or 0
local hipCentre = data.humanoid.HipHeight + data.hrp.size[2] / 2
local pos = Vector3.new(SPOT.X, groundY + hipCentre, SPOT.Z)
local m = Builder.build(data, {name = "Teno_Display", pivot = CFrame.lookAt(pos, pos + FACE), anchored = true})
m:ScaleTo(SCALE)
m:SetAttribute("DisplayTenoVersion", VERSION)
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
folder.Parent = workspace
return ("Teno_Display ground %.1f lift %.2f size %.1f x %.1f x %.1f"):format(groundY, groundY - lowest, bsize.X, bsize.Y, bsize.Z)
