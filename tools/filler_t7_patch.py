E={}
E['src/client/PregameScreen.client.luau']=[
('local Players = game:GetService("Players")\n','''-- v1.7 (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T7, MDA-581, option A): a bot entry with p = true (PracticeServer 1.16
--   Arena personas) is drawn like a player: its W-L (e.w / e.l) and "<pct>% WINS · LV <n>" on the plaque (n = clamp((w + l) / 3 + 5,
--   5, 60), made up), the player text size, and it counts as a player in the intro (no "BOTS" card; its W-L adds to the team
--   record). Switch: script attribute FillerPersonaUI (default true, read per draw; false = 1.6).
local Players = game:GetService("Players")
'''),
('VERSION = "1.6" -- v1.6 rank badge on the lineup plaques\n','VERSION = "1.6" -- v1.6 rank badge on the lineup plaques\nVERSION = "1.7" -- v1.7 filler bot personas drawn as players\n'),
('local function pct(w, l)\n','''local function isPersona(e) -- v1.7
	return type(e) == "table" and e.kind == "bot" and e.p == true and script:GetAttribute("FillerPersonaUI") ~= false
end
local function pct(w, l)
'''),
('''	if e.kind == "bot" then return (e.tier and string.upper(e.tier) or "") .. " BOT", "" end
''','''	if isPersona(e) and e.w ~= nil and e.l ~= nil then -- v1.7
		local lv = math.clamp(math.floor(((tonumber(e.w) or 0) + (tonumber(e.l) or 0)) / 3) + 5, 5, 60)
		return ("%d-%d"):format(e.w, e.l), ("%d%% WINS · LV %d"):format(pct(e.w, e.l), lv)
	end
	if e.kind == "bot" then return (e.tier and string.upper(e.tier) or "") .. " BOT", "" end
'''),
('	col.wl.TextSize = (e.kind == "bot" and 11 or 16.5) * TF\n','	col.wl.TextSize = ((e.kind == "bot" and not isPersona(e)) and 11 or 16.5) * TF -- v1.7: + persona\n'),
('		for _, e in ipairs(theirs) do if e.kind ~= "bot" then allBots = false end end\n','		for _, e in ipairs(theirs) do if e.kind ~= "bot" or isPersona(e) then allBots = false end end -- v1.7: + persona\n'),
('		if e.kind == "human" and e.w and e.l then w += e.w l += e.l any = true end\n','		if (e.kind == "human" or isPersona(e)) and e.w and e.l then w += e.w l += e.l any = true end -- v1.7: + persona\n'),
]
E['src/client/HardpointHUD.client.luau']=[
('local Players = game:GetService("Players")\n','''-- v1.15 (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T7, MDA-581, option A): a board row with p = true (HardpointServer 1.11
--   persona bots) has no BOT tag, and its results XP cell shows "+<total>" from the MatchAwards 1.1 display lines like a player's.
--   Switch: script attribute FillerPersonaUI (default true, read per draw; false = 1.14).
local Players = game:GetService("Players")
'''),
('VERSION = "1.14" -- v1.14 victory titles beat\n','VERSION = "1.14" -- v1.14 victory titles beat\nVERSION = "1.15" -- v1.15 filler bot personas drawn as players\n'),
('''				if r.bot then nm = nm .. ' <font size="10" color="#8f99aa">BOT</font>' end
''','''				local persona = r.p == true and script:GetAttribute("FillerPersonaUI") ~= false -- v1.15
				if r.bot and not persona then nm = nm .. ' <font size="10" color="#8f99aa">BOT</font>' end
'''),
('''				cell.Text = (a and not r.bot) and ("+" .. tostring(a.total or 0)) or "—"
''','''				local persona = r.p == true and script:GetAttribute("FillerPersonaUI") ~= false -- v1.15
				cell.Text = (a and (not r.bot or persona)) and ("+" .. tostring(a.total or 0)) or "—"
'''),
]
E['src/client/KillFeed.client.luau']=[
('local Players = game:GetService("Players")\n','''-- v1.4 (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T7, MDA-581, option A): a killer / victim with kP / vP (KillFeedServer 1.3,
--   a filler bot persona) gets no BOT tag, like a player. Switch: script attribute FillerPersonaUI (default true, read per line;
--   false = 1.3).
local Players = game:GetService("Players")
'''),
('VERSION = "1.3" -- v1.3 rank badge\n','VERSION = "1.3" -- v1.3 rank badge\nVERSION = "1.4" -- v1.4 filler bot personas: no BOT tag\n'),
('	if m.tags and e.kBot == true then tag(f, 2) end\n','	if m.tags and e.kBot == true and not (e.kP == true and script:GetAttribute("FillerPersonaUI") ~= false) then tag(f, 2) end -- v1.4\n'),
('	if m.tags and e.vBot == true then tag(f, 5) end\n','	if m.tags and e.vBot == true and not (e.vP == true and script:GetAttribute("FillerPersonaUI") ~= false) then tag(f, 5) end -- v1.4\n'),
]
import json
root='/home/claude/mechadinoarena/'
for f,ed in E.items():
    s=open(root+f).read()
    for o,n in ed:
        c=s.count(o); assert c==1,(f,c,o[:60]); s=s.replace(o,n)
    open(root+f,'w').write(s)
json.dump(E,open('/tmp/claude-0/-home-claude/7c8a0c48-2bce-579f-a00a-b76a8f986b09/scratchpad/t7.json','w'))
print('ok')
