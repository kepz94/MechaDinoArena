-- TargetHUD v1.0 (Mecha Dino Arena) — the health of the dino you are hitting, on your own screen (LocalScript in the
-- character, this client only). Kepu 2026-10-29: "The health bar for any enemy im attacking needs to be visible for my
-- screen"; mockup docs/mockups/hud_target_slash_options.html, picks "1 · Top centre" and "Any hit you land".
-- Layout: ScreenGui "TargetHUD" (DisplayOrder 6, ResetOnSpawn) -> frame "Target" at the top centre: AnchorPoint (0.5, 0)
--   at (0.5, 0, 0, 12), width 38% of the screen clamped to 240..420 px, dark panel (20, 20, 26; 0.13 transparent, radius
--   10) with a red stroke (240, 90, 79; 0.33 transparent); row 1: the name (upper case, white, left) and "hp / max" (red,
--   right), FredokaOne 15; row 2: the bar (10 px, back 42, 20, 20, fill red (240, 90, 79) -> orange (255, 155, 46),
--   width tweened over 0.25 s). The bar over the target's head (BiteTargetHealth) is unchanged.
-- Target = the model of the newest hit you landed, from (all server attributes, nothing new on the server):
--   * bite: your character's BiteHitAt -> model named BiteHitTarget (BiteServer; source "bite");
--   * pounce / pin: your PounceBiteAt -> the model holding your PounceLatchPart.Value (PounceServer; "pounce");
--   * Shock Cannon / Shock Mine / Arena hits: a model whose LastHitBy (ScreechServer, MineServer, ArenaPvP) is your
--     character's name gets a new LastHitAt (checked every SCAN s over the bots folder, workspace models with
--     DummyHealth and other players' characters; "lastHit"). The bots folder is the first Workspace descendant named
--     "Bots" (BotServer: Workspace.DinoIsland.Bots), looked up again when it is gone.
--   * bleed: the shown target's DummyHealth drops while its SkillBleedBy is your name and SkillBleedUntil is in the
--     future (SkillEffects; "bleed").
--   Not attributed by the server, so not shown: tree rams (RamServer has no dino target).
-- Shown from the first hit until HOLD (4) s after the newest one, and the whole time you are latched on it
--   (PounceLatched with PounceLatchPart in that model); then it fades out over 0.25 s. A hit on another model switches
--   the bar to it. Health = DummyHealth / DummyMaxHealth (Humanoid Health / MaxHealth when missing); a model that is
--   removed hides the bar. Name = DisplayName attribute, else the player's DisplayName, else the model name.
-- Switch: script attribute TargetHUDEnabled (default true, read at start; false = no bar).
-- Diagnostics (character attributes, this client): TargetHUDVersion, TargetHUDTarget (model name, "" = none),
--   TargetHUDSource ("bite" / "pounce" / "lastHit" / "bleed" / ""), TargetHUDShown ("shown" / "hidden"),
--   TargetHUDHits (hits counted), TargetHUDHealth ("hp/max").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
local HOLD = 4
local SCAN = 0.15
local FADE = 0.25
local RED = Color3.fromRGB(240, 90, 79)
local ORANGE = Color3.fromRGB(255, 155, 46)

local char = script.Parent
local player = Players.LocalPlayer
char:SetAttribute("TargetHUDVersion", VERSION)
if script:GetAttribute("TargetHUDEnabled") == nil then script:SetAttribute("TargetHUDEnabled", true) end
if script:GetAttribute("TargetHUDEnabled") == false then
	char:SetAttribute("TargetHUDShown", "hidden")
	return
end

local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("TargetHUD")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "TargetHUD"
gui.ResetOnSpawn = true
gui.DisplayOrder = 6

local panel = Instance.new("Frame")
panel.Name = "Target"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.new(0.38, 0, 0, 46)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
panel.BackgroundTransparency = 0.13
panel.Visible = false
panel.Parent = gui
local sc = Instance.new("UISizeConstraint")
sc.MinSize, sc.MaxSize = Vector2.new(240, 0), Vector2.new(420, math.huge)
sc.Parent = panel
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 10)
pc.Parent = panel
local ps = Instance.new("UIStroke")
ps.Color, ps.Transparency, ps.Thickness = RED, 0.33, 1.5
ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ps.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 5), UDim.new(0, 6)
pad.Parent = panel

local function label(align, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 15
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = align
	l.Size = UDim2.new(0.6, 0, 0, 18)
	l.Parent = panel
	return l
end
local nameL = label(Enum.TextXAlignment.Left, Color3.new(1, 1, 1))
nameL.Name = "Name"
nameL.TextTruncate = Enum.TextTruncate.AtEnd
local hpL = label(Enum.TextXAlignment.Right, RED)
hpL.Name = "HP"
hpL.AnchorPoint = Vector2.new(1, 0)
hpL.Position = UDim2.fromScale(1, 0)
hpL.Size = UDim2.new(0.4, 0, 0, 18)
local back = Instance.new("Frame")
back.Name = "Bar"
back.Position = UDim2.fromOffset(0, 23)
back.Size = UDim2.new(1, 0, 0, 10)
back.BackgroundColor3 = Color3.fromRGB(42, 20, 20)
back.BorderSizePixel = 0
back.ClipsDescendants = true
back.Parent = panel
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 10)
bc.Parent = back
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BorderSizePixel = 0
fill.Parent = back
local fc = Instance.new("UICorner")
fc.CornerRadius = UDim.new(0, 10)
fc.Parent = fill
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(RED, ORANGE)
grad.Parent = fill
gui.Parent = pg

-- state
local target, lastHit, source = nil, -math.huge, ""
local hits = 0
local lastFrac
local seenLastHitAt = setmetatable({}, {__mode = "k"})
local lastHp

local function healthOf(m)
	local hp, max = tonumber(m:GetAttribute("DummyHealth")), tonumber(m:GetAttribute("DummyMaxHealth"))
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hp and hum then hp = hum.Health end
	if not max and hum then max = hum.MaxHealth end
	return math.max(0, hp or 0), math.max(1, max or hp or 1)
end
local function nameOf(m)
	local dn = m:GetAttribute("DisplayName")
	if type(dn) == "string" and dn ~= "" then return dn end
	local p = Players:GetPlayerFromCharacter(m)
	if p then return p.DisplayName end
	return m.Name
end

local function noteHit(m, src)
	if not (m and m:IsA("Model") and m ~= char) then return end
	if m ~= target then
		target, lastFrac = m, nil
		lastHp = healthOf(m)
		char:SetAttribute("TargetHUDTarget", m.Name)
	end
	lastHit, source = os.clock(), src
	hits += 1
	char:SetAttribute("TargetHUDSource", src)
	char:SetAttribute("TargetHUDHits", hits)
end

-- the bots folder (Workspace.DinoIsland.Bots), cached
local botsFolder
local function getBots()
	if botsFolder and botsFolder:IsDescendantOf(workspace) then return botsFolder end
	botsFolder = workspace:FindFirstChild("Bots") or workspace:FindFirstChild("Bots", true)
	return botsFolder
end
-- a model by name: bots folder first, then a player's character, then the workspace top level
local function findModel(name)
	if type(name) ~= "string" or name == "" then return nil end
	local bots = getBots()
	local m = bots and bots:FindFirstChild(name)
	if m then return m end
	local p = Players:FindFirstChild(name)
	if p and p.Character then return p.Character end
	m = workspace:FindFirstChild(name)
	return (m and m:IsA("Model")) and m or nil
end
-- the target model a hitbox / root part belongs to
local function modelOfPart(part)
	local x = part
	while x and x ~= workspace do
		if x:IsA("Model") and (x:GetAttribute("DummyHealth") ~= nil or x:FindFirstChildOfClass("Humanoid")) then return x end
		x = x.Parent
	end
	return nil
end

char:GetAttributeChangedSignal("BiteHitAt"):Connect(function()
	noteHit(findModel(char:GetAttribute("BiteHitTarget")), "bite")
end)
local function latchModel()
	local v = char:FindFirstChild("PounceLatchPart")
	local part = v and v:IsA("ObjectValue") and v.Value
	return part and modelOfPart(part) or nil
end
char:GetAttributeChangedSignal("PounceBiteAt"):Connect(function()
	noteHit(latchModel() or findModel(char:GetAttribute("PounceLatchTarget")), "pounce")
end)

-- LastHitBy scan (Shock Cannon, Shock Mine, Arena hits)
local candidates, candAt = {}, -math.huge
local function refreshCandidates()
	candidates = {}
	local bots = getBots()
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") then candidates[#candidates + 1] = m end
		end
	end
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m ~= char and m:GetAttribute("DummyHealth") ~= nil then candidates[#candidates + 1] = m end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then candidates[#candidates + 1] = p.Character end
	end
	candAt = os.clock()
end
task.spawn(function()
	while gui.Parent do
		if os.clock() - candAt > 2 then refreshCandidates() end
		for _, m in ipairs(candidates) do
			if m.Parent then
				local at = m:GetAttribute("LastHitAt")
				if m:GetAttribute("LastHitBy") == char.Name and type(at) == "number" then
					local seen = seenLastHitAt[m]
					if seen == nil then
						seenLastHitAt[m] = at -- first look: only later hits count
						if workspace:GetServerTimeNow() - at < 0.5 then noteHit(m, "lastHit") end
					elseif at ~= seen then
						seenLastHitAt[m] = at
						noteHit(m, "lastHit")
					end
				elseif type(at) == "number" then
					seenLastHitAt[m] = at
				end
			end
		end
		task.wait(SCAN)
	end
end)

-- draw
local shown = false
local fadeT = 0
RunService.RenderStepped:Connect(function(dt)
	local m = target
	if m and not m:IsDescendantOf(workspace) then
		target, m = nil, nil
		char:SetAttribute("TargetHUDTarget", "")
	end
	local want = false
	if m then
		local hp, max = healthOf(m)
		-- bleed ticks from you keep the bar up
		if lastHp and hp < lastHp then
			local by, untilT = m:GetAttribute("SkillBleedBy"), m:GetAttribute("SkillBleedUntil")
			if by == char.Name and type(untilT) == "number" and workspace:GetServerTimeNow() <= untilT + 0.5
				and os.clock() - lastHit > 0.05 then
				noteHit(m, "bleed")
			end
		end
		lastHp = hp
		local latched = char:GetAttribute("PounceLatched") == true and latchModel() == m
		want = latched or os.clock() - lastHit < HOLD
		if want then
			nameL.Text = string.upper(nameOf(m))
			local txt = ("%d / %d"):format(math.floor(hp + 0.5), math.floor(max + 0.5))
			hpL.Text = txt
			local frac = math.clamp(hp / max, 0, 1)
			if frac ~= lastFrac then
				if lastFrac == nil then
					fill.Size = UDim2.fromScale(frac, 1)
				else
					TweenService:Create(fill, TweenInfo.new(0.25), {Size = UDim2.fromScale(frac, 1)}):Play()
				end
				lastFrac = frac
				char:SetAttribute("TargetHUDHealth", ("%d/%d"):format(math.floor(hp + 0.5), math.floor(max + 0.5)))
			end
		end
	end
	-- show / fade
	if want then
		fadeT = 0
		if not shown then
			shown = true
			panel.Visible = true
			char:SetAttribute("TargetHUDShown", "shown")
		end
	elseif shown then
		fadeT += dt
		if fadeT >= FADE then
			shown = false
			panel.Visible = false
			lastFrac = nil
			char:SetAttribute("TargetHUDShown", "hidden")
		end
	end
	local a = shown and math.clamp(fadeT / FADE, 0, 1) or 1
	panel.BackgroundTransparency = 0.13 + 0.87 * a
	ps.Transparency = 0.33 + 0.67 * a
	nameL.TextTransparency, hpL.TextTransparency = a, a
	nameL.TextStrokeTransparency, hpL.TextStrokeTransparency = 0.6 + 0.4 * a, 0.6 + 0.4 * a
	back.BackgroundTransparency = a
	fill.BackgroundTransparency = a
end)
char:SetAttribute("TargetHUDShown", "hidden")
char:SetAttribute("TargetHUDTarget", "")
