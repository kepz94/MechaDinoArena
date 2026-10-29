-- AdrenalineServer v1.0 (Mecha Dino Arena) — Adrenaline Injector, a raptor button part (raptor parts batch 1): heal over
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
-- Look: Model "Mecha_Adrenaline" under the character while AdrenalineEnabled is true: on the side of the neck (the Neck
--   segment's box in the HumanoidRootPart's frame, right side) a dark canister "Canister" with green glass "Glass" and a
--   grey plunger "Plunger" on top (Weld "PlungerHinge", attribute BaseC0). Welded to the Neck segment's Root. Massless,
--   no collide / query / touch, no shadow. On each use: the plunger slides down into the canister (0.25 s) and back up
--   at the end; a green Highlight "AdrenalinePulse" fades from FillTransparency 0.35 to 1 over 0.6 s and is destroyed;
--   green Trails "AdrenalineTrail" on both feet are on until AdrenalineUntil.
-- Settings: script attribute AdrenalineServerEnabled (default true).
-- Diagnostics: script AdrenalineServerVersion, AdrenalineRequests; character AdrenalineServerResult, AdrenalineCount,
--   AdrenalineHealed, AdrenalineEndReason, AdrenalineStunCleared, AdrenalineLook ("none" / "on" / "noNeck").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
local GREEN, DARK, GREY = Color3.fromRGB(95, 209, 106), Color3.fromRGB(44, 52, 64), Color3.fromRGB(154, 166, 182)

script:SetAttribute("AdrenalineServerVersion", VERSION)
if script:GetAttribute("AdrenalineServerEnabled") == nil then script:SetAttribute("AdrenalineServerEnabled", true) end
script:SetAttribute("AdrenalineRequests", 0)
local function on() return script:GetAttribute("AdrenalineServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local remote = ReplicatedStorage:FindFirstChild("DinoAdrenalineRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoAdrenalineRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum, active, healed, target}

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

local function boxOf(seg, hrp, root)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
				local q = hrp.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz))
				lo, hi = lo:Min(q), hi:Max(q)
			end end end
		end
	end
	if lo.X == math.huge then return nil end
	return lo, hi
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
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local seg = char:FindFirstChild("Neck")
	local root = seg and seg:FindFirstChild("Root")
	local lo, hi
	if hrp and root then lo, hi = boxOf(seg, hrp, root) end
	if not lo then char:SetAttribute("AdrenalineLook", "noNeck") return end
	local Hd = char:GetExtentsSize().Y
	local R, U, L = hrp.CFrame.RightVector, hrp.CFrame.UpVector, hrp.CFrame.LookVector
	local model = Instance.new("Model")
	model.Name = "Mecha_Adrenaline"
	local c = Vector3.new(hi.X + Hd * 0.012, (lo.Y + hi.Y) / 2, (lo.Z + hi.Z) / 2) -- right side of the neck
	local cs = Vector3.new(Hd * 0.035, Hd * 0.05, Hd * 0.1)
	local cf = CFrame.fromMatrix(hrp.CFrame:PointToWorldSpace(c), R, U, -L) * CFrame.Angles(math.rad(-30), 0, 0) -- along the neck
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
	-- trails on both feet (2 attachments each, off until used)
	for _, f in ipairs({"FootL", "FootR"}) do
		local fseg = char:FindFirstChild(f)
		local froot = fseg and fseg:FindFirstChild("Root")
		if froot then
			local a0 = Instance.new("Attachment")
			a0.Name = "AdrenalineTrailA"
			a0.Position = Vector3.new(0, Hd * 0.03, 0)
			a0.Parent = froot
			local a1 = Instance.new("Attachment")
			a1.Name = "AdrenalineTrailB"
			a1.Position = Vector3.new(0, -Hd * 0.03, 0)
			a1.Parent = froot
			local t = Instance.new("Trail")
			t.Name = "AdrenalineTrail"
			t.Attachment0, t.Attachment1 = a0, a1
			t.Color = ColorSequence.new(GREEN)
			t.LightEmission = 0.8
			t.Transparency = NumberSequence.new(0.2, 1)
			t.Lifetime = 0.35
			t.Enabled = false
			t.Parent = froot
		end
	end
	char:SetAttribute("AdrenalineLook", "on")
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
	if reason ~= "time" then
		char:SetAttribute("AdrenalineUntil", t)
		char:SetAttribute("AdrenalineReadyAt", t + (tonumber(char:GetAttribute("AdrenalineCooldown")) or 0))
	end
	char:SetAttribute("AdrenalineEndReason", reason)
	trails(char, false)
	plunge(char, false)
end

remote.OnServerEvent:Connect(function(player, stamp)
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
	elseif (tonumber(char:GetAttribute("AdrenalineUntil")) or 0) > t then
		result = "active"
	elseif t < (tonumber(char:GetAttribute("AdrenalineReadyAt")) or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("AdrenalineServerResult", result)
	if result ~= "ok" then return end
	if stunned then -- star: ends the stun at once
		char:SetAttribute("StunnedUntil", t)
		char:SetAttribute("AdrenalineStunCleared", (char:GetAttribute("AdrenalineStunCleared") or 0) + 1)
	end
	local dur = math.max(0.1, tonumber(char:GetAttribute("AdrenalineTime")) or 3)
	st.active = true
	st.healed = 0
	st.target = (tonumber(char:GetAttribute("AdrenalineHeal")) or 0) * hum.MaxHealth
	st.rate = st.target / dur
	char:SetAttribute("AdrenalineHealed", 0)
	char:SetAttribute("AdrenalineEndReason", "")
	char:SetAttribute("AdrenalineUntil", t + dur)
	char:SetAttribute("AdrenalineReadyAt", t + dur + (tonumber(char:GetAttribute("AdrenalineCooldown")) or 0))
	char:SetAttribute("AdrenalineCount", (char:GetAttribute("AdrenalineCount") or 0) + 1)
	char:SetAttribute("AdrenalineStartedAt", t) -- last: readers react to this one
	trails(char, true)
	plunge(char, true)
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
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	build(char)
end

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
