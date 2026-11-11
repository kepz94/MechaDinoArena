-- TeamTags v1.0 (Mecha Dino Arena) — friend or foe markers over dinos, your own screen only (LocalScript,
-- StarterPlayerScripts). MDA-417, plan docs/plans/TEAM_TAGS_v1.0.md Task 2, mockup docs/mockups/team_readability_v0.1.html
-- direction B (Kepu 2026-11-10: "I have no idea who's my teammate and who's enemy Dino's. The screen is way too overcrowded";
-- picks "B · Friends marked", "Hurt nearby counts", "Both, Arena too", "Teammate names on phone").
-- On while: script attribute TeamTagsEnabled ~= false, ReplicatedStorage.Hardpoint HpLive == true, your HardpointTeam is
--   "A" / "B" and you are out of the menu (InMenu ~= true). Off: every marker removed, every old plate given back.
-- Dinos: other players' characters (team = the player's HardpointTeam) and models in Workspace.DinoIsland.Bots with
--   HardpointBotTeam (practice bots). Which marker: ReplicatedStorage.TeamTagShared.TeamTagRules 1.0 markFor:
--   friend   blue ◆ + name (FredokaOne 14 PC / 12 phone), through walls
--   chevron  red ▼ (14 px)
--   bar      red bar 70 x 7 px (phone 56 x 6) + red name (PC only)
--   target   nothing drawn here: TargetHUD 1.2 shows that dino's bar (kept on screen); its fill is red (below)
--   none     nothing
--   Inputs, every SLOW (0.2) s per dino: dist = from your HumanoidRootPart to its marker spot;
--   inSight = a ray from the camera to the anchor hits nothing but dinos (players' characters, DinoIsland.Bots, your own
--   character are left out; trees, bushes, tall grass, rocks block); cloaked = CloakedUntil in the future; isTarget = your
--   character's TargetHUDTarget is its model name and TargetHUDShown is "shown"; hurtAgo = seconds since this client saw its
--   health drop (DummyHealth, else Humanoid.Health); alive = health > 0 and still in the Workspace.
--   Numbers: script attributes TeamTagsFriendMax (400), TeamTagsChevronMax (130), TeamTagsEngageNear (25),
--   TeamTagsHurtWindow (4), TeamTagsHurtMax (60), read every SLOW s.
-- Markers: BillboardGui per dino in ScreenGui "TeamTags" (PlayerGui; ResetOnSpawn false), Adornee = Head.Root, else Head (a
--   BasePart), else HumanoidRootPart; StudsOffsetWorldSpace (0, 5, 0) on the head (HumanoidRootPart: half the model height +
--   3); AlwaysOnTop true, LightInfluence 0; sizes in pixels (they don't grow up close).
-- Old plates (BiteTargetHealth's BillboardGui "TargetBar" in the dino) while on: MaxDistance 0 (its own value kept in the
--   billboard attribute TeamTagsOldMax) on every dino with a team; on enemies the bar fill turns red rgb(224,40,74) (own
--   colour kept in TeamTagsOldFill). Enabled is never touched (TargetHUD / CloakFX switch it). Both given back when off or
--   when the dino stops being a dino we mark (team gone). A dino without a team keeps its plate.
-- Diagnostics: TeamTagsVersion, TeamTagsState ("off" / "on"), TeamTagsFriends, TeamTagsChevrons, TeamTagsBars,
--   TeamTagsTargets (counts at the last SLOW tick), TeamTagsMode ("pc" / "phone"), TeamTagsError (last error, if any).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
local SLOW = 0.2
local BLUE, BLUE_T = Color3.fromRGB(90, 160, 255), Color3.fromRGB(140, 192, 255)
local RED, RED_T = Color3.fromRGB(224, 40, 74), Color3.fromRGB(255, 143, 163)
local FONT = Enum.Font.FredokaOne
local DEFAULTS = {TeamTagsEnabled = true, TeamTagsFriendMax = 400, TeamTagsChevronMax = 130, TeamTagsEngageNear = 25,
	TeamTagsHurtWindow = 4, TeamTagsHurtMax = 60}

script:SetAttribute("TeamTagsVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("TeamTagsState", "off")

local player = Players.LocalPlayer
local hp = ReplicatedStorage:WaitForChild("Hardpoint", 60)
local shared = ReplicatedStorage:WaitForChild("TeamTagShared", 60)
if not (hp and shared) then return end
local R = require(shared:WaitForChild("TeamTagRules"))
local pg = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "TeamTags"
gui.ResetOnSpawn = false
gui.Parent = pg

local function get(k) local v = script:GetAttribute(k) if v == nil then return DEFAULTS[k] end return v end
local function now() return workspace:GetServerTimeNow() end
local function isPhone()
	local c = player.Character
	return UserInputService.TouchEnabled or (c ~= nil and c:GetAttribute("ArenaTouchState") == "on")
end

-- ---------- old plates ----------
local function plateOf(model)
	local b = model:FindFirstChild("TargetBar", true)
	return (b and b:IsA("BillboardGui")) and b or nil
end
local function hidePlate(model, enemy)
	local b = plateOf(model)
	if not b then return end
	if b:GetAttribute("TeamTagsOldMax") == nil then b:SetAttribute("TeamTagsOldMax", b.MaxDistance) end
	b.MaxDistance = 0
	local fill = b:FindFirstChild("Fill", true)
	if fill and fill:IsA("GuiObject") then
		if enemy then
			if b:GetAttribute("TeamTagsOldFill") == nil then b:SetAttribute("TeamTagsOldFill", fill.BackgroundColor3) end
			fill.BackgroundColor3 = RED
		elseif b:GetAttribute("TeamTagsOldFill") ~= nil then
			fill.BackgroundColor3 = b:GetAttribute("TeamTagsOldFill")
			b:SetAttribute("TeamTagsOldFill", nil)
		end
	end
end
local function givePlate(model)
	local b = model and plateOf(model)
	if not b then return end
	local m = b:GetAttribute("TeamTagsOldMax")
	if m ~= nil then b.MaxDistance = m b:SetAttribute("TeamTagsOldMax", nil) end
	local f = b:GetAttribute("TeamTagsOldFill")
	local fill = b:FindFirstChild("Fill", true)
	if f ~= nil and fill and fill:IsA("GuiObject") then fill.BackgroundColor3 = f end
	b:SetAttribute("TeamTagsOldFill", nil)
end

-- ---------- markers ----------
local recs = {} -- [model] = {bb, name, chev, bar, fill, nm, lastHp, hurtAt, mark}
local function newMarker(model)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Tag_" .. model.Name
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(160, 44)
	bb.Enabled = false
	local col = Instance.new("Frame")
	col.BackgroundTransparency = 1
	col.Size = UDim2.fromScale(1, 1)
	col.Parent = bb
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = col
	local nm = Instance.new("TextLabel")
	nm.Name = "Name"
	nm.BackgroundTransparency = 1
	nm.Font = FONT
	nm.TextSize = 14
	nm.TextStrokeTransparency = 0.35
	nm.Size = UDim2.new(1, 0, 0, 16)
	nm.LayoutOrder = 1
	nm.Parent = col
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromOffset(70, 7)
	bar.LayoutOrder = 2
	bar.Parent = col
	do
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 3) c.Parent = bar
		local s = Instance.new("UIStroke") s.Color = Color3.new(0, 0, 0) s.Transparency = 0.4 s.Thickness = 1 s.Parent = bar
	end
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bar
	do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 3) c.Parent = fill end
	local chev = Instance.new("TextLabel")
	chev.Name = "Chevron"
	chev.BackgroundTransparency = 1
	chev.Font = FONT
	chev.Text = "▼"
	chev.TextSize = 14
	chev.TextColor3 = RED
	chev.TextStrokeTransparency = 0.3
	chev.Size = UDim2.new(1, 0, 0, 14)
	chev.LayoutOrder = 3
	chev.Parent = col
	bb.Parent = gui
	return {bb = bb, nm = nm, bar = bar, fill = fill, chev = chev}
end

local function anchorOf(model)
	local head = model:FindFirstChild("Head")
	local root = head and head:FindFirstChild("Root")
	if root and root:IsA("BasePart") then return root, Vector3.new(0, 5, 0) end
	if head and head:IsA("BasePart") then return head, Vector3.new(0, 3, 0) end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		local ok, size = pcall(function() return model:GetExtentsSize() end)
		return hrp, Vector3.new(0, (ok and size.Y or 8) * 0.5 + 3, 0)
	end
	return nil
end

local function healthOf(model)
	local d = tonumber(model:GetAttribute("DummyHealth"))
	local dm = tonumber(model:GetAttribute("DummyMaxHealth"))
	if d then return d, dm or d end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then return hum.Health, hum.MaxHealth end
	return 0, 1
end

local function dropRec(model)
	local r = recs[model]
	if r then r.bb:Destroy() recs[model] = nil end
	givePlate(model)
end

local function clearAll()
	for m in pairs(recs) do dropRec(m) end
end

-- the dinos with a team right now: {[model] = {team, name}}
local function collect()
	local out = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		local t = pl:GetAttribute("HardpointTeam")
		if pl ~= player and c and c.Parent and (t == "A" or t == "B") and pl:GetAttribute("InMenu") ~= true then
			out[c] = {team = t, name = pl.DisplayName}
		end
	end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			local t = m:GetAttribute("HardpointBotTeam")
			if m:IsA("Model") and (t == "A" or t == "B") then
				out[m] = {team = t, name = m:GetAttribute("DisplayName") or m.Name}
			end
		end
	end
	return out, bots
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function slowTick()
	local myTeam = player:GetAttribute("HardpointTeam")
	local on = get("TeamTagsEnabled") ~= false and hp:GetAttribute("HpLive") == true and (myTeam == "A" or myTeam == "B")
		and player:GetAttribute("InMenu") ~= true
	if not on then
		if script:GetAttribute("TeamTagsState") ~= "off" then
			clearAll()
			script:SetAttribute("TeamTagsState", "off")
		end
		return
	end
	script:SetAttribute("TeamTagsState", "on")
	local phone = isPhone()
	script:SetAttribute("TeamTagsMode", phone and "phone" or "pc")
	local cfg = {friendMax = get("TeamTagsFriendMax"), chevronMax = get("TeamTagsChevronMax"), engageNear = get("TeamTagsEngageNear"),
		hurtWindow = get("TeamTagsHurtWindow"), hurtMax = get("TeamTagsHurtMax")}
	local dinos, botsFolder = collect()
	-- gone / no longer marked
	for m in pairs(recs) do
		if not dinos[m] then dropRec(m) end
	end
	local myChar = player.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	local exclude = {gui}
	if myChar then table.insert(exclude, myChar) end
	if botsFolder then table.insert(exclude, botsFolder) end
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(exclude, pl.Character) end end
	rayParams.FilterDescendantsInstances = exclude
	local target = myChar and myChar:GetAttribute("TargetHUDShown") == "shown" and myChar:GetAttribute("TargetHUDTarget") or nil
	local t = now()
	local counts = {friend = 0, chevron = 0, bar = 0, target = 0}
	for m, info in pairs(dinos) do
		local r = recs[m]
		if not r then
			r = newMarker(m)
			recs[m] = r
		end
		local rel = R.relation(myTeam, info.team)
		hidePlate(m, rel == "enemy")
		local anchor, off = anchorOf(m)
		local h, hmax = healthOf(m)
		if r.lastHp and h < r.lastHp - 1e-3 then r.hurtAt = t end
		r.lastHp = h
		local alive = anchor ~= nil and h > 0 and m:IsDescendantOf(workspace)
		local dist, inSight = math.huge, false
		if anchor and myRoot then
			local pos = anchor.Position + off
			dist = (pos - myRoot.Position).Magnitude
			if rel == "enemy" and dist <= cfg.chevronMax then
				local from = cam.CFrame.Position
				local hit = workspace:Raycast(from, pos - from, rayParams)
				inSight = hit == nil
			end
		end
		local cu = m:GetAttribute("CloakedUntil")
		local mark = R.markFor(rel, {alive = alive, dist = dist, inSight = inSight, cloaked = type(cu) == "number" and cu > t,
			isTarget = target ~= nil and target == m.Name, hurtAgo = r.hurtAt and (t - r.hurtAt) or nil}, cfg)
		r.mark = mark
		if counts[mark] then counts[mark] += 1 end
		-- draw
		r.bb.Adornee = anchor
		r.bb.StudsOffsetWorldSpace = off or Vector3.zero
		r.bb.Enabled = anchor ~= nil and (mark == "friend" or mark == "chevron" or mark == "bar")
		if mark == "friend" then
			r.nm.Visible, r.bar.Visible, r.chev.Visible = true, false, false
			r.nm.Text = "◆ " .. info.name
			r.nm.TextColor3 = BLUE_T
			r.nm.TextSize = phone and 12 or 14
		elseif mark == "bar" then
			r.nm.Visible, r.bar.Visible, r.chev.Visible = not phone, true, false
			r.nm.Text = info.name
			r.nm.TextColor3 = RED_T
			r.nm.TextSize = 14
			r.bar.Size = phone and UDim2.fromOffset(56, 6) or UDim2.fromOffset(70, 7)
			r.fill.Size = UDim2.fromScale(math.clamp(h / math.max(hmax, 1e-3), 0, 1), 1)
		elseif mark == "chevron" then
			r.nm.Visible, r.bar.Visible, r.chev.Visible = false, false, true
		end
	end
	script:SetAttribute("TeamTagsFriends", counts.friend)
	script:SetAttribute("TeamTagsChevrons", counts.chevron)
	script:SetAttribute("TeamTagsBars", counts.bar)
	script:SetAttribute("TeamTagsTargets", counts.target)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < SLOW then return end
	acc = 0
	local ok, err = pcall(slowTick)
	if not ok then script:SetAttribute("TeamTagsError", tostring(err)) end
end)
script.Destroying:Connect(clearAll)
