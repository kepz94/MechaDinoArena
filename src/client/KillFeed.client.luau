-- KillFeed v1.0 (Mecha Dino Arena) — the kill feed, PC and phone (LocalScript, StarterPlayerScripts). MDA-411, plan
-- docs/plans/PRACTICE_MATCH_v1.0.md Task 7, mockup docs/mockups/practice_match_v0.1.html (v0.2; Kepu 2026-11-10 "Make sure you
-- have the kill feed down"; phone: "Look at how other mobile games handle kill feeds so you don't over crowd the mobile side",
-- answer "Yes, like that").
-- Reads RemoteEvent ReplicatedStorage.KillFeed (KillFeedServer 1.0): entry {k, kTeam, kBot, kId, kSp, how, v, vTeam, vBot, vId,
--   vSp, at}.
-- ScreenGui "KillFeed" (DisplayOrder 6, ScreenInsets DeviceSafeInsets, ResetOnSpawn false), FredokaOne, shown while the
--   player is out of the menu (InMenu ~= true).
--   * Lines: left column, x 16, 6 px under the lowest visible of HardpointHUD's ScoreCard / Status / Next (no HardpointHUD on
--     screen: y 128); newest at the bottom. A line = killer (team colour) [BOT] · how chip (light, dark text; none when how is
--     "") · victim (team colour) [BOT]. Team colour from the viewer: your team blue rgb(140,192,255), the other red
--     rgb(255,143,163) (no team of yours: A blue, B red; no team: white). Your own name reads "You". A line with you in it:
--     yellow outline, darker yellow back.
--   * PC: 5 lines at most, each for 5 s (lines with you 8 s), BOT tags. Phone (UserInputService.TouchEnabled, or the
--     character's ArenaTouchState == "on", the ArenaTouchForceTouch test hook): 3 lines, 82% size (UIScale), 4 s, no BOT tags,
--     and your own kill / death also shows a banner low in the middle (bottom 30% of the screen): "ELIMINATED <VICTIM>"
--     (yellow edge) / "KILLED BY <KILLER> · <how>" (red edge), 2.5 s.
--   * Lines fade out over 0.3 s.
-- Switches: script attributes KillFeedEnabled (default true, read per entry and per frame), KillFeedPhoneBanner (default true,
--   read per entry). Diagnostics: KillFeedVersion, KillFeedMode ("pc" / "phone"), KillFeedLines (lines on screen),
--   KillFeedLastLine ("<k> > <how> > <v>"), KillFeedBanner (last banner text).
-- v1.1 (MDA-423, HardpointHUD 1.5): the lines also stay under HardpointHUD's "Compass" and "CompassUnder" when those are
--   visible (on narrow screens the compass sits under the pills in the left column; in its usual top row they are higher
--   than the pills and change nothing).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.1"
VERSION = "1.2" -- v1.2 phone HUD v2: lines top-right
-- v1.2 (phone HUD v2, MDA-535, plan docs/plans/PHONE_HUD_V2_v1.0.md rule 5, mockup docs/mockups/phone_hud_v0.1.html "A · your
--   version"): while player attribute PhoneHudV2 is true (PhoneMenu 1.0) and script attribute KillFeedPhoneV2Enabled ~= false
--   (default true, read per frame), the lines sit top-right, right-aligned: AnchorPoint (1, 0) at (1, -16, 0, y), y = PhoneMenu's
--   ☰ bottom + 6 (50 without it); a late render step (Last + 40) places them. Phone rules (3 lines, 4 s, banner) unchanged.
local PC = {max = 5, life = 5, lifeMe = 8, scale = 1, tags = true}
local PHONE = {max = 3, life = 4, lifeMe = 4, scale = 0.82, tags = false}
local BANNER_LIFE = 2.5
local FALLBACK_Y = 128
local BLUE, RED, WHITE = Color3.fromRGB(140, 192, 255), Color3.fromRGB(255, 143, 163), Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 200, 50)
local PANEL, PANEL_ME = Color3.fromRGB(20, 20, 26), Color3.fromRGB(40, 34, 10)
local CHIP, CHIP_TEXT = Color3.fromRGB(233, 238, 245), Color3.fromRGB(26, 19, 0)
local FONT = Enum.Font.FredokaOne

script:SetAttribute("KillFeedVersion", VERSION)
if script:GetAttribute("KillFeedEnabled") == nil then script:SetAttribute("KillFeedEnabled", true) end
if script:GetAttribute("KillFeedPhoneBanner") == nil then script:SetAttribute("KillFeedPhoneBanner", true) end

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("KillFeed", 60)
if not remote then return end
local pg = player:WaitForChild("PlayerGui")

local function isPhone()
	local c = player.Character
	return UserInputService.TouchEnabled or (c ~= nil and c:GetAttribute("ArenaTouchState") == "on")
end
local function mode() return isPhone() and PHONE or PC end

local gui = Instance.new("ScreenGui")
gui.Name = "KillFeed"
gui.DisplayOrder = 6
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Parent = pg

local feed = Instance.new("Frame")
feed.Name = "Lines"
feed.BackgroundTransparency = 1
feed.AutomaticSize = Enum.AutomaticSize.XY
feed.Size = UDim2.fromOffset(0, 0)
feed.Position = UDim2.fromOffset(16, FALLBACK_Y)
feed.Parent = gui
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 4)
list.Parent = feed
local scale = Instance.new("UIScale")
scale.Parent = feed

-- v1.2: phone HUD v2 placement (see the header)
do
	local BIND = "KillFeedPhoneV2"
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value + 40, function()
		local on = player:GetAttribute("PhoneHudV2") == true and script:GetAttribute("KillFeedPhoneV2Enabled") ~= false
		if on then
			local y = 50
			local pm = pg:FindFirstChild("PhoneMenu")
			local b = pm and pm:IsA("ScreenGui") and pm.Enabled and pm:FindFirstChild("Burger")
			if b and b.AbsoluteSize.Y > 0 then y = b.AbsolutePosition.Y + b.AbsoluteSize.Y - gui.AbsolutePosition.Y + 6 end
			feed.AnchorPoint = Vector2.new(1, 0)
			feed.Position = UDim2.new(1, -16, 0, y)
			list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		elseif feed.AnchorPoint.X ~= 0 then
			feed.AnchorPoint = Vector2.new(0, 0)
			list.HorizontalAlignment = Enum.HorizontalAlignment.Left
		end
	end)
end

local banner = Instance.new("TextLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 1)
banner.Position = UDim2.fromScale(0.5, 0.7)
banner.AutomaticSize = Enum.AutomaticSize.X
banner.Size = UDim2.fromOffset(0, 32)
banner.BackgroundColor3 = PANEL
banner.BackgroundTransparency = 0.18
banner.Font = FONT
banner.TextSize = 18
banner.TextColor3 = WHITE
banner.RichText = true
banner.Visible = false
banner.Parent = gui
do
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = banner
	local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 14) p.PaddingRight = UDim.new(0, 14) p.Parent = banner
end
local bannerStroke = Instance.new("UIStroke")
bannerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bannerStroke.Thickness = 1.5
bannerStroke.Color = YELLOW
bannerStroke.Parent = banner
local bannerUntil = 0

local function teamColor(team)
	local mine = player:GetAttribute("HardpointTeam")
	if team ~= "A" and team ~= "B" then return WHITE end
	if mine == "A" or mine == "B" then return team == mine and BLUE or RED end
	return team == "A" and BLUE or RED
end

local function text(parent, order, s, color, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, 22)
	l.Font = FONT
	l.TextSize = size
	l.TextColor3 = color
	l.Text = s
	l.LayoutOrder = order
	l.Parent = parent
	return l
end
local function tag(parent, order)
	local t = text(parent, order, "BOT", Color3.fromRGB(201, 208, 219), 11)
	t.Size = UDim2.fromOffset(0, 14)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = Color3.fromRGB(107, 118, 134)
	s.Thickness = 1
	s.Parent = t
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 3) c.Parent = t
	local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 3) p.PaddingRight = UDim.new(0, 3) p.Parent = t
	return t
end

local lines = {} -- {frame, untilT, fading}
local order = 0

local function addLine(e)
	local m = mode()
	local me = (e.kBot ~= true and e.kId == player.UserId) or (e.vBot ~= true and e.vId == player.UserId)
	local kName = (e.kBot ~= true and e.kId == player.UserId) and "You" or tostring(e.k)
	local vName = (e.vBot ~= true and e.vId == player.UserId) and "You" or tostring(e.v)
	order += 1
	local f = Instance.new("Frame")
	f.Name = "Line"
	f.LayoutOrder = order
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, 24)
	f.BackgroundColor3 = me and PANEL_ME or PANEL
	f.BackgroundTransparency = me and 0.15 or 0.28
	do
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = f
		local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 8) p.PaddingRight = UDim.new(0, 8) p.Parent = f
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, 6)
		l.Parent = f
		if me then
			local s = Instance.new("UIStroke")
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.Color = YELLOW
			s.Thickness = 1.5
			s.Parent = f
		end
	end
	text(f, 1, kName, teamColor(e.kTeam), 15)
	if m.tags and e.kBot == true then tag(f, 2) end
	if type(e.how) == "string" and e.how ~= "" then
		local chip = text(f, 3, e.how, CHIP_TEXT, 12)
		chip.Size = UDim2.fromOffset(0, 16)
		chip.BackgroundTransparency = 0
		chip.BackgroundColor3 = CHIP
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = chip
		local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 5) p.PaddingRight = UDim.new(0, 5) p.Parent = chip
	end
	text(f, 4, vName, teamColor(e.vTeam), 15)
	if m.tags and e.vBot == true then tag(f, 5) end
	f.Parent = feed
	table.insert(lines, {frame = f, untilT = os.clock() + (me and m.lifeMe or m.life)})
	while #lines > m.max do
		local old = table.remove(lines, 1)
		old.frame:Destroy()
	end
	script:SetAttribute("KillFeedLastLine", ("%s > %s > %s"):format(kName, tostring(e.how), vName))

	if m == PHONE and me and script:GetAttribute("KillFeedPhoneBanner") ~= false then
		if kName == "You" then
			banner.Text = ('ELIMINATED <font color="#ff8fa3">%s</font>'):format(string.upper(vName))
			bannerStroke.Color = YELLOW
		else
			banner.Text = ('KILLED BY <font color="#ff8fa3">%s</font>%s'):format(string.upper(kName),
				(type(e.how) == "string" and e.how ~= "") and (" · " .. e.how) or "")
			bannerStroke.Color = Color3.fromRGB(224, 40, 74)
		end
		bannerUntil = os.clock() + BANNER_LIFE
		script:SetAttribute("KillFeedBanner", banner.Text)
	end
end

remote.OnClientEvent:Connect(function(e)
	if script:GetAttribute("KillFeedEnabled") == false or type(e) ~= "table" then return end
	addLine(e)
end)

local function fade(rec)
	rec.fading = true
	local info = TweenInfo.new(0.3)
	TweenService:Create(rec.frame, info, {BackgroundTransparency = 1}):Play()
	for _, d in ipairs(rec.frame:GetDescendants()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, {Transparency = 1}):Play()
		end
	end
	task.delay(0.3, function() rec.frame:Destroy() end)
end

RunService.RenderStepped:Connect(function()
	local m = mode()
	script:SetAttribute("KillFeedMode", m == PHONE and "phone" or "pc")
	gui.Enabled = script:GetAttribute("KillFeedEnabled") ~= false and player:GetAttribute("InMenu") ~= true
	scale.Scale = m.scale
	-- place under the HardpointHUD's card / pills
	local y = FALLBACK_Y
	local hud = pg:FindFirstChild("HardpointHUD")
	if hud and hud:IsA("ScreenGui") and hud.Enabled then
		local bottom
		for _, n in ipairs({"ScoreCard", "Status", "Next", "Compass", "CompassUnder"}) do -- v1.1: + the compass
			local o = hud:FindFirstChild(n)
			if o and o:IsA("GuiObject") and o.Visible then
				local b = o.AbsolutePosition.Y + o.AbsoluteSize.Y - hud.AbsolutePosition.Y
				if not bottom or b > bottom then bottom = b end
			end
		end
		if bottom then y = bottom + 6 end
	end
	feed.Position = UDim2.fromOffset(16, y)
	local t = os.clock()
	local i = 1
	while i <= #lines do
		local rec = lines[i]
		if not rec.fading and t >= rec.untilT then
			table.remove(lines, i)
			fade(rec)
		else
			i += 1
		end
	end
	script:SetAttribute("KillFeedLines", #lines)
	banner.Visible = t < bannerUntil
end)
