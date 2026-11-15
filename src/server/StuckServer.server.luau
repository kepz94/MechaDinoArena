-- StuckServer v1.0 (Mecha Dino Arena) — finds a player's dino inside or under the map, for sure, and puts it back on open ground
-- (Script, ServerScriptService). MDA-547, plan docs/plans/UNSTUCK_v1.0.md rules 2–3, mockup docs/mockups/unstuck_v0.1.html; Kepu
-- 2026-11-15 11:18 "I got stuck in the island and couldn't do anything about it", 11:22 "i was pushed into the ground from an attack
-- and i was in the map", "i need you to actually be able to for sure identify when a player is stuck"; picks "Nearest open ground",
-- "Both, but free me automatically" (no prompt, no UI).
-- The map's solid pieces are Block Parts (Workspace.DinoIsland Ground / MountainSteps / Rocks / EdgeWalls; Trees are left out:
--   climbing goes through leaves), so "inside" is an exact point-in-box test, not a guess from movement.
-- Every StuckTick (0.5) s, for each player whose character is alive, its HumanoidRootPart unanchored (not parked / held / in the
--   menu), player InMenu ~= true and RespawnHold ~= true:
--   * inside: the HRP centre, or the point StuckLowFrac (0.25) x HRP height below it, lies inside a solid block by more than
--     StuckInset (0.25) studs on every axis (the point in the block's object space; candidates from GetPartBoundsInRadius);
--   * under: a ray up from the centre hits the underside of a solid block (normal.Y < -0.5) within StuckUpRange (400) studs and a
--     ray down finds no solid floor within StuckFloorRange (60) studs.
--   The same answer on StuckConfirm (2) checks in a row = stuck.
-- Free: rings around the stuck spot every StuckRingStep (4) studs out to StuckRingMax (120), 16 directions per ring (the spot
--   itself first). A spot counts when a ray down from y StuckProbeTop (1000) over the solid set + Trees (collidable) first hits
--   Ground / MountainSteps / Rocks with normal.Y > StuckFlatNormal (0.8), no water part (name contains "Water") is within 1.5
--   studs above that top, and the standing body (the HRP box at top + HRP half height + HipHeight, x 0.95) touches no solid or
--   tree part. None -> the SpawnLocation top. The move: root server-owned and anchored, PivotTo the spot (same flat facing),
--   velocity 0, after StuckHold (0.3) s unanchored and ownership back to auto. That player is not checked for StuckCooldown (2) s.
-- Players only (bots untouched); every server with Workspace.DinoIsland (island, practice, Arena).
-- Switch: script attribute StuckServerEnabled (default true, read per tick). Every number above is a script attribute.
-- Diagnostics: StuckServerVersion, StuckFrees, StuckNoSpot; player StuckLast ("inside" / "under"), StuckFreedAt, StuckFreeDist.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("StuckServerVersion", VERSION)
for k, v in pairs({StuckServerEnabled = true, StuckTick = 0.5, StuckLowFrac = 0.25, StuckInset = 0.25, StuckUpRange = 400,
	StuckFloorRange = 60, StuckConfirm = 2, StuckRingStep = 4, StuckRingMax = 120, StuckProbeTop = 1000, StuckFlatNormal = 0.8,
	StuckHold = 0.3, StuckCooldown = 2, StuckFrees = 0, StuckNoSpot = 0}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function cfg(k) return tonumber(script:GetAttribute(k)) or 0 end
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end

local SOLID = {"Ground", "MountainSteps", "Rocks", "EdgeWalls"}
local function folders(names)
	local isl = workspace:FindFirstChild("DinoIsland")
	local list = {}
	for _, n in ipairs(names) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	return list
end
local solidList = folders(SOLID)
local solidTreeList = folders({"Ground", "MountainSteps", "Rocks", "EdgeWalls", "Trees"})
local waterParts = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and string.find(string.lower(d.Name), "water", 1, true) then table.insert(waterParts, d) end
end
local function isTree(part)
	local isl = workspace:FindFirstChild("DinoIsland")
	local t = isl and isl:FindFirstChild("Trees")
	return t ~= nil and part:IsDescendantOf(t)
end

local overlapSolid = OverlapParams.new()
overlapSolid.FilterType = Enum.RaycastFilterType.Include
overlapSolid.RespectCanCollide = true
local overlapSolidTree = OverlapParams.new()
overlapSolidTree.FilterType = Enum.RaycastFilterType.Include
overlapSolidTree.RespectCanCollide = true
local overlapWater = OverlapParams.new()
overlapWater.FilterType = Enum.RaycastFilterType.Include
local raySolid = RaycastParams.new()
raySolid.FilterType = Enum.RaycastFilterType.Include
raySolid.RespectCanCollide = true
local raySolidTree = RaycastParams.new()
raySolidTree.FilterType = Enum.RaycastFilterType.Include
raySolidTree.RespectCanCollide = true
local function refreshLists()
	if #solidList == 0 then
		solidList = folders(SOLID)
		solidTreeList = folders({"Ground", "MountainSteps", "Rocks", "EdgeWalls", "Trees"})
	end
	overlapSolid.FilterDescendantsInstances = solidList
	overlapSolidTree.FilterDescendantsInstances = solidTreeList
	overlapWater.FilterDescendantsInstances = waterParts
	raySolid.FilterDescendantsInstances = solidList
	raySolidTree.FilterDescendantsInstances = solidTreeList
end

-- exact: the point is inside the block, deeper than inset on every axis
local function insideBlock(part, point, inset)
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) < h.X - inset and math.abs(p.Y) < h.Y - inset and math.abs(p.Z) < h.Z - inset
end
local function pointInSolid(point)
	local inset = cfg("StuckInset")
	for _, part in ipairs(workspace:GetPartBoundsInRadius(point, 0.05, overlapSolid)) do
		if part:IsA("BasePart") and part.CanCollide and insideBlock(part, point, inset) then return true end
	end
	return false
end
local function stuckKind(hrp)
	local c = hrp.Position
	local low = c - Vector3.new(0, hrp.Size.Y * cfg("StuckLowFrac"), 0)
	if pointInSolid(c) or pointInSolid(low) then return "inside" end
	local up = workspace:Raycast(c, Vector3.new(0, cfg("StuckUpRange"), 0), raySolid)
	if up and up.Normal.Y < -0.5 then
		local down = workspace:Raycast(c, Vector3.new(0, -cfg("StuckFloorRange"), 0), raySolid)
		if not down then return "under" end
	end
	return nil
end

-- nearest open ground
local function openSpot(x, z, hrp, hum)
	local top = cfg("StuckProbeTop")
	local r = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top + 600), 0), raySolidTree)
	if not r or isTree(r.Instance) or r.Normal.Y <= cfg("StuckFlatNormal") then return nil end
	local y = r.Position.Y
	if #waterParts > 0 and #workspace:GetPartBoundsInRadius(Vector3.new(x, y + 1.5, z), 0.5, overlapWater) > 0 then return nil end
	local centreY = y + hrp.Size.Y / 2 + hum.HipHeight
	local box = CFrame.new(x, centreY, z)
	if #workspace:GetPartBoundsInBox(box, hrp.Size * 0.95, overlapSolidTree) > 0 then return nil end
	return Vector3.new(x, centreY, z)
end
local function findSpot(from, hrp, hum)
	local s = openSpot(from.X, from.Z, hrp, hum)
	if s then return s end
	local step, maxR = math.max(1, cfg("StuckRingStep")), cfg("StuckRingMax")
	local r = step
	while r <= maxR do
		for i = 0, 15 do
			local a = (i / 16) * math.pi * 2
			s = openSpot(from.X + math.cos(a) * r, from.Z + math.sin(a) * r, hrp, hum)
			if s then return s end
		end
		r += step
	end
	return nil
end

local streak = {} -- [player] = {kind, n}
local restUntil = {} -- [player] = os.clock()
local function free(pl, c, hrp, hum, kind)
	local from = hrp.Position
	local spot = findSpot(from, hrp, hum)
	if not spot then
		bump("StuckNoSpot")
		local sl = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if not sl then return end
		spot = sl.Position + Vector3.new(0, sl.Size.Y / 2 + hrp.Size.Y / 2 + hum.HipHeight, 0)
	end
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
	pcall(function() hrp:SetNetworkOwner(nil) end)
	hrp.Anchored = true
	c:PivotTo(CFrame.lookAt(spot, spot + look.Unit) * c:GetPivot():ToObjectSpace(hrp.CFrame):Inverse())
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.delay(cfg("StuckHold"), function()
		if hrp.Parent and hrp.Anchored and pl:GetAttribute("InMenu") ~= true and pl:GetAttribute("RespawnHold") ~= true then
			hrp.Anchored = false
			pcall(function() hrp:SetNetworkOwnershipAuto() end)
		end
	end)
	pl:SetAttribute("StuckLast", kind)
	pl:SetAttribute("StuckFreeDist", math.floor((spot - from).Magnitude * 10 + 0.5) / 10)
	pl:SetAttribute("StuckFreedAt", workspace:GetServerTimeNow())
	bump("StuckFrees")
	restUntil[pl] = os.clock() + cfg("StuckCooldown") + cfg("StuckHold")
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < math.max(0.1, cfg("StuckTick")) then return end
	acc = 0
	if script:GetAttribute("StuckServerEnabled") == false then return end
	refreshLists()
	if #solidList == 0 then return end
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local ok = hrp and hum and hum.Health > 0 and not hrp.Anchored and pl:GetAttribute("InMenu") ~= true
			and pl:GetAttribute("RespawnHold") ~= true and (restUntil[pl] or 0) <= os.clock()
		local kind = ok and stuckKind(hrp) or nil
		if not kind then
			streak[pl] = nil
		else
			local s = streak[pl]
			if s and s.kind == kind then s.n += 1 else s = {kind = kind, n = 1} streak[pl] = s end
			if s.n >= math.max(1, cfg("StuckConfirm")) then
				streak[pl] = nil
				free(pl, c, hrp, hum, kind)
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(pl) streak[pl], restUntil[pl] = nil, nil end)
