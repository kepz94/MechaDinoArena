"""Arena modes step 1, Studio test fixes (same versions, not yet published): kills past the limit in one tick no longer
overshoot the score (33-24 seen); the score card's under-clock line follows the mockup ("/ 30") and the warm-up line fits the card
("GO IN 0:15"; "STARTS IN 0:15" ran past the card edge). Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_tdm2.py"""
SSS = 'game:GetService("ServerScriptService").'
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}
S = []
a = '''		if f == "k" and match.mode == "tdm" and match.phase == "live" and (c == "A" or c == "B") then -- v1.12: a kill scores
			if c == "A" then match.state.scoreA += 1 else match.state.scoreB += 1 end
		end
'''
S.append((a, '''		local lim = tonumber(script:GetAttribute("HpTdmLimit")) or 30
		if f == "k" and match.mode == "tdm" and match.phase == "live" and (c == "A" or c == "B") -- v1.12: a kill scores
			and match.state.scoreA < lim and match.state.scoreB < lim then -- (none past the limit; the tick ends the match)
			if c == "A" then match.state.scoreA += 1 else match.state.scoreB += 1 end
		end
'''))
a = '''--     HpScoreB = team kills). Winner: a team at HpTdmLimit kills, or the clock at 0: more kills wins, equal = "draw". Then the
'''
S.append((a, '''--     HpScoreB = team kills; no kill counts once a team is at HpTdmLimit). Winner: a team at HpTdmLimit kills, or the clock at
--     0: more kills wins, equal = "draw". Then the
'''))
JOBS["HardpointServer"] = ("src/server/HardpointServer.server.luau", SSS + "HardpointServer", S)
U = []
a = '''		pointL.Text = warm and ("STARTS IN " .. fmt(remaining)) or ("FIRST TO %d"):format(TD.limit())
'''
U.append((a, '''		pointL.Text = warm and ("GO IN " .. fmt(remaining)) or ("/ %d"):format(TD.limit())
'''))
a = '''--   * the score card's bars fill toward HpTdmLimit (30) kills; the line under the clock reads "FIRST TO 30" ("STARTS IN m:ss" in
--     the warm-up)'''
U.append((a, '''--   * the score card's bars fill toward HpTdmLimit (30) kills; the line under the clock reads "/ 30" next to the other team's
--     kills (mockup "14 / 30"; "GO IN m:ss" in the warm-up)'''))
JOBS["HardpointHUD"] = ("src/client/HardpointHUD.client.luau", SPS + "HardpointHUD", U)
