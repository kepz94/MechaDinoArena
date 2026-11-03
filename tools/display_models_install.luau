-- display_models_install v1.0 (Mecha Dino Arena) — Edit-mode builder for the display models of the four model-only dinos
-- (MDA-187 Troodon, MDA-188 Therizino, MDA-189 Zuul, MDA-190 Dilo; the display_teno_install 1.0 pattern). Run once with
-- execute_luau on the Edit datamodel; re-running replaces each Workspace.DinoArcade_<Species> folder.
-- Each display = one anchored copy of ServerStorage.DinoArcade.Models.<Species>ModelData built with DinoModelBuilder, scaled
-- 2x (as every dino is in game), standing on the flat beach strip east of the Teno display (z 925, ground y -0.4 from x 170
-- to 335, checked by raycast 2026-11-02), heads toward the spawn side (-X), in a row:
--   Troodon_Display    x 180   (~24 studs long)
--   Dilo_Display       x 210   (~26)
--   Therizino_Display  x 245   (~32)
--   Zuul_Display       x 290   (~40; at x 305 its tail went into the rock step east of the beach)
-- The Dilo frill is built twice (48 open "_frill" parts, 8 folded "_fold" parts): every "_fold" part is hidden
-- (Transparency 1), so the display shows the frill open (MDA-190).
-- Studio only: a Script in each folder destroys the folder on a live server (RunService:IsStudio() false), so publishing the
-- place never shows the displays to players. Returns one line per display (ground, lift, size, visible part count).
local VERSION = "1.0"
local SCALE = 2
local Z = 925
local FACE = Vector3.new(-1, 0, 0)
local LIST = {
	{species = "Troodon", x = 180},
	{species = "Dilo", x = 210},
	{species = "Therizino", x = 245},
	{species = "Zuul", x = 290},
}

local SS = game:GetService("ServerStorage")
local da = SS:FindFirstChild("DinoArcade")
assert(da, "ServerStorage.DinoArcade missing")
local Builder = require(da.DinoModelBuilder)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {workspace.DinoIsland:FindFirstChild("Ground")} -- ground only (not trees)

local out = {}
for _, e in ipairs(LIST) do
	local src = da.Models:FindFirstChild(e.species .. "ModelData")
	if not src then
		table.insert(out, e.species .. ": model data missing")
		continue
	end
	local c = src:Clone()
	c.Parent = src.Parent
	local data = require(c)
	c:Destroy()

	local fname = "DinoArcade_" .. e.species
	local old = workspace:FindFirstChild(fname)
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = fname
	folder:SetAttribute("DisplayModelsVersion", VERSION)
	local guard = Instance.new("Script")
	guard.Name = "StudioOnly"
	guard.Source = "-- display_models_install 1.0: this display model is for Studio only\n"
		.. "if not game:GetService(\"RunService\"):IsStudio() then script.Parent:Destroy() end\n"
	guard.Parent = folder

	local hit = workspace:Raycast(Vector3.new(e.x, 400, Z), Vector3.new(0, -800, 0), params)
	local groundY = hit and hit.Position.Y or 0
	local hipCentre = data.humanoid.HipHeight + data.hrp.size[2] / 2
	local pos = Vector3.new(e.x, groundY + hipCentre, Z)
	local m = Builder.build(data, {name = e.species .. "_Display", pivot = CFrame.lookAt(pos, pos + FACE), anchored = true})
	m:ScaleTo(SCALE)
	m:SetAttribute("DisplayModelsVersion", VERSION)
	m.Parent = folder
	-- stand on the ground: lowest visible point to groundY
	for _, p in ipairs(m:GetDescendants()) do -- the folded frill copy stays hidden
		if p:IsA("BasePart") and p.Name:find("_fold") then p.Transparency = 1 end
	end
	local lowest, parts = math.huge, 0
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			parts += 1
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
	table.insert(out, ("%s ground %.1f lift %.2f size %.1f x %.1f x %.1f parts %d"):format(e.species .. "_Display", groundY,
		groundY - lowest, bsize.X, bsize.Y, bsize.Z, parts))
end
return table.concat(out, "\n")
