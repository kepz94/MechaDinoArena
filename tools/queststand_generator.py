# queststand_generator v1.0 — pairs patches for QUEST_STAND_v1.0 Task 3 (UniversalSkins 1.5, SkinServer 1.7).
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
F = {}
F['UniversalSkins'] = ('src/shared/UniversalSkins.luau', [
('US.VERSION = "1.4" -- v1.4 island streak unlocks (Zebra 10, Storm Front 25)',
 'US.VERSION = "1.4" -- v1.4 island streak unlocks (Zebra 10, Storm Front 25)\n'
 'US.VERSION = "1.5" -- v1.5 streak skins claimed at the Quest Stand\n'
 '-- v1.5 (Quest Stand, plan docs/plans/QUEST_STAND_v1.0.md Task 3; Kepu 2026-11-26 "this is the only place where you can claim them",\n'
 '--   picks "Claim at the stand", "Always claimable"): with US.STAND_CLAIMS (true) the Zebra and Storm Front unlocks get\n'
 '--   claim = "stand" (SkinServer 1.7 no longer grants them by itself; QuestServer 1.0 grants them through SkinGrant when claimed) and\n'
 '--   the text "10 / 25 kill streak on the island, claim at the Quest Stand". Progress (istreak) is unchanged. false = 1.4.'),
('\tUS.SKINS.storm.unlock = earn("istreak", 25, "Get a 25 kill streak on the island")\nend\n',
 '\tUS.SKINS.storm.unlock = earn("istreak", 25, "Get a 25 kill streak on the island")\nend\n'
 'US.STAND_CLAIMS = true -- v1.5\n'
 'if US.ISLAND_STREAK_UNLOCKS and US.STAND_CLAIMS then\n'
 '\tUS.SKINS.zebra.unlock.claim = "stand"\n'
 '\tUS.SKINS.zebra.unlock.text = "10 kill streak on the island, claim at the Quest Stand"\n'
 '\tUS.SKINS.storm.unlock.claim = "stand"\n'
 '\tUS.SKINS.storm.unlock.text = "25 kill streak on the island, claim at the Quest Stand"\n'
 'end\n'),
])
F['SkinServer'] = ('src/server/SkinServer.server.luau', [
('VERSION = "1.6" -- v1.6 island streak earn stat',
 'VERSION = "1.6" -- v1.6 island streak earn stat\nVERSION = "1.7" -- v1.7 stand claims + SkinGrant\n'
 '-- v1.7 (Quest Stand, plan docs/plans/QUEST_STAND_v1.0.md Task 3; picks "Claim at the stand", "Always claimable"): the earn check\n'
 '--   skips skins whose unlock has claim == "stand" (UniversalSkins 1.5: Zebra, Storm Front) while script attribute\n'
 '--   SkinStandClaimsEnabled ~= false (read per check; false = 1.6, they unlock by themselves again). Skins already owned stay owned.\n'
 '--   New server-only BindableFunction SkinGrant (child of this script): Invoke(player, id, reason) -> "ok" / "owned" / "unknown" /\n'
 '--   "notLoaded" / "failed" / "disabled" (universal skins off): writes owned[id] in the same UpdateAsync as the earn check, then\n'
 '--   SkinUnlocked / SkinUnlockedAt and SkinServerResult "earned". Diagnostic: script SkinQuestGrants.'),
('\t\tif sk.unlock.kind == "earn" and st.owned[id] ~= true and US.unlocked(id, stats) then table.insert(new, id) end',
 '\t\tif sk.unlock.kind == "earn" and st.owned[id] ~= true and US.unlocked(id, stats)\n'
 '\t\t\tand not (sk.unlock.claim == "stand" and script:GetAttribute("SkinStandClaimsEnabled") ~= false) then -- v1.7\n'
 '\t\t\ttable.insert(new, id)\n'
 '\t\tend'),
('\tPlayers.PlayerAdded:Connect(watch)\n\tfor _, p in ipairs(Players:GetPlayers()) do watch(p) end\nend\n',
 '\tPlayers.PlayerAdded:Connect(watch)\n\tfor _, p in ipairs(Players:GetPlayers()) do watch(p) end\nend\n'
 '-- v1.7: SkinGrant for the Quest Stand (see the v1.7 note)\n'
 'if script:GetAttribute("SkinStandClaimsEnabled") == nil then script:SetAttribute("SkinStandClaimsEnabled", true) end\n'
 'do\n'
 '\tlocal grantFn = script:FindFirstChild("SkinGrant") or Instance.new("BindableFunction")\n'
 '\tgrantFn.Name = "SkinGrant"\n'
 '\tgrantFn.Parent = script\n'
 '\tgrantFn.OnInvoke = function(player, id, reason)\n'
 '\t\tif not uni then return "disabled" end\n'
 '\t\tif typeof(player) ~= "Instance" or not player:IsA("Player") or type(id) ~= "string" or not US.get(id) then return "unknown" end\n'
 '\t\tlocal st = states[player]\n'
 '\t\tif not (st and st.loaded and store) then return "notLoaded" end\n'
 '\t\tif st.owned[id] == true then return "owned" end\n'
 '\t\tlocal ok, value = pcall(function()\n'
 '\t\t\treturn store:UpdateAsync("u" .. player.UserId, function(old)\n'
 '\t\t\t\tlocal v = blank(old)\n'
 '\t\t\t\tv.owned[id] = true\n'
 '\t\t\t\treturn v\n'
 '\t\t\tend)\n'
 '\t\tend)\n'
 '\t\tif not (ok and player.Parent) then return "failed" end\n'
 '\t\ttakeValue(st, value)\n'
 '\t\tst.owned[id] = true\n'
 '\t\tscript:SetAttribute("SkinQuestGrants", (script:GetAttribute("SkinQuestGrants") or 0) + 1)\n'
 '\t\tpublish(player)\n'
 '\t\tplayer:SetAttribute("SkinUnlocked", id)\n'
 '\t\tplayer:SetAttribute("SkinUnlockedAt", workspace:GetServerTimeNow())\n'
 '\t\tsetResult(player, "earned")\n'
 '\t\treturn "ok"\n'
 '\tend\n'
 'end\n'),
])
TAIL = '''}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k)
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
local m = Instance.new("ModuleScript")
m.Source = "return function()\\n" .. s .. "\\nend"
m.Parent = workspace
local okC, errC = pcall(require, m)
m:Destroy()
if not okC then return "COMPILE FAIL " .. tostring(errC) end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
'''
for name, (path, pairs_) in F.items():
    src = open(os.path.join(ROOT, path), encoding='utf-8').read()
    out = [f'-- queststand_patch_{name}: QUEST_STAND_v1.0.\nlocal PAIRS = {{\n']
    for o, n in pairs_:
        assert src.count(o) == 1, (name, src.count(o), o[:70])
        out.append('{[=====[' + o + ']=====], [=====[' + n + ']=====]},\n')
    open(os.path.join(ROOT, 'tools', f'queststand_patch_{name}.luau'), 'w', encoding='utf-8').write(''.join(out) + TAIL)
    print('wrote', name)
