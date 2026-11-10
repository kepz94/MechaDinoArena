-- TrooSlotFX v1.0 (Mecha Dino Arena) — the Troodon slot parts' effects on every client (StarterPlayerScripts). Plan
-- docs/plans/TROODON_SLOTPARTS_v1.0.md T4 (MDA-381); looks + timings = docs/mockups/troodon_slotparts_v0.1.html (Kepu
-- 2026-11-10 picks); server stamps = TrooSlotServer 1.0. Everything lives in a local Workspace.TrooSlotFX folder (Neon, no
-- collision, no queries, no shadows). Each move reads wind-up -> action -> result -> recovery; no landing FX on the troodon.
-- * Throws (Bloom Burst / Shield Dome / Sentry Pod): at <X>At + TrooSlot_throwWindup (0.34, the pose's release) the carried
--   piece leaves the hand (its on-body OPart_<id> "carry" pieces go see-through from the press until they regrow) and flies a
--   pod arc (TrooFX's: peak 9 x scale / 2) from <X>From to <X>To over <X>Flight.
--   Bloom Burst: TrooBurstLandAt -> a green flash, two flat rings out to TrooPartBurstRadius, green sparks; the bud regrows on
--   the sling 0.8 s later. Boosted dinos (TrooBoostUntil ahead) wear a green Highlight; cut ones (TrooHealCutUntil ahead) a
--   purple Highlight + a "NO HEAL" tag.
--   Shield Dome: the landing ring (blue); the dome is the server's ForceField ball; every blocked hit on it (WallBlockedAt,
--   SapWallBlock 1.3) flashes a blue ripple + sparks at WallBlockedPos; the canister regrows when the dome ends.
--   Sentry Pod: the turret (server) fires; each TrooSentryShotAt on it -> a muzzle flash + an amber bolt over the shot's flight
--   + a hit flash; TrooSentryEndAt -> teal sparks; the folded turret regrows on the saddle.
-- * Sleep Dart: TrooSleepFireAt -> a violet muzzle flash at the head and a violet dart with a trail From -> To over Flight;
--   TrooSleepSplitAt -> a second dart from the target to the next one. Sleeping dinos (TrooSleepUntil ahead) wear a violet
--   Highlight + a "Zz" tag with the seconds left; TrooSleepWokeAt -> a white flash.
-- * Bloom Tank (star): TrooBloomPulseAt -> a teal-green ring out to TrooBloomPulseRadius + a flash at TrooBloomPulseCenter.
-- Switches (script attributes, read at each event): TrooSlotFXEnabled, TrooSlotFX_<id>Enabled (obloom / oburst / odome /
--   osleep / osentry). Diagnostic: script TrooSlotFXLast ("<id>:<phase>").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
script:SetAttribute("TrooSlotFXVersion", VERSION)
for _, k in ipairs({"TrooSlotFXEnabled", "TrooSlotFX_obloomEnabled", "TrooSlotFX_oburstEnabled", "TrooSlotFX_odomeEnabled",
	"TrooSlotFX_osleepEnabled", "TrooSlotFX_osentryEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local THROW_WINDUP = 0.34
local GREEN, BLUE, VIOLET, AMBER, TEAL = Color3.fromHex("8dffb6"), Color3.fromHex("6cc4ff"), Color3.fromHex("b88cff"),
	Color3.fromHex("ffc35a"), Color3.fromHex("2fe6c8")
local function on(id) return script:GetAttribute("TrooSlotFXEnabled") ~= false and script:GetAttribute("TrooSlotFX_" .. id .. "Enabled") ~= false end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k) local v = m:GetAttribute(k); return typeof(v) == "number" and v or nil end
local function diag(id, ph) script:SetAttribute("TrooSlotFXLast", id .. ":" .. ph) end
local function scaleOf(m) local ok, v = pcall(function() return m:GetScale() end); return ok and v or 1 end

local fx = workspace:FindFirstChild("TrooSlotFX")
if not fx then fx = Instance.new("Folder"); fx.Name = "TrooSlotFX"; fx.Parent = workspace end
local function part(shape, size, color, cf, transp)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transp or 0
	if shape then p.Shape = shape end
	p.CFrame = cf
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
local function flash(pos, size, color, life)
	local p = part(Enum.PartType.Ball, Vector3.one * size * 0.3, color, CFrame.new(pos), 0.1)
	animate(life or 0.3, function(u) p.Size = Vector3.one * size * (0.3 + 0.7 * u); p.Transparency = 0.1 + 0.9 * u end, function() p:Destroy() end)
end
local function ring(center, R, color, life, thick)
	local p = part(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), color, CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.2)
	animate(life or 0.5, function(u)
		local r = math.max(0.5, R * (0.15 + 0.85 * (1 - (1 - u) ^ 2)))
		p.Size = Vector3.new(thick or 0.25, r * 2, r * 2)
		p.Transparency = 0.35 + 0.65 * u
	end, function() p:Destroy() end)
end
local function sparks(pos, color, n, speed)
	local a = Instance.new("Attachment")
	local holder = part(nil, Vector3.one * 0.2, color, CFrame.new(pos), 1)
	a.Parent = holder
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new((speed or 20) * 0.5, speed or 20)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = a
	e:Emit(n or 16)
	Debris:AddItem(holder, 1)
end
local function arc(from, to, flight, peak, color, size, trailColor, done)
	local p = part(Enum.PartType.Ball, Vector3.one * size, color, CFrame.new(from), 0)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, size * 0.3, 0), Vector3.new(0, -size * 0.3, 0)
	a0.Parent, a1.Parent = p, p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(trailColor or color)
	tr.LightEmission = 1
	tr.Lifetime = 0.25
	tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	tr.Parent = p
	animate(flight, function(u)
		local pos = from:Lerp(to, u) + Vector3.new(0, 4 * peak * u * (1 - u), 0)
		p.CFrame = CFrame.new(pos)
	end, function() p:Destroy(); if done then done() end end)
end
-- the on-body carried pieces of a part (TrooPartsServer 1.2 OPart_<id>, role "carry"): see-through while away
local function carryHide(char, id, hidden)
	local m = char:FindFirstChild("OPart_" .. id)
	if not m then return end
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("OPartRole") == "carry" then p.LocalTransparencyModifier = hidden and 1 or 0 end
	end
end
local function regrow(char, id, at)
	task.delay(math.max(0, at - now()), function()
		if not char.Parent then return end
		local m = char:FindFirstChild("OPart_" .. id)
		if not m then return end
		animate(0.4, function(u)
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") and p:GetAttribute("OPartRole") == "carry" then p.LocalTransparencyModifier = 1 - u end
			end
		end)
	end)
end

-- throws ------------------------------------------------------------------------------------------------------------------------
local function throwFx(char, id, prefix, color, size)
	local at, from, to, flight = num(char, prefix .. "At"), char:GetAttribute(prefix .. "From"), char:GetAttribute(prefix .. "To"), num(char, prefix .. "Flight")
	if not (at and typeof(from) == "Vector3" and typeof(to) == "Vector3" and flight) or now() - at > 2 then return end
	local s = scaleOf(char)
	diag(id, "windup")
	carryHide(char, id, true)
	task.delay(math.max(0, at + THROW_WINDUP - now()), function()
		diag(id, "action")
		arc(from, to, flight, 9 * s / 2, color, size * s, color, function()
			diag(id, "result")
			ring(to, 4 * s, color, 0.35, 0.2)
		end)
	end)
end

-- highlights: boost / cut / sleep -----------------------------------------------------------------------------------------------
local marks = {}
local function tagGui(m, text, color)
	local root = m:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local b = Instance.new("BillboardGui")
	b.Name = "TrooSlotTag"
	b.Size = UDim2.fromOffset(110, 34)
	b.StudsOffsetWorldSpace = Vector3.new(0, 6 * scaleOf(m), 0)
	b.AlwaysOnTop = true
	b.Adornee = root
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.Parent = b
	b.Parent = fx
	return b, l
end
local function setMark(m, kind, want, color, text)
	marks[m] = marks[m] or {}
	local mk = marks[m][kind]
	if want and not mk then
		local h = Instance.new("Highlight")
		h.FillColor, h.OutlineColor = color, color
		h.FillTransparency, h.OutlineTransparency = 0.7, 0.2
		h.Adornee = m
		h.Parent = fx
		local g, l = nil, nil
		if text then g, l = tagGui(m, text, color) end
		mk = {h = h, g = g, l = l}
		marks[m][kind] = mk
	elseif not want and mk then
		mk.h:Destroy()
		if mk.g then mk.g:Destroy() end
		marks[m][kind] = nil
	end
	return mk
end
local function watchedModels()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	if bots then for _, b in ipairs(bots:GetChildren()) do table.insert(list, b) end end
	return list
end
task.spawn(function()
	while true do
		local t = now()
		local seen = {}
		for _, m in ipairs(watchedModels()) do
			seen[m] = true
			setMark(m, "boost", on("oburst") and (num(m, "TrooBoostUntil") or 0) > t, GREEN, nil)
			setMark(m, "cut", on("oburst") and (num(m, "TrooHealCutUntil") or 0) > t, VIOLET, "NO HEAL")
			local su = num(m, "TrooSleepUntil") or 0
			local mk = setMark(m, "sleep", on("osleep") and su > t, VIOLET, "Zz")
			if mk and mk.l then mk.l.Text = ("Zz %.1f"):format(math.max(0, su - t)) end
		end
		for m, kinds in pairs(marks) do
			if not seen[m] or not m.Parent then
				for k in pairs(kinds) do setMark(m, k, false) end
				marks[m] = nil
			end
		end
		task.wait(0.1)
	end
end)

-- per character --------------------------------------------------------------------------------------------------------------------
local function watchChar(char)
	char:GetAttributeChangedSignal("TrooBurstAt"):Connect(function()
		if on("oburst") then throwFx(char, "oburst", "TrooBurst", GREEN, 0.8) end
	end)
	char:GetAttributeChangedSignal("TrooBurstLandAt"):Connect(function()
		if not on("oburst") then return end
		local to = char:GetAttribute("TrooBurstTo")
		if typeof(to) ~= "Vector3" then return end
		local R = num(char, "TrooPartBurstRadius") or 20
		local s = scaleOf(char)
		diag("oburst", "burst")
		flash(to + Vector3.new(0, 2 * s, 0), 8 * s, GREEN, 0.35)
		ring(to, R, GREEN, 0.55, 0.3)
		task.delay(0.12, function() ring(to, R * 0.75, Color3.fromHex("d6ffe6"), 0.5, 0.2) end)
		sparks(to + Vector3.new(0, 1.5 * s, 0), GREEN, 26, 26)
		regrow(char, "oburst", now() + 0.8)
	end)
	char:GetAttributeChangedSignal("TrooDomeAt"):Connect(function()
		if not on("odome") then return end
		throwFx(char, "odome", "TrooDome", BLUE, 0.9)
	end)
	char:GetAttributeChangedSignal("TrooDomeUntil"):Connect(function()
		local u = num(char, "TrooDomeUntil")
		if u and u > now() then regrow(char, "odome", u) end
	end)
	char:GetAttributeChangedSignal("TrooSentryAt"):Connect(function()
		if on("osentry") then throwFx(char, "osentry", "TrooSentry", AMBER, 1) end
	end)
	char:GetAttributeChangedSignal("TrooSentryUntil"):Connect(function()
		local u = num(char, "TrooSentryUntil")
		if u then regrow(char, "osentry", u + 0.4) end
	end)
	char:GetAttributeChangedSignal("TrooSleepFireAt"):Connect(function()
		if not on("osleep") then return end
		local from, to, flight = char:GetAttribute("TrooSleepFrom"), char:GetAttribute("TrooSleepTo"), num(char, "TrooSleepFlight")
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not flight then return end
		local s = scaleOf(char)
		diag("osleep", "action")
		flash(from, 3 * s, VIOLET, 0.2)
		arc(from, to, flight, 0, VIOLET, 0.45 * s, VIOLET, function()
			diag("osleep", "result")
			flash(to, 5 * s, Color3.fromHex("e2ccff"), 0.3)
			sparks(to, VIOLET, 12, 14)
		end)
	end)
	char:GetAttributeChangedSignal("TrooSleepSplitAt"):Connect(function()
		if not on("osleep") then return end
		local from, to = char:GetAttribute("TrooSleepSplitFrom"), char:GetAttribute("TrooSleepSplitTo")
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then return end
		arc(from, to, 0.2, 0, VIOLET, 0.4 * scaleOf(char), VIOLET, function() flash(to, 4 * scaleOf(char), Color3.fromHex("e2ccff"), 0.3) end)
	end)
	char:GetAttributeChangedSignal("TrooBloomPulseAt"):Connect(function()
		if not on("obloom") then return end
		local c, R = char:GetAttribute("TrooBloomPulseCenter"), num(char, "TrooBloomPulseRadius")
		if typeof(c) ~= "Vector3" or not R then return end
		diag("obloom", "pulse")
		ring(c, R, TEAL, 0.6, 0.35)
		ring(c, R * 0.6, GREEN, 0.5, 0.25)
		flash(c + Vector3.new(0, 1, 0), 6 * scaleOf(char), GREEN, 0.3)
	end)
end
local function watchWoken(m)
	m:GetAttributeChangedSignal("TrooSleepWokeAt"):Connect(function()
		if not on("osleep") then return end
		local r = m:FindFirstChild("HumanoidRootPart")
		if r then flash(r.Position, 5 * scaleOf(m), Color3.new(1, 1, 1), 0.25) end
	end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(function(c) watchChar(c); watchWoken(c) end)
	if pl.Character then watchChar(pl.Character); watchWoken(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 30)
	local bots = isl and isl:WaitForChild("Bots", 30)
	if not bots then return end
	bots.ChildAdded:Connect(watchWoken)
	for _, b in ipairs(bots:GetChildren()) do watchWoken(b) end
end)

-- domes: blocked hits ------------------------------------------------------------------------------------------------------------------
local function watchDome(p)
	if not p:IsA("BasePart") then return end
	p:GetAttributeChangedSignal("WallBlockedAt"):Connect(function()
		if not on("odome") then return end
		local pos = p:GetAttribute("WallBlockedPos")
		if typeof(pos) ~= "Vector3" then return end
		diag("odome", "blocked")
		flash(pos, 4, Color3.fromHex("cfe8ff"), 0.3)
		sparks(pos, BLUE, 10, 16)
	end)
	p:GetAttributeChangedSignal("TrooDomeUntil"):Connect(function()
		if (p:GetAttribute("TrooDomeUntil") or 0) == 0 and on("odome") then sparks(p.Position + Vector3.new(0, 2, 0), BLUE, 20, 22) end
	end)
end
-- sentries: shots ------------------------------------------------------------------------------------------------------------------
local function watchSentry(m)
	if not m:IsA("Model") then return end
	m:GetAttributeChangedSignal("TrooSentryShotAt"):Connect(function()
		if not on("osentry") then return end
		local from, to, flight = m:GetAttribute("TrooSentryShotFrom"), m:GetAttribute("TrooSentryShotTo"), num(m, "TrooSentryShotFlight")
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not flight then return end
		diag("osentry", "shot")
		flash(from, 2.5, Color3.fromHex("ffe2a0"), 0.15)
		arc(from, to, flight, 0.3, AMBER, 0.7, AMBER, function() flash(to, 3, AMBER, 0.2) end)
	end)
	m:GetAttributeChangedSignal("TrooSentryEndAt"):Connect(function()
		if not on("osentry") then return end
		local pv = m:GetPivot().Position
		sparks(pv + Vector3.new(0, 2, 0), TEAL, 24, 18)
		diag("osentry", "end")
	end)
end
task.spawn(function()
	local function hook(name, fn)
		local f = workspace:FindFirstChild(name) or workspace:WaitForChild(name, 1e6)
		f.ChildAdded:Connect(fn)
		for _, c in ipairs(f:GetChildren()) do fn(c) end
	end
	task.spawn(hook, "TrooDomes", watchDome)
	task.spawn(hook, "TrooSentries", watchSentry)
end)
