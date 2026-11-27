"""Arena modes step 1, Studio test fix 2 (same version, not yet published): a kill in the warm-up went on the board but not on
the team score (bots-match test: board B kills 3, HpScoreB 2). A TDM kill now scores in the warm-up too (any phase but the results),
so the team score always equals the board's kills. Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_tdm3.py"""
SSS = 'game:GetService("ServerScriptService").'
JOBS = {}
S = []
a = '''		if f == "k" and match.mode == "tdm" and match.phase == "live" and (c == "A" or c == "B") -- v1.12: a kill scores
'''
S.append((a, '''		if f == "k" and match.mode == "tdm" and match.phase ~= "results" and (c == "A" or c == "B") -- v1.12: a kill scores
'''))
a = '''--     The practice hook's "stat" field "k" with team "A" / "B" while the match is live adds 1 to that team's score (HpScoreA /
'''
S.append((a, '''--     The practice hook's "stat" field "k" with team "A" / "B" (warm-up or live; not in the results) adds 1 to that team's score
--     (HpScoreA /
'''))
JOBS["HardpointServer"] = ("src/server/HardpointServer.server.luau", SSS + "HardpointServer", S)
