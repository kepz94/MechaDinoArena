"""Arena modes step 3: Free for All (Kepu 2026-11-26 19:59 lineup pick "B"; rules + intro / HUD / results from mockup
docs/mockups/arena_modes_v0.3.html, approved 19:21 "Build"). Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_ffa.py
Design: the 8 seats stay the two groups of 4 (roster, lineup data, Arena queue sides, spawns' counted() unchanged); while a FFA match
runs, ReplicatedStorage HardpointFFA = true and every "same team" answer (SquadRules) is false, bots see everyone as an enemy, the
spawn pick treats everyone as an enemy, and the score is per dino (places by kills, then fewer deaths)."""
Q = ('Kepu 2026-11-26 "Let\'s do 1. 2 3 like you suggested" (3 = Free for All); 19:21 "Build" on mockup docs/mockups/arena_modes_v0.3.html '
     '(FFA: 8 dinos, first to 20 kills or most at 10:00, tie = fewer deaths, top 3 count as a win, bots hunt anyone); 19:59 lineup pick "B" '
     '(docs/mockups/ffa_lineup_v0.1/B_two_rows.jpg)')
SSS = 'game:GetService("ServerScriptService").'
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}

# ---------------- HardpointServer 1.13 ----------------
S = []
a = '--   Diagnostics: script attributes HpModeLast (the last match\'s mode), HpTdmLast ("<winner> <a>-<b> clock <s>").\n'
S.append((a, a + '''VERSION = "1.13" -- v1.13 Free for All
-- v1.13 (Free for All, ''' + Q + '''):
--   * HardpointPractice("start", lead, "ffa") (script attribute HpFfaEnabled ~= false, read per start) makes the new match Free
--     for All: match.mode / HpMode "ffa", clock HpFfaClock (600), HpFfaLimit (20) published at every new match, HpFfaPlaces ""
--     until live. The two seat groups ("A" / "B") stay as they are (roster, spawn rows); ReplicatedStorage attribute HardpointFFA
--     is true while a FFA match exists (set at newMatch and every publish), which SquadRules 1.4 reads: nobody is anyone's
--     teammate. No team opening spawns (match.opening false); the spawn pick counts every other dino as an enemy.
--   * FFA live tick: no point scoring (HpOcc "N", clock always runs). Every counted dino gets a board row (0 / 0) so all 8 are
--     placed. Places: kills (more first), then deaths (fewer first), then name, then id; ReplicatedStorage.Hardpoint HpFfaPlaces =
--     JSON list of ids in place order (every tick, set on change); HpScoreA / HpScoreB = the 1st / 2nd place kills. A kill past
--     HpFfaLimit is not counted. End: the leader at HpFfaLimit kills, or the clock at 0. Results as Hardpoint, with HpWinner
--     "ffa"; inside, match.winner = "W" and the top HpFfaTopWin (3) are team "W" for the titles (VictoryTitles.assign) and the
--     awards (MatchAwards.compute: win XP), the rest "L" (HpFfaTitlesEnabled ~= false, read per results).
--   Diagnostic: script attribute HpFfaLast ("<1st id> <kills> clock <s> n <dinos>").
'''))
a = 'for k, v in pairs({HpTdmEnabled = true, HpTdmLimit = 30, HpTdmClock = 600}) do -- v1.12\n'
S.append((a, '''for k, v in pairs({HpFfaEnabled = true, HpFfaLimit = 20, HpFfaClock = 600, HpFfaTopWin = 3}) do -- v1.13
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
''' + a))
a = '\t\t\tif d.team == team then table.insert(mates, d.pos) else table.insert(enemies, d.pos) end\n\t\tend\n\tend\n'
S.append((a, a + '''	if match and match.mode == "ffa" then -- v1.13: everyone is an enemy
		for _, p in ipairs(mates) do table.insert(enemies, p) end
		mates = {}
	end
'''))
a = '\tif m.winner ~= "A" and m.winner ~= "B" then script:SetAttribute("HpTitlesLast", "draw") return 0 end\n'
S.append((a, '''	local ffaW = m.mode == "ffa" and m.winner == "W" and script:GetAttribute("HpFfaTitlesEnabled") ~= false -- v1.13: the top 3 win
	if m.winner ~= "A" and m.winner ~= "B" and not ffaW then script:SetAttribute("HpTitlesLast", "draw") return 0 end -- v1.13: + not ffaW
'''))
a = '\tlocal zeroRows = {} -- v1.10: winners with no board row yet\n'
S.append((a, '''	if m.mode == "ffa" then -- v1.13: the top 3 are team "W"
		for _, x in ipairs(rows) do x.team = (m.topSet and m.topSet[x.id]) and "W" or "L" end
	end
''' + a))
a = '\tlocal res = MatchAwards.compute(rows, m.winner, PRACTICE, awardsCfg())\n'
S.append((a, '''	if m.mode == "ffa" then -- v1.13: the top 3 get the win XP
		for _, x in ipairs(rows) do x.team = (m.topSet and m.topSet[x.id]) and "W" or "L" end
	end
''' + a))
a = 'local nextMode = nil -- v1.12: the mode the next match plays ("tdm" / "hardpoint"; nil = hardpoint)\n'
S.append((a, '''local FFA = {} -- v1.13: Free for All (see the header)
function FFA.limit() return tonumber(script:GetAttribute("HpFfaLimit")) or 20 end
function FFA.places()
	for _, d in ipairs(counted()) do -- every dino in the match is placed (0 / 0 until it kills or dies)
		local id, name, species, isBot = idOf(d)
		if id and not board[id] then boardRow(id, name, d.team, species, isBot) end
	end
	local list = {}
	for _, r in pairs(board) do table.insert(list, r) end
	table.sort(list, function(x, y)
		if x.k ~= y.k then return x.k > y.k end
		if x.d ~= y.d then return x.d < y.d end
		if tostring(x.name) ~= tostring(y.name) then return tostring(x.name) < tostring(y.name) end
		return tostring(x.id) < tostring(y.id)
	end)
	return list
end
function FFA.publish(list)
	local ids = {}
	for i, r in ipairs(list) do ids[i] = r.id end
	set("HpFfaPlaces", HttpService:JSONEncode(ids))
end
function FFA.flag()
	local on = match ~= nil and match.mode == "ffa"
	if ReplicatedStorage:GetAttribute("HardpointFFA") ~= on then ReplicatedStorage:SetAttribute("HardpointFFA", on) end
end
''' + a))
a = '\tmatch.mode = nextMode == "tdm" and "tdm" or "hardpoint" -- v1.12\n'
S.append((a, a + '''	if nextMode == "ffa" then -- v1.13
		match.mode = "ffa"
		match.state.clock = tonumber(script:GetAttribute("HpFfaClock")) or 600
		match.opening = false -- no team opening spots: everyone spawns away from everyone
	end
	set("HpFfaLimit", FFA.limit())
	set("HpFfaPlaces", "")
	FFA.flag()
'''))
a = 'local function publish()\n\tlocal a, b = teamCounts()\n'
S.append((a, 'local function publish()\n\tFFA.flag() -- v1.13\n\tlocal a, b = teamCounts()\n'))
a = '\tif match.mode == "tdm" then -- v1.12: Team Deathmatch (see the header)\n'
S.append((a, '''	if match.mode == "ffa" then -- v1.13: Free for All (see the header)
		match.state.clock = math.max(0, match.state.clock - H.TICK)
		set("HpOcc", "N")
		set("HpClockPaused", false)
		local list = FFA.places()
		FFA.publish(list)
		match.state.scoreA = list[1] and list[1].k or 0
		match.state.scoreB = list[2] and list[2].k or 0
		if (list[1] and list[1].k >= FFA.limit()) or match.state.clock <= 0 then
			local topN = tonumber(script:GetAttribute("HpFfaTopWin")) or 3
			match.topSet = {}
			for i, r in ipairs(list) do if i <= topN then match.topSet[r.id] = true end end
			match.phase = "results"
			match.winner = "W"
			local extra = titlesAtResults(match)
			match.resultsEndAt = now() + H.RESULTS + extra
			set("HpWinner", "ffa")
			set("HpResultsEndAt", match.resultsEndAt)
			if match.titleList then set("HpTitles", HttpService:JSONEncode({key = match.resultsEndAt, list = match.titleList})) end
			award(match)
			script:SetAttribute("HpFfaLast", ("%s %d clock %d n %d"):format(list[1] and tostring(list[1].id) or "-",
				list[1] and list[1].k or 0, math.ceil(match.state.clock - 1e-6), #list))
		end
		ticks += 1
		if ticks % 20 == 0 then script:SetAttribute("HpTicks", ticks) end
		publish()
		return
	end
''' + a))
a = '\t\tnextMode = (b == "tdm" and script:GetAttribute("HpTdmEnabled") ~= false) and "tdm" or "hardpoint" -- v1.12\n'
S.append((a, a + '\t\tif b == "ffa" and script:GetAttribute("HpFfaEnabled") ~= false then nextMode = "ffa" end -- v1.13\n'))
a = '\t\tlocal r = boardRow(a, b, c, d, e2)\n'
S.append((a, a + '\t\tif f == "k" and match.mode == "ffa" and (r.k or 0) >= FFA.limit() then return "ok" end -- v1.13: none past the limit\n'))
JOBS["HardpointServer"] = ("src/server/HardpointServer.server.luau", SSS + "HardpointServer", S)

# ---------------- SquadRules 1.4 ----------------
Y = []
a = 'local Players = game:GetService("Players")\nlocal ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal RunService = game:GetService("RunService") -- v1.3\n'
Y.append((a, '''-- v1.4 (Free for All, ''' + Q + '''): while teamLive() and ffaLive() — ReplicatedStorage
--   HardpointFFA == true (HardpointServer 1.13, a Free for All match) and ReplicatedStorage HardpointFfaRules ~= false (the switch) —
--   same / sameChar answer false (nobody is anyone's teammate: every damage path hits everyone, team heals reach nobody). The
--   HubSafe row of sameChar still comes first. ffaLive() -> bool. ffaLive() false -> exactly 1.3.
''' + a))
a = 'function M.teamOfPlayer(player)\n'
Y.append((a, '''function M.ffaLive() -- v1.4
	return ReplicatedStorage:GetAttribute("HardpointFFA") == true and ReplicatedStorage:GetAttribute("HardpointFfaRules") ~= false
end

''' + a))
a = '\tif M.teamLive() then return M.sameIds(true, M.teamOfPlayer(plA), M.teamOfPlayer(plB), plA == plB) end -- v1.1\n'
Y.append((a, '\tif M.teamLive() and M.ffaLive() then return false end -- v1.4\n' + a))
a = '\tif M.teamLive() then return M.sameIds(true, M.teamOf(a), M.teamOf(b), a == b) end -- v1.1\n'
Y.append((a, '\tif M.teamLive() and M.ffaLive() then return false end -- v1.4\n' + a))
JOBS["SquadRules"] = ("src/shared/SquadRules.luau", 'game:GetService("ServerStorage").DinoArcade.SquadRules', Y)

# ---------------- PracticeBrain 1.2 / PracticeBrain2 2.7 ----------------
B1 = []
a = 'function M.enemiesOf(team, bots)\n\tlocal list = {}\n'
B1.append((a, '''-- v1.2 (Free for All, ''' + Q + '''): enemiesOf(team, bots, self): with self given and
--   ReplicatedStorage HardpointFFA == true, every living bot but self and every living player out of the menu on a seat ("A" / "B")
--   is an enemy. self nil (PracticeBrain 1.x callers) or not FFA = 1.1.
function M.enemiesOf(team, bots, self) -- v1.2: + self
	local list = {}
	if self ~= nil and game:GetService("ReplicatedStorage"):GetAttribute("HardpointFFA") == true then -- v1.2: Free for All
		for _, b in ipairs(bots) do
			if b.model and b.model ~= self and aliveModel(b.model) then table.insert(list, b.model) end
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			local t = pl:GetAttribute("HardpointTeam")
			local c = pl.Character
			if (t == "A" or t == "B") and c and pl:GetAttribute("InMenu") ~= true and aliveModel(c) then table.insert(list, c) end
		end
		return list
	end
'''))
JOBS["PracticeBrain"] = ("src/server/PracticeServer/PracticeBrain.luau", SSS + "PracticeServer.PracticeBrain", B1)
B2 = []
a = '\tfor _, e in ipairs(V1.enemiesOf(b.team, ctx.bots)) do\n'
B2.append((a, '\tfor _, e in ipairs(V1.enemiesOf(b.team, ctx.bots, b.model)) do -- v2.7: + self (Free for All)\n'))
a = '\tlocal enemies = V1.enemiesOf(b.team, ctx.bots)\n'
B2.append((a, '\tlocal enemies = V1.enemiesOf(b.team, ctx.bots, b.model) -- v2.7: + self (Free for All)\n'))
a = 'local Players = game:GetService("Players")\nlocal RunService = game:GetService("RunService")\nlocal PathfindingService = game:GetService("PathfindingService")\n'
B2.append((a, '''-- v2.7 (Free for All, ''' + Q + '''): both enemiesOf calls pass the bot's own model
--   (PracticeBrain 1.2): in a Free for All match every other dino is an enemy.
''' + a))
JOBS["PracticeBrain2"] = ("src/server/PracticeServer/PracticeBrain2.luau", SSS + "PracticeServer.PracticeBrain2", B2)

# ---------------- PracticeServer 1.18 ----------------
P = []
a = '--   Diagnostics: script attribute PgVoteLast ("<winner> <how: most / tie / none> <counts>").\n'
P.append((a, a + '''VERSION = "1.18" -- v1.18 Free for All
-- v1.18 (Free for All, ''' + Q + '''): the vote also offers "ffa" (script attribute PgVoteFfaEnabled ~= false, read per
--   use; appended after PgVoteModes). PrMode "ffa" -> HardpointPractice("start", lead, "ffa") (HardpointServer 1.13); the 8 seats
--   stay the two groups of 4. FFA bots: every job "duel" (why "ffa"; PrFfaBotsHuntEnabled ~= false). Arena result: HpWinner "ffa"
--   (or "W"): each human is team "W" when placed in the top HpFfaTopWin (3) of HpFfaPlaces, else "L", and the winner is "W".
'''))
a = '\tif #t == 0 then t = {"hardpoint"} end\n\treturn t\nend\nfunction MV.active()'
P.append((a, '\tif script:GetAttribute("PgVoteFfaEnabled") ~= false and not table.find(t, "ffa") then table.insert(t, "ffa") end -- v1.18\n' + a))
a = '\t\t\t\tif MV.mode == "tdm" and get("PrTdmBotsHuntEnabled") ~= false then -- v1.17: TDM bots hunt\n'
P.append((a, '''				if MV.mode == "ffa" and get("PrFfaBotsHuntEnabled") ~= false then -- v1.18: FFA bots hunt anyone
					for _, e in pairs(res) do e.job, e.why = "duel", "ffa" end
				end
''' + a))
a = '\tlocal r = arenaReport("result", arena.matchId, list, w, elig, {A = arena.leavers.A, B = arena.leavers.B})\n'
P.append((a, '''	if (w == "ffa" or w == "W") and MV.mode == "ffa" then -- v1.18: Free for All: the top 3 win
		local okP, ids = pcall(function() return HttpService:JSONDecode(hpState:GetAttribute("HpFfaPlaces") or "[]") end)
		local place = {}
		if okP and type(ids) == "table" then for i, id in ipairs(ids) do place[id] = i end end
		local top = tonumber(hs:GetAttribute("HpFfaTopWin")) or 3
		for _, e in ipairs(list) do
			local p = place["u" .. e.player.UserId]
			e.team = (p and p <= top) and "W" or "L"
		end
		w = "W"
	end
''' + a))
JOBS["PracticeServer"] = ("src/server/PracticeServer/init.server.luau", SSS + "PracticeServer", P)

# ---------------- HardpointHUD 1.17 ----------------
U = []
a = 'VERSION = "1.16" -- v1.16 Team Deathmatch HUD\n'
U.append((a, a + '''VERSION = "1.17" -- v1.17 Free for All HUD
-- v1.17 (Free for All, ''' + Q + '''): while ReplicatedStorage.Hardpoint HpMode == "ffa" (HardpointServer 1.13) and script
--   attribute HardpointHUDFfaEnabled ~= false (read per frame). Order = HpFfaPlaces (ids), anyone not in it after them by kills,
--   then deaths, then name.
--   * the score card (70 high) shows the standings over the bars: "FIRST TO 20" (yellow; "GO IN m:ss" in the warm-up) and the
--     clock, then the top 3, or the top 2 and you when you are lower ("<place>  <NAME>", kills right; you yellow, "YOU"). Status
--     pill only in the warm-up (GET READY); NEXT, marker, compass, phone strip hidden (the phone shows the card).
--   * results: the title is your place ("1ST PLACE", "2ND PLACE", ...); board sub / banner "FREE FOR ALL · VOLT WINS WITH 20"
--     ("YOU WIN WITH 20"); the two tables are PLACES 1-4 and PLACES 5-8 ("<place>  <name>", Dino, K, D, XP; no on-point column);
--     MVP / SVP tags and XP follow that order; the spot cards read "<k> K   <d> D" and the dino only. Name tags over players: red.
'''))
a = '''			if TD.on() then -- v1.16
				c.stats.Text = ('<font color="#%s">%d</font> K   <font color="#%s">%d</font> D'):format(pk.col:ToHex(), r.k or 0,
					pk.col:ToHex(), r.d or 0)
			end
'''
U.append((a, a + '''			if TD.ffa and TD.ffa() then -- v1.17
				c.stats.Text = ('<font color="#%s">%d</font> K   <font color="#%s">%d</font> D'):format(pk.col:ToHex(), r.k or 0,
					pk.col:ToHex(), r.d or 0)
				c.sub.Text = sp
			end
'''))
a = '\t\tif TD.on() then ebSub.Text = ebSub.Text .. " · TEAM DEATHMATCH" end -- v1.16\n'
U.append((a, a + '''		if TD.ffa and TD.ffa() then -- v1.17
			ebSub.Text = ebSub.Text .. " · FREE FOR ALL"
			ebScore.Text = TD.winLine()
			local p = TD.place(TD.order())
			ebTitle.TextColor3 = (p and p <= 3) and YELLOW or PINK
		end
'''))
a = '\t\t\tg.Label.TextColor3 = (t == mine) and BLUE or RED\n'
U.append((a, a + '\t\t\tif TD.ffa and TD.ffa() then g.Label.TextColor3 = RED end -- v1.17\n'))
a = 'RunService.RenderStepped:Connect(function()\n\tlocal phase = state:GetAttribute("HpPhase")\n'
U.append((a, '''-- ---------- v1.17: Free for All (see the header) ----------
function TD.ffa() return state:GetAttribute("HpMode") == "ffa" and script:GetAttribute("HardpointHUDFfaEnabled") ~= false end
function TD.limitF() return tonumber(state:GetAttribute("HpFfaLimit")) or 20 end
function TD.order()
	local list = readBoardList()
	local byId, out, seen = {}, {}, {}
	for _, r in ipairs(list) do byId[r.id] = r end
	local ok, ids = pcall(function() return HttpService:JSONDecode(state:GetAttribute("HpFfaPlaces") or "[]") end)
	if ok and type(ids) == "table" then
		for _, id in ipairs(ids) do
			if byId[id] and not seen[id] then table.insert(out, byId[id]) seen[id] = true end
		end
	end
	local rest = {}
	for _, r in ipairs(list) do if not seen[r.id] then table.insert(rest, r) end end
	table.sort(rest, function(x, y)
		if (x.k or 0) ~= (y.k or 0) then return (x.k or 0) > (y.k or 0) end
		if (x.d or 0) ~= (y.d or 0) then return (x.d or 0) < (y.d or 0) end
		return tostring(x.name) < tostring(y.name)
	end)
	for _, r in ipairs(rest) do table.insert(out, r) end
	return out
end
function TD.place(o) for i, r in ipairs(o) do if r.id == "u" .. player.UserId then return i end end return nil end
function TD.pname(i) return ({"1ST", "2ND", "3RD"})[i] or (i .. "TH") end
function TD.title() local p = TD.place(TD.order()) return p and (TD.pname(p) .. " PLACE") or "RESULTS" end
function TD.winLine()
	local r = TD.order()[1]
	if not r then return "FREE FOR ALL" end
	local me = r.id == "u" .. player.UserId
	return ("%s %s WITH %d"):format(me and "YOU" or string.upper(tostring(r.name)), me and "WIN" or "WINS", r.k or 0)
end
function TD.fillNames(o)
	for t = 1, 2 do
		local T = bTables[t]
		T[0][1].Text = ('<font color="#ffc832">%s</font>'):format(t == 1 and "PLACES 1-4" or "PLACES 5-8")
		T[0][5].Text = ""
		for i = 1, BOARD_ROWS do
			local idx = (t - 1) * 4 + i
			local r = i <= 4 and o[idx] or nil
			local cells = T[i]
			if r then
				local me = r.id == "u" .. player.UserId
				local nm = idx .. "  " .. (me and "★ " or "") .. tostring(r.name)
				local persona = r.p == true and script:GetAttribute("FillerPersonaUI") ~= false
				if r.bot and not persona then nm = nm .. ' <font size="10" color="#8f99aa">BOT</font>' end
				cells[1].Text, cells[2].Text = nm, SHORT[r.species] or tostring(r.species or "")
				cells[3].Text, cells[4].Text, cells[5].Text = tostring(r.k or 0), tostring(r.d or 0), ""
				for _, c in ipairs(cells) do c.TextColor3 = me and YELLOW or Color3.new(1, 1, 1) end
			else
				for _, c in ipairs(cells) do c.Text = "" end
			end
		end
	end
end
do
	local rawBoard = drawBoard
	drawBoard = function(mine, you, foe, title)
		rawBoard(mine, you, foe, title)
		if not TD.ffa() then return end
		TD.fillNames(TD.order())
		bSub.Text = "FREE FOR ALL · " .. TD.winLine()
	end
	local rawEnd = drawEndBoard
	drawEndBoard = function(mine, aw)
		rawEnd(mine, aw)
		if not TD.ffa() then return end
		local o = TD.order()
		TD.fillNames(o)
		for t = 1, 2 do
			for i = 1, BOARD_ROWS do
				local idx = (t - 1) * 4 + i
				local r = i <= 4 and o[idx] or nil
				local cell = xpCells[t] and xpCells[t][i]
				if cell and r then
					local a = aw and aw.rows and aw.rows[r.id]
					local persona = r.p == true and script:GetAttribute("FillerPersonaUI") ~= false
					cell.Text = (a and (not r.bot or persona)) and ("+" .. tostring(a.total or 0)) or "—"
					local tag = aw and ((r.id == aw.mvp and '<font size="11" color="#ffd25a">MVP</font> ')
						or (r.id == aw.svp and '<font size="11" color="#c9d3e0">SVP</font> ')) or nil
					if tag then bTables[t][i][1].Text = tag .. bTables[t][i][1].Text end
					cell.TextColor3 = r.id == "u" .. player.UserId and YELLOW or GREEN
				elseif cell then
					cell.Text = ""
				end
			end
		end
	end
end
-- the standings card over the score card
TD.box = Instance.new("Frame")
TD.box.Name = "FfaStandings"
TD.box.Size = UDim2.fromScale(1, 1)
TD.box.BackgroundColor3 = PANEL
TD.box.BackgroundTransparency = 0
TD.box.ZIndex = 3
TD.box.Visible = false
corner(TD.box, 10)
TD.box.Parent = card
TD.rows = {}
for i = 1, 4 do
	local y = 4 + (i - 1) * 15.5
	TD.rows[i] = {
		l = label(TD.box, {Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -70, 0, 15), TextSize = 13, ZIndex = 4,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = ""}),
		r = label(TD.box, {Position = UDim2.new(1, -58, 0, y), Size = UDim2.fromOffset(46, 15), TextSize = 13, ZIndex = 4,
			TextXAlignment = Enum.TextXAlignment.Right, Text = ""}),
	}
end
function TD.card(warm, remaining)
	local o = TD.order()
	local p = TD.place(o)
	local show = (p and p > 3) and {1, 2, p} or {1, 2, 3}
	TD.rows[1].l.Text = warm and ("GO IN " .. fmt(remaining)) or ("FIRST TO %d"):format(TD.limitF())
	TD.rows[1].l.TextColor3 = YELLOW
	TD.rows[1].r.Text = clockL.Text
	for k = 1, 3 do
		local i = show[k]
		local r = o[i]
		local L, R = TD.rows[k + 1].l, TD.rows[k + 1].r
		if r then
			local me = r.id == "u" .. player.UserId
			L.Text = i .. "  " .. (me and "YOU" or string.upper(tostring(r.name)))
			R.Text = tostring(r.k or 0)
			L.TextColor3 = me and YELLOW or Color3.new(1, 1, 1)
			R.TextColor3 = L.TextColor3
		else
			L.Text, R.Text = "", ""
		end
	end
end

''' + a))
a = '\tslimUpdate() -- v1.6\n'
U.append((a, a + '''	TD.box.Visible = TD.ffa() -- v1.17
	if TD.box.Visible then card.Size = UDim2.fromOffset(card.Size.X.Offset, 70) end
'''))
a = '\t\tlocal title = (w == "draw") and "DRAW" or (w == mine and "VICTORY" or "DEFEAT")\n\t\tbp.Visible = not boardDismissed\n'
U.append((a, '''		local title = (w == "draw") and "DRAW" or (w == mine and "VICTORY" or "DEFEAT")
		if TD.ffa() then title = TD.title() end -- v1.17: your place
		bp.Visible = not boardDismissed
'''))
a = '\tif TD.on() then -- v1.16: no point in Team Deathmatch\n'
U.append((a, '''	if TD.ffa() then -- v1.17: Free for All: the standings card, no point
		TD.card(warm, remaining)
		status.Visible = warm
		status.Text, status.TextColor3 = "GET READY", Color3.new(1, 1, 1)
		nextL.Visible = false
		marker.Visible = false
		mv3Off()
		cmp.Visible, cmpUnder.Visible = false, false
		if v2hid then card.Visible = true v2hid = false end
		script:SetAttribute("HardpointHUDState", "ffa")
		return
	end
''' + a))
JOBS["HardpointHUD"] = ("src/client/HardpointHUD.client.luau", SPS + "HardpointHUD", U)

# ---------------- PrematchCountdown 1.3 ----------------
C = []
a = 'VERSION = "1.2" -- v1.2 Team Deathmatch texts\n'
C.append((a, a + '''VERSION = "1.3" -- v1.3 Free for All texts
-- v1.3 (Free for All, ''' + Q + '''): while HpMode == "ffa" and script attribute PrematchFfaEnabled ~= false (per frame):
--   FREE FOR ALL / EVERY DINO FOR ITSELF / FIRST TO <HpFfaLimit> KILLS · <HpClock / 60> MIN; no FIRST POINT pill.
'''))
a = '\tif tdm then pill.Visible = false end\n'
C.append((a, a + '''	if hp:GetAttribute("HpMode") == "ffa" and script:GetAttribute("PrematchFfaEnabled") ~= false then -- v1.3
		mode.Text = "FREE FOR ALL"
		obj.Text = "EVERY DINO FOR ITSELF"
		how.Text = ("FIRST TO %d KILLS · %d MIN"):format(tonumber(hp:GetAttribute("HpFfaLimit")) or 20,
			math.floor((tonumber(hp:GetAttribute("HpClock")) or 600) / 60 + 0.5))
		pill.Visible = false
	end
'''))
JOBS["PrematchCountdown"] = ("src/client/PrematchCountdown.client.luau", SPS + "PrematchCountdown", C)

# ---------------- HardpointPointFX 1.2 ----------------
F = []
a = 'VERSION = "1.1" -- v1.1 no point in Team Deathmatch\n'
F.append((a, a + 'VERSION = "1.2" -- v1.2 no point in Free for All (HpMode "ffa", same switch HardpointPointFXTdmHideEnabled)\n'))
a = '\tif on and state:GetAttribute("HpMode") == "tdm" and script:GetAttribute("HardpointPointFXTdmHideEnabled") ~= false then on = false end -- v1.1\n'
F.append((a, a + '\tif on and state:GetAttribute("HpMode") == "ffa" and script:GetAttribute("HardpointPointFXTdmHideEnabled") ~= false then on = false end -- v1.2\n'))
JOBS["HardpointPointFX"] = ("src/client/HardpointPointFX.client.luau", SPS + "HardpointPointFX", F)

# ---------------- GameSounds 1.23 ----------------
N = []
a = 'VERSION = "1.22" -- v1.22 no point lines in Team Deathmatch\n'
N.append((a, a + '''VERSION = "1.23" -- v1.23 Free for All
-- v1.23 (Free for All, ''' + Q + '''): the v1.22 quiet rules also hold while HpMode == "ffa" (switch GameSoundsTdmQuietEnabled);
--   at the results with HpWinner "ffa": win when your id is in the top 3 of HpFfaPlaces, else lose (switch
--   GameSoundsFfaResultEnabled, default true, read per results).
'''))
a = '\t\t\tand not (hp:GetAttribute("HpMode") == "tdm" and script:GetAttribute("GameSoundsTdmQuietEnabled") ~= false) -- v1.22\n'
N.append((a, a + '\t\t\tand not (hp:GetAttribute("HpMode") == "ffa" and script:GetAttribute("GameSoundsTdmQuietEnabled") ~= false) -- v1.23\n'))
a = '\t\tif ph == "live" and not (hp:GetAttribute("HpMode") == "tdm" and script:GetAttribute("GameSoundsTdmQuietEnabled") ~= false) then -- v1.22: + not TDM\n'
N.append((a, '\t\tif ph == "live" and not ((hp:GetAttribute("HpMode") == "tdm" or hp:GetAttribute("HpMode") == "ffa") and script:GetAttribute("GameSoundsTdmQuietEnabled") ~= false) then -- v1.22: + not TDM; v1.23: + not FFA\n'))
a = '\t\t\tif (team == "A" or team == "B") and (w == "A" or w == "B") then play(w == team and "win" or "lose", true) end\n'
N.append((a, a + '''			if w == "ffa" and script:GetAttribute("GameSoundsFfaResultEnabled") ~= false then -- v1.23
				local okP, ids = pcall(function() return game:GetService("HttpService"):JSONDecode(hp:GetAttribute("HpFfaPlaces") or "[]") end)
				local place
				if okP and type(ids) == "table" then for i, id in ipairs(ids) do if id == "u" .. player.UserId then place = i end end end
				if place then play(place <= 3 and "win" or "lose", true) end
			end
'''))
JOBS["GameSounds"] = ("src/client/GameSounds.client.luau", SPS + "GameSounds", N)

# ---------------- TeamTags 1.3 ----------------
T = []
a = 'VERSION = "1.2" -- v1.2 rank badge\n'
T.append((a, a + '''VERSION = "1.3" -- v1.3 Free for All: no friends
-- v1.3 (Free for All, ''' + Q + '''): while ReplicatedStorage.Hardpoint HpMode == "ffa" and script attribute
--   TeamTagsFfaEnabled ~= false (read per SLOW tick) every other dino counts as the other team (no blue friend markers).
'''))
a = '\tlocal dinos, botsFolder = collect()\n'
T.append((a, a + '''	if hp:GetAttribute("HpMode") == "ffa" and get("TeamTagsFfaEnabled") ~= false then -- v1.3: nobody is a friend
		for _, info in pairs(dinos) do info.team = "FFA" end
	end
'''))
JOBS["TeamTags"] = ("src/client/TeamTags.client.luau", SPS + "TeamTags", T)

# ---------------- KillFeed 1.6 ----------------
K = []
a = 'VERSION = "1.5" -- v1.5 hidden while the phone menu drawer is open\n'
K.append((a, a + '''VERSION = "1.6" -- v1.6 Free for All: no team colours
-- v1.6 (Free for All, ''' + Q + '''): while ReplicatedStorage.Hardpoint HpMode == "ffa" and script attribute KillFeedFfaEnabled
--   ~= false (read per line) every name is white (no blue / red teams).
'''))
a = 'local function teamColor(team)\n\tlocal mine = player:GetAttribute("HardpointTeam")\n'
K.append((a, a + '''	local hpS = ReplicatedStorage:FindFirstChild("Hardpoint") -- v1.6
	if hpS and hpS:GetAttribute("HpMode") == "ffa" and script:GetAttribute("KillFeedFfaEnabled") ~= false then return WHITE end
'''))
JOBS["KillFeed"] = ("src/client/KillFeed.client.luau", SPS + "KillFeed", K)

# ---------------- PregameScreen 1.11 ----------------
G = []
a = 'VERSION = "1.10" -- v1.10 Team Deathmatch titles\n'
G.append((a, a + '''VERSION = "1.11" -- v1.11 Free for All lineup (B: two rows of 4) + intro
-- v1.11 (Free for All, ''' + Q + '''): while ReplicatedStorage.Practice PrMode == "ffa" (PracticeServer 1.18) and script
--   attribute PregameFfaEnabled ~= false (read per refresh / frame):
--   * LINEUP: all 8 seats, you first, then your seat group, then the other: two rows of 4 (columns 225 wide, 3D 110 high at y 74
--     and y 240; plaques at the column's foot, UIScale 0.62). Columns 5-8 are new (built like 1-4, hidden outside FFA). Each
--     dino has its own colour (ring + plaque border; HSV hue (i - 1) / 8 + 0.75, sat 0.62); your plaque keeps the yellow
--     border. Sub line "FREE FOR ALL · 8 DINOS · EVERY DINO FOR ITSELF" (the count follows the roster). Outside FFA: 1.10.
--   * INTRO: the 8 dinos lit one after another, 4 at a time (dinos 1-4 then 5-8), each PG_INTRO / count s, callout
--     "FREE FOR ALL · n OF 8" in its colour, the name, "<dino> · <record>". No VS screen.
--   * SELECT: the team strip and the team-needs line are hidden (no team).
'''))
a = '\tif state:GetAttribute("PrMode") == "tdm" and script:GetAttribute("PregameModeLineEnabled") ~= false then return "TEAM DEATHMATCH" end -- v1.10\n'
G.append((a, a + '\tif state:GetAttribute("PrMode") == "ffa" and script:GetAttribute("PregameModeLineEnabled") ~= false then return "FREE FOR ALL" end -- v1.11\n'))
a = '-- ---------- SELECT ----------\nlocal S = views.Select\n'
G.append((a, '''-- ---------- v1.11: Free for All lineup (see the header) ----------
local FF = {}
function FF.on() return state ~= nil and state:GetAttribute("PrMode") == "ffa" and script:GetAttribute("PregameFfaEnabled") ~= false end
function FF.color(i) return Color3.fromHSV(((i - 1) / 8 + 0.75) % 1, 0.62, 1) end
for i = 5, 8 do -- columns 5-8, built like 1-4 (hidden outside Free for All)
	local col = {}
	local x, top, viewH, py = colRect(i - 4)
	col.frame = new("Frame", {Name = "Col" .. i, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, top), Size = UDim2.fromOffset(225, viewH), Visible = false}, L)
	col.click = new("TextButton", {Name = "Hit", BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 4}, col.frame)
	col.plaque = new("TextButton", {Name = "Plaque" .. i, AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(17, 24, 33),
		BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x + 112, py), Size = UDim2.fromOffset(190, 118), ZIndex = 5, Visible = false}, L)
	corner(col.plaque, 6)
	col.stroke = stroke(col.plaque, C.line, 1.5)
	local function row(name, y, size, color, font)
		return text(col.plaque, {name = name, size = size, color = color, font = font, pos = UDim2.fromOffset(6, y), sz = UDim2.new(1, -12, 0, size + 3), z = 6})
	end
	col.pn = row("Name", 5, 10, C.text)
	col.wl = row("Record", 18, 16.5, C.text)
	col.pct = row("Pct", 37, 6.5, C.muted)
	col.dn = row("Dino", 49, 8, Color3.fromRGB(201, 212, 226))
	col.role = row("Role", 60, 6.5, C.bots)
	col.st = row("Ready", 72, 7.5, C.muted)
	col.pips = new("Frame", {Name = "Pips", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(56, 12), ZIndex = 6}, col.plaque)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Center}, col.pips)
	col.pip = {}
	for k = 1, 4 do
		col.pip[k] = new("Frame", {BackgroundColor3 = Color3.fromRGB(43, 55, 71), BorderSizePixel = 0, Size = UDim2.fromOffset(11, 11), ZIndex = 6}, col.pips)
		corner(col.pip[k], 3)
	end
	if phone then
		col.pct.Visible, col.dn.Visible, col.role.Visible = false, false, false
		col.wl.Position, col.st.Position = UDim2.fromOffset(6, 22), UDim2.fromOffset(6, 50)
		col.pips.Position = UDim2.new(0.5, 0, 0, 72)
		col.plaque.Size = UDim2.fromOffset(190, 92)
	end
	col.tap = text(L, {name = "Tap" .. i, text = "TAP TO SELECT", size = 8, color = C.dark, anchor = Vector2.new(0.5, 1),
		pos = UDim2.fromOffset(x + 112, top + 14), sz = UDim2.fromOffset(110, 16), z = 6})
	col.tap.BackgroundTransparency, col.tap.BackgroundColor3 = 0, C.yellow
	corner(col.tap, 4)
	col.tap.Visible = false
	col.view = nil
	col.flat = nil
	cols[i] = col
end
for _, col in ipairs(cols) do col.ffaScale = new("UIScale", {Name = "FfaScale", Scale = 1}, col.plaque) end
function FF.layout(on)
	for i, col in ipairs(cols) do
		local x, y, h, py, tapY, sc
		if on then
			local k = (i - 1) % 4
			x, y, h = 50 + k * 225, (i <= 4) and 74 or 240, 110
			py, tapY, sc = y + 104, y + 14, 0.62
		else
			local j = (i - 1) % 4 + 1
			local top, viewH
			x, top, viewH, py = colRect(j)
			y, h, tapY, sc = top, viewH, top + 14, 1
		end
		col.frame.Position, col.frame.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(225, h)
		col.plaque.Position = UDim2.fromOffset(x + 112, py)
		col.tap.Position = UDim2.fromOffset(x + 112, tapY)
		col.ffaScale.Scale = sc
	end
end
function FF.all()
	local all = {}
	for _, side in ipairs({mySide(), otherSide()}) do
		for _, e in ipairs(roster[side] or {}) do
			if isMe(e) then table.insert(all, 1, e) else table.insert(all, e) end
		end
	end
	return all
end

''' + a))
a = 'state:GetAttributeChangedSignal("PrRoster"):Connect(function() sig = "" end)\n'
G.append((a, '''do -- v1.11: Free for All lineup / intro / select (see the header)
	local rawRefresh = refresh
	refresh = function()
		local ph = rawRefresh()
		local on = FF.on()
		FF.layout(on)
		if on then
			local all = FF.all()
			for i, col in ipairs(cols) do
				local e = all[i]
				setColumn(col, e, FF.color(i), isMe(e))
				if e and not isMe(e) then col.stroke.Color = FF.color(i) end
			end
			tops.Lineup.sub.Text = ("FREE FOR ALL · %d DINOS · EVERY DINO FOR ITSELF"):format(#all)
			local allReady = #all > 0
			for _, e in ipairs(all) do if e.kind == "human" and e.ready ~= true then allReady = false end end
			allReadyLbl.Visible = allReady
		end
		return ph
	end
	local rawIntro = drawIntro
	drawIntro = function(t)
		if not FF.on() then return rawIntro(t) end
		local all = FF.all()
		local n = math.max(1, #all)
		local per = (PR.PG_INTRO or 8) / n
		local i = math.clamp(math.floor(t / per) + 1, 1, n)
		local g = (i <= 4) and 0 or 4
		local group = {}
		for k = 1, 4 do group[k] = all[g + k] end
		vs.Visible = false
		introColumns(group, FF.color(i), i - g)
		local e = all[i]
		if e then
			coT.Text, coT.TextColor3 = ("FREE FOR ALL · %d OF %d"):format(i, #all), FF.color(i)
			coN.Text = isMe(e) and "YOU" or tostring(e.name)
			local rec, sub = recordOf(e)
			coR.Text = nameOf(slotDino(e)) .. " · " .. rec .. (sub ~= "" and (" · " .. sub) or "")
		end
		counter.Text = "PLAYER INTROS"
	end
	local rawSelect = drawSelect
	drawSelect = function()
		rawSelect()
		if FF.on() then strip.Visible = false needsLbl.Visible = false end
	end
end
''' + a))
JOBS["PregameScreen"] = ("src/client/PregameScreen.client.luau", SPS + "PregameScreen", G)
