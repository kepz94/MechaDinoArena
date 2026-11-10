-- TrooStatsFX v1.0 (Mecha Dino Arena) — the client side of the Troodon's own stat rows (StarterPlayerScripts; SkillTree 1.88,
-- plan docs/plans/TROODON_STATS_v1.0.md, MDA-389; Kepu 2026-11-10 12:00 picks, 12:03 "Build"). Everything local, in
-- Workspace.TrooStatsFX (no collision / queries / shadows).
-- * Night Watcher: every 0.15 s, models with TrooSeenUntil ahead whose TrooSeenBy is my character's name, or whose TrooSeenSquad
--   is my SquadId (not ""), wear an amber outline through walls (Highlight AlwaysOnTop, fill off); the TrooStatsFX_maxOutlines
--   (10) nearest only (Roblox draws 31 Highlights per player).
-- * Hunter's Eyes: models with TrooMarkedUntil ahead marked by me or (TrooMarkedSquad) my squad wear a red "◎" tag; with
--   TrooMarkedSee (star) also a red outline through walls (counted in the same cap).
-- * Night Watcher star: TrooWatchDoubleAt on a model -> an amber "x2" pop + flash.
-- * Quick Feet star: when my own troodon's GlideLocal (GliderTest) goes true -> false and its TrooStatFeetTrailOn is true, fire
--   DinoTrooTrailRequest(root position) (TrooStatsServer 1.0 checks it). Any troodon's TrooTrailPadAt -> a teal-green disc at
--   TrooTrailPadCenter, TrooTrailPadRadius wide, fading out by TrooTrailPadUntil, with rising motes.
-- Switches (script attributes, default true, read at each use): TrooStatsFXEnabled, TrooStatsFX_watchEnabled,
--   TrooStatsFX_markEnabled, TrooStatsFX_trailEnabled. Diagnostics: script TrooStatsFXOutlines (outlines shown now),
--   TrooStatsFXLast.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
script:SetAttribute("TrooStatsFXVersion", VERSION)
for _, k in ipairs({"TrooStatsFXEnabled", "TrooStatsFX_watchEnabled", "TrooStatsFX_markEnabled", "TrooStatsFX_trailEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
if script:GetAttribute("TrooStatsFX_maxOutlines") == nil then script:SetAttribute("TrooStatsFX_maxOutlines", 10) end
local function on(k) return script:GetAttribute("TrooStatsFXEnabled") ~= false and (not k or script:GetAttribute("TrooStatsFX_" .. k .. "Enabled") ~= false) end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k) local v = m:GetAttribute(k); return typeof(v) == "number" and v or nil end
local player = Players.LocalPlayer
local AMBER, RED, TRAIL = Color3.fromHex("f0a62a"), Color3.fromHex("ff5a4f"), Color3.fromHex("5fe3c0")

local fx = workspace:FindFirstChild("TrooStatsFX")
if not fx then fx = Instance.new("Folder"); fx.Name = "TrooStatsFX"; fx.Parent = workspace end
local function part(size, color, cf, transp, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material, p.Color, p.Size, p.Transparency, p.CFrame = Enum.Material.Neon, color, size, transp or 0, cf
	if shape then p.Shape = shape end
	p.Parent = fx
	return p
end
local function animate(dur, fn, done)
	local t0 = os.clock()
	local c
	c = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / math.max(1e-3, dur), 0, 1)
		local ok = pcall(fn, u)
		if u >= 1 or not ok then c:Disconnect(); if done then done() end end
	end)
end
local function models()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character and pl ~= player then table.insert(list, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	if bots then for _, b in ipairs(bots:GetChildren()) do if b:IsA("Model") then table.insert(list, b) end end end
	return list
end
local function mySquad() local s = player:GetAttribute("SquadId"); return type(s) == "string" and s or "" end

-- outlines + marks -------------------------------------------------------------------------------------------------------------
local shown = {} -- model -> {h = Highlight, tag = BillboardGui}
local function tag(m)
	local root = m:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local b = Instance.new("BillboardGui")
	b.Name = "TrooMarkTag"
	b.Size = UDim2.fromOffset(38, 38)
	b.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	b.AlwaysOnTop = true
	b.Adornee = root
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = RED
	l.TextStrokeTransparency = 0.2
	l.Text = "◎"
	l.Parent = b
	b.Parent = fx
	return b
end
task.spawn(function()
	while true do
		task.wait(0.15)
		local t = now()
		local me = player.Character
		local myName, sq = me and me.Name or "", mySquad()
		local myRoot = me and me:FindFirstChild("HumanoidRootPart")
		local want = {}
		if on() then
			for _, m in ipairs(models()) do
				local root = m:FindFirstChild("HumanoidRootPart")
				if root then
					local w = {}
					if on("watch") and (num(m, "TrooSeenUntil") or 0) > t then
						local by, s = m:GetAttribute("TrooSeenBy"), m:GetAttribute("TrooSeenSquad")
						if by == myName or (s ~= nil and s ~= "" and s == sq) then w.outline = AMBER end
					end
					if on("mark") and (num(m, "TrooMarkedUntil") or 0) > t then
						local by, s = m:GetAttribute("TrooMarkedBy"), m:GetAttribute("TrooMarkedSquad")
						if by == myName or (s ~= nil and s ~= "" and s == sq) then
							w.tag = true
							if m:GetAttribute("TrooMarkedSee") == true then w.outline = RED end
						end
					end
					if w.outline or w.tag then
						w.d = myRoot and (root.Position - myRoot.Position).Magnitude or 0
						want[m] = w
					end
				end
			end
		end
		-- the nearest N get outlines
		local order = {}
		for m, w in pairs(want) do if w.outline then table.insert(order, m) end end
		table.sort(order, function(a, b) return want[a].d < want[b].d end)
		local maxN = math.max(0, math.floor(tonumber(script:GetAttribute("TrooStatsFX_maxOutlines")) or 10))
		for i, m in ipairs(order) do if i > maxN then want[m].outline = nil end end
		local n = 0
		for m, w in pairs(want) do
			local s = shown[m] or {}
			shown[m] = s
			if w.outline then
				n += 1
				if not s.h then
					s.h = Instance.new("Highlight")
					s.h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					s.h.FillTransparency = 1
					s.h.OutlineTransparency = 0
					s.h.Adornee = m
					s.h.Parent = fx
				end
				s.h.OutlineColor = w.outline
			elseif s.h then s.h:Destroy(); s.h = nil end
			if w.tag and not s.tag then s.tag = tag(m) elseif not w.tag and s.tag then s.tag:Destroy(); s.tag = nil end
		end
		for m, s in pairs(shown) do
			if not want[m] then
				if s.h then s.h:Destroy() end
				if s.tag then s.tag:Destroy() end
				shown[m] = nil
			end
		end
		script:SetAttribute("TrooStatsFXOutlines", n)
	end
end)

-- Night Watcher star pop -------------------------------------------------------------------------------------------------------
local function pop(m)
	m:GetAttributeChangedSignal("TrooWatchDoubleAt"):Connect(function()
		if not on("watch") then return end
		local root = m:FindFirstChild("HumanoidRootPart")
		if not root then return end
		script:SetAttribute("TrooStatsFXLast", "watch:x2")
		local b = Instance.new("BillboardGui")
		b.Size = UDim2.fromOffset(70, 34)
		b.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
		b.AlwaysOnTop = true
		b.Adornee = root
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = AMBER
		l.TextStrokeTransparency = 0.1
		l.Text = "x2"
		l.Parent = b
		b.Parent = fx
		animate(0.8, function(u) b.StudsOffsetWorldSpace = Vector3.new(0, 6 + u * 4, 0); l.TextTransparency = u end, function() b:Destroy() end)
		local f = part(Vector3.one * 3, AMBER, root.CFrame, 0.2, Enum.PartType.Ball)
		animate(0.25, function(u) f.Size = Vector3.one * (3 + u * 6); f.Transparency = 0.2 + 0.8 * u end, function() f:Destroy() end)
	end)
end

-- Quick Feet star: trail pads ---------------------------------------------------------------------------------------------------
local function padFx(c)
	c:GetAttributeChangedSignal("TrooTrailPadAt"):Connect(function()
		if not on("trail") then return end
		local center, R, untilT = c:GetAttribute("TrooTrailPadCenter"), num(c, "TrooTrailPadRadius"), num(c, "TrooTrailPadUntil")
		if typeof(center) ~= "Vector3" or not R or not untilT then return end
		script:SetAttribute("TrooStatsFXLast", "trail:pad")
		local life = math.max(0.3, untilT - now())
		local disc = part(Vector3.new(0.2, R * 2, R * 2), TRAIL, CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.45, Enum.PartType.Cylinder)
		local rim = part(Vector3.new(0.25, R * 2.06, R * 2.06), Color3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.6, Enum.PartType.Cylinder)
		local a = Instance.new("Attachment")
		a.Parent = disc
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(TRAIL)
		e.LightEmission = 1
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(4, 8)
		e.EmissionDirection = Enum.NormalId.Right
		e.SpreadAngle = Vector2.new(60, 60)
		e.Rate = 30
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.Parent = a
		animate(life, function(u) disc.Transparency = 0.45 + 0.55 * u ^ 2; rim.Transparency = 0.6 + 0.4 * u end, function() disc:Destroy(); rim:Destroy() end)
	end)
end
local trailRemote
local function watchMine(c)
	local last = c:GetAttribute("GlideLocal") == true
	c:GetAttributeChangedSignal("GlideLocal"):Connect(function()
		local g = c:GetAttribute("GlideLocal") == true
		if last and not g and on("trail") and c:GetAttribute("TrooStatFeetTrailOn") == true then
			local root = c:FindFirstChild("HumanoidRootPart")
			trailRemote = trailRemote or ReplicatedStorage:FindFirstChild("DinoTrooTrailRequest")
			if root and trailRemote then
				trailRemote:FireServer(root.Position)
				script:SetAttribute("TrooStatsFXLast", "trail:request")
			end
		end
		last = g
	end)
end
local function onChar(c, mine)
	pop(c)
	padFx(c)
	if mine then watchMine(c) end
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(function(c) onChar(c, pl == player) end)
	if pl.Character then onChar(pl.Character, pl == player) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 30)
	local bots = isl and isl:WaitForChild("Bots", 30)
	if not bots then return end
	bots.ChildAdded:Connect(pop)
	for _, b in ipairs(bots:GetChildren()) do pop(b) end
end)
