-- DiloPartsVFXLib v1.0 (Mecha Dino Arena) — the pure maths of DiloPartsVFX 1.0 (ModuleScript, StarterPlayerScripts; plan
-- docs/plans/DILO_VFX_v1.0.md Task 2, MDA-391). No instances, no services: DiloPartsVFX.client and the spec
-- tools/tests/DiloPartsVFX.spec.luau require it.
--   parseV(s) "x,y,z" -> Vector3 | nil
--   parseShot(s) DiloGatlingShot "i;fx,fy,fz;tx,ty,tz;flight;target" -> {i, from, to, flight, target} | nil
--   parseSpineHits(s) DiloSpineHits "name=n|name=n" -> {{name, n}} (n >= 1)
--   names(s) "a|b|c" -> {"a", "b", "c"}
--   wedges(R, n, w) -> n {angle, cf (relative to the ring centre, the wedge's centre on the circle, facing its tangent), size
--     (Vector3: tangent length x 0.15 x radial width)} for the hazard-stripe ring; alternate i odd / even = yellow / dark
--   ringPoints(R) -> the 4 Bezier attachment CFrames of a flat circle of radius R (centre space; X axis = the tangent,
--     counter-clockwise) and the curve size (0.5523 x R) for 4 Beams
--   arcPoints(R, halfDeg, dirAngle) -> the 3 attachment CFrames + the curve size of a 2-Beam arc of R studs spanning
--     dirAngle +- halfDeg (flat; angles in radians from +X towards -Z... see the code)
--   arcCurve(R, spanRad) -> the Bezier control length of a circular arc of span spanRad (4/3 tan(span/4) R)
--   chevrons(len, gap) -> the distances along a trail at which a chevron sits (from gap / 2, every gap, inside len)
--   pickTrim(list, need) -> the indices (oldest first) to finish so that the live part count drops by at least need; list =
--     {{parts = n}} in start order
local M = {}
M.VERSION = "1.0"

function M.parseV(s)
	if type(s) ~= "string" then return nil end
	local x, y, z = s:match("^%s*([%-%d%.eE]+),([%-%d%.eE]+),([%-%d%.eE]+)%s*$")
	if not x then return nil end
	local v = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
	if v ~= v then return nil end
	return v
end

function M.parseShot(s)
	if type(s) ~= "string" then return nil end
	local i, fs, ts, fl, tg = s:match("^(%d+);([^;]+);([^;]+);([^;]+);?(.*)$")
	if not i then return nil end
	local from, to, flight = M.parseV(fs), M.parseV(ts), tonumber(fl)
	if not (from and to and flight) then return nil end
	return {i = tonumber(i), from = from, to = to, flight = math.max(0.01, flight), target = tg or ""}
end

function M.parseSpineHits(s)
	local out = {}
	if type(s) ~= "string" then return out end
	for name, n in s:gmatch("([^|=]+)=(%d+)") do
		local c = tonumber(n)
		if c and c >= 1 then table.insert(out, {name = name, n = c}) end
	end
	return out
end

function M.names(s)
	local out = {}
	if type(s) ~= "string" then return out end
	for name in s:gmatch("[^|]+") do table.insert(out, name) end
	return out
end

function M.wedges(R, n, w)
	local out = {}
	n = math.max(3, math.floor(n or 28))
	w = w or 0.08 * R
	local len = 2 * math.pi * R / n
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * 2 * math.pi
		local pos = Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		out[i + 1] = {angle = a, cf = CFrame.lookAt(pos, pos + tangent), size = Vector3.new(w, 0.15, len * 1.02), dark = i % 2 == 1}
	end
	return out
end

local function tangentCF(pos, tangent)
	return CFrame.fromMatrix(pos, tangent, Vector3.yAxis)
end
function M.ringPoints(R)
	local cfs = {}
	for i = 0, 3 do
		local a = i * math.pi / 2
		local pos = Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
		cfs[i + 1] = tangentCF(pos, Vector3.new(-math.sin(a), 0, math.cos(a)))
	end
	return cfs, 0.5523 * R
end

function M.arcCurve(R, span)
	return 4 / 3 * math.tan(span / 4) * R
end

-- dirAngle: the angle (radians, in the X/Z plane measured from +X towards +Z) the arc's middle points at
function M.arcPoints(R, halfDeg, dirAngle)
	local half = math.rad(halfDeg)
	local cfs = {}
	for i, a in ipairs({dirAngle - half, dirAngle, dirAngle + half}) do
		local pos = Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
		cfs[i] = tangentCF(pos, Vector3.new(-math.sin(a), 0, math.cos(a)))
	end
	return cfs, M.arcCurve(R, half)
end

function M.chevrons(len, gap)
	local out = {}
	gap = math.max(0.5, gap or 6)
	local d = gap / 2
	while d < len do
		table.insert(out, d)
		d += gap
	end
	return out
end

function M.pickTrim(list, need)
	local out, got = {}, 0
	for i, f in ipairs(list) do
		if got >= need then break end
		if (f.parts or 0) > 0 then
			table.insert(out, i)
			got += f.parts
		end
	end
	return out
end

return M
