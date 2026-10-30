-- StatusBadges v1.2 (Dino Arcade) — buff / debuff badges above a dino, on every player's client.
-- Script, RunContext Client: runs for every dino character on every client (and as a copy inside the display
-- dino), reading the replicated effect attributes set by RoarServer 1.1 on this model:
--   DEF badge (blue, down arrow): DebuffDamageTakenMul > 1 while DebuffUntil (server time) is in the future.
--   SPD badge (red, up arrow): DebuffSpeedMul > 1 while DebuffUntil is in the future, on player dinos only
--     (the display dino's scripted walk speed does not change, so it never shows SPD).
-- Each badge: arrow + label, a timer bar that empties as the effect runs out, and a pop when the effect
-- starts or is refreshed (DebuffUntil changes). The timer's full length is measured from the moment this
-- client saw DebuffUntil change, so a client that joins mid-effect starts its bar full.
-- Placement: a BillboardGui on the head's Root, StudsOffsetWorldSpace 9 (same anchor as the health bar),
-- lifted by SizeOffset so it sits above the name + health bar. Created locally (not replicated).
-- The copy that also runs from StarterCharacterScripts itself (not inside a dino) exits at once.
-- v1.1: SPD shows on every dino (players and NPCs), because the display dino now speeds up too (WalkTest 1.3).
-- v1.2 (pachy headbutt slow; mockup docs/mockups/slowed_visual_options.html option A, Kepu 2026-10-30: "lets do A with
--   blue lines around the button dropping to show its being slowed" -> the SLOW badge): a third badge "▼ SLOW" (purple
--   rgb(138, 125, 255)) while HeadbuttSlowUntil (headbutt hit, HeadbuttServer 1.0) or HeadbuttSelfSlowUntil (the pachy's
--   last charge) is in the future, its own timer bar (full length measured from when this client saw the newer stamp)
--   and a pop on each new stamp. Around it, SLOW_LINES thin blue rgb(120, 190, 255) lines keep dropping (top of the pill
--   to below the timer, SLOW_LINE_TIME s each, fading as they fall, staggered), so it reads as being dragged down. The
--   BillboardGui widens to 3 badges + room for the lines. Switch: script attribute StatusBadgesSlowEnabled (default true,
--   read at start; false = 1.1). StatusBadgesState adds "slow"; StatusBadgesSlowLeft (s, 0.1 steps).
-- Diagnostics (client-side model attributes): StatusBadgesState = "none" / "def" / "def,spd" / ...,
--   StatusBadgesVersion.
if not script.Parent:IsA("Model") then return end

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local model = script.Parent
local VERSION = "1.2"

local BADGE_W, BADGE_H, BAR_H, GAP = 76, 22, 4, 6
local GUI_OFFSET = Vector3.new(0, 9, 0) -- same anchor height as BiteTargetHealth's bar
local GUI_LIFT = 1.45                   -- SizeOffset.Y: clears the 40 px name + health bar below
local POP_SCALE, POP_TIME = 1.4, 0.3
if script:GetAttribute("StatusBadgesSlowEnabled") == nil then script:SetAttribute("StatusBadgesSlowEnabled", true) end -- v1.2
local SLOW_ON = script:GetAttribute("StatusBadgesSlowEnabled") ~= false
local SLOW_COLOR = Color3.fromRGB(138, 125, 255)  -- v1.2: badge
local LINE_COLOR = Color3.fromRGB(120, 190, 255)  -- v1.2: dropping lines
local SLOW_LINES, SLOW_LINE_TIME, LINE_MARGIN = 6, 0.55, 10 -- v1.2: lines, s per drop, px each side for them

-- badge definitions, in display order
local BADGES = {
	{key = "def", text = "▼ DEF", color = Color3.fromRGB(80, 160, 255),
		active = function(m) local v = m:GetAttribute("DebuffDamageTakenMul") return typeof(v) == "number" and v > 1 end},
	{key = "spd", text = "▲ SPD", color = Color3.fromRGB(240, 75, 60),
		active = function(m)
			local v = m:GetAttribute("DebuffSpeedMul")
			return typeof(v) == "number" and v > 1 -- v1.1: players and NPCs
		end},
}
local function slowUntil(m) -- v1.2
	return math.max(tonumber(m:GetAttribute("HeadbuttSlowUntil")) or 0, tonumber(m:GetAttribute("HeadbuttSelfSlowUntil")) or 0)
end
if SLOW_ON then
	table.insert(BADGES, {key = "slow", text = "▼ SLOW", color = SLOW_COLOR, own = true})
end
local slowSeenAt, slowSeenUntil -- v1.2: when this client saw the current slow stamp, and its value
local slowLines = {} -- v1.2: {frame, phase, x}

local gui, row
local items = {} -- key -> {frame, fill, scale}
local seenAt, seenUntil -- server time this client saw the current DebuffUntil, and that value

local function show(attr, value)
	if model:GetAttribute(attr) ~= value then model:SetAttribute(attr, value) end
end

local function build()
	local head = model:FindFirstChild("Head")
	local anchor = head and head:FindFirstChild("Root")
	if not anchor then return false end
	gui = Instance.new("BillboardGui")
	gui.Name = "StatusBadges"
	gui.Size = UDim2.fromOffset(2 * BADGE_W + GAP + 8, BADGE_H + BAR_H + 6)
	if SLOW_ON then -- v1.2: 3 badges + room for the dropping lines
		gui.Size = UDim2.fromOffset(3 * BADGE_W + 2 * GAP + 8 + 2 * LINE_MARGIN, BADGE_H + BAR_H + 6 + 2 * LINE_MARGIN)
	end
	gui.StudsOffsetWorldSpace = GUI_OFFSET
	gui.SizeOffset = Vector2.new(0, GUI_LIFT)
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Adornee = anchor
	gui.ResetOnSpawn = false
	row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for i, b in ipairs(BADGES) do
		local holder = Instance.new("Frame")
		holder.Name = "Badge_" .. b.key
		holder.LayoutOrder = i
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(BADGE_W, BADGE_H + BAR_H + 3)
		holder.Visible = false
		holder.Parent = row
		local scale = Instance.new("UIScale")
		scale.Parent = holder
		local pill = Instance.new("TextLabel")
		pill.Name = "Pill"
		pill.Size = UDim2.fromOffset(BADGE_W, BADGE_H)
		pill.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		pill.BackgroundTransparency = 0.25
		pill.Font = Enum.Font.FredokaOne
		pill.Text = b.text
		pill.TextSize = 17
		pill.TextColor3 = b.color
		pill.TextStrokeTransparency = 0.6
		pill.Parent = holder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = pill
		local stroke = Instance.new("UIStroke")
		stroke.Color = b.color
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = pill
		local back = Instance.new("Frame")
		back.Name = "TimerBack"
		back.Position = UDim2.fromOffset(6, BADGE_H + 3)
		back.Size = UDim2.fromOffset(BADGE_W - 12, BAR_H)
		back.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		back.BackgroundTransparency = 0.3
		back.BorderSizePixel = 0
		back.Parent = holder
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = b.color
		fill.BorderSizePixel = 0
		fill.Parent = back
		items[b.key] = {frame = holder, fill = fill, scale = scale}
		if b.key == "slow" then -- v1.2: dropping blue lines around the SLOW pill
			for i = 1, SLOW_LINES do
				local ln = Instance.new("Frame")
				ln.Name = "SlowLine_" .. i
				ln.BackgroundColor3 = LINE_COLOR
				ln.BorderSizePixel = 0
				ln.Size = UDim2.fromOffset(2, 7)
				ln.ZIndex = 2
				ln.Parent = holder
				local side = (i % 2 == 1) and -1 or 1
				local k = math.ceil(i / 2) -- 1..3 per side
				local x = side < 0 and (-3 - (k - 1) * 4) or (BADGE_W + 1 + (k - 1) * 4)
				table.insert(slowLines, {frame = ln, phase = (i - 1) / SLOW_LINES, x = x})
			end
		end
	end
	gui.Parent = anchor
	return true
end

local function pop(item)
	item.scale.Scale = POP_SCALE
	TweenService:Create(item.scale, TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local function onUntilChanged()
	local untilT = model:GetAttribute("DebuffUntil")
	if typeof(untilT) == "number" and untilT ~= seenUntil then
		seenUntil, seenAt = untilT, workspace:GetServerTimeNow()
		if gui then
			for _, b in ipairs(BADGES) do
				if b.active(model) then pop(items[b.key]) end
			end
		end
	end
end
model:GetAttributeChangedSignal("DebuffUntil"):Connect(onUntilChanged)

show("StatusBadgesVersion", VERSION)
local conn
conn = RunService.RenderStepped:Connect(function()
	if not model.Parent then conn:Disconnect() return end
	if not gui then
		if not build() then return end
		onUntilChanged()
	end
	local now = workspace:GetServerTimeNow()
	local untilT = model:GetAttribute("DebuffUntil")
	local live = typeof(untilT) == "number" and now < untilT
	local frac = 0
	if live and seenAt and seenUntil == untilT and untilT > seenAt then
		frac = math.clamp((untilT - now) / (untilT - seenAt), 0, 1)
	elseif live then
		frac = 1
	end
	local shownKeys = {}
	-- v1.2: SLOW badge timing (own stamp, not DebuffUntil)
	local sU = SLOW_ON and slowUntil(model) or 0
	if sU > now and sU ~= slowSeenUntil then
		local fresh = slowSeenUntil == nil or sU > slowSeenUntil
		slowSeenUntil, slowSeenAt = sU, now
		if fresh and items.slow then pop(items.slow) end
	end
	local slowLive = sU > now
	local slowFrac = (slowLive and slowSeenAt and sU > slowSeenAt) and math.clamp((sU - now) / (sU - slowSeenAt), 0, 1) or 0
	show("StatusBadgesSlowLeft", slowLive and math.floor((sU - now) * 10 + 0.5) / 10 or 0)
	if slowLive then
		local tl = os.clock()
		for _, l in ipairs(slowLines) do
			local u = ((tl / SLOW_LINE_TIME) + l.phase) % 1
			l.frame.Position = UDim2.fromOffset(l.x, -4 + u * (BADGE_H + BAR_H + 10))
			l.frame.BackgroundTransparency = 0.1 + 0.85 * u
		end
	end
	for _, b in ipairs(BADGES) do
		local item = items[b.key]
		local on
		if b.own then -- v1.2
			on = slowLive
		else
			on = live and b.active(model)
		end
		item.frame.Visible = on
		if on then
			item.fill.Size = UDim2.fromScale(b.own and slowFrac or frac, 1)
			table.insert(shownKeys, b.key)
		end
	end
	show("StatusBadgesState", #shownKeys > 0 and table.concat(shownKeys, ",") or "none")
end)
