-- mountain_steps_v1 v1.0 (Mecha Dino Arena) — makes the mountain climbable by jumping (Island 3.3).
-- Kepu 2026-10-30: "make the mountain blocks not so high because we had trouble climbing the mountain last night as well.
--   the mountain height itself is fine it should just be scalable through jumping as well as the dedicated path."
-- Measured in Studio Play (test pad, raptor JumpPower 59, JumpBoost 10): a ledge of 8 / 10 / 12 studs is cleared from a
--   standing start and from every run-up tested; 14 is never cleared. The mountain's cliff bands are 14 studs
--   (island_v3_generator 1.2 MOUNTAIN_TIER, "> the raptor's 11-stud leap"), so its rock could only be climbed by the trail.
--   Shelves in front of a face: 14 + one 7-stud shelf (8 deep) -> one jump; 20 + one 10-stud shelf -> 2 jumps; 28 + two
--   shelves (5.3 deep each) -> 3 jumps; 42 + four shelves (3.2 deep) -> not climbable (too shallow), so faces over
--   MAX_FIX are left as they are.
-- Run in Studio Edit through execute_luau. Additive: the island's ground blocks are not changed; every shelf is a new
--   part in Workspace.DinoIsland.MountainSteps (re-running replaces that folder; deleting the folder restores 3.2).
-- Height map: every Ground part except Water / LakeWater / Seabed, per 16-stud cell (cell i covers x 16i .. 16i + 16),
--   top = the highest part top over the cell, kind = that part's Name, part = that part.
-- A face between a high cell H (kind RockGround or Trail) and a 4-neighbour low cell L (kind RockGround, Grass or
--   Meadow; never Trail, so the trail stays clear) with D = top(H) - top(L), CLIMB < D <= MAX_FIX, gets n - 1 shelves on
--   L against the face, n = ceil(D / CLIMB): shelf k (1 = next to the face) is 16 wide, 16 / n deep, from top(L) up by
--   round(D * (n - k) / n). Colour / material / surfaces from H's part (a trail face gets trail-coloured steps).
-- Reachability check by jumping (before / after): BFS over land cells (every kind but water) WITHOUT the trail (trail
--   cells are never entered: the trail is the other way up), starting from all non-rock land cells; a step A -> B is
--   allowed when top(B) - top(A) <= CLIMB, or (after) when that face got shelves on A. Counts RockGround cells not reached.
-- Folder attributes: MountainStepsVersion, MountainStepsClimb, MountainStepsMaxFix, MountainStepsFaces,
--   MountainStepsParts, MountainStepsUnreachBefore, MountainStepsUnreachAfter, MountainStepsUnreachTopAfter (highest
--   unreachable top). Island attributes: IslandVersion 3.3, IslandMountainStepsVersion 1.0.
local CLIMB = 10
local MAX_FIX = 30
local CELL = 16
local island = workspace:FindFirstChild("DinoIsland")
if not island then return "no DinoIsland" end
local ground = island:FindFirstChild("Ground")
if not ground then return "no Ground" end

local SKIP = {Water = true, LakeWater = true, Seabed = true}
local HIGH_KINDS = {RockGround = true, Trail = true}
local LOW_KINDS = {RockGround = true, Grass = true, Meadow = true}
local ROCK = {RockGround = true, Trail = true}

local top, kind, part = {}, {}, {}
local OFS = 1000 -- cell indices are negative west / north of the origin; keys stay positive
local function key(i, j) return (i + OFS) * 100000 + (j + OFS) end
local function unkey(k) return k // 100000 - OFS, k % 100000 - OFS end
for _, p in ipairs(ground:GetChildren()) do
	if p:IsA("BasePart") and not SKIP[p.Name] then
		local t = p.Position.Y + p.Size.Y / 2
		local x0, x1 = p.Position.X - p.Size.X / 2, p.Position.X + p.Size.X / 2
		local z0, z1 = p.Position.Z - p.Size.Z / 2, p.Position.Z + p.Size.Z / 2
		for x = x0 + CELL / 2, x1 - 1, CELL do
			for z = z0 + CELL / 2, z1 - 1, CELL do
				local k = key(math.floor(x / CELL), math.floor(z / CELL))
				if not top[k] or t > top[k] then top[k], kind[k], part[k] = t, p.Name, p end
			end
		end
	end
end

local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
-- faces that get shelves: shelved[lowKey .. ":" .. highKey] = true
local shelved = {}
local faces = {}
for k, tH in pairs(top) do
	if HIGH_KINDS[kind[k]] then
		local i, j = unkey(k)
		for _, d in ipairs(DIRS) do
			local lk = key(i + d[1], j + d[2])
			local tL = top[lk]
			if tL and LOW_KINDS[kind[lk]] then
				local D = tH - tL
				if D > CLIMB + 0.01 and D <= MAX_FIX + 0.01 then
					table.insert(faces, {hk = k, lk = lk, di = -d[1], dj = -d[2], D = D}) -- di / dj: from L to H
					shelved[lk .. ":" .. k] = true
				end
			end
		end
	end
end

local function unreachable(withShelves)
	local reached, queue, head = {}, {}, 1
	for k in pairs(top) do
		if not ROCK[kind[k]] then reached[k] = true table.insert(queue, k) end
	end
	while head <= #queue do
		local a = queue[head]
		head += 1
		local i, j = unkey(a)
		for _, d in ipairs(DIRS) do
			local b = key(i + d[1], j + d[2])
			if top[b] and not reached[b] and kind[b] ~= "Trail" then
				local up = top[b] - top[a]
				if up <= CLIMB + 0.01 or (withShelves and shelved[a .. ":" .. b]) then
					reached[b] = true
					table.insert(queue, b)
				end
			end
		end
	end
	local n, highest = 0, -math.huge
	for k in pairs(top) do
		if kind[k] == "RockGround" and not reached[k] then
			n += 1
			highest = math.max(highest, top[k])
		end
	end
	return n, highest
end
local before = unreachable(false)

local old = island:FindFirstChild("MountainSteps")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "MountainSteps"

local parts = 0
for _, f in ipairs(faces) do
	local i, j = unkey(f.lk)
	local tL = top[f.lk]
	local src = part[f.hk]
	local n = math.ceil(f.D / CLIMB)
	local depth = CELL / n
	-- the face: between low cell (i, j) and high cell (i + di, j + dj); di / dj point from L to H
	local cx, cz = i * CELL + CELL / 2, j * CELL + CELL / 2
	for s = 1, n - 1 do
		local h = math.floor(f.D * (n - s) / n + 0.5)
		local b = Instance.new("Part")
		b.Name = "MountainStep"
		b.Anchored = true
		b.CanTouch = src.CanTouch
		b.CanQuery = src.CanQuery
		b.CastShadow = src.CastShadow
		b.Color = src.Color
		b.Material = src.Material
		b.TopSurface = src.TopSurface
		b.BottomSurface = src.BottomSurface
		-- distance from the face to this shelf's centre, into L
		local off = CELL / 2 - depth * (s - 0.5)
		local px = cx + f.di * off
		local pz = cz + f.dj * off
		if f.di ~= 0 then
			b.Size = Vector3.new(depth, h, CELL)
		else
			b.Size = Vector3.new(CELL, h, depth)
		end
		b.Position = Vector3.new(px, tL + h / 2, pz)
		b:SetAttribute("StepFace", ("%d,%d>%d,%d D%d"):format(i, j, i + f.di, j + f.dj, math.floor(f.D + 0.5)))
		b.Parent = folder
		parts += 1
	end
end
folder.Parent = island

local after, highestAfter = unreachable(true)
folder:SetAttribute("MountainStepsVersion", "1.0")
folder:SetAttribute("MountainStepsClimb", CLIMB)
folder:SetAttribute("MountainStepsMaxFix", MAX_FIX)
folder:SetAttribute("MountainStepsFaces", #faces)
folder:SetAttribute("MountainStepsParts", parts)
folder:SetAttribute("MountainStepsUnreachBefore", before)
folder:SetAttribute("MountainStepsUnreachAfter", after)
folder:SetAttribute("MountainStepsUnreachTopAfter", after > 0 and highestAfter or 0)
island:SetAttribute("IslandVersion", "3.3")
island:SetAttribute("IslandMountainStepsVersion", "1.0")
return ("faces %d, parts %d, unreachable rock cells before %d, after %d (highest %s)"):format(#faces, parts, before, after,
	after > 0 and tostring(highestAfter) or "-")
