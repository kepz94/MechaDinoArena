"""IslandRespawnClient 1.1 (Kepu 2026-11-27 12:38, phone screenshot: "Why is this button covering my whole screen. Make it smaller"
+ "And not in the center of the screen"): the RETURN TO SPAWN PAD button is compact (210 x 44) at the top centre, under the
playtime chip (y 60), instead of 300 x 64 in the middle of the screen. Switch IslandPadCompact (true; false = the v1.0 layout).
Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_padsmall.py"""
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}
U = []
a = '''-- Switches / numbers (script attributes): IslandRespawnClientEnabled (true, read at start), IslandPadShow (2, read per show).
'''
U.append((a, a + '''-- v1.1 (Kepu 2026-11-27 12:38 "Why is this button covering my whole screen. Make it smaller" + "And not in the center of the
--   screen"): while IslandPadCompact ~= false (read per show) the button is IslandPadW (230) x IslandPadH (44, never under 44)
--   at the top centre, top edge at IslandPadY (60, under the playtime chip), label one line (20 tall, max 15); the key hint "X" 32 x 32 on its left.
--   IslandPadCompact false = the v1.0 layout (300 x 64, bottom centre 150 up). Diagnostics: IslandPadLayout ("compact" / "v1.0").
'''))
a = 'local VERSION = "1.0"\n'
U.append((a, 'local VERSION = "1.1"\n'))
a = 'for k, v in pairs({IslandRespawnClientEnabled = true, IslandPadShow = 2}) do\n'
U.append((a, 'for k, v in pairs({IslandRespawnClientEnabled = true, IslandPadShow = 2, IslandPadCompact = true, IslandPadW = 230, IslandPadH = 44, IslandPadY = 60}) do -- v1.1: + compact\n'))
a = '''local showId, untilT, total = 0, 0, 2
'''
U.append((a, '''local sizeCon = btn:FindFirstChildOfClass("UISizeConstraint")
local textCon = label:FindFirstChildOfClass("UITextSizeConstraint")
local function layout() -- v1.1: compact at the top centre, or the v1.0 layout
	if script:GetAttribute("IslandPadCompact") ~= false then
		local w = math.max(160, tonumber(script:GetAttribute("IslandPadW")) or 230)
		local h = math.max(44, tonumber(script:GetAttribute("IslandPadH")) or 44)
		btn.AnchorPoint = Vector2.new(0.5, 0)
		btn.Position = UDim2.new(0.5, 0, 0, tonumber(script:GetAttribute("IslandPadY")) or 60)
		btn.Size = UDim2.fromOffset(w, h)
		sizeCon.MinSize = Vector2.new(160, 44)
		label.Size = UDim2.new(1, -20, 0, 20) -- one line tall, so the scaled text never wraps to two lines
		label.Position = UDim2.fromOffset(10, 8)
		textCon.MaxTextSize = 15
		key.Size = UDim2.fromOffset(32, 32)
		key.TextSize = 16
		script:SetAttribute("IslandPadLayout", "compact")
	else
		btn.AnchorPoint = Vector2.new(0.5, 1)
		btn.Position = UDim2.new(0.5, 0, 1, -150)
		btn.Size = UDim2.fromOffset(300, 64)
		sizeCon.MinSize = Vector2.new(200, 48)
		label.Size = UDim2.new(1, -24, 1, -14)
		label.Position = UDim2.fromOffset(12, 2)
		textCon.MaxTextSize = 20
		key.Size = UDim2.fromOffset(40, 40)
		key.TextSize = 20
		script:SetAttribute("IslandPadLayout", "v1.0")
	end
end
layout()

''' + a))
a = '''	key.Visible = UIS.KeyboardEnabled
	gui.Enabled = true
'''
U.append((a, '''	key.Visible = UIS.KeyboardEnabled
	layout() -- v1.1
	gui.Enabled = true
'''))
JOBS["IslandRespawnClient"] = ("src/client/IslandRespawnClient.client.luau", SPS + "IslandRespawnClient", U)
