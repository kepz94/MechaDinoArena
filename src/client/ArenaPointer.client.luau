-- ArenaPointer v1.0 (Mecha Dino Arena) — points players at the island's ARENA portal (LocalScript, StarterPlayerScripts).
-- Bug hunt 2026-11-27 item 2 (new players get no pointer to the Arena: the PLAY button is off since FirstSteps 1.1 and after an
--   islet spawn the Classic camera keeps the tutorial's facing, toward the Quest Stand, with the portal behind it). Mockup
--   docs/mockups/arena_pointer_v0.1/ (in-game Studio captures). Kepu 2026-11-27 17:04 "first time load up will be play sign with the
--   light beam over portal plus first time users get the arrows To nudge them to portal"; picks "Everyone, always" (sign + beam),
--   "After 1st match" (arrows); camera turned to the portal at spawn (proposed with every option, not objected).
-- Only on a hub server (ReplicatedStorage ServerKind "hub") with Workspace.PortalIslet.Portal_arena (waited for, checked every
--   CHECK_GAP s). Everything here is local to this client (no server change, no replication).
-- 1. Sign + beam (every player): a neon yellow light pillar (cylinder, ArenaPointerBeamWidth 5 studs wide, ArenaPointerBeamHeight 170
--   tall, transparency 0.55) standing on top of the portal's Trigger part, and a BillboardGui (AlwaysOnTop, 52 x 28 studs, so it
--   scales with distance on phone and PC) ArenaPointerSignY (13) studs above the Trigger's centre: a yellow plate "PLAY" (pixel
--   font) / "4V4 ARENA MATCH" (GothamBlack: the pixel font draws "4V4" badly, mockup note) with a dark outline, under it a yellow
--   "▼" that bobs. Shown while: not InMenu, TutLane not > 0, player HubQueueState not "queued" / "found" (the queue pill takes
--   over). Switch ArenaPointerSignEnabled (read per check).
-- 2. Ground arrows (first-time players): while ArenaRecordReady is true and ArenaW + ArenaL = 0 (no Arena match recorded yet; the
--   First Steps step 1 rule), with the sign's show rules: neon yellow chevrons (two 1.5 x 0.12 x 6.5 bars at 40 degrees, ~9 studs
--   wide so they show on both sides of the dino with the camera behind it) every
--   ArenaPointerArrowGap (6) studs on the ground (raycast down onto the islet) from the point where the dino was placed by the
--   last islet spawn (player HubSpawnAt, root position 0.35 s later) to ArenaPointerArrowStop (14) studs before the portal's
--   Trigger; a light wave runs along them toward the portal. Rebuilt on every islet spawn; removed once a match is recorded.
--   Switch ArenaPointerArrowsEnabled (read per check).
-- 3. Camera at spawn: on every islet spawn (HubSpawnAt change, not InMenu), ArenaPointerCamDelay (0.35) s later, when the camera is
--   Roblox's own (CameraType Custom: the Classic camera mode) it is set ArenaPointerCamBack (22) studs behind and ArenaPointerCamUp
--   (9) studs above the root, looking at the portal (flat direction). The Shoulder camera already takes HubServer's
--   ShoulderCamLookAt and is not touched. Switch ArenaPointerCamEnabled (read per spawn).
-- Switches / numbers (script attributes): ArenaPointerEnabled (true, read at start), the three above (true), numbers above.
-- Diagnostics (script attributes): ArenaPointerVersion, ArenaPointerSign ("on" / "off <why>"), ArenaPointerArrows (chevrons shown,
--   0 = none), ArenaPointerCamTurns (count), ArenaPointerState ("notHub" / "noPortal" / "on").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("ArenaPointerVersion", VERSION)
for k, v in pairs({ArenaPointerEnabled = true, ArenaPointerSignEnabled = true, ArenaPointerArrowsEnabled = true,
	ArenaPointerCamEnabled = true, ArenaPointerSignY = 13, ArenaPointerBeamWidth = 5, ArenaPointerBeamHeight = 170,
	ArenaPointerArrowGap = 6, ArenaPointerArrowStop = 14, ArenaPointerCamDelay = 0.35, ArenaPointerCamBack = 22,
	ArenaPointerCamUp = 9}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("ArenaPointerArrows", 0)
script:SetAttribute("ArenaPointerCamTurns", 0)
if script:GetAttribute("ArenaPointerEnabled") == false then return end

local player = Players.LocalPlayer
local CHECK_GAP = 0.25
local YELLOW, PLATE = Color3.fromRGB(255, 200, 50), Color3.fromRGB(13, 18, 24)
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local function num(k, d) return tonumber(script:GetAttribute(k)) or d end
local function on(k) return script:GetAttribute(k) ~= false end

for i = 1, 40 do
	if ReplicatedStorage:GetAttribute("ServerKind") ~= nil then break end
	task.wait(0.25)
end
if ReplicatedStorage:GetAttribute("ServerKind") ~= "hub" then script:SetAttribute("ArenaPointerState", "notHub") return end
script:SetAttribute("ArenaPointerState", "noPortal")

local function trigger()
	local islet = workspace:FindFirstChild("PortalIslet")
	local portal = islet and islet:FindFirstChild("Portal_arena")
	local t = portal and portal:FindFirstChild("Trigger")
	return t and t:IsA("BasePart") and t or nil, islet
end

-- 1. sign + beam ----------------------------------------------------------------------------------------------------------
local signFolder, signArrow
local function dropSign()
	if signFolder then signFolder:Destroy() end
	signFolder, signArrow = nil, nil
end
local function makeSign(t)
	dropSign()
	local f = Instance.new("Folder")
	f.Name = "ArenaPointerSign"
	local top = t.Position + Vector3.new(0, t.Size.Y / 2, 0)
	local h, w = num("ArenaPointerBeamHeight", 170), num("ArenaPointerBeamWidth", 5)
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
	beam.Material = Enum.Material.Neon
	beam.Color = YELLOW
	beam.Transparency = 0.55
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(h, w, w)
	beam.CFrame = CFrame.new(top + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = f
	local anchor = Instance.new("Part")
	anchor.Name = "SignAnchor"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = t.Position + Vector3.new(0, num("ArenaPointerSignY", 13), 0)
	anchor.Parent = f
	local bb = Instance.new("BillboardGui")
	bb.Name = "PlaySign"
	bb.Size = UDim2.new(52, 0, 28, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 1500
	bb.Adornee = anchor
	bb.Parent = anchor
	local plate = Instance.new("Frame")
	plate.Size = UDim2.fromScale(1, 0.55)
	plate.BackgroundColor3 = YELLOW
	plate.Parent = bb
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.22, 0) c.Parent = plate
	local s = Instance.new("UIStroke") s.Color = PLATE s.Thickness = 3 s.Parent = plate
	local big = Instance.new("TextLabel")
	big.BackgroundTransparency = 1
	big.FontFace = SILK
	big.Text = "PLAY"
	big.TextScaled = true
	big.TextColor3 = PLATE
	big.Size = UDim2.fromScale(0.86, 0.52)
	big.Position = UDim2.fromScale(0.07, 0.08)
	big:SetAttribute("FontSwap", "keep")
	big.Parent = plate
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBlack
	sub.Text = "4V4 ARENA MATCH"
	sub.TextScaled = true
	sub.TextColor3 = PLATE
	sub.Size = UDim2.fromScale(0.86, 0.24)
	sub.Position = UDim2.fromScale(0.07, 0.64)
	sub:SetAttribute("FontSwap", "keep")
	sub.Parent = plate
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.TextColor3 = YELLOW
	arrow.TextStrokeColor3 = PLATE
	arrow.TextStrokeTransparency = 0
	arrow.Size = UDim2.fromScale(1, 0.38)
	arrow.Position = UDim2.fromScale(0, 0.6)
	arrow:SetAttribute("FontSwap", "keep")
	arrow.Parent = bb
	f.Parent = workspace
	signFolder, signArrow = f, arrow
end

-- 2. ground arrows --------------------------------------------------------------------------------------------------------
local arrowFolder, chevrons, arrowFrom = nil, {}, nil
local function dropArrows()
	if arrowFolder then arrowFolder:Destroy() end
	arrowFolder, chevrons = nil, {}
	script:SetAttribute("ArenaPointerArrows", 0)
end
local function makeArrows(t, islet, from)
	dropArrows()
	local goal = Vector3.new(t.Position.X, 0, t.Position.Z)
	local start = Vector3.new(from.X, 0, from.Z)
	local d = goal - start
	local len = d.Magnitude - num("ArenaPointerArrowStop", 14)
	if len <= 0 then return end
	local dir = d.Unit
	local gap = math.max(2, num("ArenaPointerArrowGap", 6))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {islet}
	local f = Instance.new("Folder")
	f.Name = "ArenaPointerArrows"
	for i = 1, math.floor(len / gap) do
		local flat = start + dir * (3 + i * gap)
		local hit = workspace:Raycast(Vector3.new(flat.X, from.Y + 20, flat.Z), Vector3.new(0, -60, 0), params)
		if hit then
			local p = hit.Position
			local m = Instance.new("Model")
			m.Name = "Chevron"
			for side = -1, 1, 2 do
				local b = Instance.new("Part")
				b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
				b.Material = Enum.Material.Neon
				b.Color = YELLOW
				b.Size = Vector3.new(1.5, 0.12, 6.5)
				b.CFrame = CFrame.lookAt(p, p + dir) * CFrame.new(side * 2.4, 0.06, 1.2) * CFrame.Angles(0, side * math.rad(40), 0) -- wider than a dino
				b.Parent = m
			end
			m.Parent = f
			table.insert(chevrons, {m = m, i = i})
		end
	end
	f.Parent = workspace
	arrowFolder = f
	script:SetAttribute("ArenaPointerArrows", #chevrons)
end

-- 3. camera at spawn ------------------------------------------------------------------------------------------------------
local function turnCamera(at)
	if not on("ArenaPointerCamEnabled") then return end
	task.delay(num("ArenaPointerCamDelay", 0.35), function()
		if player:GetAttribute("HubSpawnAt") ~= at or player:GetAttribute("InMenu") == true then return end
		local t = trigger()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		if not (t and root and cam) or cam.CameraType ~= Enum.CameraType.Custom then return end
		local d = Vector3.new(t.Position.X - root.Position.X, 0, t.Position.Z - root.Position.Z)
		if d.Magnitude < 1 then return end
		d = d.Unit
		local eye = root.Position - d * num("ArenaPointerCamBack", 22) + Vector3.new(0, num("ArenaPointerCamUp", 9), 0)
		cam.CFrame = CFrame.lookAt(eye, root.Position + d * 30 + Vector3.new(0, 6, 0))
		script:SetAttribute("ArenaPointerCamTurns", (script:GetAttribute("ArenaPointerCamTurns") or 0) + 1)
	end)
end
player:GetAttributeChangedSignal("HubSpawnAt"):Connect(function()
	local at = player:GetAttribute("HubSpawnAt")
	if type(at) ~= "number" then return end
	turnCamera(at)
	task.delay(num("ArenaPointerCamDelay", 0.35), function()
		if player:GetAttribute("HubSpawnAt") ~= at then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			arrowFrom = root.Position
			dropArrows() -- rebuilt from the new spawn on the next check
		end
	end)
end)

if type(player:GetAttribute("HubSpawnAt")) == "number" then -- already placed before this script ran
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then arrowFrom = root.Position end
end

-- the check loop + the animation ------------------------------------------------------------------------------------------
local function blockedWhy()
	if player:GetAttribute("InMenu") == true then return "menu" end
	if (tonumber(player:GetAttribute("TutLane")) or 0) > 0 then return "tutorial" end
	local q = player:GetAttribute("HubQueueState")
	if q == "queued" or q == "found" then return "queued" end
	return nil
end
local function firstTimer()
	if player:GetAttribute("ArenaRecordReady") ~= true then return false end
	return (tonumber(player:GetAttribute("ArenaW")) or 0) + (tonumber(player:GetAttribute("ArenaL")) or 0) == 0
end
task.spawn(function()
	while true do
		local t, islet = trigger()
		if not t then
			dropSign() dropArrows()
			script:SetAttribute("ArenaPointerState", "noPortal")
			script:SetAttribute("ArenaPointerSign", "off noPortal")
		else
			script:SetAttribute("ArenaPointerState", "on")
			local why = blockedWhy()
			if not on("ArenaPointerSignEnabled") then why = why or "switch" end
			if why then
				dropSign()
				script:SetAttribute("ArenaPointerSign", "off " .. why)
			else
				if not (signFolder and signFolder.Parent) then makeSign(t) end
				script:SetAttribute("ArenaPointerSign", "on")
			end
			local showArrows = on("ArenaPointerArrowsEnabled") and blockedWhy() == nil and firstTimer() and arrowFrom ~= nil
			if showArrows then
				if not (arrowFolder and arrowFolder.Parent) then makeArrows(t, islet, arrowFrom) end
			elseif arrowFolder then
				dropArrows()
			end
		end
		task.wait(CHECK_GAP)
	end
end)
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	if signArrow and signArrow.Parent then signArrow.Position = UDim2.fromScale(0, 0.6 + math.sin(t * 4) * 0.04) end
	if #chevrons > 0 then
		local w = t * 5
		for _, c in ipairs(chevrons) do
			local a = (math.sin(w - c.i * 0.8) + 1) / 2
			for _, b in ipairs(c.m:GetChildren()) do b.Transparency = 0.1 + (1 - a) * 0.65 end
		end
	end
end)
