-- MedStationServer v1.3 (Mecha Dino Arena) — the pachy's Med-Station, a Health slot part (path "medstation"). MDA-125,
-- plan docs/plans/PACHY_MEDSTATION_v1.0.md, mockup docs/mockups/pachy_medstation_options.html look "C · Pulse pad".
-- Kepu 2026-10-30: "drop a Machine that provides heals in an area for 5 seconds and heals your health up to 50 percent in
--   those 5 seconds. It can't be dropped while pinned down by another dinosaur or stunned. This gives the pachy heals but
--   limits its mobility so it's not broken". Answers: heal 50% of max over 5 s; cooldown 30 s from the drop; heals only
--   inside the circle (leaving pauses it, hits don't stop it, the pad still ends on time); only the owner heals; star =
--   10 s (full heal), not two pads.
-- Settings come from the character (SkillEffects 1.22): MedEnabled (bought AND slotted on a pachy), MedRadius (12; 18 from
--   II), MedTime (5; 7 from III; 10 at star), MedRate (0.10 = share of MaxHealth per second), MedCooldown (30).
-- Client -> server: ReplicatedStorage.DinoMedRequest:FireServer(clientServerTime) (MechaButtons 1.18). Checks, first
--   failing wins: "badArg", "dead", "disabled" (MedStationServerEnabled false or MedEnabled ~= true), "menu" (player
--   InMenu), "stunned" (StunnedUntil > now), "pinned" (PinHeld), "cooldown" (now < MedReadyAt), "ok".
--   ok: MedReadyAt = now + MedCooldown, MedActiveUntil = now + MedTime, MedCount + 1, MedDroppedAt = now (last). A pad
--   still running from before is removed first ("replaced"; not reachable at 30 s cooldown > 10 s).
-- Drop: the pad sits on the ground under the pachy's HumanoidRootPart (ray straight down up to 60 studs that respects
--   CanCollide and skips the pachy and every pad; no ground found = at the root's height minus half the body height).
-- Heal: every TICK (0.25) s while now < MedActiveUntil and the owner is alive: inside = the flat (X/Z) distance from the
--   owner's HumanoidRootPart to the pad centre <= MedRadius. Inside and Humanoid.Health < MaxHealth -> Health +=
--   MedRate x MaxHealth x TICK, capped at MaxHealth (the ArenaPvP bridge copies a Humanoid heal into DummyHealth).
--   Character MedInside (true / false while a pad runs, nil after), MedHealed (HP added by the current pad, 0.1 steps),
--   MedHealedTotal. Only the owner is healed. SkillEffects 1.22 skips its 8 s heal while MedInside is true.
-- End: at MedActiveUntil ("time"), owner dies ("dead"), leaves or the character is removed ("removed"), MedEnabled turns
--   false ("disabled"). Early ends set MedActiveUntil = now. Character MedEndReason.
-- Look (pulse pad): Model "MedPad" in Workspace.MedStations (attributes MedOwner, MedState "running"): "Base" (dark disc,
--   PAD_SIZE x the dino's scale wide), "Rim" (green neon disc a little wider and thinner under it), "Core" (green neon
--   disc on top, half as wide) with a green PointLight "Glow" (range MedRadius), and "Edge_1..24": dark-green neon blocks
--   laid round the circle at MedRadius with gaps (a dashed ring on the ground). Once a second a green neon disc "MedWave"
--   grows from the pad to the circle's edge and fades (0.9 s). While the owner is outside, the edge and the core dim.
--   A "+N" BillboardGui "MedHealPop" rises over the owner's head every second it healed (HP that second; fades in 0.8 s).
--   All parts anchored, no collide / query / touch, no shadow.
-- Settings: script attribute MedStationServerEnabled (default true; false refuses drops and removes running pads).
-- Diagnostics: script MedStationServerVersion, MedRequests, MedDrops; character MedServerResult, MedCount, MedInside,
--   MedHealed, MedHealedTotal, MedEndReason.
-- v1.1 (Kepu 2026-10-30: "You need to be able to do this crap for every Dino and its mech parts ... Plug and play"):
--   BindableFunction "BuildPreview_medstation" under this script (server only) for the Lab card (LabPreviewServer 1.2,
--   PreviewBody "none": no dino needed): Invoke() builds the same pulse pad with the same build code (scale 1) and a
--   PREVIEW_RADIUS (5) stud dashed ring so it fits a card, and returns it (not left in Workspace). Switch: script attribute
--   MedStationServerPreviewEnabled (default true).
-- v1.2 (Arena squads, MDA-161, plan docs/plans/SQUADS_v1.0.md Task S4; Kepu 2026-10-31: "Also allow heals to work for both
--   of us like the patchy heal mine"): while a pad runs, every live squadmate of the owner (SquadRules 1.0 sameChar: an Arena
--   player on the same squad, or a test model with the same SquadTestId) whose HumanoidRootPart is within the pad's radius
--   (flat) heals like the owner: MedRate x its own MaxHealth per second (every TICK), capped at its MaxHealth, with the "+N"
--   pop over it once a second. Squadmate attributes: MedSquadInside (true / false while a squadmate's pad runs, nil after),
--   MedSquadHealed (HP added by squadmates' pads, total, 0.1 steps). The owner's rules are unchanged; only Med Stations
--   heal squadmates (no other heal changes). Switch: script attribute MedStationSquadHealEnabled (default true, read every
--   tick; false = 1.1, owner only).
-- v1.4 (Bots v2, MDA-471, plan docs/plans/BOTS_V2_v1.0.md T7; Kepu 2026-11-11 20:39 "the damn bots don't even use their
--   attack buttons or their mecha"): a bot entrance. Every remote handler of this script is connected through botHook(remote)
--   (handler bodies unchanged), which also files it by the remote's name. Server-only BindableFunction "BotMechaUse" (child):
--   Invoke(model, remoteName, ...the remote's own arguments...) runs every handler filed for that remote, in order, with
--   ServerStorage.DinoArcade.BotProxy.of(model) as the player (the model is its Character; PracticeBot models only).
--   Returns "ok" (the handlers ran; their results land on the model as for a player), "off", "badArg", "noHandler" or
--   "botUnsupported" (a handler errored; script attribute MedStationServerBotMechaError keeps "<remote>: <error>").
--   Switch: script attribute MedStationServerBotMechaEnabled (default true, read per call).
--   The first call for a bot also runs this script's player-join handlers (Players.PlayerAdded, filed through botJoin) with
--   the proxy and waits 0.2 s, so the bot's character is set up here like a player's (BotProxy 1.1 gives the proxy stub
--   CharacterAdded / CharacterRemoving signals).
local __botHandlers = {} -- v1.4: remote name -> handlers (see the header)
local function botHook(remote)
	return {Connect = function(_, fn)
		local list = __botHandlers[remote.Name] or {}
		__botHandlers[remote.Name] = list
		table.insert(list, fn)
		return remote.OnServerEvent:Connect(fn)
	end}
end
local __botJoiners = {} -- v1.4: player-join handlers (see the header)
local function botJoin(signal)
	return {Connect = function(_, fn)
		table.insert(__botJoiners, fn)
		return signal:Connect(fn)
	end}
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.2"
-- v1.3 (MDA-312, plan docs/plans/PACHY_MOVES_ANIM_v1.0.md Task 10; Kepu 2026-11-05 "A · Deploy Drop", red-team "Keep the
--   delays"): with script attribute MedDeployEnabled (default true, read at each press / stop; false = 1.2) an accepted press
--   stamps MedDeployAt (the pachy's lay pose, PachyMovesPose 1.0), then a capsule (light steel box with a green band,
--   1.5 x 1.2 x 1.5 x scale) pops out of the pachy's back and lands DROP_TIME (0.3 s) later on the ground BACK_DIST (4 x scale)
--   studs behind it, where the pad is built and unfolds (Base / Rim / Core grow from 10% in 0.3 s, the edge ring fades in);
--   the heal and the waves start at the landing and run MedTime as before (MedActiveUntil = press + 0.3 + MedTime). At the
--   end (any reason) the pad folds: every piece shrinks to 10%, sinks 0.5 x scale and fades in FOLD_TIME (0.4 s), then is
--   destroyed. Heal numbers / radius / cooldown unchanged. Diagnostic: MedDeployState ("drop" / "pad" / "idle").
VERSION = "1.3" -- v1.3 Deploy Drop
local DROP_TIME, BACK_DIST, FOLD_TIME = 0.3, 4, 0.4 -- v1.3
if script:GetAttribute("MedDeployEnabled") == nil then script:SetAttribute("MedDeployEnabled", true) end -- v1.3
local pendingDrop = {} -- v1.3: [char] = token while the capsule flies
local PREVIEW_RADIUS = 5 -- v1.1
local TICK = 0.25
local PAD_SIZE = 3.5
local EDGE_PIECES = 24
local GREEN = Color3.fromRGB(70, 224, 138)
local DARK = Color3.fromRGB(46, 52, 64)

script:SetAttribute("MedStationServerVersion", VERSION)
script:SetAttribute("MedRequests", 0)
script:SetAttribute("MedDrops", 0)
if script:GetAttribute("MedStationServerEnabled") == nil then script:SetAttribute("MedStationServerEnabled", true) end
local function enabled() return script:GetAttribute("MedStationServerEnabled") ~= false end

local remote = ReplicatedStorage:FindFirstChild("DinoMedRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoMedRequest"
	remote.Parent = ReplicatedStorage
end

local folder = workspace:FindFirstChild("MedStations")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "MedStations"
	folder.Parent = workspace
end

local function now() return workspace:GetServerTimeNow() end

local pads = {} -- [char] = {model, center, radius, rate, untilT, acc, secAcc, secHealed, edge, core, glow, inside}

local function part(name, size, color, material, cf, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- a flat disc (cylinder lying down) of diameter d and height h, centred at pos
local function discCF(pos) return CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) end

local function groundUnder(char, root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char, folder}
	params.RespectCanCollide = true
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), params)
	if hit then return hit.Position end
	local _, size = char:GetBoundingBox()
	return root.Position - Vector3.new(0, size.Y / 2, 0)
end

local function build(char, center, radius)
	local s = 1
	pcall(function() s = char:GetScale() end)
	local d = PAD_SIZE * s
	local m = Instance.new("Model")
	m.Name = "MedPad"
	m:SetAttribute("MedOwner", char.Name)
	m:SetAttribute("MedState", "running")
	local base = part("Base", Vector3.new(0.4 * s, d, d), DARK, Enum.Material.SmoothPlastic, discCF(center + Vector3.new(0, 0.2 * s, 0)), m)
	base.Shape = Enum.PartType.Cylinder
	local rim = part("Rim", Vector3.new(0.2 * s, d * 1.18, d * 1.18), GREEN, Enum.Material.Neon, discCF(center + Vector3.new(0, 0.1 * s, 0)), m)
	rim.Shape = Enum.PartType.Cylinder
	local core = part("Core", Vector3.new(0.1 * s, d * 0.5, d * 0.5), GREEN, Enum.Material.Neon, discCF(center + Vector3.new(0, 0.42 * s, 0)), m)
	core.Shape = Enum.PartType.Cylinder
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = GREEN
	glow.Range = math.clamp(radius, 8, 60)
	glow.Brightness = 2
	glow.Parent = core
	local edge = {}
	local arc = 2 * math.pi * radius / EDGE_PIECES
	for i = 1, EDGE_PIECES do
		local a = (i - 0.5) / EDGE_PIECES * 2 * math.pi
		local pos = center + Vector3.new(math.cos(a) * radius, 0.08, math.sin(a) * radius)
		-- tangent piece, 55% of its arc long (the rest is the gap)
		local cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
		edge[i] = part("Edge_" .. i, Vector3.new(0.5, 0.16, arc * 0.55), GREEN, Enum.Material.Neon, cf, m)
	end
	m.Parent = folder
	return m, edge, core, glow
end

local function wave(st)
	if not (st.model and st.model.Parent) then return end
	local s = st.model:FindFirstChild("Base") and st.model.Base.Size.Y or PAD_SIZE
	local w = part("MedWave", Vector3.new(0.06, s, s), GREEN, Enum.Material.Neon, discCF(st.center + Vector3.new(0, 0.12, 0)), st.model)
	w.Shape = Enum.PartType.Cylinder
	w.Transparency = 0.35
	local tw = TweenService:Create(w, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.06, st.radius * 2, st.radius * 2), Transparency = 1})
	tw:Play()
	tw.Completed:Connect(function() w:Destroy() end)
end

local function pop(char, amount)
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not head then return end
	local _, size = char:GetBoundingBox()
	local g = Instance.new("BillboardGui")
	g.Name = "MedHealPop"
	g.Size = UDim2.fromOffset(90, 34)
	g.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.35, 0)
	g.AlwaysOnTop = true
	g.Adornee = head
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 26
	l.TextColor3 = GREEN
	l.TextStrokeColor3 = Color3.fromRGB(10, 42, 20)
	l.TextStrokeTransparency = 0
	l.Text = "+" .. tostring(math.floor(amount + 0.5))
	l.Parent = g
	g.Parent = char
	TweenService:Create(g, TweenInfo.new(0.8), {StudsOffsetWorldSpace = g.StudsOffsetWorldSpace + Vector3.new(0, 3, 0)}):Play()
	TweenService:Create(l, TweenInfo.new(0.8), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	task.delay(0.85, function() g:Destroy() end)
end

-- v1.2: squadmates inside the pad heal too
if script:GetAttribute("MedStationSquadHealEnabled") == nil then script:SetAttribute("MedStationSquadHealEnabled", true) end
local squadMod
local function squadRules()
	if not squadMod then
		local arc = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return nil end
		local ok, mod = pcall(require, m)
		if not ok then return nil end
		squadMod = mod
	end
	return squadMod
end
local function squadHeal(char, st)
	st.mates = st.mates or {}
	if script:GetAttribute("MedStationSquadHealEnabled") == false then return end
	local R = squadRules()
	if not R or not R.live() then return end
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character and pl.Character ~= char then table.insert(list, pl.Character) end
	end
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("SquadTestId") ~= nil then table.insert(list, m) end
	end
	for _, m in ipairs(list) do
		if R.sameChar(char, m) then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local flat = Vector3.new(root.Position.X - st.center.X, 0, root.Position.Z - st.center.Z).Magnitude
				local inside = flat <= st.radius
				local e = st.mates[m]
				if not e then
					e = {sec = 0}
					st.mates[m] = e
				end
				if m:GetAttribute("MedSquadInside") ~= inside then m:SetAttribute("MedSquadInside", inside) end
				if inside and hum.Health < hum.MaxHealth then
					local before = hum.Health
					hum.Health = math.min(hum.MaxHealth, before + st.rate * hum.MaxHealth * TICK)
					local added = hum.Health - before
					e.sec += added
					m:SetAttribute("MedSquadHealed", math.floor(((m:GetAttribute("MedSquadHealed") or 0) + added) * 10 + 0.5) / 10)
				end
			end
		end
	end
end

local function stop(char, reason)
	local st = pads[char]
	if not st then return end
	pads[char] = nil
	for m in pairs(st.mates or {}) do -- v1.2
		if m.Parent then m:SetAttribute("MedSquadInside", nil) end
	end
	if st.model and st.deploy and script:GetAttribute("MedDeployEnabled") ~= false then -- v1.3: fold and sink
		local m, s = st.model, st.scale or 1
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(FOLD_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{Size = p.Size * Vector3.new(1, 0.1, 0.1), CFrame = p.CFrame - Vector3.new(0, 0.5 * s, 0), Transparency = 1}):Play()
			elseif p:IsA("PointLight") then p.Enabled = false end
		end
		task.delay(FOLD_TIME + 0.05, function() if m.Parent then m:Destroy() end end)
	elseif st.model then st.model:Destroy() end
	if char.Parent and st.deploy then char:SetAttribute("MedDeployState", "idle") end
	if char.Parent then
		if reason ~= "time" then char:SetAttribute("MedActiveUntil", now()) end
		char:SetAttribute("MedInside", nil)
		char:SetAttribute("MedEndReason", reason)
	end
end

local function setResult(char, r)
	char:SetAttribute("MedServerResult", r)
	char:SetAttribute("MedServerResultAt", now())
end

botHook(remote):Connect(function(player, stamp)
	script:SetAttribute("MedRequests", (script:GetAttribute("MedRequests") or 0) + 1)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		r = "badArg"
	elseif not hum or hum.Health <= 0 or not root then
		r = "dead"
	elseif not enabled() or char:GetAttribute("MedEnabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif t < (tonumber(char:GetAttribute("MedReadyAt")) or 0) then
		r = "cooldown"
	end
	if r then setResult(char, r) return end
	if pads[char] then stop(char, "replaced") end
	local radius = math.max(1, tonumber(char:GetAttribute("MedRadius")) or 12)
	local dur = math.max(0.5, tonumber(char:GetAttribute("MedTime")) or 5)
	if script:GetAttribute("MedDeployEnabled") ~= false then -- v1.3: the Deploy Drop
		local s = 1
		pcall(function() s = char:GetScale() end)
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
		local spot = root.Position - look * BACK_DIST * s
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {char, folder}
		params.RespectCanCollide = true
		local hit = workspace:Raycast(spot + Vector3.new(0, 4 * s, 0), Vector3.new(0, -70, 0), params)
		local center = hit and hit.Position or groundUnder(char, root)
		local token = {}
		pendingDrop[char] = token
		char:SetAttribute("MedReadyAt", t + (tonumber(char:GetAttribute("MedCooldown")) or 30))
		char:SetAttribute("MedActiveUntil", t + DROP_TIME + dur)
		char:SetAttribute("MedHealed", 0)
		char:SetAttribute("MedCount", (char:GetAttribute("MedCount") or 0) + 1)
		char:SetAttribute("MedDeployState", "drop")
		script:SetAttribute("MedDrops", (script:GetAttribute("MedDrops") or 0) + 1)
		setResult(char, "ok")
		char:SetAttribute("MedDeployAt", t)
		char:SetAttribute("MedDroppedAt", t) -- last
		-- the capsule: from the pachy's back to the landing spot in an arc
		local from = root.Position + Vector3.new(0, 2.5 * s, 0) - look * 1 * s
		local cap = part("MedCapsule", Vector3.new(1.5, 1.2, 1.5) * s, Color3.fromRGB(223, 230, 238), Enum.Material.SmoothPlastic, CFrame.new(from), folder)
		local band = part("Band", Vector3.new(1.55, 0.25, 1.55) * s, GREEN, Enum.Material.Neon, CFrame.new(from), cap)
		local to = center + Vector3.new(0, 0.6 * s, 0)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local u = math.min(1, (os.clock() - t0) / DROP_TIME)
			local p = from:Lerp(to, u) + Vector3.new(0, 4 * 3 * s * u * (1 - u), 0)
			local cf = CFrame.new(p) * CFrame.Angles(u * 2.5, u * 1.5, 0)
			cap.CFrame = cf
			band.CFrame = cf
			if u >= 1 then
				conn:Disconnect()
				cap:Destroy()
				if pendingDrop[char] ~= token then return end
				pendingDrop[char] = nil
				if not char.Parent or pads[char] then return end
				local m, edge, core, glow = build(char, center, radius)
				-- unfold: the disc pieces grow out of the base, the edge ring fades in
				for _, pc in ipairs(m:GetChildren()) do
					if pc:IsA("BasePart") then
						if pc.Name == "Base" or pc.Name == "Rim" or pc.Name == "Core" then
							local full = pc.Size
							pc.Size = full * Vector3.new(1, 0.1, 0.1)
							TweenService:Create(pc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = full}):Play()
						else
							local tr = pc.Transparency
							pc.Transparency = 1
							TweenService:Create(pc, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.15), {Transparency = tr}):Play()
						end
					end
				end
				local tl = now()
				pads[char] = {model = m, center = center, radius = radius, rate = tonumber(char:GetAttribute("MedRate")) or 0.10,
					untilT = tl + dur, acc = 0, secAcc = 0, secHealed = 0, waveAcc = 1, edge = edge, core = core, glow = glow,
					deploy = true, scale = s}
				char:SetAttribute("MedActiveUntil", tl + dur)
				char:SetAttribute("MedDeployState", "pad")
			end
		end)
		return
	end
	local center = groundUnder(char, root)
	local m, edge, core, glow = build(char, center, radius)
	pads[char] = {model = m, center = center, radius = radius, rate = tonumber(char:GetAttribute("MedRate")) or 0.10,
		untilT = t + dur, acc = 0, secAcc = 0, secHealed = 0, waveAcc = 1, edge = edge, core = core, glow = glow}
	char:SetAttribute("MedReadyAt", t + (tonumber(char:GetAttribute("MedCooldown")) or 30))
	char:SetAttribute("MedActiveUntil", t + dur)
	char:SetAttribute("MedHealed", 0)
	char:SetAttribute("MedCount", (char:GetAttribute("MedCount") or 0) + 1)
	script:SetAttribute("MedDrops", (script:GetAttribute("MedDrops") or 0) + 1)
	setResult(char, "ok")
	char:SetAttribute("MedDroppedAt", t) -- last
end)

RunService.Heartbeat:Connect(function(dt)
	local t = now()
	for char, st in pairs(pads) do
		local hum = char.Parent and char:FindFirstChildOfClass("Humanoid")
		local root = char.Parent and char:FindFirstChild("HumanoidRootPart")
		if not char.Parent or not hum or not root then
			stop(char, "removed")
		elseif hum.Health <= 0 then
			stop(char, "dead")
		elseif not enabled() or char:GetAttribute("MedEnabled") ~= true then
			stop(char, "disabled")
		elseif t >= st.untilT then
			stop(char, "time")
		else
			st.waveAcc += dt
			if st.waveAcc >= 1 then
				st.waveAcc -= 1
				wave(st)
			end
			st.acc += dt
			while st.acc >= TICK do
				st.acc -= TICK
				local flat = Vector3.new(root.Position.X - st.center.X, 0, root.Position.Z - st.center.Z).Magnitude
				local inside = flat <= st.radius
				if inside ~= st.inside then
					st.inside = inside
					char:SetAttribute("MedInside", inside)
					for _, e in ipairs(st.edge) do e.Transparency = inside and 0 or 0.6 end
					st.core.Transparency = inside and 0 or 0.5
					st.glow.Enabled = inside
				end
				if inside and hum.Health < hum.MaxHealth then
					local before = hum.Health
					hum.Health = math.min(hum.MaxHealth, before + st.rate * hum.MaxHealth * TICK)
					local added = hum.Health - before
					st.secHealed += added
					char:SetAttribute("MedHealed", math.floor(((char:GetAttribute("MedHealed") or 0) + added) * 10 + 0.5) / 10)
					char:SetAttribute("MedHealedTotal", math.floor(((char:GetAttribute("MedHealedTotal") or 0) + added) * 10 + 0.5) / 10)
				end
				squadHeal(char, st) -- v1.2
				st.secAcc += TICK
				if st.secAcc >= 1 - 1e-6 then
					st.secAcc = 0
					if st.secHealed >= 0.5 then pop(char, st.secHealed) end
					st.secHealed = 0
					for m, e in pairs(st.mates or {}) do -- v1.2: squadmates' pops
						if e.sec >= 0.5 and m.Parent then pop(m, e.sec) end
						e.sec = 0
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then stop(player.Character, "removed") end
end)

-- v1.1: the Lab card model (plug and play: LabPreviewServer 1.2 finds BuildPreview_<pathId>)
if script:GetAttribute("MedStationServerPreviewEnabled") == nil then script:SetAttribute("MedStationServerPreviewEnabled", true) end
do
	local fn = Instance.new("BindableFunction")
	fn.Name = "BuildPreview_medstation"
	fn:SetAttribute("PreviewBody", "none")
	fn.OnInvoke = function()
		if script:GetAttribute("MedStationServerPreviewEnabled") == false then return nil end
		local stand = Instance.new("Model") -- stands in for the owner (scale 1, a name)
		stand.Name = "LabPreview"
		local m = build(stand, Vector3.zero, PREVIEW_RADIUS)
		m.Parent = nil
		stand:Destroy()
		return m
	end
	fn.Parent = script
end

-- v1.4: the bot entrance (see the header)
if script:GetAttribute("MedStationServerBotMechaEnabled") == nil then script:SetAttribute("MedStationServerBotMechaEnabled", true) end
do
	local proxyModule = game:GetService("ServerStorage"):WaitForChild("DinoArcade"):FindFirstChild("BotProxy")
	local BotProxy = proxyModule and require(proxyModule)
	local fn = script:FindFirstChild("BotMechaUse") or Instance.new("BindableFunction")
	fn.Name = "BotMechaUse"
	local joined = setmetatable({}, {__mode = "k"})
	fn.OnInvoke = function(model, remoteName, ...)
		if script:GetAttribute("MedStationServerBotMechaEnabled") == false then return "off" end
		if not BotProxy or typeof(model) ~= "Instance" or model:GetAttribute("PracticeBot") ~= true or not model.Parent then return "badArg" end
		local list = __botHandlers[remoteName]
		if not list then return "noHandler" end
		local proxy = BotProxy.of(model)
		if not joined[model] then
			joined[model] = true
			for _, j in ipairs(__botJoiners) do pcall(j, proxy) end
			task.wait(0.2)
		end
		for _, h in ipairs(list) do
			local ok, err = pcall(h, proxy, ...)
			if not ok then
				script:SetAttribute("MedStationServerBotMechaError", tostring(remoteName) .. ": " .. tostring(err))
				return "botUnsupported"
			end
		end
		return "ok"
	end
	fn.Parent = script
end
script:SetAttribute("MedStationServerVersion", "1.4") -- v1.4 bot entrance
