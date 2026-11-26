-- islandstreak_patch_IslandTags: ISLAND_STREAK_v1.0.
local PAIRS = {
{[=====[VERSION = "1.6" -- v1.6 filler bots tagged]=====], [=====[VERSION = "1.6" -- v1.6 filler bots tagged
VERSION = "1.7" -- v1.7 island streak flame
-- v1.7 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 5, mockup docs/mockups/island_streak_v0.1.html; Kepu 2026-11-26 "a fire streak emblem once you go on a killing spree on the main island. 25 kills streak unlocks the
--   thunder storm skin. 10 kill streak unlocks the zebra";
--   picks "A · Tag flame", "After first kill", red-team "Flame first"): in the one-line tag (v1.4) a player whose IslandStreak
--   (SkinStats 1.1) is at least IslandTagsStreakMin (1) gets a flame badge first in the line: [flame N] [rank] NAME 1W 0L, the
--   whole group centred as before. Badge = a dark plate (rgb 11,15,22 at 0.2) with a 2 px tier outline and 5 px corners, a 7 x 9
--   pixel flame (row runs of Frames) and the count (Silkscreen Bold, white); height = the name line, 5 px gap. Tiers: 1-9 orange,
--   from IslandTagsStreakTier2 (10) blue, from IslandTagsStreakTier3 (25) violet. A pop (scale 1.4 -> 1 over 0.3 s) when the count
--   goes up and a two-step core flicker (IslandTagsStreakFlicker 0.25 s), both off with Reduced Motion. Bots never show it.
--   Other looks (1.0 / 1.1 / 1.3): no badge. Switch: script attribute IslandTagsStreakEnabled (default true, read per frame).]=====]},
{[=====[
local function anchorOf(model)]=====], [=====[
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

local function anchorOf(model)]=====]},
{[=====[						local badgeW = (t.badge and t.badge.Visible) and (t.badge.AbsoluteSize.X + 5) or 0 -- last frame's badge
						local groupW = badgeW + nameW + (ready and (gapN + numsW) or 0)
						local left = -groupW / 2
						dx = math.floor(left + badgeW + nameW / 2 + 0.5)
						t.name.Position = UDim2.fromOffset(dx, 0)
						t.nums.Size = UDim2.fromOffset(math.ceil(numsW) + 2, us + 2)
						t.nums.Position = UDim2.new(0.5, math.floor(left + badgeW + nameW + gapN + 0.5), 0, math.floor((ns - us) / 2))
]=====], [=====[						local badgeW = (t.badge and t.badge.Visible) and (t.badge.AbsoluteSize.X + 5) or 0 -- last frame's badge
						local flameW = sizeStreak(t, e.p, ns + 2) -- v1.7: 0 when no streak
						local groupW = flameW + badgeW + nameW + (ready and (gapN + numsW) or 0)
						local left = -groupW / 2
						if flameW > 0 then t.streak.frame.Position = UDim2.new(0.5, math.floor(left + 0.5), 0, math.floor((ns + 2) / 2)) end -- v1.7
						dx = math.floor(left + flameW + badgeW + nameW / 2 + 0.5)
						t.name.Position = UDim2.fromOffset(dx, 0)
						t.nums.Size = UDim2.fromOffset(math.ceil(numsW) + 2, us + 2)
						t.nums.Position = UDim2.new(0.5, math.floor(left + flameW + badgeW + nameW + gapN + 0.5), 0, math.floor((ns - us) / 2))
]=====]},
{[=====[					else
						if t.name.Position ~= UDim2.new() then t.name.Position = UDim2.new() end
]=====], [=====[					else
						hideStreak(t) -- v1.7: one line only
						if t.name.Position ~= UDim2.new() then t.name.Position = UDim2.new() end
]=====]},
{[=====[				placeBadge(t, e.p, small, nS + 2) -- v1.2
]=====], [=====[				hideStreak(t) -- v1.7: one line only
				placeBadge(t, e.p, small, nS + 2) -- v1.2
]=====]},
}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
local m = Instance.new("ModuleScript")
m.Source = "return function()\n" .. s .. "\nend"
m.Parent = workspace
local okC, errC = pcall(require, m)
m:Destroy()
if not okC then return "COMPILE FAIL " .. tostring(errC) end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
