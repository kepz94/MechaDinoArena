"""Kepu 2026-11-27 14:41: "The play button being constantly there and the list being constantly open is annoying especially when I
played my first match and it didn't check off on the list ... Remove the play button have the list actually be meaningful shit that
actually checks off".
Root cause of the missed check (Studio Arena test, ArenaRecordStoreName test store): a Free for All Arena match reports
winner "W" and teams "W" / "L" to ArenaRecordServer (PracticeServer 1.18), but ArenaRecordRules.outcome only knows "A" / "B", so the
record is never written: no ArenaW / ArenaL rise, so no W-L, no leaderboard, no "Play an Arena match" quest, no First Steps 1 / 4.
(MatchAwards / VictoryTitles got the same A / B fix in HardpointServer 1.13; PracticeServer's report was missed.)
* PracticeServer 1.19: the FFA report uses seat "A" (top 3, the winner) / "B" (the rest), winner "A", no leaver sides.
* FirstSteps 1.1: the card starts folded to one line (tap to open); the toast shows on every server kind (the Arena match server
  too). The PLAY button is switched off with the 1.0 switch FirstStepsPlayEnabled = false (script attribute, set in Edit).
Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_fsfix.py"""
SSS = 'game:GetService("ServerScriptService").'
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}

P = []
a = 'VERSION = "1.18" -- v1.18 Free for All\n'
P.append((a, a + '''VERSION = "1.19" -- v1.19 FFA Arena result as seats A / B
-- v1.19 (Kepu 2026-11-27 14:41 "I played my first match and it didn't check off on the list"; Studio Arena test: the FFA report sent
--   winner "W" and teams "W" / "L", and ArenaRecordRules.outcome only knows "A" / "B", so no record was written and ArenaW / ArenaL
--   never rose): while script attribute PrFfaRecordSeatsEnabled ~= false (default true, read per result) a Free for All Arena result
--   reports the top HpFfaTopWin (3) of HpFfaPlaces as team "A" and the rest as "B", winner "A", and no leaver sides (a leaver's
--   own "left" report still counts). Diagnostic: PrArenaResult reads "A ffa <hook result>". false = 1.18.
'''))
a = '''		for _, e in ipairs(list) do
			local p = place["u" .. e.player.UserId]
			e.team = (p and p <= top) and "W" or "L"
		end
		w = "W"
	end
	local r = arenaReport("result", arena.matchId, list, w, elig, {A = arena.leavers.A, B = arena.leavers.B})
	script:SetAttribute("PrArenaResult", tostring(w) .. " " .. tostring(r))
'''
P.append((a, '''		local seats = script:GetAttribute("PrFfaRecordSeatsEnabled") ~= false -- v1.19: ArenaRecordRules only knows "A" / "B"
		for _, e in ipairs(list) do
			local p = place["u" .. e.player.UserId]
			if seats then
				e.team = (p and p <= top) and "A" or "B"
			else
				e.team = (p and p <= top) and "W" or "L"
			end
		end
		w = seats and "A" or "W"
		if seats then
			local r = arenaReport("result", arena.matchId, list, w, elig, {A = false, B = false})
			script:SetAttribute("PrArenaResult", "A ffa " .. tostring(r))
			script:SetAttribute("PrArenaState", "done")
			return
		end
	end
	local r = arenaReport("result", arena.matchId, list, w, elig, {A = arena.leavers.A, B = arena.leavers.B})
	script:SetAttribute("PrArenaResult", tostring(w) .. " " .. tostring(r))
'''))
JOBS["PracticeServer"] = ("src/server/PracticeServer/init.server.luau", SSS + "PracticeServer", P)

F = []
a = 'local VERSION = "1.0"\n'
F.append((a, '''local VERSION = "1.0"
VERSION = "1.1" -- v1.1 card starts folded, toast on every server
-- v1.1 (Kepu 2026-11-27 14:41 "The play button being constantly there and the list being constantly open is annoying ... Remove the
--   play button"): the PLAY button is off through FirstStepsPlayEnabled = false (set on this script in Edit; the 1.0 switch). While
--   script attribute FirstStepsStartFolded ~= false (default true, read at start) the card starts folded to one line ("FIRST STEPS
--   n/4" + the next step; tap the header to open / fold). While FirstStepsToastEverywhere ~= false (default true, read per toast) a
--   step finished on the Arena match server shows its toast there too (1.0: hub servers only).
'''))
a = 'local folded = false\n'
F.append((a, 'local folded = script:GetAttribute("FirstStepsStartFolded") ~= false -- v1.1 (1.0: false)\n'))
a = '''	if ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" or type(v) ~= "string" then return end
	local what, pts = v:match("^([^|]+)|(%d+)|")
'''
F.append((a, '''	if type(v) ~= "string" then return end
	if ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" and script:GetAttribute("FirstStepsToastEverywhere") == false then return end -- v1.1
	local what, pts = v:match("^([^|]+)|(%d+)|")
'''))
a = '''local gui = new("ScreenGui", {Name = "FirstSteps", DisplayOrder = 30, ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false}, pg)
'''
F.append((a, a + '''local toastGui = new("ScreenGui", {Name = "FirstStepsToast", DisplayOrder = 62, ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, pg) -- v1.1: the toast shows while the lobby UI is hidden (Arena server)
'''))
a = '''		Size = UDim2.fromOffset(phone and 250 or 340, phone and 52 or 64), BackgroundColor3 = C.plate}, gui)
'''
F.append((a, '''		Size = UDim2.fromOffset(phone and 250 or 340, phone and 52 or 64), BackgroundColor3 = C.plate}, toastGui) -- v1.1: own gui
'''))
JOBS["FirstSteps"] = ("src/client/FirstSteps.client.luau", SPS + "FirstSteps", F)
