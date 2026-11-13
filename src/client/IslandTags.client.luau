-- IslandTags v1.0 (Mecha Dino Arena) — each player's name and Arena W-L over their dino on the hub island (LocalScript,
-- StarterPlayerScripts). MDA-497, plan docs/plans/ARENA_RECORD_v1.1.md T5, mockup docs/mockups/wl_record_v0.1.html option C
-- "ON THE ISLAND (OTHER PLAYERS SEE IT)"; Kepu 2026-11-13 pick "C · B + name tag", "Yourself too".
-- On while: script attribute IslandTagsEnabled ~= false and ReplicatedStorage ServerKind == "hub" (HubServer). Off: every tag
--   hidden. Never on practice / Arena match servers (TeamTags 1.1 marks dinos there).
-- Who: every player (you too) with a character that has a HumanoidRootPart, InMenu ~= true, within IslandTagsMax (80) studs of
--   your HumanoidRootPart (of the camera when you have none); the nearest IslandTagsMaxCount (12).
-- Tag: the name (player DisplayName, upper case, FredokaOne white, 16 px PC / 13 px phone) and under it "<ArenaW>-<ArenaL>"
--   (FredokaOne orange rgb(255,155,46), 13 px PC / 11 px phone) while that player's ArenaRecordReady == true (ArenaRecordServer);
--   name only otherwise. Text stroke for reading against the sky and grass.
-- Drawn as Frames in the ScreenGui "IslandTags" (PlayerGui, IgnoreGuiInset, DisplayOrder 3, ResetOnSpawn false), placed each
--   RenderStepped at the camera's WorldToViewportPoint of the spot: the anchor (Head.Root, else Head, else HumanoidRootPart) +
--   (0, 4, 0) on a head, or + (0, half the model height + 2, 0) on the HumanoidRootPart. AnchorPoint (0.5, 1). Hidden behind
--   the camera or off the screen. (TeamTags 1.1 found AlwaysOnTop BillboardGuis did not draw, so frames, as there.)
-- Phone: touch with no keyboard, or a viewport under 500 px tall.
-- Numbers: script attributes IslandTagsMax (80), IslandTagsMaxCount (12), read every frame.
-- Diagnostics: IslandTagsVersion, IslandTagsState ("off" / "on"), IslandTagsShown (tags drawn last frame).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
local ORANGE = Color3.fromRGB(255, 155, 46)
local FONT = Enum.Font.FredokaOne
local DEFAULTS = {IslandTagsEnabled = true, IslandTagsMax = 80, IslandTagsMaxCount = 12}

script:SetAttribute("IslandTagsVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("IslandTagsState", "off")

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
	tags[p] = t
	return t
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
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if hrp and c.Parent and p:GetAttribute("InMenu") ~= true then
			local d = (hrp.Position - from).Magnitude
			if d <= maxD then table.insert(list, {p = p, c = c, d = d}) end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	local shown, small = {}, phone()
	local nS, rS = small and 13 or 16, small and 11 or 13
	local count = 0
	for i, e in ipairs(list) do
		if i > maxN then break end
		local anchor, onHead = anchorOf(e.c)
		if anchor then
			local spot = anchor.Position + Vector3.new(0, onHead and 4 or (halfHeight(e.c) + 2), 0)
			local v, inView = cam:WorldToViewportPoint(spot)
			if inView and v.Z > 0 then
				local t = tagFor(e.p)
				local ready = e.p:GetAttribute("ArenaRecordReady") == true
				t.name.Text = string.upper(e.p.DisplayName)
				t.name.TextSize = nS
				t.name.Size = UDim2.new(1, 0, 0, nS + 2)
				t.name.Position = UDim2.fromOffset(0, 0)
				t.rec.Visible = ready
				t.rec.Text = ready and ("%d-%d"):format(tonumber(e.p:GetAttribute("ArenaW")) or 0, tonumber(e.p:GetAttribute("ArenaL")) or 0) or ""
				t.rec.TextSize = rS
				t.rec.Size = UDim2.new(1, 0, 0, rS + 2)
				t.rec.Position = UDim2.fromOffset(0, nS + 2)
				t.frame.Size = UDim2.fromOffset(200, nS + 2 + (ready and rS + 2 or 0))
				t.frame.Position = UDim2.fromOffset(v.X, v.Y)
				t.frame.Visible = true
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
