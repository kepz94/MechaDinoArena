"""QuestRules 1.1 fix before publish (Studio check 2026-11-27): POOL.istreak starts with nil (no easy streak quest), so ipairs stopped
at once and the streak texts kept "on the island". Loop 1..3 instead. Run: python3 -I tools/launch_patch.py <outdir> <this file>"""
DA = 'game:GetService("ServerStorage").DinoArcade.'
JOBS = {}
R = []
a = '''	for _, q in ipairs(M.POOL.ikills) do q.text = ("Get %d kills anywhere"):format(q.need) end
	for _, q in ipairs(M.POOL.istreak) do q.text = ("Reach a %d kill streak"):format(q.need) end
'''
R.append((a, '''	for d = 1, 3 do -- the pools may start with nil (no easy quest of that kind)
		local q = M.POOL.ikills[d]
		if q then q.text = ("Get %d kills anywhere"):format(q.need) end
		q = M.POOL.istreak[d]
		if q then q.text = ("Reach a %d kill streak"):format(q.need) end
	end
'''))
JOBS["QuestRules"] = ("src/shared/QuestRules.luau", DA + "QuestRules", R)
