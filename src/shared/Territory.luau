-- Territory v1.0 (Mecha Dino Arena) — where each kind of bot may be: T-Rex land and raptor land. MDA-17, plan
-- docs/plans/TERRITORIES_v1.0.md Task 1, map docs/mockups/territory_options.png option A (Kepu 2026-10-28: "territories
-- basically so youre only running into t-rexes in one area and only running into raptors in another"; left / right
-- halves; a chasing bot stops at the border). Pure: no Instance access.
-- Zones (flat x, z; the island is -940..940):
--   TRex   - x <= -40 (the left half)
--   Raptor - x >= 40 and z <= 560 (the right half, minus the spawn side)
--   both   - not within SPAWN_SAFE (300) studs of SPAWN (88, 0, 904): no bots near where players appear.
--   Between x -40 and 40 is nobody's land. A species without a zone (anything else, nil) may be anywhere.
-- inside(species, x, z) -> boolean.
-- home(species, pos) -> pos when inside; else pos mirrored across x = 0 when that is inside; else nil (the caller picks
--   another spot). Keeps pos.Y.
-- pathInside(species, from, to) -> true when every point every STEP (8) studs along the flat straight line (both ends
--   included) is inside.
local Territory = {}
Territory.Version = "1.0"
Territory.SPAWN = Vector3.new(88, 0, 904)
Territory.SPAWN_SAFE = 300
Territory.GAP = 40
Territory.RAPTOR_MAX_Z = 560
Territory.STEP = 8

local function nearSpawn(x, z)
	local dx, dz = x - Territory.SPAWN.X, z - Territory.SPAWN.Z
	return dx * dx + dz * dz < Territory.SPAWN_SAFE * Territory.SPAWN_SAFE
end

Territory.ZONES = {
	TRex = function(x, z) return x <= -Territory.GAP end,
	Raptor = function(x, z) return x >= Territory.GAP and z <= Territory.RAPTOR_MAX_Z end,
}

function Territory.inside(species, x, z)
	local zone = species and Territory.ZONES[species]
	if not zone then return true end
	return zone(x, z) and not nearSpawn(x, z)
end

function Territory.home(species, pos)
	if Territory.inside(species, pos.X, pos.Z) then return pos end
	if Territory.inside(species, -pos.X, pos.Z) then return Vector3.new(-pos.X, pos.Y, pos.Z) end
	return nil
end

function Territory.pathInside(species, from, to)
	if not (species and Territory.ZONES[species]) then return true end
	local a = Vector3.new(from.X, 0, from.Z)
	local d = Vector3.new(to.X, 0, to.Z) - a
	local len = d.Magnitude
	local steps = math.max(1, math.ceil(len / Territory.STEP))
	for i = 0, steps do
		local q = a + d * (i / steps)
		if not Territory.inside(species, q.X, q.Z) then return false end
	end
	return true
end

return Territory
