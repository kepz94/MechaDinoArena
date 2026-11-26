# universalpoints_generator v1.0 — writes tools/universalpoints_patch1.luau (SkillServer 1.15, UNIVERSAL_POINTS_v1.0 Task 2).
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAIRS = [
('VERSION = "1.14" -- v1.14 fresh save store (account reset)',
 'VERSION = "1.14" -- v1.14 fresh save store (account reset)\n'
 'VERSION = "1.15" -- v1.15 universal skill points + bonus points\n'
 '-- v1.15 (universal points, plan docs/plans/UNIVERSAL_POINTS_v1.0.md Task 2; Kepu 2026-11-26 "Make all points universal", "the daily\n'
 '--   quest rewards will be skill points"; picks "Full pool on every dino", "Highest dino\'s XP", "Yes, past 40"; red-team "Accept",\n'
 '--   "Yes, that\'s the point", "No cap"). While script attribute SkillUniversalEnabled ~= false (read at each player\'s load, d.universal):\n'
 '--   * One account XP (so one level) for every dino: it lives in d.xp and is NOT swapped when the dino changes (switchTo keeps it;\n'
 '--     stash still writes it into the record). Kill XP and SkillGrantXp raise it, so every dino levels together.\n'
 '--   * Load: account XP = SkillPool.accountXp(value) = max(value.uxp, every dino record\'s xp) (the migration from 1.14 saves;\n'
 '--     nobody goes down); bonus = SkillPool.cleanBonus(value.bonus, SkillBonusMax). A record\'s build-over-points reset uses the\n'
 '--     account points instead of the record\'s own level points.\n'
 '--   * Points: SkillPoints = pointsOf(account level) + bonus (SkillPool.earned); each dino spends from the full pool on its own\n'
 '--     build (builds, loadouts, saved loadouts stay per dino); buys use the same number. Bonus can go past 40 (no cap unless\n'
 '--     script attribute SkillBonusMax is set). Mastery 3 unchanged.\n'
 '--   * Save: top-level uxp (account XP) and bonus are added to the value; v stays 2, so 1.14 still reads it. With the switch off,\n'
 '--     the loaded uxp / bonus are written back untouched (nothing is lost).\n'
 '--   * Server-only BindableFunction SkillGrantPoints (child of this script): Invoke(player, amount, reason) -> "ok", before, after\n'
 '--     (bonus totals) | "disabled" (SkillEnabled / SkillGrantPointsEnabled false or universal off for the player) | "notLoaded" |\n'
 '--     "badArg" (not a Player, amount not a whole number 1..100). For the Quest Stand (roadmap piece 4).\n'
 '--   Player attributes: SkillBonusPoints, SkillUniversal ("on" / "off"), SkillAccountFrom ("new" / "max of N dinos" / "uxp of N\n'
 '--   dinos"), SkillLastPoints ("quest +3"). Script attributes: SkillUniversalEnabled (true), SkillGrantPointsEnabled (true),\n'
 '--   SkillBonusMax (unset = no cap), SkillPointGrants (count). Switch off = 1.14 (per-dino XP; bonus ignored but kept in the save).'),
('local ST = require(treeModule)\n',
 'local ST = require(treeModule)\n'
 'local SkillPool = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("SkillPool")) -- v1.15\n'
 'if script:GetAttribute("SkillUniversalEnabled") == nil then script:SetAttribute("SkillUniversalEnabled", true) end -- v1.15\n'
 'if script:GetAttribute("SkillGrantPointsEnabled") == nil then script:SetAttribute("SkillGrantPointsEnabled", true) end -- v1.15\n'
 'local function bonusMax() local m = script:GetAttribute("SkillBonusMax") return type(m) == "number" and m or nil end -- v1.15\n'
 'local function earnedOf(d) -- v1.15: account level points + bonus when universal, else 1.14\n'
 '\tif d.universal then return SkillPool.earned(d.xp, d.bonus, ST, bonusMax()) end\n'
 '\treturn ST.pointsOf((ST.levelOf(d.xp)))\n'
 'end\n'),
('local earned = ST.pointsOf(level)', 'local earned = earnedOf(d) -- v1.15 (1.14: ST.pointsOf(level))'),
('player:SetAttribute("SkillLeft", earned - spent)\n',
 'player:SetAttribute("SkillLeft", earned - spent)\n'
 '\tplayer:SetAttribute("SkillBonusPoints", d.universal and SkillPool.cleanBonus(d.bonus, bonusMax()) or 0) -- v1.15\n'
 '\tplayer:SetAttribute("SkillUniversal", d.universal and "on" or "off") -- v1.15\n'),
('local earned = ST.pointsOf((ST.levelOf(d.xp)))', 'local earned = earnedOf(d) -- v1.15 (1.14: ST.pointsOf((ST.levelOf(d.xp))))'),
('\tif d.active == key then return end\n\tstash(d)\n',
 '\tif d.active == key then return end\n\tif d.universal and d.active then d.uxp = d.xp end -- v1.15: the account XP so far\n\tstash(d)\n'),
('d.xp, d.steps, d.loadout = r.xp, r.steps, r.loadout\n',
 'd.xp, d.steps, d.loadout = r.xp, r.steps, r.loadout\n'
 '\tif d.universal then d.xp = d.uxp or 0 end -- v1.15: one account XP, not the record\'s\n'),
('local function cleanRecord(raw, key)', 'local function cleanRecord(raw, key, cap) -- v1.15: + cap (account points when universal)'),
('if ST.spent(steps, key) > ST.pointsOf((ST.levelOf(xp))) then',
 'if ST.spent(steps, key) > (cap or ST.pointsOf((ST.levelOf(xp)))) then'),
('\td.saved = {} -- v1.12\n',
 '\td.saved = {} -- v1.12\n'
 '\td.universal = script:GetAttribute("SkillUniversalEnabled") ~= false -- v1.15\n'
 '\td.uxp, d.bonus = 0, 0\n'
 '\tplayer:SetAttribute("SkillAccountFrom", "new")\n'),
('elseif type(value) == "table" and value.v == 2 and type(value.dinos) == "table" then -- v1.2: per-dino records\n',
 'elseif type(value) == "table" and value.v == 2 and type(value.dinos) == "table" then -- v1.2: per-dino records\n'
 '\t\t\td.rawUxp, d.rawBonus = value.uxp, value.bonus -- v1.15: written back as they are while universal is off\n'
 '\t\t\tlocal cap -- v1.15: the account points every record is checked against\n'
 '\t\t\tif d.universal then\n'
 '\t\t\t\td.uxp, d.bonus = SkillPool.accountXp(value), SkillPool.cleanBonus(value.bonus, bonusMax())\n'
 '\t\t\t\tcap = SkillPool.earned(d.uxp, d.bonus, ST, bonusMax())\n'
 '\t\t\t\tlocal n = 0 for _ in pairs(value.dinos) do n += 1 end\n'
 '\t\t\t\tplayer:SetAttribute("SkillAccountFrom", (type(value.uxp) == "number" and "uxp" or "max") .. " of " .. n .. " dinos")\n'
 '\t\t\tend\n'),
('d.dinos[key] = cleanRecord(raw, key)', 'd.dinos[key] = cleanRecord(raw, key, cap)'),
('\tif type(d.saved) == "table" then -- v1.12',
 '\tif d.universal then value.uxp, value.bonus = d.xp, d.bonus -- v1.15\n'
 '\telse value.uxp, value.bonus = d.rawUxp, d.rawBonus end\n'
 '\tif type(d.saved) == "table" then -- v1.12'),
('\treturn "ok", {level = l1, into = i1, next = n1}, {level = l2, into = i2, next = n2}\nend',
 '\treturn "ok", {level = l1, into = i1, next = n1}, {level = l2, into = i2, next = n2}\nend\n\n'
 '-- ---------- v1.15: bonus skill points grant (see the v1.15 note) ----------\n'
 'script:SetAttribute("SkillPointGrants", script:GetAttribute("SkillPointGrants") or 0)\n'
 'local pointsFn = script:FindFirstChild("SkillGrantPoints")\n'
 'if not pointsFn then\n'
 '\tpointsFn = Instance.new("BindableFunction")\n'
 '\tpointsFn.Name = "SkillGrantPoints"\n'
 '\tpointsFn.Parent = script\n'
 'end\n'
 'pointsFn.OnInvoke = function(player, amount, reason)\n'
 '\tif script:GetAttribute("SkillEnabled") == false or script:GetAttribute("SkillGrantPointsEnabled") == false then return "disabled" end\n'
 '\tif typeof(player) ~= "Instance" or not player:IsA("Player") or not SkillPool.grantOk(amount) then return "badArg" end\n'
 '\tlocal d = data[player]\n'
 '\tif not d or not d.loaded then return "notLoaded" end\n'
 '\tif not d.universal then return "disabled" end\n'
 '\tlocal before = SkillPool.cleanBonus(d.bonus, bonusMax())\n'
 '\td.bonus = SkillPool.cleanBonus(before + amount, bonusMax())\n'
 '\td.dirty = true\n'
 '\tpublish(player, d, false)\n'
 '\tplayer:SetAttribute("SkillLastPoints", tostring(reason or "points") .. " +" .. amount)\n'
 '\tscript:SetAttribute("SkillPointGrants", (script:GetAttribute("SkillPointGrants") or 0) + 1)\n'
 '\treturn "ok", before, d.bonus\n'
 'end'),
]
TAIL = '''}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
'''
src = open(os.path.join(ROOT, 'src/server/SkillServer.server.luau'), encoding='utf-8').read()
out = ['-- universalpoints_patch1 (SkillServer 1.15): UNIVERSAL_POINTS_v1.0 Task 2.\nlocal PAIRS = {\n']
for o, n in PAIRS:
    assert not o.startswith('\n') and not n.startswith('\n')
    assert src.count(o) == 1, (src.count(o), o[:60])
    out.append('{[=====[' + o + ']=====], [=====[' + n + ']=====]},\n')
open(os.path.join(ROOT, 'tools/universalpoints_patch1.luau'), 'w', encoding='utf-8').write(''.join(out) + TAIL)
print('ok', len(PAIRS))
