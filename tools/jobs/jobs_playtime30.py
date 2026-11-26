"""Playtime track capped at 30 min (Kepu 2026-11-26 16:44). Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_playtime30.py"""
Q = 'Kepu 2026-11-26 16:44 "Nah this is too crazy, cap out at 30 minutes to get the overtime skin"; points spread: standing pick, recommended'
SSS = 'game:GetService("ServerScriptService").'
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
SS = 'game:GetService("ServerStorage").DinoArcade.'
JOBS = {}
S = []
a = 'local VERSION = "1.0"\nscript:SetAttribute("PlaytimeServerVersion", VERSION)\n'
S.append((a, '''local VERSION = "1.0"
VERSION = "1.1" -- v1.1 track capped at 30 min
-- v1.1 (''' + Q + '''): TRACK = 300 +1 pt, 600 +1 pt, 900 +1 pt, 1200 +2 pts, 1500 +2 pts, 1800 the Overtime skin (3 pts if owned).
--   Switch: script attribute PlaytimeShortTrackEnabled (true, read at start; false = the 1.0 60 min track). Claimed flags keep their
--   slot numbers (6 rewards either way).
script:SetAttribute("PlaytimeServerVersion", VERSION)
'''))
a = '\t{t = 3600, skin = "overtime", alt = 3}}\n'
S.append((a, a + '''if script:GetAttribute("PlaytimeShortTrackEnabled") == nil then script:SetAttribute("PlaytimeShortTrackEnabled", true) end -- v1.1
if script:GetAttribute("PlaytimeShortTrackEnabled") ~= false then
	TRACK = {{t = 300, pts = 1}, {t = 600, pts = 1}, {t = 900, pts = 1}, {t = 1200, pts = 2}, {t = 1500, pts = 2},
		{t = 1800, skin = "overtime", alt = 3}}
end
'''))
JOBS["PlaytimeServer"] = ("src/server/PlaytimeServer.server.luau", SSS + "PlaytimeServer", S)
C = []
a = 'local VERSION = "1.0"\nscript:SetAttribute("PlaytimeClientVersion", VERSION)\n'
C.append((a, '''local VERSION = "1.0"
VERSION = "1.1" -- v1.1 track capped at 30 min
-- v1.1 (''' + Q + '''): the cards follow PlaytimeServer 1.1: 5 / 10 / 15 MIN +1 PT, 20 / 25 MIN +2 PTS, 30 MIN OVERTIME SKIN.
--   Switch: script attribute PlaytimeShortTrackEnabled (true, read at start; false = the 1.0 cards). Layout unchanged.
script:SetAttribute("PlaytimeClientVersion", VERSION)
'''))
a = '\t{t = 2700, txt = "+3 PTS"}, {t = 3600, txt = "OVERTIME SKIN"}}\n'
C.append((a, a + '''if script:GetAttribute("PlaytimeShortTrackEnabled") == nil then script:SetAttribute("PlaytimeShortTrackEnabled", true) end -- v1.1
if script:GetAttribute("PlaytimeShortTrackEnabled") ~= false then
	TRACK = {{t = 300, txt = "+1 PT"}, {t = 600, txt = "+1 PT"}, {t = 900, txt = "+1 PT"}, {t = 1200, txt = "+2 PTS"},
		{t = 1500, txt = "+2 PTS"}, {t = 1800, txt = "OVERTIME SKIN"}}
end
'''))
JOBS["PlaytimeClient"] = ("src/client/PlaytimeClient.client.luau", SPS + "PlaytimeClient", C)
U = []
a = 'US.PLAYTIME_SKIN = true -- v1.7\n'
U.append((a, a + '''US.VERSION = "1.8" -- v1.8 Overtime at 30 min
-- v1.8 (''' + Q + '''): Overtime's need is US.PLAYTIME_NEED minutes (30; PlaytimeServer 1.1 grants it at 30 min) and its text says
--   30 minutes. Switch: set US.PLAYTIME_NEED = 60 for the 1.7 numbers.
US.PLAYTIME_NEED = 30 -- v1.8
'''))
a = '\t\tunlock = {kind = "earn", stat = "playtime", need = 60, claim = "playtime", text = "Play 60 minutes in one session, then claim it from the gift at the top"},\n'
U.append((a, '\t\tunlock = {kind = "earn", stat = "playtime", need = US.PLAYTIME_NEED, claim = "playtime", -- v1.8: need / text follow US.PLAYTIME_NEED\n'
             '\t\t\ttext = "Play " .. US.PLAYTIME_NEED .. " minutes in one session, then claim it from the gift at the top"},\n'))
JOBS["UniversalSkins"] = ("src/shared/UniversalSkins.luau", SS + "UniversalSkins", U)
