-- MechaServer v1.1 (Mecha Dino Arena) — mecha parts on the server: the Thrusters dash (requests, charges) and the visible
-- Thrusters part on the dino. MDA-27, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 5, mockup
-- docs/mockups/mecha_thrusters_options.html (Kepu 2026-10-28: framework + Thrusters first; numbers as proposed; the dash is
-- free; the part is on the dino only while it is in a loadout slot; bots only).
-- Settings come from the character (SkillEffects 1.1): DashEnabled (bought AND slotted), DashCharges (1 / 2), DashDistance,
--   DashHop, DashTime (0.35), DashRecharge (8). The dash physics is done by the owner's client (MechaButtons 1.0), like
--   JumpServer 1.0 / JumpTest: the server only gates the request.
-- Client -> server: ReplicatedStorage.DinoDashRequest:FireServer(clientServerTime). Checks, in order (first failing one
--   is the result):
--   "badArg"   stamp is not a number          "dead"     no character / Humanoid health <= 0
--   "disabled" MechaEnabled false or DashEnabled ~= true
--   "stunned"  StunnedUntil > now              "latched"  PounceLatched == true
--   "charges"  DashChargesLeft < 1             -> "ok"
--   ok: DashStartedAt = stamp clamped to [now - MAX_LAG, now], DashCount + 1, one charge used. Denied: DashDenyReason,
--   DashDeniedAt = stamp, DashDenyCount + 1. Always: DashServerResult.
-- Charges: DashChargesLeft (starts full), DashNextChargeAt (server time the next charge comes back; 0 when full). One charge
--   comes back every DashRecharge s until full. DashCharges going up adds the new charges full; going down clamps.
--   DashEnabled false -> DashChargesLeft 0, DashNextChargeAt 0; true again -> full.
-- Part: Model "Mecha_Thrusters" directly under the character (not inside a body segment, so DinoHitboxes / IdleAnimation
--   don't see it): Booster_L / Booster_R on top of the back of the Torso segment (the Model "Torso": the box of its parts in
--   the HumanoidRootPart's frame; boosters dino height x 0.09 wide, x 0.13 tall, max(torso length x 0.35, height x 0.22)
--   long, at +/- max(torso width x 0.28, booster width x 0.65) from the middle, 60% of the way from front to back, sunk
--   35% into the top), so it fits the T-Rex and the 2x raptor; Nozzle_L / _R at the
--   back of each booster with Attachment "FlameAt" + ParticleEmitter "Flame"; Fin_L / _R (orange) at star. Look per
--   step: I and II "I" (small), III "III" (boosters x 1.3), star "star" (x 1.3 + fins). All parts Massless, CanCollide /
--   CanQuery / CanTouch false, welded (WeldConstraint) to Torso.Root. Shown while DashEnabled is true, rebuilt when the
--   look changes, removed otherwise. Flame: Enabled for DashTime s after each new DashStartedAt.
-- Settings (script attributes): MechaEnabled (default true; false -> every request "disabled" and parts removed).
-- Diagnostics: script MechaServerVersion, MechaDashes (accepted dashes); character MechaThrustersLook ("none" / "I" /
--   "III" / "star"), DashServerResult, DashCount, DashDenyCount.
-- v1.1 (Thrusters boost, MDA-32; Kepu 2026-10-28 after trying it on PC: "make the fire that shoots out visible"): the flame
--   was too small and too short (0.35 s). Now each nozzle has, during the whole boost (DashTime: 1.5 s / 2 s, SkillEffects
--   1.2): the Flame ParticleEmitter with Roblox's fire texture, bigger (booster width x 1.2 -> 0.2) and longer-lived
--   (0.25-0.45 s, rate 150, spread 8); a neon Jet_L / Jet_R part behind the nozzle (yellow-orange, Transparency 0.15
--   while boosting, 1 otherwise; massless, no collide / query / touch); and a PointLight "Glow" (orange, range 4 x booster
--   width, brightness 3). A later boost restarts the timer (an earlier boost's end no longer switches off a newer one).
--   Diagnostic: character MechaFlame (true while the flame is on).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
local MAX_LAG = 0.3
local DEFAULT_RECHARGE, DEFAULT_TIME = 8, 0.35
local METAL, DARK, ORANGE = Color3.fromRGB(123, 133, 144), Color3.fromRGB(43, 47, 53), Color3.fromRGB(255, 155, 46)

script:SetAttribute("MechaServerVersion", VERSION)
if script:GetAttribute("MechaEnabled") == nil then script:SetAttribute("MechaEnabled", true) end
script:SetAttribute("MechaDashes", 0)
local function on() return script:GetAttribute("MechaEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local remote = ReplicatedStorage:FindFirstChild("DinoDashRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoDashRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {max, look}

-- charges ------------------------------------------------------------------------------------------------------------
local function enabled(char) return on() and char:GetAttribute("DashEnabled") == true end
local function recharge(char) return tonumber(char:GetAttribute("DashRecharge")) or DEFAULT_RECHARGE end

local function syncCharges(char, st)
	local max = enabled(char) and math.max(0, math.floor(tonumber(char:GetAttribute("DashCharges")) or 0)) or 0
	local left = char:GetAttribute("DashChargesLeft") or 0
	if max == 0 then
		left = 0
	elseif st.max == 0 then
		left = max -- just enabled: full
	elseif max > st.max then
		left += max - st.max -- new charges come full
	end
	left = math.clamp(left, 0, max)
	st.max = max
	char:SetAttribute("DashChargesLeft", left)
	if left >= max then char:SetAttribute("DashNextChargeAt", 0)
	elseif (char:GetAttribute("DashNextChargeAt") or 0) == 0 then char:SetAttribute("DashNextChargeAt", now() + recharge(char)) end
end

-- the visible part ---------------------------------------------------------------------------------------------------
local function lookOf(char)
	if not enabled(char) then return "none" end
	local p = char.Parent and Players:GetPlayerFromCharacter(char)
	local steps = p and p:GetAttribute("SkillPath_thrusters") or 0
	if steps >= 4 then return "star" elseif steps >= 3 then return "III" elseif steps >= 1 then return "I" end
	return "none"
end

local function part(name, size, cf, color, parent, torso)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Parent = parent
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = torso, p
	w.Parent = p
	return p
end

local function build(char, look)
	local old = char:FindFirstChild("Mecha_Thrusters")
	if old then old:Destroy() end
	char:SetAttribute("MechaThrustersLook", look)
	if look == "none" then return end
	-- the Torso segment (a Model of parts with a "Root" part; measured in Play: the parts run along the dino's look axis,
	-- Torso_body alone is not the body's length): its box in the HumanoidRootPart's frame (+X right, +Y up, -Z forward)
	local seg = char:FindFirstChild("Torso")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local torso = seg and (seg:FindFirstChild("Root") or seg:FindFirstChild("Torso_body", true))
	if not (seg and hrp and torso and torso:IsA("BasePart")) then
		char:SetAttribute("MechaThrustersLook", "noTorso")
		return
	end
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p ~= torso then
			for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
				local q = hrp.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz))
				lo, hi = lo:Min(q), hi:Max(q)
			end end end
		end
	end
	if lo.X == math.huge then
		char:SetAttribute("MechaThrustersLook", "noTorso")
		return
	end
	local R, U, L = hrp.CFrame.RightVector, hrp.CFrame.UpVector, hrp.CFrame.LookVector
	local W, H, Ln = hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z
	local k = (look == "III" or look == "star") and 1.3 or 1
	-- booster size from the dino's height (the raptor's torso is slim: torso-based boosters were 0.5 stud wide on it)
	local Hd = char:GetExtentsSize().Y
	local bs = Vector3.new(Hd * 0.09, Hd * 0.13, math.max(Ln * 0.35, Hd * 0.22)) * k -- booster: right, up, look
	local half = math.max(W * 0.28, bs.X * 0.65) -- distance of each booster from the middle
	local model = Instance.new("Model")
	model.Name = "Mecha_Thrusters"
	-- on top of the back: 60% of the way from the front (-Z) to the back (+Z), sunk 35% into the top
	local baseLocal = Vector3.new((lo.X + hi.X) / 2, hi.Y + bs.Y * 0.15, lo.Z + Ln * 0.6)
	local base = hrp.CFrame:PointToWorldSpace(baseLocal)
	for _, side in ipairs({{"L", -1}, {"R", 1}}) do
		local c = base + R * side[2] * half
		local rot = CFrame.fromMatrix(c, R, U, -L) -- part LookVector = the dino's look
		part("Booster_" .. side[1], bs, rot, METAL, model, torso)
		local ns = Vector3.new(bs.X * 0.7, bs.Y * 0.7, bs.Z * 0.18)
		local nozzle = part("Nozzle_" .. side[1], ns, rot * CFrame.new(0, 0, (bs.Z + ns.Z) / 2), DARK, model, torso)
		local at = Instance.new("Attachment")
		at.Name = "FlameAt"
		at.Position = Vector3.new(0, 0, ns.Z / 2)
		at.Parent = nozzle
		local f = Instance.new("ParticleEmitter")
		f.Name = "Flame"
		f.Enabled = false
		f.EmissionDirection = Enum.NormalId.Back
		f.Color = ColorSequence.new(Color3.fromRGB(255, 226, 122), Color3.fromRGB(255, 122, 26))
		f.Texture = "rbxasset://textures/particles/fire_main.dds" -- v1.1
		f.Size = NumberSequence.new(bs.X * 1.2, 0.2) -- v1.1: was ns.X x 0.6 -> 0
		f.Lifetime = NumberRange.new(0.25, 0.45) -- v1.1: was 0.15-0.25
		f.Rate = 150 -- v1.1: was 120
		f.Speed = NumberRange.new(12, 20) -- v1.1: was 20-30
		f.SpreadAngle = Vector2.new(8, 8) -- v1.1
		f.LightEmission = 1
		f.LightInfluence = 0 -- v1.1
		f.Parent = at
		local glow = Instance.new("PointLight") -- v1.1
		glow.Name = "Glow"
		glow.Color = Color3.fromRGB(255, 150, 50)
		glow.Range = bs.X * 4
		glow.Brightness = 3
		glow.Enabled = false
		glow.Parent = at
		local jet = part("Jet_" .. side[1], Vector3.new(ns.X * 0.8, ns.Y * 0.8, bs.Z * 0.6), -- v1.1: neon jet behind the nozzle
			rot * CFrame.new(0, 0, (bs.Z + ns.Z) / 2 + ns.Z / 2 + bs.Z * 0.3), Color3.fromRGB(255, 190, 60), model, torso)
		jet.Material = Enum.Material.Neon
		jet.Transparency = 1
		if look == "star" then
			part("Fin_" .. side[1], Vector3.new(bs.X * 0.15, bs.Y * 0.5, bs.Z * 0.6),
				rot * CFrame.new(0, (bs.Y + bs.Y * 0.5) / 2, bs.Z * 0.1), ORANGE, model, torso)
		end
	end
	model.Parent = char
end

local function refreshLook(char, st)
	local look = lookOf(char)
	if look ~= st.look or (look ~= "none" and not char:FindFirstChild("Mecha_Thrusters")) then
		st.look = look
		build(char, look)
	end
end

local flameToken = setmetatable({}, {__mode = "k"}) -- v1.1: [char] = the newest boost
local function setFlame(m, on) -- v1.1: emitters, jets and lights together
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then d.Enabled = on
		elseif d:IsA("BasePart") and d.Name:sub(1, 4) == "Jet_" then d.Transparency = on and 0.15 or 1 end
	end
end
local function flame(char)
	local m = char:FindFirstChild("Mecha_Thrusters")
	if not m then return end
	local t = tonumber(char:GetAttribute("DashTime")) or DEFAULT_TIME
	local token = {}
	flameToken[char] = token
	setFlame(m, true)
	char:SetAttribute("MechaFlame", true)
	task.delay(t, function()
		if flameToken[char] ~= token then return end -- a newer boost owns the flame
		if m.Parent then setFlame(m, false) end
		char:SetAttribute("MechaFlame", false)
	end)
end

-- characters ---------------------------------------------------------------------------------------------------------
local function onCharacter(player, char)
	if chars[char] then return end
	local st = {max = 0, look = "none"}
	chars[char] = st
	char:SetAttribute("DashChargesLeft", 0)
	char:SetAttribute("DashNextChargeAt", 0)
	char:SetAttribute("MechaThrustersLook", "none")
	local function sync()
		syncCharges(char, st)
		refreshLook(char, st)
	end
	for _, a in ipairs({"DashEnabled", "DashCharges"}) do char:GetAttributeChangedSignal(a):Connect(sync) end
	char:GetAttributeChangedSignal("DashStartedAt"):Connect(function() flame(char) end)
	char.AncestryChanged:Connect(function(_, parent) if not parent then chars[char] = nil end end)
	sync()
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
	player:GetAttributeChangedSignal("SkillPath_thrusters"):Connect(function()
		local char = player.Character
		local st = char and chars[char]
		if st then refreshLook(char, st) end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

script:GetAttributeChangedSignal("MechaEnabled"):Connect(function()
	for char, st in pairs(chars) do
		syncCharges(char, st)
		refreshLook(char, st)
	end
end)

-- recharge
RunService.Heartbeat:Connect(function()
	local t = now()
	for char, st in pairs(chars) do
		local nextAt = char:GetAttribute("DashNextChargeAt") or 0
		if st.max > 0 and nextAt > 0 and t >= nextAt then
			local left = math.min(st.max, (char:GetAttribute("DashChargesLeft") or 0) + 1)
			char:SetAttribute("DashChargesLeft", left)
			char:SetAttribute("DashNextChargeAt", left < st.max and t + recharge(char) or 0)
		end
	end
end)

-- requests
remote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	local st = char and chars[char]
	if not st then return end
	local t = now()
	local hum = char:FindFirstChildOfClass("Humanoid")
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif not enabled(char) then
		result = "disabled"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif (char:GetAttribute("DashChargesLeft") or 0) < 1 then
		result = "charges"
	else
		result = "ok"
	end
	char:SetAttribute("DashServerResult", result)
	if result == "ok" then
		local left = char:GetAttribute("DashChargesLeft") - 1
		char:SetAttribute("DashChargesLeft", left)
		if (char:GetAttribute("DashNextChargeAt") or 0) == 0 then char:SetAttribute("DashNextChargeAt", t + recharge(char)) end
		char:SetAttribute("DashCount", (char:GetAttribute("DashCount") or 0) + 1)
		char:SetAttribute("DashStartedAt", math.clamp(stamp, t - MAX_LAG, t))
		script:SetAttribute("MechaDashes", (script:GetAttribute("MechaDashes") or 0) + 1)
	elseif result ~= "badArg" then
		char:SetAttribute("DashDenyCount", (char:GetAttribute("DashDenyCount") or 0) + 1)
		char:SetAttribute("DashDenyReason", result)
		char:SetAttribute("DashDeniedAt", stamp)
	end
end)
