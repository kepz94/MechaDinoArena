-- IslandTags v1.0 (Mecha Dino Arena) — each player's name and Arena W-L over their dino on the hub island (LocalScript,
-- StarterPlayerScripts). MDA-497, plan docs/plans/ARENA_RECORD_v1.1.md T5, mockup docs/mockups/wl_record_v0.1.html option C
-- "ON THE ISLAND (OTHER PLAYERS SEE IT)"; Kepu 2026-11-13 pick "C · B + name tag", "Yourself too".
-- On while: script attribute IslandTagsEnabled ~= false and ReplicatedStorage ServerKind == "hub" (HubServer). Off: every tag
--   hidden. Never on practice / Arena match servers (TeamTags 1.1 marks dinos there).
-- Who: every player (you too) with a character that has a HumanoidRootPart, InMenu ~= true, within IslandTagsMax (80) studs of
--   your HumanoidRootPart (of the camera when you have none); the nearest IslandTagsMaxCount (12).
-- Tag: the name (player DisplayName, upper case, FredokaOne white, 22 px PC / 18 px phone) and under it "<ArenaW>-<ArenaL>"
--   (FredokaOne orange rgb(255,155,46), 18 px PC / 15 px phone) while that player's ArenaRecordReady == true (ArenaRecordServer);
--   name only otherwise. Text stroke for reading against the sky and grass.
-- Drawn as Frames in the ScreenGui "IslandTags" (PlayerGui, IgnoreGuiInset, DisplayOrder 3, ResetOnSpawn false), placed each
--   RenderStepped at the camera's WorldToViewportPoint of the spot: the anchor (Head.Root, else Head, else HumanoidRootPart) +
--   (0, 2.5, 0) on a head, or + (0, half the model height + 2, 0) on the HumanoidRootPart. AnchorPoint (0.5, 1). Hidden behind
--   the camera or off the screen. (TeamTags 1.1 found AlwaysOnTop BillboardGuis did not draw, so frames, as there.)
-- Phone: touch with no keyboard, or a viewport under 500 px tall.
-- FontSwap 1.0 turns these into Silkscreen and fits the size down (~0.65 for FredokaOne: 22 -> 14 on screen); sizes are set
--   before texts and only on a change, so its fit settles.
-- Numbers: script attributes IslandTagsMax (80), IslandTagsMaxCount (12), read every frame.
-- Diagnostics: IslandTagsVersion, IslandTagsState ("off" / "on"), IslandTagsShown (tags drawn last frame).
-- v1.1 (Kepu 2026-11-24 15:29 "how about w-l records appearing above Dino's" -> "Change how they look"; 15:34 pick "B" on mockup
--   docs/mockups/island_tags_v0.1.html "B · Ratio bar"): the tag is the name, a win / loss bar and the numbers, no plate.
--   * Name: Silkscreen Bold (set here, FontSwap "keep" so FontSwap does not shrink it), white, black text stroke; 18 px phone /
--     22 px PC (IslandTagsNameSize / IslandTagsNameSizePC).
--   * Bar (while the record is ready): IslandTagsBarW x IslandTagsBarH px (98 x 10 phone, 120 x 12 PC), round ends, dark outline;
--     green rgb(70,224,138) fill = W / (W + L) of the width over red rgb(255,90,110); 0-0 = a grey rgb(58,68,86) bar.
--   * Numbers under it: "<W>W" green and "<L>L" red side by side, Silkscreen Bold, black stroke; 13 px phone / 16 px PC.
--   Record not ready: name only (as 1.0). Who / where / distance / count rules unchanged.
--   Switch: script attribute IslandTagsBarEnabled (default true, read per frame; false = the 1.0 name + orange "W-L").
-- v1.2 (leaderboards, Kepu 2026-11-24 15:44 "a special number badge by your name", pick "Island name tag"; badge look A with
--   font 2 Builder Sans, mockup docs/mockups/rank_badge_fonts_v0.2.html): a player with a worldwide rank (RankBadge 1.0
--   rankOf: WorldRank 1..100 from LeaderboardServer 1.0) gets the rank badge just left of their name, 5 px gap, centred on the
--   name line; size IslandTagsBadgeSize (13) phone / IslandTagsBadgeSizePC (16) PC. Both looks (bar and 1.0). Switch: script
--   attribute IslandTagsBadgeEnabled (default true, read per frame; false = no badge, = 1.1).
-- v1.3 (Kepu 2026-11-24 22:21 "remove the green/red bar that shows above your name because it confuses other players for a
--   health bar. Just keep the name and record"; 22:27 pick "A" on mockup docs/mockups/postmatch_tags_v0.1.html "A · 12W 4L"):
--   in the 1.1 look the ratio bar is hidden and the "<W>W" green / "<L>L" red numbers move up under the name (5 px gap), size
--   IslandTagsNumSizeNoBar (14, was 13) phone / IslandTagsNumSizeNoBarPC (16) PC. Name, rank badge, who / where rules unchanged.
--   Switch: script attribute IslandTagsNoBarEnabled (default true, read per frame; false = the 1.1 bar back).
-- v1.4 (Kepu 2026-11-25 11:43 live phone screenshot: "remove the green/red bar entirely and realign that info above the Dino's
--   looks really off"; 11:46 pick on mockup docs/mockups/island_tag_fix_v0.2.html: "One line over the head but keep the wins in
--   green and losses in red"): with no bar (1.3) the tag is one line, [badge] NAME 1W 0L, and the whole group (badge, name,
--   record) is centred on the head spot (1.3 centred the name alone, the badge hung off its left and the record sat under the
--   name, so the two lines did not line up). "<W>W" green / "<L>L" red unchanged, IslandTagsOneLineGap (8 px) after the name,
--   IslandTagsOneLineNumGap (6 px) between W and L, the record centred on the name line. Spot (over the head), sizes, badge,
--   who / where rules unchanged. Record not ready: badge + name only, centred.
--   Switch: script attribute IslandTagsOneLineEnabled (default true, read per frame; false = the 1.3 two lines back).
-- v1.5 (Kepu 2026-11-25 11:56 "when I do an emote have it hide the name plate and records so I can properly see the emote"): a player
--   whose character has EmoteId (EmoteServer 1.0, set while the emote plays, cleared when it ends or is cancelled) gets no tag on
--   any screen; it comes back the frame EmoteId clears. Switch: script attribute IslandTagsHideOnEmote (default true, read per frame).
-- v1.6 (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T5, MDA-578, option A): models in Workspace.DinoIsland.Bots with
--   FillerPersona = true (FillerServer 1.0 bots) get a tag like a player's: DisplayName upper case and the record FillerW / FillerL
--   (made up, always "ready"), no rank badge; hidden while that bot emotes (1.5) or once its DummyHealth is 0; same distance and
--   count rules (nearest IslandTagsMaxCount over players and bots). Switch: script attribute IslandTagsBotsEnabled (default
--   true, read per frame; false = 1.5).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 ratio bar look
VERSION = "1.2" -- v1.2 rank badge
VERSION = "1.3" -- v1.3 no ratio bar
VERSION = "1.4" -- v1.4 one line, centred
VERSION = "1.5" -- v1.5 hidden while emoting
VERSION = "1.6" -- v1.6 filler bots tagged
local ORANGE = Color3.fromRGB(255, 155, 46)
local FONT = Enum.Font.FredokaOne
local DEFAULTS = {IslandTagsEnabled = true, IslandTagsMax = 80, IslandTagsMaxCount = 12,
	IslandTagsBarEnabled = true, IslandTagsNameSize = 18, IslandTagsNameSizePC = 22, IslandTagsNumSize = 13, IslandTagsNumSizePC = 16, -- v1.1
	IslandTagsBarW = 98, IslandTagsBarWPC = 120, IslandTagsBarH = 10, IslandTagsBarHPC = 12}
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold) -- v1.1: Silkscreen Bold (as FontSwap 1.0)
local GREEN, RED, GREY = Color3.fromRGB(70, 224, 138), Color3.fromRGB(255, 90, 110), Color3.fromRGB(58, 68, 86)

script:SetAttribute("IslandTagsVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("IslandTagsState", "off")
for k, v in pairs({IslandTagsBadgeEnabled = true, IslandTagsBadgeSize = 13, IslandTagsBadgeSizePC = 16,
	IslandTagsNoBarEnabled = true, IslandTagsNumSizeNoBar = 14, IslandTagsNumSizeNoBarPC = 16, -- v1.2, v1.3
	IslandTagsOneLineEnabled = true, IslandTagsOneLineGap = 8, IslandTagsOneLineNumGap = 6, -- v1.4
	IslandTagsHideOnEmote = true}) do -- v1.5
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local RB -- v1.2: RankBadge 1.0
do
	local ok, m = pcall(function() return require(script.Parent:WaitForChild("RankBadge", 10)) end)
	RB = ok and m or nil
end

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "IslandTags"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 3
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local tags = {} -- [Player] = {frame, name, rec}
local heights = {} -- [Model] = half height (cached per character)

local function phone()
	local cam = workspace.CurrentCamera
	return (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or (cam and cam.ViewportSize.Y < 500)
end

local function tagFor(p)
	local t = tags[p]
	if t then return t end
	local f = Instance.new("Frame")
	f.Name = "Tag_" .. p.UserId
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(200, 36)
	f.Visible = false
	f.Parent = gui
	local function line(name, color)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Font = FONT
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.45
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		l.Size = UDim2.new(1, 0, 0, 16)
		l.Parent = f
		return l
	end
	t = {frame = f, name = line("Name", Color3.new(1, 1, 1)), rec = line("Record", ORANGE)}
	-- v1.1: the ratio bar and the W / L numbers (hidden while the switch is off)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.BackgroundColor3 = RED
	bar.BorderSizePixel = 0
	bar.ClipsDescendants = true
	bar.Visible = false
	bar.Parent = f
	local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0.5, 0) bc.Parent = bar
	local bs = Instance.new("UIStroke") bs.Color = Color3.fromRGB(11, 15, 22) bs.Thickness = 2 bs.Transparency = 0.33 bs.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = GREEN
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0.5, 0) fc.Parent = fill
	local nums = Instance.new("Frame")
	nums.Name = "Nums"
	nums.AnchorPoint = Vector2.new(0.5, 0)
	nums.BackgroundTransparency = 1
	nums.Visible = false
	nums.Parent = f
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Padding = UDim.new(0, 10)
	lay.Parent = nums
	local function num(name, color, order)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.FontFace = SILK
		l:SetAttribute("FontSwap", "keep")
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.2
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.new(0, 0, 1, 0)
		l.LayoutOrder = order
		l.Parent = nums
		return l
	end
	t.bar, t.fill, t.nums, t.w, t.l = bar, fill, nums, num("W", GREEN, 1), num("L", RED, 2)
	t.lay = lay -- v1.4
	if RB then -- v1.2: the rank badge, left of the name
		t.badge = RB.new()
		t.badge.AnchorPoint = Vector2.new(1, 0.5)
		t.badge.Parent = f
	end
	tags[p] = t
	return t
end

-- v1.2: the rank badge just left of the name text (nameH = the name line height)
local function placeBadge(t, p, small, nameH, dx) -- v1.4: dx = the name's offset from the tag centre (one line)
	if not t.badge then return end
	local rank = script:GetAttribute("IslandTagsBadgeEnabled") ~= false and RB.rankOf(p) or nil
	local size = small and (tonumber(script:GetAttribute("IslandTagsBadgeSize")) or 13) or (tonumber(script:GetAttribute("IslandTagsBadgeSizePC")) or 16)
	if RB.set(t.badge, rank, size) then
		t.badge.Position = UDim2.new(0.5, -math.floor(t.name.TextBounds.X / 2) - 5 + (dx or 0), 0, math.floor(nameH / 2))
	end
end

local function anchorOf(model)
	local head = model:FindFirstChild("Head")
	local root = head and head:FindFirstChild("Root")
	if root and root:IsA("BasePart") then return root, true end
	if head and head:IsA("BasePart") then return head, true end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp, false end
	return nil
end

local function halfHeight(model)
	local h = heights[model]
	if h then return h end
	local ok, size = pcall(function() return model:GetExtentsSize() end)
	h = (ok and size and size.Y / 2) or 4
	heights[model] = h
	return h
end

-- v1.6: filler bots get a tag like a player (see the header)
local botStands = {} -- [model] = stand-in "player" for tagFor / the drawing code
local function botStand(m)
	local s = botStands[m]
	if s then return s end
	s = {UserId = "b" .. m.Name, Character = m}
	s.DisplayName = tostring(m:GetAttribute("DisplayName") or m.Name)
	function s:GetAttribute(k)
		if k == "ArenaRecordReady" then return true end
		if k == "ArenaW" then return tonumber(m:GetAttribute("FillerW")) or 0 end
		if k == "ArenaL" then return tonumber(m:GetAttribute("FillerL")) or 0 end
		return nil
	end
	botStands[m] = s
	return s
end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 1e9)
	local f = isl and isl:WaitForChild("Bots", 1e9)
	if not f then return end
	f.ChildRemoved:Connect(function(m)
		local s = botStands[m]
		if s then
			local t = tags[s]
			if t then t.frame:Destroy() tags[s] = nil end
			botStands[m] = nil
		end
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	local t = tags[p]
	if t then t.frame:Destroy() tags[p] = nil end
end)

RunService.RenderStepped:Connect(function()
	local on = script:GetAttribute("IslandTagsEnabled") ~= false and ReplicatedStorage:GetAttribute("ServerKind") == "hub"
	local st = on and "on" or "off"
	if script:GetAttribute("IslandTagsState") ~= st then script:SetAttribute("IslandTagsState", st) end
	local cam = workspace.CurrentCamera
	if not on or not cam then
		for _, t in pairs(tags) do t.frame.Visible = false end
		if script:GetAttribute("IslandTagsShown") ~= 0 then script:SetAttribute("IslandTagsShown", 0) end
		return
	end
	local maxD = tonumber(script:GetAttribute("IslandTagsMax")) or 80
	local maxN = tonumber(script:GetAttribute("IslandTagsMaxCount")) or 12
	local myChar = player.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local from = myRoot and myRoot.Position or cam.CFrame.Position
	local list = {}
	local hideEmote = script:GetAttribute("IslandTagsHideOnEmote") ~= false -- v1.5
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local emoting = hideEmote and c and c:GetAttribute("EmoteId") ~= nil -- v1.5: no tag while that dino emotes
		if hrp and c.Parent and p:GetAttribute("InMenu") ~= true and not emoting then
			local d = (hrp.Position - from).Magnitude
			if d <= maxD then table.insert(list, {p = p, c = c, d = d}) end
		end
	end
	if script:GetAttribute("IslandTagsBotsEnabled") ~= false then -- v1.6
		local isl = workspace:FindFirstChild("DinoIsland")
		local bf = isl and isl:FindFirstChild("Bots")
		if bf then
			for _, m in ipairs(bf:GetChildren()) do
				local hrp = m:IsA("Model") and m:GetAttribute("FillerPersona") == true and m:FindFirstChild("HumanoidRootPart")
				local emoting = hideEmote and m:GetAttribute("EmoteId") ~= nil
				if hrp and (tonumber(m:GetAttribute("DummyHealth")) or 1) > 0 and not emoting then
					local d = (hrp.Position - from).Magnitude
					if d <= maxD then table.insert(list, {p = botStand(m), c = m, d = d}) end
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	local shown, small = {}, phone()
	local nS, rS = small and 18 or 22, small and 15 or 18 -- before FontSwap's fit (FredokaOne -> Silkscreen ~0.65)
	local count = 0
	for i, e in ipairs(list) do
		if i > maxN then break end
		local anchor, onHead = anchorOf(e.c)
		if anchor then
			local spot = anchor.Position + Vector3.new(0, onHead and 2.5 or (halfHeight(e.c) + 2), 0)
			local v, inView = cam:WorldToViewportPoint(spot)
			if inView and v.Z > 0 then
				local t = tagFor(e.p)
				local ready = e.p:GetAttribute("ArenaRecordReady") == true
				if script:GetAttribute("IslandTagsBarEnabled") ~= false then -- v1.1: the ratio bar look
					local A = function(k, d) return tonumber(script:GetAttribute(k)) or d end
					local ns = small and A("IslandTagsNameSize", 18) or A("IslandTagsNameSizePC", 22)
					local us = small and A("IslandTagsNumSize", 13) or A("IslandTagsNumSizePC", 16)
					local bw = small and A("IslandTagsBarW", 98) or A("IslandTagsBarWPC", 120)
					local bh = small and A("IslandTagsBarH", 10) or A("IslandTagsBarHPC", 12)
					local noBar = script:GetAttribute("IslandTagsNoBarEnabled") ~= false -- v1.3
					if noBar then us = small and A("IslandTagsNumSizeNoBar", 14) or A("IslandTagsNumSizeNoBarPC", 16) end
					local gap = noBar and 0 or (bh + 4) -- v1.3: the bar's room under the name
					local one = noBar and script:GetAttribute("IslandTagsOneLineEnabled") ~= false -- v1.4
					if t.one ~= one then t.one, t.nS = one, nil end -- v1.4: a switch flip re-runs the size block (puts 1.3 back)
					if t.mode ~= "bar" then
						t.mode, t.nS = "bar", nil
						t.name.FontFace = SILK
						t.name:SetAttribute("FontSwap", "keep")
						t.name.TextStrokeTransparency = 0.2
						t.rec.Visible = false
					end
					if t.nS ~= ns or t.uS ~= us or t.bw ~= bw or t.bh ~= bh or t.noBar ~= noBar then
						t.nS, t.uS, t.bw, t.bh, t.noBar = ns, us, bw, bh, noBar
						t.name.TextSize = ns
						t.name.Size = UDim2.new(1, 0, 0, ns + 2)
						t.name.Position = UDim2.new()
						t.bar.Size = UDim2.fromOffset(bw, bh)
						t.bar.Position = UDim2.new(0.5, 0, 0, ns + 5)
						t.nums.Size = UDim2.new(1, 0, 0, us + 2)
						t.nums.Position = UDim2.new(0.5, 0, 0, ns + 5 + gap) -- v1.3 (1.1: ns + 5 + bh + 4)
						t.w.TextSize, t.l.TextSize = us, us
						t.nums.AnchorPoint = Vector2.new(0.5, 0) -- v1.4: 1.3 layout (the one-line block below moves these per frame)
						t.lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
						t.lay.Padding = UDim.new(0, 10)
					end
					local nameT = string.upper(e.p.DisplayName)
					if t.name.Text ~= nameT then t.name.Text = nameT end
					local w = tonumber(e.p:GetAttribute("ArenaW")) or 0
					local l = tonumber(e.p:GetAttribute("ArenaL")) or 0
					t.bar.Visible, t.nums.Visible = ready and not noBar, ready -- v1.3
					if ready then
						t.bar.BackgroundColor3 = (w + l) > 0 and RED or GREY
						t.fill.Size = UDim2.fromScale((w + l) > 0 and w / (w + l) or 0, 1)
						t.fill.Visible = w > 0
						local wt, lt = w .. "W", l .. "L"
						if t.w.Text ~= wt then t.w.Text = wt end
						if t.l.Text ~= lt then t.l.Text = lt end
					end
					local dx = 0
					if one then -- v1.4: one line [badge] NAME 1W 0L, the whole group centred on the head spot
						local gapN = A("IslandTagsOneLineGap", 8)
						local numGap = A("IslandTagsOneLineNumGap", 6)
						t.lay.Padding = UDim.new(0, numGap)
						t.lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
						t.nums.AnchorPoint = Vector2.new(0, 0)
						local nameW = t.name.TextBounds.X
						local numsW = ready and (t.w.TextBounds.X + numGap + t.l.TextBounds.X) or 0
						local badgeW = (t.badge and t.badge.Visible) and (t.badge.AbsoluteSize.X + 5) or 0 -- last frame's badge
						local groupW = badgeW + nameW + (ready and (gapN + numsW) or 0)
						local left = -groupW / 2
						dx = math.floor(left + badgeW + nameW / 2 + 0.5)
						t.name.Position = UDim2.fromOffset(dx, 0)
						t.nums.Size = UDim2.fromOffset(math.ceil(numsW) + 2, us + 2)
						t.nums.Position = UDim2.new(0.5, math.floor(left + badgeW + nameW + gapN + 0.5), 0, math.floor((ns - us) / 2))
						t.frame.Size = UDim2.fromOffset(math.max(200, math.ceil(groupW) + 20), ns + 2)
					else
						if t.name.Position ~= UDim2.new() then t.name.Position = UDim2.new() end
						t.frame.Size = UDim2.fromOffset(200, ns + 2 + (ready and (3 + gap + us + 2) or 0)) -- v1.3 (1.1: 3 + bh + 4)
					end
					t.frame.Position = UDim2.fromOffset(v.X, v.Y)
					t.frame.Visible = true
					placeBadge(t, e.p, small, ns + 2, dx) -- v1.2, v1.4 dx
					shown[e.p] = true
					count += 1
					continue
				end
				if t.mode == "bar" then -- v1.1 switch turned off: back to the 1.0 look
					t.mode, t.nS, t.noBar, t.one = nil, nil, nil, nil
					t.name.Position = UDim2.new() -- v1.4
					t.name.Font = FONT
					t.name:SetAttribute("FontSwap", nil)
					t.name.TextStrokeTransparency = 0.45
					t.bar.Visible, t.nums.Visible = false, false
				end
				-- sizes before texts, and only on a change (FontSwap 1.0 re-fits on a text or size change; per frame it would never settle)
				if t.nS ~= nS then
					t.nS = nS
					t.name.TextSize = nS
					t.name.Size = UDim2.new(1, 0, 0, nS + 2)
					t.rec.TextSize = rS
					t.rec.Size = UDim2.new(1, 0, 0, rS + 2)
					t.rec.Position = UDim2.fromOffset(0, nS + 2)
				end
				local nameT = string.upper(e.p.DisplayName)
				if t.name.Text ~= nameT then t.name.Text = nameT end
				local recT = ready and ("%d-%d"):format(tonumber(e.p:GetAttribute("ArenaW")) or 0, tonumber(e.p:GetAttribute("ArenaL")) or 0) or ""
				if t.rec.Text ~= recT then t.rec.Text = recT end
				t.rec.Visible = ready
				t.frame.Size = UDim2.fromOffset(200, nS + 2 + (ready and rS + 2 or 0))
				t.frame.Position = UDim2.fromOffset(v.X, v.Y)
				t.frame.Visible = true
				placeBadge(t, e.p, small, nS + 2) -- v1.2
				shown[e.p] = true
				count += 1
			end
		end
	end
	for p, t in pairs(tags) do
		if not shown[p] then t.frame.Visible = false end
	end
	for m in pairs(heights) do
		if not m.Parent then heights[m] = nil end
	end
	if script:GetAttribute("IslandTagsShown") ~= count then script:SetAttribute("IslandTagsShown", count) end
end)
