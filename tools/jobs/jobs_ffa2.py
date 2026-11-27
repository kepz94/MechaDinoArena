"""Free for All, Studio test fixes (same versions, not yet published):
1. MatchAwards and VictoryTitles only know seats "A" / "B": the FFA top 3 are now seat "A" (winner "A") for them, the rest "B"
   (test: 3rd place got 0 win XP and 0 kill XP with "W" / "L").
2. PracticeServer: any Arena result of a FFA match is placed by HpFfaPlaces (not only when the winner reads "ffa" / "W").
3. PregameScreen: the plaques' record line size raced FontSwap on the new columns (bots' "ELITE BOT" drawn at the human size);
   the size is set again 0.1 s after a FFA refresh, so FontSwap fits the right size.
Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_ffa2.py"""
SSS = 'game:GetService("ServerScriptService").'
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}
S = []
a = '''--     "ffa"; inside, match.winner = "W" and the top HpFfaTopWin (3) are team "W" for the titles (VictoryTitles.assign) and the
--     awards (MatchAwards.compute: win XP), the rest "L" (HpFfaTitlesEnabled ~= false, read per results).
'''
S.append((a, '''--     "ffa"; inside, match.winner = "A" and the top HpFfaTopWin (3) are seat "A" for the titles (VictoryTitles.assign) and the
--     awards (MatchAwards.compute: kill / win XP, MVP among them, SVP among the rest), the rest seat "B" (both modules only know
--     "A" / "B"); titles only while HpFfaTitlesEnabled ~= false (read per results).
'''))
a = '''	local ffaW = m.mode == "ffa" and m.winner == "W" and script:GetAttribute("HpFfaTitlesEnabled") ~= false -- v1.13: the top 3 win
	if m.winner ~= "A" and m.winner ~= "B" and not ffaW then script:SetAttribute("HpTitlesLast", "draw") return 0 end -- v1.13: + not ffaW
'''
S.append((a, '''	if m.mode == "ffa" and script:GetAttribute("HpFfaTitlesEnabled") == false then script:SetAttribute("HpTitlesLast", "ffaOff") return 0 end -- v1.13
	if m.winner ~= "A" and m.winner ~= "B" then script:SetAttribute("HpTitlesLast", "draw") return 0 end
'''))
a = '''	if m.mode == "ffa" then -- v1.13: the top 3 are team "W"
		for _, x in ipairs(rows) do x.team = (m.topSet and m.topSet[x.id]) and "W" or "L" end
	end
'''
S.append((a, '''	if m.mode == "ffa" then -- v1.13: the top 3 are seat "A" (the winner), the rest "B"
		for _, x in ipairs(rows) do x.team = (m.topSet and m.topSet[x.id]) and "A" or "B" end
	end
'''))
a = '''	if m.mode == "ffa" then -- v1.13: the top 3 get the win XP
		for _, x in ipairs(rows) do x.team = (m.topSet and m.topSet[x.id]) and "W" or "L" end
	end
'''
S.append((a, '''	if m.mode == "ffa" then -- v1.13: the top 3 get the win XP (seat "A" = the winner), the rest "B"
		for _, x in ipairs(rows) do x.team = (m.topSet and m.topSet[x.id]) and "A" or "B" end
	end
'''))
a = '\t\t\tmatch.winner = "W"\n'
S.append((a, '\t\t\tmatch.winner = "A" -- the top 3 (seat "A" for titles / awards)\n'))
JOBS["HardpointServer"] = ("src/server/HardpointServer.server.luau", SSS + "HardpointServer", S)
P = []
a = '\tif (w == "ffa" or w == "W") and MV.mode == "ffa" then -- v1.18: Free for All: the top 3 win\n'
P.append((a, '\tif MV.mode == "ffa" then -- v1.18: Free for All: the top 3 win\n'))
a = '''--   stay the two groups of 4. FFA bots: every job "duel" (why "ffa"; PrFfaBotsHuntEnabled ~= false). Arena result: HpWinner "ffa"
--   (or "W"): each human is team "W" when placed in the top HpFfaTopWin (3) of HpFfaPlaces, else "L", and the winner is "W".
'''
P.append((a, '''--   stay the two groups of 4. FFA bots: every job "duel" (why "ffa"; PrFfaBotsHuntEnabled ~= false). Arena result of a FFA match
--   (PrMode "ffa"): each human is team "W" when placed in the top HpFfaTopWin (3) of HpFfaPlaces, else "L", and the winner is "W".
'''))
JOBS["PracticeServer"] = ("src/server/PracticeServer/init.server.luau", SSS + "PracticeServer", P)
G = []
a = '''			allReadyLbl.Visible = allReady
		end
		return ph
'''
G.append((a, '''			allReadyLbl.Visible = allReady
			task.delay(0.1, function() -- the record line's size again, after FontSwap's first fit (it raced on the new columns)
				for i, col in ipairs(cols) do
					local e2 = all[i]
					if e2 and col.wl.Text ~= "" then col.wl.TextSize = ((e2.kind == "bot" and not isPersona(e2)) and 11 or 16.5) * TF end
				end
			end)
		end
		return ph
'''))
JOBS["PregameScreen"] = ("src/client/PregameScreen.client.luau", SPS + "PregameScreen", G)
