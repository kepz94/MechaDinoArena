-- DiloPartsVFX.spec v1.0 (Mecha Dino Arena) — DiloPartsVFXLib 1.0 maths + the DiloMovesFX 1.6 / DiloFX 1.3 hand-off wiring (plan
-- docs/plans/DILO_VFX_v1.0.md Task 2, MDA-391). Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.DiloPartsVFX_spec, clone +
-- require); returns "PASS n" or "FAIL ...".
local SPS = game.StarterPlayer.StarterPlayerScripts
local ok, L = pcall(function() local c = SPS.DiloPartsVFXLib:Clone() c.Parent = SPS local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(L) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-6) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
-- parsing
local v = L.parseV("1.5,-2,3e1")
eq("parseV", v and v.X == 1.5 and v.Y == -2 and v.Z == 30, true)
eq("parseV bad", L.parseV("a,b,c"), nil)
local sh = L.parseShot("3;1,2,3;4,5,6;0.25;Bot_Raptor_1")
eq("shot i", sh and sh.i, 3); eq("shot to", sh and sh.to.Z, 6); eq("shot flight", sh and sh.flight, 0.25); eq("shot target", sh and sh.target, "Bot_Raptor_1")
local sh2 = L.parseShot("1;0,0,0;0,0,-10;0.3;")
eq("shot empty target", sh2 and sh2.target, "")
eq("shot bad", L.parseShot("x;1,2,3"), nil)
local hits = L.parseSpineHits("Bot_A=2|Bot_B=1|Bad=0")
eq("spine hits n", #hits, 2); eq("spine hit 1", hits[1] and hits[1].name, "Bot_A"); eq("spine hit 1 n", hits[1] and hits[1].n, 2)
eq("names", #L.names("a|b|c"), 3); eq("names nil", #L.names(nil), 0)
-- hazard ring: 28 wedges on the circle, alternating, tangent-facing
local w = L.wedges(18, 28)
eq("wedges", #w, 28)
local darks = 0
for _, x in ipairs(w) do if x.dark then darks += 1 end end
eq("wedges alternate", darks, 14)
eq("wedge on circle", w[1].cf.Position.Magnitude, 18, 1e-4)
eq("wedge length", w[1].size.Z, 2 * math.pi * 18 / 28 * 1.02, 1e-4)
eq("wedge tangent", math.abs(w[1].cf.LookVector:Dot(w[1].cf.Position.Unit)) < 1e-4, true)
-- beam ring: 4 points on the circle, X axis = tangent, curve 0.5523 R
local cfs, c = L.ringPoints(10)
eq("ring points", #cfs, 4); eq("ring curve", c, 5.523, 1e-6)
eq("ring point radius", cfs[2].Position.Magnitude, 10, 1e-4)
eq("ring tangent", math.abs(cfs[3].RightVector:Dot(cfs[3].Position.Unit)) < 1e-4, true)
-- the Bezier through a quarter: midpoint close to the circle (within 0.1%)
local p0, p3 = cfs[1].Position, cfs[2].Position
local p1, p2 = p0 + cfs[1].RightVector * c, p3 - cfs[2].RightVector * c
local mid = (p0 + p1 * 3 + p2 * 3 + p3) / 8
eq("ring quarter mid on circle", mid.Magnitude, 10, 0.01)
-- arcs
local acfs, ac = L.arcPoints(30, 35, 0)
eq("arc points", #acfs, 3); eq("arc mid", acfs[2].Position.X, 30, 1e-4); eq("arc curve", ac, 4 / 3 * math.tan(math.rad(35) / 4) * 30, 1e-6)
-- chevrons + trim
local ch = L.chevrons(65, 6)
eq("chevrons", #ch, 11); eq("chevron first", ch[1], 3)
local t = L.pickTrim({{parts = 0}, {parts = 5}, {parts = 3}, {parts = 9}}, 6)
eq("trim picks", #t, 2); eq("trim oldest first", t[1], 2); eq("trim second", t[2], 3)
-- wiring: DiloPartsVFX switches, DiloMovesFX 1.6 gates, DiloFX 1.3 hand-off
local vfx = SPS:FindFirstChild("DiloPartsVFX")
eq("DiloPartsVFX present", vfx ~= nil, true)
if vfx then
	for _, id in ipairs({"dgatling", "dmortar", "dhiss", "dspine", "dpump", "djets", "dover"}) do
		eq("switch " .. id, vfx.Source:find('"' .. id .. '"', 1, true) ~= nil, true)
	end
	eq("budget default", vfx.Source:find("maxParts = 350", 1, true) ~= nil, true)
end
local mfx = SPS:FindFirstChild("DiloMovesFX")
local _, nOwned = mfx.Source:gsub('owned%("d%a+"%)', "")
eq("DiloMovesFX 1.6 gates", nOwned, 13)
for _, id in ipairs({"dgatling", "dmortar", "dspine", "dover", "dhiss", "dpump", "djets"}) do
	eq("gate " .. id, mfx.Source:find('owned("' .. id .. '")', 1, true) ~= nil, true)
end
eq("barbs still reload", mfx.Source:find('if owned("dspine") then st.barbsHiddenUntil', 1, true) ~= nil, true)
eq("DiloFX 1.3 hand-off", SPS.DiloFX.Source:find("overHandoff(char) and now() - at < flight", 1, true) ~= nil, true)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
