-- Territory v1.1 (Mecha Dino Arena) — where each kind of bot may be: T-Rex land and raptor land. MDA-17, plan
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
-- v1.1 (raptor pack section, MDA-22, plan docs/plans/PACKSECTION_v1.0.md Task 1, map docs/mockups/pack_section_options.png
--   option A; Kepu 2026-10-28: "how am i supposed to kill a pack of raptors. maybe just have there be individual ones in
--   the beginning" / "packs are in their own later section of the raptor half"): two bands inside the raptor zone, split at
--   PACK_SPLIT_Z (-190):
--   RaptorSolo - Raptor and z > -190 (the half nearer the spawn: lone raptors)
--   RaptorPack - Raptor and z <= -190 (the far half: raptor packs)
--   home() for these two zones also tries, in order, pos mirrored across z = 0 and pos mirrored across both axes. TRex /
--   Raptor keep the v1.0 home (pos, x mirror, nil).
local Territory = {}
Territory.Version = "1.1"
Territory.SPAWN = Vector3.new(88, 0, 904)
Territory.SPAWN_SAFE = 300
Territory.GAP = 40
Territory.RAPTOR_MAX_Z = 560
Territory.STEP = 8
Territory.PACK_SPLIT_Z = -190 -- v1.1

local function nearSpawn(x, z)
	local dx, dz = x - Territory.SPAWN.X, z - Territory.SPAWN.Z
	return dx * dx + dz * dz < Territory.SPAWN_SAFE * Territory.SPAWN_SAFE
end

Territory.ZONES = {
	TRex = function(x, z) return x <= -Territory.GAP end,
	Raptor = function(x, z) return x >= Territory.GAP and z <= Territory.RAPTOR_MAX_Z end,
}
-- v1.1: the raptor zone's two bands
Territory.ZONES.RaptorSolo = function(x, z) return Territory.ZONES.Raptor(x, z) and z > Territory.PACK_SPLIT_Z end
Territory.ZONES.RaptorPack = function(x, z) return Territory.ZONES.Raptor(x, z) and z <= Territory.PACK_SPLIT_Z end
Territory.BANDS = {RaptorSolo = true, RaptorPack = true} -- v1.1: zones whose home() also mirrors across z

function Territory.inside(species, x, z)
	local zone = species and Territory.ZONES[species]
	if not zone then return true end
	return zone(x, z) and not nearSpawn(x, z)
end

function Territory.home(species, pos)
	if Territory.inside(species, pos.X, pos.Z) then return pos end
	if Territory.inside(species, -pos.X, pos.Z) then return Vector3.new(-pos.X, pos.Y, pos.Z) end
	if species and Territory.BANDS[species] then -- v1.1
		if Territory.inside(species, pos.X, -pos.Z) then return Vector3.new(pos.X, pos.Y, -pos.Z) end
		if Territory.inside(species, -pos.X, -pos.Z) then return Vector3.new(-pos.X, pos.Y, -pos.Z) end
	end
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
