"""Arena modes step 1: Team Deathmatch + the mode vote before the lineup (Kepu 2026-11-26 19:21 "Build", mockup
docs/mockups/arena_modes_v0.3.html). Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_tdm.py
The new client VoteScreen 1.0 is a whole new file (src/client/VoteScreen.client.luau), installed separately."""
Q = ('Kepu 2026-11-26 "How about other game modes like team death match for arena like how apex does it or free for all" -> "Let\'s do '
     '1. 2 3 like you suggested"; 17:00 "Vote mode should be a quick screen before we even go into the Dino lineups like this. Like 15 '
     'seconds max to vote"; 19:21 "Build" on mockup docs/mockups/arena_modes_v0.3.html; numbers: the recommended ones')
SSS = 'game:GetService("ServerScriptService").'
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}

# ---------------- HardpointServer 1.12 ----------------
S = []
a = 'VERSION = "1.11" -- v1.11 persona bots on the board (p)\n'
S.append((a, a + '''VERSION = "1.12" -- v1.12 Team Deathmatch
-- v1.12 (Team Deathmatch, ''' + Q + '''):
--   * HardpointPractice("start", lead, mode): mode "tdm" (and script attribute HpTdmEnabled ~= false, read per start) makes the
--     new match Team Deathmatch; anything else = Hardpoint as 1.11. match.mode; ReplicatedStorage.Hardpoint HpMode ("hardpoint" /
--     "tdm") and HpTdmLimit (script attribute HpTdmLimit, 30) are set at every new match. A TDM match starts its clock at
--     HpTdmClock (600) s.
--   * TDM live tick: no point scoring and no point seconds (HpOcc "N", HpClockPaused false); the clock always runs down by TICK.
--     The practice hook's "stat" field "k" with team "A" / "B" while the match is live adds 1 to that team's score (HpScoreA /
--     HpScoreB = team kills). Winner: a team at HpTdmLimit kills, or the clock at 0: more kills wins, equal = "draw". Then the
--     same results as Hardpoint (titles, awards, HpWinner, HpResultsEndAt). Warm-up, rotations (the hidden point still drives the
--     spawns), the board and the practice end are unchanged.
--   Diagnostics: script attributes HpModeLast (the last match's mode), HpTdmLast ("<winner> <a>-<b> clock <s>").
'''))
a = 'if script:GetAttribute("HardpointEnabled") == nil then script:SetAttribute("HardpointEnabled", true) end\n'
S.append((a, a + '''for k, v in pairs({HpTdmEnabled = true, HpTdmLimit = 30, HpTdmClock = 600}) do -- v1.12
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
'''))
a = 'local function newMatch()\n\tmatch = {startAt = now(), state = H.newState(), phase = "warmup", winner = nil, resultsEndAt = nil, acc = 0}\n'
S.append((a, 'local nextMode = nil -- v1.12: the mode the next match plays ("tdm" / "hardpoint"; nil = hardpoint)\n' + a + '''	match.mode = nextMode == "tdm" and "tdm" or "hardpoint" -- v1.12
	if match.mode == "tdm" then match.state.clock = tonumber(script:GetAttribute("HpTdmClock")) or 600 end
	set("HpMode", match.mode)
	set("HpTdmLimit", tonumber(script:GetAttribute("HpTdmLimit")) or 30)
	script:SetAttribute("HpModeLast", match.mode)
'''))
a = '\tmatch.phase = "live"\n\tlocal centre = POINTS[ph.index].centre\n'
S.append((a, '''	match.phase = "live"
	if match.mode == "tdm" then -- v1.12: Team Deathmatch (see the header)
		match.state.clock = math.max(0, match.state.clock - H.TICK)
		set("HpOcc", "N")
		set("HpClockPaused", false)
		local s, lim = match.state, tonumber(script:GetAttribute("HpTdmLimit")) or 30
		if s.scoreA >= lim or s.scoreB >= lim or s.clock <= 0 then
			local w = (s.scoreA > s.scoreB) and "A" or ((s.scoreB > s.scoreA) and "B" or "draw")
			match.phase = "results"
			match.winner = w
			local extra = titlesAtResults(match)
			match.resultsEndAt = now() + H.RESULTS + extra
			set("HpWinner", w)
			set("HpResultsEndAt", match.resultsEndAt)
			if match.titleList then set("HpTitles", HttpService:JSONEncode({key = match.resultsEndAt, list = match.titleList})) end
			award(match)
			script:SetAttribute("HpTdmLast", ("%s %d-%d clock %d"):format(w, s.scoreA, s.scoreB, math.ceil(s.clock - 1e-6)))
		end
		ticks += 1
		if ticks % 20 == 0 then script:SetAttribute("HpTicks", ticks) end
		publish()
		return
	end
	local centre = POINTS[ph.index].centre
'''))
a = '\t\tif not PRACTICE then return "notPractice" end\n\t\tnewMatch()\n'
S.append((a, '''		if not PRACTICE then return "notPractice" end
		nextMode = (b == "tdm" and script:GetAttribute("HpTdmEnabled") ~= false) and "tdm" or "hardpoint" -- v1.12
		newMatch()
'''))
a = '\t\tr[f] = (r[f] or 0) + amt\n\t\treturn "ok"\n'
S.append((a, '''		r[f] = (r[f] or 0) + amt
		if f == "k" and match.mode == "tdm" and match.phase == "live" and (c == "A" or c == "B") then -- v1.12: a kill scores
			if c == "A" then match.state.scoreA += 1 else match.state.scoreB += 1 end
		end
		return "ok"
'''))
JOBS["HardpointServer"] = ("src/server/HardpointServer.server.luau", SSS + "HardpointServer", S)

# ---------------- PracticeServer 1.17 ----------------
P = []
a = 'VERSION = "1.16" -- v1.16 Arena fill bots pass as players (personas)\n'
P.append((a, a + '''VERSION = "1.17" -- v1.17 the mode vote before the lineup + TDM bots
-- v1.17 (Arena modes, ''' + Q + '''):
--   * the mode vote: while script attribute PgVoteEnabled ~= false, the pre-game is on and this is the Arena (or
--     PgVoteArenaOnly == false), a lobby with humans first runs the vote (read per tick): PgPhase "vote", PgEndsAt = the vote's
--     end (PgVoteSecs, 15 s from the first human), PrStartAt held at the vote's end + 1 + the lineup time. Humans vote with
--     RemoteEvent ReplicatedStorage.ModeVote(mode) (any of PgVoteModes "hardpoint,tdm"; switch any time; bots never vote;
--     player attributes PgVote, PgVoteResult "ok" / "closed" / "notInLobby" / "badArg" / "busy"). It ends at PgEndsAt or as soon
--     as every human in the lobby has voted. The winner: the most votes; a tie or no votes = among the tied (no votes: all
--     modes) the ones not played last on this server, at random (a fresh server: at random among them). The winner shows for
--     PgVoteFlash (1) s (PgVoteWinner set, PgEndsAt = now), then PrStartAt = now + the lineup time and the lineup runs as 1.16.
--     Practice state: PgVoteModes, PgVotes (JSON {mode = votes, current humans only}), PgVoteWinner, PgVoteHumans, PgVoteSecs,
--     PrMode (the mode picked; "hardpoint" until a vote picks). Every human leaving resets the vote; the lobby after a match
--     (toLobby) votes again. The match starts with HardpointPractice("start", lead, PrMode) (HardpointServer 1.12).
--   * TDM bots: while PrMode is "tdm" (and PrTdmBotsHuntEnabled ~= false, read per team pass) every bot's job is "duel"
--     (why "tdm"): they hunt enemies instead of holding, guarding or running to the point.
--   Diagnostics: script attribute PgVoteLast ("<winner> <how: most / tie / none> <counts>").
'''))
a = 'local function autoStart() return pgOn() and R.PG_LINEUP or get("PrAutoStart") end\n'
P.append((a, a + '''-- v1.17: the mode vote (see the header); one table, so the script's locals stay few
local MV = {by = {}, endsAt = nil, winner = nil, flashEnds = nil, done = false, mode = "hardpoint", last = nil, lastReq = {}}
for k, v in pairs({PgVoteEnabled = true, PgVoteArenaOnly = true, PgVoteSecs = 15, PgVoteFlash = 1, PgVoteModes = "hardpoint,tdm"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
set("PrMode", MV.mode)
function MV.on()
	return script:GetAttribute("PgVoteEnabled") ~= false and pgOn() and (ARENA or script:GetAttribute("PgVoteArenaOnly") == false)
end
function MV.modes()
	local t = {}
	for m in string.gmatch(tostring(script:GetAttribute("PgVoteModes") or ""), "[%a]+") do
		if (m == "hardpoint" or m == "tdm") and not table.find(t, m) then table.insert(t, m) end
	end
	if #t == 0 then t = {"hardpoint"} end
	return t
end
function MV.active() return MV.endsAt ~= nil and not MV.done end
function MV.counts()
	local c = {}
	for _, m in ipairs(MV.modes()) do c[m] = 0 end
	for _, h in ipairs(humans) do
		local v = MV.by[h.player.UserId]
		if v and c[v] then c[v] += 1 end
	end
	return c
end
function MV.allIn()
	if #humans == 0 then return false end
	for _, h in ipairs(humans) do if not MV.by[h.player.UserId] then return false end end
	return true
end
function MV.pick(c)
	local modes, best = MV.modes(), 0
	for _, m in ipairs(modes) do best = math.max(best, c[m] or 0) end
	local tied = {}
	for _, m in ipairs(modes) do if (c[m] or 0) == best then table.insert(tied, m) end end
	local how = best == 0 and "none" or (#tied == 1 and "most" or "tie")
	local pool = tied
	if #tied > 1 and MV.last then
		pool = {}
		for _, m in ipairs(tied) do if m ~= MV.last then table.insert(pool, m) end end
		if #pool == 0 then pool = tied end
	end
	local w = pool[#pool == 1 and 1 or rng:NextInteger(1, #pool)]
	local parts = {}
	for _, m in ipairs(modes) do table.insert(parts, m .. "=" .. tostring(c[m] or 0)) end
	script:SetAttribute("PgVoteLast", ("%s %s %s"):format(w, how, table.concat(parts, ",")))
	return w
end
function MV.sync()
	set("PgVoteModes", table.concat(MV.modes(), ","))
	set("PgVotes", HttpService:JSONEncode(MV.counts()))
	set("PgVoteWinner", MV.winner or "")
	set("PgVoteHumans", #humans)
	set("PgVoteSecs", tonumber(script:GetAttribute("PgVoteSecs")) or 15)
end
function MV.reset()
	MV.by, MV.endsAt, MV.winner, MV.flashEnds, MV.done = {}, nil, nil, nil, false
	for _, pl in ipairs(Players:GetPlayers()) do if pl:GetAttribute("PgVote") ~= nil then pl:SetAttribute("PgVote", nil) end end
	MV.sync()
end
'''))
a = '\t\tset("PgEndsAt", lineup and (pgIntroEnds or state:GetAttribute("PrStartAt") or 0) or 0)\n'
P.append((a, a + '''		if lineup and MV.active() then -- v1.17: the vote screen comes first
			set("PgPhase", "vote")
			set("PgEndsAt", MV.winner and now() or MV.endsAt)
			MV.sync()
		end
'''))
a = '\tlocal ok, r = pcall(function() return hpFn:Invoke("start", lead) end)\n'
P.append((a, '\tset("PrMode", MV.mode) -- v1.17\n\tlocal ok, r = pcall(function() return hpFn:Invoke("start", lead, MV.mode) end) -- v1.17: + the mode\n'))
a = '\tbotRecs = {}\n\tphase = "lobby"\n\tset("PrResult", result or "")\n'
P.append((a, a + '\tMV.last = MV.mode -- v1.17: the next lobby votes again\n\tMV.reset()\n'))
a = '-- ---------- the loop ----------\n'
P.append((a, '''-- v1.17: the mode vote remote (see the header)
MV.remote = ReplicatedStorage:FindFirstChild("ModeVote")
if not MV.remote then
	MV.remote = Instance.new("RemoteEvent")
	MV.remote.Name = "ModeVote"
	MV.remote.Parent = ReplicatedStorage
end
MV.remote.OnServerEvent:Connect(function(pl, mode)
	local r
	if os.clock() - (MV.lastReq[pl] or 0) < 0.15 then
		r = "busy"
	elseif not MV.active() or MV.winner then
		r = "closed"
	elseif not humanIndex(pl) then
		r = "notInLobby"
	elseif type(mode) ~= "string" or not table.find(MV.modes(), mode) then
		r = "badArg"
	else
		MV.by[pl.UserId] = mode
		pl:SetAttribute("PgVote", mode)
		MV.sync()
		r = "ok"
	end
	MV.lastReq[pl] = os.clock()
	pl:SetAttribute("PgVoteResult", r)
end)
Players.PlayerRemoving:Connect(function(pl) MV.lastReq[pl] = nil end)

''' + a))
a = '\t\tif pgOn() then -- v1.9: lineup -> intro -> match\n\t\t\tset("PgEndsAt", pgIntroEnds or at)\n'
P.append((a, '''		if pgOn() and MV.on() and not MV.done and not pgIntroEnds then -- v1.17: the mode vote comes first
			if #humans == 0 then
				if MV.endsAt then MV.reset() publish() end
				return
			end
			if not MV.endsAt then
				MV.endsAt = now() + (tonumber(script:GetAttribute("PgVoteSecs")) or 15)
				publish()
			end
			if not MV.winner and (now() >= MV.endsAt or MV.allIn()) then
				MV.winner = MV.pick(MV.counts())
				MV.flashEnds = now() + (tonumber(script:GetAttribute("PgVoteFlash")) or 1)
				MV.mode = MV.winner
				set("PrMode", MV.mode)
				publish()
			end
			if MV.winner and now() >= MV.flashEnds then
				MV.done = true
				at = now() + autoStart()
				set("PrStartAt", at)
				publish()
			else
				local hold = (MV.flashEnds or (MV.endsAt + 1)) + autoStart()
				if state:GetAttribute("PrStartAt") ~= hold then set("PrStartAt", hold) end
				return
			end
		end
''' + a))
a = 'pointTime = H.POINT_TIME, now = os.clock()})\n'
P.append((a, a + '''				if MV.mode == "tdm" and get("PrTdmBotsHuntEnabled") ~= false then -- v1.17: TDM bots hunt
					for _, e in pairs(res) do e.job, e.why = "duel", "tdm" end
				end
'''))
JOBS["PracticeServer"] = ("src/server/PracticeServer/init.server.luau", SSS + "PracticeServer", P)

# ---------------- HardpointHUD 1.16 ----------------
U = []
a = 'VERSION = "1.15" -- v1.15 filler bot personas drawn as players\n'
U.append((a, a + '''VERSION = "1.16" -- v1.16 Team Deathmatch HUD
-- v1.16 (Team Deathmatch, ''' + Q + '''): while ReplicatedStorage.Hardpoint HpMode == "tdm" (HardpointServer 1.12) and script
--   attribute HardpointHUDTdmEnabled ~= false (read per frame):
--   * the score card's bars fill toward HpTdmLimit (30) kills; the line under the clock reads "FIRST TO 30" ("STARTS IN m:ss" in
--     the warm-up); the status pill "TEAM DEATHMATCH · +1 PER KILL" ("GET READY" in the warm-up). The NEXT pill, the point marker
--     (and its v3 look), the compass and the phone v2 strip are hidden (the phone shows the card).
--   * the boards: the sub line gets " · TEAM DEATHMATCH" (e.g. "ARENA · TEAM DEATHMATCH"), the on-point column is empty (header
--     and cells), the MVP / SVP cards read "<k> K   <d> D".
'''))
a = 'local function mss(s) s = math.max(0, math.floor((tonumber(s) or 0) + 0.5)) return ("%d:%02d"):format(s // 60, s % 60) end\n'
U.append((a, a + '''local TD = {} -- v1.16: Team Deathmatch (see the header)
function TD.on() return state:GetAttribute("HpMode") == "tdm" and script:GetAttribute("HardpointHUDTdmEnabled") ~= false end
function TD.limit() return tonumber(state:GetAttribute("HpTdmLimit")) or 30 end
'''))
a = '\tif arenaLabel(pr) then bSub.Text = "ARENA" end -- v1.12\n'
U.append((a, a + '\tif TD.on() then bSub.Text = bSub.Text .. " · TEAM DEATHMATCH" end -- v1.16\n'))
a = '\t\tT[0][2].Text, T[0][3].Text, T[0][4].Text, T[0][5].Text = "Dino", "K", "D", "On point"\n'
U.append((a, a + '\t\tif TD.on() then T[0][5].Text = "" end -- v1.16\n'))
a = '\t\t\t\tcells[3].Text, cells[4].Text, cells[5].Text = tostring(r.k or 0), tostring(r.d or 0), mss(r.pt)\n'
U.append((a, a + '\t\t\t\tif TD.on() then cells[5].Text = "" end -- v1.16\n'))
a = '\t\t\t\tpk.col:ToHex(), mss(r.pt))\n'
U.append((a, a + '''			if TD.on() then -- v1.16
				c.stats.Text = ('<font color="#%s">%d</font> K   <font color="#%s">%d</font> D'):format(pk.col:ToHex(), r.k or 0,
					pk.col:ToHex(), r.d or 0)
			end
'''))
a = '\t\tbTables[t][0][5].Text = "ON PT"\n'
U.append((a, a + '\t\tif TD.on() then bTables[t][0][5].Text = "" end -- v1.16\n'))
a = '\t\tif arenaLabel(pr) then ebSub.Text = "ARENA" end -- v1.12\n'
U.append((a, a + '\t\tif TD.on() then ebSub.Text = ebSub.Text .. " · TEAM DEATHMATCH" end -- v1.16\n'))
a = '\tlocal limit = H and H.LIMIT or 250\n'
U.append((a, a + '\tif TD.on() then limit = TD.limit() end -- v1.16\n'))
a = '\tresults.Visible = false\n\tstatus.Visible = true\n\tlocal warm = phase == "warmup"\n'
U.append((a, a + '''	if TD.on() then -- v1.16: no point in Team Deathmatch
		pointL.Text = warm and ("STARTS IN " .. fmt(remaining)) or ("FIRST TO %d"):format(TD.limit())
		status.Text, status.TextColor3 = warm and "GET READY" or "TEAM DEATHMATCH · +1 PER KILL", Color3.new(1, 1, 1)
		nextL.Visible = false
		marker.Visible = false
		mv3Off()
		cmp.Visible, cmpUnder.Visible = false, false
		if v2hid then card.Visible = true v2hid = false end
		script:SetAttribute("HardpointHUDState", "tdm")
		return
	end
'''))
JOBS["HardpointHUD"] = ("src/client/HardpointHUD.client.luau", SPS + "HardpointHUD", U)

# ---------------- PrematchCountdown 1.2 ----------------
C = []
a = 'VERSION = "1.1" -- v1.1 chip follows the camera fly-over\n'
C.append((a, a + '''VERSION = "1.2" -- v1.2 Team Deathmatch texts
-- v1.2 (Team Deathmatch, ''' + Q + '''): while ReplicatedStorage.Hardpoint HpMode == "tdm" and script attribute
--   PrematchTdmEnabled ~= false (read per frame): TEAM DEATHMATCH / TAKE DOWN THE OTHER TEAM / FIRST TEAM TO <HpTdmLimit> KILLS ·
--   <HpClock / 60> MIN; the FIRST POINT pill is hidden. Hardpoint: the 1.1 texts.
'''))
a = '\tfor _, l in ipairs({mode, obj, how, begins, pill, held}) do l.Visible = not showGo end\n'
C.append((a, a + '''	local tdm = hp:GetAttribute("HpMode") == "tdm" and script:GetAttribute("PrematchTdmEnabled") ~= false -- v1.2
	local mt = tdm and "TEAM DEATHMATCH" or "HARDPOINT"
	if mode.Text ~= mt then
		mode.Text = mt
		obj.Text = tdm and "TAKE DOWN THE OTHER TEAM" or "CAPTURE AND HOLD THE HARDPOINT"
		how.Text = tdm and ("FIRST TEAM TO %d KILLS · %d MIN"):format(tonumber(hp:GetAttribute("HpTdmLimit")) or 30,
			math.floor((tonumber(hp:GetAttribute("HpClock")) or 600) / 60 + 0.5))
			or ("+1 PER SECOND PER DINO ON THE POINT · FIRST TO %d"):format(LIMIT)
	end
	if tdm then pill.Visible = false end
'''))
JOBS["PrematchCountdown"] = ("src/client/PrematchCountdown.client.luau", SPS + "PrematchCountdown", C)

# ---------------- PregameScreen 1.10 ----------------
G = []
a = 'VERSION = "1.9" -- v1.9 island pick back to the Lab\n'
G.append((a, a + '''VERSION = "1.10" -- v1.10 Team Deathmatch titles
-- v1.10 (Team Deathmatch, ''' + Q + '''): while ReplicatedStorage.Practice PrMode == "tdm" (PracticeServer 1.17) and script
--   attribute PregameModeLineEnabled ~= false (read per draw): the lineup / select sub line starts "TEAM DEATHMATCH" (mockup:
--   "TEAM DEATHMATCH · BLUE TEAM") and the intro's VS line reads "TAKE DOWN THE OTHER TEAM". Hardpoint: as 1.9.
'''))
a = 'local function modeLine()\n\tif state:GetAttribute("PrArena") == true then return "ARENA · HARDPOINT" end -- v1.1\n'
G.append((a, '''local function modeLine()
	if state:GetAttribute("PrMode") == "tdm" and script:GetAttribute("PregameModeLineEnabled") ~= false then return "TEAM DEATHMATCH" end -- v1.10
	if state:GetAttribute("PrArena") == true then return "ARENA · HARDPOINT" end -- v1.1
'''))
a = '\telseif pgPhase == "intro" then\n\t\tif view ~= "intro" then setGhost(nil) setView("intro") sig = "" end\n'
G.append((a, a + '''		vsGo.Text = (state:GetAttribute("PrMode") == "tdm" and script:GetAttribute("PregameModeLineEnabled") ~= false) -- v1.10
			and "TAKE DOWN THE OTHER TEAM" or "CAPTURE AND HOLD THE HARDPOINT"
'''))
JOBS["PregameScreen"] = ("src/client/PregameScreen.client.luau", SPS + "PregameScreen", G)

# ---------------- HardpointPointFX 1.1 ----------------
F = []
a = 'local VERSION = "1.0"\nscript:SetAttribute("HardpointPointFXVersion", VERSION)\n'
F.append((a, '''local VERSION = "1.0"
VERSION = "1.1" -- v1.1 no point in Team Deathmatch
-- v1.1 (Team Deathmatch, ''' + Q + '''): nothing is drawn while ReplicatedStorage.Hardpoint HpMode == "tdm"
--   (HardpointServer 1.12; the hidden point only places spawns). Switch: script attribute HardpointPointFXTdmHideEnabled
--   (default true, read per refresh).
script:SetAttribute("HardpointPointFXVersion", VERSION)
'''))
a = '\tlocal on = script:GetAttribute("HardpointPointFXEnabled") ~= false and state:GetAttribute("HpLive") == true\n\t\tand player:GetAttribute("InMenu") ~= true\n'
F.append((a, a + '\tif on and state:GetAttribute("HpMode") == "tdm" and script:GetAttribute("HardpointPointFXTdmHideEnabled") ~= false then on = false end -- v1.1\n'))
JOBS["HardpointPointFX"] = ("src/client/HardpointPointFX.client.luau", SPS + "HardpointPointFX", F)

# ---------------- GameSounds 1.22 ----------------
N = []
a = 'VERSION = "1.21" -- v1.21 the Troodon\'s buttons on their beats (round 20 picks)\n'
N.append((a, a + '''VERSION = "1.22" -- v1.22 no point lines in Team Deathmatch
-- v1.22 (Team Deathmatch, ''' + Q + '''): while ReplicatedStorage.Hardpoint HpMode == "tdm" and script attribute
--   GameSoundsTdmQuietEnabled ~= false (read per check), the intro line (vointro1 / vointro2 talk about the hardpoint) and the
--   "moving" warning are not played. Every other sound as 1.21.
'''))
a = '\t\tif ph == "warmup" and introFor ~= ends and script:GetAttribute("GameSoundsIntroEnabled") ~= false -- v1.17 the intro line\n'
N.append((a, a + '\t\t\tand not (hp:GetAttribute("HpMode") == "tdm" and script:GetAttribute("GameSoundsTdmQuietEnabled") ~= false) -- v1.22\n'))
a = '\t\tif ph == "live" then\n\t\t\tlocal idx = hp:GetAttribute("HpIndex")\n'
N.append((a, '\t\tif ph == "live" and not (hp:GetAttribute("HpMode") == "tdm" and script:GetAttribute("GameSoundsTdmQuietEnabled") ~= false) then -- v1.22: + not TDM\n\t\t\tlocal idx = hp:GetAttribute("HpIndex")\n'))
JOBS["GameSounds"] = ("src/client/GameSounds.client.luau", SPS + "GameSounds", N)

# ---------------- PracticeLobby 1.9 ----------------
L = []
a = 'VERSION = "1.8" -- v1.8 no park while the arrival loader is up\n'
L.append((a, a + '''VERSION = "1.9" -- v1.9 hidden while the vote screen shows
-- v1.9 (Arena modes, ''' + Q + '''): also hidden while ReplicatedStorage.Practice PgPhase == "vote" and the VoteScreen
--   LocalScript is there with VoteScreenEnabled ~= false. Switch: script attribute PracticeLobbyVoteHide (default true, per frame).
'''))
a = '\t\tif (ph == "lineup" or ph == "intro") and ps and ps:GetAttribute("PregameScreenEnabled") ~= false then show = false end\n'
L.append((a, a + '''		local vs = script.Parent and script.Parent:FindFirstChild("VoteScreen") -- v1.9
		if ph == "vote" and vs and vs:GetAttribute("VoteScreenEnabled") ~= false and script:GetAttribute("PracticeLobbyVoteHide") ~= false then show = false end
'''))
JOBS["PracticeLobby"] = ("src/client/PracticeLobby.client.luau", SPS + "PracticeLobby", L)
