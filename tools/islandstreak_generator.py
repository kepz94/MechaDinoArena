# islandstreak_generator v1.0 — writes tools/islandstreak_patch_<Name>.luau for ISLAND_STREAK_v1.0 (roadmap piece 3).
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEPU = ('Kepu 2026-11-26 "a fire streak emblem once you go on a killing spree on the main island. 25 kills streak unlocks the\n'
        '--   thunder storm skin. 10 kill streak unlocks the zebra"')
F = {}
F['UniversalSkins'] = ('src/shared/UniversalSkins.luau', [
('US.VERSION = "1.3" -- v1.3 price steps bland 149 / glowing 499 / animated 999 (v1.2 Prism 999; v1.1 whole-body animation)',
 'US.VERSION = "1.3" -- v1.3 price steps bland 149 / glowing 499 / animated 999 (v1.2 Prism 999; v1.1 whole-body animation)\n'
 'US.VERSION = "1.4" -- v1.4 island streak unlocks (Zebra 10, Storm Front 25)\n'
 f'-- v1.4 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 1; {KEPU}; roadmap D3 "Streak replaces old";\n'
 '--   Storm Front "Earn only"): with US.ISLAND_STREAK_UNLOCKS (true) Zebra unlocks at a 10 kill streak on the island and Storm Front\n'
 '--   at a 25 kill streak (earn stat "istreak" = stats.istreak, SkinServer / Lab: max(StatIslandBest, IslandStreak) from SkinStats\n'
 '--   1.1). Storm Front is no longer a Robux skin (owners keep it); its look, anim and ORDER place are unchanged. false = 1.3.'),
('}\nfor id, sk in pairs(US.SKINS) do\n',
 '}\nUS.ISLAND_STREAK_UNLOCKS = true -- v1.4\n'
 'if US.ISLAND_STREAK_UNLOCKS then\n'
 '\tUS.SKINS.zebra.unlock = earn("istreak", 10, "Get a 10 kill streak on the island")\n'
 '\tUS.SKINS.storm.unlock = earn("istreak", 25, "Get a 25 kill streak on the island")\n'
 'end\nfor id, sk in pairs(US.SKINS) do\n'),
('\telseif s == "best" then have = tonumber(stats.best) or 0 end',
 '\telseif s == "best" then have = tonumber(stats.best) or 0\n\telseif s == "istreak" then have = tonumber(stats.istreak) or 0 end -- v1.4'),
])
F['SkinStats'] = ('src/server/SkinStats.server.luau', [
('local VERSION = "1.0"\n',
 'local VERSION = "1.0"\nVERSION = "1.1" -- v1.1 island kill streak\n'
 f'-- v1.1 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 2; {KEPU}; kills of players and bots, main island\n'
 '--   only; picks "Death or menu"): every counted kill (after the dedupe above) also adds 1 to the killer\'s island streak when\n'
 '--   script attribute SkinStatsIslandStreakEnabled ~= false, ReplicatedStorage ServerKind == "hub", the killer\'s TutLane is not\n'
 '--   > 0 and the killer\'s Humanoid is alive. The streak goes back to 0 when the killer\'s Humanoid dies, on a new character and\n'
 '--   when the player\'s InMenu turns true. Best island streak = max(best, streak), saved as ib in the same UpdateAsync merge\n'
 '--   (ib = max(stored, ours); v stays 1) and loaded with the rest. Player attributes IslandStreak (current) and StatIslandBest\n'
 '--   (best). Diagnostics: script IslandStreakCounted, IslandStreakResets. false = 1.0.'),
('\tplayer:SetAttribute("SkinStatsReady", st.loaded)\n',
 '\tplayer:SetAttribute("SkinStatsReady", st.loaded)\n'
 '\tplayer:SetAttribute("IslandStreak", st.istreak or 0) -- v1.1\n'
 '\tplayer:SetAttribute("StatIslandBest", st.ib or 0) -- v1.1\n'),
('\tif st.pending == 0 and not st.bestDirty then return end\n\tlocal add, best = st.pending, st.best\n',
 '\tif st.pending == 0 and not st.bestDirty and not st.ibDirty then return end -- v1.1: + ibDirty\n\tlocal add, best = st.pending, st.best\n'
 '\tlocal ib = st.ib or 0 -- v1.1\n'),
('\t\t\t\tv.best = math.max(tonumber(v.best) or 0, best)\n',
 '\t\t\t\tv.best = math.max(tonumber(v.best) or 0, best)\n\t\t\t\tv.ib = math.max(tonumber(v.ib) or 0, ib) -- v1.1\n'),
('\t\tif st.best == best then st.bestDirty = false end\n',
 '\t\tif st.best == best then st.bestDirty = false end\n'
 '\t\tst.ib = math.max(st.ib or 0, tonumber(stored.ib) or 0) -- v1.1\n'
 '\t\tif st.ib == ib then st.ibDirty = false end\n'),
('\t\t\t\tst.best = math.max(st.best, math.floor(tonumber(value.best) or 0))\n',
 '\t\t\t\tst.best = math.max(st.best, math.floor(tonumber(value.best) or 0))\n'
 '\t\t\t\tst.ib = math.max(st.ib or 0, math.floor(tonumber(value.ib) or 0)) -- v1.1\n'),
('\tstates[player] = {loaded = false, k = 0, pending = 0, best = 0, bestDirty = false, lastChange = 0}\n',
 '\tstates[player] = {loaded = false, k = 0, pending = 0, best = 0, bestDirty = false, lastChange = 0}\n'
 '\tstates[player].istreak, states[player].ib, states[player].ibDirty = 0, 0, false -- v1.1\n'),
('\tplayer:GetAttributeChangedSignal("ArenaStreak"):Connect(function() onStreak(player) end)\n\tonStreak(player)\n',
 '\tplayer:GetAttributeChangedSignal("ArenaStreak"):Connect(function() onStreak(player) end)\n\tonStreak(player)\n'
 '\tlocal function resetStreak() -- v1.1: death, a new body or the menu ends the island streak\n'
 '\t\tlocal s = states[player]\n'
 '\t\tif s and (s.istreak or 0) > 0 then\n'
 '\t\t\ts.istreak = 0\n'
 '\t\t\tbump("IslandStreakResets")\n'
 '\t\t\tpublish(player)\n'
 '\t\tend\n'
 '\tend\n'
 '\tlocal function hookChar(c)\n'
 '\t\tresetStreak()\n'
 '\t\tlocal hum = c:WaitForChild("Humanoid", 10)\n'
 '\t\tif hum then hum.Died:Connect(resetStreak) end\n'
 '\tend\n'
 '\tplayer.CharacterAdded:Connect(hookChar)\n'
 '\tif player.Character then task.spawn(hookChar, player.Character) end\n'
 '\tplayer:GetAttributeChangedSignal("InMenu"):Connect(function()\n'
 '\t\tif player:GetAttribute("InMenu") == true then resetStreak() end\n'
 '\tend)\n'),
('-- kills\nlocal seen = setmetatable({}, {__mode = "k"})',
 '-- v1.1: the island streak part of a counted kill\n'
 'if script:GetAttribute("SkinStatsIslandStreakEnabled") == nil then script:SetAttribute("SkinStatsIslandStreakEnabled", true) end\n'
 'script:SetAttribute("IslandStreakCounted", 0)\n'
 'script:SetAttribute("IslandStreakResets", 0)\n'
 'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n'
 'local function islandKill(player, st)\n'
 '\tif script:GetAttribute("SkinStatsIslandStreakEnabled") == false or ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" then return end\n'
 '\tif (tonumber(player:GetAttribute("TutLane")) or 0) > 0 then return end\n'
 '\tlocal c = player.Character\n'
 '\tlocal hum = c and c:FindFirstChildOfClass("Humanoid")\n'
 '\tif not (hum and hum.Health > 0) then return end\n'
 '\tst.istreak = (st.istreak or 0) + 1\n'
 '\tif st.istreak > (st.ib or 0) then\n'
 '\t\tst.ib = st.istreak\n'
 '\t\tst.ibDirty = true\n'
 '\tend\n'
 '\tbump("IslandStreakCounted")\n'
 'end\n'
 '-- kills\nlocal seen = setmetatable({}, {__mode = "k"})'),
('\tbump("SkinStatsCounted")\n', '\tbump("SkinStatsCounted")\n\tislandKill(player, st) -- v1.1\n'),
('if st.loaded and (st.pending > 0 or st.bestDirty) and', 'if st.loaded and (st.pending > 0 or st.bestDirty or st.ibDirty) and'),
])
F['SkinServer'] = ('src/server/SkinServer.server.luau', [
('VERSION = "1.5" -- v1.5 SkinPaintBot for filler bots',
 'VERSION = "1.5" -- v1.5 SkinPaintBot for filler bots\nVERSION = "1.6" -- v1.6 island streak earn stat\n'
 '-- v1.6 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 3): the earn stats also carry istreak =\n'
 '--   max(StatIslandBest, IslandStreak) (SkinStats 1.1) for UniversalSkins 1.4 (Zebra 10, Storm Front 25), and a change of\n'
 '--   IslandStreak / StatIslandBest runs the earn check. Switch: script attribute SkinIslandStreakEarnEnabled (default true, read\n'
 '--   per check; false = istreak 0, so the streak skins stay locked).'),
('\treturn {w = player:GetAttribute("ArenaW"), l = player:GetAttribute("ArenaL"), kills = player:GetAttribute("StatKills"), best = streak}',
 '\tlocal istreak = script:GetAttribute("SkinIslandStreakEarnEnabled") ~= false -- v1.6\n'
 '\t\tand math.max(tonumber(player:GetAttribute("StatIslandBest")) or 0, tonumber(player:GetAttribute("IslandStreak")) or 0) or 0\n'
 '\treturn {w = player:GetAttribute("ArenaW"), l = player:GetAttribute("ArenaL"), kills = player:GetAttribute("StatKills"), best = streak,\n'
 '\t\tistreak = istreak}'),
('\t\tSkinStatsReady = true}\n', '\t\tSkinStatsReady = true, IslandStreak = true, StatIslandBest = true} -- v1.6: + island streak\n'),
])
F['Lab'] = ('src/client/Lab.client.luau', [
('VERSION = "2.1" -- v2.1 Looks Lab v1.0: owned first, locked tiles say why, emote wheel on the left',
 'VERSION = "2.1" -- v2.1 Looks Lab v1.0: owned first, locked tiles say why, emote wheel on the left\n'
 'VERSION = "2.2" -- v2.2 island streak progress\n'
 '-- v2.2 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 4): uniStats() also carries istreak = max(StatIslandBest,\n'
 '--   IslandStreak) (SkinStats 1.1), so the Zebra and Storm Front cards (UniversalSkins 1.4) show their island streak progress through\n'
 '--   the existing earn card path. No layout change.'),
('\t\tbest = math.max(tonumber(player:GetAttribute("StatBestStreak")) or 0, tonumber(player:GetAttribute("ArenaStreak")) or 0)}',
 '\t\tbest = math.max(tonumber(player:GetAttribute("StatBestStreak")) or 0, tonumber(player:GetAttribute("ArenaStreak")) or 0),\n'
 '\t\tistreak = math.max(tonumber(player:GetAttribute("StatIslandBest")) or 0, tonumber(player:GetAttribute("IslandStreak")) or 0)} -- v2.2'),
])
FLAME = r'''
-- v1.7: island kill streak flame badge (plan docs/plans/ISLAND_STREAK_v1.0.md Task 5)
local TweenService = game:GetService("TweenService")
local FL = {"...a...", "..aa...", "..aba..", ".abba.a", ".abbbaa", "abbcbba", "abcccba", "abcccba", ".abcba."}
local TIER_COLS = {
	{a = Color3.fromRGB(255, 90, 30), b = Color3.fromRGB(255, 155, 46), c = Color3.fromRGB(255, 228, 92), o = Color3.fromRGB(255, 138, 30)},
	{a = Color3.fromRGB(43, 123, 255), b = Color3.fromRGB(79, 182, 255), c = Color3.fromRGB(216, 243, 255), o = Color3.fromRGB(79, 182, 255)},
	{a = Color3.fromRGB(122, 43, 255), b = Color3.fromRGB(184, 107, 255), c = Color3.fromRGB(242, 227, 255), o = Color3.fromRGB(184, 107, 255)},
}
for k, v in pairs({IslandTagsStreakEnabled = true, IslandTagsStreakMin = 1, IslandTagsStreakTier2 = 10, IslandTagsStreakTier3 = 25,
	IslandTagsStreakFlicker = 0.25}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function reducedMotion()
	local ok, v = pcall(function() return game:GetService("GuiService").ReducedMotionEnabled end)
	return ok and v == true
end
local function makeStreak(parent)
	local b = Instance.new("Frame")
	b.Name = "Streak"
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.BackgroundColor3 = Color3.fromRGB(11, 15, 22)
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.Visible = false
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local fl = Instance.new("Frame")
	fl.Name = "Flame"
	fl.BackgroundTransparency = 1
	fl.AnchorPoint = Vector2.new(0, 0.5)
	fl.Parent = b
	local cells = {}
	for y, row in ipairs(FL) do -- one Frame per run of same-colour cells in a row
		local x = 1
		while x <= 7 do
			local ch = row:sub(x, x)
			local x2 = x
			while x2 < 7 and row:sub(x2 + 1, x2 + 1) == ch do x2 += 1 end
			if ch ~= "." then
				local r = Instance.new("Frame")
				r.BorderSizePixel = 0
				r.Position = UDim2.fromScale((x - 1) / 7, (y - 1) / 9)
				r.Size = UDim2.fromScale((x2 - x + 1) / 7, 1 / 9)
				r.Parent = fl
				table.insert(cells, {f = r, ch = ch})
			end
			x = x2 + 1
		end
	end
	local n = Instance.new("TextLabel")
	n.Name = "Count"
	n.BackgroundTransparency = 1
	n.FontFace = SILK
	n:SetAttribute("FontSwap", "keep")
	n.TextColor3 = Color3.new(1, 1, 1)
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.AnchorPoint = Vector2.new(0, 0.5)
	n.Parent = b
	return {frame = b, stroke = stroke, scale = scale, flame = fl, cells = cells, count = n, n = 0, tier = 0, lit = nil}
end
local function hideStreak(t) if t.streak then t.streak.frame.Visible = false t.streak.n = 0 end end
-- sizes / colours the badge for p (h = the name line height) and returns its width + 5 px gap; 0 = hidden. The caller places it.
local function sizeStreak(t, p, h)
	local n = script:GetAttribute("IslandTagsStreakEnabled") ~= false and math.floor(tonumber(p:GetAttribute("IslandStreak")) or 0) or 0
	if n < (tonumber(script:GetAttribute("IslandTagsStreakMin")) or 1) then hideStreak(t) return 0 end
	local s = t.streak
	if not s then s = makeStreak(t.frame) t.streak = s end
	local tier = n >= (tonumber(script:GetAttribute("IslandTagsStreakTier3")) or 25) and 3
		or (n >= (tonumber(script:GetAttribute("IslandTagsStreakTier2")) or 10) and 2 or 1)
	local still = reducedMotion()
	local step = tonumber(script:GetAttribute("IslandTagsStreakFlicker")) or 0.25
	local lit = still or step <= 0 or (math.floor(os.clock() / step) % 2 == 0)
	if s.tier ~= tier or s.lit ~= lit then
		s.tier, s.lit = tier, lit
		local cols = TIER_COLS[tier]
		s.stroke.Color = cols.o
		for _, c in ipairs(s.cells) do
			c.f.BackgroundColor3 = cols[(not lit and c.ch == "c") and "b" or c.ch] -- flicker: the core dims every other step
		end
	end
	local fh = math.max(8, h - 6)
	local fw = math.floor(fh * 7 / 9 + 0.5)
	local ts = math.max(10, h - 4)
	if s.count.TextSize ~= ts then s.count.TextSize = ts end
	local txt = tostring(n)
	if s.count.Text ~= txt then s.count.Text = txt end
	local cw = math.ceil(s.count.TextBounds.X)
	s.flame.Size = UDim2.fromOffset(fw, fh)
	s.flame.Position = UDim2.new(0, 4, 0.5, 0)
	s.count.Size = UDim2.fromOffset(cw + 1, h)
	s.count.Position = UDim2.new(0, 4 + fw + 3, 0.5, 0)
	local w = 4 + fw + 3 + cw + 5
	s.frame.Size = UDim2.fromOffset(w, h)
	if n > s.n and not still then -- a short pop when the count goes up
		s.scale.Scale = 1.4
		TweenService:Create(s.scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
	s.n = n
	s.frame.Visible = true
	return w + 5
end
'''
F['IslandTags'] = ('src/client/IslandTags.client.luau', [
('VERSION = "1.6" -- v1.6 filler bots tagged',
 'VERSION = "1.6" -- v1.6 filler bots tagged\nVERSION = "1.7" -- v1.7 island streak flame\n'
 f'-- v1.7 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 5, mockup docs/mockups/island_streak_v0.1.html; {KEPU};\n'
 '--   picks "A · Tag flame", "After first kill", red-team "Flame first"): in the one-line tag (v1.4) a player whose IslandStreak\n'
 '--   (SkinStats 1.1) is at least IslandTagsStreakMin (1) gets a flame badge first in the line: [flame N] [rank] NAME 1W 0L, the\n'
 '--   whole group centred as before. Badge = a dark plate (rgb 11,15,22 at 0.2) with a 2 px tier outline and 5 px corners, a 7 x 9\n'
 '--   pixel flame (row runs of Frames) and the count (Silkscreen Bold, white); height = the name line, 5 px gap. Tiers: 1-9 orange,\n'
 '--   from IslandTagsStreakTier2 (10) blue, from IslandTagsStreakTier3 (25) violet. A pop (scale 1.4 -> 1 over 0.3 s) when the count\n'
 '--   goes up and a two-step core flicker (IslandTagsStreakFlicker 0.25 s), both off with Reduced Motion. Bots never show it.\n'
 '--   Other looks (1.0 / 1.1 / 1.3): no badge. Switch: script attribute IslandTagsStreakEnabled (default true, read per frame).'),
('\nlocal function anchorOf(model)', FLAME.rstrip('\n') + '\n\nlocal function anchorOf(model)'),
('\t\t\t\t\t\tlocal badgeW = (t.badge and t.badge.Visible) and (t.badge.AbsoluteSize.X + 5) or 0 -- last frame\'s badge\n'
 '\t\t\t\t\t\tlocal groupW = badgeW + nameW + (ready and (gapN + numsW) or 0)\n'
 '\t\t\t\t\t\tlocal left = -groupW / 2\n'
 '\t\t\t\t\t\tdx = math.floor(left + badgeW + nameW / 2 + 0.5)\n'
 '\t\t\t\t\t\tt.name.Position = UDim2.fromOffset(dx, 0)\n'
 '\t\t\t\t\t\tt.nums.Size = UDim2.fromOffset(math.ceil(numsW) + 2, us + 2)\n'
 '\t\t\t\t\t\tt.nums.Position = UDim2.new(0.5, math.floor(left + badgeW + nameW + gapN + 0.5), 0, math.floor((ns - us) / 2))\n',
 '\t\t\t\t\t\tlocal badgeW = (t.badge and t.badge.Visible) and (t.badge.AbsoluteSize.X + 5) or 0 -- last frame\'s badge\n'
 '\t\t\t\t\t\tlocal flameW = sizeStreak(t, e.p, ns + 2) -- v1.7: 0 when no streak\n'
 '\t\t\t\t\t\tlocal groupW = flameW + badgeW + nameW + (ready and (gapN + numsW) or 0)\n'
 '\t\t\t\t\t\tlocal left = -groupW / 2\n'
 '\t\t\t\t\t\tif flameW > 0 then t.streak.frame.Position = UDim2.new(0.5, math.floor(left + 0.5), 0, math.floor((ns + 2) / 2)) end -- v1.7\n'
 '\t\t\t\t\t\tdx = math.floor(left + flameW + badgeW + nameW / 2 + 0.5)\n'
 '\t\t\t\t\t\tt.name.Position = UDim2.fromOffset(dx, 0)\n'
 '\t\t\t\t\t\tt.nums.Size = UDim2.fromOffset(math.ceil(numsW) + 2, us + 2)\n'
 '\t\t\t\t\t\tt.nums.Position = UDim2.new(0.5, math.floor(left + flameW + badgeW + nameW + gapN + 0.5), 0, math.floor((ns - us) / 2))\n'),
('\t\t\t\t\telse\n\t\t\t\t\t\tif t.name.Position ~= UDim2.new() then t.name.Position = UDim2.new() end\n',
 '\t\t\t\t\telse\n\t\t\t\t\t\thideStreak(t) -- v1.7: one line only\n\t\t\t\t\t\tif t.name.Position ~= UDim2.new() then t.name.Position = UDim2.new() end\n'),
('\t\t\t\tplaceBadge(t, e.p, small, nS + 2) -- v1.2\n',
 '\t\t\t\thideStreak(t) -- v1.7: one line only\n\t\t\t\tplaceBadge(t, e.p, small, nS + 2) -- v1.2\n'),
])
TAIL = '''}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
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
    out = [f'-- islandstreak_patch_{name}: ISLAND_STREAK_v1.0.\nlocal PAIRS = {{\n']
    for o, n in pairs_:
        assert not o.startswith('\n') or o.startswith('\nlocal function anchorOf'), name
        assert src.count(o) == 1, (name, src.count(o), o[:70])
        assert ']=====]' not in o + n
        out.append('{[=====[' + o + ']=====], [=====[' + n + ']=====]},\n')
    open(os.path.join(ROOT, 'tools', f'islandstreak_patch_{name}.luau'), 'w', encoding='utf-8').write(''.join(out) + TAIL)
    print('wrote', name, len(pairs_))
