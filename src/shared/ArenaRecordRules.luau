-- ArenaRecordRules v1.0 (Mecha Dino Arena) — the Arena win-loss record, pure (no Instance writes, no services). MDA-481,
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
local M = {}
M.VERSION = "1.0"
M.MIN_HUMANS = 1

local function num(v)
	v = tonumber(v)
	if not v or v ~= v or v < 0 then return 0 end
	return math.floor(v)
end

function M.clean(record)
	record = type(record) == "table" and record or {}
	return {w = num(record.w), l = num(record.l), lastMatch = type(record.lastMatch) == "string" and record.lastMatch or ""}
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
	return r
end

function M.pct(w, l)
	w, l = num(w), num(l)
	if w + l == 0 then return 0 end
	return math.floor(100 * w / (w + l) + 0.5)
end

return M
