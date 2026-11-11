-- TeamTagRules.spec v1.0 (Mecha Dino Arena) — TeamTagRules 1.0 (plan docs/plans/TEAM_TAGS_v1.0.md Task 1, MDA-416).
-- Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.TeamTagRules_spec): clone + require
-- ServerStorage.DinoArcade.TeamTagRules; returns "PASS n" or "FAIL ...".
local DA = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
local src = DA and DA:FindFirstChild("TeamTagRules")
if not src then return "FAIL missing TeamTagRules" end
local ok, R = pcall(function() local c = src:Clone() c.Parent = src.Parent local r = require(c) c:Destroy() return r end)
if not ok then return "FAIL require: " .. tostring(R) end

local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end

-- numbers
eq("friend max", R.FRIEND_MAX, 400); eq("chevron max", R.CHEVRON_MAX, 130); eq("engage near", R.ENGAGE_NEAR, 25)
eq("hurt window", R.HURT_WINDOW, 4); eq("hurt max", R.HURT_MAX, 60)

-- relation
eq("A A", R.relation("A", "A"), "friend"); eq("B B", R.relation("B", "B"), "friend")
eq("A B", R.relation("A", "B"), "enemy"); eq("B A", R.relation("B", "A"), "enemy")
eq("nil A", R.relation(nil, "A"), "none"); eq("A nil", R.relation("A", nil), "none"); eq("A empty", R.relation("A", ""), "none")
eq("C A", R.relation("C", "A"), "none")

local function m(rel, t, cfg) return R.markFor(rel, t, cfg) end
-- none / dead
eq("rel none", m("none", {alive = true, dist = 5, inSight = true}), "none")
eq("friend dead", m("friend", {alive = false, dist = 5}), "none")
eq("enemy dead", m("enemy", {alive = false, dist = 5, inSight = true}), "none")
eq("alive missing", m("enemy", {dist = 5, inSight = true}), "none")
eq("info nil", m("enemy", nil), "none")
-- friend
eq("friend near", m("friend", {alive = true, dist = 10}), "friend")
eq("friend behind wall", m("friend", {alive = true, dist = 100, inSight = false}), "friend")
eq("friend cloaked", m("friend", {alive = true, dist = 100, cloaked = true}), "friend")
eq("friend at 400", m("friend", {alive = true, dist = 400}), "friend")
eq("friend at 401", m("friend", {alive = true, dist = 401}), "none")
eq("friend cfg", m("friend", {alive = true, dist = 300}, {friendMax = 250}), "none")
-- enemy target
eq("target", m("enemy", {alive = true, dist = 50, inSight = true, isTarget = true}), "target")
eq("target out of sight", m("enemy", {alive = true, dist = 50, inSight = false, isTarget = true}), "target")
eq("target dead", m("enemy", {alive = false, dist = 50, isTarget = true}), "none")
-- hidden
eq("cloaked near", m("enemy", {alive = true, dist = 5, inSight = true, cloaked = true}), "none")
eq("out of sight near", m("enemy", {alive = true, dist = 5, inSight = false}), "none")
eq("out of sight hurt", m("enemy", {alive = true, dist = 30, inSight = false, hurtAgo = 1}), "none")
-- bar: near
eq("near 25", m("enemy", {alive = true, dist = 25, inSight = true}), "bar")
eq("near 25.1", m("enemy", {alive = true, dist = 25.1, inSight = true}), "chevron")
-- bar: hurt nearby
eq("hurt 1 s at 50", m("enemy", {alive = true, dist = 50, inSight = true, hurtAgo = 1}), "bar")
eq("hurt 4 s at 60", m("enemy", {alive = true, dist = 60, inSight = true, hurtAgo = 4}), "bar")
eq("hurt 4.1 s", m("enemy", {alive = true, dist = 50, inSight = true, hurtAgo = 4.1}), "chevron")
eq("hurt at 61", m("enemy", {alive = true, dist = 61, inSight = true, hurtAgo = 1}), "chevron")
eq("hurt negative", m("enemy", {alive = true, dist = 50, inSight = true, hurtAgo = -1}), "chevron")
eq("hurt nil", m("enemy", {alive = true, dist = 50, inSight = true}), "chevron")
-- chevron / far
eq("chevron 130", m("enemy", {alive = true, dist = 130, inSight = true}), "chevron")
eq("far 131", m("enemy", {alive = true, dist = 131, inSight = true}), "none")
eq("far hurt", m("enemy", {alive = true, dist = 131, inSight = true, hurtAgo = 1}), "none")
eq("dist missing", m("enemy", {alive = true, inSight = true}), "none")
-- cfg overrides
eq("cfg chevron", m("enemy", {alive = true, dist = 100, inSight = true}, {chevronMax = 90}), "none")
eq("cfg near", m("enemy", {alive = true, dist = 30, inSight = true}, {engageNear = 35}), "bar")
eq("cfg hurt window", m("enemy", {alive = true, dist = 50, inSight = true, hurtAgo = 5}, {hurtWindow = 6}), "bar")
eq("cfg hurt max", m("enemy", {alive = true, dist = 80, inSight = true, hurtAgo = 1}, {hurtMax = 90}), "bar")

if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
