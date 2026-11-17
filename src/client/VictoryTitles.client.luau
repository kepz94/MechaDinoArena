-- VictoryTitles v1.0 (Mecha Dino Arena) — the end-of-match title show (LocalScript, StarterPlayerScripts). MDA-556, plan
-- docs/plans/VICTORY_TITLES_v1.0.md Task 5, mockup docs/mockups/victory_titles_v0.1.html (Kepu 2026-11-16 19:00 "Oh my gosh
-- these are so good. Let's implement them").
-- When a Hardpoint match ends with a winner, HardpointServer 1.9 publishes ReplicatedStorage.Hardpoint HpTitles (JSON {key =
--   HpResultsEndAt, list = {{id, name, species, title, stat, len}}}) and a display model per entry in ReplicatedStorage
--   VictoryTitleModels. From the results start (HpResultsEndAt − HpResultsLen) + VictoryBannerSec (2) the entries play one
--   after another (each its len): a local clone of the entry's model on a stage in the sky (VictoryStageY 3000 studs up;
--   sand pad, grass, blocky trees), animated by VictoryTitlesAnim 1.0, the camera scripted (Scriptable, bound after the other
--   camera scripts), and a lower third (name · dino chip, TITLE (yellow; roasts pink), caption, stat pill) that slams in at
--   0.3 s. Top right: the names, the current one yellow. Carried: the carrier is the first other entry's model (else a twin).
--   A tap / click after VictoryTapGuard (1) s into a title skips to the next. Only while HpPhase is "results", the player is
--   out of the menu (InMenu ~= true) and HpTitles' key is this results' end. The camera goes back (Custom, your character)
--   when the show ends or anything stops it.
-- Captions: APEX PREDATOR "Top of the food chain", KING OF THE HILL "Wouldn't get off the point", UNKILLABLE "The asteroid
--   missed. Again.", MEDIC "Patched up the whole team", BUTTON MASHER "Never met a cooldown it liked", EXTINCT "Died the most.
--   Again.", CARRIED "Packed up and carried to the win", PACIFIST "Won without hurting a fly".
-- Test hook: player attribute VictoryTitlesTest = "<title>[,<title>...]" plays those titles now with clones of your own
--   character (reset to "" once read). Switch: script attribute VictoryTitlesEnabled (default true, read per show).
-- Diagnostics: VictoryTitlesVersion, VictoryTitlesState ("idle" / "show <i>/<n> <title>" / "test <title>"), VictoryTitlesLast.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
script:SetAttribute("VictoryTitlesVersion", VERSION)
for k, v in pairs({VictoryTitlesEnabled = true, VictoryBannerSec = 2, VictoryStageY = 3000, VictoryTapGuard = 1}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("VictoryTitlesState", "idle")

local player = Players.LocalPlayer
local Anim = require(script.Parent:WaitForChild("VictoryTitlesAnim"))

local NAMES = {apex = "APEX PREDATOR", king = "KING OF THE HILL", unkill = "UNKILLABLE", medic = "MEDIC", masher = "BUTTON MASHER",
	extinct = "EXTINCT", carried = "CARRIED", pacifist = "PACIFIST"}
local CAPS = {apex = "Top of the food chain", king = "Wouldn't get off the point", unkill = "The asteroid missed. Again.",
	medic = "Patched up the whole team", masher = "Never met a cooldown it liked", extinct = "Died the most. Again.",
	carried = "Packed up and carried to the win", pacifist = "Won without hurting a fly"}
local ROAST = {extinct = true, carried = true, pacifist = true}
local DINO = {TRex = "T-REX", Raptor = "RAPTOR", Pachy = "PACHY", Herrera = "HERRERA", Teno = "TENO", Troodon = "TROODON",
	Therizino = "THERIZINO", Dilo = "DILO", Zuul = "ZUUL"}
local YELLOW, PINK, BLUE = Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 107, 132), Color3.fromRGB(90, 160, 255)

-- ---------- UI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "VictoryTitles"
gui.DisplayOrder = 7
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local function label(parent, font, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.4
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.Parent = parent
	return l
end
local flashF = Instance.new("Frame")
flashF.Name = "Flash"
flashF.Size = UDim2.fromScale(1, 1)
flashF.BackgroundColor3 = Color3.new(1, 1, 1)
flashF.BackgroundTransparency = 1
flashF.BorderSizePixel = 0
flashF.ZIndex = 10
flashF.Parent = gui
local lower = Instance.new("Frame")
lower.Name = "Lower"
lower.BackgroundTransparency = 1
lower.AnchorPoint = Vector2.new(0, 1)
lower.AutomaticSize = Enum.AutomaticSize.XY
lower.Size = UDim2.fromOffset(0, 0)
lower.Parent = gui
local lowerScale = Instance.new("UIScale")
lowerScale.Parent = lower
local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = lower
local who = Instance.new("Frame")
who.BackgroundTransparency = 1
who.AutomaticSize = Enum.AutomaticSize.XY
who.Size = UDim2.fromOffset(0, 0)
who.LayoutOrder = 1
who.Parent = lower
local whoList = Instance.new("UIListLayout")
whoList.FillDirection = Enum.FillDirection.Horizontal
whoList.VerticalAlignment = Enum.VerticalAlignment.Center
whoList.Parent = who
local whoName = label(who, Enum.Font.GothamBlack, Color3.fromRGB(207, 211, 220))
whoName.LayoutOrder = 1
local chip = label(who, Enum.Font.GothamBlack, Color3.fromRGB(6, 20, 40))
chip.LayoutOrder = 2
chip.BackgroundTransparency = 0
chip.BackgroundColor3 = BLUE
chip.TextStrokeTransparency = 1
Instance.new("UICorner").Parent = chip
local chipPad = Instance.new("UIPadding")
chipPad.Parent = chip
local ttl = label(lower, Enum.Font.FredokaOne, YELLOW)
ttl.LayoutOrder = 2
ttl.TextStrokeTransparency = 0
local cap = label(lower, Enum.Font.GothamBlack, Color3.new(1, 1, 1))
cap.LayoutOrder = 3
cap.TextStrokeTransparency = 0.2
local statWrap = Instance.new("Frame")
statWrap.BackgroundTransparency = 1
statWrap.AutomaticSize = Enum.AutomaticSize.XY
statWrap.Size = UDim2.fromOffset(0, 0)
statWrap.LayoutOrder = 4
statWrap.Parent = lower
local stat = label(statWrap, Enum.Font.GothamBlack, Color3.fromRGB(27, 20, 6))
stat.BackgroundTransparency = 0
stat.BackgroundColor3 = YELLOW
stat.TextStrokeTransparency = 1
Instance.new("UICorner").Parent = stat
local statPad = Instance.new("UIPadding")
statPad.Parent = stat
local dots = Instance.new("Frame")
dots.Name = "Dots"
dots.BackgroundTransparency = 1
dots.AnchorPoint = Vector2.new(1, 0)
dots.AutomaticSize = Enum.AutomaticSize.XY
dots.Size = UDim2.fromOffset(0, 0)
dots.Parent = gui
local dotsList = Instance.new("UIListLayout")
dotsList.FillDirection = Enum.FillDirection.Horizontal
dotsList.SortOrder = Enum.SortOrder.LayoutOrder
dotsList.Parent = dots
local counter = label(gui, Enum.Font.FredokaOne, Color3.new(1, 1, 1))
counter.AnchorPoint = Vector2.new(0.5, 0)
counter.TextXAlignment = Enum.TextXAlignment.Center
counter.TextStrokeTransparency = 0
counter.Visible = false
local counterScale = Instance.new("UIScale")
counterScale.Parent = counter
local plasters = {}
for i, rot in ipairs({-32, 38}) do
	local f = Instance.new("Frame")
	f.Name = "Plaster" .. i
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundColor3 = Color3.fromRGB(241, 199, 156)
	f.BorderSizePixel = 0
	f.Rotation = rot
	f.Visible = false
	f.ZIndex = 8
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.2, 0)
	c.Parent = f
	local padf = Instance.new("Frame")
	padf.AnchorPoint = Vector2.new(0.5, 0.5)
	padf.Position = UDim2.fromScale(0.5, 0.5)
	padf.Size = UDim2.fromScale(0.32, 0.72)
	padf.BackgroundColor3 = Color3.fromRGB(251, 233, 214)
	padf.BorderSizePixel = 0
	padf.ZIndex = 9
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0.15, 0)
	c2.Parent = padf
	padf.Parent = f
	local sc = Instance.new("UIScale")
	sc.Parent = f
	f.Parent = gui
	plasters[i] = {f = f, sc = sc}
end
local skipB = Instance.new("TextButton")
skipB.Name = "Skip"
skipB.BackgroundTransparency = 1
skipB.Size = UDim2.fromScale(1, 1)
skipB.Text = ""
skipB.ZIndex = 1
skipB.Parent = gui
local skipL = label(gui, Enum.Font.GothamBlack, Color3.fromRGB(207, 211, 220))
skipL.AnchorPoint = Vector2.new(1, 1)
skipL.Text = "TAP TO SKIP >"

local ui = {
	counter = function(text, scale, color)
		counter.Visible = text ~= nil
		if text then counter.Text = text counterScale.Scale = scale or 1 counter.TextColor3 = color or Color3.new(1, 1, 1) end
	end,
	plaster = function(alpha, k)
		for _, p in ipairs(plasters) do p.f.Visible = alpha > 0 p.f.BackgroundTransparency = 1 - alpha p.sc.Scale = k or 1 end
	end,
	flash = function(alpha) flashF.BackgroundTransparency = 1 - math.clamp(alpha, 0, 1) end,
}

local function layout()
	local vp = workspace.CurrentCamera.ViewportSize
	local u = vp.Y / 100
	lower.Position = UDim2.new(0.04, 0, 1, -math.floor(7 * u))
	whoName.TextSize = math.max(12, math.floor(3 * u))
	chip.TextSize = math.max(10, math.floor(2.2 * u))
	chipPad.PaddingLeft, chipPad.PaddingRight = UDim.new(0, math.floor(0.8 * u)), UDim.new(0, math.floor(0.8 * u))
	whoList.Padding = UDim.new(0, math.floor(1.4 * u))
	ttl.TextSize = math.max(22, math.floor(8.6 * u))
	cap.TextSize = math.max(11, math.floor(2.5 * u))
	stat.TextSize = math.max(11, math.floor(2.4 * u))
	statPad.PaddingLeft, statPad.PaddingRight = UDim.new(0, math.floor(1.1 * u)), UDim.new(0, math.floor(1.1 * u))
	statPad.PaddingTop, statPad.PaddingBottom = UDim.new(0, math.floor(0.3 * u)), UDim.new(0, math.floor(0.3 * u))
	list.Padding = UDim.new(0, math.floor(0.6 * u))
	dots.Position = UDim2.new(1, -math.floor(3 * u), 0, math.floor(5 * u))
	dotsList.Padding = UDim.new(0, math.floor(1 * u))
	for _, d in ipairs(dots:GetChildren()) do if d:IsA("TextLabel") then d.TextSize = math.max(10, math.floor(2 * u)) end end
	counter.Position = UDim2.fromScale(0.5, 0.18)
	counter.TextSize = math.max(24, math.floor(7 * u))
	for _, p in ipairs(plasters) do p.f.Size = UDim2.fromOffset(math.floor(70 * u), math.floor(16 * u)) end
	skipL.Position = UDim2.new(1, -math.floor(2 * u), 1, -math.floor(2 * u))
	skipL.TextSize = math.max(10, math.floor(1.8 * u))
end

-- ---------- stage ----------
local stageFolder
local function stage()
	local y = tonumber(script:GetAttribute("VictoryStageY")) or 3000
	local origin = Vector3.new(0, y, 0)
	if stageFolder and stageFolder.Parent then return {origin = origin, folder = stageFolder, camera = workspace.CurrentCamera} end
	stageFolder = Instance.new("Folder")
	stageFolder.Name = "VictoryStage"
	local function block(size, cf, color, mat, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = stageFolder
		return p
	end
	block(Vector3.new(2, 1800, 1800), CFrame.new(origin + Vector3.new(0, -1.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(95, 154, 64), Enum.Material.Grass, Enum.PartType.Cylinder)
	block(Vector3.new(2, 300, 300), CFrame.new(origin + Vector3.new(0, -1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(194, 173, 122), Enum.Material.Sand, Enum.PartType.Cylinder)
	local rnd = Random.new(11)
	for _ = 1, 60 do
		local a, r, h = rnd:NextNumber() * math.pi * 2, 230 + rnd:NextNumber() * 300, 22 + rnd:NextNumber() * 26
		local p = origin + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		block(Vector3.new(4, h, 4), CFrame.new(p + Vector3.new(0, h / 2, 0)), Color3.fromRGB(122, 90, 56), Enum.Material.Wood)
		block(Vector3.new(18 + rnd:NextNumber() * 8, 14 + rnd:NextNumber() * 6, 18 + rnd:NextNumber() * 8), CFrame.new(p + Vector3.new(0, h + 5, 0)), rnd:NextNumber() < 0.5 and Color3.fromRGB(63, 138, 58) or Color3.fromRGB(79, 156, 68), Enum.Material.Grass)
	end
	stageFolder.Parent = workspace
	return {origin = origin, folder = stageFolder, camera = workspace.CurrentCamera}
end

-- ---------- the show ----------
local show = nil -- {entries = {{title, model, mate, name, species, stat, len}}, i, runner, t0, mode}
local savedCam = nil
local function camTake()
	local cam = workspace.CurrentCamera
	if not savedCam then savedCam = {type = cam.CameraType, subject = cam.CameraSubject, fov = cam.FieldOfView} end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 36
end
local function camGive()
	local cam = workspace.CurrentCamera
	if savedCam then
		cam.CameraType = Enum.CameraType.Custom
		local chr = player.Character
		local hum = chr and chr:FindFirstChildOfClass("Humanoid")
		cam.CameraSubject = hum or savedCam.subject
		cam.FieldOfView = savedCam.fov or 70
		savedCam = nil
	end
end
local function setDots(entries, i)
	for _, d in ipairs(dots:GetChildren()) do if d:IsA("TextLabel") then d:Destroy() end end
	if #entries < 2 then return end
	for k, e in ipairs(entries) do
		local l = label(dots, Enum.Font.GothamBlack, k == i and Color3.fromRGB(27, 20, 6) or Color3.fromRGB(143, 153, 170))
		l.LayoutOrder = k
		l.Text = " " .. tostring(e.name) .. " "
		l.BackgroundTransparency = 0.2
		l.BackgroundColor3 = k == i and YELLOW or Color3.fromRGB(20, 20, 26)
		l.TextStrokeTransparency = 1
		Instance.new("UICorner").Parent = l
	end
end
local function stopShow(why)
	if show then
		if show.runner then pcall(show.runner.destroy) end
		show = nil
	end
	gui.Enabled = false
	ui.counter(nil) ui.plaster(0, 1) ui.flash(0)
	camGive()
	script:SetAttribute("VictoryTitlesState", "idle")
	if why then script:SetAttribute("VictoryTitlesLast", why) end
end
local function startEntry(i)
	if show.runner then pcall(show.runner.destroy) show.runner = nil end
	local e = show.entries[i]
	show.i, show.t0 = i, os.clock()
	if not e then return false end
	local st = stage()
	local runner
	local ok, err = pcall(function()
		local model = e.model:Clone()
		local mate = e.mate and e.mate:Clone() or nil
		local extra = {}
		if e.title == "extinct" then
			local n = tonumber(string.match(e.stat or "", "^(%d+)")) or 6
			extra.deaths, extra.signLine = n, ("DIED %d TIMES"):format(n)
		end
		runner = Anim.new(st, ui):play(e.title, model, mate, extra)
	end)
	if not ok or not runner then
		script:SetAttribute("VictoryTitlesLast", "play failed " .. tostring(e.title) .. ": " .. string.sub(tostring(err), 1, 160))
		return false
	end
	show.runner = runner
	whoName.Text = tostring(e.name)
	chip.Text = " " .. (DINO[e.species] or string.upper(tostring(e.species or ""))) .. " "
	ttl.Text = NAMES[e.title] or string.upper(e.title)
	ttl.TextColor3 = ROAST[e.title] and PINK or YELLOW
	cap.Text = CAPS[e.title] or ""
	stat.Text = tostring(e.stat or "")
	stat.BackgroundColor3 = ROAST[e.title] and PINK or YELLOW
	stat.TextColor3 = ROAST[e.title] and Color3.fromRGB(42, 6, 16) or Color3.fromRGB(27, 20, 6)
	setDots(show.entries, i)
	script:SetAttribute("VictoryTitlesState", ("%s %d/%d %s"):format(show.mode, i, #show.entries, e.title))
	return true
end
local function beginShow(entries, mode, key, startIndex, into)
	stopShow()
	if #entries == 0 then return end
	show = {entries = entries, mode = mode, key = key}
	gui.Enabled = true
	layout()
	camTake()
	local i = startIndex or 1
	while i <= #entries and not startEntry(i) do i += 1 end
	if i > #entries then stopShow("no entry played") return end
	-- catch up (joined late): run the first title forward
	if into and into > 0.1 and show.runner then
		local n = math.floor(into / (1 / 30))
		for _ = 1, math.min(n, 300) do show.runner.step(show.runner, 1 / 30) end
	end
end

skipB.Activated:Connect(function()
	if not show or not show.runner then return end
	if os.clock() - show.t0 < (tonumber(script:GetAttribute("VictoryTapGuard")) or 1) then return end
	local i = show.i + 1
	while i <= #show.entries and not startEntry(i) do i += 1 end
	if i > #show.entries then stopShow("skipped to end") end
end)

-- per frame: run the current title after the other camera scripts
RunService:BindToRenderStep("VictoryTitles", Enum.RenderPriority.Camera.Value + 2, function(dt)
	if not show or not show.runner then return end
	dt = math.min(dt, 0.05)
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
	layout()
	local okStep, alive = pcall(show.runner.step, show.runner, dt)
	local t = os.clock() - show.t0
	-- the lower third slams in at 0.3 s
	local u = math.clamp((t - 0.3) / 0.25, 0, 1)
	local c = 1.9
	local k = u <= 0 and 0 or 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2
	lower.Visible = u > 0
	lowerScale.Scale = 1.7 + (1 - 1.7) * k
	lower.Rotation = -6 * (1 - k)
	skipL.Visible = t > (tonumber(script:GetAttribute("VictoryTapGuard")) or 1) and show.i < #show.entries
	if not okStep then
		script:SetAttribute("VictoryTitlesLast", "step error: " .. string.sub(tostring(alive), 1, 160))
		alive = false
	end
	if not alive then
		local i = show.i + 1
		while i <= #show.entries and not startEntry(i) do i += 1 end
		if i > #show.entries then stopShow("done") end
	end
end)

-- ---------- real shows: from the Hardpoint results ----------
local state = ReplicatedStorage:WaitForChild("Hardpoint", 60)
local modelsFolder = ReplicatedStorage:WaitForChild("VictoryTitleModels", 60)
local playedKey = nil
local function now() return workspace:GetServerTimeNow() end
local function check()
	if not state then return end
	if script:GetAttribute("VictoryTitlesEnabled") == false then if show and show.mode == "show" then stopShow("off") end return end
	local raw = state:GetAttribute("HpTitles")
	local endsAt = state:GetAttribute("HpResultsEndAt") or 0
	local phase = state:GetAttribute("HpPhase")
	local inMenu = player:GetAttribute("InMenu") == true
	if show and show.mode == "show" and (phase ~= "results" or inMenu or raw == "" or raw == nil) then stopShow("ended") return end
	if show or type(raw) ~= "string" or raw == "" or phase ~= "results" or inMenu then return end
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok or type(data) ~= "table" or type(data.list) ~= "table" then return end
	if data.key ~= endsAt or playedKey == endsAt then return end
	local resLen = tonumber(state:GetAttribute("HpResultsLen")) or 15
	local t = now() - (endsAt - resLen) - (tonumber(script:GetAttribute("VictoryBannerSec")) or 2)
	if t < 0 then return end
	-- which entry is due
	local entries, acc, idx, into = {}, 0, nil, 0
	local mf = modelsFolder or ReplicatedStorage:FindFirstChild("VictoryTitleModels")
	for _, e in ipairs(data.list) do
		local m = mf and mf:FindFirstChild(tostring(e.id))
		if m then table.insert(entries, {title = e.title, model = m, name = e.name, species = e.species, stat = e.stat, len = tonumber(e.len) or 5.5}) end
	end
	if #entries == 0 then playedKey = endsAt return end
	for i, e in ipairs(entries) do
		e.mate = (entries[1] ~= e and entries[1].model) or (entries[2] and entries[2].model) or nil
		if not idx and t < acc + e.len then idx, into = i, t - acc end
		acc += e.len
	end
	playedKey = endsAt
	if not idx then return end -- the show is already over
	beginShow(entries, "show", endsAt, idx, into)
end
if state then
	for _, a in ipairs({"HpTitles", "HpResultsEndAt", "HpPhase"}) do state:GetAttributeChangedSignal(a):Connect(check) end
	player:GetAttributeChangedSignal("InMenu"):Connect(check)
	task.spawn(function() while true do task.wait(0.25) check() end end)
end

-- ---------- test hook ----------
local function testHook()
	local v = player:GetAttribute("VictoryTitlesTest")
	if type(v) ~= "string" or v == "" then return end
	player:SetAttribute("VictoryTitlesTest", "")
	local chr = player.Character
	if not chr then script:SetAttribute("VictoryTitlesLast", "test: no character") return end
	local was = chr.Archivable
	chr.Archivable = true
	local ok, copy = pcall(function() return chr:Clone() end)
	chr.Archivable = was
	if not ok or not copy then script:SetAttribute("VictoryTitlesLast", "test: clone failed") return end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("ForceField") then d:Destroy() end
	end
	local entries = {}
	for title in string.gmatch(v, "[^,%s]+") do
		if NAMES[title] then
			table.insert(entries, {title = title, model = copy, mate = copy, name = player.DisplayName, species = chr:GetAttribute("Species") or "",
				stat = ({apex = "11 KILLS", king = "2:05 ON POINT", unkill = "0 DEATHS · 7 KILLS", medic = "640 HP HEALED", masher = "47 ABILITIES",
					extinct = "6 DEATHS", carried = "0 K · 0:12 ON POINT", pacifist = "0 KILLS"})[title], len = Anim.LEN[title] or 5.5})
		end
	end
	beginShow(entries, "test", nil, 1, 0)
end
player:GetAttributeChangedSignal("VictoryTitlesTest"):Connect(testHook)
