-- EnergyShieldServer v1.0 (Mecha Dino Arena) — Energy Shield, a raptor button part (raptor parts batch 1): block all
-- damage for a short time, but move slower while it's up. MDA-63, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 6, mockup
-- docs/mockups/raptor_parts_b1_options.html option B "Hard-light shell" (Kepu 2026-10-29: full block; "If we're allowing
-- it to block all attacks then the push back shouldn't exist"; "You block all damage but you're slower during the
-- blocking period" -> half speed, lighter at star).
-- Settings come from the character (SkillEffects 1.6): EnergyShieldEnabled (bought AND slotted), EnergyShieldTime (1.5;
--   2.05 from II; 2.77 at star), EnergyShieldCooldown (16; 11.8 from III), EnergyShieldSpeedMul (0.5; 0.68 at star;
--   SprintTest 1.6 applies it while EnergyShieldUntil > now).
-- Client -> server: ReplicatedStorage.DinoEnergyShieldRequest:FireServer(clientServerTime). Checks, first failing wins:
--   "badArg", "dead", "disabled" (EnergyShieldServerEnabled false or EnergyShieldEnabled ~= true), "stunned"
--   (StunnedUntil > now), "latched" (PounceLatched), "active" (EnergyShieldUntil > now), "cooldown" (now <
--   EnergyShieldReadyAt), "ok". ok: EnergyShieldStartedAt = now, EnergyShieldUntil = now + time, EnergyShieldReadyAt =
--   EnergyShieldUntil + cooldown (counted from the end, like Cloak), EnergyShieldCount + 1, EnergyShieldBlocks = 0.
-- Block: a ForceField "EnergyShieldField" (Visible = false) under the character while it is up, so every
--   Humanoid:TakeDamage (bot bites, bot latch / pin bites) does nothing. Each new LastHitAt (BotServer stamps it on every
--   hit attempt that reaches TakeDamage) while up counts a block: EnergyShieldBlocks + 1, EnergyShieldBlockAt.
-- Look: a Highlight "EnergyShieldShell" on the character while up (fill and outline blue 90,160,255, FillTransparency
--   0.85, OutlineTransparency 0; everyone sees it); on a block the outline turns white for 0.12 s. While
--   EnergyShieldEnabled: a small emitter disc "Emitter" (dark ring + blue neon core) on the chest (front of the Torso
--   segment's box in its Root's own frame, lower part), welded to Torso.Root; Model "Mecha_EnergyShield".
-- End: at EnergyShieldUntil ("time"), death ("dead") or EnergyShieldEnabled turning false ("disabled"): the ForceField
--   and the Highlight are destroyed (not disabled: disabled Highlights still count toward the per-client limit); early
--   ends set EnergyShieldUntil = now and EnergyShieldReadyAt = now + cooldown. EnergyShieldEndReason.
-- Settings: script attribute EnergyShieldServerEnabled (default true).
-- Diagnostics: script EnergyShieldServerVersion, EnergyShieldRequests; character EnergyShieldServerResult,
--   EnergyShieldCount, EnergyShieldBlocks, EnergyShieldBlockAt, EnergyShieldEndReason, EnergyShieldState ("off" / "on"),
--   EnergyShieldLook ("none" / "on" / "noTorso").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local BLUE, DARK, WHITE = Color3.fromRGB(90, 160, 255), Color3.fromRGB(44, 52, 64), Color3.new(1, 1, 1)

script:SetAttribute("EnergyShieldServerVersion", VERSION)
if script:GetAttribute("EnergyShieldServerEnabled") == nil then script:SetAttribute("EnergyShieldServerEnabled", true) end
script:SetAttribute("EnergyShieldRequests", 0)
local function on() return script:GetAttribute("EnergyShieldServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local remote = ReplicatedStorage:FindFirstChild("DinoEnergyShieldRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoEnergyShieldRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum, active, flashToken}

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
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = mount, p
	w.Parent = p
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

local function build(char)
	local old = char:FindFirstChild("Mecha_EnergyShield")
	if old then old:Destroy() end
	if not on() or char:GetAttribute("EnergyShieldEnabled") ~= true then
		char:SetAttribute("EnergyShieldLook", "none")
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local seg = char:FindFirstChild("Torso")
	local root = seg and seg:FindFirstChild("Root")
	if not (hrp and root) then char:SetAttribute("EnergyShieldLook", "noTorso") return end
	local lo, hi = rootBox(seg, root)
	if not lo then char:SetAttribute("EnergyShieldLook", "noTorso") return end
	local Hd = char:GetExtentsSize().Y
	local d = Hd * 0.06
	local model = Instance.new("Model")
	model.Name = "Mecha_EnergyShield"
	-- chest: front face of the torso box (forward = -z), lower part; the cylinder's axis (its X) points forward
	local x, y, z = bodyAxes(root, hrp)
	local pLocal = (lo + hi) / 2 - z * (extent(lo, hi, z) + d * 0.05) - y * (extent(lo, hi, y) * 0.3)
	local cf = root.CFrame * CFrame.fromMatrix(pLocal, -z, y)
	local ring = part("Emitter", Vector3.new(d * 0.25, d, d), cf, DARK, model, root)
	ring.Shape = Enum.PartType.Cylinder
	local core = part("EmitterCore", Vector3.new(d * 0.3, d * 0.5, d * 0.5), cf, BLUE, model, root)
	core.Shape = Enum.PartType.Cylinder
	core.Material = Enum.Material.Neon
	model.Parent = char
	char:SetAttribute("EnergyShieldLook", "on")
end

local function clearFx(char)
	for _, n in ipairs({"EnergyShieldField", "EnergyShieldShell"}) do
		local x = char:FindFirstChild(n)
		while x do
			x:Destroy()
			x = char:FindFirstChild(n)
		end
	end
end

local function finish(char, reason)
	local st = chars[char]
	if not st or not st.active then return end
	st.active = false
	local t = now()
	if reason ~= "time" then
		char:SetAttribute("EnergyShieldUntil", t)
		char:SetAttribute("EnergyShieldReadyAt", t + (tonumber(char:GetAttribute("EnergyShieldCooldown")) or 0))
	end
	clearFx(char)
	char:SetAttribute("EnergyShieldEndReason", reason)
	char:SetAttribute("EnergyShieldState", "off")
end

remote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	local st = char and chars[char]
	if not st then return end
	script:SetAttribute("EnergyShieldRequests", (script:GetAttribute("EnergyShieldRequests") or 0) + 1)
	local t = now()
	local hum = st.hum
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif not on() or char:GetAttribute("EnergyShieldEnabled") ~= true then
		result = "disabled"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif (tonumber(char:GetAttribute("EnergyShieldUntil")) or 0) > t then
		result = "active"
	elseif t < (tonumber(char:GetAttribute("EnergyShieldReadyAt")) or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("EnergyShieldServerResult", result)
	if result ~= "ok" then return end
	local dur = math.max(0.1, tonumber(char:GetAttribute("EnergyShieldTime")) or 1.5)
	clearFx(char)
	local ff = Instance.new("ForceField")
	ff.Name = "EnergyShieldField"
	ff.Visible = false
	ff.Parent = char
	local hl = Instance.new("Highlight")
	hl.Name = "EnergyShieldShell"
	hl.FillColor, hl.OutlineColor = BLUE, BLUE
	hl.FillTransparency, hl.OutlineTransparency = 0.85, 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	st.active = true
	st.lastHit = char:GetAttribute("LastHitAt")
	char:SetAttribute("EnergyShieldBlocks", 0)
	char:SetAttribute("EnergyShieldEndReason", "")
	char:SetAttribute("EnergyShieldUntil", t + dur)
	char:SetAttribute("EnergyShieldReadyAt", t + dur + (tonumber(char:GetAttribute("EnergyShieldCooldown")) or 0))
	char:SetAttribute("EnergyShieldCount", (char:GetAttribute("EnergyShieldCount") or 0) + 1)
	char:SetAttribute("EnergyShieldState", "on")
	char:SetAttribute("EnergyShieldStartedAt", t) -- last: readers react to this one
end)

RunService.Heartbeat:Connect(function()
	local t = now()
	for char, st in pairs(chars) do
		if st.active then
			if not char.Parent or st.hum.Health <= 0 then
				finish(char, "dead")
			elseif t >= (tonumber(char:GetAttribute("EnergyShieldUntil")) or 0) then
				finish(char, "time")
			end
		end
	end
end)

local function onCharacter(char)
	if chars[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local st = {hum = hum, active = false}
	chars[char] = st
	char:SetAttribute("EnergyShieldUntil", 0)
	char:SetAttribute("EnergyShieldReadyAt", 0)
	char:SetAttribute("EnergyShieldState", "off")
	char:SetAttribute("EnergyShieldLook", "none")
	char:GetAttributeChangedSignal("LastHitAt"):Connect(function()
		local at = char:GetAttribute("LastHitAt")
		if not st.active or at == st.lastHit then return end
		st.lastHit = at
		char:SetAttribute("EnergyShieldBlocks", (char:GetAttribute("EnergyShieldBlocks") or 0) + 1)
		char:SetAttribute("EnergyShieldBlockAt", now())
		local hl = char:FindFirstChild("EnergyShieldShell")
		if hl then
			local token = {}
			st.flashToken = token
			hl.OutlineColor = WHITE
			task.delay(0.12, function()
				if st.flashToken == token and hl.Parent then hl.OutlineColor = BLUE end
			end)
		end
	end)
	char:GetAttributeChangedSignal("EnergyShieldEnabled"):Connect(function()
		if char:GetAttribute("EnergyShieldEnabled") ~= true then finish(char, "disabled") end
		build(char)
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	build(char)
end

script:GetAttributeChangedSignal("EnergyShieldServerEnabled"):Connect(function()
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
