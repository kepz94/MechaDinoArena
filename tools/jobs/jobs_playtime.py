"""Playtime rewards (Kepu 2026-11-26 16:31 / 16:35 "A"). Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_playtime.py"""
Q = ('Kepu 2026-11-26 16:31 "play time rewards ... skill points and a skin the longer you play in a session"; mockup '
     'docs/mockups/playtime_rewards_v0.1.html, 16:35 pick "A"; skin Overtime: standing pick, recommended')
SS = 'game:GetService("ServerStorage").DinoArcade.'
JOBS = {}
U = []
a = 'US.HOLIDAY_FROM, US.HOLIDAY_TO = 1796083200, 1798761600 -- v1.6: 2026-12-01 .. 2027-01-01 00:00 UTC\n'
U.append((a, a + '''US.VERSION = "1.7" -- v1.7 Overtime (playtime skin)
-- v1.7 (''' + Q + '''): new skin Overtime (black, glowing gold bands; Studio render on the mockup), unlock {kind "earn", stat
--   "playtime", need 60 (minutes in one session), claim "playtime"}: PlaytimeServer 1.0 grants it through SkinGrant from the 60 min
--   reward; SkinServer never grants it by itself (progress on the server is 0). progress() for stat "playtime" = stats.playtime (s) or,
--   on a client, the local player's PlaytimeBase + time since PlaytimeAt, in whole minutes (the Lab tile shows n / 60). ORDER: after
--   Holiday Lights. EggRules 1.2 keeps it out of the Favorite Egg. Switch: US.PLAYTIME_SKIN (true; false = 1.6).
US.PLAYTIME_SKIN = true -- v1.7
'''))
a = 'function US.windowOpen(sk, now) -- v1.6: true when the skin has no window or it is open\n'
U.append((a, '''-- v1.7: the playtime skin (see the header)
function US.playtimeSecs()
	local RS = game:GetService("RunService")
	if not RS:IsClient() then return 0 end
	local p = game:GetService("Players").LocalPlayer
	if not p then return 0 end
	local base = tonumber(p:GetAttribute("PlaytimeBase")) or 0
	local at = tonumber(p:GetAttribute("PlaytimeAt"))
	return at and base + math.max(0, workspace:GetServerTimeNow() - at) or base
end
if US.PLAYTIME_SKIN then
	US.SKINS.overtime = {name = "Overtime",
		unlock = {kind = "earn", stat = "playtime", need = 60, claim = "playtime", text = "Play 60 minutes in one session, then claim it from the gift at the top"},
		cols = {belly = "2A2A30", claws = "0A0A0C", eyes = "FFC832", accent = "FFC832", mask = "0E0E10"}, mats = {eyes = "Neon", accent = "Neon"},
		sw = {"141416", "FFC832", "2A2A30"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			if frac(lp.Z / 1.2) < 0.24 then return "FFC832", "Neon" end
			return pick({"141416", "1C1C20", "0E0E10"}, cell(lp, 1.0, 151))
		end}
	local at = table.find(US.ORDER, "holidaylights") or table.find(US.ORDER, "inkwar") or #US.ORDER
	table.insert(US.ORDER, at + 1, "overtime")
end
''' + a))
a = '\telseif s == "istreak" then have = tonumber(stats.istreak) or 0 end -- v1.4\n'
U.append((a, '\telseif s == "istreak" then have = tonumber(stats.istreak) or 0 -- v1.4\n'
             '\telseif s == "playtime" then have = math.floor((tonumber(stats.playtime) or US.playtimeSecs()) / 60) end -- v1.7\n'))
JOBS["UniversalSkins"] = ("src/shared/UniversalSkins.luau", SS + "UniversalSkins", U)
E = []
a = 'M.EXCLUDE_HOLIDAY = true\n'
E.append((a, a + '''M.VERSION = "1.2" -- v1.2 (''' + Q + '''): Overtime (UniversalSkins 1.7, the 60 min playtime reward) is never an egg prize.
-- Switch: M.EXCLUDE_PLAYTIME (true; false = 1.1).
M.EXCLUDE_PLAYTIME = true
if M.EXCLUDE_PLAYTIME then M.EXCLUDE.skin.overtime = true end
'''))
JOBS["EggRules"] = ("src/shared/EggRules.luau", SS + "EggRules", E)
