-- arena_spawns_install.luau (Mecha Dino Arena) — run in the Studio command bar (Edit) to (re)create Workspace.ArenaSpawns,
-- the 8 spawn points ArenaSpawnServer 1.0 uses in the Arena. Positions picked 2026-10-31 by raycast: flat dry Ground,
-- no Trees / Rocks / MountainSteps / EdgeWalls within 18 studs, in a ring around the island (8 x 45 degrees from the
-- beach SpawnLocation's angle); ArenaSpawn1 = the beach SpawnLocation spot. Map: docs/reference/arena/arena_spawns_map.jpg.
local pts = {
	Vector3.new(88, 0.1, 904), Vector3.new(-661, 10, 803), Vector3.new(-617, 8, 60), Vector3.new(-494, 10, -407),
	Vector3.new(-50, 2, -518), Vector3.new(610, 10, -741), Vector3.new(836, 10, -81), Vector3.new(788, 6, 648),
}
local old = workspace:FindFirstChild("ArenaSpawns")
if old then old:Destroy() end
local f = Instance.new("Folder")
f.Name = "ArenaSpawns"
for i, p in ipairs(pts) do
	local part = Instance.new("Part")
	part.Name = "ArenaSpawn" .. i
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Size = Vector3.new(12, 1, 12)
	part.CFrame = CFrame.new(p + Vector3.new(0, 0.5, 0))
	part.Transparency = 1
	part:SetAttribute("ArenaSpawnIndex", i)
	part.Parent = f
end
f.Parent = workspace
