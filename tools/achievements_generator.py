# achievements_generator v1.0 — QuestServer 1.1 pairs patch (ACHIEVEMENTS_v1.0 Task 2).
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = [
('local VERSION = "1.0"\nscript:SetAttribute("QuestServerVersion", VERSION)',
 'local VERSION = "1.0"\nVERSION = "1.1" -- v1.1 achievements\n'
 '-- v1.1 (achievements, plan docs/plans/ACHIEVEMENTS_v1.0.md Task 2; Kepu 2026-11-26 picks "Skill points by tier", "Claim at the Quest\n'
 '--   Stand", "Start fresh" + "Live state", "B · Three columns", pop-up "top centre 1 s"; red-team "OK", "Keep 2 / 5 / 10"). The 17\n'
 '--   achievements of ServerStorage.DinoArcade.AchievementRules 1.0 ride in the same store value: ach = {p = {[stat] = n} (counters,\n'
 '--   saved as deltas / bests like the quests; everyone starts at 0), c = {[id] = true} (claimed), n = {[id] = true} (pop-up shown)}.\n'
 '--   The day roll never touches ach. Counted stats: ikill / akill / aplay / awin / istreak from the events above, awstreak (player\n'
 '--   ArenaStreak rising after ArenaRecordReady, max), qclaim (+1 per daily claim). Live stats: OwnedDinos / SkinOwnedU counts and\n'
 '--   SkillLevel. claim("a_<id>") (same near-the-stand rule) sets ach.c[id] + pend in one UpdateAsync when have >= need, then pays\n'
 '--   SkillGrantPoints(player, 2 / 5 / 10 by medal, "achievement"). The view gets achievements = {{id, name, text, where, medal, have,\n'
 '--   need, pts, claimed}} and achReady; QuestReady counts quests + achievements. When an achievement first becomes claimable and is\n'
 '--   not in ach.n: player AchDoneList ("NAME|medal;..." of the new ones) and AchDoneAt (server time) for SkinUnlockPopup 1.1, and it\n'
 '--   joins ach.n (saved). Switch: script attribute QuestAchievementsEnabled (true, read per use; false = 1.0).\n'
 'script:SetAttribute("QuestServerVersion", VERSION)'),
('local Q = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("QuestRules"))\n',
 'local Q = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("QuestRules"))\n'
 'local AR = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("AchievementRules")) -- v1.1\n'
 'if script:GetAttribute("QuestAchievementsEnabled") == nil then script:SetAttribute("QuestAchievementsEnabled", true) end -- v1.1\n'
 'local function achOn() return script:GetAttribute("QuestAchievementsEnabled") ~= false end\n'),
('\treturn out\nend\nlocal function picksValid',
 '\tlocal a = type(v.ach) == "table" and v.ach or {} -- v1.1\n'
 '\tout.ach = {p = {}, c = {}, n = {}}\n'
 '\tfor _, f in ipairs({"p", "c", "n"}) do\n'
 '\t\tif type(a[f]) == "table" then for k, x in pairs(a[f]) do if type(k) == "string" then out.ach[f][k] = x end end end\n'
 '\tend\n'
 '\treturn out\nend\nlocal function picksValid'),
('\tfor _, s in ipairs(Q.specials()) do if Q.claimable(s.need, specialHave(player), st.pc[s.id]) then n += 1 end end\n\treturn n\n',
 '\tfor _, s in ipairs(Q.specials()) do if Q.claimable(s.need, specialHave(player), st.pc[s.id]) then n += 1 end end\n'
 '\tif achOn() and st.ach then -- v1.1\n'
 '\t\tlocal live = AR.liveStats(player:GetAttribute("OwnedDinos"), player:GetAttribute("SkinOwnedU"), player:GetAttribute("SkillLevel"))\n'
 '\t\tfor _, x in ipairs(AR.LIST) do\n'
 '\t\t\tlocal h\n'
 '\t\t\tif AR.LIVE_STATS[x.stat] then h = live[x.stat]\n'
 '\t\t\telseif AR.MAX_STATS[x.stat] then h = math.max(tonumber(st.ach.p[x.stat]) or 0, st.abest[x.stat] or 0)\n'
 '\t\t\telse h = (tonumber(st.ach.p[x.stat]) or 0) + (st.aadd[x.stat] or 0) end\n'
 '\t\t\tif AR.claimable(x, h, st.ach.c[x.id]) then n += 1 end\n'
 '\t\tend\n'
 '\tend\n'
 '\treturn n\n'),
('\tlocal n = st.loaded and readyCount(player, st) or 0\n\tif player:GetAttribute("QuestReady") ~= n then player:SetAttribute("QuestReady", n) end\n',
 '\tlocal n = st.loaded and readyCount(player, st) or 0\n\tif player:GetAttribute("QuestReady") ~= n then player:SetAttribute("QuestReady", n) end\n'
 '\tif st.loaded and achOn() and st.ach then -- v1.1: the "ACHIEVEMENT DONE" pop-up, once per achievement ever\n'
 '\t\tlocal live = AR.liveStats(player:GetAttribute("OwnedDinos"), player:GetAttribute("SkinOwnedU"), player:GetAttribute("SkillLevel"))\n'
 '\t\tlocal new = {}\n'
 '\t\tfor _, x in ipairs(AR.LIST) do\n'
 '\t\t\tif not st.ach.n[x.id] and not st.ach.c[x.id] then\n'
 '\t\t\t\tlocal h\n'
 '\t\t\t\tif AR.LIVE_STATS[x.stat] then h = live[x.stat]\n'
 '\t\t\t\telseif AR.MAX_STATS[x.stat] then h = math.max(tonumber(st.ach.p[x.stat]) or 0, st.abest[x.stat] or 0)\n'
 '\t\t\t\telse h = (tonumber(st.ach.p[x.stat]) or 0) + (st.aadd[x.stat] or 0) end\n'
 '\t\t\t\tif h >= x.need then\n'
 '\t\t\t\t\tst.ach.n[x.id] = true\n'
 '\t\t\t\t\tst.dirty = true\n'
 '\t\t\t\t\ttable.insert(new, x.name .. "|" .. x.medal)\n'
 '\t\t\t\tend\n'
 '\t\t\tend\n'
 '\t\tend\n'
 '\t\tif #new > 0 then\n'
 '\t\t\tplayer:SetAttribute("AchDoneList", table.concat(new, ";"))\n'
 '\t\t\tplayer:SetAttribute("AchDoneAt", workspace:GetServerTimeNow())\n'
 '\t\tend\n'
 '\tend\n'),
('\tst.pc = v.pc\n\tst.pend = v.pend\n',
 '\tst.pc = v.pc\n\tst.pend = v.pend\n'
 '\tif v.ach then -- v1.1: keep the pop-ups already shown this session\n'
 '\t\tfor k in pairs(st.ach and st.ach.n or {}) do v.ach.n[k] = true end\n'
 '\t\tst.ach = v.ach\n'
 '\tend\n'),
('\tlocal sentAdd, sentBest = table.clone(st.add), table.clone(st.best)\n',
 '\tlocal sentAdd, sentBest = table.clone(st.add), table.clone(st.best)\n'
 '\tlocal sentAAdd, sentABest, sentN = table.clone(st.aadd), table.clone(st.abest), table.clone(st.ach.n) -- v1.1\n'),
('\t\t\tlocal v = clean(old)\n\t\t\tif (v.day or -1) > d then stored = v return v end',
 '\t\t\tlocal v = clean(old)\n'
 '\t\t\tfor s, n in pairs(sentAAdd) do v.ach.p[s] = (tonumber(v.ach.p[s]) or 0) + n end -- v1.1: achievements first (any day)\n'
 '\t\t\tfor s, n in pairs(sentABest) do v.ach.p[s] = math.max(tonumber(v.ach.p[s]) or 0, n) end\n'
 '\t\t\tfor k in pairs(sentN) do v.ach.n[k] = true end\n'
 '\t\t\tif (v.day or -1) > d then stored = v return v end'),
('\tfor id, n in pairs(sentBest) do if (st.best[id] or 0) <= n then st.best[id] = nil end end\n\tst.dirty = next(st.add) ~= nil or next(st.best) ~= nil\n',
 '\tfor id, n in pairs(sentBest) do if (st.best[id] or 0) <= n then st.best[id] = nil end end\n'
 '\tfor s, n in pairs(sentAAdd) do -- v1.1\n'
 '\t\tst.aadd[s] = (st.aadd[s] or 0) - n\n'
 '\t\tif st.aadd[s] <= 0 then st.aadd[s] = nil end\n'
 '\tend\n'
 '\tfor s, n in pairs(sentABest) do if (st.abest[s] or 0) <= n then st.abest[s] = nil end end\n'
 '\tst.dirty = next(st.add) ~= nil or next(st.best) ~= nil or next(st.aadd) ~= nil or next(st.abest) ~= nil -- v1.1: + achievements\n'),
('\t\tlastChange = 0, lastRead = 0, busy = false}\n',
 '\t\tlastChange = 0, lastRead = 0, busy = false}\n'
 '\tst.ach, st.aadd, st.abest = {p = {}, c = {}, n = {}}, {}, {} -- v1.1\n'),
('-- progress\nlocal function add(player, ev, n, value)\n\tlocal st = states[player]\n',
 '-- v1.1: achievement counters (deltas / bests, saved with the quests)\n'
 'local function achAdd(st, ev, n, value)\n'
 '\tif not achOn() or not st.ach then return end\n'
 '\tlocal used = false\n'
 '\tfor _, x in ipairs(AR.LIST) do if x.stat == ev then used = true break end end\n'
 '\tif not used then return end\n'
 '\tif AR.MAX_STATS[ev] then\n'
 '\t\tif (value or 0) > math.max(tonumber(st.ach.p[ev]) or 0, st.abest[ev] or 0) then st.abest[ev] = value else return end\n'
 '\telse\n'
 '\t\tst.aadd[ev] = (st.aadd[ev] or 0) + (n or 0)\n'
 '\tend\n'
 '\tst.dirty = true\n'
 '\tst.lastChange = os.clock()\n'
 'end\n'
 '-- progress\nlocal function add(player, ev, n, value)\n\tlocal st = states[player]\n'
 '\tif st and st.loaded then achAdd(st, ev, n, value) end -- v1.1\n'),
('\tplayer:GetAttributeChangedSignal("StatIslandBest"):Connect(function() publish(player) end)\n',
 '\tplayer:GetAttributeChangedSignal("StatIslandBest"):Connect(function() publish(player) end)\n'
 '\tfor _, k in ipairs({"OwnedDinos", "SkinOwnedU", "SkillLevel"}) do -- v1.1: live achievement stats\n'
 '\t\tplayer:GetAttributeChangedSignal(k):Connect(function() publish(player) end)\n'
 '\tend\n'
 '\tlocal lastAS -- v1.1: Arena win streak rises after the record is ready -> "awstreak" (max)\n'
 '\tplayer:GetAttributeChangedSignal("ArenaStreak"):Connect(function()\n'
 '\t\tlocal v = tonumber(player:GetAttribute("ArenaStreak")) or 0\n'
 '\t\tlocal was = lastAS\n'
 '\t\tlastAS = v\n'
 '\t\tif player:GetAttribute("ArenaRecordReady") ~= true or was == nil or v <= was then return end\n'
 '\t\tadd(player, "awstreak", 0, v)\n'
 '\t\tpublish(player)\n'
 '\tend)\n'
 '\tif player:GetAttribute("ArenaRecordReady") == true then lastAS = tonumber(player:GetAttribute("ArenaStreak")) or 0 end\n'
 '\tplayer:GetAttributeChangedSignal("ArenaRecordReady"):Connect(function()\n'
 '\t\tif player:GetAttribute("ArenaRecordReady") == true then lastAS = tonumber(player:GetAttribute("ArenaStreak")) or 0 end\n'
 '\tend)\n'),
('-- rewards\nlocal function grant(player, id)\n',
 '-- rewards\nlocal function grant(player, id)\n'
 '\tif id:sub(1, 2) == "a_" then -- v1.1: achievements pay 2 / 5 / 10 by medal\n'
 '\t\tlocal x = AR.BY_ID[id:sub(3)]\n'
 '\t\tlocal sk = ServerScriptService:FindFirstChild("SkillServer")\n'
 '\t\tlocal fn = sk and sk:FindFirstChild("SkillGrantPoints")\n'
 '\t\tif not (x and fn) then return false end\n'
 '\t\tlocal ok, r = pcall(function() return fn:Invoke(player, AR.pts(x), "achievement") end)\n'
 '\t\treturn ok and r == "ok"\n'
 '\tend\n'),
('local function claim(player, id)\n',
 '-- v1.1: claim an achievement (the caller checked hub, loaded, near, busy)\n'
 'local function achHave(player, st, x)\n'
 '\tif AR.LIVE_STATS[x.stat] then\n'
 '\t\treturn AR.liveStats(player:GetAttribute("OwnedDinos"), player:GetAttribute("SkinOwnedU"), player:GetAttribute("SkillLevel"))[x.stat]\n'
 '\tend\n'
 '\tif AR.MAX_STATS[x.stat] then return math.max(tonumber(st.ach.p[x.stat]) or 0, st.abest[x.stat] or 0) end\n'
 '\treturn (tonumber(st.ach.p[x.stat]) or 0) + (st.aadd[x.stat] or 0)\n'
 'end\n'
 'local function claimAch(player, st, id)\n'
 '\tlocal x = AR.BY_ID[id:sub(3)]\n'
 '\tif not x then return "unknown" end\n'
 '\tst.busy = true\n'
 '\tif st.dirty and not save(player) then st.busy = false return "failed" end\n'
 '\tlocal result = "failed"\n'
 '\tif not store then\n'
 '\t\tif st.ach.c[x.id] then result = "claimed" elseif achHave(player, st, x) < x.need then result = "notReady"\n'
 '\t\telse st.ach.c[x.id], st.pend[id], result = true, true, "ok" end\n'
 '\telse\n'
 '\t\tlocal liveHave = AR.LIVE_STATS[x.stat] and achHave(player, st, x) or nil\n'
 '\t\tlocal stored\n'
 '\t\tlocal ok = pcall(function()\n'
 '\t\t\tstore:UpdateAsync("u" .. player.UserId, function(old)\n'
 '\t\t\t\tlocal v = clean(old)\n'
 '\t\t\t\tstored, result = v, "failed"\n'
 '\t\t\t\tif v.ach.c[x.id] then result = "claimed" return nil end\n'
 '\t\t\t\tlocal h = liveHave or tonumber(v.ach.p[x.stat]) or 0\n'
 '\t\t\t\tif h < x.need then result = "notReady" return nil end\n'
 '\t\t\t\tv.ach.c[x.id] = true\n'
 '\t\t\t\tv.pend[id] = true\n'
 '\t\t\t\tresult = "ok"\n'
 '\t\t\t\treturn v\n'
 '\t\t\tend)\n'
 '\t\tend)\n'
 '\t\tif not ok then result = "failed" end\n'
 '\t\tif result == "ok" and stored then adopt(player, st, stored) end\n'
 '\tend\n'
 '\tst.busy = false\n'
 '\tif result == "ok" then\n'
 '\t\tbump("QuestClaims")\n'
 '\t\tplayer:SetAttribute("QuestLastClaim", id)\n'
 '\t\tif grant(player, id) then clearPend(player, id) end\n'
 '\tend\n'
 '\tpublish(player)\n'
 '\treturn result\n'
 'end\n'
 'local function claim(player, id)\n'),
('\tif not q then return "unknown" end\n\tst.busy = true\n',
 '\tif not q and id:sub(1, 2) == "a_" and achOn() then return claimAch(player, st, id) end -- v1.1\n'
 '\tif not q then return "unknown" end\n\tst.busy = true\n'),
('\tif result == "ok" then\n\t\tbump("QuestClaims")\n\t\tplayer:SetAttribute("QuestLastClaim", id)\n\t\tif grant(player, id) then clearPend(player, id) end\n\tend\n\tpublish(player)\n\treturn result\nend\n\nlocal function view',
 '\tif result == "ok" then\n\t\tbump("QuestClaims")\n\t\tplayer:SetAttribute("QuestLastClaim", id)\n'
 '\t\tif not special then achAdd(st, "qclaim", 1) end -- v1.1: Quest Fan\n'
 '\t\tif grant(player, id) then clearPend(player, id) end\n\tend\n\tpublish(player)\n\treturn result\nend\n\nlocal function view'),
('\tout.ready = readyCount(player, st)\n\treturn out\n',
 '\tout.ready = readyCount(player, st)\n'
 '\tif achOn() and st.ach then -- v1.1\n'
 '\t\tout.achievements, out.achReady, out.achGot, out.achPts = {}, 0, 0, 0\n'
 '\t\tfor _, x in ipairs(AR.LIST) do\n'
 '\t\t\tlocal h = achHave(player, st, x)\n'
 '\t\t\tlocal c = st.ach.c[x.id] == true\n'
 '\t\t\ttable.insert(out.achievements, {id = "a_" .. x.id, name = x.name, text = x.text, where = x.where, medal = x.medal,\n'
 '\t\t\t\thave = math.min(h, x.need), need = x.need, pts = AR.pts(x), claimed = c})\n'
 '\t\t\tif AR.claimable(x, h, c) then out.achReady += 1 end\n'
 '\t\t\tif c then out.achGot += 1 out.achPts += AR.pts(x) end\n'
 '\t\tend\n'
 '\tend\n'
 '\treturn out\n'),
]
src = open(os.path.join(ROOT, 'src/server/QuestServer.server.luau'), encoding='utf-8').read()
for o, n in P:
    assert src.count(o) == 1, (src.count(o), o[:70])
    src = src.replace(o, n)
open(os.path.join(ROOT, 'src/server/QuestServer.server.luau'), 'w', encoding='utf-8').write(src)
print('applied', len(P))
