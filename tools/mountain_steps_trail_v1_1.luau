-- mountain_steps_trail v1.1 (Mecha Dino Arena) — step blocks along the mountain trail's cliffs (Island 3.4). MDA-398, plan
-- docs/plans/HARDPOINT_v1.0.md Task 3. Kepu 2026-11-10: "Fix the seven stud steps to be walkable" -> (after the Play numbers)
--   "Step blocks along the trail": the sand trail spirals round the mountain and leaves 23-41-stud cliffs wherever it
--   passes, because mountain_steps_v1 1.0 never shelves a face whose LOW side is Trail ("so the trail stays clear").
-- Additive: Workspace.DinoIsland.MountainSteps keeps every 1.0 part; this script adds (re-running replaces) the subfolder
--   MountainSteps.TrailSteps. Deleting that subfolder restores Island 3.3. Re-running mountain_steps_v1 replaces the whole
--   MountainSteps folder (TrailSteps goes with it; run this again after it).
-- Height map as mountain_steps_v1 (16-stud cells, highest Ground part top per cell, kind = its Name; water kinds skipped).
-- A face between a Trail cell L and a 4-neighbour cell H that is not Trail and not water, D = top(H) - top(L),
--   STEP_MIN < D <= MAX_FIX, gets r - 1 thin shelves on L against the face, r = max(2, ceil(D / RISE)): shelf s (1 = next to
--   the face) is 16 wide, DEPTH deep (so the trail keeps 16 - (r - 1) x DEPTH studs clear), from top(L) up by
--   round(D x (r - s) / r). With StepAssistCore 1.1 a dino walks up shelf by shelf (every rise <= RISE <= its mountain max).
--   Colour / material / surfaces from H's part.
-- v1.1 also (rule B): a face mountain_steps_v1 left alone because it is too tall (its MAX_FIX 30): LOW side Rock / Grass /
--   Meadow, HIGH side Rock or Trail, V1_MAX_FIX < D <= MAX_FIX -> the same thin shelves on the low cell (measured in Play: a
--   raptor on a 1.0 shelf at 161 faced the trail at 186, a 25 rise, at the summit's east side).
-- Run in Studio Edit through execute_luau. Folder attributes: TrailStepsVersion, TrailStepsFaces, TrailStepsParts,
--   TrailStepsSkippedHigh (faces over MAX_FIX). Island attribute IslandTrailStepsVersion 1.1, IslandVersion 3.4.
local RISE = 14
local DEPTH = 2.5
local STEP_MIN = 2.6
local MAX_FIX = 45
local CELL = 16
local V1_MAX_FIX = 30
local LOW_B = {RockGround = true, Grass = true, Meadow = true}
local HIGH_B = {RockGround = true, Trail = true}
local island = workspace:FindFirstChild("DinoIsland")
if not island then return "no DinoIsland" end
local ground = island:FindFirstChild("Ground")
local steps = island:FindFirstChild("MountainSteps")
if not ground or not steps then return "no Ground / MountainSteps" end

local SKIP = {Water = true, LakeWater = true, Seabed = true, Shallows = true}
local top, kind, part = {}, {}, {}
local OFS = 1000
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
local faces, skipped = {}, 0
for lk, tL in pairs(top) do
	if kind[lk] == "Trail" then
		local i, j = unkey(lk)
		for _, d in ipairs(DIRS) do
			local hk = key(i + d[1], j + d[2])
			local tH = top[hk]
			if tH and kind[hk] ~= "Trail" then
				local D = tH - tL
				if D > STEP_MIN + 0.01 then
					if D <= MAX_FIX + 0.01 then
						table.insert(faces, {hk = hk, lk = lk, di = d[1], dj = d[2], D = D}) -- di / dj: from L to H
					else
						skipped += 1
					end
				end
			end
		end
	end
end

-- rule B: the tall faces 1.0 skipped
local skippedB = 0
for lk, tL in pairs(top) do
	if LOW_B[kind[lk]] then
		local i, j = unkey(lk)
		for _, d in ipairs(DIRS) do
			local hk = key(i + d[1], j + d[2])
			local tH = top[hk]
			if tH and HIGH_B[kind[hk]] then
				local D = tH - tL
				if D > V1_MAX_FIX + 0.01 then
					if D <= MAX_FIX + 0.01 then
						table.insert(faces, {hk = hk, lk = lk, di = d[1], dj = d[2], D = D, b = true})
					else
						skippedB += 1
					end
				end
			end
		end
	end
end

local old = steps:FindFirstChild("TrailSteps")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "TrailSteps"
local parts = 0
for _, f in ipairs(faces) do
	local i, j = unkey(f.lk)
	local tL = top[f.lk]
	local src = part[f.hk]
	local r = math.max(2, math.ceil(f.D / RISE))
	local cx, cz = i * CELL + CELL / 2, j * CELL + CELL / 2
	for s = 1, r - 1 do
		local h = math.floor(f.D * (r - s) / r + 0.5)
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
		local off = CELL / 2 - DEPTH * (s - 0.5) -- from L's centre toward the face
		local px, pz = cx + f.di * off, cz + f.dj * off
		if f.di ~= 0 then
			b.Size = Vector3.new(DEPTH, h, CELL)
		else
			b.Size = Vector3.new(CELL, h, DEPTH)
		end
		b.Position = Vector3.new(px, tL + h / 2, pz)
		b:SetAttribute("StepFace", ("%s %d,%d>%d,%d D%d"):format(f.b and "tall" or "trail", i, j, i + f.di, j + f.dj, math.floor(f.D + 0.5)))
		b.Parent = folder
		parts += 1
	end
end
folder:SetAttribute("TrailStepsVersion", "1.1")
folder:SetAttribute("TrailStepsFaces", #faces)
folder:SetAttribute("TrailStepsParts", parts)
folder:SetAttribute("TrailStepsSkippedHigh", skipped + skippedB)
folder.Parent = steps
island:SetAttribute("IslandTrailStepsVersion", "1.1")
island:SetAttribute("IslandVersion", "3.4")
return ("faces %d, parts %d, skipped (over %d) trail %d tall %d"):format(#faces, parts, MAX_FIX, skipped, skippedB)
