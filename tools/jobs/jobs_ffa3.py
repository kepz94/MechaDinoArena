"""Free for All, Studio test fix 2 (HardpointHUD 1.17, not yet published): at the results the standings card kept its last live
frame, drawn from a board copy older than the final places (it read 0 kills for 1st-3rd while the board read 20 / 17 / 14). The
card is now redrawn every frame of the results too. Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_ffa3.py"""
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}
U = []
a = '''	TD.box.Visible = TD.ffa() -- v1.17
	if TD.box.Visible then card.Size = UDim2.fromOffset(card.Size.X.Offset, 70) end
'''
U.append((a, a + '''	if TD.box.Visible and phase == "results" then TD.card(false, 0) end -- the final standings
'''))
JOBS["HardpointHUD"] = ("src/client/HardpointHUD.client.luau", SPS + "HardpointHUD", U)
