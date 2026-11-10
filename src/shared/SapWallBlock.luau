-- SapWallBlock v1.3 (Mecha Dino Arena) — does a live Sap Wall stand between two points? Plan docs/plans/TROODON_PARTS_v1.0.md
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
-- v1.2 (MDA-353, Kepu 2026-11-07 lobbed shots "Can go over"): SapWallBlock.arcBlocks(fromPos, toPos, peakHeight) -> true,
--   wallPart, u, hitPos | false: the real flight of a lobbed shot, p(u) = fromPos:Lerp(toPos, u) + (0, 4 x peakHeight x u x
--   (1 - u), 0) (the parabola every lobbing server / FX already draws; peakHeight = the arc's rise above the straight line at
--   the middle), sampled in SapWallArcSegments (default 16) straight segments, each raycast against the live walls only; the
--   first segment that hits a wall blocks the shot (u = the flight fraction at the hit, hitPos = the hit point; the wall part is
--   stamped WallBlockedAt / WallBlockedPos like blocks()). An arc that clears the wall's top does not block. Switch: script
--   attribute SapWallArcEnabled (default true, read at each call; false = the straight-line blocks(fromPos, toPos)).
--   Diagnostics: SapWallArcChecks, SapWallArcHits (script attributes).
-- v1.3 (troodon Shield Dome, plan docs/plans/TROODON_SLOTPARTS_v1.0.md, MDA-379; Kepu 2026-11-10 picks): the live Shield Domes
--   (TrooSlotServer 1.0: Ball parts tagged CollectionService "TrooDome", attribute TrooDomeUntil > now; centre = the part's
--   Position, radius = half its Size.X, so a growing dome blocks at its current size) block like walls, by sphere maths (no
--   raycast, so the dome part stays CanQuery false and never catches a ground / aim ray): a straight line (blocks) or an arc
--   segment (arcBlocks) that ENTERS a dome blocks; one that starts inside a dome does not (shots from inside go out, the pick).
--   The hit point is stamped on the dome like a wall (WallBlockedPos / WallBlockedAt, for TrooSlotFX). Checked before the walls
--   (a dome hit returns true, domePart). Switch: script attribute SapWallDomeEnabled (default true, read at each call; false =
--   1.2). Diagnostics: SapWallDomeChecks, SapWallDomeHits (script attributes).
local CollectionService = game:GetService("CollectionService")

local SapWallBlock = {}
SapWallBlock.Version = "1.0"
SapWallBlock.Version = "1.1" -- v1.1 posOf / between + WallBlockedAt stamps
SapWallBlock.Version = "1.2" -- v1.2 arcBlocks (lobbed shots)
SapWallBlock.Version = "1.3" -- v1.3 Shield Domes (sphere check)
SapWallBlock.ENABLED = true
script:SetAttribute("SapWallBlockVersion", SapWallBlock.Version)
if script:GetAttribute("SapWallArcEnabled") == nil then script:SetAttribute("SapWallArcEnabled", true) end -- v1.2
if script:GetAttribute("SapWallArcSegments") == nil then script:SetAttribute("SapWallArcSegments", 16) end -- v1.2
if script:GetAttribute("SapWallDomeEnabled") == nil then script:SetAttribute("SapWallDomeEnabled", true) end -- v1.3

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

function SapWallBlock.arcBlocks(fromPos, toPos, peakHeight) -- v1.2: a lobbed shot's real parabola against the live walls
	if not SapWallBlock.ENABLED or typeof(fromPos) ~= "Vector3" or typeof(toPos) ~= "Vector3" then return false end
	if script:GetAttribute("SapWallArcEnabled") == false then
		local b, w = SapWallBlock.blocks(fromPos, toPos)
		if b then return true, w, nil, w:GetAttribute("WallBlockedPos") end
		return false
	end
	local walls = liveWalls(workspace:GetServerTimeNow())
	if #walls == 0 then return false end
	script:SetAttribute("SapWallArcChecks", (script:GetAttribute("SapWallArcChecks") or 0) + 1)
	local H = tonumber(peakHeight) or 0
	local n = math.clamp(math.floor(tonumber(script:GetAttribute("SapWallArcSegments")) or 16), 1, 64)
	params.FilterDescendantsInstances = walls
	local function at(u) return fromPos:Lerp(toPos, u) + Vector3.new(0, 4 * H * u * (1 - u), 0) end
	local a = at(0)
	for i = 1, n do
		local b = at(i / n)
		local d = b - a
		if d.Magnitude > 1e-3 then
			local hit = workspace:Raycast(a, d, params)
			if hit then
				script:SetAttribute("SapWallArcHits", (script:GetAttribute("SapWallArcHits") or 0) + 1)
				if script:GetAttribute("SapWallStampEnabled") ~= false then
					hit.Instance:SetAttribute("WallBlockedPos", hit.Position)
					hit.Instance:SetAttribute("WallBlockedAt", workspace:GetServerTimeNow())
				end
				local u = (i - 1) / n + ((hit.Position - a).Magnitude / d.Magnitude) / n
				return true, hit.Instance, u, hit.Position
			end
		end
		a = b
	end
	return false
end

-- v1.3: the Shield Domes (see the header) -------------------------------------------------------------------------------------
local function liveDomes(t)
	local out = {}
	if script:GetAttribute("SapWallDomeEnabled") == false then return out end
	for _, p in ipairs(CollectionService:GetTagged("TrooDome")) do
		if p:IsA("BasePart") and p:IsDescendantOf(workspace) then
			local u = p:GetAttribute("TrooDomeUntil")
			if typeof(u) == "number" and u > t then table.insert(out, p) end
		end
	end
	return out
end
local function entry(a, b, c, R) -- the fraction of a -> b where it enters the sphere (c, R); nil when it starts inside / misses
	local d, f = b - a, a - c
	if f.Magnitude <= R then return nil end
	local A, B, C = d:Dot(d), 2 * f:Dot(d), f:Dot(f) - R * R
	if A < 1e-9 then return nil end
	local disc = B * B - 4 * A * C
	if disc < 0 then return nil end
	local u = (-B - math.sqrt(disc)) / (2 * A)
	if u >= 0 and u <= 1 then return u end
	return nil
end
local function domeHit(a, b, domes)
	local best, bestU
	for _, p in ipairs(domes) do
		local u = entry(a, b, p.Position, p.Size.X / 2)
		if u and (not bestU or u < bestU) then best, bestU = p, u end
	end
	return best, bestU
end
local function stampDome(p, pos)
	script:SetAttribute("SapWallDomeHits", (script:GetAttribute("SapWallDomeHits") or 0) + 1)
	if script:GetAttribute("SapWallStampEnabled") ~= false then
		p:SetAttribute("WallBlockedPos", pos)
		p:SetAttribute("WallBlockedAt", workspace:GetServerTimeNow())
	end
end
do
	local blocksV12 = SapWallBlock.blocks
	function SapWallBlock.blocks(fromPos, toPos)
		if SapWallBlock.ENABLED and typeof(fromPos) == "Vector3" and typeof(toPos) == "Vector3" then
			local domes = liveDomes(workspace:GetServerTimeNow())
			if #domes > 0 then
				script:SetAttribute("SapWallDomeChecks", (script:GetAttribute("SapWallDomeChecks") or 0) + 1)
				local p, u = domeHit(fromPos, toPos, domes)
				if p then
					stampDome(p, fromPos:Lerp(toPos, u))
					return true, p
				end
			end
		end
		return blocksV12(fromPos, toPos)
	end
	local arcV12 = SapWallBlock.arcBlocks
	function SapWallBlock.arcBlocks(fromPos, toPos, peakHeight)
		if SapWallBlock.ENABLED and typeof(fromPos) == "Vector3" and typeof(toPos) == "Vector3" then
			local domes = liveDomes(workspace:GetServerTimeNow())
			if #domes > 0 then
				script:SetAttribute("SapWallDomeChecks", (script:GetAttribute("SapWallDomeChecks") or 0) + 1)
				local H = tonumber(peakHeight) or 0
				local n = math.clamp(math.floor(tonumber(script:GetAttribute("SapWallArcSegments")) or 16), 1, 64)
				local function at(u) return fromPos:Lerp(toPos, u) + Vector3.new(0, 4 * H * u * (1 - u), 0) end
				local a = at(0)
				for i = 1, n do
					local b = at(i / n)
					local p, u = domeHit(a, b, domes)
					if p then
						local hitPos = a:Lerp(b, u)
						stampDome(p, hitPos)
						return true, p, (i - 1) / n + u / n, hitPos
					end
					a = b
				end
			end
		end
		return arcV12(fromPos, toPos, peakHeight)
	end
end

return SapWallBlock
