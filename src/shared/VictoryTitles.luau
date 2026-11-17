-- VictoryTitles v1.0 (Mecha Dino Arena) — who on the winning team gets which end-of-match title. MDA-553, plan
-- docs/plans/VICTORY_TITLES_v1.0.md Task 1, mockup docs/mockups/victory_titles_v0.1.html (Kepu 2026-11-16 19:00 "Let's
-- implement them"). Pure: no instances, no services. Lives in ServerStorage.DinoArcade.VictoryTitles; HardpointServer 1.9
-- requires it.
-- Rows (HardpointServer's scoreboard): {id, team "A" / "B", bot, k, d, pt (seconds on the point), heal (HP healed on
--   teammates), ab (abilities used)}.
-- API:
--   ORDER: the 8 titles in hand-out order: apex, king, unkill, medic, masher, extinct, carried, pacifist.
--   LEN: each title's animation length in seconds (VictoryTitlesAnim 1.0).
--   CFG: max 4 (players shown), apexK 3, kingPt 30, unkillPt 30, medicHeal 100, masherAb 20, extinctD 4, carriedFrac 0.5,
--     scoreKill 100, scoreSec 10 (the team order score, as MatchAwards: k × 100 + seconds × 10).
--   score(row, cfg) -> k × scoreKill + floor(pt + 0.5) × scoreSec.
--   earns(title, row, team, cfg) -> true / false (team = the shown members, for "best on the team" rules).
--   assign(rows, winner, cfg) -> list {{id, title, stat}} in show order (best score first; ties: more seconds on the point,
--     fewer deaths, smaller id). winner not "A" / "B" (draw) or nobody on it -> {}. Bots count (they are on the team).
--     Titles go down ORDER: each to the best member who earns it and has no title yet (best = the title's metric: apex most
--     kills, king most seconds, unkill best score, medic most heal, masher most abilities, extinct most deaths, carried
--     lowest score, pacifist lowest score). Members left over get the title they came closest to (closeness below; titles
--     nobody has first, then any).
--   closeness(title, row, team, cfg) -> 0.. (1 = just earned it).
--   statText(title, row) -> the lower-third stat line ("11 KILLS", "2:05 ON POINT", ...).
local M = {}
M.VERSION = "1.0"
M.ORDER = {"apex", "king", "unkill", "medic", "masher", "extinct", "carried", "pacifist"}
M.LEN = {apex = 5.4, king = 5.4, unkill = 5.4, medic = 5.4, masher = 5.4, carried = 6.4, pacifist = 5.6, extinct = 5.8}
M.CFG = {max = 4, apexK = 3, kingPt = 30, unkillPt = 30, medicHeal = 100, masherAb = 20, extinctD = 4, carriedFrac = 0.5,
	scoreKill = 100, scoreSec = 10}

local function num(v) return type(v) == "number" and v == v and v or 0 end
local function conf(cfg)
	local c = {}
	for k, v in pairs(M.CFG) do
		local o = type(cfg) == "table" and cfg[k] or nil
		c[k] = (type(o) == "number" and o == o) and o or v
	end
	return c
end
local function secs(row) return math.floor(num(row.pt) + 0.5) end
local function mmss(s) return ("%d:%02d"):format(s // 60, s % 60) end

function M.score(row, cfg)
	local c = conf(cfg)
	if type(row) ~= "table" then return 0 end
	return num(row.k) * c.scoreKill + secs(row) * c.scoreSec
end

local function better(x, y, c) -- x ranks above y on the team
	local sx, sy = M.score(x, c), M.score(y, c)
	if sx ~= sy then return sx > sy end
	if secs(x) ~= secs(y) then return secs(x) > secs(y) end
	if num(x.d) ~= num(y.d) then return num(x.d) < num(y.d) end
	return tostring(x.id) < tostring(y.id)
end

local function bestScore(team, c)
	local b = 0
	for _, r in ipairs(team) do b = math.max(b, M.score(r, c)) end
	return b
end

function M.earns(title, row, team, cfg)
	local c = conf(cfg)
	local k, d, s = num(row.k), num(row.d), secs(row)
	if title == "apex" then return k >= c.apexK
	elseif title == "king" then return s >= c.kingPt
	elseif title == "unkill" then return d == 0 and (k >= 1 or s >= c.unkillPt)
	elseif title == "medic" then return num(row.heal) >= c.medicHeal
	elseif title == "masher" then return num(row.ab) >= c.masherAb
	elseif title == "extinct" then return d >= c.extinctD
	elseif title == "carried" then return #team > 1 and M.score(row, c) < c.carriedFrac * bestScore(team, c)
	elseif title == "pacifist" then return k == 0
	end
	return false
end

-- the metric that ranks candidates for a title (higher wins)
local function metric(title, row, c)
	if title == "apex" then return num(row.k)
	elseif title == "king" then return secs(row)
	elseif title == "unkill" then return M.score(row, c)
	elseif title == "medic" then return num(row.heal)
	elseif title == "masher" then return num(row.ab)
	elseif title == "extinct" then return num(row.d)
	end
	return -M.score(row, c) -- carried, pacifist: the lowest score
end

function M.closeness(title, row, team, cfg)
	local c = conf(cfg)
	local k, d, s = num(row.k), num(row.d), secs(row)
	if title == "apex" then return k / math.max(1, c.apexK)
	elseif title == "king" then return s / math.max(1, c.kingPt)
	elseif title == "unkill" then return 1 / (1 + d)
	elseif title == "medic" then return num(row.heal) / math.max(1, c.medicHeal)
	elseif title == "masher" then return num(row.ab) / math.max(1, c.masherAb)
	elseif title == "extinct" then return d / math.max(1, c.extinctD)
	elseif title == "carried" then return (c.carriedFrac * bestScore(team, c)) / math.max(1, M.score(row, c))
	elseif title == "pacifist" then return 1 / (1 + k)
	end
	return 0
end

function M.statText(title, row)
	local k, d, s = num(row.k), num(row.d), secs(row)
	if title == "apex" then return ("%d KILLS"):format(k)
	elseif title == "king" then return mmss(s) .. " ON POINT"
	elseif title == "unkill" then return k > 0 and ("0 DEATHS · %d KILLS"):format(k) or ("0 DEATHS · %s ON POINT"):format(mmss(s))
	elseif title == "medic" then return ("%d HP HEALED"):format(math.floor(num(row.heal) + 0.5))
	elseif title == "masher" then return ("%d ABILITIES"):format(num(row.ab))
	elseif title == "extinct" then return ("%d DEATHS"):format(d)
	elseif title == "carried" then return ("%d K · %s ON POINT"):format(k, mmss(s))
	elseif title == "pacifist" then return "0 KILLS"
	end
	return ""
end

function M.assign(rows, winner, cfg)
	local c = conf(cfg)
	if winner ~= "A" and winner ~= "B" or type(rows) ~= "table" then return {} end
	local team = {}
	for _, r in ipairs(rows) do if type(r) == "table" and r.team == winner and r.id ~= nil then table.insert(team, r) end end
	table.sort(team, function(x, y) return better(x, y, c) end)
	while #team > c.max do table.remove(team) end
	if #team == 0 then return {} end
	local got, used = {}, {}
	for _, title in ipairs(M.ORDER) do
		local pick
		for _, r in ipairs(team) do
			if not got[r.id] and M.earns(title, r, team, c) then
				if not pick then pick = r
				else
					local a, b = metric(title, r, c), metric(title, pick, c)
					if a > b or (a == b and better(r, pick, c)) then pick = r end
				end
			end
		end
		if pick then got[pick.id] = title; used[title] = true end
	end
	for _, r in ipairs(team) do
		if not got[r.id] then
			local bestT, bestV
			for pass = 1, 2 do -- titles nobody has first, then any
				for _, title in ipairs(M.ORDER) do
					if pass == 2 or not used[title] then
						local v = M.closeness(title, r, team, c)
						if bestV == nil or v > bestV then bestT, bestV = title, v end
					end
				end
				if bestT then break end
			end
			got[r.id] = bestT
			used[bestT] = true
		end
	end
	local out = {}
	for _, r in ipairs(team) do table.insert(out, {id = r.id, title = got[r.id], stat = M.statText(got[r.id], r)}) end
	return out
end

return M
