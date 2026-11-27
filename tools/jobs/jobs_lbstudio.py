"""LeaderboardServer 1.3 (Kepu 2026-11-27 12:53, phone screenshot: the WORLDWIDE board shows "#1 YOU 12W" while his record is
0W 0L "when I haven't played a single match"). The live store MDA_ArenaWins_v2 held one key, his own (u8595585713 = 12), while
his Arena record (MDA_ArenaRecord_v3) is empty: the board copies the ArenaW attribute from any server, Studio playtests included,
and LbSaveEnabled was never one of the test switches. Now a Studio server never writes the wins store unless
LbStudioSaveEnabled == true (reads still work). Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_lbstudio.py"""
SSS = 'game:GetService("ServerScriptService").'
JOBS = {}
L = []
a = '''local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
'''
L.append((a, '''-- v1.3 (Kepu 2026-11-27 12:53: the WORLDWIDE board read "#1 YOU 12W" with a 0W 0L record and no match played; the store held
--   his own key = 12, written from a Studio playtest's ArenaW): in Studio (RunService:IsStudio()) the wins store is never
--   written unless script attribute LbStudioSaveEnabled == true (default false, read per write); fetches still run.
--   Diagnostic: LbLast "studio skip <name> <w>", LbStudioSkips (count).
''' + a))
a = 'VERSION = "1.2" -- v1.2 launch reset\n'
L.append((a, a + 'VERSION = "1.3" -- v1.3 no wins writes from Studio\n'))
a = '''	if type(w) ~= "number" or w <= 0 or written[p.UserId] == w then return end
'''
L.append((a, a + '''	if RunService:IsStudio() and script:GetAttribute("LbStudioSaveEnabled") ~= true then -- v1.3: Studio never writes the live board
		script:SetAttribute("LbStudioSkips", (script:GetAttribute("LbStudioSkips") or 0) + 1)
		script:SetAttribute("LbLast", ("studio skip %s %d"):format(p.Name, w))
		return
	end
'''))
JOBS["LeaderboardServer"] = ("src/server/LeaderboardServer.server.luau", SSS + "LeaderboardServer", L)
