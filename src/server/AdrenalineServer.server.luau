-- AdrenalineServer v1.6 (Mecha Dino Arena) — Adrenaline Injector, a raptor button part (raptor parts batch 1): heal over
-- a few seconds and run faster while it lasts. MDA-62, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 5, mockup
-- docs/mockups/raptor_parts_b1_options.html option A "Neck injector" (Kepu 2026-10-29).
-- Settings come from the character (SkillEffects 1.6): AdrenalineEnabled (bought AND slotted), AdrenalineHeal (share of
--   MaxHealth healed over AdrenalineTime), AdrenalineTime (3), AdrenalineSpeedMul (1.3; SprintTest 1.6 applies it while
--   AdrenalineUntil > now), AdrenalineCooldown (20; 14.8 from III), AdrenalineStunClear (star).
-- Client -> server: ReplicatedStorage.DinoAdrenalineRequest:FireServer(clientServerTime). Checks, first failing wins:
--   "badArg"   stamp not a number            "dead"     no Humanoid / health <= 0
--   "disabled" AdrenalineServerEnabled false or AdrenalineEnabled ~= true
--   "stunned"  StunnedUntil > now and AdrenalineStunClear ~= true
--   "latched"  PounceLatched == true          "active"   AdrenalineUntil > now
--   "cooldown" now < AdrenalineReadyAt        "ok"
--   ok: StunnedUntil > now with StunClear -> StunnedUntil = now (AdrenalineStunCleared + 1); AdrenalineStartedAt = now,
--   AdrenalineUntil = now + time, AdrenalineReadyAt = AdrenalineUntil + cooldown (the cooldown counts from the end, like
--   Cloak); AdrenalineCount + 1. Always: AdrenalineServerResult.
-- Heal: every Heartbeat while AdrenalineUntil > now and health > 0: + heal x MaxHealth x dt / time, capped at MaxHealth
--   (the last step is trimmed so the total is exactly heal x MaxHealth). AdrenalineHealed = the total so far (0.1 steps).
-- Ends early on death or AdrenalineEnabled turning false: AdrenalineUntil = now, AdrenalineReadyAt = now + cooldown.
--   AdrenalineEndReason "time" / "dead" / "disabled".
-- Look: Model "Mecha_Adrenaline" under the character while AdrenalineEnabled is true: on the right side of the neck (the
--   Neck segment's box in its Root's own frame, so the pose at build time doesn't matter) a dark canister "Canister" with green glass "Glass" and a
--   grey plunger "Plunger" on top (Weld "PlungerHinge", attribute BaseC0). Welded to the Neck segment's Root. Massless,
--   no collide / query / touch, no shadow. On each use: the plunger slides down into the canister (0.25 s) and back up
--   at the end; a green Highlight "AdrenalinePulse" fades from FillTransparency 0.35 to 1 over 0.6 s and is destroyed;
--   green Trails "AdrenalineTrail" on both feet are on until AdrenalineUntil.
-- v1.1 (Kepu 2026-10-29: "the ability themselves don't seem obvious enough" -> mockup
--   docs/mockups/raptor_parts_b1_looks.html, picked A "Back tanks"): script attribute AdrenalineLookStyle (default
--   "tanks"; "neck" = the 1.0 neck canister). Tanks: Model "Mecha_Adrenaline" on top of the front of the Torso segment
--   (the shoulders), welded to Torso.Root: "Tank_k" (dark frame) with "Glass_k" (green neon) inside; how many / how big
--   by the player's SkillPath_adrenaline: I 1, II 1 bigger (x1.25), III 2, star 3 with neon caps "TankCap_k". A dark
--   "Tube" runs from the tanks to the front top of the torso (the neck). Star: a "TankRing" of 6 neon blocks on a hub
--   "TankRingHub" (Weld "TankRingHinge") around the tanks' base, spinning (TANK_RING_SPEED deg/s). Rebuilt
--   when that step changes. While healing, a "+N" BillboardGui "AdrenalineHealPop" rises over the head every 0.5 s
--   (the HP healed since the last one; fades out in 0.8 s). Diagnostics: AdrenalineLookStep, AdrenalineTanks.
--   While the boost runs: a Highlight "AdrenalineGlow" (green fill pulsing 0.35 <-> 0.7, outline on) for the whole boost, destroyed at the end; the glass drains (Transparency 0 -> 0.75 over the boost) and refills
--   over the cooldown; foot trails wider (dino height x 0.05 each side) and longer (0.5 s). The 0.6 s start flash
--   (AdrenalinePulse) stays. AdrenalineLook "tanks" / "on" (neck) / "none" / "noTorso" / "noNeck".
-- v1.2 (Kepu 2026-10-29): the star ring is removed ("Remove it"; TankRing / TankRingHub / spin gone). The tanks now
--   show their charge as a fluid level ("when adrenaline is used I want the canisters to visibly empty out and when
--   it's refilling to visibly refill so a player can look at that as a cue"): each "Glass_k" (green neon fluid) is
--   joined to its tank by a Weld "FluidHinge" and its height goes from full (tank height x 0.8) down to FLUID_MIN
--   (bottom of the tank) over the boost, then back up over the cooldown (linear; the bottom stays put, the top moves).
--   The 1.1 glass transparency fade is replaced by this. A rebuild (step change, style flip) starts the fluid at the
--   level the timers give. Diagnostics: character AdrenalineTankState ("full" / "draining" / "refilling"),
--   AdrenalineTankFullAt (server time it will be full again).
-- v1.3 (raptor parts batch 2, MDA-74, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 6): a new PartsJammedAt on the
--   character (a star Raptor Screech hit, ScreechServer 1.0) ends a running boost at once with AdrenalineEndReason "jammed" (the
--   cooldown then counts from now, like any early end).
-- Settings: script attribute AdrenalineServerEnabled (default true).
-- Diagnostics: script AdrenalineServerVersion, AdrenalineRequests; character AdrenalineServerResult, AdrenalineCount,
--   AdrenalineHealed, AdrenalineEndReason, AdrenalineStunCleared, AdrenalineLook ("none" / "on" / "noNeck").
-- v1.4 (Lab, MDA-96, plan docs/plans/LAB_v1.0.md Task 1; Kepu 2026-10-29: "Add a preview builder"): BindableFunction
--   "BuildPreview" under this script (server only). Invoke(model) builds this part on the given dino model (a Lab
--   mannequin, not a player) with the same build code (AdrenalineEnabled = true, then build(model)) and returns its Model "Mecha_Adrenaline" (nil when
--   nothing was built). LabPreviewServer 1.0 turns it into the Lab card model. The live part is unchanged. Switch: script
--   attribute AdrenalineServerPreviewEnabled (default true; false -> returns nil).
-- v1.5 (Herrera parts pass 3, MDA-167, plan docs/plans/HERRERA_PARTS_v1.0.md Part 11; Kepu 2026-10-31 "an adrenaline that
--   works like raptors", star "refills slash charges", look A "Back Tanks"): the same request / heal / run / cooldown rules
--   serve the Herrera's "hadren" (SkillEffects 1.30 writes the Adrenaline* attributes for it). On a character with Species
--   "Herrera" no Mecha_Adrenaline model is built (HerreraPartsServer 1.3 builds the Herrera's Back Tanks; AdrenalineLook
--   "herrera"); the green glow, the start pulse and the "+N" pops are unchanged. Switch: script attribute
--   AdrenalineHerreraLookOff (default true, read at each build; false = the raptor look on a Herrera too). Star: on an "ok"
--   request with the character's AdrenalineSlashRefill = true, the character gets SlashRefillAllAt = now (SlashServer 1.7
--   refills every slash charge). Switch: AdrenalineSlashRefillEnabled (default true, read at each request).
-- v1.6 (plan docs/plans/HERRERA_MOVES_ANIM_v1.0.md Task 2, MDA-292; Kepu 2026-11-05 picked "A · Jab & Sprint", red-team
--   "Herrera only"): on a character with Species "Herrera", an "ok" request first stamps AdrenalineWindupTime (script
--   AdrenalineHerreraWindup, 0.45 s), AdrenalineWindupUntil, AdrenalineWindupResult "winding", AdrenalineWindupAt (last;
--   HerreraMovesPose 1.2 plays the jab, HerreraPartsAnim 1.1 pushes the plunger), waits it, then runs the 1.5 "ok" body
--   with the time of that moment (stun re-checked then: the star still clears it). Cancelled ("cancelled") when the
--   character left workspace, died or lost its state in the wait; else "fired". A request while AdrenalineWindupUntil >
--   now -> "windup" (checked before "active"). Every other species: 1.5 exactly. Switch: script attribute
--   AdrenalineHerreraWindupEnabled (default true, read at each request).
-- v1.7 (Bots v2, MDA-471, plan docs/plans/BOTS_V2_v1.0.md T7; Kepu 2026-11-11 20:39 "the damn bots don't even use their
--   attack buttons or their mecha"): a bot entrance. Every remote handler of this script is connected through botHook(remote)
--   (handler bodies unchanged), which also files it by the remote's name. Server-only BindableFunction "BotMechaUse" (child):
--   Invoke(model, remoteName, ...the remote's own arguments...) runs every handler filed for that remote, in order, with
--   ServerStorage.DinoArcade.BotProxy.of(model) as the player (the model is its Character; PracticeBot models only).
--   Returns "ok" (the handlers ran; their results land on the model as for a player), "off", "badArg", "noHandler" or
--   "botUnsupported" (a handler errored; script attribute AdrenalineServerBotMechaError keeps "<remote>: <error>").
--   Switch: script attribute AdrenalineServerBotMechaEnabled (default true, read per call).
local __botHandlers = {} -- v1.7: remote name -> handlers (see the header)
local function botHook(remote)
	return {Connect = function(_, fn)
		local list = __botHandlers[remote.Name] or {}
		__botHandlers[remote.Name] = list
		table.insert(list, fn)
		return remote.OnServerEvent:Connect(fn)
	end}
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.5"
VERSION = "1.6" -- v1.6 Herrera jab wind-up
local GREEN, DARK, GREY = Color3.fromRGB(95, 209, 106), Color3.fromRGB(44, 52, 64), Color3.fromRGB(154, 166, 182)

script:SetAttribute("AdrenalineServerVersion", VERSION)
if script:GetAttribute("AdrenalineServerEnabled") == nil then script:SetAttribute("AdrenalineServerEnabled", true) end
script:SetAttribute("AdrenalineRequests", 0)
if script:GetAttribute("AdrenalineLookStyle") == nil then script:SetAttribute("AdrenalineLookStyle", "tanks") end -- v1.1
local function on() return script:GetAttribute("AdrenalineServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end
-- v1.6
if script:GetAttribute("AdrenalineHerreraWindupEnabled") == nil then script:SetAttribute("AdrenalineHerreraWindupEnabled", true) end
if script:GetAttribute("AdrenalineHerreraWindup") == nil then script:SetAttribute("AdrenalineHerreraWindup", 0.45) end
local function herreraWindup(char)
	return script:GetAttribute("AdrenalineHerreraWindupEnabled") ~= false and char:GetAttribute("Species") == "Herrera"
end

local remote = ReplicatedStorage:FindFirstChild("DinoAdrenalineRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoAdrenalineRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum, active, healed, target}
local FLUID_MIN = 0.04 -- v1.2: fluid height share when empty (a thin line at the bottom)
local fluidToken = setmetatable({}, {__mode = "k"}) -- v1.2: newest fluid change per character
local POP_EVERY = 0.5 -- v1.1: heal pop interval (s)

local function part(name, size, cf, color, parent, mount)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Parent = parent
	if mount then
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = mount, p
		w.Parent = p
	end
	return p
end

-- the segment's box in its Root's own frame (so the pose at build time doesn't matter)
local function rootBox(seg, root)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
				local q = root.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz))
				lo, hi = lo:Min(q), hi:Max(q)
			end end end
		end
	end
	if lo.X == math.huge then return nil end
	return lo, hi
end
-- the Root-space axis (unit +-X / Y / Z) nearest to a world direction
local function axisOf(root, dir)
	local v = root.CFrame:VectorToObjectSpace(dir)
	local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
	if a.X >= a.Y and a.X >= a.Z then return Vector3.new(v.X >= 0 and 1 or -1, 0, 0) end
	if a.Y >= a.Z then return Vector3.new(0, v.Y >= 0 and 1 or -1, 0) end
	return Vector3.new(0, 0, v.Z >= 0 and 1 or -1)
end
-- distance from the box centre to its face along a unit axis
local function extent(lo, hi, axis)
	local h = (hi - lo) / 2
	return math.abs(axis.X) * h.X + math.abs(axis.Y) * h.Y + math.abs(axis.Z) * h.Z
end
-- Root-space right / up / back axes that follow the body's right / up (z = x cross y = back)
local function bodyAxes(root, hrp)
	local x = axisOf(root, hrp.CFrame.RightVector)
	local y = axisOf(root, hrp.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, hrp.CFrame.LookVector):Cross(x) end
	return x, y, x:Cross(y)
end

-- v1.1: the player's Adrenaline step (0..4; the test layer's star counts)
local function stepOf(char)
	local pl = Players:GetPlayerFromCharacter(char)
	return pl and tonumber(pl:GetAttribute("SkillPath_adrenaline")) or 0
end

-- v1.2: tank fluid level (0 empty .. 1 full); from = start level (nil = where it is), to = end level over time s
local function fluid(char, from, to, time)
	local m = char:FindFirstChild("Mecha_Adrenaline")
	if not m then return end
	local function shape(H, L)
		L = math.clamp(L, FLUID_MIN, 1)
		return H * L, CFrame.new(0, -H / 2 + H * L / 2, 0)
	end
	for _, g in ipairs(m:GetChildren()) do
		local w = g:IsA("BasePart") and g.Name:sub(1, 6) == "Glass_" and g:FindFirstChild("FluidHinge")
		local H = w and tonumber(g:GetAttribute("FullHeight"))
		if H then
			if from then
				local h, c0 = shape(H, from)
				g.Size = Vector3.new(g.Size.X, h, g.Size.Z)
				w.C0 = c0
			end
			local h, c0 = shape(H, to)
			local info = TweenInfo.new(math.max(0.05, time), Enum.EasingStyle.Linear)
			TweenService:Create(g, info, {Size = Vector3.new(g.Size.X, h, g.Size.Z)}):Play()
			TweenService:Create(w, info, {C0 = c0}):Play()
		end
	end
	local state = to >= 1 and (from == 1 and "full" or "refilling") or "draining"
	char:SetAttribute("AdrenalineTankState", state)
	char:SetAttribute("AdrenalineTankFullAt", to >= 1 and now() + time or 0)
	local token = {}
	fluidToken[char] = token
	if state == "refilling" then
		task.delay(time, function()
			if fluidToken[char] == token and char.Parent then char:SetAttribute("AdrenalineTankState", "full") end
		end)
	end
end
local function glow(char, on_)
	local old = char:FindFirstChild("AdrenalineGlow")
	if old then old:Destroy() end -- destroyed, not disabled
	if not on_ then return end
	local hl = Instance.new("Highlight")
	hl.Name = "AdrenalineGlow"
	hl.FillColor, hl.OutlineColor = GREEN, GREEN
	hl.FillTransparency, hl.OutlineTransparency = 0.7, 0.1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	TweenService:Create(hl, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {FillTransparency = 0.35}):Play()
end

-- v1.1: "+N" rising over the head
local function pop(char, amount)
	local head = char:FindFirstChild("HumanoidRootPart")
	if not head or amount < 0.5 then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "AdrenalineHealPop"
	bb.Size = UDim2.fromOffset(90, 36)
	bb.StudsOffsetWorldSpace = Vector3.new(0, char:GetExtentsSize().Y * 0.6, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "+" .. math.floor(amount + 0.5)
	tl.TextColor3 = GREEN
	tl.TextStrokeTransparency = 0.2
	tl.Font = Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.Parent = bb
	bb.Adornee = head
	bb.Parent = head
	TweenService:Create(bb, TweenInfo.new(0.8), {StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, 3, 0)}):Play()
	TweenService:Create(tl, TweenInfo.new(0.8), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	task.delay(0.85, function() bb:Destroy() end)
end

local function trails(char, enabled)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Trail") and d.Name == "AdrenalineTrail" then d.Enabled = enabled end
	end
end

local function build(char)
	local old = char:FindFirstChild("Mecha_Adrenaline")
	if old then old:Destroy() end
	for _, d in ipairs(char:GetDescendants()) do
		if d.Name == "AdrenalineTrail" or d.Name == "AdrenalineTrailA" or d.Name == "AdrenalineTrailB" then d:Destroy() end
	end
	if not on() or char:GetAttribute("AdrenalineEnabled") ~= true then
		char:SetAttribute("AdrenalineLook", "none")
		return
	end
	if char:GetAttribute("Species") == "Herrera" and script:GetAttribute("AdrenalineHerreraLookOff") ~= false then -- v1.5
		char:SetAttribute("AdrenalineLook", "herrera")
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local Hd = char:GetExtentsSize().Y
	local tanks = script:GetAttribute("AdrenalineLookStyle") ~= "neck" -- v1.1
	local seg = char:FindFirstChild(tanks and "Torso" or "Neck")
	local root = seg and seg:FindFirstChild("Root")
	local lo, hi
	if hrp and root then lo, hi = rootBox(seg, root) end
	if not lo then char:SetAttribute("AdrenalineLook", tanks and "noTorso" or "noNeck") return end
	if tanks then -- v1.1: shoulder tanks, count / size by step
		local model = Instance.new("Model")
		model.Name = "Mecha_Adrenaline"
		local step = stepOf(char)
		local n = step >= 4 and 3 or step >= 3 and 2 or 1
		local k = step >= 2 and 1.25 or 1
		char:SetAttribute("AdrenalineLookStep", step) -- v1.1 diag
		char:SetAttribute("AdrenalineTanks", n)
		local ts = Vector3.new(Hd * 0.07, Hd * 0.14, Hd * 0.07) * k -- tank: right, up, back
		local x, y, z = bodyAxes(root, hrp)
		local top = (lo + hi) / 2 + y * extent(lo, hi, y) - z * (extent(lo, hi, z) * 0.55) -- top of the torso, near the front
		for i = 1, n do
			local off = (i - (n + 1) / 2) * ts.X * 1.25
			local pLocal = top + x * off + y * (ts.Y * 0.4)
			local cf = root.CFrame * CFrame.fromMatrix(pLocal, x, y, z)
			local tank = part("Tank_" .. i, ts, cf, DARK, model, root)
			local glass = part("Glass_" .. i, Vector3.new(ts.X * 1.04, ts.Y * 0.8, ts.Z * 1.04), cf, GREEN, model, nil)
			glass.Material = Enum.Material.Neon
			glass:SetAttribute("FullHeight", ts.Y * 0.8) -- v1.2: fluid level, joined by a Weld so it can drain downward
			local fw = Instance.new("Weld")
			fw.Name = "FluidHinge"
			fw.Part0, fw.Part1 = tank, glass
			fw.C0 = CFrame.new()
			fw.Parent = glass
			if step >= 4 then
				local cap = part("TankCap_" .. i, Vector3.new(ts.X * 0.7, ts.Y * 0.12, ts.Z * 0.7), cf * CFrame.new(0, ts.Y * 0.56, 0), GREEN, model, tank)
				cap.Material = Enum.Material.Neon
			end
		end
		-- tube from the tank row to the front top of the torso (where the neck joins)
		local a = top - z * (ts.Z * 0.5) + y * (ts.Y * 0.1)
		local b = (lo + hi) / 2 + y * (extent(lo, hi, y) * 0.7) - z * extent(lo, hi, z)
		local len = (b - a).Magnitude
		if len > 0.05 then
			local tcf = root.CFrame * CFrame.lookAt((a + b) / 2, b) -- Root space, looking from a to b
			part("Tube", Vector3.new(Hd * 0.018, Hd * 0.018, len), tcf, DARK, model, root)
		end
		model.Parent = char
		-- v1.2: start the fluid where the timers say
		local t = now()
		local st = chars[char]
		local untilT = tonumber(char:GetAttribute("AdrenalineUntil")) or 0
		local readyT = tonumber(char:GetAttribute("AdrenalineReadyAt")) or 0
		local dur = math.max(0.1, tonumber(char:GetAttribute("AdrenalineTime")) or 3)
		local cd = math.max(0.1, tonumber(char:GetAttribute("AdrenalineCooldown")) or 1)
		if st and st.active and untilT > t then
			fluid(char, (untilT - t) / dur, 0, untilT - t)
		elseif readyT > t then
			fluid(char, 1 - (readyT - t) / cd, 1, readyT - t)
		else
			fluid(char, 1, 1, 0.05)
		end
	end
	if not tanks then
	local model = Instance.new("Model")
	model.Name = "Mecha_Adrenaline"
	local cs = Vector3.new(Hd * 0.035, Hd * 0.05, Hd * 0.1)
	local x, y, z = bodyAxes(root, hrp)
	local pLocal = (lo + hi) / 2 + x * (extent(lo, hi, x) + cs.X * 0.5) -- on the right side of the neck, in Root's frame
	local cf = root.CFrame * CFrame.fromMatrix(pLocal, x, y, z) * CFrame.Angles(math.rad(-30), 0, 0) -- along the neck
	local can = part("Canister", cs, cf, DARK, model, root)
	part("Glass", Vector3.new(cs.X * 1.05, cs.Y * 0.6, cs.Z * 0.7), cf * CFrame.new(0, 0, cs.Z * 0.05), GREEN, model, can).Material = Enum.Material.Neon
	local ps = Vector3.new(cs.X * 0.5, cs.Y * 0.5, cs.Z * 0.35)
	local pcf = cf * CFrame.new(0, 0, -(cs.Z + ps.Z) / 2) -- sticking out of the front end
	local plunger = part("Plunger", ps, pcf, GREY, model, nil)
	local hinge = Instance.new("Weld")
	hinge.Name = "PlungerHinge"
	hinge.Part0, hinge.Part1 = can, plunger
	hinge.C0 = can.CFrame:ToObjectSpace(pcf)
	hinge:SetAttribute("BaseC0", hinge.C0)
	hinge:SetAttribute("PushZ", ps.Z * 0.85)
	hinge.Parent = plunger
	model.Parent = char
	end -- v1.1: end of the 1.0 neck look
	-- trails on both feet (2 attachments each, off until used)
	for _, f in ipairs({"FootL", "FootR"}) do
		local fseg = char:FindFirstChild(f)
		local froot = fseg and fseg:FindFirstChild("Root")
		if froot then
			local a0 = Instance.new("Attachment")
			a0.Name = "AdrenalineTrailA"
			a0.Position = Vector3.new(0, Hd * 0.05, 0) -- v1.1: wider (was 0.03)
			a0.Parent = froot
			local a1 = Instance.new("Attachment")
			a1.Name = "AdrenalineTrailB"
			a1.Position = Vector3.new(0, -Hd * 0.05, 0) -- v1.1
			a1.Parent = froot
			local t = Instance.new("Trail")
			t.Name = "AdrenalineTrail"
			t.Attachment0, t.Attachment1 = a0, a1
			t.Color = ColorSequence.new(GREEN)
			t.LightEmission = 0.8
			t.Transparency = NumberSequence.new(0.2, 1)
			t.Lifetime = 0.5 -- v1.1 (was 0.35)
			t.Enabled = false
			t.Parent = froot
		end
	end
	char:SetAttribute("AdrenalineLook", tanks and "tanks" or "on")
end

local function plunge(char, down)
	local m = char:FindFirstChild("Mecha_Adrenaline")
	local p = m and m:FindFirstChild("Plunger")
	local h = p and p:FindFirstChild("PlungerHinge")
	local base = h and h:GetAttribute("BaseC0")
	if typeof(base) ~= "CFrame" then return end
	local goal = down and base * CFrame.new(0, 0, h:GetAttribute("PushZ") or 0) or base
	TweenService:Create(h, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {C0 = goal}):Play()
end

local function pulse(char)
	local hl = Instance.new("Highlight")
	hl.Name = "AdrenalinePulse"
	hl.FillColor, hl.OutlineColor = GREEN, GREEN
	hl.FillTransparency, hl.OutlineTransparency = 0.35, 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	TweenService:Create(hl, TweenInfo.new(0.6), {FillTransparency = 1, OutlineTransparency = 1}):Play()
	task.delay(0.65, function() hl:Destroy() end) -- destroyed, not disabled (disabled Highlights still count)
end

local function finish(char, reason)
	local st = chars[char]
	if not st or not st.active then return end
	st.active = false
	local t = now()
	if st.popFrom and st.healed - st.popFrom >= 0.5 then pop(char, st.healed - st.popFrom) end -- v1.1: the rest
	st.popAt = nil
	if reason ~= "time" then
		char:SetAttribute("AdrenalineUntil", t)
		char:SetAttribute("AdrenalineReadyAt", t + (tonumber(char:GetAttribute("AdrenalineCooldown")) or 0))
	end
	char:SetAttribute("AdrenalineEndReason", reason)
	trails(char, false)
	plunge(char, false)
	glow(char, false) -- v1.1
	fluid(char, 0, 1, math.max(0.1, (tonumber(char:GetAttribute("AdrenalineReadyAt")) or t) - t)) -- v1.2: refill over the cooldown (1.1: glass fade)
end

botHook(remote):Connect(function(player, stamp)
	local char = player.Character
	local st = char and chars[char]
	if not st then return end
	script:SetAttribute("AdrenalineRequests", (script:GetAttribute("AdrenalineRequests") or 0) + 1)
	local t = now()
	local hum = st.hum
	local stunned = (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif not on() or char:GetAttribute("AdrenalineEnabled") ~= true then
		result = "disabled"
	elseif stunned and char:GetAttribute("AdrenalineStunClear") ~= true then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif herreraWindup(char) and (tonumber(char:GetAttribute("AdrenalineWindupUntil")) or 0) > t then -- v1.6
		result = "windup"
	elseif (tonumber(char:GetAttribute("AdrenalineUntil")) or 0) > t then
		result = "active"
	elseif t < (tonumber(char:GetAttribute("AdrenalineReadyAt")) or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("AdrenalineServerResult", result)
	if result ~= "ok" then return end
	if herreraWindup(char) then -- v1.6: the jab wind-up
		local w = math.clamp(tonumber(script:GetAttribute("AdrenalineHerreraWindup")) or 0.45, 0, 2)
		char:SetAttribute("AdrenalineWindupTime", w)
		char:SetAttribute("AdrenalineWindupUntil", t + w)
		char:SetAttribute("AdrenalineWindupResult", "winding")
		char:SetAttribute("AdrenalineWindupAt", t) -- last
		if w > 0 then task.wait(w) end
		if not char:IsDescendantOf(workspace) or chars[char] ~= st or not hum or hum.Health <= 0 then
			char:SetAttribute("AdrenalineWindupResult", "cancelled")
			return
		end
		char:SetAttribute("AdrenalineWindupResult", "fired")
		t = now()
		stunned = (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t and char:GetAttribute("AdrenalineStunClear") == true
	end
	if stunned then -- star: ends the stun at once
		char:SetAttribute("StunnedUntil", t)
		char:SetAttribute("AdrenalineStunCleared", (char:GetAttribute("AdrenalineStunCleared") or 0) + 1)
	end
	local dur = math.max(0.1, tonumber(char:GetAttribute("AdrenalineTime")) or 3)
	st.active = true
	st.healed = 0
	st.target = (tonumber(char:GetAttribute("AdrenalineHeal")) or 0) * hum.MaxHealth
	st.rate = st.target / dur
	st.popAt, st.popFrom = t + POP_EVERY, 0 -- v1.1
	char:SetAttribute("AdrenalineHealed", 0)
	char:SetAttribute("AdrenalineEndReason", "")
	char:SetAttribute("AdrenalineUntil", t + dur)
	char:SetAttribute("AdrenalineReadyAt", t + dur + (tonumber(char:GetAttribute("AdrenalineCooldown")) or 0))
	char:SetAttribute("AdrenalineCount", (char:GetAttribute("AdrenalineCount") or 0) + 1)
	if char:GetAttribute("AdrenalineSlashRefill") == true and script:GetAttribute("AdrenalineSlashRefillEnabled") ~= false then -- v1.5
		char:SetAttribute("SlashRefillAllAt", t)
	end
	char:SetAttribute("AdrenalineStartedAt", t) -- last: readers react to this one
	trails(char, true)
	plunge(char, true)
	glow(char, true) -- v1.1: the whole boost
	fluid(char, 1, 0, dur) -- v1.2: empties over the boost (1.1: glass fade)
	pulse(char)
end)

RunService.Heartbeat:Connect(function(dt)
	local t = now()
	for char, st in pairs(chars) do
		if st.active then
			if not char.Parent or st.hum.Health <= 0 then
				finish(char, "dead")
			elseif t >= (tonumber(char:GetAttribute("AdrenalineUntil")) or 0) then
				finish(char, "time")
			else
				local give = math.min(st.rate * dt, st.target - st.healed)
				local room = st.hum.MaxHealth - st.hum.Health
				if give > 0 and room > 0 then
					st.hum.Health += math.min(give, room)
				end
				st.healed += math.max(0, give)
				char:SetAttribute("AdrenalineHealed", math.floor(st.healed * 10 + 0.5) / 10)
				if t >= (st.popAt or math.huge) then -- v1.1: heal pop
					pop(char, st.healed - st.popFrom)
					st.popAt, st.popFrom = t + POP_EVERY, st.healed
				end
			end
		end
	end
end)

local function onCharacter(char)
	if chars[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	chars[char] = {hum = hum, active = false, healed = 0, target = 0, rate = 0}
	char:SetAttribute("AdrenalineUntil", 0)
	char:SetAttribute("AdrenalineReadyAt", 0)
	char:SetAttribute("AdrenalineLook", "none")
	char:GetAttributeChangedSignal("AdrenalineEnabled"):Connect(function()
		if char:GetAttribute("AdrenalineEnabled") ~= true then finish(char, "disabled") end
		build(char)
	end)
	char:GetAttributeChangedSignal("PartsJammedAt"):Connect(function() finish(char, "jammed") end) -- v1.3
	local pl = Players:GetPlayerFromCharacter(char) -- v1.1: the look follows the step
	if pl then
		local conn = pl:GetAttributeChangedSignal("SkillPath_adrenaline"):Connect(function()
			if char.Parent and not (chars[char] and chars[char].active) then build(char) end
		end)
		char.AncestryChanged:Connect(function(_, parent) if not parent then conn:Disconnect() end end)
	end
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	build(char)
end

script:GetAttributeChangedSignal("AdrenalineLookStyle"):Connect(function() -- v1.1
	for char in pairs(chars) do build(char) end
end)
script:GetAttributeChangedSignal("AdrenalineServerEnabled"):Connect(function()
	for char in pairs(chars) do
		if not on() then finish(char, "disabled") end
		build(char)
	end
end)

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- v1.4: Lab card preview (LabPreviewServer 1.0)
if script:GetAttribute("AdrenalineServerPreviewEnabled") == nil then script:SetAttribute("AdrenalineServerPreviewEnabled", true) end
local previewFn = script:FindFirstChild("BuildPreview") or Instance.new("BindableFunction")
previewFn.Name = "BuildPreview"
previewFn.Parent = script
previewFn.OnInvoke = function(model)
	if script:GetAttribute("AdrenalineServerPreviewEnabled") == false or typeof(model) ~= "Instance" then return nil end
	model:SetAttribute("AdrenalineEnabled", true)
	build(model)
	return model:FindFirstChild("Mecha_Adrenaline")
end

-- v1.7: the bot entrance (see the header)
if script:GetAttribute("AdrenalineServerBotMechaEnabled") == nil then script:SetAttribute("AdrenalineServerBotMechaEnabled", true) end
do
	local proxyModule = game:GetService("ServerStorage"):WaitForChild("DinoArcade"):FindFirstChild("BotProxy")
	local BotProxy = proxyModule and require(proxyModule)
	local fn = script:FindFirstChild("BotMechaUse") or Instance.new("BindableFunction")
	fn.Name = "BotMechaUse"
	fn.OnInvoke = function(model, remoteName, ...)
		if script:GetAttribute("AdrenalineServerBotMechaEnabled") == false then return "off" end
		if not BotProxy or typeof(model) ~= "Instance" or model:GetAttribute("PracticeBot") ~= true or not model.Parent then return "badArg" end
		local list = __botHandlers[remoteName]
		if not list then return "noHandler" end
		local proxy = BotProxy.of(model)
		for _, h in ipairs(list) do
			local ok, err = pcall(h, proxy, ...)
			if not ok then
				script:SetAttribute("AdrenalineServerBotMechaError", tostring(remoteName) .. ": " .. tostring(err))
				return "botUnsupported"
			end
		end
		return "ok"
	end
	fn.Parent = script
end
script:SetAttribute("AdrenalineServerVersion", "1.7") -- v1.7 bot entrance
