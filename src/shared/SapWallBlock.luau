-- SapWallBlock v1.0 (Mecha Dino Arena) — does a live Sap Wall stand between two points? Plan docs/plans/TROODON_PARTS_v1.0.md
-- (Kepu 2026-11-06 21:28: "If a attack hits the wall or has to go through the wall to get to another opponent then it should be
-- stopped by the wall"), MDA-353. ServerStorage.DinoArcade.SapWallBlock (ModuleScript), required by every server that applies
-- damage at the moment it picks / resolves a target, each behind its own switch.
--   SapWallBlock.blocks(fromPos, toPos) -> true, wallPart | false: one raycast from fromPos to toPos that sees ONLY the parts
--     tagged "SapWall" (CollectionService; TrooMovesServer 1.0's walls in Workspace.TrooWalls) that are in the Workspace and
--     still live (attribute SapWallUntil > now, or no SapWallUntil). Nothing else can block it (Include filter).
--   SapWallBlock.ENABLED (default true; false = never blocks). Diagnostics: script attributes SapWallBlockChecks,
--     SapWallBlockHits (counted per call), SapWallBlockVersion.
local CollectionService = game:GetService("CollectionService")

local SapWallBlock = {}
SapWallBlock.Version = "1.0"
SapWallBlock.ENABLED = true
script:SetAttribute("SapWallBlockVersion", SapWallBlock.Version)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.IgnoreWater = true

local function liveWalls(t)
	local out = {}
	for _, p in ipairs(CollectionService:GetTagged("SapWall")) do
		if p:IsA("BasePart") and p:IsDescendantOf(workspace) then
			local u = p:GetAttribute("SapWallUntil")
			if typeof(u) ~= "number" or u > t then table.insert(out, p) end
		end
	end
	return out
end

function SapWallBlock.blocks(fromPos, toPos)
	if not SapWallBlock.ENABLED or typeof(fromPos) ~= "Vector3" or typeof(toPos) ~= "Vector3" then return false end
	local walls = liveWalls(workspace:GetServerTimeNow())
	if #walls == 0 then return false end
	script:SetAttribute("SapWallBlockChecks", (script:GetAttribute("SapWallBlockChecks") or 0) + 1)
	local d = toPos - fromPos
	if d.Magnitude < 1e-3 then return false end
	params.FilterDescendantsInstances = walls
	local hit = workspace:Raycast(fromPos, d, params)
	if hit then
		script:SetAttribute("SapWallBlockHits", (script:GetAttribute("SapWallBlockHits") or 0) + 1)
		return true, hit.Instance
	end
	return false
end

return SapWallBlock
