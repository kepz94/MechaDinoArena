-- EggLoaderMap.spec v1.0 (Mecha Dino Arena) — EggLoader 1.3's map copy (POINTS) matches HardpointRules.LAYOUT_B (MDA-478).
-- Run in Studio Edit; returns "PASS n" or "FAIL ...".
local src = game:GetService("ServerStorage").DinoArcade:FindFirstChild("HardpointRules")
if not src then return "FAIL HardpointRules missing" end
local c = src:Clone() c.Parent = src.Parent
local ok, H = pcall(require, c)
c:Destroy()
if not ok then return "FAIL require: " .. tostring(H) end
local loader = game:GetService("ReplicatedFirst"):FindFirstChild("EggLoader")
if not loader then return "FAIL EggLoader missing" end
local line = string.match(loader.Source, "local POINTS = (%b{})")
if not line then return "FAIL POINTS not found in EggLoader" end
local pts = {}
for x, z in string.gmatch(line, "{(%-?%d+),%s*(%-?%d+)}") do table.insert(pts, {tonumber(x), tonumber(z)}) end
local fails, passes = {}, 0
local function eq(n, a, b) if a == b then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(n, tostring(a), tostring(b))) end end
eq("count", #pts, #H.LAYOUT_B)
for i, p in ipairs(H.LAYOUT_B) do
	eq("P" .. i .. " x", pts[i] and pts[i][1], p.x)
	eq("P" .. i .. " z", pts[i] and pts[i][2], p.z)
end
if #fails > 0 then return "FAIL " .. table.concat(fails, " | ") end
return "PASS " .. passes
