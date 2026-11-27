"""Bug hunt 2026-11-27 items 3 + 4 (Kepu 16:49 "Okay let's do those"; proposed copy "FIGHT · 4v4 Arena matches").
* Tutorial 1.9: the welcome screen's FIGHT tile reads "4v4 Arena matches" (1.8: "Squad battles on the island"; the island has no bots
  since v1086 and the game is Arena-first). Switch TutWelcomeArenaCopyEnabled (default true, read per draw).
* VictoryTitles 1.5: the results crowd also plays for a Free for All result (HpWinner "ffa"; 1.4: only "A" / "B").
  Switch VictoryCrowdFfaEnabled (default true, read per results).
Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_bh34.py"""
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}
T = []
a = 'VERSION = "1.8" -- v1.8 the tutorial ends with the first match\n'
T.append((a, a + '''VERSION = "1.9" -- v1.9 welcome FIGHT tile: 4v4 Arena matches
-- v1.9 (bug hunt 2026-11-27 item 3; Kepu 16:49 "Okay let's do those", copy "FIGHT · 4v4 Arena matches"): while script attribute
--   TutWelcomeArenaCopyEnabled ~= false (default true, read per draw) the welcome screen's FIGHT tile reads "4v4 Arena matches"
--   (1.8: "Squad battles on the island"; no island bots since v1086). Layout, the other two tiles unchanged. false = 1.8.
'''))
a = '''		{"", "COLLECT", "7 dinos, skins, emotes, trails"}} -- Studio check: no icons (see the tile text below)
'''
T.append((a, a + '''	if script:GetAttribute("TutWelcomeArenaCopyEnabled") ~= false then TILES[1][3] = "4v4 Arena matches" end -- v1.9
'''))
JOBS["Tutorial"] = ("src/client/Tutorial.client.luau", SPS + "Tutorial", T)

V = []
a = 'VERSION = "1.4" -- v1.4 hold on the stage until the results end\n'
V.append((a, a + '''VERSION = "1.5" -- v1.5 the results crowd for Free for All too
-- v1.5 (bug hunt 2026-11-27 item 4; Kepu 16:49 "Okay let's do those"): while script attribute VictoryCrowdFfaEnabled ~= false (default
--   true, read per results) the results crowd also plays when HpWinner is "ffa" (HardpointServer's Free for All result; 1.4: only
--   "A" / "B"). false = 1.4.
'''))
a = '''			if w == "A" or w == "B" then pcall(Audio.preload) pcall(Audio.crowd, "res") end
'''
V.append((a, '''			if w == "A" or w == "B" or (w == "ffa" and script:GetAttribute("VictoryCrowdFfaEnabled") ~= false) then -- v1.5: + ffa
				pcall(Audio.preload) pcall(Audio.crowd, "res")
			end
'''))
JOBS["VictoryTitles"] = ("src/client/VictoryTitles.client.luau", SPS + "VictoryTitles", V)
