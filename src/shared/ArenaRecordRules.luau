-- ArenaRecordRules v1.1 (Mecha Dino Arena) — the Arena win-loss record, pure (no Instance writes, no services). MDA-481,
-- plan docs/plans/PREGAME_LINEUP_v1.0.md T1, ADR-012, mockup docs/mockups/pregame_v0.4.html.
-- Kepu 2026-11-12: W-L counts Arena matches only (D1); someone leaves -> their team gets no loss, the other team still gets the
--   win, the leaver gets a loss (D5); a match counts only when each team has a real player (D9); a draw changes nothing (D11);
--   leaving during the lineup is a loss like leaving mid-match (D12).
-- Lives in ServerStorage.DinoArcade.ArenaRecordRules; ArenaRecordServer 1.0 requires it. Spec tools/tests/ArenaRecordRules.spec.luau.
-- API:
--   outcome(eligible, winner, myTeam, left, teamHadLeaver) -> "w" | "l" | nil (first matching row wins):
--     eligible ~= true                          -> nil  (D9)
--     left == true                              -> "l"  (D5 / D12; written the moment the player leaves)
--     winner not "A" / "B" (draw, nil, other)   -> nil  (D11; no winner = match stopped)
--     myTeam not "A" / "B"                      -> nil
--     winner == myTeam                          -> "w"
--     teamHadLeaver == true                     -> nil  (D5: lost a player, no loss)
--     otherwise                                 -> "l"
--   eligible(nHumansA, nHumansB) -> bool: both >= MIN_HUMANS (1).
--   apply(record, out, matchId) -> record (a new table; the input is not changed). record = {w, l, lastMatch} (missing / bad
--     fields -> 0 / ""). out "w" -> w + 1, "l" -> l + 1, anything else -> unchanged copy. matchId == record.lastMatch (and not
--     "") -> unchanged copy (dedupe: one match counts once). A counted out sets lastMatch = matchId.
--   clean(record) -> {w, l, lastMatch} with whole numbers >= 0 and a string.
--   pct(w, l) -> whole-number win % (0 when no games).
-- v1.1 (MDA-493, plan docs/plans/ARENA_RECORD_v1.1.md T1, mockup docs/mockups/wl_record_v0.1.html; Kepu 2026-11-13 pick
--   "C · B + name tag", "Win streaks only"): the record also keeps
--   last  = the newest LAST_N (10) counted outcomes as a string of "w" / "l", oldest first, newest last;
--   s     = the streak: +n after n wins in a row, -n after n losses in a row (0 = none yet), clamped to ±S_MAX (9999).
--   clean keeps them (last: only the letters w / l, the last LAST_N; s: whole, clamped; bad -> "" / 0) next to w, l, lastMatch.
--   apply: a counted "w" -> last .. "w" (cut to LAST_N), s = s > 0 and s + 1 or 1; a counted "l" -> last .. "l",
--     s = s < 0 and s - 1 or -1. Not counted (other out, same matchId) -> unchanged copy, last and s too. A 1.0 record
--     (no last / s) starts from "" / 0.
--   streakText(s) -> "<s> WIN STREAK" when s >= 2, else "" (win streaks only).
local M = {}
M.VERSION = "1.0"
M.VERSION = "1.1" -- v1.1 last 10 + streak
M.MIN_HUMANS = 1
M.LAST_N = 10 -- v1.1
M.S_MAX = 9999 -- v1.1

local function num(v)
	v = tonumber(v)
	if not v or v ~= v or v < 0 then return 0 end
	return math.floor(v)
end

-- v1.1: last / s
local function cleanLast(v)
	if type(v) ~= "string" then return "" end
	local t = string.gsub(v, "[^wl]", "")
	if #t > M.LAST_N then t = string.sub(t, -M.LAST_N) end
	return t
end
local function cleanS(v)
	v = tonumber(v)
	if not v or v ~= v then return 0 end
	v = v < 0 and math.ceil(v) or math.floor(v)
	return math.clamp(v, -M.S_MAX, M.S_MAX)
end

function M.clean(record)
	record = type(record) == "table" and record or {}
	return {w = num(record.w), l = num(record.l), lastMatch = type(record.lastMatch) == "string" and record.lastMatch or "",
		last = cleanLast(record.last), s = cleanS(record.s)} -- v1.1: + last, s
end

function M.eligible(nA, nB)
	return num(nA) >= M.MIN_HUMANS and num(nB) >= M.MIN_HUMANS
end

function M.outcome(eligible, winner, myTeam, left, teamHadLeaver)
	if eligible ~= true then return nil end
	if left == true then return "l" end
	if winner ~= "A" and winner ~= "B" then return nil end
	if myTeam ~= "A" and myTeam ~= "B" then return nil end
	if winner == myTeam then return "w" end
	if teamHadLeaver == true then return nil end
	return "l"
end

function M.apply(record, out, matchId)
	local r = M.clean(record)
	if out ~= "w" and out ~= "l" then return r end
	matchId = type(matchId) == "string" and matchId or ""
	if matchId ~= "" and r.lastMatch == matchId then return r end
	if out == "w" then r.w += 1 else r.l += 1 end
	r.lastMatch = matchId
	r.last = cleanLast(r.last .. out) -- v1.1
	if out == "w" then r.s = r.s > 0 and math.min(r.s + 1, M.S_MAX) or 1 else r.s = r.s < 0 and math.max(r.s - 1, -M.S_MAX) or -1 end
	return r
end

-- v1.1: win streaks only (Kepu 2026-11-13)
function M.streakText(s)
	s = tonumber(s)
	if not s or s < 2 then return "" end
	return ("%d WIN STREAK"):format(math.floor(s))
end

function M.pct(w, l)
	w, l = num(w), num(l)
	if w + l == 0 then return 0 end
	return math.floor(100 * w / (w + l) + 0.5)
end

return M
