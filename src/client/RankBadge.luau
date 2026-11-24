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
local M = {}
M.VERSION = "1.0"
M.FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
M.INK = Color3.fromRGB(27, 20, 6)
M.TIER = {Color3.fromRGB(255, 200, 50), Color3.fromRGB(207, 216, 230), Color3.fromRGB(224, 153, 90)}
M.TOP10 = Color3.fromRGB(127, 233, 255)
M.REST = Color3.fromRGB(159, 176, 200)

for k, v in pairs({RankBadgesEnabled = true, RankBadgeMax = 100}) do
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
	l.Visible = true
	return true
end

return M
