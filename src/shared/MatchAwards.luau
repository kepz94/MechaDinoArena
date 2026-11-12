-- MatchAwards v1.0 (Mecha Dino Arena) — end of a Hardpoint match: who is MVP / SVP and each player's XP lines. MDA-461, plan
-- docs/plans/MATCH_END_v1.0.md Task 1, mockup docs/mockups/match_end_v0.1.html (Kepu 2026-11-11 19:43 "Build with all the
-- recs": MVP one per team; XP kill 50, 1 / s on the point, win 100 (draw 50), MVP 50, SVP 25, bots match 10%).
-- Pure: no instances, no services. Lives in ServerStorage.DinoArcade.MatchAwards; HardpointServer 1.5 requires it.
-- Rows (HardpointServer's scoreboard): {id, team "A" / "B", bot, k (all kills), d, pt (seconds on the point), pk (player kills)}.
-- API:
--   CFG: mvpKill 100, mvpSec 10 (MVP score points), kill 50, sec 1, win 100, draw 50, mvp 50, svp 25, practiceMul 0.1 (XP).
--   score(row, cfg) -> k × mvpKill + floor(pt + 0.5) × mvpSec (deaths don't count).
--   better(x, y, cfg) -> x ranks above y: higher score, then more seconds on the point, then fewer deaths, then the smaller id.
--   pick(rows, winner, cfg) -> mvpId | nil, svpId | nil. Bots never count. winner "A" / "B": MVP = best on the winner, SVP = best
--     on the other team. "draw": MVP = best overall, SVP = best on the team that is not the MVP's. Anything else -> nil, nil.
--   lines(row, ctx, cfg) -> {kill, point, win, mvp, svp, total}; ctx = {winner, practice, mvpId, svpId}.
--     kill = pk × kill (0 in practice: bot kills are paid live by SkillServer); point = round(floor(pt + 0.5) × sec × m);
--     win = round(win × m) on the winning team, round(draw × m) for everyone in a draw; mvp / svp = round(bonus × m) for that id;
--     m = practiceMul in practice, else 1. round = floor(x + 0.5).
--   compute(rows, winner, practice, cfg) -> {mvp = id | "", svp = id | "", rows = {[id] = lines}} (humans only).
--   cfg: any field missing / not a number -> CFG's.
local M = {}
M.VERSION = "1.0"
M.CFG = {mvpKill = 100, mvpSec = 10, kill = 50, sec = 1, win = 100, draw = 50, mvp = 50, svp = 25, practiceMul = 0.1}

local function num(v) return type(v) == "number" and v == v and v or 0 end
local function round(x) return math.floor(x + 0.5) end
local function conf(cfg)
	local c = {}
	for k, v in pairs(M.CFG) do
		local o = type(cfg) == "table" and cfg[k] or nil
		c[k] = (type(o) == "number" and o == o) and o or v
	end
	return c
end
local function secs(row) return math.floor(num(row.pt) + 0.5) end

function M.score(row, cfg)
	local c = conf(cfg)
	if type(row) ~= "table" then return 0 end
	return num(row.k) * c.mvpKill + secs(row) * c.mvpSec
end

function M.better(x, y, cfg)
	local sx, sy = M.score(x, cfg), M.score(y, cfg)
	if sx ~= sy then return sx > sy end
	if secs(x) ~= secs(y) then return secs(x) > secs(y) end
	if num(x.d) ~= num(y.d) then return num(x.d) < num(y.d) end
	return tostring(x.id) < tostring(y.id)
end

local function bestOf(rows, keep, cfg)
	local best
	for _, r in ipairs(rows) do
		if type(r) == "table" and r.bot ~= true and r.id ~= nil and (r.team == "A" or r.team == "B") and keep(r) then
			if not best or M.better(r, best, cfg) then best = r end
		end
	end
	return best
end

function M.pick(rows, winner, cfg)
	if type(rows) ~= "table" then return nil, nil end
	if winner == "A" or winner == "B" then
		local m = bestOf(rows, function(r) return r.team == winner end, cfg)
		local s = bestOf(rows, function(r) return r.team ~= winner end, cfg)
		return m and m.id or nil, s and s.id or nil
	elseif winner == "draw" then
		local m = bestOf(rows, function() return true end, cfg)
		if not m then return nil, nil end
		local s = bestOf(rows, function(r) return r.team ~= m.team end, cfg)
		return m.id, s and s.id or nil
	end
	return nil, nil
end

function M.lines(row, ctx, cfg)
	local c = conf(cfg)
	ctx = type(ctx) == "table" and ctx or {}
	local out = {kill = 0, point = 0, win = 0, mvp = 0, svp = 0, total = 0}
	if type(row) ~= "table" or row.bot == true then return out end
	local m = ctx.practice == true and c.practiceMul or 1
	if ctx.practice ~= true then out.kill = round(num(row.pk) * c.kill) end
	out.point = round(secs(row) * c.sec * m)
	if ctx.winner == "draw" then
		out.win = round(c.draw * m)
	elseif (ctx.winner == "A" or ctx.winner == "B") and row.team == ctx.winner then
		out.win = round(c.win * m)
	end
	if row.id ~= nil and row.id == ctx.mvpId then out.mvp = round(c.mvp * m) end
	if row.id ~= nil and row.id == ctx.svpId then out.svp = round(c.svp * m) end
	out.total = out.kill + out.point + out.win + out.mvp + out.svp
	return out
end

function M.compute(rows, winner, practice, cfg)
	local res = {mvp = "", svp = "", rows = {}}
	if type(rows) ~= "table" then return res end
	local mvp, svp = M.pick(rows, winner, cfg)
	res.mvp, res.svp = mvp or "", svp or ""
	local ctx = {winner = winner, practice = practice == true, mvpId = mvp, svpId = svp}
	for _, r in ipairs(rows) do
		if type(r) == "table" and r.bot ~= true and r.id ~= nil then res.rows[tostring(r.id)] = M.lines(r, ctx, cfg) end
	end
	return res
end

return M
