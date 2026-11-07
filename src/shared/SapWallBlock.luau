-- SapWallBlock v1.1 (Mecha Dino Arena) — does a live Sap Wall stand between two points? Plan docs/plans/TROODON_PARTS_v1.0.md
-- (Kepu 2026-11-06 21:28: "If a attack hits the wall or has to go through the wall to get to another opponent then it should be
-- stopped by the wall"), MDA-353. ServerStorage.DinoArcade.SapWallBlock (ModuleScript), required by every server that applies
-- damage at the moment it picks / resolves a target, each behind its own switch.
--   SapWallBlock.blocks(fromPos, toPos) -> true, wallPart | false: one raycast from fromPos to toPos that sees ONLY the parts
--     tagged "SapWall" (CollectionService; TrooMovesServer 1.0's walls in Workspace.TrooWalls) that are in the Workspace and
--     still live (attribute SapWallUntil > now, or no SapWallUntil). Nothing else can block it (Include filter).
--   SapWallBlock.ENABLED (default true; false = never blocks). Diagnostics: script attributes SapWallBlockChecks,
--     SapWallBlockHits (counted per call), SapWallBlockVersion.
-- v1.1 (MDA-353 server hooks): SapWallBlock.posOf(x) -> Vector3 (a Vector3 as is; a Model's HumanoidRootPart / PrimaryPart /
--   pivot; a BasePart's Position; a Humanoid's character) and SapWallBlock.between(a, b) = blocks(posOf(a), posOf(b)), the
--   call every damage server makes (attacker or splash centre -> target). A block stamps the wall part it hit: WallBlockedAt
--   (server time, last) + WallBlockedPos (the hit point), for TrooPartsFX; switch: script attribute SapWallStampEnabled
--   (default true).
local CollectionService = game:GetService("CollectionService")

local SapWallBlock = {}
SapWallBlock.Version = "1.0"
SapWallBlock.Version = "1.1" -- v1.1 posOf / between + WallBlockedAt stamps
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
		if script:GetAttribute("SapWallStampEnabled") ~= false then -- v1.1
			hit.Instance:SetAttribute("WallBlockedPos", hit.Position)
			hit.Instance:SetAttribute("WallBlockedAt", workspace:GetServerTimeNow())
		end
		return true, hit.Instance
	end
	return false
end

function SapWallBlock.posOf(x) -- v1.1
	local tx = typeof(x)
	if tx == "Vector3" then return x end
	if tx == "CFrame" then return x.Position end
	if tx ~= "Instance" then return nil end
	if x:IsA("Humanoid") then x = x.Parent if not x then return nil end end
	if x:IsA("BasePart") then return x.Position end
	if x:IsA("Model") then
		local r = x:FindFirstChild("HumanoidRootPart") or x.PrimaryPart
		if r and r:IsA("BasePart") then return r.Position end
		return x:GetPivot().Position
	end
	if x:IsA("Attachment") then return x.WorldPosition end
	return nil
end

function SapWallBlock.between(a, b) -- v1.1: true, wallPart when a live Sap Wall stands on the a -> b line
	local pa, pb = SapWallBlock.posOf(a), SapWallBlock.posOf(b)
	if not pa or not pb then return false end
	return SapWallBlock.blocks(pa, pb)
end

return SapWallBlock
