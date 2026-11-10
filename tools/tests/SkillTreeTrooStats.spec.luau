-- SkillTreeTrooStats.spec v1.0 (Mecha Dino Arena) — the troodon's own stat rows in ServerStorage.DinoArcade.SkillTree 1.88
-- (plan docs/plans/TROODON_STATS_v1.0.md T1, MDA-387). Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.
-- SkillTreeTrooStats_spec, clone + require); returns "PASS n" or "FAIL ...".
local ok, ST = pcall(function()
	local src = game.ServerStorage.DinoArcade.SkillTree
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(ST) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-9) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local P = ST.PATHS
eq("TROO_STATS", ST.TROO_STATS, true)
local ROWS = {tfeeder = {"Glow Feeder", "health"}, tleech = {"Spore Leech", "health"}, teyes = {"Hunter's Eyes", "attack"},
	tward = {"Zone Ward", "defense"}, tfeet = {"Quick Feet", "speed"}, twatch = {"Night Watcher", "sig"}}
for id, w in pairs(ROWS) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, w[1])
		eq(id .. " area", P[id].area, w[2])
		eq(id .. " not mech", P[id].mech == true, false)
		eq(id .. " not soon", P[id].soon == true, false)
		eq(id .. " dino", P[id].dino, "Troodon")
		eq(id .. " owner", ST.OWNER[id], "Troodon")
		eq(id .. " steps", #P[id].steps, 4)
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		eq(id .. " troodon sees", ST.seesPath(P[id], "Troodon"), true)
		eq(id .. " raptor doesn't", ST.seesPath(P[id], "Raptor"), false)
	end
end
-- the troodon's stat screen: exactly the 6 rows
local rows = {}
for _, a in ipairs(ST.AREAS) do
	for _, p in ipairs(ST.pathsFor(a.id, "Troodon")) do if not p.mech then table.insert(rows, p.id) end end
end
table.sort(rows)
eq("troodon stat rows", table.concat(rows, ","), "teyes,tfeeder,tfeet,tleech,tward,twatch")
for _, id in ipairs({"regen", "lifesteal", "jaws", "hide", "legs"}) do
	eq(id .. " hidden for troodon", ST.seesPath(P[id], "Troodon"), false)
	eq(id .. " sanitized for troodon", ST.sanitize({[id] = 3}, "Troodon")[id] or 0, 0)
end
eq("raptor keeps regen", ST.seesPath(P.regen, "Raptor"), true); eq("trex keeps jaws", ST.seesPath(P.jaws, "TRex"), true)
eq("trex keeps hide", ST.seesPath(P.hide, "TRex"), true)
-- numbers per rank
local function E(s) return ST.effects(s, "Troodon") end
local function chk(id, field, want)
	for r = 1, 4 do eq(("%s %d %s"):format(id, r, field), E({[id] = r})[field], want[r]) end
end
chk("tfeeder", "feederSelf", {2, 2.7, 2.7, 2.7}); chk("tfeeder", "feederSquadMul", {1, 1, 1.35, 1.35}); chk("tfeeder", "feederLinger", {0, 0, 0, 1})
chk("tleech", "leechHeal", {1, 1.35, 1.35, 1.35}); chk("tleech", "leechSquad", {false, false, true, true}); chk("tleech", "leechKill", {0, 0, 0, 10})
chk("teyes", "eyesReach", {1.35, 1.35, 1.35, 1.35}); chk("teyes", "eyesMark", {0, 3, 3, 3}); chk("teyes", "eyesMarkMul", {1, 1, 1.1, 1.1}); chk("teyes", "eyesSee", {false, false, false, true})
chk("tward", "wardMul", {0.9, 0.865, 0.865, 0.865}); chk("tward", "wardSquad", {false, false, true, true}); chk("tward", "wardLinger", {0, 0, 0, 1})
chk("tfeet", "feetRun", {1.05, 1.05, 1.05, 1.05}); chk("tfeet", "feetForward", {0, 30, 30, 30}); chk("tfeet", "feetAirJumps", {0, 0, 1, 1}); chk("tfeet", "feetTrail", {false, false, false, true})
chk("twatch", "watchRadius", {40, 54, 54, 54}); chk("twatch", "watchSquad", {false, false, true, true}); chk("twatch", "watchDouble", {false, false, false, true})
-- the 35% rule on the changed numbers
eq("feeder 2.7/2", 2.7 / 2 >= 1.35, true); eq("leech 1.35/1", 1.35 / 1 >= 1.35, true); eq("ward 13.5/10", 13.5 / 10 >= 1.35, true)
eq("watch 54/40", 54 / 40 >= 1.35, true); eq("eyes 108/80", 108 / 80 >= 1.35, true)
-- off for other dinos / unbought
local r = ST.effects({tfeeder = 4, tleech = 4, teyes = 4, tward = 4, tfeet = 4, twatch = 4}, "Raptor")
eq("raptor feeder", r.feederSelf, 0); eq("raptor eyes", r.eyesReach, 1); eq("raptor ward", r.wardMul, 1); eq("raptor watch", r.watchRadius, 0)
local z = E({})
eq("unbought feeder", z.feederSelf, 0); eq("unbought feet", z.feetRun, 1); eq("unbought watch double", z.watchDouble, false)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
