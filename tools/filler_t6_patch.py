E = {}
E['src/server/KillFeedServer.server.luau'] = [
('local Players = game:GetService("Players")\n',
'''-- v1.3 (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T6, MDA-579, option A): a bot model with FillerPersona = true (FillerServer
--   hub bots, Arena match fill bots) gives who.p = true; the entry also carries kP / vP (killer / victim is a persona bot), so
--   clients draw it like a player. Stats, ids and kBot / vBot unchanged. Switch: script attribute KillFeedPersonaEnabled
--   (default true, read per kill; false = no kP / vP, as 1.2).
local Players = game:GetService("Players")
'''),
('VERSION = "1.2" -- v1.2 KillCredit for SkinStats\n', 'VERSION = "1.2" -- v1.2 KillCredit for SkinStats\nVERSION = "1.3" -- v1.3 kP / vP for filler bot personas\n'),
('''		return {name = m:GetAttribute("DisplayName") or name, team = m:GetAttribute("HardpointBotTeam") or "", bot = true, id = 0,
			sp = m:GetAttribute("Species") or "", key = "b" .. name}
''', '''		return {name = m:GetAttribute("DisplayName") or name, team = m:GetAttribute("HardpointBotTeam") or "", bot = true, id = 0,
			sp = m:GetAttribute("Species") or "", key = "b" .. name, p = m:GetAttribute("FillerPersona") == true} -- v1.3: + p
'''),
('''		return {name = m:GetAttribute("DisplayName") or m.Name, team = m:GetAttribute("HardpointBotTeam") or "", bot = true, id = 0,
			sp = m:GetAttribute("Species") or "", key = "b" .. m.Name}
''', '''		return {name = m:GetAttribute("DisplayName") or m.Name, team = m:GetAttribute("HardpointBotTeam") or "", bot = true, id = 0,
			sp = m:GetAttribute("Species") or "", key = "b" .. m.Name, p = m:GetAttribute("FillerPersona") == true} -- v1.3: + p
'''),
('''		vTeam = vWho.team, vBot = vWho.bot, vId = vWho.id, vSp = vWho.sp, at = now()}
''', '''		vTeam = vWho.team, vBot = vWho.bot, vId = vWho.id, vSp = vWho.sp, at = now()}
	if script:GetAttribute("KillFeedPersonaEnabled") ~= false then e.kP, e.vP = kWho.p == true, vWho.p == true end -- v1.3
'''),
]
E['src/server/HardpointServer.server.luau'] = [
('local Players = game:GetService("Players")\n',
'''-- v1.11 (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T6, MDA-579, option A): a bot row whose model (DinoIsland.Bots child
--   named as its id after the "b") has FillerPersona = true gets p = true (kept once seen). HpBoard rows and the award rows carry
--   p; clients draw those rows like players (no BOT tag) and MatchAwards 1.x gives them display-only XP lines. Switch: script
--   attribute HpPersonaEnabled (default true, read when a row is made / published; false = no p, as 1.10).
local Players = game:GetService("Players")
'''),
('VERSION = "1.10" -- v1.10 every winner gets a title\n', 'VERSION = "1.10" -- v1.10 every winner gets a title\nVERSION = "1.11" -- v1.11 persona bots on the board (p)\n'),
('local board = {} -- [id] = {id, name, team, species, bot, k, d, pt}\n', '''-- v1.11: filler bot personas on the board (see the header)
local function personaOf(id)
	if script:GetAttribute("HpPersonaEnabled") == false or type(id) ~= "string" or id:sub(1, 1) ~= "b" then return nil end
	local island = workspace:FindFirstChild("DinoIsland")
	local f = island and island:FindFirstChild("Bots")
	local m = f and f:FindFirstChild(id:sub(2))
	return (m and m:GetAttribute("FillerPersona") == true) and true or nil
end
local board = {} -- [id] = {id, name, team, species, bot, k, d, pt}
'''),
('	r.name, r.team = name or r.name, team or r.team\n', '	r.name, r.team = name or r.name, team or r.team\n	if r.bot and not r.p then r.p = personaOf(id) end -- v1.11\n'),
('ab = r.ab or 0}) -- v1.5: + pk; v1.9: + heal, ab\n', 'ab = r.ab or 0, p = r.p}) -- v1.5: + pk; v1.9: + heal, ab; v1.11: + p\n'),
('		table.insert(rows, {id = r.id, team = r.team, bot = r.bot, k = r.k, d = r.d, pt = r.pt, pk = r.pk or 0})\n', '		table.insert(rows, {id = r.id, team = r.team, bot = r.bot, k = r.k, d = r.d, pt = r.pt, pk = r.pk or 0, p = r.p}) -- v1.11: + p\n'),
]
E['src/server/PracticeServer/init.server.luau'] = [
('local Players = game:GetService("Players")\n',
'''-- v1.16 (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T6, MDA-579, option A; Kepu 2026-11-25 "A"): on an Arena match server
--   (PrArena) the fill bots pass as players. When the first Arena arrival sets PrArena, every pool bot gets a persona (in
--   parallel, at most 8 s): name = FillerNameCheck.pick (a Roblox-style name that is not a real username), the made-up record
--   FillerRules.record, a skin and trail FillerRules.look (UniversalSkins / TrailCatalog ORDER); spec.name = that name. A bot that
--   takes a leaver's slot gets one too. The bot spawns with PracticeBots 1.2 opts.persona; PrRoster bot entries carry p = true,
--   w, l. VS BOTS matches (no PrArena) are unchanged. Switch: script attribute FillerArenaPersona (default true, read when
--   personas are made; false = 1.15).
local Players = game:GetService("Players")
'''),
('VERSION = "1.15" -- v1.15 results freeze: no more fighting once the match is won\n', 'VERSION = "1.15" -- v1.15 results freeze: no more fighting once the match is won\nVERSION = "1.16" -- v1.16 Arena fill bots pass as players (personas)\n'),
('local function rollPool()\n', '''-- v1.16: Arena match bots pass as players (see the header)
if script:GetAttribute("FillerArenaPersona") == nil then script:SetAttribute("FillerArenaPersona", true) end
local FillerR = DA:FindFirstChild("FillerRules") and require(DA.FillerRules)
local FillerNC = DA:FindFirstChild("FillerNameCheck") and require(DA.FillerNameCheck)
local personaUsed = {}
local function personaOn()
	return ARENA and script:GetAttribute("FillerArenaPersona") ~= false and FillerR ~= nil and FillerNC ~= nil
end
local function personaize(spec) -- yields (the name check)
	if not personaOn() or type(spec) ~= "table" or spec.persona then return spec end
	local name = FillerNC.pick(rng, personaUsed)
	local w, l = FillerR.record(name)
	local US = DA:FindFirstChild("UniversalSkins") and require(DA.UniversalSkins)
	local TC = DA:FindFirstChild("TrailCatalog") and require(DA.TrailCatalog)
	local skin, trail = FillerR.look(rng, US and US.ORDER or {"classic"}, TC and TC.ORDER or {})
	spec.persona = {name = name, w = w, l = l, skin = skin, trail = trail}
	spec.name = name
	return spec
end
local function personaizeAll(list) -- every spec in parallel, waits for all (at most 8 s)
	if not personaOn() then return end
	local left = 0
	for _, spec in ipairs(list) do
		if type(spec) == "table" and not spec.persona then
			left += 1
			task.spawn(function()
				pcall(personaize, spec)
				left -= 1
			end)
		end
	end
	local t0 = os.clock()
	while left > 0 and os.clock() - t0 < 8 do task.wait() end
end

local function rollPool()
'''),
('				table.insert(out[side], {kind = "bot", name = s.spec.name, species = s.spec.species, parts = partNames(s.spec)})\n',
 '				local pe = s.spec.persona -- v1.16\n				table.insert(out[side], {kind = "bot", name = s.spec.name, species = s.spec.species, parts = partNames(s.spec),\n					p = pe and true or nil, w = pe and pe.w or nil, l = pe and pe.l or nil})\n'),
('		noCollide = get("PrBotNoCollide") ~= false}) -- v1.2: + noCollide\n', '		noCollide = get("PrBotNoCollide") ~= false, persona = rec.spec and rec.spec.persona}) -- v1.2: + noCollide; v1.16: + persona\n'),
('	local spec = R.rollBot(rng, (function() local u = {} for _, r in ipairs(botRecs) do u[r.spec.name] = true end return u end)(), SkillTree, get("PrBotLevel"), botSpecies()) -- v1.3: + species\n',
 '	local spec = R.rollBot(rng, (function() local u = {} for _, r in ipairs(botRecs) do u[r.spec.name] = true end return u end)(), SkillTree, get("PrBotLevel"), botSpecies()) -- v1.3: + species\n	spec = personaize(spec) -- v1.16\n'),
('			set("PrArena", true)\n', '			set("PrArena", true)\n			personaizeAll(pool) -- v1.16\n'),
]
import json,sys
root='/home/claude/mechadinoarena/'
for f,edits in E.items():
    s=open(root+f).read()
    for o,n in edits:
        c=s.count(o); assert c==1,(f,c,o[:60])
        s=s.replace(o,n)
    open(root+f,'w').write(s)
json.dump(E,open('/tmp/claude-0/-home-claude/7c8a0c48-2bce-579f-a00a-b76a8f986b09/scratchpad/t6/edits.json','w'))
print('ok')
