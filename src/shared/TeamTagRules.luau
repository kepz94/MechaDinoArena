-- TeamTagRules v1.0 (Mecha Dino Arena) — who gets which friend / foe marker. MDA-416, plan docs/plans/TEAM_TAGS_v1.0.md
-- Task 1, mockup docs/mockups/team_readability_v0.1.html (Kepu 2026-11-10: "B · Friends marked", "Hurt nearby counts",
-- "Both, Arena too", "Teammate names on phone").
-- Lives in ServerStorage.DinoArcade.TeamTagRules; TeamTagShare 1.0 clones it to ReplicatedStorage.TeamTagShared for clients.
-- Pure: no services, no instances.
-- relation(myTeam, theirTeam) -> "friend" (same team), "enemy" (the other team), "none" (either side not "A" / "B").
-- markFor(rel, info, cfg) -> "none" | "friend" | "target" | "bar" | "chevron":
--   info = {alive, dist (studs), inSight (camera ray not blocked), cloaked, isTarget (TargetHUD's shown target), hurtAgo
--   (seconds since its health last dropped, nil = not seen)}; cfg overrides the numbers (friendMax, chevronMax, engageNear,
--   hurtWindow, hurtMax), nil = the constants.
--   none     rel "none", or not alive
--   friend   a teammate within FRIEND_MAX (through walls; sight and cloak are not checked: it is your own team)
--   target   an enemy that is TargetHUD's shown target (TargetHUD draws its bar; TeamTags only makes it red)
--   none     an enemy cloaked or out of sight
--   bar      an enemy within ENGAGE_NEAR, or hurt within HURT_WINDOW s while within HURT_MAX
--   chevron  any other enemy within CHEVRON_MAX
--   none     further
local M = {}
M.Version = "1.0"
M.FRIEND_MAX = 400
M.CHEVRON_MAX = 130
M.ENGAGE_NEAR = 25
M.HURT_WINDOW = 4
M.HURT_MAX = 60

local function isTeam(t) return t == "A" or t == "B" end

function M.relation(myTeam, theirTeam)
	if not (isTeam(myTeam) and isTeam(theirTeam)) then return "none" end
	return myTeam == theirTeam and "friend" or "enemy"
end

function M.markFor(rel, info, cfg)
	cfg = cfg or {}
	info = info or {}
	if rel ~= "friend" and rel ~= "enemy" then return "none" end
	if info.alive ~= true then return "none" end
	local d = tonumber(info.dist) or math.huge
	if rel == "friend" then
		return d <= (cfg.friendMax or M.FRIEND_MAX) and "friend" or "none"
	end
	if info.isTarget == true then return "target" end
	if info.cloaked == true or info.inSight ~= true then return "none" end
	local hurt = tonumber(info.hurtAgo)
	if d <= (cfg.engageNear or M.ENGAGE_NEAR)
		or (hurt ~= nil and hurt >= 0 and hurt <= (cfg.hurtWindow or M.HURT_WINDOW) and d <= (cfg.hurtMax or M.HURT_MAX)) then
		return "bar"
	end
	if d <= (cfg.chevronMax or M.CHEVRON_MAX) then return "chevron" end
	return "none"
end

return M
