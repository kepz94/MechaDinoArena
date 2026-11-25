-- RankBadge v1.0 (Mecha Dino Arena) — the worldwide rank badge chip, shared by the name tags, lineup, kill feed and boards
-- (ModuleScript, StarterPlayerScripts). Kepu 2026-11-24 15:44 "if you're ranked on the worldwide server you get a special
-- number badge by your name" (picks: top 100; island name tag, match name tags, pre-game lineup, kill feed); 16:08 badge look
-- "A but with a different font because it's not clear enough"; 16:22 font "Number 2" (Builder Sans) on mockup
-- docs/mockups/rank_badge_fonts_v0.2.html.
-- The badge: a TextLabel "#<rank>" (Builder Sans ExtraBold, dark ink rgb(27,20,6)) on a rounded chip with a dark outline;
--   chip colour by rank: 1 gold rgb(255,200,50), 2 silver rgb(207,216,230), 3 bronze rgb(224,153,90), 4-10 blue
--   rgb(127,233,255), 11-RankBadgeMax grey rgb(159,176,200). FontSwap "keep" (FontSwap 1.0 leaves it alone). One TextLabel
--   (no child frames), so code that fades a line's TextLabels fades the badge too.
-- API:
--   rankOf(player) -> the player's WorldRank (LeaderboardServer 1.0) when 1..RankBadgeMax and RankBadgesEnabled ~= false, else nil.
--   new(size) -> a hidden badge TextLabel (Name "RankBadge", AutomaticSize XY).
--   set(badge, rank, size) -> shows "#<rank>" in the tier colour at TextSize size (padding / corner / outline scale with it);
--     rank nil / not 1..RankBadgeMax -> hidden. Returns true when shown.
-- Switches (attributes on this ModuleScript): RankBadgesEnabled (true; false = no badge anywhere), RankBadgeMax (100).
-- v1.1 (Kepu 2026-11-24 22:21 "for people ranked in the top 10 let the border for their number be rainbow"; 22:27 picks on
--   mockup docs/mockups/postmatch_tags_v0.1.html: "spins", "Everywhere"): a badge with rank 1..RankBadgeRainbowMax (10) gets a
--   rainbow outline: the UIStroke turns opaque white (Transparency 0) with a UIGradient "Rainbow" child (red, orange, yellow,
--   green, blue, purple, pink, red), thickness max(2, floor(size x RankBadgeRainbowThick 0.17)) (was max(1, floor(size x 0.12))
--   at 45% black). The chip colour is unchanged (gold / silver / bronze / blue). The gradient turns once every
--   RankBadgeRainbowSpin (2.4) s (one RenderStepped loop in this module for every rainbow badge; 0 = still). Ranks above the
--   max, or the switch off: the 1.0 outline (gradient disabled). Every spot that uses this module gets it (island tag, match
--   tags, pre-game lineup, kill feed, boards). Fades that tween the UIStroke's Transparency still work (the loop only turns
--   the gradient). Switch: RankBadgeRainbowEnabled (default true, read per set). Diagnostic: RankBadgeRainbows (live count).
local M = {}
M.VERSION = "1.0"
M.VERSION = "1.1" -- v1.1 top-10 rainbow outline
M.FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
M.INK = Color3.fromRGB(27, 20, 6)
M.TIER = {Color3.fromRGB(255, 200, 50), Color3.fromRGB(207, 216, 230), Color3.fromRGB(224, 153, 90)}
M.TOP10 = Color3.fromRGB(127, 233, 255)
M.REST = Color3.fromRGB(159, 176, 200)

for k, v in pairs({RankBadgesEnabled = true, RankBadgeMax = 100,
	RankBadgeRainbowEnabled = true, RankBadgeRainbowMax = 10, RankBadgeRainbowThick = 0.17, RankBadgeRainbowSpin = 2.4}) do -- v1.1
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("RankBadgeVersion", M.VERSION)

local function max() return tonumber(script:GetAttribute("RankBadgeMax")) or 100 end

function M.valid(rank)
	rank = tonumber(rank)
	return rank ~= nil and rank >= 1 and rank <= max() and rank == math.floor(rank)
end

function M.rankOf(player)
	if script:GetAttribute("RankBadgesEnabled") == false then return nil end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return nil end
	local r = player:GetAttribute("WorldRank")
	return M.valid(r) and r or nil
end

function M.color(rank)
	return M.TIER[rank] or (rank <= 10 and M.TOP10) or M.REST
end

function M.new(size)
	local l = Instance.new("TextLabel")
	l.Name = "RankBadge"
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.new()
	l.BackgroundTransparency = 0
	l.BorderSizePixel = 0
	l.FontFace = M.FONT
	l.TextColor3 = M.INK
	l.Text = ""
	l.Visible = false
	l:SetAttribute("FontSwap", "keep")
	local c = Instance.new("UICorner") c.Parent = l
	local p = Instance.new("UIPadding") p.Parent = l
	local s = Instance.new("UIStroke") s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Color = Color3.new(0, 0, 0) s.Transparency = 0.45 s.Parent = l
	if size then M.size(l, size) end
	return l
end

function M.size(l, size)
	if l:GetAttribute("RankBadgeSize") == size then return end
	l:SetAttribute("RankBadgeSize", size)
	l.TextSize = size
	local c, p, s = l:FindFirstChildOfClass("UICorner"), l:FindFirstChildOfClass("UIPadding"), l:FindFirstChildOfClass("UIStroke")
	if c then c.CornerRadius = UDim.new(0, math.floor(size * 0.35)) end
	if p then
		p.PaddingLeft = UDim.new(0, math.floor(size * 0.45))
		p.PaddingRight = p.PaddingLeft
		p.PaddingTop = UDim.new(0, math.floor(size * 0.2))
		p.PaddingBottom = p.PaddingTop
	end
	if s then s.Thickness = math.max(1, math.floor(size * 0.12)) end
	l:SetAttribute("RankBadgeRainbowOn", nil) -- v1.1: the outline is re-painted by the next set
end

-- v1.1: the rainbow outline
M.RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 59, 59)), ColorSequenceKeypoint.new(1 / 7, Color3.fromRGB(255, 155, 46)),
	ColorSequenceKeypoint.new(2 / 7, Color3.fromRGB(255, 226, 59)), ColorSequenceKeypoint.new(3 / 7, Color3.fromRGB(70, 224, 138)),
	ColorSequenceKeypoint.new(4 / 7, Color3.fromRGB(59, 184, 255)), ColorSequenceKeypoint.new(5 / 7, Color3.fromRGB(138, 91, 255)),
	ColorSequenceKeypoint.new(6 / 7, Color3.fromRGB(255, 79, 216)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 59, 59))})
local spinning = {} -- [UIGradient] = true (a strong table: weak keys dropped the Instance proxies and the spin stopped; pruned when unparented / disabled)
local spinConn

local function spinStep()
	local per = tonumber(script:GetAttribute("RankBadgeRainbowSpin")) or 2.4
	local n = 0
	for g in pairs(spinning) do
		if g.Parent and g.Enabled then
			n += 1
			if per > 0 then g.Rotation = (os.clock() * 360 / per) % 360 end
		else
			spinning[g] = nil
		end
	end
	if script:GetAttribute("RankBadgeRainbows") ~= n then script:SetAttribute("RankBadgeRainbows", n) end
	if n == 0 and spinConn then spinConn:Disconnect() spinConn = nil end
end

local function paintOutline(l, rank)
	local s = l:FindFirstChildOfClass("UIStroke")
	if not s then return end
	local on = script:GetAttribute("RankBadgeRainbowEnabled") ~= false
		and rank <= (tonumber(script:GetAttribute("RankBadgeRainbowMax")) or 10)
	if l:GetAttribute("RankBadgeRainbowOn") == on then return end
	l:SetAttribute("RankBadgeRainbowOn", on)
	local g = s:FindFirstChild("Rainbow")
	local size = l.TextSize
	if on then
		if not g then
			g = Instance.new("UIGradient")
			g.Name = "Rainbow"
			g.Color = M.RAINBOW
			g.Parent = s
		end
		g.Enabled = true
		s.Color = Color3.new(1, 1, 1)
		s.Transparency = 0
		s.Thickness = math.max(2, math.floor(size * (tonumber(script:GetAttribute("RankBadgeRainbowThick")) or 0.17)))
		spinning[g] = true
		if not spinConn then spinConn = game:GetService("RunService").RenderStepped:Connect(spinStep) end
	else
		if g then g.Enabled = false spinning[g] = nil end
		s.Color = Color3.new(0, 0, 0)
		s.Transparency = 0.45
		s.Thickness = math.max(1, math.floor(size * 0.12))
	end
end

function M.set(l, rank, size)
	if not l then return false end
	if size then M.size(l, size) end
	if not M.valid(rank) or script:GetAttribute("RankBadgesEnabled") == false then
		l.Visible = false
		return false
	end
	local t = "#" .. rank
	if l.Text ~= t then l.Text = t end
	l.BackgroundColor3 = M.color(rank)
	paintOutline(l, rank) -- v1.1
	l.Visible = true
	return true
end

return M
